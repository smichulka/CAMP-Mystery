--!strict

-- Seeded round weather. Each round derives one WeatherId from the world round
-- seed, so every server (and every replay of the same seed) agrees on the sky.
-- All gameplay and visual knobs live here so weather stays tunable without
-- touching the services that consume it.

export type WeatherId = "Clear" | "Fog" | "Rain" | "Storm" | "BloodMoon"

export type WeatherDefinition = {
	id: WeatherId,
	displayName: string,
	-- Selection weight out of WeatherConfig.totalWeight.
	weight: number,

	-- Announcement copy. Day is the reveal; dusk is the reinforcement
	-- (BloodMoon's dusk line is the dramatic one).
	dayKind: string,
	dayTitle: string,
	dayMessage: string,
	duskKind: string,
	duskTitle: string,
	duskMessage: string,

	-- Visual multipliers, applied by ProductionMapService at both day and
	-- night. Fog values stack multiplicatively with the generator-powered
	-- night fog logic, so a repaired generator still helps in the mist.
	atmosphereDensityMultiplier: number,
	fogStartMultiplier: number,
	fogEndMultiplier: number,
	brightnessMultiplier: number,
	ambientMultiplier: number,
	rainEnabled: boolean,
	rainRate: number,
	lightningEnabled: boolean,
	lightningMinSeconds: number,
	lightningMaxSeconds: number,
	-- BloodMoon-style overrides; nil keeps the standard night palette.
	nightAmbientOverride: Color3?,
	nightOutdoorAmbientOverride: Color3?,
	nightFogColorOverride: Color3?,
	nightAtmosphereColorOverride: Color3?,
	nightAtmosphereDecayOverride: Color3?,
	nightTintOverride: Color3?,

	-- Gameplay modifiers (server-side).
	-- monsterRangeMultiplier scales monster ability rangeStuds: rain muffles
	-- footsteps (harder to hear) and fog shortens sight lines.
	monsterRangeMultiplier: number,
	-- monsterCooldownMultiplier scales monster ability cooldowns; mobility
	-- abilities ARE the monster's movement, so < 1 reads as a faster monster.
	monsterCooldownMultiplier: number,
	-- evidenceHoldMultiplier scales the search prompt hold duration and
	-- evidenceGlowBoost brightens the search glow (Blood Moon urgency).
	evidenceHoldMultiplier: number,
	evidenceGlowBoost: boolean,
	-- Round rewards get scaled by this (clamped in RewardCalculation).
	rewardMultiplier: number,
}

local SEED_MODULUS = 2_147_483_647
local WEATHER_SEED_SALT = 91_193

local function normalizeSeed(seed: number): number
	assert(seed == seed and math.abs(seed) < math.huge, "Weather seed must be finite")
	assert(seed % 1 == 0, "Weather seed must be a whole number")
	local normalized = seed % SEED_MODULUS
	if normalized < 0 then
		normalized += SEED_MODULUS
	end
	return normalized
end

local function deriveSeed(roundId: number, roundSeed: number): number
	return normalizeSeed(roundSeed + roundId * 104_729 + WEATHER_SEED_SALT)
end

local function definition(entry: WeatherDefinition): WeatherDefinition
	return table.freeze(entry)
end

local byId: { [WeatherId]: WeatherDefinition } = {
	Clear = definition({
		id = "Clear",
		displayName = "Clear Skies",
		weight = 40,
		dayKind = "Info",
		dayTitle = "Clear skies over camp",
		dayMessage = "A bright, open day. Finish the camp work while the light lasts.",
		duskKind = "Info",
		duskTitle = "A calm, clear dusk",
		duskMessage = "The stars are out. It almost feels safe. Almost.",
		atmosphereDensityMultiplier = 1,
		fogStartMultiplier = 1,
		fogEndMultiplier = 1,
		brightnessMultiplier = 1,
		ambientMultiplier = 1,
		rainEnabled = false,
		rainRate = 0,
		lightningEnabled = false,
		lightningMinSeconds = 0,
		lightningMaxSeconds = 0,
		nightAmbientOverride = nil,
		nightOutdoorAmbientOverride = nil,
		nightFogColorOverride = nil,
		nightAtmosphereColorOverride = nil,
		nightAtmosphereDecayOverride = nil,
		nightTintOverride = nil,
		monsterRangeMultiplier = 1,
		monsterCooldownMultiplier = 1,
		evidenceHoldMultiplier = 1,
		evidenceGlowBoost = false,
		rewardMultiplier = 1,
	}),
	Fog = definition({
		id = "Fog",
		displayName = "Rolling Fog",
		weight = 25,
		dayKind = "Info",
		dayTitle = "Fog rolls over camp",
		dayMessage = "A thick mist hangs between the cabins. Keep your buddies close.",
		duskKind = "Warning",
		duskTitle = "The fog thickens",
		duskMessage = "Shapes fade a few steps out. Whatever hunts tonight hunts half-blind too.",
		atmosphereDensityMultiplier = 1.45,
		fogStartMultiplier = 0.55,
		fogEndMultiplier = 0.6,
		brightnessMultiplier = 0.92,
		ambientMultiplier = 0.9,
		rainEnabled = false,
		rainRate = 0,
		lightningEnabled = false,
		lightningMinSeconds = 0,
		lightningMaxSeconds = 0,
		nightAmbientOverride = nil,
		nightOutdoorAmbientOverride = nil,
		nightFogColorOverride = nil,
		nightAtmosphereColorOverride = nil,
		nightAtmosphereDecayOverride = nil,
		nightTintOverride = nil,
		-- Monster sight lines are shorter in the mist.
		monsterRangeMultiplier = 0.85,
		monsterCooldownMultiplier = 1,
		evidenceHoldMultiplier = 1,
		evidenceGlowBoost = false,
		rewardMultiplier = 1,
	}),
	Rain = definition({
		id = "Rain",
		displayName = "Steady Rain",
		weight = 20,
		dayKind = "Info",
		dayTitle = "Grey clouds gather over camp",
		dayMessage = "Steady rain patters on the cabin roofs. The trails are getting muddy.",
		duskKind = "Warning",
		duskTitle = "Rain into the night",
		duskMessage = "The rain drowns out footsteps — yours, and everything else's.",
		atmosphereDensityMultiplier = 1.2,
		fogStartMultiplier = 0.8,
		fogEndMultiplier = 0.8,
		brightnessMultiplier = 0.85,
		ambientMultiplier = 0.82,
		rainEnabled = true,
		rainRate = 240,
		lightningEnabled = false,
		lightningMinSeconds = 0,
		lightningMaxSeconds = 0,
		nightAmbientOverride = nil,
		nightOutdoorAmbientOverride = nil,
		nightFogColorOverride = nil,
		nightAtmosphereColorOverride = nil,
		nightAtmosphereDecayOverride = nil,
		nightTintOverride = nil,
		-- Rain muffles sound: the monster hears campers ~20% less far.
		monsterRangeMultiplier = 0.8,
		monsterCooldownMultiplier = 1,
		evidenceHoldMultiplier = 1,
		evidenceGlowBoost = false,
		rewardMultiplier = 1,
	}),
	Storm = definition({
		id = "Storm",
		displayName = "Thunderstorm",
		weight = 10,
		dayKind = "Warning",
		dayTitle = "A storm builds over the lake",
		dayMessage = "Thunder rumbles past the water tower. Tonight will be loud and dark.",
		duskKind = "Warning",
		duskTitle = "The storm breaks",
		duskMessage = "Lightning claws at the sky. At least the thunder hides your footsteps.",
		atmosphereDensityMultiplier = 1.3,
		fogStartMultiplier = 0.7,
		fogEndMultiplier = 0.72,
		brightnessMultiplier = 0.78,
		ambientMultiplier = 0.75,
		rainEnabled = true,
		rainRate = 340,
		lightningEnabled = true,
		lightningMinSeconds = 9,
		lightningMaxSeconds = 22,
		nightAmbientOverride = nil,
		nightOutdoorAmbientOverride = nil,
		nightFogColorOverride = nil,
		nightAtmosphereColorOverride = nil,
		nightAtmosphereDecayOverride = nil,
		nightTintOverride = nil,
		monsterRangeMultiplier = 0.8,
		monsterCooldownMultiplier = 1,
		evidenceHoldMultiplier = 1,
		evidenceGlowBoost = false,
		rewardMultiplier = 1,
	}),
	BloodMoon = definition({
		id = "BloodMoon",
		displayName = "Blood Moon",
		weight = 5,
		dayKind = "Warning",
		dayTitle = "The air feels wrong today",
		dayMessage = "The counselors keep glancing at the sky. Finish the camp work early.",
		duskKind = "Danger",
		duskTitle = "A BLOOD MOON RISES",
		duskMessage = "The sky burns red. The monster is faster tonight — but clues shine brighter, and heroes earn more.",
		atmosphereDensityMultiplier = 1.1,
		fogStartMultiplier = 0.9,
		fogEndMultiplier = 0.9,
		brightnessMultiplier = 1,
		ambientMultiplier = 1,
		rainEnabled = false,
		rainRate = 0,
		lightningEnabled = false,
		lightningMinSeconds = 0,
		lightningMaxSeconds = 0,
		nightAmbientOverride = Color3.fromRGB(112, 44, 48),
		nightOutdoorAmbientOverride = Color3.fromRGB(136, 52, 56),
		nightFogColorOverride = Color3.fromRGB(98, 40, 44),
		nightAtmosphereColorOverride = Color3.fromRGB(170, 74, 74),
		nightAtmosphereDecayOverride = Color3.fromRGB(90, 32, 34),
		nightTintOverride = Color3.fromRGB(255, 196, 192),
		monsterRangeMultiplier = 1,
		-- Mobility cooldowns ~15% shorter: the monster closes distance faster.
		monsterCooldownMultiplier = 0.85,
		-- Evidence searches complete ~25% faster and glow brighter.
		evidenceHoldMultiplier = 0.75,
		evidenceGlowBoost = true,
		rewardMultiplier = 1.25,
	}),
}

-- Deterministic iteration order for weighted selection (never iterate the
-- dictionary — hash order is not stable).
local order: { WeatherId } = table.freeze({
	"Clear" :: WeatherId,
	"Fog" :: WeatherId,
	"Rain" :: WeatherId,
	"Storm" :: WeatherId,
	"BloodMoon" :: WeatherId,
})

local totalWeight = 0
for _, weatherId in order do
	totalWeight += byId[weatherId].weight
end

local WeatherConfig = {}
WeatherConfig.byId = table.freeze(byId)
WeatherConfig.order = order
WeatherConfig.totalWeight = totalWeight

function WeatherConfig.Get(weatherId: string?): WeatherDefinition
	local resolved = if weatherId then byId[weatherId :: WeatherId] else nil
	return resolved or byId.Clear
end

function WeatherConfig.DeriveSeed(roundId: number, roundSeed: number): number
	return deriveSeed(roundId, roundSeed)
end

function WeatherConfig.SelectForRound(roundId: number, roundSeed: number): WeatherId
	local roll = deriveSeed(roundId, roundSeed) % totalWeight
	local accumulated = 0
	for _, weatherId in order do
		accumulated += byId[weatherId].weight
		if roll < accumulated then
			return weatherId
		end
	end
	return "Clear"
end

return table.freeze(WeatherConfig)
