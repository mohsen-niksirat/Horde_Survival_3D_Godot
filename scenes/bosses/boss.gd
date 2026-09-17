extends CharacterBody3D
## THE MVP boss: one complete fight.
## Phase 1 (>60% HP): chase + telegraphed ground slam AOE.
## Phase 2 (30-60%): adds radial projectile fan + minion summons.
## Enrage (<30%): faster, bigger slams, tighter fan cadence.
## Death: XP burst + reward drops.

signal boss_died()

enum BossPhase { ONE, TWO, ENRAGE }

const GRAVITY := 25.0
const SLAM_TELEGRAPH := 1.1
const SLAM_RADIUS := 5.0

@onready var health: Node = $HealthComponent
@onready var mesh: MeshInstance3D = $Mesh

var player: Node3D
var enemy_manager: Node
var arena: Node3D
var phase: int = BossPhase.ONE
var alive: bool = true

var _slam_timer: float = 4.0
var _fan_timer: float = 5.0
var _summon_timer: float = 8.0
var _telegraph: MeshInstance3D
var _telegraph_active: bool = false
var _telegraph_pos: Vector3

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	health.died.connect(_on_died)
	_telegraph = $Telegraph
	_telegraph.visible = false

func setup(p_player: Node3D, p_enemy_manager: Node, p_arena: Node3D, level_scale: float) -> void:
	player = p_player
	enemy_manager = p_enemy_manager
	arena = p_arena
	health.set_scaled(600.0, 4.0, level_scale)
	alive = true
	phase = BossPhase.ONE
	_slam_timer = 3.0

func get_health_ratio() -> float:
	return health.get_ratio()

func is_enemy_alive() -> bool:
	return alive

func _physics_process(delta: float) -> void:
	if not alive or player == null or not is_instance_valid(player):
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	_update_phase()

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	# Telegraphed slam in progress?
	if _telegraph_active:
		_telegraph.scale = Vector3.ONE * (1.0 + (1.0 - _slam_timer / SLAM_TELEGRAPH) * 0.5)
		if _slam_timer <= 0.0:
			_execute_slam()
		move_and_slide()
		return

	var base_speed := 2.2
	match phase:
		BossPhase.TWO: base_speed = 2.6
		BossPhase.ENRAGE: base_speed = 3.4

	if dist > 2.2:
		var dir := to_player.normalized()
		velocity.x = dir.x * base_speed
		velocity.z = dir.z * base_speed
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 6.0 * delta)
		move_and_slide()

	_tick_attacks(delta, dist)

func _update_phase() -> void:
	var ratio: float = health.get_ratio()
	if ratio < 0.3 and phase != BossPhase.ENRAGE:
		phase = BossPhase.ENRAGE
		EventBus.boss_spawned.emit(self)  # reuse as intensity signal
	elif ratio < 0.6 and phase == BossPhase.ONE:
		phase = BossPhase.TWO

func _tick_attacks(delta: float, dist: float) -> void:
	# Ground slam (all phases, faster in enrage)
	_slam_timer -= delta
	if _slam_timer <= 0.0 and dist < 9.0:
		_start_slam()
		return

	# Radial projectile fan (phase 2+)
	if phase >= BossPhase.TWO:
		_fan_timer -= delta
		if _fan_timer <= 0.0:
			_fan_timer = 4.0 if phase == BossPhase.TWO else 2.5
			_fire_fan()

	# Minion summons (phase 2+)
	if phase >= BossPhase.TWO:
		_summon_timer -= delta
		if _summon_timer <= 0.0:
			_summon_timer = 10.0 if phase == BossPhase.TWO else 7.0
			_summon_minions()

func _start_slam() -> void:
	_slam_timer = SLAM_TELEGRAPH
	_telegraph_active = true
	_telegraph_pos = player.global_position
	_telegraph.global_position = Vector3(_telegraph_pos.x, 0.06, _telegraph_pos.z)
	_telegraph.visible = true
	# Loud audio cue so the player knows to move even mid-horde
	AudioManager.play_game_sfx("boss_warn")

func _execute_slam() -> void:
	_telegraph_active = false
	_telegraph.visible = false
	_slam_timer = 5.0 if phase == BossPhase.ENRAGE else 7.0
	# Damage player if still inside radius
	if player.global_position.distance_to(_telegraph_pos) <= SLAM_RADIUS:
		player.take_contact_damage(30.0, _telegraph_pos)
	# Camera feedback
	var cam := get_viewport().get_camera_3d()
	var rig := cam.get_parent().get_parent() if cam != null else null
	if rig != null and rig.has_method("add_shake"):
		rig.add_shake(0.35)

func _fire_fan() -> void:
	# Radial projectiles (simple pooled spheres via EnemyManager projectiles)
	var count := 10 if phase == BossPhase.ENRAGE else 8
	for i in range(count):
		var angle := TAU * i / count
		var dir := Vector3(cos(angle), 0, sin(angle))
		_spawn_boss_projectile(dir)

func _spawn_boss_projectile(dir: Vector3) -> void:
	var proj := PoolManager.acquire("res://scenes/weapons/BossProjectile.tscn")
	PoolManager.tag(proj, "res://scenes/weapons/BossProjectile.tscn")
	get_parent().add_child(proj)
	proj.setup(global_position + Vector3(0, 1.5, 0), dir, 14.0, player)

func _summon_minions() -> void:
	var drone: EnemyData = load("res://data/enemies/swarm_bat.tres")
	var count := 5 if phase == BossPhase.ENRAGE else 3
	for i in range(count):
		var angle := randf() * TAU
		var pos := global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(3.0, 5.0)
		pos.x = clampf(pos.x, -58, 58)
		pos.z = clampf(pos.z, -58, 58)
		enemy_manager.queue_spawn(drone, pos, player, 1.0, 1.0, 1.0)

func _on_died() -> void:
	if not alive:
		return
	alive = false
	EventBus.boss_died.emit()
	boss_died.emit()
	# Rewards: big XP burst
	for i in range(12):
		var orb := PoolManager.acquire("res://scenes/pickups/XpOrb.tscn")
		PoolManager.tag(orb, "res://scenes/pickups/XpOrb.tscn")
		get_parent().add_child(orb)
		var angle := TAU * i / 12.0
		orb.setup(4.0, player, global_position + Vector3(cos(angle), 0, sin(angle)) * 2.0)
	# Free the boss body — endless respawns must not stack corpses
	set_physics_process(false)
	queue_free()
