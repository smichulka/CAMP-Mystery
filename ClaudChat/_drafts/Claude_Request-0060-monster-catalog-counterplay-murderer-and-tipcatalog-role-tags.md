# Claude_Request-0060 — PublicMonsterCatalog Counterplay Suppress for Murderer + TipCatalog Role Tags

**Base commit:** (updated after 0059 lands)
**Wave:** 2 (Agent A: PublicMonsterCatalog.lua — suppress counterplay block for Murderer viewing their own monster; Agent B: TipCatalog.lua — add role exclusion tags to Tier-1 Murderer-defeating tips + consumer role filter)

---

## Preamble — 0059 Review

Request 0059 is accepted. Murderer no longer hears heartbeat dread audio for their own presence; Ghost and Spectator heartbeat suppressed; EvidenceFound subtitle reads "Evidence found against you." for Murderer; VoteOpen subtitle reads "They're voting. Choose your words carefully." for Murderer. All 83 checks passed.

---

## Mission

Two catalog/config files show role-naive content that directly exposes the Murderer's defeat conditions:

1. **`PublicMonsterCatalog.lua`** — All 8 monster entries have a `counterplay` block describing how to defeat the monster: which equipment counters it, what range/light/movement disrupts it. This is shown verbatim on the monster info panel. When the Murderer opens the panel for their assigned monster, they read a step-by-step guide on how to stop themselves.

2. **`TipCatalog.lua`** — 9 "Tier-1" tips in the lobby cycling ticker describe specific counter-tactics against the monster (e.g., "The Flashlight is your most reliable defense", "Monster Traps slow down a monster mid-hunt", per-monster escape instructions). These are shown to all roles. The Murderer reads a rotation of their own defeat conditions.

---

## Agent A — `src/shared/Config/PublicMonsterCatalog.lua` (counterplay suppress for Murderer)

### A1. Pre-implementation inspection

Agent A must read the file and confirm:

1. Confirm the exact structure of a monster entry — specifically whether `counterplay` is a nested table with `.summary` and `.recommendedEquipment` keys, or a flat string, or another structure.
2. Identify whether there is already a `murdererNote` or `role` field on any entry.
3. Find the consumer of this catalog — where is `PublicMonsterCatalog` imported and used to render a monster info panel? Search for `require.*PublicMonsterCatalog` or `PublicMonsterCatalog\[` across `src/client/`. The consumer call site is where the role filter must be applied.

### A2. Add a `murdererCounterplay` field to each monster entry

**Approach:** Rather than deleting the `counterplay` block (which breaks the consumer for non-Murderer roles), add a parallel `murdererNote` field to each entry that is a role-appropriate framing of the same information from the Murderer's perspective.

Add to each of the 8 monster entries:

| Monster | `murdererNote` |
|---|---|
| BabyAlien | `"You are fast at close range. Keep leaping range short and don't let prey isolate you in bright areas."` |
| Screamer | `"Your scream is range-dependent. Break line of sight early to buy recovery time and prevent campers from escaping."` |
| Wendigo | `"Group light sources are your threat. Isolate targets away from campfire zones and flare coverage."` |
| ShadowMonster | `"Avoid sustained direct light. Move through unlit corridors and strike before light establishes."` |
| Chupacabra | `"A UV or flashlight burst can release your latch. Time strikes when victims are isolated and unequipped."` |
| Dullahan | `"Build pursuit speed early. Break away from corners that interrupt your line — speed is your advantage."` |
| Entity | `"Your arrival silhouette is visible. Vary anchor selection and approach from unexpected angles."` |
| Banshee | `"Give campers time to enter wail radius before full attack. A quick escape means no disorientation buildup."` |

### A3. Consumer — filter `counterplay` display by role

In the consumer file (wherever the monster info panel renders `counterplay.summary` and `counterplay.recommendedEquipment`):

**Pre-implementation step:** Agent A must find the rendering call site by searching for `counterplay` in client code. Read the render function and confirm:
- Whether `localRole` (the player's current role) is already available at that call site.
- Whether the monster shown corresponds to the player's assigned monster (i.e., panel shows the Murderer's own monster).
- How the panel's text labels are updated.

**Target behavior:**

```lua
-- In the monster panel render function:
local isOwnMonster = (localRole == "Murderer" and displayedMonsterId == localMonsterId)

if isOwnMonster then
    -- Show murdererNote instead of counterplay fields
    counterplaySummaryLabel.Text = catalogEntry.murdererNote or ""
    counterplayEquipmentLabel.Visible = false  -- hide the equipment list; it names camper items
else
    -- Show standard counterplay (unchanged)
    counterplaySummaryLabel.Text = catalogEntry.counterplay.summary
    counterplayEquipmentLabel.Text = table.concat(catalogEntry.counterplay.recommendedEquipment, ", ")
    counterplayEquipmentLabel.Visible = true
end
```

**Constraints:**
- If `localMonsterId` is not available at the render site, use only the `isOwnMonster = localRole == "Murderer"` guard without the monster-ID check (conservative: all Murderer views suppress counterplay regardless of which monster is displayed).
- `catalogEntry.counterplay` is not deleted — other consumers (Ghost info panel, Spectator view, post-round summary) are unchanged.
- If the panel is only shown on the round-end summary screen and only during the `"Murderer"` outcome reveal, verify whether the Murderer can even see the panel during the round. Report this finding; if counterplay is never shown to the Murderer mid-round, the `murdererNote` addition is still valuable for the post-round monster reveal.

---

## Agent B — `src/shared/Config/TipCatalog.lua` + consumer (role-filtered tips)

### B1. Pre-implementation inspection

Agent B must:

1. Read `TipCatalog.lua` fully. Confirm the exact `definitions` table structure — specifically whether each entry is `{ body = "..." }` or `{ body = "...", category = "..." }` or another shape.
2. Search for `TipCatalog` consumers in `src/client/` — where is `require.*TipCatalog` used? The consumer is where lobby tips are cycled and displayed. Read the consumer to confirm:
   - Whether it already filters entries by any field.
   - Whether `localRole` is accessible at the tip-render call site.
   - Whether tips cycle sequentially or randomly.
3. Confirm the exact line numbers of the 9 Tier-1 tips listed below so edits can be targeted.

### B2. Add `excludeRoles` field to Tier-1 Murderer-defeating tips

**Approach:** Add an optional `excludeRoles: {string}` array to the 9 Tier-1 entries. The consumer reads this field and skips the tip when the local player's role appears in the array. This is backward-compatible — entries without `excludeRoles` show to all roles.

Target entries (add `excludeRoles = {"Murderer"}` to each):

| Approx. line | Tip body (for identification) |
|---|---|
| 15 | `"Light, distance, and teammates can improve your odds after dark."` |
| 29 | `"The Flashlight is your most reliable defense — keep it charged and pointed at threats."` |
| 30 | `"The EMF Reader spikes near recent monster activity and can expose the type of threat."` |
| 32 | `"Monster Traps slow down a monster mid-hunt. Place them on likely approach routes before nightfall."` |
| 37 | `"The Guard and Protector carry Flare Lanterns. Sustained light limits the Shadow Monster's movement."` |
| 41 | `"Break line of sight or change floors to disrupt the Dullahan before it reaches pursuit speed."` |
| 42 | `"UV light and direct flashlights can remove the Chupacabra's latch faster than waiting it out."` |
| 43 | `"Leave the wail radius immediately when the Banshee starts its attack — hesitation means injury."` |
| 44 | `"The Entity teleports between anchors. Watch for the arrival silhouette and move away from anchor points."` |

**Result for each of the 9 entries:**
```lua
{
    body = "...",  -- existing body unchanged
    excludeRoles = {"Murderer"},
},
```

### B3. Consumer — filter tips by `excludeRoles` before display

In the consumer file (wherever lobby tips are selected and rendered):

**If tips are shown sequentially (cycled by index):** Skip entries whose `excludeRoles` contains `localRole` when advancing the tip index. Advance to the next non-excluded tip rather than showing a gap.

**If tips are shown randomly:** Filter the full `definitions` table to a role-appropriate subset before selecting a random index.

**Implementation (sequential cycle, typical pattern):**

```lua
local function nextTip(definitions, currentIndex, localRole)
    local n = #definitions
    for i = 1, n do
        local nextIdx = ((currentIndex - 1 + i) % n) + 1
        local entry = definitions[nextIdx]
        local excluded = false
        if entry.excludeRoles then
            for _, r in entry.excludeRoles do
                if r == localRole then excluded = true; break end
            end
        end
        if not excluded then return nextIdx end
    end
    return currentIndex  -- fallback: no change if all tips excluded (shouldn't happen)
end
```

**Constraints:**
- Only the 9 Tier-1 entries get `excludeRoles`. All other 21 entries have no `excludeRoles` field and are shown to all roles.
- Ghost and Spectator: the 9 Tier-1 tips are still shown to Ghost and Spectator (they are observers and the content is informational for them). Only Murderer is excluded.
- `localRole` must be whatever role string the consumer already has access to. If it requires a new state read, use the same `readString(state, "player.role", "")` pattern.
- The tip cycling interval, animation, and label rendering are completely unchanged.

---

## Acceptance Criteria

**A2/A3 — PublicMonsterCatalog counterplay:**
- [ ] All 8 monster entries have a `murdererNote` field with Murderer-perspective framing
- [ ] Monster info panel: Murderer viewing their assigned monster sees `murdererNote` text, NOT `counterplay.summary`
- [ ] Monster info panel: Murderer seeing their monster hides `recommendedEquipment` list
- [ ] All non-Murderer views: panel shows `counterplay.summary` and `recommendedEquipment` unchanged
- [ ] No `counterplay` block deleted from any entry

**B2/B3 — TipCatalog role filter:**
- [ ] 9 Tier-1 entries have `excludeRoles = {"Murderer"}` field
- [ ] 21 remaining entries have no `excludeRoles` field and show to all roles
- [ ] Murderer lobby tip cycling skips all 9 Tier-1 entries
- [ ] Ghost and Spectator: all 30 tips still visible (no exclusion for them)
- [ ] Tip cycling/animation unchanged

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|---|---|---|
| `src/shared/Config/PublicMonsterCatalog.lua` | A | Add `murdererNote` field to all 8 monster entries |
| Consumer of PublicMonsterCatalog (client UI file) | A | Filter counterplay display by role at render site |
| `src/shared/Config/TipCatalog.lua` | B | Add `excludeRoles = {"Murderer"}` to 9 Tier-1 tips |
| Consumer of TipCatalog (lobby tip cycling) | B | Skip `excludeRoles`-matched entries when local role is Murderer |
