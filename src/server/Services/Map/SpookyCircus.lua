--!strict

-- SPOOKY CIRCUS / MIDWAY FESTIVAL: opt-in attraction in the northeast
-- frontier meadow (grounds x 150..218, z 240..380; the boundary-dome
-- hillside east of x 220 is the natural back fence).
--
-- Wave 5 World B — Daytime Fairgrounds: by day the Midway Festival is open
-- (bunting, soft ride spin, festival-pass booth, fair-supplies + popcorn
-- restock day side actions). At night SetNight escalates to the Midnight
-- Circus — full lights, rides, big-top show, and carnie monsters that chase
-- ticket holders only.
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
-- Streaming soak: Workspace StreamingMinRadius=128 (default.project.json).
-- Pure scenery (trail strips, fence pickets, bunting, fog hosts, rim bulbs)
-- is tagged FarDress via WorldKit.farDress so shadow soak skips them and
-- CanCollide stays false. Mesh-clone paths are unchanged when assets exist.
--
--   SpookyCircus.Build(dayCamp)  -- after terrain; parents under dayCamp
--   SpookyCircus.Start()         -- once at server start; day + night loops
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

local TENT_RED = Color3.fromRGB(148, 36, 48)
local TENT_CREAM = Color3.fromRGB(228, 214, 178)
local TENT_STRIPE = Color3.fromRGB(188, 52, 62)
local WOOD_DARK = Color3.fromRGB(58, 42, 30)
local WOOD_MID = Color3.fromRGB(88, 64, 42)
local IRON_DARK = Color3.fromRGB(48, 48, 56)
local IRON_BRASS = Color3.fromRGB(138, 112, 72)
local GLOW_GREEN = Color3.fromRGB(126, 226, 148)
local GLOW_PURPLE = Color3.fromRGB(178, 118, 240)
local GLOW_AMBER = Color3.fromRGB(255, 196, 110)
local GLOW_MAGENTA = Color3.fromRGB(236, 86, 168)
local GLOW_CYAN = Color3.fromRGB(110, 220, 236)
local DIRT = Color3.fromRGB(96, 78, 56)
local BONE_WHITE = Color3.fromRGB(222, 216, 200)
local PRIZE_TEAL = Color3.fromRGB(72, 118, 112)

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
	ticketPrompt = nil :: ProximityPrompt?,
	approachSign = nil :: Model?,
	dayBannerLabel = nil :: TextLabel?,
	festivalProps = nil :: Model?,
	-- Cycle 5: day Midway side actions (fair-supplies / popcorn-restock).
	festivalActionHandler = nil :: ((Player, string) -> boolean)?,
	festivalActionParts = {} :: { [string]: BasePart },
	festivalActionPrompts = {} :: { [string]: ProximityPrompt },
	festivalActionComplete = {} :: { [string]: boolean },
}

-- Rendered-surface seat. The circus site is FLAT slab (renders ~2.5
-- everywhere), and Build makes ~100 ground queries — running the standard
-- 8x0.25s chunk-lag retry PER CALL stalled Build for minutes on a cold boot
-- (measured 2026-08-10: loops probed as dead because Start hadn't spawned
-- yet). Instead: retry ONCE at the site center to learn the rendered
-- height, then every other call is a single-attempt ray with that cached
-- flat height as the fallback. TerrainDomes.heightAt stays as the
-- last-resort fallback for points on the hillside berm.
local seatRayParams = RaycastParams.new()
seatRayParams.FilterType = Enum.RaycastFilterType.Include

local siteGroundY: number? = nil

local function rawRay(x: number, z: number): RaycastResult?
	seatRayParams.FilterDescendantsInstances = { Workspace.Terrain }
	return Workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -240, 0), seatRayParams)
end

local function groundY(x: number, z: number): number
	if siteGroundY == nil then
		-- One patient probe at the site center seeds the cache
		for _ = 1, 8 do
			local hit = rawRay(186, 300)
			if hit and hit.Material ~= Enum.Material.Water then
				siteGroundY = hit.Position.Y
				break
			end
			task.wait(0.25)
		end
		if siteGroundY == nil then
			siteGroundY = TerrainDomes.heightAt(186, 300) + 2.0
		end
	end
	local hit = rawRay(x, z)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit.Position.Y
	end
	local analytic = TerrainDomes.heightAt(x, z)
	-- On the flat slab the cached site height is the truth; on the berm the
	-- analytic dome model (+ the slab's render offset) wins.
	return math.max(siteGroundY :: number, analytic + 2.0)
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
		WorldKit.part(circus, "CircusGatePost", Vector3.new(1.35, 12.4, 1.35),
			gateCF * CFrame.new(side * 6.5, 6.2, 0), IRON_DARK, Enum.Material.DiamondPlate)
		local brassCap = WorldKit.part(circus, "GatePostCap", Vector3.new(1.55, 0.35, 1.55),
			gateCF * CFrame.new(side * 6.5, 12.5, 0), IRON_BRASS, Enum.Material.Metal)
		brassCap.CanCollide = false
		local skull = WorldKit.part(circus, "GateSkull", Vector3.new(1.15, 1.15, 1.15),
			gateCF * CFrame.new(side * 6.5, 13.2, 0), BONE_WHITE, Enum.Material.SmoothPlastic,
			Enum.PartType.Ball)
		skull.CanCollide = false
		local neonRing = WorldKit.part(circus, "GatePostNeon", Vector3.new(0.45, 0.45, 0.45),
			gateCF * CFrame.new(side * 6.5, 11.2, 0.7),
			if side < 0 then GLOW_PURPLE else GLOW_GREEN, Enum.Material.Neon, Enum.PartType.Ball)
		neonRing.CanCollide = false
	end
	WorldKit.part(circus, "CircusGateArch", Vector3.new(14.6, 1.7, 0.95),
		gateCF * CFrame.new(0, 12.8, 0), IRON_DARK, Enum.Material.DiamondPlate)
	local neonArch = WorldKit.part(circus, "CircusGateArchNeon", Vector3.new(14.2, 0.28, 0.35),
		gateCF * CFrame.new(0, 13.75, 0.35), GLOW_MAGENTA, Enum.Material.Neon)
	neonArch.CanCollide = false
	local sign = WorldKit.part(circus, "CircusGateSign", Vector3.new(11.4, 2.6, 0.45),
		gateCF * CFrame.new(0, 10.7, 0), WOOD_DARK, Enum.Material.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(560, 140)
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0.62, 0)
	label.Font = Enum.Font.Creepster
	label.Text = "MIDNIGHT CIRCUS"
	label.TextColor3 = GLOW_GREEN
	label.TextScaled = true
	label.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.new(0, 0, 0.62, 0)
	sub.Size = UDim2.new(1, 0, 0.38, 0)
	sub.Font = Enum.Font.GothamBold
	sub.Text = "MIDWAY FESTIVAL BY DAY"
	sub.TextColor3 = GLOW_AMBER
	sub.TextScaled = true
	sub.Parent = gui
	local signLamp = WorldKit.part(circus, "GateSignLamp", Vector3.new(0.65, 0.65, 0.65),
		gateCF * CFrame.new(0, 14.1, 0), GLOW_GREEN, Enum.Material.Neon, Enum.PartType.Ball)
	signLamp.CanCollide = false
	WorldKit.lamp(signLamp, { color = GLOW_GREEN, brightness = 1.5, range = 28 })

	-- Fence: pickets along the south and west edges (the hillside walls the
	-- east and the big top anchors the north). FarDress: pure scenery.
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
			local picket = WorldKit.part(circus, "CircusFencePost", Vector3.new(0.5, 5, 0.5),
				CFrame.new(x, groundY(x, z) + 2.3, z) * CFrame.Angles(0, math.random() * 0.3, math.rad(math.random(-6, 6))),
				IRON_DARK, Enum.Material.Metal)
			WorldKit.farDress(picket)
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
			local strip = WorldKit.part(circus, "CircusTrailStrip", Vector3.new(2.6, 0.12, 7),
				CFrame.new(x, groundY(x, z) + 0.08, z)
					* CFrame.Angles(0, math.atan2(span.X, span.Y) + (segment % 3 - 1) * 0.06, 0),
				DIRT, Enum.Material.Ground)
			WorldKit.farDress(strip)
		end
	end

	-- Midway dirt path: gate -> carousel -> big top (sawdust borders + center stripe)
	local SAWDUST = Color3.fromRGB(168, 142, 96)
	local midwayPoints = { Vector2.new(gx + 3, gz + 5), Vector2.new(180, 288), Vector2.new(190, 318), Vector2.new(195, 336) }
	for index = 1, #midwayPoints - 1 do
		local fromPoint = midwayPoints[index]
		local toPoint = midwayPoints[index + 1]
		local span = toPoint - fromPoint
		local segments = math.max(1, math.floor(span.Magnitude / 5.5))
		local yaw = math.atan2(span.X, span.Y)
		for segment = 0, segments do
			local alpha = segment / segments
			local x = fromPoint.X + span.X * alpha
			local z = fromPoint.Y + span.Y * alpha
			local y = groundY(x, z) + 0.08
			local strip = WorldKit.part(circus, "MidwayStrip", Vector3.new(4.2, 0.12, 6.2),
				CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0),
				DIRT, Enum.Material.Ground)
			WorldKit.farDress(strip)
			local center = WorldKit.part(circus, "MidwayCenterStripe", Vector3.new(0.55, 0.06, 5.6),
				CFrame.new(x, y + 0.05, z) * CFrame.Angles(0, yaw, 0),
				GLOW_AMBER, Enum.Material.Neon)
			WorldKit.farDress(center)
			for side = -1, 1, 2 do
				local border = WorldKit.part(circus, "MidwaySawdust", Vector3.new(0.9, 0.1, 5.8),
					CFrame.new(x, y + 0.02, z) * CFrame.Angles(0, yaw, 0)
						* CFrame.new(side * 2.35, 0, 0),
					SAWDUST, Enum.Material.Sand)
				WorldKit.farDress(border)
			end
		end
	end

	local approachSign = WorldKit.signpost(circus, Vector3.new(140, groundY(140, 222), 222),
		{ "MIDWAY FESTIVAL", "OPEN TODAY" })
	state.approachSign = approachSign
	-- Second approach board sells the night flip so day visitors see both names.
	WorldKit.signpost(circus, Vector3.new(152, groundY(152, 248), 248),
		{ "MIDNIGHT CIRCUS", "AFTER DUSK" })
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

	WorldKit.part(circus, "BoothBase", Vector3.new(5.2, 4.3, 4.2),
		boothCF * CFrame.new(0, 2.15, 0), TENT_RED, Enum.Material.WoodPlanks)
	WorldKit.part(circus, "BoothStripe", Vector3.new(5.35, 0.6, 4.35),
		boothCF * CFrame.new(0, 3.45, 0), TENT_CREAM, Enum.Material.Fabric)
	WorldKit.part(circus, "BoothStripeLower", Vector3.new(5.35, 0.35, 4.35),
		boothCF * CFrame.new(0, 1.1, 0), TENT_STRIPE, Enum.Material.Fabric)
	WorldKit.part(circus, "BoothRoof", Vector3.new(6.4, 0.45, 5.4),
		boothCF * CFrame.new(0, 4.75, 0) * CFrame.Angles(0, 0, math.rad(4)),
		TENT_CREAM, Enum.Material.Fabric)
	-- Brass ticket window frame + neon sill
	WorldKit.part(circus, "BoothWindowFrame", Vector3.new(3.6, 2.0, 0.28),
		boothCF * CFrame.new(0, 3.0, 2.05), IRON_BRASS, Enum.Material.Metal)
	local windowNeon = WorldKit.part(circus, "BoothWindowNeon", Vector3.new(3.3, 0.18, 0.22),
		boothCF * CFrame.new(0, 2.05, 2.15), GLOW_CYAN, Enum.Material.Neon)
	windowNeon.CanCollide = false
	local counter = WorldKit.part(circus, "BoothCounter", Vector3.new(5.4, 0.42, 1.35),
		boothCF * CFrame.new(0, 2.95, 2.5), WOOD_DARK, Enum.Material.WoodPlanks)
	local counterTrim = WorldKit.part(circus, "BoothCounterTrim", Vector3.new(5.45, 0.12, 1.4),
		boothCF * CFrame.new(0, 3.2, 2.5), IRON_BRASS, Enum.Material.Metal)
	counterTrim.CanCollide = false
	local ticketSign = WorldKit.part(circus, "BoothTicketSign", Vector3.new(4.4, 1.0, 0.28),
		boothCF * CFrame.new(0, 5.55, 0.2), WOOD_DARK, Enum.Material.WoodPlanks)
	local ticketGui = Instance.new("SurfaceGui")
	ticketGui.Face = Enum.NormalId.Front
	ticketGui.CanvasSize = Vector2.new(360, 80)
	ticketGui.Parent = ticketSign
	local ticketLabel = Instance.new("TextLabel")
	ticketLabel.BackgroundTransparency = 1
	ticketLabel.Size = UDim2.fromScale(1, 1)
	ticketLabel.Font = Enum.Font.GothamBold
	ticketLabel.Text = "TICKETS · MIDWAY FESTIVAL"
	ticketLabel.TextColor3 = GLOW_AMBER
	ticketLabel.TextScaled = true
	ticketLabel.Parent = ticketGui
	local lamp = WorldKit.part(circus, "BoothLamp", Vector3.new(0.65, 0.65, 0.65),
		boothCF * CFrame.new(0, 6.2, 0), GLOW_AMBER, Enum.Material.Neon, Enum.PartType.Ball)
	lamp.CanCollide = false
	WorldKit.lamp(lamp, { color = GLOW_AMBER, brightness = 1.2, range = 18 })
	for side = -1, 1, 2 do
		local sideGlow = if side < 0 then GLOW_PURPLE else GLOW_GREEN
		local sideLamp = WorldKit.part(circus, "BoothSideLamp", Vector3.new(0.42, 0.42, 0.42),
			boothCF * CFrame.new(side * 2.55, 5.0, 0), sideGlow, Enum.Material.Neon, Enum.PartType.Ball)
		sideLamp.CanCollide = false
		WorldKit.lamp(sideLamp, { color = sideGlow, brightness = 0.7, range = 11 })
	end
	-- Soft search socket on the ticket shelf (registered as circus-ticket-booth)
	WorldKit.evidenceSocketMarker(circus, "circus-ticket-booth",
		Vector3.new(bx, ground + 3.4, bz + 1.0))

	local prompt = WorldKit.prompt(counter, "Take a Festival Pass", "Midway Festival", 0.45)
	state.ticketPrompt = prompt
	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		if not character then
			return
		end
		local hasTicket = character:GetAttribute(TICKET_ATTRIBUTE) == true
		if hasTicket then
			character:SetAttribute(TICKET_ATTRIBUTE, nil)
			removeWristband(character)
			prompt.ActionText = if state.nightActive then "Take a Ticket" else "Take a Festival Pass"
		else
			character:SetAttribute(TICKET_ATTRIBUTE, true)
			attachWristband(character)
			prompt.ActionText = "Return Pass"
			playCircusSound(counter, "TicketChime", 0.7)
		end
	end)
end

-- Daytime Midway Festival dressing + optional day side actions
-- (fair-supplies search + popcorn restock). Completions route through
-- SetFestivalActionHandler so GameRuntimeService can announce loudly.
local function registerFestivalAction(
	actionId: string,
	part: BasePart,
	prompt: ProximityPrompt,
	dayTipText: string
)
	state.festivalActionParts[actionId] = part
	state.festivalActionPrompts[actionId] = prompt
	prompt.Triggered:Connect(function(player: Player)
		if state.nightActive then
			prompt.ObjectText = "Midnight Circus"
			return
		end
		if state.festivalActionComplete[actionId] then
			return
		end
		local handler = state.festivalActionHandler
		local accepted = if handler then handler(player, actionId) else false
		if not accepted then
			-- Soft local tip when the runtime is not wired yet (boot / tests).
			local character = player.Character
			if character then
				character:SetAttribute("FairSuppliesChecked", true)
			end
			playCircusSound(part, "TicketChime", 0.45)
			local billboard = part:FindFirstChild("FestivalActionTip")
			if not (billboard and billboard:IsA("BillboardGui")) then
				billboard = Instance.new("BillboardGui")
				billboard.Name = "FestivalActionTip"
				billboard.Size = UDim2.new(8, 0, 2, 0)
				billboard.StudsOffset = Vector3.new(0, 2.8, 0)
				billboard.AlwaysOnTop = true
				billboard.MaxDistance = 40
				billboard.Parent = part
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 0.2
				label.BackgroundColor3 = Color3.fromRGB(28, 36, 30)
				label.Size = UDim2.fromScale(1, 1)
				label.Font = Enum.Font.Gotham
				label.Text = dayTipText
				label.TextColor3 = GLOW_AMBER
				label.TextScaled = true
				label.TextWrapped = true
				label.Parent = billboard
			end
			task.delay(4, function()
				local tip = part:FindFirstChild("FestivalActionTip")
				if tip then
					tip:Destroy()
				end
			end)
			return
		end
		state.festivalActionComplete[actionId] = true
		prompt.Enabled = false
		playCircusSound(part, "TicketChime", 0.55)
		local character = player.Character
		if character then
			if actionId == "fair-supplies" then
				character:SetAttribute("FairSuppliesChecked", true)
			elseif actionId == "popcorn-restock" then
				character:SetAttribute("PopcornRestocked", true)
			end
		end
	end)
end

local function buildDaytimeFestival(circus: Model)
	local festival = WorldKit.model(circus, "DaytimeFestival")
	state.festivalProps = festival
	local gx, gz = GATE_POSITION.X, GATE_POSITION.Z

	-- Entrance festival banner (day copy; night retints via SetNight attribute).
	local bannerHost = WorldKit.part(festival, "FestivalBannerHost", Vector3.new(10, 1.8, 0.35),
		CFrame.new(gx + 8, groundY(gx + 8, gz + 4) + 7.2, gz + 4), WOOD_DARK, Enum.Material.WoodPlanks)
	local bannerGui = Instance.new("SurfaceGui")
	bannerGui.Face = Enum.NormalId.Front
	bannerGui.CanvasSize = Vector2.new(520, 90)
	bannerGui.Parent = bannerHost
	local bannerLabel = Instance.new("TextLabel")
	bannerLabel.BackgroundTransparency = 1
	bannerLabel.Size = UDim2.fromScale(1, 1)
	bannerLabel.Font = Enum.Font.GothamBold
	bannerLabel.Text = "MIDWAY FESTIVAL — OPEN"
	bannerLabel.TextColor3 = GLOW_AMBER
	bannerLabel.TextScaled = true
	bannerLabel.Parent = bannerGui
	state.dayBannerLabel = bannerLabel

	-- Bunting string across the gate mouth (FarDress: pure scenery)
	for flag = 0, 8 do
		local alpha = flag / 8
		local x = gx - 4 + alpha * 16
		local z = gz + 2 + math.sin(alpha * math.pi) * 1.5
		local ground = groundY(x, z)
		local color = if flag % 3 == 0 then TENT_RED elseif flag % 3 == 1 then GLOW_CYAN else GLOW_AMBER
		local pennant = WorldKit.part(festival, "FestivalBunting", Vector3.new(1.4, 1.1, 0.12),
			CFrame.new(x, ground + 5.4, z) * CFrame.Angles(0, 0, math.rad((flag % 2) * 12 - 6)),
			color, Enum.Material.Fabric)
		WorldKit.farDress(pennant)
	end

	-- Soft daytime balloon clusters (decorative; night keeps them)
	for index, spot in {
		Vector3.new(168, 0, 270), Vector3.new(184, 0, 286), Vector3.new(176, 0, 298),
	} do
		local ground = groundY(spot.X, spot.Z)
		local stem = WorldKit.part(festival, "BalloonStem" .. index, Vector3.new(0.12, 4.2, 0.12),
			CFrame.new(spot.X, ground + 2.2, spot.Z), IRON_BRASS, Enum.Material.Metal)
		WorldKit.farDress(stem)
		local balloonColor = if index % 2 == 0 then GLOW_MAGENTA else GLOW_CYAN
		local balloon = WorldKit.part(festival, "FestivalBalloon" .. index, Vector3.new(1.6, 2.0, 1.6),
			CFrame.new(spot.X, ground + 5.4, spot.Z), balloonColor, Enum.Material.SmoothPlastic,
			Enum.PartType.Ball)
		WorldKit.farDress(balloon)
	end

	-- Fair supplies crate: day-phase Midway side action + soft search socket.
	local sx, sz = 178, 274
	local sGround = groundY(sx, sz)
	local crate = WorldKit.part(festival, "FairSuppliesCrate", Vector3.new(3.2, 2.0, 2.4),
		CFrame.new(sx, sGround + 1.0, sz) * CFrame.Angles(0, math.rad(28), 0),
		WOOD_MID, Enum.Material.WoodPlanks)
	WorldKit.part(festival, "FairSuppliesLid", Vector3.new(3.3, 0.25, 2.5),
		CFrame.new(sx, sGround + 2.15, sz) * CFrame.Angles(0, math.rad(28), math.rad(-4)),
		WOOD_DARK, Enum.Material.WoodPlanks)
	WorldKit.evidenceSocketMarker(festival, "fair-supplies",
		Vector3.new(sx, sGround + 2.4, sz))
	local suppliesPrompt = WorldKit.prompt(crate, "Check Festival Supplies", "Midway Festival", 0.55)
	registerFestivalAction(
		"fair-supplies",
		crate,
		suppliesPrompt,
		"Festival stocked — booth stays open after dusk."
	)

	-- Popcorn restock cart: second Midway day side action beside the games row.
	local px, pz = 172, 282
	local pGround = groundY(px, pz)
	local cart = WorldKit.part(festival, "PopcornRestockCart", Vector3.new(2.6, 2.2, 1.8),
		CFrame.new(px, pGround + 1.1, pz) * CFrame.Angles(0, math.rad(-18), 0),
		WOOD_DARK, Enum.Material.WoodPlanks)
	WorldKit.part(festival, "PopcornBucket", Vector3.new(1.1, 1.0, 1.1),
		CFrame.new(px, pGround + 2.5, pz) * CFrame.Angles(0, math.rad(-18), 0),
		GLOW_AMBER, Enum.Material.SmoothPlastic)
	local popcornPrompt = WorldKit.prompt(cart, "Restock Popcorn", "Midway Festival", 0.5)
	registerFestivalAction(
		"popcorn-restock",
		cart,
		popcornPrompt,
		"Popcorn bins topped off — Midway smells ready for dusk."
	)
end

-- BIG TOP + SHOW --------------------------------------------------------------

local function buildProceduralTent(circus: Model, at: CFrame): Model
	local tent = WorldKit.model(circus, "CircusTentFallback")
	-- Cylinder wall + cream roof, then stripe panels / rope lights so the
	-- graybox reads as a painted big top when Creator Store meshes are absent.
	local base = WorldKit.part(tent, "TentWall", Vector3.new(3.4, 14.2, 40.4),
		at * CFrame.new(0, 7, 0), TENT_RED, Enum.Material.Fabric, Enum.PartType.Cylinder)
	base.CFrame = at * CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.rad(90))
	local cone = Instance.new("WedgePart")
	cone.Name = "TentRoof"
	cone.Anchored = true
	cone.Size = Vector3.new(40, 12.5, 40)
	cone.CFrame = at * CFrame.new(0, 20.2, 0)
	cone.Color = TENT_CREAM
	cone.Material = Enum.Material.Fabric
	cone.Parent = tent
	local roofBand = WorldKit.part(tent, "TentRoofBand", Vector3.new(1.1, 38, 38),
		at * CFrame.new(0, 14.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
		TENT_STRIPE, Enum.Material.Fabric, Enum.PartType.Cylinder)
	roofBand.CanCollide = false
	for stripe = 0, 7 do
		local angle = stripe / 8 * math.pi * 2
		local panel = WorldKit.part(tent, "TentStripe", Vector3.new(0.38, 13.4, 5.4),
			at * CFrame.new(math.cos(angle) * 19.4, 7.2, math.sin(angle) * 19.4)
				* CFrame.Angles(0, -angle, 0),
			if stripe % 2 == 0 then TENT_STRIPE else TENT_CREAM, Enum.Material.Fabric)
		WorldKit.farDress(panel)
	end
	for pole = 0, 5 do
		local angle = pole / 6 * math.pi * 2
		WorldKit.part(tent, "TentGuyRope", Vector3.new(0.3, 11.2, 0.3),
			at * CFrame.new(math.cos(angle) * 21.2, 5.2, math.sin(angle) * 21.2)
				* CFrame.Angles(math.rad(18), -angle, 0),
			IRON_BRASS, Enum.Material.Metal)
	end
	local peak = WorldKit.part(tent, "TentPeakFinial", Vector3.new(1.2, 2.6, 1.2),
		at * CFrame.new(0, 26.8, 0), GLOW_AMBER, Enum.Material.Neon, Enum.PartType.Ball)
	peak.CanCollide = false
	WorldKit.lamp(peak, { color = GLOW_AMBER, brightness = 1.7, range = 30 })
	-- Rope bulbs: every other bulb gets a PointLight (streaming soak at distance)
	for bulb = 0, 11 do
		local angle = bulb / 12 * math.pi * 2
		local glow = if bulb % 3 == 0 then GLOW_PURPLE elseif bulb % 3 == 1 then GLOW_GREEN else GLOW_AMBER
		local lamp = WorldKit.part(tent, "TentRopeBulb", Vector3.new(0.48, 0.48, 0.48),
			at * CFrame.new(math.cos(angle) * 18.5, 14.3, math.sin(angle) * 18.5),
			glow, Enum.Material.Neon, Enum.PartType.Ball)
		WorldKit.farDress(lamp)
		if bulb % 2 == 0 then
			WorldKit.lamp(lamp, { color = glow, brightness = 0.85, range = 12 })
		end
	end
	-- Mouth awning + banner so the south face sells the entrance without meshes
	WorldKit.part(tent, "TentMouthAwning", Vector3.new(12.5, 0.42, 6.4),
		at * CFrame.new(0, 9.3, -18.2) * CFrame.Angles(math.rad(-18), 0, 0),
		TENT_CREAM, Enum.Material.Fabric)
	local awningNeon = WorldKit.part(tent, "TentAwningNeon", Vector3.new(11.8, 0.2, 0.28),
		at * CFrame.new(0, 8.6, -20.8), GLOW_MAGENTA, Enum.Material.Neon)
	awningNeon.CanCollide = false
	local banner = WorldKit.part(tent, "TentBanner", Vector3.new(10.4, 1.8, 0.38),
		at * CFrame.new(0, 11.5, -20.4), WOOD_DARK, Enum.Material.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(480, 100)
	gui.Parent = banner
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0.6, 0)
	label.Font = Enum.Font.Creepster
	label.Text = "MIDNIGHT CIRCUS"
	label.TextColor3 = GLOW_GREEN
	label.TextScaled = true
	label.Parent = gui
	local dayLine = Instance.new("TextLabel")
	dayLine.BackgroundTransparency = 1
	dayLine.Position = UDim2.new(0, 0, 0.6, 0)
	dayLine.Size = UDim2.new(1, 0, 0.4, 0)
	dayLine.Font = Enum.Font.GothamBold
	dayLine.Text = "MIDWAY FESTIVAL"
	dayLine.TextColor3 = GLOW_AMBER
	dayLine.TextScaled = true
	dayLine.Parent = gui
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
		WorldKit.part(wheel, "FerrisLeg", Vector3.new(1.45, 26.5, 1.45),
			at * CFrame.new(side * 6, 13.2, 0) * CFrame.Angles(0, 0, side * math.rad(-14)),
			IRON_DARK, Enum.Material.DiamondPlate)
		WorldKit.part(wheel, "FerrisLegBrace", Vector3.new(0.6, 10.4, 0.6),
			at * CFrame.new(side * 3.2, 8, 0) * CFrame.Angles(0, 0, side * math.rad(28)),
			IRON_BRASS, Enum.Material.Metal)
	end
	local hubCore = WorldKit.part(wheel, "FerrisHubCore", Vector3.new(3.4, 3.4, 3.4),
		at * CFrame.new(0, 24, 0), IRON_BRASS, Enum.Material.DiamondPlate, Enum.PartType.Ball)
	hubCore.CanCollide = false
	local hubGlow = WorldKit.part(wheel, "FerrisHubGlow", Vector3.new(1.5, 1.5, 1.5),
		at * CFrame.new(0, 24, 0), GLOW_MAGENTA, Enum.Material.Neon, Enum.PartType.Ball)
	hubGlow.CanCollide = false
	WorldKit.lamp(hubGlow, { color = GLOW_MAGENTA, brightness = 1.5, range = 24 })
	local hub = WorldKit.model(wheel, "FerrisHub")
	for spoke = 1, 8 do
		local angle = spoke / 8 * math.pi * 2
		WorldKit.part(hub, "FerrisSpoke", Vector3.new(0.5, 22.2, 0.5),
			at * CFrame.new(0, 24, 0) * CFrame.Angles(angle, 0, 0)
				* CFrame.Angles(math.rad(90), 0, 0),
			IRON_DARK, Enum.Material.Metal)
		local rimColor = if spoke % 2 == 0 then GLOW_PURPLE else GLOW_CYAN
		local rim = WorldKit.part(hub, "FerrisRimLight", Vector3.new(0.75, 0.75, 0.75),
			at * CFrame.new(0, 24, 0) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, 11, 0),
			rimColor, Enum.Material.Neon, Enum.PartType.Ball)
		WorldKit.farDress(rim)
		-- Half the rim bulbs cast light — keeps far-chunk cost down
		if spoke % 2 == 0 then
			WorldKit.lamp(rim, { color = rimColor, brightness = 0.8, range = 11 })
		end
		local gondola = WorldKit.part(hub, "FerrisGondola", Vector3.new(2.3, 1.5, 1.7),
			at * CFrame.new(0, 24, 0) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, 11, 0),
			if spoke % 2 == 0 then TENT_RED else TENT_CREAM, Enum.Material.SmoothPlastic)
		gondola.CanCollide = false
		local gondolaTrim = WorldKit.part(hub, "FerrisGondolaTrim", Vector3.new(2.4, 0.18, 1.8),
			at * CFrame.new(0, 24, 0) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, 11.75, 0),
			IRON_BRASS, Enum.Material.Metal)
		WorldKit.farDress(gondolaTrim)
	end
	-- Outer rim ring (thin torus stand-in: four arcs as cylinders)
	for arc = 0, 3 do
		local angle = arc / 4 * math.pi * 2
		local rimArc = WorldKit.part(hub, "FerrisRimArc", Vector3.new(1.2, 0.6, 0.6),
			at * CFrame.new(0, 24, 0) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, 11.3, 0)
				* CFrame.Angles(0, 0, math.rad(90)),
			IRON_BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
		WorldKit.farDress(rimArc)
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
	-- Fallback: painted pole + striped canopy + neon posts + lit seats
	local carousel = WorldKit.model(circus, "CarouselFallback")
	WorldKit.part(carousel, "CarouselDeck", Vector3.new(1.35, 14.4, 14.4),
		baseCF * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
		WOOD_DARK, Enum.Material.WoodPlanks, Enum.PartType.Cylinder)
	local deckRing = WorldKit.part(carousel, "CarouselDeckNeon", Vector3.new(0.35, 14.6, 14.6),
		baseCF * CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
		GLOW_CYAN, Enum.Material.Neon, Enum.PartType.Cylinder)
	WorldKit.farDress(deckRing)
	WorldKit.part(carousel, "CarouselPole", Vector3.new(1.25, 12.2, 1.25),
		baseCF * CFrame.new(0, 6, 0), IRON_BRASS, Enum.Material.DiamondPlate)
	local disc = WorldKit.part(carousel, "CarouselCanopy", Vector3.new(1.3, 16.2, 16.2),
		baseCF * CFrame.new(0, 11.5, 0), TENT_RED, Enum.Material.Fabric, Enum.PartType.Cylinder)
	disc.CFrame = baseCF * CFrame.new(0, 11.5, 0) * CFrame.Angles(0, 0, math.rad(90))
	for wedge = 0, 7 do
		local angle = wedge / 8 * math.pi * 2
		local stripe = WorldKit.part(carousel, "CarouselCanopyStripe", Vector3.new(0.28, 7.4, 1.2),
			baseCF * CFrame.new(math.cos(angle) * 5.6, 11.75, math.sin(angle) * 5.6)
				* CFrame.Angles(0, -angle, math.rad(12)),
			if wedge % 2 == 0 then TENT_CREAM else GLOW_PURPLE, Enum.Material.Fabric)
		WorldKit.farDress(stripe)
	end
	local finial = WorldKit.part(carousel, "CarouselFinial", Vector3.new(1.3, 1.3, 1.3),
		baseCF * CFrame.new(0, 12.7, 0), GLOW_AMBER, Enum.Material.Neon, Enum.PartType.Ball)
	finial.CanCollide = false
	WorldKit.lamp(finial, { color = GLOW_AMBER, brightness = 1.25, range = 18 })
	local spinner = WorldKit.model(carousel, "CarouselSpinner")
	for seat = 1, 4 do
		local angle = seat / 4 * math.pi * 2
		local postGlow = if seat % 2 == 0 then GLOW_GREEN else GLOW_MAGENTA
		WorldKit.part(spinner, "CarouselSeatPost", Vector3.new(0.45, 9.2, 0.45),
			baseCF * CFrame.new(math.cos(angle) * 6, 6.5, math.sin(angle) * 6),
			postGlow, Enum.Material.Neon)
		WorldKit.part(spinner, "CarouselSeat", Vector3.new(1.8, 0.48, 1.8),
			baseCF * CFrame.new(math.cos(angle) * 6, 3, math.sin(angle) * 6),
			if seat % 2 == 0 then TENT_CREAM else WOOD_MID, Enum.Material.WoodPlanks)
		local horse = WorldKit.part(spinner, "CarouselHorse", Vector3.new(1.15, 1.55, 2.3),
			baseCF * CFrame.new(math.cos(angle) * 6, 4.15, math.sin(angle) * 6)
				* CFrame.Angles(0, -angle + math.rad(90), 0),
			if seat % 2 == 0 then TENT_RED else GLOW_PURPLE, Enum.Material.SmoothPlastic)
		horse.CanCollide = false
		local seatLamp = WorldKit.part(spinner, "CarouselSeatLamp", Vector3.new(0.42, 0.42, 0.42),
			baseCF * CFrame.new(math.cos(angle) * 6, 10.5, math.sin(angle) * 6),
			postGlow, Enum.Material.Neon, Enum.PartType.Ball)
		WorldKit.farDress(seatLamp)
		-- Lit seats only on even indices — halves far light count
		if seat % 2 == 0 then
			WorldKit.lamp(seatLamp, { color = postGlow, brightness = 0.75, range = 11 })
		end
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
		WorldKit.part(booth, "BoothPost", Vector3.new(0.55, 6.6, 0.55),
			boothCF * CFrame.new(side * 3.6, 3.2, -1.8), WOOD_DARK, Enum.Material.Wood)
		local postCap = WorldKit.part(booth, "BoothPostNeon", Vector3.new(0.4, 0.4, 0.4),
			boothCF * CFrame.new(side * 3.6, 6.6, -1.8), glow, Enum.Material.Neon, Enum.PartType.Ball)
		WorldKit.farDress(postCap)
	end
	WorldKit.part(booth, "BoothCanopy", Vector3.new(8.6, 0.42, 4.8),
		boothCF * CFrame.new(0, 6.55, -1.4) * CFrame.Angles(math.rad(-8), 0, 0),
		TENT_RED, Enum.Material.Fabric)
	WorldKit.part(booth, "BoothCanopyStripe", Vector3.new(8.7, 0.22, 4.9),
		boothCF * CFrame.new(0, 6.35, -1.3) * CFrame.Angles(math.rad(-8), 0, 0),
		TENT_CREAM, Enum.Material.Fabric)
	for fringe = -1, 1 do
		local fringeGlow = if fringe == 0 then GLOW_AMBER elseif fringe < 0 then GLOW_PURPLE else GLOW_GREEN
		local bulb = WorldKit.part(booth, "BoothCanopyBulb", Vector3.new(0.42, 0.42, 0.42),
			boothCF * CFrame.new(fringe * 2.8, 6.25, 0.4), fringeGlow, Enum.Material.Neon, Enum.PartType.Ball)
		WorldKit.farDress(bulb)
		-- Center fringe bulb only — cuts PointLight density on the midway
		if fringe == 0 then
			WorldKit.lamp(bulb, { color = fringeGlow, brightness = 0.75, range = 10 })
		end
	end
	local counter = WorldKit.part(booth, "BoothCounter", Vector3.new(7.8, 1, 1.15),
		boothCF * CFrame.new(0, 2.2, 0.4), WOOD_MID, Enum.Material.WoodPlanks)
	local counterBrass = WorldKit.part(booth, "BoothCounterBrass", Vector3.new(7.85, 0.12, 1.2),
		boothCF * CFrame.new(0, 2.75, 0.4), IRON_BRASS, Enum.Material.Metal)
	counterBrass.CanCollide = false
	local sign = WorldKit.part(booth, "BoothSign", Vector3.new(6.6, 1.25, 0.32),
		boothCF * CFrame.new(0, 7.45, -1.4), WOOD_DARK, Enum.Material.WoodPlanks)
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

-- Prize counter sits beside the midway games. Soft-couple only: evidence can
-- spawn here without turning carnies / tickets into lethal mystery stakes.
local function buildPrizeCounter(circus: Model)
	local px, pz = 174, 278
	local ground = groundY(px, pz)
	local boothCF = CFrame.new(px, ground, pz) * CFrame.Angles(0, math.rad(150), 0)
	local prize = WorldKit.model(circus, "MidwayPrizeCounter")
	WorldKit.part(prize, "PrizeBase", Vector3.new(6.4, 3.7, 3.5),
		boothCF * CFrame.new(0, 1.85, 0), PRIZE_TEAL, Enum.Material.WoodPlanks)
	WorldKit.part(prize, "PrizeStripe", Vector3.new(6.55, 0.4, 3.65),
		boothCF * CFrame.new(0, 3.2, 0), TENT_CREAM, Enum.Material.Fabric)
	WorldKit.part(prize, "PrizeRoof", Vector3.new(7.4, 0.45, 4.4),
		boothCF * CFrame.new(0, 4.1, 0) * CFrame.Angles(0, 0, math.rad(-4)),
		TENT_CREAM, Enum.Material.Fabric)
	WorldKit.part(prize, "PrizeShelf", Vector3.new(5.8, 0.35, 1.05),
		boothCF * CFrame.new(0, 2.65, 1.65), WOOD_DARK, Enum.Material.WoodPlanks)
	for prizeIndex = -1, 1 do
		local glow = if prizeIndex == 0 then GLOW_AMBER elseif prizeIndex < 0 then GLOW_PURPLE else GLOW_GREEN
		local toy = WorldKit.part(prize, "PrizeToy", Vector3.new(0.75, 0.95, 0.75),
			boothCF * CFrame.new(prizeIndex * 1.6, 3.25, 1.6), glow, Enum.Material.Neon,
			Enum.PartType.Ball)
		WorldKit.farDress(toy)
	end
	local lamp = WorldKit.part(prize, "PrizeLamp", Vector3.new(0.58, 0.58, 0.58),
		boothCF * CFrame.new(0, 4.85, 0), GLOW_MAGENTA, Enum.Material.Neon, Enum.PartType.Ball)
	lamp.CanCollide = false
	WorldKit.lamp(lamp, { color = GLOW_MAGENTA, brightness = 1.1, range = 15 })
	local sign = WorldKit.part(prize, "PrizeSign", Vector3.new(5.4, 1.15, 0.32),
		boothCF * CFrame.new(0, 5.0, -1.25), WOOD_DARK, Enum.Material.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(360, 70)
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Creepster
	label.Text = "PRIZE COUNTER"
	label.TextColor3 = GLOW_AMBER
	label.TextScaled = true
	label.Parent = gui
	-- Registered as "midway-prize-counter" in SEARCH_TARGETS / SEARCH_LOCATIONS
	WorldKit.evidenceSocketMarker(prize, "midway-prize-counter",
		Vector3.new(px, ground + 3.2, pz + 1.2))
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
	-- Ferris + carousel: full night spin when players are near; softer daytime
	-- Midway Festival motion so the fairgrounds read as open by day.
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
				local circusFolder = state.circusFolder
				if circusFolder then
					circusFolder:SetAttribute("RideLoopBeat", os.clock())
					circusFolder:SetAttribute("RideLoopGate",
						tostring(state.nightActive) .. "/" .. tostring(nearby))
				end
			end
			if not nearby then
				continue
			end
			-- Night = full carnival speed; day = gentle Midway Festival drift.
			local wheelSpeed = if state.nightActive then 0.22 else 0.08
			local carouselSpeed = if state.nightActive then 0.5 else 0.18
			local wheel = state.ferrisWheel
			local axle = state.ferrisAxle
			local wheelOffset = state.ferrisWheelOffset
			if wheel and axle and wheel.Parent then
				theta += dt * wheelSpeed
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
				carouselTheta += dt * carouselSpeed
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
	-- automatically via ProductionMapService:SetNight's generic lamp sweep).
	-- Every other post gets a PointLight so far-chunk streaming stays light.
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
			if segment % 2 == 0 then
				WorldKit.lamp(bulb, { color = bulbColor, brightness = 1.0, range = 15 })
			end
		end
	end
	-- Ground fog: two hosts (was four) at lower rate for StreamingMinRadius soak
	for index, spot in {
		Vector3.new(178, 0, 290), Vector3.new(194, 0, 320),
	} do
		local ground = groundY(spot.X, spot.Z)
		local host = WorldKit.part(circus, "CircusFogHost" .. index, Vector3.new(22, 2, 22),
			CFrame.new(spot.X, ground + 1, spot.Z), Color3.fromRGB(255, 255, 255),
			Enum.Material.SmoothPlastic)
		host.Transparency = 1
		host.CanQuery = false
		WorldKit.farDress(host)
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
		emitter.Rate = 1.6
		emitter.Speed = NumberRange.new(0.4, 1.0)
		emitter.Lifetime = NumberRange.new(5, 8)
		emitter.SpreadAngle = Vector2.new(8, 8)
		emitter.LightEmission = 0.04
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
	buildDaytimeFestival(circus)
	buildBigTop(circus)
	buildFerrisWheel(circus)
	buildCarousel(circus)
	buildGames(circus)
	buildPrizeCounter(circus)
	buildCarnies(circus)
	buildDressing(circus)
	circus:SetAttribute("MidwayFestivalDay", true)
	circus:SetAttribute("CircusNight", false)
end

function SpookyCircus.Start()
	if state.started or not state.built then
		return
	end
	state.started = true
	-- Boot telemetry (attribute-based; invisible to players, readable by the
	-- verification loop — the console-print pattern's quieter sibling)
	local circusFolder = state.circusFolder
	if circusFolder then
		circusFolder:SetAttribute("CircusStarted", true)
	end
	startRideLoops()
	startShowLoop()
	startCarnieLoops()
end

local function setSignBoardText(sign: Model?, line1: string, line2: string)
	if not sign then
		return
	end
	local board1 = sign:FindFirstChild("Board1")
	local board2 = sign:FindFirstChild("Board2")
	if board1 and board1:IsA("BasePart") then
		local gui = board1:FindFirstChildOfClass("SurfaceGui")
		local label = if gui then gui:FindFirstChildOfClass("TextLabel") else nil
		if label then
			label.Text = line1
		end
	end
	if board2 and board2:IsA("BasePart") then
		local gui = board2:FindFirstChildOfClass("SurfaceGui")
		local label = if gui then gui:FindFirstChildOfClass("TextLabel") else nil
		if label then
			label.Text = line2
		end
	end
end

function SpookyCircus.SetNight(isNight: boolean)
	state.nightActive = isNight
	local circusFolder = state.circusFolder
	if circusFolder then
		circusFolder:SetAttribute("CircusNight", isNight)
		circusFolder:SetAttribute("MidwayFestivalDay", not isNight)
	end
	local calliope = state.calliopeSound
	if calliope then
		if isNight and not calliope.IsPlaying then
			calliope:Play()
		elseif not isNight and calliope.IsPlaying then
			calliope:Stop()
		end
	end
	local ticketPrompt = state.ticketPrompt
	if ticketPrompt then
		ticketPrompt.ObjectText = if isNight then "Midnight Circus" else "Midway Festival"
		if ticketPrompt.ActionText ~= "Return Pass" and ticketPrompt.ActionText ~= "Return Ticket" then
			ticketPrompt.ActionText = if isNight then "Take a Ticket" else "Take a Festival Pass"
		end
	end
	local banner = state.dayBannerLabel
	if banner then
		banner.Text = if isNight then "MIDNIGHT CIRCUS — AFTER DARK" else "MIDWAY FESTIVAL — OPEN"
		banner.TextColor3 = if isNight then GLOW_PURPLE else GLOW_AMBER
	end
	if isNight then
		setSignBoardText(state.approachSign, "MIDNIGHT CIRCUS", "IF YOU DARE")
	else
		setSignBoardText(state.approachSign, "MIDWAY FESTIVAL", "OPEN TODAY")
	end
	local festival = state.festivalProps
	if festival then
		-- Soft day fog stays; night dressing already covers lamps via CampLamp.
		festival:SetAttribute("FestivalNightEscalated", isNight)
	end
	-- Day Midway side actions only while the festival is open.
	for actionId, prompt in state.festivalActionPrompts do
		prompt.ObjectText = if isNight then "Midnight Circus" else "Midway Festival"
		prompt.Enabled = (not isNight) and not state.festivalActionComplete[actionId]
	end
end

function SpookyCircus.SetFestivalActionHandler(handler: ((Player, string) -> boolean)?)
	state.festivalActionHandler = handler
end

function SpookyCircus.GetFestivalActionParts(): { [string]: BasePart }
	return state.festivalActionParts
end

function SpookyCircus.MarkFestivalActionComplete(actionId: string)
	state.festivalActionComplete[actionId] = true
	local prompt = state.festivalActionPrompts[actionId]
	if prompt then
		prompt.Enabled = false
	end
end

function SpookyCircus.ResetFestivalActions()
	state.festivalActionComplete = {}
	for actionId, prompt in state.festivalActionPrompts do
		prompt.Enabled = not state.nightActive
		prompt.ObjectText = if state.nightActive then "Midnight Circus" else "Midway Festival"
		local _ = actionId
	end
end

return SpookyCircus
