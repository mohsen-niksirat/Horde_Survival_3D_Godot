# CURRENT STATE — HordeSurvival 3D

> Updated: 2026-09-06 · Version: post-MVP + V1–V10 + mobile fix round 3
> Audit per prompt 3 §1.

## Implemented Systems (working, tested)
- **Core loop**: menu → character (placeholder select) → arena → horde → XP → level-up (3 choices) → builds → game over/results → gold
- **Combat**: 5 weapons + 5 evolutions (Hellfire/HolyBible/Aurora/Judgment/Thunderstorm), unified DamageEvent pipeline, statuses (burn/slow/freeze), crit, armor
- **Enemies**: 9 archetypes (drone/wisp/golem/turret/bat/ghost/splitter/healer/mage) — distinct primitive models + behaviors (phase/split/heal/kite-volley); elites (8 abilities); 1 boss (3 phases, telegraphs, volleys, minions)
- **Spawning**: threat budget, difficulty timeline, cull 55m, spawn ring 22–30m, endless recurring bosses
- **Progression**: XP curve, 8 passives, relics (6, incl. revive), pet, 2 abilities, combo (6 tiers), achievements (10), meta gold shop (6 stats × 20 lvls), save v1 (IndexedDB on web)
- **Controls**: desktop (WASD + pointer-locked mouse + wheel zoom + Esc/P), mobile (floating joystick left, look right, zoom buttons, pause — fully independent)
- **Presentation**: hero/enemy models, muzzle flashes, trails, damage numbers, kill bursts, arena decor, procedural music (3 intensity layers), SFX presets
- **Perf**: quality auto-detect (LOW drops shadows), entity caps, pooling everywhere, F3 overlay + stress scene

## Known Issues / Debt
### Technical
1. MultiTouch unit tests are routing-level; real multi-touch browser behavior needs on-device verification (headless limitation) — device runtime verification pending for items 8–11 in PLAYTEST_FEEDBACK.md
2. Phase test suite has occasional timing flakes (fixed ad-hoc; two tests still slightly order-sensitive)
3. test_v3 flake re-verified PASS twice; root cause is frame-count dependent waits in tests, not gameplay
### Visual (superseded by docs/POST_MVP_STATE.md — code wins)
4. [RESOLVED at 7c96b4b] 3 characters implemented with select screen; shared hero model = next pass
5. [RESOLVED at dcf183e] boss model upgraded (horns, glowing eyes, plates)
6. Menu weapon collection screen is a placeholder
### Gameplay
7. Endless mode balance (post-15min scaling) untested beyond 10 min
8. Mage volleys can overwhelm in packs — tune if reported
9. Relic spawn presentation is subtle — may need beacon effect

## Deployment
- GitHub Actions → Pages: green. Live: https://mohsen-niksirat.github.io/Horde_Survival_3D_Godot/
- Custom loading shell (progress kept visible after PLAY), Click-to-Play, WebGL fallback
- Phase 1 (bugs + browser FPS P0) and Phase 2 (spatial hash, MultiMesh decor, render scale, spawn budget) landed — see docs/PHASE_PLAN.md

## Recommended Next Phases
> See docs/POST_MVP_STATE.md §12 (authoritative P-phase order).

- **V11A — feel polish**: movement accel tuning, camera sensitivity settings, hit-stop micro-pause, spawn pop-in fix (fade-in), contextual first-minute hints
- **V11B — mobile sensitivity setting** (slider in Settings) + haptics toggle
- **V12 — combat depth**: 2-3 weapon synergies (from reference design), status interactions (burn+lightning)
- **V13 — content**: 3 characters (Mage/Paladin/Rogue) with select screen
- **V14 — meta**: best-run stats panel, unlock conditions
