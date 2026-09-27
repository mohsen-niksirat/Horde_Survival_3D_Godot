extends SceneTree
## V9 validation: Endless flag + recurring bosses, meta shop economy
## (buy/apply to stats), save round-trip of upgrade levels.

var failures := 0

func _initialize() -> void:
	var save: Node = root.get_node("SaveManager")
	var game_manager := root.get_node("GameManager")
	game_manager.state = game_manager.State.PLAYING

	# --- Meta shop economy ---
	var shop_ps: PackedScene = load("res://scenes/menu/MetaShop.tscn")
	var shop: Control = shop_ps.instantiate()
	root.add_child(shop)
	await process_frame
	save.set_meta_data("gold", 1000)
	save.set_meta_data("meta_upgrades", {})
	shop._refresh()
	shop._on_buy(shop.STATS[0])  # buy Vitality (cost 50)
	_check(save.get_meta_data("gold", 0) == 950, "gold deducted (950)")
	_check(shop._level("meta_hp") == 1, "level recorded 1")

	# --- Apply to stats: +5% max_hp per level ---
	var stats := StatBlock.new({"max_hp": 100.0})
	var hp0: float = stats.get_stat("max_hp")
	shop.apply_to(stats)
	_check(absf(stats.get_stat("max_hp") - (hp0 * 1.05)) < 0.01, "meta upgrade +5%% max_hp (%.1f)" % stats.get_stat("max_hp"))

	# --- Save round-trip ---
	save.save_game()
	var save2: Node = root.get_node("SaveManager")
	save2.data = {}
	save2.load_game()
	_check(shop._level("meta_hp") == 1, "upgrade level persists after reload")

	# --- Endless: flag + recurring boss timers ---
	var run_manager: Node = root.get_node("RunManager")
	run_manager.start_run_endless()
	_check(run_manager.endless, "endless flag set")
	var wm_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := wm_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame
	var wm: Node = main.get_node("WaveManager")
	run_manager.elapsed_time = 301.0
	wm._tick_boss()
	_check(wm._endless_boss_count == 1, "first endless boss at 5min")
	run_manager.elapsed_time = 601.0
	wm._tick_boss()
	_check(wm._endless_boss_count == 2, "second endless boss at 10min (+30% stats)")

	# --- Shop button visible in menu ---
	var menu_ps: PackedScene = load("res://scenes/menu/MainMenu.tscn")
	var menu := menu_ps.instantiate()
	root.add_child(menu)
	await process_frame
	_check(menu.get_node_or_null("Center/Layout/UpgradesButton") != null, "UPGRADES button exists")
	_check(menu.get_node_or_null("Center/Layout/EndlessCheck") != null, "ENDLESS checkbox exists")
	_check(menu.get_node_or_null("MetaShop") != null, "MetaShop embedded in menu")

	if failures == 0:
		print("V9_META_PASS")
	else:
		print("V9_META_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
