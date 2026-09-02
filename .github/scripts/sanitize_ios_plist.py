#!/usr/bin/env python3
"""Sanitize and validate Godot's generated iOS application Info.plist.

INFINIDIVE does not use the camera, microphone, or photo library. Godot's iOS
template still emits empty usage-description keys for those capabilities, and
it emits the optional/deprecated CFBundleSignature key from the export preset.
This script removes only those known-empty/default values and fails closed if a
privacy usage description becomes non-empty, has an unexpected type, or a new
unreviewed UsageDescription key appears.
"""

from __future__ import annotations

import argparse
import os
import pathlib
import plistlib
import stat
import tempfile
from typing import Any


PRIVACY_USAGE_KEYS = (
    "NSCameraUsageDescription",
    "NSMicrophoneUsageDescription",
    "NSPhotoLibraryUsageDescription",
)
REMOVED_KEYS = (*PRIVACY_USAGE_KEYS, "CFBundleSignature")
MAX_PLIST_BYTES = 2 * 1024 * 1024


class PlistHardeningError(RuntimeError):
    """The generated plist does not satisfy the release hardening contract."""


def _read_plist(path: pathlib.Path) -> tuple[bytes, dict[str, Any], int]:
    try:
        metadata = path.lstat()
    except OSError as exc:
        raise PlistHardeningError(f"cannot stat plist {path}: {exc}") from exc
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISREG(metadata.st_mode):
        raise PlistHardeningError(f"plist must be a regular non-symlink file: {path}")
    if metadata.st_size > MAX_PLIST_BYTES:
        raise PlistHardeningError(
            f"plist exceeds the {MAX_PLIST_BYTES}-byte safety limit: {path}"
        )

    try:
        raw = path.read_bytes()
        decoded = plistlib.loads(raw)
    except (OSError, plistlib.InvalidFileException, ValueError) as exc:
        raise PlistHardeningError(f"cannot parse plist {path}: {exc}") from exc
    if not isinstance(decoded, dict):
        raise PlistHardeningError(f"plist root must be a dictionary: {path}")
    return raw, decoded, stat.S_IMODE(metadata.st_mode)


def _validate_unused_descriptions(plist: dict[str, Any]) -> None:
    unreviewed = sorted(
        key
        for key in plist
        if key.startswith("NS")
        and key.endswith("UsageDescription")
        and key not in PRIVACY_USAGE_KEYS
    )
    if unreviewed:
        raise PlistHardeningError(
            "generated application plist contains unreviewed privacy usage keys: "
            + ", ".join(unreviewed)
        )
    for key in PRIVACY_USAGE_KEYS:
        if key not in plist:
            continue
        value = plist[key]
        if not isinstance(value, str):
            raise PlistHardeningError(
                f"{key} must be absent or an empty string; found {type(value).__name__}"
            )
        if value.strip():
            raise PlistHardeningError(
                f"refusing to remove non-empty {key}; audit the capability and privacy copy"
            )


def _validate_sanitized(plist: dict[str, Any]) -> None:
    _validate_unused_descriptions(plist)
    present = [key for key in REMOVED_KEYS if key in plist]
    if present:
        raise PlistHardeningError(
            "generated application plist still contains forbidden keys: "
            + ", ".join(present)
        )


def _atomic_write_plist(path: pathlib.Path, plist: dict[str, Any], mode: int) -> None:
    payload = plistlib.dumps(
        plist,
        fmt=plistlib.FMT_XML,
        sort_keys=True,
    )
    temporary_path: pathlib.Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb",
            prefix=f".{path.name}.",
            suffix=".tmp",
            dir=path.parent,
            delete=False,
        ) as handle:
            temporary_path = pathlib.Path(handle.name)
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_path, mode)
        os.replace(temporary_path, path)
        temporary_path = None
        directory_fd = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    except OSError as exc:
        raise PlistHardeningError(f"cannot atomically replace plist {path}: {exc}") from exc
    finally:
        if temporary_path is not None:
            try:
                temporary_path.unlink()
            except FileNotFoundError:
                pass


def sanitize(path: pathlib.Path) -> None:
    _raw, plist, mode = _read_plist(path)
    _validate_unused_descriptions(plist)
    for key in REMOVED_KEYS:
        plist.pop(key, None)
    _validate_sanitized(plist)
    _atomic_write_plist(path, plist, mode)
    _raw_after, reparsed, _mode_after = _read_plist(path)
    _validate_sanitized(reparsed)


def check(path: pathlib.Path) -> None:
    _raw, plist, _mode = _read_plist(path)
    _validate_sanitized(plist)


def _write_fixture(path: pathlib.Path, payload: Any) -> None:
    path.write_bytes(plistlib.dumps(payload, fmt=plistlib.FMT_XML, sort_keys=True))


def run_self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="infinidive-ios-plist-test-") as root:
        root_path = pathlib.Path(root)

        positive = root_path / "positive.plist"
        _write_fixture(
            positive,
            {
                "CFBundleIdentifier": "com.matan.infinidive",
                "CFBundleSignature": "INFINIDIVE",
                "NSCameraUsageDescription": "",
                "NSMicrophoneUsageDescription": "  \t",
                "NSPhotoLibraryUsageDescription": "\n",
                "UnrelatedValue": 7,
            },
        )
        positive.chmod(0o640)
        sanitize(positive)
        check(positive)
        if stat.S_IMODE(positive.stat().st_mode) != 0o640:
            raise AssertionError("sanitization did not preserve plist file mode")
        first_pass = positive.read_bytes()
        sanitize(positive)
        if positive.read_bytes() != first_pass:
            raise AssertionError("sanitization is not deterministic and idempotent")
        positive_value = plistlib.loads(first_pass)
        if positive_value.get("UnrelatedValue") != 7:
            raise AssertionError("sanitization changed an unrelated value")

        for index, key in enumerate(PRIVACY_USAGE_KEYS):
            negative = root_path / f"negative-{index}.plist"
            _write_fixture(
                negative,
                {
                    "CFBundleIdentifier": "com.matan.infinidive",
                    key: "INFINIDIVE requires access",
                },
            )
            before = negative.read_bytes()
            try:
                sanitize(negative)
            except PlistHardeningError:
                pass
            else:
                raise AssertionError(f"non-empty {key} did not fail closed")
            if negative.read_bytes() != before:
                raise AssertionError(f"failed sanitization modified {key} fixture")

        wrong_type = root_path / "wrong-type.plist"
        _write_fixture(wrong_type, {"NSCameraUsageDescription": False})
        wrong_type_before = wrong_type.read_bytes()
        try:
            sanitize(wrong_type)
        except PlistHardeningError:
            pass
        else:
            raise AssertionError("non-string privacy usage description was accepted")
        if wrong_type.read_bytes() != wrong_type_before:
            raise AssertionError("wrong-type failure modified its plist")

        unreviewed_usage = root_path / "unreviewed-usage.plist"
        _write_fixture(
            unreviewed_usage,
            {"NSLocationWhenInUseUsageDescription": ""},
        )
        unreviewed_before = unreviewed_usage.read_bytes()
        try:
            sanitize(unreviewed_usage)
        except PlistHardeningError:
            pass
        else:
            raise AssertionError("unreviewed UsageDescription key was accepted")
        if unreviewed_usage.read_bytes() != unreviewed_before:
            raise AssertionError("unreviewed UsageDescription failure modified its plist")

        dirty_check = root_path / "dirty-check.plist"
        _write_fixture(dirty_check, {"CFBundleSignature": "ABCD"})
        try:
            check(dirty_check)
        except PlistHardeningError:
            pass
        else:
            raise AssertionError("check mode accepted CFBundleSignature")

        malformed = root_path / "malformed.plist"
        malformed.write_bytes(b"not a plist")
        try:
            sanitize(malformed)
        except PlistHardeningError:
            pass
        else:
            raise AssertionError("malformed plist was accepted")

        wrong_root = root_path / "wrong-root.plist"
        _write_fixture(wrong_root, ["not", "a", "dictionary"])
        try:
            sanitize(wrong_root)
        except PlistHardeningError:
            pass
        else:
            raise AssertionError("non-dictionary plist root was accepted")

    print("iOS Info.plist sanitizer self-test: PASS")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sanitize or validate a generated INFINIDIVE iOS Info.plist."
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--check",
        action="store_true",
        help="validate only; require all generated-only keys to be absent",
    )
    mode.add_argument(
        "--self-test",
        action="store_true",
        help="run deterministic positive and fail-closed fixtures",
    )
    parser.add_argument("plist", nargs="?", type=pathlib.Path)
    args = parser.parse_args()
    if args.self_test and args.plist is not None:
        parser.error("--self-test does not accept a plist path")
    if not args.self_test and args.plist is None:
        parser.error("a plist path is required unless --self-test is used")
    return args


def main() -> int:
    args = _parse_args()
    try:
        if args.self_test:
            run_self_test()
        elif args.check:
            check(args.plist)
            print(f"iOS Info.plist validation: PASS ({args.plist})")
        else:
            sanitize(args.plist)
            print(f"iOS Info.plist sanitization: PASS ({args.plist})")
    except (PlistHardeningError, AssertionError) as exc:
        print(f"iOS Info.plist hardening: FAIL: {exc}", file=os.sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
