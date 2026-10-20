extends Area3D
## Boss projectile: straight flight, damages the player on contact. Pooled.

const LIFETIME := 4.5
const SPEED := 6.5

var damage: float = 14.0
var _velocity: Vector3 = Vector3.ZERO
var _life: float = 0.0
var _active: bool = false
var _player: Node3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(from_pos: Vector3, dir: Vector3, p_damage: float, p_player: Node3D) -> void:
	damage = p_damage
	_player = p_player
	global_position = from_pos
	_velocity = dir.normalized() * SPEED
	_life = 0.0
	_active = true
	visible = true
	monitoring = true

func _physics_process(delta: float) -> void:
	if not _active:
		return
	_life += delta
	if _life > LIFETIME or absf(global_position.x) > 62.0 or absf(global_position.z) > 62.0:
		_deactivate()
		return
	global_position += _velocity * delta
	# Tumble + flicker so the bolt reads as an unstable energy orb.
	rotation.y += delta * 6.0
	rotation.z += delta * 4.0
	var mat: StandardMaterial3D = ($Mesh as MeshInstance3D).get_surface_override_material(0)
	if mat != null:
		mat.emission_energy_multiplier = 1.4 + sin(_life * 25.0) * 0.3
	var core_mat: StandardMaterial3D = ($Core as MeshInstance3D).get_surface_override_material(0)
	if core_mat != null:
		core_mat.emission_energy_multiplier = 2.8 + sin(_life * 40.0) * 0.6

func _on_body_entered(body: Node3D) -> void:
	if not _active:
		return
	if body.is_in_group("player"):
		body.take_contact_damage(damage, global_position)
		_deactivate()

func _deactivate() -> void:
	_active = false
	# Deferred: _deactivate can run inside the body_entered physics callback
	set_deferred("monitoring", false)
	PoolManager.release(self)
