--!strict

-- Tags every real player with a deterministic camp outfit identity for eyewitness
-- gameplay ("the camper in the mustard cap was near the generator") while keeping
-- their Roblox avatar appearance. Bots use anchored prop rigs from
-- CharacterAssetService; real Humanoid rigs keep catalog hair, face, and clothing.

local Players = game:GetService("Players")

local CharacterAssetService = require(script.Parent:WaitForChild("CharacterAssetService"))

local CAMPER_OUTFIT_PALETTE = CharacterAssetService.CamperOutfitPalette

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

	local humanoidInstance = character:WaitForChild("Humanoid", 10)
	local torso = character:WaitForChild("UpperTorso", 10)
		or character:WaitForChild("Torso", 10)
	if
		not humanoidInstance
		or not humanoidInstance:IsA("Humanoid")
		or not (torso and torso:IsA("BasePart"))
		or not character.Parent
	then
		return
	end

	local h = hashUserId(player.UserId)
	local outfitSlot = (h % #CAMPER_OUTFIT_PALETTE) + 1
	local outfitColor = CAMPER_OUTFIT_PALETTE[outfitSlot]
	local colorName = PALETTE_COLOR_NAMES[outfitSlot] or string.format("Slot%d", outfitSlot)
	character:SetAttribute("CamperOutfitColor", colorName)
	character:SetAttribute("CamperOutfitSlot", outfitSlot)
	character:SetAttribute("CamperLookApplied", true)

	if character:FindFirstChild("CampArmband") then
		return
	end
	local band = makeAccentPart("CampArmband", Vector3.new(0.55, 0.18, 0.08), outfitColor)
	weldAccent(
		character,
		torso :: BasePart,
		band,
		CFrame.new(-((torso :: BasePart).Size.X * 0.5 + 0.08), (torso :: BasePart).Size.Y * 0.18, 0)
	)
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
