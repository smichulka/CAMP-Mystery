--!strict

-- Per-monster positional hunt-loop audio.
--
-- Each entry becomes the SoundService attribute "MonsterHunt<Id>AssetId",
-- which CharacterAssetService reads when the monster spawns at night: a
-- non-zero value plays that asset as a looped 3D sound on the monster.
--
-- 0 = slot stays silent. To pick a sound: open the Toolbox in Studio
-- (View -> Toolbox -> Audio), search e.g. "creature growl loop", press play
-- to audition, then paste the asset id here. Attributes already set on
-- SoundService in the place override these values, so live experiments in
-- Studio win over this file until you clear them.
local MonsterAudioConfig: { [string]: number } = {
	BabyAlien = 0,
	Screamer = 0,
	Wendigo = 0,
	ShadowMonster = 0,
	Chupacabra = 0,
	Dullahan = 0,
	Entity = 0,
	Banshee = 0,
}

return table.freeze(MonsterAudioConfig)
