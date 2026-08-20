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
-- supplies change what night will feel like. Midway Festival is an optional
-- day detour (fair supplies / popcorn) beside the core camp work.
function MissionView.DayProgressCopy(
	objectivesDone: number,
	objectiveGoal: number,
	witnessFound: number,
	witnessTotal: number,
	roleTone: string
): (string, string)
	local progress = string.format(
		"Camp work %d/%d  |  Witnesses %d/%d  — night stakes: lights · fire · gear  ·  Midway Festival open",
		objectivesDone,
		objectiveGoal,
		witnessFound,
		witnessTotal
	)
	local header = if roleTone == "Murderer"
		then "DAY COVER"
		elseif roleTone == "Ghost" then "GHOST OBJECTIVE"
		elseif roleTone == "Spectator" then "OBSERVING"
		else "DAY OBJECTIVE"
	local body = if roleTone == "Murderer"
		then string.format(
			"%s\nCamp work: %d of %d. Witnesses: %d of %d.\nGenerator = lights. Firewood = haven. Supplies = flares. Act natural.\nMidway Festival is optional cover — fair supplies or popcorn if you wander northeast.",
			header,
			objectivesDone,
			objectiveGoal,
			witnessFound,
			witnessTotal
		)
		elseif roleTone == "Ghost" then string.format(
			"%s\n%s\nCamp work: %d of %d. Witnesses: %d of %d.\nWatch whether lights, fire, and supplies get secured.\nMidway Festival stays open by day — fair supplies and popcorn are optional side work.",
			header,
			MissionView.GhostAgencyStrip("Camper"),
			objectivesDone,
			objectiveGoal,
			witnessFound,
			witnessTotal
		)
		elseif roleTone == "Spectator" then string.format(
			"%s\nCamp work: %d of %d. Witnesses: %d of %d.\nGenerator, firewood, and supplies decide tonight's danger.\nMidway Festival (northeast) offers optional fair-supplies and popcorn restock.",
			header,
			objectivesDone,
			objectiveGoal,
			witnessFound,
			witnessTotal
		)
		else string.format(
			"%s\nCamp work: %d of %d — Generator (lights), Firewood (haven), Supplies (flares).\nInterview witnesses: %d of %d\nMidway Festival (northeast): check fair supplies or restock popcorn before dusk.",
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
		elseif roleTone == "Ghost" then "GHOST OBJECTIVE"
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
		elseif roleTone == "Ghost" then string.format(
			"%s\n%s\nDay work decided the night:\n%s\n%s\n%s",
			header,
			MissionView.GhostAgencyStrip("Camper"),
			generatorLine,
			firewoodLine,
			suppliesLine
		)
		elseif roleTone == "Spectator" then string.format(
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

-- Persistent ghost duty line: help camp / protect / observe.
function MissionView.GhostAgencyStrip(role: string): string
	if role == "Protector" then
		return "GHOST DUTY  ·  Help camp  ·  Protect  ·  Observe"
	end
	return "GHOST DUTY  ·  Help camp  ·  Observe"
end

-- Haunt / cold-spot / vigil progress from RuntimeTypes.GhostSnapshot.
function MissionView.GhostSnapshotProgress(ghost: any?): string
	if type(ghost) ~= "table" then
		return "Fill haunt energy: cold spot · vigil · echo"
	end
	local meter = if type(ghost.hauntMeter) == "number" then ghost.hauntMeter else 0
	local maximum = if type(ghost.hauntMeterMax) == "number" and ghost.hauntMeterMax > 0
		then ghost.hauntMeterMax
		else 100
	local fraction = math.clamp(meter / maximum, 0, 1)
	local cold = if type(ghost.coldSpotSeconds) == "number" then ghost.coldSpotSeconds else 0
	local coldGoal = if type(ghost.coldSpotGoalSeconds) == "number" and ghost.coldSpotGoalSeconds > 0
		then ghost.coldSpotGoalSeconds
		else 10
	local vigil = if type(ghost.vigilSeconds) == "number" then ghost.vigilSeconds else 0
	local vigilGoal = if type(ghost.vigilGoalSeconds) == "number" and ghost.vigilGoalSeconds > 0
		then ghost.vigilGoalSeconds
		else 20
	local done = if type(ghost.objectivesCompleted) == "number" then ghost.objectivesCompleted else 0
	if ghost.hauntReady == true then
		return string.format(
			"HAUNT READY  ·  Deeds %d  ·  Cold %.0f/%.0fs  ·  Vigil %.0f/%.0fs",
			done,
			cold,
			coldGoal,
			vigil,
			vigilGoal
		)
	end
	return string.format(
		"Haunt %d%%  ·  Deeds %d  ·  Cold %.0f/%.0fs  ·  Vigil %.0f/%.0fs",
		math.floor(fraction * 100 + 0.5),
		done,
		cold,
		coldGoal,
		vigil,
		vigilGoal
	)
end

-- Mission panel copy for ghosts. Prefer GhostSnapshot when Investigation.
function MissionView.GhostMissionCopy(
	ghost: any?,
	role: string,
	phase: string
): (string, string)
	local strip = MissionView.GhostAgencyStrip(role)
	local progress = MissionView.GhostSnapshotProgress(ghost)
	if phase == "Investigation" then
		local body = if role == "Protector"
			then string.format(
				"GHOST OBJECTIVE\n%s\nShadow the hunt. Ward a living camper once if you still can.\n%s",
				strip,
				progress
			)
			else string.format(
				"GHOST OBJECTIVE\n%s\nCold-spot the monster, hold vigil near survivors, then haunt.\n%s",
				strip,
				progress
			)
		return progress, body
	end
	if phase == "Campfire" then
		return progress, string.format(
			"GHOST OBJECTIVE\n%s\nWatch the vote. Call out what you saw during the hunt.",
			strip
		)
	end
	if phase == "Day" then
		return progress, string.format(
			"GHOST OBJECTIVE\n%s\nWatch whether lights, fire, and supplies get secured.",
			strip
		)
	end
	if phase == "MurderPlanning" or phase == "NightTransform" then
		return progress, string.format(
			"GHOST OBJECTIVE\n%s\nNight is coming — stay useful when the hunt begins.",
			strip
		)
	end
	return progress, string.format(
		"GHOST OBJECTIVE\n%s\nDeath is not the end of your usefulness.",
		strip
	)
end

return MissionView
