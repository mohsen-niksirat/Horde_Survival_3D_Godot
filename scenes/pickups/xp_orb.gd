extends Area3D
## XP orb: drops on enemy death, magnetizes toward the player inside pickup
## radius, collected on contact. Pooled. Supports a global soft magnet pulse
## (staggered wave pull over several seconds) from MagnetDrop pickups.

const GRAVITY := 18.0
const MAGNET_SPEED := 14.0
const LIFETIME := 30.0
const FAR_POLL_INTERVAL := 0.25
## Global magnet pulse travel: start slow, ease faster toward the end.
const PULSE_SPEED_START := 7.0
const PULSE_SPEED_END := 26.0

var value: float = 1.0
var _player: Node3D
var _magnetized: bool = false
var _life: float = 0.0
var _vertical_velocity: float = 0.0
var _settled: bool = false
var _far_poll: float = 0.0

var _pulse_left: float = 0.0
var _pulse_total: float = 1.0
var _pulse_stagger: float = 0.0
var _pulse_active: bool = false
var _wobble: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if EventBus != null and not EventBus.magnet_pulse.is_connected(_on_magnet_pulse):
		EventBus.magnet_pulse.connect(_on_magnet_pulse)

func setup(p_value: float, p_player: Node3D, spawn_pos: Vector3) -> void:
	value = p_value
	_player = p_player
	_magnetized = false
	_life = 0.0
	_settled = false
	_far_poll = 0.0
	_pulse_active = false
	_pulse_left = 0.0
	_pulse_stagger = 0.0
	_wobble = randf() * TAU
	_vertical_velocity = randf_range(2.5, 5.0)
	global_position = spawn_pos + Vector3(randf_range(-0.6, 0.6), 0.6, randf_range(-0.6, 0.6))
	set_deferred("monitoring", true)

func _on_magnet_pulse(duration: float) -> void:
	# Soft wave: farther shards wait a bit longer, then ease toward player
	_pulse_total = maxf(duration, 0.5)
	_pulse_left = _pulse_total
	_pulse_active = true
	_magnetized = false
	if _player != null and is_instance_valid(_player):
		var d: float = global_position.distance_to(_player.global_position)
		# 0–2.2s stagger by distance so the field "arrives" as a wave
		_pulse_stagger = clampf(d / 28.0, 0.0, 1.0) * 2.2
	else:
		_pulse_stagger = randf_range(0.0, 1.0)

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_life += delta
	if _life > LIFETIME:
		_deactivate()
		return

	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	var pickup_radius: float = 3.0
	if _player.has_method("get_pickup_radius"):
		pickup_radius = _player.get_pickup_radius()

	# Global magnet pulse (soft XP wave)
	if _pulse_active:
		_pulse_left -= delta
		if _pulse_stagger > 0.0:
			_pulse_stagger -= delta
		else:
			_magnetized = true
			var t := 1.0 - clampf(_pulse_left / _pulse_total, 0.0, 1.0)
			# Ease-in speed + slight swirl for a soft animation
			var speed := lerpf(PULSE_SPEED_START, PULSE_SPEED_END, t * t)
			var dir := to_player.normalized() if dist > 0.01 else Vector3.ZERO
			var swirl := Vector3.UP.cross(dir).normalized() * sin(_wobble + t * 6.0) * (1.0 - t) * 0.45
			var move := (dir + swirl)
			if move.length_squared() > 0.0001:
				move = move.normalized()
			global_position += move * speed * delta
			global_position.y = lerpf(global_position.y, 0.7, 4.0 * delta)
			if dist < 1.2:
				_collect()
				return
		if _pulse_left <= 0.0:
			_pulse_active = false
			# Keep normal magnet behavior if still near player
			if dist > pickup_radius + 2.0:
				_magnetized = false

	if _pulse_active:
		return  # pulse path already moved the orb this frame

	# LOD: settled + far from magnet → poll slowly
	if not _magnetized and _settled and dist > pickup_radius + 2.0:
		_far_poll -= delta
		if _far_poll > 0.0:
			return
		_far_poll = FAR_POLL_INTERVAL
		if dist > pickup_radius:
			return

	if _magnetized or dist <= pickup_radius:
		_magnetized = true
		var dir := to_player.normalized() if dist > 0.01 else Vector3.ZERO
		global_position += dir * MAGNET_SPEED * delta
		global_position.y = lerpf(global_position.y, 0.7, 6.0 * delta)
		if dist < 1.2:
			_collect()
	else:
		if not _settled:
			_vertical_velocity -= GRAVITY * delta
			global_position.y += _vertical_velocity * delta
			if global_position.y <= 0.45:
				global_position.y = 0.45
				_settled = true

func _collect() -> void:
	EventBus.xp_collected.emit(value)
	_deactivate()

func _deactivate() -> void:
	_pulse_active = false
	_magnetized = false
	set_deferred("monitoring", false)
	PoolManager.release(self)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_collect()
