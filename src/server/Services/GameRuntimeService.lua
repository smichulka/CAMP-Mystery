--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchConfig = require(Shared.Config:WaitForChild("MatchConfig"))
local RoundConfig = require(Shared.Config:WaitForChild("RoundConfig"))
local EquipmentRules = require(
	script.Parent.Parent.Config:WaitForChild("EquipmentRules")
)
local BotContributionConfig = require(
	script.Parent.Parent.Config:WaitForChild("BotContributionConfig")
)
local EvidenceComboRules = require(
	script.Parent.Parent.Config:WaitForChild("EvidenceComboRules")
)
local ColdCaseArchive = require(
	script.Parent.Parent.Config:WaitForChild("ColdCaseArchive")
)
local MysteryCatalog = require(
	script.Parent.Parent.Config:WaitForChild("MysteryCatalog")
)
local CombatTypes = require(Shared.Types:WaitForChild("CombatTypes"))
local CounselorTypes = require(Shared.Types:WaitForChild("CounselorTypes"))
local EquipmentTypes = require(Shared.Types:WaitForChild("EquipmentTypes"))
local EvidenceTypes = require(Shared.Types:WaitForChild("EvidenceTypes"))
local GameTypes = require(Shared.Types:WaitForChild("GameTypes"))
local MonsterTypes = require(Shared.Types:WaitForChild("MonsterTypes"))
local MysteryTypes = require(Shared.Types:WaitForChild("MysteryTypes"))
local ParticipantTypes = require(Shared.Types:WaitForChild("ParticipantTypes"))
local RuntimeTypes = require(Shared.Types:WaitForChild("RuntimeTypes"))

local services = script.Parent
local systems = script.Parent.Parent:WaitForChild("Systems")
local CombatService = require(services:WaitForChild("CombatService"))
local ComputerPlayerService = require(services:WaitForChild("ComputerPlayerService"))
local CounselorService = require(services:WaitForChild("CounselorService"))
local EvidenceService = require(services:WaitForChild("EvidenceService"))
local ProductionMapService = require(services:WaitForChild("ProductionMapService"))
local InventoryService = require(services:WaitForChild("InventoryService"))
local LobbyService = require(services:WaitForChild("LobbyService"))
local MatchmakingService = require(services:WaitForChild("MatchmakingService"))
local MonsterService = require(services:WaitForChild("MonsterService"))
local MysteryService = require(services:WaitForChild("MysteryService"))
local ParticipantService = require(services:WaitForChild("ParticipantService"))
local CharacterAssetService = require(services:WaitForChild("CharacterAssetService"))
local ProfileService = require(services:WaitForChild("ProfileService"))
local RoleAbilityService = require(services:WaitForChild("RoleAbilityService"))
local RoundLifecycle = require(services:WaitForChild("RoundLifecycle"))
local StatusEffectService = require(services:WaitForChild("StatusEffectService"))
local VotingService = require(services:WaitForChild("VotingService"))
local WorldService = require(services:WaitForChild("WorldService"))
local BotRosterSystem = require(systems:WaitForChild("BotRosterSystem"))

type ActionName = RuntimeTypes.ActionName
type ActionResult = RuntimeTypes.ActionResult
type ComboRecipe = EvidenceComboRules.ComboRecipe
type EvidenceAuthenticity = EvidenceTypes.EvidenceAuthenticity
type EvidenceRecord = EvidenceTypes.EvidenceRecord
type GameState = RuntimeTypes.GameState
type PhaseName = GameTypes.PhaseName
type WinnerName = GameTypes.WinnerName
type RoundSnapshot = GameTypes.RoundSnapshot
type EvidenceSummary = GameTypes.EvidenceSummary
type Suspect = GameTypes.Suspect
type ParticipantState = ParticipantTypes.ParticipantState
type EquipmentId = EquipmentTypes.EquipmentId
type MonsterId = MonsterTypes.MonsterId
type AbilityRequest = MonsterTypes.AbilityRequest
type MonsterStatusId = MonsterTypes.MonsterStatusId
type DialogueTopic = CounselorTypes.DialogueTopic

export type RuntimeOptions = {
	autoRun: boolean?,
	fillWithBots: boolean?,
	onStateChanged: ((player: Player, state: GameState) -> ())?,
	onAnnouncement: ((
		kind: string,
		title: string,
		message: string,
		duration: number?
	) -> ())?,
}

type MurderPlan = {
	victimParticipantId: string,
	frameParticipantId: string?,
	locationId: string,
	monsterId: MonsterId,
}

type BotSiteTask = {
	candidateId: string,
	workReadyAt: number?,
}

type DayOutcomes = {
	generator: boolean,
	firewood: boolean,
	supplies: boolean,
}

type ColdCaseFile = {
	title: string,
	summary: string,
}

type GameRuntimeServiceState = {
	options: RuntimeOptions,
	running: boolean,
	generation: number,
	roundId: number,
	phase: PhaseName,
	phaseStartedAt: number,
	phaseEndsAt: number,
	winner: WinnerName?,
	resultMessage: string?,
	victimName: string?,
	culpritParticipantId: string?,
	murderPlan: MurderPlan?,
	completedObjectives: { [string]: string },
	objectivesByParticipantId: { [string]: number },
	evidenceByParticipantId: { [string]: number },
	evidenceLocationById: { [string]: string },
	evidenceAliasById: { [string]: string },
	mysteryClueIdsByLocation: { [string]: { string } },
	mysteryReady: boolean,
	lastMonsterId: MonsterId?,
	botTaskById: { [string]: BotSiteTask },
	botObjectiveCount: number,
	botEvidenceCount: number,
	votingOpensAt: number?,
	dayOutcomes: DayOutcomes?,
	campfireStage: string?,
	discussionLog: { GameTypes.DiscussionEntry },
	presentedSuspicion: { [string]: number },
	presentedItems: { [string]: boolean },
	presentedCountByParticipantId: { [string]: number },
	checkInPairs: { [string]: boolean },
	checkInsByParticipantId: { [string]: number },
	bodyReportedByVictimId: { [string]: boolean },
	ghostFlickerAt: { [string]: number },
	activeComboRecipes: { ComboRecipe },
	usedComboRecipeIds: { [string]: boolean },
	comboCooldownAt: { [string]: number },
	contradictionEvidenceIssued: boolean,
	coldCaseFiles: { ColdCaseFile },
	coldCaseReadsByParticipantId: { [string]: { [number]: boolean } },
	coldCaseCompletedByParticipantId: { [string]: boolean },
	keyHolderByRoomId: { [string]: string },
	openedRoomIds: { [string]: boolean },
	supplyCacheClaimedBy: string?,
	activeMatchRoundId: string?,
	connections: { RBXScriptConnection },
	participants: ParticipantService.ParticipantService,
	lifecycle: RoundLifecycle.RoundLifecycle,
	inventory: InventoryService.InventoryService,
	combat: CombatService.CombatService,
	evidence: EvidenceService.EvidenceService,
	mystery: MysteryService.MysteryService,
	counselors: CounselorService.CounselorService,
	monster: MonsterService.MonsterService,
	world: WorldService.WorldService,
	map: ProductionMapService.ProductionMapService,
	statusEffects: StatusEffectService.StatusEffectService,
	roleAbilities: RoleAbilityService.RoleAbilityService,
	voting: VotingService.VotingService,
	characters: CharacterAssetService.CharacterAssetService,
	botRoster: BotRosterSystem.BotRosterSystem,
	computerPlayers: ComputerPlayerService.ComputerPlayerService,
	lobby: LobbyService.LobbyService,
	matchmaking: MatchmakingService.MatchmakingService,
	profile: ProfileService.ProfileService,
}

local GameRuntimeService = {}
GameRuntimeService.__index = GameRuntimeService

export type GameRuntimeService = typeof(
	setmetatable({} :: GameRuntimeServiceState, GameRuntimeService)
)

local OBJECTIVE_IDS = { "firewood", "generator", "supplies", "ropes" }
-- Uniquely identifies this server instance in reward receipts (JobId is ""
-- in Studio, where a timestamp keeps separate sessions distinct). Truncated
-- so receiptIds stay within the profile identifier length limit.
local SERVER_REWARD_SALT = if game.JobId == ""
	then string.format("studio-%d", os.time())
	else string.sub(game.JobId, 1, 8)
local SEARCH_LOCATIONS = {
	"main-road-clue-a",
	"residential-bedroom-clue",
	"square-gas-station-clue",
	"industrial-machine-clue",
	"water-tower-base-clue",
	"police-evidence-room-clue",
	"outskirts-company-house-clue",
}
local MONSTER_ORDER: { MonsterId } = require(Shared.Config:WaitForChild("MonsterOrder"))

-- Locked rooms + keys: two night interiors open only for players who found
-- the matching key at a seeded day-camp hiding spot. Keys are personal and
-- purely bonus — evidenceGoal never depends on them.
local LOCKED_ROOM_IDS = { "motel-room-3", "police-evidence-room" }
local ROOM_DISPLAY_NAMES: { [string]: string } = {
	["motel-room-3"] = "Motel Room 3",
	["police-evidence-room"] = "Police Evidence Room",
}
local KEY_PICKUP_LINES: { [string]: string } = {
	["motel-room-3"] = "A brass key stamped MOTEL 3. Hold onto it until dark.",
	["police-evidence-room"] = "A steel key stamped EVIDENCE. Hold onto it until dark.",
}
-- Hiding spot pool: props built by ProductionMapService's day camp.
local KEY_HIDING_SPOTS: { { id: string, position: Vector3, objectText: string } } = {
	{
		id = "pine-mattress",
		position = Vector3.new(-45.5, 2.9, 20.5),
		objectText = "Under the bunk mattress",
	},
	{
		id = "lodge-radio-desk",
		position = Vector3.new(9.5, 3.8, 68.5),
		objectText = "Behind the camp radio",
	},
	{
		id = "creek-footlocker",
		position = Vector3.new(62.5, 2.4, 24.5),
		objectText = "Inside the footlocker",
	},
	{
		id = "boathouse-canoe",
		position = Vector3.new(74.2, 4.1, 68),
		objectText = "Tucked in the racked canoe",
	},
	{
		id = "lookout-desk",
		position = Vector3.new(34, 27.9, -66.2),
		objectText = "Under the fire watch log",
	},
}
-- Cache behind each locked door: one culprit/witness card plus one combo
-- ingredient (or a second monster reading) discovered by the opener.
local LOCKED_ROOM_CACHES: { [string]: { { templateId: string, monster: boolean } } } = {
	["motel-room-3"] = {
		{ templateId = "witness-conflict", monster = false },
		{ templateId = "attack-footprint", monster = false },
	},
	["police-evidence-room"] = {
		{ templateId = "device-reading", monster = true },
		{ templateId = "monster-trace", monster = true },
	},
}
-- Outskirts supply cache: one seeded crate location per round (east district).
local SUPPLY_CACHE_SPOTS: { Vector3 } = {
	Vector3.new(226, 1.3, -262),
	Vector3.new(160, 1.3, -128),
	Vector3.new(210, 1.3, -368),
}

local DEVICE_EVIDENCE: { [EquipmentId]: boolean } = {
	UVLight = true,
	LaserProjector = true,
	Camera = true,
	SpiritBox = true,
	Thermometer = true,
	AudioRecorder = true,
	EMFReader = true,
}

local PHASE_NOTICES: {
	[PhaseName]: {
		kind: string,
		title: string,
		message: string,
	}
} = {
	Lobby = {
		kind = "Info",
		title = "Back at Camp",
		message = "The next mystery is forming. Ready campers will leave together.",
	},
	RoleReveal = {
		kind = "Warning",
		title = "Your Role Is Ready",
		message = "Read your private assignment. Trust is now a limited resource.",
	},
	Day = {
		kind = "Success",
		title = "Daylight Objectives",
		message = "Explore the cabins and finish camp work before the light disappears.",
	},
	MurderPlanning = {
		kind = "Warning",
		title = "Dusk Settles Over Camp",
		message = "Check on a buddy, hand off spare gear, and ask the counselors what they saw. Someone is choosing what happens tonight.",
	},
	NightTransform = {
		kind = "Danger",
		title = "The Town Is Appearing",
		message = "Get to safety. Camp is changing around you.",
	},
	Investigation = {
		kind = "Danger",
		title = "Night Investigation",
		message = "Search buildings, gather evidence, and survive the hunt.",
	},
	Campfire = {
		kind = "Warning",
		title = "Campfire Accusation",
		message = "Review the clues and cast one final vote.",
	},
	Resolution = {
		kind = "Info",
		title = "Mystery Resolution",
		message = "The truth is coming out.",
	},
	Rewards = {
		kind = "Success",
		title = "Round Complete",
		message = "Progress and earned rewards are being recorded.",
	},
}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function actionRejected(reason: string): ActionResult
	return {
		accepted = false,
		reason = reason,
		state = nil,
		data = nil,
	}
end

local function playerRootPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function unobstructed(
	fromPosition: Vector3,
	toPosition: Vector3,
	sourceInstance: Instance?,
	targetInstance: Instance?
): boolean
	local direction = toPosition - fromPosition
	if direction.Magnitude <= 0.01 then
		return true
	end
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.IgnoreWater = true
	local exclusions: { Instance } = {}
	if sourceInstance then
		table.insert(exclusions, sourceInstance)
	end
	parameters.FilterDescendantsInstances = exclusions
	local result = Workspace:Raycast(fromPosition, direction, parameters)
	if not result then
		return true
	end
	if
		targetInstance
		and (
			result.Instance == targetInstance
			or result.Instance:IsDescendantOf(targetInstance)
		)
	then
		return true
	end
	return (result.Position - toPosition).Magnitude <= 1.5
end

local function phaseDuration(phase: PhaseName): number
	for _, config in RoundConfig.phases do
		if config.name == phase then
			local studioDuration = config.studioDurationSeconds
			if RunService:IsStudio() and studioDuration then
				return studioDuration
			end
			return config.durationSeconds
		end
	end
	error("Missing phase configuration for " .. phase)
end

local function campfireDiscussionSeconds(): number
	for _, config in RoundConfig.phases do
		if config.name == "Campfire" then
			local anyConfig = config :: any
			local studioSeconds = anyConfig.studioDiscussionSeconds
			if RunService:IsStudio() and studioSeconds then
				return studioSeconds
			end
			return anyConfig.discussionSeconds or 0
		end
	end
	return 0
end

local function phaseDisplayName(phase: PhaseName): string
	for _, config in RoundConfig.phases do
		if config.name == phase then
			return config.displayName
		end
	end
	return phase
end

local function getString(payload: { [string]: unknown }, key: string): string?
	local value = payload[key]
	return if typeof(value) == "string" and value ~= "" then value else nil
end

local function clonePayload(payload: unknown): { [string]: unknown }
	return if typeof(payload) == "table" then payload :: { [string]: unknown } else {}
end

local function findPlayerForParticipant(participant: ParticipantState): Player?
	if participant.controller.kind ~= "Human" then
		return nil
	end
	return Players:GetPlayerByUserId(participant.controller.userId)
end

local function characterForParticipant(participant: ParticipantState): Model?
	local player = findPlayerForParticipant(participant)
	return if player then player.Character else nil
end

-- Set during construction so bot participants resolve to their visible
-- character models instead of the legacy hash-derived placeholder.
local resolveBotPosition: ((participantId: string) -> Vector3?)? = nil

local function participantPosition(participant: ParticipantState): Vector3?
	local player = findPlayerForParticipant(participant)
	if player then
		return playerRootPosition(player)
	end
	local resolver = resolveBotPosition
	if resolver then
		local botPosition = resolver(participant.participantId)
		if botPosition then
			return botPosition
		end
	end
	local offset = #participant.participantId % 8
	return Vector3.new(offset * 4, 3, -60 - offset * 3)
end

local function voteStagger(participantId: string): number
	local sum = 0
	for index = 1, #participantId do
		sum += string.byte(participantId, index)
	end
	return BotContributionConfig.voteStaggerMinimumSeconds
		+ sum % BotContributionConfig.voteStaggerSpreadSeconds
end

function GameRuntimeService.new(options: RuntimeOptions?): GameRuntimeService
	local configured = options or {}
	local participants = ParticipantService.new()
	local lifecycle = RoundLifecycle.new()
	local inventory = InventoryService.new()
	local statusEffects = StatusEffectService.new()
	local evidence = EvidenceService.new(participants)
	local voting = VotingService.new(participants)
	local botRoster = BotRosterSystem.new(participants)
	local lobby = LobbyService.new()
	local profile = ProfileService.new()
	local runtimeRef: GameRuntimeService? = nil
	local function transferParticipantState(
		source: ParticipantState,
		destination: ParticipantState
	)
		destination.role = source.role
		destination.team = source.team
		destination.alive = source.alive
		destination.isGhost = source.isGhost
		destination.healthState = source.healthState
		destination.health = source.health
		destination.maxHealth = source.maxHealth
		destination.injuryLevel = source.injuryLevel
		destination.evidenceKnowledge = table.clone(source.evidenceKnowledge)
		destination.vote = table.clone(source.vote)
		destination.abilityUses = table.clone(source.abilityUses)
		destination.abilityCooldownEndsAt =
			table.clone(source.abilityCooldownEndsAt)
		inventory:RegisterParticipant(destination.participantId)
		for _, instanceId in table.clone(source.inventoryIds) do
			local transferred = inventory:Transfer(
				source.participantId,
				destination.participantId,
				instanceId
			)
			if transferred then
				participants:RemoveInventoryItem(source.participantId, instanceId)
				participants:AddInventoryItem(destination.participantId, instanceId)
			end
		end
		source.role = "Spectator"
		source.team = "Observers"
		source.alive = false
		source.isGhost = false

		local runtime = runtimeRef
		if not runtime then
			return
		end
		runtime.statusEffects:TransferParticipant(
			source.participantId,
			destination.participantId
		)
		runtime.roleAbilities:TransferParticipant(
			source.participantId,
			destination.participantId
		)
		runtime.voting:TransferParticipant(
			source.participantId,
			destination.participantId
		)
		runtime.mystery:TransferParticipant(
			source.participantId,
			destination.participantId
		)
		runtime.objectivesByParticipantId[destination.participantId] =
			runtime.objectivesByParticipantId[source.participantId]
		runtime.objectivesByParticipantId[source.participantId] = nil
		runtime.evidenceByParticipantId[destination.participantId] =
			runtime.evidenceByParticipantId[source.participantId]
		runtime.evidenceByParticipantId[source.participantId] = nil
		for objectiveId, ownerId in runtime.completedObjectives do
			if ownerId == source.participantId then
				runtime.completedObjectives[objectiveId] = destination.participantId
			end
		end
		local murderPlan = runtime.murderPlan
		if murderPlan then
			if murderPlan.victimParticipantId == source.participantId then
				murderPlan.victimParticipantId = destination.participantId
			end
			if murderPlan.frameParticipantId == source.participantId then
				murderPlan.frameParticipantId = destination.participantId
			end
		end
		-- Personal deduction state (room keys, cold case reads, cache claim)
		-- must follow a control transfer or a rejoining human loses them.
		for roomId, holderId in runtime.keyHolderByRoomId do
			if holderId == source.participantId then
				runtime.keyHolderByRoomId[roomId] = destination.participantId
			end
		end
		local coldCaseReads = runtime.coldCaseReadsByParticipantId[source.participantId]
		if coldCaseReads then
			runtime.coldCaseReadsByParticipantId[destination.participantId] =
				coldCaseReads
			runtime.coldCaseReadsByParticipantId[source.participantId] = nil
		end
		if runtime.coldCaseCompletedByParticipantId[source.participantId] then
			runtime.coldCaseCompletedByParticipantId[destination.participantId] = true
			runtime.coldCaseCompletedByParticipantId[source.participantId] = nil
		end
		if runtime.supplyCacheClaimedBy == source.participantId then
			runtime.supplyCacheClaimedBy = destination.participantId
		end
		if destination.controller.kind == "Bot" then
			runtime.computerPlayers:RegisterBot(destination.participantId)
		end
		if source.controller.kind == "Bot" then
			runtime.computerPlayers:DeactivateBot(source.participantId)
		end
		if runtime.culpritParticipantId == source.participantId then
			runtime.culpritParticipantId = destination.participantId
			runtime.evidence:TransferCulprit(
				source.participantId,
				destination.participantId
			)
			runtime.monster:TransferControl(
				runtime.roundId,
				destination.participantId
			)
		end
	end
	local matchmaking = MatchmakingService.new(lobby, botRoster, {
		onBotReplacement = function(context, replacement, _roster)
			local departed = participants:GetByUserId(context.userId)
			local replacementState = participants:GetById(replacement.participantId)
			if not departed or not replacementState then
				return
			end
			transferParticipantState(departed, replacementState)
			local runtime = runtimeRef
			if runtime then
				runtime:Broadcast()
			end
		end,
		onHumanRejoin = function(player, context, replacement, _human, _roster)
			local rejoined = participants:GetByUserId(context.userId)
			local replacementState = participants:GetById(replacement.participantId)
			if not rejoined or not replacementState then
				return
			end
			transferParticipantState(replacementState, rejoined)
			participants:SetHumanConnected(context.userId, true)
			print(string.format(
				"[GameRuntimeService] Rejoined user %d as %s",
				context.userId,
				rejoined.role
			))
			local runtime = runtimeRef
			if runtime then
				task.defer(function()
					if runtime.running and player.Parent == Players then
						local callback = runtime.options.onStateChanged
						if callback then
							callback(player, runtime:GetGameState(player))
						end
					end
				end)
			end
		end,
	})

	local mapService = ProductionMapService.new(
		function(player: Player, objectiveId: string)
			local runtime = runtimeRef
			if runtime then
				runtime:HandleAction(player, "CompleteObjective", {
					objectiveId = objectiveId,
				})
			end
		end,
		function(player: Player, evidenceId: string): boolean
			local runtime = runtimeRef
			if not runtime then
				return false
			end
			local result = runtime:HandleAction(player, "DiscoverEvidence", {
				evidenceId = evidenceId,
			})
			return result.accepted
		end
	)

	local world = WorldService.new(mapService, {
		relocateAtTransformMidpoint = function(_context)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if character then
					character:PivotTo(CFrame.new(0, 5, 25))
				end
			end
		end,
	})
	local characters = CharacterAssetService.new()
	resolveBotPosition = function(participantId: string): Vector3?
		return characters:GetBotCharacterPosition(participantId)
	end
	local counselors = CounselorService.new({
		canInteract = function(participantId: string, counselorId: string): boolean
			local runtime = runtimeRef
			local participant = participants:GetById(participantId)
			local active = runtime ~= nil
				and participant ~= nil
				and participant.alive
				and not participant.isGhost
				and (
					runtime.phase == "Day"
					or runtime.phase == "MurderPlanning"
					or runtime.phase == "Investigation"
					or runtime.phase == "Campfire"
				)
			if not active or not participant then
				return false
			end
			local participantAt = participantPosition(participant)
			local counselorAt = characters:GetCounselorPosition(counselorId)
			local sourceCharacter: Instance? = characterForParticipant(participant)
			if participant.controller.kind == "Bot" then
				sourceCharacter = characters:GetBotCharacterModel(participant.participantId)
			end
			local counselorModel = characters:GetCounselorModel(counselorId)
			return participantAt ~= nil
				and counselorAt ~= nil
				and (counselorAt - participantAt).Magnitude <= 18
				and unobstructed(
					participantAt,
					counselorAt,
					sourceCharacter,
					counselorModel
				)
		end,
		onContradictionSlip = function(participantId: string, counselorId: string)
			local runtime = runtimeRef
			if runtime then
				runtime:_onContradictionSlip(participantId, counselorId)
			end
		end,
	})
	local mystery = MysteryService.new({
		canDiscover = function(participantId: string, _clueId: string, _locationId: string): boolean
			local runtime = runtimeRef
			local participant = participants:GetById(participantId)
			return runtime ~= nil
				and runtime.phase == "Investigation"
				and participant ~= nil
				and participant.alive
				and not participant.isGhost
		end,
		canInterview = function(participantId: string, counselorId: string): boolean
			local runtime = runtimeRef
			if not runtime then
				return false
			end
			local participant = participants:GetById(participantId)
			local counselor = counselors:GetPrivateSnapshot(counselorId)
			return participant ~= nil
				and participant.alive
				and not participant.isGhost
				and counselor ~= nil
				and counselor.interactionAllowed
		end,
	})

	local combatRef: CombatService.CombatService? = nil
	local roleAbilities = RoleAbilityService.new(
		participants,
		lifecycle,
		function(): string
			local runtime = runtimeRef
			return if runtime then runtime.phase else "Lobby"
		end,
		function(guardParticipantId: string, attackerParticipantId: string)
			local combat = combatRef
			if combat then
				combat:ApplyInjury(
					guardParticipantId,
					"Guard interception",
					attackerParticipantId
				)
			end
		end,
		nil,
		function(participantId: string, upgradeId: string): number
			local participant = participants:GetById(participantId)
			if not participant or participant.controller.kind ~= "Human" then
				return 0
			end
			local player = Players:GetPlayerByUserId(participant.controller.userId)
			local snapshot = if player then profile:GetSnapshot(player) else nil
			local roleUpgrades = if snapshot
				then snapshot.profile.upgrades[participant.role]
				else nil
			return if roleUpgrades then roleUpgrades[upgradeId] or 0 else 0
		end
	)

	local combat = CombatService.new(
		participants,
		inventory,
		lifecycle,
		function(): string
			local runtime = runtimeRef
			return if runtime then runtime.phase else "Lobby"
		end,
		function(
			attacker: ParticipantState,
			target: ParticipantState,
			request: CombatTypes.AttackRequest
		): CombatTypes.DefenseResult
			return roleAbilities:ResolveDefense(attacker, target, request)
		end,
		function(
			evidenceKind: string,
			attacker: ParticipantState,
			target: ParticipantState,
			request: CombatTypes.AttackRequest
		)
			local runtime = runtimeRef
			if runtime then
				runtime:_CreateAttackEvidence(
					evidenceKind,
					attacker,
					target,
					request
				)
			end
		end,
		function(target: ParticipantState): boolean
			local runtime = runtimeRef
			if not runtime then
				return false
			end
			return runtime:_isCampfireProtected(target)
		end
	)
	combatRef = combat

	local monster = MonsterService.new({
		getPhase = function(): string
			local runtime = runtimeRef
			return if runtime then runtime.phase else "Lobby"
		end,
		getPosition = function(participantId: string): Vector3?
			local participant = participants:GetById(participantId)
			if not participant then
				return nil
			end
			return participantPosition(participant)
		end,
		isTargetable = function(participantId: string): boolean
			local participant = participants:GetById(participantId)
			return participant ~= nil
				and participant.alive
				and not participant.isGhost
				and participant.team == "Campers"
		end,
			hasLineOfSight = function(
				fromPosition: Vector3,
				toPosition: Vector3,
				sourceParticipantId: string,
				targetParticipantId: string?
			): boolean
				local source = participants:GetById(sourceParticipantId)
				local target = if targetParticipantId
					then participants:GetById(targetParticipantId)
					else nil
				return unobstructed(
					fromPosition,
					toPosition,
					if source then characterForParticipant(source) else nil,
					if target then characterForParticipant(target) else nil
				)
			end,
		applyAttack = function(
			sourceParticipantId: string,
			targetParticipantId: string,
			_amount: number,
			abilityId: string
		)
			local runtime = runtimeRef
			if runtime then
				runtime:_ApplyMonsterAttack(
					sourceParticipantId,
					targetParticipantId,
					abilityId
				)
			end
		end,
		applyStatus = function(
			sourceParticipantId: string,
			targetParticipantId: string,
			statusId: MonsterStatusId,
			durationSeconds: number,
			abilityId: string
		)
			statusEffects:Apply(
				targetParticipantId,
				statusId,
				durationSeconds,
				sourceParticipantId,
				abilityId
			)
		end,
		emitEvidence = function(
			monsterId: MonsterId,
			_evidenceId: MonsterTypes.EvidenceId,
			_position: Vector3,
			_sourceParticipantId: string
		)
			local runtime = runtimeRef
			if runtime then
				runtime:_CreateMonsterEvidence(monsterId)
			end
		end,
		applyMobility = function(
			participantId: string,
			_movementId: string,
			targetPosition: Vector3,
			_abilityId: string
		)
			local participant = participants:GetById(participantId)
			local player = if participant then findPlayerForParticipant(participant) else nil
			local character = if player then player.Character else nil
			if character then
				character:PivotTo(CFrame.new(targetPosition + Vector3.new(0, 3, 0)))
			end
		end,
	})

	local computerPlayers = ComputerPlayerService.new(participants, {
		getAvailableActions = function(
			participant: ParticipantState,
			context
		)
			local runtime = runtimeRef
			return if runtime
				then runtime:_GetBotActions(participant, context.phase)
				else {}
		end,
		executeAction = function(
			participant: ParticipantState,
			candidate,
			_context
		): boolean
			local runtime = runtimeRef
			return runtime ~= nil and runtime:_ExecuteBotAction(participant, candidate)
		end,
	})

	local initialNow = now()
	local self: GameRuntimeService = setmetatable({
		options = configured,
		running = false,
		generation = 0,
		roundId = 0,
		phase = "Lobby",
		phaseStartedAt = initialNow,
		phaseEndsAt = initialNow,
		winner = nil,
		resultMessage = nil,
		victimName = nil,
		culpritParticipantId = nil,
		murderPlan = nil,
		completedObjectives = {},
		objectivesByParticipantId = {},
		evidenceByParticipantId = {},
		evidenceLocationById = {},
		evidenceAliasById = {},
		mysteryClueIdsByLocation = {},
		mysteryReady = false,
		activeComboRecipes = {},
		usedComboRecipeIds = {},
		comboCooldownAt = {},
		contradictionEvidenceIssued = false,
		coldCaseFiles = {},
		coldCaseReadsByParticipantId = {},
		coldCaseCompletedByParticipantId = {},
		keyHolderByRoomId = {},
		openedRoomIds = {},
		supplyCacheClaimedBy = nil,
		activeMatchRoundId = nil,
		connections = {},
		participants = participants,
		lifecycle = lifecycle,
		inventory = inventory,
		combat = combat,
		evidence = evidence,
		mystery = mystery,
		counselors = counselors,
		monster = monster,
		world = world,
		map = mapService,
		statusEffects = statusEffects,
		roleAbilities = roleAbilities,
		voting = voting,
		characters = characters,
		botRoster = botRoster,
		computerPlayers = computerPlayers,
		lobby = lobby,
		matchmaking = matchmaking,
		profile = profile,
	}, GameRuntimeService)
	runtimeRef = self
	mapService:SetKeyPickupHandler(function(player: Player, keyId: string): boolean
		local runtime = runtimeRef
		if not runtime then
			return false
		end
		return runtime:_pickupRoomKey(player, keyId)
	end)
	mapService:SetLockedRoomHandler(
		function(player: Player, roomId: string): (boolean, string?)
			local runtime = runtimeRef
			if not runtime then
				return false, nil
			end
			return runtime:_openLockedRoom(player, roomId)
		end
	)
	mapService:SetColdCaseHandler(function(player: Player, fileIndex: number): string?
		local runtime = runtimeRef
		if not runtime then
			return nil
		end
		return runtime:_inspectColdCase(player, fileIndex)
	end)
	mapService:SetSupplyCacheHandler(function(player: Player): (boolean, string?)
		local runtime = runtimeRef
		if not runtime then
			return false, nil
		end
		return runtime:_openSupplyCache(player)
	end)
	lifecycle:On("ParticipantGhostTransition", function()
		local runtime = runtimeRef
		if runtime and runtime.running then
			runtime:Broadcast()
		end
	end)
	lifecycle:On("ParticipantEliminated", function(event)
		local runtime = runtimeRef
		if not runtime then
			return
		end
		local participantId = event.payload.participantId
		if type(participantId) == "string" then
			runtime.characters:PlayBotDeath(participantId)
			if runtime.phase == "Investigation" then
				local victim = runtime.participants:GetById(participantId)
				if victim and victim.team == "Campers" then
					local position = participantPosition(victim)
					if position then
						runtime.characters:SpawnBodyMarker(
							participantId,
							victim.displayName,
							position,
							function(reporter: Player)
								local currentRuntime = runtimeRef
								if currentRuntime then
									currentRuntime:_reportBody(reporter, participantId)
								end
							end
						)
					end
				end
			end
		end
	end)
	lifecycle:On("ParticipantInjured", function(event)
		local runtime = runtimeRef
		if not runtime then
			return
		end
		local participantId = event.payload.participantId
		if type(participantId) == "string" then
			runtime.characters:ShowBotInjured(participantId)
		end
	end)
	lifecycle:On("ParticipantCritical", function(event)
		local runtime = runtimeRef
		if not runtime then
			return
		end
		local participantId = event.payload.participantId
		if type(participantId) == "string" then
			runtime.characters:ShowBotInjured(participantId)
		end
	end)
	return self
end

function GameRuntimeService:_announce(
	kind: string,
	title: string,
	message: string,
	duration: number?
)
	local callback = self.options.onAnnouncement
	if callback then
		callback(kind, title, message, duration)
	end
end

function GameRuntimeService:_createHuman(player: Player)
	self.participants:CreateHuman(player.UserId, player.DisplayName)
end

function GameRuntimeService:_readyStudioPlayers()
	if not RunService:IsStudio() then
		return
	end
	for _, player in Players:GetPlayers() do
		if not self.lobby:IsReady(player) then
			self.matchmaking:SetReady(player, true)
		end
	end
end

function GameRuntimeService:_participantForPlayer(player: Player): ParticipantState?
	return self.participants:GetByUserId(player.UserId)
end

function GameRuntimeService:_participantIdsForRound(): { string }
	local roster = self.matchmaking:GetActiveRoster()
	if not roster then
		self:_readyStudioPlayers()
		if RunService:IsStudio() and self.lobby:GetReadyCount() >= MatchConfig.minimumHumans then
			roster = self.matchmaking:ForceLock()
		else
			roster = self.matchmaking:Tick()
		end
	end
	if not roster then
		return {}
	end
	self.activeMatchRoundId = roster.roundId
	local ids: { string } = {}
	for _, rosterParticipant in roster.participants do
		if rosterParticipant.controllerKind == "Human" then
			local userId = rosterParticipant.userId
			local participant = if userId then self.participants:GetByUserId(userId) else nil
			if participant then
				table.insert(ids, participant.participantId)
			end
		else
			table.insert(ids, rosterParticipant.participantId)
		end
	end
	return ids
end

function GameRuntimeService:_findCulprit(): ParticipantState
	for _, participant in self.participants:GetAll() do
		if participant.role == "Murderer" then
			return participant
		end
	end
	error("Role assignment did not produce a Murderer")
end

function GameRuntimeService:_defaultFrameTarget(culpritId: string): string?
	for _, participant in self.participants:GetAll() do
		if participant.participantId ~= culpritId and participant.team == "Campers" then
			return participant.participantId
		end
	end
	return nil
end

function GameRuntimeService:_defaultVictim(culpritId: string): string
	local candidates: { string } = {}
	for _, participant in self.participants:GetAll() do
		if
			participant.participantId ~= culpritId
			and participant.team == "Campers"
			and participant.alive
		then
			table.insert(candidates, participant.participantId)
		end
	end
	assert(#candidates > 0, "Round needs at least one Camper target")
	return candidates[((self.roundId - 1) % #candidates) + 1]
end

function GameRuntimeService:_grantLoadout(participant: ParticipantState)
	local loadout: { EquipmentId } = { "Flashlight" }
	if participant.role == "Detective" then
		table.insert(loadout, "UVLight")
		table.insert(loadout, "Camera")
	elseif participant.role == "Medic" then
		table.insert(loadout, "MedicalKit")
		table.insert(loadout, "MedicalKit")
	elseif participant.role == "Trapper" then
		table.insert(loadout, "MonsterTrap")
		table.insert(loadout, "MonsterTrap")
	elseif participant.role == "Medium" then
		table.insert(loadout, "SpiritBox")
	elseif participant.role == "Guard" or participant.role == "Protector" then
		table.insert(loadout, "FlareLantern")
	elseif participant.role == "Camper" then
		table.insert(loadout, "EMFReader")
		-- Resourceful Packing: FlareLantern is the only starting supply without a
		-- role-gated use path, so extra ranks stay an ordinary-item benefit.
		for _ = 1, self:_getUpgradeRank(participant.participantId, "resourceful-packing") do
			table.insert(loadout, "FlareLantern")
		end
	end

	for _, equipmentId in loadout do
		local granted, instanceId = self.inventory:Grant(
			participant.participantId,
			equipmentId
		)
		if granted and instanceId then
			self.participants:AddInventoryItem(participant.participantId, instanceId)
		end
	end
	local snapshot = self.inventory:GetSnapshot(participant.participantId)
	if snapshot.items[1] then
		self.inventory:Equip(participant.participantId, snapshot.items[1].instanceId)
	end
end

function GameRuntimeService:_assignEvidenceLocations()
	self.evidenceLocationById = {}
	self.evidenceAliasById = {}
	local records = self.evidence:GetAllServer()
	for index, record in records do
		local locationId = SEARCH_LOCATIONS[((index - 1) % #SEARCH_LOCATIONS) + 1]
		self.evidenceLocationById[record.evidenceId] = locationId
		self.evidenceAliasById[locationId] = record.evidenceId
	end
end

function GameRuntimeService:_getUpgradeRank(
	participantId: string,
	upgradeId: string
): number
	local participant = self.participants:GetById(participantId)
	if not participant or participant.controller.kind ~= "Human" then
		return 0
	end
	local player = Players:GetPlayerByUserId(participant.controller.userId)
	if not player then
		return 0
	end
	return self.profile:GetUpgradeRank(player, participant.role, upgradeId)
end

function GameRuntimeService:_beginMystery(seed: number?)
	if self.mysteryReady then
		return
	end
	local culpritId = self.culpritParticipantId
	local plan = self.murderPlan
	assert(culpritId and plan, "Mystery requires a culprit and a locked murder plan")

	local participantSuspects: { string } = {}
	for _, participant in self.participants:GetAll() do
		if participant.role ~= "Spectator" then
			table.insert(participantSuspects, participant.participantId)
		end
	end
	local counselorSnapshot = self.counselors:GetPublicSnapshot()
	local counselorIds: { string } = {}
	for _, counselor in counselorSnapshot.counselors do
		table.insert(counselorIds, counselor.counselorId)
	end

	local mysterySuspects = table.clone(participantSuspects)
	local counselorIndex = 1
	while #mysterySuspects < 4 and counselorIds[counselorIndex] do
		table.insert(mysterySuspects, counselorIds[counselorIndex])
		counselorIndex += 1
	end
	-- Controlled Trace only sharpens a frame the Murderer deliberately planted;
	-- the default frame target assigned at round start gets no benefit.
	local culprit = self.participants:GetById(culpritId)
	local frameSharpness = 0
	if culprit and (culprit.abilityUses["plant-false-evidence"] or 0) >= 1 then
		frameSharpness = self:_getUpgradeRank(culpritId, "controlled-trace")
	end

	local privateMystery = self.mystery:BeginRound({
		roundId = self.roundId,
		roundSeed = seed or self.roundId,
		culpritParticipantId = culpritId,
		monsterId = plan.monsterId,
		suspectIds = mysterySuspects,
		counselorIds = counselorIds,
		frameTargetId = plan.frameParticipantId,
		frameSharpness = frameSharpness,
	})

	self.mysteryClueIdsByLocation = {}
	for _, placement in self.mystery:GetSearchPlacements() do
		local atLocation = self.mysteryClueIdsByLocation[placement.locationId]
		if not atLocation then
			atLocation = {}
			self.mysteryClueIdsByLocation[placement.locationId] = atLocation
		end
		table.insert(atLocation, placement.clueId)
	end
	for _, account in privateMystery.witnessAccounts do
		self.counselors:AssignWitnessAccount(
			account.counselorId,
			account.accountId,
			account.templateId,
			now()
		)
	end
	self.mysteryReady = true
	self:_seedDeductionDepth(seed or self.roundId)
end

-- Seeds the round's combo recipes and cold case files once the mystery is
-- fixed. Both layers are optional depth: rounds resolve identically if no
-- player ever touches them.
function GameRuntimeService:_seedDeductionDepth(seedValue: number)
	local comboRandom = Random.new(seedValue + self.roundId * 7477 + 1049)
	local recipePool = table.clone(EvidenceComboRules.recipes)
	for index = #recipePool, 2, -1 do
		local swapIndex = comboRandom:NextInteger(1, index)
		recipePool[index], recipePool[swapIndex] =
			recipePool[swapIndex], recipePool[index]
	end
	self.activeComboRecipes = {}
	for index = 1, math.min(EvidenceComboRules.recipesPerRound, #recipePool) do
		table.insert(self.activeComboRecipes, recipePool[index])
	end
	self.usedComboRecipeIds = {}

	-- Cold cases come from mystery titles NOT chosen this round; one file is
	-- the true monster written as an old sighting, one echoes its habits, and
	-- one profiles the murderer archetype.
	local plan = self.murderPlan
	local monsterId: string = if plan then plan.monsterId else "BabyAlien"
	local currentTitle = if self.mysteryReady
		then self.mystery:GetPublicSnapshot().title
		else ""
	local unusedTitles: { string } = {}
	for _, title in MysteryCatalog.titles do
		if title ~= currentTitle then
			table.insert(unusedTitles, title)
		end
	end
	local caseRandom = Random.new(seedValue + self.roundId * 5407 + 733)
	for index = #unusedTitles, 2, -1 do
		local swapIndex = caseRandom:NextInteger(1, index)
		unusedTitles[index], unusedTitles[swapIndex] =
			unusedTitles[swapIndex], unusedTitles[index]
	end
	local sighting = ColdCaseArchive.monsterSightings[monsterId]
		or "The file is water-damaged; only the year is still legible."
	local echo = ColdCaseArchive.monsterEchoes[monsterId]
		or "The follow-up page is missing from the folder."
	local pattern = ColdCaseArchive.culpritPatterns[
		caseRandom:NextInteger(1, #ColdCaseArchive.culpritPatterns)
	]
	local files: { ColdCaseFile } = {
		{ title = unusedTitles[1] or "The Missing File", summary = sighting },
		{ title = unusedTitles[2] or "The Water-Stained File", summary = echo },
		{ title = unusedTitles[3] or "The Sealed File", summary = pattern },
	}
	for index = #files, 2, -1 do
		local swapIndex = caseRandom:NextInteger(1, index)
		files[index], files[swapIndex] = files[swapIndex], files[index]
	end
	self.coldCaseFiles = files
end

-- Two room keys hide at seeded day-camp spots drawn from a fixed prop pool.
function GameRuntimeService:_spawnRoundKeys()
	local keyRandom = Random.new(
		self.world:GetPublicSnapshot().roundSeed + self.roundId * 2657 + 389
	)
	local spotPool = table.clone(KEY_HIDING_SPOTS)
	for index = #spotPool, 2, -1 do
		local swapIndex = keyRandom:NextInteger(1, index)
		spotPool[index], spotPool[swapIndex] = spotPool[swapIndex], spotPool[index]
	end
	local spots: { ProductionMapService.KeySpot } = {}
	for index, roomId in LOCKED_ROOM_IDS do
		local spot = spotPool[index]
		if spot then
			table.insert(spots, {
				keyId = roomId,
				position = spot.position,
				objectText = spot.objectText,
				pickupLine = KEY_PICKUP_LINES[roomId] or "You pocket a small key.",
			})
		end
	end
	self.map:SpawnDayKeys(spots)
end

-- Creates an evidence record and immediately posts it to the shared board as
-- discovered by the given participant. Used by insights, the contradiction
-- hook, and locked-room caches; never by the baseline search flow.
function GameRuntimeService:_grantDiscoveredEvidence(
	participant: ParticipantState,
	templateId: string,
	locationId: string,
	authenticity: EvidenceAuthenticity?,
	suspectWeights: { [string]: number }?,
	monsterWeights: { [string]: number }?,
	descriptionOverride: string?
): EvidenceRecord?
	local record = self.evidence:Create(
		templateId,
		authenticity,
		suspectWeights,
		monsterWeights
	)
	if descriptionOverride then
		record.description = descriptionOverride
	end
	local discovered = self.evidence:Discover(
		participant.participantId,
		record.evidenceId,
		locationId,
		now()
	)
	if not discovered then
		return nil
	end
	self.participants:RecordEvidenceKnowledge(participant.participantId, {
		evidenceId = record.evidenceId,
		displayName = record.displayName,
		confidence = 0.65,
		isShared = true,
		learnedAt = now(),
	})
	self.evidenceByParticipantId[participant.participantId] =
		(self.evidenceByParticipantId[participant.participantId] or 0) + 1
	return record
end

-- Contradiction evidence hook: the first player to press the seeded
-- counselor into changing their story earns a shared witness card, once per
-- round, attributed to that counselor.
function GameRuntimeService:_onContradictionSlip(
	participantId: string,
	counselorId: string
)
	if self.contradictionEvidenceIssued or self.roundId == 0 then
		return
	end
	local participant = self.participants:GetById(participantId)
	if not participant or not participant.alive or participant.isGhost then
		return
	end
	local counselorName = counselorId
	for _, counselor in self.counselors:GetPublicSnapshot().counselors do
		if counselor.counselorId == counselorId then
			counselorName = counselor.displayName
			break
		end
	end
	local record = self:_grantDiscoveredEvidence(
		participant,
		"witness-story-change",
		"counselor-interview",
		"Ambiguous",
		nil,
		nil,
		string.format(
			"%s's account of the evening changed under repeat questioning. Their posted schedule disagrees with the first story.",
			counselorName
		)
	)
	if record then
		self.contradictionEvidenceIssued = true
		self:_announce(
			"Info",
			"The story changed",
			string.format(
				"%s caught %s changing their story. The slip is on the evidence board.",
				participant.displayName,
				counselorName
			),
			5
		)
	end
end

function GameRuntimeService:_pickupRoomKey(player: Player, keyId: string): boolean
	local participant = self:_validateActiveParticipant(
		self:_participantForPlayer(player)
	)
	if not participant or self.phase ~= "Day" then
		return false
	end
	if self.keyHolderByRoomId[keyId] then
		return false
	end
	self.keyHolderByRoomId[keyId] = participant.participantId
	return true
end

function GameRuntimeService:_openLockedRoom(
	player: Player,
	roomId: string
): (boolean, string?)
	local participant = self:_validateActiveParticipant(
		self:_participantForPlayer(player)
	)
	if not participant then
		return false, nil
	end
	if self.phase ~= "Investigation" then
		return false, "The door does not budge. Come back during the night investigation."
	end
	if self.openedRoomIds[roomId] then
		return false, nil
	end
	if self.keyHolderByRoomId[roomId] ~= participant.participantId then
		return false, "Locked tight. The key was hidden somewhere in camp during the day."
	end
	local cacheEntries = LOCKED_ROOM_CACHES[roomId]
	if not cacheEntries then
		return false, nil
	end
	self.openedRoomIds[roomId] = true
	local culpritId = self.culpritParticipantId
	local plan = self.murderPlan
	local grantedNames: { string } = {}
	for _, entry in cacheEntries do
		local suspectWeights: { [string]: number }? = nil
		local monsterWeights: { [string]: number }? = nil
		if entry.monster then
			if plan then
				monsterWeights = { [plan.monsterId] = 0.6 }
			end
		elseif culpritId then
			suspectWeights = { [culpritId] = 0.55 }
		end
		local record = self:_grantDiscoveredEvidence(
			participant,
			entry.templateId,
			roomId,
			nil,
			suspectWeights,
			monsterWeights,
			nil
		)
		if record then
			table.insert(grantedNames, record.displayName)
		end
	end
	self:_announce(
		"Success",
		"A locked room opens",
		string.format(
			"%s unlocked the %s and recovered: %s.",
			participant.displayName,
			ROOM_DISPLAY_NAMES[roomId] or roomId,
			table.concat(grantedNames, ", ")
		),
		6
	)
	self:Broadcast()
	return true, "The key turns. Fresh evidence goes straight to the board."
end

function GameRuntimeService:_inspectColdCase(
	player: Player,
	fileIndex: number
): string?
	local participant = self:_validateActiveParticipant(
		self:_participantForPlayer(player)
	)
	if not participant then
		return nil
	end
	if self.phase ~= "Investigation" then
		return "The cabinet drawer is jammed. It only gives during the night investigation."
	end
	local file = self.coldCaseFiles[fileIndex]
	if not file then
		return nil
	end
	local reads = self.coldCaseReadsByParticipantId[participant.participantId]
	if not reads then
		reads = {}
		self.coldCaseReadsByParticipantId[participant.participantId] = reads
	end
	reads[fileIndex] = true
	local readCount = 0
	for _ in reads do
		readCount += 1
	end
	if
		#self.coldCaseFiles > 0
		and readCount >= #self.coldCaseFiles
		and not self.coldCaseCompletedByParticipantId[participant.participantId]
	then
		self.coldCaseCompletedByParticipantId[participant.participantId] = true
		self:_announce(
			"Success",
			"Cold cases reviewed",
			participant.displayName
				.. " studied every cold case. The old files sharpen their instincts.",
			5
		)
	end
	return string.format("COLD CASE — %s (unsolved)\n%s", file.title, file.summary)
end

function GameRuntimeService:_openSupplyCache(player: Player): (boolean, string?)
	local participant = self:_validateActiveParticipant(
		self:_participantForPlayer(player)
	)
	if not participant then
		return false, nil
	end
	if self.phase ~= "Investigation" then
		return false, "The lid will not move yet."
	end
	if self.supplyCacheClaimedBy then
		return false, "Already emptied. Someone got here first."
	end
	self.supplyCacheClaimedBy = participant.participantId
	-- Mirrors the secured-supplies consequence: a FlareLantern granted through
	-- the standard inventory path.
	local granted, instanceId = self.inventory:Grant(
		participant.participantId,
		"FlareLantern"
	)
	if granted and instanceId then
		self.participants:AddInventoryItem(participant.participantId, instanceId)
	end
	self:Broadcast()
	return true,
		participant.displayName .. " pried the cache open: one flare lantern, still good."
end

-- Detective-only combine: two owned evidence cards matching a seeded recipe
-- become a shared Insight card. Invalid pairs get a gentle cooldown.
function GameRuntimeService:_combineEvidence(
	participant: ParticipantState,
	payload: { [string]: unknown }
): ActionResult
	if participant.role ~= "Detective" then
		return actionRejected("Only the Detective can combine evidence")
	end
	if self.phase ~= "Investigation" and self.phase ~= "Campfire" then
		return actionRejected("Combinations happen at night or at the campfire")
	end
	if #self.activeComboRecipes == 0 then
		return actionRejected("No combinations are possible before the mystery takes shape")
	end
	local firstId = getString(payload, "evidenceIdA")
		or getString(payload, "firstEvidenceId")
	local secondId = getString(payload, "evidenceIdB")
		or getString(payload, "secondEvidenceId")
	if not firstId or not secondId then
		return actionRejected("Two evidence cards are required")
	end
	if firstId == secondId then
		return actionRejected("Pick two different evidence cards")
	end
	local cooldownEndsAt = self.comboCooldownAt[participant.participantId]
	if cooldownEndsAt and now() < cooldownEndsAt then
		return actionRejected("Give it a moment before trying another combination")
	end
	local firstRecord = self.evidence:GetRecordServer(firstId)
	local secondRecord = self.evidence:GetRecordServer(secondId)
	if
		not firstRecord
		or not secondRecord
		or not firstRecord.posted
		or not secondRecord.posted
	then
		return actionRejected("Both cards must be on the evidence board")
	end
	local participantId = participant.participantId
	if
		not table.find(firstRecord.chainOfCustody, participantId)
		or not table.find(secondRecord.chainOfCustody, participantId)
	then
		return actionRejected("Discover or verify a card before combining it")
	end
	local matched: ComboRecipe? = nil
	for _, recipe in self.activeComboRecipes do
		if not self.usedComboRecipeIds[recipe.id] then
			local wantA = recipe.inputTemplateIds[1]
			local wantB = recipe.inputTemplateIds[2]
			if
				(firstRecord.templateId == wantA and secondRecord.templateId == wantB)
				or (firstRecord.templateId == wantB and secondRecord.templateId == wantA)
			then
				matched = recipe
				break
			end
		end
	end
	if not matched then
		self.comboCooldownAt[participantId] = now()
			+ EvidenceComboRules.invalidComboCooldownSeconds
		return actionRejected("Those clues do not fit together. Take a breath and look again.")
	end
	local suspectWeights: { [string]: number }? = nil
	local culpritId = self.culpritParticipantId
	if culpritId then
		suspectWeights = { [culpritId] = 0.5 }
	end
	local insight = self:_grantDiscoveredEvidence(
		participant,
		matched.insightTemplateId,
		"combined-insight",
		"Real",
		suspectWeights,
		nil,
		nil
	)
	if not insight then
		return actionRejected("The insight could not be recorded")
	end
	self.usedComboRecipeIds[matched.id] = true
	self:_announce(
		"Success",
		"Insight uncovered",
		string.format(
			"%s connected two clues: %s",
			participant.displayName,
			insight.displayName
		),
		5
	)
	return {
		accepted = true,
		reason = nil,
		state = nil,
		data = {
			evidenceId = insight.evidenceId,
			recipeId = matched.id,
		},
	}
end

function GameRuntimeService:_discoverMysteryAtLocation(
	participantId: string,
	locationId: string
): { MysteryTypes.PublicMysteryClue }
	local revealed: { MysteryTypes.PublicMysteryClue } = {}
	if not self.mysteryReady then
		return revealed
	end
	local clueIds = self.mysteryClueIdsByLocation[locationId]
	if not clueIds then
		return revealed
	end
	for _, clueId in clueIds do
		local discovered = self.mystery:DiscoverClue(participantId, clueId, now())
		if discovered then
			for _, clue in self.mystery:GetPublicSnapshot().clues do
				if clue.clueId == clueId then
					table.insert(revealed, clue)
					break
				end
			end
		end
	end
	return revealed
end

function GameRuntimeService:_selectRoundMonster(roundId: number, seed: number?): MonsterId
	-- Random pick excluding last round's monster so fresh servers do not
	-- always open with the same monster; explicit seeds stay reproducible.
	local pool: { MonsterId } = {}
	for _, candidateId in MONSTER_ORDER do
		if candidateId ~= self.lastMonsterId then
			table.insert(pool, candidateId)
		end
	end
	local rng = Random.new((seed or os.time()) + roundId * 7919)
	local monsterId = pool[rng:NextInteger(1, #pool)]
	self.lastMonsterId = monsterId
	return monsterId
end

function GameRuntimeService:BeginRound(
	participantIds: { string }?,
	seed: number?
): number
	self.roundId += 1
	local roundId = self.roundId
	local selectedIds = participantIds or self:_participantIdsForRound()
	assert(#selectedIds >= 2, "A production round requires at least two participants")
	self.lifecycle:BeginRound(roundId)
	self.participants:ResetRound(selectedIds)
	self.inventory:BeginRound(roundId)
	self.statusEffects:BeginRound(roundId)
	self.roleAbilities:BeginRound(roundId)
	self.voting:BeginRound(roundId)
	self.combat:BeginRound(roundId)
	self.world:PrepareRound(roundId, seed)
	self.characters:Reset()
	self.counselors:BeginRound(roundId, seed)
	self.characters:ApplyCounselorSnapshot(self.counselors:GetPublicSnapshot())

	self.winner = nil
	self.resultMessage = nil
	self.victimName = nil
	self.completedObjectives = {}
	self.objectivesByParticipantId = {}
	self.evidenceByParticipantId = {}
	self.murderPlan = nil
	self.mysteryReady = false
	self.mysteryClueIdsByLocation = {}
	self.botTaskById = {}
	self.botObjectiveCount = 0
	self.botEvidenceCount = 0
	self.votingOpensAt = nil
	self.dayOutcomes = nil
	self.campfireStage = nil
	self.discussionLog = {}
	self.presentedSuspicion = {}
	self.presentedItems = {}
	self.presentedCountByParticipantId = {}
	self.checkInPairs = {}
	self.checkInsByParticipantId = {}
	self.bodyReportedByVictimId = {}
	self.ghostFlickerAt = {}
	self.activeComboRecipes = {}
	self.usedComboRecipeIds = {}
	self.comboCooldownAt = {}
	self.contradictionEvidenceIssued = false
	self.coldCaseFiles = {}
	self.coldCaseReadsByParticipantId = {}
	self.coldCaseCompletedByParticipantId = {}
	self.keyHolderByRoomId = {}
	self.openedRoomIds = {}
	self.supplyCacheClaimedBy = nil
	self.characters:ClearBodyMarkers()

	for _, participantId in selectedIds do
		self.inventory:RegisterParticipant(participantId)
		local participant = self.participants:GetById(participantId)
		if participant then
			self:_grantLoadout(participant)
		end
	end

	local culprit = self:_findCulprit()
	self.culpritParticipantId = culprit.participantId
	local monsterId = self:_selectRoundMonster(roundId, seed)
	self.monster:SelectForRound(roundId, culprit.participantId, monsterId)
	self.evidence:BeginRound(roundId, culprit.participantId, monsterId, seed)
	local frameTarget = self:_defaultFrameTarget(culprit.participantId)
	self.evidence:GenerateBaselineMystery(frameTarget)
	self:_assignEvidenceLocations()
	self.murderPlan = {
		victimParticipantId = self:_defaultVictim(culprit.participantId),
		frameParticipantId = frameTarget,
		locationId = "industrial-factory-monster",
		monsterId = monsterId,
	}

	self.computerPlayers:BeginRound(roundId, selectedIds)
	self.computerPlayers:Start(
		function(): PhaseName
			return self.phase
		end,
		function(): number
			return self.roundId
		end
	)

	-- Spawn visible characters for each bot participant near the camp entrance
	local botSpawnRing: { CFrame } = {
		CFrame.new(-8, 3, 12),  CFrame.new(8, 3, 12),  CFrame.new(-5, 3, 18),
		CFrame.new(5, 3, 18),   CFrame.new(-12, 3, 6), CFrame.new(12, 3, 6),
		CFrame.new(0, 3, 22),   CFrame.new(-9, 3, 22), CFrame.new(9, 3, 22),
		CFrame.new(-4, 3, 28),  CFrame.new(4, 3, 28),  CFrame.new(0, 3, 28),
	}
	local botSpawnIdx = 0
	local lockedRoster = self.botRoster:GetLockedRoster()
	if lockedRoster then
		for _, botParticipantId in lockedRoster.botParticipantIds do
			local participant = self.participants:GetById(botParticipantId)
			if participant then
				botSpawnIdx = (botSpawnIdx % #botSpawnRing) + 1
				local spawnCF = botSpawnRing[botSpawnIdx]
				self.characters:SpawnBotCharacter(
					botParticipantId,
					participant.displayName,
					participant.role,
					spawnCF
				)
				self.characters:StartBotIdleWander(botParticipantId)
			end
		end
	end

	local matchRoundId = self.activeMatchRoundId
	if matchRoundId then
		self.matchmaking:MarkRoundStarted(matchRoundId)
	end
	self:EnterPhase("RoleReveal")
	return roundId
end

function GameRuntimeService:EnterPhase(phase: PhaseName)
	local previousPhase = self.phase
	self.phase = phase
	self.phaseStartedAt = now()
	self.phaseEndsAt = self.phaseStartedAt + phaseDuration(phase)
	self.botTaskById = {}
	self.campfireStage = nil
	self.votingOpensAt = nil
	if self.roundId > 0 then
		self.counselors:SetPhase(phase, self.phaseStartedAt)
		self.characters:ApplyCounselorSnapshot(self.counselors:GetPublicSnapshot())
	end

	if phase == "Day" then
		self.world:SetObjectivePromptsEnabled(true)
		self:_spawnRoundKeys()
	elseif phase == "MurderPlanning" then
		self.world:SetObjectivePromptsEnabled(false)
		-- Keys are Day-phase pickups only; unfound keys vanish at dusk.
		self.map:ClearDayKeys()
		self.monster:BeginPlanning(self.roundId)
	elseif phase == "NightTransform" then
		local outcomes: DayOutcomes = {
			generator = self.completedObjectives.generator ~= nil,
			firewood = self.completedObjectives.firewood ~= nil,
			supplies = self.completedObjectives.supplies ~= nil,
		}
		self.dayOutcomes = outcomes
		self:_beginMystery(self.world:GetPublicSnapshot().roundSeed)
		self.world:SetNight(true, {
			generatorPowered = outcomes.generator,
			firewoodStocked = outcomes.firewood,
		})
		if outcomes.supplies then
			for _, campParticipant in self.participants:GetAll() do
				if
					campParticipant.team == "Campers"
					and campParticipant.alive
					and not campParticipant.isGhost
					and campParticipant.role ~= "Spectator"
				then
					local granted, instanceId = self.inventory:Grant(
						campParticipant.participantId,
						"FlareLantern"
					)
					if granted and instanceId then
						self.participants:AddInventoryItem(
							campParticipant.participantId,
							instanceId
						)
					end
				end
			end
		end
		local nightSummary = table.concat({
			if outcomes.generator
				then "Generator ON — the camp stays lit."
				else "Generator DEAD — darkness takes the camp.",
			if outcomes.firewood
				then "The campfire blazes — its light is a haven."
				else "The fire gutters — even the campfire is not safe.",
			if outcomes.supplies
				then "Supplies secured — every camper got a bonus flare."
				else "Supplies unsecured — no extra gear tonight.",
		}, " ")
		self:_announce("Warning", "Night falls on camp", nightSummary, 8)
		local privateMonster = self.monster:GetPrivateSnapshot()
		local monsterId = privateMonster.monsterId
		local participantId = privateMonster.participantId
		if monsterId and participantId then
			self.characters:SpawnMonster(
				monsterId,
				participantId,
				CFrame.new(0, 4, -65)
			)
			local murdererParticipant = self.participants:GetById(participantId)
			if murdererParticipant then
				local murdererPlayer = findPlayerForParticipant(murdererParticipant)
				if murdererPlayer then
					self.characters:StartMonsterTracking(murdererPlayer)
				end
			end
		end
		local cacheRandom = Random.new(
			self.world:GetPublicSnapshot().roundSeed + self.roundId * 3671 + 97
		)
		self.map:SpawnSupplyCache(
			SUPPLY_CACHE_SPOTS[cacheRandom:NextInteger(1, #SUPPLY_CACHE_SPOTS)]
		)
	elseif phase == "Investigation" then
		self.world:SpawnEvidence()
		self.monster:Activate(self.roundId)
		self.characters:PlayMonsterState("Hunt", true)
		-- Spread bots across the camp so they look like active investigators
		self.characters:ScatterBotsForInvestigation()
	elseif phase == "Campfire" then
		self.world:ClearEvidence()
		self.monster:CampfireStop(self.roundId)
		self.characters:ClearMonster()
		self.characters:ClearBodyMarkers()
		-- Draw bots toward the campfire for the vote so they look like participants
		self.characters:GatherBotsAt(Vector3.new(0, 3, 7), 4)
		self.campfireStage = "Discussion"
		local discussionSeconds = campfireDiscussionSeconds()
		self.votingOpensAt = self.phaseStartedAt + discussionSeconds
		local generation = self.generation
		local campfireRoundId = self.roundId
		task.delay(discussionSeconds, function()
			if not self.running or self.generation ~= generation then
				return
			end
			if self.roundId ~= campfireRoundId or self.phase ~= "Campfire" then
				return
			end
			if self.campfireStage ~= "Discussion" then
				return
			end
			self.campfireStage = "Voting"
			self:_announce(
				"Info",
				"Voting is open",
				"Discussion is over — lock in your accusation.",
				5
			)
			self:Broadcast()
		end)
	elseif phase == "Resolution" then
		if not self.winner then
			self:_ResolveAccusation()
		end
	elseif phase == "Rewards" then
		self:_ApplyRewards()
		self.lifecycle:Emit("RoundEnded", {
			winner = self.winner,
			resultMessage = self.resultMessage,
		})
		self.counselors:EndRound(now())
	elseif phase == "Lobby" and previousPhase ~= "Lobby" then
		self.world:ResetRound()
		self.characters:Reset()
		self.lifecycle:Emit("RoundReset", {})
	end

	self.lifecycle:Emit("PhaseChanged", {
		previousPhase = previousPhase,
		phase = phase,
		phaseEndsAt = self.phaseEndsAt,
	})
	local notice = PHASE_NOTICES[phase]
	if notice then
		self:_announce(notice.kind, notice.title, notice.message, 4)
	end
	self:Broadcast()
end

function GameRuntimeService:_objectiveCount(): number
	local count = 0
	for _ in self.completedObjectives do
		count += 1
	end
	return count
end

function GameRuntimeService:_evidenceSummaries(): { EvidenceSummary }
	local board = self.evidence:GetBoardSnapshot()
	local result: { EvidenceSummary } = {}
	for _, record in board.culpritEvidence do
		local discovery = record.discovery
		table.insert(result, {
			id = record.evidenceId,
			displayName = record.displayName,
			description = record.description,
			foundBy = if discovery then discovery.discoveredByDisplayName else "Unknown",
		})
	end
	for _, record in board.monsterEvidence do
		local discovery = record.discovery
		table.insert(result, {
			id = record.evidenceId,
			displayName = record.displayName,
			description = record.description,
			foundBy = if discovery then discovery.discoveredByDisplayName else "Unknown",
		})
	end
	return result
end

function GameRuntimeService:_suspects(): { Suspect }
	local result: { Suspect } = {}
	for _, participant in self.participants:GetAll() do
		if participant.alive and not participant.isGhost and participant.role ~= "Spectator" then
			table.insert(result, {
				key = participant.participantId,
				displayName = participant.displayName,
			})
		end
	end
	table.sort(result, function(left: Suspect, right: Suspect): boolean
		return left.displayName < right.displayName
	end)
	return result
end

function GameRuntimeService:GetRoundSnapshot(): RoundSnapshot
	local voteSnapshot = self.voting:GetSnapshot()
	local revealVotes = self.phase == "Resolution" or self.phase == "Rewards"
	local mysterySnapshot = if self.mysteryReady
		then self.mystery:GetPublicSnapshot()
		else nil
	return {
		roundNumber = self.roundId,
		phase = self.phase,
		phaseDisplayName = phaseDisplayName(self.phase),
		phaseStartedAt = self.phaseStartedAt,
		phaseEndsAt = self.phaseEndsAt,
		serverNow = now(),
		objectivesCompleted = self:_objectiveCount(),
		objectiveGoal = RoundConfig.objectiveGoal,
		evidenceFound = if mysterySnapshot
			then mysterySnapshot.discoveredClueCount
			else #self:_evidenceSummaries(),
		evidenceGoal = if mysterySnapshot
			then mysterySnapshot.totalClueCount
			else RoundConfig.evidenceGoal,
		evidence = self:_evidenceSummaries(),
		suspects = self:_suspects(),
		votesCast = voteSnapshot.votesCast,
		eligibleVoters = voteSnapshot.eligibleVoters,
		votes = if revealVotes then voteSnapshot.votes else nil,
		culpritId = if revealVotes then self.culpritParticipantId else nil,
		monsterId = if revealVotes and self.murderPlan
			then self.murderPlan.monsterId
			else nil,
		victimName = self.victimName,
		winner = self.winner,
		resultMessage = self.resultMessage,
		isNight = self.world:GetPublicSnapshot().isNight,
		dayOutcomes = self.dayOutcomes,
		campfireStage = self.campfireStage,
		votingOpensAt = self.votingOpensAt,
		discussionLog = self.discussionLog,
	}
end

function GameRuntimeService:_availableActions(
	participant: ParticipantState?
): { RuntimeTypes.AvailableAction }
	local active = participant ~= nil
		and participant.alive
		and not participant.isGhost
		and participant.role ~= "Spectator"
	local actions: { RuntimeTypes.AvailableAction } = {}
	local names: { ActionName } = {
		"Ready",
		"SetMurderPlan",
		"CompleteObjective",
		"DiscoverEvidence",
		"InterviewCounselor",
		"Vote",
		"PresentEvidence",
		"BuddyCheckIn",
		"EquipItem",
		"UseItem",
		"DropItem",
		"TransferItem",
		"UseRoleAbility",
		"UseMonsterAbility",
		"VerifyEvidence",
		"CombineEvidence",
		"AddEvidenceNote",
		"SetSettings",
		"BuyUpgrade",
		"UnlockCosmetic",
		"EquipCosmetic",
	}
	for _, name in names do
		local enabled = active
		if name == "Ready" then
			enabled = self.phase == "Lobby"
		elseif name == "SetMurderPlan" then
			enabled = active
				and self.phase == "MurderPlanning"
				and participant ~= nil
				and participant.role == "Murderer"
				and (participant.abilityUses["monster-transformation"] or 0) < 1
		elseif name == "CompleteObjective" then
			enabled = active and self.phase == "Day"
		elseif name == "DiscoverEvidence" then
			enabled = active and self.phase == "Investigation"
		elseif name == "InterviewCounselor" then
			enabled = active
				and (
					self.phase == "Day"
					or self.phase == "MurderPlanning"
					or self.phase == "Investigation"
					or self.phase == "Campfire"
				)
		elseif name == "BuddyCheckIn" then
			enabled = active and self.phase == "MurderPlanning"
		elseif name == "Vote" then
			enabled = active
				and self.phase == "Campfire"
				and self.campfireStage == "Voting"
		elseif name == "PresentEvidence" then
			enabled = active
				and self.phase == "Campfire"
				and self.campfireStage == "Discussion"
		elseif name == "UseMonsterAbility" then
			enabled = active
				and self.phase == "Investigation"
				and participant ~= nil
				and participant.role == "Murderer"
		elseif name == "UseRoleAbility" then
			if participant == nil then
				enabled = false
			elseif participant.role == "Murderer" then
				enabled = active and self.phase == "MurderPlanning"
			elseif participant.role == "Medium" then
				enabled = active
					and (self.phase == "Investigation" or self.phase == "Campfire")
			elseif participant.role == "Protector" and participant.isGhost then
				enabled = self.phase == "Investigation"
			elseif
				participant.role == "Medic"
				or participant.role == "Trapper"
				or participant.role == "Guard"
				or participant.role == "Protector"
				or participant.role == "Detective"
			then
				enabled = active and (self.phase == "Day" or self.phase == "Investigation")
			else
				enabled = false
			end
		elseif name == "VerifyEvidence" then
			enabled = active and participant ~= nil and participant.role == "Detective"
		elseif name == "CombineEvidence" then
			enabled = active
				and participant ~= nil
				and participant.role == "Detective"
				and (self.phase == "Investigation" or self.phase == "Campfire")
		elseif name == "BuyUpgrade" or name == "UnlockCosmetic" or name == "EquipCosmetic" then
			enabled = participant ~= nil
				and (self.phase == "Lobby" or self.phase == "Rewards")
		end
		table.insert(actions, {
			name = name,
			enabled = enabled,
			reason = if enabled then nil else "Not currently available",
		})
	end
	return actions
end

function GameRuntimeService:GetGameState(player: Player): GameState
	local participant = self:_participantForPlayer(player)
	local participantId = if participant then participant.participantId else nil
	local privateMonster = if participant and participant.role == "Murderer"
		then self.monster:GetPrivateSnapshot()
		else nil
	return {
		serverNow = now(),
		round = self:GetRoundSnapshot(),
		lobby = self.matchmaking:GetLobbySnapshot(),
		participants = self.participants:SerializeAllPublic(),
		player = if participant then self.participants:SerializePrivate(participant) else nil,
		inventory = if participantId then self.inventory:GetSnapshot(participantId) else nil,
		combat = if participantId then self.combat:GetSnapshot(participantId) else nil,
		evidence = self.evidence:GetBoardSnapshot(),
		mystery = if self.mysteryReady then self.mystery:GetPublicSnapshot() else nil,
		counselors = if self.roundId > 0 then self.counselors:GetPublicSnapshot() else nil,
		monster = self.monster:GetPublicSnapshot(),
		privateMonster = privateMonster,
		murderPlan = if participant and participant.role == "Murderer"
			then self.murderPlan
			else nil,
		world = self.world:GetPublicSnapshot(),
		profile = self.profile:GetSnapshot(player),
		availableActions = self:_availableActions(participant),
	}
end

function GameRuntimeService:Broadcast()
	local callback = self.options.onStateChanged
	if not callback then
		return
	end
	for _, player in Players:GetPlayers() do
		callback(player, self:GetGameState(player))
	end
end

function GameRuntimeService:_finishIfEliminated()
	local culpritId = self.culpritParticipantId
	if not culpritId or self.winner then
		return
	end
	local winner = self.voting:EvaluateEliminationVictory(culpritId)
	if winner then
		self.winner = winner
		self.resultMessage = if winner == "Campers"
			then "The Murderer was stopped before the final accusation."
			else "Too few campers remain to contain the hunt."
		self.phaseEndsAt = now()
		self:_announce("Danger", "Round decided", self.resultMessage, 5)
	end
end

function GameRuntimeService:_isNearPart(
	participant: ParticipantState,
	part: Instance?,
	maximumDistance: number
): boolean
	if not part or not part:IsA("BasePart") then
		return false
	end
	local position = participantPosition(participant)
	return position ~= nil and (position - part.Position).Magnitude <= maximumDistance
end

function GameRuntimeService:_objectivePart(objectiveId: string): Instance?
	local runtime = Workspace:FindFirstChild("Runtime")
	local map = if runtime then runtime:FindFirstChild("Map") else nil
	local camp = if map then map:FindFirstChild("DayCamp") else nil
	local objectives = if camp then camp:FindFirstChild("Objectives") else nil
	local station = if objectives then objectives:FindFirstChild(objectiveId) else nil
	if station and station:IsA("Model") then
		return station.PrimaryPart or station:FindFirstChild("InteractionRoot")
	end
	return station
end

function GameRuntimeService:_evidencePart(aliasId: string): Instance?
	local runtime = Workspace:FindFirstChild("Runtime")
	local evidenceFolder = if runtime then runtime:FindFirstChild("Evidence") else nil
	return if evidenceFolder then evidenceFolder:FindFirstChild(aliasId) else nil
end

function GameRuntimeService:_CreateAttackEvidence(
	evidenceKind: string,
	attacker: ParticipantState,
	target: ParticipantState,
	_request: CombatTypes.AttackRequest
)
	local record = self.evidence:CreateAttackEvidence(
		attacker.participantId,
		target.participantId,
		self.murderPlan and self.murderPlan.locationId or "attack-site",
		evidenceKind == "LethalAttack"
	)
	-- The default murder-plan location ("industrial-factory-monster") is a
	-- monster spawn, not a search socket; evidence must map to a real socket
	-- or no search prompt can ever reach it.
	local planLocation = if self.murderPlan then self.murderPlan.locationId else nil
	self.evidenceLocationById[record.evidenceId] = if planLocation
			and table.find(SEARCH_LOCATIONS, planLocation)
		then planLocation
		else SEARCH_LOCATIONS[((self.roundId - 1) % #SEARCH_LOCATIONS) + 1]
	if not target.alive then
		self.victimName = target.displayName
	end
	self:_finishIfEliminated()
end

function GameRuntimeService:_CreateMonsterEvidence(monsterId: MonsterId)
	local record = self.evidence:Create(
		"monster-trace",
		"Real",
		nil,
		{ [monsterId] = 0.7 }
	)
	self.evidenceLocationById[record.evidenceId] =
		SEARCH_LOCATIONS[((#self.evidence:GetAllServer() - 1) % #SEARCH_LOCATIONS) + 1]
end

function GameRuntimeService:_ApplyMonsterAttack(
	sourceParticipantId: string,
	targetParticipantId: string,
	abilityId: string
)
	local result = self.combat:ApplyAttack({
		roundId = self.roundId,
		attackerParticipantId = sourceParticipantId,
		targetParticipantId = targetParticipantId,
		source = "MonsterAbility",
		abilityId = abilityId,
		position = nil,
	})
	if result.accepted then
		local targetParticipant = self.participants:GetById(targetParticipantId)
		if targetParticipant then
			local targetPlayer = findPlayerForParticipant(targetParticipant)
			local targetPos: Vector3? = nil
			if targetPlayer and targetPlayer.Character then
				local hrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					targetPos = hrp.Position
				end
			end
			if not targetPos then
				targetPos = self.characters:GetBotCharacterPosition(targetParticipantId)
			end
			if targetPos then
				self.characters:LungeMonsterToward(targetPos)
			end
		end
		local plan = self.murderPlan
		local affectedCounselors = self.counselors:ReportThreat({
			locationId = if plan then plan.locationId else "main-road-safe-entry",
			sourceId = sourceParticipantId,
			severity = 0.85,
			occurredAt = now(),
		})
		if #affectedCounselors > 0 then
			self.characters:ApplyCounselorSnapshot(
				self.counselors:GetPublicSnapshot()
			)
		end
		self:_finishIfEliminated()
		self:Broadcast()
	end
end

function GameRuntimeService:_completeObjective(
	participant: ParticipantState,
	objectiveId: string,
	enforceSpatial: boolean?
): ActionResult
	if self.phase ~= "Day" then
		return actionRejected("Objectives are only active during the day")
	end
	if self.completedObjectives[objectiveId] then
		return actionRejected("Objective is already complete")
	end
	if not table.find(OBJECTIVE_IDS, objectiveId) then
		return actionRejected("Unknown objective")
	end
	if
		enforceSpatial ~= false
		and not self:_isNearPart(participant, self:_objectivePart(objectiveId), 14)
	then
		return actionRejected("Move closer to the objective")
	end
	self.completedObjectives[objectiveId] = participant.participantId
	self.objectivesByParticipantId[participant.participantId] =
		(self.objectivesByParticipantId[participant.participantId] or 0) + 1
	self.world:MarkObjectiveComplete(objectiveId)
	if self:_objectiveCount() >= RoundConfig.objectiveGoal then
		self.phaseEndsAt = math.min(self.phaseEndsAt, now() + 1)
	end
	return {
		accepted = true,
		reason = nil,
		state = nil,
		data = { objectiveId = objectiveId },
	}
end

function GameRuntimeService:_discoverEvidence(
	participant: ParticipantState,
	requestedEvidenceId: string,
	enforceSpatial: boolean?
): ActionResult
	if self.phase ~= "Investigation" then
		return actionRejected("Evidence can only be collected during investigation")
	end
	local resolvedEvidenceId =
		self.evidenceAliasById[requestedEvidenceId] or requestedEvidenceId
	local record = self.evidence:GetRecordServer(resolvedEvidenceId)
	if not record then
		local mysteryAtLocation = self.mysteryClueIdsByLocation[requestedEvidenceId]
		if self.mysteryReady and mysteryAtLocation and #mysteryAtLocation > 0 then
			if
				enforceSpatial ~= false
				and not self:_isNearPart(
					participant,
					self:_evidencePart(requestedEvidenceId),
					14
				)
			then
				return actionRejected("Move closer to the evidence")
			end
			local mysteryClues = self:_discoverMysteryAtLocation(
				participant.participantId,
				requestedEvidenceId
			)
			if #mysteryClues == 0 then
				return actionRejected("Evidence was already discovered")
			end
			return {
				accepted = true,
				reason = nil,
				state = nil,
				data = {
					locationId = requestedEvidenceId,
					mysteryClues = mysteryClues,
				},
			}
		end
		return actionRejected("Unknown evidence search target")
	end
	if enforceSpatial ~= false then
		local aliasId: string? = nil
		for candidateAlias, evidenceId in self.evidenceAliasById do
			if evidenceId == record.evidenceId then
				aliasId = candidateAlias
				break
			end
		end
		-- Attack and device evidence created mid-round has no socket alias;
		-- fall back to its assigned search location for the proximity check.
		aliasId = aliasId or self.evidenceLocationById[record.evidenceId]
		if
			not aliasId
			or not self:_isNearPart(participant, self:_evidencePart(aliasId), 14)
		then
			return actionRejected("Move closer to the evidence")
		end
	end
	local locationId = self.evidenceLocationById[record.evidenceId] or requestedEvidenceId
	local function discoverRecord(evidenceId: string, displayName: string): (boolean, string?)
		local discovered, reason = self.evidence:Discover(
			participant.participantId,
			evidenceId,
			locationId,
			now()
		)
		if not discovered then
			return false, reason
		end
		self.participants:RecordEvidenceKnowledge(participant.participantId, {
			evidenceId = evidenceId,
			displayName = displayName,
			confidence = 0.65,
			isShared = true,
			learnedAt = now(),
		})
		self.evidenceByParticipantId[participant.participantId] =
			(self.evidenceByParticipantId[participant.participantId] or 0) + 1
		return true, nil
	end
	local discovered, reason = discoverRecord(record.evidenceId, record.displayName)
	-- One search uncovers every undiscovered record assigned to this location,
	-- so attack traces and device readings sharing a socket are reachable too.
	for _, extra in self.evidence:GetUndiscoveredServer() do
		if
			extra.evidenceId ~= record.evidenceId
			and self.evidenceLocationById[extra.evidenceId] == locationId
		then
			local extraDiscovered = discoverRecord(extra.evidenceId, extra.displayName)
			discovered = discovered or extraDiscovered
		end
	end
	local mysteryClues = self:_discoverMysteryAtLocation(
		participant.participantId,
		locationId
	)
	if not discovered and #mysteryClues == 0 then
		return actionRejected(reason or "Evidence was already discovered")
	end
	local mysterySnapshot = if self.mysteryReady
		then self.mystery:GetPublicSnapshot()
		else nil
	if
		#self:_evidenceSummaries() >= RoundConfig.evidenceGoal
		and (
			not mysterySnapshot
			or mysterySnapshot.discoveredClueCount >= mysterySnapshot.totalClueCount
		)
	then
		self.phaseEndsAt = math.min(self.phaseEndsAt, now() + 2)
	end
	return {
		accepted = true,
		reason = nil,
		state = nil,
		data = {
			evidenceId = record.evidenceId,
			locationId = locationId,
			mysteryClues = mysteryClues,
		},
	}
end

function GameRuntimeService:_validateActiveParticipant(
	participant: ParticipantState?
): (ParticipantState?, string?)
	if not participant then
		return nil, "Player is not registered"
	end
	if not participant.alive or participant.isGhost or participant.role == "Spectator" then
		return nil, "Participant cannot perform physical actions"
	end
	return participant, nil
end

function GameRuntimeService:_useItem(
	participant: ParticipantState,
	payload: { [string]: unknown }
): ActionResult
	local instanceId = getString(payload, "instanceId")
	if not instanceId then
		return actionRejected("Item instance is required")
	end
	local item = self.inventory:GetOwnedItem(participant.participantId, instanceId)
	if not item then
		return actionRejected("Item is not owned")
	end
	if
		self.statusEffects:Has(participant.participantId, "EquipmentDisabled")
		and item.equipmentId ~= "MedicalKit"
		and item.equipmentId ~= "MonsterTrap"
	then
		return actionRejected("Equipment is temporarily disabled")
	end
	if not item.equipped or item.charges <= 0 or item.durability <= 0 then
		return actionRejected("Item must be equipped and usable")
	end
	if now() < item.cooldownEndsAt then
		return actionRejected("Item is cooling down")
	end
	local requestedTargetId = getString(payload, "targetParticipantId")
	if requestedTargetId then
		local target = self.participants:GetById(requestedTargetId)
		if not target or target.role == "Spectator" then
			return actionRejected("Item target is invalid")
		end
		local sourcePosition = participantPosition(participant)
		local targetPosition = participantPosition(target)
		local rule = EquipmentRules[item.equipmentId]
		if not sourcePosition or not targetPosition then
			return actionRejected("Item target position is unavailable")
		end
		if (targetPosition - sourcePosition).Magnitude > rule.maxRange then
			return actionRejected("Item target is out of range")
		end
		if
			not unobstructed(
				sourcePosition,
				targetPosition,
				characterForParticipant(participant),
				characterForParticipant(target)
			)
		then
			return actionRejected("Item target is not in line of sight")
		end
	end

	if item.equipmentId == "MedicalKit" then
		local targetId = requestedTargetId
		local target = if targetId then self.participants:GetById(targetId) else nil
		if
			not target
			or not target.alive
			or target.isGhost
			or target.injuryLevel ~= 1
		then
			return actionRejected("A living injured target is required")
		end
		local authorization =
			self.roleAbilities:AuthorizeTreatment(participant.participantId)
		if not authorization.accepted then
			return actionRejected(authorization.reason or "Treatment is not authorized")
		end
		local healed, healReason =
			self.combat:Heal(participant.participantId, target.participantId, true)
		if not healed then
			return actionRejected(healReason or "Treatment failed")
		end
	elseif DEVICE_EVIDENCE[item.equipmentId] and self.phase == "Investigation" then
		self:_CreateMonsterEvidence(
			self.monster:GetPrivateSnapshot().monsterId or "BabyAlien"
		)
	elseif item.equipmentId == "FlareLantern" then
		self.statusEffects:Remove(participant.participantId, "Fear")
		self.statusEffects:Remove(participant.participantId, "VisionDistortion")
	elseif item.equipmentId == "UVLight" or item.equipmentId == "Flashlight" then
		local targetId = requestedTargetId
		if targetId then
			self.statusEffects:Remove(targetId, "Latched")
			self.statusEffects:Remove(targetId, "Marked")
		end
	elseif item.equipmentId == "MonsterTrap" then
		local trapResult = self.roleAbilities:PlaceTrap(
			participant.participantId,
			getString(payload, "locationId") or "current-location"
		)
		if not trapResult.accepted then
			return actionRejected(trapResult.reason or "Trap placement failed")
		end
	end

	local consumed, consumeReason =
		self.inventory:ConsumeCharge(participant.participantId, instanceId, now())
	if not consumed then
		return actionRejected(consumeReason or "Item use failed")
	end
	return {
		accepted = true,
		reason = nil,
		state = nil,
		data = { instanceId = instanceId, equipmentId = item.equipmentId },
	}
end

function GameRuntimeService:_useRoleAbility(
	participant: ParticipantState,
	payload: { [string]: unknown }
): ActionResult
	local abilityId = getString(payload, "abilityId")
	if not abilityId then
		return actionRejected("Ability ID is required")
	end
	local targetId = getString(payload, "targetParticipantId")
	local result
	if abilityId == "monster-transformation" then
		if participant.role ~= "Murderer" or self.phase ~= "MurderPlanning" then
			return actionRejected("Monster planning is not active")
		end
		if (participant.abilityUses[abilityId] or 0) >= 1 then
			return actionRejected("Murder plan is already locked")
		end
		local victimId = targetId
		local victim = if victimId then self.participants:GetById(victimId) else nil
		if not victim or victim.team ~= "Campers" or not victim.alive then
			return actionRejected("A living Camper victim is required")
		end
		local requestedMonster = getString(payload, "monsterId")
		local monsterId: MonsterId = self.monster:GetPrivateSnapshot().monsterId
			or "BabyAlien"
		if requestedMonster and table.find(MONSTER_ORDER, requestedMonster :: MonsterId) then
			monsterId = requestedMonster :: MonsterId
		end
		local frameId = getString(payload, "frameParticipantId")
		if frameId then
			local reframed, frameReason =
				self.evidence:ReframeFake(participant.participantId, frameId)
			if not reframed then
				return actionRejected(frameReason or "Frame target is invalid")
			end
		elseif self.murderPlan then
			-- A frame chosen earlier (default or planted) must survive locking
			-- the plan, or the planted mystery clues lose their target.
			frameId = self.murderPlan.frameParticipantId
		end
		self.monster:SelectPlanningMonster(self.roundId, monsterId)
		self.evidence:SetMonsterForRound(monsterId)
		self.murderPlan = {
			victimParticipantId = victim.participantId,
			frameParticipantId = frameId,
			locationId = getString(payload, "locationId") or "industrial-factory-monster",
			monsterId = monsterId,
		}
		participant.abilityUses[abilityId] = 1
		return {
			accepted = true,
			reason = nil,
			state = nil,
			data = {
				victimParticipantId = victim.participantId,
				frameParticipantId = frameId,
				monsterId = monsterId,
			},
		}
	elseif abilityId == "plant-false-evidence" then
		if participant.role ~= "Murderer" or self.phase ~= "MurderPlanning" then
			return actionRejected("False evidence can only be planned by the Murderer")
		end
		local frameId = targetId or getString(payload, "frameParticipantId")
		if not frameId then
			return actionRejected("Frame target is required")
		end
		if (participant.abilityUses[abilityId] or 0) >= 1 then
			return actionRejected("False evidence was already planned")
		end
		local reframed, frameReason =
			self.evidence:ReframeFake(participant.participantId, frameId)
		if not reframed then
			return actionRejected(frameReason or "Frame target is invalid")
		end
		-- The mystery is generated from murderPlan, so the deliberate frame must
		-- replace the default target or the planted evidence points elsewhere.
		if self.murderPlan then
			self.murderPlan.frameParticipantId = frameId
		end
		participant.abilityUses[abilityId] = 1
		return {
			accepted = true,
			reason = nil,
			state = nil,
			data = { frameParticipantId = frameId },
		}
	elseif abilityId == "protect-participant" and targetId then
		result = self.roleAbilities:SetProtection(participant.participantId, targetId)
	elseif abilityId == "guard-post" and targetId then
		result = self.roleAbilities:SetGuard(participant.participantId, targetId)
	elseif abilityId == "place-warning-trap" then
		result = self.roleAbilities:PlaceTrap(
			participant.participantId,
			getString(payload, "locationId") or "current-location"
		)
	elseif abilityId == "analyze-evidence" and targetId then
		result = self.roleAbilities:Investigate(participant.participantId, targetId)
	elseif abilityId == "analyze-evidence" then
		local evidenceId = getString(payload, "evidenceId")
		if not evidenceId then
			return actionRejected("Evidence or participant target is required")
		end
		local verified, reason =
			self.evidence:Verify(participant.participantId, evidenceId)
		return {
			accepted = verified,
			reason = reason,
			state = nil,
			data = if verified then { evidenceId = evidenceId } else nil,
		}
	elseif abilityId == "spirit-sense" then
		result = self.roleAbilities:RequestSpiritSignal(participant.participantId)
	else
		return actionRejected("Ability payload is incomplete or unsupported")
	end
	return {
		accepted = result.accepted,
		reason = result.reason,
		state = nil,
		data = result.data,
	}
end

function GameRuntimeService:_handleParticipantAction(
	participant: ParticipantState,
	actionName: ActionName,
	payload: { [string]: unknown }
): ActionResult
	if actionName == "SetMurderPlan" then
		if self.phase ~= "MurderPlanning" or participant.role ~= "Murderer" then
			return actionRejected("Only the Murderer can plan during the planning phase")
		end
		local victimId = getString(payload, "victimParticipantId")
			or getString(payload, "targetParticipantId")
		local monsterId = getString(payload, "monsterId")
		local locationId = getString(payload, "locationId")
			or SEARCH_LOCATIONS[((self.roundId - 1) % #SEARCH_LOCATIONS) + 1]
		if not victimId or not monsterId then
			return actionRejected("A victim and monster transformation are required")
		end
		local victim = self.participants:GetById(victimId)
		if
			not victim
			or not victim.alive
			or victim.isGhost
			or victim.team ~= "Campers"
			or victim.participantId == participant.participantId
		then
			return actionRejected("The selected victim is not eligible")
		end
		if not table.find(MONSTER_ORDER, monsterId :: MonsterId) then
			return actionRejected("Unknown monster transformation")
		end
		if not table.find(SEARCH_LOCATIONS, locationId) then
			return actionRejected("Unknown murder location")
		end
		local selectedMonsterId = monsterId :: MonsterId
		self.monster:SelectPlanningMonster(self.roundId, selectedMonsterId)
		self.evidence:SetMonsterForRound(selectedMonsterId)
		local current = self.murderPlan
		self.murderPlan = {
			victimParticipantId = victim.participantId,
			frameParticipantId = if current then current.frameParticipantId else nil,
			locationId = locationId,
			monsterId = selectedMonsterId,
		}
		participant.abilityUses["monster-transformation"] = 1
		return {
			accepted = true,
			reason = "The night plan is locked.",
			state = nil,
			data = self.murderPlan,
		}
	elseif actionName == "CompleteObjective" then
		local objectiveId = getString(payload, "objectiveId")
		return if objectiveId
			then self:_completeObjective(participant, objectiveId, true)
			else actionRejected("Objective ID is required")
	elseif actionName == "DiscoverEvidence" then
		local evidenceId = getString(payload, "evidenceId")
			or getString(payload, "locationId")
		return if evidenceId
			then self:_discoverEvidence(participant, evidenceId, true)
			else actionRejected("Evidence or location ID is required")
	elseif actionName == "InterviewCounselor" then
		if
			self.phase ~= "Day"
			and self.phase ~= "MurderPlanning"
			and self.phase ~= "Investigation"
			and self.phase ~= "Campfire"
		then
			return actionRejected("Counselor interviews are not available now")
		end
		local counselorId = getString(payload, "counselorId")
		local requestedTopic = getString(payload, "topic") or "Observation"
		if not counselorId then
			return actionRejected("Counselor ID is required")
		end
		local validTopics: { [string]: boolean } = {
			Greeting = true,
			Schedule = true,
			Observation = true,
			Monster = true,
			Safety = true,
			Suspicion = true,
		}
		if not validTopics[requestedTopic] then
			return actionRejected("Unsupported counselor dialogue topic")
		end
		local dialogue, dialogueReason = self.counselors:RequestDialogue(
			participant.participantId,
			counselorId,
			requestedTopic :: DialogueTopic,
			now()
		)
		if not dialogue then
			return actionRejected(dialogueReason or "Counselor interview failed")
		end
		-- Before the mystery seeds (dusk and daytime chatter), counselors
		-- talk but have no witness account to give yet.
		if not self.mysteryReady then
			return {
				accepted = true,
				reason = nil,
				state = nil,
				data = {
					dialogue = dialogue,
					witnessAccount = nil,
				},
			}
		end
		local witnessAccount, witnessReason = self.mystery:InterviewCounselor(
			participant.participantId,
			counselorId,
			now()
		)
		return {
			accepted = true,
			reason = witnessReason,
			state = nil,
			data = {
				dialogue = dialogue,
				witnessAccount = witnessAccount,
			},
		}
	elseif actionName == "Vote" then
		if self.phase ~= "Campfire" then
			return actionRejected("Voting is not active")
		end
		if self.campfireStage ~= "Voting" then
			return actionRejected("Voting opens after the discussion")
		end
		local targetId = getString(payload, "targetParticipantId")
			or getString(payload, "targetKey")
		if not targetId then
			return actionRejected("Vote target is required")
		end
		local cast, reason = self.voting:CastVote(participant.participantId, targetId)
		if cast and self.voting:IsComplete() then
			self.phaseEndsAt = math.min(self.phaseEndsAt, now() + 1)
		end
		return {
			accepted = cast,
			reason = reason,
			state = nil,
			data = if cast then { targetParticipantId = targetId } else nil,
		}
	elseif actionName == "BuddyCheckIn" then
		if self.phase ~= "MurderPlanning" then
			return actionRejected("Check-ins happen at dusk")
		end
		local targetId = getString(payload, "targetParticipantId")
		if not targetId then
			return actionRejected("Choose a camper to check on")
		end
		if targetId == participant.participantId then
			return actionRejected("Find a buddy, not a mirror")
		end
		local target = self.participants:GetById(targetId)
		if
			not target
			or not target.alive
			or target.isGhost
			or target.role == "Spectator"
		then
			return actionRejected("That camper cannot be checked on")
		end
		local pairKey = if participant.participantId < targetId
			then participant.participantId .. "|" .. targetId
			else targetId .. "|" .. participant.participantId
		if self.checkInPairs[pairKey] then
			return actionRejected("You two already checked in tonight")
		end
		local sourcePosition = participantPosition(participant)
		local targetPosition = participantPosition(target)
		if
			not sourcePosition
			or not targetPosition
			or (targetPosition - sourcePosition).Magnitude > 8
		then
			return actionRejected("Move closer to your buddy")
		end
		self.checkInPairs[pairKey] = true
		self.checkInsByParticipantId[participant.participantId] =
			(self.checkInsByParticipantId[participant.participantId] or 0) + 1
		self.checkInsByParticipantId[targetId] =
			(self.checkInsByParticipantId[targetId] or 0) + 1
		return {
			accepted = true,
			reason = nil,
			state = nil,
			data = {
				targetParticipantId = targetId,
				targetName = target.displayName,
			},
		}
	elseif actionName == "PresentEvidence" then
		if self.phase ~= "Campfire" then
			return actionRejected("Evidence can only be presented at the campfire")
		end
		if self.campfireStage ~= "Discussion" then
			return actionRejected("Presentations happen during the discussion")
		end
		local itemId = getString(payload, "evidenceId") or getString(payload, "clueId")
		if not itemId then
			return actionRejected("Choose evidence to present")
		end
		if self.presentedItems[itemId] then
			return actionRejected("That evidence has already been presented")
		end
		local presentedCount =
			self.presentedCountByParticipantId[participant.participantId] or 0
		if presentedCount >= 3 then
			return actionRejected("You have presented enough for one night")
		end
		local itemName: string? = nil
		local suspectIds: { string } = {}
		local record = self.evidence:GetRecordServer(itemId)
		if record and record.posted then
			itemName = record.displayName
		elseif self.mysteryReady then
			for _, clue in self.mystery:GetPublicSnapshot().clues do
				if clue.clueId == itemId then
					itemName = clue.title
					if clue.channel == "Culprit" then
						suspectIds = clue.suspectCandidateIds
					end
					break
				end
			end
		end
		if not itemName then
			return actionRejected("Only discovered evidence can be presented")
		end
		self.presentedItems[itemId] = true
		self.presentedCountByParticipantId[participant.participantId] = presentedCount + 1
		for _, suspectId in suspectIds do
			self.presentedSuspicion[suspectId] = (self.presentedSuspicion[suspectId] or 0) + 1
		end
		table.insert(self.discussionLog, {
			presenterName = participant.displayName,
			itemName = itemName,
			at = now(),
		})
		if #self.discussionLog > 20 then
			table.remove(self.discussionLog, 1)
		end
		self:_announce(
			"Info",
			participant.displayName .. " presents evidence",
			itemName,
			4
		)
		return { accepted = true, reason = nil, state = nil, data = nil }
	elseif actionName == "EquipItem" then
		local instanceId = getString(payload, "instanceId")
		if not instanceId then
			return actionRejected("Item instance is required")
		end
		local equipped, reason =
			self.inventory:Equip(participant.participantId, instanceId)
		return { accepted = equipped, reason = reason, state = nil, data = nil }
	elseif actionName == "UseItem" then
		return self:_useItem(participant, payload)
	elseif actionName == "DropItem" then
		local instanceId = getString(payload, "instanceId")
		if not instanceId then
			return actionRejected("Item instance is required")
		end
		local dropped, reason =
			self.inventory:Drop(participant.participantId, instanceId)
		if dropped then
			self.participants:RemoveInventoryItem(participant.participantId, instanceId)
		end
		return { accepted = dropped, reason = reason, state = nil, data = nil }
	elseif actionName == "TransferItem" then
		local instanceId = getString(payload, "instanceId")
		local targetId = getString(payload, "targetParticipantId")
		if not instanceId or not targetId then
			return actionRejected("Item and target participant are required")
		end
		local target = self.participants:GetById(targetId)
		if not target or not target.alive or target.isGhost then
			return actionRejected("Transfer target is not eligible")
		end
		local sourcePosition = participantPosition(participant)
		local targetPosition = participantPosition(target)
		if
				not sourcePosition
				or not targetPosition
				or (targetPosition - sourcePosition).Magnitude > 12
				or not unobstructed(
					sourcePosition,
					targetPosition,
					characterForParticipant(participant),
					characterForParticipant(target)
				)
			then
			return actionRejected("Move closer to the transfer target")
		end
		local transferred, reason =
			self.inventory:Transfer(participant.participantId, targetId, instanceId)
		if transferred then
			self.participants:RemoveInventoryItem(participant.participantId, instanceId)
			self.participants:AddInventoryItem(targetId, instanceId)
		end
		return { accepted = transferred, reason = reason, state = nil, data = nil }
	elseif actionName == "UseRoleAbility" then
		return self:_useRoleAbility(participant, payload)
	elseif actionName == "UseMonsterAbility" then
		if participant.role ~= "Murderer" then
			return actionRejected("Only the Murderer controls the monster")
		end
		local abilityId = getString(payload, "abilityId")
		local requestSequence = payload.requestSequence
		if not abilityId or typeof(requestSequence) ~= "number" then
			return actionRejected("Monster ability and request sequence are required")
		end
		local targetPosition = payload.targetPosition or payload.localTargetPosition
		if typeof(targetPosition) ~= "Vector3" then
			local source = findPlayerForParticipant(participant)
			targetPosition = if source
				then playerRootPosition(source)
				else Vector3.new(0, 3, -70)
		end
		local request: AbilityRequest = {
			roundId = self.roundId,
			participantId = participant.participantId,
			abilityId = abilityId,
			targetParticipantId = getString(payload, "targetParticipantId"),
			targetPosition = targetPosition :: Vector3?,
			requestSequence = math.floor(requestSequence),
		}
		local result = self.monster:Activate(request)
		return {
			accepted = result.accepted,
			reason = result.reason,
			state = nil,
			data = result,
		}
	elseif actionName == "VerifyEvidence" then
		local evidenceId = getString(payload, "evidenceId")
		if not evidenceId then
			return actionRejected("Evidence ID is required")
		end
		local verified, reason =
			self.evidence:Verify(participant.participantId, evidenceId)
		return { accepted = verified, reason = reason, state = nil, data = nil }
	elseif actionName == "CombineEvidence" then
		return self:_combineEvidence(participant, payload)
	end
	return actionRejected("Action is handled by another server domain")
end

local GHOST_FLICKER_COOLDOWN_SECONDS = 60
local GHOST_FLICKER_RANGE_STUDS = 24

-- Ghost-only: flicker the nearest light so every living player sees it.
-- The position comes from the ghost camera; it is clamped and only ever
-- dims a light briefly, so it is safe to trust within range limits.
function GameRuntimeService:_ghostFlickerLight(
	participant: ParticipantState,
	payload: { [string]: unknown }
): ActionResult
	if self.phase ~= "Investigation" then
		return actionRejected("Spirits can only reach the lights at night")
	end
	local lastAt = self.ghostFlickerAt[participant.participantId]
	if lastAt and now() - lastAt < GHOST_FLICKER_COOLDOWN_SECONDS then
		return actionRejected("Your spectral energy is spent")
	end
	local function finiteCoordinate(key: string): number?
		local value = payload[key]
		if typeof(value) == "number" and value == value and math.abs(value) < 10000 then
			return value
		end
		return nil
	end
	local x = finiteCoordinate("x")
	local y = finiteCoordinate("y")
	local z = finiteCoordinate("z")
	if not x or not y or not z then
		return actionRejected("Flicker position is required")
	end
	local origin = Vector3.new(x, y, z)
	local nearest: Light? = nil
	local nearestDistance = GHOST_FLICKER_RANGE_STUDS
	for _, descendant in Workspace:GetDescendants() do
		if
			descendant:IsA("PointLight")
			or descendant:IsA("SpotLight")
			or descendant:IsA("SurfaceLight")
		then
			local lightParent = descendant.Parent
			if lightParent and lightParent:IsA("BasePart") then
				local distance = (lightParent.Position - origin).Magnitude
				if distance <= nearestDistance then
					nearest = descendant
					nearestDistance = distance
				end
			end
		end
	end
	if not nearest then
		return actionRejected("No light within reach")
	end
	self.ghostFlickerAt[participant.participantId] = now()
	local light = nearest :: Light
	local brightness = light.Brightness
	local fadeOut = TweenService:Create(
		light,
		TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Brightness = 0 }
	)
	fadeOut.Completed:Connect(function()
		if light.Parent then
			TweenService:Create(
				light,
				TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
				{ Brightness = brightness }
			):Play()
		end
	end)
	fadeOut:Play()
	return { accepted = true, reason = nil, state = nil, data = nil }
end

function GameRuntimeService:HandleAction(
	player: Player,
	actionName: string,
	payload: unknown
): ActionResult
	local rawParticipant = self:_participantForPlayer(player)
	local participant, participantReason =
		self:_validateActiveParticipant(rawParticipant)
	if actionName == "Ready" then
		local request = clonePayload(payload)
		local readyValue = request.ready
		local ready = if typeof(readyValue) == "boolean" then readyValue else true
		local set, reason = self.matchmaking:SetReady(player, ready)
		return {
			accepted = set,
			reason = reason,
			state = self:GetGameState(player),
			data = nil,
		}
	elseif actionName == "SetSettings" then
		local request = clonePayload(payload)
		local settings = request.settings
		if typeof(settings) ~= "table" then
			return actionRejected("Settings patch is required")
		end
		local mutation = self.profile:UpdateSettings(
			player,
			settings :: { [string]: unknown }
		)
		return {
			accepted = mutation.applied,
			reason = mutation.reason,
			state = self:GetGameState(player),
			data = mutation.snapshot,
		}
	elseif actionName == "BuyUpgrade" then
		local request = clonePayload(payload)
		local roleId = getString(request, "roleId")
		local upgradeId = getString(request, "upgradeId")
		if not roleId or not upgradeId then
			return actionRejected("Role and upgrade IDs are required")
		end
		local mutation = self.profile:PurchaseUpgrade(player, roleId, upgradeId)
		return {
			accepted = mutation.applied,
			reason = mutation.reason,
			state = self:GetGameState(player),
			data = mutation.snapshot,
		}
	elseif actionName == "UnlockCosmetic" then
		local request = clonePayload(payload)
		local cosmeticId = getString(request, "cosmeticId")
		if not cosmeticId then
			return actionRejected("Cosmetic ID is required")
		end
		local mutation = self.profile:UnlockCosmetic(player, cosmeticId)
		return {
			accepted = mutation.applied,
			reason = mutation.reason,
			state = self:GetGameState(player),
			data = mutation.snapshot,
		}
	elseif actionName == "EquipCosmetic" then
		local request = clonePayload(payload)
		local cosmeticId = getString(request, "cosmeticId")
		if not cosmeticId then
			return actionRejected("Cosmetic ID is required")
		end
		local mutation = self.profile:EquipCosmetic(player, cosmeticId)
		return {
			accepted = mutation.applied,
			reason = mutation.reason,
			state = self:GetGameState(player),
			data = mutation.snapshot,
		}
	elseif actionName == "AddEvidenceNote" then
		if not participant then
			return actionRejected(participantReason or "Player cannot add a note")
		end
		local request = clonePayload(payload)
		local evidenceId = getString(request, "evidenceId")
		local rawText = getString(request, "text")
		if not evidenceId or not rawText then
			return actionRejected("Evidence ID and note text are required")
		end
		local filteredOk, filteredText = pcall(function(): string
			local filterResult = TextService:FilterStringAsync(
				string.sub(rawText, 1, 160),
				player.UserId,
				Enum.TextFilterContext.PublicChat
			)
			return filterResult:GetNonChatStringForBroadcastAsync()
		end)
		if not filteredOk or filteredText == "" then
			return actionRejected("Evidence note could not be moderated")
		end
		local added, reason = self.evidence:AddNote(
			participant.participantId,
			evidenceId,
			filteredText,
			now()
		)
		if added then
			self:Broadcast()
		end
		return {
			accepted = added,
			reason = reason,
			state = self:GetGameState(player),
			data = nil,
		}
	elseif
		actionName == "UseRoleAbility"
		and rawParticipant
		and rawParticipant.isGhost
	then
		local result = self:_useRoleAbility(rawParticipant, clonePayload(payload))
		if result.accepted then
			self:Broadcast()
			result.state = self:GetGameState(player)
		end
		return result
	elseif
		actionName == "GhostFlickerLight"
		and rawParticipant
		and rawParticipant.isGhost
	then
		return self:_ghostFlickerLight(rawParticipant, clonePayload(payload))
	end
	if not participant then
		return actionRejected(participantReason or "Player cannot act")
	end
	local result = self:_handleParticipantAction(
		participant,
		actionName :: ActionName,
		clonePayload(payload)
	)
	if result.accepted then
		self:Broadcast()
		result.state = self:GetGameState(player)
	end
	return result
end

function GameRuntimeService:_ResolveAccusation()
	local culpritId = self.culpritParticipantId
	if not culpritId then
		self.winner = "Murderer"
		self.resultMessage = "The culprit identity was unavailable."
		return
	end
	local resolution = self.voting:Resolve(culpritId)
	self.winner = resolution.winner
	self.resultMessage = resolution.reason
	if resolution.correct then
		local culprit = self.participants:GetById(culpritId)
		if culprit then
			self.combat:Eliminate(culprit, "Correct campfire accusation", nil)
		end
	end
end

function GameRuntimeService:_ApplyRewards()
	local winner = self.winner
	if not winner then
		return
	end
	local plan = self.murderPlan
	local codexMonsterId = if plan then plan.monsterId else nil
	local culpritId = self.culpritParticipantId
	for _, participant in self.participants:GetAll() do
		-- Spectators earn nothing and ProfileService rejects their roleId;
		-- skipping them keeps round-end logs clean.
		if participant.controller.kind == "Human" and participant.role ~= "Spectator" then
			local player = Players:GetPlayerByUserId(participant.controller.userId)
			if player then
				local result = self.profile:ApplyReward(player, {
					-- Salted with the server's JobId: roundId restarts at 1 on
					-- every server, so unsalted receipts collide across servers
					-- and the duplicate check silently eats legitimate rewards.
					receiptId = string.format(
						"%s:round:%d:user:%d",
						SERVER_REWARD_SALT,
						self.roundId,
						player.UserId
					),
					roleId = participant.role,
					participated = participant.role ~= "Spectator",
					won = participant.team == winner,
					survived = participant.alive and not participant.isGhost,
					objectivesCompleted =
						self.objectivesByParticipantId[participant.participantId] or 0,
					evidenceCollected =
						self.evidenceByParticipantId[participant.participantId] or 0,
					monsterId = codexMonsterId,
					identifiedMonster = participant.vote.targetParticipantId ~= nil
						and participant.vote.targetParticipantId == culpritId,
					checkIns = self.checkInsByParticipantId[participant.participantId]
						or 0,
					coldCasesReviewed = if self.coldCaseCompletedByParticipantId[
							participant.participantId
						]
						then 1
						else 0,
				})
				if not result.applied and not result.duplicate then
					warn(string.format(
						"[GameRuntimeService] Round %d reward failed for %s: %s",
						self.roundId,
						player.Name,
						tostring(result.reason)
					))
				end
			end
		end
	end
end

local CAMPFIRE_POSITION = Vector3.new(0, 2.2, 2)
local CAMPFIRE_SAFE_RADIUS_STUDS = 18

function GameRuntimeService:_reportBody(reporter: Player, victimParticipantId: string)
	local participant = self:_participantForPlayer(reporter)
	if
		not participant
		or not participant.alive
		or participant.isGhost
		or participant.role == "Spectator"
	then
		return
	end
	if self.phase ~= "Investigation" then
		return
	end
	if self.bodyReportedByVictimId[victimParticipantId] then
		return
	end
	self.bodyReportedByVictimId[victimParticipantId] = true
	self.characters:MarkBodyReported(victimParticipantId)
	local victim = self.participants:GetById(victimParticipantId)
	local victimName = if victim then victim.displayName else "A camper"
	-- Reporting counts as finding evidence for the reporter.
	self.evidenceByParticipantId[participant.participantId] =
		(self.evidenceByParticipantId[participant.participantId] or 0) + 1
	self:_announce(
		"DangerBright",
		"Body discovered",
		string.format(
			"%s was found by %s. Find the evidence before campfire.",
			victimName,
			participant.displayName
		),
		6
	)
	self:Broadcast()
end

-- The campfire only wards off the monster if campers stacked firewood
-- during the day. Positions are server-derived, so this cannot be spoofed.
function GameRuntimeService:_isCampfireProtected(target: ParticipantState): boolean
	local outcomes = self.dayOutcomes
	if not outcomes or not outcomes.firewood then
		return false
	end
	local position = participantPosition(target)
	return position ~= nil
		and (position - CAMPFIRE_POSITION).Magnitude <= CAMPFIRE_SAFE_RADIUS_STUDS
end

function GameRuntimeService:_livingHumanCount(): number
	local count = 0
	for _, participant in self.participants:GetAll() do
		if
			participant.controller.kind == "Human"
			and participant.alive
			and not participant.isGhost
			and participant.role ~= "Spectator"
		then
			count += 1
		end
	end
	return count
end

-- Bots must physically reach a site and spend work time there before an
-- action lands. Returns false (retry next think) until the work completes.
function GameRuntimeService:_botWorkAtSite(
	participant: ParticipantState,
	candidateId: string,
	sitePosition: Vector3?,
	rangeStuds: number,
	workSeconds: number,
	execute: () -> boolean
): boolean
	if not sitePosition then
		return false
	end
	local participantId = participant.participantId
	local position = participantPosition(participant)
	if not position then
		return false
	end
	local distance = (position - sitePosition).Magnitude
	local pending = self.botTaskById[participantId]
	if pending and pending.candidateId ~= candidateId then
		pending = nil
	end
	if distance > rangeStuds then
		self.botTaskById[participantId] = { candidateId = candidateId, workReadyAt = nil }
		local travelSeconds = math.clamp(
			distance / BotContributionConfig.walkSpeedStudsPerSecond,
			1,
			BotContributionConfig.maximumTravelSeconds
		)
		self.characters:MoveBotCharacterToward(participantId, sitePosition, travelSeconds)
		return false
	end
	if not pending or not pending.workReadyAt then
		self.botTaskById[participantId] = {
			candidateId = candidateId,
			workReadyAt = now() + workSeconds,
		}
		return false
	end
	if now() < pending.workReadyAt then
		return false
	end
	self.botTaskById[participantId] = nil
	return execute()
end

function GameRuntimeService:_sitePartPosition(part: Instance?): Vector3?
	if part and part:IsA("BasePart") then
		return part.Position
	end
	return nil
end

function GameRuntimeService:_GetBotActions(participant: ParticipantState, phase: PhaseName)
	local actions = {}
	local otherCamperId: string? = nil
	local injuredCamperId: string? = nil
	for _, candidate in self.participants:GetAll() do
		if
			candidate.participantId ~= participant.participantId
			and candidate.team == "Campers"
			and candidate.alive
			and not candidate.isGhost
		then
			otherCamperId = otherCamperId or candidate.participantId
			if candidate.injuryLevel == 1 then
				injuredCamperId = injuredCamperId or candidate.participantId
			end
		end
	end
	local function addRoleAction(
		id: string,
		abilityId: string,
		targetParticipantId: string?,
		baseUtility: number
	)
		table.insert(actions, {
			id = id,
			actionType = "UseRoleAbility",
			baseUtility = baseUtility,
			targetParticipantId = targetParticipantId,
			abilityId = abilityId,
			risk = 0.1,
			informationValue = if participant.role == "Detective" or participant.role == "Medium"
				then 0.9
				else 0.2,
			teamValue = if participant.role == "Murderer" then 0 else 0.85,
		})
	end
	local caps = BotContributionConfig.GetCaps(self:_livingHumanCount())
	if phase == "Day" then
		-- Bots never take the goal-completing objective; humans get the
		-- finishing move. The ropes course is a physical obby, so grounded
		-- bot models skip it entirely.
		local objectivesAllowed = self.botObjectiveCount < caps.objectives
			and self:_objectiveCount() < RoundConfig.objectiveGoal - 1
		for _, objectiveId in OBJECTIVE_IDS do
			if
				objectivesAllowed
				and objectiveId ~= "ropes"
				and not self.completedObjectives[objectiveId]
			then
				table.insert(actions, {
					id = "objective:" .. objectiveId,
					actionType = "CompleteObjective",
					baseUtility = 20,
					objectiveId = objectiveId,
					risk = 0,
					informationValue = 0,
					teamValue = 1,
				})
			end
		end
		if participant.role == "Protector" and otherCamperId then
			addRoleAction("role:protect", "protect-participant", otherCamperId, 24)
		elseif participant.role == "Guard" and otherCamperId then
			addRoleAction("role:guard", "guard-post", otherCamperId, 22)
		elseif participant.role == "Trapper" then
			addRoleAction("role:trap", "place-warning-trap", nil, 20)
		elseif participant.role == "Detective" and otherCamperId then
			addRoleAction("role:investigate", "analyze-evidence", otherCamperId, 25)
		elseif participant.role == "Medic" and injuredCamperId then
			addRoleAction("role:treat", "field-treatment", injuredCamperId, 30)
		end
	elseif phase == "MurderPlanning" and participant.role == "Murderer" then
		local plan = self.murderPlan
		addRoleAction(
			"role:plan",
			"monster-transformation",
			if plan then plan.victimParticipantId else nil,
			35
		)
	elseif phase == "Investigation" then
		local undiscoveredRecords = self.evidence:GetUndiscoveredServer()
		local hiddenLocationCount = 0
		local hiddenLocations: { [string]: boolean } = {}
		if self.mysteryReady then
			for _, clue in self.mystery:GetPrivateSnapshot().clues do
				if clue.discoveryState == "Hidden" and not hiddenLocations[clue.locationId] then
					hiddenLocations[clue.locationId] = true
					hiddenLocationCount += 1
				end
			end
		end
		-- Bots never sweep the final undiscovered site; that beat is reserved
		-- for human investigators.
		local evidenceAllowed = self.botEvidenceCount < caps.evidence
			and (#undiscoveredRecords + hiddenLocationCount) > 1
		if evidenceAllowed then
			for _, record in undiscoveredRecords do
				table.insert(actions, {
					id = "evidence:" .. record.evidenceId,
					actionType = "CollectEvidence",
					baseUtility = 22,
					evidenceId = record.evidenceId,
					risk = 0.2,
					informationValue = 1,
					teamValue = 0.8,
				})
			end
		end
		if self.mysteryReady then
			if evidenceAllowed then
				for locationId in hiddenLocations do
					table.insert(actions, {
						id = "mystery:" .. locationId,
						actionType = "CollectEvidence",
						baseUtility = 24,
						evidenceId = locationId,
						risk = 0.2,
						informationValue = 1,
						teamValue = 0.9,
					})
				end
			end
			for _, account in self.mystery:GetPrivateSnapshot().witnessAccounts do
				if not account.revealed then
					table.insert(actions, {
						id = "interview:" .. account.counselorId,
						actionType = "InterviewCounselor",
						baseUtility = 23,
						counselorId = account.counselorId,
						risk = 0.05,
						informationValue = 1,
						teamValue = 0.9,
					})
				end
			end
		end
		if participant.role == "Murderer" then
			local plan = self.murderPlan
			local targetId = if plan then plan.victimParticipantId else nil
			local target = if targetId then self.participants:GetById(targetId) else nil
			-- A victim standing in stocked firelight is untouchable; the bot
			-- murderer waits instead of hurling itself at the ward.
			if target and target.alive and not self:_isCampfireProtected(target) then
				table.insert(actions, {
					id = "attack:" .. target.participantId,
					actionType = "Attack",
					baseUtility = 25,
					targetParticipantId = target.participantId,
					risk = 0.45,
					informationValue = 0,
					teamValue = 1,
				})
			end
		elseif participant.role == "Detective" then
			for _, record in self.evidence:GetAllServer() do
				if record.posted and record.verificationState == "Unverified" then
					table.insert(actions, {
						id = "verify:" .. record.evidenceId,
						actionType = "VerifyEvidence",
						baseUtility = 18,
						evidenceId = record.evidenceId,
						risk = 0,
						informationValue = 0.9,
						teamValue = 0.9,
					})
				end
			end
		end
		if participant.role == "Protector" and otherCamperId then
			addRoleAction("role:protect-night", "protect-participant", otherCamperId, 27)
		elseif participant.role == "Guard" and otherCamperId then
			addRoleAction("role:guard-night", "guard-post", otherCamperId, 26)
		elseif participant.role == "Trapper" then
			addRoleAction("role:trap-night", "place-warning-trap", nil, 24)
		elseif participant.role == "Detective" and otherCamperId then
			addRoleAction("role:investigate-night", "analyze-evidence", otherCamperId, 28)
		elseif participant.role == "Medium" then
			addRoleAction("role:spirit", "spirit-sense", nil, 24)
		elseif participant.role == "Medic" and injuredCamperId then
			addRoleAction("role:treat-night", "field-treatment", injuredCamperId, 32)
		end
		if participant.isGhost and participant.role == "Protector" and otherCamperId then
			local ghostSnap = self.roleAbilities:GetPrivateSnapshot(participant.participantId)
			if ghostSnap.ghostInterventionAvailable then
				addRoleAction("ghost-protect:" .. otherCamperId, "protect-participant", otherCamperId, 50)
			end
		end
	elseif phase == "Campfire" then
		local publicSuspicion: { [string]: number } = {}
		if self.mysteryReady then
			local publicMystery = self.mystery:GetPublicSnapshot()
			for _, clue in publicMystery.clues do
				if clue.channel == "Culprit" then
					for _, suspectId in clue.suspectCandidateIds do
						publicSuspicion[suspectId] =
							(publicSuspicion[suspectId] or 0) + 1
					end
				end
			end
			for _, account in publicMystery.witnessAccounts do
				if account.channel == "Culprit" then
					for _, suspectId in account.suspectCandidateIds do
						publicSuspicion[suspectId] =
							(publicSuspicion[suspectId] or 0) + 0.7
					end
				end
			end
		end
		-- Evidence presented aloud during the discussion carries extra weight
		-- with bot voters.
		for suspectId, weight in self.presentedSuspicion do
			publicSuspicion[suspectId] = (publicSuspicion[suspectId] or 0) + weight * 1.25
		end
		-- Bots hold their votes until voting opens (plus a personal stagger)
		-- so human accusations lead and bot votes follow.
		local votingOpensAt = self.votingOpensAt
			or (self.phaseStartedAt + 0.5 * (self.phaseEndsAt - self.phaseStartedAt))
		local voteReadyAt = votingOpensAt + voteStagger(participant.participantId)
		if not self.voting.votes[participant.participantId] and now() >= voteReadyAt then
			local humanVotes: { [string]: number } = {}
			for _, other in self.participants:GetAll() do
				local vote = other.vote
				if
					other.controller.kind == "Human"
					and vote
					and vote.hasVoted
					and vote.targetParticipantId
				then
					humanVotes[vote.targetParticipantId] = (humanVotes[vote.targetParticipantId] or 0) + 1
				end
			end
			for _, suspect in self:_suspects() do
				if suspect.key ~= participant.participantId then
					local caseUtility = (publicSuspicion[suspect.key] or 0) * 4
						+ (humanVotes[suspect.key] or 0)
							* BotContributionConfig.humanVoteFollowWeight
					if
						participant.role == "Murderer"
						and self.murderPlan
						and self.murderPlan.frameParticipantId == suspect.key
					then
						caseUtility = 24
					end
					table.insert(actions, {
						id = "vote:" .. suspect.key,
						actionType = "Vote",
						baseUtility = 10 + caseUtility,
						targetParticipantId = suspect.key,
						risk = 0,
						informationValue = 0.7,
						teamValue = 1,
					})
				end
			end
		end
		if self.mysteryReady then
			local campfirePrivate = self.mystery:GetPrivateSnapshot()
			for _, account in campfirePrivate.witnessAccounts do
				if not account.revealed then
					table.insert(actions, {
						id = "campfire-interview:" .. account.counselorId,
						actionType = "InterviewCounselor",
						baseUtility = 7,
						counselorId = account.counselorId,
						risk = 0.05,
						informationValue = 0.7,
						teamValue = 0.5,
					})
				end
			end
		end
	end
	local pending = self.botTaskById[participant.participantId]
	if pending then
		local matched = false
		for _, action in actions do
			if action.id == pending.candidateId then
				-- Keep the bot committed to the site it is already walking to.
				action.baseUtility += BotContributionConfig.commitBonusUtility
				matched = true
				break
			end
		end
		if not matched then
			self.botTaskById[participant.participantId] = nil
		end
	end
	table.insert(actions, {
		id = "idle",
		actionType = "Idle",
		baseUtility = 0,
		risk = 0,
		informationValue = 0,
		teamValue = 0,
	})
	return actions
end

function GameRuntimeService:_ExecuteBotAction(
	participant: ParticipantState,
	candidate
): boolean
	local actionName: ActionName
	local payload: { [string]: unknown } = {}
	if candidate.actionType == "CompleteObjective" then
		actionName = "CompleteObjective"
		payload.objectiveId = candidate.objectiveId
	elseif candidate.actionType == "CollectEvidence" then
		actionName = "DiscoverEvidence"
		payload.evidenceId = candidate.evidenceId
	elseif candidate.actionType == "InterviewCounselor" then
		actionName = "InterviewCounselor"
		payload.counselorId = candidate.counselorId
		local botTopics: { string } = if participant.role == "Murderer"
			then { "Suspicion", "Observation", "Schedule" }
			else { "Observation", "Schedule", "Monster", "Suspicion" }
		payload.topic = botTopics[math.random(1, #botTopics)]
		local counselorPosition = self.characters:GetCounselorPosition(candidate.counselorId)
		return self:_botWorkAtSite(
			participant,
			candidate.id,
			counselorPosition,
			BotContributionConfig.siteRangeStuds,
			BotContributionConfig.interviewWorkSeconds,
			function()
				return self:_handleParticipantAction(participant, actionName, payload).accepted
			end
		)
	elseif candidate.actionType == "Attack" then
		local targetId = candidate.targetParticipantId
		if not targetId then
			return false
		end
		local targetParticipant = self.participants:GetById(targetId)
		local targetPosition = if targetParticipant
			then participantPosition(targetParticipant)
			else nil
		return self:_botWorkAtSite(
			participant,
			candidate.id,
			targetPosition,
			BotContributionConfig.attackRangeStuds,
			BotContributionConfig.attackWindupSeconds,
			function()
				self:_ApplyMonsterAttack(participant.participantId, targetId, "BotAttack")
				return true
			end
		)
	elseif candidate.actionType == "VerifyEvidence" then
		actionName = "VerifyEvidence"
		payload.evidenceId = candidate.evidenceId
	elseif candidate.actionType == "Vote" then
		actionName = "Vote"
		payload.targetParticipantId = candidate.targetParticipantId
	elseif candidate.actionType == "UseRoleAbility" then
		if candidate.abilityId == "field-treatment" then
			local targetId = candidate.targetParticipantId
			if not targetId then
				return false
			end
			local targetParticipant = self.participants:GetById(targetId)
			local targetPosition = if targetParticipant
				then participantPosition(targetParticipant)
				else nil
			return self:_botWorkAtSite(
				participant,
				candidate.id,
				targetPosition,
				BotContributionConfig.treatRangeStuds,
				BotContributionConfig.interviewWorkSeconds,
				function()
					for _, item in self.inventory:GetSnapshot(participant.participantId).items do
						if item.equipmentId == "MedicalKit" then
							self.inventory:Equip(participant.participantId, item.instanceId)
							return self:_useItem(participant, {
								instanceId = item.instanceId,
								targetParticipantId = targetId,
							}).accepted
						end
					end
					return false
				end
			)
		end
		actionName = "UseRoleAbility"
		payload.abilityId = candidate.abilityId
		payload.targetParticipantId = candidate.targetParticipantId
		payload.locationId = self.murderPlan and self.murderPlan.locationId
			or "current-location"
		if candidate.abilityId == "monster-transformation" then
			local plan = self.murderPlan
			payload.monsterId = if plan then plan.monsterId else nil
			payload.frameParticipantId = if plan then plan.frameParticipantId else nil
		end
	elseif candidate.actionType == "Idle" or candidate.actionType == "Discuss" then
		return true
	else
		return false
	end
	if actionName == "CompleteObjective" then
		local objectiveId = getString(payload, "objectiveId")
		if not objectiveId then
			return false
		end
		return self:_botWorkAtSite(
			participant,
			candidate.id,
			self:_sitePartPosition(self:_objectivePart(objectiveId)),
			BotContributionConfig.siteRangeStuds,
			BotContributionConfig.objectiveWorkSeconds,
			function()
				local accepted = self:_completeObjective(participant, objectiveId, true).accepted
				if accepted then
					self.botObjectiveCount += 1
				end
				return accepted
			end
		)
	elseif actionName == "DiscoverEvidence" then
		local evidenceId = getString(payload, "evidenceId")
		if not evidenceId then
			return false
		end
		-- Resolve the search site the same way _discoverEvidence does: the
		-- socket alias if one exists, else the record's assigned location.
		local aliasId: string? = nil
		local resolvedEvidenceId = self.evidenceAliasById[evidenceId] or evidenceId
		for candidateAlias, mappedEvidenceId in self.evidenceAliasById do
			if mappedEvidenceId == resolvedEvidenceId then
				aliasId = candidateAlias
				break
			end
		end
		aliasId = aliasId
			or self.evidenceLocationById[resolvedEvidenceId]
			or evidenceId
		return self:_botWorkAtSite(
			participant,
			candidate.id,
			self:_sitePartPosition(self:_evidencePart(aliasId)),
			BotContributionConfig.siteRangeStuds,
			BotContributionConfig.evidenceWorkSeconds,
			function()
				local accepted = self:_discoverEvidence(participant, evidenceId, true).accepted
				if accepted then
					self.botEvidenceCount += 1
				end
				return accepted
			end
		)
	end
	return self:_handleParticipantAction(participant, actionName, payload).accepted
end

function GameRuntimeService:_waitUntilPhaseEnds()
	while self.running and now() < self.phaseEndsAt do
		task.wait(0.25)
	end
end

function GameRuntimeService:_continueRound(generation: number, nextPhase: PhaseName): boolean
	if not self.running or self.generation ~= generation then
		return false
	end
	self:EnterPhase(nextPhase)
	self:_waitUntilPhaseEnds()
	return self.running and self.generation == generation
end

function GameRuntimeService:_recoverRoundFailure(generation: number, failure: unknown)
	if not self.running or self.generation ~= generation then
		return
	end
	warn("[GameRuntimeService] Round aborted safely:", failure)
	self.computerPlayers:Stop()
	local matchRoundId = self.activeMatchRoundId
	if matchRoundId then
		self.matchmaking:FinishRound(matchRoundId)
		self.activeMatchRoundId = nil
	end
	pcall(function()
		self.world:ResetRound()
	end)
	pcall(function()
		self.characters:Reset()
	end)
	pcall(function()
		self.monster:Reset(self.roundId)
	end)
	pcall(function()
		self.characters:ClearMonster()
	end)
	pcall(function()
		self.lifecycle:Emit("RoundReset", {
			reason = "RuntimeFailure",
		})
	end)
	self.winner = nil
	self.resultMessage = nil
	self.phase = "Lobby"
	self.phaseStartedAt = now()
	self.phaseEndsAt = self.phaseStartedAt + phaseDuration("Lobby")
	pcall(function()
		self:Broadcast()
	end)
end

function GameRuntimeService:_runRound(generation: number)
	local ids = self:_participantIdsForRound()
	if #ids < 2 then
		task.wait(1)
		return
	end
	if not self.running or self.generation ~= generation then
		return
	end
	self:BeginRound(ids)
	self:_waitUntilPhaseEnds()
	if not self:_continueRound(generation, "Day") then
		return
	end
	if not self:_continueRound(generation, "MurderPlanning") then
		return
	end
	if not self:_continueRound(generation, "NightTransform") then
		return
	end
	if not self:_continueRound(generation, "Investigation") then
		return
	end
	if not self:_continueRound(generation, "Campfire") then
		return
	end
	if not self:_continueRound(generation, "Resolution") then
		return
	end
	if not self:_continueRound(generation, "Rewards") then
		return
	end
	local matchRoundId = self.activeMatchRoundId
	if matchRoundId then
		self.matchmaking:FinishRound(matchRoundId)
		self.activeMatchRoundId = nil
	end
	self:_continueRound(generation, "Lobby")
end

function GameRuntimeService:Start()
	if self.running then
		return
	end
	self.running = true
	self.generation += 1
	local generation = self.generation
	for _, player in Players:GetPlayers() do
		self:_createHuman(player)
	end
	self.profile:Start()
	self.matchmaking:Start()
	self:_readyStudioPlayers()
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player: Player)
		self:_createHuman(player)
		task.defer(function()
			self:_readyStudioPlayers()
			self:Broadcast()
		end)
	end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player: Player)
		self.participants:SetHumanConnected(player.UserId, false)
	end))
	self.characters:Reset()
	self:EnterPhase("Lobby")

	if self.options.autoRun ~= false then
		task.spawn(function()
			while self.running and self.generation == generation do
				while self.running and #Players:GetPlayers() == 0 do
					task.wait(1)
				end
				if self.running then
					local success, failure = pcall(function()
						self:_runRound(generation)
					end)
					if not success then
						self:_recoverRoundFailure(generation, failure)
						task.wait(1)
					end
				end
			end
		end)
	end
	task.spawn(function()
		while self.running and self.generation == generation do
			task.wait(3)
			if self.running and self.generation == generation and self.phase ~= "Lobby" then
				self:Broadcast()
			end
		end
	end)
end

function GameRuntimeService:Stop()
	if not self.running then
		return
	end
	self.running = false
	self.generation += 1
	self.computerPlayers:Destroy()
	local matchRoundId = self.activeMatchRoundId
	if matchRoundId then
		self.matchmaking:FinishRound(matchRoundId)
		self.activeMatchRoundId = nil
	end
	self.matchmaking:Stop()
	self.profile:Stop()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	pcall(function()
		self.world:ResetRound()
	end)
	self.characters:Destroy()
	self.counselors:Destroy()
	self.lifecycle:Destroy()
end

function GameRuntimeService:GetServices(): { [string]: any }
	return {
		participants = self.participants,
		inventory = self.inventory,
		combat = self.combat,
		evidence = self.evidence,
		mystery = self.mystery,
		counselors = self.counselors,
		monster = self.monster,
		world = self.world,
		statusEffects = self.statusEffects,
		roleAbilities = self.roleAbilities,
		voting = self.voting,
		lifecycle = self.lifecycle,
		computerPlayers = self.computerPlayers,
		lobby = self.lobby,
		matchmaking = self.matchmaking,
		profile = self.profile,
	}
end

return GameRuntimeService
