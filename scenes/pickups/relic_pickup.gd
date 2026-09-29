extends Area3D
## Relic pickup: rotating diamond with rarity color, magnetless (walk over it).

const GRAVITY := 18.0

var data: RelicData
var _player: Node3D
var _life: float = 0.0
var _max_life: float = 120.0
var _vertical_velocity: float = 3.0
var _settled: bool = false
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("relics")
	body_entered.connect(_on_body_entered)
	_mesh = $Mesh
	_mat = _mesh.get_surface_override_material(0)
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mesh.set_surface_override_material(0, _mat)
	# Treasure chest instead of the spinning diamond prism.
	if _mesh.get_child_count() == 0:
		var rig := RigUtil.attach_glb(_mesh, "res://assets/models/kaykit/env/chest.glb", 0.9, "ChestRig")
		if rig != null:
			_mesh.mesh = null

func setup(p_data: RelicData, p_player: Node3D, pos: Vector3, lifetime: float) -> void:
	data = p_data
	_player = p_player
	_life = 0.0
	_max_life = lifetime
	_settled = false
	_vertical_velocity = 3.0
	global_position = pos + Vector3(0, 0.8, 0)
	_mat.albedo_color = _rarity_color(data.rarity)
	_mat.emission = _rarity_color(data.rarity)
	var rig := _mesh.get_node_or_null("ChestRig")
	if rig != null:
		for mi in rig.find_children("*", "MeshInstance3D", true, false):
			var active = mi.get_active_material(0)
			if active is StandardMaterial3D:
				var tinted: StandardMaterial3D = (active as StandardMaterial3D).duplicate()
				tinted.albedo_color = tinted.albedo_color.lerp(_rarity_color(data.rarity), 0.45)
				mi.set_surface_override_material(0, tinted)
	visible = true
	monitoring = true
	# T2: taller beacon pillar so chests are findable mid-horde
	if get_node_or_null("Beacon") == null:
		_spawn_beacon(_rarity_color(data.rarity))

func _spawn_beacon(color: Color) -> void:
	var beacon := MeshInstance3D.new()
	beacon.name = "Beacon"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.35
	cyl.height = 2.8
	beacon.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.18)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.7
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon.material_override = mat
	beacon.position = Vector3(0, 1.6, 0)
	add_child(beacon)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon": return Color(0.42, 0.85, 0.5)
		"rare": return Color(0.42, 0.71, 1.0)
		"legendary": return Color(1.0, 0.84, 0.0)
		_: return Color(0.75, 0.78, 0.82)

func _process(delta: float) -> void:
	_life += delta
	if _life > _max_life:
		queue_free()
		return
	# Slow spin (visual identity)
	_mesh.rotation.y += 2.0 * delta
	# P2 pickup readability: pulsing glow so relics stand out mid-horde
	if _mat != null:
		_mat.emission_energy_multiplier = 1.2 + sin(_life * 5.0) * 0.8
		_mesh.scale = Vector3.ONE * (1.0 + sin(_life * 3.0) * 0.12)
	# Settle to ground
	if not _settled:
		_vertical_velocity -= GRAVITY * delta
		global_position.y += _vertical_velocity * delta
		if global_position.y <= 0.6:
			global_position.y = 0.6
			_settled = true
	# Blink before expiring
	if _max_life - _life < 10.0:
		visible = int(_life * 4.0) % 2 == 0

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or data == null:
		return
	var relics: Node = _find_relic_system()
	if relics != null:
		relics.apply_relic(data)
	queue_free()

func _find_relic_system() -> Node:
	# RelicSystem is a sibling under Main, not an ancestor of Projectiles
	if get_tree() != null:
		var by_group := get_tree().get_first_node_in_group("relic_system")
		if by_group != null:
			return by_group
	var parent := get_parent()
	while parent != null:
		if parent.has_method("apply_relic"):
			return parent
		parent = parent.get_parent()
	return null
