--!strict

-- Governs how much bots help (or hunt) so human players keep the spotlight.
-- Bots travel to a site, spend work time there, and act only within range;
-- their task/evidence output shrinks as more living humans are present.

export type BotContributionCaps = {
	objectives: number,
	evidence: number,
}

local BotContributionConfig = {
	walkSpeedStudsPerSecond = 9,
	siteRangeStuds = 12,
	objectiveWorkSeconds = 8,
	evidenceWorkSeconds = 5,
	interviewWorkSeconds = 4,
	treatRangeStuds = 8,
	attackRangeStuds = 10,
	attackWindupSeconds = 1.5,
	maximumTravelSeconds = 20,
	voteStaggerMinimumSeconds = 5,
	voteStaggerSpreadSeconds = 25,
	humanVoteFollowWeight = 8,
	commitBonusUtility = 40,
}

function BotContributionConfig.GetCaps(livingHumans: number): BotContributionCaps
	if livingHumans >= 4 then
		return { objectives = 0, evidence = 0 }
	end
	if livingHumans >= 2 then
		return { objectives = 1, evidence = 2 }
	end
	return { objectives = 2, evidence = 4 }
end

return table.freeze(BotContributionConfig)
