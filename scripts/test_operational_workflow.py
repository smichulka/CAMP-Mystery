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
        memory_adapter = source("src/server/Adapters/MemoryProfileStore.lua")
        roblox_adapter = source("src/server/Adapters/RobloxProfileStore.lua")
        bootstrap = source("src/server/Bootstrap.server.lua")
        progression = source("src/shared/Config/ProgressionConfig.lua")

        self.assertIn('mode ~= "TestDataStore"', config)
        self.assertIn("game.PrivateServerId", config)
        self.assertIn("RunService:IsStudio()", config)
        self.assertIn("testDataStorePrefix", config)
        self.assertIn("cannot target the production profile DataStore", config)
        self.assertIn("testLoadFailures", config)
        self.assertIn("testUpdateFailures", config)
        self.assertIn('resolution.mode == "TestDataStore"', memory_adapter)
        self.assertIn('require(script.Parent:WaitForChild("RobloxProfileStore"))', memory_adapter)
        self.assertIn("ProfileStoreConfiguration.Resolve()", roblox_adapter)
        self.assertIn("local loadFailures = 0", roblox_adapter)
        self.assertIn("local updateFailures = 0", roblox_adapter)
        self.assertIn('resolution.mode == "TestDataStore"', roblox_adapter)
        self.assertIn("remainingTestLoadFailures", roblox_adapter)
        self.assertIn("remainingTestUpdateFailures", roblox_adapter)
        self.assertIn("Injected test profile load failure", roblox_adapter)
        self.assertIn("Injected test profile update failure", roblox_adapter)
        self.assertIn("ProfileStoreConfiguration.Resolve()", bootstrap)
        self.assertIn("ProfileServiceReliabilityPatch.Apply()", bootstrap)
        self.assertNotIn("profileStore = profileStoreResolution.store", bootstrap)
        self.assertIn('testDataStorePrefix = "CAMP_Mystery_Profile_TEST_"', progression)

    def test_failed_release_save_is_retained_for_bounded_retry(self) -> None:
        patch = source("src/server/Services/ProfileServiceReliabilityPatch.lua")
        self.assertIn("class.ReleasePlayer = function", patch)
        self.assertIn("retaining state for retry", patch)
        self.assertIn("scheduleRetry", patch)
        self.assertIn("MAX_RELEASE_RETRY_ATTEMPTS = 5", patch)
        self.assertIn("for attempt = 1, MAX_RELEASE_RETRY_ATTEMPTS do", patch)
        self.assertIn("retaining state for shutdown", patch)
        self.assertIn("clearIfSameDeparture", patch)
        self.assertIn("currentPlayer == departingPlayer", patch)
        self.assertIn("currentPlayer ~= entry.player", patch)
        self.assertIn("class.LoadPlayer = function", patch)
        self.assertIn("class.Stop = function", patch)
        self.assertIn("return originalStop(self)", patch)

    def test_temporary_migration_files_are_removed(self) -> None:
        self.assertFalse((ROOT / "scripts/apply_runtime_fixes.py").exists())
        self.assertFalse((ROOT / ".github/workflows/apply-runtime-fixes.yml").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
