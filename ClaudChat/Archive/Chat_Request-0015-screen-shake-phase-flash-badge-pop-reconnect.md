# Chat_Request-0015 — Screen Shake, Phase Flash, Badge Pop, Connect/Disconnect Toasts

## 1. Exact files created, changed, or removed

- Created `ClaudChat/Archive/Claude_Request-0015-screen-shake-phase-flash-badge-pop-reconnect.md`
- Removed `ClaudChat/ClaudeToChat/Claude_Request-0015-screen-shake-phase-flash-badge-pop-reconnect.md`
- Changed `src/client/UI/Motion.lua`
- Changed `src/client/UI/GameView.lua`
- Changed `src/client/Controllers/CinematicsController.lua`
- Changed `src/client/Controllers/RoundController.lua`
- Created `ClaudChat/ChatToClaude/Chat_Request-0015-screen-shake-phase-flash-badge-pop-reconnect.md`

`Motion.lua` was the only integration dependency beyond the three assigned files. Its
`TransitionConfig` did not have the anticipated `scale` option, and `Motion.PopIn`
hard-coded `Theme.Motion.PopScale`. Without this narrow compatibility change, the
requested `scale = 1.28` and `scale = 1.12` values would have been accepted as unused
table fields at runtime and would not have changed the animation.

No other repository files were changed for Request 0015.

## 2. Pushed commit hashes

- `e78f9f06bd4d4391220a07e47c5b0270558f664a` — Archive Claude Request 0015
- `fa3b6f4213be1491e28af39643107f2b016d51a8` — Remove archived Claude Request 0015
- `d350f5d39a790c30d28b523fc140de678ee5dd71` — [Integration] Support custom pop scale
- `a49932ec69fb5934cd7ff8793681ef63a274d478` — [Agent 1] Add badge and cooldown feedback
- `ee3291d5193c61da354523340444a79c171b5129` — [Agent 2] Add screen shake and phase flash
- `e2b04a3b14af34fe3edb206cf1479fec0d05b50b` — [Agent 3] Wire feedback and connection toasts
- `d5f7dae232b2e78140f18fde095a5b55dd4d690c` — [Integration] Restore phase flash brightness

## 3. DONE and verified

### Evidence badge pop

- Added `lastEvidenceCountForPop`, initialized to `0`.
- An unread-evidence increase runs `Motion.PopIn` with `duration = 0.22` and
  `scale = 1.28`.
- An unchanged or decreased unread count does not pop.
- Hiding the badge resets `lastEvidenceCountForPop` to `0`, including the notebook-open
  path.
- Reduced motion suppresses the pop.

### Cooldown-ready feedback

- Added `lastCooldownActive`, initialized to `false`.
- The existing `abilityCooldownEndsAt` snapshot is scanned once per tick; there is no
  extra remote or timer.
- Cooldown lifecycle tracking is independent of the role button's enabled state and
  ghost state, so disabling the button cannot masquerade as cooldown completion.
- Existing cooldown text and progress-bar visibility rules remain unchanged.
- One real active-to-cleared transition runs `Motion.PopIn` on `roleAction` with
  `duration = 0.18` and `scale = 1.12`, plus one `HapticController.Click()`.
- Reduced motion suppresses the visual pop but retains the requested haptic.

### Custom pop scale compatibility

- Extended `Motion.TransitionConfig` with optional `scale`.
- `Motion.PopIn` and `Motion.PopOut` use the supplied scale when present.
- Existing callers without `scale` retain `Theme.Motion.PopScale`, so this is backward
  compatible.
- Non-finite values fall back to the theme preset; supplied values are bounded to the
  same practical UI scale range.

### Screen shake

- Added the `RunService` dependency and a public `PlayScreenShake(intensity)` method.
- The shake uses a 14 Hz x/y local-camera offset for 0.4 seconds, with amplitude
  `clamp(intensity * 0.07, 0, 0.2)` and linear decay to zero.
- Each frame removes the prior offset before applying the next, so offsets do not
  compound.
- Restart, completion, and `Destroy()` disconnect the RenderStepped connection.
- The implementation tracks the exact camera that received the prior offset. This
  prevents subtracting an old camera's offset from a replacement `CurrentCamera` and
  also permits cleanup after the original camera is unparented.
- Offset state is recorded only when an offset was actually applied.
- Critical/Incapacitated action results call `PlayScreenShake(1.0)` immediately after
  `PlayImpactFlash()`.

### Phase flash

- Added a public `PlayPhaseFlash()` method.
- Brightness rises to `0.14` over `0.10` seconds and returns to `0` over `0.28`
  seconds.
- The flash changes only `Brightness`; existing Saturation, TintColor, and Contrast
  paths remain separate.
- Genuine non-reconnect phase transitions call it after `PlayPhaseTransition`, except
  Lobby and Rewards.
- Baseline restoration now resets Brightness to `0`, so destroying or canceling the
  controller during the short flash cannot leave the shared color effect brightened.

### Participant connection notifications

- Added per-participant `lastConnectedState`.
- Initial snapshot population seeds state without notifications.
- Human `true -> false` transitions produce one Warning toast:
  `<name> left` / `Player disconnected.`
- Human `false -> true` transitions produce one Info toast:
  `<name> reconnected`.
- Bot participants are excluded.
- Invalid/empty participant IDs are ignored rather than sharing a synthetic state key.
- `RoundController.Stop()` replaces the tracking table with an empty table.

### Published file sizes

- `src/client/UI/Motion.lua`: **15,747 bytes**
- `src/client/UI/GameView.lua`: **158,877 bytes**
- `src/client/Controllers/CinematicsController.lua`: **13,887 bytes**
- `src/client/Controllers/RoundController.lua`: **26,132 bytes**

### Verification performed

- All three file-owner lanes ran focused strict Luau compilation.
- Agent 1 also ran the four motion-foundation contract tests.
- The integrated local tree passed the complete release gate before publication.
- Every connector-published source blob was read back and compared exactly with its
  reviewed local content.
- A brand-new clone of published `main` at
  `d5f7dae232b2e78140f18fde095a5b55dd4d690c` was clean and passed the complete
  release gate.

## 4. LEFT or deferred

- Roblox Studio visual/feel testing remains deferred for the evidence pop, cooldown
  pop, phase flash, and camera shake.
- Physical controller testing remains deferred for the cooldown-ready haptic.
- Live multiplayer testing remains deferred for actual participant disconnect and
  reconnect snapshot transitions and toast timing.
- No placeholder asset IDs, stubs, fake success paths, server changes, or future-scope
  features were added.

## 5. Repository gate result

Command run from a fresh clone of the published `main` tree:

```text
$ PATH=/tmp/camp-mystery-tools/bin:$PATH python scripts/run_all_checks.py --require-rojo

=== Structural project validation ===
CAMP-Mystery validation passed: 80 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.

=== Luau compilation ===
Luau compilation passed: 80 source files

All domain, server, operational, client, motion/sound, phase-cinematic,
ghost/dread, lobby/reconnect, role/phase-title, win/item, release-readiness,
content-manifest, resilience-fuzz, and 1,000-round soak checks passed.

=== Rojo build ===
Building project 'CAMP-Mystery'
Built project to CAMP-Mystery.rbxlx
Rojo artifact verified (857,711 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

Result: **PASS**.

## 6. Questions for Claude

None blocking. The only discovered contract mismatch was the missing `Motion.PopIn`
scale option; it is resolved by the backward-compatible `Motion.lua` integration
change described above.
