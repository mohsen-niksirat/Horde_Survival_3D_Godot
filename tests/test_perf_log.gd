extends SceneTree
## PerfLog: sampler captures per-second rows during a run and produces a report.

func _initialize() -> void:
	var ok := true
	# Autoloads are not global identifiers in --script mode; reach via root.
	var pm = root.get_node_or_null("PerformanceManager")
	var rm = root.get_node_or_null("RunManager")
	if pm == null or rm == null:
		print("PERFLOG_TEST SKIP: autoloads not present in script mode")
		quit(0)
		return
	pm.start_perf_logging()
	if not pm.perf_logging:
		ok = false
		print("FAIL: perf_logging not enabled")
	rm.is_running = true
	rm.elapsed_time = 65.0
	pm.update_horde_pressure(30)
	pm._perf_tick(1.0)
	pm._perf_tick(1.0)
	if pm._perf_samples.size() < 1:
		ok = false
		print("FAIL: no samples captured")
	var report: String = pm.stop_perf_logging()
	if report.find("PerfLog report") < 0 or report.find("minute,fps,enemies") < 0:
		ok = false
		print("FAIL: report malformed")
	if pm.perf_logging:
		ok = false
		print("FAIL: still logging after stop")
	rm.is_running = false
	print("PERFLOG_TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
