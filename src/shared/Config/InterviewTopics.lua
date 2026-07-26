--!strict

export type InterviewTopic = {
	topic: string, -- exact server DialogueTopic string
	label: string, -- button label shown to player
	hint: string, -- short subtitle shown under the label
	witnessHighlight: boolean, -- true = highlight Amber when counselor isWitness
}

local definitions: { InterviewTopic } = {
	{
		topic = "Observation",
		label = "WHAT DID YOU SEE?",
		hint = "Recent sightings and unusual activity",
		witnessHighlight = true,
	},
	{
		topic = "Schedule",
		label = "WHERE WERE YOU?",
		hint = "Location and routine during the night",
		witnessHighlight = false,
	},
	{
		topic = "Monster",
		label = "ABOUT THE MONSTER",
		hint = "Describe what you know about the threat",
		witnessHighlight = false,
	},
	{
		topic = "Suspicion",
		label = "WHO DO YOU SUSPECT?",
		hint = "Name anyone behaving strangely",
		witnessHighlight = false,
	},
}

return table.freeze({
	definitions = table.freeze(definitions),
})
