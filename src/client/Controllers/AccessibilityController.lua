--!strict

local RunService = game:GetService("RunService")
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

type AccessibilityControllerState = {
	roots: { GuiObject },
	evidence: { [GuiObject]: EvidenceRecord },
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
	table.clear(self.evidence)
	table.clear(self.roots)
end

return AccessibilityController
