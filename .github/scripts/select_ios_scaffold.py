#!/usr/bin/env python3
"""Select the newest source-bound iOS scaffold artifact valid for a rerun."""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
import tempfile


ARTIFACT_PATTERN = re.compile(r"infinidive-ios-unsigned-xcode-(\d+)")
SOURCE_PATTERN = re.compile(r"^- Source commit: `([0-9a-f]{40})`$", re.MULTILINE)
RUN_PATTERN = re.compile(
    r"^- GitHub Actions run: `(\d+)` \(attempt `(\d+)`\)$", re.MULTILINE
)


class ScaffoldSelectionError(RuntimeError):
    """Downloaded scaffold candidates are missing, stale, or ambiguous."""


def select(
    candidates_root: pathlib.Path,
    source_sha: str,
    run_id: int,
    current_attempt: int,
) -> pathlib.Path:
    if re.fullmatch(r"[0-9a-f]{40}", source_sha) is None:
        raise ScaffoldSelectionError("source SHA must be a full lowercase Git commit ID")
    if run_id < 1 or current_attempt < 1:
        raise ScaffoldSelectionError("run ID and attempt must be positive integers")
    if candidates_root.is_symlink() or not candidates_root.is_dir():
        raise ScaffoldSelectionError(
            f"candidate root must be a non-symlink directory: {candidates_root}"
        )
    candidate_dirs = sorted(candidates_root.iterdir())
    if not candidate_dirs:
        raise ScaffoldSelectionError("no downloaded unsigned-scaffold candidates")
    valid: list[tuple[int, pathlib.Path]] = []
    for candidate in candidate_dirs:
        artifact_match = ARTIFACT_PATTERN.fullmatch(candidate.name)
        if artifact_match is None or candidate.is_symlink() or not candidate.is_dir():
            raise ScaffoldSelectionError(f"unexpected scaffold candidate entry: {candidate}")
        evidence = candidate / "UNSIGNED_LINUX_EXPORT_EVIDENCE.md"
        if evidence.is_symlink() or not evidence.is_file():
            raise ScaffoldSelectionError(f"candidate lacks regular root evidence: {candidate}")
        text = evidence.read_text(encoding="utf-8")
        source_matches = SOURCE_PATTERN.findall(text)
        run_matches = RUN_PATTERN.findall(text)
        if len(source_matches) != 1 or len(run_matches) != 1:
            raise ScaffoldSelectionError(f"malformed unsigned-scaffold evidence: {evidence}")
        evidence_run, evidence_attempt = map(int, run_matches[0])
        artifact_attempt = int(artifact_match.group(1))
        if source_matches[0] != source_sha or evidence_run != run_id:
            raise ScaffoldSelectionError(
                f"stale or cross-source unsigned-scaffold candidate: {evidence}"
            )
        if evidence_attempt != artifact_attempt or not 1 <= evidence_attempt <= current_attempt:
            raise ScaffoldSelectionError(
                f"invalid unsigned-scaffold attempt binding: {evidence}"
            )
        valid.append((evidence_attempt, candidate.resolve()))
    highest_attempt = max(item[0] for item in valid)
    selected = [path for attempt, path in valid if attempt == highest_attempt]
    if len(selected) != 1:
        raise ScaffoldSelectionError("unsigned-scaffold selection is ambiguous")
    return selected[0]


def _write_candidate(
    root: pathlib.Path, source_sha: str, run_id: int, attempt: int, evidence_attempt: int | None = None
) -> pathlib.Path:
    candidate = root / f"infinidive-ios-unsigned-xcode-{attempt}"
    candidate.mkdir()
    bound_attempt = attempt if evidence_attempt is None else evidence_attempt
    (candidate / "UNSIGNED_LINUX_EXPORT_EVIDENCE.md").write_text(
        "# Evidence\n\n"
        f"- Source commit: `{source_sha}`\n"
        f"- GitHub Actions run: `{run_id}` (attempt `{bound_attempt}`)\n",
        encoding="utf-8",
    )
    return candidate


def run_self_test() -> None:
    source_sha = "a" * 40
    with tempfile.TemporaryDirectory(prefix="infinidive-ios-scaffold-select-") as root_text:
        root = pathlib.Path(root_text)
        attempt_one = _write_candidate(root, source_sha, 42, 1)
        attempt_three = _write_candidate(root, source_sha, 42, 3)
        if select(root, source_sha, 42, 3) != attempt_three.resolve():
            raise AssertionError("latest valid rerun attempt was not selected")

    with tempfile.TemporaryDirectory(prefix="infinidive-ios-scaffold-rerun-") as root_text:
        root = pathlib.Path(root_text)
        attempt_one = _write_candidate(root, source_sha, 42, 1)
        if select(root, source_sha, 42, 2) != attempt_one.resolve():
            raise AssertionError("prior successful attempt was not selected for rerun")

    with tempfile.TemporaryDirectory(prefix="infinidive-ios-scaffold-stale-") as root_text:
        root = pathlib.Path(root_text)
        _write_candidate(root, "b" * 40, 42, 1)
        try:
            select(root, source_sha, 42, 1)
        except ScaffoldSelectionError:
            pass
        else:
            raise AssertionError("stale-source fixture was accepted")

    with tempfile.TemporaryDirectory(prefix="infinidive-ios-scaffold-binding-") as root_text:
        root = pathlib.Path(root_text)
        _write_candidate(root, source_sha, 42, 2, evidence_attempt=1)
        try:
            select(root, source_sha, 42, 2)
        except ScaffoldSelectionError:
            pass
        else:
            raise AssertionError("attempt-name mismatch fixture was accepted")
    print("iOS scaffold selector self-test: PASS (rerun selection, stale and binding negatives)")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates-root", type=pathlib.Path)
    parser.add_argument("--source-sha")
    parser.add_argument("--run-id", type=int)
    parser.add_argument("--current-attempt", type=int)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        if any(
            value is not None
            for value in (
                args.candidates_root,
                args.source_sha,
                args.run_id,
                args.current_attempt,
            )
        ):
            parser.error("--self-test cannot be combined with selector arguments")
    elif any(
        value is None
        for value in (
            args.candidates_root,
            args.source_sha,
            args.run_id,
            args.current_attempt,
        )
    ):
        parser.error("provide all selector arguments, or use --self-test")
    try:
        if args.self_test:
            run_self_test()
        else:
            print(
                select(
                    args.candidates_root,
                    args.source_sha,
                    args.run_id,
                    args.current_attempt,
                )
            )
    except (ScaffoldSelectionError, AssertionError, OSError, UnicodeError) as exc:
        print(f"iOS scaffold selection: FAIL: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
