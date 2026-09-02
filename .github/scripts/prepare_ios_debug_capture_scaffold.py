#!/usr/bin/env python3
"""Prepare and bind a QA-only Godot Debug iOS Xcode scaffold."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import plistlib
import re
import tempfile
import xml.etree.ElementTree as ET


EVIDENCE_FILENAME = "QA_ONLY_IOS_DEBUG_CAPTURE_SCAFFOLD.json"
PURPOSE = "native-ios-simulator-store-capture-qa-only"
PLACEHOLDER_PATTERN = re.compile(r"CI[A-Z0-9]{8}")
SOURCE_SHA_PATTERN = re.compile(r"[0-9a-f]{40}")


class DebugScaffoldError(RuntimeError):
    """The debug-only scaffold is malformed, unbound, or release-like."""


def _sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _atomic_write(path: pathlib.Path, payload: bytes) -> None:
    temporary: pathlib.Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb",
            prefix=f".{path.name}.",
            suffix=".tmp",
            dir=path.parent,
            delete=False,
        ) as handle:
            temporary = pathlib.Path(handle.name)
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        if path.exists():
            os.chmod(temporary, path.stat().st_mode & 0o777)
        os.replace(temporary, path)
        temporary = None
    except OSError as exc:
        raise DebugScaffoldError(f"cannot atomically write {path}: {exc}") from exc
    finally:
        if temporary is not None:
            try:
                temporary.unlink()
            except FileNotFoundError:
                pass


def _one(paths: list[pathlib.Path], description: str) -> pathlib.Path:
    if len(paths) != 1:
        raise DebugScaffoldError(
            f"expected exactly one {description}, found {len(paths)}"
        )
    path = paths[0]
    if path.is_symlink() or not path.is_file():
        raise DebugScaffoldError(f"{description} must be a regular file: {path}")
    return path


def _validate_binding(source_sha: str, run_id: str, run_attempt: str) -> None:
    if SOURCE_SHA_PATTERN.fullmatch(source_sha) is None:
        raise DebugScaffoldError("source SHA must be a full lowercase Git commit ID")
    if not run_id.isdigit() or not run_attempt.isdigit():
        raise DebugScaffoldError("workflow run identifiers must be decimal integers")


def _validate_placeholder(placeholder: str) -> None:
    if PLACEHOLDER_PATTERN.fullmatch(placeholder) is None:
        raise DebugScaffoldError("placeholder Team ID is not an obvious CI fake")


def inject_placeholder(
    source_preset: pathlib.Path,
    temporary_preset: pathlib.Path,
    placeholder: str,
) -> None:
    _validate_placeholder(placeholder)
    if source_preset.is_symlink() or not source_preset.is_file():
        raise DebugScaffoldError(f"source preset must be a regular file: {source_preset}")
    if temporary_preset.is_symlink() or not temporary_preset.is_file():
        raise DebugScaffoldError(
            f"temporary preset must already be a regular copied file: {temporary_preset}"
        )
    source_text = source_preset.read_text(encoding="utf-8")
    temporary_text = temporary_preset.read_text(encoding="utf-8")
    blank_team = 'application/app_store_team_id=""'
    if source_text.count(blank_team) != 1 or temporary_text.count(blank_team) != 1:
        raise DebugScaffoldError("source and copied presets must each have one blank iOS Team ID")
    if source_text != temporary_text:
        raise DebugScaffoldError("temporary preset drifted before debug Team ID injection")
    if source_text.count('name="iOS"') != 1:
        raise DebugScaffoldError("source preset must contain exactly one iOS export preset")
    _atomic_write(
        temporary_preset,
        temporary_text.replace(
            blank_team,
            f'application/app_store_team_id="{placeholder}"',
            1,
        ).encode("utf-8"),
    )


def _native_target_id(project_text: str) -> str:
    section = re.search(
        r"/\* Begin PBXNativeTarget section \*/(?P<body>.*?)"
        r"/\* End PBXNativeTarget section \*/",
        project_text,
        re.DOTALL,
    )
    if section is None:
        raise DebugScaffoldError("pbxproj has no PBXNativeTarget section")
    targets = re.findall(
        r'^\s*([A-F0-9]{24}) /\* ([^*\r\n]+) \*/ = \{\s*\n'
        r"\s*isa = PBXNativeTarget;",
        section.group("body"),
        re.MULTILINE,
    )
    if len(targets) != 1 or targets[0][1] != "INFINIDIVE":
        raise DebugScaffoldError(
            f"expected the sole native target to be INFINIDIVE, found {targets!r}"
        )
    return targets[0][0]


def _repair_shared_scheme(scheme: pathlib.Path, target_id: str) -> None:
    text = scheme.read_text(encoding="utf-8")
    identifier = re.compile(
        r'(?P<prefix>BlueprintIdentifier = ")[A-F0-9]{24}(?P<suffix>")'
    )
    if len(identifier.findall(text)) != 4:
        raise DebugScaffoldError(
            "expected four shared-scheme BuildableReference identifiers"
        )
    text = identifier.sub(rf"\g<prefix>{target_id}\g<suffix>", text)
    try:
        root = ET.fromstring(text)
    except ET.ParseError as exc:
        raise DebugScaffoldError(f"cannot parse shared Xcode scheme: {exc}") from exc
    expected = {
        "BuildableIdentifier": "primary",
        "BlueprintIdentifier": target_id,
        "BuildableName": "INFINIDIVE.app",
        "BlueprintName": "INFINIDIVE",
        "ReferencedContainer": "container:INFINIDIVE.xcodeproj",
    }
    references = list(root.iter("BuildableReference"))
    if len(references) != 4 or any(item.attrib != expected for item in references):
        raise DebugScaffoldError("shared scheme is not bound to the INFINIDIVE target")
    _atomic_write(scheme, text.encode("utf-8"))


def _scaffold_files(root: pathlib.Path) -> dict[str, pathlib.Path]:
    root = root.resolve()
    if root.is_symlink() or not root.is_dir():
        raise DebugScaffoldError(f"scaffold root must be a non-symlink directory: {root}")
    project = _one(sorted(root.glob("*.xcodeproj/project.pbxproj")), "Xcode project")
    scheme = _one(
        sorted(root.glob("*.xcodeproj/xcshareddata/xcschemes/*.xcscheme")),
        "shared Xcode scheme",
    )
    if scheme.name != "INFINIDIVE.xcscheme":
        raise DebugScaffoldError(f"unexpected shared scheme name: {scheme.name}")
    return {
        "project": project,
        "scheme": scheme,
        "export_options": _one(
            sorted(root.glob("*/export_options.plist")), "export-options plist"
        ),
        "application_plist": _one(
            sorted(root.glob("*/*-Info.plist")), "application Info.plist"
        ),
        "privacy_manifest": _one(
            sorted(root.glob("PrivacyInfo.xcprivacy")), "privacy manifest"
        ),
        "game_pack": _one(sorted(root.glob("*.pck")), "Godot game pack"),
    }


def finalize(
    root: pathlib.Path,
    placeholder: str,
    source_sha: str,
    run_id: str,
    run_attempt: str,
) -> None:
    _validate_placeholder(placeholder)
    _validate_binding(source_sha, run_id, run_attempt)
    root = root.resolve()
    files = _scaffold_files(root)

    project_text = files["project"].read_text(encoding="utf-8")
    target_id = _native_target_id(project_text)
    placeholder_lines = [line for line in project_text.splitlines() if placeholder in line]
    allowed_line = re.compile(
        rf"^\s*(DevelopmentTeam|DEVELOPMENT_TEAM) = {re.escape(placeholder)};\s*$"
    )
    if len(placeholder_lines) != 3 or any(
        allowed_line.fullmatch(line) is None for line in placeholder_lines
    ):
        raise DebugScaffoldError(
            "placeholder Team ID must occur only in the three generated development-team fields"
        )
    _atomic_write(
        files["project"], project_text.replace(placeholder, '""').encode("utf-8")
    )
    _repair_shared_scheme(files["scheme"], target_id)

    try:
        export_options = plistlib.loads(files["export_options"].read_bytes())
    except (plistlib.InvalidFileException, ValueError, OSError) as exc:
        raise DebugScaffoldError(f"cannot parse export-options plist: {exc}") from exc
    if not isinstance(export_options, dict) or export_options.get("teamID") != placeholder:
        raise DebugScaffoldError("export-options teamID does not match the CI placeholder")
    export_options["teamID"] = ""
    _atomic_write(
        files["export_options"],
        plistlib.dumps(export_options, fmt=plistlib.FMT_XML, sort_keys=True),
    )

    placeholder_bytes = placeholder.encode("ascii")
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        if placeholder_bytes in path.read_bytes():
            raise DebugScaffoldError(f"placeholder Team ID remains in scaffold: {path}")

    relative_hashes = {
        key: {
            "path": path.relative_to(root).as_posix(),
            "sha256": _sha256(path),
        }
        for key, path in sorted(files.items())
    }
    evidence = {
        "schema": "infinidive.ios-debug-capture-scaffold.v1",
        "purpose": PURPOSE,
        "qa_only": True,
        "release_eligible": False,
        "export_mode": "debug",
        "xcode_configuration": "Debug",
        "code_signing_allowed": False,
        "source_commit": source_sha,
        "run_id": int(run_id),
        "run_attempt": int(run_attempt),
        "files": relative_hashes,
    }
    _atomic_write(
        root / EVIDENCE_FILENAME,
        (json.dumps(evidence, indent=2, sort_keys=True) + "\n").encode("utf-8"),
    )


def verify(
    root: pathlib.Path,
    source_sha: str,
    run_id: str,
    run_attempt: str,
) -> pathlib.Path:
    _validate_binding(source_sha, run_id, run_attempt)
    root = root.resolve()
    files = _scaffold_files(root)
    evidence_path = root / EVIDENCE_FILENAME
    if evidence_path.is_symlink() or not evidence_path.is_file():
        raise DebugScaffoldError(f"missing regular evidence file: {evidence_path}")
    try:
        evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as exc:
        raise DebugScaffoldError(f"cannot parse scaffold evidence: {exc}") from exc
    expected_scalars = {
        "schema": "infinidive.ios-debug-capture-scaffold.v1",
        "purpose": PURPOSE,
        "qa_only": True,
        "release_eligible": False,
        "export_mode": "debug",
        "xcode_configuration": "Debug",
        "code_signing_allowed": False,
        "source_commit": source_sha,
        "run_id": int(run_id),
        "run_attempt": int(run_attempt),
    }
    for key, expected in expected_scalars.items():
        if evidence.get(key) != expected:
            raise DebugScaffoldError(
                f"scaffold evidence {key}={evidence.get(key)!r}, expected {expected!r}"
            )
    recorded_files = evidence.get("files")
    if not isinstance(recorded_files, dict) or set(recorded_files) != set(files):
        raise DebugScaffoldError("scaffold evidence has an unexpected file inventory")
    for key, path in files.items():
        record = recorded_files.get(key)
        expected_path = path.relative_to(root).as_posix()
        if not isinstance(record, dict) or record.get("path") != expected_path:
            raise DebugScaffoldError(f"scaffold evidence path drift for {key}")
        if record.get("sha256") != _sha256(path):
            raise DebugScaffoldError(f"scaffold evidence hash drift for {key}")
    project_directory = files["project"].parent
    if project_directory.name != "INFINIDIVE.xcodeproj":
        raise DebugScaffoldError(f"unexpected Xcode project directory: {project_directory}")
    return project_directory


def _scheme_fixture(identifier: str) -> str:
    reference = (
        f'<BuildableReference BuildableIdentifier = "primary" '
        f'BlueprintIdentifier = "{identifier}" BuildableName = "INFINIDIVE.app" '
        f'BlueprintName = "INFINIDIVE" '
        f'ReferencedContainer = "container:INFINIDIVE.xcodeproj" />'
    )
    return "<Scheme>" + reference * 4 + "</Scheme>"


def run_self_test() -> None:
    placeholder = "CISTORE000"
    source_sha = "a" * 40
    with tempfile.TemporaryDirectory(prefix="infinidive-debug-scaffold-") as root_text:
        root = pathlib.Path(root_text)
        source = root / "source.cfg"
        copied = root / "copied.cfg"
        preset = '[preset.2]\nname="iOS"\napplication/app_store_team_id=""\n'
        source.write_text(preset, encoding="utf-8")
        copied.write_text(preset, encoding="utf-8")
        inject_placeholder(source, copied, placeholder)
        if copied.read_text(encoding="utf-8").count(placeholder) != 1:
            raise AssertionError("debug Team ID injection did not occur exactly once")

        scaffold = root / "scaffold"
        project = scaffold / "INFINIDIVE.xcodeproj"
        scheme_dir = project / "xcshareddata" / "xcschemes"
        export_dir = scaffold / "INFINIDIVE"
        scheme_dir.mkdir(parents=True)
        export_dir.mkdir()
        target_id = "A" * 24
        old_id = "B" * 24
        (project / "project.pbxproj").write_text(
            "/* Begin PBXNativeTarget section */\n"
            f"{target_id} /* INFINIDIVE */ = {{\n\tisa = PBXNativeTarget;\n}};\n"
            "/* End PBXNativeTarget section */\n"
            f"DevelopmentTeam = {placeholder};\n"
            f"DEVELOPMENT_TEAM = {placeholder};\n"
            f"DEVELOPMENT_TEAM = {placeholder};\n",
            encoding="utf-8",
        )
        (scheme_dir / "INFINIDIVE.xcscheme").write_text(
            _scheme_fixture(old_id), encoding="utf-8"
        )
        (export_dir / "export_options.plist").write_bytes(
            plistlib.dumps({"teamID": placeholder}, fmt=plistlib.FMT_XML)
        )
        (export_dir / "INFINIDIVE-Info.plist").write_bytes(
            plistlib.dumps({"CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)"})
        )
        (scaffold / "PrivacyInfo.xcprivacy").write_bytes(
            plistlib.dumps({"NSPrivacyTracking": False})
        )
        (scaffold / "INFINIDIVE.pck").write_bytes(b"debug-capture-pck")

        finalize(scaffold, placeholder, source_sha, "17", "2")
        verified_project = verify(scaffold, source_sha, "17", "2")
        if verified_project != project:
            raise AssertionError("verified project path changed")
        (scaffold / "INFINIDIVE.pck").write_bytes(b"tampered")
        try:
            verify(scaffold, source_sha, "17", "2")
        except DebugScaffoldError:
            pass
        else:
            raise AssertionError("tampered debug scaffold was accepted")
    print(
        "iOS Debug capture scaffold self-test: PASS "
        "(inject/finalize/verify positive, hash-drift negative)"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    inject_parser = subparsers.add_parser("inject")
    inject_parser.add_argument("--source-preset", required=True, type=pathlib.Path)
    inject_parser.add_argument("--temporary-preset", required=True, type=pathlib.Path)
    inject_parser.add_argument("--placeholder-team-id", required=True)

    finalize_parser = subparsers.add_parser("finalize")
    finalize_parser.add_argument("--root", required=True, type=pathlib.Path)
    finalize_parser.add_argument("--placeholder-team-id", required=True)
    finalize_parser.add_argument("--source-sha", required=True)
    finalize_parser.add_argument("--run-id", required=True)
    finalize_parser.add_argument("--run-attempt", required=True)

    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("--root", required=True, type=pathlib.Path)
    verify_parser.add_argument("--source-sha", required=True)
    verify_parser.add_argument("--run-id", required=True)
    verify_parser.add_argument("--run-attempt", required=True)

    subparsers.add_parser("self-test")
    args = parser.parse_args()
    try:
        if args.command == "inject":
            inject_placeholder(
                args.source_preset, args.temporary_preset, args.placeholder_team_id
            )
            print("iOS Debug capture preset injection: PASS")
        elif args.command == "finalize":
            finalize(
                args.root,
                args.placeholder_team_id,
                args.source_sha,
                args.run_id,
                args.run_attempt,
            )
            print("iOS Debug capture scaffold finalization: PASS")
        elif args.command == "verify":
            print(
                verify(args.root, args.source_sha, args.run_id, args.run_attempt),
                end="",
            )
        else:
            run_self_test()
    except (DebugScaffoldError, AssertionError, OSError, ValueError) as exc:
        print(f"iOS Debug capture scaffold {args.command}: FAIL: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
