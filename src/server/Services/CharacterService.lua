--!strict

-- Dresses every real player as a distinct camp attendee. The look is derived
-- deterministically from the UserId, so a player is the same camper across
-- sessions and servers — visual identity matters for eyewitness gameplay
-- ("the camper in the mustard cap was near the generator").
--
-- Bots get anchored prop models from CharacterAssetService; real Humanoid rigs
-- cannot wear those, so players instead get BodyColors paint from the shared
-- camper palette plus a couple of massless welded accent parts (cap, hair
-- fringe, optional backpack) that never affect physics or raycasts.

local Players = game:GetService("Players")

local CharacterAssetService = require(script.Parent:WaitForChild("CharacterAssetService"))

local CAMPER_OUTFIT_PALETTE = CharacterAssetService.CamperOutfitPalette
local BOT_SKIN_TONES = CharacterAssetService.BotSkinTones
local HAIR_COLORS = CharacterAssetService.HairColors

-- Speakable names for CAMPER_OUTFIT_PALETTE entries, index-aligned with the
-- palette in CharacterAssetService. Exposed via the CamperOutfitColor
-- character attribute so UI/eyewitness text can reference the outfit.
local PALETTE_COLOR_NAMES: { string } = {
	"Teal",
	"Rose Pink",
	"Berry Pink",
	"Denim Blue",
	"Sage White",
	"Warm Brown",
	"Off White",
	"Mustard Yellow",
	"Plaid Blue",
	"Hoodie Green",
	"Bright Green",
	"Charcoal",
}

type CharacterServiceState = {
	running: boolean,
	connections: { RBXScriptConnection },
	characterConnections: { [Player]: RBXScriptConnection },
}

local CharacterService = {}
CharacterService.__index = CharacterService

export type CharacterService = typeof(
	setmetatable({} :: CharacterServiceState, CharacterService)
)

-- djb2-style hash over the decimal digits of the UserId. Stable across
-- sessions and servers so the same player always maps to the same outfit.
local function hashUserId(userId: number): number
	local text = tostring(userId)
	local h = 5381
	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % 1000003
	end
	return h
end

local function makeAccentPart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	return part
end

local function weldAccent(
	character: Model,
	attachTo: BasePart,
	part: Part,
	offset: CFrame
)
	part.CFrame = attachTo.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Name = "AccentWeld"
	weld.Part0 = attachTo
	weld.Part1 = part
	weld.Parent = part
	part.Parent = character
end

local function applyCamperLook(player: Player, character: Model)
	if character:GetAttribute("CamperLookApplied") then
		return
	end
	character:SetAttribute("CamperLookApplied", true)

	local humanoidInstance = character:WaitForChild("Humanoid", 10)
	local headInstance = character:WaitForChild("Head", 10)
	if
		not humanoidInstance
		or not humanoidInstance:IsA("Humanoid")
		or not headInstance
		or not headInstance:IsA("BasePart")
		or not character.Parent
	then
		return
	end
	local humanoid = humanoidInstance :: Humanoid
	local head = headInstance :: BasePart

	local h = hashUserId(player.UserId)
	local outfitSlot = (h % #CAMPER_OUTFIT_PALETTE) + 1
	-- Legs draw a second palette color, shifted so it never matches the torso.
	local legSlot = (math.floor(h / 12) % (#CAMPER_OUTFIT_PALETTE - 1)) + 1
	if legSlot >= outfitSlot then
		legSlot += 1
	end
	local outfitColor = CAMPER_OUTFIT_PALETTE[outfitSlot]
	local legColor = CAMPER_OUTFIT_PALETTE[legSlot]
	local skinTone = BOT_SKIN_TONES[(math.floor(h / 144) % #BOT_SKIN_TONES) + 1]
	local hairColor = HAIR_COLORS[(math.floor(h / 720) % #HAIR_COLORS) + 1]
	local wearsBackpack = math.floor(h / 7200) % 2 == 0

	-- Clear anything the player's own avatar may have loaded (defensive: the
	-- place also sets StarterPlayer.LoadCharacterAppearance = false).
	humanoid:RemoveAccessories()
	for _, child in character:GetChildren() do
		if
			child:IsA("Shirt")
			or child:IsA("Pants")
			or child:IsA("ShirtGraphic")
			or child:IsA("CharacterMesh")
		then
			child:Destroy()
		end
	end

	-- BodyColors covers both R6 and R15 rigs: skin on head/arms, camper
	-- outfit color on the torso, a second palette color for the legs.
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
		or Instance.new("BodyColors")
	bodyColors.HeadColor3 = skinTone
	bodyColors.LeftArmColor3 = skinTone
	bodyColors.RightArmColor3 = skinTone
	bodyColors.TorsoColor3 = outfitColor
	bodyColors.LeftLegColor3 = legColor
	bodyColors.RightLegColor3 = legColor
	bodyColors.Parent = character

	-- Cap crown + brim in the outfit color: a strong head-level color read
	-- for eyewitness identification. Fixed offsets hug both the R6 mesh head
	-- (visually ~1.25 studs despite the 2x1x1 part) and the R15 head.
	local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6
	local headTop = if isR6 then 0.62 else head.Size.Y * 0.5
	local crown = makeAccentPart("CamperCapCrown", Vector3.new(1.25, 0.3, 1.25), outfitColor)
	weldAccent(character, head, crown, CFrame.new(0, headTop + 0.06, 0))
	local brim = makeAccentPart("CamperCapBrim", Vector3.new(1.1, 0.12, 0.5), outfitColor)
	weldAccent(character, head, brim, CFrame.new(0, headTop - 0.02, -0.82))

	-- Hair fringe peeking out under the back of the cap, from the shared
	-- hair palette, so campers with the same outfit still read differently.
	local fringe = makeAccentPart("CamperHairFringe", Vector3.new(1.2, 0.24, 0.35), hairColor)
	weldAccent(character, head, fringe, CFrame.new(0, headTop - 0.18, 0.5))

	-- Half of all campers carry a backpack in their leg color, visible from
	-- behind. Welded to Torso (R6) or UpperTorso (R15).
	if wearsBackpack then
		local torso = character:FindFirstChild("UpperTorso")
			or character:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			local backpackSize = Vector3.new(1.2, 1.35, 0.55)
			local backpack = makeAccentPart("CamperBackpack", backpackSize, legColor)
			weldAccent(
				character,
				torso,
				backpack,
				CFrame.new(0, 0.05, torso.Size.Z * 0.5 + backpackSize.Z * 0.5 + 0.02)
			)
		end
	end

	local colorName = PALETTE_COLOR_NAMES[outfitSlot] or string.format("Slot%d", outfitSlot)
	character:SetAttribute("CamperOutfitColor", colorName)
	character:SetAttribute("CamperOutfitSlot", outfitSlot)
end

function CharacterService.new(): CharacterService
	return setmetatable({
		running = false,
		connections = {},
		characterConnections = {},
	}, CharacterService)
end

function CharacterService:WatchPlayer(player: Player)
	if self.characterConnections[player] then
		return
	end
	-- Belt-and-braces alongside the StarterPlayer project setting; affects
	-- any respawn after this point.
	player.CanLoadCharacterAppearance = false
	self.characterConnections[player] = player.CharacterAdded:Connect(function(character: Model)
		task.spawn(applyCamperLook, player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(applyCamperLook, player, character)
	end
end

function CharacterService:Start()
	if self.running then
		return
	end
	self.running = true

	table.insert(self.connections, Players.PlayerAdded:Connect(function(player: Player)
		self:WatchPlayer(player)
	end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player: Player)
		local connection = self.characterConnections[player]
		if connection then
			connection:Disconnect()
			self.characterConnections[player] = nil
		end
	end))
	for _, player in Players:GetPlayers() do
		self:WatchPlayer(player)
	end
end

function CharacterService:Stop()
	self.running = false
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	for _, connection in self.characterConnections do
		connection:Disconnect()
	end
	table.clear(self.characterConnections)
end

return CharacterService
