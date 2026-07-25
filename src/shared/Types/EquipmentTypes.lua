--!strict

export type EquipmentId =
	"Flashlight"
	| "UVLight"
	| "LaserProjector"
	| "Camera"
	| "SpiritBox"
	| "Thermometer"
	| "AudioRecorder"
	| "EMFReader"
	| "MonsterTrap"
	| "MedicalKit"
	| "FlareLantern"

export type ItemInstance = {
	instanceId: string,
	equipmentId: EquipmentId,
	ownerParticipantId: string?,
	charges: number,
	durability: number,
	equipped: boolean,
	cooldownEndsAt: number,
}

export type ItemSnapshot = {
	instanceId: string,
	equipmentId: EquipmentId,
	displayName: string,
	charges: number,
	durability: number,
	equipped: boolean,
}

export type InventorySnapshot = {
	roundId: number,
	revision: number,
	capacity: number,
	items: { ItemSnapshot },
}

return {}

