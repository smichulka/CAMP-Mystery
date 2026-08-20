--!strict

-- BACKCOUNTRY: content pack for the doubled world's outer band and the
-- tripled lake's far shore.
--   * Dirt trails through the gaps in the original hill ring (north pass,
--     west ridge pass, south meadow, creekside) leading into the new band
--   * Three backcountry campsites (canvas tent, cold fire ring, log seat,
--     lantern post) plus a stargazer slab in the south meadow
--   * Aurora island east beach (sand spits + beached skiff) — the tripled
--     lake wraps the ruins, so the island earns a landing
--   * Ridgeline overlook on the far shore looking back across the water,
--     reached the long way around the lake's north corridor
--   * Meadow scatter: extra pines, boulders, stumps and ferns so the outer
--     band reads as wilderness instead of empty slab
-- Pure content builder like CampExpansion: everything parents under dayCamp,
-- no gameplay wiring beyond cosmetic prompts and night-lit lanterns.
--
-- Integration: registered in ProductionMapService's EXPANSION_MODULE_NAMES
-- after Landmarks (the Aurora bank must exist before the island beach sand).

local Workspace = game:GetService("Workspace")

local WorldKit = require(script.Parent:WaitForChild("WorldKit"))

local Backcountry = {}

-- Natural palette (matches ProductionMapService / LakeAndWilds tones)
local PINE_TRUNK = Color3.fromRGB(67, 50, 36)
local PINE_GREEN_A = Color3.fromRGB(43, 85, 57)
local PINE_GREEN_B = Color3.fromRGB(50, 94, 61)
local PLANK = Color3.fromRGB(96, 70, 46)
local PLANK_DARK = Color3.fromRGB(72, 52, 34)
local CANVAS = Color3.fromRGB(202, 188, 158)
local STONE = Color3.fromRGB(105, 102, 96)
local SLATE_GREY = Color3.fromRGB(82, 88, 78)
local DIRT = Color3.fromRGB(117, 91, 64)
local CHAR_BLACK = Color3.fromRGB(38, 34, 30)
local FERN_GREEN = Color3.fromRGB(84, 122, 66)

-- Dome layout + analytic height come from TerrainDomes — the single
-- source of truth (the hand-copied mirror this file used to carry
-- drifted). The raycast-first groundHeight below is unchanged.
local TerrainDomes = require(script.Parent:WaitForChild("TerrainDomes"))

local function analyticGroundHeight(x: number, z: number): number
	return TerrainDomes.heightAt(x, z)
end

-- Seats content on the RENDERED terrain surface. The analytic dome model
-- above underestimates the voxelized surface by ~2 studs (the slab's nominal
-- top is y 0.5 but renders at ~2.5 — measured in-boot 2026-08-09; every
-- ground-level Backcountry prop had shipped ~1.9 studs under the grass), so
-- a terrain raycast is authoritative. Build order guarantees the terrain
-- exists (Build runs after buildCampTerrain). The analytic model remains as
-- the fallback for points past the terrain edge, and for rays that hit
-- water — content never seats on the creek surface.
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
		"BackcountryPineTrunk",
		height,
		2.0,
		Vector3.new(x, base + height / 2, z),
		PINE_TRUNK,
		Enum.Material.Wood
	)
	for tier = 1, 3 do
		local ball = WorldKit.part(
			parent,
			"BackcountryPineCanopy",
			Vector3.new(9 - tier * 2, 5 - tier * 0.8, 9 - tier * 2),
			CFrame.new(x, base + height - 4 + tier * 2.4, z),
			canopyColor,
			Enum.Material.Grass,
			Enum.PartType.Ball
		)
		ball.CanCollide = false
	end
end

-- Dirt trail: a run of low ground-material strips between waypoints, laid on
-- whatever slope groundHeight reports (the DeerTrail pattern, but longer).
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

-- One backcountry campsite: A-frame canvas tent, cold stone fire ring with a
-- half-burnt log, log seat, firewood stack, and a night-lit lantern post.
local function buildCampsite(parent: Instance, name: string, cx: number, cz: number, yaw: number)
	local site = WorldKit.model(parent, name)
	local ground = groundHeight(cx, cz)
	local base = CFrame.new(cx, ground, cz) * CFrame.Angles(0, math.rad(yaw), 0)

	-- Tent: two leaned canvas slabs over a groundsheet, open end facing the fire
	WorldKit.part(site, "TentGroundsheet", Vector3.new(5.2, 0.15, 6.4),
		base * CFrame.new(0, 0.1, 0), Color3.fromRGB(94, 84, 66), Enum.Material.Fabric)
	for side = -1, 1, 2 do
		WorldKit.part(site, "TentPanel", Vector3.new(4.4, 0.25, 6.6),
			base * CFrame.new(side * 1.55, 2.0, 0)
				* CFrame.Angles(0, 0, side * math.rad(-52)),
			CANVAS, Enum.Material.Fabric)
	end
	WorldKit.part(site, "TentRidge", Vector3.new(0.22, 0.22, 6.8),
		base * CFrame.new(0, 3.4, 0), PLANK_DARK, Enum.Material.Wood)
	for endZ = -1, 1, 2 do
		WorldKit.part(site, "TentPole", Vector3.new(0.22, 3.4, 0.22),
			base * CFrame.new(0, 1.7, endZ * 3.2), PLANK_DARK, Enum.Material.Wood)
	end

	-- Cold fire ring 6 studs out from the tent mouth
	local fireCenter = base * CFrame.new(0, 0, 6.2)
	for stoneIndex = 1, 6 do
		local stoneAngle = stoneIndex / 6 * math.pi * 2
		WorldKit.part(site, "FireRingStone" .. stoneIndex, Vector3.new(0.9, 0.7, 0.9),
			fireCenter * CFrame.new(math.cos(stoneAngle) * 1.7, 0.35, math.sin(stoneAngle) * 1.7)
				* CFrame.Angles(0, stoneAngle, 0.08),
			STONE, Enum.Material.Slate)
	end
	local ash = WorldKit.part(site, "FireAshBed", Vector3.new(0.18, 2.6, 2.6),
		fireCenter * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)),
		CHAR_BLACK, Enum.Material.Slate, Enum.PartType.Cylinder)
	ash.CanCollide = false
	WorldKit.part(site, "HalfBurntLog", Vector3.new(0.7, 0.7, 2.4),
		fireCenter * CFrame.new(0.4, 0.5, -0.3) * CFrame.Angles(0, math.rad(28), 0),
		CHAR_BLACK, Enum.Material.Wood)

	-- Log seat facing the fire, firewood stack beside the tent (cylinder axis
	-- runs along X, so the length rides size.X)
	WorldKit.part(site, "LogSeat", Vector3.new(4.6, 1.1, 1.1),
		fireCenter * CFrame.new(0, 0.55, 3.4),
		PLANK_DARK, Enum.Material.Wood, Enum.PartType.Cylinder)
	for stick = 1, 3 do
		WorldKit.part(site, "Firewood" .. stick, Vector3.new(2.2, 0.55, 0.55),
			base * CFrame.new(2.9, 0.3 + (stick - 1) * 0.45, -2.4 + stick * 0.2)
				* CFrame.Angles(0, math.rad(stick * 9), 0),
			PLANK, Enum.Material.Wood, Enum.PartType.Cylinder)
	end

	-- Lantern post (CampLamp: lights at night with the rest of the camp)
	WorldKit.part(site, "LanternPost", Vector3.new(0.35, 4.4, 0.35),
		base * CFrame.new(-2.8, 2.2, 3.4), PLANK_DARK, Enum.Material.Wood)
	local lanternHead = WorldKit.part(site, "LanternHead", Vector3.new(0.7, 0.7, 0.7),
		base * CFrame.new(-2.8, 4.6, 3.4), Color3.fromRGB(255, 211, 132),
		Enum.Material.Neon, Enum.PartType.Ball)
	lanternHead.CanCollide = false
	WorldKit.lamp(lanternHead, { brightness = 1.1, range = 16 })
end

-- South meadow stargazer slab: flat granite, a wool blanket and a tin cup.
local function buildStargazerSlab(parent: Instance)
	local slabSite = WorldKit.model(parent, "StargazerSlab")
	local x, z = -38, -115
	local ground = groundHeight(x, z)
	WorldKit.part(slabSite, "GraniteSlab", Vector3.new(6.4, 1.1, 5.2),
		CFrame.new(x, ground + 0.4, z) * CFrame.Angles(math.rad(2), math.rad(24), math.rad(-2)),
		SLATE_GREY, Enum.Material.Slate)
	local blanket = WorldKit.part(slabSite, "WoolBlanket", Vector3.new(2.6, 0.12, 2.0),
		CFrame.new(x + 0.7, ground + 1.02, z - 0.5) * CFrame.Angles(0, math.rad(38), 0),
		Color3.fromRGB(140, 84, 72), Enum.Material.Fabric)
	blanket.CanCollide = false
	local cup = WorldKit.part(slabSite, "TinCup", Vector3.new(0.4, 0.35, 0.35),
		CFrame.new(x - 1.2, ground + 1.15, z + 1.1) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(168, 168, 174), Enum.Material.Metal, Enum.PartType.Cylinder)
	cup.CanCollide = false
end

-- Aurora island east landing: sand spits into the new east channel plus a
-- beached skiff and a mooring stake. Runs after Landmarks so the bank exists.
local function buildAuroraLanding(parent: Instance)
	local landing = WorldKit.model(parent, "AuroraLanding")
	Workspace.Terrain:FillCylinder(CFrame.new(195, -3.2, 18), 8.5, 6, Enum.Material.Sand)
	Workspace.Terrain:FillCylinder(CFrame.new(193, -3.2, 38), 8.5, 6, Enum.Material.Sand)
	Workspace.Terrain:FillCylinder(CFrame.new(192, -3.2, -2), 8.5, 6, Enum.Material.Sand)

	-- Beached at the waterline: the rendered water surface is 4.0 and the
	-- spit sand feathers just under it, so the hull rides at ~4.2 instead of
	-- the nominal ~1 (it shipped mostly submerged — audited 2026-08-10).
	local skiffFrame = CFrame.new(190.5, 4.2, 30) * CFrame.Angles(0, math.rad(112), math.rad(4))
	WorldKit.part(landing, "SkiffHull", Vector3.new(1.9, 0.5, 6.4),
		skiffFrame, Color3.fromRGB(104, 82, 58), Enum.Material.WoodPlanks)
	for side = -1, 1, 2 do
		WorldKit.part(landing, "SkiffGunwale", Vector3.new(0.3, 0.7, 5.6),
			skiffFrame * CFrame.new(side * 0.85, 0.35, 0), PLANK_DARK, Enum.Material.Wood)
	end
	WorldKit.wedge(landing, "SkiffBow", Vector3.new(1.9, 0.7, 1.1),
		skiffFrame * CFrame.new(0, 0.35, -3.7) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(104, 82, 58), Enum.Material.WoodPlanks)
	-- Stake rides the spit surface next to the beached skiff (~4.2 at the
	-- waterline — audited 2026-08-10)
	WorldKit.part(landing, "MooringStake", Vector3.new(0.3, 1.6, 0.3),
		CFrame.new(193.2, 4.5, 26.4) * CFrame.Angles(0, 0, math.rad(-10)),
		PLANK_DARK, Enum.Material.Wood)
	WorldKit.part(landing, "Driftwood", Vector3.new(0.6, 0.5, 4.4),
		CFrame.new(191.5, 0.9, 44) * CFrame.Angles(0, math.rad(64), math.rad(3)),
		Color3.fromRGB(150, 138, 116), Enum.Material.Wood)
end

-- Far-shore ridgeline overlook: raised deck, west railing over the water,
-- bench, brass spyglass, and a lit lantern for a night beacon across the lake.
local function buildOverlook(parent: Instance)
	local overlook = WorldKit.model(parent, "AuroraOverlook")
	local cx, cz = 219, 102
	local ground = groundHeight(cx, cz)
	local deckTop = ground + 1.1

	WorldKit.part(overlook, "OverlookDeck", Vector3.new(10, 0.7, 8),
		CFrame.new(cx, deckTop, cz), PLANK, Enum.Material.WoodPlanks)
	for postX = -1, 1, 2 do
		for postZ = -1, 1, 2 do
			-- Each footing seats on its OWN ground: the far-shore dome toe
			-- climbs ~6 studs across the deck's footprint (east footings bed
			-- into the slope; audited 2026-08-10).
			local fx = cx + postX * 4.2
			local fz = cz + postZ * 3.2
			WorldKit.part(overlook, "DeckFooting", Vector3.new(0.8, 1.6, 0.8),
				CFrame.new(fx, groundHeight(fx, fz) + 0.4, fz),
				STONE, Enum.Material.Slate)
		end
	end
	-- Railing on the west (lake-facing) edge
	for railZ = -1, 1 do
		WorldKit.part(overlook, "RailPost", Vector3.new(0.3, 1.4, 0.3),
			CFrame.new(cx - 4.7, deckTop + 1.0, cz + railZ * 3.6), PLANK_DARK, Enum.Material.Wood)
	end
	WorldKit.part(overlook, "RailTop", Vector3.new(0.28, 0.28, 7.8),
		CFrame.new(cx - 4.7, deckTop + 1.75, cz), PLANK_DARK, Enum.Material.Wood)
	-- Step up on the NORTH side, where the trail arrives. The old east-side
	-- step sat against the far-shore dome toe (terrain 9+ there vs the deck's
	-- 2.8 — it shipped 6.8 studs inside the slope, audited 2026-08-10).
	local stepX = cx - 1.5
	local stepZ = cz - 5.6
	WorldKit.wedge(overlook, "OverlookStep", Vector3.new(3.4, 1.4, 2.6),
		CFrame.new(stepX, groundHeight(stepX, stepZ) + 0.7, stepZ),
		PLANK, Enum.Material.WoodPlanks)
	-- Bench facing the water
	WorldKit.part(overlook, "BenchSeat", Vector3.new(1.2, 0.3, 5),
		CFrame.new(cx + 2.6, deckTop + 1.1, cz), PLANK, Enum.Material.WoodPlanks)
	for legZ = -1, 1, 2 do
		WorldKit.part(overlook, "BenchLeg", Vector3.new(1.0, 0.8, 0.4),
			CFrame.new(cx + 2.6, deckTop + 0.6, cz + legZ * 2.1), PLANK_DARK, Enum.Material.Wood)
	end
	-- Brass spyglass on a swivel post, aimed back at the firewatch island
	WorldKit.part(overlook, "SpyglassPost", Vector3.new(0.35, 3.4, 0.35),
		CFrame.new(cx - 3.4, deckTop + 2.0, cz - 2.4), PLANK_DARK, Enum.Material.Wood)
	local spyglass = WorldKit.part(overlook, "Spyglass", Vector3.new(1.9, 0.45, 0.45),
		CFrame.lookAt(
			Vector3.new(cx - 3.4, deckTop + 3.9, cz - 2.4),
			Vector3.new(104, 8, 55)
		) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(172, 138, 74), Enum.Material.Metal, Enum.PartType.Cylinder)
	spyglass.CanCollide = false
	WorldKit.prompt(spyglass, "Peer Across the Lake", "Spyglass", 0.3)
	-- Lantern beacon
	WorldKit.part(overlook, "OverlookLanternPost", Vector3.new(0.4, 4.6, 0.4),
		CFrame.new(cx + 4.2, deckTop + 2.6, cz - 3.2), PLANK_DARK, Enum.Material.Wood)
	local beacon = WorldKit.part(overlook, "OverlookLantern", Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(cx + 4.2, deckTop + 5.2, cz - 3.2), Color3.fromRGB(255, 211, 132),
		Enum.Material.Neon, Enum.PartType.Ball)
	beacon.CanCollide = false
	WorldKit.lamp(beacon, { brightness = 1.3, range = 22 })

	-- North shore of the water-sports basin (its old spot at (150, 150) is
	-- open water since the basin expansion)
	WorldKit.signpost(parent, Vector3.new(184, groundHeight(184, 196), 196),
		{ "AURORA OVERLOOK", "THE LONG WAY" })
end

-- Meadow scatter across the outer band: pines, boulders, stumps and ferns on
-- a golden-angle spiral, skipping the east sector (that's the lake now) and
-- the creek's south run.
local function buildScatter(parent: Instance)
	local scatter = WorldKit.model(parent, "BackcountryScatter")
	-- Two golden-angle bands: the original ring hugging the interior
	-- foothills, and a wider band (third expansion) filling the new meadow
	-- out toward the moved boundary.
	local function scatterAt(index: number, radius: number)
		local angle = index * 2.39996
		local x = math.cos(angle) * radius
		local z = 12 + math.sin(angle) * radius
		-- z bound covers the water-sports basin's north lobe (water to z 190,
		-- carve to 193)
		local inLakeSector = x > 78 and z < 210
		local inCreekRun = x > 74 and z < -55
		local inCreekNorthRun = x > 60 and x < 150 and z > 160
		-- With the south boundary domes gone, scatter there would stand on the
		-- night town's main road instead of hiding inside a hill.
		local onTownRoad = z < -95 and x > -36 and x < 36
		if inLakeSector or inCreekRun or inCreekNorthRun or onTownRoad then
			return
		end
		local kind = index % 5
		local ground = groundHeight(x, z)
		if kind == 0 then
			WorldKit.part(scatter, "BandBoulder", Vector3.new(2.6 + index % 3, 1.8 + index % 2, 2.4 + (index + 1) % 3),
				CFrame.new(x, ground + 0.7, z) * CFrame.Angles(index * 0.31, angle, index * 0.13),
				SLATE_GREY, Enum.Material.Slate)
		elseif kind == 1 or kind == 3 then
			createPine(scatter, x, z, 14 + (index % 4) * 2.5,
				if index % 2 == 0 then PINE_GREEN_A else PINE_GREEN_B)
		elseif kind == 2 then
			-- Fern cluster: three splayed fronds
			for frond = 1, 3 do
				local fern = WorldKit.part(scatter, "Fern", Vector3.new(0.16, 1.7, 0.9),
					CFrame.new(x + math.cos(frond * 2.1) * 0.5, ground + 0.75, z + math.sin(frond * 2.1) * 0.5)
						* CFrame.Angles(math.rad(24), frond * 2.1, 0),
					FERN_GREEN, Enum.Material.Grass)
				fern.CanCollide = false
			end
		else
			WorldKit.part(scatter, "Stump", Vector3.new(1.1, 1.6, 1.6),
				CFrame.new(x, ground + 0.5, z) * CFrame.Angles(0, angle, math.rad(90)),
				PINE_TRUNK, Enum.Material.Wood, Enum.PartType.Cylinder)
		end
	end
	for index = 1, 40 do
		scatterAt(index, 118 + (index % 7) * 4.3)
	end
	for index = 41, 84 do
		scatterAt(index, 168 + (index % 9) * 7.5)
	end
	-- Far-shore pine row along the ridge toe so the lake has a treed horizon
	for index = 1, 10 do
		local x = 226 + (index % 3) * 4
		local z = -105 + index * 26
		createPine(scatter, x, z, 16 + (index % 4) * 2.5,
			if index % 2 == 0 then PINE_GREEN_B else PINE_GREEN_A)
	end
end

function Backcountry.Build(dayCamp: Instance, _nightTown: Instance)
	local pack = WorldKit.model(dayCamp, "Backcountry")

	-- Trails out of the camp bowl through the original ring's gaps.
	-- Waypoints thread the passes between dome footprints (checked against
	-- the terrain layout; groundHeight seats every strip on the slopes).
	laidTrail(pack, "NorthPassTrail", {
		Vector2.new(-38, 92), Vector2.new(-44, 104),
		Vector2.new(-50, 116), Vector2.new(-56, 124),
	})
	laidTrail(pack, "WestRidgeTrail", {
		Vector2.new(-88, 20), Vector2.new(-97, 28), Vector2.new(-104, 36),
		Vector2.new(-112, 48), Vector2.new(-118, 62), Vector2.new(-120, 78),
	})
	-- Stops short of z -110: TownApproachDayWall stands there by day, and the
	-- town's fence line takes over at night.
	laidTrail(pack, "SouthMeadowTrail", {
		Vector2.new(0, -86), Vector2.new(1, -96), Vector2.new(-4, -103),
		Vector2.new(-14, -106), Vector2.new(-26, -107),
	})
	laidTrail(pack, "CreeksideTrail", {
		Vector2.new(12, -84), Vector2.new(26, -93),
		Vector2.new(42, -96), Vector2.new(56, -99),
	})
	-- Rerouted 2026-08-09: the water-sports basin flooded the old straight
	-- line (its start at (150,150) is open water now). The long way runs
	-- north of the basin's lobe, then south down the dry strip under the
	-- far-shore ridge (water ends at x 208, carve at 211).
	-- Bowed further north 2026-08-10: the straighter line dipped three strips
	-- into the basin's north-lobe water margin (carve reaches z 193 at
	-- x <= 211); the trail now stays z >= 196 until it clears x 211.
	laidTrail(pack, "OverlookTrail", {
		Vector2.new(148, 212), Vector2.new(178, 202), Vector2.new(198, 198),
		Vector2.new(212, 196), Vector2.new(214, 184),
		Vector2.new(215, 150), Vector2.new(216, 122), Vector2.new(216, 106),
	})

	WorldKit.signpost(pack, Vector3.new(-38, groundHeight(-38, 92), 92),
		{ "NORTH PASS", "BACKCOUNTRY" })
	WorldKit.signpost(pack, Vector3.new(-88, groundHeight(-88, 20), 20),
		{ "WEST RIDGE", "BACKCOUNTRY" })
	WorldKit.signpost(pack, Vector3.new(6, groundHeight(6, -78), -78),
		{ "SOUTH MEADOW", "CREEKSIDE CAMP" })

	-- Footbridge over the creek's north run (third expansion): without it the
	-- meadow north of the lake is cut off by water — pathfinding read the
	-- whole northeast band as NoPath. Deck top 4.4 clears the rendered water
	-- (bay rule: surfaces render up to ~4.0); one 0.95 step at each end.
	local bridge = WorldKit.model(pack, "NorthCreekBridge")
	-- Deck 5.6 wide with rails at ±2.6: the walk corridor between the
	-- rails must exceed the 4-stud agent diameter or the whole bridge
	-- drops out of the navigation mesh (measured: 3.4-wide corridor = NoPath).
	WorldKit.part(bridge, "BridgeDeck", Vector3.new(46, 0.4, 5.6),
		CFrame.new(119, 4.2, 216), PLANK, Enum.Material.WoodPlanks)
	for railSide = -1, 1, 2 do
		WorldKit.part(bridge, "BridgeRail", Vector3.new(46, 0.25, 0.2),
			CFrame.new(119, 5.6, 216 + railSide * 2.6), PLANK_DARK, Enum.Material.Wood)
		for _, postX in { 98, 119, 140 } do
			WorldKit.part(bridge, "BridgePost", Vector3.new(0.4, 4.4, 0.4),
				CFrame.new(postX, 3.4, 216 + railSide * 2.6), PLANK_DARK, Enum.Material.Wood)
		end
	end
	-- End ramps as pitched planks that OVERLAP under the deck edge. Two
	-- navmesh lessons cost a boot each: ~1-stud step rises read as
	-- jump-only links, and a wedge whose zero-width apex merely touches the
	-- deck edge leaves a hairline seam the mesh also treats as a jump. An
	-- angled slab buried into the ground at the foot and sliced by the deck
	-- edge at the top gives one continuous walk surface.
	WorldKit.part(bridge, "BridgeRampW", Vector3.new(8, 0.4, 5.2),
		CFrame.new(92.6, 3.4, 216) * CFrame.Angles(0, 0, math.rad(16)),
		PLANK_DARK, Enum.Material.WoodPlanks)
	WorldKit.part(bridge, "BridgeRampE", Vector3.new(8, 0.4, 5.2),
		CFrame.new(145.4, 3.4, 216) * CFrame.Angles(0, 0, math.rad(-16)),
		PLANK_DARK, Enum.Material.WoodPlanks)

	buildCampsite(pack, "WestRidgeCamp", -120, 85, 140)
	buildCampsite(pack, "NorthPassCamp", -58, 126, -35)
	buildCampsite(pack, "CreeksideCamp", 65, -100, 78)
	buildStargazerSlab(pack)
	buildAuroraLanding(pack)
	buildOverlook(pack)
	buildScatter(pack)
end

return Backcountry
