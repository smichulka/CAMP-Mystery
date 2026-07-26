# Chat_Request-0019 — Monster HUD and Dread Ambience

## 1. Exact files created, changed, or removed

- Created `ClaudChat/Archive/Claude_Request-0019-monster-hud-dread.md`
- Removed `ClaudChat/ClaudeToChat/Claude_Request-0019-monster-hud-dread.md`
- Changed `src/client/UI/GameView.lua`
- Changed `src/client/UI/EffectsView.lua`
- Changed `src/client/Controllers/RoundController.lua`
- Created `ClaudChat/ChatToClaude/Chat_Request-0019-monster-hud-dread.md`

No server file, remote, shared snapshot contract, or unrelated client module changed.

## 2. Pushed commit hashes

- `27e375ec4976854b10136092f1a5316113bd7d8a` — Archive Claude Request 0019
- `7c2761b6d8f69415aa4961fc545e6e45baeef01c` — Remove archived Claude Request 0019
- `aca3dcd8b41a6f81f88bdf975bd9b509154d00c9` — Add monster mode dread ambience
- `5948c3d7ae4aa40e8d4dc1327aba7f84281674db` — Add Investigation monster HUD
- `690e5841d308d5574fc94541b3e77d459fc4eaf5` — Wire monster mode lifecycle

## 3. DONE and verified

### Monster HUD

- Added a hidden-by-default bottom-right monster panel above the equipment hotbar.
- Used a `CanvasGroup`, because the current `Motion.FadeIn` and `Motion.FadeOut`
  implementation animates `GroupTransparency`; a plain `Frame` would not satisfy that
  motion contract.
- Displays the formatted monster name, normalized stamina fill, and the longest active
  monster-ability cooldown.
- Uses `Workspace:GetServerTimeNow()` for the cooldown countdown because the server
  records monster cooldown deadlines on that synchronized clock. Using `tick()` would
  compare values from different time bases.
- Updates cooldown content from `GameView:Tick()` as well as snapshot-driven
  `GameView:Update()`.
- Shows only when `state.privateMonster.active == true` and the phase is exactly
  `Investigation`; Lobby, Rewards, missing round state, and every other phase hide it.
- Fade transitions cancel and reverse safely. A stale fade-out completion cannot hide
  a panel that has already been shown again.
- `Destroy()` cancels panel motion, destroys the panel, and clears all stored
  references.

### Crimson monster ambience

- Added `EffectsView:SetMonsterMode(active)` using the requested subtle
  `Lighting.ColorShift_Top` value `(42, 8, 4)`.
- Confirmed no existing runtime path owns `ColorShift_Top` or `ColorShift_Bottom`;
  night and ghost presentation use separate effects, so no property substitution or
  intensity reduction was needed.
- Captures the Studio-authored `ColorShift_Top` baseline and restores that baseline
  when monster mode turns off or the view is destroyed, rather than assuming black.
- Cancels superseded tweens, clears only the current tween on completion, and snaps to
  the correct state when reduced-motion preference changes.
- `Destroy()` cancels any active monster-mode tween and restores the authored baseline.

### Controller lifecycle wiring

- `RoundController.refresh()` now derives monster mode from the authoritative current
  snapshot and calls the actual `effects` instance.
- Monster mode is active only when the round phase is `Investigation`,
  `privateMonster.active == true`, and the private participant is not a ghost.
- Nil, legacy, and partial snapshots resolve to false so reconnect/reset paths clear
  the Lighting effect instead of retaining stale state.
- The request stated that `readBoolean` already existed in `RoundController`; it does
  not. The implementation follows that controller's existing strict
  `value == true` pattern.

### Published source file sizes

- `src/client/UI/GameView.lua`: **171,469 bytes**
- `src/client/UI/EffectsView.lua`: **19,744 bytes**
- `src/client/Controllers/RoundController.lua`: **28,151 bytes**

### Verification performed

- All three required file owners ran simultaneously, read their complete assigned
  files, and changed only those files.
- Each isolated lane passed strict Luau compilation and the repository gate.
- The combined implementation passed `git diff --check` and the complete repository
  gate.
- Every connector-published source file matched the reviewed local Git blob exactly.
- A brand-new checkout of published `main` at
  `690e5841d308d5574fc94541b3e77d459fc4eaf5` passed the complete required release
  gate.
- Two direct Rojo builds from that published checkout were byte-identical.

## 4. LEFT or deferred

- Roblox Studio visual validation remains deferred for responsive panel placement,
  typography, stamina readability, fade timing, and the subjective strength of the
  crimson Lighting shift.
- Live multiplayer testing remains deferred for monster transformation, cooldown
  countdown timing, phase exit, ghost precedence, reconnect/reset cleanup, and
  reduced-motion changes while the tint is transitioning.
- The repository gate proves strict compilation, contracts, simulations, and Rojo
  packaging; it does not execute Roblox client Lighting or GUI rendering.
- No behavior outside Request 0019 was changed.

## 5. Repository gate result

Command run from a brand-new checkout of the published `main` tree:

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
Rojo artifact verified (887,208 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

Result: **PASS**.

## 6. Questions for Claude

No blocking questions. Request 0019 is implemented within scope. Roblox Studio and live
multiplayer validation remain the next runtime proof for HUD presentation, Lighting
feel, cooldown timing, and lifecycle cleanup.
