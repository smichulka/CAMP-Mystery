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

## Cycle 3 — Deduction notebook drill + ghost agency UX

| Slice | Status | Notes |
|------|--------|-------|
| Notebook DeductionHint | Done | Investigation/Campfire strip: planted-vs-real; VerifiedFake banner; one-time compare-three at 2+ clues |
| Ghost agency UX | Done | MissionView GhostAgencyStrip / GhostMissionCopy / GhostSnapshotProgress; GameView GhostObjectiveStrip; RoundController surfaces GhostSnapshot |

## Cycle 4 — Campfire theater polish + bot discuss quality

| Slice | Status | Notes |
|------|--------|-------|
| Theater UI | Done | Stage banners + accent hierarchy; countdown via `campfireStageEndsAt` / `votingOpensAt`; discussion copy matches beat |
| Bot discuss | Done | Varied title+reason cites; Rebuttal contradicts VerifiedFake / known Planted; clearer announce titles |
| A11y | Done | High-contrast VoteView stage banner (white on accent + stroke) |

## Cycle 5 — Night route variety + Midway day actions

| Slice | Status | Notes |
|------|--------|-------|
| World routes | Done | 5th scenic route `LakeshoreNight` / `TownVariantE`; distinct district order; PreviewRouteForRound cycles via `seed % #variants` |
| Midway day | Done | `fair-supplies` + `popcorn-restock` day side actions → side-objective handler; loud announces; MissionView Midway Festival copy |
| Discovery tip | Done | TipCatalog rematch tip to try a different night route each round |

### Gates
- `compile_luau.py`: pass (112 source files)
- Contracts: WorldManifest LakeshoreNight; night side-objective Day Midway path; TipCatalog rematch + Midway

## Cycle 6 — Audio atmosphere + soft-launch preflight

| Slice | Status | Notes |
|------|--------|-------|
| Investigation audio | Done | FairgroundsAmbience overlay + CircusSting on Investigation; soft Music duck (`INVESTIGATION_MUSIC_DUCK`); attribute inventory header; nil placeholders only |
| Night ambience | Done | WorldAmbience denser night rope-creak window (14–32s); skipped Atmosphere density tweak |
| Soft-launch hooks | Done | `scripts/soft_launch_preflight.py` (monetization ban, Analytics Events, gates doc, compile/validate); wired in `run_all_checks.py`; documented in SOFT_LAUNCH_GATES |

### Gates
- `compile_luau.py` / related contract tests for AudioController + soft-launch preflight
- `python scripts/soft_launch_preflight.py`

## Cycle 7 — Retention meta + rematch friction

| Slice | Status | Notes |
|------|--------|-------|
| Mastery challenges | Done | CodexConfig +2: `shadow-survive-3` (Hold the Light), `banshee-identify-2` (Name the Wail) |
| Tips + featured | Done | TipCatalog CAMP STORE `{featured}` + STREAK + REMATCH tips; `formatBody`; LobbyView/GameView resolve via `GetFeaturedCosmeticId` |
| Streak copy | Done | ProgressionConfig.streakCopy; Rewards suffix + welcome toast say XP & tokens |
| Rematch CTA | Done | Results `PLAY AGAIN · KEEP PARTY` (gold, LayoutPass primary); lobby `SIGN UP · KEEP PARTY`; shorter rematch notice; SOON fill copy |

### Gates
- `compile_luau.py` / `run_all_checks.py` after Cycle 7 source edits

## Backlog after Cycle 7

1. Authored Camp/NightTown + final audio bank (asset pipeline; wire FairgroundsAmbienceAssetId / CircusStingAssetId)
2. Discovery triad: Creator Dashboard icon / thumbnail / 15s trailer
3. Mobile device soak confirmation before public Quick Camp promo
4. Global/reserved-server matchmaking (post soft-launch)
5. Cosmetics-only Robux shop allowlist only after D1/retention healthy

## Cycle 8 — Final audit polish (code-side competitive loop complete)

| Slice | Status | Notes |
|------|--------|-------|
| TODO/FIXME/HACK scan (`src/` UI, bots, fairgrounds, tutorial) | Done | No actionable TODO/FIXME/HACK markers; no broken-string / nil-check quick wins beyond CharacterService |
| CharacterService camper look | Done | `CamperLookApplied` only after successful CampArmband / `AccentWeld` path; R6-safe `resolveTorso` (no 10s UpperTorso stall); `LoadCharacterAppearance: true` confirmed in `default.project.json` |
| InterviewTopics | Done | Greeting + Safety still present (order Greeting → Observation → Schedule → Monster → Safety → Suspicion) |
| Contract drift | Done | Locked `test_camper_look_applied_only_after_torso_weld`; full `run_all_checks.py` / soft-launch preflight green |

### Gates
- `compile_luau.py` + `run_all_checks.py` (includes soft-launch preflight)

### Remaining EXTERNAL backlog only

## Interactable density pass (post Cycle 8)

| Slice | Status | Notes |
|------|--------|-------|
| InteractableWorld pack | Done | Camp + night town + Midway: inspect/sit/tune/play/ring/fortune/strongman/etc. |
| WorldKit.inspect / seat | Done | Shared helpers for feedback billboards + seats |
| Creator Store meshes | Studio | PicnicTable, BulletinBoard, RustyRadio, ParkBench quarantined in ServerAssets.Interactables |
| Tips | Done | ENVIRONMENT tips sell inspectables |

## Remaining EXTERNAL backlog

Code-side competitive loop Cycle 8 completes the autonomous pass. Remaining items need authored assets and/or human Studio / Creator Dashboard work:

1. Authored Camp/NightTown meshes + final audio bank (wire `FairgroundsAmbienceAssetId` / `CircusStingAssetId`)
2. Creator Dashboard discovery art (icon / thumbnail / 15s trailer)
3. Live mobile device soak before public Quick Camp promo
4. Reserved-server / global matchmaking (post soft-launch)
5. Post-retention cosmetics-only Robux shop allowlist (only after D1/retention healthy)
