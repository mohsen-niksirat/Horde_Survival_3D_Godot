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

## Phase C — Finish documented placeholders (new features)
- **WEAPONS menu screen** — replace notice text with a real collection grid
  (icon, tier, evolution status), driven by `.tres` data.
- **Relic beacon** — add a readable glow/pulse beacon so relic pickups are
  discoverable.
- **Character identity** — per-character visual differentiation (tint/robe is
  partially wired; extend to distinct models/accents where feasible).
- Exit criteria: each screen/feature has a headless test and is reachable in-game.

## Phase D — Content + balance polish
- Endless balance pass with real numbers (post-15 min density/perf).
- Achievement icons in the menu panel.
- Docs sync (README feature counts, CURRENT_STATE URLs, this plan's status).
- Exit criteria: docs match code; balance recorded; release checklist updated.

## Deploy contract (every phase)
1. Run the headless suite (local Godot 4.7.2).
2. Stage only intended files; commit with `fix/perf/feat/docs` prefix.
3. Push `origin/main`; confirm the `Deploy Web Build` workflow is green.
4. Live: https://mohsen-niksirat.github.io/Horde_Survival_3D_Godot/
