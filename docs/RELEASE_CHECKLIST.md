# CAMP-Mystery Release Checklist

This is the release-candidate exit gate. A checked box means the named result was
observed on the exact commit being released; it does not mean that a similar result
passed on an earlier branch.

Use [RELEASE_EVIDENCE.md](RELEASE_EVIDENCE.md) to create commit-scoped evidence and
[RELEASE_OPERATIONS.md](RELEASE_OPERATIONS.md) for the rollback/DataStore incident
drill. `tools/release-observations.template.json` maps the human/Roblox-only sections
into the machine-readable release gate. No Studio-only box is pre-checked by repository
automation.

## 1. Repository gate

- [ ] `python scripts/run_all_checks.py --require-rojo` exits successfully.
- [ ] `python scripts/validate_content_manifest.py --require-ready` exits successfully.
- [ ] `python scripts/release_gate.py --release-candidate --commit <sha>
      --observations <file>` exits successfully and records the exact candidate.
- [ ] GitHub Actions `Validate CAMP-Mystery` passes on the release commit.
- [ ] The generated `.rbxlx` opens in the current production Roblox Studio version.
- [ ] Studio `Script Analysis` has no errors.
- [ ] Studio Output has no red errors during server start, round play, reset, or shutdown.
- [ ] The release commit contains no MarketplaceService, game-pass, developer-product,
      Robux-price, premium multiplier, or receipt-processing implementation.
- [ ] The Roblox experience remains private until every section below passes.

The repository-side suite checks strict mode, Rojo mappings, the exact remote surface,
server API and action contracts, role distribution for 1–12 participants, phase budgets,
equipment/monster cross-catalog integrity, full-profile monster solvability, 512 seeded
reference mysteries, profile migration/idempotency contracts, operational workflow
contracts, release controllers, NPC content, and the launch monetization ban.

## 2. Studio server-authority gate

Run **Test → Start** with one server and at least two clients. Repeat once with ten
clients if the current Studio/device capacity permits it.

- [ ] `Production server started` appears exactly once.
- [ ] Every client reports `Production client started` and receives a game snapshot.
- [ ] A player can ready once; request flooding is rejected without harming the round.
- [ ] The roster locks at the configured target and fills empty seats with unique bots.
- [ ] Exactly one participant receives Murderer; every participant receives one role.
- [ ] No client can read another participant's private role, inventory, monster control,
      profile mutation details, or ghost-only knowledge.
- [ ] Invalid action names and malformed payloads return a rejection without a server
      exception.
- [ ] Objective, evidence, item, role, and monster requests fail when phase, ownership,
      range, line of sight, cooldown, charge, target, or life-state checks fail.
- [ ] Disconnecting an active human creates one replacement bot without duplicating the
      participant, role, inventory, vote, or reward.
- [ ] Server shutdown completes without an unhandled save or cleanup error.

## 3. Complete round and mystery gate

- [ ] A solo Studio round starts, fills with bots, completes, rewards, resets, and starts
      a different mystery without manual repair.
- [ ] A multiplayer round follows the configured phase order: Lobby, Role Reveal, Day,
      Murder Planning, Night Transform, Investigation, Campfire, Resolution, Rewards.
- [ ] Production timings total 15–20 minutes; Studio timings stay below four minutes.
- [ ] The daytime camp changes to the nighttime town and returns cleanly after rewards.
- [ ] Each generated mystery contains enough authentic culprit evidence for a correct
      deduction without directly exposing the culprit's name.
- [ ] Monster evidence is a separate channel and its complete authentic profile
      identifies exactly one of the eight monsters.
- [ ] Fake evidence and conflicting witness statements are plausible but cannot remove
      every valid path to the correct solution.
- [ ] Evidence locations vary across repeated rounds and remain reachable/searchable.
- [ ] Posted evidence preserves finder, location, chain of custody, verification,
      confidence, notes, and suspect relationships.
- [ ] Campfire voting allows one living vote per participant, blocks ghosts, resolves
      ties as designed, and declares the correct team result.
- [ ] Run a ten-round seeded server soak: no impossible mystery, duplicate culprit,
      duplicate participant, stuck phase, duplicate reward, or uncleared map/NPC remains.

Record all ten seeds and outcomes in the release evidence.

## 4. Roles, health, inventory, and monsters

- [ ] Verify all roles: Camper, Medic, Trapper, Medium, Guard, Protector, Detective, and
      Murderer.
- [ ] Every ability enforces its uses, cooldown, phase, target, and authority rules.
- [ ] First serious injury changes a living participant to Injured; the next qualifying
      injury eliminates them.
- [ ] Medical kits are single-use and cannot self-heal or heal ghosts.
- [ ] Eliminated players return as restricted ghosts and cannot carry physical items,
      complete living objectives, collect ordinary evidence, or vote.
- [ ] Fifteen-slot inventory ownership survives equip, use, trade, drop, death drop, and
      pickup without duplication or loss.
- [ ] Exercise both abilities, intended evidence, movement behavior, and counterplay for
      Baby Alien, Screamer, Wendigo, Shadow Monster, Chupacabra, Dullahan, Entity, and
      Banshee.
- [ ] Only the Murderer receives private monster controls; campers receive only the
      public monster state authorized by the server.

## 5. Counselor NPC gate

- [ ] Six distinct adult counselor NPCs spawn with unique IDs and display names.
- [ ] Each follows a schedule and can transition among normal, witness/suspect, flee,
      hide, and reset behavior where applicable.
- [ ] Observations are created only from server-known events and do not reveal secret
      culprit state through client data.
- [ ] Dialogue is fixed/moderated, bounded, age-appropriate, and cannot echo raw
      player-provided text.
- [ ] Witness memory survives the relevant investigation and clears on round reset.
- [ ] NPC navigation recovers from a blocked route or missing waypoint without stopping
      the round.
- [ ] NPCs and their connections/models are removed exactly once during reset/shutdown.

## 6. Tutorial, audio, accessibility, and controls

- [ ] A new profile sees the tutorial; it can advance, complete, and skip without
      blocking gameplay.
- [ ] Tutorial state does not expose secret information and does not replay after
      completion unless explicitly reset.
- [ ] Music, ambience, effects, and UI audio respond independently to their settings;
      master volume scales all of them.
- [ ] Round transitions do not stack duplicate sounds, and every active sound stops on
      controller destruction/reset.
- [ ] Subtitles cover critical spoken/monster cues and remain useful with audio muted.
- [ ] Reduced motion suppresses nonessential transitions; disabled camera shake prevents
      gameplay camera shake; high-contrast evidence visibly distinguishes clue state.
- [ ] Mouse and controller sensitivity, sprint toggle, and all settings survive rejoin.
- [ ] Complete one round using keyboard/mouse, touch, and controller.
- [ ] UI remains readable at phone, tablet, 16:9 desktop, and ultrawide safe areas.
- [ ] No required action depends only on color, sound, hover, or precise pointer input.

## 7. Persistence and migration gate

Use a disposable test universe/DataStore namespace; never run destructive migration
tests against production player data. Configure the server-only attributes documented in
`TESTING.md`; the runtime rejects the production namespace, disables fault injection in
production mode, and restricts test mode to Studio or a private server.

- [ ] A new profile loads schema 1 defaults and default cosmetics.
- [ ] A representative schema-0 profile migrates to schema 1, clamps invalid values,
      drops unknown entries, preserves recognized progress, and saves successfully.
- [ ] Loading and saving the migrated profile again produces no further semantic change.
- [ ] Applying the same reward receipt twice changes XP, currency, mastery, stats, and
      unlocks only once.
- [ ] Reward receipt history remains bounded at the configured maximum.
- [ ] Leave/rejoin preserves progress, cosmetics, upgrades, and settings.
- [ ] Forced DataStore load/update failures produce bounded retries and guest/error
      behavior without granting duplicate rewards or overwriting newer data.
- [ ] A failed player-leave save is retried with bounded backoff, cancelled by a genuine
      rejoin, and attempted once more during shutdown.
- [ ] A profile with a newer unsupported schema fails safely instead of being downgraded.

## 8. Performance, safety, and publishing gate

- [ ] Measure server/client memory, script time, physics, network receive/send, and frame
      rate during a ten-player investigation and after ten resets.
- [ ] No material upward memory/instance/connection trend remains after resets.
- [ ] NPC and monster pathfinding cannot create an unbounded retry loop.
- [ ] Remote fuzzing with wrong types, oversized strings, missing IDs, stale round IDs,
      repeated sequences, and out-of-range positions produces rejections, not exceptions.
- [ ] Public evidence notes pass Roblox text filtering before replication.
- [ ] All final models, textures, animation, audio, icons, and thumbnails are owned or
      licensed for this experience and have passed Roblox moderation.
- [ ] Final lighting, collision, streaming, navigation, spawn points, mobile performance,
      and controller focus have been reviewed in the published private experience.
- [ ] A private production-server smoke test passes from a non-owner Roblox account.
- [ ] Rollback place/version and DataStore incident procedures are documented and usable.
- [ ] Only after every required gate passes: publish the approved release version.

## Honest limitations of automated validation

The Python suite does **not** execute Luau and does **not** emulate the Roblox engine. Its
seeded tests are deterministic reference-model checks backed by parsed catalogs; they
prove catalog-level invariants, not that the live generator invokes every path correctly.
Static API checks prove that expected methods and wiring are present, not that callbacks
run in the correct order.

Only Roblox Studio or a private Roblox server can validate replication boundaries,
physics, collision, streaming, navigation/pathfinding, UI focus, input devices, audio
mixing, animation, rendering, text filtering, DataStore concurrency/retries, memory
leaks, moderation, and actual performance. A green CI run is necessary, but it is not a
release approval by itself.
