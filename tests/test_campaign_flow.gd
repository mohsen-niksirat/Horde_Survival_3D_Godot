extends SceneTree
## Validation test suite for campaign roadmap implementation:
## Missions, Acts, Map Palettes, Story Enemies, Side Objectives, and Finale.

var failures := 0

func _initialize() -> void:
	print("--- Running test_campaign_flow.gd ---")
	var run_mgr = root.get_node("RunManager")
	
	# 1. Mission data validation
	var mission_paths := [
		"res://data/missions/m1_gate.tres",
		"res://data/missions/m2_frost.tres",
		"res://data/missions/m3_nest.tres",
		"res://data/missions/m4_warden.tres",
		"res://data/missions/m5_heartforge.tres",
	]
	
	_check(mission_paths.size() == 5, "5 campaign missions defined")
	for path in mission_paths:
		_check(ResourceLoader.exists(path), "mission file exists: %s" % path)
		var m: Resource = load(path)
		_check(m != null, "mission loads: %s" % path)
		_check(m.id != "", "mission has valid id (%s)" % m.id)
		_check(m.display_name != "", "mission has display_name (%s)" % m.display_name)
		_check(m.briefing != "", "mission has briefing")
		_check(m.act >= 1 and m.act <= 3, "mission belongs to Acts I-III (Act %d)" % m.act)
		_check(m.describe_win() != "", "describe_win generates description")
		if m.side_objective_type != "":
			_check(m.side_objective_target > 0, "side objective target > 0 (%d)" % m.side_objective_target)
			_check(m.side_gold_reward > 0, "side gold reward > 0 (%d)" % m.side_gold_reward)
			_check(m.describe_side() != "", "describe_side generates description")

	# 2. Story enemy archetypes validation
	var brute_path := "res://data/enemies/brute.tres"
	var specter_path := "res://data/enemies/specter.tres"
	_check(ResourceLoader.exists(brute_path), "brute enemy archetype exists")
	_check(ResourceLoader.exists(specter_path), "specter enemy archetype exists")
	
	var brute: Resource = load(brute_path)
	var specter: Resource = load(specter_path)
	_check(brute != null and brute.max_hp >= 40.0, "brute has tank stats (HP=%.1f)" % brute.max_hp)
	_check(specter != null and specter.phase_interval > 0.0, "specter has phase ability (interval=%.1f)" % specter.phase_interval)
	
	var dummy_root := Node3D.new()
	root.add_child(dummy_root)
	var EnemyVisualsC = load("res://scenes/enemies/enemy_visuals.gd")
	EnemyVisualsC.build(dummy_root, "brute")
	_check(dummy_root.has_meta("built_for"), "brute visual built successfully")
	EnemyVisualsC.build(dummy_root, "specter")
	_check(dummy_root.has_meta("built_for"), "specter visual built successfully")
	dummy_root.queue_free()

	# 3. Heartforge & Ice map palettes in ArenaDungeon
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame

	var arena_dungeon: Node = main.get_node_or_null("World/ArenaDungeon")
	_check(arena_dungeon != null, "arena dungeon exists")
	
	# Test ice map palette trigger
	var m2: Resource = load("res://data/missions/m2_frost.tres")
	run_mgr.set_mission(m2)
	arena_dungeon._apply_map_palette()
	var we: WorldEnvironment = main.find_child("WorldEnvironment", true, false) as WorldEnvironment
	_check(we != null and we.environment != null, "world environment exists")
	_check(we.environment.ambient_light_color == Color(0.55, 0.75, 1.0), "ice ambient color applied")
	
	# Test heartforge magma palette trigger
	var m5: Resource = load("res://data/missions/m5_heartforge.tres")
	run_mgr.set_mission(m5)
	arena_dungeon._apply_map_palette()
	_check(we.environment.ambient_light_color == Color(1.0, 0.42, 0.22), "heartforge magma ambient color applied")

	# 4. Side objective tracking in RunManager
	run_mgr.start_run()
	run_mgr.set_mission(m2) # m2 has side_objective_type = "kill_elites", target = 2
	_check(run_mgr.side_objective_completed == false, "side objective starts incomplete")
	run_mgr.elites_killed = 2
	run_mgr._check_side_objective()
	_check(run_mgr.side_objective_completed == true, "kill_elites side objective completed")

	# Test combo side objective
	run_mgr.start_run()
	run_mgr.set_mission(load("res://data/missions/m1_gate.tres")) # combo_streak target = 25
	run_mgr.max_combo_reached = 30
	run_mgr._check_side_objective()
	_check(run_mgr.side_objective_completed == true, "combo_streak side objective completed")

	# 5. CampaignMenu build & progress banner
	var camp_menu_ps: PackedScene = load("res://scenes/menu/CampaignMenu.tscn")
	var camp_menu := camp_menu_ps.instantiate()
	root.add_child(camp_menu)
	camp_menu.open()
	var rows: VBoxContainer = camp_menu.get_node("Center/Panel/Layout/Scroll/Rows")
	_check(rows.get_child_count() > 5, "campaign menu populated with progress banner, act headers, and cards (%d)" % rows.get_child_count())
	camp_menu.queue_free()

	main.queue_free()

	if failures == 0:
		print("CAMPAIGN_FLOW_PASS")
	else:
		print("CAMPAIGN_FLOW_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
