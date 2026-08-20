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

	-- Midway / Fairgrounds (day + night flavor — NE meadow)
	local midway = WorldKit.model(day, "InteractableMidway")
	buildRingToss(midway, CFrame.new(168, 4.5, 290) * CFrame.Angles(0, math.rad(180), 0))
	buildFortuneTeller(midway, CFrame.new(182, 4.8, 310))
	buildStrongman(midway, CFrame.new(198, 4.2, 285))
	buildFunhouseMirror(midway, CFrame.new(175, 5.8, 320) * CFrame.Angles(0, math.rad(-40), 0))
	buildCottonCandy(midway, CFrame.new(190, 4.4, 275))
	buildPlazaBench(midway, CFrame.new(160, 4.0, 300))
	buildPlazaBench(midway, CFrame.new(205, 4.0, 305) * CFrame.Angles(0, math.rad(90), 0))

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

	print(string.format("[CAMP-Mystery] InteractableWorld: %d interaction sites built", builtCount))
end

return InteractableWorld
