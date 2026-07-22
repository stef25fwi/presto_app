#!/usr/bin/env python3
"""Select profitable Flutter coverage targets from an LCOV report.

The selector never changes thresholds or excludes ordinary production files. It
ranks targets using expected LCOV gain, domain priority and a small complexity
proxy so the autopilot prefers files that can move the global percentage fast.

Critical-path rules are loaded from ``quality/critical-coverage.json``. The
autopilot keeps one profitable file queued for each requested domain until the
configured per-domain target is reached.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import math
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

PRIORITY_RULES: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("payments", ("payment", "stripe", "subscription", "billing", "checkout")),
    ("authentication", ("auth", "login", "register", "password", "credential")),
    ("publication", ("publish", "listing", "offer", "annonce")),
    ("messaging", ("message", "messaging", "chat", "conversation", "thread")),
    ("administration", ("admin", "moderation", "dashboard")),
)

CRITICAL_MODULE_CATEGORY = {
    "subscriptions_payment": "payments",
    "authentication": "authentication",
    "offer_publication": "publication",
    "messaging": "messaging",
    "administration": "administration",
}

EXCLUDED_PATH_PARTS = (
    "/generated/",
    ".g.dart",
    ".freezed.dart",
    "firebase_options.dart",
)


@dataclass(frozen=True)
class CriticalRule:
    module_id: str
    label: str
    category: str
    category_rank: int
    patterns: tuple[str, ...]
    target_percent: float


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

    @property
    def profitability(self) -> float:
        """Expected gain divided by a conservative file-complexity proxy."""
        return self.uncovered / max(1.0, math.sqrt(self.found))


def normalise_path(raw: str) -> str:
    value = raw.replace("\\", "/")
    marker = "/lib/"
    if marker in value:
        return "lib/" + value.split(marker, 1)[1]
    return value.lstrip("./")


def priority_rank(category: str) -> int:
    for rank, (name, _) in enumerate(PRIORITY_RULES):
        if name == category:
            return rank
    return len(PRIORITY_RULES)


def load_critical_rules(path: Path | None) -> tuple[CriticalRule, ...]:
    if path is None or not path.exists():
        return ()

    payload = json.loads(path.read_text(encoding="utf-8"))
    rules: list[CriticalRule] = []
    for module in payload.get("modules", []):
        module_id = str(module.get("id", ""))
        category = CRITICAL_MODULE_CATEGORY.get(module_id)
        if category is None:
            continue
        patterns = tuple(str(item) for item in module.get("patterns", []))
        if not patterns:
            continue
        rules.append(
            CriticalRule(
                module_id=module_id,
                label=str(module.get("label", module_id)),
                category=category,
                category_rank=priority_rank(category),
                patterns=patterns,
                target_percent=float(module.get("target_percent", 100) or 100),
            )
        )
    return tuple(sorted(rules, key=lambda item: item.category_rank))


def classify(
    path: str,
    critical_rules: tuple[CriticalRule, ...] = (),
) -> tuple[str, int]:
    for rule in critical_rules:
        if any(fnmatch.fnmatchcase(path, pattern) for pattern in rule.patterns):
            return rule.category, rule.category_rank

    if critical_rules:
        return "other", len(PRIORITY_RULES)

    lowered = path.lower()
    for rank, (category, needles) in enumerate(PRIORITY_RULES):
        if any(needle in lowered for needle in needles):
            return category, rank
    return "other", len(PRIORITY_RULES)


def parse_lcov(
    path: Path,
    critical_rules: tuple[CriticalRule, ...] = (),
) -> list[FileCoverage]:
    records: list[FileCoverage] = []
    current: str | None = None
    line_hits: dict[int, int] = {}

    def flush() -> None:
        nonlocal current, line_hits
        if not current:
            return
        normalised = normalise_path(current)
        if not normalised.startswith("lib/") or any(
            part in normalised for part in EXCLUDED_PATH_PARTS
        ):
            current, line_hits = None, {}
            return
        found = len(line_hits)
        if found:
            hit = sum(1 for count in line_hits.values() if count > 0)
            uncovered = sorted(
                line for line, count in line_hits.items() if count == 0
            )
            category, rank = classify(normalised, critical_rules)
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
    return ", ".join(ranges) + ("…" if len(unique_values) > limit else "")


def target_sort_key(item: FileCoverage) -> tuple[int, float, int, float, str]:
    return (
        item.category_rank,
        -item.profitability,
        -item.uncovered,
        item.percent,
        item.path,
    )


def choose_target(records: list[FileCoverage]) -> FileCoverage:
    candidates = [record for record in records if record.uncovered > 0]
    if not candidates:
        raise SystemExit("No uncovered production file found in LCOV report.")
    return min(candidates, key=target_sort_key)


def category_target_map(
    critical_rules: tuple[CriticalRule, ...],
) -> dict[str, float]:
    return {rule.category: rule.target_percent for rule in critical_rules}


def choose_targets_by_category(
    records: list[FileCoverage],
    targets: dict[str, float] | None = None,
) -> list[FileCoverage]:
    selected: list[FileCoverage] = []
    category_targets = targets or {}
    for category, _ in PRIORITY_RULES:
        target_percent = category_targets.get(category, 100.0)
        candidates = [
            record
            for record in records
            if record.category == category
            and record.uncovered > 0
            and record.percent < target_percent
        ]
        if candidates:
            selected.append(min(candidates, key=target_sort_key))
    return selected


def build_critical_status(
    records: list[FileCoverage],
    critical_rules: tuple[CriticalRule, ...],
) -> list[dict[str, object]]:
    statuses: list[dict[str, object]] = []
    for rule in critical_rules:
        scoped = [record for record in records if record.category == rule.category]
        found = sum(record.found for record in scoped)
        hit = sum(record.hit for record in scoped)
        percent = 0.0 if found == 0 else hit * 100.0 / found
        statuses.append(
            {
                "module_id": rule.module_id,
                "label": rule.label,
                "category": rule.category,
                "target_percent": rule.target_percent,
                "found": found,
                "hit": hit,
                "percent": round(percent, 2),
                "tracked_files": len(scoped),
                "target_reached": bool(scoped)
                and percent + 1e-9 >= rule.target_percent,
            }
        )
    return statuses


def rule_for_category(
    category: str,
    critical_rules: tuple[CriticalRule, ...],
) -> CriticalRule | None:
    return next(
        (rule for rule in critical_rules if rule.category == category),
        None,
    )


def target_payload(
    target: FileCoverage,
    critical_rules: tuple[CriticalRule, ...] = (),
) -> dict[str, object]:
    rule = rule_for_category(target.category, critical_rules)
    return {
        **asdict(target),
        "percent": round(target.percent, 2),
        "uncovered": target.uncovered,
        "profitability": round(target.profitability, 2),
        "uncovered_ranges": compact_ranges(target.uncovered_lines),
        "module_id": rule.module_id if rule else target.category,
        "module_label": rule.label if rule else target.category,
        "target_percent": rule.target_percent if rule else 100.0,
    }


def issue_body(
    *,
    global_percent: float,
    total_hit: int,
    total_found: int,
    global_target: float,
    targets: list[dict[str, object]],
    critical_status: list[dict[str, object]],
) -> str:
    lines = [
        "## Mission de couverture automatique — parcours critiques",
        "",
        "### Mesure réelle",
        f"- Couverture globale LCOV : **{global_percent:.2f} %** "
        f"({total_hit}/{total_found})",
        f"- Objectif global : **{global_target:.2f} %**",
        "- Objectif des cinq parcours critiques : **100 %**",
        "",
        "### État des parcours critiques",
        "",
        "| Parcours | Couverture LCOV | Cible | Fichiers suivis |",
        "|---|---:|---:|---:|",
    ]
    for status in critical_status:
        lines.append(
            f"| {status['label']} | {status['percent']} % | "
            f"{status['target_percent']} % | {status['tracked_files']} |"
        )

    lines += ["", "### Fichiers précis à traiter dans cette phase", ""]
    if not targets:
        lines.append(
            "- Aucun fichier découvert sous les motifs critiques alors qu'une cible "
            "reste incomplète : corriger d'abord l'instrumentation LCOV."
        )
    else:
        for index, target in enumerate(targets, start=1):
            lines += [
                f"{index}. **{target['module_label']}**",
                f"   - fichier : `{target['path']}`",
                f"   - couverture actuelle : **{target['percent']} %** "
                f"({target['hit']}/{target['found']})",
                f"   - objectif du fichier : **{target['target_percent']} %**",
                f"   - lignes non couvertes : **{target['uncovered']}**",
                f"   - plages : `{target['uncovered_ranges']}`",
            ]

    lines += [
        "",
        "### Boucle d'exécution obligatoire",
        "1. Traiter les fichiers ci-dessus dans l'ordre Paiement, "
        "Authentification, Publication, Messagerie, Administration.",
        "2. Ajouter uniquement des tests comportementaux déterministes.",
        "3. Pendant le développement, exécuter les tests ciblés et "
        "`flutter analyze lib test`.",
        "4. Continuer sur le même fichier jusqu'à **100 % LCOV réel**, puis passer "
        "au fichier suivant.",
        "5. Avant la PR, exécuter `dart format`, "
        "`flutter analyze --fatal-infos` et `flutter test --coverage`.",
        "6. Fournir dans la PR la couverture avant/après, globale, par parcours "
        "et par fichier.",
        "",
        "### Garde-fous",
        "- Aucun abaissement de seuil ou exclusion LCOV.",
        "- Aucun `skip`, test vide, faux succès ou attente arbitraire.",
        "- Une seule branche et une seule PR `coverage/*` active.",
        "- La couverture globale et celle de chaque parcours ne doivent pas régresser.",
        "- La mission n'est terminée que lorsque chaque fichier listé atteint 100 % "
        "ou qu'une ligne techniquement non instrumentable est démontrée dans la PR.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lcov", type=Path, required=True)
    parser.add_argument("--json-output", type=Path, required=True)
    parser.add_argument("--markdown-output", type=Path, required=True)
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("quality/critical-coverage.json"),
    )
    parser.add_argument("--global-target", type=float, default=80.0)
    args = parser.parse_args()

    critical_rules = load_critical_rules(args.config)
    records = parse_lcov(args.lcov, critical_rules)
    if not records:
        raise SystemExit("LCOV contains no eligible lib/ records.")

    total_found = sum(item.found for item in records)
    total_hit = sum(item.hit for item in records)
    global_percent = 100.0 if total_found == 0 else total_hit * 100.0 / total_found
    primary_target = choose_target(records)
    lane_targets = choose_targets_by_category(
        records,
        category_target_map(critical_rules),
    )
    critical_status = build_critical_status(records, critical_rules)
    critical_target_reached = bool(critical_status) and all(
        bool(status["target_reached"]) for status in critical_status
    )
    target_payloads = [
        target_payload(target, critical_rules) for target in lane_targets
    ]

    payload = {
        "global": {
            "found": total_found,
            "hit": total_hit,
            "percent": round(global_percent, 2),
            "target": args.global_target,
            "target_reached": global_percent >= args.global_target,
        },
        "critical_target_reached": critical_target_reached,
        "critical_modules": critical_status,
        "target": target_payload(primary_target, critical_rules),
        "targets": target_payloads,
        "priorities": [name for name, _ in PRIORITY_RULES],
    }

    args.json_output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
    args.json_output.write_text(
        json.dumps(payload, indent=2) + "\n",
        encoding="utf-8",
    )
    args.markdown_output.write_text(
        issue_body(
            global_percent=global_percent,
            total_hit=total_hit,
            total_found=total_found,
            global_target=args.global_target,
            targets=target_payloads,
            critical_status=critical_status,
        ),
        encoding="utf-8",
    )
    print(json.dumps(payload))


if __name__ == "__main__":
    main()
