--!strict

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

export type MonsterId =
	"BabyAlien"
	| "Screamer"
	| "Wendigo"
	| "ShadowMonster"
	| "Chupacabra"
	| "Dullahan"
	| "Entity"
	| "Banshee"

type PlaceholderCharacterServiceState = {
	container: Folder,
	monsterModel: Model?,
	counselorModels: { Model },
}

local PlaceholderCharacterService = {}
PlaceholderCharacterService.__index = PlaceholderCharacterService

export type PlaceholderCharacterService = typeof(
	setmetatable({} :: PlaceholderCharacterServiceState, PlaceholderCharacterService)
)

local MONSTER_PRESENTATION: {
	[MonsterId]: {
		color: Color3,
		accent: Color3,
		scale: Vector3,
		headShape: Enum.PartType,
	},
} = {
	BabyAlien = {
		color = Color3.fromRGB(105, 142, 99),
		accent = Color3.fromRGB(192, 238, 125),
		scale = Vector3.new(0.8, 0.55, 1.25),
		headShape = Enum.PartType.Ball,
	},
	Screamer = {
		color = Color3.fromRGB(117, 92, 91),
		accent = Color3.fromRGB(245, 92, 108),
		scale = Vector3.new(1, 1.25, 0.9),
		headShape = Enum.PartType.Block,
	},
	Wendigo = {
		color = Color3.fromRGB(91, 78, 65),
		accent = Color3.fromRGB(207, 190, 154),
		scale = Vector3.new(0.9, 1.65, 0.85),
		headShape = Enum.PartType.Ball,
	},
	ShadowMonster = {
		color = Color3.fromRGB(23, 24, 35),
		accent = Color3.fromRGB(105, 92, 166),
		scale = Vector3.new(1.15, 1.45, 0.8),
		headShape = Enum.PartType.Ball,
	},
	Chupacabra = {
		color = Color3.fromRGB(86, 74, 78),
		accent = Color3.fromRGB(178, 61, 76),
		scale = Vector3.new(1.1, 0.75, 1.35),
		headShape = Enum.PartType.Block,
	},
	Dullahan = {
		color = Color3.fromRGB(51, 63, 66),
		accent = Color3.fromRGB(84, 188, 193),
		scale = Vector3.new(1.15, 1.55, 1),
		headShape = Enum.PartType.Block,
	},
	Entity = {
		color = Color3.fromRGB(82, 91, 123),
		accent = Color3.fromRGB(150, 225, 255),
		scale = Vector3.new(0.85, 1.4, 0.8),
		headShape = Enum.PartType.Ball,
	},
	Banshee = {
		color = Color3.fromRGB(144, 151, 168),
		accent = Color3.fromRGB(218, 234, 255),
		scale = Vector3.new(0.9, 1.5, 0.75),
		headShape = Enum.PartType.Ball,
	},
}

local COUNSELOR_COLORS: { Color3 } = {
	Color3.fromRGB(66, 105, 155),
	Color3.fromRGB(126, 76, 139),
	Color3.fromRGB(190, 72, 116),
	Color3.fromRGB(69, 135, 89),
	Color3.fromRGB(183, 120, 55),
	Color3.fromRGB(112, 84, 62),
}

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Parent = parent
	return part
end

local function labelModel(model: Model, text: string)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlaceholderLabel"
	billboard.Size = UDim2.fromOffset(220, 40)
	billboard.StudsOffset = Vector3.new(0, root.Size.Y / 2 + 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = root
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
	label.BackgroundTransparency = 0.2
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text .. " (PLACEHOLDER)"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
end

local function findAsset(folderName: string, assetName: string): Model?
	local serverAssets = ServerStorage:FindFirstChild("ServerAssets")
	local folder = if serverAssets then serverAssets:FindFirstChild(folderName) else nil
	local asset = if folder then folder:FindFirstChild(assetName) else nil
	return if asset and asset:IsA("Model") then asset else nil
end

local function buildMonsterPlaceholder(monsterId: MonsterId, at: CFrame): Model
	local presentation = MONSTER_PRESENTATION[monsterId]
	local model = Instance.new("Model")
	model.Name = "ActiveMonster_" .. monsterId
	model:SetAttribute("Placeholder", true)
	model:SetAttribute("MonsterId", monsterId)
	local torsoSize = Vector3.new(4, 5, 3) * presentation.scale
	local root = makePart(model, "Root", torsoSize, at, presentation.color)
	model.PrimaryPart = root
	makePart(
		model,
		"Head",
		Vector3.new(3.2, 3.2, 3.2) * presentation.scale,
		at * CFrame.new(0, torsoSize.Y / 2 + 1.6, 0),
		presentation.accent,
		presentation.headShape
	)

	if monsterId == "Wendigo" then
		makePart(model, "LeftAntler", Vector3.new(0.35, 4, 0.35), at * CFrame.new(-1.5, 6, 0) * CFrame.Angles(0, 0, -0.45), presentation.accent)
		makePart(model, "RightAntler", Vector3.new(0.35, 4, 0.35), at * CFrame.new(1.5, 6, 0) * CFrame.Angles(0, 0, 0.45), presentation.accent)
	elseif monsterId == "Dullahan" then
		local head = model:FindFirstChild("Head")
		if head then
			head:Destroy()
		end
		makePart(model, "SpectralFlame", Vector3.new(2, 2, 2), at * CFrame.new(0, torsoSize.Y / 2 + 1.4, 0), presentation.accent, Enum.PartType.Ball).Material = Enum.Material.Neon
	elseif monsterId == "Entity" or monsterId == "Banshee" then
		root.Transparency = 0.25
	elseif monsterId == "ShadowMonster" then
		root.Material = Enum.Material.ForceField
		root.Transparency = 0.2
	end
	labelModel(model, monsterId)
	return model
end

local function buildCounselorPlaceholder(index: number, at: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Counselor_" .. tostring(index)
	model:SetAttribute("Placeholder", true)
	model:SetAttribute("CounselorIndex", index)
	local bodyScale = 1 + ((index - 1) % 3) * 0.12
	local root = makePart(
		model,
		"Torso",
		Vector3.new(3.5 * bodyScale, 5, 2.5),
		at,
		COUNSELOR_COLORS[index]
	)
	model.PrimaryPart = root
	makePart(
		model,
		"Head",
		Vector3.new(3, 3, 3),
		at * CFrame.new(0, 4, 0),
		Color3.fromRGB(196, 155 - index * 5, 125 - index * 3),
		Enum.PartType.Ball
	)
	labelModel(model, "Counselor " .. tostring(index))
	return model
end

function PlaceholderCharacterService.new(): PlaceholderCharacterService
	local runtime = Workspace:WaitForChild("Runtime")
	local characters = runtime:WaitForChild("Characters")
	assert(characters:IsA("Folder"), "Workspace.Runtime.Characters must be a Folder")
	local existing = characters:FindFirstChild("GeneratedCharacters")
	if existing then
		existing:Destroy()
	end
	local container = Instance.new("Folder")
	container.Name = "GeneratedCharacters"
	container.Parent = characters
	return setmetatable({
		container = container,
		monsterModel = nil,
		counselorModels = {},
	}, PlaceholderCharacterService)
end

function PlaceholderCharacterService:SpawnCounselors()
	for _, model in self.counselorModels do
		model:Destroy()
	end
	self.counselorModels = {}
	for index = 1, 6 do
		local asset = findAsset("NPCs", "Counselor_" .. tostring(index))
		local model = if asset
			then asset:Clone()
			else buildCounselorPlaceholder(
				index,
				CFrame.new(-55 + (index - 1) * 22, 3, 55)
			)
		model.Name = "Counselor_" .. tostring(index)
		model.Parent = self.container
		table.insert(self.counselorModels, model)
	end
end

function PlaceholderCharacterService:SpawnMonster(
	monsterId: MonsterId,
	participantId: string,
	at: CFrame
): Model
	if self.monsterModel then
		self.monsterModel:Destroy()
	end
	local asset = findAsset("Monsters", monsterId)
	local model = if asset then asset:Clone() else buildMonsterPlaceholder(monsterId, at)
	model.Name = "ActiveMonster_" .. monsterId
	model:SetAttribute("MonsterId", monsterId)
	model:SetAttribute("ParticipantId", participantId)
	model:PivotTo(at)
	model.Parent = self.container
	self.monsterModel = model
	return model
end

function PlaceholderCharacterService:ClearMonster()
	if self.monsterModel then
		self.monsterModel:Destroy()
		self.monsterModel = nil
	end
end

function PlaceholderCharacterService:Reset()
	self:ClearMonster()
	self:SpawnCounselors()
end

function PlaceholderCharacterService:Destroy()
	self.container:Destroy()
	self.monsterModel = nil
	self.counselorModels = {}
end

return PlaceholderCharacterService
