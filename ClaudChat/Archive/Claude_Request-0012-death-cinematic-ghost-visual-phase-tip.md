# Claude_Request-0012 — Death Cinematic + Ghost World Visual + Phase Tips + Health Flash

## Context

Baseline after 0011: **78 strict Luau files**, 828,839 bytes.

This request adds four cohesive UX moments:
1. A cinematic overlay when the player dies and becomes a ghost
2. A subtle world-level visual shift (desaturation + blue offset) that persists for the rest of the round in ghost mode
3. A context-appropriate tip line on the phase title card (expanding band height to fit)
4. A brief health-bar damage flash when health decreases

---

## Parallel Execution Model

4 agents, 2 waves. Each agent owns exactly one file. No agent touches a file owned by another.
Wave 2 agents can all run simultaneously after Wave 1 commits.

---

## Wave 1 — New file (no dependencies)

### Agent 1 — NEW `src/shared/Config/PhaseTips.lua`

Create the file with this exact content:

```lua
--!strict

local PhaseTips: { [string]: string } = {
	MurderPlanning = "Stay calm and move with purpose. The monster is choosing its plan.",
	NightTransform  = "Stick to lit paths and keep teammates in sight.",
	Investigation   = "Search methodically — scattered clues form the full picture.",
	Day             = "Complete shared work early; every resource helps after dark.",
	Campfire        = "Base your vote on evidence, not on silence or suspicion alone.",
	Resolution      = "Whatever the outcome, all evidence is revealed at resolution.",
}

return table.freeze(PhaseTips)
```

Rojo maps `src/shared/Config/` → `ReplicatedStorage.Shared.Config` automatically.
Run `python scripts/run_all_checks.py --require-rojo` and confirm 79 strict Luau files (78 + 1 new).

---

## Wave 2 — Three agents running simultaneously (start after Wave 1 commits)

---

### Agent 2 — `src/client/UI/GameView.lua`

Three additions in a single commit. Read the full file before editing.

---

#### 2a — Death cinematic overlay (`PlayDeathCinematic`)

**New state fields** — add to the `GameViewState` type and to the `return { ... }` initializer:

```lua
deathCinematicToken: number,
deathCinematicOverlay: Frame?,
```

Initialize both to `0` / `nil`.

**New method** — add after `PlayWinReveal` or near other cinematic methods:

```lua
function GameView:PlayDeathCinematic()
	if self.destroyed then
		return
	end
	self.deathCinematicToken += 1
	local token = self.deathCinematicToken
	local prev = self.deathCinematicOverlay
	if prev then
		prev:Destroy()
		self.deathCinematicOverlay = nil
	end

	local overlay = Instance.new("CanvasGroup")
	overlay.Name = "DeathCinematic"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = 0
	overlay.GroupTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 92
	overlay.Parent = self.root
	self.deathCinematicOverlay = overlay

	local heading = Components.Label(
		overlay,
		"DeathHeading",
		"YOU HAVE FALLEN",
		math.floor(Theme.Typography.HeadingSize * 1.6),
		Theme.Typography.HeadingFont
	)
	heading.AnchorPoint = Vector2.new(0.5, 0.5)
	heading.Position = UDim2.new(0.5, 0, 0.44, 0)
	heading.Size = UDim2.new(0.9, 0, 0, 56)
	heading.TextColor3 = Theme.Colors.White
	heading.TextXAlignment = Enum.TextXAlignment.Center
	heading.ZIndex = 93
	Components.SetLetterspacedText(heading, "YOU HAVE FALLEN")

	local sub = Components.Label(
		overlay,
		"DeathSub",
		"Your spirit remains — watch over the living.",
		Theme.Typography.CaptionSize,
		Theme.Typography.CaptionFont
	)
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	sub.Position = UDim2.new(0.5, 0, 0.56, 0)
	sub.Size = UDim2.new(0.7, 0, 0, 28)
	sub.TextColor3 = Theme.Colors.White
	sub.TextTransparency = 0.3
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.ZIndex = 93

	local function active(): boolean
		return not self.destroyed
			and self.deathCinematicToken == token
			and overlay.Parent ~= nil
	end

	if Motion.IsReducedMotion(self.root) then
		overlay.GroupTransparency = 0
		task.delay(2.5, function()
			if active() then
				overlay:Destroy()
				if self.deathCinematicOverlay == overlay then
					self.deathCinematicOverlay = nil
				end
			end
		end)
		return
	end

	Motion.FadeIn(overlay, { duration = 0.4, property = "GroupTransparency" })
	task.delay(2.5, function()
		if not active() then
			return
		end
		Motion.FadeOut(overlay, {
			duration = 0.5,
			property = "GroupTransparency",
			onComplete = function()
				if active() then
					overlay:Destroy()
					if self.deathCinematicOverlay == overlay then
						self.deathCinematicOverlay = nil
					end
				end
			end,
		})
	end)
end
```

Also cancel any active `deathCinematicOverlay` in the existing `Destroy()` / cleanup path:
```lua
if self.deathCinematicOverlay then
    self.deathCinematicOverlay:Destroy()
    self.deathCinematicOverlay = nil
end
```

---

#### 2b — Phase tip in title card

**New `require` at top of file** (add alongside other shared Config requires):

```lua
local PhaseTips = require(Shared:WaitForChild("Config"):WaitForChild("PhaseTips"))
```

**Expand band height** in `PlayPhaseTitleCard()`:
- Change `band.Size = UDim2.new(1, 0, 0, 96)` → `UDim2.new(1, 0, 0, 120)`

**Adjust existing label positions** to make room:
- `title.Position = UDim2.fromOffset(16, 8)` (was 12)
- `title.Size = UDim2.new(1, -32, 0, 40)` (was 42)
- `subtitle.Position = UDim2.fromOffset(16, 50)` (was 54)
- `subtitle.Size = UDim2.new(1, -32, 0, 24)` (was 28)

**Add tip label** immediately after the subtitle label build (before the `local reducedMotion` line):

```lua
local tipText = PhaseTips[phaseName]
if tipText then
    local tip = Components.Label(
        band,
        "PhaseTip",
        tipText,
        10,
        Theme.Typography.CaptionFont
    )
    tip.Position = UDim2.fromOffset(16, 76)
    tip.Size = UDim2.new(1, -32, 0, 20)
    tip.TextColor3 = Theme.Colors.White
    tip.TextTransparency = 0.55
    tip.TextXAlignment = Enum.TextXAlignment.Center
    tip.ZIndex = 81
end
```

---

#### 2c — Health bar damage flash

**New state field:**
```lua
lastHealthForFlash: number,
```

Initialize to `100`.

**In `Tick()`**, in the health section (near line ~3085), after `self.healthFill.Size = ...` is set, add:

```lua
-- Brief damage flash when health drops
local currentHealth = health
if currentHealth < self.lastHealthForFlash and not ghost then
    local fill = self.healthFill
    local originalColor = fill.BackgroundColor3
    fill.BackgroundColor3 = Theme.Colors.DangerBright
    task.delay(0.12, function()
        if not self.destroyed then
            TweenService:Create(
                fill,
                TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { BackgroundColor3 = originalColor }
            ):Play()
        end
    end)
end
self.lastHealthForFlash = currentHealth
```

Note: `TweenService` is already required in `GameView.lua` at line 6. Use it directly.

---

### Agent 3 — `src/client/Controllers/RoundController.lua`

**New module-level variable** (add near the other `last*` variables at the top of the file):

```lua
local lastIsGhost: boolean? = nil
```

**In `refresh()`**, after `local isGhost = ...` (line ~333) and before `currentEffects:SetGhostTint(isGhost)`:

```lua
-- Ghost transition cinematic — fires once on the false → true crossing
local ghostJustDied = isGhost == true and lastIsGhost == false and not reconnect
if ghostJustDied and currentView then
    currentView:PlayDeathCinematic()
end
if isGhost ~= lastIsGhost then
    currentCinematics:SetGhostMode(isGhost)
end
lastIsGhost = isGhost
```

`reconnect` is the local variable already available at this point in `refresh()` (line ~262).

**In `Stop()`** (where other `last*` variables are reset), add:

```lua
lastIsGhost = nil
```

---

### Agent 4 — `src/client/Controllers/CinematicsController.lua`

#### 4a — Add ghost state to `CinematicsControllerState` type

Add two fields to the type block:

```lua
ghostActive: boolean,
ghostSaturationOffset: number,
```

#### 4b — Initialize in `CinematicsController.new()`

Add to the `setmetatable({ ... })` initializer:

```lua
ghostActive = false,
ghostSaturationOffset = 0,
```

#### 4c — Modify `_restoreBaseline()` to incorporate ghost offset

Change:
```lua
self.colorCorrection.Saturation = self.phaseBaselineSaturation
```
To:
```lua
self.colorCorrection.Saturation = self.phaseBaselineSaturation + self.ghostSaturationOffset
```

#### 4d — Modify `_resetDread()` the same way

Change the line:
```lua
self.colorCorrection.Saturation = self.phaseBaselineSaturation
```
(in `_resetDread()`, not the one in `_restoreBaseline()`)
To:
```lua
self.colorCorrection.Saturation = self.phaseBaselineSaturation + self.ghostSaturationOffset
```

#### 4e — Add `SetGhostMode` public method

Add after `SetMonsterDread`:

```lua
function CinematicsController:SetGhostMode(active: boolean)
    if self.destroyed or self.ghostActive == active then
        return
    end
    self.ghostActive = active
    self.ghostSaturationOffset = if active then -0.28 else 0
    local targetSaturation = self.phaseBaselineSaturation + self.ghostSaturationOffset
    self:_playTween(self.colorCorrection, if active then 1.2 else 0.6, {
        Saturation = targetSaturation,
        TintColor = if active
            then Color3.fromRGB(200, 220, 255)
            else Color3.fromRGB(255, 255, 255),
    })
end
```

**Note on `TintColor`:** `ColorCorrectionEffect.TintColor` is a valid Roblox property. Confirm it compiles correctly — if the Luau strict check rejects the property name, use the string index syntax `colorCorrection["TintColor"]` as the tween goal key.

---

## Definition of Done for Request 0012

- [ ] `src/shared/Config/PhaseTips.lua` exists with 6 entries
- [ ] `GameView:PlayDeathCinematic()` exists and runs: "YOU HAVE FALLEN" overlay, 2.5s, fade in/out, cancel-safe
- [ ] Phase title band height is 120px; tip label appears below subtitle for phases that have a PhaseTips entry
- [ ] Health damage flash fires (brief DangerBright → tween back) when health decreases
- [ ] `CinematicsController:SetGhostMode(true)` applies -0.28 saturation offset + blue TintColor over 1.2s
- [ ] `CinematicsController:SetGhostMode(false)` restores saturation and white TintColor
- [ ] `RoundController` detects ghost transition and calls both `PlayDeathCinematic()` and `SetGhostMode(true)`
- [ ] `lastIsGhost` resets to `nil` in `Stop()`
- [ ] Gate: `python scripts/run_all_checks.py --require-rojo` passes with **79 strict Luau files** (78 + PhaseTips.lua)
- [ ] Reply in `ClaudChat/ChatToClaude/Chat_Request-0012-death-cinematic-ghost-visual-phase-tip.md`

## Notes for ChatGPT

- `Motion.FadeIn` / `Motion.FadeOut` on a `CanvasGroup` requires `property = "GroupTransparency"`. Verify the Motion module supports that parameter — if not, tween `GroupTransparency` directly via `TweenService`.
- `Theme.Typography.CaptionFont` — verify against `src/client/UI/Theme.lua`. If absent, use `Enum.Font.Gotham`.
- File size: `GameView.lua` is large (~130 KB). Verify byte count after edit and report it in the reply.
