--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local services = script.Parent:WaitForChild("Services")
local GameRuntimeService = require(services:WaitForChild("GameRuntimeService"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local gameStateChanged = remotes:WaitForChild("GameStateChanged") :: RemoteEvent
local getGameState = remotes:WaitForChild("GetGameState") :: RemoteFunction
local requestAction = remotes:WaitForChild("RequestAction") :: RemoteFunction
local announcement = remotes:WaitForChild("Announcement") :: RemoteEvent
local getRoundState = remotes:WaitForChild("GetRoundState") :: RemoteFunction
local submitVote = remotes:WaitForChild("SubmitVote") :: RemoteEvent

type RateWindow = {
	startedAt: number,
	count: number,
}

local requestWindows: { [number]: RateWindow } = {}
local REQUEST_WINDOW_SECONDS = 1
local MAX_REQUESTS_PER_WINDOW = 12

local function requestAllowed(player: Player): boolean
	local current = workspace:GetServerTimeNow()
	local window = requestWindows[player.UserId]
	if not window or current - window.startedAt >= REQUEST_WINDOW_SECONDS then
		requestWindows[player.UserId] = {
			startedAt = current,
			count = 1,
		}
		return true
	end
	if window.count >= MAX_REQUESTS_PER_WINDOW then
		return false
	end
	window.count += 1
	return true
end

local runtime = GameRuntimeService.new({
	autoRun = true,
	fillWithBots = true,
	onStateChanged = function(player: Player, state)
		gameStateChanged:FireClient(player, state)
	end,
	onAnnouncement = function(kind: string, title: string, message: string, duration: number?)
		announcement:FireAllClients({
			kind = kind,
			title = title,
			message = message,
			duration = duration,
		})
	end,
})

getGameState.OnServerInvoke = function(player: Player)
	return runtime:GetGameState(player)
end

requestAction.OnServerInvoke = function(player: Player, actionName: unknown, payload: unknown)
	if typeof(actionName) ~= "string" or actionName == "" then
		return {
			accepted = false,
			reason = "Action name is required",
		}
	end
	if not requestAllowed(player) then
		return {
			accepted = false,
			reason = "Too many requests; wait a moment",
		}
	end
	return runtime:HandleAction(player, actionName, payload)
end

-- Keep the validated gray-box getter and vote contract available to older clients.
getRoundState.OnServerInvoke = function(_player: Player)
	return runtime:GetRoundSnapshot()
end

submitVote.OnServerEvent:Connect(function(player: Player, suspectKey: unknown)
	if typeof(suspectKey) == "string" and requestAllowed(player) then
		runtime:HandleAction(player, "Vote", {
			targetKey = suspectKey,
			targetParticipantId = suspectKey,
		})
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	requestWindows[player.UserId] = nil
end)

runtime:Start()

game:BindToClose(function()
	runtime:Stop()
end)

print("[CAMP-Mystery] Production server started")
