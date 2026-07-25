--!strict

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Components = require(script.Parent:WaitForChild("Components"))
local Theme = require(script.Parent:WaitForChild("Theme"))

export type TutorialStep = {
	id: string,
	title: string,
	body: string,
	objective: string,
	position: number,
	total: number,
}

type TutorialViewState = {
	root: Frame,
	panel: Frame,
	title: TextLabel,
	body: TextLabel,
	objective: TextLabel,
	progress: TextLabel,
	continueButton: TextButton,
	skipButton: TextButton,
	connections: { RBXScriptConnection },
	reducedMotion: boolean,
	animationToken: number,
}

local TutorialView = {}
TutorialView.__index = TutorialView

export type TutorialView = typeof(setmetatable({} :: TutorialViewState, TutorialView))

local function setZIndex(instance: Instance, zIndex: number)
	if instance:IsA("GuiObject") then
		instance.ZIndex = zIndex
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = zIndex
		end
	end
end

function TutorialView.new(parent: Instance): TutorialView
	local existing = parent:FindFirstChild("ContextualTutorial")
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Frame")
	root.Name = "ContextualTutorial"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.Colors.Black
	root.BackgroundTransparency = 0.42
	root.BorderSizePixel = 0
	root.Visible = false
	root.Active = true
	root.ZIndex = 70
	root.Parent = parent

	local panel = Components.Panel(root, "TutorialCard")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.68, 0, 0, 350)
	panel.BackgroundColor3 = Theme.Colors.Background
	panel.BackgroundTransparency = 0.02
	Components.Stroke(panel, Theme.Colors.Gold, 2)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(310, 330)
	sizeConstraint.MaxSize = Vector2.new(720, 380)
	sizeConstraint.Parent = panel

	local progress = Components.Label(panel, "Progress", "NEW CAMPER BRIEFING", 12, Enum.Font.GothamBold)
	progress.Position = UDim2.fromOffset(24, 18)
	progress.Size = UDim2.new(1, -48, 0, 24)
	progress.TextColor3 = Theme.Colors.Gold
	progress.TextXAlignment = Enum.TextXAlignment.Center

	local title = Components.Label(panel, "Title", "", 27, Enum.Font.GothamBold)
	title.Position = UDim2.fromOffset(24, 48)
	title.Size = UDim2.new(1, -48, 0, 50)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local body = Components.Label(panel, "Body", "", 16)
	body.Position = UDim2.fromOffset(30, 103)
	body.Size = UDim2.new(1, -60, 0, 92)
	body.TextXAlignment = Enum.TextXAlignment.Center
	body.TextYAlignment = Enum.TextYAlignment.Top

	local objective = Components.Label(panel, "Objective", "", 15, Enum.Font.GothamBold)
	objective.Position = UDim2.fromOffset(30, 205)
	objective.Size = UDim2.new(1, -60, 0, 54)
	objective.BackgroundColor3 = Theme.Colors.PanelSoft
	objective.BackgroundTransparency = 0.04
	objective.TextColor3 = Theme.Colors.Gold
	objective.TextXAlignment = Enum.TextXAlignment.Center
	Components.Corner(objective, Theme.SmallCornerRadius)
	Components.Stroke(objective, Theme.Colors.Border)

	local continueButton = Components.Button(panel, {
		name = "Continue",
		text = "CONTINUE",
		size = UDim2.new(0.5, -34, 0, 48),
		position = UDim2.new(0.5, 10, 1, -70),
		color = Theme.Colors.Success,
	})

	local skipButton = Components.Button(panel, {
		name = "Skip",
		text = "SKIP BRIEFING",
		size = UDim2.new(0.5, -34, 0, 48),
		position = UDim2.fromOffset(24, 280),
		color = Theme.Colors.PanelSoft,
	})

	setZIndex(root, 70)

	local self: TutorialView = setmetatable({
		root = root,
		panel = panel,
		title = title,
		body = body,
		objective = objective,
		progress = progress,
		continueButton = continueButton,
		skipButton = skipButton,
		connections = {},
		reducedMotion = false,
		animationToken = 0,
	}, TutorialView)
	return self
end

function TutorialView:_disconnectButtons()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
end

function TutorialView:SetReducedMotion(reducedMotion: boolean)
	self.reducedMotion = reducedMotion
	self.root:SetAttribute("ReducedMotion", reducedMotion)
end

function TutorialView:Show(step: TutorialStep, onContinue: () -> (), onSkip: () -> ())
	self:_disconnectButtons()
	self.animationToken += 1

	self.title.Text = string.upper(step.title)
	self.body.Text = step.body
	self.objective.Text = step.objective
	self.progress.Text = string.format("NEW CAMPER BRIEFING  •  %d OF %d", step.position, step.total)
	self.root.Visible = true
	GuiService.SelectedObject = self.continueButton

	table.insert(self.connections, self.continueButton.Activated:Connect(onContinue))
	table.insert(self.connections, self.skipButton.Activated:Connect(onSkip))

	if self.reducedMotion then
		self.root.BackgroundTransparency = 0.42
		self.panel.Position = UDim2.fromScale(0.5, 0.5)
		return
	end

	self.root.BackgroundTransparency = 1
	self.panel.Position = UDim2.fromScale(0.5, 0.54)
	TweenService:Create(
		self.root,
		TweenInfo.new(0.18),
		{ BackgroundTransparency = 0.42 }
	):Play()
	local tween = TweenService:Create(
		self.panel,
		TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.5) }
	)
	tween:Play()
end

function TutorialView:Hide()
	self:_disconnectButtons()
	self.animationToken += 1
	GuiService.SelectedObject = nil
	if not self.root.Parent then
		return
	end
	if self.reducedMotion then
		self.root.Visible = false
		return
	end

	local token = self.animationToken
	local tween = TweenService:Create(
		self.root,
		TweenInfo.new(0.14),
		{ BackgroundTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Connect(function()
		if token == self.animationToken and self.root.Parent then
			self.root.Visible = false
		end
	end)
end

function TutorialView:IsVisible(): boolean
	return self.root.Visible
end

function TutorialView:Destroy()
	self:_disconnectButtons()
	self.animationToken += 1
	if self.root.Parent then
		self.root:Destroy()
	end
end

return TutorialView
