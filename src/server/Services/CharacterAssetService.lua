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
	monsterTrackToken: number,
	monsterTrackPlayer: Player?,
	counselorModels: { Model },
	botCharacterModels: { [string]: Model },
	monsterAnimationTrack: AnimationTrack?,
	monsterAnimationState: string?,
	counselorAnimationTracks: { [string]: AnimationTrack },
	counselorAnimationStates: { [string]: string },
	counselorMoveTokens: { [string]: number },
	counselorMoveTargets: { [string]: string },
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

local BOT_BODY_COLORS: { [string]: Color3 } = {
	Murderer = Color3.fromRGB(110, 28, 28),
	Detective = Color3.fromRGB(28, 52, 130),
	Medic = Color3.fromRGB(30, 115, 70),
	Guard = Color3.fromRGB(95, 75, 28),
	Protector = Color3.fromRGB(72, 45, 98),
	Medium = Color3.fromRGB(62, 28, 85),
	Camper = Color3.fromRGB(55, 80, 60),
}

local BOT_SKIN_TONES: { Color3 } = {
	Color3.fromRGB(255, 218, 178),   -- very light
	Color3.fromRGB(230, 194, 153),   -- light
	Color3.fromRGB(204, 162, 121),   -- medium
	Color3.fromRGB(172, 118, 80),    -- medium-dark
	Color3.fromRGB(120, 72, 44),     -- dark
}

local function nameHash(s: string): number
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + string.byte(s, i)) % 997
	end
	return h
end

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
	local headPart = model:FindFirstChild("Head")
	local anchor: BasePart? = if headPart and headPart:IsA("BasePart")
		then headPart :: BasePart
		else model.PrimaryPart
	if not anchor then
		return
	end
	local previous = anchor:FindFirstChild("CharacterLabel")
	if previous then
		previous:Destroy()
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CharacterLabel"
	billboard.Size = UDim2.fromOffset(220, 40)
	billboard.StudsOffset = Vector3.new(0, anchor.Size.Y / 2 + 1.8, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor
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

-- Builds a humanoid-proportioned body (torso, head, arms, hands, legs, feet, face).
-- All parts are Anchored; move the whole model with Model:PivotTo().
-- Returns the invisible HumanoidRootPart which should be set as PrimaryPart.
-- Builds a classic Roblox R6-proportioned humanoid body from anchored Parts.
-- tw/th/td match standard R6: 2×2×1 torso; 1×2×1 arms and legs; 2×2×1 block head.
local function buildHumanoidBody(
	model: Model,
	at: CFrame,
	bodyColor: Color3,
	skinColor: Color3,
	scale: number
): Part
	local tw = 2 * scale   -- torso/root width
	local th = 2 * scale   -- torso/root height
	local td = 1 * scale   -- torso/root depth

	-- Invisible root (PrimaryPart) exactly overlaps the torso
	local root = makePart(model, "HumanoidRootPart", Vector3.new(tw, th, td), at, Color3.fromRGB(0, 0, 0))
	root.Transparency = 1
	makePart(model, "Torso", Vector3.new(tw, th, td), at, bodyColor)

	-- Block head — 2×2×1 like classic Roblox R6
	local hs = 2 * scale   -- head width & height (square front face)
	local hd = 1 * scale   -- head depth
	local headY = th / 2 + 0.15 * scale + hs / 2  -- small gap then head
	local headCF = at * CFrame.new(0, headY, 0)
	makePart(model, "Head", Vector3.new(hs, hs, hd), headCF, skinColor)

	-- Face features: flat blocks on the front face (–Z)
	local faceZ = -(hd / 2 + 0.05)   -- just proud of the head surface
	local eyeW  = 0.42 * scale
	local eyeH  = 0.44 * scale
	local eyeD  = 0.07 * scale
	local eyeY  = headY + 0.18 * scale
	local eyeX  = 0.40 * scale
	-- Eye whites
	makePart(model, "LeftEyeW",  Vector3.new(eyeW, eyeH, eyeD), at * CFrame.new(-eyeX, eyeY, faceZ), Color3.fromRGB(242, 242, 242))
	makePart(model, "RightEyeW", Vector3.new(eyeW, eyeH, eyeD), at * CFrame.new( eyeX, eyeY, faceZ), Color3.fromRGB(242, 242, 242))
	-- Dark pupils (sit 0.04 in front of whites so they don't z-fight)
	local pupilZ = faceZ - 0.04
	makePart(model, "LeftPupil",  Vector3.new(0.21 * scale, 0.27 * scale, eyeD), at * CFrame.new(-eyeX, eyeY - 0.03 * scale, pupilZ), Color3.fromRGB(18, 20, 90))
	makePart(model, "RightPupil", Vector3.new(0.21 * scale, 0.27 * scale, eyeD), at * CFrame.new( eyeX, eyeY - 0.03 * scale, pupilZ), Color3.fromRGB(18, 20, 90))
	-- Eyebrows
	local browColor = skinColor:Lerp(Color3.fromRGB(30, 18, 10), 0.65)
	makePart(model, "LeftBrow",  Vector3.new(eyeW * 0.9, 0.13 * scale, eyeD), at * CFrame.new(-eyeX, eyeY + eyeH / 2 + 0.10 * scale, faceZ), browColor)
	makePart(model, "RightBrow", Vector3.new(eyeW * 0.9, 0.13 * scale, eyeD), at * CFrame.new( eyeX, eyeY + eyeH / 2 + 0.10 * scale, faceZ), browColor)
	-- Mouth
	makePart(model, "Mouth", Vector3.new(0.62 * scale, 0.16 * scale, eyeD), at * CFrame.new(0, headY - 0.42 * scale, faceZ), Color3.fromRGB(95, 42, 42))

	-- Arms: R6 1×2×1, shirt-colored, flush with torso sides
	local aw = 1 * scale
	local ah = 2 * scale
	local ax = tw / 2 + aw / 2   -- = 1.5 * scale
	makePart(model, "LeftArm",  Vector3.new(aw, ah, aw), at * CFrame.new(-ax, 0, 0), bodyColor)
	makePart(model, "RightArm", Vector3.new(aw, ah, aw), at * CFrame.new( ax, 0, 0), bodyColor)
	-- Skin-colored lower cuff on each arm
	local cuffH = 0.35 * scale
	local cuffY = -(ah / 2 - cuffH / 2)
	makePart(model, "LeftCuff",  Vector3.new(aw, cuffH, aw), at * CFrame.new(-ax, cuffY, 0), skinColor)
	makePart(model, "RightCuff", Vector3.new(aw, cuffH, aw), at * CFrame.new( ax, cuffY, 0), skinColor)

	-- Legs: R6 1×2×1, pants-colored (slightly darker body)
	local lw = 1 * scale
	local lh = 2 * scale
	local lx = 0.5 * scale
	local ly = -(th / 2 + lh / 2)
	local pantsColor = bodyColor:Lerp(Color3.fromRGB(10, 10, 15), 0.18)
	makePart(model, "LeftLeg",  Vector3.new(lw, lh, lw), at * CFrame.new(-lx, ly, 0), pantsColor)
	makePart(model, "RightLeg", Vector3.new(lw, lh, lw), at * CFrame.new( lx, ly, 0), pantsColor)

	return root
end

local function buildProceduralMonster(monsterId: MonsterId, at: CFrame): Model
	local presentation = MONSTER_PRESENTATION[monsterId]
	local model = Instance.new("Model")
	model.Name = "ActiveMonster_" .. monsterId
	model:SetAttribute("ProceduralFallback", true)
	model:SetAttribute("MonsterId", monsterId)

	local sc = presentation.scale
	local torsoSize = Vector3.new(4, 5, 3) * sc
	local headSize = Vector3.new(3.2, 3.2, 3.2) * sc
	local headY = torsoSize.Y / 2 + 1.6
	local root = makePart(model, "Root", torsoSize, at, presentation.color)
	model.PrimaryPart = root
	makePart(model, "Head", headSize, at * CFrame.new(0, headY, 0), presentation.accent, presentation.headShape)

	-- Glowing eyes on all monsters that have heads (BabyAlien handles its own below)
	if monsterId ~= "Dullahan" and monsterId ~= "BabyAlien" then
		local eS = Vector3.new(0.55, 0.65, 0.38) * sc
		local eX, eY, eZ = 0.62 * sc, headY + 0.1 * sc, -(headSize.Z / 2 + 0.06)
		local lg = makePart(model, "LeftGlow", eS, at * CFrame.new(-eX, eY, eZ), presentation.accent, Enum.PartType.Ball)
		lg.Material = Enum.Material.Neon
		local rg = makePart(model, "RightGlow", eS, at * CFrame.new(eX, eY, eZ), presentation.accent, Enum.PartType.Ball)
		rg.Material = Enum.Material.Neon
	end

	-- Elongated creature limbs (all monsters)
	local limbLen = 4.2 * sc
	local limbW = 0.58 * sc
	makePart(model, "LeftLimb", Vector3.new(limbW, limbLen, limbW),
		at * CFrame.new(-(torsoSize.X / 2 + limbLen * 0.16), -0.5 * sc, 0) * CFrame.Angles(0, 0, 0.42), presentation.accent)
	makePart(model, "RightLimb", Vector3.new(limbW, limbLen, limbW),
		at * CFrame.new(torsoSize.X / 2 + limbLen * 0.16, -0.5 * sc, 0) * CFrame.Angles(0, 0, -0.42), presentation.accent)

	if monsterId == "BabyAlien" then
		for side = -1, 1, 2 do
			makePart(model, if side < 0 then "LeftEye" else "RightEye",
				Vector3.new(0.8, 1.25, 0.35),
				at * CFrame.new(side * 0.75, headY + 0.35, -(headSize.Z / 2)),
				presentation.accent, Enum.PartType.Ball).Material = Enum.Material.Neon
		end
		makePart(model, "AcidSac", Vector3.new(2.4, 1.2, 2.4), at * CFrame.new(0, -1.7, 1.4), presentation.accent, Enum.PartType.Ball).Transparency = 0.2
		-- 4 spider legs radiating from the base
		for i = 0, 3 do
			local angle = (i / 4) * math.pi * 2 + math.pi / 4
			makePart(model, "SpiderLeg" .. tostring(i + 1), Vector3.new(0.32, 2.6 * sc, 0.32),
				at * CFrame.new(math.cos(angle) * 2.2 * sc, -(torsoSize.Y / 2 + 0.8 * sc), math.sin(angle) * 2.2 * sc)
					* CFrame.Angles(math.cos(angle) * 0.5, 0, math.sin(angle) * 0.5), presentation.accent)
		end
	elseif monsterId == "Screamer" then
		local mouth = makePart(model, "ResonantMouth", Vector3.new(2.2, 1.6, 0.5),
			at * CFrame.new(0, headY, -(headSize.Z / 2 + 0.06)), Color3.fromRGB(24, 10, 14))
		mouth.Material = Enum.Material.Neon
		for side = -1, 1, 2 do
			makePart(model, if side < 0 then "LeftSoundSpine" else "RightSoundSpine",
				Vector3.new(0.35, 4.5, 0.35),
				at * CFrame.new(side * 2.4, 1.2, 0) * CFrame.Angles(0, 0, side * 0.35), presentation.accent)
		end
		for side = -1, 1, 2 do
			makePart(model, if side < 0 then "LeftLeg" else "RightLeg",
				Vector3.new(0.52, 3.4 * sc, 0.52),
				at * CFrame.new(side * sc, -(torsoSize.Y / 2 + 1.4 * sc), 0) * CFrame.Angles(0, 0, side * 0.12),
				presentation.accent)
		end
	elseif monsterId == "Wendigo" then
		makePart(model, "LeftAntler", Vector3.new(0.35, 4, 0.35), at * CFrame.new(-1.5, headY + 1.6, 0) * CFrame.Angles(0, 0, -0.45), presentation.accent)
		makePart(model, "RightAntler", Vector3.new(0.35, 4, 0.35), at * CFrame.new(1.5, headY + 1.6, 0) * CFrame.Angles(0, 0, 0.45), presentation.accent)
		for side = -1, 1, 2 do
			makePart(model, if side < 0 then "LeftClaw" else "RightClaw",
				Vector3.new(0.45, 5.5, 0.45), at * CFrame.new(side * 2.1, -0.5, -0.4), presentation.accent)
		end
		for side = -1, 1, 2 do
			makePart(model, if side < 0 then "LeftLeg" else "RightLeg",
				Vector3.new(0.68, 4.2 * sc, 0.68),
				at * CFrame.new(side * sc, -(torsoSize.Y / 2 + 1.7 * sc), 0), presentation.accent)
		end
	elseif monsterId == "ShadowMonster" then
		for index = 1, 4 do
			local angle = (index / 4) * math.pi * 2
			local tendril = makePart(model, "ShadowTendril" .. tostring(index),
				Vector3.new(0.45, 5 + index * 0.45, 0.45),
				at * CFrame.new(math.cos(angle) * 2, -1.5, math.sin(angle) * 1.2)
					* CFrame.Angles(math.sin(angle) * 0.35, 0, math.cos(angle) * 0.35), presentation.accent)
			tendril.Material = Enum.Material.ForceField
			tendril.Transparency = 0.3
		end
		-- Extra lower tendrils that act as floating legs
		for index = 1, 3 do
			local angle = ((index - 1) / 3) * math.pi * 2
			local leg = makePart(model, "ShadowLeg" .. tostring(index),
				Vector3.new(0.35, 3.5 * sc, 0.35),
				at * CFrame.new(math.cos(angle) * 1.5, -(torsoSize.Y / 2 + 1.2 * sc), math.sin(angle) * 1.5)
					* CFrame.Angles(math.cos(angle) * 0.3, 0, math.sin(angle) * 0.3), presentation.accent)
			leg.Material = Enum.Material.ForceField
			leg.Transparency = 0.5
		end
	elseif monsterId == "Chupacabra" then
		for index = 1, 5 do
			makePart(model, "BackSpine" .. tostring(index),
				Vector3.new(0.35, 1.8, 0.7),
				at * CFrame.new(0, 1.3, -1.5 + index * 0.7), presentation.accent).Material = Enum.Material.Neon
		end
		for side = -1, 1, 2 do
			for fore = -1, 1, 2 do
				local tag = (if side < 0 then "Left" else "Right") .. (if fore < 0 then "Front" else "Back")
				makePart(model, tag .. "Leg", Vector3.new(0.58, 2.6 * sc, 0.58),
					at * CFrame.new(side * 1.4 * sc, -(torsoSize.Y / 2 + 0.7 * sc), fore * 0.9 * sc)
						* CFrame.Angles(fore * 0.28, 0, side * 0.1), presentation.accent)
			end
		end
	elseif monsterId == "Dullahan" then
		local head = model:FindFirstChild("Head")
		if head then
			head:Destroy()
		end
		local flame = makePart(model, "SpectralFlame", Vector3.new(2, 2, 2),
			at * CFrame.new(0, torsoSize.Y / 2 + 1.4, 0), presentation.accent, Enum.PartType.Ball)
		flame.Material = Enum.Material.Neon
		makePart(model, "HeadlessCollar", Vector3.new(3.5, 0.7, 3),
			at * CFrame.new(0, torsoSize.Y / 2, 0), Color3.fromRGB(24, 31, 33))
		for side = -1, 1, 2 do
			makePart(model, if side < 0 then "LeftLeg" else "RightLeg",
				Vector3.new(0.88, 3.6 * sc, 0.88),
				at * CFrame.new(side * sc, -(torsoSize.Y / 2 + 1.45 * sc), 0), presentation.color)
		end
	elseif monsterId == "Entity" then
		root.Transparency = 0.25
		for index = 1, 3 do
			local orb = makePart(model, "AnchorOrb" .. tostring(index),
				Vector3.new(0.9, 0.9, 0.9),
				at * CFrame.new((index - 2) * 2.4, 1 + index % 2, -0.8), presentation.accent, Enum.PartType.Ball)
			orb.Material = Enum.Material.ForceField
			orb.Transparency = 0.15
		end
		-- 3 ethereal trailing streams at the base
		for index = 1, 3 do
			local angle = ((index - 1) / 3) * math.pi * 2
			local stream = makePart(model, "EtherStream" .. tostring(index),
				Vector3.new(0.28, 3.2 * sc, 0.28),
				at * CFrame.new(math.cos(angle) * 1.2, -(torsoSize.Y / 2 + sc), math.sin(angle) * 1.2)
					* CFrame.Angles(math.cos(angle) * 0.2, 0, math.sin(angle) * 0.2), presentation.accent)
			stream.Material = Enum.Material.ForceField
			stream.Transparency = 0.4
		end
	elseif monsterId == "Banshee" then
		root.Transparency = 0.25
		local veil = makePart(model, "SpectralVeil", Vector3.new(6, 6.5, 0.25),
			at * CFrame.new(0, 0.3, 1.2), presentation.accent)
		veil.Material = Enum.Material.ForceField
		veil.Transparency = 0.55
		-- Trailing wail streams
		for index = 1, 3 do
			local offset = (index - 2) * 1.8 * sc
			local stream = makePart(model, "WailStream" .. tostring(index),
				Vector3.new(0.3, 4.0 * sc, 0.3),
				at * CFrame.new(offset, -(torsoSize.Y / 2 + 1.2 * sc), 0.4)
					* CFrame.Angles(0.15, 0, (index - 2) * 0.08), presentation.accent)
			stream.Material = Enum.Material.ForceField
			stream.Transparency = 0.5
		end
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

	local scale = 1.08 + ((index - 1) % 3) * 0.08
	local colorIdx = ((index - 1) % #COUNSELOR_COLORS) + 1
	local bodyColor = COUNSELOR_COLORS[colorIdx]
	local skinR = math.max(150, 196 - index * 5)
	local skinG = math.max(100, 155 - index * 6)
	local skinB = math.max(85, 125 - index * 4)
	local skinColor = Color3.fromRGB(skinR, skinG, skinB)

	local root = buildHumanoidBody(model, at, bodyColor, skinColor, scale)
	model.PrimaryPart = root

	-- Match the R6 dims used inside buildHumanoidBody
	local th = 2 * scale
	local td = 1 * scale
	local hs = 2 * scale
	local headY = th / 2 + 0.15 * scale + hs / 2
	local aw = 1 * scale
	local ax = scale + aw / 2   -- tw/2 + aw/2 = scale + 0.5*scale

	if index == 1 then
		-- Medical pack on front of torso with red cross
		makePart(model, "FirstAidPack", Vector3.new(2.0 * scale * 0.8, th * 0.5, 0.45),
			at * CFrame.new(0, 0.1, -(td / 2 + 0.24)), Color3.fromRGB(180, 185, 171))
		makePart(model, "CrossH", Vector3.new(2.0 * scale * 0.4, 0.18, 0.1),
			at * CFrame.new(0, 0.3, -(td / 2 + 0.5)), Color3.fromRGB(210, 48, 48))
		makePart(model, "CrossV", Vector3.new(0.18, th * 0.28, 0.1),
			at * CFrame.new(0, 0.3, -(td / 2 + 0.5)), Color3.fromRGB(210, 48, 48))
	elseif index == 2 then
		-- Ranger hat
		local hatBrimY = headY + hs / 2 + 0.15
		makePart(model, "RangerBrim", Vector3.new(hs * 1.75, 0.26, hs * 1.75),
			at * CFrame.new(0, hatBrimY, 0), Color3.fromRGB(72, 54, 36))
		makePart(model, "RangerCrown", Vector3.new(hs * 1.1, hs * 0.6, hs * 1.1),
			at * CFrame.new(0, hatBrimY + hs * 0.43, 0), Color3.fromRGB(82, 62, 42))
	elseif index == 3 then
		-- Radio on right side
		makePart(model, "Radio", Vector3.new(0.55, scale, 0.35),
			at * CFrame.new(ax + 0.26, 0.3 * scale, -(td / 2 + 0.09)), Color3.fromRGB(34, 38, 42))
		makePart(model, "RadioAntenna", Vector3.new(0.09, 0.75 * scale, 0.09),
			at * CFrame.new(ax + 0.46, 0.9 * scale, -(td / 2 + 0.09)), Color3.fromRGB(55, 60, 65))
	elseif index == 4 then
		-- Lanyard + whistle
		makePart(model, "Lanyard", Vector3.new(0.1, 1.5 * scale, 0.08),
			at * CFrame.new(0, 0.1, -(td / 2 + 0.05)), Color3.fromRGB(218, 188, 68))
		makePart(model, "Whistle", Vector3.new(0.32, 0.46, 0.32),
			at * CFrame.new(0, -(th / 2 - 0.45), -(td / 2 + 0.28)), Color3.fromRGB(218, 188, 68), Enum.PartType.Ball)
	elseif index == 5 then
		-- Tool belt across waist
		makePart(model, "ToolBelt", Vector3.new(2 * scale * 1.06, 0.42, td * 1.08),
			at * CFrame.new(0, -(th / 2 - 0.2), 0), Color3.fromRGB(82, 61, 40))
		for i = -1, 1 do
			if i ~= 0 then
				makePart(model, "ToolPouch" .. tostring(i + 2), Vector3.new(0.42, 0.66, 0.32),
					at * CFrame.new(i * 0.6 * scale, -(th / 2 - 0.52), -(td / 2 + 0.17)), Color3.fromRGB(70, 52, 32))
			end
		end
	else
		-- Field journal tucked under left arm
		makePart(model, "FieldJournal", Vector3.new(1.15 * scale, 1.5 * scale, 0.26),
			at * CFrame.new(-(ax + 0.12), 0.0, -(td / 2 + 0.13)), Color3.fromRGB(75, 97, 72))
		makePart(model, "Bookmark", Vector3.new(0.12, 0.55 * scale, 0.08),
			at * CFrame.new(-(ax + 0.04), -(0.55 * scale), -(td / 2 + 0.13)), Color3.fromRGB(160, 48, 48))
	end

	labelModel(model, displayName)
	return model
end

local function buildProceduralBotCharacter(
	displayName: string,
	roleName: string?,
	at: CFrame,
	colorIndex: number
): Model
	local model = Instance.new("Model")
	model.Name = "BotCharacter"
	model:SetAttribute("ProceduralFallback", true)
	model:SetAttribute("BotDisplayName", displayName)

	local bodyColor = if roleName then (BOT_BODY_COLORS[roleName] or Color3.fromRGB(55, 75, 65))
		else COUNSELOR_COLORS[((colorIndex - 1) % #COUNSELOR_COLORS) + 1]
	local skinColor = BOT_SKIN_TONES[(nameHash(displayName) % #BOT_SKIN_TONES) + 1]
	-- Slight height variation so bots look like a crowd of different players
	local h = nameHash(displayName)
	local scale = 0.94 + (h % 17) * 0.01   -- range ~0.94–1.10

	local root = buildHumanoidBody(model, at, bodyColor, skinColor, scale)
	model.PrimaryPart = root

	-- Glowing role badge on chest so bots are visually distinct
	local td = 1 * scale   -- matches buildHumanoidBody R6 depth
	local th = 2 * scale   -- matches buildHumanoidBody R6 height
	local badgeColor = BOT_BODY_COLORS[roleName or ""] or Color3.fromRGB(180, 180, 180)
	local badge = makePart(model, "RoleBadge", Vector3.new(0.65, 0.65, 0.1),
		at * CFrame.new(0.42, th / 2 - 0.45, -(td / 2 + 0.06)), badgeColor)
	badge.Material = Enum.Material.Neon
	-- Short role label on badge face (SurfaceGui)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 80
	sg.Parent = badge
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = string.upper(string.sub(roleName or "?", 1, 1))
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Parent = sg

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
		monsterTrackToken = 0,
		monsterTrackPlayer = nil,
		counselorModels = {},
		botCharacterModels = {},
		monsterAnimationTrack = nil,
		monsterAnimationState = nil,
		counselorAnimationTracks = {},
		counselorAnimationStates = {},
		counselorMoveTokens = {},
		counselorMoveTargets = {},
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
		local primaryPart = model.PrimaryPart
		if primaryPart and primaryPart:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = definition.displayName
			prompt.ObjectText = "Talk"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("CounselorId", definition.id)
			prompt.Parent = primaryPart
		end
		-- Start idle pacing so counselors feel alive in the world
		self:_startCounselorIdlePace(definition.id, model)
	end
end

-- Makes a counselor shuffle in a tiny radius around their spawn/location.
-- Stops automatically when a location-change move fires (token increments).
function CharacterAssetService:_startCounselorIdlePace(counselorId: string, model: Model)
	task.spawn(function()
		task.wait(math.random() * 4)   -- stagger start so they don't all move together
		local PACE_RADIUS = 1.2
		local MIN_WAIT = 3.0
		local MAX_WAIT = 7.0
		while model.Parent ~= nil do
			local tokenBefore = self.counselorMoveTokens[counselorId] or 0
			task.wait(MIN_WAIT + math.random() * (MAX_WAIT - MIN_WAIT))
			if model.Parent == nil then
				break
			end
			if (self.counselorMoveTokens[counselorId] or 0) == tokenBefore then
				local center = model:GetPivot()
				local angle = math.random() * math.pi * 2
				local r = 0.4 + math.random() * PACE_RADIUS
				local target = center * CFrame.new(math.cos(angle) * r, 0, math.sin(angle) * r)
				self:_smoothPivotCounselor(counselorId, model, target, 1.6)
			end
		end
	end)
end

function CharacterAssetService:_smoothPivotCounselor(
	counselorId: string,
	model: Model,
	target: CFrame,
	duration: number
)
	local token = (self.counselorMoveTokens[counselorId] or 0) + 1
	self.counselorMoveTokens[counselorId] = token
	task.spawn(function()
		local start = model:GetPivot()
		local began = os.clock()
		while self.counselorMoveTokens[counselorId] == token do
			local elapsed = os.clock() - began
			if elapsed >= duration then
				model:PivotTo(target)
				break
			end
			local t = elapsed / duration
			t = 1 - (1 - t) ^ 3
			model:PivotTo(start:Lerp(target, t))
			task.wait()
		end
	end)
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
								local isThreat = type(destinationId) == "string"
									and destinationId ~= ""
								if
									isThreat
									and self.counselorMoveTargets[counselorId]
										~= locationId
								then
									self.counselorMoveTargets[counselorId] = locationId
									self:_smoothPivotCounselor(counselorId, model, at, 3)
								elseif not isThreat then
									local tok = (self.counselorMoveTokens[counselorId] or 0) + 1
									self.counselorMoveTokens[counselorId] = tok
									self.counselorMoveTargets[counselorId] = locationId
									model:PivotTo(at)
								end
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
	self.monsterTrackPlayer = nil
	self:StopMonsterTracking()
	stopAnimationTrack(self.monsterAnimationTrack)
	self.monsterAnimationTrack = nil
	self.monsterAnimationState = nil
	if self.monsterModel then
		self.monsterModel:Destroy()
		self.monsterModel = nil
	end
end

function CharacterAssetService:StopMonsterTracking()
	self.monsterTrackToken = self.monsterTrackToken + 1
end

-- Briefly lunges the monster model toward a world position then resumes orbit tracking.
function CharacterAssetService:LungeMonsterToward(targetPosition: Vector3)
	local model = self.monsterModel
	if not model then
		return
	end
	local resumePlayer = self.monsterTrackPlayer
	self:StopMonsterTracking()
	task.spawn(function()
		local STEPS = 8
		local STEP_TIME = 0.05
		local current = model:GetPivot()
		local lungePos = current.Position:Lerp(targetPosition, 0.55)
		local lookDir = Vector3.new(
			targetPosition.X - current.Position.X,
			0,
			targetPosition.Z - current.Position.Z
		)
		local lungeTarget = if lookDir.Magnitude > 0.05
			then CFrame.lookAt(lungePos, lungePos + lookDir.Unit)
			else CFrame.new(lungePos)
		for i = 1, STEPS do
			local t = i / STEPS
			model:PivotTo(current:Lerp(lungeTarget, t * t))
			task.wait(STEP_TIME)
		end
		if resumePlayer then
			self:StartMonsterTracking(resumePlayer)
		end
	end)
end

-- Starts a loop that moves the monster model to orbit near the murderer's character.
-- The monster slowly circles the murderer for an atmospheric stalking effect.
function CharacterAssetService:StartMonsterTracking(murdererPlayer: Player)
	self.monsterTrackPlayer = murdererPlayer
	local token = self.monsterTrackToken + 1
	self.monsterTrackToken = token
	task.spawn(function()
		local TICK = 0.08
		local LERP_T = 0.05
		local ORBIT_RADIUS = 7
		local orbitAngle = 0
		while self.monsterTrackToken == token do
			local model = self.monsterModel
			if not model then
				break
			end
			local char = murdererPlayer.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					orbitAngle = orbitAngle + TICK * 0.25
					local offset = Vector3.new(
						math.cos(orbitAngle) * ORBIT_RADIUS,
						0,
						math.sin(orbitAngle) * ORBIT_RADIUS
					)
					local targetPos = hrp.Position + offset
					local current = model:GetPivot()
					local newPos = current.Position:Lerp(targetPos, LERP_T)
					local lookDir = Vector3.new(
						hrp.Position.X - newPos.X,
						0,
						hrp.Position.Z - newPos.Z
					)
					if lookDir.Magnitude > 0.05 then
						model:PivotTo(CFrame.lookAt(newPos, newPos + lookDir.Unit))
					else
						model:PivotTo(current - current.Position + newPos)
					end
				end
			end
			task.wait(TICK)
		end
	end)
end

function CharacterAssetService:Reset()
	self:ClearMonster()
	self:ClearBotCharacters()
	self:SpawnCounselors()
end

function CharacterAssetService:Destroy()
	self:ClearMonster()
	self:ClearBotCharacters()
	for _, track in self.counselorAnimationTracks do
		stopAnimationTrack(track)
	end
	self.counselorAnimationTracks = {}
	self.counselorAnimationStates = {}
	self.container:Destroy()
	self.counselorModels = {}
end

function CharacterAssetService:SpawnBotCharacter(
	participantId: string,
	displayName: string,
	roleName: string?,
	at: CFrame
): Model
	self:ClearBotCharacter(participantId)
	local colorIndex = 0
	for _ in self.botCharacterModels do
		colorIndex += 1
	end
	local asset = findAsset("BotCharacters", participantId)
		or findAsset("BotCharacters", roleName or "")
	local model = if asset
		then asset:Clone()
		else buildProceduralBotCharacter(displayName, roleName, at, colorIndex + 1)
	model.Name = "BotCharacter_" .. participantId
	model:SetAttribute("ParticipantId", participantId)
	model:SetAttribute("RoleName", roleName or "")
	model:PivotTo(at)
	model.Parent = self.container
	self.botCharacterModels[participantId] = model
	return model
end

function CharacterAssetService:ClearBotCharacter(participantId: string)
	local model = self.botCharacterModels[participantId]
	if model then
		model:Destroy()
		self.botCharacterModels[participantId] = nil
	end
end

-- Attaches a neon red indicator on the bot so observers know it was hurt.
function CharacterAssetService:ShowBotInjured(participantId: string)
	local model = self.botCharacterModels[participantId]
	if not model then
		return
	end
	local existing = model:FindFirstChild("InjuryIndicator")
	if existing then
		existing:Destroy()
	end
	local root = model.PrimaryPart
	if not root then
		return
	end
	local ind = makePart(
		model,
		"InjuryIndicator",
		Vector3.new(0.5, 0.5, 0.5),
		root.CFrame * CFrame.new(0, 1.4, 0),
		Color3.fromRGB(210, 25, 25),
		Enum.PartType.Ball
	)
	ind.Material = Enum.Material.Neon
	ind.Transparency = 0.25
end

-- Plays a fall-and-fade death animation for a bot character then removes its model.
function CharacterAssetService:PlayBotDeath(participantId: string)
	local model = self.botCharacterModels[participantId]
	if not model then
		return
	end
	-- Cancel any movement so the bot stops where it is
	local token = (self.counselorMoveTokens[participantId] or 0) + 1
	self.counselorMoveTokens[participantId] = token
	task.spawn(function()
		-- Fall over: tilt 90° sideways over 0.5s
		local startCF = model:GetPivot()
		local fallCF = startCF * CFrame.Angles(0, 0, math.pi / 2)
		local FALL_STEPS = 12
		for i = 1, FALL_STEPS do
			if self.counselorMoveTokens[participantId] ~= token or model.Parent == nil then
				return
			end
			model:PivotTo(startCF:Lerp(fallCF, i / FALL_STEPS))
			task.wait(0.5 / FALL_STEPS)
		end
		-- Brief pause lying down
		task.wait(0.4)
		-- Fade out with parts turning dark red
		local FADE_STEPS = 18
		local deadColor = Color3.fromRGB(60, 10, 10)
		for i = 1, FADE_STEPS do
			if model.Parent == nil then
				return
			end
			local alpha = i / FADE_STEPS
			for _, desc in model:GetDescendants() do
				if desc:IsA("BasePart") then
					desc.Color = desc.Color:Lerp(deadColor, alpha * 0.5)
					desc.Transparency = alpha
				end
			end
			task.wait(1.2 / FADE_STEPS)
		end
		self:ClearBotCharacter(participantId)
	end)
end

function CharacterAssetService:ClearBotCharacters()
	for _, model in self.botCharacterModels do
		model:Destroy()
	end
	self.botCharacterModels = {}
end

function CharacterAssetService:GetBotCharacterPosition(participantId: string): Vector3?
	local model = self.botCharacterModels[participantId]
	if not model then
		return nil
	end
	local primary = model.PrimaryPart
	return if primary then primary.Position else model:GetPivot().Position
end

-- Starts a loop that makes a bot character wander randomly near their current position.
-- Yields between steps; skips a step if a real action fired during the wait.
function CharacterAssetService:StartBotIdleWander(participantId: string)
	local RADIUS = 5
	local MIN_PAUSE = 2.5
	local MAX_PAUSE = 5.5
	task.spawn(function()
		task.wait(1 + math.random() * 2)
		while self.botCharacterModels[participantId] do
			local tokenBefore = self.counselorMoveTokens[participantId] or 0
			task.wait(MIN_PAUSE + math.random() * (MAX_PAUSE - MIN_PAUSE))
			if not self.botCharacterModels[participantId] then
				break
			end
			if (self.counselorMoveTokens[participantId] or 0) == tokenBefore then
				local center = self:GetBotCharacterPosition(participantId)
				if center then
					local angle = math.random() * math.pi * 2
					local radius = 1 + math.random() * RADIUS
					local target = center
						+ Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
					self:MoveBotCharacterToward(participantId, target, 1.4 + math.random() * 0.6)
				end
			end
		end
	end)
end

function CharacterAssetService:MoveBotCharacterToward(
	participantId: string,
	targetPosition: Vector3,
	duration: number?
)
	local model = self.botCharacterModels[participantId]
	if not model then
		return
	end
	local resolved = duration or 2.2
	local current = model:GetPivot()
	local dx = targetPosition.X - current.X
	local dz = targetPosition.Z - current.Z
	local targetCFrame = CFrame.new(targetPosition.X, current.Y, targetPosition.Z)
		* CFrame.Angles(0, math.atan2(-dx, -dz), 0)
	local token = (self.counselorMoveTokens[participantId] or 0) + 1
	self.counselorMoveTokens[participantId] = token
	task.spawn(function()
		local start = model:GetPivot()
		local began = os.clock()
		while self.counselorMoveTokens[participantId] == token do
			local elapsed = os.clock() - began
			if elapsed >= resolved then
				model:PivotTo(targetCFrame)
				break
			end
			local t = 1 - (1 - elapsed / resolved) ^ 2
			model:PivotTo(start:Lerp(targetCFrame, t))
			task.wait()
		end
	end)
end

return CharacterAssetService
