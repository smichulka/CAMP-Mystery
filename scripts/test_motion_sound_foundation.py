"""Focused contracts for Claude Request 0001 motion and UI sound wiring."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class MotionSoundFoundationTests(unittest.TestCase):
    def test_motion_presets_are_strict_cancel_safe_and_theme_driven(self) -> None:
        motion = read("src/client/UI/Motion.lua")
        self.assertTrue(motion.startswith("--!strict"))
        for function_name in (
            "PopIn",
            "PopOut",
            "SlideUp",
            "SlideDown",
            "FadeIn",
            "FadeOut",
            "Shake",
            "StaggerChildren",
        ):
            self.assertIn(f"function Motion.{function_name}", motion)
        for token in (
            "activeTransitions",
            "cancelRecord(active)",
            "record.completion.Event",
            "Theme.Motion.PopDuration",
            "Theme.Motion.SlideDuration",
            "Theme.Motion.FadeDuration",
            "Theme.Motion.StaggerDelay",
        ):
            self.assertIn(token, motion)

        theme = read("src/client/UI/Theme.lua")
        self.assertIn("Motion = {", theme)
        self.assertIn("PopEasingStyle = Enum.EasingStyle.Back", theme)
        self.assertIn("ExitEasingStyle = Enum.EasingStyle.Quint", theme)

    def test_reduced_motion_removes_scale_slide_and_shake_paths(self) -> None:
        motion = read("src/client/UI/Motion.lua")
        self.assertIn("function Motion.SetReducedMotionProvider", motion)
        self.assertIn('current:GetAttribute("ReducedMotion") == true', motion)
        self.assertIn(
            "return if appearing then Motion.FadeIn(target, resolved) "
            "else Motion.FadeOut(target, resolved)",
            motion,
        )
        self.assertIn("if not reduced then", motion)
        self.assertIn(
            "if Motion.IsReducedMotion(target, resolved.reducedMotion) then",
            motion,
        )

        components = read("src/client/UI/Components.lua")
        self.assertIn("if Motion.IsReducedMotion(button) then", components)
        self.assertIn("pressScale.Scale = 1", components)

    def test_all_six_modals_toasts_and_lists_use_motion(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for modal_name in (
            "EvidenceNotebook",
            "Settings",
            "CampfireVote",
            "RoundResults",
            "ActionTarget",
            "Progression",
        ):
            self.assertIn(f'makeModal(root, "{modal_name}"', view)
        for token in (
            "Motion.PopIn(modal",
            "Motion.PopOut(modal",
            'modal.Name == "EvidenceNotebook"',
            'modal.Name == "CampfireVote"',
            "Motion.StaggerChildren(list",
            "Motion.SlideUp(toast)",
            "Motion.FadeOut(toast",
            "Motion.Shake(button)",
        ):
            self.assertIn(token, view)

    def test_ui_sound_events_route_through_audio_controller(self) -> None:
        sound_map = read("src/client/Controllers/UISoundMap.lua")
        for event_name in (
            "hover",
            "click",
            "open",
            "close",
            "toast",
            "error",
            "success",
            "page-turn",
            "stamp",
            "vote",
            "phase-sting",
        ):
            self.assertIn(event_name, sound_map)

        components = read("src/client/UI/Components.lua")
        for event_name in ("hover", "click"):
            self.assertIn(f'Components.PlayUISound("{event_name}")', components)

        view = read("src/client/UI/GameView.lua")
        for event_name in ("open", "close", "error", "success", "toast"):
            self.assertIn(f'Components.PlayUISound("{event_name}")', view)

        audio = read("src/client/Controllers/AudioController.lua")
        self.assertIn("function AudioController:PlayUIEvent", audio)
        self.assertIn("UISoundMap.Resolve(eventName)", audio)

        round_controller = read("src/client/Controllers/RoundController.lua")
        self.assertIn("Components.SetSoundPlayer", round_controller)
        self.assertIn("Motion.SetReducedMotionProvider", round_controller)


if __name__ == "__main__":
    unittest.main(verbosity=2)
