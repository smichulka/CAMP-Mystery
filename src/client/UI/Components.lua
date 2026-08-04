--!strict

local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Motion = require(script.Parent:WaitForChild("Motion"))

local Components = {}
local soundPlayer: ((eventName: string) -> ())? = nil

export type ButtonOptions = {
	name: string,
	text: string,
	size: UDim2?,
	position: UDim2?,
	color: Color3?,
	layoutOrder: number?,
}

export type EvidenceCardEntry = {
	name: string?,
	displayName: string?,
	description: string?,
	status: string?,
	verificationState: string?,
	previousStatus: string?,
	channel: string?,
	footer: string?,
	iconAsset: string?,
	-- Optional strip/footer tint for unverified cards (Insight cards use an
	-- amber accent to stand apart from ordinary clues).
	accentColor: Color3?,
	layoutOrder: number?,
}

function Components.SetSoundPlayer(player: ((eventName: string) -> ())?)
	soundPlayer = player
end

function Components.PlayUISound(eventName: string)
	local player = soundPlayer
	if player then
		player(eventName)
	end
end

function Components.Corner(parent: GuiObject, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.CornerRadius)
	corner.Parent = parent
	return corner
end

function Components.Stroke(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Colors.Border
	stroke.Thickness = thickness or 1
	stroke.Transparency = Theme.StrokeTransparency
	stroke.Parent = parent
	return stroke
end

function Components.Padding(parent: GuiObject, horizontal: number, vertical: number?): UIPadding
	local y = vertical or horizontal
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, horizontal)
	padding.PaddingRight = UDim.new(0, horizontal)
	padding.PaddingTop = UDim.new(0, y)
	padding.PaddingBottom = UDim.new(0, y)
	padding.Parent = parent
	return padding
end

function Components.Panel(parent: Instance, name: string): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.BackgroundColor3 = Theme.Colors.Panel
	panel.BackgroundTransparency = Theme.PanelTransparency
	panel.BorderSizePixel = 0
	panel.Parent = parent
	Components.Corner(panel)
	Components.Stroke(panel)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
	})
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.92),
		NumberSequenceKeypoint.new(1, 0.96),
	})
	gradient.Rotation = 90
	gradient.Parent = panel
	return panel
end

function Components.Label(
	parent: Instance,
	name: string,
	text: string,
	textSize: number,
	font: Enum.Font?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font or Theme.Typography.BodyFont
	label.Text = text
	label.TextColor3 = Theme.Colors.Text
	label.TextSize = textSize
	-- Heading defaults apply only when the caller did not choose a font;
	-- explicit font/size parameters must never be silently overridden.
	if font == nil and (string.match(name, "Title$") or string.match(name, "Header$")) then
		label.Font = Theme.Typography.HeadingFont
		label.TextSize = Theme.Typography.SubheadingSize
	end
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function escapeRichText(value: string): string
	return (string.gsub(value, "[<>&\"]", {
		["<"] = "&lt;",
		[">"] = "&gt;",
		["&"] = "&amp;",
		['"'] = "&quot;",
	}))
end

function Components.LetterspacedText(value: string, spacing: number?): string
	local resolvedSpacing = math.max(0, math.floor(spacing or Theme.Typography.LetterSpacing))
	if resolvedSpacing == 0 or #value < 2 then
		return escapeRichText(value)
	end
	local spacer = string.format(
		'<font size="%d" transparency="1">.</font>',
		resolvedSpacing
	)
	local characters: { string } = {}
	-- Iterate graphemes, not bytes, so multi-byte UTF-8 text survives spacing
	for first, last in utf8.graphemes(value) do
		table.insert(characters, escapeRichText(string.sub(value, first, last)))
	end
	return table.concat(characters, spacer)
end

function Components.SetLetterspacedText(label: TextLabel, value: string)
	label.RichText = true
	label.Text = Components.LetterspacedText(value, Theme.Typography.LetterSpacing)
end

local function evidenceStatus(value: string?): "Unconfirmed" | "Confirmed" | "Contradicted"
	local normalized = if value then string.lower(value) else ""
	if normalized == "confirmed" or normalized == "verifiedreal" then
		return "Confirmed"
	end
	if normalized == "contradicted" or normalized == "verifiedfake" then
		return "Contradicted"
	end
	return "Unconfirmed"
end

function Components.EvidenceCard(parent: Instance, entry: EvidenceCardEntry): Frame
	local status = evidenceStatus(entry.status or entry.verificationState)
	local previousStatus = if entry.previousStatus
		then evidenceStatus(entry.previousStatus)
		else nil
	local stampColor = if status == "Confirmed"
		then Theme.Notebook.StampConfirmed
		elseif status == "Contradicted" then Theme.Notebook.StampDenied
		else entry.accentColor or Theme.Colors.Gold
	if previousStatus == "Unconfirmed" and status ~= "Unconfirmed" then
		Components.PlayUISound("stamp")
	end

	local card = Instance.new("Frame")
	card.Name = "EvidenceCard"
	card.Size = UDim2.new(
		1,
		-Theme.Notebook.CardPadding,
		0,
		Theme.Notebook.CardHeight
	)
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.LayoutOrder = entry.layoutOrder or 0
	card:SetAttribute("Generated", true)
	card:SetAttribute("IsEvidence", true)
	card:SetAttribute("EvidenceStatus", status)
	card:SetAttribute("PreferredWidth", Theme.Notebook.CardWidth)
	card.Parent = parent

	local shadow = Instance.new("Frame")
	shadow.Name = "DropShadow"
	shadow.Position = UDim2.fromOffset(2, 2)
	shadow.Size = UDim2.new(1, -2, 1, -2)
	shadow.BackgroundColor3 = Theme.Colors.Black
	shadow.BackgroundTransparency = 0.78
	shadow.BorderSizePixel = 0
	shadow.ZIndex = card.ZIndex
	shadow.Parent = card
	Components.Corner(shadow, Theme.SmallCornerRadius)

	local paper = Instance.new("Frame")
	paper.Name = "Paper"
	paper.Size = UDim2.new(1, -2, 1, -2)
	paper.BackgroundColor3 = Theme.Notebook.PageColor
	paper.BackgroundTransparency = 0
	paper.BorderSizePixel = 0
	paper.ClipsDescendants = false
	paper.ZIndex = card.ZIndex + 1
	paper.Parent = card
	Components.Corner(paper, Theme.SmallCornerRadius)

	local strip = Instance.new("Frame")
	strip.Name = "StatusStrip"
	strip.Size = UDim2.new(0, 6, 1, 0)
	strip.BackgroundColor3 = stampColor
	strip.BorderSizePixel = 0
	strip.ZIndex = paper.ZIndex + 1
	strip.Parent = paper
	Components.Corner(strip, Theme.SmallCornerRadius)

	local tape = Instance.new("Frame")
	tape.Name = "MaskingTape"
	tape.AnchorPoint = Vector2.new(0.5, 0)
	tape.Position = UDim2.new(0.5, 0, 0, -5)
	tape.Size = UDim2.fromOffset(56, 12)
	tape.BackgroundColor3 = Theme.Notebook.TapeColor
	tape.BackgroundTransparency = 0.2
	tape.BorderSizePixel = 0
	tape.Rotation = -2
	tape.ZIndex = paper.ZIndex + 3
	tape.Parent = paper

	local titleOffset = Theme.Notebook.CardPadding + 4
	local iconAsset = entry.iconAsset
	if iconAsset and iconAsset ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.Name = "EvidenceIcon"
		icon.Position = UDim2.fromOffset(titleOffset, 10)
		icon.Size = UDim2.fromOffset(24, 24)
		icon.BackgroundTransparency = 1
		icon.BorderSizePixel = 0
		icon.Image = iconAsset
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = paper.ZIndex + 2
		icon.Parent = paper
		titleOffset += 30
	end

	local titleText = entry.name or entry.displayName or "Unknown clue"
	local title = Components.Label(
		paper,
		"Title",
		titleText,
		14,
		Enum.Font.GothamBold
	)
	title.Position = UDim2.fromOffset(titleOffset, 7)
	title.Size = UDim2.new(1, -titleOffset - 96, 0, 28)
	title.TextColor3 = Theme.Notebook.InkColor
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.ZIndex = paper.ZIndex + 2

	local channel = entry.channel
	if channel and channel ~= "" then
		local channelLabel = Components.Label(
			paper,
			"Channel",
			string.upper(channel),
			10,
			Enum.Font.GothamBold
		)
		channelLabel.AnchorPoint = Vector2.new(1, 0)
		channelLabel.Position = UDim2.new(1, -10, 0, 9)
		channelLabel.Size = UDim2.fromOffset(82, 22)
		channelLabel.TextColor3 = Theme.Notebook.InkMuted
		channelLabel.TextXAlignment = Enum.TextXAlignment.Right
		channelLabel.ZIndex = paper.ZIndex + 2
	end

	local description = Components.Label(
		paper,
		"Description",
		entry.description or "No description recorded.",
		11,
		Enum.Font.Gotham
	)
	description.Position = UDim2.fromOffset(Theme.Notebook.CardPadding + 4, 35)
	description.Size = UDim2.new(1, -Theme.Notebook.CardPadding * 2 - 8, 0, 38)
	description.TextColor3 = Theme.Notebook.InkMuted
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.ZIndex = paper.ZIndex + 2

	local footerText = entry.footer
	if footerText and footerText ~= "" then
		local footer = Components.Label(
			paper,
			"Footer",
			footerText,
			10,
			Enum.Font.GothamBold
		)
		footer.Position = UDim2.fromOffset(Theme.Notebook.CardPadding + 4, 70)
		footer.Size = UDim2.new(1, -Theme.Notebook.CardPadding * 2 - 8, 0, 16)
		footer.TextColor3 = stampColor
		footer.ZIndex = paper.ZIndex + 2
	end

	if status ~= "Unconfirmed" then
		local stamp = Components.Label(
			paper,
			"Stamp",
			string.upper(status),
			16,
			Enum.Font.GothamBold
		)
		stamp.AnchorPoint = Vector2.new(0.5, 0.5)
		stamp.Position = UDim2.new(0.72, 0, 0.58, 0)
		stamp.Size = UDim2.fromOffset(144, 30)
		stamp.TextColor3 = stampColor
		stamp.TextTransparency = 0.55
		stamp.TextXAlignment = Enum.TextXAlignment.Center
		stamp.Rotation = -8
		stamp.ZIndex = paper.ZIndex + 3
		Components.Corner(stamp, 4)
	end

	return card
end

function Components.Button(parent: Instance, options: ButtonOptions): TextButton
	local button = Instance.new("TextButton")
	button.Name = options.name
	button.Size = options.size or UDim2.fromOffset(160, 42)
	button.Position = options.position or UDim2.fromOffset(0, 0)
	button.BackgroundColor3 = options.color or Theme.Colors.PanelSoft
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.Text = options.text
	button.TextColor3 = Theme.Colors.Text
	button.TextSize = 15
	button.TextWrapped = true
	button.LayoutOrder = options.layoutOrder or 0
	button.Parent = parent
	Components.Corner(button, Theme.SmallCornerRadius)
	local border = Components.Stroke(button)
	local pressScale = Instance.new("UIScale")
	pressScale.Name = "ButtonPressScale"
	pressScale.Scale = 1
	pressScale.Parent = button

	local normalColor = button.BackgroundColor3
	local hoverColor = normalColor:Lerp(Theme.Colors.White, 0.12)
	local colorTween: Tween? = nil
	local scaleTween: Tween? = nil
	local pressed = false

	local function tweenColor(color: Color3)
		if colorTween then
			colorTween:Cancel()
		end
		colorTween = TweenService:Create(
			button,
			TweenInfo.new(
				Theme.Motion.HoverDuration,
				Theme.Motion.StandardEasingStyle,
				Theme.Motion.StandardEasingDirection
			),
			{ BackgroundColor3 = color }
		)
		colorTween:Play()
	end

	local function tweenScale(scale: number, duration: number, style: Enum.EasingStyle)
		if scaleTween then
			scaleTween:Cancel()
		end
		if Motion.IsReducedMotion(button) then
			pressScale.Scale = 1
			return
		end
		scaleTween = TweenService:Create(
			pressScale,
			TweenInfo.new(duration, style, Enum.EasingDirection.Out),
			{ Scale = scale }
		)
		scaleTween:Play()
	end

	local function press()
		if not button.Active or pressed then
			return
		end
		pressed = true
		tweenScale(
			Theme.Motion.PressScale,
			Theme.Motion.PressDuration,
			Theme.Motion.StandardEasingStyle
		)
	end

	local function release()
		if not pressed and pressScale.Scale == 1 then
			return
		end
		pressed = false
		tweenScale(1, Theme.Motion.ReleaseDuration, Theme.Motion.PopEasingStyle)
	end

	button.MouseEnter:Connect(function()
		if button.Active then
			tweenColor(hoverColor)
			Components.PlayUISound("hover")
		end
	end)
	button.MouseLeave:Connect(function()
		release()
		tweenColor(normalColor)
	end)
	button.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
			or input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.Space
		then
			press()
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
			or input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.Space
		then
			release()
		end
	end)
	button.Activated:Connect(function()
		release()
		if button.Active then
			Components.PlayUISound("click")
		end
	end)
	button.SelectionGained:Connect(function()
		border.Color = Theme.Colors.Gold
		border.Thickness = 3
		border.Transparency = 0
		if button.Active then
			Components.PlayUISound("hover")
		end
	end)
	button.SelectionLost:Connect(function()
		release()
		border.Color = Theme.Colors.Border
		border.Thickness = 1
		border.Transparency = Theme.StrokeTransparency
	end)
	return button
end

function Components.SetButtonEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.Selectable = enabled
	button.AutoButtonColor = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.45
	button.TextTransparency = if enabled then 0 else 0.32
	local pressScale = button:FindFirstChild("ButtonPressScale")
	if not enabled and pressScale and pressScale:IsA("UIScale") then
		pressScale.Scale = 1
	end
	if not enabled and GuiService.SelectedObject == button then
		GuiService.SelectedObject = nil
	end
end

function Components.List(parent: GuiObject, padding: number?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding or 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

function Components.ProgressBar(parent: Instance, name: string): (Frame, Frame, TextLabel)
	local track = Instance.new("Frame")
	track.Name = name
	track.BackgroundColor3 = Theme.Colors.Background
	track.BackgroundTransparency = 0.15
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = parent
	Components.Corner(track, Theme.SmallCornerRadius)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.Colors.Success
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track
	Components.Corner(fill, Theme.SmallCornerRadius)

	local text = Components.Label(track, "Value", "", 12, Enum.Font.GothamBold)
	text.Size = UDim2.fromScale(1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.ZIndex = track.ZIndex + 2
	return track, fill, text
end

function Components.ClearGenerated(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:GetAttribute("Generated") == true then
			child:Destroy()
		end
	end
end

return table.freeze(Components)
