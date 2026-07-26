--!strict

local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

type CameraControllerState = {
	connections: { RBXScriptConnection },
	ghostMode: boolean,
	destroyed: boolean,
	position: Vector3,
	yaw: number,
	pitch: number,
	keyboardMove: { [Enum.KeyCode]: boolean },
	stickMove: Vector2,
	stickLook: Vector2,
	leftTrigger: number,
	rightTrigger: number,
	keyboardSprint: boolean,
	gamepadSprint: boolean,
	previousMouseBehavior: Enum.MouseBehavior,
	previousMouseIconEnabled: boolean,
	lastFlickerAt: number,
	lastRumbleAt: number,
	rumbleToken: number,
}

local CameraController = {}
CameraController.__index = CameraController

export type CameraController = typeof(
	setmetatable({} :: CameraControllerState, CameraController)
)

local WALK_SPEED = 24
local SPRINT_SPEED = 48
local MINIMUM_ALTITUDE = 1
local MAXIMUM_ALTITUDE = 200
local FLICKER_RANGE = 20
local FLICKER_COOLDOWN = 60
local RUMBLE_COOLDOWN = 0.5
local MOUSE_SENSITIVITY = 0.0025
local STICK_LOOK_SPEED = 2.2

local MOVEMENT_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Q] = true,
	[Enum.KeyCode.E] = true,
}

local function finiteFraction(value: number): number
	if value ~= value or math.abs(value) == math.huge then
		return 0
	end
	return math.clamp(value, 0, 1)
end

local function lightPosition(light: Light): Vector3?
	local parent = light.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	end
	if parent and parent:IsA("BasePart") then
		return parent.Position
	end
	return nil
end

local function groundHeight(position: Vector3): number
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Include
	local ground: { Instance } = { Workspace.Terrain }
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") and baseplate.CanQuery then
		table.insert(ground, baseplate)
	end
	parameters.FilterDescendantsInstances = ground
	parameters.IgnoreWater = false
	local result = Workspace:Raycast(
		Vector3.new(position.X, MAXIMUM_ALTITUDE + 50, position.Z),
		Vector3.new(0, -(MAXIMUM_ALTITUDE + 350), 0),
		parameters
	)
	return if result then result.Position.Y + MINIMUM_ALTITUDE else MINIMUM_ALTITUDE
end

function CameraController.new(): CameraController
	local camera = Workspace.CurrentCamera
	local initialCFrame = if camera then camera.CFrame else CFrame.new(0, 12, 0)
	local pitch, yaw = initialCFrame:ToOrientation()
	local self: CameraController = setmetatable({
		connections = {},
		ghostMode = false,
		destroyed = false,
		position = initialCFrame.Position,
		yaw = yaw,
		pitch = pitch,
		keyboardMove = {},
		stickMove = Vector2.zero,
		stickLook = Vector2.zero,
		leftTrigger = 0,
		rightTrigger = 0,
		keyboardSprint = false,
		gamepadSprint = false,
		previousMouseBehavior = UserInputService.MouseBehavior,
		previousMouseIconEnabled = UserInputService.MouseIconEnabled,
		lastFlickerAt = -math.huge,
		lastRumbleAt = -math.huge,
		rumbleToken = 0,
	}, CameraController)

	table.insert(
		self.connections,
		UserInputService.InputBegan:Connect(function(
			input: InputObject,
			gameProcessed: boolean
		)
			if not self.ghostMode or gameProcessed then
				return
			end
			local keyCode = input.KeyCode
			if MOVEMENT_KEYS[keyCode] then
				self.keyboardMove[keyCode] = true
			elseif keyCode == Enum.KeyCode.LeftShift
				or keyCode == Enum.KeyCode.RightShift
			then
				self.keyboardSprint = true
			elseif keyCode == Enum.KeyCode.ButtonL3 then
				self.gamepadSprint = true
			elseif keyCode == Enum.KeyCode.G or keyCode == Enum.KeyCode.ButtonY then
				self:_flickerNearestLight()
			end
		end)
	)
	table.insert(
		self.connections,
		UserInputService.InputEnded:Connect(function(
			input: InputObject,
			_gameProcessed: boolean
		)
			local keyCode = input.KeyCode
			if MOVEMENT_KEYS[keyCode] then
				self.keyboardMove[keyCode] = nil
			elseif keyCode == Enum.KeyCode.LeftShift
				or keyCode == Enum.KeyCode.RightShift
			then
				self.keyboardSprint = false
			elseif keyCode == Enum.KeyCode.ButtonL3 then
				self.gamepadSprint = false
			end
		end)
	)
	table.insert(
		self.connections,
		UserInputService.InputChanged:Connect(function(
			input: InputObject,
			gameProcessed: boolean
		)
			if not self.ghostMode or gameProcessed then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				self.yaw -= input.Delta.X * MOUSE_SENSITIVITY
				self.pitch = math.clamp(
					self.pitch - input.Delta.Y * MOUSE_SENSITIVITY,
					-math.rad(85),
					math.rad(85)
				)
			elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
				self.stickMove = Vector2.new(input.Position.X, input.Position.Y)
			elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
				self.stickLook = Vector2.new(input.Position.X, input.Position.Y)
			elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
				self.leftTrigger = finiteFraction(input.Position.Z)
			elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
				self.rightTrigger = finiteFraction(input.Position.Z)
			end
		end)
	)
	table.insert(
		self.connections,
		RunService.RenderStepped:Connect(function(deltaTime: number)
			self:_step(deltaTime)
		end)
	)

	return self
end

function CameraController:_flickerNearestLight()
	if not self.ghostMode or os.clock() - self.lastFlickerAt < FLICKER_COOLDOWN then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local nearest: Light? = nil
	local nearestDistance = FLICKER_RANGE
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("PointLight")
			or descendant:IsA("SpotLight")
			or descendant:IsA("SurfaceLight")
		then
			local position = lightPosition(descendant)
			if position then
				local distance = (position - camera.CFrame.Position).Magnitude
				if distance <= nearestDistance then
					nearest = descendant
					nearestDistance = distance
				end
			end
		end
	end
	if not nearest then
		return
	end
	self.lastFlickerAt = os.clock()
	local light = nearest :: Light
	local brightness = light.Brightness
	local fadeOut = TweenService:Create(
		light,
		TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Brightness = 0 }
	)
	fadeOut.Completed:Connect(function(playbackState: Enum.PlaybackState)
		if playbackState ~= Enum.PlaybackState.Completed or not light.Parent then
			return
		end
		TweenService:Create(
			light,
			TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{ Brightness = brightness }
		):Play()
	end)
	fadeOut:Play()
end

function CameraController:_step(deltaTime: number)
	if self.destroyed or not self.ghostMode then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	self.yaw -= self.stickLook.X * STICK_LOOK_SPEED * deltaTime
	self.pitch = math.clamp(
		self.pitch + self.stickLook.Y * STICK_LOOK_SPEED * deltaTime,
		-math.rad(85),
		math.rad(85)
	)

	local horizontal = Vector2.new(
		(if self.keyboardMove[Enum.KeyCode.D] then 1 else 0)
			- (if self.keyboardMove[Enum.KeyCode.A] then 1 else 0),
		(if self.keyboardMove[Enum.KeyCode.W] then 1 else 0)
			- (if self.keyboardMove[Enum.KeyCode.S] then 1 else 0)
	) + self.stickMove
	local vertical = (if self.keyboardMove[Enum.KeyCode.E] then 1 else 0)
		- (if self.keyboardMove[Enum.KeyCode.Q] then 1 else 0)
		+ self.rightTrigger
		- self.leftTrigger
	if horizontal.Magnitude > 1 then
		horizontal = horizontal.Unit
	end
	vertical = math.clamp(vertical, -1, 1)

	local yawFrame = CFrame.fromOrientation(0, self.yaw, 0)
	local direction = yawFrame.RightVector * horizontal.X
		+ yawFrame.LookVector * horizontal.Y
		+ Vector3.yAxis * vertical
	if direction.Magnitude > 1 then
		direction = direction.Unit
	end
	local speed = if self.keyboardSprint or self.gamepadSprint
		then SPRINT_SPEED
		else WALK_SPEED
	local candidate = self.position + direction * speed * math.min(deltaTime, 0.1)
	local minimumY = math.min(groundHeight(candidate), MAXIMUM_ALTITUDE)
	self.position = Vector3.new(
		candidate.X,
		math.clamp(candidate.Y, minimumY, MAXIMUM_ALTITUDE),
		candidate.Z
	)
	camera.CFrame = CFrame.new(self.position)
		* CFrame.fromOrientation(self.pitch, self.yaw, 0)
end

function CameraController:SetGhostMode(active: boolean)
	if self.destroyed or self.ghostMode == active then
		return
	end
	self.ghostMode = active
	table.clear(self.keyboardMove)
	self.stickMove = Vector2.zero
	self.stickLook = Vector2.zero
	self.leftTrigger = 0
	self.rightTrigger = 0
	self.keyboardSprint = false
	self.gamepadSprint = false
	local camera = Workspace.CurrentCamera
	if active then
		if camera then
			self.position = camera.CFrame.Position
			local pitch, yaw = camera.CFrame:ToOrientation()
			self.pitch = pitch
			self.yaw = yaw
			camera.CameraType = Enum.CameraType.Scriptable
		end
		self.previousMouseBehavior = UserInputService.MouseBehavior
		self.previousMouseIconEnabled = UserInputService.MouseIconEnabled
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			local character = Players.LocalPlayer.Character
			local humanoid = if character
				then character:FindFirstChildOfClass("Humanoid")
				else nil
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
		UserInputService.MouseBehavior = self.previousMouseBehavior
		UserInputService.MouseIconEnabled = self.previousMouseIconEnabled
	end
end

function CameraController:SetMonsterDread(fraction: number)
	if self.destroyed then
		return
	end
	local resolved = finiteFraction(fraction)
	if resolved <= 0.7 then
		return
	end
	local now = os.clock()
	if now - self.lastRumbleAt < RUMBLE_COOLDOWN then
		return
	end
	local connected = false
	for _, inputType in UserInputService:GetConnectedGamepads() do
		if inputType == Enum.UserInputType.Gamepad1 then
			connected = true
			break
		end
	end
	if not connected then
		return
	end
	local supported = false
	pcall(function()
		supported = HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1)
			and HapticService:IsMotorSupported(
				Enum.UserInputType.Gamepad1,
				Enum.VibrationMotor.Large
			)
	end)
	if not supported then
		return
	end
	self.lastRumbleAt = now
	self.rumbleToken += 1
	local token = self.rumbleToken
	pcall(function()
		HapticService:SetMotor(
			Enum.UserInputType.Gamepad1,
			Enum.VibrationMotor.Large,
			resolved * 0.4
		)
	end)
	task.delay(0.1, function()
		if self.destroyed or token ~= self.rumbleToken then
			return
		end
		pcall(function()
			HapticService:SetMotor(
				Enum.UserInputType.Gamepad1,
				Enum.VibrationMotor.Large,
				0
			)
		end)
	end)
end

function CameraController:Destroy()
	if self.destroyed then
		return
	end
	self:SetGhostMode(false)
	self.destroyed = true
	self.rumbleToken += 1
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	pcall(function()
		HapticService:SetMotor(
			Enum.UserInputType.Gamepad1,
			Enum.VibrationMotor.Large,
			0
		)
	end)
end

return CameraController
