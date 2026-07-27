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
	["Something Is Being Planned"] = {
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
local lastHealthState: string? = nil
local HEALTH_SEVERITY: { [string]: number } = {
	Healthy = 0,
	Injured = 1,
	Incapacitated = 2,
	Critical = 2,
}
local lastHealthSeverity: number? = nil
local lastConnectedState: { [string]: boolean } = {}
local lastParticipantAliveStates: { [string]: boolean } = {}
local lastHintRound: number? = nil
local lastToastedRound: number? = nil
local sentUrgencyWarning = false
local seenHintPhases: { [string]: boolean } = {}

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
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("Model")
			and descendant:GetAttribute("ParticipantId") == participantId
			and type(descendant:GetAttribute("MonsterId")) == "string"
		then
			local root = descendant.PrimaryPart
				or descendant:FindFirstChild("HumanoidRootPart", true)
			if root and root:IsA("BasePart") then
				return root.Position
			end
			return descendant:GetPivot().Position
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
		currentNametags:Update(participants, localParticipantId, phaseName)
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
	if settings and type(settings.controllerSensitivity) == "number" then
		pcall(function()
			local userGameSettings = UserSettings():GetService("UserGameSettings")
			local writableGameSettings = userGameSettings :: any
			writableGameSettings.GamepadCameraSensitivity =
				math.clamp(settings.controllerSensitivity, 0.1, 3)
		end)
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
		and not reconnect
		and phaseName == "Day"
		and currentView
	then
		currentView:Notify(
			"Witness interviewed",
			string.format(
				"%d of %d witnesses spoken to.",
				revealedWitnessCount,
				totalWitnessCount
			),
			"Info"
		)
	end
	lastRevealedWitnessCount = revealedWitnessCount
	local objectivesCompleted = readNumber(round, "objectivesCompleted", 0)
	local objectiveGoal = math.max(1, readNumber(round, "objectiveGoal", 1))
	if objectivesCompleted > lastObjectivesCompleted
		and not isGhost
		and not reconnect
		and phaseName == "Day"
		and currentView
	then
		currentView:Notify(
			"Camp task complete",
			string.format("%d of %d tasks done.", objectivesCompleted, objectiveGoal),
			"Info"
		)
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
			currentView:Notify(
				"All votes are in",
				"The campfire vote is sealed. The verdict is coming.",
				"Warning"
			)
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
				currentView:Notify(
					displayName .. " has been eliminated",
					"A player has been taken out.",
					"Warning"
				)
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
			currentView:PlayPhaseTitleCard(phaseName, reconnect, roleName)
			if phaseName == "Campfire" and not reconnect then
				local aliveCount = 0
				for _, participant in participants do
					if type(participant) == "table" and participant.alive == true then
						aliveCount += 1
					end
				end
				local voteMessage = if aliveCount == 1
					then "One player remains. Cast your vote."
					else string.format("%d players remain. Cast your vote.", aliveCount)
				if not isGhost and roleName ~= "Spectator" then
					currentView:Notify("CAMPFIRE VOTE", voteMessage, "Warning")
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
					if roleName == "Murderer" then
						currentView:Notify(
							"Body discovered",
							"Stay calm. Blend in with the others.",
							"Warning"
						)
					elseif roleName ~= "Spectator" then
						currentView:Notify(
							"Body discovered",
							"Someone was killed. Find the evidence before campfire.",
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
				if not playerIsGhost then
					if roleName == "Murderer" then
						currentView:Notify(
							"Your moment is now",
							"Strike true. The camp is yours.",
							"DangerBright"
						)
					elseif roleName ~= "Spectator" then
						currentView:Notify(
							"Night falls",
							"Stay alert. Someone won't make it to morning.",
							"Warning"
						)
					end
				else
					currentView:Notify(
						"Night falls",
						"Watch from beyond. The hunt begins.",
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
				and not (hintRole == "Spectator" and (phaseName == "Campfire" or phaseName == "Investigation"))
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
		currentView:Notify(
			"You have been eliminated",
			"You are now a ghost. Observe the round and witness the verdict.",
			"Info"
		)
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
			if currentSeverity >= 2 then
				currentCinematics:PlayScreenShake(0.5)
			end
		end
		if currentView then
			if currentSeverity >= 2 then
				currentView:Notify("You're incapacitated", "You've been seriously wounded. You can barely move.", "DangerBright")
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
			currentView:Notify(
				"Reconnected",
				"You are a ghost. Observe the round and witness the verdict.",
				"Info"
			)
		elseif currentHealthState == "Critical" or currentHealthState == "Incapacitated" then
			currentView:Notify(
				"Reconnected — you're incapacitated",
				string.format("Current phase: %s. You can barely move.", phaseName),
				"Warning"
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
				currentView:Notify(
					"Reconnected",
					string.format("Phase: %s. Follow the phase instructions.", phaseName),
					"Info"
				)
			elseif phaseName == "NightTransform" then
				currentView:Notify(
					"Reconnected",
					string.format("Phase: %s. Follow the phase instructions.", phaseName),
					"Info"
				)
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
	currentCamera:SetGhostMode(isGhost and not roundEnded)
	InteractionController.SetPromptsEnabled(not isGhost)
	local dreadFraction = monsterDreadFraction(snapshot)
	currentCinematics:SetMonsterDread(dreadFraction)
	currentAudio:SetHeartbeatIntensity(dreadFraction)
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
	return currentBridge:Request(actionName, payload)
end

local function handleActionResult(payload: any)
	local currentView = view
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
				end
			end
			-- Impact flash on injury/critical.
			if type(result.state) == "table" then
				local pSnap = result.state.player
				if type(pSnap) == "table"
					and (
						pSnap.healthState == "Critical"
						or pSnap.healthState == "Incapacitated"
					)
				then
					local currentCinematics = cinematics
					if currentCinematics then
						currentCinematics:PlayImpactFlash()
						currentCinematics:PlayScreenShake(1.0)
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
				currentView:Notify(
					"Action complete",
					reason or "The server confirmed your action.",
					"Success"
				)
			end
		end
	elseif currentView then
		currentView:HandleActionResult(false)
		currentView:Notify("Action rejected", reason or "That action is not allowed right now.", "Danger")
	end
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
	local releaseCamera = CameraControllerModule.new()
	camera = releaseCamera
	local accessibilityController = AccessibilityController.new(gameView.root)
	accessibility = accessibilityController
	local tutorialController = TutorialController.new(gameView.root, {
		onCompleted = function(_skipped: boolean)
			requestAction("SetSettings", {
				settings = { tutorialCompleted = true },
			})
		end,
	})
	tutorial = tutorialController
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
			gameView:Notify("Interaction complete", actionText, "Success")
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
	table.clear(seenHintPhases)
end

return table.freeze(RoundController)
