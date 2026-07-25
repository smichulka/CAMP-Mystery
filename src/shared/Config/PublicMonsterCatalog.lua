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
		description = "A small extraterrestrial hunter built for low routes, sudden leaps, and close ambushes.",
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
	},
	Screamer = {
		id = "Screamer",
		displayName = "Screamer",
		description = "A sonic attacker whose scream disrupts nearby investigation equipment.",
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
	},
	Wendigo = {
		id = "Wendigo",
		displayName = "Wendigo",
		description = "A forest hunter that isolates campers with mimicry before committing to a charge.",
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
	},
	ShadowMonster = {
		id = "ShadowMonster",
		displayName = "Shadow Monster",
		description = "A smoky silhouette that gains mobility in darkness and travels between shadowed positions.",
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
	},
	Chupacabra = {
		id = "Chupacabra",
		displayName = "Chupacabra",
		description = "A skeletal ambush predator that tracks blood, pounces over distance, and latches onto injured campers.",
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
	},
	Dullahan = {
		id = "Dullahan",
		displayName = "Dullahan",
		description = "A headless pursuer that accelerates for as long as it maintains sight of its target.",
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
	},
	Entity = {
		id = "Entity",
		displayName = "Entity",
		description = "A floating supernatural presence that teleports between nearby anchors and distorts perception.",
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
	},
	Banshee = {
		id = "Banshee",
		displayName = "Banshee",
		description = "A floating apparition whose mournful wail attacks the senses and marks vulnerable campers.",
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
