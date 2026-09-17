extends Node3D
## V4 arena decoration — MultiMesh batched props to cut draw calls on web.
## Grass/trees/pillars/rocks use MultiMeshInstance3D; rocks keep colliders
## as a small set of StaticBody3D siblings (not per-blade nodes).

const GRASS_COUNT := 90
const TREE_COUNT := 14
const EXTRA_ROCKS := 18
const WALL_PILLARS := 20

const GRASS_COLOR := Color(0.42, 0.62, 0.3)
const GRASS_COLOR2 := Color(0.5, 0.68, 0.34)
const TRUNK_COLOR := Color(0.38, 0.27, 0.17)
const LEAF_COLOR := Color(0.3, 0.55, 0.28)
const STONE_COLOR := Color(0.55, 0.52, 0.48)

var _mat_cache: Dictionary = {}

func _ready() -> void:
	_build_grass()
	_build_trees()
	_build_rocks()
	_build_wall_pillars()

func _random_ring_pos(min_r: float, max_r: float) -> Vector3:
	var angle := randf() * TAU
	var r := randf_range(min_r, max_r)
	return Vector3(cos(angle) * r, 0, sin(angle) * r)

func _baked_mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		_mat_cache[key] = m
	return _mat_cache[key]

func _make_mmi(mesh: Mesh, mat: StandardMaterial3D, transforms: Array, parent: Node3D, n: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	mmi.material_override = mat
	parent.add_child(mmi)
	return mmi

func _xform(pos: Vector3, rot_y: float = 0.0, rot_z: float = 0.0, scale: Vector3 = Vector3.ONE) -> Transform3D:
	var basis := Basis.from_euler(Vector3(0.0, rot_y, rot_z))
	basis = basis.scaled(scale)
	return Transform3D(basis, pos)

func _build_grass() -> void:
	var parent := Node3D.new()
	parent.name = "Grass"
	add_child(parent)
	var blade := PrismMesh.new()
	blade.size = Vector3(0.16, 0.45, 0.16)
	var t_a: Array = []
	var t_b: Array = []
	for i in range(GRASS_COUNT):
		var base := _random_ring_pos(6.0, 56.0)
		var bucket: Array = t_a if i % 2 == 0 else t_b
		for b in range(3):
			var offset := Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3))
			bucket.append(_xform(base + offset, 0.0, randf_range(-0.3, 0.3)))
	_make_mmi(blade, _baked_mat(GRASS_COLOR), t_a, parent, "GrassA")
	_make_mmi(blade, _baked_mat(GRASS_COLOR2), t_b, parent, "GrassB")

func _build_trees() -> void:
	var parent := Node3D.new()
	parent.name = "Trees"
	add_child(parent)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.26
	trunk.height = 2.2
	var crown := SphereMesh.new()
	crown.radius = 1.3
	crown.height = 2.2
	var trunks: Array = []
	var crowns_a: Array = []
	var crowns_b: Array = []
	for i in range(TREE_COUNT):
		var base := _random_ring_pos(38.0, 56.0)
		trunks.append(_xform(base + Vector3(0, 1.1, 0)))
		var s := randf_range(0.85, 1.25)
		var ct := _xform(base + Vector3(0, 2.9, 0), 0.0, 0.0, Vector3(s, s, s))
		if i % 2 == 0:
			crowns_a.append(ct)
		else:
			crowns_b.append(ct)
	_make_mmi(trunk, _baked_mat(TRUNK_COLOR), trunks, parent, "Trunks")
	_make_mmi(crown, _baked_mat(LEAF_COLOR), crowns_a, parent, "CrownsA")
	_make_mmi(crown, _baked_mat(LEAF_COLOR.lightened(0.08)), crowns_b, parent, "CrownsB")

func _build_rocks() -> void:
	var parent := Node3D.new()
	parent.name = "Rocks"
	add_child(parent)
	var rock := SphereMesh.new()
	rock.radius = 0.7
	rock.height = 1.0
	# Rocks need colliders — keep a few MeshInstance bodies, not MultiMesh
	for i in range(EXTRA_ROCKS):
		var rock_mi := MeshInstance3D.new()
		rock_mi.mesh = rock
		rock_mi.material_override = _baked_mat(STONE_COLOR.darkened(randf_range(0.0, 0.25)))
		rock_mi.position = _random_ring_pos(14.0, 57.0) + Vector3(0, 0.3, 0)
		rock_mi.rotation.y = randf() * TAU
		rock_mi.scale = Vector3(randf_range(0.9, 1.5), randf_range(0.6, 1.0), randf_range(0.9, 1.5))
		parent.add_child(rock_mi)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bs := SphereShape3D.new()
		bs.radius = 0.6 * rock_mi.scale.x
		shape.shape = bs
		body.add_child(shape)
		rock_mi.add_child(body)

func _build_wall_pillars() -> void:
	var parent := Node3D.new()
	parent.name = "WallPillars"
	add_child(parent)
	var pillar := BoxMesh.new()
	pillar.size = Vector3(1.6, 4.2, 1.6)
	var cap := BoxMesh.new()
	cap.size = Vector3(2.0, 0.4, 2.0)
	var pillars: Array = []
	var caps: Array = []
	var per_side := WALL_PILLARS / 4
	for i in range(WALL_PILLARS):
		var side := i / per_side
		var k := float(i % per_side) / maxf(float(per_side - 1), 1.0)
		var spread := lerpf(-57.0, 57.0, k)
		var pos: Vector3
		match side:
			0: pos = Vector3(spread, 2.1, -59.5)
			1: pos = Vector3(spread, 2.1, 59.5)
			2: pos = Vector3(-59.5, 2.1, spread)
			_: pos = Vector3(59.5, 2.1, spread)
		pillars.append(_xform(pos))
		caps.append(_xform(pos + Vector3(0, 2.1, 0)))
	_make_mmi(pillar, _baked_mat(STONE_COLOR.darkened(0.1)), pillars, parent, "Pillars")
	_make_mmi(cap, _baked_mat(STONE_COLOR.lightened(0.1)), caps, parent, "Caps")
