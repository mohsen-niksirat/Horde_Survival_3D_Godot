extends SceneTree
## V3 validation: muzzle flash fires at the staff, per-weapon fire SFX
## tone caches populate, fireball has an ember trail.

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
	var pool_manager := root.get_node("PoolManager")
	var audio := root.get_node("AudioManager")

	# --- Fireball: muzzle flash appears + tone cached ---
	# Use a tank so it survives the first hits while we watch for the flash.
	var proj_root: Node3D = main.get_node("Projectiles")
	em.queue_spawn(load("res://data/enemies/tank_golem.tres"), player.global_position + Vector3(8, 0, 0), player, 1.0, 1.0, 1.0)
	var flash_found := false
	for i in range(60):
		await process_frame
		await physics_frame
		for child in proj_root.get_children():
			if child.visible and child.name.contains("MuzzleFlash"):
				flash_found = true
		if flash_found and audio._tone_cache.has("shoot_fireball"):
			break
	_check(flash_found, "muzzle flash spawned and visible on fire")
	_check(audio._tone_cache.has("shoot_fireball"), "fireball SFX tone cached")
	_check(pool_manager.get_pool_stats("res://scenes/weapons/FireballProjectile.tscn").get("created", 0) >= 1, "fireball fired through pool")

	# --- Fireball scene has the trail ---
	var fireball_scene: PackedScene = load("res://scenes/weapons/FireballProjectile.tscn")
	var inst := fireball_scene.instantiate()
	var trail := inst.get_node_or_null("Trail")
	_check(trail != null and trail is GPUParticles3D, "fireball has ember trail")
	# V-fix: emission energy reduced so projectiles don't wash out to white
	var fb_mat: StandardMaterial3D = inst.get_node("Mesh").get_surface_override_material(0)
	if fb_mat != null and fb_mat.emission_enabled:
		_check(fb_mat.emission_energy_multiplier <= 1.0, "fireball emission softened (%.1f)" % fb_mat.emission_energy_multiplier)
	var fb_light: OmniLight3D = inst.get_node_or_null("Light")
	if fb_light != null:
		_check(fb_light.light_energy <= 1.0, "fireball light energy reduced (%.1f)" % fb_light.light_energy)
	inst.queue_free()

	# --- Missile + spear SFX tones cache on their next fire ---
	em.clear_all()
	_purge(proj_root, pool_manager)
	player.weapon_controller.weapons.clear()
	player.weapon_controller.add_weapon(load("res://data/weapons/magic_missile.tres"))
	em.queue_spawn(load("res://data/enemies/basic_drone.tres"), player.global_position + Vector3(8, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(40):
		await process_frame
		await physics_frame
	_check(audio._tone_cache.has("shoot_missile"), "missile SFX tone cached")

	player.weapon_controller.weapons.clear()
	player.weapon_controller.add_weapon(load("res://data/weapons/divine_spear.tres"))
	em.clear_all()
	_purge(proj_root, pool_manager)
	em.queue_spawn(load("res://data/enemies/basic_drone.tres"), player.global_position + Vector3(10, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(40):
		await process_frame
		await physics_frame
	_check(audio._tone_cache.has("shoot_spear"), "spear SFX tone cached")

	player.weapon_controller.weapons.clear()
	player.weapon_controller.add_weapon(load("res://data/weapons/lightning.tres"))
	em.clear_all()
	_purge(proj_root, pool_manager)
	# Tank survives long enough for the 1.5s lightning cooldown to elapse
	em.queue_spawn(load("res://data/enemies/tank_golem.tres"), player.global_position + Vector3(5, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(120):
		await process_frame
		await physics_frame
		if audio._tone_cache.has("shoot_lightning"):
			break
	_check(audio._tone_cache.has("shoot_lightning"), "lightning SFX tone cached")

	# --- Muzzle flash colors differ per weapon (spot-check dict) ---
	var wc: Node = player.weapon_controller
	_check(wc.WEAPON_FLASH_COLORS.has("fireball") and wc.WEAPON_FLASH_COLORS.has("lightning"), "flash color table populated")

	if failures == 0:
		print("V3_WEAPONS_PASS")
	else:
		print("V3_WEAPONS_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _purge(proj_root: Node3D, pm: Node) -> void:
	for proj in proj_root.get_children():
		if proj.has_meta("pool_scene"):
			pm.release(proj)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
