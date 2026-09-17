extends Control
## Settings: volume sliders + quality + shake toggle. Persisted via SaveManager.

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

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	quality_option.clear()
	quality_option.add_item("Low")
	quality_option.add_item("Medium")
	quality_option.add_item("High")
	quality_option.add_item("Auto")

	master_slider.value = SaveManager.get_setting("master_volume", 0.8)
	music_slider.value = SaveManager.get_setting("music_volume", 0.7)
	sfx_slider.value = SaveManager.get_setting("sfx_volume", 0.8)
	sensitivity_slider.value = SaveManager.get_setting("look_sensitivity", 1.0)
	touch_sens_slider.value = SaveManager.get_setting("touch_sensitivity", 1.0)
	haptics_check.button_pressed = SaveManager.get_setting("haptics", false)
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	shake_check.button_pressed = SaveManager.get_setting("screen_shake", true)
	var q: int = int(SaveManager.get_setting("quality", 1))
	# 3 = Auto preference; otherwise 0..2 fixed tier
	quality_option.selected = 3 if q == 3 or PerformanceManager.auto_mode else clampi(q, 0, 2)

	master_slider.value_changed.connect(_on_volume.bind("master_volume"))
	music_slider.value_changed.connect(_on_volume.bind("music_volume"))
	sfx_slider.value_changed.connect(_on_volume.bind("sfx_volume"))
	sensitivity_slider.value_changed.connect(_on_sensitivity)
	touch_sens_slider.value_changed.connect(_on_touch_sensitivity)
	haptics_check.toggled.connect(_on_haptics)
	fullscreen_check.toggled.connect(_on_fullscreen)
	shake_check.toggled.connect(_on_shake)
	quality_option.item_selected.connect(_on_quality)
	close_button.pressed.connect(_on_close)
	EventBus.game_state_changed.connect(_on_state_changed)

func _on_sensitivity(value: float) -> void:
	SaveManager.set_setting("look_sensitivity", value)

func _on_touch_sensitivity(value: float) -> void:
	SaveManager.set_setting("touch_sensitivity", value)

func _on_haptics(pressed: bool) -> void:
	SaveManager.set_setting("haptics", pressed)

func _on_fullscreen(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		if OS.get_name() == "Web":
			JavaScriptBridge.eval("if(document.documentElement.requestFullscreen){document.documentElement.requestFullscreen()}", true)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if OS.get_name() == "Web":
			JavaScriptBridge.eval("if(document.exitFullscreen){document.exitFullscreen()}", true)

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
	if index == 3:
		# Auto: persist preference, start from a safe tier (MED on web/touch)
		PerformanceManager.set_auto_mode(true)
		var start_tier: int = PerformanceManager.Quality.MEDIUM
		if OS.get_name() != "Web" and not DisplayServer.is_touchscreen_available() and not OS.has_feature("mobile"):
			start_tier = PerformanceManager.Quality.HIGH
		PerformanceManager.set_quality(start_tier, false)
	else:
		PerformanceManager.set_auto_mode(false)
		PerformanceManager.set_quality(index, true)

func _on_close() -> void:
	visible = false
