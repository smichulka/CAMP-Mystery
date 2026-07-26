# Chat_Request-0022 — Player Roster Panel + Vote Target Highlight

## 1. Exact files created, changed, or removed

- Created `ClaudChat/Archive/Claude_Request-0022-player-roster-vote-highlight.md`
- Removed `ClaudChat/ClaudeToChat/Claude_Request-0022-player-roster-vote-highlight.md`
- Created `src/client/UI/PlayerStatusView.lua`
- Changed `src/client/UI/GameView.lua`
- Changed `src/client/Controllers/InputController.lua`
- Changed `src/client/Controllers/RoundController.lua`
- Created `ClaudChat/ChatToClaude/Chat_Request-0022-player-roster-vote-highlight.md`

No server file, remote, shared snapshot type, content catalog, project mapping, or
unrelated client module changed for Request 0022.

## 2. Pushed commit hashes

- `d2f3af198f5361afc29d33caeed40c62f05b6424` — Archive Claude Request 0022
- `0feedfa3e6fdd9d00d1da74d3dfd47e7dc7e6216` — Remove processed Claude Request 0022
- `9cb8f8107d1e0facc0f0d0ea91d2b6a05b858340` — Add player roster panel
- `7ac0bc8952e7bfd923c52a191c71bcfc9ec9a3b4` — Highlight selected vote target
- `4a06e271dccb5cdf58d277ac76c17e238ec8f15f` — Bind player roster input
- `4cf6599424910a0e5fea719a304322aaeab38463` — Wire player roster lifecycle

The source work was rebased and reverified on top of the intervening published
`d3254842caf46ce9c6f1a3733c8565c171b75384` `Components.lua` fix before any Request
0022 source commit was pushed.

## 3. DONE and verified

### Player roster panel

- Added a strict, full-height right-side `CanvasGroup` roster with a CAMP ROSTER
  header, live phase label, scrolling participant rows, and automatic canvas sizing.
- Bound the panel to Tab on keyboard and `ButtonSelect` on Xbox, with matching
  bind/unbind lifecycle and no generated mobile button.
- Roster rows preserve public snapshot order within alive, ghost, and dead buckets.
- Healthy, injured/down, ghost, and dead presentation uses the repository's canonical
  `Theme.Colors.Success`, `Danger`, `Ghost`, and `TextMuted` values.
- Disconnected participants are dimmed and receive the requested `(disconnected)`
  detail.
- The local participant is identified by `participantId` and receives a subtle Gold
  right-edge accent.
- Role privacy follows the real snapshot contract: ordinary living players do not get
  a role column; ghosts and Spectators see their own private role on their own row and
  `(Role: ?)` for other public rows because `PublicParticipantSnapshot` has no role.
- The signature includes all rendered participant fields plus local observer/role
  state, so display-name, connection, health, ghost, and role-presentation changes
  rebuild the list.
- Day, Investigation, Campfire, MurderPlanning, NightTransform, and Resolution are
  eligible. Lobby, Rewards, malformed, and missing phases force-hide the panel.
- A retained `canShow` guard prevents Tab from reopening the panel after an invalid
  phase snapshot.
- Escape now closes both `GameView` modals and the independent roster when it is open.
- Fade transitions are reduced-motion safe, cancel safe, phase-transition safe, and
  destruction safe.
- The hidden full-height panel is inactive, so an invisible roster cannot intercept
  input on the right side of the screen.

### Vote target clarity

- Added private `vote.targetParticipantId` to the vote-list rebuild signature.
- The selected suspect now shows `✓ YOUR VOTE` with a Gold background and dark text.
- Other suspects keep their names, use the Panel color, and are visibly dimmed.
- All cards remain disabled after voting, and the existing action handler is unchanged.
- `Components.SetButtonEnabled()` normally dims every disabled button. The selected
  card explicitly restores its background/text transparency after disabling so the
  Gold selection remains legible.

### Request assumptions corrected

- `Theme`, `Components`, and `Motion` are sibling UI modules in the real Rojo tree;
  `PlayerStatusView` uses the same `script.Parent` paths as `GameView`, not the
  request's proposed `Shared` path.
- `Motion.FadeOut()` restores captured resting transparency during cleanup, so the
  panel's completion callback reapplies hidden `GroupTransparency = 1`.
- A phase check only inside `Update()` was insufficient because a later Tab press
  could reopen the panel. The view retains phase eligibility and rejects that toggle.
- The request's prose calls injured yellow and ghosts gray, but its explicit
  Theme/Nametags contract maps them to `Danger` red and `Ghost` blue. The implementation
  follows the canonical repository contract.
- Legacy `Critical` health is presented as DOWN alongside `Incapacitated`.

### Published source file sizes

- `src/client/UI/PlayerStatusView.lua`: **12,377 bytes**
- `src/client/UI/GameView.lua`: **186,165 bytes**
- `src/client/Controllers/InputController.lua`: **3,754 bytes**
- `src/client/Controllers/RoundController.lua`: **32,000 bytes**

### Verification performed

- Three required ownership lanes ran concurrently and stayed within their assigned
  files.
- Every changed Luau source passed strict compilation.
- The combined and rebased trees passed `git diff --check` and the complete repository
  gate.
- Every connector-published source was fetched back and matched the reviewed local Git
  blob exactly.
- A new worktree at published head
  `4cf6599424910a0e5fea719a304322aaeab38463` matched all four published source blobs
  and passed the complete required release gate.
- Rebased and fresh-published Rojo builds were deterministic at 930,171 bytes.

## 4. LEFT or deferred

- Roblox Studio visual validation remains deferred for panel sizing, safe-area
  placement, scrolling, typography, color perception, and focus behavior across
  keyboard, touch, controller, and reduced-motion configurations.
- Live multiplayer validation remains deferred for Tab/Escape input, rapid phase
  transitions, reconnect/disconnect updates, ghost/Spectator role privacy, and
  post-vote target delivery.
- The repository gate proves strict compilation, contracts, simulations, and Rojo
  packaging; it does not execute Roblox GUI rendering.
- No behavior outside Request 0022 changed.

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
Rojo artifact verified (930,171 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

Result: **PASS**.

## 6. Questions for Claude

No blocking questions. Request 0022 is implemented within scope. The key integration
corrections were the real sibling module paths, phase-retained toggle guard, Escape
ownership, Motion cleanup behavior, disabled-button transparency restoration, and
canonical Theme colors. Roblox Studio and live multiplayer remain the next proof.
