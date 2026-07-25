--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RuntimeTypes = require(Shared:WaitForChild("Types"):WaitForChild("RuntimeTypes"))
local uiFolder = script.Parent.Parent:WaitForChild("UI")
local GameViewModule = require(uiFolder:WaitForChild("GameView"))
local InputController = require(script.Parent:WaitForChild("InputController"))
local InteractionController = require(script.Parent:WaitForChild("InteractionController"))
local RemoteBridgeModule = require(script.Parent:WaitForChild("RemoteBridge"))

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
local interactionConnections: { RBXScriptConnection } = {}

local function refresh()
	local currentView = view
	if currentView then
		currentView:Update(state, legacyRound, legacyPlayer)
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
			currentView:Notify("Action complete", result.reason or "The server confirmed your action.", "Success")
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

	remoteBridge:OnSnapshot("game", function(payload: any)
		if type(payload) == "table" then
			state = payload :: GameState
			refresh()
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
	if view and view.root.Parent then
		view.root:Destroy()
	end
	bridge = nil
	view = nil
	state = nil
	legacyRound = nil
	legacyPlayer = nil
end

return table.freeze(RoundController)
