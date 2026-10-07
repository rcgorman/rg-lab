#!/usr/bin/env python3
"""Fail when an OpenSCAP HTML report differs from the reviewed findings."""

from __future__ import annotations

import argparse
import difflib
import html
import re
from pathlib import Path


FINDING_PATTERN = re.compile(
    r'<div class="panel panel-default rule-detail '
    r'rule-detail-(fail|error|unknown)[^>]*>.*?'
    r'<td class="rule-id col-md-9">(.*?)</td>',
    re.DOTALL,
)


def read_expected(path: Path) -> list[str]:
    return sorted(
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    )


def read_actual(path: Path) -> list[str]:
    report = path.read_text(encoding="utf-8")
    findings = {
        f"{result} {html.unescape(re.sub(r'<[^>]+>', '', rule_id)).strip()}"
        for result, rule_id in FINDING_PATTERN.findall(report)
    }
    if not findings:
        raise SystemExit("No fail/error/unknown findings parsed from CIS report")
    return sorted(findings)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("expected", type=Path)
    args = parser.parse_args()

    expected = read_expected(args.expected)
    actual = read_actual(args.report)
    if actual == expected:
        print(f"CIS findings match reviewed baseline ({len(actual)} findings)")
        return 0

    print("CIS findings changed; review the report and update documentation intentionally")
    print(
        "\n".join(
            difflib.unified_diff(
                expected,
                actual,
                fromfile=str(args.expected),
                tofile=str(args.report),
                lineterm="",
            )
        )
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
