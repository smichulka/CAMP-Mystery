--!strict

export type MonsterId =
	"BabyAlien"
	| "Screamer"
	| "Wendigo"
	| "ShadowMonster"
	| "Chupacabra"
	| "Dullahan"
	| "Entity"
	| "Banshee"

export type MonsterLifecycleState =
	"Inactive" | "Selected" | "Planning" | "Active" | "Stopped"

export type MonsterParticipantId = string

export type EvidenceId =
	"TinyTracks"
	| "AcidicResidue"
	| "LaserMotion"
	| "CorruptedAudio"
	| "EMFSpike"
	| "DeviceInterference"
	| "AntlerScrape"
	| "MimicRecording"
	| "FreezingTrace"
	| "PhotoSilhouette"
	| "LightDrain"
	| "BlackResidue"
	| "BloodTrail"
	| "ClawMarks"
	| "UVResidue"
	| "FreezingTemperature"
	| "HeadlessPhotograph"
	| "LaserSilhouette"
	| "SpiritBoxResponse"
	| "Handprint"
	| "RecordedWail"
	| "ReflectionApparition"
	| "DeathMark"

export type MonsterStatusId =
	"Bleeding"
	| "Disoriented"
	| "EquipmentDisabled"
	| "Fear"
	| "Latched"
	| "Marked"
	| "Slowed"
	| "VisionDistortion"

export type MovementPresentation = {
	style: string,
	speed: string,
	special: string,
}

export type CounterplayPresentation = {
	summary: string,
	recommendedEquipment: { string },
}

export type PublicMonsterDefinition = {
	id: MonsterId,
	displayName: string,
	description: string,
	movement: MovementPresentation,
	evidencePresentation: { string },
	counterplay: CounterplayPresentation,
}

export type AbilityRequest = {
	roundId: number,
	participantId: MonsterParticipantId,
	abilityId: string,
	targetParticipantId: MonsterParticipantId?,
	targetPosition: Vector3?,
	requestSequence: number,
}

export type ActivationCheck = {
	allowed: boolean,
	reason: string?,
	serverNow: number,
}

export type AbilityActivationResult = {
	accepted: boolean,
	reason: string?,
	roundId: number,
	revision: number,
	abilityId: string,
	staminaRemaining: number,
	cooldownEndsAt: number?,
}

export type MonsterPublicSnapshot = {
	roundId: number,
	revision: number,
	lifecycle: MonsterLifecycleState,
	active: boolean,
	monsterId: MonsterId?,
	participantId: MonsterParticipantId?,
}

export type MonsterPrivateSnapshot = {
	roundId: number,
	revision: number,
	lifecycle: MonsterLifecycleState,
	active: boolean,
	monsterId: MonsterId?,
	participantId: MonsterParticipantId?,
	stamina: number,
	maxStamina: number,
	cooldownEndsAt: { [string]: number },
	evidenceProfile: { EvidenceId },
}

export type AttackEffect = {
	kind: "Attack",
	amount: number,
}

export type StatusEffect = {
	kind: "Status",
	statusId: MonsterStatusId,
	durationSeconds: number,
}

export type EvidenceEffect = {
	kind: "Evidence",
	evidenceId: EvidenceId,
}

export type MobilityEffect = {
	kind: "Mobility",
	movementId: string,
}

export type AbilityEffect = AttackEffect | StatusEffect | EvidenceEffect | MobilityEffect

export type AbilityRule = {
	id: string,
	displayName: string,
	cooldownSeconds: number,
	rangeStuds: number,
	staminaCost: number,
	requiresTarget: boolean,
	requiresLineOfSight: boolean,
	allowedPhases: { string },
	effects: { AbilityEffect },
}

export type PrivateMonsterRule = {
	id: MonsterId,
	maxStamina: number,
	evidenceProfile: { EvidenceId },
	abilities: { [string]: AbilityRule },
}

return {}
