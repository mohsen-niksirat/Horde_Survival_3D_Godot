class_name WeaponBalance
extends RefCounted
## Single source of truth for weapon DPS math.
##
## The numbers are derived from the real firing code
## (scripts/weapons/weapon_controller.gd) so the balance table, the balance
## guard test and the in-game codex always agree.
##
## Model — sustained damage per second against a SINGLE target:
##  - projectile / pierce: every projectile of a volley lands on the target
##    when it is alone (`_spawn_projectile` reuses the same target when
##    there are not enough enemies), so DPS = damage x count / cooldown.
##  - aoe: one strike per cooldown, so DPS = damage / cooldown. The blast
##    radius hits several enemies at once, which is a crowd advantage this
##    single-target number deliberately leaves out.
##  - orbit: the shields sweep at ORBIT_ANGULAR_SPEED rad/s, so one lap
##    takes ORBIT_PERIOD seconds and every shield can reach the same enemy.
##
## Consequence: only projectile and pierce weapons receive
## `tier_projectile_bonus` from the tier curves. AoE and orbit weapons have
## to compensate in their own `tier_damage_mult` (see data/weapons/*.tres).

## Angular speed of the orbiting shields, rad/s.
const ORBIT_ANGULAR_SPEED := 2.0
## Seconds for one full lap of the orbiting shields.
const ORBIT_PERIOD := TAU / ORBIT_ANGULAR_SPEED

## Sustained single-target DPS of a weapon at the given level (1..5).
static func dps_at(data: WeaponData, level: int) -> float:
	if data == null:
		return 0.0
	var idx := clampi(level - 1, 0, 4)
	var dmg_mult: float = _mult(data.tier_damage_mult, idx)
	var cd_mult: float = _mult(data.tier_cooldown_mult, idx)
	var count_bonus: int = _bonus(data.tier_projectile_bonus, idx)
	var count := data.projectile_count + count_bonus
	var damage := data.base_damage * dmg_mult
	var cooldown := maxf(data.base_cooldown * cd_mult, 0.2)
	match data.type:
		"aoe":
			return damage / cooldown
		"orbit":
			return damage * count / ORBIT_PERIOD
		_:
			return damage * count / cooldown

## DPS for every tier of a weapon, index 0 = level 1.
static func dps_curve(data: WeaponData) -> Array:
	var out: Array = []
	for lvl in range(1, 6):
		out.append(dps_at(data, lvl))
	return out

## Growth factor from level 1 to level 5.
static func growth(data: WeaponData) -> float:
	var curve := dps_curve(data)
	if curve.is_empty():
		return 0.0
	return float(curve[curve.size() - 1]) / maxf(float(curve[0]), 0.01)

static func _mult(arr: Array, idx: int) -> float:
	if idx < 0 or idx >= arr.size():
		return 1.0
	return float(arr[idx])

static func _bonus(arr: Array, idx: int) -> int:
	if idx < 0 or idx >= arr.size():
		return 0
	return int(arr[idx])
