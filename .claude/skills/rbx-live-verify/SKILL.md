---
name: rbx-live-verify
description: Live in-Studio verification loop for CAMP-Mystery — boot the game through the Roblox Studio MCP, run the bundled world/UI audit scripts, capture screenshots, fix findings in the Rojo source, and commit. Use this whenever the task involves verifying changes in Studio, testing the game live, hunting visual or gameplay bugs, smoke-testing after map/UI/server code changes, checking whether something "looks right" or "works" in-game, or taking screenshots of the world — even if the user just says "test it", "check the game", or "make sure it works". Also use it before claiming any world-geometry or UI fix in this repo is done.
---

# CAMP-Mystery live verification loop

You are verifying a procedurally generated Roblox game (murder-mystery camp: day
phase at camp, night Investigation in the town south of it). The map is built at
server boot by `src/server/Services/ProductionMapService.lua` + `Map/*` packs;
UI is built at client boot by `src/client/UI/GameView.lua` + views. Nothing you
see in Studio's Edit mode is the game — **everything must be verified in Play
mode**, and every real fix lands in the repo source (Rojo-synced), never only as
a live patch.

The loop: **preflight → boot → audit → screenshot → fix in source → re-verify →
commit**. Read `references/audit-snippets.md` for ready-to-run audit code and
`references/gotchas.md` before trusting any surprising measurement — most
"weird" results in this project have a known engine-level explanation.

## 1. Preflight

Tools come from the `Roblox_Studio` MCP server (names like
`mcp__Roblox_Studio__execute_luau`). If they are absent from your session, the
bridge is down: check processes (`StudioMCP`, `RobloxStudioBeta`, `rojo`) via
PowerShell and tell the user the proxy must be running **before** the session
starts — a mid-session reconnect never surfaces the tools. Don't burn time
retrying ToolSearch.

Rojo must be serving and Studio must have pulled your latest edits:

```powershell
# start if missing; port 34872 is the project's configured port
Start-Process -FilePath "rojo" -ArgumentList "serve","default.project.json","--port","34872" -WorkingDirectory "C:\Users\smich\Documents\Roblox\CAMP-Mystery" -WindowStyle Hidden
```

**Sync check (do not skip):** a Play session snapshots scripts at start, so
stale sources silently invalidate everything you measure. In the **Edit**
datamodel, read the target ModuleScript's `.Source` and assert it contains a
distinctive token from your newest edit. Beware: names built by concatenation
(`"PorchRailFront" .. side`) never literal-match — pick a comment or variable
name instead. If the token is missing, the Rojo plugin isn't connected; ask the
user to click Connect in Studio's Rojo plugin panel.

## 2. Boot and settle

`start_stop_play` with `is_start: true`, then wait for generation inside your
first `execute_luau` (Server datamodel) rather than sleeping blind:

```lua
local t0 = os.clock()
repeat task.wait(0.5) until (workspace:FindFirstChild("Runtime")
	and workspace.Runtime:FindFirstChild("Map")
	and workspace.Runtime.Map:FindFirstChild("NightTown")
	and #workspace.Runtime.Map.NightTown:GetChildren() > 50) or os.clock() - t0 > 40
task.wait(5) -- streaming/navmesh settle
```

Check `get_console_output` early — the map build prints diagnostics (e.g. the
shadow-trim count) and a scripting error at boot invalidates the whole run.

## 3. Audit battery

Run on the **Server** datamodel unless it's a UI check (Client). Pick by what
changed; when in doubt run the lot — each is a few seconds.

| Changed | Run (from audit-snippets.md) |
|---|---|
| Terrain, domes, map packs | Buried-structure sweep, float check, door blockage |
| Buildings, doors, props | Door blockage, pathfinding matrix |
| Evidence/search content | Socket solid-rock check |
| Client UI | UI geometry audit (Client), duplicate-ScreenGui count |
| Anything | Console output, one screenshot pass |

Interpret with the caveats baked into each snippet — top-down rays hit roofs,
underground rooms are buried *by design*, roofs "float" over furniture. The
snippets group results so you judge structures, not raw part lists.

**Phases race you.** The round cycles Day → dusk → Investigation → Campfire →
Resolution → Lobby in a few minutes. The town is only tangible/visible at
night; raycasts through it during day report void. Bundle dependent
measurements into ONE `execute_luau` call so a phase flip can't split your
data, and re-run rather than reason about a measurement that might have
straddled a transition.

## 4. Screenshots

`screen_capture` accepts `camera_position` / `look_at_position` (Studio window
must be visible in the foreground). The briefing modal blocks center-screen
world shots — dismiss it by clicking its real button, which also regression-
tests the button:

```
user_mouse_input actions: [{"action": "mouseButtonClick", "mouse_button": "left",
  "instance_path": "Players.<PlayerName>.PlayerGui.TutorialUI.ContextualTutorial.TutorialCard.Skip"}]
```

Find the local player's name first via `execute_luau` on Client. The camera
cheat-sheet in audit-snippets.md lists proven position/look-at pairs for every
landmark. Screenshots are for *judgment* (does it read right?); numbers come
from the audits — never eyeball what you can measure.

## 5. Fix in source, re-verify, commit

- Fix in `src/`, never only in the live datamodel. Live patches
  (`execute_luau` property writes) are legitimate **only** to preview a fix
  before writing it to source.
- Terrain dome/hill edits must update every height mirror in lockstep:
  `ProductionMapService.expandedGroundHeight`, the FillBall loop skips,
  `Map/Backcountry.lua` (EXPANDED_DOMES + groundHeight), and
  `Map/LakeAndWilds.lua` (hillGroundHeight). A mirror left behind seats props
  on ghost hills.
- Before committing: `python scripts/compile_luau.py` and
  `python scripts/run_all_checks.py` must both be clean. The contract tests pin
  exact source tokens; when a legitimate change trips one, update the token in
  the test **with a dated comment explaining the change** (see
  `scripts/test_win_reveal_item_feedback.py` for the pattern).
- Commit small and fast — parallel Claude sessions work this repo
  concurrently. Then stop play, re-check sync, boot fresh, and re-run the
  relevant audits before calling anything fixed.

## When you're done

Report: what you verified (with numbers from audits, not vibes), what you fixed
and where, what remains. Update the project memory if you learned a new engine
gotcha — future sessions rely on it.
