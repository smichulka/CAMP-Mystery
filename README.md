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
Roblox-owned content inputs; the runtime, asset hooks, accessibility behavior, and
fallback presentation are implemented.

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

See [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) for the complete Studio and
private-server release gate, [docs/PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md) for the
authoritative launch rules, and [docs/TESTING.md](docs/TESTING.md) for validation.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the product boundaries, source layout, and current milestone.
