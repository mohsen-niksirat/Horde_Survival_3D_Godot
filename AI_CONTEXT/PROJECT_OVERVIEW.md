# Project Overview — HordeSurvival 3D

## 1. Executive Summary & Purpose
**HordeSurvival 3D** is an open-source, stylized third-person survival roguelite / horde auto-shooter. Players navigate a 3D arena, evading enemy swarms while auto-firing weapon arsenals, collecting XP orbs, selecting synergies and upgrades on level-up, evolving weapons, defeating elites, and facing a multi-phase boss encounter.
The project is designed Web-first for zero-install instant play via WebGL2 / WebAssembly (hosted on GitHub Pages), with first-class export support for Android (ARM64 APK) and Desktop.

## 2. Product Shape & Game Modes
- **Standard Run**: 15-minute survival countdown leading to an encounter with the 3-phase Boss for VICTORY and gold rewards.
- **Endless Mode**: Infinite scaling survival with 5-minute milestone notifications and recurring boss encounters.
- **Campaign Mode (Torchfall)**: 8 narrative-driven missions across 4 acts (including the *After the Forge* expansion) featuring custom win conditions (`survive_time`, `kill_count`, `kill_boss`), secondary objectives, briefing cards, and palette-shifted arena variants.
- **Playable Heroes (7)**: Mage (default), Paladin (1 win), Cleric (2 wins), Rogue (3 wins), Ranger (3 wins), Stormcaller (5 wins), Warden (6 wins).
- **Combat & Builds**: 14 base weapons, 6 weapon evolutions (Hellfire, Holy Bible, Aurora, Judgment, Thunderstorm, Void Reaver), 7 weapon synergies, 13 passive items, 6 map relics (including Phoenix Feather revive), 1 pet (Dragon Welp), and 2 active cooldown abilities (Meteor Strike, Time Freeze) plus an invincible dash burst.
- **Meta Progression**: Meta shop featuring 9 upgrade categories scalable across 20 tiers, 15 in-game achievements with gold rewards, and persistent stats tracking.
- **Internationalization**: Full bilingual support for English and Persian (`fa`) with runtime font switching and complete right-to-left (RTL) interface mirroring.

## 3. Technology Stack & Runtime
- **Engine**: Godot Engine 4.7.2-stable (pinned feature string `4.7` in `project.godot`).
- **Language**: GDScript 2.0 (strongly typed, strict warning flags where practical).
- **Renderer**: `gl_compatibility` (OpenGL ES 3.0 / WebGL2 compatible; avoids compute shaders to maximize compatibility on mobile and browser platforms).
- **Display Resolution**: Base 1280×720 viewport with `canvas_items` stretch mode and `expand` aspect ratio. Supports safe-area insets on mobile notches and cutouts.
- **Autoload Architecture**: 10 global singletons registered in `project.godot`:
  1. `EventBus` (`scripts/core/event_bus.gd`): Central signal hub.
  2. `GameManager` (`scripts/core/game_manager.gd`): Global state machine & pointer control.
  3. `RunManager` (`scripts/core/run_manager.gd`): Run metrics, timers, and win checks.
  4. `InputManager` (`scripts/input/input_manager.gd`): Device-agnostic input abstraction.
  5. `PoolManager` (`scripts/utilities/pool_manager.gd`): High-frequency object pooling.
  6. `SaveManager` (`scripts/save/save_manager.gd`): Platform-agnostic JSON persistence (`user://`).
  7. `AudioManager` (`scripts/audio/audio_manager.gd`): Audio bus & volume management.
  8. `PerformanceManager` (`scripts/performance/performance_manager.gd`): Dynamic resolution, quality tiers, and entity budgeting.
  9. `Localization` (`scripts/core/localization.gd`): Runtime CSV translation loader.
  10. `Analytics` (`scripts/core/analytics.gd`): Local anonymous run telemetry.

## 4. Operational Commands
- **Local Play (Godot Editor)**: Launch Godot 4.7.2 with `project.godot` or press `F5`.
- **Local Play (Console Executable)**:
  ```powershell
  .\Godot_v4.7.2-stable_win64_console.exe --path .
  ```
- **Run Headless Test Suite**:
  ```powershell
  python tools/run_tests.py --godot .\Godot_v4.7.2-stable_win64_console.exe
  ```
- **Run Single Headless Test**:
  ```powershell
  python tools/run_tests.py --godot .\Godot_v4.7.2-stable_win64_console.exe --test tests/smoke_phase1.gd
  ```
- **Export Web Build**:
  ```powershell
  godot --headless --export-release "Web" build/web/index.html
  ```
- **Export Android Debug Build**:
  ```powershell
  godot --headless --export-debug "Android" build/android/HordeSurvival3D.apk
  ```
- **Headless Asset Import**:
  ```powershell
  godot --headless --editor --import --quit
  ```

## 5. Major Architectural Constraints
- **Zero Allocations in Hot Paths**: `_process` and `_physics_process` loops must minimize heap churn, string concatenations, and dynamic array allocations.
- **Spatial Hash Grid Over Global Tree Searches**: Enemy queries and weapon targeting leverage an 8-meter spatial hash grid managed by `EnemyManager` instead of calling `get_nodes_in_group()` or relying on physics collision queries.
- **Pausable World vs Always-Active Overlays**: UI overlays (Pause, Level Up, Tutorial) and core singletons use `PROCESS_MODE_ALWAYS`, while the 3D world, horde logic, and entity controllers operate under `PROCESS_MODE_PAUSABLE`.
- **Web Limitations**: Single-threaded execution (`variant/thread_support=false`). Preloading of GLB 3D assets on worker threads is restricted to native builds.
- **Safe State Transitions**: Atomic file saves using `.tmp` swap files prevent corruption on browser refresh or mobile app backgrounding.

## 6. Known Unknowns & Limitations
- Real multi-touch browser gesture nuances (pinch-to-zoom and multi-finger touch tracking) require physical device validation beyond headless integration tests.
- Extended Endless mode balance past 25+ minutes remains open to tuning based on player playtest telemetry.
