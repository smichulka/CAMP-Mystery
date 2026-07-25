--!strict

local shared = script.Parent.Parent
local typesFolder = shared:WaitForChild("Types")
local Types = require(typesFolder:WaitForChild("ParticipantTypes"))

type RoleName = Types.RoleName
type RoleDefinition = Types.RoleDefinition

local definitions: { [RoleName]: RoleDefinition } = {
	Camper = {
		name = "Camper",
		displayName = "Camper",
		description = "Complete camp jobs, stay alive, and help expose the murderer.",
		team = "Campers",
		abilities = {
			{
				id = "camp-resourcefulness",
				displayName = "Resourcefulness",
				description = "Complete ordinary camp tasks and use general-purpose equipment.",
				cooldownSeconds = 0,
				maxUsesPerRound = nil,
			},
		},
	},
	Medic = {
		name = "Medic",
		displayName = "Medic",
		description = "Treat injuries and keep campers alive long enough to solve the mystery.",
		team = "Campers",
		abilities = {
			{
				id = "field-treatment",
				displayName = "Field Treatment",
				description = "Treat an injured participant with carried medical supplies.",
				cooldownSeconds = 20,
				maxUsesPerRound = 3,
			},
		},
	},
	Trapper = {
		name = "Trapper",
		displayName = "Trapper",
		description = "Control dangerous routes and reveal creatures or people that trigger traps.",
		team = "Campers",
		abilities = {
			{
				id = "place-warning-trap",
				displayName = "Warning Trap",
				description = "Place a limited trap that reports when something crosses it.",
				cooldownSeconds = 15,
				maxUsesPerRound = 3,
			},
		},
	},
	Medium = {
		name = "Medium",
		displayName = "Medium",
		description = "Sense supernatural activity and receive limited information from ghosts.",
		team = "Campers",
		abilities = {
			{
				id = "spirit-sense",
				displayName = "Spirit Sense",
				description = "Detect nearby ghost activity and interpret a limited ghost message.",
				cooldownSeconds = 30,
				maxUsesPerRound = 2,
			},
		},
	},
	Guard = {
		name = "Guard",
		displayName = "Guard",
		description = "Patrol the camp and interrupt threats near protected locations.",
		team = "Campers",
		abilities = {
			{
				id = "guard-post",
				displayName = "Guard Post",
				description = "Watch a nearby area and gain a chance to interrupt a hostile action.",
				cooldownSeconds = 25,
				maxUsesPerRound = 2,
			},
		},
	},
	Protector = {
		name = "Protector",
		displayName = "Protector",
		description = "Choose another participant to protect from one hostile action.",
		team = "Campers",
		abilities = {
			{
				id = "protect-participant",
				displayName = "Protection",
				description = "Protect one eligible participant from the next hostile action.",
				cooldownSeconds = 35,
				maxUsesPerRound = 2,
			},
		},
	},
	Detective = {
		name = "Detective",
		displayName = "Detective",
		description = "Analyze evidence and identify contradictions in the camp's story.",
		team = "Campers",
		abilities = {
			{
				id = "analyze-evidence",
				displayName = "Analyze Evidence",
				description = "Learn an additional property of a collected piece of evidence.",
				cooldownSeconds = 20,
				maxUsesPerRound = 3,
			},
		},
	},
	Murderer = {
		name = "Murderer",
		displayName = "Murderer",
		description = "Plan an attack, misdirect the investigation, and survive the final vote.",
		team = "Murderer",
		abilities = {
			{
				id = "monster-transformation",
				displayName = "Monster Transformation",
				description = "Transform into the selected monster during an authorized attack window.",
				cooldownSeconds = 0,
				maxUsesPerRound = 1,
			},
			{
				id = "hostile-attack",
				displayName = "Hostile Attack",
				description = "Attempt an attack against an eligible target.",
				cooldownSeconds = 20,
				maxUsesPerRound = 2,
			},
			{
				id = "plant-false-evidence",
				displayName = "Plant False Evidence",
				description = "Place one misleading clue that can frame another suspect.",
				cooldownSeconds = 30,
				maxUsesPerRound = 1,
			},
		},
	},
	Spectator = {
		name = "Spectator",
		displayName = "Spectator",
		description = "Observe the current round and join when the next round begins.",
		team = "Observers",
		abilities = {},
	},
}

local specialRoleOrder: { RoleName } = {
	"Detective",
	"Medic",
	"Guard",
	"Protector",
	"Trapper",
	"Medium",
}

local RoleCatalog = {}

function RoleCatalog.Get(roleName: RoleName): RoleDefinition
	local definition = definitions[roleName]
	assert(definition, "Missing role definition for " .. roleName)
	return definition
end

function RoleCatalog.GetDistribution(participantCount: number): { RoleName }
	assert(
		participantCount >= 0 and participantCount <= 12 and participantCount % 1 == 0,
		"Participant count must be a whole number from 0 through 12"
	)
	if participantCount == 0 then
		return {}
	end

	local roles: { RoleName } = { "Murderer" }
	if participantCount == 1 then
		return roles
	end

	local specialCount = math.min(#specialRoleOrder, participantCount - 2)
	for index = 1, specialCount do
		table.insert(roles, specialRoleOrder[index])
	end

	while #roles < participantCount do
		table.insert(roles, "Camper")
	end
	return roles
end

function RoleCatalog.GetAll(): { RoleDefinition }
	local orderedNames: { RoleName } = {
		"Camper",
		"Medic",
		"Trapper",
		"Medium",
		"Guard",
		"Protector",
		"Detective",
		"Murderer",
		"Spectator",
	}
	local result: { RoleDefinition } = {}
	for _, roleName in orderedNames do
		table.insert(result, definitions[roleName])
	end
	return result
end

return table.freeze(RoleCatalog)
