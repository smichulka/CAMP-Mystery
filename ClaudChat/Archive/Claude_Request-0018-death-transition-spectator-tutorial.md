# Claude_Request-0018 — Death Transition Window, Spectator Banner, Tutorial Steps

## Context

Baseline after 0017: **81 strict Luau files**, 876,084 bytes Rojo artifact. All checks pass.

**Gap identified from 0017 review:**

`CombatService:Eliminate()` sets `alive=false` AND `isGhost=true` simultaneously at
lines 114-115. This means the ELIMINATED banner and spectator vignette added in 0017
never fire in normal gameplay — players jump directly to ghost mode.

Additionally, the Spectator role (late joiners assigned `role = "Spectator"`) will see the
0017 ELIMINATED banner saying "You are spectating. Watch the mystery unfold." — but the
copy is wrong for them. They weren't eliminated; they joined late.

**This request has 3 agents, all modifying separate files — run in parallel.**

---

## Agent 1 — `src/server/Services/CombatService.lua`

Add a 3-second death-to-ghost transition window to `Eliminate()`.

Read the full file before editing.

**Current code (lines 105-128):**
```lua
function CombatService:Eliminate(
    target: ParticipantState,
    reason: string,
    attackerParticipantId: string?
): { string }
    if not target.alive then
        return {}
    end

    target.alive = false
    target.isGhost = true      -- ← both set simultaneously
    target.healthState = "Dead"
    target.health = 0
    target.injuryLevel = 2
    local dropped = self.inventory:DropAll(target.participantId)
    self.revision += 1
    self.lifecycle:Emit("ParticipantEliminated", {
        participantId = target.participantId,
        attackerParticipantId = attackerParticipantId,
        reason = reason,
        droppedItemIds = dropped,
    })
    return dropped
end
```

**Required change — split alive and isGhost:**
```lua
function CombatService:Eliminate(
    target: ParticipantState,
    reason: string,
    attackerParticipantId: string?
): { string }
    if not target.alive then
        return {}
    end

    target.alive = false
    -- isGhost deferred: gives clients 3 seconds to show the ELIMINATED banner
    -- before ghost mode activates. Win-condition checks use target.alive, not isGhost,
    -- so the outcome is correct during the window.
    target.healthState = "Dead"
    target.health = 0
    target.injuryLevel = 2
    local dropped = self.inventory:DropAll(target.participantId)
    self.revision += 1
    self.lifecycle:Emit("ParticipantEliminated", {
        participantId = target.participantId,
        attackerParticipantId = attackerParticipantId,
        reason = reason,
        droppedItemIds = dropped,
    })

    -- Capture participantId to avoid holding a strong reference to target across the delay
    local participantId = target.participantId
    task.delay(3, function()
        -- Guard: participant may have been reassigned or round ended
        if target.alive then
            return
        end
        if not target.isGhost then
            target.isGhost = true
            self.revision += 1
            -- Emit a lightweight state update so clients can transition
            self.lifecycle:Emit("ParticipantGhostTransition", {
                participantId = participantId,
            })
        end
    end)

    return dropped
end
```

**Important checks before implementing:**
- Confirm `self.lifecycle:Emit` is the correct method name on the lifecycle object — read the service constructor.
- Confirm that `task` is available in this file without an explicit require (it is a Luau global on Roblox, but confirm it isn't explicitly required/assigned).
- Confirm that the `ParticipantState` type allows mutation of `isGhost` after the function returns (it is a table reference, not a copy, so this should be fine).
- Do NOT remove the `target.isGhost = true` path — only defer it.
- If `task.delay` is not idiomatic in this file and the service uses a different async pattern (e.g. coroutines or a scheduler), match that pattern instead.

**What this achieves:**
- Clients receive `alive=false, isGhost=false` state for 3 seconds → ELIMINATED banner shows, spectator vignette fades in.
- After 3 seconds: `isGhost=true` syncs → ELIMINATED banner hides, ghost badge + desaturation + free-camera activate.
- Win condition checks are unaffected because they use `participant.alive`, not `participant.isGhost`.

---

## Agent 2 — `src/client/UI/GameView.lua`

Customize the ELIMINATED banner message for the `Spectator` role (late joiners).
Read the full file before editing.

**Background:**
The 0017 ELIMINATED banner added in `GameView.new()` is named `EliminatedBanner` with a
"Title" child label ("ELIMINATED") and a "Sub" child label ("You are spectating. Watch the
mystery unfold.").

Spectator-role players (late joiners) are `alive=false, isGhost=false` — the banner shows
for them correctly. But the copy is wrong: they were never eliminated.

**Required change:**

In `Update()`, after the block that sets `eliminatedBanner.Visible`:

1. Read the local player's role: `local role = readString(player, "role", "")`
2. Conditionally update the banner's label text based on whether they are a Spectator:

```lua
if self.eliminatedBanner and self.eliminatedBanner.Visible then
    local role = readString(player, "role", "")
    local titleLabel = self.eliminatedBanner:FindFirstChild("Title")
    local subLabel = self.eliminatedBanner:FindFirstChild("Sub")
    if titleLabel and subLabel then
        if role == "Spectator" then
            titleLabel.Text = "OBSERVING"
            subLabel.Text = "You joined during an active round. You'll play next."
        else
            titleLabel.Text = "ELIMINATED"
            subLabel.Text = "You are spectating. Watch the mystery unfold."
        end
    end
end
```

Apply these updates only when `eliminatedBanner.Visible == true` to avoid unnecessary
string writes every tick when the banner is hidden.

Confirm that `readString` already accepts `player` (an Instance) as its first argument,
which is used for `Instance:GetAttribute()` — match whatever pattern the surrounding
`Update()` code uses to read player attributes.

---

## Agent 3 — `src/client/Controllers/TutorialController.lua`

Add 3 missing tutorial steps and improve body copy for 2 existing steps.
Read the full file before editing.

**Missing tutorial steps to add:**

The current `STEP_COPY` has 7 steps mapped to these contexts:
```
Lobby, Role, Day, Investigation, Evidence, Vote, Rewards
```

Add these 3 new entries to `STEP_COPY` (insert at appropriate position in flow order):

**1. MurderPlanning step** — shown during `MurderPlanning` phase for all players:
```lua
{
    id = "murderplanning",
    context = "MurderPlanning",
    title = "The Night Is Being Decided",
    body = "Someone in the group is choosing a victim right now. Use this moment to prepare — equip your gear and decide where to investigate tonight.",
    objective = "EQUIP YOUR GEAR BEFORE NIGHTFALL",
},
```

**2. NightTransform step** — shown during `NightTransform` phase:
```lua
{
    id = "nighttransform",
    context = "NightTransform",
    title = "The Town Appears",
    body = "The camp has merged with an abandoned town. The monster is somewhere out there. Stay near teammates and watch your surroundings.",
    objective = "MOVE CAREFULLY — ISOLATION IS DANGEROUS",
},
```

**3. Spectator step** — shown when `role == "Spectator"`:
```lua
{
    id = "spectator",
    context = "Spectator",
    title = "You Joined Late",
    body = "This round is already underway. You can observe the current game and will join the roster at the start of the next round.",
    objective = "WATCH THE ROUND — YOU PLAY NEXT",
},
```

**In `currentContext(state: any)`**, add mappings for the new contexts:

After `if phase == "RoleReveal" or ...` block, add:
```lua
if phase == "MurderPlanning" then
    return "MurderPlanning"
end
if phase == "NightTransform" then
    return "NightTransform"
end
```

And add Spectator detection (before the phase checks, since it's role-based not phase-based):
```lua
local role = readString(round, "role", "")
if role == "Spectator" then
    return "Spectator"
end
```

Note: confirm that `round` in `currentContext` is the correct table that holds role — it
may be the player-private snapshot. If `role` lives on a different nested key, match
whatever structure the surrounding read helpers use.

**Existing step copy improvements:**

Update the `investigation` step body:
```
OLD: "The abandoned town is dangerous. Search rooms and attack sites, stay aware of teammates, and survive the monster."
NEW: "The abandoned town is dangerous. Search rooms for evidence, interview counselors, use your equipment, and stay in range of teammates. Isolation is how the monster wins."
```

Update the `evidence` step body:
```
OLD: "Evidence identifies both the supernatural threat and the human culprit. Some clues may be false, so compare what the group found."
NEW: "Your notebook has two channels: culprit clues and monster clues. Real evidence points to one answer. Compare with your group — false clues and mistaken witnesses can redirect suspicion."
```

---

## Definition of Done for Request 0018

- [ ] `CombatService.lua`: `Eliminate()` sets `alive=false` immediately, defers `isGhost=true` by 3 seconds via `task.delay`; `ParticipantGhostTransition` event emitted after delay
- [ ] `CombatService.lua`: `if not target.alive then return end` early-exit guard in the delay callback
- [ ] `GameView.lua`: Banner shows "OBSERVING" / "You joined during an active round" for Spectator role, "ELIMINATED" / "You are spectating" for dead non-ghosts
- [ ] `TutorialController.lua`: `STEP_COPY` has 10 entries (7 original + 3 new); `StepIds` table updated with `MurderPlanning`, `NightTransform`, `Spectator` keys; `currentContext()` maps all 3 new contexts
- [ ] Gate: `python scripts/run_all_checks.py --require-rojo` passes — **81 strict Luau files**
- [ ] Reply in `ClaudChat/ChatToClaude/Chat_Request-0018-death-transition-spectator-tutorial.md`

## Notes for ChatGPT

- `task.delay` is a Roblox Luau global — no require needed.
- The 3-second window is intentionally short: just long enough for the death animation and ELIMINATED banner to land, not so long it frustrates players waiting to ghost.
- `ParticipantGhostTransition` is a NEW event name. Before using it, check if any existing event would serve this purpose. If the existing state-sync mechanism automatically propagates attribute changes, the `Emit` call may not be needed — just setting `target.isGhost = true` and incrementing `self.revision` may be sufficient for the sync. Confirm what drives client state updates.
- Agent 2's `readString(player, "role", "")` — `player` here is an Instance (the LocalPlayer) and `readString` likely reads via `GetAttribute`. Confirm the exact pattern used in the surrounding `Update()` code and match it exactly; don't introduce a new read helper.
- Agent 3: `StepIds` is currently a `table.freeze({...})`. Add `MurderPlanning = "murderplanning"`, `NightTransform = "nighttransform"`, `Spectator = "spectator"` to it.
- Report byte counts for all 3 changed files.
