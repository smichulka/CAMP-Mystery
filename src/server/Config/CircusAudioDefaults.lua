--!strict

-- Default audio for the Spooky Circus (Map/SpookyCircus.lua). Same contract
-- as MonsterAudioDefaults/WorldAudioDefaults: content ids live HERE as data,
-- never as literals in service code, and every cue resolves as
--   SoundService attribute ("Circus<Slot>AssetId") -> this default -> silent.
--
-- Client AudioController owns separate FairgroundsAmbienceAssetId /
-- CircusStingAssetId slots (nil placeholders) for phase overlays; those are
-- not listed here — world-spatial Calliope/carnie cues stay server-side.
--
-- Calliope is APM Music's "My Carrousel"; the effects are Pro Sound Effects
-- (both verified Creator Store libraries, free — the same licensing class as
-- the monster hunt loops). Override any slot live via SoundService
-- attributes when tuning.
return table.freeze({
	Calliope = "rbxassetid://1835966604", -- APM "My Carrousel": warped fairground organ
	TicketChime = "rbxassetid://9114132512", -- PSE "Door Chime 10": music-box single tone
	CarnieScreech = "rbxassetid://9114628620", -- PSE "Goliath Vocal 21": throaty wrong-voice rumble
	BarkerCall = "rbxassetid://9114630281", -- PSE "Goliath Vocal 46": mumbled nonsense, distant barker
})
