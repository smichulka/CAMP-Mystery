# CAMP-Mystery Architecture

## Product direction

CAMP-Mystery is a multiplayer Roblox supernatural mystery game. The launch target includes:

- complete human and computer-player matchmaking
- eight playable roles and eight monster transformations
- one camp-and-abandoned-town map that transforms at night
- the full day, murder, investigation, campfire, vote, and resolution loop
- permanent progression, role upgrades, and cosmetics
- no monetization in the first release

The visual direction combines stylized dark Roblox horror with realistic supernatural horror. NPCs, cabins, buildings, and environments may mix features from the approved references. Each approved monster reference is an individual one-to-one visual target and must not be mixed with another monster design.

## Authority boundary

The server is authoritative for:

- secret roles and murderer identity
- round phase and timing
- real and fake evidence
- inventory ownership and item use
- injuries, death, and ghost state
- ability eligibility, limits, and cooldowns
- computer-player decisions
- voting, win conditions, progression, and rewards

The client owns player input, camera work, UI, sound, animation, and visual effects. A client may request an action, but only the server may approve and apply gameplay state.

## Source layout

| Path | Roblox destination | Purpose |
|---|---|---|
| `src/shared` | `ReplicatedStorage/Shared` | Shared types and configuration |
| `src/server` | `ServerScriptService/Server` | Authoritative services and systems |
| `src/client` | `StarterPlayerScripts/Client` | Input, controllers, and presentation |
| `ServerStorage/ServerAssets` | Server-only storage | Maps, monsters, NPCs, items, and evidence |
| `Workspace/Runtime` | Live round state | Spawned map, characters, evidence, and effects |

## Milestone 2: gray-box round

The current implementation proves one complete round without depending on final art:

1. The server waits for at least one player and privately assigns roles.
2. Players complete three interactive camp jobs during the day.
3. A victim is selected and the abandoned town appears at night.
4. Players collect three shared evidence clues in the town.
5. Living players vote for a suspect at the campfire.
6. The server resolves a Camper or Murderer victory and resets the map.

With one Studio player, Counselor Holloway acts as the computer-controlled murderer and Jamie Vale acts as the off-screen victim. With two or more players, one player receives the Murderer role. A player victim is only selected when at least two innocent candidates remain, which keeps small playtests viable.

`RoundService` owns private roles, phase transitions, objectives, evidence, votes, and results. `GrayboxMapService` creates disposable placeholder geometry and interaction prompts. `RoundController` presents authorized public and private state; it cannot decide gameplay outcomes.

The gray-box buildings, labels, colors, clues, names, and timings are test content. Final visual references and the eight launch monsters remain outside this milestone.
