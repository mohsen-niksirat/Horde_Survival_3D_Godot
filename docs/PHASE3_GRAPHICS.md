# Phase 3 — Free graphics integration (detailed build sheet)

> After pointer-lock fix + quality/FPS phase. Goal: replace primitive
> placeholder meshes with cohesive free CC0/QAL packs, without blowing
> WebGL budgets. Each sub-phase: implement → headless suite green →
> commit → push → user playtest on Pages.

## License shortlist (verified)

| Role | Pack | License | Download |
|------|------|---------|----------|
| Player + weapons | KayKit Adventurers | CC0 | https://kaylousberg.itch.io/kaykit-adventurers |
| Animations | KayKit Character Animations | CC0 | https://kaylousberg.itch.io/kaykit-character-animations |
| Enemies | KayKit Skeletons | CC0 | https://kaylousberg.itch.io/kaykit-skeletons |
| Enemies alt | Quaternius Ultimate Monsters | CC0 | https://quaternius.com/packs/ultimatemonsters.html |
| Weapons/props | Quaternius Modular Weapons + Fantasy Props | CC0 | https://quaternius.com/packs/medievalweapons.html |
| Arena nature | KayKit Forest Nature | CC0 | https://kaylousberg.itch.io/kaykit-forest |
| Arena buildings | Kenney Fantasy Town / Castle | CC0 | https://kenney.nl/assets/fantasy-town-kit |
| Sky | Kenney Skyboxes | CC0 | https://kenney.nl/assets/skyboxes |
| UI | Kenney Fantasy UI Borders + Board Game Icons | CC0 | https://kenney.nl/assets/fantasy-ui-borders |

Rules: prefer `.glb`, atlas textures, no CC-NC, keep tris low for WebGL,
record pack URL in `docs/ASSET_CREDITS.md`.

## 3A — Hero (status: implemented)

1. ~~Download KayKit Adventurers~~ — itch.io needs interactive download.
   **Shipped instead:** Kenney Mini Characters (CC0) GLB hero variants.
2. Assets live under `assets/models/heroes/hero_{mage,paladin,rogue}.glb`.
3. Godot import: run `--import` once; GLB scenes load as PackedScene.
4. `hero_model.gd` instantiates character GLB, hides primitive robe, scales
   to capsule (~1.55×), tints per Mage/Paladin/Rogue.
5. Procedural bob on GLB root (no AnimationPlayer required).
6. Staff orb primitive kept for weapon muzzle reference when using fallback.
7. Very Low still uses primitive mage for max FPS; GLB hero loads always
   (single character, cheap).
8. Test: `tests/test_phase3a_assets.gd`.

Acceptance: hero readable at 3m, no collision regressions, Very Low still fast.

## 3B — Enemies

Map 9 archetypes to pack meshes:

| Archetype | Source mesh idea |
|-----------|------------------|
| basic_drone | floating bot / small golem |
| fast_wisp | ghost / flame spirit |
| tank_golem | skeleton golem / large brute |
| shooter_turret | modular tower piece |
| swarm_bat | small flying creature |
| ghost | KayKit/Quaternius ghost |
| splitter | slime if available, else tinted blob + keep primitive fallback |
| healer | robed skeleton mage |
| mage | skeleton mage |

Implementation:
- `enemy_visuals.gd`: load cached PackedScenes per archetype instead of primitives.
- Shared AnimationPlayer clips: walk/hit/death from Character Animations pack
  (retarget if bone names match; else simple scale/pos anims as now).
- Elite gold tint: modulate mesh material or overlay ring (already have ring).
- Very Low quality: optional LOD0 primitive fallback if GLB draw cost high.

Acceptance: silhouette readable, pooling still works (`visibility_fix` green).

## 3C — Weapons & projectiles

- Orbit shields: Quaternius shield meshes on orbit nodes.
- Divine spear projectile mesh from weapons pack.
- Fireball/lightning: keep procedural emissive meshes + particles (no free VFX pack).
- Hero staff from Adventurers pack.

Acceptance: weapons fire same damage/logic; only visuals change.

## 3D — Environment

1. Kenney Skyboxes → `WorldEnvironment` PanoramaSky on Medium+ only
   (Very Low keeps current gradient / no sky texture download in PCK if possible
   — or embed one small day sky).
2. KayKit Forest trees/rocks → MultiMesh instances in `arena_decor.gd`
   (reuse Phase 2 MultiMesh path).
3. Optional Kenney castle walls for boundary pillars on Medium+.
4. Very Low: keep cheap primitives / fewer MultiMesh instances.

Acceptance: run start draw calls not higher than current MultiMesh baseline
on Very Low; Medium+ looks like a place.

## 3E — Polish

- Character select cards use hero portraits (screenshot or simple icon).
- Relic beacon: emissive pulse already exists; add Kenney icon texture optional.
- `docs/ASSET_CREDITS.md` + README credits line.
- Settings note: Ultra enables sky + more decor instances.

## Perf budget (hard)

| Tier | Hero/enemy meshes | Decor | Sky |
|------|-------------------|-------|-----|
| Very Low | GLB + no anim LOD far | primitive MultiMesh | off |
| Low | GLB | reduced MultiMesh | off |
| Medium | GLB + anim | full MultiMesh + forest | on |
| High/Ultra | + lights already gated | full | on |

Never add per-enemy unique materials; use kit atlas materials + unique copies only for elite/flash.

## Order after this sheet is approved in-session

1. Pointer-lock fix + tests + push (done in this turn if green)
2. 3A Hero GLB integration
3. 3B Enemies
4. 3C Weapons
5. 3D Environment + sky
6. 3E Credits/polish + Pages playtest

## Browser note (pointer lock)

If the browser still shows “press Esc to see mouse” after closing the game:
- Confirm the **game tab is fully closed** (not just fullscreen exit).
- Another tab/window of the same build can still hold Pointer Lock.
- Our shell + engine now call `exitPointerLock` on blur/hide/pagehide/menu.
  Residual message after a hard tab close is a **browser UI**, not the game.
