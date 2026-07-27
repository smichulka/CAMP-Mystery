--!strict

export type PhaseTitleOverride = {
	title: string,
	subtitle: string,
	tip: string,
}

export type PhaseTitle = {
	title: string,
	subtitle: string,
	murderer: PhaseTitleOverride?,
}

local PhaseTitles: { [string]: PhaseTitle } = {
	MurderPlanning = table.freeze({
		title = "THE NIGHT IS CHOSEN",
		subtitle = "A hidden plan takes shape.",
		murderer = table.freeze({
			title = "YOUR PREY IS CHOSEN",
			subtitle = "Strike before dawn.",
			tip = "Study your target now. Your window is short.",
		}),
	}),
	NightTransform = table.freeze({
		title = "NIGHT FALLS",
		subtitle = "The monster awakens.",
		murderer = table.freeze({
			title = "YOU ARE THE MONSTER NOW",
			subtitle = "The hunt begins. Move in shadow.",
			tip = "Your ability is your greatest weapon. Use it wisely.",
		}),
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
