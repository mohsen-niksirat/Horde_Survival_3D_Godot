extends Area3D
## XP orb: drops on enemy death, magnetizes toward the player inside pickup
## radius, collected on contact. Pooled. Far/settled orbs poll at a lower
## rate so 100+ shards don't cost a full _process each.

const GRAVITY := 18.0
const MAGNET_SPEED := 14.0
const LIFETIME := 30.0
## How often far settled orbs re-check magnet range (seconds).
const FAR_POLL_INTERVAL := 0.25

var value: float = 1.0
var _player: Node3D
var _magnetized: bool = false
var _life: float = 0.0
var _vertical_velocity: float = 0.0
var _settled: bool = false
var _far_poll: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(p_value: float, p_player: Node3D, spawn_pos: Vector3) -> void:
	value = p_value
	_player = p_player
	_magnetized = false
	_life = 0.0
	_settled = false
	_far_poll = 0.0
	_vertical_velocity = randf_range(2.5, 5.0)
	global_position = spawn_pos + Vector3(randf_range(-0.6, 0.6), 0.6, randf_range(-0.6, 0.6))
	set_deferred("monitoring", true)

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_life += delta
	if _life > LIFETIME:
		PoolManager.release(self)
		return

	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	var pickup_radius: float = 3.0
	if _player.has_method("get_pickup_radius"):
		pickup_radius = _player.get_pickup_radius()

	# LOD: settled + far from magnet → poll slowly
	if not _magnetized and _settled and dist > pickup_radius + 2.0:
		_far_poll -= delta
		if _far_poll > 0.0:
			return
		_far_poll = FAR_POLL_INTERVAL
		# Re-check magnet after poll; fall through if still far
		if dist > pickup_radius:
			return

	if _magnetized or dist <= pickup_radius:
		_magnetized = true
		var dir := to_player.normalized() if dist > 0.01 else Vector3.ZERO
		global_position += dir * MAGNET_SPEED * delta
		global_position.y = lerpf(global_position.y, 0.7, 6.0 * delta)
	else:
		if not _settled:
			_vertical_velocity -= GRAVITY * delta
			global_position.y += _vertical_velocity * delta
			if global_position.y <= 0.45:
				global_position.y = 0.45
				_settled = true

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		EventBus.xp_collected.emit(value)
		set_deferred("monitoring", false)
		PoolManager.release(self)
