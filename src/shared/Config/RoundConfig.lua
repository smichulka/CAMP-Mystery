--!strict

local shared = script.Parent.Parent
local typesFolder = shared:WaitForChild("Types")
local Types = require(typesFolder:WaitForChild("GameTypes"))

type PhaseConfig = Types.PhaseConfig

local phases: { PhaseConfig } = {
	{
		name = "Lobby",
		displayName = "Waiting at Camp",
		durationSeconds = 15,
	},
	{
		name = "RoleReveal",
		displayName = "Roles Revealed",
		durationSeconds = 8,
	},
	{
		name = "Day",
		displayName = "Daytime Objectives",
		durationSeconds = 30,
	},
	{
		name = "MurderPlanning",
		displayName = "Something Is Being Planned",
		durationSeconds = 12,
	},
	{
		name = "NightTransform",
		displayName = "The Town Is Appearing",
		durationSeconds = 8,
	},
	{
		name = "Investigation",
		displayName = "Night Investigation",
		durationSeconds = 45,
	},
	{
		name = "Campfire",
		displayName = "Campfire Discussion",
		durationSeconds = 25,
	},
	{
		name = "Resolution",
		displayName = "Mystery Resolution",
		durationSeconds = 10,
	},
	{
		name = "Rewards",
		displayName = "Round Rewards",
		durationSeconds = 8,
	},
}

return table.freeze({
	minimumPlayers = 1,
	phases = table.freeze(phases),
})
