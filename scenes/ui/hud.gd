extends Control
## HUD: HP bar, XP bar, level, timer, kills, combo counter, ability buttons.

@onready var hp_bar: ProgressBar = $TopLeft/HPBar
@onready var hp_label: Label = $TopLeft/HPLabel
@onready var xp_bar: ProgressBar = $Top/XPBar
@onready var level_label: Label = $TopLeft/LevelLabel
@onready var timer_label: Label = $Top/TimerLabel
@onready var kills_label: Label = $TopRight/KillsLabel
@onready var fps_label: Label = $TopRight/FpsLabel
@onready var combo_label: Label = $Combo
@onready var ability1_button: Button = $Abilities/AbilityRow/Ability1
@onready var ability2_button: Button = $Abilities/AbilityRow/Ability2
@onready var zoom_in_button: Button = $Abilities/ZoomRow/ZoomIn
@onready var zoom_out_button: Button = $Abilities/ZoomRow/ZoomOut
@onready var pause_button: Button = $PauseButton
@onready var weapon_icons: HBoxContainer = $TopLeft/WeaponIcons
@onready var boss_bar: ProgressBar = $BossBar
@onready var hint_label: Label = $HintLabel

## V14 onboarding: rotating contextual hints during the first 90 seconds.
const HINTS := [
	"Move: WASD / joystick (left side)",
	"Weapons fire automatically - stay close to enemies",
	"Cyan crystals = XP - walk near them",
	"Gold drops from every kill - spend it on UPGRADES",
	"Abilities: Q / E (or touch buttons)",
	"Hearts heal you - grab them!",
	"Pause: II button or Esc / P",
	"Zoom: mouse wheel / + and - buttons",
]

var _hint_time: float = 0.0
var _hint_index: int = 0
var _hints_active: bool = false

var _player: Node
var _ability_controller: Node
var _last_tier: String = ""
var _fps_accum: float = 0.0

const TIER_COLORS := {
	"BRONZE": Color(0.8, 0.65, 0.4),
	"SILVER": Color(0.85, 0.87, 0.9),
	"GOLD": Color(1, 0.85, 0.2),
	"PLATINUM": Color(0.3, 0.9, 1),
	"DIAMOND": Color(0.85, 0.5, 1),
	"GODLIKE": Color(1, 0.25, 0.3),
}

func bind_player(player: Node) -> void:
	_player = player
	EventBus.player_leveled_up.connect(_on_level_up)
	RunManager.kills_changed.connect(_on_kills)
	EventBus.combo_changed.connect(_on_combo)
	EventBus.upgrade_applied.connect(_on_upgrade_applied)
	pause_button.pressed.connect(_on_pause_pressed)
	# Connect once here — not in the visibility handler (that re-ran every state change)
	if not zoom_in_button.pressed.is_connected(_on_zoom_in):
		zoom_in_button.pressed.connect(_on_zoom_in)
	if not zoom_out_button.pressed.is_connected(_on_zoom_out):
		zoom_out_button.pressed.connect(_on_zoom_out)
	_refresh_weapon_icons()
	# V-fix: hide gameplay HUD while paused/level-up so overlays read clean
	EventBus.game_state_changed.connect(_on_hud_visibility)

func _on_zoom_in() -> void:
	InputManager.add_zoom_delta(-0.18)

func _on_zoom_out() -> void:
	InputManager.add_zoom_delta(0.18)

func _on_hud_visibility(new_state: int, _old: int) -> void:
	visible = not (new_state == GameManager.State.PAUSED or new_state == GameManager.State.LEVEL_UP)

func _on_upgrade_applied(_title: String) -> void:
	_refresh_weapon_icons()

## V7: data-driven weapon icons with level pips.
func _refresh_weapon_icons() -> void:
	if _player == null:
		return
	for child in weapon_icons.get_children():
		child.queue_free()
	var wc: Node = _player.weapon_controller
	var colors: Dictionary = wc.WEAPON_FLASH_COLORS
	for w in wc.weapons:
		var icon := Panel.new()
		icon.custom_minimum_size = Vector2(36, 36)
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors.get(w.data.id, Color(0.8, 0.8, 0.8))
		sb.set_corner_radius_all(7)
		sb.border_color = Color(0, 0, 0, 0.4)
		sb.set_border_width_all(2)
		if w.evolved:
			sb.border_color = Color(1.0, 0.84, 0.0)
		icon.add_theme_stylebox_override("panel", sb)
		var lv := Label.new()
		lv.text = str(w.level if not w.evolved else 5)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lv.set_anchors_preset(Control.PRESET_FULL_RECT)
		lv.add_theme_font_size_override("font_size", 16)
		lv.add_theme_color_override("font_color", Color(0, 0, 0, 0.85))
		icon.add_child(lv)
		weapon_icons.add_child(icon)

func _on_pause_pressed() -> void:
	AudioManager.play_game_sfx("ui_click")
	if GameManager.state == GameManager.State.PLAYING or GameManager.state == GameManager.State.BOSS:
		GameManager.pause_game()
	elif GameManager.state == GameManager.State.PAUSED:
		GameManager.resume_game()

func bind_abilities(controller: Node) -> void:
	_ability_controller = controller
	ability1_button.text = "Q Meteor"
	ability2_button.text = "E Freeze"
	# V-fix: touch ability buttons actually execute on mobile
	ability1_button.pressed.connect(func():
		var ac: Node = _ability_controller
		if ac != null and ac.get_cooldown_ratio("meteor_strike") == 0.0:
			ac._execute(ac.abilities[0]["data"])
			ac.abilities[0]["cooldown_left"] = ac.abilities[0]["data"].cooldown)
	ability2_button.pressed.connect(func():
		var ac: Node = _ability_controller
		if ac != null and ac.get_cooldown_ratio("time_freeze") == 0.0:
			ac._execute(ac.abilities[1]["data"])
			ac.abilities[1]["cooldown_left"] = ac.abilities[1]["data"].cooldown)

func _process(delta: float) -> void:
	timer_label.text = RunManager.get_time_string()
	_fps_accum += delta
	if _fps_accum >= 0.25:
		_fps_accum = 0.0
		_update_fps_label()
	if _player == null:
		return
	# V7: bars ease toward their true values (animated feel)
	var hp_target: float = _player.health.current_hp
	hp_bar.max_value = _player.health.max_hp
	hp_bar.value = lerpf(hp_bar.value, hp_target, minf(10.0 * delta, 1.0))
	hp_label.text = "%d / %d" % [int(_player.health.current_hp), int(_player.health.max_hp)]
	xp_bar.max_value = _player.experience.xp_to_next
	xp_bar.value = lerpf(xp_bar.value, _player.experience.current_xp, minf(10.0 * delta, 1.0))
	level_label.text = "Lv %d" % _player.experience.level
	_process_hints(delta)

	# Ability cooldown indicators
	if _ability_controller != null:
		for ab in _ability_controller.abilities:
			var data = ab["data"]
			var ratio: float = _ability_controller.get_cooldown_ratio(data.id)
			var btn := ability1_button if data.id == "meteor_strike" else ability2_button
			btn.modulate = Color(1, 1, 1, 0.4 if ratio > 0.0 else 1.0)

func _update_fps_label() -> void:
	if fps_label == null:
		return
	var fps := Engine.get_frames_per_second()
	var q := ""
	if PerformanceManager != null:
		q = PerformanceManager.quality_name()
		if PerformanceManager.stress_mode:
			q += " STRESS"
	fps_label.text = "FPS %d  %s" % [fps, q]
	if fps >= 50:
		fps_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55, 0.95))
	elif fps >= 30:
		fps_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.45, 0.95))
	else:
		fps_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4, 0.95))

func _on_level_up(_level: int) -> void:
	pass

func _on_kills(kills: int) -> void:
	kills_label.text = "Kills: %d  Gold: %d" % [kills, int(RunManager.gold_earned)]

func _process_hints(delta: float) -> void:
	# Contextual onboarding: only during the first 90 seconds of a run
	if not RunManager.is_running or RunManager.elapsed_time > 90.0:
		if hint_label.visible:
			hint_label.visible = false
			_hints_active = false
		return
	_hints_active = true
	hint_label.visible = true
	_hint_time += delta
	if _hint_time >= 11.0:
		_hint_time = 0.0
		_hint_index = (_hint_index + 1) % HINTS.size()
	hint_label.text = HINTS[_hint_index]
	hint_label.modulate.a = clampf(1.0 - (_hint_time - 9.0) / 2.0, 0.0, 1.0) if _hint_time > 9.0 else 1.0

func _on_combo(count: int, multiplier: float) -> void:
	if count <= 0:
		combo_label.visible = false
		return
	combo_label.visible = true
	var tier: String = _combo_tier(count)
	combo_label.text = "x%d COMBO %s\n(%.1f XP)" % [count, tier, multiplier]
	combo_label.add_theme_color_override("font_color", TIER_COLORS.get(tier, Color.WHITE))
	var size := 15 + mini(count / 10, 6) * 2
	combo_label.add_theme_font_size_override("font_size", size)
	# V7: pop + pulse animation on tier change
	if tier != _last_tier and tier != "BRONZE":
		_last_tier = tier
		combo_label.pivot_offset = combo_label.size * 0.5
		var tween := create_tween()
		combo_label.scale = Vector2(1.25, 1.25)
		tween.tween_property(combo_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif count % 5 == 0:
		combo_label.pivot_offset = combo_label.size * 0.5
		combo_label.scale = Vector2(1.1, 1.1)
		var tw2 := create_tween()
		tw2.tween_property(combo_label, "scale", Vector2.ONE, 0.12)

func _combo_tier(count: int) -> String:
	if count >= 200: return "GODLIKE"
	if count >= 100: return "DIAMOND"
	if count >= 50: return "PLATINUM"
	if count >= 25: return "GOLD"
	if count >= 10: return "SILVER"
	return "BRONZE"
