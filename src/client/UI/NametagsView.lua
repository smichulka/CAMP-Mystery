--!strict

local Players = game:GetService("Players")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Components = require(script.Parent:WaitForChild("Components"))

type NametagEntry = {
	billboard: BillboardGui,
	dot: Frame,
	nameLabel: TextLabel,
	charConn: RBXScriptConnection?,
	charRemovingConn: RBXScriptConnection?,
}

type NametagsViewState = {
	entries: { [string]: NametagEntry },
	destroyed: boolean,
}

local NametagsView = {}
NametagsView.__index = NametagsView

export type NametagsView = typeof(
	setmetatable({} :: NametagsViewState, NametagsView)
)

local VISIBLE_PHASES: { [string]: boolean } = {
	Day = true,
	Investigation = true,
	Campfire = true,
}

local function readBoolean(value: any, key: string, default: boolean): boolean
	if type(value) == "table" and type(value[key]) == "boolean" then
		return value[key]
	end
	return default
end

local function readString(value: any, key: string, default: string): string
	if type(value) == "table" and type(value[key]) == "string" then
		return value[key]
	end
	return default
end

local function buildBillboard(): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Nametag"
	billboard.Size = UDim2.fromOffset(120, 28)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = false
	billboard.ResetOnSpawn = false
	billboard.Enabled = false
	billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Theme.Colors.Panel
	bg.BackgroundTransparency = 0.22
	bg.BorderSizePixel = 0
	bg.Parent = billboard
	Components.Corner(bg, 6)

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.fromOffset(7, 7)
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.fromOffset(8, 14)
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = Theme.Colors.Success
	dot.Parent = bg
	Components.Corner(dot, 4)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -22, 1, 0)
	nameLabel.Position = UDim2.fromOffset(20, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 11
	nameLabel.TextColor3 = Theme.Colors.Text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = ""
	nameLabel.Parent = bg

	return billboard
end

local function destroyEntry(entry: NametagEntry)
	local connection = entry.charConn
	if connection then
		connection:Disconnect()
		entry.charConn = nil
	end
	local removingConnection = entry.charRemovingConn
	if removingConnection then
		removingConnection:Disconnect()
		entry.charRemovingConn = nil
	end
	entry.billboard:Destroy()
end

local function attachToCharacter(
	self: NametagsView,
	participantId: string,
	entry: NametagEntry,
	player: Player,
	character: Model
)
	if self.destroyed or self.entries[participantId] ~= entry then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		if player.Character == character then
			entry.billboard.Parent = rootPart
		end
		return
	end

	task.spawn(function()
		local waitedRoot = character:WaitForChild("HumanoidRootPart", 4)
		if self.destroyed
			or self.entries[participantId] ~= entry
			or player.Character ~= character
		then
			return
		end
		if waitedRoot and waitedRoot:IsA("BasePart") then
			entry.billboard.Parent = waitedRoot
		end
	end)
end

local function createEntry(
	self: NametagsView,
	participantId: string,
	player: Player
): NametagEntry
	local billboard = buildBillboard()
	local bg = billboard:FindFirstChild("Bg")
	assert(bg and bg:IsA("Frame"))
	local dot = bg:FindFirstChild("Dot")
	assert(dot and dot:IsA("Frame"))
	local nameLabel = bg:FindFirstChild("Name")
	assert(nameLabel and nameLabel:IsA("TextLabel"))

	local entry: NametagEntry = {
		billboard = billboard,
		dot = dot,
		nameLabel = nameLabel,
		charConn = nil,
		charRemovingConn = nil,
	}
	self.entries[participantId] = entry

	local previousConnection = entry.charConn
	if previousConnection then
		previousConnection:Disconnect()
	end
	entry.charConn = player.CharacterAdded:Connect(function(character: Model)
		attachToCharacter(self, participantId, entry, player, character)
	end)
	local previousRemovingConnection = entry.charRemovingConn
	if previousRemovingConnection then
		previousRemovingConnection:Disconnect()
	end
	entry.charRemovingConn = player.CharacterRemoving:Connect(function(character: Model)
		if self.destroyed or self.entries[participantId] ~= entry then
			return
		end
		local parent = entry.billboard.Parent
		if parent and parent:IsDescendantOf(character) then
			entry.billboard.Parent = nil
		end
	end)

	local character = player.Character
	if character then
		attachToCharacter(self, participantId, entry, player, character)
	end

	return entry
end

function NametagsView.new(): NametagsView
	return setmetatable({
		entries = {},
		destroyed = false,
	}, NametagsView)
end

function NametagsView:Update(
	participants: { any },
	localParticipantId: string,
	phase: string
)
	if self.destroyed then
		return
	end
	if not VISIBLE_PHASES[phase] then
		for _, entry in self.entries do
			entry.billboard.Enabled = false
		end
		return
	end

	local present: { [string]: boolean } = {}
	for _, participant in participants do
		if readBoolean(participant, "isBot", false) then
			continue
		end

		local participantId = readString(participant, "participantId", "")
		local userId = tonumber(participantId)
		if not userId
			or userId ~= userId
			or math.abs(userId) == math.huge
			or userId % 1 ~= 0
		then
			continue
		end

		local player = Players:GetPlayerByUserId(userId)
		if not player then
			continue
		end
		present[participantId] = true

		local entry = self.entries[participantId]
		if not entry then
			entry = createEntry(self, participantId, player)
		end

		local displayName = readString(participant, "displayName", "Unknown camper")
		local alive = readBoolean(participant, "alive", false)
		local isGhost = readBoolean(participant, "isGhost", false)
		local healthState = readString(participant, "healthState", "Healthy")
		local dead = not alive and not isGhost

		entry.billboard.Enabled = true
		entry.dot.BackgroundColor3 = if isGhost
			then Theme.Colors.Ghost
			elseif alive and (healthState == "Injured" or healthState == "Critical")
				then Theme.Colors.Danger
			elseif not alive then Theme.Colors.TextMuted
			else Theme.Colors.Success
		entry.nameLabel.Text = if participantId == localParticipantId
			then displayName .. " ▸"
			else displayName
		entry.nameLabel.TextColor3 = if dead
			then Theme.Colors.TextMuted
			elseif isGhost then Theme.Colors.Ghost
			else Theme.Colors.Text

		local bg = entry.billboard:FindFirstChild("Bg")
		if bg and bg:IsA("Frame") then
			bg.BackgroundTransparency = if dead then 0.55 else 0.22
		end
	end

	local departed: { string } = {}
	for participantId in self.entries do
		if not present[participantId] then
			table.insert(departed, participantId)
		end
	end
	for _, participantId in departed do
		local entry = self.entries[participantId]
		if entry then
			self.entries[participantId] = nil
			destroyEntry(entry)
		end
	end
end

function NametagsView:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	for _, entry in self.entries do
		destroyEntry(entry)
	end
	table.clear(self.entries)
end

return table.freeze(NametagsView)
