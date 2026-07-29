# CAMP-Mystery

A multiplayer Roblox supernatural mystery game designed by Skipper and Penelope.

## Current status

The repository contains the integrated, code-complete release candidate:

- Rojo 7.7 project mapping
- server-authoritative round phase state machine
- all eight hidden roles and all eight monster gameplay definitions
- three interactive daytime camp objectives
- an asset-first camp and abandoned town that materializes at night, with a procedural
  fallback for local development
- seeded, deducible mysteries with real, planted, culprit, and monster evidence
- six scheduled adult counselor NPCs with fixed dialogue and witness accounts
- campfire voting, victory conditions, and automatic reset
- responsive desktop, touch, and controller UI
- first-session tutorial, subtitle-capable audio controller, reduced-motion support,
  camera-shake controls, and high-contrast evidence presentation
- solo and mixed-roster support through computer players
- strict Luau source layout for shared, server, and client code
- stable human and computer participant identities
- catalog-driven definitions for all eight roles and eight monsters
- inventory, equipment, combat, injury, ghost, and evidence domain services
- versioned profiles, earned progression, rewards, and cosmetics
- round-scoped lifecycle and cleanup utilities
- 150-second production matchmaking fill and ready flow
- 18m55s production rounds with a 3m07s Studio test cadence
- filtered evidence notes and server-side proximity, range, line-of-sight, cooldown,
  ownership, role, phase, and request-rate validation

`GameRuntimeService` is the only live round path. `ProductionMapService` and
`CharacterAssetService` load authored models from `ServerStorage/ServerAssets` when
present and generate safe fallbacks when an asset has not yet been installed. Final
reference-quality rigs, animation clips, sounds, icons, and environment models remain
authored Roblox content inputs; the runtime, asset hooks, accessibility behavior, and
fallback presentation are implemented.

The codebase is a release candidate, not a public-release approval. The final content
inventory in `assets/content-manifest.json` deliberately records missing/pending authored
assets, licenses, and Roblox moderation. Studio multiplayer/device testing, private
server testing, DataStore failure/migration testing, performance profiling, the rollback
drill, and Creator Dashboard moderation remain required.

Audio has concrete `SoundService` attribute hooks. Authored monster/counselor animation
folders and optional role, equipment, and evidence icons now have defensive runtime
hooks with complete procedural/text fallbacks. The final files and Roblox asset IDs must
still be installed, licensed, and moderated before the strict release gate can pass.

## Local setup

From PowerShell in this repository:

```powershell
rokit install
rojo plugin install
rojo serve
```

In Roblox Studio:

1. Open the private CAMP-Mystery experience.
2. Open the Rojo plugin.
3. Connect to `localhost:34872`.
4. Allow Rojo to synchronize the project.
5. Press **Play**.

The Output panel should show the production server and client startup messages. Ready up
through the lobby UI, then follow the role, objective, investigation, and campfire HUD.

## One-command Windows workflow

From PowerShell in the repository, resolve and fast-forward the remote default branch,
install pinned tools, run the repository gate, build the place, and start Rojo:

```powershell
.\scripts\CampMystery.ps1
```

Use `-NoPull` to validate local work without switching/pulling. Other actions are
`Validate`, `Build`, `Serve`, and `Release`. `Release` requires a completed observation
file and will fail while final content, licensing, moderation, or Roblox-only gates are
pending.

## Build without Studio

```powershell
New-Item -ItemType Directory -Force -Path build
rojo build default.project.json --output build/CAMP-Mystery.rbxlx
```

## Validate the repository

```powershell
python scripts/run_all_checks.py

# Release gate when Rojo is available
python scripts/run_all_checks.py --require-rojo
```

Generate honest release evidence:

```powershell
python scripts/release_gate.py --commit <40-character-commit-sha>
```

See [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) for the complete Studio and
private-server release gate, [docs/PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md) for the
authoritative launch rules, [docs/RELEASE_EVIDENCE.md](docs/RELEASE_EVIDENCE.md) for
evidence capture, [docs/RELEASE_OPERATIONS.md](docs/RELEASE_OPERATIONS.md) for rollback
and incidents, and [docs/TESTING.md](docs/TESTING.md) for validation.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the product boundaries, source layout, and current milestone.

## Audio asset drop-in points

All game audio is attribute-driven: set attributes on **SoundService** in Studio (or a
setup script) and the runtime uses them with no code changes. Unset slots fall back to
the placeholder asset (base slots), the generic monster loop (per-monster heartbeats),
or silence (positional hunt loops).

Base slots (`SoundService` attributes, client `AudioController`):

| Attribute | Purpose |
| --- | --- |
| `LobbyMusicAssetId` | Lobby music loop |
| `CampMusicAssetId` | Day/campfire music loop |
| `NightMusicAssetId` | Night/investigation music loop |
| `ResultsMusicAssetId` | Resolution/rewards music loop |
| `CampAmbienceAssetId` | Day ambience loop |
| `NightAmbienceAssetId` | Night ambience loop |
| `PhaseChimeAssetId` | Phase-change chime |
| `EvidenceFoundAssetId` | Evidence discovery sting |
| `VoteOpenAssetId` | Campfire vote-open sting |
| `MonsterActiveAssetId` | Generic monster proximity heartbeat loop |
| `RewardAssetId` | Round reward sting |

Per-monster proximity heartbeat (client, replaces the generic loop for that monster's
rounds): `MonsterActive<MonsterId>AssetId` — e.g. `MonsterActiveWendigoAssetId`,
`MonsterActiveBansheeAssetId`. Valid ids: `BabyAlien`, `Screamer`, `Wendigo`,
`ShadowMonster`, `Chupacabra`, `Dullahan`, `Entity`, `Banshee`.

Per-monster positional hunt loop (server, 3D emitter attached to the spawned monster
model, rolls off 8–90 studs): `MonsterHunt<MonsterId>AssetId` — e.g.
`MonsterHuntScreamerAssetId`.

UI interaction sounds are defined in `src/client/Controllers/UISoundMap.lua`, with one
`SoundService` attribute per entry (see that file for the current list).
