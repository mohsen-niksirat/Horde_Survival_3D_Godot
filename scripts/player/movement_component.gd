extends Node
## Player movement: camera-relative acceleration/deceleration, arena clamp.
## Stats come from the StatsComponent when it arrives (Phase 3); for now a
## clean base_speed constant that will be replaced by a stat lookup.

signal landed()

@export var base_speed: float = 6.0
@export var acceleration: float = 10.0
@export var deceleration: float = 14.0
@export var gravity: float = 25.0

var speed_multiplier: float = 1.0
var _body: CharacterBody3D
var _move_speed: float = 0.0

func setup(body: CharacterBody3D) -> void:
	_body = body

func get_current_speed() -> float:
	return _move_speed

func get_max_speed() -> float:
	return base_speed * speed_multiplier

## Tick movement on a physics body. Returns true if the body moved.
func tick(delta: float, move_dir: Vector2) -> bool:
	if _body == null:
		return false

	if not _body.is_on_floor():
		_body.velocity.y -= gravity * delta
	else:
		_body.velocity.y = maxf(_body.velocity.y, -0.5)

	var target := Vector3(move_dir.x, 0.0, move_dir.y) * get_max_speed()
	var flat := Vector2(_body.velocity.x, _body.velocity.z)
	var target_flat := Vector2(target.x, target.z)

	# Playtest: release must stop quickly — hard damp when no input
	if move_dir.length_squared() < 0.0004:
		var stop_rate := deceleration * 2.2
		var new_flat0 := flat.move_toward(Vector2.ZERO, stop_rate * base_speed * delta)
		if new_flat0.length() < 0.15:
			new_flat0 = Vector2.ZERO
		_move_speed = new_flat0.length()
		_body.velocity.x = new_flat0.x
		_body.velocity.z = new_flat0.y
		_body.move_and_slide()
		return false

	var rate := acceleration if target_flat.length_squared() > flat.length_squared() else deceleration
	var new_flat := flat.move_toward(target_flat, rate * base_speed * delta)
	_move_speed = new_flat.length()
	_body.velocity.x = new_flat.x
	_body.velocity.z = new_flat.y
	_body.move_and_slide()

	return _move_speed > 0.3
