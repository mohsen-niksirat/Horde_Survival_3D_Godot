extends RefCounted
class_name DifficultyManager
## Difficulty scaling: reuses the reference game's proven formula shape with
## 3D-retuned constants. Per-stat caps prevent late-game absurdity.

static func difficulty_multiplier(player_level: int, minutes: float) -> float:
	var base := 1.0 + 0.18 * sqrt(float(maxi(player_level, 1))) + minutes * 0.06
	# Playtest: 12–16 min was too soft — keep pressure after 10 min
	if minutes > 10.0:
		base = 1.0 + 0.18 * sqrt(float(maxi(player_level, 1))) + 10.0 * 0.06 + (minutes - 10.0) * 0.045
	return base

static func hp_scale(difficulty: float) -> float:
	return minf(difficulty, 12.0)

static func damage_scale(difficulty: float) -> float:
	return minf(difficulty, 6.5)

static func speed_scale(difficulty: float) -> float:
	return minf(1.0 + (difficulty - 1.0) * 0.25, 1.9)

## Threat budget grows with time: more points = more/stronger enemies.
static func threat_budget(minutes: float) -> float:
	if minutes <= 10.0:
		return 2.0 + minutes * 2.2 + minutes * minutes * 0.08
	var at10 := 2.0 + 10.0 * 2.2 + 100.0 * 0.08
	var extra := minutes - 10.0
	var budget := at10 + extra * 2.0 + extra * extra * 0.06
	# R10: standard-run finale — last 2 minutes get denser hordes
	# (avoid autoload refs in this static helper)
	if minutes >= 13.0 and minutes < 15.5:
		budget *= 1.35
	return budget

## Spawn interval shrinks over time (floor keeps late hordes readable).
static func spawn_interval(minutes: float) -> float:
	return maxf(2.0 / (1.0 + minutes * 0.06), 0.45)

## Which archetypes are allowed at this time (minutes).
static func allowed_archetypes(minutes: float) -> Array:
	var out := ["basic_drone"]
	if minutes >= 1.5:
		out.append("swarm_bat")
	if minutes >= 2.5:
		out.append("fast_wisp")
	if minutes >= 3.5:
		out.append("ghost")
	if minutes >= 4.0:
		out.append("shooter_turret")
	if minutes >= 5.0:
		out.append("tank_golem")
	if minutes >= 5.5:
		out.append("specter")
	if minutes >= 6.0:
		out.append("splitter")
	if minutes >= 6.5:
		out.append("brute")
	if minutes >= 7.0:
		out.append("mage")
	if minutes >= 8.0:
		out.append("healer")
	return out

## Elite cadence: every 10 player levels (matches reference game).
static func should_spawn_elite(player_level: int, last_elite_level: int) -> bool:
	return player_level / 10 > last_elite_level / 10
