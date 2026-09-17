extends CharacterBody3D
## Horde enemy: chase steering, contact damage, death → XP drop.
## Spawned/recycled through PoolManager. Driven by EnemyData resource.

signal died(enemy: Node)

const EnemyVisuals := preload("res://scenes/enemies/enemy_visuals.gd")

const GRAVITY := 25.0

var data: EnemyData
var health: Node
var status: Node
var elite: Node = null
var hp_scale: float = 1.0
var dmg_scale: float = 1.0
var spd_scale: float = 1.0
var base_spd_scale: float = 1.0
var xp_mult: float = 1.0
var gold_mult: float = 1.0
var dmg_mult: float = 1.0

var _player: Node3D
var _attack_timer: float = 0.0
var _wobble_seed: float = 0.0
var _alive: bool = false
var _mesh: Node3D
var _flash_materials: Array = []
var _ranged_timer: float = 2.0
var _heal_timer: float = 2.0
var _phase_timer: float = 0.0
var _split_done: bool = false
var _active_tweens: Array = []
var _last_phasing: bool = false

func _ready() -> void:
	add_to_group("enemies")
	health = $HealthComponent
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	status = $StatusComponent
	status.setup(self)
	_mesh = $Visual

func _on_damaged(event: DamageEvent) -> void:
	# Apply status from the damage pipeline
	if event.status_effect != "":
		status.apply(event.status_effect, event.status_duration)
	_hit_flash()

func _hit_flash() -> void:
	# Flash all archetype part materials white briefly
	var was_phasing := _is_phasing()
	for mi in _flash_materials:
		if is_instance_valid(mi):
			mi.albedo_color = Color(3, 3, 3)
			var restore: Color = mi.get_meta("base_color")
			if was_phasing:
				restore.a = 0.35
			var tween := _track_tween(create_tween())
			tween.tween_property(mi, "albedo_color", restore, 0.12)

func setup(p_data: EnemyData, p_player: Node3D, p_hp_scale: float, p_dmg_scale: float, p_spd_scale: float) -> void:
	data = p_data
	_player = p_player
	hp_scale = p_hp_scale
	dmg_scale = p_dmg_scale
	spd_scale = p_spd_scale
	base_spd_scale = p_spd_scale
	xp_mult = 1.0
	gold_mult = 1.0
	dmg_mult = 1.0
	_wobble_seed = randf() * TAU

	# Reset pooled state from a previous life
	_kill_tweens()
	_clear_elite_ring()
	elite = null
	health.damage_interceptor = Callable()
	status.clear_all()

	health.set_scaled(data.max_hp, data.armor, hp_scale)
	# Build the archetype-specific model (rebuilds only if archetype changed)
	EnemyVisuals.build(_mesh, data.id)
	_collect_flash_materials()
	var s: float = (1.15 if hp_scale >= 3.0 else 1.0)
	# V11A: fade/scale in — softens spawn pop-in
	var target_scale := Vector3(s, s, s)
	_mesh.scale = target_scale * 0.25
	var tween := _track_tween(create_tween())
	tween.tween_property(_mesh, "scale", target_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_attack_timer = randf_range(0.0, data.attack_cooldown)
	_ranged_timer = randf_range(0.5, data.ranged_cooldown if data.ranged_attack else 2.5)
	_heal_timer = data.heal_cooldown
	_phase_timer = data.phase_interval
	_split_done = false
	_alive = true
	_last_phasing = false

## Cache the part materials for hit flashes; elites get a gold tint.
func _collect_flash_materials() -> void:
	_flash_materials.clear()
	for part in _mesh.get_children():
		if part is MeshInstance3D:
			# Duplicate shared cache mats so elite tint / hit flash stay per-instance
			var mat: StandardMaterial3D = EnemyVisuals.ensure_unique_material(part)
			if mat == null:
				continue
			if elite != null:
				mat.albedo_color = Color(1.0, 0.8, 0.2)
			mat.set_meta("base_color", mat.albedo_color)
			_flash_materials.append(mat)

## Promote this enemy to an elite with the given abilities.
func make_elite(p_abilities: Array) -> void:
	if elite != null:
		return
	_clear_elite_ring()
	health.set_scaled(data.max_hp, data.armor, hp_scale * 3.0)
	dmg_mult = 2.0
	xp_mult = 10.0
	gold_mult = 5.0
	_mesh.scale *= 1.3
	# Golden tint for elite identity
	for mi in _flash_materials:
		if is_instance_valid(mi):
			mi.albedo_color = Color(1.0, 0.8, 0.2)
			mi.set_meta("base_color", Color(1.0, 0.8, 0.2))
	# V15A: glowing ground ring so elites read instantly in hordes
	var ring := MeshInstance3D.new()
	ring.name = "EliteRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.05
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.8, 0.2, 0.85)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.75, 0.15, 1)
	ring_mat.emission_energy_multiplier = 1.6
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_mat
	ring.position = Vector3(0, 0.06, 0)
	ring.scale = Vector3(1.2, 1.0, 1.2)
	add_child(ring)
	elite = $EliteComponent
	elite.setup(self, _player, get_parent().get_parent().get_enemy_manager() if get_parent().get_parent().has_method("get_enemy_manager") else get_parent().get_parent(), p_abilities)

func _physics_process(delta: float) -> void:
	if not _alive or _player == null or not is_instance_valid(_player):
		return
	var _start := Time.get_ticks_usec()

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if dist > 0.01:
		var dir := to_player / dist
		# Movement behavior variants
		match data.movement_type:
			"wobble":
				var wobble := Vector3.UP.cross(dir).normalized()
				dir = (dir + wobble * sin(Time.get_ticks_msec() / 1000.0 * 8.0 + _wobble_seed) * 0.4).normalized()
			"sine":
				var sway := Vector3.UP.cross(dir).normalized()
				dir = (dir + sway * sin(Time.get_ticks_msec() / 1000.0 * 3.0 + _wobble_seed) * 0.3).normalized()
			"stationary":
				dir = Vector3.ZERO
			"kite":
				# Keep mid range: flee when close, approach when far
				if dist < 10.0:
					dir = -dir
				elif dist > 16.0:
					pass  # keep approaching
				else:
					var strafe := Vector3.UP.cross(dir).normalized()
					dir = strafe * (1.0 if _wobble_seed > PI else -1.0)

		# No enemy may outrun the player (player base 6 m/s)
		var speed: float = minf(data.move_speed * spd_scale * status.get_speed_factor(), 5.5)
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		move_and_slide()

		# Face player
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 8.0 * delta)

	# Contact attack
	_attack_timer -= delta
	if dist <= data.attack_range * 1.5 and _attack_timer <= 0.0:
		_attack_timer = data.attack_cooldown
		if _player.has_method("take_contact_damage"):
			_player.take_contact_damage(data.damage * dmg_scale * dmg_mult, global_position)
			if elite != null:
				elite.on_hit_player()

	# Ranged volley (mage archetype)
	if data.ranged_attack:
		_ranged_timer -= delta
		if _ranged_timer <= 0.0 and dist < 18.0:
			_ranged_timer = data.ranged_cooldown
			_fire_volley()

	# Healer aura
	if data.heal_radius > 0.0:
		_heal_timer -= delta
		if _heal_timer <= 0.0:
			_heal_timer = data.heal_cooldown
			_heal_allies()

	# Ghost phasing — only touch materials when the archetype can phase
	if data.phase_interval > 0.0:
		_phase_timer -= delta
		if _phase_timer <= -data.phase_duration:
			_phase_timer = data.phase_interval
		var phasing := _is_phasing()
		if phasing != _last_phasing:
			_last_phasing = phasing
			_set_phasing_alpha(phasing)
	# Overlay system time only when debug overlay is cheap enough (skip far LOD)
	if dist < 32.0:
		PerformanceManager.report_system_time("enemy_ai", Time.get_ticks_usec() - _start)
	# Archetype micro-animation LOD — far enemies skip per-frame anim
	if dist < 28.0:
		EnemyVisuals.animate(_mesh, data.id, Time.get_ticks_msec() / 1000.0, _wobble_seed)

## Ghost phasing: periodically untargetable.
func _is_phasing() -> bool:
	return data.phase_interval > 0.0 and _phase_timer <= 0.0

## Visual shimmer: dial part material alphas while phasing.
func _set_phasing_alpha(phasing: bool) -> void:
	var target_a := 0.35 if phasing else 1.0
	for mi in _flash_materials:
		if is_instance_valid(mi):
			var c: Color = mi.get_meta("base_color")
			c.a = target_a
			mi.albedo_color = c

func _fire_volley() -> void:
	var proj := PoolManager.acquire("res://scenes/weapons/BossProjectile.tscn")
	PoolManager.tag(proj, "res://scenes/weapons/BossProjectile.tscn")
	# Attach under the Projectiles container when available for tidy stats
	var container: Node = get_parent()
	var proj_container: Node3D = container.get_node_or_null("Projectiles")
	if proj_container != null:
		proj_container.add_child(proj)
	else:
		container.add_child(proj)
	var dir := (_player.global_position - global_position).normalized()
	proj.setup(global_position + Vector3(0, 1.0, 0), dir, data.ranged_damage * dmg_scale, _player)

func _heal_allies() -> void:
	var em: Node = get_tree().get_first_node_in_group("enemy_manager")
	if em == null:
		return
	var heal_r2 := data.heal_radius * data.heal_radius
	for ally in em.active_enemies:
		if not is_instance_valid(ally) or ally == self:
			continue
		if ally.is_in_group("boss"):
			continue
		if ally.get("health") == null or not ally.health.is_alive():
			continue
		if ally.global_position.distance_squared_to(global_position) <= heal_r2:
			ally.health.heal(ally.health.max_hp * data.heal_pct)

func get_health_ratio() -> float:
	return health.get_ratio()

func is_enemy_alive() -> bool:
	return _alive and health.is_alive()

func _on_died() -> void:
	if not _alive:
		return
	_alive = false
	if elite != null:
		elite.on_death()
	# Splitter behavior: leave copies behind (pooled, once per life)
	if data != null and data.splits_into != "" and not _split_done:
		_split_done = true
		var child_data: EnemyData = load("res://data/enemies/%s.tres" % data.splits_into)
		if child_data != null:
			for i in range(data.split_count):
				var offset := Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
				var em: Node = get_tree().get_first_node_in_group("enemy_manager")
				if em != null:
					em.queue_spawn(child_data, global_position + offset, _player, hp_scale * 0.5, dmg_scale, spd_scale)
	EventBus.enemy_died.emit(self, global_position)
	died.emit(self)
	# Death shrink effect happens while the pooled node leaves the tree
	if _mesh != null:
		var tween := _track_tween(create_tween())
		tween.tween_property(_mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.18)
		tween.tween_callback(func():
			if is_instance_valid(_mesh):
				_mesh.scale = Vector3.ONE)

## Called by the pool manager flow (or spawner) when recycled.
func despawn() -> void:
	_alive = false
	velocity = Vector3.ZERO
	_kill_tweens()
	_clear_elite_ring()
	elite = null

func _track_tween(tween: Tween) -> Tween:
	if tween != null:
		_active_tweens.append(tween)
	return tween

func _kill_tweens() -> void:
	for t in _active_tweens:
		if t != null and t.is_valid():
			t.kill()
	_active_tweens.clear()

func _clear_elite_ring() -> void:
	var ring := get_node_or_null("EliteRing")
	if ring != null:
		ring.queue_free()
