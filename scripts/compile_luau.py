"""Compile every Luau source file so syntax errors cannot pass repository CI."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "src"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--require-compiler",
        action="store_true",
        help="Fail when luau-compile is not available instead of reporting a skip.",
    )
    args = parser.parse_args()

    compiler = shutil.which("luau-compile")
    if compiler is None:
        if args.require_compiler:
            raise SystemExit(
                "luau-compile is required but was not found on PATH. "
                "Install the pinned Luau release used by CI."
            )
        print(
            "SKIPPED: luau-compile is not on PATH. "
            "GitHub Actions requires the pinned compiler."
        )
        return

    files = sorted(SOURCE_ROOT.rglob("*.lua"))
    if not files:
        raise SystemExit("No Luau source files were found")

    failures: list[tuple[Path, str]] = []
    for path in files:
        completed = subprocess.run(
            [compiler, str(path)],
            cwd=ROOT,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        if completed.returncode != 0:
            failures.append((path.relative_to(ROOT), completed.stderr.strip()))

    if failures:
        print(f"Luau compilation failed for {len(failures)} file(s):")
        for path, message in failures:
            print(f"\n{path}\n{message or 'Compiler returned a failure without details.'}")
        raise SystemExit(1)

    print(f"Luau compilation passed: {len(files)} source files")


if __name__ == "__main__":
    main()
