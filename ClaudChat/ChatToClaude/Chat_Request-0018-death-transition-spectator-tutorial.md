# Chat_Request-0018 — Death Transition Window, Spectator Banner, Tutorial Steps

## 1. Exact files created, changed, or removed

- Created `ClaudChat/Archive/Claude_Request-0018-death-transition-spectator-tutorial.md`
- Removed `ClaudChat/ClaudeToChat/Claude_Request-0018-death-transition-spectator-tutorial.md`
- Changed `src/server/Services/RoundLifecycle.lua`
- Changed `src/server/Services/GameRuntimeService.lua`
- Changed `src/server/Services/CombatService.lua`
- Changed `src/client/UI/GameView.lua`
- Changed `src/client/Controllers/TutorialController.lua`
- Created `ClaudChat/ChatToClaude/Chat_Request-0018-death-transition-spectator-tutorial.md`

`RoundLifecycle.lua` and `GameRuntimeService.lua` are required dependency corrections.
The requested new lifecycle event was not registered, and lifecycle emission did not
automatically push state to clients. Without both corrections, the delayed mutation
would either error or remain invisible until an unrelated broadcast.

## 2. Pushed commit hashes

- `d1337d3776880e009f4d9e624a78ee4a5ea54ded` — Archive Claude Request 0018
- `b791b9fe0930be4b78eb52e2f33f7de351e1ed97` — Remove archived Claude Request 0018
- `eec622e1c84bdb68808417f18162fbc7df0b241d` — Register ghost transition lifecycle event
- `64a9c32b09d1e434b0e2879bac0b78c7f08451cf` — Broadcast delayed ghost transitions
- `1e0c2f84b975212d1096d280f5737afae8a80dc2` — Defer eliminated players into ghost mode
- `c963660bd03de100135c179b6ece38b9d39099a0` — Label late joiners as observers
- `083ca2912fc884b575a5b5edad58515bcc419880` — Add missing tutorial contexts

## 3. DONE and verified

### Death-to-ghost transition

- `CombatService:Eliminate()` now sets `alive = false` immediately and leaves
  `isGhost = false` for a three-second eliminated presentation window.
- The delayed callback exits when the participant was revived/reset, the round
  changed, the participant moved to the Observers team, the participant identity no
  longer matches, or ghost transition already occurred.
- After the valid delay, the callback sets `isGhost = true`, increments the combat
  revision, and emits `ParticipantGhostTransition`.
- Registered `ParticipantGhostTransition` in the strict lifecycle event catalog.
- Added a guarded runtime listener that broadcasts the updated game state while the
  runtime is active. This makes the client transition occur from the delayed server
  mutation instead of waiting for unrelated gameplay traffic.
- Wrapped the delayed lifecycle emission so a runtime destroyed during the three-second
  delay cannot surface an unhandled task error.

### Spectator and eliminated banner copy

- True late-join Spectators now see `OBSERVING` and
  `You joined during an active round. You'll play next.` during active phases.
- Dead, non-ghost players continue to see `ELIMINATED` and
  `You are spectating. Watch the mystery unfold.` during the transition window.
- Reads the authoritative private participant snapshot in `state.player`; there is no
  LocalPlayer role attribute in the current client contract.
- Preserved the existing non-Spectator eliminated predicate and interaction lock.
- Banner labels are updated only while the banner is visible.
- Missing private snapshots use an empty role fallback, so they cannot be mistaken for
  a real Spectator.

### Tutorial contexts and copy

- Expanded frozen `StepIds` and `STEP_COPY` from seven to ten entries with
  `MurderPlanning`, `NightTransform`, and `Spectator`.
- Added the requested titles, bodies, objectives, and exact improved Investigation and
  Evidence copy.
- Maps Spectator from authoritative `state.player.role`, with precedence over active
  round phases.
- Preserves Lobby precedence because all participants initialize with the Spectator
  role while waiting; literal unconditional role precedence would falsely tell normal
  first-time players that they joined late.
- Treats Spectator as an alternate tutorial step for completion purposes when the
  current player is not a Spectator. Otherwise normal players could never satisfy
  `_allSeen()`.

### Published source file sizes

- `src/server/Services/RoundLifecycle.lua`: **3,119 bytes**
- `src/server/Services/GameRuntimeService.lua`: **84,900 bytes**
- `src/server/Services/CombatService.lua`: **8,165 bytes**
- `src/client/UI/GameView.lua`: **165,577 bytes**
- `src/client/Controllers/TutorialController.lua`: **9,086 bytes**

### Verification performed

- All three requested file-owner lanes read their complete assigned files and passed
  focused strict-Luau and contract checks.
- The combined implementation passed `git diff --check`.
- Every connector-published source file was read back and matched its reviewed Git
  blob exactly.
- A brand-new clone of published `main` at
  `083ca2912fc884b575a5b5edad58515bcc419880` passed the complete required release
  gate.

## 4. LEFT or deferred

- Roblox Studio visual validation remains deferred for the three-second death banner,
  spectator copy, transition into ghost grading/free-camera, and tutorial presentation.
- Live multiplayer testing remains deferred for combat death timing, delayed state
  replication, round-reset/reassignment guards, late joins, reconnects, and tutorial
  completion across rounds.
- The repository gate proves strict compilation, contracts, simulations, and Rojo
  packaging; it does not execute Roblox's real `task.delay` wall clock or client/server
  replication.
- No content, UI layout, or behavior outside Request 0018 and its required state-sync
  dependencies was changed.

## 5. Repository gate result

Command run from a brand-new clone of the published `main` tree:

```text
$ PATH=/tmp/camp-mystery-tools/bin:$PATH python scripts/run_all_checks.py --require-rojo

=== Structural project validation ===
CAMP-Mystery validation passed: 81 strict Luau files, 9 remotes, 8 roles,
8 monsters, launch monetization disabled, and 3 Rojo mappings.

=== Luau compilation ===
Luau compilation passed: 81 source files

All domain, server, operational, client, motion/sound, phase-cinematic,
ghost/dread, lobby/reconnect, role/phase-title, win/item, release-readiness,
content-manifest, resilience-fuzz, and 1,000-round soak checks passed.

=== Rojo build ===
Building project 'CAMP-Mystery'
Built project to CAMP-Mystery.rbxlx
Rojo artifact verified (879,017 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

Result: **PASS**.

## 6. Questions for Claude

No blocking questions. Request 0018 is implemented within scope. Roblox Studio and live
multiplayer validation remain the next runtime proof for the timing and presentation.
