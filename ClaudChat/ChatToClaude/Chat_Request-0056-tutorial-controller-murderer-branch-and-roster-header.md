# Chat_Request-0056 — TutorialController Murderer Branch + Roster Header

## Status

Accepted and implemented in full.

## Pipeline ledger

- `dfceef975b7c44627ecd8f0fe22f93e73b7f5fb2` — archived the Claude request.
- `b13ceed7746779ac291f78dabf17f5db9b7f7053` — removed the processed inbox request.
- `749560453d84d2e6e9464f9b55a9bf3e1853f0c7` — implemented and tested Request 0056.

## Implementation

### `src/client/Controllers/TutorialController.lua`

- Added Murderer-specific tutorial steps for MurderPlanning, NightTransform, Investigation, and Campfire.
- Added role-aware context routing while preserving the existing Spectator redirect.
- Used role-exclusive context names because the live controller resolves steps by `context`, not by step ID.
- Updated tutorial completion accounting so Murderers skip the four camper-only equivalents and non-Murderers skip the four Murderer-only steps. This prevents the parallel entries from blocking tutorial completion.
- Preserved standard copy for Lobby, RoleReveal, Day, Resolution, and Rewards.

### `src/client/UI/PlayerStatusView.lua`

- Stored the existing roster title label on the view.
- Updated the header through the existing letterspacing helper:
  - Murderer: `SUSPECTS`
  - Ghost: `SPIRIT VIEW`
  - Spectator and living camper: `CAMP ROSTER`
- Reused the existing update signature, which already includes local role and ghost state.
- Preserved roster layout, rows, scrolling, phase visibility, and toggle behavior.

### Regression coverage

- Added focused Request 0056 assertions to `scripts/test_role_reveal_phase_titles.py`.
- Coverage checks all requested Murderer tutorial copy and routing, role-exclusive completion handling, title-label retention, and all roster header branches.

## Validation

Command:

```text
PATH=/tmp/camp0056-tools/bin:$PATH python scripts/run_all_checks.py --require-rojo
```

Result: PASS

- Structural validation: 83 strict Luau files.
- Luau compilation: all 83 source files passed.
- All contract and simulation suites passed.
- Role reveal and phase title suite: 10 tests passed, including Request 0056.
- Rojo 7.7.0 build passed.
- Artifact: `CAMP-Mystery.rbxlx`, 973,039 bytes.

## Remaining work

None for Request 0056.
