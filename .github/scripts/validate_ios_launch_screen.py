#!/usr/bin/env python3
"""Validate INFINIDIVE's source and generated iOS launch-screen assets."""

from __future__ import annotations

import argparse
import binascii
import json
import pathlib
import re
import struct
import zlib
from dataclasses import dataclass


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
EXPECTED_IMAGES = {
    "storyboard/custom_image@2x": (780, 1688, "2x", "splash@2x.png"),
    "storyboard/custom_image@3x": (1170, 2532, "3x", "splash@3x.png"),
}
INACTIVE_OPTIONS = (
    "application/launch_screens_image",
    "application/launch_screens_interpolation",
)


class LaunchScreenError(RuntimeError):
    """The iOS launch-screen source/export contract is invalid."""


@dataclass(frozen=True)
class DecodedPng:
    width: int
    height: int
    pixels: bytes


def _paeth(left: int, above: int, upper_left: int) -> int:
    prediction = left + above - upper_left
    left_distance = abs(prediction - left)
    above_distance = abs(prediction - above)
    upper_left_distance = abs(prediction - upper_left)
    if left_distance <= above_distance and left_distance <= upper_left_distance:
        return left
    if above_distance <= upper_left_distance:
        return above
    return upper_left


def decode_rgb_png(path: pathlib.Path) -> DecodedPng:
    try:
        data = path.read_bytes()
    except OSError as exc:
        raise LaunchScreenError(f"cannot read PNG {path}: {exc}") from exc
    if not data.startswith(PNG_SIGNATURE):
        raise LaunchScreenError(f"invalid PNG signature: {path}")

    position = len(PNG_SIGNATURE)
    header: tuple[int, int, int, int, int, int, int] | None = None
    compressed_parts: list[bytes] = []
    saw_end = False
    while position < len(data):
        if len(data) - position < 12:
            raise LaunchScreenError(f"truncated PNG chunk: {path}")
        length = struct.unpack(">I", data[position : position + 4])[0]
        chunk_type = data[position + 4 : position + 8]
        chunk_start = position + 8
        chunk_end = chunk_start + length
        crc_end = chunk_end + 4
        if crc_end > len(data):
            raise LaunchScreenError(f"truncated PNG payload: {path}")
        chunk_data = data[chunk_start:chunk_end]
        stored_crc = struct.unpack(">I", data[chunk_end:crc_end])[0]
        actual_crc = binascii.crc32(chunk_type)
        actual_crc = binascii.crc32(chunk_data, actual_crc) & 0xFFFFFFFF
        if stored_crc != actual_crc:
            raise LaunchScreenError(f"PNG CRC mismatch in {path}")

        if chunk_type == b"IHDR":
            if header is not None or length != 13:
                raise LaunchScreenError(f"invalid PNG IHDR in {path}")
            header = struct.unpack(">IIBBBBB", chunk_data)
        elif chunk_type == b"IDAT":
            compressed_parts.append(chunk_data)
        elif chunk_type == b"IEND":
            if length != 0:
                raise LaunchScreenError(f"invalid PNG IEND in {path}")
            saw_end = True
            if crc_end != len(data):
                raise LaunchScreenError(f"unexpected data after PNG IEND: {path}")
            break
        position = crc_end

    if header is None or not compressed_parts or not saw_end:
        raise LaunchScreenError(f"incomplete PNG structure: {path}")
    width, height, bit_depth, color_type, compression, filtering, interlace = header
    if (bit_depth, color_type, compression, filtering, interlace) != (8, 2, 0, 0, 0):
        raise LaunchScreenError(
            f"launch PNG must be non-interlaced 8-bit RGB without alpha: {path}"
        )

    bytes_per_pixel = 3
    stride = width * bytes_per_pixel
    try:
        scanlines = zlib.decompress(b"".join(compressed_parts))
    except zlib.error as exc:
        raise LaunchScreenError(f"cannot decompress PNG {path}: {exc}") from exc
    expected_length = (stride + 1) * height
    if len(scanlines) != expected_length:
        raise LaunchScreenError(
            f"unexpected decompressed PNG size in {path}: "
            f"{len(scanlines)} != {expected_length}"
        )

    output = bytearray(stride * height)
    prior = bytearray(stride)
    read_offset = 0
    write_offset = 0
    for _row_index in range(height):
        filter_type = scanlines[read_offset]
        read_offset += 1
        encoded = scanlines[read_offset : read_offset + stride]
        read_offset += stride
        decoded = bytearray(stride)
        for index, value in enumerate(encoded):
            left = decoded[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            above = prior[index]
            upper_left = prior[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            if filter_type == 0:
                reconstructed = value
            elif filter_type == 1:
                reconstructed = value + left
            elif filter_type == 2:
                reconstructed = value + above
            elif filter_type == 3:
                reconstructed = value + ((left + above) // 2)
            elif filter_type == 4:
                reconstructed = value + _paeth(left, above, upper_left)
            else:
                raise LaunchScreenError(f"unsupported PNG filter {filter_type} in {path}")
            decoded[index] = reconstructed & 0xFF
        output[write_offset : write_offset + stride] = decoded
        write_offset += stride
        prior = decoded
    return DecodedPng(width=width, height=height, pixels=bytes(output))


def _preset_value(preset_text: str, key: str) -> str:
    matches = re.findall(rf"^{re.escape(key)}=(.+)$", preset_text, flags=re.MULTILINE)
    if len(matches) != 1:
        raise LaunchScreenError(f"expected exactly one iOS preset option {key}")
    return matches[0]


def _resolve_resource(project_root: pathlib.Path, raw_value: str) -> pathlib.Path:
    try:
        resource = json.loads(raw_value)
    except json.JSONDecodeError as exc:
        raise LaunchScreenError(f"invalid quoted resource path {raw_value}") from exc
    if not isinstance(resource, str) or not resource.startswith("res://"):
        raise LaunchScreenError(f"launch image must use a res:// path: {resource!r}")
    project_root = project_root.resolve()
    resolved = (project_root / resource.removeprefix("res://")).resolve()
    try:
        resolved.relative_to(project_root)
    except ValueError as exc:
        raise LaunchScreenError(f"launch image escapes project root: {resource}") from exc
    return resolved


def validate(
    preset_path: pathlib.Path,
    project_root: pathlib.Path,
    export_root: pathlib.Path,
) -> None:
    preset_text = preset_path.read_text(encoding="utf-8")
    for inactive_key in INACTIVE_OPTIONS:
        if re.search(rf"^{re.escape(inactive_key)}=", preset_text, flags=re.MULTILINE):
            raise LaunchScreenError(f"inactive Godot 4.7 option is still present: {inactive_key}")
    if _preset_value(preset_text, "storyboard/image_scale_mode") != "3":
        raise LaunchScreenError("storyboard/image_scale_mode must be aspect-fill mode 3")
    if _preset_value(preset_text, "storyboard/use_custom_bg_color") != "true":
        raise LaunchScreenError("custom launch-screen background must be enabled")

    source_images: dict[str, DecodedPng] = {}
    source_paths: dict[str, pathlib.Path] = {}
    for preset_key, (width, height, scale, _filename) in EXPECTED_IMAGES.items():
        source_path = _resolve_resource(
            project_root,
            _preset_value(preset_text, preset_key),
        )
        source = decode_rgb_png(source_path)
        if (source.width, source.height) != (width, height):
            raise LaunchScreenError(
                f"{scale} launch image must be {width}x{height}: {source_path}"
            )
        source_images[scale] = source
        source_paths[scale] = source_path

    image_sets = sorted(
        path
        for path in export_root.rglob("SplashImage.imageset")
        if path.is_dir()
    )
    if len(image_sets) != 1:
        raise LaunchScreenError(
            f"expected one generated SplashImage.imageset, found {len(image_sets)}"
        )
    image_set = image_sets[0]
    try:
        catalog = json.loads((image_set / "Contents.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise LaunchScreenError(f"cannot parse generated splash catalog: {exc}") from exc
    catalog_images = {
        item.get("scale"): item.get("filename")
        for item in catalog.get("images", [])
        if isinstance(item, dict) and item.get("filename")
    }

    for _preset_key, (_width, _height, scale, filename) in EXPECTED_IMAGES.items():
        if catalog_images.get(scale) != filename:
            raise LaunchScreenError(f"generated splash catalog has no {scale} {filename}")
        exported_path = image_set / filename
        exported = decode_rgb_png(exported_path)
        source = source_images[scale]
        if exported != source:
            raise LaunchScreenError(
                f"generated {scale} splash pixels do not match {source_paths[scale]}"
            )

    storyboards = sorted(export_root.rglob("Launch Screen.storyboard"))
    if len(storyboards) != 1:
        raise LaunchScreenError(
            f"expected one generated Launch Screen.storyboard, found {len(storyboards)}"
        )
    storyboard_text = storyboards[0].read_text(encoding="utf-8")
    if 'image="SplashImage"' not in storyboard_text:
        raise LaunchScreenError("generated storyboard does not reference SplashImage")
    if 'contentMode="scaleAspectFill"' not in storyboard_text:
        raise LaunchScreenError("generated storyboard does not use aspect-fill")

    print("iOS launch-screen source/export validation: PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preset", required=True, type=pathlib.Path)
    parser.add_argument("--project-root", required=True, type=pathlib.Path)
    parser.add_argument("--export-root", required=True, type=pathlib.Path)
    args = parser.parse_args()
    try:
        validate(args.preset, args.project_root, args.export_root)
    except (LaunchScreenError, OSError) as exc:
        print(f"iOS launch-screen validation: FAIL: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
