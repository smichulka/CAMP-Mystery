# CAMP-Mystery

A multiplayer Roblox supernatural mystery game designed by Skipper and Penelope.

## Current milestone

The repository contains the Milestone 2 gray-box round:

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

See [docs/PLAYTEST_MILESTONE_2.md](docs/PLAYTEST_MILESTONE_2.md) for the complete Studio smoke test.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the product boundaries, source layout, and current milestone.
