--!strict

local shared = script.Parent.Parent
local typesFolder = shared:WaitForChild("Types")
local Types = require(typesFolder:WaitForChild("GameTypes"))

type PhaseConfig = Types.PhaseConfig

local phases: { PhaseConfig } = {
	{
		name = "Lobby",
		displayName = "Waiting at Camp",
		durationSeconds = 10,
	},
	{
		name = "RoleReveal",
		displayName = "Roles Revealed",
		durationSeconds = 8,
	},
	{
		name = "Day",
		displayName = "Daytime Objectives",
		durationSeconds = 45,
	},
	{
		name = "MurderPlanning",
		displayName = "Something Is Being Planned",
		durationSeconds = 10,
	},
	{
		name = "NightTransform",
		displayName = "The Town Is Appearing",
		durationSeconds = 6,
	},
	{
		name = "Investigation",
		displayName = "Night Investigation",
		durationSeconds = 60,
	},
	{
		name = "Campfire",
		displayName = "Campfire Vote",
		durationSeconds = 30,
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
	objectiveGoal = 3,
	evidenceGoal = 3,
	computerCulpritKey = "cpu:counselor-holloway",
	computerCulpritName = "Counselor Holloway",
	computerVictimName = "Jamie Vale",
	phases = table.freeze(phases),
})
