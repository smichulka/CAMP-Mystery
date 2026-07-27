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


    def test_request_0090_reward_calculation_role_split(self) -> None:
        reward = (ROOT / "src/server/Systems/RewardCalculation.lua").read_text(encoding="utf-8")
        # Murderer wins and camper wins are tracked separately
        for token in (
            'local roleIsMurderer = input.roleId == "Murderer"',
            "camperWins = if input.participated and input.won and not roleIsMurderer",
            "murdererWins = if input.participated and input.won and roleIsMurderer",
        ):
            self.assertIn(token, reward)
        self.assertIn("return table.freeze(HINTS)", (ROOT / "src/shared/Config/KeybindHints.lua").read_text(encoding="utf-8"))
        # ProfileService passes roleId from participant
        profile = (ROOT / "src/server/Services/ProfileService.lua").read_text(encoding="utf-8")
        self.assertIn("RewardCalculation", profile)
        self.assertIn(".Calculate(", profile)


    def test_request_0100_combat_and_voting_role_eligibility_guards(self) -> None:
        combat = source("Services/CombatService.lua")
        voting = source("Services/VotingService.lua")
        # CombatService: only Murderer can attack
        self.assertIn('attacker.role ~= "Murderer"', combat)
        self.assertIn('"Attacker is not eligible"', combat)
        # CombatService: only living non-ghost Campers can be targeted
        self.assertIn("target.team ~= \"Campers\"", combat)
        self.assertIn('"Target is not eligible"', combat)
        # CombatService: ghost transition fires 3 seconds after death
        self.assertIn("target.isGhost = true", combat)
        self.assertIn("self.lifecycle:Emit(\"ParticipantGhostTransition\"", combat)
        # CombatService: ApplyInjury also blocks ghost/non-Camper targets
        injury_start = combat.index("function CombatService:ApplyInjury(")
        injury_end = combat.index("function CombatService:ApplyAttack(", injury_start)
        injury_block = combat[injury_start:injury_end]
        self.assertIn("target.isGhost", injury_block)
        self.assertIn('target.team ~= "Campers"', injury_block)
        # VotingService: Ghost and Spectator cannot vote
        self.assertIn("voter.isGhost", voting)
        self.assertIn('voter.role == "Spectator"', voting)
        self.assertIn('"Participant cannot vote"', voting)
        # VotingService: Ghost and Spectator cannot be voted out
        self.assertIn("target.isGhost", voting)
        self.assertIn('target.role == "Spectator"', voting)
        self.assertIn('"Suspect is not eligible"', voting)
        # VotingService: eligible voter count excludes Ghost and Spectator
        eligible_start = voting.index("function VotingService:GetEligibleVoterCount()")
        eligible_end = voting.index("function VotingService:CastVote(", eligible_start)
        eligible_block = voting[eligible_start:eligible_end]
        self.assertIn("not participant.isGhost", eligible_block)
        self.assertIn('participant.role ~= "Spectator"', eligible_block)
        # VotingService: early-win check requires alive, non-ghost Campers
        self.assertIn('participant.team == "Campers"', voting)
        self.assertIn("participant.alive and not participant.isGhost", voting)


    def test_request_0101_participant_and_ability_role_init_and_gate_contracts(self) -> None:
        participant_svc = (ROOT / "src/server/Services/ParticipantService.lua").read_text(encoding="utf-8")
        ability_svc = (ROOT / "src/server/Services/RoleAbilityService.lua").read_text(encoding="utf-8")
        evidence_svc = source("Services/EvidenceService.lua")
        # Spectator spawns dead (alive = false) via resetParticipant
        self.assertIn('state.alive = roleName ~= "Spectator"', participant_svc)
        self.assertIn("state.isGhost = false", participant_svc)
        # RoleAbilityService: Spectator and dead-non-ghost are blocked from all abilities
        self.assertIn(
            'participant.role == "Spectator" or (not participant.alive and not participant.isGhost)',
            ability_svc,
        )
        self.assertIn('"Participant is not active"', ability_svc)
        # RoleAbilityService: ghost blocked unless allowGhost is true
        self.assertIn("participant.isGhost and not allowGhost", ability_svc)
        self.assertIn('"Ghosts cannot use this ability"', ability_svc)
        # TriggerTrap: Murderer trigger reveals monster and gets 4-second slow; Camper gets 1
        self.assertIn('revealedMonster = triggering.role == "Murderer"', ability_svc)
        self.assertIn('if triggering.role == "Murderer" then 4 else 1', ability_svc)
        # Investigate: Spectator cannot be investigated
        self.assertIn('target.role == "Spectator"', ability_svc)
        self.assertIn('"Investigation target is invalid"', ability_svc)
        # Investigate: Murderer gets High suspicion band; innocent gets Low
        inv_start = ability_svc.index('local band = if target.role == "Murderer"')
        inv_block = ability_svc[inv_start:inv_start + 200]
        self.assertIn('"High"', inv_block)
        self.assertIn('"Low"', inv_block)
        self.assertLess(inv_block.index('"High"'), inv_block.index('"Low"'))
        # EvidenceService: ghosts cannot discover or annotate evidence
        self.assertIn("participant.isGhost", evidence_svc)
        self.assertIn('"Participant cannot discover physical evidence"', evidence_svc)
        self.assertIn('"Participant cannot add a note"', evidence_svc)
        # EvidenceService: only the living Detective can verify evidence
        self.assertIn('detective.role ~= "Detective"', evidence_svc)
        self.assertIn('"Only the living Detective can verify evidence"', evidence_svc)


    def test_request_0102_computer_player_murderer_role_gates(self) -> None:
        bot = (ROOT / "src/server/Services/ComputerPlayerService.lua").read_text(encoding="utf-8")
        # BuildMurdererLieTarget: only runs for Murderer role
        self.assertIn('participant.role ~= "Murderer"', bot)
        # Lie target selection filters out co-Murderer candidates
        self.assertIn('other.role ~= "Murderer"', bot)
        # ScoreAction: Attack actions are blocked for non-Murderers
        score_start = bot.index("function ComputerPlayerService:ScoreAction(")
        score_end = bot.index("function ComputerPlayerService:", score_start + 1)
        score_block = bot[score_start:score_end]
        self.assertIn('candidate.actionType == "Attack" and participant.role ~= "Murderer"', score_block)
        # ScoreAction: deceptive actions blocked for non-Murderers
        self.assertIn('candidate.isDeceptive and participant.role ~= "Murderer"', score_block)
        # ScoreAction: ghost bots score -math.huge except Idle and Protector intervention
        self.assertIn("not participant.alive or participant.isGhost", score_block)
        self.assertIn("participant.isGhost\n\t\t\tand participant.role == \"Protector\"", score_block)
        # Strategic lie injection in Discuss phase is Murderer-only
        lie_start = bot.index('"strategic-lie:"')
        lie_guard = bot[lie_start - 400:lie_start]
        self.assertIn('participant.role == "Murderer"', lie_guard)
        self.assertIn("ALLOWED_PHASES.Discuss[context.phase]", lie_guard)


    def test_request_0103_runtime_role_gates_and_loadout_contracts(self) -> None:
        runtime = source("Services/GameRuntimeService.lua")
        # _grantLoadout: all roles get their designated equipment
        loadout_start = runtime.index("function GameRuntimeService:_grantLoadout(")
        loadout_end = runtime.index("function GameRuntimeService:", loadout_start + 1)
        loadout_block = runtime[loadout_start:loadout_end]
        for role, item in (
            ('"Detective"', '"UVLight"'),
            ('"Detective"', '"Camera"'),
            ('"Medic"', '"MedicalKit"'),
            ('"Trapper"', '"MonsterTrap"'),
            ('"Medium"', '"SpiritBox"'),
            ('"Guard"', '"FlareLantern"'),
            ('"Camper"', '"EMFReader"'),
        ):
            self.assertIn(role, loadout_block)
            self.assertIn(item, loadout_block)
        # _findCulprit: errors if no Murderer in roster
        self.assertIn('participant.role == "Murderer"', runtime)
        self.assertIn('"Role assignment did not produce a Murderer"', runtime)
        # _suspects: filters out Ghost and Spectator
        suspects_start = runtime.index("function GameRuntimeService:_suspects()")
        suspects_end = runtime.index("function GameRuntimeService:GetRoundSnapshot", suspects_start)
        suspects_block = runtime[suspects_start:suspects_end]
        self.assertIn("not participant.isGhost", suspects_block)
        self.assertIn('participant.role ~= "Spectator"', suspects_block)
        # Action-enabled gates: SetMurderPlan only for Murderer in MurderPlanning
        self.assertIn('name == "SetMurderPlan"', runtime)
        self.assertIn('participant.role == "Murderer"', runtime)
        # Action-enabled gates: UseMonsterAbility requires Murderer in Investigation
        self.assertIn('name == "UseMonsterAbility"', runtime)
        # Action-enabled gates: UseRoleAbility respects role-phase mapping
        self.assertIn('participant.role == "Medium"', runtime)
        self.assertIn('participant.role == "Protector" and participant.isGhost', runtime)
        # Action-enabled gates: VerifyEvidence requires Detective
        self.assertIn('name == "VerifyEvidence"', runtime)
        self.assertIn('participant.role == "Detective"', runtime)


    def test_request_0104_profile_service_spectator_progression_exclusion(self) -> None:
        profile = source("Services/ProfileService.lua")
        # Spectator is excluded from progressionRoleIds
        self.assertIn('role.name ~= "Spectator"', profile)
        self.assertIn("local function isProgressionRole(roleId: string): boolean", profile)
        # isProgressionRole guards roleMastery sanitization
        mastery_start = profile.index("for rawRoleId, rawMastery in raw.roleMastery do")
        mastery_end = profile.index("for rawRoleId, rawUpgrades in raw.upgrades do", mastery_start)
        mastery_block = profile[mastery_start:mastery_end]
        self.assertIn("isProgressionRole(roleId)", mastery_block)
        # isProgressionRole guards upgrades sanitization
        upgrades_start = profile.index("for rawRoleId, rawUpgrades in raw.upgrades do")
        upgrades_end = profile.index("function ProfileService:", upgrades_start)
        upgrades_block = profile[upgrades_start:upgrades_end]
        self.assertIn("isProgressionRole(roleId)", upgrades_block)
        # Reward application rejects Spectator roleId
        self.assertIn("not isProgressionRole(roleId)", profile)
        self.assertIn('"InvalidRewardIdentity"', profile)


    def test_request_0105_available_actions_ghost_spectator_root_gate(self) -> None:
        runtime = source("Services/GameRuntimeService.lua")
        # _availableActions: active = false for ghost and Spectator
        avail_start = runtime.index("function GameRuntimeService:_availableActions(")
        avail_end = runtime.index("function GameRuntimeService:", avail_start + 1)
        avail_block = runtime[avail_start:avail_end]
        self.assertIn("not participant.isGhost", avail_block)
        self.assertIn('participant.role ~= "Spectator"', avail_block)
        # active variable is the root gate passed to all action-enabled checks
        self.assertIn("local active = participant ~= nil", avail_block)
        # Confirms active=false short-circuits all non-persistent action toggles
        self.assertIn("local enabled = active", avail_block)


if __name__ == "__main__":
    unittest.main(verbosity=2)
