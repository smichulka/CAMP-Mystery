--!strict

export type KeybindHints = {
	keyboard: { string },
	controller: { string },
}

local HINTS: { [string]: KeybindHints } = {
	Day = {
		keyboard   = { "E  Interact", "N  Notebook", "Tab  Players", "F  Equip item" },
		controller = { "A  Interact", "Y  Notebook", "View  Players", "X  Equip item" },
	},
	Investigation = {
		keyboard   = { "E  Interact", "N  Notebook", "Q  Role ability", "Tab  Players" },
		controller = { "A  Interact", "Y  Notebook", "LB  Role ability", "View  Players" },
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
