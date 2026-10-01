extends SceneTree
## Mouse-look rotation must be UNBOUNDED (pointer-locked relative motion),
## not limited by screen edges.

var failures := 0

func _initialize() -> void:
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(6):
		await process_frame
		await physics_frame

	var rig: Node3D = main.get_node("World/Player/CameraRig")
	var game_manager := root.get_node("GameManager")
	game_manager.state = game_manager.State.PLAYING

	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_RIGHT
	mb.pressed = true
	Input.parse_input_event(mb)
	await process_frame

	var yaw0: float = rig._yaw
	# Simulate large mouse motion: 20 events x 500px = far beyond one screen
	for i in range(20):
		var ev := InputEventMouseMotion.new()
		ev.relative = Vector2(-500, 0)
		Input.parse_input_event(ev)
		await process_frame
	var yaw1: float = rig._yaw
	var delta_yaw: float = absf(yaw1 - yaw0)
	_check(delta_yaw > 6.2831, "yaw exceeds 360 degrees (%.1f rad)" % delta_yaw)
	_check(delta_yaw > 12.0, "yaw accumulates unbounded (%.1f rad = %.1f turns)" % [delta_yaw, delta_yaw / 6.2831])

	# Pitch stays clamped while yaw runs free
	var ev2 := InputEventMouseMotion.new()
	ev2.relative = Vector2(0, 5000)
	Input.parse_input_event(ev2)
	await process_frame
	var pitch: float = rig._pitch
	_check(pitch <= deg_to_rad(rig.pitch_max_deg) + 0.001 and pitch >= deg_to_rad(rig.pitch_min_deg) - 0.001, "pitch clamped (%.2f rad)" % pitch)

	if failures == 0:
		print("MOUSE_LOOK_UNBOUNDED_PASS")
	else:
		print("MOUSE_LOOK_UNBOUNDED_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
