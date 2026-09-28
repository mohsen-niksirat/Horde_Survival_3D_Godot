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

## V15A telegraph colors: phase-coded so the player reads threat level at a glance.
const TELEGRAPH_COLORS := {
	BossPhase.ONE: Color(1.0, 0.55, 0.15, 0.85),
	BossPhase.TWO: Color(1.0, 0.35, 0.1, 0.9),
	BossPhase.ENRAGE: Color(1.0, 0.12, 0.08, 0.95),
}

const BOSS_RIG := "res://assets/models/kaykit/monsters/skeleton_warrior.glb"
const BOSS_HEIGHT := 5.6

@onready var health: Node = $HealthComponent
@onready var mesh: MeshInstance3D = $Mesh

var player: Node3D
var enemy_manager: Node
var arena: Node3D
var phase: int = BossPhase.ONE
var alive: bool = true
var _rig: Node3D = null

var _slam_timer: float = 4.0
var _fan_timer: float = 5.0
var _summon_timer: float = 8.0
var _telegraph: MeshInstance3D
var _telegraph_active: bool = false
var _telegraph_pos: Vector3
var _telegraph_mat: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	health.died.connect(_on_died)
	_telegraph = $Telegraph
	_telegraph.visible = false
	_cache_telegraph_mat()
	_attach_rig()

func _cache_telegraph_mat() -> void:
	var ring := _telegraph.get_node_or_null("TelegraphRing")
	if ring == null:
		return
	var mat := ring.get_active_material(0) as StandardMaterial3D
	if mat != null:
		_telegraph_mat = mat

## Swap the primitive sphere stack for a giant animated skeleton.
func _attach_rig() -> void:
	if not ResourceLoader.exists(BOSS_RIG):
		return
	_rig = RigUtil.attach_glb(self, BOSS_RIG, BOSS_HEIGHT, "BossRig")
	if _rig == null:
		return
	_rig.rotation.y = RigUtil.RIG_YAW
	mesh.visible = false
	for c in mesh.get_children():
		c.visible = false
	_apply_phase_tint()

func _apply_phase_tint() -> void:
	if _rig == null:
		return
	var tint := Color(0.55, 0.4, 0.8)
	match phase:
		BossPhase.TWO: tint = Color(0.35, 0.7, 1.0)
		BossPhase.ENRAGE: tint = Color(1.0, 0.3, 0.15)
	for mi in _rig.find_children("*", "MeshInstance3D", true, false):
		var active = mi.get_active_material(0)
		if active is StandardMaterial3D:
			var m: StandardMaterial3D = (active as StandardMaterial3D).duplicate()
			m.albedo_color = m.albedo_color * tint
			if phase == BossPhase.ENRAGE:
				m.emission_enabled = true
				m.emission = Color(1.0, 0.25, 0.1)
				m.emission_energy_multiplier = 0.6
			mi.set_surface_override_material(0, m)

func setup(p_player: Node3D, p_enemy_manager: Node, p_arena: Node3D, level_scale: float) -> void:
	player = p_player
	enemy_manager = p_enemy_manager
	arena = p_arena
	health.set_scaled(600.0, 4.0, level_scale)
	alive = true
	phase = BossPhase.ONE
	_slam_timer = 3.0
	# V15B: entrance — drop in oversized then settle (imposing first frame)
	var target := Vector3.ONE
	scale = target * 1.35
	var tw := create_tween()
	tw.tween_property(self, "scale", target, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
		var charge := 1.0 - (_slam_timer / SLAM_TELEGRAPH)
		_telegraph.scale = Vector3.ONE * (1.0 + charge * 0.5)
		if _telegraph_mat != null:
			# Pulse brighter as impact approaches
			_telegraph_mat.emission_energy_multiplier = 1.6 + charge * 2.2
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

	if _rig != null:
		RigUtil.play_locomotion(_rig, Vector2(velocity.x, velocity.z).length())
	_tick_attacks(delta, dist)

func _update_phase() -> void:
	var ratio: float = health.get_ratio()
	if ratio < 0.3 and phase != BossPhase.ENRAGE:
		phase = BossPhase.ENRAGE
		_apply_phase_tint()
		_announce_phase("ENRAGE")
		EventBus.boss_spawned.emit(self)  # reuse as intensity signal
	elif ratio < 0.6 and phase == BossPhase.ONE:
		phase = BossPhase.TWO
		_apply_phase_tint()
		_announce_phase("PHASE 2")

## V15B: phase-transition flash + camera punch so the shift is felt.
func _announce_phase(phase_name: String) -> void:
	var color: Color = TELEGRAPH_COLORS.get(phase, TELEGRAPH_COLORS[BossPhase.ONE])
	EventBus.boss_phase_changed.emit(phase_name, color)
	var cam := get_viewport().get_camera_3d()
	var rig := cam.get_parent().get_parent() if cam != null else null
	if rig != null and rig.has_method("add_shake"):
		rig.add_shake(0.28)

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
	_apply_telegraph_color()
	# Loud audio cue so the player knows to move even mid-horde
	AudioManager.play_game_sfx("boss_warn")

func _apply_telegraph_color() -> void:
	if _telegraph_mat == null:
		return
	var base: Color = TELEGRAPH_COLORS.get(phase, TELEGRAPH_COLORS[BossPhase.ONE])
	_telegraph_mat.albedo_color = base
	_telegraph_mat.emission = Color(base.r, base.g, base.b, 1.0)
	_telegraph_mat.emission_energy_multiplier = 1.6

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
	var container: Node = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_parent()
	container.add_child(proj)
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
	# V15B victory moment: gold flash + camera punch at the kill
	EventBus.boss_phase_changed.emit("VICTORY", Color(1.0, 0.9, 0.35, 0.55))
	var cam := get_viewport().get_camera_3d()
	var rig := cam.get_parent().get_parent() if cam != null else null
	if rig != null and rig.has_method("add_shake"):
		rig.add_shake(0.45)
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
