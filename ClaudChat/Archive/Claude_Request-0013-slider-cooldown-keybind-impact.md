# Claude_Request-0013 — Settings Sliders + Cooldown Bar + Keybind Hints + Impact Flash

## Context

Baseline after 0012: **79 strict Luau files**, 834,682 bytes.

Key adaptations confirmed in 0012:
- `Motion.FadeIn`/`FadeOut` on `CanvasGroup` requires no `property` field — Motion auto-discovers `GroupTransparency`
- Health-related state is calculated in `GameView:Update()`, not `Tick()`
- `deathCinematicOverlay` is typed `CanvasGroup?`, not `Frame?`

This request upgrades four independent systems, no file conflicts across agents.

---

## Parallel Execution Model

4 agents, 2 waves. Each agent owns exactly one file.

---

## Wave 1 — New file (no dependencies)

### Agent 1 — NEW `src/shared/Config/KeybindHints.lua`

Create with this exact content:

```lua
--!strict

export type KeybindHints = {
	keyboard: { string },
	controller: { string },
}

local HINTS: { [string]: KeybindHints } = {
	Day = {
		keyboard   = { "E  Interact", "N  Notebook", "Tab  Map", "F  Equip item" },
		controller = { "A  Interact", "Y  Notebook", "View  Map", "X  Equip item" },
	},
	Investigation = {
		keyboard   = { "E  Interact", "N  Notebook", "Q  Role ability", "Tab  Map" },
		controller = { "A  Interact", "Y  Notebook", "LB  Role ability", "View  Map" },
	},
	Campfire = {
		keyboard   = { "E  Vote", "N  Evidence notebook" },
		controller = { "A  Vote", "Y  Evidence notebook" },
	},
}

return table.freeze(HINTS)
```

Rojo maps `src/shared/Config/` → `ReplicatedStorage.Shared.Config` automatically.
Run gate: `python scripts/run_all_checks.py --require-rojo`. Expect **80 strict Luau files**.

---

## Wave 2 — Three agents in parallel (start after Wave 1 commit)

---

### Agent 2 — `src/client/UI/GameView.lua`

Three separate additions in a single commit. Read the full file (145 KB) before editing.

---

#### 2a — Settings sliders (replace +/− buttons for numeric rows)

In `_settingRow`, find the `else` branch that creates the `minus`/`plus` buttons and the `display` label. Replace the entire `else` branch body with a drag slider:

```lua
else
    local minValue = minimum or 0
    local maxValue = maximum or 1
    local currentValue = math.clamp(tonumber(self.settingsValues[key]) or 1, minValue, maxValue)
    local initialFraction = if maxValue > minValue
        then (currentValue - minValue) / (maxValue - minValue)
        else 0

    -- Track frame (background)
    local sliderTrack = Instance.new("Frame")
    sliderTrack.Name = "SliderTrack"
    sliderTrack.Size = UDim2.fromOffset(150, 8)
    sliderTrack.Position = UDim2.new(1, -178, 0.5, -4)
    sliderTrack.BackgroundColor3 = Theme.Colors.PanelSoft
    sliderTrack.BorderSizePixel = 0
    sliderTrack.Parent = row
    Components.Corner(sliderTrack, 4)

    -- Fill frame (left portion)
    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "SliderFill"
    sliderFill.Size = UDim2.fromScale(initialFraction, 1)
    sliderFill.BackgroundColor3 = Theme.Colors.Gold
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderTrack
    Components.Corner(sliderFill, 4)

    -- Thumb (circle at right edge of fill)
    local sliderThumb = Instance.new("Frame")
    sliderThumb.Name = "SliderThumb"
    sliderThumb.Size = UDim2.fromOffset(18, 18)
    sliderThumb.AnchorPoint = Vector2.new(0.5, 0.5)
    sliderThumb.Position = UDim2.new(initialFraction, 0, 0.5, 0)
    sliderThumb.BackgroundColor3 = Theme.Colors.White
    sliderThumb.BorderSizePixel = 0
    sliderThumb.ZIndex = sliderTrack.ZIndex + 1
    sliderThumb.Parent = sliderTrack
    Components.Corner(sliderThumb, 9)

    -- Compact value readout to the right
    local valueLabel = Components.Label(row, "Value", string.format("%.1f", currentValue), 12, Enum.Font.GothamBold)
    valueLabel.AnchorPoint = Vector2.new(1, 0.5)
    valueLabel.Position = UDim2.new(1, -12, 0.5, 0)
    valueLabel.Size = UDim2.fromOffset(22, 20)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right

    -- Drag logic — updates visuals immediately; commits value on release
    local dragging = false
    local function fractionAt(inputX: number): number
        local trackX = sliderTrack.AbsolutePosition.X
        local trackW = sliderTrack.AbsoluteSize.X
        return if trackW > 0 then math.clamp((inputX - trackX) / trackW, 0, 1) else 0
    end
    local function applyFraction(f: number)
        sliderFill.Size = UDim2.fromScale(f, 1)
        sliderThumb.Position = UDim2.new(f, 0, 0.5, 0)
        local v = minValue + f * (maxValue - minValue)
        valueLabel.Text = string.format("%.1f", v)
    end

    sliderTrack.InputBegan:Connect(function(input: InputObject)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            dragging = true
            applyFraction(fractionAt(input.Position.X))
        end
    end)
    sliderTrack.InputChanged:Connect(function(input: InputObject)
        local t = input.UserInputType
        if dragging and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) then
            applyFraction(fractionAt(input.Position.X))
        end
    end)
    sliderTrack.InputEnded:Connect(function(input: InputObject)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            dragging = false
            local finalFraction = fractionAt(input.Position.X)
            applyFraction(finalFraction)
            local rawValue = minValue + finalFraction * (maxValue - minValue)
            self:_setSetting(key, math.round(rawValue * 10) / 10)
        end
    end)
end
```

Note: `_setSetting` calls `_rebuildSettings()` which destroys and recreates rows — the drag connections on the old row clean up automatically when the row instance is destroyed.

---

#### 2b — Ability cooldown progress bar below the role action button

**New state fields** — add to the `GameViewState` type and to the `return { ... }` initializer:

```lua
cooldownBar: Frame?,
cooldownFill: Frame?,
abilityBarMaxCooldown: number,
```

Initialize `cooldownBar = nil`, `cooldownFill = nil`, `abilityBarMaxCooldown = 0`.

**Build the bar** in `GameView.new()`, after the `roleAction` button is created (line ~566):

```lua
-- Thin cooldown bar below the role action button
local cooldownBar = Instance.new("Frame")
cooldownBar.Name = "AbilityCooldownBar"
cooldownBar.Size = UDim2.new(1, -32, 0, 4)
cooldownBar.Position = UDim2.fromOffset(16, 298)
cooldownBar.BackgroundColor3 = Theme.Colors.PanelSoft
cooldownBar.BackgroundTransparency = 0.3
cooldownBar.BorderSizePixel = 0
cooldownBar.Visible = false
cooldownBar.Parent = mission

local cooldownFill = Instance.new("Frame")
cooldownFill.Name = "CooldownFill"
cooldownFill.Size = UDim2.fromScale(0, 1)
cooldownFill.BackgroundColor3 = Theme.Colors.Gold
cooldownFill.BorderSizePixel = 0
cooldownFill.Parent = cooldownBar
Components.Corner(cooldownBar, 2)
Components.Corner(cooldownFill, 2)
```

Store in state: `cooldownBar = cooldownBar, cooldownFill = cooldownFill`.

**Update in `Update()` / wherever cooldown text is computed** — after the existing cooldown text block (near line ~3302):

```lua
-- Ability cooldown progress bar
if self.cooldownBar and self.cooldownFill then
    if minimumRemaining < math.huge then
        if self.abilityBarMaxCooldown == 0 then
            self.abilityBarMaxCooldown = minimumRemaining
        end
        local fraction = math.clamp(
            1 - minimumRemaining / self.abilityBarMaxCooldown,
            0,
            1
        )
        self.cooldownFill.Size = UDim2.fromScale(fraction, 1)
        self.cooldownFill.BackgroundColor3 = if minimumRemaining <= 5
            then Theme.Colors.Success
            else Theme.Colors.Gold
        self.cooldownBar.Visible = true
    else
        self.abilityBarMaxCooldown = 0
        self.cooldownBar.Visible = false
    end
end
```

`minimumRemaining` is the local variable already computed in the cooldown block; `math.huge` means no active cooldown.

Also destroy the bar cleanly in the `Destroy()` / cleanup path.

---

#### 2c — `ShowKeybindHint(phaseName)` method

**New `require`** (add with other Config requires at top):

```lua
local KeybindHints = require(Shared:WaitForChild("Config"):WaitForChild("KeybindHints"))
```

**New state fields:**

```lua
keybindHintToken: number,
keybindHintOverlay: Frame?,
```

Initialize: `keybindHintToken = 0`, `keybindHintOverlay = nil`.

**New method** (add near other notification/overlay methods):

```lua
function GameView:ShowKeybindHint(phaseName: string)
    if self.destroyed then
        return
    end
    local entry = KeybindHints[phaseName]
    if not entry then
        return
    end
    -- Determine platform: check if a gamepad is connected
    local UserInputService = game:GetService("UserInputService")
    local hints = if UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1)
        then entry.controller
        else entry.keyboard

    -- Cancel previous
    self.keybindHintToken += 1
    local token = self.keybindHintToken
    local prev = self.keybindHintOverlay
    if prev then
        prev:Destroy()
        self.keybindHintOverlay = nil
    end

    if Motion.IsReducedMotion(self.root) then
        return
    end

    local panel = Instance.new("Frame")
    panel.Name = "KeybindHintPanel"
    panel.AnchorPoint = Vector2.new(0.5, 1)
    panel.Position = UDim2.new(0.5, 0, 1, -90)
    panel.Size = UDim2.fromOffset(320, 28 + 22 * #hints)
    panel.BackgroundColor3 = Theme.Colors.Black
    panel.BackgroundTransparency = 0.35
    panel.BorderSizePixel = 0
    panel.ZIndex = 50
    panel.GroupTransparency = 1
    panel.Parent = self.root
    self.keybindHintOverlay = panel
    Components.Corner(panel, 6)

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 2)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.Parent = panel

    for _, hint in hints do
        local row = Components.Label(panel, "HintRow_" .. hint, hint, 12, Enum.Font.Gotham)
        row.Size = UDim2.new(1, -16, 0, 20)
        row.TextXAlignment = Enum.TextXAlignment.Center
        row.TextColor3 = Theme.Colors.White
        row.TextTransparency = 0.1
        row.ZIndex = 51
    end

    local function active(): boolean
        return not self.destroyed
            and self.keybindHintToken == token
            and panel.Parent ~= nil
    end

    Motion.FadeIn(panel, { duration = 0.3 })
    task.delay(4, function()
        if not active() then return end
        Motion.FadeOut(panel, {
            duration = 0.5,
            onComplete = function()
                if active() then
                    panel:Destroy()
                    if self.keybindHintOverlay == panel then
                        self.keybindHintOverlay = nil
                    end
                end
            end,
        })
    end)
end
```

Also cancel and destroy `keybindHintOverlay` in `Destroy()`.

Note: `panel` uses `GroupTransparency` so it fades correctly. If `Frame` doesn't support `GroupTransparency`, convert it to `CanvasGroup`. Check whether `Motion.FadeIn` on a `Frame` works — if not, use a `CanvasGroup` with `GroupTransparency = 1` as the initial state (same pattern as `PlayDeathCinematic`).

---

### Agent 3 — `src/client/Controllers/RoundController.lua`

**New module-level variables** (add near other `last*` vars):

```lua
local seenHintPhases: { [string]: boolean } = {}
```

**New constant** (top of file, near other constants):

```lua
local HINT_PHASES: { [string]: boolean } = { Day = true, Investigation = true, Campfire = true }
```

**In the phase-change block of `refresh()`** — after `currentView:PlayPhaseTitleCard(phaseName, reconnect)` (line ~323):

```lua
-- Keybind hint on first entry to key phases (not on reconnect)
if HINT_PHASES[phaseName]
    and not seenHintPhases[phaseName]
    and not reconnect
    and currentView
then
    seenHintPhases[phaseName] = true
    currentView:ShowKeybindHint(phaseName)
end
```

**In `Stop()`**, reset:

```lua
table.clear(seenHintPhases)
```

**Danger haptic + impact flash on injury** (in `handleActionResult` accepted branch, after the existing `HapticController.Danger()` block at line ~386):

```lua
-- Impact flash on injury/critical
if type(result.state) == "table" then
    local pSnap = result.state.player
    if type(pSnap) == "table"
        and (pSnap.healthState == "Critical" or pSnap.healthState == "Incapacitated")
    then
        local currentCinematics = cinematics
        if currentCinematics then
            currentCinematics:PlayImpactFlash()
        end
    end
end
```

Note: `cinematics` is the module-level variable holding `CinematicsController`. Confirm it is accessible in the `handleActionResult` closure (it is a module-level variable, so yes).

---

### Agent 4 — `src/client/Controllers/CinematicsController.lua`

#### 4a — Add `PlayImpactFlash()` method

Add as a public method after `SetGhostMode`:

```lua
function CinematicsController:PlayImpactFlash()
    if self.destroyed then
        return
    end
    -- Spike contrast then recover — brief "hit" screen flash
    self:_playTween(self.colorCorrection, 0.07, { Contrast = 0.6 })
    task.delay(0.07, function()
        if not self.destroyed then
            self:_playTween(self.colorCorrection, 0.30, { Contrast = 0 })
        end
    end)
end
```

`colorCorrection.Contrast` is not currently animated by any other system (dread uses `Saturation`; ghost uses `Saturation` and `TintColor`), so this is safe.

The `_playTween` helper adds tweens to `self.activeTweens`; if a phase transition cancels them mid-flash, the flash silently aborts. That is acceptable.

---

## Definition of Done for Request 0013

- [ ] `src/shared/Config/KeybindHints.lua` exists with Day, Investigation, Campfire entries
- [ ] Settings numeric rows show drag sliders instead of +/− buttons; dragging updates fill/thumb live; releasing commits value
- [ ] Ability cooldown bar (4px) is hidden when no cooldown; fills left-to-right as cooldown drains; turns `Success` color in final 5s
- [ ] `GameView:ShowKeybindHint(phaseName)` shows a 4s auto-fading hint panel at bottom-center
- [ ] RoundController triggers `ShowKeybindHint` once per phase per round for Day, Investigation, Campfire (not on reconnect)
- [ ] `seenHintPhases` clears in `Stop()`
- [ ] `CinematicsController:PlayImpactFlash()` exists and is called from `handleActionResult` on injury/critical
- [ ] Gate: `python scripts/run_all_checks.py --require-rojo` passes with **80 strict Luau files**
- [ ] Reply in `ClaudChat/ChatToClaude/Chat_Request-0013-slider-cooldown-keybind-impact.md`

## Notes for ChatGPT

- The `CanvasGroup` vs `Frame` / `GroupTransparency` pattern: only `CanvasGroup` supports `GroupTransparency`. If `ShowKeybindHint` uses a `Frame`, animate `BackgroundTransparency` + child `TextTransparency` in sync, or convert to `CanvasGroup`. Confirmed pattern: `PlayDeathCinematic` uses `CanvasGroup` with `GroupTransparency = 1` initial state — use the same.
- The slider `_setSetting` call triggers `_rebuildSettings()` which destroys the row; connections on old instances auto-disconnect when the instance is destroyed.
- `minimumRemaining` in the cooldown bar update: confirm the variable name matches what's in scope at the point of insertion (the existing cooldown block computes this locally).
- File count: 79 + 1 (KeybindHints.lua) = **80**. Report GameView.lua final byte count in reply.
