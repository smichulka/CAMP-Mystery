# Milestone 2 Studio Playtest

## Start

From PowerShell in the repository:

```powershell
git switch main
git pull origin main
rokit install
rojo serve
```

Connect the Rojo Studio plugin to `localhost:34872`, approve synchronization, and press **Play**.

## Expected round

1. **Waiting at Camp** — a gray-box camp, three cabins, campfire, and three labeled work stations appear.
2. **Roles Revealed** — one player receives Camper or Murderer. In a solo test, the player is a Camper and Counselor Holloway is the computer culprit.
3. **Daytime Objectives** — use each glowing prompt:
   - Stack Firewood
   - Repair Generator
   - Secure Supplies
4. **Something Is Being Planned** — interaction prompts close.
5. **The Town Is Appearing** — fog, night lighting, road, buildings, streetlamps, and a water tower appear.
6. **Night Investigation** — collect the three glowing clues along the main road.
7. **Campfire Vote** — select a suspect in the center voting panel.
8. **Mystery Resolution** — the server announces the winning side.
9. **Round Rewards** — placeholder reward phase runs, then the map returns to day and a new round begins.

Completing all objectives, collecting all evidence, or receiving all eligible votes ends that phase early after a short confirmation pause.

## Multiplayer checks

Use Studio's **Server & Clients** test with at least three clients:

- Only one player sees the Murderer role.
- Other clients never receive the private Murderer identity directly.
- One innocent player becomes a ghost after the nighttime transformation.
- Ghosts can observe but cannot complete objectives, collect evidence, or vote.
- Each living player can vote only once.
- A unique correct top vote awards the Campers the win.
- A tie, no vote, or wrong vote awards the Murderer the win.

## Pass criteria

- No red errors appear in **View → Output**.
- The HUD remains synchronized on every client.
- The town is collidable only at night.
- Objective and evidence prompts only work during their authorized phases.
- The result appears on all clients and the next round resets cleanly.
