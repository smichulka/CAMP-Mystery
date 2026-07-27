# Chat_Request-0038 — MurderPlanning "Night Is Falling" Toast

## 1. Status

Request 0038 is complete and published to shared `main`.

The Murderer now receives a single Warning toast when MurderPlanning begins. The toast names the selected victim when the private murder plan resolves to a participant, and falls back safely to "your target" otherwise.

## 2. Implementation

Changed only the requested game-source file:

- `src/client/Controllers/RoundController.lua`
- Inserted the toast inside the existing phase-entry/current-view block.
- Required `phaseName == "MurderPlanning"`, `not reconnect`, and `roleName == "Murderer"`.
- Reused the existing `participants` snapshot and private `snapshot.murderPlan.victimParticipantId`.
- Preserved the Campfire vote toast and keybind-hint behavior unchanged.
- Added no module state, reconnect initialization, or `Stop()` changes.

Published source checkpoint:

- `e0874281492e70d8fb21d6cd18dd88c7dfdec96c` — Add MurderPlanning target toast
- Controller blob: `ffdabdbd1f978fdbda4f8b748679eea7daa1a398`
- Controller size: 42,060 bytes

## 3. Acceptance Coverage

Verified:

- Named target: `You must eliminate [Name]. Use the shadows.`
- Missing plan/participant fallback: `You must eliminate your target. Use the shadows.`
- Murderer-only delivery
- Reconnect suppression
- Once-per-phase-entry behavior through the existing `phaseName ~= lastCinematicPhase` guard
- Campfire notification and keybind-hint ordering remain intact

Claude's proposed insertion point and variable-scope assumptions matched the published controller; no pseudocode correction was required.

## 4. Verification

Immutable baseline at `d8faf204ed23cca475920ccc37bbac2fc33bb503`:

- 83 strict Luau files compiled
- All contract tests and soak simulations passed
- Rojo artifact: 948,937 bytes

Integrated implementation gate:

- Focused Request 0038 source acceptance checks passed
- 83 strict Luau files compiled
- All contract tests and soak simulations passed
- Rojo artifact: 949,731 bytes

Fresh-published verification at `e0874281492e70d8fb21d6cd18dd88c7dfdec96c`:

- Ran from the dedicated `camp-mystery-0038-published` worktree
- Published controller hash matched `ffdabdbd1f978fdbda4f8b748679eea7daa1a398`
- 83 strict Luau files compiled
- All contract tests and soak simulations passed
- Rojo artifact: 949,731 bytes
- `scripts/run_all_checks.py --require-rojo` explicitly reported all checks passed
- A separate post-gate `wc` command returned nonzero because the gate cleans up its generated artifact; this was not a gate failure

## 5. Commit Ledger

- `23542e8b2e9a18ef5110eda7eaa3fb98a3a4cca1` — Archive Claude request 0038
- `d8faf204ed23cca475920ccc37bbac2fc33bb503` — Clear processed Claude request 0038
- `e0874281492e70d8fb21d6cd18dd88c7dfdec96c` — Add MurderPlanning target toast

All mailbox and source writes were verified against the expected blobs.

## 6. Deferred Validation

Roblox Studio visual validation and live multiplayer validation remain deferred. Those should confirm the final toast timing, target-name rendering, and Murderer-only visibility during an actual Day-to-MurderPlanning transition.
