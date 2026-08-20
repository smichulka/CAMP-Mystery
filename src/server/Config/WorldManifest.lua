--!strict

-- Wave 5 worlds stay in ONE Place. Day uses the camp + Midway Festival
-- Fairgrounds; night investigation routes are seeded TownVariant picks
-- (including BackcountryNight and LakeshoreNight). No multi-place teleport.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldTypes = require(Shared:WaitForChild("Types"):WaitForChild("WorldTypes"))

type WorldManifestDefinition = WorldTypes.WorldManifestDefinition

local manifest: WorldManifestDefinition = {
	seedSalt = 271_828,
	worldId = "CampMystery",
	camp = {
		id = "Camp",
		displayName = "CAMP-Mystery Camp",
		transformGroup = "PersistentCamp",
		sockets = {
			{ id = "camp-town-north", tag = "TownSocket", required = true },
			{ id = "camp-town-east", tag = "TownSocket", required = true },
			{ id = "camp-counselor-spawn-a", tag = "NPCSpawn", required = true },
			{ id = "camp-counselor-spawn-b", tag = "NPCSpawn", required = true },
			{ id = "camp-evidence-board", tag = "EvidenceSocket", required = true },
			{ id = "camp-monster-tree-line", tag = "MonsterSpawn", required = true },
			{ id = "camp-shadow-cabins", tag = "ShadowNode", required = false },
			{ id = "camp-hide-cabin-a", tag = "HideSpot", required = true },
			{ id = "camp-safe-campfire", tag = "SafeVolume", required = true },
			{ id = "camp-safe-spawn", tag = "SafeVolume", required = true },
		},
	},
	nightDistricts = {
		MainRoad = {
			id = "MainRoad",
			displayName = "Foggy Main Road",
			transformGroup = "NightTown",
			sockets = {
				{ id = "main-road-camp-entry", tag = "TownSocket", required = true },
				{ id = "main-road-square-exit", tag = "TownSocket", required = true },
				{ id = "main-road-witness", tag = "NPCSpawn", required = true },
				{ id = "main-road-clue-a", tag = "EvidenceSocket", required = true },
				{ id = "main-road-monster", tag = "MonsterSpawn", required = true },
				{ id = "main-road-lamp-shadow", tag = "ShadowNode", required = true },
				{ id = "main-road-car-hide", tag = "HideSpot", required = false },
				{ id = "main-road-safe-entry", tag = "SafeVolume", required = true },
			},
		},
		ResidentialQuarter = {
			id = "ResidentialQuarter",
			displayName = "Residential Quarter",
			transformGroup = "NightTown",
			sockets = {
				{ id = "residential-road-link", tag = "TownSocket", required = true },
				{ id = "residential-outskirts-link", tag = "TownSocket", required = true },
				{ id = "residential-survivor", tag = "NPCSpawn", required = false },
				{ id = "residential-bedroom-clue", tag = "EvidenceSocket", required = true },
				{ id = "residential-backyard-monster", tag = "MonsterSpawn", required = false },
				{ id = "residential-alley-shadow", tag = "ShadowNode", required = true },
				{ id = "residential-closet-hide", tag = "HideSpot", required = true },
				{ id = "residential-safe-porch", tag = "SafeVolume", required = true },
			},
		},
		TownSquare = {
			id = "TownSquare",
			displayName = "Town Square",
			transformGroup = "NightTown",
			sockets = {
				{ id = "square-main-road-link", tag = "TownSocket", required = true },
				{ id = "square-police-link", tag = "TownSocket", required = true },
				{ id = "square-store-witness", tag = "NPCSpawn", required = false },
				{ id = "square-gas-station-clue", tag = "EvidenceSocket", required = true },
				{ id = "square-fountain-monster", tag = "MonsterSpawn", required = true },
				{ id = "square-arcade-shadow", tag = "ShadowNode", required = true },
				{ id = "square-store-hide", tag = "HideSpot", required = true },
				{ id = "square-safe-bandstand", tag = "SafeVolume", required = true },
			},
		},
		IndustrialDistrict = {
			id = "IndustrialDistrict",
			displayName = "Industrial District",
			transformGroup = "NightTown",
			sockets = {
				{ id = "industrial-square-link", tag = "TownSocket", required = true },
				{ id = "industrial-tunnel-link", tag = "TownSocket", required = true },
				{ id = "industrial-worker", tag = "NPCSpawn", required = false },
				{ id = "industrial-machine-clue", tag = "EvidenceSocket", required = true },
				{ id = "industrial-factory-monster", tag = "MonsterSpawn", required = true },
				{ id = "industrial-tunnel-shadow", tag = "ShadowNode", required = true },
				{ id = "industrial-locker-hide", tag = "HideSpot", required = true },
				{ id = "industrial-safe-loading-bay", tag = "SafeVolume", required = true },
			},
		},
		WaterTowerNeighborhood = {
			id = "WaterTowerNeighborhood",
			displayName = "Water-Tower Neighborhood",
			transformGroup = "NightTown",
			sockets = {
				{ id = "water-tower-residential-link", tag = "TownSocket", required = true },
				{ id = "water-tower-industrial-link", tag = "TownSocket", required = true },
				{ id = "water-tower-witness", tag = "NPCSpawn", required = false },
				{ id = "water-tower-base-clue", tag = "EvidenceSocket", required = true },
				{ id = "water-tower-yard-monster", tag = "MonsterSpawn", required = true },
				{ id = "water-tower-house-shadow", tag = "ShadowNode", required = true },
				{ id = "water-tower-shed-hide", tag = "HideSpot", required = true },
				{ id = "water-tower-safe-platform", tag = "SafeVolume", required = true },
			},
		},
		PoliceStation = {
			id = "PoliceStation",
			displayName = "Police Station and Evidence Room",
			transformGroup = "NightTown",
			sockets = {
				{ id = "police-square-link", tag = "TownSocket", required = true },
				{ id = "police-industrial-link", tag = "TownSocket", required = false },
				{ id = "police-desk-witness", tag = "NPCSpawn", required = false },
				{ id = "police-evidence-room-clue", tag = "EvidenceSocket", required = true },
				{ id = "police-cell-monster", tag = "MonsterSpawn", required = false },
				{ id = "police-hall-shadow", tag = "ShadowNode", required = true },
				{ id = "police-cell-hide", tag = "HideSpot", required = true },
				{ id = "police-safe-lobby", tag = "SafeVolume", required = true },
			},
		},
		DesertedOutskirts = {
			id = "DesertedOutskirts",
			displayName = "Deserted Outskirts",
			transformGroup = "NightTown",
			sockets = {
				{ id = "outskirts-residential-link", tag = "TownSocket", required = true },
				{ id = "outskirts-industrial-link", tag = "TownSocket", required = false },
				{ id = "outskirts-lost-witness", tag = "NPCSpawn", required = false },
				{ id = "outskirts-company-house-clue", tag = "EvidenceSocket", required = true },
				{ id = "outskirts-tree-line-monster", tag = "MonsterSpawn", required = true },
				{ id = "outskirts-dead-tree-shadow", tag = "ShadowNode", required = true },
				{ id = "outskirts-house-hide", tag = "HideSpot", required = true },
				{ id = "outskirts-safe-road-end", tag = "SafeVolume", required = true },
			},
		},
	},
	variants = {
		{
			id = "TownVariantA",
			displayName = "Main Street",
			nightRoute = "MainStreet",
			districtOrder = {
				"MainRoad",
				"TownSquare",
				"PoliceStation",
				"ResidentialQuarter",
				"WaterTowerNeighborhood",
				"IndustrialDistrict",
				"DesertedOutskirts",
			},
			blockedRouteIds = { "outskirts-industrial-link" },
		},
		{
			id = "TownVariantB",
			displayName = "Factory Detour",
			nightRoute = "FactoryDetour",
			districtOrder = {
				"MainRoad",
				"ResidentialQuarter",
				"WaterTowerNeighborhood",
				"IndustrialDistrict",
				"TownSquare",
				"PoliceStation",
				"DesertedOutskirts",
			},
			blockedRouteIds = { "police-industrial-link" },
		},
		{
			id = "TownVariantC",
			displayName = "Outskirts First",
			nightRoute = "OutskirtsFirst",
			districtOrder = {
				"MainRoad",
				"DesertedOutskirts",
				"ResidentialQuarter",
				"TownSquare",
				"WaterTowerNeighborhood",
				"PoliceStation",
				"IndustrialDistrict",
			},
			blockedRouteIds = { "water-tower-industrial-link" },
		},
		-- Wave 5 World C: Backcountry-leaning night start — after camp entry,
		-- investigation pushes north toward water-tower / outskirts wild edge
		-- (the day Backcountry trails feed that approach). Same Place.
		{
			id = "TownVariantD",
			displayName = "Backcountry Night",
			nightRoute = "BackcountryNight",
			districtOrder = {
				"MainRoad",
				"WaterTowerNeighborhood",
				"DesertedOutskirts",
				"ResidentialQuarter",
				"TownSquare",
				"PoliceStation",
				"IndustrialDistrict",
			},
			blockedRouteIds = { "outskirts-industrial-link", "police-industrial-link" },
		},
		-- Cycle 5 scenic route: lakeshore-leaning order — residential shore,
		-- water tower overlook, then square before the wild outskirts edge.
		{
			id = "TownVariantE",
			displayName = "Lakeshore Night",
			nightRoute = "LakeshoreNight",
			districtOrder = {
				"MainRoad",
				"ResidentialQuarter",
				"WaterTowerNeighborhood",
				"TownSquare",
				"DesertedOutskirts",
				"PoliceStation",
				"IndustrialDistrict",
			},
			blockedRouteIds = { "water-tower-industrial-link", "outskirts-industrial-link" },
		},
	},
	nightRoutes = {
		{ id = "MainStreet", variantId = "TownVariantA", displayName = "Main Street" },
		{ id = "FactoryDetour", variantId = "TownVariantB", displayName = "Factory Detour" },
		{ id = "OutskirtsFirst", variantId = "TownVariantC", displayName = "Outskirts First" },
		{ id = "BackcountryNight", variantId = "TownVariantD", displayName = "Backcountry Night" },
		{ id = "LakeshoreNight", variantId = "TownVariantE", displayName = "Lakeshore Night" },
	},
}

local function freezeArea(area: WorldTypes.AreaManifest)
	for _, socket in area.sockets do
		table.freeze(socket)
	end
	table.freeze(area.sockets)
	table.freeze(area)
end

freezeArea(manifest.camp)
for _, district in manifest.nightDistricts do
	freezeArea(district)
end
table.freeze(manifest.nightDistricts)

for _, variant in manifest.variants do
	table.freeze(variant.districtOrder)
	table.freeze(variant.blockedRouteIds)
	table.freeze(variant)
end
table.freeze(manifest.variants)

for _, route in manifest.nightRoutes do
	table.freeze(route)
end
table.freeze(manifest.nightRoutes)

return table.freeze(manifest)
