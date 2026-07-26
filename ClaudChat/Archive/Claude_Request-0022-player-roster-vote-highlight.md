# Claude_Request-0022 — Player Roster Panel (Tab Key) + Vote Target Highlight

**Base commit:** e79065f  
**Wave:** 1 (three agents, all touching different files — no merge conflicts)

---

## Mission

Two remaining gaps in game feel and clarity:

1. **The Tab key "Map" advertised in keybind hints does nothing.** Implement it as a live player
   roster panel (who is alive, injured, ghost, or dead). This is the single most prominent
   unfulfilled UI promise in the game.
2. **The vote panel shows "VOTE LOCKED" on all suspects** when the player has voted — making
   it impossible to see who you voted for. Fix it to highlight the voted suspect.

Three agents run in parallel, each owning a different set of files.

---

## Agent A — New file: `src/client/UI/PlayerStatusView.lua`

Create this file from scratch. It is a togglable side panel showing the current round's
participant roster, toggled via a method call from RoundController.

### Type definition

```lua
--!strict
```

Export two types:

```lua
export type PlayerStatusView = typeof(setmetatable({} :: PlayerStatusViewState, PlayerStatusView))
```

Where `PlayerStatusViewState` contains:
```lua
type PlayerStatusViewState = {
    root:       Instance,
    panel:      CanvasGroup,
    list:       ScrollingFrame,
    phaseLabel: TextLabel,
    destroyed:  boolean,
    visible:    boolean,
    lastSignature: string,
}
```

### Dependencies (require at top of file)

- `game:GetService("Players")` → `Players`
- `game:GetService("TweenService")` → `TweenService`
- `script.Parent.Parent:WaitForChild("Shared"):WaitForChild("Theme")` → `Theme`
  *(resolve with the same path pattern already used in other UI files in this repo)*
- `script.Parent:WaitForChild("Components")` → `Components`
- `script.Parent.Parent:WaitForChild("Shared"):WaitForChild("Motion")` → `Motion`

**Important**: Check the existing require paths in `GameView.lua` (lines 1–30) and use the
exact same patterns for Theme, Components, and Motion. Do not guess paths.

### Constants

```lua
local VISIBLE_PHASES: { [string]: boolean } = {
    Day          = true,
    Investigation = true,
    Campfire     = true,
    MurderPlanning = true,
    NightTransform = true,
    Resolution   = true,
}

-- Status dot colors match NametagsView conventions.
local STATUS_COLORS = {
    alive   = nil,   -- resolved from Theme at runtime: Theme.Colors.Success
    injured = nil,   -- Theme.Colors.Danger
    ghost   = nil,   -- Theme.Colors.Ghost
    dead    = nil,   -- Theme.Colors.TextMuted
}
```

(In practice, read them from `Theme.Colors.*` at runtime inside the functions, not as
module-level constants, so Theme is fully loaded first.)

### Panel construction — `PlayerStatusView.new(parent: Instance)`

Build the panel inside `parent` (which will be `gameView.root` — a ScreenGui):

```
CanvasGroup "PlayerStatusPanel"
  Size:       UDim2.fromOffset(270, 0) — height auto via layout
              BUT: attach to right side, full height
  AnchorPoint: (1, 0)
  Position:   UDim2.fromScale(1, 0)
  Size:       UDim2.new(0, 270, 1, 0)
  BackgroundColor3: Theme.Colors.Background (or a slightly lighter panel dark)
  BackgroundTransparency: 0.1
  GroupTransparency: 1   — starts invisible
  ZIndex: 70
  Active: true
  BorderSizePixel: 0
```

Inside the panel:

**Header strip** (top bar, 48px tall):
- Background: Theme.Colors.Panel
- Title label "CAMP ROSTER" — GothamBold, 14px, Theme.Colors.Gold, letterspace ~1
- Phase label below title — Gotham, 11px, Theme.Colors.TextMuted — store as `self.phaseLabel`

**Divider line** — 1px Frame, Theme.Colors.Ghost, 70% transparency, full width at y=48

**ScrollingFrame "List"** — below the divider, fills remaining height
- Position: UDim2.fromOffset(0, 50)
- Size: UDim2.new(1, 0, 1, -50)
- BackgroundTransparency: 1
- BorderSizePixel: 0
- ScrollBarThickness: 4
- CanvasSize: UDim2.fromOffset(0, 0)
- Layout: `Components.List(list, 2)` with padding 6px
- addCanvasSizing or UIListLayout AutomaticCanvasSize (use the same pattern as the notebook list in GameView)

Store: `self.panel = panel`, `self.list = list`, `self.phaseLabel = phaseLabel`

Initialize:
```lua
self.visible = false
self.lastSignature = ""
self.destroyed = false
```

### `PlayerStatusView:Toggle()`

```lua
function PlayerStatusView:Toggle()
    if self.destroyed then return end
    if self.visible then
        self:_hide()
    else
        self:_show()
    end
end
```

### `PlayerStatusView:_show()` and `_hide()`

Show:
```lua
self.visible = true
if Motion.IsReducedMotion(self.root) then
    self.panel.GroupTransparency = 0
else
    Motion.FadeIn(self.panel)
end
```

Hide:
```lua
self.visible = false
if Motion.IsReducedMotion(self.root) then
    self.panel.GroupTransparency = 1
else
    Motion.FadeOut(self.panel)
end
```

### `PlayerStatusView:Update(participants: { any }, localPlayer: any, phase: string)`

Called every state refresh from RoundController. If not `VISIBLE_PHASES[phase]`, force-hide
and clear signature.

Build a signature from participant IDs + alive + isGhost + healthState + phase. If signature
matches `self.lastSignature`, skip rebuild. Otherwise clear the list and rebuild rows.

**Sort order for participants**: build three buckets, then concat:
1. Alive (alive == true)
2. Ghost (isGhost == true and alive == false)
3. Dead (alive == false and isGhost == false)

**Each row** (height 42px, full width, no background):

Left side:
- Small circle dot (12×12, rounded) — color based on status:
  - alive + healthState "Healthy": Theme.Colors.Success
  - alive + healthState "Injured" or "Incapacitated": Theme.Colors.Danger
  - isGhost: Theme.Colors.Ghost
  - dead (not alive, not ghost): Theme.Colors.TextMuted
- Display name label — 14px Gotham, Theme.Colors.Text if alive, Theme.Colors.TextMuted if dead/ghost

Right side (right-aligned):
- Status text label — 11px, muted:
  - alive + Healthy: "" (blank)
  - alive + Injured: "INJURED" in Theme.Colors.Danger
  - alive + Incapacitated: "DOWN" in Theme.Colors.Danger
  - isGhost: "GHOST" in Theme.Colors.Ghost
  - dead (not ghost): "DEAD" in Theme.Colors.TextMuted

**Role visibility rule** — show role name below display name ONLY IF:
- `localPlayer ~= nil and localPlayer.isGhost == true`, OR
- `localPlayer ~= nil and localPlayer.role == "Spectator"`

When role is visible, add a small role label (11px, Gold for Murderer, Info for others) below
the display name. Roles come from `participant.role` — BUT `PublicParticipantSnapshot` does
NOT include `role`. Role is only in `PrivateParticipantSnapshot`. So: **only show the local
player's own role on their own row**. Ghosts/spectators can see everyone's role ONLY if the
server includes role in the public snapshot. Since it does NOT, display "?" for others when
in ghost/spectator mode, OR omit the role column entirely for non-ghost players.

**Practical implementation**: for ghost/spectator, add a note "(Role: ?)" in muted text for
other participants. For the local player's own row: show their role from `localPlayer.role`.

Mark local player's row with a subtle right-border accent (2px Gold bar on the right edge).

**Self-identification**: identify the local player's row by checking `localPlayer.participantId`
(from the private snapshot, `state.player.participantId`) against each participant's
`participantId`. If the `localPlayer` is nil or participantId is unknown, skip the accent.

**Connection status**: if `participant.connected == false`, dim the name label to 50%
transparency and append " (disconnected)" in 10px muted text.

### `PlayerStatusView:Destroy()`

```lua
function PlayerStatusView:Destroy()
    self.destroyed = true
    if self.panel and self.panel.Parent then
        self.panel:Destroy()
    end
end
```

---

## Agent B — `src/client/UI/GameView.lua`

**One targeted change only**: fix the vote panel to highlight the suspect the local player
voted for.

### B1. Add vote target to the signature

In `GameView:_updateVote()` (around line 3537), the signature currently reads:

```lua
local pieces = { tostring(hasVoted) }
```

Change to:

```lua
local voteTargetId = ""
if type(vote) == "table" and type(vote.targetParticipantId) == "string" then
    voteTargetId = vote.targetParticipantId
end
local pieces = { tostring(hasVoted), voteTargetId }
```

This ensures the panel rebuilds when the vote target arrives.

### B2. Highlight the voted suspect card

In the suspect button creation loop (around line 3553–3574), replace the current button
construction with this logic:

```lua
local isMyVote = hasVoted and voteTargetId ~= "" and key == voteTargetId
local isOtherVote = hasVoted and not isMyVote

local button = Components.Button(self.voteList, {
    name = "Vote_" .. key:gsub("[^%w]", "_"),
    text = if isMyVote then name .. "  ✓ YOUR VOTE"
           elseif hasVoted then name
           else name,
    size = UDim2.new(1, -8, 0, 48),
    color = if isMyVote then Theme.Colors.Gold
            elseif isOtherVote then Theme.Colors.Panel
            else Theme.Colors.Danger,
})
button:SetAttribute("Generated", true)

-- When voted: disable all buttons; isMyVote button has a gold accent, others are dimmed.
Components.SetButtonEnabled(button, not hasVoted)

if isOtherVote and button:IsA("GuiButton") then
    -- Visually dim the non-voted suspects.
    button.BackgroundTransparency = 0.7
end
if isMyVote then
    -- Gold text color for the voted card.
    button.TextColor3 = Theme.Colors.Background
end
```

Keep the `button.Activated:Connect(...)` block exactly as it exists — it already handles
the vote action and guards against double-voting through `hasVoted`.

---

## Agent C — `src/client/Controllers/InputController.lua` + `src/client/Controllers/RoundController.lua`

Two files, both owned by Agent C.

### C1. `InputController.lua` — add `togglePlayerStatus` callback + Tab keybind

**Update the `InputCallbacks` type** to include the new callback:

```lua
type InputCallbacks = {
    toggleNotebook:      () -> (),
    toggleSettings:      () -> (),
    togglePlayerStatus:  () -> (),   -- ADD THIS
    activateSlot:        (slot: number) -> (),
    selectSlot:          (slot: number) -> (),
    getSlotCount:        () -> number,
    closeModal:          () -> (),
}
```

**Add action name constant** (alongside existing ones):

```lua
local ACTION_PLAYER_STATUS = "CampMysteryPlayerStatus"
```

**In `InputController.Start()`**, after the existing `ACTION_NOTEBOOK` bind block, add:

```lua
ContextActionService:BindAction(
    ACTION_PLAYER_STATUS,
    activate(callbacks.togglePlayerStatus),
    false,
    Enum.KeyCode.Tab,
    Enum.KeyCode.ButtonSelect  -- "View" button on Xbox
)
```

No on-screen mobile button (`createTouchButton = false`).

**In `InputController.Stop()`**, add:

```lua
ContextActionService:UnbindAction(ACTION_PLAYER_STATUS)
```

### C2. `RoundController.lua` — create PlayerStatusView and wire it

**At the top of the file**, add require alongside existing UI requires:

```lua
local PlayerStatusViewModule = require(uiFolder:WaitForChild("PlayerStatusView"))
```

**Add module-level variable** alongside existing ones (e.g., near `local effects: any = nil`):

```lua
local playerStatus: any = nil
```

**In the `refresh(snapshot, isReconnectSnapshot)` function**, after the existing
`currentNametags:Update(...)` call (around line 355), add:

```lua
local currentPlayerStatus = playerStatus
if currentPlayerStatus then
    local phase = if type(round) == "table" and type(round.phase) == "string"
        then round.phase
        else "Lobby"
    currentPlayerStatus:Update(participants, player, phase)
end
```

Where `participants` and `player` are the existing local variables already in scope at
that point in `refresh()`. Verify the variable names by reading the existing code around
line 340–360.

**In the main startup block** (after `effects = EffectsViewModule.new(gameView.root)`,
around line 732–733), add:

```lua
local releasePlayerStatus = PlayerStatusViewModule.new(gameView.root)
playerStatus = releasePlayerStatus
```

**In the `InputController.Start({...})` call** (around line 837), add the new callback:

```lua
togglePlayerStatus = function()
    local current = playerStatus
    if current then
        current:Toggle()
    end
end,
```

**In the cleanup / stop logic** (around line 891 where nametags is destroyed), add:

```lua
if playerStatus then
    playerStatus:Destroy()
    playerStatus = nil
end
```

---

## Acceptance Criteria

- [ ] Pressing Tab during Day, Investigation, Campfire shows/hides the right-side roster panel
- [ ] Tab again (or Escape via `closeModal`) dismisses the panel
- [ ] Panel shows all participants sorted alive → ghost → dead
- [ ] Status dot colors match: green (alive/healthy), yellow (injured), gray (ghost), muted (dead)
- [ ] Disconnected participants are visually dimmed with "(disconnected)" label
- [ ] Local player's row has a subtle gold right-border accent
- [ ] Local player's own role is shown on their row; other rows show "?" for ghost/spectator viewers
- [ ] Panel hides automatically in Lobby and Rewards phases (VISIBLE_PHASES guard)
- [ ] Panel is motion-safe (reduced motion: instant show/hide)
- [ ] Panel is destroy-safe (Destroy() cleans up the CanvasGroup)
- [ ] Vote panel: after voting, the voted suspect card shows gold background + "✓ YOUR VOTE" text
- [ ] Vote panel: other suspect cards are dimmed (not all showing "VOTE LOCKED")
- [ ] Vote panel rebuilds when `targetParticipantId` changes (signature includes it)
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, Rojo builds cleanly)
- [ ] No `tick()` usage — use `os.clock()` or `Workspace:GetServerTimeNow()` if any time-based logic needed
- [ ] All new CanvasGroups start with `GroupTransparency = 1` (invisible until shown)

---

## File Summary

| File | Status | Agent |
|------|--------|-------|
| `src/client/UI/PlayerStatusView.lua` | New | A |
| `src/client/UI/GameView.lua` | Modified | B |
| `src/client/Controllers/InputController.lua` | Modified | C |
| `src/client/Controllers/RoundController.lua` | Modified | C |
