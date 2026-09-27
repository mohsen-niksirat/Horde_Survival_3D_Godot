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

static func _batch(mesh: Mesh, transforms: Array, parent: Node, n: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	parent.add_child(mmi)
	return mmi

func _build_floor() -> void:
	var tr: Array = []
	var half_n := int(HALF / TILE)
	for ix in range(-half_n, half_n):
		for iz in range(-half_n, half_n):
			tr.append(Transform3D(Basis.IDENTITY, Vector3(float(ix) * TILE + TILE * 0.5, 0.01, float(iz) * TILE + TILE * 0.5)))
	_batch(_tile_mesh, tr, self, "FloorTiles")

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
	_batch(_wall_mesh, tr, self, "DungeonWalls")
	var corners: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			corners.append(Transform3D(Basis.IDENTITY, Vector3(sx * 60.0, 0.0, sz * 60.0)))
	_batch(_pillar_mesh, corners, self, "CornerPillars")

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
