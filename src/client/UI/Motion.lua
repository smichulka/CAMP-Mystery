--!strict

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent:WaitForChild("Theme"))

export type TransitionConfig = {
	duration: number?,
	distance: number?,
	scale: number?,
	reducedMotion: boolean?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?,
	onComplete: ((completed: boolean) -> ())?,
}

export type StaggerConfig = {
	duration: number?,
	reducedMotion: boolean?,
	preset: ("PopIn" | "SlideUp" | "FadeIn")?,
	step: number?,
	onComplete: ((completed: boolean) -> ())?,
}

type FadeProperty = {
	instance: Instance,
	property: string,
	value: number,
}

type TransitionRecord = {
	target: GuiObject,
	tweens: { Tween },
	connections: { RBXScriptConnection },
	completion: BindableEvent,
	onComplete: ((completed: boolean) -> ())?,
	cleanup: (() -> ())?,
	finished: boolean,
}

local Motion = {}

local activeTransitions = setmetatable({}, { __mode = "k" }) :: {
	[GuiObject]: TransitionRecord,
}
local reducedMotionProvider: (() -> boolean)? = nil

local function safeDuration(value: number?, fallback: number): number
	if value == nil or value ~= value or math.abs(value) == math.huge then
		return fallback
	end
	return math.clamp(value, 0, 3)
end

local function safeDistance(value: number?, fallback: number): number
	if value == nil or value ~= value or math.abs(value) == math.huge then
		return fallback
	end
	return math.clamp(value, 0, 160)
end

local function safeScale(value: number?, fallback: number): number
	if value == nil or value ~= value or math.abs(value) == math.huge then
		return fallback
	end
	return math.clamp(value, 0.1, 3)
end

local function callback(record: TransitionRecord, completed: boolean)
	local onComplete = record.onComplete
	if onComplete then
		local succeeded, failure = pcall(onComplete, completed)
		if not succeeded then
			warn("[Motion] Completion callback failed:", failure)
		end
	end
	record.completion:Fire(completed)
	task.defer(function()
		record.completion:Destroy()
	end)
end

local function finish(record: TransitionRecord, completed: boolean)
	if record.finished then
		return
	end
	record.finished = true
	for _, connection in record.connections do
		connection:Disconnect()
	end
	table.clear(record.connections)
	-- Stop every remaining tween: when one tween of a record ends early the
	-- others would keep playing with their listeners disconnected, overwriting
	-- the resting values cleanup() just restored.
	for _, tween in record.tweens do
		tween:Cancel()
	end
	table.clear(record.tweens)
	if activeTransitions[record.target] == record then
		activeTransitions[record.target] = nil
	end
	if record.cleanup then
		record.cleanup()
	end
	callback(record, completed)
end

local function cancelRecord(record: TransitionRecord)
	if record.finished then
		return
	end
	record.finished = true
	for _, connection in record.connections do
		connection:Disconnect()
	end
	table.clear(record.connections)
	for _, tween in record.tweens do
		tween:Cancel()
	end
	table.clear(record.tweens)
	if activeTransitions[record.target] == record then
		activeTransitions[record.target] = nil
	end
	if record.cleanup then
		record.cleanup()
	end
	callback(record, false)
end

local function begin(
	target: GuiObject,
	onComplete: ((completed: boolean) -> ())?,
	cleanup: (() -> ())?
): TransitionRecord
	local active = activeTransitions[target]
	if active then
		cancelRecord(active)
	end
	local record: TransitionRecord = {
		target = target,
		tweens = {},
		connections = {},
		completion = Instance.new("BindableEvent"),
		onComplete = onComplete,
		cleanup = cleanup,
		finished = false,
	}
	activeTransitions[target] = record
	return record
end

local function play(record: TransitionRecord): RBXScriptSignal
	if #record.tweens == 0 then
		task.defer(function()
			finish(record, true)
		end)
		return record.completion.Event
	end

	local remaining = #record.tweens
	for _, tween in record.tweens do
		table.insert(
			record.connections,
			tween.Completed:Connect(function(playbackState: Enum.PlaybackState)
				if record.finished then
					return
				end
				if playbackState ~= Enum.PlaybackState.Completed then
					finish(record, false)
					return
				end
				remaining -= 1
				if remaining == 0 then
					finish(record, true)
				end
			end)
		)
		tween:Play()
	end
	return record.completion.Event
end

local function addFadeProperties(properties: { FadeProperty }, instance: Instance)
	if instance:IsA("GuiObject") then
		table.insert(properties, {
			instance = instance,
			property = "BackgroundTransparency",
			value = instance.BackgroundTransparency,
		})
	end
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		table.insert(properties, {
			instance = instance,
			property = "TextTransparency",
			value = instance.TextTransparency,
		})
		table.insert(properties, {
			instance = instance,
			property = "TextStrokeTransparency",
			value = instance.TextStrokeTransparency,
		})
	end
	if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		table.insert(properties, {
			instance = instance,
			property = "ImageTransparency",
			value = instance.ImageTransparency,
		})
	end
	if instance:IsA("UIStroke") then
		table.insert(properties, {
			instance = instance,
			property = "Transparency",
			value = instance.Transparency,
		})
	end
	if instance:IsA("CanvasGroup") then
		table.insert(properties, {
			instance = instance,
			property = "GroupTransparency",
			value = instance.GroupTransparency,
		})
	end
end

local function isVisibleDescendant(instance: Instance, target: GuiObject): boolean
	local current: Instance? = instance
	while current and current ~= target do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return true
end

local function fadeProperties(target: GuiObject): { FadeProperty }
	local properties: { FadeProperty } = {}
	addFadeProperties(properties, target)
	for _, descendant in target:GetDescendants() do
		if isVisibleDescendant(descendant, target) then
			addFadeProperties(properties, descendant)
		end
	end
	return properties
end

local function setFade(properties: { FadeProperty }, transparent: boolean)
	for _, entry in properties do
		pcall(function()
			(entry.instance :: any)[entry.property] = if transparent then 1 else entry.value
		end)
	end
end

local function addFadeTweens(
	record: TransitionRecord,
	properties: { FadeProperty },
	tweenInfo: TweenInfo,
	transparent: boolean
)
	local goalsByInstance: { [Instance]: { [string]: any } } = {}
	for _, entry in properties do
		local goals = goalsByInstance[entry.instance]
		if not goals then
			goals = {}
			goalsByInstance[entry.instance] = goals
		end
		goals[entry.property] = if transparent then 1 else entry.value
	end
	for instance, goals in goalsByInstance do
		table.insert(record.tweens, TweenService:Create(instance, tweenInfo, goals))
	end
end

local function findReducedMotionAttribute(target: GuiObject): boolean
	local current: Instance? = target
	while current do
		if current:GetAttribute("ReducedMotion") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

function Motion.SetReducedMotionProvider(provider: (() -> boolean)?)
	reducedMotionProvider = provider
end

function Motion.IsReducedMotion(target: GuiObject, override: boolean?): boolean
	if override ~= nil then
		return override
	end
	local provider = reducedMotionProvider
	if provider then
		local succeeded, value = pcall(provider)
		if succeeded and value == true then
			return true
		end
	end
	return findReducedMotionAttribute(target)
end

function Motion.Cancel(target: GuiObject)
	local active = activeTransitions[target]
	if active then
		cancelRecord(active)
	end
end

local function motionScale(target: GuiObject): UIScale
	local existing = target:FindFirstChild("MotionScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local scale = Instance.new("UIScale")
	scale.Name = "MotionScale"
	scale.Scale = 1
	scale.Parent = target
	return scale
end

local function pop(
	target: GuiObject,
	appearing: boolean,
	config: TransitionConfig?
): RBXScriptSignal
	local resolved = config or {}
	local reduced = Motion.IsReducedMotion(target, resolved.reducedMotion)
	local duration = safeDuration(
		resolved.duration,
		if reduced then Theme.Motion.ReducedFadeDuration else Theme.Motion.PopDuration
	)
	local popScale = safeScale(resolved.scale, Theme.Motion.PopScale)
	-- Cancel any in-flight transition BEFORE capturing resting values, so its
	-- cleanup restores the true baseline instead of a mid-animation snapshot.
	Motion.Cancel(target)
	local properties = fadeProperties(target)
	local scale = motionScale(target)
	local record = begin(target, resolved.onComplete, function()
		setFade(properties, false)
		scale.Scale = 1
	end)
	local tweenInfo = TweenInfo.new(
		duration,
		resolved.easingStyle
			or if appearing then Theme.Motion.PopEasingStyle else Theme.Motion.ExitEasingStyle,
		resolved.easingDirection
			or if appearing then Theme.Motion.PopEasingDirection else Theme.Motion.ExitEasingDirection
	)

	if appearing then
		setFade(properties, true)
	else
		setFade(properties, false)
	end
	addFadeTweens(record, properties, tweenInfo, not appearing)

	if not reduced then
		scale.Scale = if appearing then popScale else 1
		table.insert(
			record.tweens,
			TweenService:Create(scale, tweenInfo, {
				Scale = if appearing then 1 else popScale,
			})
		)
	end
	return play(record)
end

function Motion.PopIn(target: GuiObject, config: TransitionConfig?): RBXScriptSignal
	return pop(target, true, config)
end

function Motion.PopOut(target: GuiObject, config: TransitionConfig?): RBXScriptSignal
	return pop(target, false, config)
end

local function shifted(position: UDim2, yOffset: number): UDim2
	return UDim2.new(
		position.X.Scale,
		position.X.Offset,
		position.Y.Scale,
		position.Y.Offset + yOffset
	)
end

local function shiftedHorizontal(position: UDim2, xOffset: number): UDim2
	return UDim2.new(
		position.X.Scale,
		position.X.Offset + xOffset,
		position.Y.Scale,
		position.Y.Offset
	)
end

local function slide(
	target: GuiObject,
	appearing: boolean,
	config: TransitionConfig?
): RBXScriptSignal
	local resolved = config or {}
	local reduced = Motion.IsReducedMotion(target, resolved.reducedMotion)
	if reduced then
		return if appearing then Motion.FadeIn(target, resolved) else Motion.FadeOut(target, resolved)
	end

	local duration = safeDuration(resolved.duration, Theme.Motion.SlideDuration)
	local distance = safeDistance(resolved.distance, Theme.Motion.SlideOffset)
	-- Cancel first so the captured Position/fade values are the true baseline
	Motion.Cancel(target)
	local restingPosition = target.Position
	local properties = fadeProperties(target)
	local record = begin(target, resolved.onComplete, function()
		target.Position = restingPosition
		setFade(properties, false)
	end)
	local tweenInfo = TweenInfo.new(
		duration,
		resolved.easingStyle or Theme.Motion.StandardEasingStyle,
		resolved.easingDirection or Theme.Motion.StandardEasingDirection
	)
	if appearing then
		target.Position = shifted(restingPosition, distance)
		setFade(properties, true)
	else
		target.Position = restingPosition
		setFade(properties, false)
	end
	table.insert(
		record.tweens,
		TweenService:Create(target, tweenInfo, {
			Position = if appearing then restingPosition else shifted(restingPosition, distance),
		})
	)
	addFadeTweens(record, properties, tweenInfo, not appearing)
	return play(record)
end

function Motion.SlideUp(target: GuiObject, config: TransitionConfig?): RBXScriptSignal
	return slide(target, true, config)
end

function Motion.SlideDown(target: GuiObject, config: TransitionConfig?): RBXScriptSignal
	return slide(target, false, config)
end

local function fade(
	target: GuiObject,
	appearing: boolean,
	config: TransitionConfig?
): RBXScriptSignal
	local resolved = config or {}
	local reduced = Motion.IsReducedMotion(target, resolved.reducedMotion)
	local duration = safeDuration(
		resolved.duration,
		if reduced then Theme.Motion.ReducedFadeDuration else Theme.Motion.FadeDuration
	)
	-- Cancel first so the captured fade values are the true baseline
	Motion.Cancel(target)
	local properties = fadeProperties(target)
	local record = begin(target, resolved.onComplete, function()
		setFade(properties, false)
	end)
	local tweenInfo = TweenInfo.new(
		duration,
		resolved.easingStyle or Theme.Motion.StandardEasingStyle,
		resolved.easingDirection or Theme.Motion.StandardEasingDirection
	)
	if appearing then
		setFade(properties, true)
	else
		setFade(properties, false)
	end
	addFadeTweens(record, properties, tweenInfo, not appearing)
	return play(record)
end

function Motion.FadeIn(target: GuiObject, config: TransitionConfig?): RBXScriptSignal
	return fade(target, true, config)
end

function Motion.FadeOut(target: GuiObject, config: TransitionConfig?): RBXScriptSignal
	return fade(target, false, config)
end

function Motion.Shake(target: GuiObject, config: TransitionConfig?): RBXScriptSignal
	local resolved = config or {}
	if Motion.IsReducedMotion(target, resolved.reducedMotion) then
		local record = begin(target, resolved.onComplete, nil)
		return play(record)
	end

	-- Cancel first so the captured Position is the true resting baseline
	Motion.Cancel(target)
	local restingPosition = target.Position
	local distance = safeDistance(resolved.distance, Theme.Motion.ShakeDistance)
	local duration = safeDuration(resolved.duration, Theme.Motion.ShakeStepDuration)
	local record = begin(target, resolved.onComplete, function()
		target.Position = restingPosition
	end)
	local offsets = { -distance, distance, -distance * 0.55, distance * 0.55, 0 }

	task.spawn(function()
		for _, offset in offsets do
			if record.finished then
				return
			end
			local tween = TweenService:Create(
				target,
				TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
				{ Position = shiftedHorizontal(restingPosition, offset) }
			)
			table.clear(record.tweens)
			table.insert(record.tweens, tween)
			tween:Play()
			local playbackState = tween.Completed:Wait()
			if record.finished then
				return
			end
			if playbackState ~= Enum.PlaybackState.Completed then
				finish(record, false)
				return
			end
		end
		finish(record, true)
	end)
	return record.completion.Event
end

local function visibleChildren(container: GuiObject): { GuiObject }
	local children: { GuiObject } = {}
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			table.insert(children, child)
		end
	end
	table.sort(children, function(left: GuiObject, right: GuiObject): boolean
		if left.LayoutOrder == right.LayoutOrder then
			return left.Name < right.Name
		end
		return left.LayoutOrder < right.LayoutOrder
	end)
	return children
end

function Motion.StaggerChildren(container: GuiObject, config: StaggerConfig?): RBXScriptSignal
	local resolved = config or {}
	-- Cancel a running stagger first: its cleanup re-shows children it had
	-- hidden, so the visibility capture below sees the full set.
	Motion.Cancel(container)
	local children = visibleChildren(container)
	local reduced = Motion.IsReducedMotion(container, resolved.reducedMotion)
	local step = safeDuration(resolved.step, Theme.Motion.StaggerDelay)
	if reduced then
		step = 0
	end
	local record = begin(container, resolved.onComplete, function()
		for _, child in children do
			if child.Parent then
				child.Visible = true
				Motion.Cancel(child)
			end
		end
	end)
	if #children == 0 then
		return play(record)
	end

	for _, child in children do
		Motion.Cancel(child)
		child.Visible = false
	end

	local remaining = #children
	for index, child in children do
		task.delay((index - 1) * step, function()
			if record.finished or not child.Parent then
				if not record.finished then
					remaining -= 1
					if remaining == 0 then
						finish(record, true)
					end
				end
				return
			end
			child.Visible = true
			local childConfig: TransitionConfig = {
				duration = resolved.duration,
				reducedMotion = reduced,
				onComplete = function(_completed: boolean)
					if record.finished then
						return
					end
					remaining -= 1
					if remaining == 0 then
						finish(record, true)
					end
				end,
			}
			if reduced or resolved.preset == "FadeIn" then
				Motion.FadeIn(child, childConfig)
			elseif resolved.preset == "PopIn" then
				Motion.PopIn(child, childConfig)
			else
				Motion.SlideUp(child, childConfig)
			end
		end)
	end
	return record.completion.Event
end

return table.freeze(Motion)
