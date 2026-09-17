extends Node3D
## V2 enemy visual builder — primitive models per archetype with a shared
## material cache so recycled enemies don't explode material/draw-call counts.
## Hit-flash / elite tint duplicate materials per instance when needed.

static var _mat_cache: Dictionary = {}

static func build(visual_root: Node3D, archetype_id: String) -> void:
	if visual_root.has_meta("built_for") and visual_root.get_meta("built_for") == archetype_id:
		return
	_clear_parts(visual_root)
	visual_root.set_meta("built_for", archetype_id)
	match archetype_id:
		"basic_drone": _build_drone(visual_root)
		"fast_wisp": _build_wisp(visual_root)
		"tank_golem": _build_golem(visual_root)
		"shooter_turret": _build_turret(visual_root)
		"swarm_bat": _build_bat(visual_root)
		"ghost": _build_ghost(visual_root)
		"splitter": _build_splitter(visual_root)
		"healer": _build_healer(visual_root)
		"mage": _build_mage(visual_root)
		"swarm_bat_mini": _build_bat(visual_root)
		_: _build_drone(visual_root)

static func clear(visual_root: Node3D) -> void:
	visual_root.remove_meta("built_for")
	_clear_parts(visual_root)

static func _clear_parts(visual_root: Node3D) -> void:
	for child in visual_root.get_children():
		child.queue_free()

static func _mesh(parent: Node3D, mesh: Mesh, mat: StandardMaterial3D, pos: Vector3, rot_x: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	mi.rotation.x = rot_x
	mi.set_meta("base_y", pos.y)
	parent.add_child(mi)
	return mi

static func _mat(color: Color, emission: float = 0.0, transparency: int = BaseMaterial3D.TRANSPARENCY_DISABLED) -> StandardMaterial3D:
	var key := "%s|%.2f|%d" % [color.to_html(), emission, transparency]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	if transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		m.transparency = transparency
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	m.set_meta("shared_base", true)
	_mat_cache[key] = m
	return m

## Unique copy for flash/elite tinting so shared cache stays clean.
static func ensure_unique_material(mi: MeshInstance3D) -> StandardMaterial3D:
	var mat: StandardMaterial3D = mi.get_surface_override_material(0)
	if mat == null:
		return null
	if mat.get_meta("shared_base", false):
		mat = mat.duplicate()
		mat.set_meta("shared_base", false)
		mi.set_surface_override_material(0, mat)
	return mat

# --- Basic Drone ---
static func _build_drone(v: Node3D) -> void:
	var body_col := Color(0.62, 0.67, 0.72)
	var accent := Color(0.95, 0.45, 0.25)
	var body_mat := _mat(body_col)
	var accent_mat := _mat(accent, 0.8)
	_sphere(v, body_mat, 0.5, Vector3(0, 0.55, 0))
	_mesh(v, SphereMesh.new(), accent_mat, Vector3(0, 0.55, 0)).scale = Vector3(0.28, 0.28, 0.28)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.02
	pole.bottom_radius = 0.02
	pole.height = 0.35
	_mesh(v, pole, accent_mat, Vector3(-0.12, 1.0, 0))
	_mesh(v, pole, accent_mat, Vector3(0.12, 1.0, 0))
	var nub := CylinderMesh.new()
	nub.top_radius = 0.09
	nub.bottom_radius = 0.09
	nub.height = 0.16
	_mesh(v, nub, accent_mat, Vector3(-0.42, 0.4, 0), PI / 2)
	_mesh(v, nub, accent_mat, Vector3(0.42, 0.4, 0), PI / 2)
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.3
	skirt.bottom_radius = 0.42
	skirt.height = 0.2
	_mesh(v, skirt, body_mat, Vector3(0, 0.25, 0))

# --- Wisp ---
static func _build_wisp(v: Node3D) -> void:
	var core_mat := _mat(Color(0.4, 0.85, 1.0), 2.0)
	var outer_mat := _mat(Color(0.2, 0.55, 0.9), 1.2, BaseMaterial3D.TRANSPARENCY_ALPHA)
	outer_mat.albedo_color.a = 0.55
	_sphere(v, core_mat, 0.28, Vector3(0, 0.7, 0))
	var kite := PrismMesh.new()
	kite.size = Vector3(0.7, 0.9, 0.2)
	_mesh(v, kite, outer_mat, Vector3(0, 0.75, 0), -0.4)

# --- Golem ---
static func _build_golem(v: Node3D) -> void:
	var stone := _mat(Color(0.45, 0.42, 0.4))
	var moss := _mat(Color(0.35, 0.55, 0.3))
	_mesh(v, BoxMesh.new(), stone, Vector3(0, 0.7, 0)).scale = Vector3(0.9, 0.8, 0.7)
	_mesh(v, BoxMesh.new(), stone, Vector3(0, 1.4, 0)).scale = Vector3(0.55, 0.45, 0.5)
	_mesh(v, BoxMesh.new(), moss, Vector3(-0.55, 0.7, 0)).scale = Vector3(0.28, 0.55, 0.28)
	_mesh(v, BoxMesh.new(), moss, Vector3(0.55, 0.7, 0)).scale = Vector3(0.28, 0.55, 0.28)

# --- Turret ---
static func _build_turret(v: Node3D) -> void:
	var metal := _mat(Color(0.55, 0.58, 0.62))
	var glow := _mat(Color(1.0, 0.4, 0.2), 1.5)
	var base := CylinderMesh.new()
	base.top_radius = 0.25
	base.bottom_radius = 0.4
	base.height = 0.35
	_mesh(v, base, metal, Vector3(0, 0.2, 0))
	var head := BoxMesh.new()
	head.size = Vector3(0.4, 0.3, 0.4)
	_mesh(v, head, metal, Vector3(0, 0.55, 0))
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.06
	barrel.bottom_radius = 0.08
	barrel.height = 0.55
	_mesh(v, barrel, metal, Vector3(0, 0.55, 0.35), PI / 2)
	_sphere(v, glow, 0.08, Vector3(0, 0.72, 0))

# --- Bat ---
static func _build_bat(v: Node3D) -> void:
	var body_mat := _mat(Color(0.35, 0.2, 0.4))
	var wing_mat := _mat(Color(0.55, 0.25, 0.45), 0.0, BaseMaterial3D.TRANSPARENCY_ALPHA)
	wing_mat.albedo_color.a = 0.85
	_sphere(v, body_mat, 0.22, Vector3(0, 0.55, 0))
	var wing_mesh := PrismMesh.new()
	wing_mesh.size = Vector3(0.45, 0.12, 0.2)
	var wl := _mesh(v, wing_mesh, wing_mat, Vector3(-0.36, 0.5, 0))
	var wr := _mesh(v, wing_mesh, wing_mat, Vector3(0.36, 0.5, 0))
	wl.name = "WingL"
	wr.name = "WingR"

static func _sphere(v: Node3D, mat: StandardMaterial3D, radius: float, pos: Vector3) -> void:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	_mesh(v, s, mat, pos)

## Per-frame micro-animation — LOD: callers should skip far enemies.
static func animate(visual_root: Node3D, archetype_id: String, time: float, seed_val: float) -> void:
	match archetype_id:
		"swarm_bat", "swarm_bat_mini":
			var wl := visual_root.get_node_or_null("WingL")
			var wr := visual_root.get_node_or_null("WingR")
			if wl != null and wr != null:
				var flap := sin(time * 14.0 + seed_val) * 0.6
				wl.rotation.z = flap
				wr.rotation.z = -flap
		"fast_wisp":
			if visual_root.get_child_count() > 1:
				var outer: MeshInstance3D = visual_root.get_child(1)
				var s := 1.0 + sin(time * 9.0 + seed_val) * 0.12
				outer.scale = Vector3(s, s, s)
		"basic_drone":
			for child in visual_root.get_children():
				if child is Node3D and child.has_meta("base_y"):
					child.position.y = child.get_meta("base_y") + sin(time * 5.0 + seed_val) * 0.03

static func _build_ghost(v: Node3D) -> void:
	var pale := _mat(Color(0.75, 0.85, 0.95, 0.55), 0.0, BaseMaterial3D.TRANSPARENCY_ALPHA)
	var eye := _mat(Color(0.1, 0.2, 0.4, 1))
	var body := SphereMesh.new()
	body.radius = 0.42
	body.height = 0.84
	_mesh(v, body, pale, Vector3(0, 0.7, 0))
	var tail := SphereMesh.new()
	tail.radius = 0.3
	tail.height = 0.6
	var tail_mi := _mesh(v, tail, pale, Vector3(0, 0.25, 0))
	tail_mi.scale = Vector3(0.7, 1.0, 0.7)
	var e := SphereMesh.new()
	e.radius = 0.06
	e.height = 0.12
	_mesh(v, e, eye, Vector3(-0.12, 0.78, -0.34))
	_mesh(v, e, eye, Vector3(0.12, 0.78, -0.34))

static func _build_splitter(v: Node3D) -> void:
	var gel := _mat(Color(0.4, 0.8, 0.55, 0.85), 0.0, BaseMaterial3D.TRANSPARENCY_ALPHA)
	var inner := _mat(Color(0.25, 0.6, 0.4, 0.9), 0.0, BaseMaterial3D.TRANSPARENCY_ALPHA)
	var blob := SphereMesh.new()
	blob.radius = 0.55
	blob.height = 1.1
	_mesh(v, blob, gel, Vector3(0, 0.6, 0))
	var lobe := SphereMesh.new()
	lobe.radius = 0.22
	lobe.height = 0.44
	_mesh(v, lobe, inner, Vector3(-0.2, 0.55, 0))
	_mesh(v, lobe, inner, Vector3(0.2, 0.55, 0))

static func _build_healer(v: Node3D) -> void:
	var cloth := _mat(Color(0.92, 0.92, 0.88))
	var sigil := _mat(Color(0.4, 1.0, 0.5), 1.8)
	var robe := CylinderMesh.new()
	robe.top_radius = 0.22
	robe.bottom_radius = 0.42
	robe.height = 1.0
	_mesh(v, robe, cloth, Vector3(0, 0.5, 0))
	var head := SphereMesh.new()
	head.radius = 0.18
	head.height = 0.36
	_mesh(v, head, cloth, Vector3(0, 1.12, 0))
	var sig := SphereMesh.new()
	sig.radius = 0.12
	sig.height = 0.24
	_mesh(v, sig, sigil, Vector3(0.3, 0.95, 0.1))

static func _build_mage(v: Node3D) -> void:
	var robe_m := _mat(Color(0.35, 0.25, 0.5))
	var hat_m := _mat(Color(0.28, 0.18, 0.42))
	var orb_m := _mat(Color(0.8, 0.5, 1.0), 2.0)
	var robe := CylinderMesh.new()
	robe.top_radius = 0.24
	robe.bottom_radius = 0.5
	robe.height = 1.05
	_mesh(v, robe, robe_m, Vector3(0, 0.52, 0))
	var hat := CylinderMesh.new()
	hat.top_radius = 0.02
	hat.bottom_radius = 0.4
	hat.height = 0.45
	_mesh(v, hat, hat_m, Vector3(0, 1.45, 0))
	var brim := CylinderMesh.new()
	brim.top_radius = 0.4
	brim.bottom_radius = 0.4
	brim.height = 0.05
	_mesh(v, brim, hat_m, Vector3(0, 1.24, 0))
	var staff := CylinderMesh.new()
	staff.top_radius = 0.03
	staff.bottom_radius = 0.03
	staff.height = 1.3
	_mesh(v, staff, hat_m, Vector3(0.34, 0.85, 0.05))
	var orb := SphereMesh.new()
	orb.radius = 0.11
	orb.height = 0.22
	_mesh(v, orb, orb_m, Vector3(0.34, 1.5, 0.05))
