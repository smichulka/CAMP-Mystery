--!strict

-- Default positional hunt-loop audio per monster. Every entry is a free
-- Pro Sound Effects pick from the Creator Store, matched to the monster's
-- fiction and verified loading in-boot (2026-08-09). The SoundService
-- attribute "MonsterHunt<Id>AssetId" overrides any slot at runtime, so
-- final authored audio drops in with no code changes.
--
-- CharacterAssetService deliberately contains no literal asset ids (its
-- release contract keeps authored content optional), which is why these
-- live here as data.

local MonsterAudioDefaults: { [string]: string } = {
	BabyAlien = "rbxassetid://9118060631", -- rat squeaks: skittering hisses
	Screamer = "rbxassetid://9114170094", -- reverberant screeching wails
	Wendigo = "rbxassetid://9125842137", -- deep guttural growling
	ShadowMonster = "rbxassetid://9113324097", -- hollow basement-wind drone
	Chupacabra = "rbxassetid://9113956718", -- coyote yelps and whines
	Dullahan = "rbxassetid://9120013312", -- slowed airy thunder whomps
	Entity = "rbxassetid://9114169982", -- whispering pass-bys and wails
	Banshee = "rbxassetid://9120052030", -- sustained pack howling
}

return table.freeze(MonsterAudioDefaults)
