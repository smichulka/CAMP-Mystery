"""Focused contracts for Claude Request 0006 ghost mode and monster dread."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class GhostDreadTests(unittest.TestCase):
    def test_shared_contract_uses_is_ghost_and_monster_snapshot_has_no_position(self) -> None:
        participants = read("src/shared/Types/ParticipantTypes.lua")
        monsters = read("src/shared/Types/MonsterTypes.lua")
        self.assertIn("isGhost: boolean", participants)
        public_snapshot = monsters.split("export type MonsterPublicSnapshot", 1)[1]
        public_snapshot = public_snapshot.split("export type MonsterPrivateSnapshot", 1)[0]
        self.assertIn("participantId: MonsterParticipantId?", public_snapshot)
        self.assertNotIn("position:", public_snapshot.lower())

    def test_ghost_tint_badge_and_living_action_lock(self) -> None:
        effects = read("src/client/UI/EffectsView.lua")
        for token in (
            "function EffectsView:SetGhostTint(active: boolean)",
            "Theme.Colors.Ghost",
            "then 0.6",
            "ImageColor3",
            "self.vignetteTween:Cancel()",
        ):
            self.assertIn(token, effects)

        view = read("src/client/UI/GameView.lua")
        for token in (
            'root,\n\t\t"GhostModeBadge",\n\t\t"GHOST MODE"',
            "Theme.Typography.CaptionFont",
            "Theme.Typography.CaptionSize",
            "function GameView:SetGhostMode(active: boolean)",
            "Motion.IsReducedMotion(self.root)",
            "TextTransparency = 0.4",
            "not ghost and (roleEnabled or monsterEnabled or planEnabled)",
            "Components.SetButtonEnabled(button, not self.ghostMode)",
            "if self.ghostMode or type(item) ~= \"table\" then",
            "if self.ghostMode then\n\t\tself:HideInteraction()",
        ):
            self.assertIn(token, view)

    def test_camera_is_strict_free_fly_flicker_and_haptic_safe(self) -> None:
        camera = read("src/client/Controllers/CameraController.lua")
        self.assertTrue(camera.startswith("--!strict"))
        for token in (
            "WALK_SPEED = 24",
            "SPRINT_SPEED = 48",
            "MAXIMUM_ALTITUDE = 200",
            "Enum.KeyCode.W",
            "Enum.KeyCode.Q",
            "Enum.KeyCode.E",
            "Enum.KeyCode.ButtonL2",
            "Enum.KeyCode.ButtonR2",
            "Enum.KeyCode.ButtonL3",
            "Enum.KeyCode.ButtonY",
            "camera.CameraType = Enum.CameraType.Scriptable",
            "camera.CameraType = Enum.CameraType.Custom",
            "function CameraController:_flickerNearestLight()",
            "FLICKER_COOLDOWN = 60",
            "FLICKER_RANGE = 20",
            "HapticService:SetMotor(",
            "resolved * 0.4",
            "RUMBLE_COOLDOWN = 0.5",
            "task.delay(0.1",
            "UserInputService:GetConnectedGamepads()",
        ):
            self.assertIn(token, camera)
        self.assertNotIn("GamepadRumble", camera)

    def test_dread_uses_replicated_monster_model_and_exact_distance_curve(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        for token in (
            'require(script.Parent:WaitForChild("CameraController"))',
            'descendant:GetAttribute("ParticipantId") == participantId',
            'type(descendant:GetAttribute("MonsterId")) == "string"',
            'phase ~= "Investigation" and phase ~= "NightTransform"',
            "if distance <= 8 then",
            "if distance ~= distance or math.abs(distance) == math.huge or distance > 40 then",
            "return 1 - ((distance - 8) / 32)",
            "currentCinematics:SetMonsterDread(dreadFraction)",
            "currentAudio:SetHeartbeatIntensity(dreadFraction)",
            "currentCamera:SetMonsterDread(dreadFraction)",
            "currentCamera:SetGhostMode(isGhost and not roundEnded)",
            "InteractionController.SetPromptsEnabled(not isGhost)",
        ):
            self.assertIn(token, controller)

    def test_cinematics_dread_is_smooth_pulsed_and_transition_safe(self) -> None:
        controller = read("src/client/Controllers/CinematicsController.lua")
        for token in (
            "function CinematicsController:SetMonsterDread(fraction: number)",
            "self.phaseBaselineSaturation - (0.5 * resolved)",
            "DREAD_TWEEN_DURATION = 0.35",
            "0.35 + 0.25 * self.dreadFraction",
            "function CinematicsController:_scheduleDreadPulse",
            "Motion.IsReducedMotion(self.motionTarget)",
            "if self.destroyed or self.transitionActive then",
            "self:_resetDread()",
            "self.transitionActive = false",
        ):
            self.assertIn(token, controller)

    def test_heartbeat_is_looped_thresholded_and_settings_driven(self) -> None:
        audio = read("src/client/Controllers/AudioController.lua")
        for token in (
            'name = "MonsterActive"',
            "looped = true",
            "function AudioController:SetHeartbeatIntensity(fraction: number)",
            "heartbeat.Volume = resolved * effectsVolume",
            "if resolved > 0.3 and self:_configured(heartbeat) then",
            "heartbeat:Stop()",
        ):
            self.assertIn(token, audio)

    def test_prompt_visibility_and_activation_events_remain_separate(self) -> None:
        interaction = read("src/client/Controllers/InteractionController.lua")
        for token in (
            "ProximityPromptService.PromptShown",
            "ProximityPromptService.PromptHidden",
            "ProximityPromptService.PromptTriggered",
            "function InteractionController.SetPromptsEnabled(enabled: boolean)",
            "descendant.Enabled = false",
        ):
            self.assertIn(token, interaction)
        shown = interaction.index("ProximityPromptService.PromptShown")
        hidden = interaction.index("ProximityPromptService.PromptHidden")
        triggered = interaction.index("ProximityPromptService.PromptTriggered")
        self.assertLess(shown, hidden)
        self.assertLess(hidden, triggered)


if __name__ == "__main__":
    unittest.main(verbosity=2)
