#!/usr/bin/env python3
"""Validate source-bound, App-Store-sized screenshots from the live Web smoke."""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import tempfile
from typing import Any, Callable

import validate_ios_simulator_screenshot as png_validation


REPOSITORY_ROOT = pathlib.Path(__file__).resolve().parents[2]
STATIC_MANIFEST = (
    REPOSITORY_ROOT
    / "infinidive-game"
    / "assets"
    / "store"
    / "gameplay"
    / "capture-manifest.json"
)
EVIDENCE_MANIFEST = "infinidive-store-capture.json"
SMOKE_MANIFEST = "infinidive-browser.json"
CLASSIFICATION = (
    "current_source_ci_browser_app_store_sized_review_candidate_"
    "not_target_device_submission_evidence"
)
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40,64}$")
REPOSITORY_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
SAFE_FILE_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+$")


class StoreCaptureError(RuntimeError):
    """The screenshot set is malformed, unbound, incomplete, or visually invalid."""


def _fail(message: str) -> None:
    raise StoreCaptureError(message)


def _object(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(f"{label} must be an object")
    return value


def _exact_keys(value: dict[str, Any], expected: set[str], label: str) -> None:
    actual = set(_object(value, label))
    if actual != expected:
        _fail(
            f"{label} keys differ from the contract: "
            f"expected={sorted(expected)!r}, actual={sorted(actual)!r}"
        )


def _read_json(path: pathlib.Path, label: str) -> dict[str, Any]:
    if path.is_symlink() or not path.is_file():
        _fail(f"{label} must be a regular non-symlink file: {path}")
    try:
        return _object(json.loads(path.read_text(encoding="utf-8")), label)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        _fail(f"cannot read {label} {path}: {exc}")


def _safe_file_name(value: Any, label: str) -> str:
    if (
        not isinstance(value, str)
        or not SAFE_FILE_PATTERN.fullmatch(value)
        or pathlib.Path(value).name != value
        or "/" in value
        or "\\" in value
    ):
        _fail(f"{label} is not a safe plain file name")
    return value


def _positive_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        _fail(f"{label} must be a positive integer")
    return value


def _nested(value: dict[str, Any], dotted_path: str) -> Any:
    cursor: Any = value
    for segment in dotted_path.split("."):
        if not isinstance(cursor, dict) or segment not in cursor:
            return None
        cursor = cursor[segment]
    return cursor


def load_contract(path: pathlib.Path = STATIC_MANIFEST) -> dict[str, Any]:
    root = _read_json(path, "static capture manifest")
    contract = _object(
        _object(root.get("planned_capture"), "planned_capture").get(
            "ci_store_sized_screenshots"
        ),
        "planned_capture.ci_store_sized_screenshots",
    )
    if contract.get("schema_version") != 1:
        _fail("store capture contract schema_version must be 1")
    if contract.get("classification") != CLASSIFICATION:
        _fail("store capture contract classification is missing or unsafe")
    if contract.get("evidence_manifest") != EVIDENCE_MANIFEST:
        _fail(f"store capture evidence_manifest must be {EVIDENCE_MANIFEST}")
    if contract.get("smoke_manifest") != SMOKE_MANIFEST:
        _fail(f"store capture smoke_manifest must be {SMOKE_MANIFEST}")
    expected_image = _object(contract.get("expected_image"), "expected_image")
    if expected_image != {
        "format": "PNG",
        "width": 1320,
        "height": 2868,
        "device_scale_factor": 1,
        "capture_surface": (
            "Headless CI Chrome viewport rendering the live Godot Web export at 1320x2868"
        ),
        "post_capture_scaling": False,
    }:
        _fail("store capture expected_image contract is not the exact 1320x2868 PNG profile")
    stages = contract.get("ordered_stages")
    if not isinstance(stages, list) or not stages:
        _fail("ordered_stages must be a non-empty array")
    orders: set[int] = set()
    keys: set[str] = set()
    sources: set[str] = set()
    files: set[str] = set()
    for index, raw_stage in enumerate(stages, start=1):
        stage = _object(raw_stage, f"ordered_stages[{index - 1}]")
        _exact_keys(
            stage,
            {
                "order",
                "key",
                "source_stage",
                "snapshot_key",
                "file",
                "caption",
                "required_qa",
            },
            f"ordered_stages[{index - 1}]",
        )
        order = _positive_int(stage.get("order"), f"ordered_stages[{index - 1}].order")
        key = stage.get("key")
        source = stage.get("source_stage")
        snapshot = stage.get("snapshot_key")
        file_name = _safe_file_name(stage.get("file"), f"ordered_stages[{index - 1}].file")
        caption = stage.get("caption")
        required_qa = _object(stage.get("required_qa"), f"ordered_stages[{index - 1}].required_qa")
        if order != index or order in orders:
            _fail("ordered_stages must use unique contiguous order values starting at one")
        if not isinstance(key, str) or not re.fullmatch(r"[a-z0-9-]+", key) or key in keys:
            _fail(f"invalid or duplicate store stage key: {key!r}")
        if (
            not isinstance(source, str)
            or not re.fullmatch(r"[a-z0-9_-]+", source)
            or source in sources
        ):
            _fail(f"invalid or duplicate source_stage: {source!r}")
        if not isinstance(snapshot, str) or not re.fullmatch(r"[a-z0-9_]+", snapshot):
            _fail(f"invalid snapshot_key: {snapshot!r}")
        if file_name in files or not file_name.endswith(".png"):
            _fail(f"invalid or duplicate stage file: {file_name!r}")
        if not isinstance(caption, str) or not caption.strip():
            _fail(f"stage {key!r} must have a non-empty caption")
        if not required_qa:
            _fail(f"stage {key!r} must have at least one QA-state requirement")
        orders.add(order)
        keys.add(key)
        sources.add(source)
        files.add(file_name)
    return contract


def _validate_source_binding(
    source: dict[str, Any],
    expected_commit: str,
    expected_repository: str,
    expected_run_id: int,
    expected_run_attempt: int,
) -> None:
    _exact_keys(
        source,
        {"status", "commit", "repository", "run_id", "run_attempt", "target_url", "qa_url"},
        "source_binding",
    )
    if source.get("status") != "bound":
        _fail("source_binding.status must be bound")
    commit = source.get("commit")
    repository = source.get("repository")
    if not isinstance(commit, str) or not COMMIT_PATTERN.fullmatch(commit):
        _fail("source_binding.commit is not a full hexadecimal source revision")
    if not isinstance(repository, str) or not REPOSITORY_PATTERN.fullmatch(repository):
        _fail("source_binding.repository is invalid")
    if commit != expected_commit:
        _fail(f"source commit mismatch: expected {expected_commit}, got {commit}")
    if repository != expected_repository:
        _fail(f"source repository mismatch: expected {expected_repository}, got {repository}")
    if source.get("run_id") != expected_run_id:
        _fail(
            f"source run ID mismatch: expected {expected_run_id}, got {source.get('run_id')!r}"
        )
    if source.get("run_attempt") != expected_run_attempt:
        _fail(
            "source run attempt mismatch: "
            f"expected {expected_run_attempt}, got {source.get('run_attempt')!r}"
        )
    target_url = source.get("target_url")
    qa_url = source.get("qa_url")
    if (
        not isinstance(target_url, str)
        or not target_url.startswith(("http://", "https://"))
        or not isinstance(qa_url, str)
        or "infinidive_qa=1" not in qa_url
        or "@" in target_url.split("//", 1)[-1].split("/", 1)[0]
        or "@" in qa_url.split("//", 1)[-1].split("/", 1)[0]
    ):
        _fail("source URLs are missing, unredacted, or not bound to QA mode")


def validate(
    evidence_directory: pathlib.Path,
    *,
    expected_commit: str,
    expected_repository: str,
    expected_run_id: int,
    expected_run_attempt: int,
    contract: dict[str, Any] | None = None,
    pixel_validator: Callable[[pathlib.Path], dict[str, float | int]] = png_validation.validate,
) -> dict[str, Any]:
    if evidence_directory.is_symlink() or not evidence_directory.is_dir():
        _fail(f"evidence directory must be a real directory: {evidence_directory}")
    contract = contract or load_contract()
    manifest = _read_json(evidence_directory / EVIDENCE_MANIFEST, "store capture manifest")
    smoke = _read_json(evidence_directory / SMOKE_MANIFEST, "browser smoke manifest")
    _exact_keys(
        manifest,
        {
            "schema_version",
            "status",
            "classification",
            "submission_ready_store_asset",
            "target_device_evidence",
            "source_binding",
            "capture",
            "smoke_evidence_manifest",
            "smoke_report_status",
            "semantic_touch_status",
            "expected_stage_count",
            "captured_stage_count",
            "stages",
            "limitations",
        },
        "store capture manifest",
    )
    if manifest.get("schema_version") != 1 or manifest.get("status") != "passed":
        _fail("store capture manifest did not pass schema version 1")
    if manifest.get("classification") != CLASSIFICATION:
        _fail("store capture manifest classification is missing or unsafe")
    if manifest.get("submission_ready_store_asset") is not False:
        _fail("browser evidence must not claim submission-ready store status")
    if manifest.get("target_device_evidence") is not False:
        _fail("browser evidence must not claim target-device status")
    if manifest.get("smoke_evidence_manifest") != SMOKE_MANIFEST:
        _fail("store capture manifest points at an unexpected smoke manifest")
    if manifest.get("smoke_report_status") != "passed" or manifest.get("semantic_touch_status") != "passed":
        _fail("store capture manifest is not attached to a passed semantic smoke")
    if smoke.get("status") != "passed" or _object(smoke.get("semantic_touch"), "semantic_touch").get("status") != "passed":
        _fail("the retained browser smoke did not pass")
    source = _object(manifest.get("source_binding"), "source_binding")
    _validate_source_binding(
        source,
        expected_commit,
        expected_repository,
        expected_run_id,
        expected_run_attempt,
    )
    smoke_store = _object(smoke.get("store_capture"), "browser smoke store_capture")
    if (
        smoke_store.get("status") != "passed"
        or smoke_store.get("manifest") != EVIDENCE_MANIFEST
        or smoke_store.get("classification") != CLASSIFICATION
        or smoke_store.get("source_binding") != source
    ):
        _fail("browser smoke and store-capture source bindings differ")

    capture = _object(manifest.get("capture"), "capture")
    _exact_keys(
        capture,
        {
            "surface",
            "qa_mode",
            "actual_gameplay",
            "generated_or_mocked_frames",
            "post_capture_scaling",
            "compositing",
            "viewport_width",
            "viewport_height",
            "device_scale_factor",
        },
        "capture",
    )
    if capture != {
        "surface": "live_godot_web_export_in_headless_chrome",
        "qa_mode": True,
        "actual_gameplay": True,
        "generated_or_mocked_frames": False,
        "post_capture_scaling": False,
        "compositing": False,
        "viewport_width": 1320,
        "viewport_height": 2868,
        "device_scale_factor": 1,
    }:
        _fail("capture provenance does not describe an unscaled live 1320x2868 Godot frame")

    expected_stages = contract["ordered_stages"]
    stages = manifest.get("stages")
    if not isinstance(stages, list) or len(stages) != len(expected_stages):
        _fail("store capture stage count differs from the static contract")
    if manifest.get("expected_stage_count") != len(expected_stages):
        _fail("expected_stage_count differs from the static contract")
    if manifest.get("captured_stage_count") != len(expected_stages):
        _fail("captured_stage_count differs from the static contract")
    if smoke_store.get("expected_stage_count") != len(expected_stages):
        _fail("browser smoke expected_stage_count differs from the static contract")
    if smoke_store.get("captured_stage_count") != len(expected_stages):
        _fail("browser smoke captured_stage_count differs from the static contract")

    observed_hashes: set[str] = set()
    validated: list[dict[str, Any]] = []
    stage_keys = {
        "order",
        "key",
        "source_stage",
        "snapshot_key",
        "file",
        "caption",
        "sha256",
        "bytes",
        "width",
        "height",
        "device_scale_factor",
        "post_capture_scaling",
        "qa",
    }
    qa_keys = {
        "schema",
        "view",
        "state",
        "revision",
        "run_generation",
        "phase",
        "movement_observed",
        "organ",
        "ability",
        "boss_visual_state",
        "mutation",
    }
    smoke_stages = smoke_store.get("stages")
    if not isinstance(smoke_stages, list) or len(smoke_stages) != len(expected_stages):
        _fail("browser smoke does not retain every store stage")
    smoke_by_key = {
        stage.get("key"): stage for stage in smoke_stages if isinstance(stage, dict)
    }
    for index, (raw_stage, expected) in enumerate(zip(stages, expected_stages, strict=True)):
        stage = _object(raw_stage, f"stages[{index}]")
        _exact_keys(stage, stage_keys, f"stages[{index}]")
        for field in ("order", "key", "source_stage", "snapshot_key", "file", "caption"):
            if stage.get(field) != expected.get(field):
                _fail(
                    f"stages[{index}].{field} differs from the static contract: "
                    f"expected {expected.get(field)!r}, got {stage.get(field)!r}"
                )
        file_name = _safe_file_name(stage.get("file"), f"stages[{index}].file")
        digest = stage.get("sha256")
        if not isinstance(digest, str) or not SHA256_PATTERN.fullmatch(digest):
            _fail(f"stages[{index}].sha256 is invalid")
        if digest in observed_hashes:
            _fail(f"stage screenshot digest is duplicated: {digest}")
        image_path = evidence_directory / file_name
        if image_path.is_symlink() or not image_path.is_file():
            _fail(f"stage screenshot must be a regular non-symlink file: {image_path}")
        payload = image_path.read_bytes()
        actual_digest = hashlib.sha256(payload).hexdigest()
        if actual_digest != digest:
            _fail(
                f"stage {stage.get('key')} SHA-256 mismatch: expected {digest}, got {actual_digest}"
            )
        if stage.get("bytes") != len(payload) or len(payload) < 1024:
            _fail(f"stage {stage.get('key')} byte count is invalid")
        if (
            stage.get("width") != 1320
            or stage.get("height") != 2868
            or stage.get("device_scale_factor") != 1
            or stage.get("post_capture_scaling") is not False
        ):
            _fail(f"stage {stage.get('key')} does not declare an unscaled 1320x2868 frame")
        try:
            pixel_evidence = pixel_validator(image_path)
        except (png_validation.ScreenshotError, OSError, ValueError) as exc:
            _fail(f"stage {stage.get('key')} failed full pixel validation: {exc}")
        if pixel_evidence.get("width") != 1320 or pixel_evidence.get("height") != 2868:
            _fail(f"stage {stage.get('key')} pixel validator returned wrong dimensions")
        qa = _object(stage.get("qa"), f"stages[{index}].qa")
        _exact_keys(qa, qa_keys, f"stages[{index}].qa")
        if qa.get("schema") != "infinidive.qa.v2":
            _fail(f"stage {stage.get('key')} is not bound to the current QA schema")
        for field, expected_value in expected["required_qa"].items():
            actual_value = _nested(qa, field)
            if actual_value != expected_value:
                _fail(
                    f"stage {stage.get('key')} QA mismatch for {field}: "
                    f"expected {expected_value!r}, got {actual_value!r}"
                )
        if smoke_by_key.get(stage.get("key")) != stage:
            _fail(f"browser smoke and store manifest differ for stage {stage.get('key')}")
        observed_hashes.add(digest)
        validated.append(
            {
                "order": stage["order"],
                "key": stage["key"],
                "file": file_name,
                "sha256": digest,
                "pixel_evidence": pixel_evidence,
            }
        )

    limitations = manifest.get("limitations")
    if (
        not isinstance(limitations, list)
        or len(limitations) < 3
        or not all(isinstance(item, str) and item.strip() for item in limitations)
    ):
        _fail("store capture limitations are missing")
    return {
        "status": "passed",
        "classification": CLASSIFICATION,
        "submission_ready_store_asset": False,
        "target_device_evidence": False,
        "source_commit": expected_commit,
        "source_repository": expected_repository,
        "workflow_run_id": expected_run_id,
        "workflow_run_attempt": expected_run_attempt,
        "validated_stage_count": len(validated),
        "dimensions": [1320, 2868],
        "all_stage_hashes_unique": True,
        "stages": validated,
    }


def run_self_test() -> None:
    contract = load_contract()
    assert len(contract["ordered_stages"]) == 9
    assert [stage["order"] for stage in contract["ordered_stages"]] == list(range(1, 10))
    assert len({stage["file"] for stage in contract["ordered_stages"]}) == 9
    assert all(stage["required_qa"] for stage in contract["ordered_stages"])
    try:
        _safe_file_name("../escape.png", "fixture")
    except StoreCaptureError:
        pass
    else:
        raise AssertionError("path-traversal fixture was accepted")
    try:
        _validate_source_binding(
            {
                "status": "bound",
                "commit": "a" * 40,
                "repository": "owner/repo",
                "run_id": 12,
                "run_attempt": 1,
                "target_url": "https://example.test/infinidive/",
                "qa_url": "https://example.test/infinidive/?infinidive_qa=1",
            },
            "b" * 40,
            "owner/repo",
            12,
            1,
        )
    except StoreCaptureError:
        pass
    else:
        raise AssertionError("mismatched source commit fixture was accepted")
    with tempfile.TemporaryDirectory(prefix="infinidive-store-validator-") as root_text:
        root = pathlib.Path(root_text)
        source = {
            "status": "bound",
            "commit": "a" * 40,
            "repository": "owner/repo",
            "run_id": 12,
            "run_attempt": 1,
            "target_url": "https://example.test/infinidive/",
            "qa_url": "https://example.test/infinidive/?infinidive_qa=1",
        }
        stages: list[dict[str, Any]] = []
        for expected in contract["ordered_stages"]:
            qa: dict[str, Any] = {
                "schema": "infinidive.qa.v2",
                "view": None,
                "state": None,
                "revision": expected["order"],
                "run_generation": 0 if expected["key"] == "last-nest" else 1,
                "phase": None,
                "movement_observed": None,
                "organ": {"id": None, "status": None, "health_ratio": None},
                "ability": {"id": None, "status": None},
                "boss_visual_state": None,
                "mutation": {
                    "offered_count": None,
                    "selected_count": None,
                    "last_selected_id": None,
                },
            }
            for dotted_path, expected_value in expected["required_qa"].items():
                cursor = qa
                segments = dotted_path.split(".")
                for segment in segments[:-1]:
                    cursor = cursor.setdefault(segment, {})
                cursor[segments[-1]] = expected_value
            payload = (
                f"fixture-{expected['order']}-{expected['key']}-".encode("utf-8") * 80
            )
            assert len(payload) >= 1024
            (root / expected["file"]).write_bytes(payload)
            stages.append(
                {
                    "order": expected["order"],
                    "key": expected["key"],
                    "source_stage": expected["source_stage"],
                    "snapshot_key": expected["snapshot_key"],
                    "file": expected["file"],
                    "caption": expected["caption"],
                    "sha256": hashlib.sha256(payload).hexdigest(),
                    "bytes": len(payload),
                    "width": 1320,
                    "height": 2868,
                    "device_scale_factor": 1,
                    "post_capture_scaling": False,
                    "qa": qa,
                }
            )
        manifest = {
            "schema_version": 1,
            "status": "passed",
            "classification": CLASSIFICATION,
            "submission_ready_store_asset": False,
            "target_device_evidence": False,
            "source_binding": source,
            "capture": {
                "surface": "live_godot_web_export_in_headless_chrome",
                "qa_mode": True,
                "actual_gameplay": True,
                "generated_or_mocked_frames": False,
                "post_capture_scaling": False,
                "compositing": False,
                "viewport_width": 1320,
                "viewport_height": 2868,
                "device_scale_factor": 1,
            },
            "smoke_evidence_manifest": SMOKE_MANIFEST,
            "smoke_report_status": "passed",
            "semantic_touch_status": "passed",
            "expected_stage_count": len(stages),
            "captured_stage_count": len(stages),
            "stages": stages,
            "limitations": ["browser", "human review required", "not accepted by store"],
        }
        smoke = {
            "status": "passed",
            "semantic_touch": {"status": "passed"},
            "store_capture": {
                "status": "passed",
                "manifest": EVIDENCE_MANIFEST,
                "classification": CLASSIFICATION,
                "source_binding": source,
                "stages": list(reversed(stages)),
                "captured_stage_count": len(stages),
                "expected_stage_count": len(stages),
            },
        }
        (root / EVIDENCE_MANIFEST).write_text(
            json.dumps(manifest) + "\n", encoding="utf-8"
        )
        (root / SMOKE_MANIFEST).write_text(json.dumps(smoke) + "\n", encoding="utf-8")

        result = validate(
            root,
            expected_commit="a" * 40,
            expected_repository="owner/repo",
            expected_run_id=12,
            expected_run_attempt=1,
            contract=contract,
            pixel_validator=lambda _path: {
                "width": 1320,
                "height": 2868,
                "sample_count": 10_001,
                "non_black_ratio": 0.9,
                "luminance_range": 180,
                "quantized_colors": 128,
            },
        )
        assert result["validated_stage_count"] == 9
        manifest["source_binding"]["commit"] = "b" * 40
        (root / EVIDENCE_MANIFEST).write_text(
            json.dumps(manifest) + "\n", encoding="utf-8"
        )
        try:
            validate(
                root,
                expected_commit="a" * 40,
                expected_repository="owner/repo",
                expected_run_id=12,
                expected_run_attempt=1,
                contract=contract,
                pixel_validator=lambda _path: {"width": 1320, "height": 2868},
            )
        except StoreCaptureError:
            pass
        else:
            raise AssertionError("tampered manifest source binding was accepted")
    print(
        "store screenshot validator self-test: PASS "
        "(9-stage end-to-end structure, source mismatch rejection, path traversal rejection)"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("evidence_directory", nargs="?", type=pathlib.Path)
    parser.add_argument("--expected-commit")
    parser.add_argument("--expected-repository")
    parser.add_argument("--expected-run-id", type=int)
    parser.add_argument("--expected-run-attempt", type=int)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        if args.evidence_directory is not None:
            parser.error("--self-test cannot be combined with an evidence directory")
    else:
        missing = [
            name
            for name, value in (
                ("--expected-commit", args.expected_commit),
                ("--expected-repository", args.expected_repository),
                ("--expected-run-id", args.expected_run_id),
                ("--expected-run-attempt", args.expected_run_attempt),
            )
            if value is None
        ]
        if args.evidence_directory is None or missing:
            parser.error(
                "provide an evidence directory and all expected source-binding fields"
            )
        if not COMMIT_PATTERN.fullmatch(args.expected_commit):
            parser.error("--expected-commit must be a full lowercase hexadecimal revision")
        if not REPOSITORY_PATTERN.fullmatch(args.expected_repository):
            parser.error("--expected-repository must be owner/repository")
        if args.expected_run_id < 1 or args.expected_run_attempt < 1:
            parser.error("run ID and run attempt must be positive")
    try:
        if args.self_test:
            run_self_test()
        else:
            result = validate(
                args.evidence_directory.resolve(),
                expected_commit=args.expected_commit,
                expected_repository=args.expected_repository,
                expected_run_id=args.expected_run_id,
                expected_run_attempt=args.expected_run_attempt,
            )
            print(json.dumps(result, indent=2, sort_keys=True))
    except (StoreCaptureError, AssertionError, OSError, ValueError) as exc:
        print(f"store screenshot validation: FAIL: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
