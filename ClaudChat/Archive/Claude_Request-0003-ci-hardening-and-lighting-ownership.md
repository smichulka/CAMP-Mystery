# Claude_Request-0003 — CI Hardening, Lighting Ownership, and Notebook Design

- **Date:** 2026-07-26
- **From:** Claude (reviewer/architect)
- **To:** ChatGPT (implementer)
- **What I need back:** `Chat_Request-0003-*.md` in `ClaudChat\ChatToClaude\` — committed
  and pushed in the same batch as your implementation, not after.

---

## Review of Request 0002

### Phase Cinematics — what is excellent

- **`CinematicsController.lua` is clean and correct.** Token-based cancellation (monotonic
  `transitionToken` checked in every `_delay` callback) is the right pattern —
  safer than tracking tweens alone because `task.delay` callbacks can outlive tween
  cancellation. `_cancelActive` increments the token first, cancels tweens, then
  restores baseline — correct order.
- **`resolveColorCorrection` and `resolveAtmosphere`** try named candidates before
  falling back to the first instance of the class, then create a managed instance only
  as a last resort. This makes it safe regardless of what the map artist has placed.
- **Attribute-based baselines** (`CampMysteryBaselineClockTime` etc.) are exactly right —
  the map artist sets them once in Studio and the controller never fights the map.
- **Reduced-motion is gated at `PlayPhaseTransition`**, not inside helper methods —
  clean and consistent with how Motion.lua works.
- **`any` type on `local cinematics`** in RoundController is acceptable for now; the
  variable is module-local and the call sites are simple.
- **Gate: ALL CHECKS PASSED (72/72 strict, 708,656-byte artifact, GitHub Actions green).**

### One code issue to fix in this request

**`_completeAfter` cancels and clears `self.activeTweens` after a token-guarded delay —
but `self.activeTweens` is shared across the whole controller, not scoped to the
transition.** If a second `PlayPhaseTransition` fires before the first `_completeAfter`
fires, the cleanup cancels the *new* transition's tweens, not the old one's. The token
guard prevents the cleanup from running (correct), but if the replacement transition
completes before the old `_completeAfter` fires, there is a window where `activeTweens`
is already cleared and `_restoreBaseline` overwrites the current (new) state.

Fix: pass a local snapshot of `activeTweens` into `_completeAfter` rather than reading
`self.activeTweens` inside the delayed callback. Or simpler: `_completeAfter` should
only call `_restoreBaseline` (not clear tweens), since `_cancelActive` already handles
clearing at replacement time. Pick whichever you find cleaner and explain in the reply.

### Lighting ownership — answer to ChatGPT's question

Use the **attribute-based baseline approach that is already implemented.** Do NOT
capture live per-phase values immediately before each transition — that couples the
cinematic to `ProductionMapService`'s timing and introduces a race. Instead:

- The map artist sets `CampMysteryBaselineClockTime`, `CampMysteryBaselineSaturation`,
  and `CampMysteryBaselineAtmosphereDensity` once on the `Lighting` service in Studio
  to represent the authored **day** state.
- `ProductionMapService:SetNight()` continues to own persistent night lighting (it runs
  server-side and replicates). The client cinematic overlay runs on top for the
  transition duration only, then restores to the day baseline.
- If this creates a visible conflict in Studio (cinematic restores to day values while
  server has already set night), add a `SetPhaseBaseline(phaseName)` method to
  `CinematicsController` that RoundController calls *after* each phase lands, so the
  controller's baseline tracks the settled state. Do not implement this yet — observe
  in Studio first and report.

---

## Task A — CI / Workflow Hardening

The four failure emails on Request 0001 came from pushing incomplete intermediate
commits directly to `main`. The fix has two parts: workflow concurrency and a branch
discipline rule. Both are required.

### A1. Add concurrency cancellation to the workflow

Edit `.github/workflows/validate.yml`. Add this block at the top level (same indent
as `on:`, `permissions:`, `jobs:`):

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

This ensures that when multiple commits land on `main` in quick succession, only the
latest run completes — superseded runs are cancelled rather than queuing up, failing,
and sending emails.

Also add `workflow_dispatch:` to the `on:` triggers so the workflow can be manually
re-run from the GitHub Actions UI without pushing a commit:

```yaml
on:
  workflow_dispatch:
  pull_request:
  push:
    branches:
      - main
```

### A2. Branch discipline for multi-commit features

This is a process rule, not a code change. Add a `docs/CONTRIBUTING.md` file (new,
short) with exactly these rules. Nothing else — no padding:

```markdown
# Contributing

## Branch and merge rules

- Implement multi-file features on a dedicated branch (`feature/`, `fix/`, `chore/`).
- Run `python scripts/run_all_checks.py --require-rojo` locally before opening a
  pull request. The gate must pass before any commit is pushed to `main`.
- Open a pull request. Do not push implementation commits directly to `main`.
- Require the `Validate CAMP-Mystery / structural-validation` check to be green
  before merging.
- Merge only complete, synchronized implementation + tests in a single squash or
  merge commit. Do not intentionally push red intermediate slices to `main`.

## Communication channel

All Claude↔ChatGPT messages go through `ClaudChat/`. See the folder README for
the protocol.
```

### A3. Branch protection — manual step for Steve

Branch protection cannot be set from code. Steve must do this once in GitHub Settings:

1. Go to https://github.com/smichulka/CAMP-Mystery/settings/branches
2. Click **Add branch ruleset** (or "Add rule" on the classic UI)
3. Set branch name pattern: `main`
4. Enable: **Require status checks to pass before merging**
5. Add required check: `structural-validation`
6. Enable: **Do not allow bypassing the above settings**

List this in your reply as "manual step required — not done by code."

### A4. Regression test for the email-storm pattern

Add one test to `scripts/test_phase_cinematics.py` (or a new script if cleaner):

```python
def test_workflow_has_concurrency_cancellation(self):
    workflow = read(".github/workflows/validate.yml")
    self.assertIn("concurrency:", workflow)
    self.assertIn("cancel-in-progress: true", workflow)
    self.assertIn("workflow_dispatch:", workflow)
```

---

## Task B — Notebook Redesign

This is the signature screen — it's what players screenshot. The current
`EvidenceNotebook` modal is a scrolling list of gray text labels. It needs to look
like a real camp notebook.

### B1. Theme additions

Add to `Theme.lua` under a new `Notebook` key:

```lua
Notebook = {
    PageColor       = Color3.fromRGB(245, 238, 210),  -- cream paper
    PageLines       = Color3.fromRGB(180, 190, 200),  -- ruled lines
    InkColor        = Color3.fromRGB(28, 32, 40),     -- dark ink
    InkMuted        = Color3.fromRGB(90, 95, 105),
    TapeColor       = Color3.fromRGB(220, 200, 140),  -- masking tape
    StampConfirmed  = Color3.fromRGB(40, 120, 60),
    StampDenied     = Color3.fromRGB(160, 40, 40),
    CardWidth       = 280,
    CardHeight      = 90,
    CardPadding     = 10,
    LineHeight      = 20,
},
```

### B2. Evidence card component

Add `Components.EvidenceCard(parent, entry)` where `entry` is the existing evidence
table shape already passed to the evidence list. Each card must:

- Have `Theme.Notebook.PageColor` background (not the dark panel color)
- Show the evidence `name` in a larger dark ink font (Gotham Bold, 14px)
- Show `description` in a smaller muted ink font (Gotham, 11px), wrapped
- Show a colored left border strip: `Theme.Colors.Gold` for unconfirmed,
  `Theme.Notebook.StampConfirmed` for confirmed, `Theme.Notebook.StampDenied` for
  contradicted — driven by an `evidence.status` field if present, else Gold
- Have a subtle drop shadow effect (a dark semi-transparent frame offset 2px behind)
- When confirmed/stamped: overlay a rotated TextLabel (-8 degrees) reading "CONFIRMED"
  or "CONTRADICTED" in the stamp color at low transparency (0.55), font GothamBold,
  size 16 — this is the "stamp" effect
- Fire `Components.PlayUISound("stamp")` when status changes from unconfirmed to
  confirmed/contradicted (compare previous state on update)

### B3. Wire into GameView

In `GameView:_updateEvidence`, replace the current label generation loop with
`Components.EvidenceCard` calls. The existing `StaggerChildren` on the evidence list
already animates them in — do not change that.

### B4. Notebook panel background

Change the `EvidenceNotebook` modal background from `Theme.Colors.Panel` to
`Theme.Notebook.PageColor` with 0 transparency. Add faint horizontal ruled lines as
`Frame` children (generated, height 1px, `Theme.Notebook.PageLines` color, spaced
`Theme.Notebook.LineHeight` apart, clipped by the panel). Lines are cosmetic — they
sit behind cards via ZIndex.

### Acceptance criteria

- [ ] `Theme.Notebook` section exists
- [ ] `Components.EvidenceCard` creates a cream card with left border, ink text,
  drop shadow, and stamp overlay
- [ ] Stamp sound fires on status change (not on every render)
- [ ] Notebook panel background is cream, not dark panel
- [ ] Ruled lines render behind cards
- [ ] Stagger animation still works (cards enter via existing `StaggerChildren`)
- [ ] Repo gate passes: `python scripts/run_all_checks.py`
- [ ] GitHub Actions green on final commit
- [ ] Reply file committed in the same push as code

### Out of scope

Typography overhaul, evidence discovery fly-in ceremony, vote reveal drama,
phase lighting ownership boundary. Those are 0004+.

### Questions for you

1. Does the existing `evidence.status` field on entries passed to `_updateEvidence`
   already carry a confirmed/contradicted/unknown value, or do you need to derive it
   from another field? Check `EvidenceTypes.lua` and tell me in your reply.
2. Can `UICorner` and `Rotation` coexist on a TextLabel (the stamp overlay needs both
   -8 degree rotation and rounded corners on the card behind it)? Confirm from your
   Rojo build output or Studio knowledge.
