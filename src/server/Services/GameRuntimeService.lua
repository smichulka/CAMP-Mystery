--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchConfig = require(Shared.Config:WaitForChild("MatchConfig"))
local RoundConfig = require(Shared.Config:WaitForChild("RoundConfig"))
local EquipmentRules = require(
	script.Parent.Parent.Config:WaitForChild("EquipmentRules")
)
local CombatTypes = require(Shared.Types:WaitForChild("CombatTypes"))
local EquipmentTypes = require(Shared.Types:WaitForChild("EquipmentTypes"))
local GameTypes = require(Shared.Types:WaitForChild("GameTypes"))
local MonsterTypes = require(Shared.Types:WaitForChild("MonsterTypes"))
local ParticipantTypes = require(Shared.Types:WaitForChild("ParticipantTypes"))
local RuntimeTypes = require(Shared.Types:WaitForChild("RuntimeTypes"))

local services = script.Parent
local systems = script.Parent.Parent:WaitForChild("Systems")
local CombatService = require(services:WaitForChild("CombatService"))
local ComputerPlayerService = require(services:WaitForChild("ComputerPlayerService"))
local EvidenceService = require(services:WaitForChild("EvidenceService"))
local GrayboxMapService = require(services:WaitForChild("GrayboxMapService"))
local InventoryService = require(services:WaitForChild("InventoryService"))
local LobbyService = require(services:WaitForChild("LobbyService"))
local MatchmakingService = require(services:WaitForChild("MatchmakingService"))
local MonsterService = require(services:WaitForChild("MonsterService"))
local ParticipantService = require(services:WaitForChild("ParticipantService"))
local PlaceholderCharacterService =
	require(services:WaitForChild("PlaceholderCharacterService"))
local ProfileService = require(services:WaitForChild("ProfileService"))
local RoleAbilityService = require(services:WaitForChild("RoleAbilityService"))
local RoundLifecycle = require(services:WaitForChild("RoundLifecycle"))
local StatusEffectService = require(services:WaitForChild("StatusEffectService"))
local VotingService = require(services:WaitForChild("VotingService"))
local WorldService = require(services:WaitForChild("WorldService"))
local BotRosterSystem = require(systems:WaitForChild("BotRosterSystem"))

type ActionName = RuntimeTypes.ActionName
type ActionResult = RuntimeTypes.ActionResult
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
	activeMatchRoundId: string?,
	connections: { RBXScriptConnection },
	participants: ParticipantService.ParticipantService,
	lifecycle: RoundLifecycle.RoundLifecycle,
	inventory: InventoryService.InventoryService,
	combat: CombatService.CombatService,
	evidence: EvidenceService.EvidenceService,
	monster: MonsterService.MonsterService,
	world: WorldService.WorldService,
	statusEffects: StatusEffectService.StatusEffectService,
	roleAbilities: RoleAbilityService.RoleAbilityService,
	voting: VotingService.VotingService,
	characters: PlaceholderCharacterService.PlaceholderCharacterService,
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

local OBJECTIVE_IDS = { "firewood", "generator", "supplies" }
local SEARCH_LOCATIONS = {
	"main-road-clue-a",
	"residential-bedroom-clue",
	"square-gas-station-clue",
	"industrial-machine-clue",
	"water-tower-base-clue",
	"police-evidence-room-clue",
	"outskirts-company-house-clue",
}
local MONSTER_ORDER: { MonsterId } = {
	"BabyAlien",
	"Screamer",
	"Wendigo",
	"ShadowMonster",
	"Chupacabra",
	"Dullahan",
	"Entity",
	"Banshee",
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

local function unobstructed(fromPosition: Vector3, toPosition: Vector3): boolean
	local direction = toPosition - fromPosition
	if direction.Magnitude <= 0.01 then
		return true
	end
	local result = Workspace:Raycast(fromPosition, direction)
	return result == nil or (result.Position - toPosition).Magnitude <= 4
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

local function participantPosition(participant: ParticipantState): Vector3?
	local player = findPlayerForParticipant(participant)
	if player then
		return playerRootPosition(player)
	end
	local offset = #participant.participantId % 8
	return Vector3.new(offset * 4, 3, -60 - offset * 3)
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
	local matchmaking = MatchmakingService.new(lobby, botRoster, {
		onBotReplacement = function(context, replacement, _roster)
			local departed = participants:GetByUserId(context.userId)
			local replacementState = participants:GetById(replacement.participantId)
			if not departed or not replacementState then
				return
			end

			replacementState.role = departed.role
			replacementState.team = departed.team
			replacementState.alive = departed.alive
			replacementState.isGhost = departed.isGhost
			replacementState.healthState = departed.healthState
			replacementState.health = departed.health
			replacementState.maxHealth = departed.maxHealth
			replacementState.injuryLevel = departed.injuryLevel
			replacementState.evidenceKnowledge = table.clone(departed.evidenceKnowledge)
			replacementState.vote = table.clone(departed.vote)
			replacementState.abilityUses = table.clone(departed.abilityUses)
			replacementState.abilityCooldownEndsAt =
				table.clone(departed.abilityCooldownEndsAt)
			inventory:RegisterParticipant(replacementState.participantId)
			for _, instanceId in table.clone(departed.inventoryIds) do
				inventory:Transfer(
					departed.participantId,
					replacementState.participantId,
					instanceId
				)
				participants:RemoveInventoryItem(departed.participantId, instanceId)
				participants:AddInventoryItem(replacementState.participantId, instanceId)
			end
			departed.role = "Spectator"
			departed.team = "Observers"
			departed.alive = false
			departed.isGhost = false
			local runtime = runtimeRef
			if runtime then
				runtime.statusEffects:TransferParticipant(
					departed.participantId,
					replacementState.participantId
				)
				runtime.roleAbilities:TransferParticipant(
					departed.participantId,
					replacementState.participantId
				)
				runtime.voting:TransferParticipant(
					departed.participantId,
					replacementState.participantId
				)
				runtime.objectivesByParticipantId[replacementState.participantId] =
					runtime.objectivesByParticipantId[departed.participantId]
				runtime.objectivesByParticipantId[departed.participantId] = nil
				runtime.evidenceByParticipantId[replacementState.participantId] =
					runtime.evidenceByParticipantId[departed.participantId]
				runtime.evidenceByParticipantId[departed.participantId] = nil
				for objectiveId, ownerId in runtime.completedObjectives do
					if ownerId == departed.participantId then
						runtime.completedObjectives[objectiveId] =
							replacementState.participantId
					end
				end
				local murderPlan = runtime.murderPlan
				if murderPlan then
					if murderPlan.victimParticipantId == departed.participantId then
						murderPlan.victimParticipantId = replacementState.participantId
					end
					if murderPlan.frameParticipantId == departed.participantId then
						murderPlan.frameParticipantId = replacementState.participantId
					end
				end
				runtime.computerPlayers:RegisterBot(replacementState.participantId)
				if runtime.culpritParticipantId == departed.participantId then
					runtime.culpritParticipantId = replacementState.participantId
					runtime.evidence:TransferCulprit(
						departed.participantId,
						replacementState.participantId
					)
					runtime.monster:TransferControl(
						runtime.roundId,
						replacementState.participantId
					)
				end
				runtime:Broadcast()
			end
		end,
	})

	local mapService = GrayboxMapService.new(
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
	local characters = PlaceholderCharacterService.new()

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
		hasLineOfSight = function(fromPosition: Vector3, toPosition: Vector3): boolean
			return unobstructed(fromPosition, toPosition)
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
		activeMatchRoundId = nil,
		connections = {},
		participants = participants,
		lifecycle = lifecycle,
		inventory = inventory,
		combat = combat,
		evidence = evidence,
		monster = monster,
		world = world,
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

function GameRuntimeService:_participantForPlayer(player: Player): ParticipantState?
	return self.participants:GetByUserId(player.UserId)
end

function GameRuntimeService:_participantIdsForRound(): { string }
	local roster = self.matchmaking:GetActiveRoster()
	if not roster then
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
		self.evidenceLocationById[record.evidenceId] =
			SEARCH_LOCATIONS[((index - 1) % #SEARCH_LOCATIONS) + 1]
		if index == 1 then
			self.evidenceAliasById["muddy-bootprint"] = record.evidenceId
		elseif index == 2 then
			self.evidenceAliasById["torn-fabric"] = record.evidenceId
		elseif index == 3 then
			self.evidenceAliasById["dropped-token"] = record.evidenceId
		end
	end
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

	self.winner = nil
	self.resultMessage = nil
	self.victimName = nil
	self.completedObjectives = {}
	self.objectivesByParticipantId = {}
	self.evidenceByParticipantId = {}
	self.murderPlan = nil

	for _, participantId in selectedIds do
		self.inventory:RegisterParticipant(participantId)
		local participant = self.participants:GetById(participantId)
		if participant then
			self:_grantLoadout(participant)
		end
	end

	local culprit = self:_findCulprit()
	self.culpritParticipantId = culprit.participantId
	local monsterId = MONSTER_ORDER[((roundId - 1) % #MONSTER_ORDER) + 1]
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

	if phase == "Day" then
		self.world:SetObjectivePromptsEnabled(true)
	elseif phase == "MurderPlanning" then
		self.world:SetObjectivePromptsEnabled(false)
		self.monster:BeginPlanning(self.roundId)
	elseif phase == "NightTransform" then
		self.world:SetNight(true)
		local privateMonster = self.monster:GetPrivateSnapshot()
		local monsterId = privateMonster.monsterId
		local participantId = privateMonster.participantId
		if monsterId and participantId then
			self.characters:SpawnMonster(
				monsterId,
				participantId,
				CFrame.new(0, 4, -65)
			)
		end
	elseif phase == "Investigation" then
		self.world:SpawnEvidence()
		self.monster:Activate(self.roundId)
	elseif phase == "Campfire" then
		self.world:ClearEvidence()
		self.monster:CampfireStop(self.roundId)
		self.characters:ClearMonster()
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
	return {
		roundNumber = self.roundId,
		phase = self.phase,
		phaseDisplayName = phaseDisplayName(self.phase),
		phaseStartedAt = self.phaseStartedAt,
		phaseEndsAt = self.phaseEndsAt,
		serverNow = now(),
		objectivesCompleted = self:_objectiveCount(),
		objectiveGoal = RoundConfig.objectiveGoal,
		evidenceFound = #self:_evidenceSummaries(),
		evidenceGoal = RoundConfig.evidenceGoal,
		evidence = self:_evidenceSummaries(),
		suspects = self:_suspects(),
		votesCast = voteSnapshot.votesCast,
		eligibleVoters = voteSnapshot.eligibleVoters,
		victimName = self.victimName,
		winner = self.winner,
		resultMessage = self.resultMessage,
		isNight = self.world:GetPublicSnapshot().isNight,
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
		"CompleteObjective",
		"DiscoverEvidence",
		"Vote",
		"EquipItem",
		"UseItem",
		"DropItem",
		"TransferItem",
		"UseRoleAbility",
		"UseMonsterAbility",
		"VerifyEvidence",
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
		elseif name == "CompleteObjective" then
			enabled = active and self.phase == "Day"
		elseif name == "DiscoverEvidence" then
			enabled = active and self.phase == "Investigation"
		elseif name == "Vote" then
			enabled = active and self.phase == "Campfire"
		elseif name == "UseMonsterAbility" then
			enabled = active
				and self.phase == "Investigation"
				and participant ~= nil
				and participant.role == "Murderer"
		elseif name == "VerifyEvidence" then
			enabled = active and participant ~= nil and participant.role == "Detective"
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
		monster = self.monster:GetPublicSnapshot(),
		privateMonster = privateMonster,
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
	return if objectives then objectives:FindFirstChild(objectiveId) else nil
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
	self.evidenceLocationById[record.evidenceId] =
		self.murderPlan and self.murderPlan.locationId or SEARCH_LOCATIONS[1]
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
		if
			not aliasId
			or not self:_isNearPart(participant, self:_evidencePart(aliasId), 14)
		then
			return actionRejected("Move closer to the evidence")
		end
	end
	local locationId = self.evidenceLocationById[record.evidenceId] or requestedEvidenceId
	local discovered, reason = self.evidence:Discover(
		participant.participantId,
		record.evidenceId,
		locationId,
		now()
	)
	if not discovered then
		return actionRejected(reason or "Evidence discovery failed")
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
	if #self:_evidenceSummaries() >= RoundConfig.evidenceGoal then
		self.phaseEndsAt = math.min(self.phaseEndsAt, now() + 2)
	end
	return {
		accepted = true,
		reason = nil,
		state = nil,
		data = { evidenceId = record.evidenceId, locationId = locationId },
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
		if not unobstructed(sourcePosition, targetPosition) then
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
	if actionName == "CompleteObjective" then
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
	elseif actionName == "Vote" then
		if self.phase ~= "Campfire" then
			return actionRejected("Voting is not active")
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
			or not unobstructed(sourcePosition, targetPosition)
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
	end
	return actionRejected("Action is handled by another server domain")
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
	for _, participant in self.participants:GetAll() do
		if participant.controller.kind == "Human" then
			local player = Players:GetPlayerByUserId(participant.controller.userId)
			if player then
				self.profile:ApplyReward(player, {
					receiptId = string.format("round:%d:user:%d", self.roundId, player.UserId),
					roleId = participant.role,
					participated = participant.role ~= "Spectator",
					won = participant.team == winner,
					survived = participant.alive and not participant.isGhost,
					objectivesCompleted =
						self.objectivesByParticipantId[participant.participantId] or 0,
					evidenceCollected =
						self.evidenceByParticipantId[participant.participantId] or 0,
				})
			end
		end
	end
end

function GameRuntimeService:_GetBotActions(participant: ParticipantState, phase: PhaseName)
	local actions = {}
	if phase == "Day" then
		for _, objectiveId in OBJECTIVE_IDS do
			if not self.completedObjectives[objectiveId] then
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
	elseif phase == "Investigation" then
		for _, record in self.evidence:GetUndiscoveredServer() do
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
		if participant.role == "Murderer" then
			local plan = self.murderPlan
			local targetId = if plan then plan.victimParticipantId else nil
			local target = if targetId then self.participants:GetById(targetId) else nil
			if target and target.alive then
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
		end
	elseif phase == "Campfire" then
		for _, suspect in self:_suspects() do
			if suspect.key ~= participant.participantId then
				table.insert(actions, {
					id = "vote:" .. suspect.key,
					actionType = "Vote",
					baseUtility = if participant.role == "Murderer" then 14 else 10,
					targetParticipantId = suspect.key,
					risk = 0,
					informationValue = 0.7,
					teamValue = 1,
				})
			end
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
	elseif candidate.actionType == "Attack" then
		local targetId = candidate.targetParticipantId
		if not targetId then
			return false
		end
		self:_ApplyMonsterAttack(participant.participantId, targetId, "BotAttack")
		return true
	elseif candidate.actionType == "Vote" then
		actionName = "Vote"
		payload.targetParticipantId = candidate.targetParticipantId
	elseif candidate.actionType == "Idle" or candidate.actionType == "Discuss" then
		return true
	else
		return false
	end
	if actionName == "CompleteObjective" then
		local objectiveId = getString(payload, "objectiveId")
		return objectiveId ~= nil
			and self:_completeObjective(participant, objectiveId, false).accepted
	elseif actionName == "DiscoverEvidence" then
		local evidenceId = getString(payload, "evidenceId")
		return evidenceId ~= nil
			and self:_discoverEvidence(participant, evidenceId, false).accepted
	end
	return self:_handleParticipantAction(participant, actionName, payload).accepted
end

function GameRuntimeService:_waitUntilPhaseEnds()
	while self.running and now() < self.phaseEndsAt do
		task.wait(0.25)
	end
end

function GameRuntimeService:_runRound()
	local ids = self:_participantIdsForRound()
	if #ids < 2 then
		task.wait(1)
		return
	end
	self:BeginRound(ids)
	self:_waitUntilPhaseEnds()
	self:EnterPhase("Day")
	self:_waitUntilPhaseEnds()
	self:EnterPhase("MurderPlanning")
	self:_waitUntilPhaseEnds()
	self:EnterPhase("NightTransform")
	self:_waitUntilPhaseEnds()
	self:EnterPhase("Investigation")
	self:_waitUntilPhaseEnds()
	self:EnterPhase("Campfire")
	self:_waitUntilPhaseEnds()
	self:EnterPhase("Resolution")
	self:_waitUntilPhaseEnds()
	self:EnterPhase("Rewards")
	self:_waitUntilPhaseEnds()
	local matchRoundId = self.activeMatchRoundId
	if matchRoundId then
		self.matchmaking:FinishRound(matchRoundId)
		self.activeMatchRoundId = nil
	end
	self:EnterPhase("Lobby")
	self:_waitUntilPhaseEnds()
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
	table.insert(self.connections, Players.PlayerAdded:Connect(function(player: Player)
		self:_createHuman(player)
		task.defer(function()
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
					self:_runRound()
				end
			end
		end)
	end
end

function GameRuntimeService:Stop()
	self.running = false
	self.generation += 1
	self.computerPlayers:Stop()
	self.matchmaking:Stop()
	self.profile:Stop()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	self.characters:ClearMonster()
end

function GameRuntimeService:GetServices(): { [string]: any }
	return {
		participants = self.participants,
		inventory = self.inventory,
		combat = self.combat,
		evidence = self.evidence,
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
