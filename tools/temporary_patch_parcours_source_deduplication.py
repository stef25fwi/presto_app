#!/usr/bin/env python3

from pathlib import Path

PATH = Path('lib/services/journey_pdf_export_service.dart')


def main() -> None:
    text = PATH.read_text(encoding='utf-8')
    old = """        final key = _fingerprint(url);
        if (url.isEmpty || seen.contains(key)) continue;
        seen.add(key);
"""
    new = """        final key = url.toLowerCase();
        if (url.isEmpty || seen.contains(key)) continue;
        seen.add(key);
"""
    if text.count(old) != 1:
        raise RuntimeError('Déduplication URL attendue introuvable ou ambiguë')
    PATH.write_text(text.replace(old, new, 1), encoding='utf-8')


if __name__ == '__main__':
    main()
