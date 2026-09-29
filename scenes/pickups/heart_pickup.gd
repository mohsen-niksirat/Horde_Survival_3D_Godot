extends Area3D
## HeartPickup: rare drop that heals the player on contact. Pooled.
## Now magnetized like XP shards and drawn as a red heart shape.

const GRAVITY := 18.0

var heal_amount: float = 20.0
var _player: Node3D
var _life: float = 0.0
var _vertical_velocity: float = 3.0
var _settled: bool = false

@onready var _mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Potion bottle drop instead of the sphere-trio heart.
	if _mesh.get_child_count() == 3:
		var rig := RigUtil.attach_glb(_mesh, "res://assets/models/weapons/potion.glb", 0.6, "PotionRig")
		if rig != null:
			_mesh.mesh = null
			for cname in ["LobeL", "LobeR", "Tip"]:
				var lobe := _mesh.get_node_or_null(cname)
				if lobe != null:
					lobe.visible = false

func setup(heal: float, p_player: Node3D, spawn_pos: Vector3) -> void:
	heal_amount = heal
	_player = p_player
	_life = 0.0
	_settled = false
	_vertical_velocity = 3.0
	global_position = spawn_pos + Vector3(randf_range(-0.5, 0.5), 0.8, randf_range(-0.5, 0.5))
	set_deferred("monitoring", true)

func _process(delta: float) -> void:
	_life += delta
	if _life > 25.0:
		PoolManager.release(self)
		return
	_mesh.rotation.y += 2.0 * delta
	if _player != null and is_instance_valid(_player):
		var to_p: Vector3 = _player.global_position - global_position
		to_p.y = 0.0
		var d := to_p.length()
		# S7: low-HP players pull hearts from farther away
		var magnet_range := 6.0
		if _player.health != null and _player.health.get_ratio() < 0.4:
			magnet_range = 14.0
		if d < magnet_range and d > 0.2:
			global_position += to_p.normalized() * 11.0 * delta
		if d < 1.4 and _player.health.is_alive():
			_player.health.heal(heal_amount)
			AudioManager.play_game_sfx("relic_pickup")
			EventBus.upgrade_applied.emit("Heart — HP restored")
			set_deferred("monitoring", false)
			PoolManager.release(self)
			return
	if not _settled:
		_vertical_velocity -= GRAVITY * delta
		global_position.y += _vertical_velocity * delta
		if global_position.y <= 0.5:
			global_position.y = 0.5
			_settled = true

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	body.health.heal(heal_amount)
	set_deferred("monitoring", false)
	PoolManager.release(self)
