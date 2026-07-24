#!/usr/bin/env python3
"""Supervise LCOV workers and keep useful parallel capacity available.

The supervisor is deliberately deterministic: GitHub Actions gathers issue/PR
metadata, this module classifies worker health and returns a capacity plan. It
never lowers thresholds or treats an issue without recent activity as proof
that code is being produced.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import json
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class Worker:
    key: str
    issue_number: int | None
    pr_number: int | None
    path: str
    updated_at: datetime
    has_pr: bool


def parse_time(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return parsed.astimezone(timezone.utc)


def worker_key(item: dict[str, Any]) -> str:
    body = str(item.get("body") or "")
    title = str(item.get("title") or "")
    branch = str(item.get("headRefName") or "")
    for source in (body, title, branch):
        marker = "coverage-worker:"
        if marker in source:
            suffix = source.split(marker, 1)[1]
            token = "".join(ch for ch in suffix if ch.isalnum() or ch in "-_/." )
            if token:
                return token[:120]
    return branch or title or str(item.get("number", "unknown"))


def production_path(item: dict[str, Any]) -> str:
    body = str(item.get("body") or "")
    marker = "Fichier de production : `"
    if marker in body:
        return body.split(marker, 1)[1].split("`", 1)[0]
    return ""


def build_workers(issues: list[dict[str, Any]], prs: list[dict[str, Any]]) -> list[Worker]:
    pr_by_key = {worker_key(pr): pr for pr in prs}
    workers: list[Worker] = []
    seen: set[str] = set()

    for issue in issues:
        key = worker_key(issue)
        pr = pr_by_key.get(key)
        timestamps = [parse_time(str(issue["updatedAt"]))]
        if pr and pr.get("updatedAt"):
            timestamps.append(parse_time(str(pr["updatedAt"])))
        workers.append(
            Worker(
                key=key,
                issue_number=int(issue["number"]),
                pr_number=int(pr["number"]) if pr else None,
                path=production_path(issue),
                updated_at=max(timestamps),
                has_pr=pr is not None,
            )
        )
        seen.add(key)

    for key, pr in pr_by_key.items():
        if key in seen:
            continue
        workers.append(
            Worker(
                key=key,
                issue_number=None,
                pr_number=int(pr["number"]),
                path="",
                updated_at=parse_time(str(pr["updatedAt"])),
                has_pr=True,
            )
        )
    return workers


def supervise(
    issues: list[dict[str, Any]],
    prs: list[dict[str, Any]],
    *,
    now: datetime,
    stale_hours: float,
    max_workers: int,
    global_percent: float,
    target_percent: float,
) -> dict[str, Any]:
    workers = build_workers(issues, prs)
    healthy: list[Worker] = []
    stale: list[Worker] = []
    orphaned: list[Worker] = []

    for worker in workers:
        age_hours = (now - worker.updated_at).total_seconds() / 3600
        if not worker.has_pr and age_hours >= stale_hours:
            orphaned.append(worker)
        elif age_hours >= stale_hours:
            stale.append(worker)
        else:
            healthy.append(worker)

    reached = global_percent >= target_percent
    occupied = 0 if reached else min(max_workers, len(healthy))
    available = 0 if reached else max(0, max_workers - occupied)
    return {
        "schema_version": 1,
        "target_percent": target_percent,
        "global_percent": global_percent,
        "target_reached": reached,
        "max_workers": max_workers,
        "healthy_workers": [worker.__dict__ | {"updated_at": worker.updated_at.isoformat()} for worker in healthy],
        "stale_workers": [worker.__dict__ | {"updated_at": worker.updated_at.isoformat()} for worker in stale],
        "orphaned_workers": [worker.__dict__ | {"updated_at": worker.updated_at.isoformat()} for worker in orphaned],
        "occupied_slots": occupied,
        "available_slots": available,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--issues", type=Path, required=True)
    parser.add_argument("--prs", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--global-percent", type=float, required=True)
    parser.add_argument("--target-percent", type=float, default=80)
    parser.add_argument("--max-workers", type=int, default=4)
    parser.add_argument("--stale-hours", type=float, default=8)
    parser.add_argument("--now")
    args = parser.parse_args()

    now = parse_time(args.now) if args.now else datetime.now(timezone.utc)
    payload = supervise(
        json.loads(args.issues.read_text(encoding="utf-8")),
        json.loads(args.prs.read_text(encoding="utf-8")),
        now=now,
        stale_hours=max(1, args.stale_hours),
        max_workers=max(1, args.max_workers),
        global_percent=args.global_percent,
        target_percent=args.target_percent,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
