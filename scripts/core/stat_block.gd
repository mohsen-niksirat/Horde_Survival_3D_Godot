class_name StatBlock
extends RefCounted
## Universal stat container. Base stats + modifier recompute.
## Timed modifiers are stored as (value, remaining) and re-applied from
## BASE each frame — never multiplied in place (reference-game bug guard).

var base: Dictionary = {
	"max_hp": 100.0,
	"armor": 0.0,
	"regen": 0.0,
	"move_speed": 6.0,
	"pickup_radius": 3.0,
	"might": 1.0,
	"area_mult": 1.0,
	"cooldown_mult": 1.0,
	"attack_speed": 1.0,
	"projectile_bonus": 0,
	"crit_chance": 0.05,
	"crit_mult": 2.0,
	"luck": 0.0,
	"xp_gain": 1.0,
	"gold_gain": 1.0,
	"projectile_size": 1.0,
}

var _flat: Dictionary = {}    # stat -> accumulated flat bonus
var _percent: Dictionary = {} # stat -> accumulated percent bonus
var _timed: Array = []
var _applied_keys: Dictionary = {}        # [{stat, flat, percent, remaining}]

func _init(base_override: Dictionary = {}) -> void:
	for key in base_override:
		base[key] = base_override[key]

## Add a permanent modifier. flat adds to base; percent multiplies base.
## Duplicate application with the same key is ignored (idempotent).
func add_modifier(stat: String, flat: float = 0.0, percent: float = 0.0, key: String = "") -> void:
	if key != "":
		if _applied_keys.has(key):
			return
		_applied_keys[key] = true
	if flat != 0.0:
		_flat[stat] = _flat.get(stat, 0.0) + flat
	if percent != 0.0:
		_percent[stat] = _percent.get(stat, 0.0) + percent

## Add a timed modifier that expires after duration seconds.
func add_timed_modifier(stat: String, duration: float, flat: float = 0.0, percent: float = 0.0) -> void:
	_timed.append({
		"stat": stat,
		"flat": flat,
		"percent": percent,
		"remaining": duration,
	})

func tick(delta: float) -> void:
	# Remove expired entries as they run out — otherwise their flat/percent
	# bonuses keep applying in get_stat() forever.
	for i in range(_timed.size() - 1, -1, -1):
		var m: Dictionary = _timed[i]
		m["remaining"] -= delta
		if m["remaining"] <= 0.0:
			_timed.remove_at(i)

func get_stat(stat: String) -> float:
	var value: float = base.get(stat, 0.0)
	value += _flat.get(stat, 0.0)
	for m in _timed:
		if m["stat"] == stat:
			value += m["flat"]
	value *= 1.0 + _percent.get(stat, 0.0)
	for m in _timed:
		if m["stat"] == stat:
			value *= 1.0 + m["percent"]
	return maxf(value, 0.0)

func has_stat(stat: String) -> bool:
	return base.has(stat)
