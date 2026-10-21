extends SceneTree
## V24A — Android port support validation.
##
## Covers Phase 1 of the improvement plan:
##  - Android export preset exists with ARM64 architecture
##  - safe-area inset math is correct (notch / punch-hole)
##  - back button routing: in-game pauses, in-menu steps back, menu asks to exit
##  - app lifecycle: backgrounding pauses the run and flushes the save
##  - PerformanceManager exposes a mobile platform check

var failures := 0

func _initialize() -> void:
	await process_frame

	# The save file persists between runs (user://), so start from a clean
	# slate — otherwise a previously saved quality tier leaks into the
	# assertions below and the test stops being repeatable.
	var saves := root.get_node("SaveManager")
	saves.delete_save()
	saves.load_game()
	await process_frame

	# --- Export preset: Android with ARM64 ---
	var presets := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	_check(presets != null, "export_presets.cfg is readable")
	if presets != null:
		var text := presets.get_as_text()
		presets.close()
		_check(text.contains("name=\"Android\""), "Android export preset exists")
		_check(text.contains("platform=\"Android\""), "Android preset targets the Android platform")
		_check(text.contains("architectures/arm64-v8a=true"), "Android preset enables ARM64")
		_check(text.contains("architectures/armeabi-v7a=false") or text.contains("architectures/armeabi-v7a=true"),
			"Android preset declares an ARMv7 architecture flag")
		_check(text.contains("package/unique_name="), "Android preset sets a package name")

	# --- Safe area math ---
	# Full-screen device: no insets at all.
	var full := SafeArea.viewport_safe_rect(Vector2(1280, 720), Vector2(2400, 1080), Rect2(0, 0, 2400, 1080))
	_check(full.position.is_equal_approx(Vector2.ZERO), "no insets on a full-screen device")
	_check(full.size.is_equal_approx(Vector2(1280, 720)), "full-screen safe rect fills the viewport")

	# Landscape notch on the left: safe area starts 100px into the screen.
	var notch := SafeArea.viewport_safe_rect(Vector2(1280, 720), Vector2(2400, 1080), Rect2(100, 0, 2300, 1080))
	_check(notch.position.x > 0.0, "notch on the left produces a left inset")
	_check(notch.size.x < 1280.0, "notch shrinks the usable width")
	_check(notch.position.x + notch.size.x <= 1280.0 + 0.01, "notched safe rect stays inside the viewport")

	# Degenerate inputs must never produce a negative or NaN rect.
	var zero := SafeArea.viewport_safe_rect(Vector2.ZERO, Vector2.ZERO, Rect2())
	_check(zero.size.x >= 0.0 and zero.size.y >= 0.0, "degenerate inputs give a non-negative rect")

	# A safe rect larger than the screen must be clamped, not overflow.
	var huge := SafeArea.viewport_safe_rect(Vector2(800, 600), Vector2(100, 100), Rect2(0, 0, 100, 100))
	_check(huge.size.x <= 800.0 and huge.size.y <= 600.0, "oversized safe rect is clamped to the viewport")

	# Desktop / web must never be inset — only mobile platforms have cutouts.
	_check(SafeArea.is_mobile() == false, "desktop test run reports no mobile platform")
	var desktop_pads: Vector4 = SafeArea.insets_for(null)
	_check(desktop_pads == Vector4.ZERO, "no safe-area insets off-mobile")

	# --- Back button routing ---
	var gm := root.get_node("GameManager")
	var bus := root.get_node("EventBus")
	_check(gm.has_method("handle_back_request"), "GameManager exposes handle_back_request")
	_check(gm.handle_back_request() == false, "back request in an idle state is not consumed")

	# In a run: back pauses.
	gm.state = gm.State.PLAYING
	_check(gm.handle_back_request() == true, "back request during play is consumed")
	_check(gm.state == gm.State.PAUSED, "back request during play pauses the game")

	# In pause: back resumes.
	_check(gm.handle_back_request() == true, "back request while paused is consumed")
	_check(gm.state == gm.State.PLAYING, "back request while paused resumes the game")

	# In a sub-menu: the menu scene closes its own panels. With no menu scene
	# loaded the request falls through to the exit confirmation.
	gm.state = gm.State.MAIN_MENU
	var confirm_fired := [false]
	var on_confirm := func(): confirm_fired[0] = true
	bus.exit_confirm_requested.connect(on_confirm)
	_check(gm.handle_back_request() == true, "back request on the main menu is consumed")
	_check(confirm_fired[0], "back request on the main menu asks for exit confirmation")
	bus.exit_confirm_requested.disconnect(on_confirm)

	# --- App lifecycle: pause + save flush ---
	var im := root.get_node("InputManager")
	_check(im.has_method("_on_app_paused"), "InputManager exposes the app-paused handler")
	gm.state = gm.State.PLAYING
	im._on_app_paused()
	_check(gm.state == gm.State.PAUSED, "backgrounding the app pauses the run")
	_check(saves.has_save(), "backgrounding the app flushes the save to disk")

	# --- PerformanceManager mobile detection ---
	var perf := root.get_node("PerformanceManager")
	_check(perf.has_method("is_mobile_platform"), "PerformanceManager exposes is_mobile_platform")
	# A fresh install (no save file) must start on the cheapest tier. The
	# loaded tier itself depends on the player's saved choice, so assert the
	# default rather than the current value.
	_check(perf._default_quality() == perf.Quality.VERY_LOW,
		"fresh installs default to the lowest tier")
	_check(perf.Quality.VERY_LOW == 0, "VERY_LOW is the cheapest enum value")

	# --- Main menu back button closes the topmost open panel ---
	var menu_ps: PackedScene = load("res://scenes/menu/MainMenu.tscn")
	var menu := menu_ps.instantiate()
	root.add_child(menu)
	await process_frame
	_check(menu.has_method("handle_back_request"), "main menu exposes handle_back_request")
	var char_panel: Control = menu.get_node_or_null("CharacterSelect")
	_check(char_panel != null, "main menu has a character select panel")
	if char_panel != null:
		char_panel.visible = true
		_check(menu.handle_back_request() == true, "back closes an open panel")
		_check(not char_panel.visible, "back hides the open panel")
		_check(menu.handle_back_request() == false, "back reports nothing to close when no panel is open")
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
		print("V24A_ANDROID_PASS")
	else:
		print("V24A_ANDROID_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)
