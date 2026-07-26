"""Focused static contracts for server runtime failure and transfer semantics.

These checks do not emulate Roblox. They lock in the defensive integration paths
that are easy to accidentally remove while the live behavior remains Studio-only.
"""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "src" / "server"


def source(relative: str) -> str:
    return (SERVER / relative).read_text(encoding="utf-8")


class ServerReleaseContracts(unittest.TestCase):
    def test_remote_gateway_bounds_and_contains_failures(self) -> None:
        bootstrap = source("Bootstrap.server.lua")
        self.assertIn("MAX_PAYLOAD_DEPTH", bootstrap)
        self.assertIn("MAX_PAYLOAD_ENTRIES", bootstrap)
        self.assertIn("requestsInFlight", bootstrap)
        self.assertIn("handleActionSafely", bootstrap)
        self.assertRegex(
            bootstrap,
            r"pcall\(function\(\)\s+return runtime:HandleAction",
        )
        self.assertIn("Action payload is invalid or too large", bootstrap)

    def test_round_runner_cannot_advance_after_stop(self) -> None:
        runtime = source("Services/GameRuntimeService.lua")
        self.assertIn("function GameRuntimeService:_continueRound", runtime)
        self.assertIn("self.generation ~= generation", runtime)
        self.assertIn("function GameRuntimeService:_recoverRoundFailure", runtime)
        self.assertRegex(runtime, r"pcall\(function\(\)\s+self:_runRound\(generation\)")
        self.assertIn("self.lifecycle:Destroy()", runtime)
        self.assertIn("self.characters:Destroy()", runtime)
        stop_body = runtime.split(
            "function GameRuntimeService:Stop()", maxsplit=1
        )[1].split("function GameRuntimeService:GetServices", maxsplit=1)[0]
        self.assertIn("if not self.running then", stop_body)

    def test_studio_solo_round_cannot_deadlock_behind_ready_ui(self) -> None:
        runtime = source("Services/GameRuntimeService.lua")
        self.assertIn("function GameRuntimeService:_readyStudioPlayers()", runtime)
        self.assertIn("if not RunService:IsStudio() then", runtime)
        self.assertIn("self.matchmaking:SetReady(player, true)", runtime)
        participant_body = runtime.split(
            "function GameRuntimeService:_participantIdsForRound", maxsplit=1
        )[1].split(
            "function GameRuntimeService:_grantLoadout", maxsplit=1
        )[0]
        self.assertIn("self:_readyStudioPlayers()", participant_body)
        start_body = runtime.split(
            "function GameRuntimeService:Start()", maxsplit=1
        )[1].split("function GameRuntimeService:Stop()", maxsplit=1)[0]
        self.assertGreaterEqual(start_body.count("self:_readyStudioPlayers()"), 2)
        self.assertIn(
            'station.PrimaryPart or station:FindFirstChild("InteractionRoot")',
            runtime,
        )

    def test_procedural_world_is_navigable_interactive_and_visually_layered(self) -> None:
        world = source("Services/ProductionMapService.lua")
        for token in (
            "hideDefaultBaseplate",
            "HiddenByCampMystery",
            "buildCampTerrain",
            "terrain:FillBlock(",
            "Enum.Material.Water",
            "createInteractiveDoor",
            'createPrompt(door, "Open"',
            "createInspectPrompt",
            '"InteractionFeedback"',
            '"CabinLight"',
            '"BunkBed"',
            '"CabinTable"',
            '"TownGround"',
            '"CampAtmosphere"',
            '"CampColor"',
            '"CampBloom"',
            "TweenService:Create(Lighting",
            "interactiveDoors",
            'createPrompt(fire, "Tend Fire"',
        ):
            self.assertIn(token, world)

    def test_disconnect_transfers_every_deduction_identity(self) -> None:
        runtime = source("Services/GameRuntimeService.lua")
        mystery = source("Services/MysteryService.lua")
        voting = source("Services/VotingService.lua")
        self.assertIn("runtime.mystery:TransferParticipant(", runtime)
        self.assertIn("function MysteryService:TransferParticipant(", mystery)
        for identity in (
            "self.culpritParticipantId",
            "self.frameTargetId",
            "clue.suspectCandidateIds",
            "account.suspectCandidateIds",
            "clue.discoveredByParticipantId",
            "account.interviewedByParticipantId",
        ):
            self.assertIn(identity, mystery)
        self.assertIn("participant.vote.targetParticipantId", voting)

    def test_profile_flush_does_not_blindly_replace_current_value(self) -> None:
        profile = source("Services/ProfileService.lua")
        save_body = profile.split(
            "function ProfileService:SavePlayer", maxsplit=1
        )[1].split("function ProfileService:_MutateProfile", maxsplit=1)[0]
        self.assertIn("function(currentValue: unknown?)", save_body)
        self.assertIn("sanitizeProfile(currentValue)", save_body)
        self.assertNotIn("function(_currentValue: unknown?)", save_body)
        stop_body = profile.split("function ProfileService:Stop", maxsplit=1)[1]
        self.assertIn("shutdownSaveTimeoutSeconds", stop_body)
        self.assertIn("self:SavePlayer(player)", stop_body)
        start_body = profile.split(
            "function ProfileService:Start", maxsplit=1
        )[1].split("function ProfileService:Stop", maxsplit=1)[0]
        self.assertNotIn("BindToClose", start_body)

    def test_human_counselor_interaction_is_spatially_authorized(self) -> None:
        runtime = source("Services/GameRuntimeService.lua")
        characters = source("Services/CharacterAssetService.lua")
        monster = source("Services/MonsterService.lua")
        self.assertIn("GetCounselorPosition", characters)
        self.assertIn("GetCounselorModel", characters)
        self.assertIn("(counselorAt - participantAt).Magnitude <= 18", runtime)
        self.assertIn("RaycastParams.new()", runtime)
        self.assertIn("Enum.RaycastFilterType.Exclude", runtime)
        self.assertIn("FilterDescendantsInstances", runtime)
        self.assertIn("result.Instance:IsDescendantOf(targetInstance)", runtime)
        self.assertIn("sourceCharacter", runtime)
        self.assertIn("counselorModel", runtime)
        self.assertIn("characterForParticipant(target)", runtime)
        self.assertIn("sourceParticipantId: MonsterParticipantId", monster)
        self.assertIn("targetParticipantId: MonsterParticipantId?", monster)
        self.assertRegex(
            monster,
            r"hasLineOfSight\(\s*sourcePosition,\s*resolvedTargetPosition,"
            r"\s*request\.participantId,\s*targetParticipantId",
        )

    def test_all_fallback_monsters_have_distinct_presentation_branches(self) -> None:
        characters = source("Services/CharacterAssetService.lua")
        for monster_id in (
            "BabyAlien",
            "Screamer",
            "Wendigo",
            "ShadowMonster",
            "Chupacabra",
            "Dullahan",
            "Entity",
            "Banshee",
        ):
            self.assertGreaterEqual(
                len(re.findall(rf'monsterId == "{monster_id}"', characters)),
                1,
                monster_id,
            )
        self.assertIn('findAsset("Monsters", monsterId)', characters)
        self.assertIn('cloneAuthoredMap("Camp")', source("Services/ProductionMapService.lua"))

    def test_authored_character_animations_are_bounded_and_optional(self) -> None:
        characters = source("Services/CharacterAssetService.lua")
        runtime = source("Services/GameRuntimeService.lua")
        for state_name in ("Idle", "Transform", "Hunt", "Flee", "Hide", "Alert"):
            self.assertIn(f'{state_name} = true', characters)
        for behavior, state_name in (
            ("Routine", "Idle"),
            ("Witness", "Idle"),
            ("Suspect", "Idle"),
            ("Fleeing", "Flee"),
            ("Hiding", "Hide"),
            ("Alert", "Alert"),
            ("Unavailable", "Idle"),
        ):
            self.assertIn(f'{behavior} = "{state_name}"', characters)
        self.assertIn('model:GetAttribute("ProceduralFallback") == true', characters)
        self.assertIn('model:FindFirstChild("Animations", true)', characters)
        self.assertIn('animationFolder:IsA("Folder")', characters)
        self.assertIn('animationFolder:FindFirstChild(stateName)', characters)
        self.assertIn('animation:IsA("Animation")', characters)
        self.assertIn('"^rbxassetid://(%d+)$"', characters)
        self.assertNotRegex(characters, r"rbxassetid://\d")
        self.assertIn('model:FindFirstChildWhichIsA("Animator", true)', characters)
        self.assertIn("animator:LoadAnimation(animation)", characters)
        self.assertIn("track:Play(0.15)", characters)
        self.assertIn("track:Stop(0.15)", characters)
        self.assertIn("track:Destroy()", characters)
        self.assertIn('self:PlayMonsterState("Transform", false)', characters)
        self.assertIn('self.characters:PlayMonsterState("Hunt", true)', runtime)
        self.assertIn("self.counselorAnimationTracks = {}", characters)
        self.assertIn("self.monsterAnimationTrack = nil", characters)


if __name__ == "__main__":
    unittest.main(verbosity=2)
