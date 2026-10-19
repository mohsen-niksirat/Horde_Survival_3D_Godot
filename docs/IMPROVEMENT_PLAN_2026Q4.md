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

## Deploy contract (every phase)
1. Run the headless suite (local Godot 4.7.2).
2. Stage only intended files; commit with `fix/perf/feat/docs` prefix.
3. Push `origin/main`; confirm the `Deploy Web Build` workflow is green.
4. Live: https://mohsen-niksirat.github.io/Horde_Survival_3D_Godot/
