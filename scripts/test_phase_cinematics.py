"""Focused contracts for Claude Request 0002 phase cinematics."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class PhaseCinematicsTests(unittest.TestCase):
    def test_controller_is_strict_cancel_safe_and_restores_authored_baseline(self) -> None:
        controller = read("src/client/Controllers/CinematicsController.lua")
        self.assertTrue(controller.startswith("--!strict"))
        for token in (
            'game:GetService("Lighting")',
            'game:GetService("TweenService")',
            "function CinematicsController:PlayPhaseTransition",
            "function CinematicsController:_cancelActive",
            "tween:Cancel()",
            "token ~= self.transitionToken",
            "function CinematicsController:_restoreBaseline",
            "self:_completeAfter(token, LONG_TRANSITION_DURATION)",
            "self:_completeAfter(token, SHORT_TRANSITION_DURATION)",
        ):
            self.assertIn(token, controller)
        for attribute in (
            "CampMysteryBaselineClockTime",
            "CampMysteryBaselineSaturation",
            "CampMysteryBaselineAtmosphereDensity",
        ):
            self.assertIn(attribute, controller)

    def test_long_short_and_reduced_motion_paths_are_explicit(self) -> None:
        controller = read("src/client/Controllers/CinematicsController.lua")
        for token in (
            'string.find(normalized, "night", 1, true)',
            'string.find(normalized, "investigation", 1, true)',
            'normalized == "day"',
            'normalized == "campfire" or normalized == "resolution"',
            "NIGHT_CLOCK_TIME = 21",
            "DAY_CLOCK_TIME = 8",
            "NIGHT_ATMOSPHERE_DENSITY = 0.45",
            "DESATURATED = -0.7",
            "PARTIAL_RECOVERY = -0.35",
            "Motion.IsReducedMotion(self.motionTarget)",
        ):
            self.assertIn(token, controller)

    def test_round_controller_owns_cinematic_lifecycle_and_phase_dispatch(self) -> None:
        round_controller = read("src/client/Controllers/RoundController.lua")
        for token in (
            'require(script.Parent:WaitForChild("CinematicsController"))',
            "CinematicsController.new(gameView.root)",
            "currentEffects:Update(snapshot)",
            "currentCinematics:PlayPhaseTransition(phaseName)",
            "cinematics:Destroy()",
            "lastCinematicPhase = nil",
        ):
            self.assertIn(token, round_controller)

    def test_request_0001_review_corrections_remain_present(self) -> None:
        motion = read("src/client/UI/Motion.lua")
        self.assertIn("table.clear(record.tweens)", motion)
        self.assertIn("table.insert(record.tweens, tween)", motion)
        cleanup = motion.index("local record = begin(container")
        self.assertIn("Motion.Cancel(child)", motion[cleanup:])

        sound_map = read("src/client/Controllers/UISoundMap.lua")
        self.assertIn(
            "VoteOpen and PhaseChime are already registered by AudioController",
            sound_map,
        )
        self.assertIn("not\n-- duplicated in DEFINITIONS here.", sound_map)


if __name__ == "__main__":
    unittest.main(verbosity=2)
