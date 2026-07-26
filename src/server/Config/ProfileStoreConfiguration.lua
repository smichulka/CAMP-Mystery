--!strict

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared.Config:WaitForChild("ProgressionConfig"))
local serverRoot = script.Parent.Parent
local adapters = serverRoot:WaitForChild("Adapters")
local MemoryProfileStore = require(adapters:WaitForChild("MemoryProfileStore"))
local RobloxProfileStore = require(adapters:WaitForChild("RobloxProfileStore"))

local MODE_ATTRIBUTE = "CampMysteryProfileStoreMode"
local TEST_NAME_ATTRIBUTE = "CampMysteryTestDataStoreName"
local TEST_LOAD_FAILURES_ATTRIBUTE = "CampMysteryTestLoadFailures"
local TEST_UPDATE_FAILURES_ATTRIBUTE = "CampMysteryTestUpdateFailures"
local MAX_TEST_FAILURES = 100

export type Resolution = {
	store: any?,
	mode: "Memory" | "Production" | "TestDataStore",
	dataStoreName: string?,
	testLoadFailures: number,
	testUpdateFailures: number,
}

local ProfileStoreConfiguration = {}

local function configuredMode(): string
	local value = ServerStorage:GetAttribute(MODE_ATTRIBUTE)
	if value == nil then
		return "Auto"
	end
	if typeof(value) ~= "string" then
		error(MODE_ATTRIBUTE .. " must be a string")
	end
	return value :: string
end

local function failureCount(attributeName: string): number
	local value = ServerStorage:GetAttribute(attributeName)
	if value == nil then
		return 0
	end
	if typeof(value) ~= "number"
		or value ~= value
		or value < 0
		or value > MAX_TEST_FAILURES
		or math.floor(value) ~= value
	then
		error(string.format("%s must be an integer from 0 through %d", attributeName, MAX_TEST_FAILURES))
	end
	return value :: number
end

local function testDataStoreName(): string
	local value = ServerStorage:GetAttribute(TEST_NAME_ATTRIBUTE)
	if typeof(value) ~= "string" then
		error(TEST_NAME_ATTRIBUTE .. " must be set when TestDataStore mode is enabled")
	end
	local name = value :: string
	if name == ProgressionConfig.dataStoreName then
		error("TestDataStore mode cannot target the production profile DataStore")
	end
	if #name <= #ProgressionConfig.testDataStorePrefix
		or #name > ProgressionConfig.maxDataStoreNameLength
		or string.sub(name, 1, #ProgressionConfig.testDataStorePrefix)
			~= ProgressionConfig.testDataStorePrefix
		or string.match(name, "^[%w_%-]+$") == nil
	then
		error(
			string.format(
				"%s must start with %s, contain only letters/numbers/_/-, and be at most %d characters",
				TEST_NAME_ATTRIBUTE,
				ProgressionConfig.testDataStorePrefix,
				ProgressionConfig.maxDataStoreNameLength
			)
		)
	end
	return name
end

function ProfileStoreConfiguration.Resolve(): Resolution
	local mode = configuredMode()
	if mode == "Auto" then
		if RunService:IsStudio() then
			return {
				store = nil,
				mode = "Memory",
				dataStoreName = nil,
				testLoadFailures = 0,
				testUpdateFailures = 0,
			}
		end
		return {
			store = nil,
			mode = "Production",
			dataStoreName = ProgressionConfig.dataStoreName,
			testLoadFailures = 0,
			testUpdateFailures = 0,
		}
	end

	if mode == "Memory" then
		if not RunService:IsStudio() then
			error("Memory profile mode is restricted to Roblox Studio")
		end
		return {
			store = MemoryProfileStore.new(),
			mode = "Memory",
			dataStoreName = nil,
			testLoadFailures = 0,
			testUpdateFailures = 0,
		}
	end

	if mode ~= "TestDataStore" then
		error(MODE_ATTRIBUTE .. " must be Auto, Memory, or TestDataStore")
	end
	if not RunService:IsStudio() and game.PrivateServerId == "" then
		error("TestDataStore mode is restricted to Roblox Studio or a private server")
	end

	local name = testDataStoreName()
	local loadFailures = failureCount(TEST_LOAD_FAILURES_ATTRIBUTE)
	local updateFailures = failureCount(TEST_UPDATE_FAILURES_ATTRIBUTE)
	local retry = ProgressionConfig.storeRetry
	return {
		store = RobloxProfileStore.new(name, {
			maxAttempts = retry.maxAttempts,
			baseDelaySeconds = retry.baseDelaySeconds,
			maxDelaySeconds = retry.maxDelaySeconds,
			testLoadFailures = loadFailures,
			testUpdateFailures = updateFailures,
		}),
		mode = "TestDataStore",
		dataStoreName = name,
		testLoadFailures = loadFailures,
		testUpdateFailures = updateFailures,
	}
end

return ProfileStoreConfiguration
