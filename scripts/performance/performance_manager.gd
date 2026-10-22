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
const WEB_MEDIUM_ENEMY_CAP_SCALE := 0.45
const WEB_PROJECTILE_CAP_SCALE := 0.7
const WEB_MEDIUM_PROJECTILE_CAP_SCALE := 0.5
const WEB_PARTICLE_CAP_SCALE := 0.7
const WEB_MEDIUM_PARTICLE_CAP_SCALE := 0.5
const WEB_DAMAGE_NUMBER_CAP_SCALE := 0.7
## Native mobile (Android/iOS) is also GPU-bound — use the same tight web caps.
const TOUCH_ENEMY_CAP_SCALE := 0.65
const TOUCH_PROJECTILE_CAP_SCALE := 0.7
const TOUCH_PARTICLE_CAP_SCALE := 0.7
const TOUCH_DAMAGE_NUMBER_CAP_SCALE := 0.7

## Horde stress: when the arena is packed, temporarily shrink effective caps.
const STRESS_PRESSURE := 0.75
const STRESS_ENEMY_MIN := 45
const STRESS_FPS := 32
const STRESS_CAP_SCALE := 0.65
## V15A: at 150+ active enemies the screen is already noisy — clamp damage numbers hard.
const DAMAGE_NUMBER_HEAVY_ENEMIES := 150
const DAMAGE_NUMBER_HEAVY_SCALE := 0.4

## V30A: dynamic resolution — trade pixels for frame rate on weak GPUs.
## The tier scale is the ceiling; this ladder only ever lowers it, and it
## reverts automatically when dropping pixels does not improve FPS (CPU-bound).
const DYN_STEP := 0.08
const DYN_MIN_SCALE := 0.4
const DYN_LOW_FPS := 46
const DYN_HIGH_FPS := 57
const DYN_LOW_HOLD := 1.2
const DYN_HIGH_HOLD := 3.0
const DYN_CHECK_WINDOW := 1.5
const DYN_NO_GAIN_RATIO := 1.12
const DYN_COOLDOWN := 20.0
const DYN_SETTLE_GRACE := 2.5

## V30A: stress/Auto FPS checks at 5 Hz instead of every rendered frame.
const STRESS_SAMPLE_INTERVAL := 0.2

var quality: int = Quality.VERY_LOW
var auto_mode: bool = false
var stress_mode: bool = false
var _low_time: float = 0.0
var _high_time: float = 0.0
var _stress_low_time: float = 0.0
## V20A: startup grace before Auto judges FPS (shader compile + first-frame
## asset churn read as "slow" and would drop the tier pointlessly).
const AUTO_STARTUP_GRACE := 6.0
var _auto_grace_left: float = 0.0
## V21A: throttle Auto quality checks to once per second so we do not
## repeatedly look up Engine.get_frames_per_second() every physics frame.
var _auto_next_sample: float = 0.0
## Preserve elapsed time while sampling is throttled. Without this accumulator,
## Auto quality would react to one half-second slice per sample instead of the
## full interval and would step down too slowly on low-FPS web devices.
var _auto_sample_delta: float = 0.0

var active_enemies: int = 0
var active_projectiles: int = 0
var active_particles: int = 0

## V30A: cached platform probes. OS.get_name()/DisplayServer lookups are not
## free in WASM and the cap helpers were calling them dozens of times/second.
var _web: bool = false
var _touch: bool = false
var _mobile: bool = false
## Cached settings so per-hit cap calls never touch SaveManager dictionaries.
var _reduced_vfx: bool = false

## V30A: gameplay telemetry is off during normal play. The per-enemy dictionary
## bookkeeping in report_system_time was pure overhead unless the F3 overlay or
## F4 session logger was actually consuming it.
var telemetry_enabled: bool = false

## Dynamic resolution state (V30A).
var dynamic_resolution: bool = true
var _dyn_scale: float = 1.0
var _dyn_low_time: float = 0.0
var _dyn_high_time: float = 0.0
var _dyn_grace: float = 0.0
var _dyn_check_left: float = 0.0
var _dyn_fps_before: float = 0.0
var _dyn_fps_sum: float = 0.0
var _dyn_fps_count: int = 0
var _dyn_cooldown: float = 0.0
var _stress_accum: float = 0.0

## Release-readiness session logger (opt-in, F4). Captures a 1s telemetry
## sample while a run is active so a real-device playthrough leaves a
## paste-able trace for the balance/perf pass. Zero cost when off.
var perf_logging: bool = false
var _perf_samples: PackedStringArray = []
var _perf_sample_accum: float = 0.0
## Peak stats across the capture window (for the summary line).
var _perf_min_fps: int = 9999
var _perf_max_enemies: int = 0
var _perf_sum_fps: int = 0
var _perf_frames: int = 0

var _system_times: Dictionary = {}
var _sun_cache: Array = []
var _sun_cache_time: int = -10000
var _fog_cache: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Cache platform/settings probes once — cap helpers run on every spawn/hit.
	_web = OS.get_name() == "Web"
	_mobile = OS.get_name() == "Android" or OS.get_name() == "iOS" or OS.has_feature("mobile")
	_touch = DisplayServer.is_touchscreen_available() or _mobile
	_reduced_vfx = bool(SaveManager.get_setting("reduced_vfx", false))
	# Headless test runs have no real swap chain; leave the scale alone there.
	dynamic_resolution = DisplayServer.get_name() != "headless"
	_auto_grace_left = AUTO_STARTUP_GRACE
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

## True on Android/iOS. Used to pick safe defaults (Very Low) and to keep
## the mobile render budget honest.
func is_mobile_platform() -> bool:
	return OS.get_name() == "Android" or OS.get_name() == "iOS" or OS.has_feature("mobile")

func _migrate_legacy_quality(old_q: int) -> int:
	# Legacy: 0=LOW 1=MED 2=HIGH 3=Auto → new 1=LOW 2=MED 3=HIGH 5=Auto
	match old_q:
		0: return Quality.LOW
		1: return Quality.MEDIUM
		2: return Quality.HIGH
		3: return QUALITY_AUTO_SETTING
		_: return Quality.VERY_LOW

func _is_web() -> bool:
	return _web

func _is_touch() -> bool:
	return _touch

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
	# Mobile MEDIUM used to keep real-time shadows on because only "web" was
	# excluded — that is the single most expensive toggle on weak phone GPUs.
	var enable_shadows := quality >= Quality.HIGH or (quality == Quality.MEDIUM and not _is_web() and not _is_touch())
	for sun in _get_suns(true):
		if sun is DirectionalLight3D:
			sun.shadow_enabled = enable_shadows
	# Fog is fill-rate work: keep it for native desktop MEDIUM+, but only HIGH+
	# on web/touch where every 3D fragment is precious.
	var enable_fog := quality >= Quality.MEDIUM
	if _is_web() or _is_touch():
		enable_fog = quality >= Quality.HIGH
	for env in _get_world_envs():
		if env is WorldEnvironment and env.environment != null:
			env.environment.fog_enabled = enable_fog
	var vp := get_viewport()
	if vp == null:
		return
	var msaa := RenderingServer.VIEWPORT_MSAA_2X if (quality >= Quality.HIGH and not _is_web()) else RenderingServer.VIEWPORT_MSAA_DISABLED
	RenderingServer.viewport_set_msaa_3d(vp.get_viewport_rid(), msaa)
	# Reset the adaptive ladder to the tier ceiling and give shaders a moment
	# to settle before the first downscale decision.
	_dyn_scale = _render_scale()
	_reset_dynamic_state()
	_dyn_grace = DYN_SETTLE_GRACE
	_apply_render_scale(_dyn_scale)

## Push a 3D render scale to the root viewport. Kept separate from
## _apply_render_settings so the adaptive ladder can change it cheaply.
func _apply_render_scale(scale: float) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	if scale < 0.999:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = scale
	else:
		vp.scaling_3d_scale = 1.0

## Current 3D render scale (tier ceiling adjusted by the adaptive ladder).
func current_render_scale() -> float:
	return _dyn_scale

func _reset_dynamic_state() -> void:
	_dyn_low_time = 0.0
	_dyn_high_time = 0.0
	_dyn_check_left = 0.0
	_dyn_cooldown = 0.0
	_dyn_fps_before = 0.0
	_reset_dynamic_samples()

func _reset_dynamic_samples() -> void:
	_dyn_fps_sum = 0.0
	_dyn_fps_count = 0

func _set_dynamic_scale(value: float) -> void:
	if absf(value - _dyn_scale) < 0.001:
		return
	_dyn_scale = value
	_apply_render_scale(value)

## Lowest scale the adaptive ladder may reach for a given tier ceiling.
func _dynamic_floor(base: float) -> float:
	return maxf(DYN_MIN_SCALE, base - 0.25)

## Enable/disable adaptive resolution at runtime (settings/debug).
func set_dynamic_resolution(enabled: bool) -> void:
	dynamic_resolution = enabled
	_reset_dynamic_state()
	_set_dynamic_scale(_render_scale())

## Adaptive resolution loop (called at STRESS_SAMPLE_INTERVAL cadence).
## Drops pixels while FPS is low, climbs back when there is headroom, and
## reverts + pauses if a downscale did not actually buy frames (CPU-bound).
func _tick_dynamic_resolution(delta: float, fps: int) -> void:
	if not dynamic_resolution:
		return
	if _dyn_cooldown > 0.0:
		_dyn_cooldown = maxf(_dyn_cooldown - delta, 0.0)
		return
	var base := _render_scale()
	if _dyn_scale > base:
		_set_dynamic_scale(base)
	if _dyn_grace > 0.0:
		_dyn_grace = maxf(_dyn_grace - delta, 0.0)
		return
	if fps > 0:
		_dyn_fps_sum += float(fps)
		_dyn_fps_count += 1
	if _dyn_check_left > 0.0:
		_dyn_check_left -= delta
		if _dyn_check_left <= 0.0:
			var avg := _dyn_fps_sum / maxf(float(_dyn_fps_count), 1.0)
			if avg < _dyn_fps_before * DYN_NO_GAIN_RATIO:
				# Smaller buffers did not help — the bottleneck is CPU-side.
				# Restore sharpness and stop probing for a while.
				_set_dynamic_scale(base)
				_dyn_cooldown = DYN_COOLDOWN
			_dyn_low_time = 0.0
			_dyn_high_time = 0.0
			_reset_dynamic_samples()
		return
	if fps <= 0:
		return
	if fps < DYN_LOW_FPS:
		_dyn_high_time = 0.0
		_dyn_low_time += delta
		if _dyn_low_time >= DYN_LOW_HOLD:
			var bottom := _dynamic_floor(base)
			if _dyn_scale > bottom + 0.001:
				_dyn_fps_before = _dyn_fps_sum / maxf(float(_dyn_fps_count), 1.0)
				_set_dynamic_scale(maxf(_dyn_scale - DYN_STEP, bottom))
				_dyn_check_left = DYN_CHECK_WINDOW
				_dyn_low_time = 0.0
				_reset_dynamic_samples()
	elif fps > DYN_HIGH_FPS:
		_dyn_low_time = 0.0
		_dyn_high_time += delta
		if _dyn_high_time >= DYN_HIGH_HOLD and _dyn_scale < base - 0.001:
			_set_dynamic_scale(minf(_dyn_scale + DYN_STEP, base))
			_dyn_high_time = 0.0
			_reset_dynamic_samples()
	else:
		_dyn_low_time = 0.0
		_dyn_high_time = 0.0

func _render_scale() -> float:
	if _is_web():
		match quality:
			Quality.VERY_LOW: return 0.5
			Quality.LOW: return 0.6
			Quality.MEDIUM: return 0.75
			_: return 1.0
	if _is_touch():
		match quality:
			Quality.VERY_LOW: return 0.6
			Quality.LOW: return 0.7
			Quality.MEDIUM: return 0.8
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
	# V30A: stress + adaptive resolution sample at 5 Hz. Engine FPS lookups and
	# cap math do not need to run 60 times a second.
	_stress_accum += delta
	if _stress_accum >= STRESS_SAMPLE_INTERVAL:
		var step := _stress_accum
		_stress_accum = 0.0
		var fps := Engine.get_frames_per_second()
		_update_stress(step, fps)
		_tick_dynamic_resolution(step, fps)
	if auto_mode:
		_auto_tick(delta)
	if perf_logging:
		_perf_tick(delta)

## Toggle with F4 (or PerfLogger key). Starts/stops a capture window.
func toggle_perf_logging() -> void:
	if perf_logging:
		stop_perf_logging()
	else:
		start_perf_logging()

func start_perf_logging() -> void:
	perf_logging = true
	telemetry_enabled = true
	_perf_samples.clear()
	_perf_sample_accum = 0.0
	_perf_min_fps = 9999
	_perf_max_enemies = 0
	_perf_sum_fps = 0
	_perf_frames = 0
	push_warning("[PerfLog] capture started — play through a run, F4 or game-over dumps the report")

func stop_perf_logging() -> String:
	perf_logging = false
	telemetry_enabled = false
	var report := _perf_report()
	print(report)
	# On web the console is the only reliable sink; also try clipboard on native.
	if not _is_web() and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(report)
	return report

## V30A: per-frame system timing is only recorded while someone is looking
## (F3 overlay or F4 capture). Idle play pays zero dictionary overhead.
func set_telemetry_enabled(enabled: bool) -> void:
	telemetry_enabled = enabled or perf_logging
	if not telemetry_enabled:
		_system_times.clear()

func _perf_tick(delta: float) -> void:
	# Only sample during an active run; menu frames would pollute the trace.
	if RunManager == null or not RunManager.is_running:
		return
	_perf_sample_accum += delta
	var fps := Engine.get_frames_per_second()
	_perf_min_fps = mini(_perf_min_fps, fps)
	_perf_sum_fps += fps
	_perf_frames += 1
	_perf_max_enemies = maxi(_perf_max_enemies, active_enemies)
	if _perf_sample_accum < 1.0:
		return
	_perf_sample_accum = 0.0
	var mins := RunManager.elapsed_time / 60.0
	_perf_samples.append("%.1f,%d,%d,%s" % [mins, fps, active_enemies, quality_name()])

func _perf_report() -> String:
	var avg_fps := int(round(float(_perf_sum_fps) / maxf(float(_perf_frames), 1.0)))
	var mins := 0.0
	if RunManager != null:
		mins = RunManager.elapsed_time / 60.0
	var lines: Array[String] = []
	lines.append("=== PerfLog report — %.1f min run ===" % mins)
	lines.append("samples: %d | avg_fps: %d | min_fps: %s | peak_enemies: %d" % [
		_perf_samples.size(), avg_fps, (_perf_min_fps if _perf_min_fps < 9999 else 0), _perf_max_enemies])
	lines.append("cols: minute,fps,enemies,quality")
	lines.append_array(_perf_samples)
	lines.append("=== end PerfLog ===")
	return "\n".join(lines)

## Called by EnemyManager whenever the live horde count changes.
func update_horde_pressure(enemy_count: int) -> void:
	active_enemies = enemy_count

func _update_stress(delta: float, fps_override: int = -1) -> void:
	var cap := enemy_cap()
	var pressure := float(active_enemies) / maxf(float(cap), 1.0)
	var fps: int = fps_override if fps_override >= 0 else Engine.get_frames_per_second()
	var heavy: bool = pressure >= STRESS_PRESSURE or (active_enemies >= STRESS_ENEMY_MIN and fps > 0 and fps < STRESS_FPS)
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
	# V20A: startup grace — shader compilation + first-frame asset churn make
	# the opening seconds read as "low FPS" and would instantly drop the tier
	# (forcing a full re-warm when it climbs back). Judge quality only after
	# the scene has settled; the stress path still reacts immediately.
	if _auto_grace_left > 0.0:
		_auto_grace_left -= delta
		return
	# V21A: only re-read Engine FPS when there is enough time to act on it;
	# Engine.get_frames_per_second() is a per-frame global lookup — batch it.
	_auto_sample_delta += delta
	if _auto_next_sample > 0.0:
		_auto_next_sample -= delta
		return
	_auto_next_sample = 1.0
	var sample_delta := _auto_sample_delta
	_auto_sample_delta = 0.0

	var fps := Engine.get_frames_per_second()
	if fps_override > 0:
		fps = fps_override
	# Stress/low FPS: step down faster. Web and mobile are harsher than desktop.
	var low_threshold := 32 if (_is_web() or _is_touch() or stress_mode) else 26
	var low_hold := 0.75 if (_is_web() or _is_touch() or stress_mode) else 4.0
	if fps < low_threshold:
		_low_time += sample_delta
		_high_time = 0.0
		if _low_time > low_hold and quality > Quality.VERY_LOW:
			_low_time = 0.0
			set_quality(quality - 1, false)
	elif fps > 55 and not stress_mode:
		_high_time += sample_delta
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

## Whether pooled VFX may show real light sources. Web + Mobile: ULTRA only —
## OmniLight3D shadow updates are the #1 hitch source on weak GPUs.
func prefer_dynamic_lights() -> bool:
	if _is_web() or _is_touch():
		return quality >= Quality.ULTRA
	return quality >= Quality.HIGH

func enemy_cap() -> int:
	var cap: int = ENEMY_CAPS.get(quality, 40)
	if _is_web() and quality > Quality.VERY_LOW:
		var scale := WEB_MEDIUM_ENEMY_CAP_SCALE if quality == Quality.MEDIUM else WEB_ENEMY_CAP_SCALE
		cap = maxi(20, int(cap * scale))
	if _is_touch() and quality > Quality.VERY_LOW and not _is_web():
		cap = maxi(25, int(cap * TOUCH_ENEMY_CAP_SCALE))
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
		var scale := WEB_MEDIUM_PROJECTILE_CAP_SCALE if quality == Quality.MEDIUM else WEB_PROJECTILE_CAP_SCALE
		cap = maxi(15, int(cap * scale))
	if _is_touch() and quality > Quality.VERY_LOW and not _is_web():
		cap = maxi(20, int(cap * TOUCH_PROJECTILE_CAP_SCALE))
	if stress_mode:
		cap = maxi(15, int(cap * 0.7))
	return cap

func particle_cap() -> int:
	var cap: int = PARTICLE_CAPS.get(quality, 25)
	if _is_web() and quality > Quality.VERY_LOW:
		var scale := WEB_MEDIUM_PARTICLE_CAP_SCALE if quality == Quality.MEDIUM else WEB_PARTICLE_CAP_SCALE
		cap = maxi(8, int(cap * scale))
	if _is_touch() and quality > Quality.VERY_LOW and not _is_web():
		cap = maxi(12, int(cap * TOUCH_PARTICLE_CAP_SCALE))
	# V19: reduced-VFX setting shrinks particle budget (cached — this runs per
	# particle spawn and SaveManager lookups add up in WASM).
	if _reduced_vfx:
		cap = maxi(8, int(cap * 0.45))
	return cap

## V19: call when the reduced-VFX setting changes.
func notify_reduced_vfx() -> void:
	_reduced_vfx = bool(SaveManager.get_setting("reduced_vfx", false))
	quality_changed.emit(quality)

func damage_number_cap() -> int:
	var cap: int = DAMAGE_NUMBER_CAPS.get(quality, 12)
	if _is_web() and quality > Quality.VERY_LOW:
		cap = maxi(8, int(cap * WEB_DAMAGE_NUMBER_CAP_SCALE))
	if _is_touch() and quality > Quality.VERY_LOW and not _is_web():
		cap = maxi(8, int(cap * TOUCH_DAMAGE_NUMBER_CAP_SCALE))
	if stress_mode:
		cap = maxi(6, int(cap * 0.5))
	# V15A: 150+ enemies — fewer floating numbers so combat stays readable
	if active_enemies >= DAMAGE_NUMBER_HEAVY_ENEMIES:
		cap = maxi(4, int(cap * DAMAGE_NUMBER_HEAVY_SCALE))
	return cap

## V15A: milliseconds between non-crit damage numbers (crits stay unthrottled-ish).
func damage_number_min_gap_ms() -> int:
	var cap := damage_number_cap()
	var gap := maxi(16, int(1000.0 / maxf(float(cap), 1.0)))
	# Heavy horde: stretch the gap so numbers don't stack into a wall of text
	if active_enemies >= DAMAGE_NUMBER_HEAVY_ENEMIES:
		gap = maxi(gap, 90)
	return gap

## V15A: at extreme load, only crits / big hits get a floating number.
func should_skip_damage_number(is_crit: bool, amount: float) -> bool:
	if is_crit:
		return false
	if active_enemies >= DAMAGE_NUMBER_HEAVY_ENEMIES:
		# Keep rare big hits visible; drop constant small-hit spam
		return amount < 40.0
	return false

## True when far enemies should skip full physics this tick (horde LOD).
func should_throttle_enemy_ai() -> bool:
	# Medium on Web is still a constrained GPU/CPU budget; throttle distant
	# enemies there as well to prevent late-run frame collapse.
	if stress_mode or quality <= Quality.MEDIUM:
		return true
	# HIGH on web/touch is still a browser/phone budget — keep far-enemy LOD.
	return quality == Quality.HIGH and (_is_web() or _is_touch())

func report_system_time(name: String, elapsed_usec: int) -> void:
	if not telemetry_enabled:
		return
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
	lines.append("FPS: %d | frame: %.2f ms | physics: %.2f ms | Q:%s %s | res:%.2f" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		quality_name(),
		mode,
		current_render_scale(),
	])
	lines.append("draw calls: %d | primitives: %dk | objects: %d " % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		Performance.get_monitor(Performance.OBJECT_COUNT),
	])
	lines.append("enemies: %d/%d | projectiles: %d | particles: %d" % [
		active_enemies, effective_enemy_cap(), active_projectiles, active_particles,
	])
	# V18: endless balance snapshot (10/15/20-min tuning evidence)
	if RunManager != null:
		var mins := RunManager.elapsed_time / 60.0
		var diff := DifficultyManager.difficulty_multiplier(25, mins)
		var win_left := maxf(RunManager.target_duration - RunManager.elapsed_time, 0.0) if not RunManager.endless else -1.0
		lines.append("endless: t=%.1fm | diff=%.2f | threat=%.1f | spawn=%.2fs | win_in=%.0fs | endless=%s" % [
			mins, diff, DifficultyManager.threat_budget(mins),
			DifficultyManager.spawn_interval(mins), win_left, str(RunManager.endless),
		])
	var sys_lines: Array[String] = []
	for name in _system_times:
		sys_lines.append("%s: %.2f ms" % [name, get_system_avg_ms(name)])
	if not sys_lines.is_empty():
		lines.append(" | ".join(sys_lines))
	return "\n".join(lines)
