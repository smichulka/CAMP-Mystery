--!strict

local DEFAULT_SETTINGS = table.freeze({
	masterVolume = 1,
	musicVolume = 0.7,
	ambienceVolume = 0.8,
	effectsVolume = 0.9,
	uiVolume = 0.8,
	subtitles = true,
	reducedMotion = false,
	cameraShake = true,
	highContrastEvidence = false,
	mouseSensitivity = 1,
	controllerSensitivity = 1,
	sprintToggle = false,
	tutorialCompleted = false,
})

local REWARDS = table.freeze({
	participationXP = 50,
	participationTokens = 10,
	winXP = 40,
	winTokens = 8,
	survivalXP = 15,
	survivalTokens = 2,
	objectiveXP = 10,
	objectiveTokens = 2,
	evidenceXP = 15,
	evidenceTokens = 3,
	roleParticipationXP = 30,
	roleWinXP = 30,
	roleContributionXP = 5,
	maxRewardedObjectives = 5,
	maxRewardedEvidence = 5,
})

local function levelFromXP(xp: number): number
	local safeXP = math.max(0, math.floor(xp))
	local level = 1
	local remaining = safeXP
	while level < 100 do
		local required = 100 + (level - 1) * 50
		if remaining < required then
			break
		end
		remaining -= required
		level += 1
	end
	return level
end

local function roleLevelFromXP(xp: number): number
	local safeXP = math.max(0, math.floor(xp))
	local level = 1
	local remaining = safeXP
	while level < 25 do
		local required = 75 + (level - 1) * 35
		if remaining < required then
			break
		end
		remaining -= required
		level += 1
	end
	return level
end

return table.freeze({
	schemaVersion = 1,
	dataStoreName = "CAMP_Mystery_Profile_v1",
	testDataStorePrefix = "CAMP_Mystery_Profile_TEST_",
	maxDataStoreNameLength = 50,
	keyPrefix = "player:",
	autosaveSeconds = 75,
	shutdownSaveTimeoutSeconds = 25,
	maxRewardReceipts = 50,
	maxTotalXP = 2_000_000_000,
	maxCampTokens = 2_000_000_000,
	maxRoleMasteryXP = 2_000_000_000,
	maxUpgradeRank = 5,
	maxMapEntries = 128,
	maxIdentifierLength = 64,
	defaultSettings = DEFAULT_SETTINGS,
	rewards = REWARDS,
	storeRetry = table.freeze({
		maxAttempts = 4,
		baseDelaySeconds = 0.5,
		maxDelaySeconds = 4,
	}),
	levelFromXP = levelFromXP,
	roleLevelFromXP = roleLevelFromXP,
})
