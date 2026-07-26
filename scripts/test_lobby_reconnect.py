"""Focused contracts for Claude Request 0007 lobby polish and reconnect resilience."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class LobbyReconnectTests(unittest.TestCase):
    def test_tip_catalog_is_strict_generic_and_large_enough(self) -> None:
        catalog = read("src/shared/Config/TipCatalog.lua")
        self.assertTrue(catalog.startswith("--!strict"))
        self.assertGreaterEqual(len(re.findall(r'\{ category = "', catalog)), 16)
        for category in ("ROLES", "MONSTERS", "EVIDENCE", "VOTING"):
            self.assertIn(f'category = "{category}"', catalog)
        self.assertIn("table.freeze(definitions)", catalog)

    def test_lobby_roster_carousel_and_countdown_contract(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for token in (
            'WaitForChild("TipCatalog")',
            "currentTime - self.lobbyTipChangedAt >= 8",
            "duration = 0.4",
            '"Waiting for players..."',
            "Theme.Notebook.PageColor",
            "Theme.Notebook.InkColor",
            "function GameView:_shimmerLobbyRoster()",
            "Motion.StaggerChildren(self.lobbyRoster",
            "lobbySeconds <= 10",
            "Theme.Typography.DisplaySize * 2",
            "{ Scale = 1.15 }",
        ):
            self.assertIn(token, view)

    def test_locked_human_rejoin_reclaims_bot_roster_slot(self) -> None:
        lobby = read("src/server/Services/LobbyService.lua")
        matchmaking = read("src/server/Services/MatchmakingService.lua")
        bots = read("src/server/Systems/BotRosterSystem.lua")
        for token in (
            "disconnectedLockedPlayers",
            "disconnected.lockedRoundId == self.activeRoundId",
            "return true",
        ):
            self.assertIn(token, lobby)
        for token in (
            "disconnectedReplacementsByUserId",
            "function MatchmakingService:_RestoreLockedParticipant",
            "self.botRosterSystem:RestoreHuman(",
            "roster.participants[replacementIndex] = human",
            "onHumanRejoin",
        ):
            self.assertIn(token, matchmaking)
        for token in (
            "function BotRosterSystem:RestoreHuman(",
            "roster.participantIds[replacementIndex] = humanParticipantId",
            "table.remove(roster.botParticipantIds, botIndex)",
            "replacement.controller.connected = false",
        ):
            self.assertIn(token, bots)

    def test_runtime_reverse_handoff_restores_round_identity(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        for token in (
            "local function transferParticipantState(",
            "inventory:Transfer(",
            "runtime.statusEffects:TransferParticipant(",
            "runtime.roleAbilities:TransferParticipant(",
            "runtime.voting:TransferParticipant(",
            "runtime.mystery:TransferParticipant(",
            "runtime.computerPlayers:DeactivateBot(source.participantId)",
            "onHumanRejoin = function(",
            "callback(player, runtime:GetGameState(player))",
            "[GameRuntimeService] Rejoined user",
        ):
            self.assertIn(token, runtime)

    def test_client_reconnect_is_quiet_and_role_specific(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        view = read("src/client/UI/GameView.lua")
        for token in (
            "local receivedFullState = false",
            "local isReconnectSnapshot = firstFullState",
            'player.role ~= "Spectator"',
            "lastCinematicPhase = phaseName",
            "lastEvidenceFound = evidenceFoundCount(payload)",
            '"Reconnected — your role is " .. roleName',
            '"Info",\n\t\t\t\t\t4',
        ):
            self.assertIn(token, controller)
        self.assertIn(
            "function GameView:PrepareReconnectSnapshot(phaseName: string)",
            view,
        )
        self.assertIn("gameView:PrepareReconnectSnapshot(reconnectPhase)", controller)
        self.assertIn('SetAttribute("SuppressNextStagger", true)', view)


if __name__ == "__main__":
    unittest.main(verbosity=2)
