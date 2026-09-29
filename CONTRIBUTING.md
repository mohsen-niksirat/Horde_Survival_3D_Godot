# Contributing to HordeSurvival 3D

Thanks for your interest! This is a Godot 4.7 browser survival roguelite.
Contributions of all sizes are welcome — bug fixes, balance, content, docs.

## Quick start

1. Install [Godot 4.7+](https://godotengine.org/download) (project pins `4.7`)
2. Clone the repo and open `project.godot`
3. Press **F5** to play
4. Run headless tests before you open a PR:

```powershell
godot --headless --path . --script res://tests/smoke_phase1.gd
# plus any suite you touched, e.g. test_v5_juice.gd, test_phase8.gd
```

## Project layout

| Path | What lives there |
|------|------------------|
| `scenes/` | UI, player, enemies, boss, pickups, VFX |
| `scripts/` | Autoloads, combat, spawning, progression, audio, input |
| `data/` | Weapons, enemies, passives, relics, characters (`.tres`) |
| `tests/` | Headless `SceneTree` tests (`godot --headless --script res://tests/<t>.gd`) |
| `docs/` | Design, architecture, roadmap, asset credits |

**Code wins over older docs.** If `docs/` and `scripts/` disagree, trust the code.

## How to contribute

1. Fork and branch from `main` (`feat/…`, `fix/…`, `docs/…`)
2. Keep changes focused — one feature or fix per PR
3. Data-driven content is preferred: new weapons/enemies/relics = new `.tres` + registration in the relevant manager
4. Do not break Web export or the headless suite
5. Test locally (see above), then open a PR with:
   - What changed and why
   - How you tested (which `tests/*.gd` + any manual play notes)
6. For gameplay balance, include rough numbers (e.g. “level-ups felt too fast by min 8”)

## Style

- GDScript: tabs, typed where practical, `snake_case` functions, `PascalCase` classes
- Prefer EventBus signals over tight coupling
- Pool heavy VFX/enemies; avoid per-frame allocations
- Comments only when the *why* is non-obvious

## Content guidelines

- Keep silhouettes readable on the light dungeon floor (prefer darker tints)
- New weapons should have a role (projectile / orbit / aoe / pierce) and a flash color
- Evolutions need a base weapon at T5 + a maxed passive
- Avoid pay-to-win style meta power creep — meta shop should be modest

## Assets

- Only CC0 / permissive assets (see `docs/ASSET_CREDITS.md`)
- Do not commit large source ZIPs under `assets/models/external/`
- Credit authors in `docs/ASSET_CREDITS.md` when adding packs

## Reporting bugs

Open an issue with:

- Browser / OS (e.g. Chrome 140, Windows 11 / Android)
- Steps to reproduce
- Expected vs actual
- Screenshot or GIF if visual

## License

By contributing you agree your code is released under the MIT License (see `LICENSE`).
Third-party assets keep their own licenses (usually CC0).
