# CURRENT STATE — HordeSurvival 3D

> Updated: 2026-10-12 · Version: post-MVP + V1–V11 + P1–P4 (Phase C verified, deployed)

## Implemented Systems (working, tested)
- **Core loop**: menu → character select (Mage/Paladin/Rogue) → arena → horde → XP → level-up (3 choices) → builds → game over/results → gold
- **Combat**: 14 base weapons + 6 evolutions (Hellfire/HolyBible/Aurora/Judgment/Thunderstorm/VoidReaver), unified DamageEvent pipeline, statuses (burn/slow/freeze), crit, armor
- **Enemies**: 9 archetypes (drone/wisp/golem/turret/bat/ghost/splitter/healer/mage) — distinct primitive models + behaviors; elites (8 abilities); 1 boss (3 phases, telegraphs, volleys, minions)
- **Spawning**: threat budget, difficulty timeline (caps: HP 12x, damage 6.5x, speed 1.9x), cull 55m, spawn ring 22–30m, endless recurring bosses, 13–15min density ramp
- **Progression**: XP curve, 8 passives, 6 relics (incl. Phoenix Feather revive), Dragon Welp pet, 2 active abilities (Meteor/Time Freeze), combo (6 tiers), 15 achievements with gold rewards, meta gold shop (8 upgrades × 20 lvls), versioned meta save (IndexedDB on web)
- **Controls**: desktop (WASD + pointer-locked mouse + wheel zoom + Esc/P), mobile (floating joystick left, look right, zoom buttons, pause — fully independent)
- **Presentation**: 3D hero/enemy models from .tres data, character identity VFX (Paladin aura, Rogue trail), muzzle flashes, trails, damage numbers, kill bursts, arena decor, procedural music (3 intensity layers), SFX presets
- **Web**: 48.4 MB build (39.5MB .wasm + 10.9MB .pck), custom HTML shell (progress bar, Click-to-Play, WebGL2 fallback, pointer-lock cleanup)
- **Perf**: quality auto-detect (LOW drops shadows + caps), entity caps, pooling everywhere, F3 overlay + stress scene

## Documented Placeholders — Resolved (Phase C verified)
- [RESOLVED] Menu weapon collection screen → **WeaponCodex** (full catalog, .tres-driven)
- [RESOLVED] Relic pickup visibility → **beacon pillar** (2.8m glowing cylinder + emission pulse)
- [RESOLVED] Character identity → **identity VFX** (Paladin aura, Rogue trail)
- [RESOLVED] Achievement panel → **full catalog** (15 milestones, unlock state, gold rewards, badges)

## Known Issues / Debt
### Technical
1. MultiTouch unit tests are routing-level; real multi-touch browser behavior needs on-device verification (headless limitation)
2. Phase test suite has occasional timing flakes (fixed ad-hoc; two tests still slightly order-sensitive)
3. test_v3 flake re-verified PASS; root cause is frame-count dependent waits in tests

## Deployment
- GitHub Actions → Pages: green. Live: https://mohsen-niksirat.github.io/Horde_Survival_3D_Godot/
- Phases 1–4 landed: bugs + browser FPS fixes, web shell consolidation, Phase C features

## Recommended Next Phases
> See docs/POST_MVP_STATE.md §12 (authoritative P-phase order).

- **V12 — combat depth**: status interactions (burn+lightning), weapon synergy tuning
- **V14 — meta**: best-run stats panel, unlock conditions
- Post-15min endless balance pass with real playtest numbers
