extends Node3D
## MuzzleFlash VFX: quick light+glow burst at a weapon muzzle.
## Pooled; faces the shot direction; self-hides after 0.12s.

const LIFETIME := 0.12

var _life: float = 0.0
var _active: bool = false

func trigger(pos: Vector3, dir: Vector3) -> void:
	global_position = pos
	if dir.length_squared() > 0.01:
		look_at(pos + dir, Vector3.UP)
	_life = 0.0
	_active = true
	visible = true
	var light := get_node_or_null("Light")
	if light is Light3D:
		light.visible = PerformanceManager.prefer_dynamic_lights() if PerformanceManager != null else true

func _process(delta: float) -> void:
	if not _active:
		return
	_life += delta
	var t := _life / LIFETIME
	scale = Vector3.ONE * (1.0 + t * 1.5)
	if _life > LIFETIME:
		_active = false
		visible = false
		scale = Vector3.ONE
