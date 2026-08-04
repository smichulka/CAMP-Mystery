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

export type VoteRevealEntry = {
	voterId: string,
	targetId: string,
	voterName: string,
	targetName: string,
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
	votes: { VoteRevealEntry }?,
	culpritId: string?,
	monsterId: string?,
	victimName: string?,
	winner: WinnerName?,
	resultMessage: string?,
	isNight: boolean,
	dayOutcomes: DayOutcomeSnapshot?,
	-- Seeded round weather (WeatherConfig.WeatherId); nil before a round.
	weather: string?,
	campfireStage: string?,
	votingOpensAt: number?,
	discussionLog: { DiscussionEntry }?,
}

export type DiscussionEntry = {
	presenterName: string,
	itemName: string,
	at: number,
}

export type DayOutcomeSnapshot = {
	generator: boolean,
	firewood: boolean,
	supplies: boolean,
}

return {}
