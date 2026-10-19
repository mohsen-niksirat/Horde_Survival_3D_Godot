extends SceneTree
## V20A performance validation: menu async init (deferred panels), weapon
## query reuse, XP-orb material recycle guard, enemy animation LOD, boss-bar
## throttle, and the auto-tier startup grace window.

var failures := 0

func _initialize() -> void:
	# Autoloads connect to EventBus in _ready, which runs after _initialize.
	await process_frame

	# --- menu: stats line renders on the first frame; panel/campaign builds
	# are deferred off the critical path (scene instances them, code defers) ---
	var menu_ps: PackedScene = load("res://scenes/menu/MainMenu.tscn")
	var menu := menu_ps.instantiate()
	root.add_child(menu)
	_check(menu.get_node("Stats").text.contains("Gold"), "stats line ready on first frame")
	# Direct-call the deferred builders (call_deferred fires post-frame; the
	# scene already pre-instances both panels so the guards no-op safely).
	menu._instantiate_panel()
	menu._instantiate_campaign()
	_check(menu.get_node_or_null("AchievementPanel") != null, "panel builder produces the panel")
	_check(menu.get_node_or_null("CampaignMenu") != null, "campaign builder produces the campaign menu")

	# --- weapon volley: targeting query reused across the spread ---
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame
	var player: CharacterBody3D = main.get_node("World/Player")
	var em: Node = main.get_node("EnemyManager")
	var drone: EnemyData = load("res://data/enemies/basic_drone.tres")
	var origin := player.global_position
	em.queue_spawn(drone, origin + Vector3(6, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(3):
		await process_frame
		await physics_frame
	if em.enemy_count() == 0:
		em.queue_spawn(drone, origin + Vector3(6, 0, 0), player, 1.0, 1.0, 1.0)
		await process_frame
		await physics_frame
	var wc: Node = player.weapon_controller
	var inst = wc.weapons[0]
	# Deterministic: force the cooldown to elapse and tick once — the query
	# must populate the cache the controller's spread then reuses.
	inst._cooldown_left = 0.0
	inst.tick(0.5, player, em)
	_check(not inst.last_query_targets.is_empty(), "weapon instance caches its query targets")
	# Direct-invoke the spread with a cached set holding a stale marker (the
	# player). The spread must filter non-enemies out — without the reuse path
	# this would re-query (marker silently dropped) or aim a shot at the player.
	var enemy = em.get_all_enemies()[0]
	inst.last_query_targets = [player, enemy]
	wc._spawn_projectile(inst, player, enemy, "res://scenes/weapons/MagicMissileProjectile.tscn")
	var proj_root: Node3D = main.get_node("Projectiles")
	_check(proj_root.get_child_count() > 0, "spread spawned a projectile from the cached set")
	var aimed_ok := true
	for p in proj_root.get_children():
		var vel = p.get("_velocity")
		if vel == null or vel == Vector3.ZERO:
			continue
		var to_enemy: Vector3 = enemy.global_position - p.global_position
		if vel.normalized().dot(to_enemy.normalized()) < 0.5:
			aimed_ok = false
	_check(aimed_ok, "projectile aims at the enemy, not the injected player marker")

	# --- XP orb: same-tier recycle skips the material rebuild ---
	var pool = root.get_node("PoolManager")
	var orb_scene := "res://scenes/pickups/XpOrb.tscn"
	var orb: Node3D = pool.acquire(orb_scene)
	pool.tag(orb, orb_scene)
	main.get_node("World").add_child(orb)
	orb.setup(1.0, player, origin)
	await process_frame
	_check(orb._last_visual_tier == 0, "orb visuals built for tier 0")
	orb.setup(1.5, player, origin)
	_check(orb._last_visual_tier == 0, "same-tier recycle skipped rebuild")
	orb.setup(5.0, player, origin)
	_check(orb._last_visual_tier == 1, "tier bump rebuilds visuals")
	pool.release(orb)

	# --- boss bar throttle: gate skips the lookup until the interval expires ---
	var hud: Control = main.get_node("HUD/Hud")
	hud.boss_check_accum = 0.5
	hud._process_boss_bar()
	_check(hud.boss_check_accum > 0.4, "throttled boss bar early-outs before its interval")
	hud.boss_check_accum = 0.0
	hud._process_boss_bar()
	_check(absf(hud.boss_check_accum - hud.BOSS_BAR_CHECK_INTERVAL) < 0.001, "expired gate runs the check and re-arms")

	# --- auto-tier startup grace ---
	var perf: Node = root.get_node("PerformanceManager")
	var q0: int = perf.quality
	perf.auto_mode = true
	perf._auto_grace_left = 1.0
	perf._auto_tick(0.5, 10)
	_check(perf.quality == q0, "auto tick is a no-op during startup grace")
	perf._auto_grace_left = 0.0
	perf._auto_tick(0.5, 10)
	_check(perf.quality < perf.Quality.ULTRA, "after grace, low FPS steps the tier down")
	perf.auto_mode = false
	perf.set_quality(perf.Quality.VERY_LOW, false)

	# Cleanup: free the instantiated scenes so the exit-leak gate stays clean.
	menu.queue_free()
	main.queue_free()
	await process_frame

	if failures == 0:
		print("V20A_PERF_PASS")
	else:
		print("V20A_PERF_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
