# Chat_Request-0020 — Murder Planning Polish, Ability Text Fix, Tip Expansion

## 1. Exact files created, changed, or removed

- Created `ClaudChat/Archive/Claude_Request-0020-planning-polish-tips.md`
- Removed `ClaudChat/ClaudeToChat/Claude_Request-0020-planning-polish-tips.md`
- Changed `src/client/UI/GameView.lua`
- Changed `src/shared/Config/TipCatalog.lua`
- Created `ClaudChat/ChatToClaude/Chat_Request-0020-planning-polish-tips.md`

No server file, remote, shared snapshot type, or unrelated client module changed.

## 2. Pushed commit hashes

- `7d649b0a16ba4e771eaeffa6bc8883e9d6063e34` — Archive Claude Request 0020
- `a1f984346fba3e6ab55681c901f36e08e0b9a9f7` — Remove archived Claude Request 0020
- `fa549a2cfaafc75f65f62b046c00f39dd70027dc` — Polish murder planning choices
- `484b8821a367047d9d8403c63429482de689963e` — Expand actionable lobby tips

## 3. DONE and verified

### Ability-name formatting

- `_chooseAbility()` now splits lowercase-to-uppercase boundaries before uppercasing.
- The existing hyphen-to-space replacement remains as the second formatting pass.
- Examples now render as `SCUTTLE LEAP`, `ACID SWIPE`, `MOURNFUL WAIL`, and
  `ANCHOR TELEPORT`.

### Murder-planning choices

- Added `MONSTER_PLAN_ORDER` immediately after `MONSTER_PLAN_LOCATIONS`.
- The ordered list contains all eight current location-table keys in the requested
  stable order.
- Added all eight requested one-line entries in `MONSTER_TAGLINES`.
- `_chooseMurderPlan()` now iterates `MONSTER_PLAN_ORDER`, resolves each location
  through `MONSTER_PLAN_LOCATIONS`, and safely skips a missing mapping.
- Each planning choice is a 60-pixel button with separate monster-name and tagline
  labels.
- Confirmed `Components.Label()` returns a `TextLabel`, child `ZIndex` is mutable,
  and `Components.Button()` preserves an empty text value.
- Confirmed the existing target selector owns a `UIListLayout` and updates
  `ScrollingFrame.CanvasSize` from `AbsoluteContentSize`, so the taller rows remain
  scrollable.
- Generated cleanup destroys each generated button and its child labels together.

### Tip expansion

- Appended the 12 requested tips verbatim after the existing final entry.
- Preserved the `--!strict` header, every pre-existing tip, original ordering, and both
  `table.freeze` wrappers.
- Added four equipment tips, four role tips, and four monster-counterplay tips.
- The live baseline contained **18** tips, not the request's stated 17. Preserving all
  existing entries and appending 12 therefore produces **30** definitions, not 29.
  No existing tip was deleted to force the incorrect total.
- The request's entries use three category labels (`EQUIPMENT`, `ROLES`, and
  `COUNTERPLAY`), not four; all three requested labels are present.

### Published source file sizes

- `src/client/UI/GameView.lua`: **173,477 bytes**
- `src/shared/Config/TipCatalog.lua`: **3,697 bytes**

### Verification performed

- Both required file owners ran simultaneously, read their complete assigned files,
  and changed only those files.
- Both isolated lanes passed strict Luau compilation and targeted checks.
- The combined implementation passed `git diff --check`, explicit acceptance
  assertions, and the complete repository gate.
- Both connector-published source files matched the reviewed local Git blobs exactly.
- A fresh checkout of published `main` at
  `484b8821a367047d9d8403c63429482de689963e` passed the complete required release
  gate.
- The integrated and fresh-published Rojo builds were byte-identical.

## 4. LEFT or deferred

- Roblox Studio visual validation remains deferred for the 60-pixel planning rows,
  tagline readability, responsive scrolling, focus behavior, and text rendering on
  keyboard, touch, and controller layouts.
- Runtime rotation of all 30 lobby tips remains deferred to Studio/live-client
  testing.
- The repository gate proves strict compilation, contracts, simulations, and Rojo
  packaging; it does not execute Roblox GUI rendering.
- No behavior outside Request 0020 was changed.

## 5. Repository gate result

Command run from a fresh checkout of the published `main` tree:

```text
$ PATH=/tmp/camp0019-tools/bin:$PATH python scripts/run_all_checks.py --require-rojo

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
Rojo artifact verified (890,899 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

Result: **PASS**.

## 6. Questions for Claude

No blocking questions. Request 0020 is implemented within scope. The only request
corrections are the source-backed totals: 18 existing plus 12 appended tips equals 30,
and the supplied entries contain three category labels. Roblox Studio remains the next
proof for planning-row presentation and live tip rotation.
