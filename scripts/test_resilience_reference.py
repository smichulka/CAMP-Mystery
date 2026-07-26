"""Deterministic soak/fuzz reference tests for repository-side release readiness.

This suite does not invoke Roblox or Luau. It checks declared input boundaries and runs
pure-Python hostile-payload and repeated-round models so the release evidence clearly
separates repository proofs from the required Studio remote-fuzz and ten-reset tests.
"""

from __future__ import annotations

import json
import math
import random
import re
import string
import unittest
from pathlib import Path
from typing import Any

try:
    from release_contracts import (
        ROOT,
        assigned_strings,
        parse_action_names,
        parse_monster_evidence_profiles,
        role_distribution,
    )
except ModuleNotFoundError:
    from scripts.release_contracts import (
        ROOT,
        assigned_strings,
        parse_action_names,
        parse_monster_evidence_profiles,
        role_distribution,
    )


MAX_REFERENCE_STRING = 256
FUZZ_CASES = 10_000
SOAK_ROUNDS = 1_000
MAX_FUZZ_NODES = 96


def _reference_payload_is_bounded(value: Any, depth: int = 0) -> bool:
    """Conservative payload boundary used only by this Python reference model."""

    if depth > 4:
        return False
    if value is None or isinstance(value, bool):
        return True
    if isinstance(value, str):
        return len(value) <= MAX_REFERENCE_STRING
    if isinstance(value, (int, float)):
        return math.isfinite(value) and abs(value) <= 1_000_000
    if isinstance(value, list):
        return len(value) <= 32 and all(
            _reference_payload_is_bounded(item, depth + 1) for item in value
        )
    if isinstance(value, dict):
        return len(value) <= 32 and all(
            isinstance(key, str)
            and len(key) <= 64
            and _reference_payload_is_bounded(item, depth + 1)
            for key, item in value.items()
        )
    return False


def _fuzz_value(
    rng: random.Random,
    depth: int = 0,
    budget: list[int] | None = None,
) -> Any:
    if budget is None:
        budget = [MAX_FUZZ_NODES]
    if budget[0] <= 0:
        return None
    budget[0] -= 1
    choice = rng.randrange(10)
    if depth >= 3:
        choice %= 6
    if choice == 0:
        return None
    if choice == 1:
        return rng.choice((True, False))
    if choice == 2:
        return rng.uniform(-2_000_000, 2_000_000)
    if choice == 3:
        return rng.choice((float("nan"), float("inf"), float("-inf")))
    if choice == 4:
        size = rng.choice((0, 1, 64, 256, 257, 1024))
        return "".join(rng.choice(string.printable) for _ in range(size))
    if choice == 5:
        return rng.randint(-2_000_000, 2_000_000)
    if choice == 6:
        count = min(rng.choice((0, 1, 4, 33)), budget[0])
        return [
            _fuzz_value(rng, depth + 1, budget)
            for _ in range(count)
        ]
    if choice == 7:
        count = min(rng.choice((0, 1, 4, 33)), budget[0])
        return {
            f"k{index}": _fuzz_value(rng, depth + 1, budget)
            for index in range(count)
        }
    if choice == 8:
        return {"nested": _fuzz_value(rng, depth + 1, budget)}
    return object()


class ReferenceRemoteFuzzTests(unittest.TestCase):
    def test_bootstrap_has_request_boundary_and_rate_window(self) -> None:
        bootstrap = (ROOT / "src/server/Bootstrap.server.lua").read_text(
            encoding="utf-8"
        )
        for token in (
            "REQUEST_WINDOW_SECONDS",
            "MAX_REQUESTS_PER_WINDOW",
            "requestAllowed(player)",
            'typeof(actionName) ~= "string"',
            "runtime:HandleAction(player, actionName, payload)",
        ):
            self.assertIn(token, bootstrap)

    def test_runtime_uses_typed_extractors_for_action_payloads(self) -> None:
        runtime = (ROOT / "src/server/Services/GameRuntimeService.lua").read_text(
            encoding="utf-8"
        )
        for token in (
            "local function getString(",
            "local function clonePayload(",
            'typeof(payload) == "table"',
            'typeof(targetPosition) ~= "Vector3"',
            "self:_validateActiveParticipant",
        ):
            self.assertIn(token, runtime)

        declared = parse_action_names()
        handled = set(
            re.findall(r'actionName\s*==\s*"([A-Za-z][A-Za-z0-9]*)"', runtime)
        )
        self.assertEqual(declared - handled, set())

    def test_hostile_reference_payload_corpus_is_total_and_deterministic(self) -> None:
        first = random.Random(0xCA4F)
        second = random.Random(0xCA4F)
        accepted_first: list[bool] = []
        accepted_second: list[bool] = []
        for _ in range(FUZZ_CASES):
            accepted_first.append(_reference_payload_is_bounded(_fuzz_value(first)))
            accepted_second.append(_reference_payload_is_bounded(_fuzz_value(second)))
        self.assertEqual(accepted_first, accepted_second)
        self.assertTrue(any(accepted_first))
        self.assertTrue(any(not result for result in accepted_first))

    def test_known_oversized_stale_and_wrong_type_shapes_are_rejected_by_model(self) -> None:
        hostile = [
            "x" * (MAX_REFERENCE_STRING + 1),
            {"note": "x" * (MAX_REFERENCE_STRING + 1)},
            {"roundId": float("nan")},
            {"position": object()},
            {"nested": {"a": {"b": {"c": {"d": {"e": 1}}}}}},
            {f"k{index}": index for index in range(33)},
        ]
        self.assertTrue(all(not _reference_payload_is_bounded(value) for value in hostile))


class ReferenceRoundSoakTests(unittest.TestCase):
    def test_thousand_round_reference_soak_preserves_core_invariants(self) -> None:
        monsters = sorted(parse_monster_evidence_profiles())
        bots = sorted(set(assigned_strings("src/server/Config/BotProfiles.lua", "id")))
        self.assertGreaterEqual(len(bots), 12)
        seen_round_ids: set[int] = set()
        reward_receipts: set[str] = set()
        monster_counts = {monster: 0 for monster in monsters}

        for seed in range(SOAK_ROUNDS):
            rng = random.Random(seed ^ 0xC4A9)
            round_id = seed + 1
            self.assertNotIn(round_id, seen_round_ids)
            seen_round_ids.add(round_id)

            participant_count = 1 + (seed % 12)
            roster = bots[:participant_count]
            roles = role_distribution(participant_count)
            monster = rng.choice(monsters)
            culprit_index = rng.randrange(participant_count)
            receipt = f"round:{round_id}:participant:{culprit_index}"

            self.assertEqual(len(roster), len(set(roster)))
            self.assertEqual(len(roles), participant_count)
            self.assertEqual(roles.count("Murderer"), 1)
            self.assertNotIn(receipt, reward_receipts)
            reward_receipts.add(receipt)
            monster_counts[monster] += 1

        self.assertEqual(len(seen_round_ids), SOAK_ROUNDS)
        self.assertEqual(len(reward_receipts), SOAK_ROUNDS)
        self.assertTrue(all(count > 75 for count in monster_counts.values()))

    def test_reference_suite_parameters_are_recordable(self) -> None:
        summary = {
            "fuzzCases": FUZZ_CASES,
            "maxNodesPerFuzzPayload": MAX_FUZZ_NODES,
            "soakRounds": SOAK_ROUNDS,
            "engineExecuted": False,
            "claim": "reference-model-only",
        }
        encoded = json.dumps(summary, sort_keys=True)
        self.assertIn('"engineExecuted": false', encoded)
        self.assertIn('"claim": "reference-model-only"', encoded)


if __name__ == "__main__":
    unittest.main(verbosity=2)
