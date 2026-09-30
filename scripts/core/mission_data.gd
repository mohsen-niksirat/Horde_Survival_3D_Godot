class_name MissionData
extends Resource
## Story mission definition. Win rules: survive_time | kill_count | kill_boss.

@export var id: String = "m1"
@export var display_name: String = "Ash at the Gate"
@export var briefing: String = "Hold the outer ward until the torches burn out."
@export var map_id: String = "arena"
@export var win_rule: String = "survive_time"
@export var win_target: float = 300.0
@export var gold_reward: int = 150
@export var unlock_wins: int = 0

func describe_win() -> String:
	match win_rule:
		"survive_time":
			return "Survive %d:%02d" % [int(win_target) / 60, int(win_target) % 60]
		"kill_count":
			return "Defeat %d enemies" % int(win_target)
		"kill_boss":
			return "Defeat the Warden"
	return "Complete the objective"

func is_unlocked(victories: int) -> bool:
	return victories >= unlock_wins
