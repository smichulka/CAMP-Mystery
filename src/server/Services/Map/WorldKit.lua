--!strict

-- Shared construction kit for the world-expansion district builders under
-- Services/Map. All geometry is anchored unless noted. Helpers tag instances
-- with attributes that runtime systems sweep:
--   CampLamp (+ GeneratorGated) — lights toggled by SetNight
--   CreakyFloor — footstep creak audio (WorldAmbience)
--   HidingSpot — hide interaction registry
--   Clutter — unanchored knockable prop with impact sound
--   StormDamage — visible only during non-Clear weather
--   EvidenceSocketExtra — new search-location markers awaiting registration

local TweenService = game:GetService("TweenService")

local WorldKit = {}

function WorldKit.model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function WorldKit.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function WorldKit.wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Anchored = true
	wedge.Size = size
	wedge.CFrame = cframe
	wedge.Color = color
	wedge.Material = material or Enum.Material.SmoothPlastic
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.Parent = parent
	return wedge
end

function WorldKit.truss(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3
): TrussPart
	local truss = Instance.new("TrussPart")
	truss.Name = name
	truss.Anchored = true
	truss.Size = size
	truss.CFrame = cframe
	truss.Color = color
	truss.Parent = parent
	return truss
end

function WorldKit.prompt(
	part: BasePart,
	actionText: string,
	objectText: string,
	holdDuration: number?
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdDuration or 0.35
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

export type LampOptions = {
	color: Color3?,
	brightness: number?,
	range: number?,
	generatorGated: boolean?,
}

-- Interior/exterior lamp. Disabled by day; SetNight enables it (gated lamps
-- additionally need the generator repaired). Ghost flicker can reach these.
function WorldKit.lamp(part: BasePart, options: LampOptions?): PointLight
	local resolved = options or {}
	local light = Instance.new("PointLight")
	light.Name = "CampLamp"
	light.Color = resolved.color or Color3.fromRGB(255, 205, 130)
	light.Brightness = resolved.brightness or 1.4
	light.Range = resolved.range or 16
	light.Shadows = true
	light.Enabled = false
	light:SetAttribute("CampLamp", true)
	light:SetAttribute("GeneratorGated", resolved.generatorGated == true)
	light.Parent = part
	return light
end

function WorldKit.billboardLabel(part: BasePart, text: string, color: Color3?): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WorldLabel"
	-- Stud-based sizing so labels shrink with distance on phone screens.
	billboard.Size = UDim2.new(6.6, 0, 1.6, 0)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 45
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(13, 17, 16)
	label.BackgroundTransparency = 0.2
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(244, 224, 176)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard
	return billboard
end

-- Wooden fingerpost with stacked direction boards.
function WorldKit.signpost(parent: Instance, position: Vector3, lines: { string }): Model
	local sign = WorldKit.model(parent, "Signpost")
	local post = WorldKit.part(
		sign,
		"Post",
		Vector3.new(0.5, 6, 0.5),
		CFrame.new(position + Vector3.new(0, 3, 0)),
		Color3.fromRGB(96, 70, 45),
		Enum.Material.Wood
	)
	for index, line in lines do
		local board = WorldKit.part(
			sign,
			"Board" .. index,
			Vector3.new(4.6, 0.9, 0.3),
			CFrame.new(position + Vector3.new(0.6, 5.4 - (index - 1) * 1.1, 0))
				* CFrame.Angles(0, math.rad((index - 1) * 24 - 12), 0),
			Color3.fromRGB(126, 96, 62),
			Enum.Material.WoodPlanks
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(320, 60)
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.SpecialElite
		label.Text = line
		label.TextColor3 = Color3.fromRGB(34, 26, 18)
		label.TextScaled = true
		label.Parent = gui
	end
	post:SetAttribute("SignpostRoot", true)
	return sign
end

-- Invisible search-location marker. The id and position MUST also be reported
-- back for registration in SEARCH_TARGETS/SEARCH_LOCATIONS by the integrator.
function WorldKit.evidenceSocketMarker(parent: Instance, id: string, position: Vector3): Part
	local marker = Instance.new("Part")
	marker.Name = id
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Transparency = 1
	marker.Size = Vector3.new(2, 2, 2)
	marker.Position = position
	marker:SetAttribute("EvidenceSocketExtra", true)
	marker:SetAttribute("EvidenceAlias", id)
	marker.Parent = parent
	return marker
end

function WorldKit.creakyFloor(part: BasePart)
	part:SetAttribute("CreakyFloor", true)
end

function WorldKit.hidingSpot(part: BasePart)
	part:SetAttribute("HidingSpot", true)
end

-- Unanchored knockable prop. Keep sparse (physics cost); WorldAmbience plays
-- clatter audio on hard impacts.
function WorldKit.clutter(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local prop = WorldKit.part(parent, name, size, cframe, color, material)
	prop.Anchored = false
	prop:SetAttribute("Clutter", true)
	return prop
end

-- Storm-damage dressing: hidden on clear rounds, revealed by weather wiring.
function WorldKit.stormDamage(instance: Instance)
	instance:SetAttribute("StormDamage", true)
end

-- Window with a shutter panel players can toggle (peek or seal).
function WorldKit.shutterWindow(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame
): Part
	local glass = WorldKit.part(
		parent,
		name,
		size,
		cframe,
		Color3.fromRGB(148, 190, 196),
		Enum.Material.Glass
	)
	glass.Transparency = 0.35
	glass.CanCollide = false
	local shutter = WorldKit.part(
		parent,
		name .. "Shutter",
		Vector3.new(size.X + 0.2, size.Y + 0.2, 0.3),
		cframe * CFrame.new(0, 0, -0.25),
		Color3.fromRGB(74, 56, 38),
		Enum.Material.WoodPlanks
	)
	shutter.Transparency = 1
	shutter.CanCollide = false
	local prompt = WorldKit.prompt(glass, "Toggle Shutter", "Window", 0.25)
	local closed = false
	prompt.Triggered:Connect(function()
		closed = not closed
		shutter.Transparency = if closed then 0 else 1
		glass.Transparency = if closed then 1 else 0.35
	end)
	return glass
end

-- Openable drawer/cabinet front that slides out on a prompt. Mostly empty by
-- design; callers may parent a small prop inside for the occasional find.
function WorldKit.drawer(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3
): Part
	local face = WorldKit.part(parent, name, size, cframe, color, Enum.Material.Wood)
	local open = false
	local prompt = WorldKit.prompt(face, "Open", name, 0.3)
	prompt.Triggered:Connect(function()
		open = not open
		local target = if open
			then cframe * CFrame.new(0, 0, size.Z + 0.6)
			else cframe
		TweenService:Create(
			face,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = target }
		):Play()
	end)
	return face
end

-- Hinged door that swings open/closed on a prompt and stops colliding while
-- open. cframe is the CLOSED door cframe; the hinge is its left edge.
function WorldKit.hingedDoor(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3
): Part
	local door = WorldKit.part(parent, name, size, cframe, color, Enum.Material.WoodPlanks)
	local hingeOffset = CFrame.new(-size.X / 2, 0, 0)
	local hinge = cframe * hingeOffset
	local open = false
	local prompt = WorldKit.prompt(door, "Open", name, 0.3)
	prompt.Triggered:Connect(function()
		open = not open
		local swing = if open then math.rad(105) else 0
		local target = hinge * CFrame.Angles(0, swing, 0) * hingeOffset:Inverse()
		door.CanCollide = not open
		TweenService:Create(
			door,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = target }
		):Play()
	end)
	return door
end

-- Simple staircase out of steps; rises along the cframe's -Z look direction.
function WorldKit.stairs(
	parent: Instance,
	name: string,
	baseCFrame: CFrame,
	stepCount: number,
	stepWidth: number,
	color: Color3,
	material: Enum.Material?
): Model
	local stairsModel = WorldKit.model(parent, name)
	for step = 1, stepCount do
		WorldKit.part(
			stairsModel,
			"Step" .. step,
			Vector3.new(stepWidth, 0.9, 1.2),
			baseCFrame * CFrame.new(0, (step - 1) * 0.9 + 0.45, -(step - 1) * 1.2),
			color,
			material or Enum.Material.Concrete
		)
	end
	return stairsModel
end

return WorldKit
