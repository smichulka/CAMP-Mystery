--!strict

local shared = script.Parent.Parent
local typesFolder = shared:WaitForChild("Types")
local Types = require(typesFolder:WaitForChild("GameTypes"))

type PhaseConfig = Types.PhaseConfig

local phases: { PhaseConfig } = {
	{
		name = "Lobby",
		displayName = "Waiting at Camp",
		durationSeconds = 150,
		studioDurationSeconds = 40,
	},
	{
		name = "RoleReveal",
		displayName = "Roles Revealed",
		durationSeconds = 15,
		studioDurationSeconds = 8,
	},
	{
		name = "Day",
		displayName = "Daytime Objectives",
		durationSeconds = 240,
		studioDurationSeconds = 75,
	},
	{
		name = "MurderPlanning",
		displayName = "Something Is Being Planned",
		durationSeconds = 60,
		studioDurationSeconds = 40,
	},
	{
		name = "NightTransform",
		displayName = "The Town Is Appearing",
		durationSeconds = 20,
		studioDurationSeconds = 10,
	},
	{
		name = "Investigation",
		displayName = "Night Investigation",
		durationSeconds = 480,
		studioDurationSeconds = 90,
	},
	{
		name = "Campfire",
		displayName = "Campfire Vote",
		durationSeconds = 120,
		studioDurationSeconds = 60,
		-- Discussion window at the start of Campfire: evidence is presented
		-- and chat happens; votes unlock once it elapses.
		discussionSeconds = 75,
		studioDiscussionSeconds = 25,
	},
	{
		name = "Resolution",
		displayName = "Mystery Resolution",
		durationSeconds = 30,
		studioDurationSeconds = 12,
	},
	{
		name = "Rewards",
		displayName = "Round Rewards",
		durationSeconds = 20,
		studioDurationSeconds = 10,
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
