--!strict

export type RoleMastery = {
	xp: number,
	level: number,
}

export type PlayerStats = {
	roundsPlayed: number,
	wins: number,
	camperWins: number,
	murdererWins: number,
	objectivesCompleted: number,
	evidenceCollected: number,
	survivals: number,
}

export type PlayerSettings = {
	masterVolume: number,
	musicVolume: number,
	ambienceVolume: number,
	effectsVolume: number,
	uiVolume: number,
	subtitles: boolean,
	reducedMotion: boolean,
	cameraShake: boolean,
	highContrastEvidence: boolean,
	mouseSensitivity: number,
	controllerSensitivity: number,
	sprintToggle: boolean,
}

export type PlayerProfile = {
	schemaVersion: number,
	totalXP: number,
	campTokens: number,
	roleMastery: { [string]: RoleMastery },
	upgrades: { [string]: { [string]: number } },
	ownedCosmetics: { [string]: boolean },
	equippedCosmetics: { [string]: string },
	stats: PlayerStats,
	settings: PlayerSettings,
	recentRewardReceipts: { string },
}

export type ProfileSnapshot = {
	isGuest: boolean,
	saveError: string?,
	profile: PlayerProfile,
}

export type RewardInput = {
	receiptId: string,
	roleId: string,
	participated: boolean,
	won: boolean,
	survived: boolean,
	objectivesCompleted: number,
	evidenceCollected: number,
}

export type RewardGrant = {
	receiptId: string,
	roleId: string,
	xp: number,
	campTokens: number,
	roleMasteryXP: number,
	roundsPlayed: number,
	wins: number,
	camperWins: number,
	murdererWins: number,
	objectivesCompleted: number,
	evidenceCollected: number,
	survivals: number,
}

export type RewardResult = {
	applied: boolean,
	duplicate: boolean,
	reason: string?,
	grant: RewardGrant?,
	snapshot: ProfileSnapshot?,
}

export type ProfileMutationResult = {
	applied: boolean,
	reason: string?,
	snapshot: ProfileSnapshot?,
}

return {}
