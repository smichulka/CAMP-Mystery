# Chat Request 0040 — NightTransform Entry Toast Handoff

## 1. Outcome

Request 0040 is implemented on shared `main`.

`src/client/Controllers/RoundController.lua` now sends a role-differentiated notification on first entry to `NightTransform`:

- Living Murderer: **Your moment is now** / **Strike true. The camp is yours.** / `DangerBright`
- Living non-Spectator survivor: **Night falls** / **Stay alert. Someone won't make it to morning.** / `Warning`
- Ghost or Spectator: no NightTransform entry notification

## 2. Implementation

The requested block was inserted inside the existing `if currentView then` phase-change branch, directly after the Investigation notification and before the unchanged keybind-hint block.

The implementation uses the existing locals and guards exactly as requested:

- `phaseName == "NightTransform"`
- `not reconnect`
- strict ghost check: `player.isGhost == true`
- `roleName == "Murderer"` for the Murderer branch
- `roleName ~= "Spectator"` for the survivor branch

No module-level tracker, reconnect initialization, `Stop()` change, or additional source file was needed.

## 3. Review and Corrections

Claude's insertion point, variable-scope assumptions, and pseudocode were correct. No implementation correction was required.

The source diff is exactly 18 inserted lines in:

- `src/client/Controllers/RoundController.lua`

Adjacent Campfire, MurderPlanning, Investigation, and keybind-hint behavior remains unchanged.

During fresh-published verification, the first gate invocation ran from the workspace root rather than the new published checkout and therefore could not find `scripts/run_all_checks.py`. That invocation is not counted as verification. The gate was rerun from the correct `camp-mystery-0040-published` checkout and passed completely.

## 4. Acceptance Coverage

Focused source acceptance checks confirm:

- Living Murderers receive the requested `DangerBright` GO signal.
- Living non-Murderer, non-Spectator players receive the requested `Warning`.
- Ghosts are suppressed by strict equality.
- Spectators are suppressed.
- Reconnect snapshots are suppressed.
- Subsequent snapshots are suppressed by the existing outer `phaseName ~= lastCinematicPhase` transition guard.
- The notification remains inside the existing non-nil `currentView` scope without a redundant nil check.
- No NightTransform keybind hint was added.

## 5. Verification

Both the integrated implementation workspace and a brand-new checkout of the published source passed:

- Structural validation: 83 strict Luau files
- Luau compilation: 83 source files
- All domain, server, operational, client, motion/sound, cinematics, ghost/dread, reconnect, role-reveal, win-reveal, content-manifest, fuzz, and soak checks
- Deterministic Rojo build: 950,791 bytes

Published source evidence:

- Commit: `ad54657bff84d938209ff5bdf4674cc0ef7f1941`
- File: `src/client/Controllers/RoundController.lua`
- Blob: `1e06f2a08e348fcaa6db3aa4cbd24097d327e2e8`
- Size: 43,120 bytes

Roblox Studio and live multiplayer validation remain deferred because those environments are unavailable here.

## 6. Commit Ledger

- `3a403b1b7315da9b858fbf1a412e108f41decbcd` — archive Claude Request 0040
- `d333c0e3f1bd96db328cf8a7b6563dc46049b393` — remove processed unread Request 0040
- `ad54657bff84d938209ff5bdf4674cc0ef7f1941` — add NightTransform entry notifications

The archived request is byte-identical to the original unread request, and the unread mailbox copy is removed.
