extends SceneTree
## P2 slice: relic pickups pulse/spin for readability; hero robe tints
## per-character color; 3 characters visibly differ in-run.

var failures := 0

func _initialize() -> void:
	var game_manager := root.get_node("GameManager")
	root.get_node("SaveManager").set_meta_data("meta_upgrades", {})

	# --- Relic sparkle: emission pulses over time ---
	var relic_ps: PackedScene = load("res://scenes/pickups/RelicPickup.tscn")
	var relic: Area3D = relic_ps.instantiate()
	root.add_child(relic)
	await process_frame
	var data: RelicData = load("res://data/relics/ring.tres")
	relic.setup(data, null, Vector3(0, 0, 0), 60.0)
	await process_frame
	var e0: float = relic._mat.emission_energy_multiplier
	var max_diff: float = 0.0
	for i in range(12):
		await process_frame
		max_diff = maxf(max_diff, absf(relic._mat.emission_energy_multiplier - e0))
	_check(max_diff > 0.01, "relic emission pulses (delta=%.3f)" % max_diff)
	relic.queue_free()

	# --- Character tint: paladin robes are gold, not default blue ---
	game_manager.selected_character_id = "paladin"
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame
	var robe: MeshInstance3D = main.get_node("World/Player/Mesh/Root/Robe")
	var robe_color: Color = robe.get_surface_override_material(0).albedo_color
	_check(robe_color.r > 0.7 and robe_color.g > 0.5, "paladin robe tinted gold (r=%.2f g=%.2f)" % [robe_color.r, robe_color.g])
	main.queue_free()
	await process_frame

	# Rogue tint differs from paladin
	game_manager.selected_character_id = "rogue"
	var main2 := main_ps.instantiate()
	root.add_child(main2)
	for i in range(4):
		await process_frame
		await physics_frame
	var robe2: MeshInstance3D = main2.get_node("World/Player/Mesh/Root/Robe")
	var rc2: Color = robe2.get_surface_override_material(0).albedo_color
	_check(absf(rc2.r - robe_color.r) > 0.1 or absf(rc2.g - robe_color.g) > 0.1, "rogue tint differs from paladin")
	main2.queue_free()

	if failures == 0:
		print("P2_SLICE_PASS")
	else:
		print("P2_SLICE_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
