# Chat_Request-0057 — RoundController Toast Notifications Role-Aware

## Status

Accepted and implemented in full.

## Pipeline ledger

- `d1d13414192cccfb25b65a4ed304100bcc74cf05` — archived the Claude request.
- `5ad28fc11ce268a48dbc232a29bc5486ff67ab63` — removed the processed inbox request.
- `44981a65896d0354625845f7d95c3d31f1b71e18` — implemented and tested Request 0057.

## Implementation

### `src/client/Controllers/RoundController.lua`

- Made the all-votes-in notification role-aware:
  - Murderer receives sealed-fate copy with `DangerBright`.
  - Ghost receives watch-the-verdict copy with `Info`.
  - Living campers retain the existing verdict-coming copy with `Warning`.
- Made the Campfire transition notification role-aware:
  - Murderer receives survivor count plus deflect-suspicion copy with `DangerBright`.
  - Living campers retain the existing cast-your-vote copy with `Warning`.
  - Ghost and Spectator suppression remains unchanged.
- Made the post-death notification role-aware:
  - Murderer receives the unmasked copy with `DangerBright`.
  - Other eliminated players retain the existing ghost copy with `Info`.
  - Death cinematic ordering and cause selection remain unchanged.
- Made non-target elimination feedback role-aware:
  - Murderer secondary kills receive `ELIMINATED` success feedback.
  - Other players retain the existing warning feedback.
  - The primary `TARGET ELIMINATED` branch remains unchanged and takes precedence.

### Regression coverage

- Added focused Request 0057 assertions to `scripts/test_role_reveal_phase_titles.py`.
- Coverage checks all requested role copy, styles, branch ordering, suppression behavior, target precedence, and death-cinematic ordering.

## Validation

Command:

```text
PATH=/tmp/camp0057-tools/bin:$PATH python3 scripts/run_all_checks.py --require-rojo
```

Result: PASS

- Structural validation: 83 strict Luau files.
- Luau compilation: all 83 source files passed.
- All contract and simulation suites passed.
- Role reveal and phase title suite: 11 tests passed, including Request 0057.
- Rojo 7.7.0 build passed.
- Artifact: `CAMP-Mystery.rbxlx`, 974,057 bytes.

## Remaining work

None for Request 0057.
