"""Validate CAMP-Mystery's release content inventory.

The default mode validates inventory structure and catalog coverage. ``--require-ready``
is intentionally stricter: it fails until every final content input has an installed
source, license proof, and approved Roblox moderation record. Procedural fallbacks are
valid for development, not proof that release art is ready.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets/content-manifest.json"
ASSET_ID = re.compile(r"^[a-z0-9][a-z0-9-]*$")
UTC_STAMP = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

EXPECTED_MONSTERS = {
    "monster-baby-alien",
    "monster-screamer",
    "monster-wendigo",
    "monster-shadow",
    "monster-chupacabra",
    "monster-dullahan",
    "monster-entity",
    "monster-banshee",
}
EXPECTED_COUNSELORS = {
    "counselor-holloway",
    "counselor-ortiz",
    "counselor-reed",
    "counselor-brooks",
    "counselor-chen",
    "counselor-finch",
}
EXPECTED_RUNTIME_TARGETS = {
    "monster-baby-alien": "ServerStorage/ServerAssets/Monsters/BabyAlien",
    "monster-screamer": "ServerStorage/ServerAssets/Monsters/Screamer",
    "monster-wendigo": "ServerStorage/ServerAssets/Monsters/Wendigo",
    "monster-shadow": "ServerStorage/ServerAssets/Monsters/ShadowMonster",
    "monster-chupacabra": "ServerStorage/ServerAssets/Monsters/Chupacabra",
    "monster-dullahan": "ServerStorage/ServerAssets/Monsters/Dullahan",
    "monster-entity": "ServerStorage/ServerAssets/Monsters/Entity",
    "monster-banshee": "ServerStorage/ServerAssets/Monsters/Banshee",
    "counselor-holloway": "ServerStorage/ServerAssets/NPCs/counselor-holloway",
    "counselor-ortiz": "ServerStorage/ServerAssets/NPCs/counselor-ortiz",
    "counselor-reed": "ServerStorage/ServerAssets/NPCs/counselor-reed",
    "counselor-brooks": "ServerStorage/ServerAssets/NPCs/counselor-brooks",
    "counselor-chen": "ServerStorage/ServerAssets/NPCs/counselor-chen",
    "counselor-finch": "ServerStorage/ServerAssets/NPCs/counselor-finch",
    "world-day-camp": "ServerStorage/ServerAssets/Maps/Camp",
}
EXPECTED_KINDS = {
    "MonsterRig",
    "CounselorRig",
    "EnvironmentModel",
    "AnimationSet",
    "AudioBank",
    "ImageSet",
    "PublishingImage",
}
SOURCE_STATUSES = {"missing", "in_progress", "installed"}
LICENSE_STATUSES = {"pending", "owned", "licensed", "rejected"}
MODERATION_STATUSES = {
    "not_submitted",
    "pending",
    "approved",
    "rejected",
}


def _object(value: Any, label: str, errors: list[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return {}
    return value


def validate_manifest(require_ready: bool = False) -> tuple[list[str], list[str], dict[str, int]]:
    errors: list[str] = []
    blockers: list[str] = []
    character_runtime = (
        ROOT / "src/server/Services/CharacterAssetService.lua"
    ).read_text(encoding="utf-8")
    map_runtime = (ROOT / "src/server/Services/ProductionMapService.lua").read_text(
        encoding="utf-8"
    )
    for token in ('findAsset("Monsters", monsterId)', 'findAsset("NPCs", definition.id)'):
        if token not in character_runtime:
            errors.append(f"Character runtime asset contract changed: missing {token}")
    for token in ('cloneAuthoredMap("Camp")', 'cloneAuthoredMap("NightTown")'):
        if token not in map_runtime:
            errors.append(f"Map runtime asset contract changed: missing {token}")
    try:
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"Cannot load {MANIFEST.relative_to(ROOT)}: {error}"], [], {}

    if data.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1")
    if data.get("experience") != "CAMP-Mystery":
        errors.append("experience must be CAMP-Mystery")
    policy = _object(data.get("policy"), "policy", errors)
    for field in (
        "releaseRequiresInstalledSource",
        "releaseRequiresLicenseProof",
        "releaseRequiresRobloxModeration",
        "allowGeneratedFallbacksInDevelopment",
    ):
        if not isinstance(policy.get(field), bool):
            errors.append(f"policy.{field} must be boolean")

    assets = data.get("assets")
    if not isinstance(assets, list) or not assets:
        return errors + ["assets must be a non-empty array"], blockers, {}

    identifiers: list[str] = []
    targets: list[str] = []
    kinds: Counter[str] = Counter()
    for index, raw_asset in enumerate(assets):
        label = f"assets[{index}]"
        asset = _object(raw_asset, label, errors)
        identifier = asset.get("id")
        kind = asset.get("kind")
        display_name = asset.get("displayName")
        target = asset.get("target")
        source_status = asset.get("sourceStatus")
        notes = asset.get("notes")

        if not isinstance(identifier, str) or not ASSET_ID.fullmatch(identifier):
            errors.append(f"{label}.id must use lowercase kebab-case")
            identifier = f"invalid-{index}"
        identifiers.append(identifier)
        if kind not in EXPECTED_KINDS:
            errors.append(f"{identifier}.kind is unsupported: {kind!r}")
        elif isinstance(kind, str):
            kinds[kind] += 1
        if not isinstance(display_name, str) or not display_name.strip():
            errors.append(f"{identifier}.displayName is required")
        if not isinstance(target, str) or "/" not in target:
            errors.append(f"{identifier}.target must be a Roblox hierarchy path")
        else:
            targets.append(target)
            expected_target = EXPECTED_RUNTIME_TARGETS.get(identifier)
            if expected_target is not None and target != expected_target:
                errors.append(
                    f"{identifier}.target must match runtime path {expected_target}"
                )
        if source_status not in SOURCE_STATUSES:
            errors.append(f"{identifier}.sourceStatus is invalid")
        if not isinstance(notes, str):
            errors.append(f"{identifier}.notes must be a string")
        runtime_hook = asset.get("runtimeHook")
        if kind in {"AnimationSet", "AudioBank", "ImageSet"}:
            hook = _object(runtime_hook, f"{identifier}.runtimeHook", errors)
            hook_status = hook.get("status")
            if hook_status not in {"connected", "not_connected"}:
                errors.append(f"{identifier}.runtimeHook.status is invalid")
            hook_source = hook.get("source")
            hook_keys = hook.get("keys")
            if not isinstance(hook_source, str) or not isinstance(hook_keys, list):
                errors.append(f"{identifier}.runtimeHook source/keys are invalid")
            elif hook_status == "connected":
                source_path = ROOT / hook_source
                if not source_path.is_file():
                    errors.append(f"{identifier}.runtimeHook.source does not exist")
                elif not hook_keys:
                    errors.append(f"{identifier}.runtimeHook.keys cannot be empty")
                else:
                    source_text = source_path.read_text(encoding="utf-8")
                    missing_keys = [
                        key
                        for key in hook_keys
                        if not isinstance(key, str) or key not in source_text
                    ]
                    if missing_keys:
                        errors.append(
                            f"{identifier}.runtimeHook keys missing from source: {missing_keys}"
                        )
            if require_ready and hook_status != "connected":
                blockers.append(f"{identifier}: runtime asset hook is not connected")
        source_file = asset.get("sourceFile")
        if source_file is not None:
            if not isinstance(source_file, str) or not source_file.startswith("assets/"):
                errors.append(f"{identifier}.sourceFile must be a repository assets path")
            else:
                local_path = ROOT / source_file
                if not local_path.is_file():
                    errors.append(f"{identifier}.sourceFile does not exist: {source_file}")
                else:
                    expected_hash = asset.get("sha256")
                    actual_hash = hashlib.sha256(local_path.read_bytes()).hexdigest()
                    if not isinstance(expected_hash, str) or expected_hash != actual_hash:
                        errors.append(f"{identifier}.sha256 does not match {source_file}")
                    dimensions = asset.get("dimensions")
                    if local_path.suffix.lower() == ".png":
                        if not isinstance(dimensions, dict):
                            errors.append(f"{identifier}.dimensions are required for PNG")
                        else:
                            with local_path.open("rb") as image:
                                header = image.read(24)
                            if header[:8] != b"\x89PNG\r\n\x1a\n" or len(header) != 24:
                                errors.append(f"{identifier}.sourceFile is not a valid PNG")
                            else:
                                width, height = struct.unpack(">II", header[16:24])
                                if dimensions != {"width": width, "height": height}:
                                    errors.append(
                                        f"{identifier}.dimensions do not match PNG header"
                                    )

        license_record = _object(asset.get("license"), f"{identifier}.license", errors)
        license_status = license_record.get("status")
        if license_status not in LICENSE_STATUSES:
            errors.append(f"{identifier}.license.status is invalid")
        for field in ("owner", "sourceUrl", "proofPath", "terms"):
            if not isinstance(license_record.get(field), str):
                errors.append(f"{identifier}.license.{field} must be a string")

        moderation = _object(
            asset.get("moderation"),
            f"{identifier}.moderation",
            errors,
        )
        moderation_status = moderation.get("status")
        if moderation_status not in MODERATION_STATUSES:
            errors.append(f"{identifier}.moderation.status is invalid")
        roblox_asset_id = moderation.get("robloxAssetId")
        if roblox_asset_id is not None and (
            isinstance(roblox_asset_id, bool)
            or not isinstance(roblox_asset_id, int)
            or roblox_asset_id <= 0
        ):
            errors.append(
                f"{identifier}.moderation.robloxAssetId must be a positive integer or null"
            )
        reviewed_at = moderation.get("reviewedAtUtc")
        if reviewed_at is not None and (
            not isinstance(reviewed_at, str) or not UTC_STAMP.fullmatch(reviewed_at)
        ):
            errors.append(
                f"{identifier}.moderation.reviewedAtUtc must be UTC YYYY-MM-DDTHH:MM:SSZ or null"
            )

        if require_ready:
            if source_status != "installed":
                blockers.append(f"{identifier}: final source is not installed")
            if license_status not in {"owned", "licensed"}:
                blockers.append(f"{identifier}: license is not approved")
            elif not license_record.get("owner") or not license_record.get("proofPath"):
                blockers.append(f"{identifier}: license owner/proofPath is incomplete")
            if moderation_status != "approved":
                blockers.append(f"{identifier}: Roblox moderation is not approved")
            if not isinstance(roblox_asset_id, int) or isinstance(roblox_asset_id, bool):
                blockers.append(f"{identifier}: Roblox asset ID is not recorded")
            if not reviewed_at:
                blockers.append(f"{identifier}: moderation review time is not recorded")
            if isinstance(notes, str) and "before release" in notes.lower():
                blockers.append(f"{identifier}: inventory note requires release follow-up")

    duplicate_ids = sorted(
        identifier for identifier, count in Counter(identifiers).items() if count > 1
    )
    duplicate_targets = sorted(
        target for target, count in Counter(targets).items() if count > 1
    )
    if duplicate_ids:
        errors.append(f"duplicate asset IDs: {duplicate_ids}")
    if duplicate_targets:
        errors.append(f"duplicate target paths: {duplicate_targets}")

    monster_ids = {
        asset.get("id")
        for asset in assets
        if isinstance(asset, dict) and asset.get("kind") == "MonsterRig"
    }
    counselor_ids = {
        asset.get("id")
        for asset in assets
        if isinstance(asset, dict) and asset.get("kind") == "CounselorRig"
    }
    if monster_ids != EXPECTED_MONSTERS:
        errors.append(
            "MonsterRig inventory mismatch: "
            f"missing={sorted(EXPECTED_MONSTERS - monster_ids)}, "
            f"unexpected={sorted(monster_ids - EXPECTED_MONSTERS)}"
        )
    if counselor_ids != EXPECTED_COUNSELORS:
        errors.append(
            "CounselorRig inventory mismatch: "
            f"missing={sorted(EXPECTED_COUNSELORS - counselor_ids)}, "
            f"unexpected={sorted(counselor_ids - EXPECTED_COUNSELORS)}"
        )
    for kind, minimum in {
        "EnvironmentModel": 10,
        "AnimationSet": 2,
        "AudioBank": 4,
        "ImageSet": 1,
        "PublishingImage": 2,
    }.items():
        if kinds[kind] < minimum:
            errors.append(f"Expected at least {minimum} {kind} records")

    return errors, blockers, dict(sorted(kinds.items()))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--require-ready",
        action="store_true",
        help="Fail while any final source, license, or moderation proof is pending.",
    )
    args = parser.parse_args()
    errors, blockers, kinds = validate_manifest(args.require_ready)
    if errors:
        raise SystemExit("Content manifest is invalid:\n- " + "\n- ".join(errors))
    print(
        "Content manifest structure passed: "
        + ", ".join(f"{kind}={count}" for kind, count in kinds.items())
    )
    if blockers:
        raise SystemExit(
            "Content manifest is structurally valid but not release-ready:\n- "
            + "\n- ".join(blockers)
        )
    if args.require_ready:
        print("Every inventoried content asset has source, license, and moderation proof.")
    else:
        print(
            "Pending content is allowed in this structural check; "
            "use --require-ready for the public-release gate."
        )


if __name__ == "__main__":
    main()
