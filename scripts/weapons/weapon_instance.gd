class_name WeaponInstance
extends RefCounted
## One equipped weapon instance: owns level/tier, cooldown ticking, and
## firing through the targeting system. Generic across weapon types.

signal fired()

var data: WeaponData
var level: int = 1
var evolved: bool = false
var _cooldown_left: float = 0.0

var _combat_context: Node = null  # set by WeaponController

func setup(p_data: WeaponData, p_context: Node) -> void:
	data = p_data
	_combat_context = p_context
	_cooldown_left = 0.4

func tick(delta: float, player: Node3D, enemies: Node) -> void:
	if data == null or _combat_context == null:
		return
	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return

	var candidates: Array = enemies.get_enemies_in_radius(player.global_position, data.max_range)
	if candidates.is_empty():
		_cooldown_left = 0.1
		return

	# Prefer enemies in front of the camera (what the player can see).
	var cam: Camera3D = player.get_viewport().get_camera_3d()
	var target: Node3D = TargetingSystem.nearest_visible(player.global_position, candidates, data.max_range, cam)
	if target == null:
		_cooldown_left = 0.1
		return

	# Apply player attack_speed + cooldown_mult modifiers
	var cd := get_cooldown()
	if player.has_method("get_stat"):
		cd = cd / maxf(player.get_stat("attack_speed"), 0.1) * maxf(player.get_stat("cooldown_mult"), 0.2)
	_cooldown_left = maxf(cd, 0.15)
	_combat_context.fire_weapon(self, player, target)
	fired.emit()

# --- Stats with tier scaling ---

func get_damage() -> float:
	return data.base_damage * _tier_mult(data.tier_damage_mult)

func get_cooldown() -> float:
	return maxf(data.base_cooldown * _tier_mult(data.tier_cooldown_mult), 0.2)

func get_projectile_count() -> int:
	return data.projectile_count + _tier_bonus(data.tier_projectile_bonus)

func get_area() -> float:
	return data.area * _tier_mult(data.tier_area_mult)

func get_crit_chance() -> float:
	return data.crit_chance

func _tier_mult(arr: Array) -> float:
	var idx := clampi(level - 1, 0, arr.size() - 1)
	return arr[idx]

func _tier_bonus(arr: Array) -> int:
	var idx := clampi(level - 1, 0, arr.size() - 1)
	return arr[idx]

func level_up() -> void:
	var prev := level
	level = mini(level + 1, 5)
	if level == 5 and prev < 5 and EventBus != null:
		EventBus.upgrade_applied.emit("%s MAX TIER" % data.display_name)
