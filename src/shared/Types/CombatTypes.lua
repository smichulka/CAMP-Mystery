--!strict

export type AttackSource =
	"MonsterAbility" | "MurderPlan" | "Trap" | "Environment"

export type DefenseResult = "None" | "Blocked" | "Reduced"
export type AttackOutcome = "Rejected" | "Blocked" | "Injured" | "Eliminated"

export type AttackRequest = {
	roundId: number,
	attackerParticipantId: string,
	targetParticipantId: string,
	source: AttackSource,
	abilityId: string?,
	position: Vector3?,
}

export type AttackResult = {
	accepted: boolean,
	outcome: AttackOutcome,
	reason: string?,
	targetParticipantId: string,
	injuryLevel: number,
	evidenceRisk: number,
}

export type CombatSnapshot = {
	roundId: number,
	revision: number,
	participantId: string,
	alive: boolean,
	isGhost: boolean,
	healthState: "Healthy" | "Injured" | "Incapacitated" | "Dead",
	injuryLevel: number,
	movementMultiplier: number,
}

return {}

