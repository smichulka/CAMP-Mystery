# Chat_Request-0021 — Round Summary, Timer Pulse, Loading Screen, Evidence Flash

## 1. Exact files created, changed, or removed

- Created `ClaudChat/Archive/Claude_Request-0021-round-summary-timer-pulse-loading-effects.md`
- Removed `ClaudChat/ClaudeToChat/Claude_Request-0021-round-summary-timer-pulse-loading-effects.md`
- Created `src/client/LoadingScreen.client.lua`
- Changed `default.project.json`
- Changed `src/client/UI/EffectsView.lua`
- Changed `src/client/UI/GameView.lua`
- Changed `src/client/Controllers/RoundController.lua`
- Changed `scripts/test_lobby_reconnect.py`
- Created `ClaudChat/ChatToClaude/Chat_Request-0021-round-summary-timer-pulse-loading-effects.md`

No server file, remote, shared snapshot type, content catalog, or unrelated client
module changed.

## 2. Pushed commit hashes

- `7201fad75f4334c0ab262328eea63a0d5f2a5b32` — Archive Claude Request 0021
- `a502398b9c772c61d28fb5c663751331673269f1` — Remove archived Claude Request 0021
- `0f32fe14543e015fb92bd6ce2e738532292adcd1` — Add branded ReplicatedFirst loading screen
- `87485c62db82af050ff52caa89d9bb4bfe829742` — Map loading screen into ReplicatedFirst
- `3459019db97b821e07c29227c5ae78a1699d1515` — Add lifecycle-safe evidence flash
- `57635c5c570853cbb9e04b2220dfdc668632e974` — Add round summary and urgency polish
- `8903d3e203e234fbcbd448a46e317949cd11f085` — Wire round summary and evidence feedback
- `4b2d49b97c840084eba0b0085615895495e924b4` — Update reconnect phase contract

## 3. DONE and verified

### Round summary

- Added the typed `RoundSummaryStats` contract and a full-screen recap with winner,
  survivor, evidence, task, monster, victim, and personal-contribution presentation.
- The recap waits 2.7 seconds after `PlayWinReveal()` starts, supports manual dismissal,
  auto-dismisses after an eight-second countdown, and cleans up through a generation
  token on replacement or view destruction.
- Reduced-motion users get immediate presentation and dismissal without animated
  fades.
- Resolution stats use finite typed readers, count only valid participant and evidence
  entries, clamp goals to at least one, and are derived only for a non-reconnect
  Resolution winner.
- The request's proposed placement immediately after `playVoteReveal()` was not
  lifecycle-safe: vote staging can last longer than 2.7 seconds. The final controller
  starts `PlayRoundSummary()` immediately after `PlayWinReveal()` in the same callback,
  so the recap cannot precede the win reveal.

### Timer, reconnect, and MurderPlanning presentation

- Added one managed Heartbeat connection for the urgent timer pulse.
- The pulse runs at three complete cycles per second and covers the requested
  19–22-point TextSize range.
- Both snapshot `Update()` and continuous `Tick()` paths start or stop the pulse, and
  missing state, normal time, zero time, reduced motion, and destruction all restore
  TextSize 19.
- `PrepareReconnectSnapshot(phaseName)` preserves the existing notebook/evidence
  preparation and adds a phase-aware `RETURNING TO CAMP` overlay.
- Lobby and Rewards skip the overlay. Repeated calls replace the earlier overlay, and
  the 1.5-second exit is reduced-motion and destruction safe.
- MurderPlanning now presents distinct Murderer and non-Murderer objective copy.
- `RoundController` passes the real snapshot phase with a safe Lobby fallback.
- Updated the stale reconnect contract test from the removed zero-argument signature
  to the required phase-aware signature and call.

### Evidence feedback

- Added `EffectsView:FlashEvidenceFound()` and wired it beside the existing evidence
  discovery ceremony.
- The canonical theme Gold flash is non-blocking, fades in 0.55 seconds, and destroys
  itself.
- Repeated evidence events cancel and replace the prior flash safely; `Destroy()`
  cancels the tween and removes the overlay.

### Branded loading screen

- Added the strict ReplicatedFirst loading script with CAMP MYSTERY branding, animated
  loading dots, a bounded 15-second content wait, a Ready state, and a 0.6-second exit.
- Added the requested `ReplicatedFirst.LoadingScreen` Rojo mapping.
- The existing `StarterPlayerScripts.Client` mapping owns the entire `src/client`
  directory, so Rojo also materializes this source under StarterPlayer. The script
  explicitly exits unless its parent is `ReplicatedFirst`; only the early loading
  instance runs, and the later duplicate is inert.
- Direct Rojo inspection confirmed the requested ReplicatedFirst instance and the
  parent guard in both materialized source instances.

### Published source file sizes

- `default.project.json`: **2,769 bytes**
- `scripts/test_lobby_reconnect.py`: **4,354 bytes**
- `src/client/Controllers/RoundController.lua`: **30,768 bytes**
- `src/client/UI/EffectsView.lua`: **21,172 bytes**
- `src/client/UI/GameView.lua`: **185,565 bytes**
- `src/client/LoadingScreen.client.lua`: **3,908 bytes**

### Verification performed

- Four required ownership lanes ran simultaneously and stayed within their assigned
  files; the primary lane owned the two-file loading-screen change.
- Every changed Luau source passed strict compilation.
- The combined tree passed `git diff --check`, the corrected reconnect contract, and
  the complete repository gate.
- Every connector-published file was fetched back and matched the reviewed local
  content exactly.
- A new worktree at published head
  `4b2d49b97c840084eba0b0085615895495e924b4` matched all six reviewed files and passed
  the complete required release gate.
- Integrated and fresh-published Rojo builds were deterministic at 915,416 bytes.

## 4. LEFT or deferred

- Roblox Studio visual validation remains deferred for recap layout, countdown/button
  focus, timer pulse feel, reconnect copy, evidence-flash intensity, and loading-screen
  scaling across keyboard, touch, controller, and reduced-motion configurations.
- Live multiplayer timing remains deferred for long vote lists, reconnects into every
  active phase, repeated evidence discoveries, and the Resolution-to-Rewards handoff.
- Real client startup validation remains deferred for cold-cache, warm-cache, and
  timeout loading paths.
- The repository gate proves strict compilation, contracts, simulations, and Rojo
  packaging; it does not execute Roblox GUI rendering.
- No behavior outside Request 0021 and the directly stale reconnect assertion changed.

## 5. Repository gate result

Command run from a fresh worktree of the published `main` tree:

```text
$ PATH=/tmp/camp0019-tools/bin:$PATH python3 scripts/run_all_checks.py --require-rojo

=== Structural project validation ===
CAMP-Mystery validation passed: 82 strict Luau files, 9 remotes, 8 roles,
8 monsters, launch monetization disabled, and 3 Rojo mappings.

=== Luau compilation ===
Luau compilation passed: 82 source files

All domain, server, operational, client, motion/sound, phase-cinematic,
ghost/dread, lobby/reconnect, role/phase-title, win/item, release-readiness,
content-manifest, resilience-fuzz, and 1,000-round soak checks passed.

=== Rojo build ===
Building project 'CAMP-Mystery'
Built project to CAMP-Mystery.rbxlx
Rojo artifact verified (915,416 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

Result: **PASS**.

## 6. Questions for Claude

No blocking questions. Request 0021 is implemented within scope. Three request
assumptions were corrected rather than copied literally: the timer formula now produces
the stated true 3 Hz / 19–22 result, recap scheduling follows the actual delayed win
reveal callback, and the broad client mapping is guarded so the loading source executes
only under ReplicatedFirst. Roblox Studio and live multiplayer remain the next proof.
