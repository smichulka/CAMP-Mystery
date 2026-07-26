--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent:WaitForChild("Components"))
local Motion = require(script.Parent:WaitForChild("Motion"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local SharedConfig = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local CosmeticCatalog = require(SharedConfig:WaitForChild("CosmeticCatalog"))
local InterviewTopics = require(SharedConfig:WaitForChild("InterviewTopics"))
local PhaseTitles = require(SharedConfig:WaitForChild("PhaseTitles"))
local TipCatalog = require(SharedConfig:WaitForChild("TipCatalog"))
local UpgradeCatalog = require(SharedConfig:WaitForChild("UpgradeCatalog"))

type ActionHandler = (action: string, payload: any) -> (boolean, string?)
type ImageResolver = (key: string) -> string?

type GameViewState = {
	screenGui: ScreenGui,
	root: Frame,
	vignette: ImageLabel,
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
	ghostBadge: TextLabel,
	ghostBadgePulse: Tween?,
	ghostBadgeReducedMotion: boolean,
	ghostMode: boolean,
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
	voteRevealList: ScrollingFrame,
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
	lobbyRoster: ScrollingFrame,
	lobbyTip: Frame,
	lobbyTipCategory: TextLabel,
	lobbyTipBody: TextLabel,
	lobbyCountdown: TextLabel,
	lobbyCountdownScale: UIScale,
	lobbyTipIndex: number,
	lobbyTipChangedAt: number,
	lobbyRosterSignature: string,
	lobbyReadyStates: { [number]: boolean },
	lobbyFillSignature: string,
	lobbyCountdownSecond: number,
	lobbyWasVisible: boolean,
	announcement: Frame,
	announcementTitle: TextLabel,
	announcementBody: TextLabel,
	toastList: Frame,
	evidenceCeremony: Frame?,
	evidenceCeremonySkip: RBXScriptConnection?,
	evidenceCeremonyToken: number,
	roleRevealToken: number,
	roleRevealOverlay: CanvasGroup?,
	roleRevealSkip: RBXScriptConnection?,
	roleRevealActive: boolean,
	phaseTitleToken: number,
	phaseTitleBand: CanvasGroup?,
	phaseTitleActive: boolean,
	winRevealToken: number,
	winRevealOverlay: CanvasGroup?,
	winRevealSkip: RBXScriptConnection?,
	winRevealActive: boolean,
	voteRevealToken: number,
	voteRevealOwnsResults: boolean,
	voteConfetti: Frame?,
	currentState: any,
	legacyRound: any,
	legacyPlayer: any,
	currentVoteSignature: string,
	evidenceStatuses: { [string]: string },
	selectedInventorySlot: number,
	inventoryItems: { any },
	requestSequence: number,
	settingsValues: { [string]: any },
	audioSettingCallback: ((key: string, value: any) -> ())?,
	layoutConnections: { RBXScriptConnection },
	announcementToken: number,
	lastActionControl: GuiObject?,
	interviewPickerToken: number,
	interviewPickerSheet: Frame?,
	counselorDialogueToken: number,
	counselorDialoguePanel: Frame?,
	lastCooldownText: string?,
	roleActionBaseText: string,
	lastAnimatedXP: number,
	lastAnimatedTokens: number,
	rewardAnimationToken: number,
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

local VOLUME_SETTING_KEYS: { [string]: boolean } = {
	masterVolume = true,
	musicVolume = true,
	ambienceVolume = true,
	effectsVolume = true,
	uiVolume = true,
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
		local staggerTarget: GuiObject? = nil
		if modal.Name == "EvidenceNotebook" then
			local evidenceList = modal:FindFirstChild("EvidenceList")
			if evidenceList and evidenceList:IsA("GuiObject") then
				if modal:GetAttribute("SuppressNextStagger") == true then
					modal:SetAttribute("SuppressNextStagger", false)
				else
					staggerTarget = evidenceList
					Motion.StaggerChildren(evidenceList, {
						preset = "SlideUp",
					})
				end
			end
		elseif modal.Name == "CampfireVote" then
			local voteList = modal:FindFirstChild("Suspects")
			if voteList and voteList:IsA("GuiObject") then
				staggerTarget = voteList
			end
		end
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
		if staggerTarget and modal.Name == "CampfireVote" then
			local list = staggerTarget
			task.defer(function()
				if modal:GetAttribute("MotionTargetVisible") == true then
					Motion.StaggerChildren(list, {
						preset = "SlideUp",
					})
				end
			end)
		end
	elseif modal.Visible then
		if selected and selected:IsDescendantOf(modal) then
			GuiService.SelectedObject = nil
		end
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

	local vignette = Instance.new("ImageLabel")
	vignette.Name = "Vignette"
	vignette.AnchorPoint = Vector2.new(0.5, 0.5)
	vignette.Position = UDim2.fromScale(0.5, 0.5)
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.Image = if imageResolver then imageResolver("ui_vignette") or "" else ""
	vignette.ImageTransparency = 1
	vignette.ScaleType = Enum.ScaleType.Stretch
	vignette.Parent = root

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root

	local top = Components.Panel(root, "TopStatus")
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.fromScale(0.5, 0.018)
	top.Size = UDim2.fromOffset(540, 96)

	local phaseLabel = Components.Label(
		top,
		"Phase",
		"",
		Theme.Typography.DisplaySize,
		Theme.Typography.DisplayFont
	)
	phaseLabel.Position = UDim2.fromOffset(18, 10)
	phaseLabel.Size = UDim2.new(1, -106, 0, 32)
	phaseLabel.TextXAlignment = Enum.TextXAlignment.Center
	Components.SetLetterspacedText(phaseLabel, "WAITING AT CAMP")
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
	local roleTitle = Components.Label(
		mission,
		"RoleTitle",
		"ROLE PENDING",
		Theme.Typography.HeadingSize,
		Theme.Typography.HeadingFont
	)
	roleTitle.Font = Theme.Typography.HeadingFont
	roleTitle.TextSize = Theme.Typography.HeadingSize
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
	local roleDescription = Components.Label(
		mission,
		"RoleDescription",
		"Waiting for your private role.",
		Theme.Typography.BodySize,
		Theme.Typography.BodyFont
	)
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

	local ghostBadge = Components.Label(
		root,
		"GhostModeBadge",
		"GHOST MODE",
		Theme.Typography.CaptionSize,
		Theme.Typography.CaptionFont
	)
	ghostBadge.AnchorPoint = Vector2.new(1, 0)
	ghostBadge.Position = UDim2.new(1, -18, 0, 122)
	ghostBadge.Size = UDim2.fromOffset(132, 30)
	ghostBadge.BackgroundColor3 = Theme.Colors.Panel
	ghostBadge.BackgroundTransparency = 0.08
	ghostBadge.TextColor3 = Theme.Colors.Ghost
	ghostBadge.TextXAlignment = Enum.TextXAlignment.Center
	ghostBadge.Visible = false
	ghostBadge.ZIndex = 35
	Components.Corner(ghostBadge, 15)
	Components.Stroke(ghostBadge, Theme.Colors.Ghost, 1)

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
	notebook.BackgroundColor3 = Theme.Notebook.PageColor
	notebook.BackgroundTransparency = 0
	notebook.ClipsDescendants = true
	local settings = makeModal(root, "Settings", UDim2.new(0.58, 0, 0.76, 0))
	local voteModal = makeModal(root, "CampfireVote", UDim2.new(0.46, 0, 0.64, 0))
	local resultModal = makeModal(root, "RoundResults", UDim2.new(0.52, 0, 0.5, 0))
	local targetModal = makeModal(root, "ActionTarget", UDim2.new(0.4, 0, 0.62, 0))
	local progression = makeModal(root, "Progression", UDim2.new(0.72, 0, 0.78, 0))

	local self: GameView = setmetatable({
		screenGui = screen,
		root = root,
		vignette = vignette,
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
		ghostBadge = ghostBadge,
		ghostBadgePulse = nil,
		ghostBadgeReducedMotion = false,
		ghostMode = false,
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
		voteRevealList = nil :: any,
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
		lobbyRoster = nil :: any,
		lobbyTip = nil :: any,
		lobbyTipCategory = nil :: any,
		lobbyTipBody = nil :: any,
		lobbyCountdown = nil :: any,
		lobbyCountdownScale = nil :: any,
		lobbyTipIndex = 1,
		lobbyTipChangedAt = Workspace:GetServerTimeNow(),
		lobbyRosterSignature = "",
		lobbyReadyStates = {},
		lobbyFillSignature = "",
		lobbyCountdownSecond = -1,
		lobbyWasVisible = false,
		announcement = nil :: any,
		announcementTitle = nil :: any,
		announcementBody = nil :: any,
		toastList = nil :: any,
		evidenceCeremony = nil,
		evidenceCeremonySkip = nil,
		evidenceCeremonyToken = 0,
		roleRevealToken = 0,
		roleRevealOverlay = nil,
		roleRevealSkip = nil,
		roleRevealActive = false,
		phaseTitleToken = 0,
		phaseTitleBand = nil,
		phaseTitleActive = false,
		winRevealToken = 0,
		winRevealOverlay = nil,
		winRevealSkip = nil,
		winRevealActive = false,
		voteRevealToken = 0,
		voteRevealOwnsResults = false,
		voteConfetti = nil,
		currentState = nil,
		legacyRound = nil,
		legacyPlayer = nil,
		currentVoteSignature = "",
		evidenceStatuses = {},
		selectedInventorySlot = 0,
		inventoryItems = {},
		requestSequence = 0,
		settingsValues = {},
		audioSettingCallback = nil,
		layoutConnections = {},
		announcementToken = 0,
		lastActionControl = nil,
		interviewPickerToken = 0,
		interviewPickerSheet = nil,
		counselorDialogueToken = 0,
		counselorDialoguePanel = nil,
		lastCooldownText = nil,
		roleActionBaseText = "ABILITY UNAVAILABLE",
		lastAnimatedXP = -1,
		lastAnimatedTokens = -1,
		rewardAnimationToken = 0,
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
	local rules = Instance.new("Frame")
	rules.Name = "NotebookRules"
	rules.Position = UDim2.fromOffset(0, 58)
	rules.Size = UDim2.new(1, 0, 1, -58)
	rules.BackgroundTransparency = 1
	rules.BorderSizePixel = 0
	rules.ClipsDescendants = true
	rules.ZIndex = 0
	rules.Parent = self.notebook
	for index = 0, 32 do
		local line = Instance.new("Frame")
		line.Name = "Rule_" .. tostring(index + 1)
		line.Position = UDim2.fromOffset(
			14,
			index * Theme.Notebook.LineHeight
		)
		line.Size = UDim2.new(1, -28, 0, 1)
		line.BackgroundColor3 = Theme.Notebook.PageLines
		line.BackgroundTransparency = 0.58
		line.BorderSizePixel = 0
		line.ZIndex = 0
		line.Parent = rules
	end
	local header = self.notebook:FindFirstChild("Header")
	if header and header:IsA("GuiObject") then
		header.ZIndex = 3
		local headerTitle = header:FindFirstChild("Title")
		if headerTitle and headerTitle:IsA("TextLabel") then
			headerTitle.TextColor3 = Theme.Notebook.InkColor
		end
	end
	local summary = Components.Label(
		self.notebook,
		"Summary",
		"Clues are separated from monster identification evidence.",
		14
	)
	summary.Position = UDim2.fromOffset(20, 58)
	summary.Size = UDim2.new(1, -40, 0, 48)
	summary.TextColor3 = Theme.Notebook.InkMuted
	summary.ZIndex = 2
	self.evidenceSummary = summary

	local list = Instance.new("ScrollingFrame")
	list.Name = "EvidenceList"
	list.Position = UDim2.fromOffset(18, 108)
	list.Size = UDim2.new(1, -36, 1, -126)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = Theme.Notebook.InkMuted
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.ZIndex = 2
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
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.new(1, -48, 0, 42)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextColor3 = Theme.Colors.Gold

	local voteRevealList = Instance.new("ScrollingFrame")
	voteRevealList.Name = "VoteRevealList"
	voteRevealList.Position = UDim2.fromOffset(24, 60)
	voteRevealList.Size = UDim2.new(1, -48, 0, 112)
	voteRevealList.BackgroundTransparency = 1
	voteRevealList.BorderSizePixel = 0
	voteRevealList.CanvasSize = UDim2.fromOffset(0, 0)
	voteRevealList.ScrollBarThickness = 3
	voteRevealList.Visible = false
	voteRevealList.Parent = self.resultModal
	local voteRevealLayout = Components.List(voteRevealList, 4)
	voteRevealLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	addCanvasSizing(voteRevealList, voteRevealLayout)

	local body = Components.Label(self.resultModal, "Body", "", 17)
	body.Position = UDim2.fromOffset(28, 176)
	body.Size = UDim2.new(1, -56, 0, 46)
	body.TextXAlignment = Enum.TextXAlignment.Center
	local rewards = Components.Label(self.resultModal, "Rewards", "", 15, Enum.Font.GothamBold)
	rewards.Position = UDim2.fromOffset(28, 222)
	rewards.Size = UDim2.new(1, -56, 0, 38)
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
	self.voteRevealList = voteRevealList
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
	description.Font = Theme.Typography.CaptionFont
	description.TextSize = Theme.Typography.CaptionSize
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
	title.Font = Theme.Typography.CaptionFont
	title.TextSize = Theme.Typography.CaptionSize
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
	if control and control.Parent then
		if accepted then
			Motion.PopIn(control, { duration = 0.12 })
			Components.PlayUISound("success")
		else
			Motion.Shake(control)
		end
	end
	self.lastActionControl = nil
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
	local title = Components.Label(
		banner,
		"Title",
		"",
		Theme.Typography.DisplaySize,
		Theme.Typography.DisplayFont
	)
	title.Font = Theme.Typography.DisplayFont
	title.TextSize = Theme.Typography.DisplaySize
	title.Position = UDim2.fromOffset(18, 10)
	title.Size = UDim2.new(1, -36, 0, 28)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 31
	local body = Components.Label(
		banner,
		"Body",
		"",
		Theme.Typography.BodySize,
		Theme.Typography.BodyFont
	)
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
	lobby.AnchorPoint = Vector2.new(0.5, 0.5)
	lobby.Position = UDim2.fromScale(0.5, 0.56)
	lobby.Size = UDim2.fromOffset(520, 520)
	local text = Components.Label(
		lobby,
		"LobbyText",
		"CAMPERS ARE ARRIVING",
		Theme.Typography.HeadingSize,
		Theme.Typography.HeadingFont
	)
	text.Position = UDim2.fromOffset(18, 10)
	text.Size = UDim2.new(1, -36, 0, 34)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextColor3 = Theme.Colors.Gold

	local roster = Instance.new("ScrollingFrame")
	roster.Name = "Roster"
	roster.Position = UDim2.fromOffset(18, 50)
	roster.Size = UDim2.new(1, -36, 0, 254)
	roster.BackgroundTransparency = 1
	roster.BorderSizePixel = 0
	roster.CanvasSize = UDim2.fromOffset(0, 0)
	roster.ScrollBarThickness = 4
	roster.Parent = lobby
	local rosterLayout = Components.List(roster, 6)
	addCanvasSizing(roster, rosterLayout)

	local tip = Components.Panel(lobby, "CampTip")
	tip.Position = UDim2.fromOffset(18, 312)
	tip.Size = UDim2.new(1, -36, 0, 118)
	tip.BackgroundColor3 = Theme.Colors.PanelRaised
	local tipCategory = Components.Label(
		tip,
		"Category",
		"",
		Theme.Typography.CaptionSize,
		Theme.Typography.CaptionFont
	)
	tipCategory.Position = UDim2.fromOffset(14, 9)
	tipCategory.Size = UDim2.new(1, -28, 0, 20)
	tipCategory.TextColor3 = Theme.Colors.Gold
	local tipBody = Components.Label(
		tip,
		"Body",
		"",
		Theme.Typography.BodySize,
		Theme.Typography.BodyFont
	)
	tipBody.Position = UDim2.fromOffset(14, 31)
	tipBody.Size = UDim2.new(1, -28, 0, 74)
	tipBody.TextWrapped = true
	tipBody.TextYAlignment = Enum.TextYAlignment.Top

	local ready = Components.Button(lobby, {
		name = "Ready",
		text = "READY UP",
		size = UDim2.fromOffset(290, 54),
		position = UDim2.fromOffset(18, 446),
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
		size = UDim2.fromOffset(176, 54),
		position = UDim2.new(1, -194, 0, 446),
		color = Theme.Colors.Gold,
	})
	progression.TextColor3 = Theme.Colors.Background
	progression.Activated:Connect(function()
		self:ToggleProgression()
	end)

	local countdown = Components.Label(
		self.root,
		"LobbyCountdown",
		"",
		Theme.Typography.DisplaySize * 2,
		Theme.Typography.DisplayFont
	)
	countdown.AnchorPoint = Vector2.new(0.5, 0.5)
	countdown.Position = UDim2.fromScale(0.5, 0.26)
	countdown.Size = UDim2.fromOffset(220, 90)
	countdown.TextXAlignment = Enum.TextXAlignment.Center
	countdown.TextColor3 = Theme.Colors.Gold
	countdown.Visible = false
	countdown.ZIndex = 45
	local countdownScale = Instance.new("UIScale")
	countdownScale.Scale = 1
	countdownScale.Parent = countdown

	self.readyButton = ready
	self.lobbyText = text
	self.lobbyRoster = roster
	self.lobbyTip = tip
	self.lobbyTipCategory = tipCategory
	self.lobbyTipBody = tipBody
	self.lobbyCountdown = countdown
	self.lobbyCountdownScale = countdownScale
	self.lobbyPanel = lobby
	local firstTip = TipCatalog.definitions[1]
	if firstTip then
		tipCategory.Text = firstTip.category
		tipBody.Text = firstTip.body
	end
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
	if self.ghostMode then
		return
	end
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

function GameView:SetAudioSettingCallback(
	callback: ((key: string, value: any) -> ())?
)
	self.audioSettingCallback = callback
end

function GameView:_setSetting(key: string, value: any)
	self.settingsValues[key] = value
	if key == "reducedMotion" and type(value) == "boolean" then
		self.root:SetAttribute("ReducedMotion", value)
	end
	local audioCallback = self.audioSettingCallback
	if VOLUME_SETTING_KEYS[key] and audioCallback then
		audioCallback(key, value)
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

function GameView:_rebuildLobbyRoster(lobby: any)
	local players = asTable(lobby.players)
	local target = math.max(#players, math.floor(readNumber(lobby, "standardTarget", 10)))
	local signatureParts: { string } = { tostring(target) }
	for _, entry in players do
		if type(entry) == "table" then
			table.insert(signatureParts, string.format(
				"%d:%s:%s",
				math.floor(readNumber(entry, "userId", 0)),
				readString(entry, "displayName", ""),
				readString(entry, "status", "Waiting")
			))
		end
	end
	local signature = table.concat(signatureParts, "|")
	if signature == self.lobbyRosterSignature then
		return
	end
	local previousSignature = self.lobbyRosterSignature
	self.lobbyRosterSignature = signature
	Components.ClearGenerated(self.lobbyRoster)
	local nextReadyStates: { [number]: boolean } = {}
	for index = 1, target do
		local entry = players[index]
		local card = Components.Panel(self.lobbyRoster, "RosterCard_" .. tostring(index))
		card:SetAttribute("Generated", true)
		card.LayoutOrder = index
		card.Size = UDim2.new(1, -8, 0, 48)
		card.BackgroundColor3 = Theme.Notebook.PageColor
		card.BackgroundTransparency = 0
		local name = Components.Label(
			card,
			"DisplayName",
			"Waiting for players...",
			Theme.Typography.BodySize,
			Theme.Typography.BodyFont
		)
		name.Position = UDim2.fromOffset(16, 0)
		name.Size = UDim2.new(1, -58, 1, 0)
		name.TextColor3 = Theme.Notebook.InkMuted
		local dot = Instance.new("Frame")
		dot.Name = "ReadyDot"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(1, -24, 0.5, 0)
		dot.Size = UDim2.fromOffset(12, 12)
		dot.BackgroundColor3 = Theme.Colors.Border
		dot.BorderSizePixel = 0
		dot.Parent = card
		Components.Corner(dot, 6)
		if type(entry) == "table" then
			local userId = math.floor(readNumber(entry, "userId", 0))
			local isReady = readBoolean(entry, "isReady", false)
				or readString(entry, "status", "Waiting") == "Locked"
			nextReadyStates[userId] = isReady
			name.Text = readString(entry, "displayName", "Camper")
			name.TextColor3 = Theme.Notebook.InkColor
			dot.BackgroundColor3 = if isReady then Theme.Colors.Success else Theme.Colors.Border
			if isReady and self.lobbyReadyStates[userId] ~= true then
				dot.BackgroundColor3 = Theme.Colors.Gold
				Motion.PopIn(card)
				if self.settingsValues.reducedMotion ~= true then
					TweenService:Create(
						dot,
						TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ BackgroundColor3 = Theme.Colors.Success, Size = UDim2.fromOffset(16, 16) }
					):Play()
					task.delay(0.42, function()
						if dot.Parent then
							TweenService:Create(
								dot,
								TweenInfo.new(0.16),
								{ Size = UDim2.fromOffset(12, 12) }
							):Play()
						end
					end)
				else
					dot.BackgroundColor3 = Theme.Colors.Success
				end
			end
		end
	end
	self.lobbyReadyStates = nextReadyStates
	if previousSignature ~= "" then
		Motion.StaggerChildren(self.lobbyRoster, {
			preset = "PopIn",
		})
	end
end

function GameView:_shimmerLobbyRoster()
	local reducedMotion = self.settingsValues.reducedMotion == true
	for _, child in self.lobbyRoster:GetChildren() do
		if child:IsA("Frame") and child:GetAttribute("Generated") == true then
			if reducedMotion then
				child.BackgroundColor3 = Theme.Notebook.PageColor
			else
				local gold = TweenService:Create(
					child,
					TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundColor3 = Theme.Colors.Gold }
				)
				local cream = TweenService:Create(
					child,
					TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
					{ BackgroundColor3 = Theme.Notebook.PageColor }
				)
				gold.Completed:Connect(function(playbackState: Enum.PlaybackState)
					if playbackState == Enum.PlaybackState.Completed and child.Parent then
						cream:Play()
					end
				end)
				gold:Play()
			end
		end
	end
end

function GameView:_updateLobby(state: any, phase: string)
	local lobby = if type(state) == "table" then state.lobby else nil
	local parent = self.readyButton.Parent
	if not parent or not parent:IsA("GuiObject") then
		return
	end
	local inLobby = phase == "Lobby"
	if inLobby then
		Motion.Cancel(parent)
		parent.Visible = true
		parent.BackgroundTransparency = Theme.PanelTransparency
	elseif self.lobbyWasVisible and parent.Visible then
		Motion.FadeOut(parent, {
			duration = 0.4,
			onComplete = function(_completed: boolean)
				if parent.Parent and not self.lobbyWasVisible then
					parent.Visible = false
				end
			end,
		})
	else
		parent.Visible = false
	end
	self.lobbyWasVisible = inLobby
	self.healthPanel.Visible = phase ~= "Lobby"
	self.hotbar.Visible = phase ~= "Lobby"
	if not inLobby then
		self.lobbyCountdown.Visible = false
		self.lobbyCountdownSecond = -1
		return
	end
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
	self:_rebuildLobbyRoster(lobby)
	local isReady = false
	for _, entry in players do
		if type(entry) == "table" and entry.userId == Players.LocalPlayer.UserId then
			isReady = readBoolean(entry, "isReady", false)
			break
		end
	end
	self.readyButton.Text = if isReady then "CANCEL READY" else "READY UP"
	Components.SetButtonEnabled(self.readyButton, true)
	local fillStartedAt = readNumber(lobby, "fillStartedAt", 0)
	local fillSignature = if fillStartedAt > 0 then tostring(fillStartedAt) else ""
	if fillSignature ~= "" and fillSignature ~= self.lobbyFillSignature then
		self:_shimmerLobbyRoster()
	end
	self.lobbyFillSignature = fillSignature
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
			Components.SetButtonEnabled(button, not self.ghostMode)
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
	if self.ghostMode or type(item) ~= "table" then
		return
	end
	local instanceId = readString(item, "instanceId", "")
	if instanceId == "" then
		return
	end
	if not readBoolean(item, "equipped", false) then
		self:_send("EquipItem", { instanceId = instanceId }, control)
		if control and control.Parent then
			Motion.PopIn(control, { duration = 0.14 })
		end
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

function GameView:_dismissInterviewPicker(immediate: boolean?)
	self.interviewPickerToken += 1
	local sheet = self.interviewPickerSheet
	self.interviewPickerSheet = nil
	if not sheet then
		return
	end
	local backdrop = sheet.Parent
	Motion.Cancel(sheet)
	if immediate == true or Motion.IsReducedMotion(sheet) then
		if backdrop and backdrop.Parent then
			backdrop:Destroy()
		end
		return
	end
	Motion.SlideDown(sheet, {
		duration = 0.2,
		distance = 80,
		onComplete = function(_completed: boolean)
			if backdrop and backdrop.Parent then
				backdrop:Destroy()
			end
		end,
	})
end

function GameView:ShowInterviewTopicPicker(
	counselorId: string,
	name: string,
	isWitness: boolean
)
	if self.destroyed then
		return
	end
	self:_dismissInterviewPicker(true)
	local token = self.interviewPickerToken

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "InterviewTopicBackdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.Colors.Black
	backdrop.BackgroundTransparency = 0.55
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Active = true
	backdrop.Selectable = false
	backdrop.ZIndex = 60
	backdrop.Parent = self.root

	local sheet = Components.Panel(backdrop, "InterviewTopicPicker")
	sheet.AnchorPoint = Vector2.new(0.5, 1)
	sheet.Position = UDim2.new(0.5, 0, 1, -80)
	sheet.Size = UDim2.fromOffset(320, 220)
	sheet.BackgroundTransparency = 0
	sheet.ZIndex = 61
	self.interviewPickerSheet = sheet

	local counselorName = Components.Label(
		sheet,
		"CounselorName",
		if name ~= "" then name else "Counselor",
		Theme.Typography.HeadingSize,
		Theme.Typography.HeadingFont
	)
	counselorName.Position = UDim2.fromOffset(8, 4)
	counselorName.Size = UDim2.new(1, -16, 0, 22)
	counselorName.TextColor3 = Theme.Colors.Gold
	counselorName.TextXAlignment = Enum.TextXAlignment.Center
	counselorName.ZIndex = 62

	local prompt = Components.Label(
		sheet,
		"Prompt",
		"What do you want to ask?",
		Theme.Typography.CaptionSize,
		Theme.Typography.CaptionFont
	)
	prompt.Position = UDim2.fromOffset(8, 25)
	prompt.Size = UDim2.new(1, -16, 0, 17)
	prompt.TextColor3 = Theme.Colors.TextMuted
	prompt.TextXAlignment = Enum.TextXAlignment.Center
	prompt.ZIndex = 62

	for index, entry in InterviewTopics.definitions do
		local topic = entry.topic
		local button = Components.Button(sheet, {
			name = "Topic_" .. topic,
			text = "",
			size = UDim2.new(1, -16, 0, 36),
			position = UDim2.fromOffset(8, 45 + (index - 1) * 41),
			color = if isWitness and entry.witnessHighlight
				then Theme.Colors.Amber
				else Theme.Colors.Panel,
		})
		button.ZIndex = 62
		local label = Components.Label(
			button,
			"Label",
			entry.label,
			Theme.Typography.CaptionSize,
			Theme.Typography.HeadingFont
		)
		label.Position = UDim2.fromOffset(8, 1)
		label.Size = UDim2.new(1, -16, 0, 17)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.ZIndex = 63
		local hint = Components.Label(
			button,
			"Hint",
			entry.hint,
			Theme.Typography.CaptionSize,
			Theme.Typography.CaptionFont
		)
		hint.Position = UDim2.fromOffset(8, 17)
		hint.Size = UDim2.new(1, -16, 0, 16)
		hint.TextColor3 = Theme.Colors.TextMuted
		hint.TextXAlignment = Enum.TextXAlignment.Center
		hint.ZIndex = 63
		button.Activated:Connect(function()
			if token ~= self.interviewPickerToken then
				return
			end
			self:_dismissInterviewPicker()
			self:_send("InterviewCounselor", {
				counselorId = counselorId,
				topic = topic,
			}, button)
		end)
	end

	backdrop.Activated:Connect(function()
		if token == self.interviewPickerToken then
			self:_dismissInterviewPicker()
		end
	end)

	if not Motion.IsReducedMotion(sheet) then
		Motion.SlideUp(sheet, {
			duration = 0.25,
			distance = 80,
		})
	end
end

function GameView:_dismissCounselorDialogue(immediate: boolean?)
	self.counselorDialogueToken += 1
	local panel = self.counselorDialoguePanel
	self.counselorDialoguePanel = nil
	if not panel then
		return
	end
	Motion.Cancel(panel)
	if immediate == true or Motion.IsReducedMotion(panel) then
		if panel.Parent then
			panel:Destroy()
		end
		return
	end
	Motion.FadeOut(panel, {
		onComplete = function(_completed: boolean)
			if panel.Parent then
				panel:Destroy()
			end
		end,
	})
end

function GameView:ShowCounselorDialogue(
	counselorName: string,
	topic: string,
	text: string
)
	if self.destroyed then
		return
	end
	self:_dismissCounselorDialogue(true)
	local token = self.counselorDialogueToken
	local bodyHeight = math.clamp(
		TextService:GetTextSize(
			text,
			Theme.Typography.BodySize,
			Theme.Typography.BodyFont,
			Vector2.new(252, 116)
		).Y,
		48,
		116
	)
	local panelHeight = math.clamp(28 + bodyHeight + 16, 80, 160)

	local panel = Instance.new("Frame")
	panel.Name = "CounselorDialoguePanel"
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 16, 1, -80)
	panel.Size = UDim2.fromOffset(280, panelHeight)
	panel.BackgroundColor3 = Theme.Notebook.PageColor
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.Active = true
	panel.ClipsDescendants = false
	panel.ZIndex = 70
	panel.Parent = self.root

	local shadow = Instance.new("Frame")
	shadow.Name = "DropShadow"
	shadow.Position = UDim2.fromOffset(2, 2)
	shadow.Size = UDim2.new(1, -2, 1, -2)
	shadow.BackgroundColor3 = Theme.Colors.Black
	shadow.BackgroundTransparency = 0.78
	shadow.BorderSizePixel = 0
	shadow.ZIndex = panel.ZIndex
	shadow.Parent = panel
	Components.Corner(shadow, Theme.SmallCornerRadius)

	local paper = Instance.new("Frame")
	paper.Name = "Paper"
	paper.Size = UDim2.new(1, -2, 1, -2)
	paper.BackgroundColor3 = Theme.Notebook.PageColor
	paper.BackgroundTransparency = 0
	paper.BorderSizePixel = 0
	paper.ZIndex = panel.ZIndex + 1
	paper.Parent = panel
	Components.Corner(paper, Theme.SmallCornerRadius)

	local strip = Instance.new("Frame")
	strip.Name = "AccentStrip"
	strip.Size = UDim2.new(0, 4, 1, 0)
	strip.BackgroundColor3 = Theme.Colors.Amber
	strip.BorderSizePixel = 0
	strip.ZIndex = paper.ZIndex + 1
	strip.Parent = paper
	Components.Corner(strip, Theme.SmallCornerRadius)

	local nameLabel = Components.Label(
		paper,
		"CounselorName",
		if counselorName ~= "" then counselorName else "Counselor",
		Theme.Typography.CaptionSize,
		Theme.Typography.HeadingFont
	)
	nameLabel.Position = UDim2.fromOffset(12, 4)
	nameLabel.Size = UDim2.new(0.58, -12, 0, 20)
	nameLabel.TextColor3 = Theme.Notebook.InkColor
	nameLabel.ZIndex = paper.ZIndex + 2

	local topicLabel = Components.Label(
		paper,
		"Topic",
		string.upper(topic),
		Theme.Typography.CaptionSize,
		Theme.Typography.CaptionFont
	)
	topicLabel.AnchorPoint = Vector2.new(1, 0)
	topicLabel.Position = UDim2.new(1, -10, 0, 4)
	topicLabel.Size = UDim2.new(0.42, -6, 0, 20)
	topicLabel.TextColor3 = Theme.Notebook.InkMuted
	topicLabel.TextXAlignment = Enum.TextXAlignment.Right
	topicLabel.ZIndex = paper.ZIndex + 2

	local body = Components.Label(
		paper,
		"Dialogue",
		text,
		Theme.Typography.BodySize,
		Theme.Typography.BodyFont
	)
	body.Position = UDim2.fromOffset(12, 28)
	body.Size = UDim2.new(1, -24, 0, bodyHeight)
	body.TextColor3 = Theme.Notebook.InkColor
	body.TextWrapped = true
	body.TextTruncate = Enum.TextTruncate.AtEnd
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.ZIndex = paper.ZIndex + 2

	self.counselorDialoguePanel = panel
	panel.InputBegan:Connect(function(input: InputObject)
		if token ~= self.counselorDialogueToken then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self:_dismissCounselorDialogue()
		end
	end)

	local reducedMotion = Motion.IsReducedMotion(panel)
	if not reducedMotion then
		Motion.SlideUp(panel, {
			duration = 0.25,
		})
	end
	task.delay(if reducedMotion then 3 else 5, function()
		if not self.destroyed
			and token == self.counselorDialogueToken
			and panel.Parent
		then
			self:_dismissCounselorDialogue()
		end
	end)
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
	local nextEvidenceStatuses: { [string]: string } = {}
	local function addEvidence(record: any, channel: string)
		if type(record) ~= "table" then
			return
		end
		local evidenceId = readString(record, "evidenceId", readString(record, "id", ""))
		local displayName = readString(record, "displayName", "Unknown clue")
		local verification = readString(record, "verificationState", "Unverified")
		local status = if verification == "VerifiedReal"
			then "Confirmed"
			elseif verification == "VerifiedFake" then "Contradicted"
			else "Unconfirmed"
		local evidenceKey = if evidenceId ~= ""
			then evidenceId
			else channel .. ":" .. displayName
		local previousStatus = self.evidenceStatuses[evidenceKey]
		nextEvidenceStatuses[evidenceKey] = status
		local finder = readString(record, "foundBy", "")
		local discovery = record.discovery
		if type(discovery) == "table" then
			finder = readString(discovery, "discoveredByDisplayName", finder)
		end
		local card = Components.EvidenceCard(self.evidenceList, {
			name = displayName,
			description = readString(record, "description", "No description recorded."),
			status = status,
			previousStatus = previousStatus,
			channel = channel,
			footer = (if finder ~= "" then "Found by " .. finder .. "  |  " else "")
				.. string.upper(status),
			iconAsset = self.resolveImage(
				if channel == "MONSTER" then "Evidence_Monster" else "Evidence_Culprit"
			),
		})
		card.Size = UDim2.new(1, -8, 0, Theme.Notebook.CardHeight)
		local verifyEnabled = self:_available(state, "VerifyEvidence")
		local noteEnabled = self:_available(state, "AddEvidenceNote")
		local verify = Components.Button(card, {
			name = "Verify",
			text = "VERIFY",
			size = UDim2.fromOffset(104, 30),
			position = UDim2.new(1, -220, 1, -36),
			color = Theme.Colors.Success,
		})
		verify.ZIndex = card.ZIndex + 5
		local note = Components.Button(card, {
			name = "Note",
			text = "ADD NOTE",
			size = UDim2.fromOffset(104, 30),
			position = UDim2.new(1, -110, 1, -36),
			color = Theme.Colors.Info,
		})
		note.ZIndex = card.ZIndex + 5
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
	self.evidenceStatuses = nextEvidenceStatuses
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
			footer.Font = Theme.Typography.CaptionFont
			footer.TextSize = Theme.Typography.CaptionSize
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
			activity.Font = Theme.Typography.CaptionFont
			activity.TextSize = Theme.Typography.CaptionSize
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
				self:ShowInterviewTopicPicker(
					counselorId,
					readString(counselor, "displayName", "Camp counselor"),
					readBoolean(counselor, "isWitness", false)
				)
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
		empty.Font = Theme.Typography.CaptionFont
		empty.TextSize = Theme.Typography.CaptionSize
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

function GameView:SetGhostMode(active: boolean)
	if self.destroyed then
		return
	end
	local reducedMotion = Motion.IsReducedMotion(self.root)
	local presentationChanged = self.ghostMode ~= active
		or self.ghostBadgeReducedMotion ~= reducedMotion
	self.ghostMode = active
	self.ghostBadgeReducedMotion = reducedMotion
	if presentationChanged then
		local activeTween = self.ghostBadgePulse
		if activeTween then
			activeTween:Cancel()
			self.ghostBadgePulse = nil
		end
		self.ghostBadge.Visible = active
		self.ghostBadge.TextTransparency = 0
		if active and not reducedMotion then
			local tween = TweenService:Create(
				self.ghostBadge,
				TweenInfo.new(
					1.5,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut,
					-1,
					true
				),
				{ TextTransparency = 0.4 }
			)
			self.ghostBadgePulse = tween
			tween:Play()
		end
	end
	if active then
		self:HideInteraction()
	end
	self.interaction.BackgroundTransparency = if active then 0.45 else Theme.PanelTransparency
	self.interactionKey.TextTransparency = if active then 0.5 else 0
	self.interactionText.TextTransparency = if active then 0.5 else 0
	if active then
		Components.SetButtonEnabled(self.roleAction, false)
	end
	for _, child in self.hotbar:GetChildren() do
		if child:IsA("TextButton") and active then
			Components.SetButtonEnabled(child, false)
		end
	end
end

function GameView:_animateRewards(targetXP: number, targetTokens: number)
	if self.lastAnimatedXP == targetXP
		and self.lastAnimatedTokens == targetTokens
	then
		return
	end
	self.lastAnimatedXP = targetXP
	self.lastAnimatedTokens = targetTokens
	self.rewardAnimationToken += 1
	local token = self.rewardAnimationToken
	local function setRewardText(xp: number, tokens: number)
		self.rewardText.Text = string.format(
			"TOTAL XP  %d     CAMP TOKENS  %d",
			xp,
			tokens
		)
	end
	if Motion.IsReducedMotion(self.resultModal) then
		setRewardText(targetXP, targetTokens)
		return
	end

	setRewardText(0, 0)
	task.spawn(function()
		local duration = 1.2
		local steps = 30
		local stepInterval = duration / steps
		for step = 1, steps do
			task.wait(stepInterval)
			if self.destroyed
				or token ~= self.rewardAnimationToken
				or not self.resultModal.Visible
				or not modalTargetVisible(self.resultModal)
			then
				return
			end
			local progress = step / steps
			local eased = 1 - (1 - progress) ^ 2
			setRewardText(
				math.floor(eased * targetXP),
				math.floor(eased * targetTokens)
			)
		end
	end)
end

function GameView:Update(state: any, legacyRound: any, legacyPlayer: any)
	self.currentState = state
	self.legacyRound = legacyRound
	self.legacyPlayer = legacyPlayer
	local round = if type(state) == "table" and type(state.round) == "table" then state.round else legacyRound
	local player = if type(state) == "table" and type(state.player) == "table" then state.player else legacyPlayer
	if type(round) ~= "table" then
		Components.SetLetterspacedText(self.phaseLabel, "WAITING FOR THE CAMP")
		self.progressLabel.Text = "Connecting to the round server..."
		return
	end

	local phase = readString(round, "phase", "Lobby")
	Components.SetLetterspacedText(
		self.phaseLabel,
		string.upper(readString(round, "phaseDisplayName", phase))
	)
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
	self:SetGhostMode(ghost)
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
	Components.SetButtonEnabled(
		self.roleAction,
		not ghost and (roleEnabled or monsterEnabled or planEnabled)
	)
	self.roleAction.TextColor3 = Theme.Colors.Text
	local roleActionText = if ghost
		then "GHOST ACTIONS LOCKED"
		elseif planEnabled
		then "PLAN TONIGHT'S HUNT"
		elseif monsterEnabled
		then "USE MONSTER ABILITY"
		elseif roleEnabled then "USE ROLE ABILITY"
		elseif roleReason then string.upper(roleReason)
		else "ABILITY UNAVAILABLE"
	self.roleActionBaseText = roleActionText
	self.roleAction.Text = roleActionText

	self:_updateLobby(state, phase)
	self:_updateInventory(state)
	self:_updateEvidence(state, round)
	self:_updateVote(round, player)
	if modalTargetVisible(self.progression) then
		self:_updateProgression(state)
	end

	local winner = if type(round.winner) == "string" then round.winner else nil
	if (phase == "Resolution" or phase == "Rewards") and not modalTargetVisible(self.progression) then
		setModalVisible(self.resultModal, true)
		if not self.voteRevealOwnsResults then
			self.resultTitle.Text = if winner then string.upper(winner .. " WIN") else "MYSTERY RESOLVED"
			self.resultBody.Text = readString(round, "resultMessage", "The night is over—for now.")
		end
		local profile = if type(state) == "table" then state.profile else nil
		local profileData = if type(profile) == "table" then profile.profile else nil
		if type(profileData) == "table" then
			local totalXP = readNumber(profileData, "totalXP", 0)
			local tokens = readNumber(profileData, "campTokens", 0)
			if phase == "Rewards" then
				self:_animateRewards(totalXP, tokens)
			else
				self.rewardText.Text = string.format(
				"TOTAL XP  %d     CAMP TOKENS  %d",
					totalXP,
					tokens
				)
			end
		else
			self.rewardAnimationToken += 1
			self.rewardText.Text = "Rewards are finalized by the server."
		end
	elseif phase ~= "Rewards" then
		if self.voteRevealOwnsResults then
			self:_cancelVoteReveal()
		end
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
	local currentTime = Workspace:GetServerTimeNow()
	if self.lobbyWasVisible and currentTime - self.lobbyTipChangedAt >= 8 then
		self.lobbyTipChangedAt = currentTime
		self.lobbyTipIndex = (self.lobbyTipIndex % #TipCatalog.definitions) + 1
		local tip = TipCatalog.definitions[self.lobbyTipIndex]
		local function applyTip()
			if tip and self.lobbyTip.Parent then
				self.lobbyTipCategory.Text = tip.category
				self.lobbyTipBody.Text = tip.body
			end
		end
		if self.settingsValues.reducedMotion == true then
			applyTip()
		else
			Motion.FadeOut(self.lobbyTip, {
				duration = 0.4,
				onComplete = function(completed: boolean)
					if completed and self.lobbyTip.Parent then
						applyTip()
						Motion.FadeIn(self.lobbyTip, { duration = 0.4 })
					end
				end,
			})
		end
	end

	local lobby = if type(self.currentState) == "table"
			and type(self.currentState.lobby) == "table"
		then self.currentState.lobby
		else nil
	local fillEndsAt = readNumber(lobby, "fillEndsAt", 0)
	local lobbySeconds = math.max(0, math.ceil(fillEndsAt - currentTime))
	local showLobbyCountdown = self.lobbyWasVisible
		and lobbySeconds > 0
		and lobbySeconds <= 10
	self.lobbyCountdown.Visible = showLobbyCountdown
	if showLobbyCountdown then
		self.lobbyCountdown.Text = tostring(lobbySeconds)
		if lobbySeconds ~= self.lobbyCountdownSecond then
			self.lobbyCountdownSecond = lobbySeconds
			self.lobbyCountdownScale.Scale = 1
			if self.settingsValues.reducedMotion ~= true then
				local grow = TweenService:Create(
					self.lobbyCountdownScale,
					TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Scale = 1.15 }
				)
				local settle = TweenService:Create(
					self.lobbyCountdownScale,
					TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Scale = 1 }
				)
				grow.Completed:Connect(function(playbackState: Enum.PlaybackState)
					if playbackState == Enum.PlaybackState.Completed
						and self.lobbyCountdownScale.Parent
					then
						settle:Play()
					end
				end)
				grow:Play()
			end
		end
	else
		self.lobbyCountdownSecond = -1
		self.lobbyCountdownScale.Scale = 1
	end

	local round = if type(self.currentState) == "table" and type(self.currentState.round) == "table"
		then self.currentState.round
		else self.legacyRound
	if type(round) ~= "table" then
		return
	end
	local seconds = math.max(0, math.ceil(readNumber(round, "phaseEndsAt", 0) - currentTime))
	self.timerLabel.Text = string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
	self.timerLabel.TextColor3 = if seconds <= 10 and seconds > 0 then Theme.Colors.DangerBright else Theme.Colors.Gold

	local player = if type(self.currentState) == "table"
			and type(self.currentState.player) == "table"
		then self.currentState.player
		else nil
	local cooldownText: string? = nil
	if not self.ghostMode and self.roleAction.Active and type(player) == "table" then
		local cooldowns = if type(player.abilityCooldownEndsAt) == "table"
			then player.abilityCooldownEndsAt
			else nil
		local minimumRemaining = math.huge
		if cooldowns then
			for _, abilityId in asTable(player.abilityIds) do
				if type(abilityId) == "string" then
					local cooldownEndsAt = cooldowns[abilityId]
					if type(cooldownEndsAt) == "number"
						and cooldownEndsAt > currentTime
					then
						minimumRemaining = math.min(
							minimumRemaining,
							cooldownEndsAt - currentTime
						)
					end
				end
			end
		end
		if minimumRemaining < math.huge then
			cooldownText = string.format(
				"READY IN %ds",
				math.ceil(minimumRemaining)
			)
		end
	end
	if cooldownText then
		if self.lastCooldownText ~= cooldownText
			or self.roleAction.Text ~= cooldownText
		then
			self.roleAction.Text = cooldownText
			self.roleAction.TextColor3 = Theme.Colors.TextMuted
		end
		self.lastCooldownText = cooldownText
	else
		if self.lastCooldownText ~= nil then
			self.roleAction.Text = self.roleActionBaseText
			self.roleAction.TextColor3 = Theme.Colors.Text
		end
		self.lastCooldownText = nil
	end
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
	if self.ghostMode then
		return
	end
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
	if self.ghostMode then
		self:HideInteraction()
		return
	end
	self.interactionKey.Text = inputText
	self.interactionText.Text = actionText .. if objectText ~= "" then "\n" .. objectText else ""
	self.interaction.Visible = true
end

function GameView:HideInteraction()
	self.interaction.Visible = false
end

function GameView:_cancelVoteReveal()
	self.voteRevealToken += 1
	self.voteRevealOwnsResults = false
	Motion.Cancel(self.voteRevealList)
	for _, child in self.voteRevealList:GetChildren() do
		if child:IsA("GuiObject") then
			Motion.Cancel(child)
		end
	end
	Components.ClearGenerated(self.voteRevealList)
	self.voteRevealList.Visible = false
	local confetti = self.voteConfetti
	self.voteConfetti = nil
	if confetti and confetti.Parent then
		confetti:Destroy()
	end
end

function GameView:_playVoteConfetti(token: number)
	if self.destroyed or token ~= self.voteRevealToken then
		return
	end
	local previous = self.voteConfetti
	if previous and previous.Parent then
		previous:Destroy()
	end
	local container = Instance.new("Frame")
	container.Name = "VoteConfetti"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.ZIndex = 40
	container.Parent = self.root
	self.voteConfetti = container

	local random = Random.new(token)
	local tweenInfo = TweenInfo.new(
		0.8,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	)
	for index = 1, 12 do
		local square = Instance.new("Frame")
		square.Name = "GoldSquare_" .. tostring(index)
		square.AnchorPoint = Vector2.new(0.5, 0.5)
		square.Position = UDim2.fromScale(0.5, 0.5)
		square.Size = UDim2.fromOffset(8, 8)
		square.BackgroundColor3 = Theme.Colors.Gold
		square.BorderSizePixel = 0
		square.Rotation = random:NextNumber(-25, 25)
		square.ZIndex = 41
		square.Parent = container
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(90, 240)
		TweenService:Create(square, tweenInfo, {
			Position = UDim2.new(
				0.5,
				math.cos(angle) * distance,
				0.5,
				math.sin(angle) * distance
			),
			Rotation = square.Rotation + random:NextNumber(-150, 150),
			BackgroundTransparency = 1,
		}):Play()
	end
	task.delay(0.85, function()
		if token == self.voteRevealToken
			and self.voteConfetti == container
			and container.Parent
		then
			self.voteConfetti = nil
			container:Destroy()
		end
	end)
end

function GameView:PlayVoteReveal(
	votes: { any },
	culpritId: string,
	monsterId: string,
	namesById: { [string]: string },
	onComplete: (() -> ())?
)
	if self.destroyed then
		return
	end
	self:_cancelVoteReveal()
	self.voteRevealToken += 1
	local token = self.voteRevealToken
	self.voteRevealOwnsResults = true
	setModalVisible(self.voteModal, false)
	setModalVisible(self.resultModal, true)
	Components.PlayUISound("vote")
	self.resultTitle.Text = "COUNTING THE VOTES"
	self.resultTitle.TextColor3 = Theme.Colors.Gold
	self.resultBody.Text = ""

	local voteCount = 0
	local correctVotes = 0
	for _, vote in votes do
		if type(vote) == "table" and voteCount < 64 then
			voteCount += 1
			local voterId = readString(vote, "voterId", "")
			local targetId = readString(vote, "targetId", "")
			local voterName = readString(
				vote,
				"voterName",
				namesById[voterId] or if voterId ~= "" then voterId else "Unknown voter"
			)
			local targetName = readString(
				vote,
				"targetName",
				namesById[targetId] or if targetId ~= "" then targetId else "Unknown target"
			)
			local correct = targetId ~= "" and targetId == culpritId
			if correct then
				correctVotes += 1
			end

			local entry = Instance.new("Frame")
			entry.Name = "VoteEntry"
			entry.Size = UDim2.new(1, -8, 0, 28)
			entry.BackgroundColor3 = Theme.Colors.PanelSoft
			entry.BackgroundTransparency = 0.12
			entry.BorderSizePixel = 0
			entry.LayoutOrder = voteCount
			entry:SetAttribute("Generated", true)
			entry.Parent = self.voteRevealList
			Components.Corner(entry, Theme.SmallCornerRadius)

			local voterLabel = Components.Label(
				entry,
				"Voter",
				voterName,
				Theme.Typography.CaptionSize,
				Theme.Typography.CaptionFont
			)
			voterLabel.Position = UDim2.fromOffset(8, 2)
			voterLabel.Size = UDim2.new(0.45, -12, 1, -4)
			voterLabel.TextXAlignment = Enum.TextXAlignment.Right

			local arrow = Components.Label(
				entry,
				"Arrow",
				"→",
				Theme.Typography.HeadingSize,
				Theme.Typography.HeadingFont
			)
			arrow.Position = UDim2.new(0.45, 0, 0, 2)
			arrow.Size = UDim2.new(0.1, 0, 1, -4)
			arrow.TextColor3 = if correct
				then Theme.Colors.Gold
				else Theme.Colors.DangerBright
			arrow.TextXAlignment = Enum.TextXAlignment.Center

			local targetLabel = Components.Label(
				entry,
				"Target",
				targetName,
				Theme.Typography.CaptionSize,
				Theme.Typography.CaptionFont
			)
			targetLabel.Position = UDim2.new(0.55, 4, 0, 2)
			targetLabel.Size = UDim2.new(0.45, -12, 1, -4)
		end
	end

	local correctMajority = correctVotes > voteCount / 2
	local culpritName = namesById[culpritId]
		or if culpritId ~= "" then culpritId else "The culprit"
	local safeMonsterId = if monsterId ~= "" then monsterId else "unknown monster"
	local reducedMotion = Motion.IsReducedMotion(self.resultModal)
	local function active(): boolean
		return not self.destroyed
			and token == self.voteRevealToken
			and self.resultModal.Parent ~= nil
	end
	local function revealVerdict()
		if not active() then
			return
		end
		if correctMajority then
			self.resultTitle.Text = "THE CULPRIT IS FOUND"
			self.resultTitle.TextColor3 = Theme.Colors.Gold
			self.resultBody.Text = culpritName .. " was the " .. safeMonsterId
			Components.PlayUISound("success")
			if not reducedMotion then
				self:_playVoteConfetti(token)
			end
		else
			self.resultTitle.Text = "THE MONSTER ESCAPES"
			self.resultTitle.TextColor3 = Theme.Colors.DangerBright
			self.resultBody.Text = safeMonsterId .. " was never caught"
			Components.PlayUISound("error")
		end
		task.delay(if reducedMotion then 0.15 else 0.9, function()
			if active() and onComplete then
				onComplete()
			end
		end)
	end

	if reducedMotion then
		self.voteRevealList.Visible = true
		revealVerdict()
		return
	end

	local stagger = math.min(0.6, 8 / math.max(voteCount, 1))
	task.delay(0.3, function()
		if not active() then
			return
		end
		self.voteRevealList.Visible = true
		Motion.StaggerChildren(self.voteRevealList, {
			preset = "SlideUp",
			step = stagger,
		})
	end)
	local verdictDelay = 0.3 + math.max(voteCount - 1, 0) * stagger + 0.8
	task.delay(verdictDelay, revealVerdict)
end

function GameView:_cancelRoleReveal()
	self.roleRevealToken += 1
	local skipConnection = self.roleRevealSkip
	if skipConnection then
		skipConnection:Disconnect()
		self.roleRevealSkip = nil
	end
	local overlay = self.roleRevealOverlay
	self.roleRevealOverlay = nil
	self.roleRevealActive = false
	if not overlay then
		return
	end
	Motion.Cancel(overlay)
	for _, descendant in overlay:GetDescendants() do
		if descendant:IsA("GuiObject") then
			Motion.Cancel(descendant)
		end
	end
	if overlay.Parent then
		overlay:Destroy()
	end
end

function GameView:PlayRoleReveal(
	_roleName: string,
	roleDisplayName: string,
	roleDescription: string,
	isMonster: boolean
)
	if self.destroyed then
		return
	end
	self:_cancelRoleReveal()
	self:_cancelPhaseTitle()
	self.roleRevealToken += 1
	local token = self.roleRevealToken
	self.roleRevealActive = true

	local overlay = Instance.new("CanvasGroup")
	overlay.Name = "RoleRevealOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = 0
	overlay.BorderSizePixel = 0
	overlay.GroupTransparency = 1
	overlay.Active = true
	overlay.ZIndex = 90
	overlay.Parent = self.root
	self.roleRevealOverlay = overlay

	local host: Frame? = nil
	local cardShown = false
	local exiting = false
	local reducedMotion = Motion.IsReducedMotion(self.root)
	local function active(): boolean
		return not self.destroyed
			and self.roleRevealToken == token
			and overlay.Parent ~= nil
	end
	local function cleanup()
		if active() then
			self:_cancelRoleReveal()
		end
	end
	local function exitReveal()
		if exiting or not active() or not cardShown then
			return
		end
		exiting = true
		local skipConnection = self.roleRevealSkip
		if skipConnection then
			skipConnection:Disconnect()
			self.roleRevealSkip = nil
		end
		local currentHost = host
		if reducedMotion or not currentHost then
			cleanup()
			return
		end
		Motion.Cancel(currentHost)
		local restingPosition = currentHost.Position
		TweenService:Create(
			currentHost,
			TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
			{
				Position = UDim2.new(
					restingPosition.X.Scale,
					restingPosition.X.Offset,
					restingPosition.Y.Scale,
					restingPosition.Y.Offset - 120
				),
			}
		):Play()
		local fade = TweenService:Create(
			overlay,
			TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
			{ GroupTransparency = 1 }
		)
		fade.Completed:Connect(function(_playbackState: Enum.PlaybackState)
			cleanup()
		end)
		fade:Play()
	end

	self.roleRevealSkip = overlay.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			exitReveal()
		end
	end)

	local function showCard()
		if not active() then
			return
		end
		local cardHost = Instance.new("Frame")
		cardHost.Name = "RoleCardHost"
		cardHost.AnchorPoint = Vector2.new(0.5, 0.5)
		cardHost.Position = UDim2.fromScale(0.5, 0.5)
		cardHost.Size = UDim2.fromOffset(280, 200)
		cardHost.BackgroundTransparency = 1
		cardHost.BorderSizePixel = 0
		cardHost.ZIndex = 91
		cardHost.Parent = overlay
		host = cardHost

		local shadow = Instance.new("Frame")
		shadow.Name = "DropShadow"
		shadow.Position = UDim2.fromOffset(5, 6)
		shadow.Size = UDim2.fromScale(1, 1)
		shadow.BackgroundColor3 = Theme.Colors.Black
		shadow.BackgroundTransparency = 0.68
		shadow.BorderSizePixel = 0
		shadow.ZIndex = 91
		shadow.Parent = cardHost
		Components.Corner(shadow, Theme.CornerRadius)

		local card = Instance.new("Frame")
		card.Name = "RoleCard"
		card.Size = UDim2.fromScale(1, 1)
		card.BackgroundColor3 = Theme.Notebook.PageColor
		card.BackgroundTransparency = 0
		card.BorderSizePixel = 0
		card.ClipsDescendants = true
		card.ZIndex = 92
		card.Parent = cardHost
		Components.Corner(card, Theme.CornerRadius)

		local strip = Instance.new("Frame")
		strip.Name = "FactionStrip"
		strip.Size = UDim2.new(1, 0, 0, 8)
		strip.BackgroundColor3 = if isMonster
			then Theme.Colors.DangerBright
			else Theme.Colors.Gold
		strip.BorderSizePixel = 0
		strip.ZIndex = 93
		strip.Parent = card

		local category = Components.Label(
			card,
			"Category",
			"YOUR ROLE",
			Theme.Typography.CaptionSize,
			Theme.Typography.CaptionFont
		)
		category.Position = UDim2.fromOffset(16, 16)
		category.Size = UDim2.new(1, -32, 0, 20)
		category.TextColor3 = Theme.Notebook.InkMuted
		category.TextXAlignment = Enum.TextXAlignment.Center
		category.ZIndex = 93

		local roleName = Components.Label(
			card,
			"RoleName",
			string.upper(string.sub(roleDisplayName, 1, 48)),
			28,
			Theme.Typography.DisplayFont
		)
		roleName.Position = UDim2.fromOffset(14, 38)
		roleName.Size = UDim2.new(1, -28, 0, 48)
		roleName.TextColor3 = if isMonster
			then Theme.Colors.Danger
			else Theme.Notebook.InkColor
		roleName.TextXAlignment = Enum.TextXAlignment.Center
		roleName.ZIndex = 93

		local description = Components.Label(
			card,
			"Description",
			string.sub(roleDescription, 1, 240),
			Theme.Typography.BodySize,
			Theme.Typography.BodyFont
		)
		description.Position = UDim2.fromOffset(20, 92)
		description.Size = UDim2.new(1, -40, 0, 86)
		description.TextColor3 = Theme.Notebook.InkColor
		description.TextWrapped = true
		description.TextTruncate = Enum.TextTruncate.AtEnd
		description.TextXAlignment = Enum.TextXAlignment.Center
		description.TextYAlignment = Enum.TextYAlignment.Top
		description.ZIndex = 93

		cardShown = true
		Components.PlayUISound("open")
		if not reducedMotion then
			Motion.SlideUp(cardHost, {
				duration = 0.35,
				distance = 56,
			})
			Motion.PopIn(card, {
				duration = 0.35,
			})
		end
		task.delay(if reducedMotion then 1 else 2.35, exitReveal)
	end

	if reducedMotion then
		overlay.GroupTransparency = 0
		showCard()
	else
		TweenService:Create(
			overlay,
			TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ GroupTransparency = 0 }
		):Play()
		task.delay(0.65, showCard)
	end
end

function GameView:_cancelPhaseTitle()
	self.phaseTitleToken += 1
	local band = self.phaseTitleBand
	self.phaseTitleBand = nil
	self.phaseTitleActive = false
	if not band then
		return
	end
	Motion.Cancel(band)
	for _, descendant in band:GetDescendants() do
		if descendant:IsA("GuiObject") then
			Motion.Cancel(descendant)
		end
	end
	if band.Parent then
		band:Destroy()
	end
end

function GameView:_cancelWinReveal()
	self.winRevealToken += 1
	local skipConnection = self.winRevealSkip
	if skipConnection then
		skipConnection:Disconnect()
		self.winRevealSkip = nil
	end
	local overlay = self.winRevealOverlay
	self.winRevealOverlay = nil
	self.winRevealActive = false
	if not overlay then
		return
	end
	Motion.Cancel(overlay)
	for _, descendant in overlay:GetDescendants() do
		if descendant:IsA("GuiObject") then
			Motion.Cancel(descendant)
		end
	end
	if overlay.Parent then
		overlay:Destroy()
	end
end

function GameView:PlayWinReveal(winner: string, isHumanWin: boolean)
	if self.destroyed then
		return
	end
	self:_cancelWinReveal()
	self:_cancelPhaseTitle()
	self.winRevealToken += 1
	local token = self.winRevealToken
	self.winRevealActive = true

	local factionColor = if isHumanWin
		then Theme.Colors.Gold
		else Theme.Colors.DangerBright
	local overlay = Instance.new("CanvasGroup")
	overlay.Name = "WinRevealOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Colors.Background
	overlay.BackgroundTransparency = 0
	overlay.BorderSizePixel = 0
	overlay.GroupTransparency = 1
	overlay.Active = true
	overlay.ZIndex = 88
	overlay.Parent = self.root
	self.winRevealOverlay = overlay

	local topStrip = Instance.new("Frame")
	topStrip.Name = "TopFactionStrip"
	topStrip.Size = UDim2.new(1, 0, 0, 4)
	topStrip.BackgroundColor3 = factionColor
	topStrip.BorderSizePixel = 0
	topStrip.ZIndex = 89
	topStrip.Parent = overlay

	local bottomStrip = Instance.new("Frame")
	bottomStrip.Name = "BottomFactionStrip"
	bottomStrip.AnchorPoint = Vector2.new(0, 1)
	bottomStrip.Position = UDim2.fromScale(0, 1)
	bottomStrip.Size = UDim2.new(1, 0, 0, 4)
	bottomStrip.BackgroundColor3 = factionColor
	bottomStrip.BorderSizePixel = 0
	bottomStrip.ZIndex = 89
	bottomStrip.Parent = overlay

	local safeWinner = if winner ~= ""
		then string.upper(string.sub(winner, 1, 48))
		else if isHumanWin then "CAMPERS" else "MONSTER"
	local title = Components.Label(
		overlay,
		"WinnerTitle",
		safeWinner .. " WIN",
		64,
		Theme.Typography.DisplayFont
	)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.46)
	title.Size = UDim2.new(1, -48, 0, 82)
	title.TextColor3 = factionColor
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 89
	local titleScale = Instance.new("UIScale")
	titleScale.Scale = 0.9
	titleScale.Parent = title

	local subtitle = Components.Label(
		overlay,
		"WinnerSubtitle",
		if isHumanWin
			then "The mystery is solved."
			else "The monster escapes into the night.",
		Theme.Typography.CaptionSize,
		Theme.Typography.CaptionFont
	)
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.fromScale(0.5, 0.55)
	subtitle.Size = UDim2.new(1, -48, 0, 32)
	subtitle.TextColor3 = Theme.Colors.White
	subtitle.TextTransparency = 0.4
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.ZIndex = 89

	local reducedMotion = Motion.IsReducedMotion(self.root)
	local exiting = false
	local function active(): boolean
		return not self.destroyed
			and self.winRevealToken == token
			and overlay.Parent ~= nil
	end
	local function cleanup()
		if active() then
			self:_cancelWinReveal()
		end
	end
	local function exitReveal()
		if exiting or not active() then
			return
		end
		exiting = true
		local skipConnection = self.winRevealSkip
		if skipConnection then
			skipConnection:Disconnect()
			self.winRevealSkip = nil
		end
		if reducedMotion then
			cleanup()
			return
		end
		local fade = TweenService:Create(
			overlay,
			TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
			{ GroupTransparency = 1 }
		)
		fade.Completed:Connect(function(_playbackState: Enum.PlaybackState)
			cleanup()
		end)
		fade:Play()
	end

	self.winRevealSkip = overlay.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			exitReveal()
		end
	end)
	Components.PlayUISound(if isHumanWin then "success" else "error")
	if reducedMotion then
		overlay.GroupTransparency = 0
		titleScale.Scale = 1
		task.delay(0.8, exitReveal)
		return
	end
	TweenService:Create(
		overlay,
		TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ GroupTransparency = 0 }
	):Play()
	TweenService:Create(
		titleScale,
		TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
	task.delay(2.3, exitReveal)
end

function GameView:PlayPhaseTitleCard(phaseName: string, isReconnect: boolean)
	local entry = PhaseTitles[phaseName]
	if self.destroyed
		or isReconnect
		or self.roleRevealActive
		or type(entry) ~= "table"
	then
		return
	end
	self:_cancelPhaseTitle()
	self.phaseTitleToken += 1
	local token = self.phaseTitleToken
	self.phaseTitleActive = true

	local band = Instance.new("CanvasGroup")
	band.Name = "PhaseTitleBand"
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(0.5, 0.5)
	band.Size = UDim2.new(1, 0, 0, 96)
	band.BackgroundColor3 = Theme.Colors.Black
	band.BackgroundTransparency = 0.45
	band.BorderSizePixel = 0
	band.GroupTransparency = 1
	band.ZIndex = 80
	band.Parent = self.root
	self.phaseTitleBand = band

	local scale = Instance.new("UIScale")
	scale.Scale = 0.97
	scale.Parent = band
	local title = Components.Label(
		band,
		"PhaseTitle",
		"",
		math.floor(Theme.Typography.HeadingSize * 1.4),
		Theme.Typography.HeadingFont
	)
	title.Position = UDim2.fromOffset(16, 12)
	title.Size = UDim2.new(1, -32, 0, 42)
	title.TextColor3 = Theme.Colors.White
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 81
	Components.SetLetterspacedText(title, entry.title)
	local subtitle = Components.Label(
		band,
		"Subtitle",
		entry.subtitle,
		Theme.Typography.CaptionSize,
		Theme.Typography.CaptionFont
	)
	subtitle.Position = UDim2.fromOffset(16, 54)
	subtitle.Size = UDim2.new(1, -32, 0, 28)
	subtitle.TextColor3 = Theme.Colors.White
	subtitle.TextTransparency = 0.7
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.ZIndex = 81

	local reducedMotion = Motion.IsReducedMotion(self.root)
	local function active(): boolean
		return not self.destroyed
			and self.phaseTitleToken == token
			and band.Parent ~= nil
	end
	local function cleanup()
		if active() then
			self:_cancelPhaseTitle()
		end
	end
	if reducedMotion then
		band.GroupTransparency = 0
		scale.Scale = 1
		task.delay(0.9, cleanup)
		return
	end
	TweenService:Create(
		band,
		TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ GroupTransparency = 0 }
	):Play()
	TweenService:Create(
		scale,
		TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
	task.delay(2.05, function()
		if not active() then
			return
		end
		local fade = TweenService:Create(
			band,
			TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
			{ GroupTransparency = 1 }
		)
		fade.Completed:Connect(function(_playbackState: Enum.PlaybackState)
			cleanup()
		end)
		fade:Play()
	end)
end

function GameView:_cancelEvidenceDiscovery()
	self.evidenceCeremonyToken += 1
	local skipConnection = self.evidenceCeremonySkip
	if skipConnection then
		skipConnection:Disconnect()
		self.evidenceCeremonySkip = nil
	end
	local overlay = self.evidenceCeremony
	self.evidenceCeremony = nil
	if not overlay then
		return
	end
	Motion.Cancel(overlay)
	for _, descendant in overlay:GetDescendants() do
		if descendant:IsA("GuiObject") then
			Motion.Cancel(descendant)
		end
	end
	if overlay.Parent then
		overlay:Destroy()
	end
end

function GameView:PlayEvidenceDiscovery(evidenceName: string, evidenceDescription: string)
	if self.destroyed then
		return
	end
	self:_cancelEvidenceDiscovery()
	local safeName = if evidenceName ~= ""
		then string.sub(evidenceName, 1, 80)
		else "New evidence found"
	local safeDescription = if evidenceDescription ~= ""
		then string.sub(evidenceDescription, 1, 240)
		else "A new clue has been added to the evidence notebook."
	if Motion.IsReducedMotion(self.root) then
		self:Notify("Evidence found", safeName .. " — " .. safeDescription, "Info")
		return
	end

	self.evidenceCeremonyToken += 1
	local token = self.evidenceCeremonyToken
	local overlay = Instance.new("Frame")
	overlay.Name = "EvidenceDiscovery"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = 0.55
	overlay.BorderSizePixel = 0
	overlay.Active = true
	overlay.ZIndex = 20
	overlay.Parent = self.root
	self.evidenceCeremony = overlay

	local host: Frame? = nil
	local card: Frame? = nil
	local function active(): boolean
		return not self.destroyed
			and self.evidenceCeremonyToken == token
			and overlay.Parent ~= nil
	end
	local function cleanup()
		if active() then
			self:_cancelEvidenceDiscovery()
		end
	end
	self.evidenceCeremonySkip = overlay.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			cleanup()
		end
	end)

	Motion.FadeIn(overlay, {
		duration = 0.2,
	})
	task.delay(0.2, function()
		if not active() then
			return
		end
		local cardHost = Instance.new("Frame")
		cardHost.Name = "EvidenceCardHost"
		cardHost.AnchorPoint = Vector2.new(0.5, 0.5)
		cardHost.Position = UDim2.fromScale(0.5, 0.5)
		cardHost.Size = UDim2.fromOffset(
			Theme.Notebook.CardWidth,
			Theme.Notebook.CardHeight
		)
		cardHost.BackgroundTransparency = 1
		cardHost.BorderSizePixel = 0
		cardHost.ZIndex = 21
		cardHost.Parent = overlay
		host = cardHost

		local evidenceCard = Components.EvidenceCard(cardHost, {
			name = safeName,
			description = safeDescription,
			status = "Unconfirmed",
			channel = "NEW CLUE",
		})
		evidenceCard.Size = UDim2.fromScale(1, 1)
		evidenceCard.ZIndex = 22
		for _, descendant in evidenceCard:GetDescendants() do
			if descendant:IsA("GuiObject") then
				descendant.ZIndex += 21
			end
		end
		card = evidenceCard
		Motion.SlideUp(cardHost, {
			duration = 0.3,
		})
		Motion.PopIn(evidenceCard, {
			duration = 0.3,
		})
	end)

	task.delay(1.8, function()
		local currentCard = card
		if not active() or not currentCard then
			return
		end
		local titleInstance = currentCard:FindFirstChild("Title", true)
		if not titleInstance or not titleInstance:IsA("TextLabel") then
			return
		end
		local originalColor = titleInstance.TextColor3
		local brighten = TweenService:Create(
			titleInstance,
			TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ TextColor3 = Theme.Colors.Gold }
		)
		brighten.Completed:Connect(function(playbackState: Enum.PlaybackState)
			if playbackState ~= Enum.PlaybackState.Completed
				or not active()
				or not titleInstance.Parent
			then
				return
			end
			TweenService:Create(
				titleInstance,
				TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
				{ TextColor3 = originalColor }
			):Play()
		end)
		brighten:Play()
	end)

	task.delay(2.3, function()
		local currentHost = host
		if not active() or not currentHost then
			return
		end
		Components.PlayUISound("stamp")
		local targetPosition = UDim2.new(1, -88, 0, 44)
		local notebookButton = self.notebookButton
		if notebookButton and notebookButton.Parent then
			local buttonPosition = notebookButton.AbsolutePosition
			local buttonSize = notebookButton.AbsoluteSize
			local overlayPosition = overlay.AbsolutePosition
			targetPosition = UDim2.fromOffset(
				buttonPosition.X + buttonSize.X * 0.5 - overlayPosition.X,
				buttonPosition.Y + buttonSize.Y * 0.5 - overlayPosition.Y
			)
		end
		local flyScale = Instance.new("UIScale")
		flyScale.Name = "EvidenceFlyScale"
		flyScale.Scale = 1
		flyScale.Parent = currentHost
		local flyInfo = TweenInfo.new(
			0.4,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		)
		TweenService:Create(currentHost, flyInfo, {
			Position = targetPosition,
		}):Play()
		TweenService:Create(flyScale, flyInfo, {
			Scale = 0.1,
		}):Play()
		Motion.FadeOut(currentHost, {
			duration = 0.4,
			easingStyle = Enum.EasingStyle.Quint,
			easingDirection = Enum.EasingDirection.Out,
		})
	end)

	task.delay(2.7, cleanup)
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

function GameView:PrepareReconnectSnapshot()
	self.notebook:SetAttribute("SuppressNextStagger", true)
	Motion.Cancel(self.evidenceList)
end

function GameView:Notify(
	titleText: string,
	bodyText: string,
	kind: string,
	durationSeconds: number?
)
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
	local title = Components.Label(
		toast,
		"Title",
		titleText,
		Theme.Typography.SubheadingSize,
		Theme.Typography.HeadingFont
	)
	title.Position = UDim2.fromOffset(12, 7)
	title.Size = UDim2.new(1, -24, 0, 24)
	local body = Components.Label(
		toast,
		"Body",
		bodyText,
		Theme.Typography.BodySize,
		Theme.Typography.BodyFont
	)
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
	task.delay(math.clamp(durationSeconds or 4.5, 1, 12), function()
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
	self:_cancelRoleReveal()
	self:_cancelPhaseTitle()
	self:_cancelWinReveal()
	self:_cancelVoteReveal()
	self:_cancelEvidenceDiscovery()
	self:_dismissInterviewPicker(true)
	self:_dismissCounselorDialogue(true)
	if self.ghostBadgePulse then
		self.ghostBadgePulse:Cancel()
		self.ghostBadgePulse = nil
	end
	self.destroyed = true
	self.rewardAnimationToken += 1
	self.announcementToken += 1
	self.audioSettingCallback = nil
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
