# Chat_Request-0039 — Investigation Phase Entry Toast

## 1. Status

Request 0039 is complete and published to shared `main`.

## 2. Implementation

Updated only `src/client/Controllers/RoundController.lua`, as assigned.

- On first non-reconnect entry to `Investigation`, a living Murderer receives:
  - Title: `Body discovered`
  - Message: `Stay calm. Blend in with the others.`
  - Style: `Warning`
- A living non-Spectator survivor receives:
  - Title: `Body discovered`
  - Message: `Someone was killed. Find the evidence before campfire.`
  - Style: `DangerBright`
- Ghosts and Spectators receive no Investigation entry toast.
- The existing outer phase-change guard prevents repeat notifications on subsequent snapshots.
- Campfire, MurderPlanning, and keybind-hint behavior remains unchanged.

## 3. Commit Ledger

- `9192b3008f85d8ec3110c0d1d395f3cddec12bf8` — archive Claude Request 0039
- `a042fe94f3487c4efe91e0f3cf8bbaf61bdc2d81` — remove processed unread request
- `4c43710afbaf192dbcca9fc8b8319c2628332fee` — add Investigation phase entry toast

## 4. Verification

Fresh-published verification was run from a new checkout pinned to `4c43710a`.

- Published `RoundController.lua`: 42,589 bytes
- Published Git blob: `b0a9ef9a78519c62753a184a42b17f8caa43e904`
- Strict Luau compilation: 83/83 files passed
- Domain, server, operational, client, motion/sound, cinematic, ghost/dread, reconnect, role-reveal, win-reveal, readiness, resilience, and soak checks: passed
- Deterministic Rojo artifact: 950,268 bytes
- `scripts/run_all_checks.py --require-rojo`: passed

## 5. Acceptance Coverage

All requested branches are covered by source audit and the full release gate:

- Murderer toast, copy, and Warning style
- Survivor toast, copy, and DangerBright style
- Ghost suppression
- Spectator suppression
- Reconnect suppression
- Once-per-phase-entry behavior
- No changes to adjacent Campfire, MurderPlanning, or keybind-hint logic

No pseudocode correction was required.

## 6. Deferred Validation

Roblox Studio visual validation and live multiplayer phase-transition testing remain deferred. Hosted direct-push CI must be treated as a separate signal from the fully green fresh-published release gate.
