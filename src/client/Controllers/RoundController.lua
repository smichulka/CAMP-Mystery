--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local typesFolder = Shared:WaitForChild("Types")
local Types = require(typesFolder:WaitForChild("GameTypes"))

type RoundSnapshot = Types.RoundSnapshot

local RoundController = {}

local snapshot: RoundSnapshot? = nil

local function getOrCreateStatusLabel(): TextLabel
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gameUI = playerGui:WaitForChild("GameUI")

	assert(gameUI:IsA("ScreenGui"), "GameUI must be a ScreenGui")

	local existing = gameUI:FindFirstChild("RoundStatus")
	if existing and existing:IsA("TextLabel") then
		return existing
	end

	local label = Instance.new("TextLabel")
	label.Name = "RoundStatus"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.03)
	label.Size = UDim2.fromOffset(420, 72)
	label.BackgroundColor3 = Color3.fromRGB(14, 18, 19)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(231, 226, 205)
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = "Waiting for the camp..."
	label.Parent = gameUI

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.Parent = label

	return label
end

local function updateLabel(label: TextLabel)
	local current = snapshot
	if not current then
		label.Text = "Waiting for the camp..."
		return
	end

	local secondsRemaining = math.max(0, math.ceil(current.phaseEndsAt - workspace:GetServerTimeNow()))
	label.Text = string.format(
		"ROUND %d  •  %s\n%d seconds",
		current.roundNumber,
		current.phaseDisplayName,
		secondsRemaining
	)
end

function RoundController.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local roundStateChanged = remotes:WaitForChild("RoundStateChanged")
	local getRoundState = remotes:WaitForChild("GetRoundState")

	assert(roundStateChanged:IsA("RemoteEvent"), "RoundStateChanged must be a RemoteEvent")
	assert(getRoundState:IsA("RemoteFunction"), "GetRoundState must be a RemoteFunction")

	local statusLabel = getOrCreateStatusLabel()

	roundStateChanged.OnClientEvent:Connect(function(nextSnapshot: RoundSnapshot)
		snapshot = nextSnapshot
		updateLabel(statusLabel)
	end)

	local success, initialSnapshot = pcall(function()
		return getRoundState:InvokeServer()
	end)

	if success then
		snapshot = initialSnapshot :: RoundSnapshot
	else
		warn("[RoundController] Could not retrieve initial round state:", initialSnapshot)
	end

	updateLabel(statusLabel)

	task.spawn(function()
		while statusLabel.Parent do
			updateLabel(statusLabel)
			task.wait(0.25)
		end
	end)
end

return RoundController
