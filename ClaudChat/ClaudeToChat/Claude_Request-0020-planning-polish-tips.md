# Claude_Request-0020 — Murder Planning Polish, Ability Text Fix, Tip Expansion

## Context

Baseline after 0019: **81 strict Luau files**, 887,208 bytes Rojo artifact. All checks pass.

**Three targeted fixes identified from code review:**

1. `_chooseAbility()` in `GameView.lua` formats ability IDs with `gsub("-", " ")` — this
   only strips hyphens. Monster ability IDs are camelCase (`ScuttleLeap`, `AcidSwipe`),
   so they render as "SCUTTLELEAP" instead of "SCUTTLE LEAP". Simple gsub pattern fix.

2. `_chooseMurderPlan()` iterates `MONSTER_PLAN_LOCATIONS` (a hash table) with undefined
   key order — monsters appear in random order each time the planning modal opens.
   Additionally, buttons show only the monster name with no description, so the Murderer
   can't make an informed choice about which form to take.

3. `TipCatalog.lua` has 17 good lobby tips but they are all generic. Adding role-specific,
   equipment-specific, and monster-specific tips would give new players actionable guidance.

**This request has 2 agents modifying separate files — run in parallel.**

---

## Agent 1 — `src/client/UI/GameView.lua`

Two changes in this file. Read the full file before editing.

### Change A — Fix `_chooseAbility()` ability ID text formatting

**Current code (around line 2064):**
```lua
text = string.upper(abilityId:gsub("-", " ")),
```

**Required change:**
```lua
text = string.upper(abilityId:gsub("(%l)(%u)", "%1 %2"):gsub("-", " ")),
```

This splits camelCase words before uppercasing:
- `ScuttleLeap` → `"SCUTTLE LEAP"`
- `AcidSwipe` → `"ACID SWIPE"`
- `MournfulWail` → `"MOURNFUL WAIL"`
- `AnchorTeleport` → `"ANCHOR TELEPORT"`

The pattern `(%l)(%u)` matches a lowercase letter followed by an uppercase letter, inserting a space between them. Hyphen stripping is kept as a second pass.

### Change B — Enhance `_chooseMurderPlan()` with ordered list and monster taglines

**Add a new module-level constant** near `MONSTER_PLAN_LOCATIONS` (around line 184):

```lua
-- Ordered monster list for consistent planning UI display
local MONSTER_PLAN_ORDER: { string } = {
    "BabyAlien",
    "Screamer",
    "Wendigo",
    "ShadowMonster",
    "Chupacabra",
    "Dullahan",
    "Entity",
    "Banshee",
}

-- One-line tagline for each monster shown in the planning UI
local MONSTER_TAGLINES: { [string]: string } = {
    BabyAlien    = "Burst leaps · close ambush · weak in open light",
    Screamer     = "Scream disorients · disrupts all equipment",
    Wendigo      = "Mimicry lures · forest charge to kill",
    ShadowMonster = "Travels shadow nodes · strongest near dead lights",
    Chupacabra   = "Blood tracker · pounces over distance · latches",
    Dullahan     = "Accelerates on sustained sight · fear status",
    Entity       = "Anchor teleport · distorts victim perception",
    Banshee      = "Wail attack senses · marks vulnerable campers",
}
```

**Rewrite `_chooseMurderPlan()`:**

```lua
function GameView:_chooseMurderPlan()
    Components.ClearGenerated(self.targetList)
    self.targetTitle.Text = "Choose your transformation for tonight. Then choose a victim."
    for _, monsterId in MONSTER_PLAN_ORDER do
        local locationId = MONSTER_PLAN_LOCATIONS[monsterId]
        if not locationId then
            continue
        end
        local displayName = string.upper(monsterId:gsub("(%l)(%u)", "%1 %2"))
        local tagline = MONSTER_TAGLINES[monsterId] or ""

        -- Taller button to accommodate the tagline
        local button = Components.Button(self.targetList, {
            name = "Plan_" .. monsterId,
            text = "",  -- cleared; we add child labels below
            size = UDim2.new(1, -8, 0, 60),
            color = Theme.Colors.Danger,
        })
        button:SetAttribute("Generated", true)

        -- Monster name label (top half of button)
        local nameLabel = Components.Label(button, "MonsterName", displayName, 13, Enum.Font.GothamBold)
        nameLabel.AnchorPoint = Vector2.new(0, 0)
        nameLabel.Position = UDim2.fromOffset(10, 6)
        nameLabel.Size = UDim2.new(1, -14, 0, 22)
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextColor3 = Theme.Colors.White
        nameLabel.ZIndex = button.ZIndex + 1

        -- Tagline label (bottom half of button)
        if tagline ~= "" then
            local tagLabel = Components.Label(button, "Tagline", tagline, 10, Theme.Typography.CaptionFont)
            tagLabel.AnchorPoint = Vector2.new(0, 0)
            tagLabel.Position = UDim2.fromOffset(10, 30)
            tagLabel.Size = UDim2.new(1, -14, 0, 22)
            tagLabel.TextXAlignment = Enum.TextXAlignment.Left
            tagLabel.TextColor3 = Theme.Colors.White
            tagLabel.TextTransparency = 0.28
            tagLabel.ZIndex = button.ZIndex + 1
        end

        button.Activated:Connect(function()
            setModalVisible(self.targetModal, false)
            self:_chooseParticipant("SetMurderPlan", {
                monsterId = monsterId,
                locationId = locationId,
            }, false)
        end)
    end
    setModalVisible(self.notebook, false)
    setModalVisible(self.settings, false)
    setModalVisible(self.targetModal, true)
end
```

**Before implementing:**
- Confirm that `Components.Label()` returns a `TextLabel` and that `.ZIndex` is settable on it after creation (check the existing label creation pattern in this file for consistency).
- Confirm the `targetList` ScrollingFrame can accommodate 60px-tall children — it uses `Components.List` with a gap parameter. Check the existing list layout to ensure it will auto-size.
- If `Components.Button` does not accept `text = ""` cleanly (i.e., it forces non-empty text), use `text = " "` (a space) instead, or set the text to empty after button creation.
- `MONSTER_PLAN_ORDER` must match all 8 keys in `MONSTER_PLAN_LOCATIONS`. If any key is missing from MONSTER_PLAN_LOCATIONS (e.g., if the location table is updated separately), `continue` gracefully skips it.

---

## Agent 2 — `src/shared/Config/TipCatalog.lua`

Add 12 more tips to the `definitions` array. Read the full file before editing.

The current 17 tips are generic (CAMP BASICS, ROLES, MONSTERS, EVIDENCE, VOTING,
TEAMWORK, CONTROLS). New tips should be more specific and actionable, covering role
abilities, equipment use, and monster counterplay.

**Add these 12 entries** to the `definitions` array (append after the current last entry):

```lua
-- Equipment tips
{ category = "EQUIPMENT", body = "The Flashlight is your most reliable defense — keep it charged and pointed at threats." },
{ category = "EQUIPMENT", body = "The EMF Reader spikes near recent monster activity and can expose the type of threat." },
{ category = "EQUIPMENT", body = "Medical Kits remove serious injuries. Injured campers die from the next hit; prioritize healing them." },
{ category = "EQUIPMENT", body = "Monster Traps slow down a monster mid-hunt. Place them on likely approach routes before nightfall." },

-- Role ability tips
{ category = "ROLES", body = "Detectives can analyze a suspect for a suspicion band and verify posted evidence as real or fake." },
{ category = "ROLES", body = "The Medic cannot treat itself — ask a teammate to stay nearby when injured." },
{ category = "ROLES", body = "The Guard and Protector carry Flare Lanterns. Sustained light limits the Shadow Monster's movement." },
{ category = "ROLES", body = "The Medium's Spirit Box produces audio responses near haunted locations — post the evidence immediately." },

-- Monster counterplay tips
{ category = "COUNTERPLAY", body = "Break line of sight or change floors to disrupt the Dullahan before it reaches pursuit speed." },
{ category = "COUNTERPLAY", body = "UV light and direct flashlights can remove the Chupacabra's latch faster than waiting it out." },
{ category = "COUNTERPLAY", body = "Leave the wail radius immediately when the Banshee starts its attack — hesitation means injury." },
{ category = "COUNTERPLAY", body = "The Entity teleports between anchors. Watch for the arrival silhouette and move away from anchor points." },
```

Maintain the existing `table.freeze` wrapper and `--!strict` header. Do not modify or
reorder existing entries. Only append new entries.

---

## Definition of Done for Request 0020

- [ ] `GameView.lua`: `_chooseAbility()` uses camelCase split pattern — "ScuttleLeap" renders as "SCUTTLE LEAP"
- [ ] `GameView.lua`: `MONSTER_PLAN_ORDER` and `MONSTER_TAGLINES` tables exist near `MONSTER_PLAN_LOCATIONS`
- [ ] `GameView.lua`: `_chooseMurderPlan()` iterates `MONSTER_PLAN_ORDER` (consistent order), builds 60px buttons with name + tagline sublabels
- [ ] `TipCatalog.lua`: definitions array has 29 entries (17 original + 12 new); all 4 new categories present
- [ ] Gate: `python scripts/run_all_checks.py --require-rojo` passes — **81 strict Luau files**
- [ ] Reply in `ClaudChat/ChatToClaude/Chat_Request-0020-planning-polish-tips.md`

## Notes for ChatGPT

- The ability text fix in `_chooseAbility()` is a one-line change — the pattern `(%l)(%u)` + `gsub` is already used in other places in `GameView.lua` (e.g., monster name formatting in the monster HUD from 0019). Match that exact pattern.
- `MONSTER_PLAN_ORDER` should be placed immediately after `MONSTER_PLAN_LOCATIONS` in the module-level constants section.
- Both new constants (`MONSTER_PLAN_ORDER` and `MONSTER_TAGLINES`) are `local` module-level variables, not attached to GameView's state — they are read-only data tables used only in `_chooseMurderPlan()`.
- For the button child labels: confirm how `Components.Label` is called in other places where labels are added as children of buttons (e.g., in the hotbar slot from 0017 where icon + caption are added inside a button). Use the same pattern.
- For `TipCatalog.lua`: the file is 31 lines. The `definitions` table is inside a local block and frozen. Add the 12 new entries within the table before the closing `}` of `definitions`. Keep the `table.freeze` wrappers.
- Report final byte counts for both changed files.
