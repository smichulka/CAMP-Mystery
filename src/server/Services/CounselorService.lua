--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CounselorTypes = require(
	ReplicatedStorage.Shared.Types:WaitForChild("CounselorTypes")
)
local CounselorCatalog = require(
	script.Parent.Parent.Config:WaitForChild("CounselorCatalog")
)
local MysteryCatalog = require(
	script.Parent.Parent.Config:WaitForChild("MysteryCatalog")
)

type PhaseName = CounselorTypes.PhaseName
type CounselorId = CounselorTypes.CounselorId
type CounselorBehavior = CounselorTypes.CounselorBehavior
type DialogueTopic = CounselorTypes.DialogueTopic
type CounselorDefinition = CounselorTypes.CounselorDefinition
type CounselorScheduleEntry = CounselorTypes.CounselorScheduleEntry
type CounselorMemory = CounselorTypes.CounselorMemory
type CounselorRuntimeState = CounselorTypes.CounselorRuntimeState
type PublicCounselorSnapshot = CounselorTypes.PublicCounselorSnapshot
type PrivateCounselorSnapshot = CounselorTypes.PrivateCounselorSnapshot
type CounselorRosterSnapshot = CounselorTypes.CounselorRosterSnapshot
type CounselorObservation = CounselorTypes.CounselorObservation
type CounselorThreat = CounselorTypes.CounselorThreat
type CounselorDialogueResponse = CounselorTypes.CounselorDialogueResponse

export type Callbacks = {
	canInteract: ((participantId: string, counselorId: CounselorId) -> boolean)?,
	moveCounselor: ((
		counselorId: CounselorId,
		destinationId: string,
		behavior: CounselorBehavior
	) -> ())?,
	onDialogue: ((response: CounselorDialogueResponse) -> ())?,
	onPublicStateChanged: ((snapshot: CounselorRosterSnapshot) -> ())?,
}

type CounselorServiceState = {
	callbacks: Callbacks,
	initialized: boolean,
	destroyed: boolean,
	roundId: number,
	revision: number,
	roundSeed: number,
	phase: PhaseName,
	statesById: { [CounselorId]: CounselorRuntimeState },
	orderedIds: { CounselorId },
	nextMemoryNumber: number,
	dialogueCountByKey: { [string]: number },
	lastDialogueAtByKey: { [string]: number },
	contradictionCounselorId: CounselorId?,
}

local CounselorService = {}
CounselorService.__index = CounselorService

export type CounselorService = typeof(
	setmetatable({} :: CounselorServiceState, CounselorService)
)

local SEED_MODULUS = 2_147_483_647
local COUNSELOR_SEED_SALT = 314_159
local MAX_MEMORIES_PER_COUNSELOR = 12
local DIALOGUE_COOLDOWN_SECONDS = 1.5

local VALID_DIALOGUE_TOPICS: { [DialogueTopic]: boolean } = {
	Greeting = true,
	Schedule = true,
	Observation = true,
	Monster = true,
	Safety = true,
	Suspicion = true,
}

local FIXED_WITNESS_STATEMENTS: { [string]: string } = {}
for _, collection in {
	MysteryCatalog.truthfulWitnessAccounts,
	MysteryCatalog.mistakenWitnessAccounts,
	MysteryCatalog.monsterWitnessAccounts,
} do
	for _, template in collection do
		FIXED_WITNESS_STATEMENTS[template.id] = template.statement
	end
end
table.freeze(FIXED_WITNESS_STATEMENTS)

local function normalizeSeed(seed: number): number
	assert(seed == seed and math.abs(seed) < math.huge, "Counselor seed must be finite")
	assert(seed % 1 == 0, "Counselor seed must be a whole number")
	local normalized = seed % SEED_MODULUS
	if normalized < 0 then
		normalized += SEED_MODULUS
	end
	return normalized
end

local function deriveSeed(roundId: number, explicitSeed: number?): number
	if explicitSeed ~= nil then
		return normalizeSeed(explicitSeed + roundId * 69_069 + COUNSELOR_SEED_SALT)
	end
	return normalizeSeed(roundId * 69_069 + COUNSELOR_SEED_SALT)
end

local function hashString(value: string): number
	local hash = 17
	for index = 1, #value do
		hash = (hash * 31 + string.byte(value, index)) % SEED_MODULUS
	end
	return hash
end

local function getDefinition(counselorId: CounselorId): CounselorDefinition
	local definition = CounselorCatalog.Get(counselorId)
	assert(definition, "Unknown counselor ID: " .. counselorId)
	return definition
end

local function findScheduleEntry(
	definition: CounselorDefinition,
	phase: PhaseName
): CounselorScheduleEntry
	for _, entry in definition.schedule do
		if entry.phase == phase then
			return entry
		end
	end
	error(
		string.format(
			"Counselor %s has no schedule entry for %s",
			definition.id,
			phase
		)
	)
end

local function cloneMemory(memory: CounselorMemory): CounselorMemory
	return {
		memoryId = memory.memoryId,
		kind = memory.kind,
		summary = memory.summary,
		locationId = memory.locationId,
		subjectId = memory.subjectId,
		confidence = memory.confidence,
		createdAt = memory.createdAt,
	}
end

local function baseBehavior(state: CounselorRuntimeState): CounselorBehavior
	if state.isSuspect then
		return "Suspect"
	elseif state.isWitness then
		return "Witness"
	end
	return "Routine"
end

local function interactionAllowed(state: CounselorRuntimeState): boolean
	return state.behavior ~= "Fleeing"
		and state.behavior ~= "Hiding"
		and state.behavior ~= "Unavailable"
end

local function dialogueLines(
	definition: CounselorDefinition,
	topic: DialogueTopic
): { string }
	if topic == "Greeting" then
		return definition.dialogue.Greeting
	elseif topic == "Schedule" then
		return definition.dialogue.Schedule
	elseif topic == "Observation" then
		return definition.dialogue.Observation
	elseif topic == "Monster" then
		return definition.dialogue.Monster
	elseif topic == "Safety" then
		return definition.dialogue.Safety
	else
		return definition.dialogue.Suspicion
	end
end

function CounselorService.new(callbacks: Callbacks?): CounselorService
	return setmetatable({
		callbacks = callbacks or {},
		initialized = false,
		destroyed = false,
		roundId = 0,
		revision = 0,
		roundSeed = 0,
		phase = "Lobby",
		statesById = {},
		orderedIds = {},
		nextMemoryNumber = 0,
		dialogueCountByKey = {},
		lastDialogueAtByKey = {},
	}, CounselorService)
end

function CounselorService:_assertActive()
	assert(not self.destroyed, "CounselorService has been destroyed")
	assert(self.initialized, "BeginRound must be called before using counselor state")
end

function CounselorService:_toPublic(
	state: CounselorRuntimeState
): PublicCounselorSnapshot
	local definition = getDefinition(state.counselorId)
	return {
		counselorId = state.counselorId,
		displayName = definition.displayName,
		roleTitle = definition.roleTitle,
		description = definition.description,
		locationId = state.locationId,
		destinationId = state.destinationId,
		currentActivity = state.currentActivity,
		behavior = state.behavior,
		isWitness = state.isWitness,
		isSuspect = state.isSuspect,
		interactionAllowed = interactionAllowed(state),
		revision = state.revision,
	}
end

function CounselorService:_publish()
	local callback = self.callbacks.onPublicStateChanged
	if callback then
		callback(self:GetPublicSnapshot())
	end
end

function CounselorService:_mutated(state: CounselorRuntimeState?)
	self.revision += 1
	if state then
		state.revision += 1
	end
	self:_publish()
end

function CounselorService:_recordMemory(
	state: CounselorRuntimeState,
	kind: CounselorTypes.CounselorMemoryKind,
	summary: string,
	locationId: string?,
	subjectId: string?,
	confidence: number,
	createdAt: number
)
	self.nextMemoryNumber += 1
	local memory: CounselorMemory = {
		memoryId = string.format(
			"counselor-memory:%d:%04d",
			self.roundId,
			self.nextMemoryNumber
		),
		kind = kind,
		summary = summary,
		locationId = locationId,
		subjectId = subjectId,
		confidence = math.clamp(confidence, 0, 1),
		createdAt = createdAt,
	}
	table.insert(state.memories, memory)
	while #state.memories > MAX_MEMORIES_PER_COUNSELOR do
		table.remove(state.memories, 1)
	end
end

function CounselorService:BeginRound(
	roundId: number,
	explicitSeed: number?
): CounselorRosterSnapshot
	assert(not self.destroyed, "CounselorService has been destroyed")
	assert(
		roundId > 0 and roundId % 1 == 0,
		"roundId must be a positive integer"
	)
	assert(roundId > self.roundId, "Counselor round IDs must increase")

	self.initialized = true
	self.roundId = roundId
	self.revision = 0
	self.roundSeed = deriveSeed(roundId, explicitSeed)
	self.phase = "Lobby"
	self.statesById = {}
	self.orderedIds = table.clone(CounselorCatalog.GetOrderedIds())
	self.nextMemoryNumber = 0
	self.dialogueCountByKey = {}
	self.lastDialogueAtByKey = {}
	-- One seeded counselor misremembers (or hides) their evening this round;
	-- pressing them twice on the Schedule topic makes the story change.
	self.contradictionCounselorId =
		self.orderedIds[(self.roundSeed % #self.orderedIds) + 1]

	for _, counselorId in self.orderedIds do
		local definition = getDefinition(counselorId)
		local schedule = findScheduleEntry(definition, "Lobby")
		local state: CounselorRuntimeState = {
			counselorId = counselorId,
			roundId = roundId,
			phase = "Lobby",
			locationId = schedule.locationId,
			destinationId = nil,
			currentActivity = schedule.activity,
			behavior = "Routine",
			isWitness = false,
			isSuspect = false,
			threatActive = false,
			witnessAccountId = nil,
			witnessStatement = nil,
			memories = {},
			revision = 1,
		}
		self:_recordMemory(
			state,
			"Schedule",
			schedule.activity,
			schedule.locationId,
			nil,
			1,
			0
		)
		self.statesById[counselorId] = state
	end
	self:_mutated()
	return self:GetPublicSnapshot()
end

function CounselorService:SetPhase(
	phase: PhaseName,
	now: number
): CounselorRosterSnapshot
	self:_assertActive()
	assert(now == now and math.abs(now) < math.huge, "Phase time must be finite")
	self.phase = phase
	for _, counselorId in self.orderedIds do
		local state = self.statesById[counselorId]
		local definition = getDefinition(counselorId)
		local schedule = findScheduleEntry(definition, phase)
		state.phase = phase
		state.locationId = schedule.locationId
		state.destinationId = nil
		state.currentActivity = schedule.activity
		state.threatActive = false
		state.behavior = baseBehavior(state)
		self:_recordMemory(
			state,
			"Schedule",
			schedule.activity,
			schedule.locationId,
			nil,
			1,
			now
		)
		state.revision += 1
		local move = self.callbacks.moveCounselor
		if move then
			move(counselorId, schedule.locationId, state.behavior)
		end
	end
	self:_mutated()
	return self:GetPublicSnapshot()
end

function CounselorService:GetPublicSnapshot(): CounselorRosterSnapshot
	local counselors: { PublicCounselorSnapshot } = {}
	for _, counselorId in self.orderedIds do
		local state = self.statesById[counselorId]
		if state then
			table.insert(counselors, self:_toPublic(state))
		end
	end
	return {
		roundId = self.roundId,
		revision = self.revision,
		phase = self.phase,
		counselors = counselors,
	}
end

function CounselorService:GetPrivateSnapshot(
	counselorId: CounselorId
): PrivateCounselorSnapshot?
	local state = self.statesById[counselorId]
	if not state then
		return nil
	end
	local public = self:_toPublic(state)
	local memories: { CounselorMemory } = {}
	for _, memory in state.memories do
		table.insert(memories, cloneMemory(memory))
	end
	return {
		counselorId = public.counselorId,
		displayName = public.displayName,
		roleTitle = public.roleTitle,
		description = public.description,
		locationId = public.locationId,
		destinationId = public.destinationId,
		currentActivity = public.currentActivity,
		behavior = public.behavior,
		isWitness = public.isWitness,
		isSuspect = public.isSuspect,
		interactionAllowed = public.interactionAllowed,
		revision = public.revision,
		roundId = state.roundId,
		phase = state.phase,
		threatActive = state.threatActive,
		witnessAccountId = state.witnessAccountId,
		memories = memories,
	}
end

function CounselorService:GetSchedule(
	counselorId: CounselorId
): { CounselorScheduleEntry }
	local definition = CounselorCatalog.Get(counselorId)
	if not definition then
		return {}
	end
	local result: { CounselorScheduleEntry } = {}
	for _, entry in definition.schedule do
		table.insert(result, {
			phase = entry.phase,
			locationId = entry.locationId,
			activity = entry.activity,
		})
	end
	return result
end

function CounselorService:RecordObservation(
	counselorId: CounselorId,
	observation: CounselorObservation
): (boolean, string?)
	self:_assertActive()
	local state = self.statesById[counselorId]
	if not state then
		return false, "Unknown counselor"
	end
	if observation.summary == "" or #observation.summary > 240 then
		return false, "Observation summary must be between 1 and 240 characters"
	end
	if
		observation.confidence < 0
		or observation.confidence > 1
		or observation.importance < 0
		or observation.importance > 1
	then
		return false, "Observation confidence and importance must be between 0 and 1"
	end
	self:_recordMemory(
		state,
		observation.kind,
		observation.summary,
		observation.locationId,
		observation.subjectId,
		observation.confidence,
		observation.observedAt
	)
	if observation.importance >= 0.65 then
		state.isWitness = true
		if not state.threatActive and not state.isSuspect then
			state.behavior = "Witness"
		end
	end
	self:_mutated(state)
	return true, nil
end

function CounselorService:AssignWitnessAccount(
	counselorId: CounselorId,
	accountId: string,
	templateId: string,
	now: number
): (boolean, string?)
	self:_assertActive()
	local state = self.statesById[counselorId]
	if not state then
		return false, "Unknown counselor"
	end
	local statement = FIXED_WITNESS_STATEMENTS[templateId]
	if not statement then
		return false, "Unknown fixed witness account template"
	end
	if accountId == "" then
		return false, "Witness account ID cannot be empty"
	end
	state.isWitness = true
	state.witnessAccountId = accountId
	state.witnessStatement = statement
	if not state.threatActive and not state.isSuspect then
		state.behavior = "Witness"
	end
	self:_recordMemory(
		state,
		"WitnessAccount",
		statement,
		state.locationId,
		nil,
		getDefinition(counselorId).reliability,
		now
	)
	self:_mutated(state)
	return true, nil
end

function CounselorService:SetSuspect(
	counselorId: CounselorId,
	isSuspect: boolean,
	now: number
): (boolean, string?)
	self:_assertActive()
	local state = self.statesById[counselorId]
	if not state then
		return false, "Unknown counselor"
	end
	state.isSuspect = isSuspect
	if not state.threatActive then
		state.behavior = baseBehavior(state)
	end
	self:_recordMemory(
		state,
		"Suspicion",
		if isSuspect
			then "The counselor was added to the public suspect list."
			else "The counselor was removed from the public suspect list.",
		state.locationId,
		counselorId,
		1,
		now
	)
	self:_mutated(state)
	return true, nil
end

function CounselorService:ReportThreat(threat: CounselorThreat): { CounselorId }
	self:_assertActive()
	assert(threat.locationId ~= "", "Threat location cannot be empty")
	assert(
		threat.severity >= 0 and threat.severity <= 1,
		"Threat severity must be between 0 and 1"
	)
	local affected: { CounselorId } = {}
	for index, counselorId in self.orderedIds do
		local state = self.statesById[counselorId]
		if state.locationId == threat.locationId or threat.severity >= 0.8 then
			local definition = getDefinition(counselorId)
			local shouldFlee = definition.bravery >= threat.severity * 0.82
			local destinations = if shouldFlee
				then definition.fleeLocationIds
				else definition.hideLocationIds
			local destinationIndex = (
				(self.roundSeed + index + self.revision) % #destinations
			) + 1
			local destinationId = destinations[destinationIndex]
			local behavior: CounselorBehavior = if shouldFlee
				then "Fleeing"
				else "Hiding"
			state.threatActive = true
			state.behavior = behavior
			state.destinationId = destinationId
			state.currentActivity = if shouldFlee
				then "Fleeing along an emergency route"
				else "Hiding from the active threat"
			self:_recordMemory(
				state,
				"Threat",
				"An active threat forced an emergency movement.",
				threat.locationId,
				threat.sourceId,
				threat.severity,
				threat.occurredAt
			)
			state.revision += 1
			table.insert(affected, counselorId)
			local move = self.callbacks.moveCounselor
			if move then
				move(counselorId, destinationId, behavior)
			end
		end
	end
	if #affected > 0 then
		self:_mutated()
	end
	return affected
end

function CounselorService:ArriveAtDestination(
	counselorId: CounselorId,
	now: number
): (boolean, string?)
	self:_assertActive()
	local state = self.statesById[counselorId]
	if not state then
		return false, "Unknown counselor"
	end
	local destinationId = state.destinationId
	if not destinationId then
		return false, "Counselor has no active destination"
	end
	state.locationId = destinationId
	state.destinationId = nil
	if state.threatActive then
		if state.behavior == "Fleeing" then
			state.behavior = "Alert"
			state.currentActivity = "Monitoring the safe route for evacuees"
		else
			state.behavior = "Hiding"
			state.currentActivity = "Sheltering until the route is clear"
		end
	else
		state.behavior = baseBehavior(state)
	end
	self:_recordMemory(
		state,
		"Threat",
		"Reached the assigned emergency destination.",
		destinationId,
		nil,
		1,
		now
	)
	self:_mutated(state)
	return true, nil
end

function CounselorService:ClearThreat(
	counselorId: CounselorId?,
	now: number
): number
	self:_assertActive()
	local cleared = 0
	for _, currentId in self.orderedIds do
		if counselorId == nil or counselorId == currentId then
			local state = self.statesById[currentId]
			if state.threatActive then
				state.threatActive = false
				state.destinationId = nil
				state.behavior = baseBehavior(state)
				local schedule = findScheduleEntry(
					getDefinition(currentId),
					self.phase
				)
				state.currentActivity = schedule.activity
				self:_recordMemory(
					state,
					"Threat",
					"The immediate threat was cleared.",
					state.locationId,
					nil,
					1,
					now
				)
				state.revision += 1
				cleared += 1
			end
		end
	end
	if cleared > 0 then
		self:_mutated()
	end
	return cleared
end

function CounselorService:RequestDialogue(
	participantId: string,
	counselorId: CounselorId,
	topic: DialogueTopic,
	now: number
): (CounselorDialogueResponse?, string?)
	self:_assertActive()
	assert(participantId ~= "", "participantId cannot be empty")
	assert(now == now and math.abs(now) < math.huge, "Dialogue time must be finite")
	if not VALID_DIALOGUE_TOPICS[topic] then
		return nil, "Unsupported dialogue topic"
	end
	local state = self.statesById[counselorId]
	if not state then
		return nil, "Unknown counselor"
	end
	if not interactionAllowed(state) then
		return nil, "Counselor cannot talk while fleeing or hiding"
	end
	local canInteract = self.callbacks.canInteract
	if canInteract and not canInteract(participantId, counselorId) then
		return nil, "Participant is not allowed to interact with this counselor"
	end

	local interactionKey = participantId .. "|" .. counselorId
	local lastDialogueAt = self.lastDialogueAtByKey[interactionKey]
	if lastDialogueAt and now - lastDialogueAt < DIALOGUE_COOLDOWN_SECONDS then
		return nil, "Dialogue request is on cooldown"
	end
	self.lastDialogueAtByKey[interactionKey] = now

	local dialogueKey = interactionKey .. "|" .. topic
	local dialogueCount = (self.dialogueCountByKey[dialogueKey] or 0) + 1
	self.dialogueCountByKey[dialogueKey] = dialogueCount
	local definition = getDefinition(counselorId)
	local text: string
	if topic == "Schedule" and counselorId == self.contradictionCounselorId then
		-- The seeded contradiction: a confident blanket alibi on the first
		-- ask that the counselor walks back under repeat questioning. Their
		-- posted schedule (and visible movement) disproves the first claim.
		if dialogueCount == 1 then
			text = "I never left my post all evening. You can ask anyone."
		else
			text = "I told you, I never left— well. I may have stepped away."
				.. " Briefly. Why do you keep asking?"
			if dialogueCount == 2 then
				self:_recordMemory(
					state,
					"Interview",
					"Changed their story about the evening under repeat questioning.",
					state.locationId,
					participantId,
					3,
					now
				)
			end
		end
	elseif topic == "Observation" and state.witnessStatement then
		text = state.witnessStatement
	else
		local lines = dialogueLines(definition, topic)
		local stableIndex = (
			self.roundSeed
			+ hashString(dialogueKey)
			+ dialogueCount
		) % #lines + 1
		text = lines[stableIndex]
	end

	self:_recordMemory(
		state,
		"Interview",
		"Provided a fixed " .. topic .. " response.",
		state.locationId,
		participantId,
		1,
		now
	)
	local response: CounselorDialogueResponse = {
		counselorId = counselorId,
		topic = topic,
		text = text,
		behavior = state.behavior,
		serverTime = now,
	}
	self:_mutated(state)
	local onDialogue = self.callbacks.onDialogue
	if onDialogue then
		onDialogue(response)
	end
	return response, nil
end

function CounselorService:GetContradictionCounselorId(): CounselorId?
	self:_assertActive()
	return self.contradictionCounselorId
end

function CounselorService:EndRound(now: number)
	self:_assertActive()
	for _, counselorId in self.orderedIds do
		local state = self.statesById[counselorId]
		state.behavior = "Unavailable"
		state.destinationId = nil
		state.threatActive = false
		state.currentActivity = "Off duty between mysteries"
		self:_recordMemory(
			state,
			"Schedule",
			"The counselor went off duty at round end.",
			state.locationId,
			nil,
			1,
			now
		)
		state.revision += 1
	end
	self:_mutated()
end

function CounselorService:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.initialized = false
	self.statesById = {}
	self.orderedIds = {}
	self.dialogueCountByKey = {}
	self.lastDialogueAtByKey = {}
	self.callbacks = {}
end

return CounselorService
