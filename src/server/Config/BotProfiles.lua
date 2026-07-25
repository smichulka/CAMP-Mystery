--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local typesFolder = Shared:WaitForChild("Types")
local BotTypes = require(typesFolder:WaitForChild("BotTypes"))

type DifficultyName = BotTypes.DifficultyName
type DifficultyTuning = BotTypes.DifficultyTuning
type BotProfile = BotTypes.BotProfile

local difficultyTunings: { [DifficultyName]: DifficultyTuning } = {
	Beginner = {
		name = "Beginner",
		decisionQuality = 0.35,
		memoryLimit = 8,
		lieSkill = 0.2,
		minimumThinkInterval = 2.5,
		decisionJitter = 1.2,
	},
	Average = {
		name = "Average",
		decisionQuality = 0.65,
		memoryLimit = 16,
		lieSkill = 0.55,
		minimumThinkInterval = 1.5,
		decisionJitter = 0.7,
	},
	Expert = {
		name = "Expert",
		decisionQuality = 0.9,
		memoryLimit = 24,
		lieSkill = 0.85,
		minimumThinkInterval = 0.8,
		decisionJitter = 0.35,
	},
}

local profiles: { BotProfile } = {
	{
		id = "counselor-holloway",
		displayName = "Counselor Holloway",
		difficulty = "Expert",
		personality = {
			bravery = 0.85,
			curiosity = 0.55,
			sociability = 0.7,
			honesty = 0.35,
			aggression = 0.75,
			altruism = 0.45,
		},
	},
	{
		id = "jamie-vale",
		displayName = "Jamie Vale",
		difficulty = "Beginner",
		personality = {
			bravery = 0.3,
			curiosity = 0.8,
			sociability = 0.65,
			honesty = 0.9,
			aggression = 0.15,
			altruism = 0.75,
		},
	},
	{
		id = "rowan-pike",
		displayName = "Rowan Pike",
		difficulty = "Average",
		personality = {
			bravery = 0.7,
			curiosity = 0.7,
			sociability = 0.35,
			honesty = 0.75,
			aggression = 0.45,
			altruism = 0.65,
		},
	},
	{
		id = "tessa-brooks",
		displayName = "Tessa Brooks",
		difficulty = "Expert",
		personality = {
			bravery = 0.6,
			curiosity = 0.95,
			sociability = 0.7,
			honesty = 0.8,
			aggression = 0.25,
			altruism = 0.7,
		},
	},
	{
		id = "miles-reed",
		displayName = "Miles Reed",
		difficulty = "Average",
		personality = {
			bravery = 0.8,
			curiosity = 0.4,
			sociability = 0.55,
			honesty = 0.65,
			aggression = 0.65,
			altruism = 0.55,
		},
	},
	{
		id = "lena-ortiz",
		displayName = "Lena Ortiz",
		difficulty = "Average",
		personality = {
			bravery = 0.45,
			curiosity = 0.75,
			sociability = 0.9,
			honesty = 0.85,
			aggression = 0.2,
			altruism = 0.9,
		},
	},
	{
		id = "beck-wilder",
		displayName = "Beck Wilder",
		difficulty = "Beginner",
		personality = {
			bravery = 0.9,
			curiosity = 0.35,
			sociability = 0.55,
			honesty = 0.55,
			aggression = 0.8,
			altruism = 0.4,
		},
	},
	{
		id = "ivy-chen",
		displayName = "Ivy Chen",
		difficulty = "Expert",
		personality = {
			bravery = 0.55,
			curiosity = 0.9,
			sociability = 0.4,
			honesty = 0.9,
			aggression = 0.2,
			altruism = 0.8,
		},
	},
	{
		id = "noah-finch",
		displayName = "Noah Finch",
		difficulty = "Average",
		personality = {
			bravery = 0.4,
			curiosity = 0.6,
			sociability = 0.85,
			honesty = 0.7,
			aggression = 0.3,
			altruism = 0.75,
		},
	},
	{
		id = "mara-stone",
		displayName = "Mara Stone",
		difficulty = "Expert",
		personality = {
			bravery = 0.75,
			curiosity = 0.8,
			sociability = 0.5,
			honesty = 0.6,
			aggression = 0.55,
			altruism = 0.65,
		},
	},
	{
		id = "eli-mercer",
		displayName = "Eli Mercer",
		difficulty = "Beginner",
		personality = {
			bravery = 0.35,
			curiosity = 0.55,
			sociability = 0.75,
			honesty = 0.95,
			aggression = 0.1,
			altruism = 0.85,
		},
	},
	{
		id = "sloane-rivers",
		displayName = "Sloane Rivers",
		difficulty = "Average",
		personality = {
			bravery = 0.65,
			curiosity = 0.65,
			sociability = 0.6,
			honesty = 0.5,
			aggression = 0.5,
			altruism = 0.5,
		},
	},
}

local BotProfiles = {}

function BotProfiles.Get(profileId: string): BotProfile?
	for _, profile in profiles do
		if profile.id == profileId then
			return profile
		end
	end
	return nil
end

function BotProfiles.GetAll(): { BotProfile }
	return table.clone(profiles)
end

function BotProfiles.GetDifficulty(difficulty: DifficultyName): DifficultyTuning
	local tuning = difficultyTunings[difficulty]
	assert(tuning, "Missing bot difficulty tuning for " .. difficulty)
	return tuning
end

function BotProfiles.ResolveDifficulty(decisionQuality: number): DifficultyName
	if decisionQuality >= 0.8 then
		return "Expert"
	elseif decisionQuality >= 0.5 then
		return "Average"
	else
		return "Beginner"
	end
end

return table.freeze(BotProfiles)
