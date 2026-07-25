--!strict

export type RoleName =
	"Camper"
	| "Medic"
	| "Trapper"
	| "Medium"
	| "Guard"
	| "Protector"
	| "Detective"
	| "Murderer"
	| "Spectator"

export type TeamName = "Campers" | "Murderer" | "Observers"
export type ControllerKind = "Human" | "Bot"
export type HealthState = "Healthy" | "Injured" | "Incapacitated" | "Dead"

export type HumanControllerMetadata = {
	kind: "Human",
	userId: number,
	connected: boolean,
}

export type BotControllerMetadata = {
	kind: "Bot",
	botId: string,
	profileId: string,
	difficulty: number,
	connected: boolean,
}

export type ControllerMetadata = HumanControllerMetadata | BotControllerMetadata

export type AbilityDefinition = {
	id: string,
	displayName: string,
	description: string,
	cooldownSeconds: number,
	maxUsesPerRound: number?,
}

export type RoleDefinition = {
	name: RoleName,
	displayName: string,
	description: string,
	team: TeamName,
	abilities: { AbilityDefinition },
}

export type EvidenceKnowledge = {
	evidenceId: string,
	displayName: string,
	confidence: number,
	isShared: boolean,
	learnedAt: number,
}

export type VoteState = {
	hasVoted: boolean,
	targetParticipantId: string?,
}

export type ParticipantState = {
	participantId: string,
	displayName: string,
	controller: ControllerMetadata,
	role: RoleName,
	team: TeamName,
	alive: boolean,
	isGhost: boolean,
	healthState: HealthState,
	health: number,
	maxHealth: number,
	injuryLevel: number,
	inventoryIds: { string },
	evidenceKnowledge: { [string]: EvidenceKnowledge },
	vote: VoteState,
	abilityUses: { [string]: number },
	abilityCooldownEndsAt: { [string]: number },
}

export type PublicParticipantSnapshot = {
	participantId: string,
	displayName: string,
	controllerKind: ControllerKind,
	isBot: boolean,
	connected: boolean,
	alive: boolean,
	isGhost: boolean,
	healthState: HealthState,
	health: number,
	maxHealth: number,
	injuryLevel: number,
}

export type PrivateParticipantSnapshot = {
	participantId: string,
	displayName: string,
	controllerKind: ControllerKind,
	isBot: boolean,
	connected: boolean,
	role: RoleName,
	roleDisplayName: string,
	roleDescription: string,
	team: TeamName,
	abilityIds: { string },
	alive: boolean,
	isGhost: boolean,
	healthState: HealthState,
	health: number,
	maxHealth: number,
	injuryLevel: number,
	inventoryIds: { string },
	inventoryCapacity: number,
	evidenceKnowledge: { EvidenceKnowledge },
	vote: VoteState,
}

export type RandomSource = {
	NextInteger: (self: RandomSource, minimum: number, maximum: number) -> number,
}

return table.freeze({
	MAX_INVENTORY_SLOTS = 15,
})
