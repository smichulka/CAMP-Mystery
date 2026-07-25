--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RuntimeTypes = require(Shared:WaitForChild("Types"):WaitForChild("RuntimeTypes"))
local uiFolder = script.Parent.Parent:WaitForChild("UI")
local GameViewModule = require(uiFolder:WaitForChild("GameView"))
local EffectsViewModule = require(uiFolder:WaitForChild("EffectsView"))
local AccessibilityController = require(script.Parent:WaitForChild("AccessibilityController"))
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local InputController = require(script.Parent:WaitForChild("InputController"))
local InteractionController = require(script.Parent:WaitForChild("InteractionController"))
local RemoteBridgeModule = require(script.Parent:WaitForChild("RemoteBridge"))
local TutorialController = require(script.Parent:WaitForChild("TutorialController"))

type GameState = RuntimeTypes.GameState
type ActionResult = RuntimeTypes.ActionResult
type Announcement = RuntimeTypes.Announcement
type GameView = GameViewModule.GameView
type RemoteBridge = RemoteBridgeModule.RemoteBridge

local RoundController = {}

local started = false
local state: GameState? = nil
local legacyRound: any = nil
local legacyPlayer: any = nil
local view: GameView? = nil
local bridge: RemoteBridge? = nil
local accessibility: any = nil
local audio: any = nil
local effects: any = nil
local tutorial: any = nil
local interactionConnections: { RBXScriptConnection } = {}

local function refresh()
	local currentView = view
	if currentView then
		currentView:Update(state, legacyRound, legacyPlayer)
	end
end

local function updateReleaseExperience(snapshot: GameState)
	local currentAccessibility = accessibility
	local currentAudio = audio
	local currentEffects = effects
	local currentTutorial = tutorial
	local currentView = view
	if not currentAccessibility or not currentAudio or not currentEffects or not currentTutorial then
		return
	end
	currentAccessibility:ApplyGameState(snapshot)
	local reducedMotion = currentAccessibility:IsReducedMotion()
	currentEffects:SetReducedMotion(reducedMotion)
	currentTutorial:SetReducedMotion(reducedMotion)
	local profile = snapshot.profile
	local profileData = if profile then profile.profile else nil
	local settings = if profileData then profileData.settings else nil
	if settings and settings.tutorialCompleted then
		currentTutorial:SetCompleted(true)
	end
	currentTutorial:Update(snapshot)
	currentAudio:Update(snapshot)
	currentEffects:Update(snapshot)
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
			currentView:Notify("Action failed", "The server returned an invalid response.", "Danger")
		end
		return
	end
	local result = payload :: ActionResult
	if result.state then
		state = result.state
		refresh()
	end
	if result.accepted then
		if currentView then
			local dialogueText: string? = nil
			if type(result.data) == "table" then
				local dialogue = result.data.dialogue
				if type(dialogue) == "table" and type(dialogue.text) == "string" then
					dialogueText = dialogue.text
				end
			end
			currentView:Notify(
				if dialogueText then "Counselor interview" else "Action complete",
				dialogueText or result.reason or "The server confirmed your action.",
				"Success"
			)
		end
	elseif currentView then
		currentView:Notify("Action rejected", result.reason or "That action is not allowed right now.", "Danger")
	end
end

function RoundController.Start()
	if started then
		return
	end
	started = true

	local remoteBridge = RemoteBridgeModule.new()
	bridge = remoteBridge
	local gameView = GameViewModule.new(requestAction)
	view = gameView
	local releaseEffects = EffectsViewModule.new(gameView.root)
	effects = releaseEffects
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
			releaseEffects:ShowAnnouncement(payload)
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
	if bridge then
		bridge:Destroy()
	end
	if tutorial then
		tutorial:Destroy()
	end
	if audio then
		audio:Destroy()
	end
	if accessibility then
		accessibility:Destroy()
	end
	if effects then
		effects:Destroy()
	end
	if view and view.root.Parent then
		view.root:Destroy()
	end
	bridge = nil
	tutorial = nil
	audio = nil
	accessibility = nil
	effects = nil
	view = nil
	state = nil
	legacyRound = nil
	legacyPlayer = nil
end

return table.freeze(RoundController)
