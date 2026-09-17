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

func setup(player: Node3D) -> void:
	_player = player
	for scene_path in POOL_SIZES:
		if ResourceLoader.exists(scene_path):
			var scene: PackedScene = load(scene_path)
			var base_name: String = scene_path.get_file().get_basename()
			for i in range(POOL_SIZES[scene_path]):
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
	var idx: int = _indices.get(scene_path, 0)
	_indices[scene_path] = (idx + 1) % pool.size()
	return pool[idx]

func _on_enemy_damaged(enemy: Node, amount: float, is_crit: bool) -> void:
	var now := Time.get_ticks_msec()
	var cap: int = PerformanceManager.damage_number_cap() if PerformanceManager != null else 30
	var min_gap := maxi(16, int(1000.0 / maxf(float(cap), 1.0)))
	if not is_crit and now < _number_throttle_ms:
		return
	var number: Node3D = _acquire(DAMAGE_NUMBER_SCENE)
	if number != null and is_instance_valid(enemy):
		number.trigger(enemy.global_position, amount, is_crit)
		_number_throttle_ms = now + min_gap

func _on_enemy_died(enemy: Node, pos: Vector3) -> void:
	var burst: Node3D = _acquire(KILL_BURST_SCENE)
	if burst != null:
		var color: Color = Color(1, 1, 1)
		if enemy.get("data") != null:
			color = enemy.data.color
		burst.trigger(pos, color)

func _on_level_up(_level: int) -> void:
	if _player == null:
		return
	var burst: Node3D = _acquire(KILL_BURST_SCENE)
	if burst != null:
		burst.trigger(_player.global_position, Color(1.0, 0.85, 0.2))
	AudioManager.play_game_sfx("level_up")
