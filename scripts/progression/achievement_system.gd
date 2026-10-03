extends Node
## AchievementSystem: milestone tracking with one-time gold rewards,
## persisted through SaveManager meta.

signal achievement_unlocked(id: String, title: String, gold: int)

const DEFS := [
	{"id": "kill_1", "title": "First Blood", "gold": 50},
	{"id": "kill_100", "title": "Centurion", "gold": 100},
	{"id": "kill_1000", "title": "Exterminator", "gold": 300},
	{"id": "survive_5min", "title": "Survivor I", "gold": 100},
	{"id": "survive_10min", "title": "Survivor II", "gold": 200},
	{"id": "survive_15min", "title": "Hordebreaker", "gold": 500},
	{"id": "win_run", "title": "Victorious", "gold": 400},
	{"id": "level_10", "title": "Rising Star", "gold": 100},
	{"id": "level_25", "title": "Veteran", "gold": 200},
	{"id": "first_boss", "title": "Boss Slayer", "gold": 300},
	{"id": "combo_25", "title": "Chain Master", "gold": 150},
	{"id": "weapon_evolved", "title": "Weapon Evolver", "gold": 250},
	{"id": "elite_slayer", "title": "Elite Slayer", "gold": 200},
	{"id": "combo_100", "title": "Unstoppable", "gold": 350},
	{"id": "torchbearer", "title": "Torchbearer of Heartforge", "gold": 500},
]

var unlocked: Dictionary = {}
var _pending_kills: int = 0

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
	# Only when actually surviving 15 minutes — a short mission win must
	# not unlock Hordebreaker.
	if RunManager.elapsed_time >= 900.0:
		_unlock("survive_15min")
	elif RunManager.elapsed_time >= 600.0:
		_unlock("survive_10min")
	elif RunManager.elapsed_time >= 300.0:
		_unlock("survive_5min")

func _on_run_ended(victory: bool) -> void:
	_flush_kills()
	if victory:
		_unlock("win_run")
		# Only a genuine 15-minute survival counts (not short mission wins).
		if RunManager.elapsed_time >= 900.0:
			_unlock("survive_15min")
		if RunManager.mission != null and str(RunManager.mission.id) == "m5_heartforge":
			_unlock("torchbearer")

func _on_kill(_enemy: Node, _pos: Vector3) -> void:
	# Accumulate in memory; flushing per kill caused a disk write per kill.
	_pending_kills += 1
	var kills: int = int(SaveManager.get_meta_data("total_kills", 0)) + _pending_kills
	if kills >= 1000:
		_unlock("kill_1000")
	elif kills >= 100:
		_unlock("kill_100")
	_unlock("kill_1")
	if _enemy != null and _enemy.get("elite") != null and _enemy.elite != null:
		_unlock("elite_slayer")

## Bank the accumulated kill count into the save (end of run / partial commit).
func _flush_kills() -> void:
	if _pending_kills <= 0:
		return
	var kills: int = int(SaveManager.get_meta_data("total_kills", 0)) + _pending_kills
	_pending_kills = 0
	SaveManager.set_meta_data("total_kills", kills)

func _on_level(level: int) -> void:
	if level >= 25:
		_unlock("level_25")
	elif level >= 10:
		_unlock("level_10")

func _on_boss() -> void:
	_unlock("first_boss")

func _on_combo(count: int, _mult: float) -> void:
	if count >= 100:
		_unlock("combo_100")
	elif count >= 25:
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
