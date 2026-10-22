extends Node
## StatusComponent: data-driven status effects (burn DoT, slow, freeze).
## Attached to enemies. Effects stored as dicts and expire cleanly —
## re-applied from base each tick (reference-game decay-bug guard).

signal effect_applied(effect_id: String)
signal effect_expired(effect_id: String)

## burn: {damage_per_sec, remaining}
## slow: {factor, remaining}   (factor < 1, e.g. 0.5 = half speed)
## freeze: {remaining}         (factor 0)
var _effects: Dictionary = {}
## V30A: burn damage is applied in 0.2 s packets instead of allocating a
## DamageEvent every frame per burning enemy.
const BURN_TICK := 0.2
var _burn_accum: float = 0.0
var _burn_tick: float = 0.0

var base_move_speed: float = 3.0
var _root: Node

func setup(root: Node) -> void:
	_root = root
	_effects.clear()
	_burn_accum = 0.0
	_burn_tick = 0.0
	set_process(false)

func _process(delta: float) -> void:
	if _effects.is_empty():
		set_process(false)
		return
	var expired: Array = []
	var burn_dps := 0.0
	for id in _effects:
		var eff: Dictionary = _effects[id]
		eff["remaining"] -= delta
		if id == "burn":
			burn_dps = maxf(burn_dps, float(eff.get("damage_per_sec", 0.0)))
		if eff["remaining"] <= 0.0:
			expired.append(id)
	if burn_dps > 0.0 and _root != null and _root.health != null and _root.health.is_alive():
		_burn_accum += burn_dps * delta
		_burn_tick += delta
		if _burn_tick >= BURN_TICK:
			_root.health.take_damage(DamageEvent.new(_burn_accum, "burn"))
			_burn_accum = 0.0
			_burn_tick = 0.0
	for id in expired:
		_effects.erase(id)
		if id == "burn":
			# Flush the carried remainder so the final tick is not lost.
			if _burn_accum > 0.0 and _root != null and _root.health != null and _root.health.is_alive():
				_root.health.take_damage(DamageEvent.new(_burn_accum, "burn"))
			_burn_accum = 0.0
			_burn_tick = 0.0
		effect_expired.emit(id)
	if _effects.is_empty():
		set_process(false)

## Apply or refresh a status effect.
func apply(id: String, duration: float, params: Dictionary = {}) -> void:
	var had := _effects.has(id)
	match id:
		"burn":
			_effects[id] = {"damage_per_sec": params.get("damage_per_sec", 8.0), "remaining": duration}
		"slow":
			_effects[id] = {"factor": params.get("factor", 0.5), "remaining": duration}
		"freeze":
			_effects[id] = {"factor": 0.0, "remaining": duration}
	set_process(true)
	if not had:
		effect_applied.emit(id)

func get_speed_factor() -> float:
	var factor := 1.0
	for id in _effects:
		factor = minf(factor, _effects[id].get("factor", 1.0))
	return factor

func has_effect(id: String) -> bool:
	return _effects.has(id)

func clear_all() -> void:
	_effects.clear()
	_burn_accum = 0.0
	_burn_tick = 0.0
	set_process(false)
