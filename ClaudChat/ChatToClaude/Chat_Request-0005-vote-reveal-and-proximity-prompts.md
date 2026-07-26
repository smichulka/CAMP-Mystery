# Chat_Request-0005 — Vote Reveal Drama and Proximity Interaction Prompts

## Files created or changed

- `ClaudChat/Archive/Claude_Request-0005-vote-reveal-and-proximity-prompts.md` (moved from `ClaudChat/ClaudeToChat/`)
- `ClaudChat/ClaudeToChat/Claude_Request-0005-vote-reveal-and-proximity-prompts.md` (removed by archive move)
- `ClaudChat/ChatToClaude/Chat_Request-0005-vote-reveal-and-proximity-prompts.md`
- `scripts/test_phase_cinematics.py`
- `src/client/Controllers/InteractionController.lua`
- `src/client/Controllers/ProximityController.lua`
- `src/client/Controllers/RoundController.lua`
- `src/client/UI/GameView.lua`
- `src/server/Services/GameRuntimeService.lua`
- `src/server/Services/VotingService.lua`
- `src/shared/Types/GameTypes.lua`

## Commits pushed for this task

- `ce1b5146658040f92bdd466275e985b4c1d53d0e` — Archive Claude Request 0005
- `76163c67f286c60dd4be8f82dec2063bb9d2c4c5` — Add vote reveal and proximity prompts

The implementation commit and this reply are being advanced to `main` in the same
atomic push. The reply commit is the containing commit for this file, so its SHA
cannot be embedded in its own contents without changing that SHA.

## DONE and verified

- Added resolution-only vote details to the typed shared `RoundSnapshot`. Voter and
  target IDs/names, culprit ID, and monster ID are never exposed during Campfire;
  they appear only after `VotingService` has resolved the vote.
- Added `GameView:PlayVoteReveal` with vote-modal closure, result-modal opening,
  vote sound, colored correct/incorrect arrows, bounded stagger timing, majority
  verdict, success/error sounds, and 12 client-only 8×8 gold confetti frames.
- Capped the stagger with `min(0.6, 8 / max(voteCount, 1))`; even the defensive
  64-entry client cap completes the verdict stage in under 10 seconds.
- Added reduced-motion behavior: votes and verdict display immediately and confetti
  is not created.
- Added token/cancellation ownership so stale vote tasks and confetti cannot outlive
  the current result presentation or `GameView`.
- Wired the reveal exactly once when the client enters `Resolution`, with safe
  vote/identifier/participant-name access and empty fallbacks.
- Added strict `ProximityController.lua` with a `{BasePart -> BillboardGui}` zone
  map, cream 180×48 prompts at a 3.5-stud offset, gold key hint, ink label, and a
  12-segment rounded radial progress ring.
- Added register, unregister, progress, visibility, and full destroy lifecycle.
- Extended `InteractionController` to register shown part prompts, unregister hidden
  prompts, update hold progress every rendered frame, preserve the existing HUD for
  prompts without a `BasePart` parent, and destroy all world prompts on shutdown.
- Hid Roblox's default prompt UI with
  `prompt.Style = Enum.ProximityPromptStyle.Custom`. I intentionally did **not** set
  `ProximityPromptService.Enabled = false`: Roblox's official API says that false
  disables the prompts themselves, including their interaction behavior. Custom
  style is Roblox's documented mechanism for replacing only the UI.
- Verified all 73 Luau source files with the pinned Luau compiler.
- Verified `test_phase_cinematics.py` (13/13), client release contracts (11/11),
  and server release contracts (9/9).
- Verified the full repository gate and Rojo 7.7 build; artifact size was 746,760
  bytes.

## EvidenceCard scale-size observation

Static source inspection confirms that the ceremony's
`Size = UDim2.fromScale(1, 1)` remains internally bounded by its fixed-size host:
the shadow and paper use `1, -2`, and the status strip uses the paper's full height.
The masking tape intentionally sits 5px above the paper (`Y = -5`) as a decorative
overlap; adding `ClipsDescendants` would incorrectly cut it off. No accidental
scale-mode overflow was found, so I did not add `AutomaticSize` or clipping.
Roblox Studio visual confirmation remains deferred.

## LEFT or deferred

- Roblox Studio multiplayer/device visual testing is deferred because this
  environment has no Studio runtime. In particular, the segmented ring's perceived
  radial fill, Billboard scaling at distance, vote-list scrolling, and confetti
  spread need live visual confirmation.
- The literal `ProximityPromptService.Enabled = false` instruction is deferred as
  unsafe/incompatible with functioning proximity input. The supported custom-style
  replacement is implemented instead.
- Spectator/ghost experience, monster proximity heartbeat, lobby minigame, and
  reconnect resilience remain out of scope and untouched.

## Repository gate

Command:

```text
python scripts/run_all_checks.py --require-rojo
```

Result:

```text
PASS
CAMP-Mystery validation passed: 73 strict Luau files, 9 remotes, 8 roles,
8 monsters, launch monetization disabled, and 3 Rojo mappings.
Luau compilation passed: 73 source files
Domain contract tests: 11/11 passed
Server release contract tests: 9/9 passed
Operational workflow contract tests: 5/5 passed
Client release contract tests: 11/11 passed
Motion and UI sound contract tests: 4/4 passed
Phase cinematics contract tests: 13/13 passed
Release readiness simulations: 21/21 passed
Content manifest validation: passed
Resilience reference simulations: 6/6 passed
Rojo artifact verified (746,760 bytes).
ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

## Answers to Claude's questions

1. `state.round.votes` did **not** exist. `RuntimeTypes.GameState` references
   `GameTypes.RoundSnapshot`, which previously contained only `votesCast` and
   `eligibleVoters`. `VotingService` held the voter→target map server-side. I added
   typed `VoteRevealEntry` data, but `VotingService:GetSnapshot` returns it only
   after `self.resolution` exists, and `GameRuntimeService:GetRoundSnapshot` exposes
   it only in `Resolution`/`Rewards`.
2. `ProximityPrompt.PromptButtonHoldProgress` does **not** exist in Roblox's current
   API. The supported events are `PromptButtonHoldBegan` and
   `PromptButtonHoldEnded`; the official custom-prompt sample animates progress over
   `HoldDuration`. I implemented the equivalent using `os.clock()` plus
   `RunService.RenderStepped`. Official references:
   https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt and
   https://create.roblox.com/docs/reference/engine/classes/ProximityPromptService.

## Questions for Claude

1. Please confirm that the API-correct `ProximityPromptStyle.Custom` substitution
   satisfies B3; service-wide disabling would make the requested interactions
   unusable.
2. After Steve's next Studio run, should Request 0006 prioritize any observed
   Billboard/ring tuning before starting spectator/ghost work?
