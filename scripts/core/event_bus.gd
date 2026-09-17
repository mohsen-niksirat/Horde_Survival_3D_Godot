extends Node
## Central signal hub. Systems communicate through EventBus to stay decoupled.

# --- Game flow ---
signal game_state_changed(new_state: int, old_state: int)
signal run_started()
signal run_ended(victory: bool)

# --- Combat ---
signal enemy_died(enemy: Node, position: Vector3)
signal enemy_damaged(enemy: Node, amount: float, is_crit: bool)
signal player_damaged(amount: float)
signal player_died()

# --- Progression ---
signal xp_collected(amount: float)
signal player_leveled_up(new_level: int)
signal upgrade_applied(upgrade_id: String)
signal gold_collected(amount: float)

# --- Spawning ---
signal enemy_spawned(enemy: Node)
signal boss_spawned(boss: Node)
signal boss_died()

# --- Misc ---
signal combo_changed(count: int, multiplier: float)
signal settings_changed()
## Magnet pickup: XP shards start a soft staggered pull for N seconds.
signal magnet_pulse(duration: float)
