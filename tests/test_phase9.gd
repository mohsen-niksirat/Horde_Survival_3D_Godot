extends SceneTree
## Phase 9 test: evolutions, relics, pet, abilities, combo, achievements,
## meta save on game over.

const EliteAbilityC = preload("res://scripts/enemies/elite_ability.gd")

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
	var game_manager = root.get_node("GameManager")
	game_manager.state = game_manager.State.PLAYING
	main.get_node("WaveManager").stop()
	em.clear_all()
	# Prevent level-ups (XP orbs from test kills) from pausing the game
	player.experience.xp_to_next = 999999.0
	player.experience.current_xp = 0.0

	# --- Combo: kills within window chain, multiplier applies ---
	var combo: Node = main.combo_manager
	_check(combo != null, "combo manager exists")
	var drone: EnemyData = load("res://data/enemies/basic_drone.tres")
	for offset in [Vector3(5, 0, 0), Vector3(6, 0, 0), Vector3(7, 0, 0)]:
		em.queue_spawn(drone, player.global_position + offset, player, 1.0, 1.0, 1.0)
	for i in range(4):
		await process_frame
		await physics_frame
	for e in em.active_enemies.duplicate():
		e.health.take_damage(DamageEvent.new(9999.0, "test"))
	await process_frame
	_check(combo.count == 3, "combo counts 3 kills (got %d)" % combo.count)
	_check(absf(combo.get_multiplier() - 1.0) < 0.01, "multiplier 1.0 below 5 kills (%.2f)" % combo.get_multiplier())
	# Push to 6 kills: multiplier steps to 1.1
	for offset in [Vector3(9, 0, 0), Vector3(10, 0, 0), Vector3(11, 0, 0)]:
		em.queue_spawn(drone, player.global_position + offset, player, 1.0, 1.0, 1.0)
	for i in range(4):
		await process_frame
		await physics_frame
	for e in em.active_enemies.duplicate():
		e.health.take_damage(DamageEvent.new(9999.0, "test"))
	await process_frame
	_check(combo.count == 6, "combo counts 6 kills (got %d)" % combo.count)
	_check(absf(combo.get_multiplier() - 1.1) < 0.01, "multiplier 1.1 at 6 kills (%.2f)" % combo.get_multiplier())
	combo.reset()
	# Let the pool's deferred-release queue flush BEFORE clearing/reusing nodes
	await process_frame
	await process_frame
	em.clear_all()
	# Disable auto-fire AND purge in-flight projectiles so targets survive
	player.weapon_controller.weapons.clear()
	_purge_projectiles(main)

	# --- Abilities: meteor strike damages + time freeze stops enemies ---
	var ac: Node = main.ability_controller
	_check(ac.abilities.size() == 2, "2 abilities registered")
	em.queue_spawn(drone, player.global_position + Vector3(4, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(6):
		await process_frame
		await physics_frame
	if em.enemy_count() == 0:
		print("DEBUG: spawn failed, paused=", paused, " state=", game_manager.state, " alive=", player.health.is_alive())
		print("DEBUG: queue=", em._spawn_queue.size(), " pool free=", root.get_node("PoolManager")._pools.size())
		print("PHASE9_TEST_FAIL: target spawn failed")
		quit(1)
		return
	var target: CharacterBody3D = em.get_all_enemies()[0]
	var hp0: float = target.health.current_hp
	ac._execute(load("res://data/abilities/meteor_strike.tres"))
	await process_frame
	_check(target.health.current_hp < hp0, "meteor strike damaged enemy")
	# Fresh target for freeze (meteor may have killed the first)
	em.clear_all()
	em.queue_spawn(drone, player.global_position + Vector3(4, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(4):
		await process_frame
		await physics_frame
	target = em.get_all_enemies()[0]
	ac._execute(load("res://data/abilities/time_freeze.tres"))
	_check(target.status.has_effect("freeze"), "time freeze applied")
	_check(target.status.get_speed_factor() == 0.0, "frozen enemy speed 0")
	em.clear_all()

	# --- Evolution availability: fireball L5 + spinach maxed ---
	var prog: Node = main.progression
	player.weapon_controller.weapons.clear()
	player.weapon_controller.add_weapon(load("res://data/weapons/fireball.tres"))
	player.weapon_controller.weapons[0].level = 5
	prog.passive_levels["spinach"] = 5
	var evo: EvolutionData = EvolutionData.is_available(prog.evolutions, player.weapon_controller, prog.passive_levels)
	_check(evo != null, "hellfire evolution available")
	if evo != null:
		_check(evo.id == "hellfire", "evolution is hellfire")
		var w = player.weapon_controller.weapons[0]
		w.data = evo.evolved_weapon
		w.evolved = true
		_check(player.weapon_controller.weapons[0].data.id == "hellfire", "weapon evolved to hellfire")
		_check(player.weapon_controller.weapons[0].data.status_effect == "burn", "hellfire burns")

	# --- Relic system: spawn + apply ---
	var relics: Node = main.relic_system
	_check(relics._pool.size() == 6, "6 relics loaded (got %d)" % relics._pool.size())
	var might_before: float = player.get_stat("might")
	relics.apply_relic(load("res://data/relics/ring.tres"))
	_check(absf(player.get_stat("might") - (might_before + 0.15)) < 0.001, "ring relic +15%% might")

	# --- Pet exists and follows ---
	var pet: Node3D = null
	for child in main.get_children():
		if child.name.begins_with("Pet") or (child.get_script() != null and child.get_script().resource_path.contains("pet")):
			pet = child
	_check(pet != null, "pet spawned")

	# --- Achievements: first kill unlock persists ---
	var ach: Node = null
	for child in main.get_children():
		if child.name == "AchievementSystem":
			ach = child
	_check(ach != null, "achievement system exists")
	_purge_projectiles(main)
	var save_manager = root.get_node("SaveManager")
	save_manager.set_meta_data("achievements", {})
	save_manager.set_meta_data("total_kills", 0)
	ach.unlocked = {}
	em.queue_spawn(drone, player.global_position + Vector3(3, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(4):
		await process_frame
		await physics_frame
	em.get_all_enemies()[0].health.take_damage(DamageEvent.new(9999.0, "test"))
	await process_frame
	root.get_node("EventBus").run_ended.emit(false)
	_check(save_manager.get_meta_data("total_kills", 0) >= 1, "kill persisted at run end")
	_check(save_manager.get_meta_data("achievements", {}).has("kill_1"), "First Blood unlocked")

	if failures == 0:
		print("PHASE9_TEST_PASS")
	else:
		print("PHASE9_TEST_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1

func _purge_projectiles(main: Node) -> void:
	# Remove lingering projectiles (in-flight fireballs etc.) so test spawns
	# aren't killed by stray hits from previous test sections.
	var proj_root: Node3D = main.get_node_or_null("Projectiles")
	if proj_root == null:
		return
	for proj in proj_root.get_children():
		proj.visible = false
		proj.set("monitoring", false)
		proj.queue_free()
