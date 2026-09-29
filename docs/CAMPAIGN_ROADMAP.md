# Campaign & Story Roadmap — 10 Sessions

> Goal: turn HordeSurvival 3D from a single endless arena into a **mission-based, story-driven** roguelite while staying browser-fast on weak machines.

## North star (what “done” looks like)
- A **world map** with missions (not one arena forever)
- Each mission has a **goal** (survive, escort, destroy, boss)
- Characters have **lore** tied to the main plot
- More weapons/relics; **3 weapon slots at start**, expandable via meta
- Story told via short pre/post mission text + character select lore
- Still playable at 30 FPS on low-end browsers

---

## Session map (next 10 meetings)

### Session 1 — Foundation: mission framework
- `MissionData` resource (id, title, briefing, map, win rule, waves)
- RunManager mission state + win checks beyond “survive 15:00”
- Menu: **Campaign** button → mission list (3 stub missions)
- **Win rule types:** `survive_time`, `kill_boss`, `kill_count`

### Session 2 — First story slice
- Opening cut-card (2–3 sentences) before mission 1
- Mission 1: “Ash at the Gate” — survive 5 min (tutorial mission)
- Mission complete card + gold reward
- Character select lore (already started) linked to campaign

### Session 3 — Map & second arena skin
- Simple world map UI (nodes + lines)
- Arena variant B: ice cavern palette (recolored dungeon + fog)
- Mission 2 in the ice map: kill 80 enemies

### Session 4 — Boss mission structure
- Mission 3: reach boss + kill Warden (shorter pre-boss waves)
- Briefing: “The Warden holds the lower gate”
- Victory cut-card + unlock flag

### Session 5 — Story characters #2 wave
- 2 new heroes (e.g. **Cleric**, **Ranger**) with unique start weapon + lore
- Character unlock via campaign progress (not only wins)
- Lore modal already in select — extend text lengths

### Session 6 — Weapon arsenal expansion
- +4 weapons (mix of projectile/orbit/aoe)
- **Start slots = 3**; meta upgrade `meta_slots` +1 per level (max 5)
- Level-up offer copy: “Unlock slot” vs “New weapon”

### Session 7 — Objectives in-run
- Side objectives: “Destroy 3 nests”, “Survive elite wave”
- HUD objective tracker (1 line)
- Bonus gold for side objectives

### Session 8 — Enemy story pack
- 2 new archetypes (e.g. **Brute**, **Specter**)
- Mission-specific wave tables
- Keep entity caps for weak browsers

### Session 9 — Ending & meta
- Mission 5 finale: multi-phase boss + ending card
- Campaign % complete on menu
- Meta shop: weapon slot upgrades (from Session 6) polished

### Session 10 — Performance + ship
- Load-time pass (prewarm only what’s needed; lazy GLBs)
- FPS budget checklist on 3 quality tiers
- Full suite + store-ready copy + trailer GIF

---

## Story spine (working title: **Torchfall**)
Long ago the **Heartforge** under the city powered the wards. When it cracked, the horde crawled up the dungeon stairs. The player is a **Torchbearer** — one of the last who can hold the light.

| Act | Missions | Beat |
|-----|----------|------|
| I — Gate | Ash at the Gate, Frostroad | Hold the outer wards |
| II — Deep | Ice Caverns, Nest Hunt | Push into the dungeon |
| III — Heart | The Warden, Heartforge | End the source |

Characters:
- **Mage** — scholar who read the crack too late
- **Paladin** — last shield of the old order
- **Rogue** — thief who steals light from the dark
- *(later)* Cleric, Ranger — recruited as the wards fall

---

## Design rules (performance first)
- Prefer MultiMesh / pooled VFX; never one Node3D per grass blade
- New maps = palette + fog + layout, not unique meshes if possible
- Cap enemies/projectiles by quality tier (existing PerformanceManager)
- Story text in files (`.tres` / JSON), not heavy scenes
- Lazy-load map B+ after mission select

---

## Weapon slot plan (Session 6 detail)
| Source | Slots |
|--------|-------|
| Default run | **3** |
| Meta `meta_slots` L1–L2 | +1 each (cap **5**) |
| Campaign milestone | optional +1 once |

Level-up UI:
- If `weapons.size() < max_slots`: offer **NEW WEAPON**
- Else: only tier/evolve/passive/heal

---

## Current status
- [x] Character lore on select (tap to read)
- [ ] MissionData + Campaign menu
- [ ] Story cut-cards
- [ ] Arena variant B
- [ ] Extra weapons + slot meta
- [ ] Objectives HUD
- [ ] Ending
