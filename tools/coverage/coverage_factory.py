#!/usr/bin/env python3
"""Build two independent coverage worker missions from coverage-agent output."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

LANE_ORDER = (
    "payments",
    "authentication",
    "publication",
    "messaging",
    "administration",
)


def pick_workers(targets: list[dict[str, object]], limit: int = 2) -> list[dict[str, object]]:
    ordered = sorted(
        targets,
        key=lambda item: (
            LANE_ORDER.index(str(item["category"]))
            if str(item["category"]) in LANE_ORDER
            else len(LANE_ORDER),
            -float(item.get("profitability", 0)),
            -int(item.get("uncovered", 0)),
            str(item.get("path", "")),
        ),
    )
    selected: list[dict[str, object]] = []
    categories: set[str] = set()
    for target in ordered:
        category = str(target.get("category", ""))
        if category in categories:
            continue
        selected.append(target)
        categories.add(category)
        if len(selected) >= limit:
            break
    return selected


def worker_payload(index: int, target: dict[str, object]) -> dict[str, object]:
    category = str(target["category"])
    path = str(target["path"])
    slug = category.replace("_", "-")
    return {
        "worker": index,
        "category": category,
        "module_label": target.get("module_label", category),
        "path": path,
        "current_percent": target.get("percent", 0),
        "target_percent": 100,
        "uncovered": target.get("uncovered", 0),
        "uncovered_ranges": target.get("uncovered_ranges", "aucune"),
        "profitability": target.get("profitability", 0),
        "branch_prefix": f"coverage/w{index}-{slug}",
        "fast_commands": [
            "dart format <test-file>",
            "flutter test <test-file>",
            f"flutter analyze {path} <test-file>",
        ],
        "final_commands": [
            "dart format --set-exit-if-changed lib test",
            "flutter analyze --fatal-infos",
            "flutter test --coverage",
            "python3 tools/quality/check_critical_coverage.py --enforce",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--markdown", type=Path, required=True)
    parser.add_argument("--limit", type=int, default=2)
    args = parser.parse_args()

    data = json.loads(args.input.read_text(encoding="utf-8"))
    selected = pick_workers(list(data.get("targets", [])), max(1, args.limit))
    workers = [worker_payload(index, target) for index, target in enumerate(selected, 1)]
    payload = {
        "schema_version": 1,
        "strategy": "coverage-factory-5x2",
        "worker_limit": args.limit,
        "workers": workers,
        "remaining_target_count": max(0, len(data.get("targets", [])) - len(workers)),
        "global": data.get("global", {}),
        "critical_status": data.get("critical_status", []),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    lines = [
        "## Coverage Factory 5×2",
        "",
        "Deux workers maximum, sur deux parcours distincts, avec validation ciblée pendant l’écriture et validation complète avant fusion.",
        "",
    ]
    if not workers:
        lines.append("Aucune cible incomplète disponible.")
    for worker in workers:
        lines += [
            f"### Worker {worker['worker']} — {worker['module_label']}",
            f"- Fichier : `{worker['path']}`",
            f"- Couverture actuelle : **{worker['current_percent']} %**",
            f"- Objectif : **100 %**",
            f"- Lignes non couvertes : **{worker['uncovered']}**",
            f"- Plages : `{worker['uncovered_ranges']}`",
            f"- Préfixe de branche : `{worker['branch_prefix']}`",
            "- Boucle rapide : format du test, test ciblé, analyse du fichier et du test.",
            "- Validation finale : analyse complète, LCOV complet et contrôle des modules critiques.",
            "",
        ]
    lines += [
        "### Garde-fous",
        "- Deux branches `coverage/w*` maximum en parallèle.",
        "- Parcours différents pour éviter les conflits.",
        "- Aucun `skip`, aucune exclusion LCOV, aucun seuil abaissé.",
        "- Fusion séquentielle ; nouvelle mesure LCOV après chaque fusion.",
    ]
    args.markdown.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
