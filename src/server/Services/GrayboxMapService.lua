--!strict

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

type ObjectiveHandler = (player: Player, objectiveId: string) -> ()
type EvidenceHandler = (player: Player, evidenceId: string) -> boolean

type GrayboxMapServiceState = {
	mapFolder: Folder,
	dayCamp: Folder,
	nightTown: Folder,
	objectivesFolder: Folder,
	evidenceFolder: Folder,
	onObjective: ObjectiveHandler,
	onEvidence: EvidenceHandler,
	evidenceClaimed: { [string]: boolean },
}

local GrayboxMapService = {}
GrayboxMapService.__index = GrayboxMapService

export type GrayboxMapService = typeof(
	setmetatable({} :: GrayboxMapServiceState, GrayboxMapService)
)

local DAY_AMBIENT = Color3.fromRGB(125, 130, 118)
local NIGHT_AMBIENT = Color3.fromRGB(30, 38, 56)

local function createPart(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createPrompt(parent: BasePart, actionText: string, objectText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.75
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function createLabel(parent: BasePart, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GrayboxLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(220, 48)
	billboard.StudsOffset = Vector3.new(0, parent.Size.Y / 2 + 1.5, 0)
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(12, 15, 17)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
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
		elseif descendant:IsA("BillboardGui") then
			descendant.Enabled = visible
		elseif descendant:IsA("PointLight") then
			descendant.Enabled = visible
		end
	end
end

local function createCabin(parent: Folder, name: string, position: Vector3)
	local cabin = Instance.new("Folder")
	cabin.Name = name
	cabin.Parent = parent

	createPart(
		cabin,
		"CabinBody",
		Vector3.new(18, 10, 14),
		position + Vector3.new(0, 5, 0),
		Color3.fromRGB(91, 63, 42),
		Enum.Material.WoodPlanks
	)
	createPart(
		cabin,
		"Roof",
		Vector3.new(20, 2, 16),
		position + Vector3.new(0, 11, 0),
		Color3.fromRGB(48, 42, 38),
		Enum.Material.Slate
	)
	createPart(
		cabin,
		"Door",
		Vector3.new(4, 7, 1),
		position + Vector3.new(0, 3.5, -7.5),
		Color3.fromRGB(50, 32, 22),
		Enum.Material.Wood
	)
end

function GrayboxMapService.new(
	onObjective: ObjectiveHandler,
	onEvidence: EvidenceHandler
): GrayboxMapService
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

	local self: GrayboxMapService = setmetatable({
		mapFolder = mapFolder,
		dayCamp = dayCamp,
		nightTown = nightTown,
		objectivesFolder = objectivesFolder,
		evidenceFolder = evidenceFolder,
		onObjective = onObjective,
		onEvidence = onEvidence,
		evidenceClaimed = {},
	}, GrayboxMapService)

	self:Build()
	self:ResetRound()

	return self
end

function GrayboxMapService:Build()
	createPart(
		self.dayCamp,
		"CampGround",
		Vector3.new(180, 1, 150),
		Vector3.new(0, -0.5, 10),
		Color3.fromRGB(63, 86, 55),
		Enum.Material.Grass
	)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CampSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, 28)
	spawn.Color = Color3.fromRGB(128, 108, 76)
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Transparency = 0.25
	spawn.Parent = self.dayCamp

	createCabin(self.dayCamp, "CamperCabinA", Vector3.new(-42, 0, 8))
	createCabin(self.dayCamp, "CamperCabinB", Vector3.new(42, 0, 8))
	createCabin(self.dayCamp, "CounselorCabin", Vector3.new(0, 0, 58))

	local campfire = createPart(
		self.dayCamp,
		"Campfire",
		Vector3.new(8, 2, 8),
		Vector3.new(0, 1, 0),
		Color3.fromRGB(167, 84, 37),
		Enum.Material.Slate
	)
	campfire.Shape = Enum.PartType.Cylinder
	createLabel(campfire, "CAMPFIRE", Color3.fromRGB(255, 190, 92))

	local objectiveDefinitions = {
		{
			id = "firewood",
			name = "Stack Firewood",
			position = Vector3.new(-24, 2, -25),
			color = Color3.fromRGB(130, 86, 52),
		},
		{
			id = "generator",
			name = "Repair Generator",
			position = Vector3.new(0, 2, -38),
			color = Color3.fromRGB(100, 112, 105),
		},
		{
			id = "supplies",
			name = "Secure Supplies",
			position = Vector3.new(24, 2, -25),
			color = Color3.fromRGB(109, 94, 56),
		},
	}

	for _, definition in objectiveDefinitions do
		local station = createPart(
			self.objectivesFolder,
			definition.id,
			Vector3.new(8, 4, 8),
			definition.position,
			definition.color,
			Enum.Material.WoodPlanks
		)
		station:SetAttribute("ObjectiveId", definition.id)
		station:SetAttribute("OriginalColor", definition.color)
		createLabel(station, definition.name, Color3.fromRGB(236, 224, 184))
		local prompt = createPrompt(station, "Complete", definition.name)
		prompt.Triggered:Connect(function(player: Player)
			self.onObjective(player, definition.id)
		end)
	end

	createPart(
		self.nightTown,
		"MainRoad",
		Vector3.new(54, 1, 220),
		Vector3.new(0, 0.05, -105),
		Color3.fromRGB(40, 43, 46),
		Enum.Material.Asphalt
	)

	for index = 1, 6 do
		local side = if index % 2 == 0 then 1 else -1
		local row = math.ceil(index / 2)
		local building = createPart(
			self.nightTown,
			"AbandonedBuilding" .. index,
			Vector3.new(28, 18 + row * 2, 32),
			Vector3.new(side * 45, 9 + row, -45 - row * 48),
			Color3.fromRGB(67, 70, 72),
			Enum.Material.Brick
		)
		createLabel(building, "ABANDONED", Color3.fromRGB(170, 188, 202))
	end

	for index = 1, 5 do
		local lampPost = createPart(
			self.nightTown,
			"Streetlamp" .. index,
			Vector3.new(1, 16, 1),
			Vector3.new(18, 8, -22 - index * 36),
			Color3.fromRGB(55, 58, 60),
			Enum.Material.Metal
		)
		local lamp = createPart(
			self.nightTown,
			"Lamp" .. index,
			Vector3.new(3, 2, 3),
			lampPost.Position + Vector3.new(0, 8, 0),
			Color3.fromRGB(204, 214, 178),
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Brightness = 1.4
		light.Color = Color3.fromRGB(190, 205, 170)
		light.Range = 24
		light.Parent = lamp
	end

	local waterTower = createPart(
		self.nightTown,
		"WaterTower",
		Vector3.new(14, 22, 14),
		Vector3.new(-70, 18, -160),
		Color3.fromRGB(69, 77, 82),
		Enum.Material.CorrodedMetal
	)
	waterTower.Shape = Enum.PartType.Cylinder
	createLabel(waterTower, "WATER TOWER", Color3.fromRGB(170, 188, 202))
end

function GrayboxMapService:SetNight(isNight: boolean)
	setFolderVisible(self.nightTown, isNight)

	if isNight then
		Lighting.ClockTime = 1.5
		Lighting.Brightness = 1
		Lighting.Ambient = NIGHT_AMBIENT
		Lighting.OutdoorAmbient = Color3.fromRGB(18, 24, 39)
		Lighting.FogColor = Color3.fromRGB(45, 55, 66)
		Lighting.FogStart = 20
		Lighting.FogEnd = 170
	else
		Lighting.ClockTime = 14
		Lighting.Brightness = 2
		Lighting.Ambient = DAY_AMBIENT
		Lighting.OutdoorAmbient = Color3.fromRGB(132, 138, 124)
		Lighting.FogColor = Color3.fromRGB(190, 202, 190)
		Lighting.FogStart = 0
		Lighting.FogEnd = 100000
	end
end

function GrayboxMapService:SetObjectivePromptsEnabled(enabled: boolean)
	for _, descendant in self.objectivesFolder:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant.Enabled = enabled
		end
	end
end

function GrayboxMapService:MarkObjectiveComplete(objectiveId: string)
	local station = self.objectivesFolder:FindFirstChild(objectiveId)
	if not station or not station:IsA("BasePart") then
		return
	end

	station.Color = Color3.fromRGB(66, 135, 83)
	local prompt = station:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
end

function GrayboxMapService:ResetObjectives()
	for _, station in self.objectivesFolder:GetChildren() do
		if station:IsA("BasePart") then
			local originalColor = station:GetAttribute("OriginalColor")
			if typeof(originalColor) == "Color3" then
				station.Color = originalColor
			end
			local prompt = station:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = false
			end
		end
	end
end

function GrayboxMapService:SpawnEvidence()
	self:ClearEvidence()
	self.evidenceClaimed = {}

	local definitions = {
		{
			id = "muddy-bootprint",
			name = "Muddy Bootprint",
			position = Vector3.new(-10, 1.2, -70),
			color = Color3.fromRGB(147, 99, 59),
		},
		{
			id = "torn-fabric",
			name = "Torn Fabric",
			position = Vector3.new(12, 1.2, -125),
			color = Color3.fromRGB(137, 52, 62),
		},
		{
			id = "dropped-token",
			name = "Dropped Camp Token",
			position = Vector3.new(-8, 1.2, -182),
			color = Color3.fromRGB(202, 175, 77),
		},
	}

	for _, definition in definitions do
		local clue = createPart(
			self.evidenceFolder,
			definition.id,
			Vector3.new(3, 1, 3),
			definition.position,
			definition.color,
			Enum.Material.Neon
		)
		clue:SetAttribute("EvidenceId", definition.id)
		createLabel(clue, definition.name, Color3.fromRGB(218, 231, 238))
		local prompt = createPrompt(clue, "Collect", definition.name)
		prompt.Triggered:Connect(function(player: Player)
			if self.evidenceClaimed[definition.id] then
				return
			end
			if self.onEvidence(player, definition.id) then
				self.evidenceClaimed[definition.id] = true
				clue:Destroy()
			end
		end)
	end
end

function GrayboxMapService:ClearEvidence()
	self.evidenceFolder:ClearAllChildren()
	self.evidenceClaimed = {}
end

function GrayboxMapService:ResetRound()
	self:ClearEvidence()
	self:ResetObjectives()
	self:SetNight(false)
end

return GrayboxMapService
