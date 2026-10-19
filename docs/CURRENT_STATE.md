# CURRENT STATE — HordeSurvival 3D

> Updated: 2026-10-19 · Version: V20A — performance / weak-hardware pass (V16A dash + menu polish deployed)

## Implemented Systems (working, tested)
- **Core loop**: menu → character select (7 heroes) → campaign mission or endless arena → horde → XP → level-up (3 choices) → builds → game over/results → gold
- **Campaign**: 8 story missions (Torchfall, Acts I–III + Act IV expansion), MissionData win rules, briefing toast, objective HUD, arena palette variants (ice, Heartforge, storm, grove)
- **Combat**: 20 weapons (14 base + 6 evolutions: Hellfire/HolyBible/Aurora/Judgment/Thunderstorm/VoidReaver), unified DamageEvent pipeline, statuses (burn/slow/freeze), crit, armor, 7 synergies
- **Enemies**: 15 archetypes (drone/wisp/golem/turret/bat/ghost/splitter/healer/mage/specter/brute/ember_runner/crystal_guard/broodling/brood_keeper) with rigs + behaviors; elites (8 abilities); 1 boss (3 phases, telegraphs, volleys, minions)
- **Spawning**: threat budget, difficulty timeline (caps: HP 12x, damage 6.5x, speed 1.9x), cull 55m, spawn ring 22–30m, endless recurring bosses, 13–15min density ramp, web spawn budget (perf-gated)
- **Progression**: XP curve, 13 passives (incl. Iron Bark, Ember Lens, Time Sand, Quartz Heart), 6 relics (incl. Phoenix Feather revive), Dragon Welp pet, 2 active abilities (Meteor/Time Freeze), combo (6 tiers), 15 achievements with gold rewards, meta gold shop (9 upgrades × 20 lvls), versioned meta save (IndexedDB on web)
- **Heroes**: 7 characters (Mage free, Paladin 1 win, Cleric 2 wins, Rogue 3 wins, Ranger 3 wins, Stormcaller 5 wins incl. Ember Lens, Warden 6 wins incl. Iron Bark)
- **Controls**: desktop (WASD + pointer-locked mouse + wheel zoom + Esc/P + Space dash), mobile (floating joystick left, look right, zoom buttons, dash button, pause — fully independent)
- **Presentation**: 3D hero/enemy models from .tres data, character identity VFX (Paladin aura, Rogue trail), muzzle flashes, trails, damage numbers, kill bursts, arena decor, procedural music (3 intensity layers), SFX presets
- **Web**: 48.4 MB build (39.5MB .wasm + 10.9MB .pck), custom HTML shell (progress bar, Click-to-Play, WebGL2 fallback, pointer-lock cleanup)
- **Perf**: quality auto-detect (LOW drops shadows + caps), entity caps, pooling everywhere, F3 overlay + stress scene; V20A: 6 s auto-tier startup grace, horde animation LOD (mid-range 1-in-3 physics frames, far skipped), weapon volley query reuse, XP-orb same-tier material guard, 5 Hz boss-bar / 4 Hz objective HUD cadence, stress spawn budget 2/frame, deferred menu panel builds

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
- Phases 1–4 + campaign + After the Forge expansion landed; HEAD at docs sync (Phase D)

## Recommended Next Phases
> See docs/POST_MVP_STATE.md §12 (authoritative P-phase order) and docs/EXPANSION_QA_FA.md (browser QA gate before release).

- **EXPANSION_QA browser gate**: real WASM/WebGL2 + phone FPS verification per EXPANSION_QA_FA.md; balance is initial until measured on device
- **V14 — meta**: best-run stats panel, expanded unlock conditions
- Post-15min endless balance pass with real playtest numbers
