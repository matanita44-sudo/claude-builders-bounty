#!/usr/bin/env python3
"""Fail-closed validation for the sanitized unsigned INFINIDIVE Xcode scaffold."""

from __future__ import annotations

import argparse
import pathlib
import plistlib
import re


EXPECTED_BUNDLE_ID = "com.matan.infinidive"
EXPECTED_MARKETING_VERSION = "0.1.0"
EXPECTED_BUILD_VERSION = "1"
EXPECTED_MIN_IOS = "15.0"


class MetadataError(RuntimeError):
    pass


def _one(root: pathlib.Path, pattern: str) -> pathlib.Path:
    matches = sorted(root.rglob(pattern))
    if len(matches) != 1:
        raise MetadataError(f"expected exactly one {pattern}, found {len(matches)}")
    path = matches[0]
    if path.is_symlink() or not path.is_file():
        raise MetadataError(f"metadata input must be a regular non-symlink file: {path}")
    return path


def _preset_value(text: str, key: str) -> str:
    matches = re.findall(rf'^{re.escape(key)}="([^"]*)"$', text, re.MULTILINE)
    if len(matches) != 1:
        raise MetadataError(f"preset key {key} must occur exactly once")
    return matches[0]


def _pbx_values(text: str, key: str) -> list[str]:
    return re.findall(rf'^\s*{re.escape(key)} = "?([^";]*)"?;\s*$', text, re.MULTILINE)


def validate(root: pathlib.Path, preset: pathlib.Path) -> None:
    if root.is_symlink() or not root.is_dir():
        raise MetadataError(f"export root must be a non-symlink directory: {root}")
    preset_text = preset.read_text(encoding="utf-8")
    expected_preset = {
        "application/bundle_identifier": EXPECTED_BUNDLE_ID,
        "application/short_version": EXPECTED_MARKETING_VERSION,
        "application/version": EXPECTED_BUILD_VERSION,
        "application/min_ios_version": EXPECTED_MIN_IOS,
        "application/app_store_team_id": "",
    }
    for key, expected in expected_preset.items():
        actual = _preset_value(preset_text, key)
        if actual != expected:
            raise MetadataError(f"preset {key}={actual!r}, expected {expected!r}")

    info_path = _one(root, "*-Info.plist")
    info = plistlib.loads(info_path.read_bytes())
    expected_info = {
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleShortVersionString": "$(MARKETING_VERSION)",
        "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
        "ITSAppUsesNonExemptEncryption": False,
        "UILaunchStoryboardName": "Launch Screen",
        "UIRequiresFullScreen": True,
    }
    for key, expected in expected_info.items():
        if info.get(key) != expected:
            raise MetadataError(f"Info.plist {key}={info.get(key)!r}, expected {expected!r}")

    entitlements_path = _one(root, "*.entitlements")
    entitlements = plistlib.loads(entitlements_path.read_bytes())
    if entitlements != {}:
        raise MetadataError(f"unsigned release scaffold has unreviewed entitlements: {entitlements!r}")

    pbx_path = _one(root, "project.pbxproj")
    pbx_text = pbx_path.read_text(encoding="utf-8")
    expected_pbx = {
        "PRODUCT_BUNDLE_IDENTIFIER": (EXPECTED_BUNDLE_ID, 2),
        "MARKETING_VERSION": (EXPECTED_MARKETING_VERSION, 2),
        "CURRENT_PROJECT_VERSION": (EXPECTED_BUILD_VERSION, 2),
        "IPHONEOS_DEPLOYMENT_TARGET": (EXPECTED_MIN_IOS, 4),
        "DEVELOPMENT_TEAM": ("", 2),
    }
    for key, (expected, expected_count) in expected_pbx.items():
        values = _pbx_values(pbx_text, key)
        if len(values) != expected_count or set(values) != {expected}:
            raise MetadataError(
                f"pbxproj {key} values={values!r}, "
                f"expected {expected_count} occurrence(s) of {expected!r}"
            )
    entitlement_refs = _pbx_values(pbx_text, "CODE_SIGN_ENTITLEMENTS")
    if len(entitlement_refs) != 2 or len(set(entitlement_refs)) != 1:
        raise MetadataError(f"unexpected CODE_SIGN_ENTITLEMENTS values: {entitlement_refs!r}")

    export_options = _one(root, "export_options.plist")
    export_value = plistlib.loads(export_options.read_bytes())
    if export_value.get("teamID", "") != "":
        raise MetadataError("sanitized export_options.plist must not retain a Team ID")
    print(
        "iOS project metadata validation: PASS "
        f"({EXPECTED_BUNDLE_ID} {EXPECTED_MARKETING_VERSION} ({EXPECTED_BUILD_VERSION}), "
        "empty entitlements, no retained Team ID)"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, type=pathlib.Path)
    parser.add_argument("--preset", required=True, type=pathlib.Path)
    args = parser.parse_args()
    try:
        validate(args.root, args.preset)
    except (MetadataError, OSError, plistlib.InvalidFileException, ValueError) as exc:
        print(f"iOS project metadata validation: FAIL: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
