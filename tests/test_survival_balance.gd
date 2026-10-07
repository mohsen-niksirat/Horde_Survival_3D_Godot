extends SceneTree
## Survival balance: hearts drop from EARLY enemies (bat/drone) and heal;
## bat damage/cooldown capped.

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
	main.get_node("HUD/TutorialOverlay")._finish()
	main.get_node("WaveManager").stop()
	em.clear_all()
	player.experience.xp_to_next = 999999.0

	# --- Hearts drop from a basic drone (xp=1.0) and heal 25 ---
	var drone: EnemyData = load("res://data/enemies/basic_drone.tres")
	player.health.take_damage(DamageEvent.new(40.0, "test"))
	var hp0: float = player.health.current_hp
	var hearts := 0
	# Force 100% heart drop rate during test for deterministic verification
	player.heart_drop_rate_override = 1.0
	for trial in range(5):
		em.clear_all()
		em.queue_spawn(drone, player.global_position + Vector3(2, 0, 2), player, 1.0, 1.0, 1.0)
		for i in range(4):
			await process_frame
			await physics_frame
		if em.enemy_count() == 0:
			continue
		var e: CharacterBody3D = em.get_all_enemies()[0]
		e.set_physics_process(false)
		e.health.take_damage(DamageEvent.new(9999.0, "test"))
		for i in range(3):
			await process_frame
			await physics_frame
		hearts += _count_hearts(main)
		for child in main.get_node("World").get_children():
			if child.name.contains("HeartPickup") and child.visible:
				player.global_position = child.global_position
				for f in range(5):
					await physics_frame
				hearts += 1
	player.heart_drop_rate_override = -1.0

	# count during the kill loop (hearts get collected/released as we go)
	_check(hearts > 0, "(pre-check) hearts dropped from early enemies (%d)" % hearts)
	# walk over all spawned hearts: collect them by touching
	var world: Node3D = main.get_node("World")
	for child in world.get_children():
		if child.name.contains("HeartPickup") and child.visible:
			hearts += 1
			player.global_position = child.global_position
			for f in range(5):
				await physics_frame
	_check(hearts > 0, "hearts dropped from early enemies (%d in test kills)" % hearts)
	_check(player.health.current_hp > hp0, "heart healed player (%.0f -> %.0f)" % [hp0, player.health.current_hp])

	# --- Bat balance caps ---
	var bat: EnemyData = load("res://data/enemies/swarm_bat.tres")
	_check(bat.damage <= 2.0, "bat damage <= 2 (%.1f)" % bat.damage)
	_check(bat.attack_cooldown >= 0.8, "bat attack cooldown >= 0.8 (%.1f)" % bat.attack_cooldown)
	_check(bat.move_speed <= 4.5, "bat speed <= 4.5 (slower than player 6.0)")

	if failures == 0:
		print("SURVIVAL_BALANCE_PASS")
	else:
		print("SURVIVAL_BALANCE_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1

func _count_hearts(main: Node) -> int:
	var n := 0
	for child in main.get_node("World").get_children():
		if child.name.contains("HeartPickup") and child.visible:
			n += 1
	return n