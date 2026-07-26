--!strict

export type UISoundEvent =
	"hover"
	| "click"
	| "open"
	| "close"
	| "toast"
	| "error"
	| "success"
	| "page-turn"
	| "stamp"
	| "vote"
	| "phase-sting"

export type UISoundDefinition = {
	name: string,
	attribute: string,
	defaultAssetId: string?,
	sourceUrl: string?,
}

local EVENT_TO_CUE: { [string]: string } = {
	hover = "UIHover",
	click = "UIClick",
	open = "UIOpen",
	close = "UIClose",
	toast = "UIToast",
	error = "UIError",
	success = "UISuccess",
	["page-turn"] = "UIPageTurn",
	stamp = "UIStamp",
	vote = "VoteOpen",
	["phase-sting"] = "PhaseChime",
}

-- VoteOpen and PhaseChime are already registered by AudioController and are not
-- duplicated in DEFINITIONS here.
-- These are temporary Creator Store sounds, not final authored CAMP-Mystery audio.
-- Nil defaults intentionally stay silent until an approved asset is supplied through
-- the matching SoundService attribute.
local DEFINITIONS: { UISoundDefinition } = {
	{
		name = "UIHover",
		attribute = "UIHoverAssetId",
		defaultAssetId = "rbxassetid://10066931761",
		sourceUrl = "https://create.roblox.com/store/asset/10066931761/RBLX-UI-Hover-01-SFX",
	},
	{
		name = "UIClick",
		attribute = "UIClickAssetId",
		defaultAssetId = "rbxassetid://876939830",
		sourceUrl = "https://create.roblox.com/store/asset/876939830/Click-Sound",
	},
	{
		name = "UIOpen",
		attribute = "UIOpenAssetId",
		defaultAssetId = "rbxassetid://9126110622",
		sourceUrl = "https://create.roblox.com/store/asset/9126110622/Tonal-Click-Blurp-Tone-Slightly-Metallic-Swi-SFX",
	},
	{
		name = "UIClose",
		attribute = "UICloseAssetId",
		defaultAssetId = "rbxassetid://876939830",
		sourceUrl = "https://create.roblox.com/store/asset/876939830/Click-Sound",
	},
	{
		name = "UIToast",
		attribute = "UIToastAssetId",
		defaultAssetId = "rbxassetid://9119846112",
		sourceUrl = "https://create.roblox.com/store/asset/9119846112/Synth-Tone-High-Pitch-Rizzy-Waa-Tone-3-SFX",
	},
	{
		name = "UIError",
		attribute = "UIErrorAssetId",
		defaultAssetId = "rbxassetid://9125387654", -- verify in Studio
		sourceUrl = "https://create.roblox.com/store/asset/9125387654/Beeps-High-Pitch-Fast-Short-Bursts-Noisy-Buz-SFX",
	},
	{
		name = "UISuccess",
		attribute = "UISuccessAssetId",
		defaultAssetId = "rbxassetid://9119802003", -- verify in Studio
		sourceUrl = "https://create.roblox.com/store/asset/9119802003/Synth-Chime-Single-Synth-Tone-1-SFX",
	},
	{
		name = "UIPageTurn",
		attribute = "UIPageTurnAssetId",
		defaultAssetId = "rbxassetid://9113841825", -- verify in Studio
		sourceUrl = "https://create.roblox.com/store/asset/9113841825/Cloth-Whooshes-Sharp-Whooshes-21-SFX",
	},
	{
		name = "UIStamp",
		attribute = "UIStampAssetId",
		defaultAssetId = "rbxassetid://9113964719", -- verify in Studio
		sourceUrl = "https://create.roblox.com/store/asset/9113964719/Cracky-Punch-1-SFX",
	},
}

local UISoundMap = {}

UISoundMap.Definitions = table.freeze(DEFINITIONS)
UISoundMap.Events = table.freeze(EVENT_TO_CUE)

function UISoundMap.Resolve(eventName: string): string?
	return EVENT_TO_CUE[eventName]
end

return table.freeze(UISoundMap)
