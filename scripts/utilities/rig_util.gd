class_name RigUtil
extends Object
## Shared helpers for attaching imported GLB rigs (KayKit/kenney) at runtime:
## height-normalized attach, AnimationPlayer lookup, and locomotion state
## switching (Idle / Walking / Running) shared by heroes, enemies, and boss.

const IDLE_CANDIDATES := ["Idle", "Unarmed_Idle", "2H_Melee_Idle"]
const WALK_CANDIDATES := ["Walking_A", "Walking_B", "Walking_C", "Walking"]
const RUN_CANDIDATES := ["Running_A", "Running_B", "Running"]
## Forward yaw of imported rigs inside +Z-facing game bodies.
## Blender front (-Y) exports as +Z through the glTF pipeline, same as our
## Kenney set — so 0.0. If a future pack renders backwards, set to PI here.
const RIG_YAW := 0.0


## Pulls the first Mesh resource (and its local height) out of a GLB scene
## so static decor can batch it in a MultiMesh without instantiating scenes.
static func extract_mesh(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {"mesh": null, "height": 0.0}
	var packed: PackedScene = load(path)
	if packed == null:
		return {"mesh": null, "height": 0.0}
	var inst := packed.instantiate()
	var m: Mesh = null
	var h := 0.0
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		m = mi.mesh
		h = mi.get_aabb().size.y
		break
	inst.free()
	return {"mesh": m, "height": h}


static func attach_glb(parent: Node, path: String, target_height: float, node_name := "Rig") -> Node3D:
	if parent == null or not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var inst := packed.instantiate()
	inst.name = node_name
	parent.add_child(inst)
	var aab := _world_aabb(inst)
	var h := aab.size.y
	if h > 0.01 and target_height > 0.0:
		var s := target_height / h
		inst.scale = Vector3.ONE * s
		# Rest the rig's lowest point on the parent origin (feet on floor).
		# X/Z stay at the pivot: the skeleton's own axis IS the rotation
		# center — centering by mesh AABB would include weapons/capes and
		# make the body swing sideways whenever it turns.
		inst.position = Vector3(0, -aab.position.y * s, 0)
	return inst


static func _model_height(inst: Node3D) -> float:
	return _world_aabb(inst).size.y


static func _world_aabb(node: Node3D) -> AABB:
	# Union of every MeshInstance3D under node in node-local space.
	var acc := AABB()
	var found := false
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var local: AABB = node.global_transform.affine_inverse() * (mi.global_transform * mi.get_aabb())
		if not found:
			acc = local
			found = true
		else:
			acc = acc.merge(local)
	return acc


static func animation_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node.has_meta("rig_ap"):
		var cached = node.get_meta("rig_ap")
		if cached is AnimationPlayer and is_instance_valid(cached):
			return cached
		node.remove_meta("rig_ap")
	var players: Array = node.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return null
	var ap := players[0] as AnimationPlayer
	node.set_meta("rig_ap", ap)
	return ap


## Drives a rig's locomotion state. speed: planar movement speed in m/s.
## Returns true when a rig animation was playing (caller can skip procedural bob).
static func play_locomotion(node: Node, speed: float) -> bool:
	var ap := animation_player(node)
	if ap == null:
		return false
	var pool: Array
	if speed < 0.5:
		pool = IDLE_CANDIDATES
	elif speed < 3.6:
		pool = WALK_CANDIDATES
	else:
		pool = RUN_CANDIDATES
	var want := ""
	for c in pool:
		if ap.has_animation(c):
			want = c
			break
	if want == "":
		return false
	var current: String = ap.current_animation
	if current == want:
		return true
	var anim: Animation = ap.get_animation(want)
	if anim != null and anim.loop_mode == Animation.LOOP_NONE:
		anim.loop_mode = Animation.LOOP_LINEAR
	ap.play(want, 0.12)
	return true
