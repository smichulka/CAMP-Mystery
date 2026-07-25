# CAMP-Mystery Testing

## Automated checks

Run the unified release suite from the repository root:

```powershell
python scripts/run_all_checks.py
```

The unified runner executes the structural validator, domain contracts, release
readiness tests, 512 deterministic roster/mystery simulations, and a Rojo build when
Rojo is available. The structural validator checks the Rojo mappings, remote classes, strict-mode source
files, required catalogs, server APIs, 15-slot inventory contract, schema-v1 profiles,
Studio memory fallback, and the launch ban on monetization APIs.

The domain contract suite additionally checks that:

- matchmaking only calls methods implemented by the bot roster;
- twelve unique bot profiles can fill a full match;
- every playable role has a capped earned upgrade;
- profile persistence exposes load, release, reward, settings, upgrade, and cosmetic
  operations;
- reward receipts remain idempotent;
- the production remote contract is present.
- the production bootstrap starts `GameRuntimeService`, not the legacy round service;
- public evidence notes use Roblox text filtering;
- objective/evidence interactions retain server-side proximity authorization;
- the live runtime initializes bots, matchmaking, rewards, and profile state.

These checks are deliberately executable without Roblox Studio. They catch repository
and integration defects, but they do not simulate Roblox physics, navigation, remotes,
or DataStore behavior.

For the final release-candidate repository gate, require a successful Rojo build:

```powershell
python scripts/run_all_checks.py --require-rojo
```

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

## Studio profile test

`ProfileService.new()` uses an in-memory store automatically in Studio. This avoids guest
mode when Studio API access is disabled; the data intentionally lasts only for that
server session. An injected `MemoryProfileStore` can be used for deterministic tests.

Verify:

1. Load a new profile and confirm schema version 1 with default cosmetics.
2. Apply one reward receipt twice; the first applies and the second reports a duplicate.
3. Confirm XP, camp tokens, role mastery, statistics, and level cosmetics update once.
4. Update settings with valid and unknown fields; only the allowlisted valid settings
   change.
5. Buy a role upgrade with earned tokens, enforce its mastery/rank caps, unlock an earned
   cosmetic, and equip only owned cosmetics.
6. Release and reload the profile from the injected memory store; all changes remain.

Published servers use the Roblox DataStore adapter with bounded exponential retries.
There is no MarketplaceService, Robux purchase, premium multiplier, paid currency, or
receipt-processing path at launch.
