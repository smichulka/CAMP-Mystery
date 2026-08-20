--!strict
-- Funnel telemetry wrapper. Never throws: Roblox AnalyticsService only delivers
-- in published experiences, and Studio/API gaps must not break rounds.

local AnalyticsServiceRoblox = game:GetService("AnalyticsService")

local AnalyticsService = {}

export type FunnelFields = { [string]: string }

local function buildCustomFields(fields: FunnelFields?): { [string]: string }?
	if not fields then
		return nil
	end
	local customFields: { [string]: string } = {}
	local index = 0
	for key, value in fields do
		index += 1
		if index > 3 then
			break
		end
		local fieldKey = if index == 1
			then Enum.AnalyticsCustomFieldKeys.CustomField01.Name
			elseif index == 2 then Enum.AnalyticsCustomFieldKeys.CustomField02.Name
			else Enum.AnalyticsCustomFieldKeys.CustomField03.Name
		customFields[fieldKey] = string.format("%s=%s", key, value)
	end
	return customFields
end

function AnalyticsService.LogCustomEvent(
	player: Player?,
	eventName: string,
	value: number?,
	fields: FunnelFields?
): boolean
	if typeof(eventName) ~= "string" or eventName == "" then
		return false
	end
	local amount = if typeof(value) == "number" then value else 1
	local customFields = buildCustomFields(fields)
	local logged = false

	if player ~= nil then
		local ok = pcall(function()
			AnalyticsServiceRoblox:LogCustomEvent(player, eventName, amount, customFields)
		end)
		logged = ok
		if not ok then
			pcall(function()
				(AnalyticsServiceRoblox :: any):FireCustomEvent(player, eventName, {
					value = amount,
					fields = fields,
				})
			end)
		end
	else
		-- Non-player beats (PhaseEnter): prefer FireCustomEvent; never throw.
		pcall(function()
			(AnalyticsServiceRoblox :: any):FireCustomEvent(nil, eventName, {
				value = amount,
				fields = fields,
			})
		end)
	end
	return logged
end

function AnalyticsService.LogFunnel(
	player: Player?,
	eventName: string,
	fields: FunnelFields?
): boolean
	return AnalyticsService.LogCustomEvent(player, eventName, 1, fields)
end

-- Named funnel steps used by live-ops / soft-launch dashboards.
AnalyticsService.Events = table.freeze({
	JoinLobby = "JoinLobby",
	Ready = "Ready",
	RosterLock = "RosterLock",
	PhaseEnter = "PhaseEnter",
	VoteCast = "VoteCast",
	Rematch = "Rematch",
	TutorialComplete = "TutorialComplete",
	TutorialSkip = "TutorialSkip",
	QuickCampToggle = "QuickCampToggle",
})

return AnalyticsService
