# Claude_Request-0017 — GDD, Audio Fallbacks, Dead-Player UX, Tutorial Polish

## Context

Baseline after 0016: **81 strict Luau files**, 869,892 bytes Rojo artifact.

**Critical findings from repo audit:**
- All Lua game logic is 100% complete. Zero TODOs, stubs, or missing systems.
- Every remaining gap is a production asset (3D models, audio banks, icons, animations).
- The game is fully playable in code — it just has no audio/visual assets yet.
- `Theme.Colors.Primary` does not exist — use `Theme.Colors.Gold` for active/accent elements.
- The active accent color confirmed in 0016: `Theme.Colors.Gold`.

**What this request targets:**
1. Write the authoritative GDD and asset spec docs (from ChatGPT's design memory)
2. Fill 15 silent audio slots with free Roblox fallback asset IDs so the game has sound
3. Add dead-player (eliminated, non-ghost) UX — currently nothing tells a dead human player they've been eliminated and are spectating
4. Improve tutorial flow

**This request has 2 new files (Wave 1) and 5 existing-file changes (Wave 2).**

---

## Wave 1 — New documentation files (run first, no dependencies)

### Agent 1 — NEW `docs/GAME_DESIGN.md`

Write a comprehensive Game Design Document for CAMP-Mystery based on your full knowledge of the game's design from the project conversation. This is the authoritative reference for the team.

Structure the document with these sections:

```
# CAMP-Mystery — Game Design Document

## 1. Concept
## 2. Core Loop (phase sequence, win conditions)
## 3. Roles (all 8, with full descriptions and abilities)
## 4. Monsters (all 8, with full descriptions and abilities)
## 5. Phases (all 6: Lobby, MurderPlanning, NightTransform, Investigation, Day, Campfire, Resolution, Rewards)
## 6. Evidence & Mystery System
## 7. Counselor NPCs (all 6, with behavior states)
## 8. Combat & Status Effects
## 9. Voting System
## 10. Progression & Rewards
## 11. Map Locations (all 10)
## 12. Bot AI Behavior
## 13. Accessibility & Settings
## 14. Platform Support (PC/mobile/console)
```

Be thorough — this document will be used by the art team, audio team, and future developers. Include specific details: role ability names, cooldown windows, monster hunt ranges, evidence types, vote tie rules, XP formulas, NPC schedule states, etc.

Commit as `docs/GAME_DESIGN.md`.

---

### Agent 2 — NEW `docs/ASSET_REQUIREMENTS.md`

Write a production-ready asset requirements document for all 36 missing runtime assets. This goes to the art team and audio team.

Structure it as:

```
# CAMP-Mystery — Asset Requirements

## Status
All code is complete. All 36 listed assets are missing from the source tree.
Installing them unblocks audio, visuals, and Roblox Store submission.

## 3D Character Rigs
### Monster Rigs (8)
### Counselor Rigs (6)

## Environment Models  
### Map Locations (10)

## Animation Sets
### Monster Animations
### Counselor Animations

## Audio Banks
### Music Cues (4 tracks)
### Ambience Cues (2 loops)
### SFX Cues (2 effects)
### UI Audio Cues (4 sounds)

## UI Icon Set
### Role Icons (8)
### Equipment Icons (per role)
### Evidence Icons (4 types)
### Misc UI Icons

## Publishing Assets
### Game Icon
### Thumbnail
```

For each asset, include:
- Exact Roblox path where it must be installed
- File format and technical specs (poly count budget, texture resolution, audio format/sample rate/bitrate, icon dimensions)
- Naming convention
- Which attribute or AssetId field in the code it binds to

This doc is the handoff brief for non-programmers.

Commit as `docs/ASSET_REQUIREMENTS.md`.

---

## Wave 2 — All five agents run in parallel after Wave 1 commits

---

### Agent 3 — `src/client/Controllers/UISoundMap.lua`

Fill the 4 nil `defaultAssetId` slots with suitable free Roblox audio asset IDs. Read the full file before editing.

The four slots currently have `defaultAssetId = nil`:
- `UIError` — needs a short negative/error tone
- `UISuccess` — needs a short positive/success tone  
- `UIPageTurn` — needs a soft page-flip/whoosh sound
- `UIStamp` — needs a stamp/thud sound

Add `defaultAssetId` and `sourceUrl` for each using real, verified free Roblox audio asset IDs. Use assets from the Roblox Creator Store that are free, publicly available, and appropriate in tone for a horror/mystery game. Match the style of the existing 5 slots (which use short UI tones from the Creator Store).

If you know exact verified asset IDs, use them. If you are not certain an asset ID is valid and free, use the most commonly cited free Roblox UI sound IDs and note `-- verify in Studio` next to each one.

---

### Agent 4 — `src/client/Controllers/AudioController.lua`

Add `defaultAssetId` fallback values to the 7 music/SFX/ambience/effect cue slots that currently have none. Read the full file before editing.

The 7 slots that need fallbacks (currently read-only from SoundService attributes with no code fallback):

```lua
{ name = "LobbyMusic",    channel = "Music",    attribute = "LobbyMusicAssetId",    looped = true }
{ name = "CampMusic",     channel = "Music",    attribute = "CampMusicAssetId",     looped = true }
{ name = "NightMusic",    channel = "Music",    attribute = "NightMusicAssetId",    looped = true }
{ name = "ResultsMusic",  channel = "Music",    attribute = "ResultsMusicAssetId",  looped = true }
{ name = "CampAmbience",  channel = "Ambience", attribute = "CampAmbienceAssetId",  looped = true }
{ name = "NightAmbience", channel = "Ambience", attribute = "NightAmbienceAssetId", looped = true }
{ name = "EvidenceFound", channel = "Effects",  attribute = "EvidenceFoundAssetId" }
{ name = "MonsterActive", channel = "Effects",  attribute = "MonsterActiveAssetId", looped = true }
```

And 3 more in the DEFINITIONS list:
```lua
{ name = "PhaseChime",    channel = "UI", attribute = "PhaseChimeAssetId" }
{ name = "VoteOpen",      channel = "UI", attribute = "VoteOpenAssetId" }
{ name = "Reward",        channel = "UI", attribute = "RewardAssetId" }
```

Add a `defaultAssetId` field to each with a suitable free Roblox audio ID. Where you know verified free horror/ambient/mystery-appropriate Roblox audio IDs, use them. Where uncertain, add the field with a comment `-- placeholder: replace with final asset`. This ensures `RefreshAssetIds()` has something to fall back to and the game isn't completely silent.

Do NOT change the attribute read logic — only add `defaultAssetId` to DEFINITIONS entries.

---

### Agent 5 — `src/client/UI/GameView.lua`

Add an "ELIMINATED" spectator banner for dead non-ghost players. Currently when `alive = false` and `isGhost = false`, the player sees the full game UI with no indication they've been eliminated. Read the full file before editing.

**New state fields:**
```lua
eliminatedBanner: Frame?,
```
Initialize to `nil`.

**Build the eliminated banner** in `GameView.new()`:
```lua
local eliminatedBanner = Instance.new("Frame")
eliminatedBanner.Name = "EliminatedBanner"
eliminatedBanner.AnchorPoint = Vector2.new(0.5, 0)
eliminatedBanner.Position = UDim2.new(0.5, 0, 0, 60)
eliminatedBanner.Size = UDim2.fromOffset(320, 48)
eliminatedBanner.BackgroundColor3 = Theme.Colors.Panel
eliminatedBanner.BackgroundTransparency = 0.12
eliminatedBanner.BorderSizePixel = 0
eliminatedBanner.Visible = false
eliminatedBanner.ZIndex = 30
eliminatedBanner.Parent = root
Components.Corner(eliminatedBanner, 8)
Components.Stroke(eliminatedBanner, Theme.Colors.TextMuted, 1)

local elimTitle = Components.Label(eliminatedBanner, "Title", "ELIMINATED", 13, Enum.Font.GothamBold)
elimTitle.AnchorPoint = Vector2.new(0.5, 0)
elimTitle.Position = UDim2.new(0.5, 0, 0, 6)
elimTitle.Size = UDim2.new(1, 0, 0, 18)
elimTitle.TextXAlignment = Enum.TextXAlignment.Center
elimTitle.TextColor3 = Theme.Colors.TextMuted

local elimSub = Components.Label(eliminatedBanner, "Sub", "You are spectating. Watch the mystery unfold.", 10)
elimSub.AnchorPoint = Vector2.new(0.5, 0)
elimSub.Position = UDim2.new(0.5, 0, 0, 26)
elimSub.Size = UDim2.new(1, -16, 0, 16)
elimSub.TextXAlignment = Enum.TextXAlignment.Center
elimSub.TextColor3 = Theme.Colors.TextMuted
elimSub.TextTransparency = 0.3

self.eliminatedBanner = eliminatedBanner
```

**In `Update()`** — show/hide based on alive state:
```lua
if self.eliminatedBanner then
    local alive = readBoolean(player, "alive", false)
    local isGhost = readBoolean(player, "isGhost", false)
    local inActivePhase = phase ~= "Lobby" and phase ~= "Rewards"
    self.eliminatedBanner.Visible = not alive and not isGhost and inActivePhase
end
```

**Also in `Update()`** — when the player is dead and not a ghost, disable the role action button and hotbar interaction (but keep the notebook accessible for reviewing their evidence):
```lua
if not alive and not isGhost then
    -- keep notebook accessible; disable other interactive elements
    Components.SetButtonEnabled(self.roleAction, false)
end
```

Note: Check whether `SetButtonEnabled` already handles false→false idempotently before adding this. Don't double-disable.

**Destroy:** destroy `eliminatedBanner` in `Destroy()`.

---

### Agent 6 — `src/client/UI/EffectsView.lua`

Add a spectator vignette for dead non-ghost players — a subtle gray/desaturated full-screen overlay indicating they've been eliminated and are watching. Read the full file before editing.

**New state field:**
```lua
spectatorActive: boolean,
spectatorTween: Tween?,
```
Initialize both to `false`/`nil`.

**New public method `SetSpectatorMode(active: boolean)`:**
```lua
function EffectsView:SetSpectatorMode(active: boolean)
    if self.destroyed or active == self.spectatorActive then
        return
    end
    self.spectatorActive = active
    if self.spectatorTween then
        self.spectatorTween:Cancel()
        self.spectatorTween = nil
    end
    local targetAlpha = if active then 0.72 else 1.0
    -- Use an existing full-screen Frame (e.g. the vignette frame) or
    -- add a new dedicated spectator overlay Frame parented to self.root
    -- that covers the full screen with a dark gray color:
    -- BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    -- Use TweenService to animate BackgroundTransparency to targetAlpha over 0.6s
    -- If reduced motion: set immediately without tween
    if not self.reducedMotion then
        self.spectatorTween = TweenService:Create(
            self.spectatorOverlay,
            TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            { BackgroundTransparency = targetAlpha }
        )
        self.spectatorTween:Play()
    else
        self.spectatorOverlay.BackgroundTransparency = targetAlpha
    end
end
```

Build `self.spectatorOverlay` in `EffectsView.new()`:
- `Frame`, full screen (`Size = UDim2.fromScale(1, 1)`), `ZIndex = 2` (below status overlays), `BackgroundColor3 = Color3.fromRGB(30, 30, 35)`, `BackgroundTransparency = 1.0` (invisible by default), `BorderSizePixel = 0`

In `Destroy()`: cancel `spectatorTween`, destroy `spectatorOverlay`.

---

### Agent 7 — `src/client/Controllers/RoundController.lua`

Wire `EffectsView:SetSpectatorMode()` based on player alive/ghost state. Read the full file before editing.

**In `refresh()`**, after the existing ghost mode check (around line ~414–420 where `isGhost` is read and applied), add:

```lua
-- Spectator mode for dead non-ghost players
local isEliminated = not readBoolean(player, "alive", false) and not isGhost
local currentEffects = effects
if currentEffects then
    currentEffects:SetSpectatorMode(isEliminated and not roundEnded)
end
```

`readBoolean` is already defined in `RoundController`. `effects` is the local variable holding the `EffectsView` instance. Confirm the exact variable name used in this file.

When `roundEnded` (Lobby/Rewards phase), spectator mode is cleared so the lobby screen shows normally.

---

## Definition of Done for Request 0017

- [ ] `docs/GAME_DESIGN.md` committed and covers all 14 sections with full role/monster/phase detail
- [ ] `docs/ASSET_REQUIREMENTS.md` committed with specs for all 36 missing assets
- [ ] `UISoundMap.lua`: UIError, UISuccess, UIPageTurn, UIStamp all have non-nil `defaultAssetId`
- [ ] `AudioController.lua`: all 11 music/ambience/SFX/UI cue slots have a `defaultAssetId` fallback
- [ ] `GameView.lua`: ELIMINATED banner appears for dead non-ghost players during active phases; hidden during Lobby/Rewards; notebook remains accessible
- [ ] `EffectsView.lua`: `spectatorOverlay` frame + `SetSpectatorMode(active)` method exist; gray overlay fades in/out correctly; reduced-motion skips tween
- [ ] `RoundController.lua`: `SetSpectatorMode` wired from `refresh()` on alive/ghost state
- [ ] Gate: `python scripts/run_all_checks.py --require-rojo` passes with **83 strict Luau files** (2 new doc files do NOT count toward the Luau file count — Lua file count stays at 81)
- [ ] Reply in `ClaudChat/ChatToClaude/Chat_Request-0017-gdd-audio-spectator-tutorial.md`

## Notes for ChatGPT

- The 2 new files are `.md` documentation — they do NOT count toward the 81 Luau file gate. The structural check counts `.lua` files only.
- `Theme.Colors.Gold` is the confirmed active accent color (discovered in 0016 when `Primary` didn't exist). Use it for any accent UI in this request.
- `TweenService` is already imported in `EffectsView.lua`. Confirm before adding a duplicate import.
- For audio asset IDs: if you have high confidence in a specific Roblox asset ID being free and appropriate, use it directly. If you're uncertain, use your best match and add `-- verify in Studio` comment. The goal is the game has SOME sound, not perfect sound.
- `EffectsView.spectatorOverlay` should be at a ZIndex that puts it above the world but below status overlays like the injury vignette and ghost tint. ZIndex 2 achieves this given existing `statusFrame` ZIndex patterns — confirm before placing.
- Agent 5 and Agent 6 own different files (GameView vs EffectsView) — no conflict.
- Agent 7 only adds ~5 lines to RoundController — minimal, safe.
- Report final byte counts for all changed files and confirm line counts for the two new docs.
