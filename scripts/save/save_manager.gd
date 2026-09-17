extends Node
## Platform-agnostic versioned save system. user:// works on desktop and maps
## to IndexedDB on Web.

const SAVE_PATH := "user://meta_save.json"
const SAVE_VERSION := 1

signal save_loaded()

var data: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	data["save_version"] = SAVE_VERSION
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open save file for writing")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_game() -> void:
	if not has_save():
		data = _default_data()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		data = _default_data()
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: corrupt save, resetting")
		data = _default_data()
		return
	data = _migrate(parsed)
	save_loaded.emit()

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	data = _default_data()

func _default_data() -> Dictionary:
	return {
		"settings": {
			"master_volume": 0.8,
			"music_volume": 0.7,
			"sfx_volume": 0.8,
			"quality": 0,
			"quality_schema": 2,
			"show_damage_numbers": true,
			"screen_shake": true,
			"tutorial_done": false,
		},
		"meta": {
			"gold": 0,
			"unlocked_characters": ["mage"],
			"selected_character": "mage",
			"achievements": {},
			"best_time": 0.0,
			"best_level": 0,
			"total_runs": 0,
			"total_kills": 0,
			"meta_upgrades": {},
		},
	}

func _migrate(parsed: Dictionary) -> Dictionary:
	var version: int = int(parsed.get("save_version", 0))
	var defaults := _default_data()
	# Deep-merge missing keys so older saves pick up new defaults
	for section in defaults:
		if not parsed.has(section) or typeof(parsed[section]) != TYPE_DICTIONARY:
			parsed[section] = defaults[section]
		else:
			for key in defaults[section]:
				if not parsed[section].has(key):
					parsed[section][key] = defaults[section][key]
	parsed["save_version"] = max(version, SAVE_VERSION)
	return parsed

func get_setting(key: String, fallback = null):
	return data.get("settings", {}).get(key, fallback)

func set_setting(key: String, value) -> void:
	if not data.has("settings"):
		data["settings"] = {}
	data["settings"][key] = value
	save_game()
	EventBus.settings_changed.emit()

func get_meta_data(key: String, fallback = null):
	return data.get("meta", {}).get(key, fallback)

func set_meta_data(key: String, value) -> void:
	if not data.has("meta"):
		data["meta"] = {}
	data["meta"][key] = value
	save_game()
