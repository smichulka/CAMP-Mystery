--!strict

local Shared = script.Parent.Parent
local Types = require(Shared.Types:WaitForChild("EquipmentTypes"))

type EquipmentId = Types.EquipmentId

export type EquipmentPresentation = {
	id: EquipmentId,
	displayName: string,
	description: string,
	category: "Light" | "Evidence" | "Defense" | "Medical",
}

local catalog: { [EquipmentId]: EquipmentPresentation } = {
	Flashlight = {
		id = "Flashlight",
		displayName = "Flashlight",
		description = "Illuminates dark routes and can interrupt light-sensitive monsters.",
		category = "Light",
	},
	UVLight = {
		id = "UVLight",
		displayName = "UV Light",
		description = "Reveals UV traces and breaks a Chupacabra latch.",
		category = "Evidence",
	},
	LaserProjector = {
		id = "LaserProjector",
		displayName = "Laser Projector",
		description = "Reveals movement silhouettes and supernatural disturbances.",
		category = "Evidence",
	},
	Camera = {
		id = "Camera",
		displayName = "Camera",
		description = "Records visual evidence, reflections, and monster silhouettes.",
		category = "Evidence",
	},
	SpiritBox = {
		id = "SpiritBox",
		displayName = "Spirit Box",
		description = "Captures responses produced by certain supernatural entities.",
		category = "Evidence",
	},
	Thermometer = {
		id = "Thermometer",
		displayName = "Thermometer",
		description = "Records freezing or abnormal temperature evidence.",
		category = "Evidence",
	},
	AudioRecorder = {
		id = "AudioRecorder",
		displayName = "Audio Recorder",
		description = "Records screams, mimicry, and other audio evidence.",
		category = "Evidence",
	},
	EMFReader = {
		id = "EMFReader",
		displayName = "EMF Reader",
		description = "Detects electronic interference and supernatural energy.",
		category = "Evidence",
	},
	MonsterTrap = {
		id = "MonsterTrap",
		displayName = "Monster Trap",
		description = "Reveals, slows, or interrupts a monster that triggers it.",
		category = "Defense",
	},
	MedicalKit = {
		id = "MedicalKit",
		displayName = "Medical Kit",
		description = "A single-use treatment for one serious injury.",
		category = "Medical",
	},
	FlareLantern = {
		id = "FlareLantern",
		displayName = "Flare Lantern",
		description = "Creates a temporary bright safe area and suppresses some monsters.",
		category = "Defense",
	},
}

return table.freeze(catalog)

