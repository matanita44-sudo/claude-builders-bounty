#!/usr/bin/env python3
"""Fail-closed validation for INFINIDIVE's source/export iOS app icons."""

from __future__ import annotations

import argparse
import binascii
import hashlib
import json
import pathlib
import re
import struct
import tempfile
import zlib
from dataclasses import dataclass
from typing import Any

from validate_ios_launch_screen import LaunchScreenError, decode_rgb_png


@dataclass(frozen=True)
class IconSlot:
    preset_key: str
    source_name: str
    size: str
    scale: str | None
    pixel_size: int
    export_name: str

    @property
    def catalog_size(self) -> str:
        return f"{self.size}x{self.size}"

    @property
    def catalog_key(self) -> tuple[str, str | None]:
        return self.catalog_size, self.scale


EXPECTED_SLOTS = (
    IconSlot("icons/settings_58x58", "icon-58.png", "29", "2x", 58, "Icon-58.png"),
    IconSlot("icons/settings_87x87", "icon-87.png", "29", "3x", 87, "Icon-87.png"),
    IconSlot("icons/notification_40x40", "icon-40.png", "20", "2x", 40, "Icon-40.png"),
    IconSlot("icons/notification_60x60", "icon-60.png", "20", "3x", 60, "Icon-60.png"),
    IconSlot("icons/notification_76x76", "icon-76.png", "38", "2x", 76, "Icon-76.png"),
    IconSlot("icons/notification_114x114", "icon-114.png", "38", "3x", 114, "Icon-114.png"),
    IconSlot("icons/spotlight_80x80", "icon-80.png", "40", "2x", 80, "Icon-80.png"),
    IconSlot("icons/spotlight_120x120", "icon-120.png", "40", "3x", 120, "Icon-120.png"),
    IconSlot("icons/iphone_120x120", "icon-120.png", "60", "2x", 120, "Icon-120-1.png"),
    IconSlot("icons/iphone_180x180", "icon-180.png", "60", "3x", 180, "Icon-180.png"),
    IconSlot("icons/ipad_167x167", "icon-167.png", "83.5", "2x", 167, "Icon-167.png"),
    IconSlot("icons/ipad_152x152", "icon-152.png", "76", "2x", 152, "Icon-152.png"),
    IconSlot("icons/ios_128x128", "icon-128.png", "64", "2x", 128, "Icon-128.png"),
    IconSlot("icons/ios_192x192", "icon-192.png", "64", "3x", 192, "Icon-192.png"),
    IconSlot("icons/ios_136x136", "icon-136.png", "68", "2x", 136, "Icon-136.png"),
    IconSlot("icons/app_store_1024x1024", "icon-1024.png", "1024", None, 1024, "Icon-1024.png"),
)

EXPECTED_PRESET_KEYS = frozenset(slot.preset_key for slot in EXPECTED_SLOTS)
EXPECTED_CATALOG_KEYS = frozenset(slot.catalog_key for slot in EXPECTED_SLOTS)
EXPECTED_EXPORT_NAMES = frozenset(slot.export_name for slot in EXPECTED_SLOTS)
SAFE_FILENAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*\.png$")


class AppIconError(RuntimeError):
    """The iOS source/export app-icon contract is invalid."""


def _sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise AppIconError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def _json_no_duplicate_keys(path: pathlib.Path) -> Any:
    def reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise AppIconError(f"duplicate JSON key {key!r} in {path}")
            result[key] = value
        return result

    try:
        return json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=reject_duplicates,
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise AppIconError(f"cannot parse {path}: {exc}") from exc


def _ios_options(preset_path: pathlib.Path) -> dict[str, str]:
    try:
        text = preset_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise AppIconError(f"cannot read preset {preset_path}: {exc}") from exc

    section_matches = list(re.finditer(r"^\[([^\]\r\n]+)\]\s*$", text, re.MULTILINE))
    sections: dict[str, str] = {}
    for index, match in enumerate(section_matches):
        name = match.group(1)
        if name in sections:
            raise AppIconError(f"duplicate preset section [{name}]")
        end = section_matches[index + 1].start() if index + 1 < len(section_matches) else len(text)
        sections[name] = text[match.end() : end]

    ios_indexes: list[str] = []
    for name, body in sections.items():
        base_match = re.fullmatch(r"preset\.(\d+)", name)
        if base_match and re.search(r'^name="iOS"\s*$', body, re.MULTILINE):
            ios_indexes.append(base_match.group(1))
    if len(ios_indexes) != 1:
        raise AppIconError(f"expected exactly one iOS preset, found {len(ios_indexes)}")

    option_name = f"preset.{ios_indexes[0]}.options"
    if option_name not in sections:
        raise AppIconError(f"missing [{option_name}] section")
    options: dict[str, str] = {}
    for raw_line in sections[option_name].splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or line.startswith("#"):
            continue
        if "=" not in line:
            raise AppIconError(f"malformed iOS preset option: {raw_line!r}")
        key, value = line.split("=", 1)
        if key in options:
            raise AppIconError(f"duplicate iOS preset option {key}")
        options[key] = value

    icon_keys = frozenset(key for key in options if key.startswith("icons/"))
    if icon_keys != EXPECTED_PRESET_KEYS:
        missing = sorted(EXPECTED_PRESET_KEYS - icon_keys)
        unexpected = sorted(icon_keys - EXPECTED_PRESET_KEYS)
        raise AppIconError(
            f"iOS preset icon keys differ; missing={missing!r}, unexpected={unexpected!r}"
        )
    return options


def _source_path(
    project_root: pathlib.Path,
    preset_key: str,
    raw_value: str,
    expected_name: str,
) -> pathlib.Path:
    try:
        resource = json.loads(raw_value)
    except json.JSONDecodeError as exc:
        raise AppIconError(f"invalid resource path for {preset_key}: {raw_value!r}") from exc
    if not isinstance(resource, str) or not resource.startswith("res://"):
        raise AppIconError(f"{preset_key} must use a quoted res:// resource path")
    if pathlib.PurePosixPath(resource.removeprefix("res://")).name != expected_name:
        raise AppIconError(
            f"{preset_key} must resolve from {expected_name}, got {resource!r}"
        )
    root = project_root.resolve()
    resolved = (root / resource.removeprefix("res://")).resolve()
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise AppIconError(f"{preset_key} escapes the project root") from exc
    if resolved.is_symlink() or not resolved.is_file():
        raise AppIconError(f"{preset_key} source must be a regular non-symlink file: {resolved}")
    return resolved


def _one_app_icon_set(export_root: pathlib.Path) -> pathlib.Path:
    if export_root.is_symlink() or not export_root.is_dir():
        raise AppIconError(f"export root must be a non-symlink directory: {export_root}")
    matches = sorted(
        path for path in export_root.rglob("AppIcon.appiconset") if path.is_dir()
    )
    if len(matches) != 1:
        raise AppIconError(f"expected exactly one AppIcon.appiconset, found {len(matches)}")
    if matches[0].is_symlink():
        raise AppIconError(f"AppIcon.appiconset must not be a symlink: {matches[0]}")
    return matches[0]


def validate(
    preset_path: pathlib.Path,
    project_root: pathlib.Path,
    export_root: pathlib.Path,
) -> None:
    options = _ios_options(preset_path)
    source_paths: dict[tuple[str, str | None], pathlib.Path] = {}
    for slot in EXPECTED_SLOTS:
        source = _source_path(
            project_root,
            slot.preset_key,
            options[slot.preset_key],
            slot.source_name,
        )
        try:
            decoded = decode_rgb_png(source)
        except LaunchScreenError as exc:
            raise AppIconError(str(exc)) from exc
        if (decoded.width, decoded.height) != (slot.pixel_size, slot.pixel_size):
            raise AppIconError(
                f"{slot.preset_key} must be {slot.pixel_size}x{slot.pixel_size}: {source}"
            )
        source_paths[slot.catalog_key] = source

    icon_set = _one_app_icon_set(export_root)
    catalog_path = icon_set / "Contents.json"
    catalog = _json_no_duplicate_keys(catalog_path)
    if not isinstance(catalog, dict) or set(catalog) != {"images", "info"}:
        raise AppIconError("AppIcon Contents.json must contain only images and info")
    if catalog["info"] != {"author": "xcode", "version": 1}:
        raise AppIconError(f"unexpected AppIcon catalog info: {catalog['info']!r}")
    if not isinstance(catalog["images"], list) or len(catalog["images"]) != len(EXPECTED_SLOTS):
        raise AppIconError(
            f"AppIcon catalog must contain exactly {len(EXPECTED_SLOTS)} images"
        )

    catalog_by_slot: dict[tuple[str, str | None], dict[str, Any]] = {}
    filenames: set[str] = set()
    for index, item in enumerate(catalog["images"]):
        if not isinstance(item, dict):
            raise AppIconError(f"AppIcon image {index} is not an object")
        is_marketing = item.get("size") == "1024x1024"
        expected_item_keys = (
            {"filename", "idiom", "platform", "size"}
            if is_marketing
            else {"filename", "idiom", "platform", "size", "scale"}
        )
        if set(item) != expected_item_keys:
            raise AppIconError(
                f"AppIcon image {index} keys={sorted(item)!r}, "
                f"expected={sorted(expected_item_keys)!r}"
            )
        if item["idiom"] != "universal" or item["platform"] != "ios":
            raise AppIconError(f"AppIcon image {index} has unexpected platform metadata")
        filename = item["filename"]
        if not isinstance(filename, str) or SAFE_FILENAME.fullmatch(filename) is None:
            raise AppIconError(f"unsafe AppIcon filename at image {index}: {filename!r}")
        if pathlib.PurePosixPath(filename).name != filename:
            raise AppIconError(f"AppIcon filename must be a basename: {filename!r}")
        if filename in filenames:
            raise AppIconError(f"duplicate AppIcon filename: {filename}")
        filenames.add(filename)
        scale = item.get("scale")
        key = (item["size"], scale)
        if key not in EXPECTED_CATALOG_KEYS:
            raise AppIconError(f"unknown AppIcon size/scale slot: {key!r}")
        if key in catalog_by_slot:
            raise AppIconError(f"duplicate AppIcon size/scale slot: {key!r}")
        catalog_by_slot[key] = item

    if frozenset(catalog_by_slot) != EXPECTED_CATALOG_KEYS:
        raise AppIconError("AppIcon catalog size/scale slots are incomplete")
    if frozenset(filenames) != EXPECTED_EXPORT_NAMES:
        raise AppIconError(
            f"AppIcon filenames differ; expected={sorted(EXPECTED_EXPORT_NAMES)!r}, "
            f"actual={sorted(filenames)!r}"
        )
    exported_pngs = frozenset(path.name for path in icon_set.glob("*.png") if path.is_file())
    if exported_pngs != EXPECTED_EXPORT_NAMES:
        raise AppIconError(
            f"AppIcon exported PNG set differs; expected={sorted(EXPECTED_EXPORT_NAMES)!r}, "
            f"actual={sorted(exported_pngs)!r}"
        )

    for slot in EXPECTED_SLOTS:
        item = catalog_by_slot[slot.catalog_key]
        if item["filename"] != slot.export_name:
            raise AppIconError(
                f"{slot.catalog_key!r} filename={item['filename']!r}, "
                f"expected {slot.export_name!r}"
            )
        exported = icon_set / slot.export_name
        if exported.is_symlink() or not exported.is_file():
            raise AppIconError(f"exported icon must be a regular non-symlink file: {exported}")
        try:
            decoded = decode_rgb_png(exported)
        except LaunchScreenError as exc:
            raise AppIconError(str(exc)) from exc
        if (decoded.width, decoded.height) != (slot.pixel_size, slot.pixel_size):
            raise AppIconError(
                f"{slot.export_name} must be {slot.pixel_size}x{slot.pixel_size}"
            )
        source = source_paths[slot.catalog_key]
        if _sha256(exported) != _sha256(source):
            raise AppIconError(
                f"exported {slot.export_name} does not hash-match {source}"
            )

    print(
        "iOS app-icon validation: PASS "
        "(16 exact RGB/no-alpha source-bound size/scale slots, including 1024x1024)"
    )


def _png_bytes(width: int, height: int, rgb: tuple[int, int, int]) -> bytes:
    def chunk(kind: bytes, payload: bytes) -> bytes:
        checksum = binascii.crc32(kind)
        checksum = binascii.crc32(payload, checksum) & 0xFFFFFFFF
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", checksum)

    rows = b"".join(b"\x00" + bytes(rgb) * width for _ in range(height))
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(rows, 9))
        + chunk(b"IEND", b"")
    )


def _expect_failure(
    preset: pathlib.Path,
    project_root: pathlib.Path,
    export_root: pathlib.Path,
    label: str,
) -> None:
    try:
        validate(preset, project_root, export_root)
    except AppIconError:
        return
    raise AssertionError(f"{label} fixture was accepted")


def run_self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="infinidive-ios-app-icons-test-") as temporary:
        root = pathlib.Path(temporary)
        project_root = root / "project"
        source_root = project_root / "assets" / "platform" / "ios"
        icon_set = root / "export" / "INFINIDIVE" / "Images.xcassets" / "AppIcon.appiconset"
        source_root.mkdir(parents=True)
        icon_set.mkdir(parents=True)

        source_payloads: dict[str, bytes] = {}
        for index, slot in enumerate(EXPECTED_SLOTS):
            payload = _png_bytes(
                slot.pixel_size,
                slot.pixel_size,
                ((17 + index * 13) % 256, (71 + index * 19) % 256, (149 + index * 23) % 256),
            )
            if slot.source_name == "icon-120.png" and slot.source_name in source_payloads:
                payload = source_payloads[slot.source_name]
            source_payloads[slot.source_name] = payload
            (source_root / slot.source_name).write_bytes(payload)
            (icon_set / slot.export_name).write_bytes(payload)

        preset = project_root / "export_presets.cfg"
        option_lines = "\n".join(
            f'{slot.preset_key}="res://assets/platform/ios/{slot.source_name}"'
            for slot in EXPECTED_SLOTS
        )
        preset.write_text(
            '[preset.0]\nname="iOS"\n\n[preset.0.options]\n' + option_lines + "\n",
            encoding="utf-8",
        )
        images = []
        for slot in EXPECTED_SLOTS:
            item: dict[str, Any] = {
                "idiom": "universal",
                "platform": "ios",
                "size": slot.catalog_size,
                "filename": slot.export_name,
            }
            if slot.scale is not None:
                item["scale"] = slot.scale
            images.append(item)
        catalog_path = icon_set / "Contents.json"
        pristine_catalog = {"images": images, "info": {"author": "xcode", "version": 1}}
        catalog_path.write_text(json.dumps(pristine_catalog), encoding="utf-8")

        validate(preset, project_root, root / "export")

        wrong_scale = json.loads(json.dumps(pristine_catalog))
        wrong_scale["images"][8]["scale"] = "3x"
        catalog_path.write_text(json.dumps(wrong_scale), encoding="utf-8")
        _expect_failure(preset, project_root, root / "export", "wrong scale")

        unexpected_key = json.loads(json.dumps(pristine_catalog))
        unexpected_key["images"][0]["compression"] = "lossless"
        catalog_path.write_text(json.dumps(unexpected_key), encoding="utf-8")
        _expect_failure(preset, project_root, root / "export", "unexpected catalog key")

        duplicate_key_text = json.dumps(pristine_catalog).replace(
            '"version": 1',
            '"version": 1, "version": 1',
            1,
        )
        catalog_path.write_text(duplicate_key_text, encoding="utf-8")
        _expect_failure(preset, project_root, root / "export", "duplicate JSON key")

    print("iOS app-icon validator self-test: PASS")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate INFINIDIVE's exact iOS source/export app-icon contract."
    )
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--preset", type=pathlib.Path)
    parser.add_argument("--project-root", type=pathlib.Path)
    parser.add_argument("--export-root", type=pathlib.Path)
    args = parser.parse_args()
    supplied = (args.preset, args.project_root, args.export_root)
    if args.self_test and any(value is not None for value in supplied):
        parser.error("--self-test does not accept validation paths")
    if not args.self_test and any(value is None for value in supplied):
        parser.error("--preset, --project-root, and --export-root are required")
    return args


def main() -> int:
    args = _parse_args()
    try:
        if args.self_test:
            run_self_test()
        else:
            validate(args.preset, args.project_root, args.export_root)
    except (AppIconError, AssertionError) as exc:
        print(f"iOS app-icon validation: FAIL: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
