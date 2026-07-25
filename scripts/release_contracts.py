"""Small dependency-free helpers for CAMP-Mystery release contract tests.

These helpers intentionally parse only the stable, declarative subset of Luau used by
the project catalogs. They are not a Luau interpreter and must not be represented as
one. Roblox runtime behavior remains a Studio acceptance gate.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require_file(relative: str) -> Path:
    path = ROOT / relative
    if not path.is_file():
        raise AssertionError(f"Required release file is missing: {relative}")
    return path


def service_methods(relative: str) -> set[str]:
    source = read(relative)
    return set(
        re.findall(
            r"function\s+[A-Za-z_][A-Za-z0-9_]*"
            r":([A-Za-z_][A-Za-z0-9_]*)\s*\(",
            source,
        )
    )


def module_functions(relative: str) -> set[str]:
    source = read(relative)
    return set(
        re.findall(
            r"function\s+[A-Za-z_][A-Za-z0-9_]*"
            r"(?:[.:])([A-Za-z_][A-Za-z0-9_]*)\s*\(",
            source,
        )
    )


def assigned_strings(relative: str, field: str) -> list[str]:
    return re.findall(
        rf"\b{re.escape(field)}\s*=\s*\"([^\"]+)\"",
        read(relative),
    )


def top_level_table_keys(relative: str) -> list[str]:
    """Return one-tab table keys from a catalog-style Luau module."""

    return re.findall(
        r"^\t(?:\[\"([^\"]+)\"\]|([A-Za-z_][A-Za-z0-9_]*))\s*=\s*{",
        read(relative),
        flags=re.MULTILINE,
    )


def normalized_table_keys(relative: str) -> list[str]:
    return [quoted or bare for quoted, bare in top_level_table_keys(relative)]


def quoted_list_field(source: str, field: str) -> list[str]:
    match = re.search(
        rf"\b{re.escape(field)}\s*=\s*{{(?P<body>.*?)}}",
        source,
        flags=re.DOTALL,
    )
    if not match:
        return []
    return re.findall(r'"([^"]+)"', match.group("body"))


def extract_table_entry(source: str, key: str) -> str:
    """Extract a balanced catalog entry beginning with ``key = {``."""

    match = re.search(
        rf"^\t+(?:\[\"{re.escape(key)}\"\]|{re.escape(key)})\s*=\s*{{",
        source,
        flags=re.MULTILINE,
    )
    if not match:
        raise AssertionError(f"Could not locate catalog entry {key!r}")

    start = match.start()
    open_brace = source.find("{", match.start(), match.end())
    depth = 0
    in_string = False
    escaped = False
    for index in range(open_brace, len(source)):
        char = source[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start : index + 1]
    raise AssertionError(f"Unbalanced table entry {key!r}")


def require_any_method(
    relative: str,
    methods: Iterable[str],
    purpose: str,
) -> str:
    available = module_functions(relative)
    for method in methods:
        if method in available:
            return method
    raise AssertionError(
        f"{relative} must expose a {purpose} method; "
        f"expected one of {sorted(methods)}, found {sorted(available)}"
    )


def parse_round_phases() -> list[dict[str, int | str]]:
    source = read("src/shared/Config/RoundConfig.lua")
    result: list[dict[str, int | str]] = []
    for block in re.findall(r"\{\s*name\s*=\s*\".*?\"\s*,.*?\}", source, re.DOTALL):
        name = re.search(r'\bname\s*=\s*"([^"]+)"', block)
        duration = re.search(r"\bdurationSeconds\s*=\s*(\d+)", block)
        studio = re.search(r"\bstudioDurationSeconds\s*=\s*(\d+)", block)
        if name and duration and studio:
            result.append(
                {
                    "name": name.group(1),
                    "duration": int(duration.group(1)),
                    "studio": int(studio.group(1)),
                }
            )
    return result


def parse_action_names() -> set[str]:
    source = read("src/shared/Types/RuntimeTypes.lua")
    match = re.search(
        r"export type ActionName\s*=\s*(.*?)(?:\n\n|export type)",
        source,
        flags=re.DOTALL,
    )
    if not match:
        raise AssertionError("RuntimeTypes.ActionName union is missing")
    return set(re.findall(r'"([A-Za-z][A-Za-z0-9]*)"', match.group(1)))


def parse_monster_evidence_profiles() -> dict[str, tuple[str, ...]]:
    source = read("src/server/Config/MonsterRules.lua")
    profiles: dict[str, tuple[str, ...]] = {}
    for monster_id in normalized_table_keys(
        "src/shared/Config/PublicMonsterCatalog.lua"
    ):
        block = extract_table_entry(source, monster_id)
        evidence = quoted_list_field(block, "evidenceProfile")
        profiles[monster_id] = tuple(evidence)
    return profiles


def parse_recommended_equipment() -> set[str]:
    source = read("src/shared/Config/PublicMonsterCatalog.lua")
    recommendations: set[str] = set()
    for block in re.findall(
        r"\brecommendedEquipment\s*=\s*{(?P<body>.*?)}",
        source,
        flags=re.DOTALL,
    ):
        recommendations.update(re.findall(r'"([^"]+)"', block))
    return recommendations


def role_distribution(participant_count: int) -> list[str]:
    """Reference model for the public RoleCatalog distribution contract."""

    if not 0 <= participant_count <= 12:
        raise ValueError("participant_count must be between 0 and 12")
    if participant_count == 0:
        return []
    roles = ["Murderer"]
    if participant_count == 1:
        return roles
    special_order = ["Detective", "Medic", "Guard", "Protector", "Trapper", "Medium"]
    roles.extend(special_order[: min(len(special_order), participant_count - 2)])
    roles.extend(["Camper"] * (participant_count - len(roles)))
    return roles
