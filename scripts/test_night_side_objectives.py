"""Contracts for night side-objectives, counselor rescue, and the ghost haunt meter."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class NightSideObjectiveTests(unittest.TestCase):
    def test_runtime_types_declare_ghost_actions_and_snapshot(self) -> None:
        runtime_types = read("src/shared/Types/RuntimeTypes.lua")
        for token in (
            '| "GhostSync"',
            '| "GhostHaunt"',
            "export type GhostSnapshot",
            "hauntMeter: number",
            "hauntMeterMax: number",
            "hauntReady: boolean",
            "echoCooldownEndsAt: number",
            "ghost: GhostSnapshot?",
        ):
            self.assertIn(token, runtime_types)
        profile_types = read("src/shared/Types/ProfileTypes.lua")
        reward_input = profile_types.split("export type RewardInput", 1)[1]
        reward_input = reward_input.split("export type RewardGrant", 1)[0]
        self.assertIn("sideObjectives: number?", reward_input)
        self.assertIn("ghostObjectives: number?", reward_input)

    def test_reward_calculation_caps_side_and_ghost_bonuses(self) -> None:
        rewards = read("src/server/Systems/RewardCalculation.lua")
        for token in (
            "math.floor(input.sideObjectives or 0), 3)",
            "xp += sideObjectives * 15",
            "campTokens += sideObjectives * 2",
            "math.floor(input.ghostObjectives or 0), 6) * 4",
        ):
            self.assertIn(token, rewards)
        # Bonuses only pay when the participant actually played the round.
        participated = rewards.index("if input.participated then")
        self.assertLess(participated, rewards.index("input.sideObjectives"))
        self.assertLess(participated, rewards.index("input.ghostObjectives"))

    def test_map_side_objective_props_prompts_and_reset(self) -> None:
        world = read("src/server/Services/ProductionMapService.lua")
        for token in (
            "type SideObjectiveHandler = (player: Player, sideObjectiveId: string) -> boolean",
            '"RadioBeaconConsole"',
            '"MillFuseBox"',
            '"WTLadder"',
            'Instance.new("TrussPart")',
            "startsDark: boolean?",
            '"DarkLantern"',
            "FUSE_BOX_RELIGHT_RADIUS",
            "function ProductionMapService:SetSideObjectivePromptsEnabled",
            "function ProductionMapService:GetSideObjectivePosition",
            "function ProductionMapService:ResetSideObjectives",
            "if self.sideObjectiveComplete[sideObjectiveId] then",
        ):
            self.assertIn(token, world)
        # Side-objective prompts start dark so the day/night visibility sweep
        # caches them as disabled until the Investigation phase turns them on.
        register = world.split(
            "function ProductionMapService:_registerSideObjective", 1
        )[1].split("function ProductionMapService:_buildSideObjectives", 1)[0]
        self.assertIn("prompt.Enabled = false", register)
        # The fuse repair updates the Visible* attribute cache so the repaired
        # state survives later setFolderVisible passes.
        relight = world.split(
            "function ProductionMapService:_setFactoryStreetlights", 1
        )[1].split("function ProductionMapService:_markSideObjectiveComplete", 1)[0]
        self.assertIn('SetAttribute("VisibleTransparency", transparency)', relight)
        self.assertIn('light:SetAttribute("VisibleEnabled", repaired)', relight)
        # Round reset restores the props and the dark lanterns.
        reset_round = world.split("function ProductionMapService:ResetRound", 1)[1]
        self.assertIn("self:ResetSideObjectives()", reset_round)

    def test_world_service_side_objective_forwards_are_optional(self) -> None:
        world_service = read("src/server/Services/WorldService.lua")
        self.assertIn(
            "SetSideObjectivePromptsEnabled: ((self: any, enabled: boolean) -> ())?",
            world_service,
        )
        self.assertIn(
            "GetSideObjectivePosition: ((self: any, sideObjectiveId: string) -> Vector3?)?",
            world_service,
        )
        self.assertIn(
            "local forward = self.fallback.SetSideObjectivePromptsEnabled",
            world_service,
        )
        self.assertIn(
            "local forward = self.fallback.GetSideObjectivePosition",
            world_service,
        )

    def test_counselor_cornered_reuses_threat_machinery(self) -> None:
        counselors = read("src/server/Services/CounselorService.lua")
        for token in (
            "function CounselorService:SetCornered",
            "function CounselorService:RescueCornered",
            'state.behavior = "Hiding"',
            'state.behavior = "Fleeing"',
            "definition.fleeLocationIds",
        ):
            self.assertIn(token, counselors)
        # Hiding blocks dialogue, so a cornered counselor cannot be interviewed
        # until they are freed.
        self.assertIn('state.behavior ~= "Fleeing"', counselors)
        self.assertIn('state.behavior ~= "Hiding"', counselors)
        cornered = counselors.split("function CounselorService:SetCornered", 1)[1]
        cornered = cornered.split("function CounselorService:RescueCornered", 1)[0]
        self.assertIn("state.threatActive = true", cornered)
        self.assertIn("Counselor is already reacting to a threat", cornered)

    def test_runtime_side_objective_validation_order_and_rescue_failsafe(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        for token in (
            "local SIDE_OBJECTIVE_RANGE_STUDS = 16",
            "local RESCUE_SELF_RESOLVE_SECONDS = 60",
            "function GameRuntimeService:_handleSideObjective",
            "function GameRuntimeService:_fireRadioBeacon",
            "function GameRuntimeService:_beginCounselorRescue",
            "function GameRuntimeService:_handleCounselorRescue",
            "function GameRuntimeService:_resolveCounselorRescue",
            "self:_resolveCounselorRescue(nil)",
            "self.mystery:InterviewCounselor(rescuer.participantId, counselorId, now())",
            "self.characters:SetCounselorCornered(counselorId, true",
            'self.world:SetSideObjectivePromptsEnabled(true)',
            'self.world:SetSideObjectivePromptsEnabled(false)',
        ):
            self.assertIn(token, runtime)
        handler = runtime.split(
            "function GameRuntimeService:_handleSideObjective", 1
        )[1].split("function GameRuntimeService:_fireRadioBeacon", 1)[0]
        # Phase gate, one-claim gate, and real proximity all precede the payout.
        payout = handler.index("self.sideObjectivesByParticipantId")
        self.assertLess(handler.index('self.phase ~= "Investigation"'), payout)
        self.assertLess(
            handler.index("self.sideObjectivesCompleted[sideObjectiveId]"), payout
        )
        self.assertLess(handler.index("SIDE_OBJECTIVE_RANGE_STUDS"), payout)
        # The rescue self-resolves so an empty or solo night can never stall.
        rescue = runtime.split(
            "function GameRuntimeService:_beginCounselorRescue", 1
        )[1].split("function GameRuntimeService:_handleCounselorRescue", 1)[0]
        self.assertIn("task.delay(RESCUE_SELF_RESOLVE_SECONDS", rescue)
        self.assertIn("self:_resolveCounselorRescue(nil)", rescue)
        # The counselor is freed before the witness hint is collected (the
        # interview gate requires an interactable counselor); only then flee.
        resolve = runtime.split(
            "function GameRuntimeService:_resolveCounselorRescue", 1
        )[1].split("-- The campfire only wards off", 1)[0]
        self.assertLess(
            resolve.index("self.counselors:ClearThreat(counselorId, now())"),
            resolve.index("self.mystery:InterviewCounselor"),
        )
        self.assertLess(
            resolve.index("self.mystery:InterviewCounselor"),
            resolve.index("self.counselors:RescueCornered(counselorId, now())"),
        )

    def test_runtime_ghost_sync_scoring_and_haunt_spend(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        for token in (
            "local HAUNT_METER_MAX = 100",
            "local GHOST_SYNC_MAX_STEP_SECONDS = 2",
            "local COLD_SPOT_GOAL_SECONDS = 10",
            "local VIGIL_GOAL_SECONDS = 20",
            "local ECHO_COOLDOWN_SECONDS = 45",
            "function GameRuntimeService:_ghostSync",
            "function GameRuntimeService:_ghostHaunt",
            "function GameRuntimeService:_completeGhostObjective",
            "state.hauntMeter < HAUNT_METER_MAX",
            "state.hauntMeter = 0",
            "if not self:_flickerLightsNear(origin) then",
            "self:_playKnockAt(origin)",
            "ghost = if participant and participant.isGhost",
        ):
            self.assertIn(token, runtime)
        # Both ghost actions are gated on the caller actually being a ghost.
        for action in ("GhostSync", "GhostHaunt"):
            self.assertIn(
                f'actionName == "{action}"\n\t\tand rawParticipant'
                "\n\t\tand rawParticipant.isGhost",
                runtime,
            )
        sync = runtime.split("function GameRuntimeService:_ghostSync", 1)[1]
        sync = sync.split("function GameRuntimeService:_flickerLightsNear", 1)[0]
        # Sync steps are clamped and the vigil streak resets when broken.
        self.assertIn("math.clamp(elapsed, 0, GHOST_SYNC_MAX_STEP_SECONDS)", sync)
        self.assertGreaterEqual(sync.count("state.vigilSeconds = 0"), 2)
        self.assertIn('self.phase ~= "Investigation"', sync)
        # Murder scenes are recorded where bodies drop so ECHO has real targets.
        self.assertIn(
            "table.insert(runtime.murderScenePositions, position)", runtime
        )

    def test_runtime_rewards_and_transfer_carry_night_progress(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        rewards = runtime.split("function GameRuntimeService:_ApplyRewards", 1)[1]
        rewards = rewards.split("local CAMPFIRE_POSITION", 1)[0]
        self.assertIn("sideObjectives =", rewards)
        self.assertIn(
            "ghostObjectives = if self.ghostStateById[participant.participantId]",
            rewards,
        )
        # Bot replacement keeps side/ghost progress with the surviving identity.
        self.assertIn(
            "runtime.sideObjectivesByParticipantId[destination.participantId]",
            runtime,
        )
        self.assertIn(
            "runtime.ghostStateById[destination.participantId]",
            runtime,
        )

    def test_client_ghost_sync_heartbeat_is_silent_and_phase_gated(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        for token in (
            "local GHOST_SYNC_INTERVAL_SECONDS = 1",
            "local function maybeSendGhostSync",
            "player.isGhost ~= true",
            'readString(round, "phase", "") ~= "Investigation"',
            'requestAction("GhostSync", {',
            "maybeSendGhostSync(currentState)",
            "local function applyGhostSnapshot",
            'requestAction("GhostHaunt", {',
            "ghost.hauntReady ~= true",
            "if #pendingActionNames > 0 then",
        ):
            self.assertIn(token, controller)
        # GhostSync results never toast: the branch exits before the generic
        # toast pipeline in handleActionResult.
        handle = controller.split("local function handleActionResult", 1)[1]
        self.assertLess(
            handle.index('if actionName == "GhostSync" then'),
            handle.index('if type(payload) ~= "table" then'),
        )
        sync_branch = handle.split('if actionName == "GhostSync" then', 1)[1]
        sync_branch = sync_branch.split('if actionName == "GhostHaunt"', 1)[0]
        self.assertIn("applyGhostSnapshot((payload :: any).data)", sync_branch)
        self.assertIn("return", sync_branch)

    def test_client_haunt_key_and_meter_ui(self) -> None:
        camera = read("src/client/Controllers/CameraController.lua")
        for token in (
            "onHauntRequest: ((position: Vector3) -> ())?",
            "Enum.KeyCode.H or keyCode == Enum.KeyCode.ButtonX",
            "function CameraController:_requestHaunt()",
        ):
            self.assertIn(token, camera)
        view = read("src/client/UI/GameView.lua")
        for token in (
            '"HauntPanel"',
            '"HauntTrack"',
            '"HauntFill"',
            "function GameView:UpdateGhostHaunt(ghost: any)",
            '"HAUNT READY — press H"',
            "if not active and self.hauntPanel then",
            '"GhostObjectiveStrip"',
            "MissionView.GhostAgencyStrip",
            "MissionView.GhostSnapshotProgress",
            "MissionView.GhostMissionCopy",
        ):
            self.assertIn(token, view)

    def test_bots_ignore_night_side_objectives(self) -> None:
        bots = read("src/server/Services/ComputerPlayerService.lua")
        for token in ("radio-beacon", "fuse-box", "counselor-rescue", "GhostSync"):
            self.assertNotIn(token, bots)
        runtime = read("src/server/Services/GameRuntimeService.lua")
        bot_actions = runtime.split(
            "function GameRuntimeService:_GetBotActions", 1
        )[1].split("function GameRuntimeService:_ExecuteBotAction", 1)[0]
        for token in ("SideObjective", "radio-beacon", "fuse-box", "hauntMeter"):
            self.assertNotIn(token, bot_actions)

    def test_phase_tips_and_diegetic_announcements(self) -> None:
        tips = read("src/shared/Config/PhaseTips.lua")
        self.assertIn("water tower", tips)
        runtime = read("src/server/Services/GameRuntimeService.lua")
        for token in (
            '"Night signals"',
            "Static crackles from the water tower",
            '"A cry in the dark"',
            '"Counselor rescued"',
            '"They got away"',
        ):
            self.assertIn(token, runtime)


if __name__ == "__main__":
    unittest.main(verbosity=2)
