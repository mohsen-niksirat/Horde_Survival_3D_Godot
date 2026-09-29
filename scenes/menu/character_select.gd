extends Control
## Character select: pick applies id + starts the run.
## R4: unlock gates — mage free, paladin after 1 win, rogue after 3 wins.

const CHARS := ["mage", "paladin", "rogue"]
const UNLOCK_WINS := {
	"mage": 0,
	"paladin": 1,
	"rogue": 3,
}

@onready var cards: HBoxContainer = $Center/Layout/Cards
@onready var close_button: Button = $Center/Layout/Close

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(func(): visible = false)

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
			card.text = "%s\n\n%s\nStarts with: %s" % [data.display_name, data.description, weapon_name]
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
	GameManager.selected_character_id = data.id
	# Persist selection
	SaveManager.set_meta_data("selected_character", data.id)
	GameManager.start_game()
