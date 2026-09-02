#!/usr/bin/env python3
"""Fail-closed validation for INFINIDIVE's signed App Store archive and IPA.

The release workflow uses this file in three modes:

* validate the checked-in blank-Team-ID source preset against dispatch inputs;
* validate a decoded App Store provisioning profile before it is installed; and
* validate the signed xcarchive and exported IPA, then write bounded JSON evidence.

No certificate, private key, provisioning-profile payload, signing identity, or
Apple Team ID is written to the evidence document.
"""

from __future__ import annotations

import argparse
import datetime as dt
import email.utils
import hashlib
import json
import os
import pathlib
import plistlib
import re
import stat
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from typing import Any

import validate_ios_privacy_manifest as privacy_validation


EXPECTED_DISPLAY_NAME = "INFINIDIVE"
EXPECTED_MIN_IOS = "15.0"
EXPECTED_XCODE_CONTROL_HASHES = {
    "project.pbxproj": "50a0ce406d1cfedbbfb3bf10133732a5f98075499a81ef6d08edb79e0b6693fc",
    "project.xcworkspace/contents.xcworkspacedata": (
        "46f98ef7c427a171215e5cf716162e429760c5ffb2f85ef1037d651d31ffe769"
    ),
    "xcshareddata/xcschemes/INFINIDIVE.xcscheme": (
        "cdbfdbfbe60b8beae7e0cefce27dd9fb553da9cbfd552e2ef09576863f964dc5"
    ),
}
PORTRAIT_ONLY = ["UIInterfaceOrientationPortrait"]
SUPPORTED_LOCALIZATIONS = ["en", "he"]
TEAM_PATTERN = re.compile(r"^[A-Z0-9]{10}$")
BUNDLE_PATTERN = re.compile(
    r"^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?"
    r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$"
)
VERSION_COMPONENT = r"(?:0|[1-9][0-9]*)"
VERSION_PATTERN = re.compile(rf"^{VERSION_COMPONENT}(?:\.{VERSION_COMPONENT}){{1,2}}$")
BUILD_PATTERN = re.compile(rf"^{VERSION_COMPONENT}(?:\.{VERSION_COMPONENT}){{0,2}}$")
APPLE_APP_ID_PATTERN = re.compile(r"^[1-9][0-9]{5,14}$")
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
UUID_PATTERN = re.compile(
    r"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$"
)
SWIFT_DYLIB_PATTERN = re.compile(r"^libswift[A-Za-z0-9_]+\.dylib$")
ALLOWED_SIGNED_ENTITLEMENTS = {
    "application-identifier",
    "beta-reports-active",
    "com.apple.developer.team-identifier",
    "get-task-allow",
    "keychain-access-groups",
}
MAX_IPA_ENTRIES = 25_000
MAX_IPA_UNCOMPRESSED_BYTES = 2 * 1024 * 1024 * 1024
IOS_PRESET_GENERAL = {
    "advanced_options": "false",
    "custom_features": '"mobile"',
    "dedicated_server": "false",
    "encrypt_directory": "false",
    "encrypt_pck": "false",
    "encryption_exclude_filters": '""',
    "encryption_include_filters": '""',
    "exclude_filter": (
        '"tests/*,artifacts/*,tools/*,assets/store/*,'
        'assets/audio/generated/trailer/*,assets/platform/ios/*,'
        'assets/brand/android_adaptive_*.svg,assets/brand/feature_graphic.svg,'
        'assets/brand/logo_mark.svg,assets/brand/social_card.svg,'
        'assets/brand/wordmark.svg"'
    ),
    "export_filter": '"all_resources"',
    "export_path": '"../build/ios/INFINIDIVE.xcodeproj"',
    "include_filter": '""',
    "name": '"iOS"',
    "platform": '"iOS"',
    "runnable": "true",
    "script_export_mode": "2",
}
IOS_PRESET_STATIC_OPTIONS = {
    "application/app_store_team_id": '""',
    "application/min_ios_version": '"15.0"',
    "application/signature": '""',
    "application/supports_multiple_windows": "false",
    "application/targeted_device_family": "0",
    "custom_template/debug": '""',
    "custom_template/release": '""',
    "icons/app_store_1024x1024": '"res://assets/platform/ios/icon-1024.png"',
    "icons/ios_128x128": '"res://assets/platform/ios/icon-128.png"',
    "icons/ios_136x136": '"res://assets/platform/ios/icon-136.png"',
    "icons/ios_192x192": '"res://assets/platform/ios/icon-192.png"',
    "icons/ipad_152x152": '"res://assets/platform/ios/icon-152.png"',
    "icons/ipad_167x167": '"res://assets/platform/ios/icon-167.png"',
    "icons/iphone_120x120": '"res://assets/platform/ios/icon-120.png"',
    "icons/iphone_180x180": '"res://assets/platform/ios/icon-180.png"',
    "icons/notification_114x114": '"res://assets/platform/ios/icon-114.png"',
    "icons/notification_40x40": '"res://assets/platform/ios/icon-40.png"',
    "icons/notification_60x60": '"res://assets/platform/ios/icon-60.png"',
    "icons/notification_76x76": '"res://assets/platform/ios/icon-76.png"',
    "icons/settings_58x58": '"res://assets/platform/ios/icon-58.png"',
    "icons/settings_87x87": '"res://assets/platform/ios/icon-87.png"',
    "icons/spotlight_120x120": '"res://assets/platform/ios/icon-120.png"',
    "icons/spotlight_80x80": '"res://assets/platform/ios/icon-80.png"',
    "privacy/active_keyboard_access_reasons": "0",
    "privacy/disk_space_access_reasons": "1",
    "privacy/file_timestamp_access_reasons": "2",
    "privacy/system_boot_time_access_reasons": "1",
    "privacy/tracking_domains": "PackedStringArray()",
    "privacy/tracking_enabled": "false",
    "privacy/user_defaults_access_reasons": "0",
    "storyboard/custom_image@2x": (
        '"res://assets/platform/ios/launch_screen@2x.png"'
    ),
    "storyboard/custom_image@3x": '"res://assets/platform/ios/launch_screen.png"',
    "storyboard/custom_bg_color": "Color(0.47, 0.82, 0.88, 1)",
    "storyboard/image_scale_mode": "3",
    "storyboard/use_custom_bg_color": "true",
}
ALLOWED_PBX_SECTIONS = {
    "PBXBuildFile",
    "PBXCopyFilesBuildPhase",
    "PBXFileReference",
    "PBXFrameworksBuildPhase",
    "PBXGroup",
    "PBXHeadersBuildPhase",
    "PBXNativeTarget",
    "PBXProject",
    "PBXResourcesBuildPhase",
    "PBXSourcesBuildPhase",
    "PBXVariantGroup",
    "XCBuildConfiguration",
    "XCConfigurationList",
}
ALLOWED_PBX_ISAS = set(ALLOWED_PBX_SECTIONS)
REQUIRED_PBX_SECTIONS = {
    "PBXBuildFile",
    "PBXFileReference",
    "PBXNativeTarget",
    "PBXProject",
    "PBXResourcesBuildPhase",
    "PBXSourcesBuildPhase",
    "XCBuildConfiguration",
    "XCConfigurationList",
}
FORBIDDEN_PBX_TEXT = (
    "PBXAggregateTarget",
    "PBXAppleScriptBuildPhase",
    "PBXBuildRule",
    "PBXContainerItemProxy",
    "PBXLegacyTarget",
    "PBXShellScriptBuildPhase",
    "PBXTargetDependency",
    "XCRemoteSwiftPackageReference",
    "XCLocalSwiftPackageReference",
    "XCSwiftPackageProductDependency",
    "baseConfigurationReference",
    "packageReferences",
    "shellPath =",
    "shellScript =",
)
FORBIDDEN_BUILD_SETTING_PATTERN = re.compile(
    r'^\s*"?(?:'
    r"ALTERNATE_GROUP|ALTERNATE_MODE|ALTERNATE_OWNER|"
    r"ASSETCATALOG_COMPILER|CC|CLANG_EXEC|CODE_SIGN_INJECT_BASE_ENTITLEMENTS|"
    r"CXX|EXCLUDED_SOURCE_FILE_NAMES|GCC_PREFIX_HEADER|INFOPLIST_PREFIX_HEADER|"
    r"INFOPLIST_PREPROCESS|LD|LDPLUSPLUS|LIBTOOL|OTHER_CODE_SIGN_FLAGS|"
    r"REZ_EXECUTABLE|SCRIPT_INPUT_FILE(?:_[0-9]+)?|"
    r"SCRIPT_OUTPUT_FILE(?:_[0-9]+)?|SWIFT_DRIVER_EXEC|SWIFT_EXEC"
    r')"?\s*=',
    re.MULTILINE,
)
FORBIDDEN_COMPILER_FLAG_PATTERN = re.compile(
    r"(?:^|[\s\"])(?:-fplugin(?:=|\s)|-fpass-plugin(?:=|\s)|-load(?:\s|$)|"
    r"-mllvm(?:\s|$)|-plugin-path(?:\s|=)|-Xclang(?:\s|$)|@(?:\$\(|\$\{|/))"
)
EXPECTED_SCHEME_ACTIONS = [
    "BuildAction",
    "TestAction",
    "LaunchAction",
    "ProfileAction",
    "AnalyzeAction",
    "ArchiveAction",
]
ALLOWED_SCHEME_ELEMENTS = {
    "AdditionalOptions",
    "AnalyzeAction",
    "ArchiveAction",
    "BuildAction",
    "BuildActionEntries",
    "BuildActionEntry",
    "BuildableProductRunnable",
    "BuildableReference",
    "CommandLineArguments",
    "LaunchAction",
    "MacroExpansion",
    "ProfileAction",
    "Scheme",
    "TestAction",
    "Testables",
}
PROJECT_BUILD_SETTINGS_COMMON = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "ARCHS": '"arm64"',
    "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++0x"',
    "CLANG_CXX_LIBRARY": '"libc++"',
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_WARN_BOOL_CONVERSION": "YES",
    "CLANG_WARN_CONSTANT_CONVERSION": "YES",
    "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
    "CLANG_WARN_EMPTY_BODY": "YES",
    "CLANG_WARN_ENUM_CONVERSION": "YES",
    "CLANG_WARN_INT_CONVERSION": "YES",
    "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
    "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
    "ENABLE_BITCODE": "NO",
    "FRAMEWORK_SEARCH_PATHS[arch=*]": ('"$(PROJECT_DIR)/**"',),
    "GCC_C_LANGUAGE_STANDARD": "gnu99",
    "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
    "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
    "GCC_WARN_UNDECLARED_SELECTOR": "YES",
    "GCC_WARN_UNINITIALIZED_AUTOS": "YES",
    "GCC_WARN_UNUSED_FUNCTION": "YES",
    "GCC_WARN_UNUSED_VARIABLE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "15.0",
    "LD_CLASSIC_1500": '"-ld_classic"',
    "LD_CLASSIC_1501": '"-ld_classic"',
    "LD_CLASSIC_1510": '"-ld_classic"',
    "OTHER_LDFLAGS": '"$(LD_CLASSIC_$(XCODE_VERSION_ACTUAL))  "',
    "SDKROOT": "iphoneos",
    "TARGETED_DEVICE_FAMILY": '"1"',
}
TARGET_BUILD_SETTINGS_COMMON = {
    "ARCHS": '"arm64"',
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "CLANG_ENABLE_MODULES": "YES",
    "CODE_SIGN_ENTITLEMENTS": '"INFINIDIVE/INFINIDIVE.entitlements"',
    "CODE_SIGN_STYLE": '"Automatic"',
    "CONFIGURATION_BUILD_DIR": '"$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)"',
    "CURRENT_PROJECT_VERSION": "1",
    "DEVELOPMENT_TEAM": '""',
    "EXECUTABLE_NAME": '"INFINIDIVE"',
    "INFOPLIST_FILE": '"INFINIDIVE/INFINIDIVE-Info.plist"',
    "INFOPLIST_KEY_CFBundleDisplayName": '"INFINIDIVE"',
    "IPHONEOS_DEPLOYMENT_TARGET": "15.0",
    "LD_RUNPATH_SEARCH_PATHS": ('"$(inherited)"', '"@executable_path/Frameworks"'),
    "LIBRARY_SEARCH_PATHS": ('"$(inherited)"', '"$(PROJECT_DIR)/**"'),
    "MARKETING_VERSION": "0.1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.matan.infinidive",
    "PRODUCT_NAME": '"INFINIDIVE"',
    "PROVISIONING_PROFILE": '""',
    "PROVISIONING_PROFILE_SPECIFIER": '""',
    "SWIFT_OBJC_BRIDGING_HEADER": '"INFINIDIVE/dummy.h"',
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": '"1"',
    "VALID_ARCHS": '"arm64 x86_64"',
    "WRAPPER_EXTENSION": "app",
}


def _expected_xc_build_configurations() -> dict[tuple[str, str], dict[str, Any]]:
    project_debug = dict(PROJECT_BUILD_SETTINGS_COMMON)
    project_debug.update(
        {
            "CODE_SIGN_IDENTITY": '"Apple Development"',
            "COPY_PHASE_STRIP": "NO",
            "GCC_DYNAMIC_NO_PIC": "NO",
            "GCC_OPTIMIZATION_LEVEL": "0",
            "GCC_PREPROCESSOR_DEFINITIONS": ('"$(inherited)"',),
            "GCC_SYMBOLS_PRIVATE_EXTERN": "NO",
        }
    )
    project_release = dict(PROJECT_BUILD_SETTINGS_COMMON)
    project_release.update(
        {
            "CODE_SIGN_IDENTITY": '"Apple Distribution"',
            "COPY_PHASE_STRIP": "YES",
            "ENABLE_NS_ASSERTIONS": "NO",
            "VALIDATE_PRODUCT": "YES",
        }
    )
    target_debug = dict(TARGET_BUILD_SETTINGS_COMMON)
    target_debug["CODE_SIGN_IDENTITY"] = '"Apple Development"'
    target_release = dict(TARGET_BUILD_SETTINGS_COMMON)
    target_release["CODE_SIGN_IDENTITY"] = '"Apple Distribution"'
    return {
        ("project", "Debug"): project_debug,
        ("project", "Release"): project_release,
        ("target", "Debug"): target_debug,
        ("target", "Release"): target_release,
    }


class ReleaseValidationError(RuntimeError):
    """The signed release does not match the reviewed release contract."""


def _regular_file(path: pathlib.Path, label: str) -> pathlib.Path:
    if path.is_symlink() or not path.is_file():
        raise ReleaseValidationError(f"{label} must be a regular non-symlink file: {path}")
    if path.stat().st_size < 1:
        raise ReleaseValidationError(f"{label} must not be empty: {path}")
    return path


def _regular_directory(path: pathlib.Path, label: str) -> pathlib.Path:
    if path.is_symlink() or not path.is_dir():
        raise ReleaseValidationError(
            f"{label} must be a non-symlink directory: {path}"
        )
    return path


def _reject_tree_symlinks(root: pathlib.Path, label: str) -> None:
    _regular_directory(root, label)
    if any(candidate.is_symlink() for candidate in root.rglob("*")):
        raise ReleaseValidationError(f"{label} contains a symlink")


def _one(paths: list[pathlib.Path], label: str) -> pathlib.Path:
    if len(paths) != 1:
        raise ReleaseValidationError(f"expected exactly one {label}, found {len(paths)}")
    return paths[0]


def _sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with _regular_file(path, "hash input").open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _validate_source_pck_hash(expected_sha256: str, archive_sha256: str) -> None:
    if SHA256_PATTERN.fullmatch(expected_sha256) is None:
        raise ReleaseValidationError("source PCK SHA-256 must be 64 lowercase hex characters")
    if SHA256_PATTERN.fullmatch(archive_sha256) is None:
        raise ReleaseValidationError("archive PCK SHA-256 is malformed")
    if archive_sha256 != expected_sha256:
        raise ReleaseValidationError("archived PCK does not match the source-bound scaffold")


def _plist(path: pathlib.Path, label: str) -> dict[str, Any]:
    try:
        value = plistlib.loads(_regular_file(path, label).read_bytes())
    except (OSError, plistlib.InvalidFileException, ValueError) as exc:
        raise ReleaseValidationError(f"cannot parse {label}: {path}") from exc
    if not isinstance(value, dict):
        raise ReleaseValidationError(f"{label} root must be a dictionary: {path}")
    return value


def _run(command: list[str], label: str) -> subprocess.CompletedProcess[bytes]:
    try:
        result = subprocess.run(command, check=False, capture_output=True)
    except OSError as exc:
        raise ReleaseValidationError(f"cannot execute {label}") from exc
    if result.returncode != 0:
        raise ReleaseValidationError(f"{label} failed with exit code {result.returncode}")
    return result


def _validate_coordinates(
    bundle_id: str,
    marketing_version: str,
    build_number: str,
    team_id: str | None = None,
) -> None:
    if BUNDLE_PATTERN.fullmatch(bundle_id) is None or len(bundle_id) > 255:
        raise ReleaseValidationError("bundle identifier is malformed")
    if VERSION_PATTERN.fullmatch(marketing_version) is None:
        raise ReleaseValidationError("marketing version must contain two or three integers")
    if BUILD_PATTERN.fullmatch(build_number) is None:
        raise ReleaseValidationError("build number must contain one to three integers")
    if team_id is not None and TEAM_PATTERN.fullmatch(team_id) is None:
        raise ReleaseValidationError("Apple Team ID must be ten uppercase letters/digits")


def _sections(text: str) -> dict[str, str]:
    matches = list(re.finditer(r"^\[([^\]\r\n]+)\]\s*$", text, re.MULTILINE))
    result: dict[str, str] = {}
    for index, match in enumerate(matches):
        name = match.group(1)
        if name in result:
            raise ReleaseValidationError(f"duplicate export-preset section: {name}")
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        result[name] = text[match.end() : end]
    return result


def _section_assignments(body: str, label: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in body.splitlines():
        if not line:
            continue
        if line != line.strip() or "=" not in line:
            raise ReleaseValidationError(f"{label} contains a malformed assignment")
        key, value = line.split("=", 1)
        if re.fullmatch(r"[A-Za-z0-9_./@-]+", key) is None or not value:
            raise ReleaseValidationError(f"{label} contains a malformed key or value")
        if key in result:
            raise ReleaseValidationError(f"{label} contains duplicate key {key}")
        result[key] = value
    return result


def _require_exact_assignments(
    actual: dict[str, str], expected: dict[str, str], label: str
) -> None:
    missing = sorted(set(expected) - set(actual))
    unexpected = sorted(set(actual) - set(expected))
    mismatched = sorted(key for key in expected.keys() & actual.keys() if actual[key] != expected[key])
    if missing or unexpected or mismatched:
        details = []
        for name, values in (
            ("missing", missing),
            ("unexpected", unexpected),
            ("mismatched", mismatched),
        ):
            if values:
                details.append(f"{name}: {', '.join(values)}")
        raise ReleaseValidationError(f"{label} violates the allowlist ({'; '.join(details)})")


def validate_source(
    preset_path: pathlib.Path,
    project_path: pathlib.Path,
    bundle_id: str,
    marketing_version: str,
    build_number: str,
) -> None:
    """Validate immutable release coordinates and the blank source Team ID."""

    _validate_coordinates(bundle_id, marketing_version, build_number)
    text = _regular_file(preset_path, "export preset").read_text(encoding="utf-8")
    sections = _sections(text)
    indexes = []
    for name, body in sections.items():
        match = re.fullmatch(r"preset\.(\d+)", name)
        if match and re.search(r'^name="iOS"$', body, re.MULTILINE):
            indexes.append(match.group(1))
    if len(indexes) != 1:
        raise ReleaseValidationError(f"expected one iOS export preset, found {len(indexes)}")
    preset_name = f"preset.{indexes[0]}"
    options_name = f"{preset_name}.options"
    if options_name not in sections:
        raise ReleaseValidationError("iOS export-preset options are missing")
    _require_exact_assignments(
        _section_assignments(sections[preset_name], "iOS preset"),
        IOS_PRESET_GENERAL,
        "iOS preset",
    )
    expected_options = dict(IOS_PRESET_STATIC_OPTIONS)
    expected_options.update(
        {
            "application/bundle_identifier": f'"{bundle_id}"',
            "application/short_version": f'"{marketing_version}"',
            "application/version": f'"{build_number}"',
        }
    )
    _require_exact_assignments(
        _section_assignments(sections[options_name], "iOS preset options"),
        expected_options,
        "iOS preset options",
    )

    project_text = _regular_file(project_path, "Godot project").read_text(encoding="utf-8")
    versions = re.findall(r'^config/version="([^"]+)"$', project_text, re.MULTILINE)
    if versions != [marketing_version]:
        raise ReleaseValidationError(
            "project.godot config/version must exactly match the release marketing version"
        )
    print(
        "iOS release source validation: PASS "
        f"({bundle_id} {marketing_version} ({build_number}), blank Team ID)"
    )


def _validate_xc_build_configurations(text: str) -> None:
    matches = re.findall(
        r"/\* Begin XCBuildConfiguration section \*/(.*?)"
        r"/\* End XCBuildConfiguration section \*/",
        text,
        re.DOTALL,
    )
    if len(matches) != 1:
        raise ReleaseValidationError("Xcode project must contain one build-configuration section")
    lines = [line.strip() for line in matches[0].splitlines() if line.strip()]
    parsed: dict[tuple[str, str], dict[str, Any]] = {}
    index = 0
    while index < len(lines):
        header = re.fullmatch(
            r"[A-F0-9]{24} /\* (Debug|Release) \*/ = \{",
            lines[index],
        )
        if header is None:
            raise ReleaseValidationError("Xcode build configuration is not canonical")
        configuration = header.group(1)
        index += 1
        if index >= len(lines) or lines[index] != "isa = XCBuildConfiguration;":
            raise ReleaseValidationError("Xcode build configuration ISA is not canonical")
        index += 1
        if index >= len(lines) or lines[index] != "buildSettings = {":
            raise ReleaseValidationError("Xcode buildSettings block is not canonical")
        index += 1
        settings: dict[str, Any] = {}
        while index < len(lines) and lines[index] != "};":
            assignment = re.fullmatch(
                r'(?:"([^"\\]+)"|([A-Za-z0-9_]+)) = (?:(\()|(.*);)',
                lines[index],
            )
            if assignment is None:
                raise ReleaseValidationError("Xcode build setting syntax is not canonical")
            key = assignment.group(1) or assignment.group(2)
            value = assignment.group(3) or assignment.group(4)
            if key in settings:
                raise ReleaseValidationError("Xcode build configuration repeats a setting")
            index += 1
            if value == "(":
                items: list[str] = []
                while index < len(lines) and lines[index] != ");":
                    item = re.fullmatch(r"(.+),", lines[index])
                    if item is None:
                        raise ReleaseValidationError("Xcode build-setting array is not canonical")
                    items.append(item.group(1))
                    index += 1
                if index >= len(lines) or not items:
                    raise ReleaseValidationError("Xcode build-setting array is malformed")
                settings[key] = tuple(items)
                index += 1
            else:
                settings[key] = value
        if index >= len(lines) or lines[index] != "};":
            raise ReleaseValidationError("Xcode buildSettings block is unterminated")
        index += 1
        if index >= len(lines) or lines[index] != f"name = {configuration};":
            raise ReleaseValidationError("Xcode build configuration name is inconsistent")
        index += 1
        if index >= len(lines) or lines[index] != "};":
            raise ReleaseValidationError("Xcode build configuration object is unterminated")
        index += 1
        scope = "target" if "PRODUCT_BUNDLE_IDENTIFIER" in settings else "project"
        coordinate = (scope, configuration)
        if coordinate in parsed:
            raise ReleaseValidationError("Xcode project repeats a build configuration")
        parsed[coordinate] = settings

    expected = _expected_xc_build_configurations()
    if parsed != expected:
        details: list[str] = []
        for coordinate in sorted(set(parsed) | set(expected)):
            actual = parsed.get(coordinate, {})
            wanted = expected.get(coordinate, {})
            missing = sorted(set(wanted) - set(actual))
            unexpected = sorted(set(actual) - set(wanted))
            mismatched = sorted(
                key for key in set(actual) & set(wanted) if actual[key] != wanted[key]
            )
            if missing or unexpected or mismatched:
                details.append(
                    f"{coordinate}: missing={missing}, unexpected={unexpected}, "
                    f"mismatched={mismatched}"
                )
        raise ReleaseValidationError(
            "Xcode build configurations violate the exact reviewed manifest: "
            + "; ".join(details)
        )


def _render_xc_build_configuration_fixture() -> str:
    parts: list[str] = []
    for ordinal, ((scope, configuration), settings) in enumerate(
        _expected_xc_build_configurations().items(), start=1
    ):
        identifier = f"{ordinal:024X}"
        parts.append(f"{identifier} /* {configuration} */ = {{\n")
        parts.append("\tisa = XCBuildConfiguration;\n\tbuildSettings = {\n")
        for key, value in settings.items():
            rendered_key = f'"{key}"' if not re.fullmatch(r"[A-Za-z0-9_]+", key) else key
            if isinstance(value, tuple):
                parts.append(f"\t\t{rendered_key} = (\n")
                parts.extend(f"\t\t\t{item},\n" for item in value)
                parts.append("\t\t);\n")
            else:
                parts.append(f"\t\t{rendered_key} = {value};\n")
        parts.append(f"\t}};\n\tname = {configuration};\n}};\n")
    return "".join(parts)


def _validate_empty_pbx_lists(text: str) -> None:
    for field in ("buildRules", "dependencies", "packageProductDependencies"):
        values = re.findall(
            rf'^\s*"?{field}"?\s*=\s*\((.*?)^\s*\);\s*$',
            text,
            re.MULTILINE | re.DOTALL,
        )
        required = field in {"buildRules", "dependencies"}
        if (required and not values) or any(value.strip() for value in values):
            raise ReleaseValidationError(
                f"Xcode project {field} must exist and be empty on every target"
            )


def _validate_pbx_paths(text: str) -> None:
    quoted_keys = re.findall(r'"([^"]*)"\s*=', text)
    if any("\\" in key for key in quoted_keys):
        raise ReleaseValidationError("Xcode project contains an escaped quoted key")
    if re.search(r'"?sourceTree"?\s*=\s*"?<absolute>"?\s*;', text):
        raise ReleaseValidationError("Xcode project contains an absolute file reference")
    for raw_path in re.findall(r'(?<![A-Za-z0-9_])"?path"?\s*=\s*([^;\r\n]*);', text):
        value = raw_path.strip()
        if len(value) >= 2 and value[0] == value[-1] == '"':
            value = value[1:-1]
        if (
            not value
            or value.startswith(("/", "~"))
            or "$(" in value
            or "${" in value
            or "`" in value
            or "\\" in value
            or ".." in pathlib.PurePosixPath(value).parts
        ):
            raise ReleaseValidationError("Xcode project contains an unsafe file-reference path")


def _validate_copy_files_phases(text: str) -> None:
    match = re.search(
        r"/\* Begin PBXCopyFilesBuildPhase section \*/(.*?)"
        r"/\* End PBXCopyFilesBuildPhase section \*/",
        text,
        re.DOTALL,
    )
    if match is None:
        return
    section = match.group(1)
    phases = re.findall(
        r"^[ \t]*[A-Fa-f0-9]{24}(?:\s+/\*.*?\*/)?\s*=\s*\{\s*$"
        r"(.*?)^[ \t]*\};\s*$",
        section,
        re.MULTILINE | re.DOTALL,
    )
    semantic_count = len(
        re.findall(
            r'^\s*"?isa"?\s*=\s*"?PBXCopyFilesBuildPhase"?;\s*$',
            section,
            re.MULTILINE,
        )
    )
    if not phases or len(phases) != semantic_count:
        raise ReleaseValidationError("Xcode Copy Files phase structure is malformed")
    exact_scalars = {
        "isa": "PBXCopyFilesBuildPhase",
        "buildActionMask": "2147483647",
        "dstPath": '""',
        "dstSubfolderSpec": "10",
        "name": '"Embed Frameworks"',
        "runOnlyForDeploymentPostprocessing": "0",
    }
    for phase in phases:
        for key, expected in exact_scalars.items():
            values = re.findall(
                rf'^\s*"?{key}"?\s*=\s*(.*?);\s*$',
                phase,
                re.MULTILINE,
            )
            if values != [expected]:
                raise ReleaseValidationError(
                    "Xcode Copy Files phases may only embed frameworks into the app wrapper"
                )


def _validate_pbx_build_files(text: str) -> None:
    matches = re.findall(
        r"/\* Begin PBXBuildFile section \*/(.*?)/\* End PBXBuildFile section \*/",
        text,
        re.DOTALL,
    )
    if len(matches) != 1:
        raise ReleaseValidationError("Xcode project must contain one PBXBuildFile section")
    if re.search(r'(?<![A-Za-z0-9_])"?settings"?\s*=', matches[0]):
        raise ReleaseValidationError("Xcode per-file build settings are not permitted")


def _validate_release_scheme(path: pathlib.Path) -> None:
    try:
        root = ET.fromstring(_regular_file(path, "shared Xcode scheme").read_bytes())
    except ET.ParseError as exc:
        raise ReleaseValidationError("shared Xcode scheme is malformed") from exc
    if root.tag != "Scheme":
        raise ReleaseValidationError("shared Xcode scheme root is unexpected")
    actions = [child.tag for child in root]
    if actions != EXPECTED_SCHEME_ACTIONS:
        raise ReleaseValidationError("shared Xcode scheme action inventory is unexpected")
    element_names = {element.tag for element in root.iter()}
    unexpected = element_names - ALLOWED_SCHEME_ELEMENTS
    if unexpected:
        raise ReleaseValidationError(
            "shared Xcode scheme contains executable/unreviewed elements: "
            + ", ".join(sorted(unexpected))
        )
    if list(root.iter("TestableReference")):
        raise ReleaseValidationError("shared Xcode scheme contains an unreviewed test target")
    for empty_element_name in ("AdditionalOptions", "CommandLineArguments"):
        for element in root.iter(empty_element_name):
            if element.attrib or list(element) or (element.text or "").strip():
                raise ReleaseValidationError(
                    f"shared Xcode scheme {empty_element_name} must be empty"
                )
    archive_action = root.find("ArchiveAction")
    if archive_action is None or list(archive_action):
        raise ReleaseValidationError("ArchiveAction must not contain nested actions")
    references = list(root.iter("BuildableReference"))
    expected_reference = {
        "BuildableIdentifier": "primary",
        "BuildableName": f"{EXPECTED_DISPLAY_NAME}.app",
        "BlueprintName": EXPECTED_DISPLAY_NAME,
        "ReferencedContainer": f"container:{EXPECTED_DISPLAY_NAME}.xcodeproj",
    }
    if len(references) != 4:
        raise ReleaseValidationError("shared Xcode scheme must contain four target references")
    for reference in references:
        for key, expected in expected_reference.items():
            if reference.attrib.get(key) != expected:
                raise ReleaseValidationError("shared Xcode scheme target binding is unexpected")


def validate_scaffold_control_surfaces(
    root: pathlib.Path,
    require_frozen_manifest: bool = False,
) -> None:
    """Reject generated Xcode controls that could execute release-tag commands."""

    root = _regular_directory(root, "unsigned Xcode scaffold")
    project_files = sorted(root.glob("*.xcodeproj/project.pbxproj"))
    project_file = _one(project_files, "Xcode project.pbxproj")
    xcode_project = project_file.parent
    if require_frozen_manifest:
        actual_control_files: dict[str, str] = {}
        for candidate in sorted(xcode_project.rglob("*")):
            if candidate.is_symlink():
                raise ReleaseValidationError("Xcode control tree contains a symlink")
            if candidate.is_file():
                relative = candidate.relative_to(xcode_project).as_posix()
                actual_control_files[relative] = _sha256(candidate)
        if actual_control_files != EXPECTED_XCODE_CONTROL_HASHES:
            raise ReleaseValidationError(
                "Xcode control files do not match the frozen Godot 4.7.2 manifest"
            )
    project_text = _regular_file(project_file, "Xcode project.pbxproj").read_text(
        encoding="utf-8"
    )
    begin_sections = re.findall(r"/\* Begin ([A-Za-z0-9_]+) section \*/", project_text)
    end_sections = re.findall(r"/\* End ([A-Za-z0-9_]+) section \*/", project_text)
    if begin_sections != end_sections or len(begin_sections) != len(set(begin_sections)):
        raise ReleaseValidationError("Xcode project section structure is malformed")
    section_names = set(begin_sections)
    unexpected_sections = section_names - ALLOWED_PBX_SECTIONS
    missing_sections = REQUIRED_PBX_SECTIONS - section_names
    if unexpected_sections or missing_sections:
        raise ReleaseValidationError(
            "Xcode project section allowlist failed "
            f"(unexpected={sorted(unexpected_sections)}, missing={sorted(missing_sections)})"
        )
    semantic_isas = {
        value.strip('"')
        for value in re.findall(
            r'(?<![A-Za-z0-9_])"?isa"?\s*=\s*("?[A-Za-z0-9_]+"?)\s*;',
            project_text,
        )
    }
    unexpected_isas = semantic_isas - ALLOWED_PBX_ISAS
    if unexpected_isas or not REQUIRED_PBX_SECTIONS <= semantic_isas:
        raise ReleaseValidationError(
            "Xcode project semantic ISA allowlist failed "
            f"(unexpected={sorted(unexpected_isas)})"
        )
    forbidden = [token for token in FORBIDDEN_PBX_TEXT if token in project_text]
    if forbidden:
        raise ReleaseValidationError(
            "Xcode project contains an executable/unreviewed control: "
            + ", ".join(forbidden)
        )
    if re.search(r"\.xcconfig(?:\s|\"|;|$)", project_text, re.IGNORECASE):
        raise ReleaseValidationError("Xcode project contains an unreviewed xcconfig")
    if FORBIDDEN_BUILD_SETTING_PATTERN.search(project_text):
        raise ReleaseValidationError("Xcode project overrides a protected build tool/setting")
    if FORBIDDEN_COMPILER_FLAG_PATTERN.search(project_text):
        raise ReleaseValidationError("Xcode project contains a compiler plugin/load flag")
    _validate_xc_build_configurations(project_text)
    _validate_pbx_build_files(project_text)
    _validate_pbx_paths(project_text)
    _validate_copy_files_phases(project_text)
    _validate_empty_pbx_lists(project_text)
    product_types = re.findall(
        r'(?<![A-Za-z0-9_])"?productType"?\s*=\s*"([^"]+)"\s*;', project_text
    )
    if product_types != ["com.apple.product-type.application"]:
        raise ReleaseValidationError("Xcode project must contain one application target")

    schemes = sorted(root.glob("*.xcodeproj/xcshareddata/xcschemes/*.xcscheme"))
    scheme = _one(schemes, "shared Xcode scheme")
    if scheme.name != f"{EXPECTED_DISPLAY_NAME}.xcscheme":
        raise ReleaseValidationError("shared Xcode scheme filename is unexpected")
    _validate_release_scheme(scheme)
    print(
        "iOS release scaffold control-surface validation: PASS "
        "(one application target, empty rules/dependencies, no scripts/packages/xcconfig/tool overrides)"
    )


def _profile_summary(
    profile: dict[str, Any], team_id: str, bundle_id: str, now: dt.datetime | None = None
) -> dict[str, Any]:
    _validate_coordinates(bundle_id, "1.0", "1", team_id)
    now_value = now or dt.datetime.now(dt.timezone.utc)
    team_identifiers = profile.get("TeamIdentifier")
    if team_identifiers != [team_id]:
        raise ReleaseValidationError("provisioning profile TeamIdentifier does not match")
    uuid = profile.get("UUID")
    name = profile.get("Name")
    if not isinstance(uuid, str) or UUID_PATTERN.fullmatch(uuid) is None:
        raise ReleaseValidationError("provisioning profile UUID is malformed")
    if (
        not isinstance(name, str)
        or not 1 <= len(name) <= 256
        or any(ord(character) < 32 or ord(character) == 127 for character in name)
    ):
        raise ReleaseValidationError("provisioning profile Name is missing or contains control characters")
    expiration = profile.get("ExpirationDate")
    if not isinstance(expiration, dt.datetime):
        raise ReleaseValidationError("provisioning profile has no expiration date")
    if expiration.tzinfo is None:
        expiration = expiration.replace(tzinfo=dt.timezone.utc)
    if expiration <= now_value:
        raise ReleaseValidationError("provisioning profile is expired")
    if profile.get("ProvisionsAllDevices") not in (None, False):
        raise ReleaseValidationError("enterprise provisioning profiles are not accepted")
    if profile.get("ProvisionedDevices") not in (None, []):
        raise ReleaseValidationError("development/ad-hoc provisioning profiles are not accepted")
    platforms = profile.get("Platform")
    allowed_platforms = {"iOS", "xrOS", "visionOS"}
    if (
        not isinstance(platforms, list)
        or not platforms
        or any(not isinstance(platform, str) for platform in platforms)
        or "iOS" not in platforms
        or not set(platforms) <= allowed_platforms
    ):
        raise ReleaseValidationError("provisioning profile does not authorize reviewed iOS platforms")
    entitlements = profile.get("Entitlements")
    if not isinstance(entitlements, dict):
        raise ReleaseValidationError("provisioning profile entitlements are missing")
    unknown_entitlements = set(entitlements) - ALLOWED_SIGNED_ENTITLEMENTS
    if unknown_entitlements:
        raise ReleaseValidationError(
            "provisioning profile enables unreviewed entitlements: "
            + ", ".join(sorted(unknown_entitlements))
        )
    application_id = f"{team_id}.{bundle_id}"
    if entitlements.get("application-identifier") != application_id:
        raise ReleaseValidationError(
            "provisioning profile application-identifier does not match Team/Bundle"
        )
    if entitlements.get("com.apple.developer.team-identifier") != team_id:
        raise ReleaseValidationError("provisioning profile entitlement Team ID does not match")
    if entitlements.get("get-task-allow", False) is not False:
        raise ReleaseValidationError("provisioning profile permits debugger attachment")
    groups = entitlements.get("keychain-access-groups", [])
    allowed_profile_groups = {application_id, f"{team_id}.*"}
    if groups not in (None, []):
        if not isinstance(groups, list) or any(
            not isinstance(group, str) or group not in allowed_profile_groups
            for group in groups
        ):
            raise ReleaseValidationError(
                "provisioning profile has unreviewed keychain access groups"
            )
    if entitlements.get("beta-reports-active") is not True:
        raise ReleaseValidationError(
            "provisioning profile is not an App Store distribution profile"
        )
    return {
        "distribution": "app-store",
        "expires_utc": expiration.astimezone(dt.timezone.utc).isoformat(),
    }


def _certificate_summary(
    certificate_path: pathlib.Path,
    profile: dict[str, Any],
    team_id: str,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    certificate_path = _regular_file(certificate_path, "distribution certificate")
    metadata = _run(
        [
            "openssl",
            "x509",
            "-in",
            str(certificate_path),
            "-noout",
            "-subject",
            "-issuer",
            "-startdate",
            "-enddate",
            "-purpose",
        ],
        "distribution-certificate inspection",
    )
    text = metadata.stdout.decode("utf-8", errors="replace")
    subject = next((line for line in text.splitlines() if line.startswith("subject=")), "")
    if re.search(r"(?:CN\s*=\s*|/CN=)Apple Distribution(?::|,|/|$)", subject) is None:
        raise ReleaseValidationError("certificate is not an Apple Distribution certificate")
    if re.search(rf"(?:OU\s*=\s*|/OU=){re.escape(team_id)}(?:,|/|$)", subject) is None:
        raise ReleaseValidationError("distribution-certificate OU does not match Team ID")
    issuer = next((line for line in text.splitlines() if line.startswith("issuer=")), "")
    if "Apple Worldwide Developer Relations Certification Authority" not in issuer:
        raise ReleaseValidationError("distribution certificate has an unexpected issuer")
    start_line = next((line for line in text.splitlines() if line.startswith("notBefore=")), "")
    end_line = next((line for line in text.splitlines() if line.startswith("notAfter=")), "")
    if not start_line or not end_line:
        raise ReleaseValidationError("distribution certificate validity window is missing")
    try:
        valid_from = email.utils.parsedate_to_datetime(start_line.split("=", 1)[1])
        expiration = email.utils.parsedate_to_datetime(end_line.split("=", 1)[1])
    except (TypeError, ValueError) as exc:
        raise ReleaseValidationError("distribution-certificate expiration is malformed") from exc
    if expiration.tzinfo is None:
        expiration = expiration.replace(tzinfo=dt.timezone.utc)
    if valid_from.tzinfo is None:
        valid_from = valid_from.replace(tzinfo=dt.timezone.utc)
    now_value = now or dt.datetime.now(dt.timezone.utc)
    if valid_from > now_value or expiration <= now_value:
        raise ReleaseValidationError("distribution certificate is outside its validity window")
    if re.search(r"^Code Signing\s*:\s*Yes$", text, re.MULTILINE) is None:
        raise ReleaseValidationError("distribution certificate is not valid for code signing")
    _run(
        ["security", "verify-cert", "-c", str(certificate_path), "-p", "codeSign", "-L"],
        "Apple code-signing trust-chain verification",
    )
    der = _run(
        ["openssl", "x509", "-in", str(certificate_path), "-outform", "DER"],
        "distribution-certificate DER export",
    ).stdout
    developer_certificates = profile.get("DeveloperCertificates")
    if not isinstance(developer_certificates, list) or not any(
        isinstance(value, bytes) and value == der for value in developer_certificates
    ):
        raise ReleaseValidationError(
            "imported distribution certificate is not authorized by the provisioning profile"
        )
    return {
        "expires_utc": expiration.astimezone(dt.timezone.utc).isoformat(),
        "sha256": hashlib.sha256(der).hexdigest(),
    }


def validate_profile_plist(
    profile_path: pathlib.Path,
    certificate_path: pathlib.Path,
    team_id: str,
    bundle_id: str,
    output: pathlib.Path | None = None,
) -> dict[str, Any]:
    profile = _plist(profile_path, "decoded provisioning profile")
    summary = _profile_summary(profile, team_id, bundle_id)
    certificate_summary = _certificate_summary(certificate_path, profile, team_id)
    if output is not None:
        _atomic_json(
            output,
            {
                "schema": "infinidive.ios.signing-preflight.v1",
                "status": "passed",
                "release": {
                    "bundle_id": bundle_id,
                    "team_id_validated": True,
                },
                "profile": {
                    "distribution": summary["distribution"],
                    "expires_utc": summary["expires_utc"],
                },
                "certificate": certificate_summary,
            },
        )
    print("iOS App Store profile/certificate validation: PASS")
    return summary


def _signed_entitlements_summary(
    entitlements: dict[str, Any], team_id: str, bundle_id: str
) -> dict[str, Any]:
    unknown = set(entitlements) - ALLOWED_SIGNED_ENTITLEMENTS
    if unknown:
        raise ReleaseValidationError(
            "signed app contains unreviewed entitlements: " + ", ".join(sorted(unknown))
        )
    application_id = f"{team_id}.{bundle_id}"
    if entitlements.get("application-identifier") != application_id:
        raise ReleaseValidationError("signed application-identifier does not match Team/Bundle")
    if entitlements.get("com.apple.developer.team-identifier") != team_id:
        raise ReleaseValidationError("signed app Team entitlement does not match")
    if entitlements.get("get-task-allow", False) is not False:
        raise ReleaseValidationError("signed release unexpectedly permits debugger attachment")
    groups = entitlements.get("keychain-access-groups", [])
    if groups not in (None, []):
        if not isinstance(groups, list) or any(group != application_id for group in groups):
            raise ReleaseValidationError("signed app has unreviewed keychain access groups")
    if entitlements.get("beta-reports-active") is not True:
        raise ReleaseValidationError(
            "signed app lacks the App Store beta-reports-active entitlement"
        )
    return {"reviewed_keys": sorted(entitlements), "get_task_allow": False}


def _plist_from_codesign(result: subprocess.CompletedProcess[bytes]) -> dict[str, Any]:
    for payload in (result.stdout, result.stderr):
        starts = [index for index in (payload.find(b"<?xml"), payload.find(b"bplist")) if index >= 0]
        if not starts:
            continue
        candidate = payload[min(starts) :]
        if candidate.startswith(b"<?xml"):
            end = candidate.find(b"</plist>")
            if end >= 0:
                candidate = candidate[: end + len(b"</plist>")]
        try:
            value = plistlib.loads(candidate)
        except (plistlib.InvalidFileException, ValueError):
            continue
        if isinstance(value, dict):
            return value
    raise ReleaseValidationError("codesign did not emit parseable signed entitlements")


def _collect_strings(value: Any) -> list[str]:
    result: list[str] = []
    if isinstance(value, str):
        result.append(value)
    elif isinstance(value, dict):
        for key, nested in value.items():
            result.extend(_collect_strings(key))
            result.extend(_collect_strings(nested))
    elif isinstance(value, list):
        for nested in value:
            result.extend(_collect_strings(nested))
    return result


def _asset_catalog_summary(path: pathlib.Path) -> dict[str, Any]:
    result = _run(
        ["xcrun", "--sdk", "iphoneos", "assetutil", "--info", str(path)],
        "asset-catalog inspection",
    )
    payload = result.stdout.strip()
    try:
        value = json.loads(payload)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ReleaseValidationError("assetutil did not emit valid JSON") from exc
    names = sorted(
        {
            item
            for item in _collect_strings(value)
            if "appicon" in item.lower() and len(item) <= 256
        }
    )
    if not names:
        raise ReleaseValidationError("compiled Assets.car has no AppIcon rendition")
    return {"app_icon_renditions": names, "sha256": _sha256(path)}


def _validate_app_info(
    info: dict[str, Any], bundle_id: str, marketing_version: str, build_number: str
) -> None:
    for boolean_key in (
        "ITSAppUsesNonExemptEncryption",
        "LSRequiresIPhoneOS",
        "UIRequiresFullScreen",
    ):
        if type(info.get(boolean_key)) is not bool:
            raise ReleaseValidationError(
                f"signed app Info.plist {boolean_key} must be a plist boolean"
            )
    device_family = info.get("UIDeviceFamily")
    if (
        not isinstance(device_family, list)
        or len(device_family) != 1
        or type(device_family[0]) is not int
    ):
        raise ReleaseValidationError("signed app UIDeviceFamily must contain integer 1")
    expected = {
        "CFBundleIdentifier": bundle_id,
        "CFBundleShortVersionString": marketing_version,
        "CFBundleVersion": build_number,
        "CFBundleDisplayName": EXPECTED_DISPLAY_NAME,
        "CFBundleDevelopmentRegion": "en",
        "CFBundleLocalizations": SUPPORTED_LOCALIZATIONS,
        "CFBundleName": EXPECTED_DISPLAY_NAME,
        "CFBundlePackageType": "APPL",
        "DTPlatformName": "iphoneos",
        "LSRequiresIPhoneOS": True,
        "MinimumOSVersion": EXPECTED_MIN_IOS,
        "UIDeviceFamily": [1],
        "UIRequiresFullScreen": True,
        "UISupportedInterfaceOrientations": PORTRAIT_ONLY,
        "ITSAppUsesNonExemptEncryption": False,
    }
    for key, expected_value in expected.items():
        if info.get(key) != expected_value:
            raise ReleaseValidationError(
                f"signed app Info.plist {key}={info.get(key)!r}, expected {expected_value!r}"
            )
    sdk_name = info.get("DTSDKName")
    if not isinstance(sdk_name, str) or re.fullmatch(r"iphoneos26(?:\.[0-9]+)+", sdk_name) is None:
        raise ReleaseValidationError("signed app was not compiled with the iOS 26 SDK")
    protected_usage = sorted(
        key
        for key in info
        if isinstance(key, str) and key.startswith("NS") and key.endswith("UsageDescription")
    )
    if protected_usage:
        raise ReleaseValidationError(
            "signed app contains unreviewed protected-resource descriptions: "
            + ", ".join(protected_usage)
        )
    if info.get("UIFileSharingEnabled", False) is not False:
        raise ReleaseValidationError("signed app unexpectedly enables file sharing")
    if info.get("LSSupportsOpeningDocumentsInPlace", False) is not False:
        raise ReleaseValidationError("signed app unexpectedly opens documents in place")
    icon_strings = _collect_strings(info.get("CFBundleIcons", {}))
    if not any(value == "AppIcon" or value.startswith("AppIcon") for value in icon_strings):
        raise ReleaseValidationError("compiled Info.plist does not reference the AppIcon catalog")


def _profile_from_mobileprovision(path: pathlib.Path) -> dict[str, Any]:
    result = _run(["security", "cms", "-D", "-i", str(path)], "profile decoding")
    try:
        value = plistlib.loads(result.stdout)
    except (plistlib.InvalidFileException, ValueError) as exc:
        raise ReleaseValidationError("embedded provisioning profile is malformed") from exc
    if not isinstance(value, dict):
        raise ReleaseValidationError("embedded provisioning profile root is not a dictionary")
    return value


def _signed_app_summary(
    app: pathlib.Path,
    team_id: str,
    bundle_id: str,
    marketing_version: str,
    build_number: str,
    expected_profile_uuid: str,
    expected_profile_sha256: str,
    expected_certificate_sha256: str,
) -> dict[str, Any]:
    _regular_directory(app, "signed application")
    _reject_tree_symlinks(app, "signed application")
    info_path = _regular_file(app / "Info.plist", "signed application Info.plist")
    info = _plist(info_path, "signed application Info.plist")
    _validate_app_info(info, bundle_id, marketing_version, build_number)
    executable_name = info.get("CFBundleExecutable")
    if not isinstance(executable_name, str) or pathlib.Path(executable_name).name != executable_name:
        raise ReleaseValidationError("signed app executable name is unsafe")
    executable = _regular_file(app / executable_name, "signed application executable")

    _run(["codesign", "--verify", "--deep", "--strict", str(app)], "code-signature verification")
    details = _run(["codesign", "-dv", "--verbose=4", str(app)], "code-signature metadata")
    detail_text = (details.stdout + details.stderr).decode("utf-8", errors="replace")
    identifiers = re.findall(r"^Identifier=(.+)$", detail_text, re.MULTILINE)
    teams = re.findall(r"^TeamIdentifier=(.+)$", detail_text, re.MULTILINE)
    if identifiers != [bundle_id] or teams != [team_id]:
        raise ReleaseValidationError("code-signature identifier or Team ID does not match")
    if UUID_PATTERN.fullmatch(expected_profile_uuid) is None:
        raise ReleaseValidationError("expected provisioning-profile UUID is malformed")
    for expected_hash in (expected_profile_sha256, expected_certificate_sha256):
        if SHA256_PATTERN.fullmatch(expected_hash) is None:
            raise ReleaseValidationError("expected signing-material SHA-256 is malformed")
    with tempfile.TemporaryDirectory(prefix="infinidive-codesign-cert-") as certificate_root:
        prefix = pathlib.Path(certificate_root) / "signer"
        _run(
            ["codesign", "-d", "--extract-certificates", str(prefix), str(app)],
            "code-signature certificate extraction",
        )
        leaf = _regular_file(pathlib.Path(f"{prefix}0"), "code-signature leaf certificate")
        if _sha256(leaf) != expected_certificate_sha256:
            raise ReleaseValidationError("signed app certificate does not match preflight")

    architectures = _run(["xcrun", "lipo", "-archs", str(executable)], "Mach-O architecture check")
    if architectures.stdout.decode("ascii", errors="replace").split() != ["arm64"]:
        raise ReleaseValidationError("signed application executable must be arm64-only")

    entitlement_result = _run(
        ["codesign", "-d", "--entitlements", ":-", str(app)],
        "signed-entitlement extraction",
    )
    entitlement_summary = _signed_entitlements_summary(
        _plist_from_codesign(entitlement_result), team_id, bundle_id
    )

    profile_path = _regular_file(
        app / "embedded.mobileprovision", "embedded provisioning profile"
    )
    embedded_profile = _profile_from_mobileprovision(profile_path)
    profile_summary = _profile_summary(embedded_profile, team_id, bundle_id)
    if embedded_profile.get("UUID") != expected_profile_uuid:
        raise ReleaseValidationError("embedded profile UUID does not match preflight")
    if _sha256(profile_path) != expected_profile_sha256:
        raise ReleaseValidationError("embedded profile bytes do not match preflight")
    profile_summary["sha256"] = _sha256(profile_path)
    profile_summary["preflight_match"] = True

    manifests = sorted(app.rglob("PrivacyInfo.xcprivacy"))
    privacy_path = _one(manifests, "signed-app PrivacyInfo.xcprivacy")
    if privacy_path != app / "PrivacyInfo.xcprivacy":
        raise ReleaseValidationError("privacy manifest must be at the application root")
    privacy_value = _plist(privacy_path, "signed application privacy manifest")
    try:
        privacy_validation.validate_value(privacy_value)
    except privacy_validation.PrivacyManifestError as exc:
        raise ReleaseValidationError(str(exc)) from exc

    assets = _regular_file(app / "Assets.car", "compiled asset catalog")
    asset_summary = _asset_catalog_summary(assets)
    pck = _regular_file(app / f"{EXPECTED_DISPLAY_NAME}.pck", "packaged Godot data")
    _regular_file(app / "_CodeSignature" / "CodeResources", "code-signature resources")

    if list(app.rglob("*.appex")):
        raise ReleaseValidationError("signed app contains an unreviewed app extension")
    for forbidden in ("PlugIns", "Watch"):
        path = app / forbidden
        if path.exists() and any(path.iterdir()):
            raise ReleaseValidationError(f"signed app contains unreviewed {forbidden} content")

    frameworks: list[dict[str, str]] = []
    frameworks_dir = app / "Frameworks"
    if frameworks_dir.exists():
        _regular_directory(frameworks_dir, "embedded Frameworks directory")
        for entry in sorted(frameworks_dir.iterdir()):
            if entry.is_symlink() or not entry.is_file() or SWIFT_DYLIB_PATTERN.fullmatch(entry.name) is None:
                raise ReleaseValidationError(
                    f"signed app contains an unreviewed embedded framework/library: {entry.name}"
                )
            _run(["codesign", "--verify", "--strict", str(entry)], "embedded Swift library signature")
            architectures = _run(
                ["xcrun", "lipo", "-archs", str(entry)],
                "embedded Swift library architecture check",
            )
            if architectures.stdout.decode("ascii", errors="replace").split() != ["arm64"]:
                raise ReleaseValidationError(
                    f"embedded Swift library must be arm64-only: {entry.name}"
                )
            frameworks.append({"name": entry.name, "sha256": _sha256(entry)})

    return {
        "assets": asset_summary,
        "bundle_id": bundle_id,
        "build_number": build_number,
        "entitlements": entitlement_summary,
        "executable_sha256": _sha256(executable),
        "frameworks": frameworks,
        "info_plist_sha256": _sha256(info_path),
        "marketing_version": marketing_version,
        "pck_sha256": _sha256(pck),
        "privacy_manifest_sha256": _sha256(privacy_path),
        "profile": profile_summary,
        "signature_validated": True,
        "signing_certificate_preflight_match": True,
    }


def _macho_uuids(path: pathlib.Path, label: str) -> list[str]:
    result = _run(["xcrun", "dwarfdump", "--uuid", str(path)], f"{label} UUID check")
    text = result.stdout.decode("utf-8", errors="replace")
    matches = re.findall(
        r"^UUID: ([0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}) \(arm64\) ",
        text,
        re.MULTILINE,
    )
    if len(matches) != 1:
        raise ReleaseValidationError(f"{label} must contain exactly one arm64 UUID")
    return matches


def _archive_summary(
    archive: pathlib.Path,
    team_id: str,
    bundle_id: str,
    marketing_version: str,
    build_number: str,
    expected_profile_uuid: str,
    expected_profile_sha256: str,
    expected_certificate_sha256: str,
) -> dict[str, Any]:
    _regular_directory(archive, "Xcode archive")
    _reject_tree_symlinks(archive, "Xcode archive")
    archive_info_path = _regular_file(archive / "Info.plist", "archive Info.plist")
    archive_info = _plist(archive_info_path, "archive Info.plist")
    if archive_info.get("ArchiveVersion") != 2:
        raise ReleaseValidationError("xcarchive ArchiveVersion must be 2")
    if archive_info.get("Name") != EXPECTED_DISPLAY_NAME:
        raise ReleaseValidationError("xcarchive Name does not match")
    if archive_info.get("SchemeName") != EXPECTED_DISPLAY_NAME:
        raise ReleaseValidationError("xcarchive SchemeName does not match")
    properties = archive_info.get("ApplicationProperties")
    if not isinstance(properties, dict):
        raise ReleaseValidationError("xcarchive ApplicationProperties are missing")
    expected_properties = {
        "CFBundleIdentifier": bundle_id,
        "CFBundleShortVersionString": marketing_version,
        "CFBundleVersion": build_number,
    }
    for key, expected in expected_properties.items():
        if properties.get(key) != expected:
            raise ReleaseValidationError(f"xcarchive {key} does not match release input")
    if properties.get("ApplicationPath") != f"Applications/{EXPECTED_DISPLAY_NAME}.app":
        raise ReleaseValidationError("xcarchive ApplicationPath is unexpected")
    if not isinstance(properties.get("SigningIdentity"), str) or not properties["SigningIdentity"]:
        raise ReleaseValidationError("xcarchive has no signing identity")
    if re.match(r"^Apple Distribution(?::|$)", properties["SigningIdentity"]) is None:
        raise ReleaseValidationError("xcarchive was not signed with Apple Distribution")
    if properties.get("Team") != team_id:
        raise ReleaseValidationError("xcarchive signing team does not match")

    applications = sorted((archive / "Products" / "Applications").glob("*.app"))
    app = _one(applications, "archived application")
    if app.name != f"{EXPECTED_DISPLAY_NAME}.app":
        raise ReleaseValidationError("archived application name is unexpected")
    app_summary = _signed_app_summary(
        app,
        team_id,
        bundle_id,
        marketing_version,
        build_number,
        expected_profile_uuid,
        expected_profile_sha256,
        expected_certificate_sha256,
    )
    dwarf = _regular_file(
        archive
        / "dSYMs"
        / f"{EXPECTED_DISPLAY_NAME}.app.dSYM"
        / "Contents"
        / "Resources"
        / "DWARF"
        / EXPECTED_DISPLAY_NAME,
        "archive dSYM DWARF binary",
    )
    executable_name = _plist(app / "Info.plist", "archived application Info.plist").get(
        "CFBundleExecutable"
    )
    if not isinstance(executable_name, str):
        raise ReleaseValidationError("archived application executable name is missing")
    executable = _regular_file(app / executable_name, "archived application executable")
    executable_uuids = _macho_uuids(executable, "archived application executable")
    dwarf_uuids = _macho_uuids(dwarf, "archive dSYM DWARF binary")
    if executable_uuids != dwarf_uuids:
        raise ReleaseValidationError("archive dSYM UUID does not match the application executable")
    return {
        "app": app_summary,
        "archive_info_sha256": _sha256(archive_info_path),
        "dsym_sha256": _sha256(dwarf),
        "dsym_uuid_match": True,
    }


def _safe_extract_ipa(ipa: pathlib.Path, destination: pathlib.Path) -> pathlib.Path:
    _regular_file(ipa, "exported IPA")
    try:
        archive = zipfile.ZipFile(ipa)
    except (OSError, zipfile.BadZipFile) as exc:
        raise ReleaseValidationError("exported IPA is not a valid ZIP archive") from exc
    with archive:
        members = archive.infolist()
        if not members or len(members) > MAX_IPA_ENTRIES:
            raise ReleaseValidationError("IPA entry count is empty or exceeds the safety limit")
        total = 0
        exact_names: set[str] = set()
        folded_names: set[str] = set()
        for member in members:
            pure = pathlib.PurePosixPath(member.filename)
            mode = (member.external_attr >> 16) & 0o170000
            canonical = pure.as_posix() + ("/" if member.is_dir() else "")
            folded = canonical.casefold()
            if (
                pure.is_absolute()
                or ".." in pure.parts
                or "\\" in member.filename
                or "\x00" in member.filename
                or mode not in (0, stat.S_IFREG, stat.S_IFDIR)
                or member.filename != canonical
                or canonical in exact_names
                or folded in folded_names
            ):
                raise ReleaseValidationError(
                    "IPA contains an unsafe, duplicate, noncanonical, or symlink path"
                )
            exact_names.add(canonical)
            folded_names.add(folded)
            total += member.file_size
            if total > MAX_IPA_UNCOMPRESSED_BYTES:
                raise ReleaseValidationError("IPA uncompressed size exceeds the safety limit")
        archive.extractall(destination)
    root_entries = sorted(destination.iterdir(), key=lambda item: item.name)
    if not root_entries or any(
        entry.is_symlink()
        or not entry.is_dir()
        or entry.name not in {"Payload", "SwiftSupport", "Symbols"}
        for entry in root_entries
    ):
        raise ReleaseValidationError("IPA root inventory contains an unreviewed entry")
    applications = sorted((destination / "Payload").glob("*.app"))
    app = _one(applications, "IPA Payload application")
    if app.name != f"{EXPECTED_DISPLAY_NAME}.app":
        raise ReleaseValidationError("IPA Payload application name is unexpected")
    payload = _regular_directory(destination / "Payload", "IPA Payload directory")
    if list(payload.iterdir()) != [app]:
        raise ReleaseValidationError("IPA Payload must contain only INFINIDIVE.app")
    return app


def _atomic_json(path: pathlib.Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary: pathlib.Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            prefix=f".{path.name}.",
            suffix=".tmp",
            dir=path.parent,
            encoding="utf-8",
            delete=False,
        ) as handle:
            temporary = pathlib.Path(handle.name)
            json.dump(value, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def _meaningful_error_value(value: Any) -> bool:
    if value in (None, False, 0, "", [], {}):
        return False
    return True


def validate_ci_runs(
    input_path: pathlib.Path,
    release_sha: str,
    repository: str,
) -> int:
    """Require a successful full CI run for the exact production release SHA."""

    if re.fullmatch(r"[0-9a-f]{40}", release_sha) is None:
        raise ReleaseValidationError("release CI SHA must be 40 lowercase hex characters")
    if re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository) is None:
        raise ReleaseValidationError("release CI repository coordinate is malformed")
    try:
        value = json.loads(_regular_file(input_path, "GitHub Actions runs JSON").read_text("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ReleaseValidationError("GitHub Actions runs response is not valid JSON") from exc
    if not isinstance(value, dict) or not isinstance(value.get("workflow_runs"), list):
        raise ReleaseValidationError("GitHub Actions runs response has an unexpected shape")
    total_count = value.get("total_count")
    if not isinstance(total_count, int) or total_count < 0 or total_count > 100:
        raise ReleaseValidationError("release CI query is malformed or requires pagination")

    accepted_ids: list[int] = []
    for run in value["workflow_runs"]:
        if not isinstance(run, dict):
            continue
        head_repository = run.get("head_repository")
        if not isinstance(head_repository, dict):
            continue
        run_id = run.get("id")
        if (
            isinstance(run_id, int)
            and run_id > 0
            and run.get("name") == "INFINIDIVE CI and Web Pages"
            and run.get("path")
            == ".github/workflows/infinidive-ci.yml@infinidive-production"
            and run.get("head_sha") == release_sha
            and run.get("head_branch") == "infinidive-production"
            and run.get("event") in {"push", "workflow_dispatch"}
            and run.get("status") == "completed"
            and run.get("conclusion") == "success"
            and head_repository.get("full_name") == repository
        ):
            accepted_ids.append(run_id)
    if not accepted_ids:
        raise ReleaseValidationError(
            "release SHA has no successful production run of INFINIDIVE CI and Web Pages"
        )
    selected = max(accepted_ids)
    print(f"Exact release SHA production CI validation: PASS (run_id={selected})")
    return selected


def validate_altool_result(
    input_path: pathlib.Path,
    kind: str,
    output: pathlib.Path,
    apple_app_id: str,
    bundle_id: str,
    marketing_version: str,
    build_number: str,
) -> dict[str, Any]:
    if kind not in {"validate", "upload"}:
        raise ReleaseValidationError("altool result kind is invalid")
    _validate_coordinates(bundle_id, marketing_version, build_number)
    if APPLE_APP_ID_PATTERN.fullmatch(apple_app_id) is None:
        raise ReleaseValidationError("App Store Connect Apple ID must be 6-15 digits")
    try:
        value = json.loads(_regular_file(input_path, "altool JSON result").read_text("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ReleaseValidationError("altool did not emit valid JSON") from exc
    if not isinstance(value, dict):
        raise ReleaseValidationError("altool JSON result root must be an object")

    strings: list[tuple[tuple[str, ...], str]] = []
    identifiers: list[str] = []
    errors: list[str] = []
    http_failures: list[int] = []
    identifier_keys = {
        "deliveryid",
        "deliveryuuid",
        "id",
        "requestid",
        "requestuuid",
        "uploadid",
        "uploaduuid",
    }

    def visit(node: Any, path: tuple[str, ...] = ()) -> None:
        if isinstance(node, dict):
            for raw_key, nested in node.items():
                key = str(raw_key)
                normalized = re.sub(r"[^a-z0-9]", "", key.lower())
                nested_path = (*path, key)
                if "error" in normalized and _meaningful_error_value(nested):
                    errors.append(".".join(nested_path))
                if normalized in {"httpstatus", "httpstatuscode", "statuscode"}:
                    try:
                        status_code = int(nested)
                    except (TypeError, ValueError):
                        errors.append(".".join(nested_path))
                    else:
                        if status_code >= 400:
                            http_failures.append(status_code)
                if normalized in identifier_keys and isinstance(nested, (str, int)):
                    candidate = str(nested)
                    if re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{7,127}", candidate):
                        identifiers.append(candidate)
                visit(nested, nested_path)
        elif isinstance(node, list):
            for index, nested in enumerate(node):
                visit(nested, (*path, str(index)))
        elif isinstance(node, str):
            strings.append((path, node))

    visit(value)
    if errors:
        raise ReleaseValidationError(
            "altool JSON contains errors at: " + ", ".join(sorted(set(errors)))
        )
    if http_failures:
        raise ReleaseValidationError("altool JSON reports an HTTP failure")
    normalized_strings = [
        (path, re.sub(r"\s+", " ", item.strip().lower())) for path, item in strings
    ]
    negative_pattern = re.compile(
        r"\b(?:error|failed|failure|rejected|invalid|incomplete|unable|cannot)\b"
        r"|\bnot\s+uploaded\b"
    )
    for _path, item in normalized_strings:
        negative_candidate = re.sub(r"\bno errors?\b", "", item)
        if negative_pattern.search(negative_candidate):
            raise ReleaseValidationError("altool JSON contains a negative result string")

    positive = False
    if kind == "validate":
        positive = any(
            path
            and re.sub(r"[^a-z0-9]", "", path[-1].lower())
            in {"message", "status", "successmessage"}
            and (
                item in {"valid", "validated", "validation successful"}
                or re.fullmatch(r"no errors?\b.*\bvalidat(?:e|ed|ing|ion)\b.*", item)
                is not None
            )
            for path, item in normalized_strings
        )
    else:
        positive = any(
            path
            and (
                (
                    re.sub(r"[^a-z0-9]", "", path[-1].lower()) == "status"
                    and item in {"complete", "completed", "uploaded"}
                )
                or (
                    re.sub(r"[^a-z0-9]", "", path[-1].lower())
                    in {"message", "successmessage"}
                    and re.fullmatch(
                        r"(?:no errors?\b.*\bupload(?:ed|ing)?\b.*|"
                        r"upload(?:ed)?\b.*\b(?:successfully|complete|completed)\b.*)",
                        item,
                    )
                    is not None
                )
            )
            for path, item in normalized_strings
        )
    if not positive:
        raise ReleaseValidationError("altool JSON has no explicit success result")

    result: dict[str, Any] = {
        "schema": "infinidive.ios.app-store-connect-result.v1",
        "apple_app_id": apple_app_id,
        "build_number": build_number,
        "bundle_identifier": bundle_id,
        "marketing_version": marketing_version,
        "automatic_public_release": False,
        "automatic_submit_for_review": False,
    }
    if kind == "validate":
        result["status"] = "apple-validation-passed"
    else:
        if not identifiers:
            request_matches = []
            for _path, string in strings:
                request_matches.extend(
                    re.findall(
                        r"Request(?:UUID|ID)\s*[=:]\s*"
                        r"([A-Za-z0-9][A-Za-z0-9._-]{7,127})",
                        string,
                        re.IGNORECASE,
                    )
                )
            identifiers.extend(request_matches)
        unique_identifiers = sorted(set(identifiers))
        if len(unique_identifiers) != 1:
            raise ReleaseValidationError(
                "altool upload JSON must contain exactly one delivery/request identifier"
            )
        result.update(
            {
                "status": "uploaded-awaiting-app-store-connect-processing",
                "delivery_or_request_id": unique_identifiers[0],
            }
        )
    _atomic_json(output, result)
    print(f"App Store Connect {kind} result validation: PASS")
    return result


def _validate_archive_ipa_parity(
    archive_app: dict[str, Any],
    ipa_app: dict[str, Any],
) -> None:
    for key in (
        "executable_sha256",
        "info_plist_sha256",
        "pck_sha256",
        "privacy_manifest_sha256",
    ):
        if archive_app[key] != ipa_app[key]:
            raise ReleaseValidationError(f"archive and IPA {key} differ")
    if archive_app["assets"]["sha256"] != ipa_app["assets"]["sha256"]:
        raise ReleaseValidationError("archive and IPA compiled asset catalogs differ")
    if archive_app["frameworks"] != ipa_app["frameworks"]:
        raise ReleaseValidationError("archive and IPA embedded framework names/hashes differ")
    if archive_app["entitlements"] != ipa_app["entitlements"]:
        raise ReleaseValidationError("archive and IPA signed entitlements differ")
    if archive_app["profile"] != ipa_app["profile"]:
        raise ReleaseValidationError("archive and IPA provisioning profiles differ")


def validate_release(
    archive: pathlib.Path,
    ipa: pathlib.Path | None,
    output: pathlib.Path,
    team_id: str,
    bundle_id: str,
    marketing_version: str,
    build_number: str,
    source_sha: str,
    run_id: int,
    run_attempt: int,
    source_pck_sha256: str,
    profile_uuid: str,
    profile_sha256: str,
    certificate_sha256: str,
) -> dict[str, Any]:
    _validate_coordinates(bundle_id, marketing_version, build_number, team_id)
    if re.fullmatch(r"[0-9a-f]{40}", source_sha) is None:
        raise ReleaseValidationError("source SHA must be a full lowercase Git commit ID")
    if run_id < 1 or run_attempt < 1:
        raise ReleaseValidationError("run ID and attempt must be positive integers")
    archive_summary = _archive_summary(
        archive,
        team_id,
        bundle_id,
        marketing_version,
        build_number,
        profile_uuid,
        profile_sha256,
        certificate_sha256,
    )
    _validate_source_pck_hash(
        source_pck_sha256,
        archive_summary["app"]["pck_sha256"],
    )
    evidence: dict[str, Any] = {
        "schema": "infinidive.ios.signed-release.v1",
        "status": "archive-passed" if ipa is None else "passed",
        "source": {
            "commit": source_sha,
            "pck_sha256": source_pck_sha256,
            "run_id": run_id,
            "run_attempt": run_attempt,
        },
        "release": {
            "bundle_id": bundle_id,
            "marketing_version": marketing_version,
            "build_number": build_number,
            "minimum_ios": EXPECTED_MIN_IOS,
            "device_family": "iPhone",
            "team_id_validated": True,
        },
        "archive": archive_summary,
        "limitations": [
            "Validation is source/archive/package evidence, not App Store review approval.",
            "A successful upload still requires TestFlight processing and physical-device QA.",
            "The final App Privacy, age-rating, export-compliance, rights, and territory answers remain owner-controlled App Store Connect declarations.",
        ],
    }
    if ipa is None:
        _atomic_json(output, evidence)
        print("Signed iOS xcarchive validation: PASS")
        return evidence

    with tempfile.TemporaryDirectory(prefix="infinidive-ipa-validation-") as root:
        ipa_app = _safe_extract_ipa(ipa, pathlib.Path(root))
        ipa_summary = _signed_app_summary(
            ipa_app,
            team_id,
            bundle_id,
            marketing_version,
            build_number,
            profile_uuid,
            profile_sha256,
            certificate_sha256,
        )

    _validate_archive_ipa_parity(archive_summary["app"], ipa_summary)

    evidence["ipa"] = {
        "app": ipa_summary,
        "bytes": _regular_file(ipa, "exported IPA").stat().st_size,
        "sha256": _sha256(ipa),
    }
    _atomic_json(output, evidence)
    print("Signed iOS xcarchive and IPA validation: PASS")
    return evidence


def _expect_failure(function: Any, *args: Any) -> None:
    try:
        function(*args)
    except ReleaseValidationError:
        return
    raise AssertionError("negative release-validation fixture was accepted")


def run_self_test() -> None:
    team = "A1B2C3D4E5"
    bundle = "com.matan.infinidive"
    now = dt.datetime(2026, 1, 1, tzinfo=dt.timezone.utc)
    profile = {
        "UUID": "12345678-1234-1234-1234-1234567890AB",
        "Name": "INFINIDIVE App Store",
        "TeamIdentifier": [team],
        "Platform": ["iOS"],
        "ExpirationDate": now + dt.timedelta(days=30),
        "Entitlements": {
            "application-identifier": f"{team}.{bundle}",
            "com.apple.developer.team-identifier": team,
            "get-task-allow": False,
            "beta-reports-active": True,
        },
    }
    profile_summary = _profile_summary(profile, team, bundle, now)
    if set(profile_summary) != {"distribution", "expires_utc"}:
        raise AssertionError("profile summary exposed an unreviewed field")
    wildcard_keychain = dict(profile)
    wildcard_keychain["Entitlements"] = dict(profile["Entitlements"])
    wildcard_keychain["Entitlements"]["keychain-access-groups"] = [f"{team}.*"]
    _profile_summary(wildcard_keychain, team, bundle, now)
    development = dict(profile)
    development["ProvisionedDevices"] = ["device"]
    _expect_failure(_profile_summary, development, team, bundle, now)
    expired = dict(profile)
    expired["ExpirationDate"] = now - dt.timedelta(seconds=1)
    _expect_failure(_profile_summary, expired, team, bundle, now)
    capability = dict(profile)
    capability["Entitlements"] = dict(profile["Entitlements"])
    capability["Entitlements"]["aps-environment"] = "production"
    _expect_failure(_profile_summary, capability, team, bundle, now)
    non_store = dict(profile)
    non_store["Entitlements"] = dict(profile["Entitlements"])
    non_store["Entitlements"].pop("beta-reports-active")
    _expect_failure(_profile_summary, non_store, team, bundle, now)
    wrong_platform = dict(profile)
    wrong_platform["Platform"] = ["macOS"]
    _expect_failure(_profile_summary, wrong_platform, team, bundle, now)

    entitlements = {
        "application-identifier": f"{team}.{bundle}",
        "beta-reports-active": True,
        "com.apple.developer.team-identifier": team,
        "get-task-allow": False,
    }
    _signed_entitlements_summary(entitlements, team, bundle)
    unreviewed = dict(entitlements)
    unreviewed["aps-environment"] = "production"
    _expect_failure(_signed_entitlements_summary, unreviewed, team, bundle)
    signed_non_store = dict(entitlements)
    signed_non_store.pop("beta-reports-active")
    _expect_failure(_signed_entitlements_summary, signed_non_store, team, bundle)

    source_pck_hash = "a" * 64
    _validate_source_pck_hash(source_pck_hash, source_pck_hash)
    _expect_failure(_validate_source_pck_hash, source_pck_hash, "b" * 64)
    _expect_failure(_validate_source_pck_hash, "A" * 64, source_pck_hash)

    parity_app = {
        "assets": {"sha256": "a" * 64},
        "entitlements": {"get_task_allow": False},
        "executable_sha256": "b" * 64,
        "frameworks": [{"name": "libswiftCore.dylib", "sha256": "c" * 64}],
        "info_plist_sha256": "d" * 64,
        "pck_sha256": "e" * 64,
        "privacy_manifest_sha256": "f" * 64,
        "profile": {"sha256": "1" * 64},
    }
    _validate_archive_ipa_parity(parity_app, dict(parity_app))
    substituted_executable = dict(parity_app)
    substituted_executable["executable_sha256"] = "2" * 64
    _expect_failure(_validate_archive_ipa_parity, parity_app, substituted_executable)
    substituted_framework = dict(parity_app)
    substituted_framework["frameworks"] = [
        {"name": "libswiftCore.dylib", "sha256": "3" * 64}
    ]
    _expect_failure(_validate_archive_ipa_parity, parity_app, substituted_framework)

    info = {
        "CFBundleIdentifier": bundle,
        "CFBundleShortVersionString": "0.1.0",
        "CFBundleVersion": "1",
        "CFBundleDisplayName": EXPECTED_DISPLAY_NAME,
        "CFBundleDevelopmentRegion": "en",
        "CFBundleLocalizations": SUPPORTED_LOCALIZATIONS,
        "CFBundleName": EXPECTED_DISPLAY_NAME,
        "CFBundlePackageType": "APPL",
        "DTPlatformName": "iphoneos",
        "DTSDKName": "iphoneos26.0",
        "LSRequiresIPhoneOS": True,
        "MinimumOSVersion": EXPECTED_MIN_IOS,
        "UIDeviceFamily": [1],
        "UIRequiresFullScreen": True,
        "UISupportedInterfaceOrientations": PORTRAIT_ONLY,
        "ITSAppUsesNonExemptEncryption": False,
        "CFBundleIcons": {
            "CFBundlePrimaryIcon": {"CFBundleIconName": "AppIcon"}
        },
    }
    _validate_app_info(info, bundle, "0.1.0", "1")
    wrong_development_region = dict(info)
    wrong_development_region["CFBundleDevelopmentRegion"] = "he"
    _expect_failure(_validate_app_info, wrong_development_region, bundle, "0.1.0", "1")
    camera = dict(info)
    camera["NSCameraUsageDescription"] = "unused"
    _expect_failure(_validate_app_info, camera, bundle, "0.1.0", "1")
    integer_boolean = dict(info)
    integer_boolean["ITSAppUsesNonExemptEncryption"] = 0
    _expect_failure(_validate_app_info, integer_boolean, bundle, "0.1.0", "1")

    privacy_validation.validate_value(
        {
            "NSPrivacyTracking": False,
            "NSPrivacyAccessedAPITypes": [
                {
                    "NSPrivacyAccessedAPIType": category,
                    "NSPrivacyAccessedAPITypeReasons": sorted(reasons),
                }
                for category, reasons in privacy_validation.EXPECTED_REASONS.items()
            ],
        }
    )

    with tempfile.TemporaryDirectory(prefix="infinidive-release-self-test-") as root_text:
        root = pathlib.Path(root_text)
        preset = root / "export_presets.cfg"
        project = root / "project.godot"
        fixture_options = dict(IOS_PRESET_STATIC_OPTIONS)
        fixture_options.update(
            {
                "application/bundle_identifier": f'"{bundle}"',
                "application/short_version": '"0.1.0"',
                "application/version": '"1"',
            }
        )
        valid_preset = (
            "[preset.0]\n\n"
            + "\n".join(
                f"{key}={value}" for key, value in sorted(IOS_PRESET_GENERAL.items())
            )
            + "\n\n[preset.0.options]\n\n"
            + "\n".join(
                f"{key}={value}" for key, value in sorted(fixture_options.items())
            )
            + "\n"
        )
        preset.write_text(valid_preset, encoding="utf-8")
        project.write_text('[application]\nconfig/version="0.1.0"\n', encoding="utf-8")
        validate_source(preset, project, bundle, "0.1.0", "1")
        preset.write_text(
            valid_preset.replace(
                'application/app_store_team_id=""',
                'application/app_store_team_id="A1B2C3D4E5"',
            ),
            encoding="utf-8",
        )
        _expect_failure(validate_source, preset, project, bundle, "0.1.0", "1")
        preset.write_text(
            valid_preset.replace(
                'custom_template/release=""',
                'custom_template/release="res://unreviewed.zip"',
            ),
            encoding="utf-8",
        )
        _expect_failure(validate_source, preset, project, bundle, "0.1.0", "1")

        scaffold = root / "scaffold"
        xcode_project = scaffold / f"{EXPECTED_DISPLAY_NAME}.xcodeproj"
        scheme_dir = xcode_project / "xcshareddata" / "xcschemes"
        scheme_dir.mkdir(parents=True)
        required_sections = sorted(REQUIRED_PBX_SECTIONS | {"PBXCopyFilesBuildPhase"})
        pbx_parts = []
        for section in required_sections:
            pbx_parts.append(f"/* Begin {section} section */\n")
            if section == "PBXNativeTarget":
                pbx_parts.append(
                    "ABCDEF0123456789ABCDEF01 /* INFINIDIVE */ = {\n"
                    "\tisa = PBXNativeTarget;\n"
                    "\tbuildPhases = (\n\t);\n"
                    "\tbuildRules = (\n\t);\n"
                    "\tdependencies = (\n\t);\n"
                    "\tpackageProductDependencies = (\n\t);\n"
                    "\tproductType = \"com.apple.product-type.application\";\n"
                    "};\n"
                )
            elif section == "PBXCopyFilesBuildPhase":
                pbx_parts.append(
                    "ABCDEF0123456789ABCDEF03 /* Embed Frameworks */ = {\n"
                    "\tisa = PBXCopyFilesBuildPhase;\n"
                    "\tbuildActionMask = 2147483647;\n"
                    "\tdstPath = \"\";\n"
                    "\tdstSubfolderSpec = 10;\n"
                    "\tfiles = (\n\t);\n"
                    "\tname = \"Embed Frameworks\";\n"
                    "\trunOnlyForDeploymentPostprocessing = 0;\n"
                    "};\n"
                )
            elif section == "XCBuildConfiguration":
                pbx_parts.append(_render_xc_build_configuration_fixture())
            else:
                pbx_parts.append(
                    "ABCDEF0123456789ABCDEF02 = {\n"
                    f"\tisa = {section};\n"
                    "};\n"
                )
            pbx_parts.append(f"/* End {section} section */\n")
        safe_pbx = "".join(pbx_parts)
        project_file = xcode_project / "project.pbxproj"
        project_file.write_text(safe_pbx, encoding="utf-8")

        reference = (
            '<BuildableReference BuildableIdentifier="primary" '
            'BlueprintIdentifier="ABCDEF0123456789ABCDEF01" '
            'BuildableName="INFINIDIVE.app" BlueprintName="INFINIDIVE" '
            'ReferencedContainer="container:INFINIDIVE.xcodeproj"/>'
        )
        safe_scheme = (
            '<Scheme version="1.7">'
            '<BuildAction><BuildActionEntries><BuildActionEntry>'
            f"{reference}"
            '</BuildActionEntry></BuildActionEntries></BuildAction>'
            f'<TestAction><Testables/><MacroExpansion>{reference}</MacroExpansion></TestAction>'
            f'<LaunchAction><BuildableProductRunnable>{reference}</BuildableProductRunnable></LaunchAction>'
            f'<ProfileAction><BuildableProductRunnable>{reference}</BuildableProductRunnable></ProfileAction>'
            '<AnalyzeAction/><ArchiveAction/>'
            '</Scheme>'
        )
        scheme = scheme_dir / f"{EXPECTED_DISPLAY_NAME}.xcscheme"
        scheme.write_text(safe_scheme, encoding="utf-8")
        validate_scaffold_control_surfaces(scaffold)
        scheme.write_text(
            safe_scheme.replace("<ArchiveAction/>", "<ArchiveAction><PreActions/></ArchiveAction>"),
            encoding="utf-8",
        )
        _expect_failure(validate_scaffold_control_surfaces, scaffold)
        scheme.write_text(safe_scheme, encoding="utf-8")
        project_file.write_text(
            safe_pbx + "/* Begin PBXBuildRule section */\n/* End PBXBuildRule section */\n",
            encoding="utf-8",
        )
        _expect_failure(validate_scaffold_control_surfaces, scaffold)
        project_file.write_text(
            safe_pbx.replace(
                "isa = PBXFileReference;",
                '"isa" = "PBXShellScriptBuildPhase";',
                1,
            ),
            encoding="utf-8",
        )
        _expect_failure(validate_scaffold_control_surfaces, scaffold)
        project_file.write_text(
            safe_pbx.replace('dstPath = "";', 'dstPath = "$(SRCROOT)/../../control";', 1),
            encoding="utf-8",
        )
        _expect_failure(validate_scaffold_control_surfaces, scaffold)
        project_file.write_text(
            safe_pbx.replace(
                "isa = XCBuildConfiguration;",
                'isa = XCBuildConfiguration;\n\t"CC" = release-controlled-tool;',
                1,
            ),
            encoding="utf-8",
        )
        _expect_failure(validate_scaffold_control_surfaces, scaffold)
        project_file.write_text(
            safe_pbx.replace(
                "isa = XCBuildConfiguration;",
                'isa = XCBuildConfiguration;\n\t"CC[sdk=iphoneos*]" = release-tool;',
                1,
            ),
            encoding="utf-8",
        )
        _expect_failure(validate_scaffold_control_surfaces, scaffold)
        project_file.write_text(
            safe_pbx.replace(
                "isa = PBXBuildFile;",
                'isa = PBXBuildFile; settings = { COMPILER_FLAGS = "-fpass-plugin=evil"; };',
                1,
            ),
            encoding="utf-8",
        )
        _expect_failure(validate_scaffold_control_surfaces, scaffold)
        project_file.write_text(safe_pbx, encoding="utf-8")

        ci_runs = root / "ci-runs.json"
        release_ci_sha = "1" * 40
        ci_run = {
            "id": 123456789,
            "name": "INFINIDIVE CI and Web Pages",
            "path": ".github/workflows/infinidive-ci.yml@infinidive-production",
            "head_sha": release_ci_sha,
            "head_branch": "infinidive-production",
            "event": "push",
            "status": "completed",
            "conclusion": "success",
            "head_repository": {"full_name": "owner/infinidive"},
        }
        ci_runs.write_text(
            json.dumps({"total_count": 1, "workflow_runs": [ci_run]}),
            encoding="utf-8",
        )
        validate_ci_runs(ci_runs, release_ci_sha, "owner/infinidive")
        wrong_branch_run = dict(ci_run)
        wrong_branch_run["head_branch"] = "main"
        ci_runs.write_text(
            json.dumps({"total_count": 1, "workflow_runs": [wrong_branch_run]}),
            encoding="utf-8",
        )
        _expect_failure(validate_ci_runs, ci_runs, release_ci_sha, "owner/infinidive")
        wrong_path_run = dict(ci_run)
        wrong_path_run["path"] = ".github/workflows/impostor.yml"
        ci_runs.write_text(
            json.dumps({"total_count": 1, "workflow_runs": [wrong_path_run]}),
            encoding="utf-8",
        )
        _expect_failure(validate_ci_runs, ci_runs, release_ci_sha, "owner/infinidive")

        altool_validate = root / "altool-validate.json"
        altool_validate.write_text(
            json.dumps({"success-message": "No errors validating archive"}),
            encoding="utf-8",
        )
        validate_altool_result(
            altool_validate,
            "validate",
            root / "validation-result.json",
            "1234567890",
            bundle,
            "0.1.0",
            "1",
        )
        altool_upload = root / "altool-upload.json"
        altool_upload.write_text(
            json.dumps(
                {
                    "data": {
                        "id": "12345678-1234-1234-1234-1234567890AB",
                        "attributes": {"status": "COMPLETE"},
                    },
                    "product-errors": [],
                }
            ),
            encoding="utf-8",
        )
        validate_altool_result(
            altool_upload,
            "upload",
            root / "upload-result.json",
            "1234567890",
            bundle,
            "0.1.0",
            "1",
        )
        altool_error = root / "altool-error.json"
        altool_error.write_text(
            json.dumps({"product-errors": [{"message": "rejected"}]}),
            encoding="utf-8",
        )
        _expect_failure(
            validate_altool_result,
            altool_error,
            "upload",
            root / "must-not-exist.json",
            "1234567890",
            bundle,
            "0.1.0",
            "1",
        )
        altool_no_id = root / "altool-no-id.json"
        altool_no_id.write_text(
            json.dumps({"success-message": "No errors uploading archive"}),
            encoding="utf-8",
        )
        _expect_failure(
            validate_altool_result,
            altool_no_id,
            "upload",
            root / "must-not-exist-either.json",
            "1234567890",
            bundle,
            "0.1.0",
            "1",
        )
        altool_unrelated = root / "altool-unrelated.json"
        altool_unrelated.write_text(
            json.dumps(
                {
                    "unrelated": "success",
                    "id": "12345678-1234-1234-1234-1234567890AB",
                }
            ),
            encoding="utf-8",
        )
        _expect_failure(
            validate_altool_result,
            altool_unrelated,
            "upload",
            root / "must-not-exist-unrelated.json",
            "1234567890",
            bundle,
            "0.1.0",
            "1",
        )
        for index, message in enumerate(("upload incomplete", "not uploaded"), start=1):
            altool_negative = root / f"altool-negative-{index}.json"
            altool_negative.write_text(
                json.dumps(
                    {
                        "message": message,
                        "requestID": "12345678-1234-1234-1234-1234567890AB",
                    }
                ),
                encoding="utf-8",
            )
            _expect_failure(
                validate_altool_result,
                altool_negative,
                "upload",
                root / f"must-not-exist-negative-{index}.json",
                "1234567890",
                bundle,
                "0.1.0",
                "1",
            )

        unsafe_ipa = root / "unsafe.ipa"
        with zipfile.ZipFile(unsafe_ipa, "w") as handle:
            handle.writestr("../escape", b"bad")
        extract_root = root / "extract"
        extract_root.mkdir()
        _expect_failure(_safe_extract_ipa, unsafe_ipa, extract_root)

        symlink_tree = root / "symlink-tree"
        real_parent = symlink_tree / "real-parent"
        real_parent.mkdir(parents=True)
        (real_parent / "payload").write_text("fixture", encoding="utf-8")
        (symlink_tree / "linked-parent").symlink_to(real_parent, target_is_directory=True)
        _expect_failure(_reject_tree_symlinks, symlink_tree, "symlink fixture")

    print(
        "Signed iOS release validator self-test: PASS "
        "(source/PCK binding, profile/certificate contract, strict plist types, privacy, "
        "entitlements, Xcode controls, exact-SHA CI, altool semantics, archive/IPA "
        "executable/framework parity, ZIP traversal/duplicate/symlink negatives)"
    )


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--self-test", action="store_true")
    mode.add_argument("--source-preset", type=pathlib.Path)
    mode.add_argument("--scaffold", type=pathlib.Path)
    mode.add_argument("--ci-runs-json", type=pathlib.Path)
    mode.add_argument("--altool-json", type=pathlib.Path)
    mode.add_argument("--profile-plist", type=pathlib.Path)
    mode.add_argument("--archive", type=pathlib.Path)
    parser.add_argument("--project", type=pathlib.Path)
    parser.add_argument("--certificate-pem", type=pathlib.Path)
    parser.add_argument("--ipa", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--team-id")
    parser.add_argument("--bundle-id")
    parser.add_argument("--marketing-version")
    parser.add_argument("--build-number")
    parser.add_argument("--apple-app-id")
    parser.add_argument("--source-sha")
    parser.add_argument("--source-pck-sha256")
    parser.add_argument("--profile-uuid")
    parser.add_argument("--profile-sha256")
    parser.add_argument("--certificate-sha256")
    parser.add_argument("--repository")
    parser.add_argument("--altool-kind", choices=("validate", "upload"))
    parser.add_argument("--run-id", type=int)
    parser.add_argument("--run-attempt", type=int)
    args = parser.parse_args()
    if args.self_test:
        extras = [
            args.project,
            args.certificate_pem,
            args.ipa,
            args.output,
            args.team_id,
            args.bundle_id,
            args.marketing_version,
            args.build_number,
            args.apple_app_id,
            args.source_sha,
            args.source_pck_sha256,
            args.profile_uuid,
            args.profile_sha256,
            args.certificate_sha256,
            args.repository,
            args.altool_kind,
            args.run_id,
            args.run_attempt,
        ]
        if any(value is not None for value in extras):
            parser.error("--self-test accepts no release inputs")
    elif args.source_preset is not None:
        if None in (args.project, args.bundle_id, args.marketing_version, args.build_number):
            parser.error("source mode requires --project, --bundle-id, --marketing-version, --build-number")
        disallowed = (
            args.certificate_pem,
            args.ipa,
            args.output,
            args.team_id,
            args.source_sha,
            args.source_pck_sha256,
            args.apple_app_id,
            args.repository,
            args.altool_kind,
            args.run_id,
            args.run_attempt,
        )
        if any(value is not None for value in disallowed):
            parser.error("source mode received inputs for a different validation mode")
    elif args.scaffold is not None:
        disallowed = (
            args.project,
            args.certificate_pem,
            args.ipa,
            args.output,
            args.team_id,
            args.bundle_id,
            args.marketing_version,
            args.build_number,
            args.apple_app_id,
            args.source_sha,
            args.source_pck_sha256,
            args.repository,
            args.altool_kind,
            args.run_id,
            args.run_attempt,
        )
        if any(value is not None for value in disallowed):
            parser.error("scaffold mode accepts only --scaffold")
    elif args.ci_runs_json is not None:
        if args.source_sha is None or args.repository is None:
            parser.error("CI-runs mode requires --source-sha and --repository")
        disallowed = (
            args.project,
            args.certificate_pem,
            args.ipa,
            args.output,
            args.team_id,
            args.bundle_id,
            args.marketing_version,
            args.build_number,
            args.apple_app_id,
            args.source_pck_sha256,
            args.altool_kind,
            args.run_id,
            args.run_attempt,
        )
        if any(value is not None for value in disallowed):
            parser.error("CI-runs mode received inputs for a different validation mode")
    elif args.altool_json is not None:
        if None in (
            args.altool_kind,
            args.output,
            args.apple_app_id,
            args.bundle_id,
            args.marketing_version,
            args.build_number,
        ):
            parser.error(
                "altool mode requires kind, output, Apple app ID, and release coordinates"
            )
        disallowed = (
            args.project,
            args.certificate_pem,
            args.ipa,
            args.team_id,
            args.source_sha,
            args.source_pck_sha256,
            args.repository,
            args.run_id,
            args.run_attempt,
        )
        if any(value is not None for value in disallowed):
            parser.error("altool mode received inputs for a different validation mode")
    elif args.profile_plist is not None:
        if None in (args.certificate_pem, args.team_id, args.bundle_id):
            parser.error(
                "profile mode requires --certificate-pem, --team-id, and --bundle-id"
            )
        disallowed = (
            args.project,
            args.ipa,
            args.marketing_version,
            args.build_number,
            args.source_sha,
            args.source_pck_sha256,
            args.apple_app_id,
            args.repository,
            args.altool_kind,
            args.run_id,
            args.run_attempt,
        )
        if any(value is not None for value in disallowed):
            parser.error("profile mode received inputs for a different validation mode")
    else:
        if args.project is not None or args.certificate_pem is not None:
            parser.error("archive mode received inputs for a different validation mode")
        if args.altool_kind is not None:
            parser.error("archive mode received altool inputs")
        if args.repository is not None:
            parser.error("archive mode received a CI repository input")
        if args.apple_app_id is not None:
            parser.error("archive mode received an App Store Connect Apple ID")
        required = (
            args.output,
            args.team_id,
            args.bundle_id,
            args.marketing_version,
            args.build_number,
            args.source_sha,
            args.source_pck_sha256,
            args.profile_uuid,
            args.profile_sha256,
            args.certificate_sha256,
            args.run_id,
            args.run_attempt,
        )
        if any(value is None for value in required):
            parser.error("archive mode requires output, release coordinates, and source/run binding")
    return args


def main() -> int:
    args = _parse_args()
    try:
        if args.self_test:
            run_self_test()
        elif args.source_preset is not None:
            validate_source(
                args.source_preset,
                args.project,
                args.bundle_id,
                args.marketing_version,
                args.build_number,
            )
        elif args.scaffold is not None:
            validate_scaffold_control_surfaces(args.scaffold, require_frozen_manifest=True)
        elif args.ci_runs_json is not None:
            validate_ci_runs(args.ci_runs_json, args.source_sha, args.repository)
        elif args.altool_json is not None:
            validate_altool_result(
                args.altool_json,
                args.altool_kind,
                args.output,
                args.apple_app_id,
                args.bundle_id,
                args.marketing_version,
                args.build_number,
            )
        elif args.profile_plist is not None:
            validate_profile_plist(
                args.profile_plist,
                args.certificate_pem,
                args.team_id,
                args.bundle_id,
                args.output,
            )
        else:
            validate_release(
                args.archive,
                args.ipa,
                args.output,
                args.team_id,
                args.bundle_id,
                args.marketing_version,
                args.build_number,
                args.source_sha,
                args.run_id,
                args.run_attempt,
                args.source_pck_sha256,
                args.profile_uuid,
                args.profile_sha256,
                args.certificate_sha256,
            )
    except (ReleaseValidationError, AssertionError, OSError, ValueError) as exc:
        print(f"Signed iOS release validation: FAIL: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
