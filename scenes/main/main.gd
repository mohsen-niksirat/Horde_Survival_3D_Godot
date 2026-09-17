extends Node3D
## Root game orchestrator: owns per-run systems (enemy manager, progression,
## relics, combo, achievements, abilities, pet), global input routing,
## mouse capture, and the debug overlay.

const ENEMY_MANAGER := preload("res://scripts/spawning/enemy_manager.gd")
const WAVE_MANAGER := preload("res://scripts/spawning/wave_manager.gd")
const PROGRESSION := preload("res://scripts/progression/progression_manager.gd")
const RELIC_SYSTEM := preload("res://scripts/items/relic_system.gd")
const COMBO_MANAGER := preload("res://scripts/progression/combo_manager.gd")
const ACHIEVEMENT_SYSTEM := preload("res://scripts/progression/achievement_system.gd")

@onready var player: CharacterBody3D = $World/Player
@onready var touch_controls: Control = $HUD/TouchControls
@onready var debug_label: Label = $HUD/DebugLabel

var enemy_manager: Node
var wave_manager: Node
var progression: Node
var relic_system: Node
var combo_manager: Node
var ability_controller: Node
var projectile_root: Node3D
var _debug_enabled: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Esc/P must reach _unhandled_input while paused
	# Keep the WORLD pausable: children would otherwise inherit ALWAYS and
	# keep running (enemies attacking) while the pause overlay is up.
	$World.process_mode = Node.PROCESS_MODE_PAUSABLE
	$HUD/TutorialOverlay.process_mode = Node.PROCESS_MODE_ALWAYS
	$HUD/PauseOverlay.process_mode = Node.PROCESS_MODE_ALWAYS
	$HUD/LevelUpOverlay.process_mode = Node.PROCESS_MODE_ALWAYS

	RunManager.start_run()
	GameManager.change_state(GameManager.State.PLAYING)

	enemy_manager = Node.new()
	enemy_manager.set_script(ENEMY_MANAGER)
	enemy_manager.name = "EnemyManager"
	enemy_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(enemy_manager)

	# V9+V13: apply meta upgrades AND selected character stats FIRST
	preload("res://scenes/menu/meta_shop.gd").apply_meta_upgrades(player.stat_block)
	var char_path := "res://data/characters/%s.tres" % GameManager.selected_character_id
	if ResourceLoader.exists(char_path):
		var ch: CharacterData = load(char_path)
		player.stat_block.add_modifier("max_hp", 0.0, ch.max_hp_pct)
		player.stat_block.add_modifier("move_speed", 0.0, ch.move_speed_pct)
		player.stat_block.add_modifier("might", 0.0, ch.might_pct)
		# P3-lite: tint hero robe/hood with the character color at run start
		var robe: MeshInstance3D = player.get_node_or_null("Mesh/Root/Robe")
		var hood: MeshInstance3D = player.get_node_or_null("Mesh/Root/Hood")
		if robe != null:
			robe.get_surface_override_material(0).albedo_color = ch.color
		if hood != null:
			hood.get_surface_override_material(0).albedo_color = ch.color.darkened(0.25)
	player.on_stats_changed()
	player.health.setup(player.stat_block.get_stat("max_hp"))

	# Projectile container + weapon binding
	projectile_root = Node3D.new()
	projectile_root.name = "Projectiles"
	projectile_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(projectile_root)
	player.bind_combat(enemy_manager, projectile_root)

	# Horde spawning
	wave_manager = Node.new()
	wave_manager.set_script(WAVE_MANAGER)
	wave_manager.name = "WaveManager"
	wave_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(wave_manager)
	wave_manager.setup($World, player, enemy_manager)

	# Progression + level-up UI
	progression = Node.new()
	progression.set_script(PROGRESSION)
	progression.name = "ProgressionManager"
	progression.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(progression)
	progression.setup(player)
	player.progression = progression
	$HUD/LevelUpOverlay.bind_progression(progression)

	# Combo (drives XP multiplier)
	combo_manager = Node.new()
	combo_manager.set_script(COMBO_MANAGER)
	combo_manager.name = "ComboManager"
	combo_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(combo_manager)
	player.combo = combo_manager

	# Achievements
	var achievements := Node.new()
	achievements.set_script(ACHIEVEMENT_SYSTEM)
	achievements.name = "AchievementSystem"
	achievements.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(achievements)

	# Relics
	relic_system = Node.new()
	relic_system.set_script(RELIC_SYSTEM)
	relic_system.name = "RelicSystem"
	relic_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(relic_system)
	relic_system.setup(player, $World, projectile_root)

	# Abilities
	ability_controller = Node.new()
	ability_controller.set_script(preload("res://scripts/abilities/ability_controller.gd"))
	ability_controller.name = "AbilityController"
	ability_controller.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(ability_controller)
	ability_controller.setup(player, enemy_manager, projectile_root)
	player.ability_controller = ability_controller

	# Pet (Dragon Welp)
	var pet_scene: PackedScene = load("res://scenes/player/Pet.tscn")
	var pet := pet_scene.instantiate()
	pet.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(pet)
	pet.setup(player, enemy_manager, projectile_root)

	# UI bindings
	$HUD/Hud.bind_player(player)
	$HUD/Hud.bind_abilities(ability_controller)
	$HUD/ScreenFeedback.bind_player(player)

	# SFX event binding (autoload-style per-run listener)
	var sfx_binder := Node.new()
	sfx_binder.set_script(preload("res://scripts/audio/sfx_binder.gd"))
	sfx_binder.name = "SfxBinder"
	add_child(sfx_binder)
	AudioManager.apply_saved_volumes()

	# Combat juice: 3D damage numbers, kill bursts, level-up ring (V5)
	var juice := Node.new()
	juice.set_script(preload("res://scripts/combat/juice_manager.gd"))
	juice.name = "JuiceManager"
	add_child(juice)
	juice.setup(player)

	# Juice/pet/projectile VFX belong to the pausable world too
	juice.process_mode = Node.PROCESS_MODE_PAUSABLE

	# V8 procedural music with state-driven intensity
	var music := Node.new()
	music.set_script(preload("res://scripts/audio/music_director.gd"))
	music.name = "MusicDirector"
	add_child(music)
	music.build_music()
	music.set_intensity(0)  # calm
	EventBus.game_state_changed.connect(func(new_state, _old):
		if new_state == GameManager.State.BOSS:
			music.set_intensity(2)
		elif new_state == GameManager.State.PLAYING:
			music.set_intensity(0 if RunManager.elapsed_time < 300.0 else 1)
	)

	# Boss death → back to PLAYING state
	EventBus.boss_died.connect(_on_boss_died)

	if DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		touch_controls.visible = true
	else:
		touch_controls.visible = false
	_apply_mouse_mode(GameManager.state)
	# Release/capture the cursor as game states change (menus/level-up need
	# a visible cursor; gameplay locks it for unbounded camera rotation).
	EventBus.game_state_changed.connect(_on_game_state_changed_for_mouse)

	debug_label.visible = false

	# First-run tutorial: step-by-step controls before the action starts
	$HUD/TutorialOverlay.show_if_needed()
	# Headless tests: never leave the tree paused by tutorial/UI
	if DisplayServer.get_name() == "headless" or OS.has_feature("headless"):
		get_tree().paused = false

func _on_game_state_changed_for_mouse(new_state: int, _old: int) -> void:
	_apply_mouse_mode(new_state)

func _apply_mouse_mode(state: int) -> void:
	if DisplayServer.is_touchscreen_available():
		return
	match state:
		GameManager.State.PLAYING, GameManager.State.BOSS:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func get_enemy_manager() -> Node:
	return enemy_manager

func _on_boss_died() -> void:
	RunManager.set_boss_active(false)
	if GameManager.state == GameManager.State.BOSS:
		GameManager.change_state(GameManager.State.PLAYING)

func _unhandled_input(event: InputEvent) -> void:
	if InputManager.is_pause_just_pressed():
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F3:
			_debug_enabled = not _debug_enabled
			debug_label.visible = _debug_enabled
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		# Click-to-recapture: web pointer lock can be exited by the browser
		# (Esc); re-lock on the next click during active gameplay.
		if not DisplayServer.is_touchscreen_available():
			if GameManager.state == GameManager.State.PLAYING and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				_apply_mouse_mode(GameManager.State.PLAYING)

func _toggle_pause() -> void:
	if GameManager.state == GameManager.State.PLAYING or GameManager.state == GameManager.State.BOSS:
		GameManager.pause_game()
	elif GameManager.state == GameManager.State.PAUSED:
		GameManager.resume_game()

func _process(_delta: float) -> void:
	if _debug_enabled:
		debug_label.text = PerformanceManager.get_debug_info()
		debug_label.size.y = 0  # let multi-line text size itself
