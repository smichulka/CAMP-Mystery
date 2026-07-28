--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EvidenceTypes = require(
	ReplicatedStorage.Shared.Types:WaitForChild("EvidenceTypes")
)
local ParticipantTypes = require(
	ReplicatedStorage.Shared.Types:WaitForChild("ParticipantTypes")
)
local EvidenceRules = require(script.Parent.Parent.Config:WaitForChild("EvidenceRules"))

type EvidenceAuthenticity = EvidenceTypes.EvidenceAuthenticity
type EvidenceBoardSnapshot = EvidenceTypes.EvidenceBoardSnapshot
type EvidenceChannel = EvidenceTypes.EvidenceChannel
type EvidenceRecord = EvidenceTypes.EvidenceRecord
type PublicEvidenceRecord = EvidenceTypes.PublicEvidenceRecord
type ParticipantState = ParticipantTypes.ParticipantState

type ParticipantProvider = {
	GetById: (self: ParticipantProvider, participantId: string) -> ParticipantState?,
}

type EvidenceServiceState = {
	roundId: number,
	revision: number,
	nextEvidenceNumber: number,
	culpritParticipantId: string?,
	monsterId: string?,
	participants: ParticipantProvider,
	records: { [string]: EvidenceRecord },
	order: { string },
	fakeEvidencePlanted: boolean,
	random: Random,
}

local EvidenceService = {}
EvidenceService.__index = EvidenceService

export type EvidenceService = typeof(
	setmetatable({} :: EvidenceServiceState, EvidenceService)
)

local function cloneDiscovery(
	discovery: EvidenceTypes.EvidenceDiscovery?
): EvidenceTypes.EvidenceDiscovery?
	if not discovery then
		return nil
	end
	return {
		discoveredByParticipantId = discovery.discoveredByParticipantId,
		discoveredByDisplayName = discovery.discoveredByDisplayName,
		locationId = discovery.locationId,
		discoveredAt = discovery.discoveredAt,
	}
end

local function toPublic(record: EvidenceRecord): PublicEvidenceRecord
	return {
		evidenceId = record.evidenceId,
		channel = record.channel,
		displayName = record.displayName,
		description = record.description,
		discovery = cloneDiscovery(record.discovery),
		chainOfCustody = table.clone(record.chainOfCustody),
		notes = table.clone(record.notes),
		posted = record.posted,
		verificationState = record.verificationState,
	}
end

function EvidenceService.new(participants: ParticipantProvider): EvidenceService
	return setmetatable({
		roundId = 0,
		revision = 0,
		nextEvidenceNumber = 0,
		culpritParticipantId = nil,
		monsterId = nil,
		participants = participants,
		records = {},
		order = {},
		fakeEvidencePlanted = false,
		random = Random.new(),
	}, EvidenceService)
end

function EvidenceService:BeginRound(
	roundId: number,
	culpritParticipantId: string,
	monsterId: string,
	seed: number?
)
	assert(roundId > self.roundId, "Round IDs must increase")
	assert(self.participants:GetById(culpritParticipantId), "Unknown culprit participant")
	self.roundId = roundId
	self.revision = 0
	self.nextEvidenceNumber = 0
	self.culpritParticipantId = culpritParticipantId
	self.monsterId = monsterId
	self.records = {}
	self.order = {}
	self.fakeEvidencePlanted = false
	self.random = Random.new(seed or roundId)
end

function EvidenceService:Create(
	templateId: string,
	authenticity: EvidenceAuthenticity?,
	suspectWeights: { [string]: number }?,
	monsterWeights: { [string]: number }?
): EvidenceRecord
	local template = EvidenceRules[templateId]
	assert(template, "Unknown evidence template: " .. templateId)
	self.nextEvidenceNumber += 1
	local evidenceId = string.format(
		"evidence:%d:%d",
		self.roundId,
		self.nextEvidenceNumber
	)
	local record: EvidenceRecord = {
		evidenceId = evidenceId,
		templateId = template.id,
		channel = template.channel,
		displayName = template.displayName,
		description = template.description,
		authenticity = authenticity or template.defaultAuthenticity,
		suspectWeights = suspectWeights or {},
		monsterWeights = monsterWeights or {},
		discovery = nil,
		chainOfCustody = {},
		notes = {},
		posted = false,
		verificationState = "Unverified",
		verifiedByParticipantId = nil,
	}
	self.records[evidenceId] = record
	table.insert(self.order, evidenceId)
	self.revision += 1
	return record
end

function EvidenceService:GenerateBaselineMystery(frameParticipantId: string?)
	local culpritId = self.culpritParticipantId
	assert(culpritId, "BeginRound must be called before evidence generation")
	local realWeights = { [culpritId] = 0.55 }
	self:Create("attack-footprint", "Real", realWeights, nil)
	self:Create("attack-fabric", "Real", realWeights, nil)
	self:Create("witness-conflict", "Ambiguous", realWeights, nil)

	local monsterId = self.monsterId
	local monsterWeights = if monsterId then { [monsterId] = 0.6 } else {}
	self:Create("monster-trace", "Real", nil, monsterWeights)
	self:Create("device-reading", "Real", nil, monsterWeights)

	if frameParticipantId and frameParticipantId ~= culpritId then
		self:Create("planted-token", "Fake", { [frameParticipantId] = 0.8 }, nil)
		self.fakeEvidencePlanted = true
	end
end

function EvidenceService:CreateAttackEvidence(
	attackerParticipantId: string,
	targetParticipantId: string,
	locationId: string,
	lethal: boolean
): EvidenceRecord
	assert(attackerParticipantId == self.culpritParticipantId, "Attack evidence must come from culprit")
	assert(self.participants:GetById(targetParticipantId), "Unknown target participant")
	local templateId = if lethal or self.random:NextNumber() >= 0.5
		then "attack-blood"
		else "attack-footprint"
	return self:Create(
		templateId,
		"Real",
		{ [attackerParticipantId] = if lethal then 0.75 else 0.55 },
		nil
	)
end

function EvidenceService:PlantFake(
	murdererParticipantId: string,
	frameParticipantId: string
): (boolean, string?)
	if murdererParticipantId ~= self.culpritParticipantId then
		return false, "Only the Murderer can plant fake evidence"
	end
	if self.fakeEvidencePlanted then
		return false, "Fake evidence has already been planted"
	end
	if
		frameParticipantId == murdererParticipantId
		or not self.participants:GetById(frameParticipantId)
	then
		return false, "Invalid frame target"
	end

	self:Create("planted-token", "Fake", { [frameParticipantId] = 0.9 }, nil)
	self.fakeEvidencePlanted = true
	return true, nil
end

function EvidenceService:SetMonsterForRound(monsterId: string)
	assert(self.roundId > 0, "BeginRound must be called before changing monster evidence")
	assert(monsterId ~= "", "monsterId cannot be empty")
	self.monsterId = monsterId
	for _, record in self.records do
		if record.channel == "Monster" then
			record.monsterWeights = { [monsterId] = 0.6 }
		end
	end
	self.revision += 1
end

function EvidenceService:TransferCulprit(
	previousParticipantId: string,
	replacementParticipantId: string
)
	if self.culpritParticipantId ~= previousParticipantId then
		return
	end
	self.culpritParticipantId = replacementParticipantId
	for _, record in self.records do
		local weight = record.suspectWeights[previousParticipantId]
		if weight then
			record.suspectWeights[previousParticipantId] = nil
			record.suspectWeights[replacementParticipantId] = weight
		end
	end
	self.revision += 1
end

function EvidenceService:ReframeFake(
	murdererParticipantId: string,
	frameParticipantId: string
): (boolean, string?)
	if murdererParticipantId ~= self.culpritParticipantId then
		return false, "Only the Murderer can change the frame target"
	end
	if
		frameParticipantId == murdererParticipantId
		or not self.participants:GetById(frameParticipantId)
	then
		return false, "Invalid frame target"
	end
	for _, record in self.records do
		if record.authenticity == "Fake" then
			record.suspectWeights = { [frameParticipantId] = 0.9 }
			self.revision += 1
			return true, nil
		end
	end
	return self:PlantFake(murdererParticipantId, frameParticipantId)
end

function EvidenceService:Discover(
	participantId: string,
	evidenceId: string,
	locationId: string,
	now: number
): (boolean, string?)
	local participant = self.participants:GetById(participantId)
	local record = self.records[evidenceId]
	if not participant or not participant.alive or participant.isGhost then
		return false, "Participant cannot discover physical evidence"
	end
	if not record then
		return false, "Unknown evidence"
	end
	if record.discovery then
		return false, "Evidence was already discovered"
	end

	record.discovery = {
		discoveredByParticipantId = participantId,
		discoveredByDisplayName = participant.displayName,
		locationId = locationId,
		discoveredAt = now,
	}
	record.chainOfCustody = { participantId }
	record.posted = true
	self.revision += 1
	return true, nil
end

function EvidenceService:Verify(
	detectiveParticipantId: string,
	evidenceId: string
): (boolean, string?)
	local detective = self.participants:GetById(detectiveParticipantId)
	local record = self.records[evidenceId]
	if
		not detective
		or detective.role ~= "Detective"
		or not detective.alive
		or detective.isGhost
	then
		return false, "Only the living Detective can verify evidence"
	end
	if not record or not record.posted then
		return false, "Evidence is not on the board"
	end
	if record.verificationState ~= "Unverified" then
		return false, "Evidence was already verified"
	end

	record.verificationState = if record.authenticity == "Fake"
		then "VerifiedFake"
		else "VerifiedReal"
	record.verifiedByParticipantId = detectiveParticipantId
	if not table.find(record.chainOfCustody, detectiveParticipantId) then
		table.insert(record.chainOfCustody, detectiveParticipantId)
	end
	self.revision += 1
	return true, nil
end

function EvidenceService:AddNote(
	participantId: string,
	evidenceId: string,
	text: string,
	now: number
): (boolean, string?)
	local participant = self.participants:GetById(participantId)
	local record = self.records[evidenceId]
	local trimmed = string.sub(text, 1, 160)
	if not participant or not participant.alive or participant.isGhost then
		return false, "Participant cannot add a note"
	end
	if not record or not record.posted then
		return false, "Evidence is not on the board"
	end
	if trimmed == "" then
		return false, "Note cannot be empty"
	end

	table.insert(record.notes, {
		authorParticipantId = participantId,
		text = trimmed,
		createdAt = now,
	})
	self.revision += 1
	return true, nil
end

function EvidenceService:GetRecordServer(evidenceId: string): EvidenceRecord?
	return self.records[evidenceId]
end

function EvidenceService:GetAllServer(): { EvidenceRecord }
	local result: { EvidenceRecord } = {}
	for _, evidenceId in self.order do
		local record = self.records[evidenceId]
		if record then
			table.insert(result, record)
		end
	end
	return result
end

function EvidenceService:GetUndiscoveredServer(): { EvidenceRecord }
	local result: { EvidenceRecord } = {}
	for _, evidenceId in self.order do
		local record = self.records[evidenceId]
		if record and not record.discovery then
			table.insert(result, record)
		end
	end
	return result
end

function EvidenceService:GetBoardSnapshot(): EvidenceBoardSnapshot
	local culpritEvidence: { PublicEvidenceRecord } = {}
	local monsterEvidence: { PublicEvidenceRecord } = {}
	for _, evidenceId in self.order do
		local record = self.records[evidenceId]
		if record and record.posted then
			local destination = if record.channel == "Culprit"
				then culpritEvidence
				else monsterEvidence
			table.insert(destination, toPublic(record))
		end
	end
	return {
		roundId = self.roundId,
		revision = self.revision,
		culpritEvidence = culpritEvidence,
		monsterEvidence = monsterEvidence,
	}
end

return EvidenceService
