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
	activeTweens: { Tween },
	transitionToken: number,
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

function CinematicsController.new(motionTarget: GuiObject): CinematicsController
	local colorCorrection = resolveColorCorrection()
	local atmosphere = resolveAtmosphere()
	local attributes = CinematicsController.AttributeNames
	local self: CinematicsController = setmetatable({
		motionTarget = motionTarget,
		colorCorrection = colorCorrection,
		atmosphere = atmosphere,
		baselineClockTime = readNumberAttribute(
			Lighting,
			attributes.ClockTime,
			Lighting.ClockTime
		),
		baselineSaturation = readNumberAttribute(
			Lighting,
			attributes.Saturation,
			colorCorrection.Saturation
		),
		baselineAtmosphereDensity = readNumberAttribute(
			Lighting,
			attributes.AtmosphereDensity,
			atmosphere.Density
		),
		activeTweens = {},
		transitionToken = 0,
		destroyed = false,
	}, CinematicsController)
	return self
end

function CinematicsController:_restoreBaseline()
	Lighting.ClockTime = self.baselineClockTime
	self.colorCorrection.Saturation = self.baselineSaturation
	self.atmosphere.Density = self.baselineAtmosphereDensity
end

function CinematicsController:_cancelActive()
	self.transitionToken += 1
	for _, tween in self.activeTweens do
		tween:Cancel()
	end
	table.clear(self.activeTweens)
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

function CinematicsController:PlayPhaseTransition(phaseName: string)
	self:_cancelActive()
	if self.destroyed then
		return
	end
	local mode = transitionMode(phaseName)
	if not mode or Motion.IsReducedMotion(self.motionTarget) then
		return
	end
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
	self:_cancelActive()
end

return CinematicsController
