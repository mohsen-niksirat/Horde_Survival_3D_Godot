extends SceneTree
## Phase 6 test: XP → level up pauses game, choices generated, applied,
## modifiers affect stats, resume works.

var failures := 0

func _initialize() -> void:
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame

	var player: CharacterBody3D = main.get_node("World/Player")
	var progression: Node = main.progression
	var game_manager := root.get_node("GameManager")
	game_manager.state = game_manager.State.PLAYING

	_check(progression.passive_data.size() == 13, "13 passives loaded (got %d)" % progression.passive_data.size())

	# --- Level up via direct XP ---
	var choices_container := {"list": []}
	# LevelUpOverlay is a UI node; emulate by listening to the manager signal
	progression.choices_generated.connect(func(c): choices_container["list"] = c)

	var might0: float = player.get_stat("might")
	player.experience.add_xp(player.experience.xp_to_next + 1.0)
	await process_frame
	await process_frame

	_check(game_manager.state == game_manager.State.LEVEL_UP, "state is LEVEL_UP after level up")
	_check(paused, "game paused during level up")
	var choices_received: Array = choices_container["list"]
	_check(choices_received.size() == 3, "3 choices offered (got %d)" % choices_received.size())

	# No duplicate titles
	var titles := {}
	var dup := false
	for opt in choices_received:
		if titles.has(opt.title):
			dup = true
		titles[opt.title] = true
	_check(not dup, "no duplicate choices")

	# --- Apply the first choice ---
	if choices_received.is_empty():
		print("PHASE6_TEST_FAIL: no choices")
		quit(1)
		return
	var first = choices_received[0]
	progression.apply_choice(first)
	_check(game_manager.state == game_manager.State.LEVEL_UP, "still LEVEL_UP before close")
	game_manager.close_level_up()
	_check(not paused, "game resumed after close")
	_check(game_manager.state == game_manager.State.PLAYING, "state PLAYING after close")

	# --- Stacked multi-level-up flow via apply_and_continue ---
	# Player gains 1 more level while overlay closed (state == PLAYING now).
	player.experience.add_xp(player.experience.xp_to_next)
	await process_frame
	await process_frame
	choices_received = choices_container["list"]
	_check(choices_received.size() == 3, "second level-up offered (pending=%d)" % progression.pending_levels)
	progression.apply_and_continue(choices_received[0])
	_check(game_manager.state == game_manager.State.PLAYING, "single level consumed, PLAYING")

	# --- Two stacked levels in one XP gain: overlay chains after each pick ---
	player.experience.add_xp(player.experience.xp_to_next * 3.0)
	await process_frame
	await process_frame
	choices_received = choices_container["list"]
	_check(choices_received.size() == 3, "stacked level-up offered (pending=%d)" % progression.pending_levels)
	_check(game_manager.state == game_manager.State.LEVEL_UP, "overlay open with pending levels")
	# Pick 1 → still LEVEL_UP
	progression.apply_and_continue(choices_received[0])
	_check(game_manager.state == game_manager.State.LEVEL_UP, "overlay stays for pending level")
	choices_received = choices_container["list"]
	_check(choices_received.size() == 3, "fresh choices for pending level")
	# Pick 2 → threshold grew, so this gain = 2 levels total → close now
	progression.apply_and_continue(choices_received[0])
	_check(game_manager.state == game_manager.State.PLAYING, "all levels consumed, PLAYING")
	_check(progression.pending_levels == 0, "no pending levels left")

	# --- Passive modifier actually changes stats ---
	# Force-apply a spinach passive
	var spinach: PassiveData = progression.passive_data["spinach"]
	var might_before: float = player.get_stat("might")
	spinach.apply_per_level(player.stat_block, 1)
	_check(absf(player.get_stat("might") - (might_before + 0.1)) < 0.001, "spinach adds +0.1 might (%.2f -> %.2f)" % [might_before, player.get_stat("might")])

	# --- Weapon tier via choice ---
	var tier_opt = null
	for opt in choices_received:
		if opt.kind == UpgradeOption.Kind.WEAPON_TIER:
			tier_opt = opt
			break
	if tier_opt != null:
		var target_w = null
		for w in player.weapon_controller.weapons:
			if w.data.id == tier_opt.target.id:
				target_w = w
				break
		var lvl0: int = target_w.level if target_w != null else 0
		progression.apply_choice(tier_opt)
		_check(target_w != null and target_w.level == lvl0 + 1, "weapon tier applied (%d -> %d)" % [lvl0, target_w.level if target_w != null else 0])
	else:
		print("SKIP: no weapon-tier option offered this run")

	# --- Heal option works ---
	var hp0: float = player.health.current_hp
	player.health.take_damage(DamageEvent.new(50.0, "test"))
	var hp_after_damage: float = player.health.current_hp
	var heal_opt: UpgradeOption = progression._make_heal_option()
	progression.apply_choice(heal_opt)
	_check(player.health.current_hp > hp_after_damage, "heal applied")

	if failures == 0:
		print("PHASE6_TEST_PASS")
	else:
		print("PHASE6_TEST_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
