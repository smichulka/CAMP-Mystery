# Claude_Request-0019 — Monster Mode HUD and Dread Ambience

## Context

Baseline after 0018: **81 strict Luau files**, 879,017 bytes Rojo artifact. All checks pass.

**Gap identified:**

When the Murderer player transforms into their monster form during the Investigation
phase, they have NO dedicated HUD. They see the same UI as every other player. The only
monster-specific interaction is the role-action button opening an ability picker.

The `privateMonster` snapshot (already broadcast to the Murderer's client in `state.privateMonster`)
contains everything needed for a proper monster HUD:
- `monsterId: string?` — which monster they are
- `active: boolean` — whether the monster is in Active lifecycle
- `stamina: number` — current stamina
- `maxStamina: number` — max stamina from monster rules
- `cooldownEndsAt: { [string]: number }` — cooldown end timestamps per ability
- `lifecycle: string` — "Inactive", "Planning", "Active", "Stopped"

**This request has 3 agents, all modifying separate files — run in parallel.**

---

## Agent 1 — `src/client/UI/GameView.lua`

Add a monster mode panel that shows during Investigation when `privateMonster.active == true`.

Read the full file before editing.

### New state fields

Add to the `GameViewState` type and initialization block (`GameView.new()`):

```lua
monsterPanel: Frame?,
monsterNameLabel: TextLabel?,
monsterStaminaFill: Frame?,
monsterAbilityLabel: TextLabel?,
monsterPanelVisible: boolean,
```
Initialize all to `nil` / `false`.

### Build the panel in `GameView.new()`

Position: bottom-right corner, above the hotbar. Use these layout values:
- `AnchorPoint = Vector2.new(1, 1)`
- `Position = UDim2.new(1, -16, 1, -88)` (above hotbar area; adjust if hotbar height differs)
- `Size = UDim2.fromOffset(200, 68)`
- `BackgroundColor3 = Theme.Colors.Panel`
- `BackgroundTransparency = 0.1`
- `ZIndex = 22`
- `Visible = false` (starts hidden)
- `BorderSizePixel = 0`
- `Components.Corner(panel, 8)` 
- `Components.Stroke(panel, Theme.Colors.DangerBright, 1)`

Inside the panel, build three sub-elements:

**1. Monster name label** (`monsterNameLabel`)
```lua
-- Displays monsterId formatted as uppercase ("WATCHER", "STALKER", etc.)
-- TextColor3 = Theme.Colors.DangerBright
-- Font = Theme.Typography.HeadingFont, Size = 13
-- Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18)
-- TextXAlignment = Left
```

**2. Stamina bar** (track + fill)
```lua
-- Track: Position UDim2.fromOffset(10, 30), Size UDim2.new(1, -20, 0, 8)
-- BackgroundColor3 = Theme.Colors.Ghost (dim), Corner(track, 4)
-- Fill: child of track, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Colors.DangerBright
-- Corner(fill, 4), no borders
-- Label "STAMINA" above the track at y=22, TextColor3 = Theme.Colors.TextMuted, size 10
```

**3. Ability state label** (`monsterAbilityLabel`)
```lua
-- Displays "ABILITY READY" or "ABILITY COOLING: Xs"
-- TextColor3 = Theme.Colors.Gold (ready) or Theme.Colors.TextMuted (cooling)
-- Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 0, 14)
-- Font = Theme.Typography.CaptionFont, TextSize = 11
-- TextXAlignment = Left
```

### Update the panel in `Update()`

After reading `state.privateMonster`, add a block:

```lua
local privateMonster = if type(state) == "table" then state.privateMonster else nil
local monsterActive = type(privateMonster) == "table"
    and readBoolean(privateMonster, "active", false)

-- Show/hide panel with fade if visibility changed
if self.monsterPanel then
    local shouldShow = monsterActive and not roundEnded
    if shouldShow ~= self.monsterPanelVisible then
        self.monsterPanelVisible = shouldShow
        if shouldShow then
            self.monsterPanel.Visible = true
            Motion.FadeIn(self.monsterPanel, { duration = 0.3 })
        else
            Motion.FadeOut(self.monsterPanel, { duration = 0.3, onComplete = function()
                if self.monsterPanel then
                    self.monsterPanel.Visible = false
                end
            end})
        end
    end
end

-- Update panel content
if monsterActive and self.monsterPanel then
    local pm = privateMonster :: any

    -- Monster name
    if self.monsterNameLabel then
        local rawId = readString(pm, "monsterId", "")
        local displayName = if rawId ~= ""
            then string.upper(rawId:gsub("(%l)(%u)", "%1 %2"))
            else "MONSTER"
        self.monsterNameLabel.Text = "▸ " .. displayName
    end

    -- Stamina bar
    if self.monsterStaminaFill then
        local stamina = readNumber(pm, "stamina", 1)
        local maxStamina = readNumber(pm, "maxStamina", 1)
        local fraction = if maxStamina > 0 then math.clamp(stamina / maxStamina, 0, 1) else 1
        self.monsterStaminaFill.Size = UDim2.fromScale(fraction, 1)
    end

    -- Ability cooldown
    if self.monsterAbilityLabel then
        local cooldowns = if type(pm.cooldownEndsAt) == "table" then pm.cooldownEndsAt else {}
        local now = tick()
        local longestRemaining = 0
        for _, endsAt in cooldowns do
            if type(endsAt) == "number" then
                local remaining = endsAt - now
                if remaining > longestRemaining then
                    longestRemaining = remaining
                end
            end
        end
        if longestRemaining > 0.5 then
            self.monsterAbilityLabel.Text = string.format("ABILITY COOLING: %ds", math.ceil(longestRemaining))
            self.monsterAbilityLabel.TextColor3 = Theme.Colors.TextMuted
        else
            self.monsterAbilityLabel.Text = "ABILITY READY"
            self.monsterAbilityLabel.TextColor3 = Theme.Colors.Gold
        end
    end
end
```

**Note:** `tick()` is appropriate for client-side remaining-time display (approximate only). The server-authoritative cooldown is in `abilityCooldownEndsAt` on the participant private snapshot, but the monster's own cooldown feed from `privateMonster.cooldownEndsAt` is what we want here.

### Destroy

In `Destroy()`, destroy `monsterPanel` if not nil.

---

## Agent 2 — `src/client/UI/EffectsView.lua`

Add `SetMonsterMode(active: boolean)` — a subtle crimson ColorShift for the Murderer during Investigation. Read the full file before editing.

**Design rationale:** Ghost mode is blue/desaturated (fear). Monster mode should be the
opposite — a very faint red warmth that signals predator/power. This is a subtle
ColorShift_Top on the Lighting service, not a screen overlay.

**New state fields:**
```lua
monsterModeActive: boolean,
monsterModeTween: Tween?,
```
Initialize to `false` / `nil`.

**New public method:**
```lua
function EffectsView:SetMonsterMode(active: boolean)
    if self.destroyed or active == self.monsterModeActive then
        return
    end
    self.monsterModeActive = active

    if self.monsterModeTween then
        self.monsterModeTween:Cancel()
        self.monsterModeTween = nil
    end

    -- Target ColorShift_Top: subtle warm crimson when active, neutral when inactive
    local targetShift = if active
        then Color3.fromRGB(42, 8, 4)
        else Color3.fromRGB(0, 0, 0)

    local lighting = game:GetService("Lighting")

    if self.reducedMotion then
        lighting.ColorShift_Top = targetShift
    else
        self.monsterModeTween = TweenService:Create(
            lighting,
            TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            { ColorShift_Top = targetShift }
        )
        self.monsterModeTween:Play()
    end
end
```

**Before implementing:** Confirm that `EffectsView` already modifies `Lighting`
properties (it does for `SetNightIntensity` / `SetGhostTint` — match that existing
pattern exactly, including how `TweenService` is imported). Confirm `ColorShift_Top`
is not already animated by another system for the current phase — if so, use
`ColorShift_Bottom` instead to avoid conflict.

**In `Destroy()`:** Cancel `monsterModeTween`. Reset `lighting.ColorShift_Top` to
`Color3.fromRGB(0, 0, 0)` if `monsterModeActive == true` at destroy time.

---

## Agent 3 — `src/client/Controllers/RoundController.lua`

Wire `EffectsView:SetMonsterMode()` and manage monster HUD visibility. Read the full file before editing.

**In `refresh()`**, after the ghost mode / spectator mode block, add:

```lua
-- Monster mode: active during Investigation when this player IS the monster
local privateMonster = if type(state) == "table" then state.privateMonster else nil
local isActiveMonster = type(privateMonster) == "table"
    and readBoolean(privateMonster, "active", false)
    and phase == "Investigation"

local currentEffects = effects
if currentEffects then
    currentEffects:SetMonsterMode(isActiveMonster)
end
```

`effects` is the local variable holding the `EffectsView` instance — confirm the exact
name used in the file (it may be `effectsView`, `effects`, or similar).

`readBoolean` is already defined in `RoundController`.

**Important:** monster mode and ghost mode are mutually exclusive. A Murderer player
is never a ghost simultaneously. But add a guard: if `isGhost` is true, do NOT set
monster mode active (even if privateMonster is present). Ghost mode takes precedence
for visual state.

```lua
local currentEffects = effects
if currentEffects then
    currentEffects:SetMonsterMode(isActiveMonster and not isGhost)
end
```

---

## Definition of Done for Request 0019

- [ ] `GameView.lua`: `monsterPanel` Frame exists, hidden by default; shows during Investigation when `privateMonster.active == true`; displays monster name, stamina bar, and ability cooldown
- [ ] `GameView.lua`: Panel fades in/out with Motion.FadeIn/FadeOut; hidden during Lobby/Rewards/non-Investigation phases
- [ ] `EffectsView.lua`: `SetMonsterMode(active)` method exists; tweens `ColorShift_Top` to crimson when active, neutral when inactive; cancel-safe; destroy-safe
- [ ] `RoundController.lua`: `SetMonsterMode` wired from `refresh()` — active only when `phase == "Investigation"` and `privateMonster.active == true` and `not isGhost`
- [ ] Gate: `python scripts/run_all_checks.py --require-rojo` passes — **81 strict Luau files**
- [ ] Reply in `ClaudChat/ChatToClaude/Chat_Request-0019-monster-hud-dread.md`

## Notes for ChatGPT

- `state.privateMonster` is already in the broadcast snapshot for Murderer players — no new remote or server change needed.
- `Motion.FadeIn` and `Motion.FadeOut` require the target to be a `CanvasGroup` with `GroupTransparency`. If `monsterPanel` is a plain `Frame`, use `TweenService` on `BackgroundTransparency` + child label `TextTransparency` instead, or wrap the panel in a CanvasGroup. Choose whichever matches the existing modal pattern in `GameView.lua`.
- `tick()` for ability cooldown display is approximate but acceptable — the display updates each `Update()` tick so it's close enough.
- The crimson `ColorShift_Top` (42, 8, 4) is intentionally very subtle — just a slight warmth, not a bright red. If existing night ambience already sets a warm tone via another Lighting property, reduce the intensity to (20, 4, 2) to avoid double-warming.
- Report byte counts for all 3 changed files.
