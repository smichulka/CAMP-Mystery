--!strict

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Components = require(script.Parent:WaitForChild("Components"))
local Theme = require(script.Parent:WaitForChild("Theme"))

type StatusPresentation = {
	label: string,
	color: Color3,
}

type EffectsViewState = {
	root: Frame,
	phaseCard: Frame,
	phaseTitle: TextLabel,
	phaseBody: TextLabel,
	statusOverlay: Frame,
	statusStroke: UIStroke,
	statusLabel: TextLabel,
	subtitle: TextLabel,
	spectatorOverlay: Frame,
	spectatorActive: boolean,
	spectatorTween: Tween?,
	vignette: ImageLabel?,
	vignetteTween: Tween?,
	injuryPulseTween: Tween?,
	nightIntensity: number,
	ghostTintActive: boolean,
	monsterModeActive: boolean,
	monsterModeTween: Tween?,
	monsterModeBaselineShift: Color3,
	evidenceFlash: CanvasGroup?,
	evidenceFlashTween: Tween?,
	healFlash: CanvasGroup?,
	healFlashTween: Tween?,
	reducedMotion: boolean,
	phaseToken: number,
	subtitleToken: number,
	lastPhase: string?,
	lastStatus: string?,
	destroyed: boolean,
}

local EffectsView = {}
EffectsView.__index = EffectsView

export type EffectsView = typeof(setmetatable({} :: EffectsViewState, EffectsView))

local PHASE_COPY: {
	[string]: {
		title: string,
		body: string,
		murderer: { title: string, body: string }?,
	},
} = {
	Lobby = {
		title = "THE CAMP IS OPEN",
		body = "Ready up while the remaining campers arrive.",
	},
	RoleReveal = {
		title = "ROLES ASSIGNED",
		body = "Read your private role briefing.",
	},
	Day = {
		title = "DAYLIGHT",
		body = "Prepare the camp and gather equipment before sunset.",
		murderer = {
			title = "A NEW DAY",
			body = "Play your role. Act like the rest.",
		},
	},
	MurderPlanning = {
		title = "SOMETHING IS BEING PLANNED",
		body = "The camp grows quiet. Stay alert.",
		murderer = {
			title = "YOUR PLAN IS SET",
			body = "You chose your prey. Strike before dawn.",
		},
	},
	NightTransform = {
		title = "THE TOWN AWAKENS",
		body = "The abandoned town has appeared beyond the camp.",
		murderer = {
			title = "YOU ARE THE MONSTER",
			body = "The hunt begins. Move in shadow.",
		},
	},
	Investigation = {
		title = "NIGHT INVESTIGATION",
		body = "Search for evidence, protect each other, and survive.",
		murderer = {
			title = "THEY ARE SEARCHING",
			body = "Stay hidden. Let them doubt each other.",
		},
	},
	Campfire = {
		title = "CAMPFIRE VOTE",
		body = "Compare the evidence and identify the culprit.",
		murderer = {
			title = "THE VOTE",
			body = "Steer the blame. A tie favors you.",
		},
	},
	Resolution = {
		title = "THE MYSTERY BREAKS",
		body = "The final accusation is being resolved.",
		murderer = {
			title = "THE VERDICT",
			body = "Did they catch you?",
		},
	},
	Rewards = {
		title = "ROUND COMPLETE",
		body = "Rewards and role mastery have been updated.",
	},
}

local STATUS_COPY: { [string]: StatusPresentation } = {
	MonsterActive = { label = "THE MONSTER IS ACTIVE", color = Theme.Colors.DangerBright },
	Bleeding = { label = "BLEEDING", color = Theme.Colors.DangerBright },
	Disoriented = { label = "DISORIENTED", color = Theme.Colors.Amber },
	EquipmentDisabled = { label = "EQUIPMENT DISABLED", color = Theme.Colors.Amber },
	Fear = { label = "FEAR", color = Theme.Colors.Danger },
	Latched = { label = "MONSTER LATCHED", color = Theme.Colors.DangerBright },
	Marked = { label = "MARKED", color = Theme.Colors.DangerBright },
	Slowed = { label = "SLOWED", color = Theme.Colors.Info },
	VisionDistortion = { label = "VISION DISTORTED", color = Theme.Colors.Ghost },
	Injured = { label = "INJURED", color = Theme.Colors.Danger },
	Critical = { label = "CRITICAL INJURY", color = Theme.Colors.DangerBright },
	Incapacitated = { label = "INCAPACITATED", color = Theme.Colors.DangerBright },
	Ghost = { label = "SPIRIT STATE", color = Theme.Colors.Ghost },
}

local PULSE_STATUSES: { [string]: boolean } = {
	Injured = true,
	Critical = true,
	Incapacitated = true,
	Bleeding = true,
	Latched = true,
}

local MONSTER_MODE_SHIFT = Color3.fromRGB(42, 8, 4)

local function setLayer(instance: Instance, zIndex: number)
	if instance:IsA("GuiObject") then
		instance.ZIndex = zIndex
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = zIndex
		end
	end
end

local function readPhase(state: any): string?
	if type(state) == "table" and type(state.round) == "table" and type(state.round.phase) == "string" then
		return state.round.phase
	end
	return nil
end

local function readStatus(state: any): string?
	if type(state) ~= "table" then
		return nil
	end
	local combat = state.combat
	if type(combat) == "table" then
		if combat.isGhost == true then
			return "Ghost"
		end
		if type(combat.healthState) == "string" and combat.healthState ~= "Healthy" then
			return combat.healthState
		end
	end
	local player = state.player
	if type(player) == "table" and player.isGhost == true then
		return "Ghost"
	end
	if type(player) == "table" and type(player.statusEffects) == "table" then
		for _, status in player.statusEffects do
			local statusId = if type(status) == "table" then status.statusId else status
			if type(statusId) == "string" and STATUS_COPY[statusId] then
				return statusId
			end
		end
	end
	if type(state.monster) == "table" and state.monster.active == true then
		if type(state.privateMonster) == "table" and state.privateMonster.active == true then
			return nil
		end
		return "MonsterActive"
	end
	return nil
end

function EffectsView.new(parent: Instance): EffectsView
	local existing = parent:FindFirstChild("ReleaseEffects")
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Frame")
	root.Name = "ReleaseEffects"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ZIndex = 50
	root.Parent = parent

	local statusOverlay = Instance.new("Frame")
	statusOverlay.Name = "MonsterStatusOverlay"
	statusOverlay.BackgroundColor3 = Theme.Colors.Danger
	statusOverlay.BackgroundTransparency = 1
	statusOverlay.BorderSizePixel = 0
	statusOverlay.Visible = false
	statusOverlay.ZIndex = 50
	statusOverlay.Parent = root
	-- Stretch past the topbar inset so the danger border hugs the REAL screen
	-- edges; sized to the inset area only, its top stroke floated 58px down
	-- the screen and read as a stray red line across the view. The inset is
	-- read from the root's own absolute offset and tracked via signal because
	-- GuiService:GetGuiInset() reports 0 during early client boot.
	local function applyStatusInset()
		local inset = math.max(0, root.AbsolutePosition.Y)
		statusOverlay.Position = UDim2.fromOffset(0, -inset)
		statusOverlay.Size = UDim2.new(1, 0, 1, inset)
	end
	applyStatusInset()
	root:GetPropertyChangedSignal("AbsolutePosition"):Connect(applyStatusInset)

	local statusStroke = Instance.new("UIStroke")
	statusStroke.Name = "StatusBorder"
	statusStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	statusStroke.Color = Theme.Colors.DangerBright
	statusStroke.Thickness = 8
	statusStroke.Transparency = 0.28
	statusStroke.Parent = statusOverlay

	local statusLabel = Components.Label(statusOverlay, "Status", "", 15, Enum.Font.GothamBold)
	statusLabel.AnchorPoint = Vector2.new(0.5, 1)
	statusLabel.Position = UDim2.new(0.5, 0, 1, -106)
	statusLabel.Size = UDim2.fromOffset(300, 34)
	statusLabel.BackgroundColor3 = Theme.Colors.Background
	statusLabel.BackgroundTransparency = 0.16
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center
	Components.Corner(statusLabel, 17)
	Components.Stroke(statusLabel, Theme.Colors.DangerBright)

	local phaseCard = Components.Panel(root, "PhaseAnnouncement")
	phaseCard.AnchorPoint = Vector2.new(0.5, 0)
	phaseCard.Position = UDim2.new(0.5, 0, 0, -130)
	phaseCard.Size = UDim2.new(0.68, 0, 0, 102)
	phaseCard.BackgroundColor3 = Theme.Colors.Background
	phaseCard.BackgroundTransparency = 0.04
	phaseCard.Visible = false
	Components.Stroke(phaseCard, Theme.Colors.Gold, 2)
	local phaseConstraint = Instance.new("UISizeConstraint")
	phaseConstraint.MinSize = Vector2.new(310, 96)
	phaseConstraint.MaxSize = Vector2.new(680, 110)
	phaseConstraint.Parent = phaseCard

	local phaseTitle = Components.Label(phaseCard, "Title", "", 22, Enum.Font.GothamBold)
	phaseTitle.Position = UDim2.fromOffset(18, 10)
	phaseTitle.Size = UDim2.new(1, -36, 0, 36)
	phaseTitle.TextColor3 = Theme.Colors.Gold
	phaseTitle.TextXAlignment = Enum.TextXAlignment.Center

	local phaseBody = Components.Label(phaseCard, "Body", "", 14)
	phaseBody.Position = UDim2.fromOffset(18, 48)
	phaseBody.Size = UDim2.new(1, -36, 0, 42)
	phaseBody.TextXAlignment = Enum.TextXAlignment.Center

	local subtitle = Components.Label(root, "Subtitle", "", 16, Enum.Font.GothamBold)
	subtitle.AnchorPoint = Vector2.new(0.5, 1)
	subtitle.Position = UDim2.new(0.5, 0, 1, -118)
	subtitle.Size = UDim2.new(0.72, 0, 0, 48)
	subtitle.BackgroundColor3 = Theme.Colors.Black
	subtitle.BackgroundTransparency = 0.16
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.TextStrokeColor3 = Theme.Colors.Black
	subtitle.TextStrokeTransparency = 0
	subtitle.Visible = false
	Components.Corner(subtitle, 8)
	local subtitleConstraint = Instance.new("UISizeConstraint")
	subtitleConstraint.MinSize = Vector2.new(280, 44)
	subtitleConstraint.MaxSize = Vector2.new(820, 60)
	subtitleConstraint.Parent = subtitle

	setLayer(root, 50)

	-- This overlay is intentionally created after setLayer so its lower layer is
	-- not overwritten with the status-overlay layer used by the other effects.
	local spectatorOverlay = Instance.new("Frame")
	spectatorOverlay.Name = "SpectatorOverlay"
	spectatorOverlay.Size = UDim2.fromScale(1, 1)
	spectatorOverlay.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	spectatorOverlay.BackgroundTransparency = 1
	spectatorOverlay.BorderSizePixel = 0
	spectatorOverlay.ZIndex = 2
	spectatorOverlay.Parent = root

	local vignetteInstance = parent:FindFirstChild("Vignette")
	local vignette = if vignetteInstance and vignetteInstance:IsA("ImageLabel")
		then vignetteInstance
		else nil

	local self: EffectsView = setmetatable({
		root = root,
		phaseCard = phaseCard,
		phaseTitle = phaseTitle,
		phaseBody = phaseBody,
		statusOverlay = statusOverlay,
		statusStroke = statusStroke,
		statusLabel = statusLabel,
		subtitle = subtitle,
		spectatorOverlay = spectatorOverlay,
		spectatorActive = false,
		spectatorTween = nil,
		vignette = vignette,
		vignetteTween = nil,
		injuryPulseTween = nil,
		nightIntensity = 0,
		ghostTintActive = false,
		monsterModeActive = false,
		monsterModeTween = nil,
		monsterModeBaselineShift = Lighting.ColorShift_Top,
		evidenceFlash = nil,
		evidenceFlashTween = nil,
		healFlash = nil,
		healFlashTween = nil,
		reducedMotion = false,
		phaseToken = 0,
		subtitleToken = 0,
		lastPhase = nil,
		lastStatus = nil,
		destroyed = false,
	}, EffectsView)
	return self
end

function EffectsView:SetReducedMotion(reducedMotion: boolean)
	local changed = self.reducedMotion ~= reducedMotion
	self.reducedMotion = reducedMotion
	self.root:SetAttribute("ReducedMotion", reducedMotion)
	if changed then
		local spectatorTween = self.spectatorTween
		if spectatorTween then
			spectatorTween:Cancel()
			self.spectatorTween = nil
		end
		self.spectatorOverlay.BackgroundTransparency = if self.spectatorActive then 0.72 else 1
		if reducedMotion then
			self:_stopInjuryPulse()
			self.statusStroke.Transparency = 0.32
		elseif self.lastStatus and PULSE_STATUSES[self.lastStatus] then
			self:_startInjuryPulse(self.lastStatus, 0)
		end
		local monsterModeTween = self.monsterModeTween
		if monsterModeTween then
			monsterModeTween:Cancel()
			self.monsterModeTween = nil
		end
		Lighting.ColorShift_Top = if self.monsterModeActive
			then MONSTER_MODE_SHIFT
			else self.monsterModeBaselineShift
		self:SetNightIntensity(self.nightIntensity)
	end
end

function EffectsView:SetSpectatorMode(active: boolean)
	if self.destroyed or active == self.spectatorActive then
		return
	end
	self.spectatorActive = active

	local activeTween = self.spectatorTween
	if activeTween then
		activeTween:Cancel()
		self.spectatorTween = nil
	end

	local targetTransparency = if active then 0.72 else 1
	if self.reducedMotion then
		self.spectatorOverlay.BackgroundTransparency = targetTransparency
		return
	end

	local tween = TweenService:Create(
		self.spectatorOverlay,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ BackgroundTransparency = targetTransparency }
	)
	self.spectatorTween = tween
	tween.Completed:Connect(function()
		if self.spectatorTween == tween then
			self.spectatorTween = nil
		end
	end)
	tween:Play()
end

function EffectsView:SetNightIntensity(fraction: number)
	if self.destroyed then
		return
	end
	local resolved = if fraction == fraction and math.abs(fraction) < math.huge
		then math.clamp(fraction, 0, 1)
		else 0
	local intensityChanged = self.nightIntensity ~= resolved
	self.nightIntensity = resolved
	local vignette = self.vignette
	if not vignette or not vignette.Parent then
		return
	end
	local targetTransparency = if self.ghostTintActive
		then 0.6
		elseif vignette.Image ~= "" then 1 + (0.45 - 1) * resolved else 1
	if not intensityChanged
		and self.vignetteTween == nil
		and math.abs(vignette.ImageTransparency - targetTransparency) < 0.001
	then
		return
	end
	local activeTween = self.vignetteTween
	if activeTween then
		activeTween:Cancel()
		self.vignetteTween = nil
	end
	if self.reducedMotion then
		vignette.ImageTransparency = targetTransparency
		return
	end
	local tween = TweenService:Create(
		vignette,
		TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{
			BackgroundColor3 = if self.ghostTintActive
				then Theme.Colors.Ghost
				else Theme.Colors.White,
			BackgroundTransparency = if self.ghostTintActive
					and vignette.Image == ""
				then 0.82
				else 1,
			ImageColor3 = if self.ghostTintActive
				then Theme.Colors.Ghost
				else Theme.Colors.White,
			ImageTransparency = targetTransparency,
		}
	)
	self.vignetteTween = tween
	tween.Completed:Connect(function()
		if self.vignetteTween == tween then
			self.vignetteTween = nil
		end
	end)
	tween:Play()
end

function EffectsView:SetGhostTint(active: boolean)
	if self.destroyed or self.ghostTintActive == active then
		return
	end
	self.ghostTintActive = active
	local vignette = self.vignette
	if not vignette or not vignette.Parent then
		return
	end
	local targetTransparency = if active
		then 0.6
		elseif vignette.Image ~= ""
			then 1 + (0.45 - 1) * self.nightIntensity
			else 1
	local activeTween = self.vignetteTween
	if activeTween then
		activeTween:Cancel()
		self.vignetteTween = nil
	end
	if self.reducedMotion then
		vignette.BackgroundColor3 = if active then Theme.Colors.Ghost else Theme.Colors.White
		vignette.BackgroundTransparency = if active and vignette.Image == "" then 0.82 else 1
		vignette.ImageColor3 = if active then Theme.Colors.Ghost else Theme.Colors.White
		vignette.ImageTransparency = targetTransparency
		return
	end
	local tween = TweenService:Create(
		vignette,
		TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{
			BackgroundColor3 = if active then Theme.Colors.Ghost else Theme.Colors.White,
			BackgroundTransparency = if active and vignette.Image == "" then 0.82 else 1,
			ImageColor3 = if active then Theme.Colors.Ghost else Theme.Colors.White,
			ImageTransparency = targetTransparency,
		}
	)
	self.vignetteTween = tween
	tween.Completed:Connect(function()
		if self.vignetteTween == tween then
			self.vignetteTween = nil
		end
	end)
	tween:Play()
end

function EffectsView:SetMonsterMode(active: boolean)
	if self.destroyed or active == self.monsterModeActive then
		return
	end
	self.monsterModeActive = active

	local activeTween = self.monsterModeTween
	if activeTween then
		activeTween:Cancel()
		self.monsterModeTween = nil
	end

	local targetShift = if active
		then MONSTER_MODE_SHIFT
		else self.monsterModeBaselineShift
	if self.reducedMotion then
		Lighting.ColorShift_Top = targetShift
		return
	end

	local tween = TweenService:Create(
		Lighting,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ ColorShift_Top = targetShift }
	)
	self.monsterModeTween = tween
	tween.Completed:Connect(function()
		if self.monsterModeTween == tween then
			self.monsterModeTween = nil
		end
	end)
	tween:Play()
end

function EffectsView:FlashEvidenceFound()
	if self.destroyed or self.reducedMotion then
		return
	end

	local activeTween = self.evidenceFlashTween
	if activeTween then
		activeTween:Cancel()
		self.evidenceFlashTween = nil
	end
	local activeFlash = self.evidenceFlash
	if activeFlash then
		activeFlash:Destroy()
		self.evidenceFlash = nil
	end

	local flash = Instance.new("CanvasGroup")
	flash.Name = "EvidenceFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Theme.Colors.Gold
	flash.BackgroundTransparency = 0
	flash.GroupTransparency = 0.72
	flash.BorderSizePixel = 0
	flash.Active = false
	flash.ZIndex = 75
	flash.Parent = self.root
	self.evidenceFlash = flash

	local fadeOut = TweenService:Create(
		flash,
		TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ GroupTransparency = 1 }
	)
	self.evidenceFlashTween = fadeOut
	fadeOut.Completed:Connect(function()
		if self.evidenceFlashTween == fadeOut then
			self.evidenceFlashTween = nil
		end
		if self.evidenceFlash == flash then
			self.evidenceFlash = nil
		end
		if flash.Parent then
			flash:Destroy()
		end
	end)
	fadeOut:Play()
end

function EffectsView:ShowHealedEffect()
	if self.destroyed then
		return
	end

	local activeTween = self.healFlashTween
	if activeTween then
		activeTween:Cancel()
		self.healFlashTween = nil
	end
	local activeFlash = self.healFlash
	if activeFlash then
		activeFlash:Destroy()
		self.healFlash = nil
	end

	local flash = Instance.new("CanvasGroup")
	flash.Name = "HealFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(60, 190, 90)
	flash.BackgroundTransparency = 0
	flash.GroupTransparency = 0.78
	flash.BorderSizePixel = 0
	flash.Active = false
	flash.ZIndex = 75
	flash.Parent = self.root
	self.healFlash = flash

	local fadeOut = TweenService:Create(
		flash,
		TweenInfo.new(0.65, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ GroupTransparency = 1 }
	)
	self.healFlashTween = fadeOut
	fadeOut.Completed:Connect(function()
		if self.healFlashTween == fadeOut then
			self.healFlashTween = nil
		end
		if self.healFlash == flash then
			self.healFlash = nil
		end
		if flash.Parent then
			flash:Destroy()
		end
	end)
	fadeOut:Play()
end

function EffectsView:ShowPhase(title: string, body: string, duration: number?)
	if self.destroyed then
		return
	end
	self.phaseToken += 1
	local token = self.phaseToken
	self.phaseTitle.Text = string.upper(title)
	self.phaseBody.Text = body
	self.phaseCard.Visible = true

	if self.reducedMotion then
		self.phaseCard.Position = UDim2.new(0.5, 0, 0, 16)
	else
		self.phaseCard.Position = UDim2.new(0.5, 0, 0, -130)
		TweenService:Create(
			self.phaseCard,
			TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, 0, 0, 16) }
		):Play()
	end

	task.delay(math.clamp(duration or 4, 1, 12), function()
		if self.destroyed or token ~= self.phaseToken or not self.phaseCard.Parent then
			return
		end
		if self.reducedMotion then
			self.phaseCard.Visible = false
		else
			local tween = TweenService:Create(
				self.phaseCard,
				TweenInfo.new(0.2),
				{ Position = UDim2.new(0.5, 0, 0, -130) }
			)
			tween:Play()
			tween.Completed:Connect(function()
				if token == self.phaseToken and self.phaseCard.Parent then
					self.phaseCard.Visible = false
				end
			end)
		end
	end)
end

function EffectsView:ShowAnnouncement(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local title = if type(payload.title) == "string" then payload.title else "CAMP NOTICE"
	local message = if type(payload.message) == "string" then payload.message else ""
	local duration = if type(payload.duration) == "number"
			and payload.duration == payload.duration
			and math.abs(payload.duration) < math.huge
		then payload.duration
		else 4
	self:ShowPhase(title, message, duration)
end

function EffectsView:ShowSubtitle(text: string, duration: number?)
	if self.destroyed or text == "" then
		return
	end
	self.subtitleToken += 1
	local token = self.subtitleToken
	self.subtitle.Text = text
	self.subtitle.Visible = true
	task.delay(math.clamp(duration or 2.5, 0.5, 10), function()
		if not self.destroyed and token == self.subtitleToken and self.subtitle.Parent then
			self.subtitle.Visible = false
		end
	end)
end

function EffectsView:_stopInjuryPulse()
	local tween = self.injuryPulseTween
	if tween then
		tween:Cancel()
		self.injuryPulseTween = nil
	end
end

function EffectsView:_startInjuryPulse(statusId: string, delaySeconds: number)
	if self.destroyed or self.reducedMotion or not PULSE_STATUSES[statusId] then
		return
	end
	self:_stopInjuryPulse()
	local pulseTween = TweenService:Create(
		self.statusStroke,
		TweenInfo.new(
			0.9,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			true
		),
		{ Transparency = 0.72 }
	)
	self.injuryPulseTween = pulseTween
	if delaySeconds <= 0 then
		pulseTween:Play()
		return
	end
	task.delay(delaySeconds, function()
		if not self.destroyed and self.injuryPulseTween == pulseTween then
			pulseTween:Play()
		end
	end)
end

function EffectsView:SetMonsterStatus(statusId: string?, customMessage: string?)
	if self.destroyed or statusId == self.lastStatus then
		return
	end
	self:_stopInjuryPulse()
	self.lastStatus = statusId
	if not statusId then
		self.statusOverlay.Visible = false
		return
	end
	local presentation = STATUS_COPY[statusId]
	if not presentation then
		self.statusOverlay.Visible = false
		return
	end
	self.statusOverlay.Visible = true
	self.statusOverlay.BackgroundColor3 = presentation.color
	self.statusOverlay.BackgroundTransparency = 0.92
	self.statusStroke.Color = presentation.color
	self.statusLabel.TextColor3 = presentation.color
	self.statusLabel.Text = customMessage or presentation.label

	if not self.reducedMotion then
		self.statusStroke.Transparency = 0.05
		TweenService:Create(
			self.statusStroke,
			TweenInfo.new(0.45),
			{ Transparency = 0.32 }
		):Play()
		if PULSE_STATUSES[statusId] then
			self:_startInjuryPulse(statusId, 0.5)
		end
	else
		self.statusStroke.Transparency = 0.32
	end
end

function EffectsView:Update(state: any)
	if self.destroyed then
		return
	end
	local phase = readPhase(state)
	if phase and phase ~= self.lastPhase then
		self.lastPhase = phase
		local copy = PHASE_COPY[phase]
		if copy then
			local player = if type(state) == "table" and type(state.player) == "table"
				then state.player
				else nil
			local localRole = if type(player) == "table" and type(player.role) == "string"
				then player.role
				else ""
			local isGhost = type(player) == "table" and player.isGhost == true
			local murdererCopy = copy.murderer
			local selected = if localRole == "Murderer"
					and not isGhost
					and murdererCopy
				then murdererCopy
				else copy
			self:ShowPhase(selected.title, selected.body)
		end
	end
	local nightPhase = phase == "MurderPlanning"
		or phase == "NightTransform"
		or phase == "Investigation"
	self:SetNightIntensity(if nightPhase then 1 else 0)
	self:SetMonsterStatus(readStatus(state), nil)
end

function EffectsView:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.phaseToken += 1
	self.subtitleToken += 1
	self:_stopInjuryPulse()
	if self.spectatorTween then
		self.spectatorTween:Cancel()
		self.spectatorTween = nil
	end
	if self.vignetteTween then
		self.vignetteTween:Cancel()
		self.vignetteTween = nil
	end
	if self.monsterModeTween then
		self.monsterModeTween:Cancel()
		self.monsterModeTween = nil
	end
	if self.evidenceFlashTween then
		self.evidenceFlashTween:Cancel()
		self.evidenceFlashTween = nil
	end
	if self.evidenceFlash then
		self.evidenceFlash:Destroy()
		self.evidenceFlash = nil
	end
	if self.healFlashTween then
		self.healFlashTween:Cancel()
		self.healFlashTween = nil
	end
	if self.healFlash then
		self.healFlash:Destroy()
		self.healFlash = nil
	end
	Lighting.ColorShift_Top = self.monsterModeBaselineShift
	if self.spectatorOverlay.Parent then
		self.spectatorOverlay:Destroy()
	end
	if self.root.Parent then
		self.root:Destroy()
	end
end

return EffectsView
