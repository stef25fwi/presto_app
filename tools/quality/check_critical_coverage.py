#!/usr/bin/env python3
"""Measure LCOV coverage and instrumentation ratio for critical modules."""

from __future__ import annotations

import argparse
import fnmatch
import json
from datetime import datetime, timezone
from pathlib import Path

EXCLUDED_PARTS = {
    '.dart_tool', '.git', '.backups', 'backups', 'build', 'coverage',
    'docs', 'node_modules', 'test',
}


def parse_lcov(path: Path) -> dict[str, dict[str, int]]:
    records: dict[str, dict[str, int]] = {}
    current_path: str | None = None
    found = hit = 0
    for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
        if line.startswith('SF:'):
            current_path = line[3:].replace('\\', '/').lstrip('./')
            found = hit = 0
        elif line.startswith('LF:') and current_path is not None:
            found = int(line[3:] or 0)
        elif line.startswith('LH:') and current_path is not None:
            hit = int(line[3:] or 0)
        elif line == 'end_of_record' and current_path is not None:
            records[current_path] = {'lines_found': found, 'lines_hit': hit}
            current_path = None
    return records


def authored_dart_files(root: Path) -> list[str]:
    files = []
    for path in (root / 'lib').rglob('*.dart'):
        relative = path.relative_to(root)
        if set(relative.parts) & EXCLUDED_PARTS:
            continue
        files.append(relative.as_posix())
    return sorted(files)


def matches(path: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)


def percent(numerator: int, denominator: int) -> float:
    return round(numerator * 100 / denominator, 2) if denominator else 0.0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', default='.')
    parser.add_argument('--lcov', default='coverage/lcov.info')
    parser.add_argument('--config', default='quality/critical-coverage.json')
    parser.add_argument('--output-dir', default='quality_reports/critical-coverage')
    parser.add_argument('--enforce', action='store_true')
    args = parser.parse_args()

    root = Path(args.root).resolve()
    lcov_path = (root / args.lcov).resolve()
    config_path = (root / args.config).resolve()
    output = (root / args.output_dir).resolve()
    output.mkdir(parents=True, exist_ok=True)

    if not lcov_path.exists():
        raise SystemExit(f'LCOV file not found: {lcov_path}')
    if not config_path.exists():
        raise SystemExit(f'Config file not found: {config_path}')

    config = json.loads(config_path.read_text(encoding='utf-8'))
    coverage = parse_lcov(lcov_path)
    all_files = authored_dart_files(root)
    results = []
    failures = []

    for module in config.get('modules', []):
        module_id = module['id']
        patterns = list(module.get('patterns', []))
        files = [path for path in all_files if matches(path, patterns)]
        tracked = [path for path in files if path in coverage]
        untracked = [path for path in files if path not in coverage]
        lines_found = sum(coverage[path]['lines_found'] for path in tracked)
        lines_hit = sum(coverage[path]['lines_hit'] for path in tracked)
        coverage_percent = percent(lines_hit, lines_found)
        tracked_percent = percent(len(tracked), len(files))
        minimum = float(module.get('minimum_percent', 0) or 0)
        minimum_tracked = float(
            module.get('minimum_tracked_files_percent', 0) or 0
        )
        target = float(module.get('target_percent', 0) or 0)

        result = {
            'id': module_id,
            'label': module.get('label', module_id),
            'patterns': patterns,
            'total_files': len(files),
            'tracked_files': len(tracked),
            'untracked_files': untracked,
            'tracked_files_percent': tracked_percent,
            'lines_found': lines_found,
            'lines_hit': lines_hit,
            'coverage_percent_on_tracked_files': coverage_percent,
            'minimum_percent': minimum,
            'minimum_tracked_files_percent': minimum_tracked,
            'target_percent': target,
        }
        results.append(result)

        if coverage_percent < minimum:
            failures.append(
                f'{module_id}: coverage {coverage_percent}% < {minimum}%'
            )
        if tracked_percent < minimum_tracked:
            failures.append(
                f'{module_id}: tracked files {tracked_percent}% '
                f'< {minimum_tracked}%'
            )

    report = {
        'schema_version': 1,
        'generated_at_utc': datetime.now(timezone.utc).isoformat(),
        'lcov_file_count': len(coverage),
        'authored_dart_file_count': len(all_files),
        'modules': results,
        'failures': failures,
    }
    (output / 'critical-coverage.json').write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + '\n',
        encoding='utf-8',
    )

    lines = [
        '# Couverture des modules critiques',
        '',
        f"Générée le `{report['generated_at_utc']}`.",
        '',
        'La couverture est calculée sur les fichiers présents dans LCOV. Le taux de fichiers suivis empêche de masquer des fichiers jamais chargés par les tests.',
        '',
        '| Module | Fichiers suivis | Couverture suivie | Minimum | Cible |',
        '|---|---:|---:|---:|---:|',
    ]
    for result in results:
        lines.append(
            f"| {result['label']} | {result['tracked_files']}/"
            f"{result['total_files']} ({result['tracked_files_percent']} %) | "
            f"{result['coverage_percent_on_tracked_files']} % | "
            f"{result['minimum_percent']} % | {result['target_percent']} % |"
        )

    lines += ['', '## Fichiers non suivis par LCOV', '']
    for result in results:
        lines.append(f"### {result['label']}")
        lines.append('')
        if result['untracked_files']:
            lines.extend(f"- `{path}`" for path in result['untracked_files'])
        else:
            lines.append('- Aucun.')
        lines.append('')

    if failures:
        lines += ['## Échecs', '']
        lines.extend(f'- {failure}' for failure in failures)
        lines.append('')

    (output / 'critical-coverage.md').write_text(
        '\n'.join(lines),
        encoding='utf-8',
    )

    print(json.dumps({
        'lcov_file_count': len(coverage),
        'authored_dart_file_count': len(all_files),
        'module_count': len(results),
        'failure_count': len(failures),
    }))

    if args.enforce and failures:
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
