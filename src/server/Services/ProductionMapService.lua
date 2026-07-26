--!strict

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

type ObjectiveHandler = (player: Player, objectiveId: string) -> ()
type EvidenceHandler = (player: Player, evidenceId: string) -> boolean

type ProductionMapServiceState = {
	mapFolder: Folder,
	dayCamp: Folder,
	nightTown: Folder,
	objectivesFolder: Folder,
	evidenceFolder: Folder,
	evidenceSockets: { BasePart },
	onObjective: ObjectiveHandler,
	onEvidence: EvidenceHandler,
	evidenceClaimed: { [string]: boolean },
}

local ProductionMapService = {}
ProductionMapService.__index = ProductionMapService

export type ProductionMapService = typeof(
	setmetatable({} :: ProductionMapServiceState, ProductionMapService)
)

local DAY_AMBIENT = Color3.fromRGB(128, 139, 121)
local NIGHT_AMBIENT = Color3.fromRGB(24, 29, 43)

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
	prompt.Parent = parent
	return prompt
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
			descendant.Transparency = if visible then visibleTransparency else 1
			descendant.CanCollide = visible
			descendant.CanTouch = visible
			descendant.CanQuery = visible
		elseif descendant:IsA("ProximityPrompt") then
			descendant.Enabled = visible
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
			descendant.Enabled = visible
		elseif descendant:IsA("Light") then
			descendant.Enabled = visible
		end
	end
end

local function createCabin(parent: Instance, name: string, position: Vector3, width: number)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local body = createPart(
		model,
		"Body",
		Vector3.new(width, 10, 16),
		CFrame.new(position + Vector3.new(0, 5, 0)),
		Color3.fromRGB(83, 59, 42),
		Enum.Material.WoodPlanks
	)
	model.PrimaryPart = body
	createPart(
		model,
		"Roof",
		Vector3.new(width + 3, 2, 19),
		CFrame.new(position + Vector3.new(0, 11, 0)) * CFrame.Angles(0, 0, math.rad(4)),
		Color3.fromRGB(46, 42, 39),
		Enum.Material.Slate
	)
	createPart(
		model,
		"Porch",
		Vector3.new(width - 2, 1, 5),
		CFrame.new(position + Vector3.new(0, 0.5, -10)),
		Color3.fromRGB(77, 54, 37),
		Enum.Material.WoodPlanks
	)
	createPart(
		model,
		"Door",
		Vector3.new(4, 7, 0.6),
		CFrame.new(position + Vector3.new(0, 3.5, -8.3)),
		Color3.fromRGB(45, 30, 22),
		Enum.Material.Wood
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
end

local function createBuilding(
	parent: Instance,
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3,
	signText: string
)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local body = createPart(
		model,
		"Structure",
		size,
		CFrame.new(position + Vector3.new(0, size.Y / 2, 0)),
		color,
		Enum.Material.Brick
	)
	model.PrimaryPart = body
	createPart(
		model,
		"Roof",
		Vector3.new(size.X + 2, 1.5, size.Z + 2),
		CFrame.new(position + Vector3.new(0, size.Y + 0.75, 0)),
		Color3.fromRGB(41, 43, 46),
		Enum.Material.Slate
	)
	local sign = createPart(
		model,
		"Sign",
		Vector3.new(math.min(size.X - 3, 18), 4, 0.5),
		CFrame.new(position + Vector3.new(0, size.Y - 3, -size.Z / 2 - 0.35)),
		Color3.fromRGB(27, 29, 31),
		Enum.Material.Wood
	)
	createSign(sign, signText, Color3.fromRGB(194, 202, 191))
	for column = -1, 1, 2 do
		createPart(
			model,
			"BoardedWindow",
			Vector3.new(5, 4, 0.4),
			CFrame.new(position + Vector3.new(column * size.X * 0.23, size.Y * 0.48, -size.Z / 2 - 0.25)),
			Color3.fromRGB(75, 63, 50),
			Enum.Material.WoodPlanks
		)
	end
end

local function createStreetlight(parent: Instance, position: Vector3)
	local pole = createPart(
		parent,
		"Streetlight",
		Vector3.new(0.8, 15, 0.8),
		CFrame.new(position + Vector3.new(0, 7.5, 0)),
		Color3.fromRGB(47, 51, 53),
		Enum.Material.Metal
	)
	local lamp = createPart(
		parent,
		"Lamp",
		Vector3.new(3, 1.4, 3),
		CFrame.new(position + Vector3.new(0, 15, 0)),
		Color3.fromRGB(170, 184, 145),
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Brightness = 1.25
	light.Range = 25
	light.Color = Color3.fromRGB(184, 200, 160)
	light.Parent = lamp
	pole:SetAttribute("ShadowNode", true)
end

local function createPineTree(
	parent: Instance,
	position: Vector3,
	height: number,
	canopyColor: Color3
)
	local trunk = createPart(
		parent,
		"PineTrunk",
		Vector3.new(2.4, height, 2.4),
		CFrame.new(position + Vector3.new(0, height / 2, 0)),
		Color3.fromRGB(67, 50, 36),
		Enum.Material.Wood
	)
	trunk:SetAttribute("Occluder", true)
	for layer = 1, 3 do
		local canopy = createPart(
			parent,
			"PineCanopy",
			Vector3.new(12 - layer * 1.8, 7, 12 - layer * 1.8),
			CFrame.new(position + Vector3.new(0, height * 0.52 + layer * 3.2, 0)),
			canopyColor,
			Enum.Material.Grass
		)
		canopy.Shape = Enum.PartType.Ball
		canopy.CanCollide = false
		canopy:SetAttribute("Occluder", true)
	end
end

local function cloneAuthoredMap(folderName: string): Model?
	local assets = ServerStorage:FindFirstChild("ServerAssets")
	local maps = if assets then assets:FindFirstChild("Maps") else nil
	local source = if maps then maps:FindFirstChild(folderName) else nil
	return if source and source:IsA("Model") then source:Clone() else nil
end

function ProductionMapService.new(
	onObjective: ObjectiveHandler,
	onEvidence: EvidenceHandler
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
		evidenceClaimed = {},
	}, ProductionMapService)
	self:Build()
	self:ResetRound()
	return self
end

function ProductionMapService:Build()
	local authoredCamp = cloneAuthoredMap("Camp")
	if authoredCamp then
		authoredCamp.Name = "AuthoredCamp"
		authoredCamp.Parent = self.dayCamp
	else
		createPart(
			self.dayCamp,
			"CampGround",
			Vector3.new(230, 1, 190),
			CFrame.new(0, -0.5, 12),
			Color3.fromRGB(59, 82, 52),
			Enum.Material.Grass
		)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "CampSpawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.Position = Vector3.new(0, 0.5, 34)
		spawn.Color = Color3.fromRGB(106, 88, 64)
		spawn.Material = Enum.Material.WoodPlanks
			spawn.Transparency = 0.35
			spawn.Parent = self.dayCamp
			createPart(
				self.dayCamp,
				"CampPath",
				Vector3.new(18, 0.35, 150),
				CFrame.new(0, 0.2, 5),
				Color3.fromRGB(117, 91, 64),
				Enum.Material.Ground
			)
			local creek = createPart(
				self.dayCamp,
				"Creek",
				Vector3.new(34, 0.4, 170),
				CFrame.new(104, 0.1, 12) * CFrame.Angles(0, 0.08, 0),
				Color3.fromRGB(69, 123, 139),
				Enum.Material.Glass,
				0.25
			)
			creek.CanCollide = false
			createCabin(self.dayCamp, "PineCabin", Vector3.new(-54, 0, 18), 24)
		createCabin(self.dayCamp, "CreekCabin", Vector3.new(54, 0, 18), 24)
		createCabin(self.dayCamp, "CounselorLodge", Vector3.new(0, 0, 74), 30)
		createCabin(self.dayCamp, "SupplyCabin", Vector3.new(-76, 0, -42), 18)
		local fire = createPart(
			self.dayCamp,
			"Campfire",
			Vector3.new(8, 2, 8),
			CFrame.new(0, 1, 2) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(124, 78, 48),
			Enum.Material.Slate
		)
		fire.Shape = Enum.PartType.Cylinder
		fire:SetAttribute("SafeVolume", true)
			for index = 1, 16 do
				local angle = (index / 16) * math.pi * 2
				local radius = 95 + (index % 3) * 8
				createPineTree(
					self.dayCamp,
					Vector3.new(
						math.cos(angle) * radius,
						0,
						12 + math.sin(angle) * radius
					),
					20 + index % 4 * 3,
					if index % 2 == 0
						then Color3.fromRGB(43, 85, 57)
						else Color3.fromRGB(50, 94, 61)
				)
			end
	end

	for _, definition in OBJECTIVES do
		local station = createPart(
			self.objectivesFolder,
			definition.id,
			Vector3.new(9, 4, 9),
			CFrame.new(definition.position),
			definition.color,
			Enum.Material.WoodPlanks
		)
		station:SetAttribute("ObjectiveId", definition.id)
		station:SetAttribute("OriginalColor", definition.color)
		local prompt = createPrompt(station, "Complete", definition.name, 1.1)
		prompt.Triggered:Connect(function(player: Player)
			self.onObjective(player, definition.id)
		end)
	end

	local authoredTown = cloneAuthoredMap("NightTown")
	if authoredTown then
		authoredTown.Name = "AuthoredNightTown"
		authoredTown.Parent = self.nightTown
	else
			createPart(
				self.nightTown,
			"MainRoad",
			Vector3.new(50, 1, 360),
			CFrame.new(0, 0, -225),
			Color3.fromRGB(36, 39, 42),
				Enum.Material.Asphalt
			)
			for stripe = 1, 10 do
				createPart(
					self.nightTown,
					"FadedRoadStripe",
					Vector3.new(0.55, 0.08, 14),
					CFrame.new(0, 0.55, -62 - stripe * 32),
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
					CFrame.new(side * 29, 0.3, -225),
					Color3.fromRGB(83, 83, 79),
					Enum.Material.Concrete
				)
			end
		createPart(
			self.nightTown,
			"CrossRoad",
			Vector3.new(260, 1, 42),
			CFrame.new(0, 0.02, -190),
			Color3.fromRGB(38, 41, 43),
			Enum.Material.Asphalt
		)
		createBuilding(self.nightTown, "GeneralStore", Vector3.new(-73, 0, -185), Vector3.new(34, 19, 30), Color3.fromRGB(77, 72, 65), "GENERAL STORE")
		createBuilding(self.nightTown, "GasStation", Vector3.new(75, 0, -185), Vector3.new(35, 16, 28), Color3.fromRGB(82, 76, 65), "LAST STOP GAS")
		createBuilding(self.nightTown, "ResidentialA", Vector3.new(-100, 0, -135), Vector3.new(30, 17, 28), Color3.fromRGB(71, 67, 64), "RESIDENCE")
		createBuilding(self.nightTown, "Factory", Vector3.new(-100, 0, -275), Vector3.new(48, 28, 45), Color3.fromRGB(64, 69, 70), "MILL NO. 7")
		createBuilding(self.nightTown, "PoliceStation", Vector3.new(92, 0, -360), Vector3.new(42, 22, 38), Color3.fromRGB(64, 72, 79), "POLICE")
		createBuilding(self.nightTown, "CompanyHouse", Vector3.new(-100, 0, -390), Vector3.new(34, 18, 30), Color3.fromRGB(72, 65, 59), "COMPANY HOUSE")
		local tower = createPart(
			self.nightTown,
			"WaterTower",
			Vector3.new(16, 25, 16),
			CFrame.new(110, 22, -292),
			Color3.fromRGB(63, 72, 75),
			Enum.Material.CorrodedMetal
		)
		tower.Shape = Enum.PartType.Cylinder
		for index = 1, 9 do
			createStreetlight(self.nightTown, Vector3.new(if index % 2 == 0 then 18 else -18, 0, -62 - index * 38))
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
end

function ProductionMapService:GetEvidenceAliases(): { string }
	local aliases: { string } = {}
	for _, socket in self.evidenceSockets do
		table.insert(aliases, socket.Name)
	end
	return aliases
end

function ProductionMapService:SetNight(isNight: boolean)
	setFolderVisible(self.nightTown, isNight)
	if isNight then
		Lighting.ClockTime = 1.25
		Lighting.Brightness = 0.8
		Lighting.Ambient = NIGHT_AMBIENT
		Lighting.OutdoorAmbient = Color3.fromRGB(15, 19, 31)
		Lighting.FogColor = Color3.fromRGB(39, 48, 59)
		Lighting.FogStart = 18
		Lighting.FogEnd = 215
	else
		Lighting.ClockTime = 14.2
		Lighting.Brightness = 2.1
		Lighting.Ambient = DAY_AMBIENT
		Lighting.OutdoorAmbient = Color3.fromRGB(135, 142, 128)
		Lighting.FogColor = Color3.fromRGB(188, 201, 188)
		Lighting.FogStart = 0
		Lighting.FogEnd = 100000
	end
end

function ProductionMapService:SetObjectivePromptsEnabled(enabled: boolean)
	for _, descendant in self.objectivesFolder:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant.Enabled = enabled
		end
	end
end

function ProductionMapService:MarkObjectiveComplete(objectiveId: string)
	local station = self.objectivesFolder:FindFirstChild(objectiveId)
	if not station or not station:IsA("BasePart") then
		return
	end
	station.Color = Color3.fromRGB(63, 130, 78)
	local prompt = station:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
end

function ProductionMapService:ResetObjectives()
	for _, station in self.objectivesFolder:GetChildren() do
		if station:IsA("BasePart") then
			local original = station:GetAttribute("OriginalColor")
			if typeof(original) == "Color3" then
				station.Color = original
			end
			local prompt = station:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = false
			end
		end
	end
end

function ProductionMapService:SpawnEvidence()
	self:ClearEvidence()
	self.evidenceClaimed = {}
	for _, socket in self.evidenceSockets do
		local alias = socket.Name
		local search = createPart(
			self.evidenceFolder,
			alias,
			Vector3.new(3.5, 2, 3.5),
			socket.CFrame,
			Color3.fromRGB(173, 154, 92),
			Enum.Material.Neon,
			0.18
		)
		search:SetAttribute("EvidenceId", alias)
		local prompt = createPrompt(search, "Search", "Possible evidence", 0.9)
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
end

function ProductionMapService:ClearEvidence()
	self.evidenceFolder:ClearAllChildren()
	self.evidenceClaimed = {}
end

function ProductionMapService:ResetRound()
	self:ClearEvidence()
	self:ResetObjectives()
	self:SetNight(false)
end

return ProductionMapService
