# POST-MVP ROADMAP (after current HEAD)

> Per prompt 4 §27: only post-HEAD work. Phases 0–13 + V1–V14 are DONE and pushed.
> Select the next phase AFTER each playtest round. Priority: bugs > feedback > feel > UX > polish > content.

## Immediate candidates (next 1–3 cycles)
- **V15A — Combat readability at scale**: elite aura rings, boss telegraph colors, damage-number throttling at 150+ entities (F3-measured) — ✅ done
- **V15B — Boss presentation**: dedicated boss model upgrade, intro camera moment, phase-transition flash, victory moment — ✅ done
- **V16 — Character identity pass**: Paladin aura VFX, Rogue dash trail, per-character color on hero model (audit current 3 first) — ✅ done

## Backlog (evidence-gated)
- **V17 — Build depth**: 2-3 more synergies + relic synergy hooks (only if playtests show flat builds) — ✅ done
- **V18 — Endless balance**: collect real 10/15/20-min numbers via F3 before touching scaling — ✅ soft-cap + F3 metrics landed
- **V19 — Settings additions**: UI scale, reduced-VFX mode (only if reported) — ✅ done
- **V20 — Release candidate**: docs/RELEASE_CHECKLIST.md sweep (per prompt 4 §V26) — ✅ checklist added

## Test/deploy baseline
- 24 headless suites green at HEAD; CI (Deploy Web Build) green; Pages live.
- Known flake risk: frame-count dependent waits in phase7/phase9 tests (rerun verifies).
- Real-device multi-touch: verified manually by the user (ring visuals + no jump); headless cannot cover.
