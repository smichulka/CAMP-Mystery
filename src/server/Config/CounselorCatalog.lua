--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CounselorTypes = require(
	ReplicatedStorage.Shared.Types:WaitForChild("CounselorTypes")
)

type CounselorDefinition = CounselorTypes.CounselorDefinition
type CounselorId = CounselorTypes.CounselorId

local counselors: { CounselorDefinition } = {
	{
		id = "counselor-holloway",
		displayName = "Director Mara Holloway",
		roleTitle = "Camp Director",
		description = "An authoritative camp director who runs the operation like a field commander — radio in hand, duty roster memorised, zero tolerance for chaos.",
		isAdult = true,
		bravery = 0.86,
		reliability = 0.82,
		schedule = {
			{ phase = "Lobby", locationId = "CounselorLodge", activity = "Reviewing arrival records" },
			{ phase = "RoleReveal", locationId = "Campfire", activity = "Leading the morning briefing" },
			{ phase = "Day", locationId = "CounselorLodge", activity = "Coordinating duty assignments" },
			{ phase = "MurderPlanning", locationId = "Generator", activity = "Checking the emergency plan" },
			{ phase = "NightTransform", locationId = "camp-safe-campfire", activity = "Directing the evacuation" },
			{ phase = "Investigation", locationId = "police-safe-lobby", activity = "Maintaining the incident log" },
			{ phase = "Campfire", locationId = "camp-evidence-board", activity = "Organizing witness statements" },
			{ phase = "Resolution", locationId = "Campfire", activity = "Accounting for the camp" },
			{ phase = "Rewards", locationId = "CounselorLodge", activity = "Closing the incident file" },
		},
		hideLocationIds = { "police-cell-hide", "square-store-hide" },
		fleeLocationIds = { "camp-safe-campfire", "police-safe-lobby" },
		dialogue = {
			Greeting = {
				"Stay focused and check in before you leave the main path.",
				"I am keeping the incident log. Tell me only what you personally observed.",
			},
			Schedule = {
				"I moved between the lodge, generator, and campfire as the emergency plan required.",
				"My route is written in the duty log. Check the times instead of relying on guesses.",
			},
			Observation = {
				"I heard movement on a staff route, but the sound alone cannot identify anyone.",
				"I recorded what I saw without adding a name. Compare it with the physical evidence.",
			},
			Monster = {
				"Do not guess the creature from one frightening detail. Look for three consistent signs.",
				"Use the right countermeasure, keep an exit route, and do not chase it alone.",
			},
			Safety = {
				"Break line of sight, reach a marked safe point, and help injured campers move.",
				"If the route turns unsafe, fall back to the campfire or police lobby.",
			},
			Suspicion = {
				"Access is not proof. Several adults and campers knew the staff routes.",
				"A confident accusation still needs a chain of evidence.",
			},
		},
	},
	{
		id = "counselor-ortiz",
		displayName = "Counselor Lena Ortiz",
		roleTitle = "Health and Safety Counselor",
		description = "A calm, white-coat health counselor with a stethoscope and a medical pack always within reach. Notices injuries, vital signs, and behavioural changes others miss.",
		isAdult = true,
		bravery = 0.58,
		reliability = 0.9,
		schedule = {
			{ phase = "Lobby", locationId = "Infirmary", activity = "Inventorying first-aid kits" },
			{ phase = "RoleReveal", locationId = "Campfire", activity = "Reviewing safety rules" },
			{ phase = "Day", locationId = "Infirmary", activity = "Running the health station" },
			{ phase = "MurderPlanning", locationId = "Supplies", activity = "Restocking emergency packs" },
			{ phase = "NightTransform", locationId = "camp-hide-cabin-a", activity = "Securing medical supplies" },
			{ phase = "Investigation", locationId = "residential-safe-porch", activity = "Treating evacuees" },
			{ phase = "Campfire", locationId = "Campfire", activity = "Reporting injury timelines" },
			{ phase = "Resolution", locationId = "Infirmary", activity = "Checking survivors" },
			{ phase = "Rewards", locationId = "Supplies", activity = "Replacing used medical kits" },
		},
		hideLocationIds = { "residential-closet-hide", "camp-hide-cabin-a" },
		fleeLocationIds = { "residential-safe-porch", "camp-safe-campfire" },
		dialogue = {
			Greeting = {
				"Tell me whether anyone is hurt before we discuss anything else.",
				"Keep your voice down. Injured people need a clear route to safety.",
			},
			Schedule = {
				"I worked in the infirmary, moved to supplies, then treated evacuees at the porch.",
				"My medical log records each treatment time, but it does not prove who caused an injury.",
			},
			Observation = {
				"I noticed who arrived injured and when, not who attacked them.",
				"One timeline does not fit cleanly. Compare my notes with the camp clock.",
			},
			Monster = {
				"The creature seemed unusually aware of injured people. Treat that as a clue, not a conclusion.",
				"Fear changes memory. Equipment readings will be steadier than a panicked description.",
			},
			Safety = {
				"An injured camper should never travel alone. Pair up and use a marked safe route.",
				"Medical kits are limited. Stabilize the greatest risk first.",
			},
			Suspicion = {
				"An injury can explain suspicious movement. Check the timing before assigning blame.",
				"I will report facts, but I will not turn a medical note into an accusation.",
			},
		},
	},
	{
		id = "counselor-reed",
		displayName = "Counselor Miles Reed",
		roleTitle = "Outdoor Skills Counselor",
		description = "A khaki-and-boot trail expert with a wide-brim ranger hat and a backpack full of survival tools. Reads tracks precisely and prefers evidence over speculation.",
		isAdult = true,
		bravery = 0.78,
		reliability = 0.76,
		schedule = {
			{ phase = "Lobby", locationId = "Trailhead", activity = "Inspecting trail markers" },
			{ phase = "RoleReveal", locationId = "Campfire", activity = "Reviewing boundary rules" },
			{ phase = "Day", locationId = "ActivityField", activity = "Leading outdoor skills" },
			{ phase = "MurderPlanning", locationId = "Generator", activity = "Checking the tree-line fence" },
			{ phase = "NightTransform", locationId = "main-road-safe-entry", activity = "Clearing an escape route" },
			{ phase = "Investigation", locationId = "outskirts-safe-road-end", activity = "Reading tracks at the outskirts" },
			{ phase = "Campfire", locationId = "Campfire", activity = "Comparing routes and prints" },
			{ phase = "Resolution", locationId = "Trailhead", activity = "Reopening safe trails" },
			{ phase = "Rewards", locationId = "ActivityField", activity = "Repairing trail equipment" },
		},
		hideLocationIds = { "outskirts-house-hide", "industrial-locker-hide" },
		fleeLocationIds = { "outskirts-safe-road-end", "main-road-safe-entry" },
		dialogue = {
			Greeting = {
				"Watch the ground. The trail usually says more than the shouting.",
				"If you leave the marked route, tell someone where you are going.",
			},
			Schedule = {
				"I checked the field, generator fence, and outskirts route in that order.",
				"My trail route is predictable. That makes it easy to verify and easy to imitate.",
			},
			Observation = {
				"The print is partial. It narrows the footwear, but it does not name the wearer.",
				"Someone used the shortcut, though several people know where the latch sticks.",
			},
			Monster = {
				"Track spacing tells us how it moved. Residue and recordings tell us what it was.",
				"If it charges in a straight line, break sight early instead of trying to outrun it.",
			},
			Safety = {
				"Use open ground, keep a light ready, and never let the woods close behind you.",
				"Choose the route with two exits. The shortest route is not always the safest.",
			},
			Suspicion = {
				"A trail can be walked backward or crossed later. Preserve it before accusing anyone.",
				"Knowing the woods creates opportunity, not guilt.",
			},
		},
	},
	{
		id = "counselor-brooks",
		displayName = "Counselor Tessa Brooks",
		roleTitle = "Arts and Activities Counselor",
		description = "A free-spirited activities lead — lanyard and whistle always at hand, camera often in tow. Sharp memory for clothing, voices, and small details others overlook.",
		isAdult = true,
		bravery = 0.46,
		reliability = 0.72,
		schedule = {
			{ phase = "Lobby", locationId = "CraftCabin", activity = "Preparing activity supplies" },
			{ phase = "RoleReveal", locationId = "Campfire", activity = "Handing out duty cards" },
			{ phase = "Day", locationId = "CraftCabin", activity = "Leading camp activities" },
			{ phase = "MurderPlanning", locationId = "CounselorLodge", activity = "Returning duty materials" },
			{ phase = "NightTransform", locationId = "square-store-hide", activity = "Sheltering inside the store" },
			{ phase = "Investigation", locationId = "square-safe-bandstand", activity = "Watching the town square" },
			{ phase = "Campfire", locationId = "Campfire", activity = "Reconstructing the visual timeline" },
			{ phase = "Resolution", locationId = "CraftCabin", activity = "Accounting for supplies" },
			{ phase = "Rewards", locationId = "CraftCabin", activity = "Repairing activity materials" },
		},
		hideLocationIds = { "square-store-hide", "residential-closet-hide" },
		fleeLocationIds = { "square-safe-bandstand", "camp-safe-campfire" },
		dialogue = {
			Greeting = {
				"I remember colors and voices well, but the fog changed both tonight.",
				"Please do not move anything from the activity cabin without recording it.",
			},
			Schedule = {
				"I was in the craft cabin, then returned duty materials to the lodge.",
				"The supply sheet confirms what I carried, not every turn I made.",
			},
			Observation = {
				"I saw a coat color under emergency light, so I will not pretend the shade is certain.",
				"The voice sounded familiar, but imitation is part of what we are investigating.",
			},
			Monster = {
				"The outline changed when the light moved. A photograph may settle what my eyes could not.",
				"Record the sound before describing it. Memory reshapes frightening noises quickly.",
			},
			Safety = {
				"The bandstand has sightlines in every direction. Use it before the alleys.",
				"If the lights fail, move together and announce each turn.",
			},
			Suspicion = {
				"Similar clothing is not identity. Half the camp uses the same supply cabinet.",
				"My description should narrow the question, not finish it.",
			},
		},
	},
	{
		id = "counselor-chen",
		displayName = "Counselor Ivy Chen",
		roleTitle = "Nature and Science Counselor",
		description = "A methodical nature scientist who keeps a field journal tucked under one arm and calibrates her equipment before trusting any reading. Contamination is her first suspicion.",
		isAdult = true,
		bravery = 0.62,
		reliability = 0.94,
		schedule = {
			{ phase = "Lobby", locationId = "NatureLab", activity = "Calibrating field equipment" },
			{ phase = "RoleReveal", locationId = "Campfire", activity = "Distributing scanners" },
			{ phase = "Day", locationId = "NatureLab", activity = "Cataloging field samples" },
			{ phase = "MurderPlanning", locationId = "Generator", activity = "Checking electrical baselines" },
			{ phase = "NightTransform", locationId = "industrial-safe-loading-bay", activity = "Protecting the equipment case" },
			{ phase = "Investigation", locationId = "police-evidence-room-clue", activity = "Testing supernatural traces" },
			{ phase = "Campfire", locationId = "camp-evidence-board", activity = "Presenting verified readings" },
			{ phase = "Resolution", locationId = "NatureLab", activity = "Sealing collected samples" },
			{ phase = "Rewards", locationId = "NatureLab", activity = "Recalibrating instruments" },
		},
		hideLocationIds = { "industrial-locker-hide", "police-cell-hide" },
		fleeLocationIds = { "industrial-safe-loading-bay", "police-safe-lobby" },
		dialogue = {
			Greeting = {
				"Bring me readings with a location and time. A number without context is noise.",
				"Do not touch residue directly. Mark the spot and let the equipment work.",
			},
			Schedule = {
				"I moved from the nature lab to the generator, then to the evidence room.",
				"Instrument timestamps can verify my route within a short margin.",
			},
			Observation = {
				"The reading is abnormal, but several creatures share that signature.",
				"Contamination explains one result, not three independent results.",
			},
			Monster = {
				"Identify the creature by the intersection of multiple signs, not the most dramatic one.",
				"Counterplay is safest when the evidence profile is consistent.",
			},
			Safety = {
				"Do not test equipment while exposed. Establish a retreat point first.",
				"Failed electronics are information, but only if you survive to report the pattern.",
			},
			Suspicion = {
				"Physical access and supernatural evidence are separate questions.",
				"A planted sample can look convincing until its location and chain of custody are checked.",
			},
		},
	},
	{
		id = "counselor-finch",
		displayName = "Counselor Noah Finch",
		roleTitle = "Waterfront and Logistics Counselor",
		description = "A practical, tool-belt-wearing logistics counselor with a coffee-mug-and-wrench energy. Knows every piece of equipment, every checkout time, and every shortcut across the waterfront.",
		isAdult = true,
		bravery = 0.52,
		reliability = 0.8,
		schedule = {
			{ phase = "Lobby", locationId = "Supplies", activity = "Checking equipment returns" },
			{ phase = "RoleReveal", locationId = "Campfire", activity = "Issuing lanterns and radios" },
			{ phase = "Day", locationId = "Waterfront", activity = "Running waterfront activities" },
			{ phase = "MurderPlanning", locationId = "Supplies", activity = "Closing the checkout cage" },
			{ phase = "NightTransform", locationId = "water-tower-shed-hide", activity = "Sheltering near the water tower" },
			{ phase = "Investigation", locationId = "water-tower-safe-platform", activity = "Tracking issued equipment" },
			{ phase = "Campfire", locationId = "Campfire", activity = "Reviewing the checkout ledger" },
			{ phase = "Resolution", locationId = "Supplies", activity = "Recovering missing equipment" },
			{ phase = "Rewards", locationId = "Waterfront", activity = "Resetting the equipment racks" },
		},
		hideLocationIds = { "water-tower-shed-hide", "square-store-hide" },
		fleeLocationIds = { "water-tower-safe-platform", "camp-safe-campfire" },
		dialogue = {
			Greeting = {
				"Check equipment out properly. Missing gear creates bad evidence and worse emergencies.",
				"I can help with routes, supplies, and recorded checkout times.",
			},
			Schedule = {
				"I worked supplies, the waterfront, then the water-tower equipment point.",
				"The ledger shows what I issued, including items several people shared.",
			},
			Observation = {
				"A lantern came back with fresh soot, but the checkout line on that page is damaged.",
				"I heard the cage latch after closing. I did not see who touched it.",
			},
			Monster = {
				"The equipment failures happened in sequence, not all at once. That pattern matters.",
				"Use the ledger to see which countermeasures are still available.",
			},
			Safety = {
				"Take only what you can carry and leave spare gear at a known safe point.",
				"The water-tower platform is exposed but visible. The shed is hidden but has one exit.",
			},
			Suspicion = {
				"Possessing camp gear is ordinary. An unexplained time and location are what matter.",
				"The ledger can narrow access, but damaged records should never stand alone.",
			},
		},
	},
}

local byId: { [CounselorId]: CounselorDefinition } = {}
local orderedIds: { CounselorId } = {}

local function freezeDialogue(lines: CounselorTypes.CounselorDialogueSet)
	table.freeze(lines.Greeting)
	table.freeze(lines.Schedule)
	table.freeze(lines.Observation)
	table.freeze(lines.Monster)
	table.freeze(lines.Safety)
	table.freeze(lines.Suspicion)
	table.freeze(lines)
end

for _, definition in counselors do
	assert(definition.isAdult, "Every counselor NPC must be an adult")
	assert(not byId[definition.id], "Duplicate counselor ID: " .. definition.id)
	assert(definition.bravery >= 0 and definition.bravery <= 1, "Invalid counselor bravery")
	assert(
		definition.reliability >= 0 and definition.reliability <= 1,
		"Invalid counselor reliability"
	)
	for _, entry in definition.schedule do
		table.freeze(entry)
	end
	table.freeze(definition.schedule)
	table.freeze(definition.hideLocationIds)
	table.freeze(definition.fleeLocationIds)
	freezeDialogue(definition.dialogue)
	table.freeze(definition)
	byId[definition.id] = definition
	table.insert(orderedIds, definition.id)
end

assert(#counselors == 6, "Launch requires exactly six counselor NPCs")
table.freeze(counselors)
table.freeze(orderedIds)
table.freeze(byId)

return table.freeze({
	Get = function(counselorId: CounselorId): CounselorDefinition?
		return byId[counselorId]
	end,
	GetAll = function(): { CounselorDefinition }
		return counselors
	end,
	GetOrderedIds = function(): { CounselorId }
		return orderedIds
	end,
})
