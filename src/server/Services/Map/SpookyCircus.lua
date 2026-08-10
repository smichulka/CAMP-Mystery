--!strict

-- SPOOKY CIRCUS: opt-in night attraction in the northeast frontier meadow
-- (grounds x 150..218, z 240..380; the boundary-dome hillside east of x 220
-- is the natural back fence). By day it stands dormant and creepy; at night
-- the lights come up, the rides turn, the big-top show runs, and carnie
-- monsters patrol the midway.
--
-- Sign-up is diegetic: the ticket booth prompt stamps a CircusTicket
-- attribute on your character and welds on a glowing wristband. Carnies
-- chase ONLY ticket holders; a catch is a jump-scare escort back to the
-- gate (no damage — the murder mystery keeps the lethal stakes).
--
-- Creator Store models (vetted, script-stripped — see docs/CIRCUS_ASSETS.md)
-- are cloned from ServerStorage.ServerAssets.Circus by name; every piece has
-- a procedural fallback so the game boots identically without them.
--
--   SpookyCircus.Build(dayCamp)  -- after terrain; parents under dayCamp
--   SpookyCircus.Start()         -- once at server start; night loops
--   SpookyCircus.SetNight(bool)  -- from ProductionMapService:SetNight

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local WorldKit = require(script.Parent:WaitForChild("WorldKit"))
local TerrainDomes = require(script.Parent:WaitForChild("TerrainDomes"))
local CircusAudioDefaults = require(
	script.Parent.Parent.Parent:WaitForChild("Config"):WaitForChild("CircusAudioDefaults")
)

local TENT_RED = Color3.fromRGB(122, 40, 46)
local TENT_CREAM = Color3.fromRGB(206, 192, 160)
local WOOD_DARK = Color3.fromRGB(58, 42, 30)
local WOOD_MID = Color3.fromRGB(88, 64, 42)
local IRON_DARK = Color3.fromRGB(52, 52, 58)
local GLOW_GREEN = Color3.fromRGB(126, 226, 148)
local GLOW_PURPLE = Color3.fromRGB(168, 108, 226)
local GLOW_AMBER = Color3.fromRGB(255, 196, 110)
local DIRT = Color3.fromRGB(96, 78, 56)
local BONE_WHITE = Color3.fromRGB(222, 216, 200)

local GATE_POSITION = Vector3.new(162, 0, 258)
local TICKET_ATTRIBUTE = "CircusTicket"

type Carnie = {
	model: Model,
	root: BasePart,
	waypoints: { Vector3 },
	waypointIndex: number,
}

local state = {
	built = false,
	started = false,
	nightActive = false,
	circusFolder = nil :: Model?,
	gateDropOff = Vector3.new(158, 6, 252),
	ferrisWheel = nil :: Model?,
	ferrisBaskets = {} :: { { model: Model, radius: number, phase: number, axleX: number, rotation: CFrame } },
	ferrisAxle = nil :: CFrame?,
	ferrisWheelOffset = nil :: CFrame?,
	carousel = nil :: Model?,
	carouselPivot = nil :: CFrame?,
	showStage = nil :: Model?,
	spotlight = nil :: SpotLight?,
	performer = nil :: Model?,
	carnies = {} :: { Carnie },
	calliopeSound = nil :: Sound?,
}

-- Rendered-surface seat (the standard pack pattern): raycast with a brief
-- retry for boot-time chunk lag, TerrainDomes analytic model as fallback.
local seatRayParams = RaycastParams.new()
seatRayParams.FilterType = Enum.RaycastFilterType.Include

local function groundY(x: number, z: number): number
	seatRayParams.FilterDescendantsInstances = { Workspace.Terrain }
	for _ = 1, 8 do
		local hit = Workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -240, 0), seatRayParams)
		if hit then
			if hit.Material == Enum.Material.Water then
				break
			end
			return hit.Position.Y
		end
		task.wait(0.25)
	end
	return TerrainDomes.heightAt(x, z)
end

local function cloneCircusAsset(name: string): Model?
	local assets = ServerStorage:FindFirstChild("ServerAssets")
	local folder = if assets then assets:FindFirstChild("Circus") else nil
	local source = if folder then folder:FindFirstChild(name) else nil
	return if source and source:IsA("Model") then source:Clone() else nil
end

-- SoundService attribute override -> CircusAudioDefaults -> silent (the
-- repo-wide audio resolution contract; ids stay in the Config module).
local function resolveCircusSound(slot: string): string
	local override = SoundService:GetAttribute("Circus" .. slot .. "AssetId")
	if type(override) == "number" and override > 0 then
		return "rbxassetid://" .. tostring(override)
	elseif type(override) == "string" and override ~= "" then
		return override
	end
	return CircusAudioDefaults[slot] or ""
end

local function playCircusSound(part: BasePart, slot: string, volume: number)
	local soundId = resolveCircusSound(slot)
	if soundId == "" then
		return
	end
	local sound = part:FindFirstChild("Circus" .. slot)
	if not (sound and sound:IsA("Sound")) then
		sound = Instance.new("Sound")
		sound.Name = "Circus" .. slot
		sound.SoundId = soundId
		sound.Volume = volume
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 10
		sound.RollOffMaxDistance = 120
		sound.Parent = part
	end
	local soundInstance = sound :: Sound
	soundInstance.PlaybackSpeed = 0.94 + math.random() * 0.12
	soundInstance:Play()
end

-- GROUNDS ---------------------------------------------------------------------

local function buildGateAndFence(circus: Model)
	local gx, gz = GATE_POSITION.X, GATE_POSITION.Z
	local ground = groundY(gx, gz)
	state.gateDropOff = Vector3.new(gx - 4, ground + 3.5, gz - 6)
	local gateCF = CFrame.new(gx, ground, gz) * CFrame.Angles(0, math.rad(-142), 0)

	for side = -1, 1, 2 do
		WorldKit.part(circus, "CircusGatePost", Vector3.new(1.2, 12, 1.2),
			gateCF * CFrame.new(side * 6.5, 6, 0), IRON_DARK, Enum.Material.Metal)
		local skull = WorldKit.part(circus, "GateSkull", Vector3.new(1.1, 1.1, 1.1),
			gateCF * CFrame.new(side * 6.5, 12.5, 0), BONE_WHITE, Enum.Material.SmoothPlastic,
			Enum.PartType.Ball)
		skull.CanCollide = false
	end
	local arch = WorldKit.part(circus, "CircusGateArch", Vector3.new(14.6, 1.6, 0.9),
		gateCF * CFrame.new(0, 12.6, 0), IRON_DARK, Enum.Material.Metal)
	local sign = WorldKit.part(circus, "CircusGateSign", Vector3.new(11, 2.4, 0.4),
		gateCF * CFrame.new(0, 10.6, 0), WOOD_DARK, Enum.Material.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(560, 130)
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Creepster
	label.Text = "MIDNIGHT CIRCUS"
	label.TextColor3 = GLOW_GREEN
	label.TextScaled = true
	label.Parent = gui
	local signLamp = WorldKit.part(circus, "GateSignLamp", Vector3.new(0.6, 0.6, 0.6),
		gateCF * CFrame.new(0, 13.8, 0), GLOW_GREEN, Enum.Material.Neon, Enum.PartType.Ball)
	signLamp.CanCollide = false
	WorldKit.lamp(signLamp, { color = GLOW_GREEN, brightness = 1.4, range = 26 })

	-- Fence: pickets along the south and west edges (the hillside walls the
	-- east and the big top anchors the north)
	local fenceRuns: { { number } } = {
		-- { fromX, fromZ, toX, toZ }
		{ 150, 262, 156, 256 },
		{ 168, 252, 216, 244 },
		{ 150, 262, 150, 370 },
	}
	for _, run in fenceRuns do
		local fromX, fromZ, toX, toZ = run[1], run[2], run[3], run[4]
		local length = math.sqrt((toX - fromX) ^ 2 + (toZ - fromZ) ^ 2)
		local posts = math.max(1, math.floor(length / 6))
		for post = 0, posts do
			local alpha = post / posts
			local x = fromX + (toX - fromX) * alpha
			local z = fromZ + (toZ - fromZ) * alpha
			WorldKit.part(circus, "CircusFencePost", Vector3.new(0.5, 5, 0.5),
				CFrame.new(x, groundY(x, z) + 2.3, z) * CFrame.Angles(0, math.random() * 0.3, math.rad(math.random(-6, 6))),
				IRON_DARK, Enum.Material.Metal)
		end
	end

	-- Approach trail: gate down to the creek footbridge's east end
	local trailPoints = { Vector2.new(gx - 3, gz - 5), Vector2.new(148, 235), Vector2.new(138, 220) }
	for index = 1, #trailPoints - 1 do
		local fromPoint = trailPoints[index]
		local toPoint = trailPoints[index + 1]
		local span = toPoint - fromPoint
		local segments = math.max(1, math.floor(span.Magnitude / 6.5))
		for segment = 0, segments do
			local alpha = segment / segments
			local x = fromPoint.X + span.X * alpha
			local z = fromPoint.Y + span.Y * alpha
			local strip = WorldKit.part(circus, "CircusTrailStrip", Vector3.new(2.4, 0.12, 7),
				CFrame.new(x, groundY(x, z) + 0.08, z)
					* CFrame.Angles(0, math.atan2(span.X, span.Y) + (segment % 3 - 1) * 0.06, 0),
				DIRT, Enum.Material.Ground)
			strip.CanCollide = false
		end
	end

	-- Midway dirt path: gate -> carousel -> big top
	local midwayPoints = { Vector2.new(gx + 3, gz + 5), Vector2.new(180, 288), Vector2.new(190, 318), Vector2.new(195, 336) }
	for index = 1, #midwayPoints - 1 do
		local fromPoint = midwayPoints[index]
		local toPoint = midwayPoints[index + 1]
		local span = toPoint - fromPoint
		local segments = math.max(1, math.floor(span.Magnitude / 6))
		for segment = 0, segments do
			local alpha = segment / segments
			local x = fromPoint.X + span.X * alpha
			local z = fromPoint.Y + span.Y * alpha
			local strip = WorldKit.part(circus, "MidwayStrip", Vector3.new(3.4, 0.12, 6.4),
				CFrame.new(x, groundY(x, z) + 0.08, z)
					* CFrame.Angles(0, math.atan2(span.X, span.Y), 0),
				DIRT, Enum.Material.Ground)
			strip.CanCollide = false
		end
	end

	WorldKit.signpost(circus, Vector3.new(140, groundY(140, 222), 222),
		{ "MIDNIGHT CIRCUS", "IF YOU DARE" })
end

-- TICKET BOOTH ---------------------------------------------------------------

local function removeWristband(character: Model)
	local band = character:FindFirstChild("CircusWristband")
	if band then
		band:Destroy()
	end
end

local function attachWristband(character: Model)
	removeWristband(character)
	local arm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
		or character:FindFirstChild("HumanoidRootPart")
	if not (arm and arm:IsA("BasePart")) then
		return
	end
	local band = Instance.new("Part")
	band.Name = "CircusWristband"
	band.Size = Vector3.new(1.15, 0.24, 1.15)
	band.Color = GLOW_GREEN
	band.Material = Enum.Material.Neon
	band.CanCollide = false
	band.CanQuery = false
	band.Massless = true
	band.CFrame = arm.CFrame * CFrame.new(0, -0.6, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = arm
	weld.Part1 = band
	weld.Parent = band
	band.Parent = character
end

local function buildTicketBooth(circus: Model)
	local bx, bz = 170, 266
	local ground = groundY(bx, bz)
	local boothCF = CFrame.new(bx, ground, bz) * CFrame.Angles(0, math.rad(-135), 0)

	WorldKit.part(circus, "BoothBase", Vector3.new(5, 4.2, 4),
		boothCF * CFrame.new(0, 2.1, 0), TENT_RED, Enum.Material.WoodPlanks)
	WorldKit.part(circus, "BoothRoof", Vector3.new(6, 0.5, 5),
		boothCF * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, 0, math.rad(4)),
		TENT_CREAM, Enum.Material.Fabric)
	local counter = WorldKit.part(circus, "BoothCounter", Vector3.new(5.2, 0.4, 1.2),
		boothCF * CFrame.new(0, 2.9, 2.4), WOOD_DARK, Enum.Material.WoodPlanks)
	local lamp = WorldKit.part(circus, "BoothLamp", Vector3.new(0.6, 0.6, 0.6),
		boothCF * CFrame.new(0, 5.3, 0), GLOW_AMBER, Enum.Material.Neon, Enum.PartType.Ball)
	lamp.CanCollide = false
	WorldKit.lamp(lamp, { color = GLOW_AMBER, brightness = 1.1, range = 18 })

	local prompt = WorldKit.prompt(counter, "Take a Ticket", "Midnight Circus", 0.45)
	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		if not character then
			return
		end
		local hasTicket = character:GetAttribute(TICKET_ATTRIBUTE) == true
		if hasTicket then
			character:SetAttribute(TICKET_ATTRIBUTE, nil)
			removeWristband(character)
			prompt.ActionText = "Take a Ticket"
		else
			character:SetAttribute(TICKET_ATTRIBUTE, true)
			attachWristband(character)
			prompt.ActionText = "Return Ticket"
			playCircusSound(counter, "TicketChime", 0.7)
		end
	end)
end

-- BIG TOP + SHOW --------------------------------------------------------------

local function buildProceduralTent(circus: Model, at: CFrame): Model
	local tent = WorldKit.model(circus, "CircusTentFallback")
	local base = WorldKit.part(tent, "TentWall", Vector3.new(3, 14, 40),
		at * CFrame.new(0, 7, 0), TENT_RED, Enum.Material.Fabric, Enum.PartType.Cylinder)
	base.CFrame = at * CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.rad(90))
	local cone = Instance.new("WedgePart")
	cone.Name = "TentRoof"
	cone.Anchored = true
	cone.Size = Vector3.new(40, 12, 40)
	cone.CFrame = at * CFrame.new(0, 20, 0)
	cone.Color = TENT_CREAM
	cone.Material = Enum.Material.Fabric
	cone.Parent = tent
	return tent
end

local function buildBigTop(circus: Model)
	local tx, tz = 195, 348
	local ground = groundY(tx, tz)
	local tentCF = CFrame.new(tx, ground, tz) * CFrame.Angles(0, math.rad(180), 0)

	local tent = cloneCircusAsset("CircusTent")
	if tent then
		tent:ScaleTo(0.25)
		local _, size = tent:GetBoundingBox()
		tent:PivotTo(tentCF * CFrame.new(0, size.Y / 2 - 1, 0))
		tent.Name = "CircusBigTop"
		tent.Parent = circus
	else
		buildProceduralTent(circus, tentCF)
	end

	-- Show ring inside/in front of the tent mouth: ring, stage, benches
	local stage = WorldKit.model(circus, "CircusShowStage")
	state.showStage = stage
	local ringCF = CFrame.new(tx, ground, tz - 14)
	for stone = 1, 10 do
		local angle = stone / 10 * math.pi * 2
		WorldKit.part(stage, "RingBlock", Vector3.new(1.4, 0.9, 1.4),
			ringCF * CFrame.new(math.cos(angle) * 7, 0.9, math.sin(angle) * 7)
				* CFrame.Angles(0, angle, 0),
			TENT_RED, Enum.Material.WoodPlanks)
	end
	local platform = WorldKit.part(stage, "ShowPlatform", Vector3.new(6, 1, 6),
		ringCF * CFrame.new(0, 1, 0), WOOD_MID, Enum.Material.WoodPlanks)
	-- Benches facing the ring from the south
	for row = 1, 3 do
		WorldKit.part(stage, "ShowBench" .. row, Vector3.new(12, 0.5, 1.4),
			ringCF * CFrame.new(0, 0.9 + (row - 1) * 0.5, -11 - row * 2.2),
			WOOD_DARK, Enum.Material.WoodPlanks)
	end
	-- Spotlight rig over the stage (SpotLight swept during shows)
	local rigPole = WorldKit.part(stage, "SpotRigPole", Vector3.new(0.5, 13, 0.5),
		ringCF * CFrame.new(9, 6.5, -9), IRON_DARK, Enum.Material.Metal)
	local rigHead = WorldKit.part(stage, "SpotRigHead", Vector3.new(1.1, 1.1, 1.6),
		ringCF * CFrame.new(8.4, 12.8, -8.4) * CFrame.Angles(math.rad(-40), math.rad(45), 0),
		IRON_DARK, Enum.Material.Metal)
	rigHead.CanCollide = false
	local spot = Instance.new("SpotLight")
	spot.Angle = 34
	spot.Brightness = 4
	spot.Range = 34
	spot.Color = GLOW_PURPLE
	spot.Enabled = false
	spot.Face = Enum.NormalId.Front
	spot.Parent = rigHead
	state.spotlight = spot

	-- Performer: a still, wrong-looking ringmaster that dances at showtime
	local performer = WorldKit.model(stage, "CircusRingmaster")
	state.performer = performer
	local rootCF = CFrame.new(tx, ground + 3.2, tz - 14)
	local torso = WorldKit.part(performer, "RingmasterTorso", Vector3.new(1.8, 2.4, 1.1),
		rootCF, TENT_RED, Enum.Material.Fabric)
	performer.PrimaryPart = torso
	WorldKit.part(performer, "RingmasterHead", Vector3.new(1.2, 1.2, 1.2),
		rootCF * CFrame.new(0, 1.9, 0), BONE_WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	local hat = WorldKit.part(performer, "RingmasterHat", Vector3.new(1.0, 1.4, 1.0),
		rootCF * CFrame.new(0, 3.0, 0), IRON_DARK, Enum.Material.Fabric, Enum.PartType.Cylinder)
	hat.CFrame = rootCF * CFrame.new(0, 3.0, 0) * CFrame.Angles(0, 0, math.rad(90))
	for side = -1, 1, 2 do
		WorldKit.part(performer, "RingmasterArm", Vector3.new(0.5, 2.2, 0.5),
			rootCF * CFrame.new(side * 1.25, 0, 0) * CFrame.Angles(0, 0, side * math.rad(18)),
			TENT_RED, Enum.Material.Fabric)
		local eye = WorldKit.part(performer, "RingmasterEye", Vector3.new(0.22, 0.22, 0.22),
			rootCF * CFrame.new(side * 0.26, 2.05, -0.5), GLOW_GREEN, Enum.Material.Neon,
			Enum.PartType.Ball)
		eye.CanCollide = false
	end
	WorldKit.part(performer, "RingmasterLegs", Vector3.new(1.6, 2.0, 1.0),
		rootCF * CFrame.new(0, -2.2, 0), IRON_DARK, Enum.Material.Fabric)

	-- Calliope loop source at the tent mouth (Started/stopped with night)
	local calliopeId = resolveCircusSound("Calliope")
	if calliopeId ~= "" then
		local speaker = WorldKit.part(stage, "CalliopeSpeaker", Vector3.new(1.4, 1.8, 1.2),
			ringCF * CFrame.new(-8, 1.9, -8), WOOD_DARK, Enum.Material.Wood)
		local sound = Instance.new("Sound")
		sound.Name = "CircusCalliope"
		sound.SoundId = calliopeId
		sound.Looped = true
		sound.Volume = 0.5
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 12
		sound.RollOffMaxDistance = 140
		sound.PlaybackSpeed = 0.82 -- slowed = warped and wrong
		sound.Parent = speaker
		state.calliopeSound = sound
	end
end

-- RIDES ------------------------------------------------------------------------

local function buildProceduralFerris(circus: Model, at: CFrame)
	local wheel = WorldKit.model(circus, "FerrisWheelFallback")
	for side = -1, 1, 2 do
		WorldKit.part(wheel, "FerrisLeg", Vector3.new(1.2, 26, 1.2),
			at * CFrame.new(side * 6, 13, 0) * CFrame.Angles(0, 0, side * math.rad(-14)),
			IRON_DARK, Enum.Material.Metal)
	end
	local hub = WorldKit.model(wheel, "FerrisHub")
	for spoke = 1, 8 do
		local angle = spoke / 8 * math.pi * 2
		WorldKit.part(hub, "FerrisSpoke", Vector3.new(0.5, 22, 0.5),
			at * CFrame.new(0, 24, 0) * CFrame.Angles(angle, 0, 0)
				* CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(90), 0, 0),
			IRON_DARK, Enum.Material.Metal)
	end
	state.ferrisWheel = hub
	state.ferrisAxle = at * CFrame.new(0, 24, 0)
end

local function buildFerrisWheel(circus: Model)
	local fx, fz = 198, 300
	local ground = groundY(fx, fz)
	-- Wheel plane faces the midway (west): the model's 71-stud span runs
	-- along world Z, its 34-stud depth along X.
	local wheelCF = CFrame.new(fx, ground, fz) * CFrame.Angles(0, math.rad(90), 0)

	local model = cloneCircusAsset("FerrisWheel")
	if not model then
		buildProceduralFerris(circus, wheelCF)
		return
	end
	local _, size = model:GetBoundingBox()
	model:PivotTo(wheelCF * CFrame.new(0, size.Y / 2 - 0.5, 0))
	model.Name = "CircusFerrisWheel"
	model.Parent = circus
	state.ferrisWheel = nil
	state.ferrisAxle = nil

	local inner = model:FindFirstChild("Ferris Wheel")
	local wheelAssembly = inner and inner:FindFirstChild("Wheel")
	local baskets = inner and inner:FindFirstChild("Baskets")
	if wheelAssembly and wheelAssembly:IsA("Model") then
		local wheelCFNow = wheelAssembly:GetBoundingBox()
		-- Axle: wheel bbox center, axis along the model's depth (world X
		-- after the 90-degree yaw above)
		state.ferrisAxle = CFrame.new(wheelCFNow.Position)
		state.ferrisWheel = wheelAssembly
		-- Original pivot offset in axle space, captured ONCE: re-deriving it
		-- from the live pivot every tick would compound rotation into drift.
		state.ferrisWheelOffset = (state.ferrisAxle :: CFrame):ToObjectSpace(wheelAssembly:GetPivot())
	end
	state.ferrisBaskets = {}
	if baskets and state.ferrisAxle then
		local axle = state.ferrisAxle :: CFrame
		for _, basket in baskets:GetChildren() do
			if basket:IsA("Model") then
				local pivot = basket:GetPivot()
				local offset = axle:PointToObjectSpace(pivot.Position)
				local radius = math.sqrt(offset.Y ^ 2 + offset.Z ^ 2)
				local phase = math.atan2(offset.Y, offset.Z)
				table.insert(state.ferrisBaskets, {
					model = basket,
					radius = radius,
					phase = phase,
					axleX = offset.X,
					rotation = pivot.Rotation,
				})
			end
		end
	end
end

local function buildCarousel(circus: Model)
	local cx, cz = 170, 312
	local ground = groundY(cx, cz)
	local baseCF = CFrame.new(cx, ground, cz)

	local model = cloneCircusAsset("Carousel")
	if model then
		local _, size = model:GetBoundingBox()
		model:PivotTo(baseCF * CFrame.new(0, size.Y / 2 - 0.5, 0))
		model.Name = "CircusCarousel"
		model.Parent = circus
		local inner = model:FindFirstChild("Carousel")
		if inner and inner:IsA("Model") then
			state.carousel = inner
			state.carouselPivot = inner:GetPivot()
		end
		return
	end
	-- Fallback: pole + canopy disc + 4 seat posts
	local carousel = WorldKit.model(circus, "CarouselFallback")
	WorldKit.part(carousel, "CarouselPole", Vector3.new(1, 12, 1),
		baseCF * CFrame.new(0, 6, 0), IRON_DARK, Enum.Material.Metal)
	local disc = WorldKit.part(carousel, "CarouselCanopy", Vector3.new(1, 16, 16),
		baseCF * CFrame.new(0, 11.5, 0), TENT_RED, Enum.Material.Fabric, Enum.PartType.Cylinder)
	disc.CFrame = baseCF * CFrame.new(0, 11.5, 0) * CFrame.Angles(0, 0, math.rad(90))
	local spinner = WorldKit.model(carousel, "CarouselSpinner")
	for seat = 1, 4 do
		local angle = seat / 4 * math.pi * 2
		WorldKit.part(spinner, "CarouselSeatPost", Vector3.new(0.4, 9, 0.4),
			baseCF * CFrame.new(math.cos(angle) * 6, 6.5, math.sin(angle) * 6),
			GLOW_AMBER, Enum.Material.Metal)
		WorldKit.part(spinner, "CarouselSeat", Vector3.new(1.6, 0.4, 1.6),
			baseCF * CFrame.new(math.cos(angle) * 6, 3, math.sin(angle) * 6),
			WOOD_MID, Enum.Material.WoodPlanks)
	end
	state.carousel = spinner
	state.carouselPivot = spinner:GetPivot()
end

-- GAMES (native, archery-minigame pattern) ------------------------------------

local function buildGameBooth(
	circus: Model,
	name: string,
	position: Vector3,
	signText: string,
	glow: Color3
): (Model, BasePart, CFrame)
	local booth = WorldKit.model(circus, name)
	local ground = groundY(position.X, position.Z)
	local boothCF = CFrame.new(position.X, ground, position.Z) * CFrame.Angles(0, math.rad(135), 0)
	for side = -1, 1, 2 do
		WorldKit.part(booth, "BoothPost", Vector3.new(0.5, 6.4, 0.5),
			boothCF * CFrame.new(side * 3.6, 3.1, -1.8), WOOD_DARK, Enum.Material.Wood)
	end
	WorldKit.part(booth, "BoothCanopy", Vector3.new(8.4, 0.4, 4.6),
		boothCF * CFrame.new(0, 6.5, -1.4) * CFrame.Angles(math.rad(-8), 0, 0),
		TENT_RED, Enum.Material.Fabric)
	local counter = WorldKit.part(booth, "BoothCounter", Vector3.new(7.6, 1, 1.1),
		boothCF * CFrame.new(0, 2.2, 0.4), WOOD_MID, Enum.Material.WoodPlanks)
	local sign = WorldKit.part(booth, "BoothSign", Vector3.new(6.4, 1.2, 0.3),
		boothCF * CFrame.new(0, 7.4, -1.4), WOOD_DARK, Enum.Material.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(420, 80)
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Creepster
	label.Text = signText
	label.TextColor3 = glow
	label.TextScaled = true
	label.Parent = gui
	return booth, counter, boothCF
end

local function buildGames(circus: Model)
	-- 1. Bottle toss: three bottle stacks, a lobbed ball scatters one
	do
		local booth, counter, boothCF = buildGameBooth(
			circus, "BottleTossBooth", Vector3.new(180, 0, 272), "BOTTLE SMASH", GLOW_AMBER)
		local stacks: { { BasePart } } = {}
		for stackIndex = -1, 1 do
			local stack: { BasePart } = {}
			local baseCF = boothCF * CFrame.new(stackIndex * 2.2, 2.9, -1.4)
			for level = 1, 3 do
				local count = 4 - level
				for b = 1, count do
					local bottle = WorldKit.part(booth, "TossBottle", Vector3.new(0.45, 1.1, 0.45),
						baseCF * CFrame.new((b - (count + 1) / 2) * 0.6, (level - 1) * 1.1, 0),
						BONE_WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
					bottle.CFrame = baseCF * CFrame.new((b - (count + 1) / 2) * 0.6, (level - 1) * 1.1, 0)
					table.insert(stack, bottle)
				end
			end
			table.insert(stacks, stack)
		end
		local busy = false
		local prompt = WorldKit.prompt(counter, "Throw a Ball", "Bottle Smash", 0.3)
		prompt.Triggered:Connect(function(_player: Player)
			if busy then
				return
			end
			busy = true
			local stack = stacks[math.random(1, #stacks)]
			local originals: { [BasePart]: CFrame } = {}
			for _, bottle in stack do
				originals[bottle] = bottle.CFrame
				local fling = TweenService:Create(bottle, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = bottle.CFrame
						* CFrame.new(math.random(-3, 3), math.random(1, 3), -math.random(2, 4))
						* CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3),
				})
				fling:Play()
			end
			task.delay(2.2, function()
				for bottle, cframe in originals do
					if bottle.Parent then
						bottle.CFrame = cframe
					end
				end
				busy = false
			end)
		end)
	end
	-- 2. High striker: puck races up the tower, bell flashes
	do
		local booth, counter, boothCF = buildGameBooth(
			circus, "HighStrikerBooth", Vector3.new(188, 0, 282), "TEST YOUR DOOM", GLOW_PURPLE)
		WorldKit.part(booth, "StrikerTower", Vector3.new(0.8, 11, 0.8),
			boothCF * CFrame.new(0, 5.6, -1.6), IRON_DARK, Enum.Material.Metal)
		local bell = WorldKit.part(booth, "StrikerBell", Vector3.new(1.3, 1.3, 1.3),
			boothCF * CFrame.new(0, 11.6, -1.6), GLOW_AMBER, Enum.Material.Neon, Enum.PartType.Ball)
		bell.CanCollide = false
		local puck = WorldKit.part(booth, "StrikerPuck", Vector3.new(1.1, 0.5, 1.1),
			boothCF * CFrame.new(0, 1.4, -1.6), TENT_RED, Enum.Material.Neon, Enum.PartType.Cylinder)
		puck.CFrame = boothCF * CFrame.new(0, 1.4, -1.6)
		puck.CanCollide = false
		local restCF = puck.CFrame
		local busy = false
		local prompt = WorldKit.prompt(counter, "Swing the Mallet", "High Striker", 0.35)
		prompt.Triggered:Connect(function(_player: Player)
			if busy then
				return
			end
			busy = true
			local strength = 0.45 + math.random() * 0.55
			local up = TweenService:Create(puck, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = restCF * CFrame.new(0, 9.6 * strength, 0),
			})
			up:Play()
			up.Completed:Once(function()
				if strength > 0.92 then
					local flash = TweenService:Create(bell, TweenInfo.new(0.15, Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out, 3, true), { Size = Vector3.new(1.9, 1.9, 1.9) })
					flash:Play()
				end
				local down = TweenService:Create(puck, TweenInfo.new(0.5, Enum.EasingStyle.Bounce,
					Enum.EasingDirection.Out), { CFrame = restCF })
				down:Play()
				down.Completed:Once(function()
					busy = false
				end)
			end)
		end)
	end
	-- 3. Ring toss onto skeleton hands
	do
		local booth, counter, boothCF = buildGameBooth(
			circus, "RingTossBooth", Vector3.new(196, 0, 292), "RING THE BONES", GLOW_GREEN)
		local pegs: { CFrame } = {}
		for pegIndex = -1, 1 do
			local pegCF = boothCF * CFrame.new(pegIndex * 2.0, 3.3, -1.6)
			WorldKit.part(booth, "BonePeg", Vector3.new(0.35, 1.8, 0.35),
				pegCF, BONE_WHITE, Enum.Material.SmoothPlastic)
			table.insert(pegs, pegCF)
		end
		local busy = false
		local prompt = WorldKit.prompt(counter, "Toss a Ring", "Ring Toss", 0.3)
		prompt.Triggered:Connect(function(_player: Player)
			if busy then
				return
			end
			busy = true
			local ring = WorldKit.part(booth, "TossRing", Vector3.new(1.4, 0.18, 1.4),
				(counter :: BasePart).CFrame * CFrame.new(0, 1, 0), GLOW_GREEN,
				Enum.Material.Neon, Enum.PartType.Cylinder)
			ring.CanCollide = false
			local target = pegs[math.random(1, #pegs)]
			local arc = TweenService:Create(ring, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = target * CFrame.new(0, 2.4, 0),
			})
			arc:Play()
			arc.Completed:Once(function()
				local drop = TweenService:Create(ring, TweenInfo.new(0.22, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
					CFrame = target * CFrame.new(0, -0.6 + math.random() * 0.4, 0),
				})
				drop:Play()
			end)
			task.delay(1.6, function()
				if ring.Parent then
					ring:Destroy()
				end
				busy = false
			end)
		end)
	end
	-- Popcorn cart near the gate (vetted store prop; skip silently if absent)
	local popcorn = cloneCircusAsset("PopcornMachine")
	if popcorn then
		popcorn:ScaleTo(0.45)
		local _, size = popcorn:GetBoundingBox()
		popcorn:PivotTo(CFrame.new(168, groundY(168, 272) + size.Y / 2 - 0.3, 272)
			* CFrame.Angles(0, math.rad(60), 0))
		popcorn.Name = "CircusPopcornCart"
		popcorn.Parent = circus
	end
end

-- CARNIES ----------------------------------------------------------------------

local function buildCarnie(circus: Model, index: number, at: Vector3): Carnie
	local carnie = WorldKit.model(circus, "CircusCarnie" .. index)
	local ground = groundY(at.X, at.Z)
	local rootCF = CFrame.new(at.X, ground + 3.4, at.Z)
	local palette = if index % 2 == 0 then GLOW_PURPLE else GLOW_GREEN
	local torso = WorldKit.part(carnie, "CarnieTorso", Vector3.new(2.0, 2.6, 1.2),
		rootCF, IRON_DARK, Enum.Material.Fabric)
	carnie.PrimaryPart = torso
	WorldKit.part(carnie, "CarnieRuff", Vector3.new(2.4, 0.5, 1.6),
		rootCF * CFrame.new(0, 1.45, 0), TENT_CREAM, Enum.Material.Fabric)
	WorldKit.part(carnie, "CarnieHead", Vector3.new(1.3, 1.3, 1.3),
		rootCF * CFrame.new(0, 2.2, 0), BONE_WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	local hat = WorldKit.part(carnie, "CarnieHat", Vector3.new(0.9, 1.6, 0.9),
		rootCF * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, 0, math.rad(8)),
		palette, Enum.Material.Fabric, Enum.PartType.Cylinder)
	hat.CFrame = rootCF * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, 0, math.rad(98))
	for side = -1, 1, 2 do
		local eye = WorldKit.part(carnie, "CarnieEye", Vector3.new(0.26, 0.26, 0.26),
			rootCF * CFrame.new(side * 0.28, 2.35, -0.55), palette, Enum.Material.Neon,
			Enum.PartType.Ball)
		eye.CanCollide = false
		WorldKit.part(carnie, "CarnieArm", Vector3.new(0.55, 2.4, 0.55),
			rootCF * CFrame.new(side * 1.35, -0.1, 0) * CFrame.Angles(0, 0, side * math.rad(24)),
			IRON_DARK, Enum.Material.Fabric)
	end
	WorldKit.part(carnie, "CarnieLegs", Vector3.new(1.7, 2.2, 1.1),
		rootCF * CFrame.new(0, -2.4, 0), palette, Enum.Material.Fabric)
	for _, d in carnie:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return {
		model = carnie,
		root = torso,
		waypoints = {},
		waypointIndex = 1,
	}
end

local function buildCarnies(circus: Model)
	local patrols: { { Vector3 } } = {
		-- Midway loop
		{ Vector3.new(170, 0, 270), Vector3.new(182, 0, 288), Vector3.new(192, 0, 310),
			Vector3.new(180, 0, 322), Vector3.new(166, 0, 300) },
		-- Rides loop
		{ Vector3.new(196, 0, 318), Vector3.new(204, 0, 296), Vector3.new(190, 0, 282),
			Vector3.new(178, 0, 300) },
		-- Big-top prowl
		{ Vector3.new(188, 0, 336), Vector3.new(202, 0, 340), Vector3.new(196, 0, 324),
			Vector3.new(184, 0, 328) },
	}
	for index, waypoints in patrols do
		local carnie = buildCarnie(circus, index, waypoints[1])
		carnie.waypoints = waypoints
		table.insert(state.carnies, carnie)
	end
end

-- NIGHT LOOPS ------------------------------------------------------------------

local function anyPlayerNear(center: Vector3, radius: number): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local offset = root.Position - center
			if Vector3.new(offset.X, 0, offset.Z).Magnitude < radius then
				return true
			end
		end
	end
	return false
end

local FAIRGROUND_CENTER = Vector3.new(190, 4, 300)

local function startRideLoops()
	-- Ferris wheel: rotate the wheel assembly about its axle; baskets orbit
	-- but stay upright. Carousel: spin about its vertical axis. 15 Hz, only
	-- at night with a player within 140 studs (replication tops out ~20 Hz).
	task.spawn(function()
		local theta = 0
		local carouselTheta = 0
		local proximityTimer = 0
		local nearby = false
		while true do
			local dt = task.wait(1 / 15)
			proximityTimer += dt
			if proximityTimer >= 1 then
				proximityTimer = 0
				nearby = anyPlayerNear(FAIRGROUND_CENTER, 140)
			end
			if not state.nightActive or not nearby then
				continue
			end
			local wheel = state.ferrisWheel
			local axle = state.ferrisAxle
			local wheelOffset = state.ferrisWheelOffset
			if wheel and axle and wheel.Parent then
				theta += dt * 0.22
				if wheelOffset then
					wheel:PivotTo(axle * CFrame.Angles(theta, 0, 0) * wheelOffset)
				else
					-- Procedural fallback hub: pivot is centered on the axle
					wheel:PivotTo(axle * CFrame.Angles(theta, 0, 0))
				end
				-- Baskets re-seat on their orbit each tick with their original
				-- upright rotation (never incremental — no drift).
				for _, basket in state.ferrisBaskets do
					if basket.model.Parent then
						local angle = basket.phase + theta
						local position = axle:PointToWorldSpace(Vector3.new(
							basket.axleX,
							math.sin(angle) * basket.radius,
							math.cos(angle) * basket.radius
						))
						basket.model:PivotTo(CFrame.new(position) * basket.rotation)
					end
				end
			end
			local carousel = state.carousel
			local carouselPivot = state.carouselPivot
			if carousel and carouselPivot and carousel.Parent then
				carouselTheta += dt * 0.5
				carousel:PivotTo(carouselPivot * CFrame.Angles(0, carouselTheta, 0))
			end
		end
	end)
end

local function startShowLoop()
	task.spawn(function()
		while true do
			task.wait(math.random(120, 220))
			local performer = state.performer
			local spot = state.spotlight
			if not state.nightActive or not performer or not performer.Parent then
				continue
			end
			if not anyPlayerNear(FAIRGROUND_CENTER, 160) then
				continue
			end
			if spot then
				spot.Enabled = true
			end
			playCircusSound(
				(performer.PrimaryPart :: BasePart),
				"BarkerCall",
				0.8
			)
			-- The ringmaster's routine: slow spin with a bob, 20 seconds
			local baseCF = performer:GetPivot()
			local elapsed = 0
			while elapsed < 20 and state.nightActive and performer.Parent do
				local dt = task.wait(1 / 12)
				elapsed += dt
				performer:PivotTo(baseCF
					* CFrame.Angles(0, elapsed * 0.9, 0)
					* CFrame.new(0, math.sin(elapsed * 2.4) * 0.4, 0))
			end
			if performer.Parent then
				performer:PivotTo(baseCF)
			end
			if spot then
				spot.Enabled = false
			end
		end
	end)
end

local function ticketedCharacterNear(position: Vector3, radius: number): (Model?, BasePart?)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character:GetAttribute(TICKET_ATTRIBUTE) == true then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local offset = root.Position - position
				if Vector3.new(offset.X, 0, offset.Z).Magnitude < radius then
					return character, root
				end
			end
		end
	end
	return nil, nil
end

local function startCarnieLoops()
	for _, carnie in state.carnies do
		task.spawn(function()
			local speed = 5
			local scanTimer = 0
			local target: BasePart? = nil
			local targetCharacter: Model? = nil
			local catchCooldownUntil = 0
			while carnie.model.Parent ~= nil do
				local dt = task.wait(1 / 15)
				if not state.nightActive then
					target = nil
					targetCharacter = nil
					task.wait(1)
					continue
				end
				scanTimer += dt
				if scanTimer >= 0.5 then
					scanTimer = 0
					local currentPosition = carnie.root.Position
					local character, root = ticketedCharacterNear(currentPosition, 34)
					targetCharacter = character
					target = root
				end
				local rootPosition = carnie.root.Position
				local destination: Vector3
				if target and target.Parent and os.clock() >= catchCooldownUntil then
					destination = target.Position
					speed = 8.5
					-- Catch: jump-scare escort back to the gate
					local flat = destination - rootPosition
					if Vector3.new(flat.X, 0, flat.Z).Magnitude < 3.5 then
						local character = targetCharacter
						if character then
							playCircusSound(carnie.root, "CarnieScreech", 1)
							local escortRoot = character:FindFirstChild("HumanoidRootPart")
							if escortRoot and escortRoot:IsA("BasePart") then
								character:PivotTo(CFrame.new(state.gateDropOff)
									* CFrame.Angles(0, math.rad(140), 0))
								escortRoot.Anchored = true
								task.delay(1.5, function()
									if escortRoot.Parent then
										escortRoot.Anchored = false
									end
								end)
							end
						end
						target = nil
						targetCharacter = nil
						catchCooldownUntil = os.clock() + 6
						continue
					end
				else
					speed = 5
					local waypoint = carnie.waypoints[carnie.waypointIndex]
					local flat = waypoint - rootPosition
					if Vector3.new(flat.X, 0, flat.Z).Magnitude < 2.5 then
						carnie.waypointIndex = carnie.waypointIndex % #carnie.waypoints + 1
						waypoint = carnie.waypoints[carnie.waypointIndex]
					end
					destination = waypoint
				end
				local flatOffset = Vector3.new(destination.X - rootPosition.X, 0, destination.Z - rootPosition.Z)
				if flatOffset.Magnitude > 0.5 then
					local stepVector = flatOffset.Unit * math.min(speed * dt, flatOffset.Magnitude)
					local nextPosition = rootPosition + stepVector
					local bob = math.sin(os.clock() * 7) * 0.25
					carnie.model:PivotTo(CFrame.lookAt(
						Vector3.new(nextPosition.X, groundY(nextPosition.X, nextPosition.Z) + 3.4 + bob, nextPosition.Z),
						Vector3.new(destination.X, groundY(nextPosition.X, nextPosition.Z) + 3.4, destination.Z)
					))
				end
			end
		end)
	end
end

-- DRESSING ---------------------------------------------------------------------

local function buildDressing(circus: Model)
	-- String lights along the midway (CampLamp-tagged: they follow night
	-- automatically via ProductionMapService:SetNight's generic lamp sweep)
	local lightRun = { Vector2.new(166, 264), Vector2.new(180, 288), Vector2.new(190, 312), Vector2.new(194, 332) }
	for index = 1, #lightRun - 1 do
		local fromPoint = lightRun[index]
		local toPoint = lightRun[index + 1]
		local span = toPoint - fromPoint
		local segments = math.max(1, math.floor(span.Magnitude / 9))
		for segment = 0, segments do
			local alpha = segment / segments
			local x = fromPoint.X + span.X * alpha + (segment % 2) * 3 - 1.5
			local z = fromPoint.Y + span.Y * alpha
			local ground = groundY(x, z)
			WorldKit.part(circus, "MidwayLightPost", Vector3.new(0.4, 7, 0.4),
				CFrame.new(x, ground + 3.2, z), WOOD_DARK, Enum.Material.Wood)
			local bulbColor = if segment % 2 == 0 then GLOW_PURPLE else GLOW_GREEN
			local bulb = WorldKit.part(circus, "MidwayBulb", Vector3.new(0.55, 0.55, 0.55),
				CFrame.new(x, ground + 6.9, z), bulbColor, Enum.Material.Neon, Enum.PartType.Ball)
			bulb.CanCollide = false
			WorldKit.lamp(bulb, { color = bulbColor, brightness = 1.0, range = 16 })
		end
	end
	-- Ground fog drifting across the midway
	for index, spot in {
		Vector3.new(172, 0, 278), Vector3.new(186, 0, 300),
		Vector3.new(196, 0, 326), Vector3.new(162, 0, 262),
	} do
		local ground = groundY(spot.X, spot.Z)
		local host = WorldKit.part(circus, "CircusFogHost" .. index, Vector3.new(24, 2, 24),
			CFrame.new(spot.X, ground + 1, spot.Z), Color3.fromRGB(255, 255, 255),
			Enum.Material.SmoothPlastic)
		host.Transparency = 1
		host.CanCollide = false
		host.CanQuery = false
		host.CastShadow = false
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(150, 168, 150), Color3.fromRGB(96, 110, 120))
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 4),
			NumberSequenceKeypoint.new(1, 9),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.82),
			NumberSequenceKeypoint.new(0.5, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Rate = 3
		emitter.Speed = NumberRange.new(0.4, 1.2)
		emitter.Lifetime = NumberRange.new(5, 9)
		emitter.SpreadAngle = Vector2.new(8, 8)
		emitter.LightEmission = 0.05
		emitter.Parent = host
	end
end

-- PUBLIC -----------------------------------------------------------------------

local SpookyCircus = {}

function SpookyCircus.Build(dayCamp: Instance, _nightTown: Instance)
	if state.built then
		return
	end
	state.built = true
	local circus = WorldKit.model(dayCamp, "SpookyCircus")
	state.circusFolder = circus
	buildGateAndFence(circus)
	buildTicketBooth(circus)
	buildBigTop(circus)
	buildFerrisWheel(circus)
	buildCarousel(circus)
	buildGames(circus)
	buildCarnies(circus)
	buildDressing(circus)
end

function SpookyCircus.Start()
	if state.started or not state.built then
		return
	end
	state.started = true
	startRideLoops()
	startShowLoop()
	startCarnieLoops()
end

function SpookyCircus.SetNight(isNight: boolean)
	state.nightActive = isNight
	local calliope = state.calliopeSound
	if calliope then
		if isNight and not calliope.IsPlaying then
			calliope:Play()
		elseif not isNight and calliope.IsPlaying then
			calliope:Stop()
		end
	end
end

return SpookyCircus
