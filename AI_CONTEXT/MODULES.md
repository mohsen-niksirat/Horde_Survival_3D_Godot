# Modules & Interfaces — HordeSurvival 3D

## 1. Core Singletons (Autoloads)

### `GameManager` ([`scripts/core/game_manager.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/core/game_manager.gd))
- **Responsibility**: Global game state management, scene flow, pointer capture synchronization, and mobile back-button coordination.
- **Key Symbols**:
  - `enum State { BOOT, MAIN_MENU, CHARACTER_SELECT, GAME_START, PLAYING, LEVEL_UP, BOSS, PAUSED, GAME_OVER, RESULTS }`
  - `state: int`: Current state enum value.
  - `selected_character_id: String`: Currently chosen character identifier.
  - `change_state(new_state: int) -> void`: Emits `EventBus.game_state_changed` and synchronizes pointer capture.
  - `start_game() -> void`: Transitions to `GAME_START` and switches to `Main.tscn`.
  - `goto_menu() -> void`: Transitions to `MAIN_MENU` and switches to `MainMenu.tscn`.
  - `pause_game() -> void` / `resume_game() -> void`: Toggles tree pause and enters/exits `PAUSED`.
  - `open_level_up() -> void` / `close_level_up() -> void`: Pauses/unpauses gameplay for upgrade selection.
  - `game_over(victory: bool) -> void`: Concludes run, emits `EventBus.run_ended`, and triggers analytics logging.
  - `handle_back_request() -> bool`: Evaluates back button events across pause, level-up, and menu contexts.

### `EventBus` ([`scripts/core/event_bus.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/core/event_bus.gd))
- **Responsibility**: Central decoupled signal dispatch hub.
- **Key Signals**:
  - `game_state_changed(new_state: int, old_state: int)`
  - `run_started()` / `run_ended(victory: bool)`
  - `enemy_died(enemy: Node, position: Vector3)`
  - `enemy_damaged(enemy: Node, amount: float, is_crit: bool)`
  - `player_damaged(amount: float)` / `player_died()`
  - `xp_collected(amount: float)` / `player_leveled_up(new_level: int)`
  - `upgrade_applied(upgrade_id: String)` / `gold_collected(amount: float)`
  - `enemy_spawned(enemy: Node)` / `boss_spawned(boss: Node)` / `boss_died()`
  - `boss_phase_changed(phase_name: String, color: Color)`
  - `combo_changed(count: int, multiplier: float)`
  - `achievement_unlocked(id: String, title: String, gold: int)`
  - `exit_confirm_requested()` / `app_paused()` / `app_resumed()`

### `RunManager` ([`scripts/core/run_manager.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/core/run_manager.gd))
- **Responsibility**: Tracks run duration, kill tallies, gold earned, endless milestones, and campaign objectives.
- **Key Symbols**:
  - `is_running: bool`, `endless: bool`, `elapsed_time: float`, `kills: int`, `gold_earned: float`
  - `mission: Resource`: Active `MissionData` resource.
  - `start_run(is_endless: bool = false) -> void`: Resets run metrics and starts tracking.
  - `set_mission(m: Resource) -> void`: Configures win criteria (`survive_time`, `kill_count`, `kill_boss`).
  - `record_kill() -> void`, `add_gold(amount: float) -> void`
  - `signal time_changed(elapsed: float)`, `signal kills_changed(kills: int)`, `signal endless_milestone(minutes: int)`

### `SaveManager` ([`scripts/save/save_manager.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/save/save_manager.gd))
- **Responsibility**: Encapsulates persistence across desktop and Web (IndexedDB via `user://`).
- **Key Symbols**:
  - `const SAVE_PATH := "user://meta_save.json"`
  - `save_game() -> void`: Writes to `.tmp` file and swaps atomically.
  - `load_game() -> void`: Reads and migrates JSON into internal `data: Dictionary`.
  - `get_meta_data(key: String, default_val = null)` / `set_meta_data(key: String, val) -> void`
  - `get_setting(key: String, default_val = null)` / `set_setting(key: String, val) -> void`
  - `signal save_loaded()`

### `InputManager` ([`scripts/input/input_manager.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/input/input_manager.gd))
- **Responsibility**: Abstracts keyboard, mouse pointer capture, gamepad, and touch controls.
- **Key Symbols**:
  - `get_move_vector() -> Vector2`: Normalized directional movement vector.
  - `get_look_delta() -> Vector2`: Scaled camera rotational offset.
  - `is_action_pressed(action: String) -> bool`
  - `capture_pointer() -> void` / `release_pointer() -> void`
  - `set_touch_move(vec: Vector2) -> void` / `set_touch_look(delta: Vector2) -> void`
  - `notify_back_requested() -> bool`

### `PerformanceManager` ([`scripts/performance/performance_manager.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/performance/performance_manager.gd))
- **Responsibility**: Dynamic resolution scaling, entity caps, quality preset enforcement, and profiling.
- **Key Symbols**:
  - `enum Quality { VERY_LOW, LOW, MEDIUM, HIGH, ULTRA }`
  - `effective_enemy_cap() -> int`: Returns current enemy limit scaled for quality, platform (Web/Mobile), and stress mode.
  - `effective_projectile_cap() -> int`
  - `set_quality(tier: int) -> void`
  - `signal quality_changed(tier: int)`

### `PoolManager` ([`scripts/utilities/pool_manager.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/utilities/pool_manager.gd))
- **Responsibility**: Generalized object pooler eliminating runtime instantiation hitching.
- **Key Symbols**:
  - `create_pool(scene_path: String, prewarm: int = 0) -> void`
  - `acquire(scene_path: String) -> Node`
  - `release(scene_path: String, node: Node) -> void`: Adds node to queue for safe deferred recycling.

### `Localization` ([`scripts/core/localization.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/core/localization.gd))
- **Responsibility**: Parses `locale/en.csv` and `locale/fa.csv` at runtime; adjusts UI layout direction (LTR vs RTL).
- **Key Symbols**:
  - `current_locale: String` ("en" or "fa")
  - `set_locale(loc: String) -> void`: Applies translation catalog and configures RTL mirroring.

---

## 2. Gameplay & Combat Systems

### `EnemyManager` ([`scripts/spawning/enemy_manager.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/spawning/enemy_manager.gd))
- **Responsibility**: Manages active enemies, enforces per-frame spawn budgets, maintains spatial hash grid, and performs distance culling.
- **Key Symbols**:
  - `active_enemies: Array`
  - `queue_spawn(data: EnemyData, position: Vector3, player: Node3D, ...) -> bool`: Adds enemy spawn request to queue.
  - `get_enemies_in_radius(pos: Vector3, radius: float) -> Array`: Efficient spatial query using 8m hash cells.
  - `get_nearest_enemy(pos: Vector3) -> Node`

### `WaveManager` ([`scripts/spawning/wave_manager.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/spawning/wave_manager.gd))
- **Responsibility**: Spawns regular waves, calculates threat budgets, schedules elite encounters, and spawns the boss.
- **Key Symbols**:
  - `setup(world: Node3D, player: CharacterBody3D, enemy_mgr: Node) -> void`
  - `tick_wave(delta: float) -> void`: Evaluates spawn timer against threat budget and difficulty timeline.

### `WeaponController` ([`scripts/weapons/weapon_controller.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/weapons/weapon_controller.gd))
- **Responsibility**: Owns equipped weapons, ticks cooldowns, instantiates projectile/orbit/aoe attacks.
- **Key Symbols**:
  - `weapons: Array[WeaponInstance]`
  - `add_weapon(weapon_data: WeaponData) -> void`: Instantiates and equips new weapon.
  - `upgrade_weapon(weapon_id: String) -> void`: Increments weapon tier level.
  - `evolve_weapon(base_id: String, evolution_data: WeaponData) -> void`

### `ProgressionManager` ([`scripts/progression/progression_manager.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/progression/progression_manager.gd))
- **Responsibility**: Generates 3 upgrade cards on level up, applies passive and weapon upgrades, and handles evolutions.
- **Key Symbols**:
  - `setup(player: CharacterBody3D) -> void`
  - `generate_upgrade_options() -> Array[UpgradeOption]`: Evaluates eligible weapon upgrades, new weapons, and passives.
  - `apply_upgrade(option: UpgradeOption) -> void`

---

## 3. Player Subsystems & Components

### `Player` ([`scenes/player/player.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scenes/player/player.gd))
- **Root Node**: `CharacterBody3D`
- **Child Components**:
  - `movement` ([`scripts/player/movement_component.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/player/movement_component.gd)): Velocity steering and bounds checking.
  - `dash` ([`scripts/player/dash_component.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/player/dash_component.gd)): Burst impulse and temporary invulnerability.
  - `health` ([`scripts/combat/health_component.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/combat/health_component.gd)): HP container, armor calculation, take_damage().
  - `experience` ([`scripts/player/experience_component.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/player/experience_component.gd)): Level progression curve.
  - `weapon_controller` ([`scripts/weapons/weapon_controller.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/weapons/weapon_controller.gd)): Equipped weaponry.
  - `camera_rig` ([`scripts/player/camera_rig.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/player/camera_rig.gd)): SpringArm3D third-person camera.
  - `stat_block` ([`scripts/core/stat_block.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/core/stat_block.gd)): Modifiable stats (`max_hp`, `move_speed`, `pickup_radius`, `might`, `cooldown_reduction`, `armor`, `crit_chance`, `xp_gain`).
