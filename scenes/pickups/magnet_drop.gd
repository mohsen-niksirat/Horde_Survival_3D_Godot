extends Area3D
## MagnetDrop: horseshoe magnet pickup. On contact, XP shards on the map
## start a soft ~5s wave toward the player (not an instant vacuum).

const GRAVITY := 18.0
## Global XP pull duration after pickup.
const PULSE_DURATION := 5.0

var _player: Node3D
var _life: float = 0.0
var _vertical_velocity: float = 3.0
var _settled: bool = false
var _mesh: Node3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_mesh = $Mesh

func setup(p_player: Node3D, spawn_pos: Vector3) -> void:
	_player = p_player
	_life = 0.0
	_settled = false
	_vertical_velocity = 3.0
	global_position = spawn_pos + Vector3(randf_range(-0.5, 0.5), 0.8, randf_range(-0.5, 0.5))
	if _mesh != null:
		_mesh.rotation.y = randf() * TAU
	set_deferred("monitoring", true)

func _process(delta: float) -> void:
	_life += delta
	if _life > 30.0:
		PoolManager.release(self)
		return
	if _mesh != null:
		_mesh.rotation.y += 2.2 * delta
	if not _settled:
		_vertical_velocity -= GRAVITY * delta
		global_position.y += _vertical_velocity * delta
		if global_position.y <= 0.5:
			global_position.y = 0.5
			_settled = true

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	set_deferred("monitoring", false)
	# Soft XP wave: orbs stagger + ease toward the player for PULSE_DURATION
	EventBus.magnet_pulse.emit(PULSE_DURATION)
	AudioManager.play_game_sfx("xp_pickup")
	PoolManager.release(self)
