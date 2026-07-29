--!strict

export type Tip = {
	category: string,
	body: string,
	excludeRoles: { string }?,
	includeRoles: { string }?,
}

local definitions: { Tip } = {
	{ category = "CAMP BASICS", body = "Stay close to the group until you know the safest paths." },
	{ category = "CAMP BASICS", body = "Every phase changes what actions and locations are available." },
	{ category = "ROLES", body = "Your private role gives you a unique way to help—or mislead—the camp." },
	{ category = "ROLES", body = "Read your objective before using a limited role ability." },
	{ category = "ROLES", body = "Protect your role information until sharing it helps the investigation." },
	{ category = "MONSTERS", body = "Different monsters leave different patterns in the world." },
	{ category = "MONSTERS", body = "Light, distance, and teammates can improve your odds after dark.", excludeRoles = { "Murderer" } },
	{ category = "MONSTERS", body = "Listen for changes in the environment before entering danger." },
	{ category = "EVIDENCE", body = "Search marked objects and interview counselors to build the case." },
	{ category = "EVIDENCE", body = "One clue rarely proves a theory; compare several before deciding." },
	{ category = "EVIDENCE", body = "Confirmed and contradicted clues are stamped in your notebook." },
	{ category = "EVIDENCE", body = "Your notebook restores the evidence your character already discovered." },
	{ category = "VOTING", body = "Campfire votes are hidden until the reveal begins." },
	{ category = "VOTING", body = "Discuss evidence, not guesses, before locking in a suspect." },
	{ category = "VOTING", body = "A confident accusation can still be wrong—watch for contradictions." },
	{ category = "TEAMWORK", body = "Split up to search faster, but keep a safe route back to camp.", excludeRoles = { "Murderer" } },
	{ category = "TEAMWORK", body = "Injured campers need help; a missing teammate costs everyone information.", excludeRoles = { "Murderer" } },
	{ category = "CONTROLS", body = "Interaction prompts show the correct input for keyboard, touch, or controller." },

	-- Equipment tips
	{ category = "EQUIPMENT", body = "The Flashlight is your most reliable defense — keep it charged and pointed at threats.", excludeRoles = { "Murderer" } },
	{ category = "EQUIPMENT", body = "The EMF Reader spikes near recent monster activity and can expose the type of threat.", excludeRoles = { "Murderer" } },
	{ category = "EQUIPMENT", body = "Medical Kits remove serious injuries. Injured campers die from the next hit; prioritize healing them." },
	{ category = "EQUIPMENT", body = "Monster Traps slow down a monster mid-hunt. Place them on likely approach routes before nightfall.", excludeRoles = { "Murderer" } },

	-- Role ability tips
	{ category = "ROLES", body = "Detectives can analyze a suspect for a suspicion band and verify posted evidence as real or fake." },
	{ category = "ROLES", body = "The Medic cannot treat itself — ask a teammate to stay nearby when injured." },
	{ category = "ROLES", body = "The Guard and Protector carry Flare Lanterns. Sustained light limits the Shadow Monster's movement.", excludeRoles = { "Murderer" } },
	{ category = "ROLES", body = "The Medium's Spirit Box produces audio responses near haunted locations — post the evidence immediately." },

	-- Monster counterplay tips
	{ category = "COUNTERPLAY", body = "Break line of sight or change floors to disrupt the Dullahan before it reaches pursuit speed.", excludeRoles = { "Murderer" } },
	{ category = "COUNTERPLAY", body = "UV light and direct flashlights can remove the Chupacabra's latch faster than waiting it out.", excludeRoles = { "Murderer" } },
	{ category = "COUNTERPLAY", body = "Leave the wail radius immediately when the Banshee starts its attack — hesitation means injury.", excludeRoles = { "Murderer" } },
	{ category = "COUNTERPLAY", body = "The Entity teleports between anchors. Watch for the arrival silhouette and move away from anchor points.", excludeRoles = { "Murderer" } },

	-- Murderer-only tips
	{ category = "STRATEGY", body = "Your notebook tracks evidence collected against you. Check it often to gauge how close they are.", includeRoles = { "Murderer" } },
	{ category = "STRATEGY", body = "Vote last when possible — watch where suspicion falls before committing your vote.", includeRoles = { "Murderer" } },
	{ category = "STRATEGY", body = "Keep up with camp tasks. An idle Murderer stands out; participation builds trust.", includeRoles = { "Murderer" } },
	{ category = "STRATEGY", body = "If evidence mounts against you, redirect — point to contradictions in the clues and cast doubt on the accuser.", includeRoles = { "Murderer" } },

	-- Atmosphere / visual identification tips
	{ category = "MONSTERS", body = "The Baby Alien is small, pink, and low to the ground — a crawling shape in the dark. Get to open, lit space before it reaches leaping distance.", excludeRoles = { "Murderer" } },
	{ category = "MONSTERS", body = "The Screamer is a pale, gaunt humanoid with a hollow maw where a face should be. If you see those long dark claws, you are already too close.", excludeRoles = { "Murderer" } },
	{ category = "MONSTERS", body = "The Wendigo wears a deer skull and stands twice your height. Antlers scraping trees and mimicked voices are your first warning.", excludeRoles = { "Murderer" } },
	{ category = "MONSTERS", body = "The Dullahan has no head. If a cloaked figure is rushing you and the speed feels wrong, break line of sight immediately.", excludeRoles = { "Murderer" } },
	{ category = "MONSTERS", body = "The Banshee appears as a silver-white spectral woman. When she opens her mouth, move away before the wail builds to full intensity.", excludeRoles = { "Murderer" } },
	{ category = "ENVIRONMENT", body = "The old town beyond camp is foggy and abandoned — rusted water towers, crumbling buildings, muddy roads. Cover is plentiful but exits are limited.", excludeRoles = { "Murderer" } },
	{ category = "ENVIRONMENT", body = "Cabin interiors are dark and cluttered. Flashlights are essential once natural light drops at nightfall.", excludeRoles = { "Murderer" } },
	{ category = "COUNSELORS", body = "Each counselor has a distinct role you can recognise by their look — a wide ranger hat, a medical pack, a tool belt. Their accessories hint at what they know.", excludeRoles = { "Murderer" } },
}

return table.freeze({
	definitions = table.freeze(definitions),
})
