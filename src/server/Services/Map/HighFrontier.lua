--!strict

-- HIGH FRONTIER: content pack for the fourth expansion's doubled band — the
-- deep meadow north of the mid-country forest belt and the far west reach.
--   * Frontier fire watchtower in the north meadow: stilted cab, climbable
--     ladder, night beacon, spyglass back toward camp, ranger cache at the
--     base (search location "frontier-watch-cache")
--   * Old logging camp in the far west: saw pit and rusted blade, log piles,
--     collapsed lean-to, camp stove, foreman's ledger lectern (search
--     location "logging-camp-ledger")
--   * Frontier trail north from the pass to the watchtower and on to the
--     creek gate; west trail from the ridge out to the logging camp
--   * Aspen groves, wildflower drifts, boulder outcrops and a scatter band
--     so the doubled meadow reads as high country instead of empty slab
-- Pure content builder like Backcountry: everything parents under dayCamp,
-- no gameplay wiring beyond prompts, night-lit lanterns, and the two
-- evidence-socket markers registered in SEARCH_TARGETS/SEARCH_LOCATIONS.
--
-- Integration: registered in ProductionMapService's EXPANSION_MODULE_NAMES
-- after Backcountry (trails join Backcountry's trailheads).

local Workspace = game:GetService("Workspace")

local WorldKit = require(script.Parent:WaitForChild("WorldKit"))

local HighFrontier = {}

-- Natural palette (matches Backcountry / LakeAndWilds tones)
local PINE_TRUNK = Color3.fromRGB(67, 50, 36)
local PINE_GREEN_A = Color3.fromRGB(43, 85, 57)
local PINE_GREEN_B = Color3.fromRGB(50, 94, 61)
local ASPEN_BARK = Color3.fromRGB(214, 210, 196)
local ASPEN_LEAF = Color3.fromRGB(126, 160, 74)
local PLANK = Color3.fromRGB(96, 70, 46)
local PLANK_DARK = Color3.fromRGB(72, 52, 34)
local STONE = Color3.fromRGB(105, 102, 96)
local SLATE_GREY = Color3.fromRGB(82, 88, 78)
local DIRT = Color3.fromRGB(117, 91, 64)
local RUST = Color3.fromRGB(126, 84, 54)
local IRON_DARK = Color3.fromRGB(74, 74, 78)

-- Mirrors the ProductionMapService terrain dome layout — the interior ring
-- (with its index-9 ranger override) plus the fourth-expansion
-- OUTER_HILL_DOMES and FAR_SHORE_DOMES — so props seat on whatever slope is
-- underneath. Same mirroring pattern Backcountry uses; keep in lockstep.
local EXPANDED_DOMES: { { number } } = {
	-- outer boundary ring, fourth-expansion positions
	{ 250, -3, 196, 30 },
	{ 252, -2, 258, 32 },
	{ 249, -3, 320, 30 },
	{ 251, -2, 382, 32 },
	{ 246, -3, 436, 32 },
	{ 198, -3, 464, 30 },
	{ 92, -2, 466, 30 },
	{ 24, -2, 466, 32 },
	{ -48, -3, 470, 32 },
	{ -120, -2, 464, 34 },
	{ -192, -3, 468, 32 },
	{ -264, -2, 460, 34 },
	{ -336, -3, 466, 32 },
	{ -408, -2, 458, 34 },
	{ -472, -3, 448, 32 },
	{ -516, -2, 396, 34 },
	{ -534, -3, 330, 32 },
	{ -524, -2, 264, 34 },
	{ -536, -3, 198, 32 },
	{ -526, -2, 132, 34 },
	{ -534, -3, 66, 32 },
	{ -524, -2, 0, 34 },
	{ -532, -3, -66, 32 },
	{ -488, -2, -118, 32 },
	-- far-shore ridge + corner fillers
	{ 250, -3, -118, 28 },
	{ 252, -2, -84, 30 },
	{ 249, -3, -50, 26 },
	{ 251, -2, -16, 32 },
	{ 250, -3, 18, 28 },
	{ 252, -2, 52, 30 },
	{ 249, -3, 86, 26 },
	{ 251, -2, 120, 32 },
	{ 250, -3, 150, 28 },
	-- (northeast corner fillers removed: the water-sports basin owns that
	-- meadow now — keep in lockstep with ProductionMapService)
}

local function analyticGroundHeight(x: number, z: number): number
	local height = 0.5
	local function raiseFor(cx: number, cy: number, cz: number, ballRadius: number)
		local dx = x - cx
		local dz = z - cz
		local flat = math.sqrt(dx * dx + dz * dz)
		if flat < ballRadius - 0.5 then
			height = math.max(height, cy + math.sqrt(ballRadius * ballRadius - flat * flat))
		end
	end
	for index = 2, 13 do
		if index == 10 or index == 11 or index == 12 then
			-- Skipped in the terrain build: they sat on the town's north band.
			continue
		end
		if index == 9 then
			raiseFor(-72, -2, -80, 22)
		else
			local angle = (index / 14) * math.pi * 2
			local radius = 105 + (index % 3) * 9
			raiseFor(
				math.cos(angle) * radius,
				-3 + (index % 2),
				12 + math.sin(angle) * radius,
				20 + index % 4 * 2
			)
		end
	end
	for _, dome in EXPANDED_DOMES do
		raiseFor(dome[1], dome[2], dome[3], dome[4])
	end
	return height
end

-- Seats content on the RENDERED terrain surface — the analytic model above
-- underestimates the voxelized surface by ~2 studs (slab nominal top y 0.5
-- renders at ~2.5, measured in-boot 2026-08-09). Raycast is authoritative;
-- the analytic model is the fallback past the terrain edge or over water.
local seatRayParams = RaycastParams.new()
seatRayParams.FilterType = Enum.RaycastFilterType.Include
seatRayParams.FilterDescendantsInstances = { Workspace.Terrain }

local function groundHeight(x: number, z: number): number
	-- Terrain queries in the far chunks can lag the boot-time Clear+refill by
	-- a beat: rays through the northern meadow missed at build time and hit
	-- fine seconds later (measured 2026-08-09). Retry a null hit briefly; a
	-- water hit is definitive and falls straight back to the model.
	for _ = 1, 8 do
		local hit = Workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -240, 0), seatRayParams)
		if hit then
			if hit.Material == Enum.Material.Water then
				break
			end
			return hit.Position.Y
		end
		task.wait(0.25)
	end
	return analyticGroundHeight(x, z)
end

local function verticalCylinder(
	parent: Instance,
	name: string,
	height: number,
	diameter: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	return WorldKit.part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		Enum.PartType.Cylinder
	)
end

local function createPine(
	parent: Instance,
	x: number,
	z: number,
	height: number,
	canopyColor: Color3
)
	local base = groundHeight(x, z) - 0.4
	verticalCylinder(
		parent,
		"FrontierPineTrunk",
		height,
		2.0,
		Vector3.new(x, base + height / 2, z),
		PINE_TRUNK,
		Enum.Material.Wood
	)
	for tier = 1, 3 do
		local ball = WorldKit.part(
			parent,
			"FrontierPineCanopy",
			Vector3.new(9 - tier * 2, 5 - tier * 0.8, 9 - tier * 2),
			CFrame.new(x, base + height - 4 + tier * 2.4, z),
			canopyColor,
			Enum.Material.Grass,
			Enum.PartType.Ball
		)
		ball.CanCollide = false
	end
end

-- Aspen: slim pale trunk, one loose leaf ball. Groves of these break up the
-- pine monoculture so the high meadow reads as a different biome.
local function createAspen(parent: Instance, x: number, z: number, height: number)
	local base = groundHeight(x, z) - 0.3
	verticalCylinder(
		parent,
		"AspenTrunk",
		height,
		1.1,
		Vector3.new(x, base + height / 2, z),
		ASPEN_BARK,
		Enum.Material.Wood
	)
	local crown = WorldKit.part(
		parent,
		"AspenCrown",
		Vector3.new(6.5, 7.5, 6.5),
		CFrame.new(x, base + height + 2.4, z),
		ASPEN_LEAF,
		Enum.Material.Grass,
		Enum.PartType.Ball
	)
	crown.CanCollide = false
end

-- Dirt trail: same laid-strip pattern as Backcountry's, seated on groundHeight.
local function laidTrail(parent: Instance, name: string, points: { Vector2 })
	local trail = WorldKit.model(parent, name)
	for index = 1, #points - 1 do
		local fromPoint = points[index]
		local toPoint = points[index + 1]
		local span = toPoint - fromPoint
		local segments = math.max(1, math.floor(span.Magnitude / 6.5))
		for segment = 0, segments do
			local alpha = segment / math.max(segments, 1)
			local x = fromPoint.X + span.X * alpha
			local z = fromPoint.Y + span.Y * alpha
			local strip = WorldKit.part(
				trail,
				"TrailStrip",
				Vector3.new(2.2, 0.12, 7),
				CFrame.new(x, groundHeight(x, z) + 0.08, z)
					* CFrame.Angles(0, math.atan2(span.X, span.Y), 0)
					* CFrame.Angles(0, math.rad((index * 17 + segment * 29) % 14 - 7), 0),
				DIRT,
				Enum.Material.Ground
			)
			strip.CanCollide = false
		end
	end
end

-- Frontier fire watchtower: four-post stilted cab ~16 studs up, climbable
-- truss ladder, waist-high cab walls, pyramid roof, night beacon, spyglass
-- aimed back at camp, and the ranger cache crate at the base.
local function buildWatchtower(parent: Instance)
	local tower = WorldKit.model(parent, "FrontierWatchtower")
	local cx, cz = -60, 380
	local ground = groundHeight(cx, cz)
	local deckY = ground + 16

	for postX = -1, 1, 2 do
		for postZ = -1, 1, 2 do
			WorldKit.part(tower, "TowerLeg", Vector3.new(0.9, 16.4, 0.9),
				CFrame.new(cx + postX * 3.6, ground + 8.2, cz + postZ * 3.6),
				PLANK_DARK, Enum.Material.Wood)
		end
	end
	-- Cross braces on all four faces, two heights
	for _, braceY in { ground + 4.5, ground + 10.5 } do
		for side = -1, 1, 2 do
			WorldKit.part(tower, "TowerBraceX", Vector3.new(0.35, 0.35, 8.4),
				CFrame.new(cx + side * 3.6, braceY, cz) * CFrame.Angles(math.rad(38), 0, 0),
				PLANK, Enum.Material.Wood)
			WorldKit.part(tower, "TowerBraceZ", Vector3.new(8.4, 0.35, 0.35),
				CFrame.new(cx, braceY, cz + side * 3.6) * CFrame.Angles(0, 0, math.rad(38)),
				PLANK, Enum.Material.Wood)
		end
	end
	WorldKit.part(tower, "CabFloor", Vector3.new(10, 0.6, 10),
		CFrame.new(cx, deckY, cz), PLANK, Enum.Material.WoodPlanks)
	-- Waist-high cab walls with an open ladder gap on the east face
	for side = -1, 1, 2 do
		WorldKit.part(tower, "CabWallNS", Vector3.new(10, 2.4, 0.4),
			CFrame.new(cx, deckY + 1.5, cz + side * 4.8), PLANK, Enum.Material.WoodPlanks)
	end
	WorldKit.part(tower, "CabWallW", Vector3.new(0.4, 2.4, 10),
		CFrame.new(cx - 4.8, deckY + 1.5, cz), PLANK, Enum.Material.WoodPlanks)
	WorldKit.part(tower, "CabWallENorth", Vector3.new(0.4, 2.4, 3.4),
		CFrame.new(cx + 4.8, deckY + 1.5, cz - 3.3), PLANK, Enum.Material.WoodPlanks)
	WorldKit.part(tower, "CabWallESouth", Vector3.new(0.4, 2.4, 3.4),
		CFrame.new(cx + 4.8, deckY + 1.5, cz + 3.3), PLANK, Enum.Material.WoodPlanks)
	-- Corner roof posts under one shallow-pitched roof slab
	for postX = -1, 1, 2 do
		for postZ = -1, 1, 2 do
			WorldKit.part(tower, "RoofPost", Vector3.new(0.5, 5.4, 0.5),
				CFrame.new(cx + postX * 4.6, deckY + 3.0, cz + postZ * 4.6),
				PLANK_DARK, Enum.Material.Wood)
		end
	end
	WorldKit.part(tower, "RoofSlabA", Vector3.new(12, 0.4, 12),
		CFrame.new(cx, deckY + 5.9, cz) * CFrame.Angles(math.rad(7), 0, 0),
		PLANK_DARK, Enum.Material.WoodPlanks)
	-- Climbable ladder truss up the east face, landing at the wall gap
	WorldKit.truss(tower, "TowerLadder", Vector3.new(2, 17, 2),
		CFrame.new(cx + 5.9, ground + 8.5, cz), IRON_DARK)
	-- Beacon lantern on a roof post (CampLamp: lights at night)
	local beacon = WorldKit.part(tower, "TowerBeacon", Vector3.new(0.9, 0.9, 0.9),
		CFrame.new(cx - 4.6, deckY + 6.4, cz - 4.6), Color3.fromRGB(255, 211, 132),
		Enum.Material.Neon, Enum.PartType.Ball)
	beacon.CanCollide = false
	WorldKit.lamp(beacon, { brightness = 1.4, range = 26 })
	-- Spyglass on the south rail, aimed back down the meadow at camp
	local spyglass = WorldKit.part(tower, "FrontierSpyglass", Vector3.new(1.9, 0.45, 0.45),
		CFrame.lookAt(
			Vector3.new(cx + 2.4, deckY + 3.1, cz + 4.4),
			Vector3.new(0, 10, 12)
		) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(172, 138, 74), Enum.Material.Metal, Enum.PartType.Cylinder)
	spyglass.CanCollide = false
	WorldKit.prompt(spyglass, "Glass the Camp", "Spyglass", 0.3)

	-- Ranger cache at the base: strapped crate + the search-location marker
	-- (registered as "frontier-watch-cache" in SEARCH_TARGETS/SEARCH_LOCATIONS)
	WorldKit.part(tower, "RangerCache", Vector3.new(2.6, 1.6, 1.8),
		CFrame.new(cx - 1.5, ground + 0.8, cz - 6.4) * CFrame.Angles(0, math.rad(14), 0),
		PLANK, Enum.Material.WoodPlanks)
	WorldKit.part(tower, "CacheStrap", Vector3.new(2.7, 1.7, 0.4),
		CFrame.new(cx - 1.5, ground + 0.8, cz - 6.4) * CFrame.Angles(0, math.rad(14), 0),
		IRON_DARK, Enum.Material.Metal)
	WorldKit.evidenceSocketMarker(tower, "frontier-watch-cache",
		Vector3.new(cx - 1.5, ground + 2.4, cz - 6.4))

	WorldKit.signpost(parent, Vector3.new(cx + 9, groundHeight(cx + 9, cz + 10), cz + 10),
		{ "FIRE WATCH", "HIGH FRONTIER" })
end

-- Old logging camp: the west reach's story beat. A working camp abandoned
-- mid-season — saw pit with a rusted blade, log piles, a collapsed lean-to,
-- cold stove, and the foreman's ledger still open on its lectern.
local function buildLoggingCamp(parent: Instance)
	local camp = WorldKit.model(parent, "OldLoggingCamp")
	local cx, cz = -420, 180
	local ground = groundHeight(cx, cz)

	-- Saw pit: timber cradle over a shallow frame, half-buried circular blade
	WorldKit.part(camp, "SawPitFrameN", Vector3.new(7.6, 1.1, 0.8),
		CFrame.new(cx, ground + 0.55, cz - 2.2), PLANK_DARK, Enum.Material.Wood)
	WorldKit.part(camp, "SawPitFrameS", Vector3.new(7.6, 1.1, 0.8),
		CFrame.new(cx, ground + 0.55, cz + 2.2), PLANK_DARK, Enum.Material.Wood)
	WorldKit.part(camp, "CradledLog", Vector3.new(7.0, 1.5, 1.5),
		CFrame.new(cx, ground + 1.75, cz),
		PINE_TRUNK, Enum.Material.Wood, Enum.PartType.Cylinder)
	local blade = WorldKit.part(camp, "RustedSawBlade", Vector3.new(0.25, 4.6, 4.6),
		CFrame.new(cx + 4.6, ground + 1.4, cz) * CFrame.Angles(0, 0, 0),
		RUST, Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
	WorldKit.prompt(blade, "Inspect", "Rusted saw blade", 0.35)

	-- Log piles: stacked cylinders (length along X)
	for pile = 1, 2 do
		local px = cx - 9 + pile * 3
		local pz = cz + 8 + pile * 4
		for layer = 1, 3 do
			for slot = 1, 4 - layer do
				WorldKit.part(camp, "PileLog", Vector3.new(6.4, 1.3, 1.3),
					CFrame.new(px + slot * 1.35 + layer * 0.65, ground + 0.65 + (layer - 1) * 1.15, pz),
					PINE_TRUNK, Enum.Material.Wood, Enum.PartType.Cylinder)
			end
		end
	end

	-- Collapsed lean-to: one standing post, ridge dropped to the ground, two
	-- slumped roof panels
	WorldKit.part(camp, "LeanToPost", Vector3.new(0.5, 4.4, 0.5),
		CFrame.new(cx - 10, ground + 2.2, cz - 6), PLANK_DARK, Enum.Material.Wood)
	WorldKit.part(camp, "FallenRidge", Vector3.new(0.4, 0.4, 8.4),
		CFrame.new(cx - 7.6, ground + 0.9, cz - 8.4) * CFrame.Angles(math.rad(-18), math.rad(12), 0),
		PLANK_DARK, Enum.Material.Wood)
	WorldKit.part(camp, "SlumpedPanelA", Vector3.new(4.6, 0.3, 7.2),
		CFrame.new(cx - 9.4, ground + 1.6, cz - 8.2) * CFrame.Angles(math.rad(-32), math.rad(8), 0),
		PLANK, Enum.Material.WoodPlanks)
	WorldKit.part(camp, "SlumpedPanelB", Vector3.new(4.2, 0.3, 6.4),
		CFrame.new(cx - 5.6, ground + 0.9, cz - 8.8) * CFrame.Angles(math.rad(-11), math.rad(-9), 0),
		PLANK, Enum.Material.WoodPlanks)

	-- Cold camp stove with a leaning pipe
	WorldKit.part(camp, "CampStove", Vector3.new(1.6, 1.9, 1.4),
		CFrame.new(cx + 8, ground + 0.95, cz + 9), IRON_DARK, Enum.Material.Metal)
	WorldKit.part(camp, "StovePipe", Vector3.new(3.4, 0.5, 0.5),
		CFrame.new(cx + 8, ground + 3.4, cz + 9) * CFrame.Angles(0, 0, math.rad(82)),
		IRON_DARK, Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)

	-- Chopping block and buried axe
	WorldKit.part(camp, "ChoppingBlock", Vector3.new(1.4, 1.2, 1.4),
		CFrame.new(cx + 3, ground + 0.6, cz + 10) * CFrame.Angles(0, 0, math.rad(90)),
		PINE_TRUNK, Enum.Material.Wood, Enum.PartType.Cylinder)
	WorldKit.part(camp, "AxeHandle", Vector3.new(0.25, 2.2, 0.25),
		CFrame.new(cx + 3.2, ground + 2.1, cz + 10) * CFrame.Angles(math.rad(24), 0, math.rad(-16)),
		PLANK, Enum.Material.Wood)
	WorldKit.part(camp, "AxeHead", Vector3.new(0.7, 0.5, 0.2),
		CFrame.new(cx + 3.05, ground + 1.25, cz + 10.05), IRON_DARK, Enum.Material.Metal)

	-- Foreman's ledger lectern: the search location. The ledger is still
	-- open — whatever emptied the camp, they left mid-entry.
	WorldKit.part(camp, "LedgerLectern", Vector3.new(0.5, 2.6, 0.5),
		CFrame.new(cx + 1, ground + 1.3, cz - 7), PLANK_DARK, Enum.Material.Wood)
	local ledger = WorldKit.part(camp, "ForemanLedger", Vector3.new(1.7, 0.16, 1.2),
		CFrame.new(cx + 1, ground + 2.7, cz - 7) * CFrame.Angles(math.rad(-16), math.rad(8), 0),
		Color3.fromRGB(196, 182, 150), Enum.Material.SmoothPlastic)
	ledger.CanCollide = false
	WorldKit.prompt(ledger, "Read", "Foreman's ledger",
		0.4)
	WorldKit.evidenceSocketMarker(camp, "logging-camp-ledger",
		Vector3.new(cx + 1, ground + 3.4, cz - 7))

	-- Night lantern on the one standing post
	local lantern = WorldKit.part(camp, "LoggingLantern", Vector3.new(0.7, 0.7, 0.7),
		CFrame.new(cx - 10, ground + 4.7, cz - 6), Color3.fromRGB(255, 211, 132),
		Enum.Material.Neon, Enum.PartType.Ball)
	lantern.CanCollide = false
	WorldKit.lamp(lantern, { brightness = 1.1, range = 18 })

	WorldKit.signpost(parent, Vector3.new(cx + 14, groundHeight(cx + 14, cz + 2), cz + 2),
		{ "OLD LOGGING CAMP", "WEST REACH" })

	-- Stump field: the cut block the camp was working when it stopped
	for stump = 1, 9 do
		local angle = stump * 2.39996
		local radius = 16 + (stump % 4) * 7
		local sx = cx + math.cos(angle) * radius
		local sz = cz + math.sin(angle) * radius
		WorldKit.part(camp, "CutStump", Vector3.new(1.1, 1.7, 1.7),
			CFrame.new(sx, groundHeight(sx, sz) + 0.5, sz)
				* CFrame.Angles(0, angle, math.rad(90)),
			PINE_TRUNK, Enum.Material.Wood, Enum.PartType.Cylinder)
	end
end

-- Wildflower drift: low colored tufts, CanCollide false, clustered around a
-- center. Cheap parts; the meadow's answer to the fern clusters.
local function buildFlowerDrift(parent: Instance, cx: number, cz: number, count: number)
	local FLOWER_COLORS = {
		Color3.fromRGB(214, 116, 140),
		Color3.fromRGB(228, 196, 92),
		Color3.fromRGB(150, 128, 210),
		Color3.fromRGB(232, 230, 218),
	}
	for index = 1, count do
		local angle = index * 2.39996
		local radius = 2 + (index % 5) * 2.6
		local x = cx + math.cos(angle) * radius
		local z = cz + math.sin(angle) * radius
		local flower = WorldKit.part(parent, "Wildflower",
			Vector3.new(0.35, 0.9, 0.35),
			CFrame.new(x, groundHeight(x, z) + 0.4, z)
				* CFrame.Angles(math.rad((index * 13) % 16 - 8), angle, 0),
			FLOWER_COLORS[(index % #FLOWER_COLORS) + 1],
			Enum.Material.Grass)
		flower.CanCollide = false
	end
end

-- Scatter band across the doubled meadow: pines, aspens, boulders and stumps
-- on a golden-angle spiral between the mid-country belt and the new boundary.
local function buildScatter(parent: Instance)
	local scatter = WorldKit.model(parent, "FrontierScatter")
	local function scatterAt(index: number, radius: number)
		local angle = index * 2.39996
		local x = math.cos(angle) * radius
		local z = 12 + math.sin(angle) * radius
		-- Sector skips: east edge and lake, town band, the creek's north
		-- corridor, and anything past the slab edge.
		local offSlab = x > 235 or x < -540 or z > 462 or z < -100
		-- z bound covers the water-sports basin's north lobe (water to z 190)
		local inLakeSector = x > 82 and z < 200
		local inCreekCorridor = z > 160 and x > 60 and x < 175
		if offSlab or inLakeSector or inCreekCorridor then
			return
		end
		local kind = index % 6
		local ground = groundHeight(x, z)
		if kind == 0 then
			WorldKit.part(scatter, "FrontierBoulder",
				Vector3.new(2.8 + index % 3, 2.0 + index % 2, 2.5 + (index + 1) % 3),
				CFrame.new(x, ground + 0.8, z) * CFrame.Angles(index * 0.31, angle, index * 0.13),
				SLATE_GREY, Enum.Material.Slate)
		elseif kind == 1 or kind == 4 then
			createPine(scatter, x, z, 15 + (index % 4) * 2.5,
				if index % 2 == 0 then PINE_GREEN_A else PINE_GREEN_B)
		elseif kind == 2 then
			createAspen(scatter, x, z, 11 + (index % 3) * 2)
		elseif kind == 3 then
			WorldKit.part(scatter, "FrontierStump", Vector3.new(1.1, 1.6, 1.6),
				CFrame.new(x, ground + 0.5, z) * CFrame.Angles(0, angle, math.rad(90)),
				PINE_TRUNK, Enum.Material.Wood, Enum.PartType.Cylinder)
		else
			-- Bare patch: leave open meadow so the band breathes
			return
		end
	end
	for index = 1, 72 do
		scatterAt(index, 258 + (index % 11) * 16)
	end
end

function HighFrontier.Build(dayCamp: Instance, _nightTown: Instance)
	local pack = WorldKit.model(dayCamp, "HighFrontier")

	-- Frontier trail: north from Backcountry's north-pass trailhead, through
	-- the mid-country belt, past the watchtower, ending at the creek gate.
	laidTrail(pack, "FrontierTrail", {
		Vector2.new(-56, 124), Vector2.new(-58, 170), Vector2.new(-62, 226),
		Vector2.new(-62, 280), Vector2.new(-60, 330), Vector2.new(-60, 368),
	})
	laidTrail(pack, "GateTrail", {
		Vector2.new(-52, 392), Vector2.new(-20, 412), Vector2.new(30, 428),
		Vector2.new(80, 440), Vector2.new(116, 448),
	})
	-- West reach trail: out from Backcountry's west-ridge trailhead to the
	-- logging camp.
	laidTrail(pack, "WestReachTrail", {
		Vector2.new(-120, 78), Vector2.new(-170, 98), Vector2.new(-230, 118),
		Vector2.new(-290, 138), Vector2.new(-350, 158), Vector2.new(-402, 174),
	})

	buildWatchtower(pack)
	buildLoggingCamp(pack)

	-- Aspen groves in the north meadow
	for _, grove in { { 30, 330 }, { -150, 316 }, { -262, 398 } } do
		for tree = 1, 5 do
			local angle = tree * 2.39996
			local spread = 4 + (tree % 3) * 4.2
			createAspen(pack,
				grove[1] + math.cos(angle) * spread,
				grove[2] + math.sin(angle) * spread,
				10 + (tree % 3) * 2.5)
		end
	end

	-- Wildflower drifts along the frontier trail and around the tower meadow
	buildFlowerDrift(pack, -40, 300, 14)
	buildFlowerDrift(pack, -84, 352, 12)
	buildFlowerDrift(pack, 8, 396, 12)

	-- Boulder outcrops: three-stone clusters marking the reach's corners
	for _, outcrop in { { -350, 300 }, { -460, 90 }, { -200, 430 }, { 60, 428 } } do
		for stone = 1, 3 do
			local angle = stone * 2.1
			local sx = outcrop[1] + math.cos(angle) * (2 + stone)
			local sz = outcrop[2] + math.sin(angle) * (2 + stone)
			WorldKit.part(pack, "OutcropStone",
				Vector3.new(3.2 + stone, 2.2 + stone * 0.7, 2.8 + stone * 0.8),
				CFrame.new(sx, groundHeight(sx, sz) + 0.7 + stone * 0.2, sz)
					* CFrame.Angles(stone * 0.4, angle, stone * 0.2),
				SLATE_GREY, Enum.Material.Slate)
		end
	end

	buildScatter(pack)
end

return HighFrontier
