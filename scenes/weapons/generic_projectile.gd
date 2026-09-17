extends Area3D
## Generic projectile: straight or homing flight, single-target + optional
## pierce, status application. Pooled. Fireball keeps its own AOE scene.

const LIFETIME := 4.0
const HOMING_TURN_RATE := 6.0

var damage: float = 10.0
var speed: float = 20.0
var pierce_left: int = 0
var crit_chance: float = 0.05
var homing: bool = false
var status_effect: String = ""
var status_duration: float = 0.0

var _velocity: Vector3 = Vector3.ZERO
var _life: float = 0.0
var _active: bool = false
var _weapon_id: String = "projectile"
var _hit_enemies: Array = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup_generic(p_damage: float, p_speed: float, p_pierce: int, p_crit: float,
		p_homing: bool, p_status: String, p_status_dur: float,
		from_pos: Vector3, dir: Vector3, p_weapon_id: String) -> void:
	damage = p_damage
	speed = p_speed
	pierce_left = p_pierce
	crit_chance = p_crit
	homing = p_homing
	status_effect = p_status
	status_duration = p_status_dur
	_weapon_id = p_weapon_id
	global_position = from_pos
	_hit_enemies.clear()
	_velocity = dir * speed
	_life = 0.0
	_active = true
	visible = true
	monitoring = true
	var light := get_node_or_null("Light")
	if light is Light3D:
		light.visible = PerformanceManager.prefer_dynamic_lights() if PerformanceManager != null else true

func _physics_process(delta: float) -> void:
	if not _active:
		return
	_life += delta
	if _life > LIFETIME:
		_deactivate()
		return

	if homing:
		var target := _find_nearest_enemy()
		if target != null:
			var desired := (target.global_position + Vector3(0, 0.5, 0) - global_position).normalized() * speed
			_velocity = _velocity.slerp(desired, minf(HOMING_TURN_RATE * delta, 1.0))

	global_position += _velocity * delta
	if absf(global_position.x) > 62.0 or absf(global_position.z) > 62.0:
		_deactivate()

func _find_nearest_enemy() -> Node3D:
	var em: Node = _get_enemy_manager()
	if em == null:
		return null
	var list: Array = em.get_enemies_in_radius(global_position, 15.0, 1)
	return list[0] if not list.is_empty() else null

func _on_body_entered(body: Node3D) -> void:
	if not _active or not body.is_in_group("enemies"):
		return
	if body in _hit_enemies:
		return
	_hit_enemies.append(body)

	var is_crit := randf() < crit_chance
	var event := DamageEvent.new(damage * (2.0 if is_crit else 1.0), _weapon_id, is_crit)
	event.status_effect = status_effect
	event.status_duration = status_duration
	body.health.take_damage(event)
	EventBus.enemy_damaged.emit(body, event.final_amount, is_crit)

	if pierce_left > 0:
		pierce_left -= 1
	else:
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
	monitoring = false
	PoolManager.release(self)
