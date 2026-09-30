extends Node
## Per-run session state: timer, kills, gold, run stats.

signal time_changed(elapsed: float)
signal kills_changed(kills: int)

var is_running: bool = false
var endless: bool = false
var elapsed_time: float = 0.0
var kills: int = 0
var gold_earned: float = 0.0
var boss_active: bool = false
var target_duration: float = 900.0
## Campaign (S1): active mission win rule
var mission: Resource = null
var mission_boss_killed: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	if is_running and not get_tree().paused:
		elapsed_time += delta
		time_changed.emit(elapsed_time)
		# Playtest: standard runs must END with victory (endless is the open mode)
		if not endless and elapsed_time >= target_duration:
			is_running = false
			boss_active = false
			GameManager.game_over(true)
		elif mission != null:
			_check_mission_win()

## S1 campaign: win when mission rule is met.
func _check_mission_win() -> void:
	var won := false
	match mission.win_rule:
		"survive_time":
			won = elapsed_time >= float(mission.win_target)
		"kill_count":
			won = kills >= int(mission.win_target)
		"kill_boss":
			won = mission_boss_killed
	if won:
		is_running = false
		boss_active = false
		gold_earned += float(mission.gold_reward)
		GameManager.game_over(true)

func set_mission(m: Resource) -> void:
	mission = m
	mission_boss_killed = false
	if m != null and m.win_rule == "survive_time":
		target_duration = float(m.win_target)

func start_run() -> void:
	is_running = true
	elapsed_time = 0.0
	kills = 0
	gold_earned = 0.0
	boss_active = false
	mission_boss_killed = false
	EventBus.run_started.emit()

func start_run_endless() -> void:
	endless = true
	start_run()

func end_run() -> void:
	is_running = false
	boss_active = false

func register_kill() -> void:
	kills += 1
	kills_changed.emit(kills)

func on_boss_killed() -> void:
	mission_boss_killed = true

func add_gold(amount: float) -> void:
	gold_earned += amount

## Commit partial run rewards (pause->menu / pause->restart).
## Kills are already banked per-kill by AchievementSystem — do not re-add them.
func commit_partial_rewards() -> void:
	var gold := int(gold_earned)
	if gold > 0:
		var total: int = SaveManager.get_meta_data("gold", 0)
		SaveManager.set_meta_data("gold", total + gold)
		gold_earned = 0.0
	if elapsed_time > float(SaveManager.get_meta_data("best_time", 0.0)):
		SaveManager.set_meta_data("best_time", elapsed_time)

func set_boss_active(active: bool) -> void:
	boss_active = active

func is_boss_active() -> bool:
	return boss_active

func get_time_string() -> String:
	var total := int(elapsed_time)
	var minutes := total / 60
	var seconds := total % 60
	return "%02d:%02d" % [minutes, seconds]
