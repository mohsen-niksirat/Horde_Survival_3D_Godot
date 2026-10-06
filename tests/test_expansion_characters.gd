extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	var save = root.get_node("SaveManager")
	var gm = root.get_node("GameManager")
	save.set_meta_data("meta_upgrades", {})
	for id in ["iron_bark", "ember_lens", "time_sand", "quartz_heart"]:
		var passive: PassiveData = load("res://data/passives/%s.tres" % id)
		var stats := StatBlock.new()
		passive.apply_per_level(stats, 5)
		check(passive.max_level == 5, id + " cap")
		match id:
			"iron_bark": check(is_equal_approx(stats.get_stat("armor"), 7.5), "armor")
			"ember_lens": check(is_equal_approx(stats.get_stat("area_mult"), 1.3), "area")
			"time_sand": check(is_equal_approx(stats.get_stat("cooldown_mult"), 0.8), "cooldown")
			"quartz_heart": check(is_equal_approx(stats.get_stat("regen"), 1.5), "regen")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	for id in ["stormcaller", "warden"]:
		gm.selected_character_id = id
		var main = scene.instantiate()
		root.add_child(main)
		for frame in range(5):
			await process_frame
			await physics_frame
		var p = main.get_node("World/Player")
		var ch: CharacterData = load("res://data/characters/%s.tres" % id)
		check(p.weapon_controller.weapons[0].data.id == ch.starting_weapon_id, id + " weapon")
		check(is_equal_approx(p.health.max_hp, 85.0 if id == "stormcaller" else 125.0), id + " HP")
		check(main.progression.passive_levels.get(ch.starting_passive_id, 0) == 1, id + " starting item")
		var option := UpgradeOption.new()
		option.kind = UpgradeOption.Kind.PASSIVE
		option.target = load("res://data/passives/iron_bark.tres")
		for n in range(9):
			main.progression.apply_choice(option)
		check(main.progression.passive_levels["iron_bark"] == 5, "duplicate upgrade capped")
		check(is_equal_approx(p.stat_block.get_stat("armor"), 7.5), "no excess passive stats")
		main.queue_free()
		await process_frame
		await process_frame
	var select = load("res://scenes/menu/CharacterSelect.tscn").instantiate()
	root.add_child(select)
	save.set_meta_data("victories", 0)
	select.open()
	check(select.cards.get_child_count() == 7, "seven cards")
	check(not select._is_unlocked("stormcaller"), "new hero locked initially")
	save.set_meta_data("victories", 6)
	check(select._is_unlocked("warden"), "warden unlock")
	select.open()
	check(select.cards.get_child_count() == 7, "reopening does not duplicate cards")
	select.set_anchors_preset(Control.PRESET_TOP_LEFT)
	select.size = Vector2(390, 760)
	select._fit_layout()
	check(select.cards.columns == 1, "phone one-column layout")
	check(CharacterData.unlock_requirement("invalid") > 1000000, "unknown save id denied")
	select.queue_free()
	await process_frame
	gm.selected_character_id = "mage"
	print("EXPANSION_CHARACTERS_PASS" if failures == 0 else "EXPANSION_CHARACTERS_FAIL")
	quit(0 if failures == 0 else 1)
