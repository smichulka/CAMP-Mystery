--!strict

local controllers = script.Parent:WaitForChild("Controllers")
local RoundController = require(controllers:WaitForChild("RoundController"))

RoundController.Start()

print("[CAMP-Mystery] Client foundation started")
