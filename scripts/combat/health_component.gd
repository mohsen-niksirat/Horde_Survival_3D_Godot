extends Node
## Universal health/damage component for player, enemies, boss.
## All damage flows through take_damage() → DamageEvent.

signal died()
signal damaged(event: DamageEvent)
signal healed(amount: float)

var max_hp: float = 100.0
var armor: float = 0.0
var current_hp: float = 100.0
var alive: bool = true
var invincible_timer: float = 0.0
## For enemies: scales with difficulty at spawn time.
var hp_scale: float = 1.0
## Optional interceptor (e.g. elite shield): Callable(DamageEvent) -> float
## returning the adjusted damage before armor is applied.
var damage_interceptor: Callable = Callable()

func setup(p_max_hp: float, p_armor: float = 0.0) -> void:
	max_hp = p_max_hp
	armor = p_armor
	current_hp = max_hp
	alive = true
	invincible_timer = 0.0
	set_process(false)

func set_scaled(p_max_hp: float, p_armor: float, scale: float) -> void:
	hp_scale = scale
	setup(p_max_hp * scale, p_armor)

func _process(delta: float) -> void:
	if invincible_timer <= 0.0:
		set_process(false)
		return
	invincible_timer -= delta
	if invincible_timer <= 0.0:
		set_process(false)

func take_damage(event: DamageEvent) -> float:
	if not alive or invincible_timer > 0.0:
		return 0.0
	if damage_interceptor.is_valid():
		event.amount = damage_interceptor.call(event)
		if event.amount <= 0.0:
			return 0.0
	var final := maxf(event.amount - armor, 1.0)
	current_hp -= final
	event.final_amount = final
	damaged.emit(event)
	if current_hp <= 0.0:
		current_hp = 0.0
		alive = false
		died.emit()
	return final

func heal(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	var before := current_hp
	current_hp = minf(current_hp + amount, max_hp)
	healed.emit(current_hp - before)

func get_ratio() -> float:
	return current_hp / max_hp if max_hp > 0.0 else 0.0

func is_alive() -> bool:
	return alive

func set_invincible(duration: float) -> void:
	invincible_timer = duration
	set_process(duration > 0.0)

func reset() -> void:
	current_hp = max_hp
	alive = true
	invincible_timer = 0.0
	set_process(false)
