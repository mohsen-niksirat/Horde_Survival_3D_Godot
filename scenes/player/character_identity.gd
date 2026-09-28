extends Node3D
## V16: character identity VFX — per-character color, Paladin aura,
## Rogue move trail. Attached under the player body at runtime.

const AURA_COLOR := Color(1.0, 0.88, 0.35)
const TRAIL_COLOR := Color(0.4, 1.0, 0.6)

var _player: Node3D
var _character_id: String = "mage"
var _aura: MeshInstance3D = null
var _trail_timer: float = 0.0
var _was_moving: bool = false

func setup(player: Node3D) -> void:
	_player = player
	_character_id = GameManager.selected_character_id if GameManager != null else "mage"
	if _character_id == "paladin":
		_spawn_aura()
	elif _character_id == "rogue":
		_spawn_trail_root()

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var speed: float = 0.0
	if _player.get("movement") != null:
		speed = _player.movement.get_current_speed()
	var moving := speed > 0.5
	if _character_id == "paladin" and _aura != null:
		var t := Time.get_ticks_msec() / 1000.0
		var pulse := 1.0 + 0.06 * sin(t * 2.2)
		_aura.scale = Vector3(pulse, 1.0, pulse)
		var mat := _aura.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = 1.2 + 0.4 * (0.5 + 0.5 * sin(t * 2.2))
	if _character_id == "rogue":
		if moving and not _was_moving:
			_emit_trail()
		_was_moving = moving
		_trail_timer -= delta
		if moving and _trail_timer <= 0.0:
			_trail_timer = 0.18
			_emit_trail()

func _spawn_aura() -> void:
	_aura = MeshInstance3D.new()
	_aura.name = "PaladinAura"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.15
	torus.outer_radius = 1.45
	_aura.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(AURA_COLOR.r, AURA_COLOR.g, AURA_COLOR.b, 0.55)
	mat.emission_enabled = true
	mat.emission = AURA_COLOR
	mat.emission_energy_multiplier = 1.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aura.material_override = mat
	_aura.position = Vector3(0, 0.08, 0)
	add_child(_aura)

func _spawn_trail_root() -> void:
	# Trail puffs are pooled as short-lived MeshInstance3D discs under this node
	pass

func _emit_trail() -> void:
	if _player == null:
		return
	var puff := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.22
	disc.bottom_radius = 0.28
	disc.height = 0.06
	puff.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, 0.55)
	mat.emission_enabled = true
	mat.emission = TRAIL_COLOR
	mat.emission_energy_multiplier = 0.9
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material_override = mat
	puff.global_position = _player.global_position + Vector3(0, 0.12, 0)
	get_tree().current_scene.add_child(puff)
	var tw := puff.create_tween()
	tw.tween_property(puff, "scale", Vector3(1.8, 0.2, 1.8), 0.35)
	tw.parallel().tween_property(puff, "position:y", puff.position.y + 0.25, 0.35)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(puff.queue_free)
