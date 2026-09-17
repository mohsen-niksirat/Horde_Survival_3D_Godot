extends Node
## RelicSystem: spawns rarity-weighted relic pickups around the arena,
## applies their modifiers on pickup. Per-run node.

const RELIC_IDS := ["crown", "wings", "armor", "clover", "ring", "phoenix_feather"]
const SPAWN_INTERVAL := 45.0
const MAX_ON_MAP := 3
const PICKUP_SCENE := "res://scenes/pickups/RelicPickup.tscn"
const LIFETIME := 120.0

var player: Node3D
var arena: Node3D
var pickup_root: Node3D

var _timer: float = 20.0
var _pool: Array = []
var _relic_scene: PackedScene

func setup(p_player: Node3D, p_arena: Node3D, p_pickup_root: Node3D) -> void:
	add_to_group("relic_system")
	player = p_player
	arena = p_arena
	pickup_root = p_pickup_root
	_relic_scene = load(PICKUP_SCENE)
	for id in RELIC_IDS:
		var path := "res://data/relics/%s.tres" % id
		if ResourceLoader.exists(path):
			_pool.append(load(path))

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = SPAWN_INTERVAL
		_try_spawn()

func _try_spawn() -> void:
	if _pool.is_empty():
		return
	# Count only live relic pickups — pickup_root may also hold projectiles/VFX
	var live := 0
	if get_tree() != null:
		for child in get_tree().get_nodes_in_group("relics"):
			if is_instance_valid(child) and child.is_inside_tree():
				live += 1
	if live >= MAX_ON_MAP:
		return
	# Rarity-weighted pick
	var total := 0
	for r in _pool:
		total += r.rarity_weight()
	var roll := randi() % total
	var chosen = _pool[0]
	for r in _pool:
		roll -= r.rarity_weight()
		if roll <= 0:
			chosen = r
			break
	# Spawn on ring
	var relic := _relic_scene.instantiate()
	pickup_root.add_child(relic)
	relic.add_to_group("relics")
	var pos: Vector3 = arena.get_spawn_position(player.global_position)
	relic.setup(chosen, player, pos, LIFETIME)

func apply_relic(data: RelicData) -> void:
	player.stat_block.base["max_hp"] += 0  # no-op touch to ensure statblock exists
	for m in data.modifiers:
		player.stat_block.add_modifier(m.get("stat", ""), m.get("flat", 0.0), m.get("percent", 0.0))
	player.on_stats_changed()
	if data.special == "revive_once":
		player.grant_revive()
	EventBus.upgrade_applied.emit(data.display_name)
