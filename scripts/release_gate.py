"""Run repository checks and write honest, commit-scoped release evidence.

Automated repository results and human/Roblox observations are deliberately separate.
The public-release mode cannot pass without a full commit SHA, release-ready content
manifest, and completed observations for the same commit.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

try:
    from validate_content_manifest import validate_manifest
except ModuleNotFoundError:
    from scripts.validate_content_manifest import validate_manifest


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EVIDENCE_DIR = ROOT / "build/release-evidence"
OBSERVATION_TEMPLATE = ROOT / "tools/release-observations.template.json"
FULL_SHA = re.compile(r"^[0-9a-fA-F]{40}$")
VALID_STATUSES = {"not_run", "pass", "fail", "blocked"}
PLACEHOLDER_TOKENS = ("REPLACE", "PLACEHOLDER", "YYYY-", "TODO", "EXAMPLE", "<", ">")


def _now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def _load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def _is_placeholder(value: Any) -> bool:
    if not isinstance(value, str) or not value.strip():
        return True
    upper = value.upper()
    return any(token in upper for token in PLACEHOLDER_TOKENS)


def _parse_utc(value: Any) -> dt.datetime | None:
    if not isinstance(value, str) or not value.endswith("Z"):
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo is not None else None


def _checkout_state() -> dict[str, Any]:
    git = shutil.which("git")
    if git is None:
        return {"available": False, "commit": None, "dirty": None}
    commit = subprocess.run(
        [git, "rev-parse", "HEAD"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    status = subprocess.run(
        [git, "status", "--porcelain"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if commit.returncode != 0 or status.returncode != 0:
        return {"available": False, "commit": None, "dirty": None}
    resolved = commit.stdout.strip()
    return {
        "available": bool(FULL_SHA.fullmatch(resolved)),
        "commit": resolved,
        "dirty": bool(status.stdout.strip()),
    }


def _run_check(
    command: list[str],
    log_path: Path,
) -> dict[str, Any]:
    started = _now()
    completed = subprocess.run(
        command,
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    output = completed.stdout
    if completed.stderr:
        output += ("\n" if output else "") + completed.stderr
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(output, encoding="utf-8")
    try:
        log_reference = str(log_path.relative_to(ROOT)).replace("\\", "/")
    except ValueError:
        log_reference = str(log_path)
    return {
        "status": "pass" if completed.returncode == 0 else "fail",
        "startedAtUtc": started,
        "completedAtUtc": _now(),
        "command": command,
        "exitCode": completed.returncode,
        "log": log_reference,
    }


def _validate_observations(
    path: Path | None,
    release_commit: str,
) -> tuple[dict[str, Any], list[str]]:
    template = _load_json(OBSERVATION_TEMPLATE)
    expected_ids = [gate["id"] for gate in template["gates"]]
    if path is None:
        return template, ["Roblox/Studio observations were not supplied"]

    errors: list[str] = []
    try:
        observations = _load_json(path)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        return template, [f"Cannot load observations: {error}"]
    if observations.get("schemaVersion") != 1:
        errors.append("observations.schemaVersion must be 1")
    if observations.get("releaseCommit") != release_commit:
        errors.append("observations.releaseCommit does not match the release commit")
    tester = observations.get("tester")
    if _is_placeholder(tester) or len(str(tester).strip()) < 2:
        errors.append("observations.tester must identify the actual tester")
    place_version = observations.get("testedPlaceVersion")
    if _is_placeholder(place_version):
        errors.append("observations.testedPlaceVersion must identify the tested private place")
    started = _parse_utc(observations.get("startedAtUtc"))
    completed = _parse_utc(observations.get("completedAtUtc"))
    if started is None or completed is None:
        errors.append("observation timestamps must be concrete UTC ISO-8601 values")
    elif completed < started:
        errors.append("observations.completedAtUtc cannot precede startedAtUtc")
    gates = observations.get("gates")
    if not isinstance(gates, list):
        return observations, errors + ["observations.gates must be an array"]
    actual_ids: list[str] = []
    for index, gate in enumerate(gates):
        if not isinstance(gate, dict):
            errors.append(f"observations.gates[{index}] must be an object")
            continue
        gate_id = gate.get("id")
        actual_ids.append(gate_id if isinstance(gate_id, str) else "")
        if gate.get("status") not in VALID_STATUSES:
            errors.append(f"{gate_id or index}: invalid status")
        evidence = gate.get("evidence")
        if not isinstance(evidence, list) or not all(
            isinstance(item, str) and item.strip() and not _is_placeholder(item)
            for item in evidence
        ):
            errors.append(
                f"{gate_id or index}: evidence must contain concrete paths/URLs"
            )
        if not isinstance(gate.get("notes"), str):
            errors.append(f"{gate_id or index}: notes must be a string")
        if gate.get("status") == "pass" and not evidence:
            errors.append(f"{gate_id or index}: passing gates require evidence")
    if actual_ids != expected_ids:
        errors.append(
            "observation gate IDs/order differ from "
            "tools/release-observations.template.json"
        )
    return observations, errors


def _write_markdown(evidence: dict[str, Any], path: Path) -> None:
    lines = [
        "# CAMP-Mystery Release Evidence",
        "",
        f"- Generated: `{evidence['generatedAtUtc']}`",
        f"- Commit: `{evidence['releaseCommit']}`",
        f"- Verdict: **{evidence['verdict'].upper()}**",
        f"- Public release approved by this gate: **{str(evidence['publicReleaseApproved']).lower()}**",
        "",
        "## Automated repository evidence",
        "",
        "| Check | Status | Log |",
        "|---|---|---|",
    ]
    for name, check in evidence["automatedChecks"].items():
        lines.append(f"| {name} | {check['status']} | `{check['log']}` |")
    lines.extend(
        [
            "",
            "## Content inventory",
            "",
            f"- Structure: **{evidence['content']['structureStatus']}**",
            f"- Release readiness: **{evidence['content']['releaseStatus']}**",
            f"- Asset records: **{evidence['content']['assetCount']}**",
            "",
            "## Roblox/Studio observations",
            "",
            "| Gate | Status | Evidence |",
            "|---|---|---|",
        ]
    )
    for gate in evidence["observations"]["gates"]:
        evidence_text = "<br>".join(gate.get("evidence", [])) or "—"
        lines.append(f"| {gate.get('id', 'invalid')} | {gate.get('status', 'invalid')} | {evidence_text} |")
    lines.extend(["", "## Blocking findings", ""])
    blockers = evidence["blockers"]
    if blockers:
        lines.extend(f"- {blocker}" for blocker in blockers)
    else:
        lines.append("- None")
    lines.extend(
        [
            "",
            "> Repository checks do not execute Luau or Roblox. Studio, private-server,",
            "> DataStore, performance, device, ownership, and moderation evidence remains",
            "> mandatory and is never inferred from a green Python run.",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--release-candidate",
        action="store_true",
        help="Require Rojo, ready content, and all commit-matched human gates.",
    )
    parser.add_argument(
        "--require-rojo",
        action="store_true",
        help="Require the Rojo build even when not evaluating public release.",
    )
    parser.add_argument(
        "--commit",
        default=os.environ.get("GITHUB_SHA", os.environ.get("RELEASE_COMMIT", "")),
        help="Exact 40-character commit SHA under test.",
    )
    parser.add_argument(
        "--observations",
        type=Path,
        help="Completed copy of tools/release-observations.template.json.",
    )
    parser.add_argument(
        "--evidence-dir",
        type=Path,
        default=DEFAULT_EVIDENCE_DIR,
    )
    args = parser.parse_args()

    evidence_dir = args.evidence_dir
    if not evidence_dir.is_absolute():
        evidence_dir = ROOT / evidence_dir
    logs = evidence_dir / "logs"
    evidence_dir.mkdir(parents=True, exist_ok=True)

    run_all_command = [sys.executable, "scripts/run_all_checks.py"]
    if args.require_rojo or args.release_candidate:
        run_all_command.append("--require-rojo")
    automated = {
        "repository-suite": _run_check(
            run_all_command,
            logs / "repository-suite.log",
        )
    }

    manifest_errors, _, content_kinds = validate_manifest(require_ready=False)
    ready_errors, content_blockers, _ = validate_manifest(require_ready=True)
    if ready_errors:
        content_blockers = ready_errors + content_blockers
    manifest_data = _load_json(ROOT / "assets/content-manifest.json")
    content = {
        "structureStatus": "pass" if not manifest_errors else "fail",
        "releaseStatus": (
            "pass"
            if not manifest_errors and not content_blockers
            else "blocked"
        ),
        "assetCount": len(manifest_data.get("assets", [])),
        "kinds": content_kinds,
        "errors": manifest_errors,
        "blockers": content_blockers,
    }

    checkout = _checkout_state()
    release_commit = args.commit.strip() or str(checkout.get("commit") or "")
    blockers: list[str] = []
    checkout_commit = checkout.get("commit")
    if (
        isinstance(checkout_commit, str)
        and FULL_SHA.fullmatch(release_commit)
        and release_commit.lower() != checkout_commit.lower()
    ):
        blockers.append(
            f"Release commit {release_commit} does not match checkout {checkout_commit}"
        )
    if args.release_candidate and checkout.get("dirty") is True:
        blockers.append("Release-candidate checkout has uncommitted changes")
    if args.release_candidate and (
        not FULL_SHA.fullmatch(release_commit) or set(release_commit) == {"0"}
    ):
        blockers.append("A full 40-character release commit SHA is required")
    if not release_commit:
        release_commit = "UNRECORDED"

    observations, observation_errors = _validate_observations(
        args.observations,
        release_commit,
    )
    blockers.extend(observation_errors)
    if manifest_errors:
        blockers.extend(manifest_errors)
    if args.release_candidate:
        blockers.extend(content_blockers)
        for gate in observations.get("gates", []):
            if isinstance(gate, dict) and gate.get("status") != "pass":
                blockers.append(
                    f"{gate.get('id', 'invalid-observation')}: "
                    f"status is {gate.get('status', 'invalid')}"
                )
    if any(check["status"] != "pass" for check in automated.values()):
        blockers.append("One or more automated repository checks failed")

    public_release_approved = args.release_candidate and not blockers
    evidence = {
        "schemaVersion": 1,
        "generatedAtUtc": _now(),
        "releaseCommit": release_commit,
        "checkout": checkout,
        "mode": "release-candidate" if args.release_candidate else "repository-evidence",
        "verdict": "pass" if not blockers else "blocked",
        "publicReleaseApproved": public_release_approved,
        "automatedChecks": automated,
        "content": content,
        "observations": observations,
        "blockers": blockers,
        "limitations": [
            "Python checks do not execute Luau or the Roblox engine.",
            "Automated reference soak/fuzz tests do not replace Studio runtime tests.",
            "Only Roblox can prove replication, physics, navigation, DataStore, performance, device, filtering, and moderation behavior.",
        ],
    }
    json_path = evidence_dir / "release-evidence.json"
    markdown_path = evidence_dir / "release-evidence.md"
    json_path.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    _write_markdown(evidence, markdown_path)

    print(f"Evidence JSON: {json_path}")
    print(f"Evidence summary: {markdown_path}")
    print(f"Verdict: {evidence['verdict']}")
    if blockers:
        print("Blocking findings:")
        for blocker in blockers:
            print(f"- {blocker}")

    if any(check["status"] != "pass" for check in automated.values()) or manifest_errors:
        raise SystemExit(1)
    if args.release_candidate and blockers:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
