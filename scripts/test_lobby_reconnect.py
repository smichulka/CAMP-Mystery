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

    def test_client_reconnect_is_quiet_and_contextual(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        view = read("src/client/UI/GameView.lua")
        for token in (
            "local receivedFullState = false",
            "local isReconnectSnapshot = firstFullState",
            'player.role ~= "Spectator"',
            "lastCinematicPhase = phaseName",
            "lastEvidenceFound = evidenceFoundCount(payload)",
            "if reconnect and currentView and not roundEnded and phaseName ~= nil then",
            '"You are a ghost. Observe the round and witness the verdict."',
            '"Your identity was revealed. Watch the round as a ghost."',
            '"Reconnected — you\'re incapacitated"',
            '"Reconnected — you\'re injured"',
            'string.format("Current phase: %s.", phaseName)',
            'if roleName == "Murderer" then',
        ):
            self.assertIn(token, controller)
        self.assertNotIn('"Reconnected — your role is " .. roleName', controller)
        # Murderer ghost toast uses Warning; non-Murderer uses Info
        ghost_block = controller.split("if isGhost then", 1)[1].split(
            "elseif currentHealthState", 1
        )[0]
        self.assertIn('"Warning"', ghost_block)
        self.assertIn('"Info"', ghost_block)
        self.assertLess(ghost_block.index('"Warning"'), ghost_block.index('"Info"'))
        self.assertIn(
            "function GameView:PrepareReconnectSnapshot(phaseName: string)",
            view,
        )
        self.assertIn("gameView:PrepareReconnectSnapshot(reconnectPhase)", controller)
        self.assertIn('SetAttribute("SuppressNextStagger", true)', view)


    def test_request_0096_reconnect_role_messages_and_urgency_warning_split(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        # Active Murderer reconnect message
        self.assertIn('"You are the Murderer. Phase: %s. Stay in character."', controller)
        # Spectator reconnect message
        self.assertIn('"Observing — Phase: %s."', controller)
        # Phase-specific camper reconnect messages
        for token in (
            '"Complete camp work and interview witnesses before nightfall."',
            '"Find and post evidence before the campfire vote."',
            '"Cast your vote carefully. The verdict decides the round."',
        ):
            self.assertIn(token, controller)
        # Reconnect block ordering: Murderer → Spectator → phase messages
        reconnect_start = controller.index("if reconnect and currentView and not roundEnded")
        reconnect_end = controller.index("local abilityMonster = if type(snapshot)", reconnect_start)
        reconnect_block = controller[reconnect_start:reconnect_end]
        murderer_msg = reconnect_block.index('"You are the Murderer.')
        spectator_msg = reconnect_block.index('"Observing')
        self.assertLess(murderer_msg, spectator_msg)
        # Urgency warning: Ghost/Spectator are suppressed; Murderer vs Camper get different copy
        self.assertIn("not urgIsGhost and urgRole", controller)
        self.assertIn('"Investigation ending"', controller)
        self.assertIn('"The campers are running out of time. Prepare for the vote."', controller)
        self.assertIn('"Investigation closing"', controller)
        self.assertIn('"Under a minute left. Post your evidence before campfire."', controller)
        # Murderer urgency uses Success style; camper urgency uses DangerBright
        urgency_start = controller.index("sentUrgencyWarning = true")
        urgency_end = controller.index("end\nend\n\nlocal function evidenceCopy", urgency_start)
        urgency_block = controller[urgency_start:urgency_end]
        self.assertLess(urgency_block.index('"Success"'), urgency_block.index('"DangerBright"'))


    def test_request_0116_ghost_reconnect_murderer_vs_camper_split(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        reconnect_start = controller.index("if reconnect and currentView and not roundEnded")
        reconnect_end = controller.index("local abilityMonster = if type(snapshot)", reconnect_start)
        reconnect_block = controller[reconnect_start:reconnect_end]
        # Ghost block appears before the active (non-ghost) reconnect paths
        ghost_block_start = reconnect_block.index("if isGhost then")
        non_ghost_murderer_start = reconnect_block.index('"You are the Murderer.')
        self.assertLess(ghost_block_start, non_ghost_murderer_start)
        # Ghost + Murderer: Warning notification identifies revealed identity
        ghost_block_end = reconnect_block.index("elseif currentHealthState ==", ghost_block_start)
        ghost_block = reconnect_block[ghost_block_start:ghost_block_end]
        self.assertIn('roleName == "Murderer"', ghost_block)
        self.assertIn('"Your identity was revealed. Watch the round as a ghost."', ghost_block)
        self.assertIn('"Warning"', ghost_block)
        # Ghost + non-Murderer: Info notification — observer perspective
        self.assertIn('"You are a ghost. Observe the round and witness the verdict."', ghost_block)
        self.assertIn('"Info"', ghost_block)
        # Murderer ghost notification (Warning) appears before non-Murderer ghost (Info)
        self.assertLess(
            ghost_block.index('"Warning"'),
            ghost_block.index('"Info"'),
        )


    def test_request_0119_mid_round_notification_role_dispatch(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        # Evidence found: Murderer=Warning, Ghost/Spectator=Info, camper=effect+discovery
        ev_start = controller.index("if evidenceFound > lastEvidenceFound and currentView then")
        ev_end = controller.index("lastEvidenceFound = evidenceFound", ev_start)
        ev_block = controller[ev_start:ev_end]
        self.assertIn('"A clue has been posted against you. Stay composed."', ev_block)
        self.assertIn('"A clue has been added to the board."', ev_block)
        self.assertIn('"Warning"', ev_block)
        self.assertIn('"Info"', ev_block)
        self.assertLess(ev_block.index('"Warning"'), ev_block.index('"Info"'))
        self.assertIn('elseif isGhost or roleName == "Spectator" then', ev_block)
        self.assertIn("FlashEvidenceFound", ev_block)
        self.assertIn("PlayEvidenceDiscovery", ev_block)
        # Witness interviewed: suppressed for ghost/Spectator; Murderer=Warning, others=Info
        wit_start = controller.index(
            "if revealedWitnessCount > lastRevealedWitnessCount"
        )
        wit_end = controller.index("lastRevealedWitnessCount = revealedWitnessCount", wit_start)
        wit_block = controller[wit_start:wit_end]
        self.assertIn("not isGhost", wit_block)
        self.assertIn('roleName ~= "Spectator"', wit_block)
        self.assertIn(
            '"A witness has been questioned — %d of %d counselors spoken to."', wit_block
        )
        self.assertIn('"%d of %d witnesses spoken to."', wit_block)
        # Camp objectives: same ghost/Spectator gate; Murderer=Warning, others=Info
        obj_start = controller.index("if objectivesCompleted > lastObjectivesCompleted")
        obj_end = controller.index("lastObjectivesCompleted = objectivesCompleted", obj_start)
        obj_block = controller[obj_start:obj_end]
        self.assertIn("not isGhost", obj_block)
        self.assertIn(
            '"Campers advancing: %d of %d tasks done."', obj_block
        )
        self.assertIn('"%d of %d tasks done."', obj_block)
        # All votes in: Murderer=DangerBright, Ghost/Spectator=Info, camper=Warning
        vote_start = controller.index(
            'if phaseName == "Campfire" and not reconnect and roundNumber ~= nil and currentView then'
        )
        vote_end = controller.index("lastVoteCompleteRound = roundNumber", vote_start)
        vote_block = controller[vote_start:vote_end]
        self.assertIn('"The vote is sealed. Your fate is decided."', vote_block)
        self.assertIn('"The campfire vote is sealed. Watch the verdict."', vote_block)
        self.assertIn('"The campfire vote is sealed. The verdict is coming."', vote_block)
        self.assertIn('"DangerBright"', vote_block)
        self.assertLess(vote_block.index('"DangerBright"'), vote_block.index('"Info"'))
        self.assertLess(vote_block.index('"Info"'), vote_block.index('"Warning"'))
        self.assertIn('elseif isGhost or roleName == "Spectator" then', vote_block)


if __name__ == "__main__":
    unittest.main(verbosity=2)
