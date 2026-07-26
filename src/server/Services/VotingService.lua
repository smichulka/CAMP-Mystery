--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParticipantTypes = require(
	ReplicatedStorage.Shared.Types:WaitForChild("ParticipantTypes")
)

type ParticipantState = ParticipantTypes.ParticipantState

type ParticipantProvider = {
	GetById: (self: any, participantId: string) -> ParticipantState?,
	GetAll: (self: any) -> { ParticipantState },
	SetVote: (self: any, participantId: string, targetParticipantId: string?) -> boolean,
}

export type VoteResolution = {
	winner: "Campers" | "Murderer",
	accusedParticipantId: string?,
	correct: boolean,
	tied: boolean,
	votesCast: number,
	eligibleVoters: number,
	reason: string,
}

export type VotingSnapshot = {
	roundId: number,
	revision: number,
	votesCast: number,
	eligibleVoters: number,
	resolved: boolean,
}

type VotingServiceState = {
	roundId: number,
	revision: number,
	participants: ParticipantProvider,
	votes: { [string]: string },
	resolution: VoteResolution?,
}

local VotingService = {}
VotingService.__index = VotingService

export type VotingService = typeof(
	setmetatable({} :: VotingServiceState, VotingService)
)

function VotingService.new(participants: ParticipantProvider): VotingService
	return setmetatable({
		roundId = 0,
		revision = 0,
		participants = participants,
		votes = {},
		resolution = nil,
	}, VotingService)
end

function VotingService:BeginRound(roundId: number)
	assert(roundId > self.roundId, "Round IDs must increase")
	self.roundId = roundId
	self.revision = 0
	self.votes = {}
	self.resolution = nil
	for _, participant in self.participants:GetAll() do
		participant.vote = {
			hasVoted = false,
			targetParticipantId = nil,
		}
	end
end

function VotingService:GetEligibleVoterCount(): number
	local count = 0
	for _, participant in self.participants:GetAll() do
		if participant.alive and not participant.isGhost and participant.role ~= "Spectator" then
			count += 1
		end
	end
	return count
end

function VotingService:CastVote(
	participantId: string,
	targetParticipantId: string
): (boolean, string?)
	if self.resolution then
		return false, "Voting is already resolved"
	end
	local voter = self.participants:GetById(participantId)
	local target = self.participants:GetById(targetParticipantId)
	if not voter or not target then
		return false, "Unknown voter or suspect"
	end
	if not voter.alive or voter.isGhost or voter.role == "Spectator" then
		return false, "Participant cannot vote"
	end
	if not target.alive or target.isGhost or target.role == "Spectator" then
		return false, "Suspect is not eligible"
	end
	if self.votes[participantId] then
		return false, "Vote is already locked"
	end
	if not self.participants:SetVote(participantId, targetParticipantId) then
		return false, "Vote could not be recorded"
	end

	self.votes[participantId] = targetParticipantId
	self.revision += 1
	return true, nil
end

function VotingService:IsComplete(): boolean
	local eligible = self:GetEligibleVoterCount()
	local cast = 0
	for _ in self.votes do
		cast += 1
	end
	return eligible > 0 and cast >= eligible
end

function VotingService:Resolve(culpritParticipantId: string): VoteResolution
	if self.resolution then
		return self.resolution
	end

	local totals: { [string]: number } = {}
	local votesCast = 0
	for _, targetParticipantId in self.votes do
		totals[targetParticipantId] = (totals[targetParticipantId] or 0) + 1
		votesCast += 1
	end

	local accusedParticipantId: string? = nil
	local topCount = 0
	local tied = false
	for targetParticipantId, count in totals do
		if count > topCount then
			accusedParticipantId = targetParticipantId
			topCount = count
			tied = false
		elseif count == topCount then
			tied = true
		end
	end
	if tied then
		accusedParticipantId = nil
	end

	local correct = accusedParticipantId == culpritParticipantId
	local resolution: VoteResolution = {
		winner = if correct then "Campers" else "Murderer",
		accusedParticipantId = accusedParticipantId,
		correct = correct,
		tied = tied,
		votesCast = votesCast,
		eligibleVoters = self:GetEligibleVoterCount(),
		reason = if correct
			then "The camp correctly exposed the Murderer."
			elseif tied
				then "The accusation tied, allowing the Murderer to escape."
				elseif accusedParticipantId == nil
					then "The camp reached no verdict."
					else "The camp accused the wrong participant.",
	}
	self.resolution = resolution
	self.revision += 1
	return resolution
end

function VotingService:EvaluateEliminationVictory(
	culpritParticipantId: string
): ("Campers" | "Murderer")?
	local culprit = self.participants:GetById(culpritParticipantId)
	if not culprit or not culprit.alive then
		return "Campers"
	end
	local livingCampers = 0
	for _, participant in self.participants:GetAll() do
		if participant.team == "Campers" and participant.alive and not participant.isGhost then
			livingCampers += 1
		end
	end
	return if livingCampers <= 1 then "Murderer" else nil
end

function VotingService:TransferParticipant(
	previousParticipantId: string,
	replacementParticipantId: string
)
	local previousVote = self.votes[previousParticipantId]
	if previousVote then
		self.votes[previousParticipantId] = nil
		self.votes[replacementParticipantId] = if previousVote == previousParticipantId
			then replacementParticipantId
			else previousVote
	end
	for voterId, targetId in self.votes do
		if targetId == previousParticipantId then
			self.votes[voterId] = replacementParticipantId
		end
	end
	for _, participant in self.participants:GetAll() do
		if participant.participantId == replacementParticipantId then
			local transferredTarget = previousVote
			if transferredTarget == previousParticipantId then
				transferredTarget = replacementParticipantId
			end
			participant.vote = {
				hasVoted = transferredTarget ~= nil,
				targetParticipantId = transferredTarget,
			}
		elseif participant.vote.targetParticipantId == previousParticipantId then
			participant.vote = {
				hasVoted = participant.vote.hasVoted,
				targetParticipantId = replacementParticipantId,
			}
		end
	end
	self.revision += 1
end

function VotingService:GetSnapshot(): VotingSnapshot
	local votesCast = 0
	for _ in self.votes do
		votesCast += 1
	end
	return {
		roundId = self.roundId,
		revision = self.revision,
		votesCast = votesCast,
		eligibleVoters = self:GetEligibleVoterCount(),
		resolved = self.resolution ~= nil,
	}
end

return VotingService
