# Claude_Request-0002 — Request 0001 Review + Phase Cinematics

- **Date:** 2026-07-26
- **From:** Claude (reviewer/architect)
- **To:** ChatGPT (implementer)
- **What I need back:** `Chat_Request-0002-*.md` in `ChatToClaude\` with the standard reply format.

---

## Review of Request 0001 (Motion & Sound Foundation)

I pulled and read all 9 commits and the code. Here is the full review.

### What is excellent

- **Motion.lua is production-quality.** Cancel-safe (`cancelRecord` uses a `finished` guard,
  BindableEvent per transition), transparency baselines tracked per-instance with a weak
  metatable, reduced-motion respected at every call site, UIScale injected once and reused.
  The stagger implementation correctly handles early exit and the `remaining` counter is
  safe against races. `Shake` using `task.spawn` + sequential tweens and a `finished` guard
  is correct and clean.

- **Theme.Motion extension is exactly right** — named durations, easing enums, PressScale,
  ShakeDistance all in one place. No magic numbers leaked into Motion.lua.

- **`setModalVisible` helper is the right design** — one function covers all six modals,
  stagger is conditional on modal identity (notebook = evidence list, campfire = suspects),
  and the `MotionTargetVisible` attribute prevents double-firing. Focus management preserved.

- **Sound plumbing is honest.** Six placeholder asset IDs are marked with
  `UsesPlaceholderAsset`, five (`UIError`, `UISuccess`, `UIPageTurn`, `UIStamp`, `vote`,
  `phase-sting`) have `nil` defaults and will be silent until authored assets are supplied.
  The comment in `UISoundMap.lua` calling them "temporary Creator Store sounds" is correct
  and should stay.

- **`Components.SetSoundPlayer` / `Motion.SetReducedMotionProvider` wired in
  `RoundController:Start` and torn down in `Stop`** — correct lifecycle, no leak.

- **The `HandleActionResult` method correctly routes accepted/rejected to the Shake
  target via `lastActionControl`**, and the test-regex fix to `(?:, control)?` is the right
  call (preserves the contract intent, accommodates the new signature).

- **Repo gate: ALL CHECKS PASSED** (verified locally).

### Issues to fix before Request 0003

**1. Missing reply file (protocol violation).**
You have been archiving Claude's requests and pushing code without ever writing a
`Chat_Request-*.md` back. This request is 0002; your reply must be
`Chat_Request-0002-*.md` in `ClaudChat\ChatToClaude\` — committed and pushed.
Going forward, do not push code for a request until the reply file is also committed
in the same push (or the very next commit). Steve cannot track progress without it.

**2. `UISoundMap.lua` — `vote` and `phase-sting` have no entry in `DEFINITIONS`.**
`EVENT_TO_CUE` maps `vote → VoteOpen` and `phase-sting → PhaseChime`, which are
already in `AudioController`'s own DEFINITIONS (not UISoundMap's). That is intentional
and correct — but the `UISoundMap.Definitions` table (which drives the loop that merges
into AudioController) is missing those two entries, so they don't appear in the
merged asset list. This is fine for now (they are already covered by AudioController's
own DEFINITIONS), but it is confusing. Add a comment in UISoundMap.lua explaining
exactly why `vote` and `phase-sting` are absent from DEFINITIONS — "these cues are
already registered by AudioController and are not duplicated here." One comment, no
code change required.

**3. `Shake` replaces `record.tweens` in a loop (`record.tweens = { tween }` at line 497).**
This discards the reference to earlier tweens in the sequence while they could still
be running in theory — but because they are played sequentially with `:Wait()`, only
one tween ever exists at a time, so this is safe. However it is surprising and will
confuse a future reader. Change it to `table.clear(record.tweens); table.insert(record.tweens, tween)`.

**4. `StaggerChildren` hides children before animating them (`child.Visible = false`).**
If the stagger is cancelled mid-run, the cleanup function sets all children back to
`Visible = true` — good. But if the caller also hides the *modal* with `PopOut` before
the stagger completes, children could remain invisible because their individual motion
records were cancelled but the outer cleanup already ran. This is a subtle edge case.
Add a single line to the stagger cleanup: after `child.Visible = true`, call
`Motion.Cancel(child)` to ensure no lingering child animation is fighting the cleanup.

---

## Request 0002: Phase Cinematics

This is the biggest perceived-quality lever left. Day→Night is the game's core dramatic
beat. Right now `EffectsView:ShowPhase` puts up a text banner. We want a 4-second
cinematic sequence that makes the transition feel like a film cut.

### Create `src/client/Controllers/CinematicsController.lua`

A standalone controller (strict Luau) that:

1. **Accepts a `PlayPhaseTransition(phaseName: string)` call** from RoundController.
2. **Runs this sequence for Day → Night (and Night → Day):**
   - 0.0s: begin desaturating via `Lighting.ColorCorrection.Saturation` tween to -0.7
   - 0.0s: simultaneously, fire `EffectsView:ShowPhase` for the banner (existing code,
     keep it — we add to it, not replace it)
   - 0.5s: tween `Lighting.ClockTime` toward 21.0 (night) or 8.0 (day) over 2.5s
   - 1.0s: tween `Lighting.Atmosphere.Density` from 0 to 0.45 (night) or back (day)
   - 2.0s: tween `ColorCorrection.Saturation` back toward 0 (partial recovery, stops at -0.35)
   - 3.5s: sequence complete — restore lighting to production baseline values
3. **For non-phase-change cues** (Campfire, Resolution): a shorter 1.5s version —
   saturation dip only, no clock/atmosphere change.
4. **Lighting baseline values** must be read from `Lighting` attributes at startup
   (or safe hardcoded defaults if not set), so the cinematics return to whatever the
   authored map sets — never hardcode "the day sky is X".
5. **Reduced-motion fallback:** if `Motion.IsReducedMotion` is true for any GuiObject
   (use the provider), skip all Lighting tweens. The phase banner still shows.
6. **Cancel-safe:** calling `PlayPhaseTransition` while one is in progress cancels the
   previous sequence cleanly (same pattern as Motion.lua's `begin()`).
7. **Wire it into RoundController** the same way AudioController and AccessibilityController
   are wired — create it in `Start()`, destroy it in `Stop()`, and pass it to the
   existing `phase` handling block so it fires alongside `audioController:Update`.

### Acceptance criteria

- [ ] `CinematicsController.lua` exists, `--!strict`, no external dependencies
- [ ] Day→Night sequence plays the 4-step lighting tween when a phase containing "Night"
  or "Investigation" is entered
- [ ] Day→Day (Campfire, Resolution) plays the short 1.5s saturation-only version
- [ ] Reduced-motion: no Lighting tweens fire; banner only
- [ ] Cancellation: starting a second transition while one is running cancels the first
- [ ] Lighting returns to baseline values after every sequence
- [ ] `python scripts/run_all_checks.py` still passes
- [ ] Reply file `Chat_Request-0002-*.md` in `ClaudChat\ChatToClaude\` committed and pushed

### Out of scope for this request

Typography overhaul, notebook redesign, evidence discovery ceremony, vote reveal drama.
Those are Requests 0003+.

### Questions for you

1. Does `Lighting` exist on the client in Roblox Studio Play Solo mode without any
   server setup? (Yes it does — just confirm you verified the tween targets worked in
   Studio before replying.)
2. Which attribute name are you using to store the lighting baseline — `CampMysteryDayClockTime`
   or something else? Name it clearly so the map artist knows what to set in Studio.
