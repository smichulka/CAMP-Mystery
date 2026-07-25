--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterTypes = require(
	ReplicatedStorage.Shared.Types:WaitForChild("MonsterTypes")
)

type MonsterStatusId = MonsterTypes.MonsterStatusId

export type StatusSnapshot = {
	statusId: MonsterStatusId,
	sourceParticipantId: string,
	abilityId: string,
	appliedAt: number,
	expiresAt: number,
}

type Clock = () -> number

type StatusEffectServiceState = {
	roundId: number,
	revision: number,
	clock: Clock,
	effectsByParticipantId: { [string]: { [MonsterStatusId]: StatusSnapshot } },
}

local StatusEffectService = {}
StatusEffectService.__index = StatusEffectService

export type StatusEffectService = typeof(
	setmetatable({} :: StatusEffectServiceState, StatusEffectService)
)

local function defaultClock(): number
	return workspace:GetServerTimeNow()
end

local function cloneStatus(status: StatusSnapshot): StatusSnapshot
	return {
		statusId = status.statusId,
		sourceParticipantId = status.sourceParticipantId,
		abilityId = status.abilityId,
		appliedAt = status.appliedAt,
		expiresAt = status.expiresAt,
	}
end

function StatusEffectService.new(clock: Clock?): StatusEffectService
	return setmetatable({
		roundId = 0,
		revision = 0,
		clock = clock or defaultClock,
		effectsByParticipantId = {},
	}, StatusEffectService)
end

function StatusEffectService:BeginRound(roundId: number)
	assert(roundId > self.roundId, "Round IDs must increase")
	self.roundId = roundId
	self.revision = 0
	self.effectsByParticipantId = {}
end

function StatusEffectService:_clearExpired(participantId: string)
	local effects = self.effectsByParticipantId[participantId]
	if not effects then
		return
	end

	local now = self.clock()
	local changed = false
	for statusId, status in effects do
		if status.expiresAt <= now then
			effects[statusId] = nil
			changed = true
		end
	end
	if changed then
		self.revision += 1
	end
end

function StatusEffectService:Apply(
	participantId: string,
	statusId: MonsterStatusId,
	durationSeconds: number,
	sourceParticipantId: string,
	abilityId: string
): StatusSnapshot
	assert(participantId ~= "", "participantId cannot be empty")
	assert(durationSeconds > 0, "Status duration must be positive")
	local now = self.clock()
	local effects = self.effectsByParticipantId[participantId]
	if not effects then
		effects = {}
		self.effectsByParticipantId[participantId] = effects
	end

	local status: StatusSnapshot = {
		statusId = statusId,
		sourceParticipantId = sourceParticipantId,
		abilityId = abilityId,
		appliedAt = now,
		expiresAt = now + durationSeconds,
	}
	effects[statusId] = status
	self.revision += 1
	return cloneStatus(status)
end

function StatusEffectService:Remove(
	participantId: string,
	statusId: MonsterStatusId
): boolean
	local effects = self.effectsByParticipantId[participantId]
	if not effects or not effects[statusId] then
		return false
	end
	effects[statusId] = nil
	self.revision += 1
	return true
end

function StatusEffectService:Has(
	participantId: string,
	statusId: MonsterStatusId
): boolean
	self:_clearExpired(participantId)
	local effects = self.effectsByParticipantId[participantId]
	return effects ~= nil and effects[statusId] ~= nil
end

function StatusEffectService:GetSnapshot(participantId: string): { StatusSnapshot }
	self:_clearExpired(participantId)
	local result: { StatusSnapshot } = {}
	local effects = self.effectsByParticipantId[participantId]
	if effects then
		for _, status in effects do
			table.insert(result, cloneStatus(status))
		end
	end
	table.sort(result, function(left: StatusSnapshot, right: StatusSnapshot): boolean
		return left.statusId < right.statusId
	end)
	return result
end

function StatusEffectService:ClearParticipant(participantId: string)
	if self.effectsByParticipantId[participantId] then
		self.effectsByParticipantId[participantId] = nil
		self.revision += 1
	end
end

function StatusEffectService:TransferParticipant(
	previousParticipantId: string,
	replacementParticipantId: string
)
	local effects = self.effectsByParticipantId[previousParticipantId]
	if not effects then
		return
	end
	self.effectsByParticipantId[previousParticipantId] = nil
	self.effectsByParticipantId[replacementParticipantId] = effects
	self.revision += 1
end

return StatusEffectService
