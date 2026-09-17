# HordeSurvival 3D

<p align="center">
  <img src="ScreenShots/ScreenShot 03_title.jpg" alt="HordeSurvival 3D" width="560"/>
</p>

A stylized third-person survival roguelite for the browser. Survive increasingly dangerous hordes, auto-attack weapons, collect XP, choose powerful upgrades, evolve weapons, fight elites and a phased boss — and build increasingly broken runs.

<p align="center">
  <table>
    <tr>
      <td><img src="ScreenShots/ScreenShot 01_v2.0.jpg" alt="Gameplay 1" width="300"/></td>
      <td><img src="ScreenShots/ScreenShot 02_v2.0.jpg" alt="Gameplay 2" width="300"/></td>
    </tr>
  </table>
</p>

**Play:** https://mohsen-niksirat.github.io/Horde_Survival_3D_Godot/ (after Pages is enabled)

Inspired by the gameplay philosophy of [HordeSurvival (Android)](https://github.com/mohsen-niksirat/HordeSurvival), rebuilt from scratch as an independent Godot 4 project.

## Features

- Third-person 3D arena combat, camera-relative movement, zero aiming
- 5 auto-firing weapons + 5 evolutions (Hellfire, Holy Bible, Aurora, Judgment, Thunderstorm)
- 9 enemy archetypes + 8 modular elite abilities + one complete 3-phase boss
- XP orbs with magnet pickup, level-ups with 3 rarity-colored choices, 8 passive items
- Relics (rarity-weighted map pickups incl. Phoenix Feather revive), a pet (Dragon Welp), 2 active abilities (Meteor Strike, Time Freeze)
- Combo system with XP multiplier and 6 visual tiers, 10 achievements with gold rewards
- Threat-budget horde spawning, difficulty timeline, quality-tier entity caps
- Versioned meta save (gold, bests, achievements) that persists in the browser
- Responsive HUD; virtual joystick + touch camera on mobile
- Kenney CC0 GLB heroes/enemies/weapons/skybox (see docs/ASSET_CREDITS.md); quality Very Low→Ultra + FPS counter

## How to Run Locally

1. Install [Godot 4.7+](https://godotengine.org/download) (project features pin `4.7`)
2. Open `project.godot` in the Godot editor
3. Press **F5** (Play)

## How to Export Web

1. In Godot: **Project → Export → Web** (preset included in `export_presets.cfg`)
2. Ensure the Web export templates are installed (Editor → Manage Export Templates)
3. Export to `build/web/index.html`

Or use the CI workflow (below) which does this automatically.

## How to Deploy to GitHub Pages

Deployment is automated via GitHub Actions (`.github/workflows/deploy-web.yml`):

1. Push to `main`
2. Enable **Settings → Pages → Source: GitHub Actions** (one time)
3. The workflow builds the Web export and deploys it to Pages

Manual URL after setup: `https://mohsen-niksirat.github.io/Horde_Survival_3D_Godot/`

## How to Export Android (future)

Architecture is Android-compatible (Compatibility renderer, touch-first input abstraction). Android export steps will be added post-MVP: install Android build template (`Project → Install Android Build Template`), add the Android preset, export APK/AAB.

## Controls

| Action | Desktop | Mobile | Gamepad |
|---|---|---|---|
| Move | WASD / Arrows | Left virtual joystick | Left stick |
| Camera | Mouse (captured) / Arrow keys | Right touch drag | Right stick |
| Ability 1 (Meteor) | Q | Button | Trigger |
| Ability 2 (Freeze) | E | Button | Trigger |
| Fullscreen toggle | F11 or Alt+Enter | FS button (next to zoom) | — |
| Pause | Esc | — | Start |
| Debug overlay | F3 | — | — |

## Architecture Overview

```
scenes/  bootstrap · main · menu · world · player · enemies · weapons · bosses · pickups · ui
scripts/ core · player · combat · enemies · spawning · weapons · abilities · items ·
         progression · save · input · audio · performance · utilities
data/    weapons · enemies · passives · relics · abilities (all .tres data-driven)
web/     custom HTML shell (loading bar, Click-to-Play, WebGL fallback)
tests/   headless smoke + phase test suites (godot --headless --script tests/<t>.gd)
```

Key systems:
- **Autoloads**: EventBus (signal hub), RunManager (run session), GameManager (state machine), InputManager (platform abstraction), PoolManager (deferred-release pooling), SaveManager (versioned JSON), AudioManager (procedural SFX), PerformanceManager (quality tiers + caps)
- **Per-run**: WaveManager (threat budget), EnemyManager (registry + queries), ProgressionManager (level-ups/evolutions), RelicSystem, ComboManager, AchievementSystem, AbilityController
- **Data-driven**: all content lives in `.tres` resources — new enemies/weapons/relics = new resource files
- **Combat pipeline**: single DamageEvent flow (crit → armor → status → death → loot → combo → achievements)

## Development

Phased development per `docs/ROADMAP.md`; design rationale in `docs/GAME_DESIGN.md`, `docs/ARCHITECTURE.md`, and reference analysis in `docs/EXISTING_GAME_ANALYSIS.md`.

Run all headless tests:

```powershell
godot --headless --path . --script res://tests/smoke_phase1.gd   # (and test_phase2..10)
```
