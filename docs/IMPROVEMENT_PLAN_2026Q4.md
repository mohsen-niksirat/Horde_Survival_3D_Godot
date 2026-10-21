# Improvement Plan — HordeSurvival 3D (2026 Q4)

> Authoritative plan for the current work cycle. Supersedes older phase docs for
> *new* work; historical docs (ROADMAP.md, PHASE_PLAN.md, POST_MVP_STATE.md) stay
> as-is. Rule: each phase = implement → headless suite green → commit → push.

## 0. Debug audit (baseline established this session)

Environment: Godot 4.7.2-stable, Windows, Compatibility renderer.

Headless suite run in batches (59 suites across 49 test files):

- **58 / 59 PASS**
- **1 FAIL (flake, now fixed):** `tests/test_v7_ui.gd` — "combo pop animating
  (scale=0.98)". The HUD combo tween used `TRANS_BACK` + `EASE_OUT`, whose curve
  dips below the target near the tail; combined with a 1.0s `await` it could be
  sampled at scale < 1.0. Fixed by (a) killing any in-flight combo tween so
  tweens never stack, and (b) using a monotonic `TRANS_QUAD`/`EASE_OUT` pop.
  Verified stable over 5/5 consecutive isolated runs.
- **Clean boot:** `--quit-after 200` headless boot emits no ERROR/SCRIPT ERROR.

Also found during audit:

- **HUD tween stacking** (the flake's real root cause): repeated combo updates
  created overlapping tweens on `combo_label.scale`. Now guarded.
- **6 `.uid` files untracked** (Godot 4.4+ script UIDs) for scripts added in the
  last commits. They regenerate locally but should be committed for reproducible
  imports across machines/CI.
- **Dead shell file:** `web/index.html` is copied to `build/web/index_shell.html`
  by CI but is never referenced; `web/custom_shell.html` is the real shell
  (`export_presets.cfg` → `html/custom_html_shell`). Opportunity to consolidate.

The project is in strong shape: data-driven `.tres` content, spatial-hash
targeting, pooled entities, cached light/env lookups, web-aware quality tiers and
entity caps. The plan below targets **web load/runtime efficiency** and
**finishing the documented placeholders**, not a rewrite.

## Phase A — Correctness + regression hardening
- Fix combo HUD tween stacking (done) + commit the missing `.uid` files.
- Add a guard so combo pop is deterministic (no underscan) — covered by test.
- Fix CI/workflow drift: ensure `tools/` is available where the workflow expects
  it; align export excludes.
- Exit criteria: full suite green on a clean clone; workflow imports without
  errors.

## Phase B — Web optimization (primary user goal)
- **Load time / bundle size:** audit exported `.wasm`/`.pck` size; ensure
  `assets/models/external/*`, tests, tools, docs, screenshots excluded; consider
  trimming unused GLB variants and enabling a single-line shell.
- **Shell UX:** consolidate `web/index.html` and `web/custom_shell.html` into one
  authoritative shell; accurate progress (download vs decode phases), clearer
  first-visit messaging, persistent progress bar, robust error surface.
- **Runtime:** verify web quality defaults (Very Low), render scale, MSAA/shadows
  off, spawn budget; add an optional low-power mode; measure with the F3 overlay
  in a real browser and record numbers in docs.
- **Loading prefetch:** confirm threaded GLB preload is skipped on single-thread
  web (already guarded) and no per-frame allocations remain on web hot paths.
- Exit criteria: exported web build stays within a documented size budget; boot
  to menu under a documented time on a mid browser; no console errors.

## Phase C — Finish documented placeholders (new features)  [STATUS: already implemented]
- **WEAPONS menu screen** — `scenes/menu/weapon_codex.gd` is fully implemented:
  catalogs 14 weapons via `.tres` data, shows damage/cooldown/projectile stats,
  6 evolutions, 7 synergies, 6 relics, 10 passives, 3 relic synergies.
  Reachable from MainMenu → WeaponCodex (open() + close button).
- **Relic beacon** — `_spawn_beacon()` in `relic_pickup.gd:54` creates a 2.8m
  tall glowing cylinder pillar with a looping emission pulse tween.
  Pulse + rarity-tinted chest model make relics discoverable mid-horde.
- **Character identity** — `character_identity.gd` adds Paladin aura (pulsing
  torus) and Rogue move trail (pooled puffs with scale/fade tween).
  Wired into `player.gd:41-46` bind_combat(). Tests:
  test_p2_slice, test_orbit_decouple, test_g_rigs all PASS.
- **Achievement panel** — `scenes/menu/achievement_panel.gd` shows 15 milestones
  with unlock state, gold rewards, tier badges (★★/○), titles/desc.
- Exit criteria: ✓ all features have headless tests (test_p2_slice, test_g_rigs,
  test_phase3a_assets pass).

## Phase D — Content + balance polish  [STATUS: docs synced]
- Endless balance pass with real numbers (post-15 min density/perf).
- Docs sync (README feature counts, CURRENT_STATE URLs, this plan's status).
- Exit criteria: docs match code; balance recorded; release checklist updated.

## Phase D results (2026-10-12)
- **Docs synced:** README feature counts corrected (14 weapons + 6 evolutions, 7 characters, 15 achievements, 13 passives, 15 enemies, 8 missions, 9 meta upgrades); CURRENT_STATE.md + POST_MVP_STATE.md addendum updated.
- **Balance verified:** DifficultyManager caps (HP 12x, dmg 6.5x, speed 1.9x) confirmed; threat budget + spawn budget already tuned.
- **Release gate:** device-level balance/FPS still needs real-browser QA per `EXPANSION_QA_FA.md` before a public tag.

## Phase E — Release readiness sweep (2026-10-12, this commit)
- Full headless suite re-run at HEAD: **50/50 PASS** (4 batches; `stress_scene.gd` excluded — manual scene, not a suite).
- Local web export verified: `--export-release "Web"` → exit 0, **0 errors**, ~48.3 MB (wasm 37.7 + pck 10.4 + js 0.3). Excludes still hold.
- `RELEASE_CHECKLIST.md` Build + Headless sections marked verified.
- **Remaining (deferred — needs real device):** browser cold-boot/reload, mobile touch/FPS, full 10-min pressure run, Storm/Grove playthrough balance. These are manual gates in `EXPANSION_QA_FA.md`, not automatable headless.

## Phase B results (deployed f23c34f)
- Web build measured: 48.4 MB total (39.5MB .wasm engine + 10.9MB .pck).
- exclude_filter already excludes external models, tests, tools, docs, *.md.
- Consolidated web/index.html with custom_shell.html (pointer-lock + WebGL2
  detection + progress bar).

## V16A update (2026-10-19)
- **Dash shipped:** the `dash` input action (Space) existed in `project.godot` and was routed
  through InputManager but consumed by nothing — `scripts/player/dash_component.gd` closes the
  gap (18 m/s burst, 0.25s i-frames, 2.5s cooldown, SFX + camera shake). HUD/touch button
  mirrors it; onboarding hint updated.
- **Menu polish:** main-menu stats line now shows runs / campaign progress / endless best /
  best combo / best level; achievement panel shows progress bars for numeric goals;
  `best_combo` + `best_level` persist via RunManager's `run_ended` hook.
- **Repo hygiene:** `*.zip` gitignored; the committed 22 MB fixes archive untracked from git
  (use GitHub Releases for distributables).
- **Tests:** `tests/test_v16a_dash.gd`, `tests/test_v16a_menu.gd` (new); full headless suite
  re-run at this commit.

## V20A update (2026-10-19) — performance / weak-hardware pass
- **Startup hitch:** the menu built the achievement panel + campaign list synchronously in
  `_ready` (two PackedScene loads + UI trees on the first frame). Both now instantiate via
  `call_deferred` builders so the menu paints first; the stats line renders immediately.
- **Auto-tier grace:** `PerformanceManager._auto_tick` now waits 6 s before judging FPS —
  shader compilation and first-frame asset churn read as "slow" and previously dropped the
  tier right at spawn (forcing a re-warm when FPS recovered). Stress reactions unaffected.
- **Horde LOD:** far-enemy throttle frames now early-out before the transform math; the
  procedural micro-motion pass (per-enemy sin/tween work) is staggered 1-in-3 physics frames
  for mid-range enemies and skipped entirely beyond 28 m.
- **Query reuse:** `WeaponInstance` caches its radius-query candidates each volley; the
  controller's multi-projectile spread reuses them instead of issuing a second spatial
  query + sort per shot.
- **Allocation trims:** XP orbs skip the material-duplication pass when recycling at the
  same value tier; enemy archetype GLBs resolve through Godot's resource cache (template
  node caching was tried and reverted — leaked RIDs at exit).
- **HUD cadence:** the boss-bar group lookup + phase-tint stylebox churn run at 5 Hz
  instead of every frame; the mission objective label rebuilds at 4 Hz.
- **Spawn budget:** under horde stress the per-frame spawn admission drops to 2 (native).
- **Tests:** `tests/test_v20a_perf.gd` (new, 12 checks: deferred menu builders, query
  reuse, orb recycle guard, boss-bar gate, auto-grace).

## V24A update (2026-10-21) — Android port (Phase 1 of the improvement brief)

The improvement brief's Phase 1 (Android) is now implemented:

- **Export preset:** `Android` added to `export_presets.cfg` — ARM64 enabled,
  ARMv7 declared but off by default, package `com.mohsenhorde.hordesurvival3d`,
  Compatibility renderer, landscape + immersive, no runtime permissions.
- **Mobile defaults:** `PerformanceManager.is_mobile_platform()` recognises
  Android/iOS; a fresh install still starts on Very Low (cheapest tier) and the
  player can raise it in Settings.
- **Safe area:** `scripts/ui/safe_area.gd` converts
  `DisplayServer.get_display_safe_area()` (screen pixels) into viewport-space
  insets and applies them to the HUD root and the touch overlay, so the notch /
  punch-hole / gesture bar never overlaps the HUD or the zoom buttons.
- **Back button:** `GameManager.handle_back_request()` — pause in a run, resume
  from pause, close the level-up overlay, return to the menu from a result
  screen, close the topmost open menu panel, and finally ask for exit
  confirmation on the main menu (`EventBus.exit_confirm_requested`).
- **App lifecycle:** `NOTIFICATION_APPLICATION_PAUSED` auto-pauses the run and
  flushes `SaveManager` synchronously, so a phone call or task switch cannot
  lose run progress.
- **Input abstraction:** touch Dash/Ability buttons now report their held
  state through `InputManager.set_touch_action()` instead of only firing on
  press.
- **CI:** `.github/workflows/build-android.yml` imports assets headless, runs
  the headless suite and exports a debug-signed APK, uploaded as the
  `HordeSurvival3D-debug-apk` artifact.
- **Docs:** `docs/BUILD_ANDROID.md` rewritten (preset table, local build, CI
  build, release/keystore plan, mobile checklist).
- **Tests:** `tests/test_v24a_android.gd` (35 checks) — preset contents, safe
  area math, back routing, lifecycle pause+save flush, menu panel closing.

## V27A update (2026-10-21) — release plumbing (Phase 4)

- **In-game feedback:** the Settings menu gained a **SEND FEEDBACK** button
  that opens the GitHub issue form in the player's browser
  (`scripts/utilities/external_links.gd` — Web opens a tab, Android/desktop
  use the OS URL handler).
- **Issue templates:** `.github/ISSUE_TEMPLATE/feedback.yml` (structured
  feedback with category / platform / quality dropdowns) and
  `bug_report.yml`.
- **CHANGELOG.md** created, following Keep a Changelog + Semantic Versioning.
- **Tag workflow:** `.github/workflows/tag-release.yml` creates a GitHub
  release from a `v*` tag and refuses to tag when `CHANGELOG.md` has no
  matching `## [vX.Y.Z]` section.
- **Independent mute:** `AudioManager` gained `music_muted` / `sfx_muted`
  flags with their own Settings toggles, so the player can silence the
  soundtrack without losing the combat SFX.
- **Tutorial:** a Dash step was added to both the desktop and touch step
  lists (the key moved from Space to F).
- **Tests:** `tests/test_v27a_release.gd` (feedback link, changelog format,
  semver in the export preset).

## V26A update (2026-10-21) — weapon balance pass (Phase 3)

- **DPS table:** `tools/balance_table.gd` prints the tier-by-tier damage
  table for every weapon straight from the `.tres` data. The model lives in
  `scripts/weapons/weapon_balance.gd` so the tool, the guard test and the
  game can never disagree. Documented in `docs/WEAPON_BALANCE.md`.
- **Root cause found:** only `projectile` and `pierce` weapons receive
  `tier_projectile_bonus` from the tier curves — the AoE path fires a single
  strike and the orbit path uses the shield count. Lightning therefore grew
  1.6x by tier 5 while every other weapon grew ~4.8x and it ended up the
  weakest weapon in the pool; Thunderstorm (its evolution) was only +20%
  over its base weapon while every other evolution grants +110% to +567%.
- **Data fix (no hardcoding):** `lightning.tres`, `thunderstorm.tres` and
  `orbiting_shield.tres` received custom `tier_damage_mult` curves. The
  pickable pool now sits in a 2.2x tier-5 DPS spread (was 4.5x).
- **Guard test:** `tests/test_v26a_balance_table.gd` locks the table in
  place — monotonic damage, a bounded pool spread, a growth floor, and
  "no evolution is ever a downgrade".
- **Gotcha documented:** a typed `Array[float]` export must be written as
  `Array[float]([...])` in a `.tres`; `PackedFloat32Array(...)` is silently
  ignored and the property keeps its default.

## V25A update (2026-10-21) — save robustness (Phase 2)

- **New test** `tests/test_v25a_save_robust.gd` (25 checks): round-trip,
  legacy migration (gold / achievements / settings survive, missing keys are
  filled from the defaults, the legacy quality scale is preserved and
  translated by PerformanceManager), and recovery from a corrupt, truncated,
  empty, wrong-shaped or missing save file.
- **`SaveManager.load_game()`** now uses the `JSON` instance API instead of
  `JSON.parse_string()`. The static helper pushes an engine `ERROR:` for
  malformed input, which polluted the log on every device with a damaged
  save; the instance API returns an error code, so a corrupt file is only a
  warning.
- **Test isolation bug fixed:** `tools/run_tests.py` only set
  `XDG_DATA_HOME`, which is a Linux path — on Windows every test shared the
  same `user://` save file, so results depended on execution order (this is
  what made `test_v12_depth.gd` fail intermittently). The runner now
  isolates the save directory on every platform.

## V28A update (2026-10-21) — localization (Phase 3)

- **Infrastructure:** `scripts/core/localization.gd` is a new autoload that
  parses `locale/<locale>.csv` at runtime and registers a `Translation` per
  locale. Runtime parsing (instead of Godot's CSV importer) is deliberate:
  the importer generates per-column `.translation` artifacts whose paths
  differ between the editor and an exported build, so the catalogues would
  only work in one of them.
- **Catalogues:** `locale/en.csv` and `locale/fa.csv` (61 keys each) cover
  the main menu, the settings panel, the HUD hints, the tutorial titles, the
  meta shop, the character select and the achievement panel.
- **Language switcher:** a button in the Settings panel cycles EN <-> FA and
  persists the choice.
- **RTL:** Persian flips the menu, the settings panel and the tutorial
  overlay to `LAYOUT_DIRECTION_RTL`.
- **Tests:** `tests/test_v28a_localization.gd` (22 checks) — the autoload
  API, catalogue parity (same keys, no untranslated entries), locale
  switching, the English fallback for unsupported locales, RTL detection and
  the language button.

## V29A update (2026-10-21) — itch.io + opt-in analytics (Phase 4)

- **itch.io package:** the web workflow now zips an itch-ready build
  (`build/horde-survival-3d-itch.zip`): the exported `index.html` is renamed
  to `game.html` and wrapped in `web/itch/itch.html`, which loads it in a
  full-viewport iframe with a readable error page if the layout is wrong.
  Instructions: `docs/PUBLISH_ITCH.md`.
- **Opt-in local analytics** (`scripts/core/analytics.gd`): run counters,
  most-used weapon and death-phase buckets, stored **on the device only**.
  Nothing is recorded while the toggle in Settings is off, and turning it
  off clears the collected data. The summary is appended to the main-menu
  stats line.
- **Audio:** independent `music_muted` / `sfx_muted` flags with their own
  Settings toggles, so the soundtrack can be silenced without losing the
  combat SFX.

## Deploy contract (every phase)
1. Run the headless suite (local Godot 4.7.2).
2. Stage only intended files; commit with `fix/perf/feat/docs` prefix.
3. Push `origin/main`; confirm the `Deploy Web Build` workflow is green.
4. Live: https://mohsen-niksirat.github.io/Horde_Survival_3D_Godot/
