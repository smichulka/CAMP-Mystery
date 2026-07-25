--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local typesFolder = Shared:WaitForChild("Types")
local BotTypes = require(typesFolder:WaitForChild("BotTypes"))

local serverRoot = script.Parent.Parent
local configFolder = serverRoot:WaitForChild("Config")
local servicesFolder = serverRoot:WaitForChild("Services")
local BotProfiles = require(configFolder:WaitForChild("BotProfiles"))
local ParticipantServiceModule = require(servicesFolder:WaitForChild("ParticipantService"))

type DifficultyName = BotTypes.DifficultyName
type BotProfile = BotTypes.BotProfile
type BotRandomSource = BotTypes.BotRandomSource
type ParticipantService = ParticipantServiceModule.ParticipantService

export type LockedRoster = {
	targetSize: number,
	participantIds: { string },
	botParticipantIds: { string },
}

type BotRosterSystemState = {
	participantService: ParticipantService,
	randomSource: BotRandomSource,
	lockedRoster: LockedRoster?,
}

local BotRosterSystem = {}
BotRosterSystem.__index = BotRosterSystem

export type BotRosterSystem = typeof(
	setmetatable({} :: BotRosterSystemState, BotRosterSystem)
)

function BotRosterSystem.new(
	participantService: ParticipantService,
	randomSource: BotRandomSource?
): BotRosterSystem
	local source: BotRandomSource = randomSource or (Random.new() :: any)
	return setmetatable({
		participantService = participantService,
		randomSource = source,
		lockedRoster = nil,
	}, BotRosterSystem)
end

function BotRosterSystem:IsLocked(): boolean
	return self.lockedRoster ~= nil
end

function BotRosterSystem:GetLockedRoster(): LockedRoster?
	local roster = self.lockedRoster
	if not roster then
		return nil
	end
	return {
		targetSize = roster.targetSize,
		participantIds = table.clone(roster.participantIds),
		botParticipantIds = table.clone(roster.botParticipantIds),
	}
end

function BotRosterSystem:LockAndFill(
	targetSize: number,
	difficultyOverride: DifficultyName?
): LockedRoster
	assert(not self.lockedRoster, "The roster is already locked")
	assert(
		targetSize >= 1 and targetSize <= 12 and targetSize % 1 == 0,
		"Target roster size must be a whole number from 1 through 12"
	)

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
	assert(
		#participantIds <= targetSize,
		"Connected participants exceed the requested roster size"
	)

	local availableProfiles: { BotProfile } = {}
	for _, profile in BotProfiles.GetAll() do
		if not usedProfileIds[profile.id] then
			table.insert(availableProfiles, profile)
		end
	end
	for index = #availableProfiles, 2, -1 do
		local swapIndex = self.randomSource:NextInteger(1, index)
		availableProfiles[index], availableProfiles[swapIndex] =
			availableProfiles[swapIndex], availableProfiles[index]
	end

	local botsNeeded = targetSize - #participantIds
	assert(#availableProfiles >= botsNeeded, "Not enough unique bot profiles to fill the roster")
	for index = 1, botsNeeded do
		local profile = availableProfiles[index]
		local difficulty = difficultyOverride or profile.difficulty
		local tuning = BotProfiles.GetDifficulty(difficulty)
		local bot = self.participantService:CreateBot(
			profile.id,
			profile.displayName,
			profile.id,
			tuning.decisionQuality
		)
		table.insert(participantIds, bot.participantId)
		table.insert(botParticipantIds, bot.participantId)
	end

	table.sort(participantIds)
	table.sort(botParticipantIds)
	local roster: LockedRoster = {
		targetSize = targetSize,
		participantIds = participantIds,
		botParticipantIds = botParticipantIds,
	}
	self.lockedRoster = roster
	return self:GetLockedRoster() :: LockedRoster
end

function BotRosterSystem:Unlock()
	local roster = self.lockedRoster
	if not roster then
		return
	end
	for _, participantId in roster.botParticipantIds do
		local state = self.participantService:GetById(participantId)
		if state and state.controller.kind == "Bot" then
			state.controller.connected = false
		end
	end
	self.lockedRoster = nil
end

return BotRosterSystem
