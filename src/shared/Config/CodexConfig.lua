--!strict
-- Monster mastery / codex challenges. Progress is derived from ProfileTypes
-- MonsterStatRecord counters (encounters, survivals, identifications).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonsterTypes = require(Shared:WaitForChild("Types"):WaitForChild("MonsterTypes"))
local MonsterOrder = require(Shared:WaitForChild("Config"):WaitForChild("MonsterOrder"))

type MonsterId = MonsterTypes.MonsterId

export type ChallengeStat = "encounters" | "survivals" | "identifications"

export type CodexChallenge = {
	id: string,
	monsterId: MonsterId,
	stat: ChallengeStat,
	target: number,
	title: string,
	description: string,
}

local challenges: { CodexChallenge } = {
	{
		id = "wendigo-survive-3",
		monsterId = "Wendigo",
		stat = "survivals",
		target = 3,
		title = "Survive the Antlers",
		description = "Survive 3 nights against the Wendigo.",
	},
	{
		id = "banshee-survive-3",
		monsterId = "Banshee",
		stat = "survivals",
		target = 3,
		title = "Outrun the Wail",
		description = "Survive 3 nights against the Banshee.",
	},
	{
		id = "shadow-identify-2",
		monsterId = "ShadowMonster",
		stat = "identifications",
		target = 2,
		title = "Name the Shadow",
		description = "Correctly identify the Shadow Monster culprit twice.",
	},
	{
		id = "dullahan-encounter-5",
		monsterId = "Dullahan",
		stat = "encounters",
		target = 5,
		title = "Headless Pursuit",
		description = "Face the Dullahan in 5 rounds.",
	},
	{
		id = "chupacabra-survive-2",
		monsterId = "Chupacabra",
		stat = "survivals",
		target = 2,
		title = "Break the Latch",
		description = "Survive 2 nights against the Chupacabra.",
	},
	{
		id = "entity-identify-2",
		monsterId = "Entity",
		stat = "identifications",
		target = 2,
		title = "Anchor Hunter",
		description = "Expose the Entity as culprit twice.",
	},
	{
		id = "screamer-encounter-4",
		monsterId = "Screamer",
		stat = "encounters",
		target = 4,
		title = "Silence Practice",
		description = "Encounter the Screamer across 4 nights.",
	},
	{
		id = "baby-alien-survive-3",
		monsterId = "BabyAlien",
		stat = "survivals",
		target = 3,
		title = "Leap Denial",
		description = "Survive 3 nights against the Baby Alien.",
	},
	{
		id = "shadow-survive-3",
		monsterId = "ShadowMonster",
		stat = "survivals",
		target = 3,
		title = "Hold the Light",
		description = "Survive 3 nights against the Shadow Monster.",
	},
	{
		id = "banshee-identify-2",
		monsterId = "Banshee",
		stat = "identifications",
		target = 2,
		title = "Name the Wail",
		description = "Correctly identify the Banshee culprit twice.",
	},
}

local byMonsterId: { [MonsterId]: { CodexChallenge } } = {}
for _, monsterId in MonsterOrder do
	byMonsterId[monsterId] = {}
end
for _, challenge in challenges do
	local list = byMonsterId[challenge.monsterId]
	if list then
		table.insert(list, table.freeze(challenge))
	end
end

local function masteryTier(encounters: number, survivals: number, identifications: number): number
	local score = encounters + survivals * 2 + identifications * 3
	if score >= 20 then
		return 3
	elseif score >= 10 then
		return 2
	elseif score >= 3 then
		return 1
	end
	return 0
end

local function challengeProgress(
	challenge: CodexChallenge,
	record: { encounters: number, survivals: number, identifications: number }?
): (number, number, boolean)
	local current = 0
	if record then
		if challenge.stat == "encounters" then
			current = record.encounters
		elseif challenge.stat == "survivals" then
			current = record.survivals
		else
			current = record.identifications
		end
	end
	current = math.max(0, math.floor(current))
	local target = challenge.target
	return current, target, current >= target
end

return table.freeze({
	challenges = table.freeze(challenges),
	byMonsterId = table.freeze(byMonsterId),
	masteryTier = masteryTier,
	challengeProgress = challengeProgress,
	masteryTierLabels = table.freeze({
		[0] = "Unseen",
		[1] = "Aware",
		[2] = "Seasoned",
		[3] = "Mastered",
	}),
})
