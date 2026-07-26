--!strict

export type KeybindHints = {
	keyboard: { string },
	controller: { string },
}

local HINTS: { [string]: KeybindHints } = {
	Day = {
		keyboard   = { "E  Interact", "N  Notebook", "Tab  Map", "F  Equip item" },
		controller = { "A  Interact", "Y  Notebook", "View  Map", "X  Equip item" },
	},
	Investigation = {
		keyboard   = { "E  Interact", "N  Notebook", "Q  Role ability", "Tab  Map" },
		controller = { "A  Interact", "Y  Notebook", "LB  Role ability", "View  Map" },
	},
	Campfire = {
		keyboard   = { "E  Vote", "N  Evidence notebook" },
		controller = { "A  Vote", "Y  Evidence notebook" },
	},
}

return table.freeze(HINTS)
