# Project Map — HordeSurvival 3D

## 1. Root & Core Entry Points
- [`project.godot`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/project.godot): Engine configuration, physics layers (Player, Enemies, Projectiles, Pickups, World, Hitbox), rendering settings (`gl_compatibility`), 10 autoload singletons, and input mappings.
- [`scenes/bootstrap/Boot.tscn`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scenes/bootstrap/Boot.tscn): Application entry point (`run/main_scene`). Initializes settings and transitions to the main menu.
- [`scenes/main/Main.tscn`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scenes/main/Main.tscn) / [`scenes/main/main.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scenes/main/main.gd): Root run orchestrator. Instantiates per-run managers (`EnemyManager`, `WaveManager`, `ProgressionManager`, `RelicSystem`, `ComboManager`, `AbilityController`, `JuiceManager`, `MusicDirector`), attaches player references, sets up projectile root, and configures HUD/overlays.
- [`scenes/menu/MainMenu.tscn`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scenes/menu/MainMenu.tscn): Main menu interface with sub-panels for Character Selection, Campaign Missions, Meta Shop, Weapon Codex, Achievements, and Settings.

---

## 2. Directory Layout & Module Responsibilities

### `scripts/` — GDScript Source Code
- [`scripts/core/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/core/): Global singletons and foundation models.
  - `game_manager.gd`: State machine (BOOT → MAIN_MENU → CHARACTER_SELECT → GAME_START → PLAYING ⇄ LEVEL_UP / PAUSED → BOSS → GAME_OVER → RESULTS), pointer lock management, Android back button routing.
  - `event_bus.gd`: Central event dispatcher with typed signals for combat, game state, XP, upgrades, and platform lifecycles.
  - `run_manager.gd`: Session state, timer, kill counter, gold tracking, endless 5-min milestones, and campaign mission objectives.
  - `stat_block.gd`: Additive/multiplicative stat modification pipeline (`StatBlock`).
  - `mission_data.gd`: Resource definition for campaign stages and objectives.
  - `localization.gd`: Runtime CSV translation loader with RTL layout configuration.
  - `analytics.gd`: Local anonymous run logging.
- [`scripts/spawning/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/spawning/): Horde management and enemy generation.
  - `enemy_manager.gd`: Active enemy registry, spawn queue with hitch-guard budgeting, uniform 8m spatial hash grid, and distance culling (55m).
  - `wave_manager.gd`: Time-based threat budget, enemy spawn ring generation (22–30m), elite selection, and boss spawning trigger.
  - `difficulty_manager.gd`: Mathematical scaling curves for enemy HP, damage, and move speed over time.
- [`scripts/combat/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/combat/): Combat resolutions and juice.
  - `damage_event.gd`: Struct/class defining damage packets (amount, crit, element, knockback, source).
  - `health_component.gd`: HP tracking, armor reduction, invincibility frames, death signals.
  - `status_component.gd`: Status effect ticks and application (Burn, Slow, Freeze).
  - `targeting_system.gd`: Spatial queries for nearest, lowest-HP, and random enemies.
  - `juice_manager.gd`: Spawns pooled floating 3D damage numbers, hit sparks, and death bursts.
- [`scripts/weapons/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/weapons/): Auto-firing weapons framework.
  - `weapon_controller.gd`: Holds active `WeaponInstance`s, ticks cooldowns, instantiates projectiles/orbits/strikes.
  - `weapon_instance.gd`: Runtime wrapper for weapon tier upgrades, cooldown timers, and volley firing.
  - `weapon_data.gd`: Custom Resource schema for weapon archetypes (projectile, orbit, aoe, piercing).
  - `weapon_balance.gd`: Shared mathematical model for DPS balance validation across tiers.
- [`scripts/player/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/player/): Player entity mechanics.
  - `movement_component.gd`: Camera-relative steering, acceleration, and arena bounds clamping.
  - `dash_component.gd`: High-speed dash burst with 0.25s invincibility frames and 2.5s cooldown.
  - `experience_component.gd`: XP accumulation and level threshold calculations.
  - `camera_rig.gd`: SpringArm3D orbit camera, smoothing, zoom bounds, and look delta application.
- [`scripts/enemies/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/enemies/): Enemy behaviors and elite modifiers.
  - `enemy_data.gd`: Resource definition for enemy stats, threat cost, speed, and archetype.
  - `elite_component.gd` & `elite_ability.gd`: Modular elite enhancements (fast, tank, mortar, shield, aura).
- [`scripts/progression/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/progression/): In-run and meta upgrades.
  - `progression_manager.gd`: Level-up card generation (3 rarity-weighted choices), weapon upgrades, passives.
  - `upgrade_option.gd`, `evolution_data.gd`, `passive_data.gd`: Progression resource definitions.
  - `combo_manager.gd`: Kill combo counter, streak reset timers, and XP multiplier scaling (up to 6 visual tiers).
  - `achievement_system.gd`: 15 milestone achievements and gold grant triggers.
- [`scripts/items/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/items/): Map pickups and relics.
  - `relic_system.gd` & `relic_data.gd`: Rarity-weighted relic spawning, beacon pillars, and modifier application.
- [`scripts/performance/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/performance/): Performance optimization.
  - `performance_manager.gd`: Quality tiers (Very Low, Low, Medium, High, Ultra, Auto), entity caps, dynamic 3D resolution scaling (0.4–1.0), and performance telemetry.
- [`scripts/save/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/save/): Persistence.
  - `save_manager.gd`: Atomic file writes (`meta_save.json.tmp` → `meta_save.json`), migration switches, deep-merged defaults.
- [`scripts/input/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/input/): Platform input.
  - `input_manager.gd`: Device abstraction unifying mouse capture, virtual joystick touch events, gamepad sticks, and Android back button handlers.
- [`scripts/audio/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/audio/): Sound & music.
  - `audio_manager.gd`: Master/Music/SFX bus volumes, one-shot SFX playback.
  - `music_director.gd`: Multi-layer procedural dynamic music responding to horde intensity.
  - `sfx_binder.gd`: EventBus signal listener triggering appropriate sound effects.
- [`scripts/ui/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/ui/): Mobile UI adaptations.
  - `safe_area.gd`: Applies viewport insets from display cutouts/notches to HUD and touch overlays.
- [`scripts/utilities/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scripts/utilities/): Utilities.
  - `pool_manager.gd`: General object pooler with prewarming and deferred node release.
  - `rig_util.gd`: Helper for model bone rigs and animation extraction.
  - `external_links.gd`: Safe external link opener across Web and desktop/mobile OS.

---

### `data/` — Static Godot Resources (`.tres`)
- [`data/weapons/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/data/weapons/): 14 base weapons (`fireball`, `magic_missile`, `lightning`, `holy_bible`, `divine_spear`, `orbiting_shield`, `void_lance`, `frost_bolt`, `soul_fire`, `aurora`, `judgment`, `thunderstorm`, etc.) and 6 evolutions (`evo_hellfire`, `evo_holy_bible`, `evo_aurora`, `evo_judgment`, `evo_thunderstorm`, `evo_void_reaver`).
- [`data/characters/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/data/characters/): 7 hero definitions (`mage`, `paladin`, `cleric`, `rogue`, `ranger`, `stormcaller`, `warden`).
- [`data/enemies/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/data/enemies/): 14 enemy archetypes (`basic_drone`, `fast_wisp`, `tank_golem`, `shooter_turret`, `swarm_bat`, `ghost`, `splitter`, `healer`, `mage`, `specter`, `brute`, `ember_runner`, `crystal_guard`, `broodling`, `brood_keeper`).
- [`data/passives/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/data/passives/): 13 passive stat boost items (`spinach`, `heart`, `crown`, `wings`, `empty_tome`, `magnet`, `growth`, `vampire`, `hunters_mark`, `iron_bark`, `ember_lens`, `time_sand`, `quartz_heart`).
- [`data/relics/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/data/relics/): 6 map relics (`phoenix_feather`, `armor`, `clover`, `crown`, `ring`, `wings`).
- [`data/abilities/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/data/abilities/): Active cooldown abilities (`meteor_strike`, `time_freeze`).
- [`data/missions/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/data/missions/): 8 campaign missions (`m1_gate` through `m7_hollow`).

---

### `scenes/` — Scene Hierarchies (`.tscn`)
- [`scenes/player/Player.tscn`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scenes/player/Player.tscn): Player CharacterBody3D, attached components, CameraRig, mesh, and weapon controller.
- [`scenes/enemies/Enemy.tscn`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scenes/enemies/Enemy.tscn): Pooled enemy instance with HealthComponent, EliteComponent, StatusComponent.
- [`scenes/bosses/Boss.tscn`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scenes/bosses/Boss.tscn): 3-phase arena boss encounter.
- [`scenes/ui/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scenes/ui/): `HUD.tscn`, `LevelUpOverlay.tscn`, `PauseOverlay.tscn`, `GameOverOverlay.tscn`, `TouchControls.tscn`, `ScreenFeedback.tscn`.
- [`scenes/menu/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scenes/menu/): `MainMenu.tscn`, `CharacterSelect.tscn`, `CampaignMenu.tscn`, `MetaShop.tscn`, `WeaponCodex.tscn`, `SettingsMenu.tscn`, `AchievementPanel.tscn`.
- [`scenes/world/Arena.tscn`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scenes/world/Arena.tscn): Arena bounds, ground, lighting, and palette shift materials.
- [`scenes/weapons/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scenes/weapons/): Projectiles and visual scenes for all weapon types.
- [`scenes/pickups/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scenes/pickups/): `XpOrb.tscn`, `HeartPickup.tscn`, `MagnetDrop.tscn`, `RelicPickup.tscn`.
- [`scenes/vfx/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/scenes/vfx/): `DamageNumber.tscn`, `ImpactBurst.tscn`, `KillBurst.tscn`, `MuzzleFlash.tscn`.

---

### `tools/` and `tests/` — Tooling & CI Validation
- [`tools/run_tests.py`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/tools/run_tests.py): Headless regression runner providing each test script with a sandboxed temporary `user://` directory to prevent state cross-contamination.
- [`tools/balance_table.gd`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/tools/balance_table.gd): Standalone script printing calculated weapon DPS and tier curves.
- [`tests/`](file:///c:/Users/MOHSEN/Desktop/Github%20Projects/Horde_Survival_3D_Godot/tests/): 62 GDScript test scripts covering combat math, save round-trips, pooling balance, mobile insets, weapon balance curves, and localization.

---

## 3. Where to Look for Common Changes
| Change Goal | Primary Files & Paths |
|---|---|
| **Add / Balance a Weapon** | `data/weapons/<weapon>.tres`, `scripts/weapons/weapon_balance.gd`, `scripts/weapons/weapon_controller.gd`, `tests/test_v26a_balance_table.gd` |
| **Add / Tune an Enemy** | `data/enemies/<enemy>.tres`, `scenes/enemies/Enemy.tscn`, `scripts/spawning/wave_manager.gd` |
| **Add / Balance a Passive** | `data/passives/<passive>.tres`, `scripts/progression/progression_manager.gd` |
| **Add a Playable Character** | `data/characters/<hero>.tres`, `scenes/menu/character_select.gd`, `scripts/progression/character_data.gd` |
| **Add / Tune a Mission** | `data/missions/<mission>.tres`, `scenes/menu/campaign_menu.gd`, `scripts/core/run_manager.gd` |
| **Modify Player Mechanics / Dash** | `scenes/player/player.gd`, `scripts/player/movement_component.gd`, `scripts/player/dash_component.gd` |
| **Adjust HUD / UI Layout** | `scenes/ui/HUD.tscn`, `scenes/ui/hud.gd`, `scripts/ui/safe_area.gd` |
| **Persistence / Meta Progression** | `scripts/save/save_manager.gd`, `scenes/menu/meta_shop.gd`, `scripts/progression/achievement_system.gd` |
| **Performance Caps / Resolution** | `scripts/performance/performance_manager.gd`, `scripts/spawning/enemy_manager.gd` |
| **Translations & Localized Strings** | `locale/en.csv`, `locale/fa.csv`, `scripts/core/localization.gd` |
| **Web Shell & Service Worker** | `web/custom_shell.html`, `web/sw.js`, `export_presets.cfg` |
