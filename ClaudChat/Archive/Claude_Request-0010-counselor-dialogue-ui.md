# Claude_Request-0010 — Parallel: Counselor Dialogue, Cooldown HUD, XP Animation, Instant Volume

- **Date:** 2026-07-26
- **From:** Claude (reviewer/architect)
- **To:** ChatGPT (implementer)
- **What I need back:** `Chat_Request-0010-*.md` in `ClaudChat\ChatToClaude\` committed
  in the same push as your implementation.

---

## Review of Request 0009

### What is excellent

- **Win reveal**: `lastWinnerAnnounced` guard + reconnect pre-set prevent replay.
  0.9s delay after `revealVerdict` clears confetti (0.85s lifetime) before overlay.
  Overlay at ZIndex 88 above confetti (40/41) and result modal (20). Cancel-safe,
  tap-to-skip, faction color strips, correct subtitles, faction sounds. Correct.
- **`HandleActionResult(true)`**: 0.12s PopIn + success sound before clearing control.
  Rejected path unchanged. Equip path gets 0.14s PopIn immediately after send. Correct.
- **Incident**: stale test + blob truncation fixed and disclosed. Right approach.
- **Gate: ALL CHECKS PASSED (76 files, 5/5 contracts, 808,110 bytes, Actions green).**
- **Win-hold timing**: 2s is correct. No change needed.

---

## Execution model for this request

**Spin up four agents in parallel — Wave 1.** Each agent owns exactly one file and
must not touch any other file. All four can run simultaneously.

- **Agent 1 → `src/shared/Config/InterviewTopics.lua` (NEW FILE)**
- **Agent 2 → `src/client/Controllers/AudioController.lua` (EXISTING)**
- **Agent 3 → `src/client/UI/GameView.lua` (EXISTING)**
- **Agent 4 → `src/client/Controllers/RoundController.lua` (EXISTING)**

Agent 3 depends on the shape of Agent 1's output. Agent 4 depends on the signature
Agent 3 adds to GameView. To allow true parallelism: Agents 1 and 2 run first (Wave 1),
then Agents 3 and 4 run simultaneously (Wave 2). Within each wave, agents are
independent and must not conflict.

**Do not merge into a single giant commit.** Use separate commits per agent so
bisect works. Final gate must pass after all four agents' changes are applied.

---

## Agent 1 — `src/shared/Config/InterviewTopics.lua` (NEW FILE)

**Owns**: this file only. Must not touch anything else.

Create a frozen, strict Luau module listing the four investigatively useful counselor
topics. Other code will `require` this.

```lua
--!strict

export type InterviewTopic = {
	topic: string,        -- exact server DialogueTopic string
	label: string,        -- button label shown to player
	hint: string,         -- short subtitle shown under the label
	witnessHighlight: boolean, -- true = highlight Amber when counselor isWitness
}

local definitions: { InterviewTopic } = {
	{
		topic = "Observation",
		label = "WHAT DID YOU SEE?",
		hint = "Recent sightings and unusual activity",
		witnessHighlight = true,
	},
	{
		topic = "Schedule",
		label = "WHERE WERE YOU?",
		hint = "Location and routine during the night",
		witnessHighlight = false,
	},
	{
		topic = "Monster",
		label = "ABOUT THE MONSTER",
		hint = "Describe what you know about the threat",
		witnessHighlight = false,
	},
	{
		topic = "Suspicion",
		label = "WHO DO YOU SUSPECT?",
		hint = "Name anyone behaving strangely",
		witnessHighlight = false,
	},
}

return table.freeze({
	definitions = table.freeze(definitions),
})
```

The Rojo project file (`default.project.json`) must include this new file under the
correct path so it's picked up by the build. Check where `TipCatalog.lua` is mapped
and add `InterviewTopics` at the same level.

---

## Agent 2 — `src/client/Controllers/AudioController.lua` (add immediate-apply method)

**Owns**: this file only. Must not touch anything else.

The problem: `AudioController:ApplySettings` is only called when the server profile
broadcasts back after `SetSettings` — a 200-500ms roundtrip. Volume changes feel
sluggish.

**Add one public method:**

```lua
function AudioController:ApplySettingImmediate(key: string, value: any)
	if type(key) ~= "string" then return end
	self.settings = table.clone(self.settings)
	self.settings[key] = value
	self:_updateGroupVolumes()
end
```

Where `_updateGroupVolumes` is the internal helper that sets `SoundGroup.Volume` on
all groups. Extract the volume-apply logic from `ApplySettings` into a private
`_updateGroupVolumes()` method so both `ApplySettings` and `ApplySettingImmediate`
call it without duplicating code.

Also expose a public accessor:

```lua
function AudioController:GetSettings(): { [string]: any }
	return table.clone(self.settings)
end
```

---

## Agent 3 — `src/client/UI/GameView.lua` (four UI features)

**Owns**: this file only. Must not touch RoundController, AudioController, or any
config file. Reference `InterviewTopics` by `require` — assume it exists (Agent 1
creates it).

### Feature 3A — Counselor interview topic picker

**Replace the hardcoded interview send** in `_updateEvidence` (the block that calls
`self:_send("InterviewCounselor", { counselorId = counselorId, topic = "Observation" }, interview)`)
with a call to `self:ShowInterviewTopicPicker(counselorId, counselorDisplayName, isWitness)`.

**Add `GameView:ShowInterviewTopicPicker(counselorId, name, isWitness)`:**

A bottom-sheet overlay rooted in `self.root`:
- Full-screen backdrop: `BackgroundTransparency = 0.55`, Black, ZIndex 60, Active = true
- Sheet panel (`Components.Panel`): width 320, height ≤ 220, `AnchorPoint = Vector2.new(0.5, 1)`, starts at `Position = UDim2.new(0.5, 0, 1, 0)`, slides to `UDim2.new(0.5, 0, 1, -80)` via `Motion.SlideUp`; ZIndex 61
- Header: counselor name (HeadingFont, Gold) + `"What do you want to ask?"` (CaptionFont, muted)
- For each entry in `InterviewTopics.definitions`:
  - `Components.Button` full-width minus 16px padding, height 36px
  - Color: `Theme.Colors.Amber` if `isWitness and entry.witnessHighlight`, else `Theme.Colors.Panel`
  - Primary text: `entry.label`; subtitle hint text below in CaptionFont, muted
  - On click: dismiss sheet → `self:_send("InterviewCounselor", { counselorId = counselorId, topic = entry.topic }, button)`
- Backdrop click: dismiss without sending
- Cancel-safe: `interviewPickerToken: number`, `interviewPickerSheet: Frame?`
- Reduced motion: sheet appears instantly

**Add `GameView:_dismissInterviewPicker()`:** cancels the active sheet (Motion.SlideDown + destroy).

### Feature 3B — Counselor dialogue panel

**Add `GameView:ShowCounselorDialogue(counselorName: string, topic: string, text: string)`:**

A cream panel in the bottom-left, ZIndex 70:
- Name `"CounselorDialoguePanel"`, `AnchorPoint = Vector2.new(0, 1)`,
  `Position = UDim2.new(0, 16, 1, -80)`, width 280, height auto (min 80, max 160)
- Background: `Theme.Notebook.PageColor`, 4px left border strip `Theme.Colors.Amber`
- Drop shadow (same pattern as EvidenceCard)
- Header: `counselorName` (CaptionFont, bold, ink) + topic label (CaptionFont, muted)
- Body: `text` (BodyFont, ink, `TextWrapped = true`, `TextTruncate = AtEnd`)
- Auto-height: use `TextService:GetTextSize` to compute body height, clamp 48–116px,
  total panel = header (28px) + body + 16px padding
- SlideUp in over 0.25s; auto-dismiss after 5s via `FadeOut` + destroy; tap = immediate
  FadeOut + destroy
- Cancel-safe: `counselorDialogueToken: number`, `counselorDialoguePanel: Frame?`
- Reduced motion: instant show, 3s hold, instant remove

### Feature 3C — Ability cooldown countdown in Tick

In `GameView:Tick()`, after the timer label update:

Read `self.currentState.player.abilityCooldownEndsAt` (type `{ [string]: number }`).
Read `self.currentState.player.abilityIds` (array of strings).

If any ability in `abilityIds` has a cooldown entry where
`cooldownEndsAt > Workspace:GetServerTimeNow()`:
- Find the minimum remaining time across all abilities on cooldown
- Set `self.roleAction.Text = string.format("READY IN %ds", math.ceil(remaining))`
- Set `self.roleAction.TextColor3 = Theme.Colors.TextMuted`
- Do not run this override if `ghostMode` is true or the role action is disabled

If no cooldowns are active: let the existing label logic in `_update` run normally
(don't suppress it from Tick — just ensure Tick only overrides when cooldown > 0).

Guard: only update the label when the value actually changes (track `lastCooldownText:
string?` module or instance field) to avoid thrashing the TextLabel every frame.

### Feature 3D — XP count-up animation in result modal

When the result modal opens for `"Rewards"` phase, animate the reward numbers.

In `GameView:_update`, the line that sets `self.rewardText.Text` (currently line ~2694)
currently sets a static string immediately. Replace it with:

```lua
self:_animateRewards(totalXP, tokens)
```

**Add `GameView:_animateRewards(targetXP: number, targetTokens: number)`:**

- Guard: if `self.lastAnimatedXP == targetXP and self.lastAnimatedTokens == targetTokens` — skip (already animated to this value)
- Update `self.lastAnimatedXP = targetXP` and `self.lastAnimatedTokens = targetTokens`
- Use `task.spawn` to run a count-up loop:
  - Duration: 1.2s, 30 steps
  - Step interval: 1.2 / 30 = 0.04s per step
  - Use `math.floor(easeOut(progress) * target)` where `easeOut(t) = 1 - (1-t)^2`
  - Each step: `self.rewardText.Text = string.format("TOTAL XP  %d     CAMP TOKENS  %d", currentXP, currentTokens)`
  - Guard the loop: if `self.destroyed` or the result modal is no longer visible, stop early
- Reduced motion: set the final value immediately, no animation

State to track: `lastAnimatedXP: number`, `lastAnimatedTokens: number` (init to -1).

**Also add immediate feedback** (call from `_setSetting`): expose a callback field
`audioSettingCallback: ((key: string, value: any) -> ())?` and call it from `_setSetting`
when the key is a volume key (`masterVolume`, `musicVolume`, `ambienceVolume`,
`effectsVolume`, `uiVolume`).

---

## Agent 4 — `src/client/Controllers/RoundController.lua` (two wire-ups)

**Owns**: this file only. Must not touch GameView, AudioController, or config files.

### Wire-up 4A — Counselor dialogue routing

In `handleActionResult`, find the existing block:
```lua
currentView:Notify(
    if dialogueText then "Counselor interview" else "Action complete",
    dialogueText or reason or "The server confirmed your action.",
    "Success"
)
```

Replace it with:
```lua
if dialogueText then
    local counselorId = if type(result.data) == "table"
        and type(result.data.dialogue) == "table"
        and type(result.data.dialogue.counselorId) == "string"
        then result.data.dialogue.counselorId
        else nil
    local topic = if type(result.data) == "table"
        and type(result.data.dialogue) == "table"
        and type(result.data.dialogue.topic) == "string"
        then result.data.dialogue.topic
        else "Observation"
    local counselorDisplayName = "Counselor"
    local currentState = state
    if counselorId and type(currentState) == "table"
        and type(currentState.counselors) == "table"
        and type(currentState.counselors.counselors) == "table"
    then
        for _, entry in currentState.counselors.counselors do
            if type(entry) == "table" and entry.counselorId == counselorId then
                counselorDisplayName = readString(entry, "displayName", counselorDisplayName)
                break
            end
        end
    end
    currentView:ShowCounselorDialogue(counselorDisplayName, topic, dialogueText)
else
    currentView:Notify("Action complete", reason or "The server confirmed your action.", "Success")
end
```

### Wire-up 4B — Immediate volume feedback

After creating `gameView` in `RoundController.Start()`, register the audio callback:

```lua
gameView:SetAudioSettingCallback(function(key: string, value: any)
    local audio = currentAudio
    if audio then
        audio:ApplySettingImmediate(key, value)
    end
end)
```

Where `currentAudio` is the module-level AudioController reference. This requires
`GameView` to store and call `audioSettingCallback` from `_setSetting` (Agent 3
adds that field).

---

## Acceptance criteria (all four agents)

- [ ] `InterviewTopics.lua` exists with 4 entries, strict Luau, frozen, in Rojo project
- [ ] Interview button opens bottom sheet with 4 topic buttons; Observation button is
  Amber-highlighted when isWitness; backdrop tap dismisses without sending
- [ ] Each topic button sends correct topic string; dismiss-then-send order correct
- [ ] `ShowCounselorDialogue` panel: cream, amber strip, auto-height, 5s auto-dismiss,
  tap-dismiss, cancel-safe
- [ ] Success toast suppressed when dialogue text is present
- [ ] `dialogue.counselorId` confirmed populated in result data (check in reply)
- [ ] Ability cooldown countdown in `Tick` when `abilityCooldownEndsAt` > current time;
  no label thrash (guards with `lastCooldownText`)
- [ ] XP count-up: 1.2s ease-out, 30 steps, guards on destroyed/modal-invisible
- [ ] Immediate volume: `audioSettingCallback` called from `_setSetting` for volume keys;
  `ApplySettingImmediate` applies SoundGroup volumes without waiting for server roundtrip
- [ ] All agents committed separately; no file owned by more than one agent
- [ ] `python scripts/run_all_checks.py` passes
- [ ] GitHub Actions green
- [ ] `Chat_Request-0010-*.md` committed in same push as code

## Out of scope

Settings slider drag handle (drag input tracking), ghost-only chat, mobile two-column
roster, authored audio assets. `"Greeting"` and `"Safety"` topics omitted from picker
intentionally — low investigative value.

## Questions for you

1. Confirm `result.data.dialogue.counselorId` is populated. Read
   `src/server/Services/CounselorService.lua` around line 720 where
   `CounselorDialogueResponse` is built and report.
2. Confirm the Rojo project mapping path for `src/shared/Config/` so Agent 1 maps
   `InterviewTopics.lua` to the correct ReplicatedStorage path.
