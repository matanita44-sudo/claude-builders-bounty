#!/usr/bin/env python3
"""Scrub a temporary CI Team ID and bind an unsigned iOS scaffold to evidence."""

from __future__ import annotations

import argparse
import hashlib
import os
import pathlib
import plistlib
import re
import tempfile


class ScaffoldFinalizationError(RuntimeError):
    """The unsigned scaffold could not be made safe for artifact retention."""


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
        os.chmod(temporary, path.stat().st_mode & 0o777)
        os.replace(temporary, path)
        temporary = None
    except OSError as exc:
        raise ScaffoldFinalizationError(f"cannot atomically rewrite {path}: {exc}") from exc
    finally:
        if temporary is not None:
            try:
                temporary.unlink()
            except FileNotFoundError:
                pass


def _exactly_one(paths: list[pathlib.Path], description: str) -> pathlib.Path:
    if len(paths) != 1:
        raise ScaffoldFinalizationError(
            f"expected exactly one {description}, found {len(paths)}"
        )
    return paths[0]


def _contains(path: pathlib.Path, needle: bytes) -> bool:
    overlap = max(0, len(needle) - 1)
    tail = b""
    try:
        with path.open("rb") as handle:
            while True:
                chunk = handle.read(1024 * 1024)
                if not chunk:
                    return False
                combined = tail + chunk
                if needle in combined:
                    return True
                tail = combined[-overlap:] if overlap else b""
    except OSError as exc:
        raise ScaffoldFinalizationError(f"cannot scan {path}: {exc}") from exc


def _sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def finalize(
    root: pathlib.Path,
    placeholder: str,
    source_sha: str,
    run_id: str,
    run_attempt: str,
) -> None:
    if re.fullmatch(r"CI[A-Z0-9]{8}", placeholder) is None:
        raise ScaffoldFinalizationError("placeholder Team ID is not an obvious CI fake")
    if re.fullmatch(r"[0-9a-f]{40}", source_sha) is None:
        raise ScaffoldFinalizationError("source SHA must be a full lowercase Git commit ID")
    if not run_id.isdigit() or not run_attempt.isdigit():
        raise ScaffoldFinalizationError("workflow run identifiers must be decimal integers")
    root = root.resolve()
    if not root.is_dir():
        raise ScaffoldFinalizationError(f"scaffold root is not a directory: {root}")

    project_file = _exactly_one(
        sorted(root.glob("*.xcodeproj/project.pbxproj")),
        "Xcode project file",
    )
    export_options = _exactly_one(
        sorted(root.glob("*/export_options.plist")),
        "export-options plist",
    )
    application_plist = _exactly_one(
        sorted(root.glob("*/*-Info.plist")),
        "application Info.plist",
    )
    privacy_manifest = _exactly_one(
        sorted(root.glob("PrivacyInfo.xcprivacy")),
        "privacy manifest",
    )
    game_pack = _exactly_one(sorted(root.glob("*.pck")), "Godot game pack")

    project_text = project_file.read_text(encoding="utf-8")
    placeholder_lines = [line for line in project_text.splitlines() if placeholder in line]
    if len(placeholder_lines) != 3:
        raise ScaffoldFinalizationError(
            f"expected three placeholder Team ID lines in pbxproj, found {len(placeholder_lines)}"
        )
    allowed_line = re.compile(
        rf"^\s*(DevelopmentTeam|DEVELOPMENT_TEAM) = {re.escape(placeholder)};\s*$"
    )
    if any(allowed_line.fullmatch(line) is None for line in placeholder_lines):
        raise ScaffoldFinalizationError("placeholder Team ID appears in an unexpected pbxproj field")
    project_text = project_text.replace(placeholder, '""')
    _atomic_write(project_file, project_text.encode("utf-8"))

    try:
        options = plistlib.loads(export_options.read_bytes())
    except (OSError, plistlib.InvalidFileException, ValueError) as exc:
        raise ScaffoldFinalizationError(f"cannot parse {export_options}: {exc}") from exc
    if not isinstance(options, dict) or options.get("teamID") != placeholder:
        raise ScaffoldFinalizationError("export-options teamID does not match the CI placeholder")
    options["teamID"] = ""
    _atomic_write(
        export_options,
        plistlib.dumps(options, fmt=plistlib.FMT_XML, sort_keys=True),
    )

    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        if _contains(path, placeholder.encode("ascii")):
            raise ScaffoldFinalizationError(f"placeholder Team ID remains in artifact: {path}")

    evidence = f"""# INFINIDIVE unsigned iOS Xcode scaffold evidence

- Source commit: `{source_sha}`
- GitHub Actions run: `{run_id}` (attempt `{run_attempt}`)
- Generator: verified Godot 4.7.2 stable export templates on Linux
- Bundle: regenerated Xcode project plus release libraries and current-source PCK
- Current-source PCK SHA-256: `{_sha256(game_pack)}`
- Scrubbed project.pbxproj SHA-256: `{_sha256(project_file)}`
- Scrubbed export_options.plist SHA-256: `{_sha256(export_options)}`
- Application Info.plist SHA-256: `{_sha256(application_plist)}`
- PrivacyInfo.xcprivacy SHA-256: `{_sha256(privacy_manifest)}`

The Linux exporter required a temporary, explicitly non-secret placeholder Team
ID. It was used only in the ephemeral project copy, then removed from both the
generated Xcode project and export-options plist before this artifact was
retained. The checked-in production preset remains blank.

The application Info.plist was sanitized and validated to remove unused empty
Camera, Microphone, and Photo Library usage descriptions and the deprecated
CFBundleSignature key. The custom INFINIDIVE 2x/3x launch pixels and tracking-
false privacy manifest were validated against the generated scaffold.

This artifact is **not** an Xcode compile, signed app, archive, IPA, simulator or
device install, TestFlight upload, App Store Connect result, or submission. A
real Apple Team ID, protected signing assets, macOS/Xcode archive, upload, and
native-device QA are still required.
"""
    evidence_path = root / "UNSIGNED_LINUX_EXPORT_EVIDENCE.md"
    evidence_path.write_text(evidence, encoding="utf-8")
    if _contains(evidence_path, placeholder.encode("ascii")):
        raise ScaffoldFinalizationError("evidence note leaked the placeholder Team ID")
    print("Unsigned iOS scaffold finalization: PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, type=pathlib.Path)
    parser.add_argument("--placeholder-team-id", required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--run-attempt", required=True)
    args = parser.parse_args()
    try:
        finalize(
            args.root,
            args.placeholder_team_id,
            args.source_sha,
            args.run_id,
            args.run_attempt,
        )
    except (ScaffoldFinalizationError, OSError) as exc:
        print(f"Unsigned iOS scaffold finalization: FAIL: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
