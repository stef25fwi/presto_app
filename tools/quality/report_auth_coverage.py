#!/usr/bin/env python3
"""Affiche la couverture LCOV détaillée du périmètre Auth critique."""

from __future__ import annotations

import json
import subprocess
from fnmatch import fnmatchcase
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = ROOT / "quality" / "critical-coverage.json"
LCOV_PATH = ROOT / "coverage" / "lcov.info"


def _git_authored_dart_files() -> set[str]:
    output = subprocess.check_output(
        ["git", "ls-files", "lib"],
        cwd=ROOT,
        text=True,
    )
    return {
        path
        for path in output.splitlines()
        if path.endswith(".dart")
        and not path.endswith((".g.dart", ".freezed.dart"))
    }


def _auth_patterns() -> list[str]:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    module = next(
        item for item in config["modules"] if item["id"] == "authentication"
    )
    return list(module["patterns"])


def _lcov_records() -> dict[str, list[tuple[int, int]]]:
    if not LCOV_PATH.exists():
        raise SystemExit(
            "coverage/lcov.info absent. Lancez d'abord flutter test --coverage."
        )

    records: dict[str, list[tuple[int, int]]] = {}
    current: str | None = None
    lines: list[tuple[int, int]] = []

    for raw in LCOV_PATH.read_text(encoding="utf-8").splitlines():
        if raw.startswith("SF:"):
            current = raw[3:].replace("\\", "/")
            marker = f"{ROOT.as_posix()}/"
            if marker in current:
                current = current.split(marker, 1)[1]
            lines = []
        elif raw.startswith("DA:") and current:
            line_number, hits = raw[3:].split(",", 1)
            lines.append((int(line_number), int(hits)))
        elif raw == "end_of_record" and current:
            records[current] = lines
            current = None
            lines = []

    return records


def _ranges(values: list[int]) -> str:
    if not values:
        return "-"

    result: list[str] = []
    start = previous = values[0]
    for value in values[1:]:
        if value == previous + 1:
            previous = value
            continue
        result.append(str(start) if start == previous else f"{start}-{previous}")
        start = previous = value
    result.append(str(start) if start == previous else f"{start}-{previous}")
    return ", ".join(result)


def main() -> None:
    patterns = _auth_patterns()
    authored_files = _git_authored_dart_files()
    auth_files = sorted(
        path
        for path in authored_files
        if any(fnmatchcase(path, pattern) for pattern in patterns)
    )
    records = _lcov_records()

    rows: list[tuple[int, float, str, int, int, list[int]]] = []
    total_lines = 0
    covered_lines = 0

    for path in auth_files:
        file_lines = records.get(path, [])
        total = len(file_lines)
        covered = sum(1 for _, hits in file_lines if hits > 0)
        uncovered = [line for line, hits in file_lines if hits == 0]
        percent = 100 * covered / total if total else 0.0
        rows.append((total - covered, percent, path, covered, total, uncovered))
        total_lines += total
        covered_lines += covered

    print("COUVERTURE AUTH PAR FICHIER")
    print("=" * 110)
    for missing, percent, path, covered, total, uncovered in sorted(
        rows,
        key=lambda row: (-row[0], row[1], row[2]),
    ):
        suffix = " ABSENT LCOV" if total == 0 else ""
        print(
            f"{percent:6.2f}% {covered:4}/{total:<4} "
            f"reste {missing:4} {path}{suffix}"
        )
        if uncovered:
            print(f"         lignes non couvertes : {_ranges(uncovered)}")

    percent = 100 * covered_lines / total_lines if total_lines else 0.0
    print("=" * 110)
    print(f"AUTH GLOBAL : {covered_lines}/{total_lines} = {percent:.2f}%")
    print(f"LIGNES RESTANTES POUR 100 % : {total_lines - covered_lines}")
    print(
        "FICHIERS AUTH ABSENTS DU LCOV : "
        f"{sum(1 for path in auth_files if path not in records)}"
    )


if __name__ == "__main__":
    main()
