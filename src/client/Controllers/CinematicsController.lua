--!strict

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Motion = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Motion"))

type TransitionMode = "LongDay" | "LongNight" | "Short"

type CinematicsControllerState = {
	motionTarget: GuiObject,
	colorCorrection: ColorCorrectionEffect,
	atmosphere: Atmosphere,
	baselineClockTime: number,
	baselineSaturation: number,
	baselineAtmosphereDensity: number,
	phaseBaselineSaturation: number,
	phaseNightIntensity: number,
	activeTweens: { Tween },
	dreadTween: Tween?,
	dreadFraction: number,
	dreadPulseToken: number,
	dreadPulseRunning: boolean,
	dreadPulseHigh: boolean,
	transitionActive: boolean,
	transitionToken: number,
	ghostActive: boolean,
	ghostSaturationOffset: number,
	setNightIntensity: ((number) -> ())?,
	destroyed: boolean,
}

local CinematicsController = {}
CinematicsController.__index = CinematicsController

export type CinematicsController = typeof(setmetatable(
	{} :: CinematicsControllerState,
	CinematicsController
))

CinematicsController.AttributeNames = table.freeze({
	ClockTime = "CampMysteryBaselineClockTime",
	Saturation = "CampMysteryBaselineSaturation",
	AtmosphereDensity = "CampMysteryBaselineAtmosphereDensity",
})

local LONG_TRANSITION_DURATION = 3.5
local SHORT_TRANSITION_DURATION = 1.5
local NIGHT_CLOCK_TIME = 21
local DAY_CLOCK_TIME = 8
local NIGHT_ATMOSPHERE_DENSITY = 0.45
local DESATURATED = -0.7
local PARTIAL_RECOVERY = -0.35
local DREAD_TWEEN_DURATION = 0.35
local DREAD_PULSE_STEP = 1.2
local GHOST_TINT = Color3.fromRGB(200, 220, 255)
local DEFAULT_TINT = Color3.fromRGB(255, 255, 255)

local function readNumberAttribute(instance: Instance, name: string, fallback: number): number
	local value = instance:GetAttribute(name)
	if type(value) == "number" and value == value and math.abs(value) < math.huge then
		return value
	end
	return fallback
end

local function resolveColorCorrection(): ColorCorrectionEffect
	for _, name in { "CampColor", "ColorCorrection", "CampMysteryCinematicColor" } do
		local candidate = Lighting:FindFirstChild(name)
		if candidate and candidate:IsA("ColorCorrectionEffect") then
			return candidate
		end
	end
	local existing = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if existing then
		return existing
	end
	local created = Instance.new("ColorCorrectionEffect")
	created.Name = "CampMysteryCinematicColor"
	created.Saturation = 0
	created.Parent = Lighting
	return created
end

local function resolveAtmosphere(): Atmosphere
	for _, name in { "CampAtmosphere", "Atmosphere", "CampMysteryCinematicAtmosphere" } do
		local candidate = Lighting:FindFirstChild(name)
		if candidate and candidate:IsA("Atmosphere") then
			return candidate
		end
	end
	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	if existing then
		return existing
	end
	local created = Instance.new("Atmosphere")
	created.Name = "CampMysteryCinematicAtmosphere"
	created.Density = 0
	created.Parent = Lighting
	return created
end

local function transitionMode(phaseName: string): TransitionMode?
	local normalized = string.lower(phaseName)
	if string.find(normalized, "night", 1, true)
		or string.find(normalized, "investigation", 1, true)
	then
		return "LongNight"
	end
	if normalized == "day" then
		return "LongDay"
	end
	if normalized == "campfire" or normalized == "resolution" then
		return "Short"
	end
	return nil
end

local function phaseNightIntensity(phaseName: string): number
	return if phaseName == "Night"
			or phaseName == "MurderPlanning"
			or phaseName == "NightTransform"
			or phaseName == "Investigation"
		then 1
		else 0
end

function CinematicsController.new(
	motionTarget: GuiObject,
	setNightIntensity: ((number) -> ())?
): CinematicsController
	local colorCorrection = resolveColorCorrection()
	local atmosphere = resolveAtmosphere()
	local attributes = CinematicsController.AttributeNames
	local baselineSaturation = readNumberAttribute(
		Lighting,
		attributes.Saturation,
		colorCorrection.Saturation
	)
	local self: CinematicsController = setmetatable({
		motionTarget = motionTarget,
		colorCorrection = colorCorrection,
		atmosphere = atmosphere,
		baselineClockTime = readNumberAttribute(
			Lighting,
			attributes.ClockTime,
			Lighting.ClockTime
		),
		baselineSaturation = baselineSaturation,
		baselineAtmosphereDensity = readNumberAttribute(
			Lighting,
			attributes.AtmosphereDensity,
			atmosphere.Density
		),
		phaseBaselineSaturation = baselineSaturation,
		phaseNightIntensity = 0,
		activeTweens = {},
		dreadTween = nil,
		dreadFraction = 0,
		dreadPulseToken = 0,
		dreadPulseRunning = false,
		dreadPulseHigh = false,
		transitionActive = false,
		transitionToken = 0,
		ghostActive = false,
		ghostSaturationOffset = 0,
		setNightIntensity = setNightIntensity,
		destroyed = false,
	}, CinematicsController)
	return self
end

function CinematicsController:_restoreBaseline()
	Lighting.ClockTime = self.baselineClockTime
	self.colorCorrection.Saturation =
		self.phaseBaselineSaturation + self.ghostSaturationOffset
	self.colorCorrection.TintColor = if self.ghostActive
		then GHOST_TINT
		else DEFAULT_TINT
	self.atmosphere.Density = self.baselineAtmosphereDensity
end

function CinematicsController:_stopDreadPulse()
	self.dreadPulseToken += 1
	self.dreadPulseRunning = false
	self.dreadPulseHigh = false
end

function CinematicsController:_resetDread()
	local tween = self.dreadTween
	if tween then
		tween:Cancel()
		self.dreadTween = nil
	end
	self.dreadFraction = 0
	self:_stopDreadPulse()
	self.colorCorrection.Saturation =
		self.phaseBaselineSaturation + self.ghostSaturationOffset
	self.colorCorrection.TintColor = if self.ghostActive
		then GHOST_TINT
		else DEFAULT_TINT
	local setNightIntensity = self.setNightIntensity
	if setNightIntensity then
		setNightIntensity(self.phaseNightIntensity)
	end
end

function CinematicsController:_cancelActive()
	self.transitionToken += 1
	for _, tween in self.activeTweens do
		tween:Cancel()
	end
	table.clear(self.activeTweens)
	self.transitionActive = false
	self:_resetDread()
	self:_restoreBaseline()
end

function CinematicsController:_playTween(
	instance: Instance,
	duration: number,
	goals: { [string]: any }
)
	if self.destroyed then
		return
	end
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		goals
	)
	table.insert(self.activeTweens, tween)
	tween:Play()
end

function CinematicsController:_delay(token: number, delaySeconds: number, action: () -> ())
	task.delay(delaySeconds, function()
		if self.destroyed or token ~= self.transitionToken then
			return
		end
		action()
	end)
end

function CinematicsController:_completeAfter(token: number, duration: number)
	self:_delay(token, duration, function()
		self.transitionActive = false
		self:_resetDread()
		self:_restoreBaseline()
	end)
end

function CinematicsController:_playLong(token: number, night: boolean)
	self:_playTween(self.colorCorrection, 0.5, {
		Saturation = DESATURATED,
	})
	self:_delay(token, 0.5, function()
		self:_playTween(Lighting, 2.5, {
			ClockTime = if night then NIGHT_CLOCK_TIME else DAY_CLOCK_TIME,
		})
	end)
	self:_delay(token, 1, function()
		self:_playTween(self.atmosphere, 2, {
			Density = if night
				then NIGHT_ATMOSPHERE_DENSITY
				else self.baselineAtmosphereDensity,
		})
	end)
	self:_delay(token, 2, function()
		self:_playTween(self.colorCorrection, 1, {
			Saturation = PARTIAL_RECOVERY,
		})
	end)
	self:_completeAfter(token, LONG_TRANSITION_DURATION)
end

function CinematicsController:_playShort(token: number)
	self:_playTween(self.colorCorrection, 0.45, {
		Saturation = DESATURATED,
	})
	self:_delay(token, 0.6, function()
		self:_playTween(self.colorCorrection, 0.9, {
			Saturation = self.baselineSaturation,
		})
	end)
	self:_completeAfter(token, SHORT_TRANSITION_DURATION)
end

function CinematicsController:_scheduleDreadPulse(token: number)
	task.delay(DREAD_PULSE_STEP, function()
		if self.destroyed
			or token ~= self.dreadPulseToken
			or self.dreadFraction <= 0.5
			or self.transitionActive
		then
			return
		end
		self.dreadPulseHigh = not self.dreadPulseHigh
		local setNightIntensity = self.setNightIntensity
		if setNightIntensity then
			local base = 0.35 + 0.25 * self.dreadFraction
			setNightIntensity(math.clamp(
				base + (if self.dreadPulseHigh then 0.08 else 0),
				0,
				1
			))
		end
		self:_scheduleDreadPulse(token)
	end)
end

function CinematicsController:_updateDreadVignette()
	local setNightIntensity = self.setNightIntensity
	if not setNightIntensity then
		return
	end
	if self.dreadFraction <= 0.5 then
		self:_stopDreadPulse()
		setNightIntensity(self.phaseNightIntensity)
		return
	end
	local base = 0.35 + 0.25 * self.dreadFraction
	setNightIntensity(base)
	if Motion.IsReducedMotion(self.motionTarget) then
		self:_stopDreadPulse()
		return
	end
	if not self.dreadPulseRunning then
		self.dreadPulseRunning = true
		self.dreadPulseToken += 1
		self:_scheduleDreadPulse(self.dreadPulseToken)
	end
end

function CinematicsController:SetMonsterDread(fraction: number)
	if self.destroyed or self.transitionActive then
		return
	end
	local resolved = if fraction == fraction and math.abs(fraction) < math.huge
		then math.clamp(fraction, 0, 1)
		else 0
	self.dreadFraction = resolved
	local activeTween = self.dreadTween
	if activeTween then
		activeTween:Cancel()
		self.dreadTween = nil
	end
	local tween = TweenService:Create(
		self.colorCorrection,
		TweenInfo.new(
			DREAD_TWEEN_DURATION,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut
		),
		{
			Saturation = self.phaseBaselineSaturation - (0.5 * resolved)
				+ self.ghostSaturationOffset,
		}
	)
	self.dreadTween = tween
	tween.Completed:Connect(function()
		if self.dreadTween == tween then
			self.dreadTween = nil
		end
	end)
	tween:Play()
	self:_updateDreadVignette()
end

function CinematicsController:SetGhostMode(active: boolean)
	if self.destroyed or self.ghostActive == active then
		return
	end
	self.ghostActive = active
	self.ghostSaturationOffset = if active then -0.28 else 0
	local targetSaturation =
		self.phaseBaselineSaturation + self.ghostSaturationOffset
	self:_playTween(self.colorCorrection, if active then 1.2 else 0.6, {
		Saturation = targetSaturation,
		TintColor = if active then GHOST_TINT else DEFAULT_TINT,
	})
end

function CinematicsController:PlayPhaseTransition(phaseName: string)
	self:_cancelActive()
	if self.destroyed then
		return
	end
	self.phaseBaselineSaturation = readNumberAttribute(
		Lighting,
		CinematicsController.AttributeNames.Saturation,
		self.baselineSaturation
	)
	self.phaseNightIntensity = phaseNightIntensity(phaseName)
	local mode = transitionMode(phaseName)
	if not mode or Motion.IsReducedMotion(self.motionTarget) then
		self:_resetDread()
		self:_restoreBaseline()
		return
	end
	self.transitionActive = true
	local token = self.transitionToken
	if mode == "Short" then
		self:_playShort(token)
	else
		self:_playLong(token, mode == "LongNight")
	end
end

function CinematicsController:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.ghostActive = false
	self.ghostSaturationOffset = 0
	self:_cancelActive()
end

return CinematicsController
