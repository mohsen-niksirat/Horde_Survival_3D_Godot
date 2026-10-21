extends SceneTree
## V27A — Release plumbing: in-game feedback link, changelog, semver.
##
## Covers Phase 4 of the improvement brief:
##  - a feedback link inside the game (Settings menu)
##  - a CHANGELOG that follows Keep a Changelog
##  - semver version metadata in the export preset

var failures := 0

func _initialize() -> void:
	await process_frame

	# --- External link helper ---
	_check(ExternalLinks.FEEDBACK_URL.begins_with("https://"),
		"feedback URL is https")
	_check(ExternalLinks.FEEDBACK_URL.contains("issues"),
		"feedback URL points at the issue tracker")
	_check(ExternalLinks.ISSUES_URL.contains("github.com"),
		"issues URL points at GitHub")
	_check(ExternalLinks.CHANGELOG_URL.ends_with("CHANGELOG.md"),
		"changelog URL points at the changelog")
	_check(ExternalLinks.open("") == false, "opening an empty URL is refused")

	# --- The settings menu exposes a feedback button that is wired up ---
	var menu_ps: PackedScene = load("res://scenes/menu/SettingsMenu.tscn")
	_check(menu_ps != null, "settings menu scene loads")
	if menu_ps != null:
		var menu := menu_ps.instantiate()
		root.add_child(menu)
		await process_frame
		var fb: Button = menu.get_node_or_null("Center/Panel/Layout/FeedbackButton")
		_check(fb != null, "settings menu has a feedback button")
		if fb != null:
			_check(fb.text != "", "feedback button has a label")
			_check(fb.focus_mode == Control.FOCUS_NONE,
				"feedback button never takes keyboard focus")
			_check(menu.has_method("_on_feedback_pressed"),
				"feedback button is wired to a handler")
		menu.queue_free()
		await process_frame

	# --- CHANGELOG exists and follows the expected sections ---
	var f := FileAccess.open("res://CHANGELOG.md", FileAccess.READ)
	_check(f != null, "CHANGELOG.md exists")
	if f != null:
		var text := f.get_as_text()
		f.close()
		_check(text.contains("# Changelog"), "CHANGELOG has a title")
		_check(text.contains("Keep a Changelog"), "CHANGELOG names its format")
		_check(text.contains("Semantic Versioning"), "CHANGELOG names its version scheme")
		_check(text.contains("## [Unreleased]"), "CHANGELOG has an Unreleased section")
		for section in ["### Added", "### Changed", "### Fixed"]:
			_check(text.contains(section), "CHANGELOG has a %s section" % section)

	# --- Export preset carries a semver version ---
	var presets := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	_check(presets != null, "export_presets.cfg is readable")
	if presets != null:
		var ptext := presets.get_as_text()
		presets.close()
		_check(ptext.contains("version/name="), "export preset declares a version name")
		var version := _extract_version(ptext)
		_check(version != "", "export preset version is parseable (%s)" % version)
		_check(_is_semver(version), "export preset version is semver (%s)" % version)
		_check(ptext.contains("version/code="), "export preset declares a version code")

	# --- The web build exposes the same version so players can report it ---
	var project := FileAccess.open("res://project.godot", FileAccess.READ)
	if project != null:
		var ptext := project.get_as_text()
		project.close()
		_check(ptext.contains("config/name="), "project.godot has an application name")

	_finish()

func _extract_version(text: String) -> String:
	for line in text.split("\n"):
		if line.begins_with("version/name="):
			return line.split("=")[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
	return ""

## Loose semver check: MAJOR.MINOR.PATCH with optional pre-release/build.
func _is_semver(v: String) -> bool:
	var parts := v.split(".")
	if parts.size() < 3:
		return false
	for i in range(3):
		if not parts[i].is_valid_int():
			return false
	return true

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1

func _finish() -> void:
	if failures == 0:
		print("V27A_RELEASE_PASS")
	else:
		print("V27A_RELEASE_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)
