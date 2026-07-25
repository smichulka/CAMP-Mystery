# CAMP-Mystery

A multiplayer Roblox supernatural mystery game designed by Skipper and Penelope.

## Current milestone

The repository contains the tested Milestone 2 gray-box round plus the Milestone 3
domain foundation:

- Rojo 7.7 project mapping
- server-authoritative round phase state machine
- private Camper/Murderer role assignment
- three interactive daytime camp objectives
- a generated camp and an abandoned town that materializes at night
- three collectible evidence clues
- campfire voting, victory conditions, and automatic reset
- synchronized phase, role, evidence, objective, and voting HUD
- solo Studio support through a computer-controlled culprit
- strict Luau source layout for shared, server, and client code
- stable human and computer participant identities
- catalog-driven definitions for all eight roles and eight monsters
- inventory, equipment, combat, injury, ghost, and evidence domain services
- versioned profiles, earned progression, rewards, and cosmetics
- round-scoped lifecycle and cleanup utilities

Milestone 3 modules are being integrated behind the existing round contract. The tested
Milestone 2 runtime remains the default path until the corresponding integration gate
passes.

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

The Output panel should show the server and client foundation messages. Follow the HUD prompts to complete the gray-box round.

## Build without Studio

```powershell
New-Item -ItemType Directory -Force -Path build
rojo build default.project.json --output build/CAMP-Mystery.rbxlx
```

## Validate the repository

```powershell
python scripts/validate_project.py
```

See [docs/PLAYTEST_MILESTONE_2.md](docs/PLAYTEST_MILESTONE_2.md) for the complete Studio
smoke test, [docs/PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md) for the authoritative launch
rules, and [docs/DELIVERY_PLAN.md](docs/DELIVERY_PLAN.md) for the autonomous milestone
sequence.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the product boundaries, source layout, and current milestone.
