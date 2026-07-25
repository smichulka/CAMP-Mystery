--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local configFolder = Shared:WaitForChild("Config")
local typesFolder = Shared:WaitForChild("Types")
local CosmeticCatalog = require(configFolder:WaitForChild("CosmeticCatalog"))
local ProgressionConfig = require(configFolder:WaitForChild("ProgressionConfig"))
local Types = require(typesFolder:WaitForChild("ProfileTypes"))

local serverRoot = script.Parent.Parent
local adapters = serverRoot:WaitForChild("Adapters")
local systems = serverRoot:WaitForChild("Systems")
local RobloxProfileStore = require(adapters:WaitForChild("RobloxProfileStore"))
local RewardCalculation = require(systems:WaitForChild("RewardCalculation"))

type PlayerProfile = Types.PlayerProfile
type ProfileSnapshot = Types.ProfileSnapshot
type RewardInput = Types.RewardInput
type RewardGrant = Types.RewardGrant
type RewardResult = Types.RewardResult

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
		settings = deepCopy(ProgressionConfig.defaultSettings),
		recentRewardReceipts = {},
	}
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

	if typeof(raw.roleMastery) == "table" then
		local count = 0
		for rawRoleId, rawMastery in raw.roleMastery do
			local roleId = safeIdentifier(rawRoleId)
			if roleId and typeof(rawMastery) == "table" and count < ProgressionConfig.maxMapEntries then
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
			if roleId and typeof(rawUpgrades) == "table" and roleCount < ProgressionConfig.maxMapEntries then
				local roleUpgrades: { [string]: number } = {}
				local upgradeCount = 0
				for rawUpgradeId, rawRank in rawUpgrades do
					local upgradeId = safeIdentifier(rawUpgradeId)
					if upgradeId and upgradeCount < ProgressionConfig.maxMapEntries then
						roleUpgrades[upgradeId] = safeInteger(
							rawRank,
							0,
							ProgressionConfig.maxUpgradeRank
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

	table.insert(profile.recentRewardReceipts, grant.receiptId)
	while #profile.recentRewardReceipts > ProgressionConfig.maxRewardReceipts do
		table.remove(profile.recentRewardReceipts, 1)
	end
end

local function keyForUserId(userId: number): string
	return ProgressionConfig.keyPrefix .. tostring(userId)
end

function ProfileService.new(store: ProfileStore?): ProfileService
	local configuredStore = store
	if not configuredStore then
		local retry = ProgressionConfig.storeRetry
		configuredStore = RobloxProfileStore.new(ProgressionConfig.dataStoreName, {
			maxAttempts = retry.maxAttempts,
			baseDelaySeconds = retry.baseDelaySeconds,
			maxDelaySeconds = retry.maxDelaySeconds,
		})
	end

	return setmetatable({
		store = configuredStore :: ProfileStore,
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

function ProfileService:LoadPlayer(player: Player): ProfileSnapshot
	local existing = self.profiles[player.UserId]
	if existing then
		return self:_Snapshot(existing)
	end

	local success, rawValue, loadError =
		self.store:LoadAsync(keyForUserId(player.UserId))
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
		self.profiles[player.UserId] = guestState
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
	self.profiles[player.UserId] = state
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
		function(_currentValue: unknown?)
			return cached
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
	if not receiptId or not roleId then
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

	local normalizedInput: RewardInput = {
		receiptId = receiptId,
		roleId = roleId,
		participated = input.participated == true,
		won = input.won == true,
		survived = input.survived == true,
		objectivesCompleted = finiteNumber(input.objectivesCompleted, 0),
		evidenceCollected = finiteNumber(input.evidenceCollected, 0),
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
		self:SavePlayer(player)
		self.profiles[player.UserId] = nil
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

	game:BindToClose(function()
		local remaining = 0
		local finished = Instance.new("BindableEvent")
		for _, player in Players:GetPlayers() do
			remaining += 1
			task.spawn(function()
				self:SavePlayer(player)
				remaining -= 1
				finished:Fire()
			end)
		end

		local deadline = os.clock() + ProgressionConfig.shutdownSaveTimeoutSeconds
		while remaining > 0 and os.clock() < deadline do
			finished.Event:Wait()
		end
		finished:Destroy()
	end)
end

function ProfileService:Stop()
	self.running = false
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
end

return ProfileService
