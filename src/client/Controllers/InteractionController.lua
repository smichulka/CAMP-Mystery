--!strict

local ProximityPromptService = game:GetService("ProximityPromptService")

type InteractionCallbacks = {
	shown: (actionText: string, objectText: string, inputText: string) -> (),
	hidden: () -> (),
	triggered: (actionText: string) -> (),
}

local InteractionController = {}

local function inputLabel(prompt: ProximityPrompt): string
	if prompt.ClickablePrompt then
		return "TAP"
	end
	local key = prompt.KeyboardKeyCode
	if key ~= Enum.KeyCode.Unknown then
		return key.Name
	end
	return "USE"
end

function InteractionController.Start(callbacks: InteractionCallbacks): { RBXScriptConnection }
	local connections: { RBXScriptConnection } = {}
	table.insert(connections, ProximityPromptService.PromptShown:Connect(function(
		prompt: ProximityPrompt,
		_inputType: Enum.ProximityPromptInputType
	)
		callbacks.shown(prompt.ActionText, prompt.ObjectText, inputLabel(prompt))
	end))
	table.insert(connections, ProximityPromptService.PromptHidden:Connect(function(
		_prompt: ProximityPrompt
	)
		callbacks.hidden()
	end))
	table.insert(connections, ProximityPromptService.PromptTriggered:Connect(function(
		prompt: ProximityPrompt
	)
		callbacks.triggered(prompt.ActionText)
	end))
	return connections
end

return table.freeze(InteractionController)
