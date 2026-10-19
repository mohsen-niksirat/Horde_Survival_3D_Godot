extends Control
## Boot scene: loading text, then straight to the main menu.
## Web builds get a "Click to Play" gate (user gesture unlocks audio +
## enables fullscreen-friendly input) — desktop skips it.

@onready var click_label: Label = $ClickLabel

var _waiting_for_click: bool = false
var _load_phase: int = 0  # 0=none, 1=prewarm, 2=ready

func _ready() -> void:
	await get_tree().process_frame
	AudioManager.apply_saved_volumes()
	# V21A: warm up common resources in the background during the click-gate
	# so the menu doesn't hitch on first render. Only native; Web uses its
	# own thread-safe warmup in Main so we don't block the click gate.
	if OS.get_name() != "Web" and DisplayServer.get_name() != "headless":
		_prefetch_resources()
	if OS.get_name() == "Web":
		click_label.visible = true
		_waiting_for_click = true
	else:
		_go_menu()

# V21A: fire-and-forget warmup of the most-hit resources during the
# interactive click-gate window. No await / no blocking of _go_menu.
func _prefetch_resources() -> void:
	if _load_phase != 0:
		return
	_load_phase = 1
	var paths := [
		"res://scenes/menu/MainMenu.tscn",
		"res://data/characters/mage.tres",
		"res://data/characters/knight.tres",
		"res://data/characters/rogue.tres",
		"res://data/weapons/fireball.tres",
		"res://data/weapons/spear.tres",
	]
	for p in paths:
		if ResourceLoader.exists(p):
			ResourceLoader.load_threaded_request(p)
	_load_phase = 2

func _input(event: InputEvent) -> void:
	if not _waiting_for_click:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		_waiting_for_click = false
		click_label.visible = false
		_go_menu()

func _go_menu() -> void:
	GameManager.goto_menu()
