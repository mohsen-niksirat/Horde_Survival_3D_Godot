extends Node3D
## Arena environment: spawn helpers + decor + optional Kenney skybox (Medium+).

const DECOR_SCRIPT := preload("res://scenes/world/arena_decor.gd")
const HALF_SIZE := 60.0
const SPAWN_RING_MIN := 22.0
const SPAWN_RING_MAX := 30.0
const SKY_DAY := "res://assets/models/env/skybox-day.png"
const SKY_NIGHT := "res://assets/models/env/skybox-night.png"

func _ready() -> void:
	var decor := Node3D.new()
	decor.name = "ArenaDecor"
	decor.set_script(DECOR_SCRIPT)
	add_child(decor)
	_apply_skybox()
	if PerformanceManager != null:
		if not PerformanceManager.quality_changed.is_connected(_on_quality_changed):
			PerformanceManager.quality_changed.connect(_on_quality_changed)

func _on_quality_changed(_tier: int) -> void:
	_apply_skybox()

func _apply_skybox() -> void:
	var we: WorldEnvironment = get_node_or_null("WorldEnvironment")
	if we == null or we.environment == null:
		return
	var use_skybox := PerformanceManager == null or PerformanceManager.quality >= PerformanceManager.Quality.MEDIUM
	if not use_skybox:
		return
	var path := SKY_DAY
	if RunManager != null and RunManager.elapsed_time > 400.0 and ResourceLoader.exists(SKY_NIGHT):
		path = SKY_NIGHT
	if not ResourceLoader.exists(path):
		return
	var tex = load(path)
	if tex == null:
		return
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = tex
	var sky := Sky.new()
	sky.sky_material = pano
	we.environment.sky = sky
	we.environment.background_mode = Environment.BG_SKY

func get_spawn_position(around: Vector3) -> Vector3:
	var angle := randf() * TAU
	var dist := randf_range(SPAWN_RING_MIN, SPAWN_RING_MAX)
	var pos := around + Vector3(cos(angle), 0, sin(angle)) * dist
	pos.x = clampf(pos.x, -HALF_SIZE + 2.0, HALF_SIZE - 2.0)
	pos.z = clampf(pos.z, -HALF_SIZE + 2.0, HALF_SIZE - 2.0)
	pos.y = 0.0
	return pos

func is_inside_bounds(pos: Vector3, margin: float = 1.0) -> bool:
	return absf(pos.x) <= HALF_SIZE - margin and absf(pos.z) <= HALF_SIZE - margin
