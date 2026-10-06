extends SceneTree
## Playtest fix validation: pooled enemies/orbs stay VISIBLE after recycle,
## and weapons prefer targets in front of the camera (viewable targets).

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
	player.weapon_controller.weapons.clear()

	var drone: EnemyData = load("res://data/enemies/basic_drone.tres")

	# --- Recycled enemy must be VISIBLE ---
	em.queue_spawn(drone, player.global_position + Vector3(6, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(4):
		await process_frame
		await physics_frame
	var first: CharacterBody3D = em.get_all_enemies()[0]
	_check(first.visible, "first enemy visible")
	first.health.take_damage(DamageEvent.new(9999.0, "test"))
	await process_frame
	await physics_frame
	_check(not first.visible, "released enemy hidden (pool state)")
	# Spawn again — same pooled instance comes back
	em.queue_spawn(drone, player.global_position + Vector3(6, 0, 0), player, 1.0, 1.0, 1.0)
	for i in range(4):
		await process_frame
		await physics_frame
	var second: CharacterBody3D = em.get_all_enemies()[0]
	_check(second == first, "pool reused the same instance")
	_check(second.visible, "RECYCLED ENEMY IS VISIBLE (bug fixed)")
	em.clear_all()

	# --- XP orb visible after recycle ---
	var orb_scene := "res://scenes/pickups/XpOrb.tscn"
	var pool_manager := root.get_node("PoolManager")
	var orb1: Node3D = pool_manager.acquire(orb_scene)
	pool_manager.tag(orb1, orb_scene)
	main.get_node("World").add_child(orb1)
	orb1.setup(1.0, player, Vector3(5, 0, 5))
	_check(orb1.visible, "fresh orb visible")
	pool_manager.release(orb1)
	await process_frame
	await process_frame
	_check(not orb1.visible, "released orb hidden")
	var orb2: Node3D = pool_manager.acquire(orb_scene)
	_check(orb2.visible, "recycled orb visible again")
	# This acquired node is detached; return it before process teardown.
	pool_manager.release(orb2)
	await process_frame

	# --- Targeting prefers in-front-of-camera enemies ---
	player.global_position = Vector3(0, 0.5, 0)
	var cam: Camera3D = player.get_node("CameraRig/SpringArm3D/Camera3D")
	# Camera yaw 0 looks toward -Z. Front enemy at -Z, behind enemy at +Z.
	em.queue_spawn(drone, player.global_position + Vector3(0, 0, -8), player, 1.0, 1.0, 1.0)
	em.queue_spawn(drone, player.global_position + Vector3(0, 0, 8), player, 1.0, 1.0, 1.0)
	for i in range(4):
		await process_frame
		await physics_frame
	var candidates: Array = em.get_all_enemies()
	_check(candidates.size() == 2, "two candidates spawned")
	var chosen: Node3D = TargetingSystem.nearest_visible(player.global_position, candidates, 30.0, cam)
	_check(chosen != null and chosen.global_position.z < player.global_position.z, "in-front enemy preferred (z=%.1f)" % chosen.global_position.z)

	if failures == 0:
		print("VISIBILITY_FIX_PASS")
	else:
		print("VISIBILITY_FIX_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
