extends Node3D
## DamageNumber VFX: floating billboard number, rises + fades, pooled.
## Crits are bigger and gold; normals are white.

const LIFETIME := 0.8
const RISE_SPEED := 2.2

var _life: float = 0.0
var _active: bool = false
var _rise: float = 0.0

@onready var label: Label3D = $Label

func _ready() -> void:
	visible = false
	# V30A: pooled nodes live under JuiceManager forever — idle ones must not
	# receive a per-frame script callback.
	set_process(false)

func trigger(pos: Vector3, amount: float, is_crit: bool) -> void:
	global_position = pos + Vector3(randf_range(-0.4, 0.4), 1.6, randf_range(-0.4, 0.4))
	label.text = str(int(amount))
	if is_crit:
		label.modulate = Color(1.0, 0.8, 0.1)
		label.font_size = 52
	else:
		label.modulate = Color(1, 1, 1)
		label.font_size = 34
	_life = 0.0
	_rise = 0.0
	_active = true
	visible = true
	set_process(true)

func _process(delta: float) -> void:
	if not _active:
		set_process(false)
		return
	_life += delta
	_rise += RISE_SPEED * delta
	label.position.y = _rise
	label.modulate.a = clampf(1.0 - (_life / LIFETIME), 0.0, 1.0)
	if _life > LIFETIME:
		_active = false
		visible = false
		label.position.y = 0.0
		set_process(false)
