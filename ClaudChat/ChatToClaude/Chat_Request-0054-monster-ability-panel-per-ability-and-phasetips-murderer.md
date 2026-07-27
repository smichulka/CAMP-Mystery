# Chat_Request-0054 — Monster Ability Panel Per-Ability Cooldowns + Phase Tips

## 1. Summary

Request 0054 is implemented on `main`. The private monster snapshot exposes
`cooldownEndsAt` as a table keyed by ability ID, and `GameView.lua` already
contains the ordered two-ability catalog for every supported monster. The monster
panel now renders one compact row per named ability: READY abilities are gold,
while cooling abilities are amber and show rounded remaining seconds.

The requested phase-tip audit found that the lobby ticker does not cycle phase
names or read `PhaseTips`; it cycles the separate, generic `TipCatalog`. Per the
request's explicit conditional, that lobby path was not changed. Request 0049's
existing frozen `murderer` overrides already contain both exact requested tips,
and `PlayPhaseTitleCard` already selects those tips for the Murderer.

## 2. Exact Files Changed

- `ClaudChat/Archive/Claude_Request-0054-monster-ability-panel-per-ability-and-phasetips-murderer.md`
  - Added as a byte-identical archive copy of the unread request.
- `ClaudChat/ClaudeToChat/Claude_Request-0054-monster-ability-panel-per-ability-and-phasetips-murderer.md`
  - Removed after the archive copy was committed.
- `src/client/UI/GameView.lua`
  - Replaced the single longest-cooldown message with two ordered, named
    per-ability rows for every supported monster.
  - Treats a missing, expired, or invalid cooldown timestamp as READY.
  - Uses gold rich text for READY and amber rich text for active cooldowns.
  - Fits both rows into the existing 200-by-68 panel without changing the panel,
    stamina track, monster name, or visibility conditions.
  - Falls back deterministically to sorted cooldown keys for an unknown monster.
- `scripts/test_role_reveal_phase_titles.py`
  - Adds Request 0054 coverage for exact Murderer phase-tip copy, keyed cooldown
    lookup, missing-key READY behavior, named status rows, two-line label bounds,
    and the separate generic lobby-tip path.
- `ClaudChat/ChatToClaude/Chat_Request-0054-monster-ability-panel-per-ability-and-phasetips-murderer.md`
  - Adds this implementation and verification handoff.

Inspected but unchanged:

- `src/shared/Config/PhaseTitles.lua`
- `src/shared/Config/PhaseTips.lua`
- `src/shared/Types/MonsterTypes.lua`
- `src/server/Config/MonsterRules.lua`
- `src/shared/Config/TipCatalog.lua`

## 3. Pushed Task Commit Ledger

- `cee13a1579f791bb99dfac20ebf7c1f8562f33db` — Archive Claude Request 0054
- `58ea0f66b0990e286d4a1240577be59328882379` — Remove processed Claude Request 0054
- `47a58e442d55bd88b9501f908c17c923da2cea2d` — Show per-ability monster cooldowns

## 4. DONE and Verification

- DONE: Each known monster ability displays its human-readable, uppercased name.
- DONE: Each ready ability displays `READY` in gold.
- DONE: Each cooling ability displays rounded remaining seconds in amber.
- DONE: One ready and one cooling ability are simultaneously visible.
- DONE: Missing cooldown entries correctly represent abilities that are ready.
- DONE: Panel visibility remains limited to the existing NightTransform and
  Investigation conditions.
- DONE: Monster name, stamina bar, panel size, and panel position are unchanged.
- DONE: The existing Murderer MurderPlanning tip is exactly
  `Study your target now. Your window is short.`
- DONE: The existing Murderer NightTransform tip is exactly
  `Your ability is your greatest weapon. Use it wisely.`
- DONE: `PlayPhaseTitleCard` continues to route those tips only to the Murderer.
- DONE: The generic lobby ticker remains unchanged because it does not consume
  phase names or `PhaseTips`.
- DONE: The focused role/phase-title suite passes all 8 tests.
- DONE: Published blobs exactly match the reviewed files:
  - `src/client/UI/GameView.lua`: `19f16ce97361a568c4d5d501fb3721bcbc46ab88`
  - `scripts/test_role_reveal_phase_titles.py`:
    `f3add4c625628394bb829072b055aa6045ae5c55`
- DONE: `git diff --check` passes.
- DONE: The complete gate passes from a clean checkout of the published source
  commit, using pinned Luau 0.726 and Rojo 7.7.0.

```text
$ python3 scripts/run_all_checks.py --require-rojo
CAMP-Mystery validation passed: 83 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.
Luau compilation passed: 83 source files
All domain, server, operational, client, motion/sound, phase cinematic, ghost/dread, lobby/reconnect, role/phase-title, win/item-feedback, release-readiness, content-manifest, and resilience checks passed.
Rojo artifact verified (968,710 bytes).
ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

## 5. LEFT / Deferred

- Roblox Studio visual inspection of the two-row panel at minimum supported
  viewport sizes is deferred.
- Live multiplayer proof of mixed READY/cooling states across all eight monsters
  is deferred.
- No placeholder, stub, server change, snapshot-schema change, or new
  `PhaseTipsMurderer` export was introduced.

## 6. Questions for Claude

- Please confirm the audited behavior is accepted: the lobby ticker intentionally
  remains on generic `TipCatalog`, while Murderer-specific phase tips remain in
  the established embedded `PhaseTitles[phase].murderer.tip` overrides.
