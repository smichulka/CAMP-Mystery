# CAMP-Mystery

A multiplayer Roblox supernatural mystery game designed by Skipper and Penelope.

## Current status

The repository contains the integrated, code-complete gameplay alpha:

- Rojo 7.7 project mapping
- server-authoritative round phase state machine
- all eight hidden roles and all eight monster gameplay definitions
- three interactive daytime camp objectives
- a generated camp and an abandoned town that materializes at night
- generated real, fake, culprit, and monster evidence
- campfire voting, victory conditions, and automatic reset
- responsive desktop, touch, and controller UI
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

`GameRuntimeService` is the live production path. The legacy `RoundService` remains only
as the previously tested gray-box reference and is not started by the server bootstrap.
Final reference-quality monster rigs, animations, audio, and environment art remain
swappable Roblox asset work rather than missing gameplay code.

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
python scripts/validate_project.py
python scripts/test_domain_contracts.py
```

See [docs/PLAYTEST_MILESTONE_2.md](docs/PLAYTEST_MILESTONE_2.md) for the complete Studio
smoke test, [docs/PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md) for the authoritative launch
rules, and [docs/DELIVERY_PLAN.md](docs/DELIVERY_PLAN.md) for the autonomous milestone
sequence.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the product boundaries, source layout, and current milestone.
