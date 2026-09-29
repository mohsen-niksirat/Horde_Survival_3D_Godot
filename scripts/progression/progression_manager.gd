extends Node
## ProgressionManager: generates level-up choices and applies them to the
## player's StatBlock/weapons. Per-run node owned by Main.

const PASSIVE_IDS := [
	"spinach", "empty_tome", "crown", "wings",
	"magnet", "heart", "growth", "vampire",
	"hunters_mark",
]
const MAX_WEAPON_SLOTS_CAP := 5
const BASE_WEAPON_SLOTS := 3

## T-playtest: start with 3 slots; meta_slots expands toward 5.
func max_weapon_slots() -> int:
	var bonus: int = 0
	if SaveManager != null:
		bonus = int(SaveManager.get_meta_data("meta_upgrades", {}).get("meta_slots", 0))
	return mini(BASE_WEAPON_SLOTS + bonus, MAX_WEAPON_SLOTS_CAP)
const CHOICES := 3
const NEW_WEAPON_POOL := ["fireball", "magic_missile", "orbiting_shield", "divine_spear", "lightning", "void_lance", "frost_bolt", "soul_fire"]

signal choices_generated(choices: Array)

var player: CharacterBody3D
var passive_levels: Dictionary = {}   # passive_id -> level
var passive_data: Dictionary = {}     # passive_id -> PassiveData
var pending_levels: int = 0
var evolutions: Array = []
var evolved_ids: Array = []

func setup(p_player: CharacterBody3D) -> void:
	player = p_player
	for id in PASSIVE_IDS:
		var path := "res://data/passives/%s.tres" % id
		if ResourceLoader.exists(path):
			passive_data[id] = load(path)
	# Load evolution recipes
	for evo_path in ["res://data/weapons/evo_hellfire.tres", "res://data/weapons/evo_holy_bible.tres", "res://data/weapons/evo_aurora.tres", "res://data/weapons/evo_judgment.tres", "res://data/weapons/evo_thunderstorm.tres", "res://data/weapons/evo_void_reaver.tres"]:
		if ResourceLoader.exists(evo_path):
			evolutions.append(load(evo_path))

## Called when the player levels up. Queues the level and shows choices;
## stacked multi-level ups wait until the current pick is made.
func offer_choices() -> void:
	pending_levels += 1
	match GameManager.state:
		GameManager.State.PLAYING, GameManager.State.BOSS:
			_open_and_offer()
		GameManager.State.LEVEL_UP:
			pass  # player is mid-pick; apply_and_continue chains the rest
		_:
			pending_levels = maxi(pending_levels - 1, 0)

func _open_and_offer() -> void:
	GameManager.open_level_up()
	pending_levels -= 1
	choices_generated.emit(generate_choices())

## Called by the UI after the player picks one card.
func apply_and_continue(option: UpgradeOption) -> void:
	apply_choice(option)
	if pending_levels > 0:
		_open_and_offer()
	else:
		GameManager.close_level_up()

func generate_choices() -> Array:
	var pool: Array = []
	_fill_pool(pool)
	# Deduplicate by title, keep 3 (fallback heal always last resort)
	var picked: Array = []
	var used_titles := {}
	pool.shuffle()
	for option in pool:
		if picked.size() >= CHOICES:
			break
		if used_titles.has(option.title):
			continue
		used_titles[option.title] = true
		picked.append(option)
	if picked.is_empty():
		picked.append(_make_heal_option())
	return picked

func _fill_pool(pool: Array) -> void:
	var weapon_controller: Node = player.weapon_controller
	var weapons: Array = weapon_controller.weapons

	# Evolutions (LEGENDARY priority — added first so they surface often)
	var evo: EvolutionData = EvolutionData.is_available(evolutions, weapon_controller, passive_levels)
	if evo != null and not evolved_ids.has(evo.id):
		var opt := UpgradeOption.new()
		opt.kind = UpgradeOption.Kind.EVOLVE
		opt.rarity = "legendary"
		opt.title = "EVOLVE: %s" % evo.display_name
		opt.description = "Transform your %s into %s!" % [_weapon_name(evo.base_weapon_id), evo.display_name]
		opt.target = evo
		pool.append(opt)

	# Weapon tier-ups — with a REAL description of what improves
	for w in weapons:
		if w.level < 5:
			var opt := UpgradeOption.new()
			opt.kind = UpgradeOption.Kind.WEAPON_TIER
			opt.rarity = "rare" if w.level >= 3 else "common"
			opt.title = w.data.display_name
			opt.description = _tier_description(w)
			opt.target = w.data
			opt.current_level = w.level
			opt.next_level = w.level + 1
			pool.append(opt)

	# New weapons: offer any not-yet-held weapon (player may hold max 5)
	if weapons.size() < max_weapon_slots():
		var held: Array = []
		for w in weapons:
			held.append(w.data.id)
		for wid in NEW_WEAPON_POOL:
			if held.has(wid):
				continue
			var wdata: WeaponData = load("res://data/weapons/%s.tres" % wid)
			if wdata == null:
				continue
			var nopt := UpgradeOption.new()
			nopt.kind = UpgradeOption.Kind.NEW_WEAPON
			nopt.rarity = "rare"
			nopt.title = "NEW: " + wdata.display_name
			nopt.description = wdata.display_name + " — " + _weapon_role(wid)
			nopt.target = wdata
			nopt.current_level = 0
			nopt.next_level = 1
			pool.append(nopt)
	for id in passive_data:
		var data: PassiveData = passive_data[id]
		var lvl: int = passive_levels.get(id, 0)
		if lvl >= data.max_level:
			continue
		var opt := UpgradeOption.new()
		opt.kind = UpgradeOption.Kind.PASSIVE
		opt.rarity = "common"
		if lvl + 1 >= data.max_level:
			opt.rarity = "rare"
		opt.title = data.display_name
		opt.description = "%s (Lv %d → %d)" % [data.description, lvl, lvl + 1]
		opt.target = data
		opt.current_level = lvl
		opt.next_level = lvl + 1
		pool.append(opt)

	# Heal fallback
	if pool.size() < CHOICES or player.health.get_ratio() < 0.5:
		pool.append(_make_heal_option())

func _make_heal_option() -> UpgradeOption:
	var opt := UpgradeOption.new()
	opt.kind = UpgradeOption.Kind.HEAL
	opt.rarity = "common"
	opt.title = "Heal"
	opt.description = "Restore 30% of max HP"
	return opt

## V12 weapon synergies: holding the paired weapons grants a passive bonus
## (applied once per run, data table kept here for MVP simplicity).
const SYNERGIES := [
	{"id": "firestorm", "requires": ["fireball", "lightning"], "title": "SYNERGY: Firestorm (+15% might)", "stat": "might", "percent": 0.15},
	{"id": "storm_caller", "requires": ["magic_missile", "lightning"], "title": "SYNERGY: Storm Caller (-10% cooldown)", "stat": "cooldown_mult", "percent": -0.10},
	{"id": "iron_tempest", "requires": ["orbiting_shield", "divine_spear"], "title": "SYNERGY: Iron Tempest (+10% area)", "stat": "area_mult", "percent": 0.10},
	# V17: more build identities
	{"id": "holy_aegis", "requires": ["holy_bible", "orbiting_shield"], "title": "SYNERGY: Holy Aegis (+12% armor)", "stat": "armor", "percent": 0.12},
	{"id": "wildfire", "requires": ["hellfire", "thunderstorm"], "title": "SYNERGY: Wildfire (+12% might)", "stat": "might", "percent": 0.12},
	{"id": "astral_conduit", "requires": ["aurora", "judgment"], "title": "SYNERGY: Astral Conduit (-8% cooldown)", "stat": "cooldown_mult", "percent": -0.08},
	{"id": "void_storm", "requires": ["void_lance", "lightning"], "title": "SYNERGY: Void Storm (+12% crit)", "stat": "crit_chance", "percent": 0.12},
]
var applied_synergies: Dictionary = {}

## Called after any weapon-affecting choice.
func _check_synergies() -> void:
	var ids: Array = []
	for w in player.weapon_controller.weapons:
		ids.append(w.data.id)
	for syn in SYNERGIES:
		var ok: bool = true
		for req in syn["requires"]:
			if not ids.has(req):
				ok = false
		if ok and not applied_synergies.has(syn["id"]):
			applied_synergies[syn["id"]] = true
			player.stat_block.add_modifier(syn["stat"], 0.0, syn["percent"])
			player.on_stats_changed()
			EventBus.upgrade_applied.emit(syn["title"])

## Apply the chosen option.
func apply_choice(option: UpgradeOption) -> void:
	match option.kind:
		UpgradeOption.Kind.EVOLVE:
			var evo: EvolutionData = option.target
			for w in player.weapon_controller.weapons:
				if w.data.id == evo.base_weapon_id:
					w.data = evo.evolved_weapon
					w.evolved = true
					break
			evolved_ids.append(evo.id)
		UpgradeOption.Kind.WEAPON_TIER:
			for w in player.weapon_controller.weapons:
				if w.data == option.target:
					w.level_up()
					break
		UpgradeOption.Kind.NEW_WEAPON:
			if player.weapon_controller.weapons.size() < max_weapon_slots():
				player.weapon_controller.add_weapon(option.target)
				_check_synergies()
		UpgradeOption.Kind.PASSIVE:
			var id: String = option.target.id
			passive_levels[id] = passive_levels.get(id, 0) + 1
			option.target.apply_per_level(player.stat_block, 1)
			player.on_stats_changed()
		UpgradeOption.Kind.HEAL:
			player.health.heal(player.health.max_hp * 0.3)
	EventBus.upgrade_applied.emit(option.title)
	_check_synergies()

func _weapon_name(id: String) -> String:
	for w in player.weapon_controller.weapons:
		if w.data.id == id:
			return w.data.display_name
	return id

## Human-readable tier-up description from actual stat deltas.
func _tier_description(w: WeaponInstance) -> String:
	var lvl: int = w.level  # option advances to level+1
	var idx: int = clampi(lvl - 1, 0, 4)
	var nxt: int = clampi(lvl, 0, 4)
	var parts: Array = []
	var dmg_mult: float = w.data.tier_damage_mult[nxt] / w.data.tier_damage_mult[idx]
	if dmg_mult > 1.01:
		parts.append("+%d%% damage" % int(round((dmg_mult - 1.0) * 100.0)))
	var proj_bonus: int = w.data.tier_projectile_bonus[nxt] - w.data.tier_projectile_bonus[idx]
	if proj_bonus > 0:
		parts.append("+%d projectile" % proj_bonus)
	var area_mult: float = w.data.tier_area_mult[nxt] / w.data.tier_area_mult[idx]
	if area_mult > 1.01:
		parts.append("+%d%% area" % int(round((area_mult - 1.0) * 100.0)))
	var cd_mult: float = w.data.tier_cooldown_mult[nxt] / w.data.tier_cooldown_mult[idx]
	if cd_mult < 0.99:
		parts.append("-%d%% cooldown" % int(round((1.0 - cd_mult) * 100.0)))
	if parts.is_empty():
		parts.append("stronger")
	return "Lv %d: %s" % [lvl + 1, " | ".join(parts)]

func _weapon_role(id: String) -> String:
	match id:
		"fireball": return "explosive AOE, burn synergy"
		"void_lance": return "piercing lance, slows on hit"
		"frost_bolt": return "homing chill bolt"
		"soul_fire": return "twin burning souls"
		"magic_missile": return "homing bolts, multi-target"
		"orbiting_shield": return "orbiting guards, melee range"
		"divine_spear": return "piercing line, high crit"
		"lightning": return "AOE strikes, detonates burning foes"
	return "auto-attack weapon"
