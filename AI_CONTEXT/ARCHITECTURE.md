# Architecture — HordeSurvival 3D

## 1. Architectural Philosophy
HordeSurvival 3D is architected around six core tenets:
1. **Data-Driven Composition**: Content (weapons, passives, characters, enemies, relics, missions) lives in `.tres` Resource definitions rather than hard-coded scene logic.
2. **Component-Based Entities**: Godot scene trees act as composition roots. Entities (Player, Enemy, Boss) aggregate lightweight `Node` components (`HealthComponent`, `MovementComponent`, `DashComponent`, `ExperienceComponent`, `EliteComponent`).
3. **Decoupled Event Bus**: Systems communicate via typed signals hosted on `EventBus`, minimizing circular dependencies between gameplay layers.
4. **Zero Allocations in Hot Paths**: `_process` and `_physics_process` loops avoid array instantiations, string operations, and dynamic node lookups during active horde combat.
5. **Spatial Partitioning Over Physics Scans**: Physics body checks and $O(n^2)$ scene tree scans (`get_nodes_in_group()`) are replaced with an 8-meter uniform spatial hash grid in `EnemyManager`. Enemies use lightweight spatial movement rather than heavy physics nodes.
6. **Graceful Platform Degradation**: Dynamic resolution scaling and quality-tier entity caps automatically scale fidelity between high-end desktop rigs, mid-range Android devices, and single-threaded WebGL2 browser tabs.

---

## 2. Global State & Control Flow

```
[BOOT] (Boot.tscn)
  │
  ▼
[MAIN_MENU] (MainMenu.tscn) ◄────────────────────────┐
  │                                                   │
  ├──► [CHARACTER_SELECT]                             │
  │         │                                         │
  │         ▼                                         │
  └──► [GAME_START]                                   │
            │                                         │
            ▼                                         │
       [PLAYING] (Main.tscn)                          │
            ▲           │                             │
            │           ├──► [LEVEL_UP] (paused)      │
            │           │         │                   │
            │           │         ▼                   │
            │           │      (resume)               │
            │           │                             │
            │           ├──► [PAUSED] (paused)        │
            │           │         │                   │
            │           │         ▼                   │
            │           │      (resume)               │
            │           │                             │
            │           └──► [BOSS] (sub-state)       │
            │                     │                   │
            ▼                     ▼                   │
       [GAME_OVER] / [RESULTS] ───────────────────────┘
```

- **Pointers & Mouse Capture**:
  - `GameManager._sync_pointer()` captures mouse input (`Input.MOUSE_MODE_CAPTURED`) only during `PLAYING` and `BOSS` on non-mobile desktop environments.
  - Pausing, level up, menus, and game over unconditionally release the cursor (`Input.MOUSE_MODE_VISIBLE`) and notify web browser pointer-lock handlers.
- **Android Back Button Lifecycle**:
  - `NOTIFICATION_WM_GO_BACK_REQUEST` routes to `GameManager.handle_back_request()`.
  - In-game: triggers pause.
  - In overlays (Pause, Level Up): closes overlay and resumes.
  - In menus: closes sub-panels (Codex, Shop, Character Select), or emits `exit_confirm_requested` on the root menu.
  - `NOTIFICATION_APPLICATION_PAUSED`: automatically pauses the run and synchronously invokes `SaveManager.save_game()`.

---

## 3. Core Subsystems & Boundaries

### 3.1 Combat Pipeline
```
[WeaponInstance / Attack]
          │
          ▼
    DamageEvent (amount, crit, element, knockback, source)
          │
          ▼
   [HealthComponent.take_damage()]
          │
          ├──► Check invincibility frame
          ├──► Armor mitigation: dmg = dmg * (100 / (100 + armor))
          ├──► Health deduction: current_hp = max(0, current_hp - dmg)
          ├──► Spawn floating damage number (JuiceManager / PoolManager)
          ├──► Emit EventBus.enemy_damaged / player_damaged
          └──► If current_hp <= 0:
                   ├──► Emit HealthComponent.died
                   └──► Emit EventBus.enemy_died (triggers Loot + Combo + Run stats)
```

- **Damage Numbers & Juice**: Floating text is instantiated through `PoolManager` with cached format strings to prevent heap churn.
- **Status Effects**: `StatusComponent` ticks active burn, slow, and freeze modifiers independently, updating visual tints and movement speed multipliers.

---

### 3.2 Spawning & Spatial Grid
- **Hitch Guard**: `EnemyManager` enforces a frame admission cap (`MAX_SPAWNS_PER_FRAME = 8`, down to 2–4 under web or stress conditions). Excess spawns queue up in `_spawn_queue` (capped at 48).
- **Spatial Hash**:
  - Grid cell size: 8.0 meters.
  - Rebuilt lazily: throttled to 100 ms intervals (`GRID_REBUILD_MS = 100`) or marked dirty.
  - Queries (`get_enemies_in_radius()`, `get_nearest_enemy()`) inspect only bounding neighborhood cells.
- **Culling**: Enemies wandering beyond 55.0 meters (`CULL_DISTANCE`) from the player are released back into the pool.

---

### 3.3 Object Pooling Lifecycle
- Managed by `PoolManager` (`scripts/utilities/pool_manager.gd`).
- `create_pool(scene_path, prewarm)` creates a pool with an instantiated free list.
- `acquire(scene_path)` retrieves or instantiates nodes.
- `release(node)` places nodes into a deferred release queue processed during `_process()`, protecting against node tree mutation mid-physics iteration.
- `_retain_render_resources()` preserves Mesh and Material references during teardown to avoid memory spikes or GPU asset leaks.

---

### 3.4 Input Abstraction Layer
- `InputManager` (`scripts/input/input_manager.gd`) isolates game logic from raw input hardware:
  - `get_move_vector()`: Combines WASD/Arrow keys, gamepad left stick, and mobile virtual joystick.
  - `get_look_delta()`: Combines pointer-locked mouse motion, gamepad right stick, and touch camera drag region.
  - `is_action_pressed()`: Reads Dash, Ability 1, Ability 2, and Pause across desktop, mobile touch overlays, and gamepads.
  - `safe_area.gd`: Queries `DisplayServer.get_display_safe_area()` to adjust UI margins for Android camera cutouts and navigation bars.

---

### 3.5 Persistence & Save Model
- Managed by `SaveManager` (`scripts/save/save_manager.gd`).
- File target: `user://meta_save.json` (maps directly to IndexedDB in web browsers via Emscripten).
- **Atomic Write Guard**: Saves are written to `user://meta_save.json.tmp` and swapped into place using `DirAccess.rename_absolute()`.
- **Schema Migration**: Versioned via `SAVE_VERSION = 1`. Old saves undergo deep-merging with `_default_data()` to ensure missing properties receive valid fallback defaults without overwriting existing player achievements or currency.

---

### 3.6 Performance Management & Dynamic Fidelity
- Managed by `PerformanceManager` (`scripts/performance/performance_manager.gd`).
- **Quality Tiers**:
  - `VERY_LOW`, `LOW`, `MEDIUM`, `HIGH`, `ULTRA`, plus `AUTO`.
  - Controls hard caps for enemies (40–220), projectiles (40–180), particles (25–140), and damage numbers (12–50).
- **Web & Mobile Scaling**: Automatically multiplies caps by 0.45x–0.7x on Web/Mobile to protect the single-threaded JavaScript/WASM runtime.
- **Dynamic 3D Resolution Scaling**:
  - Monitors runtime FPS over a 1.5s sliding window (`DYN_CHECK_WINDOW`).
  - If FPS falls below 46 (`DYN_LOW_FPS`), viewport render scale steps down by 0.08 down to a 0.4 floor.
  - If frame rate does not improve (indicating a CPU bottleneck), resolution steps back up and triggers a 20-second cooldown (`DYN_COOLDOWN`).
