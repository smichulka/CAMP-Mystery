--!strict

export type UpgradeDefinition = {
	id: string,
	roleId: string,
	displayName: string,
	description: string,
	maxRank: number,
	baseCost: number,
	costPerRank: number,
	requiredMasteryLevel: number,
}

local definitions: { UpgradeDefinition } = {
	{
		id = "resourceful-packing",
		roleId = "Camper",
		displayName = "Resourceful Packing",
		description = "Packs one extra flare lantern per rank to shake off fear and distorted vision.",
		maxRank = 3,
		baseCost = 100,
		costPerRank = 75,
		requiredMasteryLevel = 1,
	},
	{
		id = "steady-hands",
		roleId = "Medic",
		displayName = "Steady Hands",
		description = "Shortens the cooldown between successful field treatments.",
		maxRank = 3,
		baseCost = 125,
		costPerRank = 90,
		requiredMasteryLevel = 1,
	},
	{
		id = "careful-reset",
		roleId = "Trapper",
		displayName = "Careful Reset",
		description = "Shortens trap setup time and improves triggered-trap recovery.",
		maxRank = 3,
		baseCost = 125,
		costPerRank = 90,
		requiredMasteryLevel = 1,
	},
	{
		id = "clear-signal",
		roleId = "Medium",
		displayName = "Clear Signal",
		description = "Shortens the cooldown between structured spirit signals.",
		maxRank = 3,
		baseCost = 125,
		costPerRank = 90,
		requiredMasteryLevel = 1,
	},
	{
		id = "watchful-post",
		roleId = "Guard",
		displayName = "Watchful Post",
		description = "Slightly extends a Guard post without increasing interception count.",
		maxRank = 3,
		baseCost = 125,
		costPerRank = 90,
		requiredMasteryLevel = 1,
	},
	{
		id = "focused-ward",
		roleId = "Protector",
		displayName = "Focused Ward",
		description = "Shortens the delay before a ward may be reassigned.",
		maxRank = 3,
		baseCost = 125,
		costPerRank = 90,
		requiredMasteryLevel = 1,
	},
	{
		id = "methodical-review",
		roleId = "Detective",
		displayName = "Methodical Review",
		description = "Shortens evidence examination without changing its result.",
		maxRank = 3,
		baseCost = 125,
		costPerRank = 90,
		requiredMasteryLevel = 1,
	},
	{
		id = "controlled-trace",
		roleId = "Murderer",
		displayName = "Controlled Trace",
		description = "Planted clues implicate fewer bystanders per rank; max rank also focuses the mistaken witness. Requires planting false evidence.",
		maxRank = 3,
		baseCost = 150,
		costPerRank = 100,
		requiredMasteryLevel = 1,
	},
}

local byRole: { [string]: { [string]: UpgradeDefinition } } = {}
for _, definition in definitions do
	assert(definition.maxRank >= 1 and definition.maxRank <= 5, "Upgrade rank cap is invalid")
	assert(definition.baseCost >= 0 and definition.costPerRank >= 0, "Upgrade cost is invalid")
	local roleDefinitions = byRole[definition.roleId]
	if not roleDefinitions then
		roleDefinitions = {}
		byRole[definition.roleId] = roleDefinitions
	end
	assert(not roleDefinitions[definition.id], "Duplicate role upgrade: " .. definition.id)
	roleDefinitions[definition.id] = table.freeze(definition)
end

local function get(roleId: string, upgradeId: string): UpgradeDefinition?
	local roleDefinitions = byRole[roleId]
	return if roleDefinitions then roleDefinitions[upgradeId] else nil
end

local function nextRankCost(definition: UpgradeDefinition, currentRank: number): number
	assert(currentRank >= 0 and currentRank < definition.maxRank, "Upgrade is already capped")
	return definition.baseCost + definition.costPerRank * currentRank
end

for _, roleDefinitions in byRole do
	table.freeze(roleDefinitions)
end

return table.freeze({
	definitions = table.freeze(definitions),
	byRole = table.freeze(byRole),
	get = get,
	nextRankCost = nextRankCost,
})
