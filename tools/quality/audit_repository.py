#!/usr/bin/env python3
"""Create a read-only, reproducible quality baseline for iliprestō."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
from dataclasses import asdict, dataclass
from pathlib import Path

EXCLUDED_PARTS = {
    ".dart_tool", ".git", ".idea", ".vscode", ".backups", "backups",
    "build", "build_logs", "coverage", "downloads", "node_modules",
    "release_apk",
}
SOURCE_EXTENSIONS = {".dart", ".js", ".mjs", ".cjs", ".ts", ".tsx"}
DOC_EXTENSIONS = {".md", ".mdx", ".rst"}
TEST_RE = re.compile(r"(?:^|[_-])test(?:[_-]|\.)|_test\.dart$", re.I)
ANALYZER_IGNORE_RE = re.compile(r"^\s{4}([a-z0-9_]+):\s*ignore\s*$", re.M)


@dataclass(frozen=True)
class FileMetric:
    path: str
    lines: int
    bytes: int
    kind: str


def excluded(path: Path, root: Path) -> bool:
    relative = path.relative_to(root)
    if set(relative.parts) & EXCLUDED_PARTS:
        return True
    return len(relative.parts) >= 2 and relative.parts[:2] == ("functions", "lib")


def classify(relative: Path) -> str:
    normalized = relative.as_posix().lower()
    suffix = relative.suffix.lower()
    if TEST_RE.search(relative.name) or normalized.startswith("test/") or "/test/" in f"/{normalized}/":
        return "test"
    if suffix in DOC_EXTENSIONS:
        return "documentation"
    if normalized.startswith(".github/workflows/") and suffix in {".yml", ".yaml"}:
        return "workflow"
    # `docs/` is also the Firebase Hosting build output. Only authored Markdown
    # is documentation; generated JS/assets must not inflate source metrics.
    if normalized.startswith("docs/"):
        return "other"
    if suffix in SOURCE_EXTENSIONS:
        return "source"
    return "other"


def line_count(path: Path) -> int:
    try:
        return sum(1 for _ in path.open("r", encoding="utf-8", errors="replace"))
    except OSError:
        return 0


def lcov_summary(path: Path) -> dict[str, float | int | None]:
    if not path.exists():
        return {"lines_found": 0, "lines_hit": 0, "percent": None}
    found = hit = 0
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("LF:"):
            found += int(line[3:] or 0)
        elif line.startswith("LH:"):
            hit += int(line[3:] or 0)
    return {
        "lines_found": found,
        "lines_hit": hit,
        "percent": round(hit * 100 / found, 2) if found else 0.0,
    }


def pattern_counts(dart_files: list[Path]) -> dict[str, int]:
    patterns = {
        "set_state_calls": r"\bsetState\s*\(",
        "stream_builders": r"\bStreamBuilder\s*<",
        "future_builders": r"\bFutureBuilder\s*<",
        "firestore_singletons": r"FirebaseFirestore\.instance",
        "firestore_snapshots": r"\.snapshots\s*\(",
        "firestore_gets": r"\.get\s*\(",
        "debug_prints": r"\b(?:print|debugPrint)\s*\(",
        "cached_network_images": r"\bCachedNetworkImage\s*\(",
    }
    compiled = {name: re.compile(pattern) for name, pattern in patterns.items()}
    totals = {name: 0 for name in patterns}
    for path in dart_files:
        text = path.read_text(encoding="utf-8", errors="replace")
        for name, regex in compiled.items():
            totals[name] += len(regex.findall(text))
    return totals


def table(rows: list[tuple[str, object]]) -> str:
    return "\n".join(["| Indicateur | Valeur |", "|---|---:|"] + [f"| {k} | {v} |" for k, v in rows])


def baseline_md(report: dict) -> str:
    coverage = report["coverage"]["percent"]
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
        ("Couverture Flutter", "non mesurée" if coverage is None else f"{coverage} %"),
    ]
    pattern_rows = [(name.replace("_", " ").capitalize(), value) for name, value in report["patterns"].items()]
    return f"""# Baseline qualité iliprestō

Générée le `{report['generated_at_utc']}` depuis `{report['git_ref']}`.

## Résumé

{table(rows)}

## Indicateurs de structure et de performance potentielle

{table(pattern_rows)}

## Interprétation

- Un fichier de plus de 1 200 lignes est critique pour la maintenabilité.
- Les compteurs Flutter et Firestore sont des signaux à examiner, pas des erreurs automatiques.
- La couverture est fiable après `flutter test --coverage`.
"""


def oversized_md(metrics: list[FileMetric]) -> str:
    items = sorted((m for m in metrics if m.kind == "source" and m.lines > 500), key=lambda m: m.lines, reverse=True)
    lines = [
        "# Fichiers source surdimensionnés", "",
        "Seuils : surveillance à 500 lignes, priorité haute à 800 lignes, criticité à 1 200 lignes.", "",
        "| Priorité | Fichier | Lignes |", "|---|---|---:|",
    ]
    for item in items:
        priority = "P0" if item.lines > 1200 else "P1" if item.lines > 800 else "P2"
        lines.append(f"| {priority} | `{item.path}` | {item.lines} |")
    if not items:
        lines.append("| — | Aucun fichier au-dessus du seuil | 0 |")
    return "\n".join(lines) + "\n"


def debt_md(report: dict, metrics: list[FileMetric]) -> str:
    rows: list[tuple[str, str, str, str, str]] = []
    for index, item in enumerate(sorted((m for m in metrics if m.kind == "source" and m.lines > 500), key=lambda m: m.lines, reverse=True), 1):
        priority = "P0" if item.lines > 1200 else "P1" if item.lines > 800 else "P2"
        rows.append((f"TECH-{index:03d}", priority, item.path, f"Fichier de {item.lines} lignes à découper par responsabilité.", "À qualifier"))
    next_id = len(rows) + 1
    ignored = report["analyzer_ignored_rules"]
    if ignored:
        rows.append((f"TECH-{next_id:03d}", "P1", "analysis_options.yaml", f"{len(ignored)} diagnostics sont ignorés globalement.", "À traiter progressivement"))
    lines = [
        "# Registre initial de dette technique", "",
        "Rapport généré automatiquement ; le suivi opérationnel se fait dans GitHub Issues.", "",
        "| ID | Priorité | Zone | Dette observée | Statut |", "|---|---|---|---|---|",
    ]
    lines += [f"| {a} | {b} | `{c}` | {d} | {e} |" for a, b, c, d, e in rows]
    if not rows:
        lines.append("| — | — | — | Aucune dette détectée par les règles actuelles. | — |")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--output-dir", default="quality_reports")
    parser.add_argument("--git-ref", default=os.environ.get("GITHUB_SHA", "local"))
    parser.add_argument("--enforce", action="store_true")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    output = (root / args.output_dir).resolve()
    output.mkdir(parents=True, exist_ok=True)

    metrics: list[FileMetric] = []
    dart_files: list[Path] = []
    for path in root.rglob("*"):
        if not path.is_file() or excluded(path, root):
            continue
        relative = path.relative_to(root)
        kind = classify(relative)
        if kind in {"source", "test", "documentation", "workflow"}:
            metrics.append(FileMetric(relative.as_posix(), line_count(path), path.stat().st_size, kind))
        if kind == "source" and relative.suffix.lower() == ".dart":
            dart_files.append(path)

    by_kind = {kind: [m for m in metrics if m.kind == kind] for kind in ("source", "test", "documentation", "workflow")}
    analyzer_path = root / "analysis_options.yaml"
    ignored = ANALYZER_IGNORE_RE.findall(analyzer_path.read_text(encoding="utf-8", errors="replace")) if analyzer_path.exists() else []
    gates_path = root / "quality" / "quality-gates.json"
    gates = json.loads(gates_path.read_text(encoding="utf-8")) if gates_path.exists() else {}

    report = {
        "schema_version": 2,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "git_ref": args.git_ref,
        "counts": {
            "source_files": len(by_kind["source"]),
            "source_lines": sum(m.lines for m in by_kind["source"]),
            "test_files": len(by_kind["test"]),
            "test_lines": sum(m.lines for m in by_kind["test"]),
            "documentation_files": len(by_kind["documentation"]),
            "workflow_files": len(by_kind["workflow"]),
        },
        "oversized": {
            "over_500": sum(m.lines > 500 for m in by_kind["source"]),
            "over_800": sum(m.lines > 800 for m in by_kind["source"]),
            "over_1200": sum(m.lines > 1200 for m in by_kind["source"]),
        },
        "analyzer_ignored_rules": sorted(set(ignored)),
        "coverage": lcov_summary(root / "coverage" / "lcov.info"),
        "patterns": pattern_counts(dart_files),
        "largest_source_files": [asdict(m) for m in sorted(by_kind["source"], key=lambda m: m.lines, reverse=True)[:50]],
        "quality_gates": gates,
    }

    (output / "baseline.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (output / "baseline.md").write_text(baseline_md(report), encoding="utf-8")
    (output / "oversized-files.md").write_text(oversized_md(metrics), encoding="utf-8")
    (output / "technical-debt-register.md").write_text(debt_md(report, metrics), encoding="utf-8")
    print(json.dumps(report["counts"], ensure_ascii=False))

    if not args.enforce:
        return 0
    max_lines = int(gates.get("source", {}).get("hard_max_lines", 0) or 0)
    min_coverage = float(gates.get("coverage", {}).get("minimum_percent", 0) or 0)
    failures: list[str] = []
    if max_lines and any(m.lines > max_lines for m in by_kind["source"]):
        failures.append(f"a source file exceeds {max_lines} lines")
    measured = report["coverage"]["percent"]
    if measured is not None and measured < min_coverage:
        failures.append(f"coverage {measured}% is below {min_coverage}%")
    for failure in failures:
        print(f"QUALITY_GATE_FAILED: {failure}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
