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
	how_to_play_button.pressed.connect(_on_placeholder_pressed.bind("WASD move · auto-attack · Q/E abilities · cyan shards = XP · chests = relics · survive 15 min to WIN (or Endless)"))
	quit_button.pressed.connect(_on_quit_pressed)
	notice_label.text = ""
	# P9: full achievements panel
	if get_node_or_null("AchievementPanel") == null:
		var ps: PackedScene = load("res://scenes/menu/AchievementPanel.tscn")
		if ps != null:
			var panel := ps.instantiate()
			panel.name = "AchievementPanel"
			add_child(panel)
	# S1: campaign mission list
	if get_node_or_null("CampaignMenu") == null:
		var cps: PackedScene = load("res://scenes/menu/CampaignMenu.tscn")
		if cps != null:
			var cpanel := cps.instantiate()
			cpanel.name = "CampaignMenu"
			add_child(cpanel)
	_build_campaign_button()
	_update_stats()

func _build_campaign_button() -> void:
	if campaign_button != null or play_button == null:
		return
	var layout := play_button.get_parent()
	if layout == null:
		return
	campaign_button = Button.new()
	campaign_button.name = "CampaignButton"
	campaign_button.text = "CAMPAIGN"
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
	stats_label.text = "Gold: %d | Best: %02d:%02d | Wins: %d | Kills: %d | Achievements: %d" % [
		gold, minutes, seconds, victories, total_kills, achievements.size()
	]

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
