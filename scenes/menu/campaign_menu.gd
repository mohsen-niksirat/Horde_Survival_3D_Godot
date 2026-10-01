extends Control
## S1 campaign menu: mission list with briefings and win rules.

const MISSIONS := [
	"res://data/missions/m1_gate.tres",
	"res://data/missions/m2_frost.tres",
	"res://data/missions/m3_nest.tres",
	"res://data/missions/m4_warden.tres",
	"res://data/missions/m5_heartforge.tres",
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
	var completed: Array = SaveManager.get_meta_data("completed_missions", [])
	
	# Progress Header
	var comp_count := 0
	for path in MISSIONS:
		if ResourceLoader.exists(path):
			var m = load(path)
			if completed.has(m.id):
				comp_count += 1
	var progress_banner := Label.new()
	progress_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if comp_count >= MISSIONS.size():
		progress_banner.text = "★ TORCHBEARER — ALL %d MISSIONS COMPLETED (100%%) ★" % MISSIONS.size()
		progress_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		progress_banner.text = "Campaign Progress: %d / %d Missions Completed (%d%%)" % [
			comp_count, MISSIONS.size(), int((float(comp_count) / float(MISSIONS.size())) * 100.0)
		]
		progress_banner.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	progress_banner.add_theme_font_size_override("font_size", 14)
	rows.add_child(progress_banner)

	var last_act := -1
	for path in MISSIONS:
		if not ResourceLoader.exists(path):
			continue
		var m = load(path)
		var act_num: int = int(m.get("act") if m.get("act") != null else 1)
		var act_title: String = str(m.get("act_name")) if m.get("act_name") != null else ("Act %d" % act_num)
		if act_num != last_act:
			last_act = act_num
			var act_header := Label.new()
			act_header.text = "— %s —" % act_title
			act_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			act_header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.45))
			act_header.add_theme_font_size_override("font_size", 15)
			rows.add_child(act_header)

		var unlocked: bool = m.is_unlocked(wins)
		var is_done: bool = completed.has(m.id)
		var card := Button.new()
		card.custom_minimum_size = Vector2(520, 100)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if unlocked:
			var done_tag := " [COMPLETED ✓]" if is_done else ""
			var side_desc := ""
			if m.has_method("describe_side") and m.describe_side() != "":
				side_desc = "  ·  " + m.describe_side()
			card.text = "%s%s\n%s\nObjective: %s%s  ·  Reward: %d gold" % [
				m.display_name, done_tag, m.briefing, m.describe_win(), side_desc, m.gold_reward]
			card.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0) if not is_done else Color(0.65, 0.95, 0.65))
			card.pressed.connect(_on_start.bind(m))
		else:
			card.text = "%s\nLOCKED — win %d run(s) to unlock" % [m.display_name, m.unlock_wins]
			card.disabled = true
			card.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
		card.add_theme_font_size_override("font_size", 13)
		rows.add_child(card)

func _on_start(m) -> void:
	RunManager.endless = false
	RunManager.set_mission(m)
	GameManager.start_game()
