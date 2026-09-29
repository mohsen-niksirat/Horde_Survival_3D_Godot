extends Node3D
## Third-person camera rig: yaw orbit, pitch clamp, spring-arm collision,
## manual zoom (scroll wheel / pinch) with optional movement-based dynamic
## zoom, and shake. Optimized for horde readability.

@export var target_path: NodePath
@export var min_distance: float = 4.0
@export var max_distance: float = 14.0
@export var height: float = 2.2
@export var pitch_min_deg: float = -70.0
@export var pitch_max_deg: float = -18.0
@export var default_pitch_deg: float = -38.0
@export var default_zoom: float = 0.45  # 0 = closest, 1 = farthest
@export var yaw_sensitivity: float = 0.0032
@export var pitch_sensitivity: float = 0.0028
## Touch look multiplier (separate tuning knob from desktop mouse).
@export var touch_look_multiplier: float = 1.0
@export var position_smoothing: float = 8.0
@export var zoom_speed: float = 3.0
@export var wheel_zoom_step: float = 0.1

@export var shake_enabled: bool = true

var _target: Node3D
var _yaw: float = 0.0
var _pitch: float
var _zoom: float
var _current_distance: float
var _shake_amount: float = 0.0
var _shake_decay: float = 6.0
## V15B intro camera: brief yaw ease toward a world point (boss entrance).
var _look_target_yaw: float = NAN
var _look_blend: float = 0.0
var _yaw_sensitivity_base: float = 0.0032
var _pitch_sensitivity_base: float = 0.0028
## True on touch devices: mouse motion is EMULATED by touches there and
## jumps between fingers — camera look must come only from InputManager.
var _touch_mode: bool = false

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D

func _ready() -> void:
	# Detach from the player's transform: the character body rotates to face
	# its movement direction — the camera must NOT inherit that rotation.
	top_level = true
	_touch_mode = DisplayServer.is_touchscreen_available()
	var sens: float = SaveManager.get_setting("look_sensitivity", 1.0)
	touch_look_multiplier = SaveManager.get_setting("touch_sensitivity", 1.0)
	_yaw_sensitivity_base = yaw_sensitivity
	_pitch_sensitivity_base = pitch_sensitivity
	yaw_sensitivity *= sens
	pitch_sensitivity *= sens
	_pitch = deg_to_rad(default_pitch_deg)
	_zoom = clampf(default_zoom, 0.0, 1.0)
	_current_distance = _target_distance()
	_spring_arm.spring_length = _current_distance
	if target_path != NodePath():
		_target = get_node(target_path)
	if _target:
		global_position = _target.global_position + Vector3(0, height, 0)

func set_target(target: Node3D) -> void:
	_target = target
	if _target:
		global_position = _target.global_position + Vector3(0, height, 0)

func _unhandled_input(event: InputEvent) -> void:
	# Desktop: plain mouse movement rotates the camera (pointer-locked).
	# Touch devices: mouse motion is EMULATED from touches and jumps when
	# fingers land/lift — ignore it there; look comes from InputManager only.
	if _touch_mode:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom = clampf(_zoom - wheel_zoom_step, 0.0, 1.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = clampf(_zoom + wheel_zoom_step, 0.0, 1.0)
		return
	if event is InputEventMouseMotion:
		# Look only when RMB held (cursor stays free for UI buttons)
		if not InputManager.is_look_active():
			return
		_yaw -= event.relative.x * yaw_sensitivity
		_pitch -= event.relative.y * pitch_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - wheel_zoom_step, 0.0, 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + wheel_zoom_step, 0.0, 1.0)

func _target_distance() -> float:
	return lerpf(min_distance, max_distance, _zoom)

func _process(delta: float) -> void:
	if _target == null:
		return

	# Touch look — consumed so each drag delta applies exactly once
	var look := InputManager.consume_look_delta() * touch_look_multiplier
	if look.length_squared() > 0.01:
		_yaw -= look.x * yaw_sensitivity
		_pitch -= look.y * pitch_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))

	# Manual zoom (scroll handled above; pinch arrives via InputManager)
	var pinch := InputManager.consume_zoom_delta()
	if pinch != 0.0:
		_zoom = clampf(_zoom + pinch, 0.0, 1.0)

	# Follow target smoothly (flat + height)
	var goal := _target.global_position + Vector3(0, height, 0)
	global_position = global_position.lerp(goal, 1.0 - exp(-position_smoothing * delta))

	# Camera distance changes ONLY from user zoom input — nothing else
	_current_distance = lerpf(_current_distance, _target_distance(), 1.0 - exp(-zoom_speed * delta))
	_spring_arm.spring_length = _current_distance

	# Apply orbit
	rotation = Vector3(0, _yaw, 0)
	_spring_arm.rotation.x = _pitch

	# V15B: soft yaw ease toward a look target (boss intro), then release
	if not is_nan(_look_target_yaw):
		_yaw = lerp_angle(_yaw, _look_target_yaw, 1.0 - exp(-4.5 * delta))
		_look_blend -= delta
		if _look_blend <= 0.0:
			_look_target_yaw = NAN

	# Shake
	if _shake_amount > 0.001:
		_camera.h_offset = randf_range(-1, 1) * _shake_amount
		_camera.v_offset = randf_range(-1, 1) * _shake_amount
		_shake_amount = maxf(0.0, _shake_amount - _shake_amount * _shake_decay * delta)
	else:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0

func add_shake(amount: float) -> void:
	if not shake_enabled or not SaveManager.get_setting("screen_shake", true):
		return
	_shake_amount = minf(_shake_amount + amount, 0.6)

## V15B: ease the orbit yaw toward a world point for a short intro beat.
func look_at_world_point(point: Vector3, hold_seconds: float = 1.2) -> void:
	if _target == null:
		return
	var to := point - global_position
	to.y = 0.0
	if to.length_squared() < 0.01:
		return
	_look_target_yaw = atan2(-to.x, -to.z)
	_look_blend = maxf(hold_seconds, 0.1)

func get_move_basis() -> Basis:
	# Camera-relative movement basis (yaw only, flattened)
	return Basis(Vector3.UP, _yaw)

func get_yaw() -> float:
	return _yaw
