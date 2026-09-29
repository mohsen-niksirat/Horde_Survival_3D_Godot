extends Node
## SfxBinder: translates EventBus signals into procedural SFX calls.
## Keeps gameplay code free of audio calls.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.enemy_damaged.connect(_on_enemy_damaged)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_leveled_up.connect(_on_level_up)
	EventBus.xp_collected.connect(_on_xp)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_died.connect(_on_boss_died)
	EventBus.player_died.connect(_on_player_died)
	EventBus.run_ended.connect(_on_run_ended)

## V11B haptics: short vibration on key gameplay moments (mobile only,
## user-toggleable via Settings).
func _haptic(ms: int) -> void:
	if SaveManager.get_setting("haptics", false) and DisplayServer.is_touchscreen_available():
		Input.vibrate_handheld(ms)

var _last_hit_ms: int = 0

func _on_enemy_damaged(_enemy: Node, _amount: float, _crit: bool) -> void:
	# Throttle identical hit sounds (reference-game lesson: 15 sounds/sec max)
	var now := Time.get_ticks_msec()
	if now - _last_hit_ms < 50:
		return
	_last_hit_ms = now
	AudioManager.play_game_sfx("enemy_hit")

func _on_enemy_died(_enemy: Node, _pos: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hit_ms < 50:
		return
	AudioManager.play_game_sfx("enemy_death")

func _on_player_damaged(_amount: float) -> void:
	AudioManager.play_game_sfx("player_hurt")
	_haptic(30)

func _on_level_up(_level: int) -> void:
	AudioManager.play_game_sfx("level_up")
	_haptic(60)

func _on_xp(_amount: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hit_ms < 60:
		return
	AudioManager.play_game_sfx("xp_pickup")

func _on_boss_spawned(_boss: Node) -> void:
	AudioManager.play_game_sfx("boss_warn")
	_haptic(120)

func _on_boss_died() -> void:
	AudioManager.play_game_sfx("boss_die")
	_haptic(200)

func _on_player_died() -> void:
	_haptic(250)

func _on_run_ended(victory: bool) -> void:
	if victory:
		AudioManager.play_game_sfx("victory")
		_haptic(180)
	else:
		AudioManager.play_game_sfx("player_hurt")
		_haptic(220)
