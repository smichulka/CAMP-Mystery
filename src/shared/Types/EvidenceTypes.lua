--!strict

-- "Insight" cards are derived deductions created by the Detective's Combine
-- action; they post to the culprit column of the board with a distinct look.
export type EvidenceChannel = "Culprit" | "Monster" | "Insight"
export type EvidenceAuthenticity = "Real" | "Fake" | "Ambiguous" | "Contaminated"
export type VerificationState = "Unverified" | "VerifiedReal" | "VerifiedFake"

export type EvidenceDiscovery = {
	discoveredByParticipantId: string,
	discoveredByDisplayName: string,
	locationId: string,
	discoveredAt: number,
}

export type EvidenceNote = {
	authorParticipantId: string,
	text: string,
	createdAt: number,
}

export type EvidenceRecord = {
	evidenceId: string,
	templateId: string,
	channel: EvidenceChannel,
	displayName: string,
	description: string,
	authenticity: EvidenceAuthenticity,
	suspectWeights: { [string]: number },
	monsterWeights: { [string]: number },
	discovery: EvidenceDiscovery?,
	chainOfCustody: { string },
	notes: { EvidenceNote },
	posted: boolean,
	verificationState: VerificationState,
	verifiedByParticipantId: string?,
}

export type PublicEvidenceRecord = {
	evidenceId: string,
	channel: EvidenceChannel,
	displayName: string,
	description: string,
	discovery: EvidenceDiscovery?,
	chainOfCustody: { string },
	notes: { EvidenceNote },
	posted: boolean,
	verificationState: VerificationState,
}

export type EvidenceBoardSnapshot = {
	roundId: number,
	revision: number,
	culpritEvidence: { PublicEvidenceRecord },
	monsterEvidence: { PublicEvidenceRecord },
}

return {}

