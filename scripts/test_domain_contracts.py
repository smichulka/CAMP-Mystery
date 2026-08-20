"""Static contract tests for CAMP-Mystery's server-authoritative domains."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def service_methods(relative: str) -> set[str]:
    source = read(relative)
    return set(re.findall(r"function\s+[A-Za-z_][A-Za-z0-9_]*:([A-Za-z_][A-Za-z0-9_]*)\s*\(", source))


def assigned_strings(relative: str, field: str) -> list[str]:
    source = read(relative)
    return re.findall(rf"\b{re.escape(field)}\s*=\s*\"([^\"]+)\"", source)


class DomainContractTests(unittest.TestCase):
    def assert_methods(self, relative: str, expected: set[str]) -> None:
        missing = expected - service_methods(relative)
        self.assertFalse(missing, f"{relative} is missing methods: {sorted(missing)}")

    def test_runtime_service_apis(self) -> None:
        self.assert_methods(
            "src/server/Services/LobbyService.lua",
            {
                "AddPlayer",
                "RemovePlayer",
                "SetReady",
                "IsReady",
                "GetReadyHumans",
                "LockRoster",
                "ReleaseRound",
                "GetSnapshot",
            },
        )
        self.assert_methods(
            "src/server/Services/MatchmakingService.lua",
            {
                "AddPlayer",
                "RemovePlayer",
                "SetReady",
                "Tick",
                "ForceLock",
                "GetActiveRoster",
                "MarkRoundStarted",
                "FinishRound",
            },
        )
        self.assert_methods(
            "src/server/Systems/BotRosterSystem.lua",
            {
                "FillEmptySlots",
                "FillReplacement",
                "ReleaseRound",
            },
        )
        self.assert_methods(
            "src/server/Services/ComputerPlayerService.lua",
            {
                "BeginRound",
                "RegisterRoster",
                "GetRuntimeSnapshot",
                "GetAllRuntimeSnapshots",
                "ObserveForBot",
                "BroadcastObservation",
                "StepBot",
                "StepAll",
            },
        )
        self.assert_methods(
            "src/server/Services/ProfileService.lua",
            {
                "LoadPlayer",
                "ReleasePlayer",
                "GetSnapshot",
                "ApplyReward",
                "UpdateSettings",
                "PurchaseUpgrade",
                "UnlockCosmetic",
                "EquipCosmetic",
            },
        )

    def test_matchmaking_calls_exist_on_bot_roster(self) -> None:
        matchmaking = read("src/server/Services/MatchmakingService.lua")
        calls = set(re.findall(r"botRosterSystem:([A-Za-z_][A-Za-z0-9_]*)\s*\(", matchmaking))
        available = service_methods("src/server/Systems/BotRosterSystem.lua")
        self.assertFalse(
            calls - available,
            f"Matchmaking calls missing BotRosterSystem methods: {sorted(calls - available)}",
        )

    def test_bot_catalog_fills_full_roster(self) -> None:
        profile_ids = assigned_strings("src/server/Config/BotProfiles.lua", "id")
        self.assertGreaterEqual(len(profile_ids), 12)
        self.assertEqual(len(profile_ids), len(set(profile_ids)), "Bot profile IDs must be unique")
        difficulties = set(assigned_strings("src/server/Config/BotProfiles.lua", "difficulty"))
        self.assertEqual(difficulties, {"Beginner", "Average", "Expert"})

    def test_upgrade_catalog_has_each_playable_role(self) -> None:
        expected_roles = {
            "Camper",
            "Medic",
            "Trapper",
            "Medium",
            "Guard",
            "Protector",
            "Detective",
            "Murderer",
        }
        role_ids = assigned_strings("src/shared/Config/UpgradeCatalog.lua", "roleId")
        upgrade_ids = assigned_strings("src/shared/Config/UpgradeCatalog.lua", "id")
        self.assertEqual(set(role_ids), expected_roles)
        self.assertEqual(len(upgrade_ids), len(set(upgrade_ids)), "Upgrade IDs must be unique")

    def test_profile_has_studio_memory_fallback(self) -> None:
        source = read("src/server/Services/ProfileService.lua")
        for token in ("RunService:IsStudio()", "MemoryProfileStore.new()", 'storeKind = "Memory"'):
            self.assertIn(token, source)

    def test_reward_receipts_are_idempotent(self) -> None:
        source = read("src/server/Services/ProfileService.lua")
        self.assertGreaterEqual(source.count("hasReceipt("), 3)
        self.assertIn("recentRewardReceipts", source)
        self.assertIn("UpdateAsync", source)

    def test_reward_normalization_keeps_every_calculator_input(self) -> None:
        # Regression guard (2026-08-09): ApplyReward's normalizedInput silently
        # dropped sideObjectives/ghostObjectives for a while, zeroing those
        # payouts. Every optional field RewardCalculation reads must survive
        # normalization.
        source = read("src/server/Services/ProfileService.lua")
        for token in (
            "sideObjectives = finiteNumber(input.sideObjectives, 0)",
            "ghostObjectives = finiteNumber(input.ghostObjectives, 0)",
            "dailyStreakCount = advancedStreak(state.profile)",
        ):
            self.assertIn(token, source)

    def test_mystery_locations_are_registered_search_targets(self) -> None:
        # Every locationId a clue template can select must exist as a
        # SEARCH_TARGETS socket, or the assigned clue spawns no world glow and
        # the round ships an unfindable objective. Added 2026-08-09 when the
        # catalog expanded beyond the original seven town spots.
        import re

        catalog = read("src/server/Config/MysteryCatalog.lua")
        map_service = read("src/server/Services/ProductionMapService.lua")
        registered = set(re.findall(r'id = "([a-z0-9-]+)"', map_service))
        used: set[str] = set()
        for block in re.findall(r"locationIds = \{([^}]*)\}", catalog):
            used.update(re.findall(r'"([a-z0-9-]+)"', block))
        self.assertTrue(used, "catalog should declare clue locations")
        unregistered = sorted(used - registered)
        self.assertFalse(
            unregistered,
            f"clue locations missing from SEARCH_TARGETS: {unregistered}",
        )
        # The expansion districts must stay in play: at least a dozen distinct
        # locations beyond the original seven.
        self.assertGreaterEqual(len(used), 19, sorted(used))

    def test_daily_streak_is_server_authoritative_and_bounded(self) -> None:
        profile_service = read("src/server/Services/ProfileService.lua")
        for token in (
            "local function currentUtcDay()",
            "local function advancedStreak(",
            "profile.streakLastDay == today - 1",
            # advance persists inside the UpdateAsync transform via applyGrant
            "if grant.roundsPlayed > 0 then",
        ):
            self.assertIn(token, profile_service)
        calculation = read("src/server/Systems/RewardCalculation.lua")
        for token in (
            "input.dailyStreakCount or 1",
            "rewards.streakBonusMaxDays",
            "rewards.streakPerDayBonus",
            "dailyStreak = streakDays",
        ):
            self.assertIn(token, calculation)
        config = read("src/shared/Config/ProgressionConfig.lua")
        self.assertIn("streakPerDayBonus = 0.10", config)
        self.assertIn("streakBonusMaxDays = 5", config)
        # Streak-exclusive cosmetics (2026-08-09): granted server-side when the
        # stored streak reaches the threshold, and never manually purchasable.
        catalog = read("src/shared/Config/CosmeticCatalog.lua")
        self.assertIn('"Streak"', catalog)
        self.assertIn('id = "title-week-one-legend"', catalog)
        self.assertIn(
            'definition.unlockKind == "Streak"\n\t\t\t\tand profile.streakCount >= definition.unlockAmount',
            profile_service,
        )
        self.assertIn('return false, "StreakRequired"', profile_service)

    def test_wave6_live_ops_surface(self) -> None:
        catalog = read("src/shared/Config/CosmeticCatalog.lua")
        for token in (
            "FEATURED_ROTATION",
            "GetFeaturedCosmeticId",
            "GetTokenPrice",
            "featuredWeek",
        ):
            self.assertIn(token, catalog)
        progression = read("src/shared/Config/ProgressionConfig.lua")
        self.assertIn("featuredTokenDiscount = 0.15", progression)
        codex = read("src/shared/Config/CodexConfig.lua")
        self.assertIn("wendigo-survive-3", codex)
        self.assertIn("masteryTier", codex)
        analytics = read("src/server/Services/AnalyticsService.lua")
        self.assertIn("LogCustomEvent", analytics)
        self.assertIn("JoinLobby", analytics)
        self.assertNotIn("MarketplaceService", analytics)
        soft_launch = read("docs/SOFT_LAUNCH_GATES.md")
        self.assertIn("JoinLobby", soft_launch)
        self.assertIn("MarketplaceService", soft_launch)
        tips = read("src/shared/Config/TipCatalog.lua")
        self.assertIn('category = "COUNTERPLAY"', tips)
        self.assertIn("Monster Codex", tips)
        profile_service = read("src/server/Services/ProfileService.lua")
        self.assertIn("CosmeticCatalog.GetTokenPrice", profile_service)

    def test_launch_has_no_monetization_surface(self) -> None:
        forbidden = {
            "MarketplaceService",
            "PromptProductPurchase",
            "PromptGamePassPurchase",
            "ProcessReceipt",
        }
        for path in (ROOT / "src").rglob("*.lua"):
            source = path.read_text(encoding="utf-8")
            found = forbidden.intersection(source)
            self.assertFalse(found, f"{path.relative_to(ROOT)} contains {sorted(found)}")

    def test_production_remote_contract(self) -> None:
        project = json.loads(read("default.project.json"))
        remotes = project["tree"]["ReplicatedStorage"]["Remotes"]
        expected = {
            "GameStateChanged": "RemoteEvent",
            "GetGameState": "RemoteFunction",
            "RequestAction": "RemoteFunction",
            "Announcement": "RemoteEvent",
        }
        for name, class_name in expected.items():
            self.assertEqual(remotes.get(name, {}).get("$className"), class_name)

    def test_production_bootstrap_starts_runtime(self) -> None:
        source = read("src/server/Bootstrap.server.lua")
        for token in (
            'WaitForChild("GameRuntimeService")',
            'WaitForChild("AnalyticsService")',
            "getGameState.OnServerInvoke",
            "requestAction.OnServerInvoke",
            "gameStateChanged:FireClient",
            "runtime:Start()",
            "runtime:Stop()",
        ):
            self.assertIn(token, source)
        self.assertNotIn("RoundService.new()", source)
        self.assertNotIn("MarketplaceService", source)

    def test_runtime_closes_authority_and_moderation_gaps(self) -> None:
        source = read("src/server/Services/GameRuntimeService.lua")
        for token in (
            "TextService:FilterStringAsync",
            "GetNonChatStringForBroadcastAsync",
            "self:_isNearPart",
            "self.computerPlayers:BeginRound",
            "self.matchmaking:MarkRoundStarted",
            "self.profile:ApplyReward",
        ):
            self.assertIn(token, source)
        self.assertNotIn(
            "baseUtility = if suspect.key == self.culpritParticipantId",
            source,
            "Innocent bots must not receive the secret culprit through vote utility",
        )

    def test_release_round_lengths(self) -> None:
        source = read("src/shared/Config/RoundConfig.lua")
        production = [
            int(value)
            for value in re.findall(r"(?<!studio)durationSeconds\s*=\s*(\d+)", source)
        ]
        studio = [
            int(value)
            for value in re.findall(r"studioDurationSeconds\s*=\s*(\d+)", source)
        ]
        # Family-audience pacing: full rounds land between 12 and 18 minutes
        self.assertGreaterEqual(sum(production), 12 * 60)
        self.assertLessEqual(sum(production), 18 * 60)
        self.assertEqual(studio, [40, 8, 75, 30, 10, 100, 60, 12, 10])
        self.assertEqual(sum(studio), 5 * 60 + 45)


if __name__ == "__main__":
    unittest.main(verbosity=2)
