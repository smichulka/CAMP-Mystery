--!strict

export type PhaseName =
	"Lobby"
	| "RoleReveal"
	| "Day"
	| "MurderPlanning"
	| "NightTransform"
	| "Investigation"
	| "Campfire"
	| "Resolution"
	| "Rewards"

export type RoleName = "Camper" | "Murderer" | "Spectator"
export type WinnerName = "Campers" | "Murderer"

export type PhaseConfig = {
	name: PhaseName,
	displayName: string,
	durationSeconds: number,
	studioDurationSeconds: number?,
}

export type Suspect = {
	key: string,
	displayName: string,
}

export type EvidenceSummary = {
	id: string,
	displayName: string,
	description: string,
	foundBy: string,
}

export type RoundSnapshot = {
	roundNumber: number,
	phase: PhaseName,
	phaseDisplayName: string,
	phaseStartedAt: number,
	phaseEndsAt: number,
	serverNow: number,
	objectivesCompleted: number,
	objectiveGoal: number,
	evidenceFound: number,
	evidenceGoal: number,
	evidence: { EvidenceSummary },
	suspects: { Suspect },
	votesCast: number,
	eligibleVoters: number,
	victimName: string?,
	winner: WinnerName?,
	resultMessage: string?,
	isNight: boolean,
}

export type PlayerSnapshot = {
	role: RoleName,
	roleDisplayName: string,
	roleDescription: string,
	alive: boolean,
	isGhost: boolean,
	objectivesCompleted: number,
	evidenceCollected: number,
	hasVoted: boolean,
	voteTargetKey: string?,
	statusMessage: string,
}

return {}
