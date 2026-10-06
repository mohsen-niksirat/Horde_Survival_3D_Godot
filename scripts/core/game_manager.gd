extends Node
## Global game-state machine and scene flow orchestration.
## Also owns pointer capture policy: lock only while PLAYING/BOSS.

enum State {
	BOOT,
	MAIN_MENU,
	CHARACTER_SELECT,
	GAME_START,
	PLAYING,
	LEVEL_UP,
	BOSS,
	PAUSED,
	GAME_OVER,
	RESULTS,
}

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const MENU_SCENE := "res://scenes/menu/MainMenu.tscn"

var state: int = State.BOOT
var selected_character_id: String = "mage"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.game_state_changed.connect(_on_game_state_changed)
	SaveManager.save_loaded.connect(_restore_selected_character)
	_restore_selected_character()

func _restore_selected_character() -> void:
	# Preserve an explicit choice made before save loading completes.
	if selected_character_id != "mage":
		return
	# GameManager is registered before SaveManager; restore after loading.
	# Unlock state is victories-driven (character_select.UNLOCK_WINS), not
	# the legacy unlocked_characters array (which is never updated).
	if SaveManager.get_meta_data("selected_character", null) != null and state == State.BOOT:
		var saved: String = str(SaveManager.get_meta_data("selected_character"))
		var wins: int = int(SaveManager.get_meta_data("victories", 0))
		var need: int = CharacterData.unlock_requirement(saved)
		if CharacterData.UNLOCK_WINS.has(saved) and wins >= need:
			selected_character_id = saved

func change_state(new_state: int) -> void:
	if new_state == state:
		return
	var old := state
	state = new_state
	EventBus.game_state_changed.emit(new_state, old)
	_sync_pointer(new_state)

func _sync_pointer(s: int) -> void:
	match s:
		State.PLAYING, State.BOSS:
			if not DisplayServer.is_touchscreen_available() and not OS.has_feature("mobile"):
				InputManager.capture_pointer()
		_:
			# Menus, pause, level-up, game over — always free the browser cursor
			InputManager.release_pointer()

func start_game() -> void:
	change_state(State.GAME_START)
	get_tree().paused = false
	InputManager.release_pointer()
	get_tree().change_scene_to_file(MAIN_SCENE)

func goto_menu() -> void:
	change_state(State.MAIN_MENU)
	get_tree().paused = false
	InputManager.release_pointer()
	get_tree().change_scene_to_file(MENU_SCENE)

func pause_game() -> void:
	if state == State.PLAYING or state == State.BOSS:
		get_tree().paused = true
		change_state(State.PAUSED)

func resume_game() -> void:
	if state == State.PAUSED:
		get_tree().paused = false
		if RunManager.is_boss_active():
			change_state(State.BOSS)
		else:
			change_state(State.PLAYING)

func open_level_up() -> void:
	if state == State.PLAYING or state == State.BOSS:
		get_tree().paused = true
		change_state(State.LEVEL_UP)

func close_level_up() -> void:
	if state == State.LEVEL_UP:
		get_tree().paused = false
		if RunManager.is_boss_active():
			change_state(State.BOSS)
		else:
			change_state(State.PLAYING)

func game_over(victory: bool) -> void:
	# Multiple simultaneous lethal/win events must not award twice.
	if state == State.GAME_OVER or state == State.RESULTS:
		return
	RunManager.is_running = false
	get_tree().paused = false
	# Deliver the result before the overlay commits rewards on GAME_OVER.
	EventBus.run_ended.emit(victory)
	change_state(State.GAME_OVER)
	InputManager.release_pointer()

func _on_game_state_changed(_new_state: int, _old: int) -> void:
	pass
