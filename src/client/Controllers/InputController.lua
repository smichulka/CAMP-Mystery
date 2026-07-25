--!strict

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

type InputCallbacks = {
	toggleNotebook: () -> (),
	toggleSettings: () -> (),
	activateSlot: (slot: number) -> (),
	closeModal: () -> (),
}

local InputController = {}

local ACTION_NOTEBOOK = "CampMysteryNotebook"
local ACTION_SETTINGS = "CampMysterySettings"
local ACTION_CLOSE = "CampMysteryCloseModal"
local ACTION_SLOT_PREVIOUS = "CampMysteryPreviousSlot"
local ACTION_SLOT_NEXT = "CampMysteryNextSlot"
local ACTION_SLOT_USE = "CampMysteryUseSlot"
local SLOT_KEYS: { Enum.KeyCode } = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local function activate(callback: () -> ())
	return function(
		_actionName: string,
		inputState: Enum.UserInputState,
		_inputObject: InputObject
	): Enum.ContextActionResult
		if inputState == Enum.UserInputState.Begin then
			callback()
		end
		return Enum.ContextActionResult.Sink
	end
end

function InputController.Start(callbacks: InputCallbacks)
	local selectedSlot = 1
	ContextActionService:BindAction(
		ACTION_NOTEBOOK,
		activate(callbacks.toggleNotebook),
		true,
		Enum.KeyCode.N,
		Enum.KeyCode.ButtonY
	)
	ContextActionService:SetTitle(ACTION_NOTEBOOK, "CLUES")
	ContextActionService:SetPosition(ACTION_NOTEBOOK, UDim2.new(1, -150, 1, -190))

	ContextActionService:BindAction(
		ACTION_SETTINGS,
		activate(callbacks.toggleSettings),
		false,
		Enum.KeyCode.F10,
		Enum.KeyCode.ButtonStart
	)

	ContextActionService:BindAction(
		ACTION_CLOSE,
		activate(callbacks.closeModal),
		false,
		Enum.KeyCode.Escape,
		Enum.KeyCode.ButtonB
	)

	for slot = 1, 9 do
		local slotNumber = slot
		local keyCode = SLOT_KEYS[slotNumber]
		ContextActionService:BindAction(
			"CampMysterySlot" .. tostring(slotNumber),
			activate(function()
				callbacks.activateSlot(slotNumber)
			end),
			false,
			keyCode
		)
	end

	ContextActionService:BindAction(
		ACTION_SLOT_PREVIOUS,
		activate(function()
			selectedSlot = if selectedSlot <= 1 then 9 else selectedSlot - 1
		end),
		false,
		Enum.KeyCode.ButtonL1
	)
	ContextActionService:BindAction(
		ACTION_SLOT_NEXT,
		activate(function()
			selectedSlot = if selectedSlot >= 9 then 1 else selectedSlot + 1
		end),
		false,
		Enum.KeyCode.ButtonR1
	)
	ContextActionService:BindAction(
		ACTION_SLOT_USE,
		activate(function()
			callbacks.activateSlot(selectedSlot)
		end),
		false,
		Enum.KeyCode.ButtonX
	)

	if UserInputService.TouchEnabled then
		ContextActionService:SetImage(ACTION_NOTEBOOK, "")
	end
end

function InputController.Stop()
	ContextActionService:UnbindAction(ACTION_NOTEBOOK)
	ContextActionService:UnbindAction(ACTION_SETTINGS)
	ContextActionService:UnbindAction(ACTION_CLOSE)
	ContextActionService:UnbindAction(ACTION_SLOT_PREVIOUS)
	ContextActionService:UnbindAction(ACTION_SLOT_NEXT)
	ContextActionService:UnbindAction(ACTION_SLOT_USE)
	for slot = 1, 9 do
		ContextActionService:UnbindAction("CampMysterySlot" .. tostring(slot))
	end
end

return table.freeze(InputController)
