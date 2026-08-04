--!strict

-- Evidence combo recipes: a seeded recipe layer over EvidenceService.
-- Each recipe joins two collected evidence card types (EvidenceRules template
-- IDs) into one derived "Insight" card. Every input template below is part of
-- the baseline mystery generated for every round, so any seeded subset of
-- recipes is always completable. Recipes never gate evidenceGoal progression;
-- insights are bonus deduction context for the campfire.

export type ComboRecipe = {
	id: string,
	-- Exactly two evidence template IDs from EvidenceRules; order-insensitive.
	inputTemplateIds: { string },
	-- The Insight-channel EvidenceRules template created by a valid combine.
	insightTemplateId: string,
}

export type EvidenceComboRulesDefinition = {
	-- How many recipes from the pool are active in one round (seeded pick).
	recipesPerRound: number,
	-- Gentle-rejection cooldown after an invalid pairing attempt.
	invalidComboCooldownSeconds: number,
	recipes: { ComboRecipe },
}

local rules: EvidenceComboRulesDefinition = {
	recipesPerRound = 3,
	invalidComboCooldownSeconds = 8,
	recipes = {
		{
			id = "combo-traced-route",
			inputTemplateIds = { "attack-footprint", "attack-fabric" },
			insightTemplateId = "insight-traced-route",
		},
		{
			id = "combo-timeline",
			inputTemplateIds = { "witness-conflict", "device-reading" },
			insightTemplateId = "insight-timeline",
		},
		{
			id = "combo-lair",
			inputTemplateIds = { "monster-trace", "device-reading" },
			insightTemplateId = "insight-lair",
		},
		{
			id = "combo-cover-up",
			inputTemplateIds = { "planted-token", "witness-conflict" },
			insightTemplateId = "insight-cover-up",
		},
		{
			id = "combo-crossed-paths",
			inputTemplateIds = { "monster-trace", "attack-footprint" },
			insightTemplateId = "insight-crossed-paths",
		},
	},
}

for _, recipe in rules.recipes do
	table.freeze(recipe.inputTemplateIds)
	table.freeze(recipe)
end
table.freeze(rules.recipes)
return table.freeze(rules)
