# CAMP-Mystery — Asset Requirements

## Status

CAMP-Mystery is code-complete and can use procedural or text fallbacks in development.
Final authored models, animation, audio, and UI imagery are still external production
inputs. Installing, licensing, moderating, and validating them is required before public
release.

The phrase “36 missing runtime assets” in Request 0017 is not the repository's canonical
inventory count. The request's only reproducible 36-item arithmetic is:

| Request checklist unit | Count |
|---|---:|
| Monster rigs | 8 |
| Counselor rigs | 6 |
| Environment models | 10 |
| Music cues | 4 |
| Ambience cues | 2 |
| Effects cues | 2 |
| Four named missing `UISoundMap` cues | 4 |
| **Normalized Request 0017 checklist** | **36** |

That arithmetic omits the animation banks, icon bank, publishing images, and three
additional UI cues (`PhaseChime`, `VoteOpen`, and `Reward`) that Request 0017 separately
requires. Conversely, `assets/content-manifest.json` contains **33 bank/category
records**: 31 are marked `missing`, while the game icon and thumbnail source files are
marked `installed` but are not uploaded or moderated. Expanding banks into individual
clips and icons produces far more than 36 files. This document therefore:

1. enumerates the normalized 36-item checklist without pretending it is the manifest;
2. covers every additional animation, audio, icon, and publishing binding required by
   the request and current code; and
3. treats `assets/content-manifest.json` as the release inventory of record.

Forward slashes below describe the Roblox Explorer hierarchy. Repository paths are
called out explicitly when they are meant to exist in Git.

## Shared production standards

### Visual direction

- Target a readable, stylized supernatural summer-camp mystery, not photoreal gore.
- Preserve silhouettes at phone size and under the game's night lighting. Shape,
  animation, and value contrast must communicate identity without relying on color.
- Use a consistent texel density. Prefer reusable trim sheets and atlases over many
  one-off materials.
- Deliver source files with unapplied transforms plus an export with scale and axes
  verified in Roblox Studio. One Roblox stud is the working world unit.
- Remove unused bones, hidden geometry, cameras, lights, scripts, constraints, and
  embedded third-party content before delivery.
- Use simple invisible collision proxies. Render meshes should normally have
  `CanCollide = false`; collision meshes should normally have `CanQuery = true` and only
  use `CanTouch` where gameplay requires it.

### Naming

- Explorer object names are case-sensitive contracts. Use the exact names in this
  document.
- Source filenames use lower-kebab-case with a semantic suffix, for example
  `monster-baby-alien-rig-v01.fbx` or `ui-evidence-culprit-v01.png`.
- Roblox upload names use `CAMP_` plus the Explorer key, for example
  `CAMP_Monster_BabyAlien_Rig` or `CAMP_UI_Evidence_Culprit`.
- Never append a version suffix to the installed Explorer contract name. Track versions
  in the source filename, upload name, manifest, and production log.

### Ownership, moderation, and delivery

Every delivery must include:

- editable source, flattened/exported source, and a preview;
- creator or vendor, source URL, license terms, and durable proof of license;
- source checksum and the uploaded Roblox asset ID;
- Roblox moderation status and UTC review timestamp;
- the target manifest record(s) and exact Explorer or attribute binding;
- an explicit statement that the asset contains no unapproved scripts or dependencies.

Update the corresponding record in `assets/content-manifest.json`; do not create an
untracked spreadsheet as a competing inventory. `sourceStatus` becomes `installed` only
after the final asset is installed at its contract path. Public release additionally
requires `license.status` to be `owned` or `licensed`, a nonempty `owner` and
`proofPath`, `moderation.status = "approved"`, a positive `robloxAssetId`, and
`reviewedAtUtc`.

## 3D Character Rigs

### Common rig contract

Deliver an `.fbx` source/import file and the installed Roblox `Model`. Each installed
model must:

- be a script-free `Model` at the exact path listed below;
- have a stable pivot and `PrimaryPart` at ground-relative root height;
- contain an `AnimationController` or `Humanoid` with a descendant `Animator`;
- use Motor6D/bone names consistently across every animation authored for that rig;
- face Roblox forward consistently, stand on the ground at identity rotation, and pass
  `Model:PivotTo()` without an offset jump;
- omit the `ProceduralFallback` attribute (that attribute disables authored animation);
- keep all required meshes, textures, bones, attachments, and animation folders inside
  the model; and
- clone cleanly from `ServerStorage` into
  `Workspace/Runtime/Characters/GeneratedCharacters`.

The runtime sets `MonsterId`, `ParticipantId`, `CounselorId`, `DisplayName`,
`LocationId`, and `Behavior`; artists must not depend on author-time values for those
attributes. Character labels are generated by code and require a valid `PrimaryPart`.

**Per monster budget:** 15,000 rendered triangles preferred, 20,000 hard maximum;
12 skinned mesh parts maximum; 60 bones maximum; two 1,024×1,024 texture sets preferred,
with a single 2,048×2,048 set allowed only when profiling supports it. Only one monster
is normally active, but validate against ten players and six counselors.

**Per counselor budget:** 8,000 rendered triangles preferred, 12,000 hard maximum;
8 skinned mesh parts maximum; 45 bones maximum; one 1,024×1,024 texture atlas preferred.
All six counselors can be active simultaneously.

Use PNG/TGA for lossless source textures. Provide PBR maps only where they materially
improve the scene; keep color-space settings documented. No texture may exceed 2,048
pixels on either axis without an approved, profiled exception.

### Monster Rigs (8)

`CharacterAssetService.findAsset("Monsters", monsterId)` binds the model name directly.
These eight entries are normalized checklist items 1–8.

| # | Model / upload stem | Exact Roblox path | Required silhouette and material read |
|---:|---|---|---|
| 1 | `BabyAlien` / `CAMP_Monster_BabyAlien_Rig` | `ServerStorage/ServerAssets/Monsters/BabyAlien` | Small, low crawler; oversized alien eyes and acidic anatomy; green/acid-lime accents; must read clearly in narrow routes. |
| 2 | `Screamer` / `CAMP_Monster_Screamer_Rig` | `ServerStorage/ServerAssets/Monsters/Screamer` | Tall direct pursuer; unmistakable resonant mouth/throat and lateral sound-spine shapes; muted flesh with red alarm accents. |
| 3 | `Wendigo` / `CAMP_Monster_Wendigo_Rig` | `ServerStorage/ServerAssets/Monsters/Wendigo` | Very tall forest stalker; antlers, long claws, lean charging silhouette; bone/wood neutrals. |
| 4 | `ShadowMonster` / `CAMP_Monster_ShadowMonster_Rig` | `ServerStorage/ServerAssets/Monsters/ShadowMonster` | Broad smoky silhouette with four readable tendril forms; near-black body and restrained violet energy. |
| 5 | `Chupacabra` / `CAMP_Monster_Chupacabra_Rig` | `ServerStorage/ServerAssets/Monsters/Chupacabra` | Low skeletal quadruped/creature profile; pronounced back spines and pounce-ready pose; UV-readable residue detail. |
| 6 | `Dullahan` / `CAMP_Monster_Dullahan_Rig` | `ServerStorage/ServerAssets/Monsters/Dullahan` | Headless armored pursuer; collar void or spectral flame must make “headless” immediate; cyan spectral accent. |
| 7 | `Entity` / `CAMP_Monster_Entity_Rig` | `ServerStorage/ServerAssets/Monsters/Entity` | Floating, narrow paranormal form with three anchor motifs; cool blue energy and partial transparency. |
| 8 | `Banshee` / `CAMP_Monster_Banshee_Rig` | `ServerStorage/ServerAssets/Monsters/Banshee` | Floating apparition with veil-like lower silhouette and readable face/voice focus; pale blue-white spectral values. |

The public monster presentation and counterplay are defined in
`src/shared/Config/PublicMonsterCatalog.lua`; the fallback silhouette reference is
`MONSTER_PRESENTATION` in
`src/server/Services/CharacterAssetService.lua`. A final rig must remain distinct from
all seven others; do not merge variants into one generic body.

### Counselor Rigs (6)

`CharacterAssetService` first looks up each exact counselor ID and only then tries its
legacy `Counselor_<index>` fallback. Use the ID path below. These are normalized
checklist items 9–14.

| # | Display identity | Exact Roblox path | Required visual role cue |
|---:|---|---|---|
| 9 | Director Mara Holloway | `ServerStorage/ServerAssets/NPCs/counselor-holloway` | Camp director; decisive posture, incident-log/emergency-lead visual language. |
| 10 | Counselor Lena Ortiz | `ServerStorage/ServerAssets/NPCs/counselor-ortiz` | Health and safety; first-aid pack or equivalent nonverbal medical cue. |
| 11 | Counselor Miles Reed | `ServerStorage/ServerAssets/NPCs/counselor-reed` | Outdoor skills; trail/ranger clothing and practical field silhouette. |
| 12 | Counselor Tessa Brooks | `ServerStorage/ServerAssets/NPCs/counselor-brooks` | Arts and activities; activity supplies, whistle, or bright practical layers. |
| 13 | Counselor Ivy Chen | `ServerStorage/ServerAssets/NPCs/counselor-chen` | Nature and science; field instruments/tool belt and methodical presentation. |
| 14 | Counselor Noah Finch | `ServerStorage/ServerAssets/NPCs/counselor-finch` | Waterfront and records; field journal and water-safety visual cues. |

All counselors are distinct adult characters. Preserve age-appropriate, non-caricatured
design. Their exact identities, jobs, schedules, and behavior are defined in
`src/server/Config/CounselorCatalog.lua`.

## Environment Models

### Runtime assembly contract

`ProductionMapService` does **not** clone ten independent locations. It only calls:

- `cloneAuthoredMap("Camp")`, requiring a `Model` at
  `ServerStorage/ServerAssets/Maps/Camp`; and
- `cloneAuthoredMap("NightTown")`, requiring a `Model` at
  `ServerStorage/ServerAssets/Maps/NightTown`.

The manifest lists nine town district targets below `NightTown`. Treat those as required
named descendant `Model` boundaries inside the one authored `NightTown` model, not as
independently cloned runtime roots. The complete installed hierarchy is:

```text
ServerStorage
└── ServerAssets
    └── Maps
        ├── Camp (Model)
        └── NightTown (Model)
            ├── MainRoad (Model)
            ├── ResidentialQuarter (Model)
            ├── TownSquare (Model)
            ├── GeneralStore (Model)
            ├── GasStation (Model)
            ├── IndustrialDistrict (Model)
            ├── WaterTowerNeighborhood (Model)
            ├── PoliceStation (Model)
            └── DesertedOutskirts (Model)
```

The runtime clones these roots to `Workspace/Runtime/Map/DayCamp/AuthoredCamp` and
`Workspace/Runtime/Map/NightTown/AuthoredNightTown`. Authored roots must be `Model`
instances; a `Folder` at either lookup path is ignored and the procedural world is used.

Preserve access to the gameplay coordinates and named destinations used in
`CharacterAssetService.COUNSELOR_LOCATIONS`, the evidence/search locations in
`GameRuntimeService`, and the safe/hide/witness sockets declared by the world
configuration. Do not place decorative collision across routes, prompts, spawn areas,
or sight lines. Validate navigation, line of sight, proximity prompts, evidence reach,
safe relocation, and day/night reset in Studio.

**Combined environment budget:** 300,000 rendered triangles preferred for the loaded
camp plus town, 400,000 hard maximum pending device profiling; 2,000 render instances
preferred, 3,000 hard maximum; no more than 150 unique materials/textures. Enable
streaming only after gameplay socket and relocation tests pass. Use 512–1,024px atlases
for repeated props and 2,048px only for major hero atlases. Provide low-cost collision
and avoid per-detail unions.

### Map Locations (10)

These are normalized checklist items 15–24.

| # | Model | Exact authored path | Scope and recommended triangle allocation |
|---:|---|---|---|
| 15 | `Camp` | `ServerStorage/ServerAssets/Maps/Camp` | Weathered Appalachian summer camp: campfire, lodge, infirmary, trailhead, activity field, supplies, generator, craft cabin, nature lab, waterfront, evidence board, safe routes, and objective access. Up to 100k triangles. |
| 16 | `MainRoad` | `ServerStorage/ServerAssets/Maps/NightTown/MainRoad` | Primary town approach, readable road hierarchy, safe entry, and long pursuit sight lines. Up to 20k. |
| 17 | `ResidentialQuarter` | `ServerStorage/ServerAssets/Maps/NightTown/ResidentialQuarter` | Houses, porch safe point, closet hide route, yards, and alternate exits. Up to 25k. |
| 18 | `TownSquare` | `ServerStorage/ServerAssets/Maps/NightTown/TownSquare` | Central navigation landmark and bandstand safe point with broad visibility. Up to 20k. |
| 19 | `GeneralStore` | `ServerStorage/ServerAssets/Maps/NightTown/GeneralStore` | Searchable store interior, hide/witness positions, and two-way egress. Up to 20k. |
| 20 | `GasStation` | `ServerStorage/ServerAssets/Maps/NightTown/GasStation` | Strong roadside landmark and clue-search area without blocking town-square routes. Up to 15k. |
| 21 | `IndustrialDistrict` | `ServerStorage/ServerAssets/Maps/NightTown/IndustrialDistrict` | Factory, tunnels, loading-bay safe point, machine clue, locker hide route, and monster area. Up to 45k. |
| 22 | `WaterTowerNeighborhood` | `ServerStorage/ServerAssets/Maps/NightTown/WaterTowerNeighborhood` | Tower landmark, reachable platform, shed hide point, witness area, and safe descent. Up to 25k. |
| 23 | `PoliceStation` | `ServerStorage/ServerAssets/Maps/NightTown/PoliceStation` | Lobby safe point, desk witness area, evidence room, cell hide point, and legible interior circulation. Up to 30k. |
| 24 | `DesertedOutskirts` | `ServerStorage/ServerAssets/Maps/NightTown/DesertedOutskirts` | Road-end safe point, abandoned-house hide route, sparse horizon, and forest/edge transition. Up to 20k. |

Budgets are caps, not targets. Use the lowest geometry and texture cost that preserves
navigation and silhouette. Since the authored `Camp` or `NightTown` replaces the
procedural equivalent as a whole, partial installation is not a safe production
strategy: deliver and test each root as a complete playable assembly.

## Animation Sets

### Technical contract

Animations bind through descendant `Animation` instances, not a model attribute or a
configuration table. Put an `Animations` `Folder` inside each character model. Every
required child must:

- be an `Animation` named exactly for its state;
- have `AnimationId = "rbxassetid://<positive-id>"`;
- target the exact rig and bone hierarchy shipped with that model;
- be owned by or shared with the publishing experience/group; and
- have passed Roblox moderation and an in-experience load test.

`CharacterAssetService` ignores all authored clips when the model has
`ProceduralFallback = true`. It also ignores missing, incorrectly named, or invalid IDs
without stopping the round.

Deliver animation source as `.fbx` at 30 fps with root motion removed unless explicitly
required. Keep the root stable, foot contact clean, and pose extremes readable at
distance. Loop clips must be seamless. Recommended lengths: idle 3–6s, flee/hunt
0.7–1.4s per cycle, hide 1–3s, alert 1–2s, and transform 1.5–3.5s. Keep each imported
clip under 10s unless the state clearly needs more.

### Monster Animations

For every one of the eight monster models:

| Required child | Exact path template | Playback |
|---|---|---|
| `Transform` | `ServerStorage/ServerAssets/Monsters/<MonsterId>/Animations/Transform` | Played once when the monster spawns. |
| `Hunt` | `ServerStorage/ServerAssets/Monsters/<MonsterId>/Animations/Hunt` | Looped while the hunt state is active. |

This is one manifest `AnimationSet` bank but **16 required rig-specific clip bindings**
unless approved rigs deliberately share a compatible skeleton and uploaded clip.
Transform and Hunt are the only monster state names currently invoked by code.

### Counselor Animations

For every one of the six counselor models:

| Required child | Exact path template | Behavior bindings |
|---|---|---|
| `Idle` | `ServerStorage/ServerAssets/NPCs/<CounselorId>/Animations/Idle` | `Routine`, `Witness`, `Suspect`, and `Unavailable` |
| `Flee` | `ServerStorage/ServerAssets/NPCs/<CounselorId>/Animations/Flee` | `Fleeing` |
| `Hide` | `ServerStorage/ServerAssets/NPCs/<CounselorId>/Animations/Hide` | `Hiding` |
| `Alert` | `ServerStorage/ServerAssets/NPCs/<CounselorId>/Animations/Alert` | `Alert` |

This is one manifest `AnimationSet` bank but **24 required model/clip bindings** unless
the six counselor rigs share an approved skeleton and clips. Reusing one compatible
uploaded clip still requires an `Animation` child with the correct name under every
installed model.

## Audio Banks

### Runtime binding contract

Final audio is configured through attributes on the **`SoundService` instance**. The
value may be a positive integer, numeric string, or `rbxassetid://<id>` string. At
runtime `AudioController` creates:

```text
SoundService
└── CampMysteryAudio (Folder)
    ├── LobbyMusic (Sound)
    ├── ...
    └── UIStamp (Sound)
```

The manifest paths such as `SoundService/CampMysteryAudio/MusicCues` are inventory-bank
labels; the code does not read authored `MusicCues`, `AmbienceCues`, `EffectCues`, or
`UICues` folders. Do not install duplicate `Sound` objects there. Set the listed
attributes on `SoundService`, then call the existing refresh path or restart the client.
The generated `Sound` child exposes its source attribute name in the
`AssetAttribute` attribute and whether it used a fallback in `UsesPlaceholderAsset`.

Audio masters: lossless WAV, 48 kHz, 24-bit preferred (16-bit accepted); mono for
non-spatial UI/SFX unless stereo materially contributes; seamless stereo is allowed for
music/ambience. If a lossy review or upload copy is required, use OGG/MP3 at 192 kbps or
higher for music/ambience and 128 kbps or higher for mono SFX. Normalize conservatively:
true peak no higher than -1 dBTP, no clipping, and consistent perceived loudness within
each channel. Remove leading silence from one-shots and verify loop seams with no pop.

Critical effect cues must retain the existing subtitle behavior; audio may reinforce
information but cannot be the only way to receive it.

### Music Cues (4 tracks)

These are normalized checklist items 25–28 and bind in
`src/client/Controllers/AudioController.lua`.

| # | Cue / runtime `Sound` | `SoundService` attribute | Direction | Delivery |
|---:|---|---|---|---|
| 25 | `LobbyMusic` | `LobbyMusicAssetId` | Welcoming but uneasy camp arrival; low intensity and non-fatiguing. | Seamless 60–150s stereo loop. |
| 26 | `CampMusic` | `CampMusicAssetId` | Investigation-minded acoustic/organic camp identity; supports dialogue and voting. | Seamless 90–180s stereo loop. |
| 27 | `NightMusic` | `NightMusicAssetId` | Sustained supernatural tension with room for SFX; no abrupt scares in the loop seam. | Seamless 90–180s stereo loop. |
| 28 | `ResultsMusic` | `ResultsMusicAssetId` | Clear resolution/reward cadence, bittersweet enough to support either winner. | Seamless 45–90s stereo loop. |

### Ambience Cues (2 loops)

These are normalized checklist items 29–30.

| # | Cue / runtime `Sound` | `SoundService` attribute | Direction | Delivery |
|---:|---|---|---|---|
| 29 | `CampAmbience` | `CampAmbienceAssetId` | Day camp bed: wind, distant birds/insects, wood and waterfront detail; no embedded speech. | Seamless 60–120s loop, stereo, low dynamic peaks. |
| 30 | `NightAmbience` | `NightAmbienceAssetId` | Abandoned-town night bed: wind, distant structures, restrained insects/electrical texture; no fake gameplay cue. | Seamless 60–120s loop, stereo, low dynamic peaks. |

### SFX Cues (2 effects)

These are normalized checklist items 31–32.

| # | Cue / runtime `Sound` | `SoundService` attribute | Direction | Delivery |
|---:|---|---|---|---|
| 31 | `EvidenceFound` | `EvidenceFoundAssetId` | Short tactile mystery discovery, distinct from success/reward UI. Subtitle: “Evidence discovered.” | 0.4–1.5s one-shot, mono or narrow stereo. |
| 32 | `MonsterActive` | `MonsterActiveAssetId` | Tension/heartbeat-like proximity bed that can loop without masking the monster subtitle. | Seamless 4–12s loop, restrained low end. |

### UI Audio Cues

The four missing `UISoundMap` entries below are normalized checklist items 33–36:

| # | Cue / runtime `Sound` | `SoundService` attribute | Direction | Delivery |
|---:|---|---|---|---|
| 33 | `UIError` | `UIErrorAssetId` | Short, soft negative response; never resemble the monster warning. | 0.15–0.7s one-shot. |
| 34 | `UISuccess` | `UISuccessAssetId` | Restrained positive confirmation, distinct from round rewards. | 0.2–0.9s one-shot. |
| 35 | `UIPageTurn` | `UIPageTurnAssetId` | Paper/page flip or subtle whoosh for notebook navigation. | 0.2–0.8s one-shot. |
| 36 | `UIStamp` | `UIStampAssetId` | Dry stamp/thud for evidence ceremony. | 0.15–0.7s one-shot. |

Request 0017 also identifies these **three additional silent core UI bindings**, which
must not disappear just because the normalized list has reached 36:

| Cue / runtime `Sound` | `SoundService` attribute | Direction |
|---|---|---|
| `PhaseChime` | `PhaseChimeAssetId` | Neutral but unmistakable phase transition; subtitle: “The camp phase has changed.” |
| `VoteOpen` | `VoteOpenAssetId` | Urgent, civic/campfire voting cue; subtitle: “The campfire vote is open.” |
| `Reward` | `RewardAssetId` | Round reward confirmation; subtitle: “Round rewards received.” |

Five other `UISoundMap` cues already have temporary Creator Store fallbacks, but a final
authored audio bank should replace or explicitly approve them:

| Cue | `SoundService` attribute | Use |
|---|---|---|
| `UIHover` | `UIHoverAssetId` | Focus/hover movement |
| `UIClick` | `UIClickAssetId` | General activation |
| `UIOpen` | `UIOpenAssetId` | Panel/notebook open |
| `UIClose` | `UICloseAssetId` | Panel/notebook close |
| `UIToast` | `UIToastAssetId` | Informational toast |

Therefore the production audio handoff is **20 code-bound sounds** in total: 11 core
`AudioController` definitions and 9 supplementary `UISoundMap` definitions. At the
Request 0017 baseline, 15 of those had no code fallback (11 core plus the four numbered
missing UI cues); Wave 2 fallbacks make the game audible but do not constitute final
licensed audio.

## UI Icon Set

### Runtime binding contract

Install UI IDs at `ReplicatedStorage/Assets/Images/UI`, a `Folder` created by
`default.project.json`. `UIAssetController` resolves a key in this order:

1. a positive ID in an attribute on the `UI` folder;
2. a child `StringValue` or `NumberValue` with the key name;
3. a child `ImageLabel`/`ImageButton` using its `Image`; or
4. any same-named child with a positive `AssetId` attribute.

**Preferred installation:** set folder attributes using the exact keys below. Attribute
values may be positive integers, numeric strings, or `rbxassetid://<id>`. Do not place
raw PNG files under `src`; Rojo does not upload image content.

Deliver each icon as transparent PNG, 1:1, at 256×256 output with a 512×512 or 1024×1024
editable source. Keep essential shape inside a 12% safe margin, avoid small text, and
test at 24×24, 36×36, and 48×48 pixels. Use one coherent stroke weight and value
hierarchy. Each icon needs a light/dark-background contrast check and a color-blind
shape check.

### Role Icons (8)

`GameView.imageKey("Role", role)` constructs these exact keys:

| Role | Folder attribute or child key |
|---|---|
| Camper | `Role_Camper` |
| Medic | `Role_Medic` |
| Trapper | `Role_Trapper` |
| Medium | `Role_Medium` |
| Guard | `Role_Guard` |
| Protector | `Role_Protector` |
| Detective | `Role_Detective` |
| Murderer | `Role_Murderer` |

`Spectator` exists as an observer role in `RoleCatalog` but is not one of the eight
hidden gameplay roles and the requested eight-icon set does not include it. If the
spectator UI is later changed to show a role icon, add `Role_Spectator`; current text
fallback remains complete.

### Equipment Icons (11)

The request says “per role,” but code binds icons by the 11 equipment IDs in
`EquipmentCatalog`, not by role:

| Equipment | Folder attribute or child key |
|---|---|
| Flashlight | `Equipment_Flashlight` |
| UV Light | `Equipment_UVLight` |
| Laser Projector | `Equipment_LaserProjector` |
| Camera | `Equipment_Camera` |
| Spirit Box | `Equipment_SpiritBox` |
| Thermometer | `Equipment_Thermometer` |
| Audio Recorder | `Equipment_AudioRecorder` |
| EMF Reader | `Equipment_EMFReader` |
| Monster Trap | `Equipment_MonsterTrap` |
| Medical Kit | `Equipment_MedicalKit` |
| Flare Lantern | `Equipment_FlareLantern` |

### Evidence Icons (4 types)

These keys are literal bindings in `GameView.lua`:

| Evidence presentation | Folder attribute or child key |
|---|---|
| Culprit evidence | `Evidence_Culprit` |
| Monster evidence | `Evidence_Monster` |
| Unresolved mystery clue | `Evidence_Mystery` |
| Witness account | `Evidence_Witness` |

Evidence channel and state must remain distinguishable by silhouette and label, not only
color, to preserve the high-contrast evidence setting.

### Misc UI Icons

No additional misc icon key is currently read by `UIAssetController` or `GameView`.
Do not invent unbound `AssetId` fields. Future misc icons must first receive an exact
runtime key and manifest update; until then, UI text and procedural components are the
authoritative fallback.

The minimum current icon bank is therefore **23 bound icons**: 8 role, 11 equipment, and
4 evidence. It is one `ImageSet` record in the manifest, not one manifest record per
PNG.

## Publishing Assets

Publishing images are Creator Dashboard assets, not runtime Explorer instances.

### Game Icon

- **Repository source:** `assets/marketing/camp-mystery-icon-1024.png`
- **Target:** `RobloxExperience/Icon`
- **Required delivery:** PNG, 1024×1024, RGB/sRGB, no alpha-dependent edge treatment.
- **Safe area:** keep the title and principal silhouette inside the central 80%; confirm
  legibility in circular/rounded and 150px store previews.
- **Binding:** upload through Creator Dashboard, then record the resulting asset ID,
  moderation approval, and UTC review time in manifest record `experience-icon`.

The source file is already installed and checksum-tracked. Upload and moderation are
still outstanding; it is inaccurate to call the source image missing.

### Thumbnail

- **Repository source:** `assets/marketing/camp-mystery-thumbnail-1920x1080.png`
- **Target:** `RobloxExperience/Thumbnails`
- **Required delivery:** PNG, 1920×1080 (16:9), RGB/sRGB.
- **Safe area:** keep title/primary action within the central 80% and clear of likely
  device/store overlays; validate at 384×216 and phone width.
- **Binding:** upload through Creator Dashboard, then record asset ID, ordering,
  moderation approval, and UTC review time in manifest record
  `experience-thumbnails`.

The source file is already installed and checksum-tracked. A future thumbnail set may
contain several images, but only this one candidate is currently inventoried.

## Installation and validation procedure

### 1. Intake

1. Verify name, version, owner, license, source URL, and checksum.
2. Scan imported models for scripts and unexpected dependencies.
3. Upload audio, images, textures, meshes, and animations under the experience owner or
   owning group; do not rely on a contractor's personal account remaining accessible.
4. Record every Roblox ID and moderation result before wiring the asset.

### 2. Install in a private Studio copy

1. Sync `default.project.json` with Rojo.
2. Insert character and map `Model` instances at the exact Explorer paths above.
3. Add exact animation children and IDs inside each character model.
4. Set final audio attributes directly on `SoundService`.
5. Set final icon attributes on
   `ReplicatedStorage/Assets/Images/UI`.
6. Upload publishing images in Creator Dashboard.
7. Update `assets/content-manifest.json` with source, license, moderation, and asset-ID
   evidence.

Assets placed manually in the Studio place are not represented by the current Rojo
filesystem mapping. Preserve the approved place version or add an explicit reviewed
source strategy before treating the installation as durable.

### 3. Automated repository checks

Run:

```powershell
python scripts/validate_content_manifest.py
python scripts/run_all_checks.py --require-rojo
python scripts/validate_content_manifest.py --require-ready
```

The first command validates structure while pending content is allowed. The final
command is intentionally expected to fail until every manifest record has installed
source, license proof, an approved moderation result, a positive Roblox ID, and a UTC
review timestamp.

### 4. Roblox Studio acceptance

- Start a solo round and a two-client server round from the exact candidate place.
- Verify all six counselors spawn as authored models, move among expected destinations,
  change animation state, reset, and respawn without duplicates.
- Exercise all eight monsters: transform, hunt, clear, reset, silhouette readability,
  animation ownership, and equipment counterplay.
- Complete camp objectives, day/night transformation, every evidence-search route,
  counselor relocation, campfire, resolution, rewards, and a second-round reset.
- Confirm both authored map roots replace their fallback cleanly; no player spawns below
  the map, becomes trapped, or loses access to a prompt, clue, safe point, or hide point.
- Test music, ambience, effects, and UI channels independently at 0%, 50%, and 100%;
  verify phase switching, loops, teardown, subtitles, and no clipping or stacked audio.
- Inspect all 23 icon keys at phone, tablet, 16:9 desktop, ultrawide, touch, and
  controller-focus layouts. Temporarily remove one key to confirm the text fallback.
- Profile client/server memory, frame rate, script time, physics, render instances,
  triangles, texture memory, streaming, and network use with ten participants.
- Repeat a ten-round soak and confirm no model, track, sound, connection, or map instance
  accumulates.

### 5. Release evidence

Attach the exact Git commit, Roblox place version, private-server test timestamp,
tester/device matrix, screenshots/video, profiler captures, Script Analysis output,
moderation records, and rollback place version. Only publish after every relevant item
in `docs/RELEASE_CHECKLIST.md` passes. A successful Rojo build or procedural fallback is
not evidence that final content is installed or release-ready.

## Binding reference

| Asset family | Code binding | Authoritative configuration |
|---|---|---|
| Monster models | `src/server/Services/CharacterAssetService.lua` | Model name under `ServerStorage/ServerAssets/Monsters` |
| Counselor models | `src/server/Services/CharacterAssetService.lua` | Counselor ID under `ServerStorage/ServerAssets/NPCs` |
| Camp/town models | `src/server/Services/ProductionMapService.lua` | `Camp` and `NightTown` root `Model` names |
| Character animation | `src/server/Services/CharacterAssetService.lua` | Descendant `Animations/<State>` `Animation.AnimationId` |
| Core audio | `src/client/Controllers/AudioController.lua` | Attributes on `SoundService` |
| Supplementary UI audio | `src/client/Controllers/UISoundMap.lua` | Attributes on `SoundService` |
| UI icons | `src/client/Controllers/UIAssetController.lua`; `src/client/UI/GameView.lua` | Attributes/children under `ReplicatedStorage/Assets/Images/UI` |
| Content release record | `assets/content-manifest.json` | Source, target, license, moderation, Roblox ID, timestamp |
| Publishing images | `assets/marketing/`; Creator Dashboard | Manifest source file and uploaded Creator Dashboard asset |
