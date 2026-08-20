--!strict

local Workspace = game:GetService("Workspace")

local Components = require(script.Parent:WaitForChild("Components"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local VoteView = {}

type BuildDeps = {
	makeHeader: (parent: Instance, title: string, closeCallback: () -> ()) -> (),
	setModalVisible: (modal: GuiObject, visible: boolean) -> (),
	addCanvasSizing: (scroll: ScrollingFrame, layout: UIListLayout) -> (),
	readString: (value: any, key: string, defaultValue: string) -> string,
	readNumber: ((value: any, key: string, defaultValue: number) -> number)?,
}

local function stageLabelText(stage: string): string
	if stage == "PresentEvidence" or stage == "Discussion" then
		return "PRESENT EVIDENCE"
	elseif stage == "Rebuttal" then
		return "REBUTTAL"
	end
	return "VOTE NOW"
end

local function stageAccent(stage: string): Color3
	if stage == "PresentEvidence" or stage == "Discussion" then
		return Theme.Colors.Gold
	elseif stage == "Rebuttal" then
		return Theme.Colors.Amber
	end
	return Theme.Colors.DangerBright
end

local function stageHint(stage: string): string
	if stage == "PresentEvidence" or stage == "Discussion" then
		return "Present your strongest notebook evidence [N]. Rebuttal comes next, then votes lock."
	elseif stage == "Rebuttal" then
		return "Challenge what was presented — call out planted or fake clues. Voting opens next."
	end
	return "Lock in your accusation before the fire goes out."
end

local function nextBeatLabel(stage: string): string
	if stage == "PresentEvidence" or stage == "Discussion" then
		return "Rebuttal"
	elseif stage == "Rebuttal" then
		return "Voting"
	end
	return "Verdict"
end

local function readNumberSafe(deps: BuildDeps?, round: any?, key: string): number
	if deps and deps.readNumber and type(round) == "table" then
		return deps.readNumber(round, key, 0)
	end
	if type(round) == "table" and type(round[key]) == "number" then
		return round[key]
	end
	return 0
end

local function formatCountdown(seconds: number, beatName: string): string
	if seconds <= 0 then
		return string.format("%s starting…", beatName)
	end
	return string.format("%ss until %s", tostring(seconds), beatName)
end

function VoteView.Build(self: any, deps: BuildDeps)
	self._voteViewDeps = deps
	deps.makeHeader(self.voteModal, "CAMPFIRE ACCUSATION", function()
		if self.localVoteHasLocked then
			deps.setModalVisible(self.voteModal, false)
		else
			local voteReqPlayer = if type(self.currentState) == "table" then self.currentState.player else nil
			local voteReqBody = if deps.readString(voteReqPlayer, "role", "") == "Murderer"
				then "Name someone before the fire goes out. Redirect suspicion — every vote matters."
				else "Choose one suspect before the fire goes out."
			self:Notify("Vote required", voteReqBody, "Warning")
		end
	end)
	local voteHeader = self.voteModal:FindFirstChild("Header")
	if voteHeader and voteHeader:IsA("Frame") then
		local voteHeaderTitle = voteHeader:FindFirstChild("Title")
		if voteHeaderTitle and voteHeaderTitle:IsA("TextLabel") then
			-- Reserve 88px for the count and 8px gaps on both sides.
			voteHeaderTitle.Size = UDim2.new(1, -212, 1, 0)
			self.voteModalTitleLabel = voteHeaderTitle
		end
	end
	local stageBanner = Instance.new("Frame")
	stageBanner.Name = "CampfireStageBanner"
	stageBanner.BackgroundColor3 = Theme.Colors.DangerBright
	stageBanner.BackgroundTransparency = 0.15
	stageBanner.BorderSizePixel = 0
	stageBanner.Position = UDim2.fromOffset(18, 38)
	stageBanner.Size = UDim2.new(1, -36, 0, 28)
	stageBanner.Parent = self.voteModal
	Components.Corner(stageBanner, 6)
	local stageStroke = Instance.new("UIStroke")
	stageStroke.Name = "HighContrastStroke"
	stageStroke.Color = Theme.Colors.Black
	stageStroke.Thickness = 2
	stageStroke.Transparency = 0.1
	stageStroke.Parent = stageBanner
	self.voteStageBanner = stageBanner
	local stageLabel = Components.Label(
		stageBanner,
		"CampfireStageLabel",
		"VOTE NOW",
		13,
		Enum.Font.GothamBlack
	)
	stageLabel.Position = UDim2.fromOffset(10, 0)
	stageLabel.Size = UDim2.new(0.62, -12, 1, 0)
	stageLabel.TextXAlignment = Enum.TextXAlignment.Left
	stageLabel.TextColor3 = Theme.Colors.White
	stageLabel.TextStrokeColor3 = Theme.Colors.Black
	stageLabel.TextStrokeTransparency = 0.25
	self.voteStageLabel = stageLabel
	local stageCountdown = Components.Label(
		stageBanner,
		"StageCountdown",
		"",
		11,
		Enum.Font.GothamBold
	)
	stageCountdown.AnchorPoint = Vector2.new(1, 0.5)
	stageCountdown.Position = UDim2.new(1, -10, 0.5, 0)
	stageCountdown.Size = UDim2.new(0.38, -8, 1, -4)
	stageCountdown.TextXAlignment = Enum.TextXAlignment.Right
	stageCountdown.TextColor3 = Theme.Colors.White
	stageCountdown.TextStrokeColor3 = Theme.Colors.Black
	stageCountdown.TextStrokeTransparency = 0.35
	self.voteStageCountdown = stageCountdown
	local voteCountLabel = Components.Label(
		self.voteModal,
		"VoteCountLabel",
		"",
		11,
		Enum.Font.GothamBold
	)
	voteCountLabel.AnchorPoint = Vector2.new(1, 0)
	voteCountLabel.Position = UDim2.new(1, -96, 0, 14)
	voteCountLabel.Size = UDim2.fromOffset(88, 20)
	voteCountLabel.TextXAlignment = Enum.TextXAlignment.Right
	voteCountLabel.TextColor3 = Theme.Colors.TextMuted
	self.voteCountLabel = voteCountLabel
	local warning = Components.Label(
		self.voteModal,
		"Warning",
		"One vote. No take-backs. A tie favors the Murderer.",
		14
	)
	warning.Position = UDim2.fromOffset(20, 72)
	warning.Size = UDim2.new(1, -40, 0, 36)
	warning.TextColor3 = Theme.Colors.Amber
	warning.TextXAlignment = Enum.TextXAlignment.Center
	self.voteWarningLabel = warning
	local list = Instance.new("ScrollingFrame")
	list.Name = "Suspects"
	list.Position = UDim2.fromOffset(18, 114)
	list.Size = UDim2.new(1, -36, 1, -132)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = self.voteModal
	local layout = Components.List(list, 8)
	deps.addCanvasSizing(list, layout)
	self.voteList = list
end

local function applyCountdown(self: any, stage: string, round: any?)
	local deps = self._voteViewDeps
	local now = Workspace:GetServerTimeNow()
	local stageEndsAt = readNumberSafe(deps, round, "campfireStageEndsAt")
	local votingOpensAt = readNumberSafe(deps, round, "votingOpensAt")
	local phaseEndsAt = readNumberSafe(deps, round, "phaseEndsAt")
	local targetAt = 0
	if stage == "PresentEvidence" or stage == "Discussion" then
		targetAt = if stageEndsAt > 0 then stageEndsAt elseif votingOpensAt > 0 then votingOpensAt else 0
	elseif stage == "Rebuttal" then
		targetAt = if votingOpensAt > 0 then votingOpensAt elseif stageEndsAt > 0 then stageEndsAt else 0
	else
		targetAt = phaseEndsAt
	end
	local countdownText = ""
	if targetAt > 0 then
		countdownText = formatCountdown(math.max(0, math.ceil(targetAt - now)), nextBeatLabel(stage))
	end
	local voteCountdown = self.voteStageCountdown
	if voteCountdown and voteCountdown:IsA("TextLabel") then
		voteCountdown.Text = countdownText
		voteCountdown.Visible = countdownText ~= ""
	end
	local discussCountdown = self.discussionStageCountdown
	if discussCountdown and discussCountdown:IsA("TextLabel") then
		discussCountdown.Text = countdownText
		discussCountdown.Visible = countdownText ~= ""
	end
end

-- Surfaces PresentEvidence / Rebuttal / Voting theater beats on vote + discussion UI.
function VoteView.ApplyCampfireStage(self: any, stage: string, round: any?)
	local accent = stageAccent(stage)
	local banner = self.voteStageBanner
	if banner and banner:IsA("Frame") then
		banner.BackgroundColor3 = accent
		banner.Visible = stage == "Voting" or stage == ""
	end
	local label = self.voteStageLabel
	if label and label:IsA("TextLabel") then
		label.Text = stageLabelText(stage)
		label.TextColor3 = Theme.Colors.White
		label.Visible = stage == "Voting" or stage == ""
	end
	local panel = self.discussionPanel
	if panel and panel:IsA("GuiObject") then
		local accentBar = panel:FindFirstChild("StageAccent")
		if accentBar and accentBar:IsA("Frame") then
			accentBar.BackgroundColor3 = accent
		end
		local title = panel:FindFirstChild("Title")
		if title and title:IsA("TextLabel") then
			title.Text = stageLabelText(stage)
			title.TextColor3 = accent
		end
		local hint = panel:FindFirstChild("Hint")
		if hint and hint:IsA("TextLabel") then
			hint.Text = stageHint(stage)
		end
	end
	applyCountdown(self, stage, round)
end

return VoteView
