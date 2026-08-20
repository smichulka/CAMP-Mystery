--!strict

local UserInputService = game:GetService("UserInputService")

local KeybindHints = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("KeybindHints")
)

export type DayOutcomes = {
	generator: boolean?,
	firewood: boolean?,
	supplies: boolean?,
}

local MissionView = {}

function MissionView.KeybindLine(phase: string): string
	local hints = KeybindHints[phase]
	if not hints then
		return ""
	end
	local useGamepad = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled
	local list = if useGamepad then hints.controller else hints.keyboard
	if #list == 0 then
		return ""
	end
	return table.concat(list, "  •  ")
end

function MissionView.ApplyKeybindLabel(label: TextLabel?, phase: string)
	if not label then
		return
	end
	local line = MissionView.KeybindLine(phase)
	label.Text = line
	label.Visible = line ~= ""
end

-- Loud mid-day copy: every camper should feel that generator / firewood /
-- supplies change what night will feel like.
function MissionView.DayProgressCopy(
	objectivesDone: number,
	objectiveGoal: number,
	witnessFound: number,
	witnessTotal: number,
	roleTone: string
): (string, string)
	local progress = string.format(
		"Camp work %d/%d  |  Witnesses %d/%d  — night stakes: lights · fire · gear",
		objectivesDone,
		objectiveGoal,
		witnessFound,
		witnessTotal
	)
	local header = if roleTone == "Murderer"
		then "DAY COVER"
		elseif roleTone == "Ghost" then "OBSERVING"
		elseif roleTone == "Spectator" then "OBSERVING"
		else "DAY OBJECTIVE"
	local body = if roleTone == "Murderer"
		then string.format(
			"%s\nCamp work: %d of %d. Witnesses: %d of %d.\nGenerator = lights. Firewood = haven. Supplies = flares. Act natural.",
			header,
			objectivesDone,
			objectiveGoal,
			witnessFound,
			witnessTotal
		)
		elseif roleTone == "Ghost" then string.format(
			"%s\nYou are a ghost. Camp work: %d of %d. Witnesses: %d of %d.\nWatch whether lights, fire, and supplies get secured.",
			header,
			objectivesDone,
			objectiveGoal,
			witnessFound,
			witnessTotal
		)
		elseif roleTone == "Spectator" then string.format(
			"%s\nCamp work: %d of %d. Witnesses: %d of %d.\nGenerator, firewood, and supplies decide tonight's danger.",
			header,
			objectivesDone,
			objectiveGoal,
			witnessFound,
			witnessTotal
		)
		else string.format(
			"%s\nCamp work: %d of %d — Generator (lights), Firewood (haven), Supplies (flares).\nInterview witnesses: %d of %d",
			header,
			objectivesDone,
			objectiveGoal,
			witnessFound,
			witnessTotal
		)
	return progress, body
end

function MissionView.ReadDayOutcomes(round: any): DayOutcomes?
	if type(round) ~= "table" then
		return nil
	end
	local raw = round.dayOutcomes
	if type(raw) ~= "table" then
		return nil
	end
	return {
		generator = raw.generator == true,
		firewood = raw.firewood == true,
		supplies = raw.supplies == true,
	}
end

function MissionView.NightPayoffLines(outcomes: DayOutcomes?): (string, string, string)
	local generatorOn = outcomes ~= nil and outcomes.generator == true
	local firewoodOn = outcomes ~= nil and outcomes.firewood == true
	local suppliesOn = outcomes ~= nil and outcomes.supplies == true
	local generatorLine = if generatorOn
		then "GENERATOR ON — camp lights stay lit."
		else "GENERATOR DEAD — darkness owns the paths."
	local firewoodLine = if firewoodOn
		then "FIREWOOD STOCKED — campfire is a safe haven."
		else "FIREWOOD MISSING — even the campfire is not safe."
	local suppliesLine = if suppliesOn
		then "SUPPLIES SECURED — every camper got a bonus flare."
		else "SUPPLIES UNSECURED — no extra gear tonight."
	return generatorLine, firewoodLine, suppliesLine
end

function MissionView.NightPayoffCopy(outcomes: DayOutcomes?, roleTone: string): (string, string)
	local generatorLine, firewoodLine, suppliesLine = MissionView.NightPayoffLines(outcomes)
	local progress = table.concat({ generatorLine, firewoodLine, suppliesLine }, "  ")
	local header = if roleTone == "Murderer"
		then "YOU ARE THE MONSTER"
		elseif roleTone == "Ghost" then "OBSERVING"
		elseif roleTone == "Spectator" then "OBSERVING"
		else "NIGHT PAYOFF"
	local body = if roleTone == "Murderer"
		then string.format(
			"%s\nDay work locked in:\n%s\n%s\n%s\nHunt in the gaps they left open.",
			header,
			generatorLine,
			firewoodLine,
			suppliesLine
		)
		elseif roleTone == "Ghost" or roleTone == "Spectator" then string.format(
			"%s\nDay work decided the night:\n%s\n%s\n%s",
			header,
			generatorLine,
			firewoodLine,
			suppliesLine
		)
		else string.format(
			"%s\n%s\n%s\n%s\nStay close — isolation is how the monster wins.",
			header,
			generatorLine,
			firewoodLine,
			suppliesLine
		)
	return progress, body
end

return MissionView
