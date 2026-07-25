--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EquipmentTypes = require(
	ReplicatedStorage.Shared.Types:WaitForChild("EquipmentTypes")
)

type EquipmentId = EquipmentTypes.EquipmentId

export type EquipmentRule = {
	id: EquipmentId,
	maxCharges: number,
	maxDurability: number,
	cooldownSeconds: number,
	maxRange: number,
	stackable: boolean,
}

local rules: { [EquipmentId]: EquipmentRule } = {
	Flashlight = {
		id = "Flashlight",
		maxCharges = 100,
		maxDurability = 100,
		cooldownSeconds = 0.15,
		maxRange = 60,
		stackable = false,
	},
	UVLight = {
		id = "UVLight",
		maxCharges = 80,
		maxDurability = 100,
		cooldownSeconds = 0.25,
		maxRange = 35,
		stackable = false,
	},
	LaserProjector = {
		id = "LaserProjector",
		maxCharges = 3,
		maxDurability = 100,
		cooldownSeconds = 2,
		maxRange = 45,
		stackable = false,
	},
	Camera = {
		id = "Camera",
		maxCharges = 12,
		maxDurability = 100,
		cooldownSeconds = 1,
		maxRange = 80,
		stackable = false,
	},
	SpiritBox = {
		id = "SpiritBox",
		maxCharges = 8,
		maxDurability = 100,
		cooldownSeconds = 2,
		maxRange = 25,
		stackable = false,
	},
	Thermometer = {
		id = "Thermometer",
		maxCharges = 100,
		maxDurability = 100,
		cooldownSeconds = 0.5,
		maxRange = 16,
		stackable = false,
	},
	AudioRecorder = {
		id = "AudioRecorder",
		maxCharges = 6,
		maxDurability = 100,
		cooldownSeconds = 2,
		maxRange = 40,
		stackable = false,
	},
	EMFReader = {
		id = "EMFReader",
		maxCharges = 100,
		maxDurability = 100,
		cooldownSeconds = 0.5,
		maxRange = 24,
		stackable = false,
	},
	MonsterTrap = {
		id = "MonsterTrap",
		maxCharges = 1,
		maxDurability = 100,
		cooldownSeconds = 4,
		maxRange = 12,
		stackable = true,
	},
	MedicalKit = {
		id = "MedicalKit",
		maxCharges = 1,
		maxDurability = 100,
		cooldownSeconds = 5,
		maxRange = 10,
		stackable = true,
	},
	FlareLantern = {
		id = "FlareLantern",
		maxCharges = 1,
		maxDurability = 100,
		cooldownSeconds = 6,
		maxRange = 32,
		stackable = true,
	},
}

return table.freeze(rules)

