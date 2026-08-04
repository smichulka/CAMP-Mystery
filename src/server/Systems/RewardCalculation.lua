--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local configFolder = Shared:WaitForChild("Config")
local typesFolder = Shared:WaitForChild("Types")
local ProgressionConfig = require(configFolder:WaitForChild("ProgressionConfig"))
local Types = require(typesFolder:WaitForChild("ProfileTypes"))

type RewardInput = Types.RewardInput
type RewardGrant = Types.RewardGrant

local RewardCalculation = {}

local function safeCount(value: number, maximum: number): number
	if value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(math.floor(value), 0, maximum)
end

function RewardCalculation.Calculate(input: RewardInput): RewardGrant
	local rewards = ProgressionConfig.rewards
	local objectives = safeCount(
		input.objectivesCompleted,
		rewards.maxRewardedObjectives
	)
	local evidence = safeCount(input.evidenceCollected, rewards.maxRewardedEvidence)

	if not input.participated then
		objectives = 0
		evidence = 0
	end

	local xp = 0
	local campTokens = 0
	local roleMasteryXP = 0
	local roundsPlayed = 0

	if input.participated then
		roundsPlayed = 1
		xp += rewards.participationXP
		campTokens += rewards.participationTokens
		roleMasteryXP += rewards.roleParticipationXP

		xp += objectives * rewards.objectiveXP
		xp += evidence * rewards.evidenceXP
		campTokens += objectives * rewards.objectiveTokens
		campTokens += evidence * rewards.evidenceTokens
		roleMasteryXP += (objectives + evidence) * rewards.roleContributionXP

		if input.won then
			xp += rewards.winXP
			campTokens += rewards.winTokens
			roleMasteryXP += rewards.roleWinXP
		end
		if input.survived then
			xp += rewards.survivalXP
			campTokens += rewards.survivalTokens
		end
		-- Dusk buddy check-ins: small social bonus, capped so farming pairs
		-- is pointless.
		xp += math.min(math.floor(input.checkIns or 0), 3) * 5
		-- Night side-objectives (counselor rescue, radio beacon, fuse box):
		-- worth a detour, capped so they never rival the main goals.
		local sideObjectives = math.min(math.floor(input.sideObjectives or 0), 3)
		xp += sideObjectives * 15
		campTokens += sideObjectives * 2
		-- Ghost micro-objectives keep eliminated players earning at a gentle
		-- rate; the cap stops idle hover-farming from paying out forever.
		xp += math.min(math.floor(input.ghostObjectives or 0), 6) * 4
		-- Cold case archive: reading all three police-station files is worth
		-- one small courage bonus per round, never more.
		xp += math.min(math.floor(input.coldCasesReviewed or 0), 1) * 15

		-- Event bonus (Blood Moon weather): modest, clamped so a bad input
		-- can never zero out or explode a round's payout. Applies after all
		-- flat bonuses so an event night lifts everything evenly.
		local rawMultiplier = input.rewardMultiplier or 1
		if rawMultiplier ~= rawMultiplier then
			rawMultiplier = 1
		end
		local rewardMultiplier = math.clamp(rawMultiplier, 1, 2)
		if rewardMultiplier > 1 then
			xp = math.floor(xp * rewardMultiplier)
			campTokens = math.floor(campTokens * rewardMultiplier)
		end
	end

	local roleIsMurderer = input.roleId == "Murderer"
	local monsterId = input.monsterId
	return {
		receiptId = input.receiptId,
		roleId = input.roleId,
		xp = xp,
		campTokens = campTokens,
		roleMasteryXP = roleMasteryXP,
		roundsPlayed = roundsPlayed,
		wins = if input.participated and input.won then 1 else 0,
		camperWins = if input.participated and input.won and not roleIsMurderer
			then 1
			else 0,
		murdererWins = if input.participated and input.won and roleIsMurderer
			then 1
			else 0,
		objectivesCompleted = objectives,
		evidenceCollected = evidence,
		survivals = if input.participated and input.survived then 1 else 0,
		monsterId = monsterId,
		monsterEncounter = if input.participated and monsterId ~= nil then 1 else 0,
		monsterSurvival = if input.participated and monsterId ~= nil and input.survived
			then 1
			else 0,
		monsterIdentification = if input.participated
				and monsterId ~= nil
				and input.identifiedMonster == true
			then 1
			else 0,
	}
end

return RewardCalculation
