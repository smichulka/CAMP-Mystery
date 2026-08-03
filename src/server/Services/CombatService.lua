--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(
	ReplicatedStorage.Shared.Types:WaitForChild("CombatTypes")
)
local ParticipantTypes = require(
	ReplicatedStorage.Shared.Types:WaitForChild("ParticipantTypes")
)

type AttackRequest = CombatTypes.AttackRequest
type AttackResult = CombatTypes.AttackResult
type CombatSnapshot = CombatTypes.CombatSnapshot
type DefenseResult = CombatTypes.DefenseResult
type ParticipantState = ParticipantTypes.ParticipantState

type ParticipantProvider = {
	GetById: (self: ParticipantProvider, participantId: string) -> ParticipantState?,
}

type InventoryDropper = {
	DropAll: (self: InventoryDropper, participantId: string) -> { string },
}

type LifecycleEmitter = {
	Emit: (
		self: LifecycleEmitter,
		eventName: string,
		payload: { [string]: unknown }
	) -> unknown,
}

type PhaseProvider = () -> string
type DefenseResolver = (
	attacker: ParticipantState,
	target: ParticipantState,
	request: AttackRequest
) -> DefenseResult
type EvidenceEmitter = (
	evidenceKind: string,
	attacker: ParticipantState,
	target: ParticipantState,
	request: AttackRequest
) -> ()

type CombatServiceState = {
	roundId: number,
	revision: number,
	participants: ParticipantProvider,
	inventory: InventoryDropper,
	lifecycle: LifecycleEmitter,
	getPhase: PhaseProvider,
	resolveDefense: DefenseResolver,
	emitEvidence: EvidenceEmitter,
	isProtected: (target: ParticipantState) -> boolean,
}

local CombatService = {}
CombatService.__index = CombatService

export type CombatService = typeof(
	setmetatable({} :: CombatServiceState, CombatService)
)

local function rejected(request: AttackRequest, reason: string): AttackResult
	return {
		accepted = false,
		outcome = "Rejected",
		reason = reason,
		targetParticipantId = request.targetParticipantId,
		injuryLevel = 0,
		evidenceRisk = 0,
	}
end

function CombatService.new(
	participants: ParticipantProvider,
	inventory: InventoryDropper,
	lifecycle: LifecycleEmitter,
	getPhase: PhaseProvider,
	resolveDefense: DefenseResolver?,
	emitEvidence: EvidenceEmitter?,
	isProtected: ((target: ParticipantState) -> boolean)?
): CombatService
	return setmetatable({
		roundId = 0,
		revision = 0,
		participants = participants,
		inventory = inventory,
		lifecycle = lifecycle,
		getPhase = getPhase,
		resolveDefense = resolveDefense
			or function(): DefenseResult
				return "None"
			end,
		emitEvidence = emitEvidence or function() end,
		isProtected = isProtected or function(): boolean
			return false
		end,
	}, CombatService)
end

function CombatService:BeginRound(roundId: number)
	assert(roundId > self.roundId, "Round IDs must increase")
	self.roundId = roundId
	self.revision = 0
end

function CombatService:Eliminate(
	target: ParticipantState,
	reason: string,
	attackerParticipantId: string?
): { string }
	if not target.alive then
		return {}
	end

	target.alive = false
	target.healthState = "Dead"
	target.health = 0
	target.injuryLevel = 4
	local dropped = self.inventory:DropAll(target.participantId)
	self.revision += 1
	self.lifecycle:Emit("ParticipantEliminated", {
		participantId = target.participantId,
		attackerParticipantId = attackerParticipantId,
		reason = reason,
		droppedItemIds = dropped,
	})

	-- Keep the eliminated state visible before ghost controls take over.
	local participantId = target.participantId
	local roundId = self.roundId
	task.delay(3, function()
		if target.alive then
			return
		end
		if self.roundId ~= roundId or target.team == "Observers" then
			return
		end
		if target.participantId ~= participantId or target.isGhost then
			return
		end

		target.isGhost = true
		self.revision += 1
		pcall(function()
			self.lifecycle:Emit("ParticipantGhostTransition", {
				participantId = participantId,
			})
		end)
	end)

	return dropped
end

-- Applies one serious injury outside the normal monster attack request path. This is
-- used by authored hazards and role interception consequences. The injury ladder is
-- Injured → Critical → Incapacitated → Dead; each call advances one tier.
function CombatService:ApplyInjury(
	targetParticipantId: string,
	reason: string,
	attackerParticipantId: string?
): (boolean, string?)
	local target = self.participants:GetById(targetParticipantId)
	if not target then
		return false, "Unknown participant"
	end
	if not target.alive or target.isGhost or target.team ~= "Campers" then
		return false, "Target is not eligible"
	end
	if self.isProtected(target) then
		return false, "The campfire wards off the monster"
	end

	if target.injuryLevel >= 3 then
		self:Eliminate(target, reason, attackerParticipantId)
		return true, "Eliminated"
	end

	if target.injuryLevel >= 2 then
		target.injuryLevel = 3
		target.healthState = "Incapacitated"
		target.health = math.min(target.health, 10)
		self.revision += 1
		self.lifecycle:Emit("ParticipantIncapacitated", {
			participantId = target.participantId,
			attackerParticipantId = attackerParticipantId,
			source = reason,
		})
		return true, "Incapacitated"
	end

	if target.injuryLevel >= 1 then
		target.injuryLevel = 2
		target.healthState = "Critical"
		target.health = math.min(target.health, 25)
		self.revision += 1
		self.lifecycle:Emit("ParticipantCritical", {
			participantId = target.participantId,
			attackerParticipantId = attackerParticipantId,
			source = reason,
		})
		return true, "Critical"
	end

	target.injuryLevel = 1
	target.healthState = "Injured"
	target.health = math.min(target.health, 50)
	self.revision += 1
	self.lifecycle:Emit("ParticipantInjured", {
		participantId = target.participantId,
		attackerParticipantId = attackerParticipantId,
		source = reason,
	})
	return true, "Injured"
end

function CombatService:ApplyAttack(request: AttackRequest): AttackResult
	if request.roundId ~= self.roundId then
		return rejected(request, "Stale or unknown round")
	end
	if self.getPhase() ~= "Investigation" then
		return rejected(request, "Attacks are not active")
	end

	local attacker = self.participants:GetById(request.attackerParticipantId)
	local target = self.participants:GetById(request.targetParticipantId)
	if not attacker or not target then
		return rejected(request, "Unknown participant")
	end
	if attacker.participantId == target.participantId then
		return rejected(request, "A participant cannot attack itself")
	end
	if not attacker.alive or attacker.isGhost or attacker.role ~= "Murderer" then
		return rejected(request, "Attacker is not eligible")
	end
	if not target.alive or target.isGhost or target.team ~= "Campers" then
		return rejected(request, "Target is not eligible")
	end
	if self.isProtected(target) then
		return rejected(request, "The campfire wards off the monster")
	end

	local defense = self.resolveDefense(attacker, target, request)
	if defense == "Blocked" then
		self.emitEvidence("InterruptedAttack", attacker, target, request)
		self.revision += 1
		return {
			accepted = true,
			outcome = "Blocked",
			reason = nil,
			targetParticipantId = target.participantId,
			injuryLevel = target.injuryLevel,
			evidenceRisk = 0.8,
		}
	end

	local evidenceRisk = if defense == "Reduced" then 0.9 else 0.65
	local _, applyResult =
		self:ApplyInjury(target.participantId, request.source, attacker.participantId)

	if not target.alive then
		self.emitEvidence("LethalAttack", attacker, target, request)
		return {
			accepted = true,
			outcome = "Eliminated",
			reason = nil,
			targetParticipantId = target.participantId,
			injuryLevel = target.injuryLevel,
			evidenceRisk = evidenceRisk,
		}
	end

	self.emitEvidence("Injury", attacker, target, request)
	local outcome: AttackOutcome = if applyResult == "Critical"
		then "Critical"
		elseif applyResult == "Incapacitated" then "Incapacitated"
		else "Injured"
	return {
		accepted = true,
		outcome = outcome,
		reason = nil,
		targetParticipantId = target.participantId,
		injuryLevel = target.injuryLevel,
		evidenceRisk = evidenceRisk,
	}
end

function CombatService:Heal(
	healerParticipantId: string,
	targetParticipantId: string,
	skillChallengeSucceeded: boolean
): (boolean, string?)
	local healer = self.participants:GetById(healerParticipantId)
	local target = self.participants:GetById(targetParticipantId)
	if not healer or not target then
		return false, "Unknown participant"
	end
	if
		not healer.alive
		or healer.isGhost
		or not target.alive
		or target.isGhost
		or healer.participantId == target.participantId
	then
		return false, "Healing participants are not eligible"
	end
	if target.injuryLevel ~= 1 or target.healthState ~= "Injured" then
		return false, "Target is not injured"
	end
	if not skillChallengeSucceeded then
		return false, "Skill challenge failed"
	end

	target.injuryLevel = 0
	target.healthState = "Healthy"
	target.health = target.maxHealth
	self.revision += 1
	return true, nil
end

function CombatService:GetSnapshot(participantId: string): CombatSnapshot?
	local participant = self.participants:GetById(participantId)
	if not participant then
		return nil
	end
	return {
		roundId = self.roundId,
		revision = self.revision,
		participantId = participant.participantId,
		alive = participant.alive,
		isGhost = participant.isGhost,
		healthState = participant.healthState,
		injuryLevel = participant.injuryLevel,
		movementMultiplier = if participant.healthState == "Incapacitated"
			then 0.25
			elseif participant.healthState == "Critical" then 0.45
			elseif participant.healthState == "Injured" then 0.72
			else 1,
	}
end

return CombatService
