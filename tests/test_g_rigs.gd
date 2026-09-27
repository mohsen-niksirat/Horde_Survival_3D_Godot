extends SceneTree
var pool: Node
## Graphics overhaul validation: rigged characters, animated enemies, GLB
## boss, KayKit dungeon arena layer, and model-based pickups.

var failures := 0

func _initialize() -> void:
	var autoload_ok := root.get_node_or_null("PoolManager") != null
	assert(autoload_ok)
	pool = root.get_node("PoolManager")
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(6):
		await process_frame
		await physics_frame

	var player: CharacterBody3D = main.get_node("World/Player")
	var hero: Node3D = player.get_node("Mesh/HeroModel")

	# --- Hero is a rigged KayKit adventurer with a playing locomotion anim ---
	var rig: Node3D = player.get_node_or_null("Mesh/HeroRig")
	_check(rig != null, "hero rig attached")
	if rig != null:
		var ap := RigUtil.animation_player(rig)
		_check(ap != null, "hero rig has AnimationPlayer")
		if ap != null:
			_check(ap.current_animation == "Idle" or ap.current_animation == "Walking_A", "hero idle anim playing (%s)" % ap.current_animation)
		var h := RigUtil._world_aabb(rig).size.y * rig.scale.y
		_check(h > 1.2 and h < 2.4, "hero rig scaled to human height (%.2f)" % h)
	_check(player.get_node("Mesh/Root").visible == false or rig == null, "primitive root hidden when rig active")

	# --- Skeleton enemies build as rigs and animate ---
	var em: Node = main.get_node("EnemyManager")
	var game_manager := root.get_node("GameManager")
	game_manager.state = game_manager.State.PLAYING
	main.get_node("WaveManager").stop()
	em.clear_all()
	player.weapon_controller.weapons.clear()
	player.experience.xp_to_next = 9999999.0
	em.queue_spawn(load("res://data/enemies/basic_drone.tres"), player.global_position + Vector3(9, 0, 0), player, 1.0, 1.0, 1.0)
	em.queue_spawn(load("res://data/enemies/tank_golem.tres"), player.global_position + Vector3(-9, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(6):
		await process_frame
		await physics_frame
	for e in em.get_all_enemies():
		var visual: Node3D = e.get_node("Visual")
		var built: String = visual.get_meta("built_for")
		_check(built.ends_with("|rig"), "%s builds rigged model (%s)" % [e.data.id, built])
		_check(not e._flash_materials.is_empty(), "%s flash materials collected" % e.data.id)
		var ap := RigUtil.animation_player(visual)
		_check(ap != null and ap.current_animation in ["Idle", "Walking_A", "Running_A"], "%s locomotion anim playing (%s)" % [e.data.id, ap.current_animation if ap != null else "none"])
	em.clear_all()

	# --- Boss uses the giant skeleton rig ---
	var boss_ps: PackedScene = load("res://scenes/bosses/Boss.tscn")
	var boss := boss_ps.instantiate()
	main.get_node("World").add_child(boss)
	await process_frame
	var boss_rig: Node3D = boss.get_node_or_null("BossRig")
	_check(boss_rig != null, "boss skeleton rig attached")
	if boss_rig != null:
		_check(RigUtil._world_aabb(boss_rig).size.y * boss_rig.scale.y > 4.0, "boss rig is huge")
	_check(boss.get_node("Mesh").mesh == null or boss_rig != null, "boss primitive stack retired")
	boss.queue_free()

	# --- Dungeon arena layer replaces the colored-box look ---
	var dungeon: Node = main.get_node_or_null("World/ArenaDungeon")
	_check(dungeon != null, "dungeon layer exists")
	if dungeon != null:
		var tiles := dungeon.get_node_or_null("FloorTiles")
		_check(tiles != null and tiles.multimesh.instance_count >= 900, "stone floor tiled (%d)" % (tiles.multimesh.instance_count if tiles != null and tiles.multimesh != null else 0))
		var walls := dungeon.get_node_or_null("DungeonWalls")
		_check(walls != null and walls.multimesh.instance_count >= 116, "dungeon walls surround arena (%d)" % (walls.multimesh.instance_count if walls != null and walls.multimesh != null else 0))
		_check(main.get_node("World/Ground/GroundMesh").visible == false, "primitive ground hidden")
		_check(main.get_node("World/WallNorth/Mesh").visible == false, "primitive walls hidden")
	var tree_rigs := main.get_node("World/ArenaDecor/Trees").get_node_or_null("TreeRigs")
	_check(tree_rigs != null, "real tree meshes scattered")

	# --- Pickups are GLB models, not prisms/spheres ---
	var orb: Node = pool.acquire("res://scenes/pickups/XpOrb.tscn")
	pool.tag(orb, "res://scenes/pickups/XpOrb.tscn")
	main.get_node("World").add_child(orb)
	await process_frame
	_check(orb.get_node_or_null("Mesh/ShardRig") != null, "xp shard model attached")
	if orb.get_node_or_null("Mesh/ShardRig") != null:
		_check(orb.get_node("Mesh").mesh == null, "orb prism cleared")
	pool.release(orb)
	var heart: Node = pool.acquire("res://scenes/pickups/HeartPickup.tscn")
	pool.tag(heart, "res://scenes/pickups/HeartPickup.tscn")
	main.get_node("World").add_child(heart)
	await process_frame
	_check(heart.get_node_or_null("Mesh/PotionRig") != null, "heart potion model attached")
	pool.release(heart)
	var relic: Node = pool.acquire("res://scenes/pickups/RelicPickup.tscn")
	pool.tag(relic, "res://scenes/pickups/RelicPickup.tscn")
	main.get_node("World").add_child(relic)
	await process_frame
	_check(relic.get_node_or_null("Mesh/ChestRig") != null, "relic chest model attached")
	pool.release(relic)

	if failures == 0:
		print("GRAPHICS_RIGS_PASS")
	else:
		print("GRAPHICS_RIGS_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
