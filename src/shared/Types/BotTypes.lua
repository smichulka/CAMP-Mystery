--!strict

local typesFolder = script.Parent
local ParticipantTypes = require(typesFolder:WaitForChild("ParticipantTypes"))
local GameTypes = require(typesFolder:WaitForChild("GameTypes"))

export type DifficultyName = "Beginner" | "Average" | "Expert"
export type PhaseName = GameTypes.PhaseName

export type Personality = {
	bravery: number,
	curiosity: number,
	sociability: number,
	honesty: number,
	aggression: number,
	altruism: number,
}

export type DifficultyTuning = {
	name: DifficultyName,
	decisionQuality: number,
	memoryLimit: number,
	lieSkill: number,
	minimumThinkInterval: number,
	decisionJitter: number,
}

export type BotProfile = {
	id: string,
	displayName: string,
	difficulty: DifficultyName,
	personality: Personality,
}

export type MemoryKind =
	"Evidence"
	| "ObservedAction"
	| "Statement"
	| "Injury"
	| "Vote"
	| "RoleHint"

export type BotMemory = {
	id: string,
	kind: MemoryKind,
	subjectParticipantId: string?,
	relatedParticipantId: string?,
	summary: string,
	confidence: number,
	importance: number,
	createdAt: number,
	expiresAt: number?,
}

export type Relationship = {
	participantId: string,
	trust: number,
	suspicion: number,
	lastUpdatedAt: number,
}

export type ActionType =
	"CompleteObjective"
	| "CollectEvidence"
	| "UseRoleAbility"
	| "Attack"
	| "Discuss"
	| "Vote"
	| "Idle"

export type ActionCandidate = {
	id: string,
	actionType: ActionType,
	baseUtility: number,
	targetParticipantId: string?,
	objectiveId: string?,
	evidenceId: string?,
	abilityId: string?,
	discussionText: string?,
	isDeceptive: boolean?,
	risk: number?,
	informationValue: number?,
	teamValue: number?,
}

export type ScoredAction = {
	candidate: ActionCandidate,
	utility: number,
}

export type ActionContext = {
	phase: PhaseName,
	roundNumber: number,
	now: number,
	publicParticipants: { ParticipantTypes.PublicParticipantSnapshot },
}

export type ActionCallbacks = {
	getAvailableActions: (
		participant: ParticipantTypes.ParticipantState,
		context: ActionContext
	) -> { ActionCandidate },
	executeAction: (
		participant: ParticipantTypes.ParticipantState,
		candidate: ActionCandidate,
		context: ActionContext
	) -> boolean,
}

export type BotRuntimeState = {
	participantId: string,
	profileId: string,
	difficulty: DifficultyName,
	personality: Personality,
	roundNumber: number,
	memories: { BotMemory },
	relationships: { [string]: Relationship },
	nextThinkAt: number,
	lastActionAt: number?,
	lastActionId: string?,
	decisionCount: number,
	active: boolean,
}

export type BotRuntimeSnapshot = {
	participantId: string,
	profileId: string,
	difficulty: DifficultyName,
	roundNumber: number,
	memoryCount: number,
	relationshipCount: number,
	nextThinkAt: number,
	lastActionAt: number?,
	lastActionId: string?,
	decisionCount: number,
	active: boolean,
}

export type BotRandomSource = {
	NextInteger: (self: BotRandomSource, minimum: number, maximum: number) -> number,
	NextNumber: (self: BotRandomSource, minimum: number, maximum: number) -> number,
}

export type BotClock = {
	Now: (self: BotClock) -> number,
}

return {}
