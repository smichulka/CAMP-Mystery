--!strict

local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ProximityControllerModule = require(
	script.Parent:WaitForChild("ProximityController")
)

type ProximityController = ProximityControllerModule.ProximityController

type InteractionCallbacks = {
	shown: (actionText: string, objectText: string, inputText: string) -> (),
	hidden: () -> (),
	triggered: (actionText: string) -> (),
}

type ActiveHold = {
	part: BasePart,
	startedAt: number,
	duration: number,
}

local InteractionController = {}

local function inputLabel(
	prompt: ProximityPrompt,
	inputType: Enum.ProximityPromptInputType
): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	end
	local key = if inputType == Enum.ProximityPromptInputType.Gamepad
		then prompt.GamepadKeyCode
		else prompt.KeyboardKeyCode
	if key ~= Enum.KeyCode.Unknown then
		return string.upper(key.Name:gsub("^Button", ""))
	end
	return "USE"
end

local function promptPart(prompt: ProximityPrompt): BasePart?
	local parent = prompt.Parent
	return if parent and parent:IsA("BasePart") then parent else nil
end

local function hideDefaultPrompt(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		-- Disabling ProximityPromptService also disables prompt input. Custom style
		-- suppresses Roblox's UI while preserving PromptShown and hold events.
		instance.Style = Enum.ProximityPromptStyle.Custom
	end
end

function InteractionController.Start(
	callbacks: InteractionCallbacks,
	proximityController: ProximityController
): { RBXScriptConnection }
	local connections: { RBXScriptConnection } = {}
	local activeHolds: { [ProximityPrompt]: ActiveHold } = {}

	for _, descendant in Workspace:GetDescendants() do
		hideDefaultPrompt(descendant)
	end
	table.insert(
		connections,
		Workspace.DescendantAdded:Connect(hideDefaultPrompt)
	)

	table.insert(connections, ProximityPromptService.PromptShown:Connect(function(
		prompt: ProximityPrompt,
		inputType: Enum.ProximityPromptInputType
	)
		hideDefaultPrompt(prompt)
		local part = promptPart(prompt)
		local hint = inputLabel(prompt, inputType)
		if part then
			proximityController:RegisterZone(part, prompt.ActionText, hint)
			proximityController:SetProgress(part, 0)
			proximityController:SetVisible(part, true)
			callbacks.hidden()
		else
			callbacks.shown(prompt.ActionText, prompt.ObjectText, hint)
		end
	end))

	table.insert(connections, ProximityPromptService.PromptHidden:Connect(function(
		prompt: ProximityPrompt
	)
		activeHolds[prompt] = nil
		local part = promptPart(prompt)
		if part then
			proximityController:UnregisterZone(part)
		else
			callbacks.hidden()
		end
	end))

	table.insert(
		connections,
		ProximityPromptService.PromptButtonHoldBegan:Connect(function(
			prompt: ProximityPrompt
		)
			local part = promptPart(prompt)
			if not part then
				return
			end
			activeHolds[prompt] = {
				part = part,
				startedAt = os.clock(),
				duration = math.max(prompt.HoldDuration, 0.01),
			}
			proximityController:SetProgress(part, 0)
		end)
	)

	table.insert(
		connections,
		ProximityPromptService.PromptButtonHoldEnded:Connect(function(
			prompt: ProximityPrompt
		)
			local hold = activeHolds[prompt]
			activeHolds[prompt] = nil
			if hold then
				proximityController:SetProgress(hold.part, 0)
			end
		end)
	)

	table.insert(connections, ProximityPromptService.PromptTriggered:Connect(function(
		prompt: ProximityPrompt
	)
		local hold = activeHolds[prompt]
		activeHolds[prompt] = nil
		local part = if hold then hold.part else promptPart(prompt)
		if part then
			proximityController:SetProgress(part, 1)
		end
		callbacks.triggered(prompt.ActionText)
	end))

	table.insert(connections, RunService.RenderStepped:Connect(function()
		local currentTime = os.clock()
		for prompt, hold in activeHolds do
			if not prompt.Parent or not hold.part.Parent then
				activeHolds[prompt] = nil
			else
				proximityController:SetProgress(
					hold.part,
					(currentTime - hold.startedAt) / hold.duration
				)
			end
		end
	end))

	return connections
end

return table.freeze(InteractionController)
