--!strict

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

export type AccessibilitySettings = {
	subtitles: boolean?,
	reducedMotion: boolean?,
	cameraShake: boolean?,
	highContrastEvidence: boolean?,
}

type EvidenceRecord = {
	gui: GuiObject,
	originalTextStrokeTransparency: number?,
	originalTextStrokeColor: Color3?,
}

type WorldEvidenceRecord = {
	part: BasePart,
	marker: BillboardGui,
	pulse: Tween?,
	ancestryConnection: RBXScriptConnection,
}

type AccessibilityControllerState = {
	roots: { GuiObject },
	evidence: { [GuiObject]: EvidenceRecord },
	worldEvidence: { [BasePart]: WorldEvidenceRecord },
	worldEvidenceConnection: RBXScriptConnection?,
	settings: {
		subtitles: boolean,
		reducedMotion: boolean,
		cameraShake: boolean,
		highContrastEvidence: boolean,
	},
	shakeToken: number,
	destroyed: boolean,
	lastEvidenceScanAt: number,
}

local AccessibilityController = {}
AccessibilityController.__index = AccessibilityController

export type AccessibilityController = typeof(setmetatable(
	{} :: AccessibilityControllerState,
	AccessibilityController
))

AccessibilityController.SettingIds = table.freeze({
	Subtitles = "subtitles",
	ReducedMotion = "reducedMotion",
	CameraShake = "cameraShake",
	HighContrastEvidence = "highContrastEvidence",
})

local function isTextGui(gui: GuiObject): boolean
	return gui:IsA("TextLabel") or gui:IsA("TextButton") or gui:IsA("TextBox")
end

function AccessibilityController.new(root: GuiObject?): AccessibilityController
	local roots: { GuiObject } = {}
	if root then
		table.insert(roots, root)
	end
	local self: AccessibilityController = setmetatable({
		roots = roots,
		evidence = {},
		worldEvidence = {},
		worldEvidenceConnection = nil,
		settings = {
			subtitles = true,
			reducedMotion = false,
			cameraShake = true,
			highContrastEvidence = false,
		},
		shakeToken = 0,
		destroyed = false,
		lastEvidenceScanAt = 0,
	}, AccessibilityController)
	self:_applyRootAttributes()
	return self
end

function AccessibilityController:_applyRootAttributes()
	for _, root in self.roots do
		if root.Parent then
			root:SetAttribute("Subtitles", self.settings.subtitles)
			root:SetAttribute("ReducedMotion", self.settings.reducedMotion)
			root:SetAttribute("CameraShake", self.settings.cameraShake)
			root:SetAttribute("HighContrastEvidence", self.settings.highContrastEvidence)
		end
	end
end

function AccessibilityController:_applyEvidence(record: EvidenceRecord)
	local gui = record.gui
	if not gui.Parent then
		self.evidence[gui] = nil
		return
	end
	local enabled = self.settings.highContrastEvidence
	gui:SetAttribute("HighContrastEvidence", enabled)
	local stroke = gui:FindFirstChild("AccessibilityEvidenceStroke")
	if enabled then
		if not stroke then
			local newStroke = Instance.new("UIStroke")
			newStroke.Name = "AccessibilityEvidenceStroke"
			newStroke.Color = Color3.fromRGB(255, 221, 87)
			newStroke.Thickness = 3
			newStroke.Transparency = 0
			newStroke.Parent = gui
		end
		if isTextGui(gui) then
			local textGui = gui :: any
			textGui.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			textGui.TextStrokeTransparency = 0
		end
	elseif stroke then
		stroke:Destroy()
		if isTextGui(gui) then
			local textGui = gui :: any
			if record.originalTextStrokeColor then
				textGui.TextStrokeColor3 = record.originalTextStrokeColor
			end
			if record.originalTextStrokeTransparency then
				textGui.TextStrokeTransparency = record.originalTextStrokeTransparency
			end
		end
	end
end

function AccessibilityController:RegisterRoot(root: GuiObject)
	for _, existing in self.roots do
		if existing == root then
			return
		end
	end
	table.insert(self.roots, root)
	self:_applyRootAttributes()
end

function AccessibilityController:RegisterEvidence(gui: GuiObject)
	if self.evidence[gui] then
		return
	end
	local record: EvidenceRecord = {
		gui = gui,
		originalTextStrokeTransparency = nil,
		originalTextStrokeColor = nil,
	}
	if isTextGui(gui) then
		local textGui = gui :: any
		record.originalTextStrokeTransparency = textGui.TextStrokeTransparency
		record.originalTextStrokeColor = textGui.TextStrokeColor3
	end
	self.evidence[gui] = record
	self:_applyEvidence(record)
end

function AccessibilityController:ScanEvidence(root: Instance)
	-- Called on every state snapshot; the full-GUI walk only needs to catch
	-- newly built evidence rows, so cap it at one sweep per 1.5s to keep
	-- broadcast bursts (combat, votes) from stacking GUI scans in one frame.
	local clockNow = os.clock()
	if clockNow - self.lastEvidenceScanAt < 1.5 then
		return
	end
	self.lastEvidenceScanAt = clockNow
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiObject") then
			local isEvidence = descendant:GetAttribute("IsEvidence") == true
				or string.find(string.lower(descendant.Name), "evidence", 1, true) ~= nil
			if isEvidence then
				self:RegisterEvidence(descendant)
			end
		end
	end
end

-- World evidence cues. The search glow's amber-on-green read is hue-dependent
-- (weak for deuteranopia), so every glow gets a client-side luminance pulse —
-- LocalTransparencyModifier only, zero replication — and highContrastEvidence
-- additionally shows a gold diamond billboard. The marker is deliberately NOT
-- AlwaysOnTop: it must never reveal evidence through walls.
local PULSE_INFO = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

function AccessibilityController:_applyWorldEvidence(record: WorldEvidenceRecord)
	local part = record.part
	if not part.Parent then
		return
	end
	record.marker.Enabled = self.settings.highContrastEvidence
	if record.pulse then
		record.pulse:Cancel()
		record.pulse = nil
		part.LocalTransparencyModifier = 0
	end
	if not self.settings.reducedMotion then
		local pulse = TweenService:Create(part, PULSE_INFO, { LocalTransparencyModifier = 0.45 })
		record.pulse = pulse
		pulse:Play()
	end
end

function AccessibilityController:_attachWorldEvidence(part: BasePart)
	if self.destroyed or self.worldEvidence[part] then
		return
	end
	local marker = Instance.new("BillboardGui")
	marker.Name = "AccessibilityEvidenceMarker"
	marker.Size = UDim2.fromOffset(30, 30)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
	marker.MaxDistance = 90
	marker.AlwaysOnTop = false
	marker.Enabled = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = utf8.char(0x25C6) -- ◆
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 221, 87)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Parent = marker
	marker.Parent = part

	local record: WorldEvidenceRecord = {
		part = part,
		marker = marker,
		pulse = nil,
		ancestryConnection = part.AncestryChanged:Connect(function()
			if not part:IsDescendantOf(game) then
				local existing = self.worldEvidence[part]
				if existing then
					if existing.pulse then
						existing.pulse:Cancel()
					end
					existing.ancestryConnection:Disconnect()
					self.worldEvidence[part] = nil
				end
			end
		end),
	}
	self.worldEvidence[part] = record
	self:_applyWorldEvidence(record)
end

-- Watches the server's evidence folder (Runtime.Evidence) — search glows are
-- its direct children, spawned per Investigation and destroyed on claim.
function AccessibilityController:WatchWorldEvidence(folder: Instance)
	if self.destroyed or self.worldEvidenceConnection then
		return
	end
	self.worldEvidenceConnection = folder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			self:_attachWorldEvidence(child)
		end
	end)
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			self:_attachWorldEvidence(child)
		end
	end
end

function AccessibilityController:ApplySettings(settings: AccessibilitySettings?)
	if not settings or self.destroyed then
		return
	end
	if type(settings.subtitles) == "boolean" then
		self.settings.subtitles = settings.subtitles
	end
	if type(settings.reducedMotion) == "boolean" then
		self.settings.reducedMotion = settings.reducedMotion
	end
	if type(settings.cameraShake) == "boolean" then
		self.settings.cameraShake = settings.cameraShake
	end
	if type(settings.highContrastEvidence) == "boolean" then
		self.settings.highContrastEvidence = settings.highContrastEvidence
	end
	if self.settings.reducedMotion or not self.settings.cameraShake then
		self:CancelCameraShake()
	end
	self:_applyRootAttributes()
	for _, record in self.evidence do
		self:_applyEvidence(record)
	end
	for _, record in self.worldEvidence do
		self:_applyWorldEvidence(record)
	end
end

function AccessibilityController:ApplyGameState(state: any)
	local settings = if type(state) == "table"
			and type(state.profile) == "table"
			and type(state.profile.profile) == "table"
		then state.profile.profile.settings
		else nil
	if type(settings) == "table" then
		self:ApplySettings(settings)
	end
end

function AccessibilityController:IsReducedMotion(): boolean
	return self.settings.reducedMotion
end

function AccessibilityController:AreSubtitlesEnabled(): boolean
	return self.settings.subtitles
end

function AccessibilityController:CanShakeCamera(): boolean
	return self.settings.cameraShake and not self.settings.reducedMotion
end

function AccessibilityController:GetMotionDuration(standardDuration: number): number
	return if self.settings.reducedMotion then 0 else math.max(0, standardDuration)
end

function AccessibilityController:CancelCameraShake()
	self.shakeToken += 1
end

function AccessibilityController:ShakeCamera(strength: number, duration: number)
	if self.destroyed or not self:CanShakeCamera() then
		return
	end
	self.shakeToken += 1
	local token = self.shakeToken
	local safeStrength = math.clamp(strength, 0, 2)
	local safeDuration = math.clamp(duration, 0.05, 2)

	task.spawn(function()
		local startedAt = os.clock()
		local previousOffset = CFrame.identity
		while not self.destroyed and token == self.shakeToken do
			local elapsed = os.clock() - startedAt
			if elapsed >= safeDuration then
				break
			end
			RunService.RenderStepped:Wait()
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame = camera.CFrame * previousOffset:Inverse()
				local fade = 1 - (elapsed / safeDuration)
				local x = math.noise(elapsed * 24, 0, 0) * safeStrength * fade
				local y = math.noise(0, elapsed * 27, 0) * safeStrength * fade
				local roll = math.noise(0, 0, elapsed * 22) * math.rad(safeStrength) * fade
				previousOffset = CFrame.new(x * 0.08, y * 0.08, 0) * CFrame.Angles(0, 0, roll)
				camera.CFrame = camera.CFrame * previousOffset
			end
		end
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CFrame = camera.CFrame * previousOffset:Inverse()
		end
	end)
end

function AccessibilityController:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self:CancelCameraShake()
	self.settings.highContrastEvidence = false
	for _, record in self.evidence do
		self:_applyEvidence(record)
	end
	if self.worldEvidenceConnection then
		self.worldEvidenceConnection:Disconnect()
		self.worldEvidenceConnection = nil
	end
	for part, record in self.worldEvidence do
		if record.pulse then
			record.pulse:Cancel()
		end
		record.ancestryConnection:Disconnect()
		record.marker:Destroy()
		part.LocalTransparencyModifier = 0
	end
	table.clear(self.worldEvidence)
	table.clear(self.evidence)
	table.clear(self.roots)
end

return AccessibilityController
