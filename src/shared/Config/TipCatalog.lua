--!strict

export type Tip = {
	category: string,
	body: string,
	excludeRoles: { string }?,
	includeRoles: { string }?,
}

-- Lobby / loading tips may include "{featured}" — resolve with the weekly
-- CosmeticCatalog display name when the UI can look it up.
local function formatBody(tip: Tip, featuredDisplayName: string?): string
	local body = tip.body
	local needle = "{featured}"
	if not string.find(body, needle, 1, true) then
		return body
	end
	local name = featuredDisplayName
	if type(name) ~= "string" or name == "" then
		name = "this week's featured cosmetic"
	end
	return (string.gsub(body, needle, name, 1))
end

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
	-- Mastery / codex challenge tips (progress lives in Monster Codex)
	{ category = "COUNTERPLAY", body = "Open the Monster Codex after each night — surviving Wendigo hunts unlocks mastery challenges.", excludeRoles = { "Murderer" } },
	{ category = "COUNTERPLAY", body = "Correct culprit IDs raise monster mastery. Shadow Monster and Entity challenges reward patient deduction.", excludeRoles = { "Murderer" } },
	{ category = "COUNTERPLAY", body = "Mastery tiers climb with encounters, survivals, and identifications. Check Codex challenges between rounds.", excludeRoles = { "Murderer" } },
	-- Live-ops: weekly featured cosmetic + daily streak (camp tokens only)
	{
		category = "CAMP STORE",
		body = "This week: {featured} — discounted camp tokens in Progress (never Robux). Daily streaks boost XP & tokens — play tomorrow to keep the bonus.",
	},
	{
		category = "STREAK",
		body = "Come back tomorrow: each consecutive UTC day adds +10% XP & camp tokens (caps at +50%). Streak titles unlock in Progress.",
	},
	-- Rematch keeps the same lobby party together
	{
		category = "REMATCH",
		body = "Hit PLAY AGAIN after the verdict — rematch keeps your party and auto-signs you up when the lobby returns.",
	},

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
	{ category = "ENVIRONMENT", body = "Almost everything can be inspected — bulletin boards, radios, Midway games, gravestones, and motel guestbooks hide flavor and soft clues." },
	{ category = "ENVIRONMENT", body = "Sit on benches and picnic seats to rest. Ring the dinner bell, tune camp radios, and try Midway ring-toss or the fortune booth." },
	{ category = "ENVIRONMENT", body = "At the lake dock: try a fishing cast, inspect the life ring and cooler, blow the boat whistle, skip rocks, or sit on the edge." },
	{ category = "ENVIRONMENT", body = "Fairgrounds Midway packs more games — balloon darts, milk bottles, duck pond, dunk tank, and a spinning prize wheel with rotating flair." },
	{ category = "ENVIRONMENT", body = "Cabin interiors are dark and cluttered. Flashlights are essential once natural light drops at nightfall.", excludeRoles = { "Murderer" } },
	{ category = "ENVIRONMENT", body = "Northeast Fairgrounds: Midway Festival by day (soft rides, prize booths, ticket booth) flips to Midnight Circus after dusk. Tickets are optional — the murder mystery stays separate from the opt-in scare.", excludeRoles = { "Murderer" } },
	{ category = "ENVIRONMENT", body = "Walk the Midway Festival while the sun is up — check fair supplies, restock popcorn, browse the prize counter, and take a Festival Pass if you want the night carnival chase.", excludeRoles = { "Murderer" } },
	{ category = "EVIDENCE", body = "The midway prize counter, ticket booth, and fair-supplies crate can hold soft clues. Searching Fairgrounds props never makes the circus lethal — the mystery stays separate from the opt-in scare." },
	{ category = "ENVIRONMENT", body = "Night routes rotate each round in this Place (Main Street, Factory Detour, Outskirts First, Backcountry Night, Lakeshore Night). Check the lobby Route chip before dusk so you know which path the investigation will take.", excludeRoles = { "Murderer" } },
	{ category = "ENVIRONMENT", body = "Rematch? Try a different night route each round — the lobby Route chip preview cycles fairly so Main Street, Factory Detour, Outskirts First, Backcountry Night, and Lakeshore Night stay fresh.", excludeRoles = { "Murderer" } },
	{ category = "COUNSELORS", body = "Each counselor has a distinct role you can recognise by their look — a wide ranger hat, a medical pack, a tool belt. Their accessories hint at what they know.", excludeRoles = { "Murderer" } },
}

return table.freeze({
	definitions = table.freeze(definitions),
	formatBody = formatBody,
})
