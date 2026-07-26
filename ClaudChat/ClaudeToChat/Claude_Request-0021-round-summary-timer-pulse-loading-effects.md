# Claude_Request-0021 — Round Summary, Timer Pulse, Loading Screen, Evidence Flash

**Base commit:** e2cf38c  
**Wave:** 1 (all four agents run in parallel — no shared files)

---

## Mission

Four simultaneous agents finish the remaining professional-quality gaps:

1. **Agent A** — `src/client/UI/GameView.lua`: Round recap overlay, timer urgency pulse, reconnect overlay enhancement, murderer MurderPlanning objective text
2. **Agent B** — `src/client/Controllers/RoundController.lua`: Wire round summary and reconnect phase arg
3. **Agent C** — `src/client/UI/EffectsView.lua`: Evidence discovery flash effect
4. **Agent D** — `src/client/LoadingScreen.client.lua` (NEW) + `default.project.json`: Branded loading screen under ReplicatedFirst

All agents touch different files. No merge conflicts.

---

## Agent A — `src/client/UI/GameView.lua`

Four additions to the existing file. No removals. All changes are additive.

---

### A1. `PlayRoundSummary(stats)` — Round Recap Overlay

Add this method after `PlayWinReveal`. It shows a full-screen recap after the win reveal exits.

**Type for stats parameter** (declare at top of file near other local types, after the existing `type EliminatedBannerState` or similar):

```lua
type RoundSummaryStats = {
    roundNumber: number,
    winner: string,
    isHumanWin: boolean,
    evidenceFound: number,
    evidenceGoal: number,
    objectivesCompleted: number,
    objectiveGoal: number,
    survivorCount: number,
    totalParticipants: number,
    monsterId: string?,
    victimName: string?,
    personalEvidence: number,
    playerRole: string,
}
```

**Add two instance fields** to the GameView type (in the `type GameView = { ... }` block):

```lua
roundSummaryOverlay: CanvasGroup?,
roundSummaryToken: number,
```

**Initialize** both to `nil` / `0` in the constructor (alongside `winRevealToken = 0`).

**In `Destroy()`**, destroy `self.roundSummaryOverlay` if it exists (alongside winRevealOverlay cleanup pattern).

**Implementation:**

```lua
function GameView:PlayRoundSummary(stats: RoundSummaryStats)
    if self.destroyed then return end
    -- Internal delay so the win reveal (2.3s auto-exit) finishes first.
    self.roundSummaryToken += 1
    local token = self.roundSummaryToken
    task.delay(2.7, function()
        if self.destroyed or self.roundSummaryToken ~= token then return end

        local factionColor = if stats.isHumanWin
            then Theme.Colors.Gold
            else Theme.Colors.DangerBright

        local overlay = Instance.new("CanvasGroup")
        overlay.Name = "RoundSummaryOverlay"
        overlay.Size = UDim2.fromScale(1, 1)
        overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        overlay.BackgroundTransparency = 0.55
        overlay.GroupTransparency = 1
        overlay.BorderSizePixel = 0
        overlay.Active = true
        overlay.ZIndex = 80
        overlay.Parent = self.root
        self.roundSummaryOverlay = overlay

        -- Central card
        local card = Instance.new("Frame")
        card.Name = "SummaryCard"
        card.AnchorPoint = Vector2.new(0.5, 0.5)
        card.Position = UDim2.fromScale(0.5, 0.5)
        card.Size = UDim2.fromOffset(520, 380)
        card.BackgroundColor3 = Theme.Colors.Panel
        card.BackgroundTransparency = 0.06
        card.BorderSizePixel = 0
        card.ZIndex = 81
        card.Parent = overlay
        Components.Corner(card, 12)

        -- Top accent strip
        local strip = Instance.new("Frame")
        strip.Name = "AccentStrip"
        strip.Size = UDim2.new(1, 0, 0, 4)
        strip.BackgroundColor3 = factionColor
        strip.BorderSizePixel = 0
        strip.ZIndex = 82
        strip.Parent = card

        local uiCornerStrip = Instance.new("UICorner")
        uiCornerStrip.CornerRadius = UDim.new(0, 12)
        uiCornerStrip.Parent = strip

        -- Header
        local header = Components.Label(card, "Header",
            string.format("ROUND %d RECAP", stats.roundNumber),
            22, Enum.Font.GothamBold)
        header.Position = UDim2.fromOffset(24, 18)
        header.Size = UDim2.new(1, -48, 0, 28)
        header.TextColor3 = Theme.Colors.Gold
        header.TextXAlignment = Enum.TextXAlignment.Center
        header.ZIndex = 82

        -- Winner line
        local winText = if stats.isHumanWin
            then "THE CAMP SURVIVED"
            else "THE MONSTER ESCAPED"
        local winLabel = Components.Label(card, "WinLine", winText,
            15, Enum.Font.GothamBold)
        winLabel.Position = UDim2.fromOffset(24, 50)
        winLabel.Size = UDim2.new(1, -48, 0, 22)
        winLabel.TextColor3 = factionColor
        winLabel.TextXAlignment = Enum.TextXAlignment.Center
        winLabel.ZIndex = 82

        -- Divider
        local divider = Instance.new("Frame")
        divider.Name = "Divider"
        divider.Position = UDim2.fromOffset(32, 80)
        divider.Size = UDim2.new(1, -64, 0, 1)
        divider.BackgroundColor3 = Theme.Colors.Ghost
        divider.BackgroundTransparency = 0.7
        divider.BorderSizePixel = 0
        divider.ZIndex = 82
        divider.Parent = card

        -- Stat rows: each row is a label pair (left label, right value)
        local function statRow(yOffset: number, labelText: string, valueText: string, valueColor: Color3?)
            local lbl = Components.Label(card, labelText .. "Label", labelText, 14)
            lbl.Position = UDim2.fromOffset(36, yOffset)
            lbl.Size = UDim2.fromOffset(240, 26)
            lbl.TextColor3 = Theme.Colors.TextMuted
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.ZIndex = 82

            local val = Components.Label(card, labelText .. "Value", valueText, 14, Enum.Font.GothamBold)
            val.Position = UDim2.new(1, -36, 0, yOffset)
            val.AnchorPoint = Vector2.new(1, 0)
            val.Size = UDim2.fromOffset(210, 26)
            val.TextColor3 = valueColor or Theme.Colors.Text
            val.TextXAlignment = Enum.TextXAlignment.Right
            val.ZIndex = 82
        end

        local survivorColor = if stats.survivorCount == 0
            then Theme.Colors.DangerBright
            elseif stats.survivorCount >= stats.totalParticipants
            then Theme.Colors.Success
            else Theme.Colors.Text

        statRow(96,  "Survivors",  string.format("%d of %d", stats.survivorCount, stats.totalParticipants), survivorColor)
        statRow(128, "Evidence",   string.format("%d / %d clues", stats.evidenceFound, stats.evidenceGoal),
            if stats.evidenceFound >= stats.evidenceGoal then Theme.Colors.Success else Theme.Colors.Text)
        statRow(160, "Camp Tasks", string.format("%d / %d", stats.objectivesCompleted, stats.objectiveGoal),
            if stats.objectivesCompleted >= stats.objectiveGoal then Theme.Colors.Success else Theme.Colors.Text)

        -- Monster / victim row (conditional)
        if stats.monsterId and stats.monsterId ~= "" then
            local monsterDisplay = stats.monsterId:gsub("(%l)(%u)", "%1 %2"):gsub("-", " ")
            statRow(192, "Monster", monsterDisplay, Theme.Colors.DangerBright)
        end
        if stats.victimName and stats.victimName ~= "" then
            statRow(224, "Victim", stats.victimName, Theme.Colors.TextMuted)
        end

        -- Personal contribution (skip for Spectators)
        if stats.playerRole ~= "Spectator" and stats.personalEvidence > 0 then
            local personalLabel = Components.Label(card, "PersonalContrib",
                string.format("You contributed %d evidence piece%s.",
                    stats.personalEvidence,
                    if stats.personalEvidence == 1 then "" else "s"),
                13)
            personalLabel.Position = UDim2.fromOffset(24, 270)
            personalLabel.Size = UDim2.new(1, -48, 0, 22)
            personalLabel.TextColor3 = Theme.Colors.Gold
            personalLabel.TextXAlignment = Enum.TextXAlignment.Center
            personalLabel.ZIndex = 82
        end

        -- Auto-advance countdown label
        local countdownLabel = Components.Label(card, "Countdown", "Auto-advancing in 8s", 12)
        countdownLabel.Position = UDim2.fromOffset(24, 302)
        countdownLabel.Size = UDim2.new(1, -48, 0, 20)
        countdownLabel.TextColor3 = Theme.Colors.TextMuted
        countdownLabel.TextXAlignment = Enum.TextXAlignment.Center
        countdownLabel.ZIndex = 82

        -- Dismiss button
        local dismissBtn = Components.Button(card, {
            name = "DismissBtn",
            text = "VIEW REWARDS →",
            size = UDim2.fromOffset(190, 44),
            position = UDim2.new(0.5, 0, 1, -60),
            color = Theme.Colors.Gold,
        })
        dismissBtn.AnchorPoint = Vector2.new(0.5, 0)
        dismissBtn.ZIndex = 82

        local dismissed = false
        local function dismiss()
            if dismissed or self.destroyed then return end
            dismissed = true
            if self.roundSummaryToken ~= token then return end
            local fadeOut = TweenService:Create(overlay,
                TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                { GroupTransparency = 1 })
            fadeOut.Completed:Connect(function()
                if overlay.Parent then overlay:Destroy() end
                if self.roundSummaryOverlay == overlay then
                    self.roundSummaryOverlay = nil
                end
            end)
            fadeOut:Play()
        end

        dismissBtn.Activated:Connect(dismiss)

        -- Countdown loop
        local countdown = 8
        task.spawn(function()
            while countdown > 0 and not dismissed and not self.destroyed do
                task.wait(1)
                countdown -= 1
                if countdownLabel.Parent then
                    countdownLabel.Text = if countdown > 0
                        then string.format("Auto-advancing in %ds", countdown)
                        else "Advancing..."
                end
            end
            if not dismissed then dismiss() end
        end)

        -- Pop in
        if Motion.IsReducedMotion(self.root) then
            overlay.GroupTransparency = 0
        else
            Motion.FadeIn(overlay)
        end
    end)
end
```

---

### A2. Timer Urgency Pulse

When `seconds <= 10 and seconds > 0`, pulse the timer label's TextSize between 19 and 22 at ~3 Hz via RunService.Heartbeat. When `seconds > 10` or `seconds == 0`, stop the pulse and reset to size 19.

**Add two instance fields** to the GameView type:

```lua
timerPulseConn: RBXScriptConnection?,
timerPulsing: boolean,
```

**Initialize** both to `nil` / `false` in the constructor.

**In `Destroy()`**, disconnect `self.timerPulseConn` if it exists.

**Add two private methods:**

```lua
function GameView:_startTimerPulse()
    if self.timerPulsing then return end
    self.timerPulsing = true
    self.timerPulseConn = RunService.Heartbeat:Connect(function()
        if self.destroyed then
            self:_stopTimerPulse()
            return
        end
        local t = os.clock()
        local sinValue = math.sin(t * math.pi * 3)  -- ~3 Hz
        local size = math.round(19 + sinValue * 1.5) -- oscillates 17.5–20.5, rounded
        self.timerLabel.TextSize = size
    end)
end

function GameView:_stopTimerPulse()
    if not self.timerPulsing then return end
    self.timerPulsing = false
    if self.timerPulseConn then
        self.timerPulseConn:Disconnect()
        self.timerPulseConn = nil
    end
    if not self.destroyed and self.timerLabel.Parent then
        self.timerLabel.TextSize = 19
    end
end
```

**Wire into the existing timer update block** (find the lines around `self.timerLabel.Text = string.format(...)` at line ~3824):

```lua
-- existing:
local seconds = math.max(0, math.ceil(readNumber(round, "phaseEndsAt", 0) - Workspace:GetServerTimeNow()))
self.timerLabel.Text = string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
if seconds <= 10 and seconds > 0 then
    self.timerLabel.TextColor3 = Theme.Colors.DangerBright
    self:_startTimerPulse()   -- ADD THIS LINE
else
    self.timerLabel.TextColor3 = Theme.Colors.Gold
    self:_stopTimerPulse()    -- ADD THIS LINE
end
```

Note: only two lines are added; the rest of the block is unchanged.

---

### A3. Reconnect Overlay — Enhanced `PrepareReconnectSnapshot`

**Change signature** of `PrepareReconnectSnapshot` to accept `phaseName: string`:

```lua
function GameView:PrepareReconnectSnapshot(phaseName: string)
```

Keep the existing two lines inside intact:

```lua
self.notebook:SetAttribute("SuppressNextStagger", true)
Motion.Cancel(self.evidenceList)
```

**After those two lines**, add the reconnect overlay:

```lua
-- Brief "returning to camp" overlay for mid-round rejoins.
if phaseName == "Lobby" or phaseName == "Rewards" then return end
local reconnectOverlay = Instance.new("CanvasGroup")
reconnectOverlay.Name = "ReconnectOverlay"
reconnectOverlay.Size = UDim2.fromScale(1, 1)
reconnectOverlay.BackgroundColor3 = Color3.fromRGB(8, 10, 12)
reconnectOverlay.BackgroundTransparency = 0
reconnectOverlay.GroupTransparency = 0
reconnectOverlay.BorderSizePixel = 0
reconnectOverlay.Active = false
reconnectOverlay.ZIndex = 90
reconnectOverlay.Parent = self.root

local phaseDisplayMap: { [string]: string } = {
    RoleReveal = "ROLE REVEAL",
    Day = "DAY PHASE",
    MurderPlanning = "NIGHT PLANNING",
    NightTransform = "NIGHT FALLS",
    Investigation = "NIGHT INVESTIGATION",
    Campfire = "CAMPFIRE VOTE",
    Resolution = "MYSTERY RESOLVED",
}
local phaseDisplay = phaseDisplayMap[phaseName] or string.upper(phaseName)

local reconnectLabel = Components.Label(reconnectOverlay, "ReconnectLabel",
    "RETURNING TO CAMP", 28, Enum.Font.GothamBold)
reconnectLabel.AnchorPoint = Vector2.new(0.5, 0.5)
reconnectLabel.Position = UDim2.fromScale(0.5, 0.46)
reconnectLabel.Size = UDim2.new(1, -48, 0, 44)
reconnectLabel.TextColor3 = Theme.Colors.White
reconnectLabel.TextXAlignment = Enum.TextXAlignment.Center
reconnectLabel.ZIndex = 91

local phaseLabel = Components.Label(reconnectOverlay, "PhaseLabel",
    phaseDisplay, 14, Enum.Font.Gotham)
phaseLabel.AnchorPoint = Vector2.new(0.5, 0)
phaseLabel.Position = UDim2.fromScale(0.5, 0.54)
phaseLabel.Size = UDim2.new(1, -48, 0, 22)
phaseLabel.TextColor3 = Theme.Colors.Gold
phaseLabel.TextTransparency = 0.2
phaseLabel.TextXAlignment = Enum.TextXAlignment.Center
phaseLabel.ZIndex = 91

task.delay(1.5, function()
    if self.destroyed or reconnectOverlay.Parent == nil then return end
    local fade = TweenService:Create(reconnectOverlay,
        TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        { GroupTransparency = 1 })
    fade.Completed:Connect(function()
        if reconnectOverlay.Parent then reconnectOverlay:Destroy() end
    end)
    fade:Play()
end)
```

---

### A4. Murderer Objective Text During MurderPlanning

In the existing phase-to-objective-text mapping (around line 3836–3854), find the `else` branch that catches unspecified phases and add a Murderer-specific branch BEFORE the generic else:

```lua
-- existing:
elseif phase == "Campfire" then
    -- ... campfire logic ...
else
    self.progressLabel.Text = readString(...)
    ...
```

Insert between the `elseif phase == "Campfire"` block and the `else`:

```lua
elseif phase == "MurderPlanning" then
    local localRole = if type(player) == "table" and type(player.role) == "string"
        then player.role
        else ""
    if localRole == "Murderer" then
        self.progressLabel.Text = "Plan your attack before night falls."
        self.objectiveText.Text = "MURDERER OBJECTIVE\nEliminate your target. Frame the evidence."
        self.objectiveFill.Size = UDim2.fromScale(1, 1)
    else
        self.progressLabel.Text = "Night is coming. Prepare your tools."
        self.objectiveText.Text = "MURDERER OBJECTIVE\nWait for darkness. Review your equipment."
        self.objectiveFill.Size = UDim2.fromScale(0, 1)
    end
```

Note: `player` is already in scope in the `refresh()` call — it comes from `state.player`. Verify the variable name in the existing else branch and use the same name.

---

## Agent B — `src/client/Controllers/RoundController.lua`

Two targeted changes only.

### B1. Call `PlayRoundSummary` When Entering Resolution

Find the existing block (around line 480):

```lua
if phaseName == "Resolution" and currentView then
    playVoteReveal(snapshot, currentView, revealWinner)
    winnerQueuedAfterVote = revealWinner ~= nil
end
```

After the `playVoteReveal` call (inside the same `if` block), add the round summary call:

```lua
if not reconnect then
    local round = if type(snapshot) == "table" and type(snapshot.round) == "table"
        then snapshot.round else nil
    local participants = if type(snapshot) == "table" and type(snapshot.participants) == "table"
        then snapshot.participants else {}
    local player = if type(snapshot) == "table" then snapshot.player else nil

    local survivorCount = 0
    for _, p in participants do
        if type(p) == "table" and p.alive == true then
            survivorCount += 1
        end
    end

    local personalEvidence = 0
    if type(player) == "table"
        and type(player.evidenceKnowledge) == "table"
    then
        for _ in player.evidenceKnowledge do
            personalEvidence += 1
        end
    end

    local stats = {
        roundNumber       = if type(round) == "table" and type(round.roundNumber) == "number" then round.roundNumber else 0,
        winner            = if type(round) == "table" and type(round.winner) == "string" then round.winner else "",
        isHumanWin        = type(round) == "table" and round.winner == "Campers",
        evidenceFound     = if type(round) == "table" and type(round.evidenceFound) == "number" then round.evidenceFound else 0,
        evidenceGoal      = if type(round) == "table" and type(round.evidenceGoal) == "number" then math.max(1, round.evidenceGoal) else 1,
        objectivesCompleted = if type(round) == "table" and type(round.objectivesCompleted) == "number" then round.objectivesCompleted else 0,
        objectiveGoal     = if type(round) == "table" and type(round.objectiveGoal) == "number" then math.max(1, round.objectiveGoal) else 1,
        survivorCount     = survivorCount,
        totalParticipants = #participants,
        monsterId         = if type(round) == "table" and type(round.monsterId) == "string" then round.monsterId else nil,
        victimName        = if type(round) == "table" and type(round.victimName) == "string" then round.victimName else nil,
        personalEvidence  = personalEvidence,
        playerRole        = if type(player) == "table" and type(player.role) == "string" then player.role else "Camper",
    }
    currentView:PlayRoundSummary(stats)
end
```

### B2. Pass Phase Name to `PrepareReconnectSnapshot`

Find the existing call (around line 715):

```lua
gameView:PrepareReconnectSnapshot()
```

Change to:

```lua
local reconnectPhase = if type(payload) == "table"
    and type(payload.round) == "table"
    and type(payload.round.phase) == "string"
    then payload.round.phase
    else "Lobby"
gameView:PrepareReconnectSnapshot(reconnectPhase)
```

---

## Agent C — `src/client/UI/EffectsView.lua`

Add one new public method: `FlashEvidenceFound()`.

### C1. `FlashEvidenceFound()`

Add after `SetMonsterMode` (around line 485):

```lua
function EffectsView:FlashEvidenceFound()
    if self.destroyed then return end
    -- Full-screen gold flash — brief, non-blocking.
    local flash = Instance.new("CanvasGroup")
    flash.Name = "EvidenceFlash"
    flash.Size = UDim2.fromScale(1, 1)
    flash.BackgroundColor3 = Color3.fromRGB(220, 176, 60)
    flash.BackgroundTransparency = 0
    flash.GroupTransparency = 0.72  -- start at 28% visible
    flash.BorderSizePixel = 0
    flash.Active = false
    flash.ZIndex = 75
    flash.Parent = self.root

    local fadeOut = TweenService:Create(flash,
        TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { GroupTransparency = 1 })
    fadeOut.Completed:Connect(function()
        if flash.Parent then flash:Destroy() end
    end)
    fadeOut:Play()
end
```

**Important:** `EffectsView` uses `TweenService` already — check the existing requires at the top and use the same reference. If it's called `TweenService` already, use that name. If not, add `local TweenService = game:GetService("TweenService")` in the local services block alongside existing ones (do not duplicate).

**Wire it in RoundController.lua**: In the block that fires `PlayEvidenceDiscovery` (find the evidenceFound counter check, around line 328–342), call `currentEffects:FlashEvidenceFound()` immediately BEFORE or AFTER `currentView:PlayEvidenceDiscovery(...)`. This is a one-line addition.

> **Note to Agent C:** You only edit `EffectsView.lua`. The RoundController wiring is included here for completeness — Agent B handles that file. If Agent B's task already includes the wiring, skip the RoundController edit. If Agent B's spec doesn't mention it, add it yourself. CHECK AGENT B'S SPEC ABOVE — it does not include this wiring. So **Agent C must also edit `RoundController.lua`** to add this single line. This is Agent C's only change to RoundController.

Actually — re-reading: Agent B's scope already touches RoundController. To avoid merge conflicts, include the `FlashEvidenceFound` wiring in **Agent B's** work scope, not Agent C's. Add it to Agent B's section above.

> **Revised Agent B note:** In the block around line 338 (`currentView:PlayEvidenceDiscovery(...)`), ALSO add `currentEffects:FlashEvidenceFound()` on the line before or after the existing PlayEvidenceDiscovery call.

**Agent C only edits `EffectsView.lua`.** No RoundController changes from Agent C.

---

## Agent D — Loading Screen (NEW FILE + project.json)

### D1. New File: `src/client/LoadingScreen.client.lua`

Create this file. It runs under ReplicatedFirst so it fires before any other game code.

```lua
--!strict
-- Branded loading screen for CAMP-Mystery.
-- Runs under ReplicatedFirst before game content loads.

local ReplicatedFirst = game:GetService("ReplicatedFirst")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 15) :: PlayerGui

-- Build the screen
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
screenGui.DisplayOrder = 100
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Name = "Background"
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(8, 10, 12)
bg.BorderSizePixel = 0
bg.Parent = screenGui

-- Top and bottom accent bars
local function accentBar(yAnchor: number)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 3)
    bar.AnchorPoint = Vector2.new(0, yAnchor)
    bar.Position = UDim2.fromScale(0, yAnchor)
    bar.BackgroundColor3 = Color3.fromRGB(210, 160, 50)
    bar.BorderSizePixel = 0
    bar.Parent = bg
end
accentBar(0)
accentBar(1)

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Text = "CAMP MYSTERY"
title.Font = Enum.Font.GothamBold
title.TextSize = 48
title.TextColor3 = Color3.fromRGB(210, 160, 50)
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.44)
title.Size = UDim2.new(1, -48, 0, 64)
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = bg

-- Tagline
local tagline = Instance.new("TextLabel")
tagline.Name = "Tagline"
tagline.Text = "Something lurks at the edge of the firelight."
tagline.Font = Enum.Font.Gotham
tagline.TextSize = 15
tagline.TextColor3 = Color3.fromRGB(180, 180, 190)
tagline.TextTransparency = 0.3
tagline.BackgroundTransparency = 1
tagline.AnchorPoint = Vector2.new(0.5, 0)
tagline.Position = UDim2.fromScale(0.5, 0.53)
tagline.Size = UDim2.new(1, -48, 0, 26)
tagline.TextXAlignment = Enum.TextXAlignment.Center
tagline.Parent = bg

-- Loading dots (animated)
local loadingLabel = Instance.new("TextLabel")
loadingLabel.Name = "LoadingLabel"
loadingLabel.Text = "Loading camp"
loadingLabel.Font = Enum.Font.Gotham
loadingLabel.TextSize = 13
loadingLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
loadingLabel.BackgroundTransparency = 1
loadingLabel.AnchorPoint = Vector2.new(0.5, 0)
loadingLabel.Position = UDim2.fromScale(0.5, 0.72)
loadingLabel.Size = UDim2.new(0, 200, 0, 22)
loadingLabel.TextXAlignment = Enum.TextXAlignment.Center
loadingLabel.Parent = bg

-- Animated dots loop
local dotCount = 0
local dotsRunning = true
task.spawn(function()
    while dotsRunning do
        dotCount = (dotCount % 3) + 1
        loadingLabel.Text = "Loading camp" .. string.rep(".", dotCount)
        task.wait(0.45)
    end
end)

-- Wait for content to load (with fallback timeout)
if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(0.3)  -- brief pause so the screen doesn't flash

dotsRunning = false
loadingLabel.Text = "Ready."

-- Fade out and destroy
local fade = TweenService:Create(bg,
    TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
    { BackgroundTransparency = 1 })

-- Fade child labels too
for _, child in bg:GetChildren() do
    if child:IsA("TextLabel") then
        TweenService:Create(child,
            TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
            { TextTransparency = 1 }):Play()
    elseif child:IsA("Frame") and child.Name ~= "Background" then
        TweenService:Create(child,
            TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
            { BackgroundTransparency = 1 }):Play()
    end
end

fade.Completed:Connect(function()
    screenGui:Destroy()
end)
fade:Play()
```

### D2. Update `default.project.json`

Add `ReplicatedFirst` to the project tree. Open `default.project.json` and add inside the `"tree"` object (alongside the existing `"StarterGui"`, `"StarterPlayer"` etc.):

```json
"ReplicatedFirst": {
    "$className": "ReplicatedFirst",
    "LoadingScreen": {
        "$path": "src/client/LoadingScreen.client.lua"
    }
}
```

---

## Acceptance Criteria

- [ ] `PlayRoundSummary` appears after the win reveal (~2.7s delay), shows correct stats, has dismiss button and 8s countdown
- [ ] Summary overlay destroys cleanly when parent is destroyed
- [ ] Timer label pulses (oscillates TextSize ~19–22) when seconds <= 10
- [ ] Pulse stops and TextSize resets to 19 when seconds > 10 or phase changes
- [ ] `PrepareReconnectSnapshot` now accepts `phaseName` and shows brief "RETURNING TO CAMP" overlay that fades out after 1.5s
- [ ] Overlay skipped for Lobby and Rewards phases
- [ ] MurderPlanning phase shows Murderer-specific objective text for Murderer role, generic "night comes" text for others
- [ ] Evidence discovery triggers a gold flash overlay (< 1s, auto-destroys)
- [ ] Loading screen shows before game content loads, fades out once loaded
- [ ] `default.project.json` maps `ReplicatedFirst.LoadingScreen` to the new file
- [ ] `scripts/run_all_checks.py --require-rojo` passes (82 strict Luau files now, Rojo builds cleanly)
- [ ] No `readBoolean` calls — use `value == true` pattern
- [ ] No `tick()` — use `Workspace:GetServerTimeNow()` or `os.clock()` for client-only timing
- [ ] All new CanvasGroups have `Active = false` unless they need to block input (the summary card needs `Active = true` on the overlay to block clicks through to the game world)

---

## File Summary

| File | Status | Agent |
|------|--------|-------|
| `src/client/UI/GameView.lua` | Modified | A |
| `src/client/Controllers/RoundController.lua` | Modified | B |
| `src/client/UI/EffectsView.lua` | Modified | C |
| `src/client/LoadingScreen.client.lua` | New | D |
| `default.project.json` | Modified | D |
