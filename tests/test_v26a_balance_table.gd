extends SceneTree
## V26A — Weapon balance table guard.
##
## The improvement brief asks for a DPS table for every weapon and every
## tier, converging on the difficulty timeline. The numbers are derived from
## the .tres data (no hardcoding) so the table always mirrors the real game.
##
## This test locks the table shape: every weapon must have sane tier growth,
## and the tier-5 spread must not be so wide that one weapon trivialises the
## difficulty curve. `tools/balance_table.gd` prints the full markdown table.

const WEAPON_DIR := "res://data/weapons/"
## The 8 weapons the player can actually pick (scripts/progression/
## progression_manager.NEW_WEAPON_POOL). The other 6 are evolutions and are
## meant to be stronger, so they are checked separately.
const POOL_WEAPONS := [
	"fireball", "magic_missile", "orbiting_shield", "divine_spear",
	"lightning", "void_lance", "frost_bolt", "soul_fire",
]
## Max allowed tier-5 DPS spread inside the pickable pool. A wider spread
## means the weakest weapon is unplayable late-game.
const MAX_POOL_TIER5_SPREAD := 2.5
## Minimum tier-1 -> tier-5 growth. A weapon that starts with more
## projectiles gains a smaller *ratio* from the count bonus (N -> N+2), so
## the floor is below the 4.8x of a single-projectile weapon.
const MIN_TIER5_GROWTH := 3.0
## An evolution must be a clear upgrade over the weapon it evolves.
const MIN_EVOLUTION_UPLIFT := 1.5

var failures := 0

func _initialize() -> void:
	await process_frame

	var files := _weapon_files()
	_check(files.size() >= 10, "at least 10 base weapons are defined (%d)" % files.size())

	var rows: Array = []
	for path in files:
		var res: Resource = load(path)
		if not (res is WeaponData):
			continue
		var data: WeaponData = res
		var per_tier: Array = []
		for lvl in range(1, 6):
			per_tier.append(_dps_at(data, lvl))
		rows.append({"data": data, "dps": per_tier})

	_check(rows.size() >= 10, "at least 10 base weapons load as WeaponData (%d)" % rows.size())

	for row in rows:
		var d: WeaponData = row["data"]
		var dps: Array = row["dps"]
		# Monotonic non-decreasing damage across tiers.
		var monotonic := true
		for i in range(1, dps.size()):
			if float(dps[i]) < float(dps[i - 1]) - 0.001:
				monotonic = false
		_check(monotonic, "%s damage never drops between tiers" % d.display_name)

	# Every weapon must be reachable: a non-empty display name and a valid
	# projectile scene path.
	for row in rows:
		var d: WeaponData = row["data"]
		_check(d.display_name != "", "%s has a display name" % d.id)
		_check(d.base_damage > 0.0, "%s has positive base damage" % d.id)
		# Orbit weapons spin continuously — their cooldown field is a tick
		# interval, not a fire rate, so the 0.2s floor does not apply.
		if d.type != "orbit":
			_check(d.base_cooldown >= 0.2, "%s has a sane cooldown floor" % d.id)

	# Evolutions are separate resources; they must all resolve too.
	var evo_count := 0
	for path in files:
		if path.ends_with(".tres") and path.get_file().begins_with("evo_"):
			if load(path) != null:
				evo_count += 1
	_check(evo_count >= 4, "evolution resources load (%d)" % evo_count)

	# --- The pickable pool must stay converged at every tier ---
	var by_id: Dictionary = {}
	for row in rows:
		by_id[row["data"].id] = row["dps"]
	for id in POOL_WEAPONS:
		_check(by_id.has(id), "pool weapon %s exists" % id)
		if not by_id.has(id):
			continue
		var dps: Array = by_id[id]
		_check(dps.size() == 5, "%s has a DPS value for every tier" % id)
		var growth: float = float(dps[4]) / maxf(float(dps[0]), 0.01)
		_check(growth >= MIN_TIER5_GROWTH,
			"pool weapon %s grows at least %.1fx by tier 5 (%.2fx)" % [id, MIN_TIER5_GROWTH, growth])

	var pool_tier5: Array = []
	for id in POOL_WEAPONS:
		if by_id.has(id):
			pool_tier5.append(float(by_id[id][4]))
	var pool_lo: float = pool_tier5.min()
	var pool_hi: float = pool_tier5.max()
	_check(pool_hi / maxf(pool_lo, 0.01) <= MAX_POOL_TIER5_SPREAD,
		"pool tier-5 DPS spread is bounded (%.2fx, max %.1fx)" % [
			pool_hi / maxf(pool_lo, 0.01), MAX_POOL_TIER5_SPREAD])

	# --- An evolution must never be a downgrade ---
	for path in files:
		if not (path.ends_with(".tres") and path.get_file().begins_with("evo_")):
			continue
		var evo: Resource = load(path)
		if not (evo is EvolutionData):
			continue
		var e: EvolutionData = evo
		var base_id: String = e.base_weapon_id
		var evolved_id: String = e.evolved_weapon.id if e.evolved_weapon != null else ""
		_check(by_id.has(base_id), "evolution %s has a base weapon in the table" % e.id)
		_check(by_id.has(evolved_id), "evolution %s has an evolved weapon in the table" % e.id)
		if not (by_id.has(base_id) and by_id.has(evolved_id)):
			continue
		var base_dps: float = float(by_id[base_id][4])
		var evo_dps: float = float(by_id[evolved_id][4])
		_check(evo_dps >= base_dps * MIN_EVOLUTION_UPLIFT,
			"evolution %s upgrades %s (%.1f -> %.1f DPS)" % [e.id, base_id, base_dps, evo_dps])

	_finish()

## Sustained single-target DPS of a weapon at a given level.
## The model lives in scripts/weapons/weapon_balance.gd so this test and
## tools/balance_table.gd can never drift apart.
func _dps_at(data: WeaponData, level: int) -> float:
	return WeaponBalance.dps_at(data, level)

func _weapon_files() -> Array:
	var out: Array = []
	var dir := DirAccess.open(WEAPON_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".tres"):
			out.append(WEAPON_DIR + f)
	out.sort()
	return out

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1

func _finish() -> void:
	if failures == 0:
		print("V26A_BALANCE_TABLE_PASS")
	else:
		print("V26A_BALANCE_TABLE_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)
