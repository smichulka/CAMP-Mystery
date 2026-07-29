--!strict

local typesFolder = script.Parent
local MonsterTypes = require(typesFolder:WaitForChild("MonsterTypes"))

export type MonsterId = MonsterTypes.MonsterId
export type MysteryChannel = "Culprit" | "Monster"
export type MysteryAuthenticity = "Authentic" | "Planted" | "Mistaken"
export type ClueDiscoveryState = "Hidden" | "Discovered"

export type MysteryGenerationRequest = {
	roundId: number,
	roundSeed: number,
	culpritParticipantId: string,
	monsterId: MonsterId,
	suspectIds: { string },
	counselorIds: { string },
	frameTargetId: string?,
	-- Controlled Trace rank (0-3); only honored when frameTargetId is a
	-- deliberate frame job, never for the randomly assigned fallback target.
	frameSharpness: number?,
}

export type MysteryClueTemplate = {
	id: string,
	channel: MysteryChannel,
	title: string,
	publicDescription: string,
	locationIds: { string },
}

export type MonsterClueTemplate = MysteryClueTemplate & {
	monsterCandidates: { MonsterId },
}

export type MysteryClue = {
	clueId: string,
	templateId: string,
	channel: MysteryChannel,
	title: string,
	publicDescription: string,
	authenticity: MysteryAuthenticity,
	locationId: string,
	suspectCandidateIds: { string },
	monsterCandidateIds: { MonsterId },
	discoveryState: ClueDiscoveryState,
	discoveredByParticipantId: string?,
	discoveredAt: number?,
}

export type PublicMysteryClue = {
	clueId: string,
	channel: MysteryChannel,
	title: string,
	publicDescription: string,
	locationId: string,
	suspectCandidateIds: { string },
	monsterCandidateIds: { MonsterId },
	discoveredByParticipantId: string,
	discoveredAt: number,
}

export type WitnessAccountTemplate = {
	id: string,
	channel: MysteryChannel,
	statement: string,
	locationId: string,
}

export type WitnessAccount = {
	accountId: string,
	templateId: string,
	counselorId: string,
	channel: MysteryChannel,
	statement: string,
	locationId: string,
	authenticity: MysteryAuthenticity,
	reliability: number,
	suspectCandidateIds: { string },
	monsterCandidateIds: { MonsterId },
	revealed: boolean,
	interviewedByParticipantId: string?,
	revealedAt: number?,
}

export type PublicWitnessAccount = {
	accountId: string,
	counselorId: string,
	channel: MysteryChannel,
	statement: string,
	locationId: string,
	suspectCandidateIds: { string },
	monsterCandidateIds: { MonsterId },
	interviewedByParticipantId: string,
	revealedAt: number,
}

export type MysterySearchPlacement = {
	clueId: string,
	locationId: string,
}

export type MysteryPublicSnapshot = {
	roundId: number,
	revision: number,
	title: string,
	discoveredClueCount: number,
	totalClueCount: number,
	revealedWitnessCount: number,
	totalWitnessCount: number,
	clues: { PublicMysteryClue },
	witnessAccounts: { PublicWitnessAccount },
}

export type MysteryPrivateSnapshot = {
	roundId: number,
	revision: number,
	roundSeed: number,
	title: string,
	culpritParticipantId: string,
	monsterId: MonsterId,
	frameTargetId: string?,
	suspectIds: { string },
	clues: { MysteryClue },
	witnessAccounts: { WitnessAccount },
}

export type DeductionAudit = {
	culpritIntersection: { string },
	monsterIntersection: { MonsterId },
	authenticCulpritClueCount: number,
	authenticMonsterClueCount: number,
	plantedClueCount: number,
	conflictingWitnessCount: number,
	isCulpritDeducible: boolean,
	isMonsterDeducible: boolean,
}

return {}
