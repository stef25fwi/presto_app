#!/usr/bin/env python3
"""Catalog Firestore access patterns in authored Dart source files."""

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

PATTERNS = {
    'firestore_instance': re.compile(r'FirebaseFirestore\.instance'),
    'collection': re.compile(r'\.collection\(\s*[\'\"]([^\'\"]+)[\'\"]\s*\)'),
    'collection_group': re.compile(r'\.collectionGroup\(\s*[\'\"]([^\'\"]+)[\'\"]\s*\)'),
    'where': re.compile(r'\.where\s*\('),
    'order_by': re.compile(r'\.orderBy\s*\('),
    'limit': re.compile(r'\.limit\s*\('),
    'start_after': re.compile(r'\.startAfter(?:Document|DocumentId)?\s*\('),
    'snapshots': re.compile(r'\.snapshots\s*\('),
    'get': re.compile(r'\.get\s*\('),
    'count': re.compile(r'\.count\s*\('),
    'write_batch': re.compile(r'\.batch\s*\('),
    'transaction': re.compile(r'runTransaction\s*\('),
}


def dart_files(root: Path):
    lib = root / 'lib'
    if not lib.exists():
        return
    for path in lib.rglob('*.dart'):
        relative = path.relative_to(root)
        if set(relative.parts) & EXCLUDED_PARTS:
            continue
        yield path


def scan_file(path: Path, root: Path) -> dict:
    text = path.read_text(encoding='utf-8', errors='replace')
    lines = text.splitlines()
    counts = {name: len(pattern.findall(text)) for name, pattern in PATTERNS.items()}
    collections = Counter(PATTERNS['collection'].findall(text))
    collection_groups = Counter(PATTERNS['collection_group'].findall(text))

    findings = []
    interesting = ('FirebaseFirestore.instance', '.snapshots(', '.get(', '.collection(')
    for number, line in enumerate(lines, start=1):
        stripped = line.strip()
        if any(marker in stripped for marker in interesting):
            findings.append({'line': number, 'code': stripped[:240]})

    risk_flags = []
    if counts['snapshots'] > 0:
        risk_flags.append('realtime_listener_review')
    if counts['get'] > 0 and counts['limit'] == 0 and counts['collection'] > 0:
        risk_flags.append('possible_unbounded_read')
    if counts['get'] >= 3:
        risk_flags.append('possible_n_plus_one')
    if counts['collection'] > 0 and counts['start_after'] == 0 and counts['limit'] == 0:
        risk_flags.append('pagination_not_visible')

    return {
        'path': path.relative_to(root).as_posix(),
        'counts': counts,
        'collections': dict(collections),
        'collection_groups': dict(collection_groups),
        'risk_flags': risk_flags,
        'findings': findings,
    }


def render_markdown(report: dict) -> str:
    totals = report['totals']
    lines = [
        '# Catalogue des accès Firestore',
        '',
        f"Généré le `{report['generated_at_utc']}`.",
        '',
        'Les drapeaux sont des signaux de revue manuelle, pas des preuves de défaut.',
        '',
        '## Résumé',
        '',
        '| Indicateur | Nombre |',
        '|---|---:|',
    ]
    labels = {
        'files_with_firestore': 'Fichiers utilisant Firestore',
        'firestore_instance': 'Accès FirebaseFirestore.instance',
        'collection': 'Collections littérales',
        'collection_group': 'Collection groups',
        'where': 'Filtres where',
        'order_by': 'Tris orderBy',
        'limit': 'Limites',
        'start_after': 'Curseurs startAfter',
        'snapshots': 'Listeners snapshots',
        'get': 'Lectures get',
        'count': 'Agrégations count',
        'write_batch': 'Write batches',
        'transaction': 'Transactions',
    }
    for key, label in labels.items():
        lines.append(f'| {label} | {totals.get(key, 0)} |')

    lines += [
        '',
        '## Collections les plus référencées',
        '',
        '| Collection | Occurrences |',
        '|---|---:|',
    ]
    for name, count in report['collections'][:30]:
        lines.append(f'| `{name}` | {count} |')
    if not report['collections']:
        lines.append('| — | 0 |')

    lines += [
        '',
        '## Fichiers à examiner',
        '',
        '| Fichier | Listeners | Get | Limit | Curseurs | Signaux |',
        '|---|---:|---:|---:|---:|---|',
    ]
    ranked = sorted(
        report['files'],
        key=lambda item: (
            len(item['risk_flags']),
            item['counts']['snapshots'],
            item['counts']['get'],
        ),
        reverse=True,
    )
    for item in ranked:
        counts = item['counts']
        flags = ', '.join(item['risk_flags']) or '—'
        lines.append(
            f"| `{item['path']}` | {counts['snapshots']} | {counts['get']} | "
            f"{counts['limit']} | {counts['start_after']} | {flags} |"
        )
    if not ranked:
        lines.append('| — | 0 | 0 | 0 | 0 | — |')

    lines += [
        '',
        '## Règles de revue',
        '',
        '- Justifier chaque listener temps réel et garantir son annulation.',
        '- Paginer toute liste potentiellement longue avec `limit` et curseur.',
        '- Éviter les lectures N+1 en dénormalisant les résumés publics utiles.',
        '- Préférer des agrégats pour les tableaux de bord plutôt que recompter toute une collection.',
        '- Tester les règles et requêtes avec Firebase Emulator Suite.',
        '',
    ]
    return '\n'.join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', default='.')
    parser.add_argument('--output-dir', default='quality_reports/firestore')
    args = parser.parse_args()

    root = Path(args.root).resolve()
    output = (root / args.output_dir).resolve()
    output.mkdir(parents=True, exist_ok=True)

    files = []
    collection_counter = Counter()
    totals = Counter()
    for path in dart_files(root) or []:
        item = scan_file(path, root)
        if not any(item['counts'].values()):
            continue
        files.append(item)
        collection_counter.update(item['collections'])
        collection_counter.update(item['collection_groups'])
        totals.update(item['counts'])

    totals['files_with_firestore'] = len(files)
    report = {
        'schema_version': 1,
        'generated_at_utc': datetime.now(timezone.utc).isoformat(),
        'totals': dict(totals),
        'collections': collection_counter.most_common(),
        'files': files,
    }

    (output / 'firestore-query-catalog.json').write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + '\n',
        encoding='utf-8',
    )
    (output / 'firestore-query-catalog.md').write_text(
        render_markdown(report),
        encoding='utf-8',
    )
    print(json.dumps(report['totals'], ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
