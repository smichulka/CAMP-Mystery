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

## First milestone

The foundation intentionally implements only a synchronized round state machine and phase HUD. It proves:

1. Rojo builds and live-syncs the project.
2. The server starts a round and owns its current phase.
3. clients receive the current phase without deciding it themselves.
4. late-joining clients can request the current round snapshot.
5. the phase and countdown are visible during a Studio playtest.

Gameplay systems will be added behind this boundary in later milestones.

