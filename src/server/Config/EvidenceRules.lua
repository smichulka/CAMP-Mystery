--!strict

export type EvidenceTemplate = {
	id: string,
	channel: "Culprit" | "Monster" | "Insight",
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
	-- Witness-channel card emitted when the seeded contradiction counselor
	-- changes their story under repeat questioning (see CounselorService).
	["witness-story-change"] = {
		id = "witness-story-change",
		channel = "Culprit",
		displayName = "The Story Changed",
		description = "A counselor's account of the evening shifted under repeat questioning.",
		defaultAuthenticity = "Ambiguous",
	},
	-- Insight cards: derived deductions produced only by the Detective's
	-- Combine action (see EvidenceComboRules); never seeded directly.
	["insight-traced-route"] = {
		id = "insight-traced-route",
		channel = "Insight",
		displayName = "Traced Route",
		description = "Footprint and fiber line up: the killer cut through the Residential Quarter after the attack.",
		defaultAuthenticity = "Real",
	},
	["insight-timeline"] = {
		id = "insight-timeline",
		channel = "Insight",
		displayName = "Reconstructed Timeline",
		description = "The conflicting stories and the device log agree on one thing: the attack came minutes after lights-out.",
		defaultAuthenticity = "Real",
	},
	["insight-lair"] = {
		id = "insight-lair",
		channel = "Insight",
		displayName = "Lair Reading",
		description = "Two readings triangulate the creature's den: somewhere low, dark, and close to the old town.",
		defaultAuthenticity = "Real",
	},
	["insight-cover-up"] = {
		id = "insight-cover-up",
		channel = "Insight",
		displayName = "Cover-Up Pattern",
		description = "The planted token and the shakiest story share one goal: pointing the camp at the wrong person.",
		defaultAuthenticity = "Real",
	},
	["insight-crossed-paths"] = {
		id = "insight-crossed-paths",
		channel = "Insight",
		displayName = "Crossed Paths",
		description = "Monster sign overlaps the fresh footprints — the creature and its master crossed the town square together.",
		defaultAuthenticity = "Real",
	},
}

return table.freeze(templates)

