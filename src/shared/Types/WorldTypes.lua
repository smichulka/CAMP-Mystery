--!strict

export type DistrictId =
	"MainRoad"
	| "ResidentialQuarter"
	| "TownSquare"
	| "IndustrialDistrict"
	| "WaterTowerNeighborhood"
	| "PoliceStation"
	| "DesertedOutskirts"

export type WorldAreaId = "Camp" | DistrictId

export type SocketTag =
	"TownSocket"
	| "NPCSpawn"
	| "EvidenceSocket"
	| "MonsterSpawn"
	| "ShadowNode"
	| "HideSpot"
	| "SafeVolume"

export type TransitionState =
	"Day" | "TransformingToNight" | "Night" | "TransformingToDay"

export type SocketDefinition = {
	id: string,
	tag: SocketTag,
	required: boolean,
}

export type AreaManifest = {
	id: WorldAreaId,
	displayName: string,
	transformGroup: string,
	sockets: { SocketDefinition },
}

-- Seeded night investigation route (same Place; not multi-place teleport).
-- nightRoute ids are stable; variantId remains the TownVariant* selector key.
export type NightRouteId =
	"MainStreet"
	| "FactoryDetour"
	| "OutskirtsFirst"
	| "BackcountryNight"

export type WorldVariantDefinition = {
	id: string,
	displayName: string,
	-- Stable route id exposed on round/lobby snapshots (Wave 5 worlds).
	nightRoute: NightRouteId,
	districtOrder: { DistrictId },
	blockedRouteIds: { string },
}

export type NightRouteDefinition = {
	id: NightRouteId,
	variantId: string,
	displayName: string,
}

export type WorldManifestDefinition = {
	seedSalt: number,
	-- Single-Place world identity (routes are seeded variants, not teleports).
	worldId: string,
	camp: AreaManifest,
	nightDistricts: { [DistrictId]: AreaManifest },
	variants: { WorldVariantDefinition },
	-- Documented selectable night routes (mirrors variants[].nightRoute).
	nightRoutes: { NightRouteDefinition },
}

export type WorldPublicSnapshot = {
	roundId: number,
	revision: number,
	roundSeed: number,
	variantId: string,
	-- Seeded night route for this round (same Place).
	nightRoute: NightRouteId,
	-- Alias of nightRoute for clients that prefer worldRoute naming.
	worldRoute: NightRouteId,
	worldId: string,
	isNight: boolean,
	transitionState: TransitionState,
	activeDistrictIds: { DistrictId },
	evidenceActive: boolean,
}

export type TransformDirection = "ToNight" | "ToDay"

export type TransformMidpointContext = {
	roundId: number,
	revision: number,
	roundSeed: number,
	variantId: string,
	direction: TransformDirection,
	safeVolumeTag: "SafeVolume",
}

export type SocketReference = {
	areaId: WorldAreaId,
	socketId: string,
	tag: SocketTag,
}

return {}
