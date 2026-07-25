"""Structural validation for the CAMP-Mystery Rojo project."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT_FILE = ROOT / "default.project.json"
REQUIRED_FILES = (
    ROOT / "src/shared/Types/GameTypes.lua",
    ROOT / "src/shared/Types/CounselorTypes.lua",
    ROOT / "src/shared/Types/ParticipantTypes.lua",
    ROOT / "src/shared/Types/EquipmentTypes.lua",
    ROOT / "src/shared/Types/CombatTypes.lua",
    ROOT / "src/shared/Types/EvidenceTypes.lua",
    ROOT / "src/shared/Types/MonsterTypes.lua",
    ROOT / "src/shared/Types/MysteryTypes.lua",
    ROOT / "src/shared/Types/ProfileTypes.lua",
    ROOT / "src/shared/Types/MatchTypes.lua",
    ROOT / "src/shared/Types/BotTypes.lua",
    ROOT / "src/shared/Types/WorldTypes.lua",
    ROOT / "src/shared/Types/RuntimeTypes.lua",
    ROOT / "src/shared/Config/RoleCatalog.lua",
    ROOT / "src/shared/Config/EquipmentCatalog.lua",
    ROOT / "src/shared/Config/PublicMonsterCatalog.lua",
    ROOT / "src/shared/Config/ProgressionConfig.lua",
    ROOT / "src/shared/Config/CosmeticCatalog.lua",
    ROOT / "src/shared/Config/UpgradeCatalog.lua",
    ROOT / "src/shared/Config/MatchConfig.lua",
    ROOT / "src/shared/Config/RoundConfig.lua",
    ROOT / "src/server/Config/EquipmentRules.lua",
    ROOT / "src/server/Config/CounselorCatalog.lua",
    ROOT / "src/server/Config/EvidenceRules.lua",
    ROOT / "src/server/Config/MonsterRules.lua",
    ROOT / "src/server/Config/MysteryCatalog.lua",
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
    ROOT / "src/server/Services/CounselorService.lua",
    ROOT / "src/server/Services/MysteryService.lua",
    ROOT / "src/server/Services/WorldService.lua",
    ROOT / "src/server/Services/RoundLifecycle.lua",
    ROOT / "src/server/Services/GameRuntimeService.lua",
    ROOT / "src/server/Services/RoleAbilityService.lua",
    ROOT / "src/server/Services/StatusEffectService.lua",
    ROOT / "src/server/Services/VotingService.lua",
    ROOT / "src/server/Services/CharacterAssetService.lua",
    ROOT / "src/server/Adapters/MemoryProfileStore.lua",
    ROOT / "src/server/Adapters/RobloxProfileStore.lua",
    ROOT / "src/server/Systems/RewardCalculation.lua",
    ROOT / "src/server/Systems/BotRosterSystem.lua",
    ROOT / "src/server/Utilities/Cleanup.lua",
    ROOT / "src/server/Services/ProductionMapService.lua",
    ROOT / "src/server/Bootstrap.server.lua",
    ROOT / "src/client/Controllers/RoundController.lua",
    ROOT / "src/client/Controllers/AccessibilityController.lua",
    ROOT / "src/client/Controllers/AudioController.lua",
    ROOT / "src/client/Controllers/RemoteBridge.lua",
    ROOT / "src/client/Controllers/InputController.lua",
    ROOT / "src/client/Controllers/InteractionController.lua",
    ROOT / "src/client/Controllers/TutorialController.lua",
    ROOT / "src/client/UI/GameView.lua",
    ROOT / "src/client/UI/Components.lua",
    ROOT / "src/client/UI/EffectsView.lua",
    ROOT / "src/client/UI/Theme.lua",
    ROOT / "src/client/UI/TutorialView.lua",
    ROOT / "src/client/Bootstrap.client.lua",
)
REQUIRED_REMOTES = {
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

SERVICE_API_CONTRACTS = {
    ROOT / "src/server/Services/LobbyService.lua": {
        "AddPlayer",
        "RemovePlayer",
        "SetReady",
        "GetReadyHumans",
        "GetSnapshot",
    },
    ROOT / "src/server/Services/MatchmakingService.lua": {
        "SetReady",
        "Tick",
        "GetActiveRoster",
        "FinishRound",
    },
    ROOT / "src/server/Services/ComputerPlayerService.lua": {
        "BeginRound",
        "GetRuntimeSnapshot",
        "StepBot",
        "StepAll",
    },
    ROOT / "src/server/Services/ProfileService.lua": {
        "LoadPlayer",
        "ReleasePlayer",
        "ApplyReward",
        "UpdateSettings",
        "PurchaseUpgrade",
        "UnlockCosmetic",
        "EquipCosmetic",
    },
    ROOT / "src/server/Systems/BotRosterSystem.lua": {
        "FillEmptySlots",
        "FillReplacement",
        "ReleaseRound",
    },
}


def require_tokens(path: Path, tokens: set[str]) -> None:
    contents = path.read_text(encoding="utf-8")
    missing = sorted(token for token in tokens if token not in contents)
    if missing:
        raise SystemExit(
            f"{path.relative_to(ROOT)} is missing required tokens: {missing}"
        )


def require_service_methods(path: Path, methods: set[str]) -> None:
    contents = path.read_text(encoding="utf-8")
    missing = sorted(
        method
        for method in methods
        if f":{method}(" not in contents
    )
    if missing:
        raise SystemExit(
            f"{path.relative_to(ROOT)} is missing service methods: {missing}"
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
    require_tokens(
        ROOT / "src/server/Bootstrap.server.lua",
        {
            "GameRuntimeService",
            "GetGameState",
            "RequestAction",
            "GameStateChanged",
            "runtime:Start()",
        },
    )
    require_tokens(
        ROOT / "src/server/Services/GameRuntimeService.lua",
        {
            "TextService:FilterStringAsync",
            "self:_isNearPart",
            "self.computerPlayers:BeginRound",
            "self.matchmaking:MarkRoundStarted",
            "self.profile:ApplyReward",
        },
    )
    require_tokens(
        ROOT / "src/server/Services/ProfileService.lua",
        {
            "RunService:IsStudio()",
            "MemoryProfileStore.new()",
            "recentRewardReceipts",
        },
    )
    require_tokens(
        ROOT / "src/shared/Config/MatchConfig.lua",
        {
            "standardTarget = 10",
            "maximumParticipants = 12",
            "fillCountdownSeconds = 150",
        },
    )
    for path, methods in SERVICE_API_CONTRACTS.items():
        require_service_methods(path, methods)

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
