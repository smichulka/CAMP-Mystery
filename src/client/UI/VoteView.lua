--!strict

local Components = require(script.Parent:WaitForChild("Components"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local VoteView = {}

type BuildDeps = {
	makeHeader: (parent: Instance, title: string, closeCallback: () -> ()) -> (),
	setModalVisible: (modal: GuiObject, visible: boolean) -> (),
	addCanvasSizing: (scroll: ScrollingFrame, layout: UIListLayout) -> (),
	readString: (value: any, key: string, defaultValue: string) -> string,
}

local function stageLabelText(stage: string): string
	if stage == "PresentEvidence" or stage == "Discussion" then
		return "PRESENT EVIDENCE"
	elseif stage == "Rebuttal" then
		return "REBUT"
	end
	return "VOTE NOW"
end

function VoteView.Build(self: any, deps: BuildDeps)
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
	local stageLabel = Components.Label(
		self.voteModal,
		"CampfireStageLabel",
		"VOTE NOW",
		12,
		Enum.Font.GothamBold
	)
	stageLabel.AnchorPoint = Vector2.new(0, 0)
	stageLabel.Position = UDim2.fromOffset(20, 40)
	stageLabel.Size = UDim2.new(1, -40, 0, 16)
	stageLabel.TextXAlignment = Enum.TextXAlignment.Left
	stageLabel.TextColor3 = Theme.Colors.Amber
	self.voteStageLabel = stageLabel
	local voteCountLabel = Components.Label(
		self.voteModal,
		"VoteCountLabel",
		"",
		11,
		Enum.Font.GothamBold
	)
	voteCountLabel.AnchorPoint = Vector2.new(1, 0)
	voteCountLabel.Position = UDim2.new(1, -96, 0, 18)
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
	warning.Position = UDim2.fromOffset(20, 58)
	warning.Size = UDim2.new(1, -40, 0, 44)
	warning.TextColor3 = Theme.Colors.Amber
	warning.TextXAlignment = Enum.TextXAlignment.Center
	self.voteWarningLabel = warning
	local list = Instance.new("ScrollingFrame")
	list.Name = "Suspects"
	list.Position = UDim2.fromOffset(18, 106)
	list.Size = UDim2.new(1, -36, 1, -124)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Parent = self.voteModal
	local layout = Components.List(list, 8)
	deps.addCanvasSizing(list, layout)
	self.voteList = list
end

-- Surfaces PresentEvidence / Rebuttal / Voting theater beats on vote + discussion UI.
function VoteView.ApplyCampfireStage(self: any, stage: string)
	local label = self.voteStageLabel
	if label and label:IsA("TextLabel") then
		label.Text = stageLabelText(stage)
		label.Visible = stage == "Voting" or stage == ""
	end
	local panel = self.discussionPanel
	if panel and panel:IsA("GuiObject") then
		local title = panel:FindFirstChild("Title")
		if title and title:IsA("TextLabel") then
			title.Text = stageLabelText(stage)
		end
		local hint = panel:FindFirstChild("Hint")
		if hint and hint:IsA("TextLabel") then
			if stage == "PresentEvidence" or stage == "Discussion" then
				hint.Text =
					"Present your strongest notebook evidence [N]. Rebuttal comes next, then votes lock."
			elseif stage == "Rebuttal" then
				hint.Text =
					"Challenge what was presented. Voting opens when this beat ends."
			else
				hint.Text = "Lock in your accusation before the fire goes out."
			end
		end
	end
end

return VoteView
