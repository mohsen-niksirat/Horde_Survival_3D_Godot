extends Control
## First-time tutorial: step-by-step control guide shown ONCE before the
## first run starts. Next/Skip buttons. Steps adapt to touch vs desktop.

const SAVE_KEY := "tutorial_done"

const DESKTOP_STEPS := [
	{"t": "Move", "d": "WASD or Arrow Keys to walk. Your character moves relative to the camera."},
	{"t": "Camera", "d": "Move the MOUSE to rotate the camera (cursor is locked while playing)."},
	{"t": "Zoom", "d": "MOUSE WHEEL or the +/- buttons to zoom in and out."},
	{"t": "Combat", "d": "Weapons fire AUTOMATICALLY at nearby enemies. Just stay close and dodge."},
	{"t": "XP & Gold", "d": "Cyan crystals = XP. Hearts heal. Every kill drops gold for UPGRADES."},
	{"t": "Abilities", "d": "Q = Meteor Strike, E = Time Freeze (or tap the big buttons)."},
	{"t": "Level Up", "d": "On level-up the game pauses — pick ONE of three upgrades. 5 weapon slots max."},
	{"t": "Pause", "d": "ESC or P pauses. II button too. You can restart or open settings from pause."},
]
const TOUCH_STEPS := [
	{"t": "Move", "d": "Touch & drag ANYWHERE ON THE LEFT HALF — a joystick appears wherever your finger lands."},
	{"t": "Camera", "d": "Touch & drag the RIGHT HALF to rotate the camera. It is independent of movement."},
	{"t": "Zoom", "d": "Use the + and - buttons above the ability buttons (bottom-right)."},
	{"t": "Combat", "d": "Weapons fire AUTOMATICALLY at nearby enemies. Just stay close and dodge."},
	{"t": "XP & Gold", "d": "Cyan crystals = XP (they fly to you). Hearts heal. Every kill drops gold for UPGRADES."},
	{"t": "Abilities", "d": "Tap the big Q/E buttons for Meteor Strike and Time Freeze."},
	{"t": "Level Up", "d": "On level-up the game pauses — pick ONE of three upgrades. 5 weapon slots max."},
	{"t": "Pause", "d": "The II button (top-right) pauses. Restart and settings are there too."},
]

@onready var title_label: Label = $Center/Panel/Layout/Title
@onready var desc_label: Label = $Center/Panel/Layout/Desc
@onready var dots_label: Label = $Center/Panel/Layout/Dots
@onready var next_button: Button = $Center/Panel/Layout/Buttons/NextButton
@onready var skip_button: Button = $Center/Panel/Layout/Buttons/SkipButton

var _steps: Array = []
var _index: int = 0

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	next_button.pressed.connect(_on_next)
	skip_button.pressed.connect(_on_skip)
	_steps = TOUCH_STEPS if DisplayServer.is_touchscreen_available() else DESKTOP_STEPS

## Returns true if the tutorial was shown (first time), false if already done.
func show_if_needed() -> bool:
	if SaveManager.get_setting(SAVE_KEY, false):
		return false
	# Headless CI/tests have no user to click NEXT — never trap the tree paused
	if DisplayServer.get_name() == "headless" or OS.has_feature("headless"):
		SaveManager.set_setting(SAVE_KEY, true)
		return false
	_index = 0
	visible = true
	get_tree().paused = true  # hold the horde until the player is ready
	_show_step()
	return true

func _show_step() -> void:
	var step: Dictionary = _steps[_index]
	title_label.text = "%d/%d  %s" % [_index + 1, _steps.size(), step["t"]]
	desc_label.text = step["d"]
	dots_label.text = "o ".repeat(_index) + "O" + " o".repeat(_steps.size() - _index - 1)
	next_button.text = "START" if _index == _steps.size() - 1 else "NEXT"

func _on_next() -> void:
	AudioManager.play_game_sfx("ui_click")
	if _index < _steps.size() - 1:
		_index += 1
		_show_step()
	else:
		_finish()

func _on_skip() -> void:
	AudioManager.play_game_sfx("ui_click")
	_finish()

func _finish() -> void:
	visible = false
	get_tree().paused = false
	_apply_mouse_mode()
	SaveManager.set_setting(SAVE_KEY, true)

func _apply_mouse_mode() -> void:
	if DisplayServer.is_touchscreen_available():
		return
	if GameManager.state == GameManager.State.PLAYING or GameManager.state == GameManager.State.BOSS:
		InputManager.capture_pointer()
	else:
		InputManager.release_pointer()
