--!strict

local Components = require(script.Parent:WaitForChild("Components"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local NotebookView = {}

NotebookView.DEDUCTION_HINT = "Planted clues frame someone. Real clues converge."
NotebookView.DEDUCTION_HINT_FAKE =
	"A planted clue was contradicted — frames someone. Real clues converge."
NotebookView.DEDUCTION_HINT_COMPARE =
	"Compare three clues. Planted clues frame someone; real clues converge."

type BuildDeps = {
	makeHeader: (parent: Instance, title: string, closeCallback: () -> ()) -> (),
	setModalVisible: (modal: GuiObject, visible: boolean) -> (),
	addCanvasSizing: (scroll: ScrollingFrame, layout: UIListLayout) -> (),
}

function NotebookView.ShouldShowDeductionHint(phase: string): boolean
	return phase == "Investigation" or phase == "Campfire"
end

function NotebookView.DeductionHintCopy(
	hasVerifiedFake: boolean,
	compareCallout: boolean
): string
	if hasVerifiedFake then
		return NotebookView.DEDUCTION_HINT_FAKE
	end
	if compareCallout then
		return NotebookView.DEDUCTION_HINT_COMPARE
	end
	return NotebookView.DEDUCTION_HINT
end

function NotebookView.ApplyDeductionHint(
	self: any,
	visible: boolean,
	text: string?
)
	local hint = self.deductionHint
	local list = self.evidenceList
	if not hint or not list then
		return
	end
	hint.Visible = visible
	if visible and type(text) == "string" and text ~= "" then
		hint.Text = text
	end
	-- Keep the ruled list clear of the teaching strip when it is showing.
	if visible then
		list.Position = UDim2.fromOffset(18, 142)
		list.Size = UDim2.new(1, -36, 1, -160)
	else
		list.Position = UDim2.fromOffset(18, 108)
		list.Size = UDim2.new(1, -36, 1, -126)
	end
end

function NotebookView.Build(self: any, deps: BuildDeps)
	deps.makeHeader(self.notebook, "EVIDENCE NOTEBOOK", function()
		deps.setModalVisible(self.notebook, false)
	end)
	local rules = Instance.new("Frame")
	rules.Name = "NotebookRules"
	rules.Position = UDim2.fromOffset(0, 58)
	rules.Size = UDim2.new(1, 0, 1, -58)
	rules.BackgroundTransparency = 1
	rules.BorderSizePixel = 0
	rules.ClipsDescendants = true
	rules.ZIndex = 0
	rules.Parent = self.notebook
	for index = 0, 32 do
		local line = Instance.new("Frame")
		line.Name = "Rule_" .. tostring(index + 1)
		line.Position = UDim2.fromOffset(14, index * Theme.Notebook.LineHeight)
		line.Size = UDim2.new(1, -28, 0, 1)
		line.BackgroundColor3 = Theme.Notebook.PageLines
		line.BackgroundTransparency = 0.58
		line.BorderSizePixel = 0
		line.ZIndex = 0
		line.Parent = rules
	end
	local header = self.notebook:FindFirstChild("Header")
	if header and header:IsA("GuiObject") then
		header.ZIndex = 3
		local headerTitle = header:FindFirstChild("Title")
		if headerTitle and headerTitle:IsA("TextLabel") then
			headerTitle.TextColor3 = Theme.Notebook.InkColor
		end
	end
	local summary = Components.Label(
		self.notebook,
		"Summary",
		"TWO CHANNELS: culprit clues narrow who did it; monster clues reveal what is hunting.",
		14
	)
	summary.Position = UDim2.fromOffset(20, 58)
	summary.Size = UDim2.new(1, -40, 0, 48)
	summary.TextColor3 = Theme.Notebook.InkMuted
	summary.ZIndex = 2
	self.evidenceSummary = summary

	-- Teaching strip: planted-vs-real drill during Investigation / Campfire.
	local deductionHint = Components.Label(
		self.notebook,
		"DeductionHint",
		NotebookView.DEDUCTION_HINT,
		12,
		Enum.Font.GothamBold
	)
	deductionHint.Position = UDim2.fromOffset(20, 108)
	deductionHint.Size = UDim2.new(1, -40, 0, 28)
	deductionHint.TextColor3 = Theme.Colors.Amber
	deductionHint.TextWrapped = true
	deductionHint.TextXAlignment = Enum.TextXAlignment.Left
	deductionHint.TextYAlignment = Enum.TextYAlignment.Center
	deductionHint.BackgroundColor3 = Theme.Notebook.TapeColor
	deductionHint.BackgroundTransparency = 0.35
	deductionHint.Visible = false
	deductionHint.ZIndex = 2
	Components.Corner(deductionHint, 6)
	local hintPad = Instance.new("UIPadding")
	hintPad.PaddingLeft = UDim.new(0, 10)
	hintPad.PaddingRight = UDim.new(0, 10)
	hintPad.Parent = deductionHint
	self.deductionHint = deductionHint

	local list = Instance.new("ScrollingFrame")
	list.Name = "EvidenceList"
	list.Position = UDim2.fromOffset(18, 108)
	list.Size = UDim2.new(1, -36, 1, -126)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = Theme.Notebook.InkMuted
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.ZIndex = 2
	list.Parent = self.notebook
	local layout = Components.List(list, 9)
	deps.addCanvasSizing(list, layout)
	self.evidenceList = list
end

function NotebookView.AddSectionHeader(
	list: ScrollingFrame,
	title: string,
	accent: Color3,
	emptyHint: string?
)
	local header = Components.Label(list, "Section_" .. title:gsub("[^%w]", ""), title, 15, Enum.Font.GothamBold)
	header:SetAttribute("Generated", true)
	header.Size = UDim2.new(1, -8, 0, 28)
	header.TextColor3 = accent
	header.TextXAlignment = Enum.TextXAlignment.Left
	if emptyHint then
		local hint = Components.Label(list, "SectionHint_" .. title:gsub("[^%w]", ""), emptyHint, 12)
		hint:SetAttribute("Generated", true)
		hint.Size = UDim2.new(1, -8, 0, 36)
		hint.TextColor3 = Theme.Notebook.InkMuted
		hint.TextWrapped = true
		hint.TextYAlignment = Enum.TextYAlignment.Top
	end
end

return NotebookView
