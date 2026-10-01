extends SceneTree
## Build variety: new weapons offered in level-ups (max 5 slots) and tier
## descriptions list real stat gains instead of "Upgrade to level 3".

var failures := 0

func _initialize() -> void:
	var game_manager := root.get_node("GameManager")

	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame

	root.get_node("SaveManager").set_meta_data("meta_upgrades", {"meta_slots": 2})

	var player: CharacterBody3D = main.get_node("World/Player")
	var prog: Node = main.progression
	game_manager.state = game_manager.State.PLAYING
	main.get_node("WaveManager").stop()
	player.experience.xp_to_next = 999999.0
	# Start from a clean slate: mage (fireball by default)
	player.weapon_controller.weapons.clear()
	player.weapon_controller.add_weapon(load("res://data/weapons/fireball.tres"))

	# --- Tier description has real numbers, not "Upgrade to level N" ---
	# Inspect the full pool deterministically (not the random 3-pick)
	var pool: Array = []
	prog._fill_pool(pool)
	var tier_opt = null
	var new_opts: Array = []
	for o in pool:
		if o.kind == UpgradeOption.Kind.WEAPON_TIER:
			tier_opt = o
		elif o.kind == UpgradeOption.Kind.NEW_WEAPON:
			new_opts.append(o)
	_check(tier_opt != null, "tier option in pool")
	if tier_opt != null:
		_check(not tier_opt.description.contains("Upgrade to level"), "no generic text (%s)" % tier_opt.description)
		_check(tier_opt.description.contains("%"), "description shows stats (%s)" % tier_opt.description)

	# --- Unheld weapons are offered (pool grew with frost/soul) ---
	_check(new_opts.size() >= 5, "unheld weapons in pool (%d)" % new_opts.size())

	# Apply until slots full (meta_slots=2 → max 5)
	for o in new_opts:
		prog.apply_choice(o)
	_check(player.weapon_controller.weapons.size() == 5, "5 weapon slots filled (%d)" % player.weapon_controller.weapons.size())

	# No more NEW weapons when full
	var pool_full: Array = []
	prog._fill_pool(pool_full)
	var leaked := 0
	for o in pool_full:
		if o.kind == UpgradeOption.Kind.NEW_WEAPON:
			leaked += 1
	_check(leaked == 0, "no NEW offers when 5 slots full (%d)" % leaked)

	# All five distinct ids present
	var ids := {}
	for w in player.weapon_controller.weapons:
		ids[w.data.id] = true
	_check(ids.size() == 5, "five distinct weapons held (%d)" % ids.size())

	if failures == 0:
		print("BUILD_VARIETY_PASS")
	else:
		print("BUILD_VARIETY_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
