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
}

return table.freeze({
	definitions = table.freeze(definitions),
})
