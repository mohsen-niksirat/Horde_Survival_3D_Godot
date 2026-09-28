extends Control
## P9: achievements catalog — all milestones with unlock state and gold rewards.

const DEFS := [
	{"id": "kill_1", "title": "First Blood", "desc": "Get your first kill", "gold": 50},
	{"id": "kill_100", "title": "Centurion", "desc": "100 total kills", "gold": 100},
	{"id": "kill_1000", "title": "Exterminator", "desc": "1000 total kills", "gold": 300},
	{"id": "survive_5min", "title": "Survivor I", "desc": "Survive 5 minutes", "gold": 100},
	{"id": "survive_10min", "title": "Survivor II", "desc": "Survive 10 minutes", "gold": 200},
	{"id": "level_10", "title": "Rising Star", "desc": "Reach level 10", "gold": 100},
	{"id": "level_25", "title": "Veteran", "desc": "Reach level 25", "gold": 200},
	{"id": "first_boss", "title": "Boss Slayer", "desc": "Defeat a boss", "gold": 300},
	{"id": "combo_25", "title": "Chain Master", "desc": "Hit a 25 kill combo", "gold": 150},
	{"id": "weapon_evolved", "title": "Weapon Evolver", "desc": "Evolve a weapon", "gold": 250},
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
	var unlocked: Dictionary = SaveManager.get_meta_data("achievements", {})
	var header := Label.new()
	header.text = "Unlocked %d / %d" % [unlocked.size(), DEFS.size()]
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	rows.add_child(header)
	for def in DEFS:
		var got: bool = unlocked.has(def["id"])
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var title := Label.new()
		var mark := "✓" if got else "…"
		title.text = "%s  %s  (+%d gold)" % [mark, def["title"], def["gold"]]
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55) if got else Color(0.55, 0.58, 0.65))
		row.add_child(title)
		var desc := Label.new()
		desc.text = def["desc"]
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
		row.add_child(desc)
		rows.add_child(row)
