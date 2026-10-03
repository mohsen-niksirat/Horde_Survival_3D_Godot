extends Node
## Per-run session state: timer, kills, gold, run stats.

signal time_changed(elapsed: float)
signal kills_changed(kills: int)
## Endless milestone: emitted once per 5-minute interval crossed.
signal endless_milestone(minutes: int)

var is_running: bool = false
var endless: bool = false
var elapsed_time: float = 0.0
var kills: int = 0
var gold_earned: float = 0.0
var boss_active: bool = false
var target_duration: float = 900.0
## Campaign (S1+S7): active mission win rule & side objectives
var mission: Resource = null
var mission_boss_killed: bool = false
var elites_killed: int = 0
var max_combo_reached: int = 0
var side_objective_completed: bool = false
## Endless: highest 5-minute milestone crossed this run (0 = none yet).
var endless_milestone_reached: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.combo_changed.connect(_on_combo_changed)
	EventBus.boss_died.connect(on_boss_killed)

func _on_enemy_died(enemy: Node, _pos: Vector3) -> void:
	if enemy != null and enemy.get("elite") != null and enemy.elite != null:
		elites_killed += 1
		_check_side_objective()

func _on_combo_changed(count: int, _mult: float) -> void:
	max_combo_reached = maxi(max_combo_reached, count)
	_check_side_objective()

func _check_side_objective() -> void:
	if mission == null or side_objective_completed:
		return
	var type: String = str(mission.get("side_objective_type"))
	var target: int = int(mission.get("side_objective_target"))
	if type == "kill_elites" and elites_killed >= target:
		side_objective_completed = true
	elif type == "combo_streak" and max_combo_reached >= target:
		side_objective_completed = true

func _process(delta: float) -> void:
	if is_running and not get_tree().paused:
		elapsed_time += delta
		time_changed.emit(elapsed_time)
		if endless:
			_check_endless_milestone()
		# Playtest: standard runs must END with victory (endless is the open mode)
		# Missions own their own win rules — don't end a kill_boss/kill_count
		# mission on the default 15-minute timer.
		if not endless and mission == null and elapsed_time >= target_duration:
			is_running = false
			boss_active = false
			GameManager.game_over(true)
		elif mission != null:
			_check_mission_win()

## Endless: emit endless_milestone once per 5-minute interval crossed.
func _check_endless_milestone() -> void:
	var milestone := int(elapsed_time / 300.0)
	if milestone > endless_milestone_reached:
		endless_milestone_reached = milestone
		endless_milestone.emit(milestone * 5)

## S1+S7 campaign: win when mission rule is met, award bonus for side objectives.
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
		_check_side_objective()
		if side_objective_completed and mission.get("side_gold_reward") != null:
			gold_earned += float(mission.side_gold_reward)
		var completed: Array = SaveManager.get_meta_data("completed_missions", []).duplicate()
		if not completed.has(mission.id):
			completed.append(mission.id)
			SaveManager.set_meta_data("completed_missions", completed)
		GameManager.game_over(true)

func set_mission(m: Resource) -> void:
	mission = m
	mission_boss_killed = false
	elites_killed = 0
	max_combo_reached = 0
	side_objective_completed = false
	if m != null and m.win_rule == "survive_time":
		target_duration = float(m.win_target)
	else:
		# Reset default so a normal run after a campaign mission
		# doesn't inherit the mission timer.
		target_duration = 900.0

func start_run() -> void:
	is_running = true
	elapsed_time = 0.0
	kills = 0
	gold_earned = 0.0
	boss_active = false
	if mission == null:
		# Reset default (a survive_time mission sets its own via set_mission)
		target_duration = 900.0
	mission_boss_killed = false
	elites_killed = 0
	max_combo_reached = 0
	side_objective_completed = false
	endless_milestone_reached = 0
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
	if endless:
		var best: int = SaveManager.get_meta_data("endless_best_minutes", 0)
		if endless_milestone_reached * 5 > best:
			SaveManager.set_meta_data("endless_best_minutes", endless_milestone_reached * 5)

func set_boss_active(active: bool) -> void:
	boss_active = active

func is_boss_active() -> bool:
	return boss_active

func get_time_string() -> String:
	var total := int(elapsed_time)
	var minutes := total / 60
	var seconds := total % 60
	return "%02d:%02d" % [minutes, seconds]
