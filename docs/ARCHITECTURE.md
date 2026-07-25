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

## Milestone 3: domain foundation

Milestone 3 introduces production-facing domains without changing the validated
Milestone 2 runtime path:

- `ParticipantService` gives humans and computer players stable string identities and a
  shared state model.
- `RoleCatalog` defines all eight roles and scales the distribution for 1–12
  participants.
- `InventoryService`, `CombatService`, and `EvidenceService` own equipment, injuries,
  death/ghost transitions, and real/fake evidence.
- `MonsterService` provides one validated lifecycle and ability contract for eight
  separate monster definitions.
- `ProfileService` provides versioned persistence, idempotent rewards, earned currency,
  role mastery, settings, and cosmetics.
- `RoundLifecycle` and `Cleanup` provide typed, round-scoped events and cleanup so later
  systems do not create circular dependencies or leak connections.

These modules are intentionally separated from `RoundService`. Integration proceeds
through phase lifecycle events and explicit callbacks instead of adding more
responsibilities to the existing orchestrator.

### Domain ownership

| Domain | Authoritative owner |
|---|---|
| Participant roster, role, health summary, private knowledge | `ParticipantService` |
| Inventory identity, capacity, ownership, transfer, drop, charges | `InventoryService` |
| Attack eligibility, injury, elimination, healing, ghost transition | `CombatService` |
| Evidence authenticity, discovery, board state, Detective verification | `EvidenceService` |
| Monster selection, stamina, cooldowns, abilities, evidence emissions | `MonsterService` |
| Round events, revision ordering, subscriber cleanup | `RoundLifecycle` |
| Profile load/save, rewards, settings, mastery, cosmetics | `ProfileService` |

All replicated domain snapshots carry a round identifier and monotonic revision. Public
snapshots exclude secret roles, private evidence associations, unrevealed monster
selection, ability state, and vote targets.
