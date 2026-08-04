--!strict

-- SeasonalDressing: Brookhaven-style seasonal refresh for the day camp.
-- Build(dayCamp) reads the real calendar month and dresses the camp for the
-- current season, then builds the reserved EVENT GROUNDS clearing at
-- (-48, ~, -8) (radius ~14): a permanent low stage + banner frame, plus a
-- per-season event inside the clearing.
--
--   Sep-Nov  autumn  — leaf piles near the paths, pumpkins at the plaza edge;
--                      harvest stalls with pumpkin/corn crates
--   Dec-Feb  winter  — snow caps on cabin roof ridgelines, frozen lake edge,
--                      snowman; small bordered ice rink
--   Mar-May  spring  — wildflower tufts, blossom rings around four trees;
--                      flower arch + seed table
--   Jun-Aug  summer  — towels + beach ball at the swimming hole, picnic
--                      blanket + basket; lemonade stand + ring-toss posts
--
-- Only the current season's set is built. Everything lands in two folders
-- under dayCamp — "Seasonal" and "EventGrounds" — and Build is idempotent:
-- it tears down and rebuilds both folders, so calling it once per round (or
-- after a map rebuild) is safe. Terrain surface sits at y ~= 0.5. Zero
-- marketplace asset ids; ~40-60 parts depending on the season.

local WorldKit = require(script.Parent:WaitForChild("WorldKit"))

local SEASONAL_FOLDER_NAME = "Seasonal"
local EVENT_GROUNDS_FOLDER_NAME = "EventGrounds"

local GROUND_Y = 0.5

-- Event grounds clearing: keep every event build inside this circle.
local EVENT_CENTER = Vector3.new(-48, GROUND_Y, -8)

type Season = "autumn" | "winter" | "spring" | "summer"

local SeasonalDressing = {}

local function resolveSeason(month: number): Season
	if month >= 9 and month <= 11 then
		return "autumn"
	elseif month == 12 or month <= 2 then
		return "winter"
	elseif month >= 3 and month <= 5 then
		return "spring"
	end
	return "summer"
end

local function upright(position: Vector3): CFrame
	-- Cylinder axis is X; this roll stands it upright.
	return CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

local function disc(
	parent: Instance,
	name: string,
	diameter: number,
	thickness: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = WorldKit.part(
		parent,
		name,
		Vector3.new(thickness, diameter, diameter),
		upright(position),
		color,
		material,
		Enum.PartType.Cylinder
	)
	part.CanCollide = false
	return part
end

local function ball(
	parent: Instance,
	name: string,
	diameter: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	return WorldKit.part(
		parent,
		name,
		Vector3.new(diameter, diameter, diameter),
		CFrame.new(position),
		color,
		material,
		Enum.PartType.Ball
	)
end

-- ---------------------------------------------------------------------------
-- Seasonal sets ("Seasonal" folder)

local LEAF_PILE_SPOTS: { { x: number, z: number, diameter: number } } = {
	{ x = -6, z = -52, diameter = 4.4 },
	{ x = 7, z = -40, diameter = 3.4 },
	{ x = -9, z = -28, diameter = 4.0 },
	{ x = 5, z = -16, diameter = 3.6 },
	{ x = 13, z = -4, diameter = 4.2 },
	{ x = -13, z = 4, diameter = 3.2 },
	{ x = 9, z = 14, diameter = 4.6 },
	{ x = -7, z = 26, diameter = 3.8 },
	{ x = 6, z = 38, diameter = 4.0 },
	{ x = -10, z = 48, diameter = 3.4 },
	{ x = 4, z = 58, diameter = 4.4 },
	{ x = -5, z = 68, diameter = 3.6 },
}

local LEAF_COLORS: { Color3 } = {
	Color3.fromRGB(191, 94, 38),
	Color3.fromRGB(158, 52, 31),
	Color3.fromRGB(205, 128, 42),
}

local function buildPumpkin(parent: Instance, position: Vector3, diameter: number)
	local body = ball(
		parent,
		"Pumpkin",
		diameter,
		-- Sunk slightly so the sphere reads as a squat pumpkin.
		position + Vector3.new(0, diameter * 0.42, 0),
		Color3.fromRGB(206, 110, 34),
		Enum.Material.SmoothPlastic
	)
	local stem = WorldKit.part(
		parent,
		"PumpkinStem",
		Vector3.new(0.55, 0.28, 0.28),
		upright(position + Vector3.new(0, diameter * 0.92, 0)),
		Color3.fromRGB(88, 92, 48),
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	stem.CanCollide = false
	body.CanCollide = false
end

local function buildAutumnSeasonal(seasonal: Folder)
	for index, spot in LEAF_PILE_SPOTS do
		disc(
			seasonal,
			"LeafPile" .. index,
			spot.diameter,
			0.22,
			Vector3.new(spot.x, GROUND_Y + 0.12, spot.z),
			LEAF_COLORS[(index - 1) % #LEAF_COLORS + 1],
			Enum.Material.Grass
		)
	end
	-- Three pumpkins along the campfire plaza edge (seat ring is radius ~10).
	buildPumpkin(seasonal, Vector3.new(14, GROUND_Y, -5), 1.8)
	buildPumpkin(seasonal, Vector3.new(16.5, GROUND_Y, 1), 1.5)
	buildPumpkin(seasonal, Vector3.new(13.5, GROUND_Y, 7), 2.1)
end

local function buildSnowman(parent: Instance, position: Vector3)
	ball(parent, "SnowmanBase", 2.6, position + Vector3.new(0, 1.1, 0), Color3.fromRGB(240, 244, 248), Enum.Material.Snow)
	ball(parent, "SnowmanBody", 2.0, position + Vector3.new(0, 2.9, 0), Color3.fromRGB(240, 244, 248), Enum.Material.Snow)
	ball(parent, "SnowmanHead", 1.4, position + Vector3.new(0, 4.3, 0), Color3.fromRGB(240, 244, 248), Enum.Material.Snow)
	-- Carrot nose (cylinder standing in for a cone) pointing toward camp.
	local nose = WorldKit.part(
		parent,
		"SnowmanNose",
		Vector3.new(0.7, 0.22, 0.22),
		CFrame.new(position + Vector3.new(0.85, 4.3, 0)),
		Color3.fromRGB(214, 122, 38),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	nose.CanCollide = false
	for side = -1, 1, 2 do
		local arm = WorldKit.part(
			parent,
			"SnowmanArm",
			Vector3.new(0.18, 1.8, 0.18),
			CFrame.new(position + Vector3.new(0, 3.1, side * 1.4))
				* CFrame.Angles(math.rad(side * 55), 0, 0),
			Color3.fromRGB(74, 56, 38),
			Enum.Material.Wood
		)
		arm.CanCollide = false
	end
end

local function buildWinterSeasonal(seasonal: Folder, dayCamp: Instance)
	-- Snow caps on every cabin roof ridgeline the map service built.
	local capCount = 0
	for _, descendant in dayCamp:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == "RoofRidge" and capCount < 8 then
			capCount += 1
			local cap = WorldKit.part(
				seasonal,
				"SnowCap" .. capCount,
				Vector3.new(descendant.Size.X + 0.5, 0.35, descendant.Size.Z + 0.5),
				descendant.CFrame * CFrame.new(0, descendant.Size.Y / 2 + 0.2, 0),
				Color3.fromRGB(240, 244, 248),
				Enum.Material.Snow
			)
			cap.CanCollide = false
		end
	end
	-- Frozen lake edge: translucent ice sheets along the western shore
	-- (x ~= 88, z -20..40; the water surface tops out around y 1.6).
	for index, z in { -14, 1, 16, 31 } do
		local sheet = WorldKit.part(
			seasonal,
			"LakeIce" .. index,
			Vector3.new(9, 0.35, 14),
			CFrame.new(89, 1.62, z) * CFrame.Angles(0, math.rad((index % 2) * 9 - 4), 0),
			Color3.fromRGB(180, 215, 230),
			Enum.Material.Ice
		)
		sheet.Transparency = 0.3
		sheet.CanCollide = false
	end
	buildSnowman(seasonal, Vector3.new(-55, GROUND_Y, -15))
end

local TUFT_SPOTS: { { x: number, z: number } } = {
	{ x = -8, z = -46 },
	{ x = 9, z = -34 },
	{ x = -12, z = -12 },
	{ x = 15, z = -10 },
	{ x = -14, z = 10 },
	{ x = 11, z = 22 },
	{ x = -8, z = 34 },
	{ x = 7, z = 46 },
	{ x = -11, z = 56 },
	{ x = 5, z = 66 },
}

local TUFT_COLORS: { Color3 } = {
	Color3.fromRGB(226, 128, 168),
	Color3.fromRGB(158, 118, 214),
	Color3.fromRGB(236, 200, 80),
	Color3.fromRGB(240, 240, 236),
}

local function buildSpringSeasonal(seasonal: Folder, dayCamp: Instance)
	-- Wildflower tufts: small pointed wedges standing in for cones (there is
	-- no cone PartType and mesh assets are off the table).
	for index, spot in TUFT_SPOTS do
		local tuft = WorldKit.wedge(
			seasonal,
			"WildflowerTuft" .. index,
			Vector3.new(0.9, 1.1, 0.9),
			CFrame.new(spot.x, GROUND_Y + 0.55, spot.z)
				* CFrame.Angles(0, math.rad(index * 73), 0),
			TUFT_COLORS[(index - 1) % #TUFT_COLORS + 1],
			Enum.Material.Grass
		)
		tuft.CanCollide = false
	end
	-- Blossom rings around the first four pines the map service planted.
	local ringCount = 0
	for _, descendant in dayCamp:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == "PineTrunk" and ringCount < 4 then
			ringCount += 1
			local base = Vector3.new(descendant.Position.X, GROUND_Y + 0.08, descendant.Position.Z)
			local ring = disc(
				seasonal,
				"BlossomRing" .. ringCount,
				7,
				0.16,
				base,
				Color3.fromRGB(233, 180, 200),
				Enum.Material.Grass
			)
			ring.Transparency = 0.15
		end
	end
end

local function buildSummerSeasonal(seasonal: Folder)
	-- Swimming hole dressing: towels on the beach shallows by the bay.
	local towelColors: { Color3 } = {
		Color3.fromRGB(64, 140, 200),
		Color3.fromRGB(220, 90, 90),
		Color3.fromRGB(120, 190, 120),
	}
	local towelSpots: { CFrame } = {
		CFrame.new(80, 1.7, 68) * CFrame.Angles(0, math.rad(24), 0),
		CFrame.new(76.5, 1.7, 62) * CFrame.Angles(0, math.rad(-40), 0),
		CFrame.new(83, 1.7, 74) * CFrame.Angles(0, math.rad(70), 0),
	}
	for index, cframe in towelSpots do
		local towel = WorldKit.part(
			seasonal,
			"BeachTowel" .. index,
			Vector3.new(2.2, 0.08, 4.6),
			cframe,
			towelColors[index],
			Enum.Material.Fabric
		)
		towel.CanCollide = false
	end
	-- Beach ball floating on the swimming hole (95, ~, 78): unanchored, light
	-- enough to bob and be knocked around (3008-style physics prop). Tagged
	-- Clutter so WorldAmbience gives it an impact clatter.
	local beachBall = ball(
		seasonal,
		"BeachBall",
		1.8,
		Vector3.new(95, 2.4, 78),
		Color3.fromRGB(236, 84, 84),
		Enum.Material.SmoothPlastic
	)
	beachBall.Anchored = false
	beachBall.CustomPhysicalProperties = PhysicalProperties.new(0.28, 0.4, 0.6)
	beachBall:SetAttribute("Clutter", true)

	-- Picnic blanket + basket at (12, ~, 18).
	local blanketCFrame = CFrame.new(12, GROUND_Y + 0.12, 18) * CFrame.Angles(0, math.rad(14), 0)
	local blanket = WorldKit.part(
		seasonal,
		"PicnicBlanket",
		Vector3.new(5.5, 0.12, 5.5),
		blanketCFrame,
		Color3.fromRGB(188, 70, 60),
		Enum.Material.Fabric
	)
	blanket.CanCollide = false
	for stripe = -1, 1, 2 do
		local band = WorldKit.part(
			seasonal,
			"PicnicStripe",
			Vector3.new(5.5, 0.13, 0.5),
			blanketCFrame * CFrame.new(0, 0.01, stripe * 1.4),
			Color3.fromRGB(238, 230, 218),
			Enum.Material.Fabric
		)
		band.CanCollide = false
	end
	WorldKit.part(
		seasonal,
		"PicnicBasket",
		Vector3.new(1.6, 1.0, 1.1),
		blanketCFrame * CFrame.new(1.7, 0.6, -1.6),
		Color3.fromRGB(134, 96, 56),
		Enum.Material.Wood
	)
	local handle = WorldKit.part(
		seasonal,
		"PicnicBasketHandle",
		Vector3.new(0.14, 0.5, 1.1),
		blanketCFrame * CFrame.new(1.7, 1.35, -1.6),
		Color3.fromRGB(110, 78, 44),
		Enum.Material.Wood
	)
	handle.CanCollide = false
end

-- ---------------------------------------------------------------------------
-- Event grounds ("EventGrounds" folder), all inside the reserved clearing

-- Stage sits toward the back (west) of the clearing so each season's event
-- fits in front of it, still inside radius ~14 of EVENT_CENTER.
local STAGE_CENTER = EVENT_CENTER + Vector3.new(-5, 0, 0)

local SEASON_BANNER_COLORS: { [Season]: Color3 } = {
	autumn = Color3.fromRGB(196, 108, 44),
	winter = Color3.fromRGB(150, 196, 226),
	spring = Color3.fromRGB(226, 140, 176),
	summer = Color3.fromRGB(236, 196, 70),
}

local function buildStageAndBanners(eventGrounds: Folder, season: Season)
	WorldKit.part(
		eventGrounds,
		"EventStage",
		Vector3.new(10, 1, 8),
		CFrame.new(STAGE_CENTER + Vector3.new(0, 0.5, 0)),
		Color3.fromRGB(110, 84, 55),
		Enum.Material.WoodPlanks
	)
	for side = -1, 1, 2 do
		WorldKit.part(
			eventGrounds,
			"BannerPole",
			Vector3.new(0.45, 8, 0.45),
			CFrame.new(EVENT_CENTER + Vector3.new(1.5, 4, side * 5.5)),
			Color3.fromRGB(74, 56, 38),
			Enum.Material.Wood
		)
	end
	WorldKit.part(
		eventGrounds,
		"BannerBeam",
		Vector3.new(0.45, 0.7, 11.5),
		CFrame.new(EVENT_CENTER + Vector3.new(1.5, 8.35, 0)),
		Color3.fromRGB(74, 56, 38),
		Enum.Material.Wood
	)
	local banner = WorldKit.part(
		eventGrounds,
		"EventBanner",
		Vector3.new(0.15, 2.2, 7),
		CFrame.new(EVENT_CENTER + Vector3.new(1.5, 6.9, 0)),
		SEASON_BANNER_COLORS[season],
		Enum.Material.Fabric
	)
	banner.CanCollide = false
end

local function buildMarketStall(eventGrounds: Folder, center: Vector3, awningColor: Color3, produce: string)
	WorldKit.part(
		eventGrounds,
		"StallCounter",
		Vector3.new(1.8, 1.1, 4.5),
		CFrame.new(center + Vector3.new(0, 0.55, 0)),
		Color3.fromRGB(126, 96, 62),
		Enum.Material.WoodPlanks
	)
	for side = -1, 1, 2 do
		WorldKit.part(
			eventGrounds,
			"StallPost",
			Vector3.new(0.35, 5, 0.35),
			CFrame.new(center + Vector3.new(-0.9, 2.5, side * 2.1)),
			Color3.fromRGB(96, 70, 45),
			Enum.Material.Wood
		)
	end
	local awning = WorldKit.part(
		eventGrounds,
		"StallAwning",
		Vector3.new(2.8, 0.22, 5),
		CFrame.new(center + Vector3.new(-0.2, 5.15, 0)) * CFrame.Angles(0, 0, math.rad(-12)),
		awningColor,
		Enum.Material.Fabric
	)
	awning.CanCollide = false
	WorldKit.part(
		eventGrounds,
		"StallCrate",
		Vector3.new(1.7, 0.9, 1.7),
		CFrame.new(center + Vector3.new(1.4, 0.45, 1.2)),
		Color3.fromRGB(110, 84, 52),
		Enum.Material.WoodPlanks
	)
	if produce == "pumpkin" then
		local crop = ball(
			eventGrounds,
			"CratePumpkin",
			1.2,
			center + Vector3.new(1.4, 1.3, 1.2),
			Color3.fromRGB(206, 110, 34),
			Enum.Material.SmoothPlastic
		)
		crop.CanCollide = false
	else
		for offset = -1, 1 do
			local cob = WorldKit.part(
				eventGrounds,
				"CrateCorn",
				Vector3.new(1.0, 0.3, 0.3),
				upright(center + Vector3.new(1.4, 1.3, 1.2 + offset * 0.42)),
				Color3.fromRGB(228, 198, 86),
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			)
			cob.CanCollide = false
		end
	end
end

local function buildAutumnEvent(eventGrounds: Folder)
	buildMarketStall(
		eventGrounds,
		EVENT_CENTER + Vector3.new(6, 0, -6.5),
		Color3.fromRGB(170, 60, 50),
		"pumpkin"
	)
	buildMarketStall(
		eventGrounds,
		EVENT_CENTER + Vector3.new(6, 0, 6.5),
		Color3.fromRGB(70, 120, 74),
		"corn"
	)
end

local function buildWinterEvent(eventGrounds: Folder)
	-- Small ice rink with a low border, in front of the stage.
	local rinkCenter = EVENT_CENTER + Vector3.new(6.5, 0, 0)
	local rink = WorldKit.part(
		eventGrounds,
		"IceRink",
		Vector3.new(9, 0.4, 12),
		CFrame.new(rinkCenter + Vector3.new(0, 0.2, 0)),
		Color3.fromRGB(190, 220, 235),
		Enum.Material.Ice
	)
	rink.Transparency = 0.12
	for side = -1, 1, 2 do
		WorldKit.part(
			eventGrounds,
			"RinkBorderLong",
			Vector3.new(9.8, 0.7, 0.45),
			CFrame.new(rinkCenter + Vector3.new(0, 0.55, side * 6.2)),
			Color3.fromRGB(226, 232, 238),
			Enum.Material.SmoothPlastic
		)
		WorldKit.part(
			eventGrounds,
			"RinkBorderShort",
			Vector3.new(0.45, 0.7, 12.8),
			CFrame.new(rinkCenter + Vector3.new(side * 4.7, 0.55, 0)),
			Color3.fromRGB(226, 232, 238),
			Enum.Material.SmoothPlastic
		)
	end
end

local function buildSpringEvent(eventGrounds: Folder)
	-- Flower arch framing the stage approach.
	local archCenter = EVENT_CENTER + Vector3.new(7, 0, 0)
	for side = -1, 1, 2 do
		WorldKit.part(
			eventGrounds,
			"ArchPost",
			Vector3.new(0.5, 6, 0.5),
			CFrame.new(archCenter + Vector3.new(0, 3, side * 4)),
			Color3.fromRGB(214, 224, 214),
			Enum.Material.SmoothPlastic
		)
	end
	WorldKit.part(
		eventGrounds,
		"ArchBeam",
		Vector3.new(0.5, 0.6, 8.6),
		CFrame.new(archCenter + Vector3.new(0, 6.2, 0)),
		Color3.fromRGB(214, 224, 214),
		Enum.Material.SmoothPlastic
	)
	for index = 1, 5 do
		local blossom = ball(
			eventGrounds,
			"ArchBlossom" .. index,
			0.7,
			archCenter + Vector3.new(0, 6.2 + (index % 2) * 0.3, -4 + (index - 1) * 2),
			TUFT_COLORS[(index - 1) % #TUFT_COLORS + 1],
			Enum.Material.SmoothPlastic
		)
		blossom.CanCollide = false
	end
	-- Seed table with a few packets.
	local tableCenter = EVENT_CENTER + Vector3.new(4, 0, 7)
	WorldKit.part(
		eventGrounds,
		"SeedTableTop",
		Vector3.new(3, 0.3, 1.6),
		CFrame.new(tableCenter + Vector3.new(0, 1.85, 0)),
		Color3.fromRGB(126, 96, 62),
		Enum.Material.WoodPlanks
	)
	for side = -1, 1, 2 do
		WorldKit.part(
			eventGrounds,
			"SeedTableLeg",
			Vector3.new(0.3, 1.7, 1.4),
			CFrame.new(tableCenter + Vector3.new(side * 1.2, 0.85, 0)),
			Color3.fromRGB(96, 70, 45),
			Enum.Material.Wood
		)
	end
	for index = 1, 3 do
		local packet = WorldKit.part(
			eventGrounds,
			"SeedPacket" .. index,
			Vector3.new(0.5, 0.62, 0.1),
			CFrame.new(tableCenter + Vector3.new(-0.9 + (index - 1) * 0.9, 2.3, 0))
				* CFrame.Angles(math.rad(-8), math.rad(index * 22), 0),
			TUFT_COLORS[index],
			Enum.Material.SmoothPlastic
		)
		packet.CanCollide = false
	end
end

local function buildSummerEvent(eventGrounds: Folder)
	-- Lemonade stand.
	local standCenter = EVENT_CENTER + Vector3.new(6, 0, -5)
	WorldKit.part(
		eventGrounds,
		"LemonadeCounter",
		Vector3.new(1.6, 1.2, 4),
		CFrame.new(standCenter + Vector3.new(0, 0.6, 0)),
		Color3.fromRGB(226, 208, 148),
		Enum.Material.WoodPlanks
	)
	for side = -1, 1, 2 do
		WorldKit.part(
			eventGrounds,
			"LemonadePost",
			Vector3.new(0.3, 4.6, 0.3),
			CFrame.new(standCenter + Vector3.new(0.55, 2.3, side * 1.85)),
			Color3.fromRGB(96, 70, 45),
			Enum.Material.Wood
		)
	end
	local awning = WorldKit.part(
		eventGrounds,
		"LemonadeAwning",
		Vector3.new(2.4, 0.2, 4.6),
		CFrame.new(standCenter + Vector3.new(0.3, 4.8, 0)) * CFrame.Angles(0, 0, math.rad(-10)),
		Color3.fromRGB(236, 196, 70),
		Enum.Material.Fabric
	)
	awning.CanCollide = false
	local pitcher = WorldKit.part(
		eventGrounds,
		"LemonadePitcher",
		Vector3.new(0.9, 0.6, 0.6),
		upright(standCenter + Vector3.new(0, 1.65, 0.9)),
		Color3.fromRGB(240, 214, 96),
		Enum.Material.Glass,
		Enum.PartType.Cylinder
	)
	pitcher.Transparency = 0.2
	pitcher.CanCollide = false

	-- Ring-toss corner: tan mat, three posts, three loose rings.
	local tossCenter = EVENT_CENTER + Vector3.new(5, 0, 6.5)
	local mat = WorldKit.part(
		eventGrounds,
		"RingTossMat",
		Vector3.new(7, 0.18, 5.5),
		CFrame.new(tossCenter + Vector3.new(0, 0.1, 0)),
		Color3.fromRGB(198, 174, 130),
		Enum.Material.Fabric
	)
	mat.CanCollide = false
	local postSpots: { Vector3 } = {
		tossCenter + Vector3.new(-2, 0, -1.4),
		tossCenter + Vector3.new(0.4, 0, 0.6),
		tossCenter + Vector3.new(2.2, 0, -0.8),
	}
	for index, spot in postSpots do
		WorldKit.part(
			eventGrounds,
			"RingTossPost" .. index,
			Vector3.new(0.3, 2.2, 0.3),
			CFrame.new(spot + Vector3.new(0, 1.1, 0)),
			Color3.fromRGB(110, 84, 52),
			Enum.Material.Wood
		)
		local ring = disc(
			eventGrounds,
			"TossRing" .. index,
			1.1,
			0.2,
			spot + Vector3.new(0.9, 0.32, 1.1),
			TUFT_COLORS[index],
			Enum.Material.SmoothPlastic
		)
		ring.CanCollide = false
	end
end

-- ---------------------------------------------------------------------------
-- Public contract

function SeasonalDressing.Build(dayCamp: Instance)
	-- Idempotent: tear down any previous dressing before rebuilding.
	local previousSeasonal = dayCamp:FindFirstChild(SEASONAL_FOLDER_NAME)
	if previousSeasonal ~= nil then
		previousSeasonal:Destroy()
	end
	local previousEvent = dayCamp:FindFirstChild(EVENT_GROUNDS_FOLDER_NAME)
	if previousEvent ~= nil then
		previousEvent:Destroy()
	end

	local clock = os.date("*t") :: any
	local month = tonumber(clock.month) or 1
	local season = resolveSeason(month)

	local seasonal = Instance.new("Folder")
	seasonal.Name = SEASONAL_FOLDER_NAME
	seasonal.Parent = dayCamp
	local eventGrounds = Instance.new("Folder")
	eventGrounds.Name = EVENT_GROUNDS_FOLDER_NAME
	eventGrounds.Parent = dayCamp

	if season == "autumn" then
		buildAutumnSeasonal(seasonal)
	elseif season == "winter" then
		buildWinterSeasonal(seasonal, dayCamp)
	elseif season == "spring" then
		buildSpringSeasonal(seasonal, dayCamp)
	else
		buildSummerSeasonal(seasonal)
	end

	buildStageAndBanners(eventGrounds, season)
	if season == "autumn" then
		buildAutumnEvent(eventGrounds)
	elseif season == "winter" then
		buildWinterEvent(eventGrounds)
	elseif season == "spring" then
		buildSpringEvent(eventGrounds)
	else
		buildSummerEvent(eventGrounds)
	end
end

return SeasonalDressing
