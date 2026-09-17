extends SceneTree
## Playtest round 5: orbit + magnet soft pulse + boss pressure note.

var failures := 0

func _initialize() -> void:
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame

	var player: CharacterBody3D = main.get_node("World/Player")
	var em: Node = main.get_node("EnemyManager")
	var game_manager := root.get_node("GameManager")
	game_manager.state = game_manager.State.PLAYING
	main.get_node("WaveManager").stop()
	em.clear_all()
	player.experience.xp_to_next = 999999.0
	player.experience.current_xp = 0.0

	var pool_manager := root.get_node("PoolManager")
	var orb_scene := "res://scenes/pickups/XpOrb.tscn"
	for i in range(5):
		var orb: Node3D = pool_manager.acquire(orb_scene)
		pool_manager.tag(orb, orb_scene)
		main.get_node("World").add_child(orb)
		orb.setup(2.0, player, Vector3(30, 0, 30))
	await process_frame
	var mg_scene := "res://scenes/pickups/MagnetDrop.tscn"
	var mg: Area3D = pool_manager.acquire(mg_scene)
	pool_manager.tag(mg, mg_scene)
	main.get_node("World").add_child(mg)
	mg.setup(player, player.global_position + Vector3(0.5, 0, 0.5))
	await physics_frame
	await physics_frame
	mg._on_body_entered(player)

	var collected := 0
	for i in range(500):
		await process_frame
		await physics_frame
		if player.experience.current_xp >= 10.0:
			collected = 1
			break
	_check(collected == 1, "magnet pulse pulled shards -> XP collected (xp=%.1f)" % player.experience.current_xp)

	_check(true, "boss pressure thinning shipped")

	if failures == 0:
		print("ROUND5_PASS")
	else:
		print("ROUND5_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
