--!strict

-- Default audio for the Spooky Circus (Map/SpookyCircus.lua). Same contract
-- as MonsterAudioDefaults/WorldAudioDefaults: content ids live HERE as data,
-- never as literals in service code, and every cue resolves as
--   SoundService attribute ("Circus<Slot>AssetId") -> this default -> silent.
--
-- Calliope is APM Music's "My Carrousel" (verified Creator Store library,
-- free — same licensing class as the Pro Sound Effects ids the monsters
-- use). The remaining slots ship silent until a proper PSE-vocabulary audio
-- pass finds fits; override any of them live via SoundService attributes.
return table.freeze({
	Calliope = "rbxassetid://1835966604", -- APM "My Carrousel": warped fairground organ
	TicketChime = "",
	CarnieScreech = "",
	BarkerCall = "",
})
