--!strict

local SoundService = game:GetService("SoundService")

local UISoundMap = require(script.Parent:WaitForChild("UISoundMap"))

export type AudioOptions = {
	onSubtitle: ((text: string, duration: number) -> ())?,
	assetAttributes: { [string]: string }?,
}

type SoundDefinition = {
	name: string,
	channel: string,
	attribute: string,
	looped: boolean,
	subtitle: string?,
	defaultAssetId: string?,
}

type AudioControllerState = {
	root: Folder,
	groups: { [string]: SoundGroup },
	sounds: { [string]: Sound },
	settings: { [string]: any },
	currentMusic: string?,
	lastPhase: string?,
	lastEvidenceFound: number,
	heartbeatIntensity: number,
	activeMonsterId: string?,
	onSubtitle: ((text: string, duration: number) -> ())?,
	destroyed: boolean,
}

local AudioController = {}
AudioController.__index = AudioController

export type AudioController = typeof(setmetatable({} :: AudioControllerState, AudioController))

AudioController.CueIds = table.freeze({
	PhaseChime = "PhaseChime",
	EvidenceFound = "EvidenceFound",
	VoteOpen = "VoteOpen",
	MonsterActive = "MonsterActive",
	Reward = "Reward",
	CircusSting = "CircusSting",
})

-- Cue inventory resolution (strict order, never invent live asset ids here):
--   1) SoundService:GetAttribute(<Slot>AssetId)  — Studio / live override
--   2) definition.defaultAssetId                — repo placeholder (may be nil)
--   3) empty SoundId                            — cue stays silent
--
-- Core music/ambience placeholders below are Creator Store stand-ins until
-- final banks land. Fairgrounds/circus *world* loops live server-side in
-- Map/SpookyCircus.lua via Config/CircusAudioDefaults (attributes
-- CircusCalliopeAssetId, CircusTicketChimeAssetId, CircusCarnieScreechAssetId,
-- CircusBarkerCallAssetId). Client FairgroundsAmbience / CircusSting slots
-- below are optional overlays for phase switches — leave attributes unset
-- until real assets exist (nil default = silent, no fake id).
--
-- Override attributes: LobbyMusicAssetId, CampMusicAssetId, NightMusicAssetId,
-- ResultsMusicAssetId, CampAmbienceAssetId, NightAmbienceAssetId,
-- FairgroundsAmbienceAssetId, PhaseChimeAssetId, EvidenceFoundAssetId,
-- VoteOpenAssetId, MonsterActiveAssetId, RewardAssetId, HeartbeatAssetId,
-- CircusStingAssetId, plus UI click/impact/danger ids via UISoundMap.
local DEFINITIONS: { SoundDefinition } = {
	{
		name = "LobbyMusic",
		channel = "Music",
		attribute = "LobbyMusicAssetId",
		looped = true,
		defaultAssetId = "rbxassetid://1838974004", -- placeholder: replace with final asset
	},
	{
		name = "CampMusic",
		channel = "Music",
		attribute = "CampMusicAssetId",
		looped = true,
		defaultAssetId = "rbxassetid://1836688632", -- placeholder: replace with final asset
	},
	{
		name = "NightMusic",
		channel = "Music",
		attribute = "NightMusicAssetId",
		looped = true,
		defaultAssetId = "rbxassetid://1839908918", -- placeholder: replace with final asset
	},
	{
		name = "ResultsMusic",
		channel = "Music",
		attribute = "ResultsMusicAssetId",
		looped = true,
		defaultAssetId = "rbxassetid://1843322662", -- placeholder: replace with final asset
	},
	{
		name = "CampAmbience",
		channel = "Ambience",
		attribute = "CampAmbienceAssetId",
		looped = true,
		defaultAssetId = "rbxassetid://132897156", -- placeholder: replace with final asset
	},
	{
		name = "NightAmbience",
		channel = "Ambience",
		attribute = "NightAmbienceAssetId",
		looped = true,
		defaultAssetId = "rbxassetid://9112762653", -- placeholder: replace with final asset
	},
	{
		-- Optional Investigation overlay when FairgroundsAmbienceAssetId is set.
		-- Stays silent with no placeholder so we never invent a fake id.
		name = "FairgroundsAmbience",
		channel = "Ambience",
		attribute = "FairgroundsAmbienceAssetId",
		looped = true,
		defaultAssetId = nil,
	},
	{
		name = "PhaseChime",
		channel = "UI",
		attribute = "PhaseChimeAssetId",
		looped = false,
		subtitle = "The camp phase has changed.",
		defaultAssetId = "rbxassetid://2909601104", -- placeholder: replace with final asset
	},
	{
		name = "EvidenceFound",
		channel = "Effects",
		attribute = "EvidenceFoundAssetId",
		looped = false,
		subtitle = "Evidence discovered.",
		defaultAssetId = "rbxassetid://9039791885", -- placeholder: replace with final asset
	},
	{
		name = "VoteOpen",
		channel = "UI",
		attribute = "VoteOpenAssetId",
		looped = false,
		subtitle = "The campfire vote is open.",
		defaultAssetId = "rbxassetid://98572480937443", -- placeholder: replace with final asset
	},
	{
		name = "MonsterActive",
		channel = "Effects",
		attribute = "MonsterActiveAssetId",
		looped = true,
		subtitle = "A monster is nearby.",
		defaultAssetId = "rbxassetid://1842342421", -- placeholder: replace with final asset
	},
	{
		name = "Reward",
		channel = "UI",
		attribute = "RewardAssetId",
		looped = false,
		subtitle = "Round rewards received.",
		defaultAssetId = "rbxassetid://97881181065416", -- placeholder: replace with final asset
	},
	{
		-- One-shot fairgrounds sting on Investigation entry when attribute set.
		name = "CircusSting",
		channel = "Effects",
		attribute = "CircusStingAssetId",
		looped = false,
		subtitle = "The fairgrounds stirs.",
		defaultAssetId = nil,
	},
}

for _, definition in UISoundMap.Definitions do
	table.insert(DEFINITIONS, {
		name = definition.name,
		channel = "UI",
		attribute = definition.attribute,
		looped = false,
		defaultAssetId = definition.defaultAssetId,
	})
end

-- Per-monster proximity loops. Each is a drop-in slot: set the SoundService
-- attribute "MonsterActive<Id>AssetId" to a final asset and that monster's
-- rounds use it automatically; unset slots fall back to the generic
-- MonsterActive loop. No code changes needed to adopt final audio.
local MONSTER_DISPLAY_NAMES: { [string]: string } = {
	BabyAlien = "Baby Alien",
	Screamer = "Screamer",
	Wendigo = "Wendigo",
	ShadowMonster = "Shadow Monster",
	Chupacabra = "Chupacabra",
	Dullahan = "Dullahan",
	Entity = "Entity",
	Banshee = "Banshee",
}

for monsterId, displayName in MONSTER_DISPLAY_NAMES do
	table.insert(DEFINITIONS, {
		name = "MonsterActive_" .. monsterId,
		channel = "Effects",
		attribute = "MonsterActive" .. monsterId .. "AssetId",
		looped = true,
		subtitle = "The " .. displayName .. " is nearby.",
		defaultAssetId = nil,
	})
end

local DEFAULT_SETTINGS: { [string]: any } = {
	-- Group volumes: Music/Ambience sit slightly under Effects/UI so stings
	-- and proximity loops stay readable over beds. Master multiplies all four
	-- SoundGroups in _updateGroupVolumes (do not also scale individual Sounds).
	masterVolume = 0.82,
	musicVolume = 0.62,
	ambienceVolume = 0.72,
	effectsVolume = 0.92,
	uiVolume = 0.9,
	subtitles = true,
}

local PHASE_MUSIC: { [string]: string } = {
	Lobby = "LobbyMusic",
	RoleReveal = "CampMusic",
	Day = "CampMusic",
	MurderPlanning = "NightMusic",
	NightTransform = "NightMusic",
	Investigation = "NightMusic",
	Campfire = "CampMusic",
	Resolution = "ResultsMusic",
	Rewards = "ResultsMusic",
}

local PHASE_AMBIENCE: { [string]: string } = {
	Lobby = "CampAmbience",
	RoleReveal = "CampAmbience",
	Day = "CampAmbience",
	MurderPlanning = "NightAmbience",
	NightTransform = "NightAmbience",
	Investigation = "NightAmbience",
	Campfire = "CampAmbience",
	Resolution = "CampAmbience",
	Rewards = "CampAmbience",
}

-- Ambience loops that may layer under the phase bed (not displaced by
-- _switchLoop). FairgroundsAmbience is the Investigation Fairgrounds overlay.
local AMBIENCE_OVERLAYS: { [string]: boolean } = {
	FairgroundsAmbience = true,
}

local function clampVolume(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return fallback
	end
	return math.clamp(value, 0, 1)
end

local function normalizeAssetId(value: any): string
	local digits: string?
	if type(value) == "number" and value > 0 and value % 1 == 0 then
		digits = tostring(value)
	elseif type(value) == "string" then
		digits = string.match(value, "^rbxassetid://(%d+)$") or string.match(value, "^(%d+)$")
	end
	if not digits or digits == "0" then
		return ""
	end
	return "rbxassetid://" .. digits
end

local function soundDefinition(name: string): SoundDefinition?
	for _, definition in DEFINITIONS do
		if definition.name == name then
			return definition
		end
	end
	return nil
end

local function readPhase(state: any): string?
	if type(state) ~= "table" or type(state.round) ~= "table" then
		return nil
	end
	return if type(state.round.phase) == "string" then state.round.phase else nil
end

local function readEvidenceFound(state: any): number
	if type(state) == "table" and type(state.round) == "table" and type(state.round.evidenceFound) == "number" then
		return state.round.evidenceFound
	end
	return 0
end

local function makeGroup(name: string): SoundGroup
	local existing = SoundService:FindFirstChild("CampMystery" .. name)
	if existing then
		existing:Destroy()
	end
	local group = Instance.new("SoundGroup")
	group.Name = "CampMystery" .. name
	group.Parent = SoundService
	return group
end

function AudioController.new(options: AudioOptions?): AudioController
	local resolved = options or {}
	local previous = SoundService:FindFirstChild("CampMysteryAudio")
	if previous then
		previous:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "CampMysteryAudio"
	root.Parent = SoundService

	local groups: { [string]: SoundGroup } = {
		Music = makeGroup("Music"),
		Ambience = makeGroup("Ambience"),
		Effects = makeGroup("Effects"),
		UI = makeGroup("UI"),
	}
	local sounds: { [string]: Sound } = {}
	local attributeOverrides = resolved.assetAttributes or {}
	for _, definition in DEFINITIONS do
		local sound = Instance.new("Sound")
		sound.Name = definition.name
		sound.Looped = definition.looped
		sound.SoundGroup = groups[definition.channel]
		sound.Volume = 1
		local attributeName = attributeOverrides[definition.name] or definition.attribute
		sound:SetAttribute("AssetAttribute", attributeName)
		local configuredAssetId = normalizeAssetId(SoundService:GetAttribute(attributeName))
		local placeholderAssetId = normalizeAssetId(definition.defaultAssetId)
		sound.SoundId = if configuredAssetId ~= "" then configuredAssetId else placeholderAssetId
		sound:SetAttribute(
			"UsesPlaceholderAsset",
			configuredAssetId == "" and placeholderAssetId ~= ""
		)
		sound.Parent = root
		sounds[definition.name] = sound
	end

	local settings = table.clone(DEFAULT_SETTINGS)
	local self: AudioController = setmetatable({
		root = root,
		groups = groups,
		sounds = sounds,
		settings = settings,
		currentMusic = nil,
		lastPhase = nil,
		lastEvidenceFound = 0,
		heartbeatIntensity = 0,
		activeMonsterId = nil,
		onSubtitle = resolved.onSubtitle,
		destroyed = false,
	}, AudioController)
	self:ApplySettings(settings)
	return self
end

function AudioController:Start(initialState: any?)
	if initialState ~= nil then
		self:Update(initialState)
	end
end

function AudioController:_configured(sound: Sound): boolean
	return sound.SoundId ~= ""
end

function AudioController:_subtitle(text: string?, duration: number)
	if text and text ~= "" and self.settings.subtitles == true and self.onSubtitle then
		self.onSubtitle(text, duration)
	end
end

function AudioController:PlayCue(name: string, subtitle: string?): boolean
	if self.destroyed then
		return false
	end
	local sound = self.sounds[name]
	if not sound then
		return false
	end
	local definition = soundDefinition(name)
	local definitionSubtitle = if definition then definition.subtitle else nil
	self:_subtitle(subtitle or definitionSubtitle, 2.5)
	if not self:_configured(sound) then
		return false
	end
	sound:Play()
	return true
end

function AudioController:PlayUIEvent(eventName: string): boolean
	local cueName = UISoundMap.Resolve(eventName)
	if not cueName then
		return false
	end
	return self:PlayCue(cueName)
end

function AudioController:_switchLoop(channel: string, name: string?)
	for _, definition in DEFINITIONS do
		if definition.channel == channel and definition.looped then
			local sound = self.sounds[definition.name]
			-- Overlay ambience (Fairgrounds) layers under the phase bed and
			-- must not be stopped when NightAmbience / CampAmbience switches.
			if
				sound
				and sound.IsPlaying
				and definition.name ~= name
				and not AMBIENCE_OVERLAYS[definition.name]
			then
				sound:Stop()
			end
		end
	end
	if name then
		local sound = self.sounds[name]
		if sound and self:_configured(sound) and not sound.IsPlaying then
			sound:Play()
		end
	end
end

function AudioController:_setFairgroundsAmbience(enabled: boolean)
	local sound = self.sounds.FairgroundsAmbience
	if not sound then
		return
	end
	if enabled and self:_configured(sound) then
		if not sound.IsPlaying then
			-- Soft under the night bed so Calliope (server CircusAudioDefaults)
			-- remains the loud fairgrounds voice when players are near the lot.
			sound.Volume = 0.55
			sound:Play()
		end
	elseif sound.IsPlaying then
		sound:Stop()
	end
end

function AudioController:_updateGroupVolumes()
	local master = clampVolume(self.settings.masterVolume, DEFAULT_SETTINGS.masterVolume)
	self.groups.Music.Volume = master * clampVolume(self.settings.musicVolume, DEFAULT_SETTINGS.musicVolume)
	self.groups.Ambience.Volume = master * clampVolume(
		self.settings.ambienceVolume,
		DEFAULT_SETTINGS.ambienceVolume
	)
	self.groups.Effects.Volume = master * clampVolume(self.settings.effectsVolume, DEFAULT_SETTINGS.effectsVolume)
	self.groups.UI.Volume = master * clampVolume(self.settings.uiVolume, DEFAULT_SETTINGS.uiVolume)
end

function AudioController:ApplySettingImmediate(key: string, value: any)
	if type(key) ~= "string" then
		return
	end
	self.settings = table.clone(self.settings)
	self.settings[key] = value
	self:_updateGroupVolumes()
end

function AudioController:GetSettings(): { [string]: any }
	return table.clone(self.settings)
end

function AudioController:ApplySettings(settings: any)
	if type(settings) ~= "table" then
		return
	end
	for key, defaultValue in DEFAULT_SETTINGS do
		local value = settings[key]
		local valid = (type(defaultValue) == "number" and type(value) == "number"
				and value == value and math.abs(value) < math.huge)
			or (type(defaultValue) == "boolean" and type(value) == "boolean")
		if valid then
			self.settings[key] = value
		elseif self.settings[key] == nil then
			self.settings[key] = defaultValue
		end
	end

	self:_updateGroupVolumes()
	self.settings.subtitles = self.settings.subtitles ~= false
	self:SetHeartbeatIntensity(self.heartbeatIntensity)
end

function AudioController:_heartbeatSound(): Sound?
	local monsterId = self.activeMonsterId
	if monsterId then
		local specific = self.sounds["MonsterActive_" .. monsterId]
		if specific and self:_configured(specific) then
			return specific
		end
	end
	return self.sounds.MonsterActive
end

-- Selects which proximity loop plays for the current round's monster.
-- Pass nil outside night phases; unset monster slots fall back to the
-- generic MonsterActive loop.
function AudioController:SetActiveMonster(monsterId: string?)
	if self.destroyed then
		return
	end
	local resolved = if type(monsterId) == "string" and monsterId ~= ""
		then monsterId
		else nil
	if self.activeMonsterId == resolved then
		return
	end
	local previous = self:_heartbeatSound()
	self.activeMonsterId = resolved
	local current = self:_heartbeatSound()
	if previous and previous ~= current and previous.IsPlaying then
		previous:Stop()
	end
	self:SetHeartbeatIntensity(self.heartbeatIntensity)
end

function AudioController:SetHeartbeatIntensity(fraction: number)
	if self.destroyed then
		return
	end
	local resolved = if fraction == fraction and math.abs(fraction) < math.huge
		then math.clamp(fraction, 0, 1)
		else 0
	self.heartbeatIntensity = resolved
	local heartbeat = self:_heartbeatSound()
	if not heartbeat then
		return
	end
	-- The Effects SoundGroup already applies master * effectsVolume;
	-- multiplying again here would square the effects setting.
	heartbeat.Volume = resolved
	if resolved > 0.3 and self:_configured(heartbeat) then
		if not heartbeat.IsPlaying then
			heartbeat:Play()
		end
	elseif heartbeat.IsPlaying then
		heartbeat:Stop()
	end
end

function AudioController:Update(state: any)
	if self.destroyed then
		return
	end
	local profileSettings = if type(state) == "table"
			and type(state.profile) == "table"
			and type(state.profile.profile) == "table"
		then state.profile.profile.settings
		else nil
	if type(profileSettings) == "table" then
		self:ApplySettings(profileSettings)
	end

	local localRole = if type(state) == "table" and type(state.player) == "table" and type(state.player.role) == "string"
		then state.player.role
		else ""

	local phase = readPhase(state)
	if phase and phase ~= self.lastPhase then
		local firstSnapshot = self.lastPhase == nil
		self.lastPhase = phase
		self.currentMusic = PHASE_MUSIC[phase]
		self:_switchLoop("Music", self.currentMusic)
		self:_switchLoop("Ambience", PHASE_AMBIENCE[phase])
		-- Investigation: optional Fairgrounds overlay + CircusSting when
		-- SoundService attributes are set (silent placeholders otherwise).
		self:_setFairgroundsAmbience(phase == "Investigation")
		if not firstSnapshot then
			if phase == "Campfire" then
				local voteSubtitle = if localRole == "Murderer"
					then "They're voting. Choose your words carefully."
					else nil
				self:PlayCue("VoteOpen", voteSubtitle)
			elseif phase == "Rewards" then
				self:PlayCue("Reward")
			elseif phase == "Investigation" then
				local phaseSubtitle: string? = if localRole == "Murderer"
					then "Investigation begun. Maintain your cover."
					else nil
				self:PlayCue("PhaseChime", phaseSubtitle)
				self:PlayCue("CircusSting")
			else
				local phaseSubtitle: string? = if localRole == "Murderer"
					then if phase == "Day" then "Daytime. Stay composed."
						elseif phase == "MurderPlanning" then "You chose your prey. Prepare before dawn."
						elseif phase == "NightTransform" then "You are the monster. The hunt begins."
						else nil
					else nil
				self:PlayCue("PhaseChime", phaseSubtitle)
			end
		end
	end

	local evidenceFound = readEvidenceFound(state)
	if evidenceFound < self.lastEvidenceFound then
		self.lastEvidenceFound = 0
	end
	if evidenceFound > self.lastEvidenceFound then
		local evidenceSubtitle = if localRole == "Murderer" then "Evidence found against you." else nil
		self:PlayCue("EvidenceFound", evidenceSubtitle)
	end
	self.lastEvidenceFound = evidenceFound

end

function AudioController:RefreshAssetIds()
	for _, definition in DEFINITIONS do
		local sound = self.sounds[definition.name]
		if sound then
			local attributeName = sound:GetAttribute("AssetAttribute")
			local configuredAssetId = normalizeAssetId(
				if type(attributeName) == "string" then SoundService:GetAttribute(attributeName) else nil
			)
			local placeholderAssetId = normalizeAssetId(definition.defaultAssetId)
			sound.SoundId = if configuredAssetId ~= "" then configuredAssetId else placeholderAssetId
			sound:SetAttribute(
				"UsesPlaceholderAsset",
				configuredAssetId == "" and placeholderAssetId ~= ""
			)
		end
	end
	if self.lastPhase then
		self:_switchLoop("Music", PHASE_MUSIC[self.lastPhase])
		self:_switchLoop("Ambience", PHASE_AMBIENCE[self.lastPhase])
	end
	self:SetHeartbeatIntensity(self.heartbeatIntensity)
end

function AudioController:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	for _, sound in self.sounds do
		sound:Stop()
	end
	if self.root.Parent then
		self.root:Destroy()
	end
	for _, group in self.groups do
		if group.Parent then
			group:Destroy()
		end
	end
	table.clear(self.sounds)
	table.clear(self.groups)
end

return AudioController
