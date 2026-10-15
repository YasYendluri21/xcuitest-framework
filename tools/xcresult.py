"""Parse an .xcresult bundle into structured results.

`xcodebuild` prints a readable log and writes a result bundle; neither is directly usable by
anything downstream. This reads the bundle through `xcrun xcresulttool` and flattens it into plain
dataclasses, which is what makes the rest of the tooling — reporting, flake tracking, CI
annotations — possible without re-parsing console output with regexes.

xcresulttool's JSON shape changed in Xcode 16: the legacy `--format json` graph now requires
`--legacy`, and a flatter `test-results` API was added. This handles both, because a test tool that
breaks on an Xcode upgrade is worse than no tool.
"""

from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class TestFailure:
    message: str
    file: str | None = None
    line: int | None = None


@dataclass
class TestCase:
    suite: str
    name: str
    # Vocabulary differs between the two xcresulttool APIs: the modern one says "Passed",
    # the legacy graph says "Success". Both are normalised by `passed` below.
    status: str
    duration: float
    failures: list[TestFailure] = field(default_factory=list)

    PASSING = {"Passed", "Success", "Expected Failure"}
    SKIPPED = {"Skipped"}

    @property
    def passed(self) -> bool:
        return self.status in TestCase.PASSING

    @property
    def identifier(self) -> str:
        return f"{self.suite}/{self.name}"


@dataclass
class TestRun:
    cases: list[TestCase]

    @property
    def total(self) -> int:
        return len(self.cases)

    @property
    def failed(self) -> list[TestCase]:
        return [c for c in self.cases if not c.passed and c.status not in TestCase.SKIPPED]

    @property
    def skipped(self) -> list[TestCase]:
        return [c for c in self.cases if c.status in TestCase.SKIPPED]

    @property
    def duration(self) -> float:
        return sum(c.duration for c in self.cases)

    @property
    def slowest(self) -> list[TestCase]:
        return sorted(self.cases, key=lambda c: c.duration, reverse=True)


def _run(args: list[str]) -> str:
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"{' '.join(args[:3])}… failed: {result.stderr.strip()[:400]}")
    return result.stdout


def parse(bundle: Path) -> TestRun:
    """Read a result bundle. Tries the modern API first, falls back to the legacy graph."""
    if not bundle.exists():
        raise FileNotFoundError(f"No result bundle at {bundle}")

    try:
        return _parse_modern(bundle)
    except (RuntimeError, KeyError, json.JSONDecodeError):
        return _parse_legacy(bundle)


def _parse_modern(bundle: Path) -> TestRun:
    """Xcode 16+ `test-results tests` — a flat tree of suites and cases."""
    payload = json.loads(
        _run(["xcrun", "xcresulttool", "get", "test-results", "tests",
              "--path", str(bundle), "--compact"])
    )

    cases: list[TestCase] = []

    def walk(node: dict, suite: str) -> None:
        kind = node.get("nodeType")
        name = node.get("name", "")

        if kind == "Test Case":
            failures = [
                TestFailure(message=child.get("name", "").strip())
                for child in node.get("children", [])
                if child.get("nodeType") == "Failure Message"
            ]
            cases.append(
                TestCase(
                    suite=suite,
                    name=name,
                    status=node.get("result", "Unknown"),
                    duration=_seconds(node.get("duration")),
                    failures=failures,
                )
            )
            return

        # Suites nest, so carry the innermost suite name down to the cases.
        next_suite = name if kind in {"Test Suite", "Unit test bundle", "UI test bundle"} else suite
        for child in node.get("children", []):
            walk(child, next_suite)

    for node in payload.get("testNodes", []):
        walk(node, node.get("name", ""))

    if not cases:
        raise RuntimeError("modern parser found no test cases")

    return TestRun(cases=cases)


def _parse_legacy(bundle: Path) -> TestRun:
    """Pre-Xcode-16 object graph. Requires walking refs by id, hence the two-step lookup."""
    root = json.loads(
        _run(["xcrun", "xcresulttool", "get", "--legacy", "--format", "json", "--path", str(bundle)])
    )

    cases: list[TestCase] = []

    def value(node: dict | None, key: str, default=None):
        return (node or {}).get(key, {}).get("_value", default)

    refs = [
        value(action.get("actionResult", {}).get("testsRef"), "id")
        for action in root.get("actions", {}).get("_values", [])
    ]

    for ref in filter(None, refs):
        summaries = json.loads(
            _run(["xcrun", "xcresulttool", "get", "--legacy", "--format", "json",
                  "--path", str(bundle), "--id", ref])
        )
        _walk_legacy(summaries, "", cases)

    return TestRun(cases=cases)


def _walk_legacy(node: dict, suite: str, out: list[TestCase]) -> None:
    def value(n: dict, key: str, default=None):
        return n.get(key, {}).get("_value", default)

    if node.get("_type", {}).get("_name") == "ActionTestMetadata":
        out.append(
            TestCase(
                suite=suite,
                name=value(node, "name", ""),
                status=value(node, "testStatus", "Unknown"),
                duration=float(value(node, "duration", 0) or 0),
            )
        )
        return

    name = value(node, "name", suite)
    for key in ("summaries", "testableSummaries", "tests", "subtests"):
        for child in node.get(key, {}).get("_values", []):
            _walk_legacy(child, name or suite, out)


def _seconds(raw) -> float:
    """Durations arrive as a float or as strings like '12.3s' / '1m 4s'."""
    if raw is None:
        return 0.0
    if isinstance(raw, (int, float)):
        return float(raw)

    text = str(raw).strip()
    total = 0.0
    for part in text.replace(",", " ").split():
        try:
            if part.endswith("ms"):
                total += float(part[:-2]) / 1000
            elif part.endswith("m"):
                total += float(part[:-1]) * 60
            elif part.endswith("s"):
                total += float(part[:-1])
            else:
                total += float(part)
        except ValueError:
            continue
    return total
