--!strict

export type EvidenceTemplate = {
	id: string,
	channel: "Culprit" | "Monster",
	displayName: string,
	description: string,
	defaultAuthenticity: "Real" | "Fake" | "Ambiguous" | "Contaminated",
}

local templates: { [string]: EvidenceTemplate } = {
	["attack-blood"] = {
		id = "attack-blood",
		channel = "Culprit",
		displayName = "Blood Trail",
		description = "A fresh trail marks the direction an injured participant traveled.",
		defaultAuthenticity = "Real",
	},
	["attack-footprint"] = {
		id = "attack-footprint",
		channel = "Culprit",
		displayName = "Partial Footprint",
		description = "The incomplete tread narrows the possible footwear but does not identify one wearer.",
		defaultAuthenticity = "Real",
	},
	["attack-fabric"] = {
		id = "attack-fabric",
		channel = "Culprit",
		displayName = "Torn Fiber",
		description = "A damaged fiber carries color and material details shared by several camp uniforms.",
		defaultAuthenticity = "Real",
	},
	["witness-conflict"] = {
		id = "witness-conflict",
		channel = "Culprit",
		displayName = "Conflicting Statement",
		description = "Two witnesses disagree about a route and time during the attack window.",
		defaultAuthenticity = "Ambiguous",
	},
	["planted-token"] = {
		id = "planted-token",
		channel = "Culprit",
		displayName = "Dropped Camp Token",
		description = "A token bearing suspicious scratches may have been dropped or deliberately planted.",
		defaultAuthenticity = "Fake",
	},
	["monster-trace"] = {
		id = "monster-trace",
		channel = "Monster",
		displayName = "Supernatural Trace",
		description = "A measurable trace is consistent with more than one monster profile.",
		defaultAuthenticity = "Real",
	},
	["device-reading"] = {
		id = "device-reading",
		channel = "Monster",
		displayName = "Equipment Reading",
		description = "A qualified device captured an abnormal reading at the scene.",
		defaultAuthenticity = "Real",
	},
}

return table.freeze(templates)

