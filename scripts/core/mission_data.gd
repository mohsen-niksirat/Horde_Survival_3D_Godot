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
@export var act: int = 1
@export var act_name: String = "Act I — The Gate"
@export var side_objective_type: String = ""   # "kill_elites" | "combo_streak"
@export var side_objective_target: int = 0
@export var side_gold_reward: int = 50

func describe_win() -> String:
	match win_rule:
		"survive_time":
			return "Survive %d:%02d" % [int(win_target) / 60, int(win_target) % 60]
		"kill_count":
			return "Defeat %d enemies" % int(win_target)
		"kill_boss":
			if id == "m5_heartforge":
				return "Defeat Heartforge Core"
			return "Defeat the Boss"
	return "Complete the objective"

func describe_side() -> String:
	match side_objective_type:
		"kill_elites":
			return "Bonus: Slay %d Elites (+%d gold)" % [side_objective_target, side_gold_reward]
		"combo_streak":
			return "Bonus: Reach %d Combo (+%d gold)" % [side_objective_target, side_gold_reward]
	return ""

func is_unlocked(victories: int, completed_missions: Array = []) -> bool:
	# Campaign progression: unlocked by finishing the previous mission,
	# falling back to victory count so existing saves keep working.
	var prev_map := {
		"m2_frost": "m1_gate",
		"m3_nest": "m2_frost",
		"m4_warden": "m3_nest",
		"m5_heartforge": "m4_warden",
		"m6_storm": "m5_heartforge",
		"m7_hollow": "m6_storm",
	}
	var prev: String = str(prev_map.get(id, ""))
	if prev != "" and completed_missions.has(prev):
		return true
	return victories >= unlock_wins
