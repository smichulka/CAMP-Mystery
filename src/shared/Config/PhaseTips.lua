--!strict

local PhaseTips: { [string]: string } = {
	MurderPlanning = "Dusk: check in with a buddy, pass spare gear, and ask counselors what they saw.",
	NightTransform  = "Stick to lit paths and keep teammates in sight.",
	Investigation   = "Search methodically — scattered clues form the full picture. Brave detours pay: the water tower radio, the mill fuse box, a cry for help.",
	Day             = "Camp tasks decide the night: generator = lights, firewood = campfire haven, supplies = bonus gear.",
	Campfire        = "Base your vote on evidence, not on silence or suspicion alone.",
	Resolution      = "Whatever the outcome, all evidence is revealed at resolution.",
}

return table.freeze(PhaseTips)
