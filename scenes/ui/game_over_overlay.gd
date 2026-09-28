extends Control
## Game over / results overlay: run stats, meta gold update, retry / menu.

@onready var stats_label: Label = $Center/Panel/Layout/Stats
@onready var retry_button: Button = $Center/Panel/Layout/RetryButton
@onready var menu_button: Button = $Center/Panel/Layout/MenuButton

var _victory: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.game_state_changed.connect(_on_state_changed)
	EventBus.run_ended.connect(_on_run_ended)
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)

func _on_run_ended(victory: bool) -> void:
	_victory = victory

func _on_state_changed(new_state: int, _old: int) -> void:
	visible = new_state == GameManager.State.GAME_OVER
	if visible:
		_commit_run()
		_victory = false

func _commit_run() -> void:
	# Meta progression: gold, bests, totals
	var gold_earned: float = RunManager.gold_earned
	if _victory:
		gold_earned += 250.0
	SaveManager.set_meta_data("gold", SaveManager.get_meta_data("gold", 0) + int(gold_earned))
	SaveManager.set_meta_data("total_runs", SaveManager.get_meta_data("total_runs", 0) + 1)
	if _victory:
		SaveManager.set_meta_data("victories", SaveManager.get_meta_data("victories", 0) + 1)
	if RunManager.elapsed_time > SaveManager.get_meta_data("best_time", 0.0):
		SaveManager.set_meta_data("best_time", RunManager.elapsed_time)
	# Kills are already counted per-kill in achievements; do not re-add
	RunManager.gold_earned = 0.0
	var title := "VICTORY" if _victory else "RUN OVER"
	var subtitle := "You survived the horde. +250 bonus gold!" if _victory else "The horde claimed you."
	stats_label.text = "%s\n%s\nSurvived: %s\nKills: %d\nGold earned: %d" % [
		title,
		subtitle,
		RunManager.get_time_string(),
		RunManager.kills,
		int(gold_earned),
	]

func _on_retry() -> void:
	GameManager.start_game()

func _on_menu() -> void:
	GameManager.goto_menu()
