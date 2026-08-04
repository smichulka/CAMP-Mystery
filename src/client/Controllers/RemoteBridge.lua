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
	destroyed: boolean,
	requestGeneration: number,
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
	Sabotage = { "RoleAction", "RequestRoleAction" },
	UseMonsterAbility = { "MonsterAction", "ActivateMonsterAbility" },
	SetSettings = { "UpdateSettings", "ProfileAction" },
	CompleteObjective = { "InteractionAction", "RequestInteraction" },
	DiscoverEvidence = { "InteractionAction", "RequestInteraction" },
	InterviewCounselor = { "InteractionAction", "RequestInteraction" },
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
		destroyed = false,
		requestGeneration = 0,
	}, RemoteBridge)
	return self
end

function RemoteBridge:_emit(channel: string, payload: any)
	if self.destroyed then
		return
	end
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
				local ok, message = pcall(handler, payload)
				if not ok then
					warn("[RemoteBridge] Action-result handler failed:", message)
				end
			end
		end))
	end
end

function RemoteBridge:Start()
	if self.destroyed then
		return
	end
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
				if ok and not self.destroyed then
					self:_emit(channel, payload)
				elseif not ok and not self.destroyed then
					warn("[RemoteBridge] Could not retrieve " .. channel .. " snapshot:", payload)
				end
			end)
		end
	end
end

function RemoteBridge:OnSnapshot(channel: string, handler: SnapshotHandler)
	if self.destroyed then
		return
	end
	local handlers = self.snapshotHandlers[channel]
	if not handlers then
		handlers = {}
		self.snapshotHandlers[channel] = handlers
	end
	table.insert(handlers, handler)
end

function RemoteBridge:OnActionResult(handler: ResultHandler)
	if self.destroyed then
		return
	end
	table.insert(self.resultHandlers, handler)
end

function RemoteBridge:HasAction(action: string): boolean
	if self.destroyed then
		return false
	end
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
	if self.destroyed then
		return false, "The camp radio is disconnected."
	end
	if type(action) ~= "string" or action == "" or type(payload) ~= "table" then
		return false, "Invalid action request."
	end
	local productionRemote = self.remotes:FindFirstChild("RequestAction")
	if self.productionReady and productionRemote and productionRemote:IsA("RemoteFunction") then
		local generation = self.requestGeneration
		task.spawn(function()
			local ok, result = pcall(function()
				return productionRemote:InvokeServer(action, payload)
			end)
			if self.destroyed or generation ~= self.requestGeneration then
				return
			end
			if ok then
				for _, handler in self.resultHandlers do
					local handled, message = pcall(handler, result)
					if not handled then
						warn("[RemoteBridge] Action-result handler failed:", message)
					end
				end
			else
				for _, handler in self.resultHandlers do
					local handled, message = pcall(handler, {
						accepted = false,
						reason = "The camp radio did not answer. Try again.",
					})
					if not handled then
						warn("[RemoteBridge] Action-result handler failed:", message)
					end
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
			local generation = self.requestGeneration
			task.spawn(function()
				local ok, result = pcall(function()
					return remote:InvokeServer(payload)
				end)
				if ok and not self.destroyed and generation == self.requestGeneration then
					for _, handler in self.resultHandlers do
						local handled, message = pcall(handler, result)
						if not handled then
							warn("[RemoteBridge] Action-result handler failed:", message)
						end
					end
				end
			end)
			return true, nil
		end
	end
	return false, "That action is not available yet."
end

function RemoteBridge:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.requestGeneration += 1
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	table.clear(self.snapshotHandlers)
	table.clear(self.resultHandlers)
	table.clear(self.boundNames)
end

return table.freeze(RemoteBridge)
