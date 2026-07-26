--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RuntimeTypes = require(Shared:WaitForChild("Types"):WaitForChild("RuntimeTypes"))
local uiFolder = script.Parent.Parent:WaitForChild("UI")
local Components = require(uiFolder:WaitForChild("Components"))
local GameViewModule = require(uiFolder:WaitForChild("GameView"))
local EffectsViewModule = require(uiFolder:WaitForChild("EffectsView"))
local Motion = require(uiFolder:WaitForChild("Motion"))
local AccessibilityController = require(script.Parent:WaitForChild("AccessibilityController"))
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local CinematicsController = require(script.Parent:WaitForChild("CinematicsController"))
local InputController = require(script.Parent:WaitForChild("InputController"))
local InteractionController = require(script.Parent:WaitForChild("InteractionController"))
local RemoteBridgeModule = require(script.Parent:WaitForChild("RemoteBridge"))
local TutorialController = require(script.Parent:WaitForChild("TutorialController"))
local UIAssetControllerModule = require(script.Parent:WaitForChild("UIAssetController"))

type GameState = RuntimeTypes.GameState
type ActionResult = RuntimeTypes.ActionResult
type Announcement = RuntimeTypes.Announcement
type GameView = GameViewModule.GameView
type RemoteBridge = RemoteBridgeModule.RemoteBridge
type UIAssetController = UIAssetControllerModule.UIAssetController

local RoundController = {}

local started = false
local state: GameState? = nil
local legacyRound: any = nil
local legacyPlayer: any = nil
local view: GameView? = nil
local bridge: RemoteBridge? = nil
local accessibility: any = nil
local audio: any = nil
local cinematics: any = nil
local effects: any = nil
local tutorial: any = nil
local uiAssets: UIAssetController? = nil
local interactionConnections: { RBXScriptConnection } = {}
local lastCinematicPhase: string? = nil

local function refresh()
	local currentView = view
	if currentView then
		currentView:Update(state, legacyRound, legacyPlayer)
	end
end

local function updateReleaseExperience(snapshot: GameState)
	local currentAccessibility = accessibility
	local currentAudio = audio
	local currentCinematics = cinematics
	local currentEffects = effects
	local currentTutorial = tutorial
	local currentView = view
	if not currentAccessibility
		or not currentAudio
		or not currentCinematics
		or not currentEffects
		or not currentTutorial
	then
		return
	end
	currentAccessibility:ApplyGameState(snapshot)
	local reducedMotion = currentAccessibility:IsReducedMotion()
	currentEffects:SetReducedMotion(reducedMotion)
	currentTutorial:SetReducedMotion(reducedMotion)
	local profile = if type(snapshot) == "table" then snapshot.profile else nil
	local profileData = if type(profile) == "table" and type(profile.profile) == "table"
		then profile.profile
		else nil
	local settings = if type(profileData) == "table" and type(profileData.settings) == "table"
		then profileData.settings
		else nil
	if settings and settings.tutorialCompleted == true then
		currentTutorial:SetCompleted(true)
	end
	if settings and type(settings.mouseSensitivity) == "number" then
		UserInputService.MouseDeltaSensitivity = math.clamp(settings.mouseSensitivity, 0.1, 3)
	end
	if settings and type(settings.controllerSensitivity) == "number" then
		pcall(function()
			local userGameSettings = UserSettings():GetService("UserGameSettings")
			local writableGameSettings = userGameSettings :: any
			writableGameSettings.GamepadCameraSensitivity =
				math.clamp(settings.controllerSensitivity, 0.1, 3)
		end)
	end
	currentTutorial:Update(snapshot)
	currentAudio:Update(snapshot)
	currentEffects:Update(snapshot)
	local round = if type(snapshot) == "table" then snapshot.round else nil
	local phaseName = if type(round) == "table" and type(round.phase) == "string"
		then round.phase
		else nil
	if phaseName and phaseName ~= lastCinematicPhase then
		lastCinematicPhase = phaseName
		currentCinematics:PlayPhaseTransition(phaseName)
	end
	if currentView then
		currentAccessibility:ScanEvidence(currentView.root)
	end
end

local function requestAction(actionName: string, payload: any): (boolean, string?)
	local currentBridge = bridge
	if not currentBridge then
		return false, "The camp radio is not connected."
	end
	return currentBridge:Request(actionName, payload)
end

local function handleActionResult(payload: any)
	local currentView = view
	if type(payload) ~= "table" then
		if currentView then
			currentView:HandleActionResult(false)
			currentView:Notify("Action failed", "The server returned an invalid response.", "Danger")
		end
		return
	end
	local result = payload :: ActionResult
	if type(result.state) == "table" then
		state = result.state
		refresh()
		updateReleaseExperience(result.state)
	end
	local accepted = result.accepted == true
	local reason = if type(result.reason) == "string" then result.reason else nil
	if accepted then
		if currentView then
			currentView:HandleActionResult(true)
			local dialogueText: string? = nil
			if type(result.data) == "table" then
				local dialogue = result.data.dialogue
				if type(dialogue) == "table" and type(dialogue.text) == "string" then
					dialogueText = dialogue.text
				end
			end
			currentView:Notify(
				if dialogueText then "Counselor interview" else "Action complete",
				dialogueText or reason or "The server confirmed your action.",
				"Success"
			)
		end
	elseif currentView then
		currentView:HandleActionResult(false)
		currentView:Notify("Action rejected", reason or "That action is not allowed right now.", "Danger")
	end
end

function RoundController.Start()
	if started then
		return
	end
	started = true

	local remoteBridge = RemoteBridgeModule.new()
	bridge = remoteBridge
	local assetController = UIAssetControllerModule.new()
	uiAssets = assetController
	local gameView = GameViewModule.new(requestAction, function(key: string): string?
		return assetController:Resolve(key)
	end)
	view = gameView
	local releaseEffects = EffectsViewModule.new(gameView.root)
	effects = releaseEffects
	local cinematicsController = CinematicsController.new(gameView.root)
	cinematics = cinematicsController
	local accessibilityController = AccessibilityController.new(gameView.root)
	accessibility = accessibilityController
	local tutorialController = TutorialController.new(gameView.root, {
		onCompleted = function(_skipped: boolean)
			requestAction("SetSettings", {
				settings = { tutorialCompleted = true },
			})
		end,
	})
	tutorial = tutorialController
	local audioController = AudioController.new({
		onSubtitle = function(text: string, duration: number)
			if accessibilityController:AreSubtitlesEnabled() then
				releaseEffects:ShowSubtitle(text, duration)
			end
		end,
	})
	audio = audioController
	Components.SetSoundPlayer(function(eventName: string)
		audioController:PlayUIEvent(eventName)
	end)
	Motion.SetReducedMotionProvider(function(): boolean
		return accessibilityController:IsReducedMotion()
	end)
	tutorialController:Start()
	audioController:Start()

	remoteBridge:OnSnapshot("game", function(payload: any)
		if type(payload) == "table" then
			state = payload :: GameState
			refresh()
			updateReleaseExperience(state :: GameState)
		end
	end)
	remoteBridge:OnSnapshot("round", function(payload: any)
		if state == nil then
			legacyRound = payload
			refresh()
		end
	end)
	remoteBridge:OnSnapshot("player", function(payload: any)
		if state == nil then
			legacyPlayer = payload
			refresh()
		end
	end)
	remoteBridge:OnSnapshot("announcement", function(payload: any)
		if type(payload) == "table" then
			gameView:Announce(payload :: Announcement)
		end
	end)
	remoteBridge:OnActionResult(handleActionResult)

	InputController.Start({
		toggleNotebook = function()
			gameView:ToggleNotebook()
		end,
		toggleSettings = function()
			gameView:ToggleSettings()
		end,
		activateSlot = function(slot: number)
			gameView:ActivateInventorySlot(slot)
		end,
		selectSlot = function(slot: number)
			gameView:SelectInventorySlot(slot)
		end,
		getSlotCount = function()
			return gameView:GetInventorySlotCount()
		end,
		closeModal = function()
			gameView:CloseModal()
		end,
	})

	interactionConnections = InteractionController.Start({
		shown = function(actionText: string, objectText: string, inputText: string)
			gameView:ShowInteraction(actionText, objectText, inputText)
		end,
		hidden = function()
			gameView:HideInteraction()
		end,
		triggered = function(actionText: string)
			gameView:Notify("Interaction complete", actionText, "Success")
		end,
	})

	remoteBridge:Start()
	refresh()
	task.spawn(function()
		while started and gameView.root.Parent do
			gameView:Tick()
			task.wait(0.2)
		end
	end)
end

function RoundController.Stop()
	if not started then
		return
	end
	started = false
	InputController.Stop()
	for _, connection in interactionConnections do
		connection:Disconnect()
	end
	table.clear(interactionConnections)
	Components.SetSoundPlayer(nil)
	Motion.SetReducedMotionProvider(nil)
	if bridge then
		bridge:Destroy()
	end
	if tutorial then
		tutorial:Destroy()
	end
	if audio then
		audio:Destroy()
	end
	if cinematics then
		cinematics:Destroy()
	end
	if accessibility then
		accessibility:Destroy()
	end
	if effects then
		effects:Destroy()
	end
	if view then
		view:Destroy()
	end
	if uiAssets then
		uiAssets:Destroy()
	end
	bridge = nil
	tutorial = nil
	audio = nil
	cinematics = nil
	accessibility = nil
	effects = nil
	uiAssets = nil
	view = nil
	state = nil
	legacyRound = nil
	legacyPlayer = nil
	lastCinematicPhase = nil
end

return table.freeze(RoundController)
