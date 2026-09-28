# Release Checklist — HordeSurvival 3D

> Use before tagging a web release. Each row must be green (or explicitly waived).

## Build
- [ ] `project.godot` features pin `4.7` and matches CI Godot
- [ ] Web export succeeds to `build/web/index.html`
- [ ] CI workflow **Deploy Web Build** is green on `main`
- [ ] GitHub Pages serves the latest build
- [ ] Custom shell shows loading bar + Click-to-Play

## Headless suite
- [ ] `smoke_phase1` … `test_phase10`
- [ ] `test_v1_hero` … `test_v13_chars` (+ `test_v21c_auto`)
- [ ] `test_v15a` paths covered via `test_v5_juice` / `test_phase8` / `test_stress_instrument`
- [ ] `test_g_rigs`, `test_p2_slice`, `test_quality_fps`, `test_stress_instrument`

## Gameplay smoke (manual)
- [ ] Menu → character select → arena load
- [ ] Move + camera (desktop and a real phone if available)
- [ ] Level-up choices, evolution, passive, relic pickup
- [ ] Elite spawn readable (gold ring), boss fight (intro / phase flash / victory)
- [ ] Pause, settings (UI scale, reduced VFX, quality), game over → gold

## Presentation
- [ ] README GIF still matches current look (regenerate if VFX changed a lot)
- [ ] README links work (Play URL, screenshots, MP4)
- [ ] `docs/ASSET_CREDITS.md` complete

## Balance sanity
- [ ] First 5 min: player can reach ~level 8–12
- [ ] 10–20 min endless: F3 shows soft-capped threat/difficulty, playable FPS
- [ ] No infinite damage-number spam at 150+ enemies

## Ship
- [ ] Commit message lists user-facing changes
- [ ] Tag `vX.Y.Z` if this is a public milestone
- [ ] (Optional) Announce in README changelog section

## Known acceptable debt
- Headless cannot verify real multi-touch; on-device check remains manual
- Phase tests can flake on frame-count waits; re-run once before failing a release
