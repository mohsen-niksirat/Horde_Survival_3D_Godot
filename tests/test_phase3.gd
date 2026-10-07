extends SceneTree
## Phase 3 test: enemy spawn via EnemyManager, chase, contact damage,
## death, XP drop, orb magnet + collection, pool recycling.

var failures := 0

func _initialize() -> void:
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player: CharacterBody3D = main.get_node("World/Player")
	var em: Node = main.get_node("EnemyManager")
	var game_manager := root.get_node("GameManager")
	game_manager.state = game_manager.State.PLAYING

	# Phase 4+ gives the player an auto-firing fireball; clear it so the
	# enemy survives for the contact-damage portion of this test.
	player.weapon_controller.weapons.clear()
	# Also stop horde spawning for determinism.
	main.get_node("WaveManager").stop()
	em.clear_all()

	# --- Spawn an enemy near the player ---
	var drone: EnemyData = load("res://data/enemies/basic_drone.tres")
	_check(drone != null, "basic_drone resource loads")
	em.queue_spawn(drone, player.global_position + Vector3(8, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(4):
		await process_frame
		await physics_frame
	_check(em.enemy_count() == 1, "enemy spawned (count=%d)" % em.enemy_count())
	if em.enemy_count() == 0:
		print("PHASE3_TEST_FAIL: spawn never happened")
		quit(1)
		return
	var enemy: CharacterBody3D = em.get_all_enemies()[0]
	_check(is_instance_valid(enemy), "enemy valid")

	# --- Enemy chases player: distance shrinks ---
	var d0: float = enemy.global_position.distance_to(player.global_position)
	for i in range(60):
		await physics_frame
	var d1: float = enemy.global_position.distance_to(player.global_position)
	_check(d1 < d0, "enemy approaches player (%.2f -> %.2f)" % [d0, d1])

	# --- Contact damage: player HP drops ---
	for i in range(120):
		await physics_frame
		if player.health.current_hp < 100.0:
			break
	_check(player.health.current_hp < 100.0, "player took contact damage (hp=%.1f)" % player.health.current_hp)

	# Position player within magnet range (3.5m) so orbs drop and are visible
	# before being immediately collected.
	var drop_pos: Vector3 = enemy.global_position
	player.global_position = drop_pos + Vector3(3.5, 0, 0)
	var run_manager := root.get_node("RunManager")
	var kills_before: int = run_manager.kills
	var xp_before: float = player.experience.current_xp
	# Direct damage via health component
	var dmg := DamageEvent.new(9999.0, "test")
	enemy.health.take_damage(dmg)
	await physics_frame
	await physics_frame
	_check(not em.active_enemies.has(enemy), "enemy released after death")
	_check(run_manager.kills == kills_before + 1, "kill registered (kills=%d)" % run_manager.kills)

	# Orbs should exist in the pickups container (or have been collected)
	var orbs := 0
	for child in main.get_node("World").get_children():
		if child.name.begins_with("XpOrb") or child.get_script() == load("res://scenes/pickups/xp_orb.gd"):
			orbs += 1
	_check(orbs >= 1 or player.experience.current_xp > xp_before, "xp orbs dropped (%d)" % orbs)

	# --- XP collection: move player to dropped position to collect ---
	player.global_position = drop_pos
	for i in range(60):
		await physics_frame
		if player.experience.current_xp > xp_before:
			break
	_check(player.experience.current_xp > xp_before, "xp collected (%.1f -> %.1f)" % [xp_before, player.experience.current_xp])

	# --- Pool stats sanity ---
	var pool_manager := root.get_node("PoolManager")
	var stats: Dictionary = pool_manager.get_pool_stats("res://scenes/enemies/Enemy.tscn")
	_check(stats.get("created", 0) >= 1, "enemy pool tracks creation")

	if failures == 0:
		print("PHASE3_TEST_PASS")
	else:
		print("PHASE3_TEST_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
