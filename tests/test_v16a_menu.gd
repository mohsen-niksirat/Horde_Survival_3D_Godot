extends SceneTree
## V16A validation: best_combo / best_level persistence, enriched main-menu
## stats line, and achievement panel progress bars for numeric goals.

var failures := 0

func _initialize() -> void:
	var save: Node = root.get_node("SaveManager")
	# Autoloads connect to EventBus in _ready, which runs after _initialize.
	await process_frame
	save.data = save._default_data()  # deterministic baseline

	# --- best_combo AND best_level persist via the RunManager run_ended hook ---
	var run_manager: Node = root.get_node("RunManager")
	run_manager.start_run()
	run_manager.max_combo_reached = 42
	root.get_node("EventBus").player_leveled_up.emit(12)
	root.get_node("EventBus").run_ended.emit(false)
	run_manager.is_running = false
	_check(int(save.get_meta_data("best_combo", 0)) == 42, "best_combo persisted on run end (42)")
	_check(int(save.get_meta_data("best_level", 0)) == 12, "best_level persisted (12)")

	# --- a lower combo must not regress the best ---
	run_manager.start_run()
	run_manager.max_combo_reached = 17
	root.get_node("EventBus").run_ended.emit(false)
	run_manager.is_running = false
	_check(int(save.get_meta_data("best_combo", 0)) == 42, "lower combo does not regress best")

	# --- enriched main-menu stats line ---
	save.set_meta_data("total_runs", 3)
	save.set_meta_data("completed_missions", ["m1_gate", "m2_road"])
	save.set_meta_data("endless_best_minutes", 10)
	var menu_ps: PackedScene = load("res://scenes/menu/MainMenu.tscn")
	var menu := menu_ps.instantiate()
	root.add_child(menu)
	await process_frame
	var stats: Label = menu.get_node("Stats")
	var text: String = stats.text
	_check(text.contains("Wins"), "stats line has wins (%s)" % text.replace("\n", " | "))
	_check(text.contains("Runs: 3"), "stats line shows run count")
	_check(text.contains("Missions: 2/8"), "stats line shows campaign progress")
	_check(text.contains("Endless best: 10 min"), "stats line shows endless best")

	# --- achievement panel: numeric goals get progress bars ---
	save.set_meta_data("total_kills", 130)
	save.set_meta_data("best_combo", 42)
	var panel_ps: PackedScene = load("res://scenes/menu/AchievementPanel.tscn")
	var panel := panel_ps.instantiate()
	root.add_child(panel)
	await process_frame
	panel.open()
	await process_frame
	var rows: VBoxContainer = panel.get_node("Center/Panel/Layout/Scroll/Rows")
	var bars := 0
	var full := 0
	var stack: Array = rows.get_children().duplicate()
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is ProgressBar:
			bars += 1
			if n.max_value > 0.0 and n.value >= n.max_value:
				full += 1
		for c in n.get_children():
			stack.append(c)
	_check(bars >= 9, "numeric achievements show progress bars (%d)" % bars)
	_check(full >= 3, "completed goals show full bars (%d)" % full)

	if failures == 0:
		print("V16A_MENU_PASS")
	else:
		print("V16A_MENU_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
