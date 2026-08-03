--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonsterTypes = require(Shared:WaitForChild("Types"):WaitForChild("MonsterTypes"))

type MonsterId = MonsterTypes.MonsterId

-- Canonical ordered list of every monster in the game. The codex UI grid and
-- per-monster profile stat validation key off this single source of truth.
local MonsterOrder: { MonsterId } = {
	"BabyAlien",
	"Screamer",
	"Wendigo",
	"ShadowMonster",
	"Chupacabra",
	"Dullahan",
	"Entity",
	"Banshee",
}

return table.freeze(MonsterOrder)
