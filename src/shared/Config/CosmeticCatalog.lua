--!strict

export type CosmeticCategory = "Outfit" | "Title" | "Emote"
export type UnlockKind = "Default" | "CampTokens" | "Level"

export type CosmeticDefinition = {
	id: string,
	displayName: string,
	category: CosmeticCategory,
	unlockKind: UnlockKind,
	unlockAmount: number,
}

local definitions: { CosmeticDefinition } = {
	{
		id = "outfit-camp-standard",
		displayName = "Camp Standard",
		category = "Outfit",
		unlockKind = "Default",
		unlockAmount = 0,
	},
	{
		id = "title-new-arrival",
		displayName = "New Arrival",
		category = "Title",
		unlockKind = "Default",
		unlockAmount = 0,
	},
	{
		id = "emote-wave",
		displayName = "Wave",
		category = "Emote",
		unlockKind = "Default",
		unlockAmount = 0,
	},
	{
		id = "outfit-night-watch",
		displayName = "Night Watch",
		category = "Outfit",
		unlockKind = "CampTokens",
		unlockAmount = 250,
	},
	{
		id = "title-clue-finder",
		displayName = "Clue Finder",
		category = "Title",
		unlockKind = "Level",
		unlockAmount = 5,
	},
	{
		id = "emote-campfire-story",
		displayName = "Campfire Story",
		category = "Emote",
		unlockKind = "CampTokens",
		unlockAmount = 150,
	},
}

local byId: { [string]: CosmeticDefinition } = {}
local defaultIds: { string } = {}
local defaultEquipped: { [string]: string } = {}

for _, definition in definitions do
	byId[definition.id] = table.freeze(definition)
	if definition.unlockKind == "Default" then
		table.insert(defaultIds, definition.id)
		defaultEquipped[definition.category] = definition.id
	end
end

return table.freeze({
	definitions = table.freeze(definitions),
	byId = table.freeze(byId),
	defaultIds = table.freeze(defaultIds),
	defaultEquipped = table.freeze(defaultEquipped),
})
