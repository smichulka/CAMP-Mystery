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
	-- Cabinet Drawer 7 (SFX): "Open and Close, With Rollers", 1.7s. Every
	-- WorldKit drawer slide (2026-08-10 pass — drawers were silent).
	DrawerSlide = "rbxassetid://9113658569",
	-- Cabinet Doors 9 (SFX): "Open & Close, Wood", 2.3s. Window shutter
	-- panel toggles (same pass — shutters were silent).
	ShutterClack = "rbxassetid://9113657040",
}

return table.freeze(WorldAudioDefaults)
