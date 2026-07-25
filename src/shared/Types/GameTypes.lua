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

export type PhaseConfig = {
	name: PhaseName,
	displayName: string,
	durationSeconds: number,
}

export type RoundSnapshot = {
	roundNumber: number,
	phase: PhaseName,
	phaseDisplayName: string,
	phaseStartedAt: number,
	phaseEndsAt: number,
	serverNow: number,
}

return {}

