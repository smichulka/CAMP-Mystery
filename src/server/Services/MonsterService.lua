--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonsterTypes = require(Shared:WaitForChild("Types"):WaitForChild("MonsterTypes"))
local MonsterRules = require(
	script.Parent.Parent:WaitForChild("Config"):WaitForChild("MonsterRules")
)

type MonsterId = MonsterTypes.MonsterId
type MonsterParticipantId = MonsterTypes.MonsterParticipantId
type MonsterLifecycleState = MonsterTypes.MonsterLifecycleState
type AbilityRequest = MonsterTypes.AbilityRequest
type ActivationCheck = MonsterTypes.ActivationCheck
type AbilityActivationResult = MonsterTypes.AbilityActivationResult
type MonsterPublicSnapshot = MonsterTypes.MonsterPublicSnapshot
type MonsterPrivateSnapshot = MonsterTypes.MonsterPrivateSnapshot
type AbilityRule = MonsterTypes.AbilityRule
type AbilityEffect = MonsterTypes.AbilityEffect
type PrivateMonsterRule = MonsterTypes.PrivateMonsterRule
type EvidenceId = MonsterTypes.EvidenceId
type MonsterStatusId = MonsterTypes.MonsterStatusId

export type Callbacks = {
	getPhase: () -> string,
	getPosition: (participantId: MonsterParticipantId) -> Vector3?,
	isTargetable: (participantId: MonsterParticipantId) -> boolean,
	hasLineOfSight: (
		fromPosition: Vector3,
		toPosition: Vector3,
		sourceParticipantId: MonsterParticipantId,
		targetParticipantId: MonsterParticipantId?
	) -> boolean,
	applyAttack: (
		sourceParticipantId: MonsterParticipantId,
		targetParticipantId: MonsterParticipantId,
		amount: number,
		abilityId: string
	) -> (),
	applyStatus: (
		sourceParticipantId: MonsterParticipantId,
		targetParticipantId: MonsterParticipantId,
		statusId: MonsterStatusId,
		durationSeconds: number,
		abilityId: string
	) -> (),
	emitEvidence: (
		monsterId: MonsterId,
		evidenceId: EvidenceId,
		position: Vector3,
		sourceParticipantId: MonsterParticipantId
	) -> (),
	applyMobility: (
		participantId: MonsterParticipantId,
		movementId: string,
		targetPosition: Vector3,
		abilityId: string
	) -> (),
	now: (() -> number)?,
	onPublicStateChanged: ((snapshot: MonsterPublicSnapshot) -> ())?,
	onPrivateStateChanged: ((snapshot: MonsterPrivateSnapshot) -> ())?,
}

type ValidatedActivation = {
	rule: AbilityRule,
	monsterRule: PrivateMonsterRule,
	sourcePosition: Vector3,
	targetPosition: Vector3,
	targetParticipantId: MonsterParticipantId?,
	now: number,
}

type MonsterServiceState = {
	callbacks: Callbacks,
	roundId: number,
	revision: number,
	lifecycle: MonsterLifecycleState,
	participantId: MonsterParticipantId?,
	monsterId: MonsterId?,
	stamina: number,
	cooldownEndsAt: { [string]: number },
	lastRequestSequence: number,
}

local MonsterService = {}
MonsterService.__index = MonsterService

export type MonsterService = typeof(setmetatable({} :: MonsterServiceState, MonsterService))

local MONSTER_ORDER: { MonsterId } = {
	"BabyAlien",
	"Screamer",
	"Wendigo",
	"ShadowMonster",
	"Chupacabra",
	"Dullahan",
	"Entity",
	"Banshee",
}

local function cloneCooldowns(source: { [string]: number }): { [string]: number }
	local result: { [string]: number } = {}
	for abilityId, endsAt in source do
		result[abilityId] = endsAt
	end
	return result
end

local function phaseAllowed(rule: AbilityRule, phase: string): boolean
	for _, allowedPhase in rule.allowedPhases do
		if allowedPhase == phase then
			return true
		end
	end
	return false
end

local function isFiniteVector(value: Vector3): boolean
	return value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) < math.huge
		and math.abs(value.Y) < math.huge
		and math.abs(value.Z) < math.huge
end

function MonsterService.new(callbacks: Callbacks): MonsterService
	assert(callbacks.getPhase, "MonsterService requires getPhase")
	assert(callbacks.getPosition, "MonsterService requires getPosition")
	assert(callbacks.isTargetable, "MonsterService requires isTargetable")
	assert(callbacks.hasLineOfSight, "MonsterService requires hasLineOfSight")
	assert(callbacks.applyAttack, "MonsterService requires applyAttack")
	assert(callbacks.applyStatus, "MonsterService requires applyStatus")
	assert(callbacks.emitEvidence, "MonsterService requires emitEvidence")
	assert(callbacks.applyMobility, "MonsterService requires applyMobility")

	return setmetatable({
		callbacks = callbacks,
		roundId = 0,
		revision = 0,
		lifecycle = "Inactive",
		participantId = nil,
		monsterId = nil,
		stamina = 0,
		cooldownEndsAt = {},
		lastRequestSequence = 0,
	}, MonsterService)
end

function MonsterService:_now(): number
	local provider = self.callbacks.now
	return if provider then provider() else workspace:GetServerTimeNow()
end

function MonsterService:GetPublicSnapshot(): MonsterPublicSnapshot
	local revealSelection = self.lifecycle == "Active" or self.lifecycle == "Stopped"
	return {
		roundId = self.roundId,
		revision = self.revision,
		lifecycle = self.lifecycle,
		active = self.lifecycle == "Active",
		monsterId = if revealSelection then self.monsterId else nil,
		participantId = if revealSelection then self.participantId else nil,
	}
end

function MonsterService:GetPrivateSnapshot(): MonsterPrivateSnapshot
	local monsterId = self.monsterId
	local monsterRule: PrivateMonsterRule? = nil
	if monsterId then
		monsterRule = MonsterRules[monsterId]
	end
	return {
		roundId = self.roundId,
		revision = self.revision,
		lifecycle = self.lifecycle,
		active = self.lifecycle == "Active",
		monsterId = self.monsterId,
		participantId = self.participantId,
		stamina = self.stamina,
		maxStamina = if monsterRule then monsterRule.maxStamina else 0,
		cooldownEndsAt = cloneCooldowns(self.cooldownEndsAt),
		evidenceProfile = if monsterRule then table.clone(monsterRule.evidenceProfile) else {},
	}
end

function MonsterService:_publish()
	local publicCallback = self.callbacks.onPublicStateChanged
	if publicCallback then
		publicCallback(self:GetPublicSnapshot())
	end

	local privateCallback = self.callbacks.onPrivateStateChanged
	if privateCallback then
		privateCallback(self:GetPrivateSnapshot())
	end
end

function MonsterService:_mutated()
	self.revision += 1
	self:_publish()
end

function MonsterService:SelectForRound(
	roundId: number,
	participantId: MonsterParticipantId,
	requestedMonsterId: MonsterId?
): MonsterPrivateSnapshot
	assert(roundId > 0 and roundId % 1 == 0, "roundId must be a positive integer")
	assert(participantId ~= "", "participantId must not be empty")
	assert(
		self.lifecycle == "Inactive" or self.lifecycle == "Stopped",
		"Reset or stop the previous monster lifecycle before selecting"
	)

	local selectedId = requestedMonsterId
	if not selectedId then
		local selectionIndex = ((roundId - 1) % #MONSTER_ORDER) + 1
		selectedId = MONSTER_ORDER[selectionIndex]
	end
	local resolvedId = selectedId :: MonsterId
	local monsterRule = MonsterRules[resolvedId]
	assert(monsterRule ~= nil, "Unknown monster selection")

	self.roundId = roundId
	self.participantId = participantId
	self.monsterId = resolvedId
	self.lifecycle = "Selected"
	self.stamina = monsterRule.maxStamina
	self.cooldownEndsAt = {}
	self.lastRequestSequence = 0
	self:_mutated()
	return self:GetPrivateSnapshot()
end

function MonsterService:BeginPlanning(roundId: number): MonsterPrivateSnapshot
	assert(roundId == self.roundId, "Planning roundId does not match selected round")
	assert(
		self.lifecycle == "Selected" or self.lifecycle == "Planning",
		"Monster planning can only begin after selection"
	)
	if self.lifecycle ~= "Planning" then
		self.lifecycle = "Planning"
		self:_mutated()
	end
	return self:GetPrivateSnapshot()
end

function MonsterService:SelectPlanningMonster(
	roundId: number,
	monsterId: MonsterId
): MonsterPrivateSnapshot
	assert(roundId == self.roundId, "Selection roundId does not match active round")
	assert(
		self.lifecycle == "Selected" or self.lifecycle == "Planning",
		"Monster choice can only change during planning"
	)
	local monsterRule = MonsterRules[monsterId]
	assert(monsterRule ~= nil, "Unknown monster selection")
	self.monsterId = monsterId
	self.stamina = monsterRule.maxStamina
	self.cooldownEndsAt = {}
	self.lastRequestSequence = 0
	self:_mutated()
	return self:GetPrivateSnapshot()
end

function MonsterService:_activateLifecycle(roundId: number): MonsterPublicSnapshot
	assert(roundId == self.roundId, "Activation roundId does not match selected round")
	assert(
		self.lifecycle == "Selected" or self.lifecycle == "Planning",
		"Monster can only activate after selection or planning"
	)
	self.lifecycle = "Active"
	self:_mutated()
	return self:GetPublicSnapshot()
end

function MonsterService:_validateActivation(
	request: AbilityRequest
): (ActivationCheck, ValidatedActivation?)
	local now = self:_now()
	if
		request.roundId <= 0
		or request.roundId % 1 ~= 0
		or request.requestSequence <= 0
		or request.requestSequence % 1 ~= 0
		or request.requestSequence >= math.huge
		or request.participantId == ""
		or request.abilityId == ""
	then
		return { allowed = false, reason = "Request fields are invalid", serverNow = now }, nil
	end
	if self.lifecycle ~= "Active" then
		return { allowed = false, reason = "Monster is not active", serverNow = now }, nil
	end
	if request.roundId ~= self.roundId then
		return { allowed = false, reason = "Round does not match", serverNow = now }, nil
	end
	if request.participantId ~= self.participantId then
		return { allowed = false, reason = "Participant does not own the monster", serverNow = now },
			nil
	end
	if request.requestSequence <= self.lastRequestSequence then
		return { allowed = false, reason = "Request sequence is stale", serverNow = now }, nil
	end

	local monsterId = self.monsterId
	if not monsterId then
		return { allowed = false, reason = "Monster is not selected", serverNow = now }, nil
	end
	local monsterRule = MonsterRules[monsterId]
	local rule = monsterRule.abilities[request.abilityId]
	if not rule then
		return { allowed = false, reason = "Ability is not valid for this monster", serverNow = now },
			nil
	end
	if not phaseAllowed(rule, self.callbacks.getPhase()) then
		return { allowed = false, reason = "Ability is not allowed in this phase", serverNow = now },
			nil
	end
	if (self.cooldownEndsAt[rule.id] or 0) > now then
		return { allowed = false, reason = "Ability is cooling down", serverNow = now }, nil
	end
	if self.stamina < rule.staminaCost then
		return { allowed = false, reason = "Not enough stamina", serverNow = now }, nil
	end

	local sourcePosition = self.callbacks.getPosition(request.participantId)
	if not sourcePosition or not isFiniteVector(sourcePosition) then
		return { allowed = false, reason = "Monster position is unavailable", serverNow = now }, nil
	end

	local targetParticipantId = request.targetParticipantId
	local targetPosition = request.targetPosition
	if rule.requiresTarget then
		if not targetParticipantId or targetParticipantId == request.participantId then
			return { allowed = false, reason = "A different participant target is required", serverNow = now },
				nil
		end
		if not self.callbacks.isTargetable(targetParticipantId) then
			return { allowed = false, reason = "Target is not eligible", serverNow = now }, nil
		end
		targetPosition = self.callbacks.getPosition(targetParticipantId)
		if not targetPosition or not isFiniteVector(targetPosition) then
			return { allowed = false, reason = "Target position is unavailable", serverNow = now },
				nil
		end
	elseif not targetPosition or not isFiniteVector(targetPosition) then
		return { allowed = false, reason = "A target position is required", serverNow = now }, nil
	end

	local resolvedTargetPosition = targetPosition :: Vector3
	if (resolvedTargetPosition - sourcePosition).Magnitude > rule.rangeStuds then
		return { allowed = false, reason = "Target is out of range", serverNow = now }, nil
	end
	if
		rule.requiresLineOfSight
		and not self.callbacks.hasLineOfSight(
			sourcePosition,
			resolvedTargetPosition,
			request.participantId,
			targetParticipantId
		)
	then
		return { allowed = false, reason = "Line of sight is blocked", serverNow = now }, nil
	end

	return { allowed = true, reason = nil, serverNow = now },
		{
			rule = rule,
			monsterRule = monsterRule,
			sourcePosition = sourcePosition,
			targetPosition = resolvedTargetPosition,
			targetParticipantId = targetParticipantId,
			now = now,
		}
end

function MonsterService:CanActivate(request: AbilityRequest): ActivationCheck
	local check, _validated = self:_validateActivation(request)
	return check
end

function MonsterService:_applyEffect(
	effect: AbilityEffect,
	validated: ValidatedActivation,
	sourceParticipantId: MonsterParticipantId
)
	if effect.kind == "Attack" then
		local targetParticipantId = validated.targetParticipantId
		if targetParticipantId then
			self.callbacks.applyAttack(
				sourceParticipantId,
				targetParticipantId,
				effect.amount,
				validated.rule.id
			)
		end
	elseif effect.kind == "Status" then
		local targetParticipantId = validated.targetParticipantId
		if targetParticipantId then
			self.callbacks.applyStatus(
				sourceParticipantId,
				targetParticipantId,
				effect.statusId,
				effect.durationSeconds,
				validated.rule.id
			)
		end
	elseif effect.kind == "Evidence" then
		local monsterId = self.monsterId
		if monsterId then
			self.callbacks.emitEvidence(
				monsterId,
				effect.evidenceId,
				validated.targetPosition,
				sourceParticipantId
			)
		end
	elseif effect.kind == "Mobility" then
		self.callbacks.applyMobility(
			sourceParticipantId,
			effect.movementId,
			validated.targetPosition,
			validated.rule.id
		)
	end
end

function MonsterService:_activateAbility(request: AbilityRequest): AbilityActivationResult
	local check, validated = self:_validateActivation(request)
	if not check.allowed or not validated then
		return {
			accepted = false,
			reason = check.reason,
			roundId = self.roundId,
			revision = self.revision,
			abilityId = request.abilityId,
			staminaRemaining = self.stamina,
			cooldownEndsAt = nil,
		}
	end

	self.lastRequestSequence = request.requestSequence
	self.stamina -= validated.rule.staminaCost
	local cooldownEndsAt = validated.now + validated.rule.cooldownSeconds
	self.cooldownEndsAt[validated.rule.id] = cooldownEndsAt

	for _, effect in validated.rule.effects do
		self:_applyEffect(effect, validated, request.participantId)
	end

	self:_mutated()
	return {
		accepted = true,
		reason = nil,
		roundId = self.roundId,
		revision = self.revision,
		abilityId = request.abilityId,
		staminaRemaining = self.stamina,
		cooldownEndsAt = cooldownEndsAt,
	}
end

-- Activate supports both lifecycle activation and validated ability activation:
-- service:Activate(roundId) activates the selected monster for investigation.
-- service:Activate(request) validates and executes one ability request.
function MonsterService:Activate(
	roundOrRequest: number | AbilityRequest
): MonsterPublicSnapshot | AbilityActivationResult
	if typeof(roundOrRequest) == "number" then
		return self:_activateLifecycle(roundOrRequest)
	end
	return self:_activateAbility(roundOrRequest)
end

function MonsterService:CampfireStop(roundId: number): MonsterPublicSnapshot
	assert(roundId == self.roundId, "Campfire roundId does not match active round")
	assert(
		self.lifecycle == "Active" or self.lifecycle == "Stopped",
		"Monster can only stop after activation"
	)
	if self.lifecycle ~= "Stopped" then
		self.lifecycle = "Stopped"
		self:_mutated()
	end
	return self:GetPublicSnapshot()
end

function MonsterService:TransferControl(
	roundId: number,
	participantId: MonsterParticipantId
): MonsterPrivateSnapshot
	assert(roundId == self.roundId, "Transfer roundId does not match active round")
	assert(participantId ~= "", "Replacement participantId cannot be empty")
	assert(self.lifecycle ~= "Inactive", "No monster lifecycle is available to transfer")
	self.participantId = participantId
	self.lastRequestSequence = 0
	self:_mutated()
	return self:GetPrivateSnapshot()
end

function MonsterService:Reset(roundId: number?)
	if roundId ~= nil and self.roundId ~= 0 then
		assert(roundId == self.roundId, "Reset roundId does not match active round")
	end
	self.roundId = 0
	self.lifecycle = "Inactive"
	self.participantId = nil
	self.monsterId = nil
	self.stamina = 0
	self.cooldownEndsAt = {}
	self.lastRequestSequence = 0
	self:_mutated()
end

return MonsterService
