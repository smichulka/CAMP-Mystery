# Engine and project gotchas

Every entry below cost real debugging time in the 2026-08 sessions. Read the
relevant section before "fixing" a surprising measurement — the measurement is
usually right and the mental model is what needs fixing.

## Terrain voxels

- Terrain is 4-stud voxels. The rendered surface of a full-occupancy fill sits
  **above** its nominal top (the camp slab tops nominally at 0.5 but renders
  ~2.4-2.9; a water fill topping at 1.6 rendered at 4.0). Measure with
  `ReadVoxels` or a raycast, never from the fill parameters.
- Water fills silently do nothing in any voxel row that still holds solid
  occupancy — carve Air above the waterline first.
- Thin material caps (<1 voxel) blend away; beaches need full-voxel depth.
- Partial Air fills only reduce occupancy; remnants render as rubble humps.
  Size carves to whole 4-stud cells.
- Marching-cubes smoothing makes analytic height mirrors wrong by 1-3 studs on
  slopes — mushrooms/props seated by formula can sink or float there.

## Height-mirror lockstep

Terrain hills are FillBall domes whose layout is **mirrored analytically** in
four places. Change one, change all, or props seat on ghost hills:
1. `ProductionMapService` — the FillBall loops AND `expandedGroundHeight`
2. `Map/Backcountry.lua` — `EXPANDED_DOMES` table AND its `groundHeight`
3. `Map/LakeAndWilds.lua` — `hillGroundHeight` (includes the index-9 override)

Interior-ring skips currently: indices 1, 14 (lakefront), 9 (moved to
-72,-80 r22), 10/11/12 (sat on the town's north band).

## Day/night world model

- `Workspace.Runtime.Map.DayCamp` is always present. `NightTown` toggles per
  phase via `setFolderVisible`: by day every part is Transparency 1,
  CanCollide/CanTouch/CanQuery false — raycasts report **void** where the town
  stands. Only audit the town at night.
- `TownApproachDayWall` (invisible, z=-110, full width) is solid only by day;
  `SetNight` opens it. It replaces the removed south boundary domes.
- The round cycles in minutes. Any two measurements taken in different
  `execute_luau` calls may straddle a phase flip — bundle dependent reads.

## Replication and performance

- Property replication to clients tops out ~20 Hz. Server animation loops
  faster than that burn CPU/bandwidth invisibly — bot loops are throttled
  (idle 15 Hz + 80-stud proximity gate, walks 30 Hz); keep new loops at or
  under these rates.
- Bot counselors and the monster are **anchored PivotTo props**, not
  Humanoids: they never pathfind, and every pivot replicates all part CFrames.
- StreamingEnabled is ON (MinRadius 128, integrity Disabled). Generated
  character models stream Atomic via the GeneratedCharacters ChildAdded hook.
  New client code must nil-guard workspace lookups; never assume the far
  district exists.
- The map build ends with `_trimSmallPartShadows` (CastShadow off for parts
  under 1.5 cubic studs) — its print in the server console is a cheap "my new
  code ran" signal.

## Client UI

- ScreenGuis with `ScreenInsets = CoreUISafeInsets` still RENDER into the
  topbar zone. "Parked" off-screen elements need y ≤ -(height + 58 + margin).
- `GuiService:GetGuiInset()` returns (0,0) during early client boot. Use
  `GuiService.TopbarInset` + its `GetPropertyChangedSignal`, and know that
  `GuiObject.AbsolutePosition` is inset-relative (real screen y = abs + 58).
- The HUD lives in ONE ScreenGui named GameUI; GameView destroys imposters.
  Two GameUIs = a regression.
- Roster/vote/hotbar/evidence lists are signature-guarded — they only rebuild
  when their input data changes. If a list stops refreshing, check whether its
  signature includes the field you changed.
- Full-GUI or full-Workspace `GetDescendants()` walks in per-snapshot paths
  are the classic hitch source here. Scope lookups to their real containers
  (monster → `Runtime.Characters.GeneratedCharacters`).

## Studio MCP mechanics

- Play sessions snapshot scripts at start; verify Rojo sync in the **Edit**
  datamodel before booting (search `.Source` for a token from your edit —
  concatenated instance names never literal-match).
- `screen_capture` needs the Studio window foregrounded; it times out
  minimized.
- GUI buttons can be clicked headlessly with `user_mouse_input` +
  `instance_path` — use it to dismiss the briefing modal and to
  regression-test buttons.
- `require` caches across command-bar runs; to run fresh module code in Edit
  mode, `Clone()` the ModuleScript into the same parent and require the clone.
- The Studio MCP bridge only binds at session start. If tools are missing,
  the fix is a new session with the proxy already running — not retries.
- Parallel Claude sessions commit to this repo concurrently: commit small,
  fast, and check `git log` before assuming your view of a file is current.

## Test suite

- `python scripts/run_all_checks.py` runs everything;
  `python scripts/compile_luau.py` is the fast type gate. Contract tests pin
  exact source tokens — update tokens WITH a dated comment when a legitimate
  change trips one (pattern: scripts/test_win_reveal_item_feedback.py).
