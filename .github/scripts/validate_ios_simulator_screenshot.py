#!/usr/bin/env python3
"""Validate that native iOS Simulator evidence is a real, non-blank PNG frame."""

from __future__ import annotations

import argparse
import os
import pathlib
import struct
import tempfile
import zlib


EXPECTED_WIDTH = 1320
EXPECTED_HEIGHT = 2868
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class ScreenshotError(RuntimeError):
    """The captured native frame is malformed, unexpected, or visually blank."""


def _paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    left_distance = abs(estimate - left)
    above_distance = abs(estimate - above)
    upper_left_distance = abs(estimate - upper_left)
    if left_distance <= above_distance and left_distance <= upper_left_distance:
        return left
    if above_distance <= upper_left_distance:
        return above
    return upper_left


def _chunks(payload: bytes) -> list[tuple[bytes, bytes]]:
    if not payload.startswith(PNG_SIGNATURE):
        raise ScreenshotError("screenshot is not a PNG")
    chunks: list[tuple[bytes, bytes]] = []
    offset = len(PNG_SIGNATURE)
    while offset < len(payload):
        if offset + 12 > len(payload):
            raise ScreenshotError("truncated PNG chunk header")
        size = struct.unpack(">I", payload[offset : offset + 4])[0]
        kind = payload[offset + 4 : offset + 8]
        data_start = offset + 8
        data_end = data_start + size
        crc_end = data_end + 4
        if crc_end > len(payload):
            raise ScreenshotError("truncated PNG chunk payload")
        data = payload[data_start:data_end]
        expected_crc = struct.unpack(">I", payload[data_end:crc_end])[0]
        if zlib.crc32(kind + data) & 0xFFFFFFFF != expected_crc:
            raise ScreenshotError(f"PNG chunk {kind!r} has an invalid CRC")
        chunks.append((kind, data))
        offset = crc_end
        if kind == b"IEND":
            if offset != len(payload):
                raise ScreenshotError("PNG has trailing data after IEND")
            break
    if not chunks or chunks[-1][0] != b"IEND":
        raise ScreenshotError("PNG has no terminal IEND chunk")
    return chunks


def _decode_rgb_rows(
    path: pathlib.Path,
    expected_dimensions: tuple[int, int] | None = None,
    require_opaque_alpha: bool = False,
) -> tuple[int, int, list[bytes]]:
    if path.is_symlink() or not path.is_file():
        raise ScreenshotError(f"PNG input must be a regular non-symlink file: {path}")
    chunks = _chunks(path.read_bytes())
    ihdr = [data for kind, data in chunks if kind == b"IHDR"]
    if len(ihdr) != 1 or len(ihdr[0]) != 13:
        raise ScreenshotError("PNG must contain exactly one valid IHDR")
    width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(
        ">IIBBBBB", ihdr[0]
    )
    if expected_dimensions is not None and (width, height) != expected_dimensions:
        raise ScreenshotError(
            f"PNG is {width}x{height}, expected {expected_dimensions[0]}x{expected_dimensions[1]}"
        )
    if bit_depth != 8 or color_type not in (2, 6):
        raise ScreenshotError(
            f"unsupported screenshot PNG format: depth={bit_depth}, color_type={color_type}"
        )
    if (compression, filtering, interlace) != (0, 0, 0):
        raise ScreenshotError("screenshot PNG must use standard non-interlaced encoding")
    channels = 3 if color_type == 2 else 4
    row_bytes = width * channels
    compressed = b"".join(data for kind, data in chunks if kind == b"IDAT")
    if not compressed:
        raise ScreenshotError("PNG has no image data")
    try:
        decoded = zlib.decompress(compressed)
    except zlib.error as exc:
        raise ScreenshotError(f"cannot decompress screenshot PNG: {exc}") from exc
    expected_size = height * (row_bytes + 1)
    if len(decoded) != expected_size:
        raise ScreenshotError(
            f"decoded PNG size is {len(decoded)}, expected {expected_size}"
        )

    previous = bytearray(row_bytes)
    rgb_rows: list[bytes] = []
    offset = 0
    for row_index in range(height):
        filter_type = decoded[offset]
        raw = decoded[offset + 1 : offset + 1 + row_bytes]
        offset += row_bytes + 1
        if filter_type not in range(5):
            raise ScreenshotError(f"unsupported PNG filter {filter_type} on row {row_index}")
        current = bytearray(row_bytes)
        for index, value in enumerate(raw):
            left = current[index - channels] if index >= channels else 0
            above = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_type == 0:
                predictor = 0
            elif filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = above
            elif filter_type == 3:
                predictor = (left + above) // 2
            else:
                predictor = _paeth(left, above, upper_left)
            current[index] = (value + predictor) & 0xFF
        if channels == 3:
            rgb_rows.append(bytes(current))
        else:
            rgb = bytearray(width * 3)
            for pixel in range(width):
                source = pixel * 4
                destination = pixel * 3
                if require_opaque_alpha and current[source + 3] != 255:
                    raise ScreenshotError(
                        f"screenshot contains non-opaque alpha on row {row_index}, pixel {pixel}"
                    )
                rgb[destination : destination + 3] = current[source : source + 3]
            rgb_rows.append(bytes(rgb))
        previous = current
    return width, height, rgb_rows


def _encode_rgb_png(width: int, height: int, rows: list[bytes]) -> bytes:
    if width <= 0 or height <= 0 or len(rows) != height:
        raise ScreenshotError("cannot encode invalid RGB dimensions")
    scanlines = bytearray()
    for row in rows:
        if len(row) != width * 3:
            raise ScreenshotError("cannot encode malformed RGB row")
        scanlines.append(0)
        scanlines.extend(row)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + kind
            + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        PNG_SIGNATURE
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(scanlines), level=9))
        + chunk(b"IEND", b"")
    )


def normalize_opaque_rgb(source: pathlib.Path, output: pathlib.Path) -> tuple[int, int]:
    if output.exists() or output.is_symlink():
        raise ScreenshotError(f"refusing to overwrite normalized screenshot: {output}")
    if not output.parent.is_dir() or output.parent.is_symlink():
        raise ScreenshotError(f"normalized screenshot directory is invalid: {output.parent}")
    width, height, rows = _decode_rgb_rows(source, require_opaque_alpha=True)
    payload = _encode_rgb_png(width, height, rows)
    temporary: pathlib.Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb",
            prefix=f".{output.name}.",
            suffix=".tmp",
            dir=output.parent,
            delete=False,
        ) as handle:
            temporary = pathlib.Path(handle.name)
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, output)
        temporary = None
    finally:
        if temporary is not None:
            try:
                temporary.unlink()
            except FileNotFoundError:
                pass
    return width, height


def _normalized_frame_distance(
    frame: tuple[int, int, list[bytes]],
    reference: tuple[int, int, list[bytes]],
) -> float:
    frame_width, frame_height, frame_rows = frame
    reference_width, reference_height, reference_rows = reference
    total = 0
    channel_samples = 0
    # Ignore the top safe-area band where the Simulator adds Dynamic Island
    # pixels that do not exist in the launch-screen source. The remaining grid
    # proves that the app replaced the storyboard with a real rendered frame.
    for grid_y in range(6, 78):
        normalized_y = grid_y / 80.0
        frame_y = min(frame_height - 1, int(normalized_y * frame_height))
        reference_y = min(reference_height - 1, int(normalized_y * reference_height))
        frame_row = frame_rows[frame_y]
        reference_row = reference_rows[reference_y]
        for grid_x in range(1, 40):
            normalized_x = grid_x / 40.0
            frame_x = min(frame_width - 1, int(normalized_x * frame_width)) * 3
            reference_x = min(reference_width - 1, int(normalized_x * reference_width)) * 3
            for channel in range(3):
                total += abs(frame_row[frame_x + channel] - reference_row[reference_x + channel])
                channel_samples += 1
    if channel_samples == 0:
        raise ScreenshotError("cannot compare native frame with launch-screen reference")
    return total / (channel_samples * 255.0)


def validate(
    path: pathlib.Path,
    forbidden_reference: pathlib.Path | None = None,
) -> dict[str, float | int]:
    width, height, rows = _decode_rgb_rows(path, (EXPECTED_WIDTH, EXPECTED_HEIGHT))
    luminance_min = 255
    luminance_max = 0
    near_black = 0
    samples = 0
    quantized_colors: set[tuple[int, int, int]] = set()
    for row_index, current in enumerate(rows):
        if row_index % 8 == 0:
            for pixel in range(0, width, 8):
                start = pixel * 3
                red, green, blue = current[start : start + 3]
                luminance = (54 * red + 183 * green + 19 * blue) >> 8
                luminance_min = min(luminance_min, luminance)
                luminance_max = max(luminance_max, luminance)
                near_black += int(red < 12 and green < 12 and blue < 12)
                samples += 1
                if len(quantized_colors) < 1024:
                    quantized_colors.add((red >> 4, green >> 4, blue >> 4))
    non_black_ratio = 1.0 - (near_black / samples)
    luminance_range = luminance_max - luminance_min
    if samples < 10_000:
        raise ScreenshotError("insufficient decoded pixel samples")
    if non_black_ratio < 0.05 or luminance_range < 24 or len(quantized_colors) < 32:
        raise ScreenshotError(
            "native screenshot is blank or visually degenerate "
            f"(non_black={non_black_ratio:.3f}, luminance_range={luminance_range}, "
            f"colors={len(quantized_colors)})"
        )
    evidence: dict[str, float | int] = {
        "width": width,
        "height": height,
        "sample_count": samples,
        "non_black_ratio": non_black_ratio,
        "luminance_range": luminance_range,
        "quantized_colors": len(quantized_colors),
    }
    if forbidden_reference is not None:
        reference = _decode_rgb_rows(forbidden_reference)
        distance = _normalized_frame_distance((width, height, rows), reference)
        evidence["forbidden_reference_distance"] = distance
        if distance < 0.035:
            raise ScreenshotError(
                "native screenshot still matches the iOS launch storyboard "
                f"(normalized RGB distance={distance:.4f})"
            )
    return evidence


def _png(
    width: int,
    height: int,
    varied: bool,
    alpha: bool = False,
    alpha_value: int = 255,
) -> bytes:
    if alpha_value < 0 or alpha_value > 255:
        raise ValueError("alpha fixture value must be an unsigned byte")
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(
            ">I", zlib.crc32(kind + data) & 0xFFFFFFFF
        )

    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            if varied:
                rows.extend(((x * 255) // max(1, width - 1), (y * 255) // max(1, height - 1), (x + y) % 256))
            else:
                rows.extend((0, 0, 0))
            if alpha:
                rows.append(alpha_value)
    header = struct.pack(">IIBBBBB", width, height, 8, 6 if alpha else 2, 0, 0, 0)
    return PNG_SIGNATURE + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")


def run_self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="infinidive-ios-screenshot-") as root_text:
        root = pathlib.Path(root_text)
        positive = root / "positive.png"
        positive.write_bytes(_png(EXPECTED_WIDTH, EXPECTED_HEIGHT, True))
        validate(positive)
        blank = root / "blank.png"
        blank.write_bytes(_png(EXPECTED_WIDTH, EXPECTED_HEIGHT, False))
        validate(positive, blank)
        try:
            validate(positive, positive)
        except ScreenshotError:
            pass
        else:
            raise AssertionError("unchanged launch-screen fixture was accepted")
        try:
            validate(blank)
        except ScreenshotError:
            pass
        else:
            raise AssertionError("blank native screenshot fixture was accepted")
        rgba = root / "opaque-rgba.png"
        normalized = root / "normalized-rgb.png"
        rgba.write_bytes(_png(4, 3, True, alpha=True))
        if normalize_opaque_rgb(rgba, normalized) != (4, 3):
            raise AssertionError("opaque RGBA normalization returned wrong dimensions")
        normalized_chunks = _chunks(normalized.read_bytes())
        normalized_header = [data for kind, data in normalized_chunks if kind == b"IHDR"]
        if len(normalized_header) != 1 or struct.unpack(">IIBBBBB", normalized_header[0])[3] != 2:
            raise AssertionError("opaque RGBA normalization did not emit RGB/no-alpha PNG")
        nonopaque = root / "nonopaque-rgba.png"
        nonopaque.write_bytes(_png(1, 1, True, alpha=True, alpha_value=254))
        try:
            normalize_opaque_rgb(nonopaque, root / "must-not-exist.png")
        except ScreenshotError:
            pass
        else:
            raise AssertionError("non-opaque RGBA screenshot was normalized instead of rejected")
    print(
        "iOS Simulator screenshot validator self-test: PASS "
        "(varied positive, blank negative, unchanged-launch negative)"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("screenshot", nargs="?", type=pathlib.Path)
    parser.add_argument("--forbid-reference", type=pathlib.Path)
    parser.add_argument("--normalize-rgb", type=pathlib.Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        if args.screenshot is not None or args.normalize_rgb is not None:
            parser.error("--self-test cannot be combined with a screenshot")
    elif args.screenshot is None:
        parser.error("provide a screenshot or use --self-test")
    try:
        if args.self_test:
            run_self_test()
        elif args.normalize_rgb is not None:
            if args.forbid_reference is not None:
                parser.error("--normalize-rgb cannot be combined with --forbid-reference")
            width, height = normalize_opaque_rgb(args.screenshot, args.normalize_rgb)
            print(
                "iOS Simulator screenshot RGB normalization: PASS "
                f"({width}x{height}, opaque input, deterministic RGB/no-alpha output)"
            )
        else:
            evidence = validate(args.screenshot, args.forbid_reference)
            launch_distance = evidence.get("forbidden_reference_distance")
            print(
                "iOS Simulator screenshot validation: PASS "
                f"({evidence['width']}x{evidence['height']}, "
                f"non-black {evidence['non_black_ratio']:.3f}, "
                f"luminance range {evidence['luminance_range']}, "
                f"colors {evidence['quantized_colors']}"
                + (
                    f", launch distance {float(launch_distance):.4f})"
                    if launch_distance is not None
                    else ")"
                )
            )
    except (ScreenshotError, AssertionError, OSError, ValueError) as exc:
        print(f"iOS Simulator screenshot validation: FAIL: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
