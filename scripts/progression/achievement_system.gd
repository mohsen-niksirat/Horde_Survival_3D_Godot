extends Node
## AchievementSystem: milestone tracking with one-time gold rewards,
## persisted through SaveManager meta.

signal achievement_unlocked(id: String, title: String, gold: int)

const DEFS := [
	{"id": "kill_1", "title": "First Blood", "gold": 50},
	{"id": "kill_100", "title": "Centurion", "gold": 100},
	{"id": "kill_1000", "title": "Exterminator", "gold": 300},
	{"id": "survive_5min", "title": " Survivor I", "gold": 100},
	{"id": "survive_10min", "title": "Survivor II", "gold": 200},
	{"id": "survive_15min", "title": "Hordebreaker", "gold": 500},
	{"id": "win_run", "title": "Victorious", "gold": 400},
	{"id": "level_10", "title": "Rising Star", "gold": 100},
	{"id": "level_25", "title": "Veteran", "gold": 200},
	{"id": "first_boss", "title": "Boss Slayer", "gold": 300},
	{"id": "combo_25", "title": "Chain Master", "gold": 150},
	{"id": "weapon_evolved", "title": "Weapon Evolver", "gold": 250},
]

var unlocked: Dictionary = {}

func _ready() -> void:
	EventBus.enemy_died.connect(_on_kill)
	EventBus.player_leveled_up.connect(_on_level)
	EventBus.boss_died.connect(_on_boss)
	EventBus.combo_changed.connect(_on_combo)
	EventBus.upgrade_applied.connect(_on_upgrade)
	EventBus.run_ended.connect(_on_run_ended)
	unlocked = SaveManager.get_meta_data("achievements", {}).duplicate()

func _process(_delta: float) -> void:
	if RunManager.is_running:
		_check_time()

func _check_time() -> void:
	if RunManager.elapsed_time >= 900.0:
		_unlock("survive_15min")
	elif RunManager.elapsed_time >= 600.0:
		_unlock("survive_10min")
	elif RunManager.elapsed_time >= 300.0:
		_unlock("survive_5min")

func _on_run_ended(victory: bool) -> void:
	if victory:
		_unlock("win_run")
		_unlock("survive_15min")

func _on_kill(_enemy: Node, _pos: Vector3) -> void:
	var kills: int = SaveManager.get_meta_data("total_kills", 0) + 1
	SaveManager.set_meta_data("total_kills", kills)
	if kills >= 1000:
		_unlock("kill_1000")
	elif kills >= 100:
		_unlock("kill_100")
	_unlock("kill_1")

func _on_level(level: int) -> void:
	if level >= 25:
		_unlock("level_25")
	elif level >= 10:
		_unlock("level_10")

func _on_boss() -> void:
	_unlock("first_boss")

func _on_combo(count: int, _mult: float) -> void:
	if count >= 25:
		_unlock("combo_25")

func _on_upgrade(title: String) -> void:
	if title.begins_with("EVOLVE"):
		_unlock("weapon_evolved")

func _unlock(id: String) -> void:
	if unlocked.has(id):
		return
	for def in DEFS:
		if def["id"] == id:
			unlocked[id] = true
			SaveManager.set_meta_data("achievements", unlocked)
			var gold: int = def["gold"]
			SaveManager.set_meta_data("gold", SaveManager.get_meta_data("gold", 0) + gold)
			achievement_unlocked.emit(id, def["title"], gold)
			if EventBus != null:
				EventBus.achievement_unlocked.emit(id, def["title"], gold)
			return
