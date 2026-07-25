--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

type SnapshotHandler = (snapshot: any) -> ()
type ResultHandler = (result: any) -> ()

local RemoteBridge = {}
RemoteBridge.__index = RemoteBridge

export type RemoteBridge = typeof(setmetatable({} :: {
	remotes: Folder,
	snapshotHandlers: { [string]: { SnapshotHandler } },
	resultHandlers: { ResultHandler },
	connections: { RBXScriptConnection },
	boundNames: { [string]: boolean },
	productionReady: boolean,
}, RemoteBridge))

local SNAPSHOT_EVENTS: { [string]: string } = {
	GameStateChanged = "game",
	RoundStateChanged = "round",
	PlayerStateChanged = "player",
	LobbyStateChanged = "lobby",
	ParticipantStateChanged = "participant",
	InventoryStateChanged = "inventory",
	CombatStateChanged = "combat",
	EvidenceBoardChanged = "evidence",
	ProfileStateChanged = "profile",
	MonsterStateChanged = "monster",
	WorldStateChanged = "world",
	Announcement = "announcement",
}

local GETTERS: { [string]: string } = {
	GetGameState = "game",
	GetRoundState = "round",
	GetPlayerState = "player",
	GetLobbyState = "lobby",
	GetParticipantState = "participant",
	GetInventoryState = "inventory",
	GetCombatState = "combat",
	GetEvidenceBoard = "evidence",
	GetProfileState = "profile",
	GetMonsterState = "monster",
	GetWorldState = "world",
}

local ACTION_REMOTES: { [string]: { string } } = {
	Vote = { "SubmitVote" },
	Ready = { "SetReady", "LobbyAction" },
	EquipItem = { "InventoryAction", "RequestInventoryAction" },
	UseItem = { "InventoryAction", "RequestInventoryAction" },
	DropItem = { "InventoryAction", "RequestInventoryAction" },
	TransferItem = { "InventoryAction", "RequestInventoryAction" },
	VerifyEvidence = { "EvidenceAction", "RequestEvidenceAction" },
	AddEvidenceNote = { "EvidenceAction", "RequestEvidenceAction" },
	UseRoleAbility = { "RoleAction", "RequestRoleAction" },
	UseMonsterAbility = { "MonsterAction", "ActivateMonsterAbility" },
	SetSettings = { "UpdateSettings", "ProfileAction" },
	CompleteObjective = { "InteractionAction", "RequestInteraction" },
	DiscoverEvidence = { "InteractionAction", "RequestInteraction" },
}

function RemoteBridge.new(): RemoteBridge
	local remotesInstance = ReplicatedStorage:WaitForChild("Remotes")
	assert(remotesInstance:IsA("Folder"), "ReplicatedStorage.Remotes must be a Folder")
	local self: RemoteBridge = setmetatable({
		remotes = remotesInstance,
		snapshotHandlers = {},
		resultHandlers = {},
		connections = {},
		boundNames = {},
		productionReady = false,
	}, RemoteBridge)
	return self
end

function RemoteBridge:_emit(channel: string, payload: any)
	if channel == "game" and type(payload) == "table" then
		self.productionReady = true
	end
	local handlers = self.snapshotHandlers[channel]
	if not handlers then
		return
	end
	for _, handler in handlers do
		local ok, message = pcall(handler, payload)
		if not ok then
			warn("[RemoteBridge] Snapshot handler failed:", message)
		end
	end
end

function RemoteBridge:_bind(instance: Instance)
	if self.boundNames[instance.Name] then
		return
	end
	local channel = SNAPSHOT_EVENTS[instance.Name]
	if channel and instance:IsA("RemoteEvent") then
		self.boundNames[instance.Name] = true
		table.insert(self.connections, instance.OnClientEvent:Connect(function(payload: any)
			self:_emit(channel, payload)
		end))
	elseif instance.Name == "ActionResult" and instance:IsA("RemoteEvent") then
		self.boundNames[instance.Name] = true
		table.insert(self.connections, instance.OnClientEvent:Connect(function(payload: any)
			for _, handler in self.resultHandlers do
				handler(payload)
			end
		end))
	end
end

function RemoteBridge:Start()
	for _, child in self.remotes:GetChildren() do
		self:_bind(child)
	end
	table.insert(self.connections, self.remotes.ChildAdded:Connect(function(child: Instance)
		self:_bind(child)
	end))

	for remoteName, channel in GETTERS do
		local instance = self.remotes:FindFirstChild(remoteName)
		if instance and instance:IsA("RemoteFunction") then
			task.spawn(function()
				local ok, payload = pcall(function()
					return instance:InvokeServer()
				end)
				if ok then
					self:_emit(channel, payload)
				else
					warn("[RemoteBridge] Could not retrieve " .. channel .. " snapshot:", payload)
				end
			end)
		end
	end
end

function RemoteBridge:OnSnapshot(channel: string, handler: SnapshotHandler)
	local handlers = self.snapshotHandlers[channel]
	if not handlers then
		handlers = {}
		self.snapshotHandlers[channel] = handlers
	end
	table.insert(handlers, handler)
end

function RemoteBridge:OnActionResult(handler: ResultHandler)
	table.insert(self.resultHandlers, handler)
end

function RemoteBridge:HasAction(action: string): boolean
	local productionRemote = self.remotes:FindFirstChild("RequestAction")
	if self.productionReady and productionRemote and productionRemote:IsA("RemoteFunction") then
		return true
	end
	local candidates = ACTION_REMOTES[action]
	if not candidates then
		return false
	end
	for _, name in candidates do
		if self.remotes:FindFirstChild(name) ~= nil then
			return true
		end
	end
	return false
end

function RemoteBridge:Request(action: string, payload: any): (boolean, string?)
	local productionRemote = self.remotes:FindFirstChild("RequestAction")
	if self.productionReady and productionRemote and productionRemote:IsA("RemoteFunction") then
		task.spawn(function()
			local ok, result = pcall(function()
				return productionRemote:InvokeServer(action, payload)
			end)
			if ok then
				for _, handler in self.resultHandlers do
					handler(result)
				end
			else
				for _, handler in self.resultHandlers do
					handler({
						accepted = false,
						reason = "The camp radio did not answer. Try again.",
					})
				end
			end
		end)
		return true, nil
	end
	local candidates = ACTION_REMOTES[action]
	if not candidates then
		return false, "Unknown action"
	end
	for _, name in candidates do
		local remote = self.remotes:FindFirstChild(name)
		if remote and remote:IsA("RemoteEvent") then
			if name == "SubmitVote" and type(payload) == "table" then
				remote:FireServer(payload.targetKey)
			elseif name == "SetReady" and type(payload) == "table" then
				remote:FireServer(payload.ready)
			else
				remote:FireServer(payload)
			end
			return true, nil
		elseif remote and remote:IsA("RemoteFunction") then
			task.spawn(function()
				local ok, result = pcall(function()
					return remote:InvokeServer(payload)
				end)
				if ok then
					for _, handler in self.resultHandlers do
						handler(result)
					end
				end
			end)
			return true, nil
		end
	end
	return false, "That action is not available yet."
end

function RemoteBridge:Destroy()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
end

return table.freeze(RemoteBridge)
