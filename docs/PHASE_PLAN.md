# Multi-Phase Improvement Plan — Horde Survival 3D

> Source of truth for post-HEAD work requested by the user:
> bugs → browser FPS → free 3D assets → implement/test/polish → push to Pages.
> Code wins over older docs. Each phase: implement → headless suite green → commit → push.

## Phase 0 — Audit (done this session)

- Repo: `https://github.com/mohsen-niksirat/Horde_Survival_3D_Godot`
- Local: `C:\Users\MOHSEN\Desktop\Horde Survival 3D` on `main`
- Findings: 24 code bugs (critical…low), browser perf hotspots, free-asset shortlist
- Local models present but unused/untracked: `assets/models/hero.glb`, `assets/models/xp_shard.glb`
- CI Godot pin `4.3-stable` vs project `4.7` mismatch

## Phase 1 — Critical bugs + browser FPS (P0) — IMPLEMENT NOW

### 1A. Gameplay / systems bugs
| ID | Fix |
|----|-----|
| BUG-01 | Time Freeze: skip enemies without `status` (boss crash) |
| BUG-02 | Relic cap: count only `relics` group, not Projectiles children |
| BUG-03 | Relic pickup: find RelicSystem via group, not parent walk |
| BUG-04 | Boss death: free body + update perf counter |
| BUG-05 | Pause→menu: do not double-count `total_kills` |
| BUG-06 | Pause→restart: bank run gold before restart |
| BUG-07 | Elite ring cleanup on pooled reuse |
| BUG-08 | Elite `request_minions` connect guard |
| BUG-09 | Burn×Lightning: check `status.has_effect("burn")` |
| BUG-10 | Ability/Combo/Relic systems `PROCESS_MODE_PAUSABLE` |
| BUG-11 | HUD zoom connect once (not every state change) |
| BUG-12 | Apply `gold_gain` stat to kill gold |
| BUG-13 | Orbit shield damage uses `weapon.get_damage()` |
| BUG-14 | Fireball AOE emits `enemy_damaged` |
| BUG-16 | Healers skip boss |
| BUG-17 | Meteor cooldown refund when no targets |
| BUG-18 | Kill enemy tweens on despawn |
| BUG-19 | Prune orbit hit-cooldown dict |
| Q-AUTO | Persist quality Auto (settings index 3) across sessions |

### 1B. Browser performance (P0)
| ID | Fix |
|----|-----|
| PERF-01 | Cache DirectionalLight3D refs; no per-frame `find_children` |
| PERF-02 | Web defaults: MSAA off, shadows off on LOW/MED web, lower enemy caps |
| PERF-03 | Auto quality: persist flag; web starts MED (or LOW touch); step-down faster |
| PERF-04 | Gate OmniLights/projectile lights by quality tier |
| PERF-05 | Enforce `damage_number_cap` in juice manager |
| PERF-06 | Custom shell: keep progress bar visible after PLAY click |
| PERF-07 | CI Godot version align to 4.7-stable |
| PERF-08 | Enemy manager cull without per-frame `duplicate()` + valid player check |

### Acceptance
- Headless suites smoke_phase1 + phase2–10 + critical path tests green
- Manual: no Time Freeze crash with boss; relics spawn/pickup; pause gold/kills correct
- F3 overlay works; quality Auto survives browser refresh
- Push to `main` → GitHub Actions deploys Pages

## Phase 2 — Browser FPS deep (P1) — ✅ implemented

- Spatial hash targeting ✅ (`enemy_manager.gd` uniform grid, linear fallback <20)
- Enemies: AI/anim LOD + phasing write gate + health process only when invincible
- Shared enemy materials + instance-unique flash/elite mats ✅
- XP orbs: far/settled poll LOD (full MultiMesh deferred to later phase)
- Orbit shield: cached EM + staggered hit checks on LOW/MED ✅
- Arena decor MultiMesh (grass/trees/pillars; rocks keep colliders) ✅
- Render scale web LOW 0.6 / MED 0.75 ✅
- Wave spawn scheduling max 8/frame + queue cap 48 ✅
- Prewarm enemy pool at run start ✅
- Homing retarget every 0.15s ✅
- New test: `tests/test_phase2_perf.gd` ✅

## Phase 2.5 — Graphics tiers + FPS + horde stress — ✅ this session

User requirements:
- Quality options: Very Low / Low / Medium / High / Ultra / Auto
- **Default = Very Low** so first browser load is fast; players raise if they want
- On-screen **FPS** + quality tier (HUD top-right)
- Horde stress: effective cap shrinks, Auto steps down faster, far-enemy physics LOD
- Code optimization continues (spatial hash, MultiMesh, shared mats from Phase 2)

Save migration: legacy quality 0..3 → new LOW..HIGH/Auto via `quality_schema=2`.

## Phase 2.7 — Magnet UX + first-load + fullscreen — ✅ this session

- Magnet pickup looks like a **horseshoe magnet** (red/blue poles), not a gem
- Magnet triggers a **soft 5s XP wave**: staggered pull, ease-in speed, slight swirl
- First-load: smaller pool/VFX prewarm on Very Low/web; export excludes `assets/models/external/*`
- **Fullscreen toggle**: F11 / Alt+Enter on desktop; **FS** button next to zoom on mobile; Settings checkbox kept in sync

## Phase 3 — Free graphics integration

**Detailed build sheet:** `docs/PHASE3_GRAPHICS.md`

| Category | Pack | License | URL |
|----------|------|---------|-----|
| Player | KayKit Adventurers | CC0 | https://kaylousberg.itch.io/kaykit-adventurers |
| Animations | KayKit Character Animations | CC0 | https://kaylousberg.itch.io/kaykit-character-animations |
| Enemies | KayKit Skeletons | CC0 | https://kaylousberg.itch.io/kaykit-skeletons |
| Enemies alt | Quaternius Ultimate Monsters | CC0 | https://quaternius.com/packs/ultimatemonsters.html |
| Weapons | Quaternius Modular Weapons | CC0 | https://quaternius.com/packs/medievalweapons.html |
| Props | Quaternius Fantasy Props MegaKit | CC0 | https://quaternius.com/packs/fantasypropsmegakit.html |
| Arena nature | KayKit Forest Nature | CC0 | https://kaylousberg.itch.io/kaykit-forest |
| Arena structures | Kenney Fantasy Town / Castle / Tower Defense | CC0 | https://kenney.nl/assets/fantasy-town-kit |
| Sky | Kenney Skyboxes | CC0 | https://kenney.nl/assets/skyboxes |
| UI | Kenney Fantasy UI Borders + Board Game Icons | CC0 | https://kenney.nl/assets/fantasy-ui-borders |

Sub-phases:
1. **3A Hero** — import KayKit mage/knight GLB, wire animations, keep collision
2. **3B Enemies** — map 9 archetypes to skeleton/monster meshes + shared anims
3. **3C Weapons** — weapon prop meshes on hero + orbit/spear visuals
4. **3D Environment** — MultiMesh trees/rocks/walls + skybox, replace primitive arena
5. **3E Polish** — per-character skins (Mage/Paladin/Rogue), relic beacon VFX

Rules: prefer `.glb`, atlas textures, keep poly budgets for WebGL; record license per pack; never use CC-NC.
Quality gates: Very Low stays primitive/light; Medium+ uses full GLB + sky.

### Pointer lock / browser cursor

Browser infobar “press Esc to see mouse” is Pointer Lock. Game now:
- Releases lock on menu/pause/level-up/game-over/focus-out/tab-hide/pagehide
- Self-heals in `Main._process` if not PLAYING/BOSS but lock is held
- Shell JS exits lock on blur/visibilitychange/pagehide
If the tab is fully closed, any leftover message is the browser UI itself.

## Phase 4 — Content + UX polish

- Weapons menu real grid (replace placeholder)
- Relic beacon pulse
- Achievement icons
- Per-character visuals from Phase 3 packs
- Endless balance pass with F3 device numbers

## Phase 5 — Release sweep

- Docs sync (PLAYTEST_FEEDBACK, CURRENT_STATE URLs, README feature counts)
- README Pages URL + asset credits
- Stress tests on Chrome desktop + Android Chrome
- Version tag + release notes

## Deploy contract

Every phase after tests:
1. Run headless suite (Godot 4.7.2 local / CI 4.7)
2. Commit with `fix/perf/feat/docs` prefix
3. Push `origin/main`
4. Confirm Actions “Deploy Web Build” green
5. Live: https://mohsen-niksirat.github.io/Horde_Survival_3D_Godot/
