extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func _run() -> void:
	var rm = root.get_node("RunManager")
	var gm = root.get_node("GameManager")
	root.get_node("SaveManager").set_meta_data("meta_upgrades", {})
	gm.selected_character_id = "mage"
	for id in ["ember_runner", "crystal_guard", "broodling", "brood_keeper"]:
		var d: EnemyData = load("res://data/enemies/%s.tres" % id)
		check(d.id == id and d.threat_cost > 0.0 and d.max_hp > 0.0, id + " valid")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	for id in ["m6_storm", "m7_hollow"]:
		var mission: MissionData = load("res://data/missions/%s.tres" % id)
		check(not mission.is_unlocked(0, []), "locked until progression")
		check(mission.is_unlocked(0, ["m5_heartforge" if id == "m6_storm" else "m6_storm"]), "previous mission unlock")
		rm.set_mission(mission)
		var main = scene.instantiate()
		root.add_child(main)
		for frame in range(5):
			await process_frame
			await physics_frame
		main.wave_manager.stop()
		var p = main.get_node("World/Player")
		var director = main.get_node("World/StageDirector")
		director.set_process(false)
		check(director.rings.size() == 3, "fixed ring budget")
		var count: int = director.get_child_count()
		var allowed: Array = main.wave_manager._allowed_archetypes(1.0)
		if id == "m6_storm":
			check(allowed.has("ember_runner") and allowed.has("crystal_guard"), "storm wave mix")
			director._begin_warning()
			check(director._warning_left >= 1.5, "fair warning window")
			check(director._inside_ring(director.rings[0], 2.4), "warning targets old position")
			p.global_position += Vector3(0, 0, 10)
			var hp: float = p.health.current_hp
			director._resolve_strike()
			check(is_equal_approx(p.health.current_hp, hp), "dodging prevents damage")
			p.global_position = director.rings[0].global_position
			director._resolve_strike()
			check(p.health.current_hp < hp, "remaining in ring hurts")
			for n in range(30):
				director._begin_warning()
			check(director.get_child_count() == count, "no hazard node growth")
		else:
			check(allowed.has("brood_keeper") and allowed.has("broodling"), "grove wave mix")
			p.health.current_hp = 50.0
			p.global_position = director.rings[0].global_position
			director._tick_sanctuary(1.1)
			check(is_equal_approx(p.health.current_hp, 52.0), "sanctuary heals exactly two")
			var old: Vector3 = director.rings[0].global_position
			director._tick_sanctuary(18.1)
			check(not director.rings[0].global_position.is_equal_approx(old), "sanctuary rotates")
		for enemy_id in ["ember_runner", "crystal_guard", "broodling", "brood_keeper"]:
			var enemy_data: EnemyData = load("res://data/enemies/%s.tres" % enemy_id)
			check(main.enemy_manager.queue_spawn(enemy_data, Vector3(10, 0, 10), p, 1.0, 1.0, 1.0), "new enemy queues")
		main.enemy_manager._process(0.016)
		check(main.enemy_manager.enemy_count() >= 4, "new enemies instantiate")
		main.queue_free()
		await process_frame
		await process_frame
	rm.mission = null
	print("EXPANSION_STAGES_PASS" if failures == 0 else "EXPANSION_STAGES_FAIL")
	quit(0 if failures == 0 else 1)
