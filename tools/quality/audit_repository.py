#!/usr/bin/env python3
"""Generate a reproducible quality baseline for the iliprestō repository.

The script uses only the Python standard library so it can run locally and in
GitHub Actions without additional dependencies. It is intentionally read-only:
it scans the repository and writes reports below the requested output folder.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable


EXCLUDED_PARTS = {
    ".dart_tool",
    ".git",
    ".idea",
    ".vscode",
    ".backups",
    "backups",
    "build",
    "build_logs",
    "coverage",
    "downloads",
    "node_modules",
    "release_apk",
}

SOURCE_EXTENSIONS = {".dart", ".js", ".mjs", ".cjs", ".ts", ".tsx"}
DOC_EXTENSIONS = {".md", ".mdx", ".rst"}
TEST_NAME_RE = re.compile(r"(?:^|[_-])test(?:[_-]|\.)|_test\.dart$", re.IGNORECASE)
ANALYZER_IGNORE_RE = re.compile(r"^\s{4}([a-z0-9_]+):\s*ignore\s*$", re.MULTILINE)


@dataclass(frozen=True)
class FileMetric:
    path: str
    lines: int
    bytes: int
    kind: str


def is_excluded(path: Path, root: Path) -> bool:
    try:
        relative = path.relative_to(root)
    except ValueError:
        return True
    parts = set(relative.parts)
    if parts & EXCLUDED_PARTS:
        return True
    if len(relative.parts) >= 2 and relative.parts[0] == "functions" and relative.parts[1] == "lib":
        return True
    return False


def iter_files(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        if path.is_file() and not is_excluded(path, root):
            yield path


def count_lines(path: Path) -> int:
    try:
        with path.open("r", encoding="utf-8", errors="replace") as handle:
            return sum(1 for _ in handle)
    except OSError:
        return 0


def classify(path: Path) -> str:
    normalized = path.as_posix().lower()
    if TEST_NAME_RE.search(path.name) or "/test/" in f"/{normalized}/" or normalized.startswith("test/"):
        return "test"
    if path.suffix.lower() in DOC_EXTENSIONS:
        return "documentation"
    if path.suffix.lower() in SOURCE_EXTENSIONS:
        return "source"
    if normalized.startswith(".github/workflows/") and path.suffix.lower() in {".yml", ".yaml"}:
        return "workflow"
    return "other"


def parse_lcov(path: Path) -> dict[str, float | int | None]:
    if not path.exists():
        return {"lines_found": 0, "lines_hit": 0, "percent": None}

    found = 0
    hit = 0
    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if raw_line.startswith("LF:"):
            found += int(raw_line[3:] or 0)
        elif raw_line.startswith("LH:"):
            hit += int(raw_line[3:] or 0)
    percent = round((hit / found) * 100, 2) if found else 0.0
    return {"lines_found": found, "lines_hit": hit, "percent": percent}


def scan_patterns(root: Path, dart_files: list[Path]) -> dict[str, int]:
    patterns = {
        "set_state_calls": re.compile(r"\bsetState\s*\("),
        "stream_builders": re.compile(r"\bStreamBuilder\s*<"),
        "future_builders": re.compile(r"\bFutureBuilder\s*<"),
        "firestore_singletons": re.compile(r"FirebaseFirestore\.instance"),
        "firestore_snapshots": re.compile(r"\.snapshots\s*\("),
        "firestore_gets": re.compile(r"\.get\s*\("),
        "debug_prints": re.compile(r"\b(?:print|debugPrint)\s*\("),
        "cached_network_images": re.compile(r"\bCachedNetworkImage\s*\("),
    }
    totals = {name: 0 for name in patterns}
    for path in dart_files:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for name, regex in patterns.items():
            totals[name] += len(regex.findall(text))
    return totals


def load_quality_gates(root: Path) -> dict:
    path = root / "quality" / "quality-gates.json"
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def markdown_table(rows: list[tuple[str, object]]) -> str:
    output = ["| Indicateur | Valeur |", "|---|---:|"]
    output.extend(f"| {label} | {value} |" for label, value in rows)
    return "\n".join(output)


def render_baseline(report: dict) -> str:
    coverage = report["coverage"]
    coverage_display = "non mesurée" if coverage["percent"] is None else f"{coverage['percent']} %"
    rows = [
        ("Fichiers source", report["counts"]["source_files"]),
        ("Lignes source", report["counts"]["source_lines"]),
        ("Fichiers de test", report["counts"]["test_files"]),
        ("Lignes de test", report["counts"]["test_lines"]),
        ("Documents techniques", report["counts"]["documentation_files"]),
        ("Workflows GitHub Actions", report["counts"]["workflow_files"]),
        ("Fichiers > 500 lignes", report["oversized"]["over_500"]),
        ("Fichiers > 800 lignes", report["oversized"]["over_800"]),
        ("Fichiers > 1 200 lignes", report["oversized"]["over_1200"]),
        ("Règles analyzer ignorées", len(report["analyzer_ignored_rules"])),
        ("Couverture Flutter", coverage_display),
    ]
    pattern_rows = [(key.replace("_", " ").capitalize(), value) for key, value in report["patterns"].items()]
    return "\n".join(
        [
            "# Baseline qualité iliprestō",
            "",
            f"Générée le `{report['generated_at_utc']}` depuis `{report['git_ref']}`.",
            "",
            "## Résumé",
            "",
            markdown_table(rows),
            "",
            "## Indicateurs de structure et de performance potentielle",
            "",
            markdown_table(pattern_rows),
            "",
            "## Interprétation",
            "",
            "- Un fichier de plus de 1 200 lignes est classé critique pour la maintenabilité.",
            "- Les appels `setState`, builders asynchrones et accès Firestore sont des indicateurs à examiner, pas des erreurs automatiques.",
            "- La couverture n'est fiable qu'après `flutter test --coverage`.",
            "- Les rapports détaillés listent les fichiers à traiter par priorité.",
            "",
        ]
    )


def render_oversized(metrics: list[FileMetric]) -> str:
    oversized = [metric for metric in metrics if metric.kind == "source" and metric.lines > 500]
    oversized.sort(key=lambda item: item.lines, reverse=True)
    lines = [
        "# Fichiers source surdimensionnés",
        "",
        "Seuils : surveillance à 500 lignes, priorité haute à 800 lignes, criticité à 1 200 lignes.",
        "",
        "| Priorité | Fichier | Lignes |",
        "|---|---|---:|",
    ]
    for metric in oversized:
        priority = "P0" if metric.lines > 1200 else "P1" if metric.lines > 800 else "P2"
        lines.append(f"| {priority} | `{metric.path}` | {metric.lines} |")
    if not oversized:
        lines.append("| — | Aucun fichier au-dessus du seuil | 0 |")
    lines.append("")
    return "\n".join(lines)


def render_debt(report: dict, metrics: list[FileMetric]) -> str:
    items: list[tuple[str, str, str, str, str]] = []
    counter = 1
    for metric in sorted(metrics, key=lambda item: item.lines, reverse=True):
        if metric.kind != "source" or metric.lines <= 500:
            continue
        priority = "P0" if metric.lines > 1200 else "P1" if metric.lines > 800 else "P2"
        items.append((f"TECH-{counter:03d}", priority, metric.path, f"Fichier de {metric.lines} lignes à découper par responsabilité.", "À qualifier"))
        counter += 1

    if report["analyzer_ignored_rules"]:
        items.append((f"TECH-{counter:03d}", "P1", "analysis_options.yaml", f"{len(report['analyzer_ignored_rules'])} catégories de diagnostics sont ignorées globalement.", "À traiter progressivement"))
        counter += 1

    if report["coverage"]["percent"] is None:
        items.append((f"TECH-{counter:03d}", "P0", "test/", "Couverture non mesurée : exécuter `flutter test --coverage` puis publier l'artefact LCOV.", "Ouvert"))

    lines = [
        "# Registre initial de dette technique",
        "",
        "Ce fichier est généré automatiquement. Les responsables, échéances et décisions doivent être suivis dans GitHub Issues.",
        "",
        "| ID | Priorité | Zone | Dette observée | Statut |",
        "|---|---|---|---|---|",
    ]
    for identifier, priority, area, description, status in items:
        lines.append(f"| {identifier} | {priority} | `{area}` | {description} | {status} |")
    if not items:
        lines.append("| — | — | — | Aucune dette détectée par les règles actuelles. | — |")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Repository root")
    parser.add_argument("--output-dir", default="quality_reports", help="Report directory")
    parser.add_argument("--git-ref", default=os.environ.get("GITHUB_SHA", "local"))
    parser.add_argument("--enforce", action="store_true", help="Apply configured hard limits")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    output_dir = (root / args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    metrics: list[FileMetric] = []
    dart_files: list[Path] = []
    for path in iter_files(root):
        suffix = path.suffix.lower()
        kind = classify(path.relative_to(root))
        if kind in {"source", "test", "documentation", "workflow"}:
            metrics.append(FileMetric(path=path.relative_to(root).as_posix(), lines=count_lines(path), bytes=path.stat().st_size, kind=kind))
        if suffix == ".dart":
            dart_files.append(path)

    analysis_options = root / "analysis_options.yaml"
    analyzer_ignored_rules: list[str] = []
    if analysis_options.exists():
        analyzer_ignored_rules = ANALYZER_IGNORE_RE.findall(analysis_options.read_text(encoding="utf-8", errors="replace"))

    source_metrics = [metric for metric in metrics if metric.kind == "source"]
    test_metrics = [metric for metric in metrics if metric.kind == "test"]
    doc_metrics = [metric for metric in metrics if metric.kind == "documentation"]
    workflow_metrics = [metric for metric in metrics if metric.kind == "workflow"]

    report = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "git_ref": args.git_ref,
        "counts": {
            "source_files": len(source_metrics),
            "source_lines": sum(metric.lines for metric in source_metrics),
            "test_files": len(test_metrics),
            "test_lines": sum(metric.lines for metric in test_metrics),
            "documentation_files": len(doc_metrics),
            "workflow_files": len(workflow_metrics),
        },
        "oversized": {
            "over_500": sum(metric.lines > 500 for metric in source_metrics),
            "over_800": sum(metric.lines > 800 for metric in source_metrics),
            "over_1200": sum(metric.lines > 1200 for metric in source_metrics),
        },
        "analyzer_ignored_rules": sorted(set(analyzer_ignored_rules)),
        "coverage": parse_lcov(root / "coverage" / "lcov.info"),
        "patterns": scan_patterns(root, dart_files),
        "largest_source_files": [asdict(metric) for metric in sorted(source_metrics, key=lambda item: item.lines, reverse=True)[:50]],
        "quality_gates": load_quality_gates(root),
    }

    (output_dir / "baseline.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (output_dir / "baseline.md").write_text(render_baseline(report), encoding="utf-8")
    (output_dir / "oversized-files.md").write_text(render_oversized(metrics), encoding="utf-8")
    (output_dir / "technical-debt-register.md").write_text(render_debt(report, metrics), encoding="utf-8")

    print(json.dumps(report["counts"], ensure_ascii=False))
    print(f"Reports written to {output_dir}")

    if args.enforce:
        gates = report.get("quality_gates", {})
        max_file_lines = int(gates.get("source", {}).get("hard_max_lines", 0) or 0)
        min_coverage = float(gates.get("coverage", {}).get("minimum_percent", 0) or 0)
        failures: list[str] = []
        if max_file_lines:
            offenders = [metric.path for metric in source_metrics if metric.lines > max_file_lines]
            if offenders:
                failures.append(f"{len(offenders)} source files exceed {max_file_lines} lines")
        measured = report["coverage"]["percent"]
        if measured is not None and measured < min_coverage:
            failures.append(f"coverage {measured}% is below {min_coverage}%")
        if failures:
            for failure in failures:
                print(f"QUALITY_GATE_FAILED: {failure}")
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
