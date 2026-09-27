# POST_MVP_STATE â€” authoritative post-V13 reconciliation

> Per prompt 5 Â§1. Code wins over any older document. Audit date: this commit.

## 1. Exact current HEAD
`dcf183e` â€” polish(V15A): imposing boss model + phase8 test root-cause fix

## 2. Actually implemented (code-verified)
- Core: third-person controller (pointer-locked desktop look, wheel zoom,
  pitch clamp), CoD-style mobile controls (left floating joystick, right
  look, zoom +/âˆ’ buttons, touch rings indicator), pause (Esc/P/II button,
  Resume/Restart/Menu), 90s contextual onboarding hints (V14)
- Combat: 5 weapons + 5 evolutions, unified DamageEvent pipeline (crit/
  armor/status), 3 weapon synergies (Firestorm/Storm Caller/Iron Tempest),
  burnÃ—lightning detonation (+50%), multi-shot spreads to N nearest
  DISTINCT targets, muzzle flashes + per-weapon SFX, damage-number
  billboards, kill bursts, level-up ring
- Enemies: 9 archetypes (drone/wisp/golem[rounded]/turret/bat/ghost/
  splitter/healer/mage), hard speed cap 5.5 m/s (< player 6.0), 8 elite
  abilities + gold ground ring + gold tint, 3-phase boss (new imposing
  model: horns, glowing eyes, plates; slam telegraph ring, fan volleys,
  Endless respawn +30%/5min)
- Progression: XP shards (cyan crystals), 8 passives, relics, pet,
  2 abilities (desktop keys + mobile buttons both execute), combo,
  10 achievements, heart pickups (magnet within 6 m, 5% drop, heal 25)
- Meta: gold from every kill + HUD counter, permanent upgrade shop
  (6 stats Ã— 20 lvls, idempotent StatBlock keys), Endless checkbox,
  3 characters (Mage balanced / Paladin +30%HP âˆ’10%spd / Rogue +20%spd
  âˆ’20%HP) with distinct starting weapons + select screen
- Presentation: hero mage model, per-archetype enemy models, arena decor
  (grass/trees/spherical rocks with colliders/wall pillars), procedural
  3-layer music (calm/tense/boss), soft low-HP vignette (25% threshold)
- Performance: quality tiers LOW/MED/HIGH + AUTO (4s<26fps step down,
  20s>55fps recover), shadow drop on LOW, pooling everywhere, spawn
  fade-in, F3 overlay + 250-enemy stress scene
- Settings: master/music/sfx, look sens, touch sens, haptics toggle,
  shake toggle, quality + Auto
- Deploy: GitHub Actions â†’ Pages, custom loading shell + Click-to-Play

## 3. Partially implemented / placeholders
- WEAPONS menu screen: still a notice-text placeholder
- Menu achievements view: text list only (no icons)
- Relic spawn presentation: pickups readable but no beacon/glow pulse
- Character visual identity: stat-differentiated but same hero model on
  all three (no per-character model/colors)

## 4. Only-placeholder items
- None beyond Â§3.

## 5. Automatically tested (32 suites, green at audit)
smoke_phase1, phase2â€“10, task_a1/a4/a5, mouse_look, v1_hero, v2_enemy,
v3_weapons, v4_arena, v5_juice, v6_content, v7_ui, v8_audio, v9_meta,
v11a_feel, v11b, v12_depth, v13_chars, touch_buttons, touch_look_accum,
survival_balance, v21c_auto, visibility_fix, stress_instrument
(known timing flakes: v3/v5 rerun-verified)

## 6. Requires real browser/device verification
- Multitouch rings + look independence (verified manually once by user)
- Heart magnet feel + 5% rate balance
- AUTO graphics on real load swings
- Endless â‰¥15 min pacing/density/perf
- Boss model readability in fight

## 7. Gameplay weaknesses
- Early 2-min pressure can still spike when bats swarm in packs
- Mage (enemy) volleys untested under 10+ mage groups
- Endless post-15min never measured on device

## 8. Visual weaknesses
- Character roster shares one model; only stat cards differ
- WEAPONS screen is placeholder text
- Relic pickup readability is subtle for new players

## 9. UX weaknesses
- Notice-label responses instead of real screens (weapons/achievements)
- First level-up card flow not explained beyond hint line

## 10. Performance risks
- Damage-number + muzzle light spam at 200+ entities (budgeted but
  unmeasured on mobile)
- Decor colliders add physics bodies near horde paths (18 rocks, cheap)

## 11. Save / deployment status
- SAVE_VERSION 1, meta_upgrades + gold + achievements persisted
  (IndexedDB on web), idempotent modifier keys, migration hook ready
- CI green historically; Pages live

## 12. Recommended next development order (prompt 5 P-phases)
P2 feel polish â†’ P3 character identity (per-character visuals) â†’
P4 menu/collection screens â†’ P5 boss presentation beats (intro/phase
moments) â†’ P6 Endless balance passes with real device numbers â†’
P7 mobile verification round â†’ P8 measured perf â†’ P9 meta polish â†’
P10 release sweep

## 13. G-series graphics overhaul (this commit)
- Heroes: KayKit Adventures rigged+animated (Mage/Knight/Rogue) with AnimationPlayer locomotion
- Enemies: KayKit Skeletons (minion/warrior/mage) + Barbarian/Rogue rigs; Kenney props for bat/wisp/ghost; rigs at EVERY quality tier
- Boss: 5.6m Skeleton_Warrior rig with per-phase tint + enrage emission
- Arena: KayKit Dungeon stone floor (900 tiles MM), perimeter walls, corner pillars, torches, banners, treasure props
- Pickups: xp_shard crystal GLB, potion bottle hearts, treasure-chest relics
- Fixes shipped in pass: projectile container group, set_deferred monitoring in body_entered, spawn queue bool + stress refit, muzzle-flash hitch guard, threaded rig preload
