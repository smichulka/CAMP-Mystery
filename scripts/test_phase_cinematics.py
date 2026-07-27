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

    def test_request_0053_murderer_announcements_and_evidence_are_role_aware(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        for token in (
            '["Something Is Being Planned"]',
            'title = "YOUR PLAN"',
            'message = "Choose your target. You have until dawn."',
            '["The Town Is Appearing"]',
            'title = "YOUR HUNT BEGINS"',
            'message = "You are the threat. Move unseen."',
            '["Night Investigation"]',
            'title = "THEY ARE SEARCHING"',
            'message = "Stay calm. Blend in. Cast doubt."',
            'readString(currentPlayer, "role", "") == "Murderer"',
            "announcementPayload = table.clone(payload)",
            "gameView:Announce(announcementPayload :: Announcement)",
            'currentView:Notify(\n\t\t\t\t"Evidence Found",',
            '"A clue has been posted against you. Stay composed."',
            '"Warning"',
        ):
            self.assertIn(token, controller)

        # Observer (Ghost/Spectator) gets quiet "Evidence Posted" Info toast
        for token in (
            "elseif isGhost or roleName == \"Spectator\" then",
            '"Evidence Posted"',
            '"A clue has been added to the board."',
            '"Info"',
        ):
            self.assertIn(token, controller)
        evidence_branch = controller.index(
            'if roleName == "Murderer" then',
            controller.index("if evidenceFound > lastEvidenceFound and currentView then"),
        )
        evidence_end = controller.index("lastEvidenceFound = evidenceFound", evidence_branch)
        murderer_branch = controller[evidence_branch:evidence_end]
        murderer_path, non_murderer_path = murderer_branch.split("\n\t\telse\n", 1)
        self.assertNotIn("FlashEvidenceFound", murderer_path)
        self.assertNotIn("PlayEvidenceDiscovery", murderer_path)
        self.assertIn("FlashEvidenceFound", non_murderer_path)
        self.assertIn("PlayEvidenceDiscovery", non_murderer_path)

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
            "playVoteReveal(snapshot, currentView, revealWinner, roleName)",
            "type(round.votes) == \"table\"",
            "gameView:PlayVoteReveal(votes, culpritId, monsterId, namesById, onComplete, roleName)",
        ):
            self.assertIn(token, controller)

    def test_request_0050_role_aware_vote_and_death_copy(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for token in (
            "localRole: string?",
            'if localRole == "Murderer"',
            '"COUNTING THE VOTES"',
            '"EXPOSED"',
            '"The camp unmasked you. The hunt is over."',
            '"YOU SURVIVED THE VOTE"',
            '"The camp guessed wrong. You remain hidden."',
            '"THE CULPRIT IS FOUND"',
            '"THE MONSTER ESCAPES"',
            "function GameView:PlayDeathCinematic(deathCause: string?, localRole: string?)",
            'local cause = deathCause or "killed"',
            'local dRole = localRole or ""',
            'if dRole == "Murderer" then',
            'headingText = "CAUGHT"',
            'subText = "The camp saw through you. Your hunt is over."',
            'elseif cause == "voted" then',
            'headingText = "VOTED OUT"',
            'subText = "The camp made their choice. Watch over the living."',
            'local headingText = "YOU HAVE FALLEN"',
            'local subText = "Your spirit remains — watch over the living."',
        ):
            self.assertIn(token, view)

        controller = read("src/client/Controllers/RoundController.lua")
        for token in (
            "roleName: string",
            'gameView:PlayVoteReveal({}, "", "", {}, onComplete, roleName)',
            "gameView:PlayVoteReveal(votes, culpritId, monsterId, namesById, onComplete, roleName)",
            'local deathCause = if phaseName == "Campfire" or phaseName == "Resolution"',
            'then "voted"',
            'else "killed"',
            "currentView:PlayDeathCinematic(deathCause, roleName)",
        ):
            self.assertIn(token, controller)

    def test_request_0051_round_summary_and_rewards_ghost_copy(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for token in (
            "killCount: number?",
            "votesAgainstMe: number?",
            "wasCaught: boolean?",
            'local rewardsIsGhost = readBoolean(player, "isGhost", false)',
            "elseif rewardsIsGhost then",
            '"JUSTICE\\nThe murderer was caught. Your death was not in vain."',
            '"UNSOLVED\\nThe murderer escaped. The mystery remains."',
            'if stats.playerRole == "Murderer" then',
            '"Outcome"',
            'if wasCaught then "CAUGHT" else "ESCAPED"',
            '"Eliminations"',
            '"Votes Against You"',
            '"Survivors Remaining"',
            'string.format("%d", stats.killCount or 0)',
            'string.format("%d", stats.votesAgainstMe or 0)',
            'if stats.playerRole ~= "Murderer"',
        ):
            self.assertIn(token, view)

        rewards = view.index('elseif phase == "Rewards" then')
        murderer = view.index('if rewardsRole == "Murderer" then', rewards)
        ghost = view.index("elseif rewardsIsGhost then", murderer)
        camper = view.index('elseif rewardsRole ~= "Spectator" then', ghost)
        self.assertLess(murderer, ghost)
        self.assertLess(ghost, camper)

        controller = read("src/client/Controllers/RoundController.lua")
        for token in (
            'local roleName = readString(player, "role", "Camper")',
            "killCount = 0",
            "votesAgainstMe = 0",
            'wasCaught = roleName == "Murderer" and winner == "Campers"',
        ):
            self.assertIn(token, controller)

    def test_request_0052_vote_self_marker_and_campfire_timer_urgency(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for token in (
            'local localParticipantKey = readString(player, "participantId", "")',
            'local isSelf = localParticipantKey ~= "" and key == localParticipantKey',
            'local labelText = if isSelf then name .. " (you)" else name',
            'text = if isMyVote then labelText .. "  ✓ YOUR VOTE" else labelText',
            'local isMurdererCampfire = phase == "Campfire" and localRole == "Murderer"',
            "local dangerThreshold = if isMurdererCampfire then 20 else 10",
            "local amberThreshold = if isMurdererCampfire then 60 else 30",
            "elseif isMurdererCampfire and seconds <= amberThreshold then",
            "self.timerLabel.TextColor3 = Theme.Colors.Amber",
            "elseif seconds <= 10 and seconds > 0 then",
            "if seconds > 0 then",
            "self:_startTimerPulse()",
        ):
            self.assertIn(token, view)

        self.assertEqual(
            view.count(
                'local isMurdererCampfire = phase == "Campfire" '
                'and localRole == "Murderer"'
            ),
            2,
            "Both snapshot and interpolated timer paths must use Murderer urgency",
        )
        self.assertIn(
            "if seconds <= dangerThreshold then\n"
            "\t\t\tself.timerFill.BackgroundColor3 = Theme.Colors.DangerBright",
            view,
        )
        self.assertIn(
            "elseif seconds <= amberThreshold then\n"
            "\t\t\tself.timerFill.BackgroundColor3 = Theme.Colors.Amber",
            view,
        )

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


    def test_request_0084_objective_panel_role_aware_copy(self) -> None:
        view = read("src/client/UI/GameView.lua")
        # Day phase: four-role objective labels
        for token in (
            '"DAY COVER\\nCamp work: %d of %d. Witnesses: %d of %d. Act natural."',
            '"DAY OBJECTIVE\\nCamp work: %d of %d\\nInterview witnesses: %d of %d"',
            "blend in.",
            '"All camp work done and witnesses interviewed. Investigation begins soon."',
            "Campers are ready. Investigation begins soon",
        ):
            self.assertIn(token, view)
        # Investigation phase: four-role objective labels
        for token in (
            '"HUNT OBJECTIVE\\nEliminate %s. Avoid discovery. Use your ability when the time is right."',
            '"NIGHT OBJECTIVE\\nCollect and post clues: %d of %d"',
            '"OBSERVING\\nYou joined mid-round. Watch the investigation unfold."',
            '"OBSERVING\\nYou are a ghost. Watch as the survivors investigate."',
            '"All clues collected. Return for the Campfire."',
            "All evidence is on the board. Stay composed",
        ):
            self.assertIn(token, view)
        # MurderPlanning phase: four-role objective labels
        for token in (
            '"MURDERER OBJECTIVE\\nEliminate %s. Frame the evidence."',
            '"PREPARATION\\nSomething is coming. Secure your equipment and stay alert."',
            '"OBSERVING\\nYou are a ghost. Watch the night unfold."',
            '"OBSERVING\\nThe night phase is beginning. Watch what unfolds."',
        ):
            self.assertIn(token, view)
        # NightTransform phase: four-role objective labels
        for token in (
            "The town is yours. Hunt %s",
            '"NIGHT BEGINS\\nThe abandoned town has merged with the camp. The monster is somewhere inside."',
            '"OBSERVING\\nYou are a ghost. Watch the hunt from beyond."',
            '"OBSERVING\\nThe night phase has begun. Watch what unfolds."',
        ):
            self.assertIn(token, view)
        # Campfire phase progress labels distinguish Spectator / Ghost / Murderer / Camper
        for token in (
            '"Votes locked %d/%d - observing."',
            '"Votes locked %d/%d - watching."',
            '"Votes locked %d/%d - stay calm."',
            '"Votes locked %d/%d - accuse carefully."',
        ):
            self.assertIn(token, view)

    def test_request_0073_resolution_and_rewards_role_copy(self) -> None:
        view = read("src/client/UI/GameView.lua")
        # Resolution phase — four-role objective text
        for token in (
            'local resRole = if type(player) == "table" and type(player.role) == "string"',
            'if resRole == "Spectator" then',
            '"ROUND OVER\\nThe mystery has been resolved."',
            "elseif isGhostRes then",
            '"JUSTICE\\nThe camp caught the killer. Your death was not in vain."',
            '"UNSOLVED\\nThe murderer escaped. Your death remains unavenged."',
            'elseif resRole == "Murderer" then',
            '"UNMASKED\\nThe camp named you. The hunt is over."',
            '"UNSEEN\\nYour name was never called. You walk free."',
            '"NAMED\\nThe murderer has been revealed. The camp is safe."',
            '"UNSOLVED\\nNo verdict reached. The killer walks free."',
        ):
            self.assertIn(token, view)
        # Rewards phase — four-role objective text
        for token in (
            'local rewardsRole = readString(player, "role", "Spectator")',
            'local rewardsIsGhost = readBoolean(player, "isGhost", false)',
            'if rewardsRole == "Murderer" then',
            '"CAUGHT\\nThe campers solved the mystery. Better luck next time."',
            '"ESCAPED\\nThe camp never caught you. A flawless hunt."',
            "elseif rewardsIsGhost then",
            '"JUSTICE\\nThe murderer was caught. Your death was not in vain."',
            '"UNSOLVED\\nThe murderer escaped. The mystery remains."',
            'elseif rewardsRole ~= "Spectator" then',
            '"VICTORY\\nYou helped catch the monster. The camp is safe."',
            '"DEFEAT\\nThe mystery went unsolved. The monster walks free."',
            '"ROUND OVER\\nThe mystery has been resolved."',
        ):
            self.assertIn(token, view)
        # Branch ordering: Spectator → Ghost → Murderer → Camper in Resolution
        resolution_start = view.index('local resRole = if type(player)')
        resolution_end = view.index('elseif phase == "Lobby"', resolution_start)
        res_block = view[resolution_start:resolution_end]
        spectator_branch = res_block.index('if resRole == "Spectator" then')
        ghost_branch = res_block.index("elseif isGhostRes then")
        murderer_branch = res_block.index('elseif resRole == "Murderer" then')
        self.assertLess(spectator_branch, ghost_branch)
        self.assertLess(ghost_branch, murderer_branch)


    def test_request_0083_audio_controller_role_aware_subtitles(self) -> None:
        audio = read("src/client/Controllers/AudioController.lua")
        # VoteOpen: Murderer gets a subtitle; others get nil
        self.assertIn('"They\'re voting. Choose your words carefully."', audio)
        # PhaseChime: one Murderer subtitle per phase
        for token in (
            '"Daytime. Stay composed."',
            '"Investigation begun. Maintain your cover."',
            '"Night phase. Choose your moment."',
            '"You chose your prey. Prepare before dawn."',
            '"You are the monster. The hunt begins."',
        ):
            self.assertIn(token, audio)
        # EvidenceFound: Murderer subtitle; others get nil
        self.assertIn('"Evidence found against you."', audio)
        # Subtitles are nil when not Murderer (all three sites use else nil)
        cue_block_start = audio.index('if phase == "Campfire" then')
        cue_block_end = audio.index("self.lastEvidenceFound = evidenceFound", cue_block_start)
        cue_block = audio[cue_block_start:cue_block_end]
        # 4 = voteSubtitle(1) + phaseSubtitle nested ternary(2) + evidenceSubtitle(1)
        self.assertEqual(cue_block.count("else nil"), 4)


if __name__ == "__main__":
    unittest.main(verbosity=2)
