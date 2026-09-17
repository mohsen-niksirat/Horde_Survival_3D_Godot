extends Node
## Enemy registry: owns the active enemy list, pool queries, and a uniform
## spatial hash so weapons don't O(n) scan every enemy every query.
## Created per-run by Main.

signal enemy_registered(enemy: Node)
signal enemy_released(enemy: Node)

const ENEMY_SCENE := "res://scenes/enemies/Enemy.tscn"
const CELL_SIZE := 8.0
## Cap how many enemies can enter the tree in a single frame (hitch guard).
const MAX_SPAWNS_PER_FRAME := 8
const MAX_SPAWN_QUEUE := 48
## Grid rebuilds when dirty or older than this (ms).
const GRID_REBUILD_MS := 40
## Below this count a linear scan is cheaper than grid bookkeeping.
const LINEAR_THRESHOLD := 20

var active_enemies: Array = []
var _spawn_queue: Array = []
var arena_ref: Node3D = null
var player_ref: Node3D = null
const CULL_DISTANCE := 55.0

var _grid: Dictionary = {}  # Vector2i -> Array[Node]
var _grid_dirty: bool = true
var _grid_time_ms: int = -100000

func queue_spawn(data: EnemyData, position: Vector3, player: Node3D, hp_scale: float, dmg_scale: float, spd_scale: float, elite: Array = []) -> void:
	if _spawn_queue.size() >= MAX_SPAWN_QUEUE:
		return
	_spawn_queue.append({
		"data": data,
		"position": position,
		"player": player,
		"hp": hp_scale,
		"dmg": dmg_scale,
		"spd": spd_scale,
		"elite": elite,
	})

func _ready() -> void:
	add_to_group("enemy_manager")
	prewarm_pool(16)

func prewarm_pool(count: int) -> void:
	# First-load budget: Very Low / web start with a smaller free list
	if PerformanceManager != null and PerformanceManager.quality <= PerformanceManager.Quality.VERY_LOW:
		count = mini(count, 8)
	if OS.get_name() == "Web" and count > 12:
		count = 12
	PoolManager.create_pool(ENEMY_SCENE, count)

func _process(_delta: float) -> void:
	# Spawn budget: max N new enemies per frame to avoid load spikes
	var budget := MAX_SPAWNS_PER_FRAME
	while budget > 0 and not _spawn_queue.is_empty():
		var req = _spawn_queue.pop_front()
		_spawn_now(req)
		budget -= 1
	_cull_far_enemies()
	_ensure_grid()

func mark_grid_dirty() -> void:
	_grid_dirty = true

func _ensure_grid() -> void:
	var now := Time.get_ticks_msec()
	if _grid_dirty or now - _grid_time_ms >= GRID_REBUILD_MS:
		_rebuild_grid(now)

func _rebuild_grid(now: int = -1) -> void:
	_grid.clear()
	for e in active_enemies:
		if not is_instance_valid(e):
			continue
		var p: Vector3 = e.global_position
		var key := Vector2i(int(floor(p.x / CELL_SIZE)), int(floor(p.z / CELL_SIZE)))
		if not _grid.has(key):
			_grid[key] = []
		_grid[key].append(e)
	_grid_dirty = false
	_grid_time_ms = now if now >= 0 else Time.get_ticks_msec()

func _cull_far_enemies() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	var cull2 := CULL_DISTANCE * CULL_DISTANCE
	var player_pos := player_ref.global_position
	var i := active_enemies.size() - 1
	while i >= 0:
		var enemy = active_enemies[i]
		if not is_instance_valid(enemy):
			active_enemies.remove_at(i)
			_grid_dirty = true
			i -= 1
			continue
		if enemy.global_position.distance_squared_to(player_pos) > cull2:
			release_enemy(enemy)
		i -= 1

func _spawn_now(req: Dictionary) -> void:
	var enemy := PoolManager.acquire(ENEMY_SCENE)
	PoolManager.tag(enemy, ENEMY_SCENE)
	var container: Node = get_node_or_null("../World")
	if container == null:
		container = get_parent()
	container.add_child(enemy)
	enemy.global_position = req["position"]
	enemy.setup(req["data"], req["player"], req["hp"], req["dmg"], req["spd"])
	if req.get("elite", []):
		enemy.make_elite(req["elite"])
		if enemy.elite != null and not enemy.elite.request_minions.is_connected(_on_minions_requested):
			enemy.elite.request_minions.connect(_on_minions_requested)
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died.bind(enemy))
	active_enemies.append(enemy)
	_grid_dirty = true
	PerformanceManager.active_enemies = active_enemies.size()
	if PerformanceManager != null:
		PerformanceManager.update_horde_pressure(active_enemies.size())
	enemy_registered.emit(enemy)

func _on_minions_requested(count: int, position: Vector3) -> void:
	var drone: EnemyData = archetype("swarm_bat")
	if drone == null:
		return
	for i in range(count):
		var offset := Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		queue_spawn(drone, position + offset, player_ref, 1.0, 1.0, 1.0)

func archetype(id: String) -> EnemyData:
	var path := "res://data/enemies/%s.tres" % id
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _on_enemy_died(_enemy: Node, enemy: Node) -> void:
	release_enemy(enemy)

func release_enemy(enemy: Node) -> void:
	active_enemies.erase(enemy)
	_grid_dirty = true
	PerformanceManager.active_enemies = active_enemies.size()
	if PerformanceManager != null:
		PerformanceManager.update_horde_pressure(active_enemies.size())
	enemy_released.emit(enemy)
	enemy.despawn()
	PoolManager.release(enemy)

## Spatial-hash radius query. Falls back to linear scan for small hordes.
func get_enemies_in_radius(center: Vector3, radius: float, max_count: int = 0) -> Array:
	var out := []
	var r2 := radius * radius
	if active_enemies.size() < LINEAR_THRESHOLD:
		for e in active_enemies:
			if not is_instance_valid(e):
				continue
			if e.global_position.distance_squared_to(center) <= r2:
				out.append(e)
				if max_count > 0 and out.size() >= max_count:
					break
		return out
	_ensure_grid()
	var min_c := Vector2i(
		int(floor((center.x - radius) / CELL_SIZE)),
		int(floor((center.z - radius) / CELL_SIZE))
	)
	var max_c := Vector2i(
		int(floor((center.x + radius) / CELL_SIZE)),
		int(floor((center.z + radius) / CELL_SIZE))
	)
	var seen := {}
	for cx in range(min_c.x, max_c.x + 1):
		for cz in range(min_c.y, max_c.y + 1):
			var cell: Array = _grid.get(Vector2i(cx, cz), [])
			for e in cell:
				if not is_instance_valid(e):
					continue
				var id: int = e.get_instance_id()
				if seen.has(id):
					continue
				seen[id] = true
				if e.global_position.distance_squared_to(center) <= r2:
					out.append(e)
					if max_count > 0 and out.size() >= max_count:
						return out
	return out

func get_all_enemies() -> Array:
	return active_enemies

func enemy_count() -> int:
	return active_enemies.size()

func clear_all() -> void:
	for e in active_enemies.duplicate():
		if is_instance_valid(e):
			release_enemy(e)
	_spawn_queue.clear()
	_grid.clear()
	_grid_dirty = true
