--!strict

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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
local ProgressionConfig = require(SharedConfig:WaitForChild("ProgressionConfig"))
local PublicMonsterCatalog = require(SharedConfig:WaitForChild("PublicMonsterCatalog"))
local InterviewTopics = require(SharedConfig:WaitForChild("InterviewTopics"))
local KeybindHints = require(SharedConfig:WaitForChild("KeybindHints"))
local MonsterOrder = require(SharedConfig:WaitForChild("MonsterOrder"))
local PhaseTips = require(SharedConfig:WaitForChild("PhaseTips"))
local PhaseTitles = require(SharedConfig:WaitForChild("PhaseTitles"))
local TipCatalog = require(SharedConfig:WaitForChild("TipCatalog"))
local UpgradeCatalog = require(SharedConfig:WaitForChild("UpgradeCatalog"))
local HapticController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("HapticController"))

type ActionHandler = (action: string, payload: any) -> (boolean, string?)
type ImageResolver = (key: string) -> string?

type RoundSummaryStats = {
	roundNumber: number,
	winner: string,
	isHumanWin: boolean,
	evidenceFound: number,
	evidenceGoal: number,
	objectivesCompleted: number,
	objectiveGoal: number,
	survivorCount: number,
	totalParticipants: number,
	monsterId: string?,
	victimName: string?,
	personalEvidence: number,
	playerRole: string,
	killCount: number?,
	votesAgainstMe: number?,
	wasCaught: boolean?,
}

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
	notebookBadge: TextLabel?,
	lastSeenEvidenceCount: number,
	lastEvidenceCountForPop: number,
	settingsButton: TextButton?,
	codexButton: TextButton?,
	actionHandler: ActionHandler,
	resolveImage: ImageResolver,
	phaseLabel: TextLabel,
	timerLabel: TextLabel,
	timerPulseConn: RBXScriptConnection?,
	timerPulsing: boolean,
	timerBar: Frame?,
	timerFill: Frame?,
	phaseArc: Frame?,
	phaseArcDots: { [string]: Frame },
	progressLabel: TextLabel,
	roleTitle: TextLabel,
	roleIcon: ImageLabel,
	roleDescription: TextLabel,
	roleAction: TextButton,
	cooldownBar: Frame?,
	cooldownFill: Frame?,
	abilityBarMaxCooldown: number,
	objectiveText: TextLabel,
	objectiveFill: Frame,
	healthText: TextLabel,
	healthFill: Frame,
	stateBadge: TextLabel,
	ghostBadge: TextLabel,
	ghostBadgePulse: Tween?,
	ghostBadgeReducedMotion: boolean,
	ghostMode: boolean,
	hauntPanel: Frame?,
	hauntFill: Frame?,
	hauntHint: TextLabel?,
	eliminatedBanner: Frame?,
	eliminatedMode: boolean,
	hotbar: ScrollingFrame,
	monsterPanel: CanvasGroup?,
	monsterNameLabel: TextLabel?,
	monsterStaminaFill: Frame?,
	monsterAbilityLabel: TextLabel?,
	monsterNoteLabel: TextLabel?,
	monsterPanelVisible: boolean,
	rosterPanel: Frame?,
	rosterPanelVisible: boolean,
	lastRosterSignature: string,
	evidenceSignature: string,
	inventorySignature: string,
	streakToastShown: boolean,
	notebook: Frame,
	evidenceList: ScrollingFrame,
	evidenceSummary: TextLabel,
	settings: Frame,
	settingsList: ScrollingFrame,
	voteModal: Frame,
	voteModalTitleLabel: TextLabel?,
	voteCountLabel: TextLabel?,
	voteWarningLabel: TextLabel?,
	voteList: ScrollingFrame,
	resultModal: Frame,
	resultTitle: TextLabel,
	resultBody: TextLabel,
	rewardText: TextLabel,
	voteRevealList: ScrollingFrame,
	progression: Frame,
	progressionSummary: TextLabel,
	progressionList: ScrollingFrame,
	codex: Frame?,
	codexSummary: TextLabel?,
	codexList: ScrollingFrame?,
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
	roundSummaryOverlay: CanvasGroup?,
	roundSummaryToken: number,
	deathCinematicToken: number,
	deathCinematicOverlay: CanvasGroup?,
	voteRevealToken: number,
	voteRevealOwnsResults: boolean,
	voteConfetti: Frame?,
	currentState: any,
	legacyRound: any,
	legacyPlayer: any,
	currentVoteSignature: string,
	localVoteHasLocked: boolean,
	dayObjectiveNotifiedRound: number?,
	evidenceNotifiedRound: number?,
	evidenceStatuses: { [string]: string },
	comboSelectionId: string?,
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
	keybindHintToken: number,
	keybindHintOverlay: CanvasGroup?,
	lastCooldownText: string?,
	lastCooldownActive: boolean,
	roleActionBaseText: string,
	lastAnimatedXP: number,
	lastAnimatedTokens: number,
	lastHealthForFlash: number,
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

local MONSTER_ABILITY_READY_RICH_COLOR = "#DAAC4F"
local MONSTER_ABILITY_COOLING_RICH_COLOR = "#E27F31"

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

-- Ordered monster list for consistent planning UI display
local MONSTER_PLAN_ORDER: { string } = {
	"BabyAlien",
	"Screamer",
	"Wendigo",
	"ShadowMonster",
	"Chupacabra",
	"Dullahan",
	"Entity",
	"Banshee",
}

-- One-line taglines shown in the planning UI — visual identity + core threat
local MONSTER_TAGLINES: { [string]: string } = {
	BabyAlien    = "Pink fleshy crawler · burst leaps · weak in open light",
	Screamer     = "Bone-pale hulk with hollow maw · scream disrupts all equipment",
	Wendigo      = "Towering deer skull · mimicry lures · charges in a straight line",
	ShadowMonster = "Smoky silhouette · travels dark nodes · weakens in direct light",
	Chupacabra   = "Spined grey stalker · blood tracker · pounces and latches",
	Dullahan     = "Headless cloaked figure · accelerates on sustained sight",
	Entity       = "Deep-sea apparition · anchor teleport · distorts perception",
	Banshee      = "Silver wailing spectre · marks campers · wail attacks the senses",
}

local VOLUME_SETTING_KEYS: { [string]: boolean } = {
	masterVolume = true,
	musicVolume = true,
	ambienceVolume = true,
	effectsVolume = true,
	uiVolume = true,
}

local ROSTER_PHASES: { [string]: boolean } = {
	Day = true,
	Investigation = true,
	Campfire = true,
}

local PHASE_ARC_ORDER: { string } = {
	"Day",
	"MurderPlanning",
	"NightTransform",
	"Investigation",
	"Campfire",
	"Resolution",
}

local PHASE_ARC_LABELS: { [string]: string } = {
	MurderPlanning = "PLAN",
	NightTransform = "NIGHT",
	Investigation = "INVEST",
	Day = "DAY",
	Campfire = "VOTE",
	Resolution = "REVEAL",
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

-- Small-viewport / touch-first HUD support. Phones report either a short
-- viewport or touch without a keyboard; both get the compact layout pass.
local COMPACT_UI_SCALE = 0.78

local function isCompactViewport(viewport: Vector2): boolean
	if viewport.X < viewport.Y then
		-- Portrait viewports keep the dedicated narrow branch.
		return false
	end
	if viewport.Y < 500 then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function ensureLayoutScale(host: Instance, name: string): UIScale
	local existing = host:FindFirstChild(name)
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = name
	scale.Parent = host
	return scale
end

local function ensureMinSizeConstraint(host: Instance): UISizeConstraint
	local existing = host:FindFirstChild("CompactMinSize")
	if existing and existing:IsA("UISizeConstraint") then
		return existing
	end
	local constraint = Instance.new("UISizeConstraint")
	constraint.Name = "CompactMinSize"
	constraint.Parent = host
	return constraint
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
	-- A StarterGui template used to clone an empty second "GameUI" on spawn
	-- (client boot races the first character spawn, so FindFirstChild missed
	-- it). The template is gone from the project, but scrub stragglers so the
	-- HUD never has an identically-named sibling.
	for _, sibling in playerGui:GetChildren() do
		if sibling ~= screen and sibling.Name == "GameUI" then
			sibling:Destroy()
		end
	end
	playerGui.ChildAdded:Connect(function(child)
		if child ~= screen and child.Name == "GameUI" then
			task.defer(function()
				if child.Parent == playerGui then
					child:Destroy()
				end
			end)
		end
	end)
	screen.DisplayOrder = 10
	screen.Enabled = true
	screen.IgnoreGuiInset = false
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		-- CoreUISafeInsets keeps the HUD's top row below the Roblox topbar;
		-- DeviceSafeInsets let the phase header and role chip collide with
		-- the core chrome on desktop.
		screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
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
	local timerBar = Instance.new("Frame")
	timerBar.Name = "TimerBar"
	timerBar.Size = UDim2.new(1, -36, 0, 5)
	timerBar.Position = UDim2.fromOffset(18, 43)
	timerBar.BackgroundColor3 = Theme.Colors.PanelSoft
	timerBar.BackgroundTransparency = 0.3
	timerBar.BorderSizePixel = 0
	timerBar.Parent = top

	local timerFill = Instance.new("Frame")
	timerFill.Name = "TimerFill"
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.BackgroundColor3 = Theme.Colors.Gold
	timerFill.BorderSizePixel = 0
	timerFill.Parent = timerBar
	Components.Corner(timerBar, 3)
	Components.Corner(timerFill, 3)

	local arcContainer = Instance.new("Frame")
	arcContainer.Name = "PhaseArc"
	arcContainer.AnchorPoint = Vector2.new(0.5, 0)
	arcContainer.Position = UDim2.new(0.5, 0, 0, 122)
	arcContainer.Size = UDim2.fromOffset(340, 32)
	arcContainer.BackgroundTransparency = 1
	arcContainer.Visible = false
	arcContainer.ZIndex = 12
	arcContainer.Parent = root

	local phaseArcDots: { [string]: Frame } = {}
	local totalPhases = #PHASE_ARC_ORDER
	local dotSpacing = 340 / (totalPhases - 1)

	for index, phaseName in PHASE_ARC_ORDER do
		local x = (index - 1) * dotSpacing

		if index > 1 then
			local line = Instance.new("Frame")
			line.Name = "Line_" .. tostring(index)
			line.AnchorPoint = Vector2.new(0, 0.5)
			line.Position = UDim2.fromOffset(x - dotSpacing + 7, 10)
			line.Size = UDim2.fromOffset(dotSpacing - 14, 2)
			line.BackgroundColor3 = Theme.Colors.TextMuted
			line.BackgroundTransparency = 0.5
			line.BorderSizePixel = 0
			line.ZIndex = 12
			line.Parent = arcContainer
		end

		local dot = Instance.new("Frame")
		dot.Name = "Dot_" .. phaseName
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromOffset(x, 10)
		dot.Size = UDim2.fromOffset(10, 10)
		dot.BackgroundColor3 = Theme.Colors.TextMuted
		dot.BorderSizePixel = 0
		dot.ZIndex = 13
		dot.Parent = arcContainer
		Components.Corner(dot, 5)
		phaseArcDots[phaseName] = dot

		local label = Components.Label(
			arcContainer,
			"Label_" .. phaseName,
			PHASE_ARC_LABELS[phaseName] or phaseName,
			8
		)
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.fromOffset(x, 17)
		label.Size = UDim2.fromOffset(44, 12)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextColor3 = Theme.Colors.TextMuted
		label.ZIndex = 13
	end

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

	-- Thin cooldown bar below the role action button
	local cooldownBar = Instance.new("Frame")
	cooldownBar.Name = "AbilityCooldownBar"
	cooldownBar.Size = UDim2.new(1, -32, 0, 4)
	cooldownBar.Position = UDim2.fromOffset(16, 298)
	cooldownBar.BackgroundColor3 = Theme.Colors.PanelSoft
	cooldownBar.BackgroundTransparency = 0.3
	cooldownBar.BorderSizePixel = 0
	cooldownBar.Visible = false
	cooldownBar.Parent = mission

	local cooldownFill = Instance.new("Frame")
	cooldownFill.Name = "CooldownFill"
	cooldownFill.Size = UDim2.fromScale(0, 1)
	cooldownFill.BackgroundColor3 = Theme.Colors.Gold
	cooldownFill.BorderSizePixel = 0
	cooldownFill.Parent = cooldownBar
	Components.Corner(cooldownBar, 2)
	Components.Corner(cooldownFill, 2)

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

	local monsterPanel = Instance.new("CanvasGroup")
	monsterPanel.Name = "MonsterPanel"
	monsterPanel.AnchorPoint = Vector2.new(1, 1)
	monsterPanel.Position = UDim2.new(1, -16, 1, -88)
	monsterPanel.Size = UDim2.fromOffset(200, 90)
	monsterPanel.BackgroundColor3 = Theme.Colors.Panel
	monsterPanel.BackgroundTransparency = 0.1
	monsterPanel.BorderSizePixel = 0
	monsterPanel.GroupTransparency = 0
	monsterPanel.Visible = false
	monsterPanel.ZIndex = 22
	monsterPanel.Parent = root
	Components.Corner(monsterPanel, 8)
	Components.Stroke(monsterPanel, Theme.Colors.DangerBright, 1)

	local monsterNameLabel = Components.Label(
		monsterPanel,
		"MonsterName",
		"▸ MONSTER",
		13,
		Theme.Typography.HeadingFont
	)
	monsterNameLabel.Position = UDim2.fromOffset(10, 6)
	monsterNameLabel.Size = UDim2.new(1, -20, 0, 18)
	monsterNameLabel.TextColor3 = Theme.Colors.DangerBright
	monsterNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	monsterNameLabel.ZIndex = 23

	local monsterStaminaLabel = Components.Label(
		monsterPanel,
		"StaminaLabel",
		"STAMINA",
		10,
		Theme.Typography.CaptionFont
	)
	monsterStaminaLabel.Position = UDim2.fromOffset(10, 22)
	monsterStaminaLabel.Size = UDim2.new(1, -20, 0, 10)
	monsterStaminaLabel.TextColor3 = Theme.Colors.TextMuted
	monsterStaminaLabel.TextXAlignment = Enum.TextXAlignment.Left
	monsterStaminaLabel.ZIndex = 23

	local monsterStaminaTrack = Instance.new("Frame")
	monsterStaminaTrack.Name = "StaminaTrack"
	monsterStaminaTrack.Position = UDim2.fromOffset(10, 30)
	monsterStaminaTrack.Size = UDim2.new(1, -20, 0, 8)
	monsterStaminaTrack.BackgroundColor3 = Theme.Colors.Ghost
	monsterStaminaTrack.BackgroundTransparency = 0.55
	monsterStaminaTrack.BorderSizePixel = 0
	monsterStaminaTrack.ZIndex = 23
	monsterStaminaTrack.Parent = monsterPanel
	Components.Corner(monsterStaminaTrack, 4)

	local monsterStaminaFill = Instance.new("Frame")
	monsterStaminaFill.Name = "StaminaFill"
	monsterStaminaFill.Size = UDim2.fromScale(0, 1)
	monsterStaminaFill.BackgroundColor3 = Theme.Colors.DangerBright
	monsterStaminaFill.BorderSizePixel = 0
	monsterStaminaFill.ZIndex = 24
	monsterStaminaFill.Parent = monsterStaminaTrack
	Components.Corner(monsterStaminaFill, 4)

	local monsterAbilityLabel = Components.Label(
		monsterPanel,
		"AbilityState",
		"ABILITY READY",
		11,
		Theme.Typography.CaptionFont
	)
	monsterAbilityLabel.Position = UDim2.fromOffset(10, 41)
	monsterAbilityLabel.Size = UDim2.new(1, -20, 0, 26)
	monsterAbilityLabel.TextSize = 10
	monsterAbilityLabel.RichText = true
	monsterAbilityLabel.TextColor3 = Theme.Colors.Gold
	monsterAbilityLabel.TextXAlignment = Enum.TextXAlignment.Left
	monsterAbilityLabel.TextYAlignment = Enum.TextYAlignment.Center
	monsterAbilityLabel.ZIndex = 23

	local monsterNoteLabel = Components.Label(
		monsterPanel,
		"MonsterNote",
		"",
		9,
		Theme.Typography.CaptionFont
	)
	monsterNoteLabel.Position = UDim2.fromOffset(10, 68)
	monsterNoteLabel.Size = UDim2.new(1, -20, 0, 20)
	monsterNoteLabel.TextWrapped = true
	monsterNoteLabel.TextColor3 = Theme.Colors.TextMuted
	monsterNoteLabel.TextXAlignment = Enum.TextXAlignment.Left
	monsterNoteLabel.TextYAlignment = Enum.TextYAlignment.Top
	monsterNoteLabel.ZIndex = 23

	-- Live player roster panel — right side, visible during active round phases
	local rosterPanel = Instance.new("Frame")
	rosterPanel.Name = "PlayerRoster"
	rosterPanel.AnchorPoint = Vector2.new(1, 1)
	rosterPanel.Position = UDim2.new(1, -18, 1, -96)
	rosterPanel.Size = UDim2.fromOffset(180, 0)
	rosterPanel.AutomaticSize = Enum.AutomaticSize.Y
	rosterPanel.BackgroundColor3 = Theme.Colors.Panel
	rosterPanel.BackgroundTransparency = 0.18
	rosterPanel.BorderSizePixel = 0
	rosterPanel.Visible = false
	rosterPanel.ZIndex = 18
	rosterPanel.Parent = root
	Components.Corner(rosterPanel, 8)

	local rosterLayout = Instance.new("UIListLayout")
	rosterLayout.Padding = UDim.new(0, 0)
	rosterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rosterLayout.Parent = rosterPanel

	local rosterPadding = Instance.new("UIPadding")
	rosterPadding.PaddingTop = UDim.new(0, 8)
	rosterPadding.PaddingBottom = UDim.new(0, 8)
	rosterPadding.PaddingLeft = UDim.new(0, 10)
	rosterPadding.PaddingRight = UDim.new(0, 10)
	rosterPadding.Parent = rosterPanel

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

	-- Haunt meter — ghost-only progress bar fed by GhostSync snapshots.
	local hauntPanel = Instance.new("Frame")
	hauntPanel.Name = "HauntPanel"
	hauntPanel.AnchorPoint = Vector2.new(1, 0)
	hauntPanel.Position = UDim2.new(1, -18, 0, 158)
	hauntPanel.Size = UDim2.fromOffset(132, 52)
	hauntPanel.BackgroundColor3 = Theme.Colors.Panel
	hauntPanel.BackgroundTransparency = 0.08
	hauntPanel.BorderSizePixel = 0
	hauntPanel.Visible = false
	hauntPanel.ZIndex = 35
	hauntPanel.Parent = root
	Components.Corner(hauntPanel, 8)
	Components.Stroke(hauntPanel, Theme.Colors.Ghost, 1)

	local hauntLabel = Components.Label(
		hauntPanel,
		"HauntLabel",
		"HAUNT",
		10,
		Theme.Typography.CaptionFont
	)
	hauntLabel.Position = UDim2.fromOffset(10, 5)
	hauntLabel.Size = UDim2.new(1, -20, 0, 12)
	hauntLabel.TextColor3 = Theme.Colors.Ghost
	hauntLabel.TextXAlignment = Enum.TextXAlignment.Left
	hauntLabel.ZIndex = 36

	local hauntTrack = Instance.new("Frame")
	hauntTrack.Name = "HauntTrack"
	hauntTrack.Position = UDim2.fromOffset(10, 20)
	hauntTrack.Size = UDim2.new(1, -20, 0, 8)
	hauntTrack.BackgroundColor3 = Theme.Colors.Ghost
	hauntTrack.BackgroundTransparency = 0.55
	hauntTrack.BorderSizePixel = 0
	hauntTrack.ZIndex = 36
	hauntTrack.Parent = hauntPanel
	Components.Corner(hauntTrack, 4)

	local hauntFill = Instance.new("Frame")
	hauntFill.Name = "HauntFill"
	hauntFill.Size = UDim2.fromScale(0, 1)
	hauntFill.BackgroundColor3 = Theme.Colors.Ghost
	hauntFill.BorderSizePixel = 0
	hauntFill.ZIndex = 37
	hauntFill.Parent = hauntTrack
	Components.Corner(hauntFill, 4)

	local hauntHint = Components.Label(
		hauntPanel,
		"HauntHint",
		"Fill the meter with ghost deeds",
		9,
		Theme.Typography.CaptionFont
	)
	hauntHint.Position = UDim2.fromOffset(10, 32)
	hauntHint.Size = UDim2.new(1, -20, 0, 16)
	hauntHint.TextColor3 = Theme.Colors.TextMuted
	hauntHint.TextXAlignment = Enum.TextXAlignment.Left
	hauntHint.TextWrapped = true
	hauntHint.ZIndex = 36

	local eliminatedBanner = Instance.new("Frame")
	eliminatedBanner.Name = "EliminatedBanner"
	eliminatedBanner.AnchorPoint = Vector2.new(0.5, 0)
	eliminatedBanner.Position = UDim2.new(0.5, 0, 0, 60)
	eliminatedBanner.Size = UDim2.fromOffset(320, 48)
	eliminatedBanner.BackgroundColor3 = Theme.Colors.Panel
	eliminatedBanner.BackgroundTransparency = 0.12
	eliminatedBanner.BorderSizePixel = 0
	eliminatedBanner.Visible = false
	eliminatedBanner.ZIndex = 30
	eliminatedBanner.Parent = root
	Components.Corner(eliminatedBanner, 8)
	Components.Stroke(eliminatedBanner, Theme.Colors.TextMuted, 1)

	local elimTitle = Components.Label(
		eliminatedBanner,
		"Title",
		"ELIMINATED",
		13,
		Enum.Font.GothamBold
	)
	elimTitle.AnchorPoint = Vector2.new(0.5, 0)
	elimTitle.Position = UDim2.new(0.5, 0, 0, 6)
	elimTitle.Size = UDim2.new(1, 0, 0, 18)
	elimTitle.TextXAlignment = Enum.TextXAlignment.Center
	elimTitle.TextColor3 = Theme.Colors.TextMuted
	elimTitle.ZIndex = 31

	local elimSub = Components.Label(
		eliminatedBanner,
		"Sub",
		"You are spectating. Watch the mystery unfold.",
		10
	)
	elimSub.AnchorPoint = Vector2.new(0.5, 0)
	elimSub.Position = UDim2.new(0.5, 0, 0, 26)
	elimSub.Size = UDim2.new(1, -16, 0, 16)
	elimSub.TextXAlignment = Enum.TextXAlignment.Center
	elimSub.TextColor3 = Theme.Colors.TextMuted
	elimSub.TextTransparency = 0.3
	elimSub.ZIndex = 31

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
		notebookBadge = nil,
		lastSeenEvidenceCount = 0,
		lastEvidenceCountForPop = 0,
		settingsButton = nil,
		codexButton = nil,
		actionHandler = actionHandler,
		resolveImage = imageResolver or function(_key: string): string?
			return nil
		end,
		phaseLabel = phaseLabel,
		timerLabel = timerLabel,
		timerPulseConn = nil,
		timerPulsing = false,
		timerBar = timerBar,
		timerFill = timerFill,
		phaseArc = nil,
		phaseArcDots = {},
		progressLabel = progressLabel,
		roleTitle = roleTitle,
		roleIcon = roleIcon,
		roleDescription = roleDescription,
		roleAction = roleAction,
		cooldownBar = cooldownBar,
		cooldownFill = cooldownFill,
		abilityBarMaxCooldown = 0,
		objectiveText = objectiveText,
		objectiveFill = objectiveFill,
		healthText = healthText,
		healthFill = healthFill,
		stateBadge = stateBadge,
		ghostBadge = ghostBadge,
		ghostBadgePulse = nil,
		ghostBadgeReducedMotion = false,
		ghostMode = false,
		hauntPanel = hauntPanel,
		hauntFill = hauntFill,
		hauntHint = hauntHint,
		eliminatedBanner = nil,
		eliminatedMode = false,
		hotbar = hotbar,
		monsterPanel = monsterPanel,
		monsterNameLabel = monsterNameLabel,
		monsterStaminaFill = monsterStaminaFill,
		monsterAbilityLabel = monsterAbilityLabel,
		monsterNoteLabel = monsterNoteLabel,
		monsterPanelVisible = false,
		rosterPanel = rosterPanel,
		rosterPanelVisible = false,
		lastRosterSignature = "",
		evidenceSignature = "",
		inventorySignature = "",
		streakToastShown = false,
		notebook = notebook,
		evidenceList = nil :: any,
		evidenceSummary = nil :: any,
		settings = settings,
		settingsList = nil :: any,
		voteModal = voteModal,
		voteModalTitleLabel = nil,
		voteCountLabel = nil,
		voteWarningLabel = nil,
		voteList = nil :: any,
		resultModal = resultModal,
		resultTitle = nil :: any,
		resultBody = nil :: any,
		rewardText = nil :: any,
		voteRevealList = nil :: any,
		progression = progression,
		progressionSummary = nil :: any,
		progressionList = nil :: any,
		codex = nil,
		codexSummary = nil,
		codexList = nil,
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
		roundSummaryOverlay = nil,
		roundSummaryToken = 0,
		deathCinematicToken = 0,
		deathCinematicOverlay = nil,
		voteRevealToken = 0,
		voteRevealOwnsResults = false,
		voteConfetti = nil,
		currentState = nil,
		legacyRound = nil,
		legacyPlayer = nil,
		currentVoteSignature = "",
		localVoteHasLocked = false,
		dayObjectiveNotifiedRound = nil,
		evidenceNotifiedRound = nil,
		evidenceStatuses = {},
		comboSelectionId = nil,
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
		keybindHintToken = 0,
		keybindHintOverlay = nil,
		lastCooldownText = nil,
		lastCooldownActive = false,
		roleActionBaseText = "ABILITY UNAVAILABLE",
		lastAnimatedXP = -1,
		lastAnimatedTokens = -1,
		lastHealthForFlash = 100,
		rewardAnimationToken = 0,
		destroyed = false,
	}, GameView)

	self.phaseArc = arcContainer
	self.phaseArcDots = phaseArcDots
	self.eliminatedBanner = eliminatedBanner

	self:_buildNotebook()
	self:_buildSettings()
	self:_buildVote()
	self:_buildResults()
	self:_buildTargetSelector()
	self:_buildProgression()
	self:_buildCodex()
	self:_buildAnnouncements()
	self:_buildLobby()

	self.notebookButton = makeMenuButton(menu, "NotebookButton", "CLUES  [N]", UDim2.fromOffset(10, 0), function()
		self:ToggleNotebook()
	end)
	local notebookBadge = Components.Label(
		self.notebookButton :: Instance,
		"EvidenceBadge",
		"0",
		10,
		Enum.Font.GothamBold
	)
	notebookBadge.AnchorPoint = Vector2.new(1, 0)
	notebookBadge.Position = UDim2.new(1, 4, 0, -4)
	notebookBadge.Size = UDim2.fromOffset(20, 20)
	notebookBadge.BackgroundColor3 = Theme.Colors.DangerBright
	notebookBadge.BackgroundTransparency = 0
	notebookBadge.TextColor3 = Color3.new(1, 1, 1)
	notebookBadge.TextXAlignment = Enum.TextXAlignment.Center
	notebookBadge.ZIndex = (self.notebookButton :: Instance).ZIndex + 1
	notebookBadge.Visible = false
	Components.Corner(notebookBadge, 10)
	self.notebookBadge = notebookBadge

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
	local compactTouch = isCompactViewport(viewport)
	if compactTouch then
		-- Phones and small touch screens get the dedicated compact pass in
		-- _applyCompactTouchLayout; shrink the whole HUD and route the branch
		-- chain below through the desktop path so the pass overrides it.
		narrow = false
		compact = false
		self.uiScale.Scale = COMPACT_UI_SCALE
	end

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
		if self.codexButton then
			self.codexButton.Position = UDim2.fromOffset(6, 46)
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
			self.lobbyPanel.Size = UDim2.new(1, -16, 0, 172)
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
		if self.codexButton then
			self.codexButton.Position = UDim2.fromOffset(10, 96)
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
			self.lobbyPanel.Size = UDim2.fromOffset(300, 172)
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
		if self.codexButton then
			self.codexButton.Position = UDim2.fromOffset(10, 96)
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
			self.lobbyPanel.Size = UDim2.fromOffset(300, 172)
		end
	end

	self:_applyCompactTouchLayout(compactTouch, viewport)

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

-- Touch / small-viewport HUD pass. Runs after the desktop branch chain so
-- every write here is additive; when `active` is false it restores the
-- constructor defaults for the properties the desktop branches never touch.
-- With the root anchored top-centre and scaled by COMPACT_UI_SCALE, the
-- bottom strip of the physical screen stays free for Roblox's dynamic
-- thumbstick (bottom-left ~180x180 px) and jump button (bottom-right
-- ~180x180 px); no interactive HUD is placed inside those reserves.
function GameView:_applyCompactTouchLayout(active: boolean, viewport: Vector2)
	local topScale = ensureLayoutScale(self.topStatus, "CompactTopScale")
	local missionScale = ensureLayoutScale(self.missionPanel, "CompactMissionScale")
	local rosterPanel = self.rosterPanel
	local rosterScale = if rosterPanel then ensureLayoutScale(rosterPanel, "CompactRosterScale") else nil
	local toastLayout = self.toastList:FindFirstChildOfClass("UIListLayout")
	local monsterPanel = self.monsterPanel
	local hauntPanel = self.hauntPanel
	local notebookButton = self.notebookButton
	local settingsButton = self.settingsButton
	local codexButton = self.codexButton
	local lobby = self.lobbyPanel
	local voteMin = ensureMinSizeConstraint(self.voteModal)
	local targetMin = ensureMinSizeConstraint(self.targetModal)
	local resultMin = ensureMinSizeConstraint(self.resultModal)

	if active then
		-- Centre the scaled canvas horizontally and pin it to the top so the
		-- bottom edge of the screen carries no HUD at all.
		self.root.AnchorPoint = Vector2.new(0.5, 0)
		self.root.Position = UDim2.fromScale(0.5, 0)

		-- Phase banner: top-centre, slightly reduced so long phase titles do
		-- not reach the mission panel or the menu column.
		topScale.Scale = 0.85
		self.topStatus.AnchorPoint = Vector2.new(0.5, 0)
		self.topStatus.Position = UDim2.new(0.5, 0, 0, 6)
		self.topStatus.Size = UDim2.fromOffset(460, 96)

		-- Menu cluster: compact column pinned to the top-right corner, clear
		-- of the top-centre phase banner.
		self.menuPanel.AnchorPoint = Vector2.new(1, 0)
		self.menuPanel.Position = UDim2.new(1, -6, 0, 6)
		self.menuPanel.Size = UDim2.fromOffset(118, 112)
		if notebookButton then
			notebookButton.Size = UDim2.fromOffset(112, 34)
			notebookButton.Position = UDim2.fromOffset(6, 0)
		end
		if settingsButton then
			settingsButton.Size = UDim2.fromOffset(112, 34)
			settingsButton.Position = UDim2.fromOffset(6, 38)
		end
		if codexButton then
			codexButton.Size = UDim2.fromOffset(112, 34)
			codexButton.Position = UDim2.fromOffset(6, 76)
		end

		-- Mission panel: keep the desktop-tuned inner layout but render it
		-- smaller so it stays well left of the screen midline.
		missionScale.Scale = 0.8
		self.missionPanel.Position = UDim2.fromOffset(6, 6)
		self.missionPanel.Size = UDim2.fromOffset(280, 310)

		-- Bottom band: health and hotbar side by side, pulled toward the
		-- centre so both bottom corners stay clear. The root is scaled and
		-- centred, so convert the 180px screen reserves into layout-space
		-- x coordinates for this viewport.
		local halfX = viewport.X / 2
		local reserveSpan = math.max(0, (halfX - 180) / COMPACT_UI_SCALE)
		local leftClear = halfX - reserveSpan
		local rightClear = halfX + reserveSpan
		local healthX = leftClear + 8
		local hotbarX = healthX + 202
		self.healthPanel.AnchorPoint = Vector2.new(0, 1)
		self.healthPanel.Position = UDim2.new(0, healthX, 1, -10)
		self.healthPanel.Size = UDim2.fromOffset(190, 62)
		self.hotbar.AnchorPoint = Vector2.new(0, 1)
		self.hotbar.Position = UDim2.new(0, hotbarX, 1, -8)
		self.hotbar.Size = UDim2.new(0, math.max(120, rightClear - 12 - hotbarX), 0, 74)
		self.interaction.Position = UDim2.new(0.5, 0, 1, -92)
		self.interaction.Size = UDim2.fromOffset(360, 54)

		-- Toasts drop in under the phase banner instead of the bottom-right,
		-- clear of the mission panel and the jump reserve.
		self.toastList.AnchorPoint = Vector2.new(0.5, 0)
		self.toastList.Position = UDim2.new(0.5, 0, 0, 104)
		self.toastList.Size = UDim2.fromOffset(340, 150)
		if toastLayout then
			toastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		end
		self.announcement.Size = UDim2.fromOffset(440, 82)

		-- Side panels that default to the bottom-right corner move up above
		-- the jump reserve; ghost haunt meter moves under the banner's right
		-- edge so it cannot collide with the roster column.
		if rosterPanel then
			rosterPanel.AnchorPoint = Vector2.new(1, 0)
			rosterPanel.Position = UDim2.new(1, -6, 0, 132)
		end
		if rosterScale then
			rosterScale.Scale = 0.72
		end
		if monsterPanel then
			monsterPanel.Position = UDim2.new(1, -6, 1, -140)
		end
		if hauntPanel then
			hauntPanel.Position = UDim2.new(1, -140, 0, 110)
		end

		-- Lobby: compact bottom-centre sheet (hotbar and health are hidden
		-- during the Lobby phase) with the ready/progress buttons on-screen.
		if lobby then
			lobby.AnchorPoint = Vector2.new(0.5, 1)
			lobby.Position = UDim2.new(0.5, 0, 1, -10)
			lobby.Size = UDim2.new(0, math.min(520, math.max(300, rightClear - leftClear - 16)), 0, 168)
			local strip = lobby:FindFirstChild("HeaderStrip")
			if strip and strip:IsA("GuiObject") then
				strip.Size = UDim2.new(1, 0, 0, 32)
			end
			local progressionButton = lobby:FindFirstChild("Progression")
			if progressionButton and progressionButton:IsA("GuiObject") then
				progressionButton.Position = UDim2.new(0.55, 6, 0, 104)
				progressionButton.Size = UDim2.new(0.45, -24, 0, 52)
			end
			self.lobbyText.Position = UDim2.fromOffset(18, 4)
			self.lobbyText.Size = UDim2.new(1, -36, 0, 26)
			self.lobbyRoster.Visible = true
			self.lobbyRoster.Position = UDim2.fromOffset(18, 36)
			self.lobbyRoster.Size = UDim2.new(1, -36, 0, 60)
			self.lobbyTip.Visible = false
			self.readyButton.Position = UDim2.fromOffset(18, 104)
			self.readyButton.Size = UDim2.new(0.55, -24, 0, 52)
		end

		-- Keep the scale-sized modals usable on short viewports.
		voteMin.MinSize = Vector2.new(440, 300)
		targetMin.MinSize = Vector2.new(380, 300)
		resultMin.MinSize = Vector2.new(460, 280)
	else
		self.root.AnchorPoint = Vector2.new(0, 0)
		self.root.Position = UDim2.fromScale(0, 0)
		topScale.Scale = 1
		missionScale.Scale = 1
		if notebookButton then
			notebookButton.Size = UDim2.fromOffset(130, 40)
		end
		if settingsButton then
			settingsButton.Size = UDim2.fromOffset(130, 40)
		end
		if codexButton then
			codexButton.Size = UDim2.fromOffset(130, 40)
		end
		self.healthPanel.AnchorPoint = Vector2.new(0, 1)
		self.toastList.AnchorPoint = Vector2.new(1, 1)
		if toastLayout then
			toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		end
		if rosterPanel then
			rosterPanel.AnchorPoint = Vector2.new(1, 1)
			rosterPanel.Position = UDim2.new(1, -18, 1, -96)
		end
		if rosterScale then
			rosterScale.Scale = 1
		end
		if monsterPanel then
			monsterPanel.Position = UDim2.new(1, -16, 1, -88)
		end
		if hauntPanel then
			hauntPanel.Position = UDim2.new(1, -18, 0, 158)
		end
		if lobby then
			-- Desktop restore matches the compact ready-up card that
			-- _buildLobby authors. The old values here re-created the retired
			-- 520x520 layout (buttons at y 446) inside a ~172px panel, pushing
			-- READY UP off the bottom of the screen.
			local strip = lobby:FindFirstChild("HeaderStrip")
			if strip and strip:IsA("GuiObject") then
				strip.Size = UDim2.new(1, 0, 0, 28)
			end
			local progressionButton = lobby:FindFirstChild("Progression")
			if progressionButton and progressionButton:IsA("GuiObject") then
				progressionButton.Position = UDim2.fromOffset(12, 98)
				progressionButton.Size = UDim2.new(1, -24, 0, 44)
			end
			self.lobbyText.Position = UDim2.fromOffset(12, 4)
			self.lobbyText.Size = UDim2.new(1, -24, 0, 20)
			self.lobbyRoster.Visible = false
			self.lobbyTip.Visible = false
			self.readyButton.Position = UDim2.fromOffset(12, 38)
			self.readyButton.Size = UDim2.new(1, -24, 0, 52)
		end
		voteMin.MinSize = Vector2.zero
		targetMin.MinSize = Vector2.zero
		resultMin.MinSize = Vector2.zero
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
		if self.localVoteHasLocked then
			setModalVisible(self.voteModal, false)
		else
			local voteReqPlayer = if type(self.currentState) == "table" then self.currentState.player else nil
			local voteReqBody = if readString(voteReqPlayer, "role", "") == "Murderer"
				then "Name someone before the fire goes out. Redirect suspicion — every vote matters."
				else "Choose one suspect before the fire goes out."
			self:Notify("Vote required", voteReqBody, "Warning")
		end
	end)
	local voteHeader = self.voteModal:FindFirstChild("Header")
	if voteHeader and voteHeader:IsA("Frame") then
		local voteHeaderTitle = voteHeader:FindFirstChild("Title")
		if voteHeaderTitle and voteHeaderTitle:IsA("TextLabel") then
			-- Reserve 88px for the count and 8px gaps on both sides.
			voteHeaderTitle.Size = UDim2.new(1, -212, 1, 0)
			self.voteModalTitleLabel = voteHeaderTitle
		end
	end
	local voteCountLabel = Components.Label(
		self.voteModal,
		"VoteCountLabel",
		"",
		11,
		Enum.Font.GothamBold
	)
	voteCountLabel.AnchorPoint = Vector2.new(1, 0)
	voteCountLabel.Position = UDim2.new(1, -96, 0, 18)
	voteCountLabel.Size = UDim2.fromOffset(88, 20)
	voteCountLabel.TextXAlignment = Enum.TextXAlignment.Right
	voteCountLabel.TextColor3 = Theme.Colors.TextMuted
	self.voteCountLabel = voteCountLabel
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
	self.voteWarningLabel = warning
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
				elseif definition.unlockKind == "Streak"
					then "Play " .. tostring(definition.unlockAmount) .. " days in a row"
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

function GameView:_buildCodex()
	local codex = makeModal(self.root, "MonsterCodex", UDim2.new(0.72, 0, 0.78, 0))
	self.codex = codex
	makeHeader(codex, "MONSTER CODEX", function()
		setModalVisible(codex, false)
	end)
	local summary = Components.Label(
		codex,
		"Summary",
		"Every monster you face is recorded here permanently.",
		15,
		Enum.Font.GothamBold
	)
	summary.Position = UDim2.fromOffset(20, 58)
	summary.Size = UDim2.new(1, -40, 0, 50)
	summary.TextColor3 = Theme.Colors.Gold
	summary.TextXAlignment = Enum.TextXAlignment.Center
	self.codexSummary = summary

	local list = Instance.new("ScrollingFrame")
	list.Name = "CodexList"
	list.Position = UDim2.fromOffset(18, 112)
	list.Size = UDim2.new(1, -36, 1, -130)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = codex
	local layout = Components.List(list, 9)
	addCanvasSizing(list, layout)
	self.codexList = list

	self.codexButton = makeMenuButton(
		self.menuPanel,
		"CodexButton",
		"CODEX",
		UDim2.fromOffset(10, 96),
		function()
			self:ToggleCodex()
		end
	)
end

function GameView:_codexCard(
	titleText: string,
	bodyText: string,
	countersText: string,
	discovered: boolean
)
	local list = self.codexList
	if not list then
		return
	end
	local card = Components.Panel(list, "CodexCard")
	card:SetAttribute("Generated", true)
	card.Size = UDim2.new(1, -8, 0, 132)

	local silhouette = Instance.new("Frame")
	silhouette.Name = "Silhouette"
	silhouette.Position = UDim2.fromOffset(12, 12)
	silhouette.Size = UDim2.fromOffset(108, 108)
	silhouette.BorderSizePixel = 0
	silhouette.BackgroundColor3 = Theme.Colors.Background
	silhouette.BackgroundTransparency = if discovered then 0.35 else 0.05
	silhouette.Parent = card
	Components.Corner(silhouette, Theme.SmallCornerRadius)

	local glyph = Components.Label(
		silhouette,
		"Glyph",
		if discovered then string.sub(titleText, 1, 1) else "?",
		34,
		Enum.Font.GothamBold
	)
	glyph.Position = UDim2.fromOffset(0, 0)
	glyph.Size = UDim2.new(1, 0, 1, 0)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	glyph.TextColor3 = if discovered then Theme.Colors.Gold else Theme.Colors.TextMuted
	glyph.TextTransparency = if discovered then 0 else 0.45

	local title = Components.Label(card, "Title", titleText, 16, Enum.Font.GothamBold)
	title.Position = UDim2.fromOffset(132, 7)
	title.Size = UDim2.new(1, -144, 0, 26)
	title.TextColor3 = if discovered then Theme.Colors.Gold else Theme.Colors.TextMuted

	local body = Components.Label(card, "Body", bodyText, 12)
	body.Position = UDim2.fromOffset(132, 35)
	body.Size = UDim2.new(1, -144, 0, 70)
	body.TextColor3 = Theme.Colors.TextMuted
	body.Font = Theme.Typography.CaptionFont
	body.TextSize = Theme.Typography.CaptionSize
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextTruncate = Enum.TextTruncate.AtEnd

	local counters = Components.Label(card, "Counters", countersText, 12, Enum.Font.GothamBold)
	counters.Position = UDim2.fromOffset(132, 107)
	counters.Size = UDim2.new(1, -144, 0, 18)
	counters.TextColor3 = if discovered then Theme.Colors.Text else Theme.Colors.TextMuted
end

function GameView:_updateCodex(state: any)
	local list = self.codexList
	if not list then
		return
	end
	Components.ClearGenerated(list)
	local profileSnapshot = if type(state) == "table" then state.profile else nil
	local profile = if type(profileSnapshot) == "table" then profileSnapshot.profile else nil
	local monsterStats = if type(profile) == "table" and type(profile.monsterStats) == "table"
		then profile.monsterStats
		else {}
	local discoveredCount = 0
	for _, monsterId in MonsterOrder do
		local definition = PublicMonsterCatalog[monsterId]
		local record = monsterStats[monsterId]
		local encounters = math.floor(readNumber(record, "encounters", 0))
		local survivalCount = math.floor(readNumber(record, "survivals", 0))
		local identificationCount = math.floor(readNumber(record, "identifications", 0))
		if encounters > 0 and definition then
			discoveredCount += 1
			self:_codexCard(
				definition.displayName,
				string.format(
					"%s\nMovement: %s (%s)\nCounter: %s",
					definition.description,
					definition.movement.style,
					definition.movement.speed,
					definition.counterplay.summary
				),
				string.format(
					"Encounters %d · Survived %d · Identified %d",
					encounters,
					survivalCount,
					identificationCount
				),
				true
			)
		else
			self:_codexCard(
				"???",
				"Face this monster to unlock its file.",
				"Undiscovered",
				false
			)
		end
	end
	local summary = self.codexSummary
	if summary then
		summary.Text = string.format(
			"MONSTERS DISCOVERED  %d / %d\nSurvive the hunt and expose the culprit to fill each file.",
			discoveredCount,
			#MonsterOrder
		)
	end
end

function GameView:ToggleCodex()
	local codex = self.codex
	if not codex then
		return
	end
	setModalVisible(self.notebook, false)
	setModalVisible(self.settings, false)
	setModalVisible(self.progression, false)
	setModalVisible(self.resultModal, false)
	local willOpen = not modalTargetVisible(codex)
	if willOpen then
		self:_updateCodex(self.currentState)
	end
	setModalVisible(codex, willOpen)
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
	elseif self.lastActionControl:IsA("TextButton") then
		Components.SetButtonEnabled(self.lastActionControl :: TextButton, false)
	end
end

function GameView:HandleActionResult(accepted: boolean)
	local control = self.lastActionControl
	-- Feedback animations are for buttons only; playing PopIn on a modal
	-- frame can cancel its close animation and strand it visible.
	if control and control.Parent and control:IsA("TextButton") then
		Components.SetButtonEnabled(control :: TextButton, true)
		if accepted then
			HapticController.Impact()
			Motion.PopIn(control, { duration = 0.12 })
			Components.PlayUISound("success")
		else
			HapticController.Error()
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
	local state = self.currentState
	local chooseLocalRole = if type(state) == "table" and type(state.player) == "table"
		then readString(state.player, "role", "")
		else ""
	self.targetTitle.Text = if chooseLocalRole == "Murderer"
		then "Choose your target."
		else "Choose the living player affected by this action."
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
				local name = readString(participant, "displayName", "Unknown player")
				local health = readString(participant, "healthState", "Healthy")
				local button = Components.Button(self.targetList, {
					name = "Target_" .. participantId:gsub("[^%w]", "_"),
					text = name .. "  -  " .. health,
					size = UDim2.new(1, -8, 0, 48),
					color = if health == "Injured" or health == "Critical" or health == "Incapacitated"
					then Theme.Colors.Danger
					else Theme.Colors.PanelSoft,
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
			if chooseLocalRole == "Murderer"
				then "No targets available — all potential victims are out of reach."
				else "This action requires at least one other living player and was not sent.",
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
	-- Parked height must clear the REAL screen top, not just the inset origin:
	-- ScreenGuis render into the topbar zone, so at -110 the banner's bottom
	-- 30px (the body line) stayed visible under the topbar. 82 tall + 58 inset
	-- + margin = park at -160.
	banner.Position = UDim2.new(0.5, 0, 0, -160)
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
	-- Compact bottom-right ready-up card. The original 520x520 center panel
	-- (roster, camp tip, buttons at y 446) never survived _applyLayout: every
	-- branch shrank the panel to ~104px while the children kept their tall
	-- offsets, so READY UP rendered ~320px BELOW the screen edge and was
	-- unclickable. The card now owns a layout that fits the size the relayout
	-- actually gives it; the roster and tip stay as hidden data targets.
	local lobby = Components.Panel(self.root, "Lobby")
	lobby.AnchorPoint = Vector2.new(1, 1)
	lobby.Position = UDim2.new(1, -18, 1, -18)
	lobby.Size = UDim2.fromOffset(300, 172)
	-- Rustic cabin-wood header strip across the top of the lobby panel
	local headerStrip = Instance.new("Frame")
	headerStrip.Name = "HeaderStrip"
	headerStrip.Size = UDim2.new(1, 0, 0, 28)
	headerStrip.Position = UDim2.fromOffset(0, 0)
	headerStrip.BackgroundColor3 = Theme.Colors.WoodRust
	headerStrip.BackgroundTransparency = 0.30
	headerStrip.BorderSizePixel = 0
	headerStrip.ZIndex = 1
	headerStrip.Parent = lobby
	Components.Corner(headerStrip)
	local text = Components.Label(
		lobby,
		"LobbyText",
		"CAMPERS ARE ARRIVING",
		Theme.Typography.CaptionSize,
		Theme.Typography.HeadingFont
	)
	text.Position = UDim2.fromOffset(12, 4)
	text.Size = UDim2.new(1, -24, 0, 20)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextColor3 = Theme.Colors.Gold
	text.ZIndex = 2

	local roster = Instance.new("ScrollingFrame")
	roster.Name = "Roster"
	roster.Position = UDim2.fromOffset(18, 50)
	roster.Size = UDim2.new(1, -36, 0, 254)
	roster.BackgroundTransparency = 1
	roster.BorderSizePixel = 0
	roster.CanvasSize = UDim2.fromOffset(0, 0)
	roster.ScrollBarThickness = 4
	roster.Visible = false
	roster.Parent = lobby
	local rosterLayout = Components.List(roster, 6)
	addCanvasSizing(roster, rosterLayout)

	local tip = Components.Panel(lobby, "CampTip")
	tip.Position = UDim2.fromOffset(18, 312)
	tip.Size = UDim2.new(1, -36, 0, 118)
	tip.Visible = false
	tip.BackgroundColor3 = Theme.Colors.MossStone
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
		size = UDim2.new(1, -24, 0, 52),
		position = UDim2.fromOffset(12, 38),
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
		size = UDim2.new(1, -24, 0, 44),
		position = UDim2.fromOffset(12, 98),
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
			text = string.upper(abilityId:gsub("(%l)(%u)", "%1 %2"):gsub("-", " ")),
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
	self.targetTitle.Text = "Choose your transformation for tonight. Then choose a victim."
	for _, monsterId in MONSTER_PLAN_ORDER do
		local locationId = MONSTER_PLAN_LOCATIONS[monsterId]
		if not locationId then
			continue
		end
		local displayName = string.upper(monsterId:gsub("(%l)(%u)", "%1 %2"))
		local tagline = MONSTER_TAGLINES[monsterId] or ""

		-- Taller button to accommodate the tagline
		local button = Components.Button(self.targetList, {
			name = "Plan_" .. monsterId,
			text = "",
			size = UDim2.new(1, -8, 0, 60),
			color = Theme.Colors.Danger,
		})
		button:SetAttribute("Generated", true)

		-- Monster name label (top half of button)
		local nameLabel = Components.Label(
			button,
			"MonsterName",
			displayName,
			13,
			Enum.Font.GothamBold
		)
		nameLabel.AnchorPoint = Vector2.new(0, 0)
		nameLabel.Position = UDim2.fromOffset(10, 6)
		nameLabel.Size = UDim2.new(1, -14, 0, 22)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = Theme.Colors.White
		nameLabel.ZIndex = button.ZIndex + 1

		-- Tagline label (bottom half of button)
		if tagline ~= "" then
			local tagLabel = Components.Label(
				button,
				"Tagline",
				tagline,
				10,
				Theme.Typography.CaptionFont
			)
			tagLabel.AnchorPoint = Vector2.new(0, 0)
			tagLabel.Position = UDim2.fromOffset(10, 30)
			tagLabel.Size = UDim2.new(1, -14, 0, 22)
			tagLabel.TextXAlignment = Enum.TextXAlignment.Left
			tagLabel.TextColor3 = Theme.Colors.White
			tagLabel.TextTransparency = 0.28
			tagLabel.ZIndex = button.ZIndex + 1
		end

		button.Activated:Connect(function()
			setModalVisible(self.targetModal, false)
			self:_chooseParticipant("SetMurderPlan", {
				monsterId = monsterId,
				locationId = locationId,
			}, false)
		end)
	end
	-- Sabotage shares the dusk menu: undo a finished camp task while unseen.
	if self:_available(self.currentState, "Sabotage") then
		local sabotageButton = Components.Button(self.targetList, {
			name = "Plan_Sabotage",
			text = "SABOTAGE A FINISHED TASK",
			size = UDim2.new(1, -8, 0, 48),
			color = Theme.Colors.Amber,
		})
		sabotageButton:SetAttribute("Generated", true)
		sabotageButton.Activated:Connect(function()
			setModalVisible(self.targetModal, false)
			self:_send("Sabotage", {})
		end)
	end
	setModalVisible(self.notebook, false)
	setModalVisible(self.settings, false)
	setModalVisible(self.targetModal, true)
end

function GameView:_requestRoleAction()
	if self.ghostMode or self.eliminatedMode then
		return
	end
	local state = self.currentState
	local planEnabled = self:_available(state, "SetMurderPlan")
	if planEnabled then
		self:_chooseMurderPlan()
		return
	end
	if self:_available(state, "BuddyCheckIn") then
		self:_chooseParticipant("BuddyCheckIn", {}, false)
		return
	end
	-- Daytime Murderer: sabotage is the only role action, sent directly; the
	-- server picks the completed station the player is standing at.
	if self:_available(state, "Sabotage") then
		self:_send("Sabotage", {})
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
		self:Notify("No active ability", "Your current role uses equipment and investigation.", "Warning")
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
		local currentValue = math.clamp(
			tonumber(self.settingsValues[key]) or 1,
			minValue,
			maxValue
		)
		local initialFraction = if maxValue > minValue
			then (currentValue - minValue) / (maxValue - minValue)
			else 0

		local sliderTrack = Instance.new("Frame")
		sliderTrack.Name = "SliderTrack"
		sliderTrack.Size = UDim2.fromOffset(150, 8)
		sliderTrack.Position = UDim2.new(1, -178, 0.5, -4)
		sliderTrack.BackgroundColor3 = Theme.Colors.PanelSoft
		sliderTrack.BorderSizePixel = 0
		sliderTrack.Active = true
		sliderTrack.Parent = row
		Components.Corner(sliderTrack, 4)

		local sliderFill = Instance.new("Frame")
		sliderFill.Name = "SliderFill"
		sliderFill.Size = UDim2.fromScale(initialFraction, 1)
		sliderFill.BackgroundColor3 = Theme.Colors.Gold
		sliderFill.BorderSizePixel = 0
		sliderFill.Parent = sliderTrack
		Components.Corner(sliderFill, 4)

		local sliderThumb = Instance.new("Frame")
		sliderThumb.Name = "SliderThumb"
		sliderThumb.Size = UDim2.fromOffset(18, 18)
		sliderThumb.AnchorPoint = Vector2.new(0.5, 0.5)
		sliderThumb.Position = UDim2.new(initialFraction, 0, 0.5, 0)
		sliderThumb.BackgroundColor3 = Theme.Colors.White
		sliderThumb.BorderSizePixel = 0
		sliderThumb.ZIndex = sliderTrack.ZIndex + 1
		sliderThumb.Parent = sliderTrack
		Components.Corner(sliderThumb, 9)

		local valueLabel = Components.Label(
			row,
			"Value",
			string.format("%.1f", currentValue),
			12,
			Enum.Font.GothamBold
		)
		valueLabel.AnchorPoint = Vector2.new(1, 0.5)
		valueLabel.Position = UDim2.new(1, -12, 0.5, 0)
		valueLabel.Size = UDim2.fromOffset(22, 20)
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right

		local dragging = false
		local function fractionAt(inputX: number): number
			local trackX = sliderTrack.AbsolutePosition.X
			local trackWidth = sliderTrack.AbsoluteSize.X
			return if trackWidth > 0
				then math.clamp((inputX - trackX) / trackWidth, 0, 1)
				else 0
		end
		local function applyFraction(fraction: number)
			sliderFill.Size = UDim2.fromScale(fraction, 1)
			sliderThumb.Position = UDim2.new(fraction, 0, 0.5, 0)
			local sliderValue = minValue + fraction * (maxValue - minValue)
			valueLabel.Text = string.format("%.1f", sliderValue)
		end

		sliderTrack.InputBegan:Connect(function(input: InputObject)
			local inputType = input.UserInputType
			if inputType == Enum.UserInputType.MouseButton1
				or inputType == Enum.UserInputType.Touch
			then
				dragging = true
				applyFraction(fractionAt(input.Position.X))
				-- GuiObject.InputEnded only fires while the pointer is over the
				-- track, so watch the input object itself: releasing anywhere
				-- ends the drag and commits the value.
				local changedConn: RBXScriptConnection? = nil
				changedConn = input.Changed:Connect(function()
					if input.UserInputState ~= Enum.UserInputState.End then
						return
					end
					if changedConn then
						changedConn:Disconnect()
						changedConn = nil
					end
					if not dragging then
						return
					end
					dragging = false
					local finalFraction = fractionAt(input.Position.X)
					applyFraction(finalFraction)
					local rawValue = minValue + finalFraction * (maxValue - minValue)
					self:_setSetting(key, math.round(rawValue * 10) / 10)
				end)
			end
		end)
		sliderTrack.InputChanged:Connect(function(input: InputObject)
			local inputType = input.UserInputType
			if dragging
				and (
					inputType == Enum.UserInputType.MouseMovement
					or inputType == Enum.UserInputType.Touch
				)
			then
				applyFraction(fractionAt(input.Position.X))
			end
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
	-- Never register the settings modal as the pending action control: the
	-- ack's Motion.PopIn would cancel an in-flight close animation and leave
	-- the modal visibly stuck open with its visibility attribute false.
	local sent, reason = self.actionHandler("SetSettings", {
		settings = { [key] = value },
	})
	if not sent then
		Motion.Shake(self.settings)
		self:Notify("Saved on this device", reason or "Server profile sync is unavailable.", "Warning")
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
		name.TextTruncate = Enum.TextTruncate.AtEnd
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
			name.Text = readString(entry, "displayName", "Player")
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
	local inventory = if type(state) == "table" then state.inventory else nil
	-- Same skip-identical guard as the evidence list: the hotbar buttons
	-- (with their connections and icons) were destroyed and rebuilt on every
	-- snapshot even when nothing about the loadout changed.
	local signatureOk, signature = pcall(HttpService.JSONEncode, HttpService, {
		inventory = inventory,
		slot = self.selectedInventorySlot,
		eliminated = self.eliminatedMode,
	})
	if signatureOk then
		if signature == self.inventorySignature then
			return
		end
		self.inventorySignature = signature
	end
	local selected = GuiService.SelectedObject
	local restoreControllerFocus = not self.eliminatedMode
		and selected ~= nil
		and selected:IsDescendantOf(self.hotbar)
	if selected
		and selected:IsDescendantOf(self.hotbar)
		and self.eliminatedMode
	then
		GuiService.SelectedObject = nil
	end
	Components.ClearGenerated(self.hotbar)
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
			if self.eliminatedMode then
				Components.SetButtonEnabled(button, false)
			else
				Components.SetButtonEnabled(button, not self.ghostMode)
			end
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
	if self.eliminatedMode then
		return
	end
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

function GameView:ShowKeybindHint(phaseName: string)
	if self.destroyed then
		return
	end
	local entry = KeybindHints[phaseName]
	if not entry then
		return
	end
	local hints = if UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1)
		then entry.controller
		else entry.keyboard

	self.keybindHintToken += 1
	local token = self.keybindHintToken
	local previous = self.keybindHintOverlay
	if previous then
		Motion.Cancel(previous)
		previous:Destroy()
		self.keybindHintOverlay = nil
	end

	if Motion.IsReducedMotion(self.root) then
		local hintLines = hints
		if #hintLines > 0 then
			self:Notify(
				"Phase controls",
				table.concat(hintLines, "  ·  "),
				"Info"
			)
		end
		return
	end

	local panel = Instance.new("CanvasGroup")
	panel.Name = "KeybindHintPanel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -90)
	panel.Size = UDim2.fromOffset(320, 28 + 22 * #hints)
	panel.BackgroundColor3 = Theme.Colors.Black
	panel.BackgroundTransparency = 0.35
	panel.BorderSizePixel = 0
	panel.GroupTransparency = 0
	panel.ZIndex = 50
	panel.Parent = self.root
	self.keybindHintOverlay = panel
	Components.Corner(panel, 6)

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = panel

	for _, hint in hints do
		local row = Components.Label(
			panel,
			"HintRow_" .. hint,
			hint,
			12,
			Enum.Font.Gotham
		)
		row.Size = UDim2.new(1, -16, 0, 20)
		row.TextXAlignment = Enum.TextXAlignment.Center
		row.TextColor3 = Theme.Colors.White
		row.TextTransparency = 0.1
		row.ZIndex = 51
	end

	local function active(): boolean
		return not self.destroyed
			and self.keybindHintToken == token
			and panel.Parent ~= nil
	end

	Motion.FadeIn(panel, { duration = 0.3 })
	task.delay(4, function()
		if not active() then
			return
		end
		Motion.FadeOut(panel, {
			duration = 0.5,
			onComplete = function(_completed: boolean)
				if active() then
					panel:Destroy()
					if self.keybindHintOverlay == panel then
						self.keybindHintOverlay = nil
					end
				end
			end,
		})
	end)
end

function GameView:_updateEvidence(state: any, round: any)
	local board = if type(state) == "table" then state.evidence else nil
	local mystery = if type(state) == "table" then state.mystery else nil
	local counselors = if type(state) == "table" then state.counselors else nil
	local localPlayer = if type(state) == "table" then state.player else nil
	local localRole = readString(localPlayer, "role", "")
	-- Evidence changes a handful of times per round, but this rebuild ran on
	-- every state snapshot (including the 3s keepalive), tearing down and
	-- recreating the whole notebook list each time. Skip when the inputs are
	-- byte-identical; a spurious mismatch merely costs one rebuild.
	local signatureOk, signature = pcall(HttpService.JSONEncode, HttpService, {
		board = board,
		mystery = mystery,
		counselors = counselors,
		role = localRole,
		legacy = if type(round) == "table" then round.evidence else nil,
	})
	if signatureOk then
		if signature == self.evidenceSignature then
			return
		end
		self.evidenceSignature = signature
	end
	Components.ClearGenerated(self.evidenceList)
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
	local culpritLabel = if localRole == "Murderer" then "EVIDENCE AGAINST YOU" else "CULPRIT CLUES"
	self.evidenceSummary.Text = string.format(
		"%s\n%s  %d     MONSTER CLUES  %d     MYSTERY  %d/%d",
		readString(mystery, "title", "CURRENT CASE"),
		culpritLabel,
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
		-- Insight cards ride the culprit column but keep their own channel
		-- label, icon, and amber accent so derived deductions stand apart.
		local recordChannel = string.upper(readString(record, "channel", channel))
		local isInsight = recordChannel == "INSIGHT"
		local finderPrefix = if isInsight then "Combined by " else "Found by "
		local card = Components.EvidenceCard(self.evidenceList, {
			name = displayName,
			description = readString(record, "description", "No description recorded."),
			status = status,
			previousStatus = previousStatus,
			channel = recordChannel,
			footer = (if finder ~= "" then finderPrefix .. finder .. "  |  " else "")
				.. string.upper(status),
			accentColor = if isInsight then Theme.Colors.Amber else nil,
			iconAsset = self.resolveImage(
				if isInsight
					then "Evidence_Insight"
					elseif channel == "MONSTER" then "Evidence_Monster"
					else "Evidence_Culprit"
			),
		})
		card.Size = UDim2.new(1, -8, 0, Theme.Notebook.CardHeight)
		local verifyEnabled = self:_available(state, "VerifyEvidence")
		local noteEnabled = self:_available(state, "AddEvidenceNote")
		local presentEnabled = self:_available(state, "PresentEvidence")
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
		if presentEnabled and evidenceId ~= "" then
			local present = Components.Button(card, {
				name = "Present",
				text = "PRESENT",
				size = UDim2.fromOffset(104, 30),
				position = UDim2.new(1, -330, 1, -36),
				color = Theme.Colors.Amber,
			})
			present.ZIndex = card.ZIndex + 5
			present.Activated:Connect(function()
				self:_send("PresentEvidence", { evidenceId = evidenceId }, present)
			end)
		end
		-- Detective-only: pick two cards to test a combination. Insights are
		-- results, not ingredients, so they never get the button.
		if
			not isInsight
			and evidenceId ~= ""
			and self:_available(state, "CombineEvidence")
		then
			local isSelected = self.comboSelectionId == evidenceId
			local combine = Components.Button(card, {
				name = "Combine",
				text = if isSelected then "SELECTED" else "COMBINE",
				size = UDim2.fromOffset(104, 30),
				position = UDim2.new(1, -440, 1, -36),
				color = if isSelected then Theme.Colors.Success else Theme.Colors.Amber,
			})
			combine.ZIndex = card.ZIndex + 5
			combine.Activated:Connect(function()
				local selectedId = self.comboSelectionId
				if selectedId == evidenceId then
					self.comboSelectionId = nil
					combine.Text = "COMBINE"
				elseif selectedId then
					self.comboSelectionId = nil
					self:_send("CombineEvidence", {
						evidenceIdA = selectedId,
						evidenceIdB = evidenceId,
					}, combine)
				else
					self.comboSelectionId = evidenceId
					combine.Text = "SELECTED"
					self:Notify(
						"First clue selected",
						"Press COMBINE on a second clue to test the pairing.",
						"Info"
					)
				end
			end)
		end
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
			local clueId = readString(clue, "clueId", "")
			if self:_available(state, "PresentEvidence") and clueId ~= "" then
				footer.Size = UDim2.new(1, -146, 0, 24)
				local presentClue = Components.Button(card, {
					name = "Present",
					text = "PRESENT",
					size = UDim2.fromOffset(104, 30),
					position = UDim2.new(1, -116, 1, -36),
					color = Theme.Colors.Amber,
				})
				presentClue.ZIndex = card.ZIndex + 5
				presentClue.Activated:Connect(function()
					self:_send("PresentEvidence", { clueId = clueId }, presentClue)
				end)
			end
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
		local localIsGhost = readBoolean(localPlayer, "isGhost", false)
		local emptyText = if localRole == "Murderer"
			then "No evidence has been posted yet. Monitor the board as the investigation continues."
			elseif localIsGhost
			then "No evidence has been posted. Watch as the survivors investigate."
			else "No evidence has been posted. Search rooms, objects, and attack sites."
		local empty = Components.Label(
			self.evidenceList,
			"Empty",
			emptyText,
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

function GameView:_updateRoster(state: any)
	local panel = self.rosterPanel
	if not panel or self.destroyed then
		return
	end
	local round = if type(state) == "table" then state.round else nil
	local phase = if type(round) == "table" and type(round.phase) == "string"
		then round.phase
		else nil
	local shouldShowRoster = phase ~= nil and ROSTER_PHASES[phase] == true
	if shouldShowRoster ~= self.rosterPanelVisible then
		self.rosterPanelVisible = shouldShowRoster
		Motion.Cancel(panel)
		if shouldShowRoster then
			panel.Visible = true
			Motion.FadeIn(panel, { duration = 0.25 })
		else
			Motion.FadeOut(panel, {
				duration = 0.2,
				onComplete = function(completed: boolean)
					if completed and not self.destroyed and not self.rosterPanelVisible and panel.Parent then
						panel.Visible = false
					end
				end,
			})
			return
		end
	end
	if not shouldShowRoster then
		return
	end

	-- Build signature to skip redraws when nothing changed
	local participants = if type(state) == "table" then asTable(state.participants) else {}
	local sigParts: { string } = {}
	for _, participant in participants do
		if type(participant) == "table"
			and not readBoolean(participant, "isBot", true)
		then
			table.insert(sigParts, string.format(
				"%s:%s:%s:%s",
				readString(participant, "participantId", ""),
				tostring(readBoolean(participant, "alive", false)),
				tostring(readBoolean(participant, "isGhost", false)),
				readString(participant, "healthState", "Healthy")
			))
		end
	end
	table.sort(sigParts)
	local signature = table.concat(sigParts, "|")
	if signature == self.lastRosterSignature then
		return
	end
	self.lastRosterSignature = signature

	Components.ClearGenerated(panel)

	-- Sort: alive first, then ghost, then dead; within each group by name
	local sorted: { any } = {}
	for _, participant in participants do
		if type(participant) == "table"
			and not readBoolean(participant, "isBot", true)
		then
			table.insert(sorted, participant)
		end
	end
	table.sort(sorted, function(left: any, right: any): boolean
		local leftAlive = readBoolean(left, "alive", false)
		local rightAlive = readBoolean(right, "alive", false)
		local leftGhost = readBoolean(left, "isGhost", false)
		local rightGhost = readBoolean(right, "isGhost", false)
		local leftScore = if leftAlive and not leftGhost then 0 elseif leftGhost then 1 else 2
		local rightScore = if rightAlive and not rightGhost then 0 elseif rightGhost then 1 else 2
		if leftScore ~= rightScore then
			return leftScore < rightScore
		end
		return readString(left, "displayName", "") < readString(right, "displayName", "")
	end)

	local ownId = if type(state) == "table" and type(state.player) == "table"
		then readString(state.player, "participantId", "")
		else ""

	for index, participant in sorted do
		local participantId = readString(participant, "participantId", "")
		local displayName = readString(participant, "displayName", "?")
		local alive = readBoolean(participant, "alive", false)
		local ghost = readBoolean(participant, "isGhost", false)
		local healthState = readString(participant, "healthState", "Healthy")
		local isMe = participantId == ownId

		local row = Instance.new("Frame")
		row.Name = "RosterRow_" .. tostring(index)
		row:SetAttribute("Generated", true)
		row.Size = UDim2.new(1, 0, 0, 22)
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.LayoutOrder = index
		row.Parent = panel

		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.Size = UDim2.fromOffset(8, 8)
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.Position = UDim2.fromOffset(0, 11)
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = if ghost
			then Theme.Colors.Ghost
			elseif not alive then Theme.Colors.TextMuted
			elseif healthState == "Injured" or healthState == "Critical" or healthState == "Incapacitated"
				then Theme.Colors.Danger
			else Theme.Colors.Success
		dot.Parent = row
		Components.Corner(dot, 4)

		local nameLabel = Components.Label(
			row,
			"Name",
			if isMe then displayName .. " ●" else displayName,
			11
		)
		nameLabel.Position = UDim2.fromOffset(14, 0)
		nameLabel.Size = UDim2.new(1, -14, 1, 0)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = if ghost
			then Theme.Colors.Ghost
			elseif not alive then Theme.Colors.TextMuted
			else Theme.Colors.Text
		nameLabel.TextTransparency = if not alive and not ghost then 0.5 else 0
	end
end

function GameView:_ensureDiscussionPanel()
	if self.discussionPanel then
		return
	end
	local panel = Instance.new("Frame")
	panel.Name = "CampfireDiscussion"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0.12, 0)
	panel.Size = UDim2.new(0.36, 0, 0.52, 0)
	panel.BackgroundColor3 = Color3.fromRGB(16, 20, 19)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Visible = false
	-- Below the modal layer (20): the hint tells players to open the
	-- notebook [N], so the notebook must draw over this ambient panel.
	panel.ZIndex = 15
	panel.Parent = self.root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -24, 0, 34)
	title.Position = UDim2.fromOffset(12, 8)
	title.Font = Enum.Font.GothamBold
	title.Text = "CAMPFIRE DISCUSSION"
	title.TextColor3 = Color3.fromRGB(244, 224, 176)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = panel.ZIndex + 1
	title.Parent = panel
	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.new(1, -24, 0, 44)
	hint.Position = UDim2.fromOffset(12, 42)
	hint.Font = Enum.Font.Gotham
	hint.Text = "Talk it over in chat, and present your strongest evidence from the notebook [N]. Voting opens when the discussion timer ends."
	hint.TextColor3 = Color3.fromRGB(214, 219, 212)
	hint.TextSize = 14
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.ZIndex = panel.ZIndex + 1
	hint.Parent = panel
	local log = Instance.new("ScrollingFrame")
	log.Name = "DiscussionLog"
	log.BackgroundTransparency = 1
	log.BorderSizePixel = 0
	log.Size = UDim2.new(1, -24, 1, -100)
	log.Position = UDim2.fromOffset(12, 92)
	log.CanvasSize = UDim2.new(0, 0, 0, 0)
	log.AutomaticCanvasSize = Enum.AutomaticSize.Y
	log.ScrollBarThickness = 4
	log.ZIndex = panel.ZIndex + 1
	log.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = log
	self.discussionPanel = panel
	self.discussionLogList = log
end

function GameView:_setDiscussionVisible(visible: boolean, round: any)
	if not visible then
		if self.discussionPanel then
			self.discussionPanel.Visible = false
		end
		return
	end
	self:_ensureDiscussionPanel()
	local panel = self.discussionPanel
	local log = self.discussionLogList
	if not panel or not log then
		return
	end
	panel.Visible = true
	Components.ClearGenerated(log)
	local entries = asTable(round.discussionLog)
	if next(entries) == nil then
		local placeholder = Instance.new("TextLabel")
		placeholder.Name = "EmptyHint"
		placeholder:SetAttribute("Generated", true)
		placeholder.BackgroundTransparency = 1
		placeholder.Size = UDim2.new(1, -8, 0, 30)
		placeholder.Font = Enum.Font.Gotham
		placeholder.Text = "No evidence presented yet — open the notebook [N] to make your case."
		placeholder.TextColor3 = Color3.fromRGB(150, 156, 148)
		placeholder.TextSize = 14
		placeholder.TextWrapped = true
		placeholder.TextXAlignment = Enum.TextXAlignment.Left
		placeholder.ZIndex = log.ZIndex + 1
		placeholder.Parent = log
	end
	for index, entry in entries do
		if type(entry) == "table" then
			local line = Instance.new("TextLabel")
			line.Name = "Entry" .. tostring(index)
			line:SetAttribute("Generated", true)
			line.BackgroundColor3 = Color3.fromRGB(28, 33, 31)
			line.BackgroundTransparency = 0.25
			line.BorderSizePixel = 0
			line.Size = UDim2.new(1, -8, 0, 30)
			line.Font = Enum.Font.Gotham
			line.Text = string.format(
				"%s presented: %s",
				readString(entry, "presenterName", "Someone"),
				readString(entry, "itemName", "evidence")
			)
			line.TextColor3 = Color3.fromRGB(232, 226, 200)
			line.TextSize = 14
			line.TextWrapped = true
			line.TextXAlignment = Enum.TextXAlignment.Left
			line.LayoutOrder = index
			line.ZIndex = log.ZIndex + 1
			line.Parent = log
		end
	end
end

function GameView:_updateVote(round: any, player: any)
	local phase = readString(round, "phase", "Lobby")
	local alive = readBoolean(player, "alive", false)
	local isGhost = readBoolean(player, "isGhost", false)
	if self.voteWarningLabel then
		self.voteWarningLabel.Text = if readString(player, "role", "") == "Murderer"
			then "One vote. No take-backs. A tie breaks in your favor."
			else "One vote. No take-backs. A tie favors the Murderer."
	end
	if self.voteModalTitleLabel then
		self.voteModalTitleLabel.Text = if readString(player, "role", "") == "Murderer"
			then "CAMPFIRE VOTE"
			else "CAMPFIRE ACCUSATION"
	end
	local vote = if type(player) == "table" then player.vote else nil
	local hasVoted = readBoolean(player, "hasVoted", false)
	if type(vote) == "table" then
		hasVoted = readBoolean(vote, "hasVoted", hasVoted)
	end
	local voteTargetId = ""
	if type(vote) == "table" and type(vote.targetParticipantId) == "string" then
		voteTargetId = vote.targetParticipantId
	end
	if phase ~= "Campfire" or not alive or isGhost then
		setModalVisible(self.voteModal, false)
		self:_setDiscussionVisible(false, round)
		self.currentVoteSignature = ""
		self.localVoteHasLocked = false
		return
	end
	-- Older snapshots have no campfireStage; treat them as open voting.
	local campfireStage = readString(round, "campfireStage", "Voting")
	if campfireStage == "Discussion" then
		setModalVisible(self.voteModal, false)
		self:_setDiscussionVisible(true, round)
		self.currentVoteSignature = ""
		return
	end
	self:_setDiscussionVisible(false, round)
	self.localVoteHasLocked = self.localVoteHasLocked or hasVoted
	if not self.localVoteHasLocked then
		setModalVisible(self.voteModal, true)
	end
	local suspects = asTable(round.suspects)
	local pieces = { tostring(hasVoted), voteTargetId }
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
	local localParticipantKey = readString(player, "participantId", "")
	for _, suspect in suspects do
		if type(suspect) == "table" then
			local key = readString(suspect, "key", readString(suspect, "participantId", ""))
			local name = readString(suspect, "displayName", "Unknown player")
			local isSelf = localParticipantKey ~= "" and key == localParticipantKey
			local labelText = if isSelf then name .. " (you)" else name
			local isMyVote = hasVoted and voteTargetId ~= "" and key == voteTargetId
			local isOtherVote = hasVoted and not isMyVote
			local button = Components.Button(self.voteList, {
				name = "Vote_" .. key:gsub("[^%w]", "_"),
				text = if isMyVote then labelText .. "  ✓ YOUR VOTE" else labelText,
				size = UDim2.new(1, -8, 0, 48),
				color = if isMyVote
					then Theme.Colors.Gold
					elseif isOtherVote then Theme.Colors.Panel
					else Theme.Colors.Danger,
			})
			button:SetAttribute("Generated", true)
			-- The server rejects self-votes, so never offer yourself as a live choice
			Components.SetButtonEnabled(button, not hasVoted and not isSelf)
			if isOtherVote then
				button.BackgroundTransparency = 0.7
			elseif isMyVote then
				button.BackgroundTransparency = 0
				button.TextTransparency = 0
				button.TextColor3 = Theme.Colors.Background
			end
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
					self:Notify("Vote rejected", reason or "Your vote could not be recorded.", "Warning")
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
			Motion.PopIn(self.ghostBadge, { duration = 0.2 })
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
	if not active and self.hauntPanel then
		self.hauntPanel.Visible = false
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

-- Ghost-only haunt meter, fed from GhostSync results and full-state snapshots.
function GameView:UpdateGhostHaunt(ghost: any)
	if self.destroyed then
		return
	end
	local panel = self.hauntPanel
	local fill = self.hauntFill
	local hint = self.hauntHint
	if not panel or not fill or not hint then
		return
	end
	if not self.ghostMode or type(ghost) ~= "table" then
		panel.Visible = false
		return
	end
	local meter = if type(ghost.hauntMeter) == "number" then ghost.hauntMeter else 0
	local maximum = if type(ghost.hauntMeterMax) == "number" and ghost.hauntMeterMax > 0
		then ghost.hauntMeterMax
		else 100
	local fraction = math.clamp(meter / maximum, 0, 1)
	panel.Visible = true
	fill.Size = UDim2.fromScale(fraction, 1)
	if ghost.hauntReady == true then
		hint.Text = "HAUNT READY — press H"
		hint.TextColor3 = Theme.Colors.Gold
	else
		hint.Text = string.format(
			"Haunt energy %d%%",
			math.floor(fraction * 100 + 0.5)
		)
		hint.TextColor3 = Theme.Colors.TextMuted
	end
end

function GameView:_animateRewards(targetXP: number, targetTokens: number, suffix: string?)
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
			"TOTAL XP  %d     CAMP TOKENS  %d%s",
			xp,
			tokens,
			suffix or ""
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

function GameView:_setObjectiveFill(fraction: number)
	local target = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	if self.settingsValues.reducedMotion == true then
		self.objectiveFill.Size = target
	else
		TweenService:Create(
			self.objectiveFill,
			TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Size = target }
		):Play()
	end
end

function GameView:_updatePhaseArc(state: any)
	local arc = self.phaseArc
	if not arc or self.destroyed then
		return
	end
	local round = if type(state) == "table" then state.round else nil
	local phase = if type(round) == "table" and type(round.phase) == "string"
		then round.phase
		else nil
	local visible = phase ~= nil and phase ~= "Lobby" and phase ~= "Rewards" and phase ~= "RoleReveal"
	arc.Visible = visible
	if not visible then
		return
	end

	local currentIndex = 0
	for index, phaseName in PHASE_ARC_ORDER do
		if phaseName == phase then
			currentIndex = index
			break
		end
	end

	local reducedMotionArc = self.settingsValues.reducedMotion == true
	for index, phaseName in PHASE_ARC_ORDER do
		local dot = self.phaseArcDots[phaseName]
		if not dot then
			continue
		end
		if index < currentIndex then
			dot.BackgroundColor3 = Theme.Colors.TextMuted
			dot.BackgroundTransparency = 0
			dot.Size = UDim2.fromOffset(8, 8)
		elseif index == currentIndex then
			dot.BackgroundColor3 = Theme.Colors.Gold
			dot.BackgroundTransparency = 0
			if reducedMotionArc then
				dot.Size = UDim2.fromOffset(12, 12)
			else
				dot.Size = UDim2.fromOffset(16, 16)
				TweenService:Create(
					dot,
					TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Size = UDim2.fromOffset(12, 12) }
				):Play()
			end
		else
			dot.BackgroundColor3 = Theme.Colors.TextMuted
			dot.BackgroundTransparency = 0.65
			dot.Size = UDim2.fromOffset(8, 8)
		end
	end
end

function GameView:_updateMonsterPanel(state: any, phase: string?)
	local panel = self.monsterPanel
	if not panel or self.destroyed then
		return
	end
	local privateMonster = if type(state) == "table" then state.privateMonster else nil
	local monsterActive = type(privateMonster) == "table"
		and readBoolean(privateMonster, "active", false)
	local shouldShow = monsterActive and (phase == "Investigation" or phase == "NightTransform")
	if shouldShow ~= self.monsterPanelVisible then
		self.monsterPanelVisible = shouldShow
		Motion.Cancel(panel)
		if shouldShow then
			panel.Visible = true
			Motion.FadeIn(panel, { duration = 0.3 })
		else
			Motion.FadeOut(panel, {
				duration = 0.3,
				onComplete = function(completed: boolean)
					if completed
						and not self.destroyed
						and not self.monsterPanelVisible
						and panel.Parent
					then
						panel.Visible = false
					end
				end,
			})
		end
	end
	if not monsterActive or type(privateMonster) ~= "table" then
		return
	end
	local monsterSnapshot = privateMonster :: any
	local monsterNameLabel = self.monsterNameLabel
	if monsterNameLabel then
		local rawId = readString(monsterSnapshot, "monsterId", "")
		local displayName = if rawId ~= ""
			then string.upper(rawId:gsub("(%l)(%u)", "%1 %2"))
			else "MONSTER"
		monsterNameLabel.Text = "▸ " .. displayName
	end
	local monsterStaminaFill = self.monsterStaminaFill
	if monsterStaminaFill then
		local stamina = readNumber(monsterSnapshot, "stamina", 0)
		local maxStamina = readNumber(monsterSnapshot, "maxStamina", 0)
		local fraction = if maxStamina > 0
			then math.clamp(stamina / maxStamina, 0, 1)
			else 0
		monsterStaminaFill.Size = UDim2.fromScale(fraction, 1)
	end
	local monsterAbilityLabel = self.monsterAbilityLabel
	if monsterAbilityLabel then
		local currentTime = Workspace:GetServerTimeNow()
		local cooldowns = monsterSnapshot.cooldownEndsAt
		local monsterId = readString(monsterSnapshot, "monsterId", "")
		local abilityIds = table.clone(MONSTER_ABILITIES[monsterId] or {})
		if #abilityIds == 0 and type(cooldowns) == "table" then
			for abilityId in cooldowns do
				if type(abilityId) == "string" then
					table.insert(abilityIds, abilityId)
				end
			end
			table.sort(abilityIds)
		end

		local abilityLines: { string } = {}
		for _, abilityId in abilityIds do
			local displayName = string.upper(
				abilityId:gsub("(%l)(%u)", "%1 %2"):gsub("-", " ")
			)
			local endsAt = if type(cooldowns) == "table" then cooldowns[abilityId] else nil
			local remaining = if type(endsAt) == "number"
					and endsAt == endsAt
					and math.abs(endsAt) < math.huge
				then endsAt - currentTime
				else 0
			if remaining > 0.5 then
				table.insert(abilityLines, string.format(
					'<font color="%s">%s  %ds</font>',
					MONSTER_ABILITY_COOLING_RICH_COLOR,
					displayName,
					math.ceil(remaining)
				))
			else
				table.insert(abilityLines, string.format(
					'<font color="%s">%s  READY</font>',
					MONSTER_ABILITY_READY_RICH_COLOR,
					displayName
				))
			end
		end

		if #abilityLines > 0 then
			monsterAbilityLabel.Text = table.concat(abilityLines, "\n")
		else
			monsterAbilityLabel.Text = "ABILITY READY"
		end
	end
	local monsterNoteLabel = self.monsterNoteLabel
	if monsterNoteLabel then
		local monsterId = readString(privateMonster, "monsterId", "")
		local catalogEntry = if monsterId ~= "" then PublicMonsterCatalog[monsterId] else nil
		monsterNoteLabel.Text = if catalogEntry then catalogEntry.murdererNote else ""
	end
end

function GameView:_stopTimerPulse()
	if not self.timerPulsing and not self.timerPulseConn then
		return
	end
	self.timerPulsing = false
	local connection = self.timerPulseConn
	self.timerPulseConn = nil
	if connection then
		connection:Disconnect()
	end
	if not self.destroyed and self.timerLabel.Parent then
		self.timerLabel.TextSize = 19
	end
end

function GameView:_startTimerPulse()
	if Motion.IsReducedMotion(self.root) then
		self:_stopTimerPulse()
		return
	end
	if self.timerPulsing then
		return
	end
	self.timerPulsing = true
	self.timerPulseConn = RunService.Heartbeat:Connect(function()
		if self.destroyed then
			self:_stopTimerPulse()
			return
		end
		-- Three complete cycles per second, ranging from 19 to 22 points.
		local size = math.round(20.5 + math.sin(os.clock() * math.pi * 6) * 1.5)
		self.timerLabel.TextSize = size
	end)
end

function GameView:Update(state: any, legacyRound: any, legacyPlayer: any)
	self:_updatePhaseArc(state)
	self.currentState = state
	self.legacyRound = legacyRound
	self.legacyPlayer = legacyPlayer
	local round = if type(state) == "table" and type(state.round) == "table" then state.round else legacyRound
	local player = if type(state) == "table" and type(state.player) == "table" then state.player else legacyPlayer
	if type(round) ~= "table" then
		self:_stopTimerPulse()
		Components.SetLetterspacedText(self.phaseLabel, "WAITING FOR THE CAMP")
		self.progressLabel.Text = "Connecting to the round server..."
		if self.eliminatedBanner then
			self.eliminatedBanner.Visible = false
		end
		self:_updateMonsterPanel(state, nil)
		return
	end

	local phase = readString(round, "phase", "Lobby")
	self:_updateMonsterPanel(state, phase)
	if self.voteCountLabel then
		if phase == "Campfire" then
			local votesCast = math.max(0, math.floor(readNumber(round, "votesCast", 0)))
			local eligibleVoters = math.max(
				0,
				math.floor(readNumber(round, "eligibleVoters", 0))
			)
			self.voteCountLabel.Text = string.format(
				"%d/%d VOTED",
				votesCast,
				eligibleVoters
			)
		else
			self.voteCountLabel.Text = ""
		end
	end
	Components.SetLetterspacedText(
		self.phaseLabel,
		string.upper(readString(round, "phaseDisplayName", phase))
	)
	local seconds = math.max(0, math.ceil(readNumber(round, "phaseEndsAt", 0) - Workspace:GetServerTimeNow()))
	self.timerLabel.Text = string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
	local localRole = readString(player, "role", "")
	local isMurdererCampfire = phase == "Campfire" and localRole == "Murderer"
	local dangerThreshold = if isMurdererCampfire then 20 else 10
	local amberThreshold = if isMurdererCampfire then 60 else 30
	if isMurdererCampfire and seconds <= dangerThreshold then
		self.timerLabel.TextColor3 = Theme.Colors.DangerBright
		if seconds > 0 then
			self:_startTimerPulse()
		else
			self:_stopTimerPulse()
		end
	elseif isMurdererCampfire and seconds <= amberThreshold then
		self.timerLabel.TextColor3 = Theme.Colors.Amber
		self:_stopTimerPulse()
	elseif seconds <= 10 and seconds > 0 then
		self.timerLabel.TextColor3 = Theme.Colors.DangerBright
		self:_startTimerPulse()
	else
		self.timerLabel.TextColor3 = Theme.Colors.Gold
		self:_stopTimerPulse()
	end

	local objectiveDone = readNumber(round, "objectivesCompleted", 0)
	local objectiveGoal = math.max(1, readNumber(round, "objectiveGoal", 1))
	local evidenceFound = readNumber(round, "evidenceFound", 0)
	local evidenceGoal = math.max(1, readNumber(round, "evidenceGoal", 1))
	if phase == "Day" then
		local mystery = if type(state) == "table" then state.mystery else nil
		local witnessFound = math.max(0, math.floor(readNumber(mystery, "revealedWitnessCount", 0)))
		local witnessTotal = math.max(1, math.floor(readNumber(mystery, "totalWitnessCount", 1)))
		local localRole = if type(player) == "table" and type(player.role) == "string"
			then player.role
			else ""
		local isGhostPlayer = readBoolean(player, "isGhost", false)
		if localRole == "Spectator" then
			self.progressLabel.Text = string.format(
				"Camp work %d/%d  |  Witnesses %d/%d",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
			self.objectiveText.Text = string.format(
				"OBSERVING\nCamp work: %d of %d. Witnesses: %d of %d.",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
		elseif isGhostPlayer then
			self.progressLabel.Text = string.format(
				"Camp work %d/%d  |  Witnesses %d/%d",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
			self.objectiveText.Text = string.format(
				"OBSERVING\nYou are a ghost. Camp work: %d of %d. Witnesses: %d of %d.",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
		elseif localRole == "Murderer" then
			self.progressLabel.Text = string.format(
				"Camp work %d/%d  |  Witnesses %d/%d  — blend in.",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
			self.objectiveText.Text = string.format(
				"DAY COVER\nCamp work: %d of %d. Witnesses: %d of %d. Act natural.",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
		else
			self.progressLabel.Text = string.format(
				"Camp work %d/%d  |  Witnesses %d/%d",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
			self.objectiveText.Text = string.format(
				"DAY OBJECTIVE\nCamp work: %d of %d\nInterview witnesses: %d of %d",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
		end
		self:_setObjectiveFill(objectiveDone / objectiveGoal)
		local roundNum = readNumber(round, "roundNumber", 0)
		local aliveNotGhost = readBoolean(player, "alive", false)
			and not readBoolean(player, "isGhost", false)
		local isLivingCamper = readString(player, "team", "") == "Campers" and aliveNotGhost
		local isMurdererAlive = localRole == "Murderer" and aliveNotGhost
		if (isLivingCamper or isMurdererAlive)
			and objectiveDone >= objectiveGoal
			and witnessFound >= witnessTotal
			and roundNum > 0
			and self.dayObjectiveNotifiedRound ~= roundNum
		then
			self.dayObjectiveNotifiedRound = roundNum
			if isMurdererAlive then
				self:Notify(
					"Day objectives complete",
					"Campers are ready. Investigation begins soon — stay composed.",
					"Warning"
				)
			else
				self:Notify(
					"Day objectives complete",
					"All camp work done and witnesses interviewed. Investigation begins soon.",
					"Success"
				)
			end
		end
	elseif phase == "Investigation" then
		local privateMonster = if type(state) == "table" then state.privateMonster else nil
		local isMonsterPlayer = type(privateMonster) == "table"
			and readBoolean(privateMonster, "active", false)
		local localRole = if type(player) == "table" and type(player.role) == "string"
			then player.role
			else ""
		if isMonsterPlayer then
			local huntMurderPlan = if type(state) == "table" then state.murderPlan else nil
			local huntVictimId = if type(huntMurderPlan) == "table"
					and type(huntMurderPlan.victimParticipantId) == "string"
					and huntMurderPlan.victimParticipantId ~= ""
				then huntMurderPlan.victimParticipantId
				else nil
			local huntVictimName = "your target"
			if huntVictimId ~= nil then
				local huntParticipants = if type(state) == "table"
						and type(state.participants) == "table"
					then state.participants
					else {}
				for _, p in huntParticipants do
					if type(p) == "table" and p.participantId == huntVictimId then
						huntVictimName = readString(p, "displayName", "your target")
						break
					end
				end
			end
			self.progressLabel.Text = string.format("Hunt %s. Don't get cornered.", huntVictimName)
			self.objectiveText.Text = string.format(
				"HUNT OBJECTIVE\nEliminate %s. Avoid discovery. Use your ability when the time is right.",
				huntVictimName
			)
			self.objectiveFill.Size = UDim2.fromScale(1, 1)
		elseif localRole == "Spectator" then
			self.progressLabel.Text = string.format("Observing. Evidence %d/%d collected.", evidenceFound, evidenceGoal)
			self.objectiveText.Text = "OBSERVING\nYou joined mid-round. Watch the investigation unfold."
			self:_setObjectiveFill(evidenceFound / evidenceGoal)
		else
			local isGhostPlayer = readBoolean(player, "isGhost", false)
			if isGhostPlayer then
				self.progressLabel.Text = string.format(
					"Evidence %d/%d collected by survivors.",
					evidenceFound,
					evidenceGoal
				)
				self.objectiveText.Text = "OBSERVING\nYou are a ghost. Watch as the survivors investigate."
				self:_setObjectiveFill(evidenceFound / evidenceGoal)
			else
				self.progressLabel.Text = string.format(
					"Evidence %d/%d - search the abandoned town.",
					evidenceFound,
					evidenceGoal
				)
				self.objectiveText.Text = string.format(
					"NIGHT OBJECTIVE\nCollect and post clues: %d of %d",
					evidenceFound,
					evidenceGoal
				)
				self:_setObjectiveFill(evidenceFound / evidenceGoal)
				local roundNum = readNumber(round, "roundNumber", 0)
				local evidAliveNotGhost = readBoolean(player, "alive", false)
					and not readBoolean(player, "isGhost", false)
				local evidIsLivingCamper = readString(player, "team", "") == "Campers" and evidAliveNotGhost
				local evidIsMurderer = localRole == "Murderer" and evidAliveNotGhost
				if (evidIsLivingCamper or evidIsMurderer)
					and evidenceFound >= evidenceGoal
					and roundNum > 0
					and self.evidenceNotifiedRound ~= roundNum
				then
					self.evidenceNotifiedRound = roundNum
					if evidIsMurderer then
						self:Notify(
							"Evidence complete",
							"All evidence is on the board. Stay composed — the vote decides your fate.",
							"Warning"
						)
					else
						self:Notify(
							"Evidence complete",
							"All clues collected. Return for the Campfire.",
							"Success"
						)
					end
				end
			end
		end
	elseif phase == "Campfire" then
		local cast = readNumber(round, "votesCast", 0)
		local eligible = math.max(1, readNumber(round, "eligibleVoters", 1))
		local campfireParticipants = if type(state) == "table"
				and type(state.participants) == "table"
			then state.participants
			else {}
		local aliveCount = 0
		for _, p in campfireParticipants do
			if type(p) == "table" and p.alive == true then
				aliveCount += 1
			end
		end
		local survivorPhrase = if aliveCount == 1
			then "1 player remains"
			else string.format("%d players remain", aliveCount)
		local localRole = if type(player) == "table" and type(player.role) == "string"
			then player.role
			else ""
		local isGhostPlayer = readBoolean(player, "isGhost", false)
		if localRole == "Spectator" then
			self.progressLabel.Text = string.format("Votes locked %d/%d - observing.", cast, eligible)
			self.objectiveText.Text = string.format(
				"OBSERVING\n%s. The vote will reveal the verdict.",
				survivorPhrase
			)
		elseif isGhostPlayer then
			self.progressLabel.Text = string.format("Votes locked %d/%d - watching.", cast, eligible)
			self.objectiveText.Text = string.format(
				"OBSERVING\n%s. Watch the vote decide the verdict.",
				survivorPhrase
			)
		elseif localRole == "Murderer" then
			self.progressLabel.Text = string.format("Votes locked %d/%d - stay calm.", cast, eligible)
			self.objectiveText.Text = string.format(
				"CAMPFIRE VOTE\n%s. Deflect suspicion. Survive the vote.",
				survivorPhrase
			)
		else
			self.progressLabel.Text = string.format("Votes locked %d/%d - accuse carefully.", cast, eligible)
			self.objectiveText.Text = string.format(
				"FINAL VOTE\n%s. Review your notebook and identify the Murderer.",
				survivorPhrase
			)
		end
		self:_setObjectiveFill(cast / eligible)
	elseif phase == "MurderPlanning" then
		local localRole = if type(player) == "table" and type(player.role) == "string"
			then player.role
			else ""
		if readBoolean(player, "isGhost", false) then
			self.progressLabel.Text = "Night is coming."
			self.objectiveText.Text = "OBSERVING\nYou are a ghost. Watch the night unfold."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		elseif localRole == "Murderer" then
			local murderPlan = if type(state) == "table" then state.murderPlan else nil
			local victimParticipantId = readString(murderPlan, "victimParticipantId", "")
			local victimName = "your target"
			local planParticipants = if type(state) == "table" then asTable(state.participants) else {}
			for _, participant in planParticipants do
				if victimParticipantId ~= ""
					and type(participant) == "table"
					and readString(participant, "participantId", "") == victimParticipantId
				then
					victimName = readString(participant, "displayName", "your target")
					break
				end
			end
			self.progressLabel.Text = "Plan your attack before night falls."
			self.objectiveText.Text = string.format(
				"MURDERER OBJECTIVE\nEliminate %s. Frame the evidence.",
				victimName
			)
			self.objectiveFill.Size = UDim2.fromScale(1, 1)
		elseif localRole == "Spectator" then
			self.progressLabel.Text = "Night is coming."
			self.objectiveText.Text = "OBSERVING\nThe night phase is beginning. Watch what unfolds."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		else
			self.progressLabel.Text = "Night is coming. Prepare your tools."
			self.objectiveText.Text = "PREPARATION\nSomething is coming. Secure your equipment and stay alert."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		end
	elseif phase == "NightTransform" then
		local privateMonster = if type(state) == "table" then state.privateMonster else nil
		local localRole = if type(player) == "table" and type(player.role) == "string"
			then player.role
			else ""
		local isMonsterPlayer = type(privateMonster) == "table" or localRole == "Murderer"
		if readBoolean(player, "isGhost", false) then
			self.progressLabel.Text = "Night has fallen."
			self.objectiveText.Text = "OBSERVING\nYou are a ghost. Watch the hunt from beyond."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		elseif isMonsterPlayer then
			local nightMurderPlan = if type(state) == "table" then state.murderPlan else nil
			local nightVictimId = if type(nightMurderPlan) == "table"
					and type(nightMurderPlan.victimParticipantId) == "string"
					and nightMurderPlan.victimParticipantId ~= ""
				then nightMurderPlan.victimParticipantId
				else nil
			local nightVictimName = "your target"
			if nightVictimId ~= nil then
				local nightParticipants = if type(state) == "table"
						and type(state.participants) == "table"
					then state.participants
					else {}
				for _, p in nightParticipants do
					if type(p) == "table" and p.participantId == nightVictimId then
						nightVictimName = readString(p, "displayName", "your target")
						break
					end
				end
			end
			self.progressLabel.Text = "The transformation is complete. The town awaits."
			self.objectiveText.Text = string.format(
				"YOU ARE THE MONSTER\nThe town is yours. Hunt %s — the campers will fight back.",
				nightVictimName
			)
			self.objectiveFill.Size = UDim2.fromScale(1, 1)
		elseif localRole == "Spectator" then
			self.progressLabel.Text = "Night has fallen."
			self.objectiveText.Text = "OBSERVING\nThe night phase has begun. Watch what unfolds."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		else
			self.progressLabel.Text = "The town has appeared. Stay close to your group."
			self.objectiveText.Text = "NIGHT BEGINS\nThe abandoned town has merged with the camp. The monster is somewhere inside."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		end
	elseif phase == "Rewards" then
		local rewardsRole = readString(player, "role", "Spectator")
		local rewardsIsGhost = readBoolean(player, "isGhost", false)
		local rewardsWinner = readString(round, "winner", "")
		local campersWon = rewardsWinner == "Campers"
		if rewardsRole == "Murderer" then
			if campersWon then
				self.progressLabel.Text = "The camp unmasked you."
				self.objectiveText.Text = "CAUGHT\nThe campers solved the mystery. Better luck next time."
			else
				self.progressLabel.Text = "You escaped into the night."
				self.objectiveText.Text = "ESCAPED\nThe camp never caught you. A flawless hunt."
			end
		elseif rewardsIsGhost then
			self.progressLabel.Text = if campersWon
				then "Justice delivered."
				else "The mystery remains unsolved."
			self.objectiveText.Text = if campersWon
				then "JUSTICE\nThe murderer was caught. Your death was not in vain."
				else "UNSOLVED\nThe murderer escaped. The mystery remains."
		elseif rewardsRole ~= "Spectator" then
			if campersWon then
				self.progressLabel.Text = "Justice was served."
				self.objectiveText.Text = "VICTORY\nYou helped catch the monster. The camp is safe."
			else
				self.progressLabel.Text = "The monster escaped."
				self.objectiveText.Text = "DEFEAT\nThe mystery went unsolved. The monster walks free."
			end
		else
			self.progressLabel.Text = if campersWon then "The campers prevailed." else "The monster escaped."
			self.objectiveText.Text = "ROUND OVER\nThe mystery has been resolved."
		end
		self.objectiveFill.Size = UDim2.fromScale(if campersWon then 1 else 0, 1)
	elseif phase == "Resolution" then
		local resRole = if type(player) == "table" and type(player.role) == "string"
			then player.role
			else ""
		local resWinner = readString(round, "winner", "")
		local campersWon = resWinner == "Campers"
		local isGhostRes = readBoolean(player, "isGhost", false)
		if resRole == "Spectator" then
			self.progressLabel.Text = if campersWon
				then "Campers prevailed."
				else "The murderer escaped."
			self.objectiveText.Text = "ROUND OVER\nThe mystery has been resolved."
			self.objectiveFill.Size = UDim2.fromScale(if campersWon then 1 else 0, 1)
		elseif isGhostRes then
			self.progressLabel.Text = if campersWon
				then "Justice delivered."
				else "The murderer escaped."
			self.objectiveText.Text = if campersWon
				then "JUSTICE\nThe camp caught the killer. Your death was not in vain."
				else "UNSOLVED\nThe murderer escaped. Your death remains unavenged."
			self.objectiveFill.Size = UDim2.fromScale(if campersWon then 1 else 0, 1)
		elseif resRole == "Murderer" then
			self.progressLabel.Text = if campersWon
				then "The camp unmasked you."
				else "The camp could not name you."
			self.objectiveText.Text = if campersWon
				then "UNMASKED\nThe camp named you. The hunt is over."
				else "UNSEEN\nYour name was never called. You walk free."
			self.objectiveFill.Size = UDim2.fromScale(if campersWon then 0 else 1, 1)
		else
			self.progressLabel.Text = if campersWon
				then "Justice delivered."
				else "The murderer escaped."
			self.objectiveText.Text = if campersWon
				then "NAMED\nThe murderer has been revealed. The camp is safe."
				else "UNSOLVED\nNo verdict reached. The killer walks free."
			self.objectiveFill.Size = UDim2.fromScale(if campersWon then 1 else 0, 1)
		end
	elseif phase == "Lobby" then
		local lobbyRole = if type(player) == "table" and type(player.role) == "string"
			then player.role
			else ""
		local lobbyMsg = readString(round, "resultMessage", "Ready up while the camp fills seats.")
		if lobbyRole == "Spectator" then
			self.progressLabel.Text = lobbyMsg
			self.objectiveText.Text = "OBSERVING\nYou are watching this round. Wait for it to begin."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		elseif lobbyRole == "Murderer" then
			self.progressLabel.Text = lobbyMsg
			self.objectiveText.Text = "CHOSEN\nYou have been selected. Your target will be revealed when night falls."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		else
			self.progressLabel.Text = lobbyMsg
			self.objectiveText.Text = "NEXT MYSTERY\nReady up while the camp fills empty seats."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		end
	else
		self.progressLabel.Text = readString(
			round,
			"resultMessage",
			if readBoolean(round, "isNight", false) then "Stay together. The town is awake." else "Listen for the next briefing."
		)
		self.objectiveText.Text = "CURRENT MISSION\nFollow the phase instructions and stay alert."
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
	local eliminated = role ~= "Spectator" and not alive and not ghost
	local observing = readString(player, "role", "") == "Spectator"
		and not alive
		and not ghost
	self.eliminatedMode = eliminated
	if eliminated then
		self:HideInteraction()
	end
	if self.eliminatedBanner then
		local inActivePhase = phase ~= "Lobby" and phase ~= "Rewards"
		local shouldShowBanner = (eliminated or observing) and inActivePhase
		local wasShowingBanner = self.eliminatedBanner.Visible
		self.eliminatedBanner.Visible = shouldShowBanner
		if shouldShowBanner and not wasShowingBanner and not Motion.IsReducedMotion(self.eliminatedBanner) then
			Motion.FadeIn(self.eliminatedBanner, { duration = 0.4 })
		end
		if self.eliminatedBanner.Visible then
			local titleLabel = self.eliminatedBanner:FindFirstChild("Title")
			local subLabel = self.eliminatedBanner:FindFirstChild("Sub")
			if titleLabel and titleLabel:IsA("TextLabel")
				and subLabel and subLabel:IsA("TextLabel")
			then
				if observing then
					titleLabel.Text = "OBSERVING"
					subLabel.Text = "You joined during an active round. You'll play next."
				else
					titleLabel.Text = "ELIMINATED"
					subLabel.Text = if role == "Murderer"
						then "The camp saw through you. Your hunt is over."
						else "You are spectating. Watch the mystery unfold."
				end
			end
		end
	end
	self:SetGhostMode(ghost)
	local healthState = readString(player, "healthState", if alive then "Healthy" else "Waiting")
	if ghost then
		self.stateBadge.Text = "GHOST"
		self.stateBadge.BackgroundColor3 = Theme.Colors.Ghost
		self.roleTitle.TextColor3 = Theme.Colors.Ghost
	elseif alive then
		self.stateBadge.Text = string.upper(healthState)
		self.stateBadge.BackgroundColor3 = if healthState == "Injured"
			or healthState == "Critical"
			or healthState == "Incapacitated"
			then Theme.Colors.Danger else Theme.Colors.Success
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
	elseif role == "Spectator" then
		self.healthText.Text = "SPECTATING  -  OBSERVING THIS ROUND"
		self.healthFill.BackgroundColor3 = Theme.Colors.PanelSoft
	elseif not alive then
		self.healthText.Text = "WAITING FOR NEXT ROUND"
		self.healthFill.BackgroundColor3 = Theme.Colors.PanelSoft
	else
		self.healthText.Text = string.format("%s  %d/%d", string.upper(healthState), health, maxHealth)
		self.healthFill.BackgroundColor3 = if healthState == "Injured"
			or healthState == "Critical"
			or healthState == "Incapacitated"
			then Theme.Colors.Danger else Theme.Colors.Success
	end
	local targetHealthScale = math.clamp(health / maxHealth, 0, 1)
	local targetHealthSize = UDim2.fromScale(targetHealthScale, 1)
	if self.settingsValues.reducedMotion == true then
		self.healthFill.Size = targetHealthSize
	else
		TweenService:Create(
			self.healthFill,
			TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Size = targetHealthSize }
		):Play()
	end
	-- Brief damage flash when health drops
	local currentHealth = health
	if currentHealth < self.lastHealthForFlash and not ghost then
		local fill = self.healthFill
		local originalColor = fill.BackgroundColor3
		fill.BackgroundColor3 = Theme.Colors.DangerBright
		task.delay(0.12, function()
			if not self.destroyed then
				TweenService:Create(
					fill,
					TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundColor3 = originalColor }
				):Play()
			end
		end)
	end
	self.lastHealthForFlash = currentHealth

	local roleEnabled, roleReason = self:_available(state, "UseRoleAbility")
	local monsterEnabled = self:_available(state, "UseMonsterAbility")
	local planEnabled = self:_available(state, "SetMurderPlan")
	local buddyEnabled = self:_available(state, "BuddyCheckIn")
	local sabotageEnabled = self:_available(state, "Sabotage")
	local livingRoleActionEnabled = not ghost
		and (roleEnabled or monsterEnabled or planEnabled or buddyEnabled)
	if not ghost and sabotageEnabled then
		livingRoleActionEnabled = true
	end
	Components.SetButtonEnabled(
		self.roleAction,
		livingRoleActionEnabled and not eliminated
	)
	self.roleAction.TextColor3 = Theme.Colors.Text
	local roleActionText = if ghost
		then "GHOST ACTIONS LOCKED"
		elseif planEnabled
		then "PLAN TONIGHT'S HUNT"
		elseif buddyEnabled
		then "BUDDY CHECK-IN"
		elseif monsterEnabled
		then "USE MONSTER ABILITY"
		elseif roleEnabled then "USE ROLE ABILITY"
		elseif sabotageEnabled then "SABOTAGE A REPAIR"
		elseif roleReason then string.upper(roleReason)
		else "ABILITY UNAVAILABLE"
	self.roleActionBaseText = roleActionText
	self.roleAction.Text = roleActionText

	self:_updateLobby(state, phase)
	self:_updateRoster(state)
	self:_updateInventory(state)
	self:_updateEvidence(state, round)
	self:_updateVote(round, player)
	if modalTargetVisible(self.progression) then
		self:_updateProgression(state)
	end
	local codexModal = self.codex
	if codexModal and modalTargetVisible(codexModal) then
		self:_updateCodex(state)
	end

	local winner = if type(round.winner) == "string" then round.winner else nil
	if (phase == "Resolution" or phase == "Rewards") and not modalTargetVisible(self.progression) then
		setModalVisible(self.resultModal, true)
		if not self.voteRevealOwnsResults then
			local modalRole = if type(player) == "table" and type(player.role) == "string"
				then player.role
				else ""
			local modalCampersWon = winner == "Campers"
			local modalIsGhost = readBoolean(player, "isGhost", false)
			if modalRole == "Spectator" then
				self.resultTitle.Text = if modalCampersWon then "CAMPERS WIN" else "MURDERER WINS"
				self.resultBody.Text = readString(round, "resultMessage", "The night is over—for now.")
			elseif modalIsGhost then
				self.resultTitle.Text = if modalCampersWon then "JUSTICE" else "UNSOLVED"
				self.resultBody.Text = if modalCampersWon
					then "The murderer was caught. Your death was not in vain."
					else "The murderer escaped. The mystery remains."
			elseif modalRole == "Murderer" then
				self.resultTitle.Text = if modalCampersWon then "CAUGHT" else "ESCAPED"
				self.resultBody.Text = if modalCampersWon
					then "The camp unmasked you. The hunt is over."
					else "The camp never identified you. A flawless hunt."
			else
				self.resultTitle.Text = if modalCampersWon then "VICTORY" else "DEFEAT"
				self.resultBody.Text = if modalCampersWon
					then "Justice was served. The camp is safe."
					else "The murderer escaped. The mystery went unsolved."
			end
		end
		local profile = if type(state) == "table" then state.profile else nil
		local profileData = if type(profile) == "table" then profile.profile else nil
		if type(profileData) == "table" then
			local totalXP = readNumber(profileData, "totalXP", 0)
			local tokens = readNumber(profileData, "campTokens", 0)
			-- Daily streak footnote: only from day 2 (a "day 1 streak" reads
			-- as noise) — mirrors the server's ProgressionConfig bonus curve.
			local streakDays = math.floor(readNumber(profileData, "streakCount", 0))
			local streakSuffix = ""
			if streakDays >= 2 then
				local bonusPercent = math.floor(
					math.min(
						streakDays - 1,
						ProgressionConfig.rewards.streakBonusMaxDays
					) * ProgressionConfig.rewards.streakPerDayBonus * 100 + 0.5
				)
				streakSuffix = string.format(
					"     DAY %d STREAK  +%d%%",
					streakDays,
					bonusPercent
				)
			end
			if phase == "Rewards" then
				self:_animateRewards(totalXP, tokens, streakSuffix)
			else
				self.rewardText.Text = string.format(
				"TOTAL XP  %d     CAMP TOKENS  %d%s",
					totalXP,
					tokens,
					streakSuffix
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
	-- One welcome-back toast per session: returning players see their streak
	-- the first time their profile arrives, so the bonus feels earned rather
	-- than silently applied at round end.
	if type(profileData) == "table" and not self.streakToastShown then
		self.streakToastShown = true
		local streakDays = math.floor(readNumber(profileData, "streakCount", 0))
		if streakDays >= 2 then
			local bonusPercent = math.floor(
				math.min(
					streakDays - 1,
					ProgressionConfig.rewards.streakBonusMaxDays
				) * ProgressionConfig.rewards.streakPerDayBonus * 100 + 0.5
			)
			-- Aspirational milestone (first-week retention pattern): name the
			-- next streak-exclusive title so the goal is visible before it's
			-- reached, not only after.
			local nextMilestone: string? = nil
			local nextDays = math.huge
			for _, definition in CosmeticCatalog.definitions do
				if definition.unlockKind == "Streak"
					and definition.unlockAmount > streakDays
					and definition.unlockAmount < nextDays
				then
					nextDays = definition.unlockAmount
					nextMilestone = definition.displayName
				end
			end
			local body = string.format(
				"Camp rewards pay +%d%% today. Play tomorrow to keep it going.",
				bonusPercent
			)
			if nextMilestone then
				body = string.format(
					"Camp rewards pay +%d%% today. %d more day%s to the \"%s\" title.",
					bonusPercent,
					nextDays - streakDays,
					if nextDays - streakDays == 1 then "" else "s",
					nextMilestone
				)
			end
			self:Notify(string.format("Day %d streak!", streakDays), body, "Success", 8)
		end
	end
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
		local localPlayer0 = if type(self.currentState) == "table" then self.currentState.player else nil
		local localRole0 = readString(localPlayer0, "role", "")
		local definitions0 = TipCatalog.definitions
		local n0 = #definitions0
		local nextIdx = self.lobbyTipIndex
		for _ = 1, n0 do
			nextIdx = (nextIdx % n0) + 1
			local candidate = definitions0[nextIdx]
			local excluded = false
			if candidate and type(candidate.excludeRoles) == "table" then
				for _, r in candidate.excludeRoles do
					if r == localRole0 then excluded = true; break end
				end
			end
			if not excluded and candidate and type(candidate.includeRoles) == "table" then
				local included = false
				for _, r in candidate.includeRoles do
					if r == localRole0 then included = true; break end
				end
				if not included then excluded = true end
			end
			if not excluded then break end
		end
		self.lobbyTipIndex = nextIdx
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
		self:_stopTimerPulse()
		self:_updateMonsterPanel(self.currentState, nil)
		return
	end
	self:_updateMonsterPanel(
		self.currentState,
		readString(round, "phase", "Lobby")
	)
	local player = if type(self.currentState) == "table"
			and type(self.currentState.player) == "table"
		then self.currentState.player
		else nil
	local phase = readString(round, "phase", "Lobby")
	local localRole = readString(player, "role", "")
	local isMurdererCampfire = phase == "Campfire" and localRole == "Murderer"
	local dangerThreshold = if isMurdererCampfire then 20 else 10
	local amberThreshold = if isMurdererCampfire then 60 else 30
	local seconds = math.max(0, math.ceil(readNumber(round, "phaseEndsAt", 0) - currentTime))
	self.timerLabel.Text = string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
	if isMurdererCampfire and seconds <= dangerThreshold then
		self.timerLabel.TextColor3 = Theme.Colors.DangerBright
		if seconds > 0 then
			self:_startTimerPulse()
		else
			self:_stopTimerPulse()
		end
	elseif isMurdererCampfire and seconds <= amberThreshold then
		self.timerLabel.TextColor3 = Theme.Colors.Amber
		self:_stopTimerPulse()
	elseif seconds <= 10 and seconds > 0 then
		self.timerLabel.TextColor3 = Theme.Colors.DangerBright
		self:_startTimerPulse()
	else
		self.timerLabel.TextColor3 = Theme.Colors.Gold
		self:_stopTimerPulse()
	end
	if self.timerFill then
		local phaseStartedAt = readNumber(round, "phaseStartedAt", 0)
		local phaseEndsAt = readNumber(round, "phaseEndsAt", 0)
		local phaseDuration = phaseEndsAt - phaseStartedAt
		local fraction: number
		if phaseDuration > 0 then
			fraction = math.clamp((currentTime - phaseStartedAt) / phaseDuration, 0, 1)
		else
			fraction = 0
		end
		local fillColor = if seconds <= dangerThreshold
			then Theme.Colors.DangerBright
			elseif seconds <= amberThreshold then Theme.Colors.Amber
			else Theme.Colors.Gold
		self.timerFill.BackgroundColor3 = fillColor
		if self.settingsValues.reducedMotion == true then
			self.timerFill.Size = UDim2.fromScale(fraction, 1)
		else
			TweenService:Create(
				self.timerFill,
				TweenInfo.new(0.75, Enum.EasingStyle.Linear),
				{ Size = UDim2.fromScale(fraction, 1) }
			):Play()
		end
	end

	local trackedMinimumRemaining = math.huge
	if type(player) == "table" then
		local cooldowns = if type(player.abilityCooldownEndsAt) == "table"
			then player.abilityCooldownEndsAt
			else nil
		if cooldowns then
			for _, abilityId in asTable(player.abilityIds) do
				if type(abilityId) == "string" then
					local cooldownEndsAt = cooldowns[abilityId]
					if type(cooldownEndsAt) == "number"
						and cooldownEndsAt > currentTime
					then
						trackedMinimumRemaining = math.min(
							trackedMinimumRemaining,
							cooldownEndsAt - currentTime
						)
					end
				end
			end
		end
	end
	local cooldownNowActive = trackedMinimumRemaining < math.huge
		and trackedMinimumRemaining > 0
	if not cooldownNowActive and self.lastCooldownActive then
		if not Motion.IsReducedMotion(self.root) then
			Motion.PopIn(self.roleAction, { duration = 0.18, scale = 1.12 })
		end
		HapticController.Click()
	end
	self.lastCooldownActive = cooldownNowActive

	local minimumRemaining = if not self.ghostMode and self.roleAction.Active
		then trackedMinimumRemaining
		else math.huge
	local cooldownText: string? = nil
	if minimumRemaining < math.huge then
		cooldownText = string.format(
			"READY IN %ds",
			math.ceil(minimumRemaining)
		)
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

	if self.cooldownBar and self.cooldownFill then
		if minimumRemaining < math.huge then
			if self.abilityBarMaxCooldown == 0 then
				self.abilityBarMaxCooldown = minimumRemaining
			end
			local fraction = math.clamp(
				1 - minimumRemaining / self.abilityBarMaxCooldown,
				0,
				1
			)
			self.cooldownFill.BackgroundColor3 = if minimumRemaining <= 5
				then Theme.Colors.Success
				else Theme.Colors.Gold
			if self.settingsValues.reducedMotion == true then
				self.cooldownFill.Size = UDim2.fromScale(fraction, 1)
			else
				TweenService:Create(
					self.cooldownFill,
					TweenInfo.new(0.75, Enum.EasingStyle.Linear),
					{ Size = UDim2.fromScale(fraction, 1) }
				):Play()
			end
			self.cooldownBar.Visible = true
		else
			self.abilityBarMaxCooldown = 0
			self.cooldownBar.Visible = false
		end
	end

	if self.notebookBadge then
		local evidence = if type(player) == "table" and type(player.evidenceKnowledge) == "table"
			then player.evidenceKnowledge
			else {}
		-- Reset the high-water mark when evidence shrinks (new round cleared the server list)
		local evidenceCount = #evidence
		if evidenceCount < self.lastSeenEvidenceCount then
			self.lastSeenEvidenceCount = 0
			self.lastEvidenceCountForPop = 0
		end
		local newCount = math.max(0, evidenceCount - self.lastSeenEvidenceCount)
		if newCount > 0 and not modalTargetVisible(self.notebook) then
			self.notebookBadge.Text = tostring(math.min(newCount, 9))
			self.notebookBadge.Visible = true
			local previousCount = self.lastEvidenceCountForPop
			self.lastEvidenceCountForPop = newCount
			if newCount > previousCount and not Motion.IsReducedMotion(self.root) then
				Motion.PopIn(self.notebookBadge, { duration = 0.22, scale = 1.28 })
			end
		else
			self.notebookBadge.Visible = false
			self.lastEvidenceCountForPop = 0
		end
	end
end

function GameView:ToggleNotebook()
	setModalVisible(self.settings, false)
	setModalVisible(self.progression, false)
	local codexForNotebook = self.codex
	if codexForNotebook then
		setModalVisible(codexForNotebook, false)
	end
	local willOpen = not modalTargetVisible(self.notebook)
	setModalVisible(self.notebook, willOpen)
	if willOpen then
		HapticController.Click()
		local currentState = self.currentState
		local player = if type(currentState) == "table" then currentState.player else nil
		local evidence = if type(player) == "table" and type(player.evidenceKnowledge) == "table"
			then player.evidenceKnowledge
			else {}
		self.lastSeenEvidenceCount = #evidence
		if self.notebookBadge then
			self.notebookBadge.Visible = false
		end
	end
end

function GameView:ToggleSettings()
	setModalVisible(self.notebook, false)
	setModalVisible(self.progression, false)
	local codexForSettings = self.codex
	if codexForSettings then
		setModalVisible(codexForSettings, false)
	end
	setModalVisible(self.settings, not modalTargetVisible(self.settings))
end

function GameView:ToggleProgression()
	setModalVisible(self.notebook, false)
	setModalVisible(self.settings, false)
	setModalVisible(self.resultModal, false)
	local codexForProgression = self.codex
	if codexForProgression then
		setModalVisible(codexForProgression, false)
	end
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
	local codexForClose = self.codex
	if codexForClose then
		setModalVisible(codexForClose, false)
	end
	setModalVisible(self.targetModal, false)
	if modalTargetVisible(self.resultModal) then
		setModalVisible(self.resultModal, false)
	end
end

function GameView:ActivateInventorySlot(slot: number)
	if self.ghostMode or self.eliminatedMode then
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
	if self.eliminatedMode or slot < 1 or slot > #self.inventoryItems then
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
	if self.eliminatedMode then
		self:HideInteraction()
		return
	end
	if self.ghostMode then
		self:HideInteraction()
		return
	end
	self.interactionKey.Text = inputText
	self.interactionText.Text = actionText .. if objectText ~= "" then "\n" .. objectText else ""
	local wasVisible = self.interaction.Visible
	self.interaction.Visible = true
	if not wasVisible and not Motion.IsReducedMotion(self.interaction) then
		Motion.PopIn(self.interaction, { duration = 0.15 })
	end
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
	onComplete: (() -> ())?,
	localRole: string?
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
			self.resultTitle.Text = if localRole == "Murderer"
				then "EXPOSED"
				else "THE CULPRIT IS FOUND"
			self.resultTitle.TextColor3 = Theme.Colors.Gold
			self.resultBody.Text = if localRole == "Murderer"
				then "The camp unmasked you. The hunt is over."
				else culpritName .. " was the " .. safeMonsterId
			Components.PlayUISound("success")
			if not reducedMotion then
				self:_playVoteConfetti(token)
			end
		else
			self.resultTitle.Text = if localRole == "Murderer"
				then "YOU SURVIVED THE VOTE"
				else "THE MONSTER ESCAPES"
			self.resultTitle.TextColor3 = Theme.Colors.DangerBright
			self.resultBody.Text = if localRole == "Murderer"
				then "The camp guessed wrong. You remain hidden."
				else safeMonsterId .. " was never caught"
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
			if isMonster then "YOU ARE THE THREAT" else "YOUR ROLE",
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

function GameView:PlayWinReveal(winner: string, isHumanWin: boolean, localRole: string?)
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
	-- Cover the real screen, not just the inset area, so the cinematic block
	-- reaches the top edge and the faction strips hug the actual borders
	-- instead of drawing a floating line under the topbar.
	local winInset = game:GetService("GuiService"):GetGuiInset()
	overlay.Position = UDim2.fromOffset(0, -winInset.Y)
	overlay.Size = UDim2.new(1, 0, 1, winInset.Y)
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
	-- "CAMPERS WIN" but "MURDERER WINS" — match the verb to the noun's number
	-- (the results modal already uses the singular form).
	local winVerb = if string.sub(safeWinner, -1) == "S" then " WIN" else " WINS"
	local title = Components.Label(
		overlay,
		"WinnerTitle",
		safeWinner .. winVerb,
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

	local resolvedRole = localRole or ""
	if resolvedRole == "Murderer" then
		if isHumanWin then
			title.Text = "CAUGHT"
			subtitle.Text = "The camp unmasked you. Your hunt is over."
		else
			title.Text = "YOU ESCAPED"
			subtitle.Text = "Your identity was never revealed. A flawless hunt."
		end
	end

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

function GameView:_cancelRoundSummary()
	self.roundSummaryToken += 1
	local overlay = self.roundSummaryOverlay
	self.roundSummaryOverlay = nil
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

function GameView:PlayRoundSummary(stats: RoundSummaryStats)
	if self.destroyed then
		return
	end
	self:_cancelRoundSummary()
	local token = self.roundSummaryToken

	-- Let the win reveal finish its normal exit before presenting the recap.
	task.delay(2.7, function()
		if self.destroyed or self.roundSummaryToken ~= token then
			return
		end

		local factionColor = if stats.isHumanWin
			then Theme.Colors.Gold
			else Theme.Colors.DangerBright
		local overlay = Instance.new("CanvasGroup")
		overlay.Name = "RoundSummaryOverlay"
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		overlay.BackgroundTransparency = 0.55
		overlay.GroupTransparency = 1
		overlay.BorderSizePixel = 0
		overlay.Active = true
		overlay.ZIndex = 80
		overlay.Parent = self.root
		self.roundSummaryOverlay = overlay

		local card = Instance.new("Frame")
		card.Name = "SummaryCard"
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.5)
		card.Size = UDim2.fromOffset(520, 380)
		card.BackgroundColor3 = Theme.Colors.Panel
		card.BackgroundTransparency = 0.06
		card.BorderSizePixel = 0
		card.ZIndex = 81
		card.Parent = overlay
		Components.Corner(card, 12)

		local strip = Instance.new("Frame")
		strip.Name = "AccentStrip"
		strip.Size = UDim2.new(1, 0, 0, 4)
		strip.BackgroundColor3 = factionColor
		strip.BorderSizePixel = 0
		strip.ZIndex = 82
		strip.Parent = card
		Components.Corner(strip, 12)

		local header = Components.Label(
			card,
			"Header",
			string.format("ROUND %d RECAP", stats.roundNumber),
			22,
			Enum.Font.GothamBold
		)
		header.Position = UDim2.fromOffset(24, 18)
		header.Size = UDim2.new(1, -48, 0, 28)
		header.TextColor3 = Theme.Colors.Gold
		header.TextXAlignment = Enum.TextXAlignment.Center
		header.ZIndex = 82

		local winText = if stats.playerRole == "Murderer"
			then if stats.isHumanWin then "YOU WERE CAUGHT" else "YOU ESCAPED"
			else if stats.isHumanWin then "THE CAMP SURVIVED" else "THE MONSTER ESCAPED"
		local winLabel = Components.Label(
			card,
			"WinLine",
			winText,
			15,
			Enum.Font.GothamBold
		)
		winLabel.Position = UDim2.fromOffset(24, 50)
		winLabel.Size = UDim2.new(1, -48, 0, 22)
		winLabel.TextColor3 = factionColor
		winLabel.TextXAlignment = Enum.TextXAlignment.Center
		winLabel.ZIndex = 82

		local divider = Instance.new("Frame")
		divider.Name = "Divider"
		divider.Position = UDim2.fromOffset(32, 80)
		divider.Size = UDim2.new(1, -64, 0, 1)
		divider.BackgroundColor3 = Theme.Colors.Ghost
		divider.BackgroundTransparency = 0.7
		divider.BorderSizePixel = 0
		divider.ZIndex = 82
		divider.Parent = card

		local function statRow(
			yOffset: number,
			labelText: string,
			valueText: string,
			valueColor: Color3?
		)
			local label = Components.Label(
				card,
				labelText .. "Label",
				labelText,
				14
			)
			label.Position = UDim2.fromOffset(36, yOffset)
			label.Size = UDim2.fromOffset(240, 26)
			label.TextColor3 = Theme.Colors.TextMuted
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.ZIndex = 82

			local value = Components.Label(
				card,
				labelText .. "Value",
				valueText,
				14,
				Enum.Font.GothamBold
			)
			value.Position = UDim2.new(1, -36, 0, yOffset)
			value.AnchorPoint = Vector2.new(1, 0)
			value.Size = UDim2.fromOffset(210, 26)
			value.TextColor3 = valueColor or Theme.Colors.Text
			value.TextXAlignment = Enum.TextXAlignment.Right
			value.ZIndex = 82
		end

		if stats.playerRole == "Murderer" then
			local wasCaught = stats.wasCaught == true
			statRow(
				96,
				"Outcome",
				if wasCaught then "CAUGHT" else "ESCAPED",
				if wasCaught then Theme.Colors.DangerBright else Theme.Colors.Success
			)
			statRow(
				128,
				"Eliminations",
				string.format("%d", stats.killCount or 0),
				Theme.Colors.DangerBright
			)
			statRow(
				160,
				"Votes Against You",
				string.format("%d", stats.votesAgainstMe or 0),
				Theme.Colors.Text
			)
			statRow(
				192,
				"Survivors Remaining",
				string.format("%d of %d", stats.survivorCount, stats.totalParticipants),
				Theme.Colors.Text
			)
		else
			local survivorColor = if stats.survivorCount == 0
				then Theme.Colors.DangerBright
				elseif stats.survivorCount >= stats.totalParticipants
				then Theme.Colors.Success
				else Theme.Colors.Text
			statRow(
				96,
				"Survivors",
				string.format("%d of %d", stats.survivorCount, stats.totalParticipants),
				survivorColor
			)
			statRow(
				128,
				"Evidence",
				string.format("%d / %d clues", stats.evidenceFound, stats.evidenceGoal),
				if stats.evidenceFound >= stats.evidenceGoal
					then Theme.Colors.Success
					else Theme.Colors.Text
			)
			statRow(
				160,
				"Camp Tasks",
				string.format("%d / %d", stats.objectivesCompleted, stats.objectiveGoal),
				if stats.objectivesCompleted >= stats.objectiveGoal
					then Theme.Colors.Success
					else Theme.Colors.Text
			)

			if stats.monsterId and stats.monsterId ~= "" then
				local monsterDisplay = stats.monsterId
					:gsub("(%l)(%u)", "%1 %2")
					:gsub("-", " ")
				statRow(192, "Monster", monsterDisplay, Theme.Colors.DangerBright)
			end
			if stats.victimName and stats.victimName ~= "" then
				statRow(224, "Victim", stats.victimName, Theme.Colors.TextMuted)
			end
		end

		if stats.playerRole ~= "Murderer"
			and stats.playerRole ~= "Spectator"
			and stats.personalEvidence > 0
		then
			local personalLabel = Components.Label(
				card,
				"PersonalContrib",
				string.format(
					"You contributed %d evidence piece%s.",
					stats.personalEvidence,
					if stats.personalEvidence == 1 then "" else "s"
				),
				13
			)
			personalLabel.Position = UDim2.fromOffset(24, 270)
			personalLabel.Size = UDim2.new(1, -48, 0, 22)
			personalLabel.TextColor3 = Theme.Colors.Gold
			personalLabel.TextXAlignment = Enum.TextXAlignment.Center
			personalLabel.ZIndex = 82
		end

		local countdownLabel = Components.Label(
			card,
			"Countdown",
			"Auto-advancing in 8s",
			12
		)
		countdownLabel.Position = UDim2.fromOffset(24, 302)
		countdownLabel.Size = UDim2.new(1, -48, 0, 20)
		countdownLabel.TextColor3 = Theme.Colors.TextMuted
		countdownLabel.TextXAlignment = Enum.TextXAlignment.Center
		countdownLabel.ZIndex = 82

		local dismissButton = Components.Button(card, {
			name = "DismissBtn",
			text = "VIEW REWARDS →",
			size = UDim2.fromOffset(190, 44),
			position = UDim2.new(0.5, 0, 1, -60),
			color = Theme.Colors.Gold,
		})
		dismissButton.AnchorPoint = Vector2.new(0.5, 0)
		dismissButton.ZIndex = 82

		local dismissed = false
		local function active(): boolean
			return not self.destroyed
				and self.roundSummaryToken == token
				and self.roundSummaryOverlay == overlay
				and overlay.Parent ~= nil
		end
		local function cleanup()
			if overlay.Parent then
				overlay:Destroy()
			end
			if self.roundSummaryOverlay == overlay then
				self.roundSummaryOverlay = nil
			end
		end
		local function dismiss()
			if dismissed or not active() then
				return
			end
			dismissed = true
			if Motion.IsReducedMotion(self.root) then
				cleanup()
				return
			end
			Motion.FadeOut(overlay, {
				duration = 0.35,
				onComplete = function(_completed: boolean)
					cleanup()
				end,
			})
		end

		dismissButton.Activated:Connect(dismiss)
		task.spawn(function()
			local countdown = 8
			while countdown > 0 and not dismissed and active() do
				task.wait(1)
				countdown -= 1
				if active() then
					countdownLabel.Text = if countdown > 0
						then string.format("Auto-advancing in %ds", countdown)
						else "Advancing..."
				end
			end
			if not dismissed and active() then
				dismiss()
			end
		end)

		-- GroupTransparency must be at target value (0) before FadeIn so it
		-- captures the correct target; without this, FadeIn captures 1 and the
		-- overlay stays invisible for the entire round summary.
		overlay.GroupTransparency = 0
		if not Motion.IsReducedMotion(self.root) then
			Motion.FadeIn(overlay)
		end
	end)
end

function GameView:PlayDeathCinematic(deathCause: string?, localRole: string?)
	if self.destroyed then
		return
	end
	local cause = deathCause or "killed"
	local dRole = localRole or ""
	local headingText = "YOU HAVE FALLEN"
	local subText = "Your spirit remains — watch over the living."
	if dRole == "Murderer" then
		headingText = "CAUGHT"
		subText = "The camp saw through you. Your hunt is over."
	elseif cause == "voted" then
		headingText = "VOTED OUT"
		subText = "The camp made their choice. Watch over the living."
	end

	self.deathCinematicToken += 1
	local token = self.deathCinematicToken
	local prev = self.deathCinematicOverlay
	if prev then
		prev:Destroy()
		self.deathCinematicOverlay = nil
	end

	local overlay = Instance.new("CanvasGroup")
	overlay.Name = "DeathCinematic"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = 0
	overlay.GroupTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 92
	overlay.Parent = self.root
	self.deathCinematicOverlay = overlay

	local heading = Components.Label(
		overlay,
		"DeathHeading",
		headingText,
		math.floor(Theme.Typography.HeadingSize * 1.6),
		Theme.Typography.HeadingFont
	)
	heading.AnchorPoint = Vector2.new(0.5, 0.5)
	heading.Position = UDim2.new(0.5, 0, 0.44, 0)
	heading.Size = UDim2.new(0.9, 0, 0, 56)
	heading.TextColor3 = Theme.Colors.White
	heading.TextXAlignment = Enum.TextXAlignment.Center
	heading.ZIndex = 93
	Components.SetLetterspacedText(heading, headingText)

	local sub = Components.Label(
		overlay,
		"DeathSub",
		subText,
		Theme.Typography.CaptionSize,
		Theme.Typography.CaptionFont
	)
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	sub.Position = UDim2.new(0.5, 0, 0.56, 0)
	sub.Size = UDim2.new(0.7, 0, 0, 28)
	sub.TextColor3 = Theme.Colors.White
	sub.TextTransparency = 0.3
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.ZIndex = 93

	local function active(): boolean
		return not self.destroyed
			and self.deathCinematicToken == token
			and overlay.Parent ~= nil
	end

	if Motion.IsReducedMotion(self.root) then
		overlay.GroupTransparency = 0
		task.delay(2.5, function()
			if active() then
				overlay:Destroy()
				if self.deathCinematicOverlay == overlay then
					self.deathCinematicOverlay = nil
				end
			end
		end)
		return
	end

	overlay.GroupTransparency = 0
	Motion.FadeIn(overlay, { duration = 0.4 })
	task.delay(2.5, function()
		if not active() then
			return
		end
		Motion.FadeOut(overlay, {
			duration = 0.5,
			onComplete = function(_completed: boolean)
				if active() then
					overlay:Destroy()
					if self.deathCinematicOverlay == overlay then
						self.deathCinematicOverlay = nil
					end
				end
			end,
		})
	end)
end

function GameView:PlayPhaseTitleCard(phaseName: string, isReconnect: boolean, localRole: string?, isObserver: boolean?)
	local defaultEntry = PhaseTitles[phaseName]
	local murdererEntry = if type(defaultEntry) == "table" then defaultEntry.murderer else nil
	local observerEntry = if type(defaultEntry) == "table" then defaultEntry.observer else nil
	local entry = if localRole == "Murderer" and type(murdererEntry) == "table"
		then murdererEntry
		elseif isObserver and type(observerEntry) == "table"
		then observerEntry
		else defaultEntry
	local tipText = if localRole == "Murderer" and type(murdererEntry) == "table"
		then murdererEntry.tip
		elseif isObserver and type(observerEntry) == "table"
		then observerEntry.tip
		else PhaseTips[phaseName]
	if self.destroyed
		or isReconnect
		or self.roleRevealActive
		or type(entry) ~= "table"
		-- The letterbox band would print straight across the results modal
		-- (vote tally / mystery-resolved card); with that card up the phase
		-- change is already narrated on screen.
		or modalTargetVisible(self.resultModal)
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
	band.Size = UDim2.new(1, 0, 0, 120)
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
	title.Position = UDim2.fromOffset(16, 8)
	title.Size = UDim2.new(1, -32, 0, 40)
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
	subtitle.Position = UDim2.fromOffset(16, 50)
	subtitle.Size = UDim2.new(1, -32, 0, 24)
	subtitle.TextColor3 = Theme.Colors.White
	subtitle.TextTransparency = 0.7
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.ZIndex = 81

	if tipText then
		local tip = Components.Label(
			band,
			"PhaseTip",
			tipText,
			10,
			Theme.Typography.CaptionFont
		)
		tip.Position = UDim2.fromOffset(16, 76)
		tip.Size = UDim2.new(1, -32, 0, 20)
		tip.TextColor3 = Theme.Colors.White
		tip.TextTransparency = 0.55
		tip.TextXAlignment = Enum.TextXAlignment.Center
		tip.ZIndex = 81
	end

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
		self:Notify("Evidence found", safeName .. " — " .. safeDescription, "Success")
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
	-- The banner slides in directly over the top phase status; both panels are
	-- translucent, so hide the status while the banner is up or the two titles
	-- overprint into unreadable double text
	self.topStatus.Visible = false
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
			self.topStatus.Visible = true
			if reducedMotion then
				self.announcement.Position = UDim2.new(0.5, 0, 0, -160)
			else
				TweenService:Create(
					self.announcement,
					TweenInfo.new(0.2),
					{ Position = UDim2.new(0.5, 0, 0, -160) }
				):Play()
			end
		end
	end)
end

function GameView:PrepareReconnectSnapshot(phaseName: string)
	self.notebook:SetAttribute("SuppressNextStagger", true)
	Motion.Cancel(self.evidenceList)

	local existingOverlay = self.root:FindFirstChild("ReconnectOverlay")
	if existingOverlay then
		if existingOverlay:IsA("GuiObject") then
			Motion.Cancel(existingOverlay)
		end
		existingOverlay:Destroy()
	end
	if phaseName == "Lobby" or phaseName == "Rewards" then
		return
	end

	local reconnectOverlay = Instance.new("CanvasGroup")
	reconnectOverlay.Name = "ReconnectOverlay"
	reconnectOverlay.Size = UDim2.fromScale(1, 1)
	reconnectOverlay.BackgroundColor3 = Color3.fromRGB(8, 10, 12)
	reconnectOverlay.BackgroundTransparency = 0
	reconnectOverlay.GroupTransparency = 0
	reconnectOverlay.BorderSizePixel = 0
	reconnectOverlay.Active = false
	reconnectOverlay.ZIndex = 90
	reconnectOverlay.Parent = self.root

	local phaseDisplayMap: { [string]: string } = {
		RoleReveal = "ROLE REVEAL",
		Day = "DAY PHASE",
		MurderPlanning = "NIGHT PLANNING",
		NightTransform = "NIGHT FALLS",
		Investigation = "NIGHT INVESTIGATION",
		Campfire = "CAMPFIRE VOTE",
		Resolution = "MYSTERY RESOLVED",
	}
	local phaseDisplay = phaseDisplayMap[phaseName] or string.upper(phaseName)

	local reconnectLabel = Components.Label(
		reconnectOverlay,
		"ReconnectLabel",
		"RETURNING TO CAMP",
		28,
		Enum.Font.GothamBold
	)
	reconnectLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	reconnectLabel.Position = UDim2.fromScale(0.5, 0.46)
	reconnectLabel.Size = UDim2.new(1, -48, 0, 44)
	reconnectLabel.TextColor3 = Theme.Colors.White
	reconnectLabel.TextXAlignment = Enum.TextXAlignment.Center
	reconnectLabel.ZIndex = 91

	local reconnectPhaseLabel = Components.Label(
		reconnectOverlay,
		"PhaseLabel",
		phaseDisplay,
		14,
		Enum.Font.Gotham
	)
	reconnectPhaseLabel.AnchorPoint = Vector2.new(0.5, 0)
	reconnectPhaseLabel.Position = UDim2.fromScale(0.5, 0.54)
	reconnectPhaseLabel.Size = UDim2.new(1, -48, 0, 22)
	reconnectPhaseLabel.TextColor3 = Theme.Colors.Gold
	reconnectPhaseLabel.TextTransparency = 0.2
	reconnectPhaseLabel.TextXAlignment = Enum.TextXAlignment.Center
	reconnectPhaseLabel.ZIndex = 91

	local reducedMotion = Motion.IsReducedMotion(self.root)
	task.delay(1.5, function()
		if self.destroyed or reconnectOverlay.Parent == nil then
			return
		end
		if reducedMotion then
			reconnectOverlay:Destroy()
			return
		end
		Motion.FadeOut(reconnectOverlay, {
			duration = 0.5,
			onComplete = function(_completed: boolean)
				if reconnectOverlay.Parent then
					reconnectOverlay:Destroy()
				end
			end,
		})
	end)
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
	local existingToasts: { GuiObject } = {}
	for _, child in self.toastList:GetChildren() do
		if child:IsA("GuiObject") and child.Name == "Toast" then
			table.insert(existingToasts, child)
		end
	end
	-- Evict the oldest toasts first so the most recent information stays visible
	for index = 1, #existingToasts - 3 do
		local stale = existingToasts[index]
		Motion.Cancel(stale)
		stale:Destroy()
	end
	local toast = Components.Panel(self.toastList, "Toast")
	toast.Size = UDim2.new(1, 0, 0, 70)
	toast.BackgroundColor3 = if kind == "DangerBright"
		then Theme.Colors.DangerBright
		elseif kind == "Danger" then Theme.Colors.Danger
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
	if kind == "Danger" or kind == "DangerBright" or kind == "Warning" then
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
	self:_cancelRoundSummary()
	self:_stopTimerPulse()
	self:_cancelVoteReveal()
	self:_cancelEvidenceDiscovery()
	self:_dismissInterviewPicker(true)
	self:_dismissCounselorDialogue(true)
	self.keybindHintToken += 1
	if self.keybindHintOverlay then
		Motion.Cancel(self.keybindHintOverlay)
		self.keybindHintOverlay:Destroy()
		self.keybindHintOverlay = nil
	end
	if self.deathCinematicOverlay then
		self.deathCinematicOverlay:Destroy()
		self.deathCinematicOverlay = nil
	end
	if self.cooldownBar then
		self.cooldownBar:Destroy()
		self.cooldownBar = nil
	end
	self.cooldownFill = nil
	self.abilityBarMaxCooldown = 0
	if self.monsterPanel then
		Motion.Cancel(self.monsterPanel)
		self.monsterPanel:Destroy()
		self.monsterPanel = nil
	end
	self.monsterNameLabel = nil
	self.monsterStaminaFill = nil
	self.monsterAbilityLabel = nil
	self.monsterNoteLabel = nil
	self.monsterPanelVisible = false
	self.rosterPanelVisible = false
	if self.phaseArc then
		self.phaseArc:Destroy()
		self.phaseArc = nil
	end
	table.clear(self.phaseArcDots)
	if self.rosterPanel then
		self.rosterPanel:Destroy()
		self.rosterPanel = nil
	end
	self.lastRosterSignature = ""
	self.voteModalTitleLabel = nil
	self.voteCountLabel = nil
	self.voteWarningLabel = nil
	self.localVoteHasLocked = false
	self.dayObjectiveNotifiedRound = nil
	self.evidenceNotifiedRound = nil
	if self.ghostBadgePulse then
		self.ghostBadgePulse:Cancel()
		self.ghostBadgePulse = nil
	end
	if self.eliminatedBanner then
		self.eliminatedBanner:Destroy()
		self.eliminatedBanner = nil
	end
	self.eliminatedMode = false
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
