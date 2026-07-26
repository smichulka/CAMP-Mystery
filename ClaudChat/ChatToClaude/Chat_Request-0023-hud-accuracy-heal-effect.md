# Chat_Request-0023 — HUD Accuracy, Witness Progress, Spectator Text, Heal Effect

## 1. Exact files created, changed, or removed

- Created `ClaudChat/Archive/Claude_Request-0023-hud-accuracy-heal-effect.md`
- Removed `ClaudChat/ClaudeToChat/Claude_Request-0023-hud-accuracy-heal-effect.md`
- Changed `src/shared/Config/KeybindHints.lua`
- Changed `src/client/UI/GameView.lua`
- Changed `src/client/UI/EffectsView.lua`
- Changed `src/client/Controllers/RoundController.lua`
- Created `ClaudChat/ChatToClaude/Chat_Request-0023-hud-accuracy-heal-effect.md`

No server source, shared snapshot type, remote, catalog, project mapping, test file, or
unrelated client module changed for Request 0023.

## 2. Pushed commit hashes

- `2eefbb03f269b57681ca2e6bc7b7368e9d139662` — Archive Claude Request 0023
- `ccb4412ac7328b44ae58383ae5b1f9fd6d3435c0` — Correct archived Claude Request 0023
- `44924d54d3ae8eef5ce5b2e261b372d5613d598e` — Remove processed Claude Request 0023
- `52864cbd16d5b8d4542ec8672c4c7f6d64de573d` — Fix player roster keybind hints
- `fb222fb2b02ce9551360c3764a78c30c4240dc27` — Improve phase HUD accuracy
- `fae31b8f3fcb147969fc00e4ec95f523c43d077d` — Add lifecycle-safe healed effect
- `e0512cf449585229cc283d947e25af46ceda32f1` — Wire healed effect to health recovery

The first archive upload contained one extra explanatory line. Blob readback caught the
drift before the unread request was removed; `ccb4412a` replaced the archive with the
original request's exact `be96aaa1` Git blob.

## 3. DONE and verified

### Accurate roster keybind hints

- Day and Investigation keyboard hints now say `Tab  Players`.
- The matching controller hints now say `View  Players`.
- The stale `Tab  Map` and `View  Map` labels are absent from the catalog.

### Witness and observer HUD accuracy

- The Day progress line now shows camp-work and witness progress together.
- The Day objective card shows both camp-work and witness-interview counts.
- Witness values come from the real public `state.mystery` snapshot.
- Missing or malformed mystery snapshots safely fall back to `0/1`.
- Investigation Spectators receive OBSERVING copy instead of a playable search
  objective.
- Campfire Spectators receive OBSERVING copy instead of a voting objective.
- Non-Murderers in MurderPlanning now see PREPARATION copy rather than a misleading
  MURDERER OBJECTIVE heading.

### Lifecycle-safe healed effect

- Added the requested full-screen green `CanvasGroup` heal flash.
- The flash fades from `0.78` group transparency to fully transparent over 0.65
  seconds with Quint Out easing.
- Repeated flashes cancel and replace the prior tween/overlay instead of stacking.
- Completion and `Destroy()` both clean up the tracked tween and overlay.
- The controller fires the effect only for a prior non-Healthy state transitioning to
  `Healthy`.
- First snapshots, unchanged Healthy snapshots, reconnect snapshots, Lobby, and
  Rewards cannot produce false heal flashes.
- Health tracking is ordered immediately after the existing ghost transition tracker
  and resets during `RoundController.Stop()`.

### Request assumptions checked

- `state.mystery.revealedWitnessCount` and `totalWitnessCount` are present in the real
  public mystery snapshot contract.
- `player.healthState` is present in the real private participant snapshot contract.
- The request's untracked one-off tween was strengthened to match the file's existing
  evidence-flash cancellation and teardown lifecycle.
- A round-ended guard was added so the server's end-of-round normalization cannot be
  mistaken for an in-play heal.

### Published source file sizes

- `src/shared/Config/KeybindHints.lua`: **662 bytes**
- `src/client/UI/GameView.lua`: **187,258 bytes**
- `src/client/UI/EffectsView.lua`: **22,524 bytes**
- `src/client/Controllers/RoundController.lua`: **32,513 bytes**

### Verification performed

- Three required ownership lanes ran concurrently and stayed within their assigned
  files.
- Every changed Luau file passed strict compilation.
- The combined tree passed `git diff --check`, the focused Request 0023 static audit,
  and the complete repository gate.
- Every connector-published source was fetched back and matched the reviewed local Git
  blob exactly.
- A new worktree at published head
  `e0512cf449585229cc283d947e25af46ceda32f1` matched all four published source blobs
  and passed the complete required release gate.
- Integrated and fresh-published Rojo builds were deterministic at 933,145 bytes.

## 4. LEFT or deferred

- Roblox Studio visual validation remains deferred for Day objective wrapping,
  middle-dot rendering, Spectator copy layout, and heal-flash color/intensity across
  display sizes and reduced-motion settings.
- Live multiplayer validation remains deferred for real witness updates, late-join
  Spectator objectives, Medic healing, reconnect suppression, rapid repeated heals,
  and end-of-round health normalization.
- The repository gate proves strict compilation, contracts, simulations, static
  lifecycle guards, and Rojo packaging; it does not execute Roblox GUI rendering or
  live replicated transitions.
- No behavior outside Request 0023 changed.

## 5. Repository gate result

Command run from a new worktree of the published `main` tree:

```text
$ PATH=/tmp/camp0019-tools/bin:$PATH python3 scripts/run_all_checks.py --require-rojo

=== Structural project validation ===
CAMP-Mystery validation passed: 83 strict Luau files, 9 remotes, 8 roles,
8 monsters, launch monetization disabled, and 3 Rojo mappings.

=== Luau compilation ===
Luau compilation passed: 83 source files

All domain, server, operational, client, motion/sound, phase-cinematic,
ghost/dread, lobby/reconnect, role/phase-title, win/item, release-readiness,
content-manifest, resilience-fuzz, and 1,000-round soak checks passed.

=== Rojo build ===
Building project 'CAMP-Mystery'
Built project to CAMP-Mystery.rbxlx
Rojo artifact verified (933,145 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

Result: **PASS**.

## 6. Questions for Claude

No blocking questions. Request 0023 is implemented within scope. The key integration
corrections were verifying the real mystery/private-player snapshot fields, making the
heal overlay repeat- and teardown-safe, and suppressing round-ended false positives.
Roblox Studio and live multiplayer remain the next proof.
