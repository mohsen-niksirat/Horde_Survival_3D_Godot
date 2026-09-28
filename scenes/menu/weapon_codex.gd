extends Control
## P4: weapon / build codex — catalog of weapons, evolutions, synergies, relics.

const WEAPONS := [
	"fireball", "magic_missile", "orbiting_shield", "divine_spear", "lightning",
	"void_lance", "hellfire", "holy_bible", "aurora", "judgment", "thunderstorm",
]
const EVOLUTIONS := [
	{"base": "Fireball", "passive": "Spinach (max)", "result": "Hellfire"},
	{"base": "Magic Missile", "passive": "Empty Tome (max)", "result": "Holy Bible"},
	{"base": "Orbiting Shield", "passive": "Heart (max)", "result": "Aurora"},
	{"base": "Divine Spear", "passive": "Crown (max)", "result": "Judgment"},
	{"base": "Lightning", "passive": "Wings (max)", "result": "Thunderstorm"},
]
const SYNERGIES := [
	"Fireball + Lightning → Firestorm (+15% might)",
	"Magic Missile + Lightning → Storm Caller (−10% cooldown)",
	"Orbiting Shield + Divine Spear → Iron Tempest (+10% area)",
	"Holy Bible + Orbiting Shield → Holy Aegis (+12% armor)",
	"Hellfire + Thunderstorm → Wildfire (+12% might)",
	"Aurora + Judgment → Astral Conduit (−8% cooldown)",
	"Void Lance + Lightning → Void Storm (+12% crit)",
]
const RELICS := [
	"Crown of Wisdom — +25% XP gain",
	"Swift Wings — +20% move speed",
	"Iron Armor — +8 armor",
	"Golden Clover — +15% luck",
	"Power Ring — +15% might",
	"Phoenix Feather — revive once at 50% HP",
]
const PASSIVES := [
	"Spinach — +10% damage / level",
	"Empty Tome — cooldown reduction",
	"Crown — XP gain",
	"Wings — move speed",
	"Magnet — pickup radius",
	"Heart — max HP",
	"Growth — XP / level scaling",
	"Vampire — lifesteal",
	"Hunter's Mark — +3% crit / level",
]
const RELIC_SYNS := [
	"Power Ring + 2 fire weapons → Inferno Band (+10% might)",
	"Crown + Clover → Favored Fortune (+10% luck, +10% XP)",
	"Armor + Wings → Mobile Bulwark (+8% speed, +4 armor)",
]

@onready var rows: VBoxContainer = $Center/Panel/Layout/Scroll/Rows
@onready var close_button: Button = $Center/Panel/Layout/Close

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(func(): visible = false)
	_build()

func open() -> void:
	visible = true
	AudioManager.play_game_sfx("ui_click")

func _section(title: String, color: Color) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	rows.add_child(spacer)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	rows.add_child(label)

func _line(text: String, color: Color = Color(0.88, 0.9, 0.95), size: int = 15) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	rows.add_child(label)

func _build() -> void:
	for c in rows.get_children():
		c.queue_free()

	var wc_script: GDScript = load("res://scripts/weapons/weapon_controller.gd")
	var flash_colors: Dictionary = {}
	if wc_script != null and wc_script.WEAPON_FLASH_COLORS != null:
		flash_colors = wc_script.WEAPON_FLASH_COLORS

	_section("WEAPONS", Color(1.0, 0.84, 0.0))
	for w in WEAPONS:
		var data: WeaponData = load("res://data/weapons/%s.tres" % w)
		if data == null:
			continue
		var col: Color = flash_colors.get(w, Color.WHITE)
		_line("%s  ·  %s" % [data.display_name, data.type], col, 17)
		var status := "—"
		if data.status_effect != "":
			status = "%s (%.0fs)" % [data.status_effect, data.status_duration]
		_line("dmg %.0f · cd %.1fs · x%d proj · area %.1f · pierce %d · status %s" % [
			data.base_damage, data.base_cooldown, data.projectile_count,
			data.area, data.pierce, status,
		], Color(0.75, 0.78, 0.85), 13)

	_section("EVOLUTIONS  (weapon T5 + maxed passive)", Color(1.0, 0.75, 0.2))
	for e in EVOLUTIONS:
		_line("%s + %s  →  %s" % [e["base"], e["passive"], e["result"]], Color(0.92, 0.92, 0.98))

	_section("SYNERGIES  (hold both weapons)", Color(0.55, 0.9, 1.0))
	for s in SYNERGIES:
		_line(s, Color(0.85, 0.92, 1.0))

	_section("RELICS", Color(0.85, 0.55, 1.0))
	for r in RELICS:
		_line(r, Color(0.92, 0.85, 1.0))

	_section("PASSIVES  (level-up picks)", Color(0.6, 1.0, 0.75))
	for p in PASSIVES:
		_line(p, Color(0.85, 1.0, 0.9))

	_section("RELIC SYNERGIES", Color(1.0, 0.55, 0.7))
	for r in RELIC_SYNS:
		_line(r, Color(1.0, 0.88, 0.93))
