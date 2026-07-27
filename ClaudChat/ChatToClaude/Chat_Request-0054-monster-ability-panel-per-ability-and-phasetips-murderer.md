# Chat_Request-0054 — Monster Ability Cooldown Rows + Phase Tip Verification

## 1. Summary

Request 0054 is implemented. The active Murderer's HUD now shows both configured
monster abilities as independent named rows. Each row displays either `READY` in
gold or its remaining cooldown seconds in amber, so one cooling ability no longer
hides another ability that is ready.

The requested phase-tip inspection found no lobby phase-tip defect. The lobby
ticker cycles generic `TipCatalog.definitions`, not phase-keyed `PhaseTips`.
Murderer-specific MurderPlanning and NightTransform tips already exist as
`murderer.tip` overrides in `PhaseTitles.lua`, and `PlayPhaseTitleCard` already
selects those overrides. Per the request's explicit fallback instruction, the
generic lobby ticker and phase-title consumer were left unchanged.

## 2. Exact Files Changed

- `src/client/UI/GameView.lua`
  - Uses the existing ordered `MONSTER_ABILITIES[monsterId]` configuration to
    include all abilities, including ready abilities absent from
    `cooldownEndsAt`.
  - Uses the keyed `{ [abilityId]: timestamp }` cooldown snapshot to calculate
    each ability independently.
  - Converts ability IDs into readable uppercase names.
  - Renders two compact rich-text rows inside the unchanged 200×68 panel:
    gold for ready and amber for cooling.
  - Preserves panel visibility, name, stamina, position, and overall dimensions.
  - Falls back to sorted cooldown keys for an unknown monster ID.
- `scripts/test_role_reveal_phase_titles.py`
  - Adds Request 0054 regression coverage for named rows, both visual states,
    stable fallback ordering, unchanged visibility, existing Murderer phase tips,
    and the generic lobby ticker finding.

## 3. Commit Ledger

- `cee13a1` — Archive Claude Request 0054 (published by the upstream pipeline actor)
- `58ea0f6` — Remove processed Claude Request 0054 (published by the upstream pipeline actor)
- `47a58e442d55bd88b9501f908c17c923da2cea2d` — Show per-ability monster cooldowns

## 4. DONE and Verification

- DONE: `cooldownEndsAt` confirmed as a map keyed by ability ID.
- DONE: Every configured monster ability appears by name.
- DONE: Ready abilities display `READY` in gold.
- DONE: Cooling abilities display remaining whole seconds in amber.
- DONE: A ready ability remains visible while another ability cools.
- DONE: Panel visibility remains NightTransform + Investigation only.
- DONE: Panel size, position, monster name, and stamina display remain unchanged.
- DONE: Required Murderer phase-title tips already exist with the exact copy.
- DONE: Generic lobby tips remain unchanged because they do not cycle by phase.
- DONE: Focused role/phase-title suite passes all 8 tests.
- DONE: `git diff --check` passes.
- DONE: Complete required gate passes with pinned Luau 0.726 and Rojo 7.7.0.

```text
$ python3 scripts/run_all_checks.py --require-rojo
CAMP-Mystery validation passed: 83 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.
Luau compilation passed: 83 source files
All contract and simulation suites passed.
Rojo artifact verified (968,710 bytes).
ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

## 5. LEFT / Deferred

- Roblox Studio visual inspection of all eight monster ability-name pairs is
  deferred.
- Live multiplayer proof of one-ready/one-cooling state is deferred.
- No server contract, phase-tip configuration, lobby ticker, or unrelated UI
  behavior changed.

## 6. Review Request

Please confirm Request 0054 is accepted, including the finding that the lobby
ticker is intentionally generic and therefore has no phase-keyed Murderer branch
to update.
