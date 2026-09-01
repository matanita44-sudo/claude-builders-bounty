#!/usr/bin/env python3
import argparse
import copy
import hashlib
import json
import math
import pathlib
import re
import subprocess
import sys
import tempfile


EXPECTED_MODELS = {
    "linear",
    "delayed_linear",
    "soft_homing",
    "expanding",
    "node_link",
    "lunge",
    "recorded_path",
}
FINGERPRINT_PATTERN = re.compile(r"^[0-9a-f]{64}$")
TRANSACTION_PATTERN = re.compile(r"^[0-9a-f]{24}$")
MARKDOWN_HASH_PATTERN = re.compile(r"^[0-9a-f]{64}$")
PRODUCTION_FINGERPRINT_ROOTS = (
    "project.godot",
    "export_presets.cfg",
    "scripts",
    "data",
    "scenes",
    "assets",
    "web",
)
PRODUCTION_FINGERPRINT_EXCLUDED_PREFIXES = (
    "assets/store/gameplay/raw/",
)
TOP_LEVEL_FIELDS = {
    "schema",
    "report_transaction_id",
    "report_markdown_sha256",
    "report_transaction_complete",
    "passed",
    "requested_duration_seconds",
    "elapsed_wall_seconds",
    "seed",
    "started_at_utc",
    "finished_at_utc",
    "source_fingerprint_start",
    "source_fingerprint_end",
    "source_changed_during_run",
    "engine",
    "display_server",
    "scope",
    "counts",
    "peaks",
    "object_counts",
    "memory",
    "failures",
    "memory_samples",
}


def fail(message: str) -> None:
    print(f"Soak report validation error: {message}", file=sys.stderr)
    raise SystemExit(1)


def reject_json_constant(token: str) -> None:
    raise ValueError(f"non-finite JSON constant {token}")


def finite_number(value: object, label: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        fail(f"{label} must be an int or float, not bool")
    numeric = float(value)
    if not math.isfinite(numeric):
        fail(f"{label} must be finite")
    return numeric


def nonnegative_integer(value: object, label: str) -> int:
    if type(value) is not int or value < 0:
        fail(f"{label} must be a non-negative integer")
    return value


def model_map(value: object, label: str, require_positive: bool) -> dict[str, int]:
    if not isinstance(value, dict) or set(value) != EXPECTED_MODELS:
        keys = sorted(value) if isinstance(value, dict) else []
        fail(f"{label} must contain exactly the seven travel models; got {keys}")
    for model, count in value.items():
        if type(count) is not int or count < 0 or (require_positive and count == 0):
            qualifier = "positive" if require_positive else "non-negative"
            fail(f"{label}.{model} must be a {qualifier} integer")
    return value


def infer_project_root(report_path: pathlib.Path) -> pathlib.Path:
    artifacts_dir = report_path.resolve().parent
    if artifacts_dir.name != "artifacts":
        fail("report must be located directly under the project's artifacts directory")
    project_root = artifacts_dir.parent
    if not (project_root / "project.godot").is_file():
        fail("cannot infer a Godot project root containing project.godot from the report path")
    return project_root


def production_source_fingerprint(project_root: pathlib.Path) -> str:
    records: list[str] = []
    for relative_root in PRODUCTION_FINGERPRINT_ROOTS:
        source_root = project_root / relative_root
        if source_root.is_dir():
            for source_path in source_root.rglob("*"):
                if source_path.is_file() and not source_path.name.endswith(".uid"):
                    relative_path = source_path.relative_to(project_root).as_posix()
                    if relative_path.startswith(PRODUCTION_FINGERPRINT_EXCLUDED_PREFIXES):
                        continue
                    records.append(
                        f"res://{relative_path}:{hashlib.sha256(source_path.read_bytes()).hexdigest()}"
                    )
        elif source_root.is_file():
            records.append(
                f"res://{relative_root}:{hashlib.sha256(source_root.read_bytes()).hexdigest()}"
            )
    return hashlib.sha256("\n".join(sorted(records)).encode("utf-8")).hexdigest()


def self_test_report() -> dict[str, object]:
    model_counts = {model: 1 for model in EXPECTED_MODELS}
    return {
        "schema": 1,
        "passed": True,
        "failures": [],
        "requested_duration_seconds": 8.0,
        "elapsed_wall_seconds": 8.25,
        "seed": 203541,
        "started_at_utc": "2026-09-01T00:00:00Z",
        "finished_at_utc": "2026-09-01T00:00:08Z",
        "source_fingerprint_start": "a" * 64,
        "source_fingerprint_end": "a" * 64,
        "source_changed_during_run": False,
        "report_transaction_id": "b" * 24,
        "report_markdown_sha256": "0" * 64,
        "report_transaction_complete": True,
        "engine": {"string": "self-test"},
        "display_server": "headless",
        "scope": "validator self-test",
        "counts": {
            "iterations": 1,
            "boss_restarts": 1,
            "dive_transitions": 1,
            "projectile_cycles": 1,
            "projectile_model_steps": copy.deepcopy(model_counts),
            "projectile_models_requested": copy.deepcopy(model_counts),
            "projectile_models_executed": copy.deepcopy(model_counts),
            "player_projectiles_spawned": 1,
            "enemy_projectiles_spawned": 7,
            "save_writes": 1,
            "save_reloads": 0,
            "offline_events_queued": 1,
            "offline_queue_reloads": 1,
            "offline_queue_final_size": 0,
        },
        "peaks": {
            "player_projectiles": 0,
            "enemy_projectiles": 7,
            "total_projectiles": 7,
            "object_count": 1,
            "node_count": 1,
            "orphan_node_count": 0,
        },
        "object_counts": {
            "baseline_objects": 1,
            "baseline_nodes": 1,
            "final_objects": 1,
            "final_nodes": 1,
        },
        "memory": {
            "sample_count": 1,
            "stable_sample_count": 1,
            "warmup_seconds": 1.0,
            "start_bytes": 1,
            "stable_start_bytes": 1,
            "end_bytes": 1,
            "peak_bytes": 1,
            "stable_delta_bytes": 0,
            "slope_bytes_per_minute": 0.0,
        },
        "memory_samples": [
            {
                "elapsed_seconds": 8.25,
                "memory_bytes": 1,
                "object_count": 1,
                "node_count": 1,
                "orphan_node_count": 0,
            }
        ],
    }


def self_test_markdown(report: dict[str, object]) -> str:
    result = "PASS" if report["passed"] else "FAIL"
    changed = str(report["source_changed_during_run"]).lower()
    executed_coverage = sum(
        count > 0 for count in report["counts"]["projectile_models_executed"].values()
    )
    lines = [
        "# INFINIDIVE Headless Soak Report",
        "",
        f"- Result: **{result}**",
        f"- Report transaction: `{report['report_transaction_id']}`",
        f"- Requested wall time: `{report['requested_duration_seconds']:.2f} seconds`",
        f"- Actual wall time: `{report['elapsed_wall_seconds']:.2f} seconds`",
        f"- Seed: `{report['seed']}`",
        f"- Source fingerprint: `{report['source_fingerprint_start']}`",
        f"- Source changed during run: `{changed}`",
        f"| Projectile travel models exercised | {executed_coverage} / 7 |",
        f"| Failures | {len(report['failures'])} |",
    ]
    if report["failures"]:
        lines.extend(("", "## Failures", ""))
        lines.extend(f"- `{failure['code']}`: {failure['detail']}" for failure in report["failures"])
    return "\n".join(lines)


def run_self_tests() -> None:
    script = pathlib.Path(__file__).resolve()
    with tempfile.TemporaryDirectory(prefix="infinidive-soak-validator-") as directory:
        project_root = pathlib.Path(directory) / "mini-project"
        fixture_dir = project_root / "artifacts"
        source_path = project_root / "scripts" / "self_test.gd"
        fixture_dir.mkdir(parents=True)
        source_path.parent.mkdir(parents=True)
        (project_root / "project.godot").write_text("[application]\nconfig/name=\"soak-validator-self-test\"\n", encoding="utf-8")
        source_path.write_text("extends Node\n", encoding="utf-8")
        current_fingerprint = production_source_fingerprint(project_root)

        def run_fixture(
            name: str,
            report: dict[str, object],
            markdown: str,
            should_pass: bool,
            expected_result: str = "pass",
            bind_markdown_hash: bool = True,
            mutate_source: bool = False,
        ) -> None:
            report = copy.deepcopy(report)
            if bind_markdown_hash:
                report["report_markdown_sha256"] = hashlib.sha256(markdown.encode("utf-8")).hexdigest()
            report_path = fixture_dir / f"{name}.json"
            report_path.write_text(json.dumps(report, allow_nan=True), encoding="utf-8")
            report_path.with_suffix(".md").write_text(markdown, encoding="utf-8")
            original_source = source_path.read_bytes()
            if mutate_source:
                source_path.write_bytes(original_source + b"# stale-report-source-change\n")
            try:
                result = subprocess.run(
                    [
                        sys.executable,
                        str(script),
                        str(report_path),
                        "--minimum-duration=8",
                        f"--expected-result={expected_result}",
                    ],
                    capture_output=True,
                    check=False,
                    text=True,
                )
            finally:
                source_path.write_bytes(original_source)
            if (result.returncode == 0) != should_pass:
                fail(
                    f"self-test fixture {name!r} returned {result.returncode}; "
                    f"stdout={result.stdout!r} stderr={result.stderr!r}"
                )

        valid = self_test_report()
        valid["source_fingerprint_start"] = current_fingerprint
        valid["source_fingerprint_end"] = current_fingerprint
        valid_markdown = self_test_markdown(valid)
        run_fixture("valid", valid, valid_markdown, True)
        run_fixture("stale_source", valid, valid_markdown, False, mutate_source=True)

        diagnostic = copy.deepcopy(valid)
        diagnostic["passed"] = False
        diagnostic["source_fingerprint_start"] = hashlib.sha256(
            f"prior-source|{current_fingerprint}".encode("utf-8")
        ).hexdigest()
        diagnostic["source_changed_during_run"] = True
        diagnostic["failures"] = [
            {
                "elapsed_seconds": 8.25,
                "iteration": 1,
                "code": "source_changed_during_run",
                "detail": "Production source fingerprint changed while the soak process was active",
            }
        ]
        diagnostic_markdown = self_test_markdown(diagnostic)
        run_fixture("diagnostic_source_change", diagnostic, diagnostic_markdown, True, "fail")

        def run_positive_failure(name: str, fixture: dict[str, object], code: str) -> None:
            fixture["passed"] = False
            fixture["failures"] = [
                {
                    "elapsed_seconds": fixture["elapsed_wall_seconds"],
                    "iteration": fixture["counts"]["iterations"],
                    "code": code,
                    "detail": f"self-test diagnostic {name}",
                }
            ]
            run_fixture(name, fixture, self_test_markdown(fixture), True, "fail")

        zero_core = copy.deepcopy(valid)
        for field in (
            "iterations",
            "projectile_cycles",
            "boss_restarts",
            "dive_transitions",
            "player_projectiles_spawned",
            "enemy_projectiles_spawned",
            "save_writes",
            "offline_events_queued",
            "offline_queue_reloads",
        ):
            zero_core["counts"][field] = 0
        for map_name in (
            "projectile_model_steps",
            "projectile_models_requested",
            "projectile_models_executed",
        ):
            zero_core["counts"][map_name] = {model: 0 for model in EXPECTED_MODELS}
        run_positive_failure("fail_zero_core", zero_core, "zero_core_coverage")

        restart_mismatch = copy.deepcopy(valid)
        restart_mismatch["counts"]["dive_transitions"] = 0
        run_positive_failure("fail_restart_dive_mismatch", restart_mismatch, "restart_dive_mismatch")

        partial_models = copy.deepcopy(valid)
        partial_models["counts"]["projectile_models_executed"]["linear"] = 0
        partial_models["counts"]["projectile_model_steps"]["soft_homing"] = 0
        partial_models["counts"]["projectile_models_requested"]["lunge"] = 3
        partial_models["counts"]["enemy_projectiles_spawned"] = 2
        run_positive_failure("fail_model_mismatch_partial", partial_models, "partial_model_coverage")

        initial_save_failure = copy.deepcopy(valid)
        initial_save_failure["counts"]["save_writes"] = 0
        run_positive_failure("fail_initial_save_coverage", initial_save_failure, "save_initial_write")

        early_failure = copy.deepcopy(valid)
        early_failure["requested_duration_seconds"] = 12.5
        early_failure["elapsed_wall_seconds"] = 0.75
        run_positive_failure("fail_early_termination", early_failure, "early_termination")

        invalid_reports = {}
        for name, value in {"nan_duration": math.nan, "infinite_duration": math.inf, "bool_duration": True}.items():
            fixture = copy.deepcopy(valid)
            fixture["elapsed_wall_seconds"] = value
            invalid_reports[name] = fixture
        blank_fingerprint = copy.deepcopy(valid)
        blank_fingerprint["source_fingerprint_start"] = ""
        blank_fingerprint["source_fingerprint_end"] = ""
        invalid_reports["blank_fingerprint"] = blank_fingerprint
        mismatched_maps = copy.deepcopy(valid)
        mismatched_maps["counts"]["projectile_models_requested"]["linear"] = 2
        invalid_reports["mismatched_model_maps"] = mismatched_maps
        missing_top_level = copy.deepcopy(valid)
        del missing_top_level["memory_samples"]
        invalid_reports["missing_top_level"] = missing_top_level
        inconsistent_source_flag = copy.deepcopy(valid)
        inconsistent_source_flag["source_changed_during_run"] = True
        invalid_reports["inconsistent_source_flag"] = inconsistent_source_flag
        float_integer_field = copy.deepcopy(valid)
        float_integer_field["counts"]["iterations"] = 1.0
        invalid_reports["float_integer_field"] = float_integer_field
        string_schema = copy.deepcopy(valid)
        string_schema["schema"] = "1"
        invalid_reports["string_schema"] = string_schema
        shorter_pass = copy.deepcopy(valid)
        shorter_pass["requested_duration_seconds"] = 9.0
        invalid_reports["shorter_pass"] = shorter_pass
        incomplete_transaction = copy.deepcopy(valid)
        incomplete_transaction["report_transaction_complete"] = False
        invalid_reports["incomplete_transaction"] = incomplete_transaction
        invariant_mutations = {
            "zero_iterations": ("iterations", 0),
            "cycle_mismatch": ("projectile_cycles", 2),
            "zero_boss_restarts": ("boss_restarts", 0),
            "dive_mismatch": ("dive_transitions", 2),
            "zero_player_projectiles": ("player_projectiles_spawned", 0),
            "zero_enemy_projectiles": ("enemy_projectiles_spawned", 0),
            "zero_save_writes": ("save_writes", 0),
            "zero_offline_events": ("offline_events_queued", 0),
            "zero_offline_reloads": ("offline_queue_reloads", 0),
        }
        for name, (field, value) in invariant_mutations.items():
            fixture = copy.deepcopy(valid)
            fixture["counts"][field] = value
            invalid_reports[name] = fixture
        model_sum_mismatch = copy.deepcopy(valid)
        for map_name in (
            "projectile_model_steps",
            "projectile_models_requested",
            "projectile_models_executed",
        ):
            model_sum_mismatch["counts"][map_name]["linear"] = 2
        invalid_reports["model_sum_mismatch"] = model_sum_mismatch
        for name, fixture in invalid_reports.items():
            run_fixture(name, fixture, self_test_markdown(fixture), False)
        run_fixture("one_byte_markdown", valid, "x", False)
        mismatched_transaction_markdown = self_test_markdown(valid).replace(
            "- Report transaction: `bbbbbbbbbbbbbbbbbbbbbbbb`",
            "- Report transaction: `cccccccccccccccccccccccc`",
        )
        run_fixture("mismatched_transaction", valid, mismatched_transaction_markdown, False)
        run_fixture(
            "markdown_hash_mismatch",
            valid,
            valid_markdown + "\ncorrupted",
            False,
            bind_markdown_hash=False,
        )
    print("Soak validator self-tests passed: PASS/diagnostic fixtures plus strict negative fixtures.")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=pathlib.Path)
    parser.add_argument("--minimum-duration", type=float, required=True)
    parser.add_argument("--expected-result", choices=("pass", "fail"), default="pass")
    args = parser.parse_args()

    minimum_duration = finite_number(args.minimum_duration, "minimum duration")
    if minimum_duration <= 0:
        fail("minimum duration must be positive")

    try:
        report = json.loads(
            args.report.read_text(encoding="utf-8"), parse_constant=reject_json_constant
        )
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as exc:
        fail(f"cannot read valid JSON from {args.report}: {exc}")

    if not isinstance(report, dict):
        fail("report root must be an object")
    if set(report) != TOP_LEVEL_FIELDS:
        fail(f"report must contain the exact top-level schema; got {sorted(report)}")
    if type(report.get("schema")) is not int or report.get("schema") != 1:
        fail("schema must equal 1")
    if type(report.get("report_transaction_complete")) is not bool or not report["report_transaction_complete"]:
        fail("report_transaction_complete must be true")
    expected_passed = args.expected_result == "pass"
    if type(report.get("passed")) is not bool or report.get("passed") is not expected_passed:
        fail(f"passed must be {str(expected_passed).lower()}")
    failures = report.get("failures")
    if not isinstance(failures, list) or report["passed"] != (len(failures) == 0):
        fail("passed must be equivalent to an empty failures array")
    fingerprint_start = report.get("source_fingerprint_start")
    fingerprint_end = report.get("source_fingerprint_end")
    if not isinstance(fingerprint_start, str) or not FINGERPRINT_PATTERN.fullmatch(fingerprint_start):
        fail("source_fingerprint_start must be a nonempty lowercase 64-hex digest")
    if not isinstance(fingerprint_end, str) or not FINGERPRINT_PATTERN.fullmatch(fingerprint_end):
        fail("source_fingerprint_end must be a nonempty lowercase 64-hex digest")
    current_fingerprint = production_source_fingerprint(infer_project_root(args.report))
    if fingerprint_end != current_fingerprint:
        fail("source_fingerprint_end does not match the current production source fingerprint")
    source_changed = report.get("source_changed_during_run")
    if type(source_changed) is not bool or source_changed != (fingerprint_start != fingerprint_end):
        fail("source_changed_during_run must exactly reflect the fingerprint comparison")
    if report["passed"] and source_changed:
        fail("a passing report cannot contain a source change")
    transaction_id = report.get("report_transaction_id")
    if not isinstance(transaction_id, str) or not TRANSACTION_PATTERN.fullmatch(transaction_id):
        fail("report_transaction_id must be a lowercase 24-hex identifier")
    markdown_digest = report.get("report_markdown_sha256")
    if not isinstance(markdown_digest, str) or not MARKDOWN_HASH_PATTERN.fullmatch(markdown_digest):
        fail("report_markdown_sha256 must be a lowercase 64-hex digest")

    requested_duration = finite_number(report.get("requested_duration_seconds"), "requested duration")
    elapsed_duration = finite_number(report.get("elapsed_wall_seconds"), "elapsed wall duration")
    if requested_duration <= 0 or elapsed_duration <= 0:
        fail("requested and elapsed durations must be positive")
    if report["passed"]:
        if requested_duration < minimum_duration:
            fail("requested duration is below the required minimum")
        if elapsed_duration < minimum_duration:
            fail("elapsed wall duration is below the required minimum")
        if elapsed_duration < requested_duration:
            fail("a passing report cannot end before its requested duration")

    for string_field in ("started_at_utc", "finished_at_utc", "display_server", "scope"):
        if not isinstance(report.get(string_field), str) or not report[string_field].strip():
            fail(f"{string_field} must be a nonempty string")
    if type(report.get("seed")) is not int:
        fail("seed must be an integer")
    if not isinstance(report.get("engine"), dict) or not report["engine"]:
        fail("engine must be a nonempty object")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        fail("counts must be an object")
    count_fields = (
        "iterations",
        "boss_restarts",
        "dive_transitions",
        "projectile_cycles",
        "player_projectiles_spawned",
        "enemy_projectiles_spawned",
        "save_writes",
        "save_reloads",
        "offline_events_queued",
        "offline_queue_reloads",
        "offline_queue_final_size",
    )
    expected_count_fields = set(count_fields) | {
        "projectile_model_steps",
        "projectile_models_requested",
        "projectile_models_executed",
    }
    if set(counts) != expected_count_fields:
        fail(f"counts must contain the exact schema; got {sorted(counts)}")
    model_steps = model_map(counts.get("projectile_model_steps"), "projectile_model_steps", report["passed"])
    models_requested = model_map(counts.get("projectile_models_requested"), "projectile_models_requested", report["passed"])
    models_executed = model_map(counts.get("projectile_models_executed"), "projectile_models_executed", report["passed"])
    for field in count_fields:
        nonnegative_integer(counts.get(field), f"counts.{field}")
    if report["passed"]:
        if model_steps != models_requested or model_steps != models_executed:
            fail("requested, executed, and model_steps maps must match exactly")
        if counts["iterations"] <= 0:
            fail("counts.iterations must be positive")
        if counts["projectile_cycles"] != counts["iterations"]:
            fail("counts.projectile_cycles must equal counts.iterations")
        if counts["boss_restarts"] <= 0:
            fail("counts.boss_restarts must be positive")
        if counts["dive_transitions"] != counts["boss_restarts"]:
            fail("counts.dive_transitions must equal counts.boss_restarts")
        if counts["player_projectiles_spawned"] <= 0:
            fail("counts.player_projectiles_spawned must be positive")
        if counts["enemy_projectiles_spawned"] <= 0:
            fail("counts.enemy_projectiles_spawned must be positive")
        if counts["save_writes"] <= 0:
            fail("counts.save_writes must be positive")
        if counts["offline_events_queued"] <= 0:
            fail("counts.offline_events_queued must be positive")
        if counts["offline_queue_reloads"] <= 0:
            fail("counts.offline_queue_reloads must be positive")
        if sum(models_requested.values()) != counts["enemy_projectiles_spawned"]:
            fail("projectile model request totals must equal enemy_projectiles_spawned")

    for object_name, required_fields in {
        "peaks": (
            "player_projectiles",
            "enemy_projectiles",
            "total_projectiles",
            "object_count",
            "node_count",
            "orphan_node_count",
        ),
        "object_counts": (
            "baseline_objects",
            "baseline_nodes",
            "final_objects",
            "final_nodes",
        ),
    }.items():
        value = report.get(object_name)
        if not isinstance(value, dict):
            fail(f"{object_name} must be an object")
        if set(value) != set(required_fields):
            fail(f"{object_name} must contain the exact schema; got {sorted(value)}")
        for field in required_fields:
            nonnegative_integer(value.get(field), f"{object_name}.{field}")

    memory = report.get("memory")
    if not isinstance(memory, dict):
        fail("memory must be an object")
    memory_integer_fields = (
        "sample_count",
        "stable_sample_count",
        "start_bytes",
        "stable_start_bytes",
        "end_bytes",
        "peak_bytes",
    )
    memory_number_fields = ("warmup_seconds", "stable_delta_bytes", "slope_bytes_per_minute")
    if set(memory) != set(memory_integer_fields) | set(memory_number_fields):
        fail(f"memory must contain the exact schema; got {sorted(memory)}")
    for field in memory_integer_fields:
        nonnegative_integer(memory.get(field), f"memory.{field}")
    for field in memory_number_fields:
        finite_number(memory.get(field), f"memory.{field}")
    memory_samples = report.get("memory_samples")
    if not isinstance(memory_samples, list) or not memory_samples:
        fail("memory_samples must be a nonempty array")
    if len(memory_samples) != memory["sample_count"]:
        fail("memory_samples length must equal memory.sample_count")
    for index, sample in enumerate(memory_samples):
        if not isinstance(sample, dict):
            fail(f"memory_samples[{index}] must be an object")
        sample_fields = {"elapsed_seconds", "memory_bytes", "object_count", "node_count", "orphan_node_count"}
        if set(sample) != sample_fields:
            fail(f"memory_samples[{index}] must contain the exact schema; got {sorted(sample)}")
        finite_number(sample.get("elapsed_seconds"), f"memory_samples[{index}].elapsed_seconds")
        for field in ("memory_bytes", "object_count", "node_count", "orphan_node_count"):
            nonnegative_integer(sample.get(field), f"memory_samples[{index}].{field}")

    source_change_failure_found = False
    for index, failure in enumerate(failures):
        if not isinstance(failure, dict) or set(failure) != {"elapsed_seconds", "iteration", "code", "detail"}:
            fail(f"failures[{index}] must contain the exact schema")
        finite_number(failure.get("elapsed_seconds"), f"failures[{index}].elapsed_seconds")
        nonnegative_integer(failure.get("iteration"), f"failures[{index}].iteration")
        for field in ("code", "detail"):
            if not isinstance(failure.get(field), str) or not failure[field].strip():
                fail(f"failures[{index}].{field} must be a nonempty string")
        if failure["code"] == "source_changed_during_run":
            source_change_failure_found = True
    if source_changed and not source_change_failure_found:
        fail("a changed source requires a source_changed_during_run failure")

    markdown = args.report.with_suffix(".md")
    try:
        markdown_bytes = markdown.read_bytes()
        markdown_text = markdown_bytes.decode("utf-8")
    except (OSError, UnicodeError) as exc:
        fail(f"matching Markdown evidence cannot be read: {markdown}: {exc}")
    actual_markdown_digest = hashlib.sha256(markdown_bytes).hexdigest()
    if actual_markdown_digest != markdown_digest:
        fail("matching Markdown SHA-256 does not equal report_markdown_sha256")
    expected_result_text = "PASS" if report["passed"] else "FAIL"
    required_markdown_lines = {
        f"- Result: **{expected_result_text}**",
        f"- Requested wall time: `{requested_duration:.2f} seconds`",
        f"- Actual wall time: `{elapsed_duration:.2f} seconds`",
        f"- Seed: `{report['seed']}`",
        f"- Source fingerprint: `{fingerprint_start}`",
        f"- Source changed during run: `{str(source_changed).lower()}`",
        f"- Report transaction: `{transaction_id}`",
        f"| Projectile travel models exercised | {sum(count > 0 for count in models_executed.values())} / {len(EXPECTED_MODELS)} |",
        f"| Failures | {len(failures)} |",
    }
    required_markdown_lines.update(f"- `{failure['code']}`: {failure['detail']}" for failure in failures)
    markdown_lines = set(markdown_text.splitlines())
    missing_markdown = sorted(required_markdown_lines - markdown_lines)
    if missing_markdown:
        fail("matching Markdown evidence is incomplete or inconsistent: " + repr(missing_markdown))
    executed_coverage = sum(count > 0 for count in models_executed.values())
    print(
        f"Soak report valid: {args.report} ({elapsed_duration:.2f}s, "
        f"{executed_coverage}/{len(EXPECTED_MODELS)} projectile models)."
    )


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        run_self_tests()
    else:
        main()
