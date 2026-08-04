--!strict

-- LakeAndWilds: the lake-and-wilderness expansion pack.
--   Day camp side: lake shore + main dock, rowboat ferry, fire-watch island,
--   swimming hole, waterfall cave, wooded thickets, greenhouse, wildlife.
--   Night town side: sawmill and cornfield (revealed with the town).
-- Integration:
--   LakeAndWilds.Build(dayCamp, nightTown) -- AFTER buildCampTerrain (the lake
--     water, beach cylinders, and hill ring must already exist)
--   LakeAndWilds.Start() -- once at server start; wildlife loops (idempotent)
-- Evidence sockets registered here (report to SEARCH_TARGETS/SEARCH_LOCATIONS):
--   island-firewatch, waterfall-cave, greenhouse-potting-table, sawmill-blade,
--   cornfield-scarecrow

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local WorldKit = require(script.Parent:WaitForChild("WorldKit"))

-- The bay's terrain water voxelizes to a rendered surface at ~y=4.0 (measured
-- via ReadVoxels; see the ProductionMapService waterfront comment), NOT the
-- nominal fill top of 1.6. Floating props pin against the rendered surface.
local WATER_SURFACE_Y = 4.0

local SAND_CREAM = Color3.fromRGB(214, 196, 158)
local PLANK = Color3.fromRGB(96, 70, 46)
local PLANK_DARK = Color3.fromRGB(72, 52, 34)
local PINE_TRUNK = Color3.fromRGB(67, 50, 36)
local PINE_GREEN_A = Color3.fromRGB(43, 85, 57)
local PINE_GREEN_B = Color3.fromRGB(50, 94, 61)
local REED_GREEN = Color3.fromRGB(94, 128, 74)
local RUST_BROWN = Color3.fromRGB(128, 84, 54)
local SLATE_GREY = Color3.fromRGB(82, 88, 78)
local CAVE_ROCK = Color3.fromRGB(46, 46, 52)
local CANVAS = Color3.fromRGB(58, 66, 54)
local BURLAP = Color3.fromRGB(150, 126, 88)
local STRAW = Color3.fromRGB(196, 178, 102)

local DOCK_LANDING = Vector3.new(94, 8.7, 20)
local ISLAND_LANDING = Vector3.new(99, 9.6, 55)

type FireflySwarm = {
	folder: Folder,
	origin: Vector3,
	orbs: { BasePart },
}

type Owl = {
	head: BasePart,
	baseCFrame: CFrame,
	eyes: { BasePart },
	eyeOffsets: { CFrame },
}

local state = {
	built = false,
	started = false,
	swarms = {} :: { FireflySwarm },
	owls = {} :: { Owl },
	fox = nil :: Model?,
	foxWaypoints = {} :: { Vector3 },
}

-- Mirrors the buildCampTerrain hill-ring FillBall layout (indices 1 and 14 are
-- skipped there for the lakefront gap) so slope props can sit on the terrain.
local function hillGroundHeight(x: number, z: number): number
	local height = 0.5
	for index = 2, 13 do
		local angle = (index / 14) * math.pi * 2
		local radius = 105 + (index % 3) * 9
		local centerX = math.cos(angle) * radius
		local centerZ = 12 + math.sin(angle) * radius
		local ballRadius = 20 + index % 4 * 2
		local dx = x - centerX
		local dz = z - centerZ
		local flat = math.sqrt(dx * dx + dz * dz)
		if flat < ballRadius - 0.5 then
			local bulge = math.sqrt(ballRadius * ballRadius - flat * flat)
			height = math.max(height, -3 + (index % 2) + bulge)
		end
	end
	return height
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
	local cylinder = WorldKit.part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		Enum.PartType.Cylinder
	)
	return cylinder
end

-- Slimmer sibling of the map's createPineTree: trunk + 3 stacked foliage balls.
local function createThicketPine(
	parent: Instance,
	position: Vector3,
	height: number,
	canopyColor: Color3
)
	verticalCylinder(
		parent,
		"ThicketPineTrunk",
		height,
		2.0,
		position + Vector3.new(0, height / 2, 0),
		PINE_TRUNK,
		Enum.Material.Wood
	)
	for layer = 1, 3 do
		local width = 10.5 - layer * 2.4
		local canopy = WorldKit.part(
			parent,
			"ThicketPineCanopy",
			Vector3.new(width, 4.6, width),
			CFrame.new(position + Vector3.new(
				if layer % 2 == 0 then 0.5 else -0.4,
				height * 0.45 + layer * 2.6,
				if layer == 3 then 0.4 else -0.3
			)),
			canopyColor:Lerp(Color3.fromRGB(26, 61, 39), layer * 0.08),
			Enum.Material.Grass,
			Enum.PartType.Ball
		)
		canopy.CanCollide = false
	end
end

local function resolveAudioSlot(attributeName: string): string
	local assetId = SoundService:GetAttribute(attributeName)
	if type(assetId) == "number" and assetId > 0 then
		return "rbxassetid://" .. tostring(assetId)
	elseif type(assetId) == "string" and assetId ~= "" then
		return assetId
	end
	return ""
end

-- FEATURE 1: real lake shore — wade-in sand strip, reeds, lily pads, main dock
local function buildLakeShore(dayCamp: Instance)
	local shore = WorldKit.model(dayCamp, "LakeShore")
	-- Sand shelf along the west lake edge so players can wade in. Full voxel
	-- depth (thin caps blend away at terrain resolution). Stops at z=-16 to
	-- stay clear of the mines pack entrance at (85, -30).
	Workspace.Terrain:FillBlock(
		CFrame.new(88, -2.6, 22),
		Vector3.new(10, 6.8, 76),
		Enum.Material.Sand
	)
	local reedClusters = {
		Vector3.new(87.5, 0, -8),
		Vector3.new(88.6, 0, -1),
		Vector3.new(87.2, 0, 9),
		Vector3.new(88.2, 0, 31),
		Vector3.new(87.6, 0, 47),
		Vector3.new(88.8, 0, 56),
	}
	for clusterIndex, cluster in reedClusters do
		for reed = 1, 3 do
			local reedHeight = 2.4 + reed * 0.4
			local offset = Vector3.new(
				math.sin(clusterIndex + reed * 2.1) * 0.7,
				0.6 + reedHeight / 2,
				math.cos(clusterIndex * 1.7 + reed) * 0.7
			)
			local blade = verticalCylinder(
				shore,
				"Reed",
				reedHeight,
				0.22,
				cluster + offset,
				REED_GREEN,
				Enum.Material.Grass
			)
			blade.CanCollide = false
		end
	end
	local lilySpots = {
		Vector3.new(97, WATER_SURFACE_Y + 0.06, 10),
		Vector3.new(101.5, WATER_SURFACE_Y + 0.06, 3),
		Vector3.new(99, WATER_SURFACE_Y + 0.06, 29),
	}
	for padIndex, spot in lilySpots do
		local pad = verticalCylinder(
			shore,
			"LilyPad" .. tostring(padIndex),
			0.16,
			2.4 + (padIndex % 2) * 0.5,
			spot,
			Color3.fromRGB(70, 122, 70),
			Enum.Material.Grass
		)
		pad.CanCollide = false
	end
	-- Main dock at z=20: ramp off the sand, planked walkway out to x~101 over
	-- the water, post pilings, cleats, and a hanging lantern.
	WorldKit.wedge(
		shore,
		"MainDockRamp",
		Vector3.new(3.6, 4.6, 7),
		CFrame.new(83.5, 3.2, 20) * CFrame.Angles(0, math.rad(90), 0),
		PLANK,
		Enum.Material.WoodPlanks
	)
	WorldKit.part(
		shore,
		"MainDockWalk",
		Vector3.new(14, 0.5, 4),
		CFrame.new(94, 5.25, 20),
		PLANK,
		Enum.Material.WoodPlanks
	)
	local pilingSpots = {
		Vector3.new(89, 0, 18.4),
		Vector3.new(89, 0, 21.6),
		Vector3.new(95, 0, 18.4),
		Vector3.new(95, 0, 21.6),
		Vector3.new(100, 0, 18.2),
		Vector3.new(100, 0, 21.8),
	}
	for pilingIndex, spot in pilingSpots do
		verticalCylinder(
			shore,
			"DockPiling" .. tostring(pilingIndex),
			5.2,
			0.55,
			spot + Vector3.new(0, 2.5, 0),
			PLANK_DARK,
			Enum.Material.Wood
		)
	end
	local cleatSpots = {
		Vector3.new(91, 5.6, 18.2),
		Vector3.new(91, 5.6, 21.8),
		Vector3.new(99.5, 5.6, 18.2),
		Vector3.new(99.5, 5.6, 21.8),
	}
	for cleatIndex, spot in cleatSpots do
		WorldKit.part(
			shore,
			"MooringCleat" .. tostring(cleatIndex),
			Vector3.new(0.7, 0.25, 0.3),
			CFrame.new(spot),
			Color3.fromRGB(58, 62, 66),
			Enum.Material.Metal
		)
	end
	WorldKit.part(
		shore,
		"DockLampPost",
		Vector3.new(0.4, 4, 0.4),
		CFrame.new(100, 7.5, 22.3),
		PLANK_DARK,
		Enum.Material.Wood
	)
	local lantern = WorldKit.part(
		shore,
		"DockLampHead",
		Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(100, 9.9, 22.3),
		Color3.fromRGB(255, 211, 132),
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	lantern.CanCollide = false
	WorldKit.lamp(lantern, { brightness = 1.2, range = 18 })
	-- Storm-damage prop: overturned canoe washed up on the beach
	local stormCanoe = WorldKit.model(shore, "StormCanoe")
	local canoeCFrame = CFrame.new(86, 1.5, 66)
		* CFrame.Angles(0, math.rad(24), math.rad(180))
	WorldKit.part(
		stormCanoe,
		"StormCanoeHull",
		Vector3.new(1.6, 0.9, 7),
		canoeCFrame,
		Color3.fromRGB(52, 118, 124),
		Enum.Material.SmoothPlastic
	)
	for tip = -1, 1, 2 do
		WorldKit.wedge(
			stormCanoe,
			"StormCanoeTip",
			Vector3.new(1.6, 0.9, 1.1),
			canoeCFrame
				* CFrame.new(0, 0, tip * 4.05)
				* CFrame.Angles(0, if tip > 0 then math.pi else 0, 0),
			Color3.fromRGB(52, 118, 124),
			Enum.Material.SmoothPlastic
		)
	end
	WorldKit.stormDamage(stormCanoe)
end

-- FEATURE 2: rowboat ferry between the main dock and the island
local function createRowboat(parent: Instance, name: string, cframe: CFrame): Part
	local boat = WorldKit.model(parent, name)
	local hull = WorldKit.part(
		boat,
		"Hull",
		Vector3.new(1.9, 0.5, 6.4),
		cframe * CFrame.new(0, -0.1, 0),
		Color3.fromRGB(112, 76, 44),
		Enum.Material.WoodPlanks
	)
	for side = -1, 1, 2 do
		WorldKit.part(
			boat,
			"Gunwale",
			Vector3.new(0.3, 0.7, 5.6),
			cframe * CFrame.new(side * 0.85, 0.35, 0),
			PLANK_DARK,
			Enum.Material.Wood
		)
	end
	WorldKit.part(
		boat,
		"Transom",
		Vector3.new(1.9, 0.7, 0.3),
		cframe * CFrame.new(0, 0.35, 3.05),
		PLANK_DARK,
		Enum.Material.Wood
	)
	WorldKit.wedge(
		boat,
		"Bow",
		Vector3.new(1.9, 0.7, 1.1),
		cframe * CFrame.new(0, 0.35, -3.7) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(112, 76, 44),
		Enum.Material.WoodPlanks
	)
	for bench = -1, 1, 2 do
		WorldKit.part(
			boat,
			"BenchSeat",
			Vector3.new(1.7, 0.18, 0.8),
			cframe * CFrame.new(0, 0.45, bench * 1.4),
			PLANK,
			Enum.Material.WoodPlanks
		)
	end
	for oar = -1, 1, 2 do
		WorldKit.part(
			boat,
			"Oar",
			Vector3.new(0.18, 0.12, 4.6),
			cframe
				* CFrame.new(oar * 0.2, 0.68, oar * 0.5)
				* CFrame.Angles(0, math.rad(80 * oar), 0),
			Color3.fromRGB(142, 110, 68),
			Enum.Material.Wood
		)
	end
	return hull
end

local function wireRowPrompt(
	hull: BasePart,
	actionText: string,
	destination: Vector3,
	faceToward: Vector3
)
	local prompt = WorldKit.prompt(hull, actionText, "Rowboat", 0.5)
	local rowing = false
	prompt.Triggered:Connect(function(player: Player)
		if rowing then
			return
		end
		rowing = true
		prompt.Enabled = false
		task.wait(1.5)
		local character = player.Character
		if character ~= nil then
			local look = Vector3.new(faceToward.X, destination.Y, faceToward.Z)
			character:PivotTo(CFrame.lookAt(destination, look))
		end
		prompt.Enabled = true
		rowing = false
	end)
end

local function buildRowboats(dayCamp: Instance)
	local ferry = WorldKit.model(dayCamp, "RowboatFerry")
	local dockHull = createRowboat(
		ferry,
		"DockRowboat",
		CFrame.new(103.2, WATER_SURFACE_Y + 0.35, 24) * CFrame.Angles(0, math.rad(8), 0)
	)
	wireRowPrompt(dockHull, "Row to the Island", ISLAND_LANDING, Vector3.new(104, 0, 55))
	-- Rope tie from the dock cleat down to the bow
	WorldKit.part(
		ferry,
		"DockBoatRope",
		Vector3.new(0.14, 0.14, 3.2),
		CFrame.lookAt(Vector3.new(101.6, 5.0, 22.6), Vector3.new(102.9, 4.6, 21.2)),
		Color3.fromRGB(168, 148, 108),
		Enum.Material.Fabric
	)
	local islandHull = createRowboat(
		ferry,
		"IslandRowboat",
		CFrame.new(94, WATER_SURFACE_Y + 0.3, 57) * CFrame.Angles(0, math.rad(96), 0)
	)
	wireRowPrompt(islandHull, "Row Back to Camp", DOCK_LANDING, Vector3.new(84, 0, 20))
	WorldKit.part(
		ferry,
		"BeachStake",
		Vector3.new(0.3, 1.5, 0.3),
		CFrame.new(96.4, 4.9, 55.6) * CFrame.Angles(0, 0, math.rad(-8)),
		PLANK_DARK,
		Enum.Material.Wood
	)
	WorldKit.part(
		ferry,
		"IslandBoatRope",
		Vector3.new(0.14, 0.14, 2.6),
		CFrame.lookAt(Vector3.new(96.2, 5.0, 55.8), Vector3.new(94.8, 4.7, 56.6)),
		Color3.fromRGB(168, 148, 108),
		Enum.Material.Fabric
	)
end

-- FEATURE 3: fire-watch island in the bay with a collapsed lookout cabin
local function buildIsland(dayCamp: Instance)
	local island = WorldKit.model(dayCamp, "FirewatchIsland")
	-- Island terrain: waterline radius ~9 keeps clear of the buoy line
	-- (z 57-66) and the existing dock platform at (100, 40); plateau ~y 7.5,
	-- well above the rendered water surface at y=4.
	Workspace.Terrain:FillBall(Vector3.new(104, -7, 55), 14, Enum.Material.Ground)
	Workspace.Terrain:FillBall(Vector3.new(104, -1, 55), 9, Enum.Material.Grass)
	-- Landing beach hump on the west edge, breaking the surface at the boat tie
	Workspace.Terrain:FillBall(Vector3.new(96, 0.2, 55), 4, Enum.Material.Sand)
	-- Ruined fire-watch cabin on the plateau. The floor rides the dome's crown,
	-- so stone pier footings ground the corners where the terrain falls away.
	WorldKit.part(island, "RuinFloor", Vector3.new(8, 0.6, 8),
		CFrame.new(104, 8.3, 55), Color3.fromRGB(88, 66, 46), Enum.Material.WoodPlanks)
	for footingX = -1, 1, 2 do
		for footingZ = -1, 1, 2 do
			WorldKit.part(island, "RuinFooting", Vector3.new(0.9, 2.6, 0.9),
				CFrame.new(104 + footingX * 3.4, 6.9, 55 + footingZ * 3.4),
				Color3.fromRGB(105, 102, 96), Enum.Material.Slate)
		end
	end
	WorldKit.part(island, "RuinNorthWall", Vector3.new(8, 4.2, 0.6),
		CFrame.new(104, 10.7, 58.7), Color3.fromRGB(104, 94, 82), Enum.Material.WoodPlanks)
	WorldKit.part(island, "RuinWestWall", Vector3.new(0.6, 4.2, 8),
		CFrame.new(100.3, 10.7, 55), Color3.fromRGB(104, 94, 82), Enum.Material.WoodPlanks)
	WorldKit.part(island, "RuinEastWallLow", Vector3.new(0.6, 1.8, 8),
		CFrame.new(107.7, 9.5, 55), Color3.fromRGB(98, 88, 76), Enum.Material.WoodPlanks)
	for plank = 1, 2 do
		WorldKit.part(island, "FallenPlank" .. tostring(plank),
			Vector3.new(0.5, 0.2, 3.4),
			CFrame.new(108.6 + plank * 0.8, 8.0 - plank * 0.5, 53 + plank * 1.6)
				* CFrame.Angles(math.rad(14 * plank), math.rad(30 + plank * 40), 0),
			Color3.fromRGB(92, 80, 66), Enum.Material.WoodPlanks)
	end
	-- Half-collapsed roof: one wedge still up over the north half, one caved in
	WorldKit.wedge(island, "RuinRoofIntact", Vector3.new(8.8, 2.4, 4.6),
		CFrame.new(104, 14.0, 56.8) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(76, 72, 64), Enum.Material.CorrodedMetal)
	WorldKit.wedge(island, "RuinRoofFallen", Vector3.new(6.5, 1.8, 4.2),
		CFrame.new(104.5, 9.6, 53.2)
			* CFrame.Angles(math.rad(12), math.rad(160), math.rad(6)),
		Color3.fromRGB(70, 66, 58), Enum.Material.CorrodedMetal)
	-- Cold stone fireplace in the northwest corner
	WorldKit.part(island, "FireplaceBase", Vector3.new(2.4, 1.2, 1.4),
		CFrame.new(101.5, 9.2, 57.6), Color3.fromRGB(105, 102, 96), Enum.Material.Slate)
	WorldKit.part(island, "FireplaceBox", Vector3.new(1.8, 1.5, 1.1),
		CFrame.new(101.5, 10.5, 57.7), Color3.fromRGB(52, 50, 48), Enum.Material.Slate)
	WorldKit.part(island, "FireplaceChimney", Vector3.new(1.3, 2.6, 1.3),
		CFrame.new(101.5, 12.5, 57.9), Color3.fromRGB(105, 102, 96), Enum.Material.Slate)
	-- Cot frame with a sagging canvas
	for rail = -1, 1, 2 do
		WorldKit.part(island, "CotRail", Vector3.new(0.25, 0.35, 4),
			CFrame.new(106.2 + rail * 0.9, 9.1, 53.4), PLANK_DARK, Enum.Material.Wood)
	end
	for leg = -1, 1, 2 do
		WorldKit.part(island, "CotLeg", Vector3.new(0.25, 0.6, 0.25),
			CFrame.new(106.2, 8.85, 53.4 + leg * 1.8), PLANK_DARK, Enum.Material.Wood)
	end
	local cotCanvas = WorldKit.part(island, "CotCanvas", Vector3.new(1.9, 0.12, 3.6),
		CFrame.new(106.2, 9.2, 53.4) * CFrame.Angles(0, 0, math.rad(-4)),
		Color3.fromRGB(196, 186, 162), Enum.Material.Fabric)
	cotCanvas.CanCollide = false
	-- Three pines around the plateau edge
	createThicketPine(island, Vector3.new(99, 5.2, 60), 11, PINE_GREEN_A)
	createThicketPine(island, Vector3.new(109, 4.9, 50), 12, PINE_GREEN_B)
	createThicketPine(island, Vector3.new(107.5, 5.0, 61), 10, PINE_GREEN_A)
	WorldKit.evidenceSocketMarker(island, "island-firewatch", Vector3.new(103, 9.8, 56.5))
end

-- FEATURE 4: swimming hole with a rope swing off a leaning tree
local function buildSwimmingHole(dayCamp: Instance)
	local hole = WorldKit.model(dayCamp, "SwimmingHole")
	-- Leaning shore tree arcing out over the north lake
	verticalCylinder(
		hole,
		"LeaningTrunk",
		13,
		1.7,
		Vector3.new(89.5, 5.9, 80),
		PINE_TRUNK,
		Enum.Material.Wood
	).CFrame = CFrame.new(89.5, 5.9, 80) * CFrame.Angles(0, 0, math.rad(90 - 38))
	local canopyA = WorldKit.part(hole, "LeaningCanopyA", Vector3.new(6.5, 5.5, 6.5),
		CFrame.new(93.5, 11, 80), PINE_GREEN_B, Enum.Material.Grass, Enum.PartType.Ball)
	canopyA.CanCollide = false
	local canopyB = WorldKit.part(hole, "LeaningCanopyB", Vector3.new(4.4, 4, 4.4),
		CFrame.new(91, 12.4, 81.4), PINE_GREEN_A, Enum.Material.Grass, Enum.PartType.Ball)
	canopyB.CanCollide = false
	-- Rope down to the tire
	for segment = 1, 3 do
		local rope = WorldKit.part(hole, "SwingRope" .. tostring(segment),
			Vector3.new(0.18, 1.3, 0.18),
			CFrame.new(92.5, 9.6 - segment * 1.15, 80),
			Color3.fromRGB(168, 148, 108), Enum.Material.Fabric)
		rope.CanCollide = false
	end
	local tire = WorldKit.part(hole, "SwingTire", Vector3.new(0.9, 2.6, 2.6),
		CFrame.new(92.5, 5.4, 80) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(38, 38, 40), Enum.Material.Rubber, Enum.PartType.Cylinder)
	tire:SetAttribute("RopeSwing", true)
	local tireHome = tire.CFrame
	local swingPrompt = WorldKit.prompt(tire, "Swing", "Rope Swing", 0.3)
	local swinging = false
	swingPrompt.Triggered:Connect(function()
		if swinging then
			return
		end
		swinging = true
		-- Flavor creak through the audio-slot convention (no marketplace ids
		-- hardcoded); WorldAmbience may add auto-creaks at night via the
		-- RopeSwing attribute above.
		local creakId = resolveAudioSlot("RopeSwingCreakAssetId")
		if creakId ~= "" then
			local creak = Instance.new("Sound")
			creak.Name = "RopeSwingCreak"
			creak.SoundId = creakId
			creak.Volume = 0.5
			creak.RollOffMaxDistance = 60
			creak.Parent = tire
			creak.Ended:Once(function()
				creak:Destroy()
			end)
			creak:Play()
		end
		local out = TweenService:Create(
			tire,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ CFrame = tireHome * CFrame.new(0, 0.25, 1.4) * CFrame.Angles(0, 0, math.rad(14)) }
		)
		out:Play()
		out.Completed:Once(function()
			local back = TweenService:Create(
				tire,
				TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ CFrame = tireHome }
			)
			back:Play()
			back.Completed:Once(function()
				swinging = false
			end)
		end)
	end)
	-- Floating platform raft on barrel floats
	WorldKit.part(hole, "RaftDeck", Vector3.new(5.5, 0.4, 5),
		CFrame.new(98, WATER_SURFACE_Y + 0.35, 85), PLANK, Enum.Material.WoodPlanks)
	for barrel = -1, 1, 2 do
		WorldKit.part(hole, "RaftBarrel", Vector3.new(4.8, 1.5, 1.5),
			CFrame.new(98, WATER_SURFACE_Y - 0.35, 85 + barrel * 1.6),
			Color3.fromRGB(68, 48, 32), Enum.Material.WoodPlanks, Enum.PartType.Cylinder)
	end
	-- Towel rack and two towels on the shore
	for post = -1, 1, 2 do
		WorldKit.part(hole, "TowelRackPost", Vector3.new(0.35, 2.6, 0.35),
			CFrame.new(84.5, 1.8, 76 + post * 1.1), PLANK_DARK, Enum.Material.Wood)
	end
	WorldKit.part(hole, "TowelRackRail", Vector3.new(0.3, 0.3, 2.6),
		CFrame.new(84.5, 3.0, 76), PLANK_DARK, Enum.Material.Wood)
	WorldKit.part(hole, "TowelCream", Vector3.new(0.15, 1.4, 1.0),
		CFrame.new(84.5, 2.5, 75.4), Color3.fromRGB(226, 214, 186), Enum.Material.Fabric)
	WorldKit.part(hole, "TowelRed", Vector3.new(0.15, 1.4, 1.0),
		CFrame.new(84.5, 2.5, 76.7), Color3.fromRGB(176, 94, 80), Enum.Material.Fabric)
end

-- FEATURE 5: waterfall off the northeast hills hiding a crystal cave
local function buildWaterfallCave(dayCamp: Instance)
	local falls = WorldKit.model(dayCamp, "WaterfallCave")
	-- Plunge pool at the hill toe (small additive water fill)
	Workspace.Terrain:FillBall(Vector3.new(70, -2.2, 84), 4.5, Enum.Material.Water)
	-- Terrain marching-cubes smoothing would bulge the hillside into the cave
	-- room unless the voxels are cleared (same pattern createCabin uses), so
	-- carve the room pocket and the entry corridor behind the falls.
	Workspace.Terrain:FillBlock(
		CFrame.new(78, 4.5, 93),
		Vector3.new(11, 8, 12),
		Enum.Material.Air
	)
	Workspace.Terrain:FillBlock(
		CFrame.new(72, 3.8, 87),
		Vector3.new(6, 6.6, 7),
		Enum.Material.Air
	)
	-- Grey slate outcrop flanking the falls and the cave mouth
	local boulderSpots = {
		{ position = Vector3.new(67.5, 1.6, 87.5), size = Vector3.new(3.4, 2.6, 3.0) },
		{ position = Vector3.new(68.2, 1.4, 80.2), size = Vector3.new(2.8, 2.2, 3.2) },
		{ position = Vector3.new(74.5, 2.2, 83.0), size = Vector3.new(3.8, 3.0, 2.6) },
		{ position = Vector3.new(69.5, 5.0, 89.5), size = Vector3.new(2.6, 2.4, 2.2) },
		{ position = Vector3.new(75.5, 6.5, 91.5), size = Vector3.new(3.2, 2.8, 2.8) },
		{ position = Vector3.new(72.0, 9.0, 91.0), size = Vector3.new(2.4, 2.0, 2.4) },
		{ position = Vector3.new(76.5, 11.5, 93.5), size = Vector3.new(3.6, 2.6, 3.0) },
	}
	for boulderIndex, boulder in boulderSpots do
		WorldKit.part(
			falls,
			"FallsBoulder" .. tostring(boulderIndex),
			boulder.size,
			CFrame.new(boulder.position) * CFrame.Angles(
				boulderIndex * 0.4,
				boulderIndex * 0.9,
				boulderIndex * 0.23
			),
			SLATE_GREY,
			Enum.Material.Slate
		)
	end
	-- Waterfall sheet: two semi-transparent slabs (no Beams), walk-through gap
	-- behind them into the corridor
	local sheetOuter = WorldKit.part(falls, "FallsSheetOuter", Vector3.new(5.2, 13.5, 0.8),
		CFrame.new(72.6, 7.4, 88.4) * CFrame.Angles(math.rad(-16), math.rad(38), 0),
		Color3.fromRGB(188, 216, 236), Enum.Material.Glass)
	sheetOuter.Transparency = 0.45
	sheetOuter.CanCollide = false
	local sheetInner = WorldKit.part(falls, "FallsSheetInner", Vector3.new(3.4, 12, 0.6),
		CFrame.new(72.2, 7.0, 87.6) * CFrame.Angles(math.rad(-16), math.rad(38), 0),
		Color3.fromRGB(214, 234, 246), Enum.Material.Glass)
	sheetInner.Transparency = 0.6
	sheetInner.CanCollide = false
	local foam = verticalCylinder(falls, "FallsFoamRing", 0.35, 7.5,
		Vector3.new(70, 2.15, 84), Color3.fromRGB(240, 246, 248), Enum.Material.SmoothPlastic)
	foam.Transparency = 0.35
	foam.CanCollide = false
	-- Crystal cave shell lining the carved pocket
	WorldKit.part(falls, "CaveFloor", Vector3.new(11, 0.5, 12),
		CFrame.new(78, 0.9, 93), CAVE_ROCK, Enum.Material.Slate)
	WorldKit.part(falls, "CaveCeiling", Vector3.new(11, 0.5, 12),
		CFrame.new(78, 8.3, 93), CAVE_ROCK, Enum.Material.Slate)
	WorldKit.part(falls, "CaveBackWall", Vector3.new(0.8, 7, 12),
		CFrame.new(83.2, 4.6, 93), CAVE_ROCK, Enum.Material.Slate)
	WorldKit.part(falls, "CaveNorthWall", Vector3.new(11, 7, 0.8),
		CFrame.new(78, 4.6, 98.8), CAVE_ROCK, Enum.Material.Slate)
	WorldKit.part(falls, "CaveSouthWall", Vector3.new(7, 7, 0.8),
		CFrame.new(80, 4.6, 87.6), CAVE_ROCK, Enum.Material.Slate)
	WorldKit.part(falls, "CaveWestWall", Vector3.new(0.8, 7, 6),
		CFrame.new(72.8, 4.6, 96), CAVE_ROCK, Enum.Material.Slate)
	-- Five glowing crystal clusters; their lights always burn (deliberately not
	-- CampLamp/generator-gated — the cave glows day and night)
	local crystalSpots = {
		{ position = Vector3.new(74.5, 2.0, 95.5), color = Color3.fromRGB(110, 225, 235) },
		{ position = Vector3.new(81.5, 2.0, 90.0), color = Color3.fromRGB(168, 120, 240) },
		{ position = Vector3.new(76.0, 2.0, 97.5), color = Color3.fromRGB(110, 225, 235) },
		{ position = Vector3.new(82.0, 2.0, 96.0), color = Color3.fromRGB(168, 120, 240) },
		{ position = Vector3.new(75.0, 2.0, 89.5), color = Color3.fromRGB(110, 225, 235) },
	}
	for crystalIndex, crystal in crystalSpots do
		local shardA = WorldKit.part(falls, "Crystal" .. tostring(crystalIndex) .. "A",
			Vector3.new(0.7, 2.2, 0.7),
			CFrame.new(crystal.position) * CFrame.Angles(
				math.rad(8 + crystalIndex * 3), math.rad(crystalIndex * 50), math.rad(-6)
			),
			crystal.color, Enum.Material.Neon)
		local shardB = WorldKit.part(falls, "Crystal" .. tostring(crystalIndex) .. "B",
			Vector3.new(0.5, 1.4, 0.5),
			CFrame.new(crystal.position + Vector3.new(0.5, -0.35, 0.2))
				* CFrame.Angles(math.rad(-14), math.rad(crystalIndex * 80), math.rad(12)),
			crystal.color, Enum.Material.Neon)
		shardB.CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Color = crystal.color
		glow.Brightness = 0.8
		glow.Range = 9
		glow.Parent = shardA
	end
	-- Pedestal with a weathered journal page
	verticalCylinder(falls, "CavePedestal", 2.4, 1.3,
		Vector3.new(80, 2.1, 96), Color3.fromRGB(96, 94, 90), Enum.Material.Slate)
	local page = WorldKit.part(falls, "JournalPage", Vector3.new(0.9, 0.06, 1.2),
		CFrame.new(80, 3.35, 96) * CFrame.Angles(0, math.rad(16), 0),
		Color3.fromRGB(222, 206, 168), Enum.Material.SmoothPlastic)
	page.CanCollide = false
	WorldKit.evidenceSocketMarker(falls, "waterfall-cave", Vector3.new(80, 3.6, 96))
end

-- FEATURE 6: four dense wooded thickets around the ring
local function buildThickets(dayCamp: Instance)
	local thicketSpecs = {
		{ center = Vector2.new(-86, -58), pines = 7, rings = 2 }, -- SW
		{ center = Vector2.new(28, -78), pines = 8, rings = 1 }, -- S (east of the road)
		{ center = Vector2.new(-88, 52), pines = 6, rings = 1 }, -- NW slope
		{ center = Vector2.new(-40.5, 112), pines = 7, rings = 2 }, -- N
	}
	for thicketIndex, spec in thicketSpecs do
		local thicket = WorldKit.model(dayCamp, "Thicket" .. tostring(thicketIndex))
		for pine = 1, spec.pines do
			local angle = pine * 2.39996 + thicketIndex
			local spread = 3 + (pine % 4) * 3.1
			local px = spec.center.X + math.cos(angle) * spread
			local pz = spec.center.Y + math.sin(angle) * spread
			local ground = hillGroundHeight(px, pz)
			createThicketPine(
				thicket,
				Vector3.new(px, ground - 0.4, pz),
				13 + (pine % 4) * 2.5,
				if pine % 2 == 0 then PINE_GREEN_A else PINE_GREEN_B
			)
		end
		for ring = 1, spec.rings do
			local ringX = spec.center.X + (if ring == 1 then 4.5 else -6)
			local ringZ = spec.center.Y + (if ring == 1 then -5 else 4)
			for cap = 1, 6 do
				local capAngle = (cap / 6) * math.pi * 2
				local capX = ringX + math.cos(capAngle) * 2.2
				local capZ = ringZ + math.sin(capAngle) * 2.2
				local mushroom = verticalCylinder(
					thicket,
					"MushroomCap",
					0.5,
					0.8,
					Vector3.new(capX, hillGroundHeight(capX, capZ) + 0.25, capZ),
					Color3.fromRGB(178, 52, 44),
					Enum.Material.SmoothPlastic
				)
				mushroom.CanCollide = false
			end
		end
		-- Deer trail: a dirt strip winding through the cluster
		for strip = 1, 3 do
			local stripAngle = thicketIndex * 0.9 + strip * 0.55
			local sx = spec.center.X + math.cos(stripAngle) * (strip * 3.4 - 4)
			local sz = spec.center.Y + math.sin(stripAngle) * (strip * 3.4 - 4)
			local trail = WorldKit.part(
				thicket,
				"DeerTrail" .. tostring(strip),
				Vector3.new(1.8, 0.12, 5.5),
				CFrame.new(sx, hillGroundHeight(sx, sz) + 0.1, sz)
					* CFrame.Angles(0, stripAngle + strip * 0.5, 0),
				Color3.fromRGB(117, 91, 64),
				Enum.Material.Ground
			)
			trail.CanCollide = false
		end
	end
end

-- FEATURE 7: derelict greenhouse between camp and the waterfront
local function buildGreenhouse(dayCamp: Instance)
	local greenhouse = WorldKit.model(dayCamp, "Greenhouse")
	local frameColor = Color3.fromRGB(222, 226, 224)
	local paneColor = Color3.fromRGB(178, 210, 206)
	local function pane(name: string, size: Vector3, cframe: CFrame): Part
		local glass = WorldKit.part(greenhouse, name, size, cframe, paneColor, Enum.Material.Glass)
		glass.Transparency = 0.4
		glass:SetAttribute("Shatterable", true)
		return glass
	end
	WorldKit.part(greenhouse, "GreenhouseFloor", Vector3.new(12, 0.5, 18),
		CFrame.new(54, 0.85, 40), Color3.fromRGB(126, 118, 106), Enum.Material.Concrete)
	for cornerX = -1, 1, 2 do
		for cornerZ = -1, 1, 2 do
			WorldKit.part(greenhouse, "FramePost", Vector3.new(0.6, 6, 0.6),
				CFrame.new(54 + cornerX * 5.4, 4.1, 40 + cornerZ * 8.4),
				frameColor, Enum.Material.Metal)
		end
	end
	WorldKit.part(greenhouse, "RidgeBeam", Vector3.new(0.5, 0.5, 18.6),
		CFrame.new(54, 10.2, 40), frameColor, Enum.Material.Metal)
	for eave = -1, 1, 2 do
		WorldKit.part(greenhouse, "EaveBeam", Vector3.new(0.5, 0.5, 18.6),
			CFrame.new(54 + eave * 5.3, 7.0, 40), frameColor, Enum.Material.Metal)
	end
	-- Side glass (east middle pane long gone)
	for _, sideZ in { 34, 40, 46 } do
		pane("PaneWest" .. tostring(sideZ), Vector3.new(0.25, 5.4, 5.5),
			CFrame.new(48.65, 4.15, sideZ))
		if sideZ ~= 40 then
			pane("PaneEast" .. tostring(sideZ), Vector3.new(0.25, 5.4, 5.5),
				CFrame.new(59.35, 4.15, sideZ))
		end
	end
	-- North end glass; south end keeps one pane beside the open door gap
	pane("PaneNorthA", Vector3.new(5.4, 5.4, 0.25), CFrame.new(51.2, 4.15, 48.4))
	pane("PaneNorthB", Vector3.new(5.4, 5.4, 0.25), CFrame.new(56.8, 4.15, 48.4))
	pane("PaneSouth", Vector3.new(5.4, 5.4, 0.25), CFrame.new(56.8, 4.15, 31.6))
	-- Roof glass (west middle pane shattered onto the floor)
	for _, roofZ in { 34, 40, 46 } do
		if roofZ ~= 40 then
			pane("PaneRoofWest" .. tostring(roofZ), Vector3.new(6.6, 0.22, 6.2),
				CFrame.new(51.2, 8.6, roofZ) * CFrame.Angles(0, 0, math.rad(31)))
		end
		pane("PaneRoofEast" .. tostring(roofZ), Vector3.new(6.6, 0.22, 6.2),
			CFrame.new(56.8, 8.6, roofZ) * CFrame.Angles(0, 0, math.rad(-31)))
	end
	-- Glass shards under the missing panes
	local shardSpots = {
		CFrame.new(51.4, 1.25, 39.2) * CFrame.Angles(0, math.rad(35), 0),
		CFrame.new(50.6, 1.2, 41.0) * CFrame.Angles(0, math.rad(-70), 0),
		CFrame.new(58.6, 1.2, 39.6) * CFrame.Angles(0, math.rad(15), 0),
		CFrame.new(58.1, 1.25, 40.9) * CFrame.Angles(0, math.rad(-40), 0),
	}
	for shardIndex, shardCFrame in shardSpots do
		local shard = WorldKit.wedge(greenhouse, "GlassShard" .. tostring(shardIndex),
			Vector3.new(1.2 + shardIndex * 0.2, 0.15, 0.9), shardCFrame,
			paneColor, Enum.Material.Glass)
		shard.Transparency = 0.35
		shard.CanCollide = false
	end
	-- Two planter bench rows with herb pots
	for benchIndex, benchX in { 51, 57 } do
		WorldKit.part(greenhouse, "PlanterBench" .. tostring(benchIndex),
			Vector3.new(2.6, 0.5, 12), CFrame.new(benchX, 2.35, 40),
			PLANK, Enum.Material.WoodPlanks)
		for support = -1, 1, 2 do
			WorldKit.part(greenhouse, "BenchSupport", Vector3.new(2.4, 2.1, 0.4),
				CFrame.new(benchX, 1.15, 40 + support * 5), PLANK_DARK, Enum.Material.Wood)
		end
		for pot = 1, 4 do
			local potZ = 35 + pot * 2.5 + (benchIndex - 1) * 0.9
			verticalCylinder(greenhouse, "HerbPot", 0.9, 1.0,
				Vector3.new(benchX, 3.05, potZ),
				Color3.fromRGB(158, 96, 64), Enum.Material.SmoothPlastic)
			local tuft = WorldKit.part(greenhouse, "HerbTuft", Vector3.new(0.8, 0.7, 0.8),
				CFrame.new(benchX, 3.75, potZ), Color3.fromRGB(92, 140, 76),
				Enum.Material.Grass, Enum.PartType.Ball)
			tuft.CanCollide = false
		end
	end
	-- Hanging vines from the roof frame
	local vineSpots = {
		Vector3.new(50.5, 8.2, 35), Vector3.new(54, 8.9, 43),
		Vector3.new(57.5, 8.2, 37), Vector3.new(53, 8.7, 46.5),
	}
	for vineIndex, vineSpot in vineSpots do
		local vine = WorldKit.part(greenhouse, "HangingVine" .. tostring(vineIndex),
			Vector3.new(0.25, 2.6 + (vineIndex % 2) * 0.8, 0.25),
			CFrame.new(vineSpot) * CFrame.Angles(math.rad(6), 0, math.rad(-5)),
			Color3.fromRGB(84, 128, 70), Enum.Material.Grass)
		vine.CanCollide = false
	end
	-- Potting table with a working drawer
	WorldKit.part(greenhouse, "PottingTableTop", Vector3.new(4, 0.4, 1.8),
		CFrame.new(54, 2.9, 46.6), PLANK, Enum.Material.WoodPlanks)
	for leg = -1, 1, 2 do
		WorldKit.part(greenhouse, "PottingTableLeg", Vector3.new(0.35, 2.3, 1.6),
			CFrame.new(54 + leg * 1.7, 1.75, 46.6), PLANK_DARK, Enum.Material.Wood)
	end
	WorldKit.drawer(greenhouse, "PottingDrawer", Vector3.new(1.7, 0.8, 0.4),
		CFrame.new(54, 2.3, 45.6) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(108, 80, 52))
	-- Lamp by the door gap
	WorldKit.part(greenhouse, "GreenhouseLampPost", Vector3.new(0.35, 5, 0.35),
		CFrame.new(50.5, 3.0, 30.6), PLANK_DARK, Enum.Material.Wood)
	local lampHead = WorldKit.part(greenhouse, "GreenhouseLampHead", Vector3.new(0.7, 0.7, 0.7),
		CFrame.new(50.5, 5.85, 30.6), Color3.fromRGB(255, 211, 132),
		Enum.Material.Neon, Enum.PartType.Ball)
	lampHead.CanCollide = false
	WorldKit.lamp(lampHead, { brightness = 1.2, range = 15 })
	WorldKit.evidenceSocketMarker(
		greenhouse,
		"greenhouse-potting-table",
		Vector3.new(54, 3.3, 46.6)
	)
end

-- FEATURE 8: sawmill between camp and town (night-only with the town reveal)
local function buildSawmill(nightTown: Instance)
	local sawmill = WorldKit.model(nightTown, "Sawmill")
	-- Kept west of x=-26 so the structure never encroaches on the main road
	-- corridor (x -25..25)
	WorldKit.part(sawmill, "SawmillFloor", Vector3.new(12.5, 0.7, 16.5),
		CFrame.new(-32, 0.95, -85), Color3.fromRGB(104, 100, 94), Enum.Material.Concrete)
	for postX = -1, 1, 2 do
		for postZ = -1, 1, 2 do
			WorldKit.part(sawmill, "SawmillPost", Vector3.new(0.8, 7.5, 0.8),
				CFrame.new(-32 + postX * 6, 4.15, -85 + postZ * 8),
				PLANK_DARK, Enum.Material.Wood)
		end
	end
	WorldKit.part(sawmill, "SawmillRoofWest", Vector3.new(7, 0.35, 17.5),
		CFrame.new(-35.2, 8.6, -85) * CFrame.Angles(0, 0, math.rad(8)),
		Color3.fromRGB(88, 84, 76), Enum.Material.CorrodedMetal)
	-- East roof panel is short — a storm tarp covers the gap
	WorldKit.part(sawmill, "SawmillRoofEast", Vector3.new(7, 0.35, 10),
		CFrame.new(-28.8, 8.4, -88.5) * CFrame.Angles(0, 0, math.rad(-8)),
		Color3.fromRGB(88, 84, 76), Enum.Material.CorrodedMetal)
	local tarp = WorldKit.part(sawmill, "SawmillTarp", Vector3.new(5.5, 0.18, 6.5),
		CFrame.new(-28.8, 8.5, -80) * CFrame.Angles(0, 0, math.rad(-8)),
		CANVAS, Enum.Material.Fabric)
	tarp.CanCollide = false
	WorldKit.stormDamage(tarp)
	-- Saw table with the big circular blade
	WorldKit.part(sawmill, "SawTable", Vector3.new(5, 2.2, 2.4),
		CFrame.new(-32, 2.4, -85), PLANK, Enum.Material.WoodPlanks)
	WorldKit.part(sawmill, "SawArbor", Vector3.new(1.2, 0.8, 0.8),
		CFrame.new(-32, 3.7, -84), Color3.fromRGB(58, 62, 66), Enum.Material.Metal)
	local blade = WorldKit.part(sawmill, "SawBlade", Vector3.new(0.25, 3.6, 3.6),
		CFrame.new(-32, 4.3, -85) * CFrame.Angles(0, math.rad(90), 0),
		RUST_BROWN, Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
	blade.CanCollide = false
	-- Log flume chute feeding in from the north
	for section = 1, 3 do
		WorldKit.wedge(sawmill, "FlumeSection" .. tostring(section),
			Vector3.new(3, 2, 5.5),
			CFrame.new(-32, 5.8 - section * 1.1, -99.5 + section * 4.6)
				* CFrame.Angles(math.rad(-13), 0, 0),
			Color3.fromRGB(102, 82, 54), Enum.Material.WoodPlanks)
	end
	for support = 1, 2 do
		WorldKit.part(sawmill, "FlumeSupport" .. tostring(support),
			Vector3.new(0.6, 3.6 + support * 0.8, 0.6),
			CFrame.new(-32 + (if support == 1 then -1.4 else 1.4), 2.4, -89 - support * 4),
			PLANK_DARK, Enum.Material.Wood)
	end
	-- Three logs riding the flume and the feed table
	WorldKit.part(sawmill, "FlumeLogA", Vector3.new(5, 1.5, 1.5),
		CFrame.new(-32, 5.6, -95.5) * CFrame.Angles(0, math.rad(90), math.rad(-11)),
		PINE_TRUNK, Enum.Material.Wood, Enum.PartType.Cylinder)
	WorldKit.part(sawmill, "FlumeLogB", Vector3.new(5, 1.5, 1.5),
		CFrame.new(-32, 4.4, -91) * CFrame.Angles(0, math.rad(90), math.rad(-11)),
		PINE_TRUNK, Enum.Material.Wood, Enum.PartType.Cylinder)
	WorldKit.part(sawmill, "FeedLog", Vector3.new(4.5, 1.4, 1.4),
		CFrame.new(-34.6, 4.0, -85), PINE_TRUNK, Enum.Material.Wood, Enum.PartType.Cylinder)
	-- Sawdust piles
	local dustSpots = {
		Vector3.new(-30, 1.55, -83.2),
		Vector3.new(-33.6, 1.5, -86.5),
		Vector3.new(-29, 1.45, -87.5),
	}
	for dustIndex, dustSpot in dustSpots do
		local pile = verticalCylinder(sawmill, "SawdustPile" .. tostring(dustIndex),
			0.5, 2.6, dustSpot, Color3.fromRGB(196, 172, 124), Enum.Material.Sand)
		pile.CanCollide = false
	end
	-- Log stacks on the west side
	for stack = 1, 2 do
		local stackZ = if stack == 1 then -90 else -79
		for log = 1, 3 do
			WorldKit.part(sawmill, "StackLog", Vector3.new(6, 1.6, 1.6),
				CFrame.new(
					-39.5,
					if log == 3 then 2.9 else 1.6,
					stackZ + (if log == 1 then -0.85 elseif log == 2 then 0.85 else 0)
				),
				PINE_TRUNK, Enum.Material.Wood, Enum.PartType.Cylinder)
		end
	end
	-- Rusty hand tools on a wall board
	WorldKit.part(sawmill, "ToolBoard", Vector3.new(0.15, 2.4, 3.6),
		CFrame.new(-37.9, 5.2, -89), Color3.fromRGB(84, 66, 46), Enum.Material.WoodPlanks)
	WorldKit.part(sawmill, "ToolHandSaw", Vector3.new(0.08, 0.5, 1.6),
		CFrame.new(-37.7, 5.6, -88.2), RUST_BROWN, Enum.Material.CorrodedMetal)
	WorldKit.part(sawmill, "ToolWrench", Vector3.new(0.1, 0.9, 0.25),
		CFrame.new(-37.7, 5.1, -89.6) * CFrame.Angles(math.rad(15), 0, 0),
		RUST_BROWN, Enum.Material.CorrodedMetal)
	WorldKit.part(sawmill, "ToolAxeHandle", Vector3.new(0.12, 1.3, 0.12),
		CFrame.new(-37.7, 4.8, -90.3) * CFrame.Angles(0, 0, math.rad(12)),
		PLANK_DARK, Enum.Material.Wood)
	WorldKit.part(sawmill, "ToolAxeHead", Vector3.new(0.14, 0.4, 0.55),
		CFrame.new(-37.75, 5.5, -90.35), RUST_BROWN, Enum.Material.CorrodedMetal)
	-- Hanging work lantern under the ridge
	local workLamp = WorldKit.part(sawmill, "SawmillLampHead", Vector3.new(0.7, 0.7, 0.7),
		CFrame.new(-32, 7.2, -85), Color3.fromRGB(255, 211, 132),
		Enum.Material.Neon, Enum.PartType.Ball)
	workLamp.CanCollide = false
	WorldKit.lamp(workLamp, { brightness = 1.3, range = 17 })
	WorldKit.evidenceSocketMarker(sawmill, "sawmill-blade", Vector3.new(-32, 4.5, -85))
end

-- FEATURE 9: cornfield with trampled lanes, a scarecrow, and a broken wagon
local function buildCornfield(nightTown: Instance)
	local cornfield = WorldKit.model(nightTown, "Cornfield")
	local stalkColorA = Color3.fromRGB(172, 178, 96)
	local stalkColorB = Color3.fromRGB(154, 166, 84)
	local scarecrowSpot = Vector2.new(62, -100)
	local bareTreeSpot = Vector2.new(48, -95) -- existing outskirts snag; leave a hollow
	local placed = 0
	for column = 0, 8 do
		for row = 0, 10 do
			if placed >= 90 then
				break
			end
			local stalkX = 43 + column * 5 + math.sin(row * 3.1 + column) * 1.3
			local stalkZ = -77 - row * 4.6 + math.cos(column * 2.3 + row) * 1.3
			-- Two winding trampled lanes stay stalk-free
			local laneAZ = -100 + 9 * math.sin((stalkX - 40) / 9)
			local laneBX = 63 + 8 * math.sin((stalkZ + 100) / 11)
			local nearLane = math.abs(stalkZ - laneAZ) < 2.6
				or math.abs(stalkX - laneBX) < 2.6
			local nearScarecrow = (Vector2.new(stalkX, stalkZ) - scarecrowSpot).Magnitude < 3.5
			local nearSnag = (Vector2.new(stalkX, stalkZ) - bareTreeSpot).Magnitude < 3
			if not nearLane and not nearScarecrow and not nearSnag then
				placed += 1
				local stalkHeight = 2.3 + ((column + row) % 3) * 0.3
				local yaw = math.rad(40 + (column * 7 + row * 13) % 40)
				local color = if (column + row) % 2 == 0 then stalkColorA else stalkColorB
				for cross = 0, 1 do
					local blade = WorldKit.part(
						cornfield,
						"CornStalk",
						Vector3.new(1.9, stalkHeight, 0.18),
						CFrame.new(stalkX, 0.35 + stalkHeight / 2, stalkZ)
							* CFrame.Angles(0, yaw + cross * math.pi / 2, 0),
						color,
						Enum.Material.Grass
					)
					blade.CanCollide = false
				end
			end
		end
	end
	-- Scarecrow on a pole at the field's heart — burlap head, button eyes
	local scarecrow = WorldKit.model(cornfield, "Scarecrow")
	WorldKit.part(scarecrow, "ScarecrowPole", Vector3.new(0.45, 5.6, 0.45),
		CFrame.new(62, 2.8, -100), PLANK_DARK, Enum.Material.Wood)
	WorldKit.part(scarecrow, "ScarecrowCrossarm", Vector3.new(4.6, 0.4, 0.4),
		CFrame.new(62, 4.7, -100), PLANK_DARK, Enum.Material.Wood)
	WorldKit.part(scarecrow, "ScarecrowTorso", Vector3.new(1.7, 2.3, 1.0),
		CFrame.new(62, 3.9, -100), BURLAP, Enum.Material.Fabric)
	WorldKit.part(scarecrow, "ScarecrowHead", Vector3.new(1.25, 1.25, 1.25),
		CFrame.new(62, 5.6, -100), BURLAP, Enum.Material.Fabric, Enum.PartType.Ball)
	for eye = -1, 1, 2 do
		local button = WorldKit.part(scarecrow, "ScarecrowButtonEye",
			Vector3.new(0.22, 0.22, 0.12),
			CFrame.new(62 + eye * 0.25, 5.75, -100.55),
			Color3.fromRGB(24, 20, 18), Enum.Material.SmoothPlastic)
		button.CanCollide = false
	end
	for arm = -1, 1, 2 do
		WorldKit.part(scarecrow, "ScarecrowStrawArm", Vector3.new(1.6, 0.28, 0.28),
			CFrame.new(62 + arm * 2.6, 4.55, -100)
				* CFrame.Angles(0, 0, math.rad(-14 * arm)),
			STRAW, Enum.Material.Grass)
	end
	local neckStraw = WorldKit.part(scarecrow, "ScarecrowNeckStraw",
		Vector3.new(0.6, 0.5, 0.6), CFrame.new(62, 5.0, -100),
		STRAW, Enum.Material.Grass, Enum.PartType.Ball)
	neckStraw.CanCollide = false
	WorldKit.evidenceSocketMarker(cornfield, "cornfield-scarecrow", Vector3.new(62, 5.2, -100))
	-- Broken wagon at the field edge
	local wagon = WorldKit.model(cornfield, "BrokenWagon")
	local wagonCFrame = CFrame.new(42.5, 1.35, -76)
		* CFrame.Angles(0, math.rad(25), math.rad(-9))
	WorldKit.part(wagon, "WagonBed", Vector3.new(5, 0.4, 2.8), wagonCFrame,
		Color3.fromRGB(92, 70, 46), Enum.Material.WoodPlanks)
	for rail = -1, 1, 2 do
		WorldKit.part(wagon, "WagonRail", Vector3.new(5, 0.7, 0.25),
			wagonCFrame * CFrame.new(0, 0.55, rail * 1.3),
			Color3.fromRGB(80, 60, 40), Enum.Material.WoodPlanks)
	end
	WorldKit.part(wagon, "WagonWheel", Vector3.new(0.4, 2.6, 2.6),
		CFrame.new(45.4, 1.6, -75.2) * CFrame.Angles(0, math.rad(20), math.rad(78)),
		Color3.fromRGB(52, 38, 24), Enum.Material.Wood, Enum.PartType.Cylinder)
	WorldKit.part(wagon, "WagonAxle", Vector3.new(0.3, 0.3, 3.4),
		wagonCFrame * CFrame.new(-1.2, -0.4, 0) * CFrame.Angles(math.rad(8), 0, 0),
		Color3.fromRGB(58, 62, 66), Enum.Material.Metal)
end

-- FEATURE 10: wildlife props (loops start in LakeAndWilds.Start)
local function buildOwl(parent: Instance, perch: Vector3, faceToward: Vector3): Owl
	local snagHeight = perch.Y - 0.5
	verticalCylinder(
		parent,
		"OwlSnag",
		snagHeight,
		0.6,
		Vector3.new(perch.X - 1.6, 0.4 + snagHeight / 2, perch.Z),
		Color3.fromRGB(52, 44, 36),
		Enum.Material.Wood
	)
	WorldKit.part(parent, "OwlBranch", Vector3.new(2.6, 0.28, 0.28),
		CFrame.new(perch.X - 0.6, perch.Y - 0.75, perch.Z),
		Color3.fromRGB(44, 36, 28), Enum.Material.Wood)
	local body = WorldKit.part(parent, "OwlBody", Vector3.new(1.05, 1.35, 0.95),
		CFrame.new(perch.X, perch.Y, perch.Z), Color3.fromRGB(96, 78, 58),
		Enum.Material.Fabric)
	body.CanCollide = false
	local headPosition = perch + Vector3.new(0, 0.95, 0)
	local baseCFrame = CFrame.lookAt(
		headPosition,
		Vector3.new(faceToward.X, headPosition.Y, faceToward.Z)
	)
	local head = WorldKit.part(parent, "OwlHead", Vector3.new(0.85, 0.85, 0.85),
		baseCFrame, Color3.fromRGB(86, 70, 52), Enum.Material.Fabric, Enum.PartType.Ball)
	head.CanCollide = false
	local eyes = {} :: { BasePart }
	local eyeOffsets = {} :: { CFrame }
	for eye = -1, 1, 2 do
		local offset = CFrame.new(eye * 0.21, 0.08, -0.36)
		local eyeball = WorldKit.part(parent, "OwlEye", Vector3.new(0.3, 0.3, 0.16),
			baseCFrame * offset, Color3.fromRGB(228, 206, 96), Enum.Material.Neon,
			Enum.PartType.Ball)
		eyeball.CanCollide = false
		table.insert(eyes, eyeball)
		table.insert(eyeOffsets, offset)
	end
	return {
		head = head,
		baseCFrame = baseCFrame,
		eyes = eyes,
		eyeOffsets = eyeOffsets,
	}
end

local function buildWildlife(dayCamp: Instance)
	local wildlife = WorldKit.model(dayCamp, "Wildlife")
	-- Firefly swarms: lake shore, plaza edge, and the SW thicket
	local anchorSpots = {
		Vector3.new(86, 2.6, 44),
		Vector3.new(12, 2.6, 10),
		Vector3.new(-86, 3, -52),
	}
	for anchorIndex, anchor in anchorSpots do
		local folder = Instance.new("Folder")
		folder.Name = "FireflySwarm" .. tostring(anchorIndex)
		folder.Parent = wildlife
		local orbs = {} :: { BasePart }
		for orb = 1, 6 do
			local spark = WorldKit.part(
				folder,
				"Firefly",
				Vector3.new(0.35, 0.35, 0.35),
				CFrame.new(anchor + Vector3.new(
					math.cos(orb * 1.9) * 2.2,
					(orb % 3) * 0.9,
					math.sin(orb * 2.6) * 2.2
				)),
				Color3.fromRGB(200, 255, 120),
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
			spark.CanCollide = false
			spark.CanTouch = false
			spark.CanQuery = false
			table.insert(orbs, spark)
		end
		table.insert(state.swarms, { folder = folder, origin = anchor, orbs = orbs })
	end
	-- Owls: one in the SW thicket, one near the lookout base. Silent by
	-- design — no marketplace asset ids; the periodic head-turn is the tell.
	table.insert(state.owls, buildOwl(wildlife, Vector3.new(-79, 6.6, -54), Vector3.new(0, 0, 12)))
	table.insert(state.owls, buildOwl(wildlife, Vector3.new(8, 7.4, 105), Vector3.new(0, 0, 12)))
	-- Fox: patrols the west treeline; doubles as an early-warning tell when it
	-- darts away from approaching players
	state.foxWaypoints = {
		Vector3.new(-92, 0.5, -8),
		Vector3.new(-83, 0.5, 14),
		Vector3.new(-95, 0.5, 34),
		Vector3.new(-84, 0.5, -24),
	}
	local fox = WorldKit.model(wildlife, "TreelineFox")
	local orange = Color3.fromRGB(196, 108, 48)
	local cream = Color3.fromRGB(232, 224, 210)
	local base = CFrame.new(state.foxWaypoints[1])
	local body = WorldKit.part(fox, "FoxBody", Vector3.new(1.0, 1.0, 2.3),
		base * CFrame.new(0, 1.15, 0), orange, Enum.Material.Fabric)
	body.CanCollide = false
	fox.PrimaryPart = body
	local head = WorldKit.part(fox, "FoxHead", Vector3.new(0.85, 0.75, 0.8),
		base * CFrame.new(0, 1.55, -1.5), orange, Enum.Material.Fabric)
	head.CanCollide = false
	local snout = WorldKit.part(fox, "FoxSnout", Vector3.new(0.4, 0.3, 0.5),
		base * CFrame.new(0, 1.4, -2.0), cream, Enum.Material.Fabric)
	snout.CanCollide = false
	for ear = -1, 1, 2 do
		local earWedge = WorldKit.wedge(fox, "FoxEar", Vector3.new(0.3, 0.45, 0.3),
			base * CFrame.new(ear * 0.24, 2.0, -1.5), orange, Enum.Material.Fabric)
		earWedge.CanCollide = false
	end
	local tail = WorldKit.wedge(fox, "FoxTail", Vector3.new(0.5, 0.5, 1.6),
		base * CFrame.new(0, 1.35, 1.75) * CFrame.Angles(math.rad(24), 0, 0),
		orange, Enum.Material.Fabric)
	tail.CanCollide = false
	local tailTip = WorldKit.part(fox, "FoxTailTip", Vector3.new(0.4, 0.4, 0.5),
		base * CFrame.new(0, 1.7, 2.5), cream, Enum.Material.Fabric)
	tailTip.CanCollide = false
	for legX = -1, 1, 2 do
		for legZ = -1, 1, 2 do
			local leg = WorldKit.part(fox, "FoxLeg", Vector3.new(0.28, 0.9, 0.28),
				base * CFrame.new(legX * 0.32, 0.45, legZ * 0.8),
				Color3.fromRGB(74, 52, 38), Enum.Material.Fabric)
			leg.CanCollide = false
		end
	end
	state.fox = fox
end

-- Wildlife loops -------------------------------------------------------------

local function startFireflyLoops()
	for _, swarm in state.swarms do
		task.spawn(function()
			while swarm.folder.Parent ~= nil do
				for _, orb in swarm.orbs do
					local target = swarm.origin + Vector3.new(
						(math.random() - 0.5) * 8,
						math.random() * 3,
						(math.random() - 0.5) * 8
					)
					TweenService:Create(
						orb,
						TweenInfo.new(
							2.2 + math.random() * 1.4,
							Enum.EasingStyle.Sine,
							Enum.EasingDirection.InOut
						),
						{ Position = target }
					):Play()
				end
				task.wait(2 + math.random() * 2)
			end
		end)
	end
end

local function startOwlLoops()
	for _, owl in state.owls do
		task.spawn(function()
			while owl.head.Parent ~= nil do
				task.wait(math.random(45, 90))
				local yaw = math.rad(math.random(-65, 65))
				local turned = owl.baseCFrame * CFrame.Angles(0, yaw, 0)
				local turnInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				TweenService:Create(owl.head, turnInfo, { CFrame = turned }):Play()
				for eyeIndex, eyeball in owl.eyes do
					TweenService:Create(eyeball, turnInfo, {
						CFrame = turned * owl.eyeOffsets[eyeIndex],
					}):Play()
				end
				task.wait(math.random(2, 5))
				local backInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
				TweenService:Create(owl.head, backInfo, { CFrame = owl.baseCFrame }):Play()
				for eyeIndex, eyeball in owl.eyes do
					TweenService:Create(eyeball, backInfo, {
						CFrame = owl.baseCFrame * owl.eyeOffsets[eyeIndex],
					}):Play()
				end
			end
		end)
	end
end

local function startFoxLoop()
	local fox = state.fox
	if fox == nil or #state.foxWaypoints == 0 then
		return
	end
	task.spawn(function()
		local position = state.foxWaypoints[1]
		local targetIndex = 2
		local speed = 4
		local darting = false
		local idleRemaining = 0
		local checkTimer = 0
		while fox.Parent ~= nil do
			local dt = task.wait(0.06)
			-- Poll player proximity on a 0.5s cadence
			checkTimer += dt
			if checkTimer >= 0.5 then
				checkTimer = 0
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local root = if character ~= nil
						then character:FindFirstChild("HumanoidRootPart")
						else nil
					if root ~= nil and root:IsA("BasePart") then
						local flat = Vector3.new(
							root.Position.X - position.X,
							0,
							root.Position.Z - position.Z
						)
						if flat.Magnitude < 12 then
							-- Spooked: dart to the waypoint farthest from the player
							local farIndex = 1
							local farDistance = -1
							for waypointIndex, waypoint in state.foxWaypoints do
								local away = (waypoint - root.Position) * Vector3.new(1, 0, 1)
								if away.Magnitude > farDistance then
									farDistance = away.Magnitude
									farIndex = waypointIndex
								end
							end
							targetIndex = farIndex
							darting = true
							speed = 18
							idleRemaining = 0
							break
						end
					end
				end
			end
			if idleRemaining > 0 then
				idleRemaining -= dt
			else
				local target = state.foxWaypoints[targetIndex]
				local delta = (target - position) * Vector3.new(1, 0, 1)
				local distance = delta.Magnitude
				local step = speed * dt
				if distance <= step then
					position = target
					targetIndex = targetIndex % #state.foxWaypoints + 1
					if darting then
						darting = false
						speed = 4
						idleRemaining = 2.5
					else
						idleRemaining = 1 + math.random() * 2
					end
				else
					position += delta.Unit * step
				end
				local lookTarget = state.foxWaypoints[targetIndex]
				fox:PivotTo(CFrame.lookAt(
					position + Vector3.new(0, 1.15, 0),
					Vector3.new(lookTarget.X, position.Y + 1.15, lookTarget.Z)
				))
			end
		end
	end)
end

-- Public API -----------------------------------------------------------------

local LakeAndWilds = {}

function LakeAndWilds.Build(dayCamp: Instance, nightTown: Instance)
	if state.built then
		return
	end
	state.built = true
	buildLakeShore(dayCamp)
	buildRowboats(dayCamp)
	buildIsland(dayCamp)
	buildSwimmingHole(dayCamp)
	buildWaterfallCave(dayCamp)
	buildThickets(dayCamp)
	buildGreenhouse(dayCamp)
	buildSawmill(nightTown)
	buildCornfield(nightTown)
	buildWildlife(dayCamp)
end

function LakeAndWilds.Start()
	if state.started or not state.built then
		return
	end
	state.started = true
	startFireflyLoops()
	startOwlLoops()
	startFoxLoop()
end

return LakeAndWilds
