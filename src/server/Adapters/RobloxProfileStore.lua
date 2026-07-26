--!strict

local DataStoreService = game:GetService("DataStoreService")

local config = script.Parent.Parent:WaitForChild("Config")
local ProfileStoreConfiguration = require(config:WaitForChild("ProfileStoreConfiguration"))

type UpdateTransform = (storedValue: unknown?) -> unknown?

export type StoreOptions = {
	maxAttempts: number?,
	baseDelaySeconds: number?,
	maxDelaySeconds: number?,
	testLoadFailures: number?,
	testUpdateFailures: number?,
}

type RobloxProfileStoreState = {
	dataStore: any,
	maxAttempts: number,
	baseDelaySeconds: number,
	maxDelaySeconds: number,
	remainingTestLoadFailures: number,
	remainingTestUpdateFailures: number,
}

local RobloxProfileStore = {}
RobloxProfileStore.__index = RobloxProfileStore

export type RobloxProfileStore = typeof(
	setmetatable({} :: RobloxProfileStoreState, RobloxProfileStore)
)

local function positiveNumber(value: number?, fallback: number): number
	if value == nil or value <= 0 then
		return fallback
	end
	return value
end

local function nonNegativeInteger(value: number?): number
	if value == nil or value ~= value or value < 0 then
		return 0
	end
	return math.floor(value)
end

function RobloxProfileStore.new(
	storeName: string,
	options: StoreOptions?
): RobloxProfileStore
	local configured = options or {}
	local resolution = ProfileStoreConfiguration.Resolve()
	local resolvedStoreName = storeName
	local loadFailures = nonNegativeInteger(configured.testLoadFailures)
	local updateFailures = nonNegativeInteger(configured.testUpdateFailures)
	if resolution.mode == "TestDataStore" then
		resolvedStoreName = resolution.dataStoreName :: string
		loadFailures = resolution.testLoadFailures
		updateFailures = resolution.testUpdateFailures
	end

	return setmetatable({
		dataStore = DataStoreService:GetDataStore(resolvedStoreName),
		maxAttempts = math.max(1, math.floor(positiveNumber(configured.maxAttempts, 4))),
		baseDelaySeconds = positiveNumber(configured.baseDelaySeconds, 0.5),
		maxDelaySeconds = positiveNumber(configured.maxDelaySeconds, 4),
		remainingTestLoadFailures = loadFailures,
		remainingTestUpdateFailures = updateFailures,
	}, RobloxProfileStore)
end

function RobloxProfileStore:_RunWithRetries(
	operation: () -> unknown?
): (boolean, unknown?, string?)
	local lastError = "Unknown DataStore failure"
	for attempt = 1, self.maxAttempts do
		local success, result = pcall(operation)
		if success then
			return true, result, nil
		end

		lastError = tostring(result)
		if attempt < self.maxAttempts then
			local delaySeconds = math.min(
				self.maxDelaySeconds,
				self.baseDelaySeconds * (2 ^ (attempt - 1))
			)
			task.wait(delaySeconds)
		end
	end
	return false, nil, lastError
end

function RobloxProfileStore:LoadAsync(key: string): (boolean, unknown?, string?)
	return self:_RunWithRetries(function()
		if self.remainingTestLoadFailures > 0 then
			self.remainingTestLoadFailures -= 1
			error("Injected test profile load failure")
		end
		return self.dataStore:GetAsync(key)
	end)
end

function RobloxProfileStore:UpdateAsync(
	key: string,
	transform: UpdateTransform
): (boolean, unknown?, string?)
	return self:_RunWithRetries(function()
		if self.remainingTestUpdateFailures > 0 then
			self.remainingTestUpdateFailures -= 1
			error("Injected test profile update failure")
		end
		return self.dataStore:UpdateAsync(key, function(currentValue: unknown?)
			return transform(currentValue)
		end)
	end)
end

return RobloxProfileStore
