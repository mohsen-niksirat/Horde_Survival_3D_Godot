class_name CharacterData
extends Resource
## Playable character definition.

@export var id: String = "mage"
@export var display_name: String = "Mage"
@export var description: String = "Balanced spellslinger"
@export var color: Color = Color(0.42, 0.71, 1.0)
@export var starting_weapon_id: String = "fireball"
@export var starting_passive_id: String = ""

const UNLOCK_WINS := {"mage": 0, "paladin": 1, "rogue": 3, "cleric": 2, "ranger": 4, "stormcaller": 5, "warden": 6}

static func unlock_requirement(character_id: String) -> int:
	return int(UNLOCK_WINS.get(character_id, 2147483647))

## Stat modifiers applied at run start (percent).
@export var max_hp_pct: float = 0.0
@export var move_speed_pct: float = 0.0
@export var might_pct: float = 0.0
