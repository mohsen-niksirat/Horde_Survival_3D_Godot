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
	var unlock_msg := ""
	if _victory:
		gold_earned += 250.0
		# S2: gold interest on victory (meta greed feel)
		var interest: int = int(gold_earned * 0.1)
		gold_earned += interest
		var wins: int = int(SaveManager.get_meta_data("victories", 0)) + 1
		SaveManager.set_meta_data("victories", wins)
		if wins == 1:
			unlock_msg = "\nPaladin unlocked!"
		elif wins == 3:
			unlock_msg = "\nRogue unlocked!"
	SaveManager.set_meta_data("gold", SaveManager.get_meta_data("gold", 0) + int(gold_earned))
	SaveManager.set_meta_data("total_runs", SaveManager.get_meta_data("total_runs", 0) + 1)
	if RunManager.elapsed_time > SaveManager.get_meta_data("best_time", 0.0):
		SaveManager.set_meta_data("best_time", RunManager.elapsed_time)
	# Kills are already counted per-kill in achievements; do not re-add
	RunManager.gold_earned = 0.0
	var title := "VICTORY" if _victory else "RUN OVER"
	var subtitle := ("You survived the horde. +250 bonus gold!" + unlock_msg) if _victory else "The horde claimed you."
	stats_label.text = "%s\n%s\nSurvived: %s\nKills: %d\nBest combo: %d\nGold earned: %d" % [
		title,
		subtitle,
		RunManager.get_time_string(),
		RunManager.kills,
		_max_combo(),
		int(gold_earned),
	]
	stats_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35) if _victory else Color(1.0, 0.55, 0.5))

func _max_combo() -> int:
	var combos := get_tree().get_nodes_in_group("combo_manager") if get_tree() != null else []
	# ComboManager is a plain Node under Main — search by script
	var main := get_tree().current_scene if get_tree() != null else null
	if main != null:
		var found: Array = main.find_children("*", "Node", true, false)
		for n in found:
			if n.get("max_combo") != null:
				return int(n.max_combo)
	return 0

func _on_retry() -> void:
	GameManager.start_game()

func _on_menu() -> void:
	GameManager.goto_menu()
