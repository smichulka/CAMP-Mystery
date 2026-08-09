--!strict

-- LANDMARKS pack: ten lore/POI structures layered over the production map.
--   1. The Mines (east hillside, under the lake bluff)
--   2. Ranger Station (southwest hill stilt platform)
--   3. Crashed Ranger Truck (camp-town transition)
--   4. Camp Chapel + bell tower
--   5. Storm Cellar Network (3 cellars, crawl-tunnel teleport ring)
--   6. Fire Lookout Tower (north hill, tallest structure)
--   7. Cabin Zero (burned cabin memorial)
--   8. Church Crypt (beneath the abandoned church)
--   9. Radio Tower Hill (southeast town corner, blinking beacon)
--  10. Camp Aurora Ruins (across the lake)
--
-- Integration: Landmarks.Build(dayCamp, nightTown) once, after the production
-- map folders exist. Evidence socket markers (WorldKit.evidenceSocketMarker)
-- are tagged EvidenceSocketExtra and await registration by the integrator.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local WorldKit = require(script.Parent:WaitForChild("WorldKit"))

local Landmarks = {}

-- Palette
local CHAR_BLACK = Color3.fromRGB(30, 28, 26)
local ASH_GREY = Color3.fromRGB(56, 54, 52)
local STONE_COLD = Color3.fromRGB(98, 102, 106)
local STONE_DARK = Color3.fromRGB(66, 70, 74)
local ROCK_BROWN = Color3.fromRGB(62, 56, 50)
local WOOD_WEATHER = Color3.fromRGB(104, 88, 62)
local WOOD_DARK = Color3.fromRGB(74, 56, 38)
local TIMBER = Color3.fromRGB(86, 64, 42)
local DIRT_BROWN = Color3.fromRGB(88, 68, 48)
local MOSS_GREEN = Color3.fromRGB(74, 108, 66)
local METAL_GREY = Color3.fromRGB(96, 100, 104)

local function announce(kind: string, title: string, message: string, duration: number)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		return
	end
	local announcementRemote = remotes:FindFirstChild("Announcement")
	if announcementRemote and announcementRemote:IsA("RemoteEvent") then
		-- Mirrors the payload shape Bootstrap.server.lua fires for onAnnouncement
		announcementRemote:FireAllClients({
			kind = kind,
			title = title,
			message = message,
			duration = duration,
		})
	end
end

local function surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(400, 220)
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.SpecialElite
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui
end

-- Shared blink/flicker driver. `apply` may return the next wait time; the loop
-- exits once the driven part leaves the tree.
local function toggleLoop(part: BasePart, interval: number, apply: (boolean) -> number?)
	task.spawn(function()
		local on = false
		while part.Parent ~= nil do
			on = not on
			local nextWait = apply(on)
			task.wait(nextWait or interval)
		end
	end)
end

-- 1. THE MINES ---------------------------------------------------------------
local function buildMines(dayCamp: Instance)
	local terrain = Workspace.Terrain
	-- Open the slope face at the portal, then hollow the shaft + chambers.
	-- Interiors are sealed with rock parts; the carves just keep voxels (and
	-- the lake water band that clips this hillside) out of the rooms.
	terrain:FillBlock(CFrame.new(83.5, 3.2, -30), Vector3.new(9, 7.4, 10), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(94, 3.1, -30), Vector3.new(22, 7.4, 9.6), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(106, 3.2, -30), Vector3.new(13, 8, 13), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(105, 3.2, -44), Vector3.new(13, 8, 17), Enum.Material.Air)

	local mines = WorldKit.model(dayCamp, "TheMines")

	-- Boarded timber portal, facing west
	WorldKit.part(mines, "PortalPostN", Vector3.new(1, 8, 1),
		CFrame.new(85, 3.9, -34.6), TIMBER, Enum.Material.Wood)
	WorldKit.part(mines, "PortalPostS", Vector3.new(1, 8, 1),
		CFrame.new(85, 3.9, -25.4), TIMBER, Enum.Material.Wood)
	WorldKit.part(mines, "PortalLintel", Vector3.new(1, 1.2, 10.6),
		CFrame.new(85, 8.1, -30), TIMBER, Enum.Material.Wood)
	for boardIndex, boardZ in { -33.2, -31.4, -29.6 } do
		WorldKit.part(mines, "PortalBoard" .. boardIndex, Vector3.new(0.4, 6.6, 1.6),
			CFrame.new(84.8, 3.6, boardZ) * CFrame.Angles(0.04 * boardIndex, 0, 0),
			WOOD_DARK, Enum.Material.WoodPlanks)
	end
	-- Crouch gap: only a stub board hangs over the pried-open south side
	WorldKit.part(mines, "PortalBoardStub", Vector3.new(0.4, 1.4, 2.6),
		CFrame.new(84.8, 6.5, -27.3), WOOD_DARK, Enum.Material.WoodPlanks)
	for priedIndex = 1, 2 do
		local pried = WorldKit.part(mines, "PriedBoard" .. priedIndex, Vector3.new(0.4, 6.2, 1.5),
			CFrame.new(82 - priedIndex, 0.9, -26 + priedIndex * 1.6)
				* CFrame.Angles(math.rad(84), math.rad(30 * priedIndex), 0),
			WOOD_DARK, Enum.Material.WoodPlanks)
		pried.CanCollide = false
	end

	-- Entry tunnel (8-wide interior, dark rock shell)
	WorldKit.part(mines, "ShaftFloor", Vector3.new(22, 1.5, 9.6),
		CFrame.new(95, -0.4, -30), ROCK_BROWN, Enum.Material.Slate)
	WorldKit.part(mines, "ShaftWallN", Vector3.new(22, 6.6, 1),
		CFrame.new(95, 3.6, -34.8), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mines, "ShaftWallS", Vector3.new(22, 6.6, 1),
		CFrame.new(95, 3.6, -25.2), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mines, "ShaftCeiling", Vector3.new(22, 1, 11),
		CFrame.new(95, 6.55, -30), STONE_DARK, Enum.Material.Slate)

	-- Chamber A (first room)
	WorldKit.part(mines, "ChamberAFloor", Vector3.new(14, 1.5, 14),
		CFrame.new(106, -0.4, -30), ROCK_BROWN, Enum.Material.Slate)
	WorldKit.part(mines, "ChamberAWallN", Vector3.new(14, 6.6, 1),
		CFrame.new(106, 3.6, -23.6), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mines, "ChamberAWallE", Vector3.new(1, 6.6, 14),
		CFrame.new(112.7, 3.6, -30), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mines, "ChamberAWallSW", Vector3.new(3.8, 6.6, 1),
		CFrame.new(101.1, 3.6, -36.3), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mines, "ChamberAWallSE", Vector3.new(3.8, 6.6, 1),
		CFrame.new(110.9, 3.6, -36.3), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mines, "ChamberACornerNW", Vector3.new(1, 6.6, 3),
		CFrame.new(99.6, 3.6, -24.8), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mines, "ChamberACornerSW", Vector3.new(1, 6.6, 2),
		CFrame.new(99.6, 3.6, -35.5), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mines, "ChamberACeiling", Vector3.new(14.5, 1, 14.5),
		CFrame.new(106, 6.9, -30), STONE_DARK, Enum.Material.Slate)

	-- Chamber B (far room) plus the connecting passage
	WorldKit.part(mines, "ChamberBFloor", Vector3.new(14, 1.5, 17),
		CFrame.new(105, -0.4, -44.5), ROCK_BROWN, Enum.Material.Slate)
	WorldKit.part(mines, "ChamberBWallW", Vector3.new(1, 6.6, 17),
		CFrame.new(98.2, 3.6, -44.5), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mines, "ChamberBWallE", Vector3.new(1, 6.6, 17),
		CFrame.new(111.8, 3.6, -44.5), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mines, "ChamberBWallS", Vector3.new(14, 6.6, 1),
		CFrame.new(105, 3.6, -53.2), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mines, "PassageWallW", Vector3.new(1, 6.6, 4.4),
		CFrame.new(102.6, 3.6, -38.2), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mines, "PassageWallE", Vector3.new(1, 6.6, 4.4),
		CFrame.new(109.4, 3.6, -38.2), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mines, "ChamberBCeiling", Vector3.new(14.5, 1, 17.5),
		CFrame.new(105, 6.9, -44.5), STONE_DARK, Enum.Material.Slate)

	-- Cart tracks: thin rails + sleepers, entry run then chamber B spur
	for railSide = -1, 1, 2 do
		WorldKit.part(mines, "EntryRail", Vector3.new(18, 0.25, 0.4),
			CFrame.new(95, 0.5, -30 + railSide * 1.1), METAL_GREY, Enum.Material.Metal)
		WorldKit.part(mines, "SpurRail", Vector3.new(0.4, 0.25, 12),
			CFrame.new(106 + railSide * 1.1, 0.5, -44), METAL_GREY, Enum.Material.Metal)
	end
	for sleeperIndex = 0, 4 do
		WorldKit.part(mines, "EntrySleeper" .. sleeperIndex, Vector3.new(0.35, 0.2, 3.2),
			CFrame.new(87 + sleeperIndex * 4, 0.45, -30), WOOD_DARK, Enum.Material.Wood)
	end
	for sleeperIndex = 0, 3 do
		WorldKit.part(mines, "SpurSleeper" .. sleeperIndex, Vector3.new(3.2, 0.2, 0.35),
			CFrame.new(106, 0.45, -39 - sleeperIndex * 3.6), WOOD_DARK, Enum.Material.Wood)
	end

	-- Ore carts: one upright in chamber A, one tipped hiding spot in chamber B
	local function oreCart(name: string, base: CFrame): Part
		local cartBase = WorldKit.part(mines, name .. "Base", Vector3.new(3, 1, 4.5),
			base, METAL_GREY, Enum.Material.CorrodedMetal)
		for side = -1, 1, 2 do
			WorldKit.part(mines, name .. "Side", Vector3.new(0.3, 1.7, 4.5),
				base * CFrame.new(side * 1.35, 0.9, 0), METAL_GREY, Enum.Material.CorrodedMetal)
			WorldKit.part(mines, name .. "End", Vector3.new(2.4, 1.7, 0.3),
				base * CFrame.new(0, 0.9, side * 2.1), METAL_GREY, Enum.Material.CorrodedMetal)
		end
		return cartBase
	end
	oreCart("CartUpright", CFrame.new(108.5, 1.1, -27))
	local tippedBase = oreCart("CartTipped",
		CFrame.new(104, 1.3, -48.5) * CFrame.Angles(0, 0.5, math.rad(102)))
	WorldKit.hidingSpot(tippedBase)

	-- Timber supports every 6 studs along the entry shaft
	for _, frameX in { 88, 94, 100 } do
		for frameSide = -1, 1, 2 do
			WorldKit.part(mines, "SupportPost", Vector3.new(0.7, 5.9, 0.7),
				CFrame.new(frameX, 3.3, -30 + frameSide * 4), TIMBER, Enum.Material.Wood)
		end
		WorldKit.part(mines, "SupportLintel", Vector3.new(0.7, 0.7, 9.2),
			CFrame.new(frameX, 5.9, -30), TIMBER, Enum.Material.Wood)
	end

	-- Dangling cage lantern in chamber A (lit at night, never generator-gated)
	local lanternChain = WorldKit.part(mines, "LanternChain", Vector3.new(0.15, 1.4, 0.15),
		CFrame.new(106, 5.9, -30), ASH_GREY, Enum.Material.Metal)
	lanternChain.CanCollide = false
	local lanternCage = WorldKit.part(mines, "LanternCage", Vector3.new(0.9, 1.1, 0.9),
		CFrame.new(106, 4.9, -30), ASH_GREY, Enum.Material.Metal)
	lanternCage.CanCollide = false
	local lanternCore = WorldKit.part(mines, "LanternCore", Vector3.new(0.45, 0.5, 0.45),
		CFrame.new(106, 4.9, -30), Color3.fromRGB(255, 205, 130), Enum.Material.Neon)
	lanternCore.CanCollide = false
	WorldKit.lamp(lanternCore, { brightness = 1.2, range = 18 })

	-- Props: pickaxe against the wall, supply crates
	WorldKit.part(mines, "PickaxeHandle", Vector3.new(0.25, 3, 0.25),
		CFrame.new(101, 1.9, -26.5) * CFrame.Angles(0, 0, math.rad(16)),
		WOOD_WEATHER, Enum.Material.Wood)
	WorldKit.part(mines, "PickaxeHead", Vector3.new(1.7, 0.3, 0.3),
		CFrame.new(100.6, 3.3, -26.5), METAL_GREY, Enum.Material.Metal)
	WorldKit.part(mines, "MineCrateA", Vector3.new(2.2, 2.2, 2.2),
		CFrame.new(110.4, 1.6, -33.5), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(mines, "MineCrateB", Vector3.new(1.8, 1.8, 1.8),
		CFrame.new(100.4, 1.4, -51), WOOD_WEATHER, Enum.Material.WoodPlanks)

	WorldKit.evidenceSocketMarker(mines, "mines-ore-cart", Vector3.new(104, 2, -48))
end

-- 2. RANGER STATION ----------------------------------------------------------
local function buildRangerStation(dayCamp: Instance)
	local station = WorldKit.model(dayCamp, "RangerStation")
	-- The perimeter dome here crests at ~22 studs; the deck must clear it or
	-- the cabin drowns in the hillside (it shipped buried at deckTop = 14).
	local deckTop = 26

	-- Stilt legs + braces (platform perches over the hill's west flank)
	for _, legX in { -87.5, -76.5 } do
		for _, legZ in { -66.5, -57.5 } do
			WorldKit.part(station, "StiltLeg", Vector3.new(0.9, deckTop + 1, 0.9),
				CFrame.new(legX, (deckTop - 1) / 2, legZ), TIMBER, Enum.Material.Wood)
		end
	end
	for _, braceY in { 7, 17 } do
		WorldKit.part(station, "StiltBraceN", Vector3.new(11.4, 0.5, 0.5),
			CFrame.new(-82, braceY, -66.5), TIMBER, Enum.Material.Wood)
		WorldKit.part(station, "StiltBraceS", Vector3.new(11.4, 0.5, 0.5),
			CFrame.new(-82, braceY, -57.5), TIMBER, Enum.Material.Wood)
	end

	local deck = WorldKit.part(station, "Deck", Vector3.new(14, 0.8, 14),
		CFrame.new(-82, deckTop - 0.4, -62), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.creakyFloor(deck)

	-- One-room cabin (8 x 10) on the west side of the deck. Walls are 7 tall
	-- with a slim header so the doorway clears a full character (6.4 studs).
	WorldKit.part(station, "RoomWallW", Vector3.new(0.6, 7, 10),
		CFrame.new(-85.7, deckTop + 3.5, -62), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(station, "RoomWallN", Vector3.new(8, 7, 0.6),
		CFrame.new(-82, deckTop + 3.5, -66.7), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(station, "RoomWallS", Vector3.new(8, 7, 0.6),
		CFrame.new(-82, deckTop + 3.5, -57.3), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(station, "RoomWallEN", Vector3.new(0.6, 7, 3.2),
		CFrame.new(-78.3, deckTop + 3.5, -65.2), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(station, "RoomWallES", Vector3.new(0.6, 7, 3.2),
		CFrame.new(-78.3, deckTop + 3.5, -58.8), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(station, "RoomDoorHeader", Vector3.new(0.6, 0.6, 3.2),
		CFrame.new(-78.3, deckTop + 6.7, -62), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(station, "RoomRoof", Vector3.new(9.6, 0.6, 11.6),
		CFrame.new(-82, deckTop + 7.4, -62), Color3.fromRGB(88, 84, 76), Enum.Material.CorrodedMetal)

	-- Deck railing on the open east side
	WorldKit.part(station, "DeckRailE", Vector3.new(0.35, 0.35, 14),
		CFrame.new(-75.2, deckTop + 1.5, -62), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(station, "DeckRailN", Vector3.new(3.4, 0.35, 0.35),
		CFrame.new(-76.8, deckTop + 1.5, -68.8), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(station, "DeckRailS", Vector3.new(3.4, 0.35, 0.35),
		CFrame.new(-76.8, deckTop + 1.5, -55.2), WOOD_DARK, Enum.Material.Wood)

	-- Climbable truss ladder up the west face from the flat meadow ground.
	-- (The old 14-step stair run started inside the west dome and was fully
	-- buried; a ladder keeps access on the one side that stays open ground.)
	local ladder = Instance.new("TrussPart")
	ladder.Name = "StationLadder"
	ladder.Size = Vector3.new(2, 28, 2)
	ladder.CFrame = CFrame.new(-90.2, deckTop - 13, -62)
	ladder.Anchored = true
	ladder.Material = Enum.Material.Wood
	ladder.Color = TIMBER
	ladder.Parent = station

	-- CB radio desk with a blinking indicator
	WorldKit.part(station, "RadioDesk", Vector3.new(1.4, 0.35, 4.6),
		CFrame.new(-84.8, deckTop + 2.3, -62), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(station, "RadioDeskPanel", Vector3.new(1.2, 2.1, 4.4),
		CFrame.new(-84.9, deckTop + 1.1, -62), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(station, "CBRadio", Vector3.new(0.9, 1, 1.7),
		CFrame.new(-85, deckTop + 3, -62), ASH_GREY, Enum.Material.Metal)
	local indicator = WorldKit.part(station, "CBIndicator", Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(-84.5, deckTop + 3.2, -61.4), Color3.fromRGB(212, 66, 52), Enum.Material.Neon)
	indicator.CanCollide = false
	toggleLoop(indicator, 2, function(on: boolean): number?
		indicator.Color = if on
			then Color3.fromRGB(72, 214, 116)
			else Color3.fromRGB(212, 66, 52)
		return nil
	end)

	-- Trail-map wall
	local trailMap = WorldKit.part(station, "TrailMapBoard", Vector3.new(3.6, 2.6, 0.15),
		CFrame.new(-82, deckTop + 3.4, -66.3), Color3.fromRGB(214, 198, 158), Enum.Material.SmoothPlastic)
	surfaceText(trailMap, Enum.NormalId.Back,
		"HOLLOW CREEK VALLEY\n~ lodge . campfire . docks ~\nN: lookout   E: mines\nSW: this station\nDO NOT HIKE ALONE",
		Color3.fromRGB(52, 40, 28))

	-- Cot and lamp
	WorldKit.part(station, "CotFrame", Vector3.new(5, 0.6, 2),
		CFrame.new(-83, deckTop + 0.7, -58.6), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(station, "CotMattress", Vector3.new(4.6, 0.35, 1.7),
		CFrame.new(-83, deckTop + 1.15, -58.6), Color3.fromRGB(126, 122, 104), Enum.Material.Fabric)
	local stationLampCore = WorldKit.part(station, "StationLampCore", Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(-82, deckTop + 5.1, -62), Color3.fromRGB(255, 205, 130), Enum.Material.Neon)
	stationLampCore.CanCollide = false
	WorldKit.lamp(stationLampCore, { brightness = 1.3, range = 15 })

	-- Binocular stand on the open deck
	WorldKit.part(station, "BinocularPost", Vector3.new(0.4, 3.4, 0.4),
		CFrame.new(-76.6, deckTop + 1.7, -62), METAL_GREY, Enum.Material.Metal)
	local binoculars = WorldKit.part(station, "Binoculars", Vector3.new(1.2, 0.5, 0.9),
		CFrame.new(-76.6, deckTop + 3.6, -62), ASH_GREY, Enum.Material.Metal)
	local binocularPrompt = WorldKit.prompt(binoculars, "Use Binoculars", "Ranger Binoculars", 0.5)
	binocularPrompt.Triggered:Connect(function()
		announce("Info", "Ranger Station", "From here you can see the whole valley.", 4)
	end)

	WorldKit.evidenceSocketMarker(station, "ranger-station-desk",
		Vector3.new(-84.5, deckTop + 2.8, -62))
end

-- 3. CRASHED RANGER TRUCK ----------------------------------------------------
local function buildCrashedTruck(dayCamp: Instance)
	local wreck = WorldKit.model(dayCamp, "CrashedRangerTruck")
	-- Truck heading south (toward town), nose dug into a dirt scrape
	local frame = CFrame.new(-15, 0, -58) * CFrame.Angles(0, math.rad(8), 0)
	-- Positive pitch about X tips the local -Z (nose) downward
	local body = frame * CFrame.Angles(math.rad(9), 0, 0)
	local green = Color3.fromRGB(64, 92, 66)

	-- Dirt scrape + skid marks (terrain-free dressing)
	local scrapeA = WorldKit.part(wreck, "DirtScrapeA", Vector3.new(7, 0.3, 10),
		frame * CFrame.new(0, 0.42, -4), DIRT_BROWN, Enum.Material.Ground)
	scrapeA.CanCollide = false
	local scrapeB = WorldKit.part(wreck, "DirtScrapeB", Vector3.new(4.6, 0.26, 6),
		frame * CFrame.new(1.4, 0.44, -8.5) * CFrame.Angles(0, 0.3, 0),
		DIRT_BROWN, Enum.Material.Ground)
	scrapeB.CanCollide = false
	for skidSide = -1, 1, 2 do
		local skid = WorldKit.part(wreck, "SkidMark", Vector3.new(1.1, 0.12, 10),
			frame * CFrame.new(skidSide * 1.9, 0.5, 9.5), ASH_GREY, Enum.Material.Asphalt)
		skid.CanCollide = false
	end

	-- Body shell
	WorldKit.part(wreck, "TruckBed", Vector3.new(6, 1.8, 8),
		body * CFrame.new(0, 2.6, 2.5), green, Enum.Material.CorrodedMetal)
	WorldKit.part(wreck, "TruckCab", Vector3.new(5.6, 3, 4),
		body * CFrame.new(0, 3.7, -2.2), green, Enum.Material.CorrodedMetal)
	WorldKit.part(wreck, "TruckHood", Vector3.new(5.6, 1.6, 3.6),
		body * CFrame.new(0, 2.9, -6), green, Enum.Material.CorrodedMetal)
	local windshield = WorldKit.part(wreck, "TruckWindshield", Vector3.new(5, 1.8, 0.3),
		body * CFrame.new(0, 4.6, -4.2) * CFrame.Angles(math.rad(-18), 0, 0),
		Color3.fromRGB(150, 168, 172), Enum.Material.Glass)
	windshield.Transparency = 0.35
	WorldKit.part(wreck, "TruckGrille", Vector3.new(4.6, 1, 0.3),
		body * CFrame.new(0, 2.3, -7.8), METAL_GREY, Enum.Material.DiamondPlate)
	for _, wheelSpot in {
		Vector3.new(-3, 1.3, -5), Vector3.new(3, 1.3, -5),
		Vector3.new(-3, 1.3, 3.4), Vector3.new(3, 1.3, 3.4),
	} do
		WorldKit.part(wreck, "TruckWheel", Vector3.new(0.8, 2.4, 2.4),
			body * CFrame.new(wheelSpot), Color3.fromRGB(36, 36, 36),
			Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end

	-- Headlights; the surviving one flickers forever
	WorldKit.part(wreck, "HeadlightDead", Vector3.new(0.6, 0.6, 0.25),
		body * CFrame.new(-2, 2.7, -7.9), Color3.fromRGB(70, 70, 60), Enum.Material.SmoothPlastic)
	local headlight = WorldKit.part(wreck, "HeadlightFlicker", Vector3.new(0.6, 0.6, 0.25),
		body * CFrame.new(2, 2.7, -7.9), Color3.fromRGB(255, 234, 180), Enum.Material.Neon)
	local headlightBeam = Instance.new("PointLight")
	headlightBeam.Color = Color3.fromRGB(255, 234, 180)
	headlightBeam.Brightness = 1.6
	headlightBeam.Range = 18
	headlightBeam.Parent = headlight
	toggleLoop(headlight, 2, function(on: boolean): number?
		headlight.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		headlightBeam.Enabled = on
		return math.random(15, 30) / 10
	end)

	-- Driver door ajar, labeled
	local door = WorldKit.hingedDoor(wreck, "TruckDoor", Vector3.new(3.4, 2.8, 0.3),
		frame * CFrame.new(3, 3.6, -2.2) * CFrame.Angles(0, math.rad(-68), 0), green)
	surfaceText(door, Enum.NormalId.Front, "CAMP RANGER\nSERVICE", Color3.fromRGB(224, 214, 178))

	-- Scattered cargo crates
	WorldKit.part(wreck, "CargoCrateA", Vector3.new(2.2, 2.2, 2.2),
		frame * CFrame.new(-4.6, 1.6, 5.2) * CFrame.Angles(0, 0.5, 0),
		WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(wreck, "CargoCrateB", Vector3.new(1.8, 1.8, 1.8),
		frame * CFrame.new(4.8, 1.4, 6.6) * CFrame.Angles(0, 0.9, 0),
		WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(wreck, "CargoCrateC", Vector3.new(1.6, 1.6, 1.6),
		frame * CFrame.new(-3.2, 1.3, 9.8) * CFrame.Angles(0.4, 0.2, 0),
		WOOD_WEATHER, Enum.Material.WoodPlanks)
end

-- 4. CAMP CHAPEL -------------------------------------------------------------
local function buildChapel(dayCamp: Instance)
	local chapel = WorldKit.model(dayCamp, "CampChapel")
	-- Center nudged to (-30, y, 51) so the footprint stays out of the
	-- outhouse row (keep-clear x -30..-14, z 58..70).
	local cx, cz = -30, 51

	local floor = WorldKit.part(chapel, "ChapelFloor", Vector3.new(10, 0.6, 14),
		CFrame.new(cx, 0.5, cz), WOOD_DARK, Enum.Material.WoodPlanks)
	WorldKit.creakyFloor(floor)

	-- A-frame sides (roof-walls) meeting at the ridge
	for side = -1, 1, 2 do
		WorldKit.part(chapel, "AFrameSide", Vector3.new(0.5, 11.4, 14.5),
			CFrame.new(cx + side * 2.6, 5.6, cz) * CFrame.Angles(0, 0, side * math.rad(27.5)),
			WOOD_WEATHER, Enum.Material.WoodPlanks)
	end
	WorldKit.part(chapel, "RidgeBeam", Vector3.new(0.7, 0.7, 15),
		CFrame.new(cx, 10.6, cz), WOOD_DARK, Enum.Material.Wood)

	-- Back wall with a stained-glass mosaic
	WorldKit.part(chapel, "BackWall", Vector3.new(7.4, 7.4, 0.5),
		CFrame.new(cx, 4.4, cz + 6.75), WOOD_WEATHER, Enum.Material.WoodPlanks)
	local paneColors = {
		Color3.fromRGB(176, 62, 62), Color3.fromRGB(214, 172, 84),
		Color3.fromRGB(72, 138, 150), Color3.fromRGB(128, 88, 158),
	}
	for paneIndex, paneColor in paneColors do
		local px = if paneIndex % 2 == 1 then cx - 1.15 else cx + 1.15
		local py = if paneIndex <= 2 then 3.4 else 5.4
		local pane = WorldKit.part(chapel, "StainedPane" .. paneIndex, Vector3.new(1.9, 1.7, 0.25),
			CFrame.new(px, py, cz + 6.55), paneColor, Enum.Material.Glass)
		pane.Transparency = 0.25
		pane.CanCollide = false
	end

	-- Front wall with door gap
	for side = -1, 1, 2 do
		WorldKit.part(chapel, "FrontWall", Vector3.new(2, 7, 0.5),
			CFrame.new(cx + side * 2.5, 4.2, cz - 6.75), WOOD_WEATHER, Enum.Material.WoodPlanks)
	end
	WorldKit.part(chapel, "FrontHeader", Vector3.new(3.2, 1.8, 0.5),
		CFrame.new(cx, 6.8, cz - 6.75), WOOD_WEATHER, Enum.Material.WoodPlanks)

	-- Pews and altar
	for pewSide = -1, 1, 2 do
		for pewRow = 0, 1 do
			local pewZ = cz - 2.6 + pewRow * 3.2
			WorldKit.part(chapel, "PewSeat", Vector3.new(3.2, 0.45, 1),
				CFrame.new(cx + pewSide * 2.4, 1.6, pewZ), WOOD_DARK, Enum.Material.Wood)
			WorldKit.part(chapel, "PewBack", Vector3.new(3.2, 1.2, 0.25),
				CFrame.new(cx + pewSide * 2.4, 2.3, pewZ + 0.55), WOOD_DARK, Enum.Material.Wood)
		end
	end
	WorldKit.part(chapel, "AltarTable", Vector3.new(3, 1.9, 1.4),
		CFrame.new(cx, 1.8, cz + 4.8), Color3.fromRGB(120, 112, 100), Enum.Material.Wood)

	-- Bell tower over the entry
	for _, postX in { cx - 1.5, cx + 1.5 } do
		for _, postZ in { cz - 7.6, cz - 5.4 } do
			WorldKit.part(chapel, "TowerPost", Vector3.new(0.5, 12, 0.5),
				CFrame.new(postX, 6.8, postZ), TIMBER, Enum.Material.Wood)
		end
	end
	WorldKit.part(chapel, "TowerCap", Vector3.new(4.4, 0.5, 3.6),
		CFrame.new(cx, 13, cz - 6.5), Color3.fromRGB(88, 84, 76), Enum.Material.CorrodedMetal)
	local bellHinge = CFrame.new(cx, 12.4, cz - 6.5)
	local bellOffset = CFrame.new(0, -0.9, 0) * CFrame.Angles(0, 0, math.rad(90))
	local bell = WorldKit.part(chapel, "BronzeBell", Vector3.new(1.7, 1.8, 1.8),
		bellHinge * bellOffset, Color3.fromRGB(146, 110, 62), Enum.Material.Metal,
		Enum.PartType.Cylinder)
	local bellRope = WorldKit.part(chapel, "BellRope", Vector3.new(0.18, 6.6, 0.18),
		CFrame.new(cx, 7.9, cz - 6.5), Color3.fromRGB(160, 138, 96), Enum.Material.Fabric)
	bellRope.CanCollide = false

	local ringPrompt = WorldKit.prompt(bellRope, "Ring the Bell", "Chapel Bell", 0.6)
	local lastRung = 0
	local BELL_COOLDOWN = 120
	ringPrompt.Triggered:Connect(function()
		local now = os.clock()
		if now - lastRung < BELL_COOLDOWN then
			return
		end
		lastRung = now
		announce("Warning", "The camp bell tolls", "Everyone hears it. Everything hears it.", 6)
		task.spawn(function()
			for _, swing in { 30, -25, 18, -10, 0 } do
				if bell.Parent == nil then
					return
				end
				local target = bellHinge * CFrame.Angles(math.rad(swing), 0, 0) * bellOffset
				local tween = TweenService:Create(
					bell,
					TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ CFrame = target }
				)
				tween:Play()
				tween.Completed:Wait()
			end
		end)
	end)
end

-- 8. CHURCH CRYPT (built before the cellars: it owns the churchside ground
-- apron that the church-side storm cellar also stands on) --------------------
local function buildChurchCrypt(nightTown: Instance)
	local crypt = WorldKit.model(nightTown, "ChurchCrypt")

	-- Ground apron east of the church (no town ground exists past z=-445).
	-- Two rectangular holes are left open: the crypt stairwell (H2) and the
	-- church-side storm cellar pit (H1, used by buildStormCellars).
	local apronColor = Color3.fromRGB(47, 51, 48)
	local apronSpecs: { { size: Vector3, cframe: CFrame } } = {
		{ size = Vector3.new(24, 1, 9), cframe = CFrame.new(21, -0.5, -475.5) },
		{ size = Vector3.new(4.5, 1, 6), cframe = CFrame.new(11.25, -0.5, -468) },
		{ size = Vector3.new(6.5, 1, 6), cframe = CFrame.new(29.75, -0.5, -468) },
		{ size = Vector3.new(24, 1, 14.5), cframe = CFrame.new(21, -0.5, -457.75) },
		{ size = Vector3.new(6, 1, 5.5), cframe = CFrame.new(12, -0.5, -447.75) },
		{ size = Vector3.new(7.5, 1, 5.5), cframe = CFrame.new(29.25, -0.5, -447.75) },
	}
	for apronIndex, spec in apronSpecs do
		WorldKit.part(crypt, "ChurchApron" .. apronIndex, spec.size, spec.cframe,
			apronColor, Enum.Material.Ground)
	end

	-- Stone stairwell behind the church (shifted just east of the church wall
	-- at x=14 so the descent clears the solid church floor slab)
	WorldKit.stairs(crypt, "CryptStairs",
		CFrame.new(14.6, -8.5, -468) * CFrame.Angles(0, math.rad(-90), 0),
		10, 4, STONE_COLD, Enum.Material.Slate)
	for wallSide = -1, 1, 2 do
		WorldKit.part(crypt, "StairwellWall", Vector3.new(13, 9, 0.5),
			CFrame.new(20.5, -4, -468 + wallSide * 2.7), STONE_DARK, Enum.Material.Slate)
	end
	for _, archZ in { -470.6, -465.4 } do
		WorldKit.part(crypt, "CryptArchPost", Vector3.new(0.8, 3.2, 0.8),
			CFrame.new(26.3, 1.6, archZ), STONE_COLD, Enum.Material.Slate)
	end
	WorldKit.part(crypt, "CryptArchLintel", Vector3.new(0.8, 0.8, 6.2),
		CFrame.new(26.3, 3.6, -468), STONE_COLD, Enum.Material.Slate)

	-- Crypt room under the church footprint (y ~ -7)
	WorldKit.part(crypt, "CryptFloor", Vector3.new(26, 0.8, 24),
		CFrame.new(0, -8.9, -459), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(crypt, "CryptBridge", Vector3.new(2.8, 0.8, 5.4),
		CFrame.new(13.2, -8.9, -468), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(crypt, "CryptWallN", Vector3.new(26, 5.5, 0.8),
		CFrame.new(0, -5.75, -447.4), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(crypt, "CryptWallS", Vector3.new(26, 5.5, 0.8),
		CFrame.new(0, -5.75, -470.6), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(crypt, "CryptWallW", Vector3.new(0.8, 5.5, 24),
		CFrame.new(-12.6, -5.75, -459), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(crypt, "CryptWallEN", Vector3.new(0.8, 5.5, 17.9),
		CFrame.new(12.6, -5.75, -456.3), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(crypt, "CryptCeiling", Vector3.new(27.5, 0.6, 25.5),
		CFrame.new(0, -2.7, -459), STONE_DARK, Enum.Material.Slate)

	-- Three wall niches; the middle one stands empty
	local nicheZs = { -466, -459, -452 }
	for nicheIndex, nicheZ in nicheZs do
		WorldKit.part(crypt, "NicheBack" .. nicheIndex, Vector3.new(0.3, 3.4, 3.2),
			CFrame.new(-12.05, -6.1, nicheZ), CHAR_BLACK, Enum.Material.Slate)
		for jambSide = -1, 1, 2 do
			WorldKit.part(crypt, "NicheJamb", Vector3.new(0.5, 3.4, 0.5),
				CFrame.new(-11.6, -6.1, nicheZ + jambSide * 1.85), STONE_COLD, Enum.Material.Slate)
		end
		WorldKit.part(crypt, "NicheShelf" .. nicheIndex, Vector3.new(1.6, 0.4, 3.4),
			CFrame.new(-11.4, -7.5, nicheZ), STONE_COLD, Enum.Material.Slate)
		if nicheIndex ~= 2 then
			WorldKit.part(crypt, "Effigy" .. nicheIndex, Vector3.new(1.1, 0.5, 2.4),
				CFrame.new(-11.4, -7.05, nicheZ), Color3.fromRGB(134, 136, 138), Enum.Material.Concrete)
			WorldKit.part(crypt, "EffigyHead" .. nicheIndex, Vector3.new(0.55, 0.55, 0.55),
				CFrame.new(-11.4, -6.95, nicheZ + 1.15), Color3.fromRGB(134, 136, 138),
				Enum.Material.Concrete, Enum.PartType.Ball)
		end
	end
	-- Disturbed dust and the open lid leaning by the empty niche
	local dust = WorldKit.part(crypt, "DisturbedDust", Vector3.new(1.4, 0.06, 2.7),
		CFrame.new(-11.4, -7.27, -459) * CFrame.Angles(0, 0.12, 0),
		Color3.fromRGB(168, 160, 142), Enum.Material.Sand)
	dust.CanCollide = false
	dust.Transparency = 0.3
	WorldKit.part(crypt, "OpenLidSlab", Vector3.new(1.3, 0.25, 2.8),
		CFrame.new(-10.7, -7, -456.1) * CFrame.Angles(0, 0.2, math.rad(72)),
		STONE_COLD, Enum.Material.Slate)

	-- Candle clusters with dim red glow (never generator-gated)
	for clusterIndex, clusterSpot in { Vector3.new(-9, -8.5, -466.5), Vector3.new(8, -8.5, -451) } do
		for candleIndex = 1, 3 do
			-- Cylinder axis runs along X; rolled upright with a 90-degree Z spin
			WorldKit.part(crypt, "Candle", Vector3.new(0.5 + candleIndex * 0.25, 0.4, 0.4),
				CFrame.new(clusterSpot + Vector3.new(candleIndex * 0.55 - 1.1, 0.5, (candleIndex % 2) * 0.5))
					* CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(214, 202, 178), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
		local flame = WorldKit.part(crypt, "CandleFlame" .. clusterIndex, Vector3.new(0.25, 0.25, 0.25),
			CFrame.new(clusterSpot + Vector3.new(0, 1.5, 0.25)), Color3.fromRGB(255, 120, 70),
			Enum.Material.Neon, Enum.PartType.Ball)
		flame.CanCollide = false
		-- Bright enough to search the niches by, still an ember-red crypt glow
		WorldKit.lamp(flame, { color = Color3.fromRGB(255, 110, 72), brightness = 1.4, range = 15 })
	end

	-- Inscription
	local inscription = WorldKit.part(crypt, "InscriptionBoard", Vector3.new(3.6, 1.5, 0.2),
		CFrame.new(0, -5.4, -448), STONE_COLD, Enum.Material.Slate)
	surfaceText(inscription, Enum.NormalId.Front, "QUI DORMIT\nNON DORMIT", Color3.fromRGB(40, 42, 44))

	WorldKit.evidenceSocketMarker(crypt, "crypt-empty-niche", Vector3.new(-11, -6, -459))
end

-- 5. STORM CELLAR NETWORK ----------------------------------------------------
local function buildStormCellars(dayCamp: Instance, nightTown: Instance)
	local terrain = Workspace.Terrain

	local function cellarDressing(model: Model, roomCenter: Vector3)
		-- Shelves, cobwebs, one non-gated lamp
		WorldKit.part(model, "CellarShelfLow", Vector3.new(3, 0.3, 1),
			CFrame.new(roomCenter + Vector3.new(-3.6, -0.6, 0)), WOOD_DARK, Enum.Material.Wood)
		WorldKit.part(model, "CellarShelfHigh", Vector3.new(3, 0.3, 1),
			CFrame.new(roomCenter + Vector3.new(-3.6, 0.7, 0)), WOOD_DARK, Enum.Material.Wood)
		for webIndex = 1, 2 do
			local web = WorldKit.part(model, "Cobweb" .. webIndex, Vector3.new(2.4, 2.4, 0.1),
				CFrame.new(roomCenter + Vector3.new(webIndex * 3 - 4.5, 1.3, webIndex * 2.4 - 3.6))
					* CFrame.Angles(0.5, webIndex * 0.9, math.rad(45)),
				Color3.fromRGB(232, 232, 228), Enum.Material.SmoothPlastic)
			web.Transparency = 0.72
			web.CanCollide = false
		end
		local lampCore = WorldKit.part(model, "CellarLampCore", Vector3.new(0.4, 0.4, 0.4),
			CFrame.new(roomCenter + Vector3.new(0, 1.9, 0)), Color3.fromRGB(255, 205, 130),
			Enum.Material.Neon)
		lampCore.CanCollide = false
		WorldKit.lamp(lampCore, { brightness = 1.1, range = 13 })
	end

	-- Cellar 1: beside the lodge (day camp), carved into the camp terrain.
	-- The stair-pit carve reaches above the rendered surface (~2.5) so the
	-- open trench under the lodge deck isn't roofed over by grass.
	terrain:FillBlock(CFrame.new(8, -4.3, 51), Vector3.new(12, 6, 14), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(8, -2.15, 61.5), Vector3.new(7, 10.7, 9), Enum.Material.Air)
	local lodgeCellar = WorldKit.model(dayCamp, "StormCellarLodge")
	WorldKit.part(lodgeCellar, "RoomFloor", Vector3.new(11, 0.8, 13),
		CFrame.new(8, -6.8, 51), DIRT_BROWN, Enum.Material.Ground)
	WorldKit.part(lodgeCellar, "RoomWallS", Vector3.new(10.6, 5.2, 0.6),
		CFrame.new(8, -3.8, 45.3), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(lodgeCellar, "RoomWallW", Vector3.new(0.6, 5.2, 12),
		CFrame.new(3.2, -3.8, 51), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(lodgeCellar, "RoomWallE", Vector3.new(0.6, 5.2, 12),
		CFrame.new(12.8, -3.8, 51), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(lodgeCellar, "RoomWallNW", Vector3.new(2.6, 5.2, 0.6),
		CFrame.new(4.2, -3.8, 56.7), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(lodgeCellar, "RoomWallNE", Vector3.new(2.6, 5.2, 0.6),
		CFrame.new(11.8, -3.8, 56.7), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(lodgeCellar, "RoomCeiling", Vector3.new(11, 0.6, 13),
		CFrame.new(8, -1.6, 51), WOOD_DARK, Enum.Material.WoodPlanks)
	-- The lodge now sits at base Y 2.0 with its porch deck top at 3.0 and a
	-- real opening cut in the deck over this pit (createCabin splits the
	-- slab): ten steps climb from the cellar to deck level, the trench
	-- walls rise to meet the deck, and the hatch lids sit on the new deck
	-- plane. Before this, the stairs dead-ended under a solid porch and the
	-- hatch doors opened onto wood.
	WorldKit.stairs(lodgeCellar, "CellarSteps",
		CFrame.new(8, -6.4, 55.2) * CFrame.Angles(0, math.rad(180), 0),
		10, 4, STONE_DARK, Enum.Material.Slate)
	for trenchSide = -1, 1, 2 do
		WorldKit.part(lodgeCellar, "TrenchWall", Vector3.new(0.5, 9.4, 9),
			CFrame.new(8 + trenchSide * 2.4, -1.7, 61.5), STONE_DARK, Enum.Material.Slate)
	end
	-- Sloped hatch doors facing away from the lodge, over the open stair pit
	for doorIndex = 0, 1 do
		WorldKit.hingedDoor(lodgeCellar, "HatchDoor", Vector3.new(2.25, 0.3, 4.3),
			CFrame.new(6.85 + doorIndex * 2.3, 3.25, 64.8) * CFrame.Angles(math.rad(-56), 0, 0),
			WOOD_DARK)
	end
	cellarDressing(lodgeCellar, Vector3.new(8, -4.6, 51))
	local lodgeCrawl = WorldKit.part(lodgeCellar, "CrawlTunnelDoor", Vector3.new(2.4, 2.8, 0.4),
		CFrame.new(8, -4.9, 45.7), CHAR_BLACK, Enum.Material.Slate)
	local lodgeArrive = Vector3.new(8, -4.4, 51)

	-- Cellar 2: beside the church (night town), pit through the crypt's apron
	local churchCellar = WorldKit.model(nightTown, "StormCellarChurch")
	WorldKit.part(churchCellar, "RoomFloor", Vector3.new(11, 0.8, 10),
		CFrame.new(28, -6.8, -448), DIRT_BROWN, Enum.Material.Ground)
	WorldKit.part(churchCellar, "RoomWallN", Vector3.new(11, 5.2, 0.6),
		CFrame.new(28, -3.8, -443.3), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(churchCellar, "RoomWallS", Vector3.new(11, 5.2, 0.6),
		CFrame.new(28, -3.8, -452.7), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(churchCellar, "RoomWallE", Vector3.new(0.6, 5.2, 9),
		CFrame.new(32.7, -3.8, -448), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(churchCellar, "RoomWallWN", Vector3.new(0.6, 5.2, 3),
		CFrame.new(23.3, -3.8, -444.9), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(churchCellar, "RoomWallWS", Vector3.new(0.6, 5.2, 3),
		CFrame.new(23.3, -3.8, -451.1), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(churchCellar, "RoomCeiling", Vector3.new(11, 0.6, 10),
		CFrame.new(28, -1.6, -448), WOOD_DARK, Enum.Material.WoodPlanks)
	WorldKit.stairs(churchCellar, "CellarSteps",
		CFrame.new(22.8, -6.4, -448) * CFrame.Angles(0, math.rad(90), 0),
		7, 4, STONE_DARK, Enum.Material.Slate)
	for trenchSide = -1, 1, 2 do
		WorldKit.part(churchCellar, "TrenchWall", Vector3.new(8.5, 7.4, 0.5),
			CFrame.new(19.15, -2.8, -448 + trenchSide * 2.35), STONE_DARK, Enum.Material.Slate)
	end
	for doorIndex = 0, 1 do
		WorldKit.hingedDoor(churchCellar, "HatchDoor", Vector3.new(2.25, 0.3, 4.3),
			CFrame.new(14.6, 1.55, -449.15 + doorIndex * 2.3)
				* CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(-54), 0, 0),
			WOOD_DARK)
	end
	cellarDressing(churchCellar, Vector3.new(28, -4.6, -448))
	local churchCrawl = WorldKit.part(churchCellar, "CrawlTunnelDoor", Vector3.new(0.4, 2.8, 2.4),
		CFrame.new(32.3, -4.9, -448), CHAR_BLACK, Enum.Material.Slate)
	local churchArrive = Vector3.new(28, -4.4, -448)

	-- Cellar 3: beside Residential A (night town). The town ground there is a
	-- solid slab, so this one is a classic mound cellar raised over grade.
	local mound = WorldKit.model(nightTown, "StormCellarResidential")
	WorldKit.part(mound, "RoomFloor", Vector3.new(9, 0.6, 8),
		CFrame.new(-92, 0.3, -120), DIRT_BROWN, Enum.Material.Ground)
	WorldKit.part(mound, "RoomWallN", Vector3.new(9, 4.6, 0.6),
		CFrame.new(-92, 2.9, -123.7), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mound, "RoomWallW", Vector3.new(0.6, 4.6, 8),
		CFrame.new(-96.2, 2.9, -120), STONE_DARK, Enum.Material.Slate)
	WorldKit.part(mound, "RoomWallE", Vector3.new(0.6, 4.6, 8),
		CFrame.new(-87.8, 2.9, -120), STONE_DARK, Enum.Material.Slate)
	for side = -1, 1, 2 do
		WorldKit.part(mound, "RoomWallSSeg", Vector3.new(3, 4.6, 0.6),
			CFrame.new(-92 + side * 3, 2.9, -116.3), STONE_DARK, Enum.Material.Slate)
	end
	WorldKit.part(mound, "RoomRoof", Vector3.new(10, 0.6, 9),
		CFrame.new(-92, 5.4, -120), STONE_DARK, Enum.Material.Slate)
	-- Earth berm over the shell
	WorldKit.wedge(mound, "BermN", Vector3.new(10, 5.4, 3.4),
		CFrame.new(-92, 2.7, -125.9), Color3.fromRGB(64, 78, 56), Enum.Material.Grass)
	WorldKit.wedge(mound, "BermW", Vector3.new(9, 5.4, 3.4),
		CFrame.new(-98.2, 2.7, -120) * CFrame.Angles(0, math.rad(-90), 0),
		Color3.fromRGB(64, 78, 56), Enum.Material.Grass)
	WorldKit.wedge(mound, "BermE", Vector3.new(9, 5.4, 3.4),
		CFrame.new(-85.8, 2.7, -120) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(64, 78, 56), Enum.Material.Grass)
	WorldKit.part(mound, "BermTop", Vector3.new(10.6, 0.5, 9.6),
		CFrame.new(-92, 5.95, -120), Color3.fromRGB(64, 78, 56), Enum.Material.Grass)
	for doorIndex = 0, 1 do
		WorldKit.hingedDoor(mound, "HatchDoor", Vector3.new(1.6, 0.3, 4.6),
			CFrame.new(-92.85 + doorIndex * 1.7, 2.5, -114.7) * CFrame.Angles(math.rad(-58), 0, 0),
			WOOD_DARK)
	end
	for stepIndex = 0, 1 do
		WorldKit.part(mound, "EntryStep", Vector3.new(3.4, 0.5, 1.1),
			CFrame.new(-92, 0.25 + stepIndex * 0.35, -113.6 - stepIndex * 1.1),
			STONE_COLD, Enum.Material.Concrete)
	end
	cellarDressing(mound, Vector3.new(-92, 2.4, -120))
	local moundCrawl = WorldKit.part(mound, "CrawlTunnelDoor", Vector3.new(2.4, 2.8, 0.4),
		CFrame.new(-92, 2.1, -123.3), CHAR_BLACK, Enum.Material.Slate)
	local moundArrive = Vector3.new(-92, 2.6, -120)

	-- Crawl-tunnel ring: lodge -> church -> residential -> lodge
	local function wireCrawl(door: BasePart, targetPos: Vector3)
		local crawlPrompt = WorldKit.prompt(door, "Crawl through the dark", "Crawl Tunnel", 0.7)
		crawlPrompt.Triggered:Connect(function(player: Player)
			task.spawn(function()
				task.wait(2)
				local character = player.Character
				if character then
					character:PivotTo(CFrame.new(targetPos))
				end
			end)
		end)
	end
	wireCrawl(lodgeCrawl, churchArrive)
	wireCrawl(churchCrawl, moundArrive)
	wireCrawl(moundCrawl, lodgeArrive)
end

-- 6. FIRE LOOKOUT TOWER ------------------------------------------------------
local function buildFireLookout(dayCamp: Instance)
	-- Small grass knoll so every leg has footing where the north hill thins
	Workspace.Terrain:FillBall(Vector3.new(0, -4, 118), 14, Enum.Material.Grass)

	local tower = WorldKit.model(dayCamp, "FireLookoutTower")
	local deckTop = 34

	for _, legX in { -5, 5 } do
		for _, legZ in { 113, 123 } do
			WorldKit.part(tower, "TowerLeg", Vector3.new(1.2, 35, 1.2),
				CFrame.new(legX, 16.5, legZ), TIMBER, Enum.Material.Wood)
			WorldKit.part(tower, "LegFooting", Vector3.new(2, 2, 2),
				CFrame.new(legX, 1, legZ), STONE_COLD, Enum.Material.Slate)
		end
	end
	for _, braceY in { 12, 24 } do
		WorldKit.part(tower, "BraceN", Vector3.new(10.6, 0.5, 0.5),
			CFrame.new(0, braceY, 123), TIMBER, Enum.Material.Wood)
		WorldKit.part(tower, "BraceS", Vector3.new(10.6, 0.5, 0.5),
			CFrame.new(0, braceY, 113), TIMBER, Enum.Material.Wood)
		WorldKit.part(tower, "BraceE", Vector3.new(0.5, 0.5, 10.6),
			CFrame.new(5, braceY, 118), TIMBER, Enum.Material.Wood)
		WorldKit.part(tower, "BraceW", Vector3.new(0.5, 0.5, 10.6),
			CFrame.new(-5, braceY, 118), TIMBER, Enum.Material.Wood)
	end

	-- Wraparound deck + railing (gap on the west edge for the stairs)
	local deck = WorldKit.part(tower, "LookoutDeck", Vector3.new(14, 0.8, 14),
		CFrame.new(0, deckTop - 0.4, 118), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.creakyFloor(deck)
	WorldKit.part(tower, "DeckRailN", Vector3.new(14, 0.4, 0.4),
		CFrame.new(0, deckTop + 1.5, 124.8), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(tower, "DeckRailS", Vector3.new(14, 0.4, 0.4),
		CFrame.new(0, deckTop + 1.5, 111.2), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(tower, "DeckRailE", Vector3.new(0.4, 0.4, 14),
		CFrame.new(6.8, deckTop + 1.5, 118), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(tower, "DeckRailWN", Vector3.new(0.4, 0.4, 4.8),
		CFrame.new(-6.8, deckTop + 1.5, 122.6), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(tower, "DeckRailWS", Vector3.new(0.4, 0.4, 3),
		CFrame.new(-6.8, deckTop + 1.5, 112.7), WOOD_DARK, Enum.Material.Wood)
	for _, postX in { -6.8, 6.8 } do
		for _, postZ in { 111.2, 124.8 } do
			WorldKit.part(tower, "RailPost", Vector3.new(0.4, 2, 0.4),
				CFrame.new(postX, deckTop + 0.9, postZ), WOOD_DARK, Enum.Material.Wood)
		end
	end

	-- Glass-walled cab
	for _, postX in { -4, 4 } do
		for _, postZ in { 114, 122 } do
			WorldKit.part(tower, "CabPost", Vector3.new(0.5, 5.6, 0.5),
				CFrame.new(postX, deckTop + 2.8, postZ), TIMBER, Enum.Material.Wood)
		end
	end
	local function cabGlass(name: string, size: Vector3, cframe: CFrame)
		local pane = WorldKit.part(tower, name, size, cframe,
			Color3.fromRGB(148, 190, 196), Enum.Material.Glass)
		pane.Transparency = 0.45
	end
	cabGlass("CabGlassN", Vector3.new(8, 5, 0.3), CFrame.new(0, deckTop + 2.9, 122))
	cabGlass("CabGlassE", Vector3.new(0.3, 5, 8), CFrame.new(4, deckTop + 2.9, 118))
	cabGlass("CabGlassW", Vector3.new(0.3, 5, 8), CFrame.new(-4, deckTop + 2.9, 118))
	cabGlass("CabGlassSE", Vector3.new(2.6, 5, 0.3), CFrame.new(2.7, deckTop + 2.9, 114))
	cabGlass("CabGlassSW", Vector3.new(2.6, 5, 0.3), CFrame.new(-2.7, deckTop + 2.9, 114))
	WorldKit.part(tower, "CabRoof", Vector3.new(9.6, 0.5, 9.6),
		CFrame.new(0, deckTop + 5.8, 118), Color3.fromRGB(88, 84, 76), Enum.Material.CorrodedMetal)

	-- Cab interior: map table, chair, lamp
	WorldKit.part(tower, "MapTable", Vector3.new(3, 0.3, 2),
		CFrame.new(1, deckTop + 1.6, 119.4), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(tower, "MapTablePedestal", Vector3.new(0.5, 1.5, 0.5),
		CFrame.new(1, deckTop + 0.75, 119.4), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(tower, "CabChairSeat", Vector3.new(1.4, 0.9, 1.4),
		CFrame.new(-1.9, deckTop + 0.45, 119.8), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(tower, "CabChairBack", Vector3.new(1.4, 1.5, 0.25),
		CFrame.new(-1.9, deckTop + 1.6, 120.4), WOOD_DARK, Enum.Material.Wood)
	local cabLampCore = WorldKit.part(tower, "CabLampCore", Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(0, deckTop + 5.2, 118), Color3.fromRGB(255, 205, 130), Enum.Material.Neon)
	cabLampCore.CanCollide = false
	WorldKit.lamp(cabLampCore, { brightness = 1.3, range = 16 })

	-- Deck telescope: sweeps the valley for anything glinting
	WorldKit.part(tower, "TelescopePedestal", Vector3.new(0.4, 1.7, 0.4),
		CFrame.new(5.4, deckTop + 0.85, 113), METAL_GREY, Enum.Material.Metal)
	local telescopeTube = WorldKit.part(tower, "TelescopeTube", Vector3.new(2.1, 0.6, 0.6),
		CFrame.new(5.4, deckTop + 2, 113) * CFrame.Angles(0, math.rad(35), math.rad(18)),
		Color3.fromRGB(120, 96, 58), Enum.Material.Metal, Enum.PartType.Cylinder)
	local telescopePrompt = WorldKit.prompt(telescopeTube, "Peer through the telescope", "Lookout Telescope", 0.6)
	local telescopeBusy = false
	telescopePrompt.Triggered:Connect(function()
		if telescopeBusy then
			return
		end
		telescopeBusy = true
		task.delay(2, function()
			telescopeBusy = false
		end)
		local runtimeFolder = Workspace:FindFirstChild("Runtime")
		local evidenceFolder = if runtimeFolder then runtimeFolder:FindFirstChild("Evidence") else nil
		local pieces = if evidenceFolder then evidenceFolder:GetChildren() else {}
		if #pieces > 0 then
			local chosen = pieces[math.random(1, #pieces)]
			announce("Info", "Lookout telescope", "Something glints near: " .. chosen.Name, 5)
		else
			announce("Info", "Lookout telescope", "The valley is quiet. For now.", 5)
		end
	end)

	-- Zigzag stairs on the west face (the east flank is buried in the hill)
	WorldKit.stairs(tower, "ApproachSteps",
		CFrame.new(-8.2, 0.9, 105.5) * CFrame.Angles(0, math.rad(180), 0),
		6, 3, WOOD_WEATHER, Enum.Material.WoodPlanks)
	local flightSpecs: { { base: CFrame, steps: number } } = {
		{ base = CFrame.new(-8.2, 6.3, 112.4) * CFrame.Angles(0, math.rad(180), 0), steps = 7 },
		{ base = CFrame.new(-8.2, 12.6, 120.9), steps = 7 },
		{ base = CFrame.new(-8.2, 18.9, 113.4) * CFrame.Angles(0, math.rad(180), 0), steps = 7 },
		{ base = CFrame.new(-8.2, 25.2, 121.7), steps = 7 },
		{ base = CFrame.new(-8.2, 31.5, 114.2) * CFrame.Angles(0, math.rad(180), 0), steps = 3 },
	}
	for flightIndex, flight in flightSpecs do
		WorldKit.stairs(tower, "Flight" .. flightIndex, flight.base, flight.steps, 3,
			WOOD_WEATHER, Enum.Material.WoodPlanks)
	end
	WorldKit.part(tower, "StairLanding1", Vector3.new(3.2, 0.9, 3.4),
		CFrame.new(-8.2, 12.15, 121.9), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(tower, "StairLanding2", Vector3.new(3.2, 0.9, 3.4),
		CFrame.new(-8.2, 18.45, 112.1), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(tower, "StairLanding3", Vector3.new(3.2, 0.9, 3.4),
		CFrame.new(-8.2, 24.75, 122.4), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(tower, "StairLanding4", Vector3.new(3.2, 0.9, 3.4),
		CFrame.new(-8.2, 31.05, 112.9), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(tower, "LandingPostA", Vector3.new(0.5, 11.7, 0.5),
		CFrame.new(-9.6, 5.85, 121.9), TIMBER, Enum.Material.Wood)
	WorldKit.part(tower, "LandingPostB", Vector3.new(0.5, 24.3, 0.5),
		CFrame.new(-9.6, 12.15, 122.9), TIMBER, Enum.Material.Wood)

	WorldKit.evidenceSocketMarker(tower, "lookout-cab", Vector3.new(0, 35.6, 118))
end

-- 7. CABIN ZERO --------------------------------------------------------------
local function buildCabinZero(dayCamp: Instance)
	local ruins = WorldKit.model(dayCamp, "CabinZero")
	-- Slab shifted to z 82 so nothing clips the counselor quarters arc
	local cx, cz = -70, 82

	WorldKit.part(ruins, "CharredSlab", Vector3.new(12, 0.5, 10),
		CFrame.new(cx, 0.5, cz), CHAR_BLACK, Enum.Material.Slate)
	WorldKit.part(ruins, "WallStubW", Vector3.new(0.6, 2.6, 9),
		CFrame.new(cx - 5.6, 2.05, cz), ASH_GREY, Enum.Material.Slate)
	WorldKit.part(ruins, "WallStubN", Vector3.new(11, 2.6, 0.6),
		CFrame.new(cx, 2.05, cz + 4.6), ASH_GREY, Enum.Material.Slate)
	WorldKit.part(ruins, "WallStubE", Vector3.new(0.6, 2.2, 5),
		CFrame.new(cx + 5.6, 1.85, cz + 1.8), ASH_GREY, Enum.Material.Slate)

	-- Collapsed roof beams
	WorldKit.wedge(ruins, "FallenBeamA", Vector3.new(1, 2.8, 6),
		CFrame.new(cx - 1.5, 1.6, cz + 0.5) * CFrame.Angles(0, 0.6, 0.12),
		CHAR_BLACK, Enum.Material.Wood)
	WorldKit.wedge(ruins, "FallenBeamB", Vector3.new(0.9, 2.2, 5),
		CFrame.new(cx + 2.4, 1.4, cz - 1.6) * CFrame.Angles(0, -0.9, -0.1),
		CHAR_BLACK, Enum.Material.Wood)
	WorldKit.part(ruins, "FallenRidge", Vector3.new(0.7, 0.7, 8.5),
		CFrame.new(cx + 0.6, 1.1, cz + 0.8) * CFrame.Angles(0.06, 0.35, 0),
		CHAR_BLACK, Enum.Material.Wood)

	-- The chimney still stands
	WorldKit.part(ruins, "ChimneyHearth", Vector3.new(3.2, 1.6, 2.8),
		CFrame.new(cx - 4.5, 1.3, cz + 3.5), STONE_DARK, Enum.Material.Cobblestone)
	WorldKit.part(ruins, "ChimneyStack", Vector3.new(2.2, 8.4, 2.2),
		CFrame.new(cx - 4.5, 5.3, cz + 3.5), STONE_DARK, Enum.Material.Cobblestone)
	WorldKit.part(ruins, "ChimneyCap", Vector3.new(2.8, 0.5, 2.8),
		CFrame.new(cx - 4.5, 9.75, cz + 3.5), STONE_COLD, Enum.Material.Slate)

	-- Memorial stone out front
	WorldKit.part(ruins, "MemorialBase", Vector3.new(3, 0.5, 1.2),
		CFrame.new(cx + 2, 0.75, cz - 5.8), STONE_COLD, Enum.Material.Concrete)
	local memorial = WorldKit.part(ruins, "MemorialStone", Vector3.new(2.6, 2.1, 0.5),
		CFrame.new(cx + 2, 2, cz - 5.8) * CFrame.Angles(math.rad(-6), 0, 0),
		STONE_COLD, Enum.Material.Concrete)
	surfaceText(memorial, Enum.NormalId.Front,
		"CABIN 0\nNEVER FORGOTTEN\nSUMMER 1987", Color3.fromRGB(40, 42, 44))

	-- Soot-black fire ring
	for stoneIndex = 1, 5 do
		local angle = stoneIndex / 5 * math.pi * 2
		WorldKit.part(ruins, "SootStone" .. stoneIndex, Vector3.new(0.9, 0.7, 0.9),
			CFrame.new(cx + 6 + math.cos(angle) * 1.7, 0.85, cz - 5.2 + math.sin(angle) * 1.7)
				* CFrame.Angles(0, angle, 0),
			ASH_GREY, Enum.Material.Slate)
	end
	local sootDisc = WorldKit.part(ruins, "SootBed", Vector3.new(0.2, 3, 3),
		CFrame.new(cx + 6, 0.6, cz - 5.2) * CFrame.Angles(0, 0, math.rad(90)),
		CHAR_BLACK, Enum.Material.Slate, Enum.PartType.Cylinder)
	sootDisc.CanCollide = false

	WorldKit.evidenceSocketMarker(ruins, "cabin-zero-chimney", Vector3.new(cx - 4.5, 3, cz + 3.5))
	-- The authored anchor sits in the saddle between two perimeter domes and
	-- ~2.5 below the camp grass; slide the finished ruin east onto the flat
	-- and lift the slab just proud of grade.
	ruins:PivotTo(ruins:GetPivot() + Vector3.new(7, 2.6, -2))
end

-- 9. RADIO TOWER HILL --------------------------------------------------------
local function buildRadioTower(nightTown: Instance)
	local hill = WorldKit.model(nightTown, "RadioTowerHill")

	-- Rocky knoll (boulder cluster; the dead street just dead-ends into it)
	local boulderSpecs: { { size: Vector3, cframe: CFrame, ball: boolean } } = {
		{ size = Vector3.new(9, 6, 9), cframe = CFrame.new(140, 2.6, -380), ball = false },
		{ size = Vector3.new(7, 4.5, 6), cframe = CFrame.new(135.5, 1.8, -374.5) * CFrame.Angles(0.1, 0.7, 0.08), ball = false },
		{ size = Vector3.new(6, 4, 7), cframe = CFrame.new(145.5, 1.6, -375) * CFrame.Angles(-0.08, 0.4, 0.1), ball = false },
		{ size = Vector3.new(7, 4.4, 6.4), cframe = CFrame.new(145, 1.8, -385.5) * CFrame.Angles(0.06, 1.2, -0.09), ball = false },
		{ size = Vector3.new(6.4, 4.2, 6.4), cframe = CFrame.new(135, 1.7, -385) * CFrame.Angles(0, 0.3, 0), ball = true },
		{ size = Vector3.new(4.4, 4.4, 4.4), cframe = CFrame.new(140.5, 1.4, -388.5), ball = true },
	}
	for boulderIndex, spec in boulderSpecs do
		WorldKit.part(hill, "Boulder" .. boulderIndex, spec.size, spec.cframe,
			STONE_DARK, Enum.Material.Slate, if spec.ball then Enum.PartType.Ball else nil)
	end

	-- Lattice mast (~40 studs) with cross braces and a maintenance ladder
	WorldKit.part(hill, "MastBase", Vector3.new(5.4, 0.8, 5.4),
		CFrame.new(140, 5.8, -380), STONE_COLD, Enum.Material.Concrete)
	for _, cornerX in { 138.9, 141.1 } do
		for _, cornerZ in { -381.1, -378.9 } do
			WorldKit.truss(hill, "MastTruss", Vector3.new(2, 40, 2),
				CFrame.new(cornerX, 26.2, cornerZ), METAL_GREY)
		end
	end
	for braceLevel = 1, 3 do
		local braceY = 12 + braceLevel * 9
		WorldKit.part(hill, "MastBraceX", Vector3.new(4.6, 0.4, 0.4),
			CFrame.new(140, braceY, -380) * CFrame.Angles(0, 0, math.rad(24)),
			METAL_GREY, Enum.Material.Metal)
		WorldKit.part(hill, "MastBraceZ", Vector3.new(0.4, 0.4, 4.6),
			CFrame.new(140, braceY + 4.5, -380) * CFrame.Angles(math.rad(-24), 0, 0),
			METAL_GREY, Enum.Material.Metal)
	end
	WorldKit.truss(hill, "MaintenanceLadder", Vector3.new(2, 40, 2),
		CFrame.new(140, 24.2, -376.7), Color3.fromRGB(120, 122, 124))

	-- Blinking red beacon (1.2s cadence — matches the skybox blink)
	local beacon = WorldKit.part(hill, "Beacon", Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(140, 47.4, -380), Color3.fromRGB(226, 48, 44), Enum.Material.Neon,
		Enum.PartType.Ball)
	beacon.CanCollide = false
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = Color3.fromRGB(226, 48, 44)
	beaconLight.Brightness = 2.2
	beaconLight.Range = 34
	beaconLight.Parent = beacon
	toggleLoop(beacon, 1.2, function(on: boolean): number?
		beacon.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		beaconLight.Enabled = on
		return nil
	end)

	-- Humming transformer box at the knoll base
	WorldKit.part(hill, "HummingTransformer", Vector3.new(3, 3.4, 2.4),
		CFrame.new(133.5, 1.7, -390.5), Color3.fromRGB(70, 74, 70), Enum.Material.CorrodedMetal)
	for insulatorIndex = 0, 1 do
		-- Cylinder axis along X; stood upright with a 90-degree Z spin
		WorldKit.part(hill, "Insulator" .. insulatorIndex, Vector3.new(0.9, 0.4, 0.4),
			CFrame.new(132.8 + insulatorIndex * 1.4, 3.7, -390.5) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(180, 184, 188), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end

	-- Broadcast shack (6 x 8) west of the knoll
	local sx, sz = 127, -393
	WorldKit.part(hill, "ShackFloor", Vector3.new(6, 0.5, 8),
		CFrame.new(sx, 0.45, sz), WOOD_DARK, Enum.Material.WoodPlanks)
	WorldKit.part(hill, "ShackWallW", Vector3.new(0.5, 6, 8),
		CFrame.new(sx - 2.75, 3.6, sz), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(hill, "ShackWallN", Vector3.new(6, 6, 0.5),
		CFrame.new(sx, 3.6, sz + 3.75), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(hill, "ShackWallS", Vector3.new(6, 6, 0.5),
		CFrame.new(sx, 3.6, sz - 3.75), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(hill, "ShackWallEN", Vector3.new(0.5, 6, 2.6),
		CFrame.new(sx + 2.75, 3.6, sz + 2.7), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(hill, "ShackWallES", Vector3.new(0.5, 6, 2.6),
		CFrame.new(sx + 2.75, 3.6, sz - 2.7), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(hill, "ShackDoorHeader", Vector3.new(0.5, 1.4, 2.8),
		CFrame.new(sx + 2.75, 5.9, sz), WOOD_WEATHER, Enum.Material.WoodPlanks)
	WorldKit.part(hill, "ShackRoof", Vector3.new(7.2, 0.5, 9.2),
		CFrame.new(sx, 6.85, sz), Color3.fromRGB(88, 84, 76), Enum.Material.CorrodedMetal)

	-- Console with dials, swivel chair, ON AIR sign that lights at night
	WorldKit.part(hill, "ConsoleDeck", Vector3.new(1.6, 0.4, 5),
		CFrame.new(sx - 1.8, 2.6, sz), ASH_GREY, Enum.Material.Metal)
	WorldKit.part(hill, "ConsolePanel", Vector3.new(1.5, 1.9, 4.8),
		CFrame.new(sx - 1.9, 1.4, sz), ASH_GREY, Enum.Material.Metal)
	for dialIndex = -1, 1 do
		local dial = WorldKit.part(hill, "ConsoleDial", Vector3.new(0.3, 0.3, 0.3),
			CFrame.new(sx - 1.5, 2.95, sz + dialIndex * 1.4),
			Color3.fromRGB(214, 176, 88), Enum.Material.Neon)
		dial.CanCollide = false
	end
	WorldKit.part(hill, "SwivelChairPost", Vector3.new(0.35, 1.3, 0.35),
		CFrame.new(sx + 0.4, 1.15, sz), METAL_GREY, Enum.Material.Metal)
	WorldKit.part(hill, "SwivelChairSeat", Vector3.new(1.4, 0.3, 1.4),
		CFrame.new(sx + 0.4, 1.95, sz), Color3.fromRGB(96, 56, 48), Enum.Material.Fabric)
	WorldKit.part(hill, "SwivelChairBack", Vector3.new(0.25, 1.4, 1.4),
		CFrame.new(sx + 1, 2.8, sz), Color3.fromRGB(96, 56, 48), Enum.Material.Fabric)
	local onAir = WorldKit.part(hill, "OnAirSign", Vector3.new(0.25, 1, 2.4),
		CFrame.new(sx - 2.45, 4.9, sz), Color3.fromRGB(30, 24, 24), Enum.Material.SmoothPlastic)
	surfaceText(onAir, Enum.NormalId.Right, "ON AIR", Color3.fromRGB(226, 64, 52))
	WorldKit.lamp(onAir, { color = Color3.fromRGB(226, 64, 52), brightness = 0.9, range = 8 })

	WorldKit.evidenceSocketMarker(hill, "radio-shack-console", Vector3.new(125.6, 3.4, -393))
end

-- 10. CAMP AURORA RUINS ------------------------------------------------------
local function buildCampAurora(dayCamp: Instance)
	-- Far shore: the camp-side terrain ends at x=125, so raise a grass bank
	-- east of the lake for the ruins to stand on (swim or row across).
	Workspace.Terrain:FillBlock(
		CFrame.new(156, -3.5, 17),
		Vector3.new(76, 8, 64),
		Enum.Material.Grass
	)

	local aurora = WorldKit.model(dayCamp, "CampAuroraRuins")

	-- Collapsed gate arch with missing letters
	WorldKit.part(aurora, "GatePostN", Vector3.new(1.1, 9, 1.1),
		CFrame.new(153, 4.9, 12) * CFrame.Angles(0, 0, math.rad(4)), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(aurora, "GatePostS", Vector3.new(1.1, 7.6, 1.1),
		CFrame.new(153, 4.2, 20) * CFrame.Angles(math.rad(-3), 0, math.rad(-7)),
		WOOD_DARK, Enum.Material.Wood)
	local gateBeam = WorldKit.part(aurora, "GateBeam", Vector3.new(0.8, 1.6, 9.6),
		CFrame.new(153, 8.6, 16.2) * CFrame.Angles(math.rad(6), 0, 0), WOOD_DARK, Enum.Material.Wood)
	surfaceText(gateBeam, Enum.NormalId.Left, "C_MP  AUR_RA", Color3.fromRGB(196, 180, 140))
	WorldKit.part(aurora, "FallenGateBoard", Vector3.new(0.5, 0.9, 4.2),
		CFrame.new(154.5, 0.9, 18.5) * CFrame.Angles(math.rad(80), 0.4, 0),
		WOOD_DARK, Enum.Material.WoodPlanks)

	-- Two ruined cabin foundations with rotted bunk frames
	for foundationIndex, foundationSpot in { Vector3.new(165, 0, 28), Vector3.new(172, 0, 4) } do
		local slab = WorldKit.part(aurora, "RuinSlab" .. foundationIndex, Vector3.new(10, 0.8, 8),
			CFrame.new(foundationSpot + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, foundationIndex * 0.4, 0),
			Color3.fromRGB(84, 86, 82), Enum.Material.Concrete)
		local slabFrame = slab.CFrame
		WorldKit.part(aurora, "RuinStubA" .. foundationIndex, Vector3.new(10, 1.4, 0.6),
			slabFrame * CFrame.new(0, 1.1, -3.7), Color3.fromRGB(84, 86, 82), Enum.Material.Concrete)
		WorldKit.part(aurora, "RuinStubB" .. foundationIndex, Vector3.new(0.6, 1.1, 8),
			slabFrame * CFrame.new(-4.7, 0.95, 0), Color3.fromRGB(84, 86, 82), Enum.Material.Concrete)
		WorldKit.part(aurora, "RuinStubC" .. foundationIndex, Vector3.new(3.4, 0.9, 0.6),
			slabFrame * CFrame.new(3, 0.85, 3.7), Color3.fromRGB(84, 86, 82), Enum.Material.Concrete)
		-- Rotted bunk frame
		WorldKit.part(aurora, "BunkRail" .. foundationIndex, Vector3.new(4.4, 0.4, 2),
			slabFrame * CFrame.new(-1.6, 1.1, -2) * CFrame.Angles(0, 0, math.rad(-7)),
			ROCK_BROWN, Enum.Material.Wood)
		WorldKit.part(aurora, "BunkPostA" .. foundationIndex, Vector3.new(0.4, 2.4, 0.4),
			slabFrame * CFrame.new(-3.6, 1.6, -1), ROCK_BROWN, Enum.Material.Wood)
		WorldKit.part(aurora, "BunkPostB" .. foundationIndex, Vector3.new(0.4, 1.7, 0.4),
			slabFrame * CFrame.new(0.6, 1.3, -3), ROCK_BROWN, Enum.Material.Wood)
	end

	-- Overgrown fire ring, cold and mossed over
	for stoneIndex = 1, 6 do
		local angle = stoneIndex / 6 * math.pi * 2
		WorldKit.part(aurora, "AuroraRingStone" .. stoneIndex, Vector3.new(1, 0.8, 1),
			CFrame.new(163 + math.cos(angle) * 2, 0.9, 15 + math.sin(angle) * 2)
				* CFrame.Angles(0, angle, 0.08),
			STONE_DARK, Enum.Material.Slate)
	end
	local mossBed = WorldKit.part(aurora, "MossyAsh", Vector3.new(0.2, 3.4, 3.4),
		CFrame.new(163, 0.62, 15) * CFrame.Angles(0, 0, math.rad(90)),
		MOSS_GREEN, Enum.Material.Grass, Enum.PartType.Cylinder)
	mossBed.CanCollide = false

	-- Flagpole with a tattered strip (cylinder axis X, stood upright)
	WorldKit.part(aurora, "AuroraFlagpole", Vector3.new(13, 0.4, 0.4),
		CFrame.new(160, 6.9, 24) * CFrame.Angles(0, 0, math.rad(87)),
		METAL_GREY, Enum.Material.Metal, Enum.PartType.Cylinder)
	local tatter = WorldKit.part(aurora, "TatteredFlag", Vector3.new(1.9, 1.1, 0.1),
		CFrame.new(161.2, 12.4, 24) * CFrame.Angles(0.15, 0.4, math.rad(14)),
		Color3.fromRGB(128, 100, 92), Enum.Material.Fabric)
	tatter.CanCollide = false

	-- Vines and moss patches over everything
	local mossSpecs: { CFrame } = {
		CFrame.new(153, 6.4, 12.6) * CFrame.Angles(0, 0, 0.3),
		CFrame.new(165.5, 1.2, 25.4) * CFrame.Angles(0.1, 0.8, 0),
		CFrame.new(161.5, 1.1, 30.2) * CFrame.Angles(0, 1.9, 0.12),
		CFrame.new(171, 1.3, 1.2) * CFrame.Angles(0.08, 0.5, 0),
		CFrame.new(175.8, 1, 6.8) * CFrame.Angles(0, 2.4, -0.1),
		CFrame.new(180.6, 3.1, 8.2) * CFrame.Angles(0, 0, 1.4),
		CFrame.new(158.2, 0.75, 18.4) * CFrame.Angles(0, 1.1, 0),
	}
	for mossIndex, mossFrame in mossSpecs do
		local moss = WorldKit.part(aurora, "MossPatch" .. mossIndex, Vector3.new(2.6, 0.15, 2),
			mossFrame, MOSS_GREEN, Enum.Material.Grass)
		moss.CanCollide = false
	end

	-- One intact-ish storm shelter, locked tight (future content tease)
	local shx, shz = 180, 10
	WorldKit.part(aurora, "ShelterWallN", Vector3.new(6, 4.4, 0.7),
		CFrame.new(shx, 2.6, shz + 3), Color3.fromRGB(84, 86, 82), Enum.Material.Concrete)
	WorldKit.part(aurora, "ShelterWallS", Vector3.new(6, 4.4, 0.7),
		CFrame.new(shx, 2.6, shz - 3), Color3.fromRGB(84, 86, 82), Enum.Material.Concrete)
	WorldKit.part(aurora, "ShelterWallE", Vector3.new(0.7, 4.4, 6.7),
		CFrame.new(shx + 3, 2.6, shz), Color3.fromRGB(84, 86, 82), Enum.Material.Concrete)
	WorldKit.part(aurora, "ShelterWallWN", Vector3.new(0.7, 4.4, 2),
		CFrame.new(shx - 3, 2.6, shz + 2.3), Color3.fromRGB(84, 86, 82), Enum.Material.Concrete)
	WorldKit.part(aurora, "ShelterWallWS", Vector3.new(0.7, 4.4, 2),
		CFrame.new(shx - 3, 2.6, shz - 2.3), Color3.fromRGB(84, 86, 82), Enum.Material.Concrete)
	WorldKit.part(aurora, "ShelterRoof", Vector3.new(7.4, 0.6, 7.4),
		CFrame.new(shx, 5.1, shz), STONE_DARK, Enum.Material.Concrete)
	local shelterDoor = WorldKit.part(aurora, "ShelterLockedDoor", Vector3.new(0.4, 4.2, 2.6),
		CFrame.new(shx - 3.1, 2.5, shz), Color3.fromRGB(66, 60, 52), Enum.Material.CorrodedMetal)
	surfaceText(shelterDoor, Enum.NormalId.Left,
		"PROPERTY OF\nAURORA COUNTY\nKEEP OUT", Color3.fromRGB(206, 188, 148))

	WorldKit.evidenceSocketMarker(aurora, "aurora-fire-ring", Vector3.new(163, 1.4, 15))
end

function Landmarks.Build(dayCamp: Instance, nightTown: Instance)
	buildMines(dayCamp)
	buildRangerStation(dayCamp)
	buildCrashedTruck(dayCamp)
	buildChapel(dayCamp)
	-- Crypt first: it lays the churchside ground apron the church cellar uses
	buildChurchCrypt(nightTown)
	buildStormCellars(dayCamp, nightTown)
	buildFireLookout(dayCamp)
	buildCabinZero(dayCamp)
	buildRadioTower(nightTown)
	buildCampAurora(dayCamp)
end

return Landmarks
