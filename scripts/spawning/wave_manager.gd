extends Node
## WaveManager: threat-budget spawning over a difficulty timeline.
## Owns SpawnManager duties (this is small enough to stay one system until
## modes require separate spawn strategies).

const EliteAbilityC := preload("res://scripts/enemies/elite_ability.gd")

## Auto-aim weapons ignore enemies beyond this range even if data says
## otherwise — keeps targeting to what the player can actually see.
const TARGETABLE_RANGE_CAP := 32.0

var arena: Node3D
var player: Node3D
var enemy_manager: Node

var archetype_data: Dictionary = {}
var _spawn_timer: float = 0.0
var _active: bool = false
var _last_elite_level: int = 0
var _boss_spawned: bool = false
var _next_endless_boss_time: float = 300.0
var _endless_boss_count: int = 0
const BOSS_TIME := 300.0
const BOSS_SCENE := "res://scenes/bosses/Boss.tscn"

func setup(p_arena: Node3D, p_player: Node3D, p_enemy_manager: Node) -> void:
	arena = p_arena
	player = p_player
	enemy_manager = p_enemy_manager
	enemy_manager.arena_ref = arena
	enemy_manager.player_ref = player
	_load_archetypes()
	_active = true

func _load_archetypes() -> void:
	for id in ["basic_drone", "fast_wisp", "tank_golem", "swarm_bat", "shooter_turret", "ghost", "splitter", "healer", "mage"]:
		var path := "res://data/enemies/%s.tres" % id
		if ResourceLoader.exists(path):
			archetype_data[id] = load(path)

func stop() -> void:
	_active = false

func _process(delta: float) -> void:
	if not _active or player == null or not is_instance_valid(player):
		return
	if GameManager.state != GameManager.State.PLAYING and GameManager.state != GameManager.State.BOSS:
		return

	var start := Time.get_ticks_usec()
	var minutes := RunManager.elapsed_time / 60.0
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = DifficultyManager.spawn_interval(minutes)
		_spawn_wave(minutes)

	_tick_boss()
	_tick_elites()
	PerformanceManager.report_system_time("waves", Time.get_ticks_usec() - start)

## Milestone boss at BOSS_TIME seconds; in Endless, respawns every 5 min
## at +30% stats.
func _tick_boss() -> void:
	if RunManager.endless:
		if RunManager.elapsed_time >= _next_endless_boss_time:
			_next_endless_boss_time += 300.0
			_endless_boss_count += 1
			_spawn_boss(1.0 + 0.3 * _endless_boss_count)
		return
	if not _boss_spawned and RunManager.elapsed_time >= BOSS_TIME:
		_boss_spawned = true
		_spawn_boss(1.0)

func _spawn_boss(stat_scale: float = 1.0) -> void:
	var boss_scene: PackedScene = load(BOSS_SCENE)
	var boss := boss_scene.instantiate()
	# Spawn under the World (PAUSABLE) so the boss obeys pause and is a
	# normal child of the arena — NOT under Main (ALWAYS).
	get_parent().get_node("World").add_child(boss)
	var angle := randf() * TAU
	var pos := player.global_position + Vector3(cos(angle), 0, sin(angle)) * 20.0
	pos.x = clampf(pos.x, -55, 55)
	pos.z = clampf(pos.z, -55, 55)
	boss.global_position = Vector3(pos.x, 0.5, pos.z)
	boss.setup(player, enemy_manager, arena, DifficultyManager.hp_scale(DifficultyManager.difficulty_multiplier(player.experience.level, RunManager.elapsed_time / 60.0)) * 0.4 * stat_scale)
	# Register the boss in the active list so weapons can target it
	if not enemy_manager.active_enemies.has(boss):
		enemy_manager.active_enemies.append(boss)
	PerformanceManager.active_enemies = enemy_manager.active_enemies.size()
	boss.boss_died.connect(func():
		enemy_manager.active_enemies.erase(boss)
		PerformanceManager.active_enemies = enemy_manager.active_enemies.size()
	)
	RunManager.set_boss_active(true)
	GameManager.change_state(GameManager.State.BOSS)
	EventBus.boss_spawned.emit(boss)

## Elite every 10 player levels (reference-game cadence).
func _tick_elites() -> void:
	var level: int = player.experience.level
	if DifficultyManager.should_spawn_elite(level, _last_elite_level):
		_last_elite_level = int(level / 10) * 10
		_spawn_elite()

func _spawn_elite() -> void:
	var cap: int = PerformanceManager.enemy_cap()
	if enemy_manager.enemy_count() >= cap:
		return
	var data: EnemyData = _pick_archetype(DifficultyManager.allowed_archetypes(RunManager.elapsed_time / 60.0))
	if data == null:
		return
	var minutes := RunManager.elapsed_time / 60.0
	var difficulty := DifficultyManager.difficulty_multiplier(player.experience.level, minutes)
	var abilities: Array = []
	var pool: Array = EliteAbilityC.ALL.duplicate()
	pool.shuffle()
	abilities.append(pool[0])
	if randf() < 0.4:
		abilities.append(pool[1])
	var pos: Vector3 = arena.get_spawn_position(player.global_position)
	enemy_manager.queue_spawn(data, pos, player, DifficultyManager.hp_scale(difficulty), DifficultyManager.damage_scale(difficulty), DifficultyManager.speed_scale(difficulty), abilities)

func _spawn_wave(minutes: float) -> void:
	# Population control first
	var cap: int = PerformanceManager.enemy_cap()
	var current: int = enemy_manager.enemy_count()
	if current >= cap:
		return
	var room: int = cap - current

	# Boss pressure: while a boss is alive, thin the horde (30%) so the
	# player can focus on telegraphs instead of drowning in adds
	if RunManager.is_boss_active():
		room = int(room * 0.3)
		if room <= 0:
			return

	# Threat budget for this wave
	var budget: float = DifficultyManager.threat_budget(minutes)
	var level: int = player.experience.level if player.has_method("get") and "experience" in player else 1
	var difficulty := DifficultyManager.difficulty_multiplier(level, minutes)
	var hp_s := DifficultyManager.hp_scale(difficulty)
	var dmg_s := DifficultyManager.damage_scale(difficulty)
	var spd_s := DifficultyManager.speed_scale(difficulty)

	var allowed: Array = DifficultyManager.allowed_archetypes(minutes)
	var spawned := 0
	for i in range(24):
		if budget <= 0.0 or spawned >= room:
			break
		var data: EnemyData = _pick_archetype(allowed)
		if data == null:
			break
		if data.threat_cost > budget and spawned > 0:
			break
		var pos: Vector3 = arena.get_spawn_position(player.global_position)
		enemy_manager.queue_spawn(data, pos, player, hp_s, dmg_s, spd_s)
		budget -= data.threat_cost
		spawned += 1

func _pick_archetype(allowed: Array) -> EnemyData:
	var pool: Array = []
	var total_weight := 0.0
	for id in allowed:
		if archetype_data.has(id):
			var data: EnemyData = archetype_data[id]
			pool.append(data)
			total_weight += data.spawn_weight
	if pool.is_empty():
		return null
	var roll := randf() * total_weight
	for data in pool:
		roll -= data.spawn_weight
		if roll <= 0.0:
			return data
	return pool[0]
