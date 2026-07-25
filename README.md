# CAMP-Mystery

A multiplayer Roblox supernatural mystery game designed by Skipper and Penelope.

## Current milestone

The repository contains the first runnable foundation:

- Rojo 7.7 project mapping
- server-authoritative round phase state machine
- synchronized client round state
- visible phase and countdown HUD
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

The Output panel should show the server and client foundation messages. A round phase and countdown should appear at the top of the screen.

## Build without Studio

```powershell
New-Item -ItemType Directory -Force -Path build
rojo build default.project.json --output build/CAMP-Mystery.rbxlx
```

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the product boundaries, source layout, and current milestone.

