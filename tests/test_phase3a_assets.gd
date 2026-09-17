extends SceneTree
## Phase 3A: Kenney GLB assets exist, hero loads, enemies use GLB on Low+.

var failures := 0

func _initialize() -> void:
	# Assets on disk
	for p in [
		"res://assets/models/heroes/hero_mage.glb",
		"res://assets/models/heroes/hero_paladin.glb",
		"res://assets/models/heroes/hero_rogue.glb",
		"res://assets/models/enemies/enemy_drone.glb",
		"res://assets/models/enemies/enemy_golem.glb",
		"res://assets/models/weapons/shield-round.glb",
		"res://assets/models/env/skybox-day.png",
	]:
		_check(ResourceLoader.exists(p) or FileAccess.file_exists(p), "asset exists: %s" % p)

	_check(FileAccess.file_exists("res://docs/ASSET_CREDITS.md"), "ASSET_CREDITS.md present")

	var perf = root.get_node("PerformanceManager")
	# Force Low+ so GLB path is taken
	perf.set_quality(perf.Quality.LOW, false)

	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(5):
		await process_frame
		await physics_frame

	var player: CharacterBody3D = main.get_node("World/Player")
	var hero = player.get_node_or_null("Mesh/HeroModel")
	_check(hero != null, "HeroModel node exists")
	if hero != null:
		_check(hero.has_method("use_external"), "hero has use_external")
		for i in range(4):
			await process_frame
		_check(hero.use_external(), "hero loaded external GLB")
		if hero.use_external():
			var ext = player.get_node_or_null("Mesh/KenneyHero")
			if ext == null and hero.get_parent() != null:
				ext = hero.get_parent().get_node_or_null("KenneyHero")
			_check(ext != null, "KenneyHero child present")

	# Enemy GLB path
	var em: Node = main.get_node("EnemyManager")
	var gm = root.get_node("GameManager")
	gm.state = gm.State.PLAYING
	main.get_node("WaveManager").stop()
	# Drop pooled enemies built during Very Low boot
	em.clear_all()
	var pool = root.get_node("PoolManager")
	if pool._pools.has(em.ENEMY_SCENE):
		pool._pools[em.ENEMY_SCENE]["free"].clear()
	player.weapon_controller.weapons.clear()
	perf.set_quality(perf.Quality.LOW, false)
	var drone: EnemyData = load("res://data/enemies/basic_drone.tres")
	em.queue_spawn(drone, player.global_position + Vector3(4, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(8):
		await process_frame
		await physics_frame
	if em.enemy_count() > 0:
		var e = em.get_all_enemies()[0]
		var visual = e.get_node_or_null("Visual")
		var has_ext := false
		var names := []
		if visual != null:
			for c in visual.get_children():
				names.append(c.name)
				if c.name == "External":
					has_ext = true
			print("DEBUG visual children=", names, " built_for=", visual.get_meta("built_for", "?"))
		_check(has_ext, "enemy uses External GLB on Low quality")
	else:
		_check(false, "enemy spawned for GLB check")

	# Very Low falls back to primitives
	perf.set_quality(perf.Quality.VERY_LOW, false)
	em.clear_all()
	em.queue_spawn(drone, player.global_position + Vector3(4, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(6):
		await process_frame
		await physics_frame
	if em.enemy_count() > 0:
		var e2 = em.get_all_enemies()[0]
		var visual2 = e2.get_node_or_null("Visual")
		var has_ext2 := false
		var has_prim := false
		if visual2 != null:
			for c in visual2.get_children():
				if c.name == "External":
					has_ext2 = true
				if c is MeshInstance3D:
					has_prim = true
		_check(not has_ext2 or has_prim, "Very Low prefers primitives (ext=%s prim=%s)" % [has_ext2, has_prim])

	# Arena is the World instance under Main
	var arena: Node3D = main.get_node("World")
	_check(arena != null and arena.has_method("get_spawn_position"), "World/Arena get_spawn_position exists")
	if arena != null:
		var sp: Vector3 = arena.get_spawn_position(Vector3.ZERO)
		_check(absf(sp.x) <= 60.0 and absf(sp.z) <= 60.0, "spawn clamped in arena")

	if failures == 0:
		print("PHASE3A_ASSETS_PASS")
	else:
		print("PHASE3A_ASSETS_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
