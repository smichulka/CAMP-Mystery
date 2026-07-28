"""Static client release contracts that do not require Roblox Studio.

These checks protect the cross-device and lifecycle guarantees that are easy to
regress during UI work. They do not emulate Roblox rendering or input dispatch;
the physical-device checks in docs/RELEASE_CHECKLIST.md remain mandatory.
"""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLIENT = ROOT / "src" / "client"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


class ClientReleaseContractTests(unittest.TestCase):
    def test_all_client_modules_remain_strict(self) -> None:
        modules = sorted(CLIENT.rglob("*.lua"))
        self.assertGreaterEqual(len(modules), 10)
        for module in modules:
            with self.subTest(module=module.relative_to(ROOT)):
                self.assertTrue(
                    module.read_text(encoding="utf-8").startswith("--!strict"),
                    f"{module.relative_to(ROOT)} must start with --!strict",
                )

    def test_ui_uses_safe_insets_and_explicit_responsive_layouts(self) -> None:
        source = read("src/client/UI/GameView.lua")
        self.assertIn("Enum.ScreenInsets.DeviceSafeInsets", source)
        self.assertIn("local narrow = viewport.X < 560", source)
        self.assertIn("local compact =", source)
        self.assertIn("self.uiScale.Scale = 1", source)
        self.assertIn("Workspace:GetPropertyChangedSignal(\"CurrentCamera\")", source)
        self.assertIn('currentCamera:GetPropertyChangedSignal("ViewportSize")', source)
        self.assertIn("function GameView:Destroy()", source)
        self.assertIn("connection:Disconnect()", source)

        tutorial = read("src/client/UI/TutorialView.lua")
        self.assertIn("panel.Size = UDim2.new(0.82, 0, 0.88, 0)", tutorial)
        self.assertIn("sizeConstraint.MinSize = Vector2.new(280, 280)", tutorial)
        self.assertIn('position = UDim2.new(0, 24, 1, -62)', tutorial)

    def test_hud_self_heals_and_boot_failures_are_visible(self) -> None:
        view = read("src/client/UI/GameView.lua")
        self.assertIn('playerGui:FindFirstChild("GameUI")', view)
        self.assertIn('screen = Instance.new("ScreenGui")', view)
        self.assertIn("screen.Enabled = true", view)
        self.assertIn(
            "screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling",
            view,
            "Modal content must render above its panel even when Studio reuses GameUI",
        )
        self.assertNotIn('playerGui:WaitForChild("GameUI")', view)

        bootstrap = read("src/client/Bootstrap.client.lua")
        self.assertIn("xpcall(function()", bootstrap)
        self.assertIn("showBootFailure", bootstrap)
        self.assertIn("CampMysteryBootFailure", bootstrap)
        self.assertIn("Production client failed", bootstrap)
        self.assertIn('WaitForChild("Controllers", 10)', bootstrap)

    def test_settings_surface_matches_persisted_profile_contract(self) -> None:
        source = read("src/client/UI/GameView.lua")
        required = {
            "masterVolume",
            "musicVolume",
            "ambienceVolume",
            "effectsVolume",
            "uiVolume",
            "subtitles",
            "reducedMotion",
            "cameraShake",
            "highContrastEvidence",
            "mouseSensitivity",
            "controllerSensitivity",
            "sprintToggle",
        }
        surfaced = set(
            re.findall(r'self:_settingRow\("[^"]+",\s*"([A-Za-z0-9]+)"', source)
        )
        self.assertTrue(required.issubset(surfaced), sorted(required - surfaced))

        controller = read("src/client/Controllers/RoundController.lua")
        self.assertIn("UserInputService.MouseDeltaSensitivity", controller)
        self.assertIn("GamepadCameraSensitivity", controller)

    def test_keyboard_touch_and_gamepad_paths_are_not_pointer_only(self) -> None:
        inputs = read("src/client/Controllers/InputController.lua")
        for token in (
            "Enum.KeyCode.N",
            "Enum.KeyCode.ButtonY",
            "Enum.KeyCode.ButtonStart",
            "Enum.KeyCode.ButtonB",
            "Enum.KeyCode.ButtonL1",
            "Enum.KeyCode.ButtonR1",
            "Enum.KeyCode.DPadLeft",
            "Enum.KeyCode.DPadRight",
            "Enum.KeyCode.ButtonX",
            "Enum.KeyCode.Zero",
            "callbacks.selectSlot(selectedSlot)",
            "math.clamp(callbacks.getSlotCount(), 0, 15)",
        ):
            self.assertIn(token, inputs)

        interactions = read("src/client/Controllers/InteractionController.lua")
        self.assertIn("Enum.ProximityPromptInputType.Touch", interactions)
        self.assertIn("Enum.ProximityPromptInputType.Gamepad", interactions)
        self.assertIn("prompt.GamepadKeyCode", interactions)
        self.assertIn("prompt.KeyboardKeyCode", interactions)

    def test_controller_focus_and_modal_focus_are_managed(self) -> None:
        components = read("src/client/UI/Components.lua")
        self.assertIn("button.SelectionGained:Connect", components)
        self.assertIn("button.SelectionLost:Connect", components)

        view = read("src/client/UI/GameView.lua")
        self.assertIn("local function findFocusable", view)
        self.assertIn("descendant.Name ~= \"Close\"", view)
        self.assertIn("selected:IsDescendantOf(modal)", view)
        self.assertIn("selected:IsDescendantOf(self.hotbar)", view)
        self.assertIn("function GameView:SelectInventorySlot", view)

    def test_targeted_actions_fail_closed_and_directional_lights_are_direct(self) -> None:
        source = read("src/client/UI/GameView.lua")
        self.assertNotIn("The server will use the action's safe default.", source)
        self.assertIn(
            "This action requires at least one other living player and was not sent.",
            source,
        )
        item_branch = re.search(
            r'if equipmentId == "MedicalKit" then(?P<body>.*?)\n\telse\n'
            r'\t\tself:_send\("UseItem", payload(?:, control)?\)',
            source,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(item_branch)
        self.assertNotIn("UVLight", item_branch.group("body"))
        self.assertNotIn("Flashlight", item_branch.group("body"))

    def test_async_remote_results_cannot_outlive_the_client(self) -> None:
        bridge = read("src/client/Controllers/RemoteBridge.lua")
        for token in (
            "destroyed: boolean",
            "requestGeneration: number",
            "if self.destroyed then",
            "generation ~= self.requestGeneration",
            "pcall(handler, payload)",
            "table.clear(self.snapshotHandlers)",
            "table.clear(self.resultHandlers)",
        ):
            self.assertIn(token, bridge)

        round_controller = read("src/client/Controllers/RoundController.lua")
        self.assertIn("view:Destroy()", round_controller)

    def test_malformed_numeric_state_has_finite_guards(self) -> None:
        view = read("src/client/UI/GameView.lua")
        audio = read("src/client/Controllers/AudioController.lua")
        effects = read("src/client/UI/EffectsView.lua")
        self.assertIn("numberValue == numberValue", view)
        self.assertIn("math.abs(numberValue) < math.huge", view)
        self.assertIn("value ~= value", audio)
        self.assertIn("payload.duration == payload.duration", effects)

    def test_loaded_tutorial_completion_does_not_write_back(self) -> None:
        tutorial = read("src/client/Controllers/TutorialController.lua")
        method = re.search(
            r"function TutorialController:SetCompleted\(completed: boolean\)"
            r"(?P<body>.*?)\nend",
            tutorial,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(method)
        self.assertNotIn("self:_finish", method.group("body"))
        self.assertIn("self.completed = true", method.group("body"))

    def test_optional_ui_images_have_safe_text_fallback_and_lifecycle(self) -> None:
        project = json.loads(read("default.project.json"))
        replicated = project["tree"]["ReplicatedStorage"]
        self.assertEqual(
            replicated["Assets"]["Images"]["UI"]["$className"],
            "Folder",
        )

        resolver = read("src/client/Controllers/UIAssetController.lua")
        for token in (
            'ReplicatedStorage:FindFirstChild("Assets")',
            'assets:FindFirstChild("Images")',
            'images:FindFirstChild("UI")',
            '"^rbxassetid://(%d+)$"',
            'string.match(key, "^[%w_%-]+$")',
            'asset:GetAttribute("AssetId")',
            "function UIAssetController:Destroy()",
        ):
            self.assertIn(token, resolver)
        self.assertNotRegex(resolver, r"rbxassetid://[1-9][0-9]+")

        view = read("src/client/UI/GameView.lua")
        for token in (
            'imageKey("Role", role)',
            'imageKey("Equipment", equipmentId)',
            '"Evidence_Culprit"',
            '"Evidence_Monster"',
            '"Evidence_Mystery"',
            '"Evidence_Witness"',
            "roleIcon.Visible = roleImage ~= nil",
            "imageResolver or function",
            "Equipment will appear here.",
            "Unknown clue",
        ):
            self.assertIn(token, view)

        controller = read("src/client/Controllers/RoundController.lua")
        self.assertIn("UIAssetControllerModule.new()", controller)
        self.assertIn("assetController:Resolve(key)", controller)
        self.assertIn("uiAssets:Destroy()", controller)

    def test_tutorial_all_seen_skips_unreachable_steps_per_role(self) -> None:
        # Murderers never receive the "Evidence" context (currentContext returns
        # "InvestigationMurderer" for them during Investigation), so _allSeen must
        # skip that step for murderers or they can never complete the tutorial.
        # Spectators never receive "Role"/"Day"/etc. contexts after Lobby, so all
        # non-lobby, non-spectator steps must be skipped for them.
        tutorial = read("src/client/Controllers/TutorialController.lua")

        all_seen = re.search(
            r"function TutorialController:_allSeen\(\)(?P<body>.*?)\nend",
            tutorial,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(all_seen, "_allSeen function not found")
        body = all_seen.group("body")  # type: ignore[union-attr]

        # Evidence skip for murderers
        self.assertIn("StepIds.Evidence", body)
        self.assertIn('role == "Murderer"', body)

        # Spectator skip for non-lobby, non-spectator steps
        self.assertIn('role == "Spectator"', body)
        self.assertIn("StepIds.Lobby", body)
        self.assertIn("StepIds.Spectator", body)


if __name__ == "__main__":
    unittest.main(verbosity=2)
