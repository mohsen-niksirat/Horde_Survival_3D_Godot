extends Node
## DashComponent (V16A): Space-dash burst with brief invincibility frames.
## The "dash" input action existed in project.godot and was routed through
## InputManager, but no system consumed it — this closes that gap.
## Driven by player.gd: while dashing, tick() replaces normal movement.

signal dashed(direction: Vector3)

const DASH_SPEED := 22.0   # m/s during the burst (player base speed is 6)
const DASH_TIME := 0.22    # seconds of boosted movement (~4.8 m — reads as a real dodge)
const IFRAMES := 0.25      # invulnerability window (slightly longer than the burst)
const COOLDOWN := 2.5      # seconds between dashes

var cooldown_left: float = 0.0
var dash_time_left: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO
var dash_count: int = 0

var _player: CharacterBody3D

func setup(p_player: CharacterBody3D) -> void:
	_player = p_player

func is_dashing() -> bool:
	return dash_time_left > 0.0

func get_cooldown_ratio() -> float:
	return cooldown_left / COOLDOWN if cooldown_left > 0.0 else 0.0

## Called from player._physics_process every physics frame.
## Returns true when this frame was dash-driven (player skips movement.tick).
## `want_dash` must be the edge/held state of the dash input — pass the
## action, not just "is the player moving". Without it every frame counts
## as a request and the dash fires automatically when cooldown ends.
func tick(delta: float, move_dir: Vector3, want_dash: bool) -> bool:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if dash_time_left > 0.0:
		dash_time_left = maxf(dash_time_left - delta, 0.0)
		if _player != null and is_instance_valid(_player):
			_player.velocity.x = dash_dir.x * DASH_SPEED
			_player.velocity.z = dash_dir.z * DASH_SPEED
			_player.move_and_slide()
		if dash_time_left <= 0.0:
			dash_dir = Vector3.ZERO
		return true
	if want_dash and _player != null and is_instance_valid(_player):
		try_dash(move_dir)
	return false

## Attempt a dash along move_dir (world space). Returns true if it started.
func try_dash(move_dir: Vector3) -> bool:
	if dash_time_left > 0.0 or cooldown_left > 0.0:
		return false
	if _player == null or not is_instance_valid(_player) or not _player.is_player_alive():
		return false
	var flat := Vector3(move_dir.x, 0.0, move_dir.z)
	if flat.length_squared() < 0.0001:
		return false
	dash_dir = flat.normalized()
	dash_time_left = DASH_TIME
	cooldown_left = COOLDOWN
	dash_count += 1
	# Brief i-frames: dash through packs instead of around them.
	_player.health.set_invincible(IFRAMES)
	if _player.camera_rig != null and _player.camera_rig.has_method("add_shake"):
		_player.camera_rig.add_shake(0.12)
	AudioManager.play_game_sfx("dash")
	dashed.emit(dash_dir)
	return true
