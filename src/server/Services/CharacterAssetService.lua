--!strict

local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CounselorCatalog = require(
	script.Parent.Parent.Config:WaitForChild("CounselorCatalog")
)
local MonsterAudioDefaults = require(
	script.Parent.Parent.Config:WaitForChild("MonsterAudioDefaults")
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
	botHomePositions: { [string]: Vector3 },
	monsterAnimationTrack: AnimationTrack?,
	monsterAnimationState: string?,
	counselorAnimationTracks: { [string]: AnimationTrack },
	counselorAnimationStates: { [string]: string },
	counselorMoveTokens: { [string]: number },
	counselorMoveTargets: { [string]: string },
	bodyMarkers: { [string]: Model },
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
		-- Pink fleshy silicone body, large dark eyes (reference: alien baby crawling)
		color = Color3.fromRGB(215, 158, 135),
		accent = Color3.fromRGB(22, 16, 20),
		scale = Vector3.new(0.8, 0.55, 1.25),
		headShape = Enum.PartType.Ball,
	},
	Screamer = {
		-- Bone-ash pale humanoid with hollow dark maw (reference: gaunt clawed figure)
		color = Color3.fromRGB(188, 175, 160),
		accent = Color3.fromRGB(28, 14, 12),
		scale = Vector3.new(1, 1.25, 0.9),
		headShape = Enum.PartType.Block,
	},
	Wendigo = {
		-- Dark earth brown, bone antler accent (reference: deer skull + root body)
		color = Color3.fromRGB(80, 62, 44),
		accent = Color3.fromRGB(195, 172, 125),
		scale = Vector3.new(0.9, 1.65, 0.85),
		headShape = Enum.PartType.Ball,
	},
	ShadowMonster = {
		-- Near-black silhouette with deep purple aura (reference: shadow people infographic)
		color = Color3.fromRGB(18, 20, 32),
		accent = Color3.fromRGB(112, 95, 178),
		scale = Vector3.new(1.15, 1.45, 0.8),
		headShape = Enum.PartType.Ball,
	},
	Chupacabra = {
		-- Dark grey-brown with blood-red spine accents (reference: parchment spiny creature)
		color = Color3.fromRGB(66, 52, 56),
		accent = Color3.fromRGB(145, 40, 52),
		scale = Vector3.new(1.1, 0.75, 1.35),
		headShape = Enum.PartType.Block,
	},
	Dullahan = {
		-- Near-black cloak with spectral teal glow (reference: headless hooded figure)
		color = Color3.fromRGB(18, 22, 26),
		accent = Color3.fromRGB(52, 168, 178),
		scale = Vector3.new(1.15, 1.55, 1),
		headShape = Enum.PartType.Block,
	},
	Entity = {
		-- Deep ocean blue with bioluminescent light (reference: Cthulhu/octopus ink art)
		color = Color3.fromRGB(52, 65, 108),
		accent = Color3.fromRGB(108, 198, 248),
		scale = Vector3.new(0.85, 1.4, 0.8),
		headShape = Enum.PartType.Ball,
	},
	Banshee = {
		-- Silver-white spectral with icy ethereal glow (reference: wailing ghostly woman)
		color = Color3.fromRGB(185, 188, 205),
		accent = Color3.fromRGB(232, 242, 255),
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
	Color3.fromRGB(55, 62, 72),      -- dark authority slate   (Holloway  – Director)
	Color3.fromRGB(192, 190, 192),   -- clinical white-grey    (Ortiz     – Health & Safety)
	Color3.fromRGB(155, 118, 58),    -- warm khaki/trail tan   (Reed      – Outdoor Skills)
	Color3.fromRGB(168, 88, 65),     -- terracotta/rust        (Brooks    – Arts & Activities)
	Color3.fromRGB(62, 128, 78),     -- forest green           (Chen      – Nature & Science)
	Color3.fromRGB(22, 22, 26),      -- near-black             (Finch     – Contractor)
}

local BOT_BODY_COLORS: { [string]: Color3 } = {
	Murderer  = Color3.fromRGB(110, 28, 28),
	Detective = Color3.fromRGB(28, 52, 130),
	Medic     = Color3.fromRGB(30, 115, 70),
	Guard     = Color3.fromRGB(95, 75, 28),
	Protector = Color3.fromRGB(72, 45, 98),
	Medium    = Color3.fromRGB(62, 28, 85),
}

-- Varied outfit palette for Camper-role bots, cycling by display name hash.
-- Colors drawn from the 12 reference camper images.
local CAMPER_OUTFIT_PALETTE: { Color3 } = {
	Color3.fromRGB(45,  160, 150),   -- teal/mint        (classic girl camper)
	Color3.fromRGB(205, 108, 148),   -- rose pink        (glitter bow girl)
	Color3.fromRGB(182,  72, 102),   -- deep Roblox pink (crop-top girl)
	Color3.fromRGB(68,  105, 168),   -- denim blue       (overalls girl)
	Color3.fromRGB(228, 232, 218),   -- white/sage       (frog-hoodie girl)
	Color3.fromRGB(145,  90,  58),   -- warm brown       (cat-onesie girl)
	Color3.fromRGB(218, 222, 228),   -- white jacket     (axolotl boy)
	Color3.fromRGB(202, 142,  42),   -- orange-yellow    (tactical vest boy)
	Color3.fromRGB(78,  108, 165),   -- plaid blue       (flannel headphones boy)
	Color3.fromRGB(68,  132,  68),   -- hoodie green     (backwards-cap boy)
	Color3.fromRGB(88,  158,  55),   -- creeper green    (Minecraft boy)
	Color3.fromRGB(45,   50,  68),   -- dark charcoal    (holographic visor boy)
}

local BOT_SKIN_TONES: { Color3 } = {
	Color3.fromRGB(255, 218, 178),   -- very light
	Color3.fromRGB(230, 194, 153),   -- light
	Color3.fromRGB(204, 162, 121),   -- medium
	Color3.fromRGB(172, 118, 80),    -- medium-dark
	Color3.fromRGB(120, 72, 44),     -- dark
}

local HAIR_COLORS: { Color3 } = {
	Color3.fromRGB(18, 12, 8),       -- black
	Color3.fromRGB(65, 40, 20),      -- dark brown
	Color3.fromRGB(110, 68, 28),     -- brown
	Color3.fromRGB(158, 110, 44),    -- golden brown
	Color3.fromRGB(200, 158, 76),    -- dirty blonde
	Color3.fromRGB(220, 206, 148),   -- blonde
	Color3.fromRGB(140, 36, 36),     -- auburn
	Color3.fromRGB(168, 168, 168),   -- grey
	Color3.fromRGB(218, 148, 178),   -- light pink  (glitter-bow camper reference)
	Color3.fromRGB(118, 162, 125),   -- sage green  (bucket-hat camper reference)
}

-- Shared with CharacterService so real players draw from the same camper
-- visual language as the procedural bots.
CharacterAssetService.CamperOutfitPalette = CAMPER_OUTFIT_PALETTE
CharacterAssetService.BotSkinTones = BOT_SKIN_TONES
CharacterAssetService.HairColors = HAIR_COLORS

local EYE_COLORS: { Color3 } = {
	Color3.fromRGB(18,  20,  90),   -- deep blue
	Color3.fromRGB(24,  72,  30),   -- dark green
	Color3.fromRGB(85,  48,  20),   -- warm brown
	Color3.fromRGB(45,  90, 140),   -- steel blue
	Color3.fromRGB(68,  38, 110),   -- violet
	Color3.fromRGB(120, 80,  18),   -- amber
	Color3.fromRGB(28,  28,  28),   -- near-black
	Color3.fromRGB(36, 100,  95),   -- teal
}

-- Status dot color on name tags — immediately communicates role at a glance
local ROLE_DOT_COLORS: { [string]: Color3 } = {
	Murderer  = Color3.fromRGB(255,  60,  60),   -- red
	Detective = Color3.fromRGB( 80, 140, 255),   -- blue
	Medic     = Color3.fromRGB( 90, 220, 130),   -- bright green
	Guard     = Color3.fromRGB(220, 175,  70),   -- gold
	Protector = Color3.fromRGB(160, 185, 230),   -- silver-blue
	Medium    = Color3.fromRGB(200, 120, 255),   -- purple
	Camper    = Color3.fromRGB(130, 200, 100),   -- olive green
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
	-- Stand points inside the lifted cabins ride their new base heights
	-- (lodge/creek +1.5, supply +2.15) so counselors keep the same footing
	-- on the raised floors.
	CounselorLodge = CFrame.new(0, 4.5, 67),
	Infirmary = CFrame.new(51, 4.5, 24),
	Trailhead = CFrame.new(-88, 3, 54),
	ActivityField = CFrame.new(65, 3, 55),
	Supplies = CFrame.new(-70, 5.15, -38),
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

local function labelModel(model: Model, text: string, dotColor: Color3?)
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
	-- Stud-based sizing so labels shrink with distance instead of dominating
	-- small phone screens.
	billboard.Size = UDim2.new(5.2, 0, 1.1, 0)
	billboard.StudsOffset = Vector3.new(0, anchor.Size.Y / 2 + 1.8, 0)
	billboard.MaxDistance = 45
	billboard.AlwaysOnTop = false
	billboard.ResetOnSpawn = false
	billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	billboard.Parent = anchor

	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(12, 18, 20)
	bg.BackgroundTransparency = 0.18
	bg.BorderSizePixel = 0
	bg.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)   -- full pill shape
	corner.Parent = bg

	-- Thin border ring for readability
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.82
	stroke.Thickness = 1
	stroke.Parent = bg

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.fromOffset(8, 8)
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.fromOffset(10, 15)
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = dotColor or Color3.fromRGB(90, 200, 128)
	dot.Parent = bg
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.Size = UDim2.new(1, -26, 1, 0)
	label.Position = UDim2.fromOffset(24, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(255, 252, 242)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = text
	label.Parent = bg

	-- Subtle shadow for legibility over bright backgrounds
	local shadow = Instance.new("UIStroke")
	shadow.Color = Color3.fromRGB(0, 0, 0)
	shadow.Transparency = 0.55
	shadow.Thickness = 1
	shadow.Parent = label
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
	scale: number,
	hairColor: Color3?,
	seed: number
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
	-- Eyelashes: dark strip at top edge of each eye, in front of the white
	local lashH = 0.10 * scale
	local lashZ = faceZ - 0.02
	makePart(model, "LeftLash",  Vector3.new(eyeW * 1.10, lashH, eyeD), at * CFrame.new(-eyeX, eyeY + eyeH / 2 - lashH / 2, lashZ), Color3.fromRGB(20, 15, 10))
	makePart(model, "RightLash", Vector3.new(eyeW * 1.10, lashH, eyeD), at * CFrame.new( eyeX, eyeY + eyeH / 2 - lashH / 2, lashZ), Color3.fromRGB(20, 15, 10))
	-- Pupils — color selected by character seed so each bot/counselor has unique eyes
	local pupilColor = EYE_COLORS[(seed % #EYE_COLORS) + 1]
	-- Iris rings: colored disc between the eye-white and the pupil
	local irisColor = pupilColor:Lerp(Color3.fromRGB(255, 255, 255), 0.45)
	local irisZ = faceZ - 0.02
	makePart(model, "LeftIris",  Vector3.new(eyeW * 0.86, eyeH * 0.86, eyeD), at * CFrame.new(-eyeX, eyeY, irisZ), irisColor)
	makePart(model, "RightIris", Vector3.new(eyeW * 0.86, eyeH * 0.86, eyeD), at * CFrame.new( eyeX, eyeY, irisZ), irisColor)
	local pupilZ = faceZ - 0.04
	local pupilCY = eyeY - 0.03 * scale
	makePart(model, "LeftPupil",  Vector3.new(0.21 * scale, 0.27 * scale, eyeD), at * CFrame.new(-eyeX, pupilCY, pupilZ), pupilColor)
	makePart(model, "RightPupil", Vector3.new(0.21 * scale, 0.27 * scale, eyeD), at * CFrame.new( eyeX, pupilCY, pupilZ), pupilColor)
	-- Catchlight: tiny white highlight in the upper corner of each pupil
	local catchZ = pupilZ - 0.03
	local catchS = 0.09 * scale
	local catchDX = 0.04 * scale
	local catchDY = 0.06 * scale
	local catchL = makePart(model, "LeftCatch",  Vector3.new(catchS, catchS, eyeD), at * CFrame.new(-eyeX + catchDX, pupilCY + catchDY, catchZ), Color3.fromRGB(255, 255, 255))
	catchL.Transparency = 0.10
	local catchR = makePart(model, "RightCatch", Vector3.new(catchS, catchS, eyeD), at * CFrame.new( eyeX - catchDX, pupilCY + catchDY, catchZ), Color3.fromRGB(255, 255, 255))
	catchR.Transparency = 0.10
	-- Eyebrows
	local browColor: Color3
	if hairColor then
		browColor = hairColor:Lerp(Color3.fromRGB(10, 5, 2), 0.30)
	else
		browColor = skinColor:Lerp(Color3.fromRGB(30, 18, 10), 0.65)
	end
	makePart(model, "LeftBrow",  Vector3.new(eyeW * 0.9, 0.13 * scale, eyeD), at * CFrame.new(-eyeX, eyeY + eyeH / 2 + 0.10 * scale, faceZ) * CFrame.Angles(0, 0,  0.20), browColor)
	makePart(model, "RightBrow", Vector3.new(eyeW * 0.9, 0.13 * scale, eyeD), at * CFrame.new( eyeX, eyeY + eyeH / 2 + 0.10 * scale, faceZ) * CFrame.Angles(0, 0, -0.20), browColor)
	-- Smile: center bar + raised corner blocks form a classic curved grin
	local mouthY = headY - 0.42 * scale
	local mouthColor = Color3.fromRGB(95, 42, 42)
	makePart(model, "MouthC",  Vector3.new(0.42 * scale, 0.13 * scale, eyeD), at * CFrame.new(0, mouthY, faceZ), mouthColor)
	makePart(model, "MouthL",  Vector3.new(0.15 * scale, 0.24 * scale, eyeD), at * CFrame.new(-0.29 * scale, mouthY + 0.06 * scale, faceZ), mouthColor)
	makePart(model, "MouthR",  Vector3.new(0.15 * scale, 0.24 * scale, eyeD), at * CFrame.new( 0.29 * scale, mouthY + 0.06 * scale, faceZ), mouthColor)
	-- Teeth: off-white strip inside the smile
	makePart(model, "Teeth", Vector3.new(0.30 * scale, 0.09 * scale, eyeD),
		at * CFrame.new(0, mouthY + 0.035 * scale, faceZ - 0.015), Color3.fromRGB(242, 240, 235))
	-- Upper and lower lip definition
	local lipColor = skinColor:Lerp(Color3.fromRGB(200, 100, 90), 0.18)
	makePart(model, "UpperLip", Vector3.new(0.46 * scale, 0.09 * scale, eyeD + 0.005),
		at * CFrame.new(0, mouthY + 0.11 * scale, faceZ - 0.003), lipColor)
	makePart(model, "LowerLip", Vector3.new(0.40 * scale, 0.11 * scale, eyeD + 0.006),
		at * CFrame.new(0, mouthY - 0.09 * scale, faceZ - 0.003), lipColor)
	-- Chin shadow: subtle darkening below the lower lip for jaw definition
	makePart(model, "ChinShadow", Vector3.new(0.36 * scale, 0.08 * scale, eyeD - 0.002),
		at * CFrame.new(0, mouthY - 0.22 * scale, faceZ - 0.002),
		skinColor:Lerp(Color3.fromRGB(0, 0, 0), 0.14))
	-- Nose: small bump between eyes and mouth
	makePart(model, "Nose", Vector3.new(0.20 * scale, 0.24 * scale, 0.14 * scale),
		at * CFrame.new(0, headY - 0.08 * scale, -(hd / 2 + 0.12)), skinColor:Lerp(Color3.fromRGB(160, 100, 75), 0.14))
	-- Nose highlight: bright catchlight on the nose tip
	makePart(model, "NoseLight", Vector3.new(0.07 * scale, 0.07 * scale, 0.04 * scale),
		at * CFrame.new(0, headY - 0.04 * scale, -(hd / 2 + 0.19)),
		skinColor:Lerp(Color3.fromRGB(255, 255, 255), 0.60))
	-- Philtrum: faint vertical groove between nose base and upper lip
	local philtrumY = headY - 0.28 * scale
	makePart(model, "Philtrum", Vector3.new(0.09 * scale, 0.14 * scale, eyeD),
		at * CFrame.new(0, philtrumY, faceZ - 0.001),
		skinColor:Lerp(Color3.fromRGB(0, 0, 0), 0.07))
	-- Rosy cheek blush marks
	local blushColor = skinColor:Lerp(Color3.fromRGB(240, 90, 90), 0.32)
	local blushW = 0.30 * scale
	local blushH = 0.17 * scale
	local blushY = headY - 0.10 * scale
	local blushX = 0.49 * scale
	local lb = makePart(model, "LeftBlush",  Vector3.new(blushW, blushH, eyeD), at * CFrame.new(-blushX, blushY, faceZ), blushColor)
	lb.Transparency = 0.40
	local rb = makePart(model, "RightBlush", Vector3.new(blushW, blushH, eyeD), at * CFrame.new( blushX, blushY, faceZ), blushColor)
	rb.Transparency = 0.40
	-- Ears: skin-colored blocks flush with head sides
	makePart(model, "LeftEar", Vector3.new(0.14 * scale, 0.44 * scale, 0.34 * scale),
		at * CFrame.new(-(hs / 2 + 0.07), headY, 0), skinColor)
	makePart(model, "RightEar", Vector3.new(0.14 * scale, 0.44 * scale, 0.34 * scale),
		at * CFrame.new(hs / 2 + 0.07, headY, 0), skinColor)
	-- Inner ear canal: darker oval on outer face of each ear
	local earCanalX  = hs / 2 + 0.07 + 0.07 * scale
	local canalColor = skinColor:Lerp(Color3.fromRGB(30, 0, 0), 0.22)
	makePart(model, "LeftEarCanal",  Vector3.new(0.02, 0.14 * scale, 0.16 * scale),
		at * CFrame.new(-earCanalX, headY, 0), canalColor)
	makePart(model, "RightEarCanal", Vector3.new(0.02, 0.14 * scale, 0.16 * scale),
		at * CFrame.new( earCanalX, headY, 0), canalColor)
	-- Neck: skin-colored block filling the gap between torso top and head bottom
	local neckW = 0.72 * scale
	makePart(model, "Neck", Vector3.new(neckW, 0.15 * scale, neckW),
		at * CFrame.new(0, th / 2 + 0.075 * scale, 0), skinColor)

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
	-- Wristwatch on left wrist: band ring + small dark face on inner wrist
	local watchBand = makePart(model, "WatchBand", Vector3.new(aw + 0.05, cuffH * 0.54, aw + 0.05),
		at * CFrame.new(-ax, cuffY, 0), Color3.fromRGB(28, 24, 22))
	watchBand.Material = Enum.Material.Metal
	makePart(model, "WatchFace", Vector3.new(aw * 0.42, cuffH * 0.52, 0.05),
		at * CFrame.new(-ax, cuffY, -(aw * 0.5 + 0.03)), Color3.fromRGB(14, 20, 34))
	-- Hands: skin-colored block at wrist end of each arm
	local handH = 0.22 * scale
	local handY = -(ah / 2 + handH / 2)
	makePart(model, "LeftHand",  Vector3.new(aw * 0.86, handH, aw * 0.72), at * CFrame.new(-ax, handY, 0), skinColor)
	makePart(model, "RightHand", Vector3.new(aw * 0.86, handH, aw * 0.72), at * CFrame.new( ax, handY, 0), skinColor)
	-- Finger nubs: 3 small knuckle bumps on the front face of each hand
	local fingW   = aw * 0.24
	local fingH2  = 0.17 * scale
	local fingD2  = 0.11 * scale
	local fingFZ  = -(aw * 0.72 * 0.5 + fingD2 * 0.5)
	local fingOff = aw * 0.86 * 0.29
	local fingColor = skinColor:Lerp(Color3.fromRGB(0, 0, 0), 0.09)
	makePart(model, "LFingA", Vector3.new(fingW, fingH2, fingD2), at * CFrame.new(-ax - fingOff, handY, fingFZ), fingColor)
	makePart(model, "LFingB", Vector3.new(fingW, fingH2, fingD2), at * CFrame.new(-ax,           handY, fingFZ), fingColor)
	makePart(model, "LFingC", Vector3.new(fingW, fingH2, fingD2), at * CFrame.new(-ax + fingOff, handY, fingFZ), fingColor)
	makePart(model, "RFingA", Vector3.new(fingW, fingH2, fingD2), at * CFrame.new( ax - fingOff, handY, fingFZ), fingColor)
	makePart(model, "RFingB", Vector3.new(fingW, fingH2, fingD2), at * CFrame.new( ax,           handY, fingFZ), fingColor)
	makePart(model, "RFingC", Vector3.new(fingW, fingH2, fingD2), at * CFrame.new( ax + fingOff, handY, fingFZ), fingColor)
	-- Thumb stubs on the medial side of each hand
	local thumbW  = 0.22 * scale
	local thumbH  = 0.30 * scale
	local thumbD  = 0.18 * scale
	local thumbOX = aw * 0.86 / 2 + thumbW * 0.25
	local thumbOY = handH * 0.25
	makePart(model, "LeftThumb",  Vector3.new(thumbW, thumbH, thumbD),
		at * CFrame.new(-ax + thumbOX, handY + thumbOY, 0), fingColor)
	makePart(model, "RightThumb", Vector3.new(thumbW, thumbH, thumbD),
		at * CFrame.new( ax - thumbOX, handY + thumbOY, 0), fingColor)

	-- Legs: R6 1×2×1, pants-colored (slightly darker body)
	local lw = 1 * scale
	local lh = 2 * scale
	local lx = 0.5 * scale
	local ly = -(th / 2 + lh / 2)
	local pantsColor = bodyColor:Lerp(Color3.fromRGB(10, 10, 15), 0.18)
	makePart(model, "LeftLeg",  Vector3.new(lw, lh, lw), at * CFrame.new(-lx, ly, 0), pantsColor)
	makePart(model, "RightLeg", Vector3.new(lw, lh, lw), at * CFrame.new( lx, ly, 0), pantsColor)
	-- Shirt collar: lighter strip across the top of the torso front
	local collarH = 0.18 * scale
	local collarColor = bodyColor:Lerp(Color3.fromRGB(240, 240, 240), 0.22)
	makePart(model, "Collar", Vector3.new(tw - 0.28 * scale, collarH, 0.08 * scale),
		at * CFrame.new(0, th / 2 - collarH / 2, -(td / 2 + 0.05 * scale)), collarColor)
	-- Breast pocket: left-chest pocket adds clothing depth
	local pocketX = -0.35 * scale
	local pocketY = th / 2 - 0.62 * scale
	local pocketBodyColor = bodyColor:Lerp(Color3.fromRGB(255, 255, 255), 0.07)
	local pocketFlapColor = bodyColor:Lerp(Color3.fromRGB(255, 255, 255), 0.14)
	makePart(model, "PocketBody", Vector3.new(0.34 * scale, 0.26 * scale, 0.07 * scale),
		at * CFrame.new(pocketX, pocketY, -(td / 2 + 0.06 * scale)), pocketBodyColor)
	makePart(model, "PocketFlap", Vector3.new(0.34 * scale, 0.07 * scale, 0.08 * scale),
		at * CFrame.new(pocketX, pocketY + 0.16 * scale, -(td / 2 + 0.065 * scale)), pocketFlapColor)
	-- Shirt buttons: three small discs down the right placket
	local btnColor = Color3.fromRGB(218, 218, 222)
	local btnX    = 0.10 * scale
	local btnZ    = -(td / 2 + 0.04 * scale)
	makePart(model, "Btn1", Vector3.new(0.09 * scale, 0.09 * scale, 0.05 * scale), at * CFrame.new(btnX, th / 2 - 0.46 * scale, btnZ), btnColor)
	makePart(model, "Btn2", Vector3.new(0.09 * scale, 0.09 * scale, 0.05 * scale), at * CFrame.new(btnX, th / 2 - 0.70 * scale, btnZ), btnColor)
	makePart(model, "Btn3", Vector3.new(0.09 * scale, 0.09 * scale, 0.05 * scale), at * CFrame.new(btnX, th / 2 - 0.94 * scale, btnZ), btnColor)
	-- Belt: dark strip straddling the torso-leg junction
	local beltH = 0.20 * scale
	local beltColor = bodyColor:Lerp(Color3.fromRGB(22, 16, 10), 0.52)
	makePart(model, "Belt", Vector3.new(tw + 0.08 * scale, beltH, td + 0.06 * scale),
		at * CFrame.new(0, -th / 2, 0), beltColor)
	-- Belt buckle: small gold-tinted square at belt center front
	local buckle = makePart(model, "BeltBuckle", Vector3.new(0.28 * scale, beltH * 0.82, 0.10 * scale),
		at * CFrame.new(0, -th / 2, -(td / 2 + 0.06 * scale)), Color3.fromRGB(172, 155, 65))
	buckle.Material = Enum.Material.Metal
	-- Shirt back seam: subtle vertical centre line on the back of the torso
	local seamColor = bodyColor:Lerp(Color3.fromRGB(255, 255, 255), 0.09)
	makePart(model, "BackSeam", Vector3.new(0.08 * scale, th * 0.85, 0.03),
		at * CFrame.new(0, th * 0.075, td / 2 + 0.02), seamColor)
	-- Shoes: slightly wider near-black blocks at bottom of each leg
	local shoeH = 0.38 * scale
	local shoeW = 1.22 * scale
	local shoeY = ly - lh / 2 + shoeH / 2
	local shoeColor = Color3.fromRGB(26, 20, 14)
	makePart(model, "LeftShoe",  Vector3.new(shoeW, shoeH, shoeW), at * CFrame.new(-lx, shoeY, 0), shoeColor)
	makePart(model, "RightShoe", Vector3.new(shoeW, shoeH, shoeW), at * CFrame.new( lx, shoeY, 0), shoeColor)
	-- Shoe soles: thin rubber-coloured strip under each shoe
	local soleH   = 0.08 * scale
	local soleW   = shoeW + 0.04 * scale
	local soleY   = shoeY - shoeH / 2 + soleH / 2
	local soleColor = Color3.fromRGB(38, 35, 30)
	makePart(model, "LeftSole",  Vector3.new(soleW, soleH, soleW), at * CFrame.new(-lx, soleY, 0), soleColor)
	makePart(model, "RightSole", Vector3.new(soleW, soleH, soleW), at * CFrame.new( lx, soleY, 0), soleColor)
	-- White ankle socks: crisp band just above the shoe top
	local sockH   = 0.16 * scale
	local sockW   = 1.20 * scale
	local sockY   = shoeY + shoeH / 2 + sockH / 2
	makePart(model, "LeftSock",  Vector3.new(sockW, sockH, sockW), at * CFrame.new(-lx, sockY, 0), Color3.fromRGB(238, 238, 238))
	makePart(model, "RightSock", Vector3.new(sockW, sockH, sockW), at * CFrame.new( lx, sockY, 0), Color3.fromRGB(238, 238, 238))

	-- Knee pads: slightly wider slab at kneecap height adds definition to the leg silhouette
	local kneeH = 0.20 * scale
	local kneeY = ly + lh * 0.05   -- just above leg center
	local kneeColor = pantsColor:Lerp(Color3.fromRGB(0, 0, 0), 0.08)
	makePart(model, "LeftKnee",  Vector3.new(lw * 1.10, kneeH, lw * 0.85), at * CFrame.new(-lx, kneeY, 0), kneeColor)
	makePart(model, "RightKnee", Vector3.new(lw * 1.10, kneeH, lw * 0.85), at * CFrame.new( lx, kneeY, 0), kneeColor)

	-- Hair: style varies by seed so each character has a distinct look
	if hairColor then
		local hairStyle = seed % 6
		local hairH = 0.44 * scale
		local hairTopY = headY + hs / 2 + hairH / 2
		local bangDepth = 0.22 * scale
		if hairStyle == 0 then
			-- Classic: cap + front bang + back drape
			makePart(model, "Hair", Vector3.new(hs, hairH, hd), at * CFrame.new(0, hairTopY, 0), hairColor)
			local bangH = 0.34 * scale
			makePart(model, "HairBang", Vector3.new(hs * 0.82, bangH, bangDepth),
				at * CFrame.new(0, headY + hs / 2 - bangH / 2, -(hd / 2 + bangDepth / 2)), hairColor)
			local backH = hs * 0.72
			makePart(model, "HairBack", Vector3.new(hs * 0.88, backH, bangDepth),
				at * CFrame.new(0, headY + hs / 2 - backH / 2, hd / 2 + bangDepth / 2), hairColor)
		elseif hairStyle == 1 then
			-- Short: cap + minimal wispy bang, no back
			local shortH = 0.30 * scale
			makePart(model, "Hair", Vector3.new(hs, shortH, hd), at * CFrame.new(0, headY + hs / 2 + shortH / 2, 0), hairColor)
			local bangH = 0.20 * scale
			makePart(model, "HairBang", Vector3.new(hs * 0.55, bangH, bangDepth * 0.70),
				at * CFrame.new(-0.10 * scale, headY + hs / 2 - bangH / 2, -(hd / 2 + bangDepth * 0.35)), hairColor)
		elseif hairStyle == 2 then
			-- Long: cap + wide bang + long back drape
			makePart(model, "Hair", Vector3.new(hs, hairH, hd), at * CFrame.new(0, hairTopY, 0), hairColor)
			local bangH = 0.52 * scale
			makePart(model, "HairBang", Vector3.new(hs * 0.92, bangH, bangDepth),
				at * CFrame.new(0, headY + hs / 2 - bangH / 2, -(hd / 2 + bangDepth / 2)), hairColor)
			local backH = hs * 1.10
			makePart(model, "HairBack", Vector3.new(hs * 0.88, backH, bangDepth),
				at * CFrame.new(0, headY + hs / 2 - backH / 2, hd / 2 + bangDepth / 2), hairColor)
		elseif hairStyle == 3 then
			-- Bun: tall rounded top-knot, no bang or drape
			local capH = 0.30 * scale
			makePart(model, "Hair", Vector3.new(hs, capH, hd), at * CFrame.new(0, headY + hs / 2 + capH / 2, 0), hairColor)
			local bunR = 0.52 * scale
			makePart(model, "HairBun", Vector3.new(bunR, bunR, bunR),
				at * CFrame.new(0, headY + hs / 2 + capH + bunR * 0.5, 0), hairColor, Enum.PartType.Ball)
		elseif hairStyle == 4 then
			-- Afro/Curly: large round volume covering the top and sides of the head
			local afroR = 1.15 * scale
			makePart(model, "Hair", Vector3.new(afroR * 2.1, afroR * 1.7, afroR * 1.85),
				at * CFrame.new(0, headY + hs / 4, 0), hairColor, Enum.PartType.Ball)
		else
			-- Pigtails: flat cap with two short side tails hanging from ear level
			local capH = 0.26 * scale
			makePart(model, "Hair", Vector3.new(hs, capH, hd), at * CFrame.new(0, headY + hs / 2 + capH / 2, 0), hairColor)
			local tailW = 0.32 * scale
			local tailH = 0.64 * scale
			local tailY = headY - 0.10 * scale
			makePart(model, "HairTailL", Vector3.new(tailW, tailH, tailW * 0.85),
				at * CFrame.new(-(hs / 2 + tailW * 0.3), tailY - tailH / 2, 0), hairColor)
			makePart(model, "HairTailR", Vector3.new(tailW, tailH, tailW * 0.85),
				at * CFrame.new( hs / 2 + tailW * 0.3, tailY - tailH / 2, 0), hairColor)
		end
		-- Sideburns: thin strips of hair at the temples on each side of the head
		local sbH = 0.28 * scale
		local sbW = 0.06 * scale
		local sbX = hs / 2 - 0.02
		local sbY = headY + hs / 4
		local sbZ = -hd / 4
		makePart(model, "SideburnL", Vector3.new(sbW, sbH, sbW),
			at * CFrame.new(-sbX, sbY, sbZ), hairColor)
		makePart(model, "SideburnR", Vector3.new(sbW, sbH, sbW),
			at * CFrame.new( sbX, sbY, sbZ), hairColor)
	end

	-- Periodic blink: eye parts briefly go transparent, ~every 4-9 seconds
	task.spawn(function()
		local BLINK_PARTS = {
			"LeftEyeW", "RightEyeW", "LeftPupil", "RightPupil",
			"LeftCatch", "RightCatch", "LeftLash", "RightLash",
		}
		local eyeParts: { BasePart } = {}
		for _, n in BLINK_PARTS do
			local p = model:FindFirstChild(n) :: BasePart?
			if p then table.insert(eyeParts, p) end
		end
		if #eyeParts == 0 then return end
		task.wait(math.random() * 6)   -- stagger so all characters do not blink in unison
		while model.Parent ~= nil do
			for step = 1, 3 do
				if model.Parent == nil then return end
				for _, p in eyeParts do if p.Parent ~= nil then p.Transparency = step / 3 end end
				task.wait(0.04)
			end
			task.wait(0.05)
			for step = 3, 0, -1 do
				if model.Parent == nil then return end
				for _, p in eyeParts do if p.Parent ~= nil then p.Transparency = step / 3 end end
				task.wait(0.05)
			end
			for _, p in eyeParts do if p.Parent ~= nil then p.Transparency = 0 end end
			task.wait(4 + (nameHash(model.Name) % 5) * 0.9 + math.random() * 2.5)
		end
	end)

	return root
end

-- Applies a full walk pose (arms + legs) to a procedural character after PivotTo.
-- swingAngle in radians; cross-coordination is handled internally:
--   rightArm backward  ↔  leftLeg backward  (natural gait)
local function applyArmSwing(model: Model, modelCF: CFrame, swingAngle: number)
	local leftArm  = model:FindFirstChild("LeftArm")  :: BasePart?
	local rightArm = model:FindFirstChild("RightArm") :: BasePart?
	if not leftArm or not rightArm then
		return
	end
	local armScale = leftArm.Size.X   -- aw = 1 * scale => equals the character scale
	local th  = 2 * armScale
	local ax  = 1.5 * armScale
	local ah  = 2 * armScale
	local cuffH = 0.35 * armScale

	-- Arms swing from shoulder joints (top of torso)
	local rightShoulderCF = modelCF * CFrame.new( ax, th / 2, 0)
	local leftShoulderCF  = modelCF * CFrame.new(-ax, th / 2, 0)
	-- Lateral splay: arm flares slightly outward when swinging back (natural gait)
	local splayR = -swingAngle * 0.18
	local splayL =  swingAngle * 0.18
	rightArm.CFrame = rightShoulderCF * CFrame.Angles(-swingAngle, 0, splayR) * CFrame.new(0, -ah / 2, 0)
	leftArm.CFrame  = leftShoulderCF  * CFrame.Angles( swingAngle, 0, splayL) * CFrame.new(0, -ah / 2, 0)
	local leftCuff  = model:FindFirstChild("LeftCuff")  :: BasePart?
	local rightCuff = model:FindFirstChild("RightCuff") :: BasePart?
	if leftCuff and rightCuff then
		local cuffDist = ah - cuffH / 2
		rightCuff.CFrame = rightShoulderCF * CFrame.Angles(-swingAngle, 0, splayR) * CFrame.new(0, -cuffDist, 0)
		leftCuff.CFrame  = leftShoulderCF  * CFrame.Angles( swingAngle, 0, splayL) * CFrame.new(0, -cuffDist, 0)
		-- Watch tracks with left cuff
		local wBand = model:FindFirstChild("WatchBand") :: BasePart?
		local wFace = model:FindFirstChild("WatchFace") :: BasePart?
		if wBand then wBand.CFrame = leftCuff.CFrame end
		if wFace then wFace.CFrame = leftCuff.CFrame * CFrame.new(0, 0, -(armScale * 0.5 + 0.03)) end
	end
	-- Sleeve bands track the upper-arm swing (only present on counselor models)
	local leftBand  = model:FindFirstChild("SleeveBandL") :: BasePart?
	local rightBand = model:FindFirstChild("SleeveBandR") :: BasePart?
	if leftBand and rightBand then
		local bandDist = 0.40 * armScale
		rightBand.CFrame = rightShoulderCF * CFrame.Angles(-swingAngle, 0, splayR) * CFrame.new(0, -bandDist, 0)
		leftBand.CFrame  = leftShoulderCF  * CFrame.Angles( swingAngle, 0, splayL) * CFrame.new(0, -bandDist, 0)
	end
	-- Hands follow the bottom of the arm swing
	local leftHand  = model:FindFirstChild("LeftHand")  :: BasePart?
	local rightHand = model:FindFirstChild("RightHand") :: BasePart?
	if leftHand and rightHand then
		local handDist = ah + leftHand.Size.Y * 0.5
		local rhCF = rightShoulderCF * CFrame.Angles(-swingAngle, 0, splayR) * CFrame.new(0, -handDist, 0)
		local lhCF = leftShoulderCF  * CFrame.Angles( swingAngle, 0, splayL) * CFrame.new(0, -handDist, 0)
		rightHand.CFrame = rhCF
		leftHand.CFrame  = lhCF
		local fZ   = -(leftHand.Size.Z * 0.5 + 0.06 * armScale)
		local fOff = leftHand.Size.X * 0.29
		local lFA = model:FindFirstChild("LFingA") :: BasePart?
		local rFA = model:FindFirstChild("RFingA") :: BasePart?
		local lFB = model:FindFirstChild("LFingB") :: BasePart?
		local rFB = model:FindFirstChild("RFingB") :: BasePart?
		local lFC = model:FindFirstChild("LFingC") :: BasePart?
		local rFC = model:FindFirstChild("RFingC") :: BasePart?
		if lFA then lFA.CFrame = lhCF * CFrame.new(-fOff, 0, fZ) end
		if rFA then rFA.CFrame = rhCF * CFrame.new(-fOff, 0, fZ) end
		if lFB then lFB.CFrame = lhCF * CFrame.new(    0, 0, fZ) end
		if rFB then rFB.CFrame = rhCF * CFrame.new(    0, 0, fZ) end
		if lFC then lFC.CFrame = lhCF * CFrame.new( fOff, 0, fZ) end
		if rFC then rFC.CFrame = rhCF * CFrame.new( fOff, 0, fZ) end
		-- Thumb stubs track the hand swing (medial side)
		local leftThumb  = model:FindFirstChild("LeftThumb")  :: BasePart?
		local rightThumb = model:FindFirstChild("RightThumb") :: BasePart?
		if leftThumb and rightThumb then
			local thumbOX = leftHand.Size.X / 2 + 0.06 * armScale
			local thumbOY = leftHand.Size.Y * 0.25
			leftThumb.CFrame  = lhCF * CFrame.new( thumbOX, thumbOY, 0)
			rightThumb.CFrame = rhCF * CFrame.new(-thumbOX, thumbOY, 0)
		end
	end

	-- Legs swing from hip joints (bottom of torso), opposite side to same-side arm
	local lh      = 2 * armScale
	local lx      = 0.5 * armScale
	local shoeH   = 0.38 * armScale
	local legSwing = swingAngle * 0.72          -- legs swing a bit less than arms
	local shoeDist = lh - shoeH / 2             -- hip-to-shoe-center distance along leg
	local rightHipCF = modelCF * CFrame.new( lx, -th / 2, 0)
	local leftHipCF  = modelCF * CFrame.new(-lx, -th / 2, 0)
	local leftLeg  = model:FindFirstChild("LeftLeg")  :: BasePart?
	local rightLeg = model:FindFirstChild("RightLeg") :: BasePart?
	if leftLeg and rightLeg then
		-- Cross-coordination: right leg rotates same direction as left arm (swingAngle > 0)
		rightLeg.CFrame = rightHipCF * CFrame.Angles( legSwing, 0, 0) * CFrame.new(0, -lh / 2, 0)
		leftLeg.CFrame  = leftHipCF  * CFrame.Angles(-legSwing, 0, 0) * CFrame.new(0, -lh / 2, 0)
		local leftShoe  = model:FindFirstChild("LeftShoe")  :: BasePart?
		local rightShoe = model:FindFirstChild("RightShoe") :: BasePart?
		if leftShoe and rightShoe then
			-- Ankle bend: shoe partly counteracts leg tilt so foot stays near-horizontal
			rightShoe.CFrame = rightHipCF * CFrame.Angles( legSwing, 0, 0) * CFrame.new(0, -shoeDist, 0) * CFrame.Angles(-legSwing * 0.55, 0, 0)
			leftShoe.CFrame  = leftHipCF  * CFrame.Angles(-legSwing, 0, 0) * CFrame.new(0, -shoeDist, 0) * CFrame.Angles( legSwing * 0.55, 0, 0)
		end
		-- Soles track the shoe with the same ankle counter-rotation
		local leftSole  = model:FindFirstChild("LeftSole")  :: BasePart?
		local rightSole = model:FindFirstChild("RightSole") :: BasePart?
		if leftSole and rightSole then
			local soleH2  = 0.08 * armScale
			local soleDist = lh - soleH2 / 2
			rightSole.CFrame = rightHipCF * CFrame.Angles( legSwing, 0, 0) * CFrame.new(0, -soleDist, 0) * CFrame.Angles(-legSwing * 0.55, 0, 0)
			leftSole.CFrame  = leftHipCF  * CFrame.Angles(-legSwing, 0, 0) * CFrame.new(0, -soleDist, 0) * CFrame.Angles( legSwing * 0.55, 0, 0)
		end
		-- Knee pads track the upper-leg swing
		local leftKnee  = model:FindFirstChild("LeftKnee")  :: BasePart?
		local rightKnee = model:FindFirstChild("RightKnee") :: BasePart?
		if leftKnee and rightKnee then
			local kneeDist = lh * 0.45
			rightKnee.CFrame = rightHipCF * CFrame.Angles( legSwing, 0, 0) * CFrame.new(0, -kneeDist, 0)
			leftKnee.CFrame  = leftHipCF  * CFrame.Angles(-legSwing, 0, 0) * CFrame.new(0, -kneeDist, 0)
		end
		-- Socks follow leg swing only (no ankle counter-rotation)
		local leftSock  = model:FindFirstChild("LeftSock")  :: BasePart?
		local rightSock = model:FindFirstChild("RightSock") :: BasePart?
		if leftSock and rightSock then
			local sockH2   = 0.16 * armScale
			local sockDist = lh - shoeH - sockH2 / 2
			rightSock.CFrame = rightHipCF * CFrame.Angles( legSwing, 0, 0) * CFrame.new(0, -sockDist, 0)
			leftSock.CFrame  = leftHipCF  * CFrame.Angles(-legSwing, 0, 0) * CFrame.new(0, -sockDist, 0)
		end
	end
end

local function buildProceduralMonster(monsterId: MonsterId, at: CFrame): Model
	local presentation = MONSTER_PRESENTATION[monsterId]
	local model = Instance.new("Model")
	model.Name = "ActiveMonster_" .. monsterId
	model:SetAttribute("ProceduralFallback", true)
	model:SetAttribute("MonsterId", monsterId)

	local sc = presentation.scale       -- Vector3: per-axis body shape multiplier
	local sx, sy, sz = sc.X, sc.Y, sc.Z -- scalar components for offset math
	local torsoSize = Vector3.new(4, 5, 3) * sc
	local headSize = Vector3.new(3.2, 3.2, 3.2) * sc
	local headY = torsoSize.Y / 2 + 1.6
	local root = makePart(model, "Root", torsoSize, at, presentation.color)
	model.PrimaryPart = root
	makePart(model, "Head", headSize, at * CFrame.new(0, headY, 0), presentation.accent, presentation.headShape)

	-- Glowing eyes on all monsters that have heads (BabyAlien handles its own below)
	if monsterId ~= "Dullahan" and monsterId ~= "BabyAlien" then
		local eS = Vector3.new(0.55 * sx, 0.65 * sy, 0.38 * sz)
		local eX = 0.62 * sx
		local eY = headY + 0.1 * sy
		local eZ = -(headSize.Z / 2 + 0.06)
		local lg = makePart(model, "LeftGlow", eS, at * CFrame.new(-eX, eY, eZ), presentation.accent, Enum.PartType.Ball)
		lg.Material = Enum.Material.Neon
		local rg = makePart(model, "RightGlow", eS, at * CFrame.new(eX, eY, eZ), presentation.accent, Enum.PartType.Ball)
		rg.Material = Enum.Material.Neon
	end

	-- Elongated creature limbs (all monsters)
	local limbLen = 4.2 * sy
	local limbW = 0.58 * sx
	local limbShoulderLX = -(torsoSize.X / 2 + limbLen * 0.16)
	local limbShoulderY  = -0.5 * sy
	makePart(model, "LeftLimb", Vector3.new(limbW, limbLen, limbW),
		at * CFrame.new(limbShoulderLX, limbShoulderY, 0) * CFrame.Angles(0, 0, 0.42), presentation.accent)
	makePart(model, "RightLimb", Vector3.new(limbW, limbLen, limbW),
		at * CFrame.new(-limbShoulderLX, limbShoulderY, 0) * CFrame.Angles(0, 0, -0.42), presentation.accent)
	-- Store shoulder anchors so the tracking loop can animate the limbs per-frame
	model:SetAttribute("LimbShoulderLX", limbShoulderLX)
	model:SetAttribute("LimbShoulderRX", -limbShoulderLX)
	model:SetAttribute("LimbShoulderY",  limbShoulderY)
	model:SetAttribute("LimbLen",        limbLen)

	if monsterId == "BabyAlien" then
		-- Swollen alien cranium: disproportionately large head is the key reference feature
		local cranium = makePart(model, "AlienCranium",
			Vector3.new(headSize.X * 1.65, headSize.Y * 1.95, headSize.Z * 1.45),
			at * CFrame.new(0, headY + headSize.Y * 0.28, 0),
			presentation.color, Enum.PartType.Ball)
		cranium.Transparency = 0.04
		-- Large dark almond eyes on the front of the cranium. Keep the eye centers on the
		-- cranium ellipsoid surface: (dx/ax)^2 + (dy/ay)^2 + (dz/az)^2 must stay ~1 relative
		-- to the cranium center (0, headY + 0.28*headSize.Y, 0) with semi-axes
		-- (0.825*hx, 0.975*hy, 0.725*hz), or the eyes float off the head.
		local craniumFrontZ = -(headSize.Z * 0.60 + 0.08)
		local eyeY = headY + headSize.Y * 0.10
		for side = -1, 1, 2 do
			local eye = makePart(model, if side < 0 then "LeftEye" else "RightEye",
				Vector3.new(1.85 * sx, 1.35 * sy, 0.55 * sz),
				at * CFrame.new(side * headSize.X * 0.45, eyeY, craniumFrontZ)
					* CFrame.Angles(0, 0, side * 0.35),
				Color3.fromRGB(5, 4, 6), Enum.PartType.Ball)
			eye.Material = Enum.Material.SmoothPlastic
		end
		-- Override generic near-black arm limbs to flesh pink (reference: uniformly fleshy creature)
		local baLL = model:FindFirstChild("LeftLimb") :: BasePart?
		local baRL = model:FindFirstChild("RightLimb") :: BasePart?
		if baLL then baLL.Color = presentation.color end
		if baRL then baRL.Color = presentation.color end
		-- 2 humanoid legs, angled forward in crawling pose (reference: baby alien lying/crawling)
		for side = -1, 1, 2 do
			makePart(model, if side < 0 then "LeftLeg" else "RightLeg",
				Vector3.new(0.50 * sx, 2.4 * sy, 0.50 * sz),
				at * CFrame.new(side * 0.85 * sx, -(torsoSize.Y / 2 + 0.9 * sy), 0.7 * sz)
					* CFrame.Angles(-0.30, 0, side * 0.08), presentation.color)
		end
		-- Small depressed mouth on lower face (reference: visible pursed opening below the eyes)
		local mouthPart = makePart(model, "Mouth",
			Vector3.new(0.55 * sx, 0.20 * sy, 0.28),
			at * CFrame.new(0, headY - headSize.Y * 0.24, -(headSize.Z / 2 + 0.04)),
			Color3.fromRGB(28, 14, 16), Enum.PartType.Ball)
		mouthPart.Material = Enum.Material.SmoothPlastic
		-- Grasping claw fingers on each arm (4 elongated fingers per hand — reference shows 4 clearly)
		for side = -1, 1, 2 do
			local clawBaseX = limbShoulderLX * (if side < 0 then 1 else -1)
			local clawBaseY = limbShoulderY - limbLen * 0.9
			for f = 1, 4 do
				local spread = (f - 2.5) * 0.20 * sx
				local fLen = (1.10 - math.abs(f - 2.5) * 0.06) * sy
				local finger = makePart(model, (if side < 0 then "LFinger" else "RFinger") .. tostring(f),
					Vector3.new(0.13, fLen, 0.13),
					at * CFrame.new(clawBaseX + spread, clawBaseY - fLen * 0.5, -(headSize.Z * 0.10))
						* CFrame.Angles(0.22, 0, side * 0.06), presentation.color)
				finger.Material = Enum.Material.SmoothPlastic
			end
		end
	elseif monsterId == "Screamer" then
		-- Reference: pale bone-white skull dome with no eyes — override generic near-black accent head
		local scHead = model:FindFirstChild("Head") :: BasePart?
		if scHead then scHead.Color = presentation.color end
		local scEyeL = model:FindFirstChild("LeftGlow") :: BasePart?
		local scEyeR = model:FindFirstChild("RightGlow") :: BasePart?
		if scEyeL then scEyeL.Transparency = 1 end
		if scEyeR then scEyeR.Transparency = 1 end
		-- Arms are near-black (dark charcoal) while upper torso/head stays pale — reference clearly shows this
		local scLL = model:FindFirstChild("LeftLimb") :: BasePart?
		local scRL = model:FindFirstChild("RightLimb") :: BasePart?
		if scLL then scLL.Color = presentation.accent end
		if scRL then scRL.Color = presentation.accent end
		-- Square mouth reads as circular from front — lamprey reference
		local mouth = makePart(model, "ResonantMouth", Vector3.new(3.0, 3.0, 0.6),
			at * CFrame.new(0, headY - 0.1, -(headSize.Z / 2 + 0.06)), Color3.fromRGB(24, 10, 14))
		mouth.Material = Enum.Material.Neon
		-- Ring of jagged white teeth around the mouth (8 teeth, like the reference's lamprey rows)
		-- Teeth must sit in FRONT of the maw panel (mouth front face is at
		-- headSize.Z/2 + 0.36) and inside its 1.5-stud half-width, or the black
		-- box swallows them entirely
		local toothW = 0.32 * sx
		local toothH = 0.75 * sy
		local toothR = 1.15 * sx  -- radius from mouth center
		local toothFaceZ = -(headSize.Z / 2 + 0.44)
		for t = 1, 8 do
			local ta = ((t - 1) / 8) * math.pi * 2
			local tx = math.cos(ta) * toothR
			local ty = headY - 0.1 + math.sin(ta) * toothR
			local tooth = makePart(model, "MouthTooth" .. tostring(t),
				Vector3.new(toothW, toothH, 0.18 * sz),
				at * CFrame.new(tx, ty, toothFaceZ) * CFrame.Angles(0, 0, ta + math.pi / 2),
				Color3.fromRGB(230, 222, 208))
			tooth.Material = Enum.Material.SmoothPlastic
		end
		for side = -1, 1, 2 do
			makePart(model, if side < 0 then "LeftSoundSpine" else "RightSoundSpine",
				Vector3.new(0.35, 4.5, 0.35),
				at * CFrame.new(side * 2.4, 1.2, 0) * CFrame.Angles(0, 0, side * 0.35), presentation.accent)
		end
		for side = -1, 1, 2 do
			makePart(model, if side < 0 then "LeftLeg" else "RightLeg",
				Vector3.new(0.52, 3.4 * sy, 0.52),
				at * CFrame.new(side * sx, -(torsoSize.Y / 2 + 1.4 * sy), 0) * CFrame.Angles(0, 0, side * 0.12),
				presentation.accent)
		end
		-- 4 talon-toes per foot fanning forward (reference shows bird-like claw feet)
		local footY = -(torsoSize.Y / 2 + 3.1 * sy)
		for side = -1, 1, 2 do
			local fx = side * sx
			for t = 1, 4 do
				local tLen = (1.70 - math.abs(t - 2.5) * 0.25) * sy
				local spread = (t - 2.5) * 0.42 * sx
				makePart(model, (if side < 0 then "LToe" else "RToe") .. tostring(t),
					Vector3.new(0.12, tLen, 0.12),
					at * CFrame.new(fx + spread, footY - tLen * 0.5, -(0.20 * sz))
						* CFrame.Angles(-0.44, 0, (t - 2.5) * 0.18),
					presentation.accent)
			end
		end
		-- 5-fingered claw hands extending below each arm (reference shows dramatically splayed talons)
		for side = -1, 1, 2 do
			local clawBaseX = limbShoulderLX * (if side < 0 then 1 else -1)
			local clawBaseY = limbShoulderY - limbLen * 0.5
			for f = 1, 5 do
				local spread = (f - 3) * 0.42 * sx
				local clawLen = (2.2 - math.abs(f - 3) * 0.22) * sy
				makePart(model, (if side < 0 then "LClaw" else "RClaw") .. tostring(f),
					Vector3.new(0.11, clawLen, 0.11),
					at * CFrame.new(clawBaseX + spread, clawBaseY - limbLen * 0.5, 0)
						* CFrame.Angles(0.22 * (f - 3), 0, side * (0.14 + math.abs(f - 3) * 0.10)), presentation.accent)
			end
		end
		-- Exposed viscera hanging from lower torso (prominent in reference image)
		local visceraC = Color3.fromRGB(120, 28, 38)
		local visOffsets = {{-0.55, -1.0}, {0.10, -1.4}, {-0.20, -1.8}}
		for vi, vOff in ipairs(visOffsets) do
			local vis = makePart(model, "Viscera" .. vi,
				Vector3.new(0.62 * sx, 0.48 * sy, 0.50 * sz),
				at * CFrame.new(vOff[1] * sx, -(torsoSize.Y * 0.40) + vOff[2] * sy, 0),
				visceraC, Enum.PartType.Ball)
			vis.Material = Enum.Material.SmoothPlastic
			vis.Transparency = 0.18
		end
	elseif monsterId == "Wendigo" then
		-- Deer skull head: pale bone cranium + hollow dark eye sockets + elongated muzzle
		local boneColor = presentation.accent:Lerp(Color3.fromRGB(226, 218, 198), 0.55)
		local wdHead = model:FindFirstChild("Head") :: BasePart?
		if wdHead then
			wdHead.Color = boneColor
		end
		-- Hollow eye sockets: large dark voids dominating the skull face (reference:
		-- the sockets are the skull's defining feature, not small dots)
		local wdEyeL = model:FindFirstChild("LeftGlow") :: BasePart?
		local wdEyeR = model:FindFirstChild("RightGlow") :: BasePart?
		for _, socket in { wdEyeL, wdEyeR } do
			if socket then
				socket.Color = Color3.fromRGB(10, 8, 10)
				socket.Material = Enum.Material.SmoothPlastic
				-- Ball parts render as spheres with diameter = smallest axis, so all
				-- three axes must grow for the socket to actually get bigger
				socket.Size = Vector3.new(0.95 * sx, 0.95 * sy, 0.95 * sz)
			end
		end
		-- Elongated skull muzzle: long, angled slightly downward, with a dark nose tip
		local muzzleCF = at * CFrame.new(0, headY - 0.30 * sy, -(headSize.Z / 2 + 0.85 * sz))
			* CFrame.Angles(0.22, 0, 0)
		makePart(model, "SkullSnout", Vector3.new(0.85 * sx, 0.72 * sy, 1.95 * sz),
			muzzleCF, boneColor)
		makePart(model, "SkullNose", Vector3.new(0.48 * sx, 0.40 * sy, 0.30 * sz),
			muzzleCF * CFrame.new(0, -0.05 * sy, -(0.95 * sz)), Color3.fromRGB(16, 12, 12))
		-- Main antler beams: sy-scaled so they tower above the tall skull (reference: massive rack)
		local aBY = headY + 1.8 * sy
		makePart(model, "LeftAntler", Vector3.new(0.35*sx, 4.2*sy, 0.35*sx),
			at * CFrame.new(-1.6*sx, aBY, 0) * CFrame.Angles(0, 0, -0.45), presentation.accent)
		makePart(model, "RightAntler", Vector3.new(0.35*sx, 4.2*sy, 0.35*sx),
			at * CFrame.new( 1.6*sx, aBY, 0) * CFrame.Angles(0, 0,  0.45), presentation.accent)
		-- Branching tines off each main antler beam (reference shows 5-7 tines per side)
		for aSide = -1, 1, 2 do
			local tag = if aSide < 0 then "Left" else "Right"
			local bx = aSide * 1.6 * sx
			makePart(model, tag .. "AntlerTine1", Vector3.new(0.22*sx, 1.8*sy, 0.22*sx),
				at * CFrame.new(bx - aSide*0.4*sx, aBY + 0.72*sy, 0.15) * CFrame.Angles(0.1, 0, aSide*(-1.25)), presentation.accent)
			makePart(model, tag .. "AntlerTine2", Vector3.new(0.20*sx, 1.4*sy, 0.20*sx),
				at * CFrame.new(bx - aSide*0.68*sx, aBY + 1.5*sy, -0.2) * CFrame.Angles(-0.15, 0, aSide*(-0.7)), presentation.accent)
			makePart(model, tag .. "AntlerTine3", Vector3.new(0.18*sx, 1.1*sy, 0.18*sx),
				at * CFrame.new(bx - aSide*0.95*sx, aBY + 2.2*sy, 0.12) * CFrame.Angles(0.1, 0, aSide*(-1.55)), presentation.accent)
			makePart(model, tag .. "AntlerTine4", Vector3.new(0.16*sx, 0.9*sy, 0.16*sx),
				at * CFrame.new(bx - aSide*0.15*sx, aBY + 2.6*sy, -0.1) * CFrame.Angles(0.2, 0, aSide*(-0.45)), presentation.accent)
		end
		-- Exposed ribcage on the torso front (reference shows skeletal chest)
		local ribColor = presentation.accent:Lerp(Color3.fromRGB(200, 190, 165), 0.4)
		for r = 1, 4 do
			local ribY = torsoSize.Y * 0.3 - r * 0.65 * sy
			local ribW  = torsoSize.X * (0.55 + r * 0.06)
			makePart(model, "Rib" .. tostring(r), Vector3.new(ribW, 0.20, 0.14),
				at * CFrame.new(0, ribY, -(torsoSize.Z / 2 + 0.06)), ribColor)
		end
		-- Twisted vine/bark strips wound around the torso (core reference-image feature)
		local barkColor = Color3.fromRGB(52, 36, 18)
		local vineAngles = {0.62, -0.48, 0.80, -0.72}
		local vineYOffsets = {torsoSize.Y * 0.30, torsoSize.Y * 0.05, -torsoSize.Y * 0.18, -torsoSize.Y * 0.38}
		for v = 1, 4 do
			local vine = makePart(model, "VineStrip" .. v,
				Vector3.new(torsoSize.X * 1.18, 0.28 * sy, 0.22),
				at * CFrame.new(0, vineYOffsets[v], -(torsoSize.Z / 2 + 0.03))
					* CFrame.Angles(0, 0, vineAngles[v]), barkColor)
			vine.Material = Enum.Material.WoodPlanks
		end
		-- Bark shard protrusions from each side of the torso
		for side = -1, 1, 2 do
			local shard = makePart(model, "BarkShard" .. (if side < 0 then "L" else "R"),
				Vector3.new(0.38 * sx, 1.20 * sy, 0.20),
				at * CFrame.new(side * (torsoSize.X * 0.62), 0.10 * sy, 0)
					* CFrame.Angles(0.22, 0, side * 0.55), barkColor)
			shard.Material = Enum.Material.WoodPlanks
		end
		-- Wide bark-wing panels extending from each shoulder (Wendigo's defining silhouette feature:
		-- the creature appears far wider than its torso because of large spreading branch slabs)
		local darkBark = Color3.fromRGB(38, 26, 12)
		for side = -1, 1, 2 do
			local wx = side * (torsoSize.X / 2 + limbLen * 0.28)
			-- Upper wing slab: large flat bark panel fanning outward from shoulder
			local wingUp = makePart(model, (if side < 0 then "WingUpL" else "WingUpR"),
				Vector3.new(0.30, 4.2 * sy, 1.80 * sz),
				at * CFrame.new(wx, 0.6 * sy, 0)
					* CFrame.Angles(0.12, 0, side * 0.62), darkBark)
			wingUp.Material = Enum.Material.WoodPlanks
			-- Lower wing slab: angled further downward and outward
			local wingLo = makePart(model, (if side < 0 then "WingLoL" else "WingLoR"),
				Vector3.new(0.26, 3.6 * sy, 1.30 * sz),
				at * CFrame.new(wx + side * 1.40, -1.8 * sy, 0.25)
					* CFrame.Angles(0.22, 0, side * 0.90), darkBark)
			wingLo.Material = Enum.Material.WoodPlanks
			-- Tip branch: tapered twig at the wing end for organic complexity
			local wingTip = makePart(model, (if side < 0 then "WingTipL" else "WingTipR"),
				Vector3.new(0.20, 2.0 * sy, 0.20),
				at * CFrame.new(wx + side * 3.0, -2.8 * sy, 0.5)
					* CFrame.Angles(0.30, 0.15, side * 1.10), darkBark)
			wingTip.Material = Enum.Material.WoodPlanks
		end
		-- Root-arm claws reaching toward the ground with multi-finger spread (key reference feature)
		local clawBase = Color3.fromRGB(38, 26, 12)
		for side = -1, 1, 2 do
			local cx = side * 2.1
			-- Main arm tendril
			local claw = makePart(model, if side < 0 then "LeftClaw" else "RightClaw",
				Vector3.new(0.45, 5.5, 0.45), at * CFrame.new(cx, -0.5, -0.4)
					* CFrame.Angles(0.18, 0, side * 0.18), clawBase)
			claw.Material = Enum.Material.WoodPlanks
			-- 4 root fingers fanning from the arm tip
			local fingerAngles = {-0.60, -0.20, 0.20, 0.60}
			for f, fAng in ipairs(fingerAngles) do
				local fLen = (1.40 - math.abs(fAng) * 0.35) * sy
				local finger = makePart(model, (if side < 0 then "LRootFinger" else "RRootFinger") .. f,
					Vector3.new(0.20, fLen, 0.20),
					at * CFrame.new(cx + fAng * 0.9 * sx, -3.40 - fLen * 0.5, -0.40)
						* CFrame.Angles(0.28, 0, side * fAng * 0.5), clawBase)
				finger.Material = Enum.Material.WoodPlanks
			end
		end
		for side = -1, 1, 2 do
			makePart(model, if side < 0 then "LeftLeg" else "RightLeg",
				Vector3.new(0.68, 4.2 * sy, 0.68),
				at * CFrame.new(side * sx, -(torsoSize.Y / 2 + 1.7 * sy), 0), presentation.accent)
		end
		-- Root-tendril toes at each leg tip: mirrors the arm root fingers (reference shows taloned feet)
		local toeAngles = {-0.48, -0.14, 0.14, 0.48}
		for side = -1, 1, 2 do
			local fx = side * sx
			local footY = -(torsoSize.Y / 2 + 3.8 * sy)
			for f, fAng in ipairs(toeAngles) do
				local tLen = (1.10 - math.abs(fAng) * 0.28) * sy
				local toe = makePart(model,
					(if side < 0 then "LToe" else "RToe") .. tostring(f),
					Vector3.new(0.18, tLen, 0.18),
					at * CFrame.new(fx + fAng * 0.70, footY - tLen * 0.5, fAng * 0.28)
						* CFrame.Angles(0.22, 0, side * fAng * 0.42),
					clawBase)
				toe.Material = Enum.Material.WoodPlanks
			end
		end
	elseif monsterId == "ShadowMonster" then
		-- Body and head are semi-transparent smoke — ForceField gives the right smoky shimmer
		root.Material = Enum.Material.ForceField
		root.Transparency = 0.38
		local smHead = model:FindFirstChild("Head") :: BasePart?
		if smHead then
			smHead.Material = Enum.Material.ForceField
			smHead.Transparency = 0.42
		end
		-- Override glowing eyes to white — classic "Hat Man" variant (glowing white eyes in darkness)
		local smEyeL = model:FindFirstChild("LeftGlow") :: BasePart?
		local smEyeR = model:FindFirstChild("RightGlow") :: BasePart?
		if smEyeL then smEyeL.Color = Color3.fromRGB(235, 240, 255) end
		if smEyeR then smEyeR.Color = Color3.fromRGB(235, 240, 255) end
		-- Wide-brim fedora hat — the iconic "Hat Man" silhouette from the reference
		local hatColor = Color3.fromRGB(8, 9, 14)
		makePart(model, "HatBrim", Vector3.new(headSize.X * 2.0 * sx, 0.35 * sy, headSize.Z * 2.0 * sz),
			at * CFrame.new(0, headY + headSize.Y / 2 * sy + 0.18 * sy, 0), hatColor)
		makePart(model, "HatCrown", Vector3.new(headSize.X * 1.15 * sx, headSize.Y * 0.72 * sy, headSize.Z * 1.10 * sz),
			at * CFrame.new(0, headY + headSize.Y / 2 * sy + 0.18 * sy + headSize.Y * 0.40 * sy, 0), hatColor)
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
				Vector3.new(0.35, 3.5 * sy, 0.35),
				at * CFrame.new(math.cos(angle) * 1.5, -(torsoSize.Y / 2 + 1.2 * sy), math.sin(angle) * 1.5)
					* CFrame.Angles(math.cos(angle) * 0.3, 0, math.sin(angle) * 0.3), presentation.accent)
			leg.Material = Enum.Material.ForceField
			leg.Transparency = 0.5
		end
	elseif monsterId == "Chupacabra" then
		-- Hide the generic upright arm-limbs so only the 4 legs show
		local ll = model:FindFirstChild("LeftLimb")
		local rl = model:FindFirstChild("RightLimb")
		if ll then ll.Transparency = 1; (ll :: BasePart).CanCollide = false end
		if rl then rl.Transparency = 1; (rl :: BasePart).CanCollide = false end
		-- Reference: large dark insect eyes (not blood-red glow) — override generic Neon eyes
		local chEyeL = model:FindFirstChild("LeftGlow") :: BasePart?
		local chEyeR = model:FindFirstChild("RightGlow") :: BasePart?
		if chEyeL then
			chEyeL.Color = Color3.fromRGB(6, 5, 7)
			chEyeL.Material = Enum.Material.SmoothPlastic
			chEyeL.Size = chEyeL.Size * 1.40
		end
		if chEyeR then
			chEyeR.Color = Color3.fromRGB(6, 5, 7)
			chEyeR.Material = Enum.Material.SmoothPlastic
			chEyeR.Size = chEyeR.Size * 1.40
		end
		for index = 1, 5 do
			local spine = makePart(model, "BackSpine" .. tostring(index),
				Vector3.new(0.28, 2.2 + index * 0.18, 0.55),
				at * CFrame.new(0, 1.5, -1.5 + index * 0.7) * CFrame.Angles(-0.12, 0, 0), presentation.accent)
			spine.Material = Enum.Material.SmoothPlastic
		end
		for side = -1, 1, 2 do
			for fore = -1, 1, 2 do
				local tag = (if side < 0 then "Left" else "Right") .. (if fore < 0 then "Front" else "Back")
				makePart(model, tag .. "Leg", Vector3.new(0.58, 2.6 * sy, 0.58),
					at * CFrame.new(side * 1.4 * sx, -(torsoSize.Y / 2 + 0.7 * sy), fore * 0.9 * sz)
						* CFrame.Angles(fore * 0.28, 0, side * 0.1), presentation.accent)
			end
		end
		-- Three-toed claws at each foot — hooked bone-ivory talons from the parchment reference
		local clawC = Color3.fromRGB(188, 172, 140)
		for side = -1, 1, 2 do
			for fore = -1, 1, 2 do
				local tag = (if side < 0 then "L" else "R") .. (if fore < 0 then "F" else "B")
				local footX = side * 1.4 * sx
				local footY = -(torsoSize.Y / 2 + 2.0 * sy) - 0.08 * sy
				local footZ = fore * 1.05 * sz
				for t = -1, 1 do
					local claw = makePart(model, "Claw" .. tag .. tostring(t + 2),
						Vector3.new(0.18 * sx, 0.15 * sy, 0.60 * sz),
						at * CFrame.new(footX + t * 0.22 * sx, footY, footZ + fore * 0.20 * sz),
						clawC)
					claw.Material = Enum.Material.SmoothPlastic
				end
			end
		end
		-- Curved whip tail arcing behind and upward: defining feature in reference image
		for s = 1, 5 do
			local tFrac = s / 5
			local tThick = (0.46 - tFrac * 0.26) * sx
			local chuTail = makePart(model, "Tail" .. tostring(s),
				Vector3.new(tThick, tThick, 0.88 * sz),
				at * CFrame.new(0,
					-(torsoSize.Y * 0.35) + s * 0.52 * sy,
					(torsoSize.Z * 0.54) + s * 0.75 * sz)
				* CFrame.Angles(-0.18 * s, 0, 0),
				presentation.accent)
			chuTail.Material = Enum.Material.SmoothPlastic
		end
		-- Protruding saber fangs curling from lower jaw (prominent in reference parchment drawing)
		local fangC = Color3.fromRGB(215, 208, 185)
		for side = -1, 1, 2 do
			local fang = makePart(model, "Fang" .. (if side < 0 then "L" else "R"),
				Vector3.new(0.28 * sx, 0.72 * sy, 0.22 * sx),
				at * CFrame.new(side * 0.38 * sx, headY - headSize.Y * 0.42, -(headSize.Z / 2 + 0.22))
					* CFrame.Angles(0.28, 0, side * 0.16), fangC)
			fang.Material = Enum.Material.SmoothPlastic
		end
		-- Large pointed ears rising from each side of the head (prominent in parchment drawing)
		for side = -1, 1, 2 do
			-- Outer ear shaft: tall narrow block leaning slightly outward
			local ear = makePart(model, "Ear" .. (if side < 0 then "L" else "R"),
				Vector3.new(0.36 * sx, 1.40 * sy, 0.28 * sx),
				at * CFrame.new(side * (headSize.X * 0.52 + 0.10), headY + headSize.Y * 0.62, 0)
					* CFrame.Angles(0, 0, side * 0.22), presentation.color)
			ear.Material = Enum.Material.SmoothPlastic
			-- Darker inner ear (concave feel)
			local earIn = makePart(model, "EarIn" .. (if side < 0 then "L" else "R"),
				Vector3.new(0.18 * sx, 1.00 * sy, 0.16 * sx),
				at * CFrame.new(side * (headSize.X * 0.52 + 0.10), headY + headSize.Y * 0.62, -0.06)
					* CFrame.Angles(0, 0, side * 0.22), Color3.fromRGB(42, 28, 30))
			earIn.Material = Enum.Material.SmoothPlastic
		end
	elseif monsterId == "Dullahan" then
		local head = model:FindFirstChild("Head")
		if head then
			head:Destroy()
		end
		makePart(model, "HeadlessCollar", Vector3.new(3.5, 0.7, 3),
			at * CFrame.new(0, torsoSize.Y / 2, 0), Color3.fromRGB(24, 31, 33))
		-- Cloak: narrow at the shoulders, belling out toward the ground (reference: tapered
		-- hooded silhouette, not a uniform slab). The taper comes from a slim shoulder width,
		-- outward-angled side panels, and a wider hem skirt at the base.
		local cloakColor = Color3.fromRGB(14, 17, 22)
		local cloakW = torsoSize.X * 1.55
		local cloakH = torsoSize.Y * 1.65
		-- Back panel
		makePart(model, "CloakBack", Vector3.new(cloakW, cloakH, 0.22),
			at * CFrame.new(0, -torsoSize.Y * 0.14, torsoSize.Z / 2 + 0.14), cloakColor)
		-- Front panel: closes the robe so no body shows through
		makePart(model, "CloakFront", Vector3.new(cloakW * 0.88, cloakH * 0.92, 0.20),
			at * CFrame.new(0, -torsoSize.Y * 0.18, -(torsoSize.Z / 2 + 0.14)), cloakColor)
		-- Side panels angled outward so the silhouette widens toward the ground
		for side = -1, 1, 2 do
			makePart(model, if side < 0 then "CloakL" else "CloakR",
				Vector3.new(0.24, cloakH, torsoSize.Z * 1.22),
				at * CFrame.new(side * (cloakW / 2 + 0.12), -torsoSize.Y * 0.16, 0)
					* CFrame.Angles(0, 0, side * 0.18), cloakColor)
		end
		-- Drooping sleeve hints hanging from the mid-cloak
		for side = -1, 1, 2 do
			makePart(model, if side < 0 then "SleeveL" else "SleeveR",
				Vector3.new(0.24, 3.4, 1.05),
				at * CFrame.new(side * (cloakW / 2 + 0.55), -torsoSize.Y * 0.02, -(torsoSize.Z * 0.18))
					* CFrame.Angles(0, 0, side * 0.55), cloakColor)
		end
		-- The generic monster limbs use the teal accent; with the slimmer cloak they peek
		-- out at the shoulders, so darken them to read as cloth folds instead
		local dlLimbL = model:FindFirstChild("LeftLimb") :: BasePart?
		local dlLimbR = model:FindFirstChild("RightLimb") :: BasePart?
		if dlLimbL then dlLimbL.Color = cloakColor end
		if dlLimbR then dlLimbR.Color = cloakColor end
		-- Hood: clearly narrower than the shoulders and pitched forward so the cowl droops
		local hoodW = cloakW * 0.58
		local hoodH = 3.6 * sy
		local hoodBotY = torsoSize.Y / 2 - 0.4
		local hoodPivot = at * CFrame.new(0, hoodBotY, 0) * CFrame.Angles(-0.14, 0, 0)
		makePart(model, "HoodBack", Vector3.new(hoodW, hoodH, 0.22),
			hoodPivot * CFrame.new(0, hoodH * 0.5, torsoSize.Z / 2 + 0.14), cloakColor)
		for hSide = -1, 1, 2 do
			makePart(model, "HoodSide" .. (if hSide < 0 then "L" else "R"),
				Vector3.new(0.24, hoodH, torsoSize.Z + 0.28),
				hoodPivot * CFrame.new(hSide * (hoodW * 0.5 + 0.12), hoodH * 0.5, 0), cloakColor)
		end
		makePart(model, "HoodTop", Vector3.new(hoodW + 0.44, 0.28, torsoSize.Z + 0.30),
			hoodPivot * CFrame.new(0, hoodH + 0.14, 0), cloakColor)
		-- Hood face: a frame around a recessed void so the cowl reads hollow
		-- (reference: dark empty opening where the head should be)
		local hoodFrontZ = -(torsoSize.Z / 2 + 0.14)
		makePart(model, "HoodBrow", Vector3.new(hoodW * 0.86, hoodH * 0.30, 0.20),
			hoodPivot * CFrame.new(0, hoodH * 0.79, hoodFrontZ), cloakColor)
		for hSide = -1, 1, 2 do
			makePart(model, "HoodJamb" .. (if hSide < 0 then "L" else "R"),
				Vector3.new(hoodW * 0.16, hoodH * 0.72, 0.20),
				hoodPivot * CFrame.new(hSide * hoodW * 0.35, hoodH * 0.28, hoodFrontZ), cloakColor)
		end
		makePart(model, "HoodVoid", Vector3.new(hoodW * 0.62, hoodH * 0.66, 0.16),
			hoodPivot * CFrame.new(0, hoodH * 0.30, -(torsoSize.Z / 2 - 0.55)), Color3.fromRGB(4, 5, 7))
		-- Spectral flame deep inside the hood void: faint teal glow from the hollow cowl
		local flame = makePart(model, "SpectralFlame", Vector3.new(1.4, 1.4, 1.4),
			hoodPivot * CFrame.new(0, hoodH * 0.30, -(torsoSize.Z / 2 - 1.05)),
			presentation.accent, Enum.PartType.Ball)
		flame.Material = Enum.Material.Neon
		-- Drooped peak folding over the brow
		makePart(model, "HoodPeak", Vector3.new(hoodW * 0.72, 0.26, 1.5),
			hoodPivot * CFrame.new(0, hoodH + 0.05, hoodFrontZ + 0.35) * CFrame.Angles(-0.55, 0, 0), cloakColor)
		-- Bottom hem flare: wide skirt that fans out at base for bell-shaped silhouette from reference
		local hemW = cloakW * 1.45
		local hemH = cloakH * 0.28
		local hemY = -(torsoSize.Y * 0.14 + cloakH * 0.58)
		makePart(model, "CloakHemFront", Vector3.new(hemW, hemH, 0.22),
			at * CFrame.new(0, hemY, -(torsoSize.Z / 2 + 0.14)), cloakColor)
		makePart(model, "CloakHemBack", Vector3.new(hemW, hemH, 0.22),
			at * CFrame.new(0, hemY, torsoSize.Z / 2 + 0.14), cloakColor)
		for side = -1, 1, 2 do
			makePart(model, if side < 0 then "CloakHemL" else "CloakHemR",
				Vector3.new(0.22, hemH, torsoSize.Z * 1.50),
				at * CFrame.new(side * (hemW / 2 + 0.12), hemY, 0), cloakColor)
		end
		-- Ragged trailing streamers below the hem (reference: tattered wisps at the ground)
		for i = 1, 7 do
			local fx = (i - 4) / 3
			local streamH = 1.3 + ((i * 37) % 5) * 0.32
			makePart(model, "HemStreamer" .. i,
				Vector3.new(0.55, streamH, 0.20),
				at * CFrame.new(fx * hemW * 0.44, hemY - hemH * 0.5 - streamH * 0.45, -(torsoSize.Z / 2 + 0.16))
					* CFrame.Angles(0, 0, fx * 0.12), cloakColor)
		end
		-- Legs hidden under cloak
		for side = -1, 1, 2 do
			local leg = makePart(model, if side < 0 then "LeftLeg" else "RightLeg",
				Vector3.new(0.88, 3.6 * sy, 0.88),
				at * CFrame.new(side * sx, -(torsoSize.Y / 2 + 1.45 * sy), 0), presentation.color)
			leg.Transparency = 0.8
		end
	elseif monsterId == "Entity" then
		-- Cthulhu/octopus: bulbous translucent mantle sitting on a skirt of curling
		-- tentacles (reference: octopus ink art with one large clock-face eye).
		-- The monster pivot spawns ~4 studs above the ground, so nothing may extend
		-- more than ~3.6 studs below the root or it ends up underground.
		root.Transparency = 1
		local entHead = model:FindFirstChild("Head") :: BasePart?
		if entHead then
			entHead:Destroy()
		end
		local entGlowL = model:FindFirstChild("LeftGlow")
		local entGlowR = model:FindFirstChild("RightGlow")
		if entGlowL then entGlowL:Destroy() end
		if entGlowR then entGlowR:Destroy() end
		-- Generic accent limbs become faint ether streams hugging the mantle
		for _, limbName in { "LeftLimb", "RightLimb" } do
			local limb = model:FindFirstChild(limbName) :: BasePart?
			if limb then
				limb.Color = presentation.color
				limb.Material = Enum.Material.ForceField
				limb.Transparency = 0.45
			end
		end
		-- Bulbous mantle dome with a smaller crown bump
		local mantle = makePart(model, "Mantle", Vector3.new(6.6 * sx, 4.3 * sy, 6.2 * sz),
			at * CFrame.new(0, 2.0, 0), presentation.color, Enum.PartType.Ball)
		mantle.Material = Enum.Material.ForceField
		mantle.Transparency = 0.12
		local crown = makePart(model, "MantleCrown", Vector3.new(4.2 * sx, 2.1 * sy, 3.8 * sz),
			at * CFrame.new(0, 4.5, 0.2), presentation.color, Enum.PartType.Ball)
		crown.Material = Enum.Material.ForceField
		crown.Transparency = 0.18
		-- One large clock-face eye on the mantle front (defining reference feature),
		-- keeping the red needle as the clock hand
		local eyeZ = -(6.2 * sz) / 2
		local sclera = makePart(model, "ClockEyeWhite", Vector3.new(2.5, 2.5, 0.6),
			at * CFrame.new(0, 2.6, eyeZ - 0.1), Color3.fromRGB(214, 224, 226), Enum.PartType.Ball)
		sclera.Material = Enum.Material.Neon
		sclera.Transparency = 0.25
		local iris = makePart(model, "ClockEyeIris", Vector3.new(1.35, 1.35, 0.5),
			at * CFrame.new(0, 2.6, eyeZ - 0.35), Color3.fromRGB(10, 12, 18), Enum.PartType.Ball)
		iris.Material = Enum.Material.SmoothPlastic
		makePart(model, "ClockEyeHand", Vector3.new(0.08, 0.85, 0.10),
			at * CFrame.new(0.12, 2.85, eyeZ - 0.42) * CFrame.Angles(0, 0, -0.55),
			Color3.fromRGB(195, 38, 38))
		-- Smaller eye organs scattered on the mantle (reference shows several)
		for i, eyeOff in ipairs({ { -1.85, 1.35 }, { 1.85, 1.5 }, { -1.15, 0.3 }, { 1.2, 0.15 } }) do
			local bodyEye = makePart(model, "BodyEye" .. i,
				Vector3.new(0.55, 0.55, 0.30),
				at * CFrame.new(eyeOff[1], eyeOff[2], eyeZ + 0.55),
				Color3.fromRGB(6, 6, 10), Enum.PartType.Ball)
			bodyEye.Material = Enum.Material.Neon
		end
		-- 3 bioluminescent anchor orbs on the crown
		for index = 1, 3 do
			local orb = makePart(model, "AnchorOrb" .. tostring(index),
				Vector3.new(0.75, 0.75, 0.75),
				at * CFrame.new((index - 2) * 2.0, 4.1 - (index % 2) * 0.5, eyeZ + 0.9),
				presentation.accent, Enum.PartType.Ball)
			orb.Material = Enum.Material.Neon
			orb.Transparency = 0.08
		end
		-- 8 two-segment tentacles curling out from under the mantle and pooling
		-- near the ground (octopus reference); tips stay above the pivot floor
		for index = 1, 8 do
			local angle = ((index - 1) / 8) * math.pi * 2
			local radial = at * CFrame.Angles(0, -angle, 0)
			local segLen1 = 2.7 + (index % 3) * 0.3
			local segLen2 = 2.5 + ((index + 1) % 3) * 0.3
			local bend1 = -0.52 - (index % 2) * 0.10
			local seg1CF = radial * CFrame.new(1.85, -0.4, 0) * CFrame.Angles(0, 0, bend1)
			local seg1 = makePart(model, "Tentacle" .. index .. "A", Vector3.new(0.72, segLen1, 0.72),
				seg1CF * CFrame.new(0, -segLen1 / 2, 0), presentation.color)
			seg1.Material = Enum.Material.ForceField
			seg1.Transparency = 0.18
			local seg2CF = seg1CF * CFrame.new(0, -segLen1, 0) * CFrame.Angles(0, 0, -0.62)
			local seg2 = makePart(model, "Tentacle" .. index .. "B", Vector3.new(0.56, segLen2, 0.56),
				seg2CF * CFrame.new(0, -segLen2 / 2, 0), presentation.color)
			seg2.Material = Enum.Material.ForceField
			seg2.Transparency = 0.22
			makePart(model, "TentacleTip" .. tostring(index),
				Vector3.new(0.40, 0.40, 0.40),
				seg2CF * CFrame.new(0, -segLen2, 0),
				presentation.accent, Enum.PartType.Ball).Material = Enum.Material.Neon
			-- Sucker rings along the lower segment (octopus reference: sucker disc rows)
			for si, f in ipairs({ 0.35, 0.75 }) do
				local ring = makePart(model, "SuckerRing" .. index .. "_" .. si,
					Vector3.new(0.58, 0.09, 0.58),
					seg2CF * CFrame.new(0, -segLen2 * f, 0),
					presentation.accent, Enum.PartType.Cylinder)
				ring.Material = Enum.Material.Neon
				ring.Transparency = 0.30
			end
		end
	elseif monsterId == "Banshee" then
		root.Transparency = 0.25
		-- Hollow dark eyes (the generic glow eyes render as white dots — too friendly)
		for _, eyeName in { "LeftGlow", "RightGlow" } do
			local bansheeEye = model:FindFirstChild(eyeName) :: BasePart?
			if bansheeEye then
				bansheeEye.Color = Color3.fromRGB(10, 10, 16)
				bansheeEye.Material = Enum.Material.SmoothPlastic
				bansheeEye.Size = Vector3.new(0.55, 0.55, 0.55)
			end
		end
		-- Open wailing mouth — the defining Banshee feature (large O scream). A Ball
		-- part renders at its smallest axis, so use a forward-facing cylinder disc
		-- for a tall dark oval on the visible head sphere (radius 1.2)
		local mouthGlow = makePart(model, "WailMouth",
			Vector3.new(0.30, 1.45 * sy * 0.66, 1.00 * sx),
			at * CFrame.new(0, headY - 0.55, -(headSize.Z / 2 - 0.05))
				* CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(12, 6, 14), Enum.PartType.Cylinder)
		mouthGlow.Material = Enum.Material.Neon
		mouthGlow.Transparency = 0.08
		-- Ghostly reaching arms: the generic accent limbs render as rigid white rods,
		-- so soften them into translucent spectral sleeves
		for _, limbName in { "LeftLimb", "RightLimb" } do
			local limb = model:FindFirstChild(limbName) :: BasePart?
			if limb then
				limb.Color = presentation.color
				limb.Material = Enum.Material.ForceField
				limb.Transparency = 0.30
			end
		end
		for side = -1, 1, 2 do
			local sleeve = makePart(model, if side < 0 then "SleeveL" else "SleeveR",
				Vector3.new(0.85, 1.9, 0.55),
				at * CFrame.new(side * 3.2, -2.2, 0) * CFrame.Angles(0, 0, side * 0.42),
				presentation.color)
			sleeve.Material = Enum.Material.ForceField
			sleeve.Transparency = 0.45
		end
		local veil = makePart(model, "SpectralVeil", Vector3.new(6, 6.5, 0.25),
			at * CFrame.new(0, 0.3, 1.35) * CFrame.Angles(0.18, 0, 0), presentation.accent)
		veil.Material = Enum.Material.ForceField
		veil.Transparency = 0.62
		-- Layered flowing hair: translucent cap, side falls past the shoulders, and an
		-- overlapping back cascade of wide waved panels (reference: wild flowing mane,
		-- not thin sticks)
		local hairC = presentation.accent
		local hairCap = makePart(model, "HairCap",
			Vector3.new(headSize.X * 1.14, headSize.Y * 0.62, headSize.Z * 1.14),
			at * CFrame.new(0, headY + 0.30, 0.10), hairC, Enum.PartType.Ball)
		hairCap.Material = Enum.Material.ForceField
		hairCap.Transparency = 0.22
		for side = -1, 1, 2 do
			local fall = makePart(model, if side < 0 then "HairFallL" else "HairFallR",
				Vector3.new(0.55, 2.5, 0.90),
				at * CFrame.new(side * (headSize.X * 0.42 + 0.18), headY - 1.25, 0.15)
					* CFrame.Angles(0, 0, side * 0.10), hairC)
			fall.Material = Enum.Material.ForceField
			fall.Transparency = 0.30
		end
		for index = 1, 4 do
			local spread = (index - 2.5) * 0.62 * sx
			local hairLen = 2.2 + (index % 2) * 0.8
			local wave = makePart(model, "HairBack" .. tostring(index),
				Vector3.new(0.72, hairLen, 0.30),
				at * CFrame.new(spread, headY - hairLen * 0.28, headSize.Z * 0.35 + index * 0.10)
					* CFrame.Angles(-0.42, 0, (index - 2.5) * 0.10), hairC)
			wave.Material = Enum.Material.ForceField
			wave.Transparency = 0.26 + index * 0.05
		end
		-- Trailing wail streams
		for index = 1, 3 do
			local offset = (index - 2) * 1.8 * sx
			local stream = makePart(model, "WailStream" .. tostring(index),
				Vector3.new(0.3, 4.0 * sy, 0.3),
				at * CFrame.new(offset, -(torsoSize.Y / 2 + 1.2 * sy), 0.4)
					* CFrame.Angles(0.15, 0, (index - 2) * 0.08), presentation.accent)
			stream.Material = Enum.Material.ForceField
			stream.Transparency = 0.5
		end
		-- Ornate corset bodice: structured metallic banding across the torso midsection
		local corsetC = Color3.fromRGB(88, 102, 122)
		for b = 1, 3 do
			local band = makePart(model, "CorsetBand" .. b,
				Vector3.new(torsoSize.X * 0.80, 0.28 * sy, torsoSize.Z + 0.10),
				at * CFrame.new(0, torsoSize.Y * (0.20 - b * 0.09), 0),
				corsetC)
			band.Material = Enum.Material.Metal
		end
		-- Flowing spectral gown from mid-torso downward (reference: long ethereal dress)
		local gownC = presentation.accent
		local gownUp = makePart(model, "GownUpper",
			Vector3.new(torsoSize.X * 1.20, torsoSize.Y * 0.58, torsoSize.Z * 1.14),
			at * CFrame.new(0, -(torsoSize.Y * 0.24), 0), gownC)
		gownUp.Material = Enum.Material.ForceField
		gownUp.Transparency = 0.44
		local gownLo = makePart(model, "GownLower",
			Vector3.new(torsoSize.X * 1.55, 2.6 * sy, torsoSize.Z * 1.38),
			at * CFrame.new(0, -(torsoSize.Y / 2 + 1.3 * sy), 0), gownC)
		gownLo.Material = Enum.Material.ForceField
		gownLo.Transparency = 0.58
		-- Chest brooch/medallion: ornate decorative piece prominent in reference image
		local brooch = makePart(model, "ChestBrooch",
			Vector3.new(0.58 * sx, 0.58 * sy, 0.20),
			at * CFrame.new(0, 0.55 * sy, -(torsoSize.Z / 2 + 0.11)),
			Color3.fromRGB(210, 225, 248), Enum.PartType.Ball)
		brooch.Material = Enum.Material.Neon
		brooch.Transparency = 0.10
		-- Ethereal sword raised in right-hand position — key visual from reference
		local blade = makePart(model, "SwordBlade", Vector3.new(0.22 * sx, 4.2 * sy, 0.1 * sz),
			at * CFrame.new(2.6 * sx, -1.2 * sy, -0.4 * sz) * CFrame.Angles(0.2, 0.1, -0.3), presentation.accent)
		blade.Material = Enum.Material.Neon
		blade.Transparency = 0.18
		makePart(model, "SwordGuard", Vector3.new(1.0 * sx, 0.22 * sy, 0.18 * sz),
			at * CFrame.new(2.6 * sx, 0.6 * sy, -0.4 * sz) * CFrame.Angles(0, 0.1, -0.3),
			Color3.fromRGB(200, 215, 235))
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
	local skinColor = BOT_SKIN_TONES[((index - 1) % #BOT_SKIN_TONES) + 1]
	local hairColor = HAIR_COLORS[((index - 1) % #HAIR_COLORS) + 1]

	local root = buildHumanoidBody(model, at, bodyColor, skinColor, scale, hairColor, index)
	model.PrimaryPart = root
	-- Counselor socks: tint to a pastel of the team colour for visual identity
	local lSock = model:FindFirstChild("LeftSock")  :: BasePart?
	local rSock = model:FindFirstChild("RightSock") :: BasePart?
	if lSock then lSock.Color  = bodyColor:Lerp(Color3.fromRGB(255, 255, 255), 0.68) end
	if rSock then rSock.Color  = bodyColor:Lerp(Color3.fromRGB(255, 255, 255), 0.68) end

	-- Match the R6 dims used inside buildHumanoidBody
	local th = 2 * scale
	local td = 1 * scale
	local hs = 2 * scale
	local headY = th / 2 + 0.15 * scale + hs / 2
	local aw = 1 * scale
	local ax = scale + aw / 2   -- tw/2 + aw/2 = scale + 0.5*scale
	-- Sleeve bands: colored stripe on upper arm unique to each counselor's team color
	local bandColor = bodyColor:Lerp(Color3.fromRGB(255, 255, 255), 0.28)
	local bandY = th / 2 - 0.40 * scale
	makePart(model, "SleeveBandL", Vector3.new(aw + 0.06, 0.22 * scale, aw + 0.06),
		at * CFrame.new(-ax, bandY, 0), bandColor)
	makePart(model, "SleeveBandR", Vector3.new(aw + 0.06, 0.22 * scale, aw + 0.06),
		at * CFrame.new( ax, bandY, 0), bandColor)

	if index == 1 then
		-- Radio clipped to hip: Director Holloway coordinates staff by radio
		makePart(model, "Radio", Vector3.new(0.55, scale, 0.35),
			at * CFrame.new(ax + 0.26, 0.3 * scale, -(td / 2 + 0.09)), Color3.fromRGB(34, 38, 42))
		makePart(model, "RadioAntenna", Vector3.new(0.09, 0.75 * scale, 0.09),
			at * CFrame.new(ax + 0.46, 0.9 * scale, -(td / 2 + 0.09)), Color3.fromRGB(55, 60, 65))
		-- Earpiece headset: field-commander ref shows headset + mic boom
		local hsetC = Color3.fromRGB(28, 28, 32)
		makePart(model, "Earpiece", Vector3.new(0.20 * scale, 0.22 * scale, 0.14),
			at * CFrame.new(-(hs / 2 + 0.06), headY + 0.04 * scale, -(hs * 0.22)),
			hsetC, Enum.PartType.Ball)
		makePart(model, "MicBoom", Vector3.new(0.07, 0.38 * scale, 0.07),
			at * CFrame.new(-(hs / 2 + 0.02), headY - 0.22 * scale, -(hs * 0.42)),
			hsetC)
		-- Clipboard with duty roster held at left side (Counselor 5 reference)
		local cbColor = Color3.fromRGB(148, 102, 58)
		makePart(model, "ClipBoard", Vector3.new(1.05 * scale, 1.45 * scale, 0.09),
			at * CFrame.new(-(ax + 0.16), 0.0 * scale, -(td / 2 + 0.10))
				* CFrame.Angles(0, 0.10, 0.14), cbColor)
		makePart(model, "ClipMetal", Vector3.new(0.52 * scale, 0.20 * scale, 0.12),
			at * CFrame.new(-(ax + 0.16), 0.76 * scale, -(td / 2 + 0.12))
				* CFrame.Angles(0, 0.10, 0.14), Color3.fromRGB(90, 92, 98))
		makePart(model, "ClipPage", Vector3.new(0.90 * scale, 1.20 * scale, 0.07),
			at * CFrame.new(-(ax + 0.16), -0.06 * scale, -(td / 2 + 0.14))
				* CFrame.Angles(0, 0.10, 0.14), Color3.fromRGB(235, 228, 215))
		-- Achievement medal on chest: Counslor 5 reference — director authority symbol
		makePart(model, "MedalRibbon", Vector3.new(0.18 * scale, 0.44 * scale, 0.06),
			at * CFrame.new(0.20 * scale, th / 2 - 0.44 * scale, -(td / 2 + 0.09)),
			Color3.fromRGB(175, 42, 42))
		local mdl = makePart(model, "Medal", Vector3.new(0.36 * scale, 0.36 * scale, 0.08),
			at * CFrame.new(0.20 * scale, th / 2 - 0.78 * scale, -(td / 2 + 0.09)),
			Color3.fromRGB(212, 178, 42), Enum.PartType.Ball)
		mdl.Material = Enum.Material.Metal
	elseif index == 2 then
		-- Medical pack + red cross on torso: Ortiz is Health & Safety
		makePart(model, "FirstAidPack", Vector3.new(2.0 * scale * 0.8, th * 0.5, 0.45),
			at * CFrame.new(0, 0.1, -(td / 2 + 0.24)), Color3.fromRGB(180, 185, 171))
		makePart(model, "CrossH", Vector3.new(2.0 * scale * 0.4, 0.18, 0.1),
			at * CFrame.new(0, 0.3, -(td / 2 + 0.5)), Color3.fromRGB(210, 48, 48))
		makePart(model, "CrossV", Vector3.new(0.18, th * 0.28, 0.1),
			at * CFrame.new(0, 0.3, -(td / 2 + 0.5)), Color3.fromRGB(210, 48, 48))
		-- Stethoscope: tube looped over the neck, disc resting on the chest
		local sColor = Color3.fromRGB(105, 105, 112)
		makePart(model, "StethoTubeL", Vector3.new(0.09, 0.75 * scale, 0.09),
			at * CFrame.new(-0.22 * scale, th / 2 - 0.28 * scale, -(td / 2 + 0.08))
				* CFrame.Angles(0.35, 0, -0.18), sColor)
		makePart(model, "StethoTubeR", Vector3.new(0.09, 0.75 * scale, 0.09),
			at * CFrame.new( 0.22 * scale, th / 2 - 0.28 * scale, -(td / 2 + 0.08))
				* CFrame.Angles(0.35, 0,  0.18), sColor)
		local disc = makePart(model, "StethoDisc", Vector3.new(0.26 * scale, 0.26 * scale, 0.08),
			at * CFrame.new(0, th / 2 - 0.72 * scale, -(td / 2 + 0.09)),
			Color3.fromRGB(78, 78, 85), Enum.PartType.Ball)
		disc.Material = Enum.Material.Metal
		-- Square-framed glasses matching the nurse reference image
		local gfC = Color3.fromRGB(30, 28, 36)
		local lensY = headY + 0.08 * scale
		local lensZ = -(hs / 2 + 0.04)
		makePart(model, "GlassLensL", Vector3.new(0.50 * scale, 0.34 * scale, 0.05),
			at * CFrame.new(-0.30 * scale, lensY, lensZ), gfC).Transparency = 0.72
		makePart(model, "GlassLensR", Vector3.new(0.50 * scale, 0.34 * scale, 0.05),
			at * CFrame.new( 0.30 * scale, lensY, lensZ), gfC).Transparency = 0.72
		makePart(model, "GlassBridge", Vector3.new(0.18 * scale, 0.06, 0.05),
			at * CFrame.new(0, lensY, lensZ), gfC)
		for side = -1, 1, 2 do
			makePart(model, "GlassTemple" .. (if side < 0 then "L" else "R"),
				Vector3.new(0.05, 0.46 * scale, 0.05),
				at * CFrame.new(side * 0.62 * scale, lensY, lensZ + 0.22), gfC)
		end
		-- Digital thermometer held at right side (Counselor 6 reference: Ortiz holds thermometer)
		local thermoC = Color3.fromRGB(238, 236, 232)
		makePart(model, "Thermometer", Vector3.new(0.12, 0.78 * scale, 0.12),
			at * CFrame.new(ax + 0.22, 0.18 * scale, -(td / 2 + 0.10))
				* CFrame.Angles(0, 0, 0.22), thermoC)
		makePart(model, "ThermoTip", Vector3.new(0.11, 0.20 * scale, 0.11),
			at * CFrame.new(ax + 0.27, 0.60 * scale, -(td / 2 + 0.11))
				* CFrame.Angles(0, 0, 0.22), Color3.fromRGB(210, 42, 42))
		-- Nurse Notes clipboard held at left side (Counselor 6 reference)
		local nbC = Color3.fromRGB(42, 74, 145)
		makePart(model, "NurseClipboard", Vector3.new(1.00 * scale, 1.35 * scale, 0.09),
			at * CFrame.new(-(ax + 0.14), 0.02 * scale, -(td / 2 + 0.10))
				* CFrame.Angles(0, -0.10, 0.12), nbC)
		makePart(model, "NurseClipMetal", Vector3.new(0.48 * scale, 0.18 * scale, 0.12),
			at * CFrame.new(-(ax + 0.14), 0.74 * scale, -(td / 2 + 0.12))
				* CFrame.Angles(0, -0.10, 0.12), Color3.fromRGB(88, 90, 96))
		-- RN badge lanyard clipped to chest
		local badgeC = Color3.fromRGB(218, 218, 228)
		makePart(model, "RNBadge", Vector3.new(0.36 * scale, 0.46 * scale, 0.06),
			at * CFrame.new(0.32 * scale, th / 2 - 0.52 * scale, -(td / 2 + 0.09)), badgeC)
		-- Blue/gold striped knit scarf: Counslor 6 reference — Ortiz wears scarf draped over shoulders
		local scarfNavy = Color3.fromRGB(28, 52, 128)
		local scarfGold = Color3.fromRGB(198, 162, 38)
		local scarfTopY = th / 2 - 0.10 * scale
		makePart(model, "ScarfNavy1", Vector3.new(1.08 * scale, 0.18 * scale, 0.08),
			at * CFrame.new(0, scarfTopY, -(td / 2 + 0.12)), scarfNavy)
		makePart(model, "ScarfGold1", Vector3.new(1.06 * scale, 0.16 * scale, 0.08),
			at * CFrame.new(0, scarfTopY - 0.20 * scale, -(td / 2 + 0.12)), scarfGold)
		makePart(model, "ScarfNavy2", Vector3.new(1.04 * scale, 0.18 * scale, 0.08),
			at * CFrame.new(0, scarfTopY - 0.40 * scale, -(td / 2 + 0.12)), scarfNavy)
		makePart(model, "ScarfTailL", Vector3.new(0.22 * scale, 0.80 * scale, 0.07),
			at * CFrame.new(-0.56 * scale, scarfTopY - 0.60 * scale, -(td / 2 + 0.10))
				* CFrame.Angles(0.08, 0, 0.12), scarfNavy)
		-- Fitness tracker on right wrist (Counslor 6 reference: dark smartwatch visible on wrist)
		local trY2 = -(th / 2 - 0.24 * scale)
		makePart(model, "FitnessTracker", Vector3.new(1.04 * scale, 0.22 * scale, 1.04 * scale),
			at * CFrame.new(ax, trY2, 0), Color3.fromRGB(18, 18, 22))
		local trScreen = makePart(model, "TrackerScreen", Vector3.new(0.28 * scale, 0.16 * scale, 0.08),
			at * CFrame.new(ax, trY2, -(0.54 * scale)), Color3.fromRGB(22, 88, 50))
		trScreen.Material = Enum.Material.Neon
		trScreen.Transparency = 0.22
	elseif index == 3 then
		-- Wide-brim ranger hat: Reed is the Outdoor Skills trail expert
		local hatBrimY = headY + hs / 2 + 0.15
		makePart(model, "RangerBrim", Vector3.new(hs * 1.75, 0.26, hs * 1.75),
			at * CFrame.new(0, hatBrimY, 0), Color3.fromRGB(72, 54, 36))
		makePart(model, "RangerCrown", Vector3.new(hs * 1.1, hs * 0.6, hs * 1.1),
			at * CFrame.new(0, hatBrimY + hs * 0.43, 0), Color3.fromRGB(82, 62, 42))
		-- Survival pack on back + shoulder straps: matches hiker/explorer reference images
		-- References 1-3 all show a forest/military green pack, not warm brown
		local bpColor = Color3.fromRGB(54, 72, 48)
		makePart(model, "BackpackBody", Vector3.new(1.28 * scale, 1.55 * scale, 0.55),
			at * CFrame.new(0, 0.12 * scale, td / 2 + 0.30), bpColor)
		makePart(model, "BackpackFlap", Vector3.new(1.14 * scale, 0.42 * scale, 0.52),
			at * CFrame.new(0, 0.12 * scale + 0.99 * scale, td / 2 + 0.28),
			Color3.fromRGB(42, 58, 36))
		makePart(model, "BpStrapL", Vector3.new(0.17, 1.26 * scale, 0.13),
			at * CFrame.new(-0.34 * scale, 0.10 * scale, -(td / 2 + 0.07))
			* CFrame.Angles(0.16, 0, 0.08), bpColor)
		makePart(model, "BpStrapR", Vector3.new(0.17, 1.26 * scale, 0.13),
			at * CFrame.new( 0.34 * scale, 0.10 * scale, -(td / 2 + 0.07))
			* CFrame.Angles(0.16, 0, -0.08), bpColor)
		-- Folded trail map held at the side: Reed is always reading the terrain
		local mapColor = Color3.fromRGB(212, 192, 128)
		makePart(model, "TrailMap", Vector3.new(1.10 * scale, 0.90 * scale, 0.06),
			at * CFrame.new(ax + 0.18, 0.0 * scale, -(td / 2 + 0.12))
				* CFrame.Angles(0, 0.12, 0.18), mapColor)
		makePart(model, "MapFold", Vector3.new(0.06, 0.90 * scale, 0.08),
			at * CFrame.new(ax + 0.18, 0.0 * scale, -(td / 2 + 0.12))
				* CFrame.Angles(0, 0.12, 0.18), Color3.fromRGB(168, 148, 88))
		-- Leather waist belt + buckle (Counslor 2 reference: prominent brown belt with large buckle)
		local beltC3 = Color3.fromRGB(82, 52, 28)
		makePart(model, "ReedBelt", Vector3.new(2.04 * scale, 0.24 * scale, td * 1.10),
			at * CFrame.new(0, -(th / 2 - 0.24 * scale), 0), beltC3)
		local reedBkl = makePart(model, "ReedBuckle", Vector3.new(0.40 * scale, 0.32 * scale, 0.12),
			at * CFrame.new(0, -(th / 2 - 0.24 * scale), -(td / 2 + 0.08)),
			Color3.fromRGB(172, 138, 44))
		reedBkl.Material = Enum.Material.Metal
		-- Dark explorer vest over khaki shirt (Counslor 3: open field vest with chest pockets)
		local vestC3 = Color3.fromRGB(52, 58, 48)
		makePart(model, "VestL", Vector3.new(0.70 * scale, th * 0.82, 0.10),
			at * CFrame.new(-0.60 * scale, 0.06 * scale, -(td / 2 + 0.09)), vestC3)
		makePart(model, "VestR", Vector3.new(0.70 * scale, th * 0.82, 0.10),
			at * CFrame.new( 0.60 * scale, 0.06 * scale, -(td / 2 + 0.09)), vestC3)
		for vSide = -1, 1, 2 do
			makePart(model, "VestPocket" .. (if vSide < 0 then "L" else "R"),
				Vector3.new(0.40 * scale, 0.36 * scale, 0.12),
				at * CFrame.new(vSide * 0.46 * scale, 0.22 * scale, -(td / 2 + 0.16)),
				Color3.fromRGB(44, 50, 40))
		end
		-- Rope coil clipped to top of backpack (Counslor 3 reference: coiled manila rope)
		local ropeC = Color3.fromRGB(188, 155, 78)
		local ropeY = 0.12 * scale + 0.99 * scale + 0.20
		local ropeZ = td / 2 + 0.30
		-- Outer ring of the coil (flat disc with axis pointing back)
		local ropeOuter = makePart(model, "RopeCoilOuter", Vector3.new(1.04 * scale, 0.36 * scale, 1.04 * scale),
			at * CFrame.new(-0.52 * scale, ropeY, ropeZ) * CFrame.Angles(math.rad(90), 0, 0),
			ropeC, Enum.PartType.Cylinder)
		ropeOuter.Material = Enum.Material.SmoothPlastic
		-- Darker inner fill to imply the hollow centre of the coil
		local ropeInner = makePart(model, "RopeCoilInner", Vector3.new(0.58 * scale, 0.38 * scale, 0.58 * scale),
			at * CFrame.new(-0.52 * scale, ropeY, ropeZ) * CFrame.Angles(math.rad(90), 0, 0),
			Color3.fromRGB(82, 62, 34), Enum.PartType.Cylinder)
		ropeInner.Material = Enum.Material.SmoothPlastic
	elseif index == 4 then
		-- Lanyard + whistle: Brooks runs camp activities
		makePart(model, "Lanyard", Vector3.new(0.1, 1.5 * scale, 0.08),
			at * CFrame.new(0, 0.1, -(td / 2 + 0.05)), Color3.fromRGB(218, 188, 68))
		makePart(model, "Whistle", Vector3.new(0.32, 0.46, 0.32),
			at * CFrame.new(0, -(th / 2 - 0.45), -(td / 2 + 0.28)), Color3.fromRGB(218, 188, 68), Enum.PartType.Ball)
		-- Camera body + lens: Brooks photographs every camp activity
		local camBody = makePart(model, "CameraBody", Vector3.new(0.62, 0.44, 0.34),
			at * CFrame.new(-0.28 * scale, -0.30 * scale, -(td / 2 + 0.19)), Color3.fromRGB(28, 28, 34))
		camBody.Material = Enum.Material.SmoothPlastic
		local camLens = makePart(model, "CameraLens", Vector3.new(0.24, 0.24, 0.22),
			at * CFrame.new(-0.28 * scale, -0.30 * scale, -(td / 2 + 0.36)), Color3.fromRGB(12, 12, 18),
			Enum.PartType.Ball)
		camLens.Material = Enum.Material.Glass
		-- Horizontal tank-top stripes: Counslor 4 reference — navy/red/white striped tank
		local stripeColors4 = {
			Color3.fromRGB(42, 58, 98),
			Color3.fromRGB(185, 50, 45),
			Color3.fromRGB(232, 228, 224),
		}
		local stripeYs4 = { th * 0.30, th * 0.05, -(th * 0.20) }
		for si = 1, 3 do
			makePart(model, "TankStripe" .. si,
				Vector3.new(1.72 * scale, 0.17 * scale, 0.06),
				at * CFrame.new(0, stripeYs4[si], -(td / 2 + 0.07)), stripeColors4[si])
		end
		-- Colorful beaded necklace (bohemian free-spirit reference)
		local beadColors = {
			Color3.fromRGB(215, 65, 65),
			Color3.fromRGB(52, 118, 215),
			Color3.fromRGB(62, 168, 68),
			Color3.fromRGB(212, 158, 42),
			Color3.fromRGB(168, 58, 185),
		}
		for i = 1, #beadColors do
			local bXOffset = (i - 3) * 0.28 * scale
			local bead = makePart(model, "Bead" .. i,
				Vector3.new(0.20, 0.20, 0.14),
				at * CFrame.new(bXOffset, th / 2 - 0.32 * scale, -(td / 2 + 0.09)),
				beadColors[i], Enum.PartType.Ball)
			bead.Material = Enum.Material.SmoothPlastic
		end
		-- Second bead strand (lower row): multi-strand necklace from Counslor 4 reference
		for i = 1, #beadColors do
			local bXOff2 = (i - 3) * 0.26 * scale
			local b2 = makePart(model, "Bead2x" .. i,
				Vector3.new(0.17, 0.17, 0.12),
				at * CFrame.new(bXOff2, th / 2 - 0.55 * scale, -(td / 2 + 0.10)),
				beadColors[i], Enum.PartType.Ball)
			b2.Material = Enum.Material.SmoothPlastic
		end
		-- Amethyst crystal cluster in right hand: Counslor 4 reference — held purple crystal
		local cryst = makePart(model, "CrystalCluster",
			Vector3.new(0.44 * scale, 0.54 * scale, 0.30 * scale),
			at * CFrame.new(ax + 0.14, -0.14 * scale, -(td / 2 + 0.14))
				* CFrame.Angles(0, 0, -0.28),
			Color3.fromRGB(148, 68, 195))
		cryst.Material = Enum.Material.Neon
		cryst.Transparency = 0.22
		local cryst2 = makePart(model, "CrystalShard",
			Vector3.new(0.22 * scale, 0.34 * scale, 0.17 * scale),
			at * CFrame.new(ax + 0.30, -0.04 * scale, -(td / 2 + 0.12))
				* CFrame.Angles(0, 0, -0.58),
			Color3.fromRGB(168, 88, 210))
		cryst2.Material = Enum.Material.Neon
		cryst2.Transparency = 0.25
	elseif index == 5 then
		-- Field journal tucked under left arm: Chen logs nature observations
		makePart(model, "FieldJournal", Vector3.new(1.15 * scale, 1.5 * scale, 0.26),
			at * CFrame.new(-(ax + 0.12), 0.0, -(td / 2 + 0.13)), Color3.fromRGB(75, 97, 72))
		makePart(model, "Bookmark", Vector3.new(0.12, 0.55 * scale, 0.08),
			at * CFrame.new(-(ax + 0.04), -(0.55 * scale), -(td / 2 + 0.13)), Color3.fromRGB(160, 48, 48))
		-- Wire-rimmed round glasses: lenses + bridge + temples
		local glassColor = Color3.fromRGB(88, 72, 48)
		local lensGY = headY + 0.08 * scale
		local lensGZ = -(hs / 2 + 0.04)
		makePart(model, "GlassLensL", Vector3.new(0.48 * scale, 0.38 * scale, 0.05),
			at * CFrame.new(-0.30 * scale, lensGY, lensGZ), glassColor, Enum.PartType.Ball).Transparency = 0.75
		makePart(model, "GlassLensR", Vector3.new(0.48 * scale, 0.38 * scale, 0.05),
			at * CFrame.new( 0.30 * scale, lensGY, lensGZ), glassColor, Enum.PartType.Ball).Transparency = 0.75
		makePart(model, "GlassBridge", Vector3.new(0.22 * scale, 0.07, 0.05),
			at * CFrame.new(0, lensGY, lensGZ), glassColor)
		for gSide = -1, 1, 2 do
			makePart(model, "GlassTemple" .. (if gSide < 0 then "L" else "R"),
				Vector3.new(0.05, 0.44 * scale, 0.05),
				at * CFrame.new(gSide * 0.62 * scale, lensGY, lensGZ + 0.20), glassColor)
		end
		-- Wide-brim khaki sun hat: field scientist working outdoors
		local hatKhaki = Color3.fromRGB(165, 148, 102)
		local hatBrimGY = headY + hs / 2 + 0.14
		makePart(model, "SunHatBrim", Vector3.new(hs * 1.80, 0.22 * scale, hs * 1.78),
			at * CFrame.new(0, hatBrimGY, 0), hatKhaki)
		makePart(model, "SunHatCrown", Vector3.new(hs * 1.05, hs * 0.52, hs * 1.05),
			at * CFrame.new(0, hatBrimGY + hs * 0.38, 0), Color3.fromRGB(148, 132, 88))
		-- Magnifying glass held in right hand: field examination tool
		local magC = Color3.fromRGB(88, 72, 48)
		local magX = ax + 0.18
		local magY = -0.05 * scale
		local magZ = -(td / 2 + 0.14)
		makePart(model, "MagHandle", Vector3.new(0.10, 0.70 * scale, 0.10),
			at * CFrame.new(magX, magY - 0.22 * scale, magZ)
				* CFrame.Angles(0, 0, 0.30), magC)
		local magRing = makePart(model, "MagRing", Vector3.new(0.50 * scale, 0.50 * scale, 0.08),
			at * CFrame.new(magX, magY + 0.18 * scale, magZ)
				* CFrame.Angles(0, 0, 0.30), magC, Enum.PartType.Ball)
		magRing.Transparency = 0.80
		local magLens = makePart(model, "MagLens", Vector3.new(0.38 * scale, 0.38 * scale, 0.05),
			at * CFrame.new(magX, magY + 0.18 * scale, magZ)
				* CFrame.Angles(0, 0, 0.30), Color3.fromRGB(190, 220, 205), Enum.PartType.Ball)
		magLens.Material = Enum.Material.Glass
		magLens.Transparency = 0.52
		-- Small specimen collection jar clipped to belt: "cataloging field samples"
		local jarC = Color3.fromRGB(175, 200, 192)
		local jarY5 = -(th / 2 - 0.42 * scale)
		local jarX5 = 0.62 * scale
		local jarZ5 = -(td / 2 + 0.20)
		local jarBody = makePart(model, "SpecimenJar", Vector3.new(0.36 * scale, 0.52 * scale, 0.36 * scale),
			at * CFrame.new(jarX5, jarY5, jarZ5), jarC, Enum.PartType.Ball)
		jarBody.Material = Enum.Material.Glass
		jarBody.Transparency = 0.55
		makePart(model, "JarLid", Vector3.new(0.38 * scale, 0.12 * scale, 0.38 * scale),
			at * CFrame.new(jarX5, jarY5 + 0.32 * scale, jarZ5), Color3.fromRGB(52, 82, 68))
	else
		-- Tool belt across waist: Finch handles waterfront gear and logistics
		makePart(model, "ToolBelt", Vector3.new(2 * scale * 1.06, 0.42, td * 1.08),
			at * CFrame.new(0, -(th / 2 - 0.2), 0), Color3.fromRGB(82, 61, 40))
		for i = -1, 1 do
			if i ~= 0 then
				makePart(model, "ToolPouch" .. tostring(i + 2), Vector3.new(0.42, 0.66, 0.32),
					at * CFrame.new(i * 0.6 * scale, -(th / 2 - 0.52), -(td / 2 + 0.17)), Color3.fromRGB(70, 52, 32))
			end
		end
		-- Adjustable wrench clipped to right side of belt
		local wrenchColor = Color3.fromRGB(80, 83, 94)
		local wrPart = makePart(model, "WrenchHandle", Vector3.new(0.13, 0.70 * scale, 0.12),
			at * CFrame.new(0.66 * scale, -(th / 2 - 0.58 * scale), -(td / 2 + 0.21)), wrenchColor)
		wrPart.Material = Enum.Material.Metal
		local wrJaw = makePart(model, "WrenchJaw", Vector3.new(0.32, 0.18, 0.12),
			at * CFrame.new(0.66 * scale, -(th / 2 - 0.58 * scale) + 0.37 * scale, -(td / 2 + 0.21)), wrenchColor)
		wrJaw.Material = Enum.Material.Metal
		-- Coffee mug held in left hand (Counselor 8 reference: contractor with mug)
		local mugC = Color3.fromRGB(232, 228, 220)
		makePart(model, "CoffeeMug", Vector3.new(0.44 * scale, 0.56 * scale, 0.44 * scale),
			at * CFrame.new(-(ax + 0.08), 0.10 * scale, -(td / 2 + 0.12)), mugC)
		makePart(model, "MugHandle", Vector3.new(0.12, 0.32 * scale, 0.08),
			at * CFrame.new(-(ax + 0.08) - 0.28 * scale, 0.10 * scale, -(td / 2 + 0.12)), mugC)
		local mugTop = makePart(model, "CoffeeSurface", Vector3.new(0.36 * scale, 0.06, 0.36 * scale),
			at * CFrame.new(-(ax + 0.08), 0.10 * scale + 0.31 * scale, -(td / 2 + 0.12)),
			Color3.fromRGB(42, 26, 12))
		mugTop.Material = Enum.Material.SmoothPlastic
		-- Wristwatch on left wrist: Counslor 8 reference — contractor wears watch
		local wristY = -(th / 2 - 0.26 * scale)
		makePart(model, "WatchFace", Vector3.new(0.32 * scale, 0.26 * scale, 0.32 * scale),
			at * CFrame.new(-ax, wristY, 0), Color3.fromRGB(24, 22, 30))
		makePart(model, "WatchBandT", Vector3.new(0.22 * scale, 0.12 * scale, 0.28 * scale),
			at * CFrame.new(-ax, wristY + 0.19 * scale, 0), Color3.fromRGB(28, 22, 18))
		makePart(model, "WatchBandB", Vector3.new(0.22 * scale, 0.12 * scale, 0.28 * scale),
			at * CFrame.new(-ax, wristY - 0.19 * scale, 0), Color3.fromRGB(28, 22, 18))
		-- Yellow tape measure on belt: Counslor 8 reference — DeWalt yellow tools
		local tapeMeas = makePart(model, "TapeMeasure", Vector3.new(0.38, 0.38, 0.26),
			at * CFrame.new(-0.68 * scale, -(th / 2 - 0.46), -(td / 2 + 0.22)),
			Color3.fromRGB(205, 165, 42))
		tapeMeas.Material = Enum.Material.SmoothPlastic
		-- Gold chain necklace: Counslor 8 reference — contractor wears gold chain
		local chn = makePart(model, "GoldChain",
			Vector3.new(0.88 * scale, 0.07 * scale, 0.80 * scale),
			at * CFrame.new(0, th / 2 - 0.36 * scale, 0), Color3.fromRGB(195, 158, 42))
		chn.Material = Enum.Material.Metal
	end

	-- Staff ID badge: colored card on a short cord around the neck
	local badgeCordColor = Color3.fromRGB(60, 60, 65)
	local badgeCardColor = Color3.fromRGB(240, 240, 245)
	makePart(model, "IDCord", Vector3.new(0.06, 0.55 * scale, 0.06),
		at * CFrame.new(0, th / 2 - 0.32 * scale, -(td / 2 + 0.07)), badgeCordColor)
	makePart(model, "IDCard", Vector3.new(0.32 * scale, 0.42 * scale, 0.07),
		at * CFrame.new(0, th / 2 - 0.60 * scale, -(td / 2 + 0.08)), badgeCardColor)

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

	local bodyColor = if roleName then (
		if roleName == "Camper"
			then CAMPER_OUTFIT_PALETTE[(nameHash(displayName) % #CAMPER_OUTFIT_PALETTE) + 1]
			else (BOT_BODY_COLORS[roleName] or Color3.fromRGB(55, 75, 65))
	) else COUNSELOR_COLORS[((colorIndex - 1) % #COUNSELOR_COLORS) + 1]
	local skinColor = BOT_SKIN_TONES[(nameHash(displayName) % #BOT_SKIN_TONES) + 1]
	-- Slight height variation so bots look like a crowd of different players
	local h = nameHash(displayName)
	local scale = 0.94 + (h % 17) * 0.01   -- range ~0.94–1.10
	local hairColor = HAIR_COLORS[(nameHash(displayName) % #HAIR_COLORS) + 1]

	local root = buildHumanoidBody(model, at, bodyColor, skinColor, scale, hairColor, h)
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

	-- Role-specific accessories so each bot is identifiable at a glance
	local hs = 2 * scale
	local headY = th / 2 + 0.15 * scale + hs / 2
	local ax = 1.5 * scale   -- arm center X (tw/2 + aw/2)
	if roleName == "Murderer" then
		-- Dark cowl draped over head
		makePart(model, "Hood",  Vector3.new(hs + 0.24, hs * 0.65, td + 0.22),
			at * CFrame.new(0, headY + hs * 0.175, 0), Color3.fromRGB(16, 12, 20))
		makePart(model, "HoodL", Vector3.new(0.16, hs * 0.85, td + 0.1),
			at * CFrame.new(-(hs / 2 + 0.12), headY, 0), Color3.fromRGB(22, 16, 28))
		makePart(model, "HoodR", Vector3.new(0.16, hs * 0.85, td + 0.1),
			at * CFrame.new(hs / 2 + 0.12, headY, 0), Color3.fromRGB(22, 16, 28))
		-- Glowing red eyes visible through the hood's shadows
		local murdEyeL = makePart(model, "MurdEyeL", Vector3.new(0.22 * scale, 0.18 * scale, 0.14),
			at * CFrame.new(-0.35 * scale, headY + 0.10 * scale, -(td / 2 + 0.04)), Color3.fromRGB(255, 28, 28))
		murdEyeL.Material = Enum.Material.Neon
		local murdEyeR = makePart(model, "MurdEyeR", Vector3.new(0.22 * scale, 0.18 * scale, 0.14),
			at * CFrame.new( 0.35 * scale, headY + 0.10 * scale, -(td / 2 + 0.04)), Color3.fromRGB(255, 28, 28))
		murdEyeR.Material = Enum.Material.Neon
		-- Sinister slow pulse — eyes dim and blaze on a 1.1 Hz cycle.
		-- 10 Hz updates: replication tops out around 20 Hz anyway, and a
		-- 1.1 Hz glow reads identically while writing 6x fewer properties.
		task.spawn(function()
			local pt = 0
			while murdEyeL.Parent ~= nil do
				local alpha = 0.04 + math.sin(pt * 1.1) * 0.08
				murdEyeL.Transparency = alpha
				murdEyeR.Transparency = alpha
				pt += task.wait(0.1)
			end
		end)
		-- Hip knife sheathed at the right side
		local kX = ax + 0.06 * scale
		local kY = -(th / 2) + 0.32 * scale
		local blade = makePart(model, "KnifeBlade",  Vector3.new(0.10 * scale, 0.56 * scale, 0.08 * scale),
			at * CFrame.new(kX, kY, 0), Color3.fromRGB(178, 184, 190))
		blade.Material = Enum.Material.Metal
		-- Tiny blood drip at the blade tip
		makePart(model, "BloodDrip", Vector3.new(0.06 * scale, 0.13 * scale, 0.06 * scale),
			at * CFrame.new(kX, kY - 0.33 * scale, 0), Color3.fromRGB(140, 18, 18))
		makePart(model, "KnifeGuard",  Vector3.new(0.26 * scale, 0.07 * scale, 0.12 * scale),
			at * CFrame.new(kX, kY + 0.30 * scale, 0), Color3.fromRGB(20, 14, 6))
		makePart(model, "KnifeHandle", Vector3.new(0.11 * scale, 0.22 * scale, 0.11 * scale),
			at * CFrame.new(kX, kY + 0.40 * scale, 0), Color3.fromRGB(52, 30, 12))
		-- Dark cloak draping from shoulders down the back
		makePart(model, "Cloak", Vector3.new(hs + 0.28, 2.0 * scale, 0.10),
			at * CFrame.new(0, -0.12 * scale, td / 2 + 0.08), Color3.fromRGB(10, 6, 16))
	elseif roleName == "Detective" then
		-- Classic flat-cap detective hat
		makePart(model, "DetBrim",  Vector3.new(hs * 1.55, 0.18 * scale, hs * 1.12),
			at * CFrame.new(-0.12, headY + hs / 2 + 0.09, 0), Color3.fromRGB(36, 30, 22))
		makePart(model, "DetCrown", Vector3.new(hs * 0.92, hs * 0.38, hs * 0.9),
			at * CFrame.new(0, headY + hs / 2 + 0.09 + hs * 0.19, 0), Color3.fromRGB(46, 38, 28))
		-- Magnifying glass clipped to the chest pocket (torso-attached, moves with PivotTo)
		local glassColor = Color3.fromRGB(180, 195, 215)
		local handleColor = Color3.fromRGB(90, 68, 40)
		local gX = 0.50 * scale
		local gY = th / 2 - 0.52 * scale
		local magGlass = makePart(model, "MagGlass", Vector3.new(0.50 * scale, 0.50 * scale, 0.10),
			at * CFrame.new(-gX, gY, -(td / 2 + 0.07)), Color3.fromRGB(195, 225, 255), Enum.PartType.Ball)
		magGlass.Material = Enum.Material.Glass
		magGlass.Transparency = 0.50
		-- Tiny neon glint at the lens centre
		local glint = makePart(model, "GlassGlint",
			Vector3.new(0.10 * scale, 0.10 * scale, 0.05),
			at * CFrame.new(-gX, gY + 0.08 * scale, -(td / 2 + 0.12)),
			Color3.fromRGB(240, 248, 255))
		glint.Material = Enum.Material.Neon
		glint.Transparency = 0.15
		makePart(model, "MagHandle", Vector3.new(0.12 * scale, 0.44 * scale, 0.10),
			at * CFrame.new(-gX + 0.14 * scale, gY - 0.42 * scale, -(td / 2 + 0.07)), handleColor)
		-- Overcoat lapels: two angled dark panels framing the chest
		local lapelColor = Color3.fromRGB(30, 24, 16)
		local lapelAngle = 0.44
		makePart(model, "LapelL", Vector3.new(0.16 * scale, 0.52 * scale, 0.10),
			at * CFrame.new(-0.22 * scale, th / 2 - 0.56 * scale, -(td / 2 + 0.09)) * CFrame.Angles(0, 0, -lapelAngle), lapelColor)
		makePart(model, "LapelR", Vector3.new(0.16 * scale, 0.52 * scale, 0.10),
			at * CFrame.new( 0.22 * scale, th / 2 - 0.56 * scale, -(td / 2 + 0.09)) * CFrame.Angles(0, 0,  lapelAngle), lapelColor)
	elseif roleName == "Medic" then
		-- Red cross on torso front with lub-dub heartbeat pulse
		local crossBaseColor = Color3.fromRGB(210, 44, 44)
		local crossBeatColor = Color3.fromRGB(255, 105, 105)
		local medCrossH = makePart(model, "MedCrossH", Vector3.new(0.84 * scale, 0.22 * scale, 0.1),
			at * CFrame.new(0, th / 2 - 0.5, -(td / 2 + 0.07)), crossBaseColor)
		local medCrossV = makePart(model, "MedCrossV", Vector3.new(0.22 * scale, 0.84 * scale, 0.1),
			at * CFrame.new(0, th / 2 - 0.5, -(td / 2 + 0.07)), crossBaseColor)
		task.spawn(function()
			-- 20 Hz keeps the short 0.12s lub-dub spikes intact while
			-- writing 3x fewer replicated color changes.
			local t = 0
			while medCrossH.Parent ~= nil do
				local cycle = t % 1.3
				local beat: number
				if cycle < 0.12 then
					beat = math.sin(cycle / 0.12 * math.pi)                   -- lub (strong)
				elseif cycle < 0.32 then
					beat = 0
				elseif cycle < 0.44 then
					beat = math.sin((cycle - 0.32) / 0.12 * math.pi) * 0.55  -- dub (softer)
				else
					beat = 0
				end
				local c = crossBaseColor:Lerp(crossBeatColor, beat)
				medCrossH.Color = c
				medCrossV.Color = c
				t += task.wait(0.05)
			end
		end)
		-- White medical shoes
		local medicLS = model:FindFirstChild("LeftShoe") :: BasePart?
		local medicRS = model:FindFirstChild("RightShoe") :: BasePart?
		if medicLS then medicLS.Color = Color3.fromRGB(225, 225, 225) end
		if medicRS then medicRS.Color = Color3.fromRGB(225, 225, 225) end
		-- Stethoscope: metallic disc + two diverging tubes
		local stethColor = Color3.fromRGB(178, 184, 192)
		local stHead = makePart(model, "StethHead", Vector3.new(0.24 * scale, 0.24 * scale, 0.07),
			at * CFrame.new(-0.18 * scale, th / 2 - 0.82 * scale, -(td / 2 + 0.08)), stethColor)
		stHead.Material = Enum.Material.Metal
		makePart(model, "StethTL", Vector3.new(0.06 * scale, 0.42 * scale, 0.07),
			at * CFrame.new(-0.28 * scale, th / 2 - 0.59 * scale, -(td / 2 + 0.06)) * CFrame.Angles(0, 0, -0.28), stethColor)
		makePart(model, "StethTR", Vector3.new(0.06 * scale, 0.42 * scale, 0.07),
			at * CFrame.new( 0.10 * scale, th / 2 - 0.59 * scale, -(td / 2 + 0.06)) * CFrame.Angles(0, 0,  0.28), stethColor)
	elseif roleName == "Guard" then
		-- Shoulder pauldrons: layered metal armor plates
		local padColor = Color3.fromRGB(60, 55, 45)
		local padL = makePart(model, "PadL", Vector3.new(scale + 0.2, scale * 0.5, scale + 0.2),
			at * CFrame.new(-ax, 0.6 * scale, 0), padColor)
		padL.Material = Enum.Material.Metal
		local padR = makePart(model, "PadR", Vector3.new(scale + 0.2, scale * 0.5, scale + 0.2),
			at * CFrame.new(ax, 0.6 * scale, 0), padColor)
		padR.Material = Enum.Material.Metal
		-- Raised rim at top of each pauldron gives armor-plating silhouette
		local rimColor = Color3.fromRGB(90, 82, 66)
		local rimH = scale * 0.09
		local rL = makePart(model, "PadRimL", Vector3.new(scale + 0.28, rimH, scale + 0.28),
			at * CFrame.new(-ax, 0.6 * scale + scale * 0.27, 0), rimColor)
		rL.Material = Enum.Material.Metal
		local rR = makePart(model, "PadRimR", Vector3.new(scale + 0.28, rimH, scale + 0.28),
			at * CFrame.new(ax, 0.6 * scale + scale * 0.27, 0), rimColor)
		rR.Material = Enum.Material.Metal
		-- Tactical helmet with tinted night-vision visor
		local helmColor = Color3.fromRGB(24, 30, 24)
		makePart(model, "Helmet", Vector3.new(hs * 1.12, hs * 0.56, hs * 1.06),
			at * CFrame.new(0, headY + hs * 0.12, 0), helmColor)
		local visor = makePart(model, "Visor", Vector3.new(hs * 0.90, hs * 0.22, 0.08),
			at * CFrame.new(0, headY - hs * 0.08, -(hs / 2 + 0.05)), Color3.fromRGB(22, 80, 35))
		visor.Material = Enum.Material.Neon
		visor.Transparency = 0.55
		-- Tactical neon status strip on left chest (like a body-cam LED)
		local tacStrip = makePart(model, "TacStrip", Vector3.new(0.07 * scale, 0.75 * scale, 0.07),
			at * CFrame.new(-0.38 * scale, th / 2 - 0.65 * scale, -(td / 2 + 0.09)),
			Color3.fromRGB(22, 200, 60))
		tacStrip.Material = Enum.Material.Neon
		tacStrip.Transparency = 0.18
	elseif roleName == "Protector" then
		-- Silver diamond badge on chest
		local badgeColor = Color3.fromRGB(192, 198, 210)
		local badge = makePart(model, "Badge", Vector3.new(0.52 * scale, 0.52 * scale, 0.08 * scale),
			at * CFrame.new(0, th / 2 - 0.45 * scale, -(td / 2 + 0.05 * scale)) * CFrame.Angles(0, 0, math.pi / 4), badgeColor)
		badge.Material = Enum.Material.Metal
		-- Occasional light-catch shimmer: badge brightens briefly then fades back
		task.spawn(function()
			local baseColor = badge.Color
			local shimmerColor = baseColor:Lerp(Color3.fromRGB(255, 255, 255), 0.68)
			while badge.Parent ~= nil do
				task.wait(5 + math.random() * 7)
				if badge.Parent == nil then return end
				for step = 1, 5 do
					if badge.Parent == nil then return end
					badge.Color = baseColor:Lerp(shimmerColor, math.sin(step / 5 * math.pi))
					task.wait(0.04)
				end
				badge.Color = baseColor
			end
		end)
		-- Silver shoulder plates completing the protective armor look
		local shldColor = Color3.fromRGB(190, 196, 208)
		local shldL = makePart(model, "ShldL", Vector3.new(0.52 * scale, 0.14 * scale, 0.64 * scale),
			at * CFrame.new(-ax, th / 2 + 0.03 * scale, 0), shldColor)
		shldL.Material = Enum.Material.Metal
		local shldR = makePart(model, "ShldR", Vector3.new(0.52 * scale, 0.14 * scale, 0.64 * scale),
			at * CFrame.new( ax, th / 2 + 0.03 * scale, 0), shldColor)
		shldR.Material = Enum.Material.Metal
	elseif roleName == "Medium" then
		-- Glowing crystal orb at chest level
		local orb = makePart(model, "CrystalOrb", Vector3.new(0.50 * scale, 0.50 * scale, 0.50 * scale),
			at * CFrame.new(0, th / 2 - 0.5 * scale, -(td / 2 + 0.30 * scale)), Color3.fromRGB(170, 85, 245), Enum.PartType.Ball)
		orb.Material = Enum.Material.Neon
		orb.Transparency = 0.20
		-- Neon summoning disc glowing below the orb
		local aura = makePart(model, "OrbAura", Vector3.new(0.82 * scale, 0.05 * scale, 0.82 * scale),
			at * CFrame.new(0, th / 2 - 0.67 * scale, -(td / 2 + 0.30 * scale)), Color3.fromRGB(200, 100, 255))
		aura.Material = Enum.Material.Neon
		aura.Transparency = 0.28
		-- Mystical slow glow pulse — orb breathes between nearly opaque and
		-- bright. 10 Hz is indistinguishable for a 1.75 Hz sine.
		task.spawn(function()
			local pt = 0
			while orb.Parent ~= nil do
				orb.Transparency = 0.10 + math.sin(pt * 1.75) * 0.15
				pt += task.wait(0.1)
			end
		end)
		-- Smaller satellite orb offset from the main crystal
		local miniOrb = makePart(model, "MiniOrb",
			Vector3.new(0.26 * scale, 0.26 * scale, 0.26 * scale),
			at * CFrame.new(0.38 * scale, th / 2 - 0.38 * scale, -(td / 2 + 0.28 * scale)),
			Color3.fromRGB(220, 140, 255), Enum.PartType.Ball)
		miniOrb.Material = Enum.Material.Neon
		miniOrb.Transparency = 0.30
	elseif roleName == "Camper" then
		-- styleSlot is the same index used to pick bodyColor from CAMPER_OUTFIT_PALETTE,
		-- so accessories always match the outfit colour.
		local styleSlot = nameHash(displayName) % 12
		local cLS = model:FindFirstChild("LeftShoe")  :: BasePart?
		local cRS = model:FindFirstChild("RightShoe") :: BasePart?

		-- Shared: backpack tinted to the outfit colour (skipped for Pixel Creeper who goes full-costume)
		if styleSlot ~= 10 then
			local packColor  = bodyColor:Lerp(Color3.fromRGB(30, 30, 30), 0.35)
			local strapColor = bodyColor:Lerp(Color3.fromRGB(15, 15, 15), 0.50)
			makePart(model, "Backpack", Vector3.new(1.40 * scale, 1.60 * scale, 0.48 * scale),
				at * CFrame.new(0, th / 2 - 0.80 * scale, td / 2 + 0.26 * scale), packColor)
			makePart(model, "StrapL", Vector3.new(0.14 * scale, 1.60 * scale, 0.10 * scale),
				at * CFrame.new(-0.44 * scale, th / 2 - 0.80 * scale, 0.10 * scale), strapColor)
			makePart(model, "StrapR", Vector3.new(0.14 * scale, 1.60 * scale, 0.10 * scale),
				at * CFrame.new( 0.44 * scale, th / 2 - 0.80 * scale, 0.10 * scale), strapColor)
			makePart(model, "WaterBottle", Vector3.new(0.22 * scale, 0.60 * scale, 0.22 * scale),
				at * CFrame.new(0.76 * scale, th / 2 - 1.10 * scale, td / 2 + 0.26 * scale),
				Color3.fromRGB(45, 125, 175))
			makePart(model, "WBottleCap", Vector3.new(0.18 * scale, 0.08 * scale, 0.18 * scale),
				at * CFrame.new(0.76 * scale, th / 2 - 0.78 * scale, td / 2 + 0.26 * scale),
				Color3.fromRGB(22, 58, 80))
		end

		if styleSlot == 0 then
			-- Teal Classic: dark sneakers, simple teal snapback
			if cLS then cLS.Color = Color3.fromRGB(24, 20, 24) end
			if cRS then cRS.Color = Color3.fromRGB(24, 20, 24) end
			-- Golden blonde hair (Girl Camper.jpg reference: straight blonde hair)
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and string.sub(p.Name, 1, 4) == "Hair" then
					(p :: BasePart).Color = Color3.fromRGB(212, 178, 88)
				end
			end
			makePart(model, "CapCrown", Vector3.new(hs * 1.04, 0.30 * scale, hs * 0.98),
				at * CFrame.new(0, headY + hs / 2 + 0.15 * scale, 0), Color3.fromRGB(35, 128, 118))
			makePart(model, "CapBand", Vector3.new(hs * 1.06, 0.11 * scale, hs * 1.00),
				at * CFrame.new(0, headY + hs / 2 + 0.005 * scale, 0), Color3.fromRGB(22, 90, 82))
			-- Denim shorts: Girl Camper.jpg reference shows blue-grey denim shorts on legs
			local ll0 = model:FindFirstChild("LeftLeg")  :: BasePart?
			local rl0 = model:FindFirstChild("RightLeg") :: BasePart?
			local denimGrey = Color3.fromRGB(105, 118, 148)
			if ll0 then ll0.Color = denimGrey end
			if rl0 then rl0.Color = denimGrey end

		elseif styleSlot == 1 then
			-- Glitter Bow: white high-tops + oversized bow on head (Girl Camper 2: blush-pink hair)
			if cLS then cLS.Color = Color3.fromRGB(232, 230, 235) end
			if cRS then cRS.Color = Color3.fromRGB(232, 230, 235) end
			-- Blush pink/cream hair matching Girl Camper 2 reference (all hair parts)
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and string.sub(p.Name, 1, 4) == "Hair" then
					(p :: BasePart).Color = Color3.fromRGB(238, 208, 215)
				end
			end
			local bowPink = Color3.fromRGB(238, 88, 168)
			makePart(model, "BowL", Vector3.new(0.90 * scale, 0.70 * scale, 0.22 * scale),
				at * CFrame.new(-0.54 * scale, headY + hs * 0.60, -hs * 0.08)
					* CFrame.Angles(0, 0, 0.36), bowPink)
			makePart(model, "BowR", Vector3.new(0.90 * scale, 0.70 * scale, 0.22 * scale),
				at * CFrame.new( 0.54 * scale, headY + hs * 0.60, -hs * 0.08)
					* CFrame.Angles(0, 0, -0.36), bowPink)
			makePart(model, "BowKnot", Vector3.new(0.28 * scale, 0.28 * scale, 0.24 * scale),
				at * CFrame.new(0, headY + hs * 0.62, -hs * 0.08),
				Color3.fromRGB(255, 138, 195), Enum.PartType.Ball)
			-- Gold layered chain necklace (Girl Camper 2 reference: prominent stacked chains)
			local gcGold = Color3.fromRGB(212, 176, 42)
			local gcY = th / 2 + 0.04 * scale
			local gcO = makePart(model, "ChainOuter", Vector3.new(1.14 * scale, 0.07 * scale, 1.00 * scale),
				at * CFrame.new(0, gcY, 0), gcGold)
			gcO.Material = Enum.Material.Metal
			local gcI = makePart(model, "ChainInner", Vector3.new(0.86 * scale, 0.06 * scale, 0.70 * scale),
				at * CFrame.new(0, gcY - 0.16 * scale, 0), gcGold)
			gcI.Material = Enum.Material.Metal
			local gcP = makePart(model, "ChainPendant", Vector3.new(0.16 * scale, 0.20 * scale, 0.07),
				at * CFrame.new(0, gcY - 0.34 * scale, -(td / 2 + 0.07)), gcGold, Enum.PartType.Ball)
			gcP.Material = Enum.Material.Metal
			-- White crop top with pink trim band (Girl Camper 2 reference)
			makePart(model, "CropTop1", Vector3.new(1.84 * scale, th * 0.44, 0.09),
				at * CFrame.new(0, th * 0.14, -(td / 2 + 0.07)), Color3.fromRGB(238, 234, 240))
			makePart(model, "CropTrim1", Vector3.new(1.86 * scale, 0.14 * scale, 0.10),
				at * CFrame.new(0, th * 0.14 - th * 0.22 - 0.07 * scale, -(td / 2 + 0.08)),
				Color3.fromRGB(225, 80, 155))
			-- Skin legs: Girl Camper 2 shows bare thighs above short denim cutoffs
			local ll1 = model:FindFirstChild("LeftLeg")  :: BasePart?
			local rl1 = model:FindFirstChild("RightLeg") :: BasePart?
			if ll1 then ll1.Color = skinColor end
			if rl1 then rl1.Color = skinColor end
			-- Denim cutoff shorts: waistband + short panel below (Girl Camper 2: visible denim shorts)
			local denimBlue = Color3.fromRGB(118, 142, 182)
			makePart(model, "DenimWaist", Vector3.new(2.04 * scale, 0.28 * scale, td * 1.06),
				at * CFrame.new(0, -(th / 2 - 0.14 * scale), 0), denimBlue)
			makePart(model, "DenimShort", Vector3.new(1.98 * scale, 0.52 * scale, td * 1.04),
				at * CFrame.new(0, -(th / 2 + 0.26 * scale), 0), Color3.fromRGB(105, 128, 168))
			-- Striped knee socks: pink/blue/white bands (very prominent in Girl Camper 2 reference)
			local sock1Y = -(th / 2 + 1.08 * scale)
			local lx1 = 0.5 * scale
			local sockColors1 = {
				Color3.fromRGB(218, 82, 148),
				Color3.fromRGB(78, 98, 195),
				Color3.fromRGB(232, 228, 235),
			}
			for side1 = -1, 1, 2 do
				local sx1 = side1 * lx1
				for bi, bc in ipairs(sockColors1) do
					makePart(model, "GlitterSock" .. (if side1 < 0 then "L" else "R") .. bi,
						Vector3.new(1.12 * scale, 0.19 * scale, 1.12 * scale),
						at * CFrame.new(sx1, sock1Y - (bi - 1) * 0.20 * scale, 0), bc)
				end
			end

		elseif styleSlot == 2 then
			-- Flower Crown Girl: black high-tops, floral crown + gold earrings
			if cLS then cLS.Color = Color3.fromRGB(22, 18, 22) end
			if cRS then cRS.Color = Color3.fromRGB(22, 18, 22) end
			-- Very dark chocolate-brown hair (Girl Camper 3 reference: deep dark-brown long hair)
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and string.sub(p.Name, 1, 4) == "Hair" then
					(p :: BasePart).Color = Color3.fromRGB(48, 24, 8)
				end
			end
			-- Pink + daisy flower hair clips on each side of head (Girl Camper 3 reference: not a crown)
			local clipPink = Color3.fromRGB(228, 95, 148)
			for hSide = -1, 1, 2 do
				local clipX = hSide * (hs / 2 + 0.06)
				local clipFlower = makePart(model, "HairClip" .. (if hSide < 0 then "L" else "R"),
					Vector3.new(0.30 * scale, 0.30 * scale, 0.20),
					at * CFrame.new(clipX, headY + hs * 0.20, 0), clipPink, Enum.PartType.Ball)
				clipFlower.Material = Enum.Material.SmoothPlastic
				makePart(model, "ClipCenter" .. (if hSide < 0 then "L" else "R"),
					Vector3.new(0.13 * scale, 0.13 * scale, 0.16),
					at * CFrame.new(clipX, headY + hs * 0.20, 0), Color3.fromRGB(252, 248, 238), Enum.PartType.Ball)
			end
			-- Gold drop earrings at ear positions
			for side = -1, 1, 2 do
				local earring = makePart(model, "Earring" .. (if side < 0 then "L" else "R"),
					Vector3.new(0.15, 0.22 * scale, 0.13),
					at * CFrame.new(side * (hs / 2 + 0.06), headY - hs * 0.14, -hs * 0.18),
					Color3.fromRGB(212, 170, 36), Enum.PartType.Ball)
				earring.Material = Enum.Material.Metal
			end
			-- Pink crop top panel (reference: pink "RoBlux" short crop tee)
			makePart(model, "PinkCropTop", Vector3.new(1.76 * scale, th * 0.38, 0.08),
				at * CFrame.new(0, th * 0.20, -(td / 2 + 0.07)), Color3.fromRGB(228, 128, 162))
			-- Skin-colored legs: Girl Camper 3 shows bare thighs under short floral skirt
			local ll2 = model:FindFirstChild("LeftLeg")  :: BasePart?
			local rl2 = model:FindFirstChild("RightLeg") :: BasePart?
			if ll2 then ll2.Color = skinColor end
			if rl2 then rl2.Color = skinColor end
			-- Dark floral mini skirt: front + back panels (poofy wrap-around look)
			local skirtDark = Color3.fromRGB(26, 18, 24)
			local skirtCY = -(th / 2 + 0.30 * scale)
			local skirtRuffleWhite = Color3.fromRGB(238, 232, 236)
			for _, skZ in ipairs({ -(td / 2 + 0.08), (td / 2 + 0.08) }) do
				makePart(model, "SkirtPanel" .. tostring(skZ > 0),
					Vector3.new(2.06 * scale, 0.72 * scale, 0.10),
					at * CFrame.new(0, skirtCY, skZ), skirtDark)
				makePart(model, "SkirtRuffle" .. tostring(skZ > 0),
					Vector3.new(2.14 * scale, 0.17 * scale, 0.10),
					at * CFrame.new(0, skirtCY - 0.47 * scale, skZ + (if skZ < 0 then -0.01 else 0.01)),
					skirtRuffleWhite)
			end
			for side2 = -1, 1, 2 do
				local rose2 = makePart(model, "SkirtRose" .. (if side2 < 0 then "L" else "R"),
					Vector3.new(0.22 * scale, 0.22 * scale, 0.10),
					at * CFrame.new(side2 * 0.42 * scale, skirtCY + 0.04 * scale, -(td / 2 + 0.10)),
					Color3.fromRGB(205, 80, 125), Enum.PartType.Ball)
				rose2.Material = Enum.Material.SmoothPlastic
			end
			-- Small charm pendant necklace (Girl Camper 3 reference: small pendant at upper chest)
			local charmChain = makePart(model, "CharmChain", Vector3.new(0.74 * scale, 0.05 * scale, 0.68 * scale),
				at * CFrame.new(0, th / 2 - 0.32 * scale, 0), Color3.fromRGB(195, 192, 205))
			charmChain.Material = Enum.Material.Metal
			local charm = makePart(model, "CharmPendant", Vector3.new(0.16 * scale, 0.18 * scale, 0.07),
				at * CFrame.new(0, th / 2 - 0.44 * scale, -(td / 2 + 0.09)),
				Color3.fromRGB(245, 238, 195), Enum.PartType.Ball)
			charm.Material = Enum.Material.Metal
			-- Black/white striped knee socks visible above shoes
			local sockY2 = -(th / 2 + 1.15 * scale)
			local lxS2 = 0.5 * scale
			for band = 0, 1 do
				local bC2 = if band == 0 then Color3.fromRGB(20, 16, 20) else Color3.fromRGB(232, 228, 232)
				makePart(model, "SockL" .. band, Vector3.new(1.12 * scale, 0.19 * scale, 1.12 * scale),
					at * CFrame.new(-lxS2, sockY2 - band * 0.21 * scale, 0), bC2)
				makePart(model, "SockR" .. band, Vector3.new(1.12 * scale, 0.19 * scale, 1.12 * scale),
					at * CFrame.new( lxS2, sockY2 - band * 0.21 * scale, 0), bC2)
			end

		elseif styleSlot == 3 then
			-- Denim Overalls: denim-blue sneakers, overall bib + suspenders, sun pendant
			if cLS then cLS.Color = Color3.fromRGB(105, 132, 168) end
			if cRS then cRS.Color = Color3.fromRGB(105, 132, 168) end
			-- Sandy-blonde hair (Girl Camper 4 reference: warm sandy/cream hair)
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and string.sub(p.Name, 1, 4) == "Hair" then
					(p :: BasePart).Color = Color3.fromRGB(192, 160, 95)
				end
			end
			-- Washed denim (lighter than body color, matching Girl Camper 4 reference)
			local denimBlue = Color3.fromRGB(132, 165, 200)
			-- White/grey striped under-shirt visible at torso sides (Girl Camper 4 ref)
			makePart(model, "UnderShirt", Vector3.new(1.88 * scale, th * 0.70, 0.09),
				at * CFrame.new(0, th * 0.04, -(td / 2 + 0.07)), Color3.fromRGB(232, 232, 232))
			for si = 0, 2 do
				makePart(model, "ShirtStripe" .. si, Vector3.new(1.86 * scale, 0.09 * scale, 0.10),
					at * CFrame.new(0, th * (0.20 - si * 0.18), -(td / 2 + 0.08)),
					Color3.fromRGB(195, 195, 198))
			end
			makePart(model, "OverallBib", Vector3.new(1.55 * scale, th * 0.50, 0.10),
				at * CFrame.new(0, th * 0.25, -(td / 2 + 0.09)), denimBlue)
			-- Chest pocket on bib (Girl Camper 4 reference: small pocket on front of bib)
			makePart(model, "BibPocket", Vector3.new(0.50 * scale, 0.35 * scale, 0.10),
				at * CFrame.new(0, th * 0.28, -(td / 2 + 0.10)), Color3.fromRGB(115, 148, 185))
			makePart(model, "SuspL", Vector3.new(0.18, th * 0.44, 0.10),
				at * CFrame.new(-0.44 * scale, th * 0.22, -(td / 2 + 0.08))
					* CFrame.Angles(0, 0, 0.22), denimBlue)
			makePart(model, "SuspR", Vector3.new(0.18, th * 0.44, 0.10),
				at * CFrame.new( 0.44 * scale, th * 0.22, -(td / 2 + 0.08))
					* CFrame.Angles(0, 0, -0.22), denimBlue)
			-- Gold buckle clips where suspenders meet bib top (Girl Camper 4 ref: yellow buckles)
			local buckleGold = Color3.fromRGB(215, 172, 42)
			for bSide = -1, 1, 2 do
				local bkl = makePart(model, "Buckle" .. (if bSide < 0 then "L" else "R"),
					Vector3.new(0.18 * scale, 0.12 * scale, 0.12),
					at * CFrame.new(bSide * 0.44 * scale, th * 0.44, -(td / 2 + 0.11)), buckleGold)
				bkl.Material = Enum.Material.Metal
			end
			local sun = makePart(model, "SunPendant", Vector3.new(0.26 * scale, 0.26 * scale, 0.07),
				at * CFrame.new(0, th / 2 - 0.38 * scale, -(td / 2 + 0.09)),
				Color3.fromRGB(220, 188, 58))
			sun.Material = Enum.Material.Metal
			-- Bare skin legs below denim shorts (Girl Camper 4: shorts-length overalls)
			local ll3 = model:FindFirstChild("LeftLeg")  :: BasePart?
			local rl3 = model:FindFirstChild("RightLeg") :: BasePart?
			if ll3 then ll3.Color = skinColor end
			if rl3 then rl3.Color = skinColor end
			-- Denim overall short leg panels (sitting over skin-colored legs, mid-thigh length)
			local overLegH = 0.80 * scale
			local overLegY = -(th / 2 + overLegH / 2 + 0.04 * scale)
			local lx3 = 0.50 * scale
			makePart(model, "OverLegL", Vector3.new(1.05 * scale, overLegH, 1.05 * scale),
				at * CFrame.new(-lx3, overLegY, 0), denimBlue)
			makePart(model, "OverLegR", Vector3.new(1.05 * scale, overLegH, 1.05 * scale),
				at * CFrame.new( lx3, overLegY, 0), denimBlue)

		elseif styleSlot == 4 then
			-- Frog Hoodie: white sneakers + daisy-print bucket hat + frog chest emblem + green socks
			if cLS then cLS.Color = Color3.fromRGB(228, 228, 232) end
			if cRS then cRS.Color = Color3.fromRGB(228, 228, 232) end
			-- Sage/mint green hair (Girl Camper 5 reference: distinctive sage-green wavy hair)
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and string.sub(p.Name, 1, 4) == "Hair" then
					(p :: BasePart).Color = Color3.fromRGB(110, 162, 115)
				end
			end
			local frogGreen = Color3.fromRGB(42, 148, 52)
			makePart(model, "BucketBrim", Vector3.new(hs * 1.55, 0.14 * scale, hs * 1.55),
				at * CFrame.new(0, headY + hs / 2 + 0.08, 0), frogGreen)
			makePart(model, "BucketCrown", Vector3.new(hs * 1.02, hs * 0.55, hs * 1.00),
				at * CFrame.new(0, headY + hs / 2 + 0.08 + hs * 0.33, 0), Color3.fromRGB(36, 138, 46))
			-- White daisy accents on hat brim
			for side = -1, 1, 2 do
				makePart(model, "Daisy" .. (if side < 0 then "L" else "R"),
					Vector3.new(0.24 * scale, 0.15, 0.24 * scale),
					at * CFrame.new(side * 0.38 * scale, headY + hs / 2 + 0.16, -(hs * 0.54)),
					Color3.fromRGB(245, 245, 245), Enum.PartType.Ball)
			end
			-- Frog face emblem on chest
			local frogFace = makePart(model, "FrogFace", Vector3.new(0.42 * scale, 0.40 * scale, 0.10),
				at * CFrame.new(0, th * 0.18, -(td / 2 + 0.08)), frogGreen, Enum.PartType.Ball)
			frogFace.Material = Enum.Material.SmoothPlastic
			makePart(model, "FrogEyeL", Vector3.new(0.14 * scale, 0.14 * scale, 0.10),
				at * CFrame.new(-0.14 * scale, th * 0.22, -(td / 2 + 0.14)),
				Color3.fromRGB(18, 18, 18), Enum.PartType.Ball)
			makePart(model, "FrogEyeR", Vector3.new(0.14 * scale, 0.14 * scale, 0.10),
				at * CFrame.new( 0.14 * scale, th * 0.22, -(td / 2 + 0.14)),
				Color3.fromRGB(18, 18, 18), Enum.PartType.Ball)
			-- Grey cuffed shorts: Girl Camper 5 reference shows light-grey shorts, not green legs
			local llFrog = model:FindFirstChild("LeftLeg")  :: BasePart?
			local rlFrog = model:FindFirstChild("RightLeg") :: BasePart?
			local greyShort = Color3.fromRGB(175, 175, 180)
			if llFrog then llFrog.Color = greyShort end
			if rlFrog then rlFrog.Color = greyShort end
			-- Gold chain necklace: Girl Camper 5 reference shows thin gold chain at neck
			local frogChain = makePart(model, "FrogNecklace",
				Vector3.new(0.82 * scale, 0.07 * scale, 0.78 * scale),
				at * CFrame.new(0, th / 2 - 0.36 * scale, 0), Color3.fromRGB(195, 162, 42))
			frogChain.Material = Enum.Material.Metal
			-- Green + white knee-high socks (prominent in Girl Camper 5 reference image)
			local frogSockG = Color3.fromRGB(62, 168, 72)
			local sockTopY4 = -(th / 2 + 1.10 * scale)
			local lxS4 = 0.5 * scale
			for side4 = -1, 1, 2 do
				local sLx4 = side4 * lxS4
				makePart(model, "KSockTop" .. (if side4 < 0 then "L" else "R"),
					Vector3.new(1.12 * scale, 0.22 * scale, 1.12 * scale),
					at * CFrame.new(sLx4, sockTopY4, 0), frogSockG)
				makePart(model, "KSockMid" .. (if side4 < 0 then "L" else "R"),
					Vector3.new(1.12 * scale, 0.20 * scale, 1.12 * scale),
					at * CFrame.new(sLx4, sockTopY4 - 0.22 * scale, 0), Color3.fromRGB(232, 232, 236))
				makePart(model, "KSockBot" .. (if side4 < 0 then "L" else "R"),
					Vector3.new(1.12 * scale, 0.18 * scale, 1.12 * scale),
					at * CFrame.new(sLx4, sockTopY4 - 0.42 * scale, 0), frogSockG)
			end

		elseif styleSlot == 5 then
			-- Cat Onesie: onesie-color shoes + full cat hood with face + ear + stripe details
			if cLS then cLS.Color = bodyColor end
			if cRS then cRS.Color = bodyColor end
			-- Dark chocolate-brown hair visible below/around hood (Girl Camper 6 reference)
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and string.sub(p.Name, 1, 4) == "Hair" then
					(p :: BasePart).Color = Color3.fromRGB(68, 38, 12)
				end
			end
			-- Full cat hood dome enclosing head
			makePart(model, "CatHood", Vector3.new(hs * 1.14, hs * 1.08, hs * 1.08),
				at * CFrame.new(0, headY, 0), bodyColor, Enum.PartType.Ball)
			-- Cat ears on top of hood
			makePart(model, "CatEarL", Vector3.new(0.32 * scale, 0.44 * scale, 0.14),
				at * CFrame.new(-0.44 * scale, headY + hs * 0.68, 0), bodyColor)
			makePart(model, "CatEarR", Vector3.new(0.32 * scale, 0.44 * scale, 0.14),
				at * CFrame.new( 0.44 * scale, headY + hs * 0.68, 0), bodyColor)
			local catInnerPink = Color3.fromRGB(210, 145, 158)
			makePart(model, "CatEarInL", Vector3.new(0.16 * scale, 0.24 * scale, 0.12),
				at * CFrame.new(-0.44 * scale, headY + hs * 0.68, -0.04), catInnerPink)
			makePart(model, "CatEarInR", Vector3.new(0.16 * scale, 0.24 * scale, 0.12),
				at * CFrame.new( 0.44 * scale, headY + hs * 0.68, -0.04), catInnerPink)
			-- Cat face: nose on front of hood
			makePart(model, "CatNose", Vector3.new(0.11 * scale, 0.09 * scale, 0.10),
				at * CFrame.new(0, headY + 0.02 * scale, -(hs * 0.56)),
				Color3.fromRGB(185, 75, 105), Enum.PartType.Ball)
			-- Whisker lines (2 per side)
			for side = -1, 1, 2 do
				for w = 0, 1 do
					makePart(model, "Wsk" .. (if side < 0 then "L" else "R") .. w,
						Vector3.new(0.40 * scale, 0.04, 0.04),
						at * CFrame.new(side * 0.30 * scale, headY - 0.08 * scale + w * 0.14 * scale, -(hs * 0.54)),
						Color3.fromRGB(32, 22, 18))
				end
			end
			-- Dark tabby stripe band on torso front
			local catDark = Color3.fromRGB(96, 52, 22)
			makePart(model, "CatStripe1", Vector3.new(1.78 * scale, 0.16, 0.10),
				at * CFrame.new(0, -(th * 0.08), -(td / 2 + 0.09)), catDark)
			makePart(model, "CatStripe2", Vector3.new(1.78 * scale, 0.14, 0.10),
				at * CFrame.new(0, -(th * 0.30), -(td / 2 + 0.09)), catDark)
			-- Tabby stripe rings on legs: Girl Camper 6 reference shows stripes extending down legs
			-- lh = 2*scale, ly = -(th/2 + lh/2) = -(2*scale); mirroring buildHumanoidBody dims
			local catLy = -(th / 2 + 1 * scale)
			local catLx = 0.5 * scale
			local catLsw = 1.08 * scale
			for side5 = -1, 1, 2 do
				local sX5 = side5 * catLx
				for si5, yOff5 in ipairs({ 0.60, 0, -0.55 }) do
					makePart(model, "CatLegStr" .. (if side5 < 0 then "L" else "R") .. si5,
						Vector3.new(catLsw, 0.14, catLsw),
						at * CFrame.new(sX5, catLy + yOff5 * scale, 0), catDark)
				end
			end

		elseif styleSlot == 6 then
			-- Axolotl Hood: purple shoes, pink hood with fan gills, white hoodie body + navy accents
			if cLS then cLS.Color = Color3.fromRGB(118, 98, 198) end
			if cRS then cRS.Color = Color3.fromRGB(118, 98, 198) end
			local axPink = Color3.fromRGB(255, 168, 198)
			-- Main axolotl hood dome — centered on head so it wraps all the way to chin
			makePart(model, "AxolotlBody", Vector3.new(hs * 1.14, hs * 1.10, hs * 1.08),
				at * CFrame.new(0, headY, 0), axPink, Enum.PartType.Ball)
			-- 4 gill fins per side, fanning upward from about eye-level (corrected from old above-head pos)
			local gillData = {
				{x = 0.52, y = 0.08, angZ = -0.18},
				{x = 0.60, y = 0.24, angZ = -0.44},
				{x = 0.58, y = 0.40, angZ = -0.68},
				{x = 0.46, y = 0.54, angZ = -0.92},
			}
			for i, g in ipairs(gillData) do
				local sz = Vector3.new(0.20 * scale, (0.46 - i * 0.05) * scale, 0.10)
				local gt = 0.18 + i * 0.05
				local gL = makePart(model, "GillL" .. i, sz,
					at * CFrame.new(-hs * g.x, headY + hs * g.y, 0) * CFrame.Angles(0, 0, g.angZ), axPink)
				gL.Transparency = gt
				local gR = makePart(model, "GillR" .. i, sz,
					at * CFrame.new( hs * g.x, headY + hs * g.y, 0) * CFrame.Angles(0, 0, -g.angZ), axPink)
				gR.Transparency = gt
			end
			-- Axolotl hood eyes (on front face of the hood, corrected Y to match new dome center)
			makePart(model, "AxolotlEyeL", Vector3.new(0.14 * scale, 0.14 * scale, 0.10),
				at * CFrame.new(-0.28 * scale, headY + hs * 0.18, -(hs * 0.52)),
				Color3.fromRGB(28, 20, 20), Enum.PartType.Ball)
			makePart(model, "AxolotlEyeR", Vector3.new(0.14 * scale, 0.14 * scale, 0.10),
				at * CFrame.new( 0.28 * scale, headY + hs * 0.18, -(hs * 0.52)),
				Color3.fromRGB(28, 20, 20), Enum.PartType.Ball)
			-- Pink blush spots on axolotl cheeks (visible in reference image)
			local axSpotPink = Color3.fromRGB(228, 108, 148)
			for spSide = -1, 1, 2 do
				local axSpot = makePart(model, "AxSpot" .. (if spSide < 0 then "L" else "R"),
					Vector3.new(0.20 * scale, 0.20 * scale, 0.08),
					at * CFrame.new(spSide * 0.38 * scale, headY - hs * 0.06, -(hs * 0.53)),
					axSpotPink, Enum.PartType.Ball)
				axSpot.Transparency = 0.18
			end
			-- Cute squiggle smile mouth (Boy Camper.jpg: happy ":)" face on the axolotl hood)
			local axMouthC = Color3.fromRGB(188, 85, 115)
			for smSide = -1, 1, 2 do
				makePart(model, "AxMouth" .. (if smSide < 0 then "L" else "R"),
					Vector3.new(0.22 * scale, 0.10 * scale, 0.08),
					at * CFrame.new(smSide * 0.16 * scale, headY - hs * 0.18, -(hs * 0.54))
						* CFrame.Angles(0, 0, smSide * 0.36), axMouthC)
			end
			-- White hoodie body with navy side accents + orange pockets
			local navyBlue = Color3.fromRGB(38, 58, 128)
			makePart(model, "HoodieFront", Vector3.new(1.78 * scale, th * 0.90, 0.11),
				at * CFrame.new(0, 0, -(td / 2 + 0.08)), Color3.fromRGB(240, 238, 232))
			makePart(model, "HoodieAccL", Vector3.new(0.40 * scale, th * 0.90, 0.11),
				at * CFrame.new(-0.70 * scale, 0, -(td / 2 + 0.09)), navyBlue)
			makePart(model, "HoodieAccR", Vector3.new(0.40 * scale, th * 0.90, 0.11),
				at * CFrame.new( 0.70 * scale, 0, -(td / 2 + 0.09)), navyBlue)
			makePart(model, "PocketL", Vector3.new(0.44 * scale, 0.38 * scale, 0.12),
				at * CFrame.new(-0.42 * scale, -(th * 0.26), -(td / 2 + 0.11)), Color3.fromRGB(215, 132, 38))
			makePart(model, "PocketR", Vector3.new(0.44 * scale, 0.38 * scale, 0.12),
				at * CFrame.new( 0.42 * scale, -(th * 0.26), -(td / 2 + 0.11)), Color3.fromRGB(215, 132, 38))
			-- Dark brown pants: Boy Camper.jpg reference shows maroon/dark-brown legs below hoodie
			local ll6 = model:FindFirstChild("LeftLeg")  :: BasePart?
			local rl6 = model:FindFirstChild("RightLeg") :: BasePart?
			local axBrown = Color3.fromRGB(82, 48, 38)
			if ll6 then ll6.Color = axBrown end
			if rl6 then rl6.Color = axBrown end
			-- Pink hoodie drawstring from axolotl hood (Boy Camper.jpg: visible pink cord)
			local axCordC = Color3.fromRGB(238, 138, 178)
			makePart(model, "AxDrawL", Vector3.new(0.07, th * 0.56, 0.07),
				at * CFrame.new(-0.18 * scale, -(th * 0.08), -(td / 2 + 0.10))
					* CFrame.Angles(0.20, 0, -0.06), axCordC)
			makePart(model, "AxDrawR", Vector3.new(0.07, th * 0.56, 0.07),
				at * CFrame.new( 0.18 * scale, -(th * 0.08), -(td / 2 + 0.10))
					* CFrame.Angles(0.20, 0,  0.06), axCordC)

		elseif styleSlot == 7 then
			-- Tactical Vest: amber work boots, grey vest over orange shirt (Boy Camper 1 reference — no hat)
			if cLS then cLS.Color = Color3.fromRGB(195, 138, 48) end
			if cRS then cRS.Color = Color3.fromRGB(195, 138, 48) end
			-- Medium brown hair (Boy Camper 1 reference: clearly visible brown hair, no hat)
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and string.sub(p.Name, 1, 4) == "Hair" then
					(p :: BasePart).Color = Color3.fromRGB(88, 48, 18)
				end
			end
			-- Orange shirt base layer visible at collar and vest sides (reference shows orange shirt under grey vest)
			makePart(model, "OrangeShirt", Vector3.new(2.0 * scale, th * 0.78, 0.10),
				at * CFrame.new(0, 0.08, -(td / 2 + 0.07)), Color3.fromRGB(218, 138, 28))
			-- Grey tactical vest narrower than shirt so orange shows on sides (reference: open-front vest)
			makePart(model, "VestFront", Vector3.new(2.0 * scale * 0.72, th * 0.65, 0.12),
				at * CFrame.new(0, 0.15, -(td / 2 + 0.09)), Color3.fromRGB(75, 80, 72))
			makePart(model, "VestPouchL", Vector3.new(0.55 * scale, 0.55 * scale, 0.14),
				at * CFrame.new(-0.52 * scale, 0.32, -(td / 2 + 0.17)), Color3.fromRGB(58, 62, 55))
			makePart(model, "VestPouchR", Vector3.new(0.55 * scale, 0.55 * scale, 0.14),
				at * CFrame.new( 0.52 * scale, 0.32, -(td / 2 + 0.17)), Color3.fromRGB(58, 62, 55))
			-- Action camera clipped to left chest vest panel (matching Boy Camper 1 reference)
			local camC = Color3.fromRGB(22, 22, 22)
			local gopro = makePart(model, "ActionCam", Vector3.new(0.34 * scale, 0.26 * scale, 0.20),
				at * CFrame.new(-0.28 * scale, th * 0.26, -(td / 2 + 0.23)), camC)
			gopro.Material = Enum.Material.SmoothPlastic
			local goproLens = makePart(model, "CamLens", Vector3.new(0.16 * scale, 0.16 * scale, 0.08),
				at * CFrame.new(-0.28 * scale, th * 0.26, -(td / 2 + 0.33)),
				Color3.fromRGB(12, 12, 20), Enum.PartType.Ball)
			goproLens.Material = Enum.Material.Glass
			-- Black tactical glove on left hand (Boy Camper 1 reference detail)
			makePart(model, "TacGloveL", Vector3.new(0.88 * scale, 0.66 * scale, 0.88 * scale),
				at * CFrame.new(-ax, -(th / 2 + 0.46 * scale), 0), Color3.fromRGB(14, 14, 18))
			-- Dark teardrop pendant on a cord (reference: black pendant at chest center)
			local pendC7 = Color3.fromRGB(16, 16, 20)
			local pendY7 = th / 2 - 0.40 * scale
			makePart(model, "TacCord", Vector3.new(0.05 * scale, 0.52 * scale, 0.05 * scale),
				at * CFrame.new(0, pendY7, -(td / 2 + 0.08)), pendC7)
			local pendant7 = makePart(model, "TacPendant", Vector3.new(0.18 * scale, 0.26 * scale, 0.12),
				at * CFrame.new(0, pendY7 - 0.30 * scale, -(td / 2 + 0.08)), pendC7, Enum.PartType.Ball)
			pendant7.Material = Enum.Material.SmoothPlastic
			-- Black tactical pants: Boy Camper 1 reference shows black pants under orange shirt
			local ll7 = model:FindFirstChild("LeftLeg")  :: BasePart?
			local rl7 = model:FindFirstChild("RightLeg") :: BasePart?
			local tacBlack = Color3.fromRGB(24, 22, 28)
			if ll7 then ll7.Color = tacBlack end
			if rl7 then rl7.Color = tacBlack end
			-- Right wrist guard band (Boy Camper 1 ref: black strap on right wrist)
			makePart(model, "WristGuard", Vector3.new(0.90 * scale, 0.26 * scale, 0.90 * scale),
				at * CFrame.new(ax, -(th / 2 - 0.20 * scale), 0), Color3.fromRGB(18, 18, 22))
			-- Dark knee pads on both legs (Boy Camper 1 reference: tactical knee guards)
			local kpC = Color3.fromRGB(18, 18, 22)
			local kpY = -(th / 2 + 0.82 * scale)
			for kSide = -1, 1, 2 do
				makePart(model, "KneePad" .. (if kSide < 0 then "L" else "R"),
					Vector3.new(1.06 * scale, 0.44 * scale, 1.04 * scale),
					at * CFrame.new(kSide * 0.5 * scale, kpY, 0), kpC)
			end

		elseif styleSlot == 8 then
			-- Flannel & Headphones: white sneakers, teal headphones, white inner hoodie
			if cLS then cLS.Color = Color3.fromRGB(228, 228, 232) end
			if cRS then cRS.Color = Color3.fromRGB(228, 228, 232) end
			-- Dark brown wavy hair (Boy Camper 2 reference: brown hair visible around headphones)
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and string.sub(p.Name, 1, 4) == "Hair" then
					(p :: BasePart).Color = Color3.fromRGB(75, 38, 14)
				end
			end
			-- White inner hoodie panel visible where flannel opens (reference: white hoodie under plaid)
			makePart(model, "InnerHoodie", Vector3.new(1.20 * scale, th * 0.96, 0.09),
				at * CFrame.new(0, 0, -(td / 2 + 0.08)), Color3.fromRGB(238, 236, 232))
			-- Teal plaid flannel overlay: horizontal teal + cream stripes across the outer torso
			local plaidTeal = Color3.fromRGB(68, 158, 182)
			local plaidCream = Color3.fromRGB(228, 222, 208)
			local stripeH = 0.20 * scale
			local stripeYs = { th * 0.35, th * 0.10, -(th * 0.15), -(th * 0.40) }
			local stripeCols = { plaidTeal, plaidCream, plaidTeal, plaidCream }
			-- Split left+right panels so the inner white hoodie shows through the open centre
			for si, syv in ipairs(stripeYs) do
				for pSide = -1, 1, 2 do
					makePart(model, "PlaidStripe" .. si .. (if pSide < 0 then "L" else "R"),
						Vector3.new(0.76 * scale, stripeH, 0.08),
						at * CFrame.new(pSide * 0.64 * scale, syv, -(td / 2 + 0.10)), stripeCols[si])
				end
			end
			-- Vertical plaid bar (crosshatch) on each side panel
			for bSide = -1, 1, 2 do
				makePart(model, "PlaidBar" .. (if bSide < 0 then "L" else "R"),
					Vector3.new(0.18 * scale, th * 0.90, 0.08),
					at * CFrame.new(bSide * 0.72 * scale, 0, -(td / 2 + 0.11)), plaidTeal)
			end
			-- Hoodie drawstrings hanging from neck
			local cordC = Color3.fromRGB(195, 192, 188)
			makePart(model, "DrawL", Vector3.new(0.06, th * 0.52, 0.06),
				at * CFrame.new(-0.22 * scale, -(th * 0.06), -(td / 2 + 0.09))
					* CFrame.Angles(0.22, 0, -0.08), cordC)
			makePart(model, "DrawR", Vector3.new(0.06, th * 0.52, 0.06),
				at * CFrame.new( 0.22 * scale, -(th * 0.06), -(td / 2 + 0.09))
					* CFrame.Angles(0.22, 0,  0.08), cordC)
			local hpC = Color3.fromRGB(72, 192, 214)
			makePart(model, "HPArc", Vector3.new(0.14 * scale, hs * 0.60, 0.14 * scale),
				at * CFrame.new(0, headY + hs * 0.45, 0), hpC)
			makePart(model, "HPCupL", Vector3.new(0.40 * scale, 0.52 * scale, 0.32 * scale),
				at * CFrame.new(-(hs / 2 + 0.22 * scale), headY + hs * 0.08, 0),
				hpC, Enum.PartType.Ball)
			makePart(model, "HPCupR", Vector3.new(0.40 * scale, 0.52 * scale, 0.32 * scale),
				at * CFrame.new( (hs / 2 + 0.22 * scale), headY + hs * 0.08, 0),
				hpC, Enum.PartType.Ball)
			-- White foam ear-pad visible on inner (head-side) face of each cup (Boy Camper 2 ref)
			local padWhite = Color3.fromRGB(236, 233, 228)
			for padSide = -1, 1, 2 do
				local padX = padSide * (hs / 2 + 0.22 * scale)
				local padInnerX = padSide * (hs / 2 + 0.06 * scale)
				local pad = makePart(model, "HPPad" .. (if padSide < 0 then "L" else "R"),
					Vector3.new(0.28 * scale, 0.40 * scale, 0.10),
					at * CFrame.new(padInnerX, headY + hs * 0.08, 0), padWhite, Enum.PartType.Ball)
				pad.Material = Enum.Material.SmoothPlastic
			end
			-- Black cargo pants: Boy Camper 2 reference shows black pants under flannel
			local ll8 = model:FindFirstChild("LeftLeg")  :: BasePart?
			local rl8 = model:FindFirstChild("RightLeg") :: BasePart?
			local flannelBlack = Color3.fromRGB(22, 20, 26)
			if ll8 then ll8.Color = flannelBlack end
			if rl8 then rl8.Color = flannelBlack end

		elseif styleSlot == 9 then
			-- Backwards Cap: white sneakers, backwards snapback, kangaroo hoodie pocket
			if cLS then cLS.Color = Color3.fromRGB(228, 228, 232) end
			if cRS then cRS.Color = Color3.fromRGB(228, 228, 232) end
			-- Dark medium-brown hair peeking below cap (Boy Camper 3 reference)
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and string.sub(p.Name, 1, 4) == "Hair" then
					(p :: BasePart).Color = Color3.fromRGB(72, 36, 12)
				end
			end
			local bCC = Color3.fromRGB(20, 20, 26)
			makePart(model, "BCapCrown", Vector3.new(hs * 1.04, 0.30 * scale, hs * 0.98),
				at * CFrame.new(0, headY + hs / 2 + 0.15 * scale, 0), bCC)
			makePart(model, "BCapBand", Vector3.new(hs * 1.06, 0.11 * scale, hs * 1.00),
				at * CFrame.new(0, headY + hs / 2 + 0.005 * scale, 0), Color3.fromRGB(14, 14, 18))
			-- Bill faces backward (positive Z in local space)
			makePart(model, "BCapBill", Vector3.new(hs * 1.06, 0.10 * scale, 0.55 * scale),
				at * CFrame.new(0, headY + hs / 2 + 0.005 * scale, hs * 0.68), bCC)
			-- Strap adjuster buckle now facing front (silver — prominent in Boy Camper 3 reference)
			local capBkl = makePart(model, "BCapBuckle", Vector3.new(0.26 * scale, 0.18 * scale, 0.10),
				at * CFrame.new(0, headY + hs / 2 + 0.005 * scale, -(hs * 0.52)),
				Color3.fromRGB(82, 86, 96))
			capBkl.Material = Enum.Material.Metal
			-- Kangaroo front pocket centered on lower hoodie — signature detail from reference
			makePart(model, "KangarooPocket", Vector3.new(1.32 * scale, 0.50 * scale, 0.10),
				at * CFrame.new(0, -(th * 0.28), -(td / 2 + 0.09)),
				Color3.fromRGB(52, 108, 52))
			-- Black joggers: Boy Camper 3 reference clearly shows black pants under green hoodie
			local ll9 = model:FindFirstChild("LeftLeg")  :: BasePart?
			local rl9 = model:FindFirstChild("RightLeg") :: BasePart?
			local blackJog = Color3.fromRGB(22, 20, 28)
			if ll9 then ll9.Color = blackJog end
			if rl9 then rl9.Color = blackJog end
			-- Drawstring detail on hoodie front (Boy Camper 3: light cream-grey cords)
			local dsCord = Color3.fromRGB(195, 192, 188)
			makePart(model, "DrawstringL", Vector3.new(0.06, 0.62 * scale, 0.06),
				at * CFrame.new(-0.16 * scale, th * 0.02, -(td / 2 + 0.10)), dsCord)
			makePart(model, "DrawstringR", Vector3.new(0.06, 0.62 * scale, 0.06),
				at * CFrame.new( 0.16 * scale, th * 0.02, -(td / 2 + 0.10)), dsCord)
			-- Black waist belt + silver buckle (very prominent in Boy Camper 3 reference)
			local beltY9 = -(th / 2 - 0.20 * scale)
			makePart(model, "WaistBelt", Vector3.new(2.10 * scale, 0.22 * scale, td * 1.08),
				at * CFrame.new(0, beltY9, 0), Color3.fromRGB(20, 18, 22))
			local bkl9 = makePart(model, "BeltBuckle", Vector3.new(0.42 * scale, 0.30 * scale, 0.12),
				at * CFrame.new(0, beltY9, -(td / 2 + 0.07)), Color3.fromRGB(82, 82, 92))
			bkl9.Material = Enum.Material.Metal

		elseif styleSlot == 10 then
			-- Pixel Creeper: full-green pixel costume with block-head mask + chest face
			-- Reference shows white sneakers with dark sole, not dark green
			if cLS then cLS.Color = Color3.fromRGB(228, 228, 232) end
			if cRS then cRS.Color = Color3.fromRGB(228, 228, 232) end
			local pxG = Color3.fromRGB(88, 158, 55)
			local pxD = Color3.fromRGB(40, 85, 25)
			-- Block mask sits over the head giving the iconic square pixel look
			makePart(model, "PixBlockHead", Vector3.new(hs * 1.12, hs * 1.08, hs * 1.08),
				at * CFrame.new(0, headY, 0), pxG)
			-- Dark pixel face markings on the front face of the block
			makePart(model, "PixEyeL", Vector3.new(0.44 * scale, 0.42 * scale, 0.10),
				at * CFrame.new(-0.30 * scale, headY + 0.10 * scale, -(hs / 2 + 0.58)), pxD)
			makePart(model, "PixEyeR", Vector3.new(0.44 * scale, 0.42 * scale, 0.10),
				at * CFrame.new( 0.30 * scale, headY + 0.10 * scale, -(hs / 2 + 0.58)), pxD)
			makePart(model, "PixMthL", Vector3.new(0.24 * scale, 0.20 * scale, 0.10),
				at * CFrame.new(-0.26 * scale, headY - 0.26 * scale, -(hs / 2 + 0.58)), pxD)
			makePart(model, "PixMthR", Vector3.new(0.24 * scale, 0.20 * scale, 0.10),
				at * CFrame.new( 0.26 * scale, headY - 0.26 * scale, -(hs / 2 + 0.58)), pxD)
			-- Creeper face on hoodie chest: two pixel "eyes" + zig-zag "mouth" rows
			-- Matches the hoodie-print creeper face visible on the torso in the reference
			makePart(model, "ChestEyeL", Vector3.new(0.52 * scale, 0.38 * scale, 0.10),
				at * CFrame.new(-0.38 * scale, th * 0.22, -(td / 2 + 0.09)), pxD)
			makePart(model, "ChestEyeR", Vector3.new(0.52 * scale, 0.38 * scale, 0.10),
				at * CFrame.new( 0.38 * scale, th * 0.22, -(td / 2 + 0.09)), pxD)
			-- Mouth row 1: three blocks
			makePart(model, "MthC1L", Vector3.new(0.28 * scale, 0.28 * scale, 0.10),
				at * CFrame.new(-0.52 * scale, th * 0.04, -(td / 2 + 0.09)), pxD)
			makePart(model, "MthC1R", Vector3.new(0.28 * scale, 0.28 * scale, 0.10),
				at * CFrame.new( 0.52 * scale, th * 0.04, -(td / 2 + 0.09)), pxD)
			-- Mouth row 2: centre indent (zig-zag)
			makePart(model, "MthC2", Vector3.new(0.30 * scale, 0.26 * scale, 0.10),
				at * CFrame.new(0, th * 0.04 - 0.30 * scale, -(td / 2 + 0.09)), pxD)
			-- Full-body green: legs are also Creeper green (Boy Camper 4 reference: full green suit)
			local ll10 = model:FindFirstChild("LeftLeg")  :: BasePart?
			local rl10 = model:FindFirstChild("RightLeg") :: BasePart?
			if ll10 then ll10.Color = pxG end
			if rl10 then rl10.Color = pxG end

		else -- styleSlot == 11
			-- Holo Visor: white sneakers, colour-shifting visor, rose-gold hoodie trim + front pockets
			if cLS then cLS.Color = Color3.fromRGB(228, 228, 232) end
			if cRS then cRS.Color = Color3.fromRGB(228, 228, 232) end
			-- Medium-dark brown spikey hair (Boy Camper 5 reference: brown hair above visor)
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and string.sub(p.Name, 1, 4) == "Hair" then
					(p :: BasePart).Color = Color3.fromRGB(80, 42, 12)
				end
			end
			local visor = makePart(model, "HoloVisor", Vector3.new(hs * 1.05, hs * 0.25, 0.10),
				at * CFrame.new(0, headY + hs * 0.08, -(hs / 2 + 0.06)),
				Color3.fromRGB(120, 190, 255))
			visor.Material = Enum.Material.Neon
			visor.Transparency = 0.28
			-- Rose-gold zip stripe + hem band on the dark hoodie
			local roseGold = Color3.fromRGB(208, 148, 102)
			makePart(model, "HoodieZip", Vector3.new(0.14 * scale, th * 0.88, 0.10),
				at * CFrame.new(0, 0, -(td / 2 + 0.08)), roseGold)
			makePart(model, "HoodieHem", Vector3.new(2.02 * scale, 0.16 * scale, 0.10),
				at * CFrame.new(0, -(th / 2 - 0.09 * scale), -(td / 2 + 0.08)), roseGold)
			-- Two front hoodie pockets (clearly visible in Boy Camper 5 reference)
			local pocketC = bodyColor:Lerp(Color3.fromRGB(0, 0, 0), 0.22)
			for side = -1, 1, 2 do
				makePart(model, "HoodiePocket" .. (if side < 0 then "L" else "R"),
					Vector3.new(0.74 * scale, 0.52 * scale, 0.10),
					at * CFrame.new(side * 0.54 * scale, -(th * 0.26), -(td / 2 + 0.09)), pocketC)
			end
			-- Rose-gold cuff bands at sleeve ends: Boy Camper 5 reference shows rose-gold accents
			local cuffY = -(th / 2 - 0.24 * scale)
			for side = -1, 1, 2 do
				makePart(model, "HoodieCuff" .. (if side < 0 then "L" else "R"),
					Vector3.new(1.10 * scale, 0.18 * scale, 1.06 * scale),
					at * CFrame.new(side * ax, cuffY, 0), roseGold)
			end
			task.spawn(function()
				local holoColors = {
					Color3.fromRGB(120, 190, 255),
					Color3.fromRGB(180, 130, 255),
					Color3.fromRGB(100, 220, 210),
				}
				local ci = 1
				while visor.Parent ~= nil do
					ci = (ci % #holoColors) + 1
					visor.Color = holoColors[ci]
					task.wait(0.8 + math.random() * 0.4)
				end
			end)
		end

		-- Brass compass on chest for all styles except the Pixel Creeper full-costume
		if styleSlot ~= 10 then
			local compass = makePart(model, "Compass", Vector3.new(0.28 * scale, 0.28 * scale, 0.07 * scale),
				at * CFrame.new(0.32 * scale, th / 2 - 0.50 * scale, -(td / 2 + 0.07)),
				Color3.fromRGB(166, 142, 78))
			compass.Material = Enum.Material.Metal
			makePart(model, "CompassNeedle", Vector3.new(0.04 * scale, 0.20 * scale, 0.06 * scale),
				at * CFrame.new(0.32 * scale, th / 2 - 0.50 * scale, -(td / 2 + 0.095)),
				Color3.fromRGB(180, 45, 35))
		end
	end

	labelModel(model, displayName, ROLE_DOT_COLORS[roleName or ""])
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
	-- With workspace streaming on, character models must stream whole:
	-- a counselor or monster with a streamed-out arm reads as a bug.
	container.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			child.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		end
	end)
	container.Parent = characters
	return setmetatable({
		container = container,
		monsterModel = nil,
		monsterTrackToken = 0,
		monsterTrackPlayer = nil,
		counselorModels = {},
		botCharacterModels = {},
		botHomePositions = {},
		monsterAnimationTrack = nil,
		monsterAnimationState = nil,
		counselorAnimationTracks = {},
		counselorAnimationStates = {},
		counselorMoveTokens = {},
		counselorMoveTargets = {},
		bodyMarkers = {},
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
			-- Verb in ActionText, name in ObjectText — matches every other
			-- prompt in the game (these two were swapped; audited 2026-08-09).
			prompt.ActionText = "Talk"
			prompt.ObjectText = definition.displayName
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

-- Gentle breathing animation played while a character is standing idle.
-- Runs for `duration` seconds then returns; exits early if the move token changes or model removed.
function CharacterAssetService:_idleBreath(id: string, model: Model, duration: number)
	local tokenBefore = self.counselorMoveTokens[id] or 0
	local baseCF = model:GetPivot()
	local began = os.clock()
	-- Breathing is a 0.028-stud sway: 15 Hz writes read identically (client
	-- replication coalesces to ~20 Hz regardless), and when no player is
	-- within eyeshot the pivots are skipped entirely. Ten idle bots at 60 Hz
	-- were the single largest source of replicated property churn.
	local nearCheckAt = 0
	local playerNear = true
	while os.clock() - began < duration do
		if model.Parent == nil then break end
		if (self.counselorMoveTokens[id] or 0) ~= tokenBefore then break end
		local t = os.clock() - began
		if os.clock() >= nearCheckAt then
			nearCheckAt = os.clock() + 1
			playerNear = false
			local here = baseCF.Position
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = if character then character.PrimaryPart else nil
				if root and (root.Position - here).Magnitude < 80 then
					playerNear = true
					break
				end
			end
		end
		if playerNear then
			local breathRate = 1.6 + (nameHash(id) % 5) * 0.10   -- 1.6–2.0 Hz, unique per character
			local breathY  = math.sin(t * breathRate) * 0.028
			local swayX    = math.sin(t * 0.52) * 0.016   -- slow side-to-side weight shift
			local gazeYaw  = math.sin(t * 0.38) * 0.08    -- very slow gaze drift left/right
			model:PivotTo(baseCF * CFrame.new(swayX, breathY, 0) * CFrame.Angles(0, gazeYaw, 0))
			local pp = model.PrimaryPart
			if pp then
				applyArmSwing(model, pp.CFrame, math.sin(t * breathRate) * 0.07)
			end
			task.wait(1 / 15)
		else
			task.wait(0.4)
		end
	end
	-- Restore neutral pose when idling ends normally (before the next move begins)
	if model.Parent ~= nil and (self.counselorMoveTokens[id] or 0) == tokenBefore then
		model:PivotTo(baseCF)
		local pp = model.PrimaryPart
		if pp then
			applyArmSwing(model, pp.CFrame, 0)
		end
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
			self:_idleBreath(counselorId, model, MIN_WAIT + math.random() * (MAX_WAIT - MIN_WAIT))
			if model.Parent == nil then
				break
			end
			if (self.counselorMoveTokens[counselorId] or 0) == tokenBefore then
				local center = model:GetPivot()
				-- Face a nearby player if one is within 9 studs -- counselors notice and watch players
				local facedPlayer = false
				for _, player in Players:GetPlayers() do
					local char = player.Character
					if char then
						local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
						if hrp then
							local diff = hrp.Position - center.Position
							if Vector3.new(diff.X, 0, diff.Z).Magnitude < 9 then
								local faceTarget = CFrame.new(center.Position)
									* CFrame.Angles(0, math.atan2(-diff.X, -diff.Z), 0)
								self:_smoothPivotCounselor(counselorId, model, faceTarget, 0.7)
								facedPlayer = true
								break
							end
						end
					end
				end
				if not facedPlayer then
					if math.random() < 0.28 then
						-- Look around: turn in place toward a new facing direction
						local yaw = (math.random() - 0.5) * math.pi * 0.8
						local turnTarget = CFrame.new(center.Position) * CFrame.Angles(0, yaw, 0)
						self:_smoothPivotCounselor(counselorId, model, turnTarget, 0.9)
					else
						local angle = math.random() * math.pi * 2
						local r = 0.4 + math.random() * PACE_RADIUS
						local target = center * CFrame.new(math.cos(angle) * r, 0, math.sin(angle) * r)
						self:_smoothPivotCounselor(counselorId, model, target, 1.6)
					end
				end
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
		local travelDist = (target.Position - start.Position).Magnitude
		local began = os.clock()
		while self.counselorMoveTokens[counselorId] == token do
			local elapsed = os.clock() - began
			if elapsed >= duration then
				model:PivotTo(target)
				break
			end
			local rawT = elapsed / duration
			local t = 1 - (1 - rawT) ^ 3
			local phase = rawT * math.pi * 4
			local bobY = math.abs(math.sin(phase)) * 0.06
			-- Forward lean only when actually walking (not turning in place)
			local leanScale = math.min(travelDist / 2.5, 1)
			local leanAngle = math.sin(rawT * math.pi) * leanScale * -0.08
			model:PivotTo(start:Lerp(target, t) * CFrame.new(0, bobY, 0) * CFrame.Angles(leanAngle, 0, 0))
			local pp = model.PrimaryPart
			if pp then
				applyArmSwing(model, pp.CFrame, math.sin(phase) * 0.28)
			end
			-- 30 Hz: still above the ~20 Hz replication ceiling clients see.
			task.wait(1 / 30)
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
									-- Face direction of travel so counselors look purposeful
									local fromPos = model:GetPivot().Position
									local toPos = at.Position
									local travelDir = Vector3.new(toPos.X - fromPos.X, 0, toPos.Z - fromPos.Z)
									local facingAt = if travelDir.Magnitude > 0.5
										then CFrame.lookAt(toPos, toPos + travelDir.Unit)
										else at
									self:_smoothPivotCounselor(counselorId, model, facingAt, 3)
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
	-- Positional hunt-loop slot: set the SoundService attribute
	-- "MonsterHunt<Id>AssetId" to override the built-in loop for a monster.
	-- Defaults live in Config/MonsterAudioDefaults (this file keeps zero
	-- literal asset ids per its release contract) — before them, every
	-- monster hunted in complete silence.
	local huntAssetId = SoundService:GetAttribute("MonsterHunt" .. monsterId .. "AssetId")
	local huntSoundId = if type(huntAssetId) == "number" and huntAssetId > 0
		then "rbxassetid://" .. tostring(huntAssetId)
		elseif type(huntAssetId) == "string" and huntAssetId ~= "" then huntAssetId
		else MonsterAudioDefaults[monsterId] or ""
	if huntSoundId ~= "" then
		local emitter = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		if emitter then
			local hunt = Instance.new("Sound")
			hunt.Name = "MonsterHuntLoop"
			hunt.SoundId = huntSoundId
			hunt.Looped = true
			hunt.Volume = 0.85
			hunt.RollOffMode = Enum.RollOffMode.InverseTapered
			hunt.RollOffMinDistance = 8
			hunt.RollOffMaxDistance = 90
			hunt.Parent = emitter
			hunt:Play()
		end
	end
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

function CharacterAssetService:GetMonsterPosition(): Vector3?
	local model = self.monsterModel
	if not model then
		return nil
	end
	local root = model.PrimaryPart
	return if root then root.Position else model:GetPivot().Position
end

-- Toggles the rescue interaction on a cornered counselor. The prompt lives on
-- the counselor model itself (mirroring SpawnBodyMarker) so the server owns
-- the trigger and can validate the rescuer before anything happens.
function CharacterAssetService:SetCounselorCornered(
	counselorId: string,
	active: boolean,
	onRescue: ((rescuer: Player) -> ())?
)
	local model = self:GetCounselorModel(counselorId)
	if not model then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root then
		return
	end
	local existingPrompt = model:FindFirstChild("RescuePrompt", true)
	local existingBillboard = model:FindFirstChild("RescueBillboard", true)
	if not active then
		if existingPrompt then
			existingPrompt:Destroy()
		end
		if existingBillboard then
			existingBillboard:Destroy()
		end
		return
	end
	if existingPrompt then
		return
	end
	local displayName = model:GetAttribute("DisplayName")
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RescueBillboard"
	billboard.Size = UDim2.new(5, 0, 1.1, 0)
	billboard.StudsOffset = Vector3.new(0, 4.4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	billboard.Parent = root
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = "HELP!"
	label.TextColor3 = Color3.fromRGB(255, 196, 110)
	label.TextScaled = true
	label.Parent = billboard
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RescuePrompt"
	prompt.ActionText = "Escort to safety"
	prompt.ObjectText = if type(displayName) == "string" then displayName else "Counselor"
	prompt.HoldDuration = 3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	if onRescue then
		prompt.Triggered:Connect(function(player: Player)
			onRescue(player)
		end)
	end
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
	-- Attack sting slot: plays the MonsterAttack<Id>AssetId SoundService
	-- attribute (if set) as a positional one-shot at the lunge origin.
	local monsterId = model:GetAttribute("MonsterId")
	if type(monsterId) == "string" and monsterId ~= "" then
		local attackAssetId = SoundService:GetAttribute(
			"MonsterAttack" .. monsterId .. "AssetId"
		)
		local attackSoundId = if type(attackAssetId) == "number" and attackAssetId > 0
			then "rbxassetid://" .. tostring(attackAssetId)
			elseif type(attackAssetId) == "string" and attackAssetId ~= "" then attackAssetId
			else ""
		local emitter = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		if attackSoundId ~= "" and emitter then
			local sting = Instance.new("Sound")
			sting.Name = "MonsterAttackSting"
			sting.SoundId = attackSoundId
			sting.Volume = 1
			sting.RollOffMode = Enum.RollOffMode.InverseTapered
			sting.RollOffMinDistance = 10
			sting.RollOffMaxDistance = 120
			sting.Parent = emitter
			sting.Ended:Once(function()
				sting:Destroy()
			end)
			sting:Play()
		end
	end
	local resumePlayer = self.monsterTrackPlayer
	self:StopMonsterTracking()
	task.spawn(function()
		local STEPS = 10
		local STEP_TIME = 0.035
		local current = model:GetPivot()
		local lungePos = current.Position:Lerp(targetPosition, 0.82)
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
			-- Ease in fast (quadratic) then overshoot slightly on final step
			local eased = if i == STEPS then 1.04 else t * t * (3 - 2 * t)
			model:PivotTo(current:Lerp(lungeTarget, math.min(eased, 1.0)))
			task.wait(STEP_TIME)
		end
		-- Dramatic pause before pulling back to orbit
		task.wait(0.28)
		if resumePlayer then
			self:StartMonsterTracking(resumePlayer)
		end
	end)
end

-- Starts a loop that moves the monster model to orbit near the murderer's character.
-- The monster slowly circles the murderer for an atmospheric stalking effect.
-- When the monster is active, scan for bots nearby and push them away.
-- Runs until the monster is cleared (monsterModel becomes nil).
function CharacterAssetService:_startProximityFlee(token: number)
	task.spawn(function()
		local TICK = 1.2
		local FLEE_RADIUS = 14       -- studs: bots within this range will flee
		local FLEE_DISTANCE = 11     -- studs: how far to flee
		local FLEE_DURATION = 2.2    -- seconds to complete the flee move
		while self.monsterTrackToken == token and self.monsterModel ~= nil do
			local monster = self.monsterModel
			if monster then
				local monsterPos = monster:GetPivot().Position
				for participantId, botModel in self.botCharacterModels do
					if botModel.Parent ~= nil then
						local botPos = botModel:GetPivot().Position
						local diff = botPos - monsterPos
						local dist = Vector3.new(diff.X, 0, diff.Z).Magnitude
						if dist < FLEE_RADIUS then
							local awayXZ = Vector3.new(diff.X, 0, diff.Z)
							if awayXZ.Magnitude > 0.5 then
								local fleeTarget = botPos
									+ awayXZ.Unit * FLEE_DISTANCE
									+ Vector3.new(0, 0, 0)
								self:MoveBotCharacterToward(participantId, fleeTarget, FLEE_DURATION)
							end
						end
					end
				end
			end
			task.wait(TICK)
		end
	end)
end

function CharacterAssetService:StartMonsterTracking(murdererPlayer: Player)
	self.monsterTrackPlayer = murdererPlayer
	local token = self.monsterTrackToken + 1
	self.monsterTrackToken = token
	self:_startProximityFlee(token)
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
					-- Undulating vertical bob gives the monster a predatory floating motion
					local bobY = math.sin(orbitAngle * 3.5) * 0.42
					local newPosB = Vector3.new(newPos.X, newPos.Y + bobY, newPos.Z)
					local lookDir = Vector3.new(
						hrp.Position.X - newPosB.X,
						0,
						hrp.Position.Z - newPosB.Z
					)
					if lookDir.Magnitude > 0.05 then
						model:PivotTo(CFrame.lookAt(newPosB, newPosB + lookDir.Unit))
					else
						model:PivotTo(current - current.Position + newPosB)
					end
					-- Animate limbs: they reach and grasp as the monster circles its prey
					local rawLX  = model:GetAttribute("LimbShoulderLX")
					local rawRX  = model:GetAttribute("LimbShoulderRX")
					local rawY   = model:GetAttribute("LimbShoulderY")
					local rawLen = model:GetAttribute("LimbLen")
					if type(rawLX) == "number" and type(rawRX) == "number"
						and type(rawY) == "number" and type(rawLen) == "number"
					then
						local leftLimb  = model:FindFirstChild("LeftLimb")  :: BasePart?
						local rightLimb = model:FindFirstChild("RightLimb") :: BasePart?
						if leftLimb and rightLimb then
							local limbSwing = math.sin(orbitAngle * 2.4) * 0.28
							local mCF = model:GetPivot()
							leftLimb.CFrame  = (mCF * CFrame.new(rawLX, rawY, 0)) * CFrame.Angles(0, 0,  0.42 + limbSwing) * CFrame.new(0, -rawLen / 2, 0)
							rightLimb.CFrame = (mCF * CFrame.new(rawRX, rawY, 0)) * CFrame.Angles(0, 0, -0.42 - limbSwing) * CFrame.new(0, -rawLen / 2, 0)
						end
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

-- Camp investigation positions: spread around the evidence-heavy areas of the camp.
local INVESTIGATION_PATROL: { Vector3 } = {
	Vector3.new(12, 3, 7),    -- evidence board
	Vector3.new(-52, 3, 24),  -- nature lab
	Vector3.new(51, 3, 24),   -- infirmary
	Vector3.new(0, 3, 55),    -- lodge area
	Vector3.new(65, 3, 45),   -- activity field
	Vector3.new(-40, 3, 38),  -- trailhead side
	Vector3.new(28, 3, 38),   -- mid-camp east
	Vector3.new(-18, 3, 12),  -- camp center west
}

-- Disperses bots to spread across the camp's investigation area so they look
-- like they are searching for clues rather than idling near spawn.
function CharacterAssetService:ScatterBotsForInvestigation()
	local i = 0
	for participantId in self.botCharacterModels do
		i += 1
		local point = INVESTIGATION_PATROL[((i - 1) % #INVESTIGATION_PATROL) + 1]
		local jitter = Vector3.new(
			(math.random() - 0.5) * 7,
			0,
			(math.random() - 0.5) * 7
		)
		self:MoveBotCharacterToward(participantId, point + jitter, 4 + math.random() * 3)
	end
end

-- Moves all bots toward a world-space position (e.g., campfire during vote phase).
-- Each bot gets a slight random offset so they don't stack on top of each other.
function CharacterAssetService:GatherBotsAt(position: Vector3, radius: number?)
	local r = radius or 3.5
	local total = 0
	for _ in self.botCharacterModels do
		total += 1
	end
	local i = 0
	for participantId in self.botCharacterModels do
		i += 1
		local angle = (i - 1) * (math.pi * 2 / math.max(1, total)) + math.random() * 0.4
		local dist = 0.6 + math.random() * r
		local target = position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		self:MoveBotCharacterToward(participantId, target, 3 + math.random() * 2, position)
	end
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
	self.botHomePositions[participantId] = at.Position
	return model
end

function CharacterAssetService:ClearBotCharacter(participantId: string)
	local model = self.botCharacterModels[participantId]
	if model then
		model:Destroy()
		self.botCharacterModels[participantId] = nil
	end
	self.botHomePositions[participantId] = nil
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

	-- Hit stagger: brief red flash + side tilt, then restore original pose and colors
	local tokenSnap = self.counselorMoveTokens[participantId] or 0
	local origColors: { [BasePart]: Color3 } = {}
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name ~= "InjuryIndicator" then
			origColors[desc] = desc.Color
		end
	end
	local pivot = model:GetPivot()
	local side = if (nameHash(participantId) % 2 == 0) then 1.0 else -1.0
	local tiltCF = pivot * CFrame.Angles(0, 0, side * 0.30)
	task.spawn(function()
		local STEPS = 10
		for i = 1, STEPS do
			if model.Parent == nil then return end
			if (self.counselorMoveTokens[participantId] or 0) ~= tokenSnap then
				for part, c in origColors do
					if part.Parent ~= nil then part.Color = c end
				end
				return
			end
			local alpha = math.sin(i / STEPS * math.pi)
			model:PivotTo(pivot:Lerp(tiltCF, alpha))
			for part, c in origColors do
				if part.Parent ~= nil then
					part.Color = c:Lerp(Color3.fromRGB(220, 55, 55), alpha * 0.52)
				end
			end
			task.wait(0.40 / STEPS)
		end
		if model.Parent ~= nil and (self.counselorMoveTokens[participantId] or 0) == tokenSnap then
			model:PivotTo(pivot)
			for part, c in origColors do
				if part.Parent ~= nil then part.Color = c end
			end
		end
	end)
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
	self.botHomePositions = {}
end

function CharacterAssetService:GetBotCharacterModel(participantId: string): Model?
	return self.botCharacterModels[participantId]
end

-- A discoverable corpse at the kill site. The global "body discovered"
-- announcement only fires once a living player reports it via the prompt.
function CharacterAssetService:SpawnBodyMarker(
	victimParticipantId: string,
	displayName: string,
	position: Vector3,
	onReport: (reporter: Player) -> ()
)
	if self.bodyMarkers[victimParticipantId] then
		return
	end
	local model = Instance.new("Model")
	model.Name = "BodyMarker_" .. victimParticipantId
	local ground = Vector3.new(position.X, math.max(position.Y, 2), position.Z)
	local mound = makePart(
		model,
		"Body",
		Vector3.new(4.4, 1.1, 2.2),
		CFrame.new(ground) * CFrame.Angles(0, math.rad(25), 0),
		Color3.fromRGB(52, 48, 46)
	)
	makePart(
		model,
		"Shroud",
		Vector3.new(3.6, 0.5, 1.8),
		CFrame.new(ground + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, math.rad(25), 0),
		Color3.fromRGB(180, 174, 158)
	)
	model.PrimaryPart = mound
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BodyLabel"
	billboard.Size = UDim2.new(6, 0, 1.3, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 45
	billboard.Parent = mound
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = "SOMETHING LIES HERE"
	label.TextColor3 = Color3.fromRGB(220, 90, 84)
	label.TextScaled = true
	label.Parent = billboard
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ReportBody"
	prompt.ActionText = "Report Body"
	prompt.ObjectText = displayName
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = mound
	prompt.Triggered:Connect(function(player: Player)
		onReport(player)
	end)
	model.Parent = self.container
	self.bodyMarkers[victimParticipantId] = model
end

function CharacterAssetService:MarkBodyReported(victimParticipantId: string)
	local model = self.bodyMarkers[victimParticipantId]
	if not model then
		return
	end
	local prompt = model:FindFirstChild("ReportBody", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
	end
	local billboard = model:FindFirstChild("BodyLabel", true)
	if billboard then
		local label = billboard:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = "REPORTED"
			label.TextColor3 = Color3.fromRGB(214, 219, 212)
		end
	end
end

function CharacterAssetService:ClearBodyMarkers()
	for _, model in self.bodyMarkers do
		model:Destroy()
	end
	self.bodyMarkers = {}
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
	local RADIUS = 4.5
	local MIN_PAUSE = 2.2
	local MAX_PAUSE = 5.0
	-- Step counter: every 4th step drift back toward spawn so bots stay clustered
	local stepCount = 0
	task.spawn(function()
		task.wait(1 + math.random() * 2)
		while self.botCharacterModels[participantId] do
			local model2 = self.botCharacterModels[participantId]
			if not model2 then break end
			local tokenBefore = self.counselorMoveTokens[participantId] or 0
			self:_idleBreath(participantId, model2, MIN_PAUSE + math.random() * (MAX_PAUSE - MIN_PAUSE))
			if not self.botCharacterModels[participantId] then
				break
			end
			if (self.counselorMoveTokens[participantId] or 0) == tokenBefore then
				stepCount += 1
				local home = self.botHomePositions[participantId]
				local center: Vector3?
				-- Every 4th step, drift back toward spawn to prevent spreading
				if stepCount % 4 == 0 and home then
					center = home
				else
					center = self:GetBotCharacterPosition(participantId)
				end
				if center then
					-- Face a nearby player if one is within 7 studs
					local facedPlayer = false
					for _, player in Players:GetPlayers() do
						local char = player.Character
						if char then
							local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
							if hrp and model2.Parent ~= nil then
								local diff = hrp.Position - model2:GetPivot().Position
								if Vector3.new(diff.X, 0, diff.Z).Magnitude < 7 then
									local faceTarget = CFrame.new(model2:GetPivot().Position)
										* CFrame.Angles(0, math.atan2(-diff.X, -diff.Z), 0)
									self:_smoothPivotCounselor(participantId, model2, faceTarget, 0.7)
									facedPlayer = true
									break
								end
							end
						end
					end
					if not facedPlayer then
						if math.random() < 0.22 then
							-- Look around: turn in place toward a random new facing direction
							if model2.Parent ~= nil then
								local botPivot = model2:GetPivot()
								local yaw = (math.random() - 0.5) * math.pi * 0.85
								local turnTarget = CFrame.new(botPivot.Position) * CFrame.Angles(0, yaw, 0)
								self:_smoothPivotCounselor(participantId, model2, turnTarget, 0.9)
							end
						else
							local angle = math.random() * math.pi * 2
							local radius = 0.8 + math.random() * RADIUS
							local target = center
								+ Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
							self:MoveBotCharacterToward(participantId, target, 1.4 + math.random() * 0.8)
						end
				end
				end
			end
		end
	end)
end

function CharacterAssetService:MoveBotCharacterToward(
	participantId: string,
	targetPosition: Vector3,
	duration: number?,
	facingTarget: Vector3?
)
	local model = self.botCharacterModels[participantId]
	if not model then
		return
	end
	local resolved = duration or 2.2
	local current = model:GetPivot()
	local dx = targetPosition.X - current.X
	local dz = targetPosition.Z - current.Z
	local targetCFrame: CFrame
	if facingTarget then
		local fdx = facingTarget.X - targetPosition.X
		local fdz = facingTarget.Z - targetPosition.Z
		targetCFrame = CFrame.new(targetPosition.X, current.Y, targetPosition.Z)
			* CFrame.Angles(0, math.atan2(-fdx, -fdz), 0)
	else
		targetCFrame = CFrame.new(targetPosition.X, current.Y, targetPosition.Z)
			* CFrame.Angles(0, math.atan2(-dx, -dz), 0)
	end
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
			local rawT = elapsed / resolved
			local t = 1 - (1 - rawT) ^ 2
			-- Faster moves (flee) get bigger bob, hop, lean, and wilder arm swing
			local phase = rawT * math.pi * 4
			local bobAmp = if resolved < 2.5 then 0.10 else 0.06
			local hopY = if resolved < 2.5 then math.sin(math.min(elapsed / 0.28, 1) * math.pi) * 0.15 else 0
			local bobY = math.abs(math.sin(phase)) * bobAmp + hopY
			local leanAngle = math.sin(rawT * math.pi) * (if resolved < 2.5 then -0.13 else -0.09)
			model:PivotTo(start:Lerp(targetCFrame, t) * CFrame.new(0, bobY, 0) * CFrame.Angles(leanAngle, 0, 0))
			local pp = model.PrimaryPart
			if pp then
				local swingAmp = if resolved < 2.5 then 0.42 else 0.28
				applyArmSwing(model, pp.CFrame, math.sin(phase) * swingAmp)
			end
			-- 30 Hz: still above the ~20 Hz replication ceiling clients see.
			task.wait(1 / 30)
		end
	end)
end

return CharacterAssetService
