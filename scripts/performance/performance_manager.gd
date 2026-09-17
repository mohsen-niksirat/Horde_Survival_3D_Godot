extends Node
## Performance budgets, quality tiers, horde stress, FPS helpers.
## First-run default is the LOWEST tier so browser load stays fast;
## players can raise graphics in Settings (Very Low → Ultra + Auto).

signal quality_changed(tier: int)

enum Quality { VERY_LOW, LOW, MEDIUM, HIGH, ULTRA }

## Settings OptionButton index for Auto (after 0..4 fixed tiers).
const QUALITY_AUTO_SETTING := 5
## Save schema version for quality values (old 0..3 → new 0..5).
const QUALITY_SCHEMA := 2

## Entity budgets per tier (native). Web multiplies further.
const ENEMY_CAPS := {
	Quality.VERY_LOW: 40,
	Quality.LOW: 70,
	Quality.MEDIUM: 110,
	Quality.HIGH: 160,
	Quality.ULTRA: 220,
}
const PROJECTILE_CAPS := {
	Quality.VERY_LOW: 40,
	Quality.LOW: 60,
	Quality.MEDIUM: 90,
	Quality.HIGH: 130,
	Quality.ULTRA: 180,
}
const PARTICLE_CAPS := {
	Quality.VERY_LOW: 25,
	Quality.LOW: 40,
	Quality.MEDIUM: 60,
	Quality.HIGH: 100,
	Quality.ULTRA: 140,
}
const DAMAGE_NUMBER_CAPS := {
	Quality.VERY_LOW: 12,
	Quality.LOW: 18,
	Quality.MEDIUM: 28,
	Quality.HIGH: 40,
	Quality.ULTRA: 50,
}

## Web WASM tax — keep caps tight except at the lowest tier (already low).
const WEB_ENEMY_CAP_SCALE := 0.65
const WEB_PROJECTILE_CAP_SCALE := 0.7
const WEB_PARTICLE_CAP_SCALE := 0.7
const WEB_DAMAGE_NUMBER_CAP_SCALE := 0.7

## Horde stress: when the arena is packed, temporarily shrink effective caps.
const STRESS_PRESSURE := 0.75
const STRESS_ENEMY_MIN := 45
const STRESS_FPS := 32
const STRESS_CAP_SCALE := 0.65

var quality: int = Quality.VERY_LOW
var auto_mode: bool = false
var stress_mode: bool = false
var _low_time: float = 0.0
var _high_time: float = 0.0
var _stress_low_time: float = 0.0

var active_enemies: int = 0
var active_projectiles: int = 0
var active_particles: int = 0

var _system_times: Dictionary = {}
var _sun_cache: Array = []
var _sun_cache_time: int = -10000
var _fog_cache: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var saved = SaveManager.get_setting("quality", -1)
	var scheme := int(SaveManager.get_setting("quality_schema", QUALITY_SCHEMA))
	var saved_i := int(saved)
	if scheme < QUALITY_SCHEMA:
		saved_i = _migrate_legacy_quality(saved_i)
	if saved_i == QUALITY_AUTO_SETTING:
		auto_mode = true
		quality = _default_quality()
	elif saved_i >= Quality.VERY_LOW and saved_i <= Quality.ULTRA:
		auto_mode = false
		quality = saved_i
	else:
		# First run: LOWEST tier for everyone — fast load, raise later if wanted.
		auto_mode = false
		quality = Quality.VERY_LOW
	quality_changed.emit(quality)
	_apply_render_settings()

func _migrate_legacy_quality(old_q: int) -> int:
	# Legacy: 0=LOW 1=MED 2=HIGH 3=Auto → new 1=LOW 2=MED 3=HIGH 5=Auto
	match old_q:
		0: return Quality.LOW
		1: return Quality.MEDIUM
		2: return Quality.HIGH
		3: return QUALITY_AUTO_SETTING
		_: return Quality.VERY_LOW

func _is_web() -> bool:
	return OS.get_name() == "Web"

func _is_touch() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

func _default_quality() -> int:
	# Lowest for everyone on first run / auto start.
	return Quality.VERY_LOW

func quality_name() -> String:
	var names: Array[String] = ["V.LOW", "LOW", "MED", "HIGH", "ULTRA"]
	var base: String = names[clampi(quality, 0, 4)]
	if auto_mode:
		return base + "+A"
	return base

func _apply_render_settings() -> void:
	var enable_shadows := quality >= Quality.HIGH or (quality == Quality.MEDIUM and not _is_web())
	for sun in _get_suns(true):
		if sun is DirectionalLight3D:
			sun.shadow_enabled = enable_shadows
	# Fog is free-ish but still fill-rate on weak GPUs
	var enable_fog := quality >= Quality.MEDIUM
	for env in _get_world_envs():
		if env is WorldEnvironment and env.environment != null:
			env.environment.fog_enabled = enable_fog
	var vp := get_viewport()
	if vp == null:
		return
	var msaa := RenderingServer.VIEWPORT_MSAA_2X if (quality >= Quality.HIGH and not _is_web()) else RenderingServer.VIEWPORT_MSAA_DISABLED
	RenderingServer.viewport_set_msaa_3d(vp.get_viewport_rid(), msaa)
	var scale := _render_scale()
	if scale < 1.0:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = scale
	else:
		vp.scaling_3d_scale = 1.0

func _render_scale() -> float:
	if _is_web():
		match quality:
			Quality.VERY_LOW: return 0.5
			Quality.LOW: return 0.6
			Quality.MEDIUM: return 0.75
			_: return 1.0
	match quality:
		Quality.VERY_LOW: return 0.75
		Quality.LOW: return 0.85
		_: return 1.0

func _get_suns(force: bool = false) -> Array:
	if not is_inside_tree():
		return _sun_cache
	var tree := get_tree()
	if tree == null or tree.root == null:
		return _sun_cache
	var now := Time.get_ticks_msec()
	if not force and not _sun_cache.is_empty() and now - _sun_cache_time < 2000:
		var valid: Array = []
		for s in _sun_cache:
			if is_instance_valid(s):
				valid.append(s)
		_sun_cache = valid
		if not valid.is_empty():
			return _sun_cache
	_sun_cache = tree.root.find_children("*", "DirectionalLight3D", true, false)
	_sun_cache_time = now
	return _sun_cache

func _get_world_envs() -> Array:
	if not is_inside_tree():
		return []
	var tree := get_tree()
	if tree == null or tree.root == null:
		return []
	_fog_cache = tree.root.find_children("*", "WorldEnvironment", true, false)
	return _fog_cache

func _process(delta: float) -> void:
	if auto_mode:
		_auto_tick(delta)
	_update_stress(delta)

## Called by EnemyManager whenever the live horde count changes.
func update_horde_pressure(enemy_count: int) -> void:
	active_enemies = enemy_count

func _update_stress(delta: float) -> void:
	var cap := enemy_cap()
	var pressure := float(active_enemies) / maxf(float(cap), 1.0)
	var fps := Engine.get_frames_per_second()
	var heavy := pressure >= STRESS_PRESSURE or (active_enemies >= STRESS_ENEMY_MIN and fps > 0 and fps < STRESS_FPS)
	if heavy:
		_stress_low_time += delta
		if _stress_low_time > 0.75:
			stress_mode = true
			# Nudge Auto down immediately when the horde is crushing FPS
			if auto_mode and quality > Quality.VERY_LOW and fps < STRESS_FPS:
				_low_time += delta * 2.0
	else:
		_stress_low_time = maxf(_stress_low_time - delta, 0.0)
		if _stress_low_time <= 0.0:
			stress_mode = false

func _auto_tick(delta: float, fps_override: int = -1) -> void:
	var fps := Engine.get_frames_per_second()
	if fps_override > 0:
		fps = fps_override
	# Stress/low FPS: step down faster. Web is harsher than desktop.
	var low_threshold := 32 if (_is_web() or stress_mode) else 26
	var low_hold := 0.75 if (_is_web() or stress_mode) else 4.0
	if fps < low_threshold:
		_low_time += delta
		_high_time = 0.0
		if _low_time > low_hold and quality > Quality.VERY_LOW:
			_low_time = 0.0
			set_quality(quality - 1, false)
	elif fps > 55 and not stress_mode:
		_high_time += delta
		_low_time = 0.0
		if _high_time > 20.0 and quality < Quality.ULTRA:
			_high_time = 0.0
			set_quality(quality + 1, false)
	else:
		_low_time = 0.0
		_high_time = 0.0

func set_quality(tier: int, save: bool = true) -> void:
	quality = clampi(tier, Quality.VERY_LOW, Quality.ULTRA)
	if save and not auto_mode:
		SaveManager.set_setting("quality", quality)
		SaveManager.set_setting("quality_schema", QUALITY_SCHEMA)
	quality_changed.emit(quality)
	_apply_render_settings()

func set_auto_mode(enabled: bool, save: bool = true) -> void:
	auto_mode = enabled
	_low_time = 0.0
	_high_time = 0.0
	if save:
		if enabled:
			SaveManager.set_setting("quality", QUALITY_AUTO_SETTING)
		else:
			SaveManager.set_setting("quality", quality)
		SaveManager.set_setting("quality_schema", QUALITY_SCHEMA)

func prefer_dynamic_lights() -> bool:
	if _is_web():
		return quality >= Quality.ULTRA
	return quality >= Quality.HIGH

func enemy_cap() -> int:
	var cap: int = ENEMY_CAPS.get(quality, 40)
	if _is_web() and quality > Quality.VERY_LOW:
		cap = maxi(25, int(cap * WEB_ENEMY_CAP_SCALE))
	return cap

## Cap used by spawners — shrinks under horde stress so the sim stays alive.
func effective_enemy_cap() -> int:
	var cap := enemy_cap()
	if stress_mode:
		cap = maxi(20, int(cap * STRESS_CAP_SCALE))
	return cap

func projectile_cap() -> int:
	var cap: int = PROJECTILE_CAPS.get(quality, 40)
	if _is_web() and quality > Quality.VERY_LOW:
		cap = maxi(20, int(cap * WEB_PROJECTILE_CAP_SCALE))
	if stress_mode:
		cap = maxi(15, int(cap * 0.7))
	return cap

func particle_cap() -> int:
	var cap: int = PARTICLE_CAPS.get(quality, 25)
	if _is_web() and quality > Quality.VERY_LOW:
		cap = maxi(12, int(cap * WEB_PARTICLE_CAP_SCALE))
	return cap

func damage_number_cap() -> int:
	var cap: int = DAMAGE_NUMBER_CAPS.get(quality, 12)
	if _is_web() and quality > Quality.VERY_LOW:
		cap = maxi(8, int(cap * WEB_DAMAGE_NUMBER_CAP_SCALE))
	if stress_mode:
		cap = maxi(6, int(cap * 0.5))
	return cap

## True when far enemies should skip full physics this tick (horde LOD).
func should_throttle_enemy_ai() -> bool:
	return stress_mode or quality <= Quality.LOW

func report_system_time(name: String, elapsed_usec: int) -> void:
	if not _system_times.has(name):
		_system_times[name] = {"total": 0, "frames": 0}
	var stat: Dictionary = _system_times[name]
	stat["total"] += elapsed_usec
	stat["frames"] += 1
	if stat["frames"] >= 10:
		stat["total"] = int(stat["total"] / float(stat["frames"]))
		stat["frames"] = 1

func get_system_avg_ms(name: String) -> float:
	if not _system_times.has(name):
		return 0.0
	var stat: Dictionary = _system_times[name]
	if stat["frames"] == 0:
		return 0.0
	return stat["total"] / float(stat["frames"]) / 1000.0

func get_debug_info() -> String:
	var lines: Array[String] = []
	var mode := "AUTO" if auto_mode else "FIXED"
	if stress_mode:
		mode += "+STRESS"
	lines.append("FPS: %d | frame: %.2f ms | physics: %.2f ms | Q:%s %s" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		quality_name(),
		mode,
	])
	lines.append("draw calls: %d | primitives: %dk | objects: %d " % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		Performance.get_monitor(Performance.OBJECT_COUNT),
	])
	lines.append("enemies: %d/%d | projectiles: %d | particles: %d" % [
		active_enemies, effective_enemy_cap(), active_projectiles, active_particles,
	])
	var sys_lines: Array[String] = []
	for name in _system_times:
		sys_lines.append("%s: %.2f ms" % [name, get_system_avg_ms(name)])
	if not sys_lines.is_empty():
		lines.append(" | ".join(sys_lines))
	return "\n".join(lines)
