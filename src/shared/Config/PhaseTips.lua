--!strict

local PhaseTips: { [string]: string } = {
	MurderPlanning = "Stay calm and move with purpose. The monster is choosing its plan.",
	NightTransform  = "Stick to lit paths and keep teammates in sight.",
	Investigation   = "Search methodically — scattered clues form the full picture.",
	Day             = "Complete shared work early; every resource helps after dark.",
	Campfire        = "Base your vote on evidence, not on silence or suspicion alone.",
	Resolution      = "Whatever the outcome, all evidence is revealed at resolution.",
}

return table.freeze(PhaseTips)
