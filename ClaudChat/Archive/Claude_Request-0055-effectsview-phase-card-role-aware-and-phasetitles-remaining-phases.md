# Claude_Request-0055 — EffectsView Phase Card Role-Awareness + PhaseTitles Remaining Phases

**Base commit:** cb29f09
**Wave:** 2 (Agent A: EffectsView.lua PHASE_COPY role branch; Agent B: PhaseTitles.lua murderer sub-keys for Investigation/Day/Campfire/Resolution)

---

## Preamble — 0054 Review

Request 0054 is accepted. Monster ability panel shows per-ability named rows with individual cooldowns. PhaseTips murderer variant verified/added. All 83 checks passed.

---

## Mission

Two high-impact gaps in phase-transition copy, both discovered by server-side audit:

1. **`EffectsView.lua` `PHASE_COPY` table** is entirely camper-framed and has no role branch in the `Update` method. During `MurderPlanning`, the Murderer sees "SOMETHING IS BEING PLANNED / The camp grows quiet. Stay alert." — third-person framing of their own action. During `Investigation`, they see "protect each other and survive" — the opposite of their goal. This is the **most visible UI element** on a phase change: a full-width animated card visible for ~4 seconds. The Murderer receives double wrong framing here (server announcement + EffectsView card both fire camper copy on the same phase transition).

2. **`PhaseTitles.lua`** has `murderer` sub-keys only for `MurderPlanning` and `NightTransform` (added in 0049). The four remaining active phases — `Investigation`, `Day`, `Campfire`, and `Resolution` — have no `murderer` sub-key. `Investigation` is the longest phase in the game. "Search for the truth" as a persistent screen-title sub-header while the Murderer is actively avoiding discovery is high-impact immersion breakage.

---

## Agent B — `src/shared/Config/PhaseTitles.lua` (remaining murderer sub-keys)

### B1. Add murderer sub-keys to Investigation, Day, Campfire, Resolution

**Context:** The existing `PhaseTitleOverride` type (line 3) and the `MurderPlanningMurderer`/`NightTransformMurderer` pattern established in 0049. Each existing `murderer = { title, subtitle, tip }` entry uses the same field names.

Add `murderer` sub-keys to the four remaining entries:

```lua
Investigation = table.freeze({
    title    = "INVESTIGATION BEGINS",
    subtitle = "Search for the truth.",
    murderer = {
        title    = "THEY ARE SEARCHING",
        subtitle = "Stay hidden. Destroy the evidence.",
        tip      = "The evidence board builds against you. Steer suspicion before it locks in.",
    },
}),

Day = table.freeze({
    title    = "A NEW DAY",
    subtitle = "What did the night reveal?",
    murderer = {
        title    = "A NEW DAY",
        subtitle = "Hide in plain sight. Play your role.",
        tip      = "Act like a Camper. Suspicion spreads fastest when you seem nervous.",
    },
}),

Campfire = table.freeze({
    title    = "CAMPFIRE VOTE",
    subtitle = "Choose your suspect.",
    murderer = {
        title    = "THE VOTE",
        subtitle = "Steer the blame. Survive the accusations.",
        tip      = "A tie breaks in your favor. Spread doubt before votes are cast.",
    },
}),

Resolution = table.freeze({
    title    = "MYSTERY RESOLVED",
    subtitle = "The verdict is in.",
    murderer = {
        title    = "THE VERDICT",
        subtitle = "Did they catch you?",
        tip      = "",
    },
}),
```

**Constraints:**
- `tip` may be an empty string for Resolution (no actionable tip after voting closes).
- The `table.freeze` wrapper must be preserved on each entry — wrap the entire updated record including the `murderer` sub-table.
- No other entries (Lobby, Loading, Transition phases) are changed.
- All existing camper-path consumers of PhaseTitles are unchanged — the `murderer` sub-key is opt-in.

---

## Agent A — `src/client/UI/EffectsView.lua` (PHASE_COPY role branch)

### A1. Pre-implementation inspection

**Agent A must inspect the file before writing any code.** Specifically:

1. Locate the `PHASE_COPY` table (approximately lines 51–88). Note all keys present and whether a `murderer` sub-table structure already exists on any entry.
2. Locate the `Update` method (approximately lines 738–755). Confirm:
   - How `phase` is read from state
   - How `localRole` (or `state.player.role`) is read — does it already exist at this call site?
   - How `ShowPhase(title, body)` is called
3. Note whether `PHASE_COPY` has entries for all 8 phases or only a subset.

### A2. PHASE_COPY table — add murderer sub-keys

Add a `murderer` sub-table to each entry that needs Murderer differentiation. Use the same structure as the existing table.

Target murderer copy per phase:

| Phase | murderer.title | murderer.body |
|---|---|---|
| MurderPlanning | "YOUR PLAN IS SET" | "You chose your prey. Strike before dawn." |
| NightTransform | "YOU ARE THE MONSTER" | "The hunt begins. Move in shadow." |
| Investigation | "THEY ARE SEARCHING" | "Stay hidden. Let them doubt each other." |
| Day | "A NEW DAY" | "Play your role. Act like the rest." |
| Campfire | "THE VOTE" | "Steer the blame. A tie favors you." |
| Resolution | "THE VERDICT" | "Did they catch you?" |

For any phase not listed above (e.g., Lobby, Rewards, Transition), the murderer sub-key is not needed — use existing camper copy.

### A3. Update method — branch by role before calling ShowPhase

**Context:** The `Update` method currently selects copy by phase and calls `ShowPhase` unconditionally.

Add a role check before selecting copy:

```lua
local copy = PHASE_COPY[phase]
if copy then
    local localRole = readString(state, "player.role", "")  -- or however role is read at this site
    local selected = if localRole == "Murderer" and copy.murderer
        then copy.murderer
        else copy

    if selected.title then
        self:ShowPhase(selected.title, selected.body or "")
    end
end
```

**Constraints:**
- `localRole` derivation must use whatever role-reading pattern is already established in this file (inspect existing `readString` / `state.player.role` usage first).
- If `localRole` is not available at this call site without a significant plumbing change, use a `readString` call on `state` with the same key path used elsewhere in EffectsView.
- Ghost players: do NOT add Ghost-differentiated copy in this request. That can be a follow-up. For now, Ghost players fall through to camper copy.
- If `ShowPhase` is called with separate title and body arguments vs a single table, match the existing call signature exactly.
- No animation, timing, or visual parameters change — only the text selected.
- No module-level variables added.

---

## Acceptance Criteria

**PhaseTitles — B1:**
- [ ] `Investigation.murderer.title` = `"THEY ARE SEARCHING"`
- [ ] `Investigation.murderer.subtitle` = `"Stay hidden. Destroy the evidence."`
- [ ] `Day.murderer.subtitle` = `"Hide in plain sight. Play your role."`
- [ ] `Campfire.murderer.subtitle` = `"Steer the blame. Survive the accusations."`
- [ ] `Resolution.murderer.title` = `"THE VERDICT"`
- [ ] All existing camper entries unchanged
- [ ] `table.freeze` preserved on all entries

**EffectsView — A2/A3 PHASE_COPY role branch:**
- [ ] Murderer in MurderPlanning: sees "YOUR PLAN IS SET" / "You chose your prey. Strike before dawn."
- [ ] Murderer in NightTransform: sees "YOU ARE THE MONSTER" / "The hunt begins. Move in shadow."
- [ ] Murderer in Investigation: sees "THEY ARE SEARCHING" / "Stay hidden. Let them doubt each other."
- [ ] Murderer in Campfire: sees "THE VOTE" / "Steer the blame. A tie favors you."
- [ ] All non-Murderer roles: see existing camper copy unchanged
- [ ] Animation, timing, layout unchanged

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/shared/Config/PhaseTitles.lua` | B | Add `murderer` sub-keys to Investigation, Day, Campfire, Resolution entries |
| `src/client/UI/EffectsView.lua` | A | Add `murderer` sub-tables to PHASE_COPY; branch Update by role before ShowPhase |
