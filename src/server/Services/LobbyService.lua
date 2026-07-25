--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local configFolder = Shared:WaitForChild("Config")
local typesFolder = Shared:WaitForChild("Types")
local MatchConfig = require(configFolder:WaitForChild("MatchConfig"))
local Types = require(typesFolder:WaitForChild("MatchTypes"))

type Clock = () -> number
type LobbyStatus = Types.LobbyStatus
type LobbySnapshot = Types.LobbySnapshot
type LobbyPlayerSnapshot = Types.LobbyPlayerSnapshot
type RosterParticipant = Types.RosterParticipant
type DisconnectContext = Types.DisconnectContext

type LobbyPlayerState = {
	player: Player,
	participantId: string,
	displayName: string,
	ready: boolean,
	queuedForNextRound: boolean,
	lockedRoundId: string?,
	joinedAt: number,
}

type LobbyServiceState = {
	clock: Clock,
	revision: number,
	status: LobbyStatus,
	players: { [number]: LobbyPlayerState },
	fillStartedAt: number?,
	fillEndsAt: number?,
	activeRoundId: string?,
}

local LobbyService = {}
LobbyService.__index = LobbyService

export type LobbyService = typeof(setmetatable({} :: LobbyServiceState, LobbyService))

local function defaultClock(): number
	return workspace:GetServerTimeNow()
end

local function participantIdForUserId(userId: number): string
	return "player:" .. tostring(userId)
end

function LobbyService.new(clock: Clock?): LobbyService
	return setmetatable({
		clock = clock or defaultClock,
		revision = 0,
		status = "Waiting",
		players = {},
		fillStartedAt = nil,
		fillEndsAt = nil,
		activeRoundId = nil,
	}, LobbyService)
end

function LobbyService:_Changed()
	self.revision += 1
end

function LobbyService:AddPlayer(player: Player)
	if self.players[player.UserId] then
		return
	end

	local queueForNextRound = self.activeRoundId ~= nil
		or self:GetCurrentQueueCount() >= MatchConfig.maximumParticipants
	self.players[player.UserId] = {
		player = player,
		participantId = participantIdForUserId(player.UserId),
		displayName = player.DisplayName,
		ready = false,
		queuedForNextRound = queueForNextRound,
		lockedRoundId = nil,
		joinedAt = self.clock(),
	}
	self:_Changed()
end

function LobbyService:RemovePlayer(player: Player): DisconnectContext?
	local state = self.players[player.UserId]
	if not state then
		return nil
	end

	local context: DisconnectContext = {
		userId = player.UserId,
		participantId = state.participantId,
		wasLocked = state.lockedRoundId ~= nil,
		roundId = state.lockedRoundId,
		wasQueuedForNextRound = state.queuedForNextRound,
	}
	self.players[player.UserId] = nil
	self:_Changed()
	return context
end

function LobbyService:SetReady(player: Player, ready: boolean): (boolean, string?)
	local state = self.players[player.UserId]
	if not state then
		return false, "PlayerNotInLobby"
	end
	if state.queuedForNextRound then
		return false, "QueuedForNextRound"
	end
	if state.lockedRoundId then
		return false, "RosterLocked"
	end
	if state.ready == ready then
		return true, nil
	end

	state.ready = ready
	self:_Changed()
	return true, nil
end

function LobbyService:GetCurrentQueueCount(): number
	local count = 0
	for _, state in self.players do
		if not state.queuedForNextRound and not state.lockedRoundId then
			count += 1
		end
	end
	return count
end

function LobbyService:GetReadyCount(): number
	local count = 0
	for _, state in self.players do
		if state.ready and not state.queuedForNextRound and not state.lockedRoundId then
			count += 1
		end
	end
	return count
end

function LobbyService:GetReadyHumans(): { RosterParticipant }
	local readyStates: { LobbyPlayerState } = {}
	for _, state in self.players do
		if state.ready and not state.queuedForNextRound and not state.lockedRoundId then
			table.insert(readyStates, state)
		end
	end
	table.sort(readyStates, function(left: LobbyPlayerState, right: LobbyPlayerState)
		if left.joinedAt == right.joinedAt then
			return left.player.UserId < right.player.UserId
		end
		return left.joinedAt < right.joinedAt
	end)

	local participants: { RosterParticipant } = {}
	for index = 1, math.min(#readyStates, MatchConfig.maximumParticipants) do
		local state = readyStates[index]
		table.insert(participants, {
			participantId = state.participantId,
			displayName = state.displayName,
			controllerKind = "Human",
			userId = state.player.UserId,
			botId = nil,
		})
	end
	return participants
end

function LobbyService:SetFillWindow(startedAt: number?, endsAt: number?)
	if self.fillStartedAt == startedAt and self.fillEndsAt == endsAt then
		return
	end
	self.fillStartedAt = startedAt
	self.fillEndsAt = endsAt
	self.status = if startedAt then "Filling" else "Waiting"
	self:_Changed()
end

function LobbyService:LockRoster(roundId: string, humans: { RosterParticipant })
	local selected: { [number]: boolean } = {}
	for _, participant in humans do
		local userId = participant.userId
		if userId then
			selected[userId] = true
		end
	end

	for userId, state in self.players do
		if selected[userId] then
			state.ready = false
			state.lockedRoundId = roundId
			state.queuedForNextRound = false
		elseif not state.queuedForNextRound then
			state.ready = false
			state.queuedForNextRound = true
		end
	end

	self.activeRoundId = roundId
	self.fillStartedAt = nil
	self.fillEndsAt = nil
	self.status = "Locked"
	self:_Changed()
end

function LobbyService:MarkRoundStarted(roundId: string): boolean
	if self.activeRoundId ~= roundId then
		return false
	end
	if self.status ~= "InRound" then
		self.status = "InRound"
		self:_Changed()
	end
	return true
end

function LobbyService:ReleaseRound(roundId: string): boolean
	if self.activeRoundId ~= roundId then
		return false
	end

	local returning: { LobbyPlayerState } = {}
	local waiting: { LobbyPlayerState } = {}
	for _, state in self.players do
		if state.lockedRoundId == roundId then
			table.insert(returning, state)
		else
			table.insert(waiting, state)
		end
	end
	table.sort(waiting, function(left: LobbyPlayerState, right: LobbyPlayerState)
		if left.joinedAt == right.joinedAt then
			return left.player.UserId < right.player.UserId
		end
		return left.joinedAt < right.joinedAt
	end)

	local availableSlots = math.max(
		0,
		MatchConfig.maximumParticipants - #returning
	)
	for _, state in returning do
		state.ready = false
		state.queuedForNextRound = false
		state.lockedRoundId = nil
	end
	for index, state in waiting do
		state.ready = false
		state.lockedRoundId = nil
		state.queuedForNextRound = index > availableSlots
	end
	self.activeRoundId = nil
	self.fillStartedAt = nil
	self.fillEndsAt = nil
	self.status = "Waiting"
	self:_Changed()
	return true
end

function LobbyService:GetSnapshot(): LobbySnapshot
	local players: { LobbyPlayerSnapshot } = {}
	local humanCount = 0
	local readyCount = 0
	local nextRoundCount = 0

	for _, state in self.players do
		local playerStatus: Types.LobbyPlayerStatus
		if state.lockedRoundId then
			playerStatus = "Locked"
			humanCount += 1
		elseif state.queuedForNextRound then
			playerStatus = "NextRound"
			nextRoundCount += 1
		elseif state.ready then
			playerStatus = "Ready"
			readyCount += 1
			humanCount += 1
		else
			playerStatus = "Waiting"
			humanCount += 1
		end

		table.insert(players, {
			userId = state.player.UserId,
			participantId = state.participantId,
			displayName = state.displayName,
			status = playerStatus,
			isReady = state.ready,
			joinedAt = state.joinedAt,
		})
	end
	table.sort(players, function(left: LobbyPlayerSnapshot, right: LobbyPlayerSnapshot)
		if left.joinedAt == right.joinedAt then
			return left.userId < right.userId
		end
		return left.joinedAt < right.joinedAt
	end)

	return {
		revision = self.revision,
		status = self.status,
		mode = MatchConfig.modeForHumanCount(readyCount),
		standardTarget = MatchConfig.standardTarget,
		maximumParticipants = MatchConfig.maximumParticipants,
		humanCount = humanCount,
		readyCount = readyCount,
		nextRoundCount = nextRoundCount,
		fillStartedAt = self.fillStartedAt,
		fillEndsAt = self.fillEndsAt,
		serverNow = self.clock(),
		activeRoundId = self.activeRoundId,
		players = players,
	}
end

return LobbyService
