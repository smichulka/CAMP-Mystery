--!strict

-- PolishPack: one hundred numbered world enhancements, built after the other
-- district packs so it can decorate their structures. Every item is a small,
-- self-contained builder run under pcall — a single failure skips that item
-- and the build reports how many of the hundred landed.
--
-- Conventions follow WorldKit: anchored parts, CampLamp for night lighting,
-- HidingSpot for hide registry, engine-shipped particle textures only.

local TweenService = game:GetService("TweenService")

local WorldKit = require(script.Parent.WorldKit)

local PolishPack = {}

-- ---------------------------------------------------------------------------
-- Palette

local WOOD = Color3.fromRGB(110, 82, 52)
local WOOD_DARK = Color3.fromRGB(76, 56, 38)
local WOOD_PALE = Color3.fromRGB(150, 120, 84)
local STONE = Color3.fromRGB(120, 122, 118)
local STONE_DARK = Color3.fromRGB(84, 86, 84)
local PAPER = Color3.fromRGB(228, 220, 196)
local CANVAS = Color3.fromRGB(206, 196, 170)
local LEAF = Color3.fromRGB(64, 106, 58)
local LEAF_DRY = Color3.fromRGB(142, 128, 74)
local RED = Color3.fromRGB(178, 52, 44)
local WHITE = Color3.fromRGB(236, 236, 230)
local INK = Color3.fromRGB(38, 30, 22)
local RUST = Color3.fromRGB(126, 82, 54)
local METAL = Color3.fromRGB(96, 100, 104)

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

-- ---------------------------------------------------------------------------
-- Helpers

local function faceText(part: BasePart, face: Enum.NormalId, text: string, textColor: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(280, 130)
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.SpecialElite
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui
end

local function seatAt(
	parent: Instance,
	name: string,
	position: Vector3,
	lookAt: Vector3,
	color: Color3
): Seat
	local seat = Instance.new("Seat")
	seat.Name = name
	seat.Anchored = true
	seat.Size = Vector3.new(2, 0.5, 2)
	seat.CFrame = CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z))
	seat.Color = color
	seat.Material = Enum.Material.WoodPlanks
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.Parent = parent
	return seat
end

type EmitterSpec = {
	texture: string,
	color: ColorSequence,
	size: NumberSequence,
	transparency: NumberSequence,
	rate: number,
	speed: NumberRange,
	lifetime: NumberRange,
	spreadAngle: Vector2?,
	acceleration: Vector3?,
	lightEmission: number?,
}

local function emitterAt(
	parent: Instance,
	name: string,
	position: Vector3,
	zone: Vector3,
	spec: EmitterSpec
): ParticleEmitter
	local host = WorldKit.part(parent, name, zone, CFrame.new(position), WHITE)
	host.Transparency = 1
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.CastShadow = false
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = spec.texture
	emitter.Color = spec.color
	emitter.Size = spec.size
	emitter.Transparency = spec.transparency
	emitter.Rate = spec.rate
	emitter.Speed = spec.speed
	emitter.Lifetime = spec.lifetime
	emitter.SpreadAngle = spec.spreadAngle or Vector2.new(12, 12)
	emitter.Acceleration = spec.acceleration or Vector3.zero
	emitter.LightEmission = spec.lightEmission or 0
	emitter.Parent = host
	return emitter
end

local function smokeColumn(parent: Instance, name: string, position: Vector3, scale: number)
	emitterAt(parent, name, position, Vector3.new(1.2, 0.4, 1.2), {
		texture = SMOKE_TEXTURE,
		color = ColorSequence.new(Color3.fromRGB(168, 168, 164), Color3.fromRGB(210, 210, 206)),
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.1 * scale),
			NumberSequenceKeypoint.new(1, 3.4 * scale),
		}),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.62),
			NumberSequenceKeypoint.new(1, 1),
		}),
		rate = 2.4,
		speed = NumberRange.new(0.8, 1.4),
		lifetime = NumberRange.new(3.5, 5.5),
		acceleration = Vector3.new(0.35, 0.6, 0.1),
	})
end

local function blinkLoop(bulb: BasePart, onColor: Color3, offColor: Color3, period: number)
	local light = Instance.new("PointLight")
	light.Color = onColor
	light.Brightness = 1.2
	light.Range = 12
	light.Parent = bulb
	task.spawn(function()
		local on = false
		while bulb.Parent ~= nil do
			on = not on
			bulb.Color = if on then onColor else offColor
			-- Respect the day/night visibility sweep: a hidden (transparent)
			-- bulb must not keep blinking its light through the folder hide.
			light.Enabled = on and bulb.Transparency < 1
			task.wait(period)
		end
	end)
end

local function tallestPartTop(model: Instance): Vector3?
	local best: BasePart? = nil
	local bestTop = -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local top = d.Position.Y + d.Size.Y / 2
			if top > bestTop then
				bestTop = top
				best = d
			end
		end
	end
	if best then
		return Vector3.new(best.Position.X, bestTop, best.Position.Z)
	end
	return nil
end

local function pathStrip(
	parent: Instance,
	name: string,
	fromPos: Vector3,
	toPos: Vector3,
	width: number
)
	local flatFrom = Vector3.new(fromPos.X, 2.92, fromPos.Z)
	local flatTo = Vector3.new(toPos.X, 2.92, toPos.Z)
	local length = (flatTo - flatFrom).Magnitude
	local strip = WorldKit.part(parent, name, Vector3.new(width, 0.3, length),
		CFrame.lookAt((flatFrom + flatTo) / 2, flatTo),
		Color3.fromRGB(128, 108, 78), Enum.Material.Ground)
	strip.CanCollide = false
	strip.CanQuery = false
end

local function barrel(parent: Instance, name: string, position: Vector3): Part
	local body = WorldKit.part(parent, name, Vector3.new(2.6, 2.2, 2.2),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	for _, offset in { -0.8, 0.8 } do
		WorldKit.part(parent, name .. "Ring", Vector3.new(0.24, 2.3, 2.3),
			CFrame.new(position + Vector3.new(0, offset, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	return body
end

-- ---------------------------------------------------------------------------
-- The hundred

type Builder = {
	label: string,
	build: (dayCamp: Instance, nightTown: Instance) -> (),
}

local builders: { Builder } = {
	-- ==================================================== campfire plaza ====
	{ label = "1 log-ring benches", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishLogRing")
		for index = 1, 4 do
			local angle = math.rad(index * 90 - 45)
			local pos = Vector3.new(math.cos(angle) * 9.5, 3.0, math.sin(angle) * 9.5)
			WorldKit.part(m, "RingLog" .. index, Vector3.new(5.4, 1.3, 1.3),
				CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi / 2, 0),
				WOOD_DARK, Enum.Material.Wood, Enum.PartType.Cylinder)
		end
	end },
	{ label = "2 stone fire ring", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishFireStones")
		for index = 1, 8 do
			local angle = index / 8 * math.pi * 2
			WorldKit.part(m, "FireStone" .. index, Vector3.new(1.1, 0.9, 1.1),
				CFrame.new(math.cos(angle) * 3.8, 3.2, math.sin(angle) * 3.8)
					* CFrame.Angles(0, angle, 0),
				STONE_DARK, Enum.Material.Slate)
		end
	end },
	{ label = "3 roasting sticks", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishRoastingSticks")
		for index = 1, 3 do
			local stick = WorldKit.part(m, "Stick" .. index, Vector3.new(0.14, 3.4, 0.14),
				CFrame.new(5.6 + index * 0.35, 3.9, 3.4 - index * 0.3)
					* CFrame.Angles(math.rad(38), math.rad(index * 30), 0),
				WOOD_DARK, Enum.Material.Wood)
			WorldKit.part(m, "Mallow" .. index, Vector3.new(0.4, 0.4, 0.4),
				stick.CFrame * CFrame.new(0, 1.75, 0),
				WHITE, Enum.Material.SmoothPlastic)
		end
	end },
	{ label = "4 campfire embers", build = function(dayCamp, _)
		local fire = dayCamp:FindFirstChild("Campfire")
		local base = if fire and fire:IsA("BasePart")
			then fire.Position + Vector3.new(0, 1.4, 0)
			else Vector3.new(0, 5.4, 0)
		emitterAt(dayCamp, "PolishEmberEmitter", base, Vector3.new(1.6, 0.6, 1.6), {
			texture = SPARKLE_TEXTURE,
			color = ColorSequence.new(Color3.fromRGB(255, 168, 74), Color3.fromRGB(214, 74, 32)),
			size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.28),
				NumberSequenceKeypoint.new(1, 0.06),
			}),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			}),
			rate = 6,
			speed = NumberRange.new(2.2, 4),
			lifetime = NumberRange.new(1.2, 2.4),
			spreadAngle = Vector2.new(16, 16),
			acceleration = Vector3.new(0.4, 2.6, 0.2),
			lightEmission = 1,
		})
	end },
	{ label = "5 campfire smoke", build = function(dayCamp, _)
		local fire = dayCamp:FindFirstChild("Campfire")
		local base = if fire and fire:IsA("BasePart")
			then fire.Position + Vector3.new(0, 2.4, 0)
			else Vector3.new(0, 6.4, 0)
		smokeColumn(dayCamp, "PolishFireSmoke", base, 1.4)
	end },
	{ label = "6 plaza string lights", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishStringLights")
		local a = Vector3.new(-9, 3, -11)
		local b = Vector3.new(10, 3, -9)
		for _, postPos in { a, b } do
			WorldKit.part(m, "LightPost", Vector3.new(0.4, 8.4, 0.4),
				CFrame.new(postPos + Vector3.new(0, 4.2, 0)), WOOD_DARK, Enum.Material.Wood)
		end
		for index = 0, 8 do
			local alpha = index / 8
			local sag = math.sin(alpha * math.pi) * 1.6
			local pos = a:Lerp(b, alpha) + Vector3.new(0, 8 - sag, 0)
			local bulb = WorldKit.part(m, "StringBulb" .. index, Vector3.new(0.34, 0.34, 0.34),
				CFrame.new(pos), Color3.fromRGB(255, 214, 150), Enum.Material.Neon,
				Enum.PartType.Ball)
			bulb.CanCollide = false
			if index % 2 == 0 then
				WorldKit.lamp(bulb, { brightness = 0.5, range = 9 })
			end
		end
	end },
	{ label = "7 carved totem", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishTotem")
		local colors = { Color3.fromRGB(148, 84, 54), Color3.fromRGB(90, 110, 80), Color3.fromRGB(160, 128, 66) }
		for index = 1, 3 do
			local block = WorldKit.part(m, "TotemTier" .. index, Vector3.new(2.2, 2.1, 2.2),
				CFrame.new(-13, 1.6 + index * 2.1, -9), colors[index], Enum.Material.Wood)
			faceText(block, Enum.NormalId.Front, if index == 2 then "◉ ◉" else "▲▽▲", INK)
		end
		WorldKit.part(m, "TotemWings", Vector3.new(5.6, 0.7, 0.7),
			CFrame.new(-13, 8.2, -9), WOOD_DARK, Enum.Material.Wood)
	end },
	{ label = "8 fire bucket stand", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishFireBucket")
		WorldKit.part(m, "BucketPost", Vector3.new(0.4, 3.4, 0.4),
			CFrame.new(-5.5, 4.3, 6.5), WOOD_DARK, Enum.Material.Wood)
		-- Cylinders lie along X; the Z-roll stands the pail upright.
		local pail = WorldKit.part(m, "Bucket", Vector3.new(1.1, 1.3, 1.3),
			CFrame.new(-4.75, 4.9, 6.5) * CFrame.Angles(0, 0, math.rad(90)),
			METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
		WorldKit.part(m, "BucketWater", Vector3.new(0.15, 1.1, 1.1),
			pail.CFrame * CFrame.new(-0.45, 0, 0),
			Color3.fromRGB(84, 128, 160), Enum.Material.Glass, Enum.PartType.Cylinder)
	end },
	{ label = "9 s'mores crate", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishSmoresCrate")
		local crate = WorldKit.part(m, "Crate", Vector3.new(2, 1.4, 1.5),
			CFrame.new(6.5, 3.3, -5.5) * CFrame.Angles(0, math.rad(24), 0),
			WOOD_PALE, Enum.Material.WoodPlanks)
		WorldKit.part(m, "Graham", Vector3.new(0.9, 0.3, 0.9),
			crate.CFrame * CFrame.new(-0.4, 0.85, 0), Color3.fromRGB(196, 152, 94),
			Enum.Material.SmoothPlastic)
		WorldKit.part(m, "Chocolate", Vector3.new(0.8, 0.24, 0.6),
			crate.CFrame * CFrame.new(0.5, 0.82, 0.2), Color3.fromRGB(74, 46, 30),
			Enum.Material.SmoothPlastic)
	end },
	{ label = "10 camp guitar", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishGuitar")
		local body = WorldKit.part(m, "GuitarBody", Vector3.new(0.5, 1.7, 1.4),
			CFrame.new(9.7, 3.5, 2.4) * CFrame.Angles(math.rad(-18), math.rad(30), 0),
			Color3.fromRGB(158, 106, 56), Enum.Material.Wood, Enum.PartType.Cylinder)
		WorldKit.part(m, "GuitarNeck", Vector3.new(0.22, 2.4, 0.34),
			body.CFrame * CFrame.new(0, 1.9, 0), WOOD_DARK, Enum.Material.Wood)
	end },

	-- ================================================= trails & wayfinding ==
	{ label = "11 path to quarters", build = function(dayCamp, _)
		pathStrip(dayCamp, "PolishPathQuarters", Vector3.new(-8, 0, 8), Vector3.new(-40, 0, 56), 3.4)
	end },
	{ label = "12 path to infirmary", build = function(dayCamp, _)
		pathStrip(dayCamp, "PolishPathInfirmary", Vector3.new(8, 0, 8), Vector3.new(20, 0, 56), 3.4)
	end },
	{ label = "13 path to archery", build = function(dayCamp, _)
		pathStrip(dayCamp, "PolishPathArchery", Vector3.new(-8, 0, -8), Vector3.new(-28, 0, -50), 3.4)
	end },
	{ label = "14 path to supply cabin", build = function(dayCamp, _)
		pathStrip(dayCamp, "PolishPathSupply", Vector3.new(-10, 0, -4), Vector3.new(-64, 0, -36), 3.4)
	end },
	{ label = "15 path to lookout", build = function(dayCamp, _)
		pathStrip(dayCamp, "PolishPathLookout", Vector3.new(2, 0, 12), Vector3.new(2, 0, 100), 3.4)
	end },
	{ label = "16 stepping stones", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishSteppingStones")
		-- The bank climbs from ~5.3 toward the swimming hole (~7).
		for index = 0, 4 do
			WorldKit.part(m, "StepStone" .. index, Vector3.new(1.7, 0.35, 1.5),
				CFrame.new(84 + index * 1.9, 5.5 + index * 0.45, 70 + index * 2.1)
					* CFrame.Angles(0, math.rad(index * 22), 0),
				STONE, Enum.Material.Slate)
		end
	end },
	{ label = "17 trail blazes", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishTrailBlazes")
		local spots = {
			Vector3.new(-24, 0, 40), Vector3.new(30, 0, 30),
			Vector3.new(-28, 0, -30), Vector3.new(28, 0, -56),
		}
		for index, spot in spots do
			local post = WorldKit.part(m, "BlazePost" .. index, Vector3.new(0.45, 4.4, 0.45),
				CFrame.new(spot.X, 4.7, spot.Z), WOOD_DARK, Enum.Material.Wood)
			WorldKit.part(m, "Blaze" .. index, Vector3.new(0.5, 0.7, 0.1),
				post.CFrame * CFrame.new(0, 1.3, -0.24),
				Color3.fromRGB(230, 148, 42), Enum.Material.Neon)
		end
	end },
	{ label = "18 plaza fingerpost", build = function(dayCamp, _)
		WorldKit.signpost(dayCamp, Vector3.new(13, 2.6, 8),
			{ "LAKE →", "← RANGER", "TOWN ROAD ↑", "LOOKOUT ↓" })
	end },
	{ label = "19 bluff rope fence", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishBluffFence")
		for index = 0, 3 do
			local x = 66 + index * 5
			WorldKit.part(m, "FencePost" .. index, Vector3.new(0.5, 3.2, 0.5),
				CFrame.new(x, 4.1, 22), WOOD_DARK, Enum.Material.Wood)
			if index > 0 then
				WorldKit.part(m, "FenceRope" .. index, Vector3.new(0.22, 0.22, 5),
					CFrame.new(x - 2.5, 5.1, 22) * CFrame.Angles(0, math.rad(90), 0),
					CANVAS, Enum.Material.Fabric, Enum.PartType.Cylinder)
			end
		end
	end },
	{ label = "20 waypoint lanterns", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishWaypointLanterns")
		local spots = {
			Vector3.new(-38, 0, 52), Vector3.new(18, 0, 52), Vector3.new(-28, 0, -44),
			Vector3.new(58, 0, 34), Vector3.new(2, 0, 94), Vector3.new(-62, 0, -30),
		}
		for index, spot in spots do
			WorldKit.part(m, "WayPost" .. index, Vector3.new(0.45, 5.6, 0.45),
				CFrame.new(spot.X, 5.3, spot.Z), WOOD_DARK, Enum.Material.Wood)
			local head = WorldKit.part(m, "WayGlow" .. index, Vector3.new(0.8, 0.9, 0.8),
				CFrame.new(spot.X, 8.4, spot.Z), Color3.fromRGB(255, 208, 140), Enum.Material.Neon)
			WorldKit.lamp(head, { brightness = 1.0, range = 14 })
		end
	end },

	-- ================================================ nature & ambient life =
	{ label = "21 firefly swarms", build = function(dayCamp, _)
		local spots = { Vector3.new(-40, 6, 30), Vector3.new(30, 6, -40), Vector3.new(-20, 6, 90) }
		for index, spot in spots do
			emitterAt(dayCamp, "PolishFireflies" .. index, spot, Vector3.new(10, 5, 10), {
				texture = SPARKLE_TEXTURE,
				color = ColorSequence.new(Color3.fromRGB(212, 255, 138)),
				size = NumberSequence.new(0.14),
				transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.3, 0.1),
					NumberSequenceKeypoint.new(0.7, 0.2),
					NumberSequenceKeypoint.new(1, 1),
				}),
				rate = 3,
				speed = NumberRange.new(0.4, 1),
				lifetime = NumberRange.new(3, 6),
				spreadAngle = Vector2.new(180, 180),
				lightEmission = 1,
			})
		end
	end },
	{ label = "22 meadow butterflies", build = function(dayCamp, _)
		for index, spot in { Vector3.new(10, 4.6, 30), Vector3.new(-32, 4.6, 44) } do
			emitterAt(dayCamp, "PolishButterflies" .. index, spot, Vector3.new(8, 3, 8), {
				texture = SPARKLE_TEXTURE,
				color = ColorSequence.new(Color3.fromRGB(240, 240, 255), Color3.fromRGB(255, 226, 140)),
				size = NumberSequence.new(0.22),
				transparency = NumberSequence.new(0.25),
				rate = 1.6,
				speed = NumberRange.new(0.6, 1.4),
				lifetime = NumberRange.new(2.5, 4),
				spreadAngle = Vector2.new(180, 60),
			})
		end
	end },
	{ label = "23 perched crows", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishCrows")
		for index, spot in { Vector3.new(2, 29, 112), Vector3.new(64, 12.6, 60) } do
			local body = WorldKit.part(m, "CrowBody" .. index, Vector3.new(0.5, 0.55, 1.0),
				CFrame.new(spot) * CFrame.Angles(0, math.rad(index * 130), 0),
				Color3.fromRGB(24, 24, 28), Enum.Material.SmoothPlastic)
			WorldKit.part(m, "CrowHead" .. index, Vector3.new(0.34, 0.34, 0.4),
				body.CFrame * CFrame.new(0, 0.4, -0.5),
				Color3.fromRGB(24, 24, 28), Enum.Material.SmoothPlastic)
		end
	end },
	{ label = "24 quarters owl", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishOwl")
		local body = WorldKit.part(m, "OwlBody", Vector3.new(0.8, 1.1, 0.7),
			CFrame.new(-33, 13.2, 75), Color3.fromRGB(118, 96, 70), Enum.Material.SmoothPlastic)
		for side = -1, 1, 2 do
			WorldKit.part(m, "OwlEye", Vector3.new(0.2, 0.2, 0.1),
				body.CFrame * CFrame.new(side * 0.18, 0.32, -0.34),
				Color3.fromRGB(255, 214, 82), Enum.Material.Neon)
		end
	end },
	{ label = "25 mushroom clusters", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishMushrooms")
		local spots = {
			Vector3.new(-52, 0, 34), Vector3.new(38, 0, -32), Vector3.new(-14, 0, -44),
			Vector3.new(52, 0, 8), Vector3.new(-58, 0, 66),
		}
		for clusterIndex, spot in spots do
			for shroom = 1, 3 do
				local offset = Vector3.new(math.cos(shroom * 2.1) * 0.9, 0, math.sin(shroom * 2.1) * 0.9)
				local height = 0.5 + shroom * 0.16
				WorldKit.part(m, "ShroomStem" .. clusterIndex .. shroom,
					Vector3.new(0.22, height, 0.22),
					CFrame.new(spot + offset + Vector3.new(0, 2.5 + height / 2, 0)),
					PAPER, Enum.Material.SmoothPlastic)
				WorldKit.part(m, "ShroomCap" .. clusterIndex .. shroom,
					Vector3.new(0.6, 0.34, 0.6),
					CFrame.new(spot + offset + Vector3.new(0, 2.5 + height + 0.14, 0)),
					RED, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			end
		end
	end },
	{ label = "26 wildflower patches", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishFlowers")
		local colors = {
			Color3.fromRGB(238, 208, 84), Color3.fromRGB(186, 122, 214),
			Color3.fromRGB(238, 148, 148),
		}
		for index = 1, 6 do
			local angle = index / 6 * math.pi * 2
			local base = Vector3.new(math.cos(angle) * 28, 0, math.sin(angle) * 26)
			for flower = 1, 4 do
				local offset = Vector3.new(math.cos(flower * 1.7) * 1.4, 0, math.sin(flower * 1.7) * 1.4)
				WorldKit.part(m, "FlowerStem" .. index .. flower, Vector3.new(0.1, 0.7, 0.1),
					CFrame.new(base + offset + Vector3.new(0, 2.85, 0)), LEAF, Enum.Material.Grass)
				local bloom = WorldKit.part(m, "FlowerBloom" .. index .. flower,
					Vector3.new(0.34, 0.2, 0.34),
					CFrame.new(base + offset + Vector3.new(0, 3.3, 0)),
					colors[(index + flower) % 3 + 1], Enum.Material.SmoothPlastic,
					Enum.PartType.Ball)
				bloom.CanCollide = false
			end
		end
	end },
	{ label = "27 lakeside cattails", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishCattails")
		local spots = {
			Vector3.new(86, 0, 64), Vector3.new(90, 0, 68), Vector3.new(82, 0, 60), Vector3.new(94, 0, 70),
		}
		for index, spot in spots do
			for reed = 1, 3 do
				local offset = Vector3.new(math.cos(reed * 2.4) * 0.7, 0, math.sin(reed * 2.4) * 0.7)
				local height = 2.4 + reed * 0.3
				-- Shoreline grade here is ~4, not the 2.5 camp-bowl grass.
				WorldKit.part(m, "Reed" .. index .. reed, Vector3.new(0.12, height, 0.12),
					CFrame.new(spot + offset + Vector3.new(0, 3.7 + height / 2, 0))
						* CFrame.Angles(math.rad(reed * 2), 0, math.rad(4 - reed * 2)),
					LEAF, Enum.Material.Grass)
				WorldKit.part(m, "CattailHead" .. index .. reed, Vector3.new(0.7, 0.22, 0.22),
					CFrame.new(spot + offset + Vector3.new(0, 3.7 + height + 0.3, 0))
						* CFrame.Angles(0, 0, math.rad(90)),
					Color3.fromRGB(92, 62, 40), Enum.Material.Fabric, Enum.PartType.Cylinder)
			end
		end
	end },
	{ label = "28 lily pads", build = function(dayCamp, _)
		-- Anchor to the lake buoys: they are the one guaranteed open-water
		-- reference (fixed coordinates here landed on the firewatch island).
		local m = WorldKit.model(dayCamp, "PolishLilyPads")
		local buoys: { BasePart } = {}
		for _, d in dayCamp:GetChildren() do
			if d.Name:find("LakeBuoy") and d:IsA("BasePart") then
				table.insert(buoys, d)
			end
		end
		if #buoys == 0 then
			error("no lake buoys to anchor lily pads")
		end
		local padIndex = 0
		for _, buoy in buoys do
			for cluster = 1, 2 do
				padIndex += 1
				local offset = Vector3.new(math.cos(padIndex * 2.4) * 3.2, 0, math.sin(padIndex * 2.4) * 3.2)
				local pad = WorldKit.part(m, "LilyPad" .. padIndex, Vector3.new(0.08, 1.5, 1.5),
					CFrame.new(buoy.Position.X + offset.X, buoy.Position.Y + 0.1, buoy.Position.Z + offset.Z)
						* CFrame.Angles(0, math.rad(padIndex * 47), math.rad(90)),
					Color3.fromRGB(74, 126, 62), Enum.Material.Grass, Enum.PartType.Cylinder)
				pad.CanCollide = false
			end
		end
	end },
	{ label = "29 mossy fallen log", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishMossyLog")
		local log = WorldKit.part(m, "MossyLog", Vector3.new(7, 1.6, 1.6),
			CFrame.new(66, 3.4, 80) * CFrame.Angles(0, math.rad(28), 0),
			WOOD_DARK, Enum.Material.Wood, Enum.PartType.Cylinder)
		WorldKit.part(m, "Moss", Vector3.new(4.4, 0.2, 1.2),
			log.CFrame * CFrame.new(0, 0.75, 0),
			Color3.fromRGB(88, 128, 70), Enum.Material.Grass)
	end },
	{ label = "30 chopping stump", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishChoppingStump")
		local stump = WorldKit.part(m, "Stump", Vector3.new(2.2, 1.4, 2.2),
			CFrame.new(-68, 3.2, -28), WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
		WorldKit.part(m, "AxeHandle", Vector3.new(0.16, 2.1, 0.16),
			stump.CFrame * CFrame.new(0.4, 1.4, 0.2) * CFrame.Angles(0, 0, math.rad(-38)),
			WOOD_PALE, Enum.Material.Wood)
		WorldKit.part(m, "AxeHead", Vector3.new(0.18, 0.5, 0.8),
			stump.CFrame * CFrame.new(-0.28, 2.06, 0.2) * CFrame.Angles(0, 0, math.rad(-38)),
			METAL, Enum.Material.Metal)
		for chip = 1, 4 do
			WorldKit.part(m, "WoodChip" .. chip, Vector3.new(0.5, 0.16, 0.3),
				CFrame.new(-68 + math.cos(chip * 1.9) * 2.2, 2.62, -28 + math.sin(chip * 1.9) * 2.2)
					* CFrame.Angles(0, chip, 0),
				WOOD_PALE, Enum.Material.Wood)
		end
	end },
	{ label = "31 firewood cord", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishFirewoodCord")
		for row = 0, 1 do
			for index = 0, 5 do
				WorldKit.part(m, "CordLog" .. row .. index, Vector3.new(2.4, 0.8, 0.8),
					CFrame.new(-70 + row * 0.1, 2.95 + row * 0.8, -32 + index * 0.85),
					WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
			end
		end
	end },
	{ label = "32 berry bushes", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishBerryBushes")
		-- All four on the flat west-meadow strip; the dome flank starts at
		-- x < -86 near z 5-15.
		local spots = {
			Vector3.new(-88, 0, -30), Vector3.new(-92, 0, -20), Vector3.new(-84, 0, 0), Vector3.new(-84, 0, 8),
		}
		for index, spot in spots do
			local bush = WorldKit.part(m, "Bush" .. index, Vector3.new(2.6, 2.2, 2.6),
				CFrame.new(spot + Vector3.new(0, 4.0, 0)), LEAF, Enum.Material.Grass,
				Enum.PartType.Ball)
			for berry = 1, 5 do
				local offset = Vector3.new(
					math.cos(berry * 2.4) * 1.1,
					math.sin(berry * 1.3) * 0.7,
					math.sin(berry * 2.4) * 1.1
				)
				local fruit = WorldKit.part(m, "Berry" .. index .. berry, Vector3.new(0.2, 0.2, 0.2),
					bush.CFrame * CFrame.new(offset), Color3.fromRGB(170, 40, 60),
					Enum.Material.SmoothPlastic, Enum.PartType.Ball)
				fruit.CanCollide = false
			end
		end
	end },
	{ label = "33 cairn marker", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishCairn")
		local sizes = { 1.4, 1.05, 0.7, 0.4 }
		local y = 2.6
		for index, size in sizes do
			y += size * 0.42
			WorldKit.part(m, "CairnStone" .. index, Vector3.new(size, size * 0.7, size),
				CFrame.new(74, y, -22) * CFrame.Angles(0, index * 0.8, 0),
				STONE, Enum.Material.Slate)
			y += size * 0.28
		end
	end },
	{ label = "34 grazing deer", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishDeer")
		for index, spot in { Vector3.new(150, 0, 24), Vector3.new(156, 0, 18) } do
			local scale = if index == 1 then 1 else 0.7
			local body = WorldKit.part(m, "DeerBody" .. index,
				Vector3.new(1.1, 1.2, 2.6) * scale,
				CFrame.new(spot + Vector3.new(0, 2.5 + 1.5 * scale, 0))
					* CFrame.Angles(0, math.rad(index * 70), 0),
				Color3.fromRGB(140, 104, 70), Enum.Material.SmoothPlastic)
			WorldKit.part(m, "DeerHead" .. index, Vector3.new(0.6, 0.7, 0.9) * scale,
				body.CFrame * CFrame.new(0, 0.85 * scale, -1.5 * scale),
				Color3.fromRGB(140, 104, 70), Enum.Material.SmoothPlastic)
			for leg = 1, 4 do
				local lx = if leg % 2 == 0 then 0.35 else -0.35
				local lz = if leg <= 2 then -0.9 else 0.9
				WorldKit.part(m, "DeerLeg" .. index .. leg,
					Vector3.new(0.22, 1.5, 0.22) * scale,
					body.CFrame * CFrame.new(lx * scale, -1.3 * scale, lz * scale),
					Color3.fromRGB(122, 90, 60), Enum.Material.SmoothPlastic)
			end
		end
	end },
	{ label = "35 lawn rabbits", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishRabbits")
		for index, spot in { Vector3.new(-44, 0, 48), Vector3.new(-52, 0, 52) } do
			local body = WorldKit.part(m, "RabbitBody" .. index, Vector3.new(0.5, 0.5, 0.8),
				CFrame.new(spot + Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, index * 2.1, 0),
				Color3.fromRGB(196, 186, 172), Enum.Material.Fabric)
			WorldKit.part(m, "RabbitEars" .. index, Vector3.new(0.3, 0.5, 0.1),
				body.CFrame * CFrame.new(0, 0.45, -0.3),
				Color3.fromRGB(196, 186, 172), Enum.Material.Fabric)
		end
	end },
	{ label = "36 roof squirrel", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishSquirrel")
		local body = WorldKit.part(m, "SquirrelBody", Vector3.new(0.35, 0.4, 0.7),
			CFrame.new(50, 15.4, 16) * CFrame.Angles(0, math.rad(40), 0),
			Color3.fromRGB(134, 84, 48), Enum.Material.Fabric)
		WorldKit.part(m, "SquirrelTail", Vector3.new(0.25, 0.8, 0.25),
			body.CFrame * CFrame.new(0, 0.35, 0.45) * CFrame.Angles(math.rad(-30), 0, 0),
			Color3.fromRGB(134, 84, 48), Enum.Material.Fabric)
	end },
	{ label = "37 pine beehive", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishBeehive")
		local hive = WorldKit.part(m, "Hive", Vector3.new(1.1, 1.5, 1.1),
			CFrame.new(34, 10.6, 66), Color3.fromRGB(188, 158, 92), Enum.Material.Sand,
			Enum.PartType.Ball)
		emitterAt(m, "BeeMotes", hive.Position - Vector3.new(0, 1, 0), Vector3.new(2, 2, 2), {
			texture = SPARKLE_TEXTURE,
			color = ColorSequence.new(Color3.fromRGB(230, 190, 60)),
			size = NumberSequence.new(0.1),
			transparency = NumberSequence.new(0.3),
			rate = 4,
			speed = NumberRange.new(0.5, 1.2),
			lifetime = NumberRange.new(1.5, 2.5),
			spreadAngle = Vector2.new(180, 180),
		})
	end },
	{ label = "38 chapel spider web", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishSpiderWeb")
		for index = 0, 2 do
			local rod = WorldKit.part(m, "WebRod" .. index, Vector3.new(0.06, 1.7, 0.06),
				CFrame.new(-25.4, 10.2, 48.4) * CFrame.Angles(0, 0, math.rad(index * 60 - 60)),
				WHITE, Enum.Material.Neon)
			rod.Transparency = 0.55
			rod.CanCollide = false
		end
	end },

	-- ========================================================== lakefront ===
	{ label = "39 beach towels + umbrella", build = function(dayCamp, _)
		-- The sand dunes fill to ~6, well above the camp-bowl grass.
		local m = WorldKit.model(dayCamp, "PolishBeachSet")
		WorldKit.part(m, "TowelA", Vector3.new(2.4, 0.12, 4),
			CFrame.new(76, 6.15, 44) * CFrame.Angles(0, math.rad(12), 0),
			Color3.fromRGB(212, 96, 82), Enum.Material.Fabric)
		WorldKit.part(m, "TowelB", Vector3.new(2.4, 0.12, 4),
			CFrame.new(80, 6.05, 48) * CFrame.Angles(0, math.rad(-20), 0),
			Color3.fromRGB(94, 148, 198), Enum.Material.Fabric)
		WorldKit.part(m, "UmbrellaPole", Vector3.new(0.22, 5.8, 0.22),
			CFrame.new(78, 8.8, 46) * CFrame.Angles(0, 0, math.rad(-8)),
			METAL, Enum.Material.Metal)
		WorldKit.part(m, "UmbrellaTop", Vector3.new(0.5, 5.4, 5.4),
			CFrame.new(77.6, 11.6, 46) * CFrame.Angles(0, 0, math.rad(82)),
			Color3.fromRGB(226, 190, 92), Enum.Material.Fabric, Enum.PartType.Cylinder)
	end },
	{ label = "40 sandcastle", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishSandcastle")
		local sand = Color3.fromRGB(212, 190, 140)
		WorldKit.part(m, "CastleBase", Vector3.new(2.6, 1, 2.6),
			CFrame.new(82, 6.3, 54), sand, Enum.Material.Sand)
		for corner = 1, 4 do
			local cx = if corner % 2 == 0 then 1.1 else -1.1
			local cz = if corner <= 2 then 1.1 else -1.1
			WorldKit.part(m, "CastleTower" .. corner, Vector3.new(1.7, 0.8, 0.8),
				CFrame.new(82 + cx, 6.65, 54 + cz) * CFrame.Angles(0, 0, math.rad(90)),
				sand, Enum.Material.Sand, Enum.PartType.Cylinder)
		end
	end },
	{ label = "41 dock life ring", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishLifeRing")
		local ring = WorldKit.part(m, "LifeRing", Vector3.new(0.35, 1.7, 1.7),
			CFrame.new(92, 5.6, 32.4) * CFrame.Angles(0, math.rad(90), math.rad(90)),
			WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		for index = 0, 3 do
			WorldKit.part(m, "RingStripe" .. index, Vector3.new(0.38, 0.5, 0.42),
				ring.CFrame * CFrame.Angles(math.rad(index * 90), 0, 0) * CFrame.new(0, 0.72, 0),
				RED, Enum.Material.SmoothPlastic)
		end
	end },
	{ label = "42 dock fishing rod", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishFishingRod")
		WorldKit.part(m, "RodHolder", Vector3.new(0.4, 1.1, 0.4),
			CFrame.new(96.6, 4.6, 37), WOOD_DARK, Enum.Material.Wood)
		local rod = WorldKit.part(m, "Rod", Vector3.new(0.1, 4.6, 0.1),
			CFrame.new(97.2, 6.4, 38) * CFrame.Angles(math.rad(38), math.rad(20), 0),
			WOOD_PALE, Enum.Material.Wood)
		local line = WorldKit.part(m, "FishLine", Vector3.new(0.03, 4.4, 0.03),
			rod.CFrame * CFrame.new(0, 2.2, 0) * CFrame.Angles(math.rad(-38), 0, 0)
				* CFrame.new(0, -2.2, 0),
			WHITE, Enum.Material.Neon)
		line.Transparency = 0.4
		line.CanCollide = false
	end },
	{ label = "43 tackle box", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishTackle")
		WorldKit.part(m, "TackleBox", Vector3.new(1.3, 0.8, 0.8),
			CFrame.new(95, 4.5, 35.4) * CFrame.Angles(0, math.rad(14), 0),
			Color3.fromRGB(64, 110, 74), Enum.Material.Metal)
		WorldKit.part(m, "BaitBucket", Vector3.new(0.9, 0.9, 0.9),
			CFrame.new(94, 4.55, 36.6) * CFrame.Angles(0, 0, math.rad(90)),
			METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	end },
	{ label = "44 floating lantern buoy", build = function(dayCamp, _)
		-- Water surface renders at ~4.2 (the lake buoy line), not 2.
		local m = WorldKit.model(dayCamp, "PolishLanternBuoy")
		WorldKit.part(m, "BuoyFloat", Vector3.new(0.8, 1.4, 1.4),
			CFrame.new(97, 4.25, 64) * CFrame.Angles(0, 0, math.rad(90)),
			WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
		local glow = WorldKit.part(m, "BuoyGlow", Vector3.new(0.6, 0.7, 0.6),
			CFrame.new(97, 5.2, 64), Color3.fromRGB(255, 208, 140), Enum.Material.Neon)
		WorldKit.lamp(glow, { brightness = 1.1, range = 13 })
	end },
	{ label = "45 canoe paddles", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishPaddles")
		for index = 1, 2 do
			local shaft = WorldKit.part(m, "PaddleShaft" .. index, Vector3.new(0.14, 3.4, 0.14),
				CFrame.new(84 + index * 0.5, 6.4, 40) * CFrame.Angles(0, 0, math.rad(14 - index * 6)),
				WOOD_PALE, Enum.Material.Wood)
			WorldKit.part(m, "PaddleBlade" .. index, Vector3.new(0.7, 1.1, 0.12),
				shaft.CFrame * CFrame.new(0, -1.9, 0), WOOD, Enum.Material.Wood)
		end
	end },
	{ label = "46 beach safety sign", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishBeachSign")
		WorldKit.part(m, "SignPost", Vector3.new(0.4, 4.6, 0.4),
			CFrame.new(72, 7.9, 38), WOOD_DARK, Enum.Material.Wood)
		local board = WorldKit.part(m, "SignBoard", Vector3.new(4.2, 1.6, 0.25),
			CFrame.new(72, 9.5, 38) * CFrame.Angles(0, math.rad(-30), 0),
			WOOD_PALE, Enum.Material.WoodPlanks)
		faceText(board, Enum.NormalId.Front, "NO SWIMMING\nAFTER DARK", INK)
	end },
	{ label = "47 rowboat oars", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishOars")
		for index = 1, 2 do
			WorldKit.part(m, "Oar" .. index, Vector3.new(0.14, 4.2, 0.14),
				CFrame.new(97 + index, 5.1, 41.5) * CFrame.Angles(math.rad(80), 0, math.rad(index * 16)),
				WOOD_PALE, Enum.Material.Wood)
		end
	end },
	{ label = "48 dock water ripples", build = function(dayCamp, _)
		emitterAt(dayCamp, "PolishRipples", Vector3.new(90, 2.25, 33), Vector3.new(4, 0.2, 4), {
			texture = SMOKE_TEXTURE,
			color = ColorSequence.new(Color3.fromRGB(220, 236, 240)),
			size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(1, 1.8),
			}),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.82),
				NumberSequenceKeypoint.new(1, 1),
			}),
			rate = 1.4,
			speed = NumberRange.new(0, 0.05),
			lifetime = NumberRange.new(2, 3),
			spreadAngle = Vector2.new(2, 2),
		})
	end },
	{ label = "49 shoreline driftwood", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishDriftwood")
		local spots = { Vector3.new(70, 0, 30), Vector3.new(74, 0, 58), Vector3.new(68, 0, 50) }
		for index, spot in spots do
			-- Cylinders already lie along X; yaw only, on the dune top (~6).
			WorldKit.part(m, "Driftwood" .. index, Vector3.new(3.2 + index * 0.6, 0.7, 0.7),
				CFrame.new(spot + Vector3.new(0, 6.25, 0)) * CFrame.Angles(0, index * 1.4, 0),
				Color3.fromRGB(168, 152, 128), Enum.Material.Wood, Enum.PartType.Cylinder)
		end
	end },
	{ label = "50 diving raft", build = function(dayCamp, _)
		-- Anchored to open water via the buoys, like the lily pads.
		local m = WorldKit.model(dayCamp, "PolishDivingRaft")
		local anchor: BasePart? = nil
		for _, d in dayCamp:GetChildren() do
			if d.Name:find("LakeBuoy") and d:IsA("BasePart") then
				anchor = d
				break
			end
		end
		if not anchor then
			error("no lake buoy to anchor the raft")
		end
		local buoy = anchor :: BasePart
		local base = Vector3.new(buoy.Position.X + 7, buoy.Position.Y + 0.3, buoy.Position.Z + 4)
		WorldKit.part(m, "RaftDeck", Vector3.new(5, 0.5, 5),
			CFrame.new(base), WOOD_PALE, Enum.Material.WoodPlanks)
		for corner = 1, 4 do
			local cx = if corner % 2 == 0 then 2 else -2
			local cz = if corner <= 2 then 2 else -2
			local drum = WorldKit.part(m, "RaftDrum" .. corner, Vector3.new(1.4, 1.2, 1.2),
				CFrame.new(base + Vector3.new(cx, -0.6, cz)),
				Color3.fromRGB(150, 60, 50), Enum.Material.Metal, Enum.PartType.Cylinder)
			drum.CanCollide = false
		end
	end },

	-- ============================================== camp buildings polish ===
	{ label = "51 chimney smoke", build = function(dayCamp, _)
		smokeColumn(dayCamp, "PolishSmokePine", Vector3.new(-54, 21.6, 20), 1)
		smokeColumn(dayCamp, "PolishSmokeCreek", Vector3.new(54, 21.6, 20), 1)
		smokeColumn(dayCamp, "PolishSmokeLodge", Vector3.new(0, 21.6, 76), 1.2)
	end },
	{ label = "52 porch doormats", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishDoormats")
		local spots = {
			Vector3.new(-54, 1.45, 8.6), Vector3.new(54, 1.45, 8.6),
			Vector3.new(0, 1.45, 64.6), Vector3.new(-76, 1.45, -51.4),
		}
		for index, spot in spots do
			local mat = WorldKit.part(m, "Doormat" .. index, Vector3.new(3, 0.14, 1.7),
				CFrame.new(spot), Color3.fromRGB(102, 84, 58), Enum.Material.Fabric)
			mat.CanCollide = false
		end
	end },
	{ label = "53 quarters mailboxes", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishMailboxes")
		local spots = {
			Vector3.new(-34.4, 2, 62.4), Vector3.new(-41.4, 2, 65.9), Vector3.new(-48.4, 2, 67.4),
			Vector3.new(-55.4, 2, 68.4), Vector3.new(-61.9, 2, 65.4), Vector3.new(-67.4, 3.5, 58.6),
		}
		for index, spot in spots do
			WorldKit.part(m, "MailPost" .. index, Vector3.new(0.3, 2.4, 0.3),
				CFrame.new(spot.X, spot.Y + 1.7, spot.Z), WOOD_DARK, Enum.Material.Wood)
			WorldKit.part(m, "MailBox" .. index, Vector3.new(0.8, 0.7, 1.2),
				CFrame.new(spot.X, spot.Y + 3.2, spot.Z), METAL, Enum.Material.Metal)
		end
	end },
	{ label = "54 quarters clothesline", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishQuartersLaundry")
		local a = Vector3.new(-64, 0, 75)
		local b = Vector3.new(-57, 0, 77.5)
		for _, spot in { a, b } do
			WorldKit.part(m, "LaundryPole", Vector3.new(0.35, 5.4, 0.35),
				CFrame.new(spot.X, 5.2, spot.Z), WOOD_DARK, Enum.Material.Wood)
		end
		local mid = (a + b) / 2
		local span = (b - a).Magnitude
		WorldKit.part(m, "LaundryLine", Vector3.new(0.08, 0.08, span),
			CFrame.lookAt(Vector3.new(mid.X, 7.6, mid.Z), Vector3.new(b.X, 7.6, b.Z)),
			WHITE, Enum.Material.Fabric)
		for index = 1, 2 do
			local alpha = index / 3
			local pos = a:Lerp(b, alpha)
			WorldKit.part(m, "LaundryTowel" .. index, Vector3.new(1.4, 1.7, 0.1),
				CFrame.lookAt(Vector3.new(pos.X, 6.7, pos.Z), Vector3.new(b.X, 6.7, b.Z)),
				if index == 1 then Color3.fromRGB(198, 120, 96) else Color3.fromRGB(120, 148, 178),
				Enum.Material.Fabric)
		end
	end },
	{ label = "55 rain barrels", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishRainBarrels")
		local spots = {
			Vector3.new(-51.5, 4.2, 74.8), Vector3.new(30.4, 4.2, 66.6), Vector3.new(-71, 3.7, -36),
		}
		for index, spot in spots do
			WorldKit.part(m, "RainBarrel" .. index, Vector3.new(2.4, 2, 2),
				CFrame.new(spot) * CFrame.Angles(0, 0, math.rad(90)),
				WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
			WorldKit.part(m, "BarrelWater" .. index, Vector3.new(0.12, 1.7, 1.7),
				CFrame.new(spot + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(70, 104, 128), Enum.Material.Glass, Enum.PartType.Cylinder)
		end
	end },
	{ label = "56 lodge window boxes", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishWindowBoxes")
		for index, x in { -4, 4 } do
			WorldKit.part(m, "WindowBox" .. index, Vector3.new(2.4, 0.6, 0.7),
				CFrame.new(x, 4.6, 65.4), WOOD_DARK, Enum.Material.Wood)
			for bloom = 1, 3 do
				local flower = WorldKit.part(m, "BoxBloom" .. index .. bloom,
					Vector3.new(0.3, 0.3, 0.3),
					CFrame.new(x - 0.8 + bloom * 0.5, 5.1, 65.4),
					if bloom == 2 then Color3.fromRGB(226, 160, 84) else RED,
					Enum.Material.SmoothPlastic, Enum.PartType.Ball)
				flower.CanCollide = false
			end
		end
	end },
	{ label = "57 door lanterns", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishDoorLanterns")
		local spots = {
			Vector3.new(-52, 7, 9.7), Vector3.new(56, 7, 9.7),
			Vector3.new(2, 7, 65.7), Vector3.new(-74, 7, -49.7),
		}
		for index, spot in spots do
			WorldKit.part(m, "DoorBracket" .. index, Vector3.new(0.2, 0.2, 0.9),
				CFrame.new(spot), METAL, Enum.Material.Metal)
			local glow = WorldKit.part(m, "DoorGlow" .. index, Vector3.new(0.5, 0.6, 0.5),
				CFrame.new(spot + Vector3.new(0, -0.5, 0.35)),
				Color3.fromRGB(255, 208, 140), Enum.Material.Neon)
			glow.CanCollide = false
			WorldKit.lamp(glow, { brightness = 0.9, range = 11, generatorGated = true })
		end
	end },
	{ label = "58 lodge firewood", build = function(dayCamp, _)
		-- West of the lodge door: the east side is the storm-cellar hatch
		-- approach and must stay clear.
		local m = WorldKit.model(dayCamp, "PolishLodgeFirewood")
		for row = 0, 1 do
			for index = 0, 3 do
				WorldKit.part(m, "PorchLog" .. row .. index, Vector3.new(1.8, 0.7, 0.7),
					CFrame.new(-8.5, 3.0 + row * 0.7, 66.5 + index * 0.75),
					WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
			end
		end
	end },
	{ label = "59 camp notice board", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishNoticeBoard")
		for _, x in { -1.6, 1.6 } do
			WorldKit.part(m, "BoardPost", Vector3.new(0.4, 5, 0.4),
				CFrame.new(-16 + x, 5, 12), WOOD_DARK, Enum.Material.Wood)
		end
		local board = WorldKit.part(m, "Board", Vector3.new(4.4, 2.6, 0.3),
			CFrame.new(-16, 6, 12), WOOD, Enum.Material.WoodPlanks)
		faceText(board, Enum.NormalId.Back, "CAMP NOTICES", PAPER)
		for index = 1, 3 do
			local note = WorldKit.part(m, "Notice" .. index, Vector3.new(0.9, 1.1, 0.06),
				board.CFrame * CFrame.new(-1.4 + index * 0.95, -0.3, 0.2)
					* CFrame.Angles(0, 0, math.rad(index * 7 - 14)),
				PAPER, Enum.Material.SmoothPlastic)
			note.CanCollide = false
		end
	end },
	{ label = "60 infirmary flag", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishMedFlag")
		WorldKit.part(m, "MedPole", Vector3.new(0.3, 8, 0.3),
			CFrame.new(31.4, 7, 55.4), METAL, Enum.Material.Metal)
		local flag = WorldKit.part(m, "MedFlag", Vector3.new(2.4, 1.6, 0.12),
			CFrame.new(32.9, 10, 55.4), WHITE, Enum.Material.Fabric)
		WorldKit.part(m, "MedCrossV", Vector3.new(0.4, 1.1, 0.14),
			flag.CFrame * CFrame.new(0, 0, -0.02), RED, Enum.Material.SmoothPlastic)
			.CanCollide = false
		WorldKit.part(m, "MedCrossH", Vector3.new(1.1, 0.4, 0.14),
			flag.CFrame * CFrame.new(0, 0, -0.02), RED, Enum.Material.SmoothPlastic)
			.CanCollide = false
	end },
	{ label = "61 greenhouse pots", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishGreenhousePots")
		for index = 1, 3 do
			local spot = Vector3.new(47 + index * 2, 3.1, 33.6 - index * 0.4)
			WorldKit.part(m, "Pot" .. index, Vector3.new(1, 1, 1),
				CFrame.new(spot) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(150, 92, 62), Enum.Material.Concrete, Enum.PartType.Cylinder)
			local plant = WorldKit.part(m, "PotPlant" .. index, Vector3.new(1, 1, 1),
				CFrame.new(spot + Vector3.new(0, 0.85, 0)), LEAF, Enum.Material.Grass,
				Enum.PartType.Ball)
			plant.CanCollide = false
		end
	end },
	{ label = "62 outhouse sundries", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishOuthouseProps")
		WorldKit.part(m, "BroomHandle", Vector3.new(0.12, 3.2, 0.12),
			CFrame.new(-18.4, 4.2, 67.4) * CFrame.Angles(0, 0, math.rad(-16)),
			WOOD_PALE, Enum.Material.Wood)
		WorldKit.part(m, "BroomHead", Vector3.new(0.7, 0.7, 0.3),
			CFrame.new(-18.9, 2.85, 67.4) * CFrame.Angles(0, 0, math.rad(-16)),
			LEAF_DRY, Enum.Material.Fabric)
		local roll = WorldKit.part(m, "PaperRoll", Vector3.new(0.5, 0.4, 0.5),
			CFrame.new(-21.4, 4.7, 66.9), WHITE, Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder)
		roll.CFrame = CFrame.new(-21.4, 4.7, 66.9) * CFrame.Angles(0, 0, math.rad(90))
	end },

	-- ===================================================== town night zone ==
	{ label = "63 police roof crow", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishPoliceCrow")
		local body = WorldKit.part(m, "CrowBody", Vector3.new(0.5, 0.55, 1.0),
			CFrame.new(92, 36, -352) * CFrame.Angles(0, math.rad(210), 0),
			Color3.fromRGB(24, 24, 28), Enum.Material.SmoothPlastic)
		WorldKit.part(m, "CrowHead", Vector3.new(0.34, 0.34, 0.4),
			body.CFrame * CFrame.new(0, 0.4, -0.5), Color3.fromRGB(24, 24, 28),
			Enum.Material.SmoothPlastic)
	end },
	{ label = "64 road newspapers", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishNewspapers")
		local spots = {
			Vector3.new(-4, 0, -150), Vector3.new(6, 0, -196), Vector3.new(-7, 0, -252),
			Vector3.new(3, 0, -308), Vector3.new(-2, 0, -366), Vector3.new(7, 0, -412),
		}
		for index, spot in spots do
			local page = WorldKit.part(m, "Newsprint" .. index, Vector3.new(1.3, 0.05, 1.8),
				CFrame.new(spot.X, 0.62, spot.Z) * CFrame.Angles(0, index * 1.2, 0),
				Color3.fromRGB(206, 202, 188), Enum.Material.SmoothPlastic)
			page.CanCollide = false
		end
	end },
	{ label = "65 tumbleweeds", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishTumbleweeds")
		for index, spot in { Vector3.new(8, 0, -220), Vector3.new(-6, 0, -310) } do
			local weed = WorldKit.part(m, "Tumbleweed" .. index, Vector3.new(1.8, 1.8, 1.8),
				CFrame.new(spot.X, 1.5, spot.Z), LEAF_DRY, Enum.Material.Grass,
				Enum.PartType.Ball)
			weed.Transparency = 0.25
		end
	end },
	{ label = "66 boarded rowhouse windows", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishBoardedWindows")
		for index, z in { -192, -210 } do
			for plank = -1, 1, 2 do
				WorldKit.part(m, "BoardPlank" .. index .. plank, Vector3.new(0.2, 0.5, 3.4),
					CFrame.new(127.4, 6, z) * CFrame.Angles(math.rad(plank * 32), 0, 0),
					WOOD_DARK, Enum.Material.WoodPlanks)
			end
		end
	end },
	{ label = "67 asphalt cracks", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishRoadCracks")
		local spots = {
			Vector3.new(-2, 0, -160), Vector3.new(3, 0, -240),
			Vector3.new(-4, 0, -330), Vector3.new(2, 0, -410),
		}
		for index, spot in spots do
			local crack = WorldKit.part(m, "Crack" .. index, Vector3.new(0.6, 0.04, 4.6),
				CFrame.new(spot.X, 0.6, spot.Z) * CFrame.Angles(0, index * 0.9, 0),
				Color3.fromRGB(22, 24, 26), Enum.Material.Asphalt)
			crack.CanCollide = false
		end
	end },
	{ label = "68 leaning bicycle", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishBicycle")
		local base = CFrame.new(176, 0, -146) * CFrame.Angles(0, math.rad(30), math.rad(12))
		for index, offset in { Vector3.new(-1.1, 1.05, 0), Vector3.new(1.1, 1.05, 0) } do
			local wheel = WorldKit.part(m, "BikeWheel" .. index, Vector3.new(0.14, 1.5, 1.5),
				base * CFrame.new(offset) * CFrame.Angles(0, math.rad(90), 0),
				METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
			wheel.CFrame = base * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(90))
		end
		WorldKit.part(m, "BikeFrame", Vector3.new(2.1, 0.14, 0.14),
			base * CFrame.new(0, 1.25, 0) * CFrame.Angles(0, 0, math.rad(14)),
			RUST, Enum.Material.CorrodedMetal)
		WorldKit.part(m, "BikeBars", Vector3.new(0.14, 0.7, 0.6),
			base * CFrame.new(1.05, 1.8, 0), RUST, Enum.Material.CorrodedMetal)
	end },
	{ label = "69 milk crate", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishMilkCrate")
		WorldKit.part(m, "MilkCrate", Vector3.new(1.3, 1, 1.3),
			CFrame.new(-56.6, 1.6, -182.6) * CFrame.Angles(0, math.rad(18), 0),
			Color3.fromRGB(170, 60, 54), Enum.Material.Plastic)
		for index = 1, 3 do
			WorldKit.part(m, "MilkBottle" .. index, Vector3.new(0.62, 0.3, 0.3),
				CFrame.new(-56.9 + index * 0.3, 2.4, -182.7 + (index % 2) * 0.3)
					* CFrame.Angles(0, 0, math.rad(90)),
				WHITE, Enum.Material.Glass, Enum.PartType.Cylinder)
		end
	end },
	{ label = "70 diner closed sign", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishDinerSign")
		local board = WorldKit.part(m, "ClosedSign", Vector3.new(2.1, 1, 0.15),
			CFrame.new(178.3, 5.2, -142) * CFrame.Angles(0, math.rad(90), math.rad(-7)),
			PAPER, Enum.Material.SmoothPlastic)
		faceText(board, Enum.NormalId.Front, "SORRY,\nWE'RE CLOSED", INK)
	end },
	{ label = "71 storm drain", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishStormDrain")
		WorldKit.part(m, "DrainGrate", Vector3.new(2.6, 0.15, 1.2),
			CFrame.new(9, 0.6, -244), Color3.fromRGB(46, 48, 50), Enum.Material.DiamondPlate)
		WorldKit.part(m, "DrainCurb", Vector3.new(2.8, 0.3, 0.3),
			CFrame.new(9, 0.75, -243.3), STONE_DARK, Enum.Material.Concrete)
	end },
	{ label = "72 alley rats", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishRats")
		local spots = {
			Vector3.new(-70, 0, -182), Vector3.new(-68, 0, -186), Vector3.new(-71.5, 0, -189),
		}
		for index, spot in spots do
			local body = WorldKit.part(m, "RatBody" .. index, Vector3.new(0.35, 0.3, 0.8),
				CFrame.new(spot.X, 0.75, spot.Z) * CFrame.Angles(0, index * 2.2, 0),
				Color3.fromRGB(64, 60, 58), Enum.Material.Fabric)
			local tail = WorldKit.part(m, "RatTail" .. index, Vector3.new(0.06, 0.06, 0.7),
				body.CFrame * CFrame.new(0, 0, 0.7), Color3.fromRGB(120, 96, 88),
				Enum.Material.SmoothPlastic)
			tail.CanCollide = false
		end
	end },
	{ label = "73 school curtains", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishSchoolCurtains")
		for index, z in { -316, -324 } do
			WorldKit.part(m, "Curtain" .. index, Vector3.new(0.12, 3, 1.7),
				CFrame.new(179.6, 7, z) * CFrame.Angles(math.rad(4), 0, math.rad(index == 1 and 3 or -5)),
				Color3.fromRGB(78, 62, 58), Enum.Material.Fabric)
		end
	end },
	{ label = "74 missing posters", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishMissingPosters")
		local spots = { Vector3.new(18, 0, -138), Vector3.new(-18, 0, -214), Vector3.new(18, 0, -290) }
		for index, spot in spots do
			local paper = WorldKit.part(m, "Missing" .. index, Vector3.new(1.1, 1.4, 0.06),
				CFrame.new(spot.X + 0.4, 4.6, spot.Z) * CFrame.Angles(0, math.rad(-90), math.rad(index * 4 - 8)),
				PAPER, Enum.Material.SmoothPlastic)
			paper.CanCollide = false
			faceText(paper, Enum.NormalId.Front, "MISSING\nHAVE YOU\nSEEN ME?", INK)
		end
	end },
	{ label = "75 graveside flowers", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishGraveFlowers")
		for stem = 1, 3 do
			WorldKit.part(m, "GraveStem" .. stem, Vector3.new(0.08, 0.7, 0.08),
				CFrame.new(-26.2 + stem * 0.14, 1.35, -462.2)
					* CFrame.Angles(math.rad(stem * 9 - 18), 0, math.rad(24 - stem * 6)),
				LEAF_DRY, Enum.Material.Grass)
			local bloom = WorldKit.part(m, "GraveBloom" .. stem, Vector3.new(0.24, 0.16, 0.24),
				CFrame.new(-26.2 + stem * 0.14, 1.75, -462.35),
				Color3.fromRGB(180, 150, 160), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			bloom.CanCollide = false
		end
		WorldKit.part(m, "FreshMound", Vector3.new(2.4, 0.5, 4),
			CFrame.new(-24, 1.15, -468), Color3.fromRGB(88, 68, 48), Enum.Material.Ground)
	end },
	{ label = "76 crypt cobwebs", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishCryptWebs")
		for index = 0, 2 do
			local rod = WorldKit.part(m, "CryptWeb" .. index, Vector3.new(0.05, 1.4, 0.05),
				CFrame.new(20.5, -1.4, -463.5) * CFrame.Angles(math.rad(20), 0, math.rad(index * 55 - 55)),
				WHITE, Enum.Material.Neon)
			rod.Transparency = 0.6
			rod.CanCollide = false
		end
		emitterAt(m, "CryptDust", Vector3.new(10, -5.5, -460), Vector3.new(8, 3, 8), {
			texture = SMOKE_TEXTURE,
			color = ColorSequence.new(Color3.fromRGB(160, 154, 140)),
			size = NumberSequence.new(0.4),
			transparency = NumberSequence.new(0.92),
			rate = 2,
			speed = NumberRange.new(0.02, 0.1),
			lifetime = NumberRange.new(4, 7),
			spreadAngle = Vector2.new(180, 180),
		})
	end },
	{ label = "77 radio tower beacon", build = function(_, nightTown)
		local hill = nightTown:FindFirstChild("RadioTowerHill")
		if not hill then
			return
		end
		local top = tallestPartTop(hill)
		if not top then
			return
		end
		local m = WorldKit.model(nightTown, "PolishTowerBeacon")
		local bulb = WorldKit.part(m, "Beacon", Vector3.new(0.7, 0.7, 0.7),
			CFrame.new(top + Vector3.new(0, 0.8, 0)), RED, Enum.Material.Neon,
			Enum.PartType.Ball)
		blinkLoop(bulb, Color3.fromRGB(255, 70, 60), Color3.fromRGB(96, 34, 30), 1.1)
	end },
	{ label = "78 drive-in dressing", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishDriveInProps")
		for index = 1, 3 do
			local reel = WorldKit.part(m, "FilmReel" .. index, Vector3.new(0.3, 1.4, 1.4),
				CFrame.new(101.5, 0.8 + index * 0.32, -424 + index * 0.2),
				METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
			reel.CFrame = CFrame.new(101.5, 0.8 + index * 0.32, -424 + index * 0.2)
				* CFrame.Angles(0, 0, math.rad(90))
		end
		local banner = WorldKit.part(m, "ClosedBanner", Vector3.new(14, 1.4, 0.12),
			CFrame.new(79, 12.6, -452.4), CANVAS, Enum.Material.Fabric)
		faceText(banner, Enum.NormalId.Front, "CLOSED  FOREVER", INK)
	end },

	-- ======================================================= fx & lighting ==
	{ label = "79 campfire flame breathing", build = function(dayCamp, _)
		local fire: Fire? = nil
		for _, d in dayCamp:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("SafeVolume") == true then
				fire = d:FindFirstChildOfClass("Fire")
				break
			end
		end
		if not fire then
			return
		end
		local flame = fire :: Fire
		task.spawn(function()
			while flame.Parent ~= nil do
				local base = flame.Size
				flame.Size = math.clamp(base + math.random(-1, 1) * 0.6, 4, 13)
				task.wait(0.9)
			end
		end)
	end },
	{ label = "80 gate torches", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishGateTorches")
		for index, x in { 56, 72 } do
			WorldKit.part(m, "TorchPost" .. index, Vector3.new(0.5, 5, 0.5),
				CFrame.new(x, 5, 52), WOOD_DARK, Enum.Material.Wood)
			local head = WorldKit.part(m, "TorchHead" .. index, Vector3.new(0.8, 0.7, 0.8),
				CFrame.new(x, 7.8, 52), Color3.fromRGB(255, 176, 96), Enum.Material.Neon)
			WorldKit.lamp(head, { brightness = 1.2, range = 15 })
		end
	end },
	{ label = "81 lake moon shimmer", build = function(dayCamp, _)
		-- Just proud of the rendered water surface (~4.2) in the open bay.
		local shimmer = WorldKit.part(dayCamp, "PolishLakeShimmer", Vector3.new(24, 0.08, 11),
			CFrame.new(108, 4.32, 61) * CFrame.Angles(0, math.rad(14), 0),
			Color3.fromRGB(214, 228, 244), Enum.Material.Neon)
		shimmer.Transparency = 0.88
		shimmer.CanCollide = false
		shimmer.CanQuery = false
	end },
	{ label = "82 aurora ruin wisps", build = function(dayCamp, _)
		emitterAt(dayCamp, "PolishAuroraWisps", Vector3.new(167, 10, 15), Vector3.new(14, 4, 14), {
			texture = SMOKE_TEXTURE,
			color = ColorSequence.new(Color3.fromRGB(110, 226, 170), Color3.fromRGB(70, 150, 210)),
			size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 2.4),
				NumberSequenceKeypoint.new(1, 4.4),
			}),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.86),
				NumberSequenceKeypoint.new(1, 1),
			}),
			rate = 1.6,
			speed = NumberRange.new(0.3, 0.8),
			lifetime = NumberRange.new(4, 7),
			acceleration = Vector3.new(0, 0.5, 0),
			lightEmission = 0.6,
		})
	end },
	{ label = "83 mine warning lantern", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishMineLantern")
		WorldKit.part(m, "LanternArm", Vector3.new(1.6, 0.2, 0.2),
			CFrame.new(84, 8.2, -30), WOOD_DARK, Enum.Material.Wood)
		local glow = WorldKit.part(m, "MineGlow", Vector3.new(0.55, 0.7, 0.55),
			CFrame.new(84.7, 7.6, -30), Color3.fromRGB(255, 88, 60), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 96, 66)
		light.Brightness = 0.8
		light.Range = 11
		light.Parent = glow
	end },
	{ label = "84 sawmill dust motes", build = function(_, nightTown)
		emitterAt(nightTown, "PolishSawdustMotes", Vector3.new(-102, 6.5, -78), Vector3.new(8, 3, 10), {
			texture = SMOKE_TEXTURE,
			color = ColorSequence.new(Color3.fromRGB(206, 184, 140)),
			size = NumberSequence.new(0.3),
			transparency = NumberSequence.new(0.9),
			rate = 2.4,
			speed = NumberRange.new(0.05, 0.2),
			lifetime = NumberRange.new(3, 5),
			spreadAngle = Vector2.new(180, 180),
		})
	end },
	{ label = "85 church door candles", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishChurchCandles")
		for index, x in { -3, 3 } do
			WorldKit.part(m, "ChurchCandle" .. index, Vector3.new(1, 0.4, 0.4),
				CFrame.new(x, 1.4, -446.6) * CFrame.Angles(0, 0, math.rad(90)),
				PAPER, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			local flame = WorldKit.part(m, "CandleGlow" .. index, Vector3.new(0.22, 0.3, 0.22),
				CFrame.new(x, 2.1, -446.6), Color3.fromRGB(255, 190, 120), Enum.Material.Neon,
				Enum.PartType.Ball)
			flame.CanCollide = false
			WorldKit.lamp(flame, { brightness = 0.8, range = 9 })
		end
	end },
	{ label = "86 ropes course beacon", build = function(dayCamp, _)
		local circuit = dayCamp:FindFirstChild("AerialCircuit")
		if not circuit then
			return
		end
		local top = tallestPartTop(circuit)
		if not top then
			return
		end
		local bulb = WorldKit.part(dayCamp, "PolishRopesBeacon", Vector3.new(0.5, 0.5, 0.5),
			CFrame.new(top + Vector3.new(0, 0.6, 0)), RED, Enum.Material.Neon,
			Enum.PartType.Ball)
		blinkLoop(bulb, Color3.fromRGB(255, 90, 70), Color3.fromRGB(110, 40, 34), 1.6)
	end },
	{ label = "87 water tower light", build = function(_, nightTown)
		local cap = nightTown:FindFirstChild("TankCap")
		if not (cap and cap:IsA("BasePart")) then
			return
		end
		local bulb = WorldKit.part(nightTown, "PolishTowerLight", Vector3.new(0.6, 0.6, 0.6),
			cap.CFrame * CFrame.new(0, cap.Size.Y / 2 + 0.5, 0), RED, Enum.Material.Neon,
			Enum.PartType.Ball)
		blinkLoop(bulb, Color3.fromRGB(255, 74, 62), Color3.fromRGB(92, 32, 30), 2.1)
	end },
	{ label = "88 outskirts ground fog", build = function(_, nightTown)
		for index, spot in { Vector3.new(-60, 2, -140), Vector3.new(40, 2, -400) } do
			emitterAt(nightTown, "PolishGroundFog" .. index, spot, Vector3.new(22, 2, 22), {
				texture = SMOKE_TEXTURE,
				color = ColorSequence.new(Color3.fromRGB(180, 190, 196)),
				size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 6),
					NumberSequenceKeypoint.new(1, 10),
				}),
				transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.94),
					NumberSequenceKeypoint.new(1, 1),
				}),
				rate = 1.2,
				speed = NumberRange.new(0.1, 0.4),
				lifetime = NumberRange.new(6, 10),
				spreadAngle = Vector2.new(60, 4),
			})
		end
	end },

	-- ============================================== gameplay qol & seating ==
	{ label = "89 extra hiding spots", build = function(dayCamp, nightTown)
		local m = WorldKit.model(dayCamp, "PolishHidingSpots")
		local lodgeBarrel = barrel(m, "LodgeBarrel", Vector3.new(10, 3.9, 80))
		WorldKit.hidingSpot(lodgeBarrel)
		local crate = WorldKit.part(m, "BoathouseCrate", Vector3.new(2.6, 2.6, 2.6),
			CFrame.new(90, 4.1, 26), WOOD_PALE, Enum.Material.WoodPlanks)
		WorldKit.hidingSpot(crate)
		local townM = WorldKit.model(nightTown, "PolishTownHiding")
		local alleyBarrel = barrel(townM, "AlleyHideBarrel", Vector3.new(-66, 1.8, -181))
		WorldKit.hidingSpot(alleyBarrel)
	end },
	{ label = "90 bus stop bench seat", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishBusBench")
		seatAt(m, "BusSeat", Vector3.new(44, 1.9, -301), Vector3.new(0, 0, -301), WOOD)
		WorldKit.part(m, "BusSeatBack", Vector3.new(0.3, 1.4, 2),
			CFrame.new(45, 2.8, -301), WOOD, Enum.Material.WoodPlanks)
	end },
	{ label = "91 dock sitting spots", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishDockSeats")
		seatAt(m, "DockSeatA", Vector3.new(94, 4.4, 34), Vector3.new(104, 0, 44), WOOD_PALE)
		seatAt(m, "DockSeatB", Vector3.new(96.5, 4.4, 36.5), Vector3.new(106, 0, 46), WOOD_PALE)
	end },
	{ label = "92 beach adirondacks", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishAdirondacks")
		for index, spot in { Vector3.new(74, 6.5, 50), Vector3.new(77, 6.5, 53) } do
			seatAt(m, "Adirondack" .. index, spot, Vector3.new(104, 0, 48),
				Color3.fromRGB(168, 140 - index * 20, 96))
			local toBeach = (Vector3.new(104, 0, 48) - spot) * Vector3.new(1, 0, 1)
			local back = CFrame.lookAt(spot, spot + toBeach) * CFrame.new(0, 1.1, 1.05)
				* CFrame.Angles(math.rad(-12), 0, 0)
			WorldKit.part(m, "AdirondackBack" .. index, Vector3.new(2, 2, 0.3),
				back, Color3.fromRGB(168, 140 - index * 20, 96), Enum.Material.WoodPlanks)
		end
	end },
	{ label = "93 zip platform rails", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishZipRails")
		for index = 0, 2 do
			local angle = math.rad(index * 90)
			WorldKit.part(m, "ZipRail" .. index, Vector3.new(4.2, 0.3, 0.3),
				CFrame.new(58, 19.8, -20) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -2.1),
				WOOD_DARK, Enum.Material.Wood)
		end
	end },
	{ label = "94 catwalk ladder cage", build = function(_, nightTown)
		local m = WorldKit.model(nightTown, "PolishLadderCage")
		for ring = 0, 2 do
			local y = 8 + ring * 6
			for side = 0, 3 do
				local angle = math.rad(side * 90)
				WorldKit.part(m, "CageBar" .. ring .. side, Vector3.new(2.4, 0.22, 0.22),
					CFrame.new(120.5, y, -292) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -1.2),
					METAL, Enum.Material.Metal)
			end
		end
	end },
	{ label = "95 expansion signposts", build = function(dayCamp, _)
		WorldKit.signpost(dayCamp, Vector3.new(-86, 2.7, -66), { "SAWMILL →", "MEADOW" })
		WorldKit.signpost(dayCamp, Vector3.new(-87, 2.7, -58), { "RANGER STATION", "CLIMB THE LADDER" })
	end },
	{ label = "96 mine danger sign", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishMineSign")
		WorldKit.part(m, "MinePost", Vector3.new(0.4, 3.6, 0.4),
			CFrame.new(80, 4.3, -28), WOOD_DARK, Enum.Material.Wood)
		local board = WorldKit.part(m, "MineBoard", Vector3.new(3.4, 1.4, 0.25),
			CFrame.new(80, 5.6, -28) * CFrame.Angles(0, math.rad(35), 0),
			WOOD_PALE, Enum.Material.WoodPlanks)
		faceText(board, Enum.NormalId.Front, "MINES\nKEEP OUT", RED)
	end },
	{ label = "97 boathouse gear shelf", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishBoathouseShelf")
		local shelf = WorldKit.part(m, "GearShelf", Vector3.new(4, 0.3, 1),
			CFrame.new(88, 5.4, 21.4), WOOD, Enum.Material.WoodPlanks)
		for index = 1, 2 do
			WorldKit.part(m, "ShelfOar" .. index, Vector3.new(0.14, 3.6, 0.14),
				shelf.CFrame * CFrame.new(-1.4 + index * 0.5, 1.6, 0)
					* CFrame.Angles(0, 0, math.rad(index * 6)),
				WOOD_PALE, Enum.Material.Wood)
		end
		local coil = WorldKit.part(m, "RopeCoil", Vector3.new(0.9, 0.35, 0.9),
			shelf.CFrame * CFrame.new(1.3, 0.35, 0), CANVAS, Enum.Material.Fabric,
			Enum.PartType.Cylinder)
		coil.CFrame = shelf.CFrame * CFrame.new(1.3, 0.35, 0)
	end },
	{ label = "98 founders slab", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishFoundersSlab")
		local slab = WorldKit.part(m, "FoundersSlab", Vector3.new(3.6, 0.5, 2.4),
			CFrame.new(4, 2.8, 14) * CFrame.Angles(0, math.rad(-8), 0),
			STONE, Enum.Material.Slate)
		faceText(slab, Enum.NormalId.Top, "CAMP BLACK PINE\nEST. 1954", INK)
	end },
	{ label = "99 flag sway", build = function(dayCamp, _)
		local flag = dayCamp:FindFirstChild("CampFlag")
		if not (flag and flag:IsA("BasePart")) then
			return
		end
		local home = flag.CFrame
		local tween = TweenService:Create(
			flag,
			TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ CFrame = home * CFrame.Angles(0, math.rad(7), math.rad(2)) }
		)
		tween:Play()
	end },
	{ label = "100 picnic feast", build = function(dayCamp, _)
		local m = WorldKit.model(dayCamp, "PolishPicnicFeast")
		local placed = 0
		for _, name in { "PicnicTable1", "PicnicTable2" } do
			local table_ = dayCamp:FindFirstChild(name)
			if table_ and table_:IsA("BasePart") then
				-- Position-based: table pivots carry rotations that fling
				-- CFrame-relative offsets sideways.
				local top = Vector3.new(
					table_.Position.X,
					table_.Position.Y + table_.Size.Y / 2 + 0.12,
					table_.Position.Z
				)
				for plate = -1, 1, 2 do
					local dish = WorldKit.part(m, name .. "Plate" .. plate,
						Vector3.new(0.12, 0.9, 0.9),
						CFrame.new(top + Vector3.new(plate * 0.9, 0, 0.5))
							* CFrame.Angles(0, 0, math.rad(90)),
						WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
					dish.CanCollide = false
					local mug = WorldKit.part(m, name .. "Mug" .. plate,
						Vector3.new(0.44, 0.36, 0.36),
						CFrame.new(top + Vector3.new(plate * 1.5, 0.2, -0.5))
							* CFrame.Angles(0, 0, math.rad(90)),
						Color3.fromRGB(90, 110, 130), Enum.Material.SmoothPlastic,
						Enum.PartType.Cylinder)
					mug.CanCollide = false
				end
				local pie = WorldKit.part(m, name .. "Pie", Vector3.new(0.32, 1.1, 1.1),
					CFrame.new(top + Vector3.new(0, 0.1, -0.2)) * CFrame.Angles(0, 0, math.rad(90)),
					Color3.fromRGB(196, 144, 78), Enum.Material.Sand, Enum.PartType.Cylinder)
				pie.CanCollide = false
				placed += 1
			end
		end
		if placed == 0 then
			error("no picnic tables found")
		end
	end },
}

-- ---------------------------------------------------------------------------

function PolishPack.Build(dayCamp: Instance, nightTown: Instance)
	local built = 0
	local failed: { string } = {}
	for _, builder in builders do
		local ok, failure = pcall(builder.build, dayCamp, nightTown)
		if ok then
			built += 1
		else
			table.insert(failed, builder.label .. " (" .. tostring(failure) .. ")")
		end
	end
	print(string.format("[CAMP-Mystery] PolishPack: %d/%d enhancements built", built, #builders))
	if #failed > 0 then
		warn("[CAMP-Mystery] PolishPack failures: " .. table.concat(failed, " | "))
	end
end

return PolishPack
