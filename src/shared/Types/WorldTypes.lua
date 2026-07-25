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

export type WorldVariantDefinition = {
	id: string,
	displayName: string,
	districtOrder: { DistrictId },
	blockedRouteIds: { string },
}

export type WorldManifestDefinition = {
	seedSalt: number,
	camp: AreaManifest,
	nightDistricts: { [DistrictId]: AreaManifest },
	variants: { WorldVariantDefinition },
}

export type WorldPublicSnapshot = {
	roundId: number,
	revision: number,
	roundSeed: number,
	variantId: string,
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
