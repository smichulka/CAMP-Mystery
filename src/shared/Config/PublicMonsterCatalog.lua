--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonsterTypes = require(Shared:WaitForChild("Types"):WaitForChild("MonsterTypes"))

type MonsterId = MonsterTypes.MonsterId
type PublicMonsterDefinition = MonsterTypes.PublicMonsterDefinition

local catalog: { [MonsterId]: PublicMonsterDefinition } = {
	BabyAlien = {
		id = "BabyAlien",
		displayName = "Baby Alien",
		description = "A small pink fleshy crawler with oversized dark eyes. Built for low routes, sudden leaps, and close ambushes.",
		movement = {
			style = "Low crawling ambush",
			speed = "Fast bursts",
			special = "Uses narrow routes and a short leap",
		},
		evidencePresentation = {
			"Tiny tracks",
			"Acidic residue",
			"Laser motion",
		},
		counterplay = {
			summary = "Keep it in open, well-lit spaces and interrupt its approach before it reaches leaping range.",
			recommendedEquipment = { "Flashlight", "LaserProjector" },
		},
		murdererNote = "You are fast at close range. Keep leaping range short and don't let prey isolate you in bright areas.",
	},
	Screamer = {
		id = "Screamer",
		displayName = "Screamer",
		description = "A bone-pale gaunt humanoid with a hollow toothy maw and impossibly long claws. Its scream disrupts nearby investigation equipment.",
		movement = {
			style = "Direct pursuit",
			speed = "Moderate",
			special = "Stops briefly to release a disabling scream",
		},
		evidencePresentation = {
			"Corrupted audio",
			"EMF spike",
			"Device interference",
		},
		counterplay = {
			summary = "Break range or line of sight during the scream, then use its recovery window to escape.",
			recommendedEquipment = { "AudioRecorder", "EMFReader" },
		},
		murdererNote = "Your scream is range-dependent. Break line of sight early to buy recovery time and prevent campers from escaping.",
	},
	Wendigo = {
		id = "Wendigo",
		displayName = "Wendigo",
		description = "A towering figure crowned with a skeletal deer skull and branching antlers, its body wrapped in roots and earth. Isolates campers with mimicry before a devastating charge.",
		movement = {
			style = "Stalking and charging",
			speed = "Fast in a straight line",
			special = "Tracks through forest routes and mimics voices",
		},
		evidencePresentation = {
			"Antler scrape",
			"Mimic recording",
			"Freezing trace",
		},
		counterplay = {
			summary = "Stay together and use campfire or flare light to deny its strongest approach routes.",
			recommendedEquipment = { "AudioRecorder", "FlareLantern" },
		},
		murdererNote = "Group light sources are your threat. Isolate targets away from campfire zones and flare coverage.",
	},
	ShadowMonster = {
		id = "ShadowMonster",
		displayName = "Shadow Monster",
		description = "A near-black smoky silhouette, barely distinguishable from the dark. Takes many forms — looming watcher, tall shadow, quick mover. Gains speed between shadowed positions.",
		movement = {
			style = "Shadow-node traversal",
			speed = "Variable",
			special = "Moves rapidly between authored dark locations",
		},
		evidencePresentation = {
			"Photo silhouette",
			"Light drain",
			"Black residue",
		},
		counterplay = {
			summary = "Sustain direct light to make it solid, visible, and slower.",
			recommendedEquipment = { "Flashlight", "Camera" },
		},
		murdererNote = "Avoid sustained direct light. Move through unlit corridors and strike before light establishes.",
	},
	Chupacabra = {
		id = "Chupacabra",
		displayName = "Chupacabra",
		description = "A grey-brown spined quadruped with sharp ridges along its back and hollow dark eyes. Tracks blood, pounces over distance, and latches onto injured campers.",
		movement = {
			style = "Low stalking and pouncing",
			speed = "Very fast",
			special = "Long-distance pounce and injured-player tracking",
		},
		evidencePresentation = {
			"Blood trail",
			"Claw marks",
			"UV-reactive residue",
		},
		counterplay = {
			summary = "A UV or direct flashlight burst forces it to release a latched camper.",
			recommendedEquipment = { "UVLight", "Flashlight", "MedicalKit" },
		},
		murdererNote = "A UV or flashlight burst can release your latch. Time strikes when victims are isolated and unequipped.",
	},
	Dullahan = {
		id = "Dullahan",
		displayName = "Dullahan",
		description = "A near-black headless figure draped in a long flowing cloak, its neck rim glowing faintly with spectral teal energy. Accelerates relentlessly as long as it has sight of its target.",
		movement = {
			style = "Relentless line-of-sight pursuit",
			speed = "Slow start, extreme finish",
			special = "Acceleration builds while a target remains visible",
		},
		evidencePresentation = {
			"Freezing temperature",
			"Headless photograph",
			"Laser silhouette",
		},
		counterplay = {
			summary = "Break line of sight before it reaches full speed.",
			recommendedEquipment = { "Camera", "LaserProjector", "Thermometer" },
		},
		murdererNote = "Build pursuit speed early. Break away from corners that interrupt your line — speed is your advantage.",
	},
	Entity = {
		id = "Entity",
		displayName = "Entity",
		description = "A deep-blue oceanic apparition with drifting anchor orbs and bioluminescent streams of light — part ancient, part unknowable. Teleports between anchors and distorts victim perception.",
		movement = {
			style = "Anchor teleportation",
			speed = "Instant repositioning",
			special = "Leaves a brief laser-visible arrival silhouette",
		},
		evidencePresentation = {
			"Spirit Box response",
			"Handprint",
			"Laser silhouette",
		},
		counterplay = {
			summary = "Watch for its arrival silhouette and move away from nearby teleport anchors.",
			recommendedEquipment = { "SpiritBox", "UVLight", "LaserProjector" },
		},
		murdererNote = "Your arrival silhouette is visible. Vary anchor selection and approach from unexpected angles.",
	},
	Banshee = {
		id = "Banshee",
		displayName = "Banshee",
		description = "A silver-white spectral woman, robes and hair streaming in an otherworldly wind, mouth open in a silent wail. Her cry attacks the senses and marks vulnerable campers for pursuit.",
		movement = {
			style = "Floating pursuit",
			speed = "Moderate",
			special = "Tracks injured or marked campers",
		},
		evidencePresentation = {
			"Recorded wail",
			"Reflection apparition",
			"Death mark",
		},
		counterplay = {
			summary = "Interrupt the wail or escape its effective radius before disorientation builds.",
			recommendedEquipment = { "AudioRecorder", "Camera", "MedicalKit" },
		},
		murdererNote = "Give campers time to enter wail radius before full attack. A quick escape means no disorientation buildup.",
	},
}

for _, definition in catalog do
	table.freeze(definition.movement)
	table.freeze(definition.evidencePresentation)
	table.freeze(definition.counterplay.recommendedEquipment)
	table.freeze(definition.counterplay)
	table.freeze(definition)
end

return table.freeze(catalog)
