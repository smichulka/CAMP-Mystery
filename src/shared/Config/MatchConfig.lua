--!strict

local shared = script.Parent.Parent
local typesFolder = shared:WaitForChild("Types")
local Types = require(typesFolder:WaitForChild("MatchTypes"))

type MatchMode = Types.MatchMode

local function modeForHumanCount(humanCount: number): MatchMode?
	local count = math.clamp(math.floor(humanCount), 0, 12)
	if count == 0 then
		-- Opt-in mystery: a round can lock with zero enrolled humans so the
		-- day/night cycle keeps running as all-bot ambient theater. Solo
		-- tuning is the closest fit (it already assumes a bot-heavy roster).
		return "Solo"
	elseif count == 1 then
		return "Solo"
	elseif count <= 5 then
		return "Small"
	elseif count <= 10 then
		return "Standard"
	end
	return "Full"
end

local function targetForHumanCount(humanCount: number): number
	local count = math.clamp(math.floor(humanCount), 0, 12)
	if count >= 11 then
		return 12
	end
	return 10
end

return table.freeze({
	-- 0 since the opt-in mystery: rounds run all-bot when nobody enrolls so
	-- night (and the night town) still comes for free-roaming players.
	minimumHumans = 0,
	standardTarget = 10,
	maximumParticipants = 12,
	fillCountdownSeconds = 150,
	tickSeconds = 0.25,
	modeForHumanCount = modeForHumanCount,
	targetForHumanCount = targetForHumanCount,
})
