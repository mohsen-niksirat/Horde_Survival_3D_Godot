extends Control
## Boot scene: warm the handful of data resources the menu reads immediately,
## then go straight to the main menu.
##
## The browser "Click to Play" gate lives in the HTML shell (web/custom_shell.html),
## so this scene never waits for user input — the old `_waiting_for_click`
## branch was dead code and its `_web_warmup()` (which synchronously parsed
## four GLBs inside the click handler) never ran at all.

func _ready() -> void:
	await get_tree().process_frame
	AudioManager.apply_saved_volumes()
	if OS.get_name() != "Web" and DisplayServer.get_name() != "headless":
		_prefetch_resources()
	_go_menu()

## Fire-and-forget warmup of the small data resources the menu and character
## select read right away. The menu scene itself is deliberately NOT requested
## here: `change_scene_to_file` loads it on the next line, so a threaded request
## would only make two loaders race over the same PackedScene.
func _prefetch_resources() -> void:
	var paths := [
		"res://data/characters/mage.tres",
		"res://data/characters/paladin.tres",
		"res://data/characters/rogue.tres",
		"res://data/weapons/fireball.tres",
		"res://data/weapons/magic_missile.tres",
	]
	for p in paths:
		if ResourceLoader.exists(p):
			ResourceLoader.load_threaded_request(p)

func _go_menu() -> void:
	GameManager.goto_menu()
