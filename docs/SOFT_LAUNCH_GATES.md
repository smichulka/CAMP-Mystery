# Soft-launch gates (Wave 6 live-ops)

Short checklist before opening a private soft-launch audience. Full release still
requires every section of [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

## Always true

- [ ] Monetization remains **banned**: no `MarketplaceService`, game passes,
      developer products, Robux prices, premium multipliers, or receipt handlers
      (see RELEASE_CHECKLIST §1 and domain contract tests).
- [ ] Cosmetics unlock with **camp tokens / level / streak only** (weekly featured
      discount is token-side, never Robux).

## Studio soak (from RELEASE_CHECKLIST)

- [ ] §2 Studio server-authority gate (2+ clients; 10 if capacity allows).
- [ ] §3 Complete round and mystery gate (solo + multiplayer; ten-round soak).
- [ ] §8 Performance: memory/script time after resets; mobile / streaming glance.
- [ ] Private experience stays private until soft-launch gates pass.

## Funnel telemetry events

Server-side via `src/server/Services/AnalyticsService.lua` (pcall-wrapped
`AnalyticsService:LogCustomEvent` / `FireCustomEvent`). Confirm Creator Dashboard
custom events populate after a published private soak (Studio does not deliver):

| Event | When |
| --- | --- |
| `JoinLobby` | Player added to lobby matchmaking |
| `Ready` | Ready / Enroll accepted in Lobby |
| `RosterLock` | Roster locks for a round |
| `PhaseEnter` | Every phase transition (`phase` field) |
| `VoteCast` | Campfire vote accepted |
| `Rematch` | RematchReady queued |
| `TutorialComplete` | Tutorial finished without skip |
| `TutorialSkip` | Tutorial skipped |
| `QuickCampToggle` | `preferQuickCamp` setting changed |

## Live-ops content smoke

- [ ] Weekly featured cosmetic shows FEATURED + discounted token price in Progress.
- [ ] Monster Codex shows mastery tier + challenge progress from `monsterStats`.
- [ ] Lobby tip rotation includes CAMP STORE / COUNTERPLAY mastery tips.

## After soft launch

Promote only when RELEASE_CHECKLIST is fully checked for the candidate commit.

## Automation

Repository-side soft-launch preflight (no Studio):

```text
python scripts/soft_launch_preflight.py
```

Also runs as a step inside `python scripts/run_all_checks.py` after release-readiness
simulations. Confirms monetization tokens stay banned, `AnalyticsService.Events`
funnel keys are present, `docs/SOFT_LAUNCH_GATES.md` exists, and Luau compiles
(or `validate_project.py` when `luau-compile` is not on PATH). Studio soak and
Creator Dashboard event population remain manual checklist items above.
