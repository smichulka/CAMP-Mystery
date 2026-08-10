--!strict

-- Default world-interaction audio. Same contract as MonsterAudioDefaults:
-- free Pro Sound Effects picks from the Creator Store, and a SoundService
-- attribute ("World<Slot>AssetId", e.g. "WorldDoorSwingAssetId") overrides
-- any slot at runtime so final authored audio drops in with no code changes.
-- Unset override + missing default leaves the cue silent rather than erroring.

local WorldAudioDefaults: { [string]: string } = {
	-- Door Creak 1 (SFX): "Door Creak, Open and Close", 2.3s. Played by
	-- every hinged/interactive door in the world (2026-08-09 UX pass — all
	-- 50+ doors swung silently).
	DoorSwing = "rbxassetid://9114135682",
}

return table.freeze(WorldAudioDefaults)
