# Changelog

All notable changes to HordeSurvival 3D are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Android export preset** (`Android` in `export_presets.cfg`): ARM64,
  Compatibility renderer, landscape, immersive mode, no runtime permissions.
- **Android CI workflow** (`.github/workflows/build-android.yml`): headless
  import → headless test suite → debug-signed APK → GitHub Actions artifact.
- **Safe-area support** (`scripts/ui/safe_area.gd`): converts
  `DisplayServer.get_display_safe_area()` into viewport-space insets and
  applies them to the HUD, the touch overlay and the settings panel, so
  notches, punch-holes and gesture bars never cover the UI.
- **Android back button routing**: pauses during a run, resumes from pause,
  closes the level-up overlay, closes the topmost open menu panel, and asks
  for exit confirmation on the main menu.
- **App lifecycle handling**: backgrounding the app auto-pauses the run and
  flushes the save synchronously.
- **Touch action state** (`InputManager.set_touch_action()`): the Dash and
  ability buttons now report their held state through the input abstraction
  instead of only firing on press.
- **Localization** (`scripts/core/localization.gd` + `locale/*.csv`): English
  and Persian catalogues parsed at runtime, a language switcher in Settings,
  and right-to-left layout mirroring for Persian. UI strings use `tr()`.
- **Weapon DPS table** (`tools/balance_table.gd` + `docs/WEAPON_BALANCE.md`)
  and a shared model (`scripts/weapons/weapon_balance.gd`).
- **Balance guard test** (`tests/test_v26a_balance_table.gd`).
- **Save robustness test** (`tests/test_v25a_save_robust.gd`).
- **Android port test** (`tests/test_v24a_android.gd`, 35 checks).
- **Release test** (`tests/test_v27a_release.gd`) and **localization test**
  (`tests/test_v28a_localization.gd`).
- **In-game feedback**: a **SEND FEEDBACK** button in the Settings menu that
  opens the GitHub issue form (`scripts/utilities/external_links.gd`).
- **Issue templates** (`.github/ISSUE_TEMPLATE/feedback.yml`,
  `bug_report.yml`).
- **CHANGELOG.md** following Keep a Changelog + Semantic Versioning.
- **Tag workflow** (`.github/workflows/tag-release.yml`) that creates a
  GitHub release from a `v*` tag and refuses to tag when the changelog has
  no matching section.
- **Independent music/SFX mute** toggles in Settings.

### Changed
- **Dash key moved from Space to F.** Space re-triggered the focused HUD
  button, which bounced the player out of fullscreen.
- **HUD buttons no longer take keyboard focus** (`FOCUS_NONE` + explicit
  `release_focus()`), so Space/Enter can never re-fire them.
- **Weapon balance (data files only)**: Lightning, Thunderstorm and Orbiting
  Shield received custom `tier_damage_mult` curves. AoE and orbit weapons
  never get `tier_projectile_bonus`, so they used to fall behind the
  projectile weapons by tier 5. See `docs/WEAPON_BALANCE.md`.
- **Web Medium tier is cheaper** on web: lower enemy/projectile/particle
  caps and enemy AI throttling now extend to Medium.
- **Adaptive 3D resolution** (V30A): the tier scale is now a ceiling; while
  FPS stays below ~46 the render scale steps down (to a floor of 0.4) and
  climbs back after sustained headroom. If a downscale does not improve FPS
  (CPU-bound device), it restores sharpness and pauses probing for 20 s.
- **HUD updates are throttled to 10 Hz** and only re-shape text / re-apply
  theme overrides when a value actually changed (timer, kills, HP, level,
  ability and dash buttons, hints). The dash button now returns to `F Dash`
  when ready instead of keeping a stale countdown.
- **Per-system timing is opt-in** (F3 overlay or F4 capture), removing
  dictionary bookkeeping and `Time.get_ticks_usec()` calls from every enemy,
  weapon and wave tick during normal play.
- **Pooled VFX and per-enemy components sleep** when idle: damage numbers,
  bursts, muzzle flashes and lightning strikes disable `_process` between
  uses; `StatusComponent` and `EliteComponent` only process while active.
- **Cheaper rendering probes**: platform/settings lookups are cached;
  fog is HIGH+ on web/touch; MEDIUM shadows are desktop-only.
- **Allocation-free target spread**: nearest-N selection replaces the
  per-volley filter/sort closures; the enemy spatial grid rebuilds at
  100 ms instead of 40 ms.
- **VFX dynamic lights** are opt-in above ULTRA on web/mobile; all pooled
  OmniLight3D nodes start hidden.
- **Service worker** no longer intercepts the large `index.wasm` /
  `index.pck` payloads — a pending service-worker response left the engine
  stuck on "Compiling engine" forever.

### Fixed
- **Web startup hang**: `engine.startGame()` is no longer gated on
  `navigator.serviceWorker.ready` (capped at 4 s) and a 5-minute watchdog
  surfaces a retry prompt instead of an endless timer.
- **Stale audio worklet**: the service worker serves Godot's audio worklets
  with `cache: no-store`, so a previous deployment's worklet can no longer
  be mixed with a new `index.js` (`GodotAudio.sampleNodes is null`).
- **Corrupt save** no longer spams the engine error log; a malformed or
  truncated save file falls back to defaults with a warning.
- **Test isolation**: `tools/run_tests.py` now isolates the Godot save
  directory on every platform. Previously only `XDG_DATA_HOME` was set, so on
  Windows all tests shared one save file and results depended on execution
  order.
- **Phase-5 wave test** no longer asserts a tight spawn count (≥7 instead of
  ≥10) — the spawn cadence is threat-budget driven.

### Removed
- `web/index.html` — a stale duplicate of the real export shell
  (`web/custom_shell.html`). It was copied into the deploy artifact but
  never referenced.
