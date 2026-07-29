# CAMP-Mystery — Game Design Document

This document is the production reference for the first playable release of
CAMP-Mystery. It is intended for game design, engineering, UI, environment art,
character art, animation, audio, QA, and live-operations planning.

Source authority is applied in this order:

1. Runtime types, shared configuration, and server/client services define implemented
   behavior.
2. `docs/PRODUCT_SPEC.md` defines product intent where the runtime does not encode a
   presentation or asset decision.
3. This GDD explains those facts in production language. When intent and implementation
   differ, the difference is called out instead of being silently resolved.

Two naming corrections are important:

- The runtime has **nine** phase identifiers, not six or eight:
  `Lobby`, `RoleReveal`, `Day`, `MurderPlanning`, `NightTransform`,
  `Investigation`, `Campfire`, `Resolution`, and `Rewards`.
- The art-facing world has ten recognizable location clusters. The authoritative
  `WorldManifest` represents them as Camp plus seven night districts because the
  General Store and Gas Station are contained by `TownSquare`, and the tunnels are
  contained by `IndustrialDistrict`.

## 1. Concept

CAMP-Mystery is a social-deduction survival mystery for Roblox. A group arrives at an
Appalachian-style summer camp, prepares during daylight, and discovers that one of its
members is the Murderer. At night the camp merges with an abandoned town, the Murderer
transforms into one of eight monsters, and the group must survive while building two
cases:

- Who is the human culprit?
- Which supernatural form is hunting the camp?

The design combines cooperative objectives, asymmetric hidden roles, authored evidence,
NPC witness interviews, direct monster play, survival combat, and a single final
accusation. Ordinary clues narrow candidate sets rather than printing an answer.
Authentic evidence is always sufficient for deduction, while planted clues and mistaken
witnesses create controlled uncertainty.

### Release pillars

1. **Deduction over guessing.** The correct culprit and monster can be reached by
   intersecting authentic clues, witness accounts, observed behavior, and equipment
   readings.
2. **A dangerous but readable night.** Every monster has a distinct movement model,
   evidence profile, attack pattern, and counterplay.
3. **Every participant matters.** Humans and computer players share the same participant
   and action contracts. Campers without a special role still complete objectives,
   collect evidence, rescue teammates, discuss, and vote.
4. **Failure creates information.** Attacks, traps, status effects, device failures,
   injuries, and interrupted hunts can all expose the threat.
5. **Fair permanent progression.** XP, role mastery, earned upgrades, cosmetics, and
   Camp Tokens reward play without revealing hidden roles or introducing paid power.

### Match shape

- One to twelve humans may enter matchmaking.
- The target roster is ten participants for one through ten humans and twelve
  participants for eleven or twelve humans.
- A 150-second fill window adds unique computer-player profiles to empty slots.
- Match modes are `Solo` for one human, `Small` for two through five, `Standard` for six
  through ten, and `Full` for eleven or twelve.
- A standard ten-participant role distribution is one Murderer, one each of Detective,
  Medic, Guard, Protector, Trapper, and Medium, plus three Campers.
- Late joiners observe the active round and enter the next-round queue.
- A disconnected locked-roster human can be replaced by a bot while participant state,
  role, mystery references, votes, inventory, statuses, and abilities are transferred.
- The authored round excluding the lobby lasts 985 seconds (16:25) if no phase ends
  early. Including the full lobby fill window, the maximum configured cycle is 18:55.

### Audience and tone

The intended tone is spooky summer-camp mystery rather than graphic horror. Visual and
audio production should emphasize fog, failing light, distant movement, damaged civic
spaces, uncertain testimony, and escalating pursuit. Monsters must remain visually
separate one-to-one designs; silhouettes or mechanics from different monsters must not
be combined.

## 2. Core Loop (phase sequence, win conditions)

### Player loop

1. Join the lobby, ready up, and review the roster.
2. Privately receive a role and its goal.
3. Complete three shared camp objectives and choose equipment during the day.
4. If Murderer, lock a victim, monster, frame target, and attack location.
5. Relocate as the abandoned town appears.
6. Search seven evidence sockets, interview counselors, operate equipment, use role
   abilities, evade or attack, and keep enough campers alive.
7. Return to the campfire, compare the culprit and monster evidence channels, and lock
   one accusation per living eligible voter.
8. Reveal votes and resolve the winner.
9. Receive idempotent XP, Camp Tokens, role mastery, statistics, and eligible unlocks.

### Phase progression

```text
Lobby → RoleReveal → Day → MurderPlanning → NightTransform
      → Investigation → Campfire → Resolution → Rewards → Lobby
```

Phases can end early:

- `Day` shortens to approximately one more second when all three shared objectives are
  complete.
- `Investigation` shortens to approximately two more seconds only after at least the
  configured evidence goal is represented and every generated mystery clue is found.
- `Campfire` shortens to approximately one more second once all eligible voters vote.
- Elimination victory sets the current phase end time to the server's current time.

### Camper-team win conditions

The Campers win when either condition is true:

- The final accusation has a unique top target and that target is the Murderer.
- The Murderer is no longer alive before the final accusation.

On a correct accusation, the server eliminates the culprit and records the result:
`The camp correctly exposed the Murderer.`

### Murderer-team win conditions

The Murderer wins when either condition is true:

- The accusation is tied, absent, or targets the wrong participant.
- One or fewer living, non-ghost Camper-team participants remain.

A tied vote produces no accused participant; the Murderer escapes. The server does not
run a runoff vote.

### Round goals and success quality

`RoundConfig` exposes a goal of three objectives and three evidence discoveries. Those
values drive the primary UI and phase acceleration, but a high-quality Camper result
also depends on:

- keeping teammates alive;
- separating culprit clues from monster clues;
- finding all generated mystery clues;
- interviewing the four counselors assigned witness accounts;
- identifying planted or mistaken information;
- using monster-specific counterplay; and
- voting for the culprit rather than merely identifying the monster.

## 3. Roles (all 8, with full descriptions and abilities)

The eight playable hidden roles are listed below. `Spectator` is a technical observer
role and is not one of the eight hidden roles.

### Standard distribution and scaling

Role assignment always starts with one `Murderer`. With at least two total
participants, special Camper-team roles are added in this order:
`Detective`, `Medic`, `Guard`, `Protector`, `Trapper`, `Medium`. Remaining slots become
`Camper`. At ten participants this yields one of every special role and three Campers.

All participants begin with a Flashlight. Role loadouts add:

| Role | Additional starting equipment |
|---|---|
| Camper | EMF Reader |
| Detective | UV Light and Camera |
| Medic | Two Medical Kits |
| Trapper | Two Monster Traps |
| Medium | Spirit Box |
| Guard | Flare Lantern |
| Protector | Flare Lantern |
| Murderer | No additional item |

Inventory capacity is 15 item instances. Items are server-owned and validate ownership,
equipped state, charges, durability, cooldown, range, line of sight, and target.

### Camper

**Team:** Campers  
**Purpose:** Complete camp jobs, use general equipment, collect evidence, keep other
campers informed, survive, and help expose the Murderer.

**Resourcefulness** (`camp-resourcefulness`)

- Catalog cooldown: 0 seconds.
- Uses: unlimited.
- The ability represents ordinary objective and equipment competence; it does not grant
  a supernatural or investigative reveal.
- The current runtime has no separate `UseRoleAbility` branch for this ID. Camper value
  is delivered through objectives, equipment, evidence, discussion, rescue, and voting.

### Detective

**Team:** Campers  
**Purpose:** Analyze evidence and identify contradictions without receiving an exact
role reveal.

**Analyze Evidence** (`analyze-evidence`)

- Catalog cooldown: 20 seconds.
- Maximum: 3 committed participant analyses per round.
- Available for participant analysis during `Day` and `Investigation`.
- A participant analysis returns a suspicion band. Murderers return `High` in most
  deterministic cases and `Moderate` in the remaining cases; innocents return `Low` in
  most cases and `Moderate` in the remaining cases.
- The ability can also verify posted evidence. Only a living Detective can convert
  `Unverified` to `VerifiedReal` or `VerifiedFake`.
- Verification never exposes hidden suspect weights or the culprit directly.

Implementation note: participant analysis commits the catalog use and cooldown.
Evidence verification is routed directly through `EvidenceService` and does not consume
that same catalog use in the current runtime.

### Medic

**Team:** Campers  
**Purpose:** Remove serious injuries and keep the group above the Murderer's
elimination threshold.

**Field Treatment** (`field-treatment`)

- Catalog cooldown: 20 seconds.
- Maximum: 3 uses per round.
- Available during `Day` and `Investigation`.
- Requires the Medic to use an equipped, charged Medical Kit on another living injured
  participant.
- The runtime validates a successful skill-challenge result, removes one serious
  injury, restores `Healthy`, and returns health to maximum.
- The healer cannot treat itself. Ghosts and dead participants cannot heal or be healed.
- Each Medical Kit has one charge and a 10-stud maximum target range.

### Trapper

**Team:** Campers  
**Purpose:** Control dangerous routes and turn monster movement into information.

**Warning Trap** (`place-warning-trap`)

- Catalog cooldown: 15 seconds.
- Maximum: 3 placements per round.
- Available during `Day` and `Investigation`.
- A location-bound trap becomes an active server record.
- When triggered, it reports the owner and triggering participant, reveals whether the
  trigger was the Murderer, and slows the Murderer for 4 seconds or a non-Murderer for
  1 second.
- The `careful-reset` upgrade can deterministically recover a triggered trap; otherwise
  it becomes inactive.
- The separate Monster Trap item has one charge, a 4-second item cooldown, and a
  12-stud use range.

### Medium

**Team:** Campers  
**Purpose:** Convert ghost presence into limited structured information without letting
the dead publish the culprit's identity.

**Spirit Sense** (`spirit-sense`)

- Catalog cooldown: 30 seconds.
- Maximum: 2 signals per round.
- Available during `Investigation` and `Campfire`.
- Requires at least one ghost.
- Returns one deterministic structured signal from the current signal bank:
  - the threat walked among the camp before night;
  - one shared clue may have been planted; or
  - the attacker favored an isolated target.
- The signal includes the current ghost count but not the Murderer's identity.

### Guard

**Team:** Campers  
**Purpose:** Protect another participant for a limited interval and intercept one
hostile action.

**Guard Post** (`guard-post`)

- Catalog cooldown: 25 seconds.
- Maximum: 2 uses per round.
- Available during `Day` and `Investigation`.
- The Guard must choose another living Camper-team participant.
- The base guard interval is 45 seconds.
- One qualifying attack consumes the guard and is blocked. The configured callback
  applies an interception consequence to the Guard.
- The Guard cannot target itself, and replacing a guard target replaces the Guard's
  previous active assignment.

### Protector

**Team:** Campers  
**Purpose:** Ward another participant against one hostile action and retain a single
post-death intervention.

**Protection** (`protect-participant`)

- Catalog cooldown: 35 seconds.
- Maximum while living: 2 uses per round.
- Available while living during `Day` and `Investigation`.
- The Protector must select another living Camper-team participant.
- One qualifying attack consumes the ward and is blocked.
- After becoming a ghost, the Protector may make one additional intervention during
  `Investigation`. It blocks the lethal result but leaves an uninjured ward at injury
  level 1, `Injured`, and no more than 50 health.
- The ghost intervention is tracked separately and can be used only once per round.

### Murderer

**Team:** Murderer  
**Purpose:** Plan the murder, choose the monster transformation, frame an innocent,
mislead the group, injure or eliminate campers, and survive the final accusation.

**Monster Transformation** (`monster-transformation`)

- Catalog cooldown: 0 seconds.
- Maximum: 1 locked plan per round.
- During `MurderPlanning`, selects a living Camper victim and one of the eight monsters.
- The complete plan also carries a frame participant and one of the seven searchable
  attack locations. If the player does not submit a valid plan, the server has a
  deterministic default victim, frame target, location, and round-rotated monster.

**Hostile Attack** (`hostile-attack`)

- Role-catalog cooldown: 20 seconds.
- Role-catalog maximum: 2 uses per round.
- Product intent is a hostile action against an eligible target.
- Actual night attacks are executed through the selected monster's named abilities,
  which use their own range, line-of-sight, stamina, status, and cooldown rules. The
  generic `hostile-attack` ID is not routed by `GameRuntimeService`.

**Plant False Evidence** (`plant-false-evidence`)

- Catalog cooldown: 30 seconds.
- Maximum: 1 use per round.
- Available during `MurderPlanning`.
- Selects a valid non-culprit frame target and redirects the planted evidence toward
  that participant. The chosen target replaces the default frame in the murder plan,
  so the round's planted mystery clues point at the deliberate target.
- Deliberate planting also activates the Controlled Trace upgrade: each rank removes
  the decoy suspects from one more planted mystery clue (rank 3 additionally narrows
  the mistaken witness account). Authentic clues are never altered.
- The runtime enforces the once-per-round use. The current direct planning branch does
  not apply the catalog's 30-second cooldown.

### Spectator technical role

Spectators are on team `Observers`, have no abilities, cannot perform physical actions,
collect evidence, use living role powers, or vote. Late joiners remain spectators until
the next roster lock. This role is deliberately excluded from the eight-role game
balance.

## 4. Monsters (all 8, with full descriptions and abilities)

Only the Murderer owns and activates monster abilities. Every activation is
server-validated against round ID, monotonic request sequence, active lifecycle,
ownership, phase, cooldown, remaining stamina, target eligibility, range, and required
line of sight. All current abilities are restricted to `Investigation`.

Stamina is set to the monster's maximum when selected and again when planning starts.
The current service contains no passive stamina regeneration, so the listed pool is a
finite ability budget for the hunt.

### Baby Alien

**Runtime ID:** `BabyAlien`  
**Fantasy:** A small extraterrestrial hunter built for low routes, sudden leaps, and
close ambushes. It has fast bursts, can use narrow routes, and is weakest in open,
well-lit space.  
**Stamina:** 100  
**Evidence profile:** Tiny Tracks, Acidic Residue, Laser Motion  
**Recommended counterplay:** Flashlight and Laser Projector.

| Ability | Cooldown | Range | Cost | Target / LOS | Effects |
|---|---:|---:|---:|---|---|
| Scuttle Leap | 7s | 34 studs | 25 | Position; LOS required | `BabyAlienLeap` mobility; Laser Motion evidence |
| Acid Swipe | 4s | 7 studs | 18 | Participant; LOS required | 22 attack amount; Acidic Residue evidence |

### Screamer

**Runtime ID:** `Screamer`  
**Fantasy:** A direct pursuer whose directional scream disrupts investigation devices,
disorients a target, and creates a recovery window.  
**Stamina:** 110  
**Evidence profile:** Corrupted Audio, EMF Spike, Device Interference  
**Recommended counterplay:** Break range or line of sight, then escape during recovery;
use Audio Recorder and EMF Reader.

| Ability | Cooldown | Range | Cost | Target / LOS | Effects |
|---|---:|---:|---:|---|---|
| Disrupting Scream | 14s | 42 studs | 38 | Participant; LOS required | Equipment Disabled 6s; Disoriented 3s; Corrupted Audio evidence |
| Claw Strike | 4s | 7 studs | 16 | Participant; LOS required | 24 attack amount |

### Wendigo

**Runtime ID:** `Wendigo`  
**Fantasy:** A forest hunter that isolates campers with mimicry before committing to a
straight charge.  
**Stamina:** 120  
**Evidence profile:** Antler Scrape, Mimic Recording, Freezing Trace  
**Recommended counterplay:** Stay grouped and use campfire or flare light; carry Audio
Recorder and Flare Lantern.

| Ability | Cooldown | Range | Cost | Target / LOS | Effects |
|---|---:|---:|---:|---|---|
| Forest Charge | 11s | 58 studs | 34 | Position; LOS required | `WendigoCharge` mobility; Antler Scrape evidence |
| Mimic Mark | 15s | 48 studs | 28 | Participant; LOS not required | Marked 12s; Mimic Recording evidence |

### Shadow Monster

**Runtime ID:** `ShadowMonster`  
**Fantasy:** A smoky silhouette that travels between authored shadow nodes and is
strongest around failed lights.  
**Stamina:** 105  
**Evidence profile:** Photo Silhouette, Light Drain, Black Residue  
**Recommended counterplay:** Sustain direct light to make it visible and slower; use
Flashlight and Camera.

| Ability | Cooldown | Range | Cost | Target / LOS | Effects |
|---|---:|---:|---:|---|---|
| Shadow Step | 9s | 45 studs | 27 | Position; LOS not required | `ShadowNodeStep` mobility; Black Residue evidence |
| Light Drain | 13s | 32 studs | 32 | Participant; LOS required | Vision Distortion 6s; Light Drain evidence |

### Chupacabra

**Runtime ID:** `Chupacabra`  
**Fantasy:** A skeletal ambush predator that tracks blood, pounces over distance, and
latches onto injured campers.  
**Stamina:** 115  
**Evidence profile:** Blood Trail, Claw Marks, UV Residue  
**Recommended counterplay:** Use UV or direct flashlight on a latched/marked teammate;
carry UV Light, Flashlight, and Medical Kit.

| Ability | Cooldown | Range | Cost | Target / LOS | Effects |
|---|---:|---:|---:|---|---|
| Blood Pounce | 10s | 54 studs | 35 | Participant; LOS required | `ChupacabraPounce` mobility; 26 attack amount; Bleeding 10s |
| Latch | 16s | 6 studs | 30 | Participant; LOS required | Latched 4s; Claw Marks evidence |

### Dullahan

**Runtime ID:** `Dullahan`  
**Fantasy:** A headless pursuer that accelerates while maintaining sight and withers the
space around its target.  
**Stamina:** 130  
**Evidence profile:** Freezing Temperature, Headless Photograph, Laser Silhouette  
**Recommended counterplay:** Break line of sight before it reaches full pursuit speed;
use Camera, Laser Projector, and Thermometer.

| Ability | Cooldown | Range | Cost | Target / LOS | Effects |
|---|---:|---:|---:|---|---|
| Relentless Pursuit | 12s | 70 studs | 36 | Participant; LOS required | `DullahanPursuit` mobility; Fear 5s |
| Freezing Touch | 7s | 8 studs | 22 | Participant; LOS required | 20 attack amount; Slowed 5s; Freezing Temperature evidence |

### Entity

**Runtime ID:** `Entity`  
**Fantasy:** A floating presence that teleports among anchors, leaves a brief
laser-readable arrival silhouette, and distorts perception.  
**Stamina:** 100  
**Evidence profile:** Spirit Box Response, Handprint, Laser Silhouette  
**Recommended counterplay:** Read arrival silhouettes and move away from anchors; use
Spirit Box, UV Light, and Laser Projector.

| Ability | Cooldown | Range | Cost | Target / LOS | Effects |
|---|---:|---:|---:|---|---|
| Anchor Teleport | 8s | 52 studs | 26 | Position; LOS not required | `EntityAnchorTeleport` mobility; Laser Silhouette evidence |
| Distort | 12s | 38 studs | 30 | Participant; LOS not required | Vision Distortion 7s; Disoriented 4s; Spirit Box Response evidence |

### Banshee

**Runtime ID:** `Banshee`  
**Fantasy:** A floating apparition whose wail attacks the senses and whose marks expose
vulnerable campers.  
**Stamina:** 110  
**Evidence profile:** Recorded Wail, Reflection Apparition, Death Mark  
**Recommended counterplay:** Interrupt or leave the wail radius; use Audio Recorder,
Camera, and Medical Kit.

| Ability | Cooldown | Range | Cost | Target / LOS | Effects |
|---|---:|---:|---:|---|---|
| Mournful Wail | 14s | 46 studs | 38 | Participant; LOS not required | Fear 8s; Disoriented 6s; Recorded Wail evidence |
| Death Mark | 18s | 55 studs | 32 | Participant; LOS not required | Marked 14s; Death Mark evidence |

## 5. Phases (all actual phase identifiers)

The production state machine has nine phases. Normal duration is used in a published
server; the shorter Studio duration supports development and playtest iteration.

| Order | Identifier | Display name | Normal | Studio | Primary behavior |
|---:|---|---|---:|---:|---|
| 1 | `Lobby` | Waiting at Camp | 150s | 40s | Ready state, matchmaking fill, observer queue, world reset |
| 2 | `RoleReveal` | Roles Revealed | 15s | 38s | Private role briefing and role tutorial |
| 3 | `Day` | Daytime Objectives | 240s | 75s | Three camp objectives, equipment, interviews, daytime role abilities |
| 4 | `MurderPlanning` | Something Is Being Planned | 60s | 40s | Murderer locks victim, monster, frame target, and location |
| 5 | `NightTransform` | The Town Is Appearing | 20s | 36s | Generate mystery, transform world, relocate safely, spawn monster |
| 6 | `Investigation` | Night Investigation | 480s | 90s | Monster hunt, combat, searches, interviews, equipment, role abilities |
| 7 | `Campfire` | Campfire Vote | 120s | 60s | Stop monster, clear world evidence objects, review board, vote |
| 8 | `Resolution` | Mystery Resolution | 30s | 40s | Resolve accusation, reveal votes, culprit, monster, and result |
| 9 | `Rewards` | Round Rewards | 20s | 38s | Apply idempotent progression, end round, send counselors off duty |

### Phase details

**Lobby**

- The camp is in its daytime state.
- Players ready up while matchmaking aims for ten or twelve participants.
- The next mystery cannot begin without at least one human.
- Returning from `Rewards` resets world, character, lifecycle, and round presentation.

**RoleReveal**

- The server sends each participant its private role description, team, and ability IDs.
- Other participants receive only public alive/ghost/controller information.
- This phase is the implemented morning briefing; there is no separate `Morning`
  identifier.

**Day**

- Objective prompts become active for Stack Firewood (`firewood`), Repair Generator
  (`generator`), and Secure Supplies (`supplies`).
- Objectives are server-validated within 14 studs and can be completed once.
- Players equip, transfer, drop, and use items, interview counselors, and use authorized
  daytime role abilities.
- Completing all three shared objectives accelerates sunset.

**MurderPlanning**

- Objective prompts turn off.
- The monster lifecycle changes to planning.
- Only the Murderer may submit or revise the night plan.
- The plan requires an eligible living Camper victim and known monster; location and
  frame target are validated separately.

**NightTransform**

- The seeded mystery is generated from the locked culprit, monster, frame target,
  participant suspects, and six counselors.
- The world enters its night transformation and safe-volume relocation path.
- The selected monster character spawns at the configured hunt entry.

**Investigation**

- Seven evidence sockets become active.
- The monster lifecycle becomes `Active`.
- Monster abilities, attacks, physical evidence discovery, equipment readings,
  counselor interviews, and night role powers are enabled.
- The complete generated clue set must remain reachable and deducible.

**Campfire**

- Searchable world evidence is cleared and the monster is stopped/removed.
- Living non-ghost, non-Spectator participants may cast exactly one locked vote.
- Evidence and witness accounts remain available in the notebook and board.

**Resolution**

- If elimination has not already selected a winner, the server resolves the vote.
- Votes become public only after resolution.
- Culprit, monster, victim, winner, and result message are included in the round
  snapshot.

**Rewards**

- Human participants receive a unique receipt keyed by round and user.
- Rewards apply once even if a response is repeated.
- Counselors become `Unavailable` and report being off duty.
- The next transition returns the world to `Lobby`.

## 6. Evidence & Mystery System

The mystery has two independent deduction channels:

- **Culprit evidence** narrows human suspects.
- **Monster evidence** narrows supernatural candidates.

Discovering the monster does not identify the Murderer, and identifying suspicious human
behavior does not identify the monster.

### Generated mystery package

Each round generates a deterministic package from the round seed:

| Content | Count | Authenticity |
|---|---:|---|
| Culprit clues | 3 | Authentic |
| Planted culprit clues | 2 | Planted |
| Monster clues | 3 | Authentic |
| Truthful culprit witnesses | 2 | Authentic; reliability 0.76–0.94 |
| Mistaken culprit witness | 1 | Mistaken; reliability 0.34–0.54 |
| Monster witness | 1 | Authentic; reliability 0.65–0.85 |

Generation requires at least four voting suspects and at least four counselor witnesses.
The deduction audit fails closed unless:

- authentic culprit-clue candidate sets intersect on the culprit;
- authentic monster-clue candidate sets intersect on the selected monster;
- at least two planted clues exist; and
- at least one conflicting witness exists.

The mystery title is selected from six authored titles, including *The Bell After
Midnight*, *Fog Over Black Pine*, and *Last Call at the General Store*.

### Evidence records and authenticity

The runtime also maintains an evidence-board record model. Its channels are `Culprit`
and `Monster`; its internal authenticity states are `Real`, `Fake`, `Ambiguous`, and
`Contaminated`. Public records deliberately omit raw authenticity and hidden weights.
Detective verification exposes only `VerifiedReal` or `VerifiedFake`.

Baseline board evidence contains:

- Partial Footprint — real culprit evidence.
- Torn Fiber — real culprit evidence.
- Conflicting Statement — ambiguous culprit evidence.
- Supernatural Trace — real monster evidence.
- Equipment Reading — real monster evidence.
- Dropped Camp Token — fake culprit evidence when a valid frame target exists.

Attack evidence may add a Blood Trail or Partial Footprint. Evidence-capable devices may
add Supernatural Trace records during `Investigation`.

### Discovery and chain of custody

- Physical evidence is hidden at searchable rooms and objects.
- A living, non-ghost participant must be within 14 studs of the evidence socket.
- First discovery locks the finder, display name, location, discovery time, and initial
  chain of custody.
- Discovered evidence is posted immediately and cannot be stolen or destroyed.
- Living participants may add notes up to 160 characters.
- The board groups public records by culprit and monster channels.
- Each participant also retains private evidence knowledge with confidence and discovery
  time; reconnect state restores that knowledge.

### Search sockets

The seven runtime evidence aliases are:

1. `main-road-clue-a` — Abandoned Sedan.
2. `residential-bedroom-clue` — Ransacked Bedroom.
3. `square-gas-station-clue` — Gas Station Counter.
4. `industrial-machine-clue` — Factory Press.
5. `water-tower-base-clue` — Water Tower Base.
6. `police-evidence-room-clue` — Police Evidence Locker.
7. `outskirts-company-house-clue` — Company House Cellar.

Generated clues choose from authored valid-location lists and attempt to avoid duplicate
locations. Multiple hidden clues at the same location can be disclosed by one valid
search.

### Monster-identification evidence

The private monster rule contains three evidence IDs, while the public catalog presents
human-readable evidence. Monster-specific mystery clues intentionally overlap candidate
sets. Examples include:

- low tracks shared by Baby Alien, Chupacabra, and Shadow Monster;
- directional audio shared by Screamer, Banshee, and Wendigo;
- frost signatures shared by Dullahan, Wendigo, and Entity; and
- anchor or silhouette evidence shared by Entity and Shadow Monster.

Players should identify a monster from the intersection of multiple signs, never one
dramatic clue.

## 7. Counselor NPCs (all 6, with behavior states)

Counselors are adult NPCs with fixed authored dialogue, phase schedules, threat
responses, memories, and possible witness/suspect roles. They are separate from computer
players in the match roster.

### Counselor roster

| ID | Counselor | Role | Bravery | Reliability | Character brief |
|---|---|---|---:|---:|---|
| `counselor-holloway` | Director Mara Holloway | Camp Director | 0.86 | 0.82 | Decisive longtime director; knows staff routes and emergency procedure |
| `counselor-ortiz` | Counselor Lena Ortiz | Health and Safety | 0.58 | 0.90 | Calm first-aid lead; notices injuries, timing, and behavior changes |
| `counselor-reed` | Counselor Miles Reed | Outdoor Skills | 0.78 | 0.76 | Practical trail expert; reads tracks and dislikes crowded discussions |
| `counselor-brooks` | Counselor Tessa Brooks | Arts and Activities | 0.46 | 0.72 | Observant; remembers clothing, voices, and small visual details |
| `counselor-chen` | Counselor Ivy Chen | Nature and Science | 0.62 | 0.94 | Methodical instrument user; checks readings for contamination |
| `counselor-finch` | Counselor Noah Finch | Waterfront and Logistics | 0.52 | 0.80 | Friendly logistics lead; knows equipment checkout history |

### Schedule matrix

Locations are listed from `Lobby` through `Rewards`.

| Counselor | Lobby | RoleReveal | Day | MurderPlanning | NightTransform | Investigation | Campfire | Resolution | Rewards |
|---|---|---|---|---|---|---|---|---|---|
| Holloway | Counselor Lodge | Campfire | Counselor Lodge | Generator | Campfire safe volume | Police safe lobby | Evidence board | Campfire | Counselor Lodge |
| Ortiz | Infirmary | Campfire | Infirmary | Supplies | Camp cabin hide | Residential safe porch | Campfire | Infirmary | Supplies |
| Reed | Trailhead | Campfire | Activity Field | Generator | Main-road safe entry | Outskirts safe road end | Campfire | Trailhead | Activity Field |
| Brooks | Craft Cabin | Campfire | Craft Cabin | Counselor Lodge | General-store hide | Town-square bandstand | Campfire | Craft Cabin | Craft Cabin |
| Chen | Nature Lab | Campfire | Nature Lab | Generator | Industrial loading bay | Police evidence room | Evidence board | Nature Lab | Nature Lab |
| Finch | Supplies | Campfire | Waterfront | Supplies | Water-tower shed | Water-tower platform | Campfire | Supplies | Waterfront |

Each entry also has an authored activity, such as Holloway maintaining the incident log,
Ortiz treating evacuees, Reed reading tracks, Brooks reconstructing the visual timeline,
Chen testing supernatural traces, and Finch tracking issued equipment.

### Behavior states

| State | Meaning and interaction |
|---|---|
| `Routine` | Following the normal phase schedule; dialogue allowed |
| `Witness` | Has a witness account or high-importance observation; dialogue allowed |
| `Suspect` | Added to the public suspect list; dialogue allowed |
| `Fleeing` | Moving along an emergency route; dialogue blocked |
| `Hiding` | Sheltering from an active threat; dialogue blocked |
| `Alert` | Reached a safe route after fleeing and is monitoring evacuees; dialogue allowed |
| `Unavailable` | Off duty after round end; dialogue blocked |

When both witness and suspect flags exist, `Suspect` is the base behavior. An observation
with importance at least 0.65 marks the counselor as a witness.

### Threat response

- A threat affects counselors at its location, or all counselors when severity is at
  least 0.8.
- A counselor flees when `bravery >= severity × 0.82`; otherwise the counselor hides.
- Destination selection is deterministic from round seed, counselor order, and current
  revision.
- A fleeing counselor becomes `Alert` on arrival. A hiding counselor remains `Hiding`.
- Clearing the threat restores `Suspect`, `Witness`, or `Routine` and the phase's
  scheduled activity.

Each counselor has two authored hide destinations and two flee/safe destinations. For
example, Holloway hides in the police cell or General Store and flees to the campfire or
police lobby; Finch hides in the water-tower shed or General Store and flees to the
water-tower platform or campfire.

### Dialogue and memory

Six dialogue topics are supported: `Greeting`, `Schedule`, `Observation`, `Monster`,
`Safety`, and `Suspicion`. Responses are fixed moderated lines selected
deterministically, not generative AI. A counselor with an assigned witness statement
uses that statement for `Observation`.

- Per-participant counselor dialogue cooldown: 1.5 seconds.
- Maximum retained memories per counselor: 12.
- Memory kinds: Schedule, Observation, Witness Account, Threat, Interview, and
  Suspicion.
- Dialogue is available during `Day`, `Investigation`, and `Campfire` when the NPC's
  behavior allows interaction.

## 8. Combat & Status Effects

### Health model

Participants begin alive, non-ghost, `Healthy`, at 100 health and injury level 0.

1. The first serious injury sets injury level 1, state `Injured`, and health to no more
   than 50.
2. A second serious injury eliminates the participant.
3. Elimination sets alive false, ghost true, state `Dead`, health 0, injury level 2, and
   drops every carried item.

An injured participant has a movement multiplier of 0.72. A successful Medic treatment
returns the participant to injury level 0, `Healthy`, and maximum health.

### Attack authorization and outcomes

Monster attacks are accepted only during `Investigation`. The attacker must be the
living, non-ghost Murderer; the target must be a different living, non-ghost Camper-team
participant.

| Outcome | Meaning | Evidence risk |
|---|---|---:|
| Rejected | Invalid round, phase, actor, target, range, LOS, cooldown, or stamina | 0 |
| Blocked | Protector or Guard consumes a defense; Interrupted Attack evidence emitted | 0.80 |
| Injured | First serious injury; Injury evidence emitted | 0.65 normally |
| Eliminated | Second serious injury; Lethal Attack evidence emitted | 0.65 normally |

The combat service accepts a `Reduced` defense result and assigns 0.90 evidence risk,
although no current role resolver returns `Reduced`.

The numeric attack amounts in monster rules are ability-effect metadata; the current
combat resolution applies the two-serious-injury model rather than subtracting those
amounts directly from participant health.

### Status effects

All statuses are server-timed and replace the prior instance of the same status on the
same participant.

| Status | Current source or consequence |
|---|---|
| `Bleeding` | Chupacabra Blood Pounce, 10s |
| `Disoriented` | Screamer 3s, Entity 4s, Banshee 6s |
| `EquipmentDisabled` | Screamer, 6s; blocks equipment except Medical Kit and Monster Trap |
| `Fear` | Dullahan 5s, Banshee 8s; removable with Flare Lantern |
| `Latched` | Chupacabra, 4s; removable from a target with UV Light or Flashlight |
| `Marked` | Wendigo 12s, Banshee 14s; removable from a target with UV Light or Flashlight |
| `Slowed` | Dullahan, 5s |
| `VisionDistortion` | Shadow Monster 6s, Entity 7s; removable with Flare Lantern |

### Equipment counterplay

| Item | Charges | Cooldown | Range | Design use |
|---|---:|---:|---:|---|
| Flashlight | 100 | 0.15s | 60 | Light routes; interrupt light-sensitive monsters; clear latch/mark |
| UV Light | 80 | 0.25s | 35 | Reveal UV traces; clear Chupacabra latch/mark |
| Laser Projector | 3 | 2s | 45 | Reveal motion and supernatural silhouettes |
| Camera | 12 | 1s | 80 | Capture reflections and silhouettes |
| Spirit Box | 8 | 2s | 25 | Capture structured supernatural responses |
| Thermometer | 100 | 0.5s | 16 | Capture abnormal/freezing temperatures |
| Audio Recorder | 6 | 2s | 40 | Capture screams, wails, and mimicry |
| EMF Reader | 100 | 0.5s | 24 | Detect interference and supernatural energy |
| Monster Trap | 1 | 4s | 12 | Reveal, slow, or interrupt a monster |
| Medical Kit | 1 | 5s | 10 | Remove one serious injury through the Medic |
| Flare Lantern | 1 | 6s | 32 | Temporary light/safe area; clears Fear and Vision Distortion |

## 9. Voting System

Voting is active only during `Campfire`.

### Eligibility

- Voter must be alive, non-ghost, and not a Spectator.
- Target must be alive, non-ghost, and not a Spectator.
- Self-voting is not explicitly forbidden by `VotingService`; the UI/action candidate
  flow normally encourages other suspects.
- Each eligible participant has one vote.
- A vote is locked immediately and cannot be changed.
- Ghosts do not vote.

### Visibility

During `Campfire`, the public round snapshot shows `votesCast` and `eligibleVoters`, so
the UI can display an authoritative `X/Y VOTED` count. Individual voter/target pairs
remain hidden until `Resolution` or `Rewards`.

### Resolution

1. Count votes by target.
2. Select the unique highest total.
3. If multiple targets share the highest total, set `tied = true` and accuse nobody.
4. Compare the accused participant with the culprit.

| Result | Winner |
|---|---|
| Unique top target is Murderer | Campers |
| Unique top target is innocent | Murderer |
| Tie for highest total | Murderer |
| No verdict / no accused target | Murderer |

When all eligible voters have cast, the phase ends early. Disconnect replacement
transfers both votes cast by the departed participant and votes targeting that
participant to the replacement participant so the locked round remains coherent.

## 10. Progression & Rewards

Progression is profile-backed and persistent. Profiles store total XP, Camp Tokens,
per-role mastery, upgrade ranks, owned/equipped cosmetics, lifetime statistics,
settings, tutorial completion, and recent reward receipt IDs.

### Per-round reward formulas

Let:

- `O = clamp(floor(objectivesCompleted), 0, 5)`
- `E = clamp(floor(evidenceCollected), 0, 5)`
- `W = 1` when the participant's team won, otherwise `0`
- `S = 1` when the participant survived alive and non-ghost, otherwise `0`

For a participating non-Spectator:

```text
Total XP       = 50 + 10O + 15E + 40W + 15S
Camp Tokens    = 10 +  2O +  3E +  8W +  2S
Role Mastery   = 30 +  5(O + E) + 30W
```

A non-participant receives zero. Each reward also increments rounds played by one;
wins, team-specific wins, survival, objectives, and evidence statistics increment from
the same validated grant. Reward receipts prevent duplicate application.

Maximum single-round grant at five objectives, five evidence, a win, and survival:

- 230 total XP.
- 45 Camp Tokens.
- 140 role mastery XP.

### Account level

- Starts at level 1 and caps at level 100.
- XP needed to advance from level `L` is `100 + 50(L - 1)`.
- Cumulative XP needed to reach level `L` is:

```text
100(L - 1) + 25(L - 1)(L - 2)
```

### Role mastery level

- Starts at level 1 and caps at level 25.
- Role XP needed to advance from role level `L` is `75 + 35(L - 1)`.
- Cumulative role XP needed to reach role level `L` is:

```text
75(L - 1) + 17.5(L - 1)(L - 2)
```

### Earned upgrades

Each role has one launch upgrade with a catalog cap of rank 3.

| Role | Upgrade | Base / added cost | Required mastery | Implemented runtime effect |
|---|---|---:|---:|---|
| Camper | Resourceful Packing | 100 / +75 | 1 | Starting loadout gains one FlareLantern per rank (self-cleanse Fear/VisionDistortion; no role-gated use path) |
| Medic | Steady Hands | 125 / +90 | 1 | Treatment cooldown −1s per rank |
| Trapper | Careful Reset | 125 / +90 | 1 | Trap cooldown −1s/rank; improves deterministic trap recovery |
| Medium | Clear Signal | 125 / +90 | 1 | Spirit Sense cooldown −2s/rank |
| Guard | Watchful Post | 125 / +90 | 1 | Guard cooldown −1s/rank and duration +3s/rank |
| Protector | Focused Ward | 125 / +90 | 1 | Protection cooldown −2s/rank |
| Detective | Methodical Review | 125 / +90 | 1 | Participant-analysis cooldown −2s/rank |
| Murderer | Controlled Trace | 150 / +100 | 1 | After planting false evidence: rank 1–2 strip decoys from one/both planted mystery clues, rank 3 also narrows the mistaken witness account |

The next-rank token cost is:

```text
baseCost + costPerRank × currentRank
```

Upgrades are modest and situational. They must not reveal hidden roles, remove required
evidence, increase a role's use count, or create unavoidable monster attacks.

### Cosmetics and monetization

Launch cosmetics include default Camp Standard outfit, New Arrival title, and Wave
emote; earnable examples include Night Watch outfit (250 tokens), Clue Finder title
(level 5), and Campfire Story emote (150 tokens).

There is no launch MarketplaceService integration, game pass, developer product, Robux
price, paid currency, premium multiplier, or purchase button. Camp Tokens are earned
through play.

## 11. Map Locations (all 10)

The visual world transforms from a wooded camp into a merged abandoned town. The ten
art-facing clusters below are the product locations. The runtime topology maps them to
`Camp` plus seven `DistrictId` values.

| # | Player-facing location | Runtime area | Required gameplay landmarks |
|---:|---|---|---|
| 1 | CAMP-Mystery Camp | `Camp` | Cabins, counselor lodge, supply cabin, campfire safe volume, evidence board, objectives, monster tree-line spawn |
| 2 | Foggy Main Road | `MainRoad` | Camp/town links, abandoned sedan clue, witness, lamp shadow node, car hide, safe entry |
| 3 | Residential Quarter | `ResidentialQuarter` | Bedroom clue, alley shadow, closet hide, porch safe volume, road/outskirts links |
| 4 | Town Square | `TownSquare` | Fountain monster spawn, arcade shadow, bandstand safe volume, police/main-road links |
| 5 | General Store | Contained by `TownSquare` | Store interior/door, witness point, store hide; visually readable from the square |
| 6 | Gas Station | Contained by `TownSquare` | Last Stop Gas, counter clue, forecourt sightlines; visually separate from General Store |
| 7 | Industrial District and Tunnels | `IndustrialDistrict` | Factory/Mill No. 7, press clue, tunnel link/shadow, locker hide, loading-bay safe volume |
| 8 | Water-Tower Neighborhood | `WaterTowerNeighborhood` | Water tower, base clue, shed hide, platform safe volume, residential/industrial links |
| 9 | Police Station and Evidence Room | `PoliceStation` | Desk witness, evidence-locker clue, cell hide/monster point, safe lobby |
| 10 | Deserted Outskirts | `DesertedOutskirts` | Company House/cellar clue, lost witness, tree-line spawn, dead-tree shadow, road-end safe volume |

### Camp fallback layout

When authored map assets are absent, `ProductionMapService` builds a playable graybox:

- Pine Cabin, Creek Cabin, Counselor Lodge, and Supply Cabin.
- A central campfire with six seats and a safe-volume attribute.
- Stack Firewood, Repair Generator, and Secure Supplies objective stations.
- Forest paths, trees, rocks, spawn, prompts, and daylight lighting.

The counselor schedule also references Infirmary, Trailhead, Activity Field, Craft Cabin,
Nature Lab, Supplies, and Waterfront. These are authoritative narrative destinations
that the final authored Camp asset must represent or alias. The fallback graybox does
not currently build a separate model for each name.

### Night variants

The manifest supports three deterministic district orders:

- `TownVariantA` / Main Street — blocks the outskirts-industrial link.
- `TownVariantB` / Factory Detour — blocks the police-industrial link.
- `TownVariantC` / Outskirts First — blocks the water-tower-industrial link.

All variants retain every active district. Required socket tags are `TownSocket`,
`NPCSpawn`, `EvidenceSocket`, `MonsterSpawn`, `ShadowNode`, `HideSpot`, and
`SafeVolume`.

## 12. Bot AI Behavior

Computer players use deterministic utility policies; they do not call an external
language model. They use the same participant state, role, equipment, evidence, combat,
vote, and action validation as humans.

### Roster behavior

- Twelve unique bot profiles are available.
- Matchmaking selects unused profiles and fills to the target roster.
- A disconnected human can be replaced with an unused bot profile.
- If the human reconnects under the supported restore path, the replacement is removed
  and control can return without duplicating the roster slot.

### Difficulty tuning

| Difficulty | Decision quality | Memory limit | Lie skill | Minimum think | Jitter |
|---|---:|---:|---:|---:|---:|
| Beginner | 0.35 | 8 | 0.20 | 2.5s | up to 1.2s |
| Average | 0.65 | 16 | 0.55 | 1.5s | up to 0.7s |
| Expert | 0.90 | 24 | 0.85 | 0.8s | up to 0.35s |

Decision noise is `(1 - decisionQuality) × 20` in either direction, so higher
difficulty means more consistent utility choices rather than extra information.

### Personality and memory

Each bot has bravery, curiosity, sociability, honesty, aggression, and altruism values
from 0 to 1. These shape utility:

- altruism increases team-objective and role-support choices;
- curiosity increases evidence and information choices;
- bravery reduces the cost of risky actions;
- aggression increases Murderer attack utility;
- sociability increases discussion utility; and
- low honesty plus difficulty lie skill increases Murderer deception utility.

Memory kinds are Evidence, Observed Action, Statement, Injury, Vote, and Role Hint.
Memories track confidence, importance, subjects, relationships, time, and optional
expiry. Relationships start at trust 0.5 and suspicion 0. Observations can decrease
trust and increase suspicion. Vote utility then adds suspicion, subtracts trust, and
weights relevant memories.

### Allowed actions by phase

| Action | Phases |
|---|---|
| Complete objective | Day |
| Collect evidence | Investigation |
| Interview counselor | Investigation, Campfire |
| Use role ability | Day, MurderPlanning, NightTransform, Investigation, Campfire |
| Attack | Investigation; Murderer only |
| Discuss | Day, Investigation, Campfire |
| Vote | Campfire |
| Idle | All nine phases |

Dead bots may only idle, except a ghost Protector may use its intervention.

### Murderer behavior

The Murderer receives attack candidates during `Investigation`, a transformation-plan
candidate during `MurderPlanning`, and deceptive discussion candidates during social
phases. A lie target is the living non-Murderer with the best combination of existing
suspicion and low trust. The authored lie is a moderated fixed statement naming that
target, not freeform generated dialogue.

### Fairness requirements

- Bots cannot read private roles, hidden authenticity, or culprit state unless their
  role/action contract authorizes that knowledge.
- Beginner bots receive more decision noise, not deliberately invalid actions.
- Expert bots receive no impossible reaction speed or extra evidence.
- Bot actions still fail when server phase, range, ownership, cooldown, or eligibility
  validation fails.

## 13. Accessibility & Settings

Settings are persisted in the player profile and restored on rejoin.

### Defaults and ranges

| Setting | Default | Range / behavior |
|---|---:|---|
| Master volume | 1.0 | 0–1 |
| Music volume | 0.7 | 0–1 |
| Ambience volume | 0.8 | 0–1 |
| Effects volume | 0.9 | 0–1 |
| UI volume | 0.8 | 0–1 |
| Subtitles | On | Captions authored audio cues |
| Reduced motion | Off | Removes supported tweens, pulses, camera shake, and motion hints |
| Camera shake | On | Effective only when reduced motion is off |
| High-contrast evidence | Off | Yellow 3px outline and black text stroke on registered evidence UI |
| Mouse sensitivity | 1.0 | 0.1–3.0 |
| Controller sensitivity | 1.0 | 0.1–3.0 |
| Toggle sprint | Off | Persisted movement preference |
| Tutorial completed | Off | Prevents repeat onboarding after completion or skip |

Volume changes apply immediately to SoundGroups and are also sent to the profile.
Subtitles remain useful when a cue cannot play; the cue definitions include authored
captions such as evidence discovered, vote open, and monster nearby.

### Reduced-motion contract

- Supported motion helpers use zero duration or immediate property changes.
- Camera shake is canceled and cannot restart while reduced motion is active.
- Injury pulse, phase flash, pop feedback, overlays, and tutorial transitions must
  respect the root's `ReducedMotion` attribute.
- Critical information must never exist only as animation, color pulse, sound, or
  vibration.

### High-contrast and readable state

Evidence controls can be registered or scanned by name/attribute. High-contrast mode
adds a bright yellow outline and full black text stroke, restoring the original styling
when disabled. Health, ghost state, cooldowns, unread evidence, phase progress, vote
count, and interaction availability also have text or shape representations.

### Tutorial and guidance

The first-round tutorial has seven contextual steps:

1. Lobby — ready up and understand human/bot parity.
2. Role — read the private assignment.
3. Day — complete objectives and choose gear.
4. Investigation — search and survive.
5. Evidence — review both evidence channels.
6. Vote — lock the best-supported suspect.
7. Rewards — review progression and prepare for the next round.

Players can continue or skip. Completion is persisted. Phase tips supplement the
tutorial for `Day`, `MurderPlanning`, `NightTransform`, `Investigation`, `Campfire`, and
`Resolution`. Control hints are shown once per applicable phase per round and are
suppressed by reduced motion.

### Multimodal feedback

- UI and gameplay events use visual feedback plus optional sound.
- Supported `Gamepad1` devices receive Click, Impact, Danger, Celebrate, and Error
  vibration patterns.
- Monster dread can pulse the large motor when proximity intensity exceeds 0.7.
- Unsupported haptic devices silently no-op.
- The final experience requires keyboard/mouse, touch, controller-focus, subtitle,
  high-contrast, reduced-motion, and no-audio playtests.

## 14. Platform Support (PC/mobile/console)

The release promise is desktop, touch, and controller support from one responsive UI and
server-authoritative action model.

### Responsive layout

- Narrow layout activates below 560 viewport pixels.
- Compact layout activates below 850 pixels wide or 560 pixels high when not narrow.
- Top status, mission panel, menu, health, hotbar, interaction prompt, announcements,
  lobby panel, and toast region reposition rather than relying on a fixed desktop
  canvas.
- Settings sliders support mouse drag and touch drag.
- Buttons support mouse click, touch, and `ButtonA`.
- Modal focus is assigned through `GuiService` for controller navigation.

### PC controls

Implemented global bindings:

| Action | Input |
|---|---|
| Notebook | `N` |
| Settings | `F10` |
| Close modal | `Escape` |
| Use hotbar slot | `1` through `0` |
| World interaction | Proximity prompt's displayed keyboard key, normally `E` |

The game uses Roblox character movement for living participants. In ghost free-camera
mode, `WASD` moves horizontally, `E/Q` ascend/descend, Shift sprints, the mouse looks,
and `G` flickers the nearest supported light once per 60 seconds within 20 studs.

### Mobile/touch behavior

- `ContextActionService` creates the Notebook touch action.
- Custom proximity prompts display `TAP`.
- Primary actions, role controls, evidence, voting, counselor topics, settings, and
  modal dismissal use touch-capable buttons.
- Narrow responsive layout keeps interaction and hotbar controls inside the viewport.
- Touch drag updates settings sliders.
- Mobile does not assume haptic support; unsupported vibration is ignored.

### Console/controller controls

| Action | Input |
|---|---|
| Notebook | `ButtonY` |
| Settings | `ButtonStart` |
| Close modal | `ButtonB` |
| Previous hotbar slot | `ButtonL1` or D-pad Left |
| Next hotbar slot | `ButtonR1` or D-pad Right |
| Use selected hotbar slot | `ButtonX` |
| Activate focused button | `ButtonA` |
| World interaction | Proximity prompt's displayed gamepad key |

Ghost mode uses left stick for horizontal movement, right stick for look, right/left
triggers for up/down, `ButtonL3` for sprint, and `ButtonY` for the light flicker.

### Platform validation requirements

Before release, QA must complete a full round on keyboard/mouse, touch, and controller
and verify:

- all nine phase layouts and transitions;
- controller focus entry, transfer, and cleanup;
- drag controls and touch targets at narrow aspect ratios;
- prompts show the correct device-specific input;
- notebook, role action, item, counselor, vote, and settings paths;
- ghost camera and return to living/custom camera;
- sensitivity and sprint preference persistence;
- safe-area, streaming, collision, navigation, spawn, and mobile performance; and
- reduced-motion, subtitles, high-contrast evidence, no-audio, and unsupported-haptics
  behavior.

### Known source-alignment notes

These are documentation facts, not newly invented mechanics:

- `KeybindHints.lua` displays intended hints for `Tab` map, `F` equip, `Q` role ability,
  and controller `View`/`LB`, but `InputController.lua` does not currently bind those
  actions. Production UI copy and input bindings must be reconciled before those hints
  are treated as guaranteed controls.
- The request that created this document described “all 6” phases while naming eight.
  Runtime source defines the nine phases documented here.
- The product describes ten player-facing locations. The world manifest intentionally
  aggregates them into eight runtime areas as documented in Section 11.
- Counselor schedules name seven camp facilities beyond the current fallback camp's
  separate models. The authored Camp asset should supply or alias those destinations.
- The role catalog's generic Murderer Hostile Attack and some upgrade descriptions are
  broader than the current action routing. Monster-specific abilities and the runtime
  effects in Sections 3, 4, and 10 are authoritative for implementation.
