extends Control
## Boot scene: loading text, then straight to the main menu.
## Web builds get a "Click to Play" gate (user gesture unlocks audio +
## enables fullscreen-friendly input) — desktop skips it.

@onready var click_label: Label = $ClickLabel

var _waiting_for_click: bool = false
var _load_phase: int = 0  # 0=none, 1=prewarm, 2=ready

func _ready() -> void:
	await get_tree().process_frame
	AudioManager.apply_saved_volumes()
	# V21A: warm up common resources in the background during the click-gate
	# so the menu doesn't hitch on first render. Only native; Web uses its
	# own thread-safe warmup in Main so we don't block the click gate.
	if OS.get_name() != "Web" and DisplayServer.get_name() != "headless":
		_prefetch_resources()
	if OS.get_name() == "Web":
		click_label.visible = true
		_waiting_for_click = true
	else:
		_go_menu()

# V21A: fire-and-forget warmup of the most-hit resources during the
# interactive click-gate window. No await / no blocking of _go_menu.
func _prefetch_resources() -> void:
	if _load_phase != 0:
		return
	_load_phase = 1
	var paths := [
		"res://scenes/menu/MainMenu.tscn",
		"res://data/characters/mage.tres",
		"res://data/characters/paladin.tres",
		"res://data/characters/rogue.tres",
		"res://data/weapons/fireball.tres",
		"res://data/weapons/magic_missile.tres",
	]
	for p in paths:
		if ResourceLoader.exists(p):
			ResourceLoader.load_threaded_request(p)
	_load_phase = 2

## V22A: Web single-threaded warmup — ResourceLoader.load_threaded_request is
## a no-op without threads, so GLBs would sync-load on first spawn mid-run.
## On weak devices a single big GLB can still dominate a frame; skip model
## warmup on VERY_LOW so the click-gate stays snappy and the first-spawn
## hitch is just a bit larger instead of freezing the menu.
func _web_warmup() -> void:
	if _load_phase != 0:
		return
	_load_phase = 1
	var paths := [
		"res://scenes/menu/MainMenu.tscn",
		"res://scenes/menu/CharacterSelect.tscn",
		"res://data/characters/mage.tres",
		"res://data/characters/paladin.tres",
		"res://data/characters/rogue.tres",
		"res://data/weapons/magic_missile.tres",
		"res://data/weapons/fireball.tres",
	]
	# Model warmup only when the device already runs a higher tier — weak
	# laptops pay the same one-time cost later during the first enemy spawn.
	if PerformanceManager == null or PerformanceManager.quality > PerformanceManager.Quality.VERY_LOW:
		paths.append_array([
			"res://assets/models/kaykit/heroes/adventurer_mage.glb",
			"res://assets/models/heroes/hero_mage.glb",
			"res://assets/models/enemies/enemy_drone.glb",
			"res://assets/models/enemies/enemy_wisp.glb",
		])
	for p in paths:
		if ResourceLoader.exists(p):
			var _r = ResourceLoader.load(p)
		await get_tree().process_frame
	_load_phase = 2

func _input(event: InputEvent) -> void:
	if not _waiting_for_click:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		_waiting_for_click = false
		click_label.visible = false
		# Warm the hot resources while the user transitions to the menu —
		# the loads happen across frames, not in one hitch.
		_web_warmup()
		_go_menu()

func _go_menu() -> void:
	GameManager.goto_menu()
