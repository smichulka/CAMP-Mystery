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

    def test_request_0106_monster_catalog_murderer_note_and_consumer(self) -> None:
        catalog = (ROOT / "src/shared/Config/PublicMonsterCatalog.lua").read_text(encoding="utf-8")
        types = (ROOT / "src/shared/Types/MonsterTypes.lua").read_text(encoding="utf-8")
        view = (ROOT / "src/client/UI/GameView.lua").read_text(encoding="utf-8")
        # PublicMonsterDefinition type includes murdererNote field
        self.assertIn("murdererNote: string,", types)
        # All 8 monsters have a murdererNote entry
        for token in (
            'murdererNote = "You are fast at close range.',
            'murdererNote = "Your scream is range-dependent.',
            'murdererNote = "Group light sources are your threat.',
            'murdererNote = "Avoid sustained direct light.',
            'murdererNote = "A UV or flashlight burst can release your latch.',
            'murdererNote = "Build pursuit speed early.',
            'murdererNote = "Your arrival silhouette is visible.',
            'murdererNote = "Give campers time to enter wail radius',
        ):
            self.assertIn(token, catalog)
        # GameView imports PublicMonsterCatalog
        self.assertIn('local PublicMonsterCatalog = require(SharedConfig:WaitForChild("PublicMonsterCatalog"))', view)
        # GameView state type declares monsterNoteLabel
        self.assertIn("monsterNoteLabel: TextLabel?,", view)
        # _updateMonsterPanel reads murdererNote from catalog and sets the label
        panel_start = view.index("function GameView:_updateMonsterPanel(state: any")
        panel_end = view.index("function GameView:_stopTimerPulse()", panel_start)
        panel_fn = view[panel_start:panel_end]
        self.assertIn("local monsterNoteLabel = self.monsterNoteLabel", panel_fn)
        self.assertIn("PublicMonsterCatalog[monsterId]", panel_fn)
        self.assertIn("catalogEntry.murdererNote", panel_fn)

    def test_request_0111_evidence_service_murderer_plant_reframe_and_detective_verify(self) -> None:
        evidence_svc = source("Services/EvidenceService.lua")
        # PlantFake: only the round culprit (Murderer) can plant fake evidence
        plant_start = evidence_svc.index("function EvidenceService:PlantFake(")
        plant_end = evidence_svc.index("function EvidenceService:SetMonsterForRound(", plant_start)
        plant_fn = evidence_svc[plant_start:plant_end]
        self.assertIn("murdererParticipantId ~= self.culpritParticipantId", plant_fn)
        self.assertIn('"Only the Murderer can plant fake evidence"', plant_fn)
        # PlantFake: one-time use gate
        self.assertIn("if self.fakeEvidencePlanted then", plant_fn)
        self.assertIn('"Fake evidence has already been planted"', plant_fn)
        # PlantFake: Murderer cannot frame themselves
        self.assertIn("frameParticipantId == murdererParticipantId", plant_fn)
        self.assertIn('"Invalid frame target"', plant_fn)
        # PlantFake: creates a "Fake" authenticity evidence record
        self.assertIn('"Fake"', plant_fn)
        self.assertIn("self.fakeEvidencePlanted = true", plant_fn)
        # ReframeFake: same culprit guard as PlantFake
        reframe_start = evidence_svc.index("function EvidenceService:ReframeFake(")
        reframe_end = evidence_svc.index("function EvidenceService:Discover(", reframe_start)
        reframe_fn = evidence_svc[reframe_start:reframe_end]
        self.assertIn("murdererParticipantId ~= self.culpritParticipantId", reframe_fn)
        self.assertIn('"Only the Murderer can change the frame target"', reframe_fn)
        # Verify: VerifiedFake or VerifiedReal based on evidence authenticity
        verify_start = evidence_svc.index("function EvidenceService:Verify(")
        verify_end = evidence_svc.index("function EvidenceService:AddNote(", verify_start)
        verify_fn = evidence_svc[verify_start:verify_end]
        self.assertIn('record.authenticity == "Fake"', verify_fn)
        self.assertIn('"VerifiedFake"', verify_fn)
        self.assertIn('"VerifiedReal"', verify_fn)
        self.assertLess(verify_fn.index('"VerifiedFake"'), verify_fn.index('"VerifiedReal"'))
        # Verify records the verifying Detective's ID
        self.assertIn("record.verifiedByParticipantId = detectiveParticipantId", verify_fn)

    def test_request_0110_ghost_protector_intervention_contracts(self) -> None:
        ability_svc = source("Services/RoleAbilityService.lua")
        # SetProtection ghost path: only Protector, only in Investigation, one-time use
        set_protection_start = ability_svc.index("function RoleAbilityService:SetProtection(")
        set_protection_end = ability_svc.index("function RoleAbilityService:SetGuard(", set_protection_start)
        set_protection_fn = ability_svc[set_protection_start:set_protection_end]
        self.assertIn("if protector and protector.isGhost then", set_protection_fn)
        self.assertIn('protector.role ~= "Protector"', set_protection_fn)
        self.assertIn('self.getPhase() ~= "Investigation"', set_protection_fn)
        self.assertIn("self.ghostInterventionUsedByProtectorId[protectorParticipantId]", set_protection_fn)
        self.assertIn('"Ghost intervention is not available"', set_protection_fn)
        # Ghost ward is created with ghostIntervention = true flag
        self.assertIn("ghostIntervention = ghostIntervention,", set_protection_fn)
        self.assertIn("local ghostIntervention = protector.isGhost", set_protection_fn)
        # Ghost intervention uses no ability cooldown (skips _commit)
        self.assertIn("if ghostIntervention then", set_protection_fn)
        self.assertIn("self.revision += 1", set_protection_fn)
        # ResolveDefense: ghost ward marks intervention consumed and still injures healthy target
        resolve_start = ability_svc.index("function RoleAbilityService:ResolveDefense(")
        resolve_end = ability_svc.index("function RoleAbilityService:GetPrivateSnapshot(", resolve_start)
        resolve_fn = ability_svc[resolve_start:resolve_end]
        self.assertIn("if ward.ghostIntervention then", resolve_fn)
        self.assertIn("self.ghostInterventionUsedByProtectorId[ward.protectorParticipantId] = true", resolve_fn)
        # Ghost intervention still injures the target if they were healthy
        self.assertIn("if target.injuryLevel == 0 then", resolve_fn)
        self.assertIn('target.healthState = "Injured"', resolve_fn)
        # Lifecycle event identifies the intervention source
        self.assertIn('"GhostProtectorIntervention"', resolve_fn)
        # Either ward path returns "Blocked"
        self.assertIn('return "Blocked"', resolve_fn)
        # GetPrivateSnapshot: ghostInterventionAvailable reflects used state
        snapshot_start = ability_svc.index("function RoleAbilityService:GetPrivateSnapshot(")
        snapshot_end = ability_svc.index("function RoleAbilityService:TransferParticipant(", snapshot_start)
        snapshot_fn = ability_svc[snapshot_start:snapshot_end]
        self.assertIn(
            "ghostInterventionAvailable = not self.ghostInterventionUsedByProtectorId[participantId],",
            snapshot_fn,
        )


    def test_request_0112_available_actions_per_role_ability_gates(self) -> None:
        runtime = source("Services/GameRuntimeService.lua")
        avail_start = runtime.index("function GameRuntimeService:_availableActions(")
        avail_end = runtime.index("function GameRuntimeService:", avail_start + 1)
        avail_block = runtime[avail_start:avail_end]
        # SetMurderPlan: Murderer only, MurderPlanning phase, abilityUses gate
        self.assertIn('participant.role == "Murderer"', avail_block)
        self.assertIn('self.phase == "MurderPlanning"', avail_block)
        self.assertIn('participant.abilityUses["monster-transformation"] or 0) < 1', avail_block)
        # UseMonsterAbility: Murderer only, Investigation phase
        use_monster_start = avail_block.index('name == "UseMonsterAbility"')
        use_monster_end = avail_block.index('name == "UseRoleAbility"', use_monster_start)
        use_monster_block = avail_block[use_monster_start:use_monster_end]
        self.assertIn('participant.role == "Murderer"', use_monster_block)
        self.assertIn('self.phase == "Investigation"', use_monster_block)
        # UseRoleAbility: Murderer enabled only in MurderPlanning
        role_ability_start = avail_block.index('name == "UseRoleAbility"')
        role_ability_end = avail_block.index('name == "VerifyEvidence"', role_ability_start)
        role_ability_block = avail_block[role_ability_start:role_ability_end]
        self.assertIn('elseif participant.role == "Murderer" then', role_ability_block)
        self.assertIn('enabled = active and self.phase == "MurderPlanning"', role_ability_block)
        # UseRoleAbility: Medium enabled in Investigation or Campfire
        self.assertIn('elseif participant.role == "Medium" then', role_ability_block)
        self.assertIn(
            'self.phase == "Investigation" or self.phase == "Campfire"',
            role_ability_block,
        )
        # UseRoleAbility: ghost Protector enabled Investigation-only with no active check
        ghost_protector_idx = role_ability_block.index(
            'elseif participant.role == "Protector" and participant.isGhost then'
        )
        self.assertIn('enabled = self.phase == "Investigation"', role_ability_block[ghost_protector_idx:])
        # Ghost Protector branch appears after Murderer/Medium branches
        self.assertLess(
            role_ability_block.index('participant.role == "Murderer"'),
            ghost_protector_idx,
        )
        self.assertLess(
            role_ability_block.index('participant.role == "Medium"'),
            ghost_protector_idx,
        )
        # UseRoleAbility: Medic/Trapper/Guard/Protector/Detective active in Day or Investigation
        for role in ("Medic", "Trapper", "Guard", "Detective"):
            self.assertIn(f'participant.role == "{role}"', role_ability_block)
        self.assertIn(
            'enabled = active and (self.phase == "Day" or self.phase == "Investigation")',
            role_ability_block,
        )
        # UseRoleAbility: else branch disables for unrecognised roles
        self.assertIn("else", role_ability_block)
        self.assertIn("enabled = false", role_ability_block)
        # VerifyEvidence: Detective only
        verify_start = avail_block.index('name == "VerifyEvidence"')
        verify_block = avail_block[verify_start:]
        self.assertIn('participant.role == "Detective"', verify_block)


    def test_request_0113_bot_actions_role_phase_dispatch(self) -> None:
        runtime = source("Services/GameRuntimeService.lua")
        bot_start = runtime.index("function GameRuntimeService:_GetBotActions(")
        bot_end = runtime.index("function GameRuntimeService:_ExecuteBotAction(", bot_start)
        bot_block = runtime[bot_start:bot_end]
        # Day phase: each support role gets a named action with appropriate abilityId
        day_start = bot_block.index('if phase == "Day" then')
        murder_planning_start = bot_block.index('elseif phase == "MurderPlanning"', day_start)
        day_block = bot_block[day_start:murder_planning_start]
        self.assertIn('participant.role == "Protector"', day_block)
        self.assertIn('"protect-participant"', day_block)
        self.assertIn('participant.role == "Guard"', day_block)
        self.assertIn('"guard-post"', day_block)
        self.assertIn('participant.role == "Trapper"', day_block)
        self.assertIn('"place-warning-trap"', day_block)
        self.assertIn('participant.role == "Detective"', day_block)
        self.assertIn('"analyze-evidence"', day_block)
        self.assertIn('participant.role == "Medic"', day_block)
        self.assertIn('"field-treatment"', day_block)
        # MurderPlanning phase: only Murderer gets the plan action
        investigation_start = bot_block.index('elseif phase == "Investigation"', murder_planning_start)
        planning_block = bot_block[murder_planning_start:investigation_start]
        self.assertIn('participant.role == "Murderer"', planning_block)
        self.assertIn('"role:plan"', planning_block)
        self.assertIn('"monster-transformation"', planning_block)
        # Investigation phase: Murderer gets Attack action toward murder plan victim
        campfire_start = bot_block.index('elseif phase == "Campfire"', investigation_start)
        investigation_block = bot_block[investigation_start:campfire_start]
        self.assertIn('participant.role == "Murderer"', investigation_block)
        self.assertIn('"Attack"', investigation_block)
        self.assertIn("plan.victimParticipantId", investigation_block)
        # Investigation: night role abilities for support roles
        self.assertIn('"role:protect-night"', investigation_block)
        self.assertIn('"role:guard-night"', investigation_block)
        self.assertIn('"role:trap-night"', investigation_block)
        self.assertIn('"role:investigate-night"', investigation_block)
        self.assertIn('"spirit-sense"', investigation_block)
        self.assertIn('"role:treat-night"', investigation_block)
        # Campfire: Murderer frame target gets boosted utility
        campfire_block = bot_block[campfire_start:]
        self.assertIn('participant.role == "Murderer"', campfire_block)
        self.assertIn("self.murderPlan.frameParticipantId", campfire_block)
        self.assertIn("caseUtility = 24", campfire_block)
        # addRoleAction: Detective/Medium have high informationValue; Murderer has zero teamValue
        self.assertIn(
            'if participant.role == "Detective" or participant.role == "Medium"',
            bot_block,
        )
        self.assertIn("then 0.9", bot_block)
        self.assertIn("else 0.2", bot_block)
        self.assertIn('if participant.role == "Murderer" then 0 else 0.85', bot_block)


    def test_request_0121_use_role_ability_gate_and_dispatch(self) -> None:
        runtime = source("Services/GameRuntimeService.lua")
        ability_start = runtime.index("function GameRuntimeService:_useRoleAbility(")
        ability_end = runtime.index("function GameRuntimeService:_handleParticipantAction(")
        ability_block = runtime[ability_start:ability_end]
        # monster-transformation: Murderer-only, MurderPlanning phase, one-use
        self.assertIn('if abilityId == "monster-transformation" then', ability_block)
        self.assertIn(
            'if participant.role ~= "Murderer" or self.phase ~= "MurderPlanning" then',
            ability_block,
        )
        self.assertIn('return actionRejected("Monster planning is not active")', ability_block)
        self.assertIn('return actionRejected("Murder plan is already locked")', ability_block)
        self.assertIn('victim.team ~= "Campers" or not victim.alive', ability_block)
        self.assertIn('return actionRejected("A living Camper victim is required")', ability_block)
        # monster-transformation sets murderPlan with victimParticipantId + monsterId
        self.assertIn("self.murderPlan = {", ability_block)
        self.assertIn("victimParticipantId = victim.participantId,", ability_block)
        self.assertIn("monsterId = monsterId,", ability_block)
        # plant-false-evidence: Murderer-only, MurderPlanning phase, one-use, frame required
        self.assertIn('elseif abilityId == "plant-false-evidence" then', ability_block)
        self.assertIn(
            '"False evidence can only be planned by the Murderer"', ability_block
        )
        self.assertIn('"False evidence was already planned"', ability_block)
        # Camper role ability dispatch: protect, guard, trap, investigate, spirit-sense
        self.assertIn(
            'elseif abilityId == "protect-participant" and targetId then', ability_block
        )
        self.assertIn("self.roleAbilities:SetProtection(", ability_block)
        self.assertIn('elseif abilityId == "guard-post" and targetId then', ability_block)
        self.assertIn("self.roleAbilities:SetGuard(", ability_block)
        self.assertIn('elseif abilityId == "place-warning-trap" then', ability_block)
        self.assertIn("self.roleAbilities:PlaceTrap(", ability_block)
        self.assertIn('elseif abilityId == "analyze-evidence" and targetId then', ability_block)
        self.assertIn("self.roleAbilities:Investigate(", ability_block)
        self.assertIn('elseif abilityId == "spirit-sense" then', ability_block)
        self.assertIn("self.roleAbilities:RequestSpiritSignal(", ability_block)
        # Fallback for unknown/incomplete ability
        self.assertIn(
            '"Ability payload is incomplete or unsupported"', ability_block
        )


    def test_request_0122_handle_participant_action_role_gates(self) -> None:
        runtime = source("Services/GameRuntimeService.lua")
        action_start = runtime.index("function GameRuntimeService:_handleParticipantAction(")
        action_end = runtime.index("function GameRuntimeService:HandleAction(")
        action_block = runtime[action_start:action_end]
        # SetMurderPlan: Murderer-only in MurderPlanning phase
        self.assertIn('if actionName == "SetMurderPlan" then', action_block)
        self.assertIn(
            'if self.phase ~= "MurderPlanning" or participant.role ~= "Murderer" then',
            action_block,
        )
        self.assertIn(
            '"Only the Murderer can plan during the planning phase"', action_block
        )
        # Victim eligibility: alive, not ghost, on Campers team, not the murderer themselves
        self.assertIn("not victim.alive", action_block)
        self.assertIn("victim.isGhost", action_block)
        self.assertIn('victim.team ~= "Campers"', action_block)
        self.assertIn(
            "victim.participantId == participant.participantId", action_block
        )
        self.assertIn('"The selected victim is not eligible"', action_block)
        # Monster and location validated against known lists
        self.assertIn("table.find(MONSTER_ORDER,", action_block)
        self.assertIn('"Unknown monster transformation"', action_block)
        self.assertIn("table.find(SEARCH_LOCATIONS,", action_block)
        self.assertIn('"Unknown murder location"', action_block)
        # Vote: Campfire phase only; accelerates phase end when all votes in
        self.assertIn('if self.phase ~= "Campfire" then', action_block)
        self.assertIn('"Voting is not active"', action_block)
        self.assertIn("self.voting:IsComplete()", action_block)
        self.assertIn("self.phaseEndsAt = math.min(self.phaseEndsAt, now() + 1)", action_block)
        # UseMonsterAbility: Murderer only
        self.assertIn('if participant.role ~= "Murderer" then', action_block)
        self.assertIn('"Only the Murderer controls the monster"', action_block)
        # TransferItem: target must be alive and not ghost
        self.assertIn(
            "not target or not target.alive or target.isGhost", action_block
        )
        self.assertIn('"Transfer target is not eligible"', action_block)
        # Proximity check for item transfers
        self.assertIn("> 12", action_block)
        self.assertIn('"Move closer to the transfer target"', action_block)
        # Fallback for unrecognized actions
        self.assertIn('"Action is handled by another server domain"', action_block)


    def test_request_0124_apply_rewards_role_and_survivor_field_assignments(self) -> None:
        runtime = source("Services/GameRuntimeService.lua")
        rewards_start = runtime.index("function GameRuntimeService:_ApplyRewards(")
        rewards_end = runtime.index("function GameRuntimeService:_GetBotActions(", rewards_start)
        rewards_block = runtime[rewards_start:rewards_end]
        # Only human participants receive rewards
        self.assertIn('participant.controller.kind == "Human"', rewards_block)
        # Spectators do not count as participated
        self.assertIn('participated = participant.role ~= "Spectator",', rewards_block)
        # Won is determined by team matching the winner
        self.assertIn("won = participant.team == winner,", rewards_block)
        # Ghost players do not count as survived
        self.assertIn(
            "survived = participant.alive and not participant.isGhost,", rewards_block
        )
        # Role is forwarded so ProfileService can compute role-specific bonuses
        self.assertIn("roleId = participant.role,", rewards_block)
        # _finishIfEliminated: winner message differs by team; both trigger announce
        elim_start = runtime.index("function GameRuntimeService:_finishIfEliminated(")
        elim_end = runtime.index("function GameRuntimeService:_isNearPart(", elim_start)
        elim_block = runtime[elim_start:elim_end]
        self.assertIn(
            '"The Murderer was stopped before the final accusation."', elim_block
        )
        self.assertIn(
            '"Too few campers remain to contain the hunt."', elim_block
        )
        self.assertIn('if winner == "Campers"', elim_block)
        self.assertIn('self:_announce("Danger",', elim_block)


    def test_request_0125_handle_action_ghost_bypass_and_note_filter(self) -> None:
        runtime = source("Services/GameRuntimeService.lua")
        handle_start = runtime.index("function GameRuntimeService:HandleAction(")
        handle_end = runtime.index("function GameRuntimeService:_ResolveAccusation(")
        handle_block = runtime[handle_start:handle_end]
        # Ghost participants can use role abilities without passing _validateActiveParticipant
        self.assertIn(
            'actionName == "UseRoleAbility"\n\t\tand rawParticipant\n\t\tand rawParticipant.isGhost',
            handle_block,
        )
        self.assertIn("self:_useRoleAbility(rawParticipant, clonePayload(payload))", handle_block)
        # The ghost branch runs _useRoleAbility with rawParticipant (not validated participant)
        ghost_branch_pos = handle_block.index("rawParticipant.isGhost")
        validate_pos = handle_block.index("_validateActiveParticipant")
        # ghost branch check must appear AFTER validation is defined, but bypasses it
        self.assertLess(validate_pos, ghost_branch_pos)
        # AddEvidenceNote: text is filtered and capped at 160 chars before storage
        self.assertIn('actionName == "AddEvidenceNote"', handle_block)
        self.assertIn("TextService:FilterStringAsync(", handle_block)
        self.assertIn("string.sub(rawText, 1, 160)", handle_block)
        self.assertIn("GetNonChatStringForBroadcastAsync()", handle_block)
        self.assertIn('"Evidence note could not be moderated"', handle_block)
        # Non-ghost path requires a validated participant; actions broadcast on acceptance
        self.assertIn('"Player cannot act"', handle_block)
        self.assertIn("self:Broadcast()", handle_block)


    def test_request_0126_voting_resolve_tie_break_and_outcome_copy(self) -> None:
        voting = source("Services/VotingService.lua")
        resolve_start = voting.index("function VotingService:Resolve(culpritParticipantId: string)")
        resolve_end = voting.index("function VotingService:EvaluateEliminationVictory(")
        resolve_block = voting[resolve_start:resolve_end]
        # Tie: accusedParticipantId set to nil → Murderer wins by default
        self.assertIn("if tied then", resolve_block)
        self.assertIn("accusedParticipantId = nil", resolve_block)
        # Winner is binary: correct accusation = Campers, anything else = Murderer
        self.assertIn('winner = if correct then "Campers" else "Murderer"', resolve_block)
        # Four outcome reason messages cover all vote results
        self.assertIn('"The camp correctly exposed the Murderer."', resolve_block)
        self.assertIn('"The accusation tied, allowing the Murderer to escape."', resolve_block)
        self.assertIn('"The camp reached no verdict."', resolve_block)
        self.assertIn('"The camp accused the wrong participant."', resolve_block)
        # Correct is compared to culprit, not just any vote target
        self.assertIn("local correct = accusedParticipantId == culpritParticipantId", resolve_block)
        # Resolution is cached after first call
        self.assertIn("if self.resolution then", resolve_block)
        self.assertIn("self.resolution = resolution", resolve_block)
        # EvaluateEliminationVictory: culprit dead → instant Campers win
        elim_start = voting.index("function VotingService:EvaluateEliminationVictory(")
        elim_end = voting.index("function VotingService:TransferParticipant(")
        elim_block = voting[elim_start:elim_end]
        self.assertIn("if not culprit or not culprit.alive then", elim_block)
        self.assertIn('return "Campers"', elim_block)
        # Living campers threshold: 1 or fewer remaining → Murderer wins
        self.assertIn(
            "participant.team == \"Campers\" and participant.alive and not participant.isGhost",
            elim_block,
        )
        self.assertIn('return if livingCampers <= 1 then "Murderer" else nil', elim_block)


    def test_request_0127_guard_trap_spirit_sense_role_gates(self) -> None:
        ability_svc = source("Services/RoleAbilityService.lua")
        # SetGuard: target must be a living non-ghost Camper, not the guard themselves
        guard_start = ability_svc.index("function RoleAbilityService:SetGuard(")
        guard_end = ability_svc.index("function RoleAbilityService:PlaceTrap(", guard_start)
        guard_block = ability_svc[guard_start:guard_end]
        self.assertIn(
            "not target or not target.alive or target.isGhost or target.team ~= \"Campers\"",
            guard_block,
        )
        self.assertIn('"Guard target is not eligible"', guard_block)
        self.assertIn("guard.participantId == target.participantId", guard_block)
        self.assertIn('"Guard must protect another participant"', guard_block)
        # Guard duration: 45 seconds + upgrade bonus
        self.assertIn("expiresAt = self.clock()", guard_block)
        self.assertIn('+ self.getUpgradeRank(guardParticipantId, "watchful-post") * 3,', guard_block)
        # PlaceTrap: location must be non-empty and under 80 chars
        trap_start = ability_svc.index("function RoleAbilityService:PlaceTrap(")
        trap_end = ability_svc.index("function RoleAbilityService:TriggerTrap(", trap_start)
        trap_block = ability_svc[trap_start:trap_end]
        self.assertIn('locationId == "" or #locationId > 80', trap_block)
        self.assertIn('"Trap location is invalid"', trap_block)
        # Trap ID is round-scoped and sequential
        self.assertIn(
            'string.format("trap:%d:%d", self.roundId, self.nextTrapNumber)', trap_block
        )
        # RequestSpiritSignal: only works when at least one ghost is present
        spirit_start = ability_svc.index("function RoleAbilityService:RequestSpiritSignal(")
        spirit_end = ability_svc.index("function RoleAbilityService:AuthorizeTreatment(")
        spirit_block = ability_svc[spirit_start:spirit_end]
        self.assertIn('{ "Investigation", "Campfire" }', spirit_block)
        self.assertIn("if ghostCount == 0 then", spirit_block)
        self.assertIn('"No ghost is able to answer"', spirit_block)
        # Three deterministic signal strings cycling by round + ghost count
        self.assertIn('"THE THREAT WALKED AMONG THE CAMP BEFORE NIGHT."', spirit_block)
        self.assertIn('"ONE SHARED CLUE MAY HAVE BEEN PLANTED."', spirit_block)
        self.assertIn('"THE ATTACKER FAVORED AN ISOLATED TARGET."', spirit_block)


    def test_request_0128_combat_attack_outcomes_and_heal_gates(self) -> None:
        combat = source("Services/CombatService.lua")
        attack_start = combat.index("function CombatService:ApplyAttack(request: AttackRequest)")
        attack_end = combat.index("function CombatService:Heal(")
        attack_block = combat[attack_start:attack_end]
        # Phase gate: Investigation only
        self.assertIn('self.getPhase() ~= "Investigation"', attack_block)
        self.assertIn('"Attacks are not active"', attack_block)
        # Stale round rejected
        self.assertIn("request.roundId ~= self.roundId", attack_block)
        self.assertIn('"Stale or unknown round"', attack_block)
        # Self-attack rejected
        self.assertIn("attacker.participantId == target.participantId", attack_block)
        self.assertIn('"A participant cannot attack itself"', attack_block)
        # Three outcomes
        self.assertIn('outcome = "Blocked"', attack_block)
        self.assertIn('outcome = "Eliminated"', attack_block)
        self.assertIn('outcome = "Injured"', attack_block)
        # Blocked: lowest evidence risk (attack was interrupted)
        self.assertIn("evidenceRisk = 0.8", attack_block)
        # Reduced defense raises evidence risk vs full attack
        self.assertIn('if defense == "Reduced" then 0.9 else 0.65', attack_block)
        # Heal: ghost participants cannot heal or be healed; can't self-heal
        heal_start = combat.index("function CombatService:Heal(")
        heal_end = combat.index("function CombatService:GetSnapshot(", heal_start)
        heal_block = combat[heal_start:heal_end]
        self.assertIn("healer.isGhost", heal_block)
        self.assertIn("target.isGhost", heal_block)
        self.assertIn("healer.participantId == target.participantId", heal_block)
        self.assertIn('"Healing participants are not eligible"', heal_block)
        # Target must be in Injured state (not healthy or dead)
        self.assertIn('target.injuryLevel ~= 1 or target.healthState ~= "Injured"', heal_block)
        self.assertIn('"Target is not injured"', heal_block)
        # Skill challenge must succeed
        self.assertIn("if not skillChallengeSucceeded then", heal_block)
        self.assertIn('"Skill challenge failed"', heal_block)
        # Successful heal fully restores target
        self.assertIn("target.injuryLevel = 0", heal_block)
        self.assertIn('target.healthState = "Healthy"', heal_block)
        self.assertIn("target.health = target.maxHealth", heal_block)


    def test_request_0129_get_game_state_murderer_only_private_fields(self) -> None:
        runtime = source("Services/GameRuntimeService.lua")
        state_start = runtime.index("function GameRuntimeService:GetGameState(player: Player)")
        state_end = runtime.index("function GameRuntimeService:Broadcast()", state_start)
        state_block = runtime[state_start:state_end]
        # privateMonster: only Murderer sees the private monster snapshot
        self.assertIn(
            'if participant and participant.role == "Murderer"\n\t\tthen self.monster:GetPrivateSnapshot()',
            state_block,
        )
        self.assertIn("else nil", state_block)
        self.assertIn("privateMonster = privateMonster,", state_block)
        # murderPlan: only Murderer receives the murder plan
        self.assertIn(
            'if participant and participant.role == "Murderer"\n\t\t\tthen self.murderPlan',
            state_block,
        )
        self.assertIn("murderPlan = ", state_block)
        # availableActions is always computed per-participant (role-aware)
        self.assertIn("availableActions = self:_availableActions(participant),", state_block)
        # GetRoundSnapshot: votes revealed only after Resolution/Rewards phases
        snapshot_start = runtime.index("function GameRuntimeService:GetRoundSnapshot()")
        snapshot_end = runtime.index("function GameRuntimeService:_availableActions(", snapshot_start)
        snapshot_block = runtime[snapshot_start:snapshot_end]
        self.assertIn(
            'local revealVotes = self.phase == "Resolution" or self.phase == "Rewards"',
            snapshot_block,
        )
        self.assertIn("votes = if revealVotes then voteSnapshot.votes else nil,", snapshot_block)
        self.assertIn(
            "culpritId = if revealVotes then self.culpritParticipantId else nil,", snapshot_block
        )
        self.assertIn(
            "monsterId = if revealVotes and self.murderPlan", snapshot_block
        )


    def test_request_0130_begin_round_culprit_victim_frame_and_monster_cycling(self) -> None:
        runtime = source("Services/GameRuntimeService.lua")
        # _findCulprit: finds the Murderer, errors hard if roster has no Murderer
        culprit_start = runtime.index("function GameRuntimeService:_findCulprit()")
        culprit_end = runtime.index("function GameRuntimeService:_defaultFrameTarget(")
        culprit_block = runtime[culprit_start:culprit_end]
        self.assertIn('if participant.role == "Murderer" then', culprit_block)
        self.assertIn('"Role assignment did not produce a Murderer"', culprit_block)
        # _defaultFrameTarget: first non-culprit Camper becomes the framing candidate
        frame_start = runtime.index("function GameRuntimeService:_defaultFrameTarget(")
        frame_end = runtime.index("function GameRuntimeService:_defaultVictim(")
        frame_block = runtime[frame_start:frame_end]
        self.assertIn("participant.participantId ~= culpritId", frame_block)
        self.assertIn('participant.team == "Campers"', frame_block)
        # _defaultVictim: living non-culprit Campers, round-indexed
        victim_start = runtime.index("function GameRuntimeService:_defaultVictim(")
        victim_end = runtime.index("function GameRuntimeService:_grantLoadout(")
        victim_block = runtime[victim_start:victim_end]
        self.assertIn("participant.participantId ~= culpritId", victim_block)
        self.assertIn('participant.team == "Campers"', victim_block)
        self.assertIn("participant.alive", victim_block)
        self.assertIn('"Round needs at least one Camper target"', victim_block)
        # Cycles deterministically by round: (roundId - 1) % #candidates + 1
        self.assertIn(
            "candidates[((self.roundId - 1) % #candidates) + 1]", victim_block
        )
        # BeginRound: monster selected via MONSTER_ORDER modulo roundId
        begin_start = runtime.index("function GameRuntimeService:BeginRound(")
        begin_end = runtime.index("function GameRuntimeService:EnterPhase(", begin_start)
        begin_block = runtime[begin_start:begin_end]
        self.assertIn(
            "MONSTER_ORDER[((roundId - 1) % #MONSTER_ORDER) + 1]", begin_block
        )
        # Initial murderPlan set from default victim/frame before player action
        self.assertIn("self.murderPlan = {", begin_block)
        self.assertIn('victimParticipantId = self:_defaultVictim(', begin_block)
        self.assertIn('frameParticipantId = frameTarget,', begin_block)
        # Round begins with RoleReveal phase
        self.assertIn('self:EnterPhase("RoleReveal")', begin_block)


    def test_request_0131_mystery_clue_generation_and_begin_round_invariants(
        self,
    ) -> None:
        mystery = source("Services/MysteryService.lua")

        # Constants
        self.assertIn("CULPRIT_CLUE_COUNT = 3", mystery)
        self.assertIn("PLANTED_CLUE_COUNT = 2", mystery)
        self.assertIn("MONSTER_CLUE_COUNT = 3", mystery)
        self.assertIn("WITNESS_ACCOUNT_COUNT = 4", mystery)

        # BeginRound guards: culprit must be in suspectIds
        self.assertIn(
            '"culpritParticipantId must be in suspectIds"', mystery
        )
        # Frame target cannot equal the culprit
        self.assertIn('"frame target cannot be the culprit"', mystery)
        # Frame target must also be a suspect
        self.assertIn('"frameTargetId must be in suspectIds"', mystery)

        # buildAuthenticCandidateSet: always seeds with culprit first
        auth_fn_start = mystery.index("local function buildAuthenticCandidateSet(")
        auth_fn_end = mystery.index("\nend\n", auth_fn_start)
        auth_fn = mystery[auth_fn_start:auth_fn_end]
        self.assertIn("local candidates: { string } = { culpritParticipantId }", auth_fn)
        self.assertIn("if suspectId ~= culpritParticipantId then", auth_fn)

        # buildPlantedCandidateSet: excludes both culprit and frameTarget from decoys
        plant_fn_start = mystery.index("local function buildPlantedCandidateSet(")
        plant_fn_end = mystery.index("\nend\n", plant_fn_start)
        plant_fn = mystery[plant_fn_start:plant_fn_end]
        self.assertIn(
            "if suspectId ~= culpritParticipantId and suspectId ~= frameTargetId then",
            plant_fn,
        )
        # Planted set always seeds with frameTargetId as the primary suspect
        self.assertIn("local candidates: { string } = { frameTargetId }", plant_fn)

        # Culprit clues use shuffled culpritClues catalog with Authentic authenticity
        begin_start = mystery.index("function MysteryService:BeginRound(")
        begin_end = mystery.index("function MysteryService:GetSearchPlacements(", begin_start)
        begin_block = mystery[begin_start:begin_end]
        self.assertIn(
            "local culpritTemplates = shuffled(MysteryCatalog.culpritClues, random)",
            begin_block,
        )
        self.assertIn('for clueIndex = 1, CULPRIT_CLUE_COUNT do', begin_block)
        self.assertIn('"Authentic",', begin_block)

        # Planted clues use shuffled plantedClues catalog with Planted authenticity
        self.assertIn(
            "local plantedTemplates = shuffled(MysteryCatalog.plantedClues, random)",
            begin_block,
        )
        self.assertIn('for clueIndex = 1, PLANTED_CLUE_COUNT do', begin_block)
        self.assertIn('"Planted",', begin_block)

        # Monster clues: {} suspect candidates, template.monsterCandidates for monsters
        self.assertIn("for clueIndex = 1, MONSTER_CLUE_COUNT do", begin_block)
        self.assertIn("template.monsterCandidates", begin_block)
        self.assertIn(
            "table.find(template.monsterCandidates, request.monsterId)",
            begin_block,
        )

        # Witness accounts: 2 truthful (Authentic, reliability 0.76+), 1 mistaken
        self.assertIn("for accountIndex = 1, 2 do", begin_block)
        self.assertIn("0.76 + random:NextNumber() * 0.18", begin_block)
        self.assertIn('"Mistaken",', begin_block)
        self.assertIn("0.34 + random:NextNumber() * 0.2", begin_block)
        # Mistaken witness uses planted candidate set (frames the frame target)
        self.assertIn(
            "buildPlantedCandidateSet(\n\t\t\trequest.culpritParticipantId,",
            begin_block,
        )
        # Monster witness: no suspect candidates, uses firstMonsterTemplate.monsterCandidates
        self.assertIn("0.65 + random:NextNumber() * 0.2", begin_block)
        self.assertIn("firstMonsterTemplate.monsterCandidates", begin_block)

        # Post-generation deduction invariants
        self.assertIn("local audit = self:AuditDeduction()", begin_block)
        self.assertIn('"Seeded mystery failed the culprit deduction invariant"', begin_block)
        self.assertIn('"Seeded mystery failed the monster deduction invariant"', begin_block)
        self.assertIn('"Seeded mystery requires plausible planted clues"', begin_block)
        self.assertIn('"Seeded mystery requires a conflicting witness"', begin_block)


    def test_request_0132_mystery_discover_interview_transfer_and_audit(
        self,
    ) -> None:
        mystery = source("Services/MysteryService.lua")

        # DiscoverClue: guard conditions, state transition, callback
        disc_start = mystery.index("function MysteryService:DiscoverClue(")
        disc_end = mystery.index("function MysteryService:InterviewCounselor(", disc_start)
        disc_block = mystery[disc_start:disc_end]
        self.assertIn('"BeginRound must be called before clue discovery"', disc_block)
        self.assertIn('"participantId cannot be empty"', disc_block)
        self.assertIn('"Unknown mystery clue"', disc_block)
        self.assertIn('"Mystery clue was already discovered"', disc_block)
        self.assertIn('"Participant cannot discover this clue"', disc_block)
        self.assertIn('clue.discoveryState = "Discovered"', disc_block)
        self.assertIn("clue.discoveredByParticipantId = participantId", disc_block)
        self.assertIn("clue.discoveredAt = now", disc_block)
        # Discovered clue fires onClueDiscovered callback via toPublicClue
        self.assertIn("local publicClue = toPublicClue(clue)", disc_block)
        self.assertIn("self.callbacks.onClueDiscovered", disc_block)

        # InterviewCounselor: guard, already-revealed short-circuit, state, callback
        intv_start = mystery.index("function MysteryService:InterviewCounselor(")
        intv_end = mystery.index("function MysteryService:TransferParticipant(", intv_start)
        intv_block = mystery[intv_start:intv_end]
        self.assertIn(
            '"BeginRound must be called before witness interviews"', intv_block
        )
        self.assertIn('"Counselor has no account for this mystery"', intv_block)
        # Already-revealed: returns public account without mutating again
        self.assertIn("if account.revealed then", intv_block)
        self.assertIn("return toPublicWitnessAccount(account), nil", intv_block)
        self.assertIn('"Participant cannot interview this counselor"', intv_block)
        self.assertIn("account.revealed = true", intv_block)
        self.assertIn("account.interviewedByParticipantId = participantId", intv_block)
        self.assertIn("account.revealedAt = now", intv_block)
        self.assertIn("self.callbacks.onWitnessRevealed", intv_block)

        # TransferParticipant: rewires every reference to previousParticipantId
        xfer_start = mystery.index("function MysteryService:TransferParticipant(")
        xfer_end = mystery.index("function MysteryService:AuditDeduction(", xfer_start)
        xfer_block = mystery[xfer_start:xfer_end]
        # Early-exit guards
        self.assertIn("not self.initialized", xfer_block)
        self.assertIn('previousParticipantId == ""', xfer_block)
        self.assertIn("previousParticipantId == replacementParticipantId", xfer_block)
        # Rewires culprit and frameTarget
        self.assertIn(
            "self.culpritParticipantId = replacementParticipantId", xfer_block
        )
        self.assertIn("self.frameTargetId = replacementParticipantId", xfer_block)
        # Rewires suspectIds, clue.suspectCandidateIds, discoveredBy, account candidates
        self.assertIn("self.suspectIds[index] = replacementParticipantId", xfer_block)
        self.assertIn(
            "clue.suspectCandidateIds[index] = replacementParticipantId", xfer_block
        )
        self.assertIn(
            "clue.discoveredByParticipantId = replacementParticipantId", xfer_block
        )
        self.assertIn(
            "account.suspectCandidateIds[index] = replacementParticipantId", xfer_block
        )
        self.assertIn(
            "account.interviewedByParticipantId = replacementParticipantId", xfer_block
        )
        # _mutated only when something actually changed
        self.assertIn("if changed then", xfer_block)
        self.assertIn("self:_mutated()", xfer_block)
        self.assertIn("return changed", xfer_block)

        # AuditDeduction: culprit/monster intersection, planted + conflicting counts
        audit_start = mystery.index("function MysteryService:AuditDeduction(")
        audit_end = mystery.index("function MysteryService:IsSolved(", audit_start)
        audit_block = mystery[audit_start:audit_end]
        self.assertIn('clue.authenticity == "Planted"', audit_block)
        self.assertIn('clue.authenticity == "Authentic" and clue.channel == "Culprit"', audit_block)
        self.assertIn('clue.authenticity == "Authentic" and clue.channel == "Monster"', audit_block)
        self.assertIn('account.authenticity == "Mistaken"', audit_block)
        self.assertIn("conflictingWitnessCount += 1", audit_block)
        # isCulpritDeducible: exactly one intersection member matching the culprit
        self.assertIn(
            "isCulpritDeducible = #culpritIntersection == 1", audit_block
        )
        self.assertIn(
            "and culpritIntersection[1] == self.culpritParticipantId,", audit_block
        )
        # isMonsterDeducible: exactly one intersection member matching the monster
        self.assertIn("isMonsterDeducible = #monsterIntersection == 1", audit_block)
        self.assertIn(
            "and monsterIntersection[1] == self.monsterId,", audit_block
        )

        # IsSolved: exact match on accused + optional monster check
        solved_start = mystery.index("function MysteryService:IsSolved(")
        solved_end = mystery.index("\nreturn MysteryService", solved_start)
        solved_block = mystery[solved_start:solved_end]
        self.assertIn(
            "return accusedParticipantId == self.culpritParticipantId", solved_block
        )
        self.assertIn(
            "and (identifiedMonsterId == nil or identifiedMonsterId == self.monsterId)",
            solved_block,
        )


    def test_request_0133_counselor_threat_flee_hide_dialogue_and_observation_routing(
        self,
    ) -> None:
        counselor = source("Services/CounselorService.lua")

        # Constants
        self.assertIn("DIALOGUE_COOLDOWN_SECONDS = 1.5", counselor)
        self.assertIn("MAX_MEMORIES_PER_COUNSELOR = 12", counselor)

        # FIXED_WITNESS_STATEMENTS built from all three witness account collections
        self.assertIn("MysteryCatalog.truthfulWitnessAccounts,", counselor)
        self.assertIn("MysteryCatalog.mistakenWitnessAccounts,", counselor)
        self.assertIn("MysteryCatalog.monsterWitnessAccounts,", counselor)
        self.assertIn("table.freeze(FIXED_WITNESS_STATEMENTS)", counselor)

        # interactionAllowed rejects Fleeing, Hiding, Unavailable behaviors
        interact_start = counselor.index("local function interactionAllowed(")
        interact_end = counselor.index("\nend\n", interact_start)
        interact_fn = counselor[interact_start:interact_end]
        self.assertIn('state.behavior ~= "Fleeing"', interact_fn)
        self.assertIn('state.behavior ~= "Hiding"', interact_fn)
        self.assertIn('state.behavior ~= "Unavailable"', interact_fn)

        # baseBehavior priority: Suspect > Witness > Routine
        base_start = counselor.index("local function baseBehavior(")
        base_end = counselor.index("\nend\n", base_start)
        base_fn = counselor[base_start:base_end]
        self.assertIn("if state.isSuspect then", base_fn)
        self.assertIn('return "Suspect"', base_fn)
        self.assertIn("elseif state.isWitness then", base_fn)
        self.assertIn('return "Witness"', base_fn)
        self.assertIn('return "Routine"', base_fn)

        # RecordObservation: importance >= 0.65 sets isWitness; behavior = Witness unless threat/suspect
        obs_start = counselor.index("function CounselorService:RecordObservation(")
        obs_end = counselor.index("function CounselorService:AssignWitnessAccount(", obs_start)
        obs_block = counselor[obs_start:obs_end]
        self.assertIn('"Observation summary must be between 1 and 240 characters"', obs_block)
        self.assertIn(
            '"Observation confidence and importance must be between 0 and 1"', obs_block
        )
        self.assertIn("if observation.importance >= 0.65 then", obs_block)
        self.assertIn("state.isWitness = true", obs_block)
        self.assertIn("if not state.threatActive and not state.isSuspect then", obs_block)
        self.assertIn('state.behavior = "Witness"', obs_block)

        # ReportThreat: bravery >= severity * 0.82 → Fleeing, else Hiding
        # severity >= 0.8 affects all counselors regardless of location
        threat_start = counselor.index("function CounselorService:ReportThreat(")
        threat_end = counselor.index("function CounselorService:ArriveAtDestination(", threat_start)
        threat_block = counselor[threat_start:threat_end]
        self.assertIn('"Threat location cannot be empty"', threat_block)
        self.assertIn(
            "state.locationId == threat.locationId or threat.severity >= 0.8", threat_block
        )
        self.assertIn("local shouldFlee = definition.bravery >= threat.severity * 0.82", threat_block)
        self.assertIn("then definition.fleeLocationIds", threat_block)
        self.assertIn("else definition.hideLocationIds", threat_block)
        self.assertIn('then "Fleeing"', threat_block)
        self.assertIn('else "Hiding"', threat_block)
        self.assertIn("state.threatActive = true", threat_block)

        # ArriveAtDestination: Fleeing counselor → Alert; Hiding counselor stays Hiding
        arrive_start = counselor.index("function CounselorService:ArriveAtDestination(")
        arrive_end = counselor.index("function CounselorService:ClearThreat(", arrive_start)
        arrive_block = counselor[arrive_start:arrive_end]
        self.assertIn('"Counselor has no active destination"', arrive_block)
        self.assertIn("state.locationId = destinationId", arrive_block)
        self.assertIn('if state.behavior == "Fleeing" then', arrive_block)
        self.assertIn('state.behavior = "Alert"', arrive_block)
        self.assertIn('"Monitoring the safe route for evacuees"', arrive_block)
        self.assertIn('"Sheltering until the route is clear"', arrive_block)

        # ClearThreat: resets threatActive + destinationId; only mutates when cleared > 0
        clear_start = counselor.index("function CounselorService:ClearThreat(")
        clear_end = counselor.index("function CounselorService:RequestDialogue(", clear_start)
        clear_block = counselor[clear_start:clear_end]
        self.assertIn("state.threatActive = false", clear_block)
        self.assertIn("state.destinationId = nil", clear_block)
        self.assertIn("if cleared > 0 then", clear_block)
        self.assertIn("return cleared", clear_block)

        # RequestDialogue: unknown topic gate, Fleeing/Hiding gate, cooldown gate
        dial_start = counselor.index("function CounselorService:RequestDialogue(")
        dial_end = counselor.index("function CounselorService:EndRound(", dial_start)
        dial_block = counselor[dial_start:dial_end]
        self.assertIn('"Unsupported dialogue topic"', dial_block)
        self.assertIn('"Counselor cannot talk while fleeing or hiding"', dial_block)
        self.assertIn('"Participant is not allowed to interact with this counselor"', dial_block)
        self.assertIn('"Dialogue request is on cooldown"', dial_block)
        self.assertIn("now - lastDialogueAt < DIALOGUE_COOLDOWN_SECONDS", dial_block)
        # Observation topic with witnessStatement bypasses dialogue lines lookup
        self.assertIn('if topic == "Observation" and state.witnessStatement then', dial_block)
        self.assertIn("text = state.witnessStatement", dial_block)
        # Non-Observation topics use stable round-seed + hash + count index
        self.assertIn("self.roundSeed", dial_block)
        self.assertIn("hashString(dialogueKey)", dial_block)
        self.assertIn("+ dialogueCount", dial_block)
        self.assertIn("% #lines + 1", dial_block)


    def test_request_0134_evidence_service_baseline_attack_transfer_culprit_and_monster(
        self,
    ) -> None:
        evidence_svc = source("Services/EvidenceService.lua")

        # GenerateBaselineMystery: 3 culprit-weighted + 2 monster-weighted + optional planted
        gen_start = evidence_svc.index("function EvidenceService:GenerateBaselineMystery(")
        gen_end = evidence_svc.index("function EvidenceService:CreateAttackEvidence(", gen_start)
        gen_block = evidence_svc[gen_start:gen_end]
        # Culprit-weighted clues with weight 0.55
        self.assertIn('"BeginRound must be called before evidence generation"', gen_block)
        self.assertIn("local realWeights = { [culpritId] = 0.55 }", gen_block)
        self.assertIn('"attack-footprint", "Real", realWeights, nil', gen_block)
        self.assertIn('"attack-fabric", "Real", realWeights, nil', gen_block)
        self.assertIn('"witness-conflict", "Ambiguous", realWeights, nil', gen_block)
        # Monster-weighted clues with weight 0.6
        self.assertIn("local monsterWeights = if monsterId then { [monsterId] = 0.6 } else {}", gen_block)
        self.assertIn('"monster-trace", "Real", nil, monsterWeights', gen_block)
        self.assertIn('"device-reading", "Real", nil, monsterWeights', gen_block)
        # Optional planted evidence only when frameParticipantId is not the culprit
        self.assertIn(
            "if frameParticipantId and frameParticipantId ~= culpritId then", gen_block
        )
        self.assertIn('"planted-token", "Fake", { [frameParticipantId] = 0.8 }, nil', gen_block)
        self.assertIn("self.fakeEvidencePlanted = true", gen_block)

        # CreateAttackEvidence: culprit-only gate; lethal or 50% random → attack-blood
        atk_start = evidence_svc.index("function EvidenceService:CreateAttackEvidence(")
        atk_end = evidence_svc.index("function EvidenceService:PlantFake(", atk_start)
        atk_block = evidence_svc[atk_start:atk_end]
        self.assertIn(
            '"Attack evidence must come from culprit"', atk_block
        )
        self.assertIn("attackerParticipantId == self.culpritParticipantId", atk_block)
        # lethal or random>=0.5 selects attack-blood; otherwise attack-footprint
        self.assertIn('"attack-blood"', atk_block)
        self.assertIn('"attack-footprint"', atk_block)
        self.assertIn("lethal or self.random:NextNumber() >= 0.5", atk_block)
        # Culprit weight: 0.75 if lethal, 0.55 otherwise
        self.assertIn("if lethal then 0.75 else 0.55", atk_block)

        # SetMonsterForRound: applies monster weight 0.6 to all Monster-channel records
        monster_start = evidence_svc.index("function EvidenceService:SetMonsterForRound(")
        monster_end = evidence_svc.index("function EvidenceService:TransferCulprit(", monster_start)
        monster_block = evidence_svc[monster_start:monster_end]
        self.assertIn(
            '"BeginRound must be called before changing monster evidence"', monster_block
        )
        self.assertIn('"monsterId cannot be empty"', monster_block)
        self.assertIn('record.channel == "Monster"', monster_block)
        self.assertIn("record.monsterWeights = { [monsterId] = 0.6 }", monster_block)

        # TransferCulprit: early-exit if previous != current culprit; migrates suspectWeights
        xfer_start = evidence_svc.index("function EvidenceService:TransferCulprit(")
        xfer_end = evidence_svc.index("function EvidenceService:ReframeFake(", xfer_start)
        xfer_block = evidence_svc[xfer_start:xfer_end]
        self.assertIn(
            "if self.culpritParticipantId ~= previousParticipantId then", xfer_block
        )
        self.assertIn(
            "self.culpritParticipantId = replacementParticipantId", xfer_block
        )
        # Weight migration: remove old key, assign same weight to new key
        self.assertIn(
            "local weight = record.suspectWeights[previousParticipantId]", xfer_block
        )
        self.assertIn(
            "record.suspectWeights[previousParticipantId] = nil", xfer_block
        )
        self.assertIn(
            "record.suspectWeights[replacementParticipantId] = weight", xfer_block
        )


    def test_request_0135_inventory_service_grant_transfer_drop_and_consume_charge(
        self,
    ) -> None:
        inv = source("Services/InventoryService.lua")

        self.assertIn("DEFAULT_CAPACITY = 15", inv)
        self.assertIn('"Inventory capacity must be positive"', inv)

        # Grant: unknown participant, full inventory, unknown equipment guards
        grant_start = inv.index("function InventoryService:Grant(")
        grant_end = inv.index("function InventoryService:GetOwnedItem(", grant_start)
        grant_block = inv[grant_start:grant_end]
        self.assertIn('"Unknown participant"', grant_block)
        self.assertIn('"Inventory is full"', grant_block)
        self.assertIn('"Unknown equipment"', grant_block)
        # Item instanceId format embeds roundId and item number
        self.assertIn('"item:%d:%d"', grant_block)
        self.assertIn("self.roundId,", grant_block)
        self.assertIn("self.nextItemNumber", grant_block)
        # Charges and durability seeded from rule
        self.assertIn("charges = rule.maxCharges,", grant_block)
        self.assertIn("durability = rule.maxDurability,", grant_block)

        # GetOwnedItem: returns nil if item.ownerParticipantId != participantId
        owned_start = inv.index("function InventoryService:GetOwnedItem(")
        owned_end = inv.index("function InventoryService:GetItemServer(", owned_start)
        owned_block = inv[owned_start:owned_end]
        self.assertIn("item.ownerParticipantId ~= participantId", owned_block)

        # Transfer: guards both inventories + item ownership; capacity check on target
        xfer_start = inv.index("function InventoryService:Transfer(")
        xfer_end = inv.index("function InventoryService:RecoverDropped(", xfer_start)
        xfer_block = inv[xfer_start:xfer_end]
        self.assertIn('"Transfer participants or item are invalid"', xfer_block)
        self.assertIn('"Target inventory is full"', xfer_block)
        self.assertIn('"Item is not in source inventory"', xfer_block)
        self.assertIn("item.ownerParticipantId = toParticipantId", xfer_block)
        self.assertIn("item.equipped = false", xfer_block)

        # RecoverDropped: ownerParticipantId must be nil (item is on ground)
        recover_start = inv.index("function InventoryService:RecoverDropped(")
        recover_end = inv.index("function InventoryService:DropAll(", recover_start)
        recover_block = inv[recover_start:recover_end]
        self.assertIn('"Item is already owned"', recover_block)
        self.assertIn("item.ownerParticipantId ~= nil", recover_block)
        self.assertIn("item.ownerParticipantId = participantId", recover_block)

        # DropAll: clears inventory, sets owner=nil and equipped=false on every item
        drop_start = inv.index("function InventoryService:DropAll(")
        drop_end = inv.index("function InventoryService:ConsumeCharge(", drop_start)
        drop_block = inv[drop_start:drop_end]
        self.assertIn("item.ownerParticipantId = nil", drop_block)
        self.assertIn("item.equipped = false", drop_block)
        self.assertIn("table.clear(inventory)", drop_block)

        # ConsumeCharge: must be equipped; checks charges+durability; cooldown guard
        consume_start = inv.index("function InventoryService:ConsumeCharge(")
        consume_end = inv.index("function InventoryService:GetSnapshot(", consume_start)
        consume_block = inv[consume_start:consume_end]
        self.assertIn('"Item must be owned and equipped"', consume_block)
        self.assertIn('"Item is depleted"', consume_block)
        self.assertIn('"Item is cooling down"', consume_block)
        self.assertIn("item.charges <= 0 or item.durability <= 0", consume_block)
        self.assertIn("now < item.cooldownEndsAt", consume_block)
        self.assertIn("item.charges -= 1", consume_block)
        self.assertIn("item.cooldownEndsAt = now + rule.cooldownSeconds", consume_block)

        # GetDroppedItemIds: items with ownerParticipantId == nil
        self.assertIn("item.ownerParticipantId == nil", inv)


    def test_request_0136_participant_service_reset_round_vote_gate_and_serialize_private(
        self,
    ) -> None:
        participant_svc = (ROOT / "src/server/Services/ParticipantService.lua").read_text(
            encoding="utf-8"
        )

        # resetParticipant: alive = false for Spectator; isGhost always cleared
        reset_start = participant_svc.index("function resetParticipant(")
        reset_end = participant_svc.index("\nend\n", reset_start)
        reset_fn = participant_svc[reset_start:reset_end]
        self.assertIn('state.alive = roleName ~= "Spectator"', reset_fn)
        self.assertIn("state.isGhost = false", reset_fn)
        self.assertIn("state.team = roleDefinition.team", reset_fn)
        self.assertIn('state.healthState = "Healthy"', reset_fn)
        self.assertIn("state.vote = {", reset_fn)
        self.assertIn("hasVoted = false,", reset_fn)

        # ResetRound: 12-participant cap; all first reset to Spectator; then roles assigned
        reset_round_start = participant_svc.index(
            "function ParticipantService:ResetRound("
        )
        reset_round_end = participant_svc.index(
            "function ParticipantService:AddInventoryItem(", reset_round_start
        )
        reset_round_block = participant_svc[reset_round_start:reset_round_end]
        self.assertIn('"A round supports at most 12 participants"', reset_round_block)
        # Fisher-Yates shuffle
        self.assertIn("self.randomSource:NextInteger(1, index)", reset_round_block)
        # All participants reset to Spectator before selective role assignment
        self.assertIn('resetParticipant(state, "Spectator")', reset_round_block)
        # Then selected participants get real roles from RoleCatalog
        self.assertIn("local roles = RoleCatalog.GetDistribution(#selectedIds)", reset_round_block)
        self.assertIn("local roleName = roles[index]", reset_round_block)
        self.assertIn("resetParticipant(state, roleName)", reset_round_block)
        self.assertIn("assignments[participantId] = roleName", reset_round_block)

        # SetVote: ghost and dead participants cannot vote
        vote_start = participant_svc.index("function ParticipantService:SetVote(")
        vote_end = participant_svc.index(
            "function ParticipantService:SerializePublic(", vote_start
        )
        vote_block = participant_svc[vote_start:vote_end]
        self.assertIn("not state.alive or state.isGhost", vote_block)
        self.assertIn("hasVoted = targetParticipantId ~= nil,", vote_block)

        # SerializePrivate: includes role, team, abilityIds from RoleCatalog
        priv_start = participant_svc.index(
            "function ParticipantService:SerializePrivate("
        )
        priv_end = participant_svc.index(
            "function ParticipantService:SerializeAllPublic(", priv_start
        )
        priv_block = participant_svc[priv_start:priv_end]
        self.assertIn("local roleDefinition = RoleCatalog.Get(state.role)", priv_block)
        self.assertIn("role = state.role,", priv_block)
        self.assertIn("roleDisplayName = roleDefinition.displayName,", priv_block)
        self.assertIn("roleDescription = roleDefinition.description,", priv_block)
        self.assertIn("team = state.team,", priv_block)
        self.assertIn("abilityIds = abilityIds,", priv_block)
        self.assertIn("isGhost = state.isGhost,", priv_block)
        self.assertIn("evidenceKnowledge = sortedEvidenceKnowledge(state),", priv_block)
        self.assertIn("inventoryCapacity = MAX_INVENTORY_SLOTS,", priv_block)

        # RecordEvidenceKnowledge: confidence range guard
        rec_start = participant_svc.index(
            "function ParticipantService:RecordEvidenceKnowledge("
        )
        rec_end = participant_svc.index("function ParticipantService:SetVote(", rec_start)
        rec_block = participant_svc[rec_start:rec_end]
        self.assertIn('"Evidence ID cannot be empty"', rec_block)
        self.assertIn(
            '"Evidence confidence must be between 0 and 1"', rec_block
        )
        self.assertIn("knowledge.confidence >= 0 and knowledge.confidence <= 1", rec_block)


    def test_request_0137_monster_service_lifecycle_ability_validation_and_effect_dispatch(
        self,
    ) -> None:
        monster = source("Services/MonsterService.lua")

        # SelectForRound: lifecycle guard + MONSTER_ORDER cycling default
        sel_start = monster.index("function MonsterService:SelectForRound(")
        sel_end = monster.index("function MonsterService:BeginPlanning(", sel_start)
        sel_block = monster[sel_start:sel_end]
        self.assertIn('"Reset or stop the previous monster lifecycle before selecting"', sel_block)
        self.assertIn("self.lifecycle == \"Inactive\" or self.lifecycle == \"Stopped\"", sel_block)
        # Default monster cycles via MONSTER_ORDER modulo roundId
        self.assertIn("((roundId - 1) % #MONSTER_ORDER) + 1", sel_block)
        self.assertIn("MONSTER_ORDER[selectionIndex]", sel_block)
        self.assertIn("self.stamina = monsterRule.maxStamina", sel_block)
        self.assertIn('self.lifecycle = "Selected"', sel_block)

        # SelectPlanningMonster: only valid during Selected or Planning
        plan_start = monster.index("function MonsterService:SelectPlanningMonster(")
        plan_end = monster.index("function MonsterService:_activateLifecycle(", plan_start)
        plan_block = monster[plan_start:plan_end]
        self.assertIn('"Monster choice can only change during planning"', plan_block)
        self.assertIn(
            'self.lifecycle == "Selected" or self.lifecycle == "Planning"', plan_block
        )

        # _activateLifecycle: rejects if not Selected or Planning
        act_start = monster.index("function MonsterService:_activateLifecycle(")
        act_end = monster.index("function MonsterService:_validateActivation(", act_start)
        act_block = monster[act_start:act_end]
        self.assertIn('"Monster can only activate after selection or planning"', act_block)
        self.assertIn('self.lifecycle = "Active"', act_block)

        # _validateActivation: ordered rejection gates
        val_start = monster.index("function MonsterService:_validateActivation(")
        val_end = monster.index("function MonsterService:CanActivate(", val_start)
        val_block = monster[val_start:val_end]
        self.assertIn('"Request fields are invalid"', val_block)
        self.assertIn('"Monster is not active"', val_block)
        self.assertIn('"Round does not match"', val_block)
        self.assertIn('"Participant does not own the monster"', val_block)
        self.assertIn('"Request sequence is stale"', val_block)
        self.assertIn('"Monster is not selected"', val_block)
        self.assertIn('"Ability is not valid for this monster"', val_block)
        self.assertIn('"Ability is not allowed in this phase"', val_block)
        self.assertIn('"Ability is cooling down"', val_block)
        self.assertIn('"Not enough stamina"', val_block)
        self.assertIn('"Monster position is unavailable"', val_block)
        self.assertIn('"A different participant target is required"', val_block)
        self.assertIn('"Target is not eligible"', val_block)
        self.assertIn('"Target is out of range"', val_block)
        self.assertIn('"Line of sight is blocked"', val_block)
        self.assertIn("self.stamina < rule.staminaCost", val_block)
        self.assertIn(
            "(resolvedTargetPosition - sourcePosition).Magnitude > rule.rangeStuds", val_block
        )

        # _activateAbility: deducts stamina, assigns cooldown, bumps lastRequestSequence
        activate_start = monster.index("function MonsterService:_activateAbility(")
        activate_end = monster.index("function MonsterService:Activate(", activate_start)
        activate_block = monster[activate_start:activate_end]
        self.assertIn("self.lastRequestSequence = request.requestSequence", activate_block)
        self.assertIn("self.stamina -= validated.rule.staminaCost", activate_block)
        self.assertIn(
            "local cooldownEndsAt = validated.now + validated.rule.cooldownSeconds",
            activate_block,
        )
        self.assertIn("self.cooldownEndsAt[validated.rule.id] = cooldownEndsAt", activate_block)

        # _applyEffect: dispatches 4 effect kinds
        effect_start = monster.index("function MonsterService:_applyEffect(")
        effect_end = monster.index("function MonsterService:_activateAbility(", effect_start)
        effect_block = monster[effect_start:effect_end]
        self.assertIn('if effect.kind == "Attack" then', effect_block)
        self.assertIn('self.callbacks.applyAttack(', effect_block)
        self.assertIn('elseif effect.kind == "Status" then', effect_block)
        self.assertIn('self.callbacks.applyStatus(', effect_block)
        self.assertIn('elseif effect.kind == "Evidence" then', effect_block)
        self.assertIn('self.callbacks.emitEvidence(', effect_block)
        self.assertIn('elseif effect.kind == "Mobility" then', effect_block)
        self.assertIn('self.callbacks.applyMobility(', effect_block)

        # TransferControl: resets lastRequestSequence to prevent replay attacks
        xfer_start = monster.index("function MonsterService:TransferControl(")
        xfer_end = monster.index("function MonsterService:Reset(", xfer_start)
        xfer_block = monster[xfer_start:xfer_end]
        self.assertIn('"Transfer roundId does not match active round"', xfer_block)
        self.assertIn('"No monster lifecycle is available to transfer"', xfer_block)
        self.assertIn("self.participantId = participantId", xfer_block)
        self.assertIn("self.lastRequestSequence = 0", xfer_block)


if __name__ == "__main__":
    unittest.main(verbosity=2)
