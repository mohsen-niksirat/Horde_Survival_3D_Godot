extends Control
## Game over / results overlay: run stats, meta gold update, retry / menu.

@onready var stats_label: Label = $Center/Panel/Layout/Stats
@onready var retry_button: Button = $Center/Panel/Layout/RetryButton
@onready var menu_button: Button = $Center/Panel/Layout/MenuButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.game_state_changed.connect(_on_state_changed)
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)

func _on_state_changed(new_state: int, _old: int) -> void:
	visible = new_state == GameManager.State.GAME_OVER
	if visible:
		_commit_run()

func _commit_run() -> void:
	# Meta progression: gold, bests, totals
	var gold_earned: float = RunManager.gold_earned
	SaveManager.set_meta_data("gold", SaveManager.get_meta_data("gold", 0) + int(gold_earned))
	SaveManager.set_meta_data("total_runs", SaveManager.get_meta_data("total_runs", 0) + 1)
	if RunManager.elapsed_time > SaveManager.get_meta_data("best_time", 0.0):
		SaveManager.set_meta_data("best_time", RunManager.elapsed_time)
	# Kills are already counted per-kill in achievements — do not re-add
	RunManager.gold_earned = 0.0
	stats_label.text = "Survived: %s\nKills: %d\nGold earned: %d" % [
		RunManager.get_time_string(),
		RunManager.kills,
		int(gold_earned),
	]

func _on_retry() -> void:
	GameManager.start_game()

func _on_menu() -> void:
	GameManager.goto_menu()
