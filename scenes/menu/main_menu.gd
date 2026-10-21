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
	play_button.pressed.connect(_on_play_pressed)
	characters_button.pressed.connect(_on_characters_pressed)
	weapons_button.pressed.connect(_on_weapons_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	upgrades_button.pressed.connect(_on_upgrades_pressed)
	how_to_play_button.pressed.connect(_on_placeholder_pressed.bind(tr("MENU_HOW_TO_PLAY_TEXT")))
	quit_button.pressed.connect(_on_quit_pressed)
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

## Apply the active locale to the menu labels. Called on ready and whenever
## the player switches the language in Settings.
func _apply_locale() -> void:
	play_button.text = tr("MENU_PLAY")
	characters_button.text = tr("MENU_CHARACTERS")
	weapons_button.text = tr("MENU_WEAPONS")
	achievements_button.text = tr("MENU_ACHIEVEMENTS")
	settings_button.text = tr("MENU_SETTINGS")
	upgrades_button.text = tr("MENU_UPGRADES")
	how_to_play_button.text = tr("MENU_HOW_TO_PLAY")
	quit_button.text = tr("MENU_QUIT")
	endless_check.text = tr("MENU_ENDLESS")
	if campaign_button != null:
		campaign_button.text = tr("MENU_CAMPAIGN")
	# Right-to-left locales mirror the layout so the panel reads naturally.
	layout_direction = Control.LAYOUT_DIRECTION_RTL if Localization.is_rtl() else Control.LAYOUT_DIRECTION_LTR

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
	campaign_button.text = tr("MENU_CAMPAIGN")
	campaign_button.custom_minimum_size = play_button.custom_minimum_size
	campaign_button.add_theme_font_size_override("font_size", 18)
	campaign_button.pressed.connect(_on_campaign_pressed)
	layout.add_child(campaign_button)
	layout.move_child(campaign_button, play_button.get_index() + 1)

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
