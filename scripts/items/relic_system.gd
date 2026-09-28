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
	applied_relics[data.id] = true
	_apply_relic_synergy(data)
	EventBus.upgrade_applied.emit("RELIC: " + data.display_name)

## V17: relic × weapon / relic × relic synergy hooks (once per pairing).
func _apply_relic_synergy(data: RelicData) -> void:
	if player == null or not is_instance_valid(player):
		return
	var weapon_ids: Array = []
	if player.get("weapon_controller") != null:
		for w in player.weapon_controller.weapons:
			weapon_ids.append(w.data.id)
	# Power Ring + fire kit → extra might
	if data.id == "ring":
		var fire_count := 0
		for wid in ["fireball", "hellfire", "thunderstorm", "lightning"]:
			if weapon_ids.has(wid):
				fire_count += 1
		if fire_count >= 2:
			_grant_once("relic_ring_fire", "RELIC SYNERGY: Inferno Band (+10% might)", "might", 0.10)
	# Crown + Clover → deeper luck well
	if data.id == "clover" or data.id == "crown":
		var other := "crown" if data.id == "clover" else "clover"
		if _has_relic(other):
			_grant_once("relic_crown_clover", "RELIC SYNERGY: Favored Fortune (+10% luck, +10% XP)", "luck", 0.10)
			player.stat_block.add_modifier("xp_gain", 0.0, 0.10)
			player.on_stats_changed()
	# Armor + Wings → mobile bulwark
	if data.id == "armor" or data.id == "wings":
		var other := "wings" if data.id == "armor" else "armor"
		if _has_relic(other):
			_grant_once("relic_bulwark", "RELIC SYNERGY: Mobile Bulwark (+8% move speed, +4 armor)", "move_speed", 0.08)
			player.stat_block.add_modifier("armor", 4.0, 0.0)
			player.on_stats_changed()

func _has_relic(id: String) -> bool:
	return applied_relics.has(id)

var applied_relics: Dictionary = {}
var applied_relic_synergies: Dictionary = {}

func _grant_once(key: String, title: String, stat: String, percent: float) -> void:
	if applied_relic_synergies.has(key):
		return
	applied_relic_synergies[key] = true
	player.stat_block.add_modifier(stat, 0.0, percent)
	player.on_stats_changed()
	EventBus.upgrade_applied.emit(title)
