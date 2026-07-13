#!/usr/bin/env python3
"""Fail when globally ignored analyzer diagnostics exceed the versioned ceiling."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

IGNORE_RE = re.compile(r"^\s{4}([a-z0-9_]+):\s*ignore\s*$", re.MULTILINE)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--analysis-options", default="analysis_options.yaml")
    parser.add_argument("--config", default="quality/analyzer-ignore-gates.json")
    parser.add_argument("--output", default="quality_reports/analyzer-ignores.md")
    parser.add_argument("--enforce", action="store_true")
    args = parser.parse_args()

    options_path = Path(args.analysis_options)
    config_path = Path(args.config)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if not options_path.exists():
        raise SystemExit(f"analysis options not found: {options_path}")
    if not config_path.exists():
        raise SystemExit(f"config not found: {config_path}")

    ignored = sorted(set(IGNORE_RE.findall(options_path.read_text(encoding="utf-8"))))
    config = json.loads(config_path.read_text(encoding="utf-8"))
    maximum = int(config.get("maximum_ignored_rules", 0))
    target = int(config.get("target_ignored_rules", 0))
    failed = len(ignored) > maximum

    lines = [
        "# Diagnostics analyzer ignorés",
        "",
        f"- Actuels : **{len(ignored)}**",
        f"- Plafond bloquant : **{maximum}**",
        f"- Cible : **{target}**",
        "",
        "## Règles ignorées",
        "",
    ]
    lines.extend(f"- `{rule}`" for rule in ignored)
    if not ignored:
        lines.append("- Aucune.")
    if failed:
        lines += ["", f"Échec : {len(ignored)} règles ignorées dépassent le plafond de {maximum}."]

    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({"ignored_rules": len(ignored), "maximum": maximum, "target": target}))
    return 1 if args.enforce and failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
