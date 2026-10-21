extends SceneTree
## Balance table: DPS for every weapon at every tier.
##
## Prints a markdown table so the balance pass can be reviewed against the
## difficulty timeline. Run headless:
##   godot --headless --path . --script tools/balance_table.gd
##
## The numbers come straight from the .tres data (no hardcoding), so the
## table always reflects what the game actually does.

const WEAPON_DIR := "res://data/weapons/"

func _initialize() -> void:
	await process_frame

	var files := _weapon_files()
	if files.is_empty():
		print("BALANCE_TABLE_FAIL no weapons found")
		quit(1)
		return

	var rows: Array = []
	for path in files:
		var res: Resource = load(path)
		# data/weapons also holds evolution resources (evo_*.tres) with a
		# different script class — only base weapons belong in this table.
		if not (res is WeaponData):
			continue
		var data: WeaponData = res
		var per_tier: Array = []
		for lvl in range(1, 6):
			per_tier.append(WeaponBalance.dps_at(data, lvl))
		rows.append({"data": data, "dps": per_tier})

	rows.sort_custom(func(a, b): return a["dps"][0] > b["dps"][0])

	print("| Weapon | Type | L1 | L2 | L3 | L4 | L5 | L1→L5 growth |")
	print("|---|---|---|---|---|---|---|---|")
	for row in rows:
		var d: WeaponData = row["data"]
		var dps: Array = row["dps"]
		var cells: Array = []
		for v in dps:
			cells.append("%.1f" % v)
		var growth := "%.2fx" % (dps[dps.size() - 1] / maxf(dps[0], 0.01))
		print("| %s | %s | %s | %s |" % [
			d.display_name, d.type,
			" | ".join(cells), growth,
		])

	# Sanity report: the biggest gap between adjacent tiers is a red flag
	# for a weapon that spikes out of line with the difficulty curve.
	print("")
	print("### Tier-5 outliers")
	var dps_values: Array = []
	for row in rows:
		dps_values.append(float(row["dps"][4]))
	var lo: float = dps_values.min()
	var hi: float = dps_values.max()
	print("min=%.1f max=%.1f ratio=%.2f" % [lo, hi, hi / maxf(lo, 0.01)])
	for row in rows:
		var d: WeaponData = row["data"]
		var v: float = row["dps"][4]
		if v < lo * 1.25:
			print("WEAK  %s tier5=%.1f" % [d.display_name, v])
		elif v > hi * 0.8:
			print("STRONG %s tier5=%.1f" % [d.display_name, v])

	print("BALANCE_TABLE_OK")
	quit(0)

## Sustained damage-per-second against a SINGLE target.
## The model lives in scripts/weapons/weapon_balance.gd so this tool, the
## balance guard test and the in-game codex always agree.

func _weapon_files() -> Array:
	var out: Array = []
	var dir := DirAccess.open(WEAPON_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".tres"):
			out.append(WEAPON_DIR + f)
	out.sort()
	return out
