# Spooky Circus — vetted Creator Store assets

These free Creator Store models live in `ServerStorage.ServerAssets.Circus`
in the place file (NOT in git — the folder is declared in
`default.project.json` without `$path`, so Rojo preserves Studio-side
contents). `Map/SpookyCircus.lua` clones them by name at build time and
falls back to procedural stand-ins when one is missing.

## Vetting protocol (applied 2026-08-10)

Every model was inserted into a quarantine folder and audited before
promotion: all `Script`/`LocalScript`/`ModuleScript`/`Sound`/`RemoteEvent`
instances **deleted unconditionally** (geometry only — all motion and audio
is driven by our own code), every `BasePart` anchored, then renamed and
moved to `ServerAssets.Circus`. Candidates over ~3,000 parts or that turn
out to be whole maps are rejected.

## Kept

| Name in ServerAssets.Circus | Store asset | Creator | Notes |
|---|---|---|---|
| `CircusTent` | 88701059892241 "Creepy Circus Tent Abandoned Horror Carnival RP" | AaliyahGamer1141 | 5 meshes; huge source scale (260x140x270) — pack applies `ScaleTo(0.25)`. Stripped 6 scripts incl. two 13KB texture scripts flagged suspicious. |
| `FerrisWheel` | 3751786052 "[Working] Ferris Wheel" | MaxEnough | 193 parts, 71x76x34. Sub-models: `Support` (static), `Wheel` (rotates), `Baskets/Basket1..18` (orbit upright). Motor script stripped; pack drives rotation. |
| `Carousel` | 498310295 "Carousel (Merry-Go-Round)" | Q_Q | 43 parts, 29x30x29. Sub-models: `Top`, `Horse1..4`. Script + embedded Sound stripped; pack spins + bobs. |
| `PopcornMachine` | 55429971 "popcorn machine" | 123456789hi | 76 parts, 12x17x7 — pack applies `ScaleTo(0.45)`. 3 vendor scripts stripped. |

## Rejected

| Store asset | Reason |
|---|---|
| 129524122729878 "Carnival Funfair Booth Game Prize Stall" | 3,540 parts / 7,296 decals — an entire carnival map, not a booth. Game booths are built natively instead. |

## Re-acquisition

If the place file loses these, re-run the insertion + vetting protocol with
the asset ids above (`insert_asset` → quarantine → strip → anchor → rename →
promote). The game boots fine without them — procedural fallbacks cover
every piece.
