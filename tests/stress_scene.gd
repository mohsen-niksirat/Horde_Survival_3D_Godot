extends Node3D
## DEV-ONLY stress scene: forces ~250 enemies around the player with the
## current horde systems so frame costs can be measured on real hardware.
## Not part of the normal game flow. Run:
##   godot --path . res://tests/StressScene.tscn

const TARGET_ENEMIES := 250
const RING_RADIUS := 12.0

@onready var player: CharacterBody3D = $World/Player

func _ready() -> void:
	# Force HIGH quality tier so caps don't interfere with measurement.
	PerformanceManager.set_quality(PerformanceManager.Quality.ULTRA, false)

	var em: Node = get_node_or_null("EnemyManager")
	if em == null:
		# Mirror Main.gd wiring when run standalone
		em = Node.new()
		em.set_script(load("res://scripts/spawning/enemy_manager.gd"))
		em.name = "EnemyManager"
		add_child(em)

	var projectile_root := Node3D.new()
	projectile_root.name = "Projectiles"
	add_child(projectile_root)
	player.bind_combat(em, projectile_root)
	player.add_to_group("player")

	var drone: EnemyData = load("res://data/enemies/basic_drone.tres")
	var bat: EnemyData = load("res://data/enemies/swarm_bat.tres")
	var tank: EnemyData = load("res://data/enemies/tank_golem.tres")

	# Ring-burst spawn: 60% drones, 30% bats, 10% tanks
	for i in range(TARGET_ENEMIES):
		var angle := TAU * i / float(TARGET_ENEMIES)
		var pos := player.global_position + Vector3(cos(angle), 0, sin(angle)) * (RING_RADIUS + (i % 5) * 2.0)
		pos.x = clampf(pos.x, -58, 58)
		pos.z = clampf(pos.z, -58, 58)
		var data: EnemyData = drone
		if i % 10 == 0:
			data = tank
		elif i % 3 == 0:
			data = bat
		em.queue_spawn(data, pos, player, 1.0, 1.0, 1.0)

	# Debug overlay on by default in the stress scene
	var hud_label := Label.new()
	hud_label.name = "StressLabel"
	hud_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud_label.position = Vector2(12, 12)
	hud_label.add_theme_font_size_override("font_size", 14)
	add_child(hud_label)
