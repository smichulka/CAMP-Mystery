# Claude_Request-0016 — Player Nametags (BillboardGui) + Phase Arc Timeline

## Context

Baseline after 0015: **80 strict Luau files**, 857,711 bytes Rojo artifact.

Confirmed state from reading the repo before writing this request:
- `AudioController:SetHeartbeatIntensity` is already wired to monster dread in `RoundController` (~line 465) — do NOT add a second health-based call that would conflict
- `Players:GetPlayerByUserId(tonumber(participantId))` is the preferred match approach for connecting snapshot participants to Player objects
- `Components.ClearGenerated(parent)` clears children with the `Generated` attribute — use for roster-style dynamic rows (same pattern as in `GameView._updateRoster`)
- Phase order for the arc: `MurderPlanning → NightTransform → Investigation → Day → Campfire → Resolution`

This request adds **one new file** (count goes from 80 → 81). Wave 1 creates it; Wave 2 wires it and adds the phase arc.

---

## Wave 1 (must complete before Wave 2 begins)

### Agent 1 — NEW `src/client/UI/NametagsView.lua`

Create a strict Luau module that manages BillboardGui name tags floating above each player's character head during active phases.

```lua
--!strict
```

**Module API:**

```lua
type NametagEntry = {
    billboard: BillboardGui,
    dot: Frame,
    nameLabel: TextLabel,
    charConn: RBXScriptConnection?,
}

type NametagsView = {
    entries: { [string]: NametagEntry },  -- keyed by participantId
    destroyed: boolean,
    Destroy: (self: NametagsView) -> (),
    Update: (
        self: NametagsView,
        participants: { any },
        localParticipantId: string,
        phase: string
    ) -> (),
}

function NametagsView.new(): NametagsView
function NametagsView:Update(participants, localParticipantId, phase)
function NametagsView:Destroy()
```

---

**Imports** (at the top of the file):
```lua
local Players = game:GetService("Players")
local Theme = require(script.Parent:WaitForChild("Theme"))
local Components = require(script.Parent:WaitForChild("Components"))
```

Adjust the require paths to match what `GameView.lua` and other UI modules use to reach `Theme` and `Components`.

---

**Phases where tags are visible:**
```lua
local VISIBLE_PHASES: { [string]: boolean } = {
    Day = true, Investigation = true, Campfire = true,
}
```

During all other phases (MurderPlanning, NightTransform, Lobby, Rewards, Resolution), all tags are hidden.

---

**Building a BillboardGui for a character:**

```lua
local function buildBillboard(): BillboardGui
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Nametag"
    billboard.Size = UDim2.fromOffset(120, 28)
    billboard.StudsOffset = Vector3.new(0, 2.6, 0)
    billboard.AlwaysOnTop = false
    billboard.ResetOnSpawn = false
    billboard.Enabled = false
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local bg = Instance.new("Frame")
    bg.Name = "Bg"
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Theme.Colors.Panel
    bg.BackgroundTransparency = 0.22
    bg.BorderSizePixel = 0
    bg.Parent = billboard
    Components.Corner(bg, 6)

    local dot = Instance.new("Frame")
    dot.Name = "Dot"
    dot.Size = UDim2.fromOffset(7, 7)
    dot.AnchorPoint = Vector2.new(0, 0.5)
    dot.Position = UDim2.fromOffset(8, 14)
    dot.BorderSizePixel = 0
    dot.BackgroundColor3 = Theme.Colors.Success
    dot.Parent = bg
    Components.Corner(dot, 4)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, -22, 1, 0)
    nameLabel.Position = UDim2.fromOffset(20, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 11
    nameLabel.TextColor3 = Theme.Colors.Text
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Text = ""
    nameLabel.Parent = bg

    return billboard
end
```

---

**Attaching to a character:**

When attaching a billboard to a player's character, parent it to `character:FindFirstChild("HumanoidRootPart")` if present. If the HumanoidRootPart doesn't exist yet, wait using `character:WaitForChild("HumanoidRootPart", 4)` (4-second timeout) and attach when it arrives.

When `player.CharacterAdded` fires, re-attach the existing billboard to the new character's HumanoidRootPart. Store this connection in `entry.charConn` and disconnect the previous one before re-connecting.

---

**`NametagsView:Update(participants, localParticipantId, phase)`:**

1. If `not VISIBLE_PHASES[phase]`, set all existing billboard `.Enabled = false` and return.
2. For each participant `p` in `participants`:
   - Skip bots: `if readBoolean(p, "isBot", false) then continue end`
   - Read: `pid`, `displayName`, `alive`, `isGhost`, `healthState`
   - Find the matching Player object: `Players:GetPlayerByUserId(tonumber(pid))` — if nil, skip (bot or missing)
   - Get or create an `entry` in `self.entries[pid]`:
     - If creating: build the billboard, connect `player.CharacterAdded` (store in `charConn`), attach to current character if one exists
   - Update visual state:
     - `billboard.Enabled = VISIBLE_PHASES[phase] == true`
     - `dot.BackgroundColor3` = ghost blue if `isGhost`, danger red if alive and (Injured or Critical), muted if not alive, success green otherwise
     - `nameLabel.Text` = `if pid == localParticipantId then displayName .. " ▸" else displayName`
     - `nameLabel.TextColor3` = muted if dead (not ghost), ghost color if ghost, default otherwise
     - `bg.BackgroundTransparency` = `0.55` if dead (not ghost), `0.22` otherwise
3. Remove entries for participants no longer in the snapshot: disconnect `charConn`, destroy billboard, remove from `self.entries`.

---

**`NametagsView:Destroy()`:**

Disconnect all `charConn` connections. Destroy all billboard instances. Set `self.destroyed = true`.

---

**Helper read functions** (define locally, same pattern as other modules):

```lua
local function readBoolean(t: any, key: string, default: boolean): boolean
local function readString(t: any, key: string, default: string): string
```

---

## Wave 2 — Both agents run in parallel after Wave 1 is committed

---

### Agent 2 — `src/client/Controllers/RoundController.lua`

Wire `NametagsView` into the round lifecycle. Read the full file before editing.

**Import** (add near top with other requires):
```lua
local NametagsView = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("NametagsView"))
```
Adjust path to match how other UI modules are required in this file.

**New module-level variable:**
```lua
local nametags: any = nil
```

**In the `Start()` function** (where `audio`, `cinematics`, `view`, etc. are created):
```lua
nametags = NametagsView.new()
```

**In `refresh()`**, after snapshot and phase are determined, call:
```lua
if nametags then
    local participants = if type(snapshot) == "table" and type(snapshot.participants) == "table"
        then snapshot.participants
        else {}
    local localId = if type(player) == "table"
        then readString(player, "participantId", "")
        else ""
    nametags:Update(participants, localId, phaseName or "")
end
```

`readString` is a local helper already in `RoundController`. Confirm it exists; if not, use an equivalent inline guard.

**In `Stop()`:**
```lua
if nametags then
    nametags:Destroy()
    nametags = nil
end
```

---

### Agent 3 — `src/client/UI/GameView.lua`

Add a compact phase arc progress strip at the top of the screen. Read the full file before editing.

**New state fields:**
```lua
phaseArc: Frame?,
phaseArcDots: { [string]: Frame },
```
Initialize: `phaseArc = nil`, `phaseArcDots = {}`.

**Phase arc constants** (module-level):
```lua
local PHASE_ARC_ORDER: { string } = {
    "MurderPlanning", "NightTransform", "Investigation",
    "Day", "Campfire", "Resolution",
}
local PHASE_ARC_LABELS: { [string]: string } = {
    MurderPlanning = "PLAN",
    NightTransform  = "NIGHT",
    Investigation   = "INVEST",
    Day             = "DAY",
    Campfire        = "VOTE",
    Resolution      = "REVEAL",
}
```

**Build the arc in `GameView.new()`** (after the timer bar is built):

```lua
local arcContainer = Instance.new("Frame")
arcContainer.Name = "PhaseArc"
arcContainer.AnchorPoint = Vector2.new(0.5, 0)
arcContainer.Position = UDim2.new(0.5, 0, 0, 4)
arcContainer.Size = UDim2.fromOffset(340, 32)
arcContainer.BackgroundTransparency = 1
arcContainer.Visible = false
arcContainer.ZIndex = 12
arcContainer.Parent = root

local phaseArcDots: { [string]: Frame } = {}
local totalPhases = #PHASE_ARC_ORDER
local dotSpacing = 340 / (totalPhases - 1)

for i, phaseName in PHASE_ARC_ORDER do
    local x = (i - 1) * dotSpacing

    -- Connector line (except before first dot)
    if i > 1 then
        local line = Instance.new("Frame")
        line.Name = "Line_" .. i
        line.AnchorPoint = Vector2.new(0, 0.5)
        line.Position = UDim2.fromOffset(x - dotSpacing + 7, 10)
        line.Size = UDim2.fromOffset(dotSpacing - 14, 2)
        line.BackgroundColor3 = Theme.Colors.TextMuted
        line.BackgroundTransparency = 0.5
        line.BorderSizePixel = 0
        line.ZIndex = 12
        line.Parent = arcContainer
    end

    -- Dot
    local dot = Instance.new("Frame")
    dot.Name = "Dot_" .. phaseName
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.fromOffset(x, 10)
    dot.Size = UDim2.fromOffset(10, 10)
    dot.BackgroundColor3 = Theme.Colors.TextMuted
    dot.BorderSizePixel = 0
    dot.ZIndex = 13
    dot.Parent = arcContainer
    Components.Corner(dot, 5)
    phaseArcDots[phaseName] = dot

    -- Label below dot
    local label = Components.Label(arcContainer, "Label_" .. phaseName,
        PHASE_ARC_LABELS[phaseName] or phaseName, 8)
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.fromOffset(x, 17)
    label.Size = UDim2.fromOffset(44, 12)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextColor3 = Theme.Colors.TextMuted
    label.ZIndex = 13
end

self.phaseArc = arcContainer
self.phaseArcDots = phaseArcDots
```

**Update arc in `Update()`** — add a call to `self:_updatePhaseArc(state)`:

```lua
function GameView:_updatePhaseArc(state: any)
    local arc = self.phaseArc
    if not arc or self.destroyed then return end
    local round = if type(state) == "table" then state.round else nil
    local phase = if type(round) == "table" and type(round.phase) == "string"
        then round.phase
        else nil
    local visible = phase ~= nil and phase ~= "Lobby" and phase ~= "Rewards"
    arc.Visible = visible
    if not visible then return end

    -- Find current phase index in the arc order
    local currentIndex = 0
    for i, p in PHASE_ARC_ORDER do
        if p == phase then currentIndex = i break end
    end

    for i, phaseName in PHASE_ARC_ORDER do
        local dot = self.phaseArcDots[phaseName]
        if not dot then continue end
        if i < currentIndex then
            -- past
            dot.BackgroundColor3 = Theme.Colors.TextMuted
            dot.BackgroundTransparency = 0
            dot.Size = UDim2.fromOffset(8, 8)
        elseif i == currentIndex then
            -- current
            dot.BackgroundColor3 = Theme.Colors.Primary
            dot.BackgroundTransparency = 0
            dot.Size = UDim2.fromOffset(12, 12)
        else
            -- future
            dot.BackgroundColor3 = Theme.Colors.TextMuted
            dot.BackgroundTransparency = 0.65
            dot.Size = UDim2.fromOffset(8, 8)
        end
    end
end
```

Also destroy `phaseArc` cleanly in `Destroy()`.

---

## Definition of Done for Request 0016

- [ ] `src/client/UI/NametagsView.lua` exists and is strict Luau
- [ ] BillboardGui tags appear above player heads during Day/Investigation/Campfire, hidden during all other phases
- [ ] Tags are hidden for bot participants
- [ ] Status dot: green=healthy-alive, red=injured/critical, blue=ghost, gray=dead
- [ ] Local player name shows a `▸` marker
- [ ] `CharacterAdded` re-attachment works — tags survive character respawn
- [ ] Entries for departed participants are cleaned up (charConn disconnected, billboard destroyed)
- [ ] `NametagsView:Destroy()` tears down all connections and instances
- [ ] Phase arc strip appears at top-center during all phases except Lobby and Rewards
- [ ] Arc shows 6 phase dots: past=muted/small, current=primary/large, future=dim/small
- [ ] Arc updates on every `Update()` call via `_updatePhaseArc`
- [ ] `nametags` in RoundController is created in `Start()` and destroyed in `Stop()`
- [ ] Gate: `python scripts/run_all_checks.py --require-rojo` passes with **81 strict Luau files**
- [ ] Reply in `ClaudChat/ChatToClaude/Chat_Request-0016-nametags-phase-arc.md`

## Notes for ChatGPT

- `Theme.Colors.Primary` may not exist — check `Theme.lua` for the actual primary/accent color name (likely `Theme.Colors.Accent` or `Theme.Colors.Brand`). Use whatever the existing active-state color is (the same color used for selected tabs or active role buttons).
- `Theme.Colors.Ghost` is confirmed from previous requests — use it for the ghost dot color.
- `Billboard.AlwaysOnTop = false` is intentional — tags should be occluded by geometry (feels more grounded). If ChatGPT disagrees based on Roblox rendering constraints, use `true` and note it.
- `Players:GetPlayerByUserId` may return `nil` for bots even if `isBot = false` in the snapshot (server-controlled bots may not have a real Player object). The `if not playerObj then continue end` guard handles this.
- The phase arc position (`y=4`) may overlap with existing top UI (timer label, timer bar). Read the current `GameView.new()` top-area layout before placing — adjust `y` offset so the arc sits just below the timer bar without overlap.
- `Components.Corner(dot, 5)` on a 10×10 frame gives a circle; on a 12×12 current-phase dot it still gives a circle. This is intentional.
- Baseline file count after this request: **81**. Report final byte counts for all changed/created files in reply.
