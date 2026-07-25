"""Structural validation for the CAMP-Mystery Rojo project."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT_FILE = ROOT / "default.project.json"
REQUIRED_FILES = (
    ROOT / "src/shared/Types/GameTypes.lua",
    ROOT / "src/shared/Config/RoundConfig.lua",
    ROOT / "src/server/Services/GrayboxMapService.lua",
    ROOT / "src/server/Services/RoundService.lua",
    ROOT / "src/server/Bootstrap.server.lua",
    ROOT / "src/client/Controllers/RoundController.lua",
    ROOT / "src/client/Bootstrap.client.lua",
)
REQUIRED_REMOTES = {
    "RoundStateChanged": "RemoteEvent",
    "GetRoundState": "RemoteFunction",
    "PlayerStateChanged": "RemoteEvent",
    "GetPlayerState": "RemoteFunction",
    "SubmitVote": "RemoteEvent",
}


def main() -> None:
    project = json.loads(PROJECT_FILE.read_text(encoding="utf-8"))
    tree = project["tree"]

    mapped_paths = {
        tree["ReplicatedStorage"]["Shared"]["$path"],
        tree["ServerScriptService"]["Server"]["$path"],
        tree["StarterPlayer"]["StarterPlayerScripts"]["Client"]["$path"],
    }
    expected_paths = {"src/shared", "src/server", "src/client"}
    if mapped_paths != expected_paths:
        raise SystemExit(
            f"Unexpected Rojo source mappings: {sorted(mapped_paths)}"
        )

    remotes = tree["ReplicatedStorage"]["Remotes"]
    for name, class_name in REQUIRED_REMOTES.items():
        actual = remotes.get(name, {}).get("$className")
        if actual != class_name:
            raise SystemExit(
                f"Remote {name} should be {class_name}, found {actual!r}"
            )

    for path in REQUIRED_FILES:
        if not path.is_file():
            raise SystemExit(f"Required source file is missing: {path.relative_to(ROOT)}")
        if not path.read_text(encoding="utf-8").startswith("--!strict"):
            raise SystemExit(
                f"Luau source must start with --!strict: {path.relative_to(ROOT)}"
            )

    print(
        "CAMP-Mystery validation passed: "
        f"{len(REQUIRED_FILES)} strict Luau files, "
        f"{len(REQUIRED_REMOTES)} remotes, and 3 Rojo mappings."
    )


if __name__ == "__main__":
    main()
