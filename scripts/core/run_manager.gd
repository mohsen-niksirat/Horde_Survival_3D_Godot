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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	if is_running and not get_tree().paused:
		elapsed_time += delta
		time_changed.emit(elapsed_time)

func start_run() -> void:
	is_running = true
	elapsed_time = 0.0
	kills = 0
	gold_earned = 0.0
	boss_active = false
	EventBus.run_started.emit()

func start_run_endless() -> void:
	start_run()
	endless = true

func end_run() -> void:
	is_running = false
	boss_active = false

func register_kill() -> void:
	kills += 1
	kills_changed.emit(kills)

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
