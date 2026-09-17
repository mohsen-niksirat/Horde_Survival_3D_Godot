extends SceneTree
## Magnet soft pulse + fullscreen API smoke.

var failures := 0

func _initialize() -> void:
	var bus = root.get_node("EventBus")
	_check(bus != null and bus.has_signal("magnet_pulse"), "EventBus has magnet_pulse")
	var im = root.get_node("InputManager")
	_check(im.has_method("toggle_fullscreen"), "InputManager.toggle_fullscreen exists")
	_check(im.has_method("is_fullscreen"), "InputManager.is_fullscreen exists")
	_check(InputMap.has_action("fullscreen"), "fullscreen input action mapped")

	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame
	var fs_btn: Button = main.get_node_or_null("HUD/Hud/Abilities/ZoomRow/Fullscreen")
	_check(fs_btn != null, "HUD fullscreen button exists")
	var player: CharacterBody3D = main.get_node("World/Player")
	var world = main.get_node("World")
	var em = main.get_node("EnemyManager")
	main.get_node("WaveManager").stop()
	em.clear_all()
	player.weapon_controller.weapons.clear()

	player.experience.xp_to_next = 999999.0
	player.experience.current_xp = 0.0
	var pool = root.get_node("PoolManager")
	var orb: Node3D = pool.acquire("res://scenes/pickups/XpOrb.tscn")
	pool.tag(orb, "res://scenes/pickups/XpOrb.tscn")
	world.add_child(orb)
	# Close enough that stagger is short but not instant pickup
	orb.setup(5.0, player, player.global_position + Vector3(10, 0, 10))
	await process_frame
	bus.magnet_pulse.emit(5.0)
	await process_frame
	_check(player.experience.current_xp < 5.0, "XP not instantly granted on pulse")
	var moved := false
	var start_pos: Vector3 = orb.global_position
	for i in range(180):
		await process_frame
		await physics_frame
		if not is_instance_valid(orb):
			moved = true
			break
		if orb.global_position.distance_to(start_pos) > 0.8:
			moved = true
			break
		if player.experience.current_xp >= 5.0:
			moved = true
			break
	_check(moved, "orb moved toward player during pulse")
	if is_instance_valid(orb):
		pool.release(orb)

	if failures == 0:
		print("MAGNET_FS_PASS")
	else:
		print("MAGNET_FS_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
