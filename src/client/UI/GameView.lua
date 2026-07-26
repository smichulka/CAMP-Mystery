--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent:WaitForChild("Components"))
local Motion = require(script.Parent:WaitForChild("Motion"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local SharedConfig = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local CosmeticCatalog = require(SharedConfig:WaitForChild("CosmeticCatalog"))
local UpgradeCatalog = require(SharedConfig:WaitForChild("UpgradeCatalog"))

type ActionHandler = (action: string, payload: any) -> (boolean, string?)
type ImageResolver = (key: string) -> string?

type GameViewState = {
	screenGui: ScreenGui,
	root: Frame,
	uiScale: UIScale,
	topStatus: Frame,
	missionPanel: Frame,
	healthPanel: Frame,
	menuPanel: Frame,
	lobbyPanel: Frame?,
	notebookButton: TextButton?,
	settingsButton: TextButton?,
	actionHandler: ActionHandler,
	resolveImage: ImageResolver,
	phaseLabel: TextLabel,
	timerLabel: TextLabel,
	progressLabel: TextLabel,
	roleTitle: TextLabel,
	roleIcon: ImageLabel,
	roleDescription: TextLabel,
	roleAction: TextButton,
	objectiveText: TextLabel,
	objectiveFill: Frame,
	healthText: TextLabel,
	healthFill: Frame,
	stateBadge: TextLabel,
	hotbar: ScrollingFrame,
	notebook: Frame,
	evidenceList: ScrollingFrame,
	evidenceSummary: TextLabel,
	settings: Frame,
	settingsList: ScrollingFrame,
	voteModal: Frame,
	voteList: ScrollingFrame,
	resultModal: Frame,
	resultTitle: TextLabel,
	resultBody: TextLabel,
	rewardText: TextLabel,
	progression: Frame,
	progressionSummary: TextLabel,
	progressionList: ScrollingFrame,
	targetModal: Frame,
	targetTitle: TextLabel,
	targetList: ScrollingFrame,
	interaction: Frame,
	interactionKey: TextLabel,
	interactionText: TextLabel,
	readyButton: TextButton,
	lobbyText: TextLabel,
	announcement: Frame,
	announcementTitle: TextLabel,
	announcementBody: TextLabel,
	toastList: Frame,
	currentState: any,
	legacyRound: any,
	legacyPlayer: any,
	currentVoteSignature: string,
	selectedInventorySlot: number,
	inventoryItems: { any },
	requestSequence: number,
	settingsValues: { [string]: any },
	layoutConnections: { RBXScriptConnection },
	announcementToken: number,
	lastActionControl: GuiObject?,
	destroyed: boolean,
}

local GameView = {}
GameView.__index = GameView

export type GameView = typeof(setmetatable({} :: GameViewState, GameView))

local MONSTER_ABILITIES: { [string]: { string } } = {
	BabyAlien = { "ScuttleLeap", "AcidSwipe" },
	Screamer = { "DisruptingScream", "ClawStrike" },
	Wendigo = { "ForestCharge", "MimicMark" },
	ShadowMonster = { "ShadowStep", "LightDrain" },
	Chupacabra = { "BloodPounce", "Latch" },
	Dullahan = { "RelentlessPursuit", "FreezingTouch" },
	Entity = { "AnchorTeleport", "Distort" },
	Banshee = { "MournfulWail", "DeathMark" },
}

local MONSTER_PLAN_LOCATIONS: { [string]: string } = {
	BabyAlien = "residential-bedroom-clue",
	Screamer = "square-gas-station-clue",
	Wendigo = "outskirts-company-house-clue",
	ShadowMonster = "main-road-clue-a",
	Chupacabra = "water-tower-base-clue",
	Dullahan = "industrial-machine-clue",
	Entity = "police-evidence-room-clue",
	Banshee = "square-gas-station-clue",
}

local function readString(value: any, key: string, fallback: string): string
	if type(value) == "table" and type(value[key]) == "string" then
		return value[key]
	end
	return fallback
end

local function readNumber(value: any, key: string, fallback: number): number
	if type(value) == "table" and type(value[key]) == "number" then
		local numberValue = value[key]
		if numberValue == numberValue and math.abs(numberValue) < math.huge then
			return numberValue
		end
	end
	return fallback
end

local function readBoolean(value: any, key: string, fallback: boolean): boolean
	if type(value) == "table" and type(value[key]) == "boolean" then
		return value[key]
	end
	return fallback
end

local function asTable(value: any): { any }
	if type(value) == "table" then
		return value
	end
	return {}
end

local function joinCandidateNames(value: any, namesById: { [string]: string }): string
	local pieces: { string } = {}
	for _, item in asTable(value) do
		if type(item) == "string" then
			table.insert(pieces, namesById[item] or item)
		end
	end
	return if #pieces > 0 then table.concat(pieces, ", ") else "Further analysis required"
end

local function imageKey(prefix: string, identifier: string): string
	return prefix .. "_" .. string.gsub(identifier, "[^%w_%-]", "")
end

local function optionalImage(
	parent: Instance,
	name: string,
	image: string?,
	position: UDim2,
	size: UDim2
): ImageLabel?
	if not image then
		return nil
	end
	local icon = Instance.new("ImageLabel")
	icon.Name = name
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Image = image
	icon.Position = position
	icon.Size = size
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = parent
	return icon
end

local function findFocusable(modal: GuiObject): GuiButton?
	local closeButton: GuiButton? = nil
	for _, descendant in modal:GetDescendants() do
		if descendant:IsA("GuiButton")
			and descendant.Visible
			and descendant.Active
			and descendant.Selectable
		then
			if descendant.Name ~= "Close" then
				return descendant
			end
			closeButton = descendant
		end
	end
	return closeButton
end

local function setModalVisible(modal: GuiObject, visible: boolean)
	local requestedVisible = modal:GetAttribute("MotionTargetVisible")
	if requestedVisible == visible then
		return
	end
	modal:SetAttribute("MotionTargetVisible", visible)
	local selected = GuiService.SelectedObject
	if visible then
		modal.Visible = true
		Components.PlayUISound("open")
		Motion.PopIn(modal, {
			onComplete = function(completed: boolean)
				if completed
					and modal.Parent
					and modal:GetAttribute("MotionTargetVisible") == true
				then
					GuiService.SelectedObject = findFocusable(modal)
				end
			end,
		})
		local staggerTarget: GuiObject? = nil
		if modal.Name == "EvidenceNotebook" then
			local evidenceList = modal:FindFirstChild("EvidenceList")
			if evidenceList and evidenceList:IsA("GuiObject") then
				staggerTarget = evidenceList
			end
		elseif modal.Name == "CampfireVote" then
			local voteList = modal:FindFirstChild("Suspects")
			if voteList and voteList:IsA("GuiObject") then
				staggerTarget = voteList
			end
		end
		if staggerTarget then
			local list = staggerTarget
			task.defer(function()
				if modal:GetAttribute("MotionTargetVisible") == true then
					Motion.StaggerChildren(list, {
						preset = "SlideUp",
					})
				end
			end)
		end
	elseif selected and selected:IsDescendantOf(modal) then
		GuiService.SelectedObject = nil
		Components.PlayUISound("close")
		Motion.PopOut(modal, {
			onComplete = function(completed: boolean)
				if completed
					and modal.Parent
					and modal:GetAttribute("MotionTargetVisible") == false
				then
					modal.Visible = false
				end
			end,
		})
	elseif modal.Visible then
		Components.PlayUISound("close")
		Motion.PopOut(modal, {
			onComplete = function(completed: boolean)
				if completed
					and modal.Parent
					and modal:GetAttribute("MotionTargetVisible") == false
				then
					modal.Visible = false
				end
			end,
		})
	end
end

local function modalTargetVisible(modal: GuiObject): boolean
	return modal:GetAttribute("MotionTargetVisible") == true
end

local function makeHeader(parent: Instance, title: string, closeCallback: () -> ())
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 58)
	header.BackgroundTransparency = 1
	header.Parent = parent

	local label = Components.Label(header, "Title", title, 24, Enum.Font.GothamBold)
	label.Position = UDim2.fromOffset(20, 0)
	label.Size = UDim2.new(1, -112, 1, 0)

	local close = Components.Button(header, {
		name = "Close",
		text = "CLOSE",
		size = UDim2.fromOffset(76, 42),
		position = UDim2.new(1, -88, 0, 8),
		color = Theme.Colors.Danger,
	})
	close.Activated:Connect(closeCallback)
end

local function makeModal(parent: Instance, name: string, size: UDim2): Frame
	local shade = Instance.new("Frame")
	shade.Name = name
	shade.AnchorPoint = Vector2.new(0.5, 0.5)
	shade.Position = UDim2.fromScale(0.5, 0.5)
	shade.Size = size
	shade.BackgroundColor3 = Theme.Colors.Background
	shade.BackgroundTransparency = 0.03
	shade.BorderSizePixel = 0
	shade.Visible = false
	shade:SetAttribute("MotionTargetVisible", false)
	shade.ZIndex = 20
	shade.Parent = parent
	Components.Corner(shade, 14)
	Components.Stroke(shade, Theme.Colors.Gold, 2)

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(280, 260)
	constraint.MaxSize = Vector2.new(920, 620)
	constraint.Parent = shade
	return shade
end

local function addCanvasSizing(scroll: ScrollingFrame, layout: UIListLayout)
	local function update()
		scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 16)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
	update()
end

local function makeMenuButton(
	parent: Instance,
	name: string,
	text: string,
	position: UDim2,
	callback: () -> ()
): TextButton
	local button = Components.Button(parent, {
		name = name,
		text = text,
		size = UDim2.fromOffset(130, 40),
		position = position,
	})
	button.Activated:Connect(callback)
	return button
end

function GameView.new(actionHandler: ActionHandler, imageResolver: ImageResolver?): GameView
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existingScreen = playerGui:FindFirstChild("GameUI")
	if existingScreen and not existingScreen:IsA("ScreenGui") then
		existingScreen:Destroy()
		existingScreen = nil
	end
	local screen: ScreenGui
	if existingScreen then
		screen = existingScreen :: ScreenGui
	else
		screen = Instance.new("ScreenGui")
		screen.Name = "GameUI"
		screen.Parent = playerGui
	end
	screen.DisplayOrder = 10
	screen.Enabled = true
	screen.IgnoreGuiInset = false
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)

	local previous = screen:FindFirstChild("CampMysteryHUD")
	if previous then
		previous:Destroy()
	end
	local oldHud = screen:FindFirstChild("RoundHUD")
	if oldHud then
		oldHud:Destroy()
	end

	local root = Instance.new("Frame")
	root.Name = "CampMysteryHUD"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = screen

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root

	local top = Components.Panel(root, "TopStatus")
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.fromScale(0.5, 0.018)
	top.Size = UDim2.fromOffset(540, 96)

	local phaseLabel = Components.Label(top, "Phase", "WAITING AT CAMP", 22, Enum.Font.GothamBold)
	phaseLabel.Position = UDim2.fromOffset(18, 10)
	phaseLabel.Size = UDim2.new(1, -106, 0, 32)
	phaseLabel.TextXAlignment = Enum.TextXAlignment.Center
	local timerLabel = Components.Label(top, "Timer", "--:--", 19, Enum.Font.GothamBold)
	timerLabel.Position = UDim2.new(1, -88, 0, 10)
	timerLabel.Size = UDim2.fromOffset(72, 32)
	timerLabel.TextColor3 = Theme.Colors.Gold
	timerLabel.TextXAlignment = Enum.TextXAlignment.Center
	local progressLabel = Components.Label(top, "Progress", "The camp is getting ready.", 14)
	progressLabel.Position = UDim2.fromOffset(18, 47)
	progressLabel.Size = UDim2.new(1, -36, 0, 38)
	progressLabel.TextXAlignment = Enum.TextXAlignment.Center

	local mission = Components.Panel(root, "Mission")
	mission.Position = UDim2.fromOffset(18, 18)
	mission.Size = UDim2.fromOffset(310, 310)
	local roleTitle = Components.Label(mission, "RoleTitle", "ROLE PENDING", 21, Enum.Font.GothamBold)
	roleTitle.Position = UDim2.fromOffset(16, 12)
	roleTitle.Size = UDim2.new(1, -32, 0, 34)
	roleTitle.TextColor3 = Theme.Colors.Gold
	local roleIcon = Instance.new("ImageLabel")
	roleIcon.Name = "RoleIcon"
	roleIcon.BackgroundTransparency = 1
	roleIcon.BorderSizePixel = 0
	roleIcon.Position = UDim2.fromOffset(16, 10)
	roleIcon.Size = UDim2.fromOffset(36, 36)
	roleIcon.ScaleType = Enum.ScaleType.Fit
	roleIcon.Visible = false
	roleIcon.Parent = mission
	local stateBadge = Components.Label(mission, "StateBadge", "WAITING", 12, Enum.Font.GothamBold)
	stateBadge.AnchorPoint = Vector2.new(1, 0)
	stateBadge.Position = UDim2.new(1, -14, 0, 16)
	stateBadge.Size = UDim2.fromOffset(90, 26)
	stateBadge.TextXAlignment = Enum.TextXAlignment.Center
	stateBadge.BackgroundColor3 = Theme.Colors.PanelSoft
	stateBadge.BackgroundTransparency = 0
	Components.Corner(stateBadge, 13)
	local roleDescription = Components.Label(mission, "RoleDescription", "Waiting for your private role.", 14)
	roleDescription.Position = UDim2.fromOffset(16, 52)
	roleDescription.Size = UDim2.new(1, -32, 0, 68)
	roleDescription.TextYAlignment = Enum.TextYAlignment.Top
	local separator = Instance.new("Frame")
	separator.Position = UDim2.fromOffset(16, 126)
	separator.Size = UDim2.new(1, -32, 0, 1)
	separator.BackgroundColor3 = Theme.Colors.Border
	separator.BorderSizePixel = 0
	separator.Parent = mission
	local objectiveText = Components.Label(mission, "Objective", "OBJECTIVE\nWaiting for briefing...", 14)
	objectiveText.Position = UDim2.fromOffset(16, 138)
	objectiveText.Size = UDim2.new(1, -32, 0, 70)
	objectiveText.TextYAlignment = Enum.TextYAlignment.Top
	local objectiveTrack, objectiveFill = Components.ProgressBar(mission, "ObjectiveProgress")
	objectiveTrack.Position = UDim2.fromOffset(16, 214)
	objectiveTrack.Size = UDim2.new(1, -32, 0, 16)
	local roleAction = Components.Button(mission, {
		name = "RoleAction",
		text = "USE ROLE ABILITY",
		size = UDim2.new(1, -32, 0, 46),
		position = UDim2.fromOffset(16, 248),
		color = Theme.Colors.Info,
	})
	Components.SetButtonEnabled(roleAction, false)

	local healthPanel = Components.Panel(root, "Health")
	healthPanel.AnchorPoint = Vector2.new(0, 1)
	healthPanel.Position = UDim2.new(0, 18, 1, -18)
	healthPanel.Size = UDim2.fromOffset(270, 66)
	local healthText = Components.Label(healthPanel, "HealthText", "HEALTH  --", 13, Enum.Font.GothamBold)
	healthText.Position = UDim2.fromOffset(12, 5)
	healthText.Size = UDim2.new(1, -24, 0, 26)
	local healthTrack, healthFill = Components.ProgressBar(healthPanel, "HealthBar")
	healthTrack.Position = UDim2.fromOffset(12, 36)
	healthTrack.Size = UDim2.new(1, -24, 0, 18)

	local hotbar = Instance.new("ScrollingFrame")
	hotbar.Name = "Hotbar"
	hotbar.AnchorPoint = Vector2.new(0.5, 1)
	hotbar.Position = UDim2.new(0.5, 0, 1, -18)
	hotbar.Size = UDim2.new(0.52, 0, 0, 80)
	hotbar.BackgroundTransparency = 1
	hotbar.BorderSizePixel = 0
	hotbar.CanvasSize = UDim2.fromOffset(0, 0)
	hotbar.AutomaticCanvasSize = Enum.AutomaticSize.X
	hotbar.ScrollingDirection = Enum.ScrollingDirection.X
	hotbar.ScrollBarThickness = 3
	hotbar.Parent = root
	local hotbarLayout = Instance.new("UIListLayout")
	hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
	hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hotbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hotbarLayout.Padding = UDim.new(0, 7)
	hotbarLayout.Parent = hotbar

	local menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.AnchorPoint = Vector2.new(1, 0)
	menu.Position = UDim2.new(1, -18, 0, 18)
	menu.Size = UDim2.fromOffset(140, 94)
	menu.BackgroundTransparency = 1
	menu.Parent = root

	local interaction = Components.Panel(root, "Interaction")
	interaction.AnchorPoint = Vector2.new(0.5, 1)
	interaction.Position = UDim2.new(0.5, 0, 1, -112)
	interaction.Size = UDim2.fromOffset(390, 60)
	interaction.Visible = false
	local interactionKey = Components.Label(interaction, "Key", "E", 18, Enum.Font.GothamBold)
	interactionKey.Position = UDim2.fromOffset(10, 10)
	interactionKey.Size = UDim2.fromOffset(40, 40)
	interactionKey.BackgroundColor3 = Theme.Colors.Gold
	interactionKey.BackgroundTransparency = 0
	interactionKey.TextColor3 = Theme.Colors.Background
	interactionKey.TextXAlignment = Enum.TextXAlignment.Center
	Components.Corner(interactionKey, Theme.SmallCornerRadius)
	local interactionText = Components.Label(interaction, "Text", "", 15, Enum.Font.GothamBold)
	interactionText.Position = UDim2.fromOffset(62, 7)
	interactionText.Size = UDim2.new(1, -72, 1, -14)

	local notebook = makeModal(root, "EvidenceNotebook", UDim2.new(0.72, 0, 0.72, 0))
	local settings = makeModal(root, "Settings", UDim2.new(0.58, 0, 0.76, 0))
	local voteModal = makeModal(root, "CampfireVote", UDim2.new(0.46, 0, 0.64, 0))
	local resultModal = makeModal(root, "RoundResults", UDim2.new(0.52, 0, 0.5, 0))
	local targetModal = makeModal(root, "ActionTarget", UDim2.new(0.4, 0, 0.62, 0))
	local progression = makeModal(root, "Progression", UDim2.new(0.72, 0, 0.78, 0))

	local self: GameView = setmetatable({
		screenGui = screen,
		root = root,
		uiScale = uiScale,
		topStatus = top,
		missionPanel = mission,
		healthPanel = healthPanel,
		menuPanel = menu,
		lobbyPanel = nil,
		notebookButton = nil,
		settingsButton = nil,
		actionHandler = actionHandler,
		resolveImage = imageResolver or function(_key: string): string?
			return nil
		end,
		phaseLabel = phaseLabel,
		timerLabel = timerLabel,
		progressLabel = progressLabel,
		roleTitle = roleTitle,
		roleIcon = roleIcon,
		roleDescription = roleDescription,
		roleAction = roleAction,
		objectiveText = objectiveText,
		objectiveFill = objectiveFill,
		healthText = healthText,
		healthFill = healthFill,
		stateBadge = stateBadge,
		hotbar = hotbar,
		notebook = notebook,
		evidenceList = nil :: any,
		evidenceSummary = nil :: any,
		settings = settings,
		settingsList = nil :: any,
		voteModal = voteModal,
		voteList = nil :: any,
		resultModal = resultModal,
		resultTitle = nil :: any,
		resultBody = nil :: any,
		rewardText = nil :: any,
		progression = progression,
		progressionSummary = nil :: any,
		progressionList = nil :: any,
		targetModal = targetModal,
		targetTitle = nil :: any,
		targetList = nil :: any,
		interaction = interaction,
		interactionKey = interactionKey,
		interactionText = interactionText,
		readyButton = nil :: any,
		lobbyText = nil :: any,
		announcement = nil :: any,
		announcementTitle = nil :: any,
		announcementBody = nil :: any,
		toastList = nil :: any,
		currentState = nil,
		legacyRound = nil,
		legacyPlayer = nil,
		currentVoteSignature = "",
		selectedInventorySlot = 0,
		inventoryItems = {},
		requestSequence = 0,
		settingsValues = {},
		layoutConnections = {},
		announcementToken = 0,
		lastActionControl = nil,
		destroyed = false,
	}, GameView)

	self:_buildNotebook()
	self:_buildSettings()
	self:_buildVote()
	self:_buildResults()
	self:_buildTargetSelector()
	self:_buildProgression()
	self:_buildAnnouncements()
	self:_buildLobby()

	self.notebookButton = makeMenuButton(menu, "NotebookButton", "CLUES  [N]", UDim2.fromOffset(10, 0), function()
		self:ToggleNotebook()
	end)
	self.settingsButton = makeMenuButton(menu, "SettingsButton", "SETTINGS", UDim2.fromOffset(10, 48), function()
		self:ToggleSettings()
	end)
	roleAction.Activated:Connect(function()
		self:_requestRoleAction()
	end)

	local viewportConnection: RBXScriptConnection? = nil
	local function bindCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		local currentCamera = Workspace.CurrentCamera
		if currentCamera then
			viewportConnection = currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self:_updateLayout()
			end)
			table.insert(self.layoutConnections, viewportConnection :: RBXScriptConnection)
		end
		self:_updateLayout()
	end
	table.insert(
		self.layoutConnections,
		Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	)
	bindCamera()

	return self
end

function GameView:_updateLayout()
	if self.destroyed then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local narrow = viewport.X < 560
	local compact = not narrow and (viewport.X < 850 or viewport.Y < 560)
	self.uiScale.Scale = 1

	if narrow then
		self.topStatus.AnchorPoint = Vector2.new(0.5, 0)
		self.topStatus.Position = UDim2.new(0.5, 0, 0, 8)
		self.topStatus.Size = UDim2.new(1, -16, 0, 80)

		self.menuPanel.AnchorPoint = Vector2.new(0.5, 0)
		self.menuPanel.Position = UDim2.new(0.5, 0, 0, 94)
		self.menuPanel.Size = UDim2.fromOffset(280, 42)
		if self.notebookButton then
			self.notebookButton.Position = UDim2.fromOffset(6, 0)
		end
		if self.settingsButton then
			self.settingsButton.Position = UDim2.fromOffset(144, 0)
		end

		self.missionPanel.Position = UDim2.fromOffset(8, 142)
		self.missionPanel.Size = UDim2.new(1, -16, 0, 310)
		self.healthPanel.Position = UDim2.new(0, 8, 1, -92)
		self.healthPanel.Size = UDim2.new(1, -16, 0, 66)
		self.hotbar.AnchorPoint = Vector2.new(0.5, 1)
		self.hotbar.Position = UDim2.new(0.5, 0, 1, -8)
		self.hotbar.Size = UDim2.new(1, -16, 0, 76)
		self.interaction.Position = UDim2.new(0.5, 0, 1, -166)
		self.interaction.Size = UDim2.new(1, -20, 0, 60)
		self.toastList.Position = UDim2.new(1, -8, 1, -170)
		self.toastList.Size = UDim2.new(1, -16, 0, 210)
		self.announcement.Size = UDim2.new(1, -16, 0, 82)
		if self.lobbyPanel then
			self.lobbyPanel.AnchorPoint = Vector2.new(0.5, 1)
			self.lobbyPanel.Position = UDim2.new(0.5, 0, 1, -8)
			self.lobbyPanel.Size = UDim2.new(1, -16, 0, 104)
		end
	elseif compact then
		self.topStatus.AnchorPoint = Vector2.new(1, 0)
		self.topStatus.Position = UDim2.new(1, -10, 0, 10)
		self.topStatus.Size = UDim2.new(1, -310, 0, 96)

		self.menuPanel.AnchorPoint = Vector2.new(1, 0)
		self.menuPanel.Position = UDim2.new(1, -10, 0, 114)
		self.menuPanel.Size = UDim2.fromOffset(140, 94)
		if self.notebookButton then
			self.notebookButton.Position = UDim2.fromOffset(10, 0)
		end
		if self.settingsButton then
			self.settingsButton.Position = UDim2.fromOffset(10, 48)
		end

		self.missionPanel.Position = UDim2.fromOffset(10, 10)
		self.missionPanel.Size = UDim2.fromOffset(280, 310)
		self.healthPanel.Position = UDim2.new(0, 10, 1, -10)
		self.healthPanel.Size = UDim2.fromOffset(220, 66)
		self.hotbar.Position = UDim2.new(1, -10, 1, -10)
		self.hotbar.AnchorPoint = Vector2.new(1, 1)
		self.hotbar.Size = UDim2.new(1, -250, 0, 80)
		self.interaction.Position = UDim2.new(0.5, 0, 1, -100)
		self.interaction.Size = UDim2.new(0.55, 0, 0, 60)
		self.toastList.Position = UDim2.new(1, -10, 1, -100)
		self.toastList.Size = UDim2.fromOffset(math.min(320, viewport.X - 20), 220)
		self.announcement.Size = UDim2.new(1, -310, 0, 82)
		if self.lobbyPanel then
			self.lobbyPanel.AnchorPoint = Vector2.new(1, 1)
			self.lobbyPanel.Position = UDim2.new(1, -10, 1, -10)
			self.lobbyPanel.Size = UDim2.fromOffset(300, 104)
		end
	else
		self.topStatus.AnchorPoint = Vector2.new(0.5, 0)
		self.topStatus.Position = UDim2.fromScale(0.5, 0.018)
		self.topStatus.Size = UDim2.fromOffset(540, 96)
		self.menuPanel.AnchorPoint = Vector2.new(1, 0)
		self.menuPanel.Position = UDim2.new(1, -18, 0, 18)
		self.menuPanel.Size = UDim2.fromOffset(140, 94)
		if self.notebookButton then
			self.notebookButton.Position = UDim2.fromOffset(10, 0)
		end
		if self.settingsButton then
			self.settingsButton.Position = UDim2.fromOffset(10, 48)
		end
		self.missionPanel.Position = UDim2.fromOffset(18, 18)
		self.missionPanel.Size = UDim2.fromOffset(310, 310)
		self.healthPanel.Position = UDim2.new(0, 18, 1, -18)
		self.healthPanel.Size = UDim2.fromOffset(270, 66)
		self.hotbar.AnchorPoint = Vector2.new(0.5, 1)
		self.hotbar.Position = UDim2.new(0.5, 0, 1, -18)
		self.hotbar.Size = UDim2.new(0.52, 0, 0, 80)
		self.interaction.Position = UDim2.new(0.5, 0, 1, -112)
		self.interaction.Size = UDim2.fromOffset(390, 60)
		self.toastList.Position = UDim2.new(1, -18, 1, -122)
		self.toastList.Size = UDim2.fromOffset(360, 250)
		self.announcement.Size = UDim2.fromOffset(520, 82)
		if self.lobbyPanel then
			self.lobbyPanel.AnchorPoint = Vector2.new(1, 1)
			self.lobbyPanel.Position = UDim2.new(1, -18, 1, -18)
			self.lobbyPanel.Size = UDim2.fromOffset(300, 104)
		end
	end

	if narrow then
		for _, modal in {
			self.notebook,
			self.settings,
			self.voteModal,
			self.resultModal,
			self.targetModal,
			self.progression,
		} do
			modal.Size = UDim2.new(1, -16, 1, -24)
		end
		local resultContinue = self.resultModal:FindFirstChild("Continue")
		local resultProgression = self.resultModal:FindFirstChild("Progression")
		if resultContinue and resultContinue:IsA("GuiObject") then
			resultContinue.Size = UDim2.new(0.5, -18, 0, 44)
			resultContinue.Position = UDim2.new(0.5, 6, 1, -64)
		end
		if resultProgression and resultProgression:IsA("GuiObject") then
			resultProgression.Size = UDim2.new(0.5, -18, 0, 44)
			resultProgression.Position = UDim2.new(0, 12, 1, -64)
		end
	else
		self.notebook.Size = UDim2.new(0.72, 0, 0.72, 0)
		self.settings.Size = UDim2.new(0.58, 0, 0.76, 0)
		self.voteModal.Size = UDim2.new(0.46, 0, 0.64, 0)
		self.resultModal.Size = UDim2.new(0.52, 0, 0.5, 0)
		self.targetModal.Size = UDim2.new(0.4, 0, 0.62, 0)
		self.progression.Size = UDim2.new(0.72, 0, 0.78, 0)
		local resultContinue = self.resultModal:FindFirstChild("Continue")
		local resultProgression = self.resultModal:FindFirstChild("Progression")
		if resultContinue and resultContinue:IsA("GuiObject") then
			resultContinue.Size = UDim2.fromOffset(170, 44)
			resultContinue.Position = UDim2.new(0.5, 8, 1, -64)
		end
		if resultProgression and resultProgression:IsA("GuiObject") then
			resultProgression.Size = UDim2.fromOffset(170, 44)
			resultProgression.Position = UDim2.new(0.5, -178, 1, -64)
		end
	end
end

function GameView:_buildNotebook()
	makeHeader(self.notebook, "EVIDENCE NOTEBOOK", function()
		setModalVisible(self.notebook, false)
	end)
	local summary = Components.Label(
		self.notebook,
		"Summary",
		"Clues are separated from monster identification evidence.",
		14
	)
	summary.Position = UDim2.fromOffset(20, 58)
	summary.Size = UDim2.new(1, -40, 0, 48)
	summary.TextColor3 = Theme.Colors.TextMuted
	self.evidenceSummary = summary

	local list = Instance.new("ScrollingFrame")
	list.Name = "EvidenceList"
	list.Position = UDim2.fromOffset(18, 108)
	list.Size = UDim2.new(1, -36, 1, -126)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = self.notebook
	local layout = Components.List(list, 9)
	addCanvasSizing(list, layout)
	self.evidenceList = list
end

function GameView:_buildSettings()
	makeHeader(self.settings, "SETTINGS & ACCESSIBILITY", function()
		setModalVisible(self.settings, false)
	end)
	local list = Instance.new("ScrollingFrame")
	list.Name = "SettingsList"
	list.Position = UDim2.fromOffset(18, 64)
	list.Size = UDim2.new(1, -36, 1, -82)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = self.settings
	local layout = Components.List(list, 8)
	addCanvasSizing(list, layout)
	self.settingsList = list
	self:_rebuildSettings()
end

function GameView:_buildVote()
	makeHeader(self.voteModal, "CAMPFIRE ACCUSATION", function()
		self:Notify("Vote required", "Choose one suspect before the fire goes out.", "Warning")
	end)
	local warning = Components.Label(
		self.voteModal,
		"Warning",
		"One vote. No take-backs. A tie favors the Murderer.",
		14
	)
	warning.Position = UDim2.fromOffset(20, 58)
	warning.Size = UDim2.new(1, -40, 0, 44)
	warning.TextColor3 = Theme.Colors.Amber
	warning.TextXAlignment = Enum.TextXAlignment.Center
	local list = Instance.new("ScrollingFrame")
	list.Name = "Suspects"
	list.Position = UDim2.fromOffset(18, 106)
	list.Size = UDim2.new(1, -36, 1, -124)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = self.voteModal
	local layout = Components.List(list, 8)
	addCanvasSizing(list, layout)
	self.voteList = list
end

function GameView:_buildResults()
	local title = Components.Label(self.resultModal, "Title", "MYSTERY RESOLVED", 28, Enum.Font.GothamBold)
	title.Position = UDim2.fromOffset(24, 26)
	title.Size = UDim2.new(1, -48, 0, 48)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextColor3 = Theme.Colors.Gold
	local body = Components.Label(self.resultModal, "Body", "", 17)
	body.Position = UDim2.fromOffset(28, 88)
	body.Size = UDim2.new(1, -56, 0, 92)
	body.TextXAlignment = Enum.TextXAlignment.Center
	local rewards = Components.Label(self.resultModal, "Rewards", "", 15, Enum.Font.GothamBold)
	rewards.Position = UDim2.fromOffset(28, 184)
	rewards.Size = UDim2.new(1, -56, 0, 58)
	rewards.TextColor3 = Theme.Colors.Success
	rewards.TextXAlignment = Enum.TextXAlignment.Center
	local continue = Components.Button(self.resultModal, {
		name = "Continue",
		text = "CONTINUE",
		size = UDim2.fromOffset(170, 44),
		position = UDim2.new(0.5, 8, 1, -64),
		color = Theme.Colors.Info,
	})
	continue.Activated:Connect(function()
		setModalVisible(self.resultModal, false)
	end)
	local progression = Components.Button(self.resultModal, {
		name = "Progression",
		text = "PROGRESSION",
		size = UDim2.fromOffset(170, 44),
		position = UDim2.new(0.5, -178, 1, -64),
		color = Theme.Colors.Gold,
	})
	progression.TextColor3 = Theme.Colors.Background
	progression.Activated:Connect(function()
		setModalVisible(self.resultModal, false)
		self:ToggleProgression()
	end)
	self.resultTitle = title
	self.resultBody = body
	self.rewardText = rewards
end

function GameView:_buildProgression()
	makeHeader(self.progression, "CAMP PROGRESSION", function()
		setModalVisible(self.progression, false)
	end)
	local summary = Components.Label(
		self.progression,
		"Summary",
		"Profile data is loading...",
		15,
		Enum.Font.GothamBold
	)
	summary.Position = UDim2.fromOffset(20, 58)
	summary.Size = UDim2.new(1, -40, 0, 50)
	summary.TextColor3 = Theme.Colors.Gold
	summary.TextXAlignment = Enum.TextXAlignment.Center
	self.progressionSummary = summary

	local list = Instance.new("ScrollingFrame")
	list.Name = "ProgressionList"
	list.Position = UDim2.fromOffset(18, 112)
	list.Size = UDim2.new(1, -36, 1, -130)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = self.progression
	local layout = Components.List(list, 9)
	addCanvasSizing(list, layout)
	self.progressionList = list
end

function GameView:_progressionCard(
	titleText: string,
	descriptionText: string,
	statusText: string,
	buttonText: string,
	buttonEnabled: boolean,
	callback: (control: TextButton) -> ()
)
	local card = Components.Panel(self.progressionList, "ProgressionCard")
	card:SetAttribute("Generated", true)
	card.Size = UDim2.new(1, -8, 0, 116)
	local title = Components.Label(card, "Title", titleText, 16, Enum.Font.GothamBold)
	title.Position = UDim2.fromOffset(12, 7)
	title.Size = UDim2.new(1, -174, 0, 28)
	title.TextColor3 = Theme.Colors.Gold
	local description = Components.Label(card, "Description", descriptionText, 12)
	description.Position = UDim2.fromOffset(12, 37)
	description.Size = UDim2.new(1, -174, 0, 54)
	description.TextColor3 = Theme.Colors.TextMuted
	description.TextYAlignment = Enum.TextYAlignment.Top
	local status = Components.Label(card, "Status", statusText, 12, Enum.Font.GothamBold)
	status.Position = UDim2.fromOffset(12, 92)
	status.Size = UDim2.new(1, -174, 0, 18)
	local button = Components.Button(card, {
		name = "Action",
		text = buttonText,
		size = UDim2.fromOffset(148, 42),
		position = UDim2.new(1, -160, 0.5, -21),
		color = Theme.Colors.Info,
	})
	Components.SetButtonEnabled(button, buttonEnabled)
	button.Activated:Connect(function()
		callback(button)
	end)
end

function GameView:_updateProgression(state: any)
	Components.ClearGenerated(self.progressionList)
	local profileSnapshot = if type(state) == "table" then state.profile else nil
	local profile = if type(profileSnapshot) == "table" then profileSnapshot.profile else nil
	if type(profile) ~= "table" then
		self.progressionSummary.Text = "Profile unavailable - progression actions are temporarily locked."
		return
	end
	local totalXP = readNumber(profile, "totalXP", 0)
	local tokens = readNumber(profile, "campTokens", 0)
	self.progressionSummary.Text = string.format(
		"TOTAL XP  %d     CAMP TOKENS  %d\nEverything here is earned by playing.",
		totalXP,
		tokens
	)
	local upgrades = if type(profile.upgrades) == "table" then profile.upgrades else {}
	local mastery = if type(profile.roleMastery) == "table" then profile.roleMastery else {}
	local buyEnabled = self:_available(state, "BuyUpgrade")

	local upgradeHeader = Components.Label(
		self.progressionList,
		"UpgradeHeader",
		"ROLE UPGRADES",
		18,
		Enum.Font.GothamBold
	)
	upgradeHeader:SetAttribute("Generated", true)
	upgradeHeader.Size = UDim2.new(1, -8, 0, 38)
	upgradeHeader.TextColor3 = Theme.Colors.Gold

	for _, definition in UpgradeCatalog.definitions do
		local roleUpgrades = if type(upgrades[definition.roleId]) == "table"
			then upgrades[definition.roleId]
			else {}
		local currentRank = math.floor(readNumber(roleUpgrades, definition.id, 0))
		local masteryEntry = if type(mastery[definition.roleId]) == "table"
			then mastery[definition.roleId]
			else nil
		local masteryLevel = readNumber(masteryEntry, "level", 1)
		local capped = currentRank >= definition.maxRank
		local cost = if capped then 0 else UpgradeCatalog.nextRankCost(definition, currentRank)
		local eligible = buyEnabled
			and not capped
			and masteryLevel >= definition.requiredMasteryLevel
			and tokens >= cost
		local statusText = string.format(
			"%s mastery %d  |  Rank %d/%d%s",
			definition.roleId,
			masteryLevel,
			currentRank,
			definition.maxRank,
			if capped then "  |  MAXIMUM" else "  |  " .. tostring(cost) .. " tokens"
		)
		self:_progressionCard(
			definition.displayName,
			definition.description,
			statusText,
			if capped then "MAX RANK" else "BUY RANK " .. tostring(currentRank + 1),
			eligible,
			function(control: TextButton)
				self:_send("BuyUpgrade", {
					roleId = definition.roleId,
					upgradeId = definition.id,
				}, control)
			end
		)
	end

	local cosmeticHeader = Components.Label(
		self.progressionList,
		"CosmeticHeader",
		"COSMETICS",
		18,
		Enum.Font.GothamBold
	)
	cosmeticHeader:SetAttribute("Generated", true)
	cosmeticHeader.Size = UDim2.new(1, -8, 0, 38)
	cosmeticHeader.TextColor3 = Theme.Colors.Gold

	local owned = if type(profile.ownedCosmetics) == "table" then profile.ownedCosmetics else {}
	local equipped = if type(profile.equippedCosmetics) == "table" then profile.equippedCosmetics else {}
	local equipEnabled = self:_available(state, "EquipCosmetic")
	local unlockEnabled = self:_available(state, "UnlockCosmetic")
	for _, definition in CosmeticCatalog.definitions do
		local isOwned = owned[definition.id] == true
		local isEquipped = equipped[definition.category] == definition.id
		local canUnlock = not isOwned
			and definition.unlockKind == "CampTokens"
			and tokens >= definition.unlockAmount
			and unlockEnabled
		local buttonText = if isEquipped
			then "EQUIPPED"
			elseif isOwned then "EQUIP"
			elseif definition.unlockKind == "CampTokens"
				then "UNLOCK " .. tostring(definition.unlockAmount)
			else "LOCKED"
		local statusText = definition.category .. "  |  "
			.. (if isEquipped
				then "Equipped"
				elseif isOwned then "Owned"
				elseif definition.unlockKind == "Level"
					then "Requires level " .. tostring(definition.unlockAmount)
				else tostring(definition.unlockAmount) .. " tokens")
		self:_progressionCard(
			definition.displayName,
			"Earned cosmetic - no Robux purchase required.",
			statusText,
			buttonText,
			(isOwned and not isEquipped and equipEnabled) or canUnlock,
			function(control: TextButton)
				if isOwned then
					self:_send("EquipCosmetic", { cosmeticId = definition.id }, control)
				elseif definition.unlockKind == "CampTokens" then
					self:_send("UnlockCosmetic", { cosmeticId = definition.id }, control)
				end
			end
		)
	end
end

function GameView:_buildTargetSelector()
	makeHeader(self.targetModal, "CHOOSE A TARGET", function()
		setModalVisible(self.targetModal, false)
	end)
	local title = Components.Label(
		self.targetModal,
		"Instruction",
		"Select the participant or clue affected by this action.",
		14
	)
	title.Position = UDim2.fromOffset(20, 58)
	title.Size = UDim2.new(1, -40, 0, 44)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextColor3 = Theme.Colors.TextMuted
	local list = Instance.new("ScrollingFrame")
	list.Name = "Targets"
	list.Position = UDim2.fromOffset(18, 108)
	list.Size = UDim2.new(1, -36, 1, -126)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = self.targetModal
	local layout = Components.List(list, 8)
	addCanvasSizing(list, layout)
	self.targetTitle = title
	self.targetList = list
end

function GameView:_targetPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

function GameView:_send(action: string, payload: { [string]: any }, control: GuiObject?)
	self.requestSequence += 1
	payload.requestSequence = self.requestSequence
	if payload.targetPosition == nil then
		payload.targetPosition = self:_targetPosition()
	end
	self.lastActionControl = control or self.roleAction
	local sent, reason = self.actionHandler(action, payload)
	if not sent then
		Motion.Shake(self.lastActionControl :: GuiObject)
		self.lastActionControl = nil
		self:Notify("Action unavailable", reason or "The server cannot process that action.", "Warning")
	end
end

function GameView:HandleActionResult(accepted: boolean)
	local control = self.lastActionControl
	self.lastActionControl = nil
	if not accepted and control and control.Parent then
		Motion.Shake(control)
	end
end

function GameView:_chooseParticipant(
	action: string,
	payload: { [string]: any },
	includeSelf: boolean
)
	Components.ClearGenerated(self.targetList)
	self.targetTitle.Text = "Choose the living camper affected by this action."
	local state = self.currentState
	local participants = if type(state) == "table" then asTable(state.participants) else {}
	local ownId = if type(state) == "table" and type(state.player) == "table"
		then readString(state.player, "participantId", "")
		else ""
	local added = 0
	for _, participant in participants do
		if type(participant) == "table" then
			local participantId = readString(participant, "participantId", "")
			local eligible = readBoolean(participant, "alive", false)
				and not readBoolean(participant, "isGhost", false)
				and (includeSelf or participantId ~= ownId)
			if eligible and participantId ~= "" then
				added += 1
				local name = readString(participant, "displayName", "Unknown camper")
				local health = readString(participant, "healthState", "Healthy")
				local button = Components.Button(self.targetList, {
					name = "Target_" .. participantId:gsub("[^%w]", "_"),
					text = name .. "  -  " .. health,
					size = UDim2.new(1, -8, 0, 48),
					color = if health == "Injured" then Theme.Colors.Danger else Theme.Colors.PanelSoft,
				})
				button:SetAttribute("Generated", true)
				button.Activated:Connect(function()
					payload.targetParticipantId = participantId
					setModalVisible(self.targetModal, false)
					self:_send(action, payload, button)
				end)
			end
		end
	end
	if added == 0 then
		setModalVisible(self.targetModal, false)
		self:Notify(
			"No selectable target",
			"This action needs another living camper and was not sent.",
			"Warning"
		)
		return
	end
	setModalVisible(self.notebook, false)
	setModalVisible(self.settings, false)
	setModalVisible(self.targetModal, true)
end

function GameView:_chooseEvidence(action: string, payload: { [string]: any })
	Components.ClearGenerated(self.targetList)
	self.targetTitle.Text = "Choose the clue to analyze or verify."
	local state = self.currentState
	local board = if type(state) == "table" then state.evidence else nil
	local records: { any } = {}
	if type(board) == "table" then
		for _, record in asTable(board.culpritEvidence) do
			table.insert(records, record)
		end
		for _, record in asTable(board.monsterEvidence) do
			table.insert(records, record)
		end
	end
	local added = 0
	for _, record in records do
		if type(record) == "table" then
			local evidenceId = readString(record, "evidenceId", "")
			if evidenceId ~= "" then
				added += 1
				local button = Components.Button(self.targetList, {
					name = "Evidence_" .. evidenceId:gsub("[^%w]", "_"),
					text = readString(record, "displayName", "Unknown clue"),
					size = UDim2.new(1, -8, 0, 48),
					color = Theme.Colors.Info,
				})
				button:SetAttribute("Generated", true)
				button.Activated:Connect(function()
					payload.evidenceId = evidenceId
					setModalVisible(self.targetModal, false)
					self:_send(action, payload, button)
				end)
			end
		end
	end
	if added == 0 then
		setModalVisible(self.targetModal, false)
		self:Notify("No evidence available", "Post a clue before using this ability.", "Warning")
		return
	end
	setModalVisible(self.notebook, false)
	setModalVisible(self.settings, false)
	setModalVisible(self.targetModal, true)
end

function GameView:_promptEvidenceNote(evidenceId: string)
	Components.ClearGenerated(self.targetList)
	self.targetTitle.Text = "Add a short observation. Notes are shared with the evidence board."
	local input = Instance.new("TextBox")
	input.Name = "EvidenceNote"
	input:SetAttribute("Generated", true)
	input.Size = UDim2.new(1, -8, 0, 120)
	input.BackgroundColor3 = Theme.Colors.PanelRaised
	input.BorderSizePixel = 0
	input.ClearTextOnFocus = false
	input.Font = Enum.Font.GothamMedium
	input.MultiLine = true
	input.PlaceholderText = "What did you notice?"
	input.PlaceholderColor3 = Theme.Colors.TextMuted
	input.Text = ""
	input.TextColor3 = Theme.Colors.Text
	input.TextSize = 15
	input.TextWrapped = true
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.TextYAlignment = Enum.TextYAlignment.Top
	input.Parent = self.targetList
	Components.Corner(input)
	Components.Padding(input, 12)
	local submit = Components.Button(self.targetList, {
		name = "SubmitNote",
		text = "POST NOTE",
		size = UDim2.new(1, -8, 0, 46),
		color = Theme.Colors.Info,
	})
	submit:SetAttribute("Generated", true)
	submit.Activated:Connect(function()
		local text = string.sub(input.Text, 1, 200)
		if string.match(text, "^%s*$") then
			self:Notify("Note is empty", "Write a short observation before posting.", "Warning")
			return
		end
		setModalVisible(self.targetModal, false)
		self:_send("AddEvidenceNote", {
			evidenceId = evidenceId,
			text = text,
		}, submit)
	end)
	setModalVisible(self.notebook, false)
	setModalVisible(self.targetModal, true)
	task.defer(function()
		input:CaptureFocus()
	end)
end

function GameView:_buildAnnouncements()
	local banner = Components.Panel(self.root, "Announcement")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, -110)
	banner.Size = UDim2.fromOffset(520, 82)
	banner.ZIndex = 30
	local title = Components.Label(banner, "Title", "", 18, Enum.Font.GothamBold)
	title.Position = UDim2.fromOffset(18, 10)
	title.Size = UDim2.new(1, -36, 0, 28)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 31
	local body = Components.Label(banner, "Body", "", 14)
	body.Position = UDim2.fromOffset(18, 40)
	body.Size = UDim2.new(1, -36, 0, 32)
	body.TextXAlignment = Enum.TextXAlignment.Center
	body.ZIndex = 31
	self.announcement = banner
	self.announcementTitle = title
	self.announcementBody = body

	local toasts = Instance.new("Frame")
	toasts.Name = "Toasts"
	toasts.AnchorPoint = Vector2.new(1, 1)
	toasts.Position = UDim2.new(1, -18, 1, -122)
	toasts.Size = UDim2.fromOffset(360, 250)
	toasts.BackgroundTransparency = 1
	toasts.Parent = self.root
	local layout = Components.List(toasts, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	self.toastList = toasts
end

function GameView:_buildLobby()
	local lobby = Components.Panel(self.root, "Lobby")
	lobby.AnchorPoint = Vector2.new(1, 1)
	lobby.Position = UDim2.new(1, -18, 1, -18)
	lobby.Size = UDim2.fromOffset(300, 104)
	local text = Components.Label(lobby, "LobbyText", "Campers: waiting...", 14)
	text.Position = UDim2.fromOffset(12, 8)
	text.Size = UDim2.new(1, -24, 0, 40)
	local ready = Components.Button(lobby, {
		name = "Ready",
		text = "READY UP",
		size = UDim2.fromOffset(174, 42),
		position = UDim2.fromOffset(12, 54),
		color = Theme.Colors.Success,
	})
	ready.Activated:Connect(function()
		local nextReady = ready.Text ~= "CANCEL READY"
		self.lastActionControl = ready
		local sent, reason = self.actionHandler("Ready", { ready = nextReady })
		if not sent then
			Motion.Shake(ready)
			self.lastActionControl = nil
			self:Notify("Not available", reason or "Ready-up is not active.", "Warning")
		end
	end)
	local progression = Components.Button(lobby, {
		name = "Progression",
		text = "PROGRESS",
		size = UDim2.fromOffset(102, 42),
		position = UDim2.new(1, -114, 0, 54),
		color = Theme.Colors.Gold,
	})
	progression.TextColor3 = Theme.Colors.Background
	progression.Activated:Connect(function()
		self:ToggleProgression()
	end)
	self.readyButton = ready
	self.lobbyText = text
	self.lobbyPanel = lobby
end

function GameView:_activateRoleAbility(abilityId: string)
		local lowered = string.lower(abilityId)
		if string.find(lowered, "analyze", 1, true) then
			self:_chooseParticipant("UseRoleAbility", {
				abilityId = abilityId,
			}, false)
		elseif string.find(lowered, "evidence", 1, true) then
			self:_chooseEvidence("UseRoleAbility", {
				abilityId = abilityId,
			})
		elseif string.find(lowered, "treatment", 1, true)
			or string.find(lowered, "protect", 1, true)
			or string.find(lowered, "guard", 1, true)
			or string.find(lowered, "attack", 1, true)
			or string.find(lowered, "false", 1, true)
		then
			self:_chooseParticipant("UseRoleAbility", {
				abilityId = abilityId,
			}, false)
		else
			self:_send("UseRoleAbility", {
				abilityId = abilityId,
			})
		end
end

function GameView:_chooseAbility(actionKind: "Role" | "Monster", abilityIds: { string })
	Components.ClearGenerated(self.targetList)
	self.targetTitle.Text = "Choose the ability to activate."
	for _, abilityId in abilityIds do
		local button = Components.Button(self.targetList, {
			name = "Ability_" .. abilityId:gsub("[^%w]", "_"),
			text = string.upper(abilityId:gsub("-", " ")),
			size = UDim2.new(1, -8, 0, 48),
			color = if actionKind == "Monster" then Theme.Colors.Danger else Theme.Colors.Info,
		})
		button:SetAttribute("Generated", true)
		button.Activated:Connect(function()
			setModalVisible(self.targetModal, false)
			if actionKind == "Monster" then
				self:_chooseParticipant("UseMonsterAbility", {
					abilityId = abilityId,
				}, false)
			else
				self:_activateRoleAbility(abilityId)
			end
		end)
	end
	setModalVisible(self.notebook, false)
	setModalVisible(self.settings, false)
	setModalVisible(self.targetModal, true)
end

function GameView:_chooseMurderPlan()
	Components.ClearGenerated(self.targetList)
	self.targetTitle.Text = "Choose tonight's transformation, then choose a victim."
	for monsterId, locationId in MONSTER_PLAN_LOCATIONS do
		local button = Components.Button(self.targetList, {
			name = "Plan_" .. monsterId,
			text = string.upper(monsterId:gsub("(%l)(%u)", "%1 %2")),
			size = UDim2.new(1, -8, 0, 48),
			color = Theme.Colors.Danger,
		})
		button:SetAttribute("Generated", true)
		button.Activated:Connect(function()
			setModalVisible(self.targetModal, false)
			self:_chooseParticipant("SetMurderPlan", {
				monsterId = monsterId,
				locationId = locationId,
			}, false)
		end)
	end
	setModalVisible(self.notebook, false)
	setModalVisible(self.settings, false)
	setModalVisible(self.targetModal, true)
end

function GameView:_requestRoleAction()
	local state = self.currentState
	local planEnabled = self:_available(state, "SetMurderPlan")
	if planEnabled then
		self:_chooseMurderPlan()
		return
	end
	local player = if type(state) == "table" then state.player else nil
	local rawAbilities = if type(player) == "table" then asTable(player.abilityIds) else {}
	local abilities: { string } = {}
	for _, ability in rawAbilities do
		if type(ability) == "string" then
			table.insert(abilities, ability)
		end
	end
	local privateMonster = if type(state) == "table" then state.privateMonster else nil
	if type(privateMonster) == "table" and readBoolean(privateMonster, "active", false) then
		local monsterId = readString(privateMonster, "monsterId", "")
		local monsterAbilities = table.clone(MONSTER_ABILITIES[monsterId] or {})
		if #monsterAbilities == 0 then
			table.insert(monsterAbilities, "primary")
		end
		if #monsterAbilities == 1 then
			self:_chooseParticipant("UseMonsterAbility", {
				abilityId = monsterAbilities[1],
			}, false)
		else
			self:_chooseAbility("Monster", monsterAbilities)
		end
	elseif #abilities == 1 then
		self:_activateRoleAbility(abilities[1])
	elseif #abilities > 1 then
		self:_chooseAbility("Role", abilities)
	else
		self:Notify("No active ability", "Your current role uses equipment and investigation.", "Info")
	end
end

function GameView:_settingRow(
	name: string,
	key: string,
	isToggle: boolean,
	minimum: number?,
	maximum: number?
)
	local row = Components.Panel(self.settingsList, "Setting_" .. key)
	row:SetAttribute("Generated", true)
	row.Size = UDim2.new(1, -8, 0, 56)
	local label = Components.Label(row, "Label", name, 14, Enum.Font.GothamBold)
	label.Position = UDim2.fromOffset(12, 0)
	label.Size = UDim2.new(1, -190, 1, 0)
	local value = self.settingsValues[key]
	if isToggle then
		local button = Components.Button(row, {
			name = "Toggle",
			text = if value == true then "ON" else "OFF",
			size = UDim2.fromOffset(112, 36),
			position = UDim2.new(1, -124, 0.5, -18),
			color = if value == true then Theme.Colors.Success else Theme.Colors.PanelSoft,
		})
		button.Activated:Connect(function()
			self:_setSetting(key, not (self.settingsValues[key] == true))
		end)
	else
		local minValue = minimum or 0
		local maxValue = maximum or 1
		local minus = Components.Button(row, {
			name = "Minus",
			text = "-",
			size = UDim2.fromOffset(36, 36),
			position = UDim2.new(1, -164, 0.5, -18),
		})
		local display = Components.Label(row, "Value", string.format("%.1f", tonumber(value) or 1), 14, Enum.Font.GothamBold)
		display.Position = UDim2.new(1, -124, 0, 0)
		display.Size = UDim2.fromOffset(72, 56)
		display.TextXAlignment = Enum.TextXAlignment.Center
		local plus = Components.Button(row, {
			name = "Plus",
			text = "+",
			size = UDim2.fromOffset(36, 36),
			position = UDim2.new(1, -44, 0.5, -18),
		})
		minus.Activated:Connect(function()
			self:_setSetting(
				key,
				math.clamp((tonumber(self.settingsValues[key]) or 1) - 0.1, minValue, maxValue)
			)
		end)
		plus.Activated:Connect(function()
			self:_setSetting(
				key,
				math.clamp((tonumber(self.settingsValues[key]) or 1) + 0.1, minValue, maxValue)
			)
		end)
	end
end

function GameView:_rebuildSettings()
	Components.ClearGenerated(self.settingsList)
	local defaults: { [string]: any } = {
		masterVolume = 1,
		musicVolume = 0.7,
		ambienceVolume = 0.8,
		effectsVolume = 0.9,
		uiVolume = 0.8,
		subtitles = true,
		reducedMotion = false,
		cameraShake = true,
		highContrastEvidence = false,
		mouseSensitivity = 1,
		controllerSensitivity = 1,
		sprintToggle = false,
	}
	for key, value in defaults do
		if self.settingsValues[key] == nil then
			self.settingsValues[key] = value
		end
	end
	self:_settingRow("Master volume", "masterVolume", false, 0, 1)
	self:_settingRow("Music volume", "musicVolume", false, 0, 1)
	self:_settingRow("Ambience volume", "ambienceVolume", false, 0, 1)
	self:_settingRow("Effects volume", "effectsVolume", false, 0, 1)
	self:_settingRow("UI volume", "uiVolume", false, 0, 1)
	self:_settingRow("Subtitles", "subtitles", true)
	self:_settingRow("Reduced motion", "reducedMotion", true)
	self:_settingRow("Camera shake", "cameraShake", true)
	self:_settingRow("High-contrast evidence", "highContrastEvidence", true)
	self:_settingRow("Mouse sensitivity", "mouseSensitivity", false, 0.1, 3)
	self:_settingRow("Controller sensitivity", "controllerSensitivity", false, 0.1, 3)
	self:_settingRow("Toggle sprint", "sprintToggle", true)
end

function GameView:_setSetting(key: string, value: any)
	self.settingsValues[key] = value
	if key == "reducedMotion" and type(value) == "boolean" then
		self.root:SetAttribute("ReducedMotion", value)
	end
	self:_rebuildSettings()
	self.lastActionControl = self.settings
	local sent, reason = self.actionHandler("SetSettings", {
		settings = { [key] = value },
	})
	if not sent then
		Motion.Shake(self.settings)
		self.lastActionControl = nil
		self:Notify("Saved on this device", reason or "Server profile sync is unavailable.", "Info")
	end
end

function GameView:_updateLobby(state: any, phase: string)
	local lobby = if type(state) == "table" then state.lobby else nil
	local parent = self.readyButton.Parent
	if not parent or not parent:IsA("GuiObject") then
		return
	end
	parent.Visible = phase == "Lobby"
	self.healthPanel.Visible = phase ~= "Lobby"
	self.hotbar.Visible = phase ~= "Lobby"
	if type(lobby) ~= "table" then
		self.lobbyText.Text = "The next mystery begins soon."
		Components.SetButtonEnabled(self.readyButton, false)
		return
	end
	local humans = readNumber(lobby, "humanCount", 0)
	local readyCount = readNumber(lobby, "readyCount", 0)
	local target = readNumber(lobby, "standardTarget", 10)
	self.lobbyText.Text = string.format("CAMPERS  %d/%d     READY  %d", humans, target, readyCount)
	local players = asTable(lobby.players)
	local isReady = false
	for _, entry in players do
		if type(entry) == "table" and entry.userId == Players.LocalPlayer.UserId then
			isReady = readBoolean(entry, "isReady", false)
			break
		end
	end
	self.readyButton.Text = if isReady then "CANCEL READY" else "READY UP"
	Components.SetButtonEnabled(self.readyButton, true)
end

function GameView:_updateInventory(state: any)
	local selected = GuiService.SelectedObject
	local restoreControllerFocus = selected ~= nil and selected:IsDescendantOf(self.hotbar)
	Components.ClearGenerated(self.hotbar)
	local inventory = if type(state) == "table" then state.inventory else nil
	local items = if type(inventory) == "table" then asTable(inventory.items) else {}
	self.inventoryItems = items
	if self.selectedInventorySlot < 1 or self.selectedInventorySlot > #items then
		self.selectedInventorySlot = if #items > 0 then 1 else 0
	end
	if #items == 0 then
		local empty = Components.Label(self.hotbar, "Empty", "Equipment will appear here.", 13)
		empty.Size = UDim2.fromOffset(260, 68)
		empty.TextXAlignment = Enum.TextXAlignment.Center
		empty:SetAttribute("Generated", true)
		return
	end
	for index, item in items do
		if type(item) == "table" then
			local displayName = readString(item, "displayName", readString(item, "equipmentId", "Item"))
			local charges = readNumber(item, "charges", 0)
			local equipped = readBoolean(item, "equipped", false)
			local button = Components.Button(self.hotbar, {
				name = "Slot_" .. tostring(index),
				text = string.format("%d\n%s%s", index, displayName, if charges > 0 then "  [" .. tostring(charges) .. "]" else ""),
				size = UDim2.fromOffset(112, 68),
				color = if index == self.selectedInventorySlot
					then Theme.Colors.Info
					elseif equipped then Theme.Colors.Gold
					else Theme.Colors.Panel,
			})
			local equipmentId = readString(item, "equipmentId", "")
			local image = self.resolveImage(imageKey("Equipment", equipmentId))
			if image then
				button.Text = ""
				optionalImage(button, "Icon", image, UDim2.fromOffset(6, 16), UDim2.fromOffset(34, 34))
				local caption = Components.Label(
					button,
					"Caption",
					string.format(
						"%d\n%s%s",
						index,
						displayName,
						if charges > 0 then " [" .. tostring(charges) .. "]" else ""
					),
					11,
					Enum.Font.GothamBold
				)
				caption.Position = UDim2.fromOffset(43, 4)
				caption.Size = UDim2.new(1, -47, 1, -8)
				caption.TextXAlignment = Enum.TextXAlignment.Center
			end
			button:SetAttribute("Generated", true)
			button.Activated:Connect(function()
				self.selectedInventorySlot = index
				self:_activateItem(item, button)
			end)
		end
	end
	if restoreControllerFocus and self.selectedInventorySlot > 0 then
		task.defer(function()
			if self.destroyed then
				return
			end
			local selectedButton = self.hotbar:FindFirstChild(
				"Slot_" .. tostring(self.selectedInventorySlot)
			)
			if selectedButton and selectedButton:IsA("GuiButton") and selectedButton.Active then
				GuiService.SelectedObject = selectedButton
			end
		end)
	end
end

function GameView:_activateItem(item: any, control: GuiObject?)
	if type(item) ~= "table" then
		return
	end
	local instanceId = readString(item, "instanceId", "")
	if instanceId == "" then
		return
	end
	if not readBoolean(item, "equipped", false) then
		self:_send("EquipItem", { instanceId = instanceId }, control)
		return
	end
	local equipmentId = readString(item, "equipmentId", "")
	local payload: { [string]: any } = {
		instanceId = instanceId,
		direction = if Workspace.CurrentCamera then Workspace.CurrentCamera.CFrame.LookVector else nil,
	}
	if equipmentId == "MedicalKit" then
		self:_chooseParticipant("UseItem", payload, false)
	else
		self:_send("UseItem", payload, control)
	end
end

function GameView:_updateEvidence(state: any, round: any)
	Components.ClearGenerated(self.evidenceList)
	local board = if type(state) == "table" then state.evidence else nil
	local mystery = if type(state) == "table" then state.mystery else nil
	local counselors = if type(state) == "table" then state.counselors else nil
	local counselorRoster = if type(counselors) == "table"
		then asTable(counselors.counselors)
		else {}
	local candidateNamesById: { [string]: string } = {}
	if type(state) == "table" then
		for _, participant in asTable(state.participants) do
			if type(participant) == "table" then
				local participantId = readString(participant, "participantId", "")
				if participantId ~= "" then
					candidateNamesById[participantId] =
						readString(participant, "displayName", participantId)
				end
			end
		end
	end
	for _, counselor in counselorRoster do
		if type(counselor) == "table" then
			local counselorId = readString(counselor, "counselorId", "")
			if counselorId ~= "" then
				candidateNamesById[counselorId] =
					readString(counselor, "displayName", counselorId)
			end
		end
	end
	local culprit: { any } = {}
	local monster: { any } = {}
	if type(board) == "table" then
		culprit = asTable(board.culpritEvidence)
		monster = asTable(board.monsterEvidence)
	else
		culprit = if type(round) == "table" then asTable(round.evidence) else {}
	end
	self.evidenceSummary.Text = string.format(
		"%s\nCULPRIT CLUES  %d     MONSTER CLUES  %d     MYSTERY  %d/%d",
		readString(mystery, "title", "CURRENT CASE"),
		#culprit,
		#monster,
		readNumber(mystery, "discoveredClueCount", 0),
		readNumber(mystery, "totalClueCount", 0)
	)
	local function addEvidence(record: any, channel: string)
		if type(record) ~= "table" then
			return
		end
		local card = Components.Panel(self.evidenceList, "EvidenceCard")
		card:SetAttribute("Generated", true)
		card.Size = UDim2.new(1, -8, 0, 142)
		local title = Components.Label(card, "Title", readString(record, "displayName", "Unknown clue"), 16, Enum.Font.GothamBold)
		title.Position = UDim2.fromOffset(12, 7)
		title.Size = UDim2.new(1, -150, 0, 27)
		title.TextColor3 = if channel == "MONSTER" then Theme.Colors.Ghost else Theme.Colors.Gold
		local icon = optionalImage(
			card,
			"EvidenceIcon",
			self.resolveImage(if channel == "MONSTER" then "Evidence_Monster" else "Evidence_Culprit"),
			UDim2.fromOffset(12, 7),
			UDim2.fromOffset(26, 26)
		)
		if icon then
			title.Position = UDim2.fromOffset(44, 7)
			title.Size = UDim2.new(1, -182, 0, 27)
		end
		local tag = Components.Label(card, "Channel", channel, 11, Enum.Font.GothamBold)
		tag.Position = UDim2.new(1, -126, 0, 7)
		tag.Size = UDim2.fromOffset(112, 26)
		tag.TextXAlignment = Enum.TextXAlignment.Center
		tag.BackgroundColor3 = Theme.Colors.PanelSoft
		tag.BackgroundTransparency = 0
		Components.Corner(tag, 13)
		local description = Components.Label(card, "Description", readString(record, "description", "No description recorded."), 13)
		description.Position = UDim2.fromOffset(12, 36)
		description.Size = UDim2.new(1, -24, 0, 42)
		description.TextYAlignment = Enum.TextYAlignment.Top
		local verification = readString(record, "verificationState", "Unverified")
		local finder = readString(record, "foundBy", "")
		local discovery = record.discovery
		if type(discovery) == "table" then
			finder = readString(discovery, "discoveredByDisplayName", finder)
		end
		local footer = Components.Label(
			card,
			"Footer",
			(if finder ~= "" then "Found by " .. finder .. "  |  " else "") .. verification,
			11,
			Enum.Font.GothamBold
		)
		footer.Position = UDim2.fromOffset(12, 80)
		footer.Size = UDim2.new(1, -24, 0, 20)
		footer.TextColor3 = if verification == "VerifiedReal"
			then Theme.Colors.Success
			elseif verification == "VerifiedFake" then Theme.Colors.DangerBright
			else Theme.Colors.TextMuted
		local evidenceId = readString(record, "evidenceId", readString(record, "id", ""))
		local verifyEnabled = self:_available(state, "VerifyEvidence")
		local noteEnabled = self:_available(state, "AddEvidenceNote")
		local verify = Components.Button(card, {
			name = "Verify",
			text = "VERIFY",
			size = UDim2.fromOffset(104, 30),
			position = UDim2.new(1, -220, 1, -36),
			color = Theme.Colors.Success,
		})
		local note = Components.Button(card, {
			name = "Note",
			text = "ADD NOTE",
			size = UDim2.fromOffset(104, 30),
			position = UDim2.new(1, -110, 1, -36),
			color = Theme.Colors.Info,
		})
		Components.SetButtonEnabled(verify, verifyEnabled and evidenceId ~= "")
		Components.SetButtonEnabled(note, noteEnabled and evidenceId ~= "")
		verify.Activated:Connect(function()
			self:_send("VerifyEvidence", { evidenceId = evidenceId }, verify)
		end)
		note.Activated:Connect(function()
			self:_promptEvidenceNote(evidenceId)
		end)
	end
	for _, record in culprit do
		addEvidence(record, "CULPRIT")
	end
	for _, record in monster do
		addEvidence(record, "MONSTER")
	end
	local mysteryClues = if type(mystery) == "table" then asTable(mystery.clues) else {}
	for _, clue in mysteryClues do
		if type(clue) == "table" then
			local card = Components.Panel(self.evidenceList, "MysteryClue")
			card:SetAttribute("Generated", true)
			card.Size = UDim2.new(1, -8, 0, 132)
			local channel = readString(clue, "channel", "Culprit")
			local title = Components.Label(
				card,
				"Title",
				readString(clue, "title", "Recovered clue"),
				16,
				Enum.Font.GothamBold
			)
			title.Position = UDim2.fromOffset(12, 7)
			title.Size = UDim2.new(1, -150, 0, 27)
			title.TextColor3 = if channel == "Monster"
				then Theme.Colors.Ghost
				else Theme.Colors.Gold
			local icon = optionalImage(
				card,
				"EvidenceIcon",
				self.resolveImage("Evidence_Mystery"),
				UDim2.fromOffset(12, 7),
				UDim2.fromOffset(26, 26)
			)
			if icon then
				title.Position = UDim2.fromOffset(44, 7)
				title.Size = UDim2.new(1, -182, 0, 27)
			end
			local tag = Components.Label(
				card,
				"Channel",
				string.upper(channel .. " lead"),
				11,
				Enum.Font.GothamBold
			)
			tag.Position = UDim2.new(1, -126, 0, 7)
			tag.Size = UDim2.fromOffset(112, 26)
			tag.TextXAlignment = Enum.TextXAlignment.Center
			tag.BackgroundColor3 = Theme.Colors.PanelSoft
			tag.BackgroundTransparency = 0
			Components.Corner(tag, 13)
			local description = Components.Label(
				card,
				"Description",
				readString(clue, "publicDescription", "No description recorded."),
				13
			)
			description.Position = UDim2.fromOffset(12, 36)
			description.Size = UDim2.new(1, -24, 0, 52)
			description.TextYAlignment = Enum.TextYAlignment.Top
			local candidateIds = if channel == "Monster"
				then clue.monsterCandidateIds
				else clue.suspectCandidateIds
			local footer = Components.Label(
				card,
				"Candidates",
				"NARROWS TO: "
					.. joinCandidateNames(candidateIds, candidateNamesById),
				11,
				Enum.Font.GothamBold
			)
			footer.Position = UDim2.fromOffset(12, 96)
			footer.Size = UDim2.new(1, -24, 0, 24)
			footer.TextColor3 = Theme.Colors.TextMuted
		end
	end
	local witnessAccounts = if type(mystery) == "table"
		then asTable(mystery.witnessAccounts)
		else {}
	for _, account in witnessAccounts do
		if type(account) == "table" then
			local card = Components.Panel(self.evidenceList, "WitnessAccount")
			card:SetAttribute("Generated", true)
			card.Size = UDim2.new(1, -8, 0, 112)
			local title = Components.Label(
				card,
				"Title",
				"WITNESS STATEMENT",
				14,
				Enum.Font.GothamBold
			)
			title.Position = UDim2.fromOffset(12, 7)
			title.Size = UDim2.new(1, -24, 0, 24)
			title.TextColor3 = Theme.Colors.Amber
			local icon = optionalImage(
				card,
				"EvidenceIcon",
				self.resolveImage("Evidence_Witness"),
				UDim2.fromOffset(12, 7),
				UDim2.fromOffset(24, 24)
			)
			if icon then
				title.Position = UDim2.fromOffset(42, 7)
				title.Size = UDim2.new(1, -54, 0, 24)
			end
			local statement = Components.Label(
				card,
				"Statement",
				readString(account, "statement", "No statement recorded."),
				13
			)
			statement.Position = UDim2.fromOffset(12, 34)
			statement.Size = UDim2.new(1, -24, 0, 66)
			statement.TextYAlignment = Enum.TextYAlignment.Top
		end
	end
	local canInterview = self:_available(state, "InterviewCounselor")
	for _, counselor in counselorRoster do
		if type(counselor) == "table" then
			local card = Components.Panel(self.evidenceList, "Counselor")
			card:SetAttribute("Generated", true)
			card.Size = UDim2.new(1, -8, 0, 104)
			local name = Components.Label(
				card,
				"Name",
				readString(counselor, "displayName", "Camp counselor"),
				15,
				Enum.Font.GothamBold
			)
			name.Position = UDim2.fromOffset(12, 7)
			name.Size = UDim2.new(1, -174, 0, 26)
			name.TextColor3 = Theme.Colors.Gold
			local activity = Components.Label(
				card,
				"Activity",
				readString(counselor, "currentActivity", "No current activity")
					.. "\nLocation: "
					.. readString(counselor, "locationId", "unknown"),
				12
			)
			activity.Position = UDim2.fromOffset(12, 36)
			activity.Size = UDim2.new(1, -174, 0, 58)
			activity.TextColor3 = Theme.Colors.TextMuted
			activity.TextYAlignment = Enum.TextYAlignment.Top
			local interview = Components.Button(card, {
				name = "Interview",
				text = if readBoolean(counselor, "isWitness", false)
					then "ASK WITNESS"
					else "INTERVIEW",
				size = UDim2.fromOffset(148, 42),
				position = UDim2.new(1, -160, 0.5, -21),
				color = Theme.Colors.Info,
			})
			local counselorId = readString(counselor, "counselorId", "")
			Components.SetButtonEnabled(
				interview,
				canInterview
					and readBoolean(counselor, "interactionAllowed", false)
					and counselorId ~= ""
			)
			interview.Activated:Connect(function()
				self:_send("InterviewCounselor", {
					counselorId = counselorId,
					topic = "Observation",
				}, interview)
			end)
		end
	end
	if #culprit + #monster + #mysteryClues + #witnessAccounts == 0 then
		local empty = Components.Label(
			self.evidenceList,
			"Empty",
			"No evidence has been posted. Search rooms, objects, and attack sites.",
			15
		)
		empty:SetAttribute("Generated", true)
		empty.Size = UDim2.new(1, -8, 0, 100)
		empty.TextXAlignment = Enum.TextXAlignment.Center
		empty.TextColor3 = Theme.Colors.TextMuted
	end
end

function GameView:_updateVote(round: any, player: any)
	local phase = readString(round, "phase", "Lobby")
	local alive = readBoolean(player, "alive", false)
	local isGhost = readBoolean(player, "isGhost", false)
	local vote = if type(player) == "table" then player.vote else nil
	local hasVoted = readBoolean(player, "hasVoted", false)
	if type(vote) == "table" then
		hasVoted = readBoolean(vote, "hasVoted", hasVoted)
	end
	if phase ~= "Campfire" or not alive or isGhost then
		setModalVisible(self.voteModal, false)
		self.currentVoteSignature = ""
		return
	end
	setModalVisible(self.voteModal, true)
	local suspects = asTable(round.suspects)
	local pieces = { tostring(hasVoted) }
	for _, suspect in suspects do
		if type(suspect) == "table" then
			table.insert(pieces, readString(suspect, "key", readString(suspect, "participantId", "")))
		end
	end
	local signature = table.concat(pieces, "|")
	if signature == self.currentVoteSignature then
		return
	end
	self.currentVoteSignature = signature
	Components.ClearGenerated(self.voteList)
	for _, suspect in suspects do
		if type(suspect) == "table" then
			local key = readString(suspect, "key", readString(suspect, "participantId", ""))
			local name = readString(suspect, "displayName", "Unknown camper")
			local button = Components.Button(self.voteList, {
				name = "Vote_" .. key:gsub("[^%w]", "_"),
				text = if hasVoted then name .. " - VOTE LOCKED" else name,
				size = UDim2.new(1, -8, 0, 48),
				color = Theme.Colors.Danger,
			})
			button:SetAttribute("Generated", true)
			Components.SetButtonEnabled(button, not hasVoted)
			button.Activated:Connect(function()
				self.lastActionControl = button
				local sent, reason = self.actionHandler("Vote", {
					targetKey = key,
					targetParticipantId = key,
				})
				if sent then
					Components.SetButtonEnabled(button, false)
				else
					Motion.Shake(button)
					self.lastActionControl = nil
					self:Notify("Vote rejected", reason or "Your vote could not be recorded.", "Danger")
				end
			end)
		end
	end
end

function GameView:_available(state: any, actionName: string): (boolean, string?)
	if type(state) ~= "table" then
		return false, nil
	end
	local actions = asTable(state.availableActions)
	for _, action in actions do
		if type(action) == "table" and action.name == actionName then
			return readBoolean(action, "enabled", false), if type(action.reason) == "string" then action.reason else nil
		end
	end
	return false, nil
end

function GameView:Update(state: any, legacyRound: any, legacyPlayer: any)
	self.currentState = state
	self.legacyRound = legacyRound
	self.legacyPlayer = legacyPlayer
	local round = if type(state) == "table" and type(state.round) == "table" then state.round else legacyRound
	local player = if type(state) == "table" and type(state.player) == "table" then state.player else legacyPlayer
	if type(round) ~= "table" then
		self.phaseLabel.Text = "WAITING FOR THE CAMP"
		self.progressLabel.Text = "Connecting to the round server..."
		return
	end

	local phase = readString(round, "phase", "Lobby")
	self.phaseLabel.Text = string.upper(readString(round, "phaseDisplayName", phase))
	local seconds = math.max(0, math.ceil(readNumber(round, "phaseEndsAt", 0) - Workspace:GetServerTimeNow()))
	self.timerLabel.Text = string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
	if seconds <= 10 and seconds > 0 then
		self.timerLabel.TextColor3 = Theme.Colors.DangerBright
	else
		self.timerLabel.TextColor3 = Theme.Colors.Gold
	end

	local objectiveDone = readNumber(round, "objectivesCompleted", 0)
	local objectiveGoal = math.max(1, readNumber(round, "objectiveGoal", 1))
	local evidenceFound = readNumber(round, "evidenceFound", 0)
	local evidenceGoal = math.max(1, readNumber(round, "evidenceGoal", 1))
	if phase == "Day" then
		self.progressLabel.Text = string.format("Camp work %d/%d - prepare before sunset.", objectiveDone, objectiveGoal)
		self.objectiveText.Text = string.format("DAY OBJECTIVE\nComplete camp work: %d of %d", objectiveDone, objectiveGoal)
		self.objectiveFill.Size = UDim2.fromScale(math.clamp(objectiveDone / objectiveGoal, 0, 1), 1)
	elseif phase == "Investigation" then
		self.progressLabel.Text = string.format("Evidence %d/%d - search the abandoned town.", evidenceFound, evidenceGoal)
		self.objectiveText.Text = string.format("NIGHT OBJECTIVE\nCollect and post clues: %d of %d", evidenceFound, evidenceGoal)
		self.objectiveFill.Size = UDim2.fromScale(math.clamp(evidenceFound / evidenceGoal, 0, 1), 1)
	elseif phase == "Campfire" then
		local cast = readNumber(round, "votesCast", 0)
		local eligible = math.max(1, readNumber(round, "eligibleVoters", 1))
		self.progressLabel.Text = string.format("Votes locked %d/%d - accuse carefully.", cast, eligible)
		self.objectiveText.Text = "FINAL OBJECTIVE\nReview the notebook and identify the Murderer."
		self.objectiveFill.Size = UDim2.fromScale(math.clamp(cast / eligible, 0, 1), 1)
	else
		self.progressLabel.Text = readString(
			round,
			"resultMessage",
			if readBoolean(round, "isNight", false) then "Stay together. The town is awake." else "Listen for the next briefing."
		)
		self.objectiveText.Text = if phase == "Lobby"
			then "NEXT MYSTERY\nReady up while the camp fills empty seats."
			else "CURRENT MISSION\nFollow the phase instructions and stay alert."
		self.objectiveFill.Size = UDim2.fromScale(0, 1)
	end

	local role = readString(player, "role", "Spectator")
	local roleImage = self.resolveImage(imageKey("Role", role))
	self.roleIcon.Image = roleImage or ""
	self.roleIcon.Visible = roleImage ~= nil
	self.roleTitle.Position = if roleImage
		then UDim2.fromOffset(58, 12)
		else UDim2.fromOffset(16, 12)
	self.roleTitle.Size = if roleImage
		then UDim2.new(1, -174, 0, 34)
		else UDim2.new(1, -32, 0, 34)
	self.roleTitle.Text = string.upper(readString(player, "roleDisplayName", role))
	self.roleDescription.Text = readString(
		player,
		"roleDescription",
		readString(player, "statusMessage", "Your private instructions will appear here.")
	)
	local alive = readBoolean(player, "alive", false)
	local ghost = readBoolean(player, "isGhost", false)
	local healthState = readString(player, "healthState", if alive then "Healthy" else "Waiting")
	if ghost then
		self.stateBadge.Text = "GHOST"
		self.stateBadge.BackgroundColor3 = Theme.Colors.Ghost
		self.roleTitle.TextColor3 = Theme.Colors.Ghost
	elseif alive then
		self.stateBadge.Text = string.upper(healthState)
		self.stateBadge.BackgroundColor3 = if healthState == "Injured" then Theme.Colors.Danger else Theme.Colors.Success
		self.roleTitle.TextColor3 = if role == "Murderer" then Theme.Colors.DangerBright else Theme.Colors.Gold
	else
		self.stateBadge.Text = "WAITING"
		self.stateBadge.BackgroundColor3 = Theme.Colors.PanelSoft
	end

	local combat = if type(state) == "table" then state.combat else nil
	local health = readNumber(combat, "health", readNumber(player, "health", if alive then 100 else 0))
	local maxHealth = math.max(1, readNumber(combat, "maxHealth", readNumber(player, "maxHealth", 100)))
	if ghost then
		self.healthText.Text = "SPIRIT STATE  -  LIVING ACTIONS LOCKED"
		self.healthFill.BackgroundColor3 = Theme.Colors.Ghost
	elseif not alive then
		self.healthText.Text = "WAITING FOR NEXT ROUND"
		self.healthFill.BackgroundColor3 = Theme.Colors.PanelSoft
	else
		self.healthText.Text = string.format("%s  %d/%d", string.upper(healthState), health, maxHealth)
		self.healthFill.BackgroundColor3 = if healthState == "Injured" then Theme.Colors.Danger else Theme.Colors.Success
	end
	self.healthFill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)

	local roleEnabled, roleReason = self:_available(state, "UseRoleAbility")
	local monsterEnabled = self:_available(state, "UseMonsterAbility")
	local planEnabled = self:_available(state, "SetMurderPlan")
	Components.SetButtonEnabled(self.roleAction, roleEnabled or monsterEnabled or planEnabled)
	self.roleAction.Text = if planEnabled
		then "PLAN TONIGHT'S HUNT"
		elseif monsterEnabled
		then "USE MONSTER ABILITY"
		elseif roleEnabled then "USE ROLE ABILITY"
		elseif roleReason then string.upper(roleReason)
		else "ABILITY UNAVAILABLE"

	self:_updateLobby(state, phase)
	self:_updateInventory(state)
	self:_updateEvidence(state, round)
	self:_updateVote(round, player)
	if modalTargetVisible(self.progression) then
		self:_updateProgression(state)
	end

	local winner = if type(round.winner) == "string" then round.winner else nil
	if (phase == "Resolution" or phase == "Rewards") and not modalTargetVisible(self.progression) then
		self.resultTitle.Text = if winner then string.upper(winner .. " WIN") else "MYSTERY RESOLVED"
		self.resultBody.Text = readString(round, "resultMessage", "The night is over—for now.")
		local profile = if type(state) == "table" then state.profile else nil
		local profileData = if type(profile) == "table" then profile.profile else nil
		self.rewardText.Text = if type(profileData) == "table"
			then string.format(
				"TOTAL XP  %d     CAMP TOKENS  %d",
				readNumber(profileData, "totalXP", 0),
				readNumber(profileData, "campTokens", 0)
			)
			else "Rewards are finalized by the server."
		setModalVisible(self.resultModal, true)
	elseif phase ~= "Rewards" then
		setModalVisible(self.resultModal, false)
	end

	local profile = if type(state) == "table" then state.profile else nil
	local profileData = if type(profile) == "table" then profile.profile else nil
	local settings = if type(profileData) == "table" then profileData.settings else nil
	if type(settings) == "table" then
		local changed = false
		for key, value in settings do
			if self.settingsValues[key] ~= value then
				self.settingsValues[key] = value
				changed = true
			end
		end
		if changed then
			self:_rebuildSettings()
		end
	end
end

function GameView:Tick()
	local round = if type(self.currentState) == "table" and type(self.currentState.round) == "table"
		then self.currentState.round
		else self.legacyRound
	if type(round) ~= "table" then
		return
	end
	local seconds = math.max(0, math.ceil(readNumber(round, "phaseEndsAt", 0) - Workspace:GetServerTimeNow()))
	self.timerLabel.Text = string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
	self.timerLabel.TextColor3 = if seconds <= 10 and seconds > 0 then Theme.Colors.DangerBright else Theme.Colors.Gold
end

function GameView:ToggleNotebook()
	setModalVisible(self.settings, false)
	setModalVisible(self.progression, false)
	setModalVisible(self.notebook, not modalTargetVisible(self.notebook))
end

function GameView:ToggleSettings()
	setModalVisible(self.notebook, false)
	setModalVisible(self.progression, false)
	setModalVisible(self.settings, not modalTargetVisible(self.settings))
end

function GameView:ToggleProgression()
	setModalVisible(self.notebook, false)
	setModalVisible(self.settings, false)
	setModalVisible(self.resultModal, false)
	local willOpen = not modalTargetVisible(self.progression)
	if willOpen then
		self:_updateProgression(self.currentState)
	end
	setModalVisible(self.progression, willOpen)
end

function GameView:CloseModal()
	setModalVisible(self.notebook, false)
	setModalVisible(self.settings, false)
	setModalVisible(self.progression, false)
	setModalVisible(self.targetModal, false)
	if modalTargetVisible(self.resultModal) then
		setModalVisible(self.resultModal, false)
	end
end

function GameView:ActivateInventorySlot(slot: number)
	local item = self.inventoryItems[slot]
	if item then
		self.selectedInventorySlot = slot
		local control = self.hotbar:FindFirstChild("Slot_" .. tostring(slot))
		self:_activateItem(
			item,
			if control and control:IsA("GuiObject") then control else nil
		)
	end
end

function GameView:SelectInventorySlot(slot: number)
	if slot < 1 or slot > #self.inventoryItems then
		return
	end
	self.selectedInventorySlot = slot
	self:_updateInventory(self.currentState)
	local button = self.hotbar:FindFirstChild("Slot_" .. tostring(slot))
	if button and button:IsA("GuiButton") and button.Active then
		GuiService.SelectedObject = button
	end
end

function GameView:GetInventorySlotCount(): number
	return math.min(#self.inventoryItems, 15)
end

function GameView:ShowInteraction(actionText: string, objectText: string, inputText: string)
	self.interactionKey.Text = inputText
	self.interactionText.Text = actionText .. if objectText ~= "" then "\n" .. objectText else ""
	self.interaction.Visible = true
end

function GameView:HideInteraction()
	self.interaction.Visible = false
end

function GameView:Announce(payload: any)
	if self.destroyed or type(payload) ~= "table" then
		return
	end
	self.announcementToken += 1
	local token = self.announcementToken
	local kind = readString(payload, "kind", "Info")
	self.announcementTitle.Text = string.upper(readString(payload, "title", "CAMP NOTICE"))
	self.announcementBody.Text = readString(payload, "message", "")
	self.announcement.BackgroundColor3 = if kind == "Danger"
		then Theme.Colors.Danger
		elseif kind == "Warning" then Theme.Colors.Amber
		elseif kind == "Success" then Theme.Colors.Success
		else Theme.Colors.Panel
	local reducedMotion = self.settingsValues.reducedMotion == true
	if reducedMotion then
		self.announcement.Position = UDim2.new(0.5, 0, 0, 16)
	else
		TweenService:Create(
			self.announcement,
			TweenInfo.new(0.25, Enum.EasingStyle.Back),
			{ Position = UDim2.new(0.5, 0, 0, 16) }
		):Play()
	end
	local duration = math.clamp(readNumber(payload, "duration", 4), 1, 12)
	task.delay(duration, function()
		if not self.destroyed and token == self.announcementToken and self.announcement.Parent then
			if reducedMotion then
				self.announcement.Position = UDim2.new(0.5, 0, 0, -110)
			else
				TweenService:Create(
					self.announcement,
					TweenInfo.new(0.2),
					{ Position = UDim2.new(0.5, 0, 0, -110) }
				):Play()
			end
		end
	end)
end

function GameView:Notify(titleText: string, bodyText: string, kind: string)
	if self.destroyed then
		return
	end
	local existingToasts = self.toastList:GetChildren()
	local toastCount = 0
	for _, child in existingToasts do
		if child:IsA("GuiObject") and child.Name == "Toast" then
			toastCount += 1
			if toastCount > 3 then
				Motion.Cancel(child)
				child:Destroy()
			end
		end
	end
	local toast = Components.Panel(self.toastList, "Toast")
	toast.Size = UDim2.new(1, 0, 0, 70)
	toast.BackgroundColor3 = if kind == "Danger"
		then Theme.Colors.Danger
		elseif kind == "Warning" then Theme.Colors.Amber
		elseif kind == "Success" then Theme.Colors.Success
		else Theme.Colors.PanelRaised
	local title = Components.Label(toast, "Title", titleText, 14, Enum.Font.GothamBold)
	title.Position = UDim2.fromOffset(12, 7)
	title.Size = UDim2.new(1, -24, 0, 24)
	local body = Components.Label(toast, "Body", bodyText, 12)
	body.Position = UDim2.fromOffset(12, 31)
	body.Size = UDim2.new(1, -24, 0, 32)
	if kind == "Danger" or kind == "Warning" then
		Components.PlayUISound("error")
	elseif kind == "Success" then
		Components.PlayUISound("success")
	else
		Components.PlayUISound("toast")
	end
	task.defer(function()
		if toast.Parent then
			Motion.SlideUp(toast)
		end
	end)
	task.delay(4.5, function()
		if toast.Parent then
			Motion.FadeOut(toast, {
				onComplete = function(_completed: boolean)
					if toast.Parent then
						toast:Destroy()
					end
				end,
			})
		end
	end)
end

function GameView:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.announcementToken += 1
	self.lastActionControl = nil
	for _, connection in self.layoutConnections do
		connection:Disconnect()
	end
	table.clear(self.layoutConnections)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.root) then
		GuiService.SelectedObject = nil
	end
	if self.root.Parent then
		self.root:Destroy()
	end
	table.clear(self.inventoryItems)
end

return table.freeze(GameView)
