extends Control
## P9: achievements catalog — all milestones with unlock state and gold rewards.

const DEFS := [
	{"id": "kill_1", "title": "First Blood", "desc": "Get your first kill", "gold": 50},
	{"id": "kill_100", "title": "Centurion", "desc": "100 total kills", "gold": 100},
	{"id": "kill_1000", "title": "Exterminator", "desc": "1000 total kills", "gold": 300},
	{"id": "survive_5min", "title": "Survivor I", "desc": "Survive 5 minutes", "gold": 100},
	{"id": "survive_10min", "title": "Survivor II", "desc": "Survive 10 minutes", "gold": 200},
	{"id": "survive_15min", "title": "Hordebreaker", "desc": "Survive 15 minutes", "gold": 500},
	{"id": "win_run", "title": "Victorious", "desc": "Win a standard 15-minute run", "gold": 400},
	{"id": "level_10", "title": "Rising Star", "desc": "Reach level 10", "gold": 100},
	{"id": "level_25", "title": "Veteran", "desc": "Reach level 25", "gold": 200},
	{"id": "first_boss", "title": "Boss Slayer", "desc": "Defeat a boss", "gold": 300},
	{"id": "combo_25", "title": "Chain Master", "desc": "Hit a 25 kill combo", "gold": 150},
	{"id": "weapon_evolved", "title": "Weapon Evolver", "desc": "Evolve a weapon", "gold": 250},
	{"id": "elite_slayer", "title": "Elite Slayer", "desc": "Defeat an elite enemy", "gold": 200},
	{"id": "combo_100", "title": "Unstoppable", "desc": "Hit a 100 kill combo", "gold": 350},
	{"id": "torchbearer", "title": "Torchbearer of Heartforge", "desc": "Complete the Heartforge finale and save the city", "gold": 500},
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
		# Row layout: status badge on the left, title/description stack on the right.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var badge := Label.new()
		badge.text = "★" if got else "○"
		badge.add_theme_font_size_override("font_size", 22)
		# Gold for unlocked, gray for locked.
		badge.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0) if got else Color(0.5, 0.52, 0.58))
		badge.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		badge.custom_minimum_size = Vector2(30, 0)
		row.add_child(badge)
		var text_col := VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_col.add_theme_constant_override("separation", 2)
		var title := Label.new()
		title.text = "%s  (+%d gold)" % [def["title"], def["gold"]]
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55) if got else Color(0.55, 0.58, 0.65))
		text_col.add_child(title)
		var desc := Label.new()
		desc.text = def["desc"]
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
		text_col.add_child(desc)
		if not got:
			# V16A: numeric goals show a progress bar; binary goals show the requirement.
			var progress: Array = _progress_for(def["id"])
			if progress.size() == 2:
				var bar := ProgressBar.new()
				bar.custom_minimum_size = Vector2(0, 8)
				bar.max_value = float(progress[1])
				bar.value = minf(float(progress[0]), float(progress[1]))
				bar.show_percentage = false
				var fill := StyleBoxFlat.new()
				fill.bg_color = Color(0.55, 0.95, 0.55) if float(progress[0]) >= float(progress[1]) else Color(0.3, 0.75, 1.0)
				fill.set_corner_radius_all(4)
				bar.add_theme_stylebox_override("fill", fill)
				var bg := StyleBoxFlat.new()
				bg.bg_color = Color(0.16, 0.18, 0.24)
				bg.set_corner_radius_all(4)
				bar.add_theme_stylebox_override("background", bg)
				text_col.add_child(bar)
			else:
				desc.text = "%s — %s" % [def["desc"], str(progress[0])]
		row.add_child(text_col)
		rows.add_child(row)

## V16A: [current, target] for numeric goals, [requirement_text] otherwise.
func _progress_for(id: String) -> Array:
	match id:
		"kill_1":
			return [mini(int(SaveManager.get_meta_data("total_kills", 0)), 1), 1]
		"kill_100":
			return [int(SaveManager.get_meta_data("total_kills", 0)), 100]
		"kill_1000":
			return [int(SaveManager.get_meta_data("total_kills", 0)), 1000]
		"level_10":
			return [int(SaveManager.get_meta_data("best_level", 0)), 10]
		"level_25":
			return [int(SaveManager.get_meta_data("best_level", 0)), 25]
		"combo_25":
			return [int(SaveManager.get_meta_data("best_combo", 0)), 25]
		"combo_100":
			return [int(SaveManager.get_meta_data("best_combo", 0)), 100]
		"survive_5min":
			return [int(SaveManager.get_meta_data("best_time", 0.0)) / 60, 5]
		"survive_10min":
			return [int(SaveManager.get_meta_data("best_time", 0.0)) / 60, 10]
		"survive_15min":
			return [int(SaveManager.get_meta_data("best_time", 0.0)) / 60, 15]
		"win_run":
			return ["Win a standard 15-minute run"]
		"first_boss":
			return ["Defeat the Warden boss"]
		"weapon_evolved":
			return ["Evolve any weapon"]
		"elite_slayer":
			return ["Defeat an elite enemy"]
		"torchbearer":
			return ["Finish the Heartforge finale (m5)"]
	return []
