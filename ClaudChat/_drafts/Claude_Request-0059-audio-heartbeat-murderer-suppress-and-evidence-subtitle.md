# Claude_Request-0059 — AudioController Heartbeat Suppress + EvidenceFound/VoteOpen Subtitle Role-Aware

**Base commit:** (updated after 0058 lands)
**Wave:** 2 (Agent A: RoundController.lua heartbeat dread suppress for Murderer/Ghost/Spectator; Agent B: AudioController.lua EvidenceFound + VoteOpen subtitle role-branching)

---

## Preamble — 0058 Review

Request 0058 is accepted. Evidence notebook summary label reads "EVIDENCE AGAINST YOU" for Murderer; empty-state text is role-branched for Murderer and Ghost; vote modal title reads "CAMPFIRE VOTE" for Murderer, "CAMPFIRE ACCUSATION" for others. All 83 checks passed.

---

## Mission

Two active audio bugs discovered by codebase audit:

1. **Heartbeat dread (`SetHeartbeatIntensity`)** — `RoundController.lua` computes `monsterDreadFraction` from the distance between the local player and the monster. When the local player IS the Murderer, that distance is `0`, producing `dreadFraction = 1.0` — so the Murderer plays the heartbeat audio at maximum intensity for themselves. Ghost and Spectator players also receive the heartbeat with no suppression. The heartbeat is a survival-terror cue. The Murderer should never hear it for their own presence.

2. **`EvidenceFound` and `VoteOpen` subtitle text** — `AudioController.lua`'s `Update()` calls `PlayCue("EvidenceFound")` every time evidence count increases, unconditionally. The subtitle fires as `"Evidence discovered."` for all roles including the Murderer, who is the subject of the evidence. Similarly `PlayCue` via `PlayUIEvent("vote")` fires `"The campfire vote is open."` for all roles — the Murderer should see an adversarial framing.

---

## Agent A — `src/client/Controllers/RoundController.lua` (heartbeat dread suppress)

### A1. Pre-implementation inspection

Agent A must read the heartbeat call site and confirm:

1. Find `monsterDreadFraction` (approximately lines 163–184). Note exactly how `dreadFraction` is computed from `snapshotState` — specifically whether it reads the monster's position relative to the local player's position, and whether there is already any role check.
2. Find `SetHeartbeatIntensity` call (approximately line 1047). Confirm `roleName` and `isGhost` are in scope at that line — they should be (derived at function scope from snapshot). Also confirm whether `Spectator` role is distinguishable from living camper at this call site.
3. Confirm the exact call signature: `AudioController.SetHeartbeatIntensity(intensity: number)` vs `AudioController:SetHeartbeatIntensity(intensity)`.

### A2. Suppress heartbeat for Murderer, Ghost, and Spectator

**Target behavior:** `SetHeartbeatIntensity` must not fire with non-zero intensity for:
- Murderer: they are the monster; the dread audio is their own presence
- Ghost: they are dead; they cannot be hunted
- Spectator: they are an observer; they cannot be in danger

**Implementation:** Wrap the existing `SetHeartbeatIntensity(dreadFraction)` call in a role guard:

```lua
-- Before (approximate):
AudioController.SetHeartbeatIntensity(dreadFraction)

-- After:
if roleName ~= "Murderer" and not isGhost and roleName ~= "Spectator" then
    AudioController.SetHeartbeatIntensity(dreadFraction)
else
    AudioController.SetHeartbeatIntensity(0)
end
```

**Constraints:**
- The `monsterDreadFraction` computation itself is NOT changed — only the call to `SetHeartbeatIntensity` is guarded.
- If `AudioController.SetHeartbeatIntensity(0)` is already called elsewhere for these roles (e.g., on phase end), this guard is still required because the update loop fires continuously during the round.
- If `roleName` is derived from `snapshotState` at the start of the containing function, no new state reads are needed — use the existing variable.
- Dead Murderer (`isGhost == true`): `isGhost` guard already covers them; the Murderer check covers the alive Murderer case. Both are correct with the combined guard.

---

## Agent B — `src/client/Controllers/AudioController.lua` (EvidenceFound + VoteOpen subtitle)

### B1. Pre-implementation inspection

Agent B must read the file and confirm:

1. Find `PlayCue` signature (approximately lines 290–316). Confirm the second parameter is `subtitle: string?` — if provided it overrides the definition's built-in subtitle.
2. Find `Update()` call to `PlayCue("EvidenceFound")` (approximately line 447). Confirm how `state` is passed into `Update` — specifically whether `state.player.role` and `state.player.isGhost` are accessible from `state` at this call site.
3. Find `PlayUIEvent("vote")` (approximately line 436) which resolves to `PlayCue("VoteOpen")` via `UISoundMap`. Confirm whether the role is accessible at this call site.
4. Check whether `readString`/`readBoolean` helpers exist in this file or need to be added.

### B2. EvidenceFound — role-aware subtitle override

**Current code (approximate):**
```lua
-- In Update(), triggered when evidenceFound count increases:
self:PlayCue("EvidenceFound")
```

**Target behavior:**

| Role | Subtitle |
|---|---|
| Murderer | `"Evidence found against you."` |
| Ghost | `"Evidence discovered."` (unchanged) |
| Spectator | `"Evidence discovered."` (unchanged) |
| Living camper | `"Evidence discovered."` (unchanged) |

**Implementation:** Pass a role-specific subtitle override as the second argument:

```lua
local evidenceSubtitle = if readString(state, "player.role", "") == "Murderer"
    then "Evidence found against you."
    else nil  -- nil means: use the definition's built-in subtitle ("Evidence discovered.")
self:PlayCue("EvidenceFound", evidenceSubtitle)
```

**Constraints:**
- `PlayCue`'s second argument is already `subtitle: string?` — `nil` means "use the definition default." This is zero-risk to pass.
- If `readString` is not in scope in AudioController, add it as a one-liner local at the top of the file using the same pattern as GameView.lua: `local function readString(t, k, d) ... end`.
- Do not modify the `DEFINITIONS` table entry for `EvidenceFound` — only the call site changes.

### B3. VoteOpen — role-aware subtitle override

**Current code (approximate):**
```lua
-- In Update(), triggered when phase transitions to "Campfire":
self:PlayUIEvent("vote")  -- resolves to PlayCue("VoteOpen")
```

The existing `PlayUIEvent` wrapper calls `PlayCue` internally. Check whether `PlayUIEvent` accepts a subtitle override as a second argument. If it does, pass it. If it does not, either:
- (preferred) Call `self:PlayCue("VoteOpen", voteSubtitle)` directly instead of `PlayUIEvent("vote")`, or
- Add a subtitle override parameter to `PlayUIEvent` (only if the change is minimal — 1–2 lines).

**Target behavior:**

| Role | Subtitle |
|---|---|
| Murderer | `"They're voting. Choose your words carefully."` |
| Ghost | `"The campfire vote is open."` (unchanged) |
| Spectator | `"The campfire vote is open."` (unchanged) |
| Living camper | `"The campfire vote is open."` (unchanged) |

```lua
local voteSubtitle = if readString(state, "player.role", "") == "Murderer"
    then "They're voting. Choose your words carefully."
    else nil
-- Pass voteSubtitle via PlayCue or PlayUIEvent depending on what you find
```

**Constraints:**
- If `PlayUIEvent` cannot accept a subtitle, replace the single `PlayUIEvent("vote")` call with `PlayCue("VoteOpen", voteSubtitle)` — do not restructure `PlayUIEvent` itself if that requires touching other call sites.
- The sound played (which audio asset fires) is unchanged — only the text subtitle changes.
- `state` must be accessible at the `Update` call site where phase == "Campfire" is detected. Confirm this during inspection.

---

## Acceptance Criteria

**A2 — Heartbeat dread suppress:**
- [ ] Murderer: `SetHeartbeatIntensity` called with `0` always (no heartbeat for own presence)
- [ ] Ghost: `SetHeartbeatIntensity(0)` always (dead, cannot be hunted)
- [ ] Spectator: `SetHeartbeatIntensity(0)` always (observer, not in danger)
- [ ] Living camper: `SetHeartbeatIntensity(dreadFraction)` unchanged — full range 0.0–1.0
- [ ] `monsterDreadFraction` computation unchanged

**B2 — EvidenceFound subtitle:**
- [ ] Murderer: subtitle = `"Evidence found against you."`
- [ ] All other roles: subtitle = `"Evidence discovered."` (definition default, unchanged)

**B3 — VoteOpen subtitle:**
- [ ] Murderer: subtitle = `"They're voting. Choose your words carefully."`
- [ ] All other roles: subtitle = `"The campfire vote is open."` (definition default, unchanged)

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|---|---|---|
| `src/client/Controllers/RoundController.lua` | A | Wrap `SetHeartbeatIntensity` call in role guard; suppress for Murderer/Ghost/Spectator |
| `src/client/Controllers/AudioController.lua` | B | `PlayCue("EvidenceFound")` and `PlayCue("VoteOpen")` pass role-specific subtitle overrides |
