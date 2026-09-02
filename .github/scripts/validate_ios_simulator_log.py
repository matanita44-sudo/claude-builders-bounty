#!/usr/bin/env python3
"""Fail closed on iOS app-process errors outside narrow reviewed exceptions."""

from __future__ import annotations

import argparse
import re
import tempfile
from pathlib import Path


MAX_LOG_BYTES = 32 * 1024 * 1024
ERROR_PATTERN = re.compile(
    r"(?:uncaught|unhandled) exception|fatal error|assertion failed|"
    r"EXC_(?:BAD_ACCESS|CRASH|RESOURCE)|SIG(?:ABRT|SEGV)|crashed|abort trap|"
    r"Segmentation fault(?:\s*:\s*\d+)?|"
    r"\[com\.matan\.infinidive:ERROR\]|SCRIPT ERROR|Parse Error|\bERROR:",
    re.IGNORECASE,
)
APP_RECORD_PATTERN = re.compile(
    r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+\s+\S+\s+"
    r"INFINIDIVE\[(?P<pid>\d+):[0-9A-Fa-f]+\]"
)
APP_ERROR_SEVERITY_PATTERN = re.compile(
    r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+\s+"
    r"(?:E|F|Error|Fault)\s+INFINIDIVE\[\d+:[0-9A-Fa-f]+\]",
    re.IGNORECASE,
)
KNOWN_PLATFORM_NOISE: tuple[tuple[str, re.Pattern[str], int, int], ...] = (
    (
        "cfbundle_factory",
        re.compile(
            r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+ E\s+"
            r"INFINIDIVE\[(?P<pid>\d+):[0-9A-Fa-f]+\] "
            r"\[com\.apple\.CFBundle:plugin\] AddInstanceForFactory: No factory registered "
            r"for id <CFUUID 0x[0-9A-Fa-f]+> F8BB1C28-BAE8-11D6-9C31-00039315CD46$"
        ),
        1,
        6,
    ),
    (
        "coremotion_missing_preferences",
        re.compile(
            r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+ E\s+"
            r"INFINIDIVE\[(?P<pid>\d+):[0-9A-Fa-f]+\] "
            r"\[com\.apple\.locationd\.Core:Core\] \{\"msg\":\"file does not exist\.\.\. clearing\", "
            r"\"file\":[^,\r\n]+/com\.apple\.CoreMotion\.plist, "
            r"\"error\":Error Domain=NSCocoaErrorDomain Code=260 "
            r"\"The file .com\.apple\.CoreMotion\.plist. couldn.t be opened because there is no such file\.\" "
            r"UserInfo=\{NSFilePath=[^,}\r\n]+/com\.apple\.CoreMotion\.plist, "
            r"NSURL=file:///[^,}\r\n]+/com\.apple\.CoreMotion\.plist, "
            r"NSUnderlyingError=0x[0-9A-Fa-f]+ \{Error Domain=NSPOSIXErrorDomain "
            r"Code=2 \"No such file or directory\"\}\}\}$"
        ),
        1,
        6,
    ),
    (
        "app_launch_measurement_event",
        re.compile(
            r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+ E\s+"
            r"INFINIDIVE\[(?P<pid>\d+):[0-9A-Fa-f]+\] "
            r"\[com\.apple\.app_launch_measurement:General\] Failed to send CA Event for app "
            r"launch measurements for ca_event_type: [01] event_name: "
            r"com\.apple\.app_launch_measurement\.(?:FirstFramePresentationMetric|ExtendedLaunchMetrics)$"
        ),
        2,
        12,
    ),
    (
        "app_launch_measurement_timeout",
        re.compile(
            r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+ E\s+"
            r"INFINIDIVE\[(?P<pid>\d+):[0-9A-Fa-f]+\] "
            r"\[com\.apple\.app_launch_measurement:General\] CA Telemetry timedout after 20 "
            r"seconds due to app launch has not reached all responsive milestones$"
        ),
        1,
        6,
    ),
    (
        "coreaudio_simulator_overload",
        re.compile(
            r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+ E\s+"
            r"INFINIDIVE\[(?P<pid>\d+):[0-9A-Fa-f]+\] "
            r"\[com\.apple\.coreaudio:AMCP\]\s+HALC_ProxyIOContext\.cpp:\d+\s+"
            r"HALC_ProxyIOContext::IOWorkLoop: skipping cycle due to overload$"
        ),
        64,
        384,
    ),
)
KNOWN_MOUSE_WARNING = re.compile(
    r"(?:\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+ E\s+"
    r"INFINIDIVE\[(?P<pid>\d+):[0-9A-Fa-f]+\]\s+)?"
    r"\[com\.matan\.infinidive:ERROR\] "
    r"servers/display/display_server\.cpp:\d+:mouse_get_position\(\): "
    r"Mouse is not supported by this display server\. Method/function failed\. "
    r"Returning: Point2i\(\)"
)


class SimulatorLogError(RuntimeError):
    """Raised when the Simulator log violates the reviewed release contract."""


def validate_text(
    text: str,
    maximum_known_warnings: int,
    maximum_known_warnings_per_process: int,
    expected_pids: set[str] | None = None,
) -> tuple[int, int]:
    if maximum_known_warnings < 0:
        raise SimulatorLogError("maximum known-warning count cannot be negative")
    if maximum_known_warnings_per_process < 0:
        raise SimulatorLogError("per-process known-warning count cannot be negative")
    known_count = 0
    app_record_count = 0
    app_pids: set[str] = set()
    process_counts: dict[str, int] = {}
    platform_noise_counts: dict[tuple[str, str], int] = {}
    platform_noise_totals: dict[str, int] = {}
    for line_number, line in enumerate(text.splitlines(), start=1):
        app_record_match = APP_RECORD_PATTERN.search(line)
        if app_record_match:
            app_record_count += 1
            app_pids.add(app_record_match.group("pid"))
        known_match = KNOWN_MOUSE_WARNING.fullmatch(line)
        if known_match:
            known_count += 1
            pid = known_match.group("pid")
            if pid is None:
                raise SimulatorLogError(
                    f"reviewed warning at line {line_number} has no attributable app process"
                )
            process_counts[pid] = process_counts.get(pid, 0) + 1
            if process_counts[pid] > maximum_known_warnings_per_process:
                raise SimulatorLogError(
                    "reviewed Godot touch-only mouse warning repeated for process "
                    f"{pid} ({process_counts[pid]} > {maximum_known_warnings_per_process})"
                )
            continue
        # Check crash/error tokens before platform exceptions so variable fields
        # inside a nominally known Simulator record cannot smuggle a hard failure.
        if ERROR_PATTERN.search(line):
            raise SimulatorLogError(
                f"app-owned Simulator error at line {line_number}: {line[:320]}"
            )
        platform_noise_match = None
        for category, pattern, per_process_limit, aggregate_limit in KNOWN_PLATFORM_NOISE:
            candidate = pattern.fullmatch(line)
            if candidate is None:
                continue
            pid = candidate.group("pid")
            key = (category, pid)
            platform_noise_counts[key] = platform_noise_counts.get(key, 0) + 1
            platform_noise_totals[category] = platform_noise_totals.get(category, 0) + 1
            if platform_noise_counts[key] > per_process_limit:
                raise SimulatorLogError(
                    f"reviewed Simulator platform noise {category} repeated for process {pid} "
                    f"({platform_noise_counts[key]} > {per_process_limit})"
                )
            if platform_noise_totals[category] > aggregate_limit:
                raise SimulatorLogError(
                    f"reviewed Simulator platform noise {category} exceeded aggregate limit "
                    f"({platform_noise_totals[category]} > {aggregate_limit})"
                )
            platform_noise_match = candidate
            break
        if platform_noise_match is not None:
            continue
        if APP_ERROR_SEVERITY_PATTERN.search(line):
            raise SimulatorLogError(
                f"unreviewed Simulator Error/Fault record at line {line_number}: {line[:320]}"
            )
    if known_count > maximum_known_warnings:
        raise SimulatorLogError(
            "reviewed Godot touch-only mouse warning repeated unexpectedly "
            f"({known_count} > {maximum_known_warnings})"
        )
    if app_record_count == 0:
        raise SimulatorLogError("Simulator log contains no attributable INFINIDIVE app record")
    if expected_pids is not None:
        if not expected_pids or any(re.fullmatch(r"[1-9][0-9]*", pid) is None for pid in expected_pids):
            raise SimulatorLogError("expected app PIDs must be non-empty positive decimal values")
        missing = sorted(expected_pids - app_pids, key=int)
        unexpected = sorted(app_pids - expected_pids, key=int)
        if missing or unexpected:
            raise SimulatorLogError(
                "Simulator app-process attribution mismatch "
                f"(missing={missing}, unexpected={unexpected})"
            )
    return known_count, sum(platform_noise_totals.values())


def validate_file(
    path: Path,
    maximum_known_warnings: int,
    maximum_known_warnings_per_process: int,
    expected_pids: set[str] | None = None,
) -> tuple[int, int]:
    if not path.is_file() or path.is_symlink():
        raise SimulatorLogError("Simulator app log must be a regular non-symlink file")
    size = path.stat().st_size
    if size > MAX_LOG_BYTES:
        raise SimulatorLogError(f"Simulator app log exceeds {MAX_LOG_BYTES} bytes")
    try:
        text = path.read_text(encoding="utf-8-sig", errors="strict")
    except UnicodeError as error:
        raise SimulatorLogError("Simulator app log is not valid UTF-8") from error
    return validate_text(
        text,
        maximum_known_warnings,
        maximum_known_warnings_per_process,
        expected_pids,
    )


def run_self_test() -> None:
    warning = (
        "2026-09-02 18:57:50.666 E  INFINIDIVE[39107:1ac09] "
        "[com.matan.infinidive:ERROR] servers/display/display_server.cpp:536:"
        "mouse_get_position(): Mouse is not supported by this display server. "
        "Method/function failed. Returning: Point2i()"
    )
    clean_record = "2026-09-02 18:57:51.000 D  INFINIDIVE[39107:1ac09] lifecycle active"
    if validate_text(f"{clean_record}\n", 0, 0, {"39107"}) != (0, 0):
        raise AssertionError("clean log did not validate")
    if validate_text(f"{clean_record}\n{warning}\n", 1, 1, {"39107"}) != (1, 0):
        raise AssertionError("reviewed warning did not validate exactly once")

    second_process_warning = warning.replace("[39107:1ac09]", "[39108:1ac0a]")
    if validate_text(
        f"{warning}\n{second_process_warning}\n", 2, 1, {"39107", "39108"}
    ) != (2, 0):
        raise AssertionError("one reviewed warning per isolated process did not validate")

    platform_noise = [
        "2026-09-02 18:57:45.455 E  INFINIDIVE[39107:1ac09] "
        "[com.apple.CFBundle:plugin] AddInstanceForFactory: No factory registered for id "
        "<CFUUID 0x60000022f120> F8BB1C28-BAE8-11D6-9C31-00039315CD46",
        "2026-09-02 18:57:45.801 E  INFINIDIVE[39107:1ac63] "
        "[com.apple.locationd.Core:Core] {\"msg\":\"file does not exist... clearing\", "
        "\"file\":/RuntimeRoot/private/var/Managed Preferences/kCFPreferencesCurrentUser/"
        "com.apple.CoreMotion.plist, \"error\":Error Domain=NSCocoaErrorDomain Code=260 "
        "\"The file “com.apple.CoreMotion.plist” couldn’t be opened because there is no such file.\" "
        "UserInfo={NSFilePath=/RuntimeRoot/private/var/Managed Preferences/"
        "com.apple.CoreMotion.plist, NSURL=file:///RuntimeRoot/private/var/Managed%20Preferences/"
        "com.apple.CoreMotion.plist, NSUnderlyingError=0x600000c48c30 "
        "{Error Domain=NSPOSIXErrorDomain Code=2 \"No such file or directory\"}}}",
        "2026-09-02 18:57:46.000 E  INFINIDIVE[39107:1ac30] "
        "[com.apple.app_launch_measurement:General] Failed to send CA Event for app launch "
        "measurements for ca_event_type: 0 event_name: "
        "com.apple.app_launch_measurement.FirstFramePresentationMetric",
        "2026-09-02 18:58:06.860 E  INFINIDIVE[39107:1ac09] "
        "[com.apple.app_launch_measurement:General] CA Telemetry timedout after 20 seconds "
        "due to app launch has not reached all responsive milestones",
        "2026-09-02 18:57:47.987 E  INFINIDIVE[39107:1ac42] "
        "[com.apple.coreaudio:AMCP] HALC_ProxyIOContext.cpp:1623 "
        "HALC_ProxyIOContext::IOWorkLoop: skipping cycle due to overload",
    ]
    if validate_text("\n".join(platform_noise) + "\n", 0, 0, {"39107"}) != (0, 5):
        raise AssertionError("reviewed Simulator platform-noise fixtures did not validate")

    rejected = [
        ("", 0),
        ("ordinary system line without an app record\n", 0),
        ("INFINIDIVE[1:a]\n", 0),
        (f"{warning}\n{warning}\n", 1),
        ("fatal error before normal output\n" + "ordinary\n" * 200_000, 0),
        ("[com.matan.infinidive:SCRIPT ERROR] broken call\n", 0),
        (f"{clean_record}\nERROR: continuation failure\n", 0),
        (f"{clean_record}\nERROR:\n", 0),
        (f"{clean_record}\nERROR:[E42]\n", 0),
        (f"{clean_record}\nError:failed\n", 0),
        (f"{clean_record}\nSegmentation fault: 11\n", 0),
        (f"{clean_record}\nSIGABRT\n", 0),
        (f"{clean_record}\nSIGSEGV\n", 0),
        (f"{clean_record}\nEXC_RESOURCE\n", 0),
        (f"{clean_record}\nUnhandled exception\n", 0),
        (f"{clean_record}\nAssertion failed\n", 0),
        (
            f"{clean_record}\n2026-09-02 18:57:52.000 Df INFINIDIVE[39107:1ac09] "
            "ERROR: deferred renderer failed\n",
            0,
        ),
        (
            "2026-09-02 18:57:51.000 E  INFINIDIVE[39107:1ac09] "
            "[com.matan.infinidive:rendering] GPU resource creation failed\n",
            0,
        ),
        (
            "2026-09-02 18:57:51.000 Fault INFINIDIVE[39107:1ac09] "
            "[com.matan.infinidive:runtime] unclassified runtime fault\n",
            0,
        ),
        (
            "2026-09-02 18:57:51.000 E  INFINIDIVE[39107:1ac09] "
            "[com.apple.runtime-issues:Swift] runtime invariant violated\n",
            0,
        ),
        (
            "2026-09-02 18:57:51.000 F  INFINIDIVE[39107:1ac09] "
            "unclassified framework failure\n",
            0,
        ),
        ("prefix fatal error " + warning + "\n", 1),
        (warning.replace("Point2i()", "Point2i(1, 1)") + "\n", 1),
    ]
    for fixture, limit in rejected:
        try:
            validate_text(fixture, limit, 1)
        except SimulatorLogError:
            continue
        raise AssertionError("Simulator log validator accepted a negative fixture")
    try:
        validate_text(f"{warning}\n{warning}\n", 2, 1)
    except SimulatorLogError:
        pass
    else:
        raise AssertionError("per-process warning limit accepted two warnings from one app process")

    try:
        validate_text(f"{clean_record}\n", 0, 0, {"39107", "39108"})
    except SimulatorLogError:
        pass
    else:
        raise AssertionError("expected-PID completeness accepted a missing app process")
    try:
        validate_text(f"{clean_record}\n", 0, 0, {"39108"})
    except SimulatorLogError:
        pass
    else:
        raise AssertionError("expected-PID attribution accepted an unexpected app process")

    poisoned_coremotion = platform_noise[1].replace(
        "/RuntimeRoot/private", "/RuntimeRoot/fatal error/private", 1
    )
    try:
        validate_text(f"{poisoned_coremotion}\n", 0, 0, {"39107"})
    except SimulatorLogError:
        pass
    else:
        raise AssertionError("platform-noise exception accepted an injected fatal error")

    audio_lines = []
    audio_template = platform_noise[4]
    for _index in range(65):
        audio_lines.append(audio_template)
    try:
        validate_text("\n".join(audio_lines) + "\n", 0, 0, {"39107"})
    except SimulatorLogError:
        pass
    else:
        raise AssertionError("platform-noise per-process cap accepted 65 CoreAudio records")

    six_process_audio_lines = []
    six_process_ids = {str(39_107 + index) for index in range(6)}
    for pid in sorted(six_process_ids, key=int):
        for _index in range(64):
            six_process_audio_lines.append(
                audio_template.replace("[39107:1ac42]", f"[{pid}:1ac42]")
            )
    if validate_text(
        "\n".join(six_process_audio_lines) + "\n", 0, 0, six_process_ids
    ) != (0, 384):
        raise AssertionError("six-process CoreAudio allowance did not validate exactly")

    with tempfile.TemporaryDirectory(prefix="infinidive-ios-log-self-test-") as root:
        path = Path(root) / "simulator-app.log"
        path.write_text(f"{warning}\n", encoding="utf-8")
        if validate_file(path, 1, 1, {"39107"}) != (1, 0):
            raise AssertionError("file-level validation did not preserve the warning count")
        invalid_utf8 = Path(root) / "invalid-utf8.log"
        invalid_utf8.write_bytes(b"\xff\xfe\xfa")
        try:
            validate_file(invalid_utf8, 0, 0, {"39107"})
        except SimulatorLogError:
            pass
        else:
            raise AssertionError("file-level validation accepted invalid UTF-8")
        oversized = Path(root) / "oversized.log"
        with oversized.open("wb") as handle:
            handle.truncate(MAX_LOG_BYTES + 1)
        try:
            validate_file(oversized, 0, 0, {"39107"})
        except SimulatorLogError:
            pass
        else:
            raise AssertionError("file-level validation accepted an oversized log")
    print("iOS Simulator app-log validator self-test: PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", nargs="?", type=Path)
    parser.add_argument("--maximum-known-mouse-warnings", type=int)
    parser.add_argument("--maximum-known-mouse-warnings-per-process", type=int)
    parser.add_argument("--expected-pid", action="append")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        if (
            args.log is not None
            or args.maximum_known_mouse_warnings is not None
            or args.maximum_known_mouse_warnings_per_process is not None
            or args.expected_pid is not None
        ):
            parser.error("--self-test accepts no log inputs")
        run_self_test()
        return 0
    if (
        args.log is None
        or args.maximum_known_mouse_warnings is None
        or args.maximum_known_mouse_warnings_per_process is None
        or not args.expected_pid
    ):
        parser.error(
            "provide a log, both known-warning limits, and at least one --expected-pid"
        )
    if len(set(args.expected_pid)) != len(args.expected_pid):
        parser.error("--expected-pid values must be unique")
    try:
        known_count, platform_count = validate_file(
            args.log,
            args.maximum_known_mouse_warnings,
            args.maximum_known_mouse_warnings_per_process,
            set(args.expected_pid),
        )
    except SimulatorLogError as error:
        print(f"iOS Simulator app-log validation: FAIL: {error}")
        return 1
    print(
        "iOS Simulator app-log validation: PASS "
        f"({known_count} bounded Godot touch-only mouse warning(s), "
        f"{platform_count} exact bounded Simulator platform-noise record(s), "
        f"{len(args.expected_pid)} expected app process(es))"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
