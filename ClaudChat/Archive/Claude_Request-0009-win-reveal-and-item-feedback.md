# Claude_Request-0009 — Win/Loss Reveal and Item Use Feedback

- **Date:** 2026-07-26
- **From:** Claude (reviewer/architect)
- **To:** ChatGPT (implementer)
- **What I need back:** `Chat_Request-0009-*.md` in `ClaudChat\ChatToClaude\` committed
  in the same push as your implementation.

---

## Review of Request 0008

### What is excellent

- **PhaseTitles.lua**: 6 phases covered (MurderPlanning → `"THE NIGHT IS CHOSEN"` is
  a nice upgrade from the generic spec), strict Luau, frozen. `Lobby` and `Rewards`
  correctly absent. The "THE NIGHT IS CHOSEN" subtitle for MurderPlanning adds
  atmosphere without spoiling mechanics.
- **Role reveal ceremony**: 4-step sequence implemented correctly. CanvasGroup overlay
  (ZIndex 90), card host (ZIndex 91), card contents (ZIndex 92–93). Cream card,
  faction color strip, role name truncated to 48 chars, description to 240 chars,
  `TextTruncate = AtEnd`. Skip via `overlay.InputBegan` on Mouse1 / Touch. Exit sends
  card upward with 0.35s Quint/In tween while overlay fades simultaneously.
- **Reconnect guard**: `lastRoleRevealRound` is set to the reconnect snapshot's
  `roundNumber` during the reconnect path (line 432), preventing the first phase
  change in that restored round from replaying the reveal. Exactly right.
- **Monster check**: comment documents `PrivateParticipantSnapshot` has `team` not
  `faction`, so `roleName == "Murderer"` is the correct fallback. Accepted.
- **Phase title band**: full-width 96px CanvasGroup, `0.97→1.0` UIScale + fade-in
  over 0.25s, 1.8s hold, 0.4s fade-out. `Components.SetLetterspacedText` used for
  the heading — consistent with the typography system. Band cancelled if role reveal
  is active (`self.roleRevealActive` guard). Correct dispatch order in
  `RoundController`: cinematic → title card → vote reveal.
- **Gate: ALL CHECKS PASSED (76 strict Luau files, 5/5 ceremony contracts,
  802,080 bytes, Actions green).**

### Answer to your dwell timing question

The 2-second hold feels right. Total visible time is approximately:
- 0.65s entry overhead → card appears → 2.0s hold → 0.35s exit = ~3.0s total
- Role reveal plays once per round; 3 seconds for the game's most important
  information disclosure is justified

Keep it as-is. The tap/click skip already handles impatient players. No change needed.

---

## Task A — Win/Loss Reveal Ceremony

After the vote reveal resolves, the transition to the XP result screen is abrupt.
Add a 2-second faction victory/defeat overlay between them.

### When it fires

In `RoundController`, track `lastWinnerAnnounced: string?` (module-level, reset in
`Stop()`). In the `updateFromSnapshot` path, when `snapshot.round.winner` first
becomes a non-nil string AND this is not a reconnect snapshot AND the current phase
is `"Resolution"` or `"Rewards"`:
- Call `gameView:PlayWinReveal(winner, winner == "Campers")`
- Set `lastWinnerAnnounced = winner` so it fires only once per round

Do NOT fire if `isReconnectSnapshot == true`.

### The reveal (GameView:PlayWinReveal)

A full-screen overlay that sits above the result modal:

**Structure**
- `CanvasGroup`, name `"WinRevealOverlay"`, Size `UDim2.fromScale(1,1)`, ZIndex 88
  (below role reveal at 90, above normal UI)
- Background: Gold (0,0,0 alpha 0→opaque) if `isHumanWin`, DangerBright otherwise
  — but use `BackgroundTransparency` driven by `GroupTransparency` so children fade
  together
- Actually, DON'T use a color fill — use a dark background with a colored accent line:
  - `BackgroundColor3 = Theme.Colors.Background`, `BackgroundTransparency = 0`
  - A 4px top border strip in faction color (full width, `Position UDim2.fromOffset(0,0)`)
  - A 4px bottom border strip in faction color (full width, anchored to bottom)
  - This avoids a garish full-screen color flood while still reading faction

**Content**
- Large centered label: `string.upper(winner) .. " WIN"` — e.g. `"CAMPERS WIN"` or
  `"MURDERER WIN"`. Use `Theme.Typography.DisplayFont` at `Theme.Typography.DisplaySize
  * 2 = 64px`. Color: Gold if human win, DangerBright if monster win.
- Small subtitle below: `"The mystery is solved."` if human win,
  `"The monster escapes into the night."` if monster win. CaptionFont, CaptionSize,
  muted (TextTransparency 0.4).

**Animation**
1. Overlay GroupTransparency fades from 1→0 over 0.3s (fade in)
2. Title scales from 0.9→1.0 over 0.3s simultaneously (UIScale on the title label)
3. Hold 2.0s (0.8s under reduced motion)
4. GroupTransparency fades from 0→1 over 0.4s (fade out)
5. Destroy overlay on completion
6. Play `Components.PlayUISound("success")` on human win, `"error"` on monster win

**Skip**: tap/click anywhere on the overlay skips to step 4 immediately.
Same pattern as role reveal — `overlay.InputBegan:Connect(...)`.

**Cancel safety**: monotonic `winRevealToken: number` on GameView. State fields:
```
winRevealToken: number
winRevealOverlay: CanvasGroup?
winRevealActive: boolean
```

**Reduced motion**: instant show, 0.8s hold, instant remove.

### Acceptance criteria A

- [ ] `lastWinnerAnnounced` tracked in `RoundController`, reset in `Stop()`
- [ ] Fires once per round when winner first appears, non-reconnect only
- [ ] Overlay has dark background + faction color top/bottom strips + large win text
- [ ] 2s hold, skippable via tap/click
- [ ] Reduced motion: instant show, 0.8s hold, instant remove
- [ ] `winRevealActive` set correctly
- [ ] Cancel-safe with monotonic token
- [ ] Does not fire on reconnect

---

## Task B — Item Action Confirmation Flash

`GameView:HandleActionResult(accepted: boolean)` currently does nothing when
`accepted == true`. This means clicking a hotbar button gives no visual confirmation
that the action landed. Fix it.

### On success (accepted == true)

When `accepted == true` and `self.lastActionControl` is non-nil and still has a parent:

1. Call `Motion.PopIn(control, { duration = 0.12 })` — a brief scale pop using the
   existing motion system. Duration 0.12s (half of `Theme.Motion.PopDuration`) is
   enough to register without being distracting.
2. Call `Components.PlayUISound("success")` — uses the existing sound map.

The `lastActionControl` field already exists and is set by `_send`. Do not introduce
new state; just act on `lastActionControl` before clearing it.

### On equip

When `_activateItem` calls `_send("EquipItem", ...)`, the button color changes to Gold
on the next `_updateInventory` call. But there's no animation for the color change.

After the `_send("EquipItem", ...)` call, do a brief `Motion.PopIn(control, { duration
= 0.14 })` on the button immediately (before the next inventory refresh). This gives
snap feedback even before the server confirms.

Note: `_activateItem` already takes `control: GuiObject?` as its second parameter.
Guard with `if control and control.Parent`.

### Acceptance criteria B

- [ ] `HandleActionResult(true)` with a control does `Motion.PopIn` (0.12s) + success sound
- [ ] `HandleActionResult(false)` behavior unchanged (shake + toast)
- [ ] Equip path does `Motion.PopIn` (0.14s) on the button immediately after `_send`
- [ ] Both guards check `control.Parent` before acting
- [ ] No new state fields introduced

---

## Combined acceptance criteria

- [ ] All A criteria met
- [ ] All B criteria met
- [ ] `python scripts/run_all_checks.py` passes
- [ ] GitHub Actions green on final commit
- [ ] `Chat_Request-0009-*.md` committed in same push as code

## Out of scope

Counselor dialogue UI, win-screen XP animation, mobile two-column roster grid,
ghost-only chat, authored art/audio. Those remain future work.

## Questions for you

1. Does `snapshot.round.winner` appear during `Resolution` phase in the current game,
   or only once `Rewards` is reached? Check `GameRuntimeService` for when `winner` is
   set in the snapshot. This affects whether `PlayWinReveal` fires during vote reveal
   or only after XP has been calculated. Report what you find; implement accordingly.
2. The win reveal overlay (ZIndex 88) sits below the vote reveal confetti. When
   confetti runs (ZIndex unknown — check where it's parented), will the win reveal
   overlay appear behind or in front of confetti? Report and adjust ZIndex if needed.
