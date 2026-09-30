extends Control
## Character select: pick applies id + starts the run.
## R4: unlock gates — mage free, paladin after 1 win, rogue after 3 wins.

const CHARS := ["mage", "paladin", "rogue", "cleric", "ranger"]
const UNLOCK_WINS := {
	"mage": 0,
	"paladin": 1,
	"rogue": 3,
	"cleric": 2,
	"ranger": 4,
}
const LORE := {
	"mage": "Once a court scholar who read the stars a little too closely. When the horde rose from the deep dungeon, she traded dusty tomes for living fire — and never looked back.",
	"paladin": "A shield-bearer of the old order. Sworn to hold the line until the last torch dies. Slow to move, harder to kill, gold as the dawn.",
	"rogue": "Grew up in the market under the dungeon walls. Steals relics from the horde the way she once stole bread — fast, quiet, and always one step ahead.",
	"cleric": "Kept the Heartforge lit for thirty years. When the wards cracked, prayer turned to light — and light turned into a weapon.",
	"ranger": "Scouted the frostroad until the ice swallowed the signal fires. Now the cold itself answers when she calls.",
}

@onready var cards: HBoxContainer = $Center/Layout/Cards
@onready var close_button: Button = $Center/Layout/Close

var _lore_label: Label

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(func(): visible = false)
	_lore_label = Label.new()
	_lore_label.name = "Lore"
	_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore_label.custom_minimum_size = Vector2(700, 80)
	_lore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lore_label.add_theme_font_size_override("font_size", 15)
	_lore_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	var layout: Node = get_node_or_null("Center/Layout")
	if layout != null:
		layout.add_child(_lore_label)
		layout.move_child(_lore_label, 1)

func open() -> void:
	_build()
	visible = true
	AudioManager.play_game_sfx("ui_click")

func _is_unlocked(id: String) -> bool:
	var wins: int = SaveManager.get_meta_data("victories", 0)
	return wins >= int(UNLOCK_WINS.get(id, 0))

func _build() -> void:
	for c in cards.get_children():
		c.queue_free()
	var wins: int = SaveManager.get_meta_data("victories", 0)
	for id in CHARS:
		var path := "res://data/characters/%s.tres" % id
		if not ResourceLoader.exists(path):
			continue
		var data: CharacterData = load(path)
		var unlocked := _is_unlocked(id)
		var need: int = int(UNLOCK_WINS.get(id, 0))
		var card := Button.new()
		card.custom_minimum_size = Vector2(220, 220)
		if unlocked:
			var weapon_name: String = data.starting_weapon_id.replace("_", " ").capitalize()
			card.text = "%s\n\n%s\nStarts with: %s\n\n(tap again to start)" % [data.display_name, data.description, weapon_name]
			card.add_theme_color_override("font_color", data.color)
			card.pressed.connect(_on_pick.bind(data))
		else:
			card.text = "%s\n\nLOCKED\nWin %d run(s) to unlock\n(you have %d)" % [data.display_name, need, wins]
			card.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
			card.disabled = true
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 15)
		cards.add_child(card)

func _on_pick(data: CharacterData) -> void:
	if not _is_unlocked(data.id):
		return
	# First tap shows lore; second tap starts (T-playtest)
	if _lore_label != null and _lore_label.text != LORE.get(data.id, ""):
		_lore_label.text = str(LORE.get(data.id, data.description))
		AudioManager.play_game_sfx("ui_click")
		return
	GameManager.selected_character_id = data.id
	# Persist selection
	SaveManager.set_meta_data("selected_character", data.id)
	GameManager.start_game()
