extends Node
## JuiceManager: pooled combat feedback — 3D damage numbers, kill bursts,
## level-up rings. Listens to EventBus; damage numbers respect quality caps.

const DAMAGE_NUMBER_SCENE := "res://scenes/vfx/DamageNumber.tscn"
const KILL_BURST_SCENE := "res://scenes/vfx/KillBurst.tscn"
const POOL_SIZES := {DAMAGE_NUMBER_SCENE: 40, KILL_BURST_SCENE: 12}

var _player: Node3D
var _pools: Dictionary = {}
var _indices: Dictionary = {}
var _number_throttle_ms: int = 0
var _burst_skip: bool = false

func setup(player: Node3D) -> void:
	_player = player
	# First-load budget: Very Low / web prewarm fewer VFX nodes
	var dmg_n: int = POOL_SIZES[DAMAGE_NUMBER_SCENE]
	var burst_n: int = POOL_SIZES[KILL_BURST_SCENE]
	if PerformanceManager != null and PerformanceManager.quality <= PerformanceManager.Quality.VERY_LOW:
		dmg_n = 14
		burst_n = 6
	if OS.get_name() == "Web":
		dmg_n = mini(dmg_n, 20)
		burst_n = mini(burst_n, 8)
	for scene_path in [DAMAGE_NUMBER_SCENE, KILL_BURST_SCENE]:
		if ResourceLoader.exists(scene_path):
			var scene: PackedScene = load(scene_path)
			var base_name: String = scene_path.get_file().get_basename()
			var n: int = dmg_n if scene_path == DAMAGE_NUMBER_SCENE else burst_n
			for i in range(n):
				var inst := scene.instantiate()
				inst.visible = false
				inst.name = "%s_%d" % [base_name, i]
				add_child(inst)
				var pool: Array = _pools.get(scene_path, [])
				pool.append(inst)
				_pools[scene_path] = pool
	EventBus.enemy_damaged.connect(_on_enemy_damaged)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_leveled_up.connect(_on_level_up)

func _acquire(scene_path: String) -> Node3D:
	var pool: Array = _pools.get(scene_path, [])
	if pool.is_empty():
		return null
	# Prefer an idle (hidden) node so a still-animating one isn't stolen.
	for node in pool:
		if is_instance_valid(node) and not node.visible:
			return node
	# All busy — fall back to round-robin.
	var idx: int = _indices.get(scene_path, 0)
	_indices[scene_path] = (idx + 1) % pool.size()
	return pool[idx]

func _on_enemy_damaged(enemy: Node, amount: float, is_crit: bool) -> void:
	var now := Time.get_ticks_msec()
	# Settings toggle
	if SaveManager != null and not SaveManager.get_setting("show_damage_numbers", true):
		return
	# V15A: skip cheap non-crits entirely when the horde is huge
	if PerformanceManager != null and PerformanceManager.should_skip_damage_number(is_crit, amount):
		return
	var min_gap: int
	if PerformanceManager != null:
		min_gap = PerformanceManager.damage_number_min_gap_ms()
	else:
		min_gap = 33
	if not is_crit and now < _number_throttle_ms:
		return
	var number: Node3D = _acquire(DAMAGE_NUMBER_SCENE)
	if number != null and is_instance_valid(enemy):
		number.trigger(enemy.global_position, amount, is_crit)
		_number_throttle_ms = now + min_gap

func _on_enemy_died(enemy: Node, pos: Vector3) -> void:
	# V19: reduced-VFX skips kill bursts (damage numbers stay)
	if SaveManager != null and SaveManager.get_setting("reduced_vfx", false):
		return
	# P8: under heavy horde load, only burst every other kill
	if PerformanceManager != null and PerformanceManager.active_enemies >= 80:
		_burst_skip = not _burst_skip
		if _burst_skip:
			return
	var burst: Node3D = _acquire(KILL_BURST_SCENE)
	if burst != null:
		var color: Color = Color(1, 1, 1)
		if enemy != null and is_instance_valid(enemy) and enemy.get("data") != null:
			var ed: Resource = enemy.get("data")
			if ed != null and "color" in ed:
				color = ed.color
		burst.trigger(pos, color)

func _on_level_up(_level: int) -> void:
	if _player == null:
		return
	var burst: Node3D = _acquire(KILL_BURST_SCENE)
	if burst != null:
		burst.trigger(_player.global_position, Color(1.0, 0.85, 0.2))
	AudioManager.play_game_sfx("level_up")
