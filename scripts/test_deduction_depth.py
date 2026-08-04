"""Contract tests for the deduction-depth features: evidence combos, the
contradiction evidence hook, the cold case archive, locked rooms + keys, and
the outskirts supply cache."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def block(source: str, start_marker: str, end_marker: str) -> str:
    start = source.index(start_marker)
    end = source.index(end_marker, start)
    return source[start:end]


class EvidenceComboConfigTests(unittest.TestCase):
    def test_combo_recipes_reference_real_templates_and_seeded_count(self) -> None:
        combos = read("src/server/Config/EvidenceComboRules.lua")
        rules = read("src/server/Config/EvidenceRules.lua")

        recipe_ids = re.findall(r'id = "(combo-[a-z\-]+)"', combos)
        self.assertGreaterEqual(len(recipe_ids), 3, "Need a pool of at least three recipes")
        self.assertEqual(len(recipe_ids), len(set(recipe_ids)), "Recipe IDs must be unique")

        input_pairs = re.findall(r'inputTemplateIds = \{ "([a-z\-]+)", "([a-z\-]+)" \}', combos)
        self.assertEqual(
            len(input_pairs), len(recipe_ids), "Every recipe needs exactly two inputs"
        )
        insight_ids = re.findall(r'insightTemplateId = "(insight-[a-z\-]+)"', combos)
        self.assertEqual(len(insight_ids), len(recipe_ids))

        template_ids = set(re.findall(r'\["([a-z\-]+)"\] = \{', rules))
        for first, second in input_pairs:
            self.assertIn(first, template_ids, f"Unknown combo input template {first}")
            self.assertIn(second, template_ids, f"Unknown combo input template {second}")
            self.assertNotEqual(first, second, "Combo inputs must differ")
        for insight_id in insight_ids:
            self.assertIn(insight_id, template_ids, f"Unknown insight template {insight_id}")

        # 2-3 seeded recipes per round.
        per_round = re.search(r"recipesPerRound = (\d+)", combos)
        assert per_round is not None
        self.assertIn(int(per_round.group(1)), (2, 3))
        self.assertIn("invalidComboCooldownSeconds", combos)

    def test_combo_inputs_are_always_collectible(self) -> None:
        # Every recipe input must be part of the baseline evidence generated
        # for every round, so any seeded recipe subset is completable.
        combos = read("src/server/Config/EvidenceComboRules.lua")
        evidence_svc = read("src/server/Services/EvidenceService.lua")
        baseline = block(
            evidence_svc,
            "function EvidenceService:GenerateBaselineMystery(",
            "function EvidenceService:CreateAttackEvidence(",
        )
        for first, second in re.findall(
            r'inputTemplateIds = \{ "([a-z\-]+)", "([a-z\-]+)" \}', combos
        ):
            self.assertIn(f'"{first}"', baseline, f"{first} is not baseline evidence")
            self.assertIn(f'"{second}"', baseline, f"{second} is not baseline evidence")

    def test_insight_templates_use_insight_channel(self) -> None:
        rules = read("src/server/Config/EvidenceRules.lua")
        for match in re.finditer(r'\["(insight-[a-z\-]+)"\] = \{(.*?)\},', rules, re.DOTALL):
            self.assertIn(
                'channel = "Insight"', match.group(2), f"{match.group(1)} must be Insight"
            )
        types = read("src/shared/Types/EvidenceTypes.lua")
        self.assertIn('"Culprit" | "Monster" | "Insight"', types)

    def test_board_snapshot_routes_insights_to_culprit_column(self) -> None:
        evidence_svc = read("src/server/Services/EvidenceService.lua")
        snapshot = block(
            evidence_svc,
            "function EvidenceService:GetBoardSnapshot(",
            "return EvidenceService",
        )
        self.assertIn('if record.channel == "Monster"', snapshot)
        self.assertIn("then monsterEvidence", snapshot)
        self.assertIn("else culpritEvidence", snapshot)


class CombineActionTests(unittest.TestCase):
    def test_combine_action_is_declared_and_dispatched(self) -> None:
        runtime_types = read("src/shared/Types/RuntimeTypes.lua")
        self.assertIn('| "CombineEvidence"', runtime_types)
        runtime = read("src/server/Services/GameRuntimeService.lua")
        self.assertIn('elseif actionName == "CombineEvidence" then', runtime)
        self.assertIn("return self:_combineEvidence(participant, payload)", runtime)
        # Availability gating mirrors the dispatch gating.
        self.assertIn('elseif name == "CombineEvidence" then', runtime)

    def test_combine_is_detective_gated_with_cooldown_and_custody(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        combine = block(
            runtime,
            "function GameRuntimeService:_combineEvidence(",
            "local GHOST_FLICKER_COOLDOWN_SECONDS",
        )
        self.assertIn('participant.role ~= "Detective"', combine)
        self.assertIn(
            'self.phase ~= "Investigation" and self.phase ~= "Campfire"', combine
        )
        # Ownership: the Detective must be in both cards' chain of custody.
        self.assertIn("table.find(firstRecord.chainOfCustody, participantId)", combine)
        self.assertIn("table.find(secondRecord.chainOfCustody, participantId)", combine)
        # Invalid pairs get a gentle cooldown; valid recipes are once-per-round.
        self.assertIn("EvidenceComboRules.invalidComboCooldownSeconds", combine)
        self.assertIn("self.usedComboRecipeIds[matched.id] = true", combine)
        self.assertIn("not self.usedComboRecipeIds[recipe.id]", combine)

    def test_recipes_are_seeded_per_round(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        seed_block = block(
            runtime,
            "function GameRuntimeService:_seedDeductionDepth(",
            "function GameRuntimeService:_spawnRoundKeys(",
        )
        self.assertIn("EvidenceComboRules.recipesPerRound", seed_block)
        self.assertIn("Random.new(", seed_block)
        # Round reset clears combo state so recipes never leak across rounds.
        self.assertIn("self.activeComboRecipes = {}", runtime)
        self.assertIn("self.usedComboRecipeIds = {}", runtime)

    def test_client_offers_combine_flow_and_insight_accent(self) -> None:
        view = read("src/client/UI/GameView.lua")
        self.assertIn('self:_available(state, "CombineEvidence")', view)
        self.assertIn('self:_send("CombineEvidence", {', view)
        self.assertIn("comboSelectionId", view)
        self.assertIn('recordChannel == "INSIGHT"', view)
        components = read("src/client/UI/Components.lua")
        self.assertIn("accentColor: Color3?", components)
        self.assertIn("entry.accentColor or Theme.Colors.Gold", components)
        bridge = read("src/client/Controllers/RemoteBridge.lua")
        self.assertIn(
            'CombineEvidence = { "EvidenceAction", "RequestEvidenceAction" }', bridge
        )


class ContradictionEvidenceHookTests(unittest.TestCase):
    def test_counselor_service_fires_slip_callback_once_per_pair(self) -> None:
        counselor = read("src/server/Services/CounselorService.lua")
        self.assertIn(
            "onContradictionSlip: ((participantId: string, counselorId: CounselorId) -> ())?",
            counselor,
        )
        dialogue = block(
            counselor,
            "function CounselorService:RequestDialogue(",
            "function CounselorService:GetContradictionCounselorId(",
        )
        # The callback fires exactly in the dialogueCount == 2 slip branch.
        slip = block(dialogue, "if dialogueCount == 2 then", "elseif topic ==")
        self.assertIn("onContradictionSlip(participantId, counselorId)", slip)

    def test_runtime_emits_witness_card_once_per_round(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        hook = block(
            runtime,
            "function GameRuntimeService:_onContradictionSlip(",
            "function GameRuntimeService:_pickupRoomKey(",
        )
        self.assertIn("if self.contradictionEvidenceIssued", hook)
        self.assertIn('"witness-story-change"', hook)
        self.assertIn("self.contradictionEvidenceIssued = true", hook)
        # The card exists in the evidence rules with the witness framing.
        rules = read("src/server/Config/EvidenceRules.lua")
        self.assertIn('["witness-story-change"]', rules)
        self.assertIn('displayName = "The Story Changed"', rules)
        # Reset with every round.
        self.assertIn("self.contradictionEvidenceIssued = false", runtime)


class ColdCaseArchiveTests(unittest.TestCase):
    def test_archive_covers_every_monster(self) -> None:
        archive = read("src/server/Config/ColdCaseArchive.lua")
        monster_order = read("src/shared/Config/MonsterOrder.lua")
        monsters = re.findall(r'"([A-Za-z]+)",', monster_order)
        self.assertGreaterEqual(len(monsters), 8)
        sightings = block(archive, "monsterSightings = {", "monsterEchoes = {")
        echoes = block(archive, "monsterEchoes = {", "culpritPatterns = {")
        for monster in monsters:
            self.assertIn(f"{monster} = ", sightings, f"No sighting for {monster}")
            self.assertIn(f"{monster} = ", echoes, f"No echo for {monster}")
        self.assertGreaterEqual(len(re.findall(r'^\t\t"', archive, re.MULTILINE)), 3)

    def test_files_seed_from_unused_titles_and_true_monster(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        seed_block = block(
            runtime,
            "function GameRuntimeService:_seedDeductionDepth(",
            "function GameRuntimeService:_spawnRoundKeys(",
        )
        self.assertIn("MysteryCatalog.titles", seed_block)
        self.assertIn("if title ~= currentTitle then", seed_block)
        self.assertIn("ColdCaseArchive.monsterSightings[monsterId]", seed_block)
        self.assertIn("ColdCaseArchive.monsterEchoes[monsterId]", seed_block)
        self.assertIn("ColdCaseArchive.culpritPatterns", seed_block)

    def test_reading_all_three_grants_capped_reward_once(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        inspect = block(
            runtime,
            "function GameRuntimeService:_inspectColdCase(",
            "function GameRuntimeService:_openSupplyCache(",
        )
        self.assertIn("readCount >= #self.coldCaseFiles", inspect)
        self.assertIn(
            "not self.coldCaseCompletedByParticipantId[participant.participantId]",
            inspect,
        )
        self.assertIn('self.phase ~= "Investigation"', inspect)
        # Reward plumbing: runtime -> ProfileService -> RewardCalculation.
        self.assertIn("coldCasesReviewed = if self.coldCaseCompletedByParticipantId[", runtime)
        profile = read("src/server/Services/ProfileService.lua")
        self.assertIn("coldCasesReviewed = finiteNumber(input.coldCasesReviewed, 0)", profile)
        rewards = read("src/server/Systems/RewardCalculation.lua")
        self.assertIn(
            "math.min(math.floor(input.coldCasesReviewed or 0), 1) * 15", rewards
        )
        types = read("src/shared/Types/ProfileTypes.lua")
        self.assertIn("coldCasesReviewed: number?", types)

    def test_map_builds_three_file_cabinet_in_police_station(self) -> None:
        map_service = read("src/server/Services/ProductionMapService.lua")
        cabinet = block(
            map_service,
            "function ProductionMapService:_buildColdCaseCabinet(",
            "local LOCKED_ROOM_DEFINITIONS",
        )
        self.assertIn('"ColdCaseCabinet"', cabinet)
        self.assertIn("for fileIndex = 1, 3 do", cabinet)
        self.assertIn("self.coldCaseHandler", cabinet)


class LockedRoomsAndKeysTests(unittest.TestCase):
    def test_key_pool_and_room_targets(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        self.assertIn('local LOCKED_ROOM_IDS = { "motel-room-3", "police-evidence-room" }', runtime)
        spot_ids = re.findall(r'id = "(pine-mattress|lodge-radio-desk|creek-footlocker|boathouse-canoe|lookout-desk)"', runtime)
        self.assertEqual(len(set(spot_ids)), 5, "Key hiding pool must keep five spots")
        # Each locked room caches exactly two bonus cards.
        caches = block(runtime, "local LOCKED_ROOM_CACHES", "local SUPPLY_CACHE_SPOTS")
        self.assertEqual(len(re.findall(r"templateId = ", caches)), 4)

    def test_keys_are_day_only_and_personal(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        pickup = block(
            runtime,
            "function GameRuntimeService:_pickupRoomKey(",
            "function GameRuntimeService:_openLockedRoom(",
        )
        self.assertIn('self.phase ~= "Day"', pickup)
        self.assertIn("if self.keyHolderByRoomId[keyId] then", pickup)
        # Unfound keys vanish at dusk.
        self.assertIn("self.map:ClearDayKeys()", runtime)

    def test_locked_door_requires_matching_key_at_night(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        open_room = block(
            runtime,
            "function GameRuntimeService:_openLockedRoom(",
            "function GameRuntimeService:_inspectColdCase(",
        )
        self.assertIn('self.phase ~= "Investigation"', open_room)
        self.assertIn(
            "self.keyHolderByRoomId[roomId] ~= participant.participantId", open_room
        )
        self.assertIn("self.openedRoomIds[roomId] = true", open_room)

    def test_map_locked_room_props_and_reset(self) -> None:
        map_service = read("src/server/Services/ProductionMapService.lua")
        self.assertIn('existingDoorName = "MotelDoor3"', map_service)
        self.assertIn('roomId = "police-evidence-room"', map_service)
        for method in (
            "SpawnDayKeys",
            "ClearDayKeys",
            "ResetLockedRooms",
            "SetKeyPickupHandler",
            "SetLockedRoomHandler",
            "SetColdCaseHandler",
            "SetSupplyCacheHandler",
            "SpawnSupplyCache",
            "ClearSupplyCache",
        ):
            self.assertIn(
                f"function ProductionMapService:{method}(", map_service,
                f"ProductionMapService is missing {method}",
            )
        reset = block(
            map_service,
            "function ProductionMapService:ResetRound(",
            "return ProductionMapService",
        )
        self.assertIn("self:ClearDayKeys()", reset)
        self.assertIn("self:ClearSupplyCache()", reset)
        self.assertIn("self:ResetLockedRooms()", reset)

    def test_evidence_goal_never_requires_bonus_features(self) -> None:
        # Baseline mystery always creates five evidence records plus the
        # optional planted token; the board-based goal must stay reachable
        # without keys, combos, or the contradiction card.
        round_config = read("src/shared/Config/RoundConfig.lua")
        goal = re.search(r"evidenceGoal = (\d+)", round_config)
        assert goal is not None
        self.assertLessEqual(int(goal.group(1)), 5)


class SupplyCacheTests(unittest.TestCase):
    def test_cache_is_seeded_single_claim_and_mirrors_flare_grant(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        self.assertIn("local SUPPLY_CACHE_SPOTS", runtime)
        self.assertIn("self.map:SpawnSupplyCache(", runtime)
        cache = block(
            runtime,
            "function GameRuntimeService:_openSupplyCache(",
            "function GameRuntimeService:_combineEvidence(",
        )
        self.assertIn("if self.supplyCacheClaimedBy then", cache)
        self.assertIn('self.inventory:Grant(', cache)
        self.assertIn('"FlareLantern"', cache)
        self.assertIn("self.participants:AddInventoryItem(participant.participantId, instanceId)", cache)

    def test_cache_prompt_uses_three_second_hold(self) -> None:
        map_service = read("src/server/Services/ProductionMapService.lua")
        spawn = block(
            map_service,
            "function ProductionMapService:SpawnSupplyCache(",
            "function ProductionMapService:ClearSupplyCache(",
        )
        self.assertIn('createPrompt(crate, "Pry Open", "Weathered supply cache", 3)', spawn)


if __name__ == "__main__":
    unittest.main(verbosity=2)
