#!/usr/bin/env python3
"""Fail-closed validation for the sanitized unsigned INFINIDIVE Xcode scaffold."""

from __future__ import annotations

import argparse
import pathlib
import plistlib
import re
import xml.etree.ElementTree as ET


EXPECTED_BUNDLE_ID = "com.matan.infinidive"
EXPECTED_MARKETING_VERSION = "0.1.0"
EXPECTED_BUILD_VERSION = "1"
EXPECTED_MIN_IOS = "15.0"
EXPECTED_DISPLAY_NAME = "INFINIDIVE"
PORTRAIT_ONLY = ["UIInterfaceOrientationPortrait"]


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


def _preset_raw_value(text: str, key: str) -> str:
    matches = re.findall(rf"^{re.escape(key)}=([^\r\n]+)$", text, re.MULTILINE)
    if len(matches) != 1:
        raise MetadataError(f"preset key {key} must occur exactly once")
    return matches[0]


def _pbx_values(text: str, key: str) -> list[str]:
    return re.findall(rf'^\s*{re.escape(key)} = "?([^";]*)"?;\s*$', text, re.MULTILINE)


def _native_target_id(text: str) -> str:
    section_match = re.search(
        r"/\* Begin PBXNativeTarget section \*/(?P<section>.*?)"
        r"/\* End PBXNativeTarget section \*/",
        text,
        re.DOTALL,
    )
    if section_match is None:
        raise MetadataError("pbxproj has no PBXNativeTarget section")
    targets = re.findall(
        r'^\s*([A-F0-9]{24}) /\* ([^*\r\n]+) \*/ = \{\s*\n'
        r"\s*isa = PBXNativeTarget;",
        section_match.group("section"),
        re.MULTILINE,
    )
    if len(targets) != 1 or targets[0][1] != EXPECTED_DISPLAY_NAME:
        raise MetadataError(
            f"expected the sole native target to be {EXPECTED_DISPLAY_NAME}, found {targets!r}"
        )
    return targets[0][0]


def _validate_shared_scheme(root: pathlib.Path, target_id: str) -> None:
    scheme_path = _one(root, f"{EXPECTED_DISPLAY_NAME}.xcscheme")
    if (
        scheme_path.parent.name != "xcschemes"
        or scheme_path.parent.parent.name != "xcshareddata"
        or scheme_path.parent.parent.parent.name != f"{EXPECTED_DISPLAY_NAME}.xcodeproj"
    ):
        raise MetadataError(f"shared scheme is in an unexpected location: {scheme_path}")
    all_schemes = sorted(root.rglob("*.xcscheme"))
    if all_schemes != [scheme_path]:
        raise MetadataError(f"unexpected additional Xcode schemes: {all_schemes!r}")
    try:
        scheme_root = ET.fromstring(scheme_path.read_text(encoding="utf-8"))
    except ET.ParseError as exc:
        raise MetadataError(f"cannot parse shared Xcode scheme: {exc}") from exc
    references = list(scheme_root.iter("BuildableReference"))
    expected = {
        "BuildableIdentifier": "primary",
        "BlueprintIdentifier": target_id,
        "BuildableName": f"{EXPECTED_DISPLAY_NAME}.app",
        "BlueprintName": EXPECTED_DISPLAY_NAME,
        "ReferencedContainer": f"container:{EXPECTED_DISPLAY_NAME}.xcodeproj",
    }
    if len(references) != 4 or any(reference.attrib != expected for reference in references):
        raise MetadataError(
            "shared scheme is not bound exactly to the generated INFINIDIVE native target"
        )


def validate(root: pathlib.Path, preset: pathlib.Path) -> None:
    if root.is_symlink() or not root.is_dir():
        raise MetadataError(f"export root must be a non-symlink directory: {root}")
    if preset.is_symlink() or not preset.is_file():
        raise MetadataError(f"preset must be a regular non-symlink file: {preset}")
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
    targeted_family = _preset_raw_value(preset_text, "application/targeted_device_family")
    if targeted_family != "0":
        raise MetadataError(
            f"preset application/targeted_device_family={targeted_family!r}, expected '0'"
        )

    info_path = _one(root, "*-Info.plist")
    info = plistlib.loads(info_path.read_bytes())
    expected_info = {
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleShortVersionString": "$(MARKETING_VERSION)",
        "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
        "CFBundleDevelopmentRegion": "en",
        "CFBundleDisplayName": "$(INFOPLIST_KEY_CFBundleDisplayName)",
        "ITSAppUsesNonExemptEncryption": False,
        "LSRequiresIPhoneOS": True,
        "UIFileSharingEnabled": False,
        "LSSupportsOpeningDocumentsInPlace": False,
        "UILaunchStoryboardName": "Launch Screen",
        "UIRequiresFullScreen": True,
        "UISupportedInterfaceOrientations": PORTRAIT_ONLY,
        "UISupportedInterfaceOrientations~ipad": PORTRAIT_ONLY,
        "CFBundleIcons": {},
        "CFBundleIcons~ipad": {},
    }
    for key, expected in expected_info.items():
        if info.get(key) != expected:
            raise MetadataError(f"Info.plist {key}={info.get(key)!r}, expected {expected!r}")
    protected_usage_keys = sorted(
        key
        for key in info
        if key.startswith("NS") and key.endswith("UsageDescription")
    )
    if protected_usage_keys:
        raise MetadataError(
            "Info.plist contains protected-resource usage descriptions: "
            + ", ".join(protected_usage_keys)
        )

    entitlements_path = _one(root, "*.entitlements")
    entitlements = plistlib.loads(entitlements_path.read_bytes())
    if entitlements != {}:
        raise MetadataError(f"unsigned release scaffold has unreviewed entitlements: {entitlements!r}")

    pbx_path = _one(root, "project.pbxproj")
    pbx_text = pbx_path.read_text(encoding="utf-8")
    native_target_id = _native_target_id(pbx_text)
    expected_pbx = {
        "PRODUCT_BUNDLE_IDENTIFIER": (EXPECTED_BUNDLE_ID, 2),
        "MARKETING_VERSION": (EXPECTED_MARKETING_VERSION, 2),
        "CURRENT_PROJECT_VERSION": (EXPECTED_BUILD_VERSION, 2),
        "IPHONEOS_DEPLOYMENT_TARGET": (EXPECTED_MIN_IOS, 4),
        "DEVELOPMENT_TEAM": ("", 2),
        "SDKROOT": ("iphoneos", 2),
        "TARGETED_DEVICE_FAMILY": ("1", 4),
        "ASSETCATALOG_COMPILER_APPICON_NAME": ("AppIcon", 2),
        "INFOPLIST_KEY_CFBundleDisplayName": (EXPECTED_DISPLAY_NAME, 2),
        "PRODUCT_NAME": (EXPECTED_DISPLAY_NAME, 2),
        "EXECUTABLE_NAME": (EXPECTED_DISPLAY_NAME, 2),
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
    if re.findall(r"^\s*DevelopmentTeam = \"([^\"]*)\";\s*$", pbx_text, re.MULTILINE) != [""]:
        raise MetadataError("pbxproj project DevelopmentTeam must occur once and be empty")
    if re.findall(r"^\s*developmentRegion = ([^;]+);\s*$", pbx_text, re.MULTILINE) != ["en"]:
        raise MetadataError("pbxproj developmentRegion must occur once and be en")
    if "UsageDescription" in pbx_text:
        raise MetadataError("pbxproj contains a protected-resource usage-description override")
    _validate_shared_scheme(root, native_target_id)

    localized_strings = _one(root, "InfoPlist.strings")
    if localized_strings.parent.name != "en.lproj":
        raise MetadataError(
            f"InfoPlist.strings must use the en localization: {localized_strings}"
        )
    localization_dirs = sorted(path for path in root.rglob("*.lproj") if path.is_dir())
    if [path.name for path in localization_dirs] != ["en.lproj"]:
        raise MetadataError(
            f"unexpected iOS project localization directories: {localization_dirs!r}"
        )

    export_options = _one(root, "export_options.plist")
    export_value = plistlib.loads(export_options.read_bytes())
    if export_value.get("teamID", "") != "":
        raise MetadataError("sanitized export_options.plist must not retain a Team ID")
    print(
        "iOS project metadata validation: PASS "
        f"({EXPECTED_BUNDLE_ID} {EXPECTED_MARKETING_VERSION} ({EXPECTED_BUILD_VERSION}), "
        "English region, iPhone/portrait-only, target-bound shared scheme, AppIcon, empty entitlements, "
        "no protected-resource usage descriptions or retained Team ID)"
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
