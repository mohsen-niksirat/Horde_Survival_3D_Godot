extends Control
## Settings: volume, look, quality tiers (Very Low → Ultra + Auto), toggles.
## Quality default is the lowest tier so first browser load is fast.

@onready var master_slider: HSlider = $Center/Panel/Layout/MasterRow/MasterSlider
@onready var music_slider: HSlider = $Center/Panel/Layout/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $Center/Panel/Layout/SfxRow/SfxSlider
@onready var sensitivity_slider: HSlider = $Center/Panel/Layout/SensRow/SensSlider
@onready var touch_sens_slider: HSlider = $Center/Panel/Layout/TouchSensRow/TouchSensSlider
@onready var haptics_check: CheckButton = $Center/Panel/Layout/HapticsCheck
@onready var fullscreen_check: CheckButton = $Center/Panel/Layout/FullscreenCheck
@onready var shake_check: CheckButton = $Center/Panel/Layout/ShakeCheck
@onready var quality_option: OptionButton = $Center/Panel/Layout/QualityRow/QualityOption
@onready var close_button: Button = $Center/Panel/Layout/CloseButton
@onready var feedback_button: Button = $Center/Panel/Layout/FeedbackButton
@onready var layout: Control = $Center/Panel/Layout

const Q_ITEMS := ["Very Low (fastest)", "Low", "Medium", "High", "Ultra", "Auto"]

var scale_label: Label
var ui_scale_slider: HSlider
var reduced_vfx_check: CheckButton
var music_mute_check: CheckButton
var sfx_mute_check: CheckButton
var locale_button: Button
var analytics_check: CheckButton
var _message_label: Label
var _save_timer: Timer

## Live-update a setting in memory and schedule a single debounced disk write.
func _set_setting_debounced(key: String, value) -> void:
	if not SaveManager.data.has("settings"):
		SaveManager.data["settings"] = {}
	SaveManager.data["settings"][key] = value
	_save_timer.start()

func _on_save_debounce() -> void:
	SaveManager.save_game()
	EventBus.settings_changed.emit()

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Debounced persistence: sliders update live but SaveManager.set_setting
	# writes to disk, so per-tick writes are replaced by one save after the drag.
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	_save_timer.timeout.connect(_on_save_debounce)
	add_child(_save_timer)
	quality_option.clear()
	for item in Q_ITEMS:
		quality_option.add_item(item)
	_build_v19_rows()
	# Android notch / punch-hole: the settings panel is a centred box that
	# can still land under a cutout in landscape.
	get_viewport().size_changed.connect(_apply_safe_area)
	call_deferred("_apply_safe_area")

	master_slider.value = SaveManager.get_setting("master_volume", 0.8)
	music_slider.value = SaveManager.get_setting("music_volume", 0.7)
	sfx_slider.value = SaveManager.get_setting("sfx_volume", 0.8)
	sensitivity_slider.value = SaveManager.get_setting("look_sensitivity", 1.0)
	touch_sens_slider.value = SaveManager.get_setting("touch_sensitivity", 1.0)
	haptics_check.button_pressed = SaveManager.get_setting("haptics", false)
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	shake_check.button_pressed = SaveManager.get_setting("screen_shake", true)
	if ui_scale_slider != null:
		ui_scale_slider.value = SaveManager.get_setting("ui_scale", 1.0)
	if reduced_vfx_check != null:
		reduced_vfx_check.button_pressed = SaveManager.get_setting("reduced_vfx", false)
	var q: int = int(SaveManager.get_setting("quality", 0))
	if PerformanceManager != null and PerformanceManager.auto_mode:
		quality_option.selected = 5
	elif q == 5:
		quality_option.selected = 5
	else:
		quality_option.selected = clampi(int(PerformanceManager.quality if PerformanceManager != null else q), 0, 4)

	master_slider.value_changed.connect(_on_volume.bind("master_volume"))
	music_slider.value_changed.connect(_on_volume.bind("music_volume"))
	sfx_slider.value_changed.connect(_on_volume.bind("sfx_volume"))
	sensitivity_slider.value_changed.connect(_on_sensitivity)
	touch_sens_slider.value_changed.connect(_on_touch_sensitivity)
	haptics_check.toggled.connect(_on_haptics)
	fullscreen_check.toggled.connect(_on_fullscreen)
	shake_check.toggled.connect(_on_shake)
	quality_option.item_selected.connect(_on_quality)
	if ui_scale_slider != null:
		ui_scale_slider.value_changed.connect(_on_ui_scale)
	if reduced_vfx_check != null:
		reduced_vfx_check.toggled.connect(_on_reduced_vfx)
	close_button.pressed.connect(_on_close)
	if feedback_button != null:
		feedback_button.pressed.connect(_on_feedback_pressed)
		feedback_button.focus_mode = Control.FOCUS_NONE
	EventBus.game_state_changed.connect(_on_state_changed)
	_apply_ui_scale(float(SaveManager.get_setting("ui_scale", 1.0)))

## V19: dynamically add UI-scale + reduced-VFX rows (avoids fragile .tscn edits).
func _build_v19_rows() -> void:
	if layout == null:
		return
	var scale_row := HBoxContainer.new()
	scale_row.name = "UiScaleRow"
	scale_label = Label.new()
	scale_label.text = tr("SETTINGS_UI_SCALE")
	scale_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_scale_slider = HSlider.new()
	ui_scale_slider.name = "UiScaleSlider"
	ui_scale_slider.min_value = 0.75
	ui_scale_slider.max_value = 1.5
	ui_scale_slider.step = 0.05
	ui_scale_slider.value = 1.0
	ui_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_row.add_child(scale_label)
	scale_row.add_child(ui_scale_slider)
	layout.add_child(scale_row)
	# Insert before close button if possible
	layout.move_child(scale_row, maxi(0, close_button.get_index() - 1))

	reduced_vfx_check = CheckButton.new()
	reduced_vfx_check.name = "ReducedVfxCheck"
	reduced_vfx_check.text = tr("SETTINGS_REDUCED_VFX")
	layout.add_child(reduced_vfx_check)
	layout.move_child(reduced_vfx_check, close_button.get_index())

	var dmg_check := CheckButton.new()
	dmg_check.name = "DamageNumbersCheck"
	dmg_check.text = "Damage Numbers"
	dmg_check.button_pressed = SaveManager.get_setting("show_damage_numbers", true)
	dmg_check.toggled.connect(func(p: bool): SaveManager.set_setting("show_damage_numbers", p))
	layout.add_child(dmg_check)
	layout.move_child(dmg_check, close_button.get_index())

	# V27A: independent mute toggles for the music mix and the SFX mix.
	music_mute_check = CheckButton.new()
	music_mute_check.name = "MusicMuteCheck"
	music_mute_check.text = tr("SETTINGS_MUTE_MUSIC")
	music_mute_check.button_pressed = AudioManager.is_music_muted()
	music_mute_check.toggled.connect(func(p: bool): AudioManager.set_music_muted(p))
	layout.add_child(music_mute_check)
	layout.move_child(music_mute_check, close_button.get_index())

	sfx_mute_check = CheckButton.new()
	sfx_mute_check.name = "SfxMuteCheck"
	sfx_mute_check.text = tr("SETTINGS_MUTE_SFX")
	sfx_mute_check.button_pressed = AudioManager.is_sfx_muted()
	sfx_mute_check.toggled.connect(func(p: bool): AudioManager.set_sfx_muted(p))
	layout.add_child(sfx_mute_check)
	layout.move_child(sfx_mute_check, close_button.get_index())

	# V28A: language switcher (EN / FA). RTL locales mirror the layout.
	locale_button = Button.new()
	locale_button.name = "LocaleButton"
	locale_button.text = tr("SETTINGS_LANGUAGE") + ": " + Localization.locale_display_name(Localization.current_locale)
	locale_button.pressed.connect(_on_locale_pressed)
	layout.add_child(locale_button)
	layout.move_child(locale_button, close_button.get_index())

	# V29A: opt-in local analytics. Nothing is recorded while it is off.
	analytics_check = CheckButton.new()
	analytics_check.name = "AnalyticsCheck"
	analytics_check.text = tr("SETTINGS_ANALYTICS")
	analytics_check.button_pressed = Analytics.enabled
	analytics_check.toggled.connect(func(p: bool): Analytics.set_enabled(p))
	layout.add_child(analytics_check)
	layout.move_child(analytics_check, close_button.get_index())

func _on_ui_scale(value: float) -> void:
	_set_setting_debounced("ui_scale", value)
	_apply_ui_scale(value)

## Show a short message in the settings panel. Uses a dedicated label so the
## message does not overwrite any setting row.
func _label(text: String) -> void:
	if _message_label == null:
		_message_label = Label.new()
		_message_label.name = "Message"
		_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_message_label.custom_minimum_size = Vector2(360, 0)
		_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_message_label.add_theme_font_size_override("font_size", 14)
		_message_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		if layout != null:
			layout.add_child(_message_label)
			layout.move_child(_message_label, close_button.get_index())
	_message_label.text = text
	_message_label.visible = text != ""

func _apply_ui_scale(value: float) -> void:
	var win := get_window()
	if win != null:
		win.content_scale_factor = clampf(value, 0.75, 1.5)

func _on_reduced_vfx(pressed: bool) -> void:
	SaveManager.set_setting("reduced_vfx", pressed)
	if PerformanceManager != null and PerformanceManager.has_method("notify_reduced_vfx"):
		PerformanceManager.notify_reduced_vfx()

func _on_sensitivity(value: float) -> void:
	_set_setting_debounced("look_sensitivity", value)

func _on_touch_sensitivity(value: float) -> void:
	_set_setting_debounced("touch_sensitivity", value)

func _on_haptics(pressed: bool) -> void:
	SaveManager.set_setting("haptics", pressed)

func _on_fullscreen(pressed: bool) -> void:
	var is_fs: bool = InputManager.is_fullscreen()
	if pressed != is_fs:
		InputManager.toggle_fullscreen()

func _on_state_changed(_new_state: int, _old: int) -> void:
	pass

## Inset the panel to the display safe area (Android notch / punch-hole).
## The overlay root is full-rect, so insetting it pulls the panel inward.
func _apply_safe_area() -> void:
	if not is_inside_tree():
		return
	var pads: Vector4 = SafeArea.insets_for(self)
	offset_left = pads.x
	offset_top = pads.y
	offset_right = -pads.z
	offset_bottom = -pads.w

func open() -> void:
	visible = true
	_apply_safe_area()
	# Keep the mute toggles in sync with the live audio state.
	if music_mute_check != null:
		music_mute_check.set_pressed_no_signal(AudioManager.is_music_muted())
	if sfx_mute_check != null:
		sfx_mute_check.set_pressed_no_signal(AudioManager.is_sfx_muted())
	_refresh_locale_labels()
	layout_direction = Control.LAYOUT_DIRECTION_RTL if Localization.is_rtl() else Control.LAYOUT_DIRECTION_LTR

func _on_volume(value: float, key: String) -> void:
	_set_setting_debounced(key, value)
	AudioManager.apply_saved_volumes()

func _on_shake(pressed: bool) -> void:
	SaveManager.set_setting("screen_shake", pressed)

func _on_quality(index: int) -> void:
	if index == 5:
		# Auto: start from lowest, let FPS monitor climb if the machine can
		PerformanceManager.set_auto_mode(true)
		PerformanceManager.set_quality(PerformanceManager.Quality.VERY_LOW, false)
	else:
		PerformanceManager.set_auto_mode(false)
		PerformanceManager.set_quality(index, true)

func _on_close() -> void:
	visible = false

## Open the GitHub issue form in the player's browser. This is the in-game
## feedback channel required before a public release.
func _on_feedback_pressed() -> void:
	AudioManager.play_game_sfx("ui_click")
	if not ExternalLinks.open_feedback():
		# The platform refused to open a URL — tell the player where to go.
		_label("Could not open the browser. Please visit:\n%s" % ExternalLinks.FEEDBACK_URL)

## Cycle the UI language (EN <-> FA) and remember the choice.
func _on_locale_pressed() -> void:
	AudioManager.play_game_sfx("ui_click")
	var applied: String = Localization.toggle_locale()
	SaveManager.set_setting("locale", applied)
	_refresh_locale_labels()
	# The whole panel mirrors for right-to-left locales.
	layout_direction = Control.LAYOUT_DIRECTION_RTL if Localization.is_rtl() else Control.LAYOUT_DIRECTION_LTR

func _refresh_locale_labels() -> void:
	if locale_button != null:
		locale_button.text = tr("SETTINGS_LANGUAGE") + ": " + Localization.locale_display_name(Localization.current_locale)
	if scale_label != null:
		scale_label.text = tr("SETTINGS_UI_SCALE")
	if reduced_vfx_check != null:
		reduced_vfx_check.text = tr("SETTINGS_REDUCED_VFX")
	if music_mute_check != null:
		music_mute_check.text = tr("SETTINGS_MUTE_MUSIC")
	if sfx_mute_check != null:
		sfx_mute_check.text = tr("SETTINGS_MUTE_SFX")
	if feedback_button != null:
		feedback_button.text = tr("SETTINGS_FEEDBACK")
	if close_button != null:
		close_button.text = tr("SETTINGS_CLOSE")
	if _message_label != null:
		_message_label.visible = false
