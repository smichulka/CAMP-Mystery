--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local configFolder = Shared:WaitForChild("Config")
local typesFolder = Shared:WaitForChild("Types")
local MatchConfig = require(configFolder:WaitForChild("MatchConfig"))
local Types = require(typesFolder:WaitForChild("MatchTypes"))

type Clock = () -> number
type LobbyService = {
	AddPlayer: (self: any, player: Player) -> boolean,
	RemovePlayer: (self: any, player: Player) -> Types.DisconnectContext?,
	SetReady: (self: any, player: Player, ready: boolean) -> (boolean, string?),
	GetReadyCount: (self: any) -> number,
	GetReadyHumans: (self: any) -> { Types.RosterParticipant },
	SetFillWindow: (self: any, startedAt: number?, endsAt: number?) -> (),
	LockRoster: (
		self: any,
		roundId: string,
		humans: { Types.RosterParticipant }
	) -> (),
	MarkRoundStarted: (self: any, roundId: string) -> boolean,
	ReleaseRound: (self: any, roundId: string) -> boolean,
	GetSnapshot: (self: any) -> Types.LobbySnapshot,
}
type BotRosterSystem = {
	FillEmptySlots: (
		self: any,
		humans: { Types.RosterParticipant },
		emptySlotCount: number,
		roundId: string
	) -> { Types.RosterParticipant },
	FillReplacement: (
		self: any,
		roundId: string,
		departedParticipantId: string
	) -> (Types.RosterParticipant?, string?),
	RestoreHuman: (
		self: any,
		roundId: string,
		replacementParticipantId: string,
		humanParticipantId: string
	) -> boolean,
	ReleaseRound: (self: any, roundId: string?) -> boolean,
}
type DisconnectHook = (context: Types.DisconnectContext) -> ()
type RosterHook = (roster: Types.LockedRoster) -> ()
type ReplacementHook = (
	context: Types.DisconnectContext,
	replacement: Types.RosterParticipant,
	roster: Types.LockedRoster
) -> ()
type HumanRejoinHook = (
	player: Player,
	context: Types.DisconnectContext,
	replacement: Types.RosterParticipant,
	human: Types.RosterParticipant,
	roster: Types.LockedRoster
) -> ()
type ReplacementRecord = {
	context: Types.DisconnectContext,
	replacement: Types.RosterParticipant,
}

export type MatchmakingOptions = {
	clock: Clock?,
	roundIdPrefix: string?,
	onLobbyDisconnect: DisconnectHook?,
	onLockedDisconnect: DisconnectHook?,
	onRosterLocked: RosterHook?,
	onRosterChanged: RosterHook?,
	onBotReplacement: ReplacementHook?,
	onHumanRejoin: HumanRejoinHook?,
}

type MatchmakingServiceState = {
	lobbyService: LobbyService,
	botRosterSystem: BotRosterSystem,
	clock: Clock,
	roundIdPrefix: string,
	onLobbyDisconnect: DisconnectHook?,
	onLockedDisconnect: DisconnectHook?,
	onRosterLocked: RosterHook?,
	onRosterChanged: RosterHook?,
	onBotReplacement: ReplacementHook?,
	onHumanRejoin: HumanRejoinHook?,
	disconnectedReplacementsByUserId: { [number]: ReplacementRecord },
	roundRevision: number,
	fillStartedAt: number?,
	activeRoster: Types.LockedRoster?,
	running: boolean,
	connections: { RBXScriptConnection },
}

local MatchmakingService = {}
MatchmakingService.__index = MatchmakingService

export type MatchmakingService = typeof(
	setmetatable({} :: MatchmakingServiceState, MatchmakingService)
)

local function defaultClock(): number
	return workspace:GetServerTimeNow()
end

local function makeRoundId(prefix: string, revision: number): string
	return string.format("%s:r%06d", prefix, revision)
end

local function cloneRosterParticipant(
	participant: Types.RosterParticipant
): Types.RosterParticipant
	return {
		participantId = participant.participantId,
		displayName = participant.displayName,
		controllerKind = participant.controllerKind,
		userId = participant.userId,
		botId = participant.botId,
	}
end

local function validateParticipants(
	humans: { Types.RosterParticipant },
	bots: { Types.RosterParticipant },
	targetSize: number
): (boolean, string?)
	if #humans + #bots ~= targetSize then
		return false, "BotRosterSystem returned the wrong participant count"
	end

	local seen: { [string]: boolean } = {}
	for _, participant in humans do
		if participant.controllerKind ~= "Human" or participant.userId == nil then
			return false, "Invalid human roster participant"
		end
		if seen[participant.participantId] then
			return false, "Duplicate participant id"
		end
		seen[participant.participantId] = true
	end
	for _, participant in bots do
		if participant.controllerKind ~= "Bot" or participant.botId == nil then
			return false, "Invalid bot roster participant"
		end
		if seen[participant.participantId] then
			return false, "Duplicate participant id"
		end
		seen[participant.participantId] = true
	end
	return true, nil
end

function MatchmakingService.new(
	lobbyService: LobbyService,
	botRosterSystem: BotRosterSystem,
	options: MatchmakingOptions?
): MatchmakingService
	local configured = options or {}
	local prefix = configured.roundIdPrefix
	if not prefix or prefix == "" then
		prefix = if game.JobId ~= "" then game.JobId else "studio"
	end

	return setmetatable({
		lobbyService = lobbyService,
		botRosterSystem = botRosterSystem,
		clock = configured.clock or defaultClock,
		roundIdPrefix = prefix,
		onLobbyDisconnect = configured.onLobbyDisconnect,
		onLockedDisconnect = configured.onLockedDisconnect,
		onRosterLocked = configured.onRosterLocked,
		onRosterChanged = configured.onRosterChanged,
		onBotReplacement = configured.onBotReplacement,
		onHumanRejoin = configured.onHumanRejoin,
		disconnectedReplacementsByUserId = {},
		roundRevision = 0,
		fillStartedAt = nil,
		activeRoster = nil,
		running = false,
		connections = {},
	}, MatchmakingService)
end

function MatchmakingService:GetLobbySnapshot(): Types.LobbySnapshot
	return self.lobbyService:GetSnapshot()
end

function MatchmakingService:GetActiveRoster(): Types.LockedRoster?
	local roster = self.activeRoster
	if not roster then
		return nil
	end
	local participants: { Types.RosterParticipant } = {}
	for _, participant in roster.participants do
		table.insert(participants, cloneRosterParticipant(participant))
	end
	return {
		roundId = roster.roundId,
		revision = roster.revision,
		mode = roster.mode,
		targetSize = roster.targetSize,
		createdAt = roster.createdAt,
		participants = participants,
	}
end

function MatchmakingService:SetReady(
	player: Player,
	ready: boolean
): (boolean, string?)
	local success, reason = self.lobbyService:SetReady(player, ready)
	if success then
		self:Tick()
	end
	return success, reason
end

function MatchmakingService:AddPlayer(player: Player)
	local restoredLockedPlayer = self.lobbyService:AddPlayer(player)
	if restoredLockedPlayer then
		self:_RestoreLockedParticipant(player)
		return
	end
	self:Tick()
end

function MatchmakingService:_RestoreLockedParticipant(player: Player): boolean
	local record = self.disconnectedReplacementsByUserId[player.UserId]
	local roster = self.activeRoster
	if not record or not roster or record.context.roundId ~= roster.roundId then
		return false
	end
	local replacementIndex: number? = nil
	for index, participant in roster.participants do
		if participant.participantId == record.replacement.participantId then
			replacementIndex = index
			break
		end
	end
	if not replacementIndex
		or not self.botRosterSystem:RestoreHuman(
			roster.roundId,
			record.replacement.participantId,
			record.context.participantId
		)
	then
		return false
	end
	local human: Types.RosterParticipant = {
		participantId = record.context.participantId,
		displayName = player.DisplayName,
		controllerKind = "Human",
		userId = player.UserId,
		botId = nil,
	}
	roster.participants[replacementIndex] = human
	roster.revision += 1
	self.disconnectedReplacementsByUserId[player.UserId] = nil
	local snapshot = self:GetActiveRoster()
	assert(snapshot, "Active roster disappeared during rejoin")
	local rejoinHook = self.onHumanRejoin
	if rejoinHook then
		rejoinHook(player, record.context, record.replacement, human, snapshot)
	end
	local changedHook = self.onRosterChanged
	if changedHook then
		changedHook(snapshot)
	end
	return true
end

function MatchmakingService:RemovePlayer(player: Player)
	local context = self.lobbyService:RemovePlayer(player)
	if not context then
		return
	end

	if context.wasLocked then
		self:_ReplaceLockedParticipant(context)
		local hook = self.onLockedDisconnect
		if hook then
			hook(context)
		end
	else
		local hook = self.onLobbyDisconnect
		if hook then
			hook(context)
		end
	end
	self:Tick()
end

function MatchmakingService:_ReplaceLockedParticipant(
	context: Types.DisconnectContext
): Types.RosterParticipant?
	local roster = self.activeRoster
	local roundId = context.roundId
	if not roster or not roundId or roster.roundId ~= roundId then
		return nil
	end

	local rosterIndex: number? = nil
	for index, participant in roster.participants do
		if participant.participantId == context.participantId then
			rosterIndex = index
			break
		end
	end
	if not rosterIndex then
		return nil
	end

	local replacement, reason = self.botRosterSystem:FillReplacement(
		roundId,
		context.participantId
	)
	if not replacement then
		warn(
			string.format(
				"[MatchmakingService] Could not replace %s: %s",
				context.participantId,
				reason or "UnknownFailure"
			)
		)
		return nil
	end

	roster.participants[rosterIndex] = replacement
	roster.revision += 1
	local snapshot = self:GetActiveRoster()
	assert(snapshot, "Active roster disappeared during replacement")
	local replacementHook = self.onBotReplacement
	if replacementHook then
		replacementHook(context, replacement, snapshot)
	end
	self.disconnectedReplacementsByUserId[context.userId] = {
		context = context,
		replacement = cloneRosterParticipant(replacement),
	}
	local changedHook = self.onRosterChanged
	if changedHook then
		changedHook(snapshot)
	end
	return replacement
end

function MatchmakingService:_TryLockRoster(): (Types.LockedRoster?, string?)
	if self.activeRoster then
		return nil, "RosterAlreadyLocked"
	end

	local humans = self.lobbyService:GetReadyHumans()
	if #humans < MatchConfig.minimumHumans then
		return nil, "NotEnoughReadyHumans"
	end
	if #humans > MatchConfig.maximumParticipants then
		return nil, "TooManyReadyHumans"
	end

	local mode = MatchConfig.modeForHumanCount(#humans)
	assert(mode, "A non-empty human roster must have a match mode")
	local targetSize = MatchConfig.targetForHumanCount(#humans)
	local nextRevision = self.roundRevision + 1
	local roundId = makeRoundId(self.roundIdPrefix, nextRevision)
	local emptySlotCount = targetSize - #humans
	local botSuccess, botResult = pcall(function()
		return self.botRosterSystem:FillEmptySlots(
			table.clone(humans),
			emptySlotCount,
			roundId
		)
	end)
	if not botSuccess then
		return nil, "BotRosterSystem failed: " .. tostring(botResult)
	end
	local bots = botResult :: { Types.RosterParticipant }
	local valid, validationError = validateParticipants(humans, bots, targetSize)
	if not valid then
		return nil, validationError
	end

	local participants = table.clone(humans)
	for _, bot in bots do
		table.insert(participants, bot)
	end

	local roster: Types.LockedRoster = {
		roundId = roundId,
		revision = nextRevision,
		mode = mode,
		targetSize = targetSize,
		createdAt = self.clock(),
		participants = participants,
	}
	self.roundRevision = nextRevision
	self.activeRoster = roster
	self.fillStartedAt = nil
	self.lobbyService:LockRoster(roundId, humans)
	local snapshot = self:GetActiveRoster()
	assert(snapshot, "Locked roster disappeared")
	local lockedHook = self.onRosterLocked
	if lockedHook then
		lockedHook(snapshot)
	end
	return snapshot, nil
end

function MatchmakingService:ForceLock(): (Types.LockedRoster?, string?)
	return self:_TryLockRoster()
end

function MatchmakingService:Tick(): (Types.LockedRoster?, string?)
	if self.activeRoster then
		return nil, nil
	end

	local readyCount = self.lobbyService:GetReadyCount()
	if readyCount < MatchConfig.minimumHumans then
		if self.fillStartedAt then
			self.fillStartedAt = nil
			self.lobbyService:SetFillWindow(nil, nil)
		end
		return nil, nil
	end

	local now = self.clock()
	if not self.fillStartedAt then
		self.fillStartedAt = now
		self.lobbyService:SetFillWindow(
			now,
			now + MatchConfig.fillCountdownSeconds
		)
	end

	local countdownExpired = now
		>= (self.fillStartedAt :: number) + MatchConfig.fillCountdownSeconds
	local targetSize = MatchConfig.targetForHumanCount(readyCount)
	if readyCount >= targetSize
		or countdownExpired
	then
		return self:_TryLockRoster()
	end
	return nil, nil
end

function MatchmakingService:MarkRoundStarted(roundId: string): boolean
	local roster = self.activeRoster
	if not roster or roster.roundId ~= roundId then
		return false
	end
	return self.lobbyService:MarkRoundStarted(roundId)
end

function MatchmakingService:FinishRound(roundId: string): boolean
	local roster = self.activeRoster
	if not roster or roster.roundId ~= roundId then
		return false
	end
	if not self.lobbyService:ReleaseRound(roundId) then
		return false
	end
	self.botRosterSystem:ReleaseRound(roundId)
	for userId, record in self.disconnectedReplacementsByUserId do
		if record.context.roundId == roundId then
			self.disconnectedReplacementsByUserId[userId] = nil
		end
	end
	self.activeRoster = nil
	self.fillStartedAt = nil
	return true
end

function MatchmakingService:Start()
	if self.running then
		return
	end
	self.running = true

	table.insert(self.connections, Players.PlayerAdded:Connect(function(player: Player)
		self:AddPlayer(player)
	end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player: Player)
		self:RemovePlayer(player)
	end))
	for _, player in Players:GetPlayers() do
		self:AddPlayer(player)
	end

	task.spawn(function()
		while self.running do
			self:Tick()
			task.wait(MatchConfig.tickSeconds)
		end
	end)
end

function MatchmakingService:Stop()
	self.running = false
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
end

return MatchmakingService
