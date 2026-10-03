# Fix & Improvement Log — This Session (post 0fd0a3c)

## Critical
- **Boss freeze**: slam telegraph never ticked (`_slam_timer` only decremented in `_tick_attacks`, skipped by early return) — boss stood telegraphing forever. (boss.gd)
- **Save atomicity**: `save_game()` wrote in place; now writes `.tmp` + atomic rename. Also fixed rename error check (`err != OK`). (save_manager.gd)
- **Save migration**: legacy quality 0..3 was stamped `quality_schema=2` before migration could read it. (save_manager.gd)

## Gameplay / systems
- 15-minute default victory no longer fires during kill_boss/kill_count missions; `target_duration` resets to 900s when mission cleared (no more inherited mission timers on normal runs). (run_manager.gd)
- Expired timed stat modifiers now removed individually (previously kept applying until all expired). (stat_block.gd)
- `release_enemy()` guards `has_method("despawn")` — releasing the boss no longer crashes mid-fight. (enemy_manager.gd)
- Boss phase change no longer re-emits `boss_spawned` (no repeated entrance banner/SFX). (boss.gd)
- Elite scale (1.3x) survives the spawn-in tween. (enemy.gd)
- Level-jump elite cadence: one elite per crossed 10-level threshold (loop). (wave_manager.gd)
- Splitter/elite kill-burst no longer crashes when `current_scene` is null. (enemy.gd)

## Combat / weapons
- Meteor strike lightning VFX: non-pooled instances `queue_free()` on expiry (leak). (lightning_strike.gd)
- AOE lightning: emptiness guard on pool index; hit loop validates enemy + health. (weapon_controller.gd, lightning_strike.gd)
- Projectiles: health-null guard in `_on_body_entered`. (generic_projectile.gd)
- Time Freeze returns real `applied` flag (was always true). (ability_controller.gd)
- Juice manager: prefers idle pooled VFX nodes; safe color read with default. (juice_manager.gd)
- `PoolManager.clear_all()` also clears pending-release/queue (no permanent leaked nodes). (pool_manager.gd)

## Progression / meta
- **Armor actually works now**: player syncs `health.armor` from stat block. (player.gd)
- Meta Bulwark upgrade grants flat armor (percent-of-zero was a no-op); same fix for Holy Aegis / Favored Fortune. (meta_shop.gd, progression_manager.gd)
- Evolved weapons no longer re-offered as NEW (base-id tracking). (progression_manager.gd)
- Hordebreaker (survive_15min) only unlocks on real 15-min survival, not short mission wins. (achievement_system.gd)
- Kills banked once per run end (was a disk write per kill). (achievement_system.gd)
- NEW BEST TIME badge compares against the pre-run best. (game_over_overlay.gd)
- Cleric (2 wins) and Ranger (4 wins) now announce unlocks too. (game_over_overlay.gd)
- Selected character persists across sessions (unlock check is victories-driven). (game_manager.gd, character_select verified)
- Campaign missions unlock by completing the previous mission (victory-count fallback kept). (mission_data.gd, campaign_menu.gd)
- Removed duplicate `m3_warden.tres` mission file (identical to m4).

## UI / input
- Touch input cleared on run start and on leaving PLAYING/BOSS (no sticky movement after pause). (main.gd, touch_controls.gd, input_manager.gd)
- Win countdown only shown for survive_time missions. (hud.gd)
- Settings sliders persist once per drag (debounced), not per tick. (settings_menu.gd)
- XP orbs re-apply value-based size/color on pool reuse. (xp_orb.gd)
- Heart pickup: `_collected` flag prevents double heal. (heart_pickup.gd)
- MusicDirector uses bound method connection (no leaked lambda on scene change). (main.gd)

## Polish (Phase 2)
- Relic beacon emission pulse (looping tween, killed on exit). (relic_pickup.gd)
- Achievement panel: gold ★ / gray ○ status badges per row. (achievement_panel.gd)
- Endless milestone tracker: 5-minute intervals, signal + `endless_best_minutes` save. (run_manager.gd)

## Verification
- 47 headless test suites green (test_phase8 known timing flake, passes on rerun — flake predates this session).
- All changed .gd files pass `gdparse` (gdtoolkit 4.5).
- Godot 4.3 headless import: 0 script errors.
