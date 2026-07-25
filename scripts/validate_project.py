"""Structural validation for the CAMP-Mystery Rojo project."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT_FILE = ROOT / "default.project.json"
REQUIRED_FILES = (
    ROOT / "src/shared/Types/GameTypes.lua",
    ROOT / "src/shared/Types/ParticipantTypes.lua",
    ROOT / "src/shared/Types/EquipmentTypes.lua",
    ROOT / "src/shared/Types/CombatTypes.lua",
    ROOT / "src/shared/Types/EvidenceTypes.lua",
    ROOT / "src/shared/Types/MonsterTypes.lua",
    ROOT / "src/shared/Types/ProfileTypes.lua",
    ROOT / "src/shared/Types/MatchTypes.lua",
    ROOT / "src/shared/Types/BotTypes.lua",
    ROOT / "src/shared/Types/WorldTypes.lua",
    ROOT / "src/shared/Config/RoleCatalog.lua",
    ROOT / "src/shared/Config/EquipmentCatalog.lua",
    ROOT / "src/shared/Config/PublicMonsterCatalog.lua",
    ROOT / "src/shared/Config/ProgressionConfig.lua",
    ROOT / "src/shared/Config/CosmeticCatalog.lua",
    ROOT / "src/shared/Config/MatchConfig.lua",
    ROOT / "src/shared/Config/RoundConfig.lua",
    ROOT / "src/server/Config/EquipmentRules.lua",
    ROOT / "src/server/Config/EvidenceRules.lua",
    ROOT / "src/server/Config/MonsterRules.lua",
    ROOT / "src/server/Config/BotProfiles.lua",
    ROOT / "src/server/Config/WorldManifest.lua",
    ROOT / "src/server/Services/ParticipantService.lua",
    ROOT / "src/server/Services/InventoryService.lua",
    ROOT / "src/server/Services/CombatService.lua",
    ROOT / "src/server/Services/EvidenceService.lua",
    ROOT / "src/server/Services/MonsterService.lua",
    ROOT / "src/server/Services/ProfileService.lua",
    ROOT / "src/server/Services/LobbyService.lua",
    ROOT / "src/server/Services/MatchmakingService.lua",
    ROOT / "src/server/Services/ComputerPlayerService.lua",
    ROOT / "src/server/Services/WorldService.lua",
    ROOT / "src/server/Services/RoundLifecycle.lua",
    ROOT / "src/server/Adapters/MemoryProfileStore.lua",
    ROOT / "src/server/Adapters/RobloxProfileStore.lua",
    ROOT / "src/server/Systems/RewardCalculation.lua",
    ROOT / "src/server/Systems/BotRosterSystem.lua",
    ROOT / "src/server/Utilities/Cleanup.lua",
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

ROLE_NAMES = {
    "Camper",
    "Medic",
    "Trapper",
    "Medium",
    "Guard",
    "Protector",
    "Detective",
    "Murderer",
}

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

MONETIZATION_TOKENS = {
    "MarketplaceService",
    "PromptProductPurchase",
    "PromptGamePassPurchase",
    "ProcessReceipt",
}


def require_tokens(path: Path, tokens: set[str]) -> None:
    contents = path.read_text(encoding="utf-8")
    missing = sorted(token for token in tokens if token not in contents)
    if missing:
        raise SystemExit(
            f"{path.relative_to(ROOT)} is missing required tokens: {missing}"
        )


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

    lua_files = sorted((ROOT / "src").rglob("*.lua"))
    for path in lua_files:
        contents = path.read_text(encoding="utf-8")
        if not contents.startswith("--!strict"):
            raise SystemExit(
                f"Luau source must start with --!strict: {path.relative_to(ROOT)}"
            )
        found_monetization = sorted(
            token for token in MONETIZATION_TOKENS if token in contents
        )
        if found_monetization:
            raise SystemExit(
                "Launch monetization is disabled, but "
                f"{path.relative_to(ROOT)} contains: {found_monetization}"
            )

    require_tokens(ROOT / "src/shared/Config/RoleCatalog.lua", ROLE_NAMES)
    require_tokens(
        ROOT / "src/shared/Config/PublicMonsterCatalog.lua",
        MONSTER_IDS,
    )
    require_tokens(ROOT / "src/server/Config/MonsterRules.lua", MONSTER_IDS)
    require_tokens(
        ROOT / "src/shared/Types/ParticipantTypes.lua",
        {"MAX_INVENTORY_SLOTS = 15"},
    )
    require_tokens(
        ROOT / "src/shared/Config/ProgressionConfig.lua",
        {"schemaVersion = 1"},
    )

    for documentation in (
        ROOT / "docs/PRODUCT_SPEC.md",
        ROOT / "docs/DELIVERY_PLAN.md",
    ):
        if not documentation.is_file():
            raise SystemExit(
                f"Required documentation is missing: {documentation.relative_to(ROOT)}"
            )

    print(
        "CAMP-Mystery validation passed: "
        f"{len(lua_files)} strict Luau files, "
        f"{len(REQUIRED_REMOTES)} remotes, 8 roles, 8 monsters, "
        "launch monetization disabled, and 3 Rojo mappings."
    )


if __name__ == "__main__":
    main()
