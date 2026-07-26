--!strict

local Players = game:GetService("Players")

local function showBootFailure(message: string)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("GameUI")
	local screen: ScreenGui
	if existing and existing:IsA("ScreenGui") then
		screen = existing
	else
		if existing then
			existing:Destroy()
		end
		screen = Instance.new("ScreenGui")
		screen.Name = "GameUI"
		screen.DisplayOrder = 100
		screen.IgnoreGuiInset = false
		screen.ResetOnSpawn = false
		screen.Parent = playerGui
	end
	screen.Enabled = true

	local oldFailure = screen:FindFirstChild("CampMysteryBootFailure")
	if oldFailure then
		oldFailure:Destroy()
	end

	local panel = Instance.new("Frame")
	panel.Name = "CampMysteryBootFailure"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 18)
	panel.Size = UDim2.new(0.8, 0, 0, 112)
	panel.BackgroundColor3 = Color3.fromRGB(92, 25, 25)
	panel.BorderSizePixel = 0
	panel.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -32, 0, 30)
	title.Font = Enum.Font.GothamBold
	title.Text = "CAMP-MYSTERY COULD NOT START"
	title.TextColor3 = Color3.fromRGB(255, 238, 218)
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.fromOffset(16, 42)
	detail.Size = UDim2.new(1, -32, 0, 58)
	detail.Font = Enum.Font.Gotham
	detail.Text = "Open View > Output and send the red CAMP-Mystery error.\n" .. message
	detail.TextColor3 = Color3.fromRGB(255, 213, 191)
	detail.TextSize = 13
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	detail.TextWrapped = true
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextYAlignment = Enum.TextYAlignment.Top
	detail.Parent = panel
end

local success, failure = xpcall(function()
	local controllers = script.Parent:WaitForChild("Controllers", 10)
	assert(controllers, "Client.Controllers did not replicate")
	local roundControllerModule = controllers:WaitForChild("RoundController", 10)
	assert(roundControllerModule, "Client.Controllers.RoundController did not replicate")
	local RoundController = require(roundControllerModule)
	RoundController.Start()
end, function(message: unknown): string
	return debug.traceback(tostring(message), 2)
end)

if success then
	print("[CAMP-Mystery] Production client started")
else
	warn("[CAMP-Mystery] Production client failed:\n" .. failure)
	showBootFailure(string.sub(failure, 1, 360))
end
