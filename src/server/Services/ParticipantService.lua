--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local configFolder = Shared:WaitForChild("Config")
local typesFolder = Shared:WaitForChild("Types")
local ParticipantTypes = require(typesFolder:WaitForChild("ParticipantTypes"))
local RoleCatalog = require(configFolder:WaitForChild("RoleCatalog"))

type RoleName = ParticipantTypes.RoleName
type ParticipantState = ParticipantTypes.ParticipantState
type EvidenceKnowledge = ParticipantTypes.EvidenceKnowledge
type PublicParticipantSnapshot = ParticipantTypes.PublicParticipantSnapshot
type PrivateParticipantSnapshot = ParticipantTypes.PrivateParticipantSnapshot
type RandomSource = ParticipantTypes.RandomSource

type ParticipantServiceState = {
	participantsById: { [string]: ParticipantState },
	humanParticipantIdsByUserId: { [number]: string },
	participantOrder: { string },
	randomSource: RandomSource,
}

local ParticipantService = {}
ParticipantService.__index = ParticipantService

export type ParticipantService = typeof(
	setmetatable({} :: ParticipantServiceState, ParticipantService)
)

local MAX_INVENTORY_SLOTS = ParticipantTypes.MAX_INVENTORY_SLOTS
local DEFAULT_MAX_HEALTH = 100

local function humanParticipantId(userId: number): string
	assert(userId ~= 0 and userId % 1 == 0, "Human userId must be a non-zero whole number")
	return "human:" .. tostring(userId)
end

local function botParticipantId(botId: string): string
	assert(botId ~= "", "Bot ID cannot be empty")
	assert(not string.find(botId, ":", 1, true), "Bot ID cannot contain ':'")
	return "bot:" .. botId
end

local function isConnected(state: ParticipantState): boolean
	return state.controller.connected
end

local function isBot(state: ParticipantState): boolean
	return state.controller.kind == "Bot"
end

local function resetParticipant(state: ParticipantState, roleName: RoleName)
	local roleDefinition = RoleCatalog.Get(roleName)
	state.role = roleName
	state.team = roleDefinition.team
	state.alive = roleName ~= "Spectator"
	state.isGhost = false
	state.healthState = "Healthy"
	state.health = state.maxHealth
	state.injuryLevel = 0
	state.inventoryIds = {}
	state.evidenceKnowledge = {}
	state.vote = {
		hasVoted = false,
		targetParticipantId = nil,
	}
	state.abilityUses = {}
	state.abilityCooldownEndsAt = {}
end

local function cloneVote(state: ParticipantState): ParticipantTypes.VoteState
	return {
		hasVoted = state.vote.hasVoted,
		targetParticipantId = state.vote.targetParticipantId,
	}
end

local function sortedEvidenceKnowledge(state: ParticipantState): { EvidenceKnowledge }
	local result: { EvidenceKnowledge } = {}
	for _, knowledge in state.evidenceKnowledge do
		table.insert(result, {
			evidenceId = knowledge.evidenceId,
			displayName = knowledge.displayName,
			confidence = knowledge.confidence,
			isShared = knowledge.isShared,
			learnedAt = knowledge.learnedAt,
		})
	end
	table.sort(result, function(left: EvidenceKnowledge, right: EvidenceKnowledge): boolean
		return left.evidenceId < right.evidenceId
	end)
	return result
end

function ParticipantService.new(randomSource: RandomSource?): ParticipantService
	local source: RandomSource = randomSource or (Random.new() :: any)
	return setmetatable({
		participantsById = {},
		humanParticipantIdsByUserId = {},
		participantOrder = {},
		randomSource = source,
	}, ParticipantService)
end

function ParticipantService:CreateHuman(userId: number, displayName: string): ParticipantState
	assert(displayName ~= "", "Human display name cannot be empty")
	local participantId = humanParticipantId(userId)
	local existing = self.participantsById[participantId]
	if existing then
		existing.displayName = displayName
		existing.controller.connected = true
		return existing
	end

	local state: ParticipantState = {
		participantId = participantId,
		displayName = displayName,
		controller = {
			kind = "Human",
			userId = userId,
			connected = true,
		},
		role = "Spectator",
		team = "Observers",
		alive = false,
		isGhost = false,
		healthState = "Healthy",
		health = DEFAULT_MAX_HEALTH,
		maxHealth = DEFAULT_MAX_HEALTH,
		injuryLevel = 0,
		inventoryIds = {},
		evidenceKnowledge = {},
		vote = {
			hasVoted = false,
			targetParticipantId = nil,
		},
		abilityUses = {},
		abilityCooldownEndsAt = {},
	}
	self.participantsById[participantId] = state
	self.humanParticipantIdsByUserId[userId] = participantId
	table.insert(self.participantOrder, participantId)
	return state
end

function ParticipantService:CreateBot(
	botId: string,
	displayName: string,
	profileId: string?,
	difficulty: number?
): ParticipantState
	assert(displayName ~= "", "Bot display name cannot be empty")
	local participantId = botParticipantId(botId)
	local resolvedDifficulty = difficulty or 1
	assert(
		resolvedDifficulty >= 0 and resolvedDifficulty <= 1,
		"Bot difficulty must be between 0 and 1"
	)
	local existing = self.participantsById[participantId]
	if existing then
		existing.displayName = displayName
		existing.controller.connected = true
		-- A reused bot must adopt the new roster's tuning, not keep whatever
		-- profile/difficulty it was created with in an earlier round.
		if existing.controller.kind == "Bot" then
			existing.controller.profileId = profileId or existing.controller.profileId
			if difficulty ~= nil then
				existing.controller.difficulty = resolvedDifficulty
			end
		end
		return existing
	end
	local state: ParticipantState = {
		participantId = participantId,
		displayName = displayName,
		controller = {
			kind = "Bot",
			botId = botId,
			profileId = profileId or "default",
			difficulty = resolvedDifficulty,
			connected = true,
		},
		role = "Spectator",
		team = "Observers",
		alive = false,
		isGhost = false,
		healthState = "Healthy",
		health = DEFAULT_MAX_HEALTH,
		maxHealth = DEFAULT_MAX_HEALTH,
		injuryLevel = 0,
		inventoryIds = {},
		evidenceKnowledge = {},
		vote = {
			hasVoted = false,
			targetParticipantId = nil,
		},
		abilityUses = {},
		abilityCooldownEndsAt = {},
	}
	self.participantsById[participantId] = state
	table.insert(self.participantOrder, participantId)
	return state
end

function ParticipantService:GetById(participantId: string): ParticipantState?
	return self.participantsById[participantId]
end

function ParticipantService:GetByUserId(userId: number): ParticipantState?
	local participantId = self.humanParticipantIdsByUserId[userId]
	if not participantId then
		return nil
	end
	return self.participantsById[participantId]
end

function ParticipantService:GetAll(): { ParticipantState }
	local result: { ParticipantState } = {}
	for _, participantId in self.participantOrder do
		local state = self.participantsById[participantId]
		if state then
			table.insert(result, state)
		end
	end
	return result
end

function ParticipantService:SetHumanConnected(userId: number, connected: boolean)
	local state = self:GetByUserId(userId)
	if state and state.controller.kind == "Human" then
		state.controller.connected = connected
	end
end

function ParticipantService:ResetRound(participantIds: { string }?): { [string]: RoleName }
	local selectedIds: { string } = {}
	if participantIds then
		local seen: { [string]: boolean } = {}
		for _, participantId in participantIds do
			assert(not seen[participantId], "Duplicate participant ID: " .. participantId)
			local state = self.participantsById[participantId]
			assert(state, "Unknown participant ID: " .. participantId)
			seen[participantId] = true
			table.insert(selectedIds, participantId)
		end
	else
		for _, participantId in self.participantOrder do
			local state = self.participantsById[participantId]
			if state and isConnected(state) then
				table.insert(selectedIds, participantId)
			end
		end
	end

	assert(#selectedIds <= 12, "A round supports at most 12 participants")
	table.sort(selectedIds)
	for index = #selectedIds, 2, -1 do
		local swapIndex = self.randomSource:NextInteger(1, index)
		selectedIds[index], selectedIds[swapIndex] = selectedIds[swapIndex], selectedIds[index]
	end

	for _, state in self:GetAll() do
		resetParticipant(state, "Spectator")
	end

	local roles = RoleCatalog.GetDistribution(#selectedIds)
	local assignments: { [string]: RoleName } = {}
	for index, participantId in selectedIds do
		local state = self.participantsById[participantId]
		local roleName = roles[index]
		assert(state, "Selected participant disappeared during round reset")
		assert(roleName, "Role distribution did not cover every participant")
		resetParticipant(state, roleName)
		assignments[participantId] = roleName
	end
	return assignments
end

function ParticipantService:AddInventoryItem(participantId: string, inventoryId: string): boolean
	assert(inventoryId ~= "", "Inventory ID cannot be empty")
	local state = self.participantsById[participantId]
	if not state or #state.inventoryIds >= MAX_INVENTORY_SLOTS then
		return false
	end
	table.insert(state.inventoryIds, inventoryId)
	return true
end

function ParticipantService:RemoveInventoryItem(
	participantId: string,
	inventoryId: string
): boolean
	local state = self.participantsById[participantId]
	if not state then
		return false
	end
	for index, currentId in state.inventoryIds do
		if currentId == inventoryId then
			table.remove(state.inventoryIds, index)
			return true
		end
	end
	return false
end

function ParticipantService:RecordEvidenceKnowledge(
	participantId: string,
	knowledge: EvidenceKnowledge
): boolean
	local state = self.participantsById[participantId]
	if not state then
		return false
	end
	assert(knowledge.evidenceId ~= "", "Evidence ID cannot be empty")
	assert(
		knowledge.confidence >= 0 and knowledge.confidence <= 1,
		"Evidence confidence must be between 0 and 1"
	)
	state.evidenceKnowledge[knowledge.evidenceId] = {
		evidenceId = knowledge.evidenceId,
		displayName = knowledge.displayName,
		confidence = knowledge.confidence,
		isShared = knowledge.isShared,
		learnedAt = knowledge.learnedAt,
	}
	return true
end

function ParticipantService:SetVote(
	participantId: string,
	targetParticipantId: string?
): boolean
	local state = self.participantsById[participantId]
	if not state or not state.alive or state.isGhost then
		return false
	end
	if targetParticipantId and not self.participantsById[targetParticipantId] then
		return false
	end
	state.vote = {
		hasVoted = targetParticipantId ~= nil,
		targetParticipantId = targetParticipantId,
	}
	return true
end

function ParticipantService:SerializePublic(
	participantOrId: ParticipantState | string
): PublicParticipantSnapshot?
	local state = if typeof(participantOrId) == "string"
		then self.participantsById[participantOrId]
		else participantOrId
	if not state then
		return nil
	end

	return {
		participantId = state.participantId,
		displayName = state.displayName,
		controllerKind = state.controller.kind,
		isBot = isBot(state),
		connected = isConnected(state),
		alive = state.alive,
		isGhost = state.isGhost,
		healthState = state.healthState,
		health = state.health,
		maxHealth = state.maxHealth,
		injuryLevel = state.injuryLevel,
	}
end

function ParticipantService:SerializePrivate(
	participantOrId: ParticipantState | string
): PrivateParticipantSnapshot?
	local state = if typeof(participantOrId) == "string"
		then self.participantsById[participantOrId]
		else participantOrId
	if not state then
		return nil
	end

	local roleDefinition = RoleCatalog.Get(state.role)
	local abilityIds: { string } = {}
	for _, ability in roleDefinition.abilities do
		table.insert(abilityIds, ability.id)
	end

	return {
		participantId = state.participantId,
		displayName = state.displayName,
		controllerKind = state.controller.kind,
		isBot = isBot(state),
		connected = isConnected(state),
		role = state.role,
		roleDisplayName = roleDefinition.displayName,
		roleDescription = roleDefinition.description,
		team = state.team,
		abilityIds = abilityIds,
		alive = state.alive,
		isGhost = state.isGhost,
		healthState = state.healthState,
		health = state.health,
		maxHealth = state.maxHealth,
		injuryLevel = state.injuryLevel,
		inventoryIds = table.clone(state.inventoryIds),
		inventoryCapacity = MAX_INVENTORY_SLOTS,
		evidenceKnowledge = sortedEvidenceKnowledge(state),
		vote = cloneVote(state),
		abilityCooldownEndsAt = table.clone(state.abilityCooldownEndsAt),
	}
end

function ParticipantService:SerializeAllPublic(): { PublicParticipantSnapshot }
	local snapshots: { PublicParticipantSnapshot } = {}
	for _, state in self:GetAll() do
		local snapshot = self:SerializePublic(state)
		if snapshot then
			table.insert(snapshots, snapshot)
		end
	end
	return snapshots
end

return ParticipantService
