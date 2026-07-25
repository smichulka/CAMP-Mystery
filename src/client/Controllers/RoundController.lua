--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local typesFolder = Shared:WaitForChild("Types")
local Types = require(typesFolder:WaitForChild("GameTypes"))

type RoundSnapshot = Types.RoundSnapshot
type PlayerSnapshot = Types.PlayerSnapshot
type Suspect = Types.Suspect

local RoundController = {}

local roundSnapshot: RoundSnapshot? = nil
local playerSnapshot: PlayerSnapshot? = nil
local currentVoteSignature = ""
local submitVoteRemote: RemoteEvent? = nil

type View = {
	statusLabel: TextLabel,
	progressLabel: TextLabel,
	roleLabel: TextLabel,
	evidenceLabel: TextLabel,
	voteFrame: Frame,
	voteList: Frame,
}

local function addCorner(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function addPadding(instance: GuiObject, amount: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, amount)
	padding.PaddingRight = UDim.new(0, amount)
	padding.PaddingBottom = UDim.new(0, amount)
	padding.PaddingLeft = UDim.new(0, amount)
	padding.Parent = instance
end

local function createPanel(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	anchorPoint: Vector2
): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = anchorPoint
	panel.Position = position
	panel.Size = size
	panel.BackgroundColor3 = Color3.fromRGB(14, 18, 20)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Parent = parent
	addCorner(panel, 10)
	return panel
end

local function createTextLabel(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	textSize: number,
	alignment: Enum.TextXAlignment
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamMedium
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(232, 227, 209)
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = alignment
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Parent = parent
	return label
end

local function getOrCreateView(): View
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gameUI = playerGui:WaitForChild("GameUI")
	assert(gameUI:IsA("ScreenGui"), "GameUI must be a ScreenGui")

	local oldStatus = gameUI:FindFirstChild("RoundStatus")
	if oldStatus then
		oldStatus:Destroy()
	end
	local oldRoot = gameUI:FindFirstChild("RoundHUD")
	if oldRoot then
		oldRoot:Destroy()
	end

	local root = Instance.new("Frame")
	root.Name = "RoundHUD"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gameUI

	local statusPanel = createPanel(
		root,
		"StatusPanel",
		UDim2.fromScale(0.5, 0.025),
		UDim2.fromOffset(520, 118),
		Vector2.new(0.5, 0)
	)
	local statusLabel = createTextLabel(
		statusPanel,
		"Status",
		UDim2.fromOffset(12, 10),
		UDim2.new(1, -24, 0, 58),
		22,
		Enum.TextXAlignment.Center
	)
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextYAlignment = Enum.TextYAlignment.Center
	local progressLabel = createTextLabel(
		statusPanel,
		"Progress",
		UDim2.fromOffset(12, 70),
		UDim2.new(1, -24, 0, 38),
		15,
		Enum.TextXAlignment.Center
	)

	local rolePanel = createPanel(
		root,
		"RolePanel",
		UDim2.fromOffset(18, 18),
		UDim2.fromOffset(300, 150),
		Vector2.zero
	)
	local roleLabel = createTextLabel(
		rolePanel,
		"Role",
		UDim2.fromOffset(4, 4),
		UDim2.new(1, -8, 1, -8),
		16,
		Enum.TextXAlignment.Left
	)
	addPadding(roleLabel, 10)

	local evidencePanel = createPanel(
		root,
		"EvidencePanel",
		UDim2.new(1, -18, 0, 18),
		UDim2.fromOffset(330, 220),
		Vector2.new(1, 0)
	)
	local evidenceLabel = createTextLabel(
		evidencePanel,
		"Evidence",
		UDim2.fromOffset(4, 4),
		UDim2.new(1, -8, 1, -8),
		15,
		Enum.TextXAlignment.Left
	)
	addPadding(evidenceLabel, 10)

	local voteFrame = createPanel(
		root,
		"VotePanel",
		UDim2.fromScale(0.5, 0.52),
		UDim2.fromOffset(430, 330),
		Vector2.new(0.5, 0.5)
	)
	voteFrame.Visible = false

	local voteTitle = createTextLabel(
		voteFrame,
		"Title",
		UDim2.fromOffset(16, 12),
		UDim2.new(1, -32, 0, 52),
		22,
		Enum.TextXAlignment.Center
	)
	voteTitle.Font = Enum.Font.GothamBold
	voteTitle.Text = "WHO IS THE MURDERER?"

	local voteList = Instance.new("Frame")
	voteList.Name = "VoteList"
	voteList.BackgroundTransparency = 1
	voteList.Position = UDim2.fromOffset(18, 70)
	voteList.Size = UDim2.new(1, -36, 1, -88)
	voteList.Parent = voteFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = voteList

	return {
		statusLabel = statusLabel,
		progressLabel = progressLabel,
		roleLabel = roleLabel,
		evidenceLabel = evidenceLabel,
		voteFrame = voteFrame,
		voteList = voteList,
	}
end

local function formatEvidence(snapshot: RoundSnapshot): string
	local lines = {
		string.format("EVIDENCE  %d/%d", snapshot.evidenceFound, snapshot.evidenceGoal),
	}
	if #snapshot.evidence == 0 then
		table.insert(lines, "\nNo clues collected.")
	else
		for _, evidence in snapshot.evidence do
			table.insert(
				lines,
				string.format(
					"\n• %s\n  %s\n  Found by %s",
					evidence.displayName,
					evidence.description,
					evidence.foundBy
				)
			)
		end
	end
	return table.concat(lines)
end

local function getVoteSignature(snapshot: RoundSnapshot, personal: PlayerSnapshot?): string
	local pieces = { snapshot.phase, tostring(personal and personal.hasVoted) }
	for _, suspect in snapshot.suspects do
		table.insert(pieces, suspect.key)
	end
	return table.concat(pieces, "|")
end

local function createVoteButton(parent: Instance, suspect: Suspect, disabled: boolean)
	local button = Instance.new("TextButton")
	button.Name = "Vote_" .. suspect.key:gsub("[^%w]", "_")
	button.Size = UDim2.new(1, 0, 0, 48)
	button.BackgroundColor3 = if disabled
		then Color3.fromRGB(58, 61, 61)
		else Color3.fromRGB(104, 47, 43)
	button.BorderSizePixel = 0
	button.AutoButtonColor = not disabled
	button.Font = Enum.Font.GothamBold
	button.Text = if disabled then suspect.displayName .. " — VOTE LOCKED" else suspect.displayName
	button.TextColor3 = Color3.fromRGB(242, 234, 214)
	button.TextSize = 18
	button.Active = not disabled
	button.Parent = parent
	addCorner(button, 8)

	if not disabled then
		button.Activated:Connect(function()
			local remote = submitVoteRemote
			if remote then
				remote:FireServer(suspect.key)
			end
		end)
	end
end

local function updateVotePanel(view: View, snapshot: RoundSnapshot, personal: PlayerSnapshot?)
	if snapshot.phase ~= "Campfire" or not personal or not personal.alive then
		view.voteFrame.Visible = false
		currentVoteSignature = ""
		return
	end
	view.voteFrame.Visible = true

	local signature = getVoteSignature(snapshot, personal)
	if signature == currentVoteSignature then
		return
	end
	currentVoteSignature = signature

	for _, child in view.voteList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for _, suspect in snapshot.suspects do
		createVoteButton(view.voteList, suspect, personal.hasVoted)
	end
end

local function updateView(view: View)
	local current = roundSnapshot
	if not current then
		view.statusLabel.Text = "Waiting for the camp..."
		return
	end

	local secondsRemaining = math.max(
		0,
		math.ceil(current.phaseEndsAt - workspace:GetServerTimeNow())
	)
	view.statusLabel.Text = string.format(
		"ROUND %d  •  %s\n%d seconds",
		current.roundNumber,
		current.phaseDisplayName,
		secondsRemaining
	)

	if current.phase == "Day" then
		view.progressLabel.Text = string.format(
			"Camp jobs: %d/%d — use the glowing stations",
			current.objectivesCompleted,
			current.objectiveGoal
		)
	elseif current.phase == "Investigation" then
		view.progressLabel.Text = string.format(
			"Evidence: %d/%d — search the abandoned road",
			current.evidenceFound,
			current.evidenceGoal
		)
	elseif current.phase == "Campfire" then
		view.progressLabel.Text = string.format(
			"Votes: %d/%d — the verdict locks when everyone votes",
			current.votesCast,
			current.eligibleVoters
		)
	elseif current.resultMessage then
		view.progressLabel.Text = current.resultMessage
	elseif current.victimName then
		view.progressLabel.Text = current.victimName .. " is missing."
	else
		view.progressLabel.Text = if current.isNight
			then "The abandoned town is active."
			else "The camp is quiet—for now."
	end

	local personal = playerSnapshot
	if personal then
		local lifeState = if personal.isGhost
			then "GHOST"
			elseif personal.alive then "ALIVE"
			else "WAITING"
		view.roleLabel.Text = string.format(
			"%s  •  %s\n\n%s\n\n%s",
			string.upper(personal.roleDisplayName),
			lifeState,
			personal.roleDescription,
			personal.statusMessage
		)
	else
		view.roleLabel.Text = "ROLE PENDING\n\nWaiting for the server..."
	end

	view.evidenceLabel.Text = formatEvidence(current)
	updateVotePanel(view, current, personal)
end

function RoundController.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local roundStateChanged = remotes:WaitForChild("RoundStateChanged")
	local getRoundState = remotes:WaitForChild("GetRoundState")
	local playerStateChanged = remotes:WaitForChild("PlayerStateChanged")
	local getPlayerState = remotes:WaitForChild("GetPlayerState")
	local submitVote = remotes:WaitForChild("SubmitVote")

	assert(roundStateChanged:IsA("RemoteEvent"), "RoundStateChanged must be a RemoteEvent")
	assert(getRoundState:IsA("RemoteFunction"), "GetRoundState must be a RemoteFunction")
	assert(playerStateChanged:IsA("RemoteEvent"), "PlayerStateChanged must be a RemoteEvent")
	assert(getPlayerState:IsA("RemoteFunction"), "GetPlayerState must be a RemoteFunction")
	assert(submitVote:IsA("RemoteEvent"), "SubmitVote must be a RemoteEvent")
	submitVoteRemote = submitVote

	local view = getOrCreateView()

	roundStateChanged.OnClientEvent:Connect(function(nextSnapshot: RoundSnapshot)
		roundSnapshot = nextSnapshot
		updateView(view)
	end)

	playerStateChanged.OnClientEvent:Connect(function(nextSnapshot: PlayerSnapshot)
		playerSnapshot = nextSnapshot
		updateView(view)
	end)

	local roundSuccess, initialRound = pcall(function()
		return getRoundState:InvokeServer()
	end)
	if roundSuccess then
		roundSnapshot = initialRound :: RoundSnapshot
	else
		warn("[RoundController] Could not retrieve round state:", initialRound)
	end

	local playerSuccess, initialPlayer = pcall(function()
		return getPlayerState:InvokeServer()
	end)
	if playerSuccess then
		playerSnapshot = initialPlayer :: PlayerSnapshot
	else
		warn("[RoundController] Could not retrieve player state:", initialPlayer)
	end

	updateView(view)
	task.spawn(function()
		while view.statusLabel.Parent do
			updateView(view)
			task.wait(0.25)
		end
	end)
end

return RoundController
