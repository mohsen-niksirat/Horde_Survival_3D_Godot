extends Node
## Input abstraction. Gameplay code calls ONLY this manager — never Input directly
## for gameplay actions. Supports keyboard+mouse, gamepad, and touch (virtual joystick).
## Owns pointer capture/release so browser Pointer Lock never sticks after leaving play.

var _move_vector: Vector2 = Vector2.ZERO
var _look_delta: Vector2 = Vector2.ZERO
var _touch_move_vector: Vector2 = Vector2.ZERO
var _touch_look_delta: Vector2 = Vector2.ZERO
var _zoom_delta: float = 0.0

var _using_touch: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "Web":
		_install_web_pointer_release()

## Release mouse capture / browser Pointer Lock. Safe to call anytime.
func release_pointer() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("try{if(window.__hordePointerRelease)window.__hordePointerRelease();else if(document.exitPointerLock)document.exitPointerLock();}catch(e){}", true)

## Capture mouse for gameplay camera look (desktop only).
func capture_pointer() -> void:
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func is_pointer_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

## Shell + engine hooks: always drop Pointer Lock when the tab loses focus.
func _install_web_pointer_release() -> void:
	var js := """
	(function(){
		if (!window.__hordePointerRelease) {
			window.__hordePointerRelease = function(){
				try {
					if (document.exitPointerLock) document.exitPointerLock();
				} catch (e) {}
			};
		}
		window.__hordePointerRelease();
		if (!window.__hordePointerHooks) {
			window.__hordePointerHooks = true;
			document.addEventListener('visibilitychange', function(){
				if (document.hidden) window.__hordePointerRelease();
			});
			window.addEventListener('blur', function(){ window.__hordePointerRelease(); });
			window.addEventListener('pagehide', function(){ window.__hordePointerRelease(); });
			window.addEventListener('beforeunload', function(){ window.__hordePointerRelease(); });
		}
	})();
	"""
	JavaScriptBridge.eval(js, true)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, \
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST:
			release_pointer()
		NOTIFICATION_EXIT_TREE, NOTIFICATION_PREDELETE:
			release_pointer()

func _unhandled_input(event: InputEvent) -> void:
	# Works in menus and gameplay (autoload ALWAYS)
	if event.is_action_pressed("fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()

func set_touch_move_vector(vec: Vector2) -> void:
	_touch_move_vector = vec
	_using_touch = true

func set_touch_look_delta(delta: Vector2) -> void:
	# ACCUMULATE: multiple drag events can arrive within one frame
	_touch_look_delta += delta
	_using_touch = true

func clear_touch() -> void:
	_touch_move_vector = Vector2.ZERO
	_touch_look_delta = Vector2.ZERO
	_using_touch = false

func get_move_vector() -> Vector2:
	var vec := Vector2.ZERO
	vec.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	vec.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	vec += _touch_move_vector
	if vec.length() > 1.0:
		vec = vec.normalized()
	return vec

func get_look_delta() -> Vector2:
	return _touch_look_delta

func consume_look_delta() -> Vector2:
	var d := get_look_delta()
	_touch_look_delta = Vector2.ZERO
	return d

func add_zoom_delta(delta: float) -> void:
	_zoom_delta += delta

func consume_zoom_delta() -> float:
	var d := _zoom_delta
	_zoom_delta = 0.0
	return d

func is_action_pressed(action: String) -> bool:
	match action:
		"ability_1", "ability_2", "dash":
			return Input.is_action_pressed(action) or _touch_action_pressed(action)
		_:
			return Input.is_action_pressed(action)

func is_action_just_pressed(action: String) -> bool:
	match action:
		"ability_1", "ability_2", "dash":
			return Input.is_action_just_pressed(action) or _touch_action_just_pressed(action)
		_:
			return Input.is_action_just_pressed(action)

func _touch_action_pressed(_action: String) -> bool:
	return false

func _touch_action_just_pressed(_action: String) -> bool:
	return false

func is_pause_just_pressed() -> bool:
	return Input.is_action_just_pressed("pause")

func is_using_touch() -> bool:
	return _using_touch

func is_fullscreen_just_pressed() -> bool:
	return Input.is_action_just_pressed("fullscreen")

## Toggle windowed <-> fullscreen. Works on desktop and web (browser FS API).
func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	var going_fs := mode != DisplayServer.WINDOW_MODE_FULLSCREEN \
		and mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if going_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		if OS.get_name() == "Web":
			JavaScriptBridge.eval("try{if(!document.fullscreenElement&&document.documentElement.requestFullscreen)document.documentElement.requestFullscreen();}catch(e){}", true)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if OS.get_name() == "Web":
			JavaScriptBridge.eval("try{if(document.exitFullscreen)document.exitFullscreen();}catch(e){}", true)
	EventBus.settings_changed.emit()

func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
