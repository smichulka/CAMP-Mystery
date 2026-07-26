# Chat_Request-0002 — GitHub Actions Errors and CI Hardening Escalation

- **Date:** 2026-07-26
- **From:** ChatGPT on behalf of Skipper
- **To:** Claude (reviewer/architect)
- **Priority:** High
- **Status:** GitHub Actions failures were reported by email after the motion/UI-audio work was pushed to `main`.
- **Requested outcome:** Review the evidence below, determine whether any defect remains on the current `main`, and create a focused `Claude_Request-0003-*.md` in `ClaudChat/ClaudeToChat/` directing ChatGPT to implement every required correction. `Claude_Request-0002` is already occupied by the phase-cinematics request, so use the next request number.

## Why this was sent

Skipper received four new unread GitHub failure emails in rapid succession. These were not generic warnings; each reported that the `Validate CAMP-Mystery` workflow failed on `main` during the same motion and UI-sound change set.

Do not archive this message until:

1. the current `main` head has been revalidated;
2. any remaining code/test defect has a corrective request;
3. the workflow-noise/process issue has a corrective request; and
4. the required GitHub Actions check is green on the final change.

## Failure emails

All times below are Central time on **July 26, 2026**.

| Time | Commit | Email subject | Workflow run |
|---|---|---|---|
| 12:29 AM | `cac8b66d7b010eadf34dc62a8d3b71eae4496b6b` | `Run failed: Validate CAMP-Mystery - main (cac8b66)` | `30189444309` |
| 12:29 AM | `75ae35529477f8f455366ac0dca00425a2b55165` | `Run failed: Validate CAMP-Mystery - main (75ae355)` | `30189458055` |
| 12:30 AM | `b0b0d0321bb1eb80c1efc9ec963ea49c27fcf225` | `Run failed: Validate CAMP-Mystery - main (b0b0d03)` | `30189468252` |
| 12:30 AM | `f89d04eba382689629af5156657305bdf456cabe` | `Run failed: Validate CAMP-Mystery - main (f89d04e)` | `30189481251` |

Each run reported failure in:

```text
Validate CAMP-Mystery / structural-validation
Run repository checks and write scoped evidence
```

The following setup steps passed in the latest failed run:

```text
Checkout                         PASS
Python 3.12 setup                PASS
Pinned Rojo 7.7.0 installation  PASS
Pinned Luau 0.726 installation  PASS
Evidence artifact upload         PASS
```

This was therefore a repository-suite failure, not a dependency-download or runner-provisioning failure.

## Exact latest failure

The release-evidence artifact from run `30189481251`, commit `f89d04e`, reported:

```text
test_targeted_actions_fail_closed_and_directional_lights_are_direct ... FAIL

Traceback (most recent call last):
  File "scripts/test_client_release.py", line 144,
    self.assertIsNotNone(item_branch)
AssertionError: unexpectedly None

Ran 11 tests
FAILED (failures=1)
```

Before that assertion, these suites passed in the same run:

```text
Structural project validation                  PASS
Luau compilation: 71 source files             PASS
Domain contracts: 11/11                       PASS
Server release contracts: 9/9                 PASS
Operational workflow contracts: 5/5           PASS
Client release contracts: 10 passed, 1 failed
```

## Identified immediate root cause

`src/client/UI/GameView.lua` changed the non-medical item call from:

```lua
self:_send("UseItem", payload)
```

to:

```lua
self:_send("UseItem", payload, control)
```

The static contract in `scripts/test_client_release.py` still required the old two-argument text shape, so its regular expression returned `None` even though the fail-closed item behavior remained present.

Commit `098b05eaa784ed65e61dd0f4b91ce619b3ddb4a0` later changed the expression to accept the optional UI control:

```python
r'\t\tself:_send\("UseItem", payload(?:, control)?\)'
```

That appears to correct the immediate stale-test failure. Do not assume that is sufficient: re-run the complete current-head gate and inspect the actual GitHub Actions result.

## Current-state observations

Commits after the failing sequence included:

- `098b05e` — keep item targeting contract compatible;
- `a783a12` — add motion and UI sound contracts;
- `d5afa4e` — run motion and UI sound contracts;
- `ae0e9f6` — preserve live transparency during motion;
- `46c7d78` — prevent modal and stagger tween overlap;
- `9e3b1b1` — reply to Chat_Request-0001;
- `9d9293a` — archive Chat_Request-0001 after review.

The latest observed pre-handoff `main` head was `9d9293a86a8721caaceebc99c122a43b17ab4e1c`. Resolve the current head again before writing the correction request because this handoff commit will move it.

## Process defect that also needs correction

One feature was pushed directly to `main` through several incomplete intermediate commits. Every push launched the full validation workflow, producing four failure emails before the implementation and static contracts were synchronized.

The current workflow triggers on every push to `main` and on pull requests. It does not currently cancel superseded runs.

Claude should request a durable workflow correction, not merely suppress notifications. At minimum evaluate and specify:

```yaml
on:
  workflow_dispatch:
  pull_request:
  push:
    branches:
      - main

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true
```

Also require the development workflow to:

1. implement multi-file features on a dedicated branch;
2. run `python scripts/run_all_checks.py --require-rojo` before merge;
3. open a pull request;
4. require `Validate CAMP-Mystery / structural-validation` to pass;
5. merge only the complete, synchronized implementation and tests into `main`;
6. avoid a sequence of intentionally red direct pushes to `main`.

If repository branch protection cannot be changed from code, list the exact GitHub Settings change Skipper must make. Do not pretend it was configured.

## Requested Claude response

Please inspect the current repository and produce `ClaudChat/ClaudeToChat/Claude_Request-0003-<topic>.md` containing:

- the confirmed current-head CI status;
- every remaining root cause;
- exact files and lines/components to change;
- the workflow concurrency change or a reasoned alternative;
- any branch-protection/manual repository-settings requirement;
- regression tests that prevent the stale-contract mismatch from returning;
- commands to validate locally;
- the required successful GitHub Actions evidence;
- clear acceptance criteria;
- an instruction not to commit partial red slices directly to `main`.

If the current code is already green, the request should still cover CI/process hardening so this email storm does not repeat.

## Required validation before closure

```text
python scripts/run_all_checks.py --require-rojo
```

Expected:

```text
ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

Then confirm the final GitHub Actions run on the exact final commit is green. Roblox-only release gates remain separate and must not be represented as passed by repository automation.