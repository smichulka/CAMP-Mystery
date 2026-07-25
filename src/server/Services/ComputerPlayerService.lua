--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local typesFolder = Shared:WaitForChild("Types")
local BotTypes = require(typesFolder:WaitForChild("BotTypes"))
local ParticipantTypes = require(typesFolder:WaitForChild("ParticipantTypes"))

local serverRoot = script.Parent.Parent
local configFolder = serverRoot:WaitForChild("Config")
local BotProfiles = require(configFolder:WaitForChild("BotProfiles"))
local ParticipantServiceModule = require(script.Parent:WaitForChild("ParticipantService"))

type PhaseName = BotTypes.PhaseName
type BotProfile = BotTypes.BotProfile
type BotMemory = BotTypes.BotMemory
type Relationship = BotTypes.Relationship
type ActionType = BotTypes.ActionType
type ActionCandidate = BotTypes.ActionCandidate
type ScoredAction = BotTypes.ScoredAction
type ActionContext = BotTypes.ActionContext
type ActionCallbacks = BotTypes.ActionCallbacks
type BotRuntimeState = BotTypes.BotRuntimeState
type BotRandomSource = BotTypes.BotRandomSource
type BotClock = BotTypes.BotClock
type ParticipantState = ParticipantTypes.ParticipantState
type ParticipantService = ParticipantServiceModule.ParticipantService

type ComputerPlayerServiceState = {
	participantService: ParticipantService,
	callbacks: ActionCallbacks,
	randomSource: BotRandomSource,
	clock: BotClock,
	runtimesByParticipantId: { [string]: BotRuntimeState },
	runtimeOrder: { string },
	schedulerIndex: number,
	maxDecisionsPerSecond: number,
	running: boolean,
	schedulerGeneration: number,
}

local ComputerPlayerService = {}
ComputerPlayerService.__index = ComputerPlayerService

export type ComputerPlayerService = typeof(
	setmetatable({} :: ComputerPlayerServiceState, ComputerPlayerService)
)

local SystemClock = {}
function SystemClock:Now(): number
	return workspace:GetServerTimeNow()
end

local ALLOWED_PHASES: { [ActionType]: { [PhaseName]: boolean } } = {
	CompleteObjective = {
		Day = true,
	},
	CollectEvidence = {
		Investigation = true,
	},
	UseRoleAbility = {
		Day = true,
		MurderPlanning = true,
		NightTransform = true,
		Investigation = true,
		Campfire = true,
	},
	Attack = {
		MurderPlanning = true,
		NightTransform = true,
		Investigation = true,
	},
	Discuss = {
		Day = true,
		Investigation = true,
		Campfire = true,
	},
	Vote = {
		Campfire = true,
	},
	Idle = {
		Lobby = true,
		RoleReveal = true,
		Day = true,
		MurderPlanning = true,
		NightTransform = true,
		Investigation = true,
		Campfire = true,
		Resolution = true,
		Rewards = true,
	},
}

local function clampUnit(value: number): number
	return math.clamp(value, 0, 1)
end

local function clonePersonality(personality: BotTypes.Personality): BotTypes.Personality
	return {
		bravery = personality.bravery,
		curiosity = personality.curiosity,
		sociability = personality.sociability,
		honesty = personality.honesty,
		aggression = personality.aggression,
		altruism = personality.altruism,
	}
end

local function cloneMemory(memory: BotMemory): BotMemory
	return {
		id = memory.id,
		kind = memory.kind,
		subjectParticipantId = memory.subjectParticipantId,
		relatedParticipantId = memory.relatedParticipantId,
		summary = memory.summary,
		confidence = memory.confidence,
		importance = memory.importance,
		createdAt = memory.createdAt,
		expiresAt = memory.expiresAt,
	}
end

function ComputerPlayerService.new(
	participantService: ParticipantService,
	callbacks: ActionCallbacks,
	randomSource: BotRandomSource?,
	clock: BotClock?,
	maxDecisionsPerSecond: number?
): ComputerPlayerService
	local source: BotRandomSource = randomSource or (Random.new() :: any)
	local resolvedClock: BotClock = clock or (SystemClock :: any)
	local rate = maxDecisionsPerSecond or 4
	assert(rate >= 0.5 and rate <= 10, "Bot scheduler rate must be between 0.5 and 10")
	return setmetatable({
		participantService = participantService,
		callbacks = callbacks,
		randomSource = source,
		clock = resolvedClock,
		runtimesByParticipantId = {},
		runtimeOrder = {},
		schedulerIndex = 0,
		maxDecisionsPerSecond = rate,
		running = false,
		schedulerGeneration = 0,
	}, ComputerPlayerService)
end

function ComputerPlayerService:RegisterBot(participantId: string): BotRuntimeState
	local existing = self.runtimesByParticipantId[participantId]
	if existing then
		existing.active = true
		return existing
	end

	local participant = self.participantService:GetById(participantId)
	assert(participant, "Unknown bot participant: " .. participantId)
	assert(participant.controller.kind == "Bot", "Participant is not controlled by a bot")
	local profile = BotProfiles.Get(participant.controller.profileId)
	assert(profile, "Missing bot profile: " .. participant.controller.profileId)

	local runtime: BotRuntimeState = {
		participantId = participantId,
		profileId = profile.id,
		difficulty = BotProfiles.ResolveDifficulty(participant.controller.difficulty),
		personality = clonePersonality(profile.personality),
		memories = {},
		relationships = {},
		nextThinkAt = self.clock:Now(),
		lastActionAt = nil,
		lastActionId = nil,
		active = true,
	}
	self.runtimesByParticipantId[participantId] = runtime
	table.insert(self.runtimeOrder, participantId)
	self:RefreshRelationships(participantId)
	return runtime
end

function ComputerPlayerService:RegisterRoster(participantIds: { string })
	for _, participantId in participantIds do
		local participant = self.participantService:GetById(participantId)
		if participant and participant.controller.kind == "Bot" then
			self:RegisterBot(participantId)
		end
	end
end

function ComputerPlayerService:GetRuntime(participantId: string): BotRuntimeState?
	return self.runtimesByParticipantId[participantId]
end

function ComputerPlayerService:RefreshRelationships(participantId: string)
	local runtime = self.runtimesByParticipantId[participantId]
	if not runtime then
		return
	end
	local now = self.clock:Now()
	for _, other in self.participantService:GetAll() do
		if other.participantId ~= participantId and not runtime.relationships[other.participantId] then
			runtime.relationships[other.participantId] = {
				participantId = other.participantId,
				trust = 0.5,
				suspicion = 0,
				lastUpdatedAt = now,
			}
		end
	end
end

function ComputerPlayerService:AdjustRelationship(
	participantId: string,
	otherParticipantId: string,
	trustDelta: number,
	suspicionDelta: number
): boolean
	local runtime = self.runtimesByParticipantId[participantId]
	if not runtime then
		return false
	end
	self:RefreshRelationships(participantId)
	local relationship = runtime.relationships[otherParticipantId]
	if not relationship then
		return false
	end
	relationship.trust = clampUnit(relationship.trust + trustDelta)
	relationship.suspicion = clampUnit(relationship.suspicion + suspicionDelta)
	relationship.lastUpdatedAt = self.clock:Now()
	return true
end

function ComputerPlayerService:Remember(participantId: string, memory: BotMemory): boolean
	local runtime = self.runtimesByParticipantId[participantId]
	if not runtime then
		return false
	end
	assert(memory.id ~= "", "Bot memory ID cannot be empty")
	assert(memory.confidence >= 0 and memory.confidence <= 1, "Memory confidence must be 0-1")
	assert(memory.importance >= 0 and memory.importance <= 1, "Memory importance must be 0-1")

	for index, existing in runtime.memories do
		if existing.id == memory.id then
			runtime.memories[index] = cloneMemory(memory)
			return true
		end
	end
	table.insert(runtime.memories, cloneMemory(memory))

	local tuning = BotProfiles.GetDifficulty(runtime.difficulty)
	while #runtime.memories > tuning.memoryLimit do
		local removeIndex = 1
		local weakestValue = math.huge
		for index, candidate in runtime.memories do
			local age = math.max(0, self.clock:Now() - candidate.createdAt)
			local value = candidate.importance * candidate.confidence - age * 0.0001
			if value < weakestValue then
				weakestValue = value
				removeIndex = index
			end
		end
		table.remove(runtime.memories, removeIndex)
	end
	return true
end

function ComputerPlayerService:GetMemories(participantId: string): { BotMemory }
	local runtime = self.runtimesByParticipantId[participantId]
	if not runtime then
		return {}
	end
	local now = self.clock:Now()
	local result: { BotMemory } = {}
	for _, memory in runtime.memories do
		if not memory.expiresAt or memory.expiresAt > now then
			table.insert(result, cloneMemory(memory))
		end
	end
	return result
end

function ComputerPlayerService:ForgetExpiredMemories(participantId: string)
	local runtime = self.runtimesByParticipantId[participantId]
	if not runtime then
		return
	end
	local now = self.clock:Now()
	local retained: { BotMemory } = {}
	for _, memory in runtime.memories do
		if not memory.expiresAt or memory.expiresAt > now then
			table.insert(retained, memory)
		end
	end
	runtime.memories = retained
end

function ComputerPlayerService:BuildMurdererLieTarget(participantId: string): string?
	local runtime = self.runtimesByParticipantId[participantId]
	local participant = self.participantService:GetById(participantId)
	if not runtime or not participant or participant.role ~= "Murderer" then
		return nil
	end

	local bestTarget: string? = nil
	local bestValue = -math.huge
	for otherParticipantId, relationship in runtime.relationships do
		local other = self.participantService:GetById(otherParticipantId)
		if other and other.alive and other.role ~= "Murderer" then
			local value = relationship.suspicion - relationship.trust * 0.25
			if value > bestValue then
				bestValue = value
				bestTarget = otherParticipantId
			end
		end
	end
	return bestTarget
end

function ComputerPlayerService:ScoreAction(
	participantId: string,
	candidate: ActionCandidate,
	context: ActionContext
): number
	local runtime = self.runtimesByParticipantId[participantId]
	local participant = self.participantService:GetById(participantId)
	if not runtime or not participant or not runtime.active then
		return -math.huge
	end
	local allowedPhases = ALLOWED_PHASES[candidate.actionType]
	if not allowedPhases or not allowedPhases[context.phase] then
		return -math.huge
	end
	if not participant.alive or participant.isGhost then
		return if candidate.actionType == "Idle" then candidate.baseUtility else -math.huge
	end
	if candidate.targetParticipantId == participantId then
		return -math.huge
	end
	if candidate.actionType == "Attack" and participant.role ~= "Murderer" then
		return -math.huge
	end
	if candidate.isDeceptive and participant.role ~= "Murderer" then
		return -math.huge
	end

	local personality = runtime.personality
	local tuning = BotProfiles.GetDifficulty(runtime.difficulty)
	local utility = candidate.baseUtility
	utility += (candidate.teamValue or 0) * (0.5 + personality.altruism)
	utility += (candidate.informationValue or 0) * (0.5 + personality.curiosity)
	utility -= (candidate.risk or 0) * (1.25 - personality.bravery)

	if candidate.actionType == "CompleteObjective" then
		utility += 12 * personality.altruism
	elseif candidate.actionType == "CollectEvidence" then
		utility += 15 * personality.curiosity + 8 * personality.honesty
	elseif candidate.actionType == "UseRoleAbility" then
		utility += 10 * (personality.curiosity + personality.altruism)
	elseif candidate.actionType == "Attack" then
		utility += 20 * personality.aggression
	elseif candidate.actionType == "Discuss" then
		utility += 10 * personality.sociability
		if candidate.isDeceptive then
			utility += 20 * tuning.lieSkill + 10 * (1 - personality.honesty)
		end
	elseif candidate.actionType == "Vote" then
		local targetId = candidate.targetParticipantId
		if targetId then
			local relationship = runtime.relationships[targetId]
			if relationship then
				utility += relationship.suspicion * 30 - relationship.trust * 12
			end
			for _, memory in self:GetMemories(participantId) do
				if memory.subjectParticipantId == targetId then
					local direction = if memory.kind == "Statement" then 0.5 else 1
					utility += memory.confidence * memory.importance * 12 * direction
				end
			end
		end
	end

	local noiseRange = (1 - tuning.decisionQuality) * 20
	utility += self.randomSource:NextNumber(-noiseRange, noiseRange)
	return utility
end

function ComputerPlayerService:ChooseAction(
	participantId: string,
	context: ActionContext
): ScoredAction?
	local participant = self.participantService:GetById(participantId)
	local runtime = self.runtimesByParticipantId[participantId]
	if not participant or not runtime or not runtime.active then
		return nil
	end

	local candidates = table.clone(self.callbacks.getAvailableActions(participant, context))
	if
		participant.role == "Murderer"
		and ALLOWED_PHASES.Discuss[context.phase]
	then
		local lieTargetId = self:BuildMurdererLieTarget(participantId)
		local lieTarget = if lieTargetId
			then self.participantService:GetById(lieTargetId)
			else nil
		if lieTargetId and lieTarget then
			table.insert(candidates, {
				id = "strategic-lie:" .. lieTargetId,
				actionType = "Discuss",
				baseUtility = 8,
				targetParticipantId = lieTargetId,
				objectiveId = nil,
				evidenceId = nil,
				abilityId = nil,
				discussionText = "I found something suspicious about " .. lieTarget.displayName .. ".",
				isDeceptive = true,
				risk = 0.35,
				informationValue = 0,
				teamValue = 0.5,
			})
		end
	end
	local best: ScoredAction? = nil
	for _, candidate in candidates do
		local utility = self:ScoreAction(participantId, candidate, context)
		if not best or utility > best.utility then
			best = {
				candidate = candidate,
				utility = utility,
			}
		end
	end
	return best
end

function ComputerPlayerService:StepBot(
	participantId: string,
	phase: PhaseName,
	roundNumber: number
): boolean
	local runtime = self.runtimesByParticipantId[participantId]
	local participant = self.participantService:GetById(participantId)
	if not runtime or not participant or not runtime.active then
		return false
	end
	local now = self.clock:Now()
	if now < runtime.nextThinkAt then
		return false
	end

	self:ForgetExpiredMemories(participantId)
	self:RefreshRelationships(participantId)
	local context: ActionContext = {
		phase = phase,
		roundNumber = roundNumber,
		now = now,
		publicParticipants = self.participantService:SerializeAllPublic(),
	}
	local selected = self:ChooseAction(participantId, context)
	local acted = false
	if selected and selected.utility > -math.huge then
		acted = self.callbacks.executeAction(participant, selected.candidate, context)
		if acted then
			runtime.lastActionAt = now
			runtime.lastActionId = selected.candidate.id
		end
	end

	local tuning = BotProfiles.GetDifficulty(runtime.difficulty)
	runtime.nextThinkAt = now
		+ tuning.minimumThinkInterval
		+ self.randomSource:NextNumber(0, tuning.decisionJitter)
	return acted
end

function ComputerPlayerService:StepNext(phase: PhaseName, roundNumber: number): boolean
	if #self.runtimeOrder == 0 then
		return false
	end
	self.schedulerIndex = (self.schedulerIndex % #self.runtimeOrder) + 1
	return self:StepBot(self.runtimeOrder[self.schedulerIndex], phase, roundNumber)
end

function ComputerPlayerService:Start(
	getPhase: () -> PhaseName,
	getRoundNumber: (() -> number)?
)
	if self.running then
		return
	end
	self.running = true
	self.schedulerGeneration += 1
	local generation = self.schedulerGeneration
	local interval = 1 / self.maxDecisionsPerSecond
	task.spawn(function()
		while self.running and self.schedulerGeneration == generation do
			self:StepNext(getPhase(), if getRoundNumber then getRoundNumber() else 0)
			task.wait(interval)
		end
	end)
end

function ComputerPlayerService:Stop()
	self.running = false
	self.schedulerGeneration += 1
end

function ComputerPlayerService:DeactivateBot(participantId: string)
	local runtime = self.runtimesByParticipantId[participantId]
	if runtime then
		runtime.active = false
	end
end

function ComputerPlayerService:Destroy()
	self:Stop()
	for _, runtime in self.runtimesByParticipantId do
		runtime.active = false
		runtime.memories = {}
		runtime.relationships = {}
	end
	self.runtimesByParticipantId = {}
	self.runtimeOrder = {}
	self.schedulerIndex = 0
end

return ComputerPlayerService
