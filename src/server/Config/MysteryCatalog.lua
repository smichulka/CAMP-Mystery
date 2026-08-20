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
		"Ashes on the Aurora Shore",
		"The Sawmill Whistle",
		"What the Cornfield Kept",
		"No One at the Lookout",
		"The Boxcar Ledger",
		"Silence at the Ranger Station",
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
				"derailed-boxcar",
				"cornfield-scarecrow",
				"sawmill-blade",
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
				"archery-shed",
				"greenhouse-potting-table",
				"cabin-zero-chimney",
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
				"ranger-station-desk",
				"quarters-footlocker",
				"infirmary-logbook",
				"frontier-watch-cache",
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
				"aurora-fire-ring",
				"lookout-cab",
				"mines-ore-cart",
				"frontier-watch-cache",
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
				"water-tower-catwalk",
				"sawmill-blade",
				"drive-in-projector",
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
				"ranger-station-desk",
				"radio-shack-console",
				"lookout-cab",
				"logging-camp-ledger",
			},
		},
		{
			id = "culprit-ash-streak",
			channel = "Culprit",
			title = "Cold Ash Streak",
			publicDescription = "A gray smear matches the camp's fire-duty ash cans. Several campers hauled ash before nightfall, so the streak narrows the roster only a little.",
			locationIds = {
				"aurora-fire-ring",
				"town-square-fountain",
				"cabin-zero-chimney",
				"midway-prize-counter",
			},
		},
		{
			id = "culprit-fletching-nick",
			channel = "Culprit",
			title = "Torn Fletching Vane",
			publicDescription = "A torn plastic vane comes from the archery range's practice arrows. Range hours list more than one certified camper for the day.",
			locationIds = {
				"archery-shed",
				"lookout-cab",
				"derailed-boxcar",
			},
		},
		{
			id = "culprit-resin-smear",
			channel = "Culprit",
			title = "Fresh Pine Resin Smear",
			publicDescription = "Sticky resin was tracked from fresh-cut lumber. The sawmill and the greenhouse both handled cut pine today, and neither logs visitors.",
			locationIds = {
				"sawmill-blade",
				"greenhouse-potting-table",
				"waterfall-cave",
				"logging-camp-ledger",
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
				"derailed-boxcar",
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
				"quarters-footlocker",
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
				"town-square-fountain",
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
				"greenhouse-potting-table",
			},
		},
		{
			id = "planted-medical-wrap",
			channel = "Culprit",
			title = "Unused Medical Wrap",
			publicDescription = "A pristine bandage roll from infirmary stock sits far from any treated injury — carried there, or placed there.",
			locationIds = {
				"infirmary-logbook",
				"crypt-empty-niche",
			},
		},
		{
			id = "planted-midway-stub",
			channel = "Culprit",
			title = "Torn Midway Stub",
			publicDescription = "A half-torn Fairgrounds ticket stub was left on a prize shelf with no matching wristband trail. It looks placed for someone to find — the Midnight Circus chase is opt-in theatre, not a lethal weapon.",
			locationIds = {
				"midway-prize-counter",
				"circus-ticket-booth",
				"aurora-fire-ring",
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
				locationIds = { "residential-bedroom-clue", "main-road-clue-a", "outskirts-company-house-clue", "cornfield-scarecrow" },
				monsterCandidates = { "BabyAlien", "Chupacabra", "ShadowMonster" },
			},
			{
				id = "baby-alien-acid",
				channel = "Monster",
				title = "Corrosive Droplets",
				publicDescription = "Small droplets etched shallow pits into metal before quickly becoming inert.",
				locationIds = { "industrial-machine-clue", "police-evidence-room-clue", "mines-ore-cart" },
				monsterCandidates = { "BabyAlien", "Entity" },
			},
			{
				id = "baby-alien-laser",
				channel = "Monster",
				title = "Floor-Level Laser Breaks",
				publicDescription = "A laser grid recorded rapid movement less than two feet above the floor.",
				locationIds = { "square-gas-station-clue", "water-tower-base-clue", "drive-in-projector" },
				monsterCandidates = { "BabyAlien", "Chupacabra" },
			},
		},
		Screamer = {
			{
				id = "screamer-audio",
				channel = "Monster",
				title = "Clipped Directional Audio",
				publicDescription = "The recorder clipped around a narrow directional sound powerful enough to overload its input.",
				locationIds = { "main-road-clue-a", "police-evidence-room-clue", "radio-shack-console" },
				monsterCandidates = { "Screamer", "Banshee", "Wendigo" },
			},
			{
				id = "screamer-electronics",
				channel = "Monster",
				title = "Synchronized Device Failure",
				publicDescription = "Several powered devices failed in a line, then recovered seconds later.",
				locationIds = { "industrial-machine-clue", "square-gas-station-clue", "drive-in-projector" },
				monsterCandidates = { "Screamer", "ShadowMonster", "Entity" },
			},
			{
				id = "screamer-recovery",
				channel = "Monster",
				title = "Abrupt Silence Window",
				publicDescription = "The audio trace shows a loud burst followed by a distinct recovery pause.",
				locationIds = { "water-tower-base-clue", "outskirts-company-house-clue", "waterfall-cave" },
				monsterCandidates = { "Screamer", "Banshee" },
			},
		},
		Wendigo = {
			{
				id = "wendigo-antler",
				channel = "Monster",
				title = "High Bark Gouges",
				publicDescription = "Paired gouges sit too high and too far apart to be ordinary tool marks.",
				locationIds = { "outskirts-company-house-clue", "main-road-clue-a", "graveyard-open-grave" },
				monsterCandidates = { "Wendigo", "Dullahan" },
			},
			{
				id = "wendigo-mimic",
				channel = "Monster",
				title = "Impossible Voice Overlap",
				publicDescription = "A familiar voice appears on the recording while its owner was documented elsewhere.",
				locationIds = { "residential-bedroom-clue", "police-evidence-room-clue", "cornfield-scarecrow" },
				monsterCandidates = { "Wendigo", "Entity", "Banshee" },
			},
			{
				id = "wendigo-scent-path",
				channel = "Monster",
				title = "Unbroken Pursuit Path",
				publicDescription = "Tracks follow an injured camper around blind corners without any search pattern.",
				locationIds = { "water-tower-base-clue", "industrial-machine-clue", "mines-ore-cart" },
				monsterCandidates = { "Wendigo", "Chupacabra" },
			},
		},
		ShadowMonster = {
			{
				id = "shadow-light-drain",
				channel = "Monster",
				title = "Localized Light Drain",
				publicDescription = "Bulbs dimmed in sequence despite stable power at the generator.",
				locationIds = { "square-gas-station-clue", "industrial-machine-clue", "drive-in-projector" },
				monsterCandidates = { "ShadowMonster", "Screamer", "Entity" },
			},
			{
				id = "shadow-photo",
				channel = "Monster",
				title = "Detached Silhouette",
				publicDescription = "A camera caught a silhouette that does not align with any nearby body or light source.",
				locationIds = { "residential-bedroom-clue", "police-evidence-room-clue", "crypt-empty-niche" },
				monsterCandidates = { "ShadowMonster", "Entity" },
			},
			{
				id = "shadow-residue",
				channel = "Monster",
				title = "Cold Black Residue",
				publicDescription = "Powdery residue appears only inside the darkest section of the room.",
				locationIds = { "outskirts-company-house-clue", "water-tower-base-clue", "mines-ore-cart" },
				monsterCandidates = { "ShadowMonster", "Dullahan" },
			},
		},
		Chupacabra = {
			{
				id = "chupacabra-blood",
				channel = "Monster",
				title = "Blood-Oriented Trail",
				publicDescription = "The pursuit route changes abruptly to follow the freshest blood instead of the nearest movement.",
				locationIds = { "main-road-clue-a", "residential-bedroom-clue", "cornfield-scarecrow" },
				monsterCandidates = { "Chupacabra", "Wendigo", "Banshee" },
			},
			{
				id = "chupacabra-claws",
				channel = "Monster",
				title = "Four-Part Claw Furrow",
				publicDescription = "A low wall holds four deep furrows and signs of a long horizontal leap.",
				locationIds = { "industrial-machine-clue", "outskirts-company-house-clue", "sawmill-blade" },
				monsterCandidates = { "Chupacabra", "BabyAlien" },
			},
			{
				id = "chupacabra-uv",
				channel = "Monster",
				title = "UV-Reactive Saliva",
				publicDescription = "A clear residue fluoresces strongly under ultraviolet light near the attack path.",
				locationIds = { "water-tower-base-clue", "police-evidence-room-clue", "waterfall-cave" },
				monsterCandidates = { "Chupacabra", "Entity" },
			},
		},
		Dullahan = {
			{
				id = "dullahan-frost",
				channel = "Monster",
				title = "Moving Frost Line",
				publicDescription = "Frost formed in a straight pursuing line while nearby surfaces stayed warm.",
				locationIds = { "main-road-clue-a", "water-tower-base-clue", "waterfall-cave" },
				monsterCandidates = { "Dullahan", "Wendigo", "Entity" },
			},
			{
				id = "dullahan-photo",
				channel = "Monster",
				title = "Headless Pursuer Photograph",
				publicDescription = "A blurred pursuer has clear shoulders but no visible head above them.",
				locationIds = { "police-evidence-room-clue", "square-gas-station-clue", "drive-in-projector" },
				monsterCandidates = { "Dullahan", "ShadowMonster" },
			},
			{
				id = "dullahan-sightline",
				channel = "Monster",
				title = "Accelerating Sightline Tracks",
				publicDescription = "Stride length increased only while the path remained in direct view of the victim.",
				locationIds = { "industrial-machine-clue", "outskirts-company-house-clue", "lookout-cab" },
				monsterCandidates = { "Dullahan", "BabyAlien" },
			},
		},
		Entity = {
			{
				id = "entity-anchor",
				channel = "Monster",
				title = "Repeated Anchor Distortion",
				publicDescription = "Three fixed points show the same distortion with no connecting tracks between them.",
				locationIds = { "police-evidence-room-clue", "industrial-machine-clue", "crypt-empty-niche" },
				monsterCandidates = { "Entity", "ShadowMonster", "BabyAlien" },
			},
			{
				id = "entity-handprint",
				channel = "Monster",
				title = "Inside-Surface Handprint",
				publicDescription = "A handprint appears on the sealed side of an undamaged pane.",
				locationIds = { "residential-bedroom-clue", "square-gas-station-clue", "lookout-cab" },
				monsterCandidates = { "Entity", "Banshee" },
			},
			{
				id = "entity-spirit-response",
				channel = "Monster",
				title = "Structured Spirit Response",
				publicDescription = "A Spirit Box answered a question from two locations within the same second.",
				locationIds = { "outskirts-company-house-clue", "water-tower-base-clue", "graveyard-open-grave" },
				monsterCandidates = { "Entity", "Wendigo" },
			},
		},
		Banshee = {
			{
				id = "banshee-wail",
				channel = "Monster",
				title = "Layered Wail Recording",
				publicDescription = "The recording holds overlapping vocal bands from one moving source.",
				locationIds = { "main-road-clue-a", "square-gas-station-clue", "island-firewatch" },
				monsterCandidates = { "Banshee", "Screamer", "Wendigo" },
			},
			{
				id = "banshee-fear-radius",
				channel = "Monster",
				title = "Circular Panic Pattern",
				publicDescription = "Witnesses reported the same sudden fear inside a clear radius around the attack.",
				locationIds = { "water-tower-base-clue", "residential-bedroom-clue", "graveyard-open-grave" },
				monsterCandidates = { "Banshee", "Dullahan" },
			},
			{
				id = "banshee-injury-focus",
				channel = "Monster",
				title = "Injured-Target Turn",
				publicDescription = "The pursuer abandoned a closer target immediately after an injured camper cried out.",
				locationIds = { "industrial-machine-clue", "outskirts-company-house-clue", "infirmary-logbook" },
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
		{
			id = "witness-midway-stub",
			channel = "Culprit",
			statement = "I saw someone linger at the Fairgrounds ticket booth after dusk. The green wristband is optional — carnies only chase ticket holders, and a catch is a scare escort, not an attack.",
			locationId = "main-road-witness",
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
