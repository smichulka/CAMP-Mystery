# Claude_Request-0015 — Screen Shake, Phase Flash, Badge Pop, Connect/Disconnect Toasts

## Context

Baseline after 0014: **80 strict Luau files**, 852,965 bytes Rojo artifact.

Confirmed state from reading the repo before writing this request:
- `ghostBadge` already pulses when ghost mode is active — no banner addition needed
- `notebookBadge` sets text and visibility but has no pop animation on new evidence
- Phase changes are handled in `RoundController.refresh()` at the `phaseName ~= lastCinematicPhase` block (~line 342); `PlayPhaseTransition` is called at ~line 359
- `PlayImpactFlash()` fires in the action-result handler (~lines 473–485)
- `CinematicsController` does NOT import `RunService` — must be added
- `colorCorrection.Contrast` is used by `PlayImpactFlash`; `colorCorrection.Saturation`+`TintColor` used by ghost/dread systems; `colorCorrection.Brightness` is currently untouched

No new files. All three agents own different existing files and can run simultaneously (single wave).

---

## Single Wave — All three agents in parallel

---

### Agent 1 — `src/client/UI/GameView.lua`

Two small additions. Read the full file before editing.

---

#### 1a — Evidence badge pop animation

**New state field:**
```lua
lastEvidenceCountForPop: number,
```
Initialize to `0`.

**In the evidence badge update block** (around line 3745 — the `if self.notebookBadge then` block), after the existing lines that set `self.notebookBadge.Text` and `.Visible = true`, add:

```lua
-- Pop animation when count just increased
local prevCount = self.lastEvidenceCountForPop
self.lastEvidenceCountForPop = newCount
if newCount > prevCount and not Motion.IsReducedMotion(self.root) then
    Motion.PopIn(self.notebookBadge, { duration = 0.22, scale = 1.28 })
end
```

Also reset `self.lastEvidenceCountForPop = 0` when the badge is hidden (the `else` branch where `Visible = false`).

---

#### 1b — Cooldown-ready feedback

**New state field:**
```lua
lastCooldownActive: boolean,
```
Initialize to `false`.

**In the ability cooldown update logic** (wherever `cooldownFill` is updated and `abilityCooldownEndsAt` is read): find where the cooldown transitions from active to cleared (i.e., when the remaining time drops to ≤0 or nil after previously being positive). Add:

```lua
local cooldownNowActive = remaining ~= nil and remaining > 0
if not cooldownNowActive and self.lastCooldownActive then
    -- cooldown just cleared
    if not Motion.IsReducedMotion(self.root) then
        Motion.PopIn(self.roleAction, { duration = 0.18, scale = 1.12 })
    end
    HapticController.Click()
end
self.lastCooldownActive = cooldownNowActive
```

`HapticController` is already required in this file. `self.roleAction` is the role action button frame.

Note: `remaining` here is the same value already computed for the fill fraction. This piggybacks on the existing cooldown read — do not add a second remote call or separate timer.

---

### Agent 2 — `src/client/Controllers/CinematicsController.lua`

Two new public methods. Read the full file before editing.

---

#### 2a — `PlayScreenShake(intensity: number?)`

**Add import** at the top of the file (after existing service imports):
```lua
local RunService = game:GetService("RunService")
```

**New state fields** (add to the state type and initializer):
```lua
shakeToken: number,
shakeConn: RBXScriptConnection?,
shakePrevOffset: Vector3,
```
Initialize: `shakeToken = 0`, `shakeConn = nil`, `shakePrevOffset = Vector3.zero`.

**New method** (add after `PlayImpactFlash`):

```lua
function CinematicsController:PlayScreenShake(intensity: number?)
    if self.destroyed then
        return
    end
    local amp = math.clamp((intensity or 1.0) * 0.07, 0, 0.2)
    local freq = 14
    local duration = 0.4
    local startedAt = os.clock()

    self.shakeToken += 1
    local token = self.shakeToken

    -- cancel previous shake and remove its residual offset
    if self.shakeConn then
        self.shakeConn:Disconnect()
        self.shakeConn = nil
        local cam = workspace.CurrentCamera
        if cam and cam.Parent then
            cam.CFrame = cam.CFrame * CFrame.new(-self.shakePrevOffset)
        end
        self.shakePrevOffset = Vector3.zero
    end

    self.shakeConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        -- remove previous frame's offset so we don't compound
        if cam and cam.Parent then
            cam.CFrame = cam.CFrame * CFrame.new(-self.shakePrevOffset)
        end

        if self.shakeToken ~= token or self.destroyed then
            self.shakePrevOffset = Vector3.zero
            if self.shakeConn then
                self.shakeConn:Disconnect()
                self.shakeConn = nil
            end
            return
        end

        local elapsed = os.clock() - startedAt
        if elapsed >= duration then
            self.shakePrevOffset = Vector3.zero
            if self.shakeConn then
                self.shakeConn:Disconnect()
                self.shakeConn = nil
            end
            return
        end

        local decay = 1 - elapsed / duration
        local t = elapsed * freq * math.pi * 2
        local x = math.sin(t) * amp * decay
        local y = math.sin(t + math.pi * 0.7) * amp * 0.5 * decay
        local newOffset = Vector3.new(x, y, 0)

        if cam and cam.Parent then
            cam.CFrame = cam.CFrame * CFrame.new(newOffset)
        end
        self.shakePrevOffset = newOffset
    end)
end
```

**In `Destroy()`**, add before existing cleanup:
```lua
if self.shakeConn then
    self.shakeConn:Disconnect()
    self.shakeConn = nil
    local cam = workspace.CurrentCamera
    if cam and cam.Parent then
        cam.CFrame = cam.CFrame * CFrame.new(-self.shakePrevOffset)
    end
    self.shakePrevOffset = Vector3.zero
end
```

---

#### 2b — `PlayPhaseFlash()`

Uses `colorCorrection.Brightness` — currently 0 and not used by any existing method (ghost/dread use Saturation+TintColor; impact uses Contrast). No conflict.

**New method** (add after `PlayScreenShake`):

```lua
function CinematicsController:PlayPhaseFlash()
    if self.destroyed then
        return
    end
    self:_playTween(self.colorCorrection, 0.10, { Brightness = 0.14 })
    task.delay(0.10, function()
        if not self.destroyed then
            self:_playTween(self.colorCorrection, 0.28, { Brightness = 0 })
        end
    end)
end
```

`_playTween` is the existing private method in `CinematicsController` that wraps `TweenService:Create`. Confirm its exact name before using.

---

### Agent 3 — `src/client/Controllers/RoundController.lua`

Three additions in a single commit. Read the full file before editing.

---

#### 3a — Wire `PlayScreenShake` on Critical/Incapacitated

In the action-result handler where `PlayImpactFlash()` is already called (~lines 473–485), add `PlayScreenShake` immediately after:

```lua
currentCinematics:PlayImpactFlash()
currentCinematics:PlayScreenShake(1.0)
```

These two calls should be adjacent. `PlayScreenShake` uses RenderStepped (not TweenService) and does not conflict with `PlayImpactFlash`'s Contrast tween.

---

#### 3b — Wire `PlayPhaseFlash` on phase transitions

In the `phaseName ~= lastCinematicPhase` block (around line 359, after `currentCinematics:PlayPhaseTransition(phaseName)`), add:

```lua
if not reconnect and phaseName ~= "Lobby" and phaseName ~= "Rewards" then
    currentCinematics:PlayPhaseFlash()
end
```

This fires only for genuine phase advances, not reconnect pre-seeding and not the lobby/rewards transitions (which already have their own full cinematic treatments).

---

#### 3c — Participant connect/disconnect notifications

**New module-level variable** (add near other `last*` vars):
```lua
local lastConnectedState: { [string]: boolean } = {}
```

**In `refresh()`**, after `snapshot.participants` is available, iterate participants to detect transitions:

```lua
-- Detect participant connect/disconnect transitions
local participants = if type(snapshot) == "table" and type(snapshot.participants) == "table"
    then snapshot.participants
    else {}
for _, p in participants do
    if type(p) ~= "table" or readBoolean(p, "isBot", false) then
        continue
    end
    local pid = readString(p, "participantId", "")
    local name = readString(p, "displayName", "?")
    local connected = readBoolean(p, "connected", true)
    local prev = lastConnectedState[pid]
    if prev ~= nil then
        if not connected and prev then
            if currentView then
                currentView:Notify(name .. " left", "Player disconnected.", "Warning")
            end
        elseif connected and not prev then
            if currentView then
                currentView:Notify(name .. " reconnected", "", "Info")
            end
        end
    end
    lastConnectedState[pid] = connected
end
```

`readBoolean` and `readString` are the existing local helpers in `RoundController`. Confirm their exact names before using. If `readBoolean` does not exist, use an equivalent inline guard.

`prev ~= nil` ensures no notification fires for participants seen for the first time (initial snapshot population).

**In `Stop()`**, reset:
```lua
lastConnectedState = {}
```

---

## Definition of Done for Request 0015

- [ ] `notebookBadge` runs `Motion.PopIn` (scale 1.28, 0.22s) when new evidence count increases; no pop on open/close or count decrease
- [ ] `lastEvidenceCountForPop` resets to 0 when badge is hidden
- [ ] `roleAction` runs `Motion.PopIn` (scale 1.12, 0.18s) + `HapticController.Click()` exactly once when cooldown transitions from active to cleared
- [ ] `PlayScreenShake(1.0)` fires immediately after `PlayImpactFlash()` on Critical/Incapacitated action results
- [ ] Screen shake: oscillates x/y camera offset for 0.4s, decays smoothly to zero, cleans up RenderStepped connection, no residual camera offset after completion
- [ ] `PlayPhaseFlash()` fires on non-reconnect phase transitions (excluding Lobby and Rewards)
- [ ] Phase flash: Brightness spikes to 0.14 over 0.10s then returns to 0 over 0.28s; no interaction with Saturation or Contrast paths
- [ ] Participant leave toast fires once per `true → false` connected transition per participant, not on initial snapshot load
- [ ] Participant reconnect toast fires once per `false → true` connected transition
- [ ] No notifications fire for bot participants
- [ ] `lastConnectedState` clears on `Stop()`
- [ ] Gate: `python scripts/run_all_checks.py --require-rojo` passes with **80 strict Luau files** (no new files this request)
- [ ] Reply in `ClaudChat/ChatToClaude/Chat_Request-0015-screen-shake-phase-flash-badge-pop-reconnect.md`

## Notes for ChatGPT

- `workspace` (lowercase) is a valid Roblox global in strict Luau — no service import needed for `workspace.CurrentCamera`. Alternatively use `game:GetService("Workspace")`. Either is fine; be consistent with what's already in the file.
- `CFrame.new(Vector3)` constructor: `CFrame.new(v: Vector3)` is the correct form in strict Luau. Do NOT use `CFrame.new(x, y, z)` separately — compute the Vector3 first then construct.
- `self.shakeConn:Disconnect()` inside the RenderStepped callback: this is safe in Roblox — disconnecting a connection from within its own callback is allowed. After `Disconnect()`, set `self.shakeConn = nil` before returning.
- The `_playTween` helper in CinematicsController: confirm its exact signature (likely `_playTween(instance, duration, goals)`) before calling from `PlayPhaseFlash`.
- `Motion.PopIn` signature: check the Motion module's `PopIn` function signature — it may be `Motion.PopIn(instance, options)` where options includes `scale`. Do not assume; read Motion.lua or grep for existing `Motion.PopIn` calls in GameView.lua to confirm the call pattern.
- For 3c: if `snapshot.participants` is already iterated elsewhere in `refresh()` using a typed loop variable, reuse that same loop rather than adding a second one. Add the connect/disconnect check as an additional `if` block inside the existing participant loop where possible.
- Baseline file count stays at 80. Report final byte counts for all three files in reply.
