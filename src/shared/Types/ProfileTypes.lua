--!strict

export type RoleMastery = {
	xp: number,
	level: number,
}

-- Per-monster codex mastery counters. Incremented server-side on reward grant
-- after Investigation / round resolution (see ProfileService + CodexConfig).
export type MonsterStatRecord = {
	encounters: number,
	survivals: number,
	identifications: number,
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
	tutorialCompleted: boolean,
	-- Opt-in mystery: sign this player up for each night's round automatically.
	-- Additive field — absent sanitizes to false (must choose to opt in).
	autoEnroll: boolean,
	-- Prefer ~7 minute Quick Camp rounds when a majority of ready players agree.
	preferQuickCamp: boolean,
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
	monsterStats: { [string]: MonsterStatRecord },
	settings: PlayerSettings,
	recentRewardReceipts: { string },
	-- Daily play streak: last UTC day index a rewarded round was played, and
	-- the run of consecutive days ending on that day. Additive v1 fields —
	-- absent values sanitize to 0 (no streak).
	streakLastDay: number,
	streakCount: number,
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
	monsterId: string?,
	identifiedMonster: boolean?,
	checkIns: number?,
	sideObjectives: number?,
	ghostObjectives: number?,
	coldCasesReviewed: number?,
	-- Event bonus (e.g. Blood Moon weather); clamped in RewardCalculation.
	rewardMultiplier: number?,
	-- Server-injected by ProfileService from the stored profile — never
	-- trusted from callers. Day count of the player's current daily streak.
	dailyStreakCount: number?,
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
	monsterId: string?,
	monsterEncounter: number,
	monsterSurvival: number,
	monsterIdentification: number,
	-- Daily streak this grant was computed with (0 when not participating)
	-- and the bonus percent applied to xp/campTokens, for UI display.
	dailyStreak: number,
	streakBonusPercent: number,
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
