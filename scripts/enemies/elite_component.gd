extends Node
## EliteComponent: modular elite modifiers applied to a normal enemy.
## Reference-game ability set: teleport, shield, explode, healer aura,
## speed boost, split, vampiric, thorns.

const EliteAbilityC := preload("res://scripts/enemies/elite_ability.gd")

signal request_minions(count: int, position: Vector3)

var abilities: Array = []
var enemy: CharacterBody3D
var player: Node3D
var enemy_manager: Node

# Ability state
var _teleport_timer: float = 3.0
var _heal_timer: float = 2.0
var _shield_hp: float = 0.0
var _shield_active: bool = false

func _ready() -> void:
	# Every enemy owns one of these; only promoted elites need per-frame work.
	set_process(false)

func setup(p_enemy: CharacterBody3D, p_player: Node3D, p_enemy_manager: Node, p_abilities: Array) -> void:
	enemy = p_enemy
	player = p_player
	enemy_manager = p_enemy_manager
	abilities = p_abilities
	_teleport_timer = randf_range(1.0, 3.0)
	_heal_timer = 2.0
	if EliteAbilityC.SHIELDED in abilities:
		_shield_hp = enemy.health.max_hp * 0.3
	enemy.health.damage_interceptor = Callable(self, "on_damaged")
	set_process(true)

## Called when a pooled enemy is recycled back into a normal enemy.
func disable() -> void:
	set_process(false)
	abilities.clear()
	enemy = null
	player = null
	enemy_manager = null
	_shield_hp = 0.0
	_shield_active = false

func _process(delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_enemy_alive():
		return

	if EliteAbilityC.TELEPORT in abilities:
		_tick_teleport(delta)
	if EliteAbilityC.HEALER_AURA in abilities:
		_tick_healer_aura(delta)
	if EliteAbilityC.SHIELDED in abilities:
		_tick_shield()
	if EliteAbilityC.SPEED_BOOST in abilities:
		_tick_speed_boost()

func _tick_teleport(delta: float) -> void:
	_teleport_timer -= delta
	if _teleport_timer <= 0.0:
		_teleport_timer = 3.0
		var angle := randf() * TAU
		var dist := randf_range(4.0, 7.0)
		var pos := player.global_position + Vector3(cos(angle), 0, sin(angle)) * dist
		if enemy_manager.arena_ref.is_inside_bounds(pos):
			enemy.global_position = pos

func _tick_healer_aura(delta: float) -> void:
	_heal_timer -= delta
	if _heal_timer <= 0.0:
		_heal_timer = 2.0
		var allies: Array = enemy_manager.get_enemies_in_radius(enemy.global_position, 5.0)
		for ally in allies:
			if ally != enemy and ally.health.is_alive():
				ally.health.heal(ally.health.max_hp * 0.05)

func _tick_shield() -> void:
	# Shield activates below 50% HP, absorbs damage first (30% max HP pool).
	if not _shield_active and enemy.health.get_ratio() < 0.5:
		_shield_active = true
		_shield_hp = enemy.health.max_hp * 0.3

func _tick_speed_boost() -> void:
	# x1.5 speed under 50% HP, x2.0 under 30% — via status component params.
	var ratio: float = enemy.health.get_ratio()
	if ratio < 0.3:
		enemy.spd_scale = enemy.base_spd_scale * 2.0
	elif ratio < 0.5:
		enemy.spd_scale = enemy.base_spd_scale * 1.5
	else:
		enemy.spd_scale = enemy.base_spd_scale

## Damage interceptor (wired to health.damage_interceptor).
## Shield absorbs first; thorns reflect to the player.
## Returns the adjusted damage.
func on_damaged(event: DamageEvent) -> float:
	var dmg: float = event.amount
	if EliteAbilityC.SHIELDED in abilities and _shield_active and _shield_hp > 0.0:
		var absorbed: float = minf(_shield_hp, dmg)
		_shield_hp -= absorbed
		dmg -= absorbed
	if EliteAbilityC.THORNS in abilities and player != null and is_instance_valid(player):
		player.take_contact_damage(event.amount * 0.3, enemy.global_position)
	return dmg

func on_hit_player() -> void:
	if EliteAbilityC.VAMPIRIC in abilities:
		enemy.health.heal(enemy.health.max_hp * 0.05)

func on_death() -> void:
	if EliteAbilityC.EXPLODE_ON_DEATH in abilities and player != null and is_instance_valid(player):
		if player.global_position.distance_to(enemy.global_position) <= 4.0:
			player.take_contact_damage(25.0, enemy.global_position)
	if EliteAbilityC.SPLIT_ON_DEATH in abilities:
		request_minions.emit(3, enemy.global_position)
