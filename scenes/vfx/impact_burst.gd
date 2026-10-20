extends Node3D
## Lightweight pooled hit reaction: expanding flash ring + short light pulse.
## Kept deliberately cheap for web horde combat; crits receive a larger burst.

const LIFETIME := 0.18
var _life := 0.0
var _active := false
var _base_scale := 1.0

@onready var ring: MeshInstance3D = $Ring
@onready var core: MeshInstance3D = $Core
@onready var light: OmniLight3D = $Light

func _ready() -> void:
	visible = false

func trigger(pos: Vector3, color: Color, critical: bool = false) -> void:
	global_position = pos + Vector3(0, 0.55, 0)
	_base_scale = 1.35 if critical else 0.9
	var ring_mat := ring.get_surface_override_material(0) as StandardMaterial3D
	var core_mat := core.get_surface_override_material(0) as StandardMaterial3D
	if ring_mat != null:
		ring_mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
		ring_mat.emission = color
		ring_mat.emission_energy_multiplier = 3.2 if critical else 1.8
	if core_mat != null:
		core_mat.albedo_color = Color(1, 0.95, 0.7, 1)
		core_mat.emission = color
		core_mat.emission_energy_multiplier = 4.0 if critical else 2.0
	if light != null:
		light.light_color = color
		light.light_energy = 3.5 if critical else 1.8
		light.visible = PerformanceManager.prefer_dynamic_lights() if PerformanceManager != null else true
	_life = 0.0
	_active = true
	visible = true
	ring.scale = Vector3.ONE * (_base_scale * 0.35)
	core.scale = Vector3.ONE * (_base_scale * 0.45)

func _process(delta: float) -> void:
	if not _active:
		return
	_life += minf(delta, LIFETIME * 0.5)
	var t := clampf(_life / LIFETIME, 0.0, 1.0)
	var grow := _base_scale * (0.35 + t * 0.9)
	ring.scale = Vector3.ONE * grow
	core.scale = Vector3.ONE * (_base_scale * (0.45 + (1.0 - t) * 0.3))
	var ring_mat := ring.get_surface_override_material(0) as StandardMaterial3D
	if ring_mat != null:
		ring_mat.albedo_color.a = 0.9 * (1.0 - t)
	if light != null and light.visible:
		light.light_energy = (3.5 if _base_scale > 1.0 else 1.8) * (1.0 - t)
	if _life >= LIFETIME:
		_active = false
		visible = false
		if light != null:
			light.visible = false
