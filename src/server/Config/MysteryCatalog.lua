--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MysteryTypes = require(
	ReplicatedStorage.Shared.Types:WaitForChild("MysteryTypes")
)

type MonsterId = MysteryTypes.MonsterId
type MysteryClueTemplate = MysteryTypes.MysteryClueTemplate
type MonsterClueTemplate = MysteryTypes.MonsterClueTemplate
type WitnessAccountTemplate = MysteryTypes.WitnessAccountTemplate

export type MysteryCatalogDefinition = {
	titles: { string },
	culpritClues: { MysteryClueTemplate },
	plantedClues: { MysteryClueTemplate },
	monsterClues: { [MonsterId]: { MonsterClueTemplate } },
	truthfulWitnessAccounts: { WitnessAccountTemplate },
	mistakenWitnessAccounts: { WitnessAccountTemplate },
	monsterWitnessAccounts: { WitnessAccountTemplate },
}

local catalog: MysteryCatalogDefinition = {
	titles = {
		"The Bell After Midnight",
		"Footsteps Beyond the Fire",
		"The Empty Counselor Cabin",
		"Fog Over Black Pine",
		"The Light Beneath the Water Tower",
		"Last Call at the General Store",
	},
	culpritClues = {
		{
			id = "culprit-boot-edge",
			channel = "Culprit",
			title = "Damaged Boot Edge",
			publicDescription = "A partial heel edge matches a small group of camp-issued and work boots. The print is incomplete and cannot identify one wearer.",
			locationIds = {
				"main-road-clue-a",
				"square-gas-station-clue",
				"industrial-machine-clue",
			},
		},
		{
			id = "culprit-uniform-fiber",
			channel = "Culprit",
			title = "Weathered Uniform Fiber",
			publicDescription = "A rain-darkened fiber has a weave used by several camp jackets. Its torn edge suggests recent movement through brush.",
			locationIds = {
				"residential-bedroom-clue",
				"outskirts-company-house-clue",
				"water-tower-base-clue",
			},
		},
		{
			id = "culprit-key-residue",
			channel = "Culprit",
			title = "Brass Key Residue",
			publicDescription = "Fine brass dust came from a commonly issued camp key ring. Several people had access to the same key cabinet.",
			locationIds = {
				"police-evidence-room-clue",
				"square-gas-station-clue",
				"residential-bedroom-clue",
			},
		},
		{
			id = "culprit-lantern-soot",
			channel = "Culprit",
			title = "Lantern Soot",
			publicDescription = "A fresh soot smear is consistent with the camp lanterns checked out before dusk. The mark narrows access, not identity.",
			locationIds = {
				"water-tower-base-clue",
				"main-road-clue-a",
				"outskirts-company-house-clue",
			},
		},
		{
			id = "culprit-route-scrape",
			channel = "Culprit",
			title = "Fresh Route Scrape",
			publicDescription = "A scrape at shoulder height suggests someone used a staff-only shortcut. More than one person knew the route.",
			locationIds = {
				"industrial-machine-clue",
				"police-evidence-room-clue",
				"main-road-clue-a",
			},
		},
		{
			id = "culprit-clock-discrepancy",
			channel = "Culprit",
			title = "Clock-In Discrepancy",
			publicDescription = "A damaged duty card leaves a short unexplained window for several people. No single name remains legible.",
			locationIds = {
				"police-evidence-room-clue",
				"residential-bedroom-clue",
				"square-gas-station-clue",
			},
		},
	},
	plantedClues = {
		{
			id = "planted-name-tag",
			channel = "Culprit",
			title = "Scuffed Name-Tag Clasp",
			publicDescription = "A broken clasp resembles camp uniform hardware, but it is unusually clean for where it was found.",
			locationIds = {
				"outskirts-company-house-clue",
				"industrial-machine-clue",
			},
		},
		{
			id = "planted-duty-note",
			channel = "Culprit",
			title = "Smudged Duty Note",
			publicDescription = "A torn duty note points toward a suspicious route. The ink and paper are common camp supplies.",
			locationIds = {
				"residential-bedroom-clue",
				"police-evidence-room-clue",
			},
		},
		{
			id = "planted-camp-token",
			channel = "Culprit",
			title = "Scratched Camp Token",
			publicDescription = "A camp token carries fresh scratches and may have been dropped, moved, or deliberately planted.",
			locationIds = {
				"square-gas-station-clue",
				"water-tower-base-clue",
			},
		},
		{
			id = "planted-glove-thread",
			channel = "Culprit",
			title = "Loose Glove Thread",
			publicDescription = "A bright thread resembles a common work glove, though it sits conspicuously above the mud.",
			locationIds = {
				"main-road-clue-a",
				"industrial-machine-clue",
			},
		},
	},
	monsterClues = {
		BabyAlien = {
			{
				id = "baby-alien-low-tracks",
				channel = "Monster",
				title = "Low Three-Toed Tracks",
				publicDescription = "Tiny tracks cross beneath a collapsed barrier where a human-sized pursuer could not fit.",
				locationIds = { "residential-bedroom-clue", "main-road-clue-a", "outskirts-company-house-clue" },
				monsterCandidates = { "BabyAlien", "Chupacabra", "ShadowMonster" },
			},
			{
				id = "baby-alien-acid",
				channel = "Monster",
				title = "Corrosive Droplets",
				publicDescription = "Small droplets etched shallow pits into metal before quickly becoming inert.",
				locationIds = { "industrial-machine-clue", "police-evidence-room-clue" },
				monsterCandidates = { "BabyAlien", "Entity" },
			},
			{
				id = "baby-alien-laser",
				channel = "Monster",
				title = "Floor-Level Laser Breaks",
				publicDescription = "A laser grid recorded rapid movement less than two feet above the floor.",
				locationIds = { "square-gas-station-clue", "water-tower-base-clue" },
				monsterCandidates = { "BabyAlien", "Chupacabra" },
			},
		},
		Screamer = {
			{
				id = "screamer-audio",
				channel = "Monster",
				title = "Clipped Directional Audio",
				publicDescription = "The recorder clipped around a narrow directional sound powerful enough to overload its input.",
				locationIds = { "main-road-clue-a", "police-evidence-room-clue" },
				monsterCandidates = { "Screamer", "Banshee", "Wendigo" },
			},
			{
				id = "screamer-electronics",
				channel = "Monster",
				title = "Synchronized Device Failure",
				publicDescription = "Several powered devices failed in a line, then recovered seconds later.",
				locationIds = { "industrial-machine-clue", "square-gas-station-clue" },
				monsterCandidates = { "Screamer", "ShadowMonster", "Entity" },
			},
			{
				id = "screamer-recovery",
				channel = "Monster",
				title = "Abrupt Silence Window",
				publicDescription = "The audio trace shows a loud burst followed by a distinct recovery pause.",
				locationIds = { "water-tower-base-clue", "outskirts-company-house-clue" },
				monsterCandidates = { "Screamer", "Banshee" },
			},
		},
		Wendigo = {
			{
				id = "wendigo-antler",
				channel = "Monster",
				title = "High Bark Gouges",
				publicDescription = "Paired gouges sit too high and too far apart to be ordinary tool marks.",
				locationIds = { "outskirts-company-house-clue", "main-road-clue-a" },
				monsterCandidates = { "Wendigo", "Dullahan" },
			},
			{
				id = "wendigo-mimic",
				channel = "Monster",
				title = "Impossible Voice Overlap",
				publicDescription = "A familiar voice appears on the recording while its owner was documented elsewhere.",
				locationIds = { "residential-bedroom-clue", "police-evidence-room-clue" },
				monsterCandidates = { "Wendigo", "Entity", "Banshee" },
			},
			{
				id = "wendigo-scent-path",
				channel = "Monster",
				title = "Unbroken Pursuit Path",
				publicDescription = "Tracks follow an injured camper around blind corners without any search pattern.",
				locationIds = { "water-tower-base-clue", "industrial-machine-clue" },
				monsterCandidates = { "Wendigo", "Chupacabra" },
			},
		},
		ShadowMonster = {
			{
				id = "shadow-light-drain",
				channel = "Monster",
				title = "Localized Light Drain",
				publicDescription = "Bulbs dimmed in sequence despite stable power at the generator.",
				locationIds = { "square-gas-station-clue", "industrial-machine-clue" },
				monsterCandidates = { "ShadowMonster", "Screamer", "Entity" },
			},
			{
				id = "shadow-photo",
				channel = "Monster",
				title = "Detached Silhouette",
				publicDescription = "A camera caught a silhouette that does not align with any nearby body or light source.",
				locationIds = { "residential-bedroom-clue", "police-evidence-room-clue" },
				monsterCandidates = { "ShadowMonster", "Entity" },
			},
			{
				id = "shadow-residue",
				channel = "Monster",
				title = "Cold Black Residue",
				publicDescription = "Powdery residue appears only inside the darkest section of the room.",
				locationIds = { "outskirts-company-house-clue", "water-tower-base-clue" },
				monsterCandidates = { "ShadowMonster", "Dullahan" },
			},
		},
		Chupacabra = {
			{
				id = "chupacabra-blood",
				channel = "Monster",
				title = "Blood-Oriented Trail",
				publicDescription = "The pursuit route changes abruptly to follow the freshest blood instead of the nearest movement.",
				locationIds = { "main-road-clue-a", "residential-bedroom-clue" },
				monsterCandidates = { "Chupacabra", "Wendigo", "Banshee" },
			},
			{
				id = "chupacabra-claws",
				channel = "Monster",
				title = "Four-Part Claw Furrow",
				publicDescription = "A low wall holds four deep furrows and signs of a long horizontal leap.",
				locationIds = { "industrial-machine-clue", "outskirts-company-house-clue" },
				monsterCandidates = { "Chupacabra", "BabyAlien" },
			},
			{
				id = "chupacabra-uv",
				channel = "Monster",
				title = "UV-Reactive Saliva",
				publicDescription = "A clear residue fluoresces strongly under ultraviolet light near the attack path.",
				locationIds = { "water-tower-base-clue", "police-evidence-room-clue" },
				monsterCandidates = { "Chupacabra", "Entity" },
			},
		},
		Dullahan = {
			{
				id = "dullahan-frost",
				channel = "Monster",
				title = "Moving Frost Line",
				publicDescription = "Frost formed in a straight pursuing line while nearby surfaces stayed warm.",
				locationIds = { "main-road-clue-a", "water-tower-base-clue" },
				monsterCandidates = { "Dullahan", "Wendigo", "Entity" },
			},
			{
				id = "dullahan-photo",
				channel = "Monster",
				title = "Headless Pursuer Photograph",
				publicDescription = "A blurred pursuer has clear shoulders but no visible head above them.",
				locationIds = { "police-evidence-room-clue", "square-gas-station-clue" },
				monsterCandidates = { "Dullahan", "ShadowMonster" },
			},
			{
				id = "dullahan-sightline",
				channel = "Monster",
				title = "Accelerating Sightline Tracks",
				publicDescription = "Stride length increased only while the path remained in direct view of the victim.",
				locationIds = { "industrial-machine-clue", "outskirts-company-house-clue" },
				monsterCandidates = { "Dullahan", "BabyAlien" },
			},
		},
		Entity = {
			{
				id = "entity-anchor",
				channel = "Monster",
				title = "Repeated Anchor Distortion",
				publicDescription = "Three fixed points show the same distortion with no connecting tracks between them.",
				locationIds = { "police-evidence-room-clue", "industrial-machine-clue" },
				monsterCandidates = { "Entity", "ShadowMonster", "BabyAlien" },
			},
			{
				id = "entity-handprint",
				channel = "Monster",
				title = "Inside-Surface Handprint",
				publicDescription = "A handprint appears on the sealed side of an undamaged pane.",
				locationIds = { "residential-bedroom-clue", "square-gas-station-clue" },
				monsterCandidates = { "Entity", "Banshee" },
			},
			{
				id = "entity-spirit-response",
				channel = "Monster",
				title = "Structured Spirit Response",
				publicDescription = "A Spirit Box answered a question from two locations within the same second.",
				locationIds = { "outskirts-company-house-clue", "water-tower-base-clue" },
				monsterCandidates = { "Entity", "Wendigo" },
			},
		},
		Banshee = {
			{
				id = "banshee-wail",
				channel = "Monster",
				title = "Layered Wail Recording",
				publicDescription = "The recording holds overlapping vocal bands from one moving source.",
				locationIds = { "main-road-clue-a", "square-gas-station-clue" },
				monsterCandidates = { "Banshee", "Screamer", "Wendigo" },
			},
			{
				id = "banshee-fear-radius",
				channel = "Monster",
				title = "Circular Panic Pattern",
				publicDescription = "Witnesses reported the same sudden fear inside a clear radius around the attack.",
				locationIds = { "water-tower-base-clue", "residential-bedroom-clue" },
				monsterCandidates = { "Banshee", "Dullahan" },
			},
			{
				id = "banshee-injury-focus",
				channel = "Monster",
				title = "Injured-Target Turn",
				publicDescription = "The pursuer abandoned a closer target immediately after an injured camper cried out.",
				locationIds = { "industrial-machine-clue", "outskirts-company-house-clue" },
				monsterCandidates = { "Banshee", "Chupacabra" },
			},
		},
	},
	truthfulWitnessAccounts = {
		{
			id = "witness-gravel-route",
			channel = "Culprit",
			statement = "I heard measured footsteps on the gravel service route after lights-out. I could not see a face, and more than one person uses that route.",
			locationId = "main-road-witness",
		},
		{
			id = "witness-lantern-window",
			channel = "Culprit",
			statement = "A covered lantern crossed the lodge window during the missing duty window. The coat looked like standard camp gear.",
			locationId = "square-store-witness",
		},
		{
			id = "witness-key-cabinet",
			channel = "Culprit",
			statement = "The staff key cabinet clicked shut shortly before the alarm. I was too far away to identify who closed it.",
			locationId = "police-desk-witness",
		},
		{
			id = "witness-shortcut-gate",
			channel = "Culprit",
			statement = "The shortcut gate moved once during the quiet period. Only people who knew the camp well would use it in the dark.",
			locationId = "water-tower-witness",
		},
	},
	mistakenWitnessAccounts = {
		{
			id = "witness-wrong-color",
			channel = "Culprit",
			statement = "I thought the coat was red, but the emergency light changed every color on that path. I cannot be certain.",
			locationId = "square-store-witness",
		},
		{
			id = "witness-clock-disagreement",
			channel = "Culprit",
			statement = "The steps came before the bell—or just after it. My watch had stopped, so my timing conflicts with the duty log.",
			locationId = "outskirts-lost-witness",
		},
		{
			id = "witness-second-shadow",
			channel = "Culprit",
			statement = "I saw two shadows near the road, but one may have belonged to the swinging sign.",
			locationId = "main-road-witness",
		},
	},
	monsterWitnessAccounts = {
		{
			id = "witness-monster-movement",
			channel = "Monster",
			statement = "It moved in a way no person could, but the fog hid its shape. The physical clues will be more reliable than my guess.",
			locationId = "main-road-witness",
		},
		{
			id = "witness-monster-sound",
			channel = "Monster",
			statement = "I heard the attack clearly, then every ordinary forest sound stopped. I recorded what I could without naming the creature.",
			locationId = "water-tower-witness",
		},
	},
}

local function freezeClueTemplate(template: MysteryClueTemplate)
	table.freeze(template.locationIds)
	table.freeze(template)
end

for _, template in catalog.culpritClues do
	freezeClueTemplate(template)
end
table.freeze(catalog.culpritClues)

for _, template in catalog.plantedClues do
	freezeClueTemplate(template)
end
table.freeze(catalog.plantedClues)

for _, templates in catalog.monsterClues do
	for _, template in templates do
		table.freeze(template.locationIds)
		table.freeze(template.monsterCandidates)
		table.freeze(template)
	end
	table.freeze(templates)
end
table.freeze(catalog.monsterClues)

for _, collection in {
	catalog.truthfulWitnessAccounts,
	catalog.mistakenWitnessAccounts,
	catalog.monsterWitnessAccounts,
} do
	for _, template in collection do
		table.freeze(template)
	end
	table.freeze(collection)
end

table.freeze(catalog.titles)
return table.freeze(catalog)
