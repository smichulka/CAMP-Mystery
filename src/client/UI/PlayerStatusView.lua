--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Components = require(script.Parent:WaitForChild("Components"))
local Motion = require(script.Parent:WaitForChild("Motion"))
local Theme = require(script.Parent:WaitForChild("Theme"))

type PlayerStatusViewState = {
	root: Instance,
	panel: CanvasGroup,
	list: ScrollingFrame,
	titleLabel: TextLabel,
	phaseLabel: TextLabel,
	destroyed: boolean,
	visible: boolean,
	canShow: boolean,
	lastSignature: string,
}

local PlayerStatusView = {}
PlayerStatusView.__index = PlayerStatusView

export type PlayerStatusView = typeof(
	setmetatable({} :: PlayerStatusViewState, PlayerStatusView)
)

local VISIBLE_PHASES: { [string]: boolean } = {
	Day = true,
	Investigation = true,
	Campfire = true,
	MurderPlanning = true,
	NightTransform = true,
	Resolution = true,
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

local function phaseDisplayName(phase: string): string
	return string.upper(phase:gsub("(%l)(%u)", "%1 %2"))
end

local function statusFor(participant: any): (Color3, string, Color3)
	local alive = readBoolean(participant, "alive", false)
	local isGhost = readBoolean(participant, "isGhost", false)
	local healthState = readString(participant, "healthState", "Healthy")

	if isGhost then
		return Theme.Colors.Ghost, "GHOST", Theme.Colors.Ghost
	end
	if not alive then
		return Theme.Colors.TextMuted, "DEAD", Theme.Colors.TextMuted
	end
	if healthState == "Incapacitated" or healthState == "Critical" then
		return Theme.Colors.Danger, "DOWN", Theme.Colors.Danger
	end
	if healthState == "Injured" then
		return Theme.Colors.Danger, "INJURED", Theme.Colors.Danger
	end
	return Theme.Colors.Success, "", Theme.Colors.TextMuted
end

local function appendSignatureValue(pieces: { string }, value: any)
	table.insert(pieces, tostring(value))
end

local function buildSignature(
	participants: { any },
	localPlayer: any,
	phase: string
): string
	local pieces: { string } = { phase }
	appendSignatureValue(pieces, readString(localPlayer, "participantId", ""))
	appendSignatureValue(pieces, readBoolean(localPlayer, "isGhost", false))
	appendSignatureValue(pieces, readString(localPlayer, "role", ""))
	appendSignatureValue(pieces, readString(localPlayer, "roleDisplayName", ""))

	for _, participant in participants do
		if type(participant) == "table" then
			appendSignatureValue(pieces, readString(participant, "participantId", ""))
			appendSignatureValue(pieces, readString(participant, "displayName", ""))
			appendSignatureValue(pieces, readBoolean(participant, "alive", false))
			appendSignatureValue(pieces, readBoolean(participant, "isGhost", false))
			appendSignatureValue(pieces, readString(participant, "healthState", "Healthy"))
			appendSignatureValue(pieces, readBoolean(participant, "connected", true))
		end
	end

	return table.concat(pieces, "\31")
end

local function sortedParticipants(participants: { any }): { any }
	local alive: { any } = {}
	local ghosts: { any } = {}
	local dead: { any } = {}

	for _, participant in participants do
		if type(participant) == "table" then
			if readBoolean(participant, "alive", false) then
				table.insert(alive, participant)
			elseif readBoolean(participant, "isGhost", false) then
				table.insert(ghosts, participant)
			else
				table.insert(dead, participant)
			end
		end
	end

	local sorted: { any } = {}
	for _, bucket in { alive, ghosts, dead } do
		for _, participant in bucket do
			table.insert(sorted, participant)
		end
	end
	return sorted
end

local function createDetailLabel(
	parent: Instance,
	name: string,
	text: string,
	textSize: number
): TextLabel
	local label = Components.Label(parent, name, text, textSize, Enum.Font.Gotham)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 15)
	label.TextColor3 = Theme.Colors.TextMuted
	label.TextWrapped = false
	label.ZIndex = 72
	return label
end

local function createRow(
	self: PlayerStatusView,
	participant: any,
	index: number,
	localPlayer: any
)
	local participantId = readString(participant, "participantId", "")
	local ownParticipantId = readString(localPlayer, "participantId", "")
	local isLocalPlayer = ownParticipantId ~= "" and participantId == ownParticipantId
	local alive = readBoolean(participant, "alive", false)
	local isGhost = readBoolean(participant, "isGhost", false)
	local connected = readBoolean(participant, "connected", true)
	local observerCanInspectRoles = readBoolean(localPlayer, "isGhost", false)
		or readString(localPlayer, "role", "") == "Spectator"
	local dotColor, statusText, statusColor = statusFor(participant)

	local row = Instance.new("Frame")
	row.Name = "Player_" .. (if participantId ~= "" then participantId:gsub("[^%w]", "_") else tostring(index))
	row:SetAttribute("Generated", true)
	row.Size = UDim2.new(1, -24, 0, 42)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.LayoutOrder = index
	row.ZIndex = 71
	row.Parent = self.list

	local dot = Instance.new("Frame")
	dot.Name = "StatusDot"
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.fromOffset(2, 21)
	dot.Size = UDim2.fromOffset(12, 12)
	dot.BackgroundColor3 = dotColor
	dot.BorderSizePixel = 0
	dot.ZIndex = 72
	dot.Parent = row
	Components.Corner(dot, 6)

	local nameLabel = Components.Label(
		row,
		"DisplayName",
		readString(participant, "displayName", "Unknown player"),
		14,
		Enum.Font.Gotham
	)
	nameLabel.Position = UDim2.fromOffset(24, 2)
	nameLabel.Size = UDim2.new(1, -104, 0, 19)
	nameLabel.TextColor3 = if alive then Theme.Colors.Text else Theme.Colors.TextMuted
	nameLabel.TextTransparency = if connected then 0 else 0.5
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.TextWrapped = false
	nameLabel.ZIndex = 72

	local statusLabel = Components.Label(
		row,
		"Status",
		statusText,
		11,
		Enum.Font.Gotham
	)
	statusLabel.AnchorPoint = Vector2.new(1, 0)
	statusLabel.Position = UDim2.new(1, -5, 0, 3)
	statusLabel.Size = UDim2.fromOffset(72, 18)
	statusLabel.TextColor3 = statusColor
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right
	statusLabel.TextWrapped = false
	statusLabel.ZIndex = 72

	local details = Instance.new("Frame")
	details.Name = "Details"
	details.Position = UDim2.fromOffset(24, 22)
	details.Size = UDim2.new(1, -32, 0, 16)
	details.BackgroundTransparency = 1
	details.BorderSizePixel = 0
	details.ZIndex = 72
	details.Parent = row

	local detailsLayout = Instance.new("UIListLayout")
	detailsLayout.FillDirection = Enum.FillDirection.Horizontal
	detailsLayout.Padding = UDim.new(0, 5)
	detailsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	detailsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	detailsLayout.Parent = details

	if observerCanInspectRoles then
		local roleText = if isLocalPlayer
			then readString(
				localPlayer,
				"roleDisplayName",
				readString(localPlayer, "role", "Unknown")
			)
			else "(Role: ?)"
		local roleLabel = createDetailLabel(details, "Role", roleText, 11)
		roleLabel.TextColor3 = if isLocalPlayer
				and readString(localPlayer, "role", "") == "Murderer"
			then Theme.Colors.Gold
			elseif isLocalPlayer then Theme.Colors.Info
			else Theme.Colors.TextMuted
		roleLabel.LayoutOrder = 1
	end

	if not connected then
		local connectionLabel =
			createDetailLabel(details, "Connection", "(disconnected)", 10)
		connectionLabel.LayoutOrder = 2
	end

	if isLocalPlayer then
		local accent = Instance.new("Frame")
		accent.Name = "LocalPlayerAccent"
		accent.AnchorPoint = Vector2.new(1, 0)
		accent.Position = UDim2.fromScale(1, 0)
		accent.Size = UDim2.new(0, 2, 1, 0)
		accent.BackgroundColor3 = Theme.Colors.Gold
		accent.BackgroundTransparency = 0.25
		accent.BorderSizePixel = 0
		accent.ZIndex = 72
		accent.Parent = row
	end
end

function PlayerStatusView.new(parent: Instance): PlayerStatusView
	local panel = Instance.new("CanvasGroup")
	panel.Name = "PlayerStatusPanel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.fromScale(1, 0)
	panel.Size = UDim2.new(0, 270, 1, 0)
	panel.BackgroundColor3 = Theme.Colors.Background
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.GroupTransparency = 1
	panel.Active = false
	panel.ZIndex = 70
	panel.Parent = parent

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundColor3 = Theme.Colors.Panel
	header.BorderSizePixel = 0
	header.ZIndex = 71
	header.Parent = panel

	local title = Components.Label(
		header,
		"RosterTitle",
		"CAMP ROSTER",
		14,
		Enum.Font.GothamBold
	)
	title.Position = UDim2.fromOffset(12, 5)
	title.Size = UDim2.new(1, -24, 0, 22)
	title.TextColor3 = Theme.Colors.Gold
	title.TextWrapped = false
	title.ZIndex = 72
	Components.SetLetterspacedText(title, "CAMP ROSTER")

	local phaseLabel = Components.Label(
		header,
		"Phase",
		"",
		11,
		Enum.Font.Gotham
	)
	phaseLabel.Position = UDim2.fromOffset(12, 26)
	phaseLabel.Size = UDim2.new(1, -24, 0, 17)
	phaseLabel.TextColor3 = Theme.Colors.TextMuted
	phaseLabel.TextWrapped = false
	phaseLabel.ZIndex = 72

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Position = UDim2.fromOffset(0, 48)
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.BackgroundColor3 = Theme.Colors.Ghost
	divider.BackgroundTransparency = 0.7
	divider.BorderSizePixel = 0
	divider.ZIndex = 72
	divider.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 50)
	list.Size = UDim2.new(1, 0, 1, -50)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Theme.Colors.TextMuted
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ZIndex = 71
	list.Parent = panel
	Components.List(list, 6)
	Components.Padding(list, 12, 8)

	return setmetatable({
		root = parent,
		panel = panel,
		list = list,
		titleLabel = title,
		phaseLabel = phaseLabel,
		destroyed = false,
		visible = false,
		canShow = false,
		lastSignature = "",
	}, PlayerStatusView)
end

function PlayerStatusView:_show()
	if self.destroyed or not self.canShow then
		return
	end
	self.visible = true
	self.panel.Active = true
	if Motion.IsReducedMotion(self.panel) then
		Motion.Cancel(self.panel)
		self.panel.GroupTransparency = 0
	else
		-- FadeIn captures the visible resting values before making the tree
		-- transparent, so establish the panel's resting state first.
		self.panel.GroupTransparency = 0
		Motion.FadeIn(self.panel)
	end
end

function PlayerStatusView:_hide()
	if self.destroyed then
		return
	end
	self.visible = false
	self.panel.Active = false
	if Motion.IsReducedMotion(self.panel) then
		Motion.Cancel(self.panel)
		self.panel.GroupTransparency = 1
	else
		Motion.FadeOut(self.panel, {
			onComplete = function(_completed: boolean)
				if not self.destroyed and not self.visible then
					self.panel.GroupTransparency = 1
				end
			end,
		})
	end
end

function PlayerStatusView:Toggle()
	if self.destroyed then
		return
	end
	if self.visible then
		self:_hide()
	elseif self.canShow then
		self:_show()
	end
end

function PlayerStatusView:Update(
	participants: { any },
	localPlayer: any,
	phase: string
)
	if self.destroyed then
		return
	end
	if not VISIBLE_PHASES[phase] then
		self.canShow = false
		if self.visible then
			self:_hide()
		else
			self.panel.Active = false
			self.panel.GroupTransparency = 1
		end
		self.lastSignature = ""
		return
	end

	self.canShow = true
	self.phaseLabel.Text = phaseDisplayName(phase)
	local signature = buildSignature(participants, localPlayer, phase)
	if signature == self.lastSignature then
		return
	end
	self.lastSignature = signature

	local localRole = readString(localPlayer, "role", "")
	local localIsGhost = readBoolean(localPlayer, "isGhost", false)
	local headerText = if localRole == "Murderer"
		then "SUSPECTS"
		elseif localIsGhost
		then "SPIRIT VIEW"
		elseif localRole == "Spectator"
		then "SPECTATOR VIEW"
		else "CAMP ROSTER"
	Components.SetLetterspacedText(self.titleLabel, headerText)

	Components.ClearGenerated(self.list)
	for index, participant in sortedParticipants(participants) do
		createRow(self, participant, index, localPlayer)
	end
end

function PlayerStatusView:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.visible = false
	Motion.Cancel(self.panel)
	if self.panel.Parent then
		self.panel:Destroy()
	end
end

return PlayerStatusView
