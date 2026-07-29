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
        # Attack outcomes include the expanded injury ladder.
        self.assertIn('outcome = "Blocked"', attack_block)
        self.assertIn('outcome = "Eliminated"', attack_block)
        self.assertIn("local outcome: AttackOutcome", attack_block)
        self.assertIn('applyResult == "Critical"', attack_block)
        self.assertIn('then "Critical"', attack_block)
        self.assertIn('applyResult == "Incapacitated"', attack_block)
        self.assertIn('then "Incapacitated"', attack_block)
        self.assertIn('else "Injured"', attack_block)
        self.assertIn("outcome = outcome", attack_block)
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


    def test_request_0138_bot_memory_eviction_observe_relationship_and_lie_target(
        self,
    ) -> None:
        bot = (ROOT / "src/server/Services/ComputerPlayerService.lua").read_text(
            encoding="utf-8"
        )

        # Remember: memory eviction removes entry with lowest value formula
        remember_start = bot.index("function ComputerPlayerService:Remember(")
        remember_end = bot.index("function ComputerPlayerService:GetMemories(", remember_start)
        remember_block = bot[remember_start:remember_end]
        self.assertIn('"Bot memory ID cannot be empty"', remember_block)
        self.assertIn('"Memory confidence must be 0-1"', remember_block)
        self.assertIn('"Memory importance must be 0-1"', remember_block)
        # Existing memory is replaced by ID match
        self.assertIn("existing.id == memory.id", remember_block)
        # Eviction: while memories exceed limit, remove weakest
        self.assertIn("while #runtime.memories > tuning.memoryLimit do", remember_block)
        self.assertIn(
            "local value = candidate.importance * candidate.confidence - age * 0.0001",
            remember_block,
        )

        # GetMemories: excludes expired entries
        get_start = bot.index("function ComputerPlayerService:GetMemories(")
        get_end = bot.index("function ComputerPlayerService:ForgetExpiredMemories(", get_start)
        get_block = bot[get_start:get_end]
        self.assertIn("not memory.expiresAt or memory.expiresAt > now", get_block)

        # ObserveForBot: truncates summary, generates composite memoryId, adjusts relationships
        obs_start = bot.index("function ComputerPlayerService:ObserveForBot(")
        obs_end = bot.index("function ComputerPlayerService:BroadcastObservation(", obs_start)
        obs_block = bot[obs_start:obs_end]
        self.assertIn("summary == \"\"", obs_block)
        self.assertIn("local safeSummary = string.sub(summary, 1, 200)", obs_block)
        self.assertIn("round:%d:%s:%d:%d:%s", obs_block)
        # Evidence/Injury/RoleHint: suspicion += confidence * importance * 0.15; trust -= suspicion * 0.35
        self.assertIn(
            'kind == "Evidence" or kind == "Injury" or kind == "RoleHint"', obs_block
        )
        self.assertIn(
            "suspicionDelta = clampUnit(confidence) * clampUnit(importance) * 0.15", obs_block
        )
        self.assertIn("trustDelta = -suspicionDelta * 0.35", obs_block)
        # Statement: small positive trust bump
        self.assertIn('elseif kind == "Statement" then', obs_block)
        self.assertIn("trustDelta = clampUnit(confidence) * 0.04", obs_block)

        # AdjustRelationship: clamps trust and suspicion to [0, 1]
        adj_start = bot.index("function ComputerPlayerService:AdjustRelationship(")
        adj_end = bot.index("function ComputerPlayerService:ObserveForBot(", adj_start)
        adj_block = bot[adj_start:adj_end]
        self.assertIn("relationship.trust = clampUnit(relationship.trust + trustDelta)", adj_block)
        self.assertIn(
            "relationship.suspicion = clampUnit(relationship.suspicion + suspicionDelta)",
            adj_block,
        )

        # BuildMurdererLieTarget: only Murderer role; value = suspicion - trust * 0.25
        lie_start = bot.index("function ComputerPlayerService:BuildMurdererLieTarget(")
        lie_end = bot.index("function ComputerPlayerService:ScoreAction(", lie_start)
        lie_block = bot[lie_start:lie_end]
        self.assertIn('participant.role ~= "Murderer"', lie_block)
        self.assertIn("other.alive and other.role ~= \"Murderer\"", lie_block)
        self.assertIn("local value = relationship.suspicion - relationship.trust * 0.25", lie_block)

        # ScoreAction: ghost Protector UseRoleAbility is the only ghost action allowed
        score_start = bot.index("function ComputerPlayerService:ScoreAction(")
        score_end = bot.index("function ComputerPlayerService:ChooseAction(", score_start)
        score_block = bot[score_start:score_end]
        self.assertIn(
            'participant.isGhost\n\t\t\tand participant.role == "Protector"', score_block
        )
        self.assertIn('candidate.actionType == "UseRoleAbility"', score_block)
        # Vote scoring: relationship suspicion and memories about target
        self.assertIn("relationship.suspicion * 30 - relationship.trust * 12", score_block)
        self.assertIn("memory.subjectParticipantId == targetId", score_block)
        # Noise injection: (1 - decisionQuality) * 20
        self.assertIn("local noiseRange = (1 - tuning.decisionQuality) * 20", score_block)


    def test_request_0139_nametags_view_dot_priority_dead_ghost_name_color_and_visible_phases(
        self,
    ) -> None:
        nametags = (ROOT / "src/client/UI/NametagsView.lua").read_text(encoding="utf-8")

        # VISIBLE_PHASES: only Day, Investigation, Campfire show nametags
        for phase in ("Day", "Investigation", "Campfire"):
            self.assertIn(f"{phase} = true", nametags)
        # Non-visible phases disable all billboards
        self.assertIn("entry.billboard.Enabled = false", nametags)

        # Bot participants are skipped (no nametag)
        self.assertIn('readBoolean(participant, "isBot", false)', nametags)

        # dead = not alive AND not isGhost (distinguishes dead from ghost)
        self.assertIn("local dead = not alive and not isGhost", nametags)

        # Dot color priority: ghost → Danger (injured/critical) → TextMuted (dead) → Success
        update_start = nametags.index("function NametagsView:Update(")
        update_end = nametags.index("function NametagsView:Destroy(", update_start)
        update_block = nametags[update_start:update_end]
        dot_start = update_block.index(
            "entry.dot.BackgroundColor3 = if isGhost"
        )
        dot_end = update_block.index(
            "if localRole == \"Murderer\"", dot_start
        )
        dot_block = update_block[dot_start:dot_end]
        # Ghost is first check
        self.assertIn("then Theme.Colors.Ghost", dot_block)
        # Alive-and-injured/critical/incapacitated: Danger
        self.assertIn(
            'alive and (healthState == "Injured" or healthState == "Critical"', dot_block
        )
        self.assertIn('"Incapacitated"', dot_block)
        self.assertIn("then Theme.Colors.Danger", dot_block)
        # Dead (not alive): TextMuted
        self.assertIn("elseif not alive then Theme.Colors.TextMuted", dot_block)
        # Otherwise alive+healthy: Success
        self.assertIn("else Theme.Colors.Success", dot_block)
        # Priority order: Ghost before Injured/Critical before dead/muted
        self.assertLess(dot_block.index("Ghost"), dot_block.index("Danger"))
        self.assertLess(dot_block.index("Danger"), dot_block.index("TextMuted"))
        self.assertLess(dot_block.index("TextMuted"), dot_block.index("Success"))

        # Name label text: self gets "▸" suffix
        self.assertIn('then displayName .. " ▸"', update_block)
        self.assertIn("else displayName", update_block)

        # Name label color: dead → TextMuted; ghost → Ghost; alive → Text
        name_color_start = update_block.index(
            "entry.nameLabel.TextColor3 = if dead"
        )
        name_color_end = update_block.index(
            "\n\t\tlocal bg = entry.billboard", name_color_start
        )
        name_color_block = update_block[name_color_start:name_color_end]
        self.assertIn("then Theme.Colors.TextMuted", name_color_block)
        self.assertIn("elseif isGhost then Theme.Colors.Ghost", name_color_block)
        self.assertIn("else Theme.Colors.Text", name_color_block)
        # dead checked before ghost in name color
        self.assertLess(
            name_color_block.index("TextMuted"), name_color_block.index("Ghost")
        )

        # Background transparency: dead = 0.55, alive = 0.22
        self.assertIn(
            "bg.BackgroundTransparency = if dead then 0.55 else 0.22", update_block
        )


    def test_request_0140_game_view_request_role_action_dispatch_and_murder_plan_setup(
        self,
    ) -> None:
        view = (ROOT / "src/client/UI/GameView.lua").read_text(encoding="utf-8")

        # MONSTER_PLAN_ORDER lists all 8 monster types for the planning UI
        for monster_id in (
            "BabyAlien", "Screamer", "Wendigo", "ShadowMonster",
            "Chupacabra", "Dullahan", "Entity", "Banshee",
        ):
            self.assertIn(f'"{monster_id}"', view)

        # MONSTER_TAGLINES: each monster has a one-line tagline for the planning UI
        self.assertIn("Pink fleshy crawler · burst leaps · weak in open light", view)
        self.assertIn("Silver wailing spectre · marks campers · wail attacks the senses", view)

        # MONSTER_ABILITIES: all 8 monsters have two named abilities
        for pair in (
            '"ScuttleLeap", "AcidSwipe"',
            '"DisruptingScream", "ClawStrike"',
            '"ForestCharge", "MimicMark"',
            '"ShadowStep", "LightDrain"',
            '"BloodPounce", "Latch"',
            '"RelentlessPursuit", "FreezingTouch"',
            '"AnchorTeleport", "Distort"',
            '"MournfulWail", "DeathMark"',
        ):
            self.assertIn(pair, view)

        # _chooseMurderPlan: iterates MONSTER_PLAN_ORDER, looks up locationId per monster
        choose_start = view.index("function GameView:_chooseMurderPlan()")
        choose_end = view.index("function GameView:_requestRoleAction()", choose_start)
        choose_block = view[choose_start:choose_end]
        self.assertIn("for _, monsterId in MONSTER_PLAN_ORDER do", choose_block)
        self.assertIn("local locationId = MONSTER_PLAN_LOCATIONS[monsterId]", choose_block)
        self.assertIn("local tagline = MONSTER_TAGLINES[monsterId] or \"\"", choose_block)
        # Each button fires SetMurderPlan with monsterId and locationId
        self.assertIn('"SetMurderPlan", {', choose_block)
        self.assertIn("monsterId = monsterId,", choose_block)
        self.assertIn("locationId = locationId,", choose_block)
        # Title prompt tells user to choose monster then victim
        self.assertIn(
            '"Choose your transformation for tonight. Then choose a victim."', choose_block
        )

        # _requestRoleAction: ghost/eliminated early-return guard
        role_start = view.index("function GameView:_requestRoleAction()")
        role_end = view.index("function GameView:_settingRow(", role_start)
        role_block = view[role_start:role_end]
        self.assertIn("if self.ghostMode or self.eliminatedMode then", role_block)
        # SetMurderPlan available (Murderer) → _chooseMurderPlan
        self.assertIn('local planEnabled = self:_available(state, "SetMurderPlan")', role_block)
        self.assertIn("self:_chooseMurderPlan()", role_block)
        # Monster active → single ability uses direct participant picker; multi → _chooseAbility Monster
        self.assertIn('"UseMonsterAbility", {', role_block)
        self.assertIn('self:_chooseAbility("Monster", monsterAbilities)', role_block)
        self.assertIn("table.clone(MONSTER_ABILITIES[monsterId] or {})", role_block)
        # Single role ability → _activateRoleAbility; multi → _chooseAbility Role
        self.assertIn("self:_activateRoleAbility(abilities[1])", role_block)
        self.assertIn('self:_chooseAbility("Role", abilities)', role_block)
        # Fallback when no abilities
        self.assertIn('"No active ability"', role_block)

        # SetGhostMode: disables role action button and all hotbar buttons
        ghost_start = view.index("function GameView:SetGhostMode(active: boolean)")
        ghost_end = view.index("function GameView:", ghost_start + 1)
        ghost_block = view[ghost_start:ghost_end]
        self.assertIn("Components.SetButtonEnabled(self.roleAction, false)", ghost_block)
        self.assertIn("child:IsA(\"TextButton\") and active", ghost_block)
        # Ghost badge pulses unless reduced motion
        self.assertIn("self.ghostBadge.Visible = active", ghost_block)
        self.assertIn("if active and not reducedMotion then", ghost_block)
        self.assertIn("TextTransparency = 0.4", ghost_block)
        # Interaction panel becomes semi-transparent in ghost mode
        self.assertIn(
            "self.interaction.BackgroundTransparency = if active then 0.45 else Theme.PanelTransparency",
            ghost_block,
        )


    def test_request_0141_game_view_inventory_ghost_eliminated_and_medical_kit_branching(
        self,
    ) -> None:
        view = (ROOT / "src/client/UI/GameView.lua").read_text(encoding="utf-8")

        # _updateInventory: ghost mode disables item buttons; eliminated mode clears selection
        inv_start = view.index("function GameView:_updateInventory(state: any)")
        inv_end = view.index("function GameView:_activateItem(", inv_start)
        inv_block = view[inv_start:inv_end]
        # Empty inventory fallback message
        self.assertIn('"Equipment will appear here."', inv_block)
        # Slot button color: selected=Info, equipped=Gold, default=Panel
        self.assertIn("then Theme.Colors.Info", inv_block)
        self.assertIn("elseif equipped then Theme.Colors.Gold", inv_block)
        self.assertIn("else Theme.Colors.Panel,", inv_block)
        # Slot selection ordering: Info (selectedSlot) checked before Gold (equipped)
        self.assertLess(
            inv_block.index("Theme.Colors.Info"),
            inv_block.index("Theme.Colors.Gold"),
        )
        # Ghost mode: buttons disabled
        self.assertIn(
            "Components.SetButtonEnabled(button, not self.ghostMode)", inv_block
        )
        # Eliminated mode: buttons disabled (separate branch from ghostMode)
        self.assertIn("if self.eliminatedMode then", inv_block)
        self.assertIn("GuiService.SelectedObject = nil", inv_block)

        # _activateItem: eliminated and ghost both cause early return
        act_start = view.index("function GameView:_activateItem(")
        act_end = view.index("function GameView:_dismissInterviewPicker(", act_start)
        act_block = view[act_start:act_end]
        self.assertIn("if self.eliminatedMode then", act_block)
        self.assertIn("if self.ghostMode or type(item) ~= \"table\" then", act_block)
        # Equipped item → UseItem; unequipped → EquipItem first
        self.assertIn(
            'if not readBoolean(item, "equipped", false) then', act_block
        )
        self.assertIn('"EquipItem", { instanceId = instanceId }', act_block)
        # MedicalKit → _chooseParticipant (target selection required)
        self.assertIn('if equipmentId == "MedicalKit" then', act_block)
        self.assertIn('self:_chooseParticipant("UseItem", payload, false)', act_block)
        # Other equipped items → _send directly
        self.assertIn('self:_send("UseItem", payload, control)', act_block)
        # Camera look direction included in UseItem payload
        self.assertIn("Workspace.CurrentCamera.CFrame.LookVector", act_block)


    def test_request_0142_game_view_progression_upgrade_mastery_gate_and_cosmetic_unlock_branching(
        self,
    ) -> None:
        view = (ROOT / "src/client/UI/GameView.lua").read_text(encoding="utf-8")

        # _updateProgression: profile unavailable fallback
        prog_start = view.index("function GameView:_updateProgression(state: any)")
        prog_end = view.index("function GameView:_buildTargetSelector()", prog_start)
        prog_block = view[prog_start:prog_end]
        self.assertIn(
            '"Profile unavailable - progression actions are temporarily locked."', prog_block
        )

        # Summary line: totalXP and campTokens
        self.assertIn('"TOTAL XP  %d     CAMP TOKENS  %d\\nEverything here is earned by playing."', prog_block)

        # Upgrade eligibility: capped check and mastery gate
        self.assertIn("local capped = currentRank >= definition.maxRank", prog_block)
        self.assertIn("local cost = if capped then 0 else UpgradeCatalog.nextRankCost(definition, currentRank)", prog_block)
        self.assertIn("and not capped", prog_block)
        self.assertIn("and masteryLevel >= definition.requiredMasteryLevel", prog_block)
        self.assertIn("and tokens >= cost", prog_block)
        # Capped upgrades show MAX RANK; uncapped show BUY RANK N+1
        self.assertIn('if capped then "MAX RANK" else "BUY RANK " .. tostring(currentRank + 1)', prog_block)
        # BuyUpgrade sends roleId and upgradeId
        self.assertIn('"BuyUpgrade", {', prog_block)
        self.assertIn("roleId = definition.roleId,", prog_block)
        self.assertIn("upgradeId = definition.id,", prog_block)

        # Cosmetic section: owned → equip vs unlockKind branching
        self.assertIn('if isEquipped\n\t\t\tthen "EQUIPPED"', prog_block)
        self.assertIn('elseif isOwned then "EQUIP"', prog_block)
        self.assertIn('elseif definition.unlockKind == "CampTokens"', prog_block)
        self.assertIn('"UNLOCK " .. tostring(definition.unlockAmount)', prog_block)
        self.assertIn('else "LOCKED"', prog_block)
        # Status text: Level-gated vs token-gated fallback
        self.assertIn('elseif definition.unlockKind == "Level"', prog_block)
        self.assertIn('"Requires level " .. tostring(definition.unlockAmount)', prog_block)
        self.assertIn('tostring(definition.unlockAmount) .. " tokens"', prog_block)
        # canUnlock: not owned, CampTokens kind, enough tokens
        self.assertIn('definition.unlockKind == "CampTokens"', prog_block)
        self.assertIn("tokens >= definition.unlockAmount", prog_block)
        # Unlock action sends cosmeticId
        self.assertIn('"UnlockCosmetic", { cosmeticId = definition.id }', prog_block)
        self.assertIn('"EquipCosmetic", { cosmeticId = definition.id }', prog_block)

        # ShowInterviewTopicPicker: witness topic highlighted Amber; others Panel
        picker_start = view.index("function GameView:ShowInterviewTopicPicker(")
        picker_end = view.index("function GameView:_dismissCounselorDialogue(", picker_start)
        picker_block = view[picker_start:picker_end]
        self.assertIn("if isWitness and entry.witnessHighlight", picker_block)
        self.assertIn("then Theme.Colors.Amber", picker_block)
        self.assertIn("else Theme.Colors.Panel,", picker_block)
        # Token guard prevents stale button activation
        self.assertIn("if token ~= self.interviewPickerToken then", picker_block)
        # Fires InterviewCounselor with counselorId and topic
        self.assertIn('"InterviewCounselor", {', picker_block)
        self.assertIn("counselorId = counselorId,", picker_block)
        self.assertIn("topic = topic,", picker_block)

    def test_request_0157_motion_shake_offset_sequence_and_stagger_children_sort_and_remaining(
        self,
    ) -> None:
        motion = (ROOT / "src" / "client" / "UI" / "Motion.lua").read_text(
            encoding="utf-8"
        )

        # Motion.Shake: reduced motion short-circuits to immediate play
        shake_start = motion.index("function Motion.Shake(target: GuiObject")
        shake_end = motion.index("\nlocal function visibleChildren(", shake_start)
        shake_fn = motion[shake_start:shake_end]
        self.assertIn(
            "if Motion.IsReducedMotion(target, resolved.reducedMotion) then",
            shake_fn,
        )

        # Five-step offset sequence: full, full, dampened, dampened, zero
        self.assertIn(
            "{ -distance, distance, -distance * 0.55, distance * 0.55, 0 }",
            shake_fn,
        )

        # restingPosition restored on cancel via record cleanup
        self.assertIn("local restingPosition = target.Position", shake_fn)
        self.assertIn("target.Position = restingPosition", shake_fn)

        # Loop guard: exits early if record.finished
        self.assertIn("if record.finished then", shake_fn)

        # Non-completed playback → finish with false (interrupted)
        self.assertIn(
            "if playbackState ~= Enum.PlaybackState.Completed then",
            shake_fn,
        )
        self.assertIn("finish(record, false)", shake_fn)

        # visibleChildren: sorted by LayoutOrder then Name
        vis_start = motion.index("local function visibleChildren(container: GuiObject)")
        vis_end = motion.index("\nfunction Motion.StaggerChildren(", vis_start)
        vis_fn = motion[vis_start:vis_end]
        self.assertIn('child:IsA("GuiObject") and child.Visible', vis_fn)
        self.assertIn("left.LayoutOrder == right.LayoutOrder", vis_fn)
        self.assertIn("return left.Name < right.Name", vis_fn)
        self.assertIn("return left.LayoutOrder < right.LayoutOrder", vis_fn)

        # Motion.StaggerChildren: reduced motion collapses step to 0
        stagger_start = motion.index("function Motion.StaggerChildren(container: GuiObject")
        stagger_fn = motion[stagger_start:]
        self.assertIn("if reduced then", stagger_fn)
        self.assertIn("step = 0", stagger_fn)

        # Empty children path: skips delay and returns immediately
        self.assertIn("if #children == 0 then", stagger_fn)

        # Remaining counter: decremented per child; finishes when 0
        self.assertIn("local remaining = #children", stagger_fn)
        self.assertIn("remaining -= 1", stagger_fn)
        self.assertIn("if remaining == 0 then", stagger_fn)
        self.assertIn("finish(record, true)", stagger_fn)

        # All children hidden before stagger begins
        self.assertIn("child.Visible = false", stagger_fn)

        # Delay per child is (index - 1) * step
        self.assertIn("task.delay((index - 1) * step,", stagger_fn)

    def test_request_0156_player_status_view_sort_order_accent_and_disconnect_label(
        self,
    ) -> None:
        roster = (
            ROOT / "src" / "client" / "UI" / "PlayerStatusView.lua"
        ).read_text(encoding="utf-8")

        # sortedParticipants: alive bucket → ghosts bucket → dead bucket
        sort_start = roster.index("local function sortedParticipants(participants: { any })")
        sort_end = roster.index("\nlocal function createDetailLabel(", sort_start)
        sort_fn = roster[sort_start:sort_end]
        # Three buckets defined
        self.assertIn("local alive: { any } = {}", sort_fn)
        self.assertIn("local ghosts: { any } = {}", sort_fn)
        self.assertIn("local dead: { any } = {}", sort_fn)
        # Alive check comes before ghost check in the classification logic
        alive_check_pos = sort_fn.index("readBoolean(participant, \"alive\", false)")
        ghost_check_pos = sort_fn.index("readBoolean(participant, \"isGhost\", false)")
        self.assertLess(alive_check_pos, ghost_check_pos)
        # Concatenation order: alive, ghosts, dead
        concat_pos = sort_fn.index("{ alive, ghosts, dead }")
        self.assertGreater(concat_pos, alive_check_pos)

        # createRow: name label transparency — connected=0, disconnected=0.5
        row_start = roster.index("local function createRow(")
        row_end = roster.index("\nfunction PlayerStatusView.new(", row_start)
        row_fn = roster[row_start:row_end]
        self.assertIn(
            "nameLabel.TextTransparency = if connected then 0 else 0.5",
            row_fn,
        )

        # Name label color: alive → Text; dead → TextMuted
        self.assertIn(
            "nameLabel.TextColor3 = if alive then Theme.Colors.Text else Theme.Colors.TextMuted",
            row_fn,
        )

        # Disconnected players get a "(disconnected)" detail label
        self.assertIn("if not connected then", row_fn)
        self.assertIn('"(disconnected)"', row_fn)

        # Local player gets a Gold accent bar
        self.assertIn("if isLocalPlayer then", row_fn)
        self.assertIn('accent.Name = "LocalPlayerAccent"', row_fn)
        self.assertIn("accent.BackgroundColor3 = Theme.Colors.Gold", row_fn)

        # Disconnected label appears before the local player accent block
        disc_pos = row_fn.index('"(disconnected)"')
        accent_pos = row_fn.index('"LocalPlayerAccent"')
        self.assertLess(disc_pos, accent_pos)

    def test_request_0155_proximity_controller_zone_registration_label_clamp_and_progress_rounding(
        self,
    ) -> None:
        prox = (
            ROOT / "src" / "client" / "Controllers" / "ProximityController.lua"
        ).read_text(encoding="utf-8")

        # RegisterZone: guard on destroyed state and part still parented
        reg_start = prox.index("function ProximityController:RegisterZone(")
        reg_end = prox.index("\nfunction ProximityController:UnregisterZone(", reg_start)
        reg_fn = prox[reg_start:reg_end]
        self.assertIn(
            "if self.destroyed or not part.Parent then",
            reg_fn,
        )

        # Label truncated to 60 chars; defaults to "Interact" when empty
        self.assertIn(
            'local safeLabel = if label ~= "" then string.sub(label, 1, 60) else "Interact"',
            reg_fn,
        )
        # Key hint truncated to 12 chars; defaults to "E" when empty
        self.assertIn(
            'local safeKey = if keyHint ~= "" then string.sub(keyHint, 1, 12) else "E"',
            reg_fn,
        )

        # Existing zone reuse: update text and re-enable without recreating GUI
        self.assertIn("if existing and existing.gui.Parent then", reg_fn)
        self.assertIn("existing.label.Text = safeLabel", reg_fn)
        self.assertIn('existing.keyHint.Text = "[" .. safeKey .. "]"', reg_fn)
        self.assertIn("existing.gui.Enabled = true", reg_fn)

        # SetProgress: segment count rounded to nearest (floor with +0.5)
        prog_start = prox.index("function ProximityController:SetProgress(")
        prog_end = prox.index("\nfunction ProximityController:SetVisible(", prog_start)
        prog_fn = prox[prog_start:prog_end]
        self.assertIn(
            "math.floor(resolved * SEGMENT_COUNT + 0.5)",
            prog_fn,
        )
        # Segments at or below threshold: fully opaque; above: 0.82 transparent
        self.assertIn(
            "if index <= visibleSegments then 0 else 0.82",
            prog_fn,
        )

        # UnregisterZone: early return if zone unknown; destroys GUI if still parented
        unreg_start = prox.index("function ProximityController:UnregisterZone(")
        unreg_end = prox.index("\nfunction ProximityController:SetProgress(", unreg_start)
        unreg_fn = prox[unreg_start:unreg_end]
        self.assertIn("if not record then", unreg_fn)
        self.assertIn("self.zones[part] = nil", unreg_fn)
        self.assertIn("record.gui:Destroy()", unreg_fn)

        # Destroy: idempotent; collects parts first, then unregisters (safe iteration)
        destroy_start = prox.index("function ProximityController:Destroy()")
        destroy_fn = prox[destroy_start:]
        self.assertIn("if self.destroyed then", destroy_fn)
        parts_collect_pos = destroy_fn.index(
            "for part in self.zones do\n\t\ttable.insert(parts, part)\n\tend"
        )
        unreg_loop_pos = destroy_fn.index("self:UnregisterZone(part)", parts_collect_pos)
        self.assertLess(parts_collect_pos, unreg_loop_pos)

    def test_request_0154_audio_controller_apply_settings_validation_and_switch_loop(
        self,
    ) -> None:
        audio = (
            ROOT / "src" / "client" / "Controllers" / "AudioController.lua"
        ).read_text(encoding="utf-8")

        # ApplySettings: rejects values with wrong type (number vs boolean, etc.)
        apply_start = audio.index("function AudioController:ApplySettings(settings: any)")
        apply_end = audio.index("\nfunction AudioController:SetHeartbeatIntensity(", apply_start)
        apply_fn = audio[apply_start:apply_end]
        self.assertIn("if type(settings) ~= \"table\" then", apply_fn)
        # Numeric values: must be finite (NaN/inf rejected)
        self.assertIn(
            "type(defaultValue) == \"number\" and type(value) == \"number\"",
            apply_fn,
        )
        self.assertIn(
            "value == value and math.abs(value) < math.huge",
            apply_fn,
        )
        # Boolean values type-checked against boolean default
        self.assertIn(
            "type(defaultValue) == \"boolean\" and type(value) == \"boolean\"",
            apply_fn,
        )
        # Fallback to defaultValue only when current setting is nil (preserves valid existing values)
        self.assertIn("elseif self.settings[key] == nil then", apply_fn)
        self.assertIn("self.settings[key] = defaultValue", apply_fn)

        # subtitles: defaults to true unless explicitly set to false
        self.assertIn(
            "self.settings.subtitles = self.settings.subtitles ~= false",
            apply_fn,
        )

        # ApplySettings ends by re-applying group volumes and heartbeat intensity
        self.assertIn("self:_updateGroupVolumes()", apply_fn)
        self.assertIn("self:SetHeartbeatIntensity(self.heartbeatIntensity)", apply_fn)

        # _updateGroupVolumes: master multiplies each group
        vol_start = audio.index("function AudioController:_updateGroupVolumes()")
        vol_end = audio.index("\nfunction AudioController:ApplySettingImmediate(", vol_start)
        vol_fn = audio[vol_start:vol_end]
        for group in ("Music", "Ambience", "Effects", "UI"):
            self.assertIn(f'self.groups.{group}.Volume = master *', vol_fn)

        # _switchLoop: stops all channel loops that are not the target; starts target if not playing
        loop_start = audio.index("function AudioController:_switchLoop(channel: string")
        loop_end = audio.index("\nfunction AudioController:_updateGroupVolumes()", loop_start)
        loop_fn = audio[loop_start:loop_end]
        self.assertIn("definition.channel == channel and definition.looped", loop_fn)
        self.assertIn("definition.name ~= name", loop_fn)
        self.assertIn("sound:Stop()", loop_fn)
        self.assertIn("not sound.IsPlaying", loop_fn)
        self.assertIn("sound:Play()", loop_fn)

        # PlayCue: provided subtitle overrides definition subtitle; empty title falls back
        cue_start = audio.index("function AudioController:PlayCue(name: string")
        cue_end = audio.index("\nfunction AudioController:PlayUIEvent(", cue_start)
        cue_fn = audio[cue_start:cue_end]
        self.assertIn("subtitle or definitionSubtitle", cue_fn)
        self.assertIn("self:_subtitle(subtitle or definitionSubtitle, 2.5)", cue_fn)

        # _subtitle: gates on text non-empty, subtitles setting, and callback presence
        sub_start = audio.index("function AudioController:_subtitle(text: string?")
        sub_end = audio.index("\nfunction AudioController:PlayCue(", sub_start)
        sub_fn = audio[sub_start:sub_end]
        self.assertIn(
            'text and text ~= "" and self.settings.subtitles == true and self.onSubtitle',
            sub_fn,
        )

    def test_request_0153_camera_controller_flicker_tween_and_step_clamp_contracts(
        self,
    ) -> None:
        camera = (
            ROOT / "src" / "client" / "Controllers" / "CameraController.lua"
        ).read_text(encoding="utf-8")

        # _flickerNearestLight: ghost-mode and cooldown gate
        flicker_start = camera.index("function CameraController:_flickerNearestLight()")
        flicker_end = camera.index("\nfunction CameraController:_step(", flicker_start)
        flicker_fn = camera[flicker_start:flicker_end]
        self.assertIn(
            "not self.ghostMode or os.clock() - self.lastFlickerAt < FLICKER_COOLDOWN",
            flicker_fn,
        )

        # Light search: three light types within FLICKER_RANGE
        for light_type in ('"PointLight"', '"SpotLight"', '"SurfaceLight"'):
            self.assertIn(light_type, flicker_fn)
        self.assertIn("distance <= nearestDistance", flicker_fn)

        # Two-stage tween: fade out (Sine Out) then fade back in (Sine In)
        self.assertIn(
            "TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)",
            flicker_fn,
        )
        self.assertIn(
            "TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In)",
            flicker_fn,
        )
        # Fade-in only executes when fade-out completed and light still parented
        self.assertIn(
            "playbackState ~= Enum.PlaybackState.Completed or not light.Parent",
            flicker_fn,
        )
        # Brightness restored to original value on fade-in
        self.assertIn("{ Brightness = brightness }", flicker_fn)
        self.assertIn("{ Brightness = 0 }", flicker_fn)

        # _step: ghost-mode gate
        step_start = camera.index("function CameraController:_step(deltaTime: number)")
        step_end = camera.index("\nfunction CameraController:SetGhostMode(", step_start)
        step_fn = camera[step_start:step_end]
        self.assertIn(
            "if self.destroyed or not self.ghostMode then",
            step_fn,
        )

        # Pitch clamped to ±85 degrees
        self.assertIn(
            "math.clamp(\n\t\tself.pitch + self.stickLook.Y * STICK_LOOK_SPEED * deltaTime,\n"
            "\t\t-math.rad(85),\n"
            "\t\tmath.rad(85)\n"
            "\t)",
            step_fn,
        )

        # Horizontal input normalized when magnitude > 1
        self.assertIn("if horizontal.Magnitude > 1 then", step_fn)
        self.assertIn("horizontal = horizontal.Unit", step_fn)

        # Vertical clamped to [-1, 1]
        self.assertIn("vertical = math.clamp(vertical, -1, 1)", step_fn)

        # deltaTime capped at 0.1 to prevent large position jumps
        self.assertIn("direction * speed * math.min(deltaTime, 0.1)", step_fn)

        # Y position clamped between ground height and MAXIMUM_ALTITUDE
        self.assertIn("math.clamp(candidate.Y, minimumY, MAXIMUM_ALTITUDE)", step_fn)

    def test_request_0152_cinematics_screen_shake_amplitude_decay_and_phase_flash(
        self,
    ) -> None:
        cin = (
            ROOT / "src" / "client" / "Controllers" / "CinematicsController.lua"
        ).read_text(encoding="utf-8")

        # PlayScreenShake: amplitude derived from intensity, clamped to [0, 0.2]
        shake_start = cin.index("function CinematicsController:PlayScreenShake(intensity: number?)")
        shake_end = cin.index("\nfunction CinematicsController:PlayPhaseFlash()", shake_start)
        shake_fn = cin[shake_start:shake_end]
        self.assertIn(
            "local amp = math.clamp((intensity or 1.0) * 0.07, 0, 0.2)",
            shake_fn,
        )
        # Fixed frequency and duration
        self.assertIn("local freq = 14", shake_fn)
        self.assertIn("local duration = 0.4", shake_fn)

        # Token guard prevents stale shakes from overwriting new ones
        self.assertIn("self.shakeToken += 1", shake_fn)
        self.assertIn("if self.shakeToken ~= token or self.destroyed then", shake_fn)

        # Previous shake cancelled and residual offset cleared before starting new one
        prev_cancel_pos = shake_fn.index("self:_clearShakeOffset()")
        self.assertIn("self.shakeConn:Disconnect()", shake_fn)

        # Decay: linear from 1 → 0 over duration
        self.assertIn("local decay = 1 - elapsed / duration", shake_fn)

        # Sinusoidal x axis; y axis at half amplitude with 0.7π phase offset
        self.assertIn("local t = elapsed * freq * math.pi * 2", shake_fn)
        self.assertIn("local x = math.sin(t) * amp * decay", shake_fn)
        self.assertIn(
            "local y = math.sin(t + math.pi * 0.7) * amp * 0.5 * decay",
            shake_fn,
        )

        # Camera offset applied and tracked for cleanup
        self.assertIn("cam.CFrame = cam.CFrame * CFrame.new(newOffset)", shake_fn)
        self.assertIn("self.shakePrevOffset = newOffset", shake_fn)

        # _clearShakeOffset called each frame to avoid accumulation
        frame_clear_count = shake_fn.count("self:_clearShakeOffset()")
        self.assertGreaterEqual(frame_clear_count, 2)

        # PlayPhaseFlash: two-stage brightness — flash to 0.14 then fade back to 0
        flash_start = cin.index("function CinematicsController:PlayPhaseFlash()")
        flash_end = cin.index("\nfunction CinematicsController:PlayPhaseTransition(", flash_start)
        flash_fn = cin[flash_start:flash_end]
        self.assertIn("{ Brightness = 0.14 }", flash_fn)
        self.assertIn("{ Brightness = 0 }", flash_fn)
        # Flash phase (0.10 s) completes before fade phase (0.28 s)
        self.assertIn("task.delay(0.10,", flash_fn)
        flash_pos = flash_fn.index("{ Brightness = 0.14 }")
        fade_pos = flash_fn.index("{ Brightness = 0 }")
        self.assertLess(flash_pos, fade_pos)

    def test_request_0151_haptic_controller_vibration_profiles_and_pcall_guards(
        self,
    ) -> None:
        haptic = (
            ROOT / "src" / "client" / "Controllers" / "HapticController.lua"
        ).read_text(encoding="utf-8")

        # Motor constants: Gamepad1, Small, Large
        self.assertIn("Enum.UserInputType.Gamepad1", haptic)
        self.assertIn("Enum.VibrationMotor.Small", haptic)
        self.assertIn("Enum.VibrationMotor.Large", haptic)

        # isSupported: pcall-wraps IsMotorSupported; only returns true on ok AND true result
        support_start = haptic.index("local function isSupported(motor: Enum.VibrationMotor)")
        support_end = haptic.index("\nlocal function vibrate(", support_start)
        support_fn = haptic[support_start:support_end]
        self.assertIn("HapticService:IsMotorSupported(INPUT_TYPE, motor)", support_fn)
        self.assertIn("return ok and result == true", support_fn)

        # vibrate: checks isSupported before setting motor; pcall-wraps SetMotor
        vib_start = haptic.index("local function vibrate(motor: Enum.VibrationMotor")
        vib_end = haptic.index("\nlocal HapticController = {}", vib_start)
        vib_fn = haptic[vib_start:vib_end]
        self.assertIn("if not isSupported(motor) then", vib_fn)
        self.assertIn("HapticService:SetMotor(INPUT_TYPE, motor, amplitude)", vib_fn)
        # Reset to 0 after duration via task.delay
        self.assertIn("HapticService:SetMotor(INPUT_TYPE, motor, 0)", vib_fn)

        # Click: Small motor, 0.35 amplitude, 0.06 duration
        click_start = haptic.index("function HapticController.Click()")
        click_end = haptic.index("\nfunction HapticController.Impact()", click_start)
        click_fn = haptic[click_start:click_end]
        self.assertIn("vibrate(MOTOR_SMALL, 0.35, 0.06)", click_fn)

        # Impact: Small AND Large motors
        impact_start = haptic.index("function HapticController.Impact()")
        impact_end = haptic.index("\nfunction HapticController.Danger()", impact_start)
        impact_fn = haptic[impact_start:impact_end]
        self.assertIn("vibrate(MOTOR_SMALL, 0.6, 0.1)", impact_fn)
        self.assertIn("vibrate(MOTOR_LARGE, 0.4, 0.08)", impact_fn)

        # Danger: Large motor leads with highest amplitude (0.85); Small follows
        danger_start = haptic.index("function HapticController.Danger()")
        danger_end = haptic.index("\nfunction HapticController.Celebrate()", danger_start)
        danger_fn = haptic[danger_start:danger_end]
        self.assertIn("vibrate(MOTOR_LARGE, 0.85, 0.22)", danger_fn)
        self.assertIn("vibrate(MOTOR_SMALL, 0.5, 0.18)", danger_fn)
        large_pos = danger_fn.index("vibrate(MOTOR_LARGE")
        small_pos = danger_fn.index("vibrate(MOTOR_SMALL")
        self.assertLess(large_pos, small_pos)

        # Celebrate: two Large pulses with 0.18 s delay between them
        cel_start = haptic.index("function HapticController.Celebrate()")
        cel_end = haptic.index("\nfunction HapticController.Error()", cel_start)
        cel_fn = haptic[cel_start:cel_end]
        self.assertIn("vibrate(MOTOR_LARGE, 0.7, 0.12)", cel_fn)
        self.assertIn("task.delay(0.18,", cel_fn)
        self.assertIn("vibrate(MOTOR_LARGE, 0.5, 0.1)", cel_fn)

        # Error: two Small pulses with 0.12 s delay between them
        err_start = haptic.index("function HapticController.Error()")
        err_fn = haptic[err_start:]
        self.assertIn("vibrate(MOTOR_SMALL, 0.9, 0.08)", err_fn)
        self.assertIn("task.delay(0.12,", err_fn)
        self.assertIn("vibrate(MOTOR_SMALL, 0.7, 0.06)", err_fn)

    def test_request_0150_reward_calculation_safe_count_non_participated_and_survival_gate(
        self,
    ) -> None:
        reward = (
            ROOT / "src" / "server" / "Systems" / "RewardCalculation.lua"
        ).read_text(encoding="utf-8")

        # safeCount: NaN and +/-inf map to 0; result clamped and floored
        safe_start = reward.index("local function safeCount(value: number, maximum: number)")
        safe_end = reward.index("\nfunction RewardCalculation.Calculate(", safe_start)
        safe_fn = reward[safe_start:safe_end]
        self.assertIn(
            "if value ~= value or value == math.huge or value == -math.huge then",
            safe_fn,
        )
        self.assertIn("return 0", safe_fn)
        self.assertIn("math.clamp(math.floor(value), 0, maximum)", safe_fn)

        calc_start = reward.index("function RewardCalculation.Calculate(")
        calc_fn = reward[calc_start:]

        # Non-participated path: objectives and evidence reset to 0 regardless of input
        self.assertIn("if not input.participated then", calc_fn)
        nonpart_pos = calc_fn.index("if not input.participated then")
        # Both zeroing assignments appear after this guard
        obj_zero_pos = calc_fn.index("objectives = 0", nonpart_pos)
        ev_zero_pos = calc_fn.index("evidence = 0", nonpart_pos)
        self.assertLess(nonpart_pos, obj_zero_pos)
        self.assertLess(nonpart_pos, ev_zero_pos)

        # Participation gate: all base rewards inside `if input.participated`
        self.assertIn("if input.participated then", calc_fn)
        self.assertIn("roundsPlayed = 1", calc_fn)
        self.assertIn("xp += rewards.participationXP", calc_fn)
        self.assertIn("campTokens += rewards.participationTokens", calc_fn)

        # Objectives and evidence contribute to role mastery XP together
        self.assertIn(
            "roleMasteryXP += (objectives + evidence) * rewards.roleContributionXP",
            calc_fn,
        )

        # Win bonus: applied inside participation gate
        self.assertIn("if input.won then", calc_fn)
        self.assertIn("xp += rewards.winXP", calc_fn)
        self.assertIn("roleMasteryXP += rewards.roleWinXP", calc_fn)

        # Survival bonus: separate inner gate
        self.assertIn("if input.survived then", calc_fn)
        self.assertIn("xp += rewards.survivalXP", calc_fn)
        self.assertIn("campTokens += rewards.survivalTokens", calc_fn)

        # Survivals field: 1 when participated AND survived, else 0
        self.assertIn(
            "survivals = if input.participated and input.survived then 1 else 0,",
            calc_fn,
        )

        # wins field: 1 when participated AND won (role-agnostic)
        self.assertIn(
            "wins = if input.participated and input.won then 1 else 0,",
            calc_fn,
        )

    def test_request_0149_world_service_seed_derivation_variant_selection_and_set_night_rollback(
        self,
    ) -> None:
        world = source("Services/WorldService.lua")

        # Seed constants: Mersenne prime modulus and multiplier
        self.assertIn("SEED_MODULUS = 2_147_483_647", world)
        self.assertIn("SEED_MULTIPLIER = 48_271", world)

        # normalizeSeed: finite + integer guards; corrects negative by adding modulus
        norm_start = world.index("local function normalizeSeed(seed: number): number")
        norm_end = world.index("\nlocal function deriveSeed(", norm_start)
        norm_fn = world[norm_start:norm_end]
        self.assertIn(
            'assert(seed == seed and math.abs(seed) < math.huge, "World seed must be finite")',
            norm_fn,
        )
        self.assertIn(
            'assert(seed % 1 == 0, "World seed must be a whole number")',
            norm_fn,
        )
        self.assertIn("local normalized = seed % SEED_MODULUS", norm_fn)
        self.assertIn("if normalized < 0 then", norm_fn)
        self.assertIn("normalized += SEED_MODULUS", norm_fn)

        # deriveSeed: roundId * multiplier + seedSalt, passed through normalizeSeed
        derive_start = world.index("local function deriveSeed(roundId: number): number")
        derive_end = world.index("\nlocal function selectVariant(", derive_start)
        derive_fn = world[derive_start:derive_end]
        self.assertIn(
            "normalizeSeed(roundId * SEED_MULTIPLIER + WorldManifest.seedSalt)",
            derive_fn,
        )

        # selectVariant: 0-indexed mod then +1 for 1-indexed Lua table
        select_start = world.index("local function selectVariant(seed: number):")
        select_end = world.index("\nlocal function cloneDistrictIds(", select_start)
        select_fn = world[select_start:select_end]
        self.assertIn(
            "(seed % #WorldManifest.variants) + 1",
            select_fn,
        )

        # PrepareRound: roundId must be a positive integer
        self.assertIn(
            'assert(roundId > 0 and roundId % 1 == 0, "roundId must be a positive integer")',
            world,
        )
        # PrepareRound: explicit seed path uses normalizeSeed; otherwise derives from roundId
        self.assertIn(
            "if explicitSeed ~= nil then normalizeSeed(explicitSeed) else deriveSeed(roundId)",
            world,
        )

        # MarkObjectiveComplete: rejects empty objectiveId
        self.assertIn(
            'assert(objectiveId ~= "", "objectiveId must not be empty")',
            world,
        )

        # TransitionState values cover all four states
        for state in ('"Day"', '"Night"', '"TransformingToNight"', '"TransformingToDay"'):
            self.assertIn(state, world)

        # SetNight: no-op when already in the target stable state
        set_night_start = world.index("function WorldService:SetNight(isNight: boolean)")
        set_night_end = world.index("\nfunction WorldService:SpawnEvidence(", set_night_start)
        set_night_fn = world[set_night_start:set_night_end]
        self.assertIn(
            "self.transitionState == self:_stableState(isNight)",
            set_night_fn,
        )

        # SetNight: transitioning state set BEFORE the pcall-wrapped fallback call
        transition_pos = set_night_fn.index(
            "self.transitionState = self:_transitionState(isNight)"
        )
        pcall_pos = set_night_fn.index("local swapped, swapFailure = pcall(")
        self.assertLess(transition_pos, pcall_pos)

        # SetNight: fallback failure rolls back transitionState and re-raises
        self.assertIn(
            "self.transitionState = self:_stableState(previousIsNight)",
            set_night_fn,
        )
        self.assertIn(
            '"World fallback transformation failed: "',
            set_night_fn,
        )

        # SetNight: successful transition sets activeDistrictIds from variant.districtOrder
        self.assertIn(
            "cloneDistrictIds(self.variant.districtOrder)",
            set_night_fn,
        )
        # activeDistrictIds cleared when returning to day
        self.assertIn(
            "else {}",
            set_night_fn,
        )

        # SetNight: relocation failure triggers rollback and double-error on rollback failure
        self.assertIn(
            '"World midpoint relocation failed: "',
            set_night_fn,
        )
        self.assertIn(
            '"World relocation and rollback failed: "',
            set_night_fn,
        )

    def test_request_0148_round_lifecycle_event_names_emit_isolation_and_disconnect(
        self,
    ) -> None:
        lc = source("Services/RoundLifecycle.lua")

        # All 7 lifecycle event names declared in the LifecycleEventName type union
        for event in (
            '"RoundStarted"',
            '"PhaseChanged"',
            '"ParticipantInjured"',
            '"ParticipantEliminated"',
            '"ParticipantGhostTransition"',
            '"RoundEnded"',
            '"RoundReset"',
        ):
            self.assertIn(event, lc)

        # LifecycleEvent shape includes roundId, revision, serverTime, and payload
        for field in (
            "roundId: number,",
            "revision: number,",
            "serverTime: number,",
            "payload: { [string]: unknown },",
        ):
            self.assertIn(field, lc)

        # BeginRound: must strictly increase round ID
        self.assertIn(
            'assert(roundId > self.roundId, "Round IDs must increase")',
            lc,
        )
        # BeginRound: emits RoundStarted immediately after setting roundId
        begin_start = lc.index("function RoundLifecycle:BeginRound(")
        begin_end = lc.index("\nfunction RoundLifecycle:On(", begin_start)
        begin_fn = lc[begin_start:begin_end]
        roundid_pos = begin_fn.index("self.roundId = roundId")
        emit_pos = begin_fn.index('self:Emit("RoundStarted", {})')
        self.assertLess(roundid_pos, emit_pos)

        # On: guards destroyed state and unknown event names
        self.assertIn(
            'assert(not self.destroyed, "Cannot subscribe to a destroyed lifecycle")',
            lc,
        )
        self.assertIn(
            '"Unknown lifecycle event: " .. eventName',
            lc,
        )
        # On: disconnect closure guards idempotency with connected flag
        on_start = lc.index("function RoundLifecycle:On(")
        on_end = lc.index("\nfunction RoundLifecycle:Emit(", on_start)
        on_fn = lc[on_start:on_end]
        self.assertIn("local connected = true", on_fn)
        self.assertIn("if not connected then", on_fn)
        self.assertIn("table.remove(listeners, index)", on_fn)

        # Emit: revision increments before building the event
        emit_start = lc.index("function RoundLifecycle:Emit(")
        emit_end = lc.index("\nfunction RoundLifecycle:Destroy(", emit_start)
        emit_fn = lc[emit_start:emit_end]
        rev_pos = emit_fn.index("self.revision += 1")
        event_build_pos = emit_fn.index("local event: LifecycleEvent = {")
        self.assertLess(rev_pos, event_build_pos)

        # Emit: listeners cloned before iteration (safe against mid-dispatch removal)
        self.assertIn("local listeners = table.clone(self.listeners[eventName])", emit_fn)

        # Emit: listener errors are isolated via pcall with a warn
        self.assertIn(
            "local success, message = pcall(listener, event)", emit_fn
        )
        self.assertIn("[RoundLifecycle]", emit_fn)

        # Destroy: idempotent and clears all listeners
        destroy_start = lc.index("function RoundLifecycle:Destroy(")
        destroy_fn = lc[destroy_start:]
        self.assertIn("if self.destroyed then", destroy_fn)
        self.assertIn("table.clear(listeners)", destroy_fn)

    def test_request_0147_status_effect_service_round_boundary_expiry_and_transfer(
        self,
    ) -> None:
        svc = source("Services/StatusEffectService.lua")

        # StatusSnapshot type declares all 5 required fields
        for field in (
            "statusId: MonsterStatusId,",
            "sourceParticipantId: string,",
            "abilityId: string,",
            "appliedAt: number,",
            "expiresAt: number,",
        ):
            self.assertIn(field, svc)

        # BeginRound: round ID must strictly increase
        self.assertIn(
            'assert(roundId > self.roundId, "Round IDs must increase")',
            svc,
        )
        # BeginRound: clears all effects and resets revision to 0
        self.assertIn("self.effectsByParticipantId = {}", svc)
        self.assertIn("self.revision = 0", svc)

        # _clearExpired: removes effects where expiresAt <= clock; bumps revision only if changed
        self.assertIn("status.expiresAt <= now", svc)
        self.assertIn("local changed = false", svc)
        self.assertIn("if changed then", svc)

        # Apply: guards on non-empty participantId and positive duration
        self.assertIn(
            'assert(participantId ~= "", "participantId cannot be empty")',
            svc,
        )
        self.assertIn(
            'assert(durationSeconds > 0, "Status duration must be positive")',
            svc,
        )
        # Apply: expiresAt is computed as now + durationSeconds
        self.assertIn("expiresAt = now + durationSeconds,", svc)

        # Remove: returns false when effect is absent; true and bumps revision when present
        remove_start = svc.index("function StatusEffectService:Remove(")
        remove_end = svc.index("\nfunction StatusEffectService:Has(", remove_start)
        remove_fn = svc[remove_start:remove_end]
        self.assertIn("return false", remove_fn)
        self.assertIn("return true", remove_fn)

        # Has: calls _clearExpired before checking existence
        has_start = svc.index("function StatusEffectService:Has(")
        has_end = svc.index("\nfunction StatusEffectService:GetSnapshot(", has_start)
        has_fn = svc[has_start:has_end]
        self.assertIn("self:_clearExpired(participantId)", has_fn)
        self.assertIn("effects ~= nil and effects[statusId] ~= nil", has_fn)

        # GetSnapshot: also calls _clearExpired; sorts results by statusId
        snap_start = svc.index("function StatusEffectService:GetSnapshot(")
        snap_end = svc.index("\nfunction StatusEffectService:ClearParticipant(", snap_start)
        snap_fn = svc[snap_start:snap_end]
        self.assertIn("self:_clearExpired(participantId)", snap_fn)
        self.assertIn("return left.statusId < right.statusId", snap_fn)

        # TransferParticipant: previous entry removed before assignment to replacement
        xfer_start = svc.index("function StatusEffectService:TransferParticipant(")
        xfer_fn = svc[xfer_start:]
        prev_nil_pos = xfer_fn.index(
            "self.effectsByParticipantId[previousParticipantId] = nil"
        )
        replacement_pos = xfer_fn.index(
            "self.effectsByParticipantId[replacementParticipantId] = effects"
        )
        self.assertLess(prev_nil_pos, replacement_pos)

    def test_request_0146_set_monster_status_dedup_guard_custom_message_and_pulse_gate(
        self,
    ) -> None:
        effects = (ROOT / "src" / "client" / "UI" / "EffectsView.lua").read_text(
            encoding="utf-8"
        )
        fn_start = effects.index("function EffectsView:SetMonsterStatus(")
        fn_end = effects.index("\nfunction EffectsView:Update(", fn_start)
        fn = effects[fn_start:fn_end]

        # Dedup guard: skip update when statusId hasn't changed
        self.assertIn("statusId == self.lastStatus", fn)

        # nil statusId: hide overlay and return
        self.assertIn("if not statusId then", fn)
        self.assertIn("self.statusOverlay.Visible = false", fn)

        # Missing STATUS_COPY entry: also hides overlay and returns
        self.assertIn("if not presentation then", fn)

        # customMessage takes priority over catalog label
        self.assertIn("customMessage or presentation.label", fn)

        # Non-reduced-motion path: stroke tweens from 0.05 → 0.32
        self.assertIn("self.statusStroke.Transparency = 0.05", fn)
        self.assertIn("{ Transparency = 0.32 }", fn)

        # Reduced-motion path: sets 0.32 directly without tween
        self.assertIn("self.statusStroke.Transparency = 0.32", fn)

        # PULSE_STATUSES gate: only pulsing statuses trigger _startInjuryPulse
        self.assertIn("if PULSE_STATUSES[statusId] then", fn)
        self.assertIn("self:_startInjuryPulse(statusId, 0.5)", fn)

        # _startInjuryPulse: reducedMotion guard prevents pulsing
        pulse_start = effects.index("function EffectsView:_startInjuryPulse(")
        pulse_end = effects.index("\nfunction EffectsView:SetMonsterStatus(", pulse_start)
        pulse_fn = effects[pulse_start:pulse_end]
        self.assertIn(
            "self.destroyed or self.reducedMotion or not PULSE_STATUSES[statusId]",
            pulse_fn,
        )
        # Pulse tween: -1 repeat count, reversing (InOut), 0.72 target transparency
        self.assertIn("-1,", pulse_fn)
        self.assertIn("true", pulse_fn)
        self.assertIn("{ Transparency = 0.72 }", pulse_fn)
        # Delayed start: 0.5 s delay honoured by task.delay guard
        self.assertIn(
            "self.injuryPulseTween == pulseTween",
            pulse_fn,
        )

    def test_request_0145_update_phase_arc_visibility_gate_and_dot_state_styling(
        self,
    ) -> None:
        view = (ROOT / "src" / "client" / "UI" / "GameView.lua").read_text(
            encoding="utf-8"
        )
        # PHASE_ARC_ORDER must list all 6 playable phases in round order
        arc_order_start = view.index("local PHASE_ARC_ORDER: { string } = {")
        arc_order_end = view.index("\n}", arc_order_start)
        arc_order = view[arc_order_start:arc_order_end]
        for phase in (
            '"MurderPlanning"',
            '"NightTransform"',
            '"Investigation"',
            '"Day"',
            '"Campfire"',
            '"Resolution"',
        ):
            self.assertIn(phase, arc_order)

        fn_start = view.index("function GameView:_updatePhaseArc(state: any)")
        fn_end = view.index("\nfunction GameView:_updateMonsterPanel(", fn_start)
        fn = view[fn_start:fn_end]

        # Visibility: hidden for Lobby and Rewards phases; visible otherwise
        self.assertIn(
            'phase ~= "Lobby" and phase ~= "Rewards"',
            fn,
        )

        # Past dot (index < current): TextMuted, fully opaque, 8×8
        self.assertIn("dot.BackgroundColor3 = Theme.Colors.TextMuted", fn)
        self.assertIn("dot.BackgroundTransparency = 0", fn)
        self.assertIn("dot.Size = UDim2.fromOffset(8, 8)", fn)

        # Current dot (index == current): Gold, fully opaque, 12×12
        self.assertIn("dot.BackgroundColor3 = Theme.Colors.Gold", fn)
        self.assertIn("dot.Size = UDim2.fromOffset(12, 12)", fn)

        # Future dot (index > current): TextMuted, 0.65 transparent, 8×8
        self.assertIn("dot.BackgroundTransparency = 0.65", fn)

        # Gold (current) dot appears after the past-dot TextMuted+0 block
        gold_pos = fn.index("dot.BackgroundColor3 = Theme.Colors.Gold")
        first_textmuted_pos = fn.index("dot.BackgroundColor3 = Theme.Colors.TextMuted")
        self.assertLess(first_textmuted_pos, gold_pos)

        # 12×12 (current dot) appears before the 0.65 transparency (future dot)
        large_dot_pos = fn.index("dot.Size = UDim2.fromOffset(12, 12)")
        future_transparency_pos = fn.index("dot.BackgroundTransparency = 0.65")
        self.assertLess(large_dot_pos, future_transparency_pos)

    def test_request_0144_monster_panel_phase_gate_stamina_fraction_and_cooldown_rich_text(
        self,
    ) -> None:
        view = (ROOT / "src" / "client" / "UI" / "GameView.lua").read_text(
            encoding="utf-8"
        )
        panel_start = view.index("function GameView:_updateMonsterPanel(state: any")
        panel_end = view.index("function GameView:_stopTimerPulse()", panel_start)
        panel_fn = view[panel_start:panel_end]

        # Phase gate: only Investigation and NightTransform show the panel
        self.assertIn(
            'monsterActive and (phase == "Investigation" or phase == "NightTransform")',
            panel_fn,
        )

        # Stamina fraction is clamped to [0, 1]; zero when maxStamina is 0
        self.assertIn(
            "then math.clamp(stamina / maxStamina, 0, 1)",
            panel_fn,
        )
        self.assertIn("else 0", panel_fn)

        # Cooldown display: remaining > 0.5 threshold distinguishes cooling from ready
        self.assertIn("if remaining > 0.5 then", panel_fn)

        # Cooling color constant defined at module level
        self.assertIn('MONSTER_ABILITY_COOLING_RICH_COLOR = "#E27F31"', view)
        # Ready color constant defined at module level
        self.assertIn('MONSTER_ABILITY_READY_RICH_COLOR = "#DAAC4F"', view)

        # Cooling line uses COOLING color and formats countdown in seconds
        self.assertIn("MONSTER_ABILITY_COOLING_RICH_COLOR,", panel_fn)
        self.assertIn("math.ceil(remaining)", panel_fn)

        # Ready line uses READY color and appends "READY" text
        self.assertIn("MONSTER_ABILITY_READY_RICH_COLOR,", panel_fn)
        self.assertIn("READY</font>", panel_fn)

        # Fallback ability list from cooldownEndsAt keys when MONSTER_ABILITIES has no entry
        self.assertIn(
            "if #abilityIds == 0 and type(cooldowns) == \"table\" then",
            panel_fn,
        )
        self.assertIn("for abilityId in cooldowns do", panel_fn)

        # Cooling label position before ready label in the conditional
        cooling_pos = panel_fn.index("MONSTER_ABILITY_COOLING_RICH_COLOR,")
        ready_pos = panel_fn.index("MONSTER_ABILITY_READY_RICH_COLOR,")
        self.assertLess(cooling_pos, ready_pos)

    def test_request_0143_choose_participant_ghost_exclusion_injured_color_and_empty_notification(
        self,
    ) -> None:
        view = (ROOT / "src" / "client" / "UI" / "GameView.lua").read_text(
            encoding="utf-8"
        )
        func_start = view.index("function GameView:_chooseParticipant(")
        func_end = view.index("\nfunction GameView:_chooseEvidence(", func_start)
        func = view[func_start:func_end]

        # Eligibility: alive check is first, then ghost exclusion
        self.assertIn("readBoolean(participant, \"alive\", false)", func)
        self.assertIn(
            "and not readBoolean(participant, \"isGhost\", false)", func
        )
        alive_pos = func.index("readBoolean(participant, \"alive\", false)")
        ghost_pos = func.index(
            "and not readBoolean(participant, \"isGhost\", false)"
        )
        self.assertLess(alive_pos, ghost_pos)

        # includeSelf guard: participantId excluded from self when false
        self.assertIn(
            "and (includeSelf or participantId ~= ownId)", func
        )

        # Injured/Critical/Incapacitated participants get Danger color; healthy get PanelSoft
        self.assertIn(
            'if health == "Injured" or health == "Critical" or health == "Incapacitated"',
            func,
        )
        self.assertIn("then Theme.Colors.Danger", func)
        self.assertIn("else Theme.Colors.PanelSoft", func)

        # Payload receives targetParticipantId before _send is called
        self.assertIn("payload.targetParticipantId = participantId", func)
        payload_pos = func.index("payload.targetParticipantId = participantId")
        send_pos = func.index("self:_send(action, payload, button)")
        self.assertLess(payload_pos, send_pos)

        # Role-specific title: Murderer title appears before camper title
        murderer_title_pos = func.index('"Choose your target."')
        camper_title_pos = func.index(
            '"Choose the living player affected by this action."'
        )
        self.assertLess(murderer_title_pos, camper_title_pos)

        # Empty-target notification: role-specific body (Murderer before camper)
        no_target_murderer = (
            '"No targets available — all potential victims are out of reach."'
        )
        no_target_camper = (
            '"This action requires at least one other living player and was not sent."'
        )
        self.assertIn(no_target_murderer, func)
        self.assertIn(no_target_camper, func)
        self.assertLess(
            func.index(no_target_murderer), func.index(no_target_camper)
        )
        # Both empty paths share the same "Warning" notification level
        self.assertIn('"Warning"', func)

    def test_request_0158_motion_helper_guards_slide_fade_pop_cancel_and_attribute_walk(
        self,
    ) -> None:
        motion = (ROOT / "src" / "client" / "UI" / "Motion.lua").read_text(
            encoding="utf-8"
        )

        # --- safeDuration: NaN + Inf guard, clamp to [0, 3] ---
        dur_start = motion.index("local function safeDuration(")
        dur_end = motion.index("\nlocal function safeDistance(", dur_start)
        dur_fn = motion[dur_start:dur_end]
        self.assertIn("value ~= value", dur_fn)
        self.assertIn("math.abs(value) == math.huge", dur_fn)
        self.assertIn("math.clamp(value, 0, 3)", dur_fn)

        # --- safeDistance: clamp to [0, 160] ---
        dist_start = motion.index("local function safeDistance(")
        dist_end = motion.index("\nlocal function safeScale(", dist_start)
        dist_fn = motion[dist_start:dist_end]
        self.assertIn("value ~= value", dist_fn)
        self.assertIn("math.clamp(value, 0, 160)", dist_fn)

        # --- safeScale: clamp to [0.1, 3] ---
        scale_start = motion.index("local function safeScale(")
        scale_end = motion.index("\nlocal function callback(", scale_start)
        scale_fn = motion[scale_start:scale_end]
        self.assertIn("value ~= value", scale_fn)
        self.assertIn("math.clamp(value, 0.1, 3)", scale_fn)

        # --- findReducedMotionAttribute: GetAttribute walk up Parent chain ---
        attr_start = motion.index("local function findReducedMotionAttribute(")
        attr_end = motion.index("\nfunction Motion.SetReducedMotionProvider(", attr_start)
        attr_fn = motion[attr_start:attr_end]
        self.assertIn('current:GetAttribute("ReducedMotion") == true', attr_fn)
        self.assertIn("current = current.Parent", attr_fn)

        # --- cancelRecord: cancels each tween, clears tweens table, fires callback(false) ---
        cancel_start = motion.index("local function cancelRecord(")
        cancel_end = motion.index("\nlocal function begin(", cancel_start)
        cancel_fn = motion[cancel_start:cancel_end]
        self.assertIn("tween:Cancel()", cancel_fn)
        self.assertIn("table.clear(record.tweens)", cancel_fn)
        self.assertIn("activeTransitions[record.target] = nil", cancel_fn)
        self.assertIn("callback(record, false)", cancel_fn)

        # --- motionScale: reuse existing UIScale or create one named "MotionScale" ---
        ms_start = motion.index("local function motionScale(")
        ms_end = motion.index("\nlocal function pop(", ms_start)
        ms_fn = motion[ms_start:ms_end]
        self.assertIn('target:FindFirstChild("MotionScale")', ms_fn)
        self.assertIn('existing:IsA("UIScale")', ms_fn)
        self.assertIn('scale.Name = "MotionScale"', ms_fn)
        self.assertIn("scale.Scale = 1", ms_fn)

        # --- pop: scale tweened only when not reduced motion ---
        pop_start = motion.index("local function pop(")
        pop_end = motion.index("\nfunction Motion.PopIn(", pop_start)
        pop_fn = motion[pop_start:pop_end]
        self.assertIn("if not reduced then", pop_fn)
        # Appearing: scale starts at popScale → tweens to 1
        self.assertIn("scale.Scale = if appearing then popScale else 1", pop_fn)
        self.assertIn("Scale = if appearing then 1 else popScale", pop_fn)
        # pop cleanup restores scale
        self.assertIn("scale.Scale = 1", pop_fn)
        # ReducedFadeDuration used when reduced, PopDuration otherwise
        self.assertIn("Theme.Motion.ReducedFadeDuration", pop_fn)
        self.assertIn("Theme.Motion.PopDuration", pop_fn)

        # --- fade: ReducedFadeDuration vs FadeDuration selection ---
        fade_start = motion.index("local function fade(")
        fade_end = motion.index("\nfunction Motion.FadeIn(", fade_start)
        fade_fn = motion[fade_start:fade_end]
        self.assertIn("Theme.Motion.ReducedFadeDuration", fade_fn)
        self.assertIn("Theme.Motion.FadeDuration", fade_fn)
        # Appearing: first setFade transparent, then tween to opaque
        self.assertIn("setFade(properties, true)", fade_fn)
        self.assertIn("addFadeTweens(record, properties, tweenInfo, not appearing)", fade_fn)

        # --- slide: reduced path falls back to FadeIn/FadeOut ---
        slide_start = motion.index("local function slide(")
        slide_end = motion.index("\nfunction Motion.SlideUp(", slide_start)
        slide_fn = motion[slide_start:slide_end]
        self.assertIn(
            "return if appearing then Motion.FadeIn(target, resolved) else Motion.FadeOut(target, resolved)",
            slide_fn,
        )
        # Non-reduced: restingPosition captured and restored
        self.assertIn("local restingPosition = target.Position", slide_fn)
        self.assertIn("target.Position = restingPosition", slide_fn)
        # Appearing: position set to shifted(restingPosition, distance) initially
        self.assertIn(
            "target.Position = shifted(restingPosition, distance)", slide_fn
        )

        # --- shifted: only modifies Y.Offset ---
        shifted_start = motion.index("local function shifted(")
        shifted_end = motion.index("\nlocal function shiftedHorizontal(", shifted_start)
        shifted_fn = motion[shifted_start:shifted_end]
        self.assertIn("position.Y.Offset + yOffset", shifted_fn)

        # --- shiftedHorizontal: only modifies X.Offset (used by Shake) ---
        hshift_start = motion.index("local function shiftedHorizontal(")
        hshift_end = motion.index("\nlocal function slide(", hshift_start)
        hshift_fn = motion[hshift_start:hshift_end]
        self.assertIn("position.X.Offset + xOffset", hshift_fn)

        # --- StaggerChildren: preset dispatch order ---
        stagger_start = motion.index("function Motion.StaggerChildren(container: GuiObject")
        stagger_fn = motion[stagger_start:]
        # "reduced or FadeIn" branch comes before PopIn branch
        fade_preset_pos = stagger_fn.index('reduced or resolved.preset == "FadeIn"')
        pop_preset_pos = stagger_fn.index('resolved.preset == "PopIn"')
        self.assertLess(fade_preset_pos, pop_preset_pos)
        # FadeIn is the fallback for reduced motion in stagger
        self.assertIn("Motion.FadeIn(child, childConfig)", stagger_fn)
        self.assertIn("Motion.PopIn(child, childConfig)", stagger_fn)
        self.assertIn("Motion.SlideUp(child, childConfig)", stagger_fn)
        # Cleanup in stagger: restores Visible=true and cancels child transitions
        self.assertIn("child.Visible = true", stagger_fn)
        self.assertIn("Motion.Cancel(child)", stagger_fn)

    def test_request_0159_components_escape_evidence_status_button_and_clear_generated(
        self,
    ) -> None:
        comp = (ROOT / "src" / "client" / "UI" / "Components.lua").read_text(
            encoding="utf-8"
        )

        # --- escapeRichText: four HTML entity substitutions (no apostrophe) ---
        esc_start = comp.index("local function escapeRichText(")
        esc_end = comp.index("\nfunction Components.LetterspacedText(", esc_start)
        esc_fn = comp[esc_start:esc_end]
        self.assertIn('"&lt;"', esc_fn)
        self.assertIn('"&gt;"', esc_fn)
        self.assertIn('"&amp;"', esc_fn)
        self.assertIn('"&quot;"', esc_fn)
        # Pattern uses a character class (not individual gsub calls); Lua escapes " as \"
        self.assertIn('[<>&\\"]', esc_fn)
        # Single-quote is NOT in the escape map (no &apos;)
        self.assertNotIn("&apos;", esc_fn)

        # --- evidenceStatus: lowercase normalization + alias mapping ---
        ev_start = comp.index("local function evidenceStatus(")
        ev_end = comp.index("\nfunction Components.EvidenceCard(", ev_start)
        ev_fn = comp[ev_start:ev_end]
        # Normalize to lowercase first
        self.assertIn("string.lower(value)", ev_fn)
        # "confirmed" and "verifiedreal" both map to Confirmed
        self.assertIn('"confirmed"', ev_fn)
        self.assertIn('"verifiedreal"', ev_fn)
        self.assertIn('return "Confirmed"', ev_fn)
        # "contradicted" and "verifiedfake" both map to Contradicted
        self.assertIn('"contradicted"', ev_fn)
        self.assertIn('"verifiedfake"', ev_fn)
        self.assertIn('return "Contradicted"', ev_fn)
        # Default fallback
        self.assertIn('return "Unconfirmed"', ev_fn)

        # --- LetterspacedText: short-circuit + spacer format ---
        lsp_start = comp.index("function Components.LetterspacedText(")
        lsp_end = comp.index("\nfunction Components.SetLetterspacedText(", lsp_start)
        lsp_fn = comp[lsp_start:lsp_end]
        # spacing floor + max(0, ...)
        self.assertIn(
            "math.max(0, math.floor(spacing or Theme.Typography.LetterSpacing))",
            lsp_fn,
        )
        # Short-circuit: spacing==0 OR value has fewer than 2 chars
        self.assertIn("resolvedSpacing == 0 or #value < 2", lsp_fn)
        self.assertIn("return escapeRichText(value)", lsp_fn)
        # Spacer is an invisible font element
        self.assertIn('<font size="%d" transparency="1">.</font>', lsp_fn)
        # Per-character escaping
        self.assertIn("escapeRichText(string.sub(value, index, index))", lsp_fn)
        # Joined by spacer
        self.assertIn("table.concat(characters, spacer)", lsp_fn)

        # --- Components.Button: hover lerp, AutoButtonColor, debounce guards, key types ---
        btn_start = comp.index("function Components.Button(")
        btn_end = comp.index("\nfunction Components.SetButtonEnabled(", btn_start)
        btn_fn = comp[btn_start:btn_end]
        # Hover color is a 12% lerp towards white
        self.assertIn("normalColor:Lerp(Theme.Colors.White, 0.12)", btn_fn)
        # AutoButtonColor disabled (managed manually)
        self.assertIn("button.AutoButtonColor = false", btn_fn)
        # press() debounce: early return if not Active or already pressed
        self.assertIn("if not button.Active or pressed then", btn_fn)
        # release() debounce: early return if not pressed and scale already at 1
        self.assertIn("if not pressed and pressScale.Scale == 1 then", btn_fn)
        # tweenScale: reduced motion short-circuits to immediate scale reset
        self.assertIn("if Motion.IsReducedMotion(button) then", btn_fn)
        self.assertIn("pressScale.Scale = 1", btn_fn)
        # InputBegan: all five input types
        for key in (
            "Enum.UserInputType.MouseButton1",
            "Enum.UserInputType.Touch",
            "Enum.KeyCode.ButtonA",
            "Enum.KeyCode.Return",
            "Enum.KeyCode.Space",
        ):
            self.assertIn(key, btn_fn)
        # SelectionGained: gold border, thickness 3, fully opaque
        self.assertIn("border.Color = Theme.Colors.Gold", btn_fn)
        self.assertIn("border.Thickness = 3", btn_fn)
        self.assertIn("border.Transparency = 0", btn_fn)
        # SelectionLost: restore border color and thickness=1
        self.assertIn("border.Color = Theme.Colors.Border", btn_fn)
        self.assertIn("border.Thickness = 1", btn_fn)
        self.assertIn("border.Transparency = Theme.StrokeTransparency", btn_fn)
        # SelectionGained fires before SelectionLost in source
        gained_pos = btn_fn.index("border.Color = Theme.Colors.Gold")
        lost_pos = btn_fn.index("border.Color = Theme.Colors.Border")
        self.assertLess(gained_pos, lost_pos)

        # --- Components.SetButtonEnabled: transparency values and reset behaviors ---
        sbe_start = comp.index("function Components.SetButtonEnabled(")
        sbe_end = comp.index("\nfunction Components.List(", sbe_start)
        sbe_fn = comp[sbe_start:sbe_end]
        self.assertIn("button.Active = enabled", sbe_fn)
        self.assertIn("button.Selectable = enabled", sbe_fn)
        # Background: 0 when enabled, 0.45 when disabled
        self.assertIn("if enabled then 0 else 0.45", sbe_fn)
        # Text: 0 when enabled, 0.32 when disabled
        self.assertIn("if enabled then 0 else 0.32", sbe_fn)
        # Scale reset on disable (prevents stuck-pressed state)
        self.assertIn('"ButtonPressScale"', sbe_fn)
        self.assertIn('pressScale:IsA("UIScale")', sbe_fn)
        # Deselect when disabled
        self.assertIn("GuiService.SelectedObject == button", sbe_fn)
        self.assertIn("GuiService.SelectedObject = nil", sbe_fn)

        # --- Components.ClearGenerated: destroys only "Generated" == true children ---
        clr_start = comp.index("function Components.ClearGenerated(")
        clr_fn = comp[clr_start:]
        self.assertIn('child:GetAttribute("Generated") == true', clr_fn)
        self.assertIn("child:Destroy()", clr_fn)

        # --- Components.ProgressBar: key structural contracts ---
        pb_start = comp.index("function Components.ProgressBar(")
        pb_end = comp.index("\nfunction Components.ClearGenerated(", pb_start)
        pb_fn = comp[pb_start:pb_end]
        # Track clips to prevent fill overflow
        self.assertIn("track.ClipsDescendants = true", pb_fn)
        # Fill uses Success color and full-scale size
        self.assertIn("fill.BackgroundColor3 = Theme.Colors.Success", pb_fn)
        self.assertIn("fill.Size = UDim2.fromScale(1, 1)", pb_fn)
        # Text label sits above fill (ZIndex bump)
        self.assertIn("text.ZIndex = track.ZIndex + 2", pb_fn)
        self.assertIn("text.TextXAlignment = Enum.TextXAlignment.Center", pb_fn)

    def test_request_0160_accessibility_controller_defaults_evidence_shake_and_destroy(
        self,
    ) -> None:
        acc = (
            ROOT / "src" / "client" / "Controllers" / "AccessibilityController.lua"
        ).read_text(encoding="utf-8")

        # --- SettingIds: four frozen setting key constants ---
        self.assertIn('Subtitles = "subtitles"', acc)
        self.assertIn('ReducedMotion = "reducedMotion"', acc)
        self.assertIn('CameraShake = "cameraShake"', acc)
        self.assertIn('HighContrastEvidence = "highContrastEvidence"', acc)

        # --- Default settings: subtitles on, reducedMotion off, cameraShake on, highContrast off ---
        new_start = acc.index("function AccessibilityController.new(")
        new_end = acc.index("\nfunction AccessibilityController:_applyRootAttributes(", new_start)
        new_fn = acc[new_start:new_end]
        self.assertIn("subtitles = true", new_fn)
        self.assertIn("reducedMotion = false", new_fn)
        self.assertIn("cameraShake = true", new_fn)
        self.assertIn("highContrastEvidence = false", new_fn)
        self.assertIn("shakeToken = 0", new_fn)
        self.assertIn("destroyed = false", new_fn)

        # --- isTextGui: TextLabel, TextButton, TextBox only ---
        itg_start = acc.index("local function isTextGui(")
        itg_end = acc.index("\nfunction AccessibilityController.new(", itg_start)
        itg_fn = acc[itg_start:itg_end]
        self.assertIn('"TextLabel"', itg_fn)
        self.assertIn('"TextButton"', itg_fn)
        self.assertIn('"TextBox"', itg_fn)

        # --- _applyRootAttributes: sets all four attributes on roots with a parent ---
        ara_start = acc.index("function AccessibilityController:_applyRootAttributes(")
        ara_end = acc.index("\nfunction AccessibilityController:_applyEvidence(", ara_start)
        ara_fn = acc[ara_start:ara_end]
        self.assertIn("root.Parent", ara_fn)
        self.assertIn('root:SetAttribute("Subtitles"', ara_fn)
        self.assertIn('root:SetAttribute("ReducedMotion"', ara_fn)
        self.assertIn('root:SetAttribute("CameraShake"', ara_fn)
        self.assertIn('root:SetAttribute("HighContrastEvidence"', ara_fn)

        # --- _applyEvidence: creates gold UIStroke when high contrast enabled ---
        ev_start = acc.index("function AccessibilityController:_applyEvidence(")
        ev_end = acc.index("\nfunction AccessibilityController:RegisterRoot(", ev_start)
        ev_fn = acc[ev_start:ev_end]
        # Orphaned gui cleans itself out of the evidence table
        self.assertIn("self.evidence[gui] = nil", ev_fn)
        # UIStroke created with specific color and thickness
        self.assertIn('newStroke.Name = "AccessibilityEvidenceStroke"', ev_fn)
        self.assertIn("Color3.fromRGB(255, 221, 87)", ev_fn)
        self.assertIn("newStroke.Thickness = 3", ev_fn)
        self.assertIn("newStroke.Transparency = 0", ev_fn)
        # Text stroke: black color, full opacity
        self.assertIn("Color3.fromRGB(0, 0, 0)", ev_fn)
        self.assertIn("textGui.TextStrokeTransparency = 0", ev_fn)
        # On disable: destroy stroke and restore original values
        self.assertIn("stroke:Destroy()", ev_fn)
        self.assertIn("record.originalTextStrokeColor", ev_fn)
        self.assertIn("record.originalTextStrokeTransparency", ev_fn)

        # --- ScanEvidence: IsEvidence attribute OR name contains "evidence" (case-insensitive) ---
        scan_start = acc.index("function AccessibilityController:ScanEvidence(")
        scan_end = acc.index("\nfunction AccessibilityController:ApplySettings(", scan_start)
        scan_fn = acc[scan_start:scan_end]
        self.assertIn('descendant:GetAttribute("IsEvidence") == true', scan_fn)
        self.assertIn(
            'string.find(string.lower(descendant.Name), "evidence", 1, true)',
            scan_fn,
        )

        # --- ApplySettings: nil/destroyed guard + type-check gates ---
        apply_start = acc.index("function AccessibilityController:ApplySettings(")
        apply_end = acc.index("\nfunction AccessibilityController:ApplyGameState(", apply_start)
        apply_fn = acc[apply_start:apply_end]
        self.assertIn("not settings or self.destroyed", apply_fn)
        self.assertIn('type(settings.subtitles) == "boolean"', apply_fn)
        self.assertIn('type(settings.reducedMotion) == "boolean"', apply_fn)
        self.assertIn('type(settings.cameraShake) == "boolean"', apply_fn)
        self.assertIn('type(settings.highContrastEvidence) == "boolean"', apply_fn)
        # Shake cancelled when reducedMotion=true OR cameraShake=false
        self.assertIn(
            "if self.settings.reducedMotion or not self.settings.cameraShake then",
            apply_fn,
        )
        self.assertIn("self:CancelCameraShake()", apply_fn)

        # --- ApplyGameState: deep profile.profile.settings path with type guards ---
        ags_start = acc.index("function AccessibilityController:ApplyGameState(")
        ags_end = acc.index("\nfunction AccessibilityController:IsReducedMotion(", ags_start)
        ags_fn = acc[ags_start:ags_end]
        self.assertIn('type(state.profile) == "table"', ags_fn)
        self.assertIn('type(state.profile.profile) == "table"', ags_fn)
        self.assertIn("state.profile.profile.settings", ags_fn)

        # --- CanShakeCamera: requires cameraShake=true AND reducedMotion=false ---
        self.assertIn(
            "return self.settings.cameraShake and not self.settings.reducedMotion",
            acc,
        )

        # --- GetMotionDuration: 0 when reduced, else max(0, duration) ---
        self.assertIn(
            "return if self.settings.reducedMotion then 0 else math.max(0, standardDuration)",
            acc,
        )

        # --- CancelCameraShake: increments shakeToken to invalidate running shake ---
        self.assertIn("self.shakeToken += 1", acc)

        # --- ShakeCamera: clamp bounds, noise frequencies, and offset scale ---
        shake_start = acc.index("function AccessibilityController:ShakeCamera(")
        shake_end = acc.index("\nfunction AccessibilityController:Destroy(", shake_start)
        shake_fn = acc[shake_start:shake_end]
        # Guard: destroyed or not CanShakeCamera
        self.assertIn("self.destroyed or not self:CanShakeCamera()", shake_fn)
        # Strength clamped to [0, 2]; duration clamped to [0.05, 2]
        self.assertIn("math.clamp(strength, 0, 2)", shake_fn)
        self.assertIn("math.clamp(duration, 0.05, 2)", shake_fn)
        # Token invalidation inside loop
        self.assertIn("token == self.shakeToken", shake_fn)
        # Noise frequencies: 24 Hz (x), 27 Hz (y), 22 Hz (roll)
        self.assertIn("elapsed * 24", shake_fn)
        self.assertIn("elapsed * 27", shake_fn)
        self.assertIn("elapsed * 22", shake_fn)
        # Spatial offset scale: 0.08 for both x and y
        self.assertIn("x * 0.08", shake_fn)
        self.assertIn("y * 0.08", shake_fn)
        # Roll uses math.rad of strength
        self.assertIn("math.rad(safeStrength)", shake_fn)
        # Cleanup: inverse offset applied after loop
        self.assertIn("camera.CFrame * previousOffset:Inverse()", shake_fn)

        # --- Destroy: idempotent, calls CancelCameraShake, clears evidence with cleanup ---
        dest_start = acc.index("function AccessibilityController:Destroy(")
        dest_fn = acc[dest_start:]
        self.assertIn("if self.destroyed then", dest_fn)
        self.assertIn("self.destroyed = true", dest_fn)
        self.assertIn("self:CancelCameraShake()", dest_fn)
        # Resets highContrast to false before cleanup so evidence strokes are removed
        self.assertIn("self.settings.highContrastEvidence = false", dest_fn)
        self.assertIn("self:_applyEvidence(record)", dest_fn)
        self.assertIn("table.clear(self.evidence)", dest_fn)
        self.assertIn("table.clear(self.roots)", dest_fn)

    def test_request_0161_interaction_controller_inputlabel_prompts_hold_and_input_controller_activate(
        self,
    ) -> None:
        interaction = (
            ROOT / "src" / "client" / "Controllers" / "InteractionController.lua"
        ).read_text(encoding="utf-8")

        # --- inputLabel: Touch → "TAP", Unknown → "USE", else upper+strip "Button" prefix ---
        il_start = interaction.index("local function inputLabel(")
        il_end = interaction.index("\nlocal function promptPart(", il_start)
        il_fn = interaction[il_start:il_end]
        self.assertIn("Enum.ProximityPromptInputType.Touch", il_fn)
        self.assertIn('return "TAP"', il_fn)
        self.assertIn("Enum.ProximityPromptInputType.Gamepad", il_fn)
        self.assertIn("prompt.GamepadKeyCode", il_fn)
        self.assertIn("prompt.KeyboardKeyCode", il_fn)
        self.assertIn("Enum.KeyCode.Unknown", il_fn)
        # Button prefix stripped from gamepad key names
        self.assertIn('key.Name:gsub("^Button", "")', il_fn)
        self.assertIn("string.upper(", il_fn)
        # Fallback for unknown key
        self.assertIn('return "USE"', il_fn)

        # --- promptPart: parent must exist and be a BasePart ---
        pp_start = interaction.index("local function promptPart(")
        pp_end = interaction.index("\nlocal function hideDefaultPrompt(", pp_start)
        pp_fn = interaction[pp_start:pp_end]
        self.assertIn('parent:IsA("BasePart")', pp_fn)

        # --- hideDefaultPrompt: sets Custom style; saves+disables when prompts disabled ---
        hdp_start = interaction.index("local function hideDefaultPrompt(")
        hdp_end = interaction.index("\nfunction InteractionController.SetPromptsEnabled(", hdp_start)
        hdp_fn = interaction[hdp_start:hdp_end]
        self.assertIn('instance:IsA("ProximityPrompt")', hdp_fn)
        self.assertIn("Enum.ProximityPromptStyle.Custom", hdp_fn)
        # Saves original Enabled value before forcing to false
        self.assertIn("ghostDisabledPrompts[instance] == nil", hdp_fn)
        self.assertIn("ghostDisabledPrompts[instance] = instance.Enabled", hdp_fn)
        self.assertIn("instance.Enabled = false", hdp_fn)

        # --- SetPromptsEnabled: enable path restores and clears; disable path scans Workspace ---
        spe_start = interaction.index("function InteractionController.SetPromptsEnabled(")
        spe_end = interaction.index("\nfunction InteractionController.Start(", spe_start)
        spe_fn = interaction[spe_start:spe_end]
        # Enable: restore wasEnabled (if prompt still has a parent), then clear table
        self.assertIn("prompt.Parent", spe_fn)
        self.assertIn("prompt.Enabled = wasEnabled", spe_fn)
        self.assertIn("table.clear(ghostDisabledPrompts)", spe_fn)
        # Disable: saves existing enabled state before forcing false
        self.assertIn("ghostDisabledPrompts[descendant] == nil", spe_fn)
        self.assertIn("ghostDisabledPrompts[descendant] = descendant.Enabled", spe_fn)
        self.assertIn("descendant.Enabled = false", spe_fn)

        # --- PromptShown: early return when prompts disabled; part vs non-part dispatch ---
        shown_start = interaction.index("ProximityPromptService.PromptShown:Connect(")
        shown_end = interaction.index("ProximityPromptService.PromptHidden:Connect(", shown_start)
        shown_block = interaction[shown_start:shown_end]
        self.assertIn("if not promptsEnabled then", shown_block)
        # Part path: registers zone, starts at 0, makes visible, hides legacy UI
        self.assertIn("proximityController:RegisterZone(part, prompt.ActionText, hint)", shown_block)
        self.assertIn("proximityController:SetProgress(part, 0)", shown_block)
        self.assertIn("callbacks.hidden()", shown_block)
        # Non-part path: passes ActionText + ObjectText + hint
        self.assertIn("callbacks.shown(prompt.ActionText, prompt.ObjectText, hint)", shown_block)

        # --- PromptButtonHoldBegan: minimum hold duration 0.01 ---
        hold_start = interaction.index("ProximityPromptService.PromptButtonHoldBegan:Connect(")
        hold_end = interaction.index("ProximityPromptService.PromptButtonHoldEnded:Connect(", hold_start)
        hold_block = interaction[hold_start:hold_end]
        self.assertIn("math.max(prompt.HoldDuration, 0.01)", hold_block)
        self.assertIn("proximityController:SetProgress(part, 0)", hold_block)

        # --- PromptTriggered: early return if disabled; SetProgress(1); part from hold or promptPart ---
        trig_start = interaction.index("ProximityPromptService.PromptTriggered:Connect(")
        trig_end = interaction.index("RunService.RenderStepped:Connect(", trig_start)
        trig_block = interaction[trig_start:trig_end]
        self.assertIn("if not promptsEnabled then", trig_block)
        self.assertIn("local part = if hold then hold.part else promptPart(prompt)", trig_block)
        self.assertIn("proximityController:SetProgress(part, 1)", trig_block)

        # --- RenderStepped: orphan cleanup when prompt or part loses its parent ---
        rs_start = interaction.index("RunService.RenderStepped:Connect(")
        rs_fn = interaction[rs_start:]
        self.assertIn("not prompt.Parent or not hold.part.Parent", rs_fn)

        # --- InputController: activate wrapper and selectOffset formula ---
        inputs = (
            ROOT / "src" / "client" / "Controllers" / "InputController.lua"
        ).read_text(encoding="utf-8")

        # activate: only fires on Begin; always Sinks
        act_start = inputs.index("local function activate(")
        act_end = inputs.index("\nfunction InputController.Start(", act_start)
        act_fn = inputs[act_start:act_end]
        self.assertIn("inputState == Enum.UserInputState.Begin", act_fn)
        self.assertIn("return Enum.ContextActionResult.Sink", act_fn)

        # selectOffset: wrapping modulo formula
        self.assertIn(
            "selectedSlot = ((selectedSlot - 1 + offset) % count) + 1",
            inputs,
        )
        # count clamped to max 15
        self.assertIn("math.clamp(callbacks.getSlotCount(), 0, 15)", inputs)

        # Notebook action name + touch-specific setup
        self.assertIn('local ACTION_NOTEBOOK = "CampMysteryNotebook"', inputs)
        self.assertIn("ContextActionService:SetTitle(ACTION_NOTEBOOK, \"CLUES\")", inputs)
        self.assertIn(
            "ContextActionService:SetPosition(ACTION_NOTEBOOK, UDim2.new(1, -150, 1, -190))",
            inputs,
        )
        self.assertIn(
            'ContextActionService:SetImage(ACTION_NOTEBOOK, "")',
            inputs,
        )

        # Stop unbinds all seven named actions and the slot loop
        stop_start = inputs.index("function InputController.Stop(")
        stop_fn = inputs[stop_start:]
        self.assertIn("UnbindAction(ACTION_NOTEBOOK)", stop_fn)
        self.assertIn("UnbindAction(ACTION_PLAYER_STATUS)", stop_fn)
        self.assertIn("UnbindAction(ACTION_SETTINGS)", stop_fn)
        self.assertIn("UnbindAction(ACTION_CLOSE)", stop_fn)
        self.assertIn("UnbindAction(ACTION_SLOT_PREVIOUS)", stop_fn)
        self.assertIn("UnbindAction(ACTION_SLOT_NEXT)", stop_fn)
        self.assertIn("UnbindAction(ACTION_SLOT_USE)", stop_fn)
        # Slot loop unregisters all 10 numeric slot actions
        self.assertIn('"CampMysterySlot" .. tostring(slot)', stop_fn)

    def test_request_0162_tutorial_controller_context_dispatch_all_seen_finish_and_lifecycle(
        self,
    ) -> None:
        tut = (
            ROOT / "src" / "client" / "Controllers" / "TutorialController.lua"
        ).read_text(encoding="utf-8")

        # --- currentContext: type guards ---
        ctx_start = tut.index("local function currentContext(state: any)")
        ctx_end = tut.index("\nfunction TutorialController.new(", ctx_start)
        ctx_fn = tut[ctx_start:ctx_end]
        self.assertIn('type(state) ~= "table"', ctx_fn)
        self.assertIn('type(round) ~= "table"', ctx_fn)

        # Lobby is checked first before any role dispatch
        self.assertIn('if phase == "Lobby" then', ctx_fn)
        self.assertIn('return "Lobby"', ctx_fn)

        # Spectator short-circuit (before Murderer check)
        lobby_pos = ctx_fn.index('return "Lobby"')
        spectator_pos = ctx_fn.index('return "Spectator"')
        murderer_pos = ctx_fn.index('role == "Murderer"')
        self.assertLess(lobby_pos, spectator_pos)
        self.assertLess(spectator_pos, murderer_pos)

        # Murderer phase dispatch: four phases map to murderer-specific contexts
        self.assertIn('return "MurderPlanningMurderer"', ctx_fn)
        self.assertIn('return "NightTransformMurderer"', ctx_fn)
        self.assertIn('return "InvestigationMurderer"', ctx_fn)
        self.assertIn('return "VoteMurderer"', ctx_fn)

        # Investigation: Evidence context when evidenceFound > 0
        self.assertIn('readNumber(round, "evidenceFound", 0)', ctx_fn)
        self.assertIn("if evidenceFound > 0 then", ctx_fn)
        self.assertIn('return "Evidence"', ctx_fn)
        # Falls back to Investigation when evidenceFound == 0
        self.assertIn('return "Investigation"', ctx_fn)

        # Resolution and Rewards both map to Rewards context
        self.assertIn('"Resolution" or phase == "Rewards"', ctx_fn)
        self.assertIn('return "Rewards"', ctx_fn)

        # --- buildSteps: injects position and total into each step ---
        build_start = tut.index("local function buildSteps()")
        build_end = tut.index("\nlocal function readString(", build_start)
        build_fn = tut[build_start:build_end]
        self.assertIn("position = index,", build_fn)
        self.assertIn("total = total,", build_fn)
        self.assertIn("local total = #STEP_COPY", build_fn)

        # --- _allSeen: role-aware step filtering ---
        all_start = tut.index("function TutorialController:_allSeen()")
        all_end = tut.index("\nfunction TutorialController:_finish(", all_start)
        all_fn = tut[all_start:all_end]
        # Spectator step is skipped for non-Spectator roles
        self.assertIn(
            'if step.id == TutorialController.StepIds.Spectator then', all_fn
        )
        self.assertIn('if role ~= "Spectator" then', all_fn)
        self.assertIn("continue", all_fn)
        # Murderer steps skipped when role != Murderer; camper steps skipped when Murderer
        self.assertIn(
            '(murdererStep and role ~= "Murderer") or (camperEquivalent and role == "Murderer")',
            all_fn,
        )
        # Returns false when any relevant step is unseen
        self.assertIn("if not self.seen[step.id] then", all_fn)
        self.assertIn("return false", all_fn)

        # --- _finish: idempotent; sets completed; fires onCompleted with skipped flag ---
        fin_start = tut.index("function TutorialController:_finish(")
        fin_end = tut.index("\nfunction TutorialController:_show(", fin_start)
        fin_fn = tut[fin_start:fin_end]
        self.assertIn("if self.completed then", fin_fn)
        self.assertIn("self.completed = true", fin_fn)
        self.assertIn("self.activeStep = nil", fin_fn)
        self.assertIn("self.view:Hide()", fin_fn)
        self.assertIn("self.onCompleted(skipped)", fin_fn)

        # --- Update: same-context no-op; marks active seen on context change ---
        upd_start = tut.index("function TutorialController:Update(")
        upd_end = tut.index("\nfunction TutorialController:Advance(", upd_start)
        upd_fn = tut[upd_start:upd_end]
        self.assertIn("if self.completed or self.destroyed then", upd_fn)
        self.assertIn("self.lastState = state", upd_fn)
        # Same context: early return
        self.assertIn("if active.context == context then", upd_fn)
        # Context change: mark seen, clear active, hide
        self.assertIn("self.seen[active.id] = true", upd_fn)
        self.assertIn("self.activeStep = nil", upd_fn)
        # If no step found and all seen: _finish(false)
        self.assertIn("elseif self:_allSeen() then", upd_fn)
        self.assertIn("self:_finish(false)", upd_fn)

        # --- Advance: marks seen, hides, then re-runs Update ---
        adv_start = tut.index("function TutorialController:Advance()")
        adv_end = tut.index("\nfunction TutorialController:Skip()", adv_start)
        adv_fn = tut[adv_start:adv_end]
        self.assertIn("self.seen[active.id] = true", adv_fn)
        self.assertIn("self.view:Hide()", adv_fn)
        self.assertIn("self:Update(self.lastState)", adv_fn)
        # allSeen → _finish(false) before Update
        self.assertIn("if self:_allSeen() then", adv_fn)

        # --- Skip: marks all steps seen, calls _finish(true) ---
        skip_start = tut.index("function TutorialController:Skip()")
        skip_end = tut.index("\nfunction TutorialController:SetReducedMotion(", skip_start)
        skip_fn = tut[skip_start:skip_end]
        self.assertIn("for _, step in self.steps do", skip_fn)
        self.assertIn("self.seen[step.id] = true", skip_fn)
        self.assertIn("self:_finish(true)", skip_fn)

        # --- SetCompleted: silently marks done without firing onCompleted ---
        sc_start = tut.index("function TutorialController:SetCompleted(")
        sc_end = tut.index("\nfunction TutorialController:IsCompleted(", sc_start)
        sc_fn = tut[sc_start:sc_end]
        self.assertIn("if completed and not self.completed then", sc_fn)
        self.assertIn("self.completed = true", sc_fn)
        self.assertIn("self.view:Hide()", sc_fn)
        # onCompleted must NOT be called (silent sync — not a real completion)
        self.assertNotIn("self.onCompleted", sc_fn)

        # --- UIAssetController: normalizeAssetId guards ---
        asset = (
            ROOT / "src" / "client" / "Controllers" / "UIAssetController.lua"
        ).read_text(encoding="utf-8")
        norm_start = asset.index("local function normalizeAssetId(")
        norm_end = asset.index("\nlocal function findRoot(", norm_start)
        norm_fn = asset[norm_start:norm_end]
        # String: two patterns
        self.assertIn('"^%s*(%d+)%s*$"', norm_fn)
        self.assertIn('"^rbxassetid://(%d+)$"', norm_fn)
        # Number: NaN guard (value == value), positive, not infinite, integer
        self.assertIn("value == value", norm_fn)
        self.assertIn("value > 0", norm_fn)
        self.assertIn("value < math.huge", norm_fn)
        self.assertIn("value % 1 == 0", norm_fn)
        self.assertIn('string.format("%.0f", value)', norm_fn)
        # Requires at least one non-zero digit (rejects "000")
        self.assertIn('string.find(digits, "[1-9]")', norm_fn)
        # Result always prefixed
        self.assertIn('"rbxassetid://" .. digits', norm_fn)

        # Resolve: five child type resolution paths
        res_start = asset.index("function UIAssetController:Resolve(")
        res_end = asset.index("\nfunction UIAssetController:Destroy(", res_start)
        res_fn = asset[res_start:res_end]
        # Key length and pattern validation
        self.assertIn("#key == 0 or #key > 64", res_fn)
        self.assertIn('"^[%w_%-]+$"', res_fn)
        # Root re-fetch when nil or orphaned
        self.assertIn("root.Parent == nil", res_fn)
        # Attribute lookup first
        self.assertIn("root:GetAttribute(key)", res_fn)
        # Five child types
        self.assertIn('asset:IsA("StringValue")', res_fn)
        self.assertIn('asset:IsA("NumberValue")', res_fn)
        self.assertIn('asset:IsA("ImageLabel")', res_fn)
        self.assertIn('asset:IsA("ImageButton")', res_fn)
        self.assertIn('asset:GetAttribute("AssetId")', res_fn)

    def test_request_0163_remote_bridge_emit_bind_has_action_request_and_destroy(
        self,
    ) -> None:
        bridge = (
            ROOT / "src" / "client" / "Controllers" / "RemoteBridge.lua"
        ).read_text(encoding="utf-8")

        # --- Channel and action tables wired correctly ---
        # SNAPSHOT_EVENTS: game channel receives GameStateChanged
        self.assertIn('GameStateChanged = "game"', bridge)
        # GETTERS: GetGameState maps to game channel
        self.assertIn('GetGameState = "game"', bridge)
        # ACTION_REMOTES: production path for UseRoleAbility
        self.assertIn('UseRoleAbility = { "RoleAction"', bridge)
        # Vote uses payload.targetKey (not raw payload)
        self.assertIn('remote:FireServer(payload.targetKey)', bridge)
        # Ready uses payload.ready
        self.assertIn('remote:FireServer(payload.ready)', bridge)

        # --- _emit: destroyed guard; game channel sets productionReady; pcall wraps handlers ---
        emit_start = bridge.index("function RemoteBridge:_emit(")
        emit_end = bridge.index("\nfunction RemoteBridge:_bind(", emit_start)
        emit_fn = bridge[emit_start:emit_end]
        self.assertIn("if self.destroyed then", emit_fn)
        self.assertIn('if channel == "game" and type(payload) == "table" then', emit_fn)
        self.assertIn("self.productionReady = true", emit_fn)
        self.assertIn("pcall(handler, payload)", emit_fn)
        self.assertIn('"[RemoteBridge] Snapshot handler failed:"', emit_fn)

        # --- _bind: dedup via boundNames; ActionResult wired separately ---
        bind_start = bridge.index("function RemoteBridge:_bind(")
        bind_end = bridge.index("\nfunction RemoteBridge:Start(", bind_start)
        bind_fn = bridge[bind_start:bind_end]
        self.assertIn("self.boundNames[instance.Name]", bind_fn)
        self.assertIn("self.boundNames[instance.Name] = true", bind_fn)
        # Normal snapshot events via SNAPSHOT_EVENTS lookup
        self.assertIn("SNAPSHOT_EVENTS[instance.Name]", bind_fn)
        self.assertIn('instance:IsA("RemoteEvent")', bind_fn)
        # ActionResult is its own branch (not via SNAPSHOT_EVENTS)
        self.assertIn('instance.Name == "ActionResult"', bind_fn)
        self.assertIn("self.resultHandlers", bind_fn)

        # --- Start: binds children + watches ChildAdded + fetches via GetterRemotes ---
        start_start = bridge.index("function RemoteBridge:Start()")
        start_end = bridge.index("\nfunction RemoteBridge:OnSnapshot(", start_start)
        start_fn = bridge[start_start:start_end]
        self.assertIn("self.remotes:GetChildren()", start_fn)
        self.assertIn("self.remotes.ChildAdded:Connect(", start_fn)
        # Getter loop invokes each RemoteFunction and emits result
        self.assertIn("for remoteName, channel in GETTERS do", start_fn)
        self.assertIn("instance:InvokeServer()", start_fn)
        self.assertIn("if ok and not self.destroyed then", start_fn)

        # --- HasAction: production override; candidates fallback ---
        ha_start = bridge.index("function RemoteBridge:HasAction(")
        ha_end = bridge.index("\nfunction RemoteBridge:Request(", ha_start)
        ha_fn = bridge[ha_start:ha_end]
        self.assertIn("if self.destroyed then", ha_fn)
        # productionReady + RequestAction remote → always true
        self.assertIn('"RequestAction"', ha_fn)
        self.assertIn(
            "if self.productionReady and productionRemote and productionRemote:IsA(\"RemoteFunction\") then",
            ha_fn,
        )
        # Unknown action → false (no candidates)
        self.assertIn("if not candidates then", ha_fn)
        self.assertIn("return false", ha_fn)
        # Any matching remote in candidates → true
        self.assertIn("self.remotes:FindFirstChild(name)", ha_fn)

        # --- Request: all major paths ---
        req_start = bridge.index("function RemoteBridge:Request(")
        req_end = bridge.index("\nfunction RemoteBridge:Destroy(", req_start)
        req_fn = bridge[req_start:req_end]
        # Destroyed path
        self.assertIn('"The camp radio is disconnected."', req_fn)
        # Type guard for action and payload
        self.assertIn('type(action) ~= "string" or action == ""', req_fn)
        self.assertIn('type(payload) ~= "table"', req_fn)
        self.assertIn('"Invalid action request."', req_fn)
        # Generation invalidation: stale response discarded
        self.assertIn("local generation = self.requestGeneration", req_fn)
        self.assertIn("generation ~= self.requestGeneration", req_fn)
        # Failure in production path sends structured error to result handlers
        self.assertIn('"The camp radio did not answer. Try again."', req_fn)
        # Legacy path unknown action
        self.assertIn('"Unknown action"', req_fn)
        # No remote found in candidates
        self.assertIn('"That action is not available yet."', req_fn)

        # --- Destroy: increments generation to invalidate pending requests ---
        dest_start = bridge.index("function RemoteBridge:Destroy()")
        dest_fn = bridge[dest_start:]
        self.assertIn("if self.destroyed then", dest_fn)
        self.assertIn("self.requestGeneration += 1", dest_fn)
        self.assertIn("connection:Disconnect()", dest_fn)
        self.assertIn("table.clear(self.connections)", dest_fn)
        self.assertIn("table.clear(self.snapshotHandlers)", dest_fn)
        self.assertIn("table.clear(self.resultHandlers)", dest_fn)
        self.assertIn("table.clear(self.boundNames)", dest_fn)


if __name__ == "__main__":
    unittest.main(verbosity=2)
