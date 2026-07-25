--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local configFolder = Shared:WaitForChild("Config")
local typesFolder = Shared:WaitForChild("Types")
local RoundConfig = require(configFolder:WaitForChild("RoundConfig"))
local Types = require(typesFolder:WaitForChild("GameTypes"))
local GrayboxMapService = require(script.Parent:WaitForChild("GrayboxMapService"))

type PhaseName = Types.PhaseName
type RoleName = Types.RoleName
type WinnerName = Types.WinnerName
type RoundSnapshot = Types.RoundSnapshot
type PlayerSnapshot = Types.PlayerSnapshot
type Suspect = Types.Suspect
type EvidenceSummary = Types.EvidenceSummary

type ParticipantState = {
	role: RoleName,
	alive: boolean,
	objectivesCompleted: number,
	evidenceCollected: number,
	hasVoted: boolean,
	voteTargetKey: string?,
	statusMessage: string,
}

type RoundServiceState = {
	roundNumber: number,
	currentPhase: PhaseName,
	currentPhaseDisplayName: string,
	phaseStartedAt: number,
	phaseEndsAt: number,
	running: boolean,
	isNight: boolean,
	participantStates: { [number]: ParticipantState },
	completedObjectives: { [string]: number },
	publicEvidence: { EvidenceSummary },
	suspects: { Suspect },
	votes: { [number]: string },
	culpritKey: string?,
	culpritDisplayName: string?,
	victimName: string?,
	winner: WinnerName?,
	resultMessage: string?,
	roundStateChanged: RemoteEvent,
	getRoundState: RemoteFunction,
	playerStateChanged: RemoteEvent,
	getPlayerState: RemoteFunction,
	submitVote: RemoteEvent,
	mapService: GrayboxMapService.GrayboxMapService?,
}

local RoundService = {}
RoundService.__index = RoundService

export type RoundService = typeof(setmetatable({} :: RoundServiceState, RoundService))

local ROLE_COPY: { [RoleName]: { displayName: string, description: string } } = {
	Camper = {
		displayName = "Camper",
		description = "Finish camp work, find evidence, and expose the murderer.",
	},
	Murderer = {
		displayName = "Murderer",
		description = "Blend in, mislead the vote, and avoid being exposed.",
	},
	Spectator = {
		displayName = "Spectator",
		description = "The current round is already underway. You will join the next one.",
	},
}

local EVIDENCE_COPY: {
	[string]: { displayName: string, template: string },
} = {
	["muddy-bootprint"] = {
		displayName = "Muddy Bootprint",
		template = "The tread matches the boots worn by %s.",
	},
	["torn-fabric"] = {
		displayName = "Torn Fabric",
		template = "The torn fibers match %s's camp gear.",
	},
	["dropped-token"] = {
		displayName = "Dropped Camp Token",
		template = "The scratched initials identify %s.",
	},
}

local function getPlayerKey(player: Player): string
	return "player:" .. tostring(player.UserId)
end

local function getPhaseDuration(phaseName: PhaseName): number
	for _, phaseConfig in RoundConfig.phases do
		if phaseConfig.name == phaseName then
			return phaseConfig.durationSeconds
		end
	end
	error("Missing phase configuration for " .. phaseName)
end

local function getPhaseDisplayName(phaseName: PhaseName): string
	for _, phaseConfig in RoundConfig.phases do
		if phaseConfig.name == phaseName then
			return phaseConfig.displayName
		end
	end
	error("Missing phase configuration for " .. phaseName)
end

local function shuffledPlayers(players: { Player }): { Player }
	local result = table.clone(players)
	for index = #result, 2, -1 do
		local swapIndex = math.random(1, index)
		result[index], result[swapIndex] = result[swapIndex], result[index]
	end
	return result
end

function RoundService.new(): RoundService
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local roundStateChanged = remotes:WaitForChild("RoundStateChanged")
	local getRoundState = remotes:WaitForChild("GetRoundState")
	local playerStateChanged = remotes:WaitForChild("PlayerStateChanged")
	local getPlayerState = remotes:WaitForChild("GetPlayerState")
	local submitVote = remotes:WaitForChild("SubmitVote")

	assert(roundStateChanged:IsA("RemoteEvent"), "RoundStateChanged must be a RemoteEvent")
	assert(getRoundState:IsA("RemoteFunction"), "GetRoundState must be a RemoteFunction")
	assert(playerStateChanged:IsA("RemoteEvent"), "PlayerStateChanged must be a RemoteEvent")
	assert(getPlayerState:IsA("RemoteFunction"), "GetPlayerState must be a RemoteFunction")
	assert(submitVote:IsA("RemoteEvent"), "SubmitVote must be a RemoteEvent")

	local now = workspace:GetServerTimeNow()
	local self: RoundService = setmetatable({
		roundNumber = 0,
		currentPhase = "Lobby",
		currentPhaseDisplayName = "Waiting at Camp",
		phaseStartedAt = now,
		phaseEndsAt = now,
		running = false,
		isNight = false,
		participantStates = {},
		completedObjectives = {},
		publicEvidence = {},
		suspects = {},
		votes = {},
		culpritKey = nil,
		culpritDisplayName = nil,
		victimName = nil,
		winner = nil,
		resultMessage = nil,
		roundStateChanged = roundStateChanged,
		getRoundState = getRoundState,
		playerStateChanged = playerStateChanged,
		getPlayerState = getPlayerState,
		submitVote = submitVote,
		mapService = nil,
	}, RoundService)

	self.mapService = GrayboxMapService.new(
		function(player: Player, objectiveId: string)
			self:HandleObjective(player, objectiveId)
		end,
		function(player: Player, evidenceId: string)
			return self:HandleEvidence(player, evidenceId)
		end
	)

	self.getRoundState.OnServerInvoke = function(_player: Player): RoundSnapshot
		return self:GetSnapshot()
	end

	self.getPlayerState.OnServerInvoke = function(player: Player): PlayerSnapshot
		return self:GetPlayerSnapshot(player)
	end

	self.submitVote.OnServerEvent:Connect(function(player: Player, suspectKey: unknown)
		if typeof(suspectKey) ~= "string" then
			return
		end
		self:HandleVote(player, suspectKey)
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		task.defer(function()
			self.roundStateChanged:FireClient(player, self:GetSnapshot())
			self.playerStateChanged:FireClient(player, self:GetPlayerSnapshot(player))
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self.participantStates[player.UserId] = nil
		self.votes[player.UserId] = nil
		self:Broadcast()
	end)

	return self
end

function RoundService:GetEligibleVoterCount(): number
	local count = 0
	for _, state in self.participantStates do
		if state.alive then
			count += 1
		end
	end
	return count
end

function RoundService:GetSnapshot(): RoundSnapshot
	return {
		roundNumber = self.roundNumber,
		phase = self.currentPhase,
		phaseDisplayName = self.currentPhaseDisplayName,
		phaseStartedAt = self.phaseStartedAt,
		phaseEndsAt = self.phaseEndsAt,
		serverNow = workspace:GetServerTimeNow(),
		objectivesCompleted = self:GetObjectiveCount(),
		objectiveGoal = RoundConfig.objectiveGoal,
		evidenceFound = #self.publicEvidence,
		evidenceGoal = RoundConfig.evidenceGoal,
		evidence = table.clone(self.publicEvidence),
		suspects = table.clone(self.suspects),
		votesCast = self:GetVoteCount(),
		eligibleVoters = self:GetEligibleVoterCount(),
		victimName = self.victimName,
		winner = self.winner,
		resultMessage = self.resultMessage,
		isNight = self.isNight,
	}
end

function RoundService:GetPlayerSnapshot(player: Player): PlayerSnapshot
	local state = self.participantStates[player.UserId]
	if not state then
		local copy = ROLE_COPY.Spectator
		return {
			role = "Spectator",
			roleDisplayName = copy.displayName,
			roleDescription = copy.description,
			alive = false,
			isGhost = false,
			objectivesCompleted = 0,
			evidenceCollected = 0,
			hasVoted = false,
			voteTargetKey = nil,
			statusMessage = "Waiting to join the next round.",
		}
	end

	local copy = ROLE_COPY[state.role]
	return {
		role = state.role,
		roleDisplayName = copy.displayName,
		roleDescription = copy.description,
		alive = state.alive,
		isGhost = not state.alive,
		objectivesCompleted = state.objectivesCompleted,
		evidenceCollected = state.evidenceCollected,
		hasVoted = state.hasVoted,
		voteTargetKey = state.voteTargetKey,
		statusMessage = state.statusMessage,
	}
end

function RoundService:Broadcast()
	local snapshot = self:GetSnapshot()
	self.roundStateChanged:FireAllClients(snapshot)
	for _, player in Players:GetPlayers() do
		self.playerStateChanged:FireClient(player, self:GetPlayerSnapshot(player))
	end
end

function RoundService:SetPhase(phase: PhaseName)
	local now = workspace:GetServerTimeNow()
	local durationSeconds = getPhaseDuration(phase)

	self.currentPhase = phase
	self.currentPhaseDisplayName = getPhaseDisplayName(phase)
	self.phaseStartedAt = now
	self.phaseEndsAt = now + durationSeconds
	self:Broadcast()

	print(
		string.format(
			"[RoundService] Round %d entered %s for %d seconds",
			self.roundNumber,
			phase,
			durationSeconds
		)
	)
end

function RoundService:WaitForPhase(predicate: (() -> boolean)?)
	while self.running and workspace:GetServerTimeNow() < self.phaseEndsAt do
		if predicate and predicate() then
			task.wait(1)
			return
		end
		task.wait(0.25)
	end
end

function RoundService:GetObjectiveCount(): number
	local count = 0
	for _ in self.completedObjectives do
		count += 1
	end
	return count
end

function RoundService:GetVoteCount(): number
	local count = 0
	for _ in self.votes do
		count += 1
	end
	return count
end

function RoundService:ResetRoundState()
	self.participantStates = {}
	self.completedObjectives = {}
	self.publicEvidence = {}
	self.suspects = {}
	self.votes = {}
	self.culpritKey = nil
	self.culpritDisplayName = nil
	self.victimName = nil
	self.winner = nil
	self.resultMessage = nil
	self.isNight = false

	local mapService = self.mapService
	if mapService then
		mapService:ResetRound()
	end
	self:Broadcast()
end

function RoundService:AssignRoles()
	local players = shuffledPlayers(Players:GetPlayers())
	if #players == 0 then
		return
	end

	local murderer: Player? = nil
	if #players >= 2 then
		murderer = players[1]
		self.culpritKey = getPlayerKey(murderer)
		self.culpritDisplayName = murderer.DisplayName
	else
		self.culpritKey = RoundConfig.computerCulpritKey
		self.culpritDisplayName = RoundConfig.computerCulpritName
	end

	for _, player in players do
		local role: RoleName = if player == murderer then "Murderer" else "Camper"
		self.participantStates[player.UserId] = {
			role = role,
			alive = true,
			objectivesCompleted = 0,
			evidenceCollected = 0,
			hasVoted = false,
			voteTargetKey = nil,
			statusMessage = if role == "Murderer"
				then "Act helpful. Do not let the campers identify you."
				else "Complete the three camp jobs before nightfall.",
		}
	end

	self:BuildSuspectList()
	self:Broadcast()
end

function RoundService:BuildSuspectList()
	local suspects: { Suspect } = {}
	for _, player in Players:GetPlayers() do
		local state = self.participantStates[player.UserId]
		if state and state.alive then
			table.insert(suspects, {
				key = getPlayerKey(player),
				displayName = player.DisplayName,
			})
		end
	end

	if self.culpritKey == RoundConfig.computerCulpritKey then
		table.insert(suspects, {
			key = RoundConfig.computerCulpritKey,
			displayName = RoundConfig.computerCulpritName,
		})
	end

	table.sort(suspects, function(left: Suspect, right: Suspect)
		return left.displayName < right.displayName
	end)
	self.suspects = suspects
end

function RoundService:HandleObjective(player: Player, objectiveId: string)
	if self.currentPhase ~= "Day" then
		return
	end

	local state = self.participantStates[player.UserId]
	if not state or not state.alive or self.completedObjectives[objectiveId] then
		return
	end

	self.completedObjectives[objectiveId] = player.UserId
	state.objectivesCompleted += 1
	state.statusMessage = "Camp job completed. Keep moving."

	local mapService = self.mapService
	if mapService then
		mapService:MarkObjectiveComplete(objectiveId)
	end
	self:Broadcast()
end

function RoundService:SelectVictim()
	local candidates: { Player } = {}
	for _, player in Players:GetPlayers() do
		local state = self.participantStates[player.UserId]
		if state and state.role ~= "Murderer" and state.alive then
			table.insert(candidates, player)
		end
	end

	if #candidates >= 2 then
		local victim = candidates[math.random(1, #candidates)]
		local victimState = self.participantStates[victim.UserId]
		if victimState then
			victimState.alive = false
			victimState.statusMessage =
				"You were taken during the transformation. Observe as a ghost."
		end
		self.victimName = victim.DisplayName
	else
		self.victimName = RoundConfig.computerVictimName
	end

	local victimName = self.victimName or RoundConfig.computerVictimName
	for _, state in self.participantStates do
		if state.alive then
			state.statusMessage =
				string.format("%s is missing. Search the town for evidence.", victimName)
		end
	end

	self:BuildSuspectList()
	self:Broadcast()
end

function RoundService:HandleEvidence(player: Player, evidenceId: string): boolean
	if self.currentPhase ~= "Investigation" then
		return false
	end

	local state = self.participantStates[player.UserId]
	local copy = EVIDENCE_COPY[evidenceId]
	if not state or not state.alive or not copy then
		return false
	end

	local culpritDisplayName = self.culpritDisplayName or "an unknown suspect"
	table.insert(self.publicEvidence, {
		id = evidenceId,
		displayName = copy.displayName,
		description = string.format(copy.template, culpritDisplayName),
		foundBy = player.DisplayName,
	})
	state.evidenceCollected += 1
	state.statusMessage = copy.displayName .. " added to the shared evidence board."
	self:Broadcast()
	return true
end

function RoundService:HandleVote(player: Player, suspectKey: string)
	if self.currentPhase ~= "Campfire" then
		return
	end

	local state = self.participantStates[player.UserId]
	if not state or not state.alive or state.hasVoted then
		return
	end

	local validSuspect = false
	for _, suspect in self.suspects do
		if suspect.key == suspectKey then
			validSuspect = true
			break
		end
	end
	if not validSuspect then
		return
	end

	state.hasVoted = true
	state.voteTargetKey = suspectKey
	state.statusMessage = "Vote locked. Watch the fire and wait for the others."
	self.votes[player.UserId] = suspectKey
	self:Broadcast()
end

function RoundService:ResolveVote()
	local totals: { [string]: number } = {}
	for _, suspectKey in self.votes do
		totals[suspectKey] = (totals[suspectKey] or 0) + 1
	end

	local topKey: string? = nil
	local topVotes = 0
	local tied = false
	for suspectKey, count in totals do
		if count > topVotes then
			topKey = suspectKey
			topVotes = count
			tied = false
		elseif count == topVotes then
			tied = true
		end
	end

	if topKey and not tied and topKey == self.culpritKey then
		self.winner = "Campers"
		self.resultMessage = string.format(
			"The evidence held up. %s was exposed. The campers win!",
			self.culpritDisplayName or "The murderer"
		)
	else
		self.winner = "Murderer"
		if tied then
			self.resultMessage = string.format(
				"The vote tied. %s escaped into the fog.",
				self.culpritDisplayName or "The murderer"
			)
		elseif not topKey then
			self.resultMessage = string.format(
				"No verdict was reached. %s escaped into the fog.",
				self.culpritDisplayName or "The murderer"
			)
		else
			self.resultMessage = string.format(
				"The camp accused the wrong suspect. %s wins.",
				self.culpritDisplayName or "The murderer"
			)
		end
	end

	for _, state in self.participantStates do
		state.statusMessage = self.resultMessage or "The round has ended."
	end
	self:Broadcast()
end

function RoundService:RunRound()
	while self.running and #Players:GetPlayers() < RoundConfig.minimumPlayers do
		self:SetPhase("Lobby")
		self:WaitForPhase()
	end
	if not self.running then
		return
	end

	self.roundNumber += 1
	self:ResetRoundState()
	self:SetPhase("Lobby")
	self:WaitForPhase()
	if #Players:GetPlayers() == 0 then
		return
	end

	self:AssignRoles()
	self:SetPhase("RoleReveal")
	self:WaitForPhase()

	local mapService = self.mapService
	if mapService then
		mapService:SetObjectivePromptsEnabled(true)
	end
	self:SetPhase("Day")
	self:WaitForPhase(function(): boolean
		return self:GetObjectiveCount() >= RoundConfig.objectiveGoal
	end)
	if mapService then
		mapService:SetObjectivePromptsEnabled(false)
	end

	for _, state in self.participantStates do
		state.statusMessage = if state.role == "Murderer"
			then "The camp is distracted. Your plan is in motion."
			else "Stay alert. Something is wrong."
	end
	self:SetPhase("MurderPlanning")
	self:WaitForPhase()

	self:SelectVictim()
	self.isNight = true
	if mapService then
		mapService:SetNight(true)
	end
	self:SetPhase("NightTransform")
	self:WaitForPhase()

	if mapService then
		mapService:SpawnEvidence()
	end
	self:SetPhase("Investigation")
	self:WaitForPhase(function(): boolean
		return #self.publicEvidence >= RoundConfig.evidenceGoal
	end)
	if mapService then
		mapService:ClearEvidence()
	end

	for _, state in self.participantStates do
		if state.alive then
			state.statusMessage = "Review the evidence and cast one vote."
		end
	end
	self:SetPhase("Campfire")
	self:WaitForPhase(function(): boolean
		local eligible = self:GetEligibleVoterCount()
		return eligible > 0 and self:GetVoteCount() >= eligible
	end)

	self:ResolveVote()
	self:SetPhase("Resolution")
	self:WaitForPhase()

	self:SetPhase("Rewards")
	self:WaitForPhase()
end

function RoundService:Start()
	if self.running then
		return
	end

	self.running = true
	task.spawn(function()
		while self.running do
			self:RunRound()
		end
	end)
end

function RoundService:Stop()
	self.running = false
end

return RoundService
