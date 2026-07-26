"""Run every repository-side CAMP-Mystery validation from one entrypoint."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run(label: str, command: list[str]) -> None:
    print(f"\n=== {label} ===", flush=True)
    completed = subprocess.run(command, cwd=ROOT, check=False)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--require-rojo",
        action="store_true",
        help="Fail instead of reporting a skip when the Rojo CLI is unavailable.",
    )
    args = parser.parse_args()

    run(
        "Structural project validation",
        [sys.executable, "scripts/validate_project.py"],
    )
    luau_command = [sys.executable, "scripts/compile_luau.py"]
    if args.require_rojo:
        luau_command.append("--require-compiler")
    run("Luau compilation", luau_command)
    run(
        "Domain contract tests",
        [sys.executable, "scripts/test_domain_contracts.py"],
    )
    run(
        "Server release contract tests",
        [sys.executable, "scripts/test_server_release_contracts.py"],
    )
    run(
        "Operational workflow contract tests",
        [sys.executable, "scripts/test_operational_workflow.py"],
    )
    run(
        "Client release contract tests",
        [sys.executable, "scripts/test_client_release.py"],
    )
    run(
        "Motion and UI sound contract tests",
        [sys.executable, "scripts/test_motion_sound_foundation.py"],
    )
    run(
        "Release readiness simulations",
        [sys.executable, "scripts/test_release_readiness.py"],
    )
    run(
        "Content manifest validation",
        [sys.executable, "scripts/validate_content_manifest.py"],
    )
    run(
        "Resilience reference simulations",
        [sys.executable, "scripts/test_resilience_reference.py"],
    )

    rojo = shutil.which("rojo")
    if rojo:
        with tempfile.TemporaryDirectory(prefix="camp-mystery-rojo-") as directory:
            output = Path(directory) / "CAMP-Mystery.rbxlx"
            run(
                "Rojo build",
                [
                    rojo,
                    "build",
                    "default.project.json",
                    "--output",
                    str(output),
                ],
            )
            if not output.is_file() or output.stat().st_size == 0:
                raise SystemExit("Rojo reported success but produced no place file")
            print(f"Rojo artifact verified ({output.stat().st_size:,} bytes).")
    elif args.require_rojo:
        raise SystemExit(
            "Rojo is required for this run but was not found on PATH. "
            "Run `rokit install` and try again."
        )
    else:
        print(
            "\n=== Rojo build ===\n"
            "SKIPPED: Rojo is not on PATH. Static Rojo mapping checks still ran; "
            "use --require-rojo for a release-candidate gate.",
            flush=True,
        )

    print("\nALL AVAILABLE CAMP-MYSTERY CHECKS PASSED", flush=True)


if __name__ == "__main__":
    main()
