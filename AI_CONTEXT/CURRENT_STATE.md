# Current State — HordeSurvival 3D

## 1. Repository Status
- **Date**: 2026-11-09
- **Current Branch**: `main` (tracking `origin/main`, clean working tree)
- **Current Commit HEAD**: `199ef7b2b37a252f54d4cf60b238595d373758ea`
- **Recent Git Log**:
  - `199ef7b` perf(v31): cache enemy anim refs + leaner steering; fix run analytics zeros and HUD gold
  - `2782c8b` perf(v30a): adaptive resolution + cut per-frame HUD/VFX/telemetry overhead
  - `8c2a129` docs: link itch.io publishing guide + record V29A release progress
  - `4863220` feat(release): Android port, localization EN/FA, weapon balance pass, changelog + release plumbing
  - `846d618` perf(medium): lower Web caps + extend enemy AI throttle to Medium

---

## 2. Observed Feature Completeness
- **Gameplay Core Loop**: Complete and stable. Boot → Main Menu → Character Select / Campaign → In-run 3D arena combat → Auto-attack weapon volleys → XP & level up → Upgrade selection → Boss encounter → Victory or Game Over → Meta gold reward.
- **Game Modes**:
  - **Standard Run**: 15-minute survival threshold triggering 3-phase Boss encounter for Victory.
  - **Endless Mode**: Infinite time survival with recurring bosses and 5-minute milestone notifications.
  - **Campaign Mode (Torchfall)**: 8 story missions across 4 acts (including *After the Forge* expansion: `m6_storm` Shattered Observatory, `m7_hollow` Hollow Grove).
- **Roster & Content**:
  - 7 Characters: Mage, Paladin, Cleric, Rogue, Ranger, Stormcaller, Warden (unlockable via victory count).
  - 14 Base Weapons + 6 Evolutions (Hellfire, Holy Bible, Aurora, Judgment, Thunderstorm, Void Reaver).
  - 13 Passives + 6 Map Relics (including Phoenix Feather auto-revive) + 1 Pet (Dragon Welp) + 2 Active Abilities (Meteor Strike, Time Freeze) + Dash (F-key with i-frames).
  - 15 Enemy Archetypes + 8 Modular Elite Abilities + 1 3-phase Boss.
- **Cross-Platform Support**:
  - **Web (HTML5/WASM)**: Custom export shell with progress loader, Click-to-Play user gesture gate, pointer-lock lifecycle handlers, and cache-stamped service worker (`web/sw.js`).
  - **Android (ARM64)**: Export preset with landscape immersive mode, display cutout safe-area insets (`safe_area.gd`), hardware back-button routing, and automatic pause/save flush on backgrounding (`NOTIFICATION_APPLICATION_PAUSED`).
  - **Desktop (Windows/Linux/macOS)**: Native high-performance execution.
- **Internationalization**: Full runtime English and Persian (`fa`) localization with complete right-to-left UI mirroring.
- **Performance Optimizations (V20A–V31 + Web Load Optimization)**:
  - Pruned unused animation tracks from KayKit hero & boss models (13.5 MB raw / 4.8 MB packed reduction).
  - Downscaled 4K skyboxes to 1024×512, saving 2.6 MB packed and ~60 MB WebGL2 VRAM.
  - Reduced `index.pck` payload from 10.9 MB to 3.66 MB (66.5% drop).
  - Modernized `web/custom_shell.html` with instant background download, live byte/percentage telemetry, and golden "PLAY NOW" gate.
  - Enabled persistent Service Worker caching (`web/sw.js`) for `index.wasm` and `index.pck` (subsequent visits load in <2s with 0 bytes downloaded).
  - Removed duplicate in-engine "Click to Play" prompt from `scenes/bootstrap/boot.gd`.
  - Adaptive dynamic 3D viewport resolution scaling (0.4x–1.0x).
  - Tiered entity budgets (Very Low to Ultra) further scaled down on Web and Mobile.
  - Spatial hash grid (8m cells) throttling rebuilds to 100ms.
  - Horde animation LOD and throttled HUD updates.

---

## 3. Verification & Test Status
- **Test Harness**: `python tools/run_tests.py --godot <binary>` executing 62 test scripts located under `tests/`.
- **Environment Isolation**: The runner dynamically provides isolated temporary save directories per test to ensure deterministic results.
- **Verified Passes (This Session)**:
  - `tests/smoke_phase1.gd`: PASS
  - `tests/test_v24a_android.gd`: PASS (35 Android port & safe-area checks)
  - `tests/test_v25a_save_robust.gd`: PASS (atomic file write, schema migrations)
  - `tests/test_v26a_balance_table.gd`: PASS (weapon mathematical DPS models)
  - `tests/test_v27a_release.gd`: PASS (release plumbing, changelog, export presets)
  - `tests/test_v28a_localization.gd`: PASS (CSV parsing, RTL font and layout shifts)
- **CI Status**: GitHub Actions workflows in `.github/workflows/`:
  - `deploy-web.yml`: Headless import → headless test suite → Web export → GitHub Pages deploy.
  - `build-android.yml`: Headless import → test suite → debug APK artifact.
  - `tag-release.yml`: Release packaging on semantic version tags.

---

## 4. Known Technical Debt & Issues
1. **Frame-Count Dependent Test Waits**: A few legacy tests rely on frame-count waits (`await get_tree().process_frame`) which can occasionally exhibit timing sensitivity under extreme CPU throttling.
2. **Multi-Touch Real Device Validation**: Headless automated tests validate touch routing logic, but complex physical gestures (simultaneous multi-finger touch tracking + joystick steering) require on-device regression checks.

---

## 5. Next Technical Priorities
1. **Browser Performance Benchmarking on Mobile**: Validate memory footprint and WebGL2 draw call overhead on low-tier mobile browsers.
2. **Extended Endless Mode Tuning**: Analyze telemetry logs for infinite run balance beyond 20+ minutes.
3. **Audio Asset Polish**: Further optimize procedural music WAV generation on web initialization.
