# CAMP-Mystery Release Evidence

Release approval is based on evidence from one exact commit and one private Roblox place
version. Repository automation is necessary, but it cannot approve a public release by
itself.

## Evidence commands

Create repository evidence without pretending that Studio tests ran:

```powershell
python scripts/release_gate.py --commit <40-character-commit-sha>
```

This writes:

- `build/release-evidence/release-evidence.json`;
- `build/release-evidence/release-evidence.md`;
- full command output under `build/release-evidence/logs/`.

The normal evidence command exits successfully when the repository suite passes. Its
overall verdict remains **blocked** until Roblox observations are supplied; that is
intentional.

For a real release candidate:

1. Copy `tools/release-observations.template.json` outside the ignored `build/` folder
   or into the release evidence folder.
2. Replace the commit and private place-version placeholders.
3. Run every named section in `docs/RELEASE_CHECKLIST.md`.
4. Set a gate to `pass` only after the whole named section passes on that commit/place
   version.
5. Add at least one evidence path or URL for every passing gate. Use screenshots,
   exported Studio logs, MicroProfiler captures, test matrices, seed/outcome tables,
   Creator Dashboard moderation pages, or incident-drill records as appropriate.
6. Run:

```powershell
python scripts/release_gate.py `
  --release-candidate `
  --commit <40-character-commit-sha> `
  --observations .\path\to\completed-observations.json
```

The gate fails if Rojo cannot build, content is pending, an observation belongs to
another commit, a required observation is not `pass`, or a passing gate has no evidence.
When Git is available, the supplied commit must match the checked-out `HEAD`, and a
release-candidate checkout must be clean. Tester, place version, UTC timestamps, and
evidence paths/URLs must be concrete; template placeholders are rejected.

## Content evidence

`assets/content-manifest.json` is the release inventory for models, animation sets,
audio, images, and publishing art. Development fallbacks may remain available, but the
public-release gate requires every listed content item to record:

- `sourceStatus: "installed"`;
- `license.status` of `owned` or `licensed`;
- the owner and a durable proof path;
- `moderation.status: "approved"`;
- a positive Roblox asset ID;
- the UTC moderation review time.

When an inventory record represents several uploaded files, split it into one record per
moderated Roblox asset before release. Do not paste credentials, cookies, private keys,
or access tokens into the manifest or evidence.

The structural inventory check is:

```powershell
python scripts/validate_content_manifest.py
```

The strict public-content check is:

```powershell
python scripts/validate_content_manifest.py --require-ready
```

## Required soak and fuzz evidence

The Python suite runs 1,000 deterministic reference rounds and 10,000 hostile reference
payloads. Those tests prove that the repository contracts and pure-Python models retain
their invariants. They do **not** send a single remote through Roblox.

Release evidence must also include:

- the ten Studio/server soak seeds and each outcome;
- instance, connection, memory, network, physics, script-time, and frame-rate readings
  before and after ten resets;
- malformed runtime remote cases: wrong types, oversized strings, missing IDs, stale
  round IDs, replayed sequences, and out-of-range positions;
- confirmation that every case was rejected without an exception or state mutation.

## Evidence retention

Attach the evidence artifact to the release record or copy it to a durable, access-
controlled project location. Retain the exact commit, Roblox place version, DataStore
test namespace, tester, timestamps, device matrix, and rollback version. Evidence from
an earlier commit is useful history, but it is not approval for a newer commit.
