extends Control
## ScreenFeedback: low-HP vignette pulse + level-up flash + boss warning.
## Pure visuals, driven by EventBus; respects the screen_shake-quality-style
## settings (tied to show_particles-style toggles later).

@onready var vignette: ColorRect = $Vignette
@onready var flash: ColorRect = $Flash

var _player: Node

func bind_player(player: Node) -> void:
	_player = player
	EventBus.player_leveled_up.connect(_on_level_up)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_spawned.connect(_on_enemy_maybe_elite)
	vignette.modulate.a = 0.0
	flash.modulate.a = 0.0

func _on_enemy_maybe_elite(enemy: Node) -> void:
	if enemy != null and enemy.get("elite") != null and enemy.elite != null:
		_on_elite_spawned()

func _on_player_died() -> void:
	# R7: hard red flash on death
	flash.color = Color(0.9, 0.05, 0.05)
	flash.modulate.a = 0.85

func _process(delta: float) -> void:
	# Low-HP pulsing vignette (<25%, softer so the arena stays readable)
	if _player != null and is_instance_valid(_player) and _player.health.is_alive():
		var ratio: float = _player.health.get_ratio()
		if ratio < 0.25:
			var intensity: float = (0.25 - ratio) / 0.25
			vignette.modulate.a = 0.15 + intensity * 0.15 + sin(Time.get_ticks_msec() / 1000.0 * 6.0) * 0.05
		else:
			vignette.modulate.a = maxf(vignette.modulate.a - delta * 2.0, 0.0)
	else:
		vignette.modulate.a = maxf(vignette.modulate.a - delta * 2.0, 0.0)
	flash.modulate.a = maxf(flash.modulate.a - delta * 2.5, 0.0)

func _on_level_up(_level: int) -> void:
	flash.color = Color(1, 0.95, 0.7)
	flash.modulate.a = 0.45

func _on_boss_spawned(_boss: Node) -> void:
	flash.color = Color(1, 0.45, 0.2)
	flash.modulate.a = 0.5

func _on_elite_spawned() -> void:
	# R13: subtle gold flash when an elite enters the arena
	flash.color = Color(1.0, 0.85, 0.3)
	flash.modulate.a = 0.28

## V15B: phase-transition / victory flash uses the phase color.
func _on_boss_phase_changed(_phase_name: String, color: Color) -> void:
	flash.color = color
	flash.modulate.a = 0.55
