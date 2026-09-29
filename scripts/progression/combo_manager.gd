extends Node
## ComboManager: kill-streak counter with decay. XP multiplier via
## StatBlock hook. Per-run node.

signal combo_tier_reached(tier_name: String)

const TIMEOUT := 2.8
const TIERS := [
	{"name": "GODLIKE", "count": 200},
	{"name": "DIAMOND", "count": 100},
	{"name": "PLATINUM", "count": 50},
	{"name": "GOLD", "count": 25},
	{"name": "SILVER", "count": 10},
	{"name": "BRONZE", "count": 0},
]

var count: int = 0
var max_combo: int = 0
var _timer: float = 0.0
var _last_tier: String = ""

func _ready() -> void:
	EventBus.enemy_died.connect(_on_kill)

func _process(delta: float) -> void:
	if count > 0:
		_timer -= delta
		if _timer <= 0.0:
			count = 0
			_emit_combo()

func _on_kill(_enemy: Node, _pos: Vector3) -> void:
	count += 1
	_timer = TIMEOUT
	if count > max_combo:
		max_combo = count
	_emit_combo()

func _emit_combo() -> void:
	EventBus.combo_changed.emit(count, get_multiplier())
	var tier := get_tier()
	if tier != _last_tier:
		_last_tier = tier
		if tier != "BRONZE":
			combo_tier_reached.emit(tier)
			if EventBus != null:
				EventBus.upgrade_applied.emit("COMBO %s" % tier)

func get_tier() -> String:
	for t in TIERS:
		if count >= t["count"]:
			return t["name"]
	return "BRONZE"

## Playtest: combo streak can hit thousands — cap XP multiplier so leveling
## does not explode. Display still shows the raw streak count.
func get_multiplier() -> float:
	var mult := 1.0 + float(count / 5) * 0.1
	return minf(mult, 3.5)

func reset() -> void:
	count = 0
	max_combo = 0
	_last_tier = ""
