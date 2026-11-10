extends Control
## Main menu: Play, Campaign, Characters, Weapons, Achievements, Settings, How to Play.

@onready var play_button: Button = $Center/Layout/PlayButton
@onready var characters_button: Button = $Center/Layout/CharactersButton
@onready var weapons_button: Button = $Center/Layout/WeaponsButton
@onready var achievements_button: Button = $Center/Layout/AchievementsButton
@onready var settings_button: Button = $Center/Layout/SettingsButton
@onready var upgrades_button: Button = $Center/Layout/UpgradesButton
@onready var endless_check: CheckBox = $Center/Layout/EndlessCheck
@onready var how_to_play_button: Button = $Center/Layout/HowToPlayButton
@onready var quit_button: Button = $Center/Layout/QuitButton
@onready var notice_label: Label = $Notice
@onready var stats_label: Label = $Stats

var campaign_button: Button

func _ready() -> void:
	InputManager.release_pointer()
	play_button.pressed.connect(_on_play_pressed)
	characters_button.pressed.connect(_on_characters_pressed)
	weapons_button.pressed.connect(_on_weapons_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	upgrades_button.pressed.connect(_on_upgrades_pressed)
	how_to_play_button.pressed.connect(_on_placeholder_pressed.bind(tr("MENU_HOW_TO_PLAY_TEXT")))
	quit_button.pressed.connect(_on_quit_pressed)
	if OS.get_name() == "Web":
		quit_button.visible = false
	notice_label.text = ""
	_apply_locale()
	# P9: full achievements panel — V20A: instantiate deferred one frame so
	# the menu's first frame (and the Play button) appear without the panel
	# build cost stalling the startup path.
	if get_node_or_null("AchievementPanel") == null:
		_instantiate_panel.call_deferred()
	# S1: campaign mission list (same deferred treatment)
	if get_node_or_null("CampaignMenu") == null:
		_instantiate_campaign.call_deferred()
	_build_campaign_button()
	_style_menu_buttons()
	_update_stats()
	# Android back button on the main menu: ask before quitting.
	EventBus.exit_confirm_requested.connect(_on_exit_confirm_requested)
	_build_exit_confirm()
	# The campaign button is created after _ready's first pass, so the locale
	# is applied once more to pick it up.
	call_deferred("_apply_locale")
	EventBus.settings_changed.connect(_on_settings_changed)

func _on_settings_changed() -> void:
	if is_inside_tree():
		_apply_locale()

## Safe translation helper ensuring raw keys are never shown to the user
func _tr_safe(key: String, fallback: String) -> String:
	var res := tr(key)
	if res == key or res.is_empty():
		return fallback
	return res

## Apply the active locale to the menu labels. Called on ready and whenever
## the player switches the language in Settings.
func _apply_locale() -> void:
	play_button.text = _tr_safe("MENU_PLAY", "⚔️ PLAY")
	characters_button.text = _tr_safe("MENU_CHARACTERS", "🧙 CHARACTERS")
	weapons_button.text = _tr_safe("MENU_WEAPONS", "🗡️ WEAPONS")
	achievements_button.text = _tr_safe("MENU_ACHIEVEMENTS", "🏆 ACHIEVEMENTS")
	settings_button.text = _tr_safe("MENU_SETTINGS", "⚙️ SETTINGS")
	upgrades_button.text = _tr_safe("MENU_UPGRADES", "⭐ UPGRADES")
	how_to_play_button.text = _tr_safe("MENU_HOW_TO_PLAY", "❓ HOW TO PLAY")
	quit_button.text = _tr_safe("MENU_QUIT", "🚪 QUIT")
	endless_check.text = _tr_safe("MENU_ENDLESS", "♾️ Endless Mode (survive past 15:00)")
	if campaign_button != null:
		campaign_button.text = _tr_safe("MENU_CAMPAIGN", "📜 CAMPAIGN")
	# Right-to-left locales mirror the layout so the panel reads naturally.
	layout_direction = Control.LAYOUT_DIRECTION_RTL if Localization.is_rtl() else Control.LAYOUT_DIRECTION_LTR

## Apply custom stylish roguelite themes to all menu buttons
func _style_menu_buttons() -> void:
	# Gold Call-to-Action for PlayButton
	var play_norm := StyleBoxFlat.new()
	play_norm.bg_color = Color(1.0, 0.82, 0.15, 1.0)
	play_norm.corner_radius_top_left = 12
	play_norm.corner_radius_top_right = 12
	play_norm.corner_radius_bottom_left = 12
	play_norm.corner_radius_bottom_right = 12
	play_norm.border_width_left = 2
	play_norm.border_width_top = 2
	play_norm.border_width_right = 2
	play_norm.border_width_bottom = 2
	play_norm.border_color = Color(1.0, 0.95, 0.6, 0.9)
	play_norm.shadow_color = Color(1.0, 0.8, 0.0, 0.35)
	play_norm.shadow_size = 8

	var play_hov := play_norm.duplicate() as StyleBoxFlat
	play_hov.bg_color = Color(1.0, 0.88, 0.28, 1.0)
	play_hov.border_color = Color(1.0, 1.0, 0.8, 1.0)
	play_hov.shadow_size = 14

	var play_press := play_norm.duplicate() as StyleBoxFlat
	play_press.bg_color = Color(0.88, 0.7, 0.1, 1.0)

	play_button.add_theme_stylebox_override("normal", play_norm)
	play_button.add_theme_stylebox_override("hover", play_hov)
	play_button.add_theme_stylebox_override("pressed", play_press)
	play_button.add_theme_color_override("font_color", Color(0.08, 0.09, 0.13, 1.0))
	play_button.add_theme_color_override("font_hover_color", Color(0.04, 0.05, 0.08, 1.0))
	play_button.add_theme_font_size_override("font_size", 24)

	# Sleek dark slate glass theme for secondary buttons
	var sec_norm := StyleBoxFlat.new()
	sec_norm.bg_color = Color(0.12, 0.15, 0.22, 0.85)
	sec_norm.corner_radius_top_left = 10
	sec_norm.corner_radius_top_right = 10
	sec_norm.corner_radius_bottom_left = 10
	sec_norm.corner_radius_bottom_right = 10
	sec_norm.border_width_left = 1
	sec_norm.border_width_top = 1
	sec_norm.border_width_right = 1
	sec_norm.border_width_bottom = 1
	sec_norm.border_color = Color(0.28, 0.38, 0.55, 0.7)

	var sec_hov := sec_norm.duplicate() as StyleBoxFlat
	sec_hov.bg_color = Color(0.18, 0.24, 0.36, 0.95)
	sec_hov.border_color = Color(0.45, 0.75, 1.0, 0.95)
	sec_hov.shadow_color = Color(0.3, 0.6, 1.0, 0.25)
	sec_hov.shadow_size = 6

	var sec_press := sec_norm.duplicate() as StyleBoxFlat
	sec_press.bg_color = Color(0.09, 0.12, 0.18, 0.95)

	var secondary_buttons: Array = [
		characters_button, weapons_button, achievements_button,
		settings_button, upgrades_button, how_to_play_button, quit_button
	]
	if campaign_button != null:
		secondary_buttons.append(campaign_button)

	for b in secondary_buttons:
		if b is Button:
			b.add_theme_stylebox_override("normal", sec_norm)
			b.add_theme_stylebox_override("hover", sec_hov)
			b.add_theme_stylebox_override("pressed", sec_press)
			b.add_theme_color_override("font_color", Color(0.9, 0.93, 0.98, 1.0))
			b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
			b.add_theme_font_size_override("font_size", 17)
			if not b.mouse_entered.is_connected(_on_btn_hover):
				b.mouse_entered.connect(_on_btn_hover)

	if not play_button.mouse_entered.is_connected(_on_btn_hover):
		play_button.mouse_entered.connect(_on_btn_hover)

func _on_btn_hover() -> void:
	AudioManager.play_game_sfx("ui_hover")

func _instantiate_panel() -> void:
	if not is_inside_tree() or get_node_or_null("AchievementPanel") != null:
		return
	var ps: PackedScene = load("res://scenes/menu/AchievementPanel.tscn")
	if ps != null:
		var panel := ps.instantiate()
		panel.name = "AchievementPanel"
		add_child(panel)

func _instantiate_campaign() -> void:
	if not is_inside_tree() or get_node_or_null("CampaignMenu") != null:
		return
	var cps: PackedScene = load("res://scenes/menu/CampaignMenu.tscn")
	if cps != null:
		var cpanel := cps.instantiate()
		cpanel.name = "CampaignMenu"
		add_child(cpanel)

func _build_campaign_button() -> void:
	if campaign_button != null or play_button == null:
		return
	var layout := play_button.get_parent()
	if layout == null:
		return
	campaign_button = Button.new()
	campaign_button.name = "CampaignButton"
	campaign_button.text = _tr_safe("MENU_CAMPAIGN", "📜 CAMPAIGN")
	campaign_button.custom_minimum_size = play_button.custom_minimum_size
	campaign_button.add_theme_font_size_override("font_size", 18)
	campaign_button.pressed.connect(_on_campaign_pressed)
	layout.add_child(campaign_button)
	layout.move_child(campaign_button, play_button.get_index() + 1)
	_style_menu_buttons()

func _on_campaign_pressed() -> void:
	AudioManager.play_game_sfx("ui_click")
	var camp := get_node_or_null("CampaignMenu")
	if camp != null:
		camp.open()

func _on_play_pressed() -> void:
	AudioManager.play_game_sfx("ui_click")
	play_button.disabled = true
	RunManager.mission = null
	RunManager.endless = endless_check.button_pressed
	GameManager.start_game()

func _update_stats() -> void:
	var gold: int = SaveManager.get_meta_data("gold", 0)
	var best_time: float = SaveManager.get_meta_data("best_time", 0.0)
	var total_kills: int = SaveManager.get_meta_data("total_kills", 0)
	var achievements: Dictionary = SaveManager.get_meta_data("achievements", {})
	var victories: int = SaveManager.get_meta_data("victories", 0)
	var minutes := int(best_time) / 60
	var seconds := int(best_time) % 60
	stats_label.text = "Gold: %d | Best: %02d:%02d | Wins: %d | Kills: %d | Achievements: %d\nRuns: %d | Missions: %d/8 | Endless best: %d min | Best combo: %d | Best level: %d" % [
		gold, minutes, seconds, victories, total_kills, achievements.size(),
		int(SaveManager.get_meta_data("total_runs", 0)),
		SaveManager.get_meta_data("completed_missions", []).size(),
		int(SaveManager.get_meta_data("endless_best_minutes", 0)),
		int(SaveManager.get_meta_data("best_combo", 0)),
		int(SaveManager.get_meta_data("best_level", 0)),
	]
	# V29A: opt-in local analytics summary (only shown while it is enabled).
	if Analytics != null and Analytics.enabled:
		stats_label.text += "\n" + Analytics.summary()

func _on_characters_pressed() -> void:
	AudioManager.play_game_sfx("ui_click")
	$CharacterSelect.open()

func _on_weapons_pressed() -> void:
	AudioManager.play_game_sfx("ui_click")
	$WeaponCodex.open()

func _on_upgrades_pressed() -> void:
	AudioManager.play_game_sfx("ui_click")
	$MetaShop.open()

func _on_achievements_pressed() -> void:
	AudioManager.play_game_sfx("ui_click")
	var panel := get_node_or_null("AchievementPanel")
	if panel != null and panel.has_method("open"):
		panel.open()
		return
	var achievements: Dictionary = SaveManager.get_meta_data("achievements", {})
	notice_label.text = "Unlocked achievements: %s" % (", ".join(achievements.keys()) if achievements.size() > 0 else "none yet")

func _on_settings_pressed() -> void:
	AudioManager.play_game_sfx("ui_click")
	$SettingsMenu.open()

func _on_placeholder_pressed(message: String) -> void:
	AudioManager.play_game_sfx("ui_click")
	notice_label.text = message

func _on_quit_pressed() -> void:
	if OS.get_name() == "Web":
		return
	get_tree().quit()

## Android back button on the main menu. Close the topmost open panel
## (character select, weapon codex, campaign list, achievements, settings);
## return false when nothing is open so the caller can offer to quit.
func handle_back_request() -> bool:
	var panels := [
		$CharacterSelect, $WeaponCodex, $MetaShop, $SettingsMenu,
		get_node_or_null("AchievementPanel"), get_node_or_null("CampaignMenu"),
	]
	for panel in panels:
		if panel is Control and (panel as Control).visible:
			(panel as Control).visible = false
			AudioManager.play_game_sfx("ui_click")
			return true
	return false

## Build the exit confirmation once, lazily. Kept out of the scene file so
## the menu's first frame stays cheap.
func _build_exit_confirm() -> void:
	if get_node_or_null("ExitConfirm") != null:
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "ExitConfirm"
	dialog.title = "Quit game?"
	dialog.dialog_text = "Your progress is saved. Quit anyway?"
	dialog.ok_button_text = "Quit"
	dialog.cancel_button_text = "Stay"
	dialog.confirmed.connect(_on_exit_confirmed)
	add_child(dialog)

## Android back button on the main menu — confirm before leaving the app.
func _on_exit_confirm_requested() -> void:
	var dialog := get_node_or_null("ExitConfirm")
	if dialog == null:
		_build_exit_confirm()
		dialog = get_node_or_null("ExitConfirm")
	if dialog is ConfirmationDialog:
		(dialog as ConfirmationDialog).popup_centered()
		return
	# No dialog available (headless): exit directly.
	_on_exit_confirmed()

func _on_exit_confirmed() -> void:
	# Web builds cannot close the tab from script; Android/native can.
	if OS.get_name() == "Web":
		return
	get_tree().quit()
