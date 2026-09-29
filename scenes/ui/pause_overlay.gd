extends Control
## Pause overlay: shown while GameManager.State == PAUSED.
## Resume / Restart / Main Menu. R11: live run stats.

@onready var resume_button: Button = $Center/Panel/Layout/ResumeButton
@onready var settings_button: Button = $Center/Panel/Layout/SettingsButton
@onready var restart_button: Button = $Center/Panel/Layout/RestartButton
@onready var menu_button: Button = $Center/Panel/Layout/MenuButton

var _stats_label: Label

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_on_resume)
	settings_button.pressed.connect(_on_settings)
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)
	EventBus.game_state_changed.connect(_on_state_changed)
	_stats_label = Label.new()
	_stats_label.name = "RunStats"
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 14)
	_stats_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	var layout: Node = $Center/Panel/Layout
	if layout != null:
		layout.add_child(_stats_label)
		layout.move_child(_stats_label, 0)

func _refresh_stats() -> void:
	if _stats_label == null:
		return
	var win_txt := ""
	if not RunManager.endless:
		var left: float = maxf(RunManager.target_duration - RunManager.elapsed_time, 0.0)
		win_txt = "  ·  Win in %d:%02d" % [int(left) / 60, int(left) % 60]
	_stats_label.text = "Time %s  ·  Kills %d  ·  Level %d  ·  Gold %d%s" % [
		RunManager.get_time_string(),
		RunManager.kills,
		_player_level(),
		int(RunManager.gold_earned),
		win_txt,
	]

func _player_level() -> int:
	var players := get_tree().get_nodes_in_group("player") if get_tree() != null else []
	for p in players:
		if p.get("experience") != null:
			return p.experience.level
	return 1

func _on_settings() -> void:
	# Open the in-game settings (Main hosts one under HUD)
	var found: Array = get_tree().root.find_children("SettingsMenu", "Control", true, false)
	if found.size() > 0:
		found[0].open()

func _on_state_changed(new_state: int, _old: int) -> void:
	visible = new_state == GameManager.State.PAUSED
	if visible:
		_refresh_stats()

func _on_resume() -> void:
	GameManager.resume_game()

func _on_restart() -> void:
	# Bank run gold/best before start_run() zeroes gold_earned
	run_commit()
	GameManager.start_game()

func _on_menu() -> void:
	# Keep partial progress: gold/kills/time already banked via RunManager
	run_commit()
	GameManager.goto_menu()

func _on_menu_pause_commit() -> void:
	run_commit()

func run_commit() -> void:
	var run_manager: Node = get_tree().root.get_node_or_null("RunManager")
	if run_manager != null:
		run_manager.commit_partial_rewards()
		run_manager.is_running = false
	SaveManager.save_game()
