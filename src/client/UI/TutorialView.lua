--!strict

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Components = require(script.Parent:WaitForChild("Components"))
local Theme = require(script.Parent:WaitForChild("Theme"))

export type TutorialChoice = {
	label: string,
	feedback: string?,
}

export type TutorialStep = {
	id: string,
	title: string,
	body: string,
	objective: string,
	position: number,
	total: number,
	choices: { TutorialChoice }?,
}

type TutorialViewState = {
	screenGui: ScreenGui,
	root: Frame,
	panel: Frame,
	title: TextLabel,
	body: TextLabel,
	objective: TextLabel,
	progress: TextLabel,
	choiceRow: Frame,
	choiceButtons: { TextButton },
	continueButton: TextButton,
	skipButton: TextButton,
	connections: { RBXScriptConnection },
	reducedMotion: boolean,
	animationToken: number,
	usesDimOverlay: boolean,
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
	-- The tutorial gets its own ScreenGui above the game UI (GameUI DisplayOrder
	-- is 10). Sharing a ScreenGui with the gameplay modals made paint order and
	-- input capture ambiguous: briefing steps interleaved with the campfire vote
	-- list and clicks fell through to the vote buttons underneath.
	local hostGui: Instance = parent:FindFirstAncestorOfClass("PlayerGui") or parent
	local existingGui = hostGui:FindFirstChild("TutorialUI")
	if existingGui then
		existingGui:Destroy()
	end
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TutorialUI"
	screenGui.DisplayOrder = 60
	-- Respect the topbar inset: contextual hint cards anchor near the top
	-- edge and were clipped under the Roblox chrome with IgnoreGuiInset.
	screenGui.IgnoreGuiInset = false
	screenGui.ResetOnSpawn = false
	pcall(function()
		screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end)
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = hostGui

	local root = Instance.new("Frame")
	root.Name = "ContextualTutorial"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.Colors.Black
	root.BackgroundTransparency = 0.42
	root.BorderSizePixel = 0
	root.Visible = false
	root.Active = true
	root.ZIndex = 70
	root.Parent = screenGui

	local panel = Components.Panel(root, "TutorialCard")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.82, 0, 0.88, 0)
	panel.BackgroundColor3 = Theme.Colors.Background
	panel.BackgroundTransparency = 0.02
	Components.Stroke(panel, Theme.Colors.Gold, 2)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(280, 280)
	sizeConstraint.MaxSize = Vector2.new(720, 380)
	sizeConstraint.Parent = panel

	local progress = Components.Label(panel, "Progress", "NEW CAMPER BRIEFING", 12, Enum.Font.GothamBold)
	progress.Position = UDim2.new(0, 24, 0.04, 0)
	progress.Size = UDim2.new(1, -48, 0, 24)
	progress.TextColor3 = Theme.Colors.Gold
	progress.TextXAlignment = Enum.TextXAlignment.Center

	local title = Components.Label(panel, "Title", "", 27, Enum.Font.GothamBold)
	title.Position = UDim2.new(0, 24, 0.14, 0)
	title.Size = UDim2.new(1, -48, 0, 50)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local body = Components.Label(panel, "Body", "", 16)
	body.Position = UDim2.new(0, 30, 0.29, 0)
	body.Size = UDim2.new(1, -60, 0.24, 0)
	body.TextXAlignment = Enum.TextXAlignment.Center
	body.TextYAlignment = Enum.TextYAlignment.Top

	local objective = Components.Label(panel, "Objective", "", 15, Enum.Font.GothamBold)
	objective.Position = UDim2.new(0, 30, 0.55, 0)
	objective.Size = UDim2.new(1, -60, 0.17, 0)
	objective.BackgroundColor3 = Theme.Colors.PanelSoft
	objective.BackgroundTransparency = 0.04
	objective.TextColor3 = Theme.Colors.Gold
	objective.TextXAlignment = Enum.TextXAlignment.Center
	Components.Corner(objective, Theme.SmallCornerRadius)
	Components.Stroke(objective, Theme.Colors.Border)

	local choiceRow = Instance.new("Frame")
	choiceRow.Name = "ChoiceRow"
	choiceRow.Position = UDim2.new(0, 24, 1, -118)
	choiceRow.Size = UDim2.new(1, -48, 0, 40)
	choiceRow.BackgroundTransparency = 1
	choiceRow.Visible = false
	choiceRow.Parent = panel

	local plantedButton = Components.Button(choiceRow, {
		name = "ChoicePlanted",
		text = "This looks planted",
		size = UDim2.new(0.5, -6, 1, 0),
		position = UDim2.fromOffset(0, 0),
		color = Theme.Colors.Amber,
	})
	local realButton = Components.Button(choiceRow, {
		name = "ChoiceReal",
		text = "This looks real",
		size = UDim2.new(0.5, -6, 1, 0),
		position = UDim2.new(0.5, 6, 0, 0),
		color = Theme.Colors.Success,
	})

	local continueButton = Components.Button(panel, {
		name = "Continue",
		text = "CONTINUE",
		size = UDim2.new(0.5, -34, 0, 44),
		position = UDim2.new(0.5, 10, 1, -62),
		color = Theme.Colors.Success,
	})

	local skipButton = Components.Button(panel, {
		name = "Skip",
		text = "SKIP BRIEFING",
		size = UDim2.new(0.5, -34, 0, 44),
		position = UDim2.new(0, 24, 1, -62),
		color = Theme.Colors.PanelSoft,
	})

	setZIndex(root, 70)

	local self: TutorialView = setmetatable({
		screenGui = screenGui,
		root = root,
		panel = panel,
		title = title,
		body = body,
		objective = objective,
		progress = progress,
		choiceRow = choiceRow,
		choiceButtons = { plantedButton, realButton },
		continueButton = continueButton,
		skipButton = skipButton,
		connections = {},
		reducedMotion = false,
		animationToken = 0,
		usesDimOverlay = false,
	}, TutorialView)
	return self
end

local function isModalStep(stepId: string): boolean
	-- Only role reveal and vote lock use a blocking backdrop.
	return stepId == "role" or stepId == "vote" or stepId == "vote_murderer"
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
	local briefingHeader = if string.find(step.id, "_murderer") then "MURDERER BRIEFING" else "NEW CAMPER BRIEFING"
	self.progress.Text = string.format("%s  •  %d OF %d", briefingHeader, step.position, step.total)
	self.usesDimOverlay = isModalStep(step.id)
	local choices = step.choices
	local hasChoices = type(choices) == "table" and #choices >= 2
	self.choiceRow.Visible = hasChoices
	self.root.Visible = true
	self.root.Active = self.usesDimOverlay
	if self.usesDimOverlay then
		self.panel.AnchorPoint = Vector2.new(0.5, 0.5)
		self.panel.Position = UDim2.fromScale(0.5, 0.5)
		self.panel.Size = UDim2.new(0.82, 0, 0.88, 0)
	else
		self.panel.AnchorPoint = Vector2.new(1, 0)
		self.panel.Position = UDim2.new(1, -16, 0, 86)
		self.panel.Size = UDim2.fromOffset(430, if hasChoices then 310 else 254)
	end
	-- Gamepad selection only: setting SelectedObject for mouse users draws stray
	-- selection boxes and warns "invalid GuiObject" when the button isn't ready
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = if hasChoices then self.choiceButtons[1] else self.continueButton
	end

	if hasChoices and choices then
		for index, button in self.choiceButtons do
			local choice = choices[index]
			if choice then
				button.Text = choice.label
				button.Visible = true
				local feedback = choice.feedback
				table.insert(self.connections, button.Activated:Connect(function()
					if type(feedback) == "string" and feedback ~= "" then
						self.body.Text = feedback
					end
					self.choiceRow.Visible = false
					if UserInputService.GamepadEnabled then
						GuiService.SelectedObject = self.continueButton
					end
				end))
			else
				button.Visible = false
			end
		end
	else
		for _, button in self.choiceButtons do
			button.Visible = false
		end
	end

	table.insert(self.connections, self.continueButton.Activated:Connect(onContinue))
	table.insert(self.connections, self.skipButton.Activated:Connect(onSkip))

	if self.reducedMotion then
		self.root.BackgroundTransparency = if self.usesDimOverlay then 0.42 else 1
		return
	end

	self.root.BackgroundTransparency = 1
	if self.usesDimOverlay then
		self.panel.Position = UDim2.fromScale(0.5, 0.54)
		TweenService:Create(
			self.root,
			TweenInfo.new(0.18),
			{ BackgroundTransparency = 0.42 }
		):Play()
	else
		self.panel.Position = UDim2.new(1, -16, 0, 98)
	end
	local tween = TweenService:Create(
		self.panel,
		TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = if self.usesDimOverlay then UDim2.fromScale(0.5, 0.5) else UDim2.new(1, -16, 0, 86) }
	)
	tween:Play()
end

function TutorialView:Hide()
	self:_disconnectButtons()
	self.animationToken += 1
	self.choiceRow.Visible = false
	if GuiService.SelectedObject == self.continueButton
		or GuiService.SelectedObject == self.choiceButtons[1]
		or GuiService.SelectedObject == self.choiceButtons[2]
	then
		GuiService.SelectedObject = nil
	end
	if not self.root.Parent then
		return
	end
	if self.reducedMotion then
		self.root.Visible = false
		return
	end

	local token = self.animationToken
	local tween = TweenService:Create(self.root, TweenInfo.new(0.14), { BackgroundTransparency = 1 })
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
	if self.screenGui.Parent then
		self.screenGui:Destroy()
	end
end

return TutorialView
