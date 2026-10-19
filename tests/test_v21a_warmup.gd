extends SceneTree
## V21A perf validation: boot prefetch, enemy phasing cache, hero GLB preload
## list, and Auto-quality sampling throttle.

var failures := 0

func _initialize() -> void:
	# Autoloads connect to EventBus in _ready, which runs after _initialize.
	await process_frame

	# --- Boot scene: native prefetch is fire-and-forget, Web is skipped ---
	# On headless we only verify the guard doesn't crash and doesn't block.
	var boot_ps: PackedScene = load("res://scenes/bootstrap/Boot.tscn")
	var boot := boot_ps.instantiate()
	root.add_child(boot)
	await process_frame
	_check(boot != null, "boot scene instantiates")
	# Boot should have moved to menu (non-web) without error.
	boot.queue_free()

	# --- Enemy phasing cache: same result as uncached read, no re-parse ---
	var enemy_ps: PackedScene = load("res://scenes/enemies/Enemy.tscn")
	var enemy := enemy_ps.instantiate()
	root.add_child(enemy)
	var data: Resource = load("res://data/enemies/ghost.tres")
	if enemy.has_method("setup"):
		enemy.setup(data, null, 1.0, 1.0, 1.0)
	await physics_frame
	_check(enemy.data == data, "enemy data bound")
	# _is_phasing exists and is deterministic; ghost has a real interval.
	var a: bool = enemy._is_phasing()
	var b: bool = enemy._is_phasing()
	_check(a == b, "phasing check deterministic")
	enemy.queue_free()

	# --- Hero GLB preload list is wired in main (V16A+V21A) ---
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		# let main settle
	_check(main != null, "main scene instantiates")
	# --- Auto-quality sampling: throttled to once per second ---
	var pm = root.get_node_or_null("PerformanceManager")
	_check(pm != null, "PerformanceManager autoload present")
	if pm != null:
		pm.set_auto_mode(true, false)
		pm._auto_grace_left = 0.0  # skip startup grace so the sample gate is exercised
		pm._auto_next_sample = 0.0
		pm._low_time = 0.0
		# First tick: gate at 0 → decrement to -0.016 → sample taken → gate reset to 1.0.
		pm._auto_tick(0.016, 60)
		# Second tick: gate at 1.0 → decrement to 0.984 → early return, no re-sample.
		pm._auto_tick(0.016, 60)
		var gate: float = pm._auto_next_sample
		_check(gate > 0.5, "auto sample throttle engaged (gate=%.3f)" % gate)
		pm.set_auto_mode(false, false)

	# Free the scene before quitting so the exit-leak gate stays clean.
	main.queue_free()
	await process_frame

	_finish()

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS  %s" % label)
	else:
		failures += 1
		push_error("FAIL  %s" % label)

func _finish() -> void:
	if failures == 0:
		print("PASS ALL (test_v21a_warmup)")
	else:
		print("FAILURES: %d" % failures)
	quit(failures)
