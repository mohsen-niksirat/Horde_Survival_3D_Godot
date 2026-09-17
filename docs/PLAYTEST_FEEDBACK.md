# PLAYTEST FEEDBACK LOG

> Per prompt 3 §18: each feedback is categorized (BUG/UX/BALANCE/VISUAL/AUDIO/
> PERFORMANCE/FEATURE) and the safest small fix is taken.

| # | Feedback | Category | Status |
|---|----------|----------|--------|
| 1 | spawn inside beacon | BUG | ✅ fixed (A1) |
| 2 | camera rotates while moving | BUG | ✅ fixed (top_level + remove binding) |
| 3 | stray red pointed object | BUG | ✅ removed (pet tail) |
| 4 | no pause button | UX | ✅ II button + Esc/P |
| 5 | scroll/pinch zoom | FEATURE | ✅ scroll + +/− buttons |
| 6 | shooting invisible enemies | BUG | ✅ pool visibility + nearest_visible + spawn ring 22-30m |
| 7 | mouse look not 360 | BUG | ✅ pointer lock |
| 8 | mobile two-finger conflict | BUG | ✅ full left/right split |
| 9 | mobile ~180° jump on 2nd finger | BUG | ✅ ignore simulated mouse-motion on touch |
| 10 | mobile touch rings | UX | ✅ TouchIndicator |
| 11 | mobile look slow while moving | BUG | ✅ accumulate touch look deltas |
| 12 | mobile zoom via buttons | UX | ✅ +/− buttons |
| 13 | hearts should magnet | UX | ✅ implemented (magnet d<6m + pick d<1.4m) |
| 14 | fewer heart drops | BALANCE | ✅ drop rate 5% |
| 15 | triangle/square shapes → real forms | VISUAL | OPEN — Phase 3 free GLB packs (KayKit/Quaternius/Kenney) |
| 16 | graphics Auto quality on heavy render | FEATURE | ✅ Auto quality persists; web defaults MED + faster step-down; lights/MSAA/shadows gated (Phase 1) |
