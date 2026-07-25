--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RoleCatalog = require(Shared.Config:WaitForChild("RoleCatalog"))
local CombatTypes = require(Shared.Types:WaitForChild("CombatTypes"))
local ParticipantTypes = require(Shared.Types:WaitForChild("ParticipantTypes"))

type AttackRequest = CombatTypes.AttackRequest
type DefenseResult = CombatTypes.DefenseResult
type ParticipantState = ParticipantTypes.ParticipantState

type ParticipantProvider = {
	GetById: (self: any, participantId: string) -> ParticipantState?,
	GetAll: (self: any) -> { ParticipantState },
}

type LifecycleEmitter = {
	Emit: (
		self: any,
		eventName: string,
		payload: { [string]: unknown }
	) -> unknown,
}

type Clock = () -> number
type PhaseProvider = () -> string
type GuardConsequence = (guardParticipantId: string, attackerParticipantId: string) -> ()
type UpgradeRankProvider = (participantId: string, upgradeId: string) -> number

export type AbilityResult = {
	accepted: boolean,
	reason: string?,
	data: unknown?,
}

export type RolePrivateSnapshot = {
	roundId: number,
	revision: number,
	wardParticipantId: string?,
	guardTargetParticipantId: string?,
	activeTrapIds: { string },
	investigationBands: { [string]: string },
	mediumSignalsRemaining: number,
	ghostInterventionAvailable: boolean,
}

type WardState = {
	protectorParticipantId: string,
	targetParticipantId: string,
	ghostIntervention: boolean,
}

type GuardState = {
	guardParticipantId: string,
	targetParticipantId: string,
	expiresAt: number,
}

type TrapState = {
	trapId: string,
	ownerParticipantId: string,
	locationId: string,
	active: boolean,
}

type RoleAbilityServiceState = {
	roundId: number,
	revision: number,
	participants: ParticipantProvider,
	lifecycle: LifecycleEmitter,
	getPhase: PhaseProvider,
	clock: Clock,
	onGuardConsequence: GuardConsequence,
	getUpgradeRank: UpgradeRankProvider,
	wardsByTargetId: { [string]: WardState },
	guardsByTargetId: { [string]: GuardState },
	trapsById: { [string]: TrapState },
	nextTrapNumber: number,
	investigationBandsByDetectiveId: { [string]: { [string]: string } },
	ghostInterventionUsedByProtectorId: { [string]: boolean },
}

local RoleAbilityService = {}
RoleAbilityService.__index = RoleAbilityService

export type RoleAbilityService = typeof(
	setmetatable({} :: RoleAbilityServiceState, RoleAbilityService)
)

local function defaultClock(): number
	return workspace:GetServerTimeNow()
end

local ABILITY_UPGRADES: {
	[string]: {
		id: string,
		cooldownReductionPerRank: number,
	},
} = {
	["field-treatment"] = { id = "steady-hands", cooldownReductionPerRank = 1 },
	["place-warning-trap"] = { id = "careful-reset", cooldownReductionPerRank = 1 },
	["spirit-sense"] = { id = "clear-signal", cooldownReductionPerRank = 2 },
	["guard-post"] = { id = "watchful-post", cooldownReductionPerRank = 1 },
	["protect-participant"] = { id = "focused-ward", cooldownReductionPerRank = 2 },
	["analyze-evidence"] = { id = "methodical-review", cooldownReductionPerRank = 2 },
	["plant-false-evidence"] = { id = "controlled-trace", cooldownReductionPerRank = 2 },
}

local function phaseIncluded(phase: string, allowed: { string }): boolean
	return table.find(allowed, phase) ~= nil
end

local function accepted(data: unknown?): AbilityResult
	return {
		accepted = true,
		reason = nil,
		data = data,
	}
end

local function rejected(reason: string): AbilityResult
	return {
		accepted = false,
		reason = reason,
		data = nil,
	}
end

function RoleAbilityService.new(
	participants: ParticipantProvider,
	lifecycle: LifecycleEmitter,
	getPhase: PhaseProvider,
	onGuardConsequence: GuardConsequence?,
	clock: Clock?,
	getUpgradeRank: UpgradeRankProvider?
): RoleAbilityService
	return setmetatable({
		roundId = 0,
		revision = 0,
		participants = participants,
		lifecycle = lifecycle,
		getPhase = getPhase,
		clock = clock or defaultClock,
		onGuardConsequence = onGuardConsequence or function() end,
		getUpgradeRank = getUpgradeRank or function(
			_participantId: string,
			_upgradeId: string
		): number
			return 0
		end,
		wardsByTargetId = {},
		guardsByTargetId = {},
		trapsById = {},
		nextTrapNumber = 0,
		investigationBandsByDetectiveId = {},
		ghostInterventionUsedByProtectorId = {},
	}, RoleAbilityService)
end

function RoleAbilityService:BeginRound(roundId: number)
	assert(roundId > self.roundId, "Round IDs must increase")
	self.roundId = roundId
	self.revision = 0
	self.wardsByTargetId = {}
	self.guardsByTargetId = {}
	self.trapsById = {}
	self.nextTrapNumber = 0
	self.investigationBandsByDetectiveId = {}
	self.ghostInterventionUsedByProtectorId = {}
end

function RoleAbilityService:_authorize(
	participantId: string,
	abilityId: string,
	allowedPhases: { string },
	allowGhost: boolean?
): (ParticipantState?, string?)
	local participant = self.participants:GetById(participantId)
	if not participant then
		return nil, "Unknown participant"
	end
	if participant.role == "Spectator" or (not participant.alive and not participant.isGhost) then
		return nil, "Participant is not active"
	end
	if participant.isGhost and not allowGhost then
		return nil, "Ghosts cannot use this ability"
	end
	if not phaseIncluded(self.getPhase(), allowedPhases) then
		return nil, "Ability is not available in this phase"
	end

	local definition = RoleCatalog.Get(participant.role)
	local abilityDefinition = nil
	for _, candidate in definition.abilities do
		if candidate.id == abilityId then
			abilityDefinition = candidate
			break
		end
	end
	if not abilityDefinition then
		return nil, "Ability does not belong to this role"
	end

	local now = self.clock()
	if (participant.abilityCooldownEndsAt[abilityId] or 0) > now then
		return nil, "Ability is cooling down"
	end
	local uses = participant.abilityUses[abilityId] or 0
	if abilityDefinition.maxUsesPerRound and uses >= abilityDefinition.maxUsesPerRound then
		return nil, "No uses remain this round"
	end
	return participant, nil
end

function RoleAbilityService:_commit(participant: ParticipantState, abilityId: string)
	local definition = RoleCatalog.Get(participant.role)
	for _, ability in definition.abilities do
		if ability.id == abilityId then
			participant.abilityUses[abilityId] =
				(participant.abilityUses[abilityId] or 0) + 1
			local upgrade = ABILITY_UPGRADES[abilityId]
			local reduction = 0
			if upgrade then
				local rank = math.clamp(
					math.floor(self.getUpgradeRank(participant.participantId, upgrade.id)),
					0,
					5
				)
				reduction = rank * upgrade.cooldownReductionPerRank
			end
			participant.abilityCooldownEndsAt[abilityId] =
				self.clock() + math.max(0, ability.cooldownSeconds - reduction)
			self.revision += 1
			return
		end
	end
	error("Authorized role ability disappeared")
end

function RoleAbilityService:SetProtection(
	protectorParticipantId: string,
	targetParticipantId: string
): AbilityResult
	local protector = self.participants:GetById(protectorParticipantId)
	local reason: string? = nil
	if protector and protector.isGhost then
		if
			protector.role ~= "Protector"
			or self.getPhase() ~= "Investigation"
			or self.ghostInterventionUsedByProtectorId[protectorParticipantId]
		then
			protector = nil
			reason = "Ghost intervention is not available"
		end
	else
		protector, reason = self:_authorize(
			protectorParticipantId,
			"protect-participant",
			{ "Day", "Investigation" },
			false
		)
	end
	if not protector then
		return rejected(reason or "Protection was rejected")
	end
	local target = self.participants:GetById(targetParticipantId)
	if not target or not target.alive or target.isGhost or target.team ~= "Campers" then
		return rejected("Protection target is not eligible")
	end
	if protector.participantId == target.participantId then
		return rejected("Protector cannot ward itself")
	end

	local ghostIntervention = protector.isGhost
	for targetId, ward in self.wardsByTargetId do
		if ward.protectorParticipantId == protectorParticipantId then
			self.wardsByTargetId[targetId] = nil
		end
	end
	self.wardsByTargetId[targetParticipantId] = {
		protectorParticipantId = protectorParticipantId,
		targetParticipantId = targetParticipantId,
		ghostIntervention = ghostIntervention,
	}
	if ghostIntervention then
		self.revision += 1
	else
		self:_commit(protector, "protect-participant")
	end
	return accepted({
		targetParticipantId = targetParticipantId,
		ghostIntervention = ghostIntervention,
	})
end

function RoleAbilityService:SetGuard(
	guardParticipantId: string,
	targetParticipantId: string
): AbilityResult
	local guard, reason =
		self:_authorize(guardParticipantId, "guard-post", { "Day", "Investigation" })
	if not guard then
		return rejected(reason or "Guard action was rejected")
	end
	local target = self.participants:GetById(targetParticipantId)
	if not target or not target.alive or target.isGhost or target.team ~= "Campers" then
		return rejected("Guard target is not eligible")
	end
	if guard.participantId == target.participantId then
		return rejected("Guard must protect another participant")
	end

	for targetId, activeGuard in self.guardsByTargetId do
		if activeGuard.guardParticipantId == guardParticipantId then
			self.guardsByTargetId[targetId] = nil
		end
	end
	self.guardsByTargetId[targetParticipantId] = {
		guardParticipantId = guardParticipantId,
		targetParticipantId = targetParticipantId,
		expiresAt = self.clock()
			+ 45
			+ self.getUpgradeRank(guardParticipantId, "watchful-post") * 3,
	}
	self:_commit(guard, "guard-post")
	return accepted({ targetParticipantId = targetParticipantId })
end

function RoleAbilityService:PlaceTrap(
	trapperParticipantId: string,
	locationId: string
): AbilityResult
	local trapper, reason = self:_authorize(
		trapperParticipantId,
		"place-warning-trap",
		{ "Day", "Investigation" }
	)
	if not trapper then
		return rejected(reason or "Trap placement was rejected")
	end
	if locationId == "" or #locationId > 80 then
		return rejected("Trap location is invalid")
	end

	self.nextTrapNumber += 1
	local trapId = string.format("trap:%d:%d", self.roundId, self.nextTrapNumber)
	self.trapsById[trapId] = {
		trapId = trapId,
		ownerParticipantId = trapperParticipantId,
		locationId = locationId,
		active = true,
	}
	self:_commit(trapper, "place-warning-trap")
	return accepted({ trapId = trapId, locationId = locationId })
end

function RoleAbilityService:TriggerTrap(
	trapId: string,
	triggeringParticipantId: string
): AbilityResult
	local trap = self.trapsById[trapId]
	local triggering = self.participants:GetById(triggeringParticipantId)
	if not trap or not trap.active then
		return rejected("Trap is not active")
	end
	if not triggering or not triggering.alive or triggering.isGhost then
		return rejected("Triggering participant is not eligible")
	end
	local recoveryRank = math.clamp(
		math.floor(self.getUpgradeRank(trap.ownerParticipantId, "careful-reset")),
		0,
		3
	)
	local recovered = recoveryRank > 0
		and (self.roundId + #trap.trapId + recoveryRank) % 4 < recoveryRank
	trap.active = recovered
	self.revision += 1
	return accepted({
		trapId = trapId,
		ownerParticipantId = trap.ownerParticipantId,
		triggeringParticipantId = triggeringParticipantId,
		revealedMonster = triggering.role == "Murderer",
		slowSeconds = if triggering.role == "Murderer" then 4 else 1,
		recovered = recovered,
	})
end

function RoleAbilityService:Investigate(
	detectiveParticipantId: string,
	targetParticipantId: string
): AbilityResult
	local detective, reason = self:_authorize(
		detectiveParticipantId,
		"analyze-evidence",
		{ "Day", "Investigation" }
	)
	if not detective then
		return rejected(reason or "Investigation was rejected")
	end
	local target = self.participants:GetById(targetParticipantId)
	if
		not target
		or target.participantId == detectiveParticipantId
		or target.role == "Spectator"
	then
		return rejected("Investigation target is invalid")
	end

	-- The deterministic noise keeps the result useful without turning the ability into
	-- an exact role reveal. Murderers are usually Moderate/High; innocents are usually
	-- Low/Moderate.
	local hash = self.roundId
	for index = 1, #targetParticipantId do
		hash = (hash * 33 + string.byte(targetParticipantId, index)) % 997
	end
	local band = if target.role == "Murderer"
		then (if hash % 4 == 0 then "Moderate" else "High")
		else (if hash % 5 == 0 then "Moderate" else "Low")
	local detectiveBands = self.investigationBandsByDetectiveId[detectiveParticipantId]
	if not detectiveBands then
		detectiveBands = {}
		self.investigationBandsByDetectiveId[detectiveParticipantId] = detectiveBands
	end
	detectiveBands[targetParticipantId] = band
	self:_commit(detective, "analyze-evidence")
	return accepted({
		targetParticipantId = targetParticipantId,
		suspicionBand = band,
	})
end

function RoleAbilityService:RequestSpiritSignal(
	mediumParticipantId: string
): AbilityResult
	local medium, reason = self:_authorize(
		mediumParticipantId,
		"spirit-sense",
		{ "Investigation", "Campfire" }
	)
	if not medium then
		return rejected(reason or "Spirit sense was rejected")
	end

	local ghostCount = 0
	for _, participant in self.participants:GetAll() do
		if participant.isGhost then
			ghostCount += 1
		end
	end
	if ghostCount == 0 then
		return rejected("No ghost is able to answer")
	end

	local signals = {
		"THE THREAT WALKED AMONG THE CAMP BEFORE NIGHT.",
		"ONE SHARED CLUE MAY HAVE BEEN PLANTED.",
		"THE ATTACKER FAVORED AN ISOLATED TARGET.",
	}
	local signal = signals[((self.roundId + ghostCount) % #signals) + 1]
	self:_commit(medium, "spirit-sense")
	return accepted({ signal = signal, ghostCount = ghostCount })
end

function RoleAbilityService:AuthorizeTreatment(medicParticipantId: string): AbilityResult
	local medic, reason = self:_authorize(
		medicParticipantId,
		"field-treatment",
		{ "Day", "Investigation" }
	)
	if not medic then
		return rejected(reason or "Treatment was rejected")
	end
	self:_commit(medic, "field-treatment")
	return accepted(nil)
end

function RoleAbilityService:ResolveDefense(
	attacker: ParticipantState,
	target: ParticipantState,
	_request: AttackRequest
): DefenseResult
	local ward = self.wardsByTargetId[target.participantId]
	if ward then
		self.wardsByTargetId[target.participantId] = nil
		if ward.ghostIntervention then
			self.ghostInterventionUsedByProtectorId[ward.protectorParticipantId] = true
			if target.injuryLevel == 0 then
				target.injuryLevel = 1
				target.healthState = "Injured"
				target.health = math.min(target.health, 50)
				self.lifecycle:Emit("ParticipantInjured", {
					participantId = target.participantId,
					attackerParticipantId = attacker.participantId,
					source = "GhostProtectorIntervention",
				})
			end
		end
		self.revision += 1
		return "Blocked"
	end

	local guard = self.guardsByTargetId[target.participantId]
	if guard then
		if guard.expiresAt <= self.clock() then
			self.guardsByTargetId[target.participantId] = nil
		else
			self.guardsByTargetId[target.participantId] = nil
			self.onGuardConsequence(guard.guardParticipantId, attacker.participantId)
			self.revision += 1
			return "Blocked"
		end
	end
	return "None"
end

function RoleAbilityService:GetPrivateSnapshot(
	participantId: string
): RolePrivateSnapshot
	local wardParticipantId: string? = nil
	for targetId, ward in self.wardsByTargetId do
		if ward.protectorParticipantId == participantId then
			wardParticipantId = targetId
			break
		end
	end
	local guardTargetParticipantId: string? = nil
	for targetId, guard in self.guardsByTargetId do
		if guard.guardParticipantId == participantId and guard.expiresAt > self.clock() then
			guardTargetParticipantId = targetId
			break
		end
	end
	local trapIds: { string } = {}
	for trapId, trap in self.trapsById do
		if trap.ownerParticipantId == participantId and trap.active then
			table.insert(trapIds, trapId)
		end
	end
	table.sort(trapIds)
	local participant = self.participants:GetById(participantId)
	local mediumUses = if participant then participant.abilityUses["spirit-sense"] or 0 else 0
	return {
		roundId = self.roundId,
		revision = self.revision,
		wardParticipantId = wardParticipantId,
		guardTargetParticipantId = guardTargetParticipantId,
		activeTrapIds = trapIds,
		investigationBands = table.clone(
			self.investigationBandsByDetectiveId[participantId] or {}
		),
		mediumSignalsRemaining = math.max(0, 2 - mediumUses),
		ghostInterventionAvailable = not self.ghostInterventionUsedByProtectorId[participantId],
	}
end

function RoleAbilityService:TransferParticipant(
	previousParticipantId: string,
	replacementParticipantId: string
)
	local replacementWards: { [string]: WardState } = {}
	for targetId, ward in self.wardsByTargetId do
		local resolvedTargetId = if targetId == previousParticipantId
			then replacementParticipantId
			else targetId
		if ward.protectorParticipantId == previousParticipantId then
			ward.protectorParticipantId = replacementParticipantId
		end
		ward.targetParticipantId = resolvedTargetId
		replacementWards[resolvedTargetId] = ward
	end
	self.wardsByTargetId = replacementWards

	local replacementGuards: { [string]: GuardState } = {}
	for targetId, guard in self.guardsByTargetId do
		local resolvedTargetId = if targetId == previousParticipantId
			then replacementParticipantId
			else targetId
		if guard.guardParticipantId == previousParticipantId then
			guard.guardParticipantId = replacementParticipantId
		end
		guard.targetParticipantId = resolvedTargetId
		replacementGuards[resolvedTargetId] = guard
	end
	self.guardsByTargetId = replacementGuards

	for _, trap in self.trapsById do
		if trap.ownerParticipantId == previousParticipantId then
			trap.ownerParticipantId = replacementParticipantId
		end
	end
	local investigationBands =
		self.investigationBandsByDetectiveId[previousParticipantId]
	if investigationBands then
		self.investigationBandsByDetectiveId[previousParticipantId] = nil
		self.investigationBandsByDetectiveId[replacementParticipantId] =
			investigationBands
	end
	if self.ghostInterventionUsedByProtectorId[previousParticipantId] then
		self.ghostInterventionUsedByProtectorId[previousParticipantId] = nil
		self.ghostInterventionUsedByProtectorId[replacementParticipantId] = true
	end
	self.revision += 1
end

return RoleAbilityService
