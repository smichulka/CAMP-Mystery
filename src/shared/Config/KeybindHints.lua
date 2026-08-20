--!strict

export type KeybindHints = {
	keyboard: { string },
	controller: { string },
}

local HINTS: { [string]: KeybindHints } = {
	Day = {
		keyboard   = { "E  Interact", "1-0  Use slots", "N  Notebook", "Tab  Players" },
		controller = { "A  Interact", "X  Use slot", "Y  Notebook", "View  Players" },
	},
	Investigation = {
		keyboard   = { "E  Interact", "1-0  Use slots", "N  Notebook", "Tab  Players" },
		controller = { "A  Interact", "X  Use slot", "Y  Notebook", "View  Players" },
	},
	Campfire = {
		keyboard   = { "E  Vote", "N  Evidence notebook" },
		controller = { "A  Vote", "Y  Evidence notebook" },
	},
	MurderPlanning = {
		keyboard   = { "CLICK  Choose target", "N  Notebook", "Tab  Players" },
		controller = { "A  Choose target", "Y  Notebook", "View  Players" },
	},
	NightTransform = {
		keyboard   = { "CLICK  Monster ability", "N  Notebook", "Tab  Players" },
		controller = { "A  Monster ability", "Y  Notebook", "View  Players" },
	},
}

return table.freeze(HINTS)
