--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local WeatherConfig = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("WeatherConfig")
)
local TerrainDomes = require(script.Parent:WaitForChild("Map"):WaitForChild("TerrainDomes"))

type ObjectiveHandler = (player: Player, objectiveId: string) -> ()
type EvidenceHandler = (player: Player, evidenceId: string) -> boolean
type SideObjectiveHandler = (player: Player, sideObjectiveId: string) -> boolean
-- Deduction-depth handlers wired by the runtime after construction.
type ColdCaseHandler = (player: Player, fileIndex: number) -> string?
type KeyPickupHandler = (player: Player, keyId: string) -> boolean
type LockedRoomHandler = (player: Player, roomId: string) -> (boolean, string?)
type SupplyCacheHandler = (player: Player) -> (boolean, string?)

export type KeySpot = {
	keyId: string,
	position: Vector3,
	objectText: string,
	pickupLine: string,
}

type InteractiveDoor = {
	part: Part,
	prompt: ProximityPrompt,
	closedCFrame: CFrame,
	openCFrame: CFrame,
	isOpen: boolean,
}

type LockedRoom = {
	roomId: string,
	door: BasePart,
	prompt: ProximityPrompt,
	closedCFrame: CFrame,
	openCFrame: CFrame,
	isOpen: boolean,
	showFeedback: (text: string, duration: number?) -> (),
}

type ProductionMapServiceState = {
	mapFolder: Folder,
	dayCamp: Folder,
	nightTown: Folder,
	objectivesFolder: Folder,
	evidenceFolder: Folder,
	evidenceSockets: { BasePart },
	onObjective: ObjectiveHandler,
	onEvidence: EvidenceHandler,
	onSideObjective: SideObjectiveHandler?,
	evidenceClaimed: { [string]: boolean },
	interactiveDoors: { InteractiveDoor },
	weatherId: string,
	weatherSeed: number,
	rainPart: BasePart?,
	-- Incremented to cancel the seeded storm lightning loop.
	stormToken: number,
	sideObjectivePrompts: { [string]: ProximityPrompt },
	sideObjectiveParts: { [string]: BasePart },
	sideObjectiveComplete: { [string]: boolean },
	-- Seeded task pool: which stations are live this round. An empty map means
	-- no round has started yet, so every station counts as active.
	activeObjectiveIds: { [string]: boolean },
	objectivePromptsEnabled: boolean,
	coldCaseHandler: ColdCaseHandler?,
	keyPickupHandler: KeyPickupHandler?,
	lockedRoomHandler: LockedRoomHandler?,
	supplyCacheHandler: SupplyCacheHandler?,
	lockedRooms: { [string]: LockedRoom },
	dayKeysFolder: Folder?,
	supplyCache: BasePart?,
}

local ProductionMapService = {}
ProductionMapService.__index = ProductionMapService

export type ProductionMapService = typeof(
	setmetatable({} :: ProductionMapServiceState, ProductionMapService)
)

local DAY_AMBIENT = Color3.fromRGB(128, 139, 121)
-- Full-moon night: bright enough to read the whole map, cool blue so it
-- still reads as night rather than an underexposed day.
local NIGHT_AMBIENT = Color3.fromRGB(94, 104, 130)
local DOOR_TWEEN = TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- Baseline day fog distances used when weather thickens the air; clear days
-- keep fog pushed out past the horizon.
local DAY_WEATHER_FOG_START = 60
local DAY_WEATHER_FOG_END = 800

local function scaleColor(color: Color3, factor: number): Color3
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end

-- Night side-objective tuning: the mill's fuse box relights the dark lanterns
-- around the industrial pocket; lamp colors flip between these two states.
local FUSE_BOX_RELIGHT_RADIUS = 90
local LANTERN_LIT_COLOR = Color3.fromRGB(255, 208, 140)
local LANTERN_LIT_TRANSPARENCY = 0.22
local LANTERN_DARK_COLOR = Color3.fromRGB(118, 104, 80)
local LANTERN_DARK_TRANSPARENCY = 0.82
local SIDE_OBJECTIVE_LAMP_OFF = Color3.fromRGB(187, 72, 49)
local SIDE_OBJECTIVE_LAMP_ON = Color3.fromRGB(79, 214, 112)

local OBJECTIVES = {
	{
		id = "firewood",
		name = "Stack Firewood",
		position = Vector3.new(-30, 2, -22),
		color = Color3.fromRGB(130, 86, 52),
	},
	{
		id = "generator",
		name = "Repair Generator",
		position = Vector3.new(0, 2, -48),
		color = Color3.fromRGB(93, 105, 99),
	},
	{
		id = "supplies",
		name = "Secure Supplies",
		position = Vector3.new(30, 2, -22),
		color = Color3.fromRGB(109, 94, 56),
	},
	{
		-- The completion platform sits at the top of a climbable course; the
		-- root is placed at position + (0, -1.4, 0), so Y=16.4 puts the
		-- platform floor at Y=15 and humans must traverse the obby to reach
		-- the prompt (bots skip this station — see _GetBotActions).
		id = "ropes",
		name = "Ropes Course",
		position = Vector3.new(58, 16.4, -44),
		color = Color3.fromRGB(139, 98, 52),
	},
	{
		id = "waterpump",
		name = "Prime the Water Pump",
		position = Vector3.new(70, 2, 30),
		color = Color3.fromRGB(74, 96, 108),
	},
	{
		id = "trailclear",
		name = "Clear the Trail",
		position = Vector3.new(12, 2, 54),
		color = Color3.fromRGB(86, 99, 62),
	},
	{
		-- Two-person alibi task: the server requires two campers to lift
		-- within a short window (see GameRuntimeService canoe handlers).
		id = "canoe",
		name = "Canoe Carry",
		position = Vector3.new(74, 2, 64),
		color = Color3.fromRGB(121, 85, 58),
	},
}

local OBJECTIVE_EFFECT_LINES: { [string]: string } = {
	firewood = "Keeps the campfire a safe haven tonight",
	generator = "Powers the camp lights tonight",
	supplies = "Bonus night gear for every camper",
	ropes = "Optional challenge — counts toward camp tasks",
	waterpump = "Camp chore — counts toward camp tasks",
	trailclear = "Camp chore — counts toward camp tasks",
	canoe = "Lift with a buddy — you both earn a verified alibi",
}

-- Per-station prompt presentation; stations without an entry use the default
-- single-press "Complete" interaction.
local OBJECTIVE_PROMPTS: { [string]: { action: string, hold: number } } = {
	firewood = { action = "Chop", hold = 0.35 },
	supplies = { action = "Pick Up Crate", hold = 0.8 },
	canoe = { action = "Lift Together", hold = 0.8 },
}

local WIRE_DEFINITIONS: { { id: string, color: Color3 } } = {
	{ id = "red", color = Color3.fromRGB(203, 74, 61) },
	{ id = "blue", color = Color3.fromRGB(74, 116, 203) },
	{ id = "yellow", color = Color3.fromRGB(214, 183, 78) },
}

local SEARCH_TARGETS = {
	{
		id = "main-road-clue-a",
		name = "Abandoned Sedan",
		position = Vector3.new(-17, 2, -101),
		color = Color3.fromRGB(91, 103, 107),
	},
	{
		id = "residential-bedroom-clue",
		name = "Ransacked Bedroom",
		position = Vector3.new(-108, 3, -154),
		color = Color3.fromRGB(107, 83, 71),
	},
	{
		id = "square-gas-station-clue",
		name = "Gas Station Counter",
		position = Vector3.new(96, 3, -185),
		color = Color3.fromRGB(119, 93, 54),
	},
	{
		id = "industrial-machine-clue",
		name = "Factory Press",
		position = Vector3.new(-105, 4, -268),
		color = Color3.fromRGB(73, 82, 83),
	},
	{
		id = "water-tower-base-clue",
		name = "Water Tower Base",
		position = Vector3.new(112, 2, -290),
		color = Color3.fromRGB(74, 90, 91),
	},
	{
		id = "police-evidence-room-clue",
		name = "Police Evidence Locker",
		position = Vector3.new(95, 3, -360),
		color = Color3.fromRGB(72, 91, 111),
	},
	{
		id = "outskirts-company-house-clue",
		name = "Company House Cellar",
		position = Vector3.new(-102, 3, -384),
		color = Color3.fromRGB(91, 74, 63),
	},
	-- World-expansion search locations (district packs under Services/Map).
	{
		id = "island-firewatch",
		name = "Island Firewatch Ruin",
		position = Vector3.new(103, 9.8, 56.5),
		color = Color3.fromRGB(96, 104, 88),
	},
	{
		id = "waterfall-cave",
		name = "Waterfall Cave",
		position = Vector3.new(80, 3.6, 96),
		color = Color3.fromRGB(88, 108, 122),
	},
	{
		id = "greenhouse-potting-table",
		name = "Greenhouse Potting Table",
		position = Vector3.new(54, 3.3, 46.6),
		color = Color3.fromRGB(96, 122, 84),
	},
	{
		id = "sawmill-blade",
		name = "Sawmill Blade",
		position = Vector3.new(-32, 4.5, -85),
		color = Color3.fromRGB(122, 96, 62),
	},
	{
		id = "cornfield-scarecrow",
		name = "Cornfield Scarecrow",
		position = Vector3.new(62, 5.2, -100),
		color = Color3.fromRGB(140, 124, 72),
	},
	{
		id = "quarters-footlocker",
		name = "Counselor Footlocker",
		-- Terrain surface renders at 2.5 here; at y 2.1 the search glow
		-- spawned buried to its lid (glows copy the socket CFrame verbatim).
		-- Follows REED's footlocker (quarters respaced 2026-08-09).
		position = Vector3.new(-59.7, 4.1, 75.5),
		color = Color3.fromRGB(108, 86, 60),
	},
	{
		id = "infirmary-logbook",
		name = "Infirmary Logbook",
		position = Vector3.new(24, 3.2, 57.5),
		color = Color3.fromRGB(168, 150, 140),
	},
	{
		id = "archery-shed",
		name = "Archery Shed",
		position = Vector3.new(-50.8, 2.2, -71),
		color = Color3.fromRGB(112, 92, 58),
	},
	{
		id = "graveyard-open-grave",
		name = "Open Grave",
		position = Vector3.new(-22, 0.6, -470),
		color = Color3.fromRGB(78, 72, 66),
	},
	{
		id = "water-tower-catwalk",
		name = "Water Tower Catwalk",
		position = Vector3.new(110, 27.3, -283.2),
		color = Color3.fromRGB(84, 98, 100),
	},
	{
		id = "town-square-fountain",
		name = "Dry Fountain",
		position = Vector3.new(21, 1.8, -187),
		color = Color3.fromRGB(120, 120, 112),
	},
	{
		id = "drive-in-projector",
		name = "Drive-In Projector",
		position = Vector3.new(104, 2.6, -420.6),
		color = Color3.fromRGB(96, 84, 78),
	},
	{
		id = "derailed-boxcar",
		name = "Derailed Boxcar",
		position = Vector3.new(-146.8, 3, -225.1),
		color = Color3.fromRGB(110, 68, 52),
	},
	{
		id = "mines-ore-cart",
		name = "Mine Ore Cart",
		position = Vector3.new(104, 2, -48),
		color = Color3.fromRGB(84, 78, 72),
	},
	{
		id = "ranger-station-desk",
		name = "Ranger Station Desk",
		position = Vector3.new(-84.5, 16.8, -62),
		color = Color3.fromRGB(104, 88, 60),
	},
	{
		id = "lookout-cab",
		name = "Lookout Cab",
		position = Vector3.new(0, 35.6, 118),
		color = Color3.fromRGB(118, 104, 76),
	},
	{
		id = "cabin-zero-chimney",
		name = "Cabin Zero Chimney",
		-- On the NW hillside: terrain renders at 5.6 here, so a y-3 socket
		-- put the search glow fully inside the slope.
		position = Vector3.new(-74.5, 6.8, 85.5),
		color = Color3.fromRGB(56, 52, 50),
	},
	{
		id = "crypt-empty-niche",
		name = "Empty Crypt Niche",
		position = Vector3.new(-11, -6, -459),
		color = Color3.fromRGB(92, 92, 98),
	},
	{
		id = "radio-shack-console",
		name = "Radio Shack Console",
		position = Vector3.new(125.6, 3.4, -393),
		color = Color3.fromRGB(90, 96, 108),
	},
	{
		id = "aurora-fire-ring",
		name = "Aurora Fire Ring",
		-- Terrain surface renders at 2.5 on the Aurora bank; y 1.4 buried
		-- the search glow under the grass.
		position = Vector3.new(163, 3.4, 15),
		color = Color3.fromRGB(86, 96, 82),
	},
	-- Fourth expansion (HighFrontier pack): the doubled band's two landmarks.
	{
		id = "frontier-watch-cache",
		name = "Ranger Cache",
		-- Beside the frontier watchtower's base, atop the strapped crate.
		position = Vector3.new(-61.5, 3.4, 373.6),
		color = Color3.fromRGB(94, 102, 84),
	},
	{
		id = "logging-camp-ledger",
		name = "Foreman's Ledger",
		-- Open on its lectern at the old logging camp in the west reach.
		position = Vector3.new(-419, 3.9, 173),
		color = Color3.fromRGB(112, 92, 62),
	},
}

local function createPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createCylinder(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local cylinder = createPart(parent, name, size, cframe, color, material)
	cylinder.Shape = Enum.PartType.Cylinder
	return cylinder
end

local function createWedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Anchored = true
	wedge.Size = size
	wedge.CFrame = cframe
	wedge.Color = color
	wedge.Material = material
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.Parent = parent
	return wedge
end

local function createPrompt(
	parent: BasePart,
	actionText: string,
	objectText: string,
	holdDuration: number?
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdDuration or 0.65
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = true
	prompt.ClickablePrompt = true
	prompt.Parent = parent
	return prompt
end

local function createInspectPrompt(
	parent: BasePart,
	objectText: string,
	response: string
): ProximityPrompt
	local prompt = createPrompt(parent, "Inspect", objectText, 0.45)
	local feedback = Instance.new("BillboardGui")
	feedback.Name = "InteractionFeedback"
	-- Stud-based sizing so world labels shrink with distance on phone screens.
	feedback.Size = UDim2.new(8.5, 0, 2, 0)
	feedback.StudsOffset = Vector3.new(0, 3.5, 0)
	feedback.AlwaysOnTop = true
	feedback.MaxDistance = 45
	feedback.Enabled = false
	feedback.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(13, 17, 16)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.Text = response
	label.TextColor3 = Color3.fromRGB(244, 224, 176)
	label.TextSize = 15
	label.TextWrapped = true
	label.Parent = feedback

	local interactionVersion = 0
	prompt.Triggered:Connect(function()
		interactionVersion += 1
		local version = interactionVersion
		prompt.ActionText = "Inspected"
		feedback.Enabled = true
		task.delay(3, function()
			if prompt.Parent and interactionVersion == version then
				prompt.ActionText = "Inspect"
				feedback.Enabled = false
			end
		end)
	end)
	return prompt
end

-- A reusable transient billboard for props whose response text changes per
-- round (cold case files, locked doors, the supply cache).
local function createFeedbackBillboard(
	parent: BasePart,
	widthOffset: number?
): (text: string, duration: number?) -> ()
	local feedback = Instance.new("BillboardGui")
	feedback.Name = "InteractionFeedback"
	feedback.Size = UDim2.new((widthOffset or 300) / 34, 0, 3, 0)
	feedback.StudsOffset = Vector3.new(0, 4, 0)
	feedback.AlwaysOnTop = true
	feedback.MaxDistance = 45
	feedback.Enabled = false
	feedback.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(13, 17, 16)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(244, 224, 176)
	label.TextSize = 14
	label.TextWrapped = true
	label.Parent = feedback

	local version = 0
	return function(text: string, duration: number?)
		version += 1
		local current = version
		label.Text = text
		feedback.Enabled = true
		task.delay(duration or 4, function()
			if feedback.Parent and version == current then
				feedback.Enabled = false
			end
		end)
	end
end

local function createInteractiveDoor(
	parent: Instance,
	name: string,
	size: Vector3,
	closedCFrame: CFrame,
	color: Color3,
	objectText: string
): InteractiveDoor
	local door = createPart(
		parent,
		name,
		size,
		closedCFrame,
		color,
		Enum.Material.WoodPlanks
	)
	door:SetAttribute("WorldInteraction", "Door")
	local prompt = createPrompt(door, "Open", objectText, 0.15)
	prompt.MaxActivationDistance = 10
	local hinge = CFrame.new(-size.X / 2, 0, 0)
	local openCFrame = closedCFrame
		* hinge
		* CFrame.Angles(0, math.rad(-102), 0)
		* hinge:Inverse()
	local state: InteractiveDoor = {
		part = door,
		prompt = prompt,
		closedCFrame = closedCFrame,
		openCFrame = openCFrame,
		isOpen = false,
	}
	prompt.Triggered:Connect(function()
		state.isOpen = not state.isOpen
		prompt.ActionText = if state.isOpen then "Close" else "Open"
		if state.isOpen then
			door.CanCollide = false
		end
		TweenService:Create(
			door,
			DOOR_TWEEN,
			{ CFrame = if state.isOpen then state.openCFrame else state.closedCFrame }
		):Play()
		if not state.isOpen then
			task.delay(DOOR_TWEEN.Time, function()
				if door.Parent and not state.isOpen then
					door.CanCollide = true
				end
			end)
		end
	end)
	return state
end

local function createSign(parent: BasePart, text: string, accent: Color3)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "LocationSign"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 36
	surface.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(14, 16, 18)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = accent
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = surface
end

local function setFolderVisible(folder: Folder, visible: boolean)
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			local visibleTransparency = descendant:GetAttribute("VisibleTransparency")
			if typeof(visibleTransparency) ~= "number" then
				visibleTransparency = descendant.Transparency
				descendant:SetAttribute("VisibleTransparency", visibleTransparency)
			end
			local visibleCanCollide = descendant:GetAttribute("VisibleCanCollide")
			if typeof(visibleCanCollide) ~= "boolean" then
				visibleCanCollide = descendant.CanCollide
				descendant:SetAttribute("VisibleCanCollide", visibleCanCollide)
			end
			local visibleCanTouch = descendant:GetAttribute("VisibleCanTouch")
			if typeof(visibleCanTouch) ~= "boolean" then
				visibleCanTouch = descendant.CanTouch
				descendant:SetAttribute("VisibleCanTouch", visibleCanTouch)
			end
			local visibleCanQuery = descendant:GetAttribute("VisibleCanQuery")
			if typeof(visibleCanQuery) ~= "boolean" then
				visibleCanQuery = descendant.CanQuery
				descendant:SetAttribute("VisibleCanQuery", visibleCanQuery)
			end
			descendant.Transparency = if visible then visibleTransparency else 1
			descendant.CanCollide = visible and visibleCanCollide
			descendant.CanTouch = visible and visibleCanTouch
			descendant.CanQuery = visible and visibleCanQuery
		elseif descendant:IsA("ProximityPrompt") then
			local visibleEnabled = descendant:GetAttribute("VisibleEnabled")
			if typeof(visibleEnabled) ~= "boolean" then
				visibleEnabled = descendant.Enabled
				descendant:SetAttribute("VisibleEnabled", visibleEnabled)
			end
			descendant.Enabled = visible and visibleEnabled
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
			local visibleEnabled = descendant:GetAttribute("VisibleEnabled")
			if typeof(visibleEnabled) ~= "boolean" then
				visibleEnabled = descendant.Enabled
				descendant:SetAttribute("VisibleEnabled", visibleEnabled)
			end
			descendant.Enabled = visible and visibleEnabled
		elseif descendant:IsA("Light") then
			local visibleEnabled = descendant:GetAttribute("VisibleEnabled")
			if typeof(visibleEnabled) ~= "boolean" then
				visibleEnabled = descendant.Enabled
				descendant:SetAttribute("VisibleEnabled", visibleEnabled)
			end
			descendant.Enabled = visible and visibleEnabled
		end
	end
end

local function createCabin(
	parent: Instance,
	name: string,
	position: Vector3,
	width: number,
	stories: number?
): InteractiveDoor
	local twoStory = stories == 2
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local wallColor  = Color3.fromRGB(112, 102, 90)   -- weathered grey-silver log (matches references)
	local trimColor  = Color3.fromRGB(46, 32, 22)
	local tinRoof    = Color3.fromRGB(88, 84, 76)    -- weathered corrugated tin
	local stoneColor = Color3.fromRGB(72, 68, 62)    -- mossy stone foundation

	-- Stone foundation strip around the base
	createPart(model, "Foundation", Vector3.new(width + 1.2, 1.8, 17.4),
		CFrame.new(position + Vector3.new(0, -0.55, 0)),
		stoneColor, Enum.Material.SmoothPlastic)

	local floor = createPart(
		model,
		"Floor",
		Vector3.new(width, 0.7, 16),
		CFrame.new(position + Vector3.new(0, 0.35, 0)),
		Color3.fromRGB(72, 51, 36),
		Enum.Material.WoodPlanks
	)
	model.PrimaryPart = floor
	-- Terrain marching-cubes smoothing bulges the grass surface above the
	-- cabin floor unless the voxels are cleared a full band BELOW it too.
	-- Inset 1 stud from the walls so no trench shows outside.
	Workspace.Terrain:FillBlock(
		CFrame.new(position + Vector3.new(0, 0.4, 0)),
		Vector3.new(width - 2, 8, 15),
		Enum.Material.Air
	)
	createPart(
		model,
		"BackWall",
		Vector3.new(width, 10, 0.7),
		CFrame.new(position + Vector3.new(0, 5, 7.65)),
		wallColor,
		Enum.Material.WoodPlanks
	)
	for side = -1, 1, 2 do
		createPart(
			model,
			"SideWall",
			Vector3.new(0.7, 10, 16),
			CFrame.new(position + Vector3.new(side * (width / 2 - 0.35), 5, 0)),
			wallColor,
			Enum.Material.WoodPlanks
		)
		createPart(
			model,
			"FrontWall",
			Vector3.new((width - 5) / 2, 10, 0.7),
			CFrame.new(
				position
					+ Vector3.new(
						side * (width / 4 + 1.25),
						5,
						-7.65
					)
			),
			wallColor,
			Enum.Material.WoodPlanks
		)
	end
	createPart(
		model,
		"DoorHeader",
		Vector3.new(5, 2.4, 0.7),
		CFrame.new(position + Vector3.new(0, 8.8, -7.65)),
		wallColor,
		Enum.Material.WoodPlanks
	)
	-- Corrugated tin roof panels (two sloped halves)
	-- Geometry derived from the wall top (y=10) so the panels rest on the walls:
	-- each panel runs from the ridge at cabin-center X down past the wall with a small overhang.
	local roofAngle = math.rad(25)
	local overhang = 1.5
	local half = width / 2
	local wallTop = if twoStory then 20 else 10
	local ridgeY = wallTop + half * math.tan(roofAngle)
	local eaveY = wallTop - overhang * math.tan(roofAngle)
	local panelLen = (half + overhang) / math.cos(roofAngle)
	local panelCX = (half + overhang) / 2
	local panelCY = (ridgeY + eaveY) / 2
	-- Positive Z rotation tilts the +X edge up; each panel's inner edge faces the ridge
	createPart(
		model,
		"RoofLeft",
		Vector3.new(panelLen, 1.1, 19),
		CFrame.new(position + Vector3.new(-panelCX, panelCY, 0))
			* CFrame.Angles(0, 0, roofAngle),
		tinRoof,
		Enum.Material.CorrodedMetal
	)
	createPart(
		model,
		"RoofRight",
		Vector3.new(panelLen, 1.1, 19),
		CFrame.new(position + Vector3.new(panelCX, panelCY, 0))
			* CFrame.Angles(0, 0, -roofAngle),
		tinRoof,
		Enum.Material.CorrodedMetal
	)
	-- Roof ridge cap along the peak
	createPart(model, "RoofRidge", Vector3.new(1.2, 1.2, 19),
		CFrame.new(position + Vector3.new(0, ridgeY + 0.35, 0)),
		Color3.fromRGB(60, 56, 52), Enum.Material.Metal)
	-- Triangular gable fills on front and back walls
	-- Two WedgeParts per gable wall, mirrored at cabin center X.
	-- A WedgePart's tall vertical face is at local +Z (verified by raycast); the
	-- slope descends toward local -Z. Rotate so each wedge's tall end faces the
	-- ridge at cabin-center X:
	--   +90° around Y: local +Z (tall end) → world +X (left wedge, toward center)
	--   -90° around Y: local +Z (tall end) → world -X (right wedge, toward center)
	-- gableHeight/(width/2) = tan(roofAngle), so the wedge slope matches the roof pitch exactly
	local gableHeight = ridgeY - wallTop
	local gableCenterY = wallTop + gableHeight / 2
	local gableSize = Vector3.new(0.7, gableHeight, width / 2)
	for _, wallZ in ipairs({ -7.65, 7.65 }) do
		createWedge(model, "GableLeft", gableSize,
			CFrame.new(position + Vector3.new(-width / 4, gableCenterY, wallZ))
				* CFrame.Angles(0, math.pi / 2, 0),
			wallColor, Enum.Material.WoodPlanks)
		createWedge(model, "GableRight", gableSize,
			CFrame.new(position + Vector3.new(width / 4, gableCenterY, wallZ))
				* CFrame.Angles(0, -math.pi / 2, 0),
			wallColor, Enum.Material.WoodPlanks)
	end
	-- Round metal stovepipe chimney (vertical cylinder through roof)
	local pipeColor = Color3.fromRGB(40, 36, 32)
	local pipeLift = wallTop - 10
	createCylinder(model, "Stovepipe",
		Vector3.new(8, 0.52, 0.52),
		CFrame.new(position + Vector3.new(width * 0.28, 14.0 + pipeLift, 6.5)) * CFrame.Angles(0, 0, math.rad(90)),
		pipeColor, Enum.Material.Metal)
	createCylinder(model, "StovepipeCap",
		Vector3.new(0.55, 0.80, 0.80),
		CFrame.new(position + Vector3.new(width * 0.28, 18.3 + pipeLift, 6.5)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(52, 46, 40), Enum.Material.CorrodedMetal)
	if twoStory then
		-- Second story: upper wall band, floor slab with a stair opening in the
		-- back-left corner, a ramp staircase along the left wall, and upstairs
		-- windows front and back. Ground-floor walls stay 0-10; this band covers
		-- 10-20 and the parameterized roof/gables sit at wallTop = 20.
		createPart(model, "BackWallUpper", Vector3.new(width, 10, 0.7),
			CFrame.new(position + Vector3.new(0, 15, 7.65)),
			wallColor, Enum.Material.WoodPlanks)
		createPart(model, "FrontWallUpper", Vector3.new(width, 10, 0.7),
			CFrame.new(position + Vector3.new(0, 15, -7.65)),
			wallColor, Enum.Material.WoodPlanks)
		for side = -1, 1, 2 do
			createPart(model, "SideWallUpper", Vector3.new(0.7, 10, 16),
				CFrame.new(position + Vector3.new(side * (width / 2 - 0.35), 15, 0)),
				wallColor, Enum.Material.WoodPlanks)
		end
		-- Floor slab in two pieces so the back-left corner stays open for the stairs
		createPart(model, "UpperFloorMain", Vector3.new(width - 1.4, 0.7, 10.3),
			CFrame.new(position + Vector3.new(0, 10.35, -2.15)),
			Color3.fromRGB(72, 51, 36), Enum.Material.WoodPlanks)
		createPart(model, "UpperFloorBack", Vector3.new(width - 6.4, 0.7, 4.3),
			CFrame.new(position + Vector3.new(2.5, 10.35, 5.15)),
			Color3.fromRGB(72, 51, 36), Enum.Material.WoodPlanks)
		-- Ramp staircase hugging the left wall, rising toward the back opening
		local stairRamp = Instance.new("WedgePart")
		stairRamp.Name = "StairRamp"
		stairRamp.Anchored = true
		stairRamp.Size = Vector3.new(3.4, 10, 12)
		stairRamp.CFrame = CFrame.new(position + Vector3.new(-(width / 2 - 2.4), 5.7, 1))
		stairRamp.Color = Color3.fromRGB(88, 62, 40)
		stairRamp.Material = Enum.Material.WoodPlanks
		stairRamp.TopSurface = Enum.SurfaceType.Smooth
		stairRamp.BottomSurface = Enum.SurfaceType.Smooth
		stairRamp.Parent = model
		local stairAngle = math.atan(10 / 12)
		createPart(model, "StairRail", Vector3.new(0.25, 0.25, 15.6),
			CFrame.new(position + Vector3.new(-(width / 2 - 4.05), 7.3, 1))
				* CFrame.Angles(-stairAngle, 0, 0),
			trimColor, Enum.Material.WoodPlanks)
		for _, railZ in { -4.6, 6.6 } do
			local railHeight = if railZ < 0 then 1.6 + 0.7 else 1.6 + 10
			createPart(model, "StairRailPost", Vector3.new(0.3, 2.6, 0.3),
				CFrame.new(position + Vector3.new(-(width / 2 - 4.05), railHeight, railZ)),
				trimColor, Enum.Material.WoodPlanks)
		end
		-- Upstairs guard rail around the stair opening edge
		createPart(model, "OpeningRail", Vector3.new(0.3, 2.4, 4.6),
			CFrame.new(position + Vector3.new(-(width / 2 - 5.4), 11.9, 5.1)),
			trimColor, Enum.Material.WoodPlanks)
		-- Upstairs windows front and back
		for side = -1, 1, 2 do
			for _, windowZ in { -8.25, 8.25 } do
				createPart(model, "WindowUpper",
					Vector3.new(4, 3.5, 0.4),
					CFrame.new(position + Vector3.new(side * width * 0.28, 15.5, windowZ)),
					Color3.fromRGB(181, 198, 174), Enum.Material.Glass, 0.2)
			end
		end
		-- Upstairs bunks (shifted forward so they clear the stair opening)
		for side = -1, 1, 2 do
			local upperBed = createPart(model, "BunkBedUpper",
				Vector3.new(5.5, 1.2, 9),
				CFrame.new(position + Vector3.new(side * (width / 2 - 3.5), 11.9, -2)),
				Color3.fromRGB(98, 80, 61), Enum.Material.WoodPlanks)
			local upperMattress = createPart(model, "MattressUpper",
				Vector3.new(5.1, 0.65, 8.4),
				upperBed.CFrame + Vector3.new(0, 0.9, 0),
				if side < 0
					then Color3.fromRGB(124, 104, 78)
					else Color3.fromRGB(96, 112, 128),
				Enum.Material.Fabric)
			upperMattress.CanCollide = false
			local upperPillow = createPart(model, "PillowUpper",
				Vector3.new(4.2, 0.36, 1.56),
				upperBed.CFrame + Vector3.new(0, 1.405, -3.4),
				Color3.fromRGB(234, 226, 208), Enum.Material.Fabric)
			upperPillow.CanCollide = false
		end
		-- Upstairs rug and lamp with its own switch
		local upperRug = createPart(model, "UpperRug", Vector3.new(6, 0.06, 4.5),
			CFrame.new(position + Vector3.new(0, 10.74, -2)),
			Color3.fromRGB(96, 64, 52), Enum.Material.Fabric)
		upperRug.CanCollide = false
		local upperLamp = createPart(model, "UpperLamp", Vector3.new(1.2, 0.45, 1.2),
			CFrame.new(position + Vector3.new(0, 19.4, 1.5)),
			Color3.fromRGB(255, 211, 132), Enum.Material.Neon)
		upperLamp.CanCollide = false
		local upperLight = Instance.new("PointLight")
		upperLight.Name = "CabinLightUpper"
		upperLight.Brightness = 1.25
		upperLight.Range = 21
		upperLight.Color = Color3.fromRGB(255, 220, 161)
		upperLight.Shadows = true
		upperLight.Enabled = false
		upperLight.Parent = upperLamp
		local upperPrompt = createPrompt(upperLamp, "Switch On", name .. " upstairs lights", 0.1)
		upperPrompt.Triggered:Connect(function()
			upperLight.Enabled = not upperLight.Enabled
			upperPrompt.ActionText = if upperLight.Enabled then "Switch Off" else "Switch On"
		end)
	end
	-- Porch with posts
	if name == "CounselorLodge" then
		-- The deck splits around the storm-cellar stair pit (world x
		-- 5.6..10.4, beside the east post) so the cellar is actually
		-- enterable from the porch — a single slab sealed the pit shut and
		-- left the hatch doors opening onto solid wood.
		createPart(
			model,
			"Porch",
			Vector3.new(19.6, 1, 5),
			CFrame.new(position + Vector3.new(-4.2, 0.5, -10)),
			Color3.fromRGB(77, 54, 37),
			Enum.Material.WoodPlanks
		)
		createPart(
			model,
			"PorchEast",
			Vector3.new(3.6, 1, 5),
			CFrame.new(position + Vector3.new(12.2, 0.5, -10)),
			Color3.fromRGB(77, 54, 37),
			Enum.Material.WoodPlanks
		)
	else
		createPart(
			model,
			"Porch",
			Vector3.new(width - 2, 1, 5),
			CFrame.new(position + Vector3.new(0, 0.5, -10)),
			Color3.fromRGB(77, 54, 37),
			Enum.Material.WoodPlanks
		)
	end
	-- Porch roof
	createPart(model, "PorchRoof", Vector3.new(width - 2, 0.35, 5.5),
		CFrame.new(position + Vector3.new(0, 9.35, -10.25)),
		tinRoof, Enum.Material.CorrodedMetal)
	-- Porch posts at each corner
	for side = -1, 1, 2 do
		createPart(model, "PorchPost", Vector3.new(0.45, 8.8, 0.45),
			CFrame.new(position + Vector3.new(side * (width / 2 - 1.5), 4.5, -12)),
			trimColor, Enum.Material.WoodPlanks)
	end
	-- Porch railing: front rail + side returns + balusters between corner posts
	-- (Cabin 4 reference). The front rail is split into two segments leaving a
	-- 5-stud entry gap over the door steps — the old full-width rail fenced
	-- the porch shut (players had to hop the railing; pathfinding read the
	-- main cabins as unreachable).
	local railY = 4.0
	-- 7 studs: a 5-stud gap read as closed on the navigation mesh (agent
	-- radius 2 + voxel padding), so paths kept vaulting the railing instead.
	local entryGap = 7.0
	local railSegment = (width - 4.0 - entryGap) / 2
	for side = -1, 1, 2 do
		local segmentWidth = railSegment
		local segmentX = side * (entryGap / 2 + railSegment / 2)
		if name == "CounselorLodge" and side > 0 then
			-- East rail stops at the storm-cellar hatch opening instead of
			-- crossing over the pit.
			segmentWidth, segmentX = 2.6, 11.7
		end
		createPart(model, "PorchRailFront" .. (if side < 0 then "L" else "R"),
			Vector3.new(segmentWidth, 0.28, 0.22),
			CFrame.new(position + Vector3.new(segmentX, railY, -12)),
			trimColor, Enum.Material.WoodPlanks)
	end
	for side = -1, 1, 2 do
		createPart(model, "PorchRailSide" .. (if side < 0 then "L" else "R"),
			Vector3.new(0.22, 0.28, 3.5),
			CFrame.new(position + Vector3.new(side * (width / 2 - 1.5), railY, -10.25)),
			trimColor, Enum.Material.WoodPlanks)
	end
	for b = 1, 3 do
		if b == 2 then
			-- Center baluster stood dead-middle of the entry gap.
			continue
		end
		if b == 3 and name == "CounselorLodge" then
			-- Would hang over the storm-cellar hatch opening.
			continue
		end
		local bX = -(width / 2 - 2.5) + (width - 5.0) / 4 * b
		createPart(model, "PorchBaluster" .. tostring(b), Vector3.new(0.20, railY - 1.1, 0.20),
			CFrame.new(position + Vector3.new(bX, (1.1 + railY) / 2, -12)),
			trimColor, Enum.Material.WoodPlanks)
	end
	-- Side lean-to: small open-sided shelter attached to the right cabin wall (Cabin 3 reference)
	local leanW, leanD = 9, 10
	local leanHi, leanLo = 8.5, 5.0
	-- Tall end (+Z after -90° rotation → world -X) sits against the cabin wall;
	-- the slope descends outward
	createWedge(model, "LeanToRoof",
		Vector3.new(leanW, leanHi - leanLo, leanD + 0.5),
		CFrame.new(position + Vector3.new(width / 2 + leanW / 2, leanLo + (leanHi - leanLo) / 2, 2))
			* CFrame.Angles(0, -math.pi / 2, 0),
		tinRoof, Enum.Material.CorrodedMetal)
	for lSide = -1, 1, 2 do
		createPart(model, "LeanToPost" .. (if lSide < 0 then "F" else "B"),
			Vector3.new(0.45, leanLo, 0.45),
			CFrame.new(position + Vector3.new(width / 2 + leanW - 0.25, leanLo / 2, 2 + lSide * (leanD / 2 - 0.25))),
			trimColor, Enum.Material.WoodPlanks)
	end
	-- Simple wooden porch chair on one side (Cabin 2 reference: chair visible
	-- on porch). The lodge's chair sits on the WEST deck — the east side is
	-- the storm-cellar hatch opening.
	local chairColor = Color3.fromRGB(68, 46, 28)
	local chairX = if name == "CounselorLodge" then -width * 0.25 else width * 0.25
	createPart(model, "ChairSeat", Vector3.new(1.7, 0.28, 1.5),
		CFrame.new(position + Vector3.new(chairX, 1.64, -9.8)), chairColor, Enum.Material.WoodPlanks)
	createPart(model, "ChairBack", Vector3.new(1.7, 1.15, 0.22),
		CFrame.new(position + Vector3.new(chairX, 2.35, -9.1)), chairColor, Enum.Material.WoodPlanks)
	local doorState = createInteractiveDoor(
		model,
		"Door",
		Vector3.new(4.4, 7.4, 0.5),
		CFrame.new(position + Vector3.new(0, 4.05, -8.05)),
		trimColor,
		name
	)

	for side = -1, 1, 2 do
		local window = createPart(
			model,
			"Window",
			Vector3.new(4, 3.5, 0.4),
			CFrame.new(position + Vector3.new(side * width * 0.28, 5.5, -8.25)),
			Color3.fromRGB(181, 198, 174),
			Enum.Material.Glass,
			0.2
		)
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Front
		light.Brightness = 0.8
		light.Range = 14
		light.Color = Color3.fromRGB(255, 221, 159)
		light.Enabled = false
		light.Parent = window
	end

	local interiorLamp = createPart(
		model,
		"InteriorLamp",
		Vector3.new(1.2, 0.45, 1.2),
		CFrame.new(position + Vector3.new(0, 9.4, 1.5)),
		Color3.fromRGB(255, 211, 132),
		Enum.Material.Neon
	)
	interiorLamp.CanCollide = false
	local interiorLight = Instance.new("PointLight")
	interiorLight.Name = "CabinLight"
	interiorLight.Brightness = 1.25
	interiorLight.Range = 21
	interiorLight.Color = Color3.fromRGB(255, 220, 161)
	interiorLight.Shadows = true
	interiorLight.Enabled = false
	interiorLight.Parent = interiorLamp
	local lightPrompt = createPrompt(interiorLamp, "Switch On", name .. " lights", 0.1)
	lightPrompt.Triggered:Connect(function()
		interiorLight.Enabled = not interiorLight.Enabled
		lightPrompt.ActionText = if interiorLight.Enabled then "Switch Off" else "Switch On"
	end)

	for side = -1, 1, 2 do
		if twoStory and side == -1 then
			-- The stair ramp runs along the left wall; upstairs bunks replace
			-- this one
			continue
		end
		local bed = createPart(
			model,
			"BunkBed",
			Vector3.new(5.5, 1.2, 9),
			CFrame.new(position + Vector3.new(side * (width / 2 - 3.5), 1.5, 2)),
			Color3.fromRGB(98, 80, 61),
			Enum.Material.WoodPlanks
		)
		local mattress = createPart(
			model,
			"Mattress",
			Vector3.new(5.1, 0.65, 8.4),
			bed.CFrame + Vector3.new(0, 0.9, 0),
			if side < 0
				then Color3.fromRGB(103, 124, 113)
				else Color3.fromRGB(118, 105, 91),
			Enum.Material.Fabric
		)
		mattress.CanCollide = false
		-- Pillow at head (door-side) end of each bunk
		local pillow = createPart(
			model, "Pillow",
			Vector3.new(4.2, 0.36, 1.56),
			bed.CFrame + Vector3.new(0, 1.405, -3.4),
			Color3.fromRGB(234, 226, 208),
			Enum.Material.Fabric
		)
		pillow.CanCollide = false
		-- Footlocker at foot end of each bunk
		createPart(
			model, "Footlocker",
			Vector3.new(4.6, 1.5, 1.8),
			bed.CFrame + Vector3.new(0, -0.65, 4.5),
			Color3.fromRGB(58, 44, 28),
			Enum.Material.WoodPlanks
		)
	end

	local tableTop = createPart(
		model,
		"CabinTable",
		Vector3.new(6, 0.55, 4),
		CFrame.new(position + Vector3.new(0, 3, 2)),
		Color3.fromRGB(91, 64, 43),
		Enum.Material.WoodPlanks
	)
	createInspectPrompt(
		tableTop,
		name .. " guest book",
		"LAST ENTRY — lights out at 11:47 PM. Something scratched at the door."
	)
	-- Interior furnishing shared by every cabin: rug under the table, a wall
	-- shelf with books and a lantern, and a dresser against the right wall
	local rug = createPart(model, "CabinRug", Vector3.new(7, 0.06, 5),
		CFrame.new(position + Vector3.new(0, 0.74, 2)),
		Color3.fromRGB(122, 60, 48), Enum.Material.Fabric)
	rug.CanCollide = false
	for shelfIndex, shelfY in { 4.5, 6.5 } do
		createPart(model, "WallShelf" .. tostring(shelfIndex),
			Vector3.new(6, 0.3, 1.4),
			CFrame.new(position + Vector3.new(-width * 0.2, shelfY, 7.0)),
			trimColor, Enum.Material.WoodPlanks)
	end
	local bookColors = {
		Color3.fromRGB(112, 54, 44),
		Color3.fromRGB(58, 86, 64),
		Color3.fromRGB(64, 66, 108),
	}
	for bookIndex, bookColor in bookColors do
		local book = createPart(model, "ShelfBook" .. tostring(bookIndex),
			Vector3.new(0.5, 1.1, 0.9),
			CFrame.new(position + Vector3.new(-width * 0.2 - 1.6 + bookIndex * 0.75, 5.25, 7.0)),
			bookColor, Enum.Material.SmoothPlastic)
		book.CanCollide = false
	end
	local shelfLantern = createPart(model, "ShelfLantern", Vector3.new(0.8, 1.0, 0.8),
		CFrame.new(position + Vector3.new(-width * 0.2 + 2.2, 7.3, 7.0)),
		Color3.fromRGB(255, 211, 132), Enum.Material.Neon)
	shelfLantern.CanCollide = false
	createPart(model, "Dresser", Vector3.new(1.6, 3.2, 2.6),
		CFrame.new(position + Vector3.new(width / 2 - 1.6, 1.95, -4)),
		Color3.fromRGB(76, 54, 36), Enum.Material.WoodPlanks)
	for drawerIndex = 1, 2 do
		local drawer = createPart(model, "DresserDrawer" .. tostring(drawerIndex),
			Vector3.new(0.18, 1.1, 2.1),
			CFrame.new(position + Vector3.new(width / 2 - 2.5, 0.85 + drawerIndex * 0.95, -4)),
			Color3.fromRGB(58, 40, 26), Enum.Material.Wood)
		drawer.CanCollide = false
	end
	if name == "CounselorLodge" then
		-- Common-room extras: long meeting table with benches, a duty-roster
		-- notice board, and the camp radio desk in the front-right corner
		createPart(model, "LodgeTable", Vector3.new(10, 0.6, 3.4),
			CFrame.new(position + Vector3.new(2, 2.9, -3)),
			Color3.fromRGB(91, 64, 43), Enum.Material.WoodPlanks)
		for _, benchZ in { -1.2, -4.8 } do
			createPart(model, "LodgeBench", Vector3.new(10, 0.5, 1.2),
				CFrame.new(position + Vector3.new(2, 1.6, benchZ)),
				Color3.fromRGB(68, 48, 32), Enum.Material.WoodPlanks)
		end
		local noticeBoard = createPart(model, "NoticeBoard", Vector3.new(5.5, 3.4, 0.3),
			CFrame.new(position + Vector3.new(-8, 5.6, 7.2)),
			Color3.fromRGB(56, 40, 26), Enum.Material.Wood)
		createSign(noticeBoard, "CAMP DUTY ROSTER", Color3.fromRGB(226, 190, 114))
		createPart(model, "RadioDesk", Vector3.new(3.4, 0.5, 2),
			CFrame.new(position + Vector3.new(9.5, 2.8, -5.5)),
			Color3.fromRGB(76, 54, 36), Enum.Material.WoodPlanks)
		local radioBox = createPart(model, "RadioBox", Vector3.new(1.8, 1.2, 1),
			CFrame.new(position + Vector3.new(9.5, 3.65, -5.7)),
			Color3.fromRGB(48, 44, 40), Enum.Material.Metal)
		local radioDial = createPart(model, "RadioDial", Vector3.new(0.4, 0.4, 0.12),
			CFrame.new(position + Vector3.new(9.9, 3.7, -6.26)),
			Color3.fromRGB(198, 165, 32), Enum.Material.Neon)
		radioDial.CanCollide = false
		createPart(model, "RadioAntenna", Vector3.new(0.12, 3, 0.12),
			CFrame.new(position + Vector3.new(8.9, 5.7, -5.7)),
			Color3.fromRGB(120, 120, 126), Enum.Material.Metal)
		createInspectPrompt(
			radioBox,
			"Camp radio",
			"The dial drifts through static. Someone has marked 146.52 in grease pencil."
		)
	end
	-- Name board hangs from the porch roof edge so it never clips the gable or hides behind the eave
	local signW = math.min(width - 6, 14)
	createSign(
		createPart(
			model,
			"CabinSign",
			Vector3.new(signW, 1.9, 0.35),
			CFrame.new(position + Vector3.new(0, 8.15, -12.3)),
			trimColor,
			Enum.Material.Wood
		),
		string.upper(string.gsub(name, "(%l)(%u)", "%1 %2")),
		Color3.fromRGB(226, 190, 114)
	)
	for hSide = -1, 1, 2 do
		createPart(model, "SignStrap" .. (if hSide < 0 then "L" else "R"),
			Vector3.new(0.14, 0.6, 0.14),
			CFrame.new(position + Vector3.new(hSide * (signW / 2 - 0.8), 9.15, -12.3)),
			trimColor, Enum.Material.WoodPlanks)
	end
	-- Two-step approach from the porch down to grade. With the cabin bases
	-- seated against the rendered surface (deck ~0.6 proud of the grass),
	-- the classic step pair works again: tops at deck -0.33 and -0.66 land
	-- the second step at or just under the approach grass.
	createPart(model, "PorchStep1", Vector3.new(4.6, 0.34, 1.5),
		CFrame.new(position + Vector3.new(0, 0.5, -13.4)),
		Color3.fromRGB(72, 50, 32), Enum.Material.WoodPlanks)
	createPart(model, "PorchStep2", Vector3.new(4.6, 0.34, 1.5),
		CFrame.new(position + Vector3.new(0, 0.17, -14.9)),
		Color3.fromRGB(62, 44, 28), Enum.Material.WoodPlanks)
	-- Wooden bench on left porch side (Cabin 4 reference: low bench/railing against left wall)
	createPart(model, "BenchSeat", Vector3.new(3.4, 0.28, 1.8),
		CFrame.new(position + Vector3.new(-(width / 2 - 3.2), 1.52, -10.4)),
		Color3.fromRGB(68, 48, 32), Enum.Material.WoodPlanks)
	local benchBack = createPart(model, "BenchBack", Vector3.new(3.4, 1.4, 0.18),
		CFrame.new(position + Vector3.new(-(width / 2 - 3.2), 2.22, -11.2)),
		Color3.fromRGB(62, 44, 28), Enum.Material.WoodPlanks)
	benchBack.CanCollide = false
	-- Firewood stack beside the right porch post (Cabin 4 reference)
	local logColor  = Color3.fromRGB(82, 55, 34)
	local logDark   = Color3.fromRGB(58, 38, 22)
	createPart(model, "WoodPileBase", Vector3.new(5.2, 1.5, 2.8),
		CFrame.new(position + Vector3.new(width / 2 + 3.6, 0.75, -11.0)),
		logColor, Enum.Material.WoodPlanks)
	createPart(model, "WoodPileMid", Vector3.new(4.8, 1.2, 2.6),
		CFrame.new(position + Vector3.new(width / 2 + 3.6, 2.1, -11.0)),
		logDark, Enum.Material.WoodPlanks)
	createPart(model, "WoodPileTop", Vector3.new(4.2, 1.0, 2.4),
		CFrame.new(position + Vector3.new(width / 2 + 3.6, 3.2, -11.0)),
		logColor, Enum.Material.WoodPlanks)
	-- Two loose cross-logs resting on the pile top
	createPart(model, "LogA", Vector3.new(0.75, 0.75, 3.8),
		CFrame.new(position + Vector3.new(width / 2 + 2.6, 3.85, -11.0)),
		logDark, Enum.Material.WoodPlanks)
	createPart(model, "LogB", Vector3.new(0.75, 0.75, 3.8),
		CFrame.new(position + Vector3.new(width / 2 + 4.6, 3.85, -11.0)),
		logDark, Enum.Material.WoodPlanks)
	return doorState
end

local function createBuilding(
	parent: Instance,
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3,
	signText: string,
	rotationY: number?
): InteractiveDoor
	-- All offsets are in the building's local frame (front = local -Z);
	-- rotationY turns the whole building so the storefront can face the road
	local base = CFrame.new(position) * CFrame.Angles(0, rotationY or 0, 0)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local floor = createPart(
		model,
		"Floor",
		Vector3.new(size.X, 0.8, size.Z),
		base * CFrame.new(0, 0.4, 0),
		color,
		Enum.Material.Concrete
	)
	model.PrimaryPart = floor
	createPart(
		model,
		"BackWall",
		Vector3.new(size.X, size.Y, 1),
		base * CFrame.new(0, size.Y / 2, size.Z / 2 - 0.5),
		color,
		Enum.Material.Brick
	)
	for side = -1, 1, 2 do
		createPart(
			model,
			"SideWall",
			Vector3.new(1, size.Y, size.Z),
			base * CFrame.new(side * (size.X / 2 - 0.5), size.Y / 2, 0),
			color,
			Enum.Material.Brick
		)
		createPart(
			model,
			"FrontWall",
			Vector3.new((size.X - 6) / 2, size.Y, 1),
			base * CFrame.new(side * (size.X / 4 + 1.5), size.Y / 2, -size.Z / 2 + 0.5),
			color,
			Enum.Material.Brick
		)
	end
	createPart(
		model,
		"DoorHeader",
		Vector3.new(6, math.max(2, size.Y - 8), 1),
		base * CFrame.new(0, 8 + math.max(2, size.Y - 8) / 2, -size.Z / 2 + 0.5),
		color,
		Enum.Material.Brick
	)
	createPart(
		model,
		"Roof",
		Vector3.new(size.X + 2, 1.5, size.Z + 2),
		base * CFrame.new(0, size.Y + 0.75, 0),
		Color3.fromRGB(41, 43, 46),
		Enum.Material.Slate
	)
	local doorState = createInteractiveDoor(
		model,
		"Door",
		Vector3.new(5.4, 7.6, 0.55),
		base * CFrame.new(0, 4.2, -size.Z / 2 - 0.05),
		Color3.fromRGB(54, 48, 42),
		signText
	)
	local sign = createPart(
		model,
		"Sign",
		Vector3.new(math.min(size.X - 3, 18), 4, 0.5),
		base * CFrame.new(0, size.Y - 3, -size.Z / 2 - 0.35),
		Color3.fromRGB(27, 29, 31),
		Enum.Material.Wood
	)
	createSign(sign, signText, Color3.fromRGB(194, 202, 191))
	for column = -1, 1, 2 do
		createPart(
			model,
			"BoardedWindow",
			Vector3.new(5, 4, 0.4),
			base * CFrame.new(column * size.X * 0.23, size.Y * 0.48, -size.Z / 2 - 0.25),
			Color3.fromRGB(75, 63, 50),
			Enum.Material.WoodPlanks
		)
	end
	-- Crumbling plaster patches: exposed dark brick where facade has fallen off (Old Town 2/3 reference)
	local damageC = Color3.fromRGB(46, 40, 35)
	local fZ = -size.Z / 2 - 0.14
	local function dmgPatch(nm, partSize, offset: Vector3)
		local p = createPart(model, nm, partSize, base * CFrame.new(offset.X, offset.Y, offset.Z), damageC, Enum.Material.Concrete)
		p.CanCollide = false
	end
	dmgPatch("DamagePatch1", Vector3.new(3.8, 3.2, 0.18), Vector3.new(-size.X * 0.29, size.Y * 0.72, fZ))
	dmgPatch("DamagePatch2", Vector3.new(2.6, 4.0, 0.18), Vector3.new( size.X * 0.27, size.Y * 0.81, fZ))
	dmgPatch("DamagePatch3", Vector3.new(0.18, 3.6, 5.0), Vector3.new(-size.X / 2 - 0.12, size.Y * 0.60, size.Z * 0.12))
	local interiorCounter = createPart(
		model,
		"SearchCounter",
		Vector3.new(math.min(12, size.X - 6), 3.5, 3),
		base * CFrame.new(0, 1.75, 3),
		Color3.fromRGB(66, 57, 49),
		Enum.Material.WoodPlanks
	)
	createInspectPrompt(
		interiorCounter,
		signText .. " interior",
		"Dust trails and fresh marks suggest someone searched this place before you."
	)
	return doorState
end

local function createStreetlight(parent: Instance, position: Vector3, startsDark: boolean?)
	local poleC = Color3.fromRGB(28, 30, 34)  -- dark wrought iron
	-- Main pole (slender Victorian shaft)
	local pole = createPart(parent, "Streetlight", Vector3.new(0.55, 18, 0.55),
		CFrame.new(position + Vector3.new(0, 9, 0)), poleC, Enum.Material.Metal)
	pole:SetAttribute("ShadowNode", true)
	-- Decorative collar ring near the top
	createPart(parent, "LampCollar", Vector3.new(0.90, 0.42, 0.90),
		CFrame.new(position + Vector3.new(0, 16.8, 0)), poleC, Enum.Material.Metal)
	-- Finial ball cap
	local cap = createPart(parent, "PoleCap", Vector3.new(0.75, 0.75, 0.75),
		CFrame.new(position + Vector3.new(0, 18.38, 0)), poleC, Enum.Material.Metal)
	cap.Shape = Enum.PartType.Ball
	-- Hook arm: horizontal beam + short vertical drop
	createPart(parent, "LampArm", Vector3.new(3.0, 0.38, 0.38),
		CFrame.new(position + Vector3.new(1.5, 17.2, 0)), poleC, Enum.Material.Metal)
	createPart(parent, "LampDrop", Vector3.new(0.38, 1.5, 0.38),
		CFrame.new(position + Vector3.new(3.0, 16.45, 0)), poleC, Enum.Material.Metal)
	-- Lantern cage (dark frame surrounding the glow bulb)
	-- Translucent panes: the amber bulb must read through the cage at night,
	-- otherwise the lantern head shows as a dead metal box.
	local frame = createPart(parent, "LanternFrame", Vector3.new(1.55, 1.90, 1.55),
		CFrame.new(position + Vector3.new(3.0, 15.2, 0)), poleC, Enum.Material.Metal)
	frame.Transparency = 0.45
	-- Glowing amber bulb inside the cage
	local glow = createPart(parent, "LanternGlow", Vector3.new(0.95, 1.20, 0.95),
		CFrame.new(position + Vector3.new(3.0, 15.2, 0)),
		Color3.fromRGB(255, 208, 140), Enum.Material.Neon)
	glow.Transparency = 0.22
	glow.Shape = Enum.PartType.Ball
	-- Warm amber point light (matches Old Town 1 reference lamp colour)
	local light = Instance.new("PointLight")
	light.Brightness = 1.6
	light.Range = 30
	light.Color = Color3.fromRGB(255, 205, 140)
	light.Parent = glow
	if startsDark then
		-- A dead lantern the fuse box can bring back: the dark values are
		-- applied before the first setFolderVisible pass so the Visible*
		-- attribute cache records the lantern as unlit.
		glow:SetAttribute("DarkLantern", true)
		glow.Color = LANTERN_DARK_COLOR
		glow.Transparency = LANTERN_DARK_TRANSPARENCY
		light.Enabled = false
	end
end

local function createUtilityPole(parent: Instance, position: Vector3)
	local poleColor = Color3.fromRGB(50, 38, 26)
	-- Vertical shaft (~22 studs tall)
	createCylinder(parent, "UtilityShaft",
		Vector3.new(22, 0.46, 0.46),
		CFrame.new(position + Vector3.new(0, 11, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		poleColor, Enum.Material.WoodPlanks)
	-- Horizontal crossarm near the top
	createPart(parent, "UtilityCrossarm",
		Vector3.new(5.6, 0.30, 0.30),
		CFrame.new(position + Vector3.new(0, 20.6, 0)),
		poleColor, Enum.Material.WoodPlanks)
	-- Ceramic insulator knobs at each end of the crossarm
	for side = -1, 1, 2 do
		createCylinder(parent, "UtilityInsulator",
			Vector3.new(0.38, 0.42, 0.42),
			CFrame.new(position + Vector3.new(side * 2.4, 20.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(55, 74, 72), Enum.Material.SmoothPlastic)
	end
end

local function createPineTree(
	parent: Instance,
	position: Vector3,
	height: number,
	canopyColor: Color3
)
	local trunk = createCylinder(
		parent,
		"PineTrunk",
		Vector3.new(height, 2.4, 2.4),
		CFrame.new(position + Vector3.new(0, height / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(67, 50, 36),
		Enum.Material.Wood
	)
	trunk:SetAttribute("Occluder", true)
	for layer = 1, 5 do
		local width = 13 - layer * 1.45
		local canopy = createPart(
			parent,
			"PineCanopy",
			Vector3.new(width, 5.2, width),
			CFrame.new(
				position
					+ Vector3.new(
						if layer % 2 == 0 then 0.7 else -0.5,
						height * 0.42 + layer * 2.65,
						if layer % 3 == 0 then 0.6 else -0.35
					)
			),
			canopyColor:Lerp(Color3.fromRGB(26, 61, 39), layer * 0.035),
			Enum.Material.Grass
		)
		canopy.Shape = Enum.PartType.Ball
		canopy.CanCollide = false
		canopy:SetAttribute("Occluder", true)
	end
end

local function createBareTree(parent: Instance, position: Vector3, height: number)
	local trunk = createCylinder(parent, "BareTrunk",
		Vector3.new(height, 1.6, 1.6),
		CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(52, 44, 36), Enum.Material.Wood)
	trunk:SetAttribute("Occluder", true)
	-- A few dead angular branches
	for b = 1, 4 do
		local branchAngle = (b / 4) * math.pi * 2
		local branchH = height * (0.45 + b * 0.09)
		local branchLen = 4 + b % 3
		createPart(parent, "Branch",
			Vector3.new(0.4, branchLen, 0.4),
			CFrame.new(position + Vector3.new(
				math.cos(branchAngle) * 1.1,
				branchH,
				math.sin(branchAngle) * 1.1
			)) * CFrame.Angles(math.cos(branchAngle) * 0.65, 0, math.sin(branchAngle) * 0.65),
			Color3.fromRGB(44, 36, 28), Enum.Material.Wood)
	end
end

local function buildWaterTower(parent: Instance, position: Vector3)
	local metalColor  = Color3.fromRGB(63, 72, 75)    -- weathered CorrodedMetal
	local legColor    = Color3.fromRGB(52, 58, 60)
	local tankHeight  = 18
	local legH        = 20

	-- Tank (cylinder lying on its side, so PartType.Cylinder rotated 90°)
	local tank = createCylinder(parent, "WaterTankBody",
		Vector3.new(tankHeight, 14, 14),
		CFrame.new(position + Vector3.new(0, legH + tankHeight / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		metalColor, Enum.Material.CorrodedMetal)
	tank.Shape = Enum.PartType.Cylinder

	-- Tank bands / hoops
	for ring = 1, 4 do
		local ringY = legH + (ring / 5) * tankHeight
		local band = createCylinder(parent, "TankBand",
			Vector3.new(0.55, 14.4, 14.4),
			CFrame.new(position + Vector3.new(0, ringY, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(44, 52, 55), Enum.Material.CorrodedMetal)
		band.Shape = Enum.PartType.Cylinder
	end

	-- Top cap
	createPart(parent, "TankCap",
		Vector3.new(14.5, 1.2, 14.5),
		CFrame.new(position + Vector3.new(0, legH + tankHeight + 0.6, 0)),
		legColor, Enum.Material.CorrodedMetal)

	-- Four support legs with X-braces
	for i = 0, 3 do
		local legAngle = (i / 4) * math.pi * 2
		local lx = math.cos(legAngle) * 5
		local lz = math.sin(legAngle) * 5
		createPart(parent, "WTLeg",
			Vector3.new(0.9, legH, 0.9),
			CFrame.new(position + Vector3.new(lx, legH / 2, lz)),
			legColor, Enum.Material.Metal)
	end
	-- Cross-braces at mid-height between adjacent legs
	for i = 0, 3 do
		local a1 = (i / 4) * math.pi * 2
		local a2 = ((i + 1) / 4) * math.pi * 2
		local x1, z1 = math.cos(a1) * 5, math.sin(a1) * 5
		local x2, z2 = math.cos(a2) * 5, math.sin(a2) * 5
		local mx, mz = (x1 + x2) / 2, (z1 + z2) / 2
		local braceLen = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
		local braceAngle = math.atan2(z2 - z1, x2 - x1)
		createPart(parent, "WTBrace",
			Vector3.new(braceLen, 0.55, 0.55),
			CFrame.new(position + Vector3.new(mx, legH * 0.55, mz))
				* CFrame.Angles(0, -braceAngle, 0),
			legColor, Enum.Material.Metal)
	end

	-- Platform deck just below the tank
	createPart(parent, "WTPlatform",
		Vector3.new(16, 0.55, 16),
		CFrame.new(position + Vector3.new(0, legH - 0.3, 0)),
		Color3.fromRGB(52, 48, 44), Enum.Material.Metal)
	-- Platform railing posts (4 sides)
	for side = -1, 1, 2 do
		createPart(parent, "WTRailH",
			Vector3.new(16.5, 0.35, 0.35),
			CFrame.new(position + Vector3.new(0, legH + 1.8, side * 8)),
			legColor, Enum.Material.Metal)
		createPart(parent, "WTRailV",
			Vector3.new(0.35, 0.35, 16.5),
			CFrame.new(position + Vector3.new(side * 8, legH + 1.8, 0)),
			legColor, Enum.Material.Metal)
	end

	-- Climbable service ladder up the -X face; the truss tops out above the
	-- platform railing so players can step over it onto the deck.
	local ladder = Instance.new("TrussPart")
	ladder.Name = "WTLadder"
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, legH + 4, 2)
	ladder.CFrame = CFrame.new(position + Vector3.new(-8.9, (legH + 4) / 2, 0))
	ladder.Color = legColor
	ladder.Material = Enum.Material.Metal
	ladder.Parent = parent

	-- "WATER" lettering sign on the tank side (SurfaceGui on a thin plate)
	local signPlate = createPart(parent, "WTSign",
		Vector3.new(8, 2.5, 0.25),
		CFrame.new(position + Vector3.new(0, legH + tankHeight * 0.5, -7.2)),
		Color3.fromRGB(40, 48, 50), Enum.Material.SmoothPlastic)
	createSign(signPlate, "WATER", Color3.fromRGB(148, 158, 148))
end

local function configureLighting()
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.32
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.55

	local atmosphere = Lighting:FindFirstChild("CampAtmosphere")
	if not atmosphere or not atmosphere:IsA("Atmosphere") then
		if atmosphere then
			atmosphere:Destroy()
		end
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "CampAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.05
	atmosphere.Color = Color3.fromRGB(192, 208, 196)
	atmosphere.Decay = Color3.fromRGB(88, 108, 95)
	atmosphere.Glare = 0.06
	atmosphere.Haze = 1.85

	local color = Lighting:FindFirstChild("CampColor")
	if not color or not color:IsA("ColorCorrectionEffect") then
		if color then
			color:Destroy()
		end
		color = Instance.new("ColorCorrectionEffect")
		color.Name = "CampColor"
		color.Parent = Lighting
	end
	color.Brightness = 0.02
	color.Contrast = 0.08
	color.Saturation = -0.04
	color.TintColor = Color3.fromRGB(255, 244, 221)

	local bloom = Lighting:FindFirstChild("CampBloom")
	if not bloom or not bloom:IsA("BloomEffect") then
		if bloom then
			bloom:Destroy()
		end
		bloom = Instance.new("BloomEffect")
		bloom.Name = "CampBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.22
	bloom.Size = 24
	bloom.Threshold = 1.15

	local rays = Lighting:FindFirstChild("CampSunRays")
	if not rays or not rays:IsA("SunRaysEffect") then
		if rays then
			rays:Destroy()
		end
		rays = Instance.new("SunRaysEffect")
		rays.Name = "CampSunRays"
		rays.Parent = Lighting
	end
	rays.Intensity = 0.08
	rays.Spread = 0.75
end

local function hideDefaultBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		baseplate.CanCollide = false
		baseplate.CanTouch = false
		baseplate.CanQuery = false
		baseplate:SetAttribute("HiddenByCampMystery", true)
	end
end

-- World footprint. The original camp shipped on a 250x205 slab; the world-x2
-- pass grew it to 450x320; the third expansion to 560x440. This FOURTH
-- expansion doubles the play area: 800x620 (x -550..250, z -148..472), still
-- growing only NORTH and WEST. The south edge stays at -148 — Hollow Creek
-- town owns everything past it and extending the slab south buries the town's
-- street grid (learned the hard way, 2026-08-04). The east edge stays at 250
-- where the far-shore ridge walls the lake; north of the lake the ridge now
-- continues as boundary domes up to the new north edge.
local WORLD_SLAB_CFRAME = CFrame.new(-150, -3.5, 162)
local WORLD_SLAB_SIZE = Vector3.new(800, 8, 620)

-- Outer boundary hill ring. The original 14-dome ring stays put as interior
-- foothills (the ranger station stilts and several props sit on those slopes),
-- so the world's edge moves out to this second ring instead. The east span is
-- omitted where the expanded lake now reaches. Rows are {x, y, z, ballRadius};
-- positions were checked against every water fill below so no dome pokes a
-- floating cap above a Water region.
--
-- The SOUTH span (z < -60) is omitted on purpose: Hollow Creek town occupies
-- z -45..-445, and a hill row there buried the town's whole north band (main
-- road, Diner, Residential A, storm-cellar hatch, cornfield, sawmill — audited
-- in-boot 2026-08-04, burial depths 15-33 studs). The day-phase boundary that
-- those domes provided is now TownApproachDayWall (see buildCampTerrain), an
-- invisible wall that switches off at night when the town becomes real.
-- Fourth expansion: the ring moved out to the doubled slab's edge (north
-- z ~455-470, west x ~-490..-536) and gained a NORTHEAST span along x ~250
-- that continues the far-shore ridge from the lake's north end up to the new
-- corner — without it the whole band north of the lake was open world edge.
-- The creek's north mouth (now at x ~140, z ~470 after the 0.08-yaw drift)
-- keeps an open gate at x ~112..168. The arc still ends where the lake (east)
-- and the town band (south) take over as natural boundaries.
-- Dome layout lives in Map/TerrainDomes — the single source of truth for
-- terrain fills AND every prop-seating height model. The hand-copied
-- mirrors that used to live here (and in Backcountry / LakeAndWilds /
-- HighFrontier) drifted repeatedly; now they all read the same tables.
local OUTER_HILL_DOMES = TerrainDomes.OUTER
local FAR_SHORE_DOMES = TerrainDomes.FAR_SHORE

-- Ground height across the expanded band: flat slab, the original dome ring
-- (including the index-9 ranger override), and both new dome tables. Used to
-- seat the outer tree wall on whatever hill happens to be underneath.
local function expandedGroundHeight(x: number, z: number): number
	return TerrainDomes.heightAt(x, z)
end

local function buildCampTerrain(parent: Instance)
	local terrain = Workspace.Terrain
	-- Terrain is fully code-sculpted; clear first so every build is
	-- deterministic instead of accumulating over whatever the place file
	-- carried (moved hills used to leave their old selves behind).
	terrain:Clear()
	-- Animated grass everywhere on grass terrain, cut short so porches/props stay visible
	-- (Decoration/GrassLength may not exist depending on Studio version; both are optional cosmetics)
	local cosmeticTerrain = terrain :: any
	pcall(function()
		cosmeticTerrain.Decoration = true
	end)
	pcall(function()
		cosmeticTerrain.GrassLength = 0.3
	end)
	terrain:FillBlock(
		WORLD_SLAB_CFRAME,
		WORLD_SLAB_SIZE,
		Enum.Material.Grass
	)
	-- Interior foothill ring: explicit per-dome entries (see TerrainDomes
	-- for the history — POI hills keep their spots, the four domes that
	-- crowded the cabins and counselor quarters moved outward 2026-08-09).
	for _, dome in TerrainDomes.INTERIOR do
		terrain:FillBall(
			Vector3.new(dome[1] :: number, dome[2] :: number, dome[3] :: number),
			dome[4] :: number,
			if dome[5] == true then Enum.Material.Ground else Enum.Material.Grass
		)
	end
	-- Doubled camp: outer boundary ring and far-shore ridge. The old ring
	-- above becomes interior foothills; these domes are the new world edge.
	for _, dome in OUTER_HILL_DOMES do
		terrain:FillBall(
			Vector3.new(dome[1] :: number, dome[2] :: number, dome[3] :: number),
			dome[4] :: number,
			if dome[5] == true then Enum.Material.Ground else Enum.Material.Grass
		)
	end
	for _, dome in FAR_SHORE_DOMES do
		terrain:FillBall(
			Vector3.new(dome[1] :: number, dome[2] :: number, dome[3] :: number),
			dome[4] :: number,
			if dome[5] == true then Enum.Material.Ground else Enum.Material.Grass
		)
	end
	-- Creek runs the full expanded slab now (300 long instead of 170); the
	-- 0.08 yaw swings the north mouth east to (116, 161) and the south mouth
	-- west to (92, -138), both clear of the boundary domes.
	--
	-- ENGINE RULE (measured in-boot 2026-08-04): filling Water into a voxel
	-- row that still holds ANY solid occupancy does nothing, silently — even
	-- the 0.13-occupancy sliver the slab top leaves in the y 0..4 row blocks
	-- it. Water only floods rows that are already open air, then occupies
	-- them fully (which is why the rendered surface sits at 4.0, the top of
	-- the y 0..4 row). The bay below only shows water because of its r42 Air
	-- carve; so EVERY water region here gets an Air carve above the waterline
	-- first. The carves also shave hill-dome toes that would otherwise hang
	-- as floating slices over the water (dome 2's east toe at the north arm).
	-- The mid-run through the mines bluff (z -58..-15) stays uncarved: the
	-- bluff there is a dry gorge notch, as shipped, and carving it would
	-- expose the mines' sealed rock rooms.
	terrain:FillBlock(
		CFrame.new(104, 13, 12) * CFrame.Angles(0, 0.08, 0) * CFrame.new(0, 0, 65),
		Vector3.new(37, 24, 170),
		Enum.Material.Air
	)
	-- Third expansion: the creek continues along the same bearing through the
	-- new north meadow to the moved boundary (its gate stays open at the
	-- ring and the tree wall skips the water corridor).
	terrain:FillBlock(
		CFrame.new(104, 13, 12) * CFrame.Angles(0, 0.08, 0) * CFrame.new(0, 0, 215),
		Vector3.new(37, 24, 150),
		Enum.Material.Air
	)
	-- Fourth expansion: the creek runs on to the doubled slab's north edge
	-- (local z 290..460, mouth at ~(140, 470)); the boundary-gate domes at
	-- x 92 and 198 flank it and this carve shaves any dome toe over the water.
	terrain:FillBlock(
		CFrame.new(104, 13, 12) * CFrame.Angles(0, 0.08, 0) * CFrame.new(0, 0, 375),
		Vector3.new(37, 24, 170),
		Enum.Material.Air
	)
	terrain:FillBlock(
		CFrame.new(99.5, 13, -75),
		Vector3.new(27, 24, 34),
		Enum.Material.Air
	)
	terrain:FillBlock(
		CFrame.new(93, 13, -115),
		Vector3.new(34, 24, 46),
		Enum.Material.Air
	)
	-- Water band y -4..4: fully covers the y 0..4 voxel row so block fills
	-- read 1.0 there like cylinder fills do (a nominal-band block fill only
	-- wrote 0.4 and rendered its surface 2.4 studs below the bay's). The
	-- full-grass bed rows below stay solid, so nothing deepens.
	terrain:FillBlock(
		CFrame.new(104, 0, 12) * CFrame.Angles(0, 0.08, 0),
		Vector3.new(31, 8, 300),
		Enum.Material.Water
	)
	-- North-run water for the extended creek; same y band as the main run so
	-- the rendered surfaces meet seamlessly (see the water-row engine rule
	-- above — the Air carve for this stretch is done alongside the main one).
	terrain:FillBlock(
		CFrame.new(104, 0, 12) * CFrame.Angles(0, 0.08, 0) * CFrame.new(0, 0, 215),
		Vector3.new(31, 8, 160),
		Enum.Material.Water
	)
	-- Fourth-expansion water run to the new north gate. Ends at local z 455
	-- (world z ~465) so the surface stays inside the slab instead of standing
	-- as a bare water face past the terrain edge.
	terrain:FillBlock(
		CFrame.new(104, 0, 12) * CFrame.Angles(0, 0.08, 0) * CFrame.new(0, 0, 372.5),
		Vector3.new(31, 8, 165),
		Enum.Material.Water
	)
	-- Widen the creek into a proper lake bay east of camp, with a sandy
	-- beach along the western shore. Carve away any neighboring hill spill
	-- above the waterline first so the bay stays open water.
	terrain:FillCylinder(CFrame.new(105, 13, 48), 24, 42, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(105, -0.8, 48), 4.8, 36, Enum.Material.Water)
	terrain:FillCylinder(CFrame.new(112, -0.8, 22), 4.8, 26, Enum.Material.Water)
	-- Sand needs full voxel depth to dominate the grass at terrain resolution;
	-- a thin cap simply blends away
	terrain:FillCylinder(CFrame.new(78, -3.2, 48), 8.5, 16, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(80, -3.2, 28), 8.5, 12, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(80, -3.2, 66), 8.5, 12, Enum.Material.Sand)

	-- Lake x3: the bay above stays the camp-side shore; these basins wrap the
	-- Camp Aurora bank (Landmarks re-grasses its 76x64 rectangle afterwards,
	-- which is what carves the island's shoreline) so the ruins sit across
	-- open water on every side. Every fill keeps the bay's vertical band
	-- (top y=1.6 -> rendered surface ~4.0) so WATER_SURFACE_Y consumers and
	-- every pinned floating prop stay calibrated. Air carves first (see the
	-- engine rule at the creek fills), radius/size +3 over the water's.
	terrain:FillCylinder(CFrame.new(122, 13, 72), 24, 33, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(152, 13, 102), 24, 48, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(192, 13, 84), 24, 23, Enum.Material.Air)
	-- Water-sports basin: the old r45 north basin opens into one big body
	-- (x 132..208, z 78..190 plus the r45 west bulge) filling the northeast
	-- meadow the corner-filler domes used to occupy. East edge stops at x 208
	-- (carve 211) so the walk strip under the far-shore ridge — the "long way"
	-- to the Aurora Overlook at (219, 102) — stays dry; the north lobe stops
	-- at z 190 (carve 193) short of Backcountry's extended scatter skip
	-- (z < 200) and west of it the creek keeps an 8-stud bank (creek carve
	-- reaches x ~137 there). Same vertical band as every other lake fill.
	terrain:FillBlock(CFrame.new(170, 13, 122), Vector3.new(82, 24, 94), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(178, 13, 178), Vector3.new(66, 24, 30), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(203, 13, 20), Vector3.new(26, 24, 146), Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(170, 13, -68), 24, 45, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(158, 13, -36), 24, 33, Enum.Material.Air)
	terrain:FillBlock(CFrame.new(120.5, 13, -72), Vector3.new(22, 24, 28), Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(122, 0, 72), 8, 30, Enum.Material.Water) -- bay-to-north neck
	terrain:FillCylinder(CFrame.new(152, 0, 102), 8, 45, Enum.Material.Water) -- north basin, west bulge
	terrain:FillCylinder(CFrame.new(192, 0, 84), 8, 20, Enum.Material.Water) -- northeast corner
	terrain:FillBlock(
		CFrame.new(170, 0, 122),
		Vector3.new(76, 8, 88),
		Enum.Material.Water
	) -- water-sports basin, main body
	terrain:FillBlock(
		CFrame.new(178, 0, 178),
		Vector3.new(60, 8, 24),
		Enum.Material.Water
	) -- water-sports basin, north lobe
	terrain:FillBlock(
		CFrame.new(203, 0, 20),
		Vector3.new(22, 8, 140),
		Enum.Material.Water
	) -- east channel behind Aurora
	terrain:FillCylinder(CFrame.new(170, 0, -68), 8, 42, Enum.Material.Water) -- south basin
	terrain:FillCylinder(CFrame.new(158, 0, -36), 8, 30, Enum.Material.Water) -- south basin, Aurora shore
	terrain:FillBlock(
		CFrame.new(120.5, 0, -72),
		Vector3.new(18, 8, 24),
		Enum.Material.Water
	) -- strait joining the creek to the south basin (south of the mines bluff)
	-- Beaches on the enlarged shoreline (full voxel depth, same as the bay's).
	-- The old north-basin-head beach at (160, 149) is open water now; its
	-- replacement sits on the water-sports basin's north shore, plus a cove
	-- on the east strip below the Aurora Overlook.
	terrain:FillCylinder(CFrame.new(97, -3.2, 70), 8.5, 8, Enum.Material.Sand) -- swimming-hole cove
	terrain:FillCylinder(CFrame.new(133, -3.2, -52), 8.5, 9, Enum.Material.Sand) -- south basin head
	terrain:FillCylinder(CFrame.new(172, -3.2, 192), 8.5, 8, Enum.Material.Sand) -- north-shore beach
	terrain:FillCylinder(CFrame.new(206, -3.2, 120), 8.5, 8, Enum.Material.Sand) -- overlook cove

	-- Sits below the storm-cellar tunnel (floor ~-6.9) so the passage can be
	-- carved through the terrain block above it
	local bounds = createPart(
		parent,
		"CampGround",
		Vector3.new(WORLD_SLAB_SIZE.X, 1, WORLD_SLAB_SIZE.Z),
		CFrame.new(25, -9, 12),
		Color3.fromRGB(59, 82, 52),
		Enum.Material.Grass,
		1
	)
	bounds.CanCollide = false
	bounds.CanTouch = false
	bounds.CanQuery = false

	-- Day-phase stand-in for the removed south boundary domes: while the town
	-- is intangible (daytime), this keeps campers (and swimmers crossing the
	-- south basin) from wandering onto its non-collidable ground and falling
	-- through the world. SetNight lowers it when the town turns solid. Spans
	-- the full slab width, tall enough that nothing hops it off a hill toe.
	local dayWall = createPart(
		parent,
		"TownApproachDayWall",
		-- Wider than the slab: the far-shore ridge dome bulges past the east
		-- edge and its outer flank would otherwise walk around the wall's end.
		-- Width tracks the fourth-expansion slab (x -550..250).
		Vector3.new(900, 34, 2),
		CFrame.new(-150, 13, -110),
		Color3.fromRGB(59, 82, 52),
		Enum.Material.SmoothPlastic,
		1
	)
	dayWall.CanTouch = false
	dayWall.CanQuery = false
end

local function cloneAuthoredMap(folderName: string): Model?
	local assets = ServerStorage:FindFirstChild("ServerAssets")
	local maps = if assets then assets:FindFirstChild("Maps") else nil
	local source = if maps then maps:FindFirstChild(folderName) else nil
	return if source and source:IsA("Model") then source:Clone() else nil
end

function ProductionMapService.new(
	onObjective: ObjectiveHandler,
	onEvidence: EvidenceHandler,
	onSideObjective: SideObjectiveHandler?
): ProductionMapService
	local runtime = Workspace:WaitForChild("Runtime")
	local mapFolder = runtime:WaitForChild("Map")
	local evidenceFolder = runtime:WaitForChild("Evidence")
	assert(mapFolder:IsA("Folder"), "Workspace.Runtime.Map must be a Folder")
	assert(evidenceFolder:IsA("Folder"), "Workspace.Runtime.Evidence must be a Folder")
	mapFolder:ClearAllChildren()
	evidenceFolder:ClearAllChildren()

	local dayCamp = Instance.new("Folder")
	dayCamp.Name = "DayCamp"
	dayCamp.Parent = mapFolder
	local nightTown = Instance.new("Folder")
	nightTown.Name = "NightTown"
	nightTown.Parent = mapFolder
	local objectivesFolder = Instance.new("Folder")
	objectivesFolder.Name = "Objectives"
	objectivesFolder.Parent = dayCamp

	local self: ProductionMapService = setmetatable({
		mapFolder = mapFolder,
		dayCamp = dayCamp,
		nightTown = nightTown,
		objectivesFolder = objectivesFolder,
		evidenceFolder = evidenceFolder,
		evidenceSockets = {},
		onObjective = onObjective,
		onEvidence = onEvidence,
		onSideObjective = onSideObjective,
		evidenceClaimed = {},
		interactiveDoors = {},
		weatherId = "Clear",
		weatherSeed = 0,
		rainPart = nil,
		stormToken = 0,
		sideObjectivePrompts = {},
		sideObjectiveParts = {},
		sideObjectiveComplete = {},
		activeObjectiveIds = {},
		objectivePromptsEnabled = false,
		coldCaseHandler = nil,
		keyPickupHandler = nil,
		lockedRoomHandler = nil,
		supplyCacheHandler = nil,
		lockedRooms = {},
		dayKeysFolder = nil,
		supplyCache = nil,
	}, ProductionMapService)
	hideDefaultBaseplate()
	configureLighting()
	self:Build()
	self:ResetRound()
	return self
end

function ProductionMapService:Build()
	local authoredCamp = cloneAuthoredMap("Camp")
	if authoredCamp then
		authoredCamp.Name = "AuthoredCamp"
		authoredCamp.Parent = self.dayCamp
		-- Strip legacy brick chimneys and add stovepipes to authored cabin models
		local cabinSet = { PineCabin = true, CreekCabin = true, CounselorLodge = true, SupplyCabin = true }
		for _, child in ipairs(authoredCamp:GetDescendants()) do
			if child:IsA("Model") and cabinSet[child.Name] then
				for _, part in ipairs(child:GetDescendants()) do
					if part:IsA("BasePart") and part.Name:lower():find("chimney") then
						part:Destroy()
					end
				end
				if not child:FindFirstChild("Stovepipe") then
					local floor = child:FindFirstChild("Floor")
					if floor then
						local pos = floor.Position - Vector3.new(0, 0.35, 0)
						local w = floor.Size.X
						createCylinder(child, "Stovepipe",
							Vector3.new(8, 0.52, 0.52),
							CFrame.new(pos + Vector3.new(w * 0.28, 14.0, 6.5)) * CFrame.Angles(0, 0, math.rad(90)),
							Color3.fromRGB(40, 36, 32), Enum.Material.Metal)
						createCylinder(child, "StovepipeCap",
							Vector3.new(0.55, 0.80, 0.80),
							CFrame.new(pos + Vector3.new(w * 0.28, 18.3, 6.5)) * CFrame.Angles(0, 0, math.rad(90)),
							Color3.fromRGB(52, 46, 40), Enum.Material.CorrodedMetal)
					end
				end
			end
		end
	else
		buildCampTerrain(self.dayCamp)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "CampSpawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.Position = Vector3.new(0, 1, 34)
		spawn.Color = Color3.fromRGB(106, 88, 64)
		spawn.Material = Enum.Material.WoodPlanks
		spawn.Transparency = 0.35
		spawn.Parent = self.dayCamp
		for segment = -3, 3 do
			createPart(
				self.dayCamp,
				"CampPath",
				Vector3.new(18 + math.abs(segment), 0.3, 28),
				CFrame.new(
					math.sin(segment * 0.85) * 3,
					0.66,
					segment * 24 + 5
				) * CFrame.Angles(0, math.rad(math.sin(segment) * 4), 0),
				Color3.fromRGB(117, 91, 64),
				Enum.Material.Ground
			)
		end
		-- Cabin base heights are seated per-site against the RENDERED voxel
		-- surface (measured in-boot 2026-08-09: Pine approach 2.24, Creek and
		-- the lodge 2.40, Supply 3.06). Y places the porch deck (base + 1.0)
		-- about 0.6 proud of the approach grass, which also finally exposes
		-- the stone foundation strip instead of burying it. The old uniform
		-- 0.5 predates the world-x2 slab and sank every porch below grade.
		table.insert(
			self.interactiveDoors,
			createCabin(self.dayCamp, "PineCabin", Vector3.new(-54, 1.85, 18), 24, 2)
		)
		table.insert(
			self.interactiveDoors,
			createCabin(self.dayCamp, "CreekCabin", Vector3.new(54, 2.0, 18), 24, 2)
		)
		table.insert(
			self.interactiveDoors,
			createCabin(self.dayCamp, "CounselorLodge", Vector3.new(0, 2.0, 74), 30)
		)
		table.insert(
			self.interactiveDoors,
			createCabin(self.dayCamp, "SupplyCabin", Vector3.new(-76, 2.65, -42), 18)
		)
		-- Cylinder axis is X; the roll stands it upright. Base stays planted at
		-- terrain level (Y 0.5) while the pit rises well proud of the grass.
		local fire = createPart(
			self.dayCamp,
			"Campfire",
			Vector3.new(3.4, 8, 8),
			CFrame.new(0, 2.2, 2) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(124, 78, 48),
			Enum.Material.Slate
		)
		fire.Shape = Enum.PartType.Cylinder
		fire:SetAttribute("SafeVolume", true)
		local flame = Instance.new("Fire")
		flame.Name = "CampFlame"
		flame.Color = Color3.fromRGB(255, 170, 66)
		flame.SecondaryColor = Color3.fromRGB(193, 65, 34)
		flame.Heat = 8
		flame.Size = 7
		flame.Parent = fire
		local fireLight = Instance.new("PointLight")
		fireLight.Name = "FireLight"
		fireLight.Brightness = 2.4
		fireLight.Range = 32
		fireLight.Color = Color3.fromRGB(255, 169, 82)
		fireLight.Shadows = true
		fireLight.Parent = fire
		local firePrompt = createPrompt(fire, "Tend Fire", "Campfire", 0.35)
		firePrompt.Triggered:Connect(function()
			flame.Size = if flame.Size > 7 then 7 else 10
			fireLight.Brightness = if fireLight.Brightness > 2.5 then 2.4 else 3.2
		end)
		for seatIndex = 1, 6 do
			local angle = (seatIndex / 6) * math.pi * 2
			local seat = Instance.new("Seat")
			seat.Name = "CampfireSeat"
			seat.Anchored = true
			seat.Size = Vector3.new(5, 1.2, 2)
			seat.CFrame = CFrame.new(
				math.cos(angle) * 10,
				1.2,
				2 + math.sin(angle) * 10
			) * CFrame.Angles(0, -angle + math.pi / 2, 0)
			seat.Color = Color3.fromRGB(83, 59, 39)
			seat.Material = Enum.Material.Wood
			seat.Parent = self.dayCamp
		end
		for index = 1, 30 do
			if index <= 3 or index >= 29 then
				-- Lakefront gap: the east-northeast sector stays open so the
				-- camp looks onto the lake instead of a tree wall
				continue
			end
			if index == 22 or index == 23 then
				-- These two land at (-11, -96) and (12, -105): mid-asphalt on
				-- the town's main road now that the south foothills are gone.
				continue
			end
			local angle = (index / 30) * math.pi * 2
			local radius = 91 + (index % 4) * 9
			createPineTree(
				self.dayCamp,
				Vector3.new(
					math.cos(angle) * radius,
					0.5,
					12 + math.sin(angle) * radius
				),
				18 + index % 5 * 2.5,
				if index % 2 == 0
					then Color3.fromRGB(43, 85, 57)
					else Color3.fromRGB(50, 94, 61)
			)
		end
		-- Mid-country forest belt at the old third-expansion line (radius
		-- 205-250). The boundary moved out again, so this ring now stands
		-- mid-meadow as the belt you pass through into the high frontier.
		-- The east span stays open (indices 1-7 and 41-48) exactly like the
		-- inner ring's lakefront gap, because that whole sector is the lake.
		for index = 1, 48 do
			if index <= 7 or index >= 41 then
				continue
			end
			local angle = (index / 48) * math.pi * 2
			local radius = 205 + (index % 4) * 15
			local treeX = math.cos(angle) * radius
			local treeZ = 12 + math.sin(angle) * radius
			if treeZ < -60 and treeX > -240 and treeX < 250 then
				-- Town overlap: these trunks would stand on Hollow Creek's
				-- streets and yards (the wider gate matches the wider ring).
				continue
			end
			if treeZ > 180 and treeX > 60 and treeX < 150 then
				-- Creek's north run: keep the water gate clear of trunks.
				continue
			end
			createPineTree(
				self.dayCamp,
				Vector3.new(treeX, expandedGroundHeight(treeX, treeZ), treeZ),
				19 + index % 6 * 2.5,
				if index % 2 == 0
					then Color3.fromRGB(43, 85, 57)
					else Color3.fromRGB(50, 94, 61)
			)
		end
		-- Boundary tree wall at the fourth-expansion edge. Three straight
		-- runs trace the doubled slab's open sides (north, west, and the
		-- northeast span north of the lake); the lake and the town own the
		-- other two. Trunks ride expandedGroundHeight so pines climb the
		-- moved boundary domes instead of drowning in them.
		local boundaryRuns: { { number } } = {
			-- { fromX, fromZ, toX, toZ }
			{ -510, 446, 228, 446 }, -- north edge
			{ -512, -120, -512, 432 }, -- west edge
			{ 234, 200, 234, 428 }, -- northeast span, north of the lake
		}
		for runIndex, run in boundaryRuns do
			local fromX, fromZ, toX, toZ = run[1], run[2], run[3], run[4]
			local runLength = math.sqrt((toX - fromX) ^ 2 + (toZ - fromZ) ^ 2)
			local steps = math.floor(runLength / 18)
			for step = 0, steps do
				local alpha = step / math.max(steps, 1)
				-- Deterministic jitter keeps the wall from reading as a fence
				local seed = runIndex * 97 + step * 31
				local treeX = fromX + (toX - fromX) * alpha + (seed % 11) - 5
				local treeZ = fromZ + (toZ - fromZ) * alpha + (seed % 7) - 3
				if treeZ > 430 and treeX > 112 and treeX < 172 then
					-- Creek's fourth-expansion gate: keep the mouth clear.
					continue
				end
				createPineTree(
					self.dayCamp,
					Vector3.new(treeX, expandedGroundHeight(treeX, treeZ), treeZ),
					19 + seed % 6 * 2.5,
					if seed % 2 == 0
						then Color3.fromRGB(43, 85, 57)
						else Color3.fromRGB(50, 94, 61)
				)
			end
		end
		for index = 1, 18 do
			local angle = index * 2.17
			local radius = 34 + (index % 5) * 10
			local rock = createPart(
				self.dayCamp,
				"ForestRock",
				Vector3.new(2.5 + index % 3, 1.6 + index % 2, 2.8 + (index + 1) % 3),
				CFrame.new(
					math.cos(angle) * radius,
					1.1,
					12 + math.sin(angle) * radius
				) * CFrame.Angles(index * 0.27, angle, index * 0.11),
				Color3.fromRGB(82, 88, 78),
				Enum.Material.Slate
			)
			rock.CanCollide = false
		end
		-- Waterfront: dock over the lake bay, boathouse with canoe rack,
		-- beached and floating canoes, lifeguard chair, and buoy line
		local dockWood = Color3.fromRGB(96, 70, 46)
		local dockDark = Color3.fromRGB(72, 52, 34)
		-- The terrain water voxelizes to a rendered surface at y=4.0 mid-bay
		-- (measured via ReadVoxels), NOT the nominal fill top of 1.6 — every
		-- floating part is pinned against the rendered surface
		createPart(self.dayCamp, "DockWalk", Vector3.new(26, 0.5, 3.6),
			CFrame.new(83, 5.25, 40), dockWood, Enum.Material.WoodPlanks)
		createPart(self.dayCamp, "DockPlatform", Vector3.new(8, 0.5, 8),
			CFrame.new(100, 5.25, 40), dockWood, Enum.Material.WoodPlanks)
		local dockPostSpots = {
			Vector3.new(74, 0, 38.5), Vector3.new(74, 0, 41.5),
			Vector3.new(82, 0, 38.5), Vector3.new(82, 0, 41.5),
			Vector3.new(90, 0, 38.5), Vector3.new(90, 0, 41.5),
			Vector3.new(97, 0, 36.5), Vector3.new(97, 0, 43.5),
			Vector3.new(103, 0, 36.5), Vector3.new(103, 0, 43.5),
		}
		for postIndex, postSpot in dockPostSpots do
			createCylinder(self.dayCamp, "DockPost" .. tostring(postIndex),
				Vector3.new(5.2, 0.55, 0.55),
				CFrame.new(postSpot + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				dockDark, Enum.Material.Wood)
		end
		-- Boarding ramp from the beach up to the raised deck
		local dockRamp = Instance.new("WedgePart")
		dockRamp.Name = "DockRamp"
		dockRamp.Anchored = true
		dockRamp.Size = Vector3.new(3.6, 4.6, 7)
		dockRamp.CFrame = CFrame.new(66.5, 3.2, 40) * CFrame.Angles(0, math.rad(90), 0)
		dockRamp.Color = dockWood
		dockRamp.Material = Enum.Material.WoodPlanks
		dockRamp.TopSurface = Enum.SurfaceType.Smooth
		dockRamp.Parent = self.dayCamp
		createPart(self.dayCamp, "DockLanternPost", Vector3.new(0.4, 4, 0.4),
			CFrame.new(103, 7.5, 43.5), dockDark, Enum.Material.Wood)
		local dockLamp = createPart(self.dayCamp, "DockLantern", Vector3.new(0.8, 0.8, 0.8),
			CFrame.new(103, 9.8, 43.5), Color3.fromRGB(255, 211, 132), Enum.Material.Neon)
		dockLamp.Shape = Enum.PartType.Ball
		dockLamp.CanCollide = false
		local dockLight = Instance.new("PointLight")
		dockLight.Brightness = 0.6
		dockLight.Range = 18
		dockLight.Color = Color3.fromRGB(255, 220, 161)
		dockLight.Parent = dockLamp
		-- Boathouse: open east wall faces the water
		local bhX, bhZ = 74, 68
		Workspace.Terrain:FillBlock(
			CFrame.new(bhX, 1.4, bhZ),
			Vector3.new(9, 7, 7),
			Enum.Material.Air
		)
		createPart(self.dayCamp, "BoathouseFloor", Vector3.new(10, 0.6, 8),
			CFrame.new(bhX, 0.8, bhZ), dockDark, Enum.Material.WoodPlanks)
		createPart(self.dayCamp, "BoathouseWestWall", Vector3.new(0.7, 7, 8),
			CFrame.new(bhX - 4.65, 4.6, bhZ), Color3.fromRGB(112, 102, 90), Enum.Material.WoodPlanks)
		createPart(self.dayCamp, "BoathouseNorthWall", Vector3.new(10, 7, 0.7),
			CFrame.new(bhX, 4.6, bhZ + 3.65), Color3.fromRGB(112, 102, 90), Enum.Material.WoodPlanks)
		createPart(self.dayCamp, "BoathouseSouthWall", Vector3.new(10, 7, 0.7),
			CFrame.new(bhX, 4.6, bhZ - 3.65), Color3.fromRGB(112, 102, 90), Enum.Material.WoodPlanks)
		createPart(self.dayCamp, "BoathouseRoof", Vector3.new(11, 0.4, 9.5),
			CFrame.new(bhX, 8.6, bhZ) * CFrame.Angles(0, 0, math.rad(6)),
			Color3.fromRGB(88, 84, 76), Enum.Material.CorrodedMetal)
		local boathouseSign = createPart(self.dayCamp, "BoathouseSign", Vector3.new(5, 1.4, 0.3),
			CFrame.new(bhX, 6.5, bhZ - 4.05), Color3.fromRGB(46, 32, 22), Enum.Material.Wood)
		createSign(boathouseSign, "BOATHOUSE", Color3.fromRGB(226, 190, 114))
		for railSide = -1, 1, 2 do
			createPart(self.dayCamp, "CanoeRackRail" .. (if railSide < 0 then "L" else "R"),
				Vector3.new(0.35, 0.35, 7),
				CFrame.new(bhX + 0.2 + railSide * 0.9, 2.6, bhZ), dockDark, Enum.Material.Wood)
			for postZ = -1, 1, 2 do
				createPart(self.dayCamp, "CanoeRackPost", Vector3.new(0.35, 2.6, 0.35),
					CFrame.new(bhX + 0.2 + railSide * 0.9, 1.3, bhZ + postZ * 3),
					dockDark, Enum.Material.Wood)
			end
		end
		-- Canoes: one racked, one beached, one tied at the dock
		local canoeSpots = {
			{ cframe = CFrame.new(74.2, 3.35, 68), color = Color3.fromRGB(74, 110, 60) },
			{ cframe = CFrame.new(80, 1.0, 26) * CFrame.Angles(0, math.rad(35), 0), color = Color3.fromRGB(52, 118, 124) },
			{ cframe = CFrame.new(101, 4.25, 33) * CFrame.Angles(0, math.rad(75), 0), color = Color3.fromRGB(150, 54, 44) },
		}
		for canoeIndex, canoe in canoeSpots do
			local suffix = tostring(canoeIndex)
			createPart(self.dayCamp, "CanoeHull" .. suffix, Vector3.new(1.6, 0.9, 7),
				canoe.cframe, canoe.color, Enum.Material.SmoothPlastic)
			local inner = createPart(self.dayCamp, "CanoeInner" .. suffix, Vector3.new(1.2, 0.28, 5.4),
				canoe.cframe * CFrame.new(0, 0.33, 0), Color3.fromRGB(40, 34, 26), Enum.Material.Wood)
			inner.CanCollide = false
			for tip = -1, 1, 2 do
				local tipWedge = Instance.new("WedgePart")
				tipWedge.Name = "CanoeTip" .. suffix
				tipWedge.Anchored = true
				tipWedge.Size = Vector3.new(1.6, 0.9, 1.1)
				tipWedge.CFrame = canoe.cframe
					* CFrame.new(0, 0, tip * 4.05)
					* CFrame.Angles(0, if tip > 0 then math.pi else 0, 0)
				tipWedge.Color = canoe.color
				tipWedge.Material = Enum.Material.SmoothPlastic
				tipWedge.Parent = self.dayCamp
			end
		end
		-- Lifeguard chair on the beach
		local chairWhite = Color3.fromRGB(232, 232, 226)
		for legX = -1, 1, 2 do
			for legZ = -1, 1, 2 do
				createPart(self.dayCamp, "LifeguardLeg", Vector3.new(0.35, 5, 0.35),
					CFrame.new(64 + legX * 1.0, 2.5, 58 + legZ * 0.8),
					chairWhite, Enum.Material.SmoothPlastic)
			end
		end
		createPart(self.dayCamp, "LifeguardSeat", Vector3.new(2.6, 0.4, 2.2),
			CFrame.new(64, 5.2, 58), chairWhite, Enum.Material.SmoothPlastic)
		createPart(self.dayCamp, "LifeguardBack", Vector3.new(0.3, 2.2, 2.6),
			CFrame.new(62.9, 6.5, 58), Color3.fromRGB(190, 58, 48), Enum.Material.SmoothPlastic)
		local buoySpots = {
			Vector3.new(92, 4.15, 62), Vector3.new(103, 4.15, 66),
			Vector3.new(114, 4.15, 63), Vector3.new(123, 4.15, 57),
		}
		for buoyIndex, buoySpot in buoySpots do
			local buoy = createPart(self.dayCamp, "LakeBuoy" .. tostring(buoyIndex),
				Vector3.new(0.9, 0.9, 0.9), CFrame.new(buoySpot),
				Color3.fromRGB(198, 60, 48), Enum.Material.SmoothPlastic)
			buoy.Shape = Enum.PartType.Ball
			buoy.CanCollide = false
		end
		-- Camp dressing: flagpole, picnic tables, trail signpost, archery range
		createCylinder(self.dayCamp, "Flagpole", Vector3.new(18, 0.5, 0.5),
			CFrame.new(14, 9, 42) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(168, 168, 174), Enum.Material.Metal)
		local flagBall = createPart(self.dayCamp, "FlagpoleCap", Vector3.new(0.7, 0.7, 0.7),
			CFrame.new(14, 18.2, 42), Color3.fromRGB(198, 165, 32), Enum.Material.Metal)
		flagBall.Shape = Enum.PartType.Ball
		flagBall.CanCollide = false
		local flag = createPart(self.dayCamp, "CampFlag", Vector3.new(3.4, 2, 0.15),
			CFrame.new(15.95, 16.8, 42), Color3.fromRGB(58, 96, 64), Enum.Material.Fabric)
		flag.CanCollide = false
		local picnicSpots = {
			CFrame.new(24, 0, 12) * CFrame.Angles(0, math.rad(15), 0),
			CFrame.new(-24, 0, 8) * CFrame.Angles(0, math.rad(-20), 0),
		}
		for picnicIndex, picnicCF in picnicSpots do
			local suffix = tostring(picnicIndex)
			createPart(self.dayCamp, "PicnicTable" .. suffix, Vector3.new(7, 0.45, 3),
				picnicCF * CFrame.new(0, 2.6, 0), Color3.fromRGB(98, 72, 46), Enum.Material.WoodPlanks)
			for benchSide = -1, 1, 2 do
				createPart(self.dayCamp, "PicnicBench" .. suffix, Vector3.new(7, 0.35, 1.2),
					picnicCF * CFrame.new(0, 1.7, benchSide * 2.2),
					Color3.fromRGB(82, 60, 38), Enum.Material.WoodPlanks)
			end
		end
		createPart(self.dayCamp, "TrailPost", Vector3.new(0.5, 7, 0.5),
			CFrame.new(10, 3.5, 52), Color3.fromRGB(72, 52, 34), Enum.Material.Wood)
		local trailSigns = {
			{ text = "LAKE", height = 5.9, yaw = -35 },
			{ text = "CABINS", height = 5.0, yaw = 90 },
			{ text = "TOWN ROAD", height = 4.1, yaw = 180 },
		}
		for _, trailSign in trailSigns do
			local board = createPart(self.dayCamp, "TrailSign" .. trailSign.text,
				Vector3.new(3.6, 0.8, 0.22),
				CFrame.new(10, trailSign.height, 52) * CFrame.Angles(0, math.rad(trailSign.yaw), 0),
				Color3.fromRGB(56, 40, 26), Enum.Material.Wood)
			createSign(board, trailSign.text, Color3.fromRGB(226, 190, 114))
		end
		local targetSpots = { Vector3.new(-44, 0, -66), Vector3.new(-35, 0, -70) }
		for targetIndex, targetSpot in targetSpots do
			local suffix = tostring(targetIndex)
			createPart(self.dayCamp, "TargetPost" .. suffix, Vector3.new(0.5, 3.2, 0.5),
				CFrame.new(targetSpot + Vector3.new(0, 1.6, 0)),
				Color3.fromRGB(72, 52, 34), Enum.Material.Wood)
			createCylinder(self.dayCamp, "TargetFace" .. suffix, Vector3.new(0.5, 3.2, 3.2),
				CFrame.new(targetSpot + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(228, 224, 210), Enum.Material.SmoothPlastic)
			createCylinder(self.dayCamp, "TargetRing" .. suffix, Vector3.new(0.5, 1.9, 1.9),
				CFrame.new(targetSpot + Vector3.new(0, 3.2, 0.06)) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(190, 58, 48), Enum.Material.SmoothPlastic)
			createCylinder(self.dayCamp, "TargetBull" .. suffix, Vector3.new(0.5, 0.8, 0.8),
				CFrame.new(targetSpot + Vector3.new(0, 3.2, 0.12)) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(198, 165, 32), Enum.Material.SmoothPlastic)
		end
		createPart(self.dayCamp, "HayBale", Vector3.new(4, 2.2, 1.6),
			CFrame.new(-39.5, 1.1, -72), Color3.fromRGB(172, 150, 92), Enum.Material.Grass)
		-- Fire lookout tower: climbable via the north lattice, with a view
		-- over the whole camp and the town road
		local towerWood = Color3.fromRGB(84, 60, 38)
		local towerX, towerZ = 34, -70
		for legX = -1, 1, 2 do
			for legZ = -1, 1, 2 do
				createPart(self.dayCamp, "LookoutLeg", Vector3.new(0.8, 26, 0.8),
					CFrame.new(towerX + legX * 3.6, 13, towerZ + legZ * 3.6),
					towerWood, Enum.Material.Wood)
			end
		end
		for _, braceY in { 8, 17 } do
			for legX = -1, 1, 2 do
				createPart(self.dayCamp, "LookoutBraceNS", Vector3.new(0.5, 0.5, 7.6),
					CFrame.new(towerX + legX * 3.6, braceY, towerZ),
					towerWood, Enum.Material.Wood)
			end
			for legZ = -1, 1, 2 do
				createPart(self.dayCamp, "LookoutBraceEW", Vector3.new(7.6, 0.5, 0.5),
					CFrame.new(towerX, braceY, towerZ + legZ * 3.6),
					towerWood, Enum.Material.Wood)
			end
		end
		createPart(self.dayCamp, "LookoutFloor", Vector3.new(10, 0.6, 10),
			CFrame.new(towerX, 26, towerZ), Color3.fromRGB(96, 70, 46), Enum.Material.WoodPlanks)
		for legX = -1, 1, 2 do
			for legZ = -1, 1, 2 do
				createPart(self.dayCamp, "LookoutRailPost", Vector3.new(0.5, 3, 0.5),
					CFrame.new(towerX + legX * 4.7, 27.8, towerZ + legZ * 4.7),
					Color3.fromRGB(46, 32, 22), Enum.Material.Wood)
			end
		end
		createPart(self.dayCamp, "LookoutRailSouth", Vector3.new(10, 0.35, 0.35),
			CFrame.new(towerX, 29.2, towerZ + 4.7), Color3.fromRGB(46, 32, 22), Enum.Material.Wood)
		for legX = -1, 1, 2 do
			createPart(self.dayCamp, "LookoutRailSide", Vector3.new(0.35, 0.35, 10),
				CFrame.new(towerX + legX * 4.7, 29.2, towerZ), Color3.fromRGB(46, 32, 22), Enum.Material.Wood)
			-- North rail is split so climbers can step off the lattice
			createPart(self.dayCamp, "LookoutRailNorth", Vector3.new(3.4, 0.35, 0.35),
				CFrame.new(towerX + legX * 3.3, 29.2, towerZ - 4.7), Color3.fromRGB(46, 32, 22), Enum.Material.Wood)
		end
		local lookoutLattice = Instance.new("TrussPart")
		lookoutLattice.Name = "LookoutLattice"
		lookoutLattice.Anchored = true
		lookoutLattice.Size = Vector3.new(2, 26, 2)
		lookoutLattice.CFrame = CFrame.new(towerX, 13, towerZ - 5.9)
		lookoutLattice.Color = Color3.fromRGB(96, 78, 52)
		lookoutLattice.Material = Enum.Material.Wood
		lookoutLattice.TopSurface = Enum.SurfaceType.Smooth
		lookoutLattice.BottomSurface = Enum.SurfaceType.Smooth
		lookoutLattice.Parent = self.dayCamp
		for legX = -1, 1, 2 do
			for legZ = -1, 1, 2 do
				createPart(self.dayCamp, "LookoutRoofPost", Vector3.new(0.4, 4, 0.4),
					CFrame.new(towerX + legX * 4.2, 28.3, towerZ + legZ * 4.2),
					towerWood, Enum.Material.Wood)
			end
		end
		createPart(self.dayCamp, "LookoutRoof", Vector3.new(11, 0.4, 11),
			CFrame.new(towerX, 30.7, towerZ), Color3.fromRGB(88, 84, 76), Enum.Material.CorrodedMetal)
		local lookoutDesk = createPart(self.dayCamp, "LookoutDesk", Vector3.new(3, 0.4, 1.4),
			CFrame.new(towerX, 27.3, towerZ + 3.8), Color3.fromRGB(91, 64, 43), Enum.Material.WoodPlanks)
		createInspectPrompt(
			lookoutDesk,
			"Fire watch log",
			"Saw lights moving in the old town again. Third night running. Nobody believes me."
		)
		-- Storm cellar: hidden tunnel from behind Pine Cabin south to the
		-- tree line by the town road. Carved through the terrain block and
		-- lined with mine-shaft timber framing.
		local terrainRef = Workspace.Terrain
		terrainRef:FillBlock(CFrame.new(-58, -3.25, 36), Vector3.new(5, 8.5, 8), Enum.Material.Air)
		terrainRef:FillBlock(CFrame.new(-58, -4.5, -15), Vector3.new(5, 7, 110), Enum.Material.Air)
		terrainRef:FillBlock(CFrame.new(-22, -4.5, -70), Vector3.new(77, 7, 5), Enum.Material.Air)
		terrainRef:FillBlock(CFrame.new(14, -3.25, -74), Vector3.new(5, 8.5, 10), Enum.Material.Air)
		-- Thin the surface band directly over the passage so it cannot sag
		-- into the tunnel as a colliding membrane (part walls and ceiling
		-- seal the passage; a 3-wide low-occupancy seam is invisible above)
		terrainRef:FillBlock(CFrame.new(-58, 1, -17), Vector3.new(3, 3.5, 97), Enum.Material.Air)
		terrainRef:FillBlock(CFrame.new(-22, 1, -70), Vector3.new(74, 3.5, 3), Enum.Material.Air)
		-- Open the L-junction corner fully — sized to swallow whole 4-stud
		-- voxel cells (partial Air fills only reduce occupancy and leave
		-- rubble humps that marching-cubes bulges past the wall parts)
		terrainRef:FillBlock(CFrame.new(-60, -4, -72), Vector3.new(12, 8, 12), Enum.Material.Air)
		local rampEntry = Instance.new("WedgePart")
		rampEntry.Name = "CellarRampEntry"
		rampEntry.Anchored = true
		rampEntry.Size = Vector3.new(4.6, 7, 8)
		rampEntry.CFrame = CFrame.new(-58, -3, 36) * CFrame.Angles(0, math.pi, 0)
		rampEntry.Color = Color3.fromRGB(88, 62, 40)
		rampEntry.Material = Enum.Material.WoodPlanks
		rampEntry.Parent = self.dayCamp
		local rampExit = Instance.new("WedgePart")
		rampExit.Name = "CellarRampExit"
		rampExit.Anchored = true
		rampExit.Size = Vector3.new(4.6, 7, 9)
		rampExit.CFrame = CFrame.new(14, -3, -74.5) * CFrame.Angles(0, math.pi, 0)
		rampExit.Color = Color3.fromRGB(88, 62, 40)
		rampExit.Material = Enum.Material.WoodPlanks
		rampExit.Parent = self.dayCamp
		createPart(self.dayCamp, "TunnelFloorSouth", Vector3.new(4.6, 0.3, 108),
			CFrame.new(-58, -6.85, -14), Color3.fromRGB(76, 56, 38), Enum.Material.WoodPlanks)
		createPart(self.dayCamp, "TunnelFloorEast", Vector3.new(72, 0.3, 4.6),
			CFrame.new(-21, -6.85, -70), Color3.fromRGB(76, 56, 38), Enum.Material.WoodPlanks)
		for _, frameZ in { 20, 0, -20, -40, -60 } do
			for frameSide = -1, 1, 2 do
				createPart(self.dayCamp, "TunnelPost", Vector3.new(0.5, 5.6, 0.5),
					CFrame.new(-58 + frameSide * 2.1, -4.1, frameZ),
					Color3.fromRGB(62, 44, 28), Enum.Material.Wood)
			end
			createPart(self.dayCamp, "TunnelLintel", Vector3.new(5.2, 0.5, 0.5),
				CFrame.new(-58, -1.4, frameZ), Color3.fromRGB(62, 44, 28), Enum.Material.Wood)
		end
		for _, frameX in { -40, -16, 4 } do
			for frameSide = -1, 1, 2 do
				createPart(self.dayCamp, "TunnelPostEast", Vector3.new(0.5, 5.6, 0.5),
					CFrame.new(frameX, -4.1, -70 + frameSide * 2.1),
					Color3.fromRGB(62, 44, 28), Enum.Material.Wood)
			end
			createPart(self.dayCamp, "TunnelLintelEast", Vector3.new(0.5, 0.5, 5.2),
				CFrame.new(frameX, -1.4, -70), Color3.fromRGB(62, 44, 28), Enum.Material.Wood)
		end
		-- The carved terrain shell is too thin to enclose the passage; part
		-- walls and ceilings make it a sealed mine shaft regardless of how
		-- the voxels render
		local earthWall = Color3.fromRGB(58, 50, 44)
		local tunnelCeil = Color3.fromRGB(64, 46, 30)
		for _, wallX in { -60.4, -55.6 } do
			createPart(self.dayCamp, "TunnelWallNS", Vector3.new(0.5, 6, 106),
				CFrame.new(wallX, -4, -13), earthWall, Enum.Material.Slate)
		end
		createPart(self.dayCamp, "TunnelCeilNS", Vector3.new(5.3, 0.5, 97.5),
			CFrame.new(-58, -1.15, -17.25), tunnelCeil, Enum.Material.WoodPlanks)
		createPart(self.dayCamp, "TunnelWallES", Vector3.new(71.4, 6, 0.5),
			CFrame.new(-24.3, -4, -72.4), earthWall, Enum.Material.Slate)
		createPart(self.dayCamp, "TunnelWallEN", Vector3.new(72, 6, 0.5),
			CFrame.new(-19.5, -4, -67.6), earthWall, Enum.Material.Slate)
		createPart(self.dayCamp, "TunnelCapWest", Vector3.new(0.5, 6, 5.3),
			CFrame.new(-60.3, -4, -70), earthWall, Enum.Material.Slate)
		createPart(self.dayCamp, "TunnelCapEast", Vector3.new(0.5, 6, 5.3),
			CFrame.new(16.3, -4, -70), earthWall, Enum.Material.Slate)
		createPart(self.dayCamp, "TunnelCeilEW", Vector3.new(77, 0.5, 5.3),
			CFrame.new(-22, -1.15, -70), tunnelCeil, Enum.Material.WoodPlanks)
		for _, exitWallX in { 11.6, 16.4 } do
			createPart(self.dayCamp, "TunnelExitWall", Vector3.new(0.5, 6, 10),
				CFrame.new(exitWallX, -4, -74.5), earthWall, Enum.Material.Slate)
		end
		local tunnelLampSpots = {
			Vector3.new(-58, -2, 10), Vector3.new(-58, -2, -45),
			Vector3.new(-40, -2, -70), Vector3.new(0, -2, -70),
		}
		for lampIndex, lampSpot in tunnelLampSpots do
			local tunnelLamp = createPart(self.dayCamp, "TunnelLamp" .. tostring(lampIndex),
				Vector3.new(0.5, 0.5, 0.5), CFrame.new(lampSpot),
				Color3.fromRGB(255, 196, 110), Enum.Material.Neon)
			tunnelLamp.CanCollide = false
			local tunnelLight = Instance.new("PointLight")
			tunnelLight.Brightness = 0.8
			tunnelLight.Range = 12
			tunnelLight.Color = Color3.fromRGB(255, 200, 120)
			tunnelLight.Parent = tunnelLamp
		end
		-- Cellar mouth dressing: stone cheeks, flung-open doors, and a sign
		local cellarStone = Color3.fromRGB(96, 96, 90)
		for cheekSide = -1, 1, 2 do
			createPart(self.dayCamp, "CellarCheek", Vector3.new(0.6, 1.6, 8.4),
				CFrame.new(-58 + cheekSide * 2.9, 1.3, 36), cellarStone, Enum.Material.Concrete)
		end
		for doorSide = -1, 1, 2 do
			local cellarDoor = createPart(self.dayCamp, "CellarDoorOpen", Vector3.new(2.4, 0.3, 5),
				CFrame.new(-58 + doorSide * 4.9, 0.68, 34.5) * CFrame.Angles(0, 0, math.rad(doorSide * 6)),
				Color3.fromRGB(72, 50, 32), Enum.Material.WoodPlanks)
			cellarDoor.CanCollide = false
		end
		local cellarSign = createPart(self.dayCamp, "CellarSign", Vector3.new(3.2, 1, 0.25),
			CFrame.new(-62.5, 1.6, 31), Color3.fromRGB(56, 40, 26), Enum.Material.Wood)
		createSign(cellarSign, "STORM CELLAR", Color3.fromRGB(226, 190, 114))
		for bushIndex, bushSpot in { Vector3.new(11, 0.8, -79.5), Vector3.new(17.5, 0.9, -77.5) } do
			local exitBush = createPart(self.dayCamp, "ExitBush" .. tostring(bushIndex),
				Vector3.new(2.6, 2.0, 2.4), CFrame.new(bushSpot),
				Color3.fromRGB(50, 94, 61), Enum.Material.Grass)
			exitBush.Shape = Enum.PartType.Ball
			exitBush.CanCollide = false
		end
	end

	-- Strip any surviving brick chimneys (from authored place-file content or ServerStorage models)
	-- and add stovepipes if missing — runs unconditionally after both the authored and procedural paths
	local cabinNames = { PineCabin = true, CreekCabin = true, CounselorLodge = true, SupplyCabin = true }
	for _, child in ipairs(self.dayCamp:GetDescendants()) do
		if child:IsA("Model") and cabinNames[child.Name] then
			for _, part in ipairs(child:GetDescendants()) do
				if part:IsA("BasePart") and part.Name:lower():find("chimney") then
					part:Destroy()
				end
			end
			if not child:FindFirstChild("Stovepipe") then
				local floor = child:FindFirstChild("Floor")
				if floor then
					local pos = floor.Position - Vector3.new(0, 0.35, 0)
					local w = floor.Size.X
					createCylinder(child, "Stovepipe",
						Vector3.new(8, 0.52, 0.52),
						CFrame.new(pos + Vector3.new(w * 0.28, 14.0, 6.5)) * CFrame.Angles(0, 0, math.rad(90)),
						Color3.fromRGB(40, 36, 32), Enum.Material.Metal)
					createCylinder(child, "StovepipeCap",
						Vector3.new(0.55, 0.80, 0.80),
						CFrame.new(pos + Vector3.new(w * 0.28, 18.3, 6.5)) * CFrame.Angles(0, 0, math.rad(90)),
						Color3.fromRGB(52, 46, 40), Enum.Material.CorrodedMetal)
				end
			end
		end
	end

	for _, definition in OBJECTIVES do
		local station = Instance.new("Model")
		station.Name = definition.id
		station:SetAttribute("ObjectiveId", definition.id)
		station.Parent = self.objectivesFolder
		local root = createPart(
			station,
			"InteractionRoot",
			Vector3.new(8, 1.2, 8),
			CFrame.new(definition.position + Vector3.new(0, -1.4, 0)),
			definition.color,
			Enum.Material.WoodPlanks
		)
		root:SetAttribute("OriginalColor", definition.color)
		station.PrimaryPart = root
		if definition.id == "firewood" then
			for logIndex = 1, 6 do
				local row = (logIndex - 1) % 3
				local layer = math.floor((logIndex - 1) / 3)
				createCylinder(
					station,
					"SplitLog",
					Vector3.new(5.8, 1.05, 1.05),
					CFrame.new(
						definition.position
							+ Vector3.new(0, layer * 1.15, row * 1.35 - 1.35)
					),
					Color3.fromRGB(116, 73, 42),
					Enum.Material.Wood
				)
			end
		elseif definition.id == "generator" then
			local generator = createPart(
				station,
				"Generator",
				Vector3.new(7, 5, 5),
				CFrame.new(definition.position + Vector3.new(0, 0.55, 0)),
				Color3.fromRGB(63, 75, 71),
				Enum.Material.DiamondPlate
			)
			for vent = -1, 1, 2 do
				createPart(
					station,
					"Vent",
					Vector3.new(0.25, 2.2, 1.5),
					generator.CFrame * CFrame.new(3.58, 0.5, vent * 1.35),
					Color3.fromRGB(28, 33, 32),
					Enum.Material.Metal
				)
			end
			local statusLamp = createPart(
				station,
				"StatusLamp",
				Vector3.new(0.45, 0.45, 0.45),
				generator.CFrame * CFrame.new(3.7, 1.55, 0),
				Color3.fromRGB(187, 72, 49),
				Enum.Material.Neon
			)
			statusLamp:SetAttribute("CompletionIndicator", true)
			statusLamp.CanCollide = false
			-- Wire-sequence minigame targets: three loose wires that must be
			-- reconnected in a seeded order (validated server-side).
			for wireIndex, wireDefinition in WIRE_DEFINITIONS do
				local wirePart = createPart(
					station,
					"Wire" .. wireDefinition.id,
					Vector3.new(0.6, 0.6, 0.6),
					generator.CFrame * CFrame.new(-3.6, 0.4, (wireIndex - 2) * 1.6),
					wireDefinition.color,
					Enum.Material.Neon
				)
				wirePart.CanCollide = false
				local wireId = wireDefinition.id
				local wirePrompt = createPrompt(wirePart, "Connect", "Loose wire", 0.35)
				wirePrompt.MaxActivationDistance = 10
				wirePrompt.Triggered:Connect(function(player: Player)
					self.onObjective(player, "generator#" .. wireId)
				end)
			end
		elseif definition.id == "supplies" then
			for crateIndex = 1, 4 do
				local x = if crateIndex % 2 == 0 then 2.2 else -2.2
				local y = if crateIndex > 2 then 2.2 else 0
				createPart(
					station,
					"SupplyCrate",
					Vector3.new(4, 3.6, 4),
					CFrame.new(definition.position + Vector3.new(x, y, 0)),
					Color3.fromRGB(105, 78, 48),
					Enum.Material.WoodPlanks
				)
			end
			-- Carry minigame drop zone near the campfire: picking up a crate at
			-- the pile and dropping it here completes the task (server-validated).
			local dropZone = createPart(
				station,
				"SupplyDropZone",
				Vector3.new(6, 0.4, 6),
				CFrame.new(10, 0.45, 10),
				Color3.fromRGB(96, 82, 54),
				Enum.Material.WoodPlanks
			)
			local dropMarker = Instance.new("BillboardGui")
			dropMarker.Name = "DropZoneMarker"
			dropMarker.Size = UDim2.new(6, 0, 1.5, 0)
			dropMarker.StudsOffset = Vector3.new(0, 4, 0)
			dropMarker.AlwaysOnTop = true
			dropMarker.MaxDistance = 55
			dropMarker.Parent = dropZone
			local dropText = Instance.new("TextLabel")
			dropText.BackgroundColor3 = Color3.fromRGB(13, 17, 16)
			dropText.BackgroundTransparency = 0.12
			dropText.BorderSizePixel = 0
			dropText.Size = UDim2.fromScale(1, 1)
			dropText.Font = Enum.Font.GothamBold
			dropText.Text = "SUPPLY DROP"
			dropText.TextColor3 = Color3.fromRGB(244, 224, 176)
			dropText.TextScaled = true
			dropText.Parent = dropMarker
			local dropPrompt = createPrompt(dropZone, "Drop Crate", "Supply drop", 0.5)
			dropPrompt.Triggered:Connect(function(player: Player)
				self.onObjective(player, "supplies#drop")
			end)
		elseif definition.id == "waterpump" then
			createCylinder(
				station,
				"PumpBarrel",
				Vector3.new(3.2, 2.2, 2.2),
				CFrame.new(definition.position + Vector3.new(0, 0.9, 0))
					* CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(88, 104, 112),
				Enum.Material.Metal
			)
			createCylinder(
				station,
				"PumpSpout",
				Vector3.new(2.6, 0.5, 0.5),
				CFrame.new(definition.position + Vector3.new(1.6, 2, 0)),
				Color3.fromRGB(62, 74, 80),
				Enum.Material.CorrodedMetal
			)
			createPart(
				station,
				"PumpHandle",
				Vector3.new(0.4, 2.6, 0.4),
				CFrame.new(definition.position + Vector3.new(-1.2, 3, 0))
					* CFrame.Angles(0, 0, math.rad(24)),
				Color3.fromRGB(122, 66, 52),
				Enum.Material.Metal
			)
			createPart(
				station,
				"PumpTrough",
				Vector3.new(4.4, 1, 2),
				CFrame.new(definition.position + Vector3.new(2.6, 0.4, 0)),
				Color3.fromRGB(96, 78, 52),
				Enum.Material.WoodPlanks
			)
		elseif definition.id == "trailclear" then
			for branchIndex, branchSpec in {
				{ offset = Vector3.new(-1.6, 0.5, 0.4), yaw = 24 },
				{ offset = Vector3.new(0.8, 0.7, -0.8), yaw = -38 },
				{ offset = Vector3.new(0.2, 1.4, 0.9), yaw = 74 },
			} do
				createCylinder(
					station,
					"FallenBranch" .. tostring(branchIndex),
					Vector3.new(6.4, 0.7, 0.7),
					CFrame.new(definition.position + branchSpec.offset)
						* CFrame.Angles(0, math.rad(branchSpec.yaw), 0),
					Color3.fromRGB(92, 64, 40),
					Enum.Material.Wood
				)
			end
			local leafPile = createPart(
				station,
				"LeafPile",
				Vector3.new(3, 1.4, 3),
				CFrame.new(definition.position + Vector3.new(2.2, 0.3, -2)),
				Color3.fromRGB(74, 96, 54),
				Enum.Material.Grass
			)
			leafPile.Shape = Enum.PartType.Ball
			leafPile.CanCollide = false
		elseif definition.id == "canoe" then
			local hull = createPart(
				station,
				"CanoeHull",
				Vector3.new(11, 1.1, 2.4),
				CFrame.new(definition.position + Vector3.new(0, 1.5, 0))
					* CFrame.Angles(0, math.rad(18), 0),
				Color3.fromRGB(146, 84, 52),
				Enum.Material.WoodPlanks
			)
			for standOffset = -1, 1, 2 do
				createPart(
					station,
					"CanoeStand",
					Vector3.new(0.7, 1.1, 3),
					hull.CFrame * CFrame.new(standOffset * 3.6, -1, 0),
					Color3.fromRGB(84, 60, 38),
					Enum.Material.Wood
				)
			end
			createPart(
				station,
				"CanoePaddle",
				Vector3.new(0.35, 3.4, 0.35),
				CFrame.new(definition.position + Vector3.new(3.4, 1.7, 2.4))
					* CFrame.Angles(0, 0, math.rad(12)),
				Color3.fromRGB(168, 128, 82),
				Enum.Material.Wood
			)
		elseif definition.id == "ropes" then
			-- Climbable ropes course: stepping stumps over a mud pit, a rope-rail
			-- balance beam, rising jump pads, a wooden lattice climb, and the
			-- completion platform (InteractionRoot) at the top with a slide down.
			local base = Vector3.new(definition.position.X, 0, definition.position.Z)
			local postColor = Color3.fromRGB(84, 60, 38)
			local stumpColor = Color3.fromRGB(116, 84, 50)
			local ropeColor = Color3.fromRGB(168, 142, 96)
			local platformTrim = Color3.fromRGB(46, 32, 22)
			for _, corner in {
				Vector3.new(-3.4, 0, -3.4),
				Vector3.new(-3.4, 0, 3.4),
				Vector3.new(3.4, 0, -3.4),
				Vector3.new(3.4, 0, 3.4),
			} do
				createPart(
					station,
					"TowerPost",
					Vector3.new(0.9, 15, 0.9),
					CFrame.new(base + corner + Vector3.new(0, 7.5, 0)),
					postColor,
					Enum.Material.Wood
				)
			end
			local gateBoard = createPart(
				station,
				"RopesSign",
				Vector3.new(7, 2.6, 0.5),
				CFrame.new(base + Vector3.new(-20, 5.4, 10))
					* CFrame.Angles(0, math.rad(140), 0),
				platformTrim,
				Enum.Material.WoodPlanks
			)
			createSign(gateBoard, "ROPES COURSE", Color3.fromRGB(244, 224, 176))
			for side = -1, 1, 2 do
				createPart(
					station,
					"GatePost",
					Vector3.new(0.7, 6.4, 0.7),
					CFrame.new(base + Vector3.new(-20, 3.2, 10))
						* CFrame.Angles(0, math.rad(140), 0)
						* CFrame.new(side * 3.6, 0, 0),
					postColor,
					Enum.Material.Wood
				)
			end
			createPart(
				station,
				"MudPit",
				Vector3.new(14, 0.28, 7),
				CFrame.new(base + Vector3.new(-10.75, 0.14, 7))
					* CFrame.Angles(0, math.rad(-10), 0),
				Color3.fromRGB(58, 44, 30),
				Enum.Material.Ground
			)
			local stumps = {
				{ offsetX = -16, offsetZ = 8, height = 2.4 },
				{ offsetX = -12.5, offsetZ = 6.5, height = 3.2 },
				{ offsetX = -9, offsetZ = 8, height = 4 },
				{ offsetX = -5.5, offsetZ = 6, height = 4.8 },
			}
			for stumpIndex, stump in stumps do
				createCylinder(
					station,
					"Stump" .. tostring(stumpIndex),
					Vector3.new(stump.height, 2.6, 2.6),
					CFrame.new(base + Vector3.new(stump.offsetX, stump.height / 2, stump.offsetZ))
						* CFrame.Angles(0, 0, math.rad(90)),
					stumpColor,
					Enum.Material.Wood
				)
			end
			createPart(
				station,
				"BalanceBeam",
				Vector3.new(8, 0.5, 1.3),
				CFrame.new(base + Vector3.new(-1, 4.55, 5)),
				stumpColor,
				Enum.Material.WoodPlanks
			)
			for _, beamEndX in { -5, 3 } do
				createPart(
					station,
					"RopePost",
					Vector3.new(0.4, 3, 0.4),
					CFrame.new(base + Vector3.new(beamEndX, 6.3, 6.2)),
					postColor,
					Enum.Material.Wood
				)
			end
			createCylinder(
				station,
				"BeamRope",
				Vector3.new(8, 0.24, 0.24),
				CFrame.new(base + Vector3.new(-1, 7.4, 6.2)),
				ropeColor,
				Enum.Material.Fabric
			)
			createPart(
				station,
				"LowPlatform",
				Vector3.new(5, 0.8, 5),
				CFrame.new(base + Vector3.new(6.5, 4.6, 4)),
				stumpColor,
				Enum.Material.WoodPlanks
			)
			createPart(
				station,
				"JumpPadA",
				Vector3.new(4, 0.8, 4),
				CFrame.new(base + Vector3.new(6, 6.8, -2)),
				stumpColor,
				Enum.Material.WoodPlanks
			)
			createPart(
				station,
				"JumpPadB",
				Vector3.new(4, 0.8, 4),
				CFrame.new(base + Vector3.new(4, 9, -5.5)),
				stumpColor,
				Enum.Material.WoodPlanks
			)
			for trussOffset = -1, 1, 2 do
				local truss = Instance.new("TrussPart")
				truss.Name = "ClimbLattice"
				truss.Anchored = true
				truss.Size = Vector3.new(2, 16, 2)
				truss.CFrame = CFrame.new(base + Vector3.new(-1.8 + trussOffset, 8, -5.2))
				truss.Color = Color3.fromRGB(96, 78, 52)
				truss.Material = Enum.Material.Wood
				truss.TopSurface = Enum.SurfaceType.Smooth
				truss.BottomSurface = Enum.SurfaceType.Smooth
				truss.Parent = station
			end
			for _, railPostOffset in {
				Vector3.new(-4, 0, 4),
				Vector3.new(4, 0, 4),
				Vector3.new(4, 0, -4),
			} do
				createPart(
					station,
					"RailPost",
					Vector3.new(0.5, 2.8, 0.5),
					CFrame.new(base + railPostOffset + Vector3.new(0, 17, 0)),
					platformTrim,
					Enum.Material.Wood
				)
			end
			createPart(
				station,
				"RailNorth",
				Vector3.new(8.6, 0.35, 0.35),
				CFrame.new(base + Vector3.new(0, 18.3, 4)),
				platformTrim,
				Enum.Material.Wood
			)
			createPart(
				station,
				"RailEast",
				Vector3.new(0.35, 0.35, 8.6),
				CFrame.new(base + Vector3.new(4, 18.3, 0)),
				platformTrim,
				Enum.Material.Wood
			)
			createPart(
				station,
				"BellPost",
				Vector3.new(0.5, 3.2, 0.5),
				CFrame.new(base + Vector3.new(-3.2, 17.2, 3.4)),
				postColor,
				Enum.Material.Wood
			)
			local bell = createPart(
				station,
				"StatusLamp",
				Vector3.new(1.1, 1.1, 1.1),
				CFrame.new(base + Vector3.new(-3.2, 19.2, 3.4)),
				Color3.fromRGB(187, 72, 49),
				Enum.Material.Neon
			)
			bell.Shape = Enum.PartType.Ball
			bell:SetAttribute("CompletionIndicator", true)
			bell.CanCollide = false
			local slide = Instance.new("WedgePart")
			slide.Name = "ExitSlide"
			slide.Anchored = true
			slide.Size = Vector3.new(5, 15, 26)
			slide.CFrame = CFrame.new(base + Vector3.new(-17, 7.5, 0))
				* CFrame.Angles(0, math.pi / 2, 0)
			slide.Color = Color3.fromRGB(148, 108, 62)
			slide.Material = Enum.Material.SmoothPlastic
			slide.TopSurface = Enum.SurfaceType.Smooth
			slide.BottomSurface = Enum.SurfaceType.Smooth
			slide.Parent = station
			for railOffset = -1, 1, 2 do
				local slideRail = Instance.new("WedgePart")
				slideRail.Name = "SlideRail"
				slideRail.Anchored = true
				slideRail.Size = Vector3.new(0.5, 16, 26)
				slideRail.CFrame = CFrame.new(
					base + Vector3.new(-17, 8, railOffset * 2.75)
				) * CFrame.Angles(0, math.pi / 2, 0)
				slideRail.Color = platformTrim
				slideRail.Material = Enum.Material.Wood
				slideRail.TopSurface = Enum.SurfaceType.Smooth
				slideRail.BottomSurface = Enum.SurfaceType.Smooth
				slideRail.Parent = station
			end
		end
		local marker = Instance.new("BillboardGui")
		marker.Name = "ObjectiveMarker"
		marker.Size = UDim2.new(7, 0, 2.2, 0)
		marker.StudsOffset = Vector3.new(0, 5.5, 0)
		marker.AlwaysOnTop = true
		marker.MaxDistance = 55
		marker.Parent = root
		local markerText = Instance.new("TextLabel")
		markerText.BackgroundColor3 = Color3.fromRGB(13, 17, 16)
		markerText.BackgroundTransparency = 0.12
		markerText.BorderSizePixel = 0
		markerText.Size = UDim2.fromScale(1, 1)
		markerText.Font = Enum.Font.GothamBold
		local effectLine = OBJECTIVE_EFFECT_LINES[definition.id]
		markerText.Text = if effectLine
			then string.upper(definition.name) .. "\n" .. effectLine
			else string.upper(definition.name)
		markerText:SetAttribute("OriginalText", markerText.Text)
		markerText.TextColor3 = Color3.fromRGB(244, 224, 176)
		markerText.TextScaled = true
		markerText.Parent = marker
		-- The generator has no single-press completion: its three wire prompts
		-- are the only way to finish it (seeded order, server-validated).
		if definition.id ~= "generator" then
			local promptConfig = OBJECTIVE_PROMPTS[definition.id]
			local prompt = createPrompt(
				root,
				if promptConfig then promptConfig.action else "Complete",
				definition.name,
				if promptConfig then promptConfig.hold else 1.1
			)
			prompt.Triggered:Connect(function(player: Player)
				self.onObjective(player, definition.id)
			end)
		end
	end

	local authoredTown = cloneAuthoredMap("NightTown")
	if authoredTown then
		authoredTown.Name = "AuthoredNightTown"
		authoredTown.Parent = self.nightTown
	else
		createPart(
			self.nightTown,
			"TownGround",
			Vector3.new(300, 1, 430),
			CFrame.new(0, -0.5, -230),
			Color3.fromRGB(47, 51, 48),
			Enum.Material.Ground
		)
		createPart(
			self.nightTown,
				"MainRoad",
				Vector3.new(50, 1, 360),
				CFrame.new(0, 0.05, -225),
				Color3.fromRGB(36, 39, 42),
			Enum.Material.Asphalt
		)
		for stripe = 1, 10 do
			createPart(
				self.nightTown,
				"FadedRoadStripe",
				Vector3.new(0.55, 0.08, 14),
				CFrame.new(0, 0.59, -62 - stripe * 32),
				Color3.fromRGB(177, 164, 111),
				Enum.Material.Concrete,
				0.2
			).CanCollide = false
		end
		for side = -1, 1, 2 do
			createPart(
				self.nightTown,
				"BrokenSidewalk",
				Vector3.new(8, 0.6, 350),
				CFrame.new(side * 29, 0.35, -225),
				Color3.fromRGB(83, 83, 79),
				Enum.Material.Concrete
			)
		end
		createPart(
			self.nightTown,
			"CrossRoad",
			Vector3.new(260, 1, 42),
			CFrame.new(0, 0.05, -190),
			Color3.fromRGB(38, 41, 43),
			Enum.Material.Asphalt
		)
		-- Buildings flank the north-south main road; rotate storefronts to face it
		-- (left side of the road faces +X = -90 deg, right side faces -X = +90 deg)
		table.insert(self.interactiveDoors, createBuilding(self.nightTown, "GeneralStore", Vector3.new(-73, 0, -185), Vector3.new(34, 19, 30), Color3.fromRGB(77, 72, 65), "GENERAL STORE", -math.pi / 2))
		table.insert(self.interactiveDoors, createBuilding(self.nightTown, "GasStation", Vector3.new(75, 0, -185), Vector3.new(35, 16, 28), Color3.fromRGB(82, 76, 65), "LAST STOP GAS", math.pi / 2))
		table.insert(self.interactiveDoors, createBuilding(self.nightTown, "ResidentialA", Vector3.new(-100, 0, -135), Vector3.new(30, 17, 28), Color3.fromRGB(71, 67, 64), "RESIDENCE", -math.pi / 2))
		table.insert(self.interactiveDoors, createBuilding(self.nightTown, "Factory", Vector3.new(-100, 0, -275), Vector3.new(48, 28, 45), Color3.fromRGB(64, 69, 70), "MILL NO. 7", -math.pi / 2))
		table.insert(self.interactiveDoors, createBuilding(self.nightTown, "PoliceStation", Vector3.new(92, 0, -360), Vector3.new(42, 22, 38), Color3.fromRGB(64, 72, 79), "POLICE", math.pi / 2))
		table.insert(self.interactiveDoors, createBuilding(self.nightTown, "CompanyHouse", Vector3.new(-100, 0, -390), Vector3.new(34, 18, 30), Color3.fromRGB(72, 65, 59), "COMPANY HOUSE", -math.pi / 2))
		buildWaterTower(self.nightTown, Vector3.new(110, 0, -292))
		-- Abandoned church at the far end of the road (prominent in Old Town 4
		-- aerial reference). Rebuilt 2026-08-09: the first pass had the facade
		-- and steeple on the SOUTH side (a blank brick wall greeted the road,
		-- and the door opened into the graveyard fence 5 studs away) with the
		-- steeple base standing inside the nave, corking the entrance. Now the
		-- entrance tower faces the road, the roof ridge runs along the nave,
		-- and the interior is a ruin worth walking into.
		do
			local cPos = Vector3.new(0, 0, -455)
			local cW, cH, cD = 28, 20, 36
			local churchColor = Color3.fromRGB(68, 63, 56)
			local roofC = Color3.fromRGB(42, 40, 38)
			local pewWood = Color3.fromRGB(66, 50, 34)
			local churchModel = Instance.new("Model")
			churchModel.Name = "AbandonedChurch"
			churchModel.Parent = self.nightTown
			local function churchWedge(name: string, size: Vector3, cframe: CFrame, color: Color3)
				local wedge = Instance.new("WedgePart")
				wedge.Name = name
				wedge.Size = size
				wedge.CFrame = cframe
				wedge.Color = color
				wedge.Material = Enum.Material.Slate
				wedge.Anchored = true
				wedge.Parent = churchModel
				return wedge
			end
			createPart(churchModel, "ChurchFloor", Vector3.new(cW, 0.8, cD), CFrame.new(cPos + Vector3.new(0, 0.4, 0)), churchColor, Enum.Material.Concrete)
			-- Front facade faces NORTH (+Z, toward the road's south terminus)
			createPart(churchModel, "ChurchFrontL", Vector3.new((cW - 8) / 2, cH, 1), CFrame.new(cPos + Vector3.new(-(4 + (cW - 8) / 4), cH / 2, cD / 2 - 0.5)), churchColor, Enum.Material.Brick)
			createPart(churchModel, "ChurchFrontR", Vector3.new((cW - 8) / 2, cH, 1), CFrame.new(cPos + Vector3.new((4 + (cW - 8) / 4), cH / 2, cD / 2 - 0.5)), churchColor, Enum.Material.Brick)
			createPart(churchModel, "ChurchArchHeader", Vector3.new(8, cH - 9, 1), CFrame.new(cPos + Vector3.new(0, 9 + (cH - 9) / 2, cD / 2 - 0.5)), churchColor, Enum.Material.Brick)
			createPart(churchModel, "ChurchBackWall", Vector3.new(cW, cH, 1), CFrame.new(cPos + Vector3.new(0, cH / 2, -cD / 2 + 0.5)), churchColor, Enum.Material.Brick)
			createPart(churchModel, "ChurchSideL", Vector3.new(1, cH, cD), CFrame.new(cPos + Vector3.new(-cW / 2 + 0.5, cH / 2, 0)), churchColor, Enum.Material.Brick)
			createPart(churchModel, "ChurchSideR", Vector3.new(1, cH, cD), CFrame.new(cPos + Vector3.new(cW / 2 - 0.5, cH / 2, 0)), churchColor, Enum.Material.Brick)
			-- Roof ridge runs along the nave (north-south); the two slopes
			-- stop just shy of the front wall so the tower stands clear.
			churchWedge("ChurchRoofW", Vector3.new(36.5, 8, 15),
				CFrame.new(cPos + Vector3.new(-7, cH + 4, -1)) * CFrame.Angles(0, math.rad(90), 0), roofC)
			churchWedge("ChurchRoofE", Vector3.new(36.5, 8, 15),
				CFrame.new(cPos + Vector3.new(7, cH + 4, -1)) * CFrame.Angles(0, math.rad(-90), 0), roofC)
			-- Triangular gable fills above the flat-topped front and back walls
			for _, gable in { { z = cD / 2 - 0.5 }, { z = -cD / 2 + 0.5 } } do
				churchWedge("ChurchGableW", Vector3.new(1, 8, 14),
					CFrame.new(cPos + Vector3.new(-7, cH + 4, gable.z)) * CFrame.Angles(0, math.rad(90), 0), churchColor)
				churchWedge("ChurchGableE", Vector3.new(1, 8, 14),
					CFrame.new(cPos + Vector3.new(7, cH + 4, gable.z)) * CFrame.Angles(0, math.rad(-90), 0), churchColor)
			end
			-- Entrance tower projects from the facade: open passage at ground
			-- level (5 studs wide — clears the navmesh agent), solid shaft
			-- above, belfry, tapered spire, cross.
			local towerZ = cD / 2 + 3.5
			for towerSide = -1, 1, 2 do
				createPart(churchModel, "TowerPillar", Vector3.new(1.2, 8.5, 7), CFrame.new(cPos + Vector3.new(towerSide * 3.1, 4.25, towerZ)), churchColor, Enum.Material.Brick)
			end
			createPart(churchModel, "TowerShaft", Vector3.new(7.4, 15.5, 7), CFrame.new(cPos + Vector3.new(0, 16.25, towerZ)), churchColor, Enum.Material.Brick)
			createPart(churchModel, "Belfry", Vector3.new(5.4, 6, 5.4), CFrame.new(cPos + Vector3.new(0, 27, towerZ)), churchColor, Enum.Material.Brick)
			for _, louver in {
				Vector3.new(0, 27.4, towerZ + 2.75), Vector3.new(0, 27.4, towerZ - 2.75),
				Vector3.new(2.75, 27.4, towerZ), Vector3.new(-2.75, 27.4, towerZ),
			} do
				local louverPart = createPart(churchModel, "BelfryLouver",
					if math.abs(louver.X) > 2 then Vector3.new(0.2, 3.2, 2.2) else Vector3.new(2.2, 3.2, 0.2),
					CFrame.new(cPos + louver), Color3.fromRGB(24, 22, 20), Enum.Material.SmoothPlastic)
				louverPart.CanCollide = false
			end
			-- Tapered spire: two crossed wedge tents read as a pyramid
			churchWedge("SpireN", Vector3.new(5.8, 8, 2.9),
				CFrame.new(cPos + Vector3.new(0, 34, towerZ + 1.45)) * CFrame.Angles(0, math.rad(180), 0), roofC)
			churchWedge("SpireS", Vector3.new(5.8, 8, 2.9),
				CFrame.new(cPos + Vector3.new(0, 34, towerZ - 1.45)), roofC)
			churchWedge("SpireE", Vector3.new(5.8, 8, 2.9),
				CFrame.new(cPos + Vector3.new(1.45, 34, towerZ)) * CFrame.Angles(0, math.rad(90), 0), roofC)
			churchWedge("SpireW", Vector3.new(5.8, 8, 2.9),
				CFrame.new(cPos + Vector3.new(-1.45, 34, towerZ)) * CFrame.Angles(0, math.rad(-90), 0), roofC)
			createPart(churchModel, "CrossV", Vector3.new(0.6, 4, 0.6), CFrame.new(cPos + Vector3.new(0, 40, towerZ)), Color3.fromRGB(72, 65, 55), Enum.Material.Wood)
			createPart(churchModel, "CrossH", Vector3.new(2.6, 0.6, 0.6), CFrame.new(cPos + Vector3.new(0, 40.8, towerZ)), Color3.fromRGB(72, 65, 55), Enum.Material.Wood)
			-- One door hangs ajar on the arch; its twin lies flat just inside
			createPart(churchModel, "ChurchDoorAjar", Vector3.new(3.8, 8.5, 0.4),
				CFrame.new(cPos + Vector3.new(-3.1, 4.25, cD / 2 - 2.2)) * CFrame.Angles(0, math.rad(-55), 0),
				Color3.fromRGB(52, 40, 28), Enum.Material.WoodPlanks)
			createPart(churchModel, "ChurchDoorFallen", Vector3.new(3.8, 0.35, 8.2),
				CFrame.new(cPos + Vector3.new(2.6, 1.0, cD / 2 - 6.5)) * CFrame.Angles(0, math.rad(12), 0),
				Color3.fromRGB(52, 40, 28), Enum.Material.WoodPlanks)
			-- Ruined nave: pew rows flank a 5-stud aisle, one row knocked over
			-- Rows start one stud closer to the door and the altar tucks toward
			-- the back wall so the chancel band stays > 4 studs — the navmesh
			-- refused the altar approach at the first spacing.
			for pewRow = 1, 4 do
				local pewZ = -15 + pewRow * 6
				for pewSide = -1, 1, 2 do
					if pewRow == 4 and pewSide == -1 then
						createPart(churchModel, "PewToppled", Vector3.new(9, 0.45, 1.1),
							CFrame.new(cPos + Vector3.new(-7, 1.35, pewZ)) * CFrame.Angles(math.rad(105), math.rad(8), 0),
							pewWood, Enum.Material.WoodPlanks)
						continue
					end
					createPart(churchModel, "PewSeat", Vector3.new(9, 0.45, 1.1),
						CFrame.new(cPos + Vector3.new(pewSide * 7, 1.85, pewZ)), pewWood, Enum.Material.WoodPlanks)
					createPart(churchModel, "PewBack", Vector3.new(9, 1.3, 0.25),
						CFrame.new(cPos + Vector3.new(pewSide * 7, 2.45, pewZ - 0.6)), pewWood, Enum.Material.WoodPlanks)
					for legSide = -1, 1, 2 do
						createPart(churchModel, "PewLeg", Vector3.new(0.4, 0.85, 1.1),
							CFrame.new(cPos + Vector3.new(pewSide * 7 + legSide * 4, 1.2, pewZ)), pewWood, Enum.Material.WoodPlanks)
					end
				end
			end
			createPart(churchModel, "ChurchAltar", Vector3.new(6, 2.2, 1.8), CFrame.new(cPos + Vector3.new(0, 1.9, -cD / 2 + 2.6)), Color3.fromRGB(58, 46, 34), Enum.Material.Wood)
			local altarCloth = createPart(churchModel, "AltarCloth", Vector3.new(6.4, 0.15, 2.0), CFrame.new(cPos + Vector3.new(0, 3.05, -cD / 2 + 2.6)), Color3.fromRGB(118, 112, 96), Enum.Material.Fabric)
			altarCloth.CanCollide = false
			for rubbleIndex, rubble in {
				{ size = Vector3.new(1.5, 1.0, 1.2), offset = Vector3.new(10.5, 1.3, -8), yaw = 20 },
				{ size = Vector3.new(1.1, 0.7, 0.9), offset = Vector3.new(11.5, 1.15, -10), yaw = -35 },
				{ size = Vector3.new(0.9, 0.5, 1.3), offset = Vector3.new(-11, 1.05, 5), yaw = 50 },
			} do
				createPart(churchModel, "ChurchRubble" .. tostring(rubbleIndex), rubble.size,
					CFrame.new(cPos + rubble.offset) * CFrame.Angles(0, math.rad(rubble.yaw), 0),
					Color3.fromRGB(74, 70, 64), Enum.Material.Concrete)
			end
			-- Arched windows on side walls
			for wSide = -1, 1, 2 do
				for wn = 1, 2 do
					createPart(churchModel, "ChurchWin" .. tostring(wSide) .. wn,
						Vector3.new(3.5, 5.5, 0.5),
						CFrame.new(cPos + Vector3.new(wSide * (cW / 2 - 0.25), cH * 0.62, (wn - 1.5) * cD * 0.30)),
						Color3.fromRGB(48, 55, 62), Enum.Material.SmoothPlastic)
				end
			end
			-- Gravel walk from the main road's south terminus to the tower door
			createPart(self.nightTown, "ChurchPath", Vector3.new(6, 0.6, 34),
				CFrame.new(0, 0.3, -420.5), Color3.fromRGB(58, 58, 52), Enum.Material.Ground)
		end
		for index = 1, 9 do
			createStreetlight(self.nightTown, Vector3.new(if index % 2 == 0 then 18 else -18, 0, -62 - index * 38))
		end
		-- The industrial pocket between the main road and Mill No. 7 starts
		-- unlit; repairing the mill fuse box brings these lanterns back.
		createStreetlight(self.nightTown, Vector3.new(-64, 0, -250), true)
		createStreetlight(self.nightTown, Vector3.new(-64, 0, -300), true)
		createStreetlight(self.nightTown, Vector3.new(-40, 0, -275), true)
		-- East district: a second north-south street with connecting cross
		-- streets turns the strip into a town grid — diner, motel, school,
		-- rowhouses, a fountain plaza, and the churchyard
		createPart(self.nightTown, "TownGroundEast", Vector3.new(120, 1, 430),
			CFrame.new(210, -0.5, -230), Color3.fromRGB(47, 51, 48), Enum.Material.Ground)
		createPart(self.nightTown, "EastStreet", Vector3.new(24, 1, 360),
			CFrame.new(150, 0.05, -240), Color3.fromRGB(36, 39, 42), Enum.Material.Asphalt)
		for _, crossZ in { -150, -320 } do
			createPart(self.nightTown, "CrossStreet" .. tostring(-crossZ), Vector3.new(110, 1, 18),
				CFrame.new(81, 0.05, crossZ), Color3.fromRGB(38, 41, 43), Enum.Material.Asphalt)
		end
		createStreetlight(self.nightTown, Vector3.new(138, 0, -130))
		createStreetlight(self.nightTown, Vector3.new(162, 0, -200))
		createStreetlight(self.nightTown, Vector3.new(138, 0, -270))
		createStreetlight(self.nightTown, Vector3.new(162, 0, -340))
		table.insert(self.interactiveDoors, createBuilding(self.nightTown, "Diner", Vector3.new(190, 0, -140), Vector3.new(30, 14, 24), Color3.fromRGB(94, 76, 60), "MOONLIGHT DINER", math.pi / 2))
		table.insert(self.interactiveDoors, createBuilding(self.nightTown, "School", Vector3.new(194, 0, -320), Vector3.new(40, 18, 30), Color3.fromRGB(88, 82, 74), "HOLLOW CREEK SCHOOL", math.pi / 2))
		local rowhouseColors = {
			Color3.fromRGB(74, 68, 60),
			Color3.fromRGB(68, 64, 62),
			Color3.fromRGB(78, 70, 58),
		}
		for rowIndex = 1, 3 do
			table.insert(self.interactiveDoors, createBuilding(
				self.nightTown,
				"Rowhouse" .. tostring(rowIndex),
				Vector3.new(120, 0, -172 - rowIndex * 18),
				Vector3.new(16, 15, 14),
				rowhouseColors[rowIndex],
				"NO. " .. tostring(rowIndex * 2 + 1),
				-math.pi / 2
			))
		end
		-- Tall Pines Motel: a real room strip — four furnished rooms behind the
		-- street facade. Rooms 1/2/4 open on interactive doors; room 3 stays a
		-- plain part that _buildLockedRooms decorates (key-gated bonus room),
		-- so opening the door with the key now reveals an actual interior
		-- instead of the solid block that used to stand behind it.
		local motelWall = Color3.fromRGB(82, 72, 66)
		local motelTrim = Color3.fromRGB(70, 62, 56)
		-- Shell: floor, back wall, end walls, room dividers (block was solid)
		createPart(self.nightTown, "MotelFloor", Vector3.new(15.7, 0.5, 43.6),
			CFrame.new(195.85, 0.65, -220), Color3.fromRGB(96, 84, 68), Enum.Material.WoodPlanks)
		createPart(self.nightTown, "MotelBackWall", Vector3.new(0.6, 12, 44),
			CFrame.new(203.7, 6, -220), motelWall, Enum.Material.Concrete)
		createPart(self.nightTown, "MotelEndWallN", Vector3.new(16, 12, 0.6),
			CFrame.new(196, 6, -198.2), motelWall, Enum.Material.Concrete)
		createPart(self.nightTown, "MotelEndWallS", Vector3.new(16, 12, 0.6),
			CFrame.new(196, 6, -241.8), motelWall, Enum.Material.Concrete)
		for _, dividerZ in { -211, -220, -229 } do
			createPart(self.nightTown, "MotelDivider", Vector3.new(15.5, 12, 0.5),
				CFrame.new(195.85, 6, dividerZ), motelTrim, Enum.Material.Concrete)
		end
		createPart(self.nightTown, "MotelRoof", Vector3.new(18, 0.5, 46),
			CFrame.new(196, 12.3, -220), Color3.fromRGB(52, 48, 44), Enum.Material.CorrodedMetal)
		createPart(self.nightTown, "MotelWalk", Vector3.new(3, 0.4, 44),
			CFrame.new(186.5, 0.7, -220), Color3.fromRGB(70, 70, 66), Enum.Material.Concrete)
		-- Facade caps north of window 1 and south of doorway 4
		createPart(self.nightTown, "MotelFacadeN", Vector3.new(0.6, 12, 1.6),
			CFrame.new(188, 6, -199.3), motelWall, Enum.Material.Concrete)
		createPart(self.nightTown, "MotelFacadeS", Vector3.new(0.6, 12, 6.3),
			CFrame.new(188, 6, -238.35), motelWall, Enum.Material.Concrete)
		local blanketColors = {
			Color3.fromRGB(122, 62, 54),
			Color3.fromRGB(74, 96, 78),
			Color3.fromRGB(70, 78, 108),
			Color3.fromRGB(120, 104, 62),
		}
		for roomIndex = 1, 4 do
			local roomZ = -197.5 - roomIndex * 9
			local suffix = tostring(roomIndex)
			if roomIndex == 3 then
				-- Locked bonus room: plain part; _buildLockedRooms adds the
				-- Try Door prompt, hinge tween, and key handling by name.
				createPart(self.nightTown, "MotelDoor3",
					Vector3.new(0.4, 7, 3.2),
					CFrame.new(187.9, 3.6, roomZ),
					Color3.fromRGB(58, 84, 88), Enum.Material.Wood)
			else
				table.insert(self.interactiveDoors, createInteractiveDoor(
					self.nightTown,
					"MotelDoor" .. suffix,
					Vector3.new(3.2, 7, 0.4),
					CFrame.new(187.9, 3.6, roomZ) * CFrame.Angles(0, math.rad(90), 0),
					Color3.fromRGB(58, 84, 88),
					"Room " .. suffix
				))
			end
			-- Facade: strips between the doorway and window openings, plus the
			-- door header, window sill and window header
			createPart(self.nightTown, "MotelFacadeMidA" .. suffix, Vector3.new(0.6, 12, 1.1),
				CFrame.new(188, 6, roomZ + 2.25), motelWall, Enum.Material.Concrete)
			createPart(self.nightTown, "MotelFacadeMidB" .. suffix, Vector3.new(0.6, 12, 0.9),
				CFrame.new(188, 6, roomZ - 2.15), motelWall, Enum.Material.Concrete)
			createPart(self.nightTown, "MotelDoorHeader" .. suffix, Vector3.new(0.6, 4.9, 3.4),
				CFrame.new(188, 9.55, roomZ), motelWall, Enum.Material.Concrete)
			createPart(self.nightTown, "MotelWindowSill" .. suffix, Vector3.new(0.6, 3.9, 3.6),
				CFrame.new(188, 1.95, roomZ + 4.6), motelWall, Enum.Material.Concrete)
			createPart(self.nightTown, "MotelWindowHeader" .. suffix, Vector3.new(0.6, 5.1, 3.6),
				CFrame.new(188, 9.45, roomZ + 4.6), motelWall, Enum.Material.Concrete)
			local roomLamp = createPart(self.nightTown, "MotelRoomLamp" .. suffix,
				Vector3.new(0.3, 0.5, 0.5),
				CFrame.new(187.8, 7.8, roomZ),
				Color3.fromRGB(255, 211, 132), Enum.Material.Neon)
			roomLamp.CanCollide = false
			createPart(self.nightTown, "MotelWindow" .. suffix,
				Vector3.new(0.3, 3, 3.4),
				CFrame.new(187.9, 5.4, roomZ + 4.6),
				Color3.fromRGB(38, 44, 52), Enum.Material.Glass, 0.15)
			-- Room interior: bed against the back wall, nightstand with a
			-- bedside lamp, dresser under the window
			createPart(self.nightTown, "MotelBedFrame" .. suffix, Vector3.new(6.5, 1.2, 4.2),
				CFrame.new(199.8, 1.5, roomZ - 1.6), motelTrim, Enum.Material.Wood)
			createPart(self.nightTown, "MotelMattress" .. suffix, Vector3.new(6.1, 0.7, 3.8),
				CFrame.new(199.8, 2.45, roomZ - 1.6), Color3.fromRGB(198, 192, 180), Enum.Material.Fabric)
			local blanket = createPart(self.nightTown, "MotelBlanket" .. suffix, Vector3.new(3.4, 0.25, 3.9),
				CFrame.new(201.2, 2.85, roomZ - 1.6), blanketColors[roomIndex], Enum.Material.Fabric)
			blanket.CanCollide = false
			local pillow = createPart(self.nightTown, "MotelPillow" .. suffix, Vector3.new(1.2, 0.45, 2.4),
				CFrame.new(197.2, 2.95, roomZ - 1.6), Color3.fromRGB(226, 222, 212), Enum.Material.Fabric)
			pillow.CanCollide = false
			createPart(self.nightTown, "MotelNightstand" .. suffix, Vector3.new(1.6, 2.1, 1.6),
				CFrame.new(202.6, 1.95, roomZ + 1.6), motelTrim, Enum.Material.Wood)
			local bedsideLamp = createPart(self.nightTown, "MotelBedsideLamp" .. suffix,
				Vector3.new(0.6, 0.8, 0.6),
				CFrame.new(202.6, 3.4, roomZ + 1.6),
				Color3.fromRGB(255, 214, 150), Enum.Material.Neon)
			bedsideLamp.CanCollide = false
			local bedsideGlow = Instance.new("PointLight")
			bedsideGlow.Brightness = 0.7
			bedsideGlow.Range = 11
			bedsideGlow.Color = Color3.fromRGB(255, 214, 150)
			bedsideGlow.Parent = bedsideLamp
			createPart(self.nightTown, "MotelDresser" .. suffix, Vector3.new(1.4, 3, 3.6),
				CFrame.new(189.2, 2.4, roomZ + 4.6), motelTrim, Enum.Material.Wood)
		end
		-- Room 3 payoff: the key-gated room reads searched-through — someone
		-- was staying here and left in a hurry
		local room3Z = -224.5
		local suitcase = createPart(self.nightTown, "MotelSuitcase", Vector3.new(2.2, 0.7, 1.5),
			CFrame.new(193, 1.25, room3Z - 2.6) * CFrame.Angles(0, math.rad(24), 0),
			Color3.fromRGB(94, 74, 52), Enum.Material.Leather)
		createInspectPrompt(suitcase, "Rifled suitcase",
			"Clothes flung everywhere. Whoever packed this never came back for it.")
		local wallMap = createPart(self.nightTown, "MotelWallMap", Vector3.new(0.2, 2.6, 3.4),
			CFrame.new(203.3, 6.2, room3Z + 1),
			Color3.fromRGB(206, 194, 160), Enum.Material.SmoothPlastic)
		wallMap.CanCollide = false
		createInspectPrompt(wallMap, "Marked-up county map",
			"Pins circle the camp, the mines, and Cabin Zero. Red string ties them together.")
		for postIndex = 0, 4 do
			createPart(self.nightTown, "MotelPost" .. tostring(postIndex),
				Vector3.new(0.4, 11.6, 0.4),
				CFrame.new(186.2, 5.8, -200 - postIndex * 10),
				Color3.fromRGB(60, 56, 52), Enum.Material.Metal)
		end
		createPart(self.nightTown, "MotelSignPole", Vector3.new(0.5, 9, 0.5),
			CFrame.new(178, 4.5, -198), Color3.fromRGB(60, 56, 52), Enum.Material.Metal)
		local motelBoard = createPart(self.nightTown, "MotelSignBoard", Vector3.new(6, 3, 0.4),
			CFrame.new(178, 10, -198) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(30, 34, 40), Enum.Material.SmoothPlastic)
		createSign(motelBoard, "TALL PINES MOTEL", Color3.fromRGB(226, 190, 114))
		-- Fountain plaza between the gas station and the police station
		local plazaStone = Color3.fromRGB(96, 96, 90)
		createCylinder(self.nightTown, "PlazaFloor", Vector3.new(0.4, 40, 40),
			CFrame.new(55, 0.2, -255) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(78, 78, 74), Enum.Material.Cobblestone)
		createCylinder(self.nightTown, "FountainRing", Vector3.new(1.8, 14, 14),
			CFrame.new(55, 0.9, -255) * CFrame.Angles(0, 0, math.rad(90)),
			plazaStone, Enum.Material.Concrete)
		local fountainWater = createCylinder(self.nightTown, "FountainWater", Vector3.new(0.5, 11, 11),
			CFrame.new(55, 1.35, -255) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(46, 72, 84), Enum.Material.Glass)
		fountainWater.Transparency = 0.3
		fountainWater.CanCollide = false
		createCylinder(self.nightTown, "FountainPillar", Vector3.new(2.6, 1.2, 1.2),
			CFrame.new(55, 1.9, -255) * CFrame.Angles(0, 0, math.rad(90)),
			plazaStone, Enum.Material.Concrete)
		createCylinder(self.nightTown, "FountainBowl", Vector3.new(0.5, 5, 5),
			CFrame.new(55, 3.35, -255) * CFrame.Angles(0, 0, math.rad(90)),
			plazaStone, Enum.Material.Concrete)
		createPart(self.nightTown, "PlazaBenchA", Vector3.new(4.5, 0.4, 1.4),
			CFrame.new(43, 1.1, -244) * CFrame.Angles(0, math.rad(40), 0),
			Color3.fromRGB(58, 44, 30), Enum.Material.WoodPlanks)
		createPart(self.nightTown, "PlazaBenchB", Vector3.new(4.5, 0.4, 1.4),
			CFrame.new(67, 1.1, -266) * CFrame.Angles(0, math.rad(-140), 0),
			Color3.fromRGB(58, 44, 30), Enum.Material.WoodPlanks)
		-- Churchyard: fenced graveyard beside the abandoned church
		local graveStone = Color3.fromRGB(128, 126, 118)
		local fenceIron = Color3.fromRGB(56, 52, 48)
		for _, postSpot in {
			Vector3.new(-65, 0, -421), Vector3.new(-52, 0, -421), Vector3.new(-39, 0, -421),
			Vector3.new(-65, 0, -430), Vector3.new(-39, 0, -430),
			Vector3.new(-65, 0, -439), Vector3.new(-52, 0, -439), Vector3.new(-39, 0, -439),
		} do
			createPart(self.nightTown, "GraveFencePost", Vector3.new(0.35, 2.6, 0.35),
				CFrame.new(postSpot + Vector3.new(0, 1.3, 0)), fenceIron, Enum.Material.CorrodedMetal)
		end
		for _, railY in { 1.1, 1.9 } do
			createPart(self.nightTown, "GraveRailNorth", Vector3.new(26, 0.18, 0.18),
				CFrame.new(-52, railY, -421), fenceIron, Enum.Material.CorrodedMetal)
			createPart(self.nightTown, "GraveRailSouth", Vector3.new(26, 0.18, 0.18),
				CFrame.new(-52, railY, -439), fenceIron, Enum.Material.CorrodedMetal)
			createPart(self.nightTown, "GraveRailWest", Vector3.new(0.18, 0.18, 18),
				CFrame.new(-65, railY, -430), fenceIron, Enum.Material.CorrodedMetal)
		end
		local graveSpots = {
			{ x = -61, z = -426, tilt = 4 },
			{ x = -56, z = -424, tilt = -6 },
			{ x = -49, z = -427, tilt = 2 },
			{ x = -44, z = -424, tilt = -3 },
			{ x = -60, z = -434, tilt = 7 },
			{ x = -53, z = -436, tilt = -5 },
			{ x = -45, z = -434, tilt = 3 },
		}
		for graveIndex, grave in graveSpots do
			createPart(self.nightTown, "Gravestone" .. tostring(graveIndex),
				Vector3.new(1.6, 2.2, 0.4),
				CFrame.new(grave.x, 1.1, grave.z) * CFrame.Angles(0, 0, math.rad(grave.tilt)),
				graveStone, Enum.Material.Concrete)
		end
		createPart(self.nightTown, "GraveCrossV", Vector3.new(0.4, 2.6, 0.4),
			CFrame.new(-64, 1.3, -428), Color3.fromRGB(88, 70, 52), Enum.Material.Wood)
		createPart(self.nightTown, "GraveCrossH", Vector3.new(1.4, 0.4, 0.4),
			CFrame.new(-64, 1.9, -428), Color3.fromRGB(88, 70, 52), Enum.Material.Wood)
		-- Alley clutter and outskirts trees for the new blocks
		createCylinder(self.nightTown, "AlleyBarrel", Vector3.new(2.4, 2.2, 2.2),
			CFrame.new(-92, 1.2, -158) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(68, 48, 32), Enum.Material.WoodPlanks)
		createPart(self.nightTown, "AlleyCrateA", Vector3.new(2.2, 2.2, 2.2),
			CFrame.new(-89, 1.1, -161), Color3.fromRGB(82, 65, 44), Enum.Material.WoodPlanks)
		createPart(self.nightTown, "AlleyCrateB", Vector3.new(1.7, 1.7, 1.7),
			CFrame.new(-91, 1.0, -163), Color3.fromRGB(75, 60, 40), Enum.Material.WoodPlanks)
		createPart(self.nightTown, "PoliceCrate", Vector3.new(2.2, 2.2, 2.2),
			CFrame.new(108, 1.1, -368), Color3.fromRGB(82, 65, 44), Enum.Material.WoodPlanks)
		createBareTree(self.nightTown, Vector3.new(170, 0, -175), 16)
		createBareTree(self.nightTown, Vector3.new(215, 0, -260), 18)
		createBareTree(self.nightTown, Vector3.new(176, 0, -368), 15)
		-- Dead/bare trees scattered around the outskirts for atmosphere
		local bareTreePositions = {
			Vector3.new(-135, 0, -150), Vector3.new(-140, 0, -340),
			Vector3.new(-130, 0, -408), Vector3.new(130, 0, -265),
			Vector3.new(130, 0, -380), Vector3.new(-22, 0, -415),
			Vector3.new(48, 0, -95),   Vector3.new(-48, 0, -95),
		}
		for idx, treePos in bareTreePositions do
			createBareTree(self.nightTown, treePos, 14 + (idx % 3) * 3)
		end
		-- Scatter props: barrels + crates in front of General Store (reference: porch/ground clutter)
		local barrelColor = Color3.fromRGB(68, 48, 32)
		for b = 1, 3 do
			createCylinder(self.nightTown, "Barrel" .. tostring(b),
				Vector3.new(2.2, 2.4, 2.4),
				CFrame.new(-58 + (b - 1) * 2.8, 1.2, -174) * CFrame.Angles(0, 0, math.rad(90)),
				barrelColor, Enum.Material.WoodPlanks)
			-- Metal band rings on each barrel
			createCylinder(self.nightTown, "BarrelRing" .. tostring(b) .. "T",
				Vector3.new(2.25, 0.25, 0.25),
				CFrame.new(-58 + (b - 1) * 2.8, 0.6, -174) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(52, 46, 40), Enum.Material.CorrodedMetal)
			createCylinder(self.nightTown, "BarrelRing" .. tostring(b) .. "B",
				Vector3.new(2.25, 0.25, 0.25),
				CFrame.new(-58 + (b - 1) * 2.8, 1.8, -174) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(52, 46, 40), Enum.Material.CorrodedMetal)
		end
		-- Wooden crates stacked near Gas Station (reference: roadside debris)
		local crateColor = Color3.fromRGB(82, 65, 44)
		createPart(self.nightTown, "CrateBase",  Vector3.new(2.4, 2.4, 2.4), CFrame.new(60, 1.2, -175), crateColor, Enum.Material.WoodPlanks)
		createPart(self.nightTown, "CrateTop",   Vector3.new(2.0, 2.0, 2.0), CFrame.new(60, 3.6, -175), crateColor:Lerp(Color3.fromRGB(0,0,0), 0.12), Enum.Material.WoodPlanks)
		createPart(self.nightTown, "CrateSmall", Vector3.new(1.6, 1.6, 1.6), CFrame.new(62.8, 0.8, -177), crateColor, Enum.Material.WoodPlanks)
		-- Wagon wheel lying flat on the road edge (reference old town 2 shows wheel debris)
		local wheelColor = Color3.fromRGB(52, 38, 24)
		for spoke = 1, 6 do
			local spokeAngle = math.rad(spoke * 30)
			createPart(self.nightTown, "WheelSpoke" .. tostring(spoke),
				Vector3.new(0.18, 3.6, 0.18),
				CFrame.new(-52, 0.18, -220) * CFrame.Angles(0, spokeAngle, 0),
				wheelColor, Enum.Material.Wood)
		end
		createCylinder(self.nightTown, "WheelRim",
			Vector3.new(0.22, 8.2, 8.2),
			CFrame.new(-52, 0.18, -220) * CFrame.Angles(0, 0, math.rad(90)),
			wheelColor, Enum.Material.Wood)
		-- Utility poles along the right side of the main road (prominent in both old-town references)
		for p = 1, 5 do
			createUtilityPole(self.nightTown, Vector3.new(32, 0, -118 - (p - 1) * 58))
		end
		-- Rusted metal fence along the left sidewalk edge of main road
		for section = 0, 9 do
			createPart(self.nightTown, "FencePost",
				Vector3.new(0.35, 3.2, 0.35),
				CFrame.new(-36, 1.6, -78 - section * 34),
				Color3.fromRGB(64, 58, 52), Enum.Material.CorrodedMetal)
			if section < 9 then
				createPart(self.nightTown, "FenceRail",
					Vector3.new(0.2, 0.2, 33.5),
					CFrame.new(-36, 2.8, -95 - section * 34),
					Color3.fromRGB(60, 54, 48), Enum.Material.CorrodedMetal)
			end
		end
		-- Ground rubble and fallen plaster chunks scattered along the road
		-- Matches Old Town 1 reference: irregular concrete debris on the ground
		local rubbleData = {
			{ -12, -118, 2.8, 1.1, 2.2, 0.55 },
			{  10, -148, 1.8, 0.8, 1.6, 1.20 },
			{ -22, -170, 3.4, 1.3, 2.6, 0.30 },
			{  18, -210, 2.2, 0.9, 2.0, 2.10 },
			{ -10, -240, 1.6, 0.7, 1.4, 0.80 },
			{ -26, -265, 3.0, 1.2, 2.4, 1.60 },
			{  12, -310, 2.4, 1.0, 2.2, 0.40 },
			{ -16, -345, 1.8, 0.8, 1.6, 2.50 },
			{  22, -368, 2.6, 1.1, 2.0, 1.00 },
			{  -8, -395, 2.0, 0.9, 1.8, 1.80 },
		}
		local rubbleC = Color3.fromRGB(148, 142, 134)
		for i, rd in ipairs(rubbleData) do
			local chunk = createPart(self.nightTown, "Rubble" .. i,
				Vector3.new(rd[3], rd[4], rd[5]),
				CFrame.new(rd[1], rd[4] / 2, rd[2]) * CFrame.Angles(0.14, rd[6], 0.10),
				rubbleC, Enum.Material.Concrete)
			chunk.CanCollide = false
		end
		-- Dried scrub-brush clumps scattered around town (Old Town 4 aerial reference shows pervasive scrub)
		local scrubColor = Color3.fromRGB(56, 64, 36)
		local scrubPositions = {
			{-55, -112}, {-68, -158}, {-56, -200}, {-72, -245}, {-60, -292},
			{ 58, -128}, { 66, -172}, { 54, -218}, { 70, -260}, { 60, -308},
			{-38, -245}, { 38, -248}, {-22, -308}, { 30, -355},
			{-46, -422}, { 42, -428}, { 18, -440},
		}
		for i, pos in ipairs(scrubPositions) do
			local sz = 1.3 + (i % 3) * 0.55
			local scrub = createPart(self.nightTown, "Scrub" .. i,
				Vector3.new(sz * 1.1, sz * 0.72, sz * 0.95),
				CFrame.new(pos[1], sz * 0.36, pos[2]),
				scrubColor, Enum.Material.Grass)
			scrub.Shape = Enum.PartType.Ball
			scrub.CanCollide = false
		end
		-- Weed bands hugging both road edges (Old Town 1/2 reference: vegetation
		-- reclaiming the street). Deterministic jitter keeps the layout stable.
		local weedColors = {
			Color3.fromRGB(56, 64, 36),
			Color3.fromRGB(96, 92, 48),
			Color3.fromRGB(74, 78, 40),
		}
		local weedIndex = 0
		for _, edgeX in { -17, 17 } do
			for z = -100, -440, -13 do
				weedIndex += 1
				local jitterX = (((weedIndex * 37) % 11) - 5) * 0.6
				local jitterZ = ((weedIndex * 53) % 7) - 3
				local wSz = 0.8 + ((weedIndex * 29) % 10) * 0.14
				local weed = createPart(self.nightTown, "RoadWeed" .. weedIndex,
					Vector3.new(wSz * 1.15, wSz * 0.6, wSz),
					CFrame.new(edgeX + jitterX, wSz * 0.3, z + jitterZ),
					weedColors[(weedIndex % #weedColors) + 1], Enum.Material.Grass)
				weed.Shape = Enum.PartType.Ball
				weed.CanCollide = false
			end
		end
		-- Golden autumn bushes: bright yellow shrubs against bare trees (Old Town 3 reference)
		local goldenBushData = {
			{ -78, -168, 2.8 }, { 80, -225, 3.2 }, { -82, -310, 2.5 }, { 78, -375, 3.0 },
		}
		for i, gb in ipairs(goldenBushData) do
			local gBush = createPart(self.nightTown, "GoldenBush" .. i,
				Vector3.new(gb[3] * 1.15, gb[3] * 0.88, gb[3]),
				CFrame.new(gb[1], gb[3] * 0.44, gb[2]),
				Color3.fromRGB(198, 165, 32), Enum.Material.Grass)
			gBush.Shape = Enum.PartType.Ball
			gBush.CanCollide = false
		end
		-- Road puddles: flat dark reflective patches on the dirt road (Old Town 3 reference)
		local puddleData = {
			{ 6, -138, 3.2, 2.4 }, { -4, -195, 4.0, 2.8 }, { 8, -268, 2.8, 2.0 }, { -6, -342, 3.5, 2.5 },
		}
		for i, pd in ipairs(puddleData) do
			local puddle = createPart(self.nightTown, "Puddle" .. i,
				Vector3.new(pd[3], 0.07, pd[4]),
				CFrame.new(pd[1], 0.04, pd[2]),
				Color3.fromRGB(22, 28, 38), Enum.Material.SmoothPlastic)
			puddle.Shape = Enum.PartType.Ball
			puddle.Transparency = 0.25
			puddle.CanCollide = false
		end
		-- Autumn leaf drifts on the road and curbs (Old Town 2 reference: fallen leaves cover the ground)
		local leafData = {
			{ 4, -122, 0.22, Color3.fromRGB(118, 72, 22) },
			{ -18, -145, 0.18, Color3.fromRGB(138, 88, 18) },
			{ 28, -168, 0.24, Color3.fromRGB(105, 60, 15) },
			{ -8, -195, 0.20, Color3.fromRGB(120, 75, 20) },
			{ 20, -225, 0.22, Color3.fromRGB(110, 65, 18) },
			{ -30, -252, 0.18, Color3.fromRGB(130, 82, 16) },
			{ 14, -278, 0.20, Color3.fromRGB(100, 58, 14) },
			{ -4, -315, 0.22, Color3.fromRGB(115, 70, 20) },
			{ 32, -342, 0.18, Color3.fromRGB(108, 64, 16) },
			{ -22, -385, 0.20, Color3.fromRGB(122, 76, 18) },
		}
		for i, ld in ipairs(leafData) do
			local leafSz = 2.2 + (i % 3) * 0.8
			local leaf = createPart(self.nightTown, "LeafDrift" .. i,
				Vector3.new(leafSz, ld[3], leafSz * 0.85),
				CFrame.new(ld[1], ld[3] / 2, ld[2]) * CFrame.Angles(0, i * 0.7, 0),
				ld[4], Enum.Material.Grass)
			leaf.Shape = Enum.PartType.Ball
			leaf.CanCollide = false
		end
	end

	for _, definition in SEARCH_TARGETS do
		local socket = createPart(
			self.nightTown,
			definition.id,
			Vector3.new(6, 4, 6),
			CFrame.new(definition.position),
			definition.color,
			Enum.Material.WoodPlanks
		)
		socket:SetAttribute("EvidenceSocket", true)
		socket:SetAttribute("EvidenceAlias", definition.id)
		socket.Transparency = 1
		socket.CanCollide = false
		table.insert(self.evidenceSockets, socket)
	end

	self:_buildSideObjectives()
	-- Deduction-depth props live in the night town regardless of whether the
	-- surrounding buildings are authored or procedural.
	self:_buildColdCaseCabinet()
	self:_buildLockedRooms()
	self:_buildExpansions()
	self:_trimSmallPartShadows()
end

-- One post-build pass: small dressing parts (weeds, corn blades, road
-- stripes, balusters, pebbles — a few thousand across both districts) each
-- get drawn into the shadow atlas despite casting shadows nobody can see.
-- Turning CastShadow off for sub-1.5-stud-volume parts is a pure GPU win,
-- which matters most on the phones this game needs to feel smooth on.
function ProductionMapService:_trimSmallPartShadows()
	local trimmed = 0
	for _, descendant in self.mapFolder:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.CastShadow then
			local size = descendant.Size
			if size.X * size.Y * size.Z < 1.5 then
				descendant.CastShadow = false
				trimmed += 1
			end
		end
	end
	if trimmed > 0 then
		print(string.format("[CAMP-Mystery] Shadow trim: %d small parts", trimmed))
	end
end

-- World-expansion district builders live under Services/Map and are loaded
-- optionally so the map service works before/without any given pack.
-- PolishPack runs last: it decorates structures the other packs build.
local EXPANSION_MODULE_NAMES =
	{ "TownExpansion", "CampExpansion", "LakeAndWilds", "Landmarks", "Backcountry", "HighFrontier", "PolishPack" }

local function optionalMapModule(name: string): any
	local servicesFolder = script.Parent
	local mapModules = if servicesFolder then servicesFolder:FindFirstChild("Map") else nil
	local child = if mapModules then mapModules:FindFirstChild(name) else nil
	if not child or not child:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, child)
	if ok then
		return result
	end
	warn("[CAMP-Mystery] Map module failed to load: " .. name .. " - " .. tostring(result))
	return nil
end

function ProductionMapService:_buildExpansions()
	for _, moduleName in EXPANSION_MODULE_NAMES do
		local moduleValue = optionalMapModule(moduleName)
		if moduleValue and typeof(moduleValue.Build) == "function" then
			local ok, failure = pcall(moduleValue.Build, self.dayCamp, self.nightTown)
			if not ok then
				warn("[CAMP-Mystery] " .. moduleName .. ".Build failed: " .. tostring(failure))
			end
		end
	end
	local seasonal = optionalMapModule("SeasonalDressing")
	if seasonal and typeof(seasonal.Build) == "function" then
		local ok, failure = pcall(seasonal.Build, self.dayCamp)
		if not ok then
			warn("[CAMP-Mystery] SeasonalDressing.Build failed: " .. tostring(failure))
		end
	end
	local wilds = optionalMapModule("LakeAndWilds")
	if wilds and typeof(wilds.Start) == "function" then
		task.spawn(function()
			local ok, failure = pcall(wilds.Start)
			if not ok then
				warn("[CAMP-Mystery] LakeAndWilds.Start failed: " .. tostring(failure))
			end
		end)
	end
	local ambience = optionalMapModule("WorldAmbience")
	if ambience and typeof(ambience.Start) == "function" then
		task.spawn(function()
			local ok, failure = pcall(ambience.Start)
			if not ok then
				warn("[CAMP-Mystery] WorldAmbience.Start failed: " .. tostring(failure))
			end
		end)
	end
end

-- Optional night-side objectives: hand-built props whose prompts stay dark
-- until the Investigation phase enables them. Their triggers route through
-- onSideObjective so the runtime owns validation and rewards.
function ProductionMapService:_registerSideObjective(
	sideObjectiveId: string,
	part: BasePart,
	actionText: string,
	objectText: string,
	holdDuration: number
)
	local prompt = createPrompt(part, actionText, objectText, holdDuration)
	prompt.Enabled = false
	part:SetAttribute("SideObjective", sideObjectiveId)
	self.sideObjectivePrompts[sideObjectiveId] = prompt
	self.sideObjectiveParts[sideObjectiveId] = part
	prompt.Triggered:Connect(function(player: Player)
		if self.sideObjectiveComplete[sideObjectiveId] then
			return
		end
		local handler = self.onSideObjective
		if handler and handler(player, sideObjectiveId) then
			self:_markSideObjectiveComplete(sideObjectiveId)
		end
	end)
end

function ProductionMapService:_buildSideObjectives()
	-- Radio relay console on the water tower platform (tower base 110, 0, -292;
	-- deck top sits just under Y 20). Reaching it means climbing the ladder.
	local console = createPart(
		self.nightTown,
		"RadioBeaconConsole",
		Vector3.new(2.4, 2.6, 1.6),
		CFrame.new(Vector3.new(105, 21.1, -287)),
		Color3.fromRGB(58, 66, 72),
		Enum.Material.Metal
	)
	createPart(
		self.nightTown,
		"RadioBeaconAntenna",
		Vector3.new(0.3, 7, 0.3),
		CFrame.new(Vector3.new(105, 25.9, -287.4)),
		Color3.fromRGB(40, 46, 50),
		Enum.Material.Metal
	)
	local consoleLamp = createPart(
		self.nightTown,
		"StatusLamp",
		Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(Vector3.new(105, 22.6, -286.5)),
		SIDE_OBJECTIVE_LAMP_OFF,
		Enum.Material.Neon
	)
	consoleLamp.CanCollide = false
	consoleLamp.Parent = console
	self:_registerSideObjective(
		"radio-beacon",
		console,
		"Boost the signal",
		"Camp radio relay",
		5
	)

	-- Fuse box on the east wall of Mill No. 7 (factory footprint reaches
	-- x -77.5), facing the unlit industrial pocket it can relight.
	local fuseBox = createPart(
		self.nightTown,
		"MillFuseBox",
		Vector3.new(0.9, 3, 2.2),
		CFrame.new(Vector3.new(-77, 4.5, -266)),
		Color3.fromRGB(70, 74, 70),
		Enum.Material.DiamondPlate
	)
	createPart(
		self.nightTown,
		"MillFuseConduit",
		Vector3.new(0.45, 3.2, 0.45),
		CFrame.new(Vector3.new(-77.2, 1.6, -266)),
		Color3.fromRGB(48, 52, 50),
		Enum.Material.Metal
	)
	local fuseLamp = createPart(
		self.nightTown,
		"StatusLamp",
		Vector3.new(0.45, 0.45, 0.45),
		CFrame.new(Vector3.new(-76.4, 6.2, -266)),
		SIDE_OBJECTIVE_LAMP_OFF,
		Enum.Material.Neon
	)
	fuseLamp.CanCollide = false
	fuseLamp.Parent = fuseBox
	self:_registerSideObjective(
		"fuse-box",
		fuseBox,
		"Restore power",
		"Mill No. 7 fuse box",
		4
	)
end

function ProductionMapService:_setSideObjectiveLamp(sideObjectiveId: string, complete: boolean)
	local part = self.sideObjectiveParts[sideObjectiveId]
	local lamp = if part then part:FindFirstChild("StatusLamp") else nil
	if lamp and lamp:IsA("BasePart") then
		lamp.Color = if complete then SIDE_OBJECTIVE_LAMP_ON else SIDE_OBJECTIVE_LAMP_OFF
	end
end

-- Relights (or re-darkens) every dead lantern within reach of the fuse box.
-- The Visible* attribute cache must be updated alongside the live properties
-- so the next day/night visibility sweep keeps the repaired state.
function ProductionMapService:_setFactoryStreetlights(repaired: boolean)
	local fusePart = self.sideObjectiveParts["fuse-box"]
	if not fusePart then
		return
	end
	for _, descendant in self.nightTown:GetDescendants() do
		if
			descendant:IsA("BasePart")
			and descendant:GetAttribute("DarkLantern") == true
			and (descendant.Position - fusePart.Position).Magnitude
				<= FUSE_BOX_RELIGHT_RADIUS
		then
			descendant.Color = if repaired then LANTERN_LIT_COLOR else LANTERN_DARK_COLOR
			local transparency = if repaired
				then LANTERN_LIT_TRANSPARENCY
				else LANTERN_DARK_TRANSPARENCY
			descendant.Transparency = transparency
			descendant:SetAttribute("VisibleTransparency", transparency)
			local light = descendant:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = repaired
				light:SetAttribute("VisibleEnabled", repaired)
			end
		end
	end
end

function ProductionMapService:_markSideObjectiveComplete(sideObjectiveId: string)
	self.sideObjectiveComplete[sideObjectiveId] = true
	local prompt = self.sideObjectivePrompts[sideObjectiveId]
	if prompt then
		prompt.Enabled = false
	end
	self:_setSideObjectiveLamp(sideObjectiveId, true)
	if sideObjectiveId == "fuse-box" then
		self:_setFactoryStreetlights(true)
	end
end

function ProductionMapService:SetSideObjectivePromptsEnabled(enabled: boolean)
	for sideObjectiveId, prompt in self.sideObjectivePrompts do
		prompt.Enabled = enabled and not self.sideObjectiveComplete[sideObjectiveId]
	end
end

function ProductionMapService:GetSideObjectivePosition(sideObjectiveId: string): Vector3?
	local part = self.sideObjectiveParts[sideObjectiveId]
	return if part then part.Position else nil
end

function ProductionMapService:ResetSideObjectives()
	self.sideObjectiveComplete = {}
	for sideObjectiveId, prompt in self.sideObjectivePrompts do
		prompt.Enabled = false
		self:_setSideObjectiveLamp(sideObjectiveId, false)
	end
	self:_setFactoryStreetlights(false)
end

-- Filing cabinet inside the police station holding three seeded cold-case
-- files. File text comes from the runtime via SetColdCaseHandler so summaries
-- can change every round.
function ProductionMapService:_buildColdCaseCabinet()
	local cabinetColor = Color3.fromRGB(74, 82, 88)
	local drawerColor = Color3.fromRGB(60, 68, 74)
	-- Police station interior: building at (92, 0, -360), rotated +90 deg, so
	-- the interior back wall sits near world X = 110. The cabinet stands
	-- against it, drawers facing into the room (-X).
	local body = createPart(
		self.nightTown,
		"ColdCaseCabinet",
		Vector3.new(1.8, 5.6, 3.2),
		CFrame.new(109.2, 2.8, -346),
		cabinetColor,
		Enum.Material.Metal
	)
	local signPlate = createPart(
		self.nightTown,
		"ColdCaseSign",
		Vector3.new(2.8, 1, 0.25),
		CFrame.new(108.1, 6, -346) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(30, 34, 40),
		Enum.Material.SmoothPlastic
	)
	createSign(signPlate, "COLD CASES", Color3.fromRGB(226, 190, 114))
	local showFeedback = createFeedbackBillboard(body, 340)
	for fileIndex = 1, 3 do
		local drawer = createPart(
			self.nightTown,
			"ColdCaseFile" .. tostring(fileIndex),
			Vector3.new(0.3, 1.5, 2.6),
			CFrame.new(108.15, 0.6 + fileIndex * 1.7, -346),
			drawerColor,
			Enum.Material.Metal
		)
		createPart(
			self.nightTown,
			"ColdCaseHandle" .. tostring(fileIndex),
			Vector3.new(0.15, 0.2, 1),
			CFrame.new(107.95, 0.6 + fileIndex * 1.7, -346),
			Color3.fromRGB(198, 165, 32),
			Enum.Material.Metal
		).CanCollide = false
		local prompt = createPrompt(
			drawer,
			"Open File",
			"Cold case file " .. tostring(fileIndex),
			0.45
		)
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(player: Player)
			local handler = self.coldCaseHandler
			if not handler then
				return
			end
			local summary = handler(player, fileIndex)
			if summary then
				showFeedback(summary, 8)
			end
		end)
	end
end

local LOCKED_ROOM_DEFINITIONS: {
	{
		roomId: string,
		objectText: string,
		existingDoorName: string?,
		fallbackCFrame: CFrame,
		fallbackSize: Vector3,
		color: Color3,
	}
} = {
	{
		roomId = "motel-room-3",
		objectText = "Motel Room 3",
		-- The procedural motel strip names its doors MotelDoor1..4; an
		-- authored town using the same names is picked up automatically.
		existingDoorName = "MotelDoor3",
		fallbackCFrame = CFrame.new(187.9, 3.6, -224.5),
		fallbackSize = Vector3.new(0.4, 7, 3.2),
		color = Color3.fromRGB(58, 84, 88),
	},
	{
		roomId = "police-evidence-room",
		objectText = "Police Evidence Room",
		existingDoorName = nil,
		-- Against the police station's interior back wall, facing the room.
		fallbackCFrame = CFrame.new(109.55, 3.9, -370),
		fallbackSize = Vector3.new(0.5, 7.4, 4.6),
		color = Color3.fromRGB(52, 60, 68),
	},
}

-- Two night interiors are locked behind day-camp keys: motel room 3 and the
-- police evidence room. Prompts always show; the runtime handler decides
-- whether the player carries the matching key.
function ProductionMapService:_buildLockedRooms()
	for _, definition in LOCKED_ROOM_DEFINITIONS do
		local door: BasePart? = nil
		local existingName = definition.existingDoorName
		if existingName then
			local found = self.nightTown:FindFirstChild(existingName, true)
			if found and found:IsA("BasePart") then
				door = found
			end
		end
		if not door then
			door = createPart(
				self.nightTown,
				"LockedDoor_" .. definition.roomId,
				definition.fallbackSize,
				definition.fallbackCFrame,
				definition.color,
				Enum.Material.Wood
			)
		end
		local lockedDoor = door :: BasePart
		lockedDoor:SetAttribute("WorldInteraction", "LockedDoor")
		local prompt = createPrompt(lockedDoor, "Try Door", definition.objectText, 0.4)
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		local closedCFrame = lockedDoor.CFrame
		local hinge = CFrame.new(0, 0, -lockedDoor.Size.Z / 2)
		local openCFrame = closedCFrame
			* hinge
			* CFrame.Angles(0, math.rad(-104), 0)
			* hinge:Inverse()
		local room: LockedRoom = {
			roomId = definition.roomId,
			door = lockedDoor,
			prompt = prompt,
			closedCFrame = closedCFrame,
			openCFrame = openCFrame,
			isOpen = false,
			showFeedback = createFeedbackBillboard(lockedDoor),
		}
		self.lockedRooms[definition.roomId] = room
		prompt.Triggered:Connect(function(player: Player)
			if room.isOpen then
				return
			end
			local handler = self.lockedRoomHandler
			if not handler then
				return
			end
			local opened, message = handler(player, room.roomId)
			if opened then
				room.isOpen = true
				prompt.Enabled = false
				room.door.CanCollide = false
				TweenService:Create(
					room.door,
					DOOR_TWEEN,
					{ CFrame = room.openCFrame }
				):Play()
			end
			if message then
				room.showFeedback(message, 5)
			end
		end)
	end
end

function ProductionMapService:SetColdCaseHandler(handler: ColdCaseHandler?)
	self.coldCaseHandler = handler
end

function ProductionMapService:SetKeyPickupHandler(handler: KeyPickupHandler?)
	self.keyPickupHandler = handler
end

function ProductionMapService:SetLockedRoomHandler(handler: LockedRoomHandler?)
	self.lockedRoomHandler = handler
end

function ProductionMapService:SetSupplyCacheHandler(handler: SupplyCacheHandler?)
	self.supplyCacheHandler = handler
end

-- Day-only key pickups at seeded hiding spots. The runtime spawns these when
-- Day begins and clears them at dusk; picked-up keys never respawn.
function ProductionMapService:SpawnDayKeys(spots: { KeySpot })
	self:ClearDayKeys()
	local folder = Instance.new("Folder")
	folder.Name = "DayKeys"
	folder.Parent = self.dayCamp
	self.dayKeysFolder = folder
	for _, spot in spots do
		local key = createPart(
			folder,
			"HiddenKey_" .. spot.keyId,
			Vector3.new(1.1, 0.28, 0.5),
			CFrame.new(spot.position),
			Color3.fromRGB(214, 178, 84),
			Enum.Material.Metal
		)
		key.CanCollide = false
		local prompt = createPrompt(key, "Take Key", spot.objectText, 0.5)
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 8
		prompt.Triggered:Connect(function(player: Player)
			local handler = self.keyPickupHandler
			if not handler or key.Parent == nil then
				return
			end
			if handler(player, spot.keyId) then
				-- Leave a short confirmation floating where the key was.
				local marker = createPart(
					folder,
					"KeyTakenMarker",
					Vector3.new(0.2, 0.2, 0.2),
					CFrame.new(spot.position),
					Color3.fromRGB(214, 178, 84),
					Enum.Material.Metal,
					1
				)
				marker.CanCollide = false
				marker.CanQuery = false
				local showFeedback = createFeedbackBillboard(marker)
				showFeedback(spot.pickupLine, 4)
				task.delay(4.5, function()
					if marker.Parent then
						marker:Destroy()
					end
				end)
				key:Destroy()
			end
		end)
	end
end

function ProductionMapService:ClearDayKeys()
	local folder = self.dayKeysFolder
	if folder then
		folder:Destroy()
		self.dayKeysFolder = nil
	end
end

-- One seeded crate in the outskirts opens with a 3-second pry and rewards the
-- finder through the runtime handler.
function ProductionMapService:SpawnSupplyCache(position: Vector3)
	self:ClearSupplyCache()
	local crate = createPart(
		self.nightTown,
		"SupplyCache",
		Vector3.new(3, 2.6, 3),
		CFrame.new(position),
		Color3.fromRGB(96, 74, 44),
		Enum.Material.WoodPlanks
	)
	local seam = createPart(
		crate,
		"SupplyCacheSeam",
		Vector3.new(3.05, 0.2, 3.05),
		CFrame.new(position + Vector3.new(0, 0.7, 0)),
		Color3.fromRGB(226, 190, 114),
		Enum.Material.Neon
	)
	seam.CanCollide = false
	local prompt = createPrompt(crate, "Pry Open", "Weathered supply cache", 3)
	prompt.RequiresLineOfSight = false
	local showFeedback = createFeedbackBillboard(crate)
	prompt.Triggered:Connect(function(player: Player)
		local handler = self.supplyCacheHandler
		if not handler then
			return
		end
		local opened, message = handler(player)
		if opened then
			prompt.Enabled = false
			seam.Material = Enum.Material.Wood
			seam.Color = Color3.fromRGB(60, 46, 28)
			crate.Color = Color3.fromRGB(70, 54, 32)
		end
		if message then
			showFeedback(message, 5)
		end
	end)
	self.supplyCache = crate
end

function ProductionMapService:ClearSupplyCache()
	local crate = self.supplyCache
	if crate then
		crate:Destroy()
		self.supplyCache = nil
	end
end

function ProductionMapService:ResetLockedRooms()
	for _, room in self.lockedRooms do
		room.isOpen = false
		room.door.CFrame = room.closedCFrame
		room.door.CanCollide = true
		room.prompt.Enabled = true
		room.prompt.ActionText = "Try Door"
	end
end

function ProductionMapService:GetEvidenceAliases(): { string }
	local aliases: { string } = {}
	for _, socket in self.evidenceSockets do
		table.insert(aliases, socket.Name)
	end
	return aliases
end

export type NightOptions = {
	generatorPowered: boolean?,
	firewoodStocked: boolean?,
	-- Seeded round weather (WeatherConfig.WeatherId); nil keeps Clear.
	weather: string?,
	weatherSeed: number?,
}

-- One thin invisible sheet high above camp and town; rain particles fall from
-- random points across it, so a single modest emitter covers the play area.
function ProductionMapService:_ensureRainPart(): BasePart
	local existing = self.rainPart
	if existing and existing.Parent then
		return existing
	end
	local sheet = createPart(
		self.mapFolder,
		"WeatherRainEmitter",
		-- Covers the fourth-expansion slab (x -550..250, z -148..472) plus the
		-- town band to the south (z to -445).
		Vector3.new(820, 1, 930),
		CFrame.new(-150, 92, 10),
		Color3.fromRGB(160, 176, 192),
		Enum.Material.SmoothPlastic,
		1
	)
	sheet.CanCollide = false
	sheet.CanTouch = false
	sheet.CanQuery = false
	local drops = Instance.new("ParticleEmitter")
	drops.Name = "RainDrops"
	drops.Enabled = false
	drops.Rate = 0
	drops.Lifetime = NumberRange.new(1.1, 1.5)
	drops.Speed = NumberRange.new(52, 70)
	drops.EmissionDirection = Enum.NormalId.Bottom
	drops.Acceleration = Vector3.new(0, -38, 0)
	drops.Color = ColorSequence.new(Color3.fromRGB(188, 205, 224))
	drops.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0.14),
	})
	drops.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0.75),
	})
	drops.Parent = sheet
	self.rainPart = sheet
	return sheet
end

function ProductionMapService:_applyRainForWeather(
	weather: WeatherConfig.WeatherDefinition
)
	local sheet = self:_ensureRainPart()
	local drops = sheet:FindFirstChild("RainDrops")
	if drops and drops:IsA("ParticleEmitter") then
		drops.Enabled = weather.rainEnabled
		drops.Rate = if weather.rainEnabled then weather.rainRate else 0
	end
end

function ProductionMapService:_stopLightning()
	self.stormToken += 1
end

-- Seeded storm lightning: brief Brightness/ambient spikes at night, with an
-- optional thunder one-shot from the WeatherThunderAssetId SoundService
-- attribute (mirrors the MonsterAttack<Id>AssetId sting slot).
function ProductionMapService:_startLightning(
	weather: WeatherConfig.WeatherDefinition
)
	self.stormToken += 1
	local token = self.stormToken
	local rng = Random.new(self.weatherSeed + 1)
	task.spawn(function()
		while self.stormToken == token do
			task.wait(rng:NextNumber(
				math.max(weather.lightningMinSeconds, 4),
				math.max(weather.lightningMaxSeconds, 6)
			))
			if self.stormToken ~= token then
				break
			end
			local previousBrightness = Lighting.Brightness
			local previousOutdoor = Lighting.OutdoorAmbient
			for flash = 1, 2 do
				Lighting.Brightness = previousBrightness + 1.6
				Lighting.OutdoorAmbient = Color3.fromRGB(148, 158, 182)
				task.wait(if flash == 1 then 0.07 else 0.12)
				Lighting.Brightness = previousBrightness
				Lighting.OutdoorAmbient = previousOutdoor
				task.wait(0.06)
			end
			local thunderAssetId = SoundService:GetAttribute("WeatherThunderAssetId")
			local thunderSoundId = if type(thunderAssetId) == "number" and thunderAssetId > 0
				then "rbxassetid://" .. tostring(thunderAssetId)
				elseif type(thunderAssetId) == "string" and thunderAssetId ~= "" then thunderAssetId
				-- Thunder And Rain 1 (Pro Sound Effects, free Creator Store,
				-- verified loading in-boot 2026-08-09). Storm rounds were
				-- flashing lightning in total silence before this default.
				else "rbxassetid://9120015808"
			local emitter = self.rainPart
			if thunderSoundId ~= "" and emitter then
				local rumble = Instance.new("Sound")
				rumble.Name = "WeatherThunder"
				rumble.SoundId = thunderSoundId
				rumble.Volume = 0.8
				rumble.RollOffMode = Enum.RollOffMode.InverseTapered
				rumble.RollOffMinDistance = 60
				rumble.RollOffMaxDistance = 900
				rumble.Parent = emitter
				rumble.Ended:Once(function()
					rumble:Destroy()
				end)
				rumble:Play()
			end
		end
	end)
end

function ProductionMapService:SetNight(isNight: boolean, options: NightOptions?)
	local powered = options ~= nil and options.generatorPowered == true
	local stocked = options ~= nil and options.firewoodStocked == true
	if options ~= nil and options.weather ~= nil then
		self.weatherId = options.weather
		self.weatherSeed = options.weatherSeed or 0
	elseif options == nil and not isNight then
		-- Bare day reset (round teardown) clears the round weather.
		self.weatherId = "Clear"
		self.weatherSeed = 0
	end
	local weather = WeatherConfig.Get(self.weatherId)
	setFolderVisible(self.nightTown, isNight)
	-- The south day-wall only exists while the town is intangible; at night
	-- the road into Hollow Creek must be walkable.
	local dayWall = self.dayCamp:FindFirstChild("TownApproachDayWall")
	if dayWall and dayWall:IsA("BasePart") then
		dayWall.CanCollide = not isNight
	end
	for _, descendant in self.dayCamp:GetDescendants() do
		if descendant:IsA("SurfaceLight") then
			-- Cabin window lights only burn at night if the generator was repaired.
			descendant.Enabled = isNight and powered
		end
	end
	-- Expansion-pack lamps (WorldKit.lamp): burn at night; gated ones also
	-- need the generator repaired.
	for _, folder in { self.dayCamp :: Instance, self.nightTown :: Instance } do
		for _, descendant in folder:GetDescendants() do
			if
				descendant:IsA("PointLight")
				and descendant:GetAttribute("CampLamp") == true
			then
				local gated = descendant:GetAttribute("GeneratorGated") == true
				descendant.Enabled = isNight and (not gated or powered)
			end
		end
	end
	local ambience = optionalMapModule("WorldAmbience")
	if ambience then
		if typeof(ambience.SetNight) == "function" then
			pcall(ambience.SetNight, isNight)
		end
		if typeof(ambience.SetWeather) == "function" then
			pcall(ambience.SetWeather, if isNight then self.weatherId else "Clear")
		end
	end

	local flame: BasePart? = nil
	for _, descendant in self.dayCamp:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("SafeVolume") == true then
			flame = descendant
			break
		end
	end
	if flame then
		local light = flame:FindFirstChildOfClass("PointLight")
		local fire = flame:FindFirstChildOfClass("Fire")
		if isNight then
			-- Stocked firewood keeps the campfire blazing (and marks the safe
			-- haven); unstocked, it gutters down to embers.
			if light then
				light.Brightness = if stocked then 3.4 else 1.1
				light.Range = if stocked then 44 else 16
			end
			if fire then
				fire.Size = if stocked then 12 else 5
				fire.Heat = if stocked then 12 else 6
			end
		else
			if light then
				light.Brightness = 2.4
				light.Range = 32
			end
			if fire then
				fire.Size = 7
				fire.Heat = 9
			end
		end
	end

	local atmosphere = Lighting:FindFirstChild("CampAtmosphere")
	local color = Lighting:FindFirstChild("CampColor")
	local bloom = Lighting:FindFirstChild("CampBloom")
	local rays = Lighting:FindFirstChild("CampSunRays")
	local transition = TweenInfo.new(
		if isNight then 1.8 else 1.25,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut
	)
	if isNight then
		Lighting.ClockTime = 1.25
		-- Weather fog stacks multiplicatively with the generator consequence:
		-- a powered camp still sees farther through the same weather.
		TweenService:Create(Lighting, transition, {
			Brightness = (if powered then 1.85 else 1.55)
				* weather.brightnessMultiplier,
			Ambient = weather.nightAmbientOverride
				or scaleColor(NIGHT_AMBIENT, weather.ambientMultiplier),
			OutdoorAmbient = weather.nightOutdoorAmbientOverride
				or scaleColor(
					if powered
						then Color3.fromRGB(126, 138, 170)
						else Color3.fromRGB(104, 116, 148),
					weather.ambientMultiplier
				),
			FogColor = weather.nightFogColorOverride or Color3.fromRGB(52, 62, 82),
			FogStart = (if powered then 160 else 110) * weather.fogStartMultiplier,
			FogEnd = (if powered then 1200 else 900) * weather.fogEndMultiplier,
		}):Play()
		if atmosphere and atmosphere:IsA("Atmosphere") then
			TweenService:Create(atmosphere, transition, {
				Density = math.min(0.26 * weather.atmosphereDensityMultiplier, 0.55),
				Offset = 0,
				Color = weather.nightAtmosphereColorOverride
					or Color3.fromRGB(118, 132, 152),
				Decay = weather.nightAtmosphereDecayOverride
					or Color3.fromRGB(48, 58, 84),
				Glare = 0.14,
				Haze = 1.6,
			}):Play()
		end
		if color and color:IsA("ColorCorrectionEffect") then
			TweenService:Create(color, transition, {
				Brightness = 0.05,
				Contrast = 0.16,
				-- The blood moon keeps more color so the red reads as red.
				Saturation = if weather.nightTintOverride then -0.18 else -0.26,
				TintColor = weather.nightTintOverride
					or Color3.fromRGB(172, 192, 220),
			}):Play()
		end
		if bloom and bloom:IsA("BloomEffect") then
			TweenService:Create(bloom, transition, {
				Intensity = 0.42,
				Threshold = 0.82,
			}):Play()
		end
		if rays and rays:IsA("SunRaysEffect") then
			rays.Enabled = false
		end
	else
		Lighting.ClockTime = 14.2
		local weatherFoggedDay = weather.fogEndMultiplier < 1
		TweenService:Create(Lighting, transition, {
			Brightness = 2.1 * weather.brightnessMultiplier,
			Ambient = scaleColor(DAY_AMBIENT, weather.ambientMultiplier),
			OutdoorAmbient = scaleColor(
				Color3.fromRGB(135, 142, 128),
				weather.ambientMultiplier
			),
			FogColor = Color3.fromRGB(188, 201, 188),
			FogStart = if weatherFoggedDay
				then DAY_WEATHER_FOG_START * weather.fogStartMultiplier
				else 0,
			FogEnd = if weatherFoggedDay
				then DAY_WEATHER_FOG_END * weather.fogEndMultiplier
				else 100000,
		}):Play()
		if atmosphere and atmosphere:IsA("Atmosphere") then
			TweenService:Create(atmosphere, transition, {
				Density = math.min(0.22 * weather.atmosphereDensityMultiplier, 0.45),
				Offset = 0.05,
				Color = Color3.fromRGB(199, 213, 200),
				Decay = Color3.fromRGB(92, 111, 98),
				Glare = 0.08,
				Haze = 1.15,
			}):Play()
		end
		if color and color:IsA("ColorCorrectionEffect") then
			TweenService:Create(color, transition, {
				Brightness = 0.02,
				Contrast = 0.08,
				Saturation = -0.04,
				TintColor = Color3.fromRGB(255, 244, 221),
			}):Play()
		end
		if bloom and bloom:IsA("BloomEffect") then
			TweenService:Create(bloom, transition, {
				Intensity = 0.22,
				Threshold = 1.15,
			}):Play()
		end
		if rays and rays:IsA("SunRaysEffect") then
			rays.Enabled = weather.id == "Clear"
		end
	end

	self:_applyRainForWeather(weather)
	if isNight and weather.lightningEnabled then
		self:_startLightning(weather)
	else
		self:_stopLightning()
	end
end

-- Before a round seeds the pool the active map is empty, which means every
-- station is treated as live (legacy behavior for tools and tests).
function ProductionMapService:_isStationActive(objectiveId: string): boolean
	if next(self.activeObjectiveIds) == nil then
		return true
	end
	return self.activeObjectiveIds[objectiveId] == true
end

-- Tamper-evidence inspect prompts stay interactive regardless of the
-- day-objective prompt toggles, so night investigators can still find them.
local function isTamperPrompt(prompt: Instance): boolean
	local holder = prompt.Parent
	return holder ~= nil and holder.Name == "TamperEvidence"
end

function ProductionMapService:SetObjectivePromptsEnabled(enabled: boolean)
	self.objectivePromptsEnabled = enabled
	for _, station in self.objectivesFolder:GetChildren() do
		local active = self:_isStationActive(station.Name)
		for _, descendant in station:GetDescendants() do
			if descendant:IsA("ProximityPrompt") and not isTamperPrompt(descendant) then
				descendant.Enabled = enabled and active
			end
		end
	end
end

-- Applies the seeded pool for the round: inactive stations hide their prompts
-- and billboards but keep their geometry so the camp still looks lived-in.
function ProductionMapService:SetActiveObjectives(activeIds: { [string]: boolean })
	self.activeObjectiveIds = table.clone(activeIds)
	for _, station in self.objectivesFolder:GetChildren() do
		local active = self:_isStationActive(station.Name)
		for _, descendant in station:GetDescendants() do
			if descendant:IsA("ProximityPrompt") and not isTamperPrompt(descendant) then
				descendant.Enabled = self.objectivePromptsEnabled and active
			elseif
				descendant:IsA("BillboardGui")
				and (
					descendant.Name == "ObjectiveMarker"
					or descendant.Name == "DropZoneMarker"
				)
			then
				descendant.Enabled = active
			end
		end
	end
end

-- Minigame progress feedback on the station billboard. An empty string
-- restores the original station text.
function ProductionMapService:SetObjectiveProgress(objectiveId: string, text: string)
	local station = self.objectivesFolder:FindFirstChild(objectiveId)
	if not station then
		return
	end
	local marker = station:FindFirstChild("ObjectiveMarker", true)
	if marker and marker:IsA("BillboardGui") then
		local label = marker:FindFirstChildOfClass("TextLabel")
		if label then
			local originalText = label:GetAttribute("OriginalText")
			label.Text = if text == "" and type(originalText) == "string"
				then originalText
				else text
		end
	end
end

function ProductionMapService:MarkObjectiveComplete(objectiveId: string)
	local station = self.objectivesFolder:FindFirstChild(objectiveId)
	if not station then
		return
	end
	local root = if station:IsA("Model")
		then station:FindFirstChild("InteractionRoot")
		else station
	if root and root:IsA("BasePart") then
		root.Color = Color3.fromRGB(63, 130, 78)
	end
	local indicator = station:FindFirstChild("StatusLamp", true)
	if indicator and indicator:IsA("BasePart") then
		indicator.Color = Color3.fromRGB(79, 214, 112)
	end
	local marker = station:FindFirstChild("ObjectiveMarker", true)
	if marker and marker:IsA("BillboardGui") then
		local label = marker:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = "COMPLETE"
			label.TextColor3 = Color3.fromRGB(111, 239, 144)
		end
	end
	-- Disable every station prompt (wire targets and drop zones included).
	for _, descendant in station:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and not isTamperPrompt(descendant) then
			descendant.Enabled = false
		end
	end
end

-- Sabotage support: visually reverts a completed station so it can be redone.
function ProductionMapService:MarkObjectiveIncomplete(objectiveId: string)
	local station = self.objectivesFolder:FindFirstChild(objectiveId)
	if not station then
		return
	end
	local root = if station:IsA("Model")
		then station:FindFirstChild("InteractionRoot")
		else station
	if root and root:IsA("BasePart") then
		local original = root:GetAttribute("OriginalColor")
		if typeof(original) == "Color3" then
			root.Color = original
		end
	end
	local indicator = station:FindFirstChild("StatusLamp", true)
	if indicator and indicator:IsA("BasePart") then
		indicator.Color = Color3.fromRGB(187, 72, 49)
	end
	local marker = station:FindFirstChild("ObjectiveMarker", true)
	if marker and marker:IsA("BillboardGui") then
		local label = marker:FindFirstChildOfClass("TextLabel")
		if label then
			local originalText = label:GetAttribute("OriginalText")
			if type(originalText) == "string" then
				label.Text = originalText
			end
			label.TextColor3 = Color3.fromRGB(244, 224, 176)
		end
	end
	local active = self:_isStationActive(objectiveId)
	for _, descendant in station:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and not isTamperPrompt(descendant) then
			descendant.Enabled = self.objectivePromptsEnabled and active
		end
	end
end

-- A sabotaged station leaves a daytime hint: a small prop with an inspect
-- prompt telling campers the repair was undone on purpose.
function ProductionMapService:SpawnTamperEvidence(objectiveId: string)
	local station = self.objectivesFolder:FindFirstChild(objectiveId)
	if not station or station:FindFirstChild("TamperEvidence", true) then
		return
	end
	local root = if station:IsA("Model")
		then station:FindFirstChild("InteractionRoot")
		else station
	if not root or not root:IsA("BasePart") then
		return
	end
	local prop = createPart(
		station,
		"TamperEvidence",
		Vector3.new(1.6, 1, 1.6),
		root.CFrame * CFrame.new(3.2, 1.1, 3.2),
		Color3.fromRGB(54, 46, 42),
		Enum.Material.Slate
	)
	createInspectPrompt(
		prop,
		"Frayed handiwork",
		"The repair has been undone. Deliberately."
	)
end

function ProductionMapService:ResetObjectives()
	self.activeObjectiveIds = {}
	self.objectivePromptsEnabled = false
	for _, station in self.objectivesFolder:GetChildren() do
		local root = if station:IsA("Model")
			then station:FindFirstChild("InteractionRoot")
			else station
		if root and root:IsA("BasePart") then
			local original = root:GetAttribute("OriginalColor")
			if typeof(original) == "Color3" then
				root.Color = original
			end
		end
		local tamper = station:FindFirstChild("TamperEvidence", true)
		if tamper then
			tamper:Destroy()
		end
		local indicator = station:FindFirstChild("StatusLamp", true)
		if indicator and indicator:IsA("BasePart") then
			indicator.Color = Color3.fromRGB(187, 72, 49)
		end
		local marker = station:FindFirstChild("ObjectiveMarker", true)
		if marker and marker:IsA("BillboardGui") then
			marker.Enabled = true
			local label = marker:FindFirstChildOfClass("TextLabel")
			if label then
				local originalText = label:GetAttribute("OriginalText")
				if type(originalText) == "string" then
					label.Text = originalText
				end
				label.TextColor3 = Color3.fromRGB(244, 224, 176)
			end
		end
		local dropMarker = station:FindFirstChild("DropZoneMarker", true)
		if dropMarker and dropMarker:IsA("BillboardGui") then
			dropMarker.Enabled = true
		end
		for _, descendant in station:GetDescendants() do
			if descendant:IsA("ProximityPrompt") then
				descendant.Enabled = false
			end
		end
	end
end

function ProductionMapService:_spawnSearchAt(socket: Part)
	local alias = socket.Name
	if self.evidenceFolder:FindFirstChild(alias) then
		return
	end
	local weather = WeatherConfig.Get(self.weatherId)
	local search = createPart(
		self.evidenceFolder,
		alias,
		Vector3.new(3.5, 2, 3.5),
		socket.CFrame,
		-- Blood Moon: search sites glow hotter so clues read through the
		-- red haze.
		if weather.evidenceGlowBoost
			then Color3.fromRGB(236, 176, 96)
			else Color3.fromRGB(173, 154, 92),
		Enum.Material.Neon,
		if weather.evidenceGlowBoost then 0.05 else 0.18
	)
	search:SetAttribute("EvidenceId", alias)
	-- Blood Moon: evidence interactions complete ~25% faster.
	local prompt = createPrompt(
		search,
		"Search",
		"Possible evidence",
		0.9 * weather.evidenceHoldMultiplier
	)
	prompt.Triggered:Connect(function(player: Player)
		if self.evidenceClaimed[alias] then
			return
		end
		if self.onEvidence(player, alias) then
			self.evidenceClaimed[alias] = true
			search:Destroy()
		end
	end)
end

-- With ~27 registered search locations and only a handful of finds per
-- round, glows spawn only where something is actually assigned; nil keeps
-- the legacy spawn-everywhere behavior.
function ProductionMapService:SpawnEvidence(activeAliasIds: { [string]: boolean }?)
	self:ClearEvidence()
	self.evidenceClaimed = {}
	local spawned: { string } = {}
	for _, socket in self.evidenceSockets do
		if activeAliasIds == nil or activeAliasIds[socket.Name] == true then
			self:_spawnSearchAt(socket)
			table.insert(spawned, socket.Name)
		end
	end
	-- Round telemetry: which search sites host evidence tonight. Cheap, once
	-- per Investigation, and it makes clue-spread regressions visible in the
	-- Output log without any tooling.
	print("[CAMP-Mystery] Investigation search sites: " .. table.concat(spawned, ", "))
end

-- Mid-round evidence (attacks, device traces) can land on a location whose
-- glow was not spawned at Investigation start.
function ProductionMapService:EnsureSearchSpawn(aliasId: string)
	for _, socket in self.evidenceSockets do
		if socket.Name == aliasId then
			self:_spawnSearchAt(socket)
			return
		end
	end
end

function ProductionMapService:ClearEvidence()
	self.evidenceFolder:ClearAllChildren()
	self.evidenceClaimed = {}
end

function ProductionMapService:ResetRound()
	self:ClearEvidence()
	self:ResetObjectives()
	self:ResetSideObjectives()
	self:ClearDayKeys()
	self:ClearSupplyCache()
	self:ResetLockedRooms()
	for _, door in self.interactiveDoors do
		door.isOpen = false
		door.part.CFrame = door.closedCFrame
		door.part.CanCollide = true
		door.prompt.ActionText = "Open"
	end
	self:SetNight(false)
end

return ProductionMapService
