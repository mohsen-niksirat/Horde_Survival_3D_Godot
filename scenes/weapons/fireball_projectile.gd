extends Area3D
## Fireball projectile: travels toward aim, AOE explosion on impact.
## Pooled. Applies damage through the unified DamageEvent pipeline.

const GRAVITYLESS := true
const LIFETIME := 4.0

var damage: float = 20.0
var aoe_radius: float = 2.2
var crit_chance: float = 0.05
var weapon_data: WeaponData

var _velocity: Vector3 = Vector3.ZERO
var _life: float = 0.0
var _active: bool = false
var _owner_weapon: WeaponInstance

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup_fireball(weapon: WeaponInstance, p_damage: float, p_area: float, p_crit: float, p_data: WeaponData, from_pos: Vector3, dir: Vector3) -> void:
	_owner_weapon = weapon
	damage = p_damage
	aoe_radius = p_area
	crit_chance = p_crit
	weapon_data = p_data
	global_position = from_pos
	_velocity = dir * p_data.projectile_speed
	_life = 0.0
	_active = true
	visible = true
	monitoring = true
	_gate_vfx()

func _gate_vfx() -> void:
	var light := get_node_or_null("Light")
	if light is Light3D:
		light.visible = PerformanceManager.prefer_dynamic_lights() if PerformanceManager != null else true
	var trail := get_node_or_null("Trail")
	if trail is GPUParticles3D:
		trail.amount = 10 if (PerformanceManager == null or PerformanceManager.quality >= PerformanceManager.Quality.MEDIUM) else 4

func _physics_process(delta: float) -> void:
	if not _active:
		return
	_life += delta
	if _life > LIFETIME:
		_deactivate()
		return
	global_position += _velocity * delta
	# Flicker the glow while flying
	var mat: StandardMaterial3D = ($Mesh as MeshInstance3D).get_surface_override_material(0)
	if mat != null:
		mat.emission_energy_multiplier = 2.0 + sin(_life * 30.0) * 0.5
	# Despawn outside arena
	if absf(global_position.x) > 62.0 or absf(global_position.z) > 62.0:
		_deactivate()

func _on_body_entered(body: Node3D) -> void:
	if not _active:
		return
	if body.is_in_group("enemies"):
		_explode()
	elif body.collision_layer & 16:  # world layer 5
		_deactivate()

func _explode() -> void:
	if not _active:
		return
	_active = false
	# AOE damage via owner's enemy manager
	var em: Node = _get_enemy_manager()
	if em != null:
		var hits: Array = em.get_enemies_in_radius(global_position, aoe_radius)
		var is_crit := randf() < crit_chance
		for enemy in hits:
			if not is_instance_valid(enemy) or enemy.get("health") == null:
				continue
			var event := DamageEvent.new(damage * (2.0 if is_crit else 1.0), "fireball", is_crit)
			if weapon_data != null and weapon_data.status_effect != "":
				event.status_effect = weapon_data.status_effect
				event.status_duration = weapon_data.status_duration
			enemy.health.take_damage(event)
			EventBus.enemy_damaged.emit(enemy, event.final_amount, is_crit)
	_deactivate()

func _get_enemy_manager() -> Node:
	var parent := get_parent()
	while parent != null:
		if parent.has_method("get_enemy_manager"):
			return parent.get_enemy_manager()
		parent = parent.get_parent()
	return null

func _deactivate() -> void:
	_active = false
	set_deferred("monitoring", false)
	PoolManager.release(self)
