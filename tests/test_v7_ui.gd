extends SceneTree
## V7 validation: weapon icons render with levels, bars ease, combo pops,
## menu animated background draws.

var failures := 0

func _initialize() -> void:
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame

	var player: CharacterBody3D = main.get_node("World/Player")
	var hud: Control = main.get_node("HUD/Hud")
	var game_manager := root.get_node("GameManager")
	game_manager.state = game_manager.State.PLAYING

	# --- Weapon icons: one per weapon with level text ---
	var icons: HBoxContainer = hud.get_node("TopLeft/WeaponIcons")
	_check(icons.get_child_count() == player.weapon_controller.weapons.size(), "icon per weapon (%d)" % icons.get_child_count())
	if icons.get_child_count() > 0:
		var icon: Panel = icons.get_child(0)
		var lv: Label = icon.get_child(0)
		_check(lv.text != "", "icon shows level (%s)" % lv.text)
		var style: StyleBoxFlat = icon.get_theme_stylebox("panel")
		_check(style != null, "icon has tinted stylebox")

	# --- Bars ease toward target (not instant) ---
	var hp_bar: ProgressBar = hud.get_node("TopLeft/HPBar")
	player.health.take_damage(DamageEvent.new(50.0, "test"))
	var v0: float = hp_bar.value
	await process_frame
	await process_frame
	var v1: float = hp_bar.value
	_check(v1 < v0 - 1.0, "HP bar eases (drops gradually, not snap) (%.1f -> %.1f)" % [v0, v1])
	# let it settle
	await create_timer(1.0).timeout
	_check(absf(hp_bar.value - player.health.current_hp) < 1.0, "HP bar settles on true value")

	# --- Combo pop tween on tier change ---
	var combo: Label = hud.get_node("Combo")
	hud._last_tier = ""
	hud._on_combo(10, 1.2)
	await process_frame
	_check(combo.visible, "combo visible")
	_check(combo.scale.x > 1.0, "combo pop animating (scale=%.2f)" % combo.scale.x)

	# --- Menu animated background exists ---
	var menu_ps: PackedScene = load("res://scenes/menu/MainMenu.tscn")
	var menu := menu_ps.instantiate()
	root.add_child(menu)
	await process_frame
	var bg: Node2D = menu.get_node_or_null("AnimatedBG")
	_check(bg != null, "menu animated bg node exists")
	var orbs: int = bg._orbs.size()
	menu.queue_free()
	_check(orbs >= 14, "bg orbs spawned (%d)" % orbs)

	if failures == 0:
		print("V7_UI_PASS")
	else:
		print("V7_UI_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
