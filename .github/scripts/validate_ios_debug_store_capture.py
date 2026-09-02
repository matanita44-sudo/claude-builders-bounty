#!/usr/bin/env python3
"""Validate QA-only native iOS Debug store-capture stages and bright identity."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import pathlib
import re
import struct
import tempfile
import zlib


EXPECTED_WIDTH = 1320
EXPECTED_HEIGHT = 2868
EXPECTED_DEVICE_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max"
SCHEMA = "infinidive.native-ios-store-capture.v1"
VISUAL_IDENTITY = "current-bright-gameplay-v1"
CAPTURE_SEED = 24681357
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
STAGES = (
    "nest",
    "titan-exterior",
    "breach-open",
    "organ-chamber",
    "mutation-choice",
    "post-organ-titan",
)
EXPECTED_STATES = {
    "nest": None,
    "titan-exterior": "EXTERIOR",
    "breach-open": "BREACH_OPEN",
    "organ-chamber": "ORGAN_CHAMBER",
    "mutation-choice": "MUTATION_CHOICE",
    "post-organ-titan": "EXTERIOR",
}
SHA_PATTERN = re.compile(r"[0-9a-f]{40}")
REPOSITORY_PATTERN = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+")


class StoreCaptureError(RuntimeError):
    """Native capture evidence is incomplete, dim, alpha-bearing, or untruthful."""


def _load_png_validator():
    validator_path = pathlib.Path(__file__).with_name(
        "validate_ios_simulator_screenshot.py"
    )
    spec = importlib.util.spec_from_file_location(
        "infinidive_ios_screenshot_validator", validator_path
    )
    if spec is None or spec.loader is None:
        raise StoreCaptureError(f"cannot load PNG decoder: {validator_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


PNG_VALIDATOR = _load_png_validator()


def _sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _regular_file(path: pathlib.Path, description: str) -> pathlib.Path:
    if path.is_symlink() or not path.is_file():
        raise StoreCaptureError(f"{description} must be a regular file: {path}")
    return path


def _read_json(path: pathlib.Path, description: str) -> dict[str, object]:
    _regular_file(path, description)
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise StoreCaptureError(f"cannot parse {description} {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise StoreCaptureError(f"{description} root must be an object: {path}")
    return value


def _expect(mapping: dict[str, object], key: str, expected: object, context: str) -> None:
    actual = mapping.get(key)
    if actual != expected:
        raise StoreCaptureError(
            f"{context} {key}={actual!r}, expected {expected!r}"
        )


def _validate_marker(stage: str, stage_index: int, marker: dict[str, object]) -> int:
    context = f"{stage} marker"
    expected_scalars = {
        "schema": SCHEMA,
        "visual_identity": VISUAL_IDENTITY,
        "qa_only": True,
        "release_eligible": False,
        "stage": stage,
        "stage_index": stage_index,
        "capture_seed": CAPTURE_SEED,
    }
    for key, expected in expected_scalars.items():
        _expect(marker, key, expected, context)
    process_id = marker.get("process_id")
    if isinstance(process_id, bool) or not isinstance(process_id, int) or process_id <= 0:
        raise StoreCaptureError(f"{context} process_id must be a positive integer")

    gate = marker.get("gate")
    if not isinstance(gate, dict):
        raise StoreCaptureError(f"{context} gate must be an object")
    expected_gate = {
        "stage": stage,
        "debug_build": True,
        "ios_feature": True,
        "explicit_ci": True,
        "explicit_environment": True,
        "explicit_argument": True,
    }
    if gate != expected_gate:
        raise StoreCaptureError(
            f"{context} does not prove the exact Debug/CI/environment/argument gate"
        )

    runtime = marker.get("runtime")
    if not isinstance(runtime, dict):
        raise StoreCaptureError(f"{context} runtime must be an object")
    _expect(runtime, "view", "nest" if stage == "nest" else "run", context)
    _expect(runtime, "state", EXPECTED_STATES[stage], context)
    if stage == "nest":
        _expect(runtime, "destroyed_organs", [], context)
        return process_id

    _expect(runtime, "boss_id", "gravemaw", context)
    destroyed = runtime.get("destroyed_organs")
    expected_destroyed = (
        ["hunter_eye"]
        if stage in ("mutation-choice", "post-organ-titan")
        else []
    )
    if destroyed != expected_destroyed:
        raise StoreCaptureError(
            f"{context} destroyed_organs={destroyed!r}, expected {expected_destroyed!r}"
        )
    organ = runtime.get("organ")
    mutation = runtime.get("mutation")
    if not isinstance(organ, dict) or not isinstance(mutation, dict):
        raise StoreCaptureError(f"{context} organ/mutation snapshots must be objects")
    if stage in ("organ-chamber", "mutation-choice", "post-organ-titan"):
        _expect(organ, "id", "hunter_eye", context)
        _expect(
            organ,
            "status",
            "destroyed" if stage != "organ-chamber" else "selected",
            context,
        )
    if stage == "mutation-choice":
        offered_count = mutation.get("offered_count")
        if not isinstance(offered_count, int) or offered_count < 1 or offered_count > 3:
            raise StoreCaptureError(f"{context} has no bounded live mutation offer")
        _expect(mutation, "selected_count", 0, context)
    if stage == "post-organ-titan":
        _expect(runtime, "boss_visual_state", "blinded_hunter_eye", context)
        _expect(mutation, "selected_count", 1, context)
        selected_id = mutation.get("last_selected_id")
        if not isinstance(selected_id, str) or not selected_id:
            raise StoreCaptureError(f"{context} has no selected mutation identity")
    return process_id


def _png_color_type(path: pathlib.Path) -> int:
    chunks = PNG_VALIDATOR._chunks(path.read_bytes())
    headers = [data for kind, data in chunks if kind == b"IHDR"]
    if len(headers) != 1 or len(headers[0]) != 13:
        raise StoreCaptureError(f"{path.name} must have one valid PNG IHDR")
    _width, _height, depth, color_type, _compression, _filtering, _interlace = (
        struct.unpack(">IIBBBBB", headers[0])
    )
    if depth != 8 or color_type != 2:
        raise StoreCaptureError(
            f"{path.name} must be 8-bit RGB with no alpha (depth={depth}, "
            f"color_type={color_type})"
        )
    return color_type


def _bright_metrics(
    path: pathlib.Path,
    expected_dimensions: tuple[int, int],
) -> dict[str, float | int | str]:
    _regular_file(path, "stage screenshot")
    _png_color_type(path)
    try:
        width, height, rows = PNG_VALIDATOR._decode_rgb_rows(
            path, expected_dimensions
        )
    except Exception as exc:
        raise StoreCaptureError(f"cannot decode {path.name}: {exc}") from exc
    stride_x = max(1, width // 96)
    stride_y = max(1, height // 160)
    samples = 0
    luminance_total = 0
    chroma_total = 0
    bright = 0
    dark = 0
    colors: set[tuple[int, int, int]] = set()
    for y in range(0, height, stride_y):
        row = rows[y]
        for x in range(0, width, stride_x):
            red, green, blue = row[x * 3 : x * 3 + 3]
            luminance = (54 * red + 183 * green + 19 * blue) >> 8
            luminance_total += luminance
            chroma_total += max(red, green, blue) - min(red, green, blue)
            bright += int(luminance >= 110)
            dark += int(luminance < 36)
            samples += 1
            colors.add((red >> 4, green >> 4, blue >> 4))
    if samples < 5_000:
        raise StoreCaptureError(f"{path.name} produced too few RGB samples")
    mean_luminance = luminance_total / samples
    mean_chroma = chroma_total / samples
    bright_ratio = bright / samples
    dark_ratio = dark / samples
    if (
        mean_luminance < 75.0
        or mean_chroma < 12.0
        or bright_ratio < 0.28
        or dark_ratio > 0.55
        or len(colors) < 64
    ):
        raise StoreCaptureError(
            f"{path.name} does not match the current bright gameplay identity "
            f"(mean_luminance={mean_luminance:.1f}, mean_chroma={mean_chroma:.1f}, "
            f"bright_ratio={bright_ratio:.3f}, dark_ratio={dark_ratio:.3f}, "
            f"colors={len(colors)})"
        )
    return {
        "sha256": _sha256(path),
        "width": width,
        "height": height,
        "png_color_type": 2,
        "sample_count": samples,
        "mean_luminance": round(mean_luminance, 4),
        "mean_chroma": round(mean_chroma, 4),
        "bright_ratio": round(bright_ratio, 6),
        "dark_ratio": round(dark_ratio, 6),
        "quantized_colors": len(colors),
    }


def validate_capture(
    capture_dir: pathlib.Path,
    expected_commit: str,
    expected_repository: str,
    expected_run_id: str,
    expected_run_attempt: str,
    xcode_version: str,
    simulator_sdk_version: str,
    expected_dimensions: tuple[int, int] = (EXPECTED_WIDTH, EXPECTED_HEIGHT),
) -> dict[str, object]:
    if capture_dir.is_symlink() or not capture_dir.is_dir():
        raise StoreCaptureError(
            f"capture directory must be a non-symlink directory: {capture_dir}"
        )
    if SHA_PATTERN.fullmatch(expected_commit) is None:
        raise StoreCaptureError("expected commit must be a full lowercase Git SHA")
    if REPOSITORY_PATTERN.fullmatch(expected_repository) is None:
        raise StoreCaptureError("expected repository must be owner/name")
    if not expected_run_id.isdigit() or not expected_run_attempt.isdigit():
        raise StoreCaptureError("expected workflow run identifiers must be decimal")
    if re.fullmatch(r"26(?:\.\d+)+", xcode_version) is None:
        raise StoreCaptureError(f"unexpected Xcode version: {xcode_version!r}")
    if re.fullmatch(r"26(?:\.\d+)+", simulator_sdk_version) is None:
        raise StoreCaptureError(
            f"unexpected iOS Simulator SDK version: {simulator_sdk_version!r}"
        )

    stage_evidence: list[dict[str, object]] = []
    screenshot_hashes: set[str] = set()
    process_ids: set[int] = set()
    for stage_index, stage in enumerate(STAGES):
        stem = f"{stage_index:02d}-{stage}"
        marker_path = capture_dir / f"{stem}.json"
        screenshot_path = capture_dir / f"{stem}.png"
        marker = _read_json(marker_path, f"{stage} readiness marker")
        process_id = _validate_marker(stage, stage_index, marker)
        if process_id in process_ids:
            raise StoreCaptureError(
                f"{stage} marker reuses app process_id {process_id} from another stage"
            )
        process_ids.add(process_id)
        metrics = _bright_metrics(screenshot_path, expected_dimensions)
        screenshot_hash = str(metrics["sha256"])
        if screenshot_hash in screenshot_hashes:
            raise StoreCaptureError(f"{stage} screenshot duplicates another canonical stage")
        screenshot_hashes.add(screenshot_hash)
        stage_evidence.append(
            {
                "stage": stage,
                "runtime_state": EXPECTED_STATES[stage],
                "process_id": process_id,
                "marker_sha256": _sha256(marker_path),
                "screenshot": metrics,
            }
        )

    return {
        "schema": "infinidive.native-ios-store-capture-evidence.v1",
        "status": "passed",
        "qa_only": True,
        "release_eligible": False,
        "visual_identity": VISUAL_IDENTITY,
        "source_commit": expected_commit,
        "source_repository": expected_repository,
        "run_id": int(expected_run_id),
        "run_attempt": int(expected_run_attempt),
        "build": {
            "export_mode": "debug",
            "xcode_configuration": "Debug",
            "code_signing_allowed": False,
            "xcode_version": xcode_version,
            "simulator_sdk_version": simulator_sdk_version,
        },
        "simulator": {
            "device_type_identifier": EXPECTED_DEVICE_TYPE,
            "pixels": {
                "width": expected_dimensions[0],
                "height": expected_dimensions[1],
            },
        },
        "stage_count": len(stage_evidence),
        "stages": stage_evidence,
    }


def _png(
    width: int,
    height: int,
    stage_index: int,
    *,
    alpha: bool = False,
    dark: bool = False,
) -> bytes:
    channels = 4 if alpha else 3
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            if dark:
                red, green, blue = (8 + stage_index, 10, 14)
            else:
                red = 70 + ((x * 5 + stage_index * 17) % 180)
                green = 95 + ((y * 3 + stage_index * 23) % 155)
                blue = 80 + (((x + y) * 7 + stage_index * 31) % 175)
            rows.extend((red, green, blue))
            if channels == 4:
                rows.append(255)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + kind
            + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
        )

    header = struct.pack(
        ">IIBBBBB", width, height, 8, 6 if alpha else 2, 0, 0, 0
    )
    return (
        PNG_SIGNATURE
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(rows))
        + chunk(b"IEND", b"")
    )


def _marker(stage: str, stage_index: int) -> dict[str, object]:
    runtime: dict[str, object] = {
        "view": "nest" if stage == "nest" else "run",
        "state": EXPECTED_STATES[stage],
        "boss_id": None if stage == "nest" else "gravemaw",
        "destroyed_organs": (
            ["hunter_eye"]
            if stage in ("mutation-choice", "post-organ-titan")
            else []
        ),
        "organ": {},
        "ability": {},
        "mutation": {"offered_count": 0, "selected_count": 0},
        "boss_visual_state": None,
    }
    if stage in ("organ-chamber", "mutation-choice", "post-organ-titan"):
        runtime["organ"] = {
            "id": "hunter_eye",
            "status": "selected" if stage == "organ-chamber" else "destroyed",
        }
    if stage == "mutation-choice":
        runtime["mutation"] = {"offered_count": 3, "selected_count": 0}
    if stage == "post-organ-titan":
        runtime["boss_visual_state"] = "blinded_hunter_eye"
        runtime["mutation"] = {
            "offered_count": 0,
            "selected_count": 1,
            "last_selected_id": "bright_fixture",
        }
    return {
        "schema": SCHEMA,
        "visual_identity": VISUAL_IDENTITY,
        "qa_only": True,
        "release_eligible": False,
        "stage": stage,
        "stage_index": stage_index,
        "capture_seed": CAPTURE_SEED,
        "process_id": 39_107 + stage_index,
        "gate": {
            "stage": stage,
            "debug_build": True,
            "ios_feature": True,
            "explicit_ci": True,
            "explicit_environment": True,
            "explicit_argument": True,
        },
        "runtime": runtime,
    }


def run_self_test() -> None:
    dimensions = (132, 287)
    with tempfile.TemporaryDirectory(prefix="infinidive-native-store-capture-") as root_text:
        root = pathlib.Path(root_text)
        for index, stage in enumerate(STAGES):
            stem = f"{index:02d}-{stage}"
            (root / f"{stem}.json").write_text(
                json.dumps(_marker(stage, index)), encoding="utf-8"
            )
            (root / f"{stem}.png").write_bytes(
                _png(dimensions[0], dimensions[1], index)
            )
        arguments = (root, "a" * 40, "owner/repository", "71", "3", "26.0", "26.0")
        validate_capture(*arguments, expected_dimensions=dimensions)

        alpha_path = root / "00-nest.png"
        valid_nest = alpha_path.read_bytes()
        alpha_path.write_bytes(_png(*dimensions, 0, alpha=True))
        try:
            validate_capture(*arguments, expected_dimensions=dimensions)
        except StoreCaptureError:
            pass
        else:
            raise AssertionError("alpha-bearing native screenshot was accepted")
        alpha_path.write_bytes(valid_nest)

        dim_path = root / "01-titan-exterior.png"
        valid_exterior = dim_path.read_bytes()
        dim_path.write_bytes(_png(dimensions[0] - 1, dimensions[1], 1))
        try:
            validate_capture(*arguments, expected_dimensions=dimensions)
        except StoreCaptureError:
            pass
        else:
            raise AssertionError("wrong-dimension native screenshot was accepted")
        dim_path.write_bytes(valid_exterior)

        dark_path = root / "02-breach-open.png"
        valid_breach = dark_path.read_bytes()
        dark_path.write_bytes(_png(*dimensions, 2, dark=True))
        try:
            validate_capture(*arguments, expected_dimensions=dimensions)
        except StoreCaptureError:
            pass
        else:
            raise AssertionError("dim legacy-identity screenshot was accepted")
        dark_path.write_bytes(valid_breach)

        process_marker_path = root / "00-nest.json"
        valid_process_marker = process_marker_path.read_text(encoding="utf-8")
        invalid_process_marker = json.loads(valid_process_marker)
        invalid_process_marker["process_id"] = True
        process_marker_path.write_text(json.dumps(invalid_process_marker), encoding="utf-8")
        try:
            validate_capture(*arguments, expected_dimensions=dimensions)
        except StoreCaptureError:
            pass
        else:
            raise AssertionError("boolean native capture process ID was accepted")
        process_marker_path.write_text(valid_process_marker, encoding="utf-8")

        duplicate_process_path = root / "01-titan-exterior.json"
        valid_duplicate_process_marker = duplicate_process_path.read_text(encoding="utf-8")
        duplicate_process_marker = json.loads(valid_duplicate_process_marker)
        duplicate_process_marker["process_id"] = 39_107
        duplicate_process_path.write_text(
            json.dumps(duplicate_process_marker), encoding="utf-8"
        )
        try:
            validate_capture(*arguments, expected_dimensions=dimensions)
        except StoreCaptureError:
            pass
        else:
            raise AssertionError("duplicate native capture process ID was accepted")
        duplicate_process_path.write_text(
            valid_duplicate_process_marker, encoding="utf-8"
        )

        marker_path = root / "05-post-organ-titan.json"
        valid_marker = marker_path.read_text(encoding="utf-8")
        drifted = json.loads(valid_marker)
        drifted["runtime"]["boss_visual_state"] = None
        marker_path.write_text(json.dumps(drifted), encoding="utf-8")
        try:
            validate_capture(*arguments, expected_dimensions=dimensions)
        except StoreCaptureError:
            pass
        else:
            raise AssertionError("truthful-stage identity drift was accepted")
    print(
        "iOS Debug native store-capture validator self-test: PASS "
        "(six-stage bright RGB/unique-process positive; alpha, dimensions, dim "
        "identity, duplicate-process, and runtime-state negatives)"
    )


def _atomic_json(path: pathlib.Path, value: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")
    temporary: pathlib.Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb", prefix=f".{path.name}.", suffix=".tmp", dir=path.parent, delete=False
        ) as handle:
            temporary = pathlib.Path(handle.name)
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        temporary = None
    finally:
        if temporary is not None:
            try:
                temporary.unlink()
            except FileNotFoundError:
                pass


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture_dir", nargs="?", type=pathlib.Path)
    parser.add_argument("--expected-commit")
    parser.add_argument("--expected-repository")
    parser.add_argument("--expected-run-id")
    parser.add_argument("--expected-run-attempt")
    parser.add_argument("--xcode-version")
    parser.add_argument("--simulator-sdk-version")
    parser.add_argument("--write-report", type=pathlib.Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    required = (
        args.expected_commit,
        args.expected_repository,
        args.expected_run_id,
        args.expected_run_attempt,
        args.xcode_version,
        args.simulator_sdk_version,
    )
    if args.self_test:
        if args.capture_dir is not None or any(item is not None for item in required):
            parser.error("--self-test cannot be combined with capture arguments")
    elif args.capture_dir is None or any(item is None for item in required):
        parser.error("capture validation requires the directory and every expected binding")
    try:
        if args.self_test:
            run_self_test()
        else:
            evidence = validate_capture(
                args.capture_dir,
                args.expected_commit,
                args.expected_repository,
                args.expected_run_id,
                args.expected_run_attempt,
                args.xcode_version,
                args.simulator_sdk_version,
            )
            if args.write_report is not None:
                _atomic_json(args.write_report, evidence)
            print(
                "Native iOS Debug store capture: PASS "
                f"({evidence['stage_count']} truthful current-bright RGB stages, "
                f"{EXPECTED_WIDTH}x{EXPECTED_HEIGHT}, QA-only)"
            )
    except (StoreCaptureError, AssertionError, OSError, ValueError) as exc:
        print(f"Native iOS Debug store capture: FAIL: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
