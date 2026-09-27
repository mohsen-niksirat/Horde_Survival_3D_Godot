extends SceneTree
## V8 validation: three music layers build as looped streams, intensity
## cross-fades by game state, cached once.

var failures := 0

func _initialize() -> void:
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(6):
		await process_frame
		await physics_frame

	var music: Node = main.get_node_or_null("MusicDirector")
	_check(music != null, "MusicDirector exists")
	_check(music._built, "3 layers built")
	_check(music._players.size() == 3, "calm/tense/boss players (%d)" % music._players.size())
	for key in music._players:
		var p: AudioStreamPlayer = music._players[key]
		_check(p.stream is AudioStreamWAV, "layer %s is WAV" % str(key))
		_check(p.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "layer loops")
	_check(music._current == 0, "starts CALM")

	# --- Boss intensity switch ---
	var game_manager := root.get_node("GameManager")
	game_manager.change_state(game_manager.State.BOSS)
	await process_frame
	_check(music._current == 2, "boss intensity on BOSS state")

	game_manager.change_state(game_manager.State.PLAYING)
	await process_frame
	_check(music._current == 0, "back to calm on PLAYING")

	# --- V8 FIX: music respects master_volume via Master bus ---
	var audio: Node = root.get_node("AudioManager")
	# All music players must route through Master bus
	for key in music._players:
		var p: AudioStreamPlayer = music._players[key]
		_check(p.bus == "Master", "music layer %s on Master bus" % str(key))
	# Setting master_volume=0 must mute everything
	audio.set_volumes(0.0, 0.5, 0.5)
	await process_frame
	var muted_db := linear_to_db(clampf(0.0 * 0.5, 0.001, 1.0))
	for key in music._players:
		var p: AudioStreamPlayer = music._players[key]
		if not p.playing:
			continue
		_check(p.volume_db <= -70.0, "music layer %s muted at master=0" % str(key))
	# Restore volumes
	audio.set_volumes(1.0, 0.7, 0.8)

	# --- V8 FIX: notes are not sub-bass (no muddy drone) ---
	_check(music.CALM_NOTES.min() >= 110.0, "calm notes start at A2+ (no 55Hz drone)")

	if failures == 0:
		print("V8_AUDIO_PASS")
	else:
		print("V8_AUDIO_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
