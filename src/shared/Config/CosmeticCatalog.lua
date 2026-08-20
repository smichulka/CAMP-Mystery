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
	-- Optional ISO-week rotation slot (1-based into FEATURED_ROTATION). Cosmetics
	-- without a slot can still appear via the shared weekly rotation helper.
	featuredWeek: number?,
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
		featuredWeek = 1,
	},
	-- Camper styles drawn from reference images
	{
		id = "outfit-teal-classic",
		displayName = "Teal Classic",
		category = "Outfit",
		unlockKind = "CampTokens",
		unlockAmount = 120,
		featuredWeek = 2,
	},
	{
		id = "outfit-glitter-bow",
		displayName = "Glitter Bow",
		category = "Outfit",
		unlockKind = "CampTokens",
		unlockAmount = 180,
		featuredWeek = 3,
	},
	{
		id = "outfit-denim-overalls",
		displayName = "Denim Overalls",
		category = "Outfit",
		unlockKind = "CampTokens",
		unlockAmount = 150,
		featuredWeek = 4,
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
		featuredWeek = 5,
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
		featuredWeek = 6,
	},
	{
		id = "outfit-green-hoodie-cap",
		displayName = "Hoodie Cap",
		category = "Outfit",
		unlockKind = "CampTokens",
		unlockAmount = 130,
		featuredWeek = 7,
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
		featuredWeek = 8,
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
		featuredWeek = 9,
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
		featuredWeek = 10,
	},
}

-- Weekly featured rotation (camp-token cosmetics only). Index by UTC week.
local FEATURED_ROTATION: { string } = {
	"outfit-night-watch",
	"outfit-teal-classic",
	"outfit-glitter-bow",
	"outfit-denim-overalls",
	"outfit-cat-onesie",
	"outfit-flannel-headphones",
	"outfit-green-hoodie-cap",
	"title-night-owl",
	"emote-campfire-story",
	"emote-ghost-float",
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

-- UTC week index since Unix epoch (Mon-start approximation via day-of-year/7).
local function getUtcWeekIndex(unixTime: number?): number
	local stamp = if typeof(unixTime) == "number" then unixTime else os.time()
	local date = os.date("!*t", stamp) :: { yday: number, year: number }
	local yearDay = date.yday
	local weekOfYear = math.floor((yearDay - 1) / 7) + 1
	return date.year * 100 + weekOfYear
end

local function getFeaturedCosmeticId(weekIndex: number?): string
	local index = weekIndex or getUtcWeekIndex()
	local slot = ((index - 1) % #FEATURED_ROTATION) + 1
	return FEATURED_ROTATION[slot]
end

local function isFeatured(cosmeticId: string, weekIndex: number?): boolean
	return getFeaturedCosmeticId(weekIndex) == cosmeticId
end

local function getTokenPrice(
	definition: CosmeticDefinition,
	discountFraction: number,
	weekIndex: number?
): number
	if definition.unlockKind ~= "CampTokens" then
		return definition.unlockAmount
	end
	local price = definition.unlockAmount
	if isFeatured(definition.id, weekIndex) and discountFraction > 0 then
		price = math.max(1, math.floor(price * (1 - discountFraction) + 0.5))
	end
	return price
end

return table.freeze({
	definitions = table.freeze(definitions),
	byId = table.freeze(byId),
	defaultIds = table.freeze(defaultIds),
	defaultEquipped = table.freeze(defaultEquipped),
	featuredRotation = table.freeze(FEATURED_ROTATION),
	GetUtcWeekIndex = getUtcWeekIndex,
	GetFeaturedCosmeticId = getFeaturedCosmeticId,
	IsFeatured = isFeatured,
	GetTokenPrice = getTokenPrice,
})
