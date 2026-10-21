extends Node
## Lightweight, opt-in local analytics.
##
## Nothing ever leaves the device: the counters are kept in the save file
## and shown in the menu, so balance decisions can be made from real
## numbers without a server or a tracking script.
##
## The player has to turn it on explicitly in the Settings menu
## (`analytics_enabled`). While it is off, no run data is recorded at all.

## Run facts we want to know for balance decisions.
const TRACKED_RUNS := 25

var enabled: bool = false
## Aggregated counters: key -> value.
var _counters: Dictionary = {}
## Recent run records, newest first. Each is a small dictionary.
var _runs: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = bool(SaveManager.get_setting("analytics_enabled", false))
	_load()

func set_enabled(value: bool) -> void:
	enabled = value
	SaveManager.set_setting("analytics_enabled", value)
	if not value:
		# Turning it off clears the collected data.
		_counters.clear()
		_runs.clear()
		_save()

## Record the end of a run. Called from the run-end hook.
func record_run(victory: bool, elapsed_time: float, level: int, kills: int, weapon_ids: Array) -> void:
	if not enabled:
		return
	_counters["runs"] = int(_counters.get("runs", 0)) + 1
	if victory:
		_counters["victories"] = int(_counters.get("victories", 0)) + 1
	_counters["total_time"] = float(_counters.get("total_time", 0.0)) + elapsed_time
	_counters["total_kills"] = int(_counters.get("total_kills", 0)) + kills
	_counters["total_level"] = int(_counters.get("total_level", 0)) + level
	_runs.push_front({
		"victory": victory,
		"time": elapsed_time,
		"level": level,
		"kills": kills,
		"weapons": weapon_ids.duplicate(),
	})
	while _runs.size() > TRACKED_RUNS:
		_runs.pop_back()
	_save()

## A human-readable summary for the menu.
func summary() -> String:
	if not enabled:
		return "Analytics: OFF (no data is recorded)"
	var runs: int = int(_counters.get("runs", 0))
	if runs == 0:
		return "Analytics: ON — no runs recorded yet"
	var victories: int = int(_counters.get("victories", 0))
	var avg_time: float = float(_counters.get("total_time", 0.0)) / float(runs)
	var avg_kills: float = float(_counters.get("total_kills", 0)) / float(runs)
	var avg_level: float = float(_counters.get("total_level", 0)) / float(runs)
	return "Analytics: ON — %d runs · %d wins (%.0f%%) · avg %.0fs · avg %d kills · avg level %.1f" % [
		runs, victories, 100.0 * float(victories) / float(runs), avg_time, int(avg_kills), avg_level,
	]

## The most common weapon in the recorded runs — helps spot dead picks.
func most_used_weapon() -> String:
	var counts: Dictionary = {}
	for r in _runs:
		for wid in r.get("weapons", []):
			counts[wid] = int(counts.get(wid, 0)) + 1
	var best := ""
	var best_count := 0
	for wid in counts:
		if int(counts[wid]) > best_count:
			best = str(wid)
			best_count = int(counts[wid])
	return best

## The average run length in minutes per death phase bucket, e.g. how many
## runs ended in each 5-minute band.
func death_phase_buckets() -> Dictionary:
	var out: Dictionary = {}
	for r in _runs:
		if bool(r.get("victory", false)):
			continue
		var band := int(float(r.get("time", 0.0)) / 300.0) * 5
		out[band] = int(out.get(band, 0)) + 1
	return out

func _load() -> void:
	var saved = SaveManager.get_meta_data("analytics", null)
	if typeof(saved) != TYPE_DICTIONARY:
		_counters = {}
		_runs = []
		return
	_counters = saved.get("counters", {})
	_runs = saved.get("runs", [])

func _save() -> void:
	SaveManager.set_meta_data("analytics", {
		"counters": _counters,
		"runs": _runs,
	})
