# CAMP-Mystery Product Specification

This document is the authoritative implementation baseline for the first playable release.
It converts the completed design conversation into rules that can be built and tested.

## Release promise

- Ten-player standard matches, with support for 1–12 human and computer participants.
- A 150-second lobby countdown fills empty seats with computer players.
- One transforming summer-camp and abandoned-town map.
- Eight hidden roles and eight separate monster transformations.
- A complete 15–20 minute morning, daytime, murder-planning, transformation, survival,
  investigation, campfire, accusation, resolution, and rewards loop.
- Permanent progression, role mastery, earned upgrades, and cosmetics.
- Desktop, touch, and controller support.
- No monetization at launch. Camp tokens are earned only by playing.

## Standard role distribution

A standard ten-participant match contains:

| Role | Count | Core responsibility |
|---|---:|---|
| Murderer | 1 | Plan the murder, transform, mislead the camp, and survive the accusation |
| Detective | 1 | Investigate suspicion and officially verify real or fake evidence |
| Protector | 1 | Ward a participant and perform one ghost intervention after death |
| Medic | 1 | Treat injuries using medical kits and a healing skill challenge |
| Trapper | 1 | Place limited traps that reveal, slow, or interrupt a monster |
| Medium | 1 | Receive limited structured information from ghosts |
| Guard | 1 | Guard a participant or location and absorb or interrupt an attack |
| Camper | 3 | Complete work, search, survive, discuss, and vote without a special power |

Role counts scale with roster size. Every valid match has exactly one Murderer. Small
matches preserve the Detective first, then add defensive and information roles as the
roster grows. Ordinary Campers have no supernatural or investigative ability.

### Role rules

- The **Detective** investigates one participant per day and receives a suspicion band,
  never an exact role. The Detective has limited examinations for blood, footprints,
  attack traces, and other clues. Only the Detective can mark evidence as officially
  verified real or fake. The Murderer can frame the Detective.
- The **Protector** selects a living ward during the day. Protection can interrupt one
  planned attack. After becoming a ghost, the Protector retains one intervention for the
  round: it saves the planned victim but leaves that victim injured. Protection never
  grants permanent immunity.
- The **Medic** uses a medical kit on another living participant and completes a
  server-validated skill challenge. A successful treatment removes one serious injury.
  Ghosts cannot heal living participants.
- The **Trapper** carries a limited number of reusable or consumable monster traps.
  Correct placement can reveal, slow, interrupt, or leave evidence from a monster.
- The **Medium** can perceive ghosts and request a small number of structured signals.
  Ghosts know the Murderer's identity, but communication is deliberately constrained so
  the Medium cannot simply publish the answer.
- The **Guard** protects one participant or defensible location for a limited interval.
  A successful interception stops the immediate lethal result and may injure the Guard.
- The **Murderer** chooses a victim at the end of daytime, selects the night's monster
  transformation, can plant convincing fake evidence, and may frame another participant.
  Monster attacks risk leaving real evidence.

## Participant and computer-player rules

Humans and computer players use the same participant and action contracts. Computer
players are not decorative NPC names; they can complete objectives, collect and discuss
evidence, use role abilities, survive, attack, lie, and vote.

Computer-player difficulty levels are Beginner, Average, and Expert. Each computer
player has a stable personality, observations, memories, trust relationships, suspicion,
and a willingness to lie when its role permits. They use deterministic utility-based
decision policies; game outcomes do not depend on an external language model.

Late joiners spectate and enter the next-round queue. Disconnect handling must preserve a
valid match by replacing participants with computer control when possible.

## Round loop

1. **Lobby** — humans join, ready up, and empty seats are filled by computer players.
2. **Morning briefing** — the public scenario is introduced and hidden roles are sent
   privately.
3. **Daytime** — participants explore, prepare defenses, complete consequential camp
   work, search rooms and objects, trade equipment, and use daytime role abilities.
4. **Murder planning** — the Murderer chooses a valid victim, frame target, location,
   and monster transformation.
5. **Night transformation** — camp structures merge with an abandoned town and the
   Murderer becomes the selected monster.
6. **Night survival and investigation** — the monster hunts directly while campers use
   equipment, rescue injured participants, gather evidence, and identify counterplay.
7. **Campfire** — the monster is contained, the shared evidence board is reviewed, and
   living participants make one accusation.
8. **Resolution** — the server resolves the accusation, survivor state, and team outcome.
9. **Rewards** — immutable round results award XP, role mastery, earned camp tokens, and
   eligible cosmetics before the town resets with a new mystery.

Incorrect accusations give the Murderer a major advantage. The Murderer wins by escaping
the accusation or eliminating enough campers that the camp can no longer stop the hunt.
The campers win by surviving and correctly removing the Murderer. Endings vary according
to evidence quality, objectives, injuries, and survivors.

## Health, death, and ghosts

- Living health states are Healthy and Injured. A second serious injury kills.
- Injured participants move more slowly and leave blood or track evidence.
- Medical kits are single-use and must be used by another living participant.
- A murdered or otherwise eliminated participant immediately returns as a ghost.
- Ghosts learn the Murderer's identity but cannot complete living objectives, carry
  physical equipment, heal, collect ordinary evidence, or vote.
- Ghost collision, visibility, interaction, and communication are server-controlled.

## Evidence and deduction

Every generated mystery includes enough authentic evidence to support a correct
deduction, plus plausible fake clues and conflicting witness accounts. Evidence is hidden
inside searchable rooms and objects rather than always appearing at fixed road markers.

The evidence board records:

- clue and discovery details;
- finder and chain of custody;
- related locations, attacks, tools, monsters, and suspects;
- participant notes and suspect labels;
- Detective verification state and confidence.

Posted evidence cannot be stolen or destroyed. The Murderer can add convincing fakes.
Culprit evidence and monster-identification evidence are separate channels. Ordinary
clues narrow possibilities; they do not print the Murderer's name.

## Inventory and equipment

Each participant has 15 inventory slots. Server-owned item instances can be equipped,
used, traded, dropped, or recovered from dead players.

The launch equipment set includes:

- flashlight and UV light;
- laser projector;
- camera;
- Spirit Box;
- thermometer;
- audio recorder;
- EMF reader or scanner;
- monster traps;
- flare or camp lantern;
- single-use medical kits.

The server validates ownership, equipped state, charges, durability, cooldown, phase,
range, direction, line of sight, and target before applying an item action.

## Monster roster

Each monster is a separate one-to-one visual target. Monster designs must never be
combined.

| Monster | Signature play | Primary counterplay |
|---|---|---|
| Baby Alien | Fast crawling, low routes, leap, and acidic denial | Open ground and interrupting light |
| Screamer | Directional scream disables electronics and reveals targets | Break range or line of sight; exploit recovery |
| Wendigo | Scent tracking, voice mimicry, and a straight charge | Fire, flares, and staying grouped |
| Shadow Monster | Shadow-node movement and strength near failed lights | Sustained direct light |
| Chupacabra | Blood tracking, long pounce, and injured-player latch | UV or direct flashlight burst |
| Dullahan | Accelerates while maintaining sight and withers surroundings | Break line of sight early |
| Entity | Teleports between anchors and distorts senses | Read teleport silhouettes and deny anchors |
| Banshee | Wail causes fear, blur, and disorientation; senses the injured | Interrupt the wail or leave its radius |

## World and NPC rules

The daytime camp uses weathered Appalachian-style cabins, forest paths, activity spaces,
a counselor lodge, generator, supplies, and campfire. At night, authored town districts
materialize through and around the camp: main road, residential quarter, town square,
general store, gas station, industrial district and tunnels, water-tower neighborhood,
police station and evidence room, and deserted outskirts.

The six approved counselor references become distinct adult counselor NPCs. NPC,
building, cabin, and environment references may be mixed into original designs. NPCs
follow schedules, become witnesses or suspects, flee or hide during attacks, remember
observations, and provide fixed moderated dialogue.

## Progression and fairness

Profiles store XP, earned camp tokens, role mastery, upgrade ranks, owned and equipped
cosmetics, settings, statistics, and idempotent reward receipts. Upgrades are capped,
modest, and situational so permanent progression does not reveal roles or create
pay-to-win power gaps.

The first release contains no MarketplaceService integration, game passes, developer
products, Robux prices, premium multipliers, paid currency, or purchase buttons.

