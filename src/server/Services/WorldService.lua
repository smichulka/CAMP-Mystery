--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldTypes = require(Shared:WaitForChild("Types"):WaitForChild("WorldTypes"))
local WorldManifest = require(
	script.Parent.Parent:WaitForChild("Config"):WaitForChild("WorldManifest")
)

type DistrictId = WorldTypes.DistrictId
type SocketTag = WorldTypes.SocketTag
type TransitionState = WorldTypes.TransitionState
type WorldVariantDefinition = WorldTypes.WorldVariantDefinition
type WorldPublicSnapshot = WorldTypes.WorldPublicSnapshot
type TransformMidpointContext = WorldTypes.TransformMidpointContext
type SocketReference = WorldTypes.SocketReference

export type NightOptions = {
	generatorPowered: boolean?,
	firewoodStocked: boolean?,
}

export type GrayboxFallback = {
	ResetRound: (self: any) -> (),
	SetObjectivePromptsEnabled: (self: any, enabled: boolean) -> (),
	MarkObjectiveComplete: (self: any, objectiveId: string) -> (),
	SetNight: (self: any, isNight: boolean, options: NightOptions?) -> (),
	SpawnEvidence: (self: any) -> (),
	ClearEvidence: (self: any) -> (),
	-- Optional seeded-task-pool extensions; fallbacks without them keep the
	-- legacy always-on station behavior.
	SetActiveObjectives: ((self: any, activeIds: { [string]: boolean }) -> ())?,
	SetObjectiveProgress: ((self: any, objectiveId: string, text: string) -> ())?,
	MarkObjectiveIncomplete: ((self: any, objectiveId: string) -> ())?,
	SpawnTamperEvidence: ((self: any, objectiveId: string) -> ())?,
}

export type Callbacks = {
	relocateAtTransformMidpoint: (context: TransformMidpointContext) -> (),
	onPublicStateChanged: ((snapshot: WorldPublicSnapshot) -> ())?,
}

type WorldServiceState = {
	fallback: GrayboxFallback,
	callbacks: Callbacks,
	roundId: number,
	revision: number,
	roundSeed: number,
	variant: WorldVariantDefinition,
	isNight: boolean,
	transitionState: TransitionState,
	activeDistrictIds: { DistrictId },
	evidenceActive: boolean,
}

local WorldService = {}
WorldService.__index = WorldService

export type WorldService = typeof(setmetatable({} :: WorldServiceState, WorldService))

local SEED_MODULUS = 2_147_483_647
local SEED_MULTIPLIER = 48_271

local function normalizeSeed(seed: number): number
	assert(seed == seed and math.abs(seed) < math.huge, "World seed must be finite")
	assert(seed % 1 == 0, "World seed must be a whole number")
	local normalized = seed % SEED_MODULUS
	if normalized < 0 then
		normalized += SEED_MODULUS
	end
	return normalized
end

local function deriveSeed(roundId: number): number
	return normalizeSeed(roundId * SEED_MULTIPLIER + WorldManifest.seedSalt)
end

local function selectVariant(seed: number): WorldVariantDefinition
	local index = (seed % #WorldManifest.variants) + 1
	return WorldManifest.variants[index]
end

local function cloneDistrictIds(source: { DistrictId }): { DistrictId }
	return table.clone(source)
end

function WorldService.new(
	fallback: GrayboxFallback,
	callbacks: Callbacks
): WorldService
	assert(fallback.ResetRound, "WorldService fallback requires ResetRound")
	assert(
		fallback.SetObjectivePromptsEnabled,
		"WorldService fallback requires SetObjectivePromptsEnabled"
	)
	assert(
		fallback.MarkObjectiveComplete,
		"WorldService fallback requires MarkObjectiveComplete"
	)
	assert(fallback.SetNight, "WorldService fallback requires SetNight")
	assert(fallback.SpawnEvidence, "WorldService fallback requires SpawnEvidence")
	assert(fallback.ClearEvidence, "WorldService fallback requires ClearEvidence")
	assert(
		callbacks.relocateAtTransformMidpoint,
		"WorldService requires a safe midpoint relocation callback"
	)

	local initialVariant = selectVariant(deriveSeed(0))
	return setmetatable({
		fallback = fallback,
		callbacks = callbacks,
		roundId = 0,
		revision = 0,
		roundSeed = 0,
		variant = initialVariant,
		isNight = false,
		transitionState = "Day",
		activeDistrictIds = {},
		evidenceActive = false,
	}, WorldService)
end

function WorldService:GetPublicSnapshot(): WorldPublicSnapshot
	return {
		roundId = self.roundId,
		revision = self.revision,
		roundSeed = self.roundSeed,
		variantId = self.variant.id,
		isNight = self.isNight,
		transitionState = self.transitionState,
		activeDistrictIds = cloneDistrictIds(self.activeDistrictIds),
		evidenceActive = self.evidenceActive,
	}
end

function WorldService:_publish()
	local callback = self.callbacks.onPublicStateChanged
	if callback then
		callback(self:GetPublicSnapshot())
	end
end

function WorldService:_mutated()
	self.revision += 1
	self:_publish()
end

function WorldService:PrepareRound(
	roundId: number,
	explicitSeed: number?
): WorldPublicSnapshot
	assert(roundId > 0 and roundId % 1 == 0, "roundId must be a positive integer")
	local seed = if explicitSeed ~= nil then normalizeSeed(explicitSeed) else deriveSeed(roundId)

	self.fallback:ResetRound()
	self.roundId = roundId
	self.revision = 0
	self.roundSeed = seed
	self.variant = selectVariant(seed)
	self.isNight = false
	self.transitionState = "Day"
	self.activeDistrictIds = {}
	self.evidenceActive = false
	self:_mutated()
	return self:GetPublicSnapshot()
end

function WorldService:ResetRound()
	self.fallback:ResetRound()
	self.isNight = false
	self.transitionState = "Day"
	self.activeDistrictIds = {}
	self.evidenceActive = false
	self:_mutated()
end

function WorldService:SetObjectivePromptsEnabled(enabled: boolean)
	self.fallback:SetObjectivePromptsEnabled(enabled)
end

function WorldService:MarkObjectiveComplete(objectiveId: string)
	assert(objectiveId ~= "", "objectiveId must not be empty")
	self.fallback:MarkObjectiveComplete(objectiveId)
end

function WorldService:SetActiveObjectives(activeIds: { [string]: boolean })
	local setActive = self.fallback.SetActiveObjectives
	if setActive then
		setActive(self.fallback, activeIds)
	end
end

function WorldService:SetObjectiveProgress(objectiveId: string, text: string)
	assert(objectiveId ~= "", "objectiveId must not be empty")
	local setProgress = self.fallback.SetObjectiveProgress
	if setProgress then
		setProgress(self.fallback, objectiveId, text)
	end
end

function WorldService:MarkObjectiveIncomplete(objectiveId: string)
	assert(objectiveId ~= "", "objectiveId must not be empty")
	local markIncomplete = self.fallback.MarkObjectiveIncomplete
	if markIncomplete then
		markIncomplete(self.fallback, objectiveId)
	end
end

function WorldService:SpawnTamperEvidence(objectiveId: string)
	assert(objectiveId ~= "", "objectiveId must not be empty")
	local spawnTamper = self.fallback.SpawnTamperEvidence
	if spawnTamper then
		spawnTamper(self.fallback, objectiveId)
	end
end

function WorldService:_stableState(isNight: boolean): TransitionState
	return if isNight then "Night" else "Day"
end

function WorldService:_transitionState(isNight: boolean): TransitionState
	return if isNight then "TransformingToNight" else "TransformingToDay"
end

function WorldService:SetNight(isNight: boolean, options: NightOptions?)
	if self.isNight == isNight and self.transitionState == self:_stableState(isNight) then
		self.fallback:SetNight(isNight, options)
		return
	end

	local previousIsNight = self.isNight
	self.transitionState = self:_transitionState(isNight)
	self:_mutated()

	local swapped, swapFailure = pcall(function()
		self.fallback:SetNight(isNight, options)
	end)
	if not swapped then
		self.transitionState = self:_stableState(previousIsNight)
		self:_mutated()
		error("World fallback transformation failed: " .. tostring(swapFailure))
	end

	local midpointContext: TransformMidpointContext = {
		roundId = self.roundId,
		revision = self.revision,
		roundSeed = self.roundSeed,
		variantId = self.variant.id,
		direction = if isNight then "ToNight" else "ToDay",
		safeVolumeTag = "SafeVolume",
	}
	local relocated, relocationFailure = pcall(
		self.callbacks.relocateAtTransformMidpoint,
		midpointContext
	)
	if not relocated then
		local rolledBack, rollbackFailure = pcall(function()
			self.fallback:SetNight(previousIsNight)
		end)
		self.isNight = previousIsNight
		self.transitionState = self:_stableState(previousIsNight)
		self.activeDistrictIds = if previousIsNight
			then cloneDistrictIds(self.variant.districtOrder)
			else {}
		self:_mutated()

		if not rolledBack then
			error(
				"World relocation and rollback failed: "
					.. tostring(relocationFailure)
					.. " / "
					.. tostring(rollbackFailure)
			)
		end
		error("World midpoint relocation failed: " .. tostring(relocationFailure))
	end

	self.isNight = isNight
	self.transitionState = self:_stableState(isNight)
	self.activeDistrictIds = if isNight
		then cloneDistrictIds(self.variant.districtOrder)
		else {}
	self:_mutated()
end

function WorldService:SpawnEvidence()
	self.fallback:SpawnEvidence()
	if not self.evidenceActive then
		self.evidenceActive = true
		self:_mutated()
	end
end

function WorldService:ClearEvidence()
	self.fallback:ClearEvidence()
	if self.evidenceActive then
		self.evidenceActive = false
		self:_mutated()
	end
end

function WorldService:GetActiveSockets(tag: SocketTag): { SocketReference }
	local result: { SocketReference } = {}

	for _, socket in WorldManifest.camp.sockets do
		if socket.tag == tag then
			table.insert(result, {
				areaId = "Camp",
				socketId = socket.id,
				tag = socket.tag,
			})
		end
	end

	for _, districtId in self.activeDistrictIds do
		local district = WorldManifest.nightDistricts[districtId]
		for _, socket in district.sockets do
			if socket.tag == tag then
				table.insert(result, {
					areaId = districtId,
					socketId = socket.id,
					tag = socket.tag,
				})
			end
		end
	end

	return result
end

return WorldService
