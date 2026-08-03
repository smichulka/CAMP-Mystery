--!strict

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

type ObjectiveHandler = (player: Player, objectiveId: string) -> ()
type EvidenceHandler = (player: Player, evidenceId: string) -> boolean

type InteractiveDoor = {
	part: Part,
	prompt: ProximityPrompt,
	closedCFrame: CFrame,
	openCFrame: CFrame,
	isOpen: boolean,
}

type ProductionMapServiceState = {
	mapFolder: Folder,
	dayCamp: Folder,
	nightTown: Folder,
	objectivesFolder: Folder,
	evidenceFolder: Folder,
	evidenceSockets: { BasePart },
	onObjective: ObjectiveHandler,
	onEvidence: EvidenceHandler,
	evidenceClaimed: { [string]: boolean },
	interactiveDoors: { InteractiveDoor },
}

local ProductionMapService = {}
ProductionMapService.__index = ProductionMapService

export type ProductionMapService = typeof(
	setmetatable({} :: ProductionMapServiceState, ProductionMapService)
)

local DAY_AMBIENT = Color3.fromRGB(128, 139, 121)
local NIGHT_AMBIENT = Color3.fromRGB(24, 29, 43)
local DOOR_TWEEN = TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local OBJECTIVES = {
	{
		id = "firewood",
		name = "Stack Firewood",
		position = Vector3.new(-30, 2, -22),
		color = Color3.fromRGB(130, 86, 52),
	},
	{
		id = "generator",
		name = "Repair Generator",
		position = Vector3.new(0, 2, -48),
		color = Color3.fromRGB(93, 105, 99),
	},
	{
		id = "supplies",
		name = "Secure Supplies",
		position = Vector3.new(30, 2, -22),
		color = Color3.fromRGB(109, 94, 56),
	},
}

local SEARCH_TARGETS = {
	{
		id = "main-road-clue-a",
		name = "Abandoned Sedan",
		position = Vector3.new(-17, 2, -101),
		color = Color3.fromRGB(91, 103, 107),
	},
	{
		id = "residential-bedroom-clue",
		name = "Ransacked Bedroom",
		position = Vector3.new(-108, 3, -154),
		color = Color3.fromRGB(107, 83, 71),
	},
	{
		id = "square-gas-station-clue",
		name = "Gas Station Counter",
		position = Vector3.new(96, 3, -185),
		color = Color3.fromRGB(119, 93, 54),
	},
	{
		id = "industrial-machine-clue",
		name = "Factory Press",
		position = Vector3.new(-105, 4, -268),
		color = Color3.fromRGB(73, 82, 83),
	},
	{
		id = "water-tower-base-clue",
		name = "Water Tower Base",
		position = Vector3.new(112, 2, -290),
		color = Color3.fromRGB(74, 90, 91),
	},
	{
		id = "police-evidence-room-clue",
		name = "Police Evidence Locker",
		position = Vector3.new(95, 3, -360),
		color = Color3.fromRGB(72, 91, 111),
	},
	{
		id = "outskirts-company-house-clue",
		name = "Company House Cellar",
		position = Vector3.new(-102, 3, -384),
		color = Color3.fromRGB(91, 74, 63),
	},
}

local function createPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createCylinder(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local cylinder = createPart(parent, name, size, cframe, color, material)
	cylinder.Shape = Enum.PartType.Cylinder
	return cylinder
end

local function createWedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Anchored = true
	wedge.Size = size
	wedge.CFrame = cframe
	wedge.Color = color
	wedge.Material = material
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.Parent = parent
	return wedge
end

local function createPrompt(
	parent: BasePart,
	actionText: string,
	objectText: string,
	holdDuration: number?
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdDuration or 0.65
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = true
	prompt.ClickablePrompt = true
	prompt.Parent = parent
	return prompt
end

local function createInspectPrompt(
	parent: BasePart,
	objectText: string,
	response: string
): ProximityPrompt
	local prompt = createPrompt(parent, "Inspect", objectText, 0.45)
	local feedback = Instance.new("BillboardGui")
	feedback.Name = "InteractionFeedback"
	feedback.Size = UDim2.fromOffset(260, 58)
	feedback.StudsOffset = Vector3.new(0, 3.5, 0)
	feedback.AlwaysOnTop = true
	feedback.MaxDistance = 70
	feedback.Enabled = false
	feedback.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(13, 17, 16)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.Text = response
	label.TextColor3 = Color3.fromRGB(244, 224, 176)
	label.TextSize = 15
	label.TextWrapped = true
	label.Parent = feedback

	local interactionVersion = 0
	prompt.Triggered:Connect(function()
		interactionVersion += 1
		local version = interactionVersion
		prompt.ActionText = "Inspected"
		feedback.Enabled = true
		task.delay(3, function()
			if prompt.Parent and interactionVersion == version then
				prompt.ActionText = "Inspect"
				feedback.Enabled = false
			end
		end)
	end)
	return prompt
end

local function createInteractiveDoor(
	parent: Instance,
	name: string,
	size: Vector3,
	closedCFrame: CFrame,
	color: Color3,
	objectText: string
): InteractiveDoor
	local door = createPart(
		parent,
		name,
		size,
		closedCFrame,
		color,
		Enum.Material.WoodPlanks
	)
	door:SetAttribute("WorldInteraction", "Door")
	local prompt = createPrompt(door, "Open", objectText, 0.15)
	prompt.MaxActivationDistance = 10
	local hinge = CFrame.new(-size.X / 2, 0, 0)
	local openCFrame = closedCFrame
		* hinge
		* CFrame.Angles(0, math.rad(-102), 0)
		* hinge:Inverse()
	local state: InteractiveDoor = {
		part = door,
		prompt = prompt,
		closedCFrame = closedCFrame,
		openCFrame = openCFrame,
		isOpen = false,
	}
	prompt.Triggered:Connect(function()
		state.isOpen = not state.isOpen
		prompt.ActionText = if state.isOpen then "Close" else "Open"
		if state.isOpen then
			door.CanCollide = false
		end
		TweenService:Create(
			door,
			DOOR_TWEEN,
			{ CFrame = if state.isOpen then state.openCFrame else state.closedCFrame }
		):Play()
		if not state.isOpen then
			task.delay(DOOR_TWEEN.Time, function()
				if door.Parent and not state.isOpen then
					door.CanCollide = true
				end
			end)
		end
	end)
	return state
end

local function createSign(parent: BasePart, text: string, accent: Color3)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "LocationSign"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 36
	surface.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(14, 16, 18)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = accent
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = surface
end

local function setFolderVisible(folder: Folder, visible: boolean)
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			local visibleTransparency = descendant:GetAttribute("VisibleTransparency")
			if typeof(visibleTransparency) ~= "number" then
				visibleTransparency = descendant.Transparency
				descendant:SetAttribute("VisibleTransparency", visibleTransparency)
			end
			local visibleCanCollide = descendant:GetAttribute("VisibleCanCollide")
			if typeof(visibleCanCollide) ~= "boolean" then
				visibleCanCollide = descendant.CanCollide
				descendant:SetAttribute("VisibleCanCollide", visibleCanCollide)
			end
			local visibleCanTouch = descendant:GetAttribute("VisibleCanTouch")
			if typeof(visibleCanTouch) ~= "boolean" then
				visibleCanTouch = descendant.CanTouch
				descendant:SetAttribute("VisibleCanTouch", visibleCanTouch)
			end
			local visibleCanQuery = descendant:GetAttribute("VisibleCanQuery")
			if typeof(visibleCanQuery) ~= "boolean" then
				visibleCanQuery = descendant.CanQuery
				descendant:SetAttribute("VisibleCanQuery", visibleCanQuery)
			end
			descendant.Transparency = if visible then visibleTransparency else 1
			descendant.CanCollide = visible and visibleCanCollide
			descendant.CanTouch = visible and visibleCanTouch
			descendant.CanQuery = visible and visibleCanQuery
		elseif descendant:IsA("ProximityPrompt") then
			local visibleEnabled = descendant:GetAttribute("VisibleEnabled")
			if typeof(visibleEnabled) ~= "boolean" then
				visibleEnabled = descendant.Enabled
				descendant:SetAttribute("VisibleEnabled", visibleEnabled)
			end
			descendant.Enabled = visible and visibleEnabled
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
			local visibleEnabled = descendant:GetAttribute("VisibleEnabled")
			if typeof(visibleEnabled) ~= "boolean" then
				visibleEnabled = descendant.Enabled
				descendant:SetAttribute("VisibleEnabled", visibleEnabled)
			end
			descendant.Enabled = visible and visibleEnabled
		elseif descendant:IsA("Light") then
			local visibleEnabled = descendant:GetAttribute("VisibleEnabled")
			if typeof(visibleEnabled) ~= "boolean" then
				visibleEnabled = descendant.Enabled
				descendant:SetAttribute("VisibleEnabled", visibleEnabled)
			end
			descendant.Enabled = visible and visibleEnabled
		end
	end
end

local function createCabin(
	parent: Instance,
	name: string,
	position: Vector3,
	width: number
): InteractiveDoor
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local wallColor  = Color3.fromRGB(112, 102, 90)   -- weathered grey-silver log (matches references)
	local trimColor  = Color3.fromRGB(46, 32, 22)
	local tinRoof    = Color3.fromRGB(88, 84, 76)    -- weathered corrugated tin
	local stoneColor = Color3.fromRGB(72, 68, 62)    -- mossy stone foundation

	-- Stone foundation strip around the base
	createPart(model, "Foundation", Vector3.new(width + 1.2, 1.8, 17.4),
		CFrame.new(position + Vector3.new(0, -0.55, 0)),
		stoneColor, Enum.Material.SmoothPlastic)

	local floor = createPart(
		model,
		"Floor",
		Vector3.new(width, 0.7, 16),
		CFrame.new(position + Vector3.new(0, 0.35, 0)),
		Color3.fromRGB(72, 51, 36),
		Enum.Material.WoodPlanks
	)
	model.PrimaryPart = floor
	createPart(
		model,
		"BackWall",
		Vector3.new(width, 10, 0.7),
		CFrame.new(position + Vector3.new(0, 5, 7.65)),
		wallColor,
		Enum.Material.WoodPlanks
	)
	for side = -1, 1, 2 do
		createPart(
			model,
			"SideWall",
			Vector3.new(0.7, 10, 16),
			CFrame.new(position + Vector3.new(side * (width / 2 - 0.35), 5, 0)),
			wallColor,
			Enum.Material.WoodPlanks
		)
		createPart(
			model,
			"FrontWall",
			Vector3.new((width - 5) / 2, 10, 0.7),
			CFrame.new(
				position
					+ Vector3.new(
						side * (width / 4 + 1.25),
						5,
						-7.65
					)
			),
			wallColor,
			Enum.Material.WoodPlanks
		)
	end
	createPart(
		model,
		"DoorHeader",
		Vector3.new(5, 2.4, 0.7),
		CFrame.new(position + Vector3.new(0, 8.8, -7.65)),
		wallColor,
		Enum.Material.WoodPlanks
	)
	-- Corrugated tin roof panels (two sloped halves)
	-- Geometry derived from the wall top (y=10) so the panels rest on the walls:
	-- each panel runs from the ridge at cabin-center X down past the wall with a small overhang.
	local roofAngle = math.rad(25)
	local overhang = 1.5
	local half = width / 2
	local wallTop = 10
	local ridgeY = wallTop + half * math.tan(roofAngle)
	local eaveY = wallTop - overhang * math.tan(roofAngle)
	local panelLen = (half + overhang) / math.cos(roofAngle)
	local panelCX = (half + overhang) / 2
	local panelCY = (ridgeY + eaveY) / 2
	-- Positive Z rotation tilts the +X edge up; each panel's inner edge faces the ridge
	createPart(
		model,
		"RoofLeft",
		Vector3.new(panelLen, 1.1, 19),
		CFrame.new(position + Vector3.new(-panelCX, panelCY, 0))
			* CFrame.Angles(0, 0, roofAngle),
		tinRoof,
		Enum.Material.CorrodedMetal
	)
	createPart(
		model,
		"RoofRight",
		Vector3.new(panelLen, 1.1, 19),
		CFrame.new(position + Vector3.new(panelCX, panelCY, 0))
			* CFrame.Angles(0, 0, -roofAngle),
		tinRoof,
		Enum.Material.CorrodedMetal
	)
	-- Roof ridge cap along the peak
	createPart(model, "RoofRidge", Vector3.new(1.2, 1.2, 19),
		CFrame.new(position + Vector3.new(0, ridgeY + 0.35, 0)),
		Color3.fromRGB(60, 56, 52), Enum.Material.Metal)
	-- Triangular gable fills on front and back walls
	-- Two WedgeParts per gable wall, mirrored at cabin center X.
	-- A WedgePart's tall vertical face is at local +Z (verified by raycast); the
	-- slope descends toward local -Z. Rotate so each wedge's tall end faces the
	-- ridge at cabin-center X:
	--   +90° around Y: local +Z (tall end) → world +X (left wedge, toward center)
	--   -90° around Y: local +Z (tall end) → world -X (right wedge, toward center)
	-- gableHeight/(width/2) = tan(roofAngle), so the wedge slope matches the roof pitch exactly
	local gableHeight = ridgeY - wallTop
	local gableCenterY = wallTop + gableHeight / 2
	local gableSize = Vector3.new(0.7, gableHeight, width / 2)
	for _, wallZ in ipairs({ -7.65, 7.65 }) do
		createWedge(model, "GableLeft", gableSize,
			CFrame.new(position + Vector3.new(-width / 4, gableCenterY, wallZ))
				* CFrame.Angles(0, math.pi / 2, 0),
			wallColor, Enum.Material.WoodPlanks)
		createWedge(model, "GableRight", gableSize,
			CFrame.new(position + Vector3.new(width / 4, gableCenterY, wallZ))
				* CFrame.Angles(0, -math.pi / 2, 0),
			wallColor, Enum.Material.WoodPlanks)
	end
	-- Round metal stovepipe chimney (vertical cylinder through roof)
	local pipeColor = Color3.fromRGB(40, 36, 32)
	createCylinder(model, "Stovepipe",
		Vector3.new(8, 0.52, 0.52),
		CFrame.new(position + Vector3.new(width * 0.28, 14.0, 6.5)) * CFrame.Angles(0, 0, math.rad(90)),
		pipeColor, Enum.Material.Metal)
	createCylinder(model, "StovepipeCap",
		Vector3.new(0.55, 0.80, 0.80),
		CFrame.new(position + Vector3.new(width * 0.28, 18.3, 6.5)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(52, 46, 40), Enum.Material.CorrodedMetal)
	-- Porch with posts
	createPart(
		model,
		"Porch",
		Vector3.new(width - 2, 1, 5),
		CFrame.new(position + Vector3.new(0, 0.5, -10)),
		Color3.fromRGB(77, 54, 37),
		Enum.Material.WoodPlanks
	)
	-- Porch roof
	createPart(model, "PorchRoof", Vector3.new(width - 2, 0.35, 5.5),
		CFrame.new(position + Vector3.new(0, 9.35, -10.25)),
		tinRoof, Enum.Material.CorrodedMetal)
	-- Porch posts at each corner
	for side = -1, 1, 2 do
		createPart(model, "PorchPost", Vector3.new(0.45, 8.8, 0.45),
			CFrame.new(position + Vector3.new(side * (width / 2 - 1.5), 4.5, -12)),
			trimColor, Enum.Material.WoodPlanks)
	end
	-- Porch railing: front rail + side returns + balusters between corner posts (Cabin 4 reference)
	local railY = 4.0
	createPart(model, "PorchRailFront", Vector3.new(width - 4.0, 0.28, 0.22),
		CFrame.new(position + Vector3.new(0, railY, -12)), trimColor, Enum.Material.WoodPlanks)
	for side = -1, 1, 2 do
		createPart(model, "PorchRailSide" .. (if side < 0 then "L" else "R"),
			Vector3.new(0.22, 0.28, 3.5),
			CFrame.new(position + Vector3.new(side * (width / 2 - 1.5), railY, -10.25)),
			trimColor, Enum.Material.WoodPlanks)
	end
	for b = 1, 3 do
		local bX = -(width / 2 - 2.5) + (width - 5.0) / 4 * b
		createPart(model, "PorchBaluster" .. tostring(b), Vector3.new(0.20, railY - 1.1, 0.20),
			CFrame.new(position + Vector3.new(bX, (1.1 + railY) / 2, -12)),
			trimColor, Enum.Material.WoodPlanks)
	end
	-- Side lean-to: small open-sided shelter attached to the right cabin wall (Cabin 3 reference)
	local leanW, leanD = 9, 10
	local leanHi, leanLo = 8.5, 5.0
	-- Tall end (+Z after -90° rotation → world -X) sits against the cabin wall;
	-- the slope descends outward
	createWedge(model, "LeanToRoof",
		Vector3.new(leanW, leanHi - leanLo, leanD + 0.5),
		CFrame.new(position + Vector3.new(width / 2 + leanW / 2, leanLo + (leanHi - leanLo) / 2, 2))
			* CFrame.Angles(0, -math.pi / 2, 0),
		tinRoof, Enum.Material.CorrodedMetal)
	for lSide = -1, 1, 2 do
		createPart(model, "LeanToPost" .. (if lSide < 0 then "F" else "B"),
			Vector3.new(0.45, leanLo, 0.45),
			CFrame.new(position + Vector3.new(width / 2 + leanW - 0.25, leanLo / 2, 2 + lSide * (leanD / 2 - 0.25))),
			trimColor, Enum.Material.WoodPlanks)
	end
	-- Simple wooden porch chair on one side (Cabin 2 reference: chair visible on porch)
	local chairColor = Color3.fromRGB(68, 46, 28)
	createPart(model, "ChairSeat", Vector3.new(1.7, 0.28, 1.5),
		CFrame.new(position + Vector3.new(width * 0.25, 1.64, -9.8)), chairColor, Enum.Material.WoodPlanks)
	createPart(model, "ChairBack", Vector3.new(1.7, 1.15, 0.22),
		CFrame.new(position + Vector3.new(width * 0.25, 2.35, -9.1)), chairColor, Enum.Material.WoodPlanks)
	local doorState = createInteractiveDoor(
		model,
		"Door",
		Vector3.new(4.4, 7.4, 0.5),
		CFrame.new(position + Vector3.new(0, 4.05, -8.05)),
		trimColor,
		name
	)

	for side = -1, 1, 2 do
		local window = createPart(
			model,
			"Window",
			Vector3.new(4, 3.5, 0.4),
			CFrame.new(position + Vector3.new(side * width * 0.28, 5.5, -8.25)),
			Color3.fromRGB(181, 198, 174),
			Enum.Material.Glass,
			0.2
		)
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Front
		light.Brightness = 0.8
		light.Range = 14
		light.Color = Color3.fromRGB(255, 221, 159)
		light.Enabled = false
		light.Parent = window
	end

	local interiorLamp = createPart(
		model,
		"InteriorLamp",
		Vector3.new(1.2, 0.45, 1.2),
		CFrame.new(position + Vector3.new(0, 9.4, 1.5)),
		Color3.fromRGB(255, 211, 132),
		Enum.Material.Neon
	)
	interiorLamp.CanCollide = false
	local interiorLight = Instance.new("PointLight")
	interiorLight.Name = "CabinLight"
	interiorLight.Brightness = 1.25
	interiorLight.Range = 21
	interiorLight.Color = Color3.fromRGB(255, 220, 161)
	interiorLight.Shadows = true
	interiorLight.Enabled = false
	interiorLight.Parent = interiorLamp
	local lightPrompt = createPrompt(interiorLamp, "Switch On", name .. " lights", 0.1)
	lightPrompt.Triggered:Connect(function()
		interiorLight.Enabled = not interiorLight.Enabled
		lightPrompt.ActionText = if interiorLight.Enabled then "Switch Off" else "Switch On"
	end)

	for side = -1, 1, 2 do
		local bed = createPart(
			model,
			"BunkBed",
			Vector3.new(5.5, 1.2, 9),
			CFrame.new(position + Vector3.new(side * (width / 2 - 3.5), 1.5, 2)),
			Color3.fromRGB(98, 80, 61),
			Enum.Material.WoodPlanks
		)
		local mattress = createPart(
			model,
			"Mattress",
			Vector3.new(5.1, 0.65, 8.4),
			bed.CFrame + Vector3.new(0, 0.9, 0),
			if side < 0
				then Color3.fromRGB(103, 124, 113)
				else Color3.fromRGB(118, 105, 91),
			Enum.Material.Fabric
		)
		mattress.CanCollide = false
		-- Pillow at head (door-side) end of each bunk
		local pillow = createPart(
			model, "Pillow",
			Vector3.new(4.2, 0.36, 1.56),
			bed.CFrame + Vector3.new(0, 1.405, -3.4),
			Color3.fromRGB(234, 226, 208),
			Enum.Material.Fabric
		)
		pillow.CanCollide = false
		-- Footlocker at foot end of each bunk
		createPart(
			model, "Footlocker",
			Vector3.new(4.6, 1.5, 1.8),
			bed.CFrame + Vector3.new(0, -0.65, 4.5),
			Color3.fromRGB(58, 44, 28),
			Enum.Material.WoodPlanks
		)
	end

	local tableTop = createPart(
		model,
		"CabinTable",
		Vector3.new(6, 0.55, 4),
		CFrame.new(position + Vector3.new(0, 3, 2)),
		Color3.fromRGB(91, 64, 43),
		Enum.Material.WoodPlanks
	)
	createInspectPrompt(
		tableTop,
		name .. " guest book",
		"LAST ENTRY — lights out at 11:47 PM. Something scratched at the door."
	)
	-- Name board hangs from the porch roof edge so it never clips the gable or hides behind the eave
	local signW = math.min(width - 6, 14)
	createSign(
		createPart(
			model,
			"CabinSign",
			Vector3.new(signW, 1.9, 0.35),
			CFrame.new(position + Vector3.new(0, 8.15, -12.3)),
			trimColor,
			Enum.Material.Wood
		),
		string.upper(string.gsub(name, "(%l)(%u)", "%1 %2")),
		Color3.fromRGB(226, 190, 114)
	)
	for hSide = -1, 1, 2 do
		createPart(model, "SignStrap" .. (if hSide < 0 then "L" else "R"),
			Vector3.new(0.14, 0.6, 0.14),
			CFrame.new(position + Vector3.new(hSide * (signW / 2 - 0.8), 9.15, -12.3)),
			trimColor, Enum.Material.WoodPlanks)
	end
	-- Two-step approach from porch down to ground (Cabin 2/4 reference: raised porch feel)
	createPart(model, "PorchStep1", Vector3.new(4.2, 0.38, 1.5),
		CFrame.new(position + Vector3.new(0, 0.19, -13.4)),
		Color3.fromRGB(72, 50, 32), Enum.Material.WoodPlanks)
	createPart(model, "PorchStep2", Vector3.new(4.6, 0.20, 1.4),
		CFrame.new(position + Vector3.new(0, 0.10, -14.9)),
		Color3.fromRGB(62, 44, 28), Enum.Material.WoodPlanks)
	-- Wooden bench on left porch side (Cabin 4 reference: low bench/railing against left wall)
	createPart(model, "BenchSeat", Vector3.new(3.4, 0.28, 1.8),
		CFrame.new(position + Vector3.new(-(width / 2 - 3.2), 1.52, -10.4)),
		Color3.fromRGB(68, 48, 32), Enum.Material.WoodPlanks)
	local benchBack = createPart(model, "BenchBack", Vector3.new(3.4, 1.4, 0.18),
		CFrame.new(position + Vector3.new(-(width / 2 - 3.2), 2.22, -11.2)),
		Color3.fromRGB(62, 44, 28), Enum.Material.WoodPlanks)
	benchBack.CanCollide = false
	-- Firewood stack beside the right porch post (Cabin 4 reference)
	local logColor  = Color3.fromRGB(82, 55, 34)
	local logDark   = Color3.fromRGB(58, 38, 22)
	createPart(model, "WoodPileBase", Vector3.new(5.2, 1.5, 2.8),
		CFrame.new(position + Vector3.new(width / 2 + 3.6, 0.75, -11.0)),
		logColor, Enum.Material.WoodPlanks)
	createPart(model, "WoodPileMid", Vector3.new(4.8, 1.2, 2.6),
		CFrame.new(position + Vector3.new(width / 2 + 3.6, 2.1, -11.0)),
		logDark, Enum.Material.WoodPlanks)
	createPart(model, "WoodPileTop", Vector3.new(4.2, 1.0, 2.4),
		CFrame.new(position + Vector3.new(width / 2 + 3.6, 3.2, -11.0)),
		logColor, Enum.Material.WoodPlanks)
	-- Two loose cross-logs resting on the pile top
	createPart(model, "LogA", Vector3.new(0.75, 0.75, 3.8),
		CFrame.new(position + Vector3.new(width / 2 + 2.6, 3.85, -11.0)),
		logDark, Enum.Material.WoodPlanks)
	createPart(model, "LogB", Vector3.new(0.75, 0.75, 3.8),
		CFrame.new(position + Vector3.new(width / 2 + 4.6, 3.85, -11.0)),
		logDark, Enum.Material.WoodPlanks)
	return doorState
end

local function createBuilding(
	parent: Instance,
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3,
	signText: string,
	rotationY: number?
): InteractiveDoor
	-- All offsets are in the building's local frame (front = local -Z);
	-- rotationY turns the whole building so the storefront can face the road
	local base = CFrame.new(position) * CFrame.Angles(0, rotationY or 0, 0)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local floor = createPart(
		model,
		"Floor",
		Vector3.new(size.X, 0.8, size.Z),
		base * CFrame.new(0, 0.4, 0),
		color,
		Enum.Material.Concrete
	)
	model.PrimaryPart = floor
	createPart(
		model,
		"BackWall",
		Vector3.new(size.X, size.Y, 1),
		base * CFrame.new(0, size.Y / 2, size.Z / 2 - 0.5),
		color,
		Enum.Material.Brick
	)
	for side = -1, 1, 2 do
		createPart(
			model,
			"SideWall",
			Vector3.new(1, size.Y, size.Z),
			base * CFrame.new(side * (size.X / 2 - 0.5), size.Y / 2, 0),
			color,
			Enum.Material.Brick
		)
		createPart(
			model,
			"FrontWall",
			Vector3.new((size.X - 6) / 2, size.Y, 1),
			base * CFrame.new(side * (size.X / 4 + 1.5), size.Y / 2, -size.Z / 2 + 0.5),
			color,
			Enum.Material.Brick
		)
	end
	createPart(
		model,
		"DoorHeader",
		Vector3.new(6, math.max(2, size.Y - 8), 1),
		base * CFrame.new(0, 8 + math.max(2, size.Y - 8) / 2, -size.Z / 2 + 0.5),
		color,
		Enum.Material.Brick
	)
	createPart(
		model,
		"Roof",
		Vector3.new(size.X + 2, 1.5, size.Z + 2),
		base * CFrame.new(0, size.Y + 0.75, 0),
		Color3.fromRGB(41, 43, 46),
		Enum.Material.Slate
	)
	local doorState = createInteractiveDoor(
		model,
		"Door",
		Vector3.new(5.4, 7.6, 0.55),
		base * CFrame.new(0, 4.2, -size.Z / 2 - 0.05),
		Color3.fromRGB(54, 48, 42),
		signText
	)
	local sign = createPart(
		model,
		"Sign",
		Vector3.new(math.min(size.X - 3, 18), 4, 0.5),
		base * CFrame.new(0, size.Y - 3, -size.Z / 2 - 0.35),
		Color3.fromRGB(27, 29, 31),
		Enum.Material.Wood
	)
	createSign(sign, signText, Color3.fromRGB(194, 202, 191))
	for column = -1, 1, 2 do
		createPart(
			model,
			"BoardedWindow",
			Vector3.new(5, 4, 0.4),
			base * CFrame.new(column * size.X * 0.23, size.Y * 0.48, -size.Z / 2 - 0.25),
			Color3.fromRGB(75, 63, 50),
			Enum.Material.WoodPlanks
		)
	end
	-- Crumbling plaster patches: exposed dark brick where facade has fallen off (Old Town 2/3 reference)
	local damageC = Color3.fromRGB(46, 40, 35)
	local fZ = -size.Z / 2 - 0.14
	local function dmgPatch(nm, partSize, offset: Vector3)
		local p = createPart(model, nm, partSize, base * CFrame.new(offset.X, offset.Y, offset.Z), damageC, Enum.Material.Concrete)
		p.CanCollide = false
	end
	dmgPatch("DamagePatch1", Vector3.new(3.8, 3.2, 0.18), Vector3.new(-size.X * 0.29, size.Y * 0.72, fZ))
	dmgPatch("DamagePatch2", Vector3.new(2.6, 4.0, 0.18), Vector3.new( size.X * 0.27, size.Y * 0.81, fZ))
	dmgPatch("DamagePatch3", Vector3.new(0.18, 3.6, 5.0), Vector3.new(-size.X / 2 - 0.12, size.Y * 0.60, size.Z * 0.12))
	local interiorCounter = createPart(
		model,
		"SearchCounter",
		Vector3.new(math.min(12, size.X - 6), 3.5, 3),
		base * CFrame.new(0, 1.75, 3),
		Color3.fromRGB(66, 57, 49),
		Enum.Material.WoodPlanks
	)
	createInspectPrompt(
		interiorCounter,
		signText .. " interior",
		"Dust trails and fresh marks suggest someone searched this place before you."
	)
	return doorState
end

local function createStreetlight(parent: Instance, position: Vector3)
	local poleC = Color3.fromRGB(28, 30, 34)  -- dark wrought iron
	-- Main pole (slender Victorian shaft)
	local pole = createPart(parent, "Streetlight", Vector3.new(0.55, 18, 0.55),
		CFrame.new(position + Vector3.new(0, 9, 0)), poleC, Enum.Material.Metal)
	pole:SetAttribute("ShadowNode", true)
	-- Decorative collar ring near the top
	createPart(parent, "LampCollar", Vector3.new(0.90, 0.42, 0.90),
		CFrame.new(position + Vector3.new(0, 16.8, 0)), poleC, Enum.Material.Metal)
	-- Finial ball cap
	local cap = createPart(parent, "PoleCap", Vector3.new(0.75, 0.75, 0.75),
		CFrame.new(position + Vector3.new(0, 18.38, 0)), poleC, Enum.Material.Metal)
	cap.Shape = Enum.PartType.Ball
	-- Hook arm: horizontal beam + short vertical drop
	createPart(parent, "LampArm", Vector3.new(3.0, 0.38, 0.38),
		CFrame.new(position + Vector3.new(1.5, 17.2, 0)), poleC, Enum.Material.Metal)
	createPart(parent, "LampDrop", Vector3.new(0.38, 1.5, 0.38),
		CFrame.new(position + Vector3.new(3.0, 16.45, 0)), poleC, Enum.Material.Metal)
	-- Lantern cage (dark frame surrounding the glow bulb)
	createPart(parent, "LanternFrame", Vector3.new(1.55, 1.90, 1.55),
		CFrame.new(position + Vector3.new(3.0, 15.2, 0)), poleC, Enum.Material.Metal)
	-- Glowing amber bulb inside the cage
	local glow = createPart(parent, "LanternGlow", Vector3.new(0.95, 1.20, 0.95),
		CFrame.new(position + Vector3.new(3.0, 15.2, 0)),
		Color3.fromRGB(255, 208, 140), Enum.Material.Neon)
	glow.Transparency = 0.22
	glow.Shape = Enum.PartType.Ball
	-- Warm amber point light (matches Old Town 1 reference lamp colour)
	local light = Instance.new("PointLight")
	light.Brightness = 1.6
	light.Range = 30
	light.Color = Color3.fromRGB(255, 205, 140)
	light.Parent = glow
end

local function createUtilityPole(parent: Instance, position: Vector3)
	local poleColor = Color3.fromRGB(50, 38, 26)
	-- Vertical shaft (~22 studs tall)
	createCylinder(parent, "UtilityShaft",
		Vector3.new(22, 0.46, 0.46),
		CFrame.new(position + Vector3.new(0, 11, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		poleColor, Enum.Material.WoodPlanks)
	-- Horizontal crossarm near the top
	createPart(parent, "UtilityCrossarm",
		Vector3.new(5.6, 0.30, 0.30),
		CFrame.new(position + Vector3.new(0, 20.6, 0)),
		poleColor, Enum.Material.WoodPlanks)
	-- Ceramic insulator knobs at each end of the crossarm
	for side = -1, 1, 2 do
		createCylinder(parent, "UtilityInsulator",
			Vector3.new(0.38, 0.42, 0.42),
			CFrame.new(position + Vector3.new(side * 2.4, 20.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(55, 74, 72), Enum.Material.SmoothPlastic)
	end
end

local function createPineTree(
	parent: Instance,
	position: Vector3,
	height: number,
	canopyColor: Color3
)
	local trunk = createCylinder(
		parent,
		"PineTrunk",
		Vector3.new(height, 2.4, 2.4),
		CFrame.new(position + Vector3.new(0, height / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(67, 50, 36),
		Enum.Material.Wood
	)
	trunk:SetAttribute("Occluder", true)
	for layer = 1, 5 do
		local width = 13 - layer * 1.45
		local canopy = createPart(
			parent,
			"PineCanopy",
			Vector3.new(width, 5.2, width),
			CFrame.new(
				position
					+ Vector3.new(
						if layer % 2 == 0 then 0.7 else -0.5,
						height * 0.42 + layer * 2.65,
						if layer % 3 == 0 then 0.6 else -0.35
					)
			),
			canopyColor:Lerp(Color3.fromRGB(26, 61, 39), layer * 0.035),
			Enum.Material.Grass
		)
		canopy.Shape = Enum.PartType.Ball
		canopy.CanCollide = false
		canopy:SetAttribute("Occluder", true)
	end
end

local function createBareTree(parent: Instance, position: Vector3, height: number)
	local trunk = createCylinder(parent, "BareTrunk",
		Vector3.new(height, 1.6, 1.6),
		CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(52, 44, 36), Enum.Material.Wood)
	trunk:SetAttribute("Occluder", true)
	-- A few dead angular branches
	for b = 1, 4 do
		local branchAngle = (b / 4) * math.pi * 2
		local branchH = height * (0.45 + b * 0.09)
		local branchLen = 4 + b % 3
		createPart(parent, "Branch",
			Vector3.new(0.4, branchLen, 0.4),
			CFrame.new(position + Vector3.new(
				math.cos(branchAngle) * 1.1,
				branchH,
				math.sin(branchAngle) * 1.1
			)) * CFrame.Angles(math.cos(branchAngle) * 0.65, 0, math.sin(branchAngle) * 0.65),
			Color3.fromRGB(44, 36, 28), Enum.Material.Wood)
	end
end

local function buildWaterTower(parent: Instance, position: Vector3)
	local metalColor  = Color3.fromRGB(63, 72, 75)    -- weathered CorrodedMetal
	local legColor    = Color3.fromRGB(52, 58, 60)
	local tankHeight  = 18
	local legH        = 20

	-- Tank (cylinder lying on its side, so PartType.Cylinder rotated 90°)
	local tank = createCylinder(parent, "WaterTankBody",
		Vector3.new(tankHeight, 14, 14),
		CFrame.new(position + Vector3.new(0, legH + tankHeight / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		metalColor, Enum.Material.CorrodedMetal)
	tank.Shape = Enum.PartType.Cylinder

	-- Tank bands / hoops
	for ring = 1, 4 do
		local ringY = legH + (ring / 5) * tankHeight
		local band = createCylinder(parent, "TankBand",
			Vector3.new(0.55, 14.4, 14.4),
			CFrame.new(position + Vector3.new(0, ringY, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(44, 52, 55), Enum.Material.CorrodedMetal)
		band.Shape = Enum.PartType.Cylinder
	end

	-- Top cap
	createPart(parent, "TankCap",
		Vector3.new(14.5, 1.2, 14.5),
		CFrame.new(position + Vector3.new(0, legH + tankHeight + 0.6, 0)),
		legColor, Enum.Material.CorrodedMetal)

	-- Four support legs with X-braces
	for i = 0, 3 do
		local legAngle = (i / 4) * math.pi * 2
		local lx = math.cos(legAngle) * 5
		local lz = math.sin(legAngle) * 5
		createPart(parent, "WTLeg",
			Vector3.new(0.9, legH, 0.9),
			CFrame.new(position + Vector3.new(lx, legH / 2, lz)),
			legColor, Enum.Material.Metal)
	end
	-- Cross-braces at mid-height between adjacent legs
	for i = 0, 3 do
		local a1 = (i / 4) * math.pi * 2
		local a2 = ((i + 1) / 4) * math.pi * 2
		local x1, z1 = math.cos(a1) * 5, math.sin(a1) * 5
		local x2, z2 = math.cos(a2) * 5, math.sin(a2) * 5
		local mx, mz = (x1 + x2) / 2, (z1 + z2) / 2
		local braceLen = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
		local braceAngle = math.atan2(z2 - z1, x2 - x1)
		createPart(parent, "WTBrace",
			Vector3.new(braceLen, 0.55, 0.55),
			CFrame.new(position + Vector3.new(mx, legH * 0.55, mz))
				* CFrame.Angles(0, -braceAngle, 0),
			legColor, Enum.Material.Metal)
	end

	-- Platform deck just below the tank
	createPart(parent, "WTPlatform",
		Vector3.new(16, 0.55, 16),
		CFrame.new(position + Vector3.new(0, legH - 0.3, 0)),
		Color3.fromRGB(52, 48, 44), Enum.Material.Metal)
	-- Platform railing posts (4 sides)
	for side = -1, 1, 2 do
		createPart(parent, "WTRailH",
			Vector3.new(16.5, 0.35, 0.35),
			CFrame.new(position + Vector3.new(0, legH + 1.8, side * 8)),
			legColor, Enum.Material.Metal)
		createPart(parent, "WTRailV",
			Vector3.new(0.35, 0.35, 16.5),
			CFrame.new(position + Vector3.new(side * 8, legH + 1.8, 0)),
			legColor, Enum.Material.Metal)
	end

	-- "WATER" lettering sign on the tank side (SurfaceGui on a thin plate)
	local signPlate = createPart(parent, "WTSign",
		Vector3.new(8, 2.5, 0.25),
		CFrame.new(position + Vector3.new(0, legH + tankHeight * 0.5, -7.2)),
		Color3.fromRGB(40, 48, 50), Enum.Material.SmoothPlastic)
	createSign(signPlate, "WATER", Color3.fromRGB(148, 158, 148))
end

local function configureLighting()
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.32
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.55

	local atmosphere = Lighting:FindFirstChild("CampAtmosphere")
	if not atmosphere or not atmosphere:IsA("Atmosphere") then
		if atmosphere then
			atmosphere:Destroy()
		end
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "CampAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.05
	atmosphere.Color = Color3.fromRGB(192, 208, 196)
	atmosphere.Decay = Color3.fromRGB(88, 108, 95)
	atmosphere.Glare = 0.06
	atmosphere.Haze = 1.85

	local color = Lighting:FindFirstChild("CampColor")
	if not color or not color:IsA("ColorCorrectionEffect") then
		if color then
			color:Destroy()
		end
		color = Instance.new("ColorCorrectionEffect")
		color.Name = "CampColor"
		color.Parent = Lighting
	end
	color.Brightness = 0.02
	color.Contrast = 0.08
	color.Saturation = -0.04
	color.TintColor = Color3.fromRGB(255, 244, 221)

	local bloom = Lighting:FindFirstChild("CampBloom")
	if not bloom or not bloom:IsA("BloomEffect") then
		if bloom then
			bloom:Destroy()
		end
		bloom = Instance.new("BloomEffect")
		bloom.Name = "CampBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.22
	bloom.Size = 24
	bloom.Threshold = 1.15

	local rays = Lighting:FindFirstChild("CampSunRays")
	if not rays or not rays:IsA("SunRaysEffect") then
		if rays then
			rays:Destroy()
		end
		rays = Instance.new("SunRaysEffect")
		rays.Name = "CampSunRays"
		rays.Parent = Lighting
	end
	rays.Intensity = 0.08
	rays.Spread = 0.75
end

local function hideDefaultBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		baseplate.CanCollide = false
		baseplate.CanTouch = false
		baseplate.CanQuery = false
		baseplate:SetAttribute("HiddenByCampMystery", true)
	end
end

local function buildCampTerrain(parent: Instance)
	local terrain = Workspace.Terrain
	-- Animated grass everywhere on grass terrain, cut short so porches/props stay visible
	-- (Decoration/GrassLength may not exist depending on Studio version; both are optional cosmetics)
	local cosmeticTerrain = terrain :: any
	pcall(function()
		cosmeticTerrain.Decoration = true
	end)
	pcall(function()
		cosmeticTerrain.GrassLength = 0.3
	end)
	terrain:FillBlock(
		CFrame.new(0, -3.5, 12),
		Vector3.new(250, 8, 205),
		Enum.Material.Grass
	)
	for index = 1, 14 do
		local angle = (index / 14) * math.pi * 2
		local radius = 105 + (index % 3) * 9
		terrain:FillBall(
			Vector3.new(
				math.cos(angle) * radius,
				-3 + (index % 2),
				12 + math.sin(angle) * radius
			),
			20 + index % 4 * 2,
			if index % 3 == 0 then Enum.Material.Ground else Enum.Material.Grass
		)
	end
	terrain:FillBlock(
		CFrame.new(104, -0.8, 12) * CFrame.Angles(0, 0.08, 0),
		Vector3.new(31, 4.8, 170),
		Enum.Material.Water
	)

	local bounds = createPart(
		parent,
		"CampGround",
		Vector3.new(250, 1, 205),
		CFrame.new(0, -3, 12),
		Color3.fromRGB(59, 82, 52),
		Enum.Material.Grass,
		1
	)
	bounds.CanCollide = false
	bounds.CanTouch = false
	bounds.CanQuery = false
end

local function cloneAuthoredMap(folderName: string): Model?
	local assets = ServerStorage:FindFirstChild("ServerAssets")
	local maps = if assets then assets:FindFirstChild("Maps") else nil
	local source = if maps then maps:FindFirstChild(folderName) else nil
	return if source and source:IsA("Model") then source:Clone() else nil
end

function ProductionMapService.new(
	onObjective: ObjectiveHandler,
	onEvidence: EvidenceHandler
): ProductionMapService
	local runtime = Workspace:WaitForChild("Runtime")
	local mapFolder = runtime:WaitForChild("Map")
	local evidenceFolder = runtime:WaitForChild("Evidence")
	assert(mapFolder:IsA("Folder"), "Workspace.Runtime.Map must be a Folder")
	assert(evidenceFolder:IsA("Folder"), "Workspace.Runtime.Evidence must be a Folder")
	mapFolder:ClearAllChildren()
	evidenceFolder:ClearAllChildren()

	local dayCamp = Instance.new("Folder")
	dayCamp.Name = "DayCamp"
	dayCamp.Parent = mapFolder
	local nightTown = Instance.new("Folder")
	nightTown.Name = "NightTown"
	nightTown.Parent = mapFolder
	local objectivesFolder = Instance.new("Folder")
	objectivesFolder.Name = "Objectives"
	objectivesFolder.Parent = dayCamp

	local self: ProductionMapService = setmetatable({
		mapFolder = mapFolder,
		dayCamp = dayCamp,
		nightTown = nightTown,
		objectivesFolder = objectivesFolder,
		evidenceFolder = evidenceFolder,
		evidenceSockets = {},
		onObjective = onObjective,
		onEvidence = onEvidence,
		evidenceClaimed = {},
		interactiveDoors = {},
	}, ProductionMapService)
	hideDefaultBaseplate()
	configureLighting()
	self:Build()
	self:ResetRound()
	return self
end

function ProductionMapService:Build()
	local authoredCamp = cloneAuthoredMap("Camp")
	if authoredCamp then
		authoredCamp.Name = "AuthoredCamp"
		authoredCamp.Parent = self.dayCamp
		-- Strip legacy brick chimneys and add stovepipes to authored cabin models
		local cabinSet = { PineCabin = true, CreekCabin = true, CounselorLodge = true, SupplyCabin = true }
		for _, child in ipairs(authoredCamp:GetDescendants()) do
			if child:IsA("Model") and cabinSet[child.Name] then
				for _, part in ipairs(child:GetDescendants()) do
					if part:IsA("BasePart") and part.Name:lower():find("chimney") then
						part:Destroy()
					end
				end
				if not child:FindFirstChild("Stovepipe") then
					local floor = child:FindFirstChild("Floor")
					if floor then
						local pos = floor.Position - Vector3.new(0, 0.35, 0)
						local w = floor.Size.X
						createCylinder(child, "Stovepipe",
							Vector3.new(8, 0.52, 0.52),
							CFrame.new(pos + Vector3.new(w * 0.28, 14.0, 6.5)) * CFrame.Angles(0, 0, math.rad(90)),
							Color3.fromRGB(40, 36, 32), Enum.Material.Metal)
						createCylinder(child, "StovepipeCap",
							Vector3.new(0.55, 0.80, 0.80),
							CFrame.new(pos + Vector3.new(w * 0.28, 18.3, 6.5)) * CFrame.Angles(0, 0, math.rad(90)),
							Color3.fromRGB(52, 46, 40), Enum.Material.CorrodedMetal)
					end
				end
			end
		end
	else
		buildCampTerrain(self.dayCamp)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "CampSpawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.Position = Vector3.new(0, 1, 34)
		spawn.Color = Color3.fromRGB(106, 88, 64)
		spawn.Material = Enum.Material.WoodPlanks
		spawn.Transparency = 0.35
		spawn.Parent = self.dayCamp
		for segment = -3, 3 do
			createPart(
				self.dayCamp,
				"CampPath",
				Vector3.new(18 + math.abs(segment), 0.3, 28),
				CFrame.new(
					math.sin(segment * 0.85) * 3,
					0.66,
					segment * 24 + 5
				) * CFrame.Angles(0, math.rad(math.sin(segment) * 4), 0),
				Color3.fromRGB(117, 91, 64),
				Enum.Material.Ground
			)
		end
		table.insert(
			self.interactiveDoors,
			createCabin(self.dayCamp, "PineCabin", Vector3.new(-54, 0.5, 18), 24)
		)
		table.insert(
			self.interactiveDoors,
			createCabin(self.dayCamp, "CreekCabin", Vector3.new(54, 0.5, 18), 24)
		)
		table.insert(
			self.interactiveDoors,
			createCabin(self.dayCamp, "CounselorLodge", Vector3.new(0, 0.5, 74), 30)
		)
		table.insert(
			self.interactiveDoors,
			createCabin(self.dayCamp, "SupplyCabin", Vector3.new(-76, 0.5, -42), 18)
		)
		local fire = createPart(
			self.dayCamp,
			"Campfire",
			Vector3.new(2, 8, 8),
			CFrame.new(0, 1.5, 2) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(124, 78, 48),
			Enum.Material.Slate
		)
		fire.Shape = Enum.PartType.Cylinder
		fire:SetAttribute("SafeVolume", true)
		local flame = Instance.new("Fire")
		flame.Name = "CampFlame"
		flame.Color = Color3.fromRGB(255, 170, 66)
		flame.SecondaryColor = Color3.fromRGB(193, 65, 34)
		flame.Heat = 8
		flame.Size = 7
		flame.Parent = fire
		local fireLight = Instance.new("PointLight")
		fireLight.Name = "FireLight"
		fireLight.Brightness = 2.4
		fireLight.Range = 32
		fireLight.Color = Color3.fromRGB(255, 169, 82)
		fireLight.Shadows = true
		fireLight.Parent = fire
		local firePrompt = createPrompt(fire, "Tend Fire", "Campfire", 0.35)
		firePrompt.Triggered:Connect(function()
			flame.Size = if flame.Size > 7 then 7 else 10
			fireLight.Brightness = if fireLight.Brightness > 2.5 then 2.4 else 3.2
		end)
		for seatIndex = 1, 6 do
			local angle = (seatIndex / 6) * math.pi * 2
			local seat = Instance.new("Seat")
			seat.Name = "CampfireSeat"
			seat.Anchored = true
			seat.Size = Vector3.new(5, 1.2, 2)
			seat.CFrame = CFrame.new(
				math.cos(angle) * 10,
				1.2,
				2 + math.sin(angle) * 10
			) * CFrame.Angles(0, -angle + math.pi / 2, 0)
			seat.Color = Color3.fromRGB(83, 59, 39)
			seat.Material = Enum.Material.Wood
			seat.Parent = self.dayCamp
		end
		for index = 1, 30 do
			local angle = (index / 30) * math.pi * 2
			local radius = 91 + (index % 4) * 9
			createPineTree(
				self.dayCamp,
				Vector3.new(
					math.cos(angle) * radius,
					0.5,
					12 + math.sin(angle) * radius
				),
				18 + index % 5 * 2.5,
				if index % 2 == 0
					then Color3.fromRGB(43, 85, 57)
					else Color3.fromRGB(50, 94, 61)
			)
		end
		for index = 1, 18 do
			local angle = index * 2.17
			local radius = 34 + (index % 5) * 10
			local rock = createPart(
				self.dayCamp,
				"ForestRock",
				Vector3.new(2.5 + index % 3, 1.6 + index % 2, 2.8 + (index + 1) % 3),
				CFrame.new(
					math.cos(angle) * radius,
					1.1,
					12 + math.sin(angle) * radius
				) * CFrame.Angles(index * 0.27, angle, index * 0.11),
				Color3.fromRGB(82, 88, 78),
				Enum.Material.Slate
			)
			rock.CanCollide = false
		end
	end

	-- Strip any surviving brick chimneys (from authored place-file content or ServerStorage models)
	-- and add stovepipes if missing — runs unconditionally after both the authored and procedural paths
	local cabinNames = { PineCabin = true, CreekCabin = true, CounselorLodge = true, SupplyCabin = true }
	for _, child in ipairs(self.dayCamp:GetDescendants()) do
		if child:IsA("Model") and cabinNames[child.Name] then
			for _, part in ipairs(child:GetDescendants()) do
				if part:IsA("BasePart") and part.Name:lower():find("chimney") then
					part:Destroy()
				end
			end
			if not child:FindFirstChild("Stovepipe") then
				local floor = child:FindFirstChild("Floor")
				if floor then
					local pos = floor.Position - Vector3.new(0, 0.35, 0)
					local w = floor.Size.X
					createCylinder(child, "Stovepipe",
						Vector3.new(8, 0.52, 0.52),
						CFrame.new(pos + Vector3.new(w * 0.28, 14.0, 6.5)) * CFrame.Angles(0, 0, math.rad(90)),
						Color3.fromRGB(40, 36, 32), Enum.Material.Metal)
					createCylinder(child, "StovepipeCap",
						Vector3.new(0.55, 0.80, 0.80),
						CFrame.new(pos + Vector3.new(w * 0.28, 18.3, 6.5)) * CFrame.Angles(0, 0, math.rad(90)),
						Color3.fromRGB(52, 46, 40), Enum.Material.CorrodedMetal)
				end
			end
		end
	end

	for _, definition in OBJECTIVES do
		local station = Instance.new("Model")
		station.Name = definition.id
		station:SetAttribute("ObjectiveId", definition.id)
		station.Parent = self.objectivesFolder
		local root = createPart(
			station,
			"InteractionRoot",
			Vector3.new(8, 1.2, 8),
			CFrame.new(definition.position + Vector3.new(0, -1.4, 0)),
			definition.color,
			Enum.Material.WoodPlanks
		)
		root:SetAttribute("OriginalColor", definition.color)
		station.PrimaryPart = root
		if definition.id == "firewood" then
			for logIndex = 1, 6 do
				local row = (logIndex - 1) % 3
				local layer = math.floor((logIndex - 1) / 3)
				createCylinder(
					station,
					"SplitLog",
					Vector3.new(5.8, 1.05, 1.05),
					CFrame.new(
						definition.position
							+ Vector3.new(0, layer * 1.15, row * 1.35 - 1.35)
					),
					Color3.fromRGB(116, 73, 42),
					Enum.Material.Wood
				)
			end
		elseif definition.id == "generator" then
			local generator = createPart(
				station,
				"Generator",
				Vector3.new(7, 5, 5),
				CFrame.new(definition.position + Vector3.new(0, 0.55, 0)),
				Color3.fromRGB(63, 75, 71),
				Enum.Material.DiamondPlate
			)
			for vent = -1, 1, 2 do
				createPart(
					station,
					"Vent",
					Vector3.new(0.25, 2.2, 1.5),
					generator.CFrame * CFrame.new(3.58, 0.5, vent * 1.35),
					Color3.fromRGB(28, 33, 32),
					Enum.Material.Metal
				)
			end
			local statusLamp = createPart(
				station,
				"StatusLamp",
				Vector3.new(0.45, 0.45, 0.45),
				generator.CFrame * CFrame.new(3.7, 1.55, 0),
				Color3.fromRGB(187, 72, 49),
				Enum.Material.Neon
			)
			statusLamp:SetAttribute("CompletionIndicator", true)
			statusLamp.CanCollide = false
		else
			for crateIndex = 1, 4 do
				local x = if crateIndex % 2 == 0 then 2.2 else -2.2
				local y = if crateIndex > 2 then 2.2 else 0
				createPart(
					station,
					"SupplyCrate",
					Vector3.new(4, 3.6, 4),
					CFrame.new(definition.position + Vector3.new(x, y, 0)),
					Color3.fromRGB(105, 78, 48),
					Enum.Material.WoodPlanks
				)
			end
		end
		local marker = Instance.new("BillboardGui")
		marker.Name = "ObjectiveMarker"
		marker.Size = UDim2.fromOffset(190, 46)
		marker.StudsOffset = Vector3.new(0, 5.5, 0)
		marker.AlwaysOnTop = true
		marker.MaxDistance = 100
		marker.Parent = root
		local markerText = Instance.new("TextLabel")
		markerText.BackgroundColor3 = Color3.fromRGB(13, 17, 16)
		markerText.BackgroundTransparency = 0.12
		markerText.BorderSizePixel = 0
		markerText.Size = UDim2.fromScale(1, 1)
		markerText.Font = Enum.Font.GothamBold
		markerText.Text = string.upper(definition.name)
		markerText:SetAttribute("OriginalText", markerText.Text)
		markerText.TextColor3 = Color3.fromRGB(244, 224, 176)
		markerText.TextScaled = true
		markerText.Parent = marker
		local prompt = createPrompt(root, "Complete", definition.name, 1.1)
		prompt.Triggered:Connect(function(player: Player)
			self.onObjective(player, definition.id)
		end)
	end

	local authoredTown = cloneAuthoredMap("NightTown")
	if authoredTown then
		authoredTown.Name = "AuthoredNightTown"
		authoredTown.Parent = self.nightTown
	else
		createPart(
			self.nightTown,
			"TownGround",
			Vector3.new(300, 1, 430),
			CFrame.new(0, -0.5, -230),
			Color3.fromRGB(47, 51, 48),
			Enum.Material.Ground
		)
		createPart(
			self.nightTown,
				"MainRoad",
				Vector3.new(50, 1, 360),
				CFrame.new(0, 0.05, -225),
				Color3.fromRGB(36, 39, 42),
			Enum.Material.Asphalt
		)
		for stripe = 1, 10 do
			createPart(
				self.nightTown,
				"FadedRoadStripe",
				Vector3.new(0.55, 0.08, 14),
				CFrame.new(0, 0.59, -62 - stripe * 32),
				Color3.fromRGB(177, 164, 111),
				Enum.Material.Concrete,
				0.2
			).CanCollide = false
		end
		for side = -1, 1, 2 do
			createPart(
				self.nightTown,
				"BrokenSidewalk",
				Vector3.new(8, 0.6, 350),
				CFrame.new(side * 29, 0.35, -225),
				Color3.fromRGB(83, 83, 79),
				Enum.Material.Concrete
			)
		end
		createPart(
			self.nightTown,
			"CrossRoad",
			Vector3.new(260, 1, 42),
			CFrame.new(0, 0.05, -190),
			Color3.fromRGB(38, 41, 43),
			Enum.Material.Asphalt
		)
		-- Buildings flank the north-south main road; rotate storefronts to face it
		-- (left side of the road faces +X = -90 deg, right side faces -X = +90 deg)
		table.insert(self.interactiveDoors, createBuilding(self.nightTown, "GeneralStore", Vector3.new(-73, 0, -185), Vector3.new(34, 19, 30), Color3.fromRGB(77, 72, 65), "GENERAL STORE", -math.pi / 2))
		table.insert(self.interactiveDoors, createBuilding(self.nightTown, "GasStation", Vector3.new(75, 0, -185), Vector3.new(35, 16, 28), Color3.fromRGB(82, 76, 65), "LAST STOP GAS", math.pi / 2))
		table.insert(self.interactiveDoors, createBuilding(self.nightTown, "ResidentialA", Vector3.new(-100, 0, -135), Vector3.new(30, 17, 28), Color3.fromRGB(71, 67, 64), "RESIDENCE", -math.pi / 2))
		table.insert(self.interactiveDoors, createBuilding(self.nightTown, "Factory", Vector3.new(-100, 0, -275), Vector3.new(48, 28, 45), Color3.fromRGB(64, 69, 70), "MILL NO. 7", -math.pi / 2))
		table.insert(self.interactiveDoors, createBuilding(self.nightTown, "PoliceStation", Vector3.new(92, 0, -360), Vector3.new(42, 22, 38), Color3.fromRGB(64, 72, 79), "POLICE", math.pi / 2))
		table.insert(self.interactiveDoors, createBuilding(self.nightTown, "CompanyHouse", Vector3.new(-100, 0, -390), Vector3.new(34, 18, 30), Color3.fromRGB(72, 65, 59), "COMPANY HOUSE", -math.pi / 2))
		buildWaterTower(self.nightTown, Vector3.new(110, 0, -292))
		-- Abandoned church at the far end of the road (prominent in Old Town 4 aerial reference)
		do
			local cPos = Vector3.new(0, 0, -455)
			local cW, cH, cD = 28, 20, 36
			local churchColor = Color3.fromRGB(68, 63, 56)
			local churchModel = Instance.new("Model")
			churchModel.Name = "AbandonedChurch"
			churchModel.Parent = self.nightTown
			createPart(churchModel, "ChurchFloor", Vector3.new(cW, 0.8, cD), CFrame.new(cPos + Vector3.new(0, 0.4, 0)), churchColor, Enum.Material.Concrete)
			createPart(churchModel, "ChurchBackWall", Vector3.new(cW, cH, 1), CFrame.new(cPos + Vector3.new(0, cH / 2, cD / 2 - 0.5)), churchColor, Enum.Material.Brick)
			createPart(churchModel, "ChurchSideL", Vector3.new(1, cH, cD), CFrame.new(cPos + Vector3.new(-cW / 2 + 0.5, cH / 2, 0)), churchColor, Enum.Material.Brick)
			createPart(churchModel, "ChurchSideR", Vector3.new(1, cH, cD), CFrame.new(cPos + Vector3.new(cW / 2 - 0.5, cH / 2, 0)), churchColor, Enum.Material.Brick)
			createPart(churchModel, "ChurchFrontL", Vector3.new((cW - 8) / 2, cH, 1), CFrame.new(cPos + Vector3.new(-(4 + (cW - 8) / 4), cH / 2, -cD / 2 + 0.5)), churchColor, Enum.Material.Brick)
			createPart(churchModel, "ChurchFrontR", Vector3.new((cW - 8) / 2, cH, 1), CFrame.new(cPos + Vector3.new( (4 + (cW - 8) / 4), cH / 2, -cD / 2 + 0.5)), churchColor, Enum.Material.Brick)
			createPart(churchModel, "ChurchArchHeader", Vector3.new(8, cH - 9, 1), CFrame.new(cPos + Vector3.new(0, 9 + (cH - 9) / 2, -cD / 2 + 0.5)), churchColor, Enum.Material.Brick)
			-- Peaked roof slopes
			local roofC = Color3.fromRGB(42, 40, 38)
			local roofL = Instance.new("WedgePart")
			roofL.Name = "ChurchRoofL"
			roofL.Size = Vector3.new(cW + 2, 8, cD / 2 + 1)
			roofL.CFrame = CFrame.new(cPos + Vector3.new(0, cH + 4, cD / 4)) * CFrame.Angles(0, math.rad(180), 0)
			roofL.Color = roofC
			roofL.Material = Enum.Material.Slate
			roofL.Anchored = true
			roofL.Parent = churchModel
			local roofR = Instance.new("WedgePart")
			roofR.Name = "ChurchRoofR"
			roofR.Size = Vector3.new(cW + 2, 8, cD / 2 + 1)
			roofR.CFrame = CFrame.new(cPos + Vector3.new(0, cH + 4, -cD / 4))
			roofR.Color = roofC
			roofR.Material = Enum.Material.Slate
			roofR.Anchored = true
			roofR.Parent = churchModel
			-- Steeple base tower on front-center
			local spX, spZ = 0, -cD / 2 + 4
			createPart(churchModel, "SteepleBase", Vector3.new(7, cH + 4, 7), CFrame.new(cPos + Vector3.new(spX, (cH + 4) / 2, spZ)), churchColor, Enum.Material.Brick)
			createPart(churchModel, "SteepleSpire", Vector3.new(6, 18, 6), CFrame.new(cPos + Vector3.new(spX, cH + 4 + 9, spZ)), roofC, Enum.Material.Slate)
			-- Cross at the top of the steeple
			createPart(churchModel, "CrossV", Vector3.new(0.6, 5, 0.6), CFrame.new(cPos + Vector3.new(spX, cH + 4 + 18 + 2.5, spZ)), Color3.fromRGB(72, 65, 55), Enum.Material.Wood)
			createPart(churchModel, "CrossH", Vector3.new(3.5, 0.6, 0.6), CFrame.new(cPos + Vector3.new(spX, cH + 4 + 20, spZ)), Color3.fromRGB(72, 65, 55), Enum.Material.Wood)
			-- Arched windows on side walls
			for wSide = -1, 1, 2 do
				for wn = 1, 2 do
					createPart(churchModel, "ChurchWin" .. tostring(wSide) .. wn,
						Vector3.new(3.5, 5.5, 0.5),
						CFrame.new(cPos + Vector3.new(wSide * (cW / 2 - 0.25), cH * 0.62, (wn - 1.5) * cD * 0.30)),
						Color3.fromRGB(48, 55, 62), Enum.Material.SmoothPlastic)
				end
			end
		end
		for index = 1, 9 do
			createStreetlight(self.nightTown, Vector3.new(if index % 2 == 0 then 18 else -18, 0, -62 - index * 38))
		end
		-- Dead/bare trees scattered around the outskirts for atmosphere
		local bareTreePositions = {
			Vector3.new(-135, 0, -150), Vector3.new(-140, 0, -340),
			Vector3.new(-130, 0, -408), Vector3.new(130, 0, -265),
			Vector3.new(130, 0, -380), Vector3.new(-22, 0, -415),
			Vector3.new(48, 0, -95),   Vector3.new(-48, 0, -95),
		}
		for idx, treePos in bareTreePositions do
			createBareTree(self.nightTown, treePos, 14 + (idx % 3) * 3)
		end
		-- Scatter props: barrels + crates in front of General Store (reference: porch/ground clutter)
		local barrelColor = Color3.fromRGB(68, 48, 32)
		for b = 1, 3 do
			createCylinder(self.nightTown, "Barrel" .. tostring(b),
				Vector3.new(2.2, 2.4, 2.4),
				CFrame.new(-58 + (b - 1) * 2.8, 1.2, -174) * CFrame.Angles(0, 0, math.rad(90)),
				barrelColor, Enum.Material.WoodPlanks)
			-- Metal band rings on each barrel
			createCylinder(self.nightTown, "BarrelRing" .. tostring(b) .. "T",
				Vector3.new(2.25, 0.25, 0.25),
				CFrame.new(-58 + (b - 1) * 2.8, 0.6, -174) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(52, 46, 40), Enum.Material.CorrodedMetal)
			createCylinder(self.nightTown, "BarrelRing" .. tostring(b) .. "B",
				Vector3.new(2.25, 0.25, 0.25),
				CFrame.new(-58 + (b - 1) * 2.8, 1.8, -174) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(52, 46, 40), Enum.Material.CorrodedMetal)
		end
		-- Wooden crates stacked near Gas Station (reference: roadside debris)
		local crateColor = Color3.fromRGB(82, 65, 44)
		createPart(self.nightTown, "CrateBase",  Vector3.new(2.4, 2.4, 2.4), CFrame.new(60, 1.2, -175), crateColor, Enum.Material.WoodPlanks)
		createPart(self.nightTown, "CrateTop",   Vector3.new(2.0, 2.0, 2.0), CFrame.new(60, 3.6, -175), crateColor:Lerp(Color3.fromRGB(0,0,0), 0.12), Enum.Material.WoodPlanks)
		createPart(self.nightTown, "CrateSmall", Vector3.new(1.6, 1.6, 1.6), CFrame.new(62.8, 0.8, -177), crateColor, Enum.Material.WoodPlanks)
		-- Wagon wheel lying flat on the road edge (reference old town 2 shows wheel debris)
		local wheelColor = Color3.fromRGB(52, 38, 24)
		for spoke = 1, 6 do
			local spokeAngle = math.rad(spoke * 30)
			createPart(self.nightTown, "WheelSpoke" .. tostring(spoke),
				Vector3.new(0.18, 3.6, 0.18),
				CFrame.new(-52, 0.18, -220) * CFrame.Angles(0, spokeAngle, 0),
				wheelColor, Enum.Material.Wood)
		end
		createCylinder(self.nightTown, "WheelRim",
			Vector3.new(0.22, 8.2, 8.2),
			CFrame.new(-52, 0.18, -220) * CFrame.Angles(0, 0, math.rad(90)),
			wheelColor, Enum.Material.Wood)
		-- Utility poles along the right side of the main road (prominent in both old-town references)
		for p = 1, 5 do
			createUtilityPole(self.nightTown, Vector3.new(32, 0, -118 - (p - 1) * 58))
		end
		-- Rusted metal fence along the left sidewalk edge of main road
		for section = 0, 9 do
			createPart(self.nightTown, "FencePost",
				Vector3.new(0.35, 3.2, 0.35),
				CFrame.new(-36, 1.6, -78 - section * 34),
				Color3.fromRGB(64, 58, 52), Enum.Material.CorrodedMetal)
			if section < 9 then
				createPart(self.nightTown, "FenceRail",
					Vector3.new(0.2, 0.2, 33.5),
					CFrame.new(-36, 2.8, -95 - section * 34),
					Color3.fromRGB(60, 54, 48), Enum.Material.CorrodedMetal)
			end
		end
		-- Ground rubble and fallen plaster chunks scattered along the road
		-- Matches Old Town 1 reference: irregular concrete debris on the ground
		local rubbleData = {
			{ -12, -118, 2.8, 1.1, 2.2, 0.55 },
			{  10, -148, 1.8, 0.8, 1.6, 1.20 },
			{ -22, -170, 3.4, 1.3, 2.6, 0.30 },
			{  18, -210, 2.2, 0.9, 2.0, 2.10 },
			{ -10, -240, 1.6, 0.7, 1.4, 0.80 },
			{ -26, -265, 3.0, 1.2, 2.4, 1.60 },
			{  12, -310, 2.4, 1.0, 2.2, 0.40 },
			{ -16, -345, 1.8, 0.8, 1.6, 2.50 },
			{  22, -368, 2.6, 1.1, 2.0, 1.00 },
			{  -8, -395, 2.0, 0.9, 1.8, 1.80 },
		}
		local rubbleC = Color3.fromRGB(148, 142, 134)
		for i, rd in ipairs(rubbleData) do
			local chunk = createPart(self.nightTown, "Rubble" .. i,
				Vector3.new(rd[3], rd[4], rd[5]),
				CFrame.new(rd[1], rd[4] / 2, rd[2]) * CFrame.Angles(0.14, rd[6], 0.10),
				rubbleC, Enum.Material.Concrete)
			chunk.CanCollide = false
		end
		-- Dried scrub-brush clumps scattered around town (Old Town 4 aerial reference shows pervasive scrub)
		local scrubColor = Color3.fromRGB(56, 64, 36)
		local scrubPositions = {
			{-55, -112}, {-68, -158}, {-56, -200}, {-72, -245}, {-60, -292},
			{ 58, -128}, { 66, -172}, { 54, -218}, { 70, -260}, { 60, -308},
			{-38, -245}, { 38, -248}, {-22, -308}, { 30, -355},
			{-46, -422}, { 42, -428}, { 18, -440},
		}
		for i, pos in ipairs(scrubPositions) do
			local sz = 1.3 + (i % 3) * 0.55
			local scrub = createPart(self.nightTown, "Scrub" .. i,
				Vector3.new(sz * 1.1, sz * 0.72, sz * 0.95),
				CFrame.new(pos[1], sz * 0.36, pos[2]),
				scrubColor, Enum.Material.Grass)
			scrub.Shape = Enum.PartType.Ball
			scrub.CanCollide = false
		end
		-- Weed bands hugging both road edges (Old Town 1/2 reference: vegetation
		-- reclaiming the street). Deterministic jitter keeps the layout stable.
		local weedColors = {
			Color3.fromRGB(56, 64, 36),
			Color3.fromRGB(96, 92, 48),
			Color3.fromRGB(74, 78, 40),
		}
		local weedIndex = 0
		for _, edgeX in { -17, 17 } do
			for z = -100, -440, -13 do
				weedIndex += 1
				local jitterX = (((weedIndex * 37) % 11) - 5) * 0.6
				local jitterZ = ((weedIndex * 53) % 7) - 3
				local wSz = 0.8 + ((weedIndex * 29) % 10) * 0.14
				local weed = createPart(self.nightTown, "RoadWeed" .. weedIndex,
					Vector3.new(wSz * 1.15, wSz * 0.6, wSz),
					CFrame.new(edgeX + jitterX, wSz * 0.3, z + jitterZ),
					weedColors[(weedIndex % #weedColors) + 1], Enum.Material.Grass)
				weed.Shape = Enum.PartType.Ball
				weed.CanCollide = false
			end
		end
		-- Golden autumn bushes: bright yellow shrubs against bare trees (Old Town 3 reference)
		local goldenBushData = {
			{ -78, -168, 2.8 }, { 80, -225, 3.2 }, { -82, -310, 2.5 }, { 78, -375, 3.0 },
		}
		for i, gb in ipairs(goldenBushData) do
			local gBush = createPart(self.nightTown, "GoldenBush" .. i,
				Vector3.new(gb[3] * 1.15, gb[3] * 0.88, gb[3]),
				CFrame.new(gb[1], gb[3] * 0.44, gb[2]),
				Color3.fromRGB(198, 165, 32), Enum.Material.Grass)
			gBush.Shape = Enum.PartType.Ball
			gBush.CanCollide = false
		end
		-- Road puddles: flat dark reflective patches on the dirt road (Old Town 3 reference)
		local puddleData = {
			{ 6, -138, 3.2, 2.4 }, { -4, -195, 4.0, 2.8 }, { 8, -268, 2.8, 2.0 }, { -6, -342, 3.5, 2.5 },
		}
		for i, pd in ipairs(puddleData) do
			local puddle = createPart(self.nightTown, "Puddle" .. i,
				Vector3.new(pd[3], 0.07, pd[4]),
				CFrame.new(pd[1], 0.04, pd[2]),
				Color3.fromRGB(22, 28, 38), Enum.Material.SmoothPlastic)
			puddle.Shape = Enum.PartType.Ball
			puddle.Transparency = 0.25
			puddle.CanCollide = false
		end
		-- Autumn leaf drifts on the road and curbs (Old Town 2 reference: fallen leaves cover the ground)
		local leafData = {
			{ 4, -122, 0.22, Color3.fromRGB(118, 72, 22) },
			{ -18, -145, 0.18, Color3.fromRGB(138, 88, 18) },
			{ 28, -168, 0.24, Color3.fromRGB(105, 60, 15) },
			{ -8, -195, 0.20, Color3.fromRGB(120, 75, 20) },
			{ 20, -225, 0.22, Color3.fromRGB(110, 65, 18) },
			{ -30, -252, 0.18, Color3.fromRGB(130, 82, 16) },
			{ 14, -278, 0.20, Color3.fromRGB(100, 58, 14) },
			{ -4, -315, 0.22, Color3.fromRGB(115, 70, 20) },
			{ 32, -342, 0.18, Color3.fromRGB(108, 64, 16) },
			{ -22, -385, 0.20, Color3.fromRGB(122, 76, 18) },
		}
		for i, ld in ipairs(leafData) do
			local leafSz = 2.2 + (i % 3) * 0.8
			local leaf = createPart(self.nightTown, "LeafDrift" .. i,
				Vector3.new(leafSz, ld[3], leafSz * 0.85),
				CFrame.new(ld[1], ld[3] / 2, ld[2]) * CFrame.Angles(0, i * 0.7, 0),
				ld[4], Enum.Material.Grass)
			leaf.Shape = Enum.PartType.Ball
			leaf.CanCollide = false
		end
	end

	for _, definition in SEARCH_TARGETS do
		local socket = createPart(
			self.nightTown,
			definition.id,
			Vector3.new(6, 4, 6),
			CFrame.new(definition.position),
			definition.color,
			Enum.Material.WoodPlanks
		)
		socket:SetAttribute("EvidenceSocket", true)
		socket:SetAttribute("EvidenceAlias", definition.id)
		socket.Transparency = 1
		socket.CanCollide = false
		table.insert(self.evidenceSockets, socket)
	end
end

function ProductionMapService:GetEvidenceAliases(): { string }
	local aliases: { string } = {}
	for _, socket in self.evidenceSockets do
		table.insert(aliases, socket.Name)
	end
	return aliases
end

function ProductionMapService:SetNight(isNight: boolean)
	setFolderVisible(self.nightTown, isNight)
	for _, descendant in self.dayCamp:GetDescendants() do
		if descendant:IsA("SurfaceLight") then
			descendant.Enabled = isNight
		end
	end

	local atmosphere = Lighting:FindFirstChild("CampAtmosphere")
	local color = Lighting:FindFirstChild("CampColor")
	local bloom = Lighting:FindFirstChild("CampBloom")
	local rays = Lighting:FindFirstChild("CampSunRays")
	local transition = TweenInfo.new(
		if isNight then 1.8 else 1.25,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut
	)
	if isNight then
		Lighting.ClockTime = 1.25
		TweenService:Create(Lighting, transition, {
			Brightness = 0.62,
			Ambient = NIGHT_AMBIENT,
			OutdoorAmbient = Color3.fromRGB(12, 16, 28),
			FogColor = Color3.fromRGB(34, 42, 54),
			FogStart = 14,
			FogEnd = 165,
		}):Play()
		if atmosphere and atmosphere:IsA("Atmosphere") then
			TweenService:Create(atmosphere, transition, {
				Density = 0.58,
				Offset = -0.12,
				Color = Color3.fromRGB(82, 98, 112),
				Decay = Color3.fromRGB(20, 26, 42),
				Glare = 0,
				Haze = 3.5,
			}):Play()
		end
		if color and color:IsA("ColorCorrectionEffect") then
			TweenService:Create(color, transition, {
				Brightness = -0.12,
				Contrast = 0.28,
				Saturation = -0.42,
				TintColor = Color3.fromRGB(142, 168, 198),
			}):Play()
		end
		if bloom and bloom:IsA("BloomEffect") then
			TweenService:Create(bloom, transition, {
				Intensity = 0.42,
				Threshold = 0.82,
			}):Play()
		end
		if rays and rays:IsA("SunRaysEffect") then
			rays.Enabled = false
		end
	else
		Lighting.ClockTime = 14.2
		TweenService:Create(Lighting, transition, {
			Brightness = 2.1,
			Ambient = DAY_AMBIENT,
			OutdoorAmbient = Color3.fromRGB(135, 142, 128),
			FogColor = Color3.fromRGB(188, 201, 188),
			FogStart = 0,
			FogEnd = 100000,
		}):Play()
		if atmosphere and atmosphere:IsA("Atmosphere") then
			TweenService:Create(atmosphere, transition, {
				Density = 0.22,
				Offset = 0.05,
				Color = Color3.fromRGB(199, 213, 200),
				Decay = Color3.fromRGB(92, 111, 98),
				Glare = 0.08,
				Haze = 1.15,
			}):Play()
		end
		if color and color:IsA("ColorCorrectionEffect") then
			TweenService:Create(color, transition, {
				Brightness = 0.02,
				Contrast = 0.08,
				Saturation = -0.04,
				TintColor = Color3.fromRGB(255, 244, 221),
			}):Play()
		end
		if bloom and bloom:IsA("BloomEffect") then
			TweenService:Create(bloom, transition, {
				Intensity = 0.22,
				Threshold = 1.15,
			}):Play()
		end
		if rays and rays:IsA("SunRaysEffect") then
			rays.Enabled = true
		end
	end
end

function ProductionMapService:SetObjectivePromptsEnabled(enabled: boolean)
	for _, descendant in self.objectivesFolder:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant.Enabled = enabled
		end
	end
end

function ProductionMapService:MarkObjectiveComplete(objectiveId: string)
	local station = self.objectivesFolder:FindFirstChild(objectiveId)
	if not station then
		return
	end
	local root = if station:IsA("Model")
		then station:FindFirstChild("InteractionRoot")
		else station
	if root and root:IsA("BasePart") then
		root.Color = Color3.fromRGB(63, 130, 78)
	end
	local indicator = station:FindFirstChild("StatusLamp", true)
	if indicator and indicator:IsA("BasePart") then
		indicator.Color = Color3.fromRGB(79, 214, 112)
	end
	local marker = station:FindFirstChild("ObjectiveMarker", true)
	if marker and marker:IsA("BillboardGui") then
		local label = marker:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = "COMPLETE"
			label.TextColor3 = Color3.fromRGB(111, 239, 144)
		end
	end
	local prompt = station:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Enabled = false
	end
end

function ProductionMapService:ResetObjectives()
	for _, station in self.objectivesFolder:GetChildren() do
		local root = if station:IsA("Model")
			then station:FindFirstChild("InteractionRoot")
			else station
		if root and root:IsA("BasePart") then
			local original = root:GetAttribute("OriginalColor")
			if typeof(original) == "Color3" then
				root.Color = original
			end
		end
		local indicator = station:FindFirstChild("StatusLamp", true)
		if indicator and indicator:IsA("BasePart") then
			indicator.Color = Color3.fromRGB(187, 72, 49)
		end
		local marker = station:FindFirstChild("ObjectiveMarker", true)
		if marker and marker:IsA("BillboardGui") then
			local label = marker:FindFirstChildOfClass("TextLabel")
			if label then
				local originalText = label:GetAttribute("OriginalText")
				if type(originalText) == "string" then
					label.Text = originalText
				end
				label.TextColor3 = Color3.fromRGB(244, 224, 176)
			end
		end
		local prompt = station:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Enabled = false
		end
	end
end

function ProductionMapService:SpawnEvidence()
	self:ClearEvidence()
	self.evidenceClaimed = {}
	for _, socket in self.evidenceSockets do
		local alias = socket.Name
		local search = createPart(
			self.evidenceFolder,
			alias,
			Vector3.new(3.5, 2, 3.5),
			socket.CFrame,
			Color3.fromRGB(173, 154, 92),
			Enum.Material.Neon,
			0.18
		)
		search:SetAttribute("EvidenceId", alias)
		local prompt = createPrompt(search, "Search", "Possible evidence", 0.9)
		prompt.Triggered:Connect(function(player: Player)
			if self.evidenceClaimed[alias] then
				return
			end
			if self.onEvidence(player, alias) then
				self.evidenceClaimed[alias] = true
				search:Destroy()
			end
		end)
	end
end

function ProductionMapService:ClearEvidence()
	self.evidenceFolder:ClearAllChildren()
	self.evidenceClaimed = {}
end

function ProductionMapService:ResetRound()
	self:ClearEvidence()
	self:ResetObjectives()
	for _, door in self.interactiveDoors do
		door.isOpen = false
		door.part.CFrame = door.closedCFrame
		door.part.CanCollide = true
		door.prompt.ActionText = "Open"
	end
	self:SetNight(false)
end

return ProductionMapService
