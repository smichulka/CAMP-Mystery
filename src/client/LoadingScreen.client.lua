--!strict
-- Branded loading screen for CAMP-Mystery.
-- This source is also visible through the broad StarterPlayer client mapping,
-- so only the ReplicatedFirst instance is allowed to run.

local ReplicatedFirst = game:GetService("ReplicatedFirst")

if script.Parent ~= ReplicatedFirst then
	return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local GOLD = Color3.fromRGB(210, 160, 50)
local GOLD_DIM = Color3.fromRGB(140, 104, 34)
local INK = Color3.fromRGB(8, 10, 12)
local INK_WARM = Color3.fromRGB(16, 13, 10)
local TEXT_SOFT = Color3.fromRGB(180, 180, 190)
local TEXT_FAINT = Color3.fromRGB(140, 140, 150)

local STATUS_LINES = {
	"Lighting the campfire",
	"Waking the counselors",
	"Checking the cabin locks",
	"Reading last night's reports",
	"Counting flashlight batteries",
	"Watching the treeline",
}

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGuiInstance = player:WaitForChild("PlayerGui", 15)
if playerGuiInstance == nil or not playerGuiInstance:IsA("PlayerGui") then
	return
end
local playerGui = playerGuiInstance :: PlayerGui

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
screenGui.DisplayOrder = 100
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = INK
background.BorderSizePixel = 0
background.Parent = screenGui

local backdropGradient = Instance.new("UIGradient")
backdropGradient.Rotation = 90
backdropGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, INK),
	ColorSequenceKeypoint.new(0.55, INK_WARM),
	ColorSequenceKeypoint.new(1, INK),
})
backdropGradient.Parent = background

-- Soft radial glow behind the title, like distant firelight
local glow = Instance.new("Frame")
glow.Name = "FireGlow"
glow.AnchorPoint = Vector2.new(0.5, 0.5)
glow.Position = UDim2.fromScale(0.5, 0.47)
glow.Size = UDim2.fromOffset(560, 260)
glow.BackgroundColor3 = GOLD
glow.BackgroundTransparency = 0.94
glow.BorderSizePixel = 0
glow.Parent = background
local glowCorner = Instance.new("UICorner")
glowCorner.CornerRadius = UDim.new(0.5, 0)
glowCorner.Parent = glow

local function addAccentBar(yAnchor: number)
	local bar = Instance.new("Frame")
	bar.Name = if yAnchor == 0 then "TopAccent" else "BottomAccent"
	bar.Size = UDim2.new(1, 0, 0, 3)
	bar.AnchorPoint = Vector2.new(0, yAnchor)
	bar.Position = UDim2.fromScale(0, yAnchor)
	bar.BackgroundColor3 = GOLD
	bar.BorderSizePixel = 0
	bar.Parent = background
	local barGradient = Instance.new("UIGradient")
	barGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD_DIM),
		ColorSequenceKeypoint.new(0.5, GOLD),
		ColorSequenceKeypoint.new(1, GOLD_DIM),
	})
	barGradient.Parent = bar
end

addAccentBar(0)
addAccentBar(1)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Text = "CAMP MYSTERY"
title.Font = Enum.Font.GothamBold
title.TextSize = 52
title.TextColor3 = GOLD
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.42)
title.Size = UDim2.new(1, -48, 0, 64)
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = background

local titleGradient = Instance.new("UIGradient")
titleGradient.Rotation = 90
titleGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(246, 214, 130)),
	ColorSequenceKeypoint.new(1, GOLD_DIM),
})
titleGradient.Parent = title

local tagline = Instance.new("TextLabel")
tagline.Name = "Tagline"
tagline.Text = "Something lurks at the edge of the firelight."
tagline.Font = Enum.Font.Gotham
tagline.TextSize = 15
tagline.TextColor3 = TEXT_SOFT
tagline.TextTransparency = 0.3
tagline.BackgroundTransparency = 1
tagline.AnchorPoint = Vector2.new(0.5, 0)
tagline.Position = UDim2.fromScale(0.5, 0.5)
tagline.Size = UDim2.new(1, -48, 0, 26)
tagline.TextXAlignment = Enum.TextXAlignment.Center
tagline.Parent = background

-- Progress track + fill
local track = Instance.new("Frame")
track.Name = "ProgressTrack"
track.AnchorPoint = Vector2.new(0.5, 0)
track.Position = UDim2.fromScale(0.5, 0.66)
track.Size = UDim2.fromOffset(320, 6)
track.BackgroundColor3 = Color3.fromRGB(34, 38, 44)
track.BorderSizePixel = 0
track.Parent = background
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Name = "ProgressFill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = GOLD
fill.BorderSizePixel = 0
fill.Parent = track
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill
local fillGradient = Instance.new("UIGradient")
fillGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, GOLD_DIM),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(246, 214, 130)),
})
fillGradient.Parent = fill

local loadingLabel = Instance.new("TextLabel")
loadingLabel.Name = "LoadingLabel"
loadingLabel.Text = STATUS_LINES[1] .. "..."
loadingLabel.Font = Enum.Font.Gotham
loadingLabel.TextSize = 13
loadingLabel.TextColor3 = TEXT_FAINT
loadingLabel.BackgroundTransparency = 1
loadingLabel.AnchorPoint = Vector2.new(0.5, 0)
loadingLabel.Position = UDim2.fromScale(0.5, 0.7)
loadingLabel.Size = UDim2.fromOffset(320, 22)
loadingLabel.TextXAlignment = Enum.TextXAlignment.Center
loadingLabel.Parent = background

local running = true

-- Rising embers drifting up past the title
task.spawn(function()
	local random = Random.new()
	while running do
		local ember = Instance.new("Frame")
		ember.AnchorPoint = Vector2.new(0.5, 0.5)
		local startX = 0.5 + random:NextNumber(-0.16, 0.16)
		ember.Position = UDim2.fromScale(startX, 0.78)
		local size = random:NextInteger(2, 4)
		ember.Size = UDim2.fromOffset(size, size)
		ember.BackgroundColor3 = if random:NextNumber() < 0.5
			then GOLD
			else Color3.fromRGB(226, 120, 62)
		ember.BackgroundTransparency = 0.25
		ember.BorderSizePixel = 0
		ember.Parent = background
		local emberCorner = Instance.new("UICorner")
		emberCorner.CornerRadius = UDim.new(1, 0)
		emberCorner.Parent = ember
		local rise = TweenService:Create(
			ember,
			TweenInfo.new(
				random:NextNumber(2.2, 3.6),
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.Out
			),
			{
				Position = UDim2.fromScale(
					startX + random:NextNumber(-0.05, 0.05),
					random:NextNumber(0.2, 0.34)
				),
				BackgroundTransparency = 1,
			}
		)
		rise.Completed:Connect(function()
			ember:Destroy()
		end)
		rise:Play()
		task.wait(random:NextNumber(0.28, 0.6))
	end
end)

-- Gentle title glow breathing
task.spawn(function()
	while running do
		local brighten = TweenService:Create(
			glow,
			TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ BackgroundTransparency = 0.9 }
		)
		brighten:Play()
		task.wait(1.4)
		if not running then
			break
		end
		local dim = TweenService:Create(
			glow,
			TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ BackgroundTransparency = 0.95 }
		)
		dim:Play()
		task.wait(1.4)
	end
end)

-- Rotate status lines
task.spawn(function()
	local index = 1
	while running do
		task.wait(1.6)
		if not running then
			break
		end
		index = (index % #STATUS_LINES) + 1
		loadingLabel.Text = STATUS_LINES[index] .. "..."
	end
end)

-- Honest-feeling progress: ease toward 90% while loading, snap to full when done
local LOAD_DEADLINE_SECONDS = 15
local startedAt = os.clock()
local progressConn: RBXScriptConnection? = nil
progressConn = RunService.Heartbeat:Connect(function()
	local elapsed = os.clock() - startedAt
	local fraction = 1 - math.exp(-elapsed / 4)
	fill.Size = UDim2.fromScale(math.min(0.9, fraction), 1)
end)

while not game:IsLoaded() and os.clock() - startedAt < LOAD_DEADLINE_SECONDS do
	task.wait(0.1)
end

if progressConn then
	progressConn:Disconnect()
	progressConn = nil
end
TweenService:Create(
	fill,
	TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{ Size = UDim2.fromScale(1, 1) }
):Play()
task.wait(0.45)

running = false
loadingLabel.Text = "Ready."

local fadeInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local fade = TweenService:Create(background, fadeInfo, { BackgroundTransparency = 1 })

for _, child in background:GetDescendants() do
	if child:IsA("TextLabel") then
		TweenService:Create(child, fadeInfo, { TextTransparency = 1 }):Play()
	elseif child:IsA("Frame") then
		TweenService:Create(child, fadeInfo, { BackgroundTransparency = 1 }):Play()
	end
end

fade.Completed:Connect(function()
	screenGui:Destroy()
end)
fade:Play()
