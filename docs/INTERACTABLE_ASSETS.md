# Interactable world assets (optional Creator Store)

`Map/InteractableWorld.lua` fills camp, night town, and Midway with Inspect /
Sit / Tune / Play prompts. Procedural geometry always ships.

Optional meshes live in **Studio-only** `ServerStorage.ServerAssets.Interactables`
(Rojo preserves the folder; contents are not in git — same pattern as Circus).

## Suggested free Creator Store models

| Name in Interactables | Asset ID | Notes |
|---|---|---|
| `PicnicTable` | 231878673 | Picnic table |
| `ParkBench` | 407532238 or 13892740187 | Bench / camping bench |
| `BulletinBoard` | 5122928559 | Bulletin board — strip scripts |
| `RustyRadio` | 7017487793 | Rusty radio — strip scripts |

## Vetting protocol

Same as `CIRCUS_ASSETS.md`: quarantine → delete Script/LocalScript/ModuleScript/
Sound/Remote* → anchor BaseParts → rename → move to `ServerAssets.Interactables`.

Reject whole-map / multi-thousand-part packs.
