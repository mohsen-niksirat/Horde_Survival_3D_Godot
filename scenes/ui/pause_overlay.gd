extends Control
## Pause overlay: shown while GameManager.State == PAUSED.
## Resume / Restart / Main Menu.

@onready var resume_button: Button = $Center/Panel/Layout/ResumeButton
@onready var settings_button: Button = $Center/Panel/Layout/SettingsButton
@onready var restart_button: Button = $Center/Panel/Layout/RestartButton
@onready var menu_button: Button = $Center/Panel/Layout/MenuButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_on_resume)
	settings_button.pressed.connect(_on_settings)
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)
	EventBus.game_state_changed.connect(_on_state_changed)

func _on_settings() -> void:
	# Open the in-game settings (Main hosts one under HUD)
	var found: Array = get_tree().root.find_children("SettingsMenu", "Control", true, false)
	if found.size() > 0:
		found[0].open()

func _on_state_changed(new_state: int, _old: int) -> void:
	visible = new_state == GameManager.State.PAUSED

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
