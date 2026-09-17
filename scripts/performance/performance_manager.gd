extends Node
## Performance budgets and quality tiers. Owns entity/particle caps,
## dynamic degradation decisions, and the profiling stats shown in the
## F3 debug overlay.

signal quality_changed(tier: int)

enum Quality { LOW, MEDIUM, HIGH }

## Auto is stored in SaveManager settings as quality == 3
const QUALITY_AUTO_SETTING := 3

## Entity budgets per quality tier (desktop/editor).
const ENEMY_CAPS := {Quality.LOW: 100, Quality.MEDIUM: 160, Quality.HIGH: 240}
const PROJECTILE_CAPS := {Quality.LOW: 80, Quality.MEDIUM: 120, Quality.HIGH: 180}
const PARTICLE_CAPS := {Quality.LOW: 50, Quality.MEDIUM: 90, Quality.HIGH: 140}
const DAMAGE_NUMBER_CAPS := {Quality.LOW: 20, Quality.MEDIUM: 30, Quality.HIGH: 40}

## Browser runs pay a much higher WASM/WebGL tax — scale caps down.
const WEB_ENEMY_CAP_SCALE := 0.55
const WEB_PROJECTILE_CAP_SCALE := 0.7
const WEB_PARTICLE_CAP_SCALE := 0.7
const WEB_DAMAGE_NUMBER_CAP_SCALE := 0.7

var quality: int = Quality.MEDIUM
## AUTO mode — watches FPS and steps the tier down/up automatically.
var auto_mode: bool = false
var _low_time: float = 0.0
var _high_time: float = 0.0

## Live counters (updated by spawners/pools each frame or on change).
var active_enemies: int = 0
var active_projectiles: int = 0
var active_particles: int = 0

## Per-system frame-time rolling stats (milliseconds, ~10-frame average).
var _system_times: Dictionary = {}   # name -> {total, frames}
var _sun_cache: Array = []
var _sun_cache_time: int = -10000

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var saved = SaveManager.get_setting("quality", -1)
	var saved_i := int(saved)
	if saved_i == QUALITY_AUTO_SETTING:
		auto_mode = true
		quality = _default_quality()
	elif saved_i >= Quality.LOW and saved_i <= Quality.HIGH:
		auto_mode = false
		quality = saved_i
	else:
		# First run / unset: web & touch start MEDIUM; desktop HIGH.
		# Web also enables AUTO so weak GPUs degrade instead of freezing.
		auto_mode = _is_web()
		quality = _default_quality()
	quality_changed.emit(quality)
	_apply_render_settings()

func _is_web() -> bool:
	return OS.get_name() == "Web"

func _is_touch() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

func _default_quality() -> int:
	if _is_web() or _is_touch():
		return Quality.MEDIUM
	return Quality.HIGH

## Shadows/MSAA/fog are applied only when quality changes (not every frame).
func _apply_render_settings() -> void:
	var enable_shadows := quality == Quality.HIGH or (quality == Quality.MEDIUM and not _is_web())
	for sun in _get_suns(true):
		if sun is DirectionalLight3D:
			sun.shadow_enabled = enable_shadows
	# MSAA is expensive on WebGL2 — keep off unless HIGH native
	var vp := get_viewport()
	if vp == null:
		return
	var msaa := RenderingServer.VIEWPORT_MSAA_2X if (quality == Quality.HIGH and not _is_web()) else RenderingServer.VIEWPORT_MSAA_DISABLED
	RenderingServer.viewport_set_msaa_3d(vp.get_viewport_rid(), msaa)

func _get_suns(force: bool = false) -> Array:
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

func _process(delta: float) -> void:
	if auto_mode:
		_auto_tick(delta)

## AUTO: sustained low FPS steps down; sustained high FPS recovers.
## Web uses a faster step-down (1s < 30 FPS) because WASM hitches are harsher.
func _auto_tick(delta: float, fps_override: int = -1) -> void:
	var fps := Engine.get_frames_per_second()
	if fps_override > 0:
		fps = fps_override
	var low_threshold := 30 if _is_web() else 26
	var low_hold := 1.0 if _is_web() else 4.0
	if fps < low_threshold:
		_low_time += delta
		_high_time = 0.0
		if _low_time > low_hold and quality > Quality.LOW:
			_low_time = 0.0
			set_quality(quality - 1, false)
	elif fps > 55:
		_high_time += delta
		_low_time = 0.0
		if _high_time > 20.0 and quality < Quality.HIGH:
			_high_time = 0.0
			set_quality(quality + 1, false)
	else:
		_low_time = 0.0
		_high_time = 0.0

func set_quality(tier: int, save: bool = true) -> void:
	quality = clampi(tier, Quality.LOW, Quality.HIGH)
	if save and not auto_mode:
		# Do not overwrite Auto preference when auto-stepping
		SaveManager.set_setting("quality", quality)
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

func prefer_dynamic_lights() -> bool:
	# Dynamic OmniLights are hostile to WebGL Compatibility
	if _is_web():
		return quality >= Quality.HIGH
	return quality >= Quality.MEDIUM

func enemy_cap() -> int:
	var cap: int = ENEMY_CAPS[quality]
	if _is_web():
		cap = maxi(40, int(cap * WEB_ENEMY_CAP_SCALE))
	return cap

func projectile_cap() -> int:
	var cap: int = PROJECTILE_CAPS[quality]
	if _is_web():
		cap = maxi(30, int(cap * WEB_PROJECTILE_CAP_SCALE))
	return cap

func particle_cap() -> int:
	var cap: int = PARTICLE_CAPS[quality]
	if _is_web():
		cap = maxi(20, int(cap * WEB_PARTICLE_CAP_SCALE))
	return cap

func damage_number_cap() -> int:
	var cap: int = DAMAGE_NUMBER_CAPS[quality]
	if _is_web():
		cap = maxi(12, int(cap * WEB_DAMAGE_NUMBER_CAP_SCALE))
	return cap

## Add one frame's elapsed microseconds for a named system.
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

## Debug overlay data (multi-line; F3 toggles it).
func get_debug_info() -> String:
	var lines: Array[String] = []
	var mode := "AUTO" if auto_mode else "FIXED"
	lines.append("FPS: %d | frame: %.2f ms | physics: %.2f ms | Q:%s %s" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		["LOW","MED","HIGH"][quality],
		mode,
	])
	lines.append("draw calls: %d | primitives: %dk | objects: %d " % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		Performance.get_monitor(Performance.OBJECT_COUNT),
	])
	lines.append("enemies: %d | projectiles: %d | particles: %d" % [
		active_enemies, active_projectiles, active_particles,
	])
	var sys_lines: Array[String] = []
	for name in _system_times:
		sys_lines.append("%s: %.2f ms" % [name, get_system_avg_ms(name)])
	if not sys_lines.is_empty():
		lines.append(" | ".join(sys_lines))
	return "\n".join(lines)
