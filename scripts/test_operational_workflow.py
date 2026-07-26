"""Regression contracts for E2E release workflow and persistence testability."""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


class OperationalWorkflowContracts(unittest.TestCase):
    def test_windows_workflow_resolves_the_default_branch(self) -> None:
        script = source("scripts/CampMystery.ps1")
        self.assertIn("function Get-DefaultBranch", script)
        self.assertIn("function Sync-DefaultBranch", script)
        self.assertIn("refs/remotes/origin/HEAD", script)
        self.assertIn('git merge --ff-only "origin/$DefaultBranch"', script)
        self.assertNotIn("git switch master", script)
        self.assertNotIn("origin master", script)
        self.assertNotIn("Sync-Master", script)
        self.assertNotIn("pull `master`", source("README.md"))
        self.assertNotIn("Keep `master`", source("docs/DELIVERY_PLAN.md"))

    def test_real_datastore_test_mode_is_isolated_and_fault_injectable(self) -> None:
        config = source("src/server/Config/ProfileStoreConfiguration.lua")
        adapter = source("src/server/Adapters/RobloxProfileStore.lua")
        bootstrap = source("src/server/Bootstrap.server.lua")
        runtime = source("src/server/Services/GameRuntimeService.lua")
        progression = source("src/shared/Config/ProgressionConfig.lua")

        self.assertIn('mode ~= "TestDataStore"', config)
        self.assertIn("game.PrivateServerId", config)
        self.assertIn("RunService:IsStudio()", config)
        self.assertIn("testDataStorePrefix", config)
        self.assertIn("cannot target the production profile DataStore", config)
        self.assertIn("testLoadFailures", config)
        self.assertIn("testUpdateFailures", config)
        self.assertIn("remainingTestLoadFailures", adapter)
        self.assertIn("remainingTestUpdateFailures", adapter)
        self.assertIn("Injected test profile load failure", adapter)
        self.assertIn("Injected test profile update failure", adapter)
        self.assertIn("profileStore = profileStoreResolution.store", bootstrap)
        self.assertIn("profileStore: ProfileService.ProfileStore?", runtime)
        self.assertIn("ProfileService.new(configured.profileStore)", runtime)
        self.assertIn('testDataStorePrefix = "CAMP_Mystery_Profile_TEST_"', progression)

    def test_failed_release_save_is_retained_for_retry(self) -> None:
        profile = source("src/server/Services/ProfileService.lua")
        release = profile.split(
            "function ProfileService:ReleasePlayer", maxsplit=1
        )[1].split("function ProfileService:ApplyReward", maxsplit=1)[0]
        self.assertIn('reason == "GuestMode"', release)
        self.assertIn("retaining state for retry", release)
        self.assertIn("self.profiles[player.UserId] == state", release)
        self.assertNotIn(
            "local saved, reason = self:SavePlayer(player)\n\tself.profiles[player.UserId] = nil",
            release,
        )

        start = profile.split("function ProfileService:Start", maxsplit=1)[1].split(
            "function ProfileService:Stop", maxsplit=1
        )[0]
        stop = profile.split("function ProfileService:Stop", maxsplit=1)[1]
        self.assertIn("for _, state in self.profiles do", start)
        self.assertIn("for _, state in self.profiles do", stop)
        self.assertIn("local player = state.player", start)
        self.assertIn("local player = state.player", stop)


if __name__ == "__main__":
    unittest.main(verbosity=2)
