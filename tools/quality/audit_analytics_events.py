#!/usr/bin/env python3
"""Catalog product analytics events and flag likely PII parameter keys."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

EXCLUDED_PARTS = {
    '.dart_tool', '.git', '.backups', 'backups', 'build', 'coverage',
    'docs', 'node_modules', 'test',
}
EVENT_RE = re.compile(r"\.logEvent\(\s*['\"]([a-zA-Z0-9_]+)['\"]")
TYPED_EVENT_RE = re.compile(r'ProductAnalyticsEvent\.([a-zA-Z0-9_]+)\s*\(')
PARAMETER_KEY_RE = re.compile(r"['\"]([a-zA-Z0-9_]+)['\"]\s*:")
FORBIDDEN_KEYS = {
    'email', 'email_address', 'phone', 'phone_number', 'first_name',
    'last_name', 'full_name', 'address', 'postal_address', 'message',
    'description', 'free_text', 'auth_token', 'access_token', 'id_token',
    'user_id', 'uid',
}


def authored_dart_files(root: Path):
    for path in (root / 'lib').rglob('*.dart'):
        relative = path.relative_to(root)
        if set(relative.parts) & EXCLUDED_PARTS:
            continue
        yield path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', default='.')
    parser.add_argument('--output-dir', default='quality_reports/analytics')
    parser.add_argument('--enforce', action='store_true')
    args = parser.parse_args()

    root = Path(args.root).resolve()
    output = (root / args.output_dir).resolve()
    output.mkdir(parents=True, exist_ok=True)

    raw_events = Counter()
    typed_factories = Counter()
    files = []
    violations = []

    for path in authored_dart_files(root):
        text = path.read_text(encoding='utf-8', errors='replace')
        relative = path.relative_to(root).as_posix()
        events = EVENT_RE.findall(text)
        typed = TYPED_EVENT_RE.findall(text)
        if not events and not typed and 'parameters:' not in text:
            continue

        raw_events.update(events)
        typed_factories.update(typed)
        file_violations = []
        for number, line in enumerate(text.splitlines(), start=1):
            keys = PARAMETER_KEY_RE.findall(line)
            for key in keys:
                normalized = key.lower()
                if normalized in FORBIDDEN_KEYS and (
                    'parameters' in text or '.logEvent' in text
                ):
                    item = {
                        'path': relative,
                        'line': number,
                        'key': normalized,
                        'code': line.strip()[:240],
                    }
                    violations.append(item)
                    file_violations.append(item)
        files.append({
            'path': relative,
            'raw_events': events,
            'typed_factories': typed,
            'violations': file_violations,
        })

    report = {
        'schema_version': 1,
        'generated_at_utc': datetime.now(timezone.utc).isoformat(),
        'raw_events': raw_events.most_common(),
        'typed_factories': typed_factories.most_common(),
        'violations': violations,
        'files': files,
    }

    (output / 'analytics-event-catalog.json').write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + '\n',
        encoding='utf-8',
    )

    lines = [
        '# Catalogue Analytics produit',
        '',
        f"Généré le `{report['generated_at_utc']}`.",
        '',
        '## Événements bruts existants',
        '',
        '| Événement | Occurrences |',
        '|---|---:|',
    ]
    for name, count in report['raw_events']:
        lines.append(f'| `{name}` | {count} |')
    if not report['raw_events']:
        lines.append('| — | 0 |')

    lines += [
        '',
        '## Factories typées utilisées',
        '',
        '| Factory | Occurrences |',
        '|---|---:|',
    ]
    for name, count in report['typed_factories']:
        lines.append(f'| `{name}` | {count} |')
    if not report['typed_factories']:
        lines.append('| — | 0 |')

    lines += [
        '',
        '## Violations potentielles',
        '',
        '| Fichier | Ligne | Clé |',
        '|---|---:|---|',
    ]
    for violation in violations:
        lines.append(
            f"| `{violation['path']}` | {violation['line']} | "
            f"`{violation['key']}` |"
        )
    if not violations:
        lines.append('| — | 0 | Aucune |')

    lines += [
        '',
        'Les résultats sont des garde-fous statiques. Une revue humaine reste nécessaire pour vérifier les valeurs dynamiques et le consentement.',
        '',
    ]
    (output / 'analytics-event-catalog.md').write_text(
        '\n'.join(lines),
        encoding='utf-8',
    )

    print(json.dumps({
        'raw_event_count': sum(raw_events.values()),
        'typed_factory_count': sum(typed_factories.values()),
        'potential_pii_violations': len(violations),
    }))

    if args.enforce and violations:
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
