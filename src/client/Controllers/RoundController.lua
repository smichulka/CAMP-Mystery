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
}

local RoundController = {}

local HINT_PHASES: { [string]: boolean } = {
	Day = true,
	Investigation = true,
	Campfire = true,
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
local receivedFullState = false
local lastRoleRevealRound: number? = nil
local lastWinnerAnnounced: string? = nil
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
		sentUrgencyWarning = true
		currentView:Notify(
			"Investigation closing",
			"Under a minute remaining.",
			"Danger"
		)
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
	onComplete: (() -> ())?
)
	local round = if type(snapshot) == "table" then snapshot.round else nil
	if type(round) ~= "table" then
		gameView:PlayVoteReveal({}, "", "", {}, onComplete)
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
	gameView:PlayVoteReveal(votes, culpritId, monsterId, namesById, onComplete)
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
		playerRole = readString(player, "role", "Camper"),
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
		local evidenceName, evidenceDescription = evidenceCopy(latestEvidence)
		currentEffects:FlashEvidenceFound()
		currentView:PlayEvidenceDiscovery(evidenceName, evidenceDescription)
	end
	lastEvidenceFound = evidenceFound
	lastCulpritEvidenceCount = #culpritEvidence
	lastMonsterEvidenceCount = #monsterEvidence
	currentEffects:Update(snapshot)
	local round = if type(snapshot) == "table" then snapshot.round else nil
	local phaseName = if type(round) == "table" and type(round.phase) == "string"
		then round.phase
		else nil
	updateInvestigationUrgencyWarning(snapshot)
	local roundNumber = if type(round) == "table"
			and type(round.roundNumber) == "number"
		then round.roundNumber
		else nil
	if roundNumber ~= nil and roundNumber ~= lastHintRound then
		table.clear(seenHintPhases)
		lastHintRound = roundNumber
	end
	local player = if type(snapshot) == "table" then snapshot.player else nil
	local reconnect = isReconnectSnapshot == true
	-- Detect participant connect/disconnect transitions.
	local participants = if type(snapshot) == "table"
			and type(snapshot.participants) == "table"
		then snapshot.participants
		else {}
	for _, participant in participants do
		if type(participant) ~= "table" or participant.isBot == true then
			continue
		end
		local participantId = readString(participant, "participantId", "")
		if participantId == "" then
			continue
		end
		local displayName = readString(participant, "displayName", "?")
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
			currentView:PlayWinReveal(winner, winner == "Campers")
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
			currentView:Notify(
				string.format("ROUND %d", roundNumber),
				"The mystery begins. Stay together.",
				"Info"
			)
		end
		currentCinematics:PlayPhaseTransition(phaseName)
		if not reconnect and phaseName ~= "Lobby" and phaseName ~= "Rewards" then
			currentCinematics:PlayPhaseFlash()
		end
		if currentView then
			local roleName = if type(player) == "table" and type(player.role) == "string"
				then player.role
				else "Spectator"
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
			currentView:PlayPhaseTitleCard(phaseName, reconnect)
			-- Keybind hint on first entry to key phases (not on reconnect).
			if HINT_PHASES[phaseName]
				and not seenHintPhases[phaseName]
				and not reconnect
				and currentView
			then
				seenHintPhases[phaseName] = true
				currentView:ShowKeybindHint(phaseName)
			end
		end
		if phaseName == "Resolution" and currentView then
			playVoteReveal(snapshot, currentView, revealWinner)
			winnerQueuedAfterVote = revealWinner ~= nil
		end
	end
	if revealWinner and not winnerQueuedAfterVote then
		revealWinner()
	end
	local isGhost = type(player) == "table" and player.isGhost == true
	local roundEnded = phaseName == "Rewards" or phaseName == "Lobby"
	-- Ghost transition cinematic — fires once on the false → true crossing.
	local ghostJustDied = isGhost == true and lastIsGhost == false and not reconnect
	if ghostJustDied and currentView then
		currentView:PlayDeathCinematic()
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
	end
	if currentSeverity ~= lastHealthSeverity then
		lastHealthSeverity = currentSeverity
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
			local roleName = if type(player) == "table"
					and type(player.roleDisplayName) == "string"
				then player.roleDisplayName
				elseif type(player) == "table" and type(player.role) == "string"
					then player.role
				else "Camper"
			local isReconnectSnapshot = firstFullState
				and phaseName ~= nil
				and phaseName ~= "Lobby"
				and phaseName ~= "Rewards"
				and type(player) == "table"
				and player.role ~= "Spectator"
			if isReconnectSnapshot then
				lastCinematicPhase = phaseName
				if type(round) == "table" and type(round.roundNumber) == "number" then
					lastRoleRevealRound = round.roundNumber
				end
				lastEvidenceFound = evidenceFoundCount(payload)
				lastCulpritEvidenceCount = #evidenceList(payload, "culpritEvidence")
				lastMonsterEvidenceCount = #evidenceList(payload, "monsterEvidence")
				local reconnectPhase = if type(round) == "table"
						and type(round.phase) == "string"
					then round.phase
					else "Lobby"
				gameView:PrepareReconnectSnapshot(reconnectPhase)
			end
			state = payload :: GameState
			refresh()
			updateReleaseExperience(state :: GameState, isReconnectSnapshot)
			if isReconnectSnapshot then
				gameView:Notify(
					"Reconnected — your role is " .. roleName,
					"Your round state has been restored.",
					"Info",
					4
				)
			end
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
			gameView:Announce(payload :: Announcement)
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
	receivedFullState = false
	lastRoleRevealRound = nil
	lastWinnerAnnounced = nil
	lastIsGhost = nil
	lastHealthState = nil
	lastHealthSeverity = nil
	lastConnectedState = {}
	lastHintRound = nil
	lastToastedRound = nil
	sentUrgencyWarning = false
	table.clear(seenHintPhases)
end

return table.freeze(RoundController)
