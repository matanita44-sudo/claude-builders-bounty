#!/usr/bin/env python3
"""Validate the exact native privacy manifest emitted for INFINIDIVE iOS."""

from __future__ import annotations

import argparse
import pathlib
import plistlib
import tempfile
from typing import Any


EXPECTED_REASONS = {
    "NSPrivacyAccessedAPICategoryFileTimestamp": {"C617.1"},
    "NSPrivacyAccessedAPICategorySystemBootTime": {"35F9.1"},
    "NSPrivacyAccessedAPICategoryDiskSpace": {"E174.1"},
}
ALLOWED_ROOT_KEYS = {
    "NSPrivacyAccessedAPITypes",
    "NSPrivacyCollectedDataTypes",
    "NSPrivacyTracking",
    "NSPrivacyTrackingDomains",
}


class PrivacyManifestError(RuntimeError):
    """The generated iOS privacy manifest differs from reviewed behavior."""


def validate_value(manifest: Any) -> None:
    if not isinstance(manifest, dict):
        raise PrivacyManifestError("privacy manifest root must be a dictionary")
    unknown_root_keys = set(manifest) - ALLOWED_ROOT_KEYS
    if unknown_root_keys:
        raise PrivacyManifestError(
            "privacy manifest contains unreviewed root keys: "
            + ", ".join(sorted(unknown_root_keys))
        )
    if manifest.get("NSPrivacyTracking") is not False:
        raise PrivacyManifestError("NSPrivacyTracking must be exactly false")
    for empty_key in ("NSPrivacyTrackingDomains", "NSPrivacyCollectedDataTypes"):
        value = manifest.get(empty_key, [])
        if not isinstance(value, list) or value:
            raise PrivacyManifestError(f"{empty_key} must be absent or an empty array")

    accessed = manifest.get("NSPrivacyAccessedAPITypes")
    if not isinstance(accessed, list):
        raise PrivacyManifestError("NSPrivacyAccessedAPITypes must be an array")
    actual: dict[str, set[str]] = {}
    for entry in accessed:
        if not isinstance(entry, dict):
            raise PrivacyManifestError("required-reason API entry must be a dictionary")
        if set(entry) != {
            "NSPrivacyAccessedAPIType",
            "NSPrivacyAccessedAPITypeReasons",
        }:
            raise PrivacyManifestError("required-reason API entry has unreviewed fields")
        category = entry.get("NSPrivacyAccessedAPIType")
        reasons = entry.get("NSPrivacyAccessedAPITypeReasons")
        if not isinstance(category, str) or not isinstance(reasons, list):
            raise PrivacyManifestError("required-reason API category/reasons have wrong types")
        if category in actual:
            raise PrivacyManifestError(f"duplicate required-reason API category: {category}")
        if not reasons or any(not isinstance(reason, str) for reason in reasons):
            raise PrivacyManifestError(f"invalid reason list for {category}")
        reason_set = set(reasons)
        if len(reason_set) != len(reasons):
            raise PrivacyManifestError(f"duplicate reason code for {category}")
        actual[category] = reason_set
    if actual != EXPECTED_REASONS:
        raise PrivacyManifestError(
            f"required-reason APIs differ from reviewed contract: {actual!r}"
        )


def validate(path: pathlib.Path) -> None:
    try:
        manifest = plistlib.loads(path.read_bytes())
    except (OSError, plistlib.InvalidFileException, ValueError) as exc:
        raise PrivacyManifestError(f"cannot parse privacy manifest {path}: {exc}") from exc
    validate_value(manifest)


def _valid_fixture() -> dict[str, Any]:
    return {
        "NSPrivacyTracking": False,
        "NSPrivacyAccessedAPITypes": [
            {
                "NSPrivacyAccessedAPIType": category,
                "NSPrivacyAccessedAPITypeReasons": sorted(reasons),
            }
            for category, reasons in EXPECTED_REASONS.items()
        ],
    }


def run_self_test() -> None:
    validate_value(_valid_fixture())
    invalid_fixtures = []
    tracking = _valid_fixture()
    tracking["NSPrivacyTracking"] = True
    invalid_fixtures.append(tracking)
    collected = _valid_fixture()
    collected["NSPrivacyCollectedDataTypes"] = [{"unexpected": True}]
    invalid_fixtures.append(collected)
    domain = _valid_fixture()
    domain["NSPrivacyTrackingDomains"] = ["example.invalid"]
    invalid_fixtures.append(domain)
    wrong_reason = _valid_fixture()
    wrong_reason["NSPrivacyAccessedAPITypes"][0][
        "NSPrivacyAccessedAPITypeReasons"
    ] = ["DDA9.1"]
    invalid_fixtures.append(wrong_reason)
    extra_category = _valid_fixture()
    extra_category["NSPrivacyAccessedAPITypes"].append(
        {
            "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
            "NSPrivacyAccessedAPITypeReasons": ["CA92.1"],
        }
    )
    invalid_fixtures.append(extra_category)
    unknown = _valid_fixture()
    unknown["UnreviewedKey"] = True
    invalid_fixtures.append(unknown)
    for index, fixture in enumerate(invalid_fixtures):
        try:
            validate_value(fixture)
        except PrivacyManifestError:
            continue
        raise AssertionError(f"privacy-manifest negative fixture {index} was accepted")

    with tempfile.TemporaryDirectory(prefix="infinidive-privacy-manifest-test-") as root:
        malformed = pathlib.Path(root) / "PrivacyInfo.xcprivacy"
        malformed.write_bytes(b"not a plist")
        try:
            validate(malformed)
        except PrivacyManifestError:
            pass
        else:
            raise AssertionError("malformed privacy manifest was accepted")
    print("iOS privacy-manifest validator self-test: PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", nargs="?", type=pathlib.Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test == (args.manifest is not None):
        parser.error("use exactly one of --self-test or a manifest path")
    try:
        if args.self_test:
            run_self_test()
        else:
            validate(args.manifest)
            print(f"iOS privacy-manifest validation: PASS ({args.manifest})")
    except (PrivacyManifestError, AssertionError) as exc:
        print(f"iOS privacy-manifest validation: FAIL: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
