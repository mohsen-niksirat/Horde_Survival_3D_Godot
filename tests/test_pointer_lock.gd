extends SceneTree
## Pointer lock policy: capture only in PLAYING/BOSS; release everywhere else.

var failures := 0

func _initialize() -> void:
	var gm = root.get_node("GameManager")
	var im = root.get_node("InputManager")
	_check(im != null and im.has_method("release_pointer"), "InputManager has release_pointer")
	_check(im.has_method("capture_pointer"), "InputManager has capture_pointer")

	# Menu / pause / game over must release
	gm.change_state(gm.State.MAIN_MENU)
	_check(not im.is_pointer_captured(), "MAIN_MENU releases pointer")
	gm.change_state(gm.State.PAUSED)
	_check(not im.is_pointer_captured(), "PAUSED releases pointer")
	gm.change_state(gm.State.GAME_OVER)
	_check(not im.is_pointer_captured(), "GAME_OVER releases pointer")
	gm.change_state(gm.State.LEVEL_UP)
	_check(not im.is_pointer_captured(), "LEVEL_UP releases pointer")

	# Headless: capture may no-op on some drivers — but API must not crash
	gm.change_state(gm.State.PLAYING)
	im.capture_pointer()
	gm.change_state(gm.State.MAIN_MENU)
	# After leaving play, self-heal path (Main._process) also releases
	_check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or OS.get_name() == "headless",
		"pointer not stuck captured after menu (mode=%d)" % Input.mouse_mode)

	if failures == 0:
		print("POINTER_LOCK_PASS")
	else:
		print("POINTER_LOCK_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
