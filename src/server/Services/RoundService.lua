--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local configFolder = Shared:WaitForChild("Config")
local typesFolder = Shared:WaitForChild("Types")
local RoundConfig = require(configFolder:WaitForChild("RoundConfig"))
local Types = require(typesFolder:WaitForChild("GameTypes"))

type PhaseName = Types.PhaseName
type PhaseConfig = Types.PhaseConfig
type RoundSnapshot = Types.RoundSnapshot

type RoundServiceState = {
	roundNumber: number,
	currentPhase: PhaseName,
	currentPhaseDisplayName: string,
	phaseStartedAt: number,
	phaseEndsAt: number,
	running: boolean,
	roundStateChanged: RemoteEvent,
	getRoundState: RemoteFunction,
}

local RoundService = {}
RoundService.__index = RoundService

export type RoundService = typeof(setmetatable({} :: RoundServiceState, RoundService))

function RoundService.new(): RoundService
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local roundStateChanged = remotes:WaitForChild("RoundStateChanged")
	local getRoundState = remotes:WaitForChild("GetRoundState")

	assert(roundStateChanged:IsA("RemoteEvent"), "RoundStateChanged must be a RemoteEvent")
	assert(getRoundState:IsA("RemoteFunction"), "GetRoundState must be a RemoteFunction")

	local now = workspace:GetServerTimeNow()
	local self: RoundService = setmetatable({
		roundNumber = 0,
		currentPhase = "Lobby",
		currentPhaseDisplayName = "Waiting at Camp",
		phaseStartedAt = now,
		phaseEndsAt = now,
		running = false,
		roundStateChanged = roundStateChanged,
		getRoundState = getRoundState,
	}, RoundService)

	self.getRoundState.OnServerInvoke = function(_player: Player): RoundSnapshot
		return self:GetSnapshot()
	end

	return self
end

function RoundService:GetSnapshot(): RoundSnapshot
	return {
		roundNumber = self.roundNumber,
		phase = self.currentPhase,
		phaseDisplayName = self.currentPhaseDisplayName,
		phaseStartedAt = self.phaseStartedAt,
		phaseEndsAt = self.phaseEndsAt,
		serverNow = workspace:GetServerTimeNow(),
	}
end

function RoundService:SetPhase(phase: PhaseName, displayName: string, durationSeconds: number)
	local now = workspace:GetServerTimeNow()

	self.currentPhase = phase
	self.currentPhaseDisplayName = displayName
	self.phaseStartedAt = now
	self.phaseEndsAt = now + durationSeconds

	local snapshot = self:GetSnapshot()
	self.roundStateChanged:FireAllClients(snapshot)

	print(
		string.format(
			"[RoundService] Round %d entered %s for %d seconds",
			self.roundNumber,
			phase,
			durationSeconds
		)
	)
end

function RoundService:RunRound()
	self.roundNumber += 1

	for _, phaseConfig: PhaseConfig in RoundConfig.phases do
		if not self.running then
			return
		end

		self:SetPhase(
			phaseConfig.name,
			phaseConfig.displayName,
			phaseConfig.durationSeconds
		)
		task.wait(phaseConfig.durationSeconds)
	end
end

function RoundService:Start()
	if self.running then
		return
	end

	self.running = true

	task.spawn(function()
		while self.running do
			self:RunRound()
		end
	end)
end

function RoundService:Stop()
	self.running = false
end

return RoundService
