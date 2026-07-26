--!strict

export type PhaseTitle = {
	title: string,
	subtitle: string,
}

local PhaseTitles: { [string]: PhaseTitle } = {
	MurderPlanning = table.freeze({
		title = "THE NIGHT IS CHOSEN",
		subtitle = "A hidden plan takes shape.",
	}),
	NightTransform = table.freeze({
		title = "NIGHT FALLS",
		subtitle = "The monster awakens.",
	}),
	Investigation = table.freeze({
		title = "INVESTIGATION BEGINS",
		subtitle = "Search for the truth.",
	}),
	Day = table.freeze({
		title = "A NEW DAY",
		subtitle = "What did the night reveal?",
	}),
	Campfire = table.freeze({
		title = "CAMPFIRE VOTE",
		subtitle = "Choose your suspect.",
	}),
	Resolution = table.freeze({
		title = "MYSTERY RESOLVED",
		subtitle = "The verdict is in.",
	}),
}

return table.freeze(PhaseTitles)
