# Claude_Request-0011 — Cooldown Fix + Haptic Feedback + Timer Bar + Evidence Badge

## Context

Request 0010 delivered counselor topic picker, dialogue panel, XP count-up, and volume immediacy.
One blocker emerged: `ParticipantService:SerializePrivate()` does **not** include `abilityCooldownEndsAt`,
so the cooldown countdown UI (already implemented in `GameView:Tick()`) receives no data.

This request fixes that blocker and adds three parallel UX improvements across non-conflicting files.

---

## Parallel Execution Model

**Spawn one agent per task below.** No agent touches a file owned by another agent.
Wave 1 agents may run simultaneously. Wave 2 agents may start only after both Wave 1 commits land.

---

## Wave 1 — Independent files (run both simultaneously)

---

### Agent 1 — `src/server/Services/ParticipantService.lua`

**Task: Add `abilityCooldownEndsAt` to `SerializePrivate()`**

**Context:**
- `ParticipantService:SerializePrivate()` is at line ~367.
- Its return table (lines ~383–404) already includes `alive`, `healthState`, `injuryLevel`, `inventoryIds`, `evidenceKnowledge`, `vote` — but NOT `abilityCooldownEndsAt`.
- The internal state field `state.abilityCooldownEndsAt` is a `{ [string]: number }` dict initialized at line ~70, 140, 193.
- The shared type `PrivateParticipantSnapshot` (in `src/shared/Types/ParticipantTypes.lua`) already declares `abilityCooldownEndsAt: { [string]: number }` at line 79 — so no type change is needed.
- The client-side `GameView:Tick()` already reads `currentState.player.abilityCooldownEndsAt` and computes a countdown, but renders nothing because the field is always absent from the snapshot.

**Change (one line):**
In the `return { ... }` block of `SerializePrivate()`, add after `vote = cloneVote(state),`:

```lua
abilityCooldownEndsAt = table.clone(state.abilityCooldownEndsAt),
```

**Verify:** After the change, `SerializePrivate()` must include the `abilityCooldownEndsAt` key.
Run `python scripts/run_all_checks.py --require-rojo` and confirm the gate passes.

---

### Agent 2 — NEW `src/client/Controllers/HapticController.lua`

**Task: Create a haptic feedback module for controller/mobile rumble**

Create `src/client/Controllers/HapticController.lua` with the following interface and behavior.

**File contents:**

```lua
--!strict

local HapticService = game:GetService("HapticService")
local UserInputService = game:GetService("UserInputService")

local INPUT_TYPE = Enum.UserInputType.Gamepad1
local MOTOR_SMALL = Enum.VibrationMotor.Small
local MOTOR_LARGE = Enum.VibrationMotor.Large

local function isSupported(motor: Enum.VibrationMotor): boolean
	local ok, result = pcall(function()
		return HapticService:IsMotorSupported(INPUT_TYPE, motor)
	end)
	return ok and result == true
end

local function vibrate(motor: Enum.VibrationMotor, amplitude: number, duration: number)
	if not isSupported(motor) then
		return
	end
	pcall(function()
		HapticService:SetMotor(INPUT_TYPE, motor, amplitude)
	end)
	task.delay(duration, function()
		pcall(function()
			HapticService:SetMotor(INPUT_TYPE, motor, 0)
		end)
	end)
end

local HapticController = {}

-- Short, light tap — UI confirmation, notebook open/close, button press
function HapticController.Click()
	vibrate(MOTOR_SMALL, 0.35, 0.06)
end

-- Medium bump — action accepted, item equipped
function HapticController.Impact()
	vibrate(MOTOR_SMALL, 0.6, 0.1)
	vibrate(MOTOR_LARGE, 0.4, 0.08)
end

-- Strong rumble — injury, danger
function HapticController.Danger()
	vibrate(MOTOR_LARGE, 0.85, 0.22)
	vibrate(MOTOR_SMALL, 0.5, 0.18)
end

-- Double-pulse — win reveal / celebration
function HapticController.Celebrate()
	vibrate(MOTOR_LARGE, 0.7, 0.12)
	task.delay(0.18, function()
		vibrate(MOTOR_LARGE, 0.5, 0.1)
	end)
end

-- Sharp error buzz — action rejected
function HapticController.Error()
	vibrate(MOTOR_SMALL, 0.9, 0.08)
	task.delay(0.12, function()
		vibrate(MOTOR_SMALL, 0.7, 0.06)
	end)
end

return HapticController
```

**Notes:**
- All `HapticService` calls are wrapped in `pcall` — silently no-ops on PC and unsupported platforms.
- No `UserInputService` usage beyond the constant — it is retained in case a platform check is needed later.
- Rojo maps `src/client/Controllers/` → `StarterPlayerScripts.Controllers` automatically — no `project.json` change needed.
- Run `python scripts/run_all_checks.py --require-rojo` and confirm the gate passes.

---

## Wave 2 — Depends on Wave 1 (start after both Wave 1 commits are on `main`)

---

### Agent 3 — `src/client/UI/GameView.lua`

**Task: Phase timer progress bar + evidence badge on notebook button + haptic integration**

This agent makes three focused additions to `GameView.lua`. Each is independent of the others within the file.
Make all three changes in a single commit.

---

#### 3a — Phase timer progress bar

**Goal:** A thin horizontal bar under the phase timer label that fills left-to-right as the phase progresses,
changing color as time runs low (Gold → Amber → Danger).

**New state fields** (add to the `GameViewState` type block and to the `return { ... }` initializer inside `GameView.new()`):

```lua
timerBar: Frame?,
timerFill: Frame?,
```

Initialize both to `nil`.

**Build the bar** (in `GameView.new()`, immediately after the `timerLabel` is created at line ~471):

```lua
local timerBar = Instance.new("Frame")
timerBar.Name = "TimerBar"
timerBar.Size = UDim2.new(1, -36, 0, 5)
timerBar.Position = UDim2.fromOffset(18, 43)
timerBar.BackgroundColor3 = Theme.Colors.PanelSoft
timerBar.BackgroundTransparency = 0.3
timerBar.BorderSizePixel = 0
timerBar.Parent = top

local timerFill = Instance.new("Frame")
timerFill.Name = "TimerFill"
timerFill.Size = UDim2.fromScale(1, 1)
timerFill.BackgroundColor3 = Theme.Colors.Gold
timerFill.BorderSizePixel = 0
timerFill.Parent = timerBar
Components.Corner(timerBar, 3)
Components.Corner(timerFill, 3)
```

Store in state: `timerBar = timerBar, timerFill = timerFill,`

**Update in `Tick()`** — in the existing timer block (near line ~2964), add after setting `self.timerLabel.Text`:

```lua
-- Phase timer progress bar
if self.timerFill then
    local phaseStartedAt = readNumber(round, "phaseStartedAt", 0)
    local phaseEndsAt = readNumber(round, "phaseEndsAt", 0)
    local phaseDuration = phaseEndsAt - phaseStartedAt
    local fraction: number
    if phaseDuration > 0 then
        fraction = math.clamp((Workspace:GetServerTimeNow() - phaseStartedAt) / phaseDuration, 0, 1)
    else
        fraction = 0
    end
    self.timerFill.Size = UDim2.fromScale(fraction, 1)
    if seconds <= 10 and seconds > 0 then
        self.timerFill.BackgroundColor3 = Theme.Colors.DangerBright
    elseif seconds <= 30 then
        self.timerFill.BackgroundColor3 = Theme.Colors.Amber
    else
        self.timerFill.BackgroundColor3 = Theme.Colors.Gold
    end
end
```

Note: `Theme.Colors.Amber` may or may not exist — check `src/client/UI/Theme.lua` first.
If absent, substitute `Color3.fromHex("#E07830")`.

---

#### 3b — Evidence badge on notebook button

**Goal:** A small circular badge on the "CLUES [N]" notebook button that shows how many new evidence items
have been discovered since the notebook was last opened.

**New state fields:**

```lua
notebookBadge: TextLabel?,
lastSeenEvidenceCount: number,
```

Initialize `lastSeenEvidenceCount = 0`.

**Build the badge** (in `GameView.new()`, immediately after `notebookButton` is created at line ~748):

```lua
-- Badge for new evidence — built immediately after notebookButton
local notebookBadge = Components.Label(
    self.notebookButton :: Instance,
    "EvidenceBadge",
    "0",
    10,
    Enum.Font.GothamBold
)
notebookBadge.AnchorPoint = Vector2.new(1, 0)
notebookBadge.Position = UDim2.new(1, 4, 0, -4)
notebookBadge.Size = UDim2.fromOffset(20, 20)
notebookBadge.BackgroundColor3 = Theme.Colors.DangerBright
notebookBadge.BackgroundTransparency = 0
notebookBadge.TextColor3 = Color3.new(1, 1, 1)
notebookBadge.TextXAlignment = Enum.TextXAlignment.Center
notebookBadge.ZIndex = (self.notebookButton :: Instance).ZIndex + 1
notebookBadge.Visible = false
Components.Corner(notebookBadge, 10)
self.notebookBadge = notebookBadge
```

**Update in `ToggleNotebook()`** — when opening the notebook, clear the badge:

```lua
function GameView:ToggleNotebook()
    setModalVisible(self.settings, false)
    setModalVisible(self.progression, false)
    local willOpen = not modalTargetVisible(self.notebook)
    setModalVisible(self.notebook, willOpen)
    if willOpen then
        -- Notebook opened: mark all current evidence as seen
        local cs = self.currentState
        local player = if type(cs) == "table" then cs.player else nil
        local evidenceList = if type(player) == "table" and type(player.evidenceKnowledge) == "table"
            then player.evidenceKnowledge
            else {}
        self.lastSeenEvidenceCount = #evidenceList
        if self.notebookBadge then
            self.notebookBadge.Visible = false
        end
    end
end
```

**Update in `Tick()`** — after the existing player evidence/cooldown block, add:

```lua
-- Evidence badge
if self.notebookBadge then
    local evidence = if type(player) == "table" and type(player.evidenceKnowledge) == "table"
        then player.evidenceKnowledge
        else {}
    local newCount = math.max(0, #evidence - self.lastSeenEvidenceCount)
    if newCount > 0 and not modalTargetVisible(self.notebook) then
        self.notebookBadge.Text = tostring(math.min(newCount, 9))
        self.notebookBadge.Visible = true
    else
        self.notebookBadge.Visible = false
    end
end
```

---

#### 3c — Haptic integration in GameView

At the top of `GameView.lua`, add after the existing `require` block:

```lua
local HapticController = require(script.Parent.Parent.Controllers.HapticController)
```

(Adjust path if Controllers is not at `script.Parent.Parent.Controllers` — verify against how AudioController is required.)

In **`HandleActionResult(accepted)`**:
- On `true`: add `HapticController.Impact()` before `Motion.PopIn(...)`.
- On `false`: add `HapticController.Error()` before `Motion.Shake(...)`.

In **`ToggleNotebook()`**: add `HapticController.Click()` immediately when `willOpen` is true.

**Run the gate:** `python scripts/run_all_checks.py --require-rojo`. Must pass.

---

### Agent 4 — `src/client/Controllers/RoundController.lua`

**Task: Wire HapticController for win reveal and action results**

#### 4a — Require HapticController

At the top of `RoundController.lua`, after the existing `require` statements, add:

```lua
local HapticController = require(script.Parent.HapticController)
```

(Verify the path is consistent with how `AudioController` is required — they should be siblings in the same `Controllers` folder.)

#### 4b — Win reveal celebration haptic

The `revealWinner` closure is created and called in the `handleStateUpdate` function.
Find the line where `PlayWinReveal` is called (or where `currentView:PlayWinReveal(...)` is invoked
after the 0.9s delay). Add `HapticController.Celebrate()` immediately before the `PlayWinReveal` call:

```lua
HapticController.Celebrate()
currentView:PlayWinReveal(winner, isHumanWin)
```

#### 4c — Danger haptic on critical injury

In `handleActionResult` (line ~356), in the `accepted = true` branch, after `currentView:HandleActionResult(true)`,
check if the incoming state indicates the player's healthState changed to "Critical" or "Incapacitated":

```lua
if type(result.state) == "table" then
    local pSnap = result.state.player
    if type(pSnap) == "table" and (pSnap.healthState == "Critical" or pSnap.healthState == "Incapacitated") then
        HapticController.Danger()
    end
end
```

Place this block **after** the existing `state = result.state; refresh()` lines, not before.

**Run the gate:** `python scripts/run_all_checks.py --require-rojo`. Must pass with 77 Luau files.

---

## Definition of Done for Request 0011

- [ ] `ParticipantService:SerializePrivate()` return table includes `abilityCooldownEndsAt`
- [ ] `src/client/Controllers/HapticController.lua` exists with Click / Impact / Danger / Celebrate / Error
- [ ] GameView phase timer bar builds without error and animates in Tick (Gold → Amber → Danger)
- [ ] Notebook button shows badge (red circle + count) when unread evidence exists; badge clears on open
- [ ] HapticController is called from GameView (HandleActionResult accept/reject, notebook open)
- [ ] HapticController is called from RoundController (win reveal, critical health)
- [ ] All 4 commits reference the agent number (e.g. `[Agent 1]`, `[Agent 3]`)
- [ ] Gate: `python scripts/run_all_checks.py --require-rojo` passes (77 files) after each wave
- [ ] Reply in `ClaudChat/ChatToClaude/Chat_Request-0011-cooldown-fix-haptics-timer-badge.md`

## Pending for a future request (do not include here)

- `Theme.Colors.Amber` — if it does not exist, use the hex fallback above and flag it in your reply
- Studio playtesting for timer bar sizing, badge positioning, and haptic intensities
