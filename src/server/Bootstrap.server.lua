--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundService = game:GetService("SoundService")

local serverRoot = script.Parent
local config = serverRoot:WaitForChild("Config")
local services = serverRoot:WaitForChild("Services")
local ProfileStoreConfiguration = require(config:WaitForChild("ProfileStoreConfiguration"))
local MonsterAudioConfig = require(config:WaitForChild("MonsterAudioConfig"))

-- Apply configured monster hunt-loop audio slots; attributes already set on
-- SoundService (e.g. Studio experiments) take precedence over the config file
for monsterId, assetId in MonsterAudioConfig do
	local attributeName = "MonsterHunt" .. monsterId .. "AssetId"
	if SoundService:GetAttribute(attributeName) == nil and assetId ~= 0 then
		SoundService:SetAttribute(attributeName, assetId)
	end
end
local ProfileServiceReliabilityPatch = require(
	services:WaitForChild("ProfileServiceReliabilityPatch")
)
ProfileServiceReliabilityPatch.Apply()
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
local requestsInFlight: { [number]: boolean } = {}
local REQUEST_WINDOW_SECONDS = 1
local MAX_REQUESTS_PER_WINDOW = 12
local MAX_ACTION_NAME_LENGTH = 64
local MAX_PAYLOAD_DEPTH = 4
local MAX_PAYLOAD_ENTRIES = 96
local MAX_STRING_LENGTH = 512

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

local profileStoreResolution = ProfileStoreConfiguration.Resolve()
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

local profileStoreLabel = profileStoreResolution.mode
if profileStoreResolution.dataStoreName then
	profileStoreLabel ..= " (" .. profileStoreResolution.dataStoreName .. ")"
end
if profileStoreResolution.mode == "TestDataStore" then
	warn(
		string.format(
			"[CAMP-Mystery] TEST profile store active: %s; injected load failures=%d, update failures=%d",
			profileStoreLabel,
			profileStoreResolution.testLoadFailures,
			profileStoreResolution.testUpdateFailures
		)
	)
else
	print("[CAMP-Mystery] Profile store mode: " .. profileStoreLabel)
end

local function finiteNumber(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

local function validPayload(payload: unknown): boolean
	local entries = 0
	local seen: { [any]: boolean } = {}

	local function visit(value: unknown, depth: number): boolean
		local kind = typeof(value)
		if kind == "nil" or kind == "boolean" then
			return true
		elseif kind == "number" then
			return finiteNumber(value :: number)
		elseif kind == "string" then
			return #(value :: string) <= MAX_STRING_LENGTH
		elseif kind == "Vector3" then
			local vector = value :: Vector3
			return finiteNumber(vector.X)
				and finiteNumber(vector.Y)
				and finiteNumber(vector.Z)
		elseif kind ~= "table" or depth >= MAX_PAYLOAD_DEPTH then
			return false
		end

		local current = value :: { [any]: any }
		if seen[current] then
			return false
		end
		seen[current] = true
		for key, child in current do
			entries += 1
			if entries > MAX_PAYLOAD_ENTRIES then
				seen[current] = nil
				return false
			end
			if
				(typeof(key) ~= "string" and typeof(key) ~= "number")
				or (typeof(key) == "string" and #(key :: string) > MAX_ACTION_NAME_LENGTH)
				or not visit(child, depth + 1)
			then
				seen[current] = nil
				return false
			end
		end
		seen[current] = nil
		return true
	end

	return visit(payload, 0)
end

local function rejected(reason: string)
	return {
		accepted = false,
		reason = reason,
	}
end

local function handleActionSafely(
	player: Player,
	actionName: string,
	payload: unknown
)
	if requestsInFlight[player.UserId] then
		return rejected("Another request is still being processed")
	end
	if not validPayload(payload) then
		return rejected("Action payload is invalid or too large")
	end

	requestsInFlight[player.UserId] = true
	local success, result = pcall(function()
		return runtime:HandleAction(player, actionName, payload)
	end)
	requestsInFlight[player.UserId] = nil
	if not success then
		warn(
			string.format(
				"[CAMP-Mystery] Action %s failed for user %d: %s",
				actionName,
				player.UserId,
				tostring(result)
			)
		)
		return rejected("The server could not process that action")
	end
	return result
end

getGameState.OnServerInvoke = function(player: Player)
	if not requestAllowed(player) then
		return nil
	end
	local success, result = pcall(function()
		return runtime:GetGameState(player)
	end)
	if not success then
		warn("[CAMP-Mystery] GetGameState failed:", result)
		return nil
	end
	return result
end

requestAction.OnServerInvoke = function(player: Player, actionName: unknown, payload: unknown)
	if
		typeof(actionName) ~= "string"
		or actionName == ""
		or #actionName > MAX_ACTION_NAME_LENGTH
	then
		return rejected("Action name is invalid")
	end
	if not requestAllowed(player) then
		return rejected("Too many requests; wait a moment")
	end
	return handleActionSafely(player, actionName, payload)
end

-- Keep the validated gray-box getter and vote contract available to older clients.
getRoundState.OnServerInvoke = function(player: Player)
	if not requestAllowed(player) then
		return nil
	end
	local success, result = pcall(function()
		return runtime:GetRoundSnapshot()
	end)
	if not success then
		warn("[CAMP-Mystery] GetRoundState failed:", result)
		return nil
	end
	return result
end

submitVote.OnServerEvent:Connect(function(player: Player, suspectKey: unknown)
	if
		typeof(suspectKey) == "string"
		and suspectKey ~= ""
		and #suspectKey <= MAX_STRING_LENGTH
		and requestAllowed(player)
	then
		handleActionSafely(player, "Vote", {
			targetKey = suspectKey,
			targetParticipantId = suspectKey,
		})
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	requestWindows[player.UserId] = nil
	requestsInFlight[player.UserId] = nil
end)

runtime:Start()

game:BindToClose(function()
	runtime:Stop()
end)

print("[CAMP-Mystery] Production server started")
