extends SceneTree
## V25A — Save robustness: version migration and corrupt-file recovery.
##
## The improvement brief's Phase 2 asks for:
##  - old save versions migrate without losing gold / achievements
##  - a corrupt or truncated save falls back to defaults with a warning,
##    never a crash
##
## The save file lives in user://, so the test drives the real file on disk.

const SAVE_PATH := "user://meta_save.json"

var failures := 0

func _initialize() -> void:
	await process_frame

	var saves := root.get_node("SaveManager")
	var original: Dictionary = saves.data.duplicate(true)

	# --- Round-trip: what we write is what we read back ---
	saves.delete_save()
	saves.set_meta_data("gold", 4321)
	saves.set_meta_data("achievements", {"first_blood": true, "untouchable": true})
	saves.set_meta_data("best_time", 612.5)
	saves.load_game()
	_check(int(saves.get_meta_data("gold", 0)) == 4321, "gold survives a save round-trip")
	_check(saves.get_meta_data("achievements", {}).size() == 2, "achievements survive a save round-trip")
	_check(absf(float(saves.get_meta_data("best_time", 0.0)) - 612.5) < 0.01, "best time survives a save round-trip")

	# --- Migration: a v0 save (no save_version, missing sections) ---
	var legacy := {
		"settings": {"master_volume": 0.42, "quality": 2},
		"meta": {"gold": 777, "achievements": {"veteran": true}, "selected_character": "rogue"},
	}
	_write_raw(legacy)
	saves.load_game()
	_check(int(saves.get_meta_data("gold", 0)) == 777, "legacy save keeps gold")
	_check(saves.get_meta_data("achievements", {}).has("veteran"), "legacy save keeps achievements")
	_check(str(saves.get_meta_data("selected_character", "")) == "rogue", "legacy save keeps the selected character")
	_check(absf(float(saves.get_setting("master_volume", 0.0)) - 0.42) < 0.01, "legacy save keeps settings")
	# Missing keys must be filled from the defaults, not left undefined.
	_check(saves.get_setting("music_volume", null) != null, "migration fills missing settings from defaults")
	_check(saves.get_meta_data("total_runs", null) != null, "migration fills missing meta keys from defaults")
	# A legacy save keeps the LEGACY quality schema on purpose: the old
	# 0..3 quality scale means something different from the current 0..5
	# scale, so stamping the new schema would silently change the player's
	# graphics tier. PerformanceManager migrates it on load instead.
	_check(int(saves.get_setting("quality_schema", 99)) < 2, "legacy save keeps the legacy quality schema")
	_check(int(saves.get_setting("quality", -1)) == 2, "migration keeps the legacy quality value")
	# PerformanceManager must translate the legacy value, not use it raw.
	var perf: Node = root.get_node("PerformanceManager")
	_check(perf.has_method("_migrate_legacy_quality"), "PerformanceManager can migrate legacy quality values")
	var migrated: int = perf._migrate_legacy_quality(2)
	_check(migrated == perf.Quality.HIGH, "legacy quality 2 maps to HIGH in the new scale")
	_check(perf._migrate_legacy_quality(0) == perf.Quality.LOW, "legacy quality 0 maps to LOW in the new scale")
	_check(perf._migrate_legacy_quality(3) == perf.QUALITY_AUTO_SETTING, "legacy quality 3 maps to Auto in the new scale")

	# --- Corrupt file: not valid JSON ---
	_write_text("{ this is not json ")
	saves.load_game()
	_check(saves.data.get("meta", {}).get("gold", 0) == 0, "corrupt save falls back to default gold")
	_check(saves.get_setting("master_volume", null) != null, "corrupt save falls back to default settings")
	_check(saves.data.has("settings") and saves.data.has("meta"), "corrupt save still has a complete data shape")

	# --- Truncated file: valid JSON prefix but cut off mid-object ---
	_write_text('{"settings": {"master_volume": 0.5}, "meta": {"gold": 100')
	saves.load_game()
	_check(saves.get_setting("master_volume", null) != null, "truncated save falls back to defaults")
	_check(saves.data.has("meta"), "truncated save still has a meta section")

	# --- Empty file ---
	_write_text("")
	saves.load_game()
	_check(saves.get_setting("master_volume", null) != null, "empty save falls back to defaults")

	# --- Wrong top-level type (an array instead of an object) ---
	_write_text("[1, 2, 3]")
	saves.load_game()
	_check(saves.get_setting("master_volume", null) != null, "array-shaped save falls back to defaults")

	# --- Missing file entirely ---
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	saves.load_game()
	_check(saves.get_setting("master_volume", null) != null, "missing save falls back to defaults")
	_check(saves.get_meta_data("gold", 0) == 0, "missing save starts with zero gold")

	# --- Restore the player's real save so the test is not destructive ---
	saves.data = original
	saves.save_game()

	_finish()

## Write a raw JSON payload straight to the save file (bypassing SaveManager).
func _write_raw(payload: Dictionary) -> void:
	_write_text(JSON.stringify(payload))

func _write_text(text: String) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("cannot open save for writing")
		return
	file.store_string(text)
	file.close()

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1

func _finish() -> void:
	if failures == 0:
		print("V25A_SAVE_ROBUST_PASS")
	else:
		print("V25A_SAVE_ROBUST_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)
