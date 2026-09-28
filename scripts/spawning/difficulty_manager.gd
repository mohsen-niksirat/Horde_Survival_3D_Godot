extends RefCounted
class_name DifficultyManager
## Difficulty scaling: reuses the reference game's proven formula shape with
## 3D-retuned constants. Per-stat caps prevent late-game absurdity.

static func difficulty_multiplier(player_level: int, minutes: float) -> float:
	var base := 1.0 + 0.18 * sqrt(float(maxi(player_level, 1))) + minutes * 0.06
	# V18: endless soft-cap after 10 min so 15–20 min runs stay playable
	if minutes > 10.0:
		base = 1.0 + 0.18 * sqrt(float(maxi(player_level, 1))) + 10.0 * 0.06 + (minutes - 10.0) * 0.025
	return base

static func hp_scale(difficulty: float) -> float:
	return minf(difficulty, 10.0)

static func damage_scale(difficulty: float) -> float:
	return minf(difficulty, 5.0)

static func speed_scale(difficulty: float) -> float:
	return minf(1.0 + (difficulty - 1.0) * 0.25, 1.8)

## Threat budget grows with time: more points = more/stronger enemies.
## V18: quadratic term softens after 10 min (endless survivability).
static func threat_budget(minutes: float) -> float:
	if minutes <= 10.0:
		return 2.0 + minutes * 2.2 + minutes * minutes * 0.08
	var at10 := 2.0 + 10.0 * 2.2 + 100.0 * 0.08
	var extra := minutes - 10.0
	return at10 + extra * 1.6 + extra * extra * 0.03

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
	if minutes >= 6.0:
		out.append("splitter")
	if minutes >= 7.0:
		out.append("mage")
	if minutes >= 8.0:
		out.append("healer")
	return out

## Elite cadence: every 10 player levels (matches reference game).
static func should_spawn_elite(player_level: int, last_elite_level: int) -> bool:
	return player_level / 10 > last_elite_level / 10
