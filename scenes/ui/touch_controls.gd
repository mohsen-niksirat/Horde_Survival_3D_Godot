extends Control
## CoD-style mobile touch controls with visible rings:
## - Left half: floating movement ring wherever touched (knob stretches)
## - Right half: camera look ring — independent of movement
## - Zoom +/− buttons (bottom right)
## Rings are drawn by a child TouchIndicator (Node2D) fed on every event.

const RING_RADIUS := 110.0
const DEAD_ZONE := 0.12
const BUTTON_ZOOM_STEP := 0.18

@onready var zoom_in: Button = $ZoomIn
@onready var zoom_out: Button = $ZoomOut
@onready var indicator: Control = $Indicator

var _joy_index: int = -1
var _joy_center: Vector2 = Vector2.ZERO
var _look_index: int = -1
var _look_center: Vector2 = Vector2.ZERO
var _look_last: Vector2 = Vector2.ZERO

func _ready() -> void:
	visible = false
	if DisplayServer.is_touchscreen_available():
		visible = true
	# While paused we ignore gameplay input via _input (only buttons keep working
	# through their own GUI event handling, which does not depend on _input).
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.game_state_changed.connect(_on_game_state_changed)
	zoom_in.pressed.connect(func(): InputManager.add_zoom_delta(-BUTTON_ZOOM_STEP))
	zoom_out.pressed.connect(func(): InputManager.add_zoom_delta(BUTTON_ZOOM_STEP))

func _on_game_state_changed(new_state: int, _old: int) -> void:
	if new_state != GameManager.State.PLAYING and new_state != GameManager.State.BOSS:
		_joy_index = -1
		_look_index = -1
		InputManager.set_touch_move_vector(Vector2.ZERO)
		InputManager.set_touch_look_delta(Vector2.ZERO)
		_push_indicator()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# While paused / in menus, swallow gameplay touch so deltas don't accumulate.
	if GameManager.state != GameManager.State.PLAYING and GameManager.state != GameManager.State.BOSS:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var half := get_viewport_rect().size.x * 0.5
		if _joy_index == -1 and event.position.x < half:
			_joy_index = event.index
			_joy_center = event.position
		elif _look_index == -1 and event.position.x >= half:
			_look_index = event.index
			_look_center = event.position
			_look_last = event.position
	else:
		if event.index == _joy_index:
			_joy_index = -1
			InputManager.set_touch_move_vector(Vector2.ZERO)
		elif event.index == _look_index:
			_look_index = -1
	_push_indicator()

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joy_index:
		var offset: Vector2 = event.position - _joy_center
		if offset.length() > RING_RADIUS:
			offset = offset.normalized() * RING_RADIUS
		var vec := offset / RING_RADIUS
		if vec.length() < DEAD_ZONE:
			vec = Vector2.ZERO
		else:
			vec = (vec - vec.normalized() * DEAD_ZONE) / (1.0 - DEAD_ZONE)
		InputManager.set_touch_move_vector(Vector2(vec.x, vec.y))
	elif event.index == _look_index:
		InputManager.set_touch_look_delta(event.position - _look_last)
		_look_last = event.position
	_push_indicator()

func _push_indicator() -> void:
	var joy_knob := _joy_center
	if _joy_index != -1:
		var offset: Vector2 = InputManager.get_move_vector() * RING_RADIUS
		joy_knob = _joy_center + offset
	var look_knob := _look_center
	if _look_index != -1:
		var to_look: Vector2 = _look_last - _look_center
		look_knob = _look_center + to_look.limit_length(RING_RADIUS - 42.0)
	indicator.update_rings(
		_joy_index != -1, _joy_center, joy_knob,
		_look_index != -1, _look_center, look_knob
	)
