--!strict
-- Branded loading screen for CAMP-Mystery.
-- This source is also visible through the broad StarterPlayer client mapping,
-- so only the ReplicatedFirst instance is allowed to run.

local ReplicatedFirst = game:GetService("ReplicatedFirst")

if script.Parent ~= ReplicatedFirst then
	return
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

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
background.BackgroundColor3 = Color3.fromRGB(8, 10, 12)
background.BorderSizePixel = 0
background.Parent = screenGui

local function addAccentBar(yAnchor: number)
	local bar = Instance.new("Frame")
	bar.Name = if yAnchor == 0 then "TopAccent" else "BottomAccent"
	bar.Size = UDim2.new(1, 0, 0, 3)
	bar.AnchorPoint = Vector2.new(0, yAnchor)
	bar.Position = UDim2.fromScale(0, yAnchor)
	bar.BackgroundColor3 = Color3.fromRGB(210, 160, 50)
	bar.BorderSizePixel = 0
	bar.Parent = background
end

addAccentBar(0)
addAccentBar(1)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Text = "CAMP MYSTERY"
title.Font = Enum.Font.GothamBold
title.TextSize = 48
title.TextColor3 = Color3.fromRGB(210, 160, 50)
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.44)
title.Size = UDim2.new(1, -48, 0, 64)
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = background

local tagline = Instance.new("TextLabel")
tagline.Name = "Tagline"
tagline.Text = "Something lurks at the edge of the firelight."
tagline.Font = Enum.Font.Gotham
tagline.TextSize = 15
tagline.TextColor3 = Color3.fromRGB(180, 180, 190)
tagline.TextTransparency = 0.3
tagline.BackgroundTransparency = 1
tagline.AnchorPoint = Vector2.new(0.5, 0)
tagline.Position = UDim2.fromScale(0.5, 0.53)
tagline.Size = UDim2.new(1, -48, 0, 26)
tagline.TextXAlignment = Enum.TextXAlignment.Center
tagline.Parent = background

local loadingLabel = Instance.new("TextLabel")
loadingLabel.Name = "LoadingLabel"
loadingLabel.Text = "Loading camp"
loadingLabel.Font = Enum.Font.Gotham
loadingLabel.TextSize = 13
loadingLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
loadingLabel.BackgroundTransparency = 1
loadingLabel.AnchorPoint = Vector2.new(0.5, 0)
loadingLabel.Position = UDim2.fromScale(0.5, 0.72)
loadingLabel.Size = UDim2.fromOffset(200, 22)
loadingLabel.TextXAlignment = Enum.TextXAlignment.Center
loadingLabel.Parent = background

local dotCount = 0
local dotsRunning = true
task.spawn(function()
	while dotsRunning do
		dotCount = (dotCount % 3) + 1
		loadingLabel.Text = "Loading camp" .. string.rep(".", dotCount)
		task.wait(0.45)
	end
end)

local loadDeadline = os.clock() + 15
while not game:IsLoaded() and os.clock() < loadDeadline do
	task.wait(0.1)
end
task.wait(0.3)

dotsRunning = false
loadingLabel.Text = "Ready."

local fadeInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local fade = TweenService:Create(background, fadeInfo, { BackgroundTransparency = 1 })

for _, child in background:GetChildren() do
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
