--!strict

local services = script.Parent:WaitForChild("Services")
local RoundService = require(services:WaitForChild("RoundService"))

local roundService = RoundService.new()
roundService:Start()

print("[CAMP-Mystery] Server foundation started")
