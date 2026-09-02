#!/usr/bin/env python3
"""Fail-closed validation for INFINIDIVE's unsigned iOS Simulator app."""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import plistlib
import re
import struct
import tempfile


EXPECTED_BUNDLE_ID = "com.matan.infinidive"
EXPECTED_MARKETING_VERSION = "0.1.0"
EXPECTED_BUILD_VERSION = "1"
EXPECTED_DISPLAY_NAME = "INFINIDIVE"
EXPECTED_MIN_IOS = "15.0"
CPU_TYPE_X86_64 = 0x01000007
CPU_TYPE_ARM64 = 0x0100000C
CPU_TYPES = {"simulator": CPU_TYPE_X86_64, "device": CPU_TYPE_ARM64}
CPU_NAMES = {"simulator": "x86_64", "device": "arm64"}
LC_BUILD_VERSION = 0x32
BUILD_PLATFORMS = {"simulator": 7, "device": 2}
MACH_HEADER_64_SIZE = 32


class SimulatorAppError(RuntimeError):
    """The compiled Simulator app differs from the reviewed release contract."""


def _regular_file(path: pathlib.Path, description: str) -> pathlib.Path:
    if path.is_symlink() or not path.is_file():
        raise SimulatorAppError(f"{description} must be a regular non-symlink file: {path}")
    return path


def _one(root: pathlib.Path, pattern: str, description: str) -> pathlib.Path:
    matches = sorted(root.rglob(pattern))
    if len(matches) != 1:
        raise SimulatorAppError(
            f"expected exactly one {description} under {root}, found {len(matches)}"
        )
    return _regular_file(matches[0], description)


def _sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _plist(path: pathlib.Path, description: str) -> dict[str, object]:
    try:
        value = plistlib.loads(path.read_bytes())
    except (OSError, plistlib.InvalidFileException, ValueError) as exc:
        raise SimulatorAppError(f"cannot parse {description} {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise SimulatorAppError(f"{description} root must be a dictionary: {path}")
    return value


def _expect(info: dict[str, object], key: str, expected: object) -> None:
    actual = info.get(key)
    if actual != expected:
        raise SimulatorAppError(f"compiled Info.plist {key}={actual!r}, expected {expected!r}")


def _validate_info(info: dict[str, object], platform: str) -> str:
    if platform == "simulator":
        supported_platform = "iPhoneSimulator"
        platform_name = "iphonesimulator"
    elif platform == "device":
        supported_platform = "iPhoneOS"
        platform_name = "iphoneos"
    else:
        raise SimulatorAppError(f"unsupported Apple build platform: {platform!r}")
    expected = {
        "CFBundleIdentifier": EXPECTED_BUNDLE_ID,
        "CFBundleShortVersionString": EXPECTED_MARKETING_VERSION,
        "CFBundleVersion": EXPECTED_BUILD_VERSION,
        "CFBundleDisplayName": EXPECTED_DISPLAY_NAME,
        "CFBundleName": EXPECTED_DISPLAY_NAME,
        "CFBundleSupportedPlatforms": [supported_platform],
        "DTPlatformName": platform_name,
        "LSRequiresIPhoneOS": True,
        "MinimumOSVersion": EXPECTED_MIN_IOS,
        "UIDeviceFamily": [1],
        "UIRequiresFullScreen": True,
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
    }
    for key, value in expected.items():
        _expect(info, key, value)

    ipad_orientations = info.get("UISupportedInterfaceOrientations~ipad")
    if ipad_orientations not in (None, ["UIInterfaceOrientationPortrait"]):
        raise SimulatorAppError(
            "compiled Info.plist contains unreviewed iPad/landscape orientations: "
            f"{ipad_orientations!r}"
        )

    sdk_name = info.get("DTSDKName")
    platform_version = info.get("DTPlatformVersion")
    if not isinstance(sdk_name, str) or re.fullmatch(
        rf"{platform_name}26(?:\.\d+)+", sdk_name
    ) is None:
        raise SimulatorAppError(f"compiled app is not bound to an iOS 26 SDK: {sdk_name!r}")
    if not isinstance(platform_version, str) or re.fullmatch(
        r"26(?:\.\d+)+", platform_version
    ) is None:
        raise SimulatorAppError(
            f"compiled app has an unexpected iOS platform version: {platform_version!r}"
        )

    protected_usage_keys = sorted(
        key
        for key in info
        if isinstance(key, str) and key.startswith("NS") and key.endswith("UsageDescription")
    )
    if protected_usage_keys:
        raise SimulatorAppError(
            "compiled app declares unreviewed protected-resource descriptions: "
            + ", ".join(protected_usage_keys)
        )
    for key in ("UIFileSharingEnabled", "LSSupportsOpeningDocumentsInPlace"):
        if info.get(key, False) is not False:
            raise SimulatorAppError(f"compiled Info.plist {key} must be absent or false")

    executable = info.get("CFBundleExecutable")
    if not isinstance(executable, str) or re.fullmatch(r"[A-Za-z0-9_.-]+", executable) is None:
        raise SimulatorAppError(f"invalid CFBundleExecutable: {executable!r}")
    return executable


def _validate_macho(path: pathlib.Path, platform: str) -> None:
    expected_cpu = CPU_TYPES[platform]
    expected_name = CPU_NAMES[platform]
    try:
        with path.open("rb") as handle:
            header = handle.read(MACH_HEADER_64_SIZE)
            if len(header) < MACH_HEADER_64_SIZE:
                raise SimulatorAppError(
                    f"compiled executable is too short for a Mach-O header: {path}"
                )
            (
                magic,
                cpu_type,
                _subtype,
                _filetype,
                command_count,
                command_size,
                _flags,
                _reserved,
            ) = struct.unpack("<IiiIIIII", header)
            if command_count > 4096 or command_size > 16 * 1024 * 1024:
                raise SimulatorAppError("compiled executable has unreasonable load commands")
            load_commands = handle.read(command_size)
    except OSError as exc:
        raise SimulatorAppError(f"cannot read compiled executable {path}: {exc}") from exc
    if header[:4] != b"\xcf\xfa\xed\xfe":
        raise SimulatorAppError(
            "compiled executable must be a thin little-endian 64-bit Mach-O for "
            + expected_name
        )
    if magic != 0xFEEDFACF or cpu_type != expected_cpu:
        raise SimulatorAppError(
            f"compiled executable has Mach-O magic/cpu {magic:#x}/{cpu_type:#x}, "
            f"expected {expected_name} {expected_cpu:#x}"
        )
    if len(load_commands) != command_size:
        raise SimulatorAppError("compiled executable has truncated Mach-O load commands")
    build_platforms: list[int] = []
    offset = 0
    for _index in range(command_count):
        if offset + 8 > len(load_commands):
            raise SimulatorAppError("compiled executable has a truncated load-command header")
        command, size = struct.unpack_from("<II", load_commands, offset)
        if size < 8 or offset + size > len(load_commands):
            raise SimulatorAppError("compiled executable has an invalid load-command size")
        if command == LC_BUILD_VERSION:
            if size < 24:
                raise SimulatorAppError("compiled executable has a short LC_BUILD_VERSION")
            build_platforms.append(struct.unpack_from("<I", load_commands, offset + 8)[0])
        offset += size
    if offset != len(load_commands):
        raise SimulatorAppError("compiled executable load-command size does not match its header")
    expected_platform = BUILD_PLATFORMS[platform]
    if build_platforms != [expected_platform]:
        raise SimulatorAppError(
            f"compiled executable LC_BUILD_VERSION platforms={build_platforms!r}, "
            f"expected [{expected_platform}] for {platform}"
        )


def validate(app: pathlib.Path, scaffold: pathlib.Path, platform: str = "simulator") -> dict[str, str]:
    if app.is_symlink() or not app.is_dir() or app.suffix != ".app":
        raise SimulatorAppError(f"compiled app must be a non-symlink .app directory: {app}")
    if scaffold.is_symlink() or not scaffold.is_dir():
        raise SimulatorAppError(f"scaffold must be a non-symlink directory: {scaffold}")

    info_path = _regular_file(app / "Info.plist", "compiled application Info.plist")
    info = _plist(info_path, "compiled application Info.plist")
    executable_name = _validate_info(info, platform)
    executable_path = _regular_file(app / executable_name, "compiled application executable")
    _validate_macho(executable_path, platform)

    app_pck = _regular_file(app / "INFINIDIVE.pck", "compiled Godot PCK")
    scaffold_pck = _one(scaffold, "*.pck", "source-bound scaffold PCK")
    if scaffold_pck.parent != scaffold:
        raise SimulatorAppError("source-bound scaffold PCK must be at the scaffold root")
    app_pck_hash = _sha256(app_pck)
    scaffold_pck_hash = _sha256(scaffold_pck)
    if not app_pck.stat().st_size or app_pck_hash != scaffold_pck_hash:
        raise SimulatorAppError(
            "compiled PCK does not exactly match the downloaded Linux scaffold "
            f"({app_pck_hash} != {scaffold_pck_hash})"
        )

    app_privacy = _regular_file(app / "PrivacyInfo.xcprivacy", "compiled privacy manifest")
    scaffold_privacy = _one(
        scaffold, "PrivacyInfo.xcprivacy", "source-bound scaffold privacy manifest"
    )
    if scaffold_privacy.parent != scaffold:
        raise SimulatorAppError("source-bound privacy manifest must be at the scaffold root")
    _plist(app_privacy, "compiled privacy manifest")
    privacy_hash = _sha256(app_privacy)
    scaffold_privacy_hash = _sha256(scaffold_privacy)
    if privacy_hash != scaffold_privacy_hash:
        raise SimulatorAppError(
            "compiled privacy manifest does not exactly match the downloaded scaffold "
            f"({privacy_hash} != {scaffold_privacy_hash})"
        )

    assets = _regular_file(app / "Assets.car", "compiled asset catalog")
    if assets.stat().st_size == 0:
        raise SimulatorAppError("compiled Assets.car is empty")

    provisioning = sorted(app.rglob("*.mobileprovision"))
    code_signature = app / "_CodeSignature"
    if provisioning or (app / "embedded.mobileprovision").exists() or code_signature.exists():
        raise SimulatorAppError(
            "unsigned Simulator app unexpectedly contains signing material: "
            + ", ".join(str(path) for path in provisioning + [code_signature] if path.exists())
        )

    return {
        "info_sha256": _sha256(info_path),
        "executable_sha256": _sha256(executable_path),
        "pck_sha256": app_pck_hash,
        "privacy_sha256": privacy_hash,
        "assets_sha256": _sha256(assets),
    }


def _write_fixture(root: pathlib.Path, platform: str) -> tuple[pathlib.Path, pathlib.Path]:
    app = root / "INFINIDIVE.app"
    scaffold = root / "scaffold"
    app.mkdir()
    scaffold.mkdir()
    info = {
        "CFBundleDisplayName": EXPECTED_DISPLAY_NAME,
        "CFBundleExecutable": EXPECTED_DISPLAY_NAME,
        "CFBundleIdentifier": EXPECTED_BUNDLE_ID,
        "CFBundleName": EXPECTED_DISPLAY_NAME,
        "CFBundleShortVersionString": EXPECTED_MARKETING_VERSION,
        "CFBundleSupportedPlatforms": [
            "iPhoneSimulator" if platform == "simulator" else "iPhoneOS"
        ],
        "CFBundleVersion": EXPECTED_BUILD_VERSION,
        "DTPlatformName": "iphonesimulator" if platform == "simulator" else "iphoneos",
        "DTPlatformVersion": "26.0",
        "DTSDKName": "iphonesimulator26.0" if platform == "simulator" else "iphoneos26.0",
        "LSRequiresIPhoneOS": True,
        "MinimumOSVersion": EXPECTED_MIN_IOS,
        "UIDeviceFamily": [1],
        "UIRequiresFullScreen": True,
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
    }
    (app / "Info.plist").write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_BINARY))
    build_version = struct.pack(
        "<IIIIII", LC_BUILD_VERSION, 24, BUILD_PLATFORMS[platform], 0, 0, 0
    )
    macho = struct.pack(
        "<IiiIIIII",
        0xFEEDFACF,
        CPU_TYPES[platform],
        0,
        2,
        1,
        len(build_version),
        0,
        0,
    ) + build_version
    (app / EXPECTED_DISPLAY_NAME).write_bytes(macho)
    pck = b"INFINIDIVE-self-test-pck\x00"
    privacy = plistlib.dumps({"NSPrivacyTracking": False}, fmt=plistlib.FMT_XML)
    (app / "INFINIDIVE.pck").write_bytes(pck)
    (scaffold / "INFINIDIVE.pck").write_bytes(pck)
    (app / "PrivacyInfo.xcprivacy").write_bytes(privacy)
    (scaffold / "PrivacyInfo.xcprivacy").write_bytes(privacy)
    (app / "Assets.car").write_bytes(b"INFINIDIVE-self-test-assets")
    return app, scaffold


def run_self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="infinidive-ios-simulator-validator-") as root_text:
        root = pathlib.Path(root_text)
        simulator_root = root / "simulator"
        simulator_root.mkdir()
        app, scaffold = _write_fixture(simulator_root, "simulator")
        validate(app, scaffold, "simulator")
        valid_macho = (app / EXPECTED_DISPLAY_NAME).read_bytes()
        valid_pck = (app / "INFINIDIVE.pck").read_bytes()
        valid_privacy = (app / "PrivacyInfo.xcprivacy").read_bytes()

        info_path = app / "Info.plist"
        info = plistlib.loads(info_path.read_bytes())
        info["NSCameraUsageDescription"] = "not reviewed"
        info_path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_BINARY))
        try:
            validate(app, scaffold, "simulator")
        except SimulatorAppError:
            pass
        else:
            raise AssertionError("protected-resource negative fixture was accepted")
        del info["NSCameraUsageDescription"]
        info_path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_BINARY))

        (app / "INFINIDIVE.pck").write_bytes(b"drifted compiled pack")
        try:
            validate(app, scaffold, "simulator")
        except SimulatorAppError:
            pass
        else:
            raise AssertionError("compiled PCK drift negative fixture was accepted")
        (app / "INFINIDIVE.pck").write_bytes(valid_pck)

        wrong_architecture = bytearray(valid_macho)
        struct.pack_into("<i", wrong_architecture, 4, CPU_TYPE_ARM64)
        (app / EXPECTED_DISPLAY_NAME).write_bytes(wrong_architecture)
        try:
            validate(app, scaffold, "simulator")
        except SimulatorAppError:
            pass
        else:
            raise AssertionError("wrong-architecture negative fixture was accepted")
        (app / EXPECTED_DISPLAY_NAME).write_bytes(valid_macho)

        (app / "PrivacyInfo.xcprivacy").write_bytes(
            plistlib.dumps({"NSPrivacyTracking": True}, fmt=plistlib.FMT_XML)
        )
        try:
            validate(app, scaffold, "simulator")
        except SimulatorAppError:
            pass
        else:
            raise AssertionError("privacy-drift negative fixture was accepted")
        (app / "PrivacyInfo.xcprivacy").write_bytes(valid_privacy)

        code_signature = app / "_CodeSignature"
        code_signature.mkdir()
        try:
            validate(app, scaffold, "simulator")
        except SimulatorAppError:
            pass
        else:
            raise AssertionError("signing-material negative fixture was accepted")

        device_root = root / "device"
        device_root.mkdir()
        device_app, device_scaffold = _write_fixture(device_root, "device")
        validate(device_app, device_scaffold, "device")
    print(
        "iOS Simulator app validator self-test: PASS "
        "(positive; protected-resource, PCK-drift, wrong-architecture, "
        "privacy-drift, and signing-material negatives; arm64 device positive)"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=pathlib.Path)
    parser.add_argument("--scaffold", type=pathlib.Path)
    parser.add_argument("--platform", choices=("simulator", "device"), default="simulator")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        if args.app is not None or args.scaffold is not None:
            parser.error("--self-test cannot be combined with --app/--scaffold")
    elif args.app is None or args.scaffold is None:
        parser.error("provide both --app and --scaffold, or use --self-test")
    try:
        if args.self_test:
            run_self_test()
        else:
            evidence = validate(args.app, args.scaffold, args.platform)
            print(
                f"iOS {args.platform} app validation: PASS "
                f"({EXPECTED_BUNDLE_ID} {EXPECTED_MARKETING_VERSION} "
                f"({EXPECTED_BUILD_VERSION}), iPhone portrait, "
                f"{CPU_NAMES[args.platform]} Mach-O, "
                f"PCK {evidence['pck_sha256']})"
            )
    except (SimulatorAppError, AssertionError, OSError, ValueError) as exc:
        print(f"iOS Simulator app validation: FAIL: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
