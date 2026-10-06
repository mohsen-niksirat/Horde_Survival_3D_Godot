extends Node3D
## Expansion stage mechanics. Three reusable meshes, no per-tick spawning,
## physics areas, dynamic lights, transparent particles or navigation meshes.
const WARNING_TIME := 1.6
const STRIKE_RADIUS := 2.4
const STRIKE_DAMAGE := 18.0
const STORM_INTERVAL := 7.0
const SANCTUARY_RADIUS := 3.0
const SANCTUARY_INTERVAL := 18.0
const SANCTUARY_POSITIONS := [Vector3(-9, 0, -9), Vector3(9, 0, -9), Vector3(9, 0, 9), Vector3(-9, 0, 9)]

var map_id := ""
var player: Node3D
var rings: Array[MeshInstance3D] = []
var _warning_material: StandardMaterial3D
var _hit_material: StandardMaterial3D
var _safe_material: StandardMaterial3D
var _timer := 4.0
var _warning_left := 0.0
var _flash_left := 0.0
var _heal_timer := 1.0
var _sanctuary_index := 0
var _label: Label

func setup(target: Node3D, stage_id: String) -> void:
	player = target
	map_id = stage_id
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if map_id not in ["storm_ruins", "hollow_grove"]:
		set_process(false)
		return
	_warning_material = _material(Color(1.0, 0.65, 0.08))
	_hit_material = _material(Color(1.0, 0.95, 0.8))
	_safe_material = _material(Color(0.12, 0.9, 0.45))
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.92
	mesh.outer_radius = 1.0
	mesh.rings = 20
	mesh.ring_segments = 4
	for i in range(3):
		var ring := MeshInstance3D.new()
		ring.mesh = mesh
		ring.material_override = _warning_material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		rings.append(ring)
	_build_landmarks()
	_build_hint()
	if map_id == "hollow_grove":
		_timer = SANCTUARY_INTERVAL
		_move_sanctuary()

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat

func _build_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_label.offset_left = -155.0
	_label.offset_right = 155.0
	_label.offset_top = -100.0
	_label.offset_bottom = -64.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_label)
	_label.text = "STORM RUINS | Avoid amber rings" if map_id == "storm_ruins" else "HOLLOW GROVE | Green ring heals"

func _build_landmarks() -> void:
	# One draw batch; geometry and material shared by all twelve landmarks.
	var crystal := CylinderMesh.new()
	crystal.top_radius = 0.0
	crystal.bottom_radius = 0.6
	crystal.height = 2.2
	crystal.radial_segments = 5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = crystal
	mm.instance_count = 12
	for i in range(12):
		var angle := TAU * float(i) / 12.0
		var pos := Vector3(cos(angle) * 19.0, 1.1, sin(angle) * 19.0)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, angle), pos))
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = mm
	batch.material_override = _material(Color(0.35, 0.25, 0.65) if map_id == "storm_ruins" else Color(0.16, 0.36, 0.18))
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not RunManager.is_running:
		return
	if GameManager.state not in [GameManager.State.PLAYING, GameManager.State.BOSS]:
		return
	if map_id == "storm_ruins":
		_tick_storm(delta)
	elif map_id == "hollow_grove":
		_tick_sanctuary(delta)

func _tick_storm(delta: float) -> void:
	if _warning_left > 0.0:
		_warning_left -= delta
		if _warning_left <= 0.0:
			_resolve_strike()
		return
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			for ring in rings:
				ring.visible = false
		return
	_timer -= delta
	if _timer <= 0.0:
		_begin_warning()

func _begin_warning() -> void:
	_timer = STORM_INTERVAL
	_warning_left = WARNING_TIME
	var origin := player.global_position
	for i in range(rings.size()):
		var offset := Vector3.ZERO if i == 0 else Vector3(6.0 * (1.0 if i == 1 else -1.0), 0, 3.5)
		var pos := origin + offset
		pos.x = clampf(pos.x, -57.0, 57.0)
		pos.z = clampf(pos.z, -57.0, 57.0)
		pos.y = 0.08
		rings[i].global_position = pos
		rings[i].scale = Vector3(STRIKE_RADIUS, 0.22, STRIKE_RADIUS)
		rings[i].material_override = _warning_material
		rings[i].visible = true
	_label.text = "LIGHTNING INCOMING — STEP OUT!"

func _inside_ring(ring: Node3D, radius: float) -> bool:
	var offset := player.global_position - ring.global_position
	offset.y = 0.0
	return offset.length_squared() <= radius * radius

func _resolve_strike() -> void:
	var hit := false
	for ring in rings:
		ring.material_override = _hit_material
		if _inside_ring(ring, STRIKE_RADIUS):
			hit = true
	# Overlapping telegraphs never multiply one strike's damage.
	if hit and player.has_method("take_contact_damage"):
		player.take_contact_damage(STRIKE_DAMAGE, player.global_position - Vector3.FORWARD)
	_flash_left = 0.22
	_label.text = "STORM RUINS | Keep moving"

func _move_sanctuary() -> void:
	rings[0].global_position = SANCTUARY_POSITIONS[_sanctuary_index] + Vector3(0, 0.08, 0)
	rings[0].scale = Vector3(SANCTUARY_RADIUS, 0.22, SANCTUARY_RADIUS)
	rings[0].material_override = _safe_material
	rings[0].visible = true

func _tick_sanctuary(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = SANCTUARY_INTERVAL
		_sanctuary_index = (_sanctuary_index + 1) % SANCTUARY_POSITIONS.size()
		_move_sanctuary()
	_heal_timer -= delta
	if _heal_timer <= 0.0:
		_heal_timer = 1.0
		var inside := _inside_ring(rings[0], SANCTUARY_RADIUS)
		if inside:
			player.health.heal(2.0)
		_label.text = "SANCTUARY | +2 HP/sec" if inside else "HOLLOW GROVE | Find the green ring"
