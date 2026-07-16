#!/usr/bin/env python3
"""Select high-value Flutter coverage targets from an LCOV report.

The selector is deterministic and intentionally never edits coverage thresholds,
excludes files, or generates fake tests. It emits JSON and Markdown consumed by
GitHub Actions. The JSON contains one primary target for backward compatibility
and one target per priority domain so independent coverage waves can run in
parallel without duplicating the same domain.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

PRIORITY_RULES: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("payments", ("payment", "stripe", "subscription", "billing", "checkout")),
    ("publication", ("publish", "listing", "offer", "annonce")),
    ("messaging", ("message", "messaging", "chat", "conversation", "thread")),
    ("administration", ("admin", "moderation", "dashboard")),
    ("authentication", ("auth", "login", "register", "password", "credential")),
)

EXCLUDED_PATH_PARTS = (
    "/generated/",
    ".g.dart",
    ".freezed.dart",
    "firebase_options.dart",
)


@dataclass(frozen=True)
class FileCoverage:
    path: str
    found: int
    hit: int
    uncovered_lines: list[int]
    category: str
    category_rank: int

    @property
    def percent(self) -> float:
        return 100.0 if self.found == 0 else self.hit * 100.0 / self.found

    @property
    def uncovered(self) -> int:
        return self.found - self.hit


def normalise_path(raw: str) -> str:
    value = raw.replace("\\", "/")
    marker = "/lib/"
    if marker in value:
        return "lib/" + value.split(marker, 1)[1]
    return value.lstrip("./")


def classify(path: str) -> tuple[str, int]:
    lowered = path.lower()
    for rank, (category, needles) in enumerate(PRIORITY_RULES):
        if any(needle in lowered for needle in needles):
            return category, rank
    return "other", len(PRIORITY_RULES)


def parse_lcov(path: Path) -> list[FileCoverage]:
    records: list[FileCoverage] = []
    current: str | None = None
    line_hits: dict[int, int] = {}

    def flush() -> None:
        nonlocal current, line_hits
        if not current:
            return
        normalised = normalise_path(current)
        if not normalised.startswith("lib/"):
            current, line_hits = None, {}
            return
        if any(part in normalised for part in EXCLUDED_PATH_PARTS):
            current, line_hits = None, {}
            return
        found = len(line_hits)
        if found:
            hit = sum(1 for count in line_hits.values() if count > 0)
            uncovered = sorted(line for line, count in line_hits.items() if count == 0)
            category, rank = classify(normalised)
            records.append(
                FileCoverage(
                    normalised,
                    found,
                    hit,
                    uncovered,
                    category,
                    rank,
                )
            )
        current, line_hits = None, {}

    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if raw_line.startswith("SF:"):
            flush()
            current = raw_line[3:].strip()
        elif raw_line.startswith("DA:") and current:
            match = re.match(r"DA:(\d+),(\d+)", raw_line)
            if match:
                line_hits[int(match.group(1))] = int(match.group(2))
        elif raw_line == "end_of_record":
            flush()
    flush()
    return records


def compact_ranges(lines: Iterable[int], limit: int = 80) -> str:
    unique_values = sorted(set(lines))
    values = unique_values[:limit]
    if not values:
        return "aucune"
    ranges: list[str] = []
    start = previous = values[0]
    for value in values[1:]:
        if value == previous + 1:
            previous = value
            continue
        ranges.append(str(start) if start == previous else f"{start}-{previous}")
        start = previous = value
    ranges.append(str(start) if start == previous else f"{start}-{previous}")
    suffix = "…" if len(unique_values) > limit else ""
    return ", ".join(ranges) + suffix


def _target_sort_key(item: FileCoverage) -> tuple[float, int, str]:
    return (item.percent, -item.uncovered, item.path)


def choose_target(records: list[FileCoverage]) -> FileCoverage:
    candidates = [record for record in records if record.uncovered > 0]
    if not candidates:
        raise SystemExit("No uncovered production file found in LCOV report.")
    return min(
        candidates,
        key=lambda item: (
            item.category_rank,
            *_target_sort_key(item),
        ),
    )


def choose_targets_by_category(
    records: list[FileCoverage],
) -> list[FileCoverage]:
    """Return at most one uncovered target for each configured priority domain."""

    selected: list[FileCoverage] = []
    for category, _ in PRIORITY_RULES:
        candidates = [
            record
            for record in records
            if record.category == category and record.uncovered > 0
        ]
        if candidates:
            selected.append(min(candidates, key=_target_sort_key))
    return selected


def target_payload(target: FileCoverage) -> dict[str, object]:
    return {
        **asdict(target),
        "percent": round(target.percent, 2),
        "uncovered": target.uncovered,
        "uncovered_ranges": compact_ranges(target.uncovered_lines),
    }


def issue_body(
    *,
    global_percent: float,
    total_hit: int,
    total_found: int,
    global_target: float,
    target: FileCoverage,
) -> str:
    return f"""## Mission de couverture automatique

### Mesure réelle
- Couverture globale LCOV : **{global_percent:.2f} %** ({total_hit}/{total_found})
- Objectif global : **{global_target:.2f} %**
- Domaine prioritaire : **{target.category}**
- Fichier sélectionné : `{target.path}`
- Couverture du fichier : **{target.percent:.2f} %** ({target.hit}/{target.found})
- Lignes non couvertes : `{compact_ranges(target.uncovered_lines)}`

### Travail demandé
1. Lire le fichier et ses tests existants.
2. Ajouter des tests comportementaux déterministes pour augmenter sa couverture.
3. Extraire uniquement les dépendances strictement nécessaires à la testabilité.
4. Exécuter `dart format`, `flutter analyze`, `flutter test` et `flutter test --coverage`.
5. Fournir dans la PR la couverture avant/après, globale et pour ce fichier.

### Garde-fous obligatoires
- Ne pas abaisser de seuil de couverture.
- Ne pas exclure de fichier ou de ligne du LCOV.
- Ne pas ajouter `skip`, faux succès, attente arbitraire ou test vide.
- Ne pas modifier le comportement produit sauf correction justifiée et testée.
- Une seule cible principale par PR.
- Ne pas fusionner si les tests échouent ou si la couverture globale régresse.

### Critère de fin
La PR doit augmenter la couverture LCOV réelle et conserver tous les contrôles au vert.
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lcov", type=Path, required=True)
    parser.add_argument("--json-output", type=Path, required=True)
    parser.add_argument("--markdown-output", type=Path, required=True)
    parser.add_argument("--global-target", type=float, default=80.0)
    args = parser.parse_args()

    records = parse_lcov(args.lcov)
    if not records:
        raise SystemExit("LCOV contains no eligible lib/ records.")

    total_found = sum(item.found for item in records)
    total_hit = sum(item.hit for item in records)
    global_percent = 100.0 if total_found == 0 else total_hit * 100.0 / total_found
    primary_target = choose_target(records)
    lane_targets = choose_targets_by_category(records)

    payload = {
        "global": {
            "found": total_found,
            "hit": total_hit,
            "percent": round(global_percent, 2),
            "target": args.global_target,
            "target_reached": global_percent >= args.global_target,
        },
        "target": target_payload(primary_target),
        "targets": [target_payload(target) for target in lane_targets],
        "priorities": [name for name, _ in PRIORITY_RULES],
    }

    args.json_output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
    args.json_output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    args.markdown_output.write_text(
        issue_body(
            global_percent=global_percent,
            total_hit=total_hit,
            total_found=total_found,
            global_target=args.global_target,
            target=primary_target,
        ),
        encoding="utf-8",
    )
    print(json.dumps(payload))


if __name__ == "__main__":
    main()
