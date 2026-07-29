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
})

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

local DEFAULT_SETTINGS: { [string]: any } = {
	masterVolume = 0.8,
	musicVolume = 0.65,
	ambienceVolume = 0.7,
	effectsVolume = 0.9,
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
			if sound and sound.IsPlaying and definition.name ~= name then
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

function AudioController:SetHeartbeatIntensity(fraction: number)
	if self.destroyed then
		return
	end
	local resolved = if fraction == fraction and math.abs(fraction) < math.huge
		then math.clamp(fraction, 0, 1)
		else 0
	self.heartbeatIntensity = resolved
	local heartbeat = self.sounds.MonsterActive
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
		if not firstSnapshot then
			if phase == "Campfire" then
				local voteSubtitle = if localRole == "Murderer"
					then "They're voting. Choose your words carefully."
					else nil
				self:PlayCue("VoteOpen", voteSubtitle)
			elseif phase == "Rewards" then
				self:PlayCue("Reward")
			else
				local phaseSubtitle: string? = if localRole == "Murderer"
					then if phase == "Day" then "Daytime. Stay composed."
						elseif phase == "Investigation" then "Investigation begun. Maintain your cover."
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
