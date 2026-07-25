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

## Production runtime

`GameRuntimeService` is the sole live orchestrator. It composes:

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
- `MysteryService` deterministically generates authentic, planted, monster, and witness
  clues whose complete authentic intersections identify one culprit and one monster.
- `CounselorService` owns six adult NPC schedules, fixed dialogue, observations,
  witness accounts, threat behavior, and round cleanup.
- `ProductionMapService` loads authored camp/town assets or supplies a complete
  procedural fallback with objectives, searchable locations, lighting, and safe areas.
- `CharacterAssetService` loads authored monsters/NPCs or supplies labeled procedural
  fallbacks through the same runtime interface.
- `RoundLifecycle` and `Cleanup` provide typed, round-scoped events and cleanup so
  systems do not create circular dependencies or leak connections.

Integration proceeds through phase lifecycle events and explicit callbacks. The client
receives only public snapshots plus its own private participant, inventory, profile, and
Murderer-only control state.

### Domain ownership

| Domain | Authoritative owner |
|---|---|
| Participant roster, role, health summary, private knowledge | `ParticipantService` |
| Inventory identity, capacity, ownership, transfer, drop, charges | `InventoryService` |
| Attack eligibility, injury, elimination, healing, ghost transition | `CombatService` |
| Evidence authenticity, discovery, board state, Detective verification | `EvidenceService` |
| Deducible clue graph and witness revelation | `MysteryService` |
| Counselor schedule, memory, dialogue, witness/threat state | `CounselorService` |
| Monster selection, stamina, cooldowns, abilities, evidence emissions | `MonsterService` |
| Round events, revision ordering, subscriber cleanup | `RoundLifecycle` |
| Profile load/save, rewards, settings, mastery, cosmetics | `ProfileService` |

All replicated domain snapshots carry a round identifier and monotonic revision. Public
snapshots exclude secret roles, private evidence associations, unrevealed monster
selection, ability state, and vote targets.

## Presentation and asset boundary

The client runtime composes `RoundController`, `GameView`, tutorial, audio, visual
effects, accessibility, input, and interaction controllers. Keyboard/mouse, touch, and
controller share the same server action contract.

Authored Roblox content belongs under `ServerStorage/ServerAssets/Maps`,
`ServerStorage/ServerAssets/Monsters`, and `ServerStorage/ServerAssets/NPCs`. Missing
assets never prevent a round from starting: the production services use deterministic
fallback geometry and characters. This makes the repository playable while licensed
final content moves through Roblox moderation.
