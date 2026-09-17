extends Node
## Enemy registry: owns the active enemy list, the Enemy scene pool, and
## lookup queries for targeting. Created per-run by Main.

signal enemy_registered(enemy: Node)
signal enemy_released(enemy: Node)

const ENEMY_SCENE := "res://scenes/enemies/Enemy.tscn"

var active_enemies: Array = []
var _spawn_queue: Array = []
var arena_ref: Node3D = null
var player_ref: Node3D = null
## Enemies beyond this distance from the player are recycled.
const CULL_DISTANCE := 55.0

## Queue a spawn (deferred to next frame to keep spawner cheap).
## elite: optional Array of ability ids.
func queue_spawn(data: EnemyData, position: Vector3, player: Node3D, hp_scale: float, dmg_scale: float, spd_scale: float, elite: Array = []) -> void:
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

func _process(_delta: float) -> void:
	if _spawn_queue.is_empty():
		# Still run culling even without spawns pending
		_cull_far_enemies()
		return
	var queue := _spawn_queue
	_spawn_queue = []
	for req in queue:
		_spawn_now(req)
	_cull_far_enemies()

## Recycle enemies too far from the player — they would otherwise attack
## from off-screen invisibly.
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
	# Elite promotion
	if req.get("elite", []):
		enemy.make_elite(req["elite"])
		if enemy.elite != null and not enemy.elite.request_minions.is_connected(_on_minions_requested):
			enemy.elite.request_minions.connect(_on_minions_requested)
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died.bind(enemy))
	active_enemies.append(enemy)
	PerformanceManager.active_enemies = active_enemies.size()
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
	PerformanceManager.active_enemies = active_enemies.size()
	enemy_released.emit(enemy)
	enemy.despawn()
	PoolManager.release(enemy)

## --- Queries (used by TargetingSystem at weapon cadence) ---

func get_enemies_in_radius(center: Vector3, radius: float, max_count: int = 0) -> Array:
	var out := []
	var r2 := radius * radius
	for e in active_enemies:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_squared_to(center) <= r2:
			out.append(e)
			if max_count > 0 and out.size() >= max_count:
				break
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
