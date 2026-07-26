# Chat_Request-0035 — Monster Stamina Low Notification

## 1. Status

Request 0035 is implemented and published to `main`.

The active Monster now receives a Warning toast once each time observed stamina crosses from at least 20% to below 20%. Reconnect snapshots initialize the tracker silently, first-observation low state cannot trigger the toast, consecutive low snapshots do not repeat it, inactive Monster state clears the tracker, and `RoundController.Stop()` resets it.

## 2. Implementation

Updated only `src/client/Controllers/RoundController.lua` as assigned:

- Added nullable `lastStaminaWasLow` state.
- Seeded it from reconnect `privateMonster.stamina / maxStamina` with a positive-maximum guard.
- Reused the existing 0034 `abilityMonster` local.
- Added the guarded notification:
  - title: `Stamina low`
  - body: `Disengage and let it recover before striking again.`
  - style: `Warning`
- Reset tracking when Monster state is missing/inactive and during `Stop()`.

## 3. Ownership and Scope

One mandated owner modified one game-source file only:

| Owner | File | Result |
|---|---|---|
| Agent A | `src/client/Controllers/RoundController.lua` | Complete |

No other game source or test file changed.

## 4. Verification

Fresh-published verification was run from commit `ae6acaebbf641656098dab898af72ff091044596`:

- Published controller blob: `b511641eac20e3eee1cda9e2157dca751642148a`
- Published controller size: 40,272 bytes
- Strict Luau compilation: 83 files passed
- Domain, server, operational, client, UI/motion, cinematic, ghost, reconnect, phase-title, win, release, resilience, and soak checks: passed
- Deterministic Rojo artifact: 946,750 bytes
- Command: `python3 scripts/run_all_checks.py --require-rojo`

## 5. Commit Ledger

| Commit | Purpose |
|---|---|
| `4a7a9dba184baf101744778bbc5f51fff124c371` | Archived Claude Request 0035 |
| `985c12431f35e0f1adb4dea716194cabed8d8832` | Removed the processed unread request |
| `ae6acaebbf641656098dab898af72ff091044596` | Published the Monster stamina-low notification |

## 6. Correction and Deferred Validation

The supplied predicate `lastStaminaWasLow ~= true` conflicts with the acceptance criterion that nil history must not notify: in Luau, `nil ~= true` evaluates true. The implementation uses `lastStaminaWasLow == false`, so notification requires an observed normal-to-low crossing.

Stamina changes occur during accepted Monster ability mutations and are followed by a game-state broadcast, so this snapshot-driven alert should be prompt. Roblox Studio visual testing and live multiplayer stamina/reconnect testing remain deferred.
