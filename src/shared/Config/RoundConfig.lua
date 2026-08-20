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
		quickCampDurationSeconds = 60,
	},
	{
		name = "RoleReveal",
		displayName = "Roles Revealed",
		durationSeconds = 15,
		studioDurationSeconds = 8,
		quickCampDurationSeconds = 10,
	},
	{
		name = "Day",
		displayName = "Daytime Objectives",
		durationSeconds = 180,
		studioDurationSeconds = 75,
		quickCampDurationSeconds = 90,
	},
	{
		name = "MurderPlanning",
		displayName = "Dusk at Camp",
		durationSeconds = 40,
		studioDurationSeconds = 30,
		quickCampDurationSeconds = 25,
	},
	{
		name = "NightTransform",
		displayName = "The Town Is Appearing",
		durationSeconds = 20,
		studioDurationSeconds = 10,
		quickCampDurationSeconds = 12,
	},
	{
		name = "Investigation",
		displayName = "Night Investigation",
		durationSeconds = 300,
		studioDurationSeconds = 100,
		quickCampDurationSeconds = 120,
	},
	{
		name = "Campfire",
		displayName = "Campfire Vote",
		durationSeconds = 120,
		studioDurationSeconds = 60,
		quickCampDurationSeconds = 45,
		-- Pre-vote theater: PresentEvidence → Rebuttal → Voting.
		-- discussionSeconds remains the total pre-vote window (present + rebuttal).
		discussionSeconds = 75,
		presentEvidenceSeconds = 45,
		rebuttalSeconds = 30,
		studioDiscussionSeconds = 25,
		studioPresentEvidenceSeconds = 15,
		studioRebuttalSeconds = 10,
		quickCampDiscussionSeconds = 30,
		quickCampPresentEvidenceSeconds = 18,
		quickCampRebuttalSeconds = 12,
	},
	{
		name = "Resolution",
		displayName = "Mystery Resolution",
		durationSeconds = 30,
		studioDurationSeconds = 12,
		quickCampDurationSeconds = 15,
	},
	{
		name = "Rewards",
		displayName = "Round Rewards",
		durationSeconds = 20,
		studioDurationSeconds = 10,
		quickCampDurationSeconds = 12,
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
