# Index Scope & Coverage — HordeSurvival 3D

## 1. Metadata
- **Analysis Date**: 2026-11-09
- **Indexing Mode**: `INITIALIZE`
- **Target Commit**: `199ef7b2b37a252f54d4cf60b238595d373758ea`
- **Git Branch**: `main` (clean working directory, tracking `origin/main`)

---

## 2. Inspected Artifacts & Directories

### Configuration & Project Manifests
- `project.godot`: Global settings, rendering configuration (`gl_compatibility`), 10 autoload singletons, physics layers, input maps.
- `export_presets.cfg`: Presets for Web (PWA, custom shell) and Android (ARM64, landscape, immersive mode).
- `.gitignore` & `.gitattributes`: Repository ignore patterns, LFS rules.
- `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `LICENSE`.

### Documentation (`docs/`)
- `docs/ARCHITECTURE.md`: High-level system structure and design rules.
- `docs/CURRENT_STATE.md`: Recent phase progress and resolved debt.
- `docs/WEAPON_BALANCE.md`: Weapon DPS model and tier progression curves.
- `docs/BUILD_ANDROID.md` & `docs/BUILD_WEB.md`: Export instructions and configurations.
- `docs/PUBLISH_ITCH.md`: Itch.io packaging and iframe integration.

### Automation & Workflows (`.github/workflows/`)
- `.github/workflows/deploy-web.yml`: Headless import, headless tests, Web export, and GitHub Pages deployment.
- `.github/workflows/build-android.yml`: Android ARM64 headless build and debug APK artifact generation.
- `.github/workflows/tag-release.yml`: Automated GitHub release creation gated on changelog validation.

### Source Code (`scripts/`)
- `scripts/core/`: `game_manager.gd`, `event_bus.gd`, `run_manager.gd`, `stat_block.gd`, `localization.gd`, `analytics.gd`, `mission_data.gd`.
- `scripts/spawning/`: `enemy_manager.gd`, `wave_manager.gd`, `difficulty_manager.gd`.
- `scripts/combat/`: `damage_event.gd`, `health_component.gd`, `status_component.gd`, `targeting_system.gd`, `juice_manager.gd`.
- `scripts/weapons/`: `weapon_controller.gd`, `weapon_instance.gd`, `weapon_data.gd`, `weapon_balance.gd`.
- `scripts/player/`: `movement_component.gd`, `dash_component.gd`, `experience_component.gd`, `camera_rig.gd`.
- `scripts/enemies/`: `enemy_data.gd`, `elite_component.gd`, `elite_ability.gd`.
- `scripts/items/`: `relic_system.gd`, `relic_data.gd`.
- `scripts/progression/`: `progression_manager.gd`, `upgrade_option.gd`, `evolution_data.gd`, `passive_data.gd`, `combo_manager.gd`, `achievement_system.gd`.
- `scripts/performance/`: `performance_manager.gd`.
- `scripts/save/`: `save_manager.gd`.
- `scripts/input/`: `input_manager.gd`.
- `scripts/audio/`: `audio_manager.gd`, `music_director.gd`, `sfx_binder.gd`.
- `scripts/ui/`: `safe_area.gd`.
- `scripts/utilities/`: `pool_manager.gd`, `rig_util.gd`, `external_links.gd`.
- `scripts/world/`: `stage_director.gd`.

### Scenes (`scenes/`)
- `scenes/bootstrap/Boot.tscn`
- `scenes/main/Main.tscn` & `scenes/main/main.gd`
- `scenes/player/Player.tscn` & `scenes/player/player.gd`
- `scenes/enemies/Enemy.tscn` & `scenes/bosses/Boss.tscn`
- `scenes/menu/` (`MainMenu.tscn`, `CharacterSelect.tscn`, `CampaignMenu.tscn`, `MetaShop.tscn`, `WeaponCodex.tscn`, `SettingsMenu.tscn`, `AchievementPanel.tscn`)
- `scenes/ui/` (`HUD.tscn`, `LevelUpOverlay.tscn`, `PauseOverlay.tscn`, `GameOverOverlay.tscn`, `TouchControls.tscn`, `ScreenFeedback.tscn`, `TutorialOverlay.tscn`)
- `scenes/pickups/` (`XpOrb.tscn`, `HeartPickup.tscn`, `MagnetDrop.tscn`, `RelicPickup.tscn`)
- `scenes/weapons/` (All projectile and visual attack scenes)
- `scenes/world/Arena.tscn`

### Data Resources (`data/`)
- 55 `.tres` resource files covering weapons, evolutions, characters, enemies, passives, relics, abilities, and campaign missions.

### Localization & Web Assets
- `locale/en.csv` & `locale/fa.csv`.
- `web/custom_shell.html`, `web/sw.js`, `web/itch/itch.html`.

### Tools & Tests
- `tools/run_tests.py`, `tools/balance_table.gd`.
- `tests/smoke_phase1.gd` and representative test scripts (`test_v24a_android.gd`, `test_v25a_save_robust.gd`, `test_v26a_balance_table.gd`, `test_v27a_release.gd`, `test_v28a_localization.gd`).

---

## 3. Deliberately Excluded from Index
- **Binary Assets & Models**:
  - `Godot_v4.7.2-stable_win64.exe` and `Godot_v4.7.2-stable_win64_console.exe` (local engine binaries).
  - External archive packages (`*.zip`, `Horde_Survival_3D_Godot-fixes-v2.1.zip`).
  - Raw Kenney 3D GLB model files (`assets/models/external/`, `assets/models/kaykit/`).
- **Engine & System Cache**:
  - `.godot/` internal imported assets cache.
  - `.git/` repository internal metadata.
- **Build & Test Outputs**:
  - `build/` (web, android, itch export artifacts and test output logs).
  - Scratch temporary files (`*.tmp`, `tmp_out.txt`).

---

## 4. Coverage Limitations & Remaining Uncertainties
- **Full Suite Execution**: Verified a representative subset of 6 tests (`smoke_phase1` + `test_v24a` to `test_v28a`) which passed 100%. The entire 62-test suite was not executed end-to-end in this session to respect turn duration limits.
- **Physical Multi-Touch Nuance**: Browser gesture nuances (pinch-zoom multi-finger cancel edges) are covered via synthetic event routing tests, requiring periodic on-device mobile browser validation.
