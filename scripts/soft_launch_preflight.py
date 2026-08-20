"""Soft-launch preflight gates for CAMP-Mystery (no Studio required).

Checks monetization remains banned, AnalyticsService.Events funnel keys exist,
SOFT_LAUNCH_GATES.md is present, and Luau sources compile (or project validate
when luau-compile is unavailable).

Reuse FORBIDDEN_MONETIZATION from test_release_readiness so the ban list stays
single-sourced with the release-readiness suite.
"""

from __future__ import annotations

import importlib.util
import re
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def _load_release_readiness():
    path = ROOT / "scripts" / "test_release_readiness.py"
    spec = importlib.util.spec_from_file_location("test_release_readiness", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"Cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


EXPECTED_ANALYTICS_EVENTS = (
    "JoinLobby",
    "Ready",
    "RosterLock",
    "PhaseEnter",
    "VoteCast",
    "Rematch",
    "TutorialComplete",
    "TutorialSkip",
    "QuickCampToggle",
)


def check_monetization_banned(forbidden: set[str]) -> list[str]:
    failures: list[str] = []
    for path in sorted((ROOT / "src").rglob("*.lua")):
        source = path.read_text(encoding="utf-8")
        found = sorted(token for token in forbidden if token in source)
        if found:
            failures.append(f"{path.relative_to(ROOT)} contains {found}")
    return failures


def check_analytics_events() -> list[str]:
    path = ROOT / "src" / "server" / "Services" / "AnalyticsService.lua"
    if not path.is_file():
        return ["src/server/Services/AnalyticsService.lua is missing"]
    source = path.read_text(encoding="utf-8")
    block = re.search(
        r"AnalyticsService\.Events\s*=\s*table\.freeze\(\{(?P<body>.*?)\}\)",
        source,
        flags=re.DOTALL,
    )
    if not block:
        return ["AnalyticsService.Events table.freeze block is missing"]
    body = block.group("body")
    failures: list[str] = []
    for key in EXPECTED_ANALYTICS_EVENTS:
        if not re.search(rf"\b{re.escape(key)}\s*=\s*\"{re.escape(key)}\"", body):
            failures.append(f"AnalyticsService.Events missing key {key}")
    return failures


def check_soft_launch_gates_doc() -> list[str]:
    path = ROOT / "docs" / "SOFT_LAUNCH_GATES.md"
    if not path.is_file():
        return ["docs/SOFT_LAUNCH_GATES.md is missing"]
    return []


def check_compile_or_validate() -> list[str]:
    """Prefer compile_luau when the compiler is on PATH; else validate_project."""
    if shutil.which("luau-compile"):
        completed = subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "compile_luau.py"), "--require-compiler"],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        if completed.returncode != 0:
            detail = (completed.stdout or completed.stderr or "").strip()
            return [f"compile_luau failed:\n{detail or 'no output'}"]
        return []

    completed = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "validate_project.py")],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        detail = (completed.stdout or completed.stderr or "").strip()
        return [
            "luau-compile not on PATH; validate_project fallback failed:\n"
            + (detail or "no output")
        ]
    print(
        "NOTE: luau-compile not on PATH; used validate_project.py as compile stand-in.",
        flush=True,
    )
    return []


def main() -> int:
    readiness = _load_release_readiness()
    forbidden = set(readiness.FORBIDDEN_MONETIZATION)

    print("=== Soft-launch preflight ===", flush=True)
    failures: list[str] = []
    failures.extend(check_monetization_banned(forbidden))
    failures.extend(check_analytics_events())
    failures.extend(check_soft_launch_gates_doc())
    failures.extend(check_compile_or_validate())

    if failures:
        print("SOFT-LAUNCH PREFLIGHT FAILED:", flush=True)
        for item in failures:
            print(f"  - {item}", flush=True)
        return 1

    print("SOFT-LAUNCH PREFLIGHT PASSED", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
