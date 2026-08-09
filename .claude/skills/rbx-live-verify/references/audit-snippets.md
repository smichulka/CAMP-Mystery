# Audit snippets (battle-tested, paste into execute_luau)

All run on the **Server** datamodel unless marked Client. Each was debugged
in-boot during the 2026-08 passes; the caveats are load-bearing.

## Contents
- [A. Buried-structure sweep](#a-buried-structure-sweep)
- [B. Door blockage](#b-door-blockage)
- [C. Evidence socket solid-rock check](#c-evidence-socket-solid-rock-check)
- [D. Pathfinding matrix](#d-pathfinding-matrix)
- [E. Float check](#e-float-check)
- [F. Client UI geometry audit](#f-client-ui-geometry-audit)
- [G. Camera cheat-sheet](#g-camera-cheat-sheet)

## A. Buried-structure sweep

Reports the worst-buried part per top-level group. Caveats: parts with
`Position.Y <= -1` are usually underground rooms by design (storm cellars,
mines, crypt) — filtered out; ~2.5 studs of "burial" for town-band parts is the
slab-surface offset (authored for ground y=0, voxel surface renders ~2.4-2.9)
and only matters for SHORT parts; mines/waterfall interiors read as deeply
buried from above but are carved air pockets (verify with snippet C, not this).

```lua
local out = {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {workspace.Terrain}
local function terrainAt(x, z)
	local r = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	return r and r.Position.Y or nil
end
for _, folder in {workspace.Runtime.Map.NightTown, workspace.Runtime.Map.DayCamp} do
	local worst = {}
	for _, p in folder:GetDescendants() do
		if p:IsA("BasePart") and p.Position.Y > -1 then
			local ty = terrainAt(p.Position.X, p.Position.Z)
			if ty then
				local buried = ty - (p.Position.Y - p.Size.Y/2)
				if buried > 3 and p.Size.Y < 20 then
					local a = p
					while a.Parent ~= folder and a.Parent do a = a.Parent end
					if not worst[a.Name] or buried > worst[a.Name].d then
						worst[a.Name] = {d = buried, part = p.Name, x = p.Position.X, z = p.Position.Z}
					end
				end
			end
		end
	end
	for k, w in pairs(worst) do
		table.insert(out, ("%s/%s: %.1f deep (%s @ %.0f,%.0f)"):format(folder.Name, k, w.d, w.part, w.x, w.z))
	end
end
return #out > 0 and table.concat(out, "\n") or "no burials > 3"
```

## B. Door blockage

Horizontal terrain-only rays through each doorway at waist and head height,
plus a voxel-occupancy check of the door's own volume. Do NOT use top-down rays
for this — they hit the building's own roof and report false blockage. A ray
that STARTS inside solid terrain does not hit it, which is why the EMBEDDED
voxel check exists.

```lua
local Terrain = workspace.Terrain
local out = {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {Terrain}
params.IgnoreWater = true
for _, d in workspace:GetDescendants() do
	local n = d.Name:lower()
	if d:IsA("BasePart") and n:find("door") and not n:find("header")
		and not n:find("mat") and not n:find("bracket") and not n:find("glow") then
		local cf, size = d.CFrame, d.Size
		local bottomY = cf.Position.Y - size.Y/2
		local hits = {}
		for _, h in {1.5, 4} do
			for dirName, dir in pairs({front = -cf.LookVector, back = cf.LookVector}) do
				local origin = Vector3.new(cf.Position.X, bottomY + h, cf.Position.Z)
				local r = workspace:Raycast(origin, dir * (size.Z/2 + 5), params)
				if r then hits[dirName .. "@h" .. h] = ("%.1f"):format((r.Position - origin).Magnitude) end
			end
		end
		local region = Region3.new(cf.Position - Vector3.new(1.5,1.5,1.5), cf.Position + Vector3.new(1.5,1.5,1.5)):ExpandToGrid(4)
		local ok, mats, occs = pcall(function() return Terrain:ReadVoxels(region, 4) end)
		local solid = 0
		if ok then
			for x = 1, mats.Size.X do for y = 1, mats.Size.Y do for z = 1, mats.Size.Z do
				local m = mats[x][y][z]
				if m ~= Enum.Material.Air and m ~= Enum.Material.Water and occs[x][y][z] > 0.5 then solid += 1 end
			end end end
		end
		local cnt = 0; for _ in pairs(hits) do cnt += 1 end
		if cnt > 0 or solid > 2 then
			local parts = {}
			for k, v in pairs(hits) do table.insert(parts, k .. "=" .. v) end
			table.sort(parts)
			table.insert(out, ("%s @ (%.0f,%.0f,%.0f): %s%s"):format(
				d:GetFullName():gsub("Workspace.Runtime.Map.", ""), cf.Position.X, cf.Position.Y, cf.Position.Z,
				table.concat(parts, " "), solid > 2 and (" EMBEDDED(" .. solid .. ")") or ""))
		end
	end
end
return #out > 0 and table.concat(out, "\n") or "all doorways clear"
```

Note: during the Day phase the town is intangible (`CanQuery=false`), so town
doors report nothing meaningful — run this at night, or accept that only
DayCamp results are valid by day.

## C. Evidence socket solid-rock check

A socket >60% inside solid terrain spawns an unreachable clue (glows copy the
socket CFrame verbatim, no ground snap). Sockets inside carved interiors
(mines, waterfall cave) legitimately read "buried" to top-down rays but pass
this occupancy test — that is the point of it.

```lua
local Terrain = workspace.Terrain
local out = {}
local count = 0
for _, p in workspace:GetDescendants() do
	if p:IsA("BasePart") and (p:GetAttribute("EvidenceSocket") ~= nil
		or p:GetAttribute("EvidenceSocketExtra") ~= nil or p:GetAttribute("EvidenceAlias") ~= nil) then
		count += 1
		local region = Region3.new(p.Position - Vector3.new(1.5,1.5,1.5), p.Position + Vector3.new(1.5,1.5,1.5)):ExpandToGrid(4)
		local ok, mats, occs = pcall(function() return Terrain:ReadVoxels(region, 4) end)
		if ok then
			local solid, total = 0, 0
			for x = 1, mats.Size.X do for y = 1, mats.Size.Y do for z = 1, mats.Size.Z do
				total += 1
				local m = mats[x][y][z]
				if m ~= Enum.Material.Air and m ~= Enum.Material.Water and occs[x][y][z] > 0.5 then solid += 1 end
			end end end
			if solid / math.max(total, 1) > 0.6 then
				table.insert(out, ("%s @ (%.0f,%.0f,%.0f): %.0f%% solid"):format(p.Name, p.Position.X, p.Position.Y, p.Position.Z, 100 * solid / total))
			end
		end
	end
end
table.insert(out, 1, ("checked %d sockets"):format(count))
return table.concat(out, "\n")
```

## D. Pathfinding matrix

Ground truth for "can you actually get there". Three hard-won rules:
1. **Pick targets at walk height** — a target floating 2+ studs above a deck
   can fail to snap to the navmesh and report NoPath even though the route is
   fine (porch decks sit ~1.5-2.5; use y=2.5 near them).
2. **No-jump NoPath is not a player-facing bug by itself**: players jump, and
   bot counselors don't pathfind at all (they're PivotTo-animated props). Use
   no-jump as a quality bar, jump-enabled as the functional bar.
3. Navmesh gaps must be ≥7 studs wide for agent radius 2 — a 5-stud gap reads
   as closed.

```lua
local out = {}
local PathfindingService = game:GetService("PathfindingService")
local targets = {
	{"PineCabin porch", Vector3.new(-54, 2.5, 8)},
	{"CreekCabin porch", Vector3.new(54, 2.5, 8)},
	{"CounselorLodge porch", Vector3.new(0, 2.5, 64)},
	{"SupplyCabin porch", Vector3.new(-76, 2.5, -55)},
	{"Infirmary porch", Vector3.new(22, 2.5, 59)},
	-- night-only targets (town is intangible by day):
	{"GeneralStore door", Vector3.new(-55, 4, -185)},
	{"ResidentialA door", Vector3.new(-83, 4, -135)},
	{"Diner door", Vector3.new(175, 4, -140)},
	{"PoliceStation door", Vector3.new(70, 4, -360)},
	{"Church area", Vector3.new(15, 4, -440)},
}
for _, t in targets do
	for _, jump in {false, true} do
		local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = jump})
		pcall(function() path:ComputeAsync(Vector3.new(0, 4, 0), t[2]) end)
		table.insert(out, ("%s (%s): %s"):format(t[1], jump and "jump" or "nojump", path.Status.Name))
	end
end
return table.concat(out, "\n")
```

## E. Float check

Parts hovering above whatever is below them. High false-positive rate on
buildings (roofs legitimately "float" over furniture) — only chase standalone
ground props, and expect ropes-course/aerial pieces to be airborne by design.

```lua
local out, nfloat = {}, 0
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = false
for _, p in workspace.Runtime.Map.DayCamp:GetDescendants() do
	if p:IsA("BasePart") and p.Size.Magnitude > 3 then
		params.FilterDescendantsInstances = {p}
		local bottom = p.Position.Y - p.Size.Y/2
		local r = workspace:Raycast(p.Position, Vector3.new(0, -60, 0), params)
		if r and bottom - r.Position.Y > 3.5 then
			nfloat += 1
			if nfloat <= 30 then
				local a = p
				while a.Parent ~= workspace.Runtime.Map.DayCamp and a.Parent do a = a.Parent end
				table.insert(out, ("%s/%s @ (%.0f,%.0f,%.0f) gap %.1f over %s"):format(
					a.Name, p.Name, p.Position.X, p.Position.Y, p.Position.Z, bottom - r.Position.Y, r.Instance.Name))
			end
		end
	end
end
table.insert(out, 1, ("floating candidates: %d (first 30 shown)"):format(nfloat))
return table.concat(out, "\n")
```

## F. Client UI geometry audit

Run on the **Client** datamodel. Reports off-screen/clipped visible elements,
duplicate GameUI ScreenGuis, and full-width strays. Reminders that explain the
usual suspects: ScreenGuis RENDER into the topbar zone (an element "parked"
above the fold needs y ≤ -(height+inset)); `GetGuiInset()` is (0,0) during
early boot; `AbsolutePosition` is inset-relative under CoreUISafeInsets, so
the real screen y = AbsolutePosition.Y + 58.

```lua
local Players = game:GetService("Players")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
local cam = workspace.CurrentCamera
local vp = cam.ViewportSize
local inset = game:GetService("GuiService"):GetGuiInset()
local out = {("viewport %dx%d inset %d"):format(vp.X, vp.Y, inset.Y)}
local n = 0
for _, s in pg:GetChildren() do if s.Name == "GameUI" then n += 1 end end
table.insert(out, "GameUI count: " .. n .. " (must be 1)")
local function vis(g)
	local o = g
	while o and o ~= pg do
		if o:IsA("GuiObject") and not o.Visible then return false end
		if o:IsA("ScreenGui") and not o.Enabled then return false end
		o = o.Parent
	end
	return true
end
for _, g in pg:GetDescendants() do
	if g:IsA("GuiObject") and vis(g) and g.AbsoluteSize.X > 4 and g.AbsoluteSize.Y > 4 then
		local pos, size = g.AbsolutePosition, g.AbsoluteSize
		local clip = (pos.Y < -2 and " TOP" or "") .. (pos.X < -2 and " LEFT" or "")
			.. (pos.X + size.X > vp.X + 2 and " RIGHT" or "")
			.. (pos.Y + size.Y > vp.Y - inset.Y + 2 and " BOTTOM" or "")
		if clip ~= "" then
			local p = g.Parent
			local parentClipped = p and p:IsA("GuiObject") and (p.AbsolutePosition.Y < -2
				or p.AbsolutePosition.X < -2
				or p.AbsolutePosition.X + p.AbsoluteSize.X > vp.X + 2
				or p.AbsolutePosition.Y + p.AbsoluteSize.Y > vp.Y - inset.Y + 2)
			if not parentClipped then
				table.insert(out, ("CLIPPED%s %s pos=(%d,%d) size=(%d,%d) %s"):format(
					clip, g:GetFullName():gsub("Players.[^.]+.PlayerGui.", ""), pos.X, pos.Y, size.X, size.Y,
					(g:IsA("TextLabel") or g:IsA("TextButton")) and string.sub(g.Text, 1, 30) or ""))
			end
		end
	end
end
return table.concat(out, "\n")
```

An element parked deliberately off-screen (e.g. the Announcement banner at
y=-160) is expected — judge whether each hit is a parking spot or a bug.

## G. Camera cheat-sheet

Proven `screen_capture` position → look_at pairs (Studio window must be
foregrounded). At night add ~2s settle after phase flips before capturing.

| Subject | camera_position | look_at_position |
|---|---|---|
| Camp overview from spawn | [0, 30, 80] | [30, 60, -700] |
| Pine Cabin porch | [-54, 8, -18] | [-54, 3, 10] |
| Creek Cabin porch | [54, 8, -18] | [54, 3, 10] |
| Counselor Lodge | [0, 10, 40] | [0, 5, 66] |
| Town road south (night) | [0, 18, -70] | [0, 2, -160] |
| ResidentialA door (night) | [-72, 7, -135] | [-86, 4, -135] |
| Diner (night) | [160, 9, -140] | [178, 4, -140] |
| Sawmill (night) | [-135, 14, -100] | [-105, 3, -75] |
| Cornfield (night) | [20, 25, -60] | [60, 2, -100] |
| Aurora ruins / east bank | [150, 14, -12] | [172, 3, 12] |
| Archery range | [-24, 10, -70] | [-42, 3, -75] |
| Far ridges / skyline | [0, 30, 80] | [30, 60, -700] |
| Full-map aerial | [50, 420, -240] | [50, 0, -239] |
