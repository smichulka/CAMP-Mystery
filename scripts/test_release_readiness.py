"""Deterministic release-readiness tests that run without Roblox Studio.

The suite combines static source contracts with pure-Python reference simulations.
It deliberately does not claim to execute Luau, Roblox services, physics, navigation,
replication, audio, or DataStore behavior; those remain explicit Studio gates.
"""

from __future__ import annotations

import copy
import json
import random
import re
import unittest
from pathlib import Path
from typing import Any

try:
    from release_contracts import (
        ROOT,
        assigned_strings,
        extract_table_entry,
        module_functions,
        normalized_table_keys,
        parse_action_names,
        parse_monster_evidence_profiles,
        parse_recommended_equipment,
        parse_round_phases,
        read,
        require_any_method,
        require_file,
        role_distribution,
        service_methods,
    )
except ModuleNotFoundError:  # Supports `python -m unittest scripts.test_...`.
    from scripts.release_contracts import (
        ROOT,
        assigned_strings,
        extract_table_entry,
        module_functions,
        normalized_table_keys,
        parse_action_names,
        parse_monster_evidence_profiles,
        parse_recommended_equipment,
        parse_round_phases,
        read,
        require_any_method,
        require_file,
        role_distribution,
        service_methods,
    )


MONSTER_IDS = {
    "BabyAlien",
    "Screamer",
    "Wendigo",
    "ShadowMonster",
    "Chupacabra",
    "Dullahan",
    "Entity",
    "Banshee",
}

PLAYABLE_ROLES = {
    "Camper",
    "Medic",
    "Trapper",
    "Medium",
    "Guard",
    "Protector",
    "Detective",
    "Murderer",
}

REMOTE_SURFACE = {
    "RoundStateChanged": "RemoteEvent",
    "GetRoundState": "RemoteFunction",
    "PlayerStateChanged": "RemoteEvent",
    "GetPlayerState": "RemoteFunction",
    "SubmitVote": "RemoteEvent",
    "GameStateChanged": "RemoteEvent",
    "GetGameState": "RemoteFunction",
    "RequestAction": "RemoteFunction",
    "Announcement": "RemoteEvent",
}

FORBIDDEN_MONETIZATION = {
    "MarketplaceService",
    "PromptProductPurchase",
    "PromptGamePassPurchase",
    "PromptPremiumPurchase",
    "ProcessReceipt",
    "GetProductInfo",
    "UserOwnsGamePassAsync",
}

EXPECTED_PHASES = [
    "Lobby",
    "RoleReveal",
    "Day",
    "MurderPlanning",
    "NightTransform",
    "Investigation",
    "Campfire",
    "Resolution",
    "Rewards",
]

RELEASE_MODULES = {
    "src/server/Services/MysteryService.lua",
    "src/server/Services/CounselorService.lua",
    "src/client/Controllers/TutorialController.lua",
    "src/client/Controllers/AudioController.lua",
    "src/client/Controllers/AccessibilityController.lua",
}


def _integer_constant(relative: str, field: str) -> int:
    match = re.search(rf"\b{re.escape(field)}\s*=\s*(\d[\d_]*)", read(relative))
    if not match:
        raise AssertionError(f"{relative} does not declare {field}")
    return int(match.group(1).replace("_", ""))


def _setting_fields() -> set[str]:
    source = read("src/shared/Config/ProgressionConfig.lua")
    default_block = re.search(
        r"local DEFAULT_SETTINGS\s*=\s*table\.freeze\(\{(?P<body>.*?)\}\)",
        source,
        flags=re.DOTALL,
    )
    if not default_block:
        raise AssertionError("ProgressionConfig.DEFAULT_SETTINGS is missing")
    return set(
        re.findall(
            r"^\t([A-Za-z_][A-Za-z0-9_]*)\s*=",
            default_block.group("body"),
            flags=re.MULTILINE,
        )
    )


def _sanitize_profile_model(raw_value: Any) -> dict[str, Any]:
    """Reference model for schema-0-to-v1 safety and idempotency contracts."""

    schema = _integer_constant("src/shared/Config/ProgressionConfig.lua", "schemaVersion")
    max_xp = _integer_constant("src/shared/Config/ProgressionConfig.lua", "maxTotalXP")
    max_tokens = _integer_constant(
        "src/shared/Config/ProgressionConfig.lua", "maxCampTokens"
    )
    max_receipts = _integer_constant(
        "src/shared/Config/ProgressionConfig.lua", "maxRewardReceipts"
    )
    settings = {
        "masterVolume": 1.0,
        "musicVolume": 0.7,
        "ambienceVolume": 0.8,
        "effectsVolume": 0.9,
        "uiVolume": 0.8,
        "subtitles": True,
        "reducedMotion": False,
        "cameraShake": True,
        "highContrastEvidence": False,
        "mouseSensitivity": 1.0,
        "controllerSensitivity": 1.0,
        "sprintToggle": False,
        "tutorialCompleted": False,
        # Opt-in mystery (2026-08-10): auto-enroll preference; absent
        # sanitizes to False so opting in is always an explicit choice.
        "autoEnroll": False,
    }
    raw = raw_value if isinstance(raw_value, dict) else {}

    def safe_int(value: Any, maximum: int) -> int:
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            return 0
        if value != value or value in (float("inf"), float("-inf")):
            return 0
        return max(0, min(int(value), maximum))

    raw_settings = raw.get("settings")
    if isinstance(raw_settings, dict):
        for field, default in tuple(settings.items()):
            value = raw_settings.get(field, default)
            if isinstance(default, bool):
                settings[field] = value if isinstance(value, bool) else default
            elif isinstance(value, (int, float)) and not isinstance(value, bool):
                if field.endswith("Sensitivity"):
                    settings[field] = max(0.1, min(float(value), 3.0))
                else:
                    settings[field] = max(0.0, min(float(value), 1.0))

    receipts: list[str] = []
    raw_receipts = raw.get("recentRewardReceipts")
    if isinstance(raw_receipts, list):
        for value in raw_receipts:
            if (
                isinstance(value, str)
                and 0 < len(value) <= 64
                and re.fullmatch(r"[\w\-_:]+", value)
                and value not in receipts
            ):
                receipts.append(value)
    receipts = receipts[-max_receipts:]

    return {
        "schemaVersion": schema,
        "totalXP": safe_int(raw.get("totalXP"), max_xp),
        "campTokens": safe_int(raw.get("campTokens"), max_tokens),
        "settings": settings,
        "recentRewardReceipts": receipts,
    }


class ReleaseCatalogTests(unittest.TestCase):
    def test_role_distribution_for_every_supported_roster_size(self) -> None:
        role_source = read("src/shared/Config/RoleCatalog.lua")
        for token in (
            "participantCount >= 0",
            "participantCount <= 12",
            'local roles: { RoleName } = { "Murderer" }',
            "participantCount - 2",
        ):
            self.assertIn(token, role_source)

        for count in range(1, 13):
            with self.subTest(participants=count):
                roles = role_distribution(count)
                self.assertEqual(len(roles), count)
                self.assertEqual(roles.count("Murderer"), 1)
                self.assertTrue(set(roles).issubset(PLAYABLE_ROLES))
                if count >= 2:
                    self.assertGreaterEqual(roles.count("Camper"), 1)
                expected_non_campers = 1 if count == 1 else min(count - 1, 7)
                self.assertEqual(
                    len(roles) - roles.count("Camper"),
                    expected_non_campers,
                )

    def test_round_phase_order_and_timing_budget(self) -> None:
        phases = parse_round_phases()
        self.assertEqual([phase["name"] for phase in phases], EXPECTED_PHASES)
        self.assertTrue(all(int(phase["duration"]) > 0 for phase in phases))
        self.assertTrue(all(int(phase["studio"]) > 0 for phase in phases))
        production_seconds = sum(int(phase["duration"]) for phase in phases)
        studio_seconds = sum(int(phase["studio"]) for phase in phases)
        # Family-audience pacing: full rounds land between 12 and 18 minutes
        self.assertGreaterEqual(production_seconds, 12 * 60)
        self.assertLessEqual(production_seconds, 18 * 60)
        self.assertEqual(
            [int(phase["studio"]) for phase in phases],
            [40, 8, 75, 30, 10, 100, 60, 12, 10],
        )
        self.assertEqual(studio_seconds, 5 * 60 + 45)

    def test_equipment_catalog_rules_and_counterplay_agree(self) -> None:
        presentations = set(
            normalized_table_keys("src/shared/Config/EquipmentCatalog.lua")
        )
        rules = set(normalized_table_keys("src/server/Config/EquipmentRules.lua"))
        self.assertGreaterEqual(len(presentations), 11)
        self.assertEqual(presentations, rules)
        self.assertTrue(parse_recommended_equipment().issubset(presentations))
        self.assertIn("MedicalKit", presentations)
        self.assertIn("FlareLantern", presentations)

        rules_source = read("src/server/Config/EquipmentRules.lua")
        for equipment_id in sorted(rules):
            block = extract_table_entry(rules_source, equipment_id)
            for positive_field in (
                "maxCharges",
                "maxDurability",
                "maxRange",
            ):
                value = re.search(rf"\b{positive_field}\s*=\s*([\d.]+)", block)
                self.assertIsNotNone(value, f"{equipment_id}.{positive_field} missing")
                self.assertGreater(float(value.group(1)), 0)
            cooldown = re.search(r"\bcooldownSeconds\s*=\s*([\d.]+)", block)
            self.assertIsNotNone(cooldown)
            self.assertGreaterEqual(float(cooldown.group(1)), 0)

    def test_monster_catalogs_have_unique_solvable_evidence_profiles(self) -> None:
        public_ids = set(
            normalized_table_keys("src/shared/Config/PublicMonsterCatalog.lua")
        )
        rule_ids = set(normalized_table_keys("src/server/Config/MonsterRules.lua"))
        self.assertEqual(public_ids, MONSTER_IDS)
        self.assertEqual(rule_ids, MONSTER_IDS)

        profiles = parse_monster_evidence_profiles()
        rules_source = read("src/server/Config/MonsterRules.lua")
        fingerprints: set[frozenset[str]] = set()
        for monster_id, evidence in profiles.items():
            with self.subTest(monster=monster_id):
                self.assertGreaterEqual(len(evidence), 3)
                self.assertEqual(len(evidence), len(set(evidence)))
                fingerprint = frozenset(evidence)
                self.assertNotIn(
                    fingerprint,
                    fingerprints,
                    "Full evidence profiles must identify one monster",
                )
                fingerprints.add(fingerprint)

                candidates = {
                    candidate
                    for candidate, candidate_evidence in profiles.items()
                    if set(evidence).issubset(candidate_evidence)
                }
                self.assertEqual(candidates, {monster_id})
                rule_block = extract_table_entry(rules_source, monster_id)
                stamina = re.search(r"\bmaxStamina\s*=\s*([\d.]+)", rule_block)
                self.assertIsNotNone(stamina)
                self.assertGreater(float(stamina.group(1)), 0)
                ability_ids = re.findall(
                    r"^\t\t\t([A-Za-z_][A-Za-z0-9_]*)\s*=\s*{",
                    rule_block,
                    flags=re.MULTILINE,
                )
                self.assertEqual(
                    len(ability_ids),
                    2,
                    f"{monster_id} must ship exactly two authored abilities",
                )
                self.assertGreaterEqual(
                    rule_block.count('kind = "Evidence"'),
                    1,
                    f"{monster_id} abilities must create investigation evidence",
                )
                self.assertIn("allowedPhases = INVESTIGATION_ONLY", rule_block)

    def test_authored_mystery_clues_narrow_to_one_monster(self) -> None:
        relative = "src/server/Config/MysteryCatalog.lua"
        source = read(relative)
        all_clue_ids = re.findall(
            r'^\s+id\s*=\s*"([a-z0-9][a-z0-9\-]+)"',
            source,
            flags=re.MULTILINE,
        )
        self.assertGreaterEqual(len(all_clue_ids), 34)
        self.assertEqual(
            len(all_clue_ids),
            len(set(all_clue_ids)),
            "Every authored clue ID must be globally unique",
        )

        all_locations: set[str] = set()
        for monster_id in sorted(MONSTER_IDS):
            block = extract_table_entry(source, monster_id)
            candidate_lists = [
                set(re.findall(r'"([^"]+)"', body))
                for body in re.findall(
                    r"\bmonsterCandidates\s*=\s*{(.*?)}",
                    block,
                    flags=re.DOTALL,
                )
            ]
            self.assertGreaterEqual(len(candidate_lists), 3)
            for candidates in candidate_lists:
                self.assertIn(monster_id, candidates)
                self.assertGreaterEqual(
                    len(candidates),
                    2,
                    "A single ordinary clue must not print the monster answer",
                )
                self.assertTrue(candidates.issubset(MONSTER_IDS))
            intersection = set.intersection(*candidate_lists)
            self.assertEqual(
                intersection,
                {monster_id},
                "The complete authentic clue set must identify one monster",
            )
            for body in re.findall(
                r"\blocationIds\s*=\s*{(.*?)}",
                block,
                flags=re.DOTALL,
            ):
                all_locations.update(re.findall(r'"([^"]+)"', body))

        world_contract = read("src/server/Config/WorldManifest.lua") + read(
            "src/server/Services/ProductionMapService.lua"
        )
        missing_locations = sorted(
            location_id
            for location_id in all_locations
            if f'"{location_id}"' not in world_contract
        )
        self.assertEqual(
            missing_locations,
            [],
            "Mystery clues must point to authored world search locations",
        )

    def test_repeated_seeded_roster_and_mystery_invariants(self) -> None:
        monster_ids = sorted(MONSTER_IDS)
        profiles = parse_monster_evidence_profiles()
        bot_ids = assigned_strings("src/server/Config/BotProfiles.lua", "id")
        self.assertGreaterEqual(len(set(bot_ids)), 12)

        exercised_monsters: set[str] = set()
        exercised_culprits: set[str] = set()
        for seed in range(512):
            rng = random.Random(seed)
            count = 1 + seed % 12
            roster = [f"participant:{index}" for index in range(count)]
            culprit = rng.choice(roster)
            monster_id = rng.choice(monster_ids)
            evidence = list(profiles[monster_id])
            rng.shuffle(evidence)

            roles = role_distribution(count)
            murderer_slot = rng.randrange(count)
            assigned_roles = roles.copy()
            rng.shuffle(assigned_roles)
            assigned_roles[murderer_slot], assigned_roles[
                assigned_roles.index("Murderer")
            ] = ("Murderer", assigned_roles[murderer_slot])

            self.assertEqual(len(roster), len(set(roster)))
            self.assertIn(culprit, roster)
            self.assertEqual(assigned_roles.count("Murderer"), 1)
            self.assertEqual(len(assigned_roles), count)
            self.assertEqual(len(evidence), len(set(evidence)))
            self.assertGreaterEqual(len(evidence), 3)
            exercised_monsters.add(monster_id)
            exercised_culprits.add(culprit)

        self.assertEqual(exercised_monsters, MONSTER_IDS)
        self.assertGreater(len(exercised_culprits), 10)

    def test_repeated_culprit_candidate_intersections_are_solvable(self) -> None:
        source = read("src/server/Services/MysteryService.lua")
        for token in (
            "local CULPRIT_CLUE_COUNT = 3",
            "exclusionBucket",
            "exclusionBucket ~= clueIndex",
            "audit.isCulpritDeducible",
        ):
            self.assertIn(token, source)

        exercised_positions: set[int] = set()
        for seed in range(512):
            rng = random.Random(seed)
            count = 4 + seed % 9
            suspects = [f"suspect:{index:02d}" for index in range(count)]
            culprit = rng.choice(suspects)
            exercised_positions.add(suspects.index(culprit))
            authentic_sets: list[set[str]] = []
            for clue_index in range(1, 4):
                candidates = {culprit}
                decoy_index = 0
                for suspect_id in suspects:
                    if suspect_id == culprit:
                        continue
                    decoy_index += 1
                    exclusion_bucket = ((decoy_index - 1) % 3) + 1
                    if exclusion_bucket != clue_index:
                        candidates.add(suspect_id)
                self.assertIn(culprit, candidates)
                self.assertGreaterEqual(len(candidates), 2)
                authentic_sets.append(candidates)
            self.assertEqual(set.intersection(*authentic_sets), {culprit})

        self.assertEqual(exercised_positions, set(range(12)))


class ReleaseApiTests(unittest.TestCase):
    def test_remote_surface_is_explicit_and_exact(self) -> None:
        project = json.loads(read("default.project.json"))
        remotes = project["tree"]["ReplicatedStorage"]["Remotes"]
        actual = {
            name: definition.get("$className")
            for name, definition in remotes.items()
            if name != "$className"
        }
        self.assertEqual(actual, REMOTE_SURFACE)

        bootstrap = read("src/server/Bootstrap.server.lua")
        for token in (
            "REQUEST_WINDOW_SECONDS",
            "MAX_REQUESTS_PER_WINDOW",
            "requestAllowed(player)",
            "requestAction.OnServerInvoke",
            "typeof(actionName)",
            "runtime:HandleAction(player, actionName, payload)",
        ):
            self.assertIn(token, bootstrap)

    def test_declared_actions_have_server_handlers(self) -> None:
        declared = parse_action_names()
        runtime = read("src/server/Services/GameRuntimeService.lua")
        handled = set(re.findall(r'actionName\s*==\s*"([A-Za-z][A-Za-z0-9]*)"', runtime))
        self.assertEqual(declared - handled, set())

    def test_server_service_api_contracts(self) -> None:
        required = {
            "src/server/Services/GameRuntimeService.lua": {
                "BeginRound",
                "EnterPhase",
                "GetGameState",
                "HandleAction",
                "Start",
                "Stop",
            },
            "src/server/Services/EvidenceService.lua": {
                "BeginRound",
                "GenerateBaselineMystery",
                "CreateAttackEvidence",
                "PlantFake",
                "Discover",
                "Verify",
                "GetBoardSnapshot",
            },
            "src/server/Services/MonsterService.lua": {
                "SelectForRound",
                "BeginPlanning",
                "Activate",
                "GetPublicSnapshot",
                "GetPrivateSnapshot",
                "Reset",
            },
            "src/server/Services/ProfileService.lua": {
                "LoadPlayer",
                "SavePlayer",
                "ReleasePlayer",
                "ApplyReward",
                "UpdateSettings",
            },
        }
        for relative, expected in required.items():
            with self.subTest(service=relative):
                self.assertEqual(expected - service_methods(relative), set())

    def test_launch_has_no_monetization_surface(self) -> None:
        for path in sorted((ROOT / "src").rglob("*.lua")):
            source = path.read_text(encoding="utf-8")
            found = sorted(token for token in FORBIDDEN_MONETIZATION if token in source)
            self.assertEqual(found, [], f"{path.relative_to(ROOT)} contains {found}")


class ReleasePersistenceTests(unittest.TestCase):
    def test_profile_migration_source_contract(self) -> None:
        source = read("src/server/Services/ProfileService.lua")
        for token in (
            "local function defaultProfile()",
            "local function sanitizeProfile(",
            "rawVersion > ProgressionConfig.schemaVersion",
            "Schema 0",
            "safeInteger(",
            "safeUnit(",
            "safeBoolean(",
            "recentRewardReceipts",
            "hasReceipt(",
            "UpdateAsync",
        ):
            self.assertIn(token, source)
        self.assertEqual(_integer_constant(
            "src/shared/Config/ProgressionConfig.lua", "schemaVersion"
        ), 1)
        self.assertGreaterEqual(source.count("hasReceipt("), 3)
        for setting in _setting_fields():
            self.assertIn(
                setting,
                source,
                f"Profile migration/update code must handle setting {setting}",
            )

    def test_reference_migration_is_safe_and_idempotent(self) -> None:
        malformed_v0 = {
            "schemaVersion": 0,
            "totalXP": 9_999_999_999,
            "campTokens": -50,
            "settings": {
                "masterVolume": 8,
                "musicVolume": -2,
                "subtitles": "yes",
                "reducedMotion": True,
                "mouseSensitivity": 99,
                "unknown": True,
            },
            "recentRewardReceipts": [
                "round:1",
                "round:1",
                "bad receipt!",
                "round:2",
            ],
            "unknownField": {"must": "drop"},
        }
        migrated = _sanitize_profile_model(malformed_v0)
        self.assertEqual(migrated["schemaVersion"], 1)
        self.assertGreaterEqual(migrated["totalXP"], 0)
        self.assertEqual(migrated["campTokens"], 0)
        self.assertEqual(migrated["settings"]["masterVolume"], 1)
        self.assertEqual(migrated["settings"]["musicVolume"], 0)
        self.assertTrue(migrated["settings"]["reducedMotion"])
        self.assertTrue(migrated["settings"]["subtitles"])
        self.assertEqual(migrated["recentRewardReceipts"], ["round:1", "round:2"])
        self.assertNotIn("unknownField", migrated)
        self.assertEqual(_sanitize_profile_model(copy.deepcopy(migrated)), migrated)
        self.assertEqual(set(migrated["settings"]), _setting_fields())

    def test_reward_receipt_storage_is_bounded(self) -> None:
        source = read("src/server/Services/ProfileService.lua")
        maximum = _integer_constant(
            "src/shared/Config/ProgressionConfig.lua", "maxRewardReceipts"
        )
        self.assertGreaterEqual(maximum, 10)
        self.assertLessEqual(maximum, 100)
        self.assertIn("ProgressionConfig.maxRewardReceipts", source)
        self.assertIn("table.remove", source)


class ReleaseFeatureModuleTests(unittest.TestCase):
    def test_expected_release_modules_exist_and_are_strict(self) -> None:
        for relative in sorted(RELEASE_MODULES):
            with self.subTest(module=relative):
                path = require_file(relative)
                self.assertTrue(
                    path.read_text(encoding="utf-8").startswith("--!strict"),
                    f"{relative} must use strict Luau",
                )

    def test_mystery_service_contract(self) -> None:
        relative = "src/server/Services/MysteryService.lua"
        require_file(relative)
        methods = module_functions(relative)
        self.assertIn("new", methods)
        require_any_method(relative, {"BeginRound", "Generate", "GenerateMystery"}, "generation")
        require_any_method(
            relative,
            {"GetSnapshot", "GetPublicSnapshot", "GetMysterySnapshot"},
            "snapshot",
        )
        require_any_method(
            relative,
            {
                "Resolve",
                "ResolveAccusation",
                "EvaluateAccusation",
                "IsSolved",
                "AuditDeduction",
            },
            "resolution",
        )
        source = read(relative)
        for concept in ("clue", "culprit", "monster"):
            self.assertIn(concept, source.lower())
        for invariant in ("isCulpritDeducible", "isMonsterDeducible"):
            self.assertIn(invariant, source)
        self.assertIn("Random.new(seed)", source)
        self.assertNotIn("math.randomseed", source)

    def test_counselor_content_contract(self) -> None:
        relative = "src/server/Services/CounselorService.lua"
        require_file(relative)
        methods = module_functions(relative)
        self.assertIn("new", methods)
        require_any_method(relative, {"BeginRound", "Start", "Spawn"}, "lifecycle")
        require_any_method(
            relative,
            {"GetSnapshot", "GetPublicSnapshot", "GetCounselors", "GetAll"},
            "public snapshot",
        )
        require_any_method(relative, {"Reset", "Stop", "Destroy", "Cleanup"}, "cleanup")
        source = read(relative)
        self.assertIn("counselor", source.lower())
        self.assertRegex(source.lower(), r"(witness|observation|dialogue)")
        self.assertRegex(source.lower(), r"(schedule|flee|hide)")

        catalog = read("src/server/Config/CounselorCatalog.lua")
        content_ids = re.findall(
            r'^\t\{\s*\n\t\tid\s*=\s*"(counselor-[a-z0-9\-]+)"',
            catalog,
            flags=re.MULTILINE,
        )
        named_counselors = re.findall(
            r'^\t\tdisplayName\s*=\s*"([^"]+)"',
            catalog,
            flags=re.MULTILINE,
        )
        self.assertEqual(len(content_ids), 6)
        self.assertEqual(len(content_ids), len(set(content_ids)))
        self.assertEqual(len(named_counselors), 6)
        self.assertEqual(len(named_counselors), len(set(named_counselors)))
        self.assertEqual(catalog.count("isAdult = true"), 6)
        for phase in EXPECTED_PHASES:
            self.assertEqual(
                catalog.count(f'phase = "{phase}"'),
                6,
                f"Every counselor requires a {phase} schedule entry",
            )
        for dialogue_kind in (
            "Greeting",
            "Schedule",
            "Observation",
            "Monster",
            "Safety",
            "Suspicion",
        ):
            self.assertEqual(
                len(
                    re.findall(
                        rf"^\t\t\t{dialogue_kind}\s*=",
                        catalog,
                        flags=re.MULTILINE,
                    )
                ),
                6,
            )

        character_assets = read("src/server/Services/CharacterAssetService.lua")
        scheduled_locations = set(
            re.findall(r'\blocationId\s*=\s*"([^"]+)"', catalog)
        )
        emergency_locations: set[str] = set()
        for body in re.findall(
            r'\b(?:hideLocationIds|fleeLocationIds)\s*=\s*{(.*?)}',
            catalog,
            flags=re.DOTALL,
        ):
            emergency_locations.update(re.findall(r'"([^"]+)"', body))
        for location_id in sorted(scheduled_locations | emergency_locations):
            with self.subTest(counselor_location=location_id):
                plain_key = f"{location_id} = CFrame"
                quoted_key = f'["{location_id}"] = CFrame'
                self.assertTrue(
                    plain_key in character_assets or quoted_key in character_assets,
                    f"Counselor location {location_id} needs a physical world position",
                )
        self.assertIn("counselor.destinationId", character_assets)

        runtime = read("src/server/Services/GameRuntimeService.lua")
        self.assertIn("self.counselors:ReportThreat", runtime)
        self.assertIn("self.characters:ApplyCounselorSnapshot", runtime)

        notebook = read("src/client/UI/GameView.lua")
        self.assertIn("joinCandidateNames(candidateIds, candidateNamesById)", notebook)

    def test_tutorial_controller_contract(self) -> None:
        relative = "src/client/Controllers/TutorialController.lua"
        require_file(relative)
        methods = module_functions(relative)
        self.assertIn("new", methods)
        require_any_method(relative, {"Start", "Begin", "Update"}, "state entry")
        require_any_method(relative, {"Destroy", "Stop", "Reset"}, "cleanup")
        source = read(relative).lower()
        for concept in ("step", "complete", "skip"):
            self.assertIn(concept, source)

    def test_audio_controller_contract(self) -> None:
        relative = "src/client/Controllers/AudioController.lua"
        require_file(relative)
        methods = module_functions(relative)
        self.assertIn("new", methods)
        require_any_method(relative, {"Start", "Begin", "Update"}, "state entry")
        require_any_method(relative, {"Destroy", "Stop"}, "cleanup")
        source = read(relative)
        for setting in ("masterVolume", "musicVolume", "ambienceVolume", "effectsVolume"):
            self.assertIn(setting, source)

    def test_accessibility_controller_contract(self) -> None:
        relative = "src/client/Controllers/AccessibilityController.lua"
        require_file(relative)
        methods = module_functions(relative)
        self.assertIn("new", methods)
        require_any_method(relative, {"Start", "Apply", "ApplySettings"}, "application")
        require_any_method(relative, {"Destroy", "Stop", "Reset"}, "cleanup")
        source = read(relative)
        for setting in (
            "subtitles",
            "reducedMotion",
            "cameraShake",
            "highContrastEvidence",
        ):
            self.assertIn(setting, source)

    def test_feature_modules_are_wired_into_bootstraps(self) -> None:
        server = read("src/server/Bootstrap.server.lua")
        client = read("src/client/Bootstrap.client.lua") + read(
            "src/client/Controllers/RoundController.lua"
        )
        for module_name in ("MysteryService", "CounselorService"):
            self.assertIn(module_name, server + read("src/server/Services/GameRuntimeService.lua"))
        for module_name in (
            "TutorialController",
            "AudioController",
            "AccessibilityController",
        ):
            self.assertIn(module_name, client)
        for cleanup_call in (
            "tutorial:Destroy()",
            "audio:Destroy()",
            "accessibility:Destroy()",
        ):
            self.assertIn(cleanup_call, client)


if __name__ == "__main__":
    unittest.main(verbosity=2)
