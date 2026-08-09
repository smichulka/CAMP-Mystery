--!strict

-- CAMP EXPANSION pack — front gate + camp bus, wayfinding signage, campfire
-- plaza, ropes aerial circuit + zipline, lodge hub, outhouse row + showers,
-- counselor quarters row, infirmary, archery range, and per-cabin character
-- props. Pure content builder: everything parents under dayCamp (always
-- visible). No gameplay wiring beyond cosmetic prompts; evidence socket
-- markers are tagged EvidenceSocketExtra via WorldKit and must be registered
-- in SEARCH_TARGETS/SEARCH_LOCATIONS by the integrator:
--   quarters-footlocker  Vector3.new(-52.7, 2.1, 74.5)   (Reed's cabin)
--   infirmary-logbook    Vector3.new(24, 3.2, 57.3)      (infirmary desk)
--   archery-shed         Vector3.new(-50.8, 2.2, -71)    (equipment shed)
--
-- Integration (end of ProductionMapService:Build()):
--   local CampExpansion = require(
--       script.Parent:WaitForChild("Map"):WaitForChild("CampExpansion")
--   )
--   CampExpansion.Build(self.dayCamp, self.nightTown)
--
-- Placement notes (checked against ProductionMapService geometry):
--   * Gate sits at (70, ·, 58), not (70, ·, 62): the boathouse (74, 68),
--     canoe-carry station (74, 64) and beach sand fill (80, 66) crowd the
--     suggested spot; the shifted arch still reads through the lakefront gap.
--   * Infirmary sits at (27, ·, 61), not (30, ·, 58): ForestRock #12 lands at
--     (33.3, 1.1, 54.6) and would poke through the interior at the suggested
--     footprint.
--   * Archery range works around the existing mini-range (targets at
--     (-44,-66)/(-35,-70), hay bale (-39.5,-72)), pine tree 20 at
--     (-45.6, ·, -67) and the storm-cellar surface seam along z = -70.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local WorldKit = require(script.Parent:WaitForChild("WorldKit"))

local CampExpansion = {}

-- Natural camp palette (matches ProductionMapService cabin/dock tones)
local WOOD_DARK = Color3.fromRGB(46, 32, 22)
local WOOD_MID = Color3.fromRGB(84, 60, 38)
local WOOD_PLANK = Color3.fromRGB(96, 70, 46)
local WOOD_WARM = Color3.fromRGB(112, 82, 52)
local WOOD_WALL = Color3.fromRGB(112, 102, 90)
local WOOD_FLOOR = Color3.fromRGB(72, 51, 36)
local TIN_ROOF = Color3.fromRGB(88, 84, 76)
local CANVAS = Color3.fromRGB(214, 198, 168)
local PAPER = Color3.fromRGB(234, 226, 208)
local FOREST_GREEN = Color3.fromRGB(58, 96, 64)
local LEAF_GREEN = Color3.fromRGB(74, 110, 60)
local BUS_GREEN = Color3.fromRGB(64, 106, 70)
local SLATE = Color3.fromRGB(96, 100, 92)
local LABEL_GOLD = Color3.fromRGB(226, 190, 114)
local LANTERN_AMBER = Color3.fromRGB(222, 186, 120)
local METAL_DARK = Color3.fromRGB(56, 60, 64)
local HAY = Color3.fromRGB(172, 150, 92)

-- Campfire pit center (the seat ring and plaza share this origin)
local FIRE_CENTER = Vector3.new(0, 0, 2)

local function cyl(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	return WorldKit.part(parent, name, size, cframe, color, material, Enum.PartType.Cylinder)
end

local function surfaceText(
	part: BasePart,
	text: string,
	textColor: Color3?,
	face: Enum.NormalId?,
	textSize: number?
): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(360, 140)
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.SpecialElite
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(34, 26, 18)
	if textSize then
		label.TextSize = textSize
		label.TextWrapped = true
	else
		label.TextScaled = true
	end
	label.Parent = gui
	return gui
end

-- Sound following the project convention: SoundService attribute override
-- with a placeholder default asset.
local function attachSound(
	parent: Instance,
	name: string,
	attribute: string,
	fallbackId: string,
	volume: number,
	playbackSpeed: number
): Sound
	local configured = SoundService:GetAttribute(attribute)
	local resolved = if typeof(configured) == "number" and configured > 0
		then "rbxassetid://" .. tostring(configured)
		elseif typeof(configured) == "string" and configured ~= "" then configured
		else fallbackId
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = resolved
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 14
	sound.RollOffMaxDistance = 160
	sound.Parent = parent
	return sound
end

-- Hanging lantern used along paths and inside expansion structures.
local function lanternBox(parent: Instance, position: Vector3, options: WorldKit.LampOptions?): Part
	local box = WorldKit.part(
		parent,
		"LanternBox",
		Vector3.new(0.9, 1.15, 0.9),
		CFrame.new(position),
		LANTERN_AMBER,
		Enum.Material.Glass
	)
	box.Transparency = 0.3
	box.CanCollide = false
	WorldKit.part(
		parent,
		"LanternCap",
		Vector3.new(1.1, 0.22, 1.1),
		CFrame.new(position + Vector3.new(0, 0.68, 0)),
		METAL_DARK,
		Enum.Material.Metal
	).CanCollide = false
	WorldKit.lamp(box, options or { generatorGated = true })
	return box
end

-- ============================================================ feature 1 ====
-- Per-counselor cabin furnishing: character props inside the four existing
-- cabins. Free floor lives in the front corners (bunks hug the side walls,
-- table sits center, dresser front-right, shelves on the back wall).

local function furnishCabins(dayCamp: Instance)
	for _, cabinName in { "PineCabin", "CreekCabin", "CounselorLodge", "SupplyCabin" } do
		local cabin = dayCamp:FindFirstChild(cabinName, true)
		if cabin then
			for _, floorName in { "Floor", "UpperFloorMain", "UpperFloorBack" } do
				local floor = cabin:FindFirstChild(floorName)
				if floor and floor:IsA("BasePart") then
					WorldKit.creakyFloor(floor)
				end
			end
		end
	end

	-- Small two-part desk used by several furnishings.
	local function propDesk(parent: Instance, name: string, position: Vector3): Part
		local top = WorldKit.part(parent, name .. "Top", Vector3.new(2.6, 0.3, 1.7),
			CFrame.new(position + Vector3.new(0, 2.05, 0)), WOOD_WARM, Enum.Material.WoodPlanks)
		WorldKit.part(parent, name .. "Base", Vector3.new(2.2, 1.6, 1.4),
			CFrame.new(position + Vector3.new(0, 1.15, 0)), WOOD_MID, Enum.Material.Wood)
		return top
	end

	-- Cabinet body + one WorldKit.drawer face sliding into the room (+Z).
	local function drawerCabinet(parent: Instance, name: string, position: Vector3)
		WorldKit.part(parent, name, Vector3.new(1.6, 2.1, 1.5),
			CFrame.new(position + Vector3.new(0, 1.55, 0)), WOOD_MID, Enum.Material.Wood)
		WorldKit.drawer(parent, name .. "Drawer", Vector3.new(1.4, 0.85, 0.35),
			CFrame.new(position + Vector3.new(0, 1.75, 0.8)), WOOD_DARK)
	end

	-- PineCabin — Counselor Holloway: trail maps wall + CB radio.
	local pine = WorldKit.model(dayCamp, "PineCabinProps")
	-- Anchors ride the lifted cabin bases (Pine +1.35, Creek/Lodge +1.5,
	-- Supply +2.15) so interior props stay seated on the raised floors.
	local pineP = Vector3.new(-54, 1.35, 18)
	for _, map in {
		{ offset = Vector3.new(5.2, 6.1, 7.1), text = "NORTH RIDGE TRAIL" },
		{ offset = Vector3.new(8.4, 5.7, 7.1), text = "LAKE LOOP — 2.1 MI" },
		{ offset = Vector3.new(6.8, 7.8, 7.1), text = "BLACK PINE SUMMIT" },
	} do
		local board = WorldKit.part(pine, "TrailMap", Vector3.new(2.3, 1.7, 0.18),
			CFrame.new(pineP + map.offset), Color3.fromRGB(196, 188, 158), Enum.Material.SmoothPlastic)
		board.CanCollide = false
		surfaceText(board, map.text, nil, Enum.NormalId.Front, 22)
	end
	local pineDesk = propDesk(pine, "RadioDesk", pineP + Vector3.new(-9.3, 0.5, -6.3))
	local cbRadio = WorldKit.part(pine, "CBRadio", Vector3.new(1.5, 1.0, 0.9),
		CFrame.new(pineP + Vector3.new(-9.3, 3.2, -6.5)), Color3.fromRGB(60, 66, 72), Enum.Material.Metal)
	surfaceText(cbRadio, "CB-9", LABEL_GOLD, Enum.NormalId.Front, 30)
	cyl(pine, "CBAntenna", Vector3.new(1.9, 0.09, 0.09),
		CFrame.new(pineP + Vector3.new(-9.9, 4.6, -6.7)) * CFrame.Angles(0, 0, math.rad(90)),
		METAL_DARK, Enum.Material.Metal).CanCollide = false
	WorldKit.part(pine, "CBMic", Vector3.new(0.25, 0.4, 0.22),
		CFrame.new(pineP + Vector3.new(-8.4, 2.45, -6.1)), METAL_DARK, Enum.Material.Metal)
		.CanCollide = false
	drawerCabinet(pine, "MapCabinet", pineP + Vector3.new(-6.9, 0.5, -6.8))
	local _ = pineDesk

	-- CreekCabin — Ivy Chen: botany presses, hanging plants, seed trays.
	local creek = WorldKit.model(dayCamp, "CreekCabinProps")
	local creekP = Vector3.new(54, 1.5, 18)
	propDesk(creek, "PottingBench", creekP + Vector3.new(-9.3, 0.5, -6.3))
	for trayIndex = 1, 3 do
		WorldKit.part(creek, "SeedTray" .. tostring(trayIndex),
			Vector3.new(0.85, 0.28, 0.65),
			CFrame.new(creekP + Vector3.new(-10.1 + (trayIndex - 1) * 0.95, 2.85, -6.3))
				* CFrame.Angles(0, math.rad(trayIndex * 7 - 12), 0),
			Color3.fromRGB(78, 96, 58), Enum.Material.Grass).CanCollide = false
	end
	for pressIndex = 1, 3 do
		WorldKit.part(creek, "BotanyPress" .. tostring(pressIndex),
			Vector3.new(1.3, 0.18, 1.6),
			CFrame.new(creekP + Vector3.new(5.5, 0.95 + pressIndex * 0.22, -6.5))
				* CFrame.Angles(0, math.rad(pressIndex * 9 - 14), 0),
			if pressIndex % 2 == 0 then PAPER else WOOD_WARM, Enum.Material.WoodPlanks)
			.CanCollide = false
	end
	for _, hangSpot in {
		Vector3.new(7, 0, 6.6),
		Vector3.new(4, 0, 6.9),
		Vector3.new(9.5, 0, 5.9),
	} do
		cyl(creek, "PlantChain", Vector3.new(2.2, 0.07, 0.07),
			CFrame.new(creekP + hangSpot + Vector3.new(0, 8.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			METAL_DARK, Enum.Material.Metal).CanCollide = false
		WorldKit.part(creek, "PlantPot", Vector3.new(0.75, 0.55, 0.75),
			CFrame.new(creekP + hangSpot + Vector3.new(0, 7.5, 0)),
			Color3.fromRGB(124, 78, 48), Enum.Material.SmoothPlastic).CanCollide = false
		local foliage = WorldKit.part(creek, "PlantFoliage", Vector3.new(1.3, 1.0, 1.3),
			CFrame.new(creekP + hangSpot + Vector3.new(0, 8.15, 0)),
			LEAF_GREEN, Enum.Material.Grass)
		foliage.Shape = Enum.PartType.Ball
		foliage.CanCollide = false
	end
	drawerCabinet(creek, "SpecimenCabinet", creekP + Vector3.new(3.6, 0.5, -6.8))

	-- SupplyCabin — quartermaster: clipboards, rope coils, crate stacks.
	local supply = WorldKit.model(dayCamp, "SupplyCabinProps")
	local supplyP = Vector3.new(-76, 2.15, -42)
	WorldKit.part(supply, "QMCrateA", Vector3.new(1.9, 1.9, 1.9),
		CFrame.new(supplyP + Vector3.new(-6.3, 1.45, -6.2)), WOOD_PLANK, Enum.Material.WoodPlanks)
	WorldKit.part(supply, "QMCrateB", Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(supplyP + Vector3.new(-4.6, 1.3, -6.5)) * CFrame.Angles(0, math.rad(-11), 0),
		WOOD_WARM, Enum.Material.WoodPlanks)
	WorldKit.part(supply, "QMCrateC", Vector3.new(1.5, 1.5, 1.5),
		CFrame.new(supplyP + Vector3.new(-6.2, 3.15, -6.2)) * CFrame.Angles(0, math.rad(15), 0),
		WOOD_PLANK, Enum.Material.WoodPlanks)
	for coilIndex, coilSpot in {
		Vector3.new(-5.4, 4.5, -7.2),
		Vector3.new(-7.1, 3.8, -7.2),
	} do
		cyl(supply, "RopeCoil" .. tostring(coilIndex), Vector3.new(0.4, 1.5, 1.5),
			CFrame.new(supplyP + coilSpot) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(168, 142, 96), Enum.Material.Fabric).CanCollide = false
	end
	for _, clip in {
		{ offset = Vector3.new(2.2, 5.1, 7.25), text = "INVENTORY — WK 6" },
		{ offset = Vector3.new(3.8, 5.6, 7.25), text = "LOAN LOG" },
		{ offset = Vector3.new(3.0, 4.3, 7.25), text = "SHORTAGES" },
	} do
		local board = WorldKit.part(supply, "Clipboard", Vector3.new(0.75, 1.05, 0.1),
			CFrame.new(supplyP + clip.offset), WOOD_DARK, Enum.Material.Wood)
		board.CanCollide = false
		surfaceText(board, clip.text, PAPER, Enum.NormalId.Front, 12)
	end
	drawerCabinet(supply, "LedgerCabinet", supplyP + Vector3.new(5, 0.5, -6.8))
end

-- ============================================================ feature 2 ====
-- Front gate + entrance: timber arch, gravel road, parked camp bus with an
-- open door and bench seats, and a luggage pile. Gate shifted to (70, ·, 58)
-- to clear the boathouse and canoe-carry station (see header).

local function buildFrontGate(dayCamp: Instance)
	local gate = WorldKit.model(dayCamp, "FrontGate")
	local gateOrigin = Vector3.new(70, 0, 58)
	local gateDir = Vector3.new(0.86, 0, 0.51).Unit
	local gateCF = CFrame.lookAt(gateOrigin, gateOrigin + gateDir)

	for side = -1, 1, 2 do
		WorldKit.part(gate, "GatePost", Vector3.new(1.4, 11, 1.4),
			gateCF * CFrame.new(side * 5.6, 6.0, 0), WOOD_MID, Enum.Material.Wood)
		WorldKit.part(gate, "GateBrace", Vector3.new(0.5, 3.4, 0.5),
			gateCF * CFrame.new(side * 4.3, 9.4, 0) * CFrame.Angles(0, 0, side * math.rad(38)),
			WOOD_DARK, Enum.Material.Wood)
		lanternBox(gate, (gateCF * CFrame.new(side * 5.6, 8.6, -0.9)).Position)
	end
	WorldKit.part(gate, "GateBeam", Vector3.new(13.8, 0.9, 0.9),
		gateCF * CFrame.new(0, 10.3, 0), WOOD_MID, Enum.Material.Wood)
	local signBoard = WorldKit.part(gate, "GateSign", Vector3.new(9.4, 2.0, 0.5),
		gateCF * CFrame.new(0, 11.6, 0), WOOD_DARK, Enum.Material.WoodPlanks)
	surfaceText(signBoard, "CAMP BLACK PINE", LABEL_GOLD, Enum.NormalId.Front)
	surfaceText(signBoard, "CAMP BLACK PINE", LABEL_GOLD, Enum.NormalId.Back)

	-- Short gravel road: one segment leading in, one leading out to the beach.
	for _, roadOffset in { -7, 7 } do
		WorldKit.part(gate, "GateRoad", Vector3.new(8, 0.25, 14),
			gateCF * CFrame.new(0, 0.64, roadOffset),
			Color3.fromRGB(117, 91, 64), Enum.Material.Ground).CanCollide = false
	end

	-- Parked camp bus, nose toward camp (arrived), rear toward the gate.
	local busOrigin = Vector3.new(52, 0, 65)
	local busCF = CFrame.lookAt(busOrigin, busOrigin + Vector3.new(-0.82, 0, -0.57))
	local chassis = WorldKit.part(gate, "BusChassis", Vector3.new(7, 0.5, 16),
		busCF * CFrame.new(0, 1.5, 0), METAL_DARK, Enum.Material.Metal)
	WorldKit.hidingSpot(chassis)
	WorldKit.part(gate, "BusWallLeft", Vector3.new(0.4, 4.6, 16),
		busCF * CFrame.new(-3.3, 4.05, 0), BUS_GREEN, Enum.Material.SmoothPlastic)
	-- Right side leaves a 3-stud door opening near the front.
	WorldKit.part(gate, "BusWallRightRear", Vector3.new(0.4, 4.6, 9.6),
		busCF * CFrame.new(3.3, 4.05, 3.2), BUS_GREEN, Enum.Material.SmoothPlastic)
	WorldKit.part(gate, "BusWallRightFront", Vector3.new(0.4, 4.6, 3.4),
		busCF * CFrame.new(3.3, 4.05, -6.3), BUS_GREEN, Enum.Material.SmoothPlastic)
	WorldKit.part(gate, "BusFrontPanel", Vector3.new(7, 2.2, 0.4),
		busCF * CFrame.new(0, 2.85, -8.2), BUS_GREEN, Enum.Material.SmoothPlastic)
	local windshield = WorldKit.part(gate, "BusWindshield", Vector3.new(6.6, 2.3, 0.3),
		busCF * CFrame.new(0, 5.1, -8.2), Color3.fromRGB(148, 190, 196), Enum.Material.Glass)
	windshield.Transparency = 0.35
	WorldKit.part(gate, "BusRearPanel", Vector3.new(7, 4.6, 0.4),
		busCF * CFrame.new(0, 4.05, 8.2), BUS_GREEN, Enum.Material.SmoothPlastic)
	WorldKit.part(gate, "BusRoof", Vector3.new(7.4, 0.4, 16.8),
		busCF * CFrame.new(0, 6.55, 0), Color3.fromRGB(214, 214, 206), Enum.Material.SmoothPlastic)
	local leftGlass = WorldKit.part(gate, "BusGlassLeft", Vector3.new(0.25, 1.9, 14),
		busCF * CFrame.new(-3.4, 5.15, 0), Color3.fromRGB(148, 190, 196), Enum.Material.Glass)
	leftGlass.Transparency = 0.4
	leftGlass.CanCollide = false
	local rightGlass = WorldKit.part(gate, "BusGlassRight", Vector3.new(0.25, 1.9, 9.4),
		busCF * CFrame.new(3.4, 5.15, 3.2), Color3.fromRGB(148, 190, 196), Enum.Material.Glass)
	rightGlass.Transparency = 0.4
	rightGlass.CanCollide = false
	local busSide = WorldKit.part(gate, "BusNameBoard", Vector3.new(0.1, 1.3, 9),
		busCF * CFrame.new(-3.55, 3.4, 0.5), BUS_GREEN, Enum.Material.SmoothPlastic)
	busSide.CanCollide = false
	surfaceText(busSide, "CAMP BLACK PINE", PAPER, Enum.NormalId.Left, 26)
	for _, wheelSpot in {
		Vector3.new(-3.2, 1.1, -5.5), Vector3.new(3.2, 1.1, -5.5),
		Vector3.new(-3.2, 1.1, 5.5), Vector3.new(3.2, 1.1, 5.5),
	} do
		cyl(gate, "BusWheel", Vector3.new(0.9, 2.2, 2.2),
			busCF * CFrame.new(wheelSpot) * CFrame.Angles(0, 0, 0),
			Color3.fromRGB(34, 34, 34), Enum.Material.SmoothPlastic).CanCollide = false
	end
	for benchIndex = 1, 3 do
		local benchZ = -3 + benchIndex * 3
		WorldKit.part(gate, "BusBench" .. tostring(benchIndex), Vector3.new(3.2, 0.5, 1.3),
			busCF * CFrame.new(-1.4, 2.3, benchZ), WOOD_WARM, Enum.Material.WoodPlanks)
		WorldKit.part(gate, "BusBenchBack" .. tostring(benchIndex), Vector3.new(3.2, 1.2, 0.25),
			busCF * CFrame.new(-1.4, 3.15, benchZ + 0.75), WOOD_MID, Enum.Material.WoodPlanks)
	end
	cyl(gate, "BusWheelSteer", Vector3.new(0.15, 1.1, 1.1),
		busCF * CFrame.new(-2.2, 3.4, -7.2) * CFrame.Angles(0, math.rad(90), math.rad(20)),
		METAL_DARK, Enum.Material.Metal).CanCollide = false
	WorldKit.part(gate, "BusStep", Vector3.new(2.4, 0.5, 1.2),
		busCF * CFrame.new(3.9, 0.9, -3.1), METAL_DARK, Enum.Material.Metal)

	-- Luggage pile on the camp side of the gate, tarped over (storm damage).
	local luggageOrigin = Vector3.new(58, 0, 47)
	local suitcaseColors = {
		Color3.fromRGB(112, 54, 44), Color3.fromRGB(64, 66, 108),
		Color3.fromRGB(105, 78, 48), Color3.fromRGB(58, 86, 64),
		Color3.fromRGB(124, 104, 78),
	}
	for caseIndex, caseColor in suitcaseColors do
		local layer = if caseIndex > 3 then 1 else 0
		local slot = if caseIndex > 3 then caseIndex - 4 else caseIndex - 1
		WorldKit.part(gate, "Suitcase" .. tostring(caseIndex),
			Vector3.new(2.2 - layer * 0.3, 1.3, 1.5),
			CFrame.new(luggageOrigin + Vector3.new(slot * 1.9 - 1.9 + layer * 0.7, 1.15 + layer * 1.3, (slot % 2) * 0.5))
				* CFrame.Angles(0, math.rad(caseIndex * 13 - 26), 0),
			caseColor, Enum.Material.Fabric)
	end
	cyl(gate, "DuffelBag", Vector3.new(2.4, 1.0, 1.0),
		CFrame.new(luggageOrigin + Vector3.new(0.4, 3.2, 0.3)) * CFrame.Angles(0, math.rad(24), 0),
		FOREST_GREEN, Enum.Material.Fabric).CanCollide = false
	local tarp = WorldKit.part(gate, "LuggageTarp", Vector3.new(5.6, 0.22, 4.6),
		CFrame.new(luggageOrigin + Vector3.new(0, 3.85, 0.2)) * CFrame.Angles(math.rad(6), math.rad(12), math.rad(-4)),
		CANVAS, Enum.Material.Fabric)
	tarp.CanCollide = false
	WorldKit.stormDamage(tarp)

	-- Fallen branch just outside the arch (storm damage).
	local branchCF = CFrame.new(66, 1.0, 68) * CFrame.Angles(0, math.rad(25), math.rad(4))
	local branchTrunk = cyl(gate, "FallenBranch", Vector3.new(7, 0.9, 0.9),
		branchCF, Color3.fromRGB(74, 58, 42), Enum.Material.Wood)
	WorldKit.stormDamage(branchTrunk)
	local branchOffshoot = cyl(gate, "FallenBranchLimb", Vector3.new(3, 0.45, 0.45),
		branchCF * CFrame.new(1.4, 0.3, 1.1) * CFrame.Angles(0, math.rad(40), math.rad(12)),
		Color3.fromRGB(74, 58, 42), Enum.Material.Wood)
	branchOffshoot.CanCollide = false
	WorldKit.stormDamage(branchOffshoot)
	local needles = WorldKit.part(gate, "FallenBranchNeedles", Vector3.new(2.4, 1.4, 2.4),
		branchCF * CFrame.new(3, 0.4, 0.6), Color3.fromRGB(43, 85, 57), Enum.Material.Grass)
	needles.Shape = Enum.PartType.Ball
	needles.CanCollide = false
	WorldKit.stormDamage(needles)
end

-- ============================================================ feature 3 ====
-- Signage system: fingerposts at path junctions + lantern posts along the
-- central path. Two suggested spots nudged off obstacles: (12,-28) dodges
-- ForestRock #11 at (13.5,-30.1); (-9,50) keeps clear of the path surface
-- (the suggested (5,50) sits on CampPath segment 2) and the trailclear props.

local function buildSignage(dayCamp: Instance)
	local signs = WorldKit.model(dayCamp, "CampSignage")
	local fingerposts: { { position: Vector3, lines: { string } } } = {
		{ position = Vector3.new(18, 0.5, 20), lines = { "Campfire", "Lake", "Lodge" } },
		{ position = Vector3.new(-18, 0.5, 12), lines = { "Cabins", "Firewood" } },
		{ position = Vector3.new(12, 0.5, -28), lines = { "Generator", "Supplies", "Ropes" } },
		{ position = Vector3.new(40, 0.5, 8), lines = { "Gate", "Marina" } },
		{ position = Vector3.new(-40, 0.5, 30), lines = { "Chapel", "Quarters" } },
		{ position = Vector3.new(-9, 0.5, 50), lines = { "Lodge", "Lookout" } },
	}
	for _, post in fingerposts do
		WorldKit.signpost(signs, post.position, post.lines)
	end

	-- Lantern posts along the central path edges (generator-gated light).
	local lanternSpots: { Vector3 } = {
		Vector3.new(11, 0, -52), Vector3.new(-11, 0, -40),
		Vector3.new(11, 0, -16), Vector3.new(-12, 0, -10),
		Vector3.new(11, 0, 16), Vector3.new(-13, 0, 30),
		Vector3.new(11, 0, 46), Vector3.new(-12, 0, 56),
	}
	for _, spot in lanternSpots do
		local towardPath = if spot.X > 0 then -1 else 1
		WorldKit.part(signs, "LanternPole", Vector3.new(0.45, 7, 0.45),
			CFrame.new(spot + Vector3.new(0, 4, 0)), WOOD_MID, Enum.Material.Wood)
		WorldKit.part(signs, "LanternArm", Vector3.new(1.6, 0.3, 0.3),
			CFrame.new(spot + Vector3.new(towardPath * 0.8, 7.2, 0)), WOOD_DARK, Enum.Material.Wood)
			.CanCollide = false
		lanternBox(signs, spot + Vector3.new(towardPath * 1.5, 6.5, 0))
	end
end

-- ============================================================ feature 4 ====
-- Campfire plaza: slate ring pavement, log benches outside the seat ring,
-- s'mores props, and string-light poles. Pavement rides at y 0.86 so its top
-- (0.92) clears the CampPath strips (tops at 0.81). Ring gaps are left where
-- the SupplyDropZone (10, ·, 10) sits.

local function buildCampfirePlaza(dayCamp: Instance)
	local plaza = WorldKit.model(dayCamp, "CampfirePlaza")

	for segmentIndex = 0, 13 do
		if segmentIndex == 1 or segmentIndex == 2 then
			-- Gap toward the SupplyDropZone at (10, ·, 10): reads as the
			-- walk-in to the drop platform and avoids covering its floor.
			continue
		end
		local angle = math.rad(12 + segmentIndex * (360 / 14))
		local position = FIRE_CENTER + Vector3.new(math.cos(angle) * 13.5, 0.86, math.sin(angle) * 13.5)
		local slab = WorldKit.part(plaza, "PlazaStone" .. tostring(segmentIndex),
			Vector3.new(5.7, 0.12, 4.6),
			CFrame.lookAt(position, Vector3.new(FIRE_CENTER.X, 0.86, FIRE_CENTER.Z)),
			SLATE, Enum.Material.Slate)
		slab.CanCollide = false
	end

	-- Log benches at radius 13, angled around the drop zone, the zipline
	-- landing (14, ·, -2) and the relocation clearing at (0, ·, 25).
	for _, benchAngle in { 10, 55, 125, 180, 235, 290 } do
		local angle = math.rad(benchAngle)
		local position = FIRE_CENTER + Vector3.new(math.cos(angle) * 13, 1.05, math.sin(angle) * 13)
		cyl(plaza, "LogBench", Vector3.new(4.6, 1.15, 1.15),
			CFrame.lookAt(position, Vector3.new(FIRE_CENTER.X, 1.05, FIRE_CENTER.Z))
				* CFrame.Angles(0, math.rad(90), 0),
			WOOD_MID, Enum.Material.Wood)
	end

	-- S'mores crate + marshmallow-stick barrel on the southwest edge.
	local snackSpot = FIRE_CENTER + Vector3.new(-14.3, 0, -8.3)
	local crate = WorldKit.part(plaza, "SmoresCrate", Vector3.new(2.1, 1.7, 2.1),
		CFrame.new(snackSpot + Vector3.new(0, 1.35, 0)) * CFrame.Angles(0, math.rad(18), 0),
		WOOD_PLANK, Enum.Material.WoodPlanks)
	surfaceText(crate, "S'MORES", LABEL_GOLD, Enum.NormalId.Front, 26)
	WorldKit.part(plaza, "SmoresLid", Vector3.new(2.2, 0.2, 2.2),
		CFrame.new(snackSpot + Vector3.new(0.5, 2.35, -0.4)) * CFrame.Angles(math.rad(-8), math.rad(30), 0),
		WOOD_WARM, Enum.Material.WoodPlanks).CanCollide = false
	cyl(plaza, "StickBarrel", Vector3.new(2.4, 1.9, 1.9),
		CFrame.new(snackSpot + Vector3.new(2.4, 1.7, 0.6)) * CFrame.Angles(0, 0, math.rad(90)),
		WOOD_MID, Enum.Material.Wood)
	for stickIndex = 1, 3 do
		cyl(plaza, "MarshmallowStick" .. tostring(stickIndex), Vector3.new(2.8, 0.12, 0.12),
			CFrame.new(snackSpot + Vector3.new(2.4 + stickIndex * 0.2 - 0.4, 3.1, 0.4 + stickIndex * 0.2))
				* CFrame.Angles(math.rad(stickIndex * 16), math.rad(stickIndex * 40), math.rad(64)),
			Color3.fromRGB(148, 116, 78), Enum.Material.Wood).CanCollide = false
	end

	-- String-light poles + catenary strings with generator-gated fairy lamps.
	local poleAngles = { 5, 145, 215, 325 }
	local poleTops: { Vector3 } = {}
	for _, poleAngle in poleAngles do
		local angle = math.rad(poleAngle)
		local basePosition = FIRE_CENTER + Vector3.new(math.cos(angle) * 15, 0, math.sin(angle) * 15)
		WorldKit.part(plaza, "StringPole", Vector3.new(0.5, 8.6, 0.5),
			CFrame.new(basePosition + Vector3.new(0, 4.8, 0)), WOOD_MID, Enum.Material.Wood)
		table.insert(poleTops, basePosition + Vector3.new(0, 9.0, 0))
	end
	local spans = { { 4, 1 }, { 2, 3 }, { 3, 4 } }
	for _, span in spans do
		local fromTop = poleTops[span[1]]
		local toTop = poleTops[span[2]]
		local knotA = fromTop:Lerp(toTop, 1 / 3) - Vector3.new(0, 1.2, 0)
		local knotB = fromTop:Lerp(toTop, 2 / 3) - Vector3.new(0, 1.2, 0)
		local points = { fromTop, knotA, knotB, toTop }
		for segment = 1, 3 do
			local a = points[segment]
			local b = points[segment + 1]
			local mid = a:Lerp(b, 0.5)
			local wire = cyl(plaza, "LightString", Vector3.new((b - a).Magnitude, 0.12, 0.12),
				CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0),
				WOOD_DARK, Enum.Material.Fabric)
			wire.CanCollide = false
		end
		for _, hangPoint in { knotA, knotA:Lerp(knotB, 0.5), knotB } do
			local bulb = WorldKit.part(plaza, "StringLamp", Vector3.new(0.55, 0.7, 0.55),
				CFrame.new(hangPoint - Vector3.new(0, 0.5, 0)), LANTERN_AMBER, Enum.Material.Glass)
			bulb.Transparency = 0.25
			bulb.CanCollide = false
			WorldKit.lamp(bulb, { generatorGated = true, range = 10, brightness = 0.8 })
		end
	end
end

-- ============================================================ feature 5 ====
-- Ropes aerial circuit: balance beam, swing-step planks and a cargo-net wall
-- extending north (+Z) from the existing completion platform at (58,16.4,-44),
-- ending in a cosmetic zipline down to a landing pad beside the plaza. The
-- "ride" is a server-side PivotTo after a short wait — no scripted movement.

local function buildAerialCircuit(dayCamp: Instance)
	local circuit = WorldKit.model(dayCamp, "AerialCircuit")
	local ropeColor = Color3.fromRGB(168, 142, 96)

	-- Balance beam north from the platform (players hop the north rail).
	WorldKit.part(circuit, "AerialBeam", Vector3.new(1.1, 0.4, 9.5),
		CFrame.new(58, 15.2, -35.5), WOOD_WARM, Enum.Material.WoodPlanks)
	WorldKit.part(circuit, "AerialBeamPost", Vector3.new(0.55, 19, 0.55),
		CFrame.new(59, 10, -30.6), WOOD_MID, Enum.Material.Wood)

	-- Overhead support cable for the swing steps.
	cyl(circuit, "SwingCable", Vector3.new(11, 0.15, 0.15),
		CFrame.new(58, 19.4, -25.5) * CFrame.Angles(0, math.rad(90), 0),
		ropeColor, Enum.Material.Fabric).CanCollide = false
	local swingSpots = {
		Vector3.new(57.3, 15.3, -29.4),
		Vector3.new(58.7, 15.3, -27.2),
		Vector3.new(57.3, 15.3, -25.0),
		Vector3.new(58, 15.3, -23.0),
	}
	for swingIndex, swingSpot in swingSpots do
		WorldKit.part(circuit, "SwingPlank" .. tostring(swingIndex), Vector3.new(2.2, 0.3, 1.6),
			CFrame.new(swingSpot), WOOD_WARM, Enum.Material.WoodPlanks)
		cyl(circuit, "SwingRope" .. tostring(swingIndex), Vector3.new(3.9, 0.07, 0.07),
			CFrame.new(swingSpot.X, 17.35, swingSpot.Z) * CFrame.Angles(0, 0, math.rad(90)),
			ropeColor, Enum.Material.Fabric).CanCollide = false
	end

	-- Cargo-net wall (thin crossed parts) flanking the final approach plank.
	for _, netPostZ in { -24.2, -20.2 } do
		WorldKit.part(circuit, "NetPost", Vector3.new(0.3, 5.4, 0.3),
			CFrame.new(56.2, 15.6, netPostZ), WOOD_MID, Enum.Material.Wood)
	end
	for lineIndex = 0, 3 do
		WorldKit.part(circuit, "NetLineH" .. tostring(lineIndex), Vector3.new(0.15, 0.15, 4.0),
			CFrame.new(56.2, 14 + lineIndex * 1.2, -22.2), ropeColor, Enum.Material.Fabric)
			.CanCollide = false
		WorldKit.part(circuit, "NetLineV" .. tostring(lineIndex), Vector3.new(0.15, 5.0, 0.15),
			CFrame.new(56.25, 15.6, -23.6 + lineIndex * 0.9), ropeColor, Enum.Material.Fabric)
			.CanCollide = false
	end
	WorldKit.part(circuit, "ApproachPlank", Vector3.new(1.8, 0.35, 3.6),
		CFrame.new(58, 15.3, -21.6), WOOD_WARM, Enum.Material.WoodPlanks)

	-- Zipline start deck + mast.
	WorldKit.part(circuit, "ZipDeck", Vector3.new(4.5, 0.5, 4.5),
		CFrame.new(58, 16.1, -19.6), WOOD_PLANK, Enum.Material.WoodPlanks)
	WorldKit.part(circuit, "ZipMast", Vector3.new(0.6, 4.2, 0.6),
		CFrame.new(58, 18.3, -18.5), WOOD_MID, Enum.Material.Wood)
	WorldKit.part(circuit, "ZipMastArm", Vector3.new(0.25, 0.25, 1.8),
		CFrame.new(58, 18, -19.3), WOOD_DARK, Enum.Material.Wood).CanCollide = false
	local anchor = WorldKit.part(circuit, "ZipAnchor", Vector3.new(0.7, 0.7, 0.7),
		CFrame.new(58, 18, -20), METAL_DARK, Enum.Material.Metal)
	anchor.CanCollide = false

	-- The cable itself: (58,18,-20) down to the landing pad at (14,3,-2).
	local cableFrom = Vector3.new(58, 18, -20)
	local cableTo = Vector3.new(14, 3, -2)
	local cableMid = cableFrom:Lerp(cableTo, 0.5)
	local cable = cyl(circuit, "ZipCable", Vector3.new((cableTo - cableFrom).Magnitude, 0.18, 0.18),
		CFrame.lookAt(cableMid, cableTo) * CFrame.Angles(0, math.rad(90), 0),
		METAL_DARK, Enum.Material.Metal)
	cable.CanCollide = false

	-- Landing pad near the plaza, with an A-frame catching the cable end.
	WorldKit.part(circuit, "ZipLandingPad", Vector3.new(4.4, 0.6, 4.4),
		CFrame.new(14, 0.85, -2), WOOD_PLANK, Enum.Material.WoodPlanks)
	WorldKit.part(circuit, "ZipLandingMat", Vector3.new(3.6, 0.2, 3.6),
		CFrame.new(14, 1.25, -1.6), CANVAS, Enum.Material.Fabric).CanCollide = false
	for side = -1, 1, 2 do
		WorldKit.part(circuit, "ZipCatchLeg", Vector3.new(0.4, 3.4, 0.4),
			CFrame.new(14 + side * 1.3, 1.9, -3.3) * CFrame.Angles(0, 0, side * math.rad(-24)),
			WOOD_MID, Enum.Material.Wood)
	end

	local whoosh = attachSound(cable, "ZipWhoosh", "ZiplineWhooshAssetId",
		"rbxassetid://12222095", 0.7, 0.9) -- placeholder: replace with final asset
	local prompt = WorldKit.prompt(anchor, "Grab Line", "Zipline", 0.25)
	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		if not character then
			return
		end
		whoosh:Play()
		task.wait(1.2)
		character = player.Character
		if character and character.Parent then
			character:PivotTo(CFrame.new(14, 4.6, -1) * CFrame.Angles(0, math.rad(160), 0))
		end
	end)
end

-- ============================================================ feature 6 ====
-- Lodge hub, in the back half of the CounselorLodge interior: job notice
-- board, camp roster wall, trophy shelf and a map table with a drawer.

local function buildLodgeHub(dayCamp: Instance)
	local hub = WorldKit.model(dayCamp, "LodgeHub")
	local lodgeP = Vector3.new(0, 1.5, 74)

	-- Job notice board on the back wall (right of the existing duty roster).
	local jobBoard = WorldKit.part(hub, "JobBoard", Vector3.new(4.4, 3.1, 0.25),
		CFrame.new(lodgeP + Vector3.new(2.5, 6.1, 7.2)), Color3.fromRGB(140, 102, 64),
		Enum.Material.Fabric)
	jobBoard.CanCollide = false
	surfaceText(jobBoard, "CAMP JOBS", LABEL_GOLD, Enum.NormalId.Front, 20)
	for noteIndex, note in {
		"K.P. DUTY\n— Brooks",
		"LIFEGUARD ROTA\n— Vale",
		"FIREWOOD RUN\n— Pike",
	} do
		local pin = WorldKit.part(hub, "JobNote" .. tostring(noteIndex),
			Vector3.new(1.15, 1.4, 0.08),
			CFrame.new(lodgeP + Vector3.new(1.1 + (noteIndex - 1) * 1.45, 5.7 + (noteIndex % 2) * 0.5, 7.02))
				* CFrame.Angles(0, 0, math.rad(noteIndex * 5 - 10)),
			PAPER, Enum.Material.SmoothPlastic)
		pin.CanCollide = false
		surfaceText(pin, note, nil, Enum.NormalId.Front, 12)
	end

	-- Camp roster wall: 12 portrait frames along the east wall.
	local rosterNames = {
		"Counselor Holloway", "Ivy Chen", "Tessa Brooks", "Rowan Pike",
		"Eli Mercer", "Beck Wilder", "Mara Stone", "Jamie Vale",
		"Noah Finch", "Lena Ortiz", "Sloane Rivers", "YOU?",
	}
	local rosterColors = {
		Color3.fromRGB(120, 88, 56), Color3.fromRGB(96, 128, 88),
		Color3.fromRGB(168, 128, 96), Color3.fromRGB(88, 104, 132),
		Color3.fromRGB(140, 108, 72), Color3.fromRGB(104, 88, 120),
		Color3.fromRGB(128, 96, 88), Color3.fromRGB(88, 120, 120),
		Color3.fromRGB(152, 136, 96), Color3.fromRGB(112, 120, 88),
		Color3.fromRGB(96, 96, 108), Color3.fromRGB(52, 52, 52),
	}
	for rosterIndex, rosterName in rosterNames do
		local row = if rosterIndex > 6 then 1 else 0
		local column = if rosterIndex > 6 then rosterIndex - 7 else rosterIndex - 1
		local frame = WorldKit.part(hub, "RosterFrame" .. tostring(rosterIndex),
			Vector3.new(0.15, 1.55, 1.55),
			CFrame.new(lodgeP + Vector3.new(14.15, 7.0 - row * 1.9, -5.5 + column * 2.2)),
			rosterColors[rosterIndex], Enum.Material.SmoothPlastic)
		frame.CanCollide = false
		surfaceText(frame, rosterName, PAPER, Enum.NormalId.Left, 11)
	end

	-- Trophy shelf on the back wall.
	WorldKit.part(hub, "TrophyShelf", Vector3.new(3.6, 0.25, 1.1),
		CFrame.new(lodgeP + Vector3.new(10.5, 5.7, 7.0)), WOOD_DARK, Enum.Material.WoodPlanks)
	for trophyIndex = 1, 3 do
		local trophyX = 9.4 + (trophyIndex - 1) * 1.1
		cyl(hub, "TrophyBase" .. tostring(trophyIndex), Vector3.new(0.55, 0.7, 0.7),
			CFrame.new(lodgeP + Vector3.new(trophyX, 6.1, 7.0)) * CFrame.Angles(0, 0, math.rad(90)),
			WOOD_MID, Enum.Material.Wood).CanCollide = false
		local cup = WorldKit.part(hub, "TrophyCup" .. tostring(trophyIndex),
			Vector3.new(0.6, 0.65, 0.6),
			CFrame.new(lodgeP + Vector3.new(trophyX, 6.75, 7.0)),
			Color3.fromRGB(198, 165, 32), Enum.Material.Metal)
		cup.Shape = Enum.PartType.Ball
		cup.CanCollide = false
	end

	-- Map table with the lodge's WorldKit drawer and a camp-map SurfaceGui.
	local mapTop = WorldKit.part(hub, "MapTableTop", Vector3.new(4, 0.4, 3),
		CFrame.new(lodgeP + Vector3.new(6, 3.1, 5)), WOOD_WARM, Enum.Material.WoodPlanks)
	WorldKit.part(hub, "MapTableBase", Vector3.new(3.2, 2.4, 2.2),
		CFrame.new(lodgeP + Vector3.new(6, 1.7, 5)), WOOD_MID, Enum.Material.Wood)
	WorldKit.drawer(hub, "MapTableDrawer", Vector3.new(1.6, 0.8, 0.35),
		CFrame.new(lodgeP + Vector3.new(6, 2.1, 3.75)) * CFrame.Angles(0, math.rad(180), 0),
		WOOD_DARK)
	local mapGui = Instance.new("SurfaceGui")
	mapGui.Face = Enum.NormalId.Top
	mapGui.CanvasSize = Vector2.new(400, 300)
	mapGui.Parent = mapTop
	local mapBackground = Instance.new("Frame")
	mapBackground.BackgroundColor3 = Color3.fromRGB(78, 104, 72)
	mapBackground.BorderSizePixel = 0
	mapBackground.Size = UDim2.fromScale(1, 1)
	mapBackground.Parent = mapGui
	local lakeShape = Instance.new("Frame")
	lakeShape.BackgroundColor3 = Color3.fromRGB(74, 116, 138)
	lakeShape.BorderSizePixel = 0
	lakeShape.Position = UDim2.fromScale(0.74, 0.1)
	lakeShape.Size = UDim2.fromScale(0.26, 0.8)
	lakeShape.Parent = mapBackground
	for _, cabinSpot in {
		UDim2.fromScale(0.18, 0.32), UDim2.fromScale(0.6, 0.32),
		UDim2.fromScale(0.4, 0.72), UDim2.fromScale(0.1, 0.12),
	} do
		local square = Instance.new("Frame")
		square.BackgroundColor3 = Color3.fromRGB(150, 122, 86)
		square.BorderSizePixel = 0
		square.Position = cabinSpot
		square.Size = UDim2.fromOffset(28, 22)
		square.Parent = mapBackground
	end
	local fireDot = Instance.new("Frame")
	fireDot.BackgroundColor3 = Color3.fromRGB(198, 92, 48)
	fireDot.BorderSizePixel = 0
	fireDot.Position = UDim2.fromScale(0.44, 0.44)
	fireDot.Size = UDim2.fromOffset(20, 20)
	fireDot.Parent = mapBackground
	local fireCorner = Instance.new("UICorner")
	fireCorner.CornerRadius = UDim.new(1, 0)
	fireCorner.Parent = fireDot
	local mapTitle = Instance.new("TextLabel")
	mapTitle.BackgroundTransparency = 1
	mapTitle.Position = UDim2.fromScale(0.02, 0.02)
	mapTitle.Size = UDim2.fromScale(0.7, 0.14)
	mapTitle.Font = Enum.Font.SpecialElite
	mapTitle.Text = "CAMP BLACK PINE — GROUNDS"
	mapTitle.TextColor3 = PAPER
	mapTitle.TextScaled = true
	mapTitle.TextXAlignment = Enum.TextXAlignment.Left
	mapTitle.Parent = mapBackground
end

-- ============================================================ feature 7 ====
-- Outhouse row + shower block northwest of the lodge, tucked between the
-- chapel keep-clear zone (-30, ·, 55) and the lodge porch (x -14..14).

local function buildSanitationRow(dayCamp: Instance)
	local sanitation = WorldKit.model(dayCamp, "SanitationRow")

	for outhouseIndex, outhouseX in { -20, -24, -28 } do
		local suffix = tostring(outhouseIndex)
		-- Camp-bowl grass sits at ~2.5, not 0: lift the floor above grade so
		-- the doorway keeps full headroom from the outside approach.
		local base = Vector3.new(outhouseX, 2, 68.5)
		local floor = WorldKit.part(sanitation, "OuthouseFloor" .. suffix, Vector3.new(3, 0.4, 3),
			CFrame.new(base + Vector3.new(0, 0.9, 0)), WOOD_FLOOR, Enum.Material.WoodPlanks)
		WorldKit.creakyFloor(floor)
		WorldKit.hidingSpot(floor)
		WorldKit.part(sanitation, "OuthouseBack" .. suffix, Vector3.new(3, 6.4, 0.3),
			CFrame.new(base + Vector3.new(0, 4.1, 1.35)), WOOD_WALL, Enum.Material.WoodPlanks)
		for side = -1, 1, 2 do
			WorldKit.part(sanitation, "OuthouseSide" .. suffix, Vector3.new(0.3, 6.4, 3),
				CFrame.new(base + Vector3.new(side * 1.35, 4.1, 0)), WOOD_WALL, Enum.Material.WoodPlanks)
		end
		WorldKit.part(sanitation, "OuthouseHeader" .. suffix, Vector3.new(3, 0.5, 0.3),
			CFrame.new(base + Vector3.new(0, 7.05, -1.35)), WOOD_WALL, Enum.Material.WoodPlanks)
		WorldKit.part(sanitation, "OuthouseRoof" .. suffix, Vector3.new(3.6, 0.3, 3.9),
			CFrame.new(base + Vector3.new(0, 7.6, 0.1)) * CFrame.Angles(math.rad(-8), 0, 0),
			TIN_ROOF, Enum.Material.CorrodedMetal)
		local door = WorldKit.hingedDoor(sanitation, "OuthouseDoor" .. suffix,
			Vector3.new(2.2, 5.6, 0.25),
			CFrame.new(base + Vector3.new(0, 3.9, -1.42)), WOOD_MID)
		-- Crescent-moon cutout: pale disc with an offset door-colored overlap.
		cyl(sanitation, "MoonDisc" .. suffix, Vector3.new(0.1, 0.7, 0.7),
			CFrame.new(base + Vector3.new(0, 5.2, -1.62)) * CFrame.Angles(0, math.rad(90), 0),
			PAPER, Enum.Material.SmoothPlastic).CanCollide = false
		cyl(sanitation, "MoonShade" .. suffix, Vector3.new(0.12, 0.58, 0.58),
			CFrame.new(base + Vector3.new(0.18, 5.28, -1.63)) * CFrame.Angles(0, math.rad(90), 0),
			WOOD_MID, Enum.Material.SmoothPlastic).CanCollide = false
		WorldKit.part(sanitation, "OuthouseBench" .. suffix, Vector3.new(2.6, 1.5, 1.2),
			CFrame.new(base + Vector3.new(0, 1.85, 0.65)), WOOD_WARM, Enum.Material.WoodPlanks)
		lanternBox(sanitation, base + Vector3.new(0, 6.4, 0.6), { generatorGated = true, range = 9, brightness = 0.9 })
		local _ = door
	end

	-- Four-stall shower block, entrance facing east toward the lodge path.
	-- Lifted so the concrete pad sits at the rendered surface (~2.5)
	-- instead of 1.8 studs under the grass.
	local blockBase = Vector3.new(-19.5, 1.8, 61.5)
	local showerFloor = WorldKit.part(sanitation, "ShowerFloor", Vector3.new(5, 0.4, 8),
		CFrame.new(blockBase + Vector3.new(0, 0.9, 0)), Color3.fromRGB(126, 126, 118),
		Enum.Material.Concrete)
	WorldKit.part(sanitation, "ShowerBack", Vector3.new(0.3, 6.8, 8),
		CFrame.new(blockBase + Vector3.new(-2.35, 4.3, 0)), WOOD_WALL, Enum.Material.WoodPlanks)
	for side = -1, 1, 2 do
		WorldKit.part(sanitation, "ShowerEnd", Vector3.new(5, 6.8, 0.3),
			CFrame.new(blockBase + Vector3.new(0, 4.3, side * 3.85)), WOOD_WALL,
			Enum.Material.WoodPlanks)
	end
	WorldKit.part(sanitation, "ShowerRoof", Vector3.new(5.8, 0.3, 8.8),
		CFrame.new(blockBase + Vector3.new(-0.2, 7.9, 0)) * CFrame.Angles(0, 0, math.rad(7)),
		TIN_ROOF, Enum.Material.CorrodedMetal)
	local showerSign = WorldKit.part(sanitation, "ShowerSign", Vector3.new(0.2, 1.0, 3.2),
		CFrame.new(blockBase + Vector3.new(2.55, 6.2, 0)), WOOD_DARK, Enum.Material.Wood)
	showerSign.CanCollide = false
	surfaceText(showerSign, "SHOWERS", LABEL_GOLD, Enum.NormalId.Right, 24)
	for partitionIndex = 1, 3 do
		WorldKit.part(sanitation, "ShowerPartition" .. tostring(partitionIndex),
			Vector3.new(3.4, 5, 0.25),
			CFrame.new(blockBase + Vector3.new(-0.65, 3.4, -1.85 + (partitionIndex - 1) * 1.85)),
			WOOD_WARM, Enum.Material.WoodPlanks)
	end
	for stallIndex = 1, 4 do
		local stallZ = -2.8 + (stallIndex - 1) * 1.85
		cyl(sanitation, "ShowerRiser" .. tostring(stallIndex), Vector3.new(2.6, 0.18, 0.18),
			CFrame.new(blockBase + Vector3.new(-2.1, 5.3, stallZ)) * CFrame.Angles(0, 0, math.rad(90)),
			METAL_DARK, Enum.Material.Metal).CanCollide = false
		cyl(sanitation, "ShowerElbow" .. tostring(stallIndex), Vector3.new(0.9, 0.18, 0.18),
			CFrame.new(blockBase + Vector3.new(-1.6, 6.55, stallZ)),
			METAL_DARK, Enum.Material.Metal).CanCollide = false
		cyl(sanitation, "ShowerHead" .. tostring(stallIndex), Vector3.new(0.14, 0.5, 0.5),
			CFrame.new(blockBase + Vector3.new(-1.1, 6.4, stallZ)) * CFrame.Angles(0, 0, math.rad(58)),
			Color3.fromRGB(174, 178, 182), Enum.Material.Metal).CanCollide = false
	end
	WorldKit.part(sanitation, "ShowerDrain", Vector3.new(1.2, 0.06, 1.2),
		CFrame.new(blockBase + Vector3.new(-0.6, 1.14, 0)), METAL_DARK, Enum.Material.DiamondPlate)
		.CanCollide = false
	-- Hiding spot in the last (south) stall.
	local stallMat = WorldKit.part(sanitation, "ShowerStallMat", Vector3.new(1.6, 0.08, 1.5),
		CFrame.new(blockBase + Vector3.new(-1.2, 1.15, -3.0)), CANVAS, Enum.Material.Fabric)
	stallMat.CanCollide = false
	WorldKit.hidingSpot(stallMat)
	lanternBox(sanitation, blockBase + Vector3.new(0.6, 6.6, 0), { generatorGated = true, range = 11 })
	local _ = showerFloor
end

-- ============================================================ feature 8 ====
-- Counselor's quarters: six tiny personal cabins arcing northwest of camp,
-- between the chapel and Cabin Zero keep-clear zones. Doors face the camp.

type QuartersSpec = {
	label: string,
	position: Vector3,
}

local function buildCounselorQuarters(dayCamp: Instance): Vector3
	local quarters = WorldKit.model(dayCamp, "CounselorQuarters")
	-- Base Y lifts each floor above the camp-bowl grade (~2.5; FINCH sits on
	-- a 4-stud rise) so doorways keep full headroom from the outside.
	local specs: { QuartersSpec } = {
		{ label = "HOLLOWAY", position = Vector3.new(-37, 2, 67) },
		{ label = "ORTIZ", position = Vector3.new(-44, 2, 70.5) },
		{ label = "REED", position = Vector3.new(-51, 2, 72) },
		{ label = "BROOKS", position = Vector3.new(-58, 2, 73) },
		{ label = "CHEN", position = Vector3.new(-64.5, 2, 70) },
		{ label = "FINCH", position = Vector3.new(-69.5, 3.5, 63.5) },
	}
	local reedFootlocker = Vector3.zero
	for cabinIndex, spec in specs do
		local suffix = tostring(cabinIndex)
		local base = spec.position
		local floor = WorldKit.part(quarters, "QuartersFloor" .. suffix, Vector3.new(6, 0.5, 7),
			CFrame.new(base + Vector3.new(0, 0.85, 0)), WOOD_FLOOR, Enum.Material.WoodPlanks)
		WorldKit.creakyFloor(floor)
		WorldKit.part(quarters, "QuartersBack" .. suffix, Vector3.new(6, 6.5, 0.4),
			CFrame.new(base + Vector3.new(0, 4.35, 3.3)), WOOD_WALL, Enum.Material.WoodPlanks)
		for side = -1, 1, 2 do
			WorldKit.part(quarters, "QuartersSide" .. suffix, Vector3.new(0.4, 6.5, 7),
				CFrame.new(base + Vector3.new(side * 2.8, 4.35, 0)), WOOD_WALL,
				Enum.Material.WoodPlanks)
			WorldKit.part(quarters, "QuartersFront" .. suffix, Vector3.new(1.75, 6.5, 0.4),
				CFrame.new(base + Vector3.new(side * 2.15, 4.35, -3.3)), WOOD_WALL,
				Enum.Material.WoodPlanks)
		end
		local header = WorldKit.part(quarters, "QuartersHeader" .. suffix, Vector3.new(2.6, 0.7, 0.4),
			CFrame.new(base + Vector3.new(0, 7.25, -3.3)), WOOD_WALL, Enum.Material.WoodPlanks)
		WorldKit.billboardLabel(header, spec.label)
		WorldKit.part(quarters, "QuartersRoof" .. suffix, Vector3.new(7, 0.35, 8.6),
			CFrame.new(base + Vector3.new(0, 8.1, 0.2)) * CFrame.Angles(math.rad(-9), 0, 0),
			TIN_ROOF, Enum.Material.CorrodedMetal)
		WorldKit.hingedDoor(quarters, "QuartersDoor" .. suffix, Vector3.new(2.2, 5.5, 0.3),
			CFrame.new(base + Vector3.new(0, 3.95, -3.4)), WOOD_MID)
		-- Cot with a canvas mattress along the west wall.
		WorldKit.part(quarters, "QuartersCot" .. suffix, Vector3.new(2, 0.7, 4.2),
			CFrame.new(base + Vector3.new(-1.75, 1.55, 0.4)), WOOD_MID, Enum.Material.Wood)
		local mattress = WorldKit.part(quarters, "QuartersMattress" .. suffix,
			Vector3.new(1.9, 0.4, 4.0),
			CFrame.new(base + Vector3.new(-1.75, 2.1, 0.4)), CANVAS, Enum.Material.Fabric)
		mattress.CanCollide = false
		local footlockerPosition = base + Vector3.new(-1.7, 1.6, 2.5)
		WorldKit.part(quarters, "QuartersFootlocker" .. suffix, Vector3.new(1.8, 1.0, 1.1),
			CFrame.new(footlockerPosition), WOOD_DARK, Enum.Material.WoodPlanks)
		WorldKit.part(quarters, "QuartersShelf" .. suffix, Vector3.new(1.6, 0.25, 0.9),
			CFrame.new(base + Vector3.new(2.25, 4.3, 1.5)), WOOD_DARK, Enum.Material.WoodPlanks)
			.CanCollide = false
		if spec.label == "REED" then
			reedFootlocker = footlockerPosition + Vector3.new(0, 0.5, 0)
		end

		-- One personality prop per cabin.
		if spec.label == "HOLLOWAY" then
			cyl(quarters, "PropCoffeePot", Vector3.new(1.0, 0.7, 0.7),
				CFrame.new(base + Vector3.new(-1.7, 2.6, 2.5)) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(96, 108, 116), Enum.Material.Metal).CanCollide = false
			cyl(quarters, "PropPotSpout", Vector3.new(0.5, 0.12, 0.12),
				CFrame.new(base + Vector3.new(-1.35, 2.75, 2.7)) * CFrame.Angles(0, 0, math.rad(30)),
				Color3.fromRGB(96, 108, 116), Enum.Material.Metal).CanCollide = false
		elseif spec.label == "ORTIZ" then
			WorldKit.part(quarters, "PropGuitarBody", Vector3.new(1.1, 1.4, 0.35),
				CFrame.new(base + Vector3.new(2.2, 1.85, -1.6)) * CFrame.Angles(math.rad(-10), math.rad(14), 0),
				WOOD_WARM, Enum.Material.Wood).CanCollide = false
			WorldKit.part(quarters, "PropGuitarNeck", Vector3.new(0.25, 1.5, 0.15),
				CFrame.new(base + Vector3.new(2.35, 3.2, -1.75)) * CFrame.Angles(math.rad(-10), math.rad(14), 0),
				WOOD_DARK, Enum.Material.Wood).CanCollide = false
		elseif spec.label == "REED" then
			WorldKit.part(quarters, "PropJournalStack", Vector3.new(0.9, 0.55, 1.2),
				CFrame.new(base + Vector3.new(2.25, 4.7, 1.5)), Color3.fromRGB(112, 54, 44),
				Enum.Material.SmoothPlastic).CanCollide = false
			WorldKit.part(quarters, "PropOpenJournal", Vector3.new(1.0, 0.08, 1.3),
				CFrame.new(base + Vector3.new(-1.7, 2.35, 0)), PAPER,
				Enum.Material.SmoothPlastic).CanCollide = false
		elseif spec.label == "BROOKS" then
			cyl(quarters, "PropFloatRing", Vector3.new(0.3, 1.5, 1.5),
				CFrame.new(base + Vector3.new(2.3, 1.6, 0.6)) * CFrame.Angles(0, math.rad(90), math.rad(8)),
				Color3.fromRGB(198, 92, 48), Enum.Material.SmoothPlastic).CanCollide = false
		elseif spec.label == "CHEN" then
			WorldKit.part(quarters, "PropFernPot", Vector3.new(0.6, 0.5, 0.6),
				CFrame.new(base + Vector3.new(2.25, 4.65, 1.5)), Color3.fromRGB(124, 78, 48),
				Enum.Material.SmoothPlastic).CanCollide = false
			local fern = WorldKit.part(quarters, "PropFern", Vector3.new(1.1, 0.9, 1.1),
				CFrame.new(base + Vector3.new(2.25, 5.3, 1.5)), LEAF_GREEN, Enum.Material.Grass)
			fern.Shape = Enum.PartType.Ball
			fern.CanCollide = false
		elseif spec.label == "FINCH" then
			for lens = -1, 1, 2 do
				cyl(quarters, "PropBinoculars", Vector3.new(0.7, 0.28, 0.28),
					CFrame.new(base + Vector3.new(2.1 + lens * 0.16, 4.6, 1.3))
						* CFrame.Angles(0, math.rad(90), math.rad(76)),
					METAL_DARK, Enum.Material.Metal).CanCollide = false
			end
		end
	end
	return reedFootlocker
end

-- ============================================================ feature 9 ====
-- Infirmary: small cabin with cots, medicine cabinet, logbook desk and a red
-- cross sign. Shifted to (27, ·, 61) — see header.

local function buildInfirmary(dayCamp: Instance): Vector3
	local infirmary = WorldKit.model(dayCamp, "Infirmary")
	-- Lifted above the ~2.5 camp-bowl grade so the west doorway keeps full
	-- headroom from the outside approach.
	local base = Vector3.new(27, 2, 61)

	local floor = WorldKit.part(infirmary, "InfirmaryFloor", Vector3.new(10, 0.6, 12),
		CFrame.new(base + Vector3.new(0, 0.8, 0)), WOOD_FLOOR, Enum.Material.WoodPlanks)
	WorldKit.creakyFloor(floor)
	WorldKit.part(infirmary, "InfirmaryEastWall", Vector3.new(0.5, 7.5, 12),
		CFrame.new(base + Vector3.new(4.75, 4.85, 0)), WOOD_WALL, Enum.Material.WoodPlanks)
	for side = -1, 1, 2 do
		WorldKit.part(infirmary, "InfirmaryEndWall", Vector3.new(10, 7.5, 0.5),
			CFrame.new(base + Vector3.new(0, 4.85, side * 5.75)), WOOD_WALL,
			Enum.Material.WoodPlanks)
		-- West wall pieces leave a 3.5-stud door opening at the center.
		WorldKit.part(infirmary, "InfirmaryWestWall", Vector3.new(0.5, 7.5, 4.0),
			CFrame.new(base + Vector3.new(-4.75, 4.85, side * 4.0)), WOOD_WALL,
			Enum.Material.WoodPlanks)
	end
	WorldKit.part(infirmary, "InfirmaryDoorHeader", Vector3.new(0.5, 1.0, 3.5),
		CFrame.new(base + Vector3.new(-4.75, 8.1, 0)), WOOD_WALL, Enum.Material.WoodPlanks)
	for side = -1, 1, 2 do
		WorldKit.part(infirmary, "InfirmaryRoof", Vector3.new(5.8, 0.5, 13),
			CFrame.new(base + Vector3.new(side * 2.7, 9.6, 0)) * CFrame.Angles(0, 0, side * math.rad(-20)),
			TIN_ROOF, Enum.Material.CorrodedMetal)
	end
	WorldKit.hingedDoor(infirmary, "InfirmaryDoor", Vector3.new(3.4, 6.2, 0.35),
		CFrame.new(base + Vector3.new(-4.8, 3.9, 0)) * CFrame.Angles(0, math.rad(90), 0),
		WOOD_MID)
	WorldKit.shutterWindow(infirmary, "InfirmaryWindow", Vector3.new(2.6, 2.4, 0.3),
		CFrame.new(base + Vector3.new(1.5, 4.6, -5.8)))

	-- Two cots with white sheets along the east wall.
	for cotIndex, cotZ in { -3.2, 3.2 } do
		local suffix = tostring(cotIndex)
		WorldKit.part(infirmary, "InfirmaryCot" .. suffix, Vector3.new(2.4, 0.9, 4.6),
			CFrame.new(base + Vector3.new(3.3, 1.55, cotZ)), WOOD_MID, Enum.Material.Wood)
		WorldKit.part(infirmary, "InfirmarySheet" .. suffix, Vector3.new(2.2, 0.5, 4.4),
			CFrame.new(base + Vector3.new(3.3, 2.25, cotZ)), Color3.fromRGB(236, 238, 236),
			Enum.Material.Fabric).CanCollide = false
		WorldKit.part(infirmary, "InfirmaryPillow" .. suffix, Vector3.new(1.8, 0.3, 1.0),
			CFrame.new(base + Vector3.new(3.3, 2.65, cotZ + 1.5)), PAPER, Enum.Material.Fabric)
			.CanCollide = false
	end

	-- Medicine cabinet (drawer) on the north wall.
	WorldKit.part(infirmary, "MedicineCabinet", Vector3.new(2.2, 2.6, 0.9),
		CFrame.new(base + Vector3.new(-1.5, 4.6, 5.3)), Color3.fromRGB(214, 214, 206),
		Enum.Material.SmoothPlastic).CanCollide = false
	WorldKit.drawer(infirmary, "MedicineDrawer", Vector3.new(1.8, 1.0, 0.4),
		CFrame.new(base + Vector3.new(-1.5, 4.2, 4.75)) * CFrame.Angles(0, math.rad(180), 0),
		Color3.fromRGB(190, 190, 184))
	WorldKit.part(infirmary, "CabinetCrossH", Vector3.new(0.9, 0.3, 0.06),
		CFrame.new(base + Vector3.new(-1.5, 5.4, 4.82)), Color3.fromRGB(190, 58, 48),
		Enum.Material.SmoothPlastic).CanCollide = false
	WorldKit.part(infirmary, "CabinetCrossV", Vector3.new(0.3, 0.9, 0.06),
		CFrame.new(base + Vector3.new(-1.5, 5.4, 4.82)), Color3.fromRGB(190, 58, 48),
		Enum.Material.SmoothPlastic).CanCollide = false

	-- Logbook desk near the south end.
	local deskPosition = base + Vector3.new(-3, 0, -3.7)
	WorldKit.part(infirmary, "InfirmaryDeskTop", Vector3.new(3.2, 0.35, 1.8),
		CFrame.new(deskPosition + Vector3.new(0, 2.9, 0)), WOOD_WARM, Enum.Material.WoodPlanks)
	WorldKit.part(infirmary, "InfirmaryDeskBase", Vector3.new(2.8, 2.5, 1.5),
		CFrame.new(deskPosition + Vector3.new(0, 1.5, 0)), WOOD_MID, Enum.Material.Wood)
	for pageSide = -1, 1, 2 do
		WorldKit.part(infirmary, "InfirmaryLogbook", Vector3.new(0.85, 0.08, 1.2),
			CFrame.new(deskPosition + Vector3.new(pageSide * 0.44, 3.15, 0))
				* CFrame.Angles(0, 0, pageSide * math.rad(-4)),
			PAPER, Enum.Material.SmoothPlastic).CanCollide = false
	end

	-- Red cross sign over the door, outside.
	WorldKit.part(infirmary, "CrossBoard", Vector3.new(0.3, 2.2, 2.2),
		CFrame.new(base + Vector3.new(-5.15, 7.6, 0)), Color3.fromRGB(236, 238, 236),
		Enum.Material.SmoothPlastic).CanCollide = false
	WorldKit.part(infirmary, "CrossH", Vector3.new(0.1, 0.5, 1.6),
		CFrame.new(base + Vector3.new(-5.32, 7.6, 0)), Color3.fromRGB(190, 58, 48),
		Enum.Material.SmoothPlastic).CanCollide = false
	WorldKit.part(infirmary, "CrossV", Vector3.new(0.1, 1.6, 0.5),
		CFrame.new(base + Vector3.new(-5.32, 7.6, 0)), Color3.fromRGB(190, 58, 48),
		Enum.Material.SmoothPlastic).CanCollide = false

	local lampHolder = WorldKit.part(infirmary, "InfirmaryLampHolder", Vector3.new(1.0, 0.3, 1.0),
		CFrame.new(base + Vector3.new(0, 7.9, 0)), LANTERN_AMBER, Enum.Material.Glass)
	lampHolder.Transparency = 0.3
	lampHolder.CanCollide = false
	WorldKit.lamp(lampHolder, { generatorGated = true, range = 15 })

	-- Marker sits over the logbook on the desk top.
	return deskPosition + Vector3.new(0, 3.2, 0.2)
end

-- =========================================================== feature 10 ====
-- Archery range: three ring-painted hay-bale targets fired at east-to-west,
-- a shooting-line fence with a cosmetic "Practice Shot", and an equipment
-- shed with a bow rack short one bow. Laid out around the existing mini-range
-- props and pine tree 20 at (-45.6, ·, -67).

local function buildArcheryRange(dayCamp: Instance): Vector3
	local range = WorldKit.model(dayCamp, "ArcheryRange")

	-- Whole range shifted east (+10) off the perimeter dome's flank: at the
	-- authored x the bales/targets were sunk up to 12 studs into the hill.
	local laneZs = { -58.6, -61.6, -64.6 }
	local targetFaces: { Vector3 } = {}
	for targetIndex, laneZ in laneZs do
		local suffix = tostring(targetIndex)
		WorldKit.part(range, "RangeBale" .. suffix, Vector3.new(1.7, 2.8, 3.0),
			CFrame.new(-40.6, 3.3, laneZ), HAY, Enum.Material.Grass)
		cyl(range, "RangeFace" .. suffix, Vector3.new(0.2, 2.0, 2.0),
			CFrame.new(-39.6, 4.0, laneZ), Color3.fromRGB(228, 224, 210), Enum.Material.SmoothPlastic)
			.CanCollide = false
		cyl(range, "RangeRing" .. suffix, Vector3.new(0.24, 1.3, 1.3),
			CFrame.new(-39.56, 4.0, laneZ), Color3.fromRGB(190, 58, 48), Enum.Material.SmoothPlastic)
			.CanCollide = false
		cyl(range, "RangeBull" .. suffix, Vector3.new(0.28, 0.55, 0.55),
			CFrame.new(-39.52, 4.0, laneZ), Color3.fromRGB(198, 165, 32), Enum.Material.SmoothPlastic)
			.CanCollide = false
		table.insert(targetFaces, Vector3.new(-39.4, 4.0, laneZ))
	end

	-- Shooting-line fence.
	for _, postZ in { -57.5, -62, -66.5 } do
		WorldKit.part(range, "RangeFencePost", Vector3.new(0.45, 3.4, 0.45),
			CFrame.new(-28, 2.1, postZ), WOOD_MID, Enum.Material.Wood)
	end
	local topRail = WorldKit.part(range, "RangeFenceRailTop", Vector3.new(0.3, 0.25, 9.4),
		CFrame.new(-28, 3.35, -62), WOOD_MID, Enum.Material.Wood)
	WorldKit.part(range, "RangeFenceRailLow", Vector3.new(0.3, 0.25, 9.4),
		CFrame.new(-28, 2.35, -62), WOOD_MID, Enum.Material.Wood)

	local bowRelease = attachSound(topRail, "BowRelease", "ArcheryBowAssetId",
		"rbxassetid://12222095", 0.55, 1.6) -- placeholder: replace with final asset
	local shotBusy = false
	local prompt = WorldKit.prompt(topRail, "Practice Shot", "Archery line", 0.3)
	prompt.Triggered:Connect(function(_player: Player)
		if shotBusy then
			return
		end
		shotBusy = true
		bowRelease:Play()
		local target = targetFaces[math.random(1, #targetFaces)]
		local start = Vector3.new(-28.8, 3.6, target.Z + math.random(-6, 6) * 0.1)
		local apex = start:Lerp(target, 0.5) + Vector3.new(0, 2.6, 0)
		local arrow = WorldKit.part(range, "PracticeArrow", Vector3.new(0.1, 0.1, 2.4),
			CFrame.lookAt(start, apex), Color3.fromRGB(122, 92, 58), Enum.Material.Wood)
		arrow.CanCollide = false
		local rise = TweenService:Create(arrow,
			TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.lookAt(apex, target) })
		rise:Play()
		rise.Completed:Once(function()
			local strike = TweenService:Create(arrow,
				TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = CFrame.lookAt(target, target + (target - apex)) })
			strike:Play()
		end)
		task.delay(1.4, function()
			arrow:Destroy()
			shotBusy = false
		end)
	end)

	-- Equipment shed, door facing the range. Shifted east with the range,
	-- sitting in the shallow dip at the dome's toe (grade ~0.5-2 here). The
	-- base map's stray HayBale lands inside — free set dressing.
	local shedBase = Vector3.new(-39, 0, -70.5)
	WorldKit.part(range, "ShedFloor", Vector3.new(6, 0.5, 8),
		CFrame.new(shedBase + Vector3.new(0, 0.85, 0)), WOOD_FLOOR, Enum.Material.WoodPlanks)
	WorldKit.part(range, "ShedSouthWall", Vector3.new(6, 6.5, 0.4),
		CFrame.new(shedBase + Vector3.new(0, 4.35, 3.8)), WOOD_WALL, Enum.Material.WoodPlanks)
	for side = -1, 1, 2 do
		WorldKit.part(range, "ShedSideWall", Vector3.new(0.4, 6.5, 8),
			CFrame.new(shedBase + Vector3.new(side * 2.8, 4.35, 0)), WOOD_WALL,
			Enum.Material.WoodPlanks)
		WorldKit.part(range, "ShedFrontWall", Vector3.new(1.75, 6.5, 0.4),
			CFrame.new(shedBase + Vector3.new(side * 2.15, 4.35, -3.8)), WOOD_WALL,
			Enum.Material.WoodPlanks)
	end
	WorldKit.part(range, "ShedHeader", Vector3.new(2.6, 0.7, 0.4),
		CFrame.new(shedBase + Vector3.new(0, 7.25, -3.8)), WOOD_WALL, Enum.Material.WoodPlanks)
	WorldKit.part(range, "ShedRoof", Vector3.new(6.8, 0.35, 9),
		CFrame.new(shedBase + Vector3.new(0, 8.2, 0.2)) * CFrame.Angles(math.rad(8), 0, 0),
		TIN_ROOF, Enum.Material.CorrodedMetal)
	WorldKit.hingedDoor(range, "ShedDoor", Vector3.new(2.4, 5.6, 0.3),
		CFrame.new(shedBase + Vector3.new(0, 3.9, -3.9)), WOOD_MID)

	-- Bow rack on the west interior wall: three bows, one conspicuously
	-- empty hook with a lore tag.
	WorldKit.part(range, "BowRackBoard", Vector3.new(0.3, 0.4, 5.2),
		CFrame.new(shedBase + Vector3.new(-2.45, 4.6, 0.2)), WOOD_DARK, Enum.Material.WoodPlanks)
		.CanCollide = false
	for hookIndex = 1, 4 do
		local hookZ = shedBase.Z + 2.15 - (hookIndex - 1) * 1.3
		WorldKit.part(range, "BowHook" .. tostring(hookIndex), Vector3.new(0.5, 0.2, 0.2),
			CFrame.new(shedBase.X - 2.2, 4.6, hookZ), METAL_DARK, Enum.Material.Metal)
			.CanCollide = false
		if hookIndex < 4 then
			WorldKit.part(range, "RackBowLimb" .. tostring(hookIndex), Vector3.new(0.2, 3.0, 0.35),
				CFrame.new(shedBase.X - 2.1, 4.3, hookZ) * CFrame.Angles(0, 0, math.rad(12)),
				WOOD_WARM, Enum.Material.Wood).CanCollide = false
			WorldKit.part(range, "RackBowString" .. tostring(hookIndex), Vector3.new(0.06, 2.7, 0.06),
				CFrame.new(shedBase.X - 1.85, 4.3, hookZ) * CFrame.Angles(0, 0, math.rad(4)),
				PAPER, Enum.Material.Fabric).CanCollide = false
		else
			local tag = WorldKit.part(range, "MissingBowTag", Vector3.new(0.06, 0.5, 0.9),
				CFrame.new(shedBase.X - 2.1, 4.0, hookZ) * CFrame.Angles(0, 0, math.rad(-6)),
				PAPER, Enum.Material.SmoothPlastic)
			tag.CanCollide = false
			surfaceText(tag, "MISSING:\n1 BOW", Color3.fromRGB(112, 54, 44), Enum.NormalId.Right, 11)
		end
	end
	cyl(range, "QuiverBarrel", Vector3.new(2.2, 1.7, 1.7),
		CFrame.new(shedBase + Vector3.new(1.9, 1.7, 2.8)) * CFrame.Angles(0, 0, math.rad(90)),
		WOOD_MID, Enum.Material.Wood)
	for arrowIndex = 1, 3 do
		WorldKit.part(range, "QuiverArrow" .. tostring(arrowIndex), Vector3.new(0.1, 2.6, 0.1),
			CFrame.new(shedBase + Vector3.new(1.7 + arrowIndex * 0.2, 3.2, 2.6 + (arrowIndex % 2) * 0.4))
				* CFrame.Angles(math.rad(arrowIndex * 7 - 12), 0, math.rad(arrowIndex * 5)),
			Color3.fromRGB(122, 92, 58), Enum.Material.Wood).CanCollide = false
	end
	lanternBox(range, shedBase + Vector3.new(0.4, 6.6, 0.4), { generatorGated = true, range = 11 })

	return shedBase + Vector3.new(-0.3, 2.2, -0.5)
end

-- ===========================================================================

function CampExpansion.Build(dayCamp: Instance, nightTown: Instance)
	local _ = nightTown -- day-side pack; kept for the shared Build contract

	furnishCabins(dayCamp)
	buildFrontGate(dayCamp)
	buildSignage(dayCamp)
	buildCampfirePlaza(dayCamp)
	buildAerialCircuit(dayCamp)
	buildLodgeHub(dayCamp)
	buildSanitationRow(dayCamp)
	local quartersMarker = buildCounselorQuarters(dayCamp)
	local infirmaryMarker = buildInfirmary(dayCamp)
	local archeryMarker = buildArcheryRange(dayCamp)

	-- Search-location markers (register these in SEARCH_TARGETS/LOCATIONS).
	WorldKit.evidenceSocketMarker(dayCamp, "quarters-footlocker", quartersMarker)
	WorldKit.evidenceSocketMarker(dayCamp, "infirmary-logbook", infirmaryMarker)
	WorldKit.evidenceSocketMarker(dayCamp, "archery-shed", archeryMarker)
end

return CampExpansion
