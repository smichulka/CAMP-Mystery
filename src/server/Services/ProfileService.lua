--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local configFolder = Shared:WaitForChild("Config")
local typesFolder = Shared:WaitForChild("Types")
local CosmeticCatalog = require(configFolder:WaitForChild("CosmeticCatalog"))
local MonsterOrder = require(configFolder:WaitForChild("MonsterOrder"))
local ProgressionConfig = require(configFolder:WaitForChild("ProgressionConfig"))
local RoleCatalog = require(configFolder:WaitForChild("RoleCatalog"))
local UpgradeCatalog = require(configFolder:WaitForChild("UpgradeCatalog"))
local Types = require(typesFolder:WaitForChild("ProfileTypes"))

local serverRoot = script.Parent.Parent
local adapters = serverRoot:WaitForChild("Adapters")
local systems = serverRoot:WaitForChild("Systems")
local MemoryProfileStore = require(adapters:WaitForChild("MemoryProfileStore"))
local RobloxProfileStore = require(adapters:WaitForChild("RobloxProfileStore"))
local RewardCalculation = require(systems:WaitForChild("RewardCalculation"))

type PlayerProfile = Types.PlayerProfile
type ProfileSnapshot = Types.ProfileSnapshot
type RewardInput = Types.RewardInput
type RewardGrant = Types.RewardGrant
type RewardResult = Types.RewardResult
type ProfileMutationResult = Types.ProfileMutationResult
type ProfileMutation = (profile: PlayerProfile) -> (boolean, string?)

type ProfileStore = {
	LoadAsync: (self: any, key: string) -> (boolean, unknown?, string?),
	UpdateAsync: (
		self: any,
		key: string,
		transform: (unknown?) -> unknown?
	) -> (boolean, unknown?, string?),
}

type ProfileState = {
	profile: PlayerProfile,
	isGuest: boolean,
	dirty: boolean,
	busy: boolean,
	saveError: string?,
}

type ProfileServiceState = {
	store: ProfileStore,
	storeKind: "Memory" | "Roblox" | "Injected",
	profiles: { [number]: ProfileState },
	running: boolean,
	connections: { RBXScriptConnection },
}

local ProfileService = {}
ProfileService.__index = ProfileService

export type ProfileService = typeof(setmetatable({} :: ProfileServiceState, ProfileService))

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[deepCopy(key)] = deepCopy(child)
	end
	return result
end

local function finiteNumber(value: unknown, fallback: number): number
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return value
end

local function safeInteger(value: unknown, minimum: number, maximum: number): number
	return math.clamp(math.floor(finiteNumber(value, minimum)), minimum, maximum)
end

local function safeUnit(value: unknown, fallback: number): number
	return math.clamp(finiteNumber(value, fallback), 0, 1)
end

local function safeSensitivity(value: unknown, fallback: number): number
	return math.clamp(finiteNumber(value, fallback), 0.1, 3)
end

local function safeBoolean(value: unknown, fallback: boolean): boolean
	if typeof(value) == "boolean" then
		return value
	end
	return fallback
end

local function safeIdentifier(value: unknown): string?
	if typeof(value) ~= "string" then
		return nil
	end
	if #value < 1 or #value > ProgressionConfig.maxIdentifierLength then
		return nil
	end
	if not string.match(value, "^[%w%-%_:]+$") then
		return nil
	end
	return value
end

local progressionRoleIds: { [string]: boolean } = {}
for _, role in RoleCatalog.GetAll() do
	if role.name ~= "Spectator" then
		progressionRoleIds[role.name] = true
	end
end

local function isProgressionRole(roleId: string): boolean
	return progressionRoleIds[roleId] == true
end

local codexMonsterIds: { [string]: boolean } = {}
for _, monsterId in MonsterOrder do
	codexMonsterIds[monsterId] = true
end

local function isCodexMonster(monsterId: string): boolean
	return codexMonsterIds[monsterId] == true
end

local function defaultProfile(): PlayerProfile
	local ownedCosmetics: { [string]: boolean } = {}
	for _, cosmeticId in CosmeticCatalog.defaultIds do
		ownedCosmetics[cosmeticId] = true
	end

	return {
		schemaVersion = ProgressionConfig.schemaVersion,
		totalXP = 0,
		campTokens = 0,
		roleMastery = {},
		upgrades = {},
		ownedCosmetics = ownedCosmetics,
		equippedCosmetics = deepCopy(CosmeticCatalog.defaultEquipped),
		stats = {
			roundsPlayed = 0,
			wins = 0,
			camperWins = 0,
			murdererWins = 0,
			objectivesCompleted = 0,
			evidenceCollected = 0,
			survivals = 0,
		},
		monsterStats = {},
		settings = deepCopy(ProgressionConfig.defaultSettings),
		recentRewardReceipts = {},
		streakLastDay = 0,
		streakCount = 0,
	}
end

-- UTC day index, identical on every server, so a streak never depends on
-- which server the player happens to land on.
local function currentUtcDay(): number
	return math.floor(os.time() / 86400)
end

-- What the player's streak becomes if a rewarded round lands today: same-day
-- play keeps it, consecutive-day play extends it, a gap resets it to 1.
local function advancedStreak(profile: PlayerProfile): number
	local today = currentUtcDay()
	if profile.streakLastDay == today then
		return math.max(profile.streakCount, 1)
	elseif profile.streakLastDay == today - 1 then
		return profile.streakCount + 1
	end
	return 1
end

local function sanitizeStringMap(source: unknown): { [string]: boolean }
	local result: { [string]: boolean } = {}
	if typeof(source) ~= "table" then
		return result
	end

	local count = 0
	for rawId, rawOwned in source :: any do
		local id = safeIdentifier(rawId)
		if id and rawOwned == true and CosmeticCatalog.byId[id] and count < ProgressionConfig.maxMapEntries then
			result[id] = true
			count += 1
		end
	end
	return result
end

local function sanitizeProfile(rawValue: unknown): (PlayerProfile?, string?)
	if rawValue == nil then
		return defaultProfile(), nil
	end
	if typeof(rawValue) ~= "table" then
		return defaultProfile(), nil
	end

	local raw = rawValue :: any
	local rawVersion = safeInteger(raw.schemaVersion, 0, 1_000_000)
	if rawVersion > ProgressionConfig.schemaVersion then
		return nil, string.format(
			"Profile schema %d is newer than supported schema %d",
			rawVersion,
			ProgressionConfig.schemaVersion
		)
	end

	-- Schema 0 had no formal contract. Its recognized fields are carried into v1;
	-- all missing or invalid fields are replaced with safe v1 defaults below.
	local profile = defaultProfile()
	profile.totalXP = safeInteger(raw.totalXP, 0, ProgressionConfig.maxTotalXP)
	profile.campTokens = safeInteger(
		raw.campTokens,
		0,
		ProgressionConfig.maxCampTokens
	)
	-- Daily streak (additive v1 fields): absent or invalid values read as 0,
	-- which advancedStreak treats as "no streak yet".
	profile.streakLastDay = safeInteger(raw.streakLastDay, 0, 100_000_000)
	profile.streakCount = safeInteger(raw.streakCount, 0, 1_000_000)

	if typeof(raw.roleMastery) == "table" then
		local count = 0
		for rawRoleId, rawMastery in raw.roleMastery do
			local roleId = safeIdentifier(rawRoleId)
			if roleId
				and isProgressionRole(roleId)
				and typeof(rawMastery) == "table"
				and count < ProgressionConfig.maxMapEntries
			then
				local masteryXP = safeInteger(
					rawMastery.xp,
					0,
					ProgressionConfig.maxRoleMasteryXP
				)
				profile.roleMastery[roleId] = {
					xp = masteryXP,
					level = ProgressionConfig.roleLevelFromXP(masteryXP),
				}
				count += 1
			end
		end
	end

	if typeof(raw.upgrades) == "table" then
		local roleCount = 0
		for rawRoleId, rawUpgrades in raw.upgrades do
			local roleId = safeIdentifier(rawRoleId)
			if roleId
				and isProgressionRole(roleId)
				and typeof(rawUpgrades) == "table"
				and roleCount < ProgressionConfig.maxMapEntries
			then
				local roleUpgrades: { [string]: number } = {}
				local upgradeCount = 0
				for rawUpgradeId, rawRank in rawUpgrades do
					local upgradeId = safeIdentifier(rawUpgradeId)
					local definition = if upgradeId
						then UpgradeCatalog.get(roleId, upgradeId)
						else nil
					if definition and upgradeCount < ProgressionConfig.maxMapEntries then
						local resolvedUpgradeId = upgradeId :: string
						roleUpgrades[resolvedUpgradeId] = safeInteger(
							rawRank,
							0,
							math.min(ProgressionConfig.maxUpgradeRank, definition.maxRank)
						)
						upgradeCount += 1
					end
				end
				profile.upgrades[roleId] = roleUpgrades
				roleCount += 1
			end
		end
	end

	local ownedCosmetics = sanitizeStringMap(raw.ownedCosmetics)
	for _, defaultId in CosmeticCatalog.defaultIds do
		ownedCosmetics[defaultId] = true
	end
	profile.ownedCosmetics = ownedCosmetics

	if typeof(raw.equippedCosmetics) == "table" then
		for rawCategory, rawCosmeticId in raw.equippedCosmetics do
			if typeof(rawCategory) == "string" and typeof(rawCosmeticId) == "string" then
				local definition = CosmeticCatalog.byId[rawCosmeticId]
				if definition
					and definition.category == rawCategory
					and profile.ownedCosmetics[rawCosmeticId]
				then
					profile.equippedCosmetics[rawCategory] = rawCosmeticId
				end
			end
		end
	end

	if typeof(raw.stats) == "table" then
		profile.stats.roundsPlayed = safeInteger(raw.stats.roundsPlayed, 0, 2_000_000_000)
		profile.stats.wins = safeInteger(raw.stats.wins, 0, 2_000_000_000)
		profile.stats.camperWins = safeInteger(raw.stats.camperWins, 0, 2_000_000_000)
		profile.stats.murdererWins = safeInteger(raw.stats.murdererWins, 0, 2_000_000_000)
		profile.stats.objectivesCompleted =
			safeInteger(raw.stats.objectivesCompleted, 0, 2_000_000_000)
		profile.stats.evidenceCollected =
			safeInteger(raw.stats.evidenceCollected, 0, 2_000_000_000)
		profile.stats.survivals = safeInteger(raw.stats.survivals, 0, 2_000_000_000)
	end

	if typeof(raw.monsterStats) == "table" then
		local count = 0
		for rawMonsterId, rawRecord in raw.monsterStats do
			local monsterId = safeIdentifier(rawMonsterId)
			if monsterId
				and isCodexMonster(monsterId)
				and typeof(rawRecord) == "table"
				and count < ProgressionConfig.maxMapEntries
			then
				profile.monsterStats[monsterId] = {
					encounters = safeInteger(rawRecord.encounters, 0, 2_000_000_000),
					survivals = safeInteger(rawRecord.survivals, 0, 2_000_000_000),
					identifications =
						safeInteger(rawRecord.identifications, 0, 2_000_000_000),
				}
				count += 1
			end
		end
	end

	local defaults = ProgressionConfig.defaultSettings
	if typeof(raw.settings) == "table" then
		profile.settings.masterVolume =
			safeUnit(raw.settings.masterVolume, defaults.masterVolume)
		profile.settings.musicVolume =
			safeUnit(raw.settings.musicVolume, defaults.musicVolume)
		profile.settings.ambienceVolume =
			safeUnit(raw.settings.ambienceVolume, defaults.ambienceVolume)
		profile.settings.effectsVolume =
			safeUnit(raw.settings.effectsVolume, defaults.effectsVolume)
		profile.settings.uiVolume = safeUnit(raw.settings.uiVolume, defaults.uiVolume)
		profile.settings.subtitles =
			safeBoolean(raw.settings.subtitles, defaults.subtitles)
		profile.settings.reducedMotion =
			safeBoolean(raw.settings.reducedMotion, defaults.reducedMotion)
		profile.settings.cameraShake =
			safeBoolean(raw.settings.cameraShake, defaults.cameraShake)
		profile.settings.highContrastEvidence = safeBoolean(
			raw.settings.highContrastEvidence,
			defaults.highContrastEvidence
		)
		profile.settings.mouseSensitivity = safeSensitivity(
			raw.settings.mouseSensitivity,
			defaults.mouseSensitivity
		)
		profile.settings.controllerSensitivity = safeSensitivity(
			raw.settings.controllerSensitivity,
			defaults.controllerSensitivity
		)
		profile.settings.sprintToggle =
			safeBoolean(raw.settings.sprintToggle, defaults.sprintToggle)
		profile.settings.tutorialCompleted =
			safeBoolean(raw.settings.tutorialCompleted, defaults.tutorialCompleted)
		profile.settings.autoEnroll =
			safeBoolean(raw.settings.autoEnroll, defaults.autoEnroll)
		profile.settings.preferQuickCamp =
			safeBoolean(raw.settings.preferQuickCamp, defaults.preferQuickCamp)
	end

	local receiptSet: { [string]: boolean } = {}
	if typeof(raw.recentRewardReceipts) == "table" then
		local startIndex = math.max(
			1,
			#raw.recentRewardReceipts - ProgressionConfig.maxRewardReceipts + 1
		)
		for index = startIndex, #raw.recentRewardReceipts do
			local receiptId = safeIdentifier(raw.recentRewardReceipts[index])
			if receiptId and not receiptSet[receiptId] then
				table.insert(profile.recentRewardReceipts, receiptId)
				receiptSet[receiptId] = true
			end
		end
	end

	return profile, nil
end

local function hasReceipt(profile: PlayerProfile, receiptId: string): boolean
	for _, existing in profile.recentRewardReceipts do
		if existing == receiptId then
			return true
		end
	end
	return false
end

local function addClamped(left: number, right: number, maximum: number): number
	return math.clamp(left + right, 0, maximum)
end

local function applyGrant(profile: PlayerProfile, grant: RewardGrant)
	profile.totalXP = addClamped(
		profile.totalXP,
		grant.xp,
		ProgressionConfig.maxTotalXP
	)
	profile.campTokens = addClamped(
		profile.campTokens,
		grant.campTokens,
		ProgressionConfig.maxCampTokens
	)

	local mastery = profile.roleMastery[grant.roleId] or { xp = 0, level = 1 }
	mastery.xp = addClamped(
		mastery.xp,
		grant.roleMasteryXP,
		ProgressionConfig.maxRoleMasteryXP
	)
	mastery.level = ProgressionConfig.roleLevelFromXP(mastery.xp)
	profile.roleMastery[grant.roleId] = mastery

	local stats = profile.stats
	stats.roundsPlayed = addClamped(stats.roundsPlayed, grant.roundsPlayed, 2_000_000_000)
	stats.wins = addClamped(stats.wins, grant.wins, 2_000_000_000)
	stats.camperWins = addClamped(stats.camperWins, grant.camperWins, 2_000_000_000)
	stats.murdererWins =
		addClamped(stats.murdererWins, grant.murdererWins, 2_000_000_000)
	stats.objectivesCompleted = addClamped(
		stats.objectivesCompleted,
		grant.objectivesCompleted,
		2_000_000_000
	)
	stats.evidenceCollected = addClamped(
		stats.evidenceCollected,
		grant.evidenceCollected,
		2_000_000_000
	)
	stats.survivals = addClamped(stats.survivals, grant.survivals, 2_000_000_000)

	-- A rewarded round played today advances the daily streak. Computed
	-- against the profile being mutated (inside the UpdateAsync transform),
	-- so server-hopping around midnight cannot double-advance it.
	if grant.roundsPlayed > 0 then
		profile.streakCount = advancedStreak(profile)
		profile.streakLastDay = currentUtcDay()
	end

	local monsterId = grant.monsterId
	if monsterId then
		local record = profile.monsterStats[monsterId]
			or { encounters = 0, survivals = 0, identifications = 0 }
		record.encounters =
			addClamped(record.encounters, grant.monsterEncounter, 2_000_000_000)
		record.survivals =
			addClamped(record.survivals, grant.monsterSurvival, 2_000_000_000)
		record.identifications =
			addClamped(record.identifications, grant.monsterIdentification, 2_000_000_000)
		profile.monsterStats[monsterId] = record
	end

	table.insert(profile.recentRewardReceipts, grant.receiptId)
	while #profile.recentRewardReceipts > ProgressionConfig.maxRewardReceipts do
		table.remove(profile.recentRewardReceipts, 1)
	end
end

local function grantEligibleCosmetics(profile: PlayerProfile)
	local accountLevel = ProgressionConfig.levelFromXP(profile.totalXP)
	for _, definition in CosmeticCatalog.definitions do
		if definition.unlockKind == "Default"
			or (
				definition.unlockKind == "Level"
				and accountLevel >= definition.unlockAmount
			)
			or (
				definition.unlockKind == "Streak"
				and profile.streakCount >= definition.unlockAmount
			)
		then
			profile.ownedCosmetics[definition.id] = true
		end
	end
end

local function keyForUserId(userId: number): string
	return ProgressionConfig.keyPrefix .. tostring(userId)
end

function ProfileService.new(store: ProfileStore?): ProfileService
	local configuredStore = store
	local storeKind: "Memory" | "Roblox" | "Injected" = "Injected"
	if not configuredStore then
		if RunService:IsStudio() then
			configuredStore = MemoryProfileStore.new()
			storeKind = "Memory"
		else
			local retry = ProgressionConfig.storeRetry
			configuredStore = RobloxProfileStore.new(ProgressionConfig.dataStoreName, {
				maxAttempts = retry.maxAttempts,
				baseDelaySeconds = retry.baseDelaySeconds,
				maxDelaySeconds = retry.maxDelaySeconds,
			})
			storeKind = "Roblox"
		end
	end

	return setmetatable({
		store = configuredStore :: ProfileStore,
		storeKind = storeKind,
		profiles = {},
		running = false,
		connections = {},
	}, ProfileService)
end

function ProfileService:_Snapshot(state: ProfileState): ProfileSnapshot
	return {
		isGuest = state.isGuest,
		saveError = state.saveError,
		profile = deepCopy(state.profile),
	}
end

function ProfileService:GetStoreKind(): "Memory" | "Roblox" | "Injected"
	return self.storeKind
end

function ProfileService:GetSnapshot(player: Player): ProfileSnapshot?
	local state = self.profiles[player.UserId]
	if not state then
		return nil
	end
	return self:_Snapshot(state)
end

function ProfileService:IsGuest(player: Player): boolean
	local state = self.profiles[player.UserId]
	return state == nil or state.isGuest
end

function ProfileService:IsLoaded(player: Player): boolean
	return self.profiles[player.UserId] ~= nil
end

function ProfileService:LoadPlayer(player: Player): ProfileSnapshot
	local existing = self.profiles[player.UserId]
	if existing then
		return self:_Snapshot(existing)
	end

	local success, rawValue, loadError =
		self.store:LoadAsync(keyForUserId(player.UserId))
	-- LoadAsync yields (with retries) — re-check the world before caching:
	-- if the player left, caching would leak an entry no PlayerRemoving will
	-- ever release (and a failed load would strand them in guest mode on
	-- rejoin); if a concurrent load already cached a state, keep that one.
	local playerStillHere = Players:GetPlayerByUserId(player.UserId) == player
		and player.Parent ~= nil
	local concurrent = self.profiles[player.UserId]
	if concurrent then
		return self:_Snapshot(concurrent)
	end
	local profile: PlayerProfile?
	local migrationError: string?
	if success then
		profile, migrationError = sanitizeProfile(rawValue)
	end

	if not success or not profile then
		local reason = loadError or migrationError or "Profile load failed"
		local guestState: ProfileState = {
			profile = defaultProfile(),
			isGuest = true,
			dirty = false,
			busy = false,
			saveError = reason,
		}
		if playerStillHere then
			self.profiles[player.UserId] = guestState
		end
		warn(
			string.format(
				"[ProfileService] %s entered guest mode: %s",
				player.Name,
				reason
			)
		)
		return self:_Snapshot(guestState)
	end

	local state: ProfileState = {
		profile = profile,
		isGuest = false,
		dirty = rawValue == nil
			or typeof(rawValue) ~= "table"
			or rawValue.schemaVersion ~= ProgressionConfig.schemaVersion,
		busy = false,
		saveError = nil,
	}
	if playerStillHere then
		self.profiles[player.UserId] = state
	end
	return self:_Snapshot(state)
end

function ProfileService:_WaitForAccess(state: ProfileState): boolean
	local deadline = os.clock() + 10
	while state.busy and os.clock() < deadline do
		task.wait(0.05)
	end
	if state.busy then
		state.saveError = "Profile operation timed out"
		return false
	end
	state.busy = true
	return true
end

function ProfileService:SavePlayer(player: Player): (boolean, string?)
	local state = self.profiles[player.UserId]
	if not state then
		return false, "ProfileNotLoaded"
	end
	if state.isGuest then
		return false, "GuestMode"
	end
	if not state.dirty then
		return true, nil
	end
	if not self:_WaitForAccess(state) then
		return false, state.saveError
	end

	local cached = deepCopy(state.profile)
	local success, storedValue, saveError = self.store:UpdateAsync(
		keyForUserId(player.UserId),
		function(currentValue: unknown?)
			if currentValue == nil then
				return cached
			end
			-- Dirty saves are currently schema migration/default-profile flushes.
			-- Re-sanitize the value observed by UpdateAsync instead of overwriting
			-- progress that a newer server may already have committed.
			local current, validationError = sanitizeProfile(currentValue)
			if not current then
				error(validationError or "Stored profile could not be validated")
			end
			return current
		end
	)
	state.busy = false

	if not success then
		state.saveError = saveError or "Profile save failed"
		return false, state.saveError
	end

	local stored, validationError = sanitizeProfile(storedValue)
	if not stored then
		state.saveError = validationError or "Saved profile could not be validated"
		return false, state.saveError
	end
	state.profile = stored
	state.dirty = false
	state.saveError = nil
	return true, nil
end

function ProfileService:_MutateProfile(
	player: Player,
	mutation: ProfileMutation
): ProfileMutationResult
	local state = self.profiles[player.UserId]
	if not state then
		return {
			applied = false,
			reason = "ProfileNotLoaded",
			snapshot = nil,
		}
	end
	if state.isGuest then
		return {
			applied = false,
			reason = "GuestMode",
			snapshot = self:_Snapshot(state),
		}
	end
	if not self:_WaitForAccess(state) then
		return {
			applied = false,
			reason = state.saveError,
			snapshot = self:_Snapshot(state),
		}
	end

	local applied = false
	local mutationReason: string? = nil
	local success, storedValue, saveError = self.store:UpdateAsync(
		keyForUserId(player.UserId),
		function(currentValue: unknown?)
			local current, validationError = sanitizeProfile(currentValue)
			if not current then
				error(validationError or "Stored profile could not be validated")
			end
			local didApply, reason = mutation(current)
			applied = didApply
			mutationReason = reason
			return current
		end
	)
	state.busy = false
	if not success then
		state.saveError = saveError or "Profile mutation failed"
		return {
			applied = false,
			reason = state.saveError,
			snapshot = self:_Snapshot(state),
		}
	end

	local stored, validationError = sanitizeProfile(storedValue)
	if not stored then
		state.saveError = validationError or "Mutated profile could not be validated"
		return {
			applied = false,
			reason = state.saveError,
			snapshot = self:_Snapshot(state),
		}
	end
	state.profile = stored
	state.dirty = false
	state.saveError = nil
	return {
		applied = applied,
		reason = mutationReason,
		snapshot = self:_Snapshot(state),
	}
end

function ProfileService:UpdateSettings(
	player: Player,
	patch: { [string]: unknown }
): ProfileMutationResult
	return self:_MutateProfile(player, function(profile: PlayerProfile): (boolean, string?)
		local changed = false
		local recognized = false
		for key, value in patch do
			if key == "masterVolume" and typeof(value) == "number" then
				recognized = true
				local resolved = safeUnit(value, profile.settings.masterVolume)
				changed = changed or resolved ~= profile.settings.masterVolume
				profile.settings.masterVolume = resolved
			elseif key == "musicVolume" and typeof(value) == "number" then
				recognized = true
				local resolved = safeUnit(value, profile.settings.musicVolume)
				changed = changed or resolved ~= profile.settings.musicVolume
				profile.settings.musicVolume = resolved
			elseif key == "ambienceVolume" and typeof(value) == "number" then
				recognized = true
				local resolved = safeUnit(value, profile.settings.ambienceVolume)
				changed = changed or resolved ~= profile.settings.ambienceVolume
				profile.settings.ambienceVolume = resolved
			elseif key == "effectsVolume" and typeof(value) == "number" then
				recognized = true
				local resolved = safeUnit(value, profile.settings.effectsVolume)
				changed = changed or resolved ~= profile.settings.effectsVolume
				profile.settings.effectsVolume = resolved
			elseif key == "uiVolume" and typeof(value) == "number" then
				recognized = true
				local resolved = safeUnit(value, profile.settings.uiVolume)
				changed = changed or resolved ~= profile.settings.uiVolume
				profile.settings.uiVolume = resolved
			elseif key == "mouseSensitivity" and typeof(value) == "number" then
				recognized = true
				local resolved = safeSensitivity(value, profile.settings.mouseSensitivity)
				changed = changed or resolved ~= profile.settings.mouseSensitivity
				profile.settings.mouseSensitivity = resolved
			elseif key == "controllerSensitivity" and typeof(value) == "number" then
				recognized = true
				local resolved = safeSensitivity(value, profile.settings.controllerSensitivity)
				changed = changed or resolved ~= profile.settings.controllerSensitivity
				profile.settings.controllerSensitivity = resolved
			elseif key == "subtitles" and typeof(value) == "boolean" then
				recognized = true
				changed = changed or value ~= profile.settings.subtitles
				profile.settings.subtitles = value
			elseif key == "reducedMotion" and typeof(value) == "boolean" then
				recognized = true
				changed = changed or value ~= profile.settings.reducedMotion
				profile.settings.reducedMotion = value
			elseif key == "cameraShake" and typeof(value) == "boolean" then
				recognized = true
				changed = changed or value ~= profile.settings.cameraShake
				profile.settings.cameraShake = value
			elseif key == "highContrastEvidence" and typeof(value) == "boolean" then
				recognized = true
				changed = changed or value ~= profile.settings.highContrastEvidence
				profile.settings.highContrastEvidence = value
			elseif key == "sprintToggle" and typeof(value) == "boolean" then
				recognized = true
				changed = changed or value ~= profile.settings.sprintToggle
				profile.settings.sprintToggle = value
			elseif key == "tutorialCompleted" and typeof(value) == "boolean" then
				recognized = true
				changed = changed or value ~= profile.settings.tutorialCompleted
				profile.settings.tutorialCompleted = value
			elseif key == "autoEnroll" and typeof(value) == "boolean" then
				recognized = true
				changed = changed or value ~= profile.settings.autoEnroll
				profile.settings.autoEnroll = value
			elseif key == "preferQuickCamp" and typeof(value) == "boolean" then
				recognized = true
				changed = changed or value ~= profile.settings.preferQuickCamp
				profile.settings.preferQuickCamp = value
			end
		end
		if not recognized then
			return false, "NoValidSettings"
		end
		return changed, if changed then nil else "NoChange"
	end)
end

function ProfileService:PurchaseUpgrade(
	player: Player,
	roleId: string,
	upgradeId: string
): ProfileMutationResult
	local safeRoleId = safeIdentifier(roleId)
	local safeUpgradeId = safeIdentifier(upgradeId)
	local definition = if safeRoleId and safeUpgradeId
		then UpgradeCatalog.get(safeRoleId, safeUpgradeId)
		else nil
	if not definition then
		return {
			applied = false,
			reason = "UnknownUpgrade",
			snapshot = self:GetSnapshot(player),
		}
	end

	return self:_MutateProfile(player, function(profile: PlayerProfile): (boolean, string?)
		local roleMastery = profile.roleMastery[definition.roleId] or { xp = 0, level = 1 }
		if roleMastery.level < definition.requiredMasteryLevel then
			return false, "MasteryLevelRequired"
		end
		local roleUpgrades = profile.upgrades[definition.roleId]
		if not roleUpgrades then
			roleUpgrades = {}
			profile.upgrades[definition.roleId] = roleUpgrades
		end
		local currentRank = roleUpgrades[definition.id] or 0
		if currentRank >= definition.maxRank then
			return false, "UpgradeCapped"
		end
		local cost = UpgradeCatalog.nextRankCost(definition, currentRank)
		if profile.campTokens < cost then
			return false, "NotEnoughCampTokens"
		end
		profile.campTokens -= cost
		roleUpgrades[definition.id] = currentRank + 1
		return true, nil
	end)
end

function ProfileService:GetUpgradeRank(
	player: Player,
	roleId: string,
	upgradeId: string
): number
	local state = self.profiles[player.UserId]
	if not state then
		return 0
	end
	local roleUpgrades = state.profile.upgrades[roleId]
	return if roleUpgrades then roleUpgrades[upgradeId] or 0 else 0
end

function ProfileService:UnlockCosmetic(
	player: Player,
	cosmeticId: string
): ProfileMutationResult
	local id = safeIdentifier(cosmeticId)
	local definition = if id then CosmeticCatalog.byId[id] else nil
	if not definition then
		return {
			applied = false,
			reason = "UnknownCosmetic",
			snapshot = self:GetSnapshot(player),
		}
	end
	return self:_MutateProfile(player, function(profile: PlayerProfile): (boolean, string?)
		if profile.ownedCosmetics[definition.id] then
			return false, "AlreadyOwned"
		end
		if definition.unlockKind == "Level" then
			if ProgressionConfig.levelFromXP(profile.totalXP) < definition.unlockAmount then
				return false, "AccountLevelRequired"
			end
		elseif definition.unlockKind == "Streak" then
			-- Earned by returning daily, never purchasable.
			if profile.streakCount < definition.unlockAmount then
				return false, "StreakRequired"
			end
		elseif definition.unlockKind == "CampTokens" then
			local price = CosmeticCatalog.GetTokenPrice(
				definition,
				ProgressionConfig.featuredTokenDiscount
			)
			if profile.campTokens < price then
				return false, "NotEnoughCampTokens"
			end
			profile.campTokens -= price
		end
		profile.ownedCosmetics[definition.id] = true
		return true, nil
	end)
end

function ProfileService:EquipCosmetic(
	player: Player,
	cosmeticId: string
): ProfileMutationResult
	local id = safeIdentifier(cosmeticId)
	local definition = if id then CosmeticCatalog.byId[id] else nil
	if not definition then
		return {
			applied = false,
			reason = "UnknownCosmetic",
			snapshot = self:GetSnapshot(player),
		}
	end
	return self:_MutateProfile(player, function(profile: PlayerProfile): (boolean, string?)
		if not profile.ownedCosmetics[definition.id] then
			return false, "CosmeticNotOwned"
		end
		if profile.equippedCosmetics[definition.category] == definition.id then
			return false, "AlreadyEquipped"
		end
		profile.equippedCosmetics[definition.category] = definition.id
		return true, nil
	end)
end

function ProfileService:ReleasePlayer(player: Player): (boolean, string?)
	local state = self.profiles[player.UserId]
	if not state then
		return true, nil
	end
	local saved, reason = self:SavePlayer(player)
	self.profiles[player.UserId] = nil
	return saved, reason
end

function ProfileService:ApplyReward(
	player: Player,
	input: RewardInput
): RewardResult
	local state = self.profiles[player.UserId]
	if not state then
		return {
			applied = false,
			duplicate = false,
			reason = "ProfileNotLoaded",
			grant = nil,
			snapshot = nil,
		}
	end
	if state.isGuest then
		return {
			applied = false,
			duplicate = false,
			reason = "GuestMode",
			grant = nil,
			snapshot = self:_Snapshot(state),
		}
	end

	local receiptId = safeIdentifier(input.receiptId)
	local roleId = safeIdentifier(input.roleId)
	if not receiptId or not roleId or not isProgressionRole(roleId) then
		return {
			applied = false,
			duplicate = false,
			reason = "InvalidRewardIdentity",
			grant = nil,
			snapshot = self:_Snapshot(state),
		}
	end

	if hasReceipt(state.profile, receiptId) then
		return {
			applied = false,
			duplicate = true,
			reason = nil,
			grant = nil,
			snapshot = self:_Snapshot(state),
		}
	end
	if not self:_WaitForAccess(state) then
		return {
			applied = false,
			duplicate = false,
			reason = state.saveError,
			grant = nil,
			snapshot = self:_Snapshot(state),
		}
	end

	local rawMonsterId = safeIdentifier(input.monsterId)
	local normalizedInput: RewardInput = {
		receiptId = receiptId,
		roleId = roleId,
		participated = input.participated == true,
		won = input.won == true,
		survived = input.survived == true,
		objectivesCompleted = finiteNumber(input.objectivesCompleted, 0),
		evidenceCollected = finiteNumber(input.evidenceCollected, 0),
		monsterId = if rawMonsterId and isCodexMonster(rawMonsterId)
			then rawMonsterId
			else nil,
		identifiedMonster = input.identifiedMonster == true,
		checkIns = finiteNumber(input.checkIns, 0),
		-- These two were dropped by normalization for a while, silently
		-- zeroing the night side-objective and ghost-objective payouts the
		-- calculator supports — keep them when touching this list.
		sideObjectives = finiteNumber(input.sideObjectives, 0),
		ghostObjectives = finiteNumber(input.ghostObjectives, 0),
		rewardMultiplier = finiteNumber(input.rewardMultiplier, 1),
		coldCasesReviewed = finiteNumber(input.coldCasesReviewed, 0),
		-- Server-authoritative: derived from the stored profile, never from
		-- the caller. Slight staleness across a midnight server-hop only
		-- shifts the bonus by one step; the transform below is what persists.
		dailyStreakCount = advancedStreak(state.profile),
	}
	local grant = RewardCalculation.Calculate(normalizedInput)
	local appliedByThisUpdate = false

	local success, storedValue, saveError = self.store:UpdateAsync(
		keyForUserId(player.UserId),
		function(currentValue: unknown?)
			local current, validationError = sanitizeProfile(currentValue)
			if not current then
				error(validationError or "Stored profile could not be validated")
			end
			if hasReceipt(current, receiptId) then
				appliedByThisUpdate = false
				return current
			end
			applyGrant(current, grant)
			grantEligibleCosmetics(current)
			appliedByThisUpdate = true
			return current
		end
	)
	state.busy = false

	if not success then
		state.saveError = saveError or "Reward save failed"
		return {
			applied = false,
			duplicate = false,
			reason = state.saveError,
			grant = nil,
			snapshot = self:_Snapshot(state),
		}
	end

	local stored, validationError = sanitizeProfile(storedValue)
	if not stored then
		state.saveError = validationError or "Rewarded profile could not be validated"
		return {
			applied = false,
			duplicate = false,
			reason = state.saveError,
			grant = nil,
			snapshot = self:_Snapshot(state),
		}
	end

	state.profile = stored
	state.dirty = false
	state.saveError = nil
	return {
		applied = appliedByThisUpdate,
		duplicate = not appliedByThisUpdate,
		reason = nil,
		grant = if appliedByThisUpdate then grant else nil,
		snapshot = self:_Snapshot(state),
	}
end

function ProfileService:Start()
	if self.running then
		return
	end
	self.running = true

	table.insert(self.connections, Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(function()
			self:LoadPlayer(player)
		end)
	end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player: Player)
		self:ReleasePlayer(player)
	end))

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:LoadPlayer(player)
		end)
	end

	task.spawn(function()
		while self.running do
			task.wait(ProgressionConfig.autosaveSeconds)
			if not self.running then
				break
			end
			for _, player in Players:GetPlayers() do
				task.spawn(function()
					self:SavePlayer(player)
				end)
			end
		end
	end)

end

function ProfileService:Stop()
	if not self.running then
		return
	end
	self.running = false
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)

	local remaining = 0
	for _, player in Players:GetPlayers() do
		if self.profiles[player.UserId] then
			remaining += 1
			task.spawn(function()
				local saved, reason = self:SavePlayer(player)
				if not saved and reason ~= "GuestMode" then
					warn(
						string.format(
							"[ProfileService] Shutdown save failed for user %d: %s",
							player.UserId,
							reason or "UnknownFailure"
						)
					)
				end
				remaining -= 1
			end)
		end
	end
	local deadline = os.clock() + ProgressionConfig.shutdownSaveTimeoutSeconds
	while remaining > 0 and os.clock() < deadline do
		task.wait(0.05)
	end
	if remaining > 0 then
		warn(
			string.format(
				"[ProfileService] %d profile save(s) exceeded the shutdown deadline",
				remaining
			)
		)
	end
end

return ProfileService
