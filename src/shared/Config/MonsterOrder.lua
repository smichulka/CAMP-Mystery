--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonsterTypes = require(Shared:WaitForChild("Types"):WaitForChild("MonsterTypes"))

type MonsterId = MonsterTypes.MonsterId

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
