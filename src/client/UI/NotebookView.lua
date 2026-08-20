--!strict

local Components = require(script.Parent:WaitForChild("Components"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local NotebookView = {}

type BuildDeps = {
	makeHeader: (parent: Instance, title: string, closeCallback: () -> ()) -> (),
	setModalVisible: (modal: GuiObject, visible: boolean) -> (),
	addCanvasSizing: (scroll: ScrollingFrame, layout: UIListLayout) -> (),
}

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
