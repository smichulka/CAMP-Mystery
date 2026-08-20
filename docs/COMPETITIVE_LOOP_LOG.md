# Competitive Improvement Loop Log

Evidence record for the continuous designer+developer loop. Do not treat this as a substitute for `RELEASE_CHECKLIST.md` or `SOFT_LAUNCH_GATES.md`.

## Cycle 1 — Master roadmap Waves 0–6 (shipped in source)

| Wave | Status | Notes |
|------|--------|-------|
| 0 Stabilize | Done | `resetBodyPose` after `applyArmSwing`; live Studio: 6 counselors + 9 bots, clean boot |
| 1 Deduction | Done | Interview Greeting/Safety; Deduction quiz + Ghost tutorial; louder day→night |
| 2 Fairgrounds | Done | Premium procedural circus; ticket/prize/fair-supplies sockets; tips + Reed pointer |
| 3 Theater/bots | Done | PresentEvidence → Rebuttal → Voting; bots cite clues; smoother bot walks |
| 4 Presentation | Done | Lighting/FarDress/audio Fairgrounds hooks; nametag/NPC polish |
| 5 Worlds | Done | Day Midway Festival; BackcountryNight route + lobby Route chip |
| 6 Live-ops | Done | Funnel AnalyticsService; featured cosmetics; CodexConfig; SOFT_LAUNCH_GATES |

### Live verify (Cycle 1)
- Console: Production server started; PolishPack 105/105; AnalyticsService events fire
- Characters: counselors=6 bots=9 in GeneratedCharacters
- Fairgrounds sockets present: `circus-ticket-booth`, `fair-supplies`

### Gates
- `compile_luau.py` / `validate_project.py`: pass (112 strict files)
- `run_all_checks.py`: re-run after contract token updates for featured cosmetics + fog

## Cycle 2 — Fairgrounds premium + streaming soak + discovery

| Slice | Status | Notes |
|------|--------|-------|
| Procedural Fairgrounds | Done | Richer tent/ferris/carousel/booths; dual MIDNIGHT CIRCUS / MIDWAY FESTIVAL signage |
| Streaming density | Done | More FarDress tags; fewer far lights/particles; StreamingMinRadius=128 docs |
| Discovery copy | Done | Stronger TipCatalog + lobby Fairgrounds tip + night-route chip copy |

Studio mesh install still optional (`CIRCUS_ASSETS.md`); procedural path is the shippable bar.

## Backlog after Cycle 2

1. Authored Camp/NightTown + final audio bank (asset pipeline)
2. Discovery triad: Creator Dashboard icon / thumbnail / 15s trailer
3. Mobile device soak confirmation before public Quick Camp promo
4. Deduction notebook drill depth + ghost agency UX (Cycle 3)
5. Campfire theater polish + bot discuss quality (Cycle 4)
6. Global/reserved-server matchmaking (post soft-launch)
7. Cosmetics-only Robux shop allowlist only after D1/retention healthy
