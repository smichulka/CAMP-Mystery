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
	observer: PhaseTitleOverride?,
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
		murderer = table.freeze({
			title = "THEY ARE SEARCHING",
			subtitle = "Stay hidden. Destroy the evidence.",
			tip = "The evidence board builds against you. Steer suspicion before it locks in.",
		}),
		observer = table.freeze({
			title = "INVESTIGATION BEGINS",
			subtitle = "Watch the survivors search for clues.",
			tip = "",
		}),
	}),
	Day = table.freeze({
		title = "A NEW DAY",
		subtitle = "What did the night reveal?",
		murderer = table.freeze({
			title = "A NEW DAY",
			subtitle = "Hide in plain sight. Play your role.",
			tip = "Act like a Camper. Suspicion spreads fastest when you seem nervous.",
		}),
	}),
	Campfire = table.freeze({
		title = "CAMPFIRE VOTE",
		subtitle = "Choose your suspect.",
		murderer = table.freeze({
			title = "THE VOTE",
			subtitle = "Steer the blame. Survive the accusations.",
			tip = "A tie breaks in your favor. Spread doubt before votes are cast.",
		}),
		observer = table.freeze({
			title = "CAMPFIRE VOTE",
			subtitle = "Watch the verdict unfold.",
			tip = "",
		}),
	}),
	Resolution = table.freeze({
		title = "MYSTERY RESOLVED",
		subtitle = "The verdict is in.",
		murderer = table.freeze({
			title = "THE VERDICT",
			subtitle = "Did they catch you?",
			tip = "",
		}),
	}),
}

return table.freeze(PhaseTitles)
