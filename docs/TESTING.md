# CAMP-Mystery Testing

## Automated checks

Run the unified release suite from the repository root:

```powershell
python scripts/run_all_checks.py
```

The unified runner executes the structural validator, domain contracts, focused server
and client release contracts, operational workflow contracts, release readiness tests,
512 deterministic roster/mystery simulations, a 1,000-round reference soak, 10,000
hostile reference payloads, content-manifest validation, and a Rojo build when Rojo is
available. The structural validator checks the Rojo mappings, remote classes, strict-mode
source files, required catalogs, server APIs, 15-slot inventory contract, schema-v1
profiles, Studio memory fallback, and the launch ban on monetization APIs.

The contract suites additionally check that:

- matchmaking only calls methods implemented by the bot roster;
- twelve unique bot profiles can fill a full match;
- every playable role has a capped earned upgrade;
- profile persistence exposes load, release, reward, settings, upgrade, and cosmetic
  operations;
- reward receipts remain idempotent;
- the production remote contract is present;
- the production bootstrap starts `GameRuntimeService`, not the legacy round service;
- public evidence notes use Roblox text filtering;
- objective/evidence interactions retain server-side proximity authorization;
- the live runtime initializes bots, matchmaking, rewards, and profile state;
- the Windows workflow resolves the repository default branch instead of assuming a
  branch name;
- real-DataStore test mode cannot use the production namespace or run on a normal public
  server;
- forced DataStore failures execute inside the real bounded retry path;
- a failed player-leave save retains state for bounded retry and a final shutdown attempt.

These checks are deliberately executable without Roblox Studio. They catch repository
and integration defects, but they do not simulate Roblox physics, navigation, remotes,
or actual DataStore behavior.

For the final release-candidate repository gate, require a successful Rojo build:

```powershell
python scripts/run_all_checks.py --require-rojo
```

The soak and fuzz cases are pure-Python reference models. They do not invoke a Roblox
server and therefore cannot pass the Studio soak, runtime remote-fuzz, or performance
gates.

GitHub Actions downloads the exact Rojo 7.7.0 Linux release asset from its immutable
versioned URL and requires a successful build. Luau engine analysis remains the explicit
Roblox Studio `Script Analysis` gate; the workflow does not claim to replace it.

## Release evidence

Generate commit-scoped repository evidence:

```powershell
python scripts/release_gate.py --commit <40-character-commit-sha>
```

Evaluate a real release candidate only after completing the Roblox observation template:

```powershell
python scripts/release_gate.py `
  --release-candidate `
  --commit <40-character-commit-sha> `
  --observations .\path\to\completed-observations.json
```

See [RELEASE_EVIDENCE.md](RELEASE_EVIDENCE.md) for evidence handling and
[RELEASE_OPERATIONS.md](RELEASE_OPERATIONS.md) for rollback and incidents.

## Production runtime acceptance

Run a two-client Studio server test and verify:

1. `Production server started` and `Production client started` appear without red Output
   errors.
2. Ready state updates the lobby; the Studio roster locks and fills with unique bots.
3. Every participant receives exactly one private role and only the Murderer receives the
   private monster state.
4. Remote objective/evidence requests fail when the player is not near the matching
   world prompt.
5. A first serious attack injures, a second eliminates, equipment drops, and the player
   returns as a restricted ghost.
6. Medic, Protector, Guard, Trapper, Medium, and Detective abilities respect phase,
   target, cooldown, and use limits.
7. Each of the eight monsters can activate its two catalog abilities and produce the
   intended evidence/status/attack effects.
8. Evidence notes replicate only after Roblox text filtering.
9. Search every active evidence socket; confirm the public mystery becomes deducible,
   planted clues remain marked only through Detective verification, and four counselor
   witness accounts can be interviewed without exposing secret state.
10. The campfire accepts one living vote, resolves the correct winner, grants one
    idempotent reward receipt, and returns to the lobby.
11. Disconnecting a locked human transfers the active state to a replacement bot.

## Rojo build

When Rojo is available:

```powershell
New-Item -ItemType Directory -Force -Path build
rojo build default.project.json --output build/CAMP-Mystery.rbxlx
```

## Studio bot and matchmaking test

Use a short fill countdown in a local test configuration or call
`MatchmakingService:ForceLock()` after one human readies.

Verify:

1. One ready human is retained and the roster fills to ten with unique bots.
2. Every roster participant receives exactly one role.
3. Bots complete available daytime objectives, use eligible role abilities, gather
   evidence, attack only as the Murderer, and cast one living campfire vote.
4. A disconnected locked human is replaced by a bot and the roster-changed callback
   transfers the departed role and round state.
5. Late joiners receive `NextRound` status and cannot enter the active roster.
6. `FinishRound` releases round bots and returns queued humans to the lobby.

## Studio profile and DataStore test

The default Studio path remains an in-memory store. This avoids guest mode when Studio API
access is disabled and intentionally lasts only for the current server session.

Verify the deterministic memory path:

1. Load a new profile and confirm schema version 1 with default cosmetics.
2. Apply one reward receipt twice; the first applies and the second reports a duplicate.
3. Confirm XP, camp tokens, role mastery, statistics, and level cosmetics update once.
4. Update settings with valid and unknown fields; only the allowlisted valid settings
   change.
5. Buy a role upgrade with earned tokens, enforce its mastery/rank caps, unlock an earned
   cosmetic, and equip only owned cosmetics.
6. Release and reload the profile; all changes remain.

To exercise the real Roblox adapter, use a disposable test place and DataStore namespace.
Set these **ServerStorage attributes** before starting the server:

| Attribute | Value |
|---|---|
| `CampMysteryProfileStoreMode` | `TestDataStore` |
| `CampMysteryTestDataStoreName` | A unique name beginning with `CAMP_Mystery_Profile_TEST_` |
| `CampMysteryTestLoadFailures` | Optional integer from `0` through `100` |
| `CampMysteryTestUpdateFailures` | Optional integer from `0` through `100` |

Enable Studio access to API services only in the disposable test place. Test mode is
restricted to Studio or a Roblox private server, rejects the production DataStore name,
requires the test prefix, and keeps failure injection disabled in production mode. Remove
the attributes—or set mode to `Auto`—to restore the normal Studio memory path.

The current adapter performs four attempts. Use an injected failure count of `1` through
`3` to prove transient recovery. Use `4` or more to prove exhausted retries and guest/error
behavior. Then verify:

1. schema-0 migration clamps invalid values, removes unknown values, and preserves known
   progress;
2. loading and saving the migrated profile again makes no semantic change;
3. a newer unsupported schema enters safe guest/error behavior rather than downgrading;
4. leave/rejoin preserves progress and does not duplicate reward receipts;
5. forced load and update failures never grant duplicate rewards or overwrite newer data;
6. a failed leave save is retried at most five times with bounded backoff, is cancelled by
   a genuine rejoin, and receives one final shutdown save attempt.

Published servers use the production Roblox DataStore adapter with bounded exponential
retries. There is no MarketplaceService, Robux purchase, premium multiplier, paid
currency, or receipt-processing path at launch.
