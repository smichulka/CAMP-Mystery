# CAMP-Mystery Growth UX (Track B)

Operational notes for discovery, session shape, and social loops after genre-best UX ships.

## Quick Camp vs Full Camp

- **Full Camp** uses `RoundConfig` production phase durations (~16 minutes authored).
- **Quick Camp** uses `quickCampDurationSeconds` on each phase (~7 minutes total).
- Players toggle **QUICK CAMP (~7m)** vs **FULL CAMP (~16m)** on the lobby card (`preferQuickCamp` profile setting).
- When the roster locks, a **majority of ready humans** with Quick Camp enabled sets `ReplicatedStorage.QuickCamp = true` for that round.
- Live-ops can still force Quick Camp by setting the attribute before rounds start.
- Studio continues to prefer `studioDurationSeconds` for fast iteration.

## Social lobby

- Lobby card shows roster, rotating camp tips, fill countdown, and **INVITE** (`SocialService:PromptGameInvite`).
- Ready / withdraw uses the same Enroll flow as before.
- End-of-round **PLAY AGAIN** queues `RematchReady` — auto sign-up when the lobby returns.
- **CONTINUE** dismisses results; ready players rematch with whoever stays.

## Discovery assets (Creator Dashboard)

Ship three assets that show the actual loop, not generic horror:

1. **Icon** — campfire + silhouetted cabins (readable at 512px).
2. **Thumbnail** — day camp tasks → night town → vote panel triptych.
3. **15s trailer** — lobby ready → role card → one objective → one clue → campfire vote.

## Live-ops (cosmetics only)

- Weekly featured monster **cosmetic** in `CosmeticCatalog` (no power).
- Rotating mystery seed titles in lobby tip rotation (content-only; no paywall).

## Performance gate

Before promoting Quick Camp publicly: mobile memory, streaming, and 10-client Studio soak per `RELEASE_CHECKLIST.md`.
