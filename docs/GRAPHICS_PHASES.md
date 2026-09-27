## Status: G1–G6 COMPLETE — 45/45 headless tests PASS

# GRAPHICS_PHASES â€” from geometric shapes to real 3D models

Goal: replace primitive/placeholder visuals (boxes, spheres, capsules) with
rigged, animated CC0 models for heroes, enemies, the boss, pickups, and the
arena environment â€” while keeping the web build fast (Compatibility
renderer, pooling, MultiMesh) and the primitive builders as last-resort
fallback for failed imports only.

## Asset research (free / CC0 packs)

| Source | What it offers | Chosen for | URL |
|---|---|---|---|
| **KayKit Adventures** (GitHub, CC0) | Rigged + animated humanoid GLBs (Idle/Walk/Run/Attack embedded, ~3.5MB each) | Heroes (Mage/Knight/Rogue), brute + hooded enemies | github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 |
| **KayKit Skeletons** (GitHub, CC0) | Rigged + animated skeleton GLBs (Minion/Warrior/Mage, ~4.7MB each) | Skeleton horde + BIG boss (Warrior @ 2.4x) | github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0 |
| **KayKit Dungeon Remastered** (GitHub, CC0) | 203 tiny modular dungeon GLBs (20â€“140KB): floors, walls, pillars, banners, torches, chests, coins | Arena floor/wall/perimeter + prop scatter | github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0 |
| Kenney Mini Characters / Fantasy Town / Skyboxes (already integrated) | Low-poly characters & nature props | wisp/bat/ghost/orc enemies, trees, rocks, skybox | kenney.nl |
| Quaternius (site/Patreon only) | Animated monsters, stylized nature | Evaluated â€” downloads gated behind Patreon/Drive; KayKit covers the same ground with direct raw-GLB URLs | quaternius.com |

License: all KayKit packs are CC0 â€” `LICENSE.txt` of each repo is mirrored
into `assets/models/kaykit/`.

## Phases

| Phase | Scope | Exit criteria |
|---|---|---|
| **G1 Fetch** | Download curated GLBs to `assets/models/kaykit/...`, reimport clean | `--headless --import` without errors; probe script asserts every GLB loads, has >=1 animation, sane AABB height |
| **G2 Characters** | hero_model.gd + enemy_visuals.gd use KayKit rigs; AnimationPlayer Idle/Walk by movement state; height auto-normalized; material tint/flash still works | test_v1/test_v2 updated + PASS; visible rigs in game at every quality tier |
| **G3 Boss** | Skeleton_Warrior x2.4 scale replaces the primitive boss stack, phase tint, death anim | test_p2_slice/boss probes PASS |
| **G4 Environment + pickups** | Dungeon floor tiles + perimeter wall + columns + banners + torches (MultiMesh batches); xp_shard/potion/chest/coin GLBs for pickups | test_v4 PASS; draw-call delta measured in stress scene |
| **G5 Quality** | GLB preferred at ALL tiers (primitives only if load fails); Web keeps Very-Low cheap path via import compression | stress >= same enemy budget as before; first-load not regressed beyond +pck size noted |
| **G6 Verify + ship** | Full headless suite, docs, commit, push to GitHub (CI re-exports web build) | ✅ 45/45 headless tests PASS, pushed |

## Guardrails

- No new O(n) per-frame work; pooled scenes unchanged.
- MultiMesh instances for decor (per-phase-2 rule); characters stay instanced.
- Every swap keeps the primitive path as fallback (ResourceLoader.exists check).
- Asset weight tracked in ASSET_CREDITS.md (approx +28MB pck source before import compression).

