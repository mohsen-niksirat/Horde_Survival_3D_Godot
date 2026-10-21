extends Node
## Localization bootstrap: parses the translation catalogues and exposes the
## active locale.
##
## The catalogue files live in `locale/<locale>.csv` with the format
##
##     keys,<col0>,<col1>,...
##     KEY,English text,Persian text
##
## The catalogues are parsed at runtime instead of relying on Godot's CSV
## importer, because the importer generates per-column `.translation`
## artifacts whose paths differ between the editor and an exported build.
## Runtime parsing behaves identically everywhere (desktop, web, Android).
##
## UI strings use `tr("KEY")`; a missing key falls back to the key itself,
## which makes untranslated strings obvious instead of silently empty.

const CSV_DIR := "res://locale/"

## The locales the game ships with. The first entry is the fallback.
const SUPPORTED_LOCALES := ["en", "fa"]

## Locales that are written right-to-left.
const RTL_LOCALES := ["fa", "ar", "he", "ur"]

var current_locale: String = "en"
## locale -> { key -> text }
var _catalogues: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_catalogues()
	_apply_saved_locale()

## Parse every catalogue into a Translation and register it.
func _load_catalogues() -> void:
	_catalogues.clear()
	# The first catalogue holds every key; later ones only fill in gaps.
	for loc in SUPPORTED_LOCALES:
		var path := "%s%s.csv" % [CSV_DIR, loc]
		if not FileAccess.file_exists(path):
			continue
		var rows := _read_csv(path)
		if rows.is_empty():
			continue
		_catalogues[loc] = rows
		var tr_res := Translation.new()
		tr_res.locale = loc
		for key in rows:
			tr_res.add_message(key, String(rows[key]))
		TranslationServer.add_translation(tr_res)

## Read a catalogue into { key -> text } for the locale implied by the file
## name. Rows with fewer columns than the header are padded.
func _read_csv(path: String) -> Dictionary:
	var out: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	var header := file.get_csv_line()
	if header.is_empty():
		file.close()
		return out
	# Column 0 is the key column; column 1 is the text for this file's
	# locale. Extra columns are ignored.
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.is_empty():
			continue
		var key := String(line[0]).strip_edges()
		if key.is_empty():
			continue
		var value := ""
		if line.size() > 1:
			value = String(line[1])
		out[key] = value
	file.close()
	return out

func _apply_saved_locale() -> void:
	set_locale(str(SaveManager.get_setting("locale", "en")))

## Switch the active locale. Returns the locale actually applied.
func set_locale(loc: String) -> String:
	var wanted := loc
	if not SUPPORTED_LOCALES.has(wanted):
		wanted = SUPPORTED_LOCALES[0]
	current_locale = wanted
	TranslationServer.set_locale(wanted)
	EventBus.settings_changed.emit()
	return wanted

## Cycle through the supported locales.
func toggle_locale() -> String:
	var idx: int = SUPPORTED_LOCALES.find(current_locale)
	if idx < 0:
		idx = 0
	var next_locale: String = SUPPORTED_LOCALES[(idx + 1) % SUPPORTED_LOCALES.size()]
	SaveManager.set_setting("locale", next_locale)
	return set_locale(next_locale)

## True when the active locale is written right-to-left.
func is_rtl() -> bool:
	return RTL_LOCALES.has(current_locale)

## Human-readable name of a locale, in that locale.
func locale_display_name(loc: String) -> String:
	match loc:
		"en": return "English"
		"fa": return "فارسی"
		_: return loc

## All keys known to the catalogue of the given locale.
func keys_for(loc: String) -> Array:
	var out: Array = []
	if _catalogues.has(loc):
		out = (_catalogues[loc] as Dictionary).keys()
	out.sort()
	return out

## The raw text of a key in the given locale, or an empty string.
func text_for(key: String, loc: String) -> String:
	if _catalogues.has(loc):
		var rows: Dictionary = _catalogues[loc]
		if rows.has(key):
			return String(rows[key])
	return ""
