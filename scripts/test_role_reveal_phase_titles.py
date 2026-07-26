"""Focused contracts for Claude Request 0008 role and phase ceremonies."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class RoleRevealPhaseTitleTests(unittest.TestCase):
    def test_phase_title_catalog_is_strict_frozen_and_complete(self) -> None:
        catalog = read("src/shared/Config/PhaseTitles.lua")
        self.assertTrue(catalog.startswith("--!strict"))
        for phase in (
            "MurderPlanning",
            "NightTransform",
            "Investigation",
            "Day",
            "Campfire",
            "Resolution",
        ):
            self.assertIn(f"\t{phase} = table.freeze(", catalog)
        self.assertNotIn("\tLobby =", catalog)
        self.assertNotIn("\tRewards =", catalog)
        self.assertIn("return table.freeze(PhaseTitles)", catalog)

    def test_round_controller_fires_once_and_suppresses_reconnect(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        for token in (
            "local lastRoleRevealRound: number? = nil",
            'previousPhase == "Lobby"',
            'roleName ~= "Spectator"',
            "and not reconnect",
            "and lastRoleRevealRound ~= roundNumber",
            "lastRoleRevealRound = roundNumber",
            "currentView:PlayRoleReveal(",
            'roleName == "Murderer"',
            "lastRoleRevealRound = nil",
        ):
            self.assertIn(token, controller)
        reconnect_branch = controller.split("if isReconnectSnapshot then", 1)[1]
        self.assertIn("lastRoleRevealRound = round.roundNumber", reconnect_branch)

    def test_role_reveal_card_is_skippable_reduced_and_cancel_safe(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for token in (
            "roleRevealToken: number",
            "roleRevealOverlay: CanvasGroup?",
            "roleRevealActive: boolean",
            "function GameView:_cancelRoleReveal()",
            "function GameView:PlayRoleReveal(",
            'overlay.Name = "RoleRevealOverlay"',
            "overlay.GroupTransparency = 1",
            "cardHost.Size = UDim2.fromOffset(280, 200)",
            "card.BackgroundColor3 = Theme.Notebook.PageColor",
            "strip.Size = UDim2.new(1, 0, 0, 8)",
            "Theme.Colors.DangerBright",
            '"YOUR ROLE"',
            "Components.PlayUISound(\"open\")",
            "Motion.SlideUp(cardHost",
            "Motion.PopIn(card",
            "overlay.InputBegan:Connect",
            "if reducedMotion then 1 else 2.35",
            "restingPosition.Y.Offset - 120",
        ):
            self.assertIn(token, view)

    def test_phase_band_has_required_timing_style_and_guards(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for token in (
            "phaseTitleToken: number",
            "phaseTitleActive: boolean",
            "function GameView:_cancelPhaseTitle()",
            "function GameView:PlayPhaseTitleCard(phaseName: string, isReconnect: boolean)",
            "or isReconnect",
            "or self.roleRevealActive",
            'band.Name = "PhaseTitleBand"',
            "band.Size = UDim2.new(1, 0, 0, 96)",
            "band.BackgroundTransparency = 0.45",
            "scale.Scale = 0.97",
            "math.floor(Theme.Typography.HeadingSize * 1.4)",
            "Components.SetLetterspacedText(title, entry.title)",
            "subtitle.TextTransparency = 0.7",
            "task.delay(0.9, cleanup)",
            "TweenInfo.new(0.25",
            "task.delay(2.05",
            "TweenInfo.new(0.4",
        ):
            self.assertIn(token, view)

    def test_phase_title_dispatch_order_follows_cinematic(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        cinematic = controller.index(
            "currentCinematics:PlayPhaseTransition(phaseName)"
        )
        title = controller.index(
            "currentView:PlayPhaseTitleCard(phaseName, reconnect)"
        )
        resolution = controller.index(
            'if phaseName == "Resolution" and currentView then'
        )
        self.assertLess(cinematic, title)
        self.assertLess(title, resolution)


if __name__ == "__main__":
    unittest.main(verbosity=2)
