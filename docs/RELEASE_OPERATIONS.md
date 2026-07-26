# CAMP-Mystery Release, Rollback, and Incident Operations

These procedures are designed for a private experience first. They do not assume that a
Python check can control Roblox place versions, live servers, moderation, or DataStores.

## Release record

Before publishing, record:

| Field | Required value |
|---|---|
| Git commit | Full 40-character SHA |
| Roblox universe and place | Creator Dashboard URLs/IDs |
| Candidate place version | Exact private version tested |
| Rollback place version | Last known-good version |
| DataStore namespace | Production namespace; never use it for destructive tests |
| Test namespace | Disposable namespace used for migration/failure tests |
| Evidence artifact | JSON, summary, logs, captures, and device matrix |
| Release owner | Person authorized to publish or roll back |
| Start/end time | UTC timestamps |

Keep the experience private until the release gate passes. The automated gate does not
press Publish or make an experience public.

## Release procedure

1. Freeze the candidate commit. Do not mix additional changes into the test window.
2. Run `scripts/CampMystery.ps1 -Action Release -Observations <file>`.
3. Confirm the generated `.rbxlx` opens in the current production Roblox Studio.
4. Run the Studio, DataStore, performance, device, moderation, and private-server gates
   from `docs/RELEASE_CHECKLIST.md`.
5. Confirm the observation file names the same commit and private place version.
6. Record the current known-good Roblox place version as the rollback target.
7. Publish the candidate to the private experience.
8. Run a smoke test from a non-owner account.
9. Review server errors, DataStore failures, memory, network, and join success before
   changing audience access.
10. Make the experience public only after the named release owner accepts the complete
    evidence package.

## Place-version rollback

Use this when a release causes startup, replication, gameplay, performance, or device
failures.

1. Stop audience expansion and return the experience to private if player safety or data
   integrity may be affected.
2. In Creator Dashboard/Studio, restore and publish the recorded last known-good place
   version. Do not guess a version from its date alone.
3. Shut down active servers when the failure requires all players to receive the restored
   version. Expect active sessions to be interrupted.
4. Join from a non-owner account and run the startup/lobby/private-state smoke test.
5. Confirm new servers report the rollback place version and no longer reproduce the
   incident.
6. Preserve the failed version, commit, logs, server/job IDs, timestamps, and reproduction
   steps. A code revert can follow through the normal repository workflow; it is not a
   substitute for the immediate Roblox place rollback.

Never delete the failed place version or evidence during the incident.

## DataStore incident procedure

Use this for unexpected profile resets, save failures, duplication, unsupported schema,
or reward reapplication.

1. Set the experience private if continued joins or rewards could expand the damage.
2. Do not run migration scripts, bulk writes, or manual key edits against production.
3. Record universe/place version, commit, UTC window, affected user IDs, server/job IDs,
   DataStore request/error metrics, and the last known good player state.
4. Determine whether the failure is availability-only or data-mutating. Availability
   failures may use the runtime's bounded retry/guest behavior; evidence of destructive
   writes requires immediate containment.
5. Restore the last known-good place version if the current code writes unsafe data.
   Remember that rolling back code does not automatically roll back DataStore values.
6. Reproduce with sanitized sample data in a disposable test namespace.
7. Design any repair as an idempotent, version-aware migration with dry-run output,
   bounded targets, a backup/export plan, and peer review.
8. Test the repair twice against copied sample data. The second run must make no semantic
   change.
9. Reopen only after load/save/rejoin, duplicate-receipt, failure-retry, and unsupported-
   schema tests pass.

Roblox does not provide a universal transactional "undo all DataStore writes" button.
That is why containment and an idempotent repair plan outrank improvisation.

## Security, filtering, or moderation incident

1. Make the experience private if unfiltered player text, unauthorized assets, exposed
   private roles/state, or rejected content is visible.
2. Capture the exact input, output, asset ID, user/server context, and UTC time without
   redistributing abusive content more widely than needed.
3. Remove or replace rejected/unlicensed assets in the private candidate.
4. Re-run filtering, replication-boundary, asset-manifest, and moderation gates.
5. Do not reuse a moderation approval from a different uploaded asset ID.

## Incident severity and exit criteria

- **Critical:** data corruption/duplication, secret-state exposure, unfiltered unsafe
  content, or widespread inability to join. Make private and roll back immediately.
- **High:** repeatable round failure, severe memory/performance regression, or a required
  device/control path is unusable. Stop rollout and normally roll back.
- **Moderate:** contained cosmetic/audio/content defect without data or gameplay impact.
  Keep private or limit rollout until a tested patch is ready.

An incident is not closed until containment is verified, the known-good version is
identified, evidence is retained, the root cause and affected scope are recorded, and a
regression test or explicit Studio acceptance step covers the failure.

## Rollback drill

Before public launch, perform one private drill:

1. Publish a harmless candidate private version.
2. Record its version and the known-good predecessor.
3. Restore the predecessor and shut down test servers.
4. Verify the restored version from a non-owner account.
5. Re-publish the candidate only if still approved.
6. Attach timestamps, version IDs, tester, and screenshots/logs to
   `rollback-and-incident-drill`.

The drill must not use production DataStore mutation as a prop.
