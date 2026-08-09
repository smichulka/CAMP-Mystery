--!strict

export type CosmeticCategory = "Outfit" | "Title" | "Emote"
-- "Streak": granted automatically when the daily play streak reaches
-- unlockAmount consecutive days (never purchasable).
export type UnlockKind = "Default" | "CampTokens" | "Level" | "Streak"

export type CosmeticDefinition = {
	id: string,
	displayName: string,
	category: CosmeticCategory,
	unlockKind: UnlockKind,
	unlockAmount: number,
}

local definitions: { CosmeticDefinition } = {
	-- ── Outfits ──────────────────────────────────────────────────────────────
	{
		id = "outfit-camp-standard",
		displayName = "Camp Standard",
		category = "Outfit",
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
	-- Camper styles drawn from reference images
	{
		id = "outfit-teal-classic",
		displayName = "Teal Classic",
		category = "Outfit",
		unlockKind = "CampTokens",
		unlockAmount = 120,
	},
	{
		id = "outfit-glitter-bow",
		displayName = "Glitter Bow",
		category = "Outfit",
		unlockKind = "CampTokens",
		unlockAmount = 180,
	},
	{
		id = "outfit-denim-overalls",
		displayName = "Denim Overalls",
		category = "Outfit",
		unlockKind = "CampTokens",
		unlockAmount = 150,
	},
	{
		id = "outfit-frog-hoodie",
		displayName = "Frog Hoodie",
		category = "Outfit",
		unlockKind = "Level",
		unlockAmount = 3,
	},
	{
		id = "outfit-cat-onesie",
		displayName = "Cat Onesie",
		category = "Outfit",
		unlockKind = "CampTokens",
		unlockAmount = 200,
	},
	{
		id = "outfit-axolotl-hat",
		displayName = "Axolotl Explorer",
		category = "Outfit",
		unlockKind = "Level",
		unlockAmount = 6,
	},
	{
		id = "outfit-flannel-headphones",
		displayName = "Flannel & Phones",
		category = "Outfit",
		unlockKind = "CampTokens",
		unlockAmount = 175,
	},
	{
		id = "outfit-green-hoodie-cap",
		displayName = "Hoodie Cap",
		category = "Outfit",
		unlockKind = "CampTokens",
		unlockAmount = 130,
	},
	{
		id = "outfit-creeper",
		displayName = "Pixel Creeper",
		category = "Outfit",
		unlockKind = "Level",
		unlockAmount = 10,
	},
	{
		id = "outfit-holo-visor",
		displayName = "Holo Visor",
		category = "Outfit",
		unlockKind = "Level",
		unlockAmount = 8,
	},
	-- ── Titles ───────────────────────────────────────────────────────────────
	{
		id = "title-new-arrival",
		displayName = "New Arrival",
		category = "Title",
		unlockKind = "Default",
		unlockAmount = 0,
	},
	{
		id = "title-clue-finder",
		displayName = "Clue Finder",
		category = "Title",
		unlockKind = "Level",
		unlockAmount = 5,
	},
	{
		id = "title-monster-hunter",
		displayName = "Monster Hunter",
		category = "Title",
		unlockKind = "Level",
		unlockAmount = 12,
	},
	{
		id = "title-night-owl",
		displayName = "Night Owl",
		category = "Title",
		unlockKind = "CampTokens",
		unlockAmount = 300,
	},
	{
		id = "title-camp-legend",
		displayName = "Camp Legend",
		category = "Title",
		unlockKind = "Level",
		unlockAmount = 20,
	},
	{
		id = "title-regular-camper",
		displayName = "Regular Camper",
		category = "Title",
		unlockKind = "Streak",
		unlockAmount = 3,
	},
	{
		id = "title-week-one-legend",
		displayName = "Week One Legend",
		category = "Title",
		unlockKind = "Streak",
		unlockAmount = 7,
	},
	-- ── Emotes ───────────────────────────────────────────────────────────────
	{
		id = "emote-wave",
		displayName = "Wave",
		category = "Emote",
		unlockKind = "Default",
		unlockAmount = 0,
	},
	{
		id = "emote-campfire-story",
		displayName = "Campfire Story",
		category = "Emote",
		unlockKind = "CampTokens",
		unlockAmount = 150,
	},
	{
		id = "emote-frog-jump",
		displayName = "Frog Jump",
		category = "Emote",
		unlockKind = "Level",
		unlockAmount = 4,
	},
	{
		id = "emote-ghost-float",
		displayName = "Ghost Float",
		category = "Emote",
		unlockKind = "CampTokens",
		unlockAmount = 220,
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
