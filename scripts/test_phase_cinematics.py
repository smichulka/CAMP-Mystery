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
            "CinematicsController.new(\n\t\tgameView.root,",
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

    def test_workflow_has_concurrency_cancellation(self) -> None:
        workflow = read(".github/workflows/validate.yml")
        self.assertIn("concurrency:", workflow)
        self.assertIn("cancel-in-progress: true", workflow)
        self.assertIn("workflow_dispatch:", workflow)

    def test_notebook_theme_and_evidence_card_visual_contract(self) -> None:
        theme = read("src/client/UI/Theme.lua")
        self.assertIn("Notebook = {", theme)
        for token in (
            "PageColor = Color3.fromRGB(245, 238, 210)",
            "PageLines = Color3.fromRGB(180, 190, 200)",
            "InkColor = Color3.fromRGB(28, 32, 40)",
            "StampConfirmed = Color3.fromRGB(40, 120, 60)",
            "StampDenied = Color3.fromRGB(160, 40, 40)",
        ):
            self.assertIn(token, theme)

        components = read("src/client/UI/Components.lua")
        for token in (
            "function Components.EvidenceCard",
            "Theme.Notebook.PageColor",
            'shadow.Name = "DropShadow"',
            'strip.Name = "StatusStrip"',
            'stamp.Rotation = -8',
            "stamp.TextTransparency = 0.55",
            'Components.PlayUISound("stamp")',
            'previousStatus == "Unconfirmed"',
        ):
            self.assertIn(token, components)

    def test_notebook_uses_cards_ruled_paper_and_verification_status(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for token in (
            "notebook.BackgroundColor3 = Theme.Notebook.PageColor",
            "notebook.BackgroundTransparency = 0",
            'rules.Name = "NotebookRules"',
            "index * Theme.Notebook.LineHeight",
            "Components.EvidenceCard(self.evidenceList",
            'verification == "VerifiedReal"',
            'verification == "VerifiedFake"',
            "self.evidenceStatuses[evidenceKey]",
            "self.evidenceStatuses = nextEvidenceStatuses",
            "Motion.StaggerChildren(evidenceList",
        ):
            self.assertIn(token, view)

    def test_typography_hierarchy_and_panel_depth_contract(self) -> None:
        theme = read("src/client/UI/Theme.lua")
        for token in (
            "Typography = {",
            "DisplayFont = Enum.Font.GothamBlack",
            "HeadingFont = Enum.Font.GothamBold",
            "BodyFont = Enum.Font.GothamMedium",
            "CaptionFont = Enum.Font.Gotham",
            "DisplaySize = 32",
            "HeadingSize = 18",
            "SubheadingSize = 15",
            "BodySize = 13",
            "CaptionSize = 11",
            "LetterSpacing = 3",
            "CardHeight = 142",
        ):
            self.assertIn(token, theme)

        components = read("src/client/UI/Components.lua")
        for token in (
            'Instance.new("UIGradient")',
            "NumberSequenceKeypoint.new(0, 0.92)",
            "NumberSequenceKeypoint.new(1, 0.96)",
            'string.match(name, "Title$")',
            'string.match(name, "Header$")',
            "function Components.SetLetterspacedText",
        ):
            self.assertIn(token, components)

        view = read("src/client/UI/GameView.lua")
        for token in (
            "Theme.Typography.DisplayFont",
            "Theme.Typography.DisplaySize",
            "Theme.Typography.HeadingFont",
            "Theme.Typography.HeadingSize",
            "Theme.Typography.BodyFont",
            "Theme.Typography.BodySize",
            "Components.SetLetterspacedText(self.phaseLabel",
        ):
            self.assertIn(token, view)

    def test_vignette_is_optional_and_phase_driven(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for token in (
            'vignette.Name = "Vignette"',
            'imageResolver("ui_vignette")',
            "vignette.ImageTransparency = 1",
            "vignette.ScaleType = Enum.ScaleType.Stretch",
        ):
            self.assertIn(token, view)

        effects = read("src/client/UI/EffectsView.lua")
        for token in (
            "function EffectsView:SetNightIntensity",
            "then 1 + (0.45 - 1) * resolved",
            'phase == "Night"',
            'phase == "Investigation"',
            "self:SetNightIntensity(if nightPhase then 1 else 0)",
            "self.vignetteTween:Cancel()",
        ):
            self.assertIn(token, effects)

    def test_evidence_discovery_is_timed_skippable_reduced_and_cancel_safe(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for token in (
            "function GameView:_cancelEvidenceDiscovery",
            "function GameView:PlayEvidenceDiscovery",
            "Motion.IsReducedMotion(self.root)",
            'self:Notify("Evidence found"',
            'overlay.Name = "EvidenceDiscovery"',
            "overlay.BackgroundTransparency = 0.55",
            "overlay.InputBegan:Connect",
            "Enum.UserInputType.MouseButton1",
            "Enum.UserInputType.Touch",
            "Motion.FadeIn(overlay",
            "task.delay(0.2",
            "Motion.SlideUp(cardHost",
            "Motion.PopIn(evidenceCard",
            "task.delay(1.8",
            "{ TextColor3 = Theme.Colors.Gold }",
            "task.delay(2.3",
            'Components.PlayUISound("stamp")',
            "Scale = 0.1",
            "task.delay(2.7, cleanup)",
        ):
            self.assertIn(token, view)

        controller = read("src/client/Controllers/RoundController.lua")
        audio_update = controller.index("currentAudio:Update(snapshot)")
        ceremony = controller.index("currentView:PlayEvidenceDiscovery", audio_update)
        effects_update = controller.index("currentEffects:Update(snapshot)", ceremony)
        self.assertLess(audio_update, ceremony)
        self.assertLess(ceremony, effects_update)
        for token in (
            "evidenceFound > lastEvidenceFound",
            'evidenceList(snapshot, "culpritEvidence")',
            'evidenceList(snapshot, "monsterEvidence")',
            'return "New evidence found", ""',
        ):
            self.assertIn(token, controller)

    def test_vote_reveal_is_staged_bounded_and_reduced_motion_safe(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for token in (
            "function GameView:PlayVoteReveal",
            "function GameView:_cancelVoteReveal",
            'setModalVisible(self.voteModal, false)',
            'Components.PlayUISound("vote")',
            'entry.Name = "VoteEntry"',
            'then Theme.Colors.Gold',
            'else Theme.Colors.DangerBright',
            "Motion.StaggerChildren(self.voteRevealList",
            "local stagger = math.min(0.6, 8 / math.max(voteCount, 1))",
            '"THE CULPRIT IS FOUND"',
            '"THE MONSTER ESCAPES"',
            'Components.PlayUISound("success")',
            'Components.PlayUISound("error")',
            "for index = 1, 12 do",
            "Size = UDim2.fromOffset(8, 8)",
            "if reducedMotion then",
        ):
            self.assertIn(token, view)

        controller = read("src/client/Controllers/RoundController.lua")
        for token in (
            'if phaseName == "Resolution" and currentView then',
            "playVoteReveal(snapshot, currentView, revealWinner)",
            "type(round.votes) == \"table\"",
            "gameView:PlayVoteReveal(votes, culpritId, monsterId, namesById, onComplete)",
        ):
            self.assertIn(token, controller)

    def test_vote_details_are_resolution_only_in_shared_snapshot(self) -> None:
        game_types = read("src/shared/Types/GameTypes.lua")
        for token in (
            "export type VoteRevealEntry",
            "votes: { VoteRevealEntry }?",
            "culpritId: string?",
            "monsterId: string?",
        ):
            self.assertIn(token, game_types)

        voting = read("src/server/Services/VotingService.lua")
        self.assertIn("if self.resolution then", voting)
        self.assertIn("votes = revealedVotes", voting)
        runtime = read("src/server/Services/GameRuntimeService.lua")
        self.assertIn(
            'local revealVotes = self.phase == "Resolution" or self.phase == "Rewards"',
            runtime,
        )
        self.assertIn("votes = if revealVotes then voteSnapshot.votes else nil", runtime)

    def test_world_proximity_prompts_have_radial_progress_and_lifecycle(self) -> None:
        proximity = read("src/client/Controllers/ProximityController.lua")
        self.assertTrue(proximity.startswith("--!strict"))
        for token in (
            "zones: { [BasePart]: ZoneRecord }",
            'Instance.new("BillboardGui")',
            "gui.Size = UDim2.fromOffset(180, 48)",
            "gui.StudsOffset = Vector3.new(0, 3.5, 0)",
            "Theme.Notebook.PageColor",
            'ring.Name = "RadialProgressRing"',
            "ring.ClipsDescendants = true",
            'segment.Name = string.format("ArcSegment_%02d", index)',
            "function ProximityController:RegisterZone",
            "function ProximityController:UnregisterZone",
            "function ProximityController:SetProgress",
            "function ProximityController:SetVisible",
            "function ProximityController:Destroy",
        ):
            self.assertIn(token, proximity)

        interactions = read("src/client/Controllers/InteractionController.lua")
        for token in (
            "Enum.ProximityPromptStyle.Custom",
            "proximityController:RegisterZone",
            "proximityController:UnregisterZone",
            "proximityController:SetProgress",
            "ProximityPromptService.PromptButtonHoldBegan",
            "ProximityPromptService.PromptButtonHoldEnded",
            "RunService.RenderStepped",
            "(currentTime - hold.startedAt) / hold.duration",
        ):
            self.assertIn(token, interactions)
        self.assertNotIn("ProximityPromptService.Enabled = false", interactions)


if __name__ == "__main__":
    unittest.main(verbosity=2)
