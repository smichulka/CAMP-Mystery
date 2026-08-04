--!strict

-- Cold case archive: flavor pools for the police-station filing cabinet.
-- Each round, three "unsolved case" files are seeded from the MysteryCatalog
-- titles that were NOT chosen for the current round. One file retells the
-- round's true monster as an old sighting, one echoes that monster's habits,
-- and one profiles the murderer archetype. Reading all three grants a small
-- one-time XP bonus at round end (see RewardCalculation).

export type ColdCaseArchiveDefinition = {
	filesPerRound: number,
	-- Old sighting written in a ranger/deputy voice; keyed by MonsterId.
	monsterSightings: { [string]: string },
	-- A second, habit-focused echo of the same monster; keyed by MonsterId.
	monsterEchoes: { [string]: string },
	-- Murderer-archetype hints: the culprit is always someone inside the camp.
	culpritPatterns: { string },
}

local archive: ColdCaseArchiveDefinition = {
	filesPerRound = 3,

	monsterSightings = {
		BabyAlien = "Witness swore something small slipped under a locked cellar hatch. Droplets on the latch had eaten pits into the metal. Case closed as 'animal damage.' Nobody believed that.",
		Screamer = "Three families reported the same night: a sound so loud their radios died in a line down the street, then silence. No damage, no tracks. File marked unresolved.",
		Wendigo = "A search party followed a hurt hiker's trail and found gouges in the bark far above head height. One searcher heard his own brother calling from two places at once.",
		ShadowMonster = "Deputy's note: the streetlamps dimmed one after another with the generator running clean. The dark between them felt occupied. Investigation suspended.",
		Chupacabra = "Livestock case from the old ranch: the trail ignored the nearest pens and went straight for the injured animal. Four-part claw marks on a low wall. Never solved.",
		Dullahan = "A photographer's last roll shows a pursuer with clear shoulders and nothing above them. Frost in a straight line down the road in summer. File sealed by request.",
		Entity = "Same distortion at three fixed points, no tracks between them. A handprint on the inside of a sealed window. The investigating officer transferred out that week.",
		Banshee = "Every witness in a clean circle around the site reported the same sudden dread. A layered cry on the wire recording came from one moving source. Unresolved.",
	},

	monsterEchoes = {
		BabyAlien = "Follow-up memo: whatever it was kept low — under floors, through vents, beneath collapsed fencing. Watch the crawlspaces, not the doorways.",
		Screamer = "Follow-up memo: the bursts came in pairs with a strange quiet after each one. Investigators learned to move during the recovery pause.",
		Wendigo = "Follow-up memo: it never lost a trail once blood was drawn. Around corners, through the creek — no search pattern, just pursuit.",
		ShadowMonster = "Follow-up memo: it kept to the darkest section of every room. Witnesses who stayed near strong light were never approached.",
		Chupacabra = "Follow-up memo: fresh blood pulled it off any other target. The wounded were moved to the firehouse under double guard.",
		Dullahan = "Follow-up memo: it only gained speed in the open, in direct line of sight. Survivors broke view behind walls and lived.",
		Entity = "Follow-up memo: locks meant nothing. It appeared where it wished, but only near its anchor points. Find the anchors.",
		Banshee = "Follow-up memo: a cry of pain turned it instantly. The injured were kept quiet and together until sunrise.",
	},

	culpritPatterns = {
		"Pattern note across every file: the trouble started with someone the camp trusted. Keys, schedules, shortcuts — the culprit always knew them all.",
		"Reviewing officer's note: each unsolved case had one person whose story changed between tellings. Small changes. Ask twice.",
		"Archive summary: the evidence that pointed loudest was planted; the quiet, boring clues held up. The culprit was standing in the search party.",
	},
}

table.freeze(archive.monsterSightings)
table.freeze(archive.monsterEchoes)
table.freeze(archive.culpritPatterns)
return table.freeze(archive)
