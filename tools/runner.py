#!/usr/bin/env python3
"""Run the UI suite and report on it.

What this adds over calling `xcodebuild test` directly:

  * picks a simulator by name instead of requiring a UDID nobody remembers
  * shards the suite across parallel simulator clones for CI
  * parses the result bundle into structured output rather than console text
  * writes a Markdown summary and a JSON artefact, and sets a non-zero exit on failure
  * flags tests slower than a threshold, which is how a suite's runtime is kept honest

Usage:
    python3 tools/runner.py                       # whole suite
    python3 tools/runner.py --only LoginTests     # one class
    python3 tools/runner.py --shard 1/3           # CI shard
    python3 tools/runner.py --device "iPhone 16"  # pick a simulator
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

from xcresult import TestRun, parse

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "BluDelivery.xcodeproj"
SCHEME = "BluDelivery"
BUNDLE = "BluDeliveryUITests"
SLOW_TEST_SECONDS = 20.0


def simulator_udid(name: str) -> str:
    """Resolve a simulator name to a UDID.

    Names are ambiguous across runtimes — there can be an 'iPhone 16 Pro' on both iOS 18 and 26 —
    so passing a bare name to xcodebuild fails with an unhelpful error. Resolving here means the
    caller can use a name and the toolchain gets something unambiguous.
    """
    payload = json.loads(
        subprocess.run(
            ["xcrun", "simctl", "list", "devices", "available", "--json"],
            capture_output=True, text=True, check=True,
        ).stdout
    )

    matches = [
        (runtime, device)
        for runtime, devices in payload["devices"].items()
        for device in devices
        if device["name"] == name
    ]

    if not matches:
        available = sorted({d["name"] for ds in payload["devices"].values() for d in ds})
        raise SystemExit(f"No simulator named {name!r}.\nAvailable: {', '.join(available[:12])}…")

    # Newest runtime last in simctl's ordering; take it so we test the current OS by default.
    runtime, device = matches[-1]
    print(f"  simulator: {name} ({runtime.rsplit('.', 1)[-1]})")
    return device["udid"]


def build_command(udid: str, result_path: Path, only: str | None, shard: str | None) -> list[str]:
    command = [
        "xcodebuild", "test",
        "-project", str(PROJECT),
        "-scheme", SCHEME,
        "-destination", f"id={udid}",
        "-resultBundlePath", str(result_path),
    ]

    if only:
        target = only if "/" in only else f"{BUNDLE}/{only}"
        command += ["-only-testing", target]

    if shard:
        index, total = (int(part) for part in shard.split("/"))
        # xcodebuild shards by clone, distributing test classes across parallel simulators.
        command += [
            "-parallel-testing-enabled", "YES",
            "-maximum-parallel-testing-workers", str(total),
            "-test-iterations", "1",
        ]
        print(f"  shard {index} of {total}")

    return command


def summarize(run: TestRun, elapsed: float) -> str:
    passed = run.total - len(run.failed) - len(run.skipped)
    status = "PASSED" if not run.failed else "FAILED"

    lines = [
        f"# UI test run — {status}",
        "",
        f"**{passed} passed** · {len(run.failed)} failed · {len(run.skipped)} skipped "
        f"· {elapsed:.0f}s wall · {run.duration:.0f}s in tests",
        "",
    ]

    if run.failed:
        lines += ["## Failures", ""]
        for case in run.failed:
            lines.append(f"**{case.identifier}** ({case.duration:.1f}s)")
            for failure in case.failures:
                lines.append(f"> {failure.message}")
            lines.append("")

    slow = [c for c in run.slowest if c.duration > SLOW_TEST_SECONDS]
    if slow:
        lines += [
            f"## Slower than {SLOW_TEST_SECONDS:.0f}s",
            "",
            "| Test | Duration |",
            "| --- | ---: |",
            *[f"| {c.identifier} | {c.duration:.1f}s |" for c in slow],
            "",
        ]

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the BluDelivery UI suite.")
    parser.add_argument("--device", default="iPhone 16 Pro")
    parser.add_argument("--only", help="A test class or class/method")
    parser.add_argument("--shard", help="CI shard as index/total, e.g. 1/3")
    parser.add_argument("--results", default="TestResults.xcresult")
    args = parser.parse_args()

    result_path = ROOT / args.results
    subprocess.run(["rm", "-rf", str(result_path)], check=False)

    print("Running UI tests")
    udid = simulator_udid(args.device)

    started = time.monotonic()
    completed = subprocess.run(
        build_command(udid, result_path, args.only, args.shard),
        cwd=ROOT, capture_output=True, text=True,
    )
    elapsed = time.monotonic() - started

    try:
        run = parse(result_path)
    except Exception as error:  # noqa: BLE001 — a parse failure must not hide the build failure
        print(f"\nCould not parse {result_path.name}: {error}")
        print(completed.stdout[-3000:] or completed.stderr[-3000:])
        return completed.returncode or 1

    report = summarize(run, elapsed)
    print("\n" + report)

    (ROOT / "test-report.md").write_text(report)
    (ROOT / "test-results.json").write_text(
        json.dumps(
            {
                "total": run.total,
                "failed": [c.identifier for c in run.failed],
                "skipped": [c.identifier for c in run.skipped],
                "durations": {c.identifier: round(c.duration, 2) for c in run.cases},
            },
            indent=2,
        )
    )
    print("Wrote test-report.md and test-results.json")

    return 1 if run.failed else 0


if __name__ == "__main__":
    sys.exit(main())
