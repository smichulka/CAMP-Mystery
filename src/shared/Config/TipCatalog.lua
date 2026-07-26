--!strict

export type Tip = {
	category: string,
	body: string,
}

local definitions: { Tip } = {
	{ category = "CAMP BASICS", body = "Stay close to the group until you know the safest paths." },
	{ category = "CAMP BASICS", body = "Every phase changes what actions and locations are available." },
	{ category = "ROLES", body = "Your private role gives you a unique way to help—or mislead—the camp." },
	{ category = "ROLES", body = "Read your objective before using a limited role ability." },
	{ category = "ROLES", body = "Protect your role information until sharing it helps the investigation." },
	{ category = "MONSTERS", body = "Different monsters leave different patterns in the world." },
	{ category = "MONSTERS", body = "Light, distance, and teammates can improve your odds after dark." },
	{ category = "MONSTERS", body = "Listen for changes in the environment before entering danger." },
	{ category = "EVIDENCE", body = "Search marked objects and interview counselors to build the case." },
	{ category = "EVIDENCE", body = "One clue rarely proves a theory; compare several before deciding." },
	{ category = "EVIDENCE", body = "Confirmed and contradicted clues are stamped in your notebook." },
	{ category = "EVIDENCE", body = "Your notebook restores the evidence your character already discovered." },
	{ category = "VOTING", body = "Campfire votes are hidden until the reveal begins." },
	{ category = "VOTING", body = "Discuss evidence, not guesses, before locking in a suspect." },
	{ category = "VOTING", body = "A confident accusation can still be wrong—watch for contradictions." },
	{ category = "TEAMWORK", body = "Split up to search faster, but keep a safe route back to camp." },
	{ category = "TEAMWORK", body = "Injured campers need help; a missing teammate costs everyone information." },
	{ category = "CONTROLS", body = "Interaction prompts show the correct input for keyboard, touch, or controller." },

	-- Equipment tips
	{ category = "EQUIPMENT", body = "The Flashlight is your most reliable defense — keep it charged and pointed at threats." },
	{ category = "EQUIPMENT", body = "The EMF Reader spikes near recent monster activity and can expose the type of threat." },
	{ category = "EQUIPMENT", body = "Medical Kits remove serious injuries. Injured campers die from the next hit; prioritize healing them." },
	{ category = "EQUIPMENT", body = "Monster Traps slow down a monster mid-hunt. Place them on likely approach routes before nightfall." },

	-- Role ability tips
	{ category = "ROLES", body = "Detectives can analyze a suspect for a suspicion band and verify posted evidence as real or fake." },
	{ category = "ROLES", body = "The Medic cannot treat itself — ask a teammate to stay nearby when injured." },
	{ category = "ROLES", body = "The Guard and Protector carry Flare Lanterns. Sustained light limits the Shadow Monster's movement." },
	{ category = "ROLES", body = "The Medium's Spirit Box produces audio responses near haunted locations — post the evidence immediately." },

	-- Monster counterplay tips
	{ category = "COUNTERPLAY", body = "Break line of sight or change floors to disrupt the Dullahan before it reaches pursuit speed." },
	{ category = "COUNTERPLAY", body = "UV light and direct flashlights can remove the Chupacabra's latch faster than waiting it out." },
	{ category = "COUNTERPLAY", body = "Leave the wail radius immediately when the Banshee starts its attack — hesitation means injury." },
	{ category = "COUNTERPLAY", body = "The Entity teleports between anchors. Watch for the arrival silhouette and move away from anchor points." },
}

return table.freeze({
	definitions = table.freeze(definitions),
})
