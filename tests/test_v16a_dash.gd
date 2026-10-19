extends SceneTree
## V16A validation: dash component — burst movement, i-frames, cooldown,
## HUD indicator, dash SFX preset, and re-trigger after cooldown.

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

	# --- Dash starts along a world direction ---
	var started: bool = dash.try_dash(Vector3(0, 0, -1))
	_check(started, "dash starts on request")
	_check(dash.is_dashing(), "dash active right after start")
	_check(absf(dash.get_cooldown_ratio() - 1.0) < 0.01, "cooldown full right after dash")

	# --- Burst actually moves the body ---
	var pos0: Vector3 = player.global_position
	for i in range(6):
		await physics_frame
	var moved: float = (player.global_position - pos0).length()
	_check(moved > 1.0, "dash moved the player (%.2f m over 6 physics frames)" % moved)

	# --- i-frames: contact damage ignored during the dash window ---
	var hp0: float = player.health.current_hp
	player.take_contact_damage(25.0, player.global_position + Vector3(1, 0, 0))
	_check(absf(player.health.current_hp - hp0) < 0.01, "i-frames block contact damage during dash")

	# --- i-frames expire: damage lands again ---
	await create_timer(0.4).timeout
	player.take_contact_damage(25.0, player.global_position + Vector3(1, 0, 0))
	_check(player.health.current_hp < hp0 - 1.0, "contact damage lands after i-frames expire")

	# --- second dash blocked while cooling down ---
	var blocked: bool = dash.try_dash(Vector3(0, 0, -1))
	_check(not blocked, "dash blocked during cooldown")

	# --- burst ends on its own ---
	_check(not dash.is_dashing(), "dash burst ended after DASH_TIME")

	# --- HUD indicator exists and SFX preset is registered ---
	var hud: Control = main.get_node("HUD/Hud")
	var dash_btn: Button = hud.get_node_or_null("AbilityPanel/AbilityCol/DashButton")
	_check(dash_btn != null, "HUD dash button exists")
	var audio := root.get_node("AudioManager")
	_check(audio.SFX_IMPORTANCE.has("dash"), "dash SFX preset registered")
	audio.play_game_sfx("dash")

	# --- re-trigger works once the cooldown is cleared ---
	var count0: int = dash.dash_count
	dash.cooldown_left = 0.0
	var again: bool = dash.try_dash(Vector3(1, 0, 0))
	_check(again and dash.dash_count == count0 + 1, "dash re-triggers after cooldown")

	if failures == 0:
		print("V16A_DASH_PASS")
	else:
		print("V16A_DASH_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
