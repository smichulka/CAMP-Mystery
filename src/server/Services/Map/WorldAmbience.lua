--!strict

-- WorldAmbience: server-side ambient behavior loops for the camp world.
-- Consumes the WorldKit attribute contract (see Map/WorldKit.lua):
--   CreakyFloor  — BasePart creaks when a character limb steps on it
--   Clutter      — unanchored prop clatters on hard impacts
--   RopeSwing    — creaks by itself on a slow random timer, night only
--   StormDamage  — instance (part or model) shown only during non-Clear weather
-- Also owns: rain footprints + puddles (Rain/Storm at night), the far-scenery
-- mountain silhouette folder, and a default star-field Sky when none exists.
--
-- Integration (wired by the map/runtime service):
--   WorldAmbience.Start()            -- once at boot; idempotent
--   WorldAmbience.SetNight(isNight)  -- alongside ProductionMapService:SetNight
--   WorldAmbience.SetWeather(id)     -- round WeatherId ("Clear"/"Fog"/"Rain"/
--                                    -- "Storm"/"BloodMoon") or nil at teardown
--
-- All loops are plain task.spawn/task.wait loops (no RunService churn) and
-- tolerate the map folder being cleared between rounds: every pass prunes
-- entries whose instances have lost their Parent and re-registers on the next
-- sweep. Zero marketplace asset ids; the only SoundId is a built-in rbxasset,
-- and a missing sound degrades silently (the Sound is simply never played).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local WeatherConfig = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("WeatherConfig")
)

-- Audio-slot convention (matches MonsterAudioConfig): the asset id comes from
-- a SoundService attribute so live Studio experiments can wire real audio.
-- Unset/zero leaves creaks and clatters silent rather than erroring.
local SoundService = game:GetService("SoundService")
local IMPACT_SOUND_ATTRIBUTE = "AmbienceImpactAssetId"

local function impactSoundId(): string?
	local assetId = SoundService:GetAttribute(IMPACT_SOUND_ATTRIBUTE)
	if typeof(assetId) == "number" and assetId > 0 then
		return "rbxassetid://" .. tostring(assetId)
	end
	if typeof(assetId) == "string" and assetId ~= "" then
		return assetId
	end
	return nil
end

local SWEEP_INTERVAL_SECONDS = 20
local CREAK_THROTTLE_SECONDS = 2.5
local CLUTTER_THROTTLE_SECONDS = 1
local CLUTTER_IMPACT_SPEED = 8
local ROPE_SWING_MIN_SECONDS = 20
local ROPE_SWING_MAX_SECONDS = 40
local ROPE_SWING_POLL_SECONDS = 2

local FOOTPRINT_INTERVAL_SECONDS = 0.6
local FOOTPRINT_LIFETIME_SECONDS = 25
local FOOTPRINT_FADE_SECONDS = 5
local FOOTPRINT_CAP = 120
local FOOTPRINT_MIN_STEP_STUDS = 1.4

local SHOWN_TRANSPARENCY_ATTRIBUTE = "AmbienceShownTransparency"
local SHOWN_CAN_COLLIDE_ATTRIBUTE = "AmbienceShownCanCollide"

local AMBIENCE_FOLDER_NAME = "Ambience"
local FAR_SCENERY_FOLDER_NAME = "FarScenery"

-- Ground materials that hold a footprint in the rain.
local FOOTPRINT_MATERIALS: { [Enum.Material]: boolean } = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.Mud] = true,
}

-- Fixed roadside/camp puddle spots (terrain surface y ~= 0.5). Diameters vary
-- so the set does not read as stamped copies.
local PUDDLE_SPOTS: { { position: Vector3, diameter: number } } = {
	{ position = Vector3.new(6, 0.6, -20), diameter = 4.6 },
	{ position = Vector3.new(-10, 0.6, 8), diameter = 3.6 },
	{ position = Vector3.new(4, 0.6, 30), diameter = 5.2 },
	{ position = Vector3.new(-16, 0.6, 46), diameter = 3.2 },
	{ position = Vector3.new(20, 0.6, -4), diameter = 4.2 },
	{ position = Vector3.new(-44, 0.6, -26), diameter = 3.8 },
	{ position = Vector3.new(44, 0.6, 12), diameter = 4.4 },
	{ position = Vector3.new(-4, 0.6, 62), diameter = 3.4 },
}

-- Far mountain silhouette ridgeline: a few huge dark low-detail slabs at
-- 700-900 studs. Deliberately does NOT include a radio-tower pin light — the
-- real tower at (140, ~, -380) carries its own blinking beacon (another pack).
local RIDGE_SLABS: { { size: Vector3, cframe: CFrame } } = {
	{
		size = Vector3.new(420, 190, 80),
		cframe = CFrame.new(-320, 55, -780) * CFrame.Angles(0, math.rad(12), 0),
	},
	{
		size = Vector3.new(520, 230, 100),
		cframe = CFrame.new(60, 75, -840) * CFrame.Angles(0, math.rad(-4), 0),
	},
	{
		size = Vector3.new(380, 170, 90),
		cframe = CFrame.new(430, 45, -760) * CFrame.Angles(0, math.rad(-18), 0),
	},
	{
		size = Vector3.new(460, 180, 90),
		cframe = CFrame.new(-780, 50, -150) * CFrame.Angles(0, math.rad(82), 0),
	},
}
local RIDGE_COLOR = Color3.fromRGB(18, 24, 30)

local started = false
local nightActive = false
local activeWeatherId: string? = nil
local rng = Random.new()

local creakConnections: { [BasePart]: RBXScriptConnection } = {}
local lastCreakAt: { [BasePart]: number } = {}
local clutterConnections: { [BasePart]: RBXScriptConnection } = {}
local lastClutterAt: { [BasePart]: number } = {}
local ropeSwingNextCreakAt: { [BasePart]: number } = {}
local stormDamageTracked: { [Instance]: boolean } = {}

local footprints: { BasePart } = {}
local puddles: { BasePart } = {}
local lastFootprintPosition: { [Player]: Vector3 } = {}
local footprintSide: { [Player]: number } = {}

local footprintRayParams = RaycastParams.new()
footprintRayParams.FilterType = Enum.RaycastFilterType.Exclude
footprintRayParams.IgnoreWater = true

local WorldAmbience = {}

-- ---------------------------------------------------------------------------
-- Shared helpers

local function findMapFolder(): Instance?
	local runtime = Workspace:FindFirstChild("Runtime")
	if runtime == nil then
		return nil
	end
	return runtime:FindFirstChild("Map")
end

-- Transient ambience output (footprints, puddles) lives in its own folder
-- under Runtime.Map so round teardown (ClearAllChildren) wipes it with the map.
local function getAmbienceFolder(): Folder?
	local mapFolder = findMapFolder()
	if mapFolder == nil then
		return nil
	end
	local existing = mapFolder:FindFirstChild(AMBIENCE_FOLDER_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = AMBIENCE_FOLDER_NAME
	folder.Parent = mapFolder
	return folder
end

-- Plays a short one-shot impact sound on a part. Structured so a missing or
-- unloadable built-in asset degrades silently: the Sound is created but never
-- played, then cleaned up.
local function playImpactSound(part: BasePart, volume: number, playbackSpeed: number)
	if part.Parent == nil then
		return
	end
	local soundId = impactSoundId()
	if soundId == nil then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "AmbienceImpact"
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = 55
	local assigned = pcall(function()
		sound.SoundId = soundId
	end)
	sound.Parent = part
	if assigned and sound.SoundId ~= "" then
		sound:Play()
	end
	task.delay(4, function()
		sound:Destroy()
	end)
end

local function isCharacterLimb(hit: BasePart): boolean
	local model = hit:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- ---------------------------------------------------------------------------
-- Storm damage visibility

local function stormActive(): boolean
	return activeWeatherId ~= nil and activeWeatherId ~= "Clear"
end

local function applyStormPartVisibility(part: BasePart, shown: boolean)
	-- Cache the authored look once so repeated toggles restore exactly.
	if part:GetAttribute(SHOWN_TRANSPARENCY_ATTRIBUTE) == nil then
		part:SetAttribute(SHOWN_TRANSPARENCY_ATTRIBUTE, part.Transparency)
		part:SetAttribute(SHOWN_CAN_COLLIDE_ATTRIBUTE, part.CanCollide)
	end
	if shown then
		local transparency = part:GetAttribute(SHOWN_TRANSPARENCY_ATTRIBUTE)
		part.Transparency = if typeof(transparency) == "number" then transparency else 0
		part.CanCollide = part:GetAttribute(SHOWN_CAN_COLLIDE_ATTRIBUTE) == true
	else
		part.Transparency = 1
		part.CanCollide = false
	end
end

local function applyStormVisibility(instance: Instance, shown: boolean)
	if instance:IsA("BasePart") then
		applyStormPartVisibility(instance, shown)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			applyStormPartVisibility(descendant, shown)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Attribute registration (creaks, clutter, rope swings, storm damage)

local function registerCreakyFloor(part: BasePart)
	if creakConnections[part] ~= nil then
		return
	end
	creakConnections[part] = part.Touched:Connect(function(hit: BasePart)
		if part.Parent == nil then
			return
		end
		local now = os.clock()
		if now - (lastCreakAt[part] or 0) < CREAK_THROTTLE_SECONDS then
			return
		end
		if not isCharacterLimb(hit) then
			return
		end
		lastCreakAt[part] = now
		playImpactSound(part, 0.35, 0.8 + rng:NextNumber() * 0.5)
	end)
end

local function registerClutter(part: BasePart)
	if clutterConnections[part] ~= nil then
		return
	end
	clutterConnections[part] = part.Touched:Connect(function(hit: BasePart)
		if part.Parent == nil then
			return
		end
		local now = os.clock()
		if now - (lastClutterAt[part] or 0) < CLUTTER_THROTTLE_SECONDS then
			return
		end
		local relative = part.AssemblyLinearVelocity - hit.AssemblyLinearVelocity
		if relative.Magnitude <= CLUTTER_IMPACT_SPEED then
			return
		end
		lastClutterAt[part] = now
		playImpactSound(part, 0.4, 1.2)
	end)
end

local function registerRopeSwing(part: BasePart)
	if ropeSwingNextCreakAt[part] ~= nil then
		return
	end
	ropeSwingNextCreakAt[part] =
		os.clock() + rng:NextNumber(ROPE_SWING_MIN_SECONDS, ROPE_SWING_MAX_SECONDS)
end

local function registerStormDamage(instance: Instance)
	if stormDamageTracked[instance] then
		return
	end
	stormDamageTracked[instance] = true
	applyStormVisibility(instance, stormActive())
end

local function inspectInstance(instance: Instance)
	if instance.Parent == nil then
		return
	end
	if instance:GetAttribute("StormDamage") == true then
		registerStormDamage(instance)
	end
	if instance:IsA("BasePart") then
		if instance:GetAttribute("CreakyFloor") == true then
			registerCreakyFloor(instance)
		end
		if instance:GetAttribute("Clutter") == true then
			registerClutter(instance)
		end
		if instance:GetAttribute("RopeSwing") == true then
			registerRopeSwing(instance)
		end
	end
end

local function pruneDeadEntries()
	for part, connection in creakConnections do
		if part.Parent == nil then
			connection:Disconnect()
			creakConnections[part] = nil
			lastCreakAt[part] = nil
		end
	end
	for part, connection in clutterConnections do
		if part.Parent == nil then
			connection:Disconnect()
			clutterConnections[part] = nil
			lastClutterAt[part] = nil
		end
	end
	for part in ropeSwingNextCreakAt do
		if part.Parent == nil then
			ropeSwingNextCreakAt[part] = nil
		end
	end
	for instance in stormDamageTracked do
		if instance.Parent == nil then
			stormDamageTracked[instance] = nil
		end
	end
end

-- ---------------------------------------------------------------------------
-- Far scenery + sky (build-once, self-healing after map clears)

local function buildFarScenery(dayCamp: Instance)
	local folder = Instance.new("Folder")
	folder.Name = FAR_SCENERY_FOLDER_NAME
	for index, slab in RIDGE_SLABS do
		local ridge = Instance.new("WedgePart")
		ridge.Name = "MountainRidge" .. index
		ridge.Anchored = true
		ridge.CanCollide = false
		ridge.CanQuery = false
		ridge.CanTouch = false
		ridge.CastShadow = false
		ridge.Size = slab.size
		ridge.CFrame = slab.cframe
		ridge.Color = RIDGE_COLOR
		ridge.Material = Enum.Material.SmoothPlastic
		ridge.Parent = folder
	end
	folder.Parent = dayCamp
end

local function ensureFarScenery()
	local mapFolder = findMapFolder()
	if mapFolder == nil then
		return
	end
	local dayCamp = mapFolder:FindFirstChild("DayCamp")
	if dayCamp == nil then
		return
	end
	if dayCamp:FindFirstChild(FAR_SCENERY_FOLDER_NAME) == nil then
		buildFarScenery(dayCamp)
	end
end

-- Non-destructive sky pass: if the place already has a Sky we own
-- (CampNightSky) we keep its full-moon settings current; a foreign Sky is
-- left entirely alone. If none exists we add one with engine-default
-- properties, a deep star field, and an oversized moon so every night reads
-- as a full moon. Existing Atmosphere/ColorCorrection instances are never
-- touched here.
local function ensureSky()
	local existing = Lighting:FindFirstChildOfClass("Sky")
	if existing ~= nil and existing.Name ~= "CampNightSky" then
		return
	end
	local sky = existing or Instance.new("Sky")
	sky.Name = "CampNightSky"
	sky.StarCount = 5000
	sky.MoonAngularSize = 18
	sky.Parent = Lighting
end

-- ---------------------------------------------------------------------------
-- Rain ground state: footprints + puddles

local function rainFalling(): boolean
	return WeatherConfig.Get(activeWeatherId).rainEnabled
end

local function removeFootprint(footprint: BasePart)
	local index = table.find(footprints, footprint)
	if index ~= nil then
		table.remove(footprints, index)
	end
	footprint:Destroy()
end

local function stampFootprint(player: Player, root: BasePart, hitPosition: Vector3)
	local ambienceFolder = getAmbienceFolder()
	if ambienceFolder == nil then
		return
	end

	local look = root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local side = footprintSide[player] or 1
	footprintSide[player] = -side
	local right = root.CFrame.RightVector
	local lateral = Vector3.new(right.X, 0, right.Z)
	local offset = if lateral.Magnitude > 0.01 then lateral.Unit * 0.35 * side else Vector3.zero

	local footprint = Instance.new("Part")
	footprint.Name = "RainFootprint"
	footprint.Anchored = true
	footprint.CanCollide = false
	footprint.CanQuery = false
	footprint.CanTouch = false
	footprint.CastShadow = false
	footprint.Size = Vector3.new(0.9, 0.05, 1.4)
	footprint.CFrame = CFrame.new(hitPosition + offset + Vector3.new(0, 0.05, 0))
		* CFrame.Angles(0, yaw, 0)
	footprint.Color = Color3.fromRGB(34, 30, 22)
	footprint.Material = Enum.Material.Mud
	footprint.Transparency = 0.25
	footprint.Parent = ambienceFolder

	table.insert(footprints, footprint)
	lastFootprintPosition[player] = root.Position

	-- Ring buffer: oldest footprints go first once the cap is hit.
	while #footprints > FOOTPRINT_CAP do
		local oldest = table.remove(footprints, 1)
		if oldest ~= nil then
			oldest:Destroy()
		end
	end

	task.delay(FOOTPRINT_LIFETIME_SECONDS - FOOTPRINT_FADE_SECONDS, function()
		if footprint.Parent ~= nil then
			TweenService:Create(
				footprint,
				TweenInfo.new(FOOTPRINT_FADE_SECONDS, Enum.EasingStyle.Linear),
				{ Transparency = 1 }
			):Play()
		end
	end)
	task.delay(FOOTPRINT_LIFETIME_SECONDS, function()
		removeFootprint(footprint)
	end)
end

local function tryStampForPlayer(player: Player)
	local character = player.Character
	if character == nil or character.Parent == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	-- Footprints only trail a moving character; a camper standing still in the
	-- rain should not pile ovals under their feet.
	if humanoid.MoveDirection.Magnitude < 0.15 then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local lastPosition = lastFootprintPosition[player]
	if lastPosition ~= nil and (root.Position - lastPosition).Magnitude < FOOTPRINT_MIN_STEP_STUDS then
		return
	end
	footprintRayParams.FilterDescendantsInstances = { character }
	local result = Workspace:Raycast(root.Position, Vector3.new(0, -6, 0), footprintRayParams)
	if result == nil or not FOOTPRINT_MATERIALS[result.Material] then
		return
	end
	stampFootprint(player, root, result.Position)
end

local function spawnPuddles()
	local ambienceFolder = getAmbienceFolder()
	if ambienceFolder == nil then
		return
	end
	for index, spot in PUDDLE_SPOTS do
		local puddle = Instance.new("Part")
		puddle.Name = "RainPuddle" .. index
		puddle.Shape = Enum.PartType.Cylinder
		puddle.Anchored = true
		puddle.CanCollide = false
		puddle.CanQuery = false
		puddle.CanTouch = false
		puddle.CastShadow = false
		puddle.Size = Vector3.new(0.12, spot.diameter, spot.diameter)
		puddle.CFrame = CFrame.new(spot.position) * CFrame.Angles(0, 0, math.rad(90))
		puddle.Color = Color3.fromRGB(70, 86, 96)
		puddle.Material = Enum.Material.Glass
		puddle.Transparency = 0.35
		puddle.Reflectance = 0.35
		puddle.Parent = ambienceFolder
		table.insert(puddles, puddle)
	end
end

local function updatePuddles()
	-- Drop entries the round teardown already destroyed.
	for index = #puddles, 1, -1 do
		if puddles[index].Parent == nil then
			table.remove(puddles, index)
		end
	end
	local shouldShow = rainFalling()
	if shouldShow and #puddles == 0 then
		spawnPuddles()
	elseif not shouldShow and #puddles > 0 then
		for _, puddle in puddles do
			puddle:Destroy()
		end
		table.clear(puddles)
	end
end

-- ---------------------------------------------------------------------------
-- Loops

local function sweepLoop()
	while true do
		pruneDeadEntries()
		for _, descendant in Workspace:GetDescendants() do
			inspectInstance(descendant)
		end
		ensureFarScenery()
		ensureSky()
		-- Re-establish rain dressing if the map was rebuilt mid-weather.
		updatePuddles()
		task.wait(SWEEP_INTERVAL_SECONDS)
	end
end

local function ropeSwingLoop()
	while true do
		task.wait(ROPE_SWING_POLL_SECONDS)
		local now = os.clock()
		for part, nextCreakAt in ropeSwingNextCreakAt do
			if part.Parent == nil then
				ropeSwingNextCreakAt[part] = nil
			elseif now >= nextCreakAt then
				-- Always reschedule so day-time silence does not queue a burst
				-- of overdue creaks for the first minute of night.
				ropeSwingNextCreakAt[part] =
					now + rng:NextNumber(ROPE_SWING_MIN_SECONDS, ROPE_SWING_MAX_SECONDS)
				if nightActive then
					-- The empty swing creaks by itself in the dark: slow and low.
					playImpactSound(part, 0.3, 0.55 + rng:NextNumber() * 0.25)
				end
			end
		end
	end
end

local function footprintLoop()
	while true do
		task.wait(FOOTPRINT_INTERVAL_SECONDS)
		if nightActive and rainFalling() then
			for _, player in Players:GetPlayers() do
				tryStampForPlayer(player)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Public contract

function WorldAmbience.Start()
	if started then
		return
	end
	started = true

	Players.PlayerRemoving:Connect(function(player: Player)
		lastFootprintPosition[player] = nil
		footprintSide[player] = nil
	end)

	-- Catch late builds immediately; attributes are set right after parenting,
	-- so defer one step. The 20s sweep below is the safety net for anything
	-- this misses.
	Workspace.DescendantAdded:Connect(function(descendant: Instance)
		task.defer(inspectInstance, descendant)
	end)

	task.spawn(sweepLoop)
	task.spawn(ropeSwingLoop)
	task.spawn(footprintLoop)
end

function WorldAmbience.SetNight(isNight: boolean)
	nightActive = isNight
end

function WorldAmbience.SetWeather(weatherId: string?)
	activeWeatherId = weatherId
	local shown = stormActive()
	for instance in stormDamageTracked do
		if instance.Parent == nil then
			stormDamageTracked[instance] = nil
		else
			applyStormVisibility(instance, shown)
		end
	end
	updatePuddles()
end

return WorldAmbience
