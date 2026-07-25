--!strict

local typesFolder = script.Parent
local GameTypes = require(typesFolder:WaitForChild("GameTypes"))

export type CounselorId = string
export type PhaseName = GameTypes.PhaseName
export type CounselorBehavior =
	"Routine"
	| "Witness"
	| "Suspect"
	| "Alert"
	| "Fleeing"
	| "Hiding"
	| "Unavailable"

export type DialogueTopic =
	"Greeting"
	| "Schedule"
	| "Observation"
	| "Monster"
	| "Safety"
	| "Suspicion"

export type CounselorMemoryKind =
	"Schedule"
	| "Observation"
	| "WitnessAccount"
	| "Threat"
	| "Interview"
	| "Suspicion"

export type CounselorScheduleEntry = {
	phase: PhaseName,
	locationId: string,
	activity: string,
}

export type CounselorDialogueSet = {
	Greeting: { string },
	Schedule: { string },
	Observation: { string },
	Monster: { string },
	Safety: { string },
	Suspicion: { string },
}

export type CounselorDefinition = {
	id: CounselorId,
	displayName: string,
	roleTitle: string,
	description: string,
	isAdult: boolean,
	bravery: number,
	reliability: number,
	schedule: { CounselorScheduleEntry },
	hideLocationIds: { string },
	fleeLocationIds: { string },
	dialogue: CounselorDialogueSet,
}

export type CounselorMemory = {
	memoryId: string,
	kind: CounselorMemoryKind,
	summary: string,
	locationId: string?,
	subjectId: string?,
	confidence: number,
	createdAt: number,
}

export type CounselorRuntimeState = {
	counselorId: CounselorId,
	roundId: number,
	phase: PhaseName,
	locationId: string,
	destinationId: string?,
	currentActivity: string,
	behavior: CounselorBehavior,
	isWitness: boolean,
	isSuspect: boolean,
	threatActive: boolean,
	witnessAccountId: string?,
	witnessStatement: string?,
	memories: { CounselorMemory },
	revision: number,
}

export type PublicCounselorSnapshot = {
	counselorId: CounselorId,
	displayName: string,
	roleTitle: string,
	description: string,
	locationId: string,
	destinationId: string?,
	currentActivity: string,
	behavior: CounselorBehavior,
	isWitness: boolean,
	isSuspect: boolean,
	interactionAllowed: boolean,
	revision: number,
}

export type PrivateCounselorSnapshot = PublicCounselorSnapshot & {
	roundId: number,
	phase: PhaseName,
	threatActive: boolean,
	witnessAccountId: string?,
	memories: { CounselorMemory },
}

export type CounselorRosterSnapshot = {
	roundId: number,
	revision: number,
	phase: PhaseName,
	counselors: { PublicCounselorSnapshot },
}

export type CounselorObservation = {
	kind: CounselorMemoryKind,
	summary: string,
	locationId: string?,
	subjectId: string?,
	confidence: number,
	importance: number,
	observedAt: number,
}

export type CounselorThreat = {
	locationId: string,
	sourceId: string?,
	severity: number,
	occurredAt: number,
}

export type CounselorDialogueResponse = {
	counselorId: CounselorId,
	topic: DialogueTopic,
	text: string,
	behavior: CounselorBehavior,
	serverTime: number,
}

return {}
