extends SceneTree
## V1 validation: hero model parts exist and the active visual animates.
## Rig path: AnimationPlayer locomotion states. Fallback path: procedural
## bob + run lean on the primitive Root.

var failures := 0

func _initialize() -> void:
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(10):
		await process_frame
		await physics_frame

	var player: CharacterBody3D = main.get_node("World/Player")
	var hero: Node3D = player.get_node("Mesh/HeroModel")
	var model_root: Node3D = player.get_node("Mesh/Root")

	# --- All primitive fallback parts still exist (builder integrity) ---
	for part in ["Robe", "Torso", "Head", "Hood", "ShoulderL", "ShoulderR", "Belt", "Staff/Pole", "Staff/Orb"]:
		var node: Node = model_root.get_node_or_null(part)
		_check(node != null, "hero part exists: " + part)

	# --- Materials assigned (robe visible) ---
	var robe: MeshInstance3D = model_root.get_node("Robe")
	_check(robe.mesh != null, "robe has a mesh")
	_check(robe.get_surface_override_material(0) != null, "robe has a material")

	# --- Animation: rig locomotion or procedural bob ---
	var rig: Node3D = player.get_node_or_null("Mesh/HeroRig")
	if rig != null:
		var ap := RigUtil.animation_player(rig)
		_check(ap != null, "hero rig has AnimationPlayer")
		_check(ap.current_animation == "Idle", "hero idle anim playing (%s)" % ap.current_animation)
		Input.action_press("move_up")
		for i in range(30):
			await physics_frame
		Input.action_release("move_up")
		_check(ap.current_animation in ["Walking_A", "Running_A"], "hero move anim (%s)" % ap.current_animation)
		_check(not model_root.visible, "primitive root hidden under rig")
	else:
		var y0: float = model_root.position.y
		for i in range(20):
			await physics_frame
		var y1: float = model_root.position.y
		_check(absf(y1 - y0) > 0.001, "idle bob animates (%.3f -> %.3f)" % [y0, y1])
		Input.action_press("move_up")
		for i in range(30):
			await physics_frame
		Input.action_release("move_up")
		_check(model_root.rotation.x > 0.02, "run lean applied (rx=%.2f)" % model_root.rotation.x)

	# --- Player still functions: camera, health, weapon ---
	var cam: Camera3D = player.get_node("CameraRig/SpringArm3D/Camera3D")
	_check(cam.current, "camera still current")
	_check(player.weapon_controller.weapons.size() >= 1, "weapons intact")

	if failures == 0:
		print("V1_HERO_PASS")
	else:
		print("V1_HERO_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
