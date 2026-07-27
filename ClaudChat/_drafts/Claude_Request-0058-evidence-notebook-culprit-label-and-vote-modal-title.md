# Claude_Request-0058 — Evidence Notebook "CULPRIT CLUES" Label + Vote Modal Title Role-Aware

**Base commit:** c189a55
**Wave:** 2 (Agent A: GameView.lua _updateEvidence label + empty-state; Agent B: GameView.lua vote modal title in _updateVote)

---

## Preamble — 0057 Review

Request 0057 is accepted. All four RoundController toast call-sites are role-branched: Campfire transition (Murderer sees "Stay calm. Deflect suspicion."), all-votes-in (Murderer → DangerBright "Your fate is decided.", Ghost → Info), ghost post-death (Murderer → "You have been unmasked"), non-target elimination (Murderer → Success "ELIMINATED"). All 83 checks passed.

---

## Mission

Two high-impact label/text gaps in GameView.lua discovered by full-file audit:

1. **`_updateEvidence`** — the evidence notebook summary row always reads `"CULPRIT CLUES  N"`. The word `CULPRIT` is the label for evidence posted against the Murderer, visible to the Murderer every time they open the notebook. The Murderer sees themselves labeled as the culprit on every card. Additionally, the empty-state instruction `"Search rooms, objects, and attack sites."` instructs the Murderer to gather clues as if they are a detective, and tells Ghosts to search rooms they physically cannot enter.

2. **`_buildVote` / `_updateVote`** — the vote modal title is hardcoded as `"CAMPFIRE ACCUSATION"` in the modal constructor and never updated by role. When the Murderer (alive) opens the vote modal, the title correctly shows their warning label (already role-differentiated by 0047), but the main header still says `"CAMPFIRE ACCUSATION"` — framing the vote as an accusation directed at others, not at the Murderer.

---

## Agent A — `src/client/UI/GameView.lua` (_updateEvidence)

### A1. Pre-implementation inspection

Agent A must read `_updateEvidence` (approximately lines 3127–3420) and confirm:
1. Exactly how the `"CULPRIT CLUES"` string appears — is it a label text set directly, or passed through a helper?
2. How `state.player` (with `.role` and `.isGhost`) is accessible in this function. Check whether it receives `state` directly or reads from `self`.
3. The exact text of the empty-state label (approximately line 3410) and how it is set.
4. How the per-card channel tag `"CULPRIT"` is applied — is it a string passed to `addEvidence()` or set on a label inside the card builder?

### A2. Evidence notebook summary — relabel "CULPRIT CLUES" for Murderer

**Context:** The summary row shows three counters: `CULPRIT CLUES`, `MONSTER CLUES`, and `MYSTERY X/Y`. For the Murderer, `CULPRIT CLUES` refers to evidence against themselves.

**Target behavior:**
- Murderer: label reads `"EVIDENCE AGAINST YOU"`
- All other roles: label reads `"CULPRIT CLUES"` (unchanged)

```lua
local localRole = readString(state, "player.role", "")  -- or however role is read here
local culpritLabel = if localRole == "Murderer"
    then "EVIDENCE AGAINST YOU"
    else "CULPRIT CLUES"
-- use culpritLabel wherever "CULPRIT CLUES" is currently hardcoded in the summary
```

**Constraints:**
- Only the summary counter label changes. The counter value (the number) is unchanged.
- `MONSTER CLUES` and `MYSTERY X/Y` labels are unchanged for all roles.
- The per-card `"CULPRIT"` channel tag on individual evidence cards is NOT changed in this request (it is a separate label inside the card; leave it for a follow-up if needed).

### A3. Evidence empty-state — role-aware instruction text

**Context:** When no evidence has been posted, a label reads `"No evidence has been posted. Search rooms, objects, and attack sites."` This is camper-only advice.

**Target behavior:**

| Role | Empty-state text |
|---|---|
| Murderer | `"No evidence has been posted yet. Monitor the board as the investigation continues."` |
| Ghost (isGhost == true) | `"No evidence has been posted. Watch as the survivors investigate."` |
| Living camper / Spectator | `"No evidence has been posted. Search rooms, objects, and attack sites."` (unchanged) |

```lua
local localRole   = readString(state, "player.role", "")
local localIsGhost = readBoolean(state, "player.isGhost", false)

local emptyText = if localRole == "Murderer"
    then "No evidence has been posted yet. Monitor the board as the investigation continues."
    elseif localIsGhost
    then "No evidence has been posted. Watch as the survivors investigate."
    else "No evidence has been posted. Search rooms, objects, and attack sites."
```

**Constraints:**
- `readBoolean` is already defined as a local helper in GameView.lua — do not add a new definition.
- The empty-state check condition (whatever triggers the label to show) is unchanged.
- If the empty-state label is shared with the non-empty path, only branch the text assignment, not the visibility logic.

---

## Agent B — `src/client/UI/GameView.lua` (vote modal title)

### B1. Pre-implementation inspection

Agent B must read `_buildVote` (approximately line 1417) and `_updateVote` (approximately lines 3542–3606) and confirm:
1. Exactly how `"CAMPFIRE ACCUSATION"` is set — `makeHeader(self.voteModal, "CAMPFIRE ACCUSATION", ...)` or a direct label assignment.
2. Whether the header label handle is already stored on `self` (e.g., `self.voteModalHeader`) or is a local variable in `_buildVote` that goes out of scope.
3. Whether `_updateVote` already receives `player` (with `.role`) — if so, where.

### B2. Vote modal title — branch by role in _updateVote

**Context:** `_buildVote` is the constructor — the modal is built once and reused. The title set at build time persists for the round. Role-aware text must be applied in `_updateVote`, which runs on every state update while the vote modal is visible.

**Target behavior:**

| Role | Modal title |
|---|---|
| Murderer (alive) | `"CAMPFIRE VOTE"` |
| All other roles | `"CAMPFIRE ACCUSATION"` (unchanged) |

**Implementation:**

Step 1 — In `_buildVote`, store a reference to the title label on `self`:
```lua
-- If makeHeader returns the label or stores it, capture it:
self.voteModalTitleLabel = <the label created by makeHeader>
```
Only add this if `self.voteModalTitleLabel` is not already stored. Inspect first.

Step 2 — In `_updateVote`, after the existing `voteWarningLabel` role-check, update the title:
```lua
if self.voteModalTitleLabel then
    local localRole = readString(player, "role", "")
    self.voteModalTitleLabel.Text = if localRole == "Murderer"
        then "CAMPFIRE VOTE"
        else "CAMPFIRE ACCUSATION"
end
```

**Constraints:**
- If `makeHeader` does not return the label and does not store it externally, use `self.voteModal:FindFirstChild` to locate the header title label by name (inspect the modal's child structure).
- The letter-spacing on the header is not changed — only `.Text`. If the header uses `Components.SetLetterspacedText`, use that function instead of direct `.Text` assignment, but only if the existing code already uses it for this label (inspect first).
- `_updateVote` already has access to `player` — confirm and use the same reference.
- Only the title text changes. All other modal behavior — vote buttons, warning label, faction strips, animation, submit logic — is completely unchanged.

---

## Acceptance Criteria

**A2 — Evidence summary label:**
- [ ] Murderer: notebook summary shows `"EVIDENCE AGAINST YOU  N"` (where N is the count)
- [ ] All other roles: `"CULPRIT CLUES  N"` (unchanged)
- [ ] MONSTER CLUES and MYSTERY counters unchanged for all roles

**A3 — Evidence empty-state:**
- [ ] Murderer: `"No evidence has been posted yet. Monitor the board as the investigation continues."`
- [ ] Ghost: `"No evidence has been posted. Watch as the survivors investigate."`
- [ ] Living camper / Spectator: `"No evidence has been posted. Search rooms, objects, and attack sites."` (unchanged)

**B2 — Vote modal title:**
- [ ] Murderer (alive, in Campfire): modal title = `"CAMPFIRE VOTE"`
- [ ] All other living roles: modal title = `"CAMPFIRE ACCUSATION"` (unchanged)
- [ ] All other modal behavior unchanged

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/client/UI/GameView.lua` | A | _updateEvidence: "EVIDENCE AGAINST YOU" label for Murderer; role-aware empty-state |
| `src/client/UI/GameView.lua` | B | _updateVote: vote modal title "CAMPFIRE VOTE" for Murderer, "CAMPFIRE ACCUSATION" for others |
