--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonsterTypes = require(Shared:WaitForChild("Types"):WaitForChild("MonsterTypes"))

type MonsterId = MonsterTypes.MonsterId
type PrivateMonsterRule = MonsterTypes.PrivateMonsterRule

local INVESTIGATION_ONLY = table.freeze({ "Investigation" })

local rules: { [MonsterId]: PrivateMonsterRule } = {
	BabyAlien = {
		id = "BabyAlien",
		maxStamina = 100,
		evidenceProfile = { "TinyTracks", "AcidicResidue", "LaserMotion" },
		abilities = {
			ScuttleLeap = {
				id = "ScuttleLeap",
				displayName = "Scuttle Leap",
				cooldownSeconds = 7,
				rangeStuds = 34,
				staminaCost = 25,
				requiresTarget = false,
				requiresLineOfSight = true,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Mobility", movementId = "BabyAlienLeap" },
					{ kind = "Evidence", evidenceId = "LaserMotion" },
				},
			},
			AcidSwipe = {
				id = "AcidSwipe",
				displayName = "Acid Swipe",
				cooldownSeconds = 4,
				rangeStuds = 7,
				staminaCost = 18,
				requiresTarget = true,
				requiresLineOfSight = true,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Attack", amount = 22 },
					{ kind = "Evidence", evidenceId = "AcidicResidue" },
				},
			},
		},
	},
	Screamer = {
		id = "Screamer",
		maxStamina = 110,
		evidenceProfile = { "CorruptedAudio", "EMFSpike", "DeviceInterference" },
		abilities = {
			DisruptingScream = {
				id = "DisruptingScream",
				displayName = "Disrupting Scream",
				cooldownSeconds = 14,
				rangeStuds = 42,
				staminaCost = 38,
				requiresTarget = true,
				requiresLineOfSight = true,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Status", statusId = "EquipmentDisabled", durationSeconds = 6 },
					{ kind = "Status", statusId = "Disoriented", durationSeconds = 3 },
					{ kind = "Evidence", evidenceId = "CorruptedAudio" },
				},
			},
			ClawStrike = {
				id = "ClawStrike",
				displayName = "Claw Strike",
				cooldownSeconds = 4,
				rangeStuds = 7,
				staminaCost = 16,
				requiresTarget = true,
				requiresLineOfSight = true,
				allowedPhases = INVESTIGATION_ONLY,
				effects = { { kind = "Attack", amount = 24 } },
			},
		},
	},
	Wendigo = {
		id = "Wendigo",
		maxStamina = 120,
		evidenceProfile = { "AntlerScrape", "MimicRecording", "FreezingTrace" },
		abilities = {
			ForestCharge = {
				id = "ForestCharge",
				displayName = "Forest Charge",
				cooldownSeconds = 11,
				rangeStuds = 58,
				staminaCost = 34,
				requiresTarget = false,
				requiresLineOfSight = true,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Mobility", movementId = "WendigoCharge" },
					{ kind = "Evidence", evidenceId = "AntlerScrape" },
				},
			},
			MimicMark = {
				id = "MimicMark",
				displayName = "Mimic Mark",
				cooldownSeconds = 15,
				rangeStuds = 48,
				staminaCost = 28,
				requiresTarget = true,
				requiresLineOfSight = false,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Status", statusId = "Marked", durationSeconds = 12 },
					{ kind = "Evidence", evidenceId = "MimicRecording" },
				},
			},
		},
	},
	ShadowMonster = {
		id = "ShadowMonster",
		maxStamina = 105,
		evidenceProfile = { "PhotoSilhouette", "LightDrain", "BlackResidue" },
		abilities = {
			ShadowStep = {
				id = "ShadowStep",
				displayName = "Shadow Step",
				cooldownSeconds = 9,
				rangeStuds = 45,
				staminaCost = 27,
				requiresTarget = false,
				requiresLineOfSight = false,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Mobility", movementId = "ShadowNodeStep" },
					{ kind = "Evidence", evidenceId = "BlackResidue" },
				},
			},
			LightDrain = {
				id = "LightDrain",
				displayName = "Light Drain",
				cooldownSeconds = 13,
				rangeStuds = 32,
				staminaCost = 32,
				requiresTarget = true,
				requiresLineOfSight = true,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Status", statusId = "VisionDistortion", durationSeconds = 6 },
					{ kind = "Evidence", evidenceId = "LightDrain" },
				},
			},
		},
	},
	Chupacabra = {
		id = "Chupacabra",
		maxStamina = 115,
		evidenceProfile = { "BloodTrail", "ClawMarks", "UVResidue" },
		abilities = {
			BloodPounce = {
				id = "BloodPounce",
				displayName = "Blood Pounce",
				cooldownSeconds = 10,
				rangeStuds = 54,
				staminaCost = 35,
				requiresTarget = true,
				requiresLineOfSight = true,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Mobility", movementId = "ChupacabraPounce" },
					{ kind = "Attack", amount = 26 },
					{ kind = "Status", statusId = "Bleeding", durationSeconds = 10 },
				},
			},
			Latch = {
				id = "Latch",
				displayName = "Latch",
				cooldownSeconds = 16,
				rangeStuds = 6,
				staminaCost = 30,
				requiresTarget = true,
				requiresLineOfSight = true,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Status", statusId = "Latched", durationSeconds = 4 },
					{ kind = "Evidence", evidenceId = "ClawMarks" },
				},
			},
		},
	},
	Dullahan = {
		id = "Dullahan",
		maxStamina = 130,
		evidenceProfile = {
			"FreezingTemperature",
			"HeadlessPhotograph",
			"LaserSilhouette",
		},
		abilities = {
			RelentlessPursuit = {
				id = "RelentlessPursuit",
				displayName = "Relentless Pursuit",
				cooldownSeconds = 12,
				rangeStuds = 70,
				staminaCost = 36,
				requiresTarget = true,
				requiresLineOfSight = true,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Mobility", movementId = "DullahanPursuit" },
					{ kind = "Status", statusId = "Fear", durationSeconds = 5 },
				},
			},
			FreezingTouch = {
				id = "FreezingTouch",
				displayName = "Freezing Touch",
				cooldownSeconds = 7,
				rangeStuds = 8,
				staminaCost = 22,
				requiresTarget = true,
				requiresLineOfSight = true,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Attack", amount = 20 },
					{ kind = "Status", statusId = "Slowed", durationSeconds = 5 },
					{ kind = "Evidence", evidenceId = "FreezingTemperature" },
				},
			},
		},
	},
	Entity = {
		id = "Entity",
		maxStamina = 100,
		evidenceProfile = { "SpiritBoxResponse", "Handprint", "LaserSilhouette" },
		abilities = {
			AnchorTeleport = {
				id = "AnchorTeleport",
				displayName = "Anchor Teleport",
				cooldownSeconds = 8,
				rangeStuds = 52,
				staminaCost = 26,
				requiresTarget = false,
				requiresLineOfSight = false,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Mobility", movementId = "EntityAnchorTeleport" },
					{ kind = "Evidence", evidenceId = "LaserSilhouette" },
				},
			},
			Distort = {
				id = "Distort",
				displayName = "Distort",
				cooldownSeconds = 12,
				rangeStuds = 38,
				staminaCost = 30,
				requiresTarget = true,
				requiresLineOfSight = false,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Status", statusId = "VisionDistortion", durationSeconds = 7 },
					{ kind = "Status", statusId = "Disoriented", durationSeconds = 4 },
					{ kind = "Evidence", evidenceId = "SpiritBoxResponse" },
				},
			},
		},
	},
	Banshee = {
		id = "Banshee",
		maxStamina = 110,
		evidenceProfile = { "RecordedWail", "ReflectionApparition", "DeathMark" },
		abilities = {
			MournfulWail = {
				id = "MournfulWail",
				displayName = "Mournful Wail",
				cooldownSeconds = 14,
				rangeStuds = 46,
				staminaCost = 38,
				requiresTarget = true,
				requiresLineOfSight = false,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Status", statusId = "Fear", durationSeconds = 8 },
					{ kind = "Status", statusId = "Disoriented", durationSeconds = 6 },
					{ kind = "Evidence", evidenceId = "RecordedWail" },
				},
			},
			DeathMark = {
				id = "DeathMark",
				displayName = "Death Mark",
				cooldownSeconds = 18,
				rangeStuds = 55,
				staminaCost = 32,
				requiresTarget = true,
				requiresLineOfSight = false,
				allowedPhases = INVESTIGATION_ONLY,
				effects = {
					{ kind = "Status", statusId = "Marked", durationSeconds = 14 },
					{ kind = "Evidence", evidenceId = "DeathMark" },
				},
			},
		},
	},
}

for _, monsterRule in rules do
	table.freeze(monsterRule.evidenceProfile)
	for _, ability in monsterRule.abilities do
		for _, effect in ability.effects do
			table.freeze(effect)
		end
		table.freeze(ability.effects)
		table.freeze(ability)
	end
	table.freeze(monsterRule.abilities)
	table.freeze(monsterRule)
end

return table.freeze(rules)
