--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local typesFolder = Shared:WaitForChild("Types")
local BotTypes = require(typesFolder:WaitForChild("BotTypes"))
local MatchTypes = require(typesFolder:WaitForChild("MatchTypes"))

local serverRoot = script.Parent.Parent
local configFolder = serverRoot:WaitForChild("Config")
local servicesFolder = serverRoot:WaitForChild("Services")
local BotProfiles = require(configFolder:WaitForChild("BotProfiles"))
local ParticipantServiceModule = require(servicesFolder:WaitForChild("ParticipantService"))

type DifficultyName = BotTypes.DifficultyName
type BotProfile = BotTypes.BotProfile
type BotRandomSource = BotTypes.BotRandomSource
type RosterParticipant = MatchTypes.RosterParticipant
type ParticipantService = ParticipantServiceModule.ParticipantService

export type LockedRoster = {
	roundId: string,
	targetSize: number,
	participantIds: { string },
	botParticipantIds: { string },
}

type BotRosterSystemState = {
	participantService: ParticipantService,
	randomSource: BotRandomSource,
	lockedRoster: LockedRoster?,
	difficultyOverride: DifficultyName?,
}

local BotRosterSystem = {}
BotRosterSystem.__index = BotRosterSystem

export type BotRosterSystem = typeof(
	setmetatable({} :: BotRosterSystemState, BotRosterSystem)
)

local function copyLockedRoster(roster: LockedRoster): LockedRoster
	return {
		roundId = roster.roundId,
		targetSize = roster.targetSize,
		participantIds = table.clone(roster.participantIds),
		botParticipantIds = table.clone(roster.botParticipantIds),
	}
end

local function validateCount(value: number, name: string, minimum: number, maximum: number)
	assert(
		value >= minimum and value <= maximum and value % 1 == 0,
		string.format("%s must be a whole number from %d through %d", name, minimum, maximum)
	)
end

function BotRosterSystem.new(
	participantService: ParticipantService,
	randomSource: BotRandomSource?,
	difficultyOverride: DifficultyName?
): BotRosterSystem
	local source: BotRandomSource = randomSource or (Random.new() :: any)
	if difficultyOverride then
		BotProfiles.GetDifficulty(difficultyOverride)
	end
	return setmetatable({
		participantService = participantService,
		randomSource = source,
		lockedRoster = nil,
		difficultyOverride = difficultyOverride,
	}, BotRosterSystem)
end

function BotRosterSystem:IsLocked(): boolean
	return self.lockedRoster ~= nil
end

function BotRosterSystem:GetLockedRoster(): LockedRoster?
	local roster = self.lockedRoster
	return if roster then copyLockedRoster(roster) else nil
end

function BotRosterSystem:_AvailableProfiles(
	excludedProfileIds: { [string]: boolean }
): { BotProfile }
	local available: { BotProfile } = {}
	for _, profile in BotProfiles.GetAll() do
		if not excludedProfileIds[profile.id] then
			table.insert(available, profile)
		end
	end
	for index = #available, 2, -1 do
		local swapIndex = self.randomSource:NextInteger(1, index)
		available[index], available[swapIndex] = available[swapIndex], available[index]
	end
	return available
end

function BotRosterSystem:_CreateRosterBot(profile: BotProfile): RosterParticipant
	local difficulty = self.difficultyOverride or profile.difficulty
	local tuning = BotProfiles.GetDifficulty(difficulty)
	local bot = self.participantService:CreateBot(
		profile.id,
		profile.displayName,
		profile.id,
		tuning.decisionQuality
	)
	return {
		participantId = bot.participantId,
		displayName = bot.displayName,
		controllerKind = "Bot",
		userId = nil,
		botId = profile.id,
	}
end

-- Matchmaking calls this method after selecting the ready humans. It deliberately
-- returns only the bot additions so the caller remains the owner of roster ordering.
function BotRosterSystem:FillEmptySlots(
	humans: { RosterParticipant },
	emptySlotCount: number,
	roundId: string
): { RosterParticipant }
	assert(not self.lockedRoster, "The bot roster is already locked")
	assert(roundId ~= "", "Round ID cannot be empty")
	validateCount(emptySlotCount, "Empty slot count", 0, 12)
	assert(#humans + emptySlotCount <= 12, "A roster supports at most 12 participants")

	local participantIds: { string } = {}
	local botParticipantIds: { string } = {}
	local seenParticipantIds: { [string]: boolean } = {}
	for _, human in humans do
		assert(human.controllerKind == "Human" and human.userId ~= nil, "Invalid human roster entry")
		assert(not seenParticipantIds[human.participantId], "Duplicate human participant ID")
		seenParticipantIds[human.participantId] = true
		table.insert(participantIds, human.participantId)
	end

	local availableProfiles = self:_AvailableProfiles({})
	assert(#availableProfiles >= emptySlotCount, "Not enough unique bot profiles to fill the roster")
	local bots: { RosterParticipant } = {}
	for index = 1, emptySlotCount do
		local rosterBot = self:_CreateRosterBot(availableProfiles[index])
		assert(not seenParticipantIds[rosterBot.participantId], "Bot participant ID collides with roster")
		seenParticipantIds[rosterBot.participantId] = true
		table.insert(bots, rosterBot)
		table.insert(participantIds, rosterBot.participantId)
		table.insert(botParticipantIds, rosterBot.participantId)
	end

	self.lockedRoster = {
		roundId = roundId,
		targetSize = #humans + emptySlotCount,
		participantIds = participantIds,
		botParticipantIds = botParticipantIds,
	}
	return bots
end

-- Replaces a disconnected locked human with a fresh bot profile. The round
-- integrator may transfer the departed participant's role and state in its
-- roster-changed callback.
function BotRosterSystem:FillReplacement(
	roundId: string,
	departedParticipantId: string
): (RosterParticipant?, string?)
	local roster = self.lockedRoster
	if not roster or roster.roundId ~= roundId then
		return nil, "RoundRosterNotLocked"
	end
	local departedIndex = table.find(roster.participantIds, departedParticipantId)
	if not departedIndex then
		return nil, "DepartedParticipantNotInRoster"
	end

	local excluded: { [string]: boolean } = {}
	for _, botParticipantId in roster.botParticipantIds do
		local bot = self.participantService:GetById(botParticipantId)
		if bot and bot.controller.kind == "Bot" then
			excluded[bot.controller.profileId] = true
		end
	end
	local available = self:_AvailableProfiles(excluded)
	local profile = available[1]
	if not profile then
		return nil, "NoBotProfileAvailable"
	end

	local replacement = self:_CreateRosterBot(profile)
	roster.participantIds[departedIndex] = replacement.participantId
	table.insert(roster.botParticipantIds, replacement.participantId)
	return replacement, nil
end

-- Compatibility entry point for server simulations that build the participant
-- domain before invoking matchmaking.
function BotRosterSystem:LockAndFill(
	targetSize: number,
	difficultyOverride: DifficultyName?
): LockedRoster
	validateCount(targetSize, "Target roster size", 1, 12)
	assert(not self.lockedRoster, "The roster is already locked")

	local previousOverride = self.difficultyOverride
	if difficultyOverride then
		BotProfiles.GetDifficulty(difficultyOverride)
		self.difficultyOverride = difficultyOverride
	end

	local participantIds: { string } = {}
	local botParticipantIds: { string } = {}
	local usedProfileIds: { [string]: boolean } = {}
	for _, state in self.participantService:GetAll() do
		if state.controller.connected then
			table.insert(participantIds, state.participantId)
			if state.controller.kind == "Bot" then
				table.insert(botParticipantIds, state.participantId)
				usedProfileIds[state.controller.profileId] = true
			end
		end
	end
	assert(#participantIds <= targetSize, "Connected participants exceed target size")

	local botsNeeded = targetSize - #participantIds
	local available = self:_AvailableProfiles(usedProfileIds)
	assert(#available >= botsNeeded, "Not enough unique bot profiles to fill the roster")
	for index = 1, botsNeeded do
		local bot = self:_CreateRosterBot(available[index])
		table.insert(participantIds, bot.participantId)
		table.insert(botParticipantIds, bot.participantId)
	end
	local roster: LockedRoster = {
		roundId = "compatibility",
		targetSize = targetSize,
		participantIds = participantIds,
		botParticipantIds = botParticipantIds,
	}
	table.sort(roster.participantIds)
	table.sort(roster.botParticipantIds)
	self.lockedRoster = roster
	self.difficultyOverride = previousOverride
	return copyLockedRoster(roster)
end

function BotRosterSystem:ReleaseRound(roundId: string?): boolean
	local roster = self.lockedRoster
	if not roster then
		return false
	end
	if roundId and roster.roundId ~= roundId then
		return false
	end
	for _, participantId in roster.botParticipantIds do
		local state = self.participantService:GetById(participantId)
		if state and state.controller.kind == "Bot" then
			state.controller.connected = false
		end
	end
	self.lockedRoster = nil
	return true
end

function BotRosterSystem:Unlock()
	self:ReleaseRound(nil)
end

return BotRosterSystem
