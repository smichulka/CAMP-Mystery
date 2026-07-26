--!strict

local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme"))

type ZoneRecord = {
	gui: BillboardGui,
	label: TextLabel,
	keyHint: TextLabel,
	segments: { Frame },
	progress: number,
}

type ProximityControllerState = {
	zones: { [BasePart]: ZoneRecord },
	destroyed: boolean,
}

local ProximityController = {}
ProximityController.__index = ProximityController

export type ProximityController = typeof(
	setmetatable({} :: ProximityControllerState, ProximityController)
)

local SEGMENT_COUNT = 12
local RING_SIZE = 36
local RING_CENTER = RING_SIZE * 0.5
local SEGMENT_RADIUS = 14

local function finiteFraction(value: number): number
	if value ~= value or math.abs(value) == math.huge then
		return 0
	end
	return math.clamp(value, 0, 1)
end

local function rounded(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = if radius
		then UDim.new(0, radius)
		else UDim.new(1, 0)
	corner.Parent = parent
end

local function makeLabel(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	position: UDim2
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Theme.Typography.BodyFont
	label.Text = text
	label.TextColor3 = Theme.Notebook.InkColor
	label.TextSize = Theme.Typography.BodySize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function createZone(part: BasePart, labelText: string, keyText: string): ZoneRecord
	local gui = Instance.new("BillboardGui")
	gui.Name = "CampMysteryProximity"
	gui.Adornee = part
	gui.Size = UDim2.fromOffset(180, 48)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 36
	gui.Enabled = true
	gui.Parent = part

	local panel = Instance.new("Frame")
	panel.Name = "PromptPanel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Theme.Notebook.PageColor
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = gui
	rounded(panel, Theme.SmallCornerRadius)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Gold
	stroke.Thickness = 1
	stroke.Transparency = 0.32
	stroke.Parent = panel

	local ring = Instance.new("Frame")
	ring.Name = "RadialProgressRing"
	ring.Position = UDim2.fromOffset(6, 6)
	ring.Size = UDim2.fromOffset(RING_SIZE, RING_SIZE)
	ring.BackgroundColor3 = Theme.Notebook.InkColor
	ring.BackgroundTransparency = 0.92
	ring.BorderSizePixel = 0
	ring.ClipsDescendants = true
	ring.Parent = panel
	rounded(ring)

	local segments: { Frame } = {}
	for index = 1, SEGMENT_COUNT do
		local angle = ((index - 1) / SEGMENT_COUNT) * math.pi * 2 - math.pi / 2
		local segment = Instance.new("Frame")
		segment.Name = string.format("ArcSegment_%02d", index)
		segment.AnchorPoint = Vector2.new(0.5, 0.5)
		segment.Position = UDim2.fromOffset(
			RING_CENTER + math.cos(angle) * SEGMENT_RADIUS,
			RING_CENTER + math.sin(angle) * SEGMENT_RADIUS
		)
		segment.Size = UDim2.fromOffset(4, 8)
		segment.Rotation = math.deg(angle) + 90
		segment.BackgroundColor3 = Theme.Colors.Gold
		segment.BackgroundTransparency = 0.82
		segment.BorderSizePixel = 0
		segment.Parent = ring
		rounded(segment)
		table.insert(segments, segment)
	end

	local keyHint = makeLabel(
		ring,
		"KeyHint",
		"[" .. keyText .. "]",
		UDim2.fromScale(1, 1),
		UDim2.fromScale(0, 0)
	)
	keyHint.Font = Theme.Typography.HeadingFont
	keyHint.TextColor3 = Theme.Colors.Gold
	keyHint.TextSize = Theme.Typography.CaptionSize
	keyHint.TextXAlignment = Enum.TextXAlignment.Center
	keyHint.ZIndex = 2

	local label = makeLabel(
		panel,
		"InteractionLabel",
		labelText,
		UDim2.new(1, -54, 1, -8),
		UDim2.fromOffset(50, 4)
	)

	return {
		gui = gui,
		label = label,
		keyHint = keyHint,
		segments = segments,
		progress = 0,
	}
end

function ProximityController.new(): ProximityController
	return setmetatable({
		zones = {},
		destroyed = false,
	}, ProximityController)
end

function ProximityController:RegisterZone(
	part: BasePart,
	label: string,
	keyHint: string
)
	if self.destroyed or not part.Parent then
		return
	end
	local safeLabel = if label ~= "" then string.sub(label, 1, 60) else "Interact"
	local safeKey = if keyHint ~= "" then string.sub(keyHint, 1, 12) else "E"
	local existing = self.zones[part]
	if existing and existing.gui.Parent then
		existing.label.Text = safeLabel
		existing.keyHint.Text = "[" .. safeKey .. "]"
		existing.gui.Enabled = true
		return
	end
	if existing then
		self.zones[part] = nil
	end
	self.zones[part] = createZone(part, safeLabel, safeKey)
end

function ProximityController:UnregisterZone(part: BasePart)
	local record = self.zones[part]
	if not record then
		return
	end
	self.zones[part] = nil
	if record.gui.Parent then
		record.gui:Destroy()
	end
end

function ProximityController:SetProgress(part: BasePart, fraction: number)
	local record = self.zones[part]
	if not record then
		return
	end
	local resolved = finiteFraction(fraction)
	record.progress = resolved
	local visibleSegments = math.floor(resolved * SEGMENT_COUNT + 0.5)
	for index, segment in record.segments do
		segment.BackgroundTransparency = if index <= visibleSegments then 0 else 0.82
	end
end

function ProximityController:SetVisible(part: BasePart, visible: boolean)
	local record = self.zones[part]
	if record and record.gui.Parent then
		record.gui.Enabled = visible
	end
end

function ProximityController:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	local parts: { BasePart } = {}
	for part in self.zones do
		table.insert(parts, part)
	end
	for _, part in parts do
		self:UnregisterZone(part)
	end
	table.clear(self.zones)
end

return table.freeze(ProximityController)
