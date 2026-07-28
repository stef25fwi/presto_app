#!/usr/bin/env python3
"""Rank real LCOV gaps and build two high-yield coverage packs.

The planner never alters LCOV input and never excludes lines from the global
measurement. It only prioritises which already-uncovered production lines should
be attacked next.
"""

from __future__ import annotations

import argparse
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable, Sequence

CRITICAL_TOKENS: tuple[tuple[str, float], ...] = (
    ("payment", 1.55),
    ("paiement", 1.55),
    ("subscription", 1.50),
    ("stripe", 1.50),
    ("auth", 1.50),
    ("login", 1.45),
    ("publish", 1.45),
    ("publication", 1.45),
    ("offer", 1.35),
    ("messag", 1.40),
    ("conversation", 1.35),
    ("admin", 1.30),
)

HARD_DEPENDENCY_TOKENS = (
    "FirebaseFirestore.instance",
    "FirebaseAuth.instance",
    "FirebaseFunctions.instance",
    "FirebaseStorage.instance",
    "MethodChannel(",
    "MobileAds.instance",
    "ImagePicker(",
    "launchUrl(",
    "http.get(",
    "http.post(",
)

PURE_TOKENS = (
    "fromData(",
    "fromJson(",
    "copyWith(",
    "ChangeNotifier",
    "StatelessWidget",
    "ValueNotifier",
    "enum ",
    "typedef ",
)


@dataclass(frozen=True)
class FileCoverage:
    path: str
    lines_found: int
    lines_hit: int
    missing_lines: tuple[int, ...]

    @property
    def missing(self) -> int:
        return max(0, self.lines_found - self.lines_hit)

    @property
    def percent(self) -> float:
        if self.lines_found <= 0:
            return 100.0
        return self.lines_hit * 100.0 / self.lines_found


@dataclass(frozen=True)
class Candidate:
    path: str
    subsystem: str
    lines_found: int
    lines_hit: int
    missing: int
    percent: float
    source_lines: int
    testability: float
    criticality: float
    expected_gain: int
    score: float
    reasons: tuple[str, ...]
    missing_lines: tuple[int, ...]


@dataclass(frozen=True)
class Pack:
    lane: int
    subsystem: str
    expected_gain: int
    score: float
    files: tuple[Candidate, ...]


def _normalise_source_path(raw: str) -> str:
    value = raw.replace("\\", "/")
    marker = "/lib/"
    if marker in value:
        return "lib/" + value.split(marker, 1)[1]
    return value.lstrip("./")


def parse_lcov(path: Path) -> tuple[list[FileCoverage], int, int]:
    records: list[FileCoverage] = []
    current: str | None = None
    found = hit = 0
    missing: list[int] = []
    global_found = global_hit = 0

    def flush() -> None:
        nonlocal current, found, hit, missing
        if current is not None:
            records.append(
                FileCoverage(
                    path=_normalise_source_path(current),
                    lines_found=found,
                    lines_hit=hit,
                    missing_lines=tuple(sorted(set(missing))),
                )
            )
        current = None
        found = hit = 0
        missing = []

    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if raw_line.startswith("SF:"):
            flush()
            current = raw_line[3:]
        elif raw_line.startswith("LF:"):
            found = int(raw_line[3:])
            global_found += found
        elif raw_line.startswith("LH:"):
            hit = int(raw_line[3:])
            global_hit += hit
        elif raw_line.startswith("DA:") and current is not None:
            line_no, count, *_ = raw_line[3:].split(",")
            if int(count) == 0:
                missing.append(int(line_no))
        elif raw_line == "end_of_record":
            flush()
    flush()
    return records, global_hit, global_found


def subsystem_for(path: str) -> str:
    parts = Path(path).parts
    if len(parts) >= 3 and parts[1] in {
        "admin",
        "features",
        "pages",
        "services",
        "widgets",
        "models",
        "data",
    }:
        if parts[1] in {"admin", "features", "data"} and len(parts) >= 4:
            return "/".join(parts[1:3])
        return parts[1]
    return parts[1] if len(parts) > 1 else "core"


def criticality_for(path: str) -> float:
    lowered = path.lower()
    return max(
        (weight for token, weight in CRITICAL_TOKENS if token in lowered),
        default=1.0,
    )


def score_testability(path: str, source: str) -> tuple[float, tuple[str, ...]]:
    score = 0.80
    reasons: list[str] = []
    lowered_path = path.lower()
    source_lines = source.count("\n") + 1 if source else 0

    hard_count = sum(source.count(token) for token in HARD_DEPENDENCY_TOKENS)
    if hard_count == 0:
        score += 0.20
        reasons.append("sans dépendance dure détectée")
    else:
        score -= min(0.45, 0.08 * hard_count)
        reasons.append(f"{hard_count} dépendance(s) dure(s)")

    pure_count = sum(1 for token in PURE_TOKENS if token in source)
    if pure_count:
        score += min(0.25, 0.05 * pure_count)
        reasons.append("logique pure/modèle détectée")

    if any(segment in lowered_path for segment in ("/models/", "/utils/", "/config/")):
        score += 0.15
        reasons.append("fichier modèle/utilitaire")
    elif any(segment in lowered_path for segment in ("/widgets/", "/pages/")):
        score += 0.05
        reasons.append("widget testable")

    if "StreamBuilder<" in source or "FutureBuilder<" in source:
        score -= 0.05
        reasons.append("flux asynchrone")
    if source_lines > 1200:
        score -= 0.20
        reasons.append("fichier très volumineux")
    elif source_lines > 700:
        score -= 0.10
        reasons.append("fichier volumineux")

    return max(0.20, min(1.25, score)), tuple(reasons)


def build_candidates(
    records: Iterable[FileCoverage],
    source_root: Path,
    min_missing: int,
    reserved_targets: set[str] | None = None,
) -> list[Candidate]:
    reserved = reserved_targets or set()
    candidates: list[Candidate] = []
    for record in records:
        if not record.path.startswith("lib/") or record.missing < min_missing:
            continue
        if record.path in reserved:
            continue
        source_path = source_root / record.path
        source = (
            source_path.read_text(encoding="utf-8", errors="replace")
            if source_path.exists()
            else ""
        )
        source_lines = source.count("\n") + 1 if source else record.lines_found
        testability, reasons = score_testability(record.path, source)
        criticality = criticality_for(record.path)
        expected = max(
            1,
            min(
                record.missing,
                int(round(record.missing * min(1.0, testability))),
            ),
        )
        effort = 1.0 + source_lines / 650.0
        score = expected * criticality * testability / effort
        candidates.append(
            Candidate(
                path=record.path,
                subsystem=subsystem_for(record.path),
                lines_found=record.lines_found,
                lines_hit=record.lines_hit,
                missing=record.missing,
                percent=round(record.percent, 4),
                source_lines=source_lines,
                testability=round(testability, 4),
                criticality=round(criticality, 4),
                expected_gain=expected,
                score=round(score, 4),
                reasons=reasons,
                missing_lines=record.missing_lines,
            )
        )
    return sorted(
        candidates,
        key=lambda item: (item.score, item.expected_gain, item.missing),
        reverse=True,
    )


def minimum_pack_gain(global_percent: float) -> int:
    if global_percent < 80.0:
        return 25
    if global_percent < 87.5:
        return 10
    return 2


def build_packs(
    candidates: Sequence[Candidate],
    max_lanes: int,
    max_files_per_pack: int,
    min_pack_gain: int,
    max_pack_gain: int = 150,
) -> list[Pack]:
    remaining = list(candidates)
    packs: list[Pack] = []
    used_subsystems: set[str] = set()

    for lane in range(1, max_lanes + 1):
        if not remaining:
            break
        seed_index = next(
            (
                index
                for index, candidate in enumerate(remaining)
                if candidate.subsystem not in used_subsystems
            ),
            0,
        )
        seed = remaining.pop(seed_index)
        files = [seed]
        expected = seed.expected_gain
        score = seed.score

        same_subsystem = [
            item for item in remaining if item.subsystem == seed.subsystem
        ]
        same_subsystem.sort(
            key=lambda item: (item.score, item.expected_gain),
            reverse=True,
        )
        for item in same_subsystem:
            if len(files) >= max_files_per_pack or expected >= min_pack_gain:
                break
            if expected + item.expected_gain > max_pack_gain and expected > 0:
                continue
            files.append(item)
            expected += item.expected_gain
            score += item.score
            remaining.remove(item)

        if expected < min_pack_gain:
            cross_subsystem = sorted(
                remaining,
                key=lambda item: (item.score, item.expected_gain),
                reverse=True,
            )
            for item in cross_subsystem:
                if len(files) >= max_files_per_pack or expected >= min_pack_gain:
                    break
                if expected + item.expected_gain > max_pack_gain and expected > 0:
                    continue
                files.append(item)
                expected += item.expected_gain
                score += item.score
                remaining.remove(item)

        if expected < min_pack_gain and candidates and min_pack_gain > 2:
            continue
        used_subsystems.add(seed.subsystem)
        packs.append(
            Pack(
                lane=lane,
                subsystem=seed.subsystem,
                expected_gain=expected,
                score=round(score, 4),
                files=tuple(files),
            )
        )
    return packs


def plan_to_dict(
    global_hit: int,
    global_found: int,
    candidates: Sequence[Candidate],
    packs: Sequence[Pack],
) -> dict:
    percent = 100.0 if global_found == 0 else global_hit * 100.0 / global_found
    return {
        "global": {
            "hit": global_hit,
            "found": global_found,
            "percent": round(percent, 4),
            "target": 90.0,
            "missing_to_target": max(
                0,
                math.ceil(global_found * 0.90 - global_hit),
            ),
        },
        "policy": {
            "max_lanes": 2,
            "minimum_pack_gain": minimum_pack_gain(percent),
            "max_files_per_pack": 4,
            "merge_order": "highest_real_lcov_gain_first",
            "zero_gain_action": "close_without_merge_and_refill",
        },
        "packs": [
            {
                "lane": pack.lane,
                "subsystem": pack.subsystem,
                "expected_gain": pack.expected_gain,
                "score": pack.score,
                "files": [asdict(file) for file in pack.files],
            }
            for pack in packs
        ],
        "candidates": [asdict(candidate) for candidate in candidates],
    }


def render_markdown(plan: dict) -> str:
    global_data = plan["global"]
    lines = [
        "# Coverage FastLane plan",
        "",
        f"- Global réel: **{global_data['hit']} / {global_data['found']} = {global_data['percent']:.4f} %**",
        f"- Lignes supplémentaires requises pour 90 %: **{global_data['missing_to_target']}**",
        f"- Gain minimum par voie à ce niveau: **{plan['policy']['minimum_pack_gain']} lignes attendues**",
        "- Mesure obligatoire: `flutter test --coverage` complet, sans exclusion ni baisse de seuil.",
        "",
    ]
    for pack in plan["packs"]:
        lines.extend(
            [
                f"## Voie {pack['lane']} — {pack['subsystem']}",
                "",
                f"Gain attendu: **{pack['expected_gain']} lignes** — score {pack['score']}",
                "",
            ]
        )
        for file in pack["files"]:
            lines.append(
                f"- `{file['path']}` — {file['lines_hit']}/{file['lines_found']} "
                f"({file['percent']:.2f} %), {file['missing']} manquantes, "
                f"gain attendu {file['expected_gain']}"
            )
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lcov", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, default=Path("."))
    parser.add_argument("--output-json", type=Path, required=True)
    parser.add_argument("--output-md", type=Path, required=True)
    parser.add_argument("--max-lanes", type=int, default=2)
    parser.add_argument("--max-files-per-pack", type=int, default=4)
    parser.add_argument("--reserved-target", action="append", default=[])
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    records, global_hit, global_found = parse_lcov(args.lcov)
    percent = 100.0 if global_found == 0 else global_hit * 100.0 / global_found
    min_missing = 2 if percent >= 87.5 else 5
    candidates = build_candidates(
        records,
        args.source_root,
        min_missing=min_missing,
        reserved_targets=set(args.reserved_target),
    )
    packs = build_packs(
        candidates,
        max_lanes=max(1, args.max_lanes),
        max_files_per_pack=max(1, args.max_files_per_pack),
        min_pack_gain=minimum_pack_gain(percent),
    )
    plan = plan_to_dict(global_hit, global_found, candidates, packs)
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_md.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(
        json.dumps(plan, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    args.output_md.write_text(render_markdown(plan), encoding="utf-8")
    print(render_markdown(plan))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
