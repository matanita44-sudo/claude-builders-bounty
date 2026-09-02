#!/usr/bin/env python3
"""Validate that a bright gameplay trailer is source-bound, truthful, and nontrivial."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import statistics
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit, urlunsplit


EXPECTED_CLASSIFICATION = (
    "current_source_ci_browser_gameplay_trailer_review_candidate_not_apple_submission_evidence"
)
EXPECTED_CAPTURE_STATUS = "captured_pending_independent_validation"
EXPECTED_SCHEMA_VERSION = 2
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


class ValidationError(RuntimeError):
    """Raised when an artifact does not meet the source-bound trailer contract."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def sha256_file(file_path: Path) -> str:
    digest = hashlib.sha256()
    with file_path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_url(raw_url: str, qa: bool = False) -> str:
    parsed = urlsplit(raw_url)
    require(parsed.scheme in {"http", "https"}, f"Unsupported target URL scheme: {parsed.scheme!r}")
    require(bool(parsed.hostname), "Target URL has no hostname")
    host = parsed.hostname
    if ":" in host and not host.startswith("["):
        host = f"[{host}]"
    if parsed.port is not None:
        host = f"{host}:{parsed.port}"
    path = parsed.path or "/"
    return urlunsplit((parsed.scheme, host, path, "infinidive_qa=1" if qa else "", ""))


def safe_artifact_path(evidence_dir: Path, basename: Any, suffixes: set[str], label: str) -> Path:
    require(isinstance(basename, str), f"{label} filename is not a string")
    require(Path(basename).name == basename, f"{label} filename is not a safe basename: {basename!r}")
    require(Path(basename).suffix.lower() in suffixes, f"{label} has an unsupported suffix: {basename!r}")
    resolved = (evidence_dir / basename).resolve()
    require(resolved.parent == evidence_dir.resolve(), f"{label} escapes evidence directory")
    require(resolved.is_file(), f"{label} is missing: {resolved}")
    return resolved


def safe_repository_path(relative_path: Any, label: str) -> Path:
    require(isinstance(relative_path, str) and bool(relative_path), f"{label} path is invalid")
    require("\\" not in relative_path, f"{label} must use repository-relative POSIX separators")
    candidate = Path(relative_path)
    require(not candidate.is_absolute(), f"{label} path must be repository-relative")
    require(candidate.parts and all(part not in {"", ".", ".."} for part in candidate.parts), f"{label} path is unsafe")
    resolved = (REPOSITORY_ROOT / candidate).resolve()
    require(resolved != REPOSITORY_ROOT and REPOSITORY_ROOT in resolved.parents, f"{label} escapes repository")
    require(resolved.is_file(), f"{label} is missing: {relative_path}")
    return resolved


def require_sha256(value: Any, label: str) -> str:
    require(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None, f"{label} is invalid")
    return value


def run(command: list[str], label: str, binary: bool = False) -> bytes | str:
    completed = subprocess.run(command, check=False, capture_output=True)
    if completed.returncode != 0:
        stderr = completed.stderr.decode("utf-8", "replace")[-4000:]
        raise ValidationError(f"{label} failed ({completed.returncode}): {stderr}")
    return completed.stdout if binary else completed.stdout.decode("utf-8", "strict")


def ffprobe(file_path: Path, ffprobe_bin: str) -> dict[str, Any]:
    output = run(
        [
            ffprobe_bin,
            "-v",
            "error",
            "-show_entries",
            (
                "format=format_name,duration,size:"
                "stream=index,codec_type,codec_name,profile,width,height,pix_fmt,"
                "avg_frame_rate,r_frame_rate,sample_fmt,sample_rate,channels,channel_layout,duration"
            ),
            "-of",
            "json",
            str(file_path),
        ],
        f"FFprobe {file_path.name}",
    )
    return json.loads(output)


def audio_levels(file_path: Path, ffmpeg_bin: str) -> dict[str, float]:
    completed = subprocess.run(
        [
            ffmpeg_bin,
            "-hide_banner",
            "-nostats",
            "-i",
            str(file_path),
            "-map",
            "0:a:0",
            "-af",
            "volumedetect",
            "-f",
            "null",
            "-",
        ],
        check=False,
        capture_output=True,
    )
    require(completed.returncode == 0, f"Audio level analysis failed for {file_path.name}")
    diagnostics = completed.stderr.decode("utf-8", "replace")
    mean_match = re.search(r"mean_volume:\s*(-?(?:\d+(?:\.\d+)?|inf))\s*dB", diagnostics, re.IGNORECASE)
    peak_match = re.search(r"max_volume:\s*(-?(?:\d+(?:\.\d+)?|inf))\s*dB", diagnostics, re.IGNORECASE)
    require(mean_match is not None and peak_match is not None, f"Audio levels were not reported for {file_path.name}")
    return {
        "mean_volume_dbfs": float(mean_match.group(1)),
        "peak_volume_dbfs": float(peak_match.group(1)),
    }


def assert_audio_levels(levels: dict[str, float], validation: dict[str, Any], label: str) -> None:
    mean_volume = levels.get("mean_volume_dbfs", -math.inf)
    peak_volume = levels.get("peak_volume_dbfs", -math.inf)
    require(math.isfinite(mean_volume) and math.isfinite(peak_volume), f"{label} is silent")
    require(mean_volume >= validation["minimum_mean_volume_dbfs"], f"{label} mean level is too low: {mean_volume} dBFS")
    require(peak_volume >= validation["minimum_peak_volume_dbfs"], f"{label} peak level is too low: {peak_volume} dBFS")
    require(peak_volume <= validation["maximum_peak_volume_dbfs"], f"{label} peak level is too high: {peak_volume} dBFS")


def video_packet_sha256(file_path: Path, ffmpeg_bin: str) -> str:
    output = run(
        [
            ffmpeg_bin,
            "-hide_banner",
            "-v",
            "error",
            "-i",
            str(file_path),
            "-map",
            "0:v:0",
            "-c:v",
            "copy",
            "-f",
            "hash",
            "-hash",
            "sha256",
            "-",
        ],
        f"Video packet hash {file_path.name}",
    ).strip()
    match = re.fullmatch(r"SHA256=([0-9a-f]{64})", output)
    require(match is not None, f"Invalid video packet hash output for {file_path.name}")
    return match.group(1)


def parse_rate(raw_rate: Any) -> float:
    require(isinstance(raw_rate, str) and "/" in raw_rate, f"Invalid frame rate {raw_rate!r}")
    numerator_raw, denominator_raw = raw_rate.split("/", 1)
    numerator = float(numerator_raw)
    denominator = float(denominator_raw)
    require(math.isfinite(numerator) and math.isfinite(denominator) and denominator > 0, "Invalid frame rate")
    return numerator / denominator


def video_stream(probe: dict[str, Any]) -> dict[str, Any]:
    streams = [stream for stream in probe.get("streams", []) if stream.get("codec_type") == "video"]
    require(len(streams) == 1, f"Expected exactly one video stream, found {len(streams)}")
    return streams[0]


def audio_streams(probe: dict[str, Any]) -> list[dict[str, Any]]:
    return [stream for stream in probe.get("streams", []) if stream.get("codec_type") == "audio"]


def assert_deliverable_probe(
    probe: dict[str, Any],
    deliverable_manifest: dict[str, Any],
    deliverable_contract: dict[str, Any],
    audio_contract: dict[str, Any],
    file_suffix: str,
) -> dict[str, Any]:
    stream = video_stream(probe)
    observed_audio_streams = audio_streams(probe)
    require(len(observed_audio_streams) == audio_contract["track_count"], f"Expected exactly one audio stream, found {len(observed_audio_streams)}")
    audio = observed_audio_streams[0]
    require(len(probe.get("streams", [])) == 2, "Deliverable contains unexpected non-audio/video streams")
    duration = float(probe["format"]["duration"])
    size = int(probe["format"]["size"])
    container = deliverable_manifest.get("container")
    format_names = set(str(probe["format"].get("format_name", "")).split(","))
    if container == "mp4":
        require(file_suffix == ".mp4" and bool({"mov", "mp4"} & format_names), "MP4 manifest/container mismatch")
    elif container == "webm":
        require(file_suffix == ".webm" and "webm" in format_names, "WebM manifest/container mismatch")
    else:
        raise ValidationError(f"Unsupported declared container: {container!r}")
    profiles = deliverable_contract["accepted_profiles"]
    accepted = any(
        container == profile["container"]
        and stream.get("codec_name") == profile["video_codec"]
        and stream.get("pix_fmt") == profile["pixel_format"]
        and audio.get("codec_name") == profile["audio_codec"]
        for profile in profiles
    )
    require(accepted, f"Deliverable audio/video codec, container, or pixel format is unsupported: {probe.get('streams')!r}")
    require(deliverable_manifest.get("video_codec") == stream.get("codec_name"), "Manifest codec differs from FFprobe")
    require(deliverable_manifest.get("audio_codec") == audio.get("codec_name"), "Manifest audio codec differs from FFprobe")
    require(stream.get("width") == deliverable_contract["width"], "Deliverable width mismatch")
    require(stream.get("height") == deliverable_contract["height"], "Deliverable height mismatch")
    require(
        deliverable_contract["minimum_duration_seconds"] <= duration <= deliverable_contract["maximum_duration_seconds"],
        f"Deliverable duration {duration}s is outside 15–30s",
    )
    require(size <= deliverable_contract["maximum_bytes"], "Deliverable exceeds byte limit")
    frame_rate = parse_rate(stream.get("avg_frame_rate"))
    require(frame_rate <= deliverable_contract["maximum_frame_rate"] + 0.01, f"Frame rate {frame_rate} is too high")
    require(deliverable_manifest.get("audio_tracks") == audio_contract["track_count"], "Manifest audio-track count is false")
    require(audio.get("codec_name") in {"aac", "opus"}, "Deliverable audio is not AAC or Opus")
    require(int(audio.get("sample_rate", -1)) == audio_contract["mux"]["encoded_sample_rate"], "Deliverable audio sample rate mismatch")
    require(audio.get("channels") == audio_contract["mux"]["encoded_channels"], "Deliverable audio channel count mismatch")
    return {
        "stream": stream,
        "audio_stream": audio,
        "duration": duration,
        "size": size,
        "frame_rate": frame_rate,
    }


def value_at_path(value: dict[str, Any], dotted_path: str) -> Any:
    cursor: Any = value
    for segment in dotted_path.split("."):
        if not isinstance(cursor, dict):
            return None
        cursor = cursor.get(segment)
    return cursor


def normalized_frame_distance(left: bytes, right: bytes) -> float:
    require(len(left) == len(right) and len(left) > 0, "Cannot compare unequal or empty frames")
    return sum(abs(a - b) for a, b in zip(left, right, strict=True)) / (len(left) * 255.0)


def frame_mean_luma(frame: bytes) -> float:
    require(len(frame) % 3 == 0 and len(frame) > 0, "RGB frame has an invalid byte count")
    total = 0.0
    for index in range(0, len(frame), 3):
        total += 0.2126 * frame[index] + 0.7152 * frame[index + 1] + 0.0722 * frame[index + 2]
    return total / (len(frame) // 3)


def frame_luma_deviation(frame: bytes) -> float:
    lumas = [
        0.2126 * frame[index] + 0.7152 * frame[index + 1] + 0.0722 * frame[index + 2]
        for index in range(0, len(frame), 3)
    ]
    return statistics.pstdev(lumas)


def analyse_frames(frames: list[bytes], bright_threshold: float) -> dict[str, Any]:
    require(len(frames) > 0, "No decoded frames were available for visual validation")
    lumas = [frame_mean_luma(frame) for frame in frames]
    deviations = [frame_luma_deviation(frame) for frame in frames]
    interframe = [
        normalized_frame_distance(frames[index - 1], frames[index])
        for index in range(1, len(frames))
    ]
    perceptually_unique: list[bytes] = []
    for frame in frames:
        if all(normalized_frame_distance(frame, prior) >= 0.006 for prior in perceptually_unique):
            perceptually_unique.append(frame)
    return {
        "sample_count": len(frames),
        "unique_frame_count": len(perceptually_unique),
        "unique_frame_fraction": len(perceptually_unique) / len(frames),
        "median_frame_mean_luma": statistics.median(lumas),
        "bright_frame_fraction": sum(value >= bright_threshold for value in lumas) / len(lumas),
        "median_frame_luma_deviation": statistics.median(deviations),
        "mean_interframe_distance": statistics.fmean(interframe) if interframe else 0.0,
        "frame_mean_lumas": lumas,
        "interframe_distances": interframe,
    }


def assert_visual_metrics(metrics: dict[str, Any], visual_contract: dict[str, Any]) -> None:
    comparisons = [
        ("sample_count", metrics["sample_count"], visual_contract["minimum_sample_count"]),
        ("unique_frame_fraction", metrics["unique_frame_fraction"], visual_contract["minimum_unique_frame_fraction"]),
        ("median_frame_mean_luma", metrics["median_frame_mean_luma"], visual_contract["minimum_median_luma"]),
        ("bright_frame_fraction", metrics["bright_frame_fraction"], visual_contract["minimum_bright_frame_fraction"]),
        (
            "median_frame_luma_deviation",
            metrics["median_frame_luma_deviation"],
            visual_contract["minimum_frame_luma_deviation"],
        ),
        (
            "mean_interframe_distance",
            metrics["mean_interframe_distance"],
            visual_contract["minimum_mean_interframe_distance"],
        ),
    ]
    for name, observed, minimum in comparisons:
        require(observed >= minimum, f"Visual metric {name}={observed:.6f} is below {minimum}")


def decode_sample_frames(
    media_path: Path,
    ffmpeg_bin: str,
    width: int,
    height: int,
    interval: float,
) -> list[bytes]:
    frame_size = width * height * 3
    output = run(
        [
            ffmpeg_bin,
            "-hide_banner",
            "-v",
            "error",
            "-i",
            str(media_path),
            "-vf",
            f"fps=1/{interval:.6f},scale={width}:{height}:flags=area,format=rgb24",
            "-f",
            "rawvideo",
            "-pix_fmt",
            "rgb24",
            "-",
        ],
        f"Decode sampled frames from {media_path.name}",
        binary=True,
    )
    require(len(output) % frame_size == 0, "FFmpeg returned a partial RGB sample frame")
    return [output[index : index + frame_size] for index in range(0, len(output), frame_size)]


def decode_reference_frame(
    image_path: Path,
    ffmpeg_bin: str,
    width: int,
    height: int,
) -> bytes:
    output = run(
        [
            ffmpeg_bin,
            "-hide_banner",
            "-v",
            "error",
            "-i",
            str(image_path),
            "-frames:v",
            "1",
            "-vf",
            f"scale={width}:{height}:flags=area,format=rgb24",
            "-f",
            "rawvideo",
            "-pix_fmt",
            "rgb24",
            "-",
        ],
        f"Decode legacy reference {image_path.name}",
        binary=True,
    )
    require(len(output) == width * height * 3, f"Legacy reference {image_path.name} decoded incorrectly")
    return output


def validate_contract(contract: dict[str, Any]) -> None:
    require(contract.get("schema_version") == EXPECTED_SCHEMA_VERSION, "Trailer contract schema is not version 2")
    require(contract.get("classification") == EXPECTED_CLASSIFICATION, "Trailer contract classification changed")
    require(contract.get("evidence_manifest") == "infinidive-bright-trailer.json", "Unexpected evidence manifest")
    capture = contract.get("capture", {})
    deliverable = contract.get("deliverable", {})
    audio = contract.get("audio", {})
    editing = contract.get("editing", {})
    require(capture.get("actual_gameplay") is True, "Contract does not require actual gameplay")
    require(capture.get("generated_or_mocked_gameplay") is False, "Contract permits mocked gameplay")
    require(capture.get("debug_state_injection") is False, "Contract permits debug state injection")
    require(capture.get("save_manipulation") is False, "Contract permits save manipulation")
    require(capture.get("browser_audio_captured") is False, "Contract falsely claims browser-captured audio")
    require(
        isinstance(capture.get("browser_audio_disclosure"), str)
        and "not event-synchronous" in capture["browser_audio_disclosure"],
        "Contract omits the offline/non-synchronous audio disclosure",
    )
    require(deliverable.get("minimum_duration_seconds", 0) >= 15, "Contract duration minimum is below 15s")
    require(deliverable.get("maximum_duration_seconds", 99) <= 30, "Contract duration maximum exceeds 30s")
    require(deliverable.get("maximum_frame_rate", 99) <= 30, "Contract frame rate exceeds 30fps")
    require(
        "Exactly one AAC (MP4) or Opus (WebM) track" in str(deliverable.get("audio_policy", ""))
        and "not live-captured or event-synchronous" in deliverable["audio_policy"],
        "Contract audio policy is missing or misleading",
    )
    profile_keys = [
        (profile.get("container"), profile.get("video_codec"), profile.get("pixel_format"), profile.get("audio_codec"))
        for profile in deliverable.get("accepted_profiles", [])
    ]
    require(
        profile_keys == [("mp4", "h264", "yuv420p", "aac"), ("webm", "vp9", "yuv420p", "opus")],
        "Contract does not bind each container to exactly one supported audio/video profile",
    )
    source_asset = audio.get("source_asset", {})
    provenance = audio.get("provenance", {})
    mux = audio.get("mux", {})
    audio_validation = audio.get("validation", {})
    require(audio.get("track_count") == 1, "Contract does not require exactly one audio track")
    require(source_asset.get("format") == "wav" and source_asset.get("codec") == "pcm_s16le", "Audio source is not PCM WAV")
    require(source_asset.get("sample_rate") == 48000 and source_asset.get("channels") == 2, "Audio source PCM format changed")
    require(source_asset.get("duration_seconds") == 30.0, "Audio source must cover the full 30-second contract window")
    require(isinstance(source_asset.get("bytes"), int) and source_asset["bytes"] > 0, "Audio source byte count is invalid")
    require(Path(str(source_asset.get("evidence_file", ""))).name == source_asset.get("evidence_file"), "Audio evidence filename is unsafe")
    require(Path(str(source_asset.get("evidence_file", ""))).suffix.lower() == ".wav", "Audio evidence is not WAV")
    require_sha256(source_asset.get("sha256"), "Audio source hash")
    require(
        provenance.get("kind") == "deterministic_offline_mix_of_project_generated_runtime_music"
        and provenance.get("project_owned") is True
        and provenance.get("external_samples") is False
        and provenance.get("browser_captured") is False
        and provenance.get("event_synchronized") is False
        and provenance.get("music_only") is True,
        "Audio provenance is missing or overclaims the offline music bed",
    )
    source_files = provenance.get("source_files")
    require(isinstance(source_files, list) and len(source_files) >= 3, "Audio provenance source list is incomplete")
    source_names: set[str] = set()
    for source in source_files:
        require(isinstance(source, dict), "Audio provenance source entry is invalid")
        relative = source.get("repository_file")
        require(isinstance(relative, str) and relative not in source_names, "Audio provenance source path is empty or duplicated")
        source_names.add(relative)
        require_sha256(source.get("sha256"), f"Audio provenance hash for {relative}")
    require(
        mux.get("timing") == "trim_source_music_to_edited_video_duration"
        and mux.get("video_mode") == "stream_copy_after_hard_cut_video_encode"
        and mux.get("require_identical_video_packet_sha256_before_and_after_audio_mux") is True
        and mux.get("encoded_sample_rate") == 48000
        and mux.get("encoded_channels") == 2,
        "Audio mux contract can change gameplay frames or encoded audio format",
    )
    minimum_mean = audio_validation.get("minimum_mean_volume_dbfs")
    minimum_peak = audio_validation.get("minimum_peak_volume_dbfs")
    maximum_peak = audio_validation.get("maximum_peak_volume_dbfs")
    require(
        all(isinstance(value, (int, float)) and math.isfinite(value) for value in (minimum_mean, minimum_peak, maximum_peak))
        and minimum_mean < minimum_peak < maximum_peak < 0,
        "Audio level validation contract is invalid",
    )
    require(editing.get("kind") == "hard_cuts_from_one_continuous_actual_gameplay_recording", "Unsafe edit kind")
    for false_field in (
        "overlays",
        "drawn_text",
        "fabricated_ui",
        "compositing",
        "cropping",
        "scaling",
        "generated_gameplay_frames",
    ):
        require(editing.get(false_field) is False, f"Contract permits {false_field}")
    require(editing.get("speed_multiplier") == 1.0, "Contract permits speed changes")


def validate_generated_audio_catalog(catalog_path: Path) -> dict[str, Any]:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    require(catalog.get("schema_version") == 1, "Generated audio catalog schema changed")
    require(catalog.get("asset_version") == "infinidive-audio-v1", "Generated audio catalog version changed")
    generator = catalog.get("generator")
    require(isinstance(generator, dict), "Generated audio catalog has no generator provenance")
    generator_sources = (
        ("path", "sha256"),
        ("synthesis_path", "synthesis_sha256"),
        ("definitions_path", "definitions_sha256"),
    )
    verified_generator_sources: list[dict[str, str]] = []
    for path_key, hash_key in generator_sources:
        resource_path = generator.get(path_key)
        require(isinstance(resource_path, str) and resource_path.startswith("res://"), "Generated audio source path is invalid")
        repository_path = safe_repository_path(f"infinidive-game/{resource_path.removeprefix('res://')}", "Generated audio source")
        expected_hash = require_sha256(generator.get(hash_key), f"Generated audio source hash for {resource_path}")
        require(sha256_file(repository_path) == expected_hash, f"Generated audio source changed: {resource_path}")
        verified_generator_sources.append({"resource": resource_path, "sha256": expected_hash})

    assets = catalog.get("assets")
    require(isinstance(assets, list) and len(assets) >= 1, "Generated audio catalog has no assets")
    prior_path = ""
    total_bytes = 0
    seen: set[str] = set()
    for entry in assets:
        require(isinstance(entry, dict), "Generated audio catalog asset entry is invalid")
        resource_path = entry.get("path")
        require(
            isinstance(resource_path, str) and resource_path.startswith("res://assets/audio/generated/")
            and resource_path not in seen and resource_path > prior_path,
            "Generated audio catalog assets are unsafe, duplicated, or unsorted",
        )
        seen.add(resource_path)
        prior_path = resource_path
        repository_path = safe_repository_path(f"infinidive-game/{resource_path.removeprefix('res://')}", "Generated audio asset")
        expected_hash = require_sha256(entry.get("sha256"), f"Generated audio asset hash for {resource_path}")
        byte_count = repository_path.stat().st_size
        require(entry.get("bytes") == byte_count, f"Generated audio asset byte count changed: {resource_path}")
        require(sha256_file(repository_path) == expected_hash, f"Generated audio asset changed: {resource_path}")
        total_bytes += byte_count
    require(catalog.get("total_resource_bytes") == total_bytes, "Generated audio catalog total byte count is false")
    require(catalog.get("counts", {}).get("total") == len(assets), "Generated audio catalog count is false")
    return {
        "asset_count": len(assets),
        "total_resource_bytes": total_bytes,
        "generator_sources": verified_generator_sources,
    }


def validate_contract_audio_sources(contract: dict[str, Any]) -> dict[str, Any]:
    audio = contract["audio"]
    source_asset = audio["source_asset"]
    source_path = safe_repository_path(source_asset.get("repository_file"), "Audio source asset")
    source_hash = require_sha256(source_asset.get("sha256"), "Audio source hash")
    require(source_path.stat().st_size == source_asset["bytes"], "Contract audio source byte count mismatch")
    require(sha256_file(source_path) == source_hash, "Contract audio source hash mismatch")
    catalog_evidence: dict[str, Any] | None = None
    verified_sources: list[dict[str, str]] = []
    for source in audio["provenance"]["source_files"]:
        repository_path = safe_repository_path(source.get("repository_file"), "Audio provenance source")
        expected_hash = require_sha256(source.get("sha256"), f"Audio provenance hash for {repository_path.name}")
        require(sha256_file(repository_path) == expected_hash, f"Audio provenance source changed: {repository_path}")
        verified_sources.append({"repository_file": source["repository_file"], "sha256": expected_hash})
        if source["repository_file"] == "infinidive-game/assets/audio/generated/manifest.json":
            catalog_evidence = validate_generated_audio_catalog(repository_path)
    require(catalog_evidence is not None, "Audio provenance does not bind the generated-audio catalog")
    return {
        "source_file": source_asset["repository_file"],
        "sha256": source_hash,
        "bytes": source_path.stat().st_size,
        "source_files": verified_sources,
        "generated_catalog": catalog_evidence,
    }


def validate_audio_provenance(
    manifest: dict[str, Any],
    contract: dict[str, Any],
    evidence_dir: Path,
    ffmpeg_bin: str,
    ffprobe_bin: str,
) -> dict[str, Any]:
    audio_contract = contract["audio"]
    source_contract = audio_contract["source_asset"]
    manifest_audio = manifest.get("audio", {})
    require(manifest_audio.get("track_count") == audio_contract["track_count"], "Manifest audio-track count changed")
    require(manifest_audio.get("provenance") == audio_contract["provenance"], "Manifest audio provenance differs from the contract")
    manifest_source = manifest_audio.get("source_asset", {})
    for field in ("repository_file", "evidence_file", "sha256", "bytes", "codec", "sample_rate", "channels", "duration_seconds"):
        require(manifest_source.get(field) == source_contract.get(field), f"Manifest audio source changed {field}")

    repository_source = safe_repository_path(source_contract.get("repository_file"), "Audio source asset")
    evidence_source = safe_artifact_path(evidence_dir, source_contract.get("evidence_file"), {".wav"}, "Audio evidence")
    expected_hash = require_sha256(source_contract.get("sha256"), "Audio source hash")
    for candidate in (repository_source, evidence_source):
        require(candidate.stat().st_size == source_contract["bytes"], f"Audio source byte count changed: {candidate}")
        require(sha256_file(candidate) == expected_hash, f"Audio source SHA-256 mismatch: {candidate}")

    probe = ffprobe(evidence_source, ffprobe_bin)
    source_audio_streams = audio_streams(probe)
    require(len(source_audio_streams) == 1 and len(probe.get("streams", [])) == 1, "Audio evidence is not exactly one audio-only stream")
    source_stream = source_audio_streams[0]
    duration = float(probe["format"]["duration"])
    require("wav" in str(probe["format"].get("format_name", "")).split(","), "Audio evidence is not WAV")
    require(source_stream.get("codec_name") == source_contract["codec"], "Audio evidence codec changed")
    require(source_stream.get("sample_fmt") == "s16", "Audio evidence is not signed 16-bit PCM")
    require(int(source_stream.get("sample_rate", -1)) == source_contract["sample_rate"], "Audio evidence sample rate changed")
    require(source_stream.get("channels") == source_contract["channels"], "Audio evidence channel count changed")
    require(abs(duration - source_contract["duration_seconds"]) <= 0.001, "Audio evidence duration changed")
    levels = audio_levels(evidence_source, ffmpeg_bin)
    assert_audio_levels(levels, audio_contract["validation"], "Audio source evidence")
    require(abs(float(manifest_source.get("mean_volume_dbfs", -999)) - levels["mean_volume_dbfs"]) <= 0.11, "Manifest source mean level is false")
    require(abs(float(manifest_source.get("peak_volume_dbfs", -999)) - levels["peak_volume_dbfs"]) <= 0.11, "Manifest source peak level is false")

    contract_sources = validate_contract_audio_sources(contract)
    return {
        "source_file": evidence_source.name,
        "sha256": expected_hash,
        "bytes": evidence_source.stat().st_size,
        "duration_seconds": duration,
        "codec": source_stream["codec_name"],
        "sample_rate": int(source_stream["sample_rate"]),
        "channels": source_stream["channels"],
        "levels": levels,
        "source_files": contract_sources["source_files"],
        "generated_catalog": contract_sources["generated_catalog"],
        "browser_captured": False,
        "event_synchronized": False,
    }


def validate_source_binding(
    manifest: dict[str, Any],
    commit: str,
    repository: str,
    run_id: int,
    run_attempt: int,
    target_url: str,
) -> dict[str, Any]:
    require(bool(commit) and all(character in "0123456789abcdef" for character in commit) and len(commit) in range(40, 65), "Invalid expected commit")
    require(repository.count("/") == 1 and all(part for part in repository.split("/")), "Invalid expected repository")
    require(run_id >= 1 and run_attempt >= 1, "Invalid expected workflow identity")
    expected = {
        "status": "bound",
        "commit": commit,
        "repository": repository,
        "run_id": run_id,
        "run_attempt": run_attempt,
        "target_url": canonical_url(target_url),
        "qa_url": canonical_url(target_url, qa=True),
    }
    observed = manifest.get("source_binding")
    require(observed == expected, f"Manifest source binding mismatch: expected {expected!r}, got {observed!r}")
    return expected


def validate_semantics(manifest: dict[str, Any], contract: dict[str, Any]) -> dict[str, Any]:
    expected_milestones = contract["semantic_flow"]["milestones"]
    observed_milestones = manifest.get("capture", {}).get("milestones")
    require(isinstance(observed_milestones, list), "Manifest has no semantic milestones")
    require(
        [item.get("key") for item in observed_milestones]
        == [item.get("key") for item in expected_milestones],
        "Semantic milestone keys or order differ from the capture contract",
    )
    previous_time = -1.0
    previous_revision = -1
    run_generation: int | None = None
    for observed, expected in zip(observed_milestones, expected_milestones, strict=True):
        capture_seconds = observed.get("capture_seconds")
        qa = observed.get("qa")
        require(isinstance(capture_seconds, (int, float)) and math.isfinite(capture_seconds), "Invalid milestone time")
        require(capture_seconds > previous_time, "Milestone times are not strictly increasing")
        require(isinstance(qa, dict) and qa.get("schema") == "infinidive.qa.v2" and qa.get("view") == "run", "Invalid milestone QA envelope")
        require(isinstance(qa.get("revision"), int) and qa["revision"] > previous_revision, "QA revisions are not monotonic")
        require(isinstance(qa.get("run_generation"), int), "Milestone has no run generation")
        if run_generation is None:
            run_generation = qa["run_generation"]
        require(qa["run_generation"] == run_generation, "Trailer milestones span more than one run")
        for field, expected_value in expected["required_qa"].items():
            observed_value = value_at_path(qa, field)
            require(
                observed_value == expected_value,
                f"Milestone {observed['key']} QA {field} expected {expected_value!r}, got {observed_value!r}",
            )
        previous_time = float(capture_seconds)
        previous_revision = qa["revision"]
    core_states = [
        item["qa"]["state"]
        for item in observed_milestones
        if item["key"] != "exterior_combat"
    ]
    expected_states = contract["semantic_flow"]["expected_states"]
    require(core_states == expected_states, f"Semantic path mismatch: {core_states!r}")
    require(manifest["capture"].get("observed_states") == expected_states, "Manifest observed-state summary is false")
    return {
        "milestone_count": len(observed_milestones),
        "run_generation": run_generation,
        "observed_states": core_states,
    }


def validate_edit(manifest: dict[str, Any], contract: dict[str, Any], raw_duration: float) -> dict[str, Any]:
    editing = manifest.get("editing", {})
    require(editing.get("kind") == contract["editing"]["kind"], "Manifest edit kind changed")
    required_truth = {
        "one_continuous_source": True,
        "speed_multiplier": 1.0,
        "hard_cuts_only": True,
        "overlays": False,
        "drawn_text": False,
        "fabricated_ui": False,
        "compositing": False,
        "cropping": False,
        "scaling": False,
        "generated_gameplay_frames": False,
    }
    for field, expected in required_truth.items():
        require(editing.get(field) == expected, f"Manifest editing.{field} is not truthful")
    milestones = {item["key"]: float(item["capture_seconds"]) for item in manifest["capture"]["milestones"]}
    segments = editing.get("segments")
    expected_segments = contract["editing"]["ordered_segments"]
    require(isinstance(segments, list) and len(segments) == len(expected_segments), "Edit segment count differs")
    total = 0.0
    for observed, expected in zip(segments, expected_segments, strict=True):
        for field in ("key", "start_anchor", "end_anchor", "start_offset_seconds", "end_offset_seconds"):
            require(observed.get(field) == expected.get(field), f"Segment {expected['key']} changed {field}")
        calculated_start = milestones[expected["start_anchor"]] + expected["start_offset_seconds"]
        calculated_end = milestones[expected["end_anchor"]] + expected["end_offset_seconds"]
        require(abs(float(observed.get("start_seconds", -999)) - calculated_start) <= 0.002, f"Segment {expected['key']} start is unbound")
        require(abs(float(observed.get("end_seconds", -999)) - calculated_end) <= 0.002, f"Segment {expected['key']} end is unbound")
        require(calculated_start >= 0 and calculated_end > calculated_start, f"Segment {expected['key']} has invalid bounds")
        require(calculated_end <= raw_duration + 0.075, f"Segment {expected['key']} exceeds raw source")
        segment_duration = calculated_end - calculated_start
        require(abs(float(observed.get("duration_seconds", -999)) - segment_duration) <= 0.002, f"Segment {expected['key']} duration is false")
        total += segment_duration
    require(abs(float(editing.get("intended_duration_seconds", -999)) - total) <= 0.01, "Intended duration is false")
    return {"segment_count": len(segments), "intended_duration_seconds": total}


def validate_media(
    manifest: dict[str, Any],
    contract: dict[str, Any],
    evidence_dir: Path,
    contract_dir: Path,
    ffmpeg_bin: str,
    ffprobe_bin: str,
) -> dict[str, Any]:
    capture = manifest["capture"]
    deliverable = manifest.get("deliverable", {})
    require(capture.get("raw_file") == contract["capture"]["raw_file"], "Raw capture filename changed")
    expected_deliverable_names = {
        contract["deliverable"]["preferred_file"],
        str(Path(contract["deliverable"]["preferred_file"]).with_suffix(".webm")),
    }
    require(deliverable.get("file") in expected_deliverable_names, "Deliverable filename changed")
    raw_path = safe_artifact_path(evidence_dir, capture.get("raw_file"), {".webm"}, "Raw capture")
    deliverable_path = safe_artifact_path(evidence_dir, deliverable.get("file"), {".mp4", ".webm"}, "Deliverable")
    require(capture.get("raw_sha256") == sha256_file(raw_path), "Raw capture SHA-256 mismatch")
    require(capture.get("raw_bytes") == raw_path.stat().st_size, "Raw capture byte count mismatch")
    require(deliverable.get("sha256") == sha256_file(deliverable_path), "Deliverable SHA-256 mismatch")
    require(deliverable.get("bytes") == deliverable_path.stat().st_size, "Deliverable byte count mismatch")
    banned = set(contract["visual_validation"]["banned_legacy_video_sha256"])
    require(sha256_file(raw_path) not in banned, "Raw capture is a banned legacy trailer")
    require(sha256_file(deliverable_path) not in banned, "Deliverable is a banned legacy trailer")

    raw_probe = ffprobe(raw_path, ffprobe_bin)
    raw_video = video_stream(raw_probe)
    require(len(audio_streams(raw_probe)) == 0, "Raw browser canvas evidence unexpectedly contains audio")
    require(capture.get("raw_audio_tracks") == 0, "Manifest raw-audio count is false")
    raw_duration = float(raw_probe["format"]["duration"])
    require(raw_video.get("width") == contract["capture"]["viewport_width"], "Raw capture width mismatch")
    require(raw_video.get("height") == contract["capture"]["viewport_height"], "Raw capture height mismatch")
    require(raw_duration > contract["deliverable"]["maximum_duration_seconds"], "Raw source is not a meaningful continuous session")

    probe = ffprobe(deliverable_path, ffprobe_bin)
    media_contract_evidence = assert_deliverable_probe(
        probe, deliverable, contract["deliverable"], contract["audio"], deliverable_path.suffix.lower()
    )
    stream = media_contract_evidence["stream"]
    audio_stream = media_contract_evidence["audio_stream"]
    duration = media_contract_evidence["duration"]
    size = media_contract_evidence["size"]
    frame_rate = media_contract_evidence["frame_rate"]
    run([ffmpeg_bin, "-hide_banner", "-v", "error", "-i", str(deliverable_path), "-f", "null", "-"], "Full trailer decode")
    levels = audio_levels(deliverable_path, ffmpeg_bin)
    assert_audio_levels(levels, contract["audio"]["validation"], "Encoded trailer audio")
    declared_levels = deliverable.get("audio_levels", {})
    require(abs(float(declared_levels.get("mean_volume_dbfs", -999)) - levels["mean_volume_dbfs"]) <= 0.11, "Manifest encoded mean level is false")
    require(abs(float(declared_levels.get("peak_volume_dbfs", -999)) - levels["peak_volume_dbfs"]) <= 0.11, "Manifest encoded peak level is false")
    manifest_audio_mux = manifest.get("audio", {}).get("mux", {})
    require(manifest_audio_mux.get("timing") == contract["audio"]["mux"]["timing"], "Manifest audio trim policy changed")
    require(manifest_audio_mux.get("video_mode") == contract["audio"]["mux"]["video_mode"], "Manifest audio mux can alter gameplay video")
    require(manifest_audio_mux.get("encoded_codec") == audio_stream.get("codec_name"), "Manifest encoded audio codec is false")
    require(manifest_audio_mux.get("encoded_sample_rate") == int(audio_stream.get("sample_rate", -1)), "Manifest encoded audio sample rate is false")
    require(manifest_audio_mux.get("encoded_channels") == audio_stream.get("channels"), "Manifest encoded audio channels are false")
    require(abs(float(manifest_audio_mux.get("source_trim_end_seconds", -999)) - duration) <= 0.15, "Audio trim duration differs from the edited video")
    actual_video_packet_hash = video_packet_sha256(deliverable_path, ffmpeg_bin)
    video_integrity = manifest.get("editing", {}).get("video_integrity", {})
    before_mux_hash = require_sha256(video_integrity.get("packet_sha256_before_audio_mux"), "Pre-mux video packet hash")
    after_mux_hash = require_sha256(video_integrity.get("packet_sha256_after_audio_mux"), "Post-mux video packet hash")
    require(video_integrity.get("mux_video_mode") == contract["audio"]["mux"]["video_mode"], "Manifest video mux mode changed")
    require(video_integrity.get("identical_before_and_after_audio_mux") is True, "Manifest does not attest exact video packet preservation")
    require(before_mux_hash == after_mux_hash == actual_video_packet_hash, "Audio mux did not preserve the exact encoded gameplay video packets")

    visual_contract = contract["visual_validation"]
    sample_width = int(visual_contract["sample_width"])
    sample_height = int(visual_contract["sample_height"])
    frames = decode_sample_frames(
        deliverable_path,
        ffmpeg_bin,
        sample_width,
        sample_height,
        float(visual_contract["sample_interval_seconds"]),
    )
    metrics = analyse_frames(frames, float(visual_contract["bright_frame_luma"]))
    assert_visual_metrics(metrics, visual_contract)

    references: list[bytes] = []
    reference_evidence: list[dict[str, Any]] = []
    for reference in visual_contract["legacy_dark_still_references"]:
        reference_path = safe_artifact_path(contract_dir, reference.get("file"), {".png"}, "Legacy reference")
        digest = sha256_file(reference_path)
        require(digest == reference.get("sha256"), f"Legacy reference hash changed: {reference_path.name}")
        references.append(decode_reference_frame(reference_path, ffmpeg_bin, sample_width, sample_height))
        reference_evidence.append({"file": reference_path.name, "sha256": digest})
    nearest_legacy_distances = [
        min(normalized_frame_distance(frame, reference) for reference in references)
        for frame in frames
    ]
    median_legacy_distance = statistics.median(nearest_legacy_distances)
    require(
        median_legacy_distance >= visual_contract["minimum_legacy_reference_distance"],
        f"Trailer remains too close to legacy dark art: distance={median_legacy_distance:.6f}",
    )
    metrics["median_nearest_legacy_reference_distance"] = median_legacy_distance
    metrics["legacy_references"] = reference_evidence
    metrics.pop("frame_mean_lumas", None)
    metrics.pop("interframe_distances", None)
    return {
        "raw_file": raw_path.name,
        "raw_duration_seconds": raw_duration,
        "deliverable_file": deliverable_path.name,
        "duration_seconds": duration,
        "width": stream["width"],
        "height": stream["height"],
        "codec": stream["codec_name"],
        "video_packet_sha256": actual_video_packet_hash,
        "pixel_format": stream["pix_fmt"],
        "frame_rate": frame_rate,
        "audio_track_count": 1,
        "audio_codec": audio_stream["codec_name"],
        "audio_sample_rate": int(audio_stream["sample_rate"]),
        "audio_channels": audio_stream["channels"],
        "audio_levels": levels,
        "bytes": size,
        "visual_metrics": metrics,
    }


def validate(args: argparse.Namespace) -> dict[str, Any]:
    contract_path = args.contract.resolve()
    manifest_path = args.manifest.resolve()
    evidence_dir = args.evidence_dir.resolve()
    require(contract_path.is_file(), f"Contract is missing: {contract_path}")
    require(manifest_path.is_file(), f"Manifest is missing: {manifest_path}")
    require(evidence_dir.is_dir(), f"Evidence directory is missing: {evidence_dir}")
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    validate_contract(contract)
    require(manifest.get("schema_version") == EXPECTED_SCHEMA_VERSION, "Manifest schema is not version 2")
    require(manifest.get("status") == EXPECTED_CAPTURE_STATUS, "Capture did not finish successfully")
    require(manifest.get("classification") == EXPECTED_CLASSIFICATION, "Manifest classification changed")
    require(manifest.get("submission_ready_store_asset") is False, "Browser trailer claims store readiness")
    require(manifest.get("target_device_evidence") is False, "Browser trailer claims target-device evidence")
    require(manifest.get("contract") == {
        "id": contract["contract_id"],
        "file": contract_path.name,
        "sha256": sha256_file(contract_path),
    }, "Manifest is not bound to the exact static contract")
    capture = manifest.get("capture", {})
    require(
        capture.get("surface") == "live_godot_web_canvas_mediarecorder_in_headless_chrome",
        "Manifest capture surface is not the live Godot Web canvas",
    )
    required_capture_truth = {
        "qa_mode": True,
        "actual_gameplay": True,
        "generated_or_mocked_frames": False,
        "debug_state_injection": False,
        "save_manipulation": False,
        "browser_audio_captured": False,
        "browser_audio_disclosure": contract["capture"]["browser_audio_disclosure"],
        "viewport_width": contract["capture"]["viewport_width"],
        "viewport_height": contract["capture"]["viewport_height"],
        "device_scale_factor": 1,
        "has_touch": True,
        "is_mobile": True,
    }
    for field, expected in required_capture_truth.items():
        require(capture.get(field) == expected, f"Manifest capture.{field} is not contract-compliant")
    diagnostics = manifest.get("diagnostics", {})
    for category in ("console_errors", "page_errors", "page_crashes", "critical_request_failures"):
        require(diagnostics.get(category) == [], f"Runtime diagnostic category {category} is not empty")
    binding = validate_source_binding(
        manifest, args.commit, args.repository, args.run_id, args.run_attempt, args.target_url,
    )
    semantics = validate_semantics(manifest, contract)
    audio_provenance = validate_audio_provenance(
        manifest,
        contract,
        evidence_dir,
        args.ffmpeg,
        args.ffprobe,
    )
    media = validate_media(
        manifest,
        contract,
        evidence_dir,
        contract_path.parent,
        args.ffmpeg,
        args.ffprobe,
    )
    editing = validate_edit(manifest, contract, media["raw_duration_seconds"])
    require(
        abs(media["duration_seconds"] - editing["intended_duration_seconds"]) <= 0.15,
        "Encoded duration differs materially from the source-bound edit decision list",
    )
    return {
        "schema_version": EXPECTED_SCHEMA_VERSION,
        "status": "passed",
        "classification": EXPECTED_CLASSIFICATION,
        "submission_ready_store_asset": False,
        "target_device_evidence": False,
        "source_binding": binding,
        "contract_sha256": sha256_file(contract_path),
        "manifest_sha256": sha256_file(manifest_path),
        "semantic_validation": semantics,
        "editing_validation": editing,
        "audio_provenance_validation": audio_provenance,
        "media_validation": media,
        "limitations": [
            "This is current-source browser gameplay, not native-iOS or physical-device capture.",
            "The project-original music bed is an offline mix, not live-captured or event-synchronous gameplay audio.",
            "Human audiovisual review remains required before any final store marketing claim.",
        ],
    }


def self_test() -> None:
    width = 12
    height = 18
    frames: list[bytes] = []
    for frame_index in range(9):
        pixels = bytearray()
        for y in range(height):
            for x in range(width):
                pixels.extend(
                    (
                        105 + ((x * 19 + frame_index * 31) % 145),
                        115 + ((y * 17 + frame_index * 23) % 135),
                        95 + (((x + y) * 13 + frame_index * 29) % 155),
                    )
                )
        frames.append(bytes(pixels))
    visual_contract = {
        "minimum_sample_count": 7,
        "minimum_unique_frame_fraction": 0.7,
        "minimum_median_luma": 80.0,
        "bright_frame_luma": 70.0,
        "minimum_bright_frame_fraction": 0.7,
        "minimum_frame_luma_deviation": 8.0,
        "minimum_mean_interframe_distance": 0.012,
    }
    passing_metrics = analyse_frames(frames, visual_contract["bright_frame_luma"])
    assert_visual_metrics(passing_metrics, visual_contract)
    static_metrics = analyse_frames([frames[0]] * 9, visual_contract["bright_frame_luma"])
    try:
        assert_visual_metrics(static_metrics, visual_contract)
    except ValidationError:
        pass
    else:
        raise AssertionError("Static duplicate frames passed nontrivial-frame validation")
    dark_frames = [bytes([3, 4, 5] * width * height) for _ in range(9)]
    try:
        assert_visual_metrics(analyse_frames(dark_frames, 70.0), visual_contract)
    except ValidationError:
        pass
    else:
        raise AssertionError("Dark frames passed bright-art validation")
    require(abs(parse_rate("30000/1001") - 29.97002997) < 1e-6, "Frame-rate parser self-test failed")
    require(
        canonical_url("https://user:secret@example.com/game/?old=1#private", qa=True)
        == "https://example.com/game/?infinidive_qa=1",
        "URL redaction self-test failed",
    )
    def expect_rejection(label: str, callback: Any) -> None:
        try:
            callback()
        except ValidationError:
            pass
        else:
            raise AssertionError(f"{label} passed validation")

    probe_contract = {
        "width": 886,
        "height": 1920,
        "minimum_duration_seconds": 15.0,
        "maximum_duration_seconds": 30.0,
        "maximum_frame_rate": 30.0,
        "maximum_bytes": 500_000_000,
        "accepted_profiles": [
            {"container": "mp4", "video_codec": "h264", "pixel_format": "yuv420p", "audio_codec": "aac"},
        ],
    }
    probe_audio_contract = {
        "track_count": 1,
        "mux": {"encoded_sample_rate": 48000, "encoded_channels": 2},
    }
    probe_manifest = {
        "container": "mp4",
        "video_codec": "h264",
        "audio_codec": "aac",
        "audio_tracks": 1,
    }
    good_probe = {
        "format": {"format_name": "mov,mp4,m4a,3gp,3g2,mj2", "duration": "22.000", "size": "123456"},
        "streams": [
            {
                "index": 0,
                "codec_type": "video",
                "codec_name": "h264",
                "width": 886,
                "height": 1920,
                "pix_fmt": "yuv420p",
                "avg_frame_rate": "30/1",
            },
            {
                "index": 1,
                "codec_type": "audio",
                "codec_name": "aac",
                "sample_rate": "48000",
                "channels": 2,
            },
        ],
    }
    assert_deliverable_probe(good_probe, probe_manifest, probe_contract, probe_audio_contract, ".mp4")
    for field, bad_value in (("width", 885), ("codec_name", "mpeg4")):
        bad_probe = json.loads(json.dumps(good_probe))
        bad_probe["streams"][0][field] = bad_value
        expect_rejection(
            f"Bad {field}",
            lambda probe=bad_probe: assert_deliverable_probe(
                probe, probe_manifest, probe_contract, probe_audio_contract, ".mp4"
            ),
        )
    bad_duration_probe = json.loads(json.dumps(good_probe))
    bad_duration_probe["format"]["duration"] = "12.000"
    expect_rejection(
        "Under-15-second trailer",
        lambda: assert_deliverable_probe(
            bad_duration_probe, probe_manifest, probe_contract, probe_audio_contract, ".mp4"
        ),
    )
    missing_audio_probe = json.loads(json.dumps(good_probe))
    missing_audio_probe["streams"] = missing_audio_probe["streams"][:1]
    expect_rejection(
        "Missing audio track",
        lambda: assert_deliverable_probe(
            missing_audio_probe, probe_manifest, probe_contract, probe_audio_contract, ".mp4"
        ),
    )
    extra_audio_probe = json.loads(json.dumps(good_probe))
    extra_audio_probe["streams"].append(dict(extra_audio_probe["streams"][1], index=2))
    expect_rejection(
        "Extra audio track",
        lambda: assert_deliverable_probe(
            extra_audio_probe, probe_manifest, probe_contract, probe_audio_contract, ".mp4"
        ),
    )
    wrong_codec_probe = json.loads(json.dumps(good_probe))
    wrong_codec_probe["streams"][1]["codec_name"] = "mp3"
    expect_rejection(
        "Wrong audio codec",
        lambda: assert_deliverable_probe(
            wrong_codec_probe, probe_manifest, probe_contract, probe_audio_contract, ".mp4"
        ),
    )
    wrong_manifest_audio = dict(probe_manifest, audio_tracks=0)
    expect_rejection(
        "False manifest audio-track count",
        lambda: assert_deliverable_probe(
            good_probe, wrong_manifest_audio, probe_contract, probe_audio_contract, ".mp4"
        ),
    )
    webm_contract = dict(
        probe_contract,
        accepted_profiles=[
            {"container": "webm", "video_codec": "vp9", "pixel_format": "yuv420p", "audio_codec": "opus"}
        ],
    )
    webm_manifest = {"container": "webm", "video_codec": "vp9", "audio_codec": "opus", "audio_tracks": 1}
    webm_probe = json.loads(json.dumps(good_probe))
    webm_probe["format"]["format_name"] = "matroska,webm"
    webm_probe["streams"][0]["codec_name"] = "vp9"
    webm_probe["streams"][1]["codec_name"] = "opus"
    assert_deliverable_probe(webm_probe, webm_manifest, webm_contract, probe_audio_contract, ".webm")
    wrong_pair_probe = json.loads(json.dumps(webm_probe))
    wrong_pair_probe["streams"][1]["codec_name"] = "aac"
    expect_rejection(
        "AAC in WebM",
        lambda: assert_deliverable_probe(
            wrong_pair_probe, webm_manifest, webm_contract, probe_audio_contract, ".webm"
        ),
    )
    level_contract = {
        "minimum_mean_volume_dbfs": -45.0,
        "minimum_peak_volume_dbfs": -30.0,
        "maximum_peak_volume_dbfs": -0.1,
    }
    assert_audio_levels({"mean_volume_dbfs": -20.3, "peak_volume_dbfs": -9.0}, level_contract, "Audible fixture")
    expect_rejection(
        "Silent audio",
        lambda: assert_audio_levels(
            {"mean_volume_dbfs": -math.inf, "peak_volume_dbfs": -math.inf}, level_contract, "Silent fixture"
        ),
    )
    contract_path = REPOSITORY_ROOT / "infinidive-game/assets/store/gameplay/bright-trailer-capture-contract.json"
    static_contract = json.loads(contract_path.read_text(encoding="utf-8"))
    validate_contract(static_contract)
    source_evidence = validate_contract_audio_sources(static_contract)
    tampered_contract = json.loads(json.dumps(static_contract))
    tampered_contract["audio"]["source_asset"]["sha256"] = "0" * 64
    expect_rejection("Tampered audio source hash", lambda: validate_contract_audio_sources(tampered_contract))
    tampered_provenance = json.loads(json.dumps(static_contract))
    tampered_provenance["audio"]["provenance"]["source_files"][0]["sha256"] = "f" * 64
    expect_rejection("Tampered renderer source hash", lambda: validate_contract_audio_sources(tampered_provenance))
    sys.stdout.write(
        "BRIGHT_TRAILER_VALIDATOR_SELF_TEST_OK "
        f"audio_sha256={source_evidence['sha256']} generated_assets={source_evidence['generated_catalog']['asset_count']}\n"
    )


def audio_reproducibility_test(args: argparse.Namespace) -> None:
    contract_path = (
        args.contract.resolve()
        if args.contract is not None
        else REPOSITORY_ROOT / "infinidive-game/assets/store/gameplay/bright-trailer-capture-contract.json"
    )
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    validate_contract(contract)
    source_evidence = validate_contract_audio_sources(contract)
    project_root = REPOSITORY_ROOT / "infinidive-game"
    renderer_scene = contract["audio"]["provenance"].get("renderer_scene")
    require(isinstance(renderer_scene, str) and renderer_scene.startswith("res://"), "Audio renderer scene is invalid")
    renderer_path = project_root / renderer_scene.removeprefix("res://")
    require(renderer_path.is_file(), "Audio renderer scene is missing")
    with tempfile.TemporaryDirectory(prefix="infinidive-bright-audio-repro-") as temporary_directory:
        output_paths = [Path(temporary_directory) / "first.wav", Path(temporary_directory) / "second.wav"]
        for output_path in output_paths:
            completed = subprocess.run(
                [
                    args.godot,
                    "--headless",
                    "--path",
                    str(project_root),
                    "--scene",
                    renderer_scene,
                    "--",
                    str(output_path),
                ],
                check=False,
                capture_output=True,
                timeout=120,
            )
            diagnostics = (completed.stdout + completed.stderr).decode("utf-8", "replace")
            require(completed.returncode == 0, f"Audio renderer failed ({completed.returncode}): {diagnostics[-4000:]}")
            require("BRIGHT_TRAILER_AUDIO_OK" in diagnostics, "Audio renderer did not report its success sentinel")
            require(output_path.is_file(), "Audio renderer did not create its WAV")
        hashes = [sha256_file(output_path) for output_path in output_paths]
        sizes = [output_path.stat().st_size for output_path in output_paths]
        require(hashes[0] == hashes[1] == source_evidence["sha256"], "Repeated audio renders are not byte-reproducible")
        require(sizes[0] == sizes[1] == source_evidence["bytes"], "Repeated audio renders differ in size")
        probe = ffprobe(output_paths[0], args.ffprobe)
        rendered_streams = audio_streams(probe)
        source_contract = contract["audio"]["source_asset"]
        require(len(rendered_streams) == 1 and len(probe.get("streams", [])) == 1, "Re-rendered WAV is not audio-only")
        require(rendered_streams[0].get("codec_name") == source_contract["codec"], "Re-rendered WAV codec changed")
        require(int(rendered_streams[0].get("sample_rate", -1)) == source_contract["sample_rate"], "Re-rendered WAV sample rate changed")
        require(rendered_streams[0].get("channels") == source_contract["channels"], "Re-rendered WAV channel count changed")
        require(abs(float(probe["format"]["duration"]) - source_contract["duration_seconds"]) <= 0.001, "Re-rendered WAV duration changed")
        levels = audio_levels(output_paths[0], args.ffmpeg)
        assert_audio_levels(levels, contract["audio"]["validation"], "Re-rendered audio")
    sys.stdout.write(
        "BRIGHT_TRAILER_AUDIO_REPRODUCIBILITY_TEST_OK "
        f"sha256={source_evidence['sha256']} bytes={source_evidence['bytes']} "
        f"generated_assets={source_evidence['generated_catalog']['asset_count']}\n"
    )


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--self-test", action="store_true")
    result.add_argument("--audio-reproducibility-test", action="store_true")
    result.add_argument("--contract", type=Path)
    result.add_argument("--manifest", type=Path)
    result.add_argument("--evidence-dir", type=Path)
    result.add_argument("--commit", default=os.environ.get("INFINIDIVE_SOURCE_COMMIT") or os.environ.get("GITHUB_SHA", ""))
    result.add_argument("--repository", default=os.environ.get("INFINIDIVE_SOURCE_REPOSITORY") or os.environ.get("GITHUB_REPOSITORY", ""))
    result.add_argument("--run-id", type=int, default=int(os.environ.get("INFINIDIVE_SOURCE_RUN_ID") or os.environ.get("GITHUB_RUN_ID", "0")))
    result.add_argument("--run-attempt", type=int, default=int(os.environ.get("INFINIDIVE_SOURCE_RUN_ATTEMPT") or os.environ.get("GITHUB_RUN_ATTEMPT", "0")))
    result.add_argument("--target-url", default="")
    result.add_argument("--ffmpeg", default=os.environ.get("INFINIDIVE_FFMPEG_BIN", "ffmpeg"))
    result.add_argument("--ffprobe", default=os.environ.get("INFINIDIVE_FFPROBE_BIN", "ffprobe"))
    result.add_argument("--godot", default=os.environ.get("INFINIDIVE_GODOT_BIN", "godot"))
    result.add_argument("--report", type=Path)
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        if args.self_test:
            self_test()
            return 0
        if args.audio_reproducibility_test:
            audio_reproducibility_test(args)
            return 0
        for name in ("contract", "manifest", "evidence_dir"):
            require(getattr(args, name) is not None, f"--{name.replace('_', '-')} is required")
        require(bool(args.target_url), "--target-url is required")
        report = validate(args)
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(
                "w", encoding="utf-8", dir=args.report.parent, prefix=f".{args.report.name}.", delete=False
            ) as handle:
                json.dump(report, handle, indent=2, sort_keys=True)
                handle.write("\n")
                temporary_path = Path(handle.name)
            temporary_path.replace(args.report)
        sys.stdout.write(json.dumps({
            "status": "passed",
            "file": report["media_validation"]["deliverable_file"],
            "duration_seconds": report["media_validation"]["duration_seconds"],
            "source_commit": report["source_binding"]["commit"],
        }, sort_keys=True) + "\n")
        return 0
    except (ValidationError, OSError, ValueError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        sys.stderr.write(f"BRIGHT_TRAILER_VALIDATION_FAILED: {error}\n")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
