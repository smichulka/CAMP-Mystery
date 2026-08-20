--!strict

-- InteractableWorld: dense day-camp + night-town + midway flavor interactions.
-- Every prop is meant to be touched — Inspect, Sit, Ring, Tune, Play, Read.
-- Soft mystery texture only (no lethal stakes). Optional Creator Store meshes
-- under ServerStorage.ServerAssets.Interactables are cloned when present;
-- procedural fallbacks always ship (see docs/INTERACTABLE_ASSETS.md).

local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")

local WorldKit = require(script.Parent:WaitForChild("WorldKit"))

local WOOD = Color3.fromRGB(110, 82, 52)
local WOOD_DARK = Color3.fromRGB(72, 52, 36)
local PAPER = Color3.fromRGB(228, 220, 196)
local METAL = Color3.fromRGB(96, 100, 104)
local RUST = Color3.fromRGB(126, 82, 54)
local RED = Color3.fromRGB(178, 52, 44)
local CREAM = Color3.fromRGB(236, 228, 204)
local NEON = Color3.fromRGB(255, 120, 80)

local InteractableWorld = {}

local builtCount = 0

local function tryCloneAsset(name: string): Model?
	local assets = ServerStorage:FindFirstChild("ServerAssets")
	local folder = if assets then assets:FindFirstChild("Interactables") else nil
	local source = if folder then folder:FindFirstChild(name) else nil
	if source and source:IsA("Model") then
		local clone = source:Clone()
		for _, desc in clone:GetDescendants() do
			if
				desc:IsA("Script")
				or desc:IsA("LocalScript")
				or desc:IsA("ModuleScript")
				or desc:IsA("RemoteEvent")
				or desc:IsA("RemoteFunction")
			then
				desc:Destroy()
			end
		end
		for _, desc in clone:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Anchored = true
			end
		end
		return clone
	end
	return nil
end

local function placeModel(model: Model, parent: Instance, at: CFrame, scale: number?)
	model.Parent = parent
	if scale and scale ~= 1 and typeof((model :: any).ScaleTo) == "function" then
		pcall(function()
			(model :: any):ScaleTo(scale)
		end)
	end
	model:PivotTo(at)
end

local function feedbackAction(
	part: BasePart,
	actionText: string,
	objectText: string,
	response: string,
	holdDuration: number?
): ProximityPrompt
	local prompt = WorldKit.prompt(part, actionText, objectText, holdDuration or 0.35)
	local feedback = Instance.new("BillboardGui")
	feedback.Name = "InteractionFeedback"
	feedback.Size = UDim2.new(9, 0, 2.4, 0)
	feedback.StudsOffset = Vector3.new(0, 3.6, 0)
	feedback.AlwaysOnTop = true
	feedback.MaxDistance = 50
	feedback.Enabled = false
	feedback.Parent = part
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
	local version = 0
	local idleAction = actionText
	prompt.Triggered:Connect(function()
		version += 1
		local current = version
		prompt.ActionText = "Done"
		feedback.Enabled = true
		task.delay(3.4, function()
			if prompt.Parent and version == current then
				prompt.ActionText = idleAction
				feedback.Enabled = false
			end
		end)
	end)
	return prompt
end

local function playCue(attributeName: string, fallbackId: string?)
	local id = SoundService:GetAttribute(attributeName)
	local soundId = if typeof(id) == "string" and id ~= "" then id else (fallbackId or "")
	if soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.55
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local function bump()
	builtCount += 1
end

local function buildBulletin(parent: Instance, at: CFrame, title: string, body: string)
	local mesh = tryCloneAsset("BulletinBoard")
	if mesh then
		placeModel(mesh, parent, at, 1)
		local anchor = mesh.PrimaryPart or mesh:FindFirstChildWhichIsA("BasePart", true)
		if anchor and anchor:IsA("BasePart") then
			WorldKit.inspect(anchor, title, body, 0.5)
			bump()
			return
		end
		mesh:Destroy()
	end
	local board = WorldKit.part(parent, "BulletinBoard", Vector3.new(4.2, 3.2, 0.28), at, WOOD_DARK, Enum.Material.WoodPlanks)
	WorldKit.part(parent, "BulletinPaper", Vector3.new(3.6, 2.6, 0.08), at * CFrame.new(0, 0, -0.2), PAPER, Enum.Material.Cardboard)
	WorldKit.inspect(board, title, body, 0.5)
	bump()
end

local function buildMailbox(parent: Instance, at: CFrame)
	local box = WorldKit.part(parent, "CampMailbox", Vector3.new(1.4, 1.6, 2.2), at, RED, Enum.Material.Metal)
	WorldKit.part(parent, "MailboxFlag", Vector3.new(0.15, 0.7, 0.9), at * CFrame.new(0.85, 0.5, 0), Color3.fromRGB(220, 180, 40), Enum.Material.Metal)
	WorldKit.inspect(
		box,
		"Camp mailbox",
		"Letters from home. One envelope is empty — only a pressed leaf inside.",
		0.45
	)
	bump()
end

local function buildRadio(parent: Instance, at: CFrame, night: boolean)
	local mesh = tryCloneAsset("RustyRadio")
	local radio: BasePart
	if mesh then
		placeModel(mesh, parent, at, 0.85)
		local anchor = mesh.PrimaryPart or mesh:FindFirstChildWhichIsA("BasePart", true)
		if not (anchor and anchor:IsA("BasePart")) then
			mesh:Destroy()
			radio = WorldKit.part(parent, "CampRadio", Vector3.new(1.8, 1.1, 1.0), at, METAL, Enum.Material.Metal)
		else
			radio = anchor
		end
	else
		radio = WorldKit.part(parent, "CampRadio", Vector3.new(1.8, 1.1, 1.0), at, METAL, Enum.Material.Metal)
		WorldKit.part(parent, "RadioDial", Vector3.new(0.25, 0.25, 0.2), at * CFrame.new(0.55, 0.15, -0.55), Color3.fromRGB(40, 40, 44), Enum.Material.SmoothPlastic)
	end
	local lines = if night
		then {
			"Static… then a weather report from a station that shut down years ago.",
			"A call-in show argues about lights in the meadow. Host hangs up mid-sentence.",
			"Faint calliope music underneath the hiss — Fairgrounds frequency?",
		}
		else {
			"Morning show: 'Finish your camp chores before dusk, campers!'",
			"Counselor Ortiz left a sticky note: CHECK THE GENERATOR.",
			"A jingle about Midway Festival popcorn plays twice.",
		}
	local index = 0
	local prompt = WorldKit.prompt(radio, "Tune Radio", if night then "Abandoned radio" else "Camp radio", 0.3)
	prompt.Triggered:Connect(function()
		index = (index % #lines) + 1
		local existing = radio:FindFirstChild("RadioFeedback")
		if existing then
			existing:Destroy()
		end
		local feedback = Instance.new("BillboardGui")
		feedback.Name = "RadioFeedback"
		feedback.Size = UDim2.new(9, 0, 2.4, 0)
		feedback.StudsOffset = Vector3.new(0, 3.8, 0)
		feedback.AlwaysOnTop = true
		feedback.Enabled = true
		feedback.Parent = radio
		local label = Instance.new("TextLabel")
		label.BackgroundColor3 = Color3.fromRGB(13, 17, 16)
		label.BackgroundTransparency = 0.08
		label.BorderSizePixel = 0
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamMedium
		label.Text = lines[index]
		label.TextColor3 = Color3.fromRGB(244, 224, 176)
		label.TextSize = 15
		label.TextWrapped = true
		label.Parent = feedback
		playCue("WorldRadioTuneAssetId", nil)
		task.delay(4, function()
			if feedback.Parent then
				feedback:Destroy()
			end
		end)
	end)
	bump()
end

local function buildDinnerBell(parent: Instance, at: CFrame)
	local post = WorldKit.part(parent, "BellPost", Vector3.new(0.45, 4.2, 0.45), at, WOOD, Enum.Material.Wood)
	local bell = WorldKit.part(parent, "DinnerBell", Vector3.new(1.4, 1.2, 1.4), at * CFrame.new(0, 2.2, 0), Color3.fromRGB(190, 150, 60), Enum.Material.Metal)
	feedbackAction(
		bell,
		"Ring Bell",
		"Dinner bell",
		"CLANG — every camper within earshot looks toward the lodge.",
		0.25
	)
	bump()
end

local function buildWishJar(parent: Instance, at: CFrame)
	local jar = WorldKit.part(parent, "WishJar", Vector3.new(1.2, 1.6, 1.2), at, Color3.fromRGB(160, 200, 210), Enum.Material.Glass)
	jar.Transparency = 0.35
	WorldKit.inspect(
		jar,
		"Wish jar",
		"Folded notes: 'Keep the lights on.' 'Don't go alone.' 'I saw someone at Cabin Zero.'",
		0.5
	)
	bump()
end

local function buildPhotoCutout(parent: Instance, at: CFrame)
	local board = WorldKit.part(parent, "PhotoCutout", Vector3.new(5.5, 6.2, 0.4), at, CREAM, Enum.Material.Cardboard)
	WorldKit.part(parent, "CutoutHoleL", Vector3.new(1.2, 1.2, 0.5), at * CFrame.new(-1.1, 1.4, 0), Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic)
	WorldKit.part(parent, "CutoutHoleR", Vector3.new(1.2, 1.2, 0.5), at * CFrame.new(1.1, 1.4, 0), Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic)
	feedbackAction(
		board,
		"Pose",
		"Camp photo cutout",
		"Snap! Imaginary flash. You look ridiculous — and slightly braver.",
		0.2
	)
	bump()
end

local function buildTrailKiosk(parent: Instance, at: CFrame)
	local kiosk = WorldKit.part(parent, "TrailKiosk", Vector3.new(3.4, 4.0, 0.35), at, WOOD, Enum.Material.WoodPlanks)
	WorldKit.part(parent, "TrailMapFace", Vector3.new(3.0, 3.4, 0.08), at * CFrame.new(0, 0.1, -0.22), PAPER, Enum.Material.Cardboard)
	WorldKit.inspect(
		kiosk,
		"Trail map",
		"Red pin on the northeast meadow: MIDWAY FESTIVAL. Pencil arrow: 'Don't miss night rides.'",
		0.45
	)
	bump()
end

local function buildBugSpray(parent: Instance, at: CFrame)
	local station = WorldKit.part(parent, "BugSprayStation", Vector3.new(1.6, 2.4, 1.0), at, Color3.fromRGB(70, 110, 70), Enum.Material.Metal)
	feedbackAction(
		station,
		"Spray",
		"Bug spray station",
		"Pssst. Smells like citronella and summer. Mosquitoes hate you slightly more.",
		0.3
	)
	bump()
end

local function buildWaterCooler(parent: Instance, at: CFrame)
	local cooler = WorldKit.part(parent, "WaterCooler", Vector3.new(1.5, 2.8, 1.5), at, Color3.fromRGB(210, 220, 230), Enum.Material.SmoothPlastic)
	local jug = WorldKit.part(parent, "WaterJug", Vector3.new(1.3, 1.2, 1.3), at * CFrame.new(0, 1.6, 0), Color3.fromRGB(140, 190, 220), Enum.Material.Glass)
	jug.Transparency = 0.4
	feedbackAction(
		cooler,
		"Fill Cup",
		"Water cooler",
		"Cold water. Someone carved 'TRUST NO ONE' into the plastic rim.",
		0.35
	)
	bump()
end

local function buildSongbook(parent: Instance, at: CFrame)
	local book = WorldKit.part(parent, "CampSongbook", Vector3.new(1.4, 0.25, 1.0), at, Color3.fromRGB(90, 40, 40), Enum.Material.Leather)
	WorldKit.inspect(
		book,
		"Camp songbook",
		"Page dog-eared: 'By the light of the silvery moon…' A newer verse mentions calliope music.",
		0.4
	)
	bump()
end

local function buildTrophyCase(parent: Instance, at: CFrame)
	local case = WorldKit.part(parent, "TrophyCase", Vector3.new(3.6, 3.2, 1.2), at, WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(parent, "TrophyGlass", Vector3.new(3.2, 2.6, 0.12), at * CFrame.new(0, 0.1, -0.55), Color3.fromRGB(180, 210, 220), Enum.Material.Glass).Transparency = 0.45
	WorldKit.inspect(
		case,
		"Trophy case",
		"Canoe Race '19. Archery '21. One plaque is missing — only dust and two screw holes.",
		0.5
	)
	bump()
end

local function buildLostAndFound(parent: Instance, at: CFrame)
	local bin = WorldKit.part(parent, "LostAndFound", Vector3.new(2.8, 1.6, 2.0), at, Color3.fromRGB(60, 70, 90), Enum.Material.Metal)
	WorldKit.inspect(
		bin,
		"Lost & found",
		"One left sneaker. A cracked flashlight. A camp armband in mustard yellow — no name tag.",
		0.45
	)
	bump()
end

local function buildBinoculars(parent: Instance, at: CFrame)
	WorldKit.part(parent, "BinocularStand", Vector3.new(0.6, 3.0, 0.6), at, METAL, Enum.Material.Metal)
	local bins = WorldKit.part(parent, "Binoculars", Vector3.new(1.6, 0.7, 0.9), at * CFrame.new(0, 1.7, 0), Color3.fromRGB(40, 44, 48), Enum.Material.Metal)
	feedbackAction(
		bins,
		"Look",
		"Binoculars",
		"You catch Midway lights to the northeast… and a shape that might be a counselor on the trail.",
		0.4
	)
	bump()
end

local function buildNewspaperBox(parent: Instance, at: CFrame)
	local box = WorldKit.part(parent, "NewspaperBox", Vector3.new(1.6, 2.4, 1.4), at, RED, Enum.Material.Metal)
	WorldKit.inspect(
		box,
		"County gazette box",
		"Headline yellowed: 'ABANDONED TOWN ANNEXED TO CAMP PROPERTY.' Date torn off.",
		0.45
	)
	bump()
end

local function buildPayphone(parent: Instance, at: CFrame)
	local booth = WorldKit.part(parent, "PayphoneBooth", Vector3.new(2.2, 5.0, 2.2), at, Color3.fromRGB(50, 90, 70), Enum.Material.Metal)
	feedbackAction(
		booth,
		"Lift Receiver",
		"Payphone",
		"Dial tone… then a whisper: 'Don't vote the wrong name.' Click.",
		0.4
	)
	bump()
end

local function buildVending(parent: Instance, at: CFrame)
	local machine = WorldKit.part(parent, "VendingMachine", Vector3.new(2.4, 4.2, 1.6), at, Color3.fromRGB(40, 80, 140), Enum.Material.Metal)
	feedbackAction(
		machine,
		"Kick Machine",
		"Dead vending machine",
		"Nothing falls. A faded sticker reads: OUT OF ORDER SINCE THE LAST BLOOD MOON.",
		0.35
	)
	bump()
end

local function buildWantedPoster(parent: Instance, at: CFrame)
	local poster = WorldKit.part(parent, "WantedPoster", Vector3.new(2.0, 2.8, 0.08), at, PAPER, Enum.Material.Cardboard)
	WorldKit.inspect(
		poster,
		"Wanted poster",
		"Sketch of a hooded figure. Reward blanked out. Someone wrote 'IT'S ONE OF US' in red marker.",
		0.4
	)
	bump()
end

local function buildGravestone(parent: Instance, at: CFrame, epitaph: string)
	local stone = WorldKit.part(parent, "Gravestone", Vector3.new(1.6, 2.2, 0.45), at, Color3.fromRGB(110, 112, 118), Enum.Material.Slate)
	WorldKit.inspect(stone, "Gravestone", epitaph, 0.5)
	bump()
end

local function buildMotelGuestbook(parent: Instance, at: CFrame)
	local desk = WorldKit.part(parent, "MotelDesk", Vector3.new(3.2, 1.4, 1.8), at, WOOD, Enum.Material.Wood)
	local book = WorldKit.part(parent, "Guestbook", Vector3.new(1.2, 0.2, 0.9), at * CFrame.new(0, 0.85, 0), PAPER, Enum.Material.Cardboard)
	WorldKit.inspect(
		book,
		"Motel guestbook",
		"Last entry: 'Checking out early. Heard the calliope again.' No signature.",
		0.45
	)
	bump()
end

local function buildDriveInSpeaker(parent: Instance, at: CFrame)
	local pole = WorldKit.part(parent, "DriveInSpeaker", Vector3.new(0.35, 3.4, 0.35), at, METAL, Enum.Material.Metal)
	local head = WorldKit.part(parent, "SpeakerHead", Vector3.new(1.0, 0.8, 0.8), at * CFrame.new(0, 1.5, 0.4), RUST, Enum.Material.Metal)
	feedbackAction(
		head,
		"Listen",
		"Drive-in speaker",
		"A film reel ticks. Dialogue: 'We should have left before nightfall.'",
		0.35
	)
	bump()
end

local function buildGasPump(parent: Instance, at: CFrame)
	local pump = WorldKit.part(parent, "GasPump", Vector3.new(1.4, 3.6, 1.2), at, Color3.fromRGB(180, 50, 40), Enum.Material.Metal)
	WorldKit.inspect(
		pump,
		"Gas pump",
		"Hose cracked. Gauge stuck at empty. Fresh footprints circle it twice.",
		0.4
	)
	bump()
end

local function buildArcade(parent: Instance, at: CFrame)
	local cab = WorldKit.part(parent, "ArcadeCabinet", Vector3.new(2.2, 3.8, 2.0), at, Color3.fromRGB(30, 30, 40), Enum.Material.SmoothPlastic)
	local screen = WorldKit.part(parent, "ArcadeScreen", Vector3.new(1.6, 1.2, 0.1), at * CFrame.new(0, 1.0, -0.95), Color3.fromRGB(20, 60, 40), Enum.Material.Neon)
	screen.Transparency = 0.2
	feedbackAction(
		cab,
		"Insert Coin",
		"Dead arcade",
		"INSERT COIN blinks once… then the screen shows a stick-figure camper being chased.",
		0.4
	)
	bump()
end

local function buildManhole(parent: Instance, at: CFrame)
	local cover = WorldKit.part(parent, "ManholeCover", Vector3.new(3.2, 0.2, 3.2), at, METAL, Enum.Material.Metal)
	WorldKit.inspect(
		cover,
		"Manhole cover",
		"Scratches like claw marks radiate from the center. Best not to lift it.",
		0.5
	)
	bump()
end

local function buildRingToss(parent: Instance, at: CFrame)
	local booth = WorldKit.part(parent, "RingTossBooth", Vector3.new(5.0, 3.2, 3.0), at, Color3.fromRGB(40, 90, 160), Enum.Material.WoodPlanks)
	WorldKit.part(parent, "RingTossStripe", Vector3.new(5.0, 0.4, 0.15), at * CFrame.new(0, 1.2, -1.5), NEON, Enum.Material.Neon)
	feedbackAction(
		booth,
		"Try Toss",
		"Ring toss",
		"Clink — near miss. The carnie mannequin seems to wink. Prize shelf stays locked.",
		0.35
	)
	bump()
end

local function buildFortuneTeller(parent: Instance, at: CFrame)
	local tent = WorldKit.part(parent, "FortuneBooth", Vector3.new(4.0, 3.6, 4.0), at, Color3.fromRGB(70, 30, 90), Enum.Material.Fabric)
	local orb = WorldKit.part(parent, "CrystalOrb", Vector3.new(1.2, 1.2, 1.2), at * CFrame.new(0, 0.2, -0.8), Color3.fromRGB(160, 100, 220), Enum.Material.Glass)
	orb.Transparency = 0.25
	orb.Material = Enum.Material.Neon
	local fortunes = {
		"The orb swirls: 'Three clues tell the truth. One was planted.'",
		"A whisper: 'Counselors can slip. Ask Schedule twice.'",
		"Fog clears: 'The Midway ticket is optional. The vote is not.'",
		"You see your own face — then a different camper's armband color.",
	}
	local i = 0
	local prompt = WorldKit.prompt(orb, "Ask Fortune", "Fortune booth", 0.55)
	prompt.Triggered:Connect(function()
		i = (i % #fortunes) + 1
		local existing = orb:FindFirstChild("FortuneFeedback")
		if existing then
			existing:Destroy()
		end
		local feedback = Instance.new("BillboardGui")
		feedback.Name = "FortuneFeedback"
		feedback.Size = UDim2.new(10, 0, 2.6, 0)
		feedback.StudsOffset = Vector3.new(0, 3.5, 0)
		feedback.AlwaysOnTop = true
		feedback.Enabled = true
		feedback.Parent = orb
		local label = Instance.new("TextLabel")
		label.BackgroundColor3 = Color3.fromRGB(20, 10, 28)
		label.BackgroundTransparency = 0.05
		label.BorderSizePixel = 0
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamMedium
		label.Text = fortunes[i]
		label.TextColor3 = Color3.fromRGB(230, 200, 255)
		label.TextSize = 15
		label.TextWrapped = true
		label.Parent = feedback
		task.delay(4.5, function()
			if feedback.Parent then
				feedback:Destroy()
			end
		end)
	end)
	bump()
end

local function buildStrongman(parent: Instance, at: CFrame)
	local base = WorldKit.part(parent, "StrongmanBase", Vector3.new(3.0, 0.5, 3.0), at, WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(parent, "StrongmanTower", Vector3.new(0.6, 6.0, 0.6), at * CFrame.new(0, 3.2, 0), METAL, Enum.Material.Metal)
	WorldKit.part(parent, "StrongmanBell", Vector3.new(1.4, 0.5, 1.4), at * CFrame.new(0, 6.2, 0), Color3.fromRGB(200, 160, 50), Enum.Material.Metal)
	feedbackAction(
		base,
		"Swing Mallet",
		"Strongman game",
		"THUD. The puck climbs… stalls under the bell. A carnie chalk mark says 'MURDERER CHEATS.'",
		0.45
	)
	bump()
end

local function buildFunhouseMirror(parent: Instance, at: CFrame)
	local mirror = WorldKit.part(parent, "FunhouseMirror", Vector3.new(3.2, 5.5, 0.25), at, Color3.fromRGB(180, 200, 210), Enum.Material.Glass)
	mirror.Transparency = 0.15
	WorldKit.inspect(
		mirror,
		"Funhouse mirror",
		"Your reflection stretches — then for a blink, someone else stands behind you.",
		0.4
	)
	bump()
end

local function buildCottonCandy(parent: Instance, at: CFrame)
	local cart = WorldKit.part(parent, "CottonCandyCart", Vector3.new(3.4, 2.4, 2.2), at, Color3.fromRGB(240, 120, 160), Enum.Material.Metal)
	WorldKit.inspect(
		cart,
		"Cotton candy cart",
		"Sugar dust and a half-torn ticket stub: MIDWAY AFTER DARK — KEEP YOUR WRISTBAND ON.",
		0.4
	)
	bump()
end

local function buildPicnicWithSeats(parent: Instance, at: CFrame)
	local mesh = tryCloneAsset("PicnicTable")
	if mesh then
		placeModel(mesh, parent, at, 1)
		bump()
	else
		WorldKit.part(parent, "PicnicTop", Vector3.new(6.0, 0.3, 3.2), at, WOOD, Enum.Material.WoodPlanks)
		WorldKit.part(parent, "PicnicLegL", Vector3.new(0.35, 1.6, 0.35), at * CFrame.new(-2.4, -0.95, 0), WOOD_DARK, Enum.Material.Wood)
		WorldKit.part(parent, "PicnicLegR", Vector3.new(0.35, 1.6, 0.35), at * CFrame.new(2.4, -0.95, 0), WOOD_DARK, Enum.Material.Wood)
		bump()
	end
	local p = at.Position
	WorldKit.seat(parent, "PicnicSeatA", p + Vector3.new(-1.5, -0.55, -2.2), p, WOOD)
	WorldKit.seat(parent, "PicnicSeatB", p + Vector3.new(1.5, -0.55, -2.2), p, WOOD)
	WorldKit.seat(parent, "PicnicSeatC", p + Vector3.new(-1.5, -0.55, 2.2), p, WOOD)
	WorldKit.seat(parent, "PicnicSeatD", p + Vector3.new(1.5, -0.55, 2.2), p, WOOD)
	bump()
end

local function buildPlazaBench(parent: Instance, at: CFrame)
	local mesh = tryCloneAsset("ParkBench")
	if mesh then
		placeModel(mesh, parent, at, 1)
	else
		WorldKit.part(parent, "BenchSeat", Vector3.new(4.4, 0.35, 1.5), at, WOOD, Enum.Material.WoodPlanks)
		WorldKit.part(parent, "BenchBack", Vector3.new(4.4, 1.4, 0.3), at * CFrame.new(0, 0.85, 0.55), WOOD, Enum.Material.WoodPlanks)
	end
	local p = at.Position
	WorldKit.seat(parent, "BenchSit", p + Vector3.new(0, 0.35, 0), p + at.LookVector * 4, WOOD)
	bump()
end

local function buildFishingPole(parent: Instance, at: CFrame)
	local pole = WorldKit.part(parent, "FishingPole", Vector3.new(0.18, 4.6, 0.18), at * CFrame.Angles(0, 0, math.rad(28)), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(parent, "FishingReel", Vector3.new(0.35, 0.35, 0.45), at * CFrame.new(0.15, -0.8, 0), METAL, Enum.Material.Metal)
	feedbackAction(
		pole,
		"Try Cast",
		"Fishing pole",
		"Line sings out… splash. Nothing bites. Ripples settle into a face-shaped swirl, then gone.",
		0.4
	)
	bump()
end

local function buildLifeRing(parent: Instance, at: CFrame)
	local ring = WorldKit.part(parent, "LifeRing", Vector3.new(1.8, 0.35, 1.8), at, RED, Enum.Material.SmoothPlastic)
	ring.Shape = Enum.PartType.Cylinder
	WorldKit.inspect(
		ring,
		"Life ring",
		"White lettering: CAMP PROPERTY. Rope frayed where someone clung too hard.",
		0.4
	)
	bump()
end

local function buildBoatWhistle(parent: Instance, at: CFrame)
	local whistle = WorldKit.part(parent, "BoatWhistle", Vector3.new(0.7, 0.5, 1.4), at, Color3.fromRGB(210, 200, 80), Enum.Material.Metal)
	feedbackAction(
		whistle,
		"Blow Whistle",
		"Boat whistle",
		"TWEEEET — ducks scatter. Across the lake, something answers once… then silence.",
		0.3
	)
	bump()
end

local function buildDockCooler(parent: Instance, at: CFrame)
	local cooler = WorldKit.part(parent, "DockCooler", Vector3.new(2.2, 1.4, 1.4), at, Color3.fromRGB(40, 90, 160), Enum.Material.SmoothPlastic)
	WorldKit.part(parent, "CoolerLid", Vector3.new(2.15, 0.2, 1.35), at * CFrame.new(0, 0.8, 0), Color3.fromRGB(30, 70, 130), Enum.Material.SmoothPlastic)
	WorldKit.inspect(
		cooler,
		"Dock cooler",
		"Melted ice and one unclaimed soda. Tape on the lid: 'BUDDY SYSTEM — NO SOLO SWIMS.'",
		0.4
	)
	bump()
end

local function buildSkipRocks(parent: Instance, at: CFrame)
	local pile = WorldKit.part(parent, "SkipRockPile", Vector3.new(2.4, 0.6, 2.0), at, Color3.fromRGB(120, 118, 110), Enum.Material.Slate)
	WorldKit.part(parent, "SkipRockA", Vector3.new(0.55, 0.18, 0.45), at * CFrame.new(-0.5, 0.4, 0.2), Color3.fromRGB(140, 138, 130), Enum.Material.Slate)
	WorldKit.part(parent, "SkipRockB", Vector3.new(0.5, 0.16, 0.4), at * CFrame.new(0.4, 0.38, -0.15), Color3.fromRGB(130, 128, 120), Enum.Material.Slate)
	feedbackAction(
		pile,
		"Play",
		"Skip-rocks pile",
		"One… two… three skips. The fourth plink echoes longer than it should.",
		0.3
	)
	bump()
end

local function buildLakeDockCluster(parent: Instance, origin: Vector3)
	local dock = WorldKit.model(parent, "InteractableLakeDock")
	buildFishingPole(dock, CFrame.new(origin + Vector3.new(4, 2.2, -2)) * CFrame.Angles(0, math.rad(-20), 0))
	buildLifeRing(dock, CFrame.new(origin + Vector3.new(-2, 1.0, 3)) * CFrame.Angles(0, 0, math.rad(90)))
	buildBoatWhistle(dock, CFrame.new(origin + Vector3.new(1, 1.1, 1)))
	buildDockCooler(dock, CFrame.new(origin + Vector3.new(-3, 0.9, -1)))
	buildSkipRocks(dock, CFrame.new(origin + Vector3.new(6, 0.4, 4)))
	WorldKit.seat(dock, "DockEdgeSeatA", origin + Vector3.new(2, 0.55, -3.5), origin + Vector3.new(12, 0.55, 0), WOOD)
	WorldKit.seat(dock, "DockEdgeSeatB", origin + Vector3.new(0, 0.55, -3.5), origin + Vector3.new(12, 0.55, 0), WOOD)
	bump()
end

local function buildBalloonDart(parent: Instance, at: CFrame)
	local booth = WorldKit.part(parent, "BalloonDartBooth", Vector3.new(4.8, 3.4, 2.8), at, Color3.fromRGB(200, 60, 90), Enum.Material.WoodPlanks)
	WorldKit.part(parent, "BalloonBoard", Vector3.new(4.2, 2.6, 0.2), at * CFrame.new(0, 0.2, -1.3), Color3.fromRGB(40, 40, 50), Enum.Material.SmoothPlastic)
	for i = -1, 1 do
		local balloon = WorldKit.part(parent, "Balloon" .. tostring(i + 2), Vector3.new(0.7, 0.9, 0.7), at * CFrame.new(i * 1.1, 0.4, -1.35), Color3.fromRGB(255, 80 + i * 40, 120), Enum.Material.SmoothPlastic)
		balloon.Shape = Enum.PartType.Ball
		balloon.CanCollide = false
	end
	feedbackAction(
		booth,
		"Try Throw",
		"Balloon dart",
		"Thwick — balloon wobbles, stays whole. Carnie chalk: 'THREE DARTS / ONE PRIZE / NO REFUNDS.'",
		0.35
	)
	bump()
end

local function buildMilkBottlePyramid(parent: Instance, at: CFrame)
	local stand = WorldKit.part(parent, "MilkBottleStand", Vector3.new(3.6, 1.0, 2.4), at, WOOD, Enum.Material.WoodPlanks)
	local colors = {
		Color3.fromRGB(240, 240, 245),
		Color3.fromRGB(235, 235, 240),
		Color3.fromRGB(230, 230, 238),
	}
	local offsets = {
		Vector3.new(-0.7, 1.1, 0),
		Vector3.new(0.7, 1.1, 0),
		Vector3.new(0, 1.1, 0.55),
		Vector3.new(0, 2.0, 0.2),
	}
	for i, offset in offsets do
		WorldKit.part(parent, "MilkBottle" .. tostring(i), Vector3.new(0.55, 1.1, 0.55), at * CFrame.new(offset), colors[((i - 1) % #colors) + 1], Enum.Material.Glass)
	end
	feedbackAction(
		stand,
		"Knock Down",
		"Milk bottle pyramid",
		"Clatter! Two bottles tip… the top one somehow stays. Rigged? Or lucky?",
		0.4
	)
	bump()
end

local function buildDuckPond(parent: Instance, at: CFrame)
	local tub = WorldKit.part(parent, "DuckPondTub", Vector3.new(4.5, 1.2, 3.2), at, Color3.fromRGB(50, 120, 170), Enum.Material.Metal)
	local water = WorldKit.part(parent, "DuckPondWater", Vector3.new(4.0, 0.3, 2.7), at * CFrame.new(0, 0.35, 0), Color3.fromRGB(90, 170, 200), Enum.Material.Glass)
	water.Transparency = 0.35
	WorldKit.part(parent, "RubberDuckA", Vector3.new(0.6, 0.5, 0.7), at * CFrame.new(-0.8, 0.55, 0.2), Color3.fromRGB(240, 200, 50), Enum.Material.SmoothPlastic)
	WorldKit.part(parent, "RubberDuckB", Vector3.new(0.55, 0.45, 0.65), at * CFrame.new(0.9, 0.52, -0.3), Color3.fromRGB(240, 190, 40), Enum.Material.SmoothPlastic)
	feedbackAction(
		tub,
		"Scoop Duck",
		"Duck pond",
		"You scoop a smiling duck. Number on the bottom: 7. Prize window closed — 'SEE CARNIE.'",
		0.35
	)
	bump()
end

local function buildDunkTank(parent: Instance, at: CFrame)
	local tank = WorldKit.part(parent, "DunkTankFrame", Vector3.new(4.0, 4.5, 3.5), at, Color3.fromRGB(40, 100, 160), Enum.Material.Metal)
	local glass = WorldKit.part(parent, "DunkTankGlass", Vector3.new(3.4, 3.2, 0.15), at * CFrame.new(0, 0.2, -1.7), Color3.fromRGB(140, 200, 220), Enum.Material.Glass)
	glass.Transparency = 0.45
	local seatPos = at.Position + Vector3.new(0, 1.6, 0.4)
	WorldKit.seat(parent, "DunkTankSeat", seatPos, at.Position + at.LookVector * 6, Color3.fromRGB(180, 60, 50))
	local lever = WorldKit.part(parent, "DunkTankLever", Vector3.new(0.35, 1.6, 0.35), at * CFrame.new(2.4, 0.2, -1.2), METAL, Enum.Material.Metal)
	WorldKit.inspect(
		lever,
		"Dunk tank lever",
		"Target plate dented. Note taped on: 'COUNSELOR SHIFT — DON'T ACTUALLY DROP ANYONE.'",
		0.4
	)
	bump()
	bump()
end

local function buildPrizeWheel(parent: Instance, at: CFrame)
	local post = WorldKit.part(parent, "PrizeWheelPost", Vector3.new(0.5, 4.0, 0.5), at, WOOD_DARK, Enum.Material.Wood)
	local wheel = WorldKit.part(parent, "PrizeWheel", Vector3.new(3.6, 3.6, 0.35), at * CFrame.new(0, 1.4, -0.4), Color3.fromRGB(220, 80, 60), Enum.Material.SmoothPlastic)
	wheel.Shape = Enum.PartType.Cylinder
	WorldKit.part(parent, "PrizeWheelHub", Vector3.new(0.6, 0.6, 0.5), at * CFrame.new(0, 1.4, -0.55), Color3.fromRGB(240, 200, 60), Enum.Material.Metal)
	local spins = {
		"Click-click-click… lands on FREE POPCORN. The chute is empty.",
		"Wheel sings. BONUS SPIN — same wedge as last time. Rigged luck?",
		"Pointer stops on MYSTERY TOKEN. A faded Midway stamp falls out.",
		"Almost… TRY AGAIN. The carnie mannequin's painted smile widens.",
		"JACKPOT wedge! Curtain stays shut. A whisper: 'Save it for after dark.'",
	}
	local i = 0
	local prompt = WorldKit.prompt(wheel, "Spin Wheel", "Prize wheel", 0.45)
	prompt.Triggered:Connect(function()
		i = (i % #spins) + 1
		local existing = wheel:FindFirstChild("WheelFeedback")
		if existing then
			existing:Destroy()
		end
		local feedback = Instance.new("BillboardGui")
		feedback.Name = "WheelFeedback"
		feedback.Size = UDim2.new(10, 0, 2.6, 0)
		feedback.StudsOffset = Vector3.new(0, 3.8, 0)
		feedback.AlwaysOnTop = true
		feedback.Enabled = true
		feedback.Parent = wheel
		local label = Instance.new("TextLabel")
		label.BackgroundColor3 = Color3.fromRGB(20, 12, 10)
		label.BackgroundTransparency = 0.06
		label.BorderSizePixel = 0
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamMedium
		label.Text = spins[i]
		label.TextColor3 = Color3.fromRGB(255, 220, 160)
		label.TextSize = 15
		label.TextWrapped = true
		label.Parent = feedback
		task.delay(4.2, function()
			if feedback.Parent then
				feedback:Destroy()
			end
		end)
	end)
	bump()
end

local function buildCabinPorchCluster(parent: Instance, origin: Vector3)
	local porch = WorldKit.model(parent, "InteractableCabinPorch")
	WorldKit.part(porch, "RockingChairBase", Vector3.new(1.8, 0.35, 1.6), CFrame.new(origin + Vector3.new(-2.2, 0.5, 0.5)), WOOD, Enum.Material.WoodPlanks)
	WorldKit.part(porch, "RockingChairBack", Vector3.new(1.8, 1.5, 0.25), CFrame.new(origin + Vector3.new(-2.2, 1.3, 1.15)), WOOD, Enum.Material.WoodPlanks)
	WorldKit.seat(porch, "RockingSeat", origin + Vector3.new(-2.2, 0.75, 0.4), origin + Vector3.new(-2.2, 0.75, -4), WOOD)
	bump()
	WorldKit.part(porch, "PorchSwingBeam", Vector3.new(4.2, 0.3, 0.3), CFrame.new(origin + Vector3.new(2.5, 3.2, -0.5)), WOOD_DARK, Enum.Material.Wood)
	WorldKit.part(porch, "PorchSwingSeatBoard", Vector3.new(3.4, 0.25, 1.4), CFrame.new(origin + Vector3.new(2.5, 1.0, -0.5)), WOOD, Enum.Material.WoodPlanks)
	WorldKit.seat(porch, "PorchSwingSeat", origin + Vector3.new(2.5, 1.2, -0.5), origin + Vector3.new(2.5, 1.2, -6), WOOD)
	bump()
	local mat = WorldKit.part(porch, "WelcomeMat", Vector3.new(2.4, 0.12, 1.4), CFrame.new(origin + Vector3.new(0, 0.2, 2.2)), Color3.fromRGB(90, 50, 40), Enum.Material.Fabric)
	WorldKit.inspect(
		mat,
		"Welcome mat",
		"Faded stitchwork: WIPE YOUR FEET. Underside pencil: 'Cabin Zero key still missing.'",
		0.35
	)
	bump()
	local lantern = WorldKit.part(porch, "PorchLantern", Vector3.new(0.7, 0.9, 0.7), CFrame.new(origin + Vector3.new(4.2, 2.4, 1.2)), Color3.fromRGB(222, 186, 120), Enum.Material.Glass)
	lantern.Transparency = 0.25
	WorldKit.part(porch, "PorchLanternPost", Vector3.new(0.3, 3.2, 0.3), CFrame.new(origin + Vector3.new(4.2, 1.6, 1.2)), WOOD_DARK, Enum.Material.Wood)
	local light = Instance.new("PointLight")
	light.Name = "PorchLanternLight"
	light.Color = Color3.fromRGB(255, 204, 138)
	light.Brightness = 1.6
	light.Range = 14
	light.Enabled = true
	light.Parent = lantern
	local prompt = WorldKit.prompt(lantern, "Toggle", "Porch lantern", 0.25)
	prompt.Triggered:Connect(function()
		light.Enabled = not light.Enabled
		local existing = lantern:FindFirstChild("LanternFeedback")
		if existing then
			existing:Destroy()
		end
		local feedback = Instance.new("BillboardGui")
		feedback.Name = "LanternFeedback"
		feedback.Size = UDim2.new(7, 0, 1.8, 0)
		feedback.StudsOffset = Vector3.new(0, 2.8, 0)
		feedback.AlwaysOnTop = true
		feedback.Enabled = true
		feedback.Parent = lantern
		local label = Instance.new("TextLabel")
		label.BackgroundColor3 = Color3.fromRGB(13, 17, 16)
		label.BackgroundTransparency = 0.08
		label.BorderSizePixel = 0
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamMedium
		label.Text = if light.Enabled then "Lantern clicks on — warm pool of light on the porch boards." else "Lantern clicks off. Shadows rush back under the swing."
		label.TextColor3 = Color3.fromRGB(244, 224, 176)
		label.TextSize = 15
		label.TextWrapped = true
		label.Parent = feedback
		task.delay(2.8, function()
			if feedback.Parent then
				feedback:Destroy()
			end
		end)
	end)
	bump()
end

local ENRICH_CAP = 80

local function hasProximityPrompt(part: BasePart): boolean
	return part:FindFirstChildOfClass("ProximityPrompt") ~= nil
end

local function shouldSkipEnrichPart(part: BasePart): boolean
	local name = part.Name
	if name == "EvidenceSocket" or name == "HumanoidRootPart" or name == "Terrain" then
		return true
	end
	if part:IsA("Terrain") then
		return true
	end
	return false
end

local function signFlavor(name: string): (string, string)
	if string.find(name, "Poster") then
		return "Poster", "Edges curled. Someone circled a face in pencil."
	elseif string.find(name, "Notice") then
		return "Notice", "Official stamp half-faded. Read twice."
	elseif string.find(name, "Map") then
		return "Map", "Trails marked in red. One path scratched out."
	end
	return "Sign", "Weathered lettering. Still points the way."
end

-- Pass over existing day/night geometry and wire sit/inspect on unnamed props.
local function enrichExistingProps(dayCamp: Folder, nightTown: Folder)
	local enriched = 0
	local seatIndex = 0

	local function enrichRoot(root: Instance)
		for _, desc in root:GetDescendants() do
			if enriched >= ENRICH_CAP then
				return
			end
			if not desc:IsA("BasePart") then
				continue
			end
			local part = desc :: BasePart
			if shouldSkipEnrichPart(part) or hasProximityPrompt(part) then
				continue
			end

			local name = part.Name
			local isSitNamed = string.find(name, "Bench")
				or string.find(name, "Seat")
				or string.find(name, "Chair")
			local isSignNamed = string.find(name, "Sign")
				or string.find(name, "Poster")
				or string.find(name, "Notice")
				or string.find(name, "Map")

			if isSitNamed then
				if part:IsA("Seat") then
					continue
				end
				local hasSeatChild = part:FindFirstChildWhichIsA("Seat") ~= nil
				local isLargeBench = string.find(name, "Bench") ~= nil
					and (part.Size.X >= 3 or part.Size.Z >= 3 or part.Size.Magnitude >= 4)
				seatIndex += 1
				local lookAt = part.Position + part.CFrame.LookVector * 4
				WorldKit.seat(
					part.Parent or root,
					string.format("EnrichSeat_%d", seatIndex),
					part.Position + Vector3.new(0, 0.35, 0),
					lookAt,
					WOOD
				)
				enriched += 1
				if enriched >= ENRICH_CAP then
					return
				end
				if isLargeBench and not hasSeatChild then
					WorldKit.inspect(
						part,
						"Bench",
						"Worn wood. Good place to rest and listen.",
						0.4
					)
					enriched += 1
				end
			elseif isSignNamed then
				local title, body = signFlavor(name)
				WorldKit.inspect(part, title, body, 0.35)
				enriched += 1
			end
		end
	end

	enrichRoot(dayCamp)
	if enriched < ENRICH_CAP then
		enrichRoot(nightTown)
	end
	print(string.format("[CAMP-Mystery] InteractableWorld: enriched %d existing props", enriched))
end

function InteractableWorld.Build(dayCamp: Folder, nightTown: Folder)
	builtCount = 0
	local day = WorldKit.model(dayCamp, "InteractableWorldDay")
	local night = WorldKit.model(nightTown, "InteractableWorldNight")

	-- Day camp density (around plaza / lodge / docks / trails)
	buildBulletin(
		day,
		CFrame.new(6, 5.5, 8),
		"Camp bulletin",
		"TODAY: Finish 3 camp chores. Dusk buddy-check. Night: search town, interview counselors, vote smart."
	)
	buildMailbox(day, CFrame.new(-18, 4.2, 14))
	buildRadio(day, CFrame.new(12, 4.0, -6), false)
	buildDinnerBell(day, CFrame.new(-4, 5.0, 22))
	buildWishJar(day, CFrame.new(20, 4.0, 16))
	buildPhotoCutout(day, CFrame.new(-28, 6.2, 30) * CFrame.Angles(0, math.rad(25), 0))
	buildTrailKiosk(day, CFrame.new(32, 5.2, 40) * CFrame.Angles(0, math.rad(-20), 0))
	buildBugSpray(day, CFrame.new(8, 4.4, 36))
	buildWaterCooler(day, CFrame.new(-10, 4.6, -12))
	buildSongbook(day, CFrame.new(2, 3.6, 2))
	buildTrophyCase(day, CFrame.new(-22, 5.0, -8) * CFrame.Angles(0, math.rad(90), 0))
	buildLostAndFound(day, CFrame.new(24, 3.8, -14))
	buildBinoculars(day, CFrame.new(0, 5.0, 55))
	buildPicnicWithSeats(day, CFrame.new(40, 4.2, 18))
	buildPlazaBench(day, CFrame.new(-14, 3.9, 28) * CFrame.Angles(0, math.rad(40), 0))
	buildPlazaBench(day, CFrame.new(16, 3.9, 24) * CFrame.Angles(0, math.rad(-30), 0))
	buildPlazaBench(day, CFrame.new(5, 3.9, 48) * CFrame.Angles(0, math.rad(10), 0))

	-- Extra camp flavor: flagpole, canoe rack, archery chalkboard, infirmary chart
	do
		local pole = WorldKit.part(day, "FlagPole", Vector3.new(0.35, 12, 0.35), CFrame.new(-35, 9, 5), METAL, Enum.Material.Metal)
		local flag = WorldKit.part(day, "CampFlag", Vector3.new(3.2, 1.8, 0.12), CFrame.new(-33.2, 13.5, 5), Color3.fromRGB(40, 90, 160), Enum.Material.Fabric)
		feedbackAction(flag, "Salute Flag", "Camp flag", "Colors snap in the breeze. Motto stitched on the hem: FINISH THE WORK BEFORE DARK.", 0.25)
		bump()
		local rack = WorldKit.part(day, "CanoeRack", Vector3.new(8, 2.2, 2.4), CFrame.new(88, 4.5, 42), WOOD, Enum.Material.Wood)
		WorldKit.inspect(rack, "Canoe rack", "Two canoes missing paddles. A tag reads: ALIBI PAIRS — SIGN THE LOG.", 0.4)
		bump()
		local chalk = WorldKit.part(day, "ArcheryChalkboard", Vector3.new(3.6, 2.4, 0.2), CFrame.new(55, 5.0, -40) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(40, 50, 40), Enum.Material.Slate)
		WorldKit.inspect(chalk, "Archery scores", "Top score blanked out. Fresh chalk: 'DON'T STAND IN THE OPEN AT NIGHT.'", 0.4)
		bump()
		local chart = WorldKit.part(day, "InfirmaryChart", Vector3.new(2.4, 3.0, 0.12), CFrame.new(-48, 5.2, -20), PAPER, Enum.Material.Cardboard)
		WorldKit.inspect(chart, "Infirmary chart", "Injury tiers listed. Sticky note: Medic cannot self-heal — stay near a buddy.", 0.45)
		bump()
		local fireRing = WorldKit.part(day, "StoryCircleLog", Vector3.new(5.5, 0.7, 1.2), CFrame.new(0, 3.6, 18), WOOD_DARK, Enum.Material.Wood)
		WorldKit.seat(day, "StorySeatA", Vector3.new(-2, 3.9, 16), Vector3.new(0, 3.9, 20), WOOD)
		WorldKit.seat(day, "StorySeatB", Vector3.new(2, 3.9, 16), Vector3.new(0, 3.9, 20), WOOD)
		WorldKit.inspect(fireRing, "Story circle", "Charred wood and marshmallow sticks. Someone whispered a monster name into the smoke.", 0.4)
		bump()
	end

	-- Lake / dock cluster (east waterfront)
	buildLakeDockCluster(day, Vector3.new(95, 4, 40))

	-- Cabin porch flavor (west cabins)
	buildCabinPorchCluster(day, Vector3.new(-40, 4, 50))

	-- Midway / Fairgrounds (day + night flavor — NE meadow)
	local midway = WorldKit.model(day, "InteractableMidway")
	buildRingToss(midway, CFrame.new(168, 4.5, 290) * CFrame.Angles(0, math.rad(180), 0))
	buildFortuneTeller(midway, CFrame.new(182, 4.8, 310))
	buildStrongman(midway, CFrame.new(198, 4.2, 285))
	buildFunhouseMirror(midway, CFrame.new(175, 5.8, 320) * CFrame.Angles(0, math.rad(-40), 0))
	buildCottonCandy(midway, CFrame.new(190, 4.4, 275))
	buildPlazaBench(midway, CFrame.new(160, 4.0, 300))
	buildPlazaBench(midway, CFrame.new(205, 4.0, 305) * CFrame.Angles(0, math.rad(90), 0))
	buildBalloonDart(midway, CFrame.new(185, 4.5, 298) * CFrame.Angles(0, math.rad(15), 0))
	buildMilkBottlePyramid(midway, CFrame.new(195, 4.2, 312))
	buildDuckPond(midway, CFrame.new(178, 4.0, 280))
	buildDunkTank(midway, CFrame.new(210, 4.5, 295) * CFrame.Angles(0, math.rad(-90), 0))
	buildPrizeWheel(midway, CFrame.new(172, 4.4, 305) * CFrame.Angles(0, math.rad(40), 0))

	-- Night town density
	buildNewspaperBox(night, CFrame.new(-40, 4.4, -120))
	buildNewspaperBox(night, CFrame.new(30, 4.4, -160))
	buildPayphone(night, CFrame.new(-60, 5.5, -140))
	buildPayphone(night, CFrame.new(55, 5.5, -180))
	buildVending(night, CFrame.new(-20, 5.2, -150))
	buildVending(night, CFrame.new(70, 5.2, -200))
	buildWantedPoster(night, CFrame.new(-90, 5.0, -130) * CFrame.Angles(0, math.rad(90), 0))
	buildWantedPoster(night, CFrame.new(10, 5.0, -210) * CFrame.Angles(0, math.rad(-15), 0))
	buildGravestone(night, CFrame.new(-120, 4.2, -100), "HERE LIES WHAT WE REFUSED TO NAME.")
	buildGravestone(night, CFrame.new(-115, 4.2, -108), "BELOVED CAMPER — RETURNED AT DUSK.")
	buildGravestone(night, CFrame.new(-125, 4.2, -112), "THE LIGHTS FAILED. SO DID WE.")
	buildMotelGuestbook(night, CFrame.new(85, 4.0, -175))
	buildDriveInSpeaker(night, CFrame.new(100, 4.8, -220))
	buildDriveInSpeaker(night, CFrame.new(110, 4.8, -230))
	buildGasPump(night, CFrame.new(-70, 4.9, -190))
	buildArcade(night, CFrame.new(45, 5.0, -145))
	buildManhole(night, CFrame.new(0, 3.1, -165))
	buildManhole(night, CFrame.new(-50, 3.1, -200))
	buildRadio(night, CFrame.new(-95, 4.0, -155), true)
	buildBulletin(
		night,
		CFrame.new(20, 5.5, -125) * CFrame.Angles(0, math.rad(180), 0),
		"Town notice",
		"EVACUATION ORDER — expired. Beneath: 'Evidence first. Accusations second.'"
	)
	buildPlazaBench(night, CFrame.new(-30, 3.9, -170))
	buildPlazaBench(night, CFrame.new(40, 3.9, -190) * CFrame.Angles(0, math.rad(70), 0))

	-- Extra night town: church pew hymnals, factory clipboard, junkyard hood
	do
		local hymnal = WorldKit.part(night, "ChurchHymnal", Vector3.new(1.2, 0.25, 0.9), CFrame.new(-100, 4.0, -95), Color3.fromRGB(90, 40, 40), Enum.Material.Leather)
		WorldKit.inspect(hymnal, "Hymnal", "A verse underlined: 'Walk while ye have the light.' Margin: 'GENERATOR = LIGHT.'", 0.45)
		bump()
		local clip = WorldKit.part(night, "FactoryClipboard", Vector3.new(1.0, 1.4, 0.15), CFrame.new(60, 4.5, -250), PAPER, Enum.Material.Cardboard)
		WorldKit.inspect(clip, "Factory clipboard", "Shift checklist incomplete. Last line: 'Seal east door — something scratched through.'", 0.4)
		bump()
		local hood = WorldKit.part(night, "JunkyardHood", Vector3.new(3.5, 0.4, 2.5), CFrame.new(95, 3.5, -260), RUST, Enum.Material.CorrodedMetal)
		WorldKit.hidingSpot(hood)
		WorldKit.inspect(hood, "Car hood", "Good cover. Oil smell. A camp token is wedged in the grille — maybe planted.", 0.4)
		bump()
		local meter = WorldKit.part(night, "ParkingMeter", Vector3.new(0.4, 2.8, 0.4), CFrame.new(-15, 4.5, -155), METAL, Enum.Material.Metal)
		feedbackAction(meter, "Check Meter", "Parking meter", "EXPIRED. Coin slot jammed with a folded note: 'Meet at the Midway.'", 0.3)
		bump()
		local hydrant = WorldKit.part(night, "FireHydrant", Vector3.new(1.2, 1.8, 1.2), CFrame.new(25, 4.0, -175), RED, Enum.Material.Metal)
		WorldKit.inspect(hydrant, "Fire hydrant", "Paint scraped by claws… or a pry bar. Fresh mud tracks lead toward the square.", 0.35)
		bump()
	end

	-- Backcountry / landmarks cluster
	do
		local rangerDesk = WorldKit.part(day, "RangerStationDesk", Vector3.new(2.8, 0.35, 1.6), CFrame.new(-84.5, 28.5, -62), WOOD_DARK, Enum.Material.Wood)
		WorldKit.part(day, "RangerDeskPaper", Vector3.new(1.4, 0.05, 1.0), CFrame.new(-84.5, 28.75, -62), PAPER, Enum.Material.Cardboard)
		WorldKit.inspect(
			rangerDesk,
			"Ranger station desk",
			"Duty log open to tonight: 'Buddy checks every hour. Cabin Zero stays sealed.' Ink still wet.",
			0.45
		)
		bump()

		local mineCart = WorldKit.part(day, "MineCartBody", Vector3.new(3.2, 1.4, 4.2), CFrame.new(104, 1.8, -40), RUST, Enum.Material.Metal)
		WorldKit.part(day, "MineCartWheelFL", Vector3.new(0.5, 0.5, 0.5), CFrame.new(102.6, 1.0, -41.4), METAL, Enum.Material.Metal)
		WorldKit.part(day, "MineCartWheelFR", Vector3.new(0.5, 0.5, 0.5), CFrame.new(105.4, 1.0, -41.4), METAL, Enum.Material.Metal)
		WorldKit.part(day, "MineCartWheelBL", Vector3.new(0.5, 0.5, 0.5), CFrame.new(102.6, 1.0, -38.6), METAL, Enum.Material.Metal)
		WorldKit.part(day, "MineCartWheelBR", Vector3.new(0.5, 0.5, 0.5), CFrame.new(105.4, 1.0, -38.6), METAL, Enum.Material.Metal)
		WorldKit.hidingSpot(mineCart)
		WorldKit.inspect(
			mineCart,
			"Mine cart",
			"Ore dust and a half-torn camp roster. Good place to duck out of sight — if you fit.",
			0.45
		)
		bump()

		WorldKit.seat(day, "ChapelPewSeatA", Vector3.new(-32.4, 2.0, 48.4), Vector3.new(-30, 2.0, 55), WOOD_DARK)
		WorldKit.seat(day, "ChapelPewSeatB", Vector3.new(-27.6, 2.0, 48.4), Vector3.new(-30, 2.0, 55), WOOD_DARK)
		bump()
		bump()
		local candle = WorldKit.part(day, "ChapelCandle", Vector3.new(0.35, 0.9, 0.35), CFrame.new(-30, 3.2, 55.8), CREAM, Enum.Material.SmoothPlastic)
		local flame = WorldKit.part(day, "ChapelCandleFlame", Vector3.new(0.25, 0.35, 0.25), CFrame.new(-30, 3.85, 55.8), Color3.fromRGB(255, 170, 80), Enum.Material.Neon)
		flame.CanCollide = false
		WorldKit.inspect(
			candle,
			"Chapel candle",
			"Wax pooled around a brass holder. Someone whispered a name into the flame and left.",
			0.4
		)
		bump()

		WorldKit.part(day, "LookoutTelescopeStand", Vector3.new(0.45, 2.4, 0.45), CFrame.new(5.4, 35.2, 112.5), METAL, Enum.Material.Metal)
		local telescope = WorldKit.part(day, "LookoutTelescope", Vector3.new(2.2, 0.55, 0.55), CFrame.new(5.4, 36.6, 112.5) * CFrame.Angles(0, math.rad(40), math.rad(12)), Color3.fromRGB(90, 74, 48), Enum.Material.Metal)
		feedbackAction(
			telescope,
			"Look",
			"Lookout telescope",
			"Valley haze. Midway neon to the northeast… and a dark smear near Cabin Zero that might be smoke.",
			0.4
		)
		bump()

		buildRadio(night, CFrame.new(125.5, 3.2, -393), true)

		local cabinDoor = WorldKit.part(day, "CabinZeroDoor", Vector3.new(2.4, 4.2, 0.28), CFrame.new(-63, 4.8, 76.5), Color3.fromRGB(48, 44, 40), Enum.Material.WoodPlanks)
		WorldKit.part(day, "CabinZeroDoorKnob", Vector3.new(0.2, 0.2, 0.25), CFrame.new(-62.1, 4.5, 76.35), METAL, Enum.Material.Metal)
		WorldKit.inspect(
			cabinDoor,
			"Cabin Zero door",
			"Do not enter alone. Charred boards nailed shut — a fresh handprint in the soot.",
			0.5
		)
		bump()

		local cairnBase = WorldKit.part(day, "TrailCairnBase", Vector3.new(1.5, 0.55, 1.4), CFrame.new(74, 3.0, -22), Color3.fromRGB(120, 118, 110), Enum.Material.Slate)
		WorldKit.part(day, "TrailCairnMid", Vector3.new(1.1, 0.45, 1.0), CFrame.new(74, 3.55, -22) * CFrame.Angles(0, 0.7, 0), Color3.fromRGB(110, 108, 102), Enum.Material.Slate)
		WorldKit.part(day, "TrailCairnTop", Vector3.new(0.7, 0.35, 0.65), CFrame.new(74, 4.0, -22) * CFrame.Angles(0, 1.4, 0), Color3.fromRGB(130, 128, 120), Enum.Material.Slate)
		WorldKit.inspect(
			cairnBase,
			"Trail cairn",
			"Stacked trail stones. Top rock scratched with an arrow toward the lookout — and a second mark scratched out.",
			0.4
		)
		bump()
	end

	enrichExistingProps(dayCamp, nightTown)
	print(string.format("[CAMP-Mystery] InteractableWorld: %d interaction sites built", builtCount))
end

return InteractableWorld
