--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MysteryTypes = require(
	ReplicatedStorage.Shared.Types:WaitForChild("MysteryTypes")
)
local MysteryCatalog = require(
	script.Parent.Parent.Config:WaitForChild("MysteryCatalog")
)

type MonsterId = MysteryTypes.MonsterId
type MysteryAuthenticity = MysteryTypes.MysteryAuthenticity
type MysteryGenerationRequest = MysteryTypes.MysteryGenerationRequest
type MysteryClueTemplate = MysteryTypes.MysteryClueTemplate
type MonsterClueTemplate = MysteryTypes.MonsterClueTemplate
type MysteryClue = MysteryTypes.MysteryClue
type PublicMysteryClue = MysteryTypes.PublicMysteryClue
type WitnessAccountTemplate = MysteryTypes.WitnessAccountTemplate
type WitnessAccount = MysteryTypes.WitnessAccount
type PublicWitnessAccount = MysteryTypes.PublicWitnessAccount
type MysterySearchPlacement = MysteryTypes.MysterySearchPlacement
type MysteryPublicSnapshot = MysteryTypes.MysteryPublicSnapshot
type MysteryPrivateSnapshot = MysteryTypes.MysteryPrivateSnapshot
type DeductionAudit = MysteryTypes.DeductionAudit

export type Callbacks = {
	canDiscover: ((
		participantId: string,
		clueId: string,
		locationId: string
	) -> boolean)?,
	canInterview: ((participantId: string, counselorId: string) -> boolean)?,
	onClueDiscovered: ((clue: PublicMysteryClue) -> ())?,
	onWitnessRevealed: ((account: PublicWitnessAccount) -> ())?,
	onPublicStateChanged: ((snapshot: MysteryPublicSnapshot) -> ())?,
}

type MysteryServiceState = {
	callbacks: Callbacks,
	initialized: boolean,
	roundId: number,
	revision: number,
	roundSeed: number,
	title: string,
	culpritParticipantId: string,
	monsterId: MonsterId,
	frameTargetId: string?,
	suspectIds: { string },
	counselorIds: { string },
	clues: { MysteryClue },
	cluesById: { [string]: MysteryClue },
	witnessAccounts: { WitnessAccount },
	witnessAccountsById: { [string]: WitnessAccount },
	witnessAccountIdsByCounselorId: { [string]: string },
}

local MysteryService = {}
MysteryService.__index = MysteryService

export type MysteryService = typeof(
	setmetatable({} :: MysteryServiceState, MysteryService)
)

local SEED_MODULUS = 2_147_483_647
local MYSTERY_SEED_SALT = 91_931
local CULPRIT_CLUE_COUNT = 3
local PLANTED_CLUE_COUNT = 2
local MONSTER_CLUE_COUNT = 3
local WITNESS_ACCOUNT_COUNT = 4

local function normalizeSeed(seed: number): number
	assert(seed == seed and math.abs(seed) < math.huge, "Mystery seed must be finite")
	assert(seed % 1 == 0, "Mystery seed must be a whole number")
	local normalized = seed % SEED_MODULUS
	if normalized < 0 then
		normalized += SEED_MODULUS
	end
	return normalized
end

local function deriveSeed(roundId: number, roundSeed: number): number
	return normalizeSeed(roundSeed + roundId * 48_271 + MYSTERY_SEED_SALT)
end

local function sortedUnique(source: { string }, label: string): { string }
	local seen: { [string]: boolean } = {}
	local result: { string } = {}
	for _, value in source do
		assert(value ~= "", label .. " cannot contain an empty ID")
		assert(not seen[value], label .. " contains duplicate ID: " .. value)
		seen[value] = true
		table.insert(result, value)
	end
	table.sort(result)
	return result
end

local function shuffled<T>(source: { T }, random: Random): { T }
	local result = table.clone(source)
	for index = #result, 2, -1 do
		local swapIndex = random:NextInteger(1, index)
		result[index], result[swapIndex] = result[swapIndex], result[index]
	end
	return result
end

local function contains(source: { string }, target: string): boolean
	for _, value in source do
		if value == target then
			return true
		end
	end
	return false
end

local function cloneClue(clue: MysteryClue): MysteryClue
	return {
		clueId = clue.clueId,
		templateId = clue.templateId,
		channel = clue.channel,
		title = clue.title,
		publicDescription = clue.publicDescription,
		authenticity = clue.authenticity,
		locationId = clue.locationId,
		suspectCandidateIds = table.clone(clue.suspectCandidateIds),
		monsterCandidateIds = table.clone(clue.monsterCandidateIds),
		discoveryState = clue.discoveryState,
		discoveredByParticipantId = clue.discoveredByParticipantId,
		discoveredAt = clue.discoveredAt,
	}
end

local function toPublicClue(clue: MysteryClue): PublicMysteryClue?
	local participantId = clue.discoveredByParticipantId
	local discoveredAt = clue.discoveredAt
	if clue.discoveryState ~= "Discovered" or not participantId or not discoveredAt then
		return nil
	end
	return {
		clueId = clue.clueId,
		channel = clue.channel,
		title = clue.title,
		publicDescription = clue.publicDescription,
		locationId = clue.locationId,
		suspectCandidateIds = table.clone(clue.suspectCandidateIds),
		monsterCandidateIds = table.clone(clue.monsterCandidateIds),
		discoveredByParticipantId = participantId,
		discoveredAt = discoveredAt,
	}
end

local function cloneWitnessAccount(account: WitnessAccount): WitnessAccount
	return {
		accountId = account.accountId,
		templateId = account.templateId,
		counselorId = account.counselorId,
		channel = account.channel,
		statement = account.statement,
		locationId = account.locationId,
		authenticity = account.authenticity,
		reliability = account.reliability,
		suspectCandidateIds = table.clone(account.suspectCandidateIds),
		monsterCandidateIds = table.clone(account.monsterCandidateIds),
		revealed = account.revealed,
		interviewedByParticipantId = account.interviewedByParticipantId,
		revealedAt = account.revealedAt,
	}
end

local function toPublicWitnessAccount(
	account: WitnessAccount
): PublicWitnessAccount?
	local participantId = account.interviewedByParticipantId
	local revealedAt = account.revealedAt
	if not account.revealed or not participantId or not revealedAt then
		return nil
	end
	return {
		accountId = account.accountId,
		counselorId = account.counselorId,
		channel = account.channel,
		statement = account.statement,
		locationId = account.locationId,
		suspectCandidateIds = table.clone(account.suspectCandidateIds),
		monsterCandidateIds = table.clone(account.monsterCandidateIds),
		interviewedByParticipantId = participantId,
		revealedAt = revealedAt,
	}
end

local function buildAuthenticCandidateSet(
	culpritParticipantId: string,
	suspectIds: { string },
	clueIndex: number
): { string }
	local candidates: { string } = { culpritParticipantId }
	local decoyIndex = 0
	for _, suspectId in suspectIds do
		if suspectId ~= culpritParticipantId then
			decoyIndex += 1
			local exclusionBucket = ((decoyIndex - 1) % CULPRIT_CLUE_COUNT) + 1
			if exclusionBucket ~= clueIndex then
				table.insert(candidates, suspectId)
			end
		end
	end
	table.sort(candidates)
	return candidates
end

local function buildPlantedCandidateSet(
	culpritParticipantId: string,
	frameTargetId: string,
	suspectIds: { string },
	clueIndex: number
): { string }
	local decoys: { string } = {}
	for _, suspectId in suspectIds do
		if suspectId ~= culpritParticipantId and suspectId ~= frameTargetId then
			table.insert(decoys, suspectId)
		end
	end
	local candidates: { string } = { frameTargetId }
	if #decoys > 0 then
		table.insert(candidates, decoys[((clueIndex - 1) % #decoys) + 1])
	end
	if #decoys > 1 then
		table.insert(candidates, decoys[(clueIndex % #decoys) + 1])
	end
	table.sort(candidates)
	return candidates
end

local function intersectStringLists(lists: { { string } }): { string }
	if #lists == 0 then
		return {}
	end
	local counts: { [string]: number } = {}
	for _, value in lists[1] do
		counts[value] = 1
	end
	for listIndex = 2, #lists do
		local present: { [string]: boolean } = {}
		for _, value in lists[listIndex] do
			present[value] = true
		end
		for value, count in counts do
			if count == listIndex - 1 and present[value] then
				counts[value] = listIndex
			else
				counts[value] = nil
			end
		end
	end
	local result: { string } = {}
	for value, count in counts do
		if count == #lists then
			table.insert(result, value)
		end
	end
	table.sort(result)
	return result
end

local function selectLocation(
	template: MysteryClueTemplate,
	random: Random,
	usedLocations: { [string]: boolean }
): string
	local choices = shuffled(template.locationIds, random)
	for _, locationId in choices do
		if not usedLocations[locationId] then
			usedLocations[locationId] = true
			return locationId
		end
	end
	local fallback = choices[1]
	assert(fallback, "Mystery clue template requires at least one location")
	return fallback
end

function MysteryService.new(callbacks: Callbacks?): MysteryService
	return setmetatable({
		callbacks = callbacks or {},
		initialized = false,
		roundId = 0,
		revision = 0,
		roundSeed = 0,
		title = "",
		culpritParticipantId = "",
		monsterId = "BabyAlien",
		frameTargetId = nil,
		suspectIds = {},
		counselorIds = {},
		clues = {},
		cluesById = {},
		witnessAccounts = {},
		witnessAccountsById = {},
		witnessAccountIdsByCounselorId = {},
	}, MysteryService)
end

function MysteryService:_publish()
	local callback = self.callbacks.onPublicStateChanged
	if callback then
		callback(self:GetPublicSnapshot())
	end
end

function MysteryService:_mutated()
	self.revision += 1
	self:_publish()
end

function MysteryService:_addClue(
	template: MysteryClueTemplate,
	authenticity: MysteryAuthenticity,
	locationId: string,
	suspectCandidateIds: { string },
	monsterCandidateIds: { MonsterId }
)
	local clueNumber = #self.clues + 1
	local clue: MysteryClue = {
		clueId = string.format("mystery:%d:clue:%02d", self.roundId, clueNumber),
		templateId = template.id,
		channel = template.channel,
		title = template.title,
		publicDescription = template.publicDescription,
		authenticity = authenticity,
		locationId = locationId,
		suspectCandidateIds = table.clone(suspectCandidateIds),
		monsterCandidateIds = table.clone(monsterCandidateIds),
		discoveryState = "Hidden",
		discoveredByParticipantId = nil,
		discoveredAt = nil,
	}
	table.insert(self.clues, clue)
	self.cluesById[clue.clueId] = clue
end

function MysteryService:_addWitnessAccount(
	template: WitnessAccountTemplate,
	counselorId: string,
	authenticity: MysteryAuthenticity,
	reliability: number,
	suspectCandidateIds: { string },
	monsterCandidateIds: { MonsterId }
)
	local accountNumber = #self.witnessAccounts + 1
	local account: WitnessAccount = {
		accountId = string.format(
			"mystery:%d:witness:%02d",
			self.roundId,
			accountNumber
		),
		templateId = template.id,
		counselorId = counselorId,
		channel = template.channel,
		statement = template.statement,
		locationId = template.locationId,
		authenticity = authenticity,
		reliability = math.clamp(reliability, 0, 1),
		suspectCandidateIds = table.clone(suspectCandidateIds),
		monsterCandidateIds = table.clone(monsterCandidateIds),
		revealed = false,
		interviewedByParticipantId = nil,
		revealedAt = nil,
	}
	table.insert(self.witnessAccounts, account)
	self.witnessAccountsById[account.accountId] = account
	self.witnessAccountIdsByCounselorId[counselorId] = account.accountId
end

function MysteryService:BeginRound(
	request: MysteryGenerationRequest
): MysteryPrivateSnapshot
	assert(
		request.roundId > 0 and request.roundId % 1 == 0,
		"roundId must be a positive integer"
	)
	assert(
		request.roundId > self.roundId,
		"Mystery round IDs must increase"
	)

	local suspectIds = sortedUnique(request.suspectIds, "suspectIds")
	local counselorIds = sortedUnique(request.counselorIds, "counselorIds")
	assert(
		#suspectIds >= 4,
		"Mystery generation requires at least four voting suspects"
	)
	assert(
		#counselorIds >= WITNESS_ACCOUNT_COUNT,
		"Mystery generation requires at least four counselor witnesses"
	)
	assert(
		contains(suspectIds, request.culpritParticipantId),
		"culpritParticipantId must be in suspectIds"
	)
	if request.frameTargetId then
		assert(
			request.frameTargetId ~= request.culpritParticipantId,
			"frame target cannot be the culprit"
		)
		assert(
			contains(suspectIds, request.frameTargetId),
			"frameTargetId must be in suspectIds"
		)
	end

	local seed = deriveSeed(request.roundId, request.roundSeed)
	local random = Random.new(seed)
	local frameTargetId = request.frameTargetId
	if not frameTargetId then
		local frameCandidates: { string } = {}
		for _, suspectId in suspectIds do
			if suspectId ~= request.culpritParticipantId then
				table.insert(frameCandidates, suspectId)
			end
		end
		frameTargetId = frameCandidates[random:NextInteger(1, #frameCandidates)]
	end

	self.initialized = true
	self.roundId = request.roundId
	self.revision = 0
	self.roundSeed = seed
	self.title = MysteryCatalog.titles[
		(seed % #MysteryCatalog.titles) + 1
	]
	self.culpritParticipantId = request.culpritParticipantId
	self.monsterId = request.monsterId
	self.frameTargetId = frameTargetId
	self.suspectIds = suspectIds
	self.counselorIds = counselorIds
	self.clues = {}
	self.cluesById = {}
	self.witnessAccounts = {}
	self.witnessAccountsById = {}
	self.witnessAccountIdsByCounselorId = {}

	local usedLocations: { [string]: boolean } = {}
	local culpritTemplates = shuffled(MysteryCatalog.culpritClues, random)
	for clueIndex = 1, CULPRIT_CLUE_COUNT do
		local template = culpritTemplates[clueIndex]
		assert(template, "Culprit clue catalog is too small")
		self:_addClue(
			template,
			"Authentic",
			selectLocation(template, random, usedLocations),
			buildAuthenticCandidateSet(
				request.culpritParticipantId,
				suspectIds,
				clueIndex
			),
			{}
		)
	end

	local plantedTemplates = shuffled(MysteryCatalog.plantedClues, random)
	for clueIndex = 1, PLANTED_CLUE_COUNT do
		local template = plantedTemplates[clueIndex]
		assert(template, "Planted clue catalog is too small")
		self:_addClue(
			template,
			"Planted",
			selectLocation(template, random, usedLocations),
			buildPlantedCandidateSet(
				request.culpritParticipantId,
				frameTargetId :: string,
				suspectIds,
				clueIndex
			),
			{}
		)
	end

	local monsterTemplates: { MonsterClueTemplate }? =
		MysteryCatalog.monsterClues[request.monsterId]
	assert(monsterTemplates, "Unknown monster mystery profile")
	assert(
		#monsterTemplates >= MONSTER_CLUE_COUNT,
		"Monster mystery profile requires three clues"
	)
	for clueIndex = 1, MONSTER_CLUE_COUNT do
		local template = monsterTemplates[clueIndex]
		assert(template, "Monster clue catalog is too small")
		assert(
			table.find(template.monsterCandidates, request.monsterId),
			"Monster clue must include its owning monster"
		)
		self:_addClue(
			template,
			"Authentic",
			selectLocation(template, random, usedLocations),
			{},
			template.monsterCandidates
		)
	end

	local witnessCounselors = shuffled(counselorIds, random)
	local truthfulTemplates = shuffled(
		MysteryCatalog.truthfulWitnessAccounts,
		random
	)
	for accountIndex = 1, 2 do
		local template = truthfulTemplates[accountIndex]
		local counselorId = witnessCounselors[accountIndex]
		assert(template and counselorId, "Truthful witness catalog is incomplete")
		self:_addWitnessAccount(
			template,
			counselorId,
			"Authentic",
			0.76 + random:NextNumber() * 0.18,
			buildAuthenticCandidateSet(
				request.culpritParticipantId,
				suspectIds,
				accountIndex
			),
			{}
		)
	end

	local mistakenTemplates = shuffled(
		MysteryCatalog.mistakenWitnessAccounts,
		random
	)
	local mistakenTemplate = mistakenTemplates[1]
	local mistakenCounselorId = witnessCounselors[3]
	assert(
		mistakenTemplate and mistakenCounselorId,
		"Mistaken witness catalog is incomplete"
	)
	self:_addWitnessAccount(
		mistakenTemplate,
		mistakenCounselorId,
		"Mistaken",
		0.34 + random:NextNumber() * 0.2,
		buildPlantedCandidateSet(
			request.culpritParticipantId,
			frameTargetId :: string,
			suspectIds,
			1
		),
		{}
	)

	local monsterWitnessTemplates = shuffled(
		MysteryCatalog.monsterWitnessAccounts,
		random
	)
	local monsterWitnessTemplate = monsterWitnessTemplates[1]
	local monsterCounselorId = witnessCounselors[4]
	local firstMonsterTemplate = monsterTemplates[1]
	assert(
		monsterWitnessTemplate and monsterCounselorId and firstMonsterTemplate,
		"Monster witness catalog is incomplete"
	)
	self:_addWitnessAccount(
		monsterWitnessTemplate,
		monsterCounselorId,
		"Authentic",
		0.65 + random:NextNumber() * 0.2,
		{},
		firstMonsterTemplate.monsterCandidates
	)

	local audit = self:AuditDeduction()
	assert(
		audit.isCulpritDeducible,
		"Seeded mystery failed the culprit deduction invariant"
	)
	assert(
		audit.isMonsterDeducible,
		"Seeded mystery failed the monster deduction invariant"
	)
	assert(
		audit.plantedClueCount >= PLANTED_CLUE_COUNT,
		"Seeded mystery requires plausible planted clues"
	)
	assert(
		audit.conflictingWitnessCount >= 1,
		"Seeded mystery requires a conflicting witness"
	)

	self:_mutated()
	return self:GetPrivateSnapshot()
end

function MysteryService:GetSearchPlacements(): { MysterySearchPlacement }
	assert(self.initialized, "BeginRound must be called before reading placements")
	local placements: { MysterySearchPlacement } = {}
	for _, clue in self.clues do
		table.insert(placements, {
			clueId = clue.clueId,
			locationId = clue.locationId,
		})
	end
	return placements
end

function MysteryService:GetPublicSnapshot(): MysteryPublicSnapshot
	local clues: { PublicMysteryClue } = {}
	for _, clue in self.clues do
		local publicClue = toPublicClue(clue)
		if publicClue then
			table.insert(clues, publicClue)
		end
	end

	local witnessAccounts: { PublicWitnessAccount } = {}
	for _, account in self.witnessAccounts do
		local publicAccount = toPublicWitnessAccount(account)
		if publicAccount then
			table.insert(witnessAccounts, publicAccount)
		end
	end

	return {
		roundId = self.roundId,
		revision = self.revision,
		title = self.title,
		discoveredClueCount = #clues,
		totalClueCount = #self.clues,
		revealedWitnessCount = #witnessAccounts,
		totalWitnessCount = #self.witnessAccounts,
		clues = clues,
		witnessAccounts = witnessAccounts,
	}
end

function MysteryService:GetPrivateSnapshot(): MysteryPrivateSnapshot
	assert(self.initialized, "BeginRound must be called before reading mystery state")
	local clues: { MysteryClue } = {}
	for _, clue in self.clues do
		table.insert(clues, cloneClue(clue))
	end
	local witnessAccounts: { WitnessAccount } = {}
	for _, account in self.witnessAccounts do
		table.insert(witnessAccounts, cloneWitnessAccount(account))
	end
	return {
		roundId = self.roundId,
		revision = self.revision,
		roundSeed = self.roundSeed,
		title = self.title,
		culpritParticipantId = self.culpritParticipantId,
		monsterId = self.monsterId,
		frameTargetId = self.frameTargetId,
		suspectIds = table.clone(self.suspectIds),
		clues = clues,
		witnessAccounts = witnessAccounts,
	}
end

function MysteryService:GetWitnessAccountForCounselor(
	counselorId: string
): WitnessAccount?
	local accountId = self.witnessAccountIdsByCounselorId[counselorId]
	local account = if accountId then self.witnessAccountsById[accountId] else nil
	return if account then cloneWitnessAccount(account) else nil
end

function MysteryService:DiscoverClue(
	participantId: string,
	clueId: string,
	now: number
): (boolean, string?)
	assert(self.initialized, "BeginRound must be called before clue discovery")
	assert(participantId ~= "", "participantId cannot be empty")
	assert(now == now and math.abs(now) < math.huge, "Discovery time must be finite")
	local clue = self.cluesById[clueId]
	if not clue then
		return false, "Unknown mystery clue"
	end
	if clue.discoveryState == "Discovered" then
		return false, "Mystery clue was already discovered"
	end
	local canDiscover = self.callbacks.canDiscover
	if canDiscover and not canDiscover(participantId, clueId, clue.locationId) then
		return false, "Participant cannot discover this clue"
	end

	clue.discoveryState = "Discovered"
	clue.discoveredByParticipantId = participantId
	clue.discoveredAt = now
	self:_mutated()

	local publicClue = toPublicClue(clue)
	local callback = self.callbacks.onClueDiscovered
	if publicClue and callback then
		callback(publicClue)
	end
	return true, nil
end

function MysteryService:InterviewCounselor(
	participantId: string,
	counselorId: string,
	now: number
): (PublicWitnessAccount?, string?)
	assert(self.initialized, "BeginRound must be called before witness interviews")
	assert(participantId ~= "", "participantId cannot be empty")
	assert(now == now and math.abs(now) < math.huge, "Interview time must be finite")
	local accountId = self.witnessAccountIdsByCounselorId[counselorId]
	local account = if accountId then self.witnessAccountsById[accountId] else nil
	if not account then
		return nil, "Counselor has no account for this mystery"
	end
	if account.revealed then
		return toPublicWitnessAccount(account), nil
	end
	local canInterview = self.callbacks.canInterview
	if canInterview and not canInterview(participantId, counselorId) then
		return nil, "Participant cannot interview this counselor"
	end

	account.revealed = true
	account.interviewedByParticipantId = participantId
	account.revealedAt = now
	self:_mutated()

	local publicAccount = toPublicWitnessAccount(account)
	local callback = self.callbacks.onWitnessRevealed
	if publicAccount and callback then
		callback(publicAccount)
	end
	return publicAccount, nil
end

-- A disconnected human can be replaced by a bot without changing the mystery.
-- Every server-owned participant reference must move with that control transfer;
-- otherwise authentic clues can continue naming a suspect who is no longer votable.
function MysteryService:TransferParticipant(
	previousParticipantId: string,
	replacementParticipantId: string
): boolean
	if
		not self.initialized
		or previousParticipantId == ""
		or replacementParticipantId == ""
		or previousParticipantId == replacementParticipantId
	then
		return false
	end

	local changed = false
	if self.culpritParticipantId == previousParticipantId then
		self.culpritParticipantId = replacementParticipantId
		changed = true
	end
	if self.frameTargetId == previousParticipantId then
		self.frameTargetId = replacementParticipantId
		changed = true
	end
	for index, suspectId in self.suspectIds do
		if suspectId == previousParticipantId then
			self.suspectIds[index] = replacementParticipantId
			changed = true
		end
	end
	for _, clue in self.clues do
		for index, suspectId in clue.suspectCandidateIds do
			if suspectId == previousParticipantId then
				clue.suspectCandidateIds[index] = replacementParticipantId
				changed = true
			end
		end
		if clue.discoveredByParticipantId == previousParticipantId then
			clue.discoveredByParticipantId = replacementParticipantId
			changed = true
		end
	end
	for _, account in self.witnessAccounts do
		for index, suspectId in account.suspectCandidateIds do
			if suspectId == previousParticipantId then
				account.suspectCandidateIds[index] = replacementParticipantId
				changed = true
			end
		end
		if account.interviewedByParticipantId == previousParticipantId then
			account.interviewedByParticipantId = replacementParticipantId
			changed = true
		end
	end

	if changed then
		self:_mutated()
	end
	return changed
end

function MysteryService:AuditDeduction(): DeductionAudit
	assert(self.initialized, "BeginRound must be called before deduction audit")
	local culpritLists: { { string } } = {}
	local monsterLists: { { string } } = {}
	local authenticCulpritClueCount = 0
	local authenticMonsterClueCount = 0
	local plantedClueCount = 0
	for _, clue in self.clues do
		if clue.authenticity == "Planted" then
			plantedClueCount += 1
		elseif clue.authenticity == "Authentic" and clue.channel == "Culprit" then
			authenticCulpritClueCount += 1
			table.insert(culpritLists, clue.suspectCandidateIds)
		elseif clue.authenticity == "Authentic" and clue.channel == "Monster" then
			authenticMonsterClueCount += 1
			local ids: { string } = {}
			for _, monsterId in clue.monsterCandidateIds do
				table.insert(ids, monsterId)
			end
			table.insert(monsterLists, ids)
		end
	end

	local conflictingWitnessCount = 0
	for _, account in self.witnessAccounts do
		if account.authenticity == "Mistaken" then
			conflictingWitnessCount += 1
		end
	end

	local culpritIntersection = intersectStringLists(culpritLists)
	local monsterStringIntersection = intersectStringLists(monsterLists)
	local monsterIntersection: { MonsterId } = {}
	for _, monsterId in monsterStringIntersection do
		table.insert(monsterIntersection, monsterId :: MonsterId)
	end

	return {
		culpritIntersection = culpritIntersection,
		monsterIntersection = monsterIntersection,
		authenticCulpritClueCount = authenticCulpritClueCount,
		authenticMonsterClueCount = authenticMonsterClueCount,
		plantedClueCount = plantedClueCount,
		conflictingWitnessCount = conflictingWitnessCount,
		isCulpritDeducible = #culpritIntersection == 1
			and culpritIntersection[1] == self.culpritParticipantId,
		isMonsterDeducible = #monsterIntersection == 1
			and monsterIntersection[1] == self.monsterId,
	}
end

function MysteryService:IsSolved(
	accusedParticipantId: string,
	identifiedMonsterId: MonsterId?
): boolean
	assert(self.initialized, "BeginRound must be called before resolving a mystery")
	assert(accusedParticipantId ~= "", "accusedParticipantId cannot be empty")
	return accusedParticipantId == self.culpritParticipantId
		and (identifiedMonsterId == nil or identifiedMonsterId == self.monsterId)
end

return MysteryService
