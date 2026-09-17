extends CharacterBody3D
## Third-person player: components drive movement, health, XP.
## Movement is camera-relative; the body rotates toward its velocity.

const CONTACT_INVINCIBILITY := 0.5

@onready var movement: Node = $MovementComponent
@onready var camera_rig: Node3D = $CameraRig
@onready var mesh: Node3D = $Mesh
@onready var hero: Node3D = $Mesh/HeroModel
@onready var health: Node = $HealthComponent
@onready var experience: Node = $ExperienceComponent
@onready var weapon_controller: Node = $WeaponController

var stat_block: StatBlock
var progression: Node = null  # set by Main
var combo: Node = null        # set by Main
var ability_controller: Node = null  # set by Main
var has_revive: bool = false

var _face_yaw: float = 0.0
var _base_hp: float = 100.0

func _ready() -> void:
	add_to_group("player")
	stat_block = StatBlock.new({"max_hp": _base_hp, "move_speed": 6.0, "pickup_radius": 3.0})
	movement.setup(self)
	_face_yaw = rotation.y
	camera_rig.set_target(self)
	health.setup(_base_hp)
	health.died.connect(_on_died)
	experience.leveled_up.connect(_on_leveled_up)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.xp_collected.connect(_on_xp_collected)

func bind_combat(enemy_manager: Node, projectile_root: Node3D) -> void:
	## Called by Main after both player and systems exist.
	weapon_controller.setup(self, enemy_manager, projectile_root)
	# Starting weapon: selected character's weapon (V13), default fireball
	var char_path := "res://data/characters/%s.tres" % GameManager.selected_character_id
	var weapon_id := "fireball"
	if ResourceLoader.exists(char_path):
		weapon_id = (load(char_path) as CharacterData).starting_weapon_id
	weapon_controller.add_weapon(load("res://data/weapons/%s.tres" % weapon_id))

func get_pickup_radius() -> float:
	return stat_block.get_stat("pickup_radius")

func get_stat(stat: String) -> float:
	return stat_block.get_stat(stat)

func on_stats_changed() -> void:
	## Re-apply derived stats after a modifier changed.
	var max_hp: float = stat_block.get_stat("max_hp")
	if max_hp > health.max_hp:
		health.heal(max_hp - health.max_hp)
	health.max_hp = max_hp
	movement.base_speed = stat_block.get_stat("move_speed")

func _on_xp_collected(amount: float) -> void:
	experience.add_xp(amount * stat_block.get_stat("xp_gain"))

func _physics_process(delta: float) -> void:
	if not health.is_alive():
		return
	var input_vec := InputManager.get_move_vector()
	var basis: Basis = camera_rig.get_move_basis()
	var dir := (basis * Vector3(input_vec.x, 0, input_vec.y))
	var move2 := Vector2(dir.x, dir.z)

	movement.tick(delta, move2)

	if move2.length_squared() > 0.04:
		var target_yaw := atan2(move2.x, move2.y)
		_face_yaw = lerp_angle(_face_yaw, target_yaw, 12.0 * delta)
	rotation.y = _face_yaw

	var speed: float = movement.get_current_speed()
	hero.animate(delta, speed)

## Called by enemies on contact attacks.
func take_contact_damage(amount: float, from_position: Vector3) -> void:
	if health.invincible_timer > 0.0 or not health.is_alive():
		return
	var event := DamageEvent.new(amount, "contact")
	health.take_damage(event)
	EventBus.player_damaged.emit(amount)
	# Knockback push away from the attacker
	var push := (global_position - from_position)
	push.y = 0.0
	if push.length() > 0.01:
		push = push.normalized() * 2.0
		velocity += push
	# Short invincibility window between contact hits
	health.set_invincible(CONTACT_INVINCIBILITY)
	camera_rig.add_shake(0.08)

func _on_enemy_died(enemy: Node, position: Vector3) -> void:
	RunManager.register_kill()
	# Kills grant gold directly (auto-collected) — meta Greed (gold_gain) applies
	if enemy.get("data") != null and enemy.data != null:
		var gold_mult: float = get_stat("gold_gain") if has_method("get_stat") else 1.0
		RunManager.add_gold(enemy.data.gold * enemy.gold_mult * gold_mult)
	var xp_mult: float = 1.0
	if combo != null:
		xp_mult = combo.get_multiplier()
	_drop_xp(enemy, position, xp_mult)

func _drop_xp(enemy: Node, position: Vector3, xp_mult: float = 1.0) -> void:
	var data: EnemyData = enemy.data
	if data == null:
		return
	var orb_scene := "res://scenes/pickups/XpOrb.tscn"
	var orb_count := 1
	if data.xp >= 10.0:
		orb_count = 3
	elif data.xp >= 3.0:
		orb_count = 2
	var per_orb: float = data.xp * xp_mult / orb_count
	for i in range(orb_count):
		var orb: Node3D = PoolManager.acquire(orb_scene)
		PoolManager.tag(orb, orb_scene)
		get_parent().add_child(orb)
		orb.setup(per_orb, self, position)
	# Heart drop — ANY enemy can drop (5%); early survival lifeline
	if randf() < 0.05:
		var heart := PoolManager.acquire("res://scenes/pickups/HeartPickup.tscn")
		PoolManager.tag(heart, "res://scenes/pickups/HeartPickup.tscn")
		get_parent().add_child(heart)
		heart.setup(25.0, self, position)
	# Magnet drop (2%) — collecting it vacuums every XP shard on the map
	if randf() < 0.02:
		var magnet := PoolManager.acquire("res://scenes/pickups/MagnetDrop.tscn")
		PoolManager.tag(magnet, "res://scenes/pickups/MagnetDrop.tscn")
		get_parent().add_child(magnet)
		magnet.setup(self, position)

func _on_leveled_up(new_level: int) -> void:
	# ProgressionManager handles pause + choice UI (supports stacked levels)
	if progression != null:
		progression.offer_choices()

func _on_died() -> void:
	if has_revive:
		has_revive = false
		health.reset()
		health.set_invincible(2.0)
		camera_rig.add_shake(0.3)
		return
	EventBus.player_died.emit()
	GameManager.game_over(false)

func grant_revive() -> void:
	has_revive = true

func is_player_alive() -> bool:
	return health.is_alive()
