"""Focused contracts for Claude Request 0009 win reveal and item feedback."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class WinRevealItemFeedbackTests(unittest.TestCase):
    def test_server_resolves_winner_during_resolution(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        resolution = runtime.index('elseif phase == "Resolution" then')
        rewards = runtime.index('elseif phase == "Rewards" then', resolution)
        resolution_branch = runtime[resolution:rewards]
        self.assertIn("self:_ResolveAccusation()", resolution_branch)
        self.assertNotIn("self:_ApplyRewards()", resolution_branch)

    def test_controller_dispatches_winner_once_after_vote(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        for token in (
            "local lastWinnerAnnounced: string? = nil",
            'phaseName == "Resolution" or phaseName == "Rewards"',
            "and not reconnect",
            "and lastWinnerAnnounced ~= winner",
            "lastWinnerAnnounced = winner",
            'currentView:PlayWinReveal(winner, winner == "Campers", roleName)',
            "playVoteReveal(snapshot, currentView, revealWinner, roleName)",
            "lastWinnerAnnounced = nil",
        ):
            self.assertIn(token, controller)
        vote = controller.index(
            "playVoteReveal(snapshot, currentView, revealWinner, roleName)"
        )
        fallback = controller.index(
            "if revealWinner and not winnerQueuedAfterVote then"
        )
        self.assertLess(vote, fallback)

    def test_win_reveal_has_required_style_timing_and_safety(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for token in (
            "winRevealToken: number",
            "winRevealOverlay: CanvasGroup?",
            "winRevealActive: boolean",
            "function GameView:_cancelWinReveal()",
            "function GameView:PlayWinReveal(winner: string, isHumanWin: boolean, localRole: string?)",
            'overlay.Name = "WinRevealOverlay"',
            "overlay.BackgroundColor3 = Theme.Colors.Background",
            "overlay.ZIndex = 88",
            "topStrip.Size = UDim2.new(1, 0, 0, 4)",
            "bottomStrip.Size = UDim2.new(1, 0, 0, 4)",
            "Theme.Colors.DangerBright",
            'safeWinner .. " WIN"',
            "64,",
            '"The mystery is solved."',
            '"The monster escapes into the night."',
            "subtitle.TextTransparency = 0.4",
            "titleScale.Scale = 0.9",
            "overlay.InputBegan:Connect",
            'Components.PlayUISound(if isHumanWin then "success" else "error")',
            "task.delay(0.8, exitReveal)",
            "TweenInfo.new(0.3",
            "task.delay(2.3, exitReveal)",
            "TweenInfo.new(0.4",
        ):
            self.assertIn(token, view)

    def test_request_0048_role_aware_cinematic_copy(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        view = read("src/client/UI/GameView.lua")
        for token in (
            'local resolvedRole = localRole or ""',
            'if resolvedRole == "Murderer" then',
            'title.Text = "CAUGHT"',
            'subtitle.Text = "The camp unmasked you. Your hunt is over."',
            'title.Text = "YOU ESCAPED"',
            'subtitle.Text = "Your identity was never revealed. A flawless hunt."',
            'if isMonster then "YOU ARE THE THREAT" else "YOUR ROLE"',
            'monsterActive and (phase == "Investigation" or phase == "NightTransform")',
        ):
            self.assertIn(token, view)
        for token in (
            'currentView:PlayWinReveal(winner, winner == "Campers", roleName)',
            'local roundToastRole = if type(player) == "table"',
            'then "Your identity is hidden. Play the role."',
            'elseif roundToastRole == "Spectator"',
            'then "You are observing this round."',
            'else "The mystery begins. Stay together."',
        ):
            self.assertIn(token, controller)

    def test_vote_completion_waits_until_confetti_lifetime_ends(self) -> None:
        view = read("src/client/UI/GameView.lua")
        self.assertIn(
            "task.delay(if reducedMotion then 0.15 else 0.9, function()",
            view,
        )
        self.assertIn("if active() and onComplete then", view)
        confetti_destroy = view.index("task.delay(0.85, function()")
        reveal_callback = view.index(
            "task.delay(if reducedMotion then 0.15 else 0.9, function()"
        )
        self.assertLess(confetti_destroy, reveal_callback)

    def test_item_success_and_equip_have_distinct_feedback(self) -> None:
        view = read("src/client/UI/GameView.lua")
        result_start = view.index(
            "function GameView:HandleActionResult(accepted: boolean)"
        )
        result_end = view.index(
            "function GameView:_chooseParticipant", result_start
        )
        result = view[result_start:result_end]
        self.assertIn("if accepted then", result)
        self.assertIn("Motion.PopIn(control, { duration = 0.12 })", result)
        self.assertIn('Components.PlayUISound("success")', result)
        self.assertIn("Motion.Shake(control)", result)
        self.assertLess(
            result.index("Motion.PopIn(control"),
            result.index("self.lastActionControl = nil"),
        )

        equip_start = view.index("function GameView:_activateItem")
        equip_end = view.index("function GameView:_updateEvidence", equip_start)
        equip = view[equip_start:equip_end]
        self.assertIn(
            'self:_send("EquipItem", { instanceId = instanceId }, control)',
            equip,
        )
        self.assertIn("Motion.PopIn(control, { duration = 0.14 })", equip)


if __name__ == "__main__":
    unittest.main(verbosity=2)
