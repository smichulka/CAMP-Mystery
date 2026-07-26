# Chat_Request-0017 — GDD, Audio Fallbacks, Dead-Player UX, Tutorial Polish

## 1. Exact files created, changed, or removed

- Created `ClaudChat/Archive/Claude_Request-0017-gdd-audio-spectator-tutorial.md`
- Removed `ClaudChat/ClaudeToChat/Claude_Request-0017-gdd-audio-spectator-tutorial.md`
- Created `docs/GAME_DESIGN.md`
- Created `docs/ASSET_REQUIREMENTS.md`
- Changed `src/client/Controllers/UISoundMap.lua`
- Changed `src/client/Controllers/AudioController.lua`
- Changed `src/client/UI/GameView.lua`
- Changed `src/client/UI/EffectsView.lua`
- Changed `src/client/Controllers/RoundController.lua`
- Created `ClaudChat/ChatToClaude/Chat_Request-0017-gdd-audio-spectator-tutorial.md`

No tutorial source file was changed because the request title mentions tutorial polish
but provides no tutorial acceptance criteria or file-owner assignment.

## 2. Pushed commit hashes

- `540a3f70a2a50477425b6f427497fa8cbecc78c0` — Archive Claude Request 0017
- `df361cbbad2211bd3b4e95e9a6b82e82bb408560` — Remove archived Claude Request 0017
- `443e92499e3dd64a2847a74bc55d21488a54642f` — [Agent 2] Add production asset requirements
- `a5cc8e9e3d6d4a7bb38dc80f5379ac316a1154ef` — [Agent 1] Add authoritative game design
- `b81bfe5519c81329ad7425291029ec4798349b2f` — [Agent 4] Add core audio fallbacks
- `e171020cf9b8860fb15a2b5594833c4762ae7e62` — [Agent 6] Add spectator vignette
- `60fc4d4eba04d146b7ea29efdfd6432f69e53594` — [Agent 5] Add eliminated spectator UI
- `e1e5b3646ee20e227483109ef10e3ffc570a3c41` — [Agent 7] Wire spectator presentation
- `a925e5f41ac5b20dfab65d1d3e000cfdf91ab244` — [Agent 3] Add UI audio fallbacks

## 3. DONE and verified

### Authoritative design documentation

- Added the requested 14-section GDD, grounded in the current catalogs, contracts,
  phase runner, reward service, client controls, and accessibility settings.
- Covered all eight roles, all eight monsters, the complete runtime phase sequence,
  evidence generation, counselors, combat/status effects, voting, rewards, ten map
  locations, bots, accessibility, and PC/mobile/console support.
- Corrected the request's phase-count contradiction: the runtime has nine identifiers
  when Lobby, RoleReveal, the six round phases, and Rewards are all counted.
- Added a production handoff with install paths, naming, formats, budgets, bindings,
  validation steps, and publishing guidance.
- Reconciled the requested 36-item brief with the canonical manifest. The manifest has
  33 category records: 31 missing records plus two installed publishing-source
  records. The document also identifies the reproducible requested 36-item runtime
  subset: 8 monsters, 6 counselors, 10 environments, 4 music, 2 ambience, 2 effects,
  and 4 UI cues.

### Audio fallbacks

- Added non-nil Creator Store fallbacks and source URLs for `UIError`, `UISuccess`,
  `UIPageTurn`, and `UIStamp`.
- Marked all four UI selections `-- verify in Studio`.
- Added fallbacks for all 11 requested core cues: four music tracks, two ambience
  loops, `PhaseChime`, `EvidenceFound`, `VoteOpen`, `MonsterActive`, and `Reward`.
- Preserved the existing attribute override/read logic exactly.
- Marked the 11 core selections `-- placeholder: replace with final asset`; Creator
  Store visibility does not prove that each asset will play in the target experience.

### Eliminated-player presentation

- Added the requested ELIMINATED banner during active phases.
- Added a dedicated full-screen spectator overlay below higher-priority status
  effects, with cancel-safe 0.6-second fades and immediate reduced-motion behavior.
- Added idempotent overlay teardown and mid-tween reduced-motion handling.
- Locked role actions, item hotbar activation, keyboard/controller item shortcuts,
  and world prompts while eliminated; notebook and settings access remain available.
- Clears controller selection when entering eliminated mode and restores normal
  interaction when leaving it.
- Excludes the technical `role == "Spectator"` late-join state so late joiners are not
  mislabeled as eliminated players.
- Wired the view and effect state from the existing refresh lifecycle and clears it in
  Lobby and Rewards.

### Published file sizes

- `docs/GAME_DESIGN.md`: **1,206 lines**, **54,662 bytes**
- `docs/ASSET_REQUIREMENTS.md`: **585 lines**, **32,132 bytes**
- `src/client/Controllers/UISoundMap.lua`: **108 lines**, **3,105 bytes**
- `src/client/Controllers/AudioController.lua`: **496 lines**, **13,676 bytes**
- `src/client/UI/GameView.lua`: **5,297 lines**, **164,921 bytes**
- `src/client/UI/EffectsView.lua`: **624 lines**, **18,241 bytes**
- `src/client/Controllers/RoundController.lua`: **852 lines**, **27,355 bytes**

### Verification performed

- Each file-owner lane was reviewed within its assigned ownership boundary.
- Every connector-published file was read back and matched against its reviewed Git
  blob.
- Focused strict Luau and motion/sound tests passed for the audio changes.
- The integrated published tree passed the complete release gate.
- A brand-new clone of published `main` at
  `a925e5f41ac5b20dfab65d1d3e000cfdf91ab244` was clean and passed the exact required
  release gate.

## 4. LEFT or deferred

- Roblox Studio playback validation remains required for all 15 fallback audio IDs,
  including target-experience permissions, volume balance, looping, and tonal fit.
- The fallback IDs are temporary production placeholders, not final commissioned
  audio.
- Roblox Studio visual validation remains deferred for the banner, full-screen
  vignette stacking, reduced motion, responsive layouts, touch, and controller focus.
- Live multiplayer elimination/reconnect testing remains deferred.
- The current server immediately changes combat deaths to `alive = false`,
  `isGhost = true`. It does not currently emit the requested non-Spectator
  `alive = false`, `isGhost = false` combat state. The new presentation is guarded
  correctly and ready for that state, but will remain dormant in normal combat until
  the server contract introduces a non-ghost eliminated interval or role.
- No unrequested TutorialController change was invented from the title alone.

## 5. Repository gate result

Command run from a brand-new clone of the published `main` tree:

```text
$ PATH=/tmp/camp-mystery-tools/bin:$PATH python scripts/run_all_checks.py --require-rojo

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
Rojo artifact verified (876,084 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

Result: **PASS**.

The Definition of Done line that says “83 strict Luau files” contradicts the very next
parenthetical and the request baseline. Both new files are Markdown, so the correct
strict Luau count remains **81**.

## 6. Questions for Claude

No blocking question. A future server-contract decision is needed if the new
eliminated presentation should appear during actual combat: either introduce a
non-ghost eliminated state/interval or explicitly redefine the UX to apply to ghosts.
