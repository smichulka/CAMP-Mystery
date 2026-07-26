# Claude_Request-0014 — Live Player Roster + Vote Count + Injury Pulse

## Context

Baseline after 0013: **80 strict Luau files**, 843,321 bytes.

Confirmed Motion API:
- `CanvasGroup.GroupTransparency` must be **0** (visible) on creation. `Motion.FadeIn` captures `0`, sets it to `1`, then tweens back to `0`. Initializing it to `1` leaves the element invisible.

This request has no new files. All three agents own different existing files and can run simultaneously.

---

## Single Wave — All three agents in parallel (no dependency ordering needed)

---

### Agent 1 — `src/client/UI/GameView.lua`

Two additions in a single commit. Read the full file (~151 KB) before editing.

---

#### 1a — Live player roster HUD panel

A compact panel showing all participants' status during Investigation, Day, and Campfire. Shown on the right side of the screen, above the hotbar.

**New state fields** (add to type and initializer):

```lua
rosterPanel: Frame?,
rosterScrollFrame: ScrollingFrame?,
lastRosterSignature: string,
```

Initialize: `rosterPanel = nil`, `rosterScrollFrame = nil`, `lastRosterSignature = ""`.

**Build the panel** in `GameView.new()`, after the hotbar is set up (around line ~590):

```lua
-- Live player roster panel — right side, visible during active round phases
local rosterPanel = Instance.new("Frame")
rosterPanel.Name = "PlayerRoster"
rosterPanel.AnchorPoint = Vector2.new(1, 1)
rosterPanel.Position = UDim2.new(1, -18, 1, -96)
rosterPanel.Size = UDim2.fromOffset(180, 0)
rosterPanel.AutomaticSize = Enum.AutomaticSize.Y
rosterPanel.BackgroundColor3 = Theme.Colors.Panel
rosterPanel.BackgroundTransparency = 0.18
rosterPanel.BorderSizePixel = 0
rosterPanel.Visible = false
rosterPanel.ZIndex = 18
rosterPanel.Parent = root
Components.Corner(rosterPanel, 8)

local rosterLayout = Instance.new("UIListLayout")
rosterLayout.Padding = UDim.new(0, 0)
rosterLayout.SortOrder = Enum.SortOrder.LayoutOrder
rosterLayout.Parent = rosterPanel

local rosterPadding = Instance.new("UIPadding")
rosterPadding.PaddingTop = UDim.new(0, 8)
rosterPadding.PaddingBottom = UDim.new(0, 8)
rosterPadding.PaddingLeft = UDim.new(0, 10)
rosterPadding.PaddingRight = UDim.new(0, 10)
rosterPadding.Parent = rosterPanel
```

Store: `rosterPanel = rosterPanel`.

**Update in `Update()`** — add a new `_updateRoster(state)` call near the existing `Update()` dispatch, called only when `state.participants` changes. Implement `_updateRoster`:

```lua
local ROSTER_PHASES: { [string]: boolean } = {
    Day = true, Investigation = true, Campfire = true,
}

function GameView:_updateRoster(state: any)
    local panel = self.rosterPanel
    if not panel or self.destroyed then
        return
    end
    local round = if type(state) == "table" then state.round else nil
    local phase = if type(round) == "table" and type(round.phase) == "string"
        then round.phase
        else nil
    if not phase or not ROSTER_PHASES[phase] then
        panel.Visible = false
        return
    end
    panel.Visible = true

    -- Build signature to skip redraws when nothing changed
    local participants = if type(state) == "table" then asTable(state.participants) else {}
    local sigParts: { string } = {}
    for _, p in participants do
        if type(p) == "table" and not readBoolean(p, "isBot", true) then
            table.insert(sigParts, string.format(
                "%s:%s:%s:%s",
                readString(p, "participantId", ""),
                tostring(readBoolean(p, "alive", false)),
                tostring(readBoolean(p, "isGhost", false)),
                readString(p, "healthState", "Healthy")
            ))
        end
    end
    table.sort(sigParts)
    local sig = table.concat(sigParts, "|")
    if sig == self.lastRosterSignature then
        return
    end
    self.lastRosterSignature = sig

    -- Clear old rows (Generated attribute)
    Components.ClearGenerated(panel)

    -- Sort: alive first, then ghost, then dead; within each group by name
    local sorted: { any } = {}
    for _, p in participants do
        if type(p) == "table" and not readBoolean(p, "isBot", true) then
            table.insert(sorted, p)
        end
    end
    table.sort(sorted, function(a, b)
        local aAlive = readBoolean(a, "alive", false)
        local bAlive = readBoolean(b, "alive", false)
        local aGhost = readBoolean(a, "isGhost", false)
        local bGhost = readBoolean(b, "isGhost", false)
        local aScore = if aAlive and not aGhost then 0 elseif aGhost then 1 else 2
        local bScore = if bAlive and not bGhost then 0 elseif bGhost then 1 else 2
        if aScore ~= bScore then return aScore < bScore end
        return readString(a, "displayName", "") < readString(b, "displayName", "")
    end)

    local ownId = if type(state.player) == "table"
        then readString(state.player, "participantId", "")
        else ""

    for i, p in sorted do
        local pid = readString(p, "participantId", "")
        local name = readString(p, "displayName", "?")
        local alive = readBoolean(p, "alive", false)
        local ghost = readBoolean(p, "isGhost", false)
        local healthState = readString(p, "healthState", "Healthy")
        local isMe = pid == ownId

        local row = Instance.new("Frame")
        row.Name = "RosterRow_" .. i
        row:SetAttribute("Generated", true)
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = panel

        -- Status dot
        local dot = Instance.new("Frame")
        dot.Name = "Dot"
        dot.Size = UDim2.fromOffset(8, 8)
        dot.AnchorPoint = Vector2.new(0, 0.5)
        dot.Position = UDim2.fromOffset(0, 11)
        dot.BorderSizePixel = 0
        dot.BackgroundColor3 = if ghost then Theme.Colors.Ghost
            elseif not alive then Theme.Colors.TextMuted
            elseif healthState == "Injured" or healthState == "Critical" then Theme.Colors.Danger
            else Theme.Colors.Success
        dot.Parent = row
        Components.Corner(dot, 4)

        -- Name label
        local nameLabel = Components.Label(row, "Name", if isMe then name .. " ●" else name, 11)
        nameLabel.Position = UDim2.fromOffset(14, 0)
        nameLabel.Size = UDim2.new(1, -14, 1, 0)
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextColor3 = if ghost then Theme.Colors.Ghost
            elseif not alive then Theme.Colors.TextMuted
            else Theme.Colors.Text
        nameLabel.TextTransparency = if not alive and not ghost then 0.5 else 0
    end
end
```

Call `self:_updateRoster(state)` from within the existing `Update(state)` body (near the end, after other update calls).

Also destroy `rosterPanel` cleanly in `Destroy()`.

---

#### 1b — Live vote count in campfire modal header

**New state field:**

```lua
voteCountLabel: TextLabel?,
```

Initialize to `nil`.

**In `_buildVote()`**, immediately after `makeHeader(self.voteModal, "CAMPFIRE ACCUSATION", ...)`, add:

```lua
local voteCountLabel = Components.Label(self.voteModal, "VoteCountLabel", "", 11, Enum.Font.GothamBold)
voteCountLabel.AnchorPoint = Vector2.new(1, 0)
voteCountLabel.Position = UDim2.new(1, -14, 0, 18)
voteCountLabel.Size = UDim2.fromOffset(88, 20)
voteCountLabel.TextXAlignment = Enum.TextXAlignment.Right
voteCountLabel.TextColor3 = Theme.Colors.TextMuted
self.voteCountLabel = voteCountLabel
```

**In `Update()`**, after participant data is read, update the vote count label:

```lua
-- Vote count display in campfire modal
if self.voteCountLabel then
    local round = if type(state) == "table" then state.round else nil
    local votePhase = type(round) == "table"
        and readString(round, "phase", "") == "Campfire"
    if votePhase then
        local participants = if type(state) == "table" then asTable(state.participants) else {}
        local totalEligible = 0
        local totalVoted = 0
        for _, p in participants do
            if type(p) == "table"
                and not readBoolean(p, "isBot", false)
                and readBoolean(p, "alive", false)
                and not readBoolean(p, "isGhost", false)
            then
                totalEligible += 1
                -- Vote state is on the private snapshot (player) or public participants
                -- Use the public participant's hasVoted if available
                local vote = if type(p.vote) == "table" then p.vote else nil
                if type(vote) == "table" and vote.hasVoted == true then
                    totalVoted += 1
                end
            end
        end
        self.voteCountLabel.Text = string.format("%d/%d VOTED", totalVoted, totalEligible)
    else
        self.voteCountLabel.Text = ""
    end
end
```

Note: `PublicParticipantSnapshot` may not include a `vote` field. If it's absent, check `state.player.vote.hasVoted` for the local player and leave others unknown. In that case simplify: count non-bot alive non-ghost participants who are `state.player` if their vote is locked, or omit the "already voted" sub-count and just show "N ELIGIBLE". Do whichever is data-available; report the approach in your reply.

---

### Agent 2 — `src/client/UI/EffectsView.lua`

Add a repeating pulse on the damage border when the player is injured. Read the full file before editing.

**New state field** (add to `EffectsViewState` type and initializer):

```lua
injuryPulseTween: Tween?,
```

Initialize: `injuryPulseTween = nil`.

**New private helper `_stopInjuryPulse`** (add before `SetMonsterStatus`):

```lua
function EffectsView:_stopInjuryPulse()
    local t = self.injuryPulseTween
    if t then
        t:Cancel()
        self.injuryPulseTween = nil
    end
end
```

**Modify `SetMonsterStatus`** — at the top, just after the guard/early-return section and before setting `self.lastStatus = statusId`, add `self:_stopInjuryPulse()`. This cancels any previous pulse before applying the new status.

Then, after the existing `statusStroke` one-shot fade-in tween at the bottom of the method (for `not self.reducedMotion`), add a repeating pulse for injury statuses:

```lua
-- Repeating pulse for sustained injury statuses
local PULSE_STATUSES: { [string]: boolean } = {
    Injured = true, Incapacitated = true, Bleeding = true, Latched = true,
}
if not self.reducedMotion and statusId and PULSE_STATUSES[statusId] then
    local pulseTween = TweenService:Create(
        self.statusStroke,
        TweenInfo.new(
            0.9,
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.InOut,
            -1,   -- repeat forever
            true  -- reverses (ping-pong)
        ),
        { Transparency = 0.72 }
    )
    self.injuryPulseTween = pulseTween
    -- Start after the one-shot fade finishes
    task.delay(0.5, function()
        if not self.destroyed and self.injuryPulseTween == pulseTween then
            pulseTween:Play()
        end
    end)
end
```

**In `Destroy()`**, add `self:_stopInjuryPulse()` before the existing cleanup.

**Important:** The one-shot fade tween (already in `SetMonsterStatus`) tweens `statusStroke.Transparency` from 0.05 → 0.32 over 0.45s. The pulse starts at 0.5s (after the one-shot), tweening from 0.32 → 0.72 and back, at 0.9s period. These don't conflict because the one-shot completes before the pulse starts.

---

### Agent 3 — `src/client/Controllers/RoundController.lua`

Two additions in a single commit.

#### 3a — Round-start toast

**New module-level variable** (add near other `last*` vars):

```lua
local lastToastedRound: number? = nil
```

**In `refresh()`**, after `local phaseName` is determined (around line ~258–261), in the phase-change block:

```lua
-- Show round number once per round when leaving Lobby
local roundNumber = if type(round) == "table" and type(round.roundNumber) == "number"
    then round.roundNumber
    else nil
if roundNumber
    and roundNumber ~= lastToastedRound
    and phaseName ~= "Lobby"
    and phaseName ~= "Rewards"
    and currentView
then
    lastToastedRound = roundNumber
    currentView:Notify(
        string.format("ROUND %d", roundNumber),
        "The mystery begins. Stay together.",
        "Info"
    )
end
```

**In `Stop()`**, reset:

```lua
lastToastedRound = nil
```

#### 3b — Investigation urgency warning

**New module-level variable**:

```lua
local sentUrgencyWarning = false
```

**In `refresh()`**, in the section where `round` is read and `phase` is active:

```lua
-- One-time urgency toast when investigation timer drops below 60s
if phaseName == "Investigation" and currentView then
    local phaseEndsAt = if type(round) == "table"
        then readNumber(round, "phaseEndsAt", 0)
        else 0
    local remaining = phaseEndsAt - Workspace:GetServerTimeNow()
    if remaining > 0 and remaining < 60 and not sentUrgencyWarning then
        sentUrgencyWarning = true
        currentView:Notify("Investigation closing", "Under a minute remaining.", "Danger")
    end
end
if phaseName ~= "Investigation" then
    sentUrgencyWarning = false
end
```

Note: `Workspace` is already imported in `RoundController.lua` at the top. `readNumber` is a local helper already defined in that file. Confirm both before inserting.

**In `Stop()`**, reset:

```lua
sentUrgencyWarning = false
```

---

## Definition of Done for Request 0014

- [ ] Player roster panel appears during Day/Investigation/Campfire with alive (green dot), ghost (blue dot), dead (gray dot), injured (red dot) — sorted alive-first
- [ ] Roster updates only when participant states change (signature guard)
- [ ] Roster is hidden during Lobby, Rewards, and any phase without ROSTER_PHASES entry
- [ ] `voteCountLabel` shows "X/Y VOTED" during Campfire; empty otherwise
- [ ] `EffectsView` injury pulse: Bleeding/Injured/Incapacitated/Latched statuses trigger a 0.9s ping-pong stroke pulse; other statuses use one-shot fade only
- [ ] `ClearGenerated(panel)` and `Destroy()` clean up all roster rows and injury tween
- [ ] Round number toast fires once per round when first leaving Lobby
- [ ] Investigation urgency notification fires once per Investigation phase when <60s remain
- [ ] Gate: `python scripts/run_all_checks.py --require-rojo` passes with **80 strict Luau files** (no new files this request)
- [ ] Reply in `ClaudChat/ChatToClaude/Chat_Request-0014-roster-panel-vote-count-injury-pulse.md`

## Notes for ChatGPT

- `asTable` is a local helper in `GameView.lua`; confirm it's accessible at the `_updateRoster` call site.
- `PublicParticipantSnapshot` does NOT include a `vote` field — only `PrivateParticipantSnapshot` does. For vote count: count non-bot alive non-ghost participants, and separately compare against `state.player.vote.hasVoted` for the local player only. For others, the count from a server-pushed vote tally may be needed. If the data isn't available on `participants`, simplify `voteCountLabel` to just show "N ELIGIBLE" or omit the voted sub-count and note this in the reply.
- `ROSTER_PHASES` is a module-level constant inside `_updateRoster` — in strict Luau this is fine as a local constant inside a function body.
- `Components.Corner(dot, 4)` — `dot` is a `Frame` inside a `Frame` that is inside `rosterPanel`. Verify the parent chain resolves correctly.
- Baseline file count stays at 80. Report final `GameView.lua` byte count in reply.
