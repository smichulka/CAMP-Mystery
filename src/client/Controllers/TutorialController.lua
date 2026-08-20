--!strict

local uiFolder = script.Parent.Parent:WaitForChild("UI")
local TutorialViewModule = require(uiFolder:WaitForChild("TutorialView"))

type TutorialView = TutorialViewModule.TutorialView
type TutorialStep = TutorialViewModule.TutorialStep
type TutorialChoice = TutorialViewModule.TutorialChoice

export type TutorialOptions = {
	completed: boolean?,
	onCompleted: ((skipped: boolean) -> ())?,
}

type StepDefinition = TutorialStep & {
	context: string,
}

type TutorialControllerState = {
	view: TutorialView,
	steps: { StepDefinition },
	seen: { [string]: boolean },
	activeStep: StepDefinition?,
	lastState: any,
	completed: boolean,
	modalBlocked: boolean,
	destroyed: boolean,
	onCompleted: ((skipped: boolean) -> ())?,
}

local TutorialController = {}
TutorialController.__index = TutorialController

export type TutorialController = typeof(setmetatable({} :: TutorialControllerState, TutorialController))

TutorialController.StepIds = table.freeze({
	Lobby = "lobby",
	Role = "role",
	Day = "day",
	MurderPlanning = "murderplanning",
	MurderPlanningMurderer = "murderplanning_murderer",
	NightTransform = "nighttransform",
	NightTransformMurderer = "nighttransform_murderer",
	Investigation = "investigation",
	InvestigationMurderer = "investigation_murderer",
	Evidence = "evidence",
	Deduction = "deduction",
	Ghost = "ghost",
	Vote = "vote",
	VoteMurderer = "vote_murderer",
	Rewards = "rewards",
	Spectator = "spectator",
})

local DEDUCTION_CHOICES: { TutorialChoice } = {
	{
		label = "This looks planted",
		feedback = "Planted clues push one name hard. Cross-check before you trust them.",
	},
	{
		label = "This looks real",
		feedback = "Real culprit clues converge on one answer across multiple finds.",
	},
}

local STEP_COPY: {
	{
		id: string,
		context: string,
		title: string,
		body: string,
		objective: string,
		choices: { TutorialChoice }?,
	}
} = {
	{
		id = "lobby",
		context = "Lobby",
		title = "Welcome to Camp",
		body = "Ready up while the camp fills. Human campers and computer campers follow the same round rules.",
		objective = "READY UP AND WATCH THE LOBBY STATUS",
	},
	{
		id = "role",
		context = "Role",
		title = "Your Secret Role",
		body = "Only you can see this briefing. Your role card explains your goal and whether you have a special ability.",
		objective = "READ YOUR ROLE BEFORE THE ROUND BEGINS",
	},
	{
		id = "day",
		context = "Day",
		title = "Prepare Before Sunset",
		body = "Camp tasks decide the night: the generator keeps the lights on, firewood keeps the campfire safe, and supplies earn bonus gear. Finish what you can.",
		objective = "COMPLETE CAMP OBJECTIVES AND CHOOSE YOUR GEAR",
	},
	{
		id = "murderplanning",
		context = "MurderPlanning",
		title = "Dusk at Camp",
		body = "Someone is choosing a victim right now. Check in with a buddy, hand spare gear to whoever heads out alone, and ask counselors what they saw.",
		objective = "BUDDY CHECK-IN AND GEAR UP BEFORE NIGHTFALL",
	},
	{
		id = "murderplanning_murderer",
		context = "MurderPlanningMurderer",
		title = "YOU ARE CHOOSING",
		body = "Select your target and monster form before the night falls. Your choice is final.",
		objective = "CHOOSE YOUR TARGET AND MONSTER FORM",
	},
	{
		id = "nighttransform",
		context = "NightTransform",
		title = "The Town Appears",
		body = "The camp has merged with an abandoned town. The monster is somewhere out there. Stay near teammates and watch your surroundings.",
		objective = "MOVE CAREFULLY — ISOLATION IS DANGEROUS",
	},
	{
		id = "nighttransform_murderer",
		context = "NightTransformMurderer",
		title = "YOU ARE THE MONSTER",
		body = "Your form has changed. Hunt your target and avoid detection. Use your ability wisely.",
		objective = "HUNT YOUR TARGET WITHOUT BEING EXPOSED",
	},
	{
		id = "investigation",
		context = "Investigation",
		title = "Investigate the Town",
		body = "Search rooms for evidence and interview counselors — and if you find a body, report it so the camp knows. Stay in range of teammates; isolation is how the monster wins.",
		objective = "FIND CLUES AND REPORT WHAT YOU DISCOVER",
	},
	{
		id = "investigation_murderer",
		context = "InvestigationMurderer",
		title = "STAY HIDDEN",
		body = "The camp is searching for evidence. Blend in. Steer suspicion. Isolation is your tool — and their downfall.",
		objective = "BLEND IN AND REDIRECT SUSPICION",
	},
	{
		id = "evidence",
		context = "Evidence",
		title = "Real Clues vs Planted",
		body = "Your notebook has two channels: culprit clues and monster clues. Planted clues try to frame someone — they feel loud and one-sided. Real culprit clues converge on the same answer. Compare finds with your group before you accuse.",
		objective = "OPEN THE NOTEBOOK AND COMPARE POSTED EVIDENCE",
	},
	{
		id = "deduction",
		context = "Deduction",
		title = "Real Clues vs Planted",
		body = "Before you accuse, drill the board: planted clues frame a person; authentic clues converge across finds. Pick how this sample clue feels — then compare three real clues in your notebook.",
		objective = "COMPARE THREE CLUES BEFORE YOU ACCUSE",
		choices = DEDUCTION_CHOICES,
	},
	{
		id = "ghost",
		context = "Ghost",
		title = "You Are a Ghost",
		body = "Death is not the end of your usefulness. Watch the hunt, call out danger, and — if you are a Protector — you can still intervene from beyond. Report what you see through spirit channels when the camp needs it.",
		objective = "STAY USEFUL AFTER DEATH",
	},
	{
		id = "vote",
		context = "Vote",
		title = "Talk First, Then Vote",
		body = "The campfire opens with a discussion: present your strongest evidence and make your case. When voting opens, accuse one suspect — no take-backs.",
		objective = "PRESENT EVIDENCE, THEN LOCK IN YOUR ACCUSATION",
	},
	{
		id = "vote_murderer",
		context = "VoteMurderer",
		title = "THE VOTE",
		body = "You are being considered. Redirect suspicion. A tie breaks in your favor.",
		objective = "REDIRECT THE VOTE AWAY FROM YOURSELF",
	},
	{
		id = "rewards",
		context = "Rewards",
		title = "Round Complete",
		body = "Round rewards advance role mastery and unlock progression. The next mystery resets the world and secret roles.",
		objective = "REVIEW YOUR REWARDS, THEN PREPARE FOR THE NEXT ROUND",
	},
	{
		id = "spectator",
		context = "Spectator",
		title = "You Joined Late",
		body = "This round is already underway. You can observe the current game and will join the roster at the start of the next round.",
		objective = "WATCH THE ROUND — YOU PLAY NEXT",
	},
}

local function buildSteps(): { StepDefinition }
	local result: { StepDefinition } = {}
	local total = #STEP_COPY
	for index, definition in STEP_COPY do
		table.insert(result, {
			id = definition.id,
			context = definition.context,
			title = definition.title,
			body = definition.body,
			objective = definition.objective,
			choices = definition.choices,
			position = index,
			total = total,
		})
	end
	return result
end

local function readString(value: any, key: string, fallback: string): string
	if type(value) == "table" and type(value[key]) == "string" then
		return value[key]
	end
	return fallback
end

local function readNumber(value: any, key: string, fallback: number): number
	if type(value) == "table" and type(value[key]) == "number" then
		return value[key]
	end
	return fallback
end

local function readBoolean(value: any, key: string, fallback: boolean): boolean
	if type(value) == "table" and type(value[key]) == "boolean" then
		return value[key]
	end
	return fallback
end

local function playerIsGhost(player: any): boolean
	if type(player) ~= "table" then
		return false
	end
	if readBoolean(player, "isGhost", false) then
		return true
	end
	-- Dead-as-ghost: some snapshots surface healthState before isGhost flips.
	return readString(player, "healthState", "") == "Ghost"
end

local function currentContext(state: any, seen: { [string]: boolean }): string?
	if type(state) ~= "table" then
		return nil
	end
	local round = state.round
	if type(round) ~= "table" then
		return nil
	end

	local phase = readString(round, "phase", "Lobby")
	if phase == "Lobby" then
		return "Lobby"
	end
	local player = state.player
	local role = readString(player, "role", "")
	if role == "Spectator" then
		return "Spectator"
	end
	if playerIsGhost(player) and not seen[TutorialController.StepIds.Ghost] then
		return "Ghost"
	end
	if role == "Murderer" then
		if phase == "MurderPlanning" then
			return "MurderPlanningMurderer"
		end
		if phase == "NightTransform" then
			return "NightTransformMurderer"
		end
		if phase == "Investigation" then
			return "InvestigationMurderer"
		end
		if phase == "Campfire" then
			return "VoteMurderer"
		end
	end
	if phase == "RoleReveal" then
		return "Role"
	end
	if phase == "Day" then
		return "Day"
	end
	if phase == "MurderPlanning" then
		return "MurderPlanning"
	end
	if phase == "NightTransform" then
		return "NightTransform"
	end
	local evidenceFound = readNumber(round, "evidenceFound", 0)
	if phase == "Investigation" then
		if evidenceFound > 0 then
			if not seen[TutorialController.StepIds.Evidence] then
				return "Evidence"
			end
			if not seen[TutorialController.StepIds.Deduction] then
				return "Deduction"
			end
			return "Evidence"
		end
		return "Investigation"
	end
	if phase == "Campfire" then
		if evidenceFound > 0 and not seen[TutorialController.StepIds.Deduction] then
			return "Deduction"
		end
		return "Vote"
	end
	if phase == "Resolution" or phase == "Rewards" then
		return "Rewards"
	end
	return nil
end

function TutorialController.new(parent: Instance, options: TutorialOptions?): TutorialController
	local resolved = options or {}
	local view = TutorialViewModule.new(parent)
	local self: TutorialController = setmetatable({
		view = view,
		steps = buildSteps(),
		seen = {},
		activeStep = nil,
		lastState = nil,
		completed = resolved.completed == true,
		modalBlocked = false,
		destroyed = false,
		onCompleted = resolved.onCompleted,
	}, TutorialController)
	return self
end

function TutorialController:Start(initialState: any?)
	if initialState ~= nil then
		self:Update(initialState)
	end
end

function TutorialController:_findForContext(context: string): StepDefinition?
	for _, step in self.steps do
		if step.context == context and not self.seen[step.id] then
			return step
		end
	end
	return nil
end

-- Mirrors currentContext: which cards this role can ever be shown.
local function stepApplies(stepId: string, role: string, isGhost: boolean): boolean
	if stepId == TutorialController.StepIds.Spectator then
		return role == "Spectator"
	end
	-- Spectators only pass through Lobby before getting the Spectator context;
	-- all other step contexts are never returned for them by currentContext.
	if role == "Spectator" then
		return stepId == TutorialController.StepIds.Lobby
	end
	if stepId == TutorialController.StepIds.Ghost then
		return isGhost
	end
	local murdererStep = stepId == TutorialController.StepIds.MurderPlanningMurderer
		or stepId == TutorialController.StepIds.NightTransformMurderer
		or stepId == TutorialController.StepIds.InvestigationMurderer
		or stepId == TutorialController.StepIds.VoteMurderer
	if murdererStep then
		return role == "Murderer"
	end
	local camperEquivalent = stepId == TutorialController.StepIds.MurderPlanning
		or stepId == TutorialController.StepIds.NightTransform
		or stepId == TutorialController.StepIds.Investigation
		or stepId == TutorialController.StepIds.Vote
	if camperEquivalent then
		return role ~= "Murderer"
	end
	-- currentContext returns InvestigationMurderer (not Evidence/Deduction) for
	-- murderers, so murderers will never see those camper deduction cards.
	if stepId == TutorialController.StepIds.Evidence
		or stepId == TutorialController.StepIds.Deduction
	then
		return role ~= "Murderer"
	end
	return true
end

function TutorialController:_allSeen(): boolean
	local lastState = self.lastState
	local player = if type(lastState) == "table" then lastState.player else nil
	local role = readString(player, "role", "")
	local isGhost = playerIsGhost(player)
	for _, step in self.steps do
		if stepApplies(step.id, role, isGhost) and not self.seen[step.id] then
			return false
		end
	end
	return true
end

function TutorialController:_displayNumbering(step: StepDefinition): (number, number)
	local player = if type(self.lastState) == "table" then self.lastState.player else nil
	local role = readString(player, "role", "")
	local isGhost = playerIsGhost(player)
	local position = 0
	local total = 0
	for _, candidate in self.steps do
		if stepApplies(candidate.id, role, isGhost) then
			total += 1
			if candidate.id == step.id then
				position = total
			end
		end
	end
	if position == 0 then
		return step.position, step.total
	end
	return position, total
end

function TutorialController:_finish(skipped: boolean)
	if self.completed then
		return
	end
	self.completed = true
	self.activeStep = nil
	self.view:Hide()
	if self.onCompleted then
		self.onCompleted(skipped)
	end
end

function TutorialController:_show(step: StepDefinition)
	self.activeStep = step
	local position, total = self:_displayNumbering(step)
	local display: StepDefinition = {
		id = step.id,
		context = step.context,
		title = step.title,
		body = step.body,
		objective = step.objective,
		choices = step.choices,
		position = position,
		total = total,
	}
	self.view:Show(display, function()
		self:Advance()
	end, function()
		self:Skip()
	end)
end

function TutorialController:SetModalBlocked(blocked: boolean)
	if self.destroyed or self.modalBlocked == blocked then
		return
	end
	self.modalBlocked = blocked
	if blocked then
		self.view:Hide()
		return
	end
	if self.lastState ~= nil then
		self:Update(self.lastState)
	end
end

function TutorialController:Reset()
	if self.destroyed then
		return
	end
	self.completed = false
	self.activeStep = nil
	table.clear(self.seen)
	self.view:Hide()
	if self.lastState ~= nil then
		self:Update(self.lastState)
	end
end

function TutorialController:Update(state: any)
	if self.destroyed or self.modalBlocked then
		return
	end
	self.lastState = state
	local context = currentContext(state, self.seen)
	if not context then
		return
	end

	-- Ghost briefing can still fire after the rest of the tutorial finished.
	local ghostOverride = context == "Ghost" and not self.seen[TutorialController.StepIds.Ghost]
	if self.completed and not ghostOverride then
		return
	end

	local active = self.activeStep
	if active then
		if active.context == context then
			return
		end
		self.seen[active.id] = true
		self.activeStep = nil
		self.view:Hide()
	end

	local step = self:_findForContext(context)
	if step then
		self:_show(step)
	elseif not self.completed and self:_allSeen() then
		self:_finish(false)
	end
end

function TutorialController:Advance()
	if self.destroyed then
		return
	end
	local active = self.activeStep
	if active then
		self.seen[active.id] = true
	end
	self.activeStep = nil
	self.view:Hide()

	if self.completed then
		return
	end
	if self:_allSeen() then
		self:_finish(false)
		return
	end
	self:Update(self.lastState)
end

function TutorialController:Skip()
	if self.completed or self.destroyed then
		return
	end
	for _, step in self.steps do
		self.seen[step.id] = true
	end
	self:_finish(true)
end

function TutorialController:SetReducedMotion(reducedMotion: boolean)
	self.view:SetReducedMotion(reducedMotion)
end

function TutorialController:SetCompleted(completed: boolean)
	if completed then
		if not self.completed then
			-- Loading an already-completed profile is synchronization, not a new
			-- completion. Do not call onCompleted and write the setting back.
			self.completed = true
			self.activeStep = nil
			self.view:Hide()
		end
		return
	end
	self.completed = false
	self.activeStep = nil
	table.clear(self.seen)
	self.view:Hide()
end

function TutorialController:IsCompleted(): boolean
	return self.completed
end

function TutorialController:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.activeStep = nil
	self.lastState = nil
	self.view:Destroy()
end

return TutorialController
