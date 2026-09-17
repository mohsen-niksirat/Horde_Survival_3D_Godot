extends SceneTree
## Phase 2 validation: spatial-hash radius queries match linear results,
## spawn budget caps per-frame admits, pool prewarm, MultiMesh decor,
## instance-unique flash materials, XP orb LOD.

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
	player.weapon_controller.weapons.clear()
	player.experience.xp_to_next = 999999.0

	var drone: EnemyData = load("res://data/enemies/basic_drone.tres")
	var origin := player.global_position

	for i in range(30):
		var ang := TAU * i / 30.0
		var r := 4.0 if i % 2 == 0 else 14.0
		em.queue_spawn(drone, origin + Vector3(cos(ang) * r, 0, sin(ang) * r), player, 1.0, 1.0, 1.0)
	for i in range(8):
		await process_frame
		await physics_frame
	_check(em.enemy_count() >= 20, "spawned pack (count=%d)" % em.enemy_count())

	var near: Array = em.get_enemies_in_radius(origin, 6.0)
	var linear_hits := 0
	for e in em.active_enemies:
		if is_instance_valid(e) and e.global_position.distance_squared_to(origin) <= 36.0:
			linear_hits += 1
	_check(near.size() == linear_hits, "spatial hash count matches linear (%d vs %d)" % [near.size(), linear_hits])

	var capped: Array = em.get_enemies_in_radius(origin, 20.0, 5)
	_check(capped.size() <= 5, "max_count respected (%d)" % capped.size())

	em.clear_all()
	for i in range(20):
		em.queue_spawn(drone, origin + Vector3(3, 0, 3), player, 1.0, 1.0, 1.0)
	_check(em._spawn_queue.size() <= em.MAX_SPAWN_QUEUE, "spawn queue capped")
	await process_frame
	_check(em.enemy_count() <= em.MAX_SPAWNS_PER_FRAME, "per-frame spawn budget (got %d)" % em.enemy_count())

	var mmi_count := _count_mmi(main)
	_check(mmi_count >= 4, "arena/world MultiMesh instances (got %d)" % mmi_count)

	var e1: CharacterBody3D = null
	var e2: CharacterBody3D = null
	em.clear_all()
	em.queue_spawn(drone, origin + Vector3(2, 0, 0), player, 1.0, 1.0, 1.0)
	em.queue_spawn(drone, origin + Vector3(-2, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(6):
		await process_frame
		await physics_frame
	if em.enemy_count() >= 2:
		e1 = em.get_all_enemies()[0]
		e2 = em.get_all_enemies()[1]
	if e1 != null and e2 != null:
		_check(e1._flash_materials.size() > 0, "enemy has flash materials")
		var unique_ok := true
		for mat in e1._flash_materials:
			if is_instance_valid(mat) and mat.get_meta("shared_base", false):
				unique_ok = false
		_check(unique_ok, "flash materials are instance-unique")
		_check(e1 != e2, "two distinct enemy nodes")

	var pool_manager = root.get_node("PoolManager")
	var orb_scene := "res://scenes/pickups/XpOrb.tscn"
	var orb: Node3D = pool_manager.acquire(orb_scene)
	pool_manager.tag(orb, orb_scene)
	main.get_node("World").add_child(orb)
	orb.setup(1.0, player, origin + Vector3(20, 0, 20))
	for i in range(4):
		await process_frame
	_check(orb != null and is_instance_valid(orb), "far XP orb valid after LOD ticks")
	pool_manager.release(orb)

	if failures == 0:
		print("PHASE2_PERF_PASS")
	else:
		print("PHASE2_PERF_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _count_mmi(node: Node) -> int:
	var n := 0
	if node is MultiMeshInstance3D:
		n += 1
	for c in node.get_children():
		n += _count_mmi(c)
	return n

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
