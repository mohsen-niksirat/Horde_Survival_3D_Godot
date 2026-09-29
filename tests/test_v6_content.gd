extends SceneTree
## V6 validation: 4 new archetypes behave (ghost phases, splitter splits,
## healer heals, mage volleys) and all 5 evolutions exist + resolve.

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
	player.weapon_controller.weapons.clear()
	var orbit_root: Node3D = player.get_node_or_null("OrbitRoot")
	if orbit_root != null:
		orbit_root.queue_free()
	player.experience.xp_to_next = 999999.0

	# --- Ghost phases (untargetable during window) ---
	em.queue_spawn(load("res://data/enemies/ghost.tres"), player.global_position + Vector3(8, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(5):
		await process_frame
		await physics_frame
	var ghost: CharacterBody3D = em.get_all_enemies()[0]
	ghost.set_physics_process(false)
	ghost._phase_timer = 0.0
	ghost._set_phasing_alpha(true)
	_check(ghost._is_phasing(), "ghost phases on timer")
	_check(ghost._flash_materials[0].albedo_color.a < 0.6, "phasing ghost shimmers")
	ghost._phase_timer = 3.0
	ghost._set_phasing_alpha(false)
	_check(not ghost._is_phasing(), "ghost solid between phases")
	ghost.set_physics_process(true)
	em.clear_all()

	# --- Splitter spawns 2 children on death ---
	em.queue_spawn(load("res://data/enemies/splitter.tres"), player.global_position + Vector3(6, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(5):
		await process_frame
		await physics_frame
	var splitter: CharacterBody3D = em.get_all_enemies()[0]
	splitter.health.take_damage(DamageEvent.new(9999.0, "test"))
	for i in range(8):
		await process_frame
		await physics_frame
	_check(em.enemy_count() == 2, "splitter left 2 children (%d)" % em.enemy_count())
	em.clear_all()

	# --- Healer heals a damaged ally nearby ---
	em.queue_spawn(load("res://data/enemies/healer.tres"), player.global_position + Vector3(10, 0, 0), player, 1.0, 1.0, 1.0)
	em.queue_spawn(load("res://data/enemies/basic_drone.tres"), player.global_position + Vector3(11, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(5):
		await process_frame
		await physics_frame
	var hurt: CharacterBody3D = null
	for e in em.active_enemies:
		if e.data.id == "basic_drone":
			hurt = e
	hurt.health.take_damage(DamageEvent.new(8.0, "test"))
	var hp0: float = hurt.health.current_hp
	for i in range(150):
		await physics_frame
		if hurt.health.current_hp > hp0:
			break
	_check(hurt.health.current_hp > hp0, "healer healed ally (%.1f -> %.1f)" % [hp0, hurt.health.current_hp])
	em.clear_all()

	# --- Mage fires a volley (BossProjectile appears) ---
	em.queue_spawn(load("res://data/enemies/mage.tres"), player.global_position + Vector3(12, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(5):
		await process_frame
		await physics_frame
	var mage: CharacterBody3D = em.get_all_enemies()[0]
	var volleys_before := _boss_projectile_count(main)
	for i in range(200):
		await physics_frame
		if _boss_projectile_count(main) > volleys_before:
			break
	_check(_boss_projectile_count(main) > volleys_before, "mage fired a volley")
	em.clear_all()

	# --- All evolutions exist and resolve ---
	var prog: Node = main.progression
	_check(prog.evolutions.size() >= 5, "evolution recipes loaded (%d)" % prog.evolutions.size())
	player.weapon_controller.weapons.clear()
	for w_id in ["fireball", "magic_missile", "orbiting_shield", "divine_spear", "lightning", "void_lance"]:
		player.weapon_controller.add_weapon(load("res://data/weapons/%s.tres" % w_id))
	for w in player.weapon_controller.weapons:
		w.level = 5
	for p_id in ["spinach", "empty_tome", "heart", "crown", "wings", "hunters_mark"]:
		prog.passive_levels[p_id] = 5
	var resolved := {}
	for trial in range(30):
		var evo: EvolutionData = EvolutionData.is_available(prog.evolutions, player.weapon_controller, prog.passive_levels)
		if evo != null:
			resolved[evo.id] = true
			# remove the base weapon so other evolutions can surface
			player.weapon_controller.weapons = player.weapon_controller.weapons.filter(func(w): return w.data.id != evo.base_weapon_id)
	var missing := []
	for id in ["hellfire", "holy_bible", "aurora", "judgment", "thunderstorm", "void_reaver"]:
		if not resolved.has(id):
			missing.append(id)
	_check(missing.is_empty(), "all evolutions resolve (missing: %s)" % str(missing))

	if failures == 0:
		print("V6_CONTENT_PASS")
	else:
		print("V6_CONTENT_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _boss_projectile_count(main: Node) -> int:
	var n := 0
	var proj_root: Node3D = main.get_node_or_null("Projectiles")
	for c in proj_root.get_children():
		if c.name.contains("BossProjectile") and c.visible:
			n += 1
	return n

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
