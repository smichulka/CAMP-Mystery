--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RuntimeTypes = require(Shared:WaitForChild("Types"):WaitForChild("RuntimeTypes"))
local uiFolder = script.Parent.Parent:WaitForChild("UI")
local Components = require(uiFolder:WaitForChild("Components"))
local GameViewModule = require(uiFolder:WaitForChild("GameView"))
local EffectsViewModule = require(uiFolder:WaitForChild("EffectsView"))
local Motion = require(uiFolder:WaitForChild("Motion"))
local NametagsView = require(uiFolder:WaitForChild("NametagsView"))
local PlayerStatusViewModule = require(uiFolder:WaitForChild("PlayerStatusView"))
local AccessibilityController = require(script.Parent:WaitForChild("AccessibilityController"))
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local CameraControllerModule = require(script.Parent:WaitForChild("CameraController"))
local CinematicsController = require(script.Parent:WaitForChild("CinematicsController"))
local HapticController = require(script.Parent:WaitForChild("HapticController"))
local InputController = require(script.Parent:WaitForChild("InputController"))
local InteractionController = require(script.Parent:WaitForChild("InteractionController"))
local ProximityControllerModule = require(
	script.Parent:WaitForChild("ProximityController")
)
local RemoteBridgeModule = require(script.Parent:WaitForChild("RemoteBridge"))
local TutorialController = require(script.Parent:WaitForChild("TutorialController"))
local UIAssetControllerModule = require(script.Parent:WaitForChild("UIAssetController"))

type GameState = RuntimeTypes.GameState
type ActionResult = RuntimeTypes.ActionResult
type Announcement = RuntimeTypes.Announcement
type GameView = GameViewModule.GameView
type RemoteBridge = RemoteBridgeModule.RemoteBridge
type UIAssetController = UIAssetControllerModule.UIAssetController
type ProximityController = ProximityControllerModule.ProximityController
type CameraController = CameraControllerModule.CameraController
type RoundSummaryStats = {
	roundNumber: number,
	winner: string,
	isHumanWin: boolean,
	evidenceFound: number,
	evidenceGoal: number,
	objectivesCompleted: number,
	objectiveGoal: number,
	survivorCount: number,
	totalParticipants: number,
	monsterId: string?,
	victimName: string?,
	personalEvidence: number,
	playerRole: string,
	killCount: number?,
	votesAgainstMe: number?,
	wasCaught: boolean?,
}

local RoundController = {}

local HINT_PHASES: { [string]: boolean } = {
	Day = true,
	Investigation = true,
	Campfire = true,
}

local MURDERER_HINT_PHASES: { [string]: boolean } = {
	MurderPlanning = true,
	NightTransform = true,
}

local MURDERER_ANNOUNCEMENT_COPY: {
	[string]: { title: string, message: string },
} = {
	["Your Role Is Ready"] = {
		title = "YOUR ROLE IS SET",
		message = "You are among them, and you are the threat. Keep your composure.",
	},
	["Daylight Objectives"] = {
		title = "A NEW DAY",
		message = "Blend in with the camp. Complete tasks and draw no suspicion.",
	},
	["Dusk Settles Over Camp"] = {
		title = "YOUR PLAN",
		message = "Choose your target. You have until dawn.",
	},
	["The Town Is Appearing"] = {
		title = "YOUR HUNT BEGINS",
		message = "You are the threat. Move unseen.",
	},
	["Night Investigation"] = {
		title = "THEY ARE SEARCHING",
		message = "Stay calm. Blend in. Cast doubt.",
	},
	["Campfire Accusation"] = {
		title = "THE VOTE",
		message = "Steer the blame. A tie breaks in your favor.",
	},
}

local started = false
local state: GameState? = nil
local legacyRound: any = nil
local legacyPlayer: any = nil
local view: GameView? = nil
local bridge: RemoteBridge? = nil
local accessibility: any = nil
local audio: any = nil
local camera: CameraController? = nil
local cinematics: any = nil
local effects: any = nil
local nametags: any = nil
local playerStatus: any = nil
local tutorial: any = nil
local uiAssets: UIAssetController? = nil
local proximity: ProximityController? = nil
local interactionConnections: { RBXScriptConnection } = {}
local lastCinematicPhase: string? = nil
local lastEvidenceFound = 0
local lastCulpritEvidenceCount = 0
local lastMonsterEvidenceCount = 0
local lastRevealedWitnessCount = 0
local lastObjectivesCompleted = 0
local lastAbilityWasCooling: boolean? = nil
local lastStaminaWasLow: boolean? = nil
local receivedFullState = false
local lastRoleRevealRound: number? = nil
local lastWinnerAnnounced: string? = nil
local lastVoteCompleteRound: number? = nil
local lastIsGhost: boolean? = nil
-- FIFO of in-flight action names; results arrive in request order, so the
-- oldest entry always corresponds to the next result (a single slot would
-- mislabel results when two actions overlap in flight).
local pendingActionNames: { string } = {}
local lastHealthState: string? = nil
local HEALTH_SEVERITY: { [string]: number } = {
	Healthy = 0,
	Injured = 1,
	Critical = 2,
	Incapacitated = 3,
}
local lastHealthSeverity: number? = nil
local lastConnectedState: { [string]: boolean } = {}
local lastParticipantAliveStates: { [string]: boolean } = {}
local lastHintRound: number? = nil
local lastToastedRound: number? = nil
local sentUrgencyWarning = false
local seenHintPhases: { [string]: boolean } = {}
-- Ghost objective sync: the free-fly camera position is reported once a
-- second during Investigation so the server can score ghost objectives.
local GHOST_SYNC_INTERVAL_SECONDS = 1
local lastGhostSyncClock = 0
local lastGhostSnapshot: any = nil

local function playerRootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function replicatedMonsterPosition(snapshot: any): Vector3?
	if type(snapshot) ~= "table" or type(snapshot.monster) ~= "table" then
		return nil
	end
	local participantId = snapshot.monster.participantId
	if type(participantId) ~= "string" or participantId == "" then
		return nil
	end
	-- Spawned monsters live in Runtime.Characters.GeneratedCharacters (same
	-- home resolveActiveMonsterId reads). This used to walk the ENTIRE
	-- workspace — tens of thousands of instances per state snapshot — which
	-- hitched every broadcast once the full map existed.
	local runtime = Workspace:FindFirstChild("Runtime")
	local characters = if runtime then runtime:FindFirstChild("Characters") else nil
	local generated = if characters
		then characters:FindFirstChild("GeneratedCharacters")
		else nil
	if not generated then
		return nil
	end
	for _, child in generated:GetChildren() do
		if child:IsA("Model")
			and child:GetAttribute("ParticipantId") == participantId
			and type(child:GetAttribute("MonsterId")) == "string"
		then
			local root = child.PrimaryPart
				or child:FindFirstChild("HumanoidRootPart", true)
			if root and root:IsA("BasePart") then
				return root.Position
			end
			return child:GetPivot().Position
		end
	end
	return nil
end

local function monsterDreadFraction(snapshot: any): number
	if type(snapshot) ~= "table" or type(snapshot.round) ~= "table" then
		return 0
	end
	local phase = snapshot.round.phase
	if phase ~= "Investigation" and phase ~= "NightTransform" then
		return 0
	end
	local playerPosition = playerRootPosition()
	local monsterPosition = replicatedMonsterPosition(snapshot)
	if not playerPosition or not monsterPosition then
		return 0
	end
	local distance = (monsterPosition - playerPosition).Magnitude
	if distance ~= distance or math.abs(distance) == math.huge or distance > 40 then
		return 0
	end
	if distance <= 8 then
		return 1
	end
	return 1 - ((distance - 8) / 32)
end

-- Which monster's audio should play. The public snapshot only exposes
-- monsterId at resolution, but during night phases the spawned monster
-- model (visible to everyone anyway) carries its id as an attribute.
local function resolveActiveMonsterId(snapshot: any): string?
	if type(snapshot) ~= "table" or type(snapshot.round) ~= "table" then
		return nil
	end
	local phase = snapshot.round.phase
	if phase ~= "Investigation" and phase ~= "NightTransform" then
		return nil
	end
	if type(snapshot.round.monsterId) == "string" and snapshot.round.monsterId ~= "" then
		return snapshot.round.monsterId
	end
	local runtime = workspace:FindFirstChild("Runtime")
	local characters = if runtime then runtime:FindFirstChild("Characters") else nil
	local generated = if characters
		then characters:FindFirstChild("GeneratedCharacters")
		else nil
	if not generated then
		return nil
	end
	for _, child in generated:GetChildren() do
		if child:IsA("Model") then
			local monsterId = child:GetAttribute("MonsterId")
			if type(monsterId) == "string" and monsterId ~= "" then
				return monsterId
			end
		end
	end
	return nil
end

local function evidenceList(snapshot: any, key: string): { any }
	if type(snapshot) ~= "table" or type(snapshot.evidence) ~= "table" then
		return {}
	end
	local value = snapshot.evidence[key]
	return if type(value) == "table" then value else {}
end

local function evidenceFoundCount(snapshot: any): number
	if type(snapshot) == "table"
		and type(snapshot.round) == "table"
		and type(snapshot.round.evidenceFound) == "number"
	then
		local value = snapshot.round.evidenceFound
		if value == value and math.abs(value) < math.huge then
			return math.max(0, value)
		end
	end
	return 0
end

local function readString(value: any, key: string, fallback: string): string
	if type(value) == "table" and type(value[key]) == "string" then
		return value[key]
	end
	return fallback
end

local function readNumber(value: any, key: string, fallback: number): number
	if type(value) == "table" and type(value[key]) == "number" then
		local numberValue = value[key]
		if numberValue == numberValue and math.abs(numberValue) < math.huge then
			return numberValue
		end
	end
	return fallback
end

local function readBoolean(value: any, key: string, fallback: boolean): boolean
	if type(value) == "table" and type(value[key]) == "boolean" then
		return value[key]
	end
	return fallback
end

local function updateInvestigationUrgencyWarning(snapshot: any)
	local round = if type(snapshot) == "table" then snapshot.round else nil
	local phaseName = if type(round) == "table" and type(round.phase) == "string"
		then round.phase
		else nil
	if phaseName ~= "Investigation" then
		sentUrgencyWarning = false
		return
	end
	local currentView = view
	if not currentView or sentUrgencyWarning then
		return
	end
	local phaseEndsAt = readNumber(round, "phaseEndsAt", 0)
	local remaining = phaseEndsAt - Workspace:GetServerTimeNow()
	if remaining > 0 and remaining < 60 then
		local urgPlayer = if type(snapshot) == "table" then snapshot.player else nil
		local urgIsGhost = type(urgPlayer) == "table" and urgPlayer.isGhost == true
		local urgRole = if type(urgPlayer) == "table" and type(urgPlayer.role) == "string"
			then urgPlayer.role
			else ""
		if not urgIsGhost and urgRole ~= "Spectator" then
			sentUrgencyWarning = true
			if urgRole == "Murderer" then
				currentView:Notify(
					"Investigation ending",
					"The campers are running out of time. Prepare for the vote.",
					"Success"
				)
			else
				currentView:Notify(
					"Investigation closing",
					"Under a minute left. Post your evidence before campfire.",
					"DangerBright"
				)
			end
		end
	end
end

local function evidenceCopy(entry: any): (string, string)
	if type(entry) ~= "table" then
		return "New evidence found", ""
	end
	local name = if type(entry.displayName) == "string"
		then entry.displayName
		elseif type(entry.name) == "string"
		then entry.name
		elseif type(entry.title) == "string" then entry.title else "New evidence found"
	local description = if type(entry.description) == "string"
		then entry.description
		elseif type(entry.publicDescription) == "string" then entry.publicDescription else ""
	return name, description
end

local function playVoteReveal(
	snapshot: any,
	gameView: GameView,
	onComplete: (() -> ())?,
	roleName: string
)
	local round = if type(snapshot) == "table" then snapshot.round else nil
	if type(round) ~= "table" then
		gameView:PlayVoteReveal({}, "", "", {}, onComplete, roleName)
		return
	end
	local votes = if type(round.votes) == "table" then round.votes else {}
	local culpritId = if type(round.culpritId) == "string" then round.culpritId else ""
	local monsterId = if type(round.monsterId) == "string" then round.monsterId else ""
	local namesById: { [string]: string } = {}
	if type(snapshot.participants) == "table" then
		for _, participant in snapshot.participants do
			if type(participant) == "table"
				and type(participant.participantId) == "string"
				and type(participant.displayName) == "string"
			then
				namesById[participant.participantId] = participant.displayName
			end
		end
	end
	gameView:PlayVoteReveal(votes, culpritId, monsterId, namesById, onComplete, roleName)
end

local function roundSummaryStats(snapshot: any): RoundSummaryStats
	local round = if type(snapshot) == "table" and type(snapshot.round) == "table"
		then snapshot.round
		else nil
	local participants = if type(snapshot) == "table"
			and type(snapshot.participants) == "table"
		then snapshot.participants
		else {}
	local player = if type(snapshot) == "table" and type(snapshot.player) == "table"
		then snapshot.player
		else nil

	local survivorCount = 0
	local totalParticipants = 0
	for _, participant in participants do
		if type(participant) == "table" then
			totalParticipants += 1
			if participant.alive == true then
				survivorCount += 1
			end
		end
	end

	local personalEvidence = 0
	local evidenceKnowledge = if type(player) == "table"
			and type(player.evidenceKnowledge) == "table"
		then player.evidenceKnowledge
		else {}
	for _, evidence in evidenceKnowledge do
		if type(evidence) == "table" then
			personalEvidence += 1
		end
	end

	local winner = readString(round, "winner", "")
	local monsterId = if type(round) == "table" and type(round.monsterId) == "string"
		then round.monsterId
		else nil
	local victimName = if type(round) == "table" and type(round.victimName) == "string"
		then round.victimName
		else nil
	local roleName = readString(player, "role", "Camper")

	return {
		roundNumber = math.max(0, readNumber(round, "roundNumber", 0)),
		winner = winner,
		isHumanWin = winner == "Campers",
		evidenceFound = math.max(0, readNumber(round, "evidenceFound", 0)),
		evidenceGoal = math.max(1, readNumber(round, "evidenceGoal", 1)),
		objectivesCompleted = math.max(
			0,
			readNumber(round, "objectivesCompleted", 0)
		),
		objectiveGoal = math.max(1, readNumber(round, "objectiveGoal", 1)),
		survivorCount = survivorCount,
		totalParticipants = totalParticipants,
		monsterId = monsterId,
		victimName = victimName,
		personalEvidence = personalEvidence,
		playerRole = roleName,
		-- The public round snapshot does not currently expose either count.
		killCount = 0,
		votesAgainstMe = 0,
		wasCaught = roleName == "Murderer" and winner == "Campers",
	}
end

local function refresh()
	local currentView = view
	if currentView then
		currentView:Update(state, legacyRound, legacyPlayer)
	end
	local currentEffects = effects
	if currentEffects then
		local snapshot: any = state
		local round = if type(snapshot) == "table" and type(snapshot.round) == "table"
			then snapshot.round
			else nil
		local player = if type(snapshot) == "table" and type(snapshot.player) == "table"
			then snapshot.player
			else nil
		local privateMonster = if type(snapshot) == "table"
				and type(snapshot.privateMonster) == "table"
			then snapshot.privateMonster
			else nil
		local phaseName = readString(round, "phase", "")
		local isGhost = type(player) == "table" and player.isGhost == true
		local monsterModeActive = phaseName == "Investigation"
			and type(privateMonster) == "table"
			and privateMonster.active == true
			and not isGhost
		currentEffects:SetMonsterMode(monsterModeActive)
	end
	local currentNametags = nametags
	if currentNametags then
		local snapshot: any = state
		local round = if type(snapshot) == "table" and type(snapshot.round) == "table"
			then snapshot.round
			elseif type(legacyRound) == "table" then legacyRound
			else nil
		local player = if type(snapshot) == "table" and type(snapshot.player) == "table"
			then snapshot.player
			elseif type(legacyPlayer) == "table" then legacyPlayer
			else nil
		local participants = if type(snapshot) == "table"
				and type(snapshot.participants) == "table"
			then snapshot.participants
			else {}
		local phaseName = readString(round, "phase", "")
		local localParticipantId = readString(player, "participantId", "")
		local localRole = readString(player, "role", "")
		local victimId = if type(snapshot) == "table"
				and type(snapshot.murderPlan) == "table"
				and type(snapshot.murderPlan.victimParticipantId) == "string"
				and snapshot.murderPlan.victimParticipantId ~= ""
			then snapshot.murderPlan.victimParticipantId
			else nil
		currentNametags:Update(participants, localParticipantId, phaseName, localRole, victimId)
	end
	local currentPlayerStatus = playerStatus
	if currentPlayerStatus then
		local snapshot: any = state
		local round = if type(snapshot) == "table" and type(snapshot.round) == "table"
			then snapshot.round
			elseif type(legacyRound) == "table" then legacyRound
			else nil
		local player = if type(snapshot) == "table" and type(snapshot.player) == "table"
			then snapshot.player
			elseif type(legacyPlayer) == "table" then legacyPlayer
			else nil
		local participants = if type(snapshot) == "table"
				and type(snapshot.participants) == "table"
			then snapshot.participants
			else {}
		local phaseName = readString(round, "phase", "Lobby")
		currentPlayerStatus:Update(participants, player, phaseName)
	end
end

-- Applies a fresh ghost snapshot to the haunt meter UI and toasts the two
-- transitions worth celebrating: an objective completing and the meter filling.
local function applyGhostSnapshot(ghost: any)
	local currentView = view
	if currentView then
		currentView:UpdateGhostHaunt(ghost)
	end
	if type(ghost) ~= "table" then
		lastGhostSnapshot = nil
		return
	end
	local previous = lastGhostSnapshot
	lastGhostSnapshot = ghost
	if type(previous) ~= "table" or not currentView then
		return
	end
	local previousCount = if type(previous.objectivesCompleted) == "number"
		then previous.objectivesCompleted
		else 0
	local currentCount = if type(ghost.objectivesCompleted) == "number"
		then ghost.objectivesCompleted
		else 0
	if currentCount > previousCount then
		currentView:Notify(
			"Haunt energy rises",
			"Your ghost deed left a chill in the air.",
			"Info"
		)
	end
	if ghost.hauntReady == true and previous.hauntReady ~= true then
		currentView:Notify(
			"HAUNT READY",
			"Press H (X on controller) to haunt the spot you are hovering.",
			"Success"
		)
	end
end

-- Gamepad sensitivity writes are rejected in Studio playtests and warn loudly,
-- so stop retrying after the first failure and skip redundant re-applies.
local gamepadSensitivityBlocked = false
local lastAppliedGamepadSensitivity: number? = nil

local function updateReleaseExperience(
	snapshot: GameState,
	isReconnectSnapshot: boolean?
)
	local currentAccessibility = accessibility
	local currentAudio = audio
	local currentCamera = camera
	local currentCinematics = cinematics
	local currentEffects = effects
	local currentTutorial = tutorial
	local currentView = view
	if not currentAccessibility
		or not currentAudio
		or not currentCamera
		or not currentCinematics
		or not currentEffects
		or not currentTutorial
	then
		return
	end
	currentAccessibility:ApplyGameState(snapshot)
	local reducedMotion = currentAccessibility:IsReducedMotion()
	currentEffects:SetReducedMotion(reducedMotion)
	currentTutorial:SetReducedMotion(reducedMotion)
	local profile = if type(snapshot) == "table" then snapshot.profile else nil
	local profileData = if type(profile) == "table" and type(profile.profile) == "table"
		then profile.profile
		else nil
	local settings = if type(profileData) == "table" and type(profileData.settings) == "table"
		then profileData.settings
		else nil
	if settings and settings.tutorialCompleted == true then
		currentTutorial:SetCompleted(true)
	end
	if settings and type(settings.mouseSensitivity) == "number" then
		UserInputService.MouseDeltaSensitivity = math.clamp(settings.mouseSensitivity, 0.1, 3)
	end
	if settings and type(settings.controllerSensitivity) == "number" and not gamepadSensitivityBlocked then
		local target = math.clamp(settings.controllerSensitivity, 0.1, 3)
		if target ~= lastAppliedGamepadSensitivity then
			local ok = pcall(function()
				local userGameSettings = UserSettings():GetService("UserGameSettings")
				local writableGameSettings = userGameSettings :: any
				writableGameSettings.GamepadCameraSensitivity = target
			end)
			if ok then
				lastAppliedGamepadSensitivity = target
			else
				gamepadSensitivityBlocked = true
			end
		end
	end
	currentTutorial:Update(snapshot)
	local reconnect = isReconnectSnapshot == true
	local round = if type(snapshot) == "table" then snapshot.round else nil
	local phaseName = if type(round) == "table" and type(round.phase) == "string"
		then round.phase
		else nil
	local player = if type(snapshot) == "table" then snapshot.player else nil
	local roleName = if type(player) == "table" and type(player.role) == "string"
		then player.role
		else "Spectator"
	local isGhost = type(player) == "table" and player.isGhost == true
	local evidenceFound = evidenceFoundCount(snapshot)
	local culpritEvidence = evidenceList(snapshot, "culpritEvidence")
	local monsterEvidence = evidenceList(snapshot, "monsterEvidence")
	local latestEvidence: any = nil
	if #culpritEvidence > lastCulpritEvidenceCount then
		latestEvidence = culpritEvidence[#culpritEvidence]
	elseif #monsterEvidence > lastMonsterEvidenceCount then
		latestEvidence = monsterEvidence[#monsterEvidence]
	end
	currentAudio:Update(snapshot)
	if evidenceFound > lastEvidenceFound and currentView then
		if roleName == "Murderer" then
			currentView:Notify(
				"Evidence Found",
				"A clue has been posted against you. Stay composed.",
				"Warning"
			)
		elseif isGhost or roleName == "Spectator" then
			currentView:Notify(
				"Evidence Posted",
				"A clue has been added to the board.",
				"Info"
			)
		else
			local evidenceName, evidenceDescription = evidenceCopy(latestEvidence)
			currentEffects:FlashEvidenceFound()
			currentView:PlayEvidenceDiscovery(evidenceName, evidenceDescription)
		end
	end
	lastEvidenceFound = evidenceFound
	lastCulpritEvidenceCount = #culpritEvidence
	lastMonsterEvidenceCount = #monsterEvidence
	local mystery = if type(snapshot) == "table" then snapshot.mystery else nil
	local revealedWitnessCount = readNumber(mystery, "revealedWitnessCount", 0)
	local totalWitnessCount = math.max(1, readNumber(mystery, "totalWitnessCount", 1))
	if revealedWitnessCount > lastRevealedWitnessCount
		and not isGhost
		and roleName ~= "Spectator"
		and not reconnect
		and (
			phaseName == "Day"
			or phaseName == "Investigation"
			or phaseName == "Campfire"
		)
		and currentView
	then
		if roleName == "Murderer" then
			currentView:Notify(
				"Witness interviewed",
				string.format(
					"A witness has been questioned — %d of %d counselors spoken to.",
					revealedWitnessCount,
					totalWitnessCount
				),
				"Warning"
			)
		else
			currentView:Notify(
				"Witness interviewed",
				string.format(
					"%d of %d witnesses spoken to.",
					revealedWitnessCount,
					totalWitnessCount
				),
				"Success"
			)
		end
	end
	lastRevealedWitnessCount = revealedWitnessCount
	local objectivesCompleted = readNumber(round, "objectivesCompleted", 0)
	local objectiveGoal = math.max(1, readNumber(round, "objectiveGoal", 1))
	if objectivesCompleted > lastObjectivesCompleted
		and not isGhost
		and roleName ~= "Spectator"
		and not reconnect
		and phaseName == "Day"
		and currentView
	then
		if roleName == "Murderer" then
			currentView:Notify(
				"Camp task progress",
				string.format("Campers advancing: %d of %d tasks done.", objectivesCompleted, objectiveGoal),
				"Warning"
			)
		else
			currentView:Notify(
				"Camp task complete",
				string.format("%d of %d tasks done.", objectivesCompleted, objectiveGoal),
				"Success"
			)
		end
	end
	lastObjectivesCompleted = objectivesCompleted
	currentEffects:Update(snapshot)
	updateInvestigationUrgencyWarning(snapshot)
	local roundNumber = if type(round) == "table"
			and type(round.roundNumber) == "number"
		then round.roundNumber
		else nil
	if phaseName == "Campfire" and not reconnect and roundNumber ~= nil and currentView then
		local votesCast = math.floor(readNumber(round, "votesCast", 0))
		local eligibleVoters = math.floor(readNumber(round, "eligibleVoters", 0))
		if eligibleVoters > 0
			and votesCast >= eligibleVoters
			and roundNumber ~= lastVoteCompleteRound
		then
			if roleName == "Murderer" then
				currentView:Notify(
					"All votes are in",
					"The vote is sealed. Your fate is decided.",
					"DangerBright"
				)
			elseif isGhost or roleName == "Spectator" then
				currentView:Notify(
					"All votes are in",
					"The campfire vote is sealed. Watch the verdict.",
					"Info"
				)
			else
				currentView:Notify(
					"All votes are in",
					"The campfire vote is sealed. The verdict is coming.",
					"Warning"
				)
			end
			lastVoteCompleteRound = roundNumber
		end
	end
	if roundNumber ~= nil and roundNumber ~= lastHintRound then
		table.clear(seenHintPhases)
		lastHintRound = roundNumber
	end
	local localParticipantId = readString(player, "participantId", "")
	-- Detect participant connect/disconnect transitions.
	local participants = if type(snapshot) == "table"
			and type(snapshot.participants) == "table"
		then snapshot.participants
		else {}
	local monsterTargetId: string? = nil
	local murderPlan = if type(snapshot) == "table" then snapshot.murderPlan else nil
	if type(murderPlan) == "table"
		and type(murderPlan.victimParticipantId) == "string"
		and murderPlan.victimParticipantId ~= ""
	then
		monsterTargetId = murderPlan.victimParticipantId
	end
	for _, participant in participants do
		if type(participant) ~= "table" then
			continue
		end
		local participantId = readString(participant, "participantId", "")
		if participantId == "" then
			continue
		end
		local displayName = readString(participant, "displayName", "?")
		if participant.isBot ~= true then
			local connected = if type(participant.connected) == "boolean"
				then participant.connected
				else true
			local previousConnected = lastConnectedState[participantId]
			if previousConnected ~= nil then
				if not connected and previousConnected then
					if currentView then
						currentView:Notify(
							displayName .. " left",
							"Player disconnected.",
							"Warning"
						)
					end
				elseif connected and not previousConnected then
					if currentView then
						currentView:Notify(displayName .. " reconnected", "", "Info")
					end
				end
			end
			lastConnectedState[participantId] = connected
		end
		local alive = participant.alive == true
		local previousAlive = lastParticipantAliveStates[participantId]
		if previousAlive == true
			and not alive
			and not reconnect
			and phaseName ~= "Rewards"
			and phaseName ~= "Lobby"
		then
			if monsterTargetId ~= nil and monsterTargetId == participantId and currentView then
				currentView:Notify(
					"TARGET ELIMINATED",
					displayName .. " has been eliminated.",
					"Success"
				)
			elseif participantId ~= localParticipantId and currentView then
				if roleName == "Murderer" then
					currentView:Notify(
						"ELIMINATED",
						displayName .. " has been taken out.",
						"Success"
					)
				else
					currentView:Notify(
						displayName .. " has been eliminated",
						"A player has been taken out.",
						"Warning"
					)
				end
			end
		end
		lastParticipantAliveStates[participantId] = alive
	end
	local winner = if type(round) == "table" and type(round.winner) == "string"
		then round.winner
		else nil
	if phaseName == "Lobby" then
		lastWinnerAnnounced = nil
	end
	if reconnect and winner then
		lastWinnerAnnounced = winner
	end
	local shouldRevealWinner = currentView ~= nil
		and winner ~= nil
		and (phaseName == "Resolution" or phaseName == "Rewards")
		and not reconnect
		and lastWinnerAnnounced ~= winner
	local summaryStats = if shouldRevealWinner and phaseName == "Resolution"
		then roundSummaryStats(snapshot)
		else nil
	local revealWinner = if shouldRevealWinner and currentView and winner
		then function()
			HapticController.Celebrate()
			currentView:PlayWinReveal(winner, winner == "Campers", roleName)
			if summaryStats then
				currentView:PlayRoundSummary(summaryStats)
			end
		end
		else nil
	if shouldRevealWinner then
		lastWinnerAnnounced = winner
	end
	local winnerQueuedAfterVote = false
	if phaseName and phaseName ~= lastCinematicPhase then
		local previousPhase = lastCinematicPhase
		lastCinematicPhase = phaseName
		-- Show the round number once when a new round leaves the lobby.
		if roundNumber ~= nil
			and roundNumber ~= lastToastedRound
			and phaseName ~= "Lobby"
			and phaseName ~= "Rewards"
			and currentView
		then
			lastToastedRound = roundNumber
			local roundToastRole = if type(player) == "table" and type(player.role) == "string"
				then player.role
				else ""
			currentView:Notify(
				string.format("ROUND %d", roundNumber),
				if roundToastRole == "Murderer"
					then "Your identity is hidden. Play the role."
					elseif roundToastRole == "Spectator"
					then "You are observing this round."
					else "The mystery begins. Stay together.",
				"Info"
			)
		end
		currentCinematics:PlayPhaseTransition(phaseName)
		if not reconnect and phaseName ~= "Lobby" and phaseName ~= "Rewards" then
			currentCinematics:PlayPhaseFlash()
		end
		if currentView then
			if previousPhase == "Lobby"
				and phaseName ~= "Lobby"
				and phaseName ~= "Rewards"
				and roleName ~= "Spectator"
				and not reconnect
				and roundNumber ~= nil
				and lastRoleRevealRound ~= roundNumber
			then
				lastRoleRevealRound = roundNumber
				local roleDisplayName = if type(player.roleDisplayName) == "string"
					then player.roleDisplayName
					else roleName
				local roleDescription = if type(player.roleDescription) == "string"
					then player.roleDescription
					else "Your role has been assigned for this mystery."
				-- PrivateParticipantSnapshot has no faction field, so the
				-- architect-approved role fallback is the authoritative check.
				currentView:PlayRoleReveal(
					roleName,
					roleDisplayName,
					roleDescription,
					roleName == "Murderer"
				)
			end
			currentView:PlayPhaseTitleCard(phaseName, reconnect, roleName, isGhost or roleName == "Spectator")
			if phaseName == "Campfire" and not reconnect then
				local aliveCount = 0
				for _, participant in participants do
					if type(participant) == "table" and participant.alive == true then
						aliveCount += 1
					end
				end
				if not isGhost and roleName ~= "Spectator" then
					if roleName == "Murderer" then
						local survivorText = if aliveCount == 1
							then "One player remains."
							else string.format("%d players remain.", aliveCount)
						currentView:Notify(
							"CAMPFIRE VOTE",
							survivorText .. " Stay calm. Deflect suspicion.",
							"DangerBright"
						)
					else
						local voteMessage = if aliveCount == 1
							then "One player remains. Cast your vote."
							else string.format("%d players remain. Cast your vote.", aliveCount)
						currentView:Notify("CAMPFIRE VOTE", voteMessage, "Warning")
					end
				end
			end
			if phaseName == "MurderPlanning" and not reconnect and roleName == "Murderer" then
				local murdPlan = if type(snapshot) == "table" then snapshot.murderPlan else nil
				local victimId = if type(murdPlan) == "table"
						and type(murdPlan.victimParticipantId) == "string"
						and murdPlan.victimParticipantId ~= ""
					then murdPlan.victimParticipantId
					else nil
				local victimName = "your target"
				if victimId ~= nil then
					for _, p in participants do
						if type(p) == "table" and p.participantId == victimId then
							victimName = readString(p, "displayName", "your target")
							break
						end
					end
				end
				currentView:Notify(
					"Night is falling",
					string.format("You must eliminate %s. Use the shadows.", victimName),
					"Warning"
				)
			end
			if phaseName == "Investigation" and not reconnect then
				local playerIsGhost = type(player) == "table" and player.isGhost == true
				if not playerIsGhost then
					-- The real "Body discovered" announcement comes from the
					-- server once someone physically reports a corpse.
					if roleName == "Murderer" then
						currentView:Notify(
							"The night is yours",
							"Hunt carefully. Blend in when they gather.",
							"Warning"
						)
					elseif roleName ~= "Spectator" then
						currentView:Notify(
							"Night investigation begins",
							"Not everyone may have made it. Search the town and watch each other.",
							"DangerBright"
						)
					end
				else
					currentView:Notify(
						"Investigation begins",
						"You are a ghost. Watch as the survivors search for the truth.",
						"Info"
					)
				end
			end
			if phaseName == "NightTransform" and not reconnect then
				local playerIsGhost = type(player) == "table" and player.isGhost == true
				local dayOutcomes = if type(round) == "table" then round.dayOutcomes else nil
				local generatorOn = type(dayOutcomes) == "table" and dayOutcomes.generator == true
				local firewoodOn = type(dayOutcomes) == "table" and dayOutcomes.firewood == true
				local suppliesOn = type(dayOutcomes) == "table" and dayOutcomes.supplies == true
				local payoffLine = table.concat({
					if generatorOn then "Lights ON" else "Lights OUT",
					if firewoodOn then "Fire haven" else "Fire cold",
					if suppliesOn then "Flares ready" else "No flares",
				}, " · ")
				if not playerIsGhost then
					if roleName == "Murderer" then
						currentView:Notify(
							"Your moment is now",
							string.format("Strike true. Day payoff: %s.", payoffLine),
							"DangerBright"
						)
					elseif roleName ~= "Spectator" then
						currentView:Notify(
							"Night falls — day work pays off",
							string.format("%s. Stay alert — someone won't make it to morning.", payoffLine),
							"Warning"
						)
					end
				else
					currentView:Notify(
						"Night falls — day work pays off",
						string.format("%s. Watch from beyond. The hunt begins.", payoffLine),
						"Info"
					)
				end
			end
			-- Keybind hint on first entry to key phases (not on reconnect).
			local hintIsGhost = type(player) == "table" and player.isGhost == true
			local hintRole = roleName
			local showHint = HINT_PHASES[phaseName]
				and not seenHintPhases[phaseName]
				and not reconnect
				and currentView
				and not hintIsGhost
				and hintRole ~= "Spectator"
			local showMurdererHint = MURDERER_HINT_PHASES[phaseName]
				and not seenHintPhases[phaseName]
				and not reconnect
				and currentView
				and not hintIsGhost
				and hintRole == "Murderer"
			if showHint or showMurdererHint then
				seenHintPhases[phaseName] = true
				currentView:ShowKeybindHint(phaseName)
			end
		end
		if phaseName == "Resolution" and currentView then
			playVoteReveal(snapshot, currentView, revealWinner, roleName)
			winnerQueuedAfterVote = revealWinner ~= nil
		end
	end
	if revealWinner and not winnerQueuedAfterVote then
		revealWinner()
	end
	local roundEnded = phaseName == "Rewards" or phaseName == "Lobby"
	-- Ghost transition cinematic — fires once on the false → true crossing.
	local ghostJustDied = isGhost == true and lastIsGhost == false and not reconnect
	if ghostJustDied and currentView then
		local deathCause = if phaseName == "Campfire" or phaseName == "Resolution"
			then "voted"
			else "killed"
		currentView:PlayDeathCinematic(deathCause, roleName)
		if roleName == "Murderer" then
			currentView:Notify(
				"You have been unmasked",
				"The camp named you. Watch the resolution unfold.",
				"DangerBright"
			)
		else
			currentView:Notify(
				"You have been eliminated",
				"You are now a ghost. Observe the round and witness the verdict.",
				"Info"
			)
		end
	end
	if isGhost ~= lastIsGhost then
		currentCinematics:SetGhostMode(isGhost)
	end
	lastIsGhost = isGhost
	local currentHealthState = if type(player) == "table"
			and type(player.healthState) == "string"
		then player.healthState
		else nil
	local healthImproved = currentHealthState == "Healthy"
		and lastHealthState ~= nil
		and lastHealthState ~= "Healthy"
		and not reconnect
		and not roundEnded
	if healthImproved then
		currentEffects:ShowHealedEffect()
		if currentView then
			currentView:Notify("You've recovered", "You're no longer injured and can act freely.", "Success")
		end
	end
	if currentHealthState ~= lastHealthState then
		lastHealthState = currentHealthState
	end
	local currentSeverity = if currentHealthState ~= nil
		then HEALTH_SEVERITY[currentHealthState]
		else nil
	local severityDegraded = currentSeverity ~= nil
		and lastHealthSeverity ~= nil
		and currentSeverity > lastHealthSeverity
		and not reconnect
		and not roundEnded
	if severityDegraded then
		local currentCinematics = cinematics
		if currentCinematics then
			currentCinematics:PlayImpactFlash()
			if currentSeverity >= 2 and currentAccessibility then
				currentAccessibility:ShakeCamera(0.5, 0.4)
			end
		end
		if currentView then
			if currentSeverity >= 3 then
				currentView:Notify("You're incapacitated", "You've been seriously wounded. You can barely move.", "Danger")
			elseif currentSeverity >= 2 then
				currentView:Notify("Critical injury", "You're badly hurt. Movement is severely limited.", "DangerBright")
			else
				currentView:Notify("You've been injured", "You're hurt. Find help before it gets worse.", "Warning")
			end
		end
	end
	if currentSeverity ~= lastHealthSeverity then
		lastHealthSeverity = currentSeverity
	end
	if reconnect and currentView and not roundEnded and phaseName ~= nil then
		if isGhost then
			if roleName == "Murderer" then
				currentView:Notify(
					"Reconnected",
					"Your identity was revealed. Watch the round as a ghost.",
					"Warning"
				)
			else
				currentView:Notify(
					"Reconnected",
					"You are a ghost. Observe the round and witness the verdict.",
					"Info"
				)
			end
		elseif currentHealthState == "Incapacitated" then
			currentView:Notify(
				"Reconnected — you're incapacitated",
				string.format("Current phase: %s. You can barely move.", phaseName),
				"Danger"
			)
		elseif currentHealthState == "Critical" then
			currentView:Notify(
				"Reconnected — critical injury",
				string.format("Current phase: %s. Movement is severely limited.", phaseName),
				"DangerBright"
			)
		elseif currentHealthState == "Injured" then
			currentView:Notify(
				"Reconnected — you're injured",
				string.format("Current phase: %s. Find help.", phaseName),
				"Warning"
			)
		else
			if roleName == "Murderer" then
				currentView:Notify(
					"Reconnected",
					string.format("You are the Murderer. Phase: %s. Stay in character.", phaseName),
					"Warning"
				)
			elseif roleName == "Spectator" then
				currentView:Notify(
					"Reconnected",
					string.format("Observing — Phase: %s.", phaseName),
					"Info"
				)
			elseif phaseName == "Day" then
				currentView:Notify(
					"Reconnected",
					"Complete camp work and interview witnesses before nightfall.",
					"Info"
				)
			elseif phaseName == "Investigation" then
				currentView:Notify(
					"Reconnected",
					"Find and post evidence before the campfire vote.",
					"Info"
				)
			elseif phaseName == "Campfire" then
				currentView:Notify(
					"Reconnected",
					"Cast your vote carefully. The verdict decides the round.",
					"Info"
				)
			elseif phaseName == "MurderPlanning" then
				if roleName == "Murderer" then
					currentView:Notify(
						"Reconnected",
						"Night is falling. Check your plan and prepare to strike.",
						"Warning"
					)
				else
					currentView:Notify(
						"Reconnected",
						"Night approaches. Watch for suspicious behaviour.",
						"Info"
					)
				end
			elseif phaseName == "NightTransform" then
				if roleName == "Murderer" then
					currentView:Notify(
						"Reconnected",
						"Your moment is now. Act fast.",
						"DangerBright"
					)
				else
					currentView:Notify(
						"Reconnected",
						"Something dark is happening. Stay alert.",
						"Warning"
					)
				end
			else
				currentView:Notify(
					"Reconnected",
					string.format("Current phase: %s.", phaseName),
					"Info"
				)
			end
		end
	end
	local abilityMonster = if type(snapshot) == "table"
		then (snapshot :: any).privateMonster
		else nil
	if type(abilityMonster) == "table" and readBoolean(abilityMonster, "active", false) then
		local longestRemaining = 0
		local cooldowns = (abilityMonster :: any).cooldownEndsAt
		if type(cooldowns) == "table" then
			local now = Workspace:GetServerTimeNow()
			for _, endsAt in cooldowns do
				if type(endsAt) == "number"
					and endsAt == endsAt
					and math.abs(endsAt) < math.huge
				then
					longestRemaining = math.max(longestRemaining, endsAt - now)
				end
			end
		end
		local abilityCooling = longestRemaining > 0.5
		if lastAbilityWasCooling == true
			and not abilityCooling
			and not reconnect
			and currentView
		then
			currentView:Notify(
				"Ability ready",
				"Your ability is charged. Strike when the moment is right.",
				"Success"
			)
		end
		lastAbilityWasCooling = abilityCooling
	else
		lastAbilityWasCooling = nil
	end
	if type(abilityMonster) == "table" and readBoolean(abilityMonster, "active", false) then
		local stamina = readNumber(abilityMonster, "stamina", 0)
		local maxStamina = readNumber(abilityMonster, "maxStamina", 0)
		local staminaIsLow = maxStamina > 0 and (stamina / maxStamina) < 0.2
		if staminaIsLow and lastStaminaWasLow ~= true and not reconnect and currentView then
			currentView:Notify(
				"Stamina low",
				"Disengage and let it recover before striking again.",
				"Warning"
			)
		end
		lastStaminaWasLow = staminaIsLow
	else
		lastStaminaWasLow = nil
	end
	currentEffects:SetGhostTint(isGhost)
	-- Role-based spectators also serialize as dead non-ghost participants.
	local isEliminated = type(player) == "table"
		and player.role ~= "Spectator"
		and player.alive == false
		and not isGhost
	currentEffects:SetSpectatorMode(isEliminated and not roundEnded)
	if currentView then
		currentView:SetGhostMode(isGhost)
	end
	applyGhostSnapshot(if isGhost then (snapshot :: any).ghost else nil)
	currentCamera:SetGhostMode(isGhost and not roundEnded)
	-- Opt-in mystery: Spectators are free-roaming campers now, so they keep
	-- world prompts (activities, doors, the sign-up desk). Only ghosts lose
	-- interaction; non-participants just have mystery-only prompts hidden.
	InteractionController.SetPromptsEnabled(not isGhost)
	InteractionController.SetMysteryPromptsSuppressed(roleName == "Spectator")
	local dreadFraction = monsterDreadFraction(snapshot)
	currentCinematics:SetMonsterDread(dreadFraction)
	currentAudio:SetActiveMonster(resolveActiveMonsterId(snapshot))
	if roleName == "Murderer" or isGhost or roleName == "Spectator" then
		currentAudio:SetHeartbeatIntensity(0)
	else
		currentAudio:SetHeartbeatIntensity(dreadFraction)
	end
	currentCamera:SetMonsterDread(dreadFraction)
	if currentView then
		currentAccessibility:ScanEvidence(currentView.root)
	end
end

local function requestAction(actionName: string, payload: any): (boolean, string?)
	local currentBridge = bridge
	if not currentBridge then
		return false, "The camp radio is not connected."
	end
	table.insert(pendingActionNames, actionName)
	local sent, reason = currentBridge:Request(actionName, payload)
	if not sent then
		-- The request never left the client, so no result will arrive for it
		table.remove(pendingActionNames)
	end
	return sent, reason
end

local function handleActionResult(payload: any)
	local actionName: string? = table.remove(pendingActionNames, 1)
	local currentView = view
	-- GhostSync is a silent heartbeat: it never toasts, it only feeds the
	-- haunt meter. Rejections (phase just ended, etc.) are dropped quietly.
	if actionName == "GhostSync" then
		if type(payload) == "table" and payload.accepted == true then
			applyGhostSnapshot((payload :: any).data)
		end
		return
	end
	if actionName == "GhostHaunt" and type(payload) == "table" then
		local hauntResult = payload :: ActionResult
		if hauntResult.accepted == true then
			if type(hauntResult.data) == "table" then
				applyGhostSnapshot(hauntResult.data)
			end
			if currentView then
				currentView:HandleActionResult(true)
				currentView:Notify(
					"Haunt unleashed",
					"Something stirs where you pointed.",
					"Success"
				)
			end
		elseif currentView then
			currentView:HandleActionResult(false)
			currentView:Notify(
				"Haunt failed",
				if type(hauntResult.reason) == "string"
					then hauntResult.reason
					else "The haunt would not take.",
				"Warning"
			)
		end
		return
	end
	if type(payload) ~= "table" then
		if currentView then
			currentView:HandleActionResult(false)
			currentView:Notify("Action failed", "The server returned an invalid response.", "Danger")
		end
		return
	end
	local result = payload :: ActionResult
	if type(result.state) == "table" then
		state = result.state
		refresh()
		updateReleaseExperience(result.state, false)
	end
	local accepted = result.accepted == true
	local reason = if type(result.reason) == "string" then result.reason else nil
	if accepted then
		if currentView then
			currentView:HandleActionResult(true)
			if type(result.state) == "table" then
				local pSnap = result.state.player
				if type(pSnap) == "table"
					and (
						pSnap.healthState == "Critical"
						or pSnap.healthState == "Incapacitated"
					)
				then
					HapticController.Danger()
					local currentCinematics = cinematics
					if currentCinematics then
						currentCinematics:PlayImpactFlash()
					end
					local currentAcc = accessibility
					if currentAcc then
						currentAcc:ShakeCamera(1.0, 0.4)
					end
				end
			end
			local dialogueText: string? = nil
			if type(result.data) == "table" then
				local dialogue = result.data.dialogue
				if type(dialogue) == "table" and type(dialogue.text) == "string" then
					dialogueText = dialogue.text
				end
			end
			if dialogueText then
				local counselorId = if type(result.data) == "table"
						and type(result.data.dialogue) == "table"
						and type(result.data.dialogue.counselorId) == "string"
					then result.data.dialogue.counselorId
					else nil
				local topic = if type(result.data) == "table"
						and type(result.data.dialogue) == "table"
						and type(result.data.dialogue.topic) == "string"
					then result.data.dialogue.topic
					else "Observation"
				local counselorDisplayName = "Counselor"
				local currentState = state
				if counselorId
					and type(currentState) == "table"
					and type(currentState.counselors) == "table"
					and type(currentState.counselors.counselors) == "table"
				then
					for _, entry in currentState.counselors.counselors do
						if type(entry) == "table" and entry.counselorId == counselorId then
							counselorDisplayName =
								readString(entry, "displayName", counselorDisplayName)
							break
						end
					end
				end
				currentView:ShowCounselorDialogue(
					counselorDisplayName,
					topic,
					dialogueText
				)
			else
				-- Minigame steps (chops, wires, crate pickup) accept without
				-- finishing the task; the server tags them as taskProgress.
				local isTaskProgress = type(result.data) == "table"
					and result.data.taskProgress == true
				local toastTitle = if actionName == "Vote"
					then "Vote cast"
					elseif actionName == "UseItem" or actionName == "EquipItem"
					then "Item used"
					elseif actionName == "UseRoleAbility" or actionName == "UseMonsterAbility"
					then "Ability activated"
					elseif actionName == "CompleteObjective" and isTaskProgress
					then "Camp task"
					elseif actionName == "CompleteObjective"
					then "Task complete"
					elseif actionName == "DiscoverEvidence"
					then "Evidence discovered"
					elseif actionName == "AddEvidenceNote"
					then "Note added"
					elseif actionName == "VerifyEvidence"
					then "Evidence verified"
					else "Action complete"
				local toastBody = if reason and reason ~= "" then reason else "The server confirmed your action."
				currentView:Notify(toastTitle, toastBody, "Success")
			end
		end
	elseif currentView then
		currentView:HandleActionResult(false)
		currentView:Notify("Action rejected", reason or "That action is not allowed right now.", "Danger")
	end
end

local function maybeSendGhostSync(snapshot: any)
	if type(snapshot) ~= "table" then
		return
	end
	local player = if type(snapshot.player) == "table" then snapshot.player else nil
	if type(player) ~= "table" or player.isGhost ~= true then
		return
	end
	local round = if type(snapshot.round) == "table" then snapshot.round else nil
	if readString(round, "phase", "") ~= "Investigation" then
		return
	end
	if os.clock() - lastGhostSyncClock < GHOST_SYNC_INTERVAL_SECONDS then
		return
	end
	-- Never overlap another in-flight request: the action-result FIFO labels
	-- results by send order, and the sync can always wait a beat.
	if #pendingActionNames > 0 then
		return
	end
	local currentCamera = Workspace.CurrentCamera
	if not currentCamera then
		return
	end
	lastGhostSyncClock = os.clock()
	local position = currentCamera.CFrame.Position
	requestAction("GhostSync", {
		x = position.X,
		y = position.Y,
		z = position.Z,
	})
end

function RoundController.Start()
	if started then
		return
	end
	started = true

	local remoteBridge = RemoteBridgeModule.new()
	bridge = remoteBridge
	local assetController = UIAssetControllerModule.new()
	uiAssets = assetController
	local gameView = GameViewModule.new(requestAction, function(key: string): string?
		return assetController:Resolve(key)
	end)
	view = gameView
	nametags = NametagsView.new()
	gameView:SetAudioSettingCallback(function(key: string, value: any)
		local currentAudio = audio
		if currentAudio then
			currentAudio:ApplySettingImmediate(key, value)
		end
	end)
	local releaseEffects = EffectsViewModule.new(gameView.root)
	effects = releaseEffects
	local releasePlayerStatus = PlayerStatusViewModule.new(gameView.root)
	playerStatus = releasePlayerStatus
	local cinematicsController = CinematicsController.new(
		gameView.root,
		function(intensity: number)
			releaseEffects:SetNightIntensity(intensity)
		end
	)
	cinematics = cinematicsController
	local releaseCamera = CameraControllerModule.new({
		onFlickerRequest = function(position: Vector3)
			requestAction("GhostFlickerLight", {
				x = position.X,
				y = position.Y,
				z = position.Z,
			})
		end,
		onHauntRequest = function(position: Vector3)
			local ghost = lastGhostSnapshot
			if type(ghost) ~= "table" or ghost.hauntReady ~= true then
				local currentView = view
				if currentView then
					currentView:Notify(
						"Haunt not ready",
						"Complete ghost objectives to fill your haunt meter.",
						"Info"
					)
				end
				return
			end
			requestAction("GhostHaunt", {
				x = position.X,
				y = position.Y,
				z = position.Z,
			})
		end,
	})
	camera = releaseCamera
	local accessibilityController = AccessibilityController.new(gameView.root)
	accessibility = accessibilityController
	-- World evidence cues (pulse + high-contrast markers) watch the server's
	-- glow folder; deferred so a slow Runtime replication can't stall boot.
	task.spawn(function()
		local runtime = Workspace:WaitForChild("Runtime", 30)
		local evidenceFolder = if runtime then runtime:WaitForChild("Evidence", 30) else nil
		if evidenceFolder then
			accessibilityController:WatchWorldEvidence(evidenceFolder)
		end
	end)
	local tutorialController = TutorialController.new(gameView.root, {
		onCompleted = function(skipped: boolean)
			requestAction("SetSettings", {
				settings = {
					tutorialCompleted = true,
					tutorialSkipped = skipped == true,
				},
			})
		end,
	})
	tutorial = tutorialController
	gameView:SetTutorialModalNotifier(function(blocked: boolean)
		tutorialController:SetModalBlocked(blocked)
	end)
	gameView:SetTutorialReplayCallback(function()
		tutorialController:SetCompleted(false)
		tutorialController:Reset()
	end)
	local audioController = AudioController.new({
		onSubtitle = function(text: string, duration: number)
			if accessibilityController:AreSubtitlesEnabled() then
				releaseEffects:ShowSubtitle(text, duration)
			end
		end,
	})
	audio = audioController
	Components.SetSoundPlayer(function(eventName: string)
		audioController:PlayUIEvent(eventName)
	end)
	Motion.SetReducedMotionProvider(function(): boolean
		return accessibilityController:IsReducedMotion()
	end)
	tutorialController:Start()
	audioController:Start()

	remoteBridge:OnSnapshot("game", function(payload: any)
		if type(payload) == "table" then
			local firstFullState = not receivedFullState
			receivedFullState = true
			local round = if type(payload.round) == "table" then payload.round else nil
			local player = if type(payload.player) == "table" then payload.player else nil
			local phaseName = if type(round) == "table" and type(round.phase) == "string"
				then round.phase
				else nil
			local isReconnectSnapshot = firstFullState
				and phaseName ~= nil
				and phaseName ~= "Lobby"
				and phaseName ~= "Rewards"
				and type(player) == "table"
			if isReconnectSnapshot then
				lastCinematicPhase = phaseName
				if type(round) == "table" and type(round.roundNumber) == "number" then
					lastRoleRevealRound = round.roundNumber
				end
				lastEvidenceFound = evidenceFoundCount(payload)
				lastCulpritEvidenceCount = #evidenceList(payload, "culpritEvidence")
				lastMonsterEvidenceCount = #evidenceList(payload, "monsterEvidence")
				local reconnectMystery = if type(payload) == "table" then payload.mystery else nil
				lastRevealedWitnessCount =
					readNumber(reconnectMystery, "revealedWitnessCount", 0)
				local reconnectRound = if type(payload) == "table" then payload.round else nil
				local reconnectVotesCast =
					math.floor(readNumber(reconnectRound, "votesCast", 0))
				local reconnectEligible =
					math.floor(readNumber(reconnectRound, "eligibleVoters", 0))
				if reconnectEligible > 0
					and reconnectVotesCast >= reconnectEligible
					and type(round) == "table"
					and type(round.roundNumber) == "number"
				then
					lastVoteCompleteRound = round.roundNumber
				end
				lastObjectivesCompleted =
					readNumber(reconnectRound, "objectivesCompleted", 0)
				local reconnectMonster = if type(payload) == "table"
					then (payload :: any).privateMonster
					else nil
				if type(reconnectMonster) == "table"
					and readBoolean(reconnectMonster, "active", false)
				then
					local reconnectCooldowns = (reconnectMonster :: any).cooldownEndsAt
					local reconnectLongest = 0
					if type(reconnectCooldowns) == "table" then
						local now = Workspace:GetServerTimeNow()
						for _, endsAt in reconnectCooldowns do
							if type(endsAt) == "number"
								and endsAt == endsAt
								and math.abs(endsAt) < math.huge
							then
								reconnectLongest =
									math.max(reconnectLongest, endsAt - now)
							end
						end
					end
					lastAbilityWasCooling = reconnectLongest > 0.5
				else
					lastAbilityWasCooling = nil
				end
				if type(reconnectMonster) == "table"
					and readBoolean(reconnectMonster, "active", false)
				then
					local reconnectStamina = readNumber(reconnectMonster, "stamina", 0)
					local reconnectMaxStamina = readNumber(reconnectMonster, "maxStamina", 0)
					lastStaminaWasLow = reconnectMaxStamina > 0
						and (reconnectStamina / reconnectMaxStamina) < 0.2
				else
					lastStaminaWasLow = nil
				end
				local reconnectPhase = if type(round) == "table"
						and type(round.phase) == "string"
					then round.phase
					else "Lobby"
				gameView:PrepareReconnectSnapshot(reconnectPhase)
			end
			state = payload :: GameState
			refresh()
			updateReleaseExperience(state :: GameState, isReconnectSnapshot)
		end
	end)
	remoteBridge:OnSnapshot("round", function(payload: any)
		if state == nil then
			legacyRound = payload
			refresh()
		end
	end)
	remoteBridge:OnSnapshot("player", function(payload: any)
		if state == nil then
			legacyPlayer = payload
			refresh()
		end
	end)
	remoteBridge:OnSnapshot("announcement", function(payload: any)
		if type(payload) == "table" then
			local currentState: any = state
			local currentPlayer = if type(currentState) == "table"
					and type(currentState.player) == "table"
				then currentState.player
				elseif type(legacyPlayer) == "table" then legacyPlayer
				else nil
			local announcementPayload = payload
			if readString(currentPlayer, "role", "") == "Murderer" then
				local replacement = MURDERER_ANNOUNCEMENT_COPY[
					readString(payload, "title", "")
				]
				if replacement then
					announcementPayload = table.clone(payload)
					announcementPayload.title = replacement.title
					announcementPayload.message = replacement.message
				end
			end
			gameView:Announce(announcementPayload :: Announcement)
		end
	end)
	remoteBridge:OnActionResult(handleActionResult)

	InputController.Start({
		toggleNotebook = function()
			gameView:ToggleNotebook()
		end,
		toggleSettings = function()
			gameView:ToggleSettings()
		end,
		togglePlayerStatus = function()
			local current = playerStatus
			if current then
				current:Toggle()
			end
		end,
		activateSlot = function(slot: number)
			gameView:ActivateInventorySlot(slot)
		end,
		selectSlot = function(slot: number)
			gameView:SelectInventorySlot(slot)
		end,
		getSlotCount = function()
			return gameView:GetInventorySlotCount()
		end,
		closeModal = function()
			gameView:CloseModal()
			local current = playerStatus
			if current and current.visible == true then
				current:Toggle()
			end
		end,
	})

	local proximityController = ProximityControllerModule.new()
	proximity = proximityController
	interactionConnections = InteractionController.Start({
		shown = function(actionText: string, objectText: string, inputText: string)
			gameView:ShowInteraction(actionText, objectText, inputText)
		end,
		hidden = function()
			gameView:HideInteraction()
		end,
		triggered = function(actionText: string)
			if actionText == "enrollment-desk" then
				gameView:ShowEnrollmentSheet()
				return
			end
			if actionText:sub(1, 10) == "counselor:" then
				local counselorId = actionText:sub(11)
				local roster = state and state.counselors
				local counselors = roster and roster.counselors
				if counselors then
					for _, entry in counselors do
						if entry.counselorId == counselorId then
							if entry.interactionAllowed == true then
								local name = readString(entry, "displayName", "Counselor")
								gameView:ShowInterviewTopicPicker(
									counselorId,
									name,
									entry.isWitness == true
								)
							else
								local behavior = tostring(entry.behavior or "")
								local msg = if behavior == "Fleeing"
									then "They're running away!"
									else if behavior == "Hiding"
										then "They're hiding and won't talk."
										else "They're not available right now."
								gameView:Notify("Can't interview", msg, "Warning")
							end
							return
						end
					end
				end
				gameView:Notify("Can't interview", "They're not available right now.", "Warning")
			else
				gameView:Notify("Interaction complete", actionText, "Success")
			end
		end,
	}, proximityController)

	remoteBridge:Start()
	refresh()
	task.spawn(function()
		while started and gameView.root.Parent do
			gameView:Tick()
			local currentState = state
			if currentState then
				updateInvestigationUrgencyWarning(currentState)
				maybeSendGhostSync(currentState)
			end
			task.wait(0.2)
		end
	end)
end

function RoundController.Stop()
	if not started then
		return
	end
	started = false
	if nametags then
		nametags:Destroy()
		nametags = nil
	end
	if playerStatus then
		playerStatus:Destroy()
		playerStatus = nil
	end
	InputController.Stop()
	for _, connection in interactionConnections do
		connection:Disconnect()
	end
	table.clear(interactionConnections)
	if proximity then
		proximity:Destroy()
	end
	InteractionController.SetPromptsEnabled(true)
	Components.SetSoundPlayer(nil)
	Motion.SetReducedMotionProvider(nil)
	if bridge then
		bridge:Destroy()
	end
	if tutorial then
		tutorial:Destroy()
	end
	if audio then
		audio:Destroy()
	end
	if camera then
		camera:Destroy()
	end
	if cinematics then
		cinematics:Destroy()
	end
	if accessibility then
		accessibility:Destroy()
	end
	if effects then
		effects:Destroy()
	end
	if view then
		view:Destroy()
	end
	if uiAssets then
		uiAssets:Destroy()
	end
	bridge = nil
	tutorial = nil
	audio = nil
	camera = nil
	cinematics = nil
	accessibility = nil
	effects = nil
	uiAssets = nil
	proximity = nil
	view = nil
	state = nil
	legacyRound = nil
	legacyPlayer = nil
	lastCinematicPhase = nil
	lastEvidenceFound = 0
	lastCulpritEvidenceCount = 0
	lastMonsterEvidenceCount = 0
	lastRevealedWitnessCount = 0
	lastObjectivesCompleted = 0
	lastAbilityWasCooling = nil
	lastStaminaWasLow = nil
	receivedFullState = false
	lastRoleRevealRound = nil
	lastWinnerAnnounced = nil
	lastVoteCompleteRound = nil
	lastIsGhost = nil
	lastHealthState = nil
	lastHealthSeverity = nil
	lastConnectedState = {}
	lastParticipantAliveStates = {}
	lastHintRound = nil
	lastToastedRound = nil
	sentUrgencyWarning = false
	lastGhostSyncClock = 0
	lastGhostSnapshot = nil
	table.clear(pendingActionNames)
	table.clear(seenHintPhases)
end

return table.freeze(RoundController)
