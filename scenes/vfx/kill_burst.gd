extends Node3D
## KillBurst VFX: quick expanding ring + light pulse at death position.
## Pooled, color-tinted by the dying enemy's archetype color.

const LIFETIME := 0.35

var _life: float = 0.0
var _active: bool = false

@onready var ring: MeshInstance3D = $Ring
@onready var core: MeshInstance3D = $Core
@onready var light: OmniLight3D = $Light

func _ready() -> void:
	visible = false

func trigger(pos: Vector3, color: Color) -> void:
	global_position = Vector3(pos.x, 0.1, pos.z)
	var mat: StandardMaterial3D = ring.get_surface_override_material(0)
	if mat != null:
		mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
		mat.emission = color
	var core_mat: StandardMaterial3D = core.get_surface_override_material(0)
	if core_mat != null:
		core_mat.albedo_color = Color(1.0, 0.8, 0.2, 0.95)
		core_mat.emission = color
		core_mat.emission_energy_multiplier = 3.0
	if light != null:
		light.light_color = color
		light.visible = PerformanceManager.prefer_dynamic_lights() if PerformanceManager != null else true
	_life = 0.0
	_active = true
	visible = true

func _process(delta: float) -> void:
	if not _active:
		return
	_life += delta
	var t := _life / LIFETIME
	ring.scale = Vector3.ONE * (0.5 + t * 2.5)
	core.scale = Vector3.ONE * (1.2 + (1.0 - t) * 1.4)
	ring.get_surface_override_material(0).albedo_color.a = clampf(1.0 - t, 0.0, 1.0)
	core.get_surface_override_material(0).albedo_color.a = clampf(1.0 - t, 0.0, 1.0)
	if light != null and light.visible:
		light.light_energy = clampf(3.0 * (1.0 - t), 0.0, 3.0)
	if _life > LIFETIME:
		_active = false
		visible = false
