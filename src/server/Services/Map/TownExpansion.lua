--!strict

-- TOWN EXPANSION pack: full interiors (General Store, Gas Station), second
-- floors (Police cell block, Factory catwalk), cellars (ResidentialA and
-- CompanyHouse), church graveyard, climbable water tower, main-road decay
-- dressing, town square, drive-in ruin, west train line, and the caretaker's
-- junkyard behind Mill No. 7.
--
-- Everything parents under a single "TownExpansion" model inside the NightTown
-- folder; the existing day/night visibility sweep reveals it at dusk. Call
-- TownExpansion.Build from ProductionMapService:Build() AFTER the night-town
-- geometry exists and BEFORE the first SetNight sweep runs:
--
--     local TownExpansion = require(script.Parent:WaitForChild("Map"):WaitForChild("TownExpansion"))
--     TownExpansion.Build(self.dayCamp, self.nightTown)
--
-- New search-location markers (register in SEARCH_TARGETS/SEARCH_LOCATIONS):
--     graveyard-open-grave   (-22, 0.6, -470)
--     water-tower-catwalk    (110, 27.3, -283.2)
--     town-square-fountain   (21, 1.8, -187)
--     drive-in-projector     (104, 2.6, -420.6)
--     derailed-boxcar        (~-146.8, 3.0, -225.1)

local Workspace = game:GetService("Workspace")

local WorldKit = require(script.Parent:WaitForChild("WorldKit"))

local GROUND = Color3.fromRGB(47, 51, 48)
local WOOD = Color3.fromRGB(110, 84, 58)
local WOOD_DARK = Color3.fromRGB(78, 58, 40)
local PLANK = Color3.fromRGB(96, 72, 48)
local STEEL = Color3.fromRGB(96, 96, 100)
local IRON_DARK = Color3.fromRGB(56, 52, 48)
local RUST = Color3.fromRGB(128, 74, 50)
local RUST_DEEP = Color3.fromRGB(96, 58, 40)
local CONCRETE = Color3.fromRGB(96, 96, 90)
local EARTH = Color3.fromRGB(74, 58, 40)
local PAPER = Color3.fromRGB(190, 180, 152)
local CLOTH = Color3.fromRGB(148, 138, 120)
local GLASS_DARK = Color3.fromRGB(40, 46, 52)
local SCREEN_WHITE = Color3.fromRGB(186, 180, 168)
local SLATE = Color3.fromRGB(41, 43, 46)
local MATTRESS = Color3.fromRGB(140, 132, 116)

-- Flat text plate (posters, headline boards, etched plates).
local function surfaceText(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	textColor: Color3
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(420, 240)
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.SpecialElite
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui
end

-- Hanging bulb fixture wired through WorldKit.lamp (off by day, lit at night).
local function lampFixture(parent: Instance, position: Vector3, range: number)
	local fixture = WorldKit.part(
		parent,
		"LampFixture",
		Vector3.new(0.55, 0.5, 0.55),
		CFrame.new(position),
		IRON_DARK,
		Enum.Material.Metal
	)
	fixture.CanCollide = false
	local bulb = WorldKit.part(
		parent,
		"LampBulb",
		Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(position - Vector3.new(0, 0.45, 0)),
		Color3.fromRGB(216, 196, 150),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	bulb.CanCollide = false
	WorldKit.lamp(bulb, { range = range })
end

-- Carves a rectangular hole through thin horizontal slabs (ground plane,
-- roofs) so stairwells can pass. Each intersected slab is replaced by up to
-- four look-alike slabs around the hole; walls and tall parts are never
-- touched. Pack-owned parts are skipped unless includePack is true.
local function carveRect(
	nightTown: Instance,
	packRoot: Model,
	center: Vector3,
	size: Vector3,
	includePack: boolean?
)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { nightTown }
	local hits = Workspace:GetPartBoundsInBox(CFrame.new(center), size, params)
	local holeX0 = center.X - size.X / 2
	local holeX1 = center.X + size.X / 2
	local holeZ0 = center.Z - size.Z / 2
	local holeZ1 = center.Z + size.Z / 2
	for _, hit in hits do
		if not hit:IsA("BasePart") then
			continue
		end
		if includePack ~= true and hit:IsDescendantOf(packRoot) then
			continue
		end
		if not hit.CanCollide or hit.Transparency >= 1 then
			continue
		end
		local cf = hit.CFrame
		local half = hit.Size / 2
		local right, up, look = cf.RightVector, cf.UpVector, cf.LookVector
		local ex = math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z
		local ey = math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z
		local ez = math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
		if ey * 2 > 3 then
			-- Not a thin slab (wall/column): leave it alone.
			continue
		end
		local px0, px1 = cf.Position.X - ex, cf.Position.X + ex
		local pz0, pz1 = cf.Position.Z - ez, cf.Position.Z + ez
		if holeX1 <= px0 or holeX0 >= px1 or holeZ1 <= pz0 or holeZ0 >= pz1 then
			continue
		end
		local cx0 = math.max(holeX0, px0)
		local cx1 = math.min(holeX1, px1)
		local cz0 = math.max(holeZ0, pz0)
		local cz1 = math.min(holeZ1, pz1)
		local pieces: { { x0: number, x1: number, z0: number, z1: number } } = {
			{ x0 = px0, x1 = cx0, z0 = pz0, z1 = pz1 },
			{ x0 = cx1, x1 = px1, z0 = pz0, z1 = pz1 },
			{ x0 = cx0, x1 = cx1, z0 = pz0, z1 = cz0 },
			{ x0 = cx0, x1 = cx1, z0 = cz1, z1 = pz1 },
		}
		for _, piece in pieces do
			local width = piece.x1 - piece.x0
			local depth = piece.z1 - piece.z0
			if width < 0.05 or depth < 0.05 then
				continue
			end
			local slab = Instance.new("Part")
			slab.Name = hit.Name
			slab.Anchored = true
			slab.Size = Vector3.new(width, ey * 2, depth)
			slab.CFrame = CFrame.new(
				(piece.x0 + piece.x1) / 2,
				cf.Position.Y,
				(piece.z0 + piece.z1) / 2
			)
			slab.Color = hit.Color
			slab.Material = hit.Material
			slab.Transparency = hit.Transparency
			slab.TopSurface = Enum.SurfaceType.Smooth
			slab.BottomSurface = Enum.SurfaceType.Smooth
			slab.Parent = hit.Parent
		end
		hit:Destroy()
	end
end

-- The visibility sweep force-disables collision on hidden parts, which would
-- drop unanchored clutter into the void by day. Knockables therefore rest
-- anchored while hidden and only go physical while revealed; the rest pose is
-- restored every time the town hides so each night starts tidy.
local function makeKnockable(prop: BasePart)
	local restCFrame = prop.CFrame
	prop.Anchored = true
	prop:GetPropertyChangedSignal("Transparency"):Connect(function()
		if prop.Transparency >= 1 then
			prop.Anchored = true
			prop.CFrame = restCFrame
		else
			prop.Anchored = false
		end
	end)
end

-- Simple double-sided shelf unit: two end panels, three boards, one crate of
-- goods. widthAxisCFrame's local X runs along the unit's width.
local function shelfUnit(parent: Instance, cframe: CFrame, width: number, depth: number)
	for side = -1, 1, 2 do
		WorldKit.part(
			parent,
			"ShelfEnd",
			Vector3.new(0.35, 6.2, depth),
			cframe * CFrame.new(side * (width / 2 - 0.175), 3.1, 0),
			WOOD_DARK,
			Enum.Material.WoodPlanks
		)
	end
	for level = 1, 3 do
		WorldKit.part(
			parent,
			"ShelfBoard",
			Vector3.new(width - 0.5, 0.3, depth),
			cframe * CFrame.new(0, level * 1.9 - 0.6, 0),
			PLANK,
			Enum.Material.WoodPlanks
		)
	end
	WorldKit.part(
		parent,
		"ShelfGoods",
		Vector3.new(math.min(width - 1.4, 2.4), 1.1, depth - 0.5),
		cframe * CFrame.new((width / 2 - 1.6) * 0.4, 1.9, 0),
		RUST_DEEP,
		Enum.Material.Fabric
	)
end

local function railingRun(
	parent: Instance,
	fromPos: Vector3,
	toPos: Vector3,
	height: number
)
	local span = toPos - fromPos
	local length = span.Magnitude
	local mid = (fromPos + toPos) / 2
	local yaw = math.atan2(-span.Z, span.X)
	WorldKit.part(
		parent,
		"RailTop",
		Vector3.new(length, 0.3, 0.3),
		CFrame.new(mid + Vector3.new(0, height, 0)) * CFrame.Angles(0, yaw, 0),
		STEEL,
		Enum.Material.Metal
	)
	WorldKit.part(
		parent,
		"RailMid",
		Vector3.new(length, 0.25, 0.25),
		CFrame.new(mid + Vector3.new(0, height * 0.55, 0)) * CFrame.Angles(0, yaw, 0),
		STEEL,
		Enum.Material.Metal
	)
end

-- Ground plane extension south of z -445 so the graveyard, church surrounds,
-- and the deep end of the drive-in stand on solid ground.
local function buildSouthGround(root: Model)
	WorldKit.part(
		root,
		"SouthFieldGround",
		Vector3.new(300, 1, 40),
		CFrame.new(0, -0.5, -465),
		GROUND,
		Enum.Material.Ground
	)
end

-- 1a. General Store interior: aisles, stockroom partition, register drawer.
-- Interior box: x -87..-59, z -201..-169, door at x -58.5 / z -185.
local function buildGeneralStoreInterior(root: Model)
	local store = WorldKit.model(root, "GeneralStoreInterior")
	local boards = WorldKit.part(
		store,
		"StoreFloorBoards",
		Vector3.new(27.4, 0.25, 31.6),
		CFrame.new(-73.2, 0.93, -185),
		WOOD_DARK,
		Enum.Material.WoodPlanks
	)
	WorldKit.creakyFloor(boards)
	-- Stockroom partition (back seventh of the store) with an open doorway.
	WorldKit.part(
		store,
		"StockroomWall",
		Vector3.new(0.4, 8.5, 24),
		CFrame.new(-80.5, 5.3, -189),
		WOOD,
		Enum.Material.WoodPlanks
	)
	WorldKit.part(
		store,
		"StockroomWallEnd",
		Vector3.new(0.4, 8.5, 4.5),
		CFrame.new(-80.5, 5.3, -171.25),
		WOOD,
		Enum.Material.WoodPlanks
	)
	-- Stockroom shelving and stock.
	shelfUnit(store, CFrame.new(-85.2, 1.05, -193), 8, 1.8)
	shelfUnit(store, CFrame.new(-85.2, 1.05, -178), 8, 1.8)
	WorldKit.part(
		store,
		"StockCrate",
		Vector3.new(2.4, 2.4, 2.4),
		CFrame.new(-82.6, 2.25, -198.5) * CFrame.Angles(0, 0.3, 0),
		PLANK,
		Enum.Material.WoodPlanks
	)
	WorldKit.part(
		store,
		"StockSack",
		Vector3.new(1.8, 1.2, 1.4),
		CFrame.new(-82.2, 1.65, -172.4),
		CLOTH,
		Enum.Material.Fabric
	)
	-- Sales-floor gondola aisles (door corridor at z -182..-188 stays open).
	shelfUnit(store, CFrame.new(-67, 1.05, -194) * CFrame.Angles(0, math.rad(90), 0), 10, 1.9)
	shelfUnit(store, CFrame.new(-67, 1.05, -176) * CFrame.Angles(0, math.rad(90), 0), 10, 1.9)
	shelfUnit(store, CFrame.new(-70, 1.05, -170.6), 10, 1.6)
	-- Cash register on the existing counter, with a sliding cash drawer.
	WorldKit.part(
		store,
		"CashRegister",
		Vector3.new(1.6, 1.2, 1.4),
		CFrame.new(-76, 4.1, -181.5),
		IRON_DARK,
		Enum.Material.Metal
	)
	WorldKit.drawer(
		store,
		"Cash Drawer",
		Vector3.new(2.4, 1.1, 0.6),
		CFrame.new(-74.15, 2.6, -181.5) * CFrame.Angles(0, math.rad(90), 0),
		WOOD_DARK
	)
	lampFixture(store, Vector3.new(-68, 9.5, -185), 22)
	lampFixture(store, Vector3.new(-84, 8.5, -186), 12)
end

-- 1b. Gas Station interior: garage bay with a car on a lift, tool wall,
-- office nook. Interior box: x 62..88, z -201..-169, door at x 61.5 / z -185.
local function buildGasStationInterior(root: Model)
	local garage = WorldKit.model(root, "GasStationInterior")
	-- Lift columns and arms.
	for _, columnX in { 68, 82 } do
		WorldKit.part(
			garage,
			"LiftColumn",
			Vector3.new(1.2, 8, 1.2),
			CFrame.new(columnX, 4.8, -196),
			STEEL,
			Enum.Material.DiamondPlate
		)
	end
	for _, armZ in { -197.6, -194.4 } do
		WorldKit.part(
			garage,
			"LiftArm",
			Vector3.new(14.6, 0.5, 1),
			CFrame.new(75, 4.6, armZ),
			IRON_DARK,
			Enum.Material.Metal
		)
	end
	-- Rusted sedan up on the lift.
	WorldKit.part(
		garage,
		"LiftCarBody",
		Vector3.new(9, 1.4, 4.4),
		CFrame.new(75, 5.6, -196),
		RUST,
		Enum.Material.CorrodedMetal
	)
	WorldKit.part(
		garage,
		"LiftCarCabin",
		Vector3.new(4.6, 1.5, 3.9),
		CFrame.new(73.6, 7.05, -196),
		RUST_DEEP,
		Enum.Material.CorrodedMetal
	)
	for _, offset in { Vector3.new(-3, 0, -1.9), Vector3.new(3, 0, -1.9), Vector3.new(-3, 0, 1.9), Vector3.new(3, 0, 1.9) } do
		local wheel = WorldKit.part(
			garage,
			"LiftCarWheel",
			Vector3.new(0.7, 1.9, 1.9),
			CFrame.new(Vector3.new(75, 5, -196) + offset) * CFrame.Angles(0, math.rad(90), 0),
			IRON_DARK,
			Enum.Material.Rubber,
			Enum.PartType.Cylinder
		)
		wheel.CanCollide = false
	end
	-- Tool wall against the back wall of the bay.
	WorldKit.part(
		garage,
		"ToolWall",
		Vector3.new(0.25, 5.5, 9),
		CFrame.new(87.8, 5.6, -195.5),
		WOOD_DARK,
		Enum.Material.WoodPlanks
	)
	local toolOffsets: { { y: number, z: number, w: number, h: number } } = {
		{ y = 6.8, z = -198.6, w = 0.4, h = 2.2 },
		{ y = 6.4, z = -196.8, w = 0.4, h = 1.6 },
		{ y = 6.9, z = -195, w = 0.5, h = 2.6 },
		{ y = 6.3, z = -193.2, w = 0.4, h = 1.4 },
		{ y = 6.7, z = -192, w = 0.6, h = 1.9 },
	}
	for _, tool in toolOffsets do
		WorldKit.part(
			garage,
			"HungTool",
			Vector3.new(0.18, tool.h, tool.w),
			CFrame.new(87.55, tool.y, tool.z),
			STEEL,
			Enum.Material.Metal
		).CanCollide = false
	end
	-- Workbench, tires, oil stains.
	WorldKit.part(garage, "BenchTop", Vector3.new(5.5, 0.3, 2.2), CFrame.new(85.4, 3.05, -190.4), PLANK, Enum.Material.WoodPlanks)
	WorldKit.part(garage, "BenchLegA", Vector3.new(0.35, 2.1, 2), CFrame.new(83, 1.85, -190.4), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(garage, "BenchLegB", Vector3.new(0.35, 2.1, 2), CFrame.new(87.8, 1.85, -190.4), WOOD_DARK, Enum.Material.Wood)
	for stack = 1, 3 do
		WorldKit.part(
			garage,
			"BayTire",
			Vector3.new(0.75, 2.4, 2.4),
			CFrame.new(64, 0.8 + (stack - 1) * 0.78, -198.4) * CFrame.Angles(0, 0, math.rad(90)),
			IRON_DARK,
			Enum.Material.Rubber,
			Enum.PartType.Cylinder
		)
	end
	for _, stain in { Vector3.new(71, 0.94, -193), Vector3.new(79.5, 0.94, -198.5) } do
		local oil = WorldKit.part(
			garage,
			"OilStain",
			Vector3.new(3.2, 0.06, 2.4),
			CFrame.new(stain),
			Color3.fromRGB(28, 28, 30),
			Enum.Material.SmoothPlastic
		)
		oil.CanCollide = false
	end
	-- Office nook behind a half partition (entry gap at x 62..70).
	WorldKit.part(
		garage,
		"OfficePartition",
		Vector3.new(18, 7, 0.4),
		CFrame.new(79, 4.3, -178.7),
		CONCRETE,
		Enum.Material.Concrete
	)
	local officeFloor = WorldKit.part(
		garage,
		"OfficeFloorBoards",
		Vector3.new(25.6, 0.2, 9),
		CFrame.new(75, 0.9, -173.8),
		WOOD_DARK,
		Enum.Material.WoodPlanks
	)
	WorldKit.creakyFloor(officeFloor)
	WorldKit.part(garage, "OfficeDeskTop", Vector3.new(4.5, 0.3, 2.2), CFrame.new(84, 3.05, -171.8), PLANK, Enum.Material.WoodPlanks)
	WorldKit.part(garage, "OfficeDeskSideA", Vector3.new(0.35, 2.1, 2.2), CFrame.new(82, 1.95, -171.8), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(garage, "OfficeDeskSideB", Vector3.new(0.35, 2.1, 2.2), CFrame.new(86, 1.95, -171.8), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(garage, "DeskPapers", Vector3.new(1.4, 0.18, 1.1), CFrame.new(84.4, 3.3, -171.6) * CFrame.Angles(0, 0.4, 0), PAPER, Enum.Material.SmoothPlastic).CanCollide = false
	WorldKit.part(garage, "OfficeChairSeat", Vector3.new(1.6, 0.3, 1.6), CFrame.new(84, 2.3, -174.4), WOOD, Enum.Material.Wood)
	WorldKit.part(garage, "OfficeChairBack", Vector3.new(1.6, 1.7, 0.3), CFrame.new(84, 3.3, -175.1), WOOD, Enum.Material.Wood)
	WorldKit.part(garage, "FilingCabinet", Vector3.new(1.6, 4.2, 1.8), CFrame.new(87, 3.1, -170.3), STEEL, Enum.Material.Metal)
	WorldKit.drawer(
		garage,
		"Service Records",
		Vector3.new(1.3, 0.9, 0.5),
		CFrame.new(86, 3.9, -170.3) * CFrame.Angles(0, math.rad(-90), 0),
		IRON_DARK
	)
	lampFixture(garage, Vector3.new(75, 13, -196), 24)
	lampFixture(garage, Vector3.new(76, 8.6, -173.5), 14)
end

-- 2a. Police Station second floor: exterior massing over the one-story box, a
-- switchback stair, and a three-cell block with barred fronts and hinged
-- doors. Existing footprint x 73..111, z -381..-339, walls 22 high.
local function buildPoliceCellBlock(root: Model, nightTown: Instance)
	local station = WorldKit.model(root, "PoliceUpperFloor")
	-- Hole through the existing flat roof for the stairwell.
	carveRect(nightTown, root, Vector3.new(84, 22.75, -376.5), Vector3.new(16, 2.5, 9))
	-- Exterior massing: four walls plus a new flat roof.
	local wallColor = Color3.fromRGB(64, 72, 79)
	WorldKit.part(station, "UpperWallN", Vector3.new(38, 11, 1), CFrame.new(92, 29, -339.5), wallColor, Enum.Material.Brick)
	WorldKit.part(station, "UpperWallS", Vector3.new(38, 11, 1), CFrame.new(92, 29, -380.5), wallColor, Enum.Material.Brick)
	WorldKit.part(station, "UpperWallW", Vector3.new(1, 11, 42), CFrame.new(73.5, 29, -360), wallColor, Enum.Material.Brick)
	WorldKit.part(station, "UpperWallE", Vector3.new(1, 11, 42), CFrame.new(110.5, 29, -360), wallColor, Enum.Material.Brick)
	WorldKit.part(station, "UpperRoof", Vector3.new(40, 1.2, 44), CFrame.new(92, 35.1, -360), SLATE, Enum.Material.Slate)
	-- Upper floorboards laid around the stair opening.
	local floorPieces: { { size: Vector3, position: Vector3 } } = {
		{ size = Vector3.new(37, 0.4, 32.5), position = Vector3.new(92, 23.7, -355.75) },
		{ size = Vector3.new(18.5, 0.4, 9), position = Vector3.new(101.25, 23.7, -376.5) },
		{ size = Vector3.new(2.5, 0.4, 9), position = Vector3.new(74.75, 23.7, -376.5) },
	}
	for _, piece in floorPieces do
		local deck = WorldKit.part(
			station,
			"UpperFloor",
			piece.size,
			CFrame.new(piece.position),
			WOOD_DARK,
			Enum.Material.WoodPlanks
		)
		WorldKit.creakyFloor(deck)
	end
	-- Switchback stair along the south wall.
	WorldKit.stairs(
		station,
		"StairsLower",
		CFrame.new(79, 0.8, -377.2) * CFrame.Angles(0, math.rad(-90), 0),
		13,
		4.2,
		CONCRETE,
		Enum.Material.Concrete
	)
	WorldKit.part(station, "StairLanding", Vector3.new(4.4, 0.8, 4.4), CFrame.new(95.8, 12.1, -377.2), CONCRETE, Enum.Material.Concrete)
	WorldKit.stairs(
		station,
		"StairsUpper",
		CFrame.new(93.4, 12.5, -377.2) * CFrame.Angles(0, math.rad(90), 0),
		12,
		4.2,
		CONCRETE,
		Enum.Material.Concrete
	)
	-- Arrival landing bridging the top step to the upper floorboards.
	WorldKit.part(
		station,
		"StairTopLanding",
		Vector3.new(4.8, 0.4, 9),
		CFrame.new(78.4, 23.7, -376.5),
		CONCRETE,
		Enum.Material.Concrete
	)
	-- Guard rails around the stair opening on the upper floor.
	railingRun(station, Vector3.new(76, 23.9, -372.2), Vector3.new(92, 23.9, -372.2), 1.1)
	railingRun(station, Vector3.new(92.2, 23.9, -372.4), Vector3.new(92.2, 23.9, -380.8), 1.1)
	-- Cell block along the east wall: three cells, barred fronts, hinged doors.
	local cellBoundaries = { -342, -354, -366, -378 }
	for _, boundaryZ in cellBoundaries do
		WorldKit.part(
			station,
			"CellPartition",
			Vector3.new(8.4, 7.2, 0.4),
			CFrame.new(105.9, 27.5, boundaryZ),
			STEEL,
			Enum.Material.Metal
		)
	end
	for cell = 1, 3 do
		local cellNorthZ = -342 - (cell - 1) * 12
		local doorZ = cellNorthZ - 3
		WorldKit.hingedDoor(
			station,
			"Cell " .. tostring(cell) .. " Door",
			Vector3.new(3, 6.8, 0.3),
			CFrame.new(101.8, 27.3, doorZ) * CFrame.Angles(0, math.rad(90), 0),
			STEEL
		)
		-- Bars fill the front from the door edge to the next partition with
		-- gaps too narrow to slip through.
		for bar = 1, 5 do
			WorldKit.part(
				station,
				"CellBar",
				Vector3.new(0.25, 7.2, 0.25),
				CFrame.new(101.8, 27.5, cellNorthZ - 4.5 - bar * 1.25),
				STEEL,
				Enum.Material.Metal
			)
		end
		WorldKit.part(
			station,
			"CellHeader",
			Vector3.new(0.35, 0.5, 12),
			CFrame.new(101.8, 31.35, cellNorthZ - 6),
			STEEL,
			Enum.Material.Metal
		)
		WorldKit.part(
			station,
			"CellBedFrame",
			Vector3.new(6, 0.5, 2.6),
			CFrame.new(107, 24.65, cellNorthZ - 8.6),
			IRON_DARK,
			Enum.Material.Metal
		)
		WorldKit.part(
			station,
			"CellMattress",
			Vector3.new(5.6, 0.45, 2.3),
			CFrame.new(107, 25.1, cellNorthZ - 8.6),
			MATTRESS,
			Enum.Material.Fabric
		)
	end
	-- Barred slit windows on the street-facing massing wall.
	for _, windowZ in { -350, -370 } do
		WorldKit.part(station, "UpperWindow", Vector3.new(0.3, 3, 2.4), CFrame.new(72.9, 29.5, windowZ), GLASS_DARK, Enum.Material.Glass)
		for barSide = -1, 1, 2 do
			WorldKit.part(
				station,
				"WindowBar",
				Vector3.new(0.15, 3.2, 0.15),
				CFrame.new(72.8, 29.5, windowZ + barSide * 0.7),
				IRON_DARK,
				Enum.Material.Metal
			)
		end
	end
	lampFixture(station, Vector3.new(90, 32.5, -358), 24)
	lampFixture(station, Vector3.new(105, 32.5, -368), 16)
end

-- 2b. Factory catwalk over the press, plus a rooftop monitor so the new level
-- reads from outside. Interior x -121.5..-78.5, z -299..-251, walls 28 high.
local function buildFactoryCatwalk(root: Model)
	local mill = WorldKit.model(root, "FactoryCatwalk")
	-- The press itself (the search socket sits here; give it a machine).
	WorldKit.part(mill, "PressBase", Vector3.new(6, 3, 5), CFrame.new(-106, 2.3, -266), IRON_DARK, Enum.Material.DiamondPlate)
	WorldKit.part(mill, "PressColumn", Vector3.new(2.5, 6, 2.5), CFrame.new(-106, 6.8, -266), STEEL, Enum.Material.Metal)
	WorldKit.part(mill, "PressHead", Vector3.new(4, 2, 4), CFrame.new(-106, 10.8, -266), IRON_DARK, Enum.Material.DiamondPlate)
	WorldKit.part(
		mill,
		"PressFlywheel",
		Vector3.new(0.6, 3.4, 3.4),
		CFrame.new(-102.6, 4.4, -266),
		RUST,
		Enum.Material.CorrodedMetal,
		Enum.PartType.Cylinder
	)
	-- Stair up the east wall, then a catwalk across to the press.
	WorldKit.stairs(
		mill,
		"CatwalkStairs",
		CFrame.new(-82, 0.8, -257),
		14,
		4,
		STEEL,
		Enum.Material.DiamondPlate
	)
	WorldKit.part(mill, "CatwalkDeckEast", Vector3.new(20.5, 0.6, 4.5), CFrame.new(-92.3, 13.7, -274.5), STEEL, Enum.Material.DiamondPlate)
	WorldKit.part(mill, "CatwalkDeckPress", Vector3.new(7, 0.6, 22), CFrame.new(-106, 13.7, -268), STEEL, Enum.Material.DiamondPlate)
	for _, trussPos in { Vector3.new(-108.5, 6.8, -277.5), Vector3.new(-108.5, 6.8, -258.5), Vector3.new(-103.5, 6.8, -258.5) } do
		WorldKit.truss(mill, "CatwalkTruss", Vector3.new(2, 12, 2), CFrame.new(trussPos), IRON_DARK)
	end
	-- Railings on every open deck edge.
	railingRun(mill, Vector3.new(-102.5, 14, -279), Vector3.new(-102.5, 14, -272.6), 1.1)
	railingRun(mill, Vector3.new(-102.5, 14, -257), Vector3.new(-102.5, 14, -263.5), 1.1)
	railingRun(mill, Vector3.new(-109.5, 14, -279), Vector3.new(-109.5, 14, -257), 1.1)
	railingRun(mill, Vector3.new(-106, 14, -257), Vector3.new(-102.5, 14, -257), 1.1)
	railingRun(mill, Vector3.new(-106, 14, -279), Vector3.new(-102.5, 14, -279), 1.1)
	railingRun(mill, Vector3.new(-102.3, 14, -276.75), Vector3.new(-84, 14, -276.75), 1.1)
	railingRun(mill, Vector3.new(-102.3, 14, -272.25), Vector3.new(-96, 14, -272.25), 1.1)
	-- Sloped handrail alongside the stair flight.
	WorldKit.part(
		mill,
		"StairHandrail",
		Vector3.new(0.3, 0.3, 20),
		CFrame.new(-84.2, 9.1, -264.8) * CFrame.Angles(math.atan2(12.6, 15.6), 0, 0),
		STEEL,
		Enum.Material.Metal
	)
	-- Rooftop monitor: exterior massing hinting at the new level inside.
	WorldKit.part(mill, "MonitorWallW", Vector3.new(0.5, 5, 18), CFrame.new(-104, 32, -275), Color3.fromRGB(64, 69, 70), Enum.Material.Brick)
	WorldKit.part(mill, "MonitorWallE", Vector3.new(0.5, 5, 18), CFrame.new(-96, 32, -275), Color3.fromRGB(64, 69, 70), Enum.Material.Brick)
	WorldKit.part(mill, "MonitorEndN", Vector3.new(7.5, 5, 0.5), CFrame.new(-100, 32, -266.25), Color3.fromRGB(64, 69, 70), Enum.Material.Brick)
	WorldKit.part(mill, "MonitorEndS", Vector3.new(7.5, 5, 0.5), CFrame.new(-100, 32, -283.75), Color3.fromRGB(64, 69, 70), Enum.Material.Brick)
	WorldKit.part(mill, "MonitorRoof", Vector3.new(9, 0.8, 19), CFrame.new(-100, 34.9, -275), SLATE, Enum.Material.Slate)
	WorldKit.part(mill, "MonitorGlazeW", Vector3.new(0.2, 2, 14), CFrame.new(-104.3, 32.4, -275), GLASS_DARK, Enum.Material.Glass).CanCollide = false
	WorldKit.part(mill, "MonitorGlazeE", Vector3.new(0.2, 2, 14), CFrame.new(-95.7, 32.4, -275), GLASS_DARK, Enum.Material.Glass).CanCollide = false
	lampFixture(mill, Vector3.new(-106, 12.9, -268), 20)
	lampFixture(mill, Vector3.new(-92, 17, -274.5), 16)
end

-- 3. Cellars under ResidentialA and CompanyHouse: exterior bulkhead trench
-- behind the house, stairs below grade, one low room with shelving, a
-- hideable wardrobe, and a lamp. originX = exterior face of the back wall.
local function buildCellar(
	root: Model,
	nightTown: Instance,
	name: string,
	originX: number,
	centerZ: number
)
	local cellar = WorldKit.model(root, name)
	carveRect(
		nightTown,
		root,
		Vector3.new(originX - 4.3, -0.5, centerZ),
		Vector3.new(13, 1.6, 4.8)
	)
	-- Open stair trench from grade down to the room.
	WorldKit.stairs(
		cellar,
		"CellarStairs",
		CFrame.new(originX + 1.1, -8.9, centerZ) * CFrame.Angles(0, math.rad(90), 0),
		10,
		3.4,
		EARTH,
		Enum.Material.Ground
	)
	for side = -1, 1, 2 do
		WorldKit.part(
			cellar,
			"TrenchWall",
			Vector3.new(12.4, 8.9, 0.35),
			CFrame.new(originX - 4.4, -4.15, centerZ + side * 1.95),
			EARTH,
			Enum.Material.Ground
		)
	end
	WorldKit.part(
		cellar,
		"TrenchEndWall",
		Vector3.new(0.35, 8.9, 4.25),
		CFrame.new(originX - 10.45, -4.15, centerZ),
		EARTH,
		Enum.Material.Ground
	)
	-- Bulkhead dressing above grade.
	for side = -1, 1, 2 do
		WorldKit.part(
			cellar,
			"BulkheadSide",
			Vector3.new(11, 2, 0.4),
			CFrame.new(originX - 4.6, 1, centerZ + side * 2.3),
			WOOD_DARK,
			Enum.Material.WoodPlanks
		)
	end
	WorldKit.part(cellar, "BulkheadPostA", Vector3.new(0.45, 3.4, 0.45), CFrame.new(originX - 10.2, 1.7, centerZ - 2.3), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(cellar, "BulkheadPostB", Vector3.new(0.45, 3.4, 0.45), CFrame.new(originX - 10.2, 1.7, centerZ + 2.3), WOOD_DARK, Enum.Material.Wood)
	local hood = WorldKit.wedge(
		cellar,
		"BulkheadHood",
		Vector3.new(5, 2.8, 5.4),
		CFrame.new(originX - 1.7, 1.6, centerZ) * CFrame.Angles(0, math.rad(90), 0),
		WOOD_DARK,
		Enum.Material.WoodPlanks
	)
	hood.CanCollide = false
	-- The room itself: x originX+2 .. originX+24, 6.6-stud clearance.
	local roomMinX = originX + 2
	local roomMaxX = originX + 24
	local roomCenterX = (roomMinX + roomMaxX) / 2
	WorldKit.part(
		cellar,
		"CellarFloor",
		Vector3.new(23.6, 0.5, 15.6),
		CFrame.new(roomCenterX, -8.25, centerZ),
		Color3.fromRGB(68, 66, 62),
		Enum.Material.Concrete
	)
	WorldKit.part(
		cellar,
		"CellarCeiling",
		Vector3.new(23.6, 0.5, 15.6),
		CFrame.new(roomCenterX, -1.2, centerZ),
		WOOD_DARK,
		Enum.Material.WoodPlanks
	)
	WorldKit.part(cellar, "CellarWallE", Vector3.new(0.4, 6.6, 15.2), CFrame.new(roomMaxX + 0.2, -4.7, centerZ), EARTH, Enum.Material.Ground)
	WorldKit.part(cellar, "CellarWallN", Vector3.new(23.2, 6.6, 0.4), CFrame.new(roomCenterX, -4.7, centerZ + 7.2), EARTH, Enum.Material.Ground)
	WorldKit.part(cellar, "CellarWallS", Vector3.new(23.2, 6.6, 0.4), CFrame.new(roomCenterX, -4.7, centerZ - 7.2), EARTH, Enum.Material.Ground)
	for side = -1, 1, 2 do
		WorldKit.part(
			cellar,
			"CellarWallW",
			Vector3.new(0.4, 6.6, 5.2),
			CFrame.new(roomMinX - 0.2, -4.7, centerZ + side * 4.75),
			EARTH,
			Enum.Material.Ground
		)
	end
	-- Furnishing: shelving, crates, wardrobe hiding spot, lamp.
	shelfUnit(cellar, CFrame.new(roomCenterX - 3, -8, centerZ - 6), 9, 1.8)
	WorldKit.part(
		cellar,
		"CellarCrateA",
		Vector3.new(2.6, 2.6, 2.6),
		CFrame.new(roomMinX + 2.4, -6.7, centerZ + 5.4) * CFrame.Angles(0, 0.4, 0),
		PLANK,
		Enum.Material.WoodPlanks
	)
	WorldKit.part(
		cellar,
		"CellarCrateB",
		Vector3.new(1.9, 1.9, 1.9),
		CFrame.new(roomMinX + 4.8, -7.05, centerZ + 5.9),
		PLANK,
		Enum.Material.WoodPlanks
	)
	local wardrobe = WorldKit.part(
		cellar,
		"CellarWardrobe",
		Vector3.new(2.2, 5.4, 3),
		CFrame.new(roomMaxX - 1.4, -5.3, centerZ + 4.8),
		WOOD,
		Enum.Material.Wood
	)
	WorldKit.hidingSpot(wardrobe)
	WorldKit.hingedDoor(
		cellar,
		"Wardrobe",
		Vector3.new(2.8, 5.2, 0.25),
		CFrame.new(roomMaxX - 2.65, -5.35, centerZ + 4.8) * CFrame.Angles(0, math.rad(-90), 0),
		WOOD_DARK
	)
	lampFixture(cellar, Vector3.new(roomCenterX, -1.75, centerZ), 15)
end

-- 4. Graveyard behind the church: leaning headstones, iron fence, and a
-- freshly dug open grave (a real pit, carved through the south field).
local function buildGraveyard(root: Model, nightTown: Instance)
	local yard = WorldKit.model(root, "Graveyard")
	-- The open grave: carve a hole in the pack's own south field FIRST (before
	-- any yard furniture is near the query region), line the pit, and pile the
	-- spoil beside it with a planted shovel.
	carveRect(nightTown, root, Vector3.new(-22, -0.5, -470), Vector3.new(7, 1.6, 3.4), true)
	WorldKit.part(yard, "GravePitWallN", Vector3.new(7.4, 3.4, 0.35), CFrame.new(-22, -1.7, -468.45), EARTH, Enum.Material.Ground)
	WorldKit.part(yard, "GravePitWallS", Vector3.new(7.4, 3.4, 0.35), CFrame.new(-22, -1.7, -471.55), EARTH, Enum.Material.Ground)
	WorldKit.part(yard, "GravePitWallE", Vector3.new(0.35, 3.4, 2.9), CFrame.new(-18.75, -1.7, -470), EARTH, Enum.Material.Ground)
	WorldKit.part(yard, "GravePitWallW", Vector3.new(0.35, 3.4, 2.9), CFrame.new(-25.25, -1.7, -470), EARTH, Enum.Material.Ground)
	WorldKit.part(yard, "GravePitFloor", Vector3.new(7, 0.3, 3.2), CFrame.new(-22, -3.35, -470), Color3.fromRGB(52, 42, 30), Enum.Material.Ground)
	WorldKit.part(yard, "GraveSpoilMound", Vector3.new(5, 1.4, 2.6), CFrame.new(-22, 0.7, -466.6) * CFrame.Angles(0, 0.2, 0.06), EARTH, Enum.Material.Ground)
	WorldKit.part(yard, "GraveSpoilTop", Vector3.new(3.4, 0.9, 1.8), CFrame.new(-21.7, 1.5, -466.5) * CFrame.Angles(0, -0.3, 0), EARTH, Enum.Material.Ground)
	WorldKit.part(yard, "ShovelHandle", Vector3.new(0.18, 3.4, 0.18), CFrame.new(-19.4, 1.7, -466.8) * CFrame.Angles(0.28, 0, -0.2), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(yard, "ShovelBlade", Vector3.new(0.7, 0.9, 0.12), CFrame.new(-19.9, 0.5, -466.6) * CFrame.Angles(0.28, 0, -0.2), STEEL, Enum.Material.Metal)
	WorldKit.evidenceSocketMarker(yard, "graveyard-open-grave", Vector3.new(-22, 0.6, -470))
	local stoneColor = Color3.fromRGB(128, 126, 118)
	local headstones: { { x: number, z: number, tilt: number } } = {
		{ x = -28, z = -464.5, tilt = 7 },
		{ x = -24.5, z = -463.8, tilt = -5 },
		{ x = -20, z = -464.2, tilt = 4 },
		{ x = -17, z = -466, tilt = -8 },
		{ x = -28.5, z = -468.5, tilt = -4 },
		{ x = -28, z = -472.5, tilt = 9 },
		{ x = -27.5, z = -476.3, tilt = -6 },
		{ x = -23.5, z = -474.8, tilt = 5 },
		{ x = -19.5, z = -476.5, tilt = -3 },
		{ x = -16.8, z = -473.8, tilt = 6 },
		{ x = -9, z = -475.5, tilt = -7 },
		{ x = -4, z = -476.6, tilt = 4 },
		{ x = 1, z = -475.2, tilt = -5 },
		{ x = 6, z = -476.8, tilt = 8 },
	}
	for index, stone in headstones do
		WorldKit.part(
			yard,
			"Headstone" .. tostring(index),
			Vector3.new(1.5, 2.1, 0.35),
			CFrame.new(stone.x, 1.05, stone.z)
				* CFrame.Angles(math.rad((index % 3 - 1) * 3), 0, math.rad(stone.tilt)),
			stoneColor,
			Enum.Material.Concrete
		)
	end
	-- Iron fence: west run, south run, and a gated north run facing the church.
	local fenceIron = Color3.fromRGB(56, 52, 48)
	local posts = {
		Vector3.new(-30, 0, -462), Vector3.new(-30, 0, -470), Vector3.new(-30, 0, -478),
		Vector3.new(-20.5, 0, -478), Vector3.new(-11, 0, -478), Vector3.new(-1.5, 0, -478),
		Vector3.new(8, 0, -478), Vector3.new(-24, 0, -462), Vector3.new(-16, 0, -462),
	}
	for _, postPos in posts do
		WorldKit.part(
			yard,
			"YardFencePost",
			Vector3.new(0.35, 2.8, 0.35),
			CFrame.new(postPos + Vector3.new(0, 1.4, 0)),
			fenceIron,
			Enum.Material.CorrodedMetal
		)
	end
	local spans: { { from: Vector3, to: Vector3 } } = {
		{ from = Vector3.new(-30, 0, -462), to = Vector3.new(-30, 0, -470) },
		{ from = Vector3.new(-30, 0, -470), to = Vector3.new(-30, 0, -478) },
		{ from = Vector3.new(-30, 0, -478), to = Vector3.new(-20.5, 0, -478) },
		{ from = Vector3.new(-20.5, 0, -478), to = Vector3.new(-11, 0, -478) },
		{ from = Vector3.new(-11, 0, -478), to = Vector3.new(-1.5, 0, -478) },
		{ from = Vector3.new(-1.5, 0, -478), to = Vector3.new(8, 0, -478) },
		{ from = Vector3.new(-30, 0, -462), to = Vector3.new(-24, 0, -462) },
		{ from = Vector3.new(-16, 0, -462), to = Vector3.new(-14.4, 0, -462) },
	}
	for _, span in spans do
		for _, railY in { 1.05, 1.95 } do
			local delta = span.to - span.from
			local mid = (span.from + span.to) / 2
			WorldKit.part(
				yard,
				"YardFenceRail",
				Vector3.new(math.max(math.abs(delta.X), 0.18), 0.18, math.max(math.abs(delta.Z), 0.18)),
				CFrame.new(mid + Vector3.new(0, railY, 0)),
				fenceIron,
				Enum.Material.CorrodedMetal
			)
		end
	end
end

-- 5. Climbable water tower: caged ladder on the +X face up to a catwalk ring
-- around the tank, with an etched clue plate. Tower base sits at (110, 0, -292).
local function buildWaterTowerClimb(root: Model)
	local tower = WorldKit.model(root, "WaterTowerClimb")
	WorldKit.truss(tower, "CatwalkLadder", Vector3.new(2, 27, 2), CFrame.new(120, 13.5, -292), IRON_DARK)
	for _, hoopY in { 10, 16, 22 } do
		WorldKit.part(tower, "LadderHoopBack", Vector3.new(2.9, 0.3, 0.3), CFrame.new(121.6, hoopY, -292) * CFrame.Angles(0, math.rad(90), 0), RUST, Enum.Material.CorrodedMetal).CanCollide = false
		for side = -1, 1, 2 do
			WorldKit.part(
				tower,
				"LadderHoopSide",
				Vector3.new(1.6, 0.3, 0.3),
				CFrame.new(120.7, hoopY, -292 + side * 1.3),
				RUST,
				Enum.Material.CorrodedMetal
			).CanCollide = false
		end
	end
	-- Eight-segment catwalk ring around the tank at y ~26.
	local towerCenter = Vector3.new(110, 0, -292)
	for segment = 0, 7 do
		local angle = math.rad(segment * 45)
		local px = towerCenter.X + math.cos(angle) * 8.8
		local pz = towerCenter.Z + math.sin(angle) * 8.8
		WorldKit.part(
			tower,
			"CatwalkSegment",
			Vector3.new(7.3, 0.35, 2.8),
			CFrame.new(px, 26.15, pz) * CFrame.Angles(0, math.rad(90) + angle, 0),
			STEEL,
			Enum.Material.DiamondPlate
		)
	end
	-- Railing posts and rails on the outer edge; the +X bay stays open so
	-- players can step off the ladder onto the ring.
	for post = 0, 7 do
		local angle = math.rad(post * 45 + 22.5)
		local px = towerCenter.X + math.cos(angle) * 10.2
		local pz = towerCenter.Z + math.sin(angle) * 10.2
		WorldKit.part(
			tower,
			"CatwalkRailPost",
			Vector3.new(0.3, 2.2, 0.3),
			CFrame.new(px, 27.4, pz),
			IRON_DARK,
			Enum.Material.Metal
		)
	end
	for rail = 1, 7 do
		local angle = math.rad(rail * 45)
		local px = towerCenter.X + math.cos(angle) * 10.2
		local pz = towerCenter.Z + math.sin(angle) * 10.2
		WorldKit.part(
			tower,
			"CatwalkRail",
			Vector3.new(8.2, 0.3, 0.3),
			CFrame.new(px, 28.35, pz) * CFrame.Angles(0, math.rad(90) + angle, 0),
			IRON_DARK,
			Enum.Material.Metal
		)
	end
	-- Etched clue plate on the tank face beside the catwalk.
	local plate = WorldKit.part(
		tower,
		"EtchedPlate",
		Vector3.new(4.6, 1.5, 0.22),
		CFrame.new(110, 26.9, -285.1),
		Color3.fromRGB(88, 94, 96),
		Enum.Material.Metal
	)
	surfaceText(plate, Enum.NormalId.Front, "R.C. + M.H. 1987", Color3.fromRGB(52, 48, 44))
	WorldKit.evidenceSocketMarker(tower, "water-tower-catwalk", Vector3.new(110, 27.3, -283.2))
end

-- 6. Decay details along the main road: newspaper stand, rusted school bus
-- shell, laundry lines behind ResidentialA, and storm-damage dressing.
local function buildDecayDressing(root: Model)
	local decay = WorldKit.model(root, "RoadDecay")
	-- Newspaper stand on the east sidewalk.
	WorldKit.part(decay, "NewsstandBase", Vector3.new(3.2, 2.6, 2.2), CFrame.new(29, 1.95, -150), WOOD, Enum.Material.WoodPlanks)
	WorldKit.part(decay, "NewsstandRoof", Vector3.new(3.8, 0.3, 2.8), CFrame.new(29, 4.75, -150), WOOD_DARK, Enum.Material.WoodPlanks)
	WorldKit.part(decay, "NewsstandPostA", Vector3.new(0.25, 1.5, 0.25), CFrame.new(27.7, 3.85, -149.1), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(decay, "NewsstandPostB", Vector3.new(0.25, 1.5, 0.25), CFrame.new(30.3, 3.85, -149.1), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(decay, "NewsstandPapers", Vector3.new(1.5, 0.5, 1), CFrame.new(28.6, 3.55, -150.1) * CFrame.Angles(0, 0.3, 0), PAPER, Enum.Material.SmoothPlastic)
	local headline = WorldKit.part(
		decay,
		"HeadlineBoard",
		Vector3.new(2.8, 1.8, 0.15),
		CFrame.new(29, 2.4, -148.8),
		PAPER,
		Enum.Material.SmoothPlastic
	)
	surfaceText(headline, Enum.NormalId.Front, "BLACK PINE GAZETTE\nSEARCH CALLED OFF", Color3.fromRGB(38, 34, 30))
	-- Rusted school bus shell, rear opening, hideable back bench.
	local bus = WorldKit.model(decay, "SchoolBusShell")
	local bc = CFrame.new(40, 0, -298) * CFrame.Angles(0, math.rad(12), 0)
	WorldKit.part(bus, "BusFloor", Vector3.new(7.4, 0.35, 23), bc * CFrame.new(0, 1.03, 0), IRON_DARK, Enum.Material.CorrodedMetal)
	for side = -1, 1, 2 do
		WorldKit.part(bus, "BusSideLower", Vector3.new(0.35, 3.1, 23), bc * CFrame.new(side * 3.55, 2.75, 0), RUST, Enum.Material.CorrodedMetal)
		WorldKit.part(bus, "BusSideRail", Vector3.new(0.35, 0.45, 23), bc * CFrame.new(side * 3.55, 6.35, 0), RUST_DEEP, Enum.Material.CorrodedMetal)
		for pillar = -1, 1 do
			WorldKit.part(
				bus,
				"BusPillar",
				Vector3.new(0.35, 2.2, 0.45),
				bc * CFrame.new(side * 3.55, 5.2, pillar * 7.5),
				RUST_DEEP,
				Enum.Material.CorrodedMetal
			)
		end
	end
	WorldKit.part(bus, "BusRoof", Vector3.new(7.8, 0.35, 23.8), bc * CFrame.new(0, 6.75, 0), RUST_DEEP, Enum.Material.CorrodedMetal)
	WorldKit.part(bus, "BusFront", Vector3.new(7.4, 5.4, 0.4), bc * CFrame.new(0, 3.9, -11.3), RUST, Enum.Material.CorrodedMetal)
	WorldKit.part(bus, "BusWindshield", Vector3.new(5.4, 1.7, 0.15), bc * CFrame.new(0, 5.2, -11.05), GLASS_DARK, Enum.Material.Glass).CanCollide = false
	WorldKit.part(bus, "BusHood", Vector3.new(6.6, 1.7, 3), bc * CFrame.new(0, 1.9, -13), RUST, Enum.Material.CorrodedMetal)
	for _, wheelOffset in { Vector3.new(-3.6, 1.05, -8), Vector3.new(3.6, 1.05, -8), Vector3.new(-3.6, 1.05, 8), Vector3.new(3.6, 1.05, 8) } do
		WorldKit.part(
			bus,
			"BusWheel",
			Vector3.new(0.7, 2.1, 2.1),
			bc * CFrame.new(wheelOffset),
			IRON_DARK,
			Enum.Material.Rubber,
			Enum.PartType.Cylinder
		)
	end
	local seatSpots: { { x: number, z: number } } = {
		{ x = -1.7, z = -4 }, { x = 1.7, z = -1 }, { x = -1.7, z = 2 }, { x = 1.7, z = 5 },
	}
	for _, seat in seatSpots do
		WorldKit.part(
			bus,
			"BusBench",
			Vector3.new(2.8, 0.95, 1.3),
			bc * CFrame.new(seat.x, 1.75, seat.z),
			Color3.fromRGB(70, 60, 48),
			Enum.Material.Fabric
		)
	end
	local rearBench = WorldKit.part(bus, "BusRearBench", Vector3.new(6.8, 0.95, 1.4), bc * CFrame.new(0, 1.75, 9.5), Color3.fromRGB(70, 60, 48), Enum.Material.Fabric)
	WorldKit.hidingSpot(rearBench)
	WorldKit.part(bus, "BusDriverSeat", Vector3.new(1.9, 0.95, 1.3), bc * CFrame.new(-2, 1.75, -9.5), Color3.fromRGB(70, 60, 48), Enum.Material.Fabric)
	WorldKit.part(bus, "BusSteering", Vector3.new(0.25, 1.4, 0.25), bc * CFrame.new(-2, 3, -10.5) * CFrame.Angles(0.5, 0, 0), IRON_DARK, Enum.Material.Metal).CanCollide = false
	-- Laundry lines between ResidentialA's south wall and two new poles.
	local laundry = WorldKit.model(decay, "LaundryLines")
	for _, poleX in { -106, -96 } do
		WorldKit.part(laundry, "LaundryPole", Vector3.new(0.35, 7.5, 0.35), CFrame.new(poleX, 3.75, -166), WOOD_DARK, Enum.Material.Wood)
		WorldKit.part(laundry, "LaundryCrossbar", Vector3.new(2.6, 0.3, 0.3), CFrame.new(poleX, 7.2, -166), WOOD_DARK, Enum.Material.Wood)
		WorldKit.part(laundry, "LaundryLine", Vector3.new(0.12, 0.12, 15.6), CFrame.new(poleX, 7.35, -157.8), Color3.fromRGB(170, 164, 150), Enum.Material.Fabric).CanCollide = false
		for cloth = 1, 3 do
			local hang = WorldKit.part(
				laundry,
				"LaundryCloth",
				Vector3.new(1.9, 2.3, 0.12),
				CFrame.new(poleX, 6.2, -151.5 - cloth * 4.4) * CFrame.Angles(0, math.rad(90), 0),
				if cloth == 2 then Color3.fromRGB(120, 108, 92) else CLOTH,
				Enum.Material.Fabric
			)
			hang.CanCollide = false
		end
	end
	-- Storm-damage dressing item: a rain barrel blown onto its side.
	local barrel = WorldKit.part(
		decay,
		"TippedRainBarrel",
		Vector3.new(2.2, 2, 2),
		CFrame.new(-100, 1.05, -162.5) * CFrame.Angles(0, 0.6, math.rad(90)),
		WOOD_DARK,
		Enum.Material.WoodPlanks,
		Enum.PartType.Cylinder
	)
	WorldKit.stormDamage(barrel)
end

-- 7. Town square east of the crossroads: cracked plaza, dry three-tier
-- fountain, notice board with missing posters, benches, storm dressing.
local function buildTownSquare(root: Model)
	local square = WorldKit.model(root, "TownSquare")
	WorldKit.part(
		square,
		"PlazaSlab",
		Vector3.new(38, 0.5, 38),
		CFrame.new(21, 0.6, -190),
		Color3.fromRGB(84, 84, 80),
		Enum.Material.Cobblestone
	)
	local crackSpots: { { x: number, z: number, len: number, yaw: number } } = {
		{ x = 12, z = -184, len = 9, yaw = 0.6 },
		{ x = 27, z = -196, len = 12, yaw = -0.9 },
		{ x = 33, z = -182, len = 6, yaw = 1.8 },
		{ x = 9, z = -200, len = 7, yaw = 0.2 },
	}
	for _, crack in crackSpots do
		WorldKit.part(
			square,
			"PlazaCrack",
			Vector3.new(0.35, 0.06, crack.len),
			CFrame.new(crack.x, 0.88, crack.z) * CFrame.Angles(0, crack.yaw, 0),
			Color3.fromRGB(38, 40, 38),
			Enum.Material.Slate
		).CanCollide = false
	end
	-- Dry three-tier fountain.
	local basinColor = CONCRETE
	local function fountainDisc(name: string, size: Vector3, y: number)
		WorldKit.part(
			square,
			name,
			size,
			CFrame.new(21, y, -190) * CFrame.Angles(0, 0, math.rad(90)),
			basinColor,
			Enum.Material.Concrete,
			Enum.PartType.Cylinder
		)
	end
	fountainDisc("FountainBasin", Vector3.new(1.6, 13, 13), 1.65)
	fountainDisc("FountainDryFloor", Vector3.new(0.3, 11.6, 11.6), 1.0)
	fountainDisc("FountainStainRing", Vector3.new(0.06, 9, 9), 1.2)
	fountainDisc("FountainPedestal", Vector3.new(2.2, 1.6, 1.6), 1.95)
	fountainDisc("FountainBowlMid", Vector3.new(0.5, 6, 6), 3.3)
	fountainDisc("FountainStemUpper", Vector3.new(1.6, 1, 1), 4.35)
	fountainDisc("FountainBowlTop", Vector3.new(0.4, 3.2, 3.2), 5.35)
	WorldKit.part(square, "FountainFinial", Vector3.new(0.9, 0.9, 0.9), CFrame.new(21, 6, -190), basinColor, Enum.Material.Concrete, Enum.PartType.Ball)
	WorldKit.part(
		square,
		"FountainBrokenChunk",
		Vector3.new(2.4, 0.5, 1.8),
		CFrame.new(18.6, 1.5, -192.2) * CFrame.Angles(0.3, 0.8, 0.15),
		basinColor,
		Enum.Material.Concrete
	)
	-- Notice board with three missing-poster frames.
	WorldKit.part(square, "NoticePostA", Vector3.new(0.4, 6, 0.4), CFrame.new(6.6, 3.85, -204), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(square, "NoticePostB", Vector3.new(0.4, 6, 0.4), CFrame.new(9.4, 3.85, -204), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(square, "NoticeBoard", Vector3.new(5.2, 3.4, 0.3), CFrame.new(8, 5, -204), WOOD, Enum.Material.WoodPlanks)
	local posterLines = {
		"MISSING\nR. CALLOWAY\nLAST SEEN 6/12/87",
		"MISSING\nM. HALE\nLAST SEEN 6/12/87",
		"REWARD\nINFORMATION WANTED\nBLACK PINE SHERIFF",
	}
	for index, posterText in posterLines do
		local poster = WorldKit.part(
			square,
			"MissingPoster" .. tostring(index),
			Vector3.new(1.4, 2.4, 0.12),
			CFrame.new(6.7 + (index - 1) * 1.3, 5, -203.75),
			PAPER,
			Enum.Material.SmoothPlastic
		)
		poster.CanCollide = false
		surfaceText(poster, Enum.NormalId.Back, posterText, Color3.fromRGB(44, 38, 32))
	end
	-- Two benches facing the fountain.
	local benchSpots: { { x: number, z: number, yaw: number } } = {
		{ x = 12, z = -181, yaw = 25 },
		{ x = 31, z = -199, yaw = -155 },
	}
	for _, spot in benchSpots do
		local benchCFrame = CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad(spot.yaw), 0)
		WorldKit.part(square, "BenchSeat", Vector3.new(4.4, 0.35, 1.5), benchCFrame * CFrame.new(0, 1.9, 0), WOOD, Enum.Material.WoodPlanks)
		WorldKit.part(square, "BenchBack", Vector3.new(4.4, 1.3, 0.3), benchCFrame * CFrame.new(0, 2.9, 0.75), WOOD, Enum.Material.WoodPlanks)
		WorldKit.part(square, "BenchLegA", Vector3.new(0.4, 1.1, 1.4), benchCFrame * CFrame.new(-1.8, 1.3, 0), WOOD_DARK, Enum.Material.Wood)
		WorldKit.part(square, "BenchLegB", Vector3.new(0.4, 1.1, 1.4), benchCFrame * CFrame.new(1.8, 1.3, 0), WOOD_DARK, Enum.Material.Wood)
	end
	-- Market stall whose tarp is storm dressing, plus a fallen branch.
	local stallCFrame = CFrame.new(33.5, 0, -184)
	for cornerX = -1, 1, 2 do
		for cornerZ = -1, 1, 2 do
			WorldKit.part(
				square,
				"StallLeg",
				Vector3.new(0.35, 5, 0.35),
				stallCFrame * CFrame.new(cornerX * 2.1, 3.35, cornerZ * 1.5),
				WOOD_DARK,
				Enum.Material.Wood
			)
		end
	end
	WorldKit.part(square, "StallCounter", Vector3.new(4.6, 0.4, 3.4), stallCFrame * CFrame.new(0, 3, 0), PLANK, Enum.Material.WoodPlanks)
	WorldKit.part(square, "StallCrate", Vector3.new(1.8, 1.8, 1.8), stallCFrame * CFrame.new(-0.8, 1.75, 0.3), PLANK, Enum.Material.WoodPlanks)
	local tarp = WorldKit.part(
		square,
		"StallTarp",
		Vector3.new(5.4, 0.25, 4.2),
		stallCFrame * CFrame.new(0, 6.1, 0) * CFrame.Angles(math.rad(8), 0, math.rad(-4)),
		Color3.fromRGB(96, 92, 74),
		Enum.Material.Fabric
	)
	tarp.CanCollide = false
	WorldKit.stormDamage(tarp)
	local branchMain = WorldKit.part(
		square,
		"FallenBranch",
		Vector3.new(0.5, 5.2, 0.5),
		CFrame.new(14, 1.05, -199) * CFrame.Angles(0, 0.7, math.rad(87)),
		Color3.fromRGB(52, 44, 36),
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	WorldKit.stormDamage(branchMain)
	local branchFork = WorldKit.part(
		square,
		"FallenBranchFork",
		Vector3.new(0.35, 3.2, 0.35),
		CFrame.new(15.6, 1.0, -197.8) * CFrame.Angles(0, 1.5, math.rad(80)),
		Color3.fromRGB(52, 44, 36),
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	WorldKit.stormDamage(branchFork)
	WorldKit.evidenceSocketMarker(square, "town-square-fountain", Vector3.new(21, 1.8, -187))
end

-- 8. Drive-in theater ruin: torn screen, speaker posts, three rusted car
-- shells with hideable interiors, and a projector shack.
local function buildDriveInRuin(root: Model)
	local driveIn = WorldKit.model(root, "DriveInRuin")
	-- Torn screen: two offset white slabs on posts, plus a base wall.
	WorldKit.part(driveIn, "ScreenMain", Vector3.new(26, 15, 0.8), CFrame.new(76, 9.3, -451.5), SCREEN_WHITE, Enum.Material.Concrete)
	WorldKit.part(driveIn, "ScreenTorn", Vector3.new(13, 9, 0.8), CFrame.new(91.5, 6.3, -450.6) * CFrame.Angles(0, math.rad(4), 0), SCREEN_WHITE, Enum.Material.Concrete)
	WorldKit.part(driveIn, "ScreenBase", Vector3.new(28, 2.5, 1), CFrame.new(80, 1.25, -452.3), CONCRETE, Enum.Material.Concrete)
	for _, postX in { 66, 78, 90 } do
		WorldKit.part(driveIn, "ScreenPost", Vector3.new(0.8, 14, 0.8), CFrame.new(postX, 7, -452.8), IRON_DARK, Enum.Material.Metal)
	end
	-- Speaker posts in two ragged rows.
	local speakerSpots: { { x: number, z: number } } = {
		{ x = 62, z = -424 }, { x = 72, z = -425 }, { x = 82, z = -424 },
		{ x = 62, z = -433 }, { x = 72, z = -434 }, { x = 82, z = -433 },
	}
	for _, spot in speakerSpots do
		WorldKit.part(driveIn, "SpeakerPost", Vector3.new(0.3, 3.4, 0.3), CFrame.new(spot.x, 1.7, spot.z), IRON_DARK, Enum.Material.Metal)
		WorldKit.part(driveIn, "SpeakerBox", Vector3.new(0.9, 0.7, 0.5), CFrame.new(spot.x, 3.5, spot.z), RUST, Enum.Material.CorrodedMetal)
	end
	-- Rusted car shells, each with an openable door and a hideable bench seat.
	local carSpots: { { x: number, z: number, yaw: number } } = {
		{ x = 63, z = -429, yaw = 8 },
		{ x = 79, z = -432, yaw = -6 },
		{ x = 96, z = -428, yaw = 14 },
	}
	for index, spot in carSpots do
		local car = WorldKit.model(driveIn, "RustedCar" .. tostring(index))
		local cc = CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad(spot.yaw), 0)
		WorldKit.part(car, "CarBody", Vector3.new(8.6, 1.5, 4.6), cc * CFrame.new(0, 1.25, 0), RUST, Enum.Material.CorrodedMetal)
		WorldKit.part(car, "CarRoof", Vector3.new(4.4, 0.25, 4.2), cc * CFrame.new(-0.4, 4.4, 0), RUST_DEEP, Enum.Material.CorrodedMetal)
		WorldKit.part(car, "CarBackPanel", Vector3.new(0.3, 2.4, 4.2), cc * CFrame.new(1.8, 3.15, 0), RUST, Enum.Material.CorrodedMetal)
		WorldKit.part(car, "CarWindshield", Vector3.new(0.15, 2.2, 4), cc * CFrame.new(-2.5, 3.2, 0) * CFrame.Angles(0, 0, math.rad(-18)), GLASS_DARK, Enum.Material.Glass).CanCollide = false
		local seat = WorldKit.part(car, "CarSeat", Vector3.new(2, 0.8, 3.6), cc * CFrame.new(0.4, 2.4, 0), Color3.fromRGB(76, 64, 50), Enum.Material.Fabric)
		WorldKit.hidingSpot(seat)
		WorldKit.hingedDoor(
			car,
			"Rusted Door",
			Vector3.new(2.6, 2.2, 0.25),
			cc * CFrame.new(-0.2, 3.1, -2.35),
			RUST_DEEP
		)
		for _, wheelOffset in { Vector3.new(-2.7, 0.9, -2), Vector3.new(2.7, 0.9, -2), Vector3.new(-2.7, 0.9, 2), Vector3.new(2.7, 0.9, 2) } do
			WorldKit.part(
				car,
				"CarWheel",
				Vector3.new(0.6, 1.8, 1.8),
				cc * CFrame.new(wheelOffset) * CFrame.Angles(0, math.rad(90), 0),
				IRON_DARK,
				Enum.Material.Rubber,
				Enum.PartType.Cylinder
			).CanCollide = false
		end
	end
	-- Projector shack in the northeast corner, aimed at the screen.
	local shack = WorldKit.model(driveIn, "ProjectorShack")
	local shackFloor = WorldKit.part(shack, "ShackFloor", Vector3.new(7, 0.5, 7), CFrame.new(104, 0.5, -419.5), WOOD_DARK, Enum.Material.WoodPlanks)
	WorldKit.creakyFloor(shackFloor)
	WorldKit.part(shack, "ShackWallNA", Vector3.new(2.4, 6.5, 0.4), CFrame.new(101.9, 4, -416.4), WOOD, Enum.Material.WoodPlanks)
	WorldKit.part(shack, "ShackWallNB", Vector3.new(2.4, 6.5, 0.4), CFrame.new(106.1, 4, -416.4), WOOD, Enum.Material.WoodPlanks)
	WorldKit.part(shack, "ShackWallE", Vector3.new(0.4, 6.5, 7), CFrame.new(107.3, 4, -419.5), WOOD, Enum.Material.WoodPlanks)
	WorldKit.part(shack, "ShackWallW", Vector3.new(0.4, 6.5, 7), CFrame.new(100.7, 4, -419.5), WOOD, Enum.Material.WoodPlanks)
	WorldKit.part(shack, "ShackWallS", Vector3.new(7, 6.5, 0.4), CFrame.new(104, 4, -422.6), WOOD, Enum.Material.WoodPlanks)
	WorldKit.part(shack, "ShackRoof", Vector3.new(8, 0.4, 8), CFrame.new(104, 7.45, -419.5), SLATE, Enum.Material.CorrodedMetal)
	WorldKit.part(shack, "ProjectionSlot", Vector3.new(2, 1.2, 0.15), CFrame.new(104, 4.4, -422.85), Color3.fromRGB(22, 24, 26), Enum.Material.SmoothPlastic).CanCollide = false
	-- Projector, reels, and work table.
	WorldKit.part(shack, "ProjectorStand", Vector3.new(0.6, 2.6, 0.6), CFrame.new(104, 2.05, -421.2), IRON_DARK, Enum.Material.Metal)
	WorldKit.part(shack, "ProjectorBody", Vector3.new(1.8, 1.2, 1.1), CFrame.new(104, 3.95, -421.2), STEEL, Enum.Material.Metal)
	WorldKit.part(shack, "ProjectorLens", Vector3.new(0.5, 0.7, 0.7), CFrame.new(104, 3.95, -421.95) * CFrame.Angles(0, math.rad(90), 0), IRON_DARK, Enum.Material.Metal, Enum.PartType.Cylinder).CanCollide = false
	for _, reelZ in { -420.8, -421.6 } do
		WorldKit.part(
			shack,
			"ProjectorReel",
			Vector3.new(0.2, 1.4, 1.4),
			CFrame.new(104, 5.2, reelZ) * CFrame.Angles(0, math.rad(90), 0),
			RUST,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		).CanCollide = false
	end
	WorldKit.part(shack, "FilmTable", Vector3.new(2.8, 0.3, 1.6), CFrame.new(106.2, 2.8, -418), PLANK, Enum.Material.WoodPlanks)
	WorldKit.part(
		shack,
		"FilmCanister",
		Vector3.new(0.25, 1.1, 1.1),
		CFrame.new(106.2, 3.1, -417.8) * CFrame.Angles(0, 0, math.rad(90)),
		STEEL,
		Enum.Material.Metal
	).CanCollide = false
	lampFixture(shack, Vector3.new(104, 6.6, -419.5), 12)
	WorldKit.evidenceSocketMarker(shack, "drive-in-projector", Vector3.new(104, 2.6, -420.6))
end

-- 9. Train line along the west edge: ballast, sleepers, rails, a tilted
-- derailed boxcar you can enter, a sealed boxcar, and a buffer stop.
local function buildTrainTracks(root: Model)
	local tracks = WorldKit.model(root, "TrainTracks")
	WorldKit.part(tracks, "TrackBallast", Vector3.new(11, 0.3, 302), CFrame.new(-146, 0.15, -250), Color3.fromRGB(70, 66, 60), Enum.Material.Ground)
	local sleeperZ = -102
	while sleeperZ >= -398 do
		WorldKit.part(
			tracks,
			"Sleeper",
			Vector3.new(7.2, 0.35, 1.4),
			CFrame.new(-146, 0.48, sleeperZ),
			WOOD_DARK,
			Enum.Material.WoodPlanks
		)
		sleeperZ -= 6
	end
	for side = -1, 1, 2 do
		WorldKit.part(
			tracks,
			"Rail",
			Vector3.new(0.4, 0.55, 300),
			CFrame.new(-146 + side * 2.35, 0.93, -250),
			RUST,
			Enum.Material.CorrodedMetal
		)
	end
	-- Derailed boxcar: tilted off the rails, open east side, hideable crate.
	local wreck = WorldKit.model(tracks, "DerailedBoxcar")
	local wc = CFrame.new(-147, 1.45, -225)
		* CFrame.Angles(0, math.rad(18), 0)
		* CFrame.Angles(0, 0, math.rad(-8))
	WorldKit.part(wreck, "BoxcarFloor", Vector3.new(7.8, 0.5, 21), wc, WOOD_DARK, Enum.Material.WoodPlanks)
	WorldKit.part(wreck, "BoxcarSideW", Vector3.new(0.4, 8, 21), wc * CFrame.new(-3.7, 4.25, 0), RUST_DEEP, Enum.Material.CorrodedMetal)
	WorldKit.part(wreck, "BoxcarSideStubN", Vector3.new(0.4, 8, 5), wc * CFrame.new(3.7, 4.25, -8), RUST_DEEP, Enum.Material.CorrodedMetal)
	WorldKit.part(wreck, "BoxcarSideStubS", Vector3.new(0.4, 8, 5), wc * CFrame.new(3.7, 4.25, 8), RUST_DEEP, Enum.Material.CorrodedMetal)
	WorldKit.part(wreck, "BoxcarEndN", Vector3.new(7.8, 8, 0.4), wc * CFrame.new(0, 4.25, -10.7), RUST_DEEP, Enum.Material.CorrodedMetal)
	WorldKit.part(wreck, "BoxcarEndS", Vector3.new(7.8, 8, 0.4), wc * CFrame.new(0, 4.25, 10.7), RUST_DEEP, Enum.Material.CorrodedMetal)
	WorldKit.part(wreck, "BoxcarRoof", Vector3.new(8.2, 0.4, 21.6), wc * CFrame.new(0, 8.45, 0), IRON_DARK, Enum.Material.CorrodedMetal)
	for _, bogieZ in { -7, 7 } do
		WorldKit.part(wreck, "BoxcarBogie", Vector3.new(5, 1.2, 2.6), wc * CFrame.new(0, -0.85, bogieZ), IRON_DARK, Enum.Material.Metal)
	end
	local wreckCrate = WorldKit.part(wreck, "BoxcarCrate", Vector3.new(2.2, 2.2, 2.2), wc * CFrame.new(-1.8, 1.35, -6) * CFrame.Angles(0, 0.5, 0), PLANK, Enum.Material.WoodPlanks)
	WorldKit.hidingSpot(wreckCrate)
	WorldKit.part(wreck, "BoxcarStraw", Vector3.new(3, 0.4, 4), wc * CFrame.new(1, 0.45, 4), Color3.fromRGB(130, 110, 62), Enum.Material.Grass).CanCollide = false
	WorldKit.evidenceSocketMarker(wreck, "derailed-boxcar", (wc * CFrame.new(0, 1.6, 0)).Position)
	-- Sealed boxcar still on the rails.
	local sealed = WorldKit.model(tracks, "SealedBoxcar")
	local sc = CFrame.new(-146, 1.7, -318)
	WorldKit.part(sealed, "BoxcarFloor", Vector3.new(7.8, 0.5, 21), sc, WOOD_DARK, Enum.Material.WoodPlanks)
	for side = -1, 1, 2 do
		WorldKit.part(sealed, "BoxcarSide", Vector3.new(0.4, 8, 21), sc * CFrame.new(side * 3.7, 4.25, 0), RUST_DEEP, Enum.Material.CorrodedMetal)
		WorldKit.part(sealed, "BoxcarEnd", Vector3.new(7.8, 8, 0.4), sc * CFrame.new(0, 4.25, side * 10.7), RUST_DEEP, Enum.Material.CorrodedMetal)
		WorldKit.part(sealed, "BoxcarBogie", Vector3.new(5, 1.2, 2.6), sc * CFrame.new(0, -0.85, side * 7), IRON_DARK, Enum.Material.Metal)
	end
	WorldKit.part(sealed, "BoxcarRoof", Vector3.new(8.2, 0.4, 21.6), sc * CFrame.new(0, 8.45, 0), IRON_DARK, Enum.Material.CorrodedMetal)
	local railLabel = WorldKit.part(
		sealed,
		"BoxcarLabel",
		Vector3.new(0.2, 2.2, 7),
		sc * CFrame.new(3.95, 4.6, 0),
		Color3.fromRGB(120, 112, 100),
		Enum.Material.SmoothPlastic
	)
	railLabel.CanCollide = false
	surfaceText(railLabel, Enum.NormalId.Right, "PROPERTY OF N&W RAIL", Color3.fromRGB(40, 36, 32))
	-- Buffer stop at the south end of the line.
	local stop = WorldKit.model(tracks, "BufferStop")
	for side = -1, 1, 2 do
		WorldKit.part(
			stop,
			"BufferBeam",
			Vector3.new(0.5, 0.5, 4.6),
			CFrame.new(-146 + side * 1.8, 1.6, -396.4) * CFrame.Angles(math.rad(-40), 0, 0),
			RUST,
			Enum.Material.CorrodedMetal
		)
		WorldKit.part(stop, "BufferBase", Vector3.new(1.2, 1, 2.4), CFrame.new(-146 + side * 1.8, 0.5, -395.6), IRON_DARK, Enum.Material.Metal)
	end
	WorldKit.part(stop, "BufferCross", Vector3.new(5, 0.8, 0.8), CFrame.new(-146, 2.9, -397.6), RUST, Enum.Material.CorrodedMetal)
end

-- 10. Caretaker's junkyard behind the factory: corrugated fence ring with one
-- gap, winding lanes between scrap islands, an overhead crane hook, and a few
-- knockable cans and hubcaps.
local function buildJunkyard(root: Model)
	local junkyard = WorldKit.model(root, "CaretakerJunkyard")
	local corrugated = Color3.fromRGB(104, 88, 70)
	-- Fence panels: west run, north run (with the entrance gap), south run.
	for panel = 0, 6 do
		WorldKit.part(
			junkyard,
			"JunkFenceW",
			Vector3.new(0.35, 5, 6.2),
			CFrame.new(-140.3, 2.5, -258.4 - panel * 6.1),
			corrugated,
			Enum.Material.CorrodedMetal
		)
	end
	for _, panelX in { -137.2, -131 } do
		WorldKit.part(junkyard, "JunkFenceN", Vector3.new(6.2, 5, 0.35), CFrame.new(panelX, 2.5, -255.2), corrugated, Enum.Material.CorrodedMetal)
	end
	for _, panelX in { -137.2, -131 } do
		WorldKit.part(junkyard, "JunkFenceS", Vector3.new(6.2, 5, 0.35), CFrame.new(panelX, 2.5, -294.8), corrugated, Enum.Material.CorrodedMetal)
	end
	-- Shorter closing panel so the run stops flush at the factory's back wall.
	WorldKit.part(junkyard, "JunkFenceSEnd", Vector3.new(5, 5, 0.35), CFrame.new(-125.4, 2.5, -294.8), corrugated, Enum.Material.CorrodedMetal)
	WorldKit.part(junkyard, "JunkGatePostA", Vector3.new(0.5, 5.5, 0.5), CFrame.new(-127.9, 2.75, -255.2), IRON_DARK, Enum.Material.Metal)
	WorldKit.part(junkyard, "JunkGatePostB", Vector3.new(0.5, 5.5, 0.5), CFrame.new(-124.1, 2.75, -255.2), IRON_DARK, Enum.Material.Metal)
	-- Scrap islands that bend the lanes (chase-breaking geometry).
	WorldKit.part(junkyard, "ApplianceBoxA", Vector3.new(3, 3.4, 2.6), CFrame.new(-135, 1.7, -261) * CFrame.Angles(0, 0.3, 0), STEEL, Enum.Material.Metal)
	WorldKit.part(junkyard, "ApplianceBoxB", Vector3.new(2.6, 2.8, 2.4), CFrame.new(-134.7, 4.8, -261.2) * CFrame.Angles(0, -0.2, 0.05), Color3.fromRGB(118, 118, 112), Enum.Material.Metal)
	WorldKit.part(junkyard, "ApplianceBoxC", Vector3.new(2.4, 3, 2.2), CFrame.new(-132.2, 1.5, -262.4) * CFrame.Angles(0, 0.8, 0), RUST, Enum.Material.CorrodedMetal)
	WorldKit.part(junkyard, "CrushedCarBase", Vector3.new(7, 1.6, 3.6), CFrame.new(-127.5, 0.85, -267) * CFrame.Angles(0, math.rad(10), 0.04), RUST, Enum.Material.CorrodedMetal)
	WorldKit.part(junkyard, "CrushedCarCabin", Vector3.new(3.6, 0.9, 3.2), CFrame.new(-128, 2.1, -267.2) * CFrame.Angles(0, math.rad(10), 0), RUST_DEEP, Enum.Material.CorrodedMetal)
	WorldKit.part(
		junkyard,
		"CrushedCarTire",
		Vector3.new(0.7, 2.2, 2.2),
		CFrame.new(-124.9, 1.1, -265.4) * CFrame.Angles(0, 0.4, math.rad(80)),
		IRON_DARK,
		Enum.Material.Rubber,
		Enum.PartType.Cylinder
	)
	for tier = 1, 3 do
		WorldKit.part(
			junkyard,
			"TirePile",
			Vector3.new(0.75, 2.6 - tier * 0.2, 2.6 - tier * 0.2),
			CFrame.new(-135.5 + (tier % 2) * 0.3, 0.85 + (tier - 1) * 0.72, -274)
				* CFrame.Angles(0, tier * 0.7, math.rad(90)),
			IRON_DARK,
			Enum.Material.Rubber,
			Enum.PartType.Cylinder
		)
	end
	WorldKit.part(junkyard, "OldFridge", Vector3.new(2.2, 5, 2.2), CFrame.new(-128, 2.5, -281) * CFrame.Angles(0, 0.2, 0), Color3.fromRGB(132, 130, 122), Enum.Material.Metal)
	WorldKit.part(junkyard, "OldWasher", Vector3.new(2, 2.6, 2), CFrame.new(-130.6, 1.3, -281.8) * CFrame.Angles(0, -0.5, 0), STEEL, Enum.Material.Metal)
	WorldKit.part(junkyard, "OldStove", Vector3.new(2.2, 2.8, 2.2), CFrame.new(-127.6, 1.4, -283.9) * CFrame.Angles(0, 0.9, 0), RUST, Enum.Material.CorrodedMetal)
	WorldKit.part(junkyard, "ScrapCrate", Vector3.new(2.8, 2.8, 2.8), CFrame.new(-135.5, 1.4, -288) * CFrame.Angles(0, 0.4, 0), PLANK, Enum.Material.WoodPlanks)
	WorldKit.part(junkyard, "EngineBlock", Vector3.new(1.8, 1.6, 1.4), CFrame.new(-133.2, 0.85, -289.4) * CFrame.Angles(0, 1.1, 0), IRON_DARK, Enum.Material.DiamondPlate)
	WorldKit.part(junkyard, "ScrapPallet", Vector3.new(3, 0.3, 3), CFrame.new(-136.4, 0.2, -290.8), WOOD_DARK, Enum.Material.WoodPlanks)
	WorldKit.part(
		junkyard,
		"LeaningSheet",
		Vector3.new(0.25, 5.6, 4.2),
		CFrame.new(-123.4, 2.6, -288) * CFrame.Angles(0, 0, math.rad(14)),
		corrugated,
		Enum.Material.CorrodedMetal
	)
	-- Crane hook overhead, jib cantilevered off the factory side.
	WorldKit.part(junkyard, "CraneColumn", Vector3.new(1.4, 17, 1.4), CFrame.new(-123.6, 8.5, -272), IRON_DARK, Enum.Material.Metal)
	WorldKit.part(junkyard, "CraneJib", Vector3.new(13, 0.8, 0.8), CFrame.new(-130, 16.6, -272), STEEL, Enum.Material.Metal)
	WorldKit.part(junkyard, "CraneCable", Vector3.new(0.15, 6, 0.15), CFrame.new(-135.8, 13.2, -272), Color3.fromRGB(40, 40, 42), Enum.Material.Metal).CanCollide = false
	WorldKit.part(junkyard, "CraneHookShank", Vector3.new(0.3, 1.2, 0.3), CFrame.new(-135.8, 9.6, -272), STEEL, Enum.Material.Metal).CanCollide = false
	WorldKit.part(junkyard, "CraneHookCurl", Vector3.new(0.9, 0.35, 0.35), CFrame.new(-135.6, 9.0, -272) * CFrame.Angles(0, 0, 0.6), STEEL, Enum.Material.Metal).CanCollide = false
	-- Knockable clutter in the lanes (anchored while the town is hidden).
	local canSpots = { Vector3.new(-131, 0.75, -258.5), Vector3.new(-133, 0.75, -284) }
	for _, canPos in canSpots do
		local can = WorldKit.clutter(
			junkyard,
			"JunkCan",
			Vector3.new(0.9, 1.2, 0.9),
			CFrame.new(canPos),
			STEEL,
			Enum.Material.Metal
		)
		can.Shape = Enum.PartType.Cylinder
		makeKnockable(can)
	end
	local hubcapSpots = { Vector3.new(-129, 0.7, -272.5), Vector3.new(-137, 0.7, -269) }
	for _, hubPos in hubcapSpots do
		local hubcap = WorldKit.clutter(
			junkyard,
			"JunkHubcap",
			Vector3.new(0.15, 1.3, 1.3),
			CFrame.new(hubPos) * CFrame.Angles(0, 0, math.rad(80)),
			Color3.fromRGB(150, 148, 142),
			Enum.Material.Metal
		)
		hubcap.Shape = Enum.PartType.Cylinder
		makeKnockable(hubcap)
	end
end

local TownExpansion = {}

function TownExpansion.Build(dayCamp: Instance, nightTown: Instance)
	local _ = dayCamp
	local root = WorldKit.model(nightTown, "TownExpansion")
	buildSouthGround(root)
	buildGeneralStoreInterior(root)
	buildGasStationInterior(root)
	buildPoliceCellBlock(root, nightTown)
	buildFactoryCatwalk(root)
	buildCellar(root, nightTown, "ResidentialCellar", -114, -135.5)
	buildCellar(root, nightTown, "CompanyHouseCellar", -115, -390)
	buildGraveyard(root, nightTown)
	buildWaterTowerClimb(root)
	buildDecayDressing(root)
	buildTownSquare(root)
	buildDriveInRuin(root)
	buildTrainTracks(root)
	buildJunkyard(root)
end

return TownExpansion
