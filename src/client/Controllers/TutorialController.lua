--!strict

local uiFolder = script.Parent.Parent:WaitForChild("UI")
local TutorialViewModule = require(uiFolder:WaitForChild("TutorialView"))

type TutorialView = TutorialViewModule.TutorialView
type TutorialStep = TutorialViewModule.TutorialStep

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
	NightTransform = "nighttransform",
	Investigation = "investigation",
	Evidence = "evidence",
	Vote = "vote",
	Rewards = "rewards",
	Spectator = "spectator",
})

local STEP_COPY: { { id: string, context: string, title: string, body: string, objective: string } } = {
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
		body = "Explore the camp, complete shared work, and gather equipment. Preparation makes the night survivable.",
		objective = "COMPLETE CAMP OBJECTIVES AND CHOOSE YOUR GEAR",
	},
	{
		id = "murderplanning",
		context = "MurderPlanning",
		title = "The Night Is Being Decided",
		body = "Someone in the group is choosing a victim right now. Use this moment to prepare — equip your gear and decide where to investigate tonight.",
		objective = "EQUIP YOUR GEAR BEFORE NIGHTFALL",
	},
	{
		id = "nighttransform",
		context = "NightTransform",
		title = "The Town Appears",
		body = "The camp has merged with an abandoned town. The monster is somewhere out there. Stay near teammates and watch your surroundings.",
		objective = "MOVE CAREFULLY — ISOLATION IS DANGEROUS",
	},
	{
		id = "investigation",
		context = "Investigation",
		title = "Investigate the Town",
		body = "The abandoned town is dangerous. Search rooms for evidence, interview counselors, use your equipment, and stay in range of teammates. Isolation is how the monster wins.",
		objective = "FIND REAL CLUES WITHOUT GETTING ISOLATED",
	},
	{
		id = "evidence",
		context = "Evidence",
		title = "Build the Case",
		body = "Your notebook has two channels: culprit clues and monster clues. Real evidence points to one answer. Compare with your group — false clues and mistaken witnesses can redirect suspicion.",
		objective = "OPEN THE NOTEBOOK AND REVIEW POSTED EVIDENCE",
	},
	{
		id = "vote",
		context = "Vote",
		title = "Choose Carefully",
		body = "At the campfire, review the evidence and accuse one suspect. Living players receive one server-validated vote.",
		objective = "LOCK IN THE SUSPECT BEST SUPPORTED BY THE CLUES",
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

local function currentContext(state: any): string?
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
	if phase == "Investigation" then
		local evidenceFound = readNumber(round, "evidenceFound", 0)
		if evidenceFound > 0 then
			return "Evidence"
		end
		return "Investigation"
	end
	if phase == "Campfire" then
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

function TutorialController:_allSeen(): boolean
	for _, step in self.steps do
		if step.id == TutorialController.StepIds.Spectator then
			local lastState = self.lastState
			local player = if type(lastState) == "table" then lastState.player else nil
			if readString(player, "role", "") ~= "Spectator" then
				continue
			end
		end
		if not self.seen[step.id] then
			return false
		end
	end
	return true
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
	self.view:Show(step, function()
		self:Advance()
	end, function()
		self:Skip()
	end)
end

function TutorialController:Update(state: any)
	if self.completed or self.destroyed then
		return
	end
	self.lastState = state
	local context = currentContext(state)
	if not context then
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
	elseif self:_allSeen() then
		self:_finish(false)
	end
end

function TutorialController:Advance()
	if self.completed or self.destroyed then
		return
	end
	local active = self.activeStep
	if active then
		self.seen[active.id] = true
	end
	self.activeStep = nil
	self.view:Hide()

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
	if completed and not self.completed then
		-- Loading an already-completed profile is synchronization, not a new
		-- completion. Do not call onCompleted and write the setting back.
		self.completed = true
		self.activeStep = nil
		self.view:Hide()
	end
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
