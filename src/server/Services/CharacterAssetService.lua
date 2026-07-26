--!strict

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local CounselorCatalog = require(
	script.Parent.Parent.Config:WaitForChild("CounselorCatalog")
)

export type MonsterId =
	"BabyAlien"
	| "Screamer"
	| "Wendigo"
	| "ShadowMonster"
	| "Chupacabra"
	| "Dullahan"
	| "Entity"
	| "Banshee"

type CharacterAssetServiceState = {
	container: Folder,
	monsterModel: Model?,
	counselorModels: { Model },
	monsterAnimationTrack: AnimationTrack?,
	monsterAnimationState: string?,
	counselorAnimationTracks: { [string]: AnimationTrack },
	counselorAnimationStates: { [string]: string },
}

local CharacterAssetService = {}
CharacterAssetService.__index = CharacterAssetService

export type CharacterAssetService = typeof(
	setmetatable({} :: CharacterAssetServiceState, CharacterAssetService)
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

local MONSTER_DISPLAY_NAMES: { [MonsterId]: string } = {
	BabyAlien = "Baby Alien",
	Screamer = "The Screamer",
	Wendigo = "Wendigo",
	ShadowMonster = "Shadow Monster",
	Chupacabra = "Chupacabra",
	Dullahan = "Dullahan",
	Entity = "The Entity",
	Banshee = "Banshee",
}

local COUNSELOR_COLORS: { Color3 } = {
	Color3.fromRGB(66, 105, 155),
	Color3.fromRGB(126, 76, 139),
	Color3.fromRGB(190, 72, 116),
	Color3.fromRGB(69, 135, 89),
	Color3.fromRGB(183, 120, 55),
	Color3.fromRGB(112, 84, 62),
}

local APPROVED_ANIMATION_STATES: { [string]: boolean } = {
	Idle = true,
	Transform = true,
	Hunt = true,
	Flee = true,
	Hide = true,
	Alert = true,
}

local COUNSELOR_ANIMATION_BY_BEHAVIOR: { [string]: string } = {
	Routine = "Idle",
	Witness = "Idle",
	Suspect = "Idle",
	Fleeing = "Flee",
	Hiding = "Hide",
	Alert = "Alert",
	Unavailable = "Idle",
}

local COUNSELOR_LOCATIONS: { [string]: CFrame } = {
	Campfire = CFrame.new(0, 3, 7),
	CounselorLodge = CFrame.new(0, 3, 67),
	Infirmary = CFrame.new(51, 3, 24),
	Trailhead = CFrame.new(-88, 3, 54),
	ActivityField = CFrame.new(65, 3, 55),
	Supplies = CFrame.new(-70, 3, -38),
	Generator = CFrame.new(-35, 3, -17),
	CraftCabin = CFrame.new(78, 3, -38),
	NatureLab = CFrame.new(-52, 3, 24),
	Waterfront = CFrame.new(85, 3, 72),
	["camp-evidence-board"] = CFrame.new(12, 3, 7),
	["camp-safe-campfire"] = CFrame.new(0, 3, 7),
	["camp-hide-cabin-a"] = CFrame.new(-48, 3, 18),
	["main-road-safe-entry"] = CFrame.new(0, 3, -52),
	["industrial-safe-loading-bay"] = CFrame.new(-75, 3, -285),
	["industrial-locker-hide"] = CFrame.new(-110, 3, -275),
	["square-gas-station-clue"] = CFrame.new(75, 3, -185),
	["industrial-machine-clue"] = CFrame.new(-100, 3, -275),
	["police-safe-lobby"] = CFrame.new(92, 3, -350),
	["police-desk-witness"] = CFrame.new(92, 3, -360),
	["police-evidence-room-clue"] = CFrame.new(92, 3, -360),
	["police-cell-hide"] = CFrame.new(100, 3, -370),
	["residential-safe-porch"] = CFrame.new(-100, 3, -125),
	["residential-closet-hide"] = CFrame.new(-105, 3, -135),
	["outskirts-safe-road-end"] = CFrame.new(-72, 3, -420),
	["outskirts-house-hide"] = CFrame.new(-100, 3, -390),
	["square-safe-bandstand"] = CFrame.new(0, 3, -190),
	["square-store-hide"] = CFrame.new(-73, 3, -185),
	["square-store-witness"] = CFrame.new(-73, 3, -175),
	["water-tower-safe-platform"] = CFrame.new(110, 22, -292),
	["water-tower-shed-hide"] = CFrame.new(120, 3, -306),
	["water-tower-witness"] = CFrame.new(110, 3, -292),
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
	local previous = root:FindFirstChild("CharacterLabel")
	if previous then
		previous:Destroy()
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CharacterLabel"
	billboard.Size = UDim2.fromOffset(220, 40)
	billboard.StudsOffset = Vector3.new(0, root.Size.Y / 2 + 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = root
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
	label.BackgroundTransparency = 0.2
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
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

local function stopAnimationTrack(track: AnimationTrack?)
	if not track then
		return
	end
	pcall(function()
		track:Stop(0.15)
	end)
	pcall(function()
		track:Destroy()
	end)
end

local function authoredAnimation(model: Model, stateName: string): Animation?
	if
		model:GetAttribute("ProceduralFallback") == true
		or not APPROVED_ANIMATION_STATES[stateName]
	then
		return nil
	end
	local animationFolder = model:FindFirstChild("Animations", true)
	if not animationFolder or not animationFolder:IsA("Folder") then
		return nil
	end
	local animation = animationFolder:FindFirstChild(stateName)
	if not animation or not animation:IsA("Animation") then
		return nil
	end
	local numericId = string.match(animation.AnimationId, "^rbxassetid://(%d+)$")
	if not numericId or (tonumber(numericId) or 0) <= 0 then
		warn(
			string.format(
				"[CharacterAssetService] Ignoring invalid %s animation on %s",
				stateName,
				model.Name
			)
		)
		return nil
	end
	return animation
end

local function loadAuthoredAnimation(
	model: Model,
	stateName: string,
	looped: boolean
): AnimationTrack?
	local animation = authoredAnimation(model, stateName)
	if not animation then
		return nil
	end
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		return nil
	end
	local loaded, result = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not loaded then
		warn(
			string.format(
				"[CharacterAssetService] Could not load %s animation on %s: %s",
				stateName,
				model.Name,
				tostring(result)
			)
		)
		return nil
	end
	local track = result :: AnimationTrack
	track.Looped = looped
	local played, playFailure = pcall(function()
		track:Play(0.15)
	end)
	if not played then
		warn(
			string.format(
				"[CharacterAssetService] Could not play %s animation on %s: %s",
				stateName,
				model.Name,
				tostring(playFailure)
			)
		)
		stopAnimationTrack(track)
		return nil
	end
	return track
end

local function buildProceduralMonster(monsterId: MonsterId, at: CFrame): Model
	local presentation = MONSTER_PRESENTATION[monsterId]
	local model = Instance.new("Model")
	model.Name = "ActiveMonster_" .. monsterId
	model:SetAttribute("ProceduralFallback", true)
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

	if monsterId == "BabyAlien" then
		for side = -1, 1, 2 do
			makePart(
				model,
				if side < 0 then "LeftEye" else "RightEye",
				Vector3.new(0.8, 1.25, 0.35),
				at * CFrame.new(side * 0.75, 3.4, -1.25),
				presentation.accent,
				Enum.PartType.Ball
			).Material = Enum.Material.Neon
		end
		makePart(
			model,
			"AcidSac",
			Vector3.new(2.4, 1.2, 2.4),
			at * CFrame.new(0, -1.7, 1.4),
			presentation.accent,
			Enum.PartType.Ball
		).Transparency = 0.2
	elseif monsterId == "Screamer" then
		local mouth = makePart(
			model,
			"ResonantMouth",
			Vector3.new(2.2, 1.6, 0.5),
			at * CFrame.new(0, 3.4, -1.45),
			Color3.fromRGB(24, 10, 14)
		)
		mouth.Material = Enum.Material.Neon
		for side = -1, 1, 2 do
			makePart(
				model,
				if side < 0 then "LeftSoundSpine" else "RightSoundSpine",
				Vector3.new(0.35, 4.5, 0.35),
				at
					* CFrame.new(side * 2.4, 1.2, 0)
					* CFrame.Angles(0, 0, side * 0.35),
				presentation.accent
			)
		end
	elseif monsterId == "Wendigo" then
		makePart(model, "LeftAntler", Vector3.new(0.35, 4, 0.35), at * CFrame.new(-1.5, 6, 0) * CFrame.Angles(0, 0, -0.45), presentation.accent)
		makePart(model, "RightAntler", Vector3.new(0.35, 4, 0.35), at * CFrame.new(1.5, 6, 0) * CFrame.Angles(0, 0, 0.45), presentation.accent)
		for side = -1, 1, 2 do
			makePart(
				model,
				if side < 0 then "LeftClaw" else "RightClaw",
				Vector3.new(0.45, 5.5, 0.45),
				at * CFrame.new(side * 2.1, -0.5, -0.4),
				presentation.accent
			)
		end
	elseif monsterId == "ShadowMonster" then
		for index = 1, 4 do
			local angle = (index / 4) * math.pi * 2
			local tendril = makePart(
				model,
				"ShadowTendril" .. tostring(index),
				Vector3.new(0.45, 5 + index * 0.45, 0.45),
				at
					* CFrame.new(math.cos(angle) * 2, -1.5, math.sin(angle) * 1.2)
					* CFrame.Angles(math.sin(angle) * 0.35, 0, math.cos(angle) * 0.35),
				presentation.accent
			)
			tendril.Material = Enum.Material.ForceField
			tendril.Transparency = 0.3
		end
	elseif monsterId == "Chupacabra" then
		for index = 1, 5 do
			makePart(
				model,
				"BackSpine" .. tostring(index),
				Vector3.new(0.35, 1.8, 0.7),
				at * CFrame.new(0, 1.3, -1.5 + index * 0.7),
				presentation.accent
			).Material = Enum.Material.Neon
		end
	elseif monsterId == "Dullahan" then
		local head = model:FindFirstChild("Head")
		if head then
			head:Destroy()
		end
		makePart(model, "SpectralFlame", Vector3.new(2, 2, 2), at * CFrame.new(0, torsoSize.Y / 2 + 1.4, 0), presentation.accent, Enum.PartType.Ball).Material = Enum.Material.Neon
		makePart(
			model,
			"HeadlessCollar",
			Vector3.new(3.5, 0.7, 3),
			at * CFrame.new(0, torsoSize.Y / 2, 0),
			Color3.fromRGB(24, 31, 33)
		)
	elseif monsterId == "Entity" then
		root.Transparency = 0.25
		for index = 1, 3 do
			local orb = makePart(
				model,
				"AnchorOrb" .. tostring(index),
				Vector3.new(0.9, 0.9, 0.9),
				at * CFrame.new((index - 2) * 2.4, 1 + index % 2, -0.8),
				presentation.accent,
				Enum.PartType.Ball
			)
			orb.Material = Enum.Material.ForceField
			orb.Transparency = 0.15
		end
	elseif monsterId == "Banshee" then
		root.Transparency = 0.25
		local veil = makePart(
			model,
			"SpectralVeil",
			Vector3.new(6, 6.5, 0.25),
			at * CFrame.new(0, 0.3, 1.2),
			presentation.accent
		)
		veil.Material = Enum.Material.ForceField
		veil.Transparency = 0.55
	end
	labelModel(model, MONSTER_DISPLAY_NAMES[monsterId])
	return model
end

local function buildProceduralCounselor(
	index: number,
	counselorId: string,
	displayName: string,
	at: CFrame
): Model
	local model = Instance.new("Model")
	model.Name = counselorId
	model:SetAttribute("ProceduralFallback", true)
	model:SetAttribute("CounselorIndex", index)
	model:SetAttribute("CounselorId", counselorId)
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
	if index == 1 then
		makePart(model, "FirstAidPack", Vector3.new(2.2, 2.6, 0.8), at * CFrame.new(0, 0.2, 1.6), Color3.fromRGB(180, 185, 171))
	elseif index == 2 then
		makePart(model, "RangerHat", Vector3.new(4.2, 0.35, 4.2), at * CFrame.new(0, 5.35, 0), Color3.fromRGB(72, 54, 36))
	elseif index == 3 then
		makePart(model, "Radio", Vector3.new(0.7, 1.4, 0.45), at * CFrame.new(1.8, 1, -1.1), Color3.fromRGB(34, 38, 42))
	elseif index == 4 then
		makePart(model, "Whistle", Vector3.new(0.35, 0.55, 0.35), at * CFrame.new(0.7, 1.4, -1.4), Color3.fromRGB(218, 188, 68), Enum.PartType.Ball)
	elseif index == 5 then
		makePart(model, "ToolBelt", Vector3.new(4.1, 0.55, 2.9), at * CFrame.new(0, -1.5, 0), Color3.fromRGB(82, 61, 40))
	else
		makePart(model, "FieldJournal", Vector3.new(1.4, 1.8, 0.3), at * CFrame.new(-1.7, 0.5, -1.15), Color3.fromRGB(75, 97, 72))
	end
	labelModel(model, displayName)
	return model
end

function CharacterAssetService.new(): CharacterAssetService
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
		monsterAnimationTrack = nil,
		monsterAnimationState = nil,
		counselorAnimationTracks = {},
		counselorAnimationStates = {},
	}, CharacterAssetService)
end

function CharacterAssetService:SpawnCounselors()
	for _, track in self.counselorAnimationTracks do
		stopAnimationTrack(track)
	end
	self.counselorAnimationTracks = {}
	self.counselorAnimationStates = {}
	for _, model in self.counselorModels do
		model:Destroy()
	end
	self.counselorModels = {}
	for index, definition in CounselorCatalog.GetAll() do
		local asset = findAsset("NPCs", definition.id)
			or findAsset("NPCs", "Counselor_" .. tostring(index))
		local model = if asset
			then asset:Clone()
			else buildProceduralCounselor(
				index,
				definition.id,
				definition.displayName,
				CFrame.new(-55 + (index - 1) * 22, 3, 55)
			)
		model.Name = definition.id
		model:SetAttribute("CounselorId", definition.id)
		model:SetAttribute("DisplayName", definition.displayName)
		labelModel(model, definition.displayName)
		model.Parent = self.container
		table.insert(self.counselorModels, model)
	end
end

function CharacterAssetService:ApplyCounselorSnapshot(snapshot: any)
	if type(snapshot) ~= "table" or type(snapshot.counselors) ~= "table" then
		return
	end
	for _, counselor in snapshot.counselors do
		if type(counselor) == "table" then
			local counselorId = counselor.counselorId
			if type(counselorId) == "string" then
				for _, model in self.counselorModels do
					if model:GetAttribute("CounselorId") == counselorId then
						local destinationId = counselor.destinationId
						local locationId = if
							type(destinationId) == "string"
							and destinationId ~= ""
						then destinationId
						else counselor.locationId
						local displayName = counselor.displayName
						local behavior = counselor.behavior
						if type(locationId) == "string" then
							model:SetAttribute("LocationId", locationId)
							local at = COUNSELOR_LOCATIONS[locationId]
							if at then
								model:PivotTo(at)
							end
						end
						if type(displayName) == "string" then
							model:SetAttribute("DisplayName", displayName)
						end
						if type(behavior) == "string" then
							model:SetAttribute("Behavior", behavior)
							local animationState =
								COUNSELOR_ANIMATION_BY_BEHAVIOR[behavior]
							if
								animationState
								and self.counselorAnimationStates[counselorId]
									~= animationState
							then
								stopAnimationTrack(
									self.counselorAnimationTracks[counselorId]
								)
								self.counselorAnimationTracks[counselorId] = nil
								local track = loadAuthoredAnimation(
									model,
									animationState,
									true
								)
								if track then
									self.counselorAnimationTracks[counselorId] =
										track
								end
								self.counselorAnimationStates[counselorId] =
									animationState
							end
						end
						break
					end
				end
			end
		end
	end
end

function CharacterAssetService:GetCounselorPosition(counselorId: string): Vector3?
	local model = self:GetCounselorModel(counselorId)
	if not model then
		return nil
	end
	local root = model.PrimaryPart
	return if root then root.Position else model:GetPivot().Position
end

function CharacterAssetService:GetCounselorModel(counselorId: string): Model?
	for _, model in self.counselorModels do
		if model:GetAttribute("CounselorId") == counselorId then
			return model
		end
	end
	return nil
end

function CharacterAssetService:SpawnMonster(
	monsterId: MonsterId,
	participantId: string,
	at: CFrame
): Model
	self:ClearMonster()
	local asset = findAsset("Monsters", monsterId)
	local model = if asset then asset:Clone() else buildProceduralMonster(monsterId, at)
	model.Name = "ActiveMonster_" .. monsterId
	model:SetAttribute("MonsterId", monsterId)
	model:SetAttribute("ParticipantId", participantId)
	model:PivotTo(at)
	model.Parent = self.container
	self.monsterModel = model
	self:PlayMonsterState("Transform", false)
	return model
end

function CharacterAssetService:PlayMonsterState(
	stateName: string,
	looped: boolean?
): boolean
	local model = self.monsterModel
	if
		not model
		or not APPROVED_ANIMATION_STATES[stateName]
		or self.monsterAnimationState == stateName
	then
		return false
	end
	stopAnimationTrack(self.monsterAnimationTrack)
	self.monsterAnimationTrack = loadAuthoredAnimation(
		model,
		stateName,
		looped ~= false
	)
	self.monsterAnimationState = stateName
	return self.monsterAnimationTrack ~= nil
end

function CharacterAssetService:ClearMonster()
	stopAnimationTrack(self.monsterAnimationTrack)
	self.monsterAnimationTrack = nil
	self.monsterAnimationState = nil
	if self.monsterModel then
		self.monsterModel:Destroy()
		self.monsterModel = nil
	end
end

function CharacterAssetService:Reset()
	self:ClearMonster()
	self:SpawnCounselors()
end

function CharacterAssetService:Destroy()
	self:ClearMonster()
	for _, track in self.counselorAnimationTracks do
		stopAnimationTrack(track)
	end
	self.counselorAnimationTracks = {}
	self.counselorAnimationStates = {}
	self.container:Destroy()
	self.counselorModels = {}
end

return CharacterAssetService
