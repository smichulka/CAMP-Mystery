--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared.Config:WaitForChild("ProgressionConfig"))
local config = script.Parent.Parent:WaitForChild("Config")
local ProfileStoreConfiguration = require(config:WaitForChild("ProfileStoreConfiguration"))

type UpdateTransform = (storedValue: unknown?) -> unknown?

type MemoryProfileStoreState = {
	records: { [string]: any },
	failLoads: boolean,
	failUpdates: boolean,
}

local MemoryProfileStore = {}
MemoryProfileStore.__index = MemoryProfileStore

export type MemoryProfileStore = typeof(
	setmetatable({} :: MemoryProfileStoreState, MemoryProfileStore)
)

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end

	local result = {}
	for key, child in value do
		result[deepCopy(key)] = deepCopy(child)
	end
	return result
end

function MemoryProfileStore.new(initialRecords: { [string]: any }?): any
	local resolution = ProfileStoreConfiguration.Resolve()
	if resolution.mode == "TestDataStore" then
		local RobloxProfileStore = require(script.Parent:WaitForChild("RobloxProfileStore"))
		local retry = ProgressionConfig.storeRetry
		return RobloxProfileStore.new(resolution.dataStoreName :: string, {
			maxAttempts = retry.maxAttempts,
			baseDelaySeconds = retry.baseDelaySeconds,
			maxDelaySeconds = retry.maxDelaySeconds,
		})
	end

	return setmetatable({
		records = deepCopy(initialRecords or {}),
		failLoads = false,
		failUpdates = false,
	}, MemoryProfileStore)
end

function MemoryProfileStore:SetFailureModes(failLoads: boolean, failUpdates: boolean)
	self.failLoads = failLoads
	self.failUpdates = failUpdates
end

function MemoryProfileStore:LoadAsync(key: string): (boolean, unknown?, string?)
	if self.failLoads then
		return false, nil, "MemoryProfileStore forced load failure"
	end
	return true, deepCopy(self.records[key]), nil
end

function MemoryProfileStore:UpdateAsync(
	key: string,
	transform: UpdateTransform
): (boolean, unknown?, string?)
	if self.failUpdates then
		return false, nil, "MemoryProfileStore forced update failure"
	end

	local success, transformed = pcall(function()
		return transform(deepCopy(self.records[key]))
	end)
	if not success then
		return false, nil, tostring(transformed)
	end

	if transformed ~= nil then
		self.records[key] = deepCopy(transformed)
	end
	return true, deepCopy(self.records[key]), nil
end

function MemoryProfileStore:ReadForTest(key: string): unknown?
	return deepCopy(self.records[key])
end

return MemoryProfileStore
