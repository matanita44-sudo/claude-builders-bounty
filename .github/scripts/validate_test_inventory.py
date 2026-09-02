#!/usr/bin/env python3
import csv
import collections
import pathlib
import re
import sys


def fail(message: str) -> None:
    print(f"Test inventory error: {message}", file=sys.stderr)
    raise SystemExit(1)


def workflow_suite_calls(workflow: str) -> collections.Counter[str]:
    run_blocks = []
    lines = workflow.splitlines()
    line_index = 0
    while line_index < len(lines):
        match = re.match(r"^(\s*)(?:-\s+)?run:\s*(.*)$", lines[line_index])
        if not match:
            line_index += 1
            continue
        indentation = len(match.group(1))
        scalar = match.group(2)
        if scalar and scalar not in {"|", ">", "|-", ">-", "|+", ">+"}:
            run_blocks.append(scalar)
            line_index += 1
            continue
        block_lines = []
        line_index += 1
        while line_index < len(lines):
            candidate = lines[line_index]
            if candidate.strip() and len(candidate) - len(candidate.lstrip()) <= indentation:
                break
            if candidate.strip() and not candidate.lstrip().startswith("#"):
                block_lines.append(candidate.strip())
            line_index += 1
        run_blocks.append("\n".join(block_lines))

    calls: collections.Counter[str] = collections.Counter()
    command_pattern = re.compile(
        r"^bash \.github/scripts/run_godot_checked\.sh --suite ([a-z0-9_]+)(?:\s|$)"
    )
    for block in run_blocks:
        for command_line in block.splitlines():
            match = command_pattern.match(command_line.strip())
            if match:
                calls[match.group(1)] += 1
    return calls


def runnable_test_sources(project: pathlib.Path, scene: str) -> list[str]:
    scene_path = project / pathlib.PurePosixPath(scene.removeprefix("res://"))
    scene_text = scene_path.read_text(encoding="utf-8")
    sources = [scene_text]
    script_path_pattern = re.compile(r'path="(res://tests/[^" ]+\.gd)"')
    for script in sorted(set(script_path_pattern.findall(scene_text))):
        script_path = project / pathlib.PurePosixPath(script.removeprefix("res://"))
        if not script_path.is_file():
            fail(f"{scene} references a missing test script: {script}")
        sources.append(script_path.read_text(encoding="utf-8"))
    return sources


def main() -> None:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    manifest = root / ".github/scripts/test_suites.tsv"
    project = root / "infinidive-game"
    rows = []
    with manifest.open(encoding="utf-8", newline="") as handle:
        reader = csv.reader((line for line in handle if not line.startswith("#")), delimiter="|")
        for line_number, row in enumerate(reader, start=2):
            if not row:
                continue
            if len(row) != 8:
                fail(f"manifest row {line_number} has {len(row)} fields, expected 8")
            rows.append(row)

    ids = [row[0] for row in rows]
    if len(ids) != len(set(ids)):
        fail("suite ids must be unique")

    manifested = {}
    manifested_resources = {}
    for suite_id, role, scene, timeout, expected, sentinel, allow_count, allow_regex in rows:
        if role not in {"import", "suite", "nested", "imported", "soak"}:
            fail(f"{suite_id} has invalid role {role!r}")
        if role == "suite" and (not expected.isdigit() or sentinel == "-"):
            fail(f"{suite_id} lacks an exact assertion count or sentinel")
        if role in {"suite", "import", "soak"} and not timeout.isdigit():
            fail(f"{suite_id} lacks a numeric timeout")
        if not allow_count.isdigit():
            fail(f"{suite_id} has invalid allowed error count")
        if int(allow_count) and allow_regex == "-":
            fail(f"{suite_id} allows errors without an exact regex")
        if scene == "-":
            continue
        if not scene.startswith("res://"):
            fail(f"{suite_id} has a non-resource scene path")
        relative = pathlib.PurePosixPath(scene.removeprefix("res://"))
        disk_path = project / relative
        if not disk_path.is_file():
            fail(f"{suite_id} scene does not exist: {scene}")
        if scene in manifested_resources:
            fail(f"resource appears twice: {scene}")
        manifested_resources[scene] = role
        if scene.endswith(".tscn"):
            manifested[scene] = role

    discovered = {
        "res://" + path.relative_to(project).as_posix()
        for path in (project / "tests").rglob("*.tscn")
    }
    missing = sorted(discovered - set(manifested))
    stale = sorted(set(manifested) - discovered)
    if missing:
        fail("unaccounted test scene(s): " + ", ".join(missing))
    if stale:
        fail("manifested scene(s) not found: " + ", ".join(stale))

    referenced_scripts = set()
    script_path_pattern = re.compile(r'path="(res://tests/[^" ]+\.gd)"')
    for scene in discovered:
        scene_path = project / pathlib.PurePosixPath(scene.removeprefix("res://"))
        referenced_scripts.update(script_path_pattern.findall(scene_path.read_text(encoding="utf-8")))
    entrypoint_scripts = {
        "res://" + path.relative_to(project).as_posix()
        for path in (project / "tests").rglob("*.gd")
        if path.name == "test_runner.gd"
        or path.name.endswith("_test.gd")
        or path.name.endswith("_probe.gd")
    }
    intentionally_non_scene = {
        resource
        for resource, role in manifested_resources.items()
        if resource.endswith(".gd") and role in {"nested", "imported"}
    }
    unbound_entrypoints = sorted(entrypoint_scripts - referenced_scripts - intentionally_non_scene)
    if unbound_entrypoints:
        fail(
            "test entrypoint script(s) lack a scene or nested/imported manifest role: "
            + ", ".join(unbound_entrypoints)
        )

    required_roles = {
        "res://tests/progression/ProcessRelaunchProbe.tscn": "nested",
        "res://tests/soak/SoakTest.tscn": "soak",
    }
    for scene, expected_role in required_roles.items():
        if manifested.get(scene) != expected_role:
            fail(f"{scene} must be marked {expected_role}")

    suite_count = sum(role == "suite" for role in manifested.values())
    if suite_count < 1:
        fail("at least one standalone suite is required")

    runnable_sources = []
    for scene, role in manifested.items():
        if role in {"suite", "soak"}:
            runnable_sources.extend(runnable_test_sources(project, scene))
    combined_runnable_sources = "\n".join(runnable_sources)
    for scene, role in manifested.items():
        escaped_scene = re.escape(scene)
        if role == "imported":
            scene_resource_reference = re.compile(
                rf'(?:path\s*=\s*|(?:preload|load|ResourceLoader\.load)\(\s*)["\']{escaped_scene}["\']'
            )
            if not scene_resource_reference.search(combined_runnable_sources):
                fail(
                    f"imported test scene is not structurally imported by a runnable suite: {scene}"
                )
        elif role == "nested":
            nested_scene_invocation = re.compile(
                rf'["\']--scene["\']\s*,\s*["\']{escaped_scene}["\']', re.DOTALL
            )
            if not nested_scene_invocation.search(combined_runnable_sources):
                fail(
                    f"nested test scene is not structurally invoked by a runnable suite: {scene}"
                )

    workflow = (root / ".github/workflows/infinidive-ci.yml").read_text(encoding="utf-8")
    workflow_calls = workflow_suite_calls(workflow)
    runnable_ids = {row[0] for row in rows if row[1] in {"import", "suite", "soak"}}
    missing_calls = sorted(runnable_ids - set(workflow_calls))
    unknown_calls = sorted(set(workflow_calls) - runnable_ids)
    duplicate_calls = sorted(suite_id for suite_id, count in workflow_calls.items() if count != 1)
    if missing_calls:
        fail("runnable suite(s) absent from workflow: " + ", ".join(missing_calls))
    if unknown_calls:
        fail("workflow references unknown suite(s): " + ", ".join(unknown_calls))
    if duplicate_calls:
        fail("workflow must invoke each runnable suite exactly once: " + ", ".join(duplicate_calls))
    nested_count = sum(role == "nested" for role in manifested.values())
    imported_count = sum(role == "imported" for role in manifested.values())
    soak_count = sum(role == "soak" for role in manifested.values())
    print(
        f"Test inventory valid: {len(discovered)} scenes, {suite_count} suites, "
        f"{nested_count} nested probe(s), {imported_count} structurally imported scene(s), "
        f"{soak_count} soak scene(s)."
    )


if __name__ == "__main__":
    main()
