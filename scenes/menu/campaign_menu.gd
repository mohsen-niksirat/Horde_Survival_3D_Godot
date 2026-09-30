extends Control
## S1 campaign menu: mission list with briefings and win rules.

const MISSIONS := [
	"res://data/missions/m1_gate.tres",
	"res://data/missions/m2_frost.tres",
	"res://data/missions/m3_warden.tres",
]

@onready var rows: VBoxContainer = $Center/Panel/Layout/Scroll/Rows
@onready var close_button: Button = $Center/Panel/Layout/Close

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(func(): visible = false)

func open() -> void:
	_build()
	visible = true
	AudioManager.play_game_sfx("ui_click")

func _build() -> void:
	for c in rows.get_children():
		c.queue_free()
	var wins: int = int(SaveManager.get_meta_data("victories", 0))
	for path in MISSIONS:
		if not ResourceLoader.exists(path):
			continue
		var m = load(path)
		var unlocked: bool = m.is_unlocked(wins)
		var card := Button.new()
		card.custom_minimum_size = Vector2(520, 92)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if unlocked:
			card.text = "%s\n%s\nObjective: %s  ·  Reward: %d gold" % [
				m.display_name, m.briefing, m.describe_win(), m.gold_reward]
			card.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
			card.pressed.connect(_on_start.bind(m))
		else:
			card.text = "%s\nLOCKED — win %d run(s) to unlock" % [m.display_name, m.unlock_wins]
			card.disabled = true
			card.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
		card.add_theme_font_size_override("font_size", 14)
		rows.add_child(card)

func _on_start(m) -> void:
	RunManager.endless = false
	RunManager.set_mission(m)
	GameManager.start_game()
