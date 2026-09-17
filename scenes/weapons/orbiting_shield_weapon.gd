extends Node3D
## OrbitingShield weapon: N shields orbit the player on the horizontal plane,
## damaging enemies on contact with per-enemy hit cooldown (grid queries,
## not physics). Lives under the player; driven by WeaponController.

const SHIELD_RADIUS_BASE := 2.2
const HIT_COOLDOWN := 0.35
## P2 feel: the orbit breathes in and out while it spins.
const RADIUS_PULSE := 0.35
@export var shield_scene: PackedScene

var _weapon: WeaponInstance
var _player: Node3D
var _shields: Array = []
var _angle: float = 0.0
var _hit_cooldowns: Dictionary = {}  # instance_id -> timestamp
var _enemy_manager: Node = null
var _prune_accum: float = 0.0

func setup(weapon: WeaponInstance, player: Node3D) -> void:
	_weapon = weapon
	_player = player
	_enemy_manager = null
	_hit_cooldowns.clear()
	if shield_scene == null:
		shield_scene = load("res://scenes/weapons/OrbitShield.tscn")
	_sync_shields()

func _process(delta: float) -> void:
	if _weapon == null or _player == null or not is_instance_valid(_player):
		return
	global_position = _player.global_position
	_angle += 2.0 * delta  # rad/s

	var count := _weapon.get_projectile_count()
	_sync_shields(count)
	var radius: float = SHIELD_RADIUS_BASE * sqrt(_weapon.get_area())
	# Breathing radius: expands ~35% and returns
	radius *= 1.0 + (sin(_angle * 1.5) * 0.5 + 0.5) * RADIUS_PULSE

	var now := Time.get_ticks_msec() / 1000.0
	_prune_accum += delta
	if _prune_accum > 2.0:
		_prune_accum = 0.0
		_prune_cooldowns(now)
	for i in range(_shields.size()):
		var shield: Node3D = _shields[i]
		var a := _angle + TAU * i / count
		shield.position = Vector3(cos(a) * radius, 1.0, sin(a) * radius)
		_check_hits(shield, now)

func _prune_cooldowns(now: float) -> void:
	if _hit_cooldowns.is_empty():
		return
	var stale: Array = []
	for id in _hit_cooldowns:
		if now - float(_hit_cooldowns[id]) > HIT_COOLDOWN * 4.0:
			stale.append(id)
	for id in stale:
		_hit_cooldowns.erase(id)

func _sync_shields(count: int = -1) -> void:
	if count < 0:
		count = _weapon.get_projectile_count() if _weapon != null else 1
	while _shields.size() < count:
		var s := shield_scene.instantiate()
		add_child(s)
		_shields.append(s)
	while _shields.size() > count:
		var s: Node3D = _shields.pop_back()
		s.queue_free()

func _check_hits(shield: Node3D, now: float) -> void:
	var em: Node = _find_enemy_manager()
	if em == null:
		return
	var hits: Array = em.get_enemies_in_radius(shield.global_position, 0.8)
	var might: float = 1.0
	var base_dmg := 16.0
	if _player.has_method("get_stat"):
		might = _player.get_stat("might")
	if _weapon != null:
		base_dmg = _weapon.get_damage()
	for enemy in hits:
		if not is_instance_valid(enemy) or enemy.get("health") == null:
			continue
		var id: int = enemy.get_instance_id()
		var last: float = _hit_cooldowns.get(id, -100.0)
		if now - last < HIT_COOLDOWN:
			continue
		_hit_cooldowns[id] = now
		var event := DamageEvent.new(base_dmg * might, "orbit_shield")
		enemy.health.take_damage(event)
		EventBus.enemy_damaged.emit(enemy, event.final_amount, false)

func _find_enemy_manager() -> Node:
	if _enemy_manager != null and is_instance_valid(_enemy_manager):
		return _enemy_manager
	_enemy_manager = get_tree().get_first_node_in_group("enemy_manager")
	if _enemy_manager != null:
		return _enemy_manager
	var parent := get_parent()
	while parent != null:
		if parent.has_method("get_enemy_manager"):
			_enemy_manager = parent.get_enemy_manager()
			return _enemy_manager
		parent = parent.get_parent()
	return null
