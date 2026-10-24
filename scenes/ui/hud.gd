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
@onready var ability1_button: Button = $AbilityPanel/AbilityCol/Ability1
@onready var ability2_button: Button = $AbilityPanel/AbilityCol/Ability2
@onready var zoom_in_button: Button = $Abilities/ZoomCol/ZoomIn
@onready var zoom_out_button: Button = $Abilities/ZoomCol/ZoomOut
@onready var fullscreen_button: Button = $Abilities/Fullscreen
@onready var pause_button: Button = $PauseButton
@onready var dash_button: Button = $AbilityPanel/AbilityCol/DashButton
@onready var weapon_icons: HBoxContainer = $TopLeft/WeaponIcons
@onready var boss_bar: ProgressBar = $BossBar
@onready var hint_label: Label = $HintLabel
var _objective_label: Label

## V14 onboarding: rotating contextual hints during the first 90 seconds.
## Keys into the locale catalogue (locale/<locale>.csv).
const HINT_KEYS := [
	"HINT_MOVE",
	"HINT_AUTO_ATTACK",
	"HINT_XP",
	"HINT_GOLD",
	"HINT_ABILITIES",
	"HINT_HEARTS",
	"HINT_RELICS",
	"HINT_WIN",
	"HINT_PAUSE",
	"HINT_ZOOM",
]
## English fallback used when a key is missing from the catalogue.
const HINTS := [
	"Move: WASD / joystick (left side)",
	"Weapons fire automatically - stay close to enemies",
	"Cyan crystals = XP - walk near them",
	"Gold drops from every kill - spend it on UPGRADES",
	"Abilities: Q / E abilities · F to dash (short invincibility)",
	"Hearts heal you - grab them!",
	"Glowing chests give relics - walk over them",
	"Survive 15 minutes to WIN",
	"Pause: II button or Esc / P",
	"Zoom: mouse wheel / + and - buttons",
]

var _hint_time: float = 0.0
var _hint_index: int = 0
var _hints_active: bool = false
var _toast_left: float = 0.0

var _player: Node
var _ability_controller: Node
var _last_tier: String = ""
var _combo_tween: Tween = null
var _fps_accum: float = 0.0
## V20A: boss bar check cadence — the group lookup + phase-tint stylebox
## churn run at 5 Hz instead of every frame.
const BOSS_BAR_CHECK_INTERVAL := 0.2
var boss_check_accum: float = 0.0

## V30A: HUD text was reshaped 8+ times per rendered frame (timer twice,
## kills, HP, level, ability buttons, dash, hints) and theme overrides force a
## full re-style. Text only needs ~10 Hz, and only when the value changed.
const UI_REFRESH_INTERVAL := 0.1
var _ui_accum: float = 0.0
var _last_timer_text: String = ""
var _last_kills_text: String = ""
var _last_hp_text: String = ""
var _last_level_text: String = ""
var _last_timer_warning: int = -1
var _last_ability_text: Array = ["", ""]
var _ability_ready_state: Array = [-1, -1]
var _last_dash_text: String = ""
var _dash_ready_state: int = -1
var _hint_shown: bool = false

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
	_refresh_weapon_icons()
	EventBus.player_leveled_up.connect(_on_level_up)
	EventBus.combo_changed.connect(_on_combo)
	EventBus.upgrade_applied.connect(_on_upgrade_applied)
	EventBus.run_ended.connect(_on_run_ended_toast)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	EventBus.boss_spawned.connect(_on_boss_banner)
	EventBus.boss_phase_changed.connect(_on_boss_phase_banner)

func _on_boss_banner(_boss: Node) -> void:
	_show_toast("THE WARDEN AWAKENS")
	AudioManager.play_game_sfx("boss_warn")

func _on_boss_phase_banner(phase_name: String, _color: Color) -> void:
	if phase_name == "VICTORY":
		return
	_show_toast("BOSS %s" % phase_name)

func _on_achievement_unlocked(_id: String, title: String, gold: int) -> void:
	_show_toast("ACHIEVEMENT: %s (+%d gold)" % [title, gold])
	AudioManager.play_game_sfx("level_up")

func _ready() -> void:
	# Android notch / punch-hole: keep every HUD element inside the display
	# safe area. The HUD root is full-rect, so insetting it shifts every
	# child inward in one move.
	get_viewport().size_changed.connect(_apply_safe_area)
	call_deferred("_apply_safe_area")
	# HUD buttons must never take keyboard focus — Space/Enter on a focused
	# button re-triggers its action mid-gameplay (and Space conflicts with
	# browser fullscreen on some setups).
	for btn in [pause_button, fullscreen_button, zoom_in_button, zoom_out_button, ability1_button, ability2_button, dash_button]:
		if btn != null:
			btn.focus_mode = Control.FOCUS_NONE
	pause_button.pressed.connect(_on_pause_pressed)
	# Connect once here — not in the visibility handler (that re-ran every state change)
	if not zoom_in_button.pressed.is_connected(_on_zoom_in):
		zoom_in_button.pressed.connect(_on_zoom_in)
	if not zoom_out_button.pressed.is_connected(_on_zoom_out):
		zoom_out_button.pressed.connect(_on_zoom_out)
	if fullscreen_button != null and not fullscreen_button.pressed.is_connected(_on_fullscreen_pressed):
		fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	_refresh_weapon_icons()
	# V-fix: hide gameplay HUD while paused/level-up so overlays read clean
	EventBus.game_state_changed.connect(_on_hud_visibility)
	EventBus.run_started.connect(_on_run_started_briefing)
	_build_objective_label()

func _on_run_started_briefing() -> void:
	var m = RunManager.mission
	if m != null:
		_show_toast("%s — %s" % [m.display_name, m.briefing])

func _on_zoom_in() -> void:
	InputManager.add_zoom_delta(-0.18)

func _on_zoom_out() -> void:
	InputManager.add_zoom_delta(0.18)

func _on_fullscreen_pressed() -> void:
	AudioManager.play_game_sfx("ui_click")
	InputManager.toggle_fullscreen()
	if fullscreen_button != null:
		fullscreen_button.text = "Win" if InputManager.is_fullscreen() else "FS"
		# Release focus — a focused button re-fires on Space/Enter which would
		# bounce the player out of fullscreen mid-gameplay.
		fullscreen_button.release_focus()

func _on_hud_visibility(new_state: int, _old: int) -> void:
	visible = not (new_state == GameManager.State.PAUSED or new_state == GameManager.State.LEVEL_UP)

func _on_upgrade_applied(title: String) -> void:
	_refresh_weapon_icons()
	# Playtest: relic/chest pickups must show what you got
	_show_toast(title)

func _on_run_ended_toast(victory: bool) -> void:
	if victory:
		_show_toast("VICTORY! +250 gold")
	else:
		_show_toast("You fell to the horde...")

func _show_toast(text: String) -> void:
	if hint_label == null:
		return
	hint_label.text = text
	hint_label.visible = true
	hint_label.modulate.a = 1.0
	_toast_left = 3.5
	_hints_active = false
	_hint_shown = false

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

## Inset the HUD root to the display safe area (Android notch / punch-hole).
## Idempotent: the HUD root is full-rect, so its children move inward with it.
func _apply_safe_area() -> void:
	if not is_inside_tree():
		return
	var pads: Vector4 = SafeArea.insets_for(self)
	offset_left = pads.x
	offset_top = pads.y
	offset_right = -pads.z
	offset_bottom = -pads.w

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
	ability1_button.pressed.connect(func(): ability1_button.release_focus(); _trigger_ability("meteor_strike"))
	ability2_button.pressed.connect(func(): ability2_button.release_focus(); _trigger_ability("time_freeze"))
	# V16A: dash button mirrors the F-key dash (touch parity)
	dash_button.text = "F Dash"
	dash_button.button_down.connect(func(): InputManager.set_touch_action("dash", true))
	dash_button.button_up.connect(func(): InputManager.set_touch_action("dash", false))
	dash_button.pressed.connect(_on_dash_pressed)

func _on_dash_pressed() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if dash_button != null:
		dash_button.release_focus()
	AudioManager.play_game_sfx("ui_click")
	# Direction: current camera-relative move input, else the facing direction.
	var input_vec: Vector2 = InputManager.get_move_vector()
	var basis: Basis = _player.camera_rig.get_move_basis()
	var dir := basis * Vector3(input_vec.x, 0, input_vec.y)
	if Vector2(dir.x, dir.z).length_squared() < 0.0001:
		dir = Vector3(-sin(_player.rotation.y), 0.0, -cos(_player.rotation.y))
	_player.dash.try_dash(dir)

func _trigger_ability(id: String) -> void:
	if id == "dash":
		_on_dash_pressed()
		return
	var ac: Node = _ability_controller
	if ac == null or ac.get_cooldown_ratio(id) != 0.0:
		return
	for entry in ac.abilities:
		if entry["data"].id == id:
			entry["cooldown_left"] = entry["data"].cooldown
			if not ac._execute(entry["data"]):
				entry["cooldown_left"] = 0.0
			return

func _build_objective_label() -> void:
	_objective_label = Label.new()
	_objective_label.name = "ObjectiveLabel"
	_objective_label.add_theme_font_size_override("font_size", 16)
	_objective_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_objective_label.offset_top = 96.0
	_objective_label.visible = false
	add_child(_objective_label)

const OBJECTIVE_UPDATE_INTERVAL := 0.25
## V20A: the objective label rebuilds a multi-branch string every frame;
## mission objectives change at second granularity — 4 Hz is plenty.
var _objective_accum: float = 0.0

func _process_objective(delta: float) -> void:
	if _objective_label == null:
		return
	_objective_accum -= delta
	if _objective_accum > 0.0:
		return
	_objective_accum = OBJECTIVE_UPDATE_INTERVAL
	var m = RunManager.mission
	if m == null or not RunManager.is_running:
		_objective_label.visible = false
		return
	_objective_label.visible = true
	var obj_text := ""
	match m.win_rule:
		"survive_time":
			var left: float = maxf(float(m.win_target) - RunManager.elapsed_time, 0.0)
			obj_text = "%s — survive %d:%02d" % [m.display_name, int(left) / 60, int(left) % 60]
		"kill_count":
			obj_text = "%s — %d / %d kills" % [m.display_name, RunManager.kills, int(m.win_target)]
		"kill_boss":
			var target_name: String = "the Heartforge Core" if m.id == "m5_heartforge" else "the Warden"
			obj_text = "%s — defeat %s" % [m.display_name, target_name]

	var side_type: String = str(m.get("side_objective_type"))
	var side_target: int = int(m.get("side_objective_target"))
	if side_type != "" and side_target > 0:
		var side_done: bool = bool(RunManager.side_objective_completed)
		var tag := " [DONE]" if side_done else ""
		match side_type:
			"kill_elites":
				obj_text += "  ·  Bonus: %d/%d Elites%s" % [mini(RunManager.elites_killed, side_target), side_target, tag]
			"combo_streak":
				obj_text += "  ·  Bonus: %d/%d Combo%s" % [mini(RunManager.max_combo_reached, side_target), side_target, tag]
	_objective_label.text = obj_text

func _process(delta: float) -> void:
	# Cheap per-frame work: fading hints, throttled objective/boss reads.
	_process_objective(delta)
	_process_hints(delta)
	_process_boss_bar()

	_fps_accum += delta
	if _fps_accum >= 0.5:
		_fps_accum = 0.0
		_update_fps_label()

	if _player == null:
		return
	_process_bars(delta)

	_ui_accum += delta
	if _ui_accum < UI_REFRESH_INTERVAL:
		return
	_ui_accum = 0.0
	_refresh_run_labels()
	_refresh_ability_buttons()
	_refresh_dash_button()

## Bars animate every frame (single-quad redraws are cheap), but skip writes
## when the eased value has already visually converged.
func _process_bars(delta: float) -> void:
	var max_hp: float = _player.health.max_hp
	if not is_equal_approx(hp_bar.max_value, max_hp):
		hp_bar.max_value = max_hp
	var hp_target: float = _player.health.current_hp
	var hp_next := lerpf(hp_bar.value, hp_target, minf(10.0 * delta, 1.0))
	if absf(hp_next - hp_bar.value) > 0.02:
		hp_bar.value = hp_next

	var xp_max: float = _player.experience.xp_to_next
	if not is_equal_approx(xp_bar.max_value, xp_max):
		xp_bar.max_value = xp_max
	var xp_next := lerpf(xp_bar.value, _player.experience.current_xp, minf(10.0 * delta, 1.0))
	if absf(xp_next - xp_bar.value) > 0.02:
		xp_bar.value = xp_next

## 10 Hz text refresh; every label only re-shapes when its string changed.
func _refresh_run_labels() -> void:
	var timer_text := RunManager.get_time_string()
	var warn := 0
	var mission = RunManager.mission
	var timed_win: bool = mission == null or mission.win_rule == "survive_time"
	if not RunManager.endless and RunManager.is_running and timed_win:
		var left: float = maxf(RunManager.target_duration - RunManager.elapsed_time, 0.0)
		timer_text = "%s  (win %d:%02d)" % [timer_text, int(left) / 60, int(left) % 60]
		if left < 60.0:
			warn = 1
	if timer_text != _last_timer_text:
		_last_timer_text = timer_text
		timer_label.text = timer_text
	if warn != _last_timer_warning:
		_last_timer_warning = warn
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if warn == 1 else Color.WHITE)
	# R18: run phase label under timer pressure
	if RunManager.is_running:
		var mins := RunManager.elapsed_time / 60.0
		var phase := "EARLY"
		if mins >= 13.0:
			phase = "FINALE"
		elif mins >= 10.0:
			phase = "LATE"
		elif mins >= 5.0:
			phase = "MID"
		# Gold lives here too — kills_changed used to write a competing
		# "Kills/Gold" format that the 10 Hz refresh overwrote instantly,
		# so gold was never readable during a run.
		var kills_text := "%d kills  ·  %d gold  ·  %s" % [RunManager.kills, int(RunManager.gold_earned), phase]
		if kills_text != _last_kills_text:
			_last_kills_text = kills_text
			kills_label.text = kills_text
	if _player == null:
		return
	var hp_text := "%d / %d" % [int(_player.health.current_hp), int(_player.health.max_hp)]
	if hp_text != _last_hp_text:
		_last_hp_text = hp_text
		hp_label.text = hp_text
	var lv_text := "Lv %d" % _player.experience.level
	if lv_text != _last_level_text:
		_last_level_text = lv_text
		level_label.text = lv_text

## Ability cooldowns: only restyle when ready→cooling (or back), and only
## rewrite the countdown when the rounded value changes.
func _refresh_ability_buttons() -> void:
	if _ability_controller == null:
		return
	for ab in _ability_controller.abilities:
		var data = ab["data"]
		var is_meteor: bool = data.id == "meteor_strike"
		var btn: Button = ability1_button if is_meteor else ability2_button
		var idx: int = 0 if is_meteor else 1
		var ratio: float = _ability_controller.get_cooldown_ratio(data.id)
		var ready_state: int = 0 if ratio > 0.0 else 1
		if ready_state != _ability_ready_state[idx]:
			_ability_ready_state[idx] = ready_state
			if ready_state == 1:
				btn.modulate = Color(0.75, 1.0, 0.75, 1.0)
				btn.add_theme_color_override("font_color", Color(0.05, 0.25, 0.08))
			else:
				btn.modulate = Color(1, 1, 1, 0.4)
				btn.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		var base := "Q Meteor" if is_meteor else "E Freeze"
		var text := base
		if ratio > 0.0:
			text = "%s %.0f" % [base, ceil(float(ab.get("cooldown_left", 0.0)))]
		if text != _last_ability_text[idx]:
			_last_ability_text[idx] = text
			btn.text = text

## Dash cooldown indicator (F key / touch button). Restores "F Dash" when ready.
func _refresh_dash_button() -> void:
	if dash_button == null or _player == null or not is_instance_valid(_player):
		return
	var dr: float = _player.dash.get_cooldown_ratio()
	var ready_state: int = 0 if dr > 0.0 else 1
	if ready_state != _dash_ready_state:
		_dash_ready_state = ready_state
		if ready_state == 1:
			dash_button.modulate = Color(0.75, 1.0, 0.75, 1.0)
			dash_button.add_theme_color_override("font_color", Color(0.05, 0.25, 0.08))
		else:
			dash_button.modulate = Color(1, 1, 1, 0.4)
			dash_button.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	var text: String = "F Dash" if dr <= 0.0 else "%.1f" % _player.dash.cooldown_left
	if text != _last_dash_text:
		_last_dash_text = text
		dash_button.text = text

func _process_boss_bar() -> void:
	if boss_bar == null:
		return
	# V20A: the group lookup + stylebox churn every frame is wasted work —
	# bar state changes at second granularity. Throttle the whole check to
	# 5 Hz (HP still reads smooth; a spawning boss shows within 0.2 s).
	boss_check_accum -= get_process_delta_time()
	if boss_check_accum > 0.0:
		return
	boss_check_accum = BOSS_BAR_CHECK_INTERVAL
	var boss := get_tree().get_first_node_in_group("boss") if get_tree() != null else null
	if boss == null or not is_instance_valid(boss) or not boss.is_enemy_alive():
		boss_bar.visible = false
		return
	boss_bar.visible = true
	boss_bar.max_value = boss.health.max_hp
	boss_bar.value = boss.health.current_hp
	boss_bar.tooltip_text = "THE WARDEN"
	# R3: bar tint tracks fight phase
	var ratio: float = boss.health.get_ratio()
	var fill := boss_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill == null:
		fill = StyleBoxFlat.new()
		fill.bg_color = Color(0.85, 0.2, 0.15)
		boss_bar.add_theme_stylebox_override("fill", fill)
	if ratio < 0.3:
		fill.bg_color = Color(1.0, 0.15, 0.08)
	elif ratio < 0.6:
		fill.bg_color = Color(1.0, 0.45, 0.12)
	else:
		fill.bg_color = Color(0.9, 0.25, 0.2)

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

func _process_hints(delta: float) -> void:
	# Toast (relic pickup, synergy) always wins over onboarding hints
	if _toast_left > 0.0:
		_toast_left -= delta
		if not hint_label.visible:
			hint_label.visible = true
		hint_label.modulate.a = clampf(_toast_left / 0.6, 0.0, 1.0)
		_hint_shown = false
		return
	# Contextual onboarding: only during the first 90 seconds of a run
	if not RunManager.is_running or RunManager.elapsed_time > 90.0:
		if hint_label.visible and _toast_left <= 0.0:
			hint_label.visible = false
			_hints_active = false
			_hint_shown = false
		return
	_hints_active = true
	if not hint_label.visible:
		hint_label.visible = true
	_hint_time += delta
	if _hint_time >= 11.0:
		_hint_time = 0.0
		_hint_index = (_hint_index + 1) % HINT_KEYS.size()
		_hint_shown = false
	# V30A: text shaping was happening every frame; only rewrite on change.
	if not _hint_shown:
		hint_label.text = _hint_text(_hint_index)
		_hint_shown = true
	hint_label.modulate.a = clampf(1.0 - (_hint_time - 9.0) / 2.0, 0.0, 1.0) if _hint_time > 9.0 else 1.0

## Localized hint text, falling back to the English string when the key is
## not in the catalogue.
func _hint_text(index: int) -> String:
	if index < 0 or index >= HINT_KEYS.size():
		return ""
	var key: String = HINT_KEYS[index]
	var text := tr(key)
	if text == key:
		return HINTS[index] if index < HINTS.size() else key
	return text

func _on_combo(count: int, multiplier: float) -> void:
	if count <= 0:
		combo_label.visible = false
		_last_tier = ""
		return
	combo_label.visible = true
	var tier: String = _combo_tier(count)
	combo_label.text = "x%d COMBO %s\n(%.1f XP)" % [count, tier, multiplier]
	combo_label.add_theme_color_override("font_color", TIER_COLORS.get(tier, Color.WHITE))
	var size := 15 + mini(count / 10, 6) * 2
	combo_label.add_theme_font_size_override("font_size", size)
	# V7: pop + pulse animation on tier change.
	# Kill any in-flight pop so tweens never stack (which caused scale to
	# undershoot below 1.0 mid-animation and produced a flaky test).
	if _combo_tween != null and _combo_tween.is_valid():
		_combo_tween.kill()
	if tier != _last_tier and tier != "BRONZE":
		_last_tier = tier
		combo_label.pivot_offset = combo_label.size * 0.5
		combo_label.scale = Vector2(1.25, 1.25)
		_combo_tween = create_tween()
		# Monotonic ease-out: pops from 1.25 back to 1.0 without dipping below it.
		_combo_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif count % 5 == 0:
		combo_label.pivot_offset = combo_label.size * 0.5
		combo_label.scale = Vector2(1.1, 1.1)
		_combo_tween = create_tween()
		_combo_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _combo_tier(count: int) -> String:
	if count >= 200: return "GODLIKE"
	if count >= 100: return "DIAMOND"
	if count >= 50: return "PLATINUM"
	if count >= 25: return "GOLD"
	if count >= 10: return "SILVER"
	return "BRONZE"
