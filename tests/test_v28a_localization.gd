extends SceneTree
## V28A — Localization: catalogue registration, locale switching, RTL.
##
## Covers Phase 3 item 5 of the improvement brief: tr() infrastructure with
## EN + FA, including right-to-left layout for Persian.

var failures := 0

func _initialize() -> void:
	await process_frame

	# --- Autoload exists and exposes the API ---
	var loc: Node = root.get_node_or_null("Localization")
	_check(loc != null, "Localization autoload is registered")
	if loc == null:
		_finish()
		return
	_check(loc.has_method("set_locale"), "Localization exposes set_locale")
	_check(loc.has_method("toggle_locale"), "Localization exposes toggle_locale")
	_check(loc.has_method("is_rtl"), "Localization exposes is_rtl")
	_check(loc.get("SUPPORTED_LOCALES").has("en"), "English is a supported locale")
	_check(loc.get("SUPPORTED_LOCALES").has("fa"), "Persian is a supported locale")

	# --- The catalogues are present, in sync and registered ---
	var en_keys: Array = loc.keys_for("en")
	var fa_keys: Array = loc.keys_for("fa")
	_check(en_keys.size() > 20, "the English catalogue has a usable number of keys (%d)" % en_keys.size())
	_check(fa_keys.size() == en_keys.size(),
		"both catalogues define the same number of keys (%d vs %d)" % [en_keys.size(), fa_keys.size()])
	var missing: String = ""
	for k in en_keys:
		if not fa_keys.has(k):
			missing = str(k)
			break
	_check(missing.is_empty(), "every English key exists in the Persian catalogue%s" % (
		"" if missing.is_empty() else " (missing '%s')" % missing))
	# Every Persian entry must actually be translated, not left in English.
	var untranslated: String = ""
	for k in fa_keys:
		var text: String = loc.text_for(k, "fa")
		var en_text: String = loc.text_for(k, "en")
		if text.is_empty() or text == en_text:
			untranslated = str(k)
			break
	_check(untranslated.is_empty(), "every Persian entry is translated%s" % (
		"" if untranslated.is_empty() else " (identical to English: '%s')" % untranslated))

	# --- Switching the locale changes the resolved strings ---
	var original: String = loc.get("current_locale")
	loc.set_locale("fa")
	_check(loc.get("current_locale") == "fa", "set_locale switches to Persian")
	_check(loc.is_rtl(), "Persian is detected as a right-to-left locale")
	var fa_text: String = tr("MENU_PLAY")
	_check(fa_text != "MENU_PLAY", "a translated key resolves in Persian (%s)" % fa_text)
	_check(fa_text == "بازی", "MENU_PLAY resolves to the Persian string")

	loc.set_locale("en")
	_check(loc.get("current_locale") == "en", "set_locale switches back to English")
	_check(not loc.is_rtl(), "English is not right-to-left")
	_check(tr("MENU_PLAY") == "PLAY", "MENU_PLAY resolves to the English string")

	# --- Unknown locales fall back to English ---
	loc.set_locale("xx")
	_check(loc.get("current_locale") == "en", "an unsupported locale falls back to English")

	# --- toggle cycles through the supported locales ---
	loc.set_locale("en")
	var toggled: String = loc.toggle_locale()
	_check(toggled == "fa", "toggle_locale cycles English -> Persian (%s)" % toggled)
	loc.toggle_locale()
	_check(loc.get("current_locale") == "en", "toggle_locale cycles back to English")

	# Restore the player's original locale.
	loc.set_locale(original)

	# --- The settings menu exposes a language switcher ---
	var menu_ps: PackedScene = load("res://scenes/menu/SettingsMenu.tscn")
	_check(menu_ps != null, "settings menu scene loads")
	if menu_ps != null:
		var menu := menu_ps.instantiate()
		root.add_child(menu)
		await process_frame
		_check(menu.get_node_or_null("Center/Panel/Layout/LocaleButton") != null,
			"settings menu has a language button")
		menu.queue_free()
		await process_frame

	_finish()

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1

func _finish() -> void:
	if failures == 0:
		print("V28A_LOCALIZATION_PASS")
	else:
		print("V28A_LOCALIZATION_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)
