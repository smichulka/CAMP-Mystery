--!strict

local typesFolder = script.Parent

local CombatTypes = require(typesFolder:WaitForChild("CombatTypes"))
local CounselorTypes = require(typesFolder:WaitForChild("CounselorTypes"))
local EquipmentTypes = require(typesFolder:WaitForChild("EquipmentTypes"))
local EvidenceTypes = require(typesFolder:WaitForChild("EvidenceTypes"))
local GameTypes = require(typesFolder:WaitForChild("GameTypes"))
local MatchTypes = require(typesFolder:WaitForChild("MatchTypes"))
local MonsterTypes = require(typesFolder:WaitForChild("MonsterTypes"))
local MysteryTypes = require(typesFolder:WaitForChild("MysteryTypes"))
local ParticipantTypes = require(typesFolder:WaitForChild("ParticipantTypes"))
local ProfileTypes = require(typesFolder:WaitForChild("ProfileTypes"))
local WorldTypes = require(typesFolder:WaitForChild("WorldTypes"))

export type ActionName =
	"Ready"
	| "SetMurderPlan"
	| "CompleteObjective"
	| "DiscoverEvidence"
	| "InterviewCounselor"
	| "Vote"
	| "PresentEvidence"
	| "BuddyCheckIn"
	| "Sabotage"
	| "GhostFlickerLight"
	| "EquipItem"
	| "UseItem"
	| "DropItem"
	| "TransferItem"
	| "UseRoleAbility"
	| "UseMonsterAbility"
	| "VerifyEvidence"
	| "AddEvidenceNote"
	| "SetSettings"
	| "BuyUpgrade"
	| "UnlockCosmetic"
	| "EquipCosmetic"

export type AvailableAction = {
	name: ActionName,
	enabled: boolean,
	reason: string?,
}

export type MurderPlanSnapshot = {
	victimParticipantId: string,
	frameParticipantId: string?,
	locationId: string,
	monsterId: MonsterTypes.MonsterId,
}

export type GameState = {
	serverNow: number,
	round: GameTypes.RoundSnapshot,
	lobby: MatchTypes.LobbySnapshot?,
	participants: { ParticipantTypes.PublicParticipantSnapshot },
	player: ParticipantTypes.PrivateParticipantSnapshot?,
	inventory: EquipmentTypes.InventorySnapshot?,
	combat: CombatTypes.CombatSnapshot?,
	evidence: EvidenceTypes.EvidenceBoardSnapshot?,
	mystery: MysteryTypes.MysteryPublicSnapshot?,
	counselors: CounselorTypes.CounselorRosterSnapshot?,
	monster: MonsterTypes.MonsterPublicSnapshot?,
	privateMonster: MonsterTypes.MonsterPrivateSnapshot?,
	murderPlan: MurderPlanSnapshot?,
	world: WorldTypes.WorldPublicSnapshot?,
	profile: ProfileTypes.ProfileSnapshot?,
	availableActions: { AvailableAction },
}

export type ActionResult = {
	accepted: boolean,
	reason: string?,
	state: GameState?,
	data: unknown?,
}

export type Announcement = {
	kind: "Info" | "Success" | "Warning" | "Danger",
	title: string,
	message: string,
	duration: number?,
}

return {}
