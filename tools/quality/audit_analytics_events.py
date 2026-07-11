#!/usr/bin/env python3
"""Catalog product analytics events and flag PII keys in logEvent calls."""

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
LOG_EVENT_START_RE = re.compile(r'\.logEvent\s*\(')
LITERAL_EVENT_RE = re.compile(r"\.logEvent\s*\(\s*['\"]([a-zA-Z0-9_]+)['\"]")
TYPED_EVENT_RE = re.compile(r'ProductAnalyticsEvent\.([a-zA-Z0-9_]+)\s*\(')
FACTORY_DEFINITION_RE = re.compile(
    r'factory\s+ProductAnalyticsEvent\.([a-zA-Z0-9_]+)\s*\('
)
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


def extract_balanced_call(text: str, open_parenthesis: int) -> tuple[str, int]:
    depth = 0
    quote = None
    escaped = False
    for index in range(open_parenthesis, len(text)):
        char = text[index]
        if quote is not None:
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == quote:
                quote = None
            continue
        if char in {'\'', '"'}:
            quote = char
            continue
        if char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
            if depth == 0:
                return text[open_parenthesis:index + 1], index + 1
    return text[open_parenthesis:], len(text)


def log_event_calls(text: str):
    for match in LOG_EVENT_START_RE.finditer(text):
        open_parenthesis = text.find('(', match.start())
        call, end = extract_balanced_call(text, open_parenthesis)
        full_call = text[match.start():end]
        line = text.count('\n', 0, match.start()) + 1
        yield full_call, line


def typed_usages(text: str) -> list[str]:
    definitions = set(FACTORY_DEFINITION_RE.findall(text))
    usages = []
    for match in TYPED_EVENT_RE.finditer(text):
        prefix = text[max(0, match.start() - 16):match.start()]
        name = match.group(1)
        if 'factory' in prefix and name in definitions:
            continue
        usages.append(name)
    return usages


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
    typed_factory_definitions = Counter()
    typed_factory_usages = Counter()
    files = []
    violations = []

    for path in authored_dart_files(root):
        text = path.read_text(encoding='utf-8', errors='replace')
        relative = path.relative_to(root).as_posix()
        definitions = FACTORY_DEFINITION_RE.findall(text)
        typed = typed_usages(text)
        calls = list(log_event_calls(text))
        if not calls and not definitions and not typed:
            continue

        typed_factory_definitions.update(definitions)
        typed_factory_usages.update(typed)
        file_events = []
        file_violations = []

        for call, start_line in calls:
            literal_match = LITERAL_EVENT_RE.search(call)
            if literal_match:
                event_name = literal_match.group(1)
                raw_events[event_name] += 1
                file_events.append(event_name)

            parameters_index = call.find('parameters:')
            if parameters_index < 0:
                continue
            parameters_block = call[parameters_index:]
            for key_match in PARAMETER_KEY_RE.finditer(parameters_block):
                normalized = key_match.group(1).lower()
                if normalized not in FORBIDDEN_KEYS:
                    continue
                relative_line = parameters_block.count(
                    '\n', 0, key_match.start()
                )
                item = {
                    'path': relative,
                    'line': start_line + relative_line,
                    'key': normalized,
                }
                violations.append(item)
                file_violations.append(item)

        files.append({
            'path': relative,
            'raw_events': file_events,
            'typed_factory_definitions': definitions,
            'typed_factory_usages': typed,
            'violations': file_violations,
        })

    report = {
        'schema_version': 2,
        'generated_at_utc': datetime.now(timezone.utc).isoformat(),
        'raw_events': raw_events.most_common(),
        'typed_factory_definitions': typed_factory_definitions.most_common(),
        'typed_factory_usages': typed_factory_usages.most_common(),
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
        '## Factories typées définies',
        '',
        '| Factory | Occurrences |',
        '|---|---:|',
    ]
    for name, count in report['typed_factory_definitions']:
        lines.append(f'| `{name}` | {count} |')
    if not report['typed_factory_definitions']:
        lines.append('| — | 0 |')

    lines += [
        '',
        '## Factories typées utilisées',
        '',
        '| Factory | Occurrences |',
        '|---|---:|',
    ]
    for name, count in report['typed_factory_usages']:
        lines.append(f'| `{name}` | {count} |')
    if not report['typed_factory_usages']:
        lines.append('| — | 0 |')

    lines += [
        '',
        '## Violations Analytics confirmées statiquement',
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
        'Le scanner limite la recherche PII au bloc `parameters` des appels `logEvent`. Les factories typées appliquent en plus une validation à l’exécution.',
        '',
    ]
    (output / 'analytics-event-catalog.md').write_text(
        '\n'.join(lines),
        encoding='utf-8',
    )

    print(json.dumps({
        'raw_event_count': sum(raw_events.values()),
        'typed_factory_definition_count': sum(
            typed_factory_definitions.values()
        ),
        'typed_factory_usage_count': sum(typed_factory_usages.values()),
        'analytics_pii_violations': len(violations),
    }))

    if args.enforce and violations:
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
