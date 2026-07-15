#!/usr/bin/env python3
"""Select the next high-value Flutter coverage target from an LCOV report.

The script is deterministic and intentionally never edits coverage thresholds,
excludes files, or generates fake tests. It emits JSON and Markdown consumed by
GitHub Actions to create one focused coding-agent task at a time.
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
    ("authentication", ("auth", "login", "register", "password", "credential")),
    ("publication", ("publish", "listing", "offer", "annonce")),
    ("messaging", ("message", "messaging", "chat", "conversation", "thread")),
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
            records.append(FileCoverage(normalised, found, hit, uncovered, category, rank))
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
    values = sorted(set(lines))[:limit]
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
    suffix = "…" if len(set(lines)) > limit else ""
    return ", ".join(ranges) + suffix


def choose_target(records: list[FileCoverage]) -> FileCoverage:
    candidates = [record for record in records if record.uncovered > 0]
    if not candidates:
        raise SystemExit("No uncovered production file found in LCOV report.")
    return min(
        candidates,
        key=lambda item: (
            item.category_rank,
            item.percent,
            -item.uncovered,
            item.path,
        ),
    )


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
    target = choose_target(records)

    payload = {
        "global": {
            "found": total_found,
            "hit": total_hit,
            "percent": round(global_percent, 2),
            "target": args.global_target,
            "target_reached": global_percent >= args.global_target,
        },
        "target": {
            **asdict(target),
            "percent": round(target.percent, 2),
            "uncovered": target.uncovered,
            "uncovered_ranges": compact_ranges(target.uncovered_lines),
        },
        "priorities": [name for name, _ in PRIORITY_RULES],
    }

    args.json_output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
    args.json_output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    body = f"""## Mission de couverture automatique

### Mesure réelle
- Couverture globale LCOV : **{global_percent:.2f} %** ({total_hit}/{total_found})
- Objectif global : **{args.global_target:.2f} %**
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
    args.markdown_output.write_text(body, encoding="utf-8")
    print(json.dumps(payload))


if __name__ == "__main__":
    main()
