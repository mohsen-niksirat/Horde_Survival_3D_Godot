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
@onready var layout: Control = $Center/Panel/Layout

const Q_ITEMS := ["Very Low (fastest)", "Low", "Medium", "High", "Ultra", "Auto"]

var ui_scale_slider: HSlider
var reduced_vfx_check: CheckButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	quality_option.clear()
	for item in Q_ITEMS:
		quality_option.add_item(item)
	_build_v19_rows()

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
	EventBus.game_state_changed.connect(_on_state_changed)
	_apply_ui_scale(float(SaveManager.get_setting("ui_scale", 1.0)))

## V19: dynamically add UI-scale + reduced-VFX rows (avoids fragile .tscn edits).
func _build_v19_rows() -> void:
	if layout == null:
		return
	var scale_row := HBoxContainer.new()
	scale_row.name = "UiScaleRow"
	var scale_label := Label.new()
	scale_label.text = "UI Scale"
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
	reduced_vfx_check.text = "Reduced VFX"
	layout.add_child(reduced_vfx_check)
	layout.move_child(reduced_vfx_check, close_button.get_index())

	var dmg_check := CheckButton.new()
	dmg_check.name = "DamageNumbersCheck"
	dmg_check.text = "Damage Numbers"
	dmg_check.button_pressed = SaveManager.get_setting("show_damage_numbers", true)
	dmg_check.toggled.connect(func(p: bool): SaveManager.set_setting("show_damage_numbers", p))
	layout.add_child(dmg_check)
	layout.move_child(dmg_check, close_button.get_index())

func _on_ui_scale(value: float) -> void:
	SaveManager.set_setting("ui_scale", value)
	_apply_ui_scale(value)

func _apply_ui_scale(value: float) -> void:
	var win := get_window()
	if win != null:
		win.content_scale_factor = clampf(value, 0.75, 1.5)

func _on_reduced_vfx(pressed: bool) -> void:
	SaveManager.set_setting("reduced_vfx", pressed)
	if PerformanceManager != null and PerformanceManager.has_method("notify_reduced_vfx"):
		PerformanceManager.notify_reduced_vfx()

func _on_sensitivity(value: float) -> void:
	SaveManager.set_setting("look_sensitivity", value)

func _on_touch_sensitivity(value: float) -> void:
	SaveManager.set_setting("touch_sensitivity", value)

func _on_haptics(pressed: bool) -> void:
	SaveManager.set_setting("haptics", pressed)

func _on_fullscreen(pressed: bool) -> void:
	var is_fs: bool = InputManager.is_fullscreen()
	if pressed != is_fs:
		InputManager.toggle_fullscreen()

func _on_state_changed(_new_state: int, _old: int) -> void:
	pass

func open() -> void:
	visible = true

func _on_volume(value: float, key: String) -> void:
	SaveManager.set_setting(key, value)
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
