extends SceneTree
## V22A regression: dash must NOT auto-fire on movement alone.
## The old tick() polled try_dash(move_dir) every physics frame, so the dash
## triggered the instant the cooldown expired — no key press needed. This
## test asserts tick() only starts a dash when want_dash is true.

var failures := 0

func _initialize() -> void:
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame

	var player: CharacterBody3D = main.get_node("World/Player")
	var game_manager := root.get_node("GameManager")
	game_manager.state = game_manager.State.PLAYING
	var dash: Node = player.dash
	_check(dash != null, "DashComponent exists on player")
	dash.cooldown_left = 0.0
	dash.dash_time_left = 0.0

	# --- Moving alone must NOT start a dash ---
	var count0: int = dash.dash_count
	var moved := false
	# Simulate several physics frames of "moving forward, no dash press".
	for i in range(8):
		var dash_driven: bool = dash.tick(0.016, Vector3(0, 0, -1), false)
		moved = moved or dash_driven
	_check(dash.dash_count == count0, "no dash fires on movement alone (count=%d)" % dash.dash_count)
	_check(not moved, "movement tick is not dash-driven when want_dash=false")

	# --- Pressing the dash action DOES start it (the frame that calls
	# try_dash returns false — it only reports dash-driven once the burst is
	# in progress on the next tick) ---
	dash.tick(0.016, Vector3(0, 0, -1), true)
	_check(dash.dash_count == count0 + 1, "dash count increments on press")
	_check(dash.is_dashing(), "dash active after press")

	# Space must NOT trigger dash — the fullscreen button could be focused.
	var evs: Array = InputMap.action_get_events("dash")
	var keycodes: Array = []
	for ev in evs:
		if ev is InputEventKey:
			keycodes.append(ev.physical_keycode)
	_check(70 in keycodes, "dash bound to F (physical_keycode 70)")
	_check(not (32 in keycodes), "dash NOT bound to SPACE (32)")

	main.queue_free()
	await process_frame

	if failures == 0:
		print("V22A_DASH_INPUT_PASS")
	else:
		print("V22A_DASH_INPUT_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
