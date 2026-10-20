extends SceneTree
## V23A validation: projectile prop attachment and pooled impact/kill VFX.

var failures := 0

func _initialize() -> void:
	await process_frame
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame

	var player: CharacterBody3D = main.get_node("World/Player")
	var wc: Node = player.weapon_controller
	_check(wc != null, "weapon controller exists")
	# Generic projectile picks its CC0 model after setup assigns weapon_id.
	var proj: Node3D = root.get_node("PoolManager").acquire("res://scenes/weapons/MagicMissileProjectile.tscn")
	root.get_node("PoolManager").tag(proj, "res://scenes/weapons/MagicMissileProjectile.tscn")
	main.get_node("Projectiles").add_child(proj)
	var dummy_weapon = wc.weapons[0]
	proj.setup_generic(10.0, 20.0, 0, 0.0, false, "", 0.0,
		player.global_position, Vector3.FORWARD, "magic_missile")
	var mesh: Node3D = proj.get_node("Mesh")
	_check(mesh.get_node_or_null("PropRig") != null, "generic projectile attaches Kenney prop after setup")
	root.get_node("PoolManager").release(proj)

	# Impact pool is initialized by JuiceManager and responds to a damage event.
	var juice: Node = main.get_node("JuiceManager")
	_check(juice._pools.has("res://scenes/vfx/ImpactBurst.tscn"), "impact burst pool initialized")
	var impact: Node3D = juice._acquire("res://scenes/vfx/ImpactBurst.tscn")
	_check(impact != null, "impact burst acquired from pool")
	if impact != null:
		impact.trigger(Vector3.ZERO, Color.CORNFLOWER_BLUE, false)
		_check(impact.visible, "impact burst visible after trigger")
		await create_timer(0.25).timeout
		_check(not impact.visible, "impact burst expires")
		# Return the pooled node to its hidden pool state before teardown.
		impact.visible = false

	main.queue_free()
	await process_frame
	if failures == 0:
		print("V23A_COMBAT_VFX_PASS")
	else:
		print("V23A_COMBAT_VFX_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
