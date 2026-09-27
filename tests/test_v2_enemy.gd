extends SceneTree
## V2 validation: each archetype builds its distinct model, parts persist
## through pool recycling (per archetype), hit flash works, wings animate.

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

	var offsets := [Vector3(6, 0, 0), Vector3(-6, 0, 0), Vector3(0, 0, 6), Vector3(0, 0, -6), Vector3(8, 0, 8)]
	var ids := ["basic_drone", "fast_wisp", "tank_golem", "shooter_turret", "swarm_bat"]
	for i in range(ids.size()):
		var data: EnemyData = load("res://data/enemies/%s.tres" % ids[i])
		em.queue_spawn(data, player.global_position + offsets[i], player, 1.0, 1.0, 1.0)
	for i in range(6):
		await process_frame
		await physics_frame
	_check(em.enemy_count() == 5, "5 archetypes spawned (%d)" % em.enemy_count())

	# --- Distinct visual builds per archetype (GLB or primitive, quality-dependent) ---
	var built := {}
	for e in em.active_enemies:
		var visual: Node3D = e.get_node("Visual")
		var key: String = visual.get_meta("built_for") if visual.has_meta("built_for") else ""
		built[e.data.id] = key
		var has_mesh: bool = not e._flash_materials.is_empty()
		_check(has_mesh, "%s visual built (%s)" % [e.data.id, key])
	_check(built.values().filter(func(k): return k.begins_with("fast_wisp|")).size() == 1, "wisp visual tagged (%s)" % built["fast_wisp"])
	_check(built.values().filter(func(k): return k.begins_with("tank_golem|")).size() == 1, "golem visual tagged (%s)" % built["tank_golem"])
	_check(built.values().filter(func(k): return k.begins_with("shooter_turret|")).size() == 1, "turret visual tagged (%s)" % built["shooter_turret"])
	_check(built.values().filter(func(k): return k.begins_with("swarm_bat|")).size() == 1, "bat visual tagged (%s)" % built["swarm_bat"])
	_check(built["basic_drone"] != built["tank_golem"], "archetypes build distinct models")

	# --- Wing animation on bat (primitive fallback only) ---
	var bat: CharacterBody3D = null
	for e in em.active_enemies:
		if e.data.id == "swarm_bat":
			bat = e
	var wing_l: Node3D = bat.get_node("Visual").get_node_or_null("WingL")
	if wing_l != null:
		var rz0: float = wing_l.rotation.z
		for i in range(10):
			await physics_frame
		var rz1: float = wing_l.rotation.z
		_check(absf(rz1 - rz0) > 0.01, "bat wings flap (%.2f -> %.2f)" % [rz0, rz1])
	else:
		print("SKIP: bat wings flap (GLB visual active)")

	# --- Hit flash: material changes then restores ---
	var drone_e: CharacterBody3D = null
	for e in em.active_enemies:
		if e.data.id == "basic_drone":
			drone_e = e
	var part_mat: StandardMaterial3D = drone_e._flash_materials[0]
	var base_col: Color = part_mat.get_meta("base_color")
	drone_e.health.take_damage(DamageEvent.new(1.0, "test"))
	_check(part_mat.albedo_color == Color(3, 3, 3), "hit flash white")
	for i in range(20):
		await physics_frame
	_check(part_mat.albedo_color.is_equal_approx(base_col), "flash restores base color")

	# --- Pool recycle with a DIFFERENT archetype rebuilds the model ---
	drone_e.health.take_damage(DamageEvent.new(9999.0, "test"))
	await process_frame
	await physics_frame
	var bat_data: EnemyData = load("res://data/enemies/swarm_bat.tres")
	em.queue_spawn(bat_data, player.global_position + Vector3(3, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(6):
		await process_frame
		await physics_frame
	var rebuilt: CharacterBody3D = null
	for e in em.active_enemies:
		if e == drone_e:
			rebuilt = e
	_check(rebuilt != null, "pooled instance re-spawned")
	_check(rebuilt != null and rebuilt.data.id == "swarm_bat", "re-spawned as bat")
	var rb_visual: Node3D = rebuilt.get_node("Visual")
	_check(rb_visual.get_meta("built_for").begins_with("swarm_bat|"), "bat model rebuilt on recycle")

	if failures == 0:
		print("V2_ENEMY_PASS")
	else:
		print("V2_ENEMY_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
