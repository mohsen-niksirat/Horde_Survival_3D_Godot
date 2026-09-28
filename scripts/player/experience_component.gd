extends Node
## XP + level for the player. Emits level_up through EventBus.

signal leveled_up(new_level: int)

const XP_BASE := 18.0
const XP_GROWTH := 1.22

var level: int = 1
var current_xp: float = 0.0
var xp_to_next: float = XP_BASE

func add_xp(amount: float) -> void:
	current_xp += amount
	while current_xp >= xp_to_next:
		current_xp -= xp_to_next
		level += 1
		xp_to_next = XP_BASE * pow(XP_GROWTH, level - 1)
		leveled_up.emit(level)
		EventBus.player_leveled_up.emit(level)

func reset() -> void:
	level = 1
	current_xp = 0.0
	xp_to_next = XP_BASE

func get_ratio() -> float:
	return current_xp / xp_to_next
