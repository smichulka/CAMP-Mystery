--!strict

local HapticService = game:GetService("HapticService")
local UserInputService = game:GetService("UserInputService")

local INPUT_TYPE = Enum.UserInputType.Gamepad1
local MOTOR_SMALL = Enum.VibrationMotor.Small
local MOTOR_LARGE = Enum.VibrationMotor.Large

local function isSupported(motor: Enum.VibrationMotor): boolean
	local ok, result = pcall(function()
		return HapticService:IsMotorSupported(INPUT_TYPE, motor)
	end)
	return ok and result == true
end

local generationByMotor: { [Enum.VibrationMotor]: number } = {}

local function vibrate(motor: Enum.VibrationMotor, amplitude: number, duration: number)
	if not isSupported(motor) then
		return
	end
	local generation = (generationByMotor[motor] or 0) + 1
	generationByMotor[motor] = generation
	pcall(function()
		HapticService:SetMotor(INPUT_TYPE, motor, amplitude)
	end)
	task.delay(duration, function()
		-- A newer pulse owns this motor now; let it finish on its own clock
		if generationByMotor[motor] ~= generation then
			return
		end
		pcall(function()
			HapticService:SetMotor(INPUT_TYPE, motor, 0)
		end)
	end)
end

local HapticController = {}

-- Short, light tap — UI confirmation, notebook open/close, button press
function HapticController.Click()
	vibrate(MOTOR_SMALL, 0.35, 0.06)
end

-- Medium bump — action accepted, item equipped
function HapticController.Impact()
	vibrate(MOTOR_SMALL, 0.6, 0.1)
	vibrate(MOTOR_LARGE, 0.4, 0.08)
end

-- Strong rumble — injury, danger
function HapticController.Danger()
	vibrate(MOTOR_LARGE, 0.85, 0.22)
	vibrate(MOTOR_SMALL, 0.5, 0.18)
end

-- Double-pulse — win reveal / celebration
function HapticController.Celebrate()
	vibrate(MOTOR_LARGE, 0.7, 0.12)
	task.delay(0.18, function()
		vibrate(MOTOR_LARGE, 0.5, 0.1)
	end)
end

-- Sharp error buzz — action rejected
function HapticController.Error()
	vibrate(MOTOR_SMALL, 0.9, 0.08)
	task.delay(0.12, function()
		vibrate(MOTOR_SMALL, 0.7, 0.06)
	end)
end

return HapticController
