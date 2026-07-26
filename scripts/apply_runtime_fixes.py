"""Apply the large-file CAMP-Mystery E2E fixes once, then remove this migration."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(relative: str, old: str, new: str) -> None:
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{relative}: expected one exact block, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    print(f"updated: {relative}")


replace_once(
    "src/server/Services/ProfileService.lua",
    "type ProfileStore = {\n",
    "export type ProfileStore = {\n",
)
replace_once(
    "src/server/Services/GameRuntimeService.lua",
    '''export type RuntimeOptions = {
\tautoRun: boolean?,
\tfillWithBots: boolean?,
''',
    '''export type RuntimeOptions = {
\tautoRun: boolean?,
\tfillWithBots: boolean?,
\tprofileStore: ProfileService.ProfileStore?,
''',
)
replace_once(
    "src/server/Services/GameRuntimeService.lua",
    "\tlocal profile = ProfileService.new()\n",
    "\tlocal profile = ProfileService.new(configured.profileStore)\n",
)

replace_once(
    "src/server/Services/ProfileService.lua",
    '''type ProfileState = {
\tprofile: PlayerProfile,
''',
    '''type ProfileState = {
\tplayer: Player,
\tprofile: PlayerProfile,
''',
)
replace_once(
    "src/server/Services/ProfileService.lua",
    '''\tlocal existing = self.profiles[player.UserId]
\tif existing then
\t\treturn self:_Snapshot(existing)
\tend
''',
    '''\tlocal existing = self.profiles[player.UserId]
\tif existing then
\t\texisting.player = player
\t\treturn self:_Snapshot(existing)
\tend
''',
)
replace_once(
    "src/server/Services/ProfileService.lua",
    '''\t\tlocal guestState: ProfileState = {
\t\t\tprofile = defaultProfile(),
''',
    '''\t\tlocal guestState: ProfileState = {
\t\t\tplayer = player,
\t\t\tprofile = defaultProfile(),
''',
)
replace_once(
    "src/server/Services/ProfileService.lua",
    '''\tlocal state: ProfileState = {
\t\tprofile = profile,
''',
    '''\tlocal state: ProfileState = {
\t\tplayer = player,
\t\tprofile = profile,
''',
)
replace_once(
    "src/server/Services/ProfileService.lua",
    '''function ProfileService:ReleasePlayer(player: Player): (boolean, string?)
\tlocal state = self.profiles[player.UserId]
\tif not state then
\t\treturn true, nil
\tend
\tlocal saved, reason = self:SavePlayer(player)
\tself.profiles[player.UserId] = nil
\treturn saved, reason
end
''',
    '''function ProfileService:ReleasePlayer(player: Player): (boolean, string?)
\tlocal state = self.profiles[player.UserId]
\tif not state then
\t\treturn true, nil
\tend
\tstate.player = player
\tlocal saved, reason = self:SavePlayer(player)
\tif saved or reason == "GuestMode" then
\t\tif self.profiles[player.UserId] == state then
\t\t\tself.profiles[player.UserId] = nil
\t\tend
\telseif self.profiles[player.UserId] == state then
\t\twarn(
\t\t\tstring.format(
\t\t\t\t"[ProfileService] Release save failed for user %d; retaining state for retry: %s",
\t\t\t\tplayer.UserId,
\t\t\t\treason or "UnknownFailure"
\t\t\t)
\t\t)
\tend
\treturn saved, reason
end
''',
)
replace_once(
    "src/server/Services/ProfileService.lua",
    '''\t\t\tfor _, player in Players:GetPlayers() do
\t\t\t\ttask.spawn(function()
\t\t\t\t\tself:SavePlayer(player)
\t\t\t\tend)
\t\t\tend
''',
    '''\t\t\tfor _, state in self.profiles do
\t\t\t\tlocal player = state.player
\t\t\t\ttask.spawn(function()
\t\t\t\t\tself:SavePlayer(player)
\t\t\t\tend)
\t\t\tend
''',
)
replace_once(
    "src/server/Services/ProfileService.lua",
    '''\tlocal remaining = 0
\tfor _, player in Players:GetPlayers() do
\t\tif self.profiles[player.UserId] then
\t\t\tremaining += 1
\t\t\ttask.spawn(function()
\t\t\t\tlocal saved, reason = self:SavePlayer(player)
\t\t\t\tif not saved and reason ~= "GuestMode" then
\t\t\t\t\twarn(
\t\t\t\t\t\tstring.format(
\t\t\t\t\t\t\t"[ProfileService] Shutdown save failed for user %d: %s",
\t\t\t\t\t\t\tplayer.UserId,
\t\t\t\t\t\t\treason or "UnknownFailure"
\t\t\t\t\t\t)
\t\t\t\t\t)
\t\t\t\tend
\t\t\t\tremaining -= 1
\t\t\tend)
\t\tend
\tend
''',
    '''\tlocal remaining = 0
\tfor _, state in self.profiles do
\t\tlocal player = state.player
\t\tremaining += 1
\t\ttask.spawn(function()
\t\t\tlocal saved, reason = self:SavePlayer(player)
\t\t\tif not saved and reason ~= "GuestMode" then
\t\t\t\twarn(
\t\t\t\t\tstring.format(
\t\t\t\t\t\t"[ProfileService] Shutdown save failed for user %d: %s",
\t\t\t\t\t\tplayer.UserId,
\t\t\t\t\t\treason or "UnknownFailure"
\t\t\t\t\t)
\t\t\t\t)
\t\t\tend
\t\t\tremaining -= 1
\t\tend)
\tend
''',
)

replace_once(
    "scripts/validate_project.py",
    '    ROOT / "src/server/Config/WorldManifest.lua",\n',
    '    ROOT / "src/server/Config/WorldManifest.lua",\n'
    '    ROOT / "src/server/Config/ProfileStoreConfiguration.lua",\n',
)
replace_once(
    "scripts/test_server_release_contracts.py",
    '        self.assertIn("self:SavePlayer(player)", stop_body)\n',
    '        self.assertIn("self:SavePlayer(player)", stop_body)\n'
    '        self.assertIn("for _, state in self.profiles do", stop_body)\n'
    '        release_body = profile.split(\n'
    '            "function ProfileService:ReleasePlayer", maxsplit=1\n'
    '        )[1].split("function ProfileService:ApplyReward", maxsplit=1)[0]\n'
    '        self.assertIn("retaining state for retry", release_body)\n',
)

replace_once(
    "docs/TESTING.md",
    "and client release contracts, release readiness tests, 512 deterministic roster/mystery\n",
    "and client release contracts, operational workflow contracts, release readiness tests,\n"
    "512 deterministic roster/mystery\n",
)
replace_once(
    "docs/TESTING.md",
    '''## Studio profile test

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
''',
    '''## Studio profile and DataStore test

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

To exercise the real Roblox adapter in Studio or a private server, use a disposable test
place/namespace and set these **ServerStorage attributes** before starting the server:

| Attribute | Value |
|---|---|
| `CampMysteryProfileStoreMode` | `TestDataStore` |
| `CampMysteryTestDataStoreName` | A unique name beginning with `CAMP_Mystery_Profile_TEST_` |
| `CampMysteryTestLoadFailures` | Optional integer `0`–`100` |
| `CampMysteryTestUpdateFailures` | Optional integer `0`–`100` |

Enable Studio access to API services only in the disposable test place. Test mode is
rejected on a normal public server, rejects the production DataStore name, and requires
the test prefix. Remove the attributes—or set mode to `Auto`—to restore the normal Studio
memory path.

Use injected failure counts below the configured retry count to prove transient recovery.
Use a count equal to or greater than the retry count to prove guest/error behavior. Then
verify schema-0 migration, repeated save/load idempotency, unsupported-schema rejection,
leave/rejoin persistence, duplicate-reward protection, and failed leave-save retry.

Published servers use the production Roblox DataStore adapter with bounded exponential
retries. There is no MarketplaceService, Robux purchase, premium multiplier, paid
currency, or receipt-processing path at launch.
''',
)
replace_once(
    "docs/RELEASE_CHECKLIST.md",
    '''Use a disposable test universe/DataStore namespace; never run destructive migration
tests against production player data.
''',
    '''Use a disposable test universe/DataStore namespace; never run destructive migration
tests against production player data. Configure the server-only attributes documented in
`TESTING.md`; the runtime rejects the production namespace and restricts test mode to
Studio or a private server.
''',
)

for relative in (
    "scripts/apply_runtime_fixes.py",
    ".github/workflows/apply-runtime-fixes.yml",
):
    path = ROOT / relative
    if path.exists():
        path.unlink()
        print(f"removed: {relative}")

print("Runtime E2E fixes applied")
