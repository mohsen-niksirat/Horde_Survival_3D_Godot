extends Node3D
## KayKit Dungeon Remastered overlay for the arena: stone tile floor,
## perimeter walls with corner pillars, torches, banners and prop clusters.
## Purely visual — the Arena.tscn StaticBody colliders stay authoritative,
## their primitive meshes are just hidden underneath.

const ENV := "res://assets/models/kaykit/env/"
const TILE := 4.0
const HALF := 60.0

var _tile_mesh: Mesh = null
var _wall_mesh: Mesh = null
var _pillar_mesh: Mesh = null
var _torch_mesh: Mesh = null

func _ready() -> void:
	_hide_primitives()
	if _extract_meshes():
		_build_floor()
		_build_walls()
		_build_torches()
		_build_dressing()
	_apply_map_palette()

## S3: cheap palette swap for mission maps (ice cavern vs stone gate).
func _is_ice_map() -> bool:
	if RunManager == null or RunManager.mission == null:
		return false
	return str(RunManager.mission.map_id) == "ice"

func _apply_map_palette() -> void:
	if not _is_ice_map():
		return
	var we := get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		# walk up
		var p := get_parent()
		while p != null and we == null:
			we = p.get_node_or_null("WorldEnvironment") as WorldEnvironment
			p = p.get_parent()
	if we != null and we.environment != null:
		we.environment.ambient_light_color = Color(0.55, 0.75, 1.0)
		we.environment.fog_enabled = true
		we.environment.fog_light_color = Color(0.45, 0.65, 0.9)
		we.environment.fog_density = 0.012
	for n in ["FloorTiles", "DungeonWalls", "CornerPillars"]:
		var mmi := get_node_or_null(n) as MultiMeshInstance3D
		if mmi != null:
			var mat := mmi.material_override as StandardMaterial3D
			if mat == null:
				mat = StandardMaterial3D.new()
				mmi.material_override = mat
			mat.albedo_color = Color(0.55, 0.78, 1.0)

func _extract_meshes() -> bool:
	_tile_mesh = RigUtil.extract_mesh(ENV + "floor_tile_large.glb")["mesh"]
	_wall_mesh = RigUtil.extract_mesh(ENV + "wall.glb")["mesh"]
	_pillar_mesh = RigUtil.extract_mesh(ENV + "pillar.glb")["mesh"]
	_torch_mesh = RigUtil.extract_mesh(ENV + "torch_lit.glb")["mesh"]
	return _tile_mesh != null and _wall_mesh != null and _pillar_mesh != null

func _hide_primitives() -> void:
	var arena := get_parent()
	for n in ["Ground/GroundMesh", "WallNorth/Mesh", "WallSouth/Mesh", "WallEast/Mesh", "WallWest/Mesh", "PillarNW", "PillarNE", "PillarSW", "PillarSE", "Rock1", "Rock2", "Rock3"]:
		var node := arena.get_node_or_null(n)
		if node is VisualInstance3D:
			node.visible = false

static func _batch(mesh: Mesh, transforms: Array, parent: Node, n: String, tint := Color.TRANSPARENT) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	if tint.a > 0.0:
		var base = mesh.surface_get_material(0)
		if base is StandardMaterial3D:
			var m: StandardMaterial3D = (base as StandardMaterial3D).duplicate()
			m.albedo_color = m.albedo_color * tint
			mmi.material_override = m
	parent.add_child(mmi)
	return mmi

func _build_floor() -> void:
	var tr: Array = []
	var half_n := int(HALF / TILE)
	for ix in range(-half_n, half_n):
		for iz in range(-half_n, half_n):
			tr.append(Transform3D(Basis.IDENTITY, Vector3(float(ix) * TILE + TILE * 0.5, 0.01, float(iz) * TILE + TILE * 0.5)))
	_batch(_tile_mesh, tr, self, "FloorTiles", Color(0.88, 0.8, 0.68))

func _build_walls() -> void:
	var tr: Array = []
	var span := range(-58, 59, 4)
	for x in span:
		tr.append(Transform3D(Basis.IDENTITY, Vector3(float(x), 0.0, -60.5)))
		tr.append(Transform3D(Basis.IDENTITY, Vector3(float(x), 0.0, 60.5)))
	var rot := Basis.from_euler(Vector3(0.0, PI / 2.0, 0.0))
	for z in span:
		tr.append(Transform3D(rot, Vector3(-60.5, 0.0, float(z))))
		tr.append(Transform3D(rot, Vector3(60.5, 0.0, float(z))))
	_batch(_wall_mesh, tr, self, "DungeonWalls", Color(0.62, 0.7, 0.92))
	var corners: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			corners.append(Transform3D(Basis.IDENTITY, Vector3(sx * 60.0, 0.0, sz * 60.0)))
	_batch(_pillar_mesh, corners, self, "CornerPillars", Color(0.7, 0.68, 0.78))

func _build_torches() -> void:
	if _torch_mesh == null:
		return
	var tr: Array = []
	var rot := Basis.from_euler(Vector3(0.0, PI / 2.0, 0.0))
	for o in [-40.0, 0.0, 40.0]:
		tr.append(Transform3D(Basis.IDENTITY, Vector3(o, 2.2, -59.6)))
		tr.append(Transform3D(Basis.IDENTITY, Vector3(o, 2.2, 59.6)))
		tr.append(Transform3D(rot, Vector3(-59.6, 2.2, o)))
		tr.append(Transform3D(rot, Vector3(59.6, 2.2, o)))
	_batch(_torch_mesh, tr, self, "WallTorches")

func _build_dressing() -> void:
	_instance_prop(ENV + "banner_red.glb", Vector3(-20.0, 1.4, -59.2))
	_instance_prop(ENV + "banner_blue.glb", Vector3(20.0, 1.4, -59.2))
	_instance_prop(ENV + "banner_red.glb", Vector3(-20.0, 1.4, 59.2))
	_instance_prop(ENV + "banner_blue.glb", Vector3(20.0, 1.4, 59.2))
	_instance_prop(ENV + "chest_gold.glb", Vector3(34.0, 0.0, -36.0))
	_instance_prop(ENV + "chest.glb", Vector3(32.0, 0.0, -33.5))
	_instance_prop(ENV + "table_medium.glb", Vector3(-36.0, 0.0, 32.0))
	_instance_prop(ENV + "coin_stack_medium.glb", Vector3(-35.0, 1.02, 31.0))
	_instance_prop(ENV + "coin_stack_small.glb", Vector3(-37.0, 1.02, 33.0))
	_instance_prop(ENV + "column.glb", Vector3(-40.0, 0.0, -40.0))
	_instance_prop(ENV + "column.glb", Vector3(40.0, 0.0, -40.0))
	_instance_prop(ENV + "column.glb", Vector3(-40.0, 0.0, 40.0))
	_instance_prop(ENV + "column.glb", Vector3(40.0, 0.0, 40.0))

func _instance_prop(path: String, pos: Vector3) -> void:
	if not ResourceLoader.exists(path):
		return
	var node := (load(path) as PackedScene).instantiate()
	node.position = pos
	node.rotate_y(randf() * TAU)
	add_child(node)
	# T-playtest: solid props block the player
	var name_l := path.get_file().to_lower()
	if name_l.contains("column") or name_l.contains("table") or name_l.contains("chest"):
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		if name_l.contains("column"):
			box.size = Vector3(1.1, 3.2, 1.1)
			shape.position = Vector3(0, 1.6, 0)
		elif name_l.contains("table"):
			box.size = Vector3(1.8, 1.0, 1.0)
			shape.position = Vector3(0, 0.5, 0)
		else:
			box.size = Vector3(1.0, 0.9, 0.8)
			shape.position = Vector3(0, 0.45, 0)
		shape.shape = box
		body.add_child(shape)
		node.add_child(body)
