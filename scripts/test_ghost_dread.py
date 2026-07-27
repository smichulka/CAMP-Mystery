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
            "InteractionController.SetPromptsEnabled(not isGhost and roleName ~= \"Spectator\")",
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


    def test_request_0080_health_panel_role_aware_copy(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for token in (
            '"SPIRIT STATE  -  LIVING ACTIONS LOCKED"',
            '"SPECTATING  -  OBSERVING THIS ROUND"',
            '"WAITING FOR NEXT ROUND"',
        ):
            self.assertIn(token, view)
        # Branch ordering: Ghost → Spectator → dead → alive
        self.assertLess(
            view.index('"SPIRIT STATE  -  LIVING ACTIONS LOCKED"'),
            view.index('"SPECTATING  -  OBSERVING THIS ROUND"'),
        )
        self.assertLess(
            view.index('"SPECTATING  -  OBSERVING THIS ROUND"'),
            view.index('"WAITING FOR NEXT ROUND"'),
        )

    def test_request_0081_witness_and_objectives_spectator_guard(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        witness_start = controller.index("revealedWitnessCount > lastRevealedWitnessCount")
        objectives_start = controller.index("objectivesCompleted > lastObjectivesCompleted")
        witness_block = controller[witness_start:objectives_start]
        objectives_block = controller[objectives_start:objectives_start + 600]
        for block in (witness_block, objectives_block):
            self.assertIn("and not isGhost", block)
            self.assertIn('and roleName ~= "Spectator"', block)
            self.assertLess(
                block.index("and not isGhost"),
                block.index('and roleName ~= "Spectator"'),
            )

    def test_request_0063_nametagsview_role_and_victim_dot(self) -> None:
        nametags = read("src/client/UI/NametagsView.lua")
        controller = read("src/client/Controllers/RoundController.lua")
        # Extended Update signature
        for token in (
            "function NametagsView:Update(",
            "localRole: string?,",
            "victimParticipantId: string?",
        ):
            self.assertIn(token, nametags)
        # Murderer victim dot override uses Amber
        for token in (
            'if localRole == "Murderer"',
            "and alive",
            "and victimParticipantId ~= nil",
            "and participantId == victimParticipantId",
            "Theme.Colors.Amber",
        ):
            self.assertIn(token, nametags)
        # RoundController passes localRole and victimId
        for token in (
            "local localRole = readString(player, \"role\", \"\")",
            "local victimId = if type(snapshot) == \"table\"",
            "currentNametags:Update(participants, localParticipantId, phaseName, localRole, victimId)",
        ):
            self.assertIn(token, controller)


    def test_request_0091_effects_view_status_copy_and_ghost_detection(self) -> None:
        effects = read("src/client/UI/EffectsView.lua")
        # STATUS_COPY table has Ghost entry mapping to "SPIRIT STATE"
        for token in (
            'Ghost = { label = "SPIRIT STATE", color = Theme.Colors.Ghost }',
            'MonsterActive = { label = "THE MONSTER IS ACTIVE", color = Theme.Colors.DangerBright }',
            'Incapacitated = { label = "INCAPACITATED", color = Theme.Colors.DangerBright }',
            'Injured = { label = "INJURED", color = Theme.Colors.Danger }',
        ):
            self.assertIn(token, effects)
        # PULSE_STATUSES marks the high-urgency statuses
        for token in ("Injured = true", "Incapacitated = true", "Bleeding = true", "Latched = true"):
            self.assertIn(token, effects)
        # readStatus checks combat.isGhost before healthState, then player.isGhost
        read_start = effects.index("local function readStatus(state: any)")
        read_end = effects.index("if type(state.monster)", read_start)
        read_fn = effects[read_start:read_end]
        self.assertIn("combat.isGhost == true", read_fn)
        self.assertIn("player.isGhost == true", read_fn)
        self.assertLess(
            read_fn.index("combat.isGhost == true"),
            read_fn.index("combat.healthState"),
        )


    def test_request_0097_spectator_and_ghost_role_gates_for_effects_modes(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        effects = read("src/client/UI/EffectsView.lua")
        # isEliminated excludes Spectator-role players (they are not eliminated even when dead)
        self.assertIn('player.role ~= "Spectator"', controller)
        self.assertIn("player.alive == false", controller)
        self.assertIn("and not isGhost", controller)
        # SetSpectatorMode is called with the isEliminated guard
        self.assertIn("currentEffects:SetSpectatorMode(isEliminated and not roundEnded)", controller)
        # monsterModeActive is gated: ghost players never see monster mode visuals
        monster_mode_start = controller.index("local monsterModeActive = phaseName")
        monster_mode_end = controller.index("currentEffects:SetMonsterMode(monsterModeActive)", monster_mode_start)
        monster_mode_def = controller[monster_mode_start:monster_mode_end]
        self.assertIn("and not isGhost", monster_mode_def)
        self.assertIn('phaseName == "Investigation"', monster_mode_def)
        # Heartbeat suppressed for Ghost, Spectator, and Murderer; only living Camper gets dread
        heartbeat_start = controller.index('if roleName == "Murderer" or isGhost or roleName == "Spectator"')
        heartbeat_end = controller.index("currentAudio:SetHeartbeatIntensity(dreadFraction)", heartbeat_start)
        heartbeat_block = controller[heartbeat_start:heartbeat_end]
        self.assertIn("currentAudio:SetHeartbeatIntensity(0)", heartbeat_block)
        # EffectsView: SetSpectatorMode fades spectatorOverlay in; SetMonsterMode tweens ColorShift_Top
        self.assertIn("function EffectsView:SetSpectatorMode(active: boolean)", effects)
        self.assertIn("spectatorOverlay.BackgroundTransparency = targetTransparency", effects)
        self.assertIn("function EffectsView:SetMonsterMode(active: boolean)", effects)
        self.assertIn("MONSTER_MODE_SHIFT = Color3.fromRGB(42, 8, 4)", effects)
        self.assertIn("ColorShift_Top = targetShift", effects)


    def test_request_0098_witness_and_objective_notification_role_split(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        # Witness-interviewed notification: Murderer gets Warning; Camper gets Info
        self.assertIn('"Witness interviewed"', controller)
        self.assertIn(
            '"A witness has been questioned — %d of %d counselors spoken to."',
            controller,
        )
        self.assertIn('"%d of %d witnesses spoken to."', controller)
        # Objectives notification: Murderer gets Warning; Camper gets Info
        self.assertIn('"Camp task progress"', controller)
        self.assertIn('"Campers advancing: %d of %d tasks done."', controller)
        self.assertIn('"Camp task complete"', controller)
        self.assertIn('"%d of %d tasks done."', controller)
        # Both notifications are suppressed for Ghost and Spectator
        witness_start = controller.index("revealedWitnessCount > lastRevealedWitnessCount")
        witness_end = controller.index("lastRevealedWitnessCount = revealedWitnessCount", witness_start)
        witness_block = controller[witness_start:witness_end]
        self.assertIn("and not isGhost", witness_block)
        self.assertIn('and roleName ~= "Spectator"', witness_block)
        objectives_start = controller.index("objectivesCompleted > lastObjectivesCompleted")
        objectives_end = controller.index("lastObjectivesCompleted = objectivesCompleted", objectives_start)
        objectives_block = controller[objectives_start:objectives_end]
        self.assertIn("and not isGhost", objectives_block)
        self.assertIn('and roleName ~= "Spectator"', objectives_block)
        # Within each notification block, Murderer Warning precedes Camper Info
        for block, name in ((witness_block, "witness"), (objectives_block, "objectives")):
            murderer_idx = block.index('"Warning"')
            camper_idx = block.index('"Info"')
            self.assertLess(murderer_idx, camper_idx, name)

    def test_request_0109_health_state_degradation_and_recovery_notifications(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        # HEALTH_SEVERITY lookup table: four states with numeric severity levels
        self.assertIn("local HEALTH_SEVERITY: { [string]: number } = {", controller)
        self.assertIn("Healthy = 0,", controller)
        self.assertIn("Injured = 1,", controller)
        self.assertIn("Incapacitated = 2,", controller)
        self.assertIn("Critical = 2,", controller)
        # healthImproved guard: only fires when actually healing, not on reconnect or round end
        self.assertIn(
            "local healthImproved = currentHealthState == \"Healthy\"",
            controller,
        )
        self.assertIn("and lastHealthState ~= nil", controller)
        self.assertIn('and lastHealthState ~= "Healthy"', controller)
        # Healing effect + notification on health improvement
        recovery_start = controller.index("if healthImproved then")
        recovery_end = controller.index("if currentHealthState ~= lastHealthState then", recovery_start)
        recovery_block = controller[recovery_start:recovery_end]
        self.assertIn("currentEffects:ShowHealedEffect()", recovery_block)
        self.assertIn('"You\'ve recovered"', recovery_block)
        self.assertIn('"Success"', recovery_block)
        # severityDegraded guard: only fires when severity strictly worsens
        self.assertIn("local severityDegraded = currentSeverity ~= nil", controller)
        self.assertIn("and currentSeverity > lastHealthSeverity", controller)
        # Impact flash fires for both injury severity levels
        degrade_start = controller.index("if severityDegraded then")
        degrade_end = controller.index("if currentSeverity ~= lastHealthSeverity then", degrade_start)
        degrade_block = controller[degrade_start:degrade_end]
        self.assertIn("currentCinematics:PlayImpactFlash()", degrade_block)
        # Incapacitated (severity >= 2): screen shake + DangerBright notification
        self.assertIn("if currentSeverity >= 2 then", degrade_block)
        self.assertIn("currentCinematics:PlayScreenShake(0.5)", degrade_block)
        self.assertIn('"You\'re incapacitated"', degrade_block)
        self.assertIn('"DangerBright"', degrade_block)
        # Injured (severity < 2): Warning notification, no extra shake
        self.assertIn('"You\'ve been injured"', degrade_block)
        self.assertIn('"Warning"', degrade_block)
        # Incapacitated branch precedes Injured branch (matching if/else order)
        self.assertLess(
            degrade_block.index('"DangerBright"'),
            degrade_block.index('"Warning"'),
        )
        # healthImproved block comes before severityDegraded block in source order
        self.assertLess(
            controller.index("if healthImproved then"),
            controller.index("if severityDegraded then"),
        )


    def test_request_0115_role_panel_badge_and_action_button_role_dispatch(self) -> None:
        view = read("src/client/UI/GameView.lua")
        update_start = view.index("function GameView:Update(state: any")
        update_end = view.index("function GameView:Tick()", update_start)
        update_block = view[update_start:update_end]
        # State badge: ghost gets "GHOST" text and Ghost color (both stateBadge and roleTitle)
        ghost_badge_start = update_block.index("if ghost then")
        alive_badge_start = update_block.index("elseif alive then", ghost_badge_start)
        ghost_badge_block = update_block[ghost_badge_start:alive_badge_start]
        self.assertIn('self.stateBadge.Text = "GHOST"', ghost_badge_block)
        self.assertIn("self.stateBadge.BackgroundColor3 = Theme.Colors.Ghost", ghost_badge_block)
        self.assertIn("self.roleTitle.TextColor3 = Theme.Colors.Ghost", ghost_badge_block)
        # Alive non-ghost: Murderer gets DangerBright role title; others get Gold
        alive_badge_end = update_block.index("else\n\t\tself.stateBadge.Text", alive_badge_start)
        alive_badge_block = update_block[alive_badge_start:alive_badge_end]
        self.assertIn(
            'if role == "Murderer" then Theme.Colors.DangerBright else Theme.Colors.Gold',
            alive_badge_block,
        )
        # Ghost badge block appears before alive block (ordering enforced)
        self.assertLess(ghost_badge_start, alive_badge_start)
        # Role action button: ghost locks all actions
        role_action_start = update_block.index("local roleActionText = if ghost")
        role_action_end = update_block.index("self.roleActionBaseText = roleActionText", role_action_start)
        role_action_block = update_block[role_action_start:role_action_end]
        self.assertIn('"GHOST ACTIONS LOCKED"', role_action_block)
        self.assertIn('"PLAN TONIGHT\'S HUNT"', role_action_block)
        self.assertIn('"USE MONSTER ABILITY"', role_action_block)
        self.assertIn('"USE ROLE ABILITY"', role_action_block)
        # Ghost text precedes plan/monster/role text in dispatch (ghost is first branch)
        self.assertLess(
            role_action_block.index('"GHOST ACTIONS LOCKED"'),
            role_action_block.index('"PLAN TONIGHT\'S HUNT"'),
        )
        # Living role action enabled gate: ghost cannot trigger living role abilities
        self.assertIn(
            "local livingRoleActionEnabled = not ghost and (roleEnabled or monsterEnabled or planEnabled)",
            update_block,
        )


    def test_request_0117_roster_panel_ghost_sort_and_dot_color_dispatch(self) -> None:
        view = read("src/client/UI/GameView.lua")
        roster_start = view.index("function GameView:_updateRoster(state: any)")
        roster_end = view.index("function GameView:_updateVote(", roster_start)
        roster_block = view[roster_start:roster_end]
        # Sort: alive+not-ghost=0, ghost=1, dead=2 (alive < ghost < dead)
        self.assertIn(
            "if leftAlive and not leftGhost then 0 elseif leftGhost then 1 else 2",
            roster_block,
        )
        self.assertIn(
            "if rightAlive and not rightGhost then 0 elseif rightGhost then 1 else 2",
            roster_block,
        )
        # Dot color: ghost → Ghost, not alive → TextMuted, Injured/Critical → Danger, else → Success
        self.assertIn(
            "if ghost\n\t\t\tthen Theme.Colors.Ghost",
            roster_block,
        )
        self.assertIn("elseif not alive then Theme.Colors.TextMuted", roster_block)
        self.assertIn(
            'elseif healthState == "Injured" or healthState == "Critical"',
            roster_block,
        )
        self.assertIn("then Theme.Colors.Danger", roster_block)
        self.assertIn("else Theme.Colors.Success", roster_block)
        # Name label: ghost → Ghost, not alive → TextMuted + 0.5 transparency, else → Text
        self.assertIn("nameLabel.TextColor3 = if ghost", roster_block)
        self.assertIn("then Theme.Colors.Ghost", roster_block)
        self.assertIn("elseif not alive then Theme.Colors.TextMuted", roster_block)
        self.assertIn("else Theme.Colors.Text", roster_block)
        self.assertIn(
            "nameLabel.TextTransparency = if not alive and not ghost then 0.5 else 0",
            roster_block,
        )
        # "isMe" marker appended to the local player's name
        self.assertIn('if isMe then displayName .. " ●" else displayName', roster_block)


    def test_request_0118_vote_panel_murderer_text_and_ghost_gate(self) -> None:
        view = read("src/client/UI/GameView.lua")
        vote_start = view.index("function GameView:_updateVote(round: any, player: any)")
        vote_end = view.index("function GameView:_available(", vote_start)
        vote_block = view[vote_start:vote_end]
        # Warning label: Murderer favors tie vs non-Murderer does not
        self.assertIn(
            'readString(player, "role", "") == "Murderer"',
            vote_block,
        )
        self.assertIn(
            '"One vote. No take-backs. A tie breaks in your favor."',
            vote_block,
        )
        self.assertIn(
            '"One vote. No take-backs. A tie favors the Murderer."',
            vote_block,
        )
        # Modal title: Murderer sees "CAMPFIRE VOTE"; others see "CAMPFIRE ACCUSATION"
        self.assertIn('"CAMPFIRE VOTE"', vote_block)
        self.assertIn('"CAMPFIRE ACCUSATION"', vote_block)
        # Modal hides when not Campfire phase, not alive, or isGhost
        self.assertIn(
            'phase ~= "Campfire" or not alive or isGhost',
            vote_block,
        )
        # "(you)" suffix on the local player's own suspect row
        self.assertIn('if isSelf then name .. " (you)" else name', vote_block)
        # "YOUR VOTE" suffix and Gold color on the selected vote
        self.assertIn('if isMyVote then labelText .. "  ✓ YOUR VOTE" else labelText', vote_block)
        self.assertIn(
            "if isMyVote\n\t\t\t\t\tthen Theme.Colors.Gold",
            vote_block,
        )
        self.assertIn("elseif isOtherVote then Theme.Colors.Panel", vote_block)
        self.assertIn("else Theme.Colors.Danger", vote_block)
        # isOtherVote rows are dimmed; isMyVote row uses Background text color
        self.assertIn("button.BackgroundTransparency = 0.7", vote_block)
        self.assertIn("button.TextColor3 = Theme.Colors.Background", vote_block)


if __name__ == "__main__":
    unittest.main(verbosity=2)
