#!/usr/bin/env python3

from pathlib import Path

PATH = Path('lib/services/journey_pdf_export_service.dart')


def main() -> None:
    text = PATH.read_text(encoding='utf-8')
    old = 'pw.NewPage(freeSpace: 320)'
    new = 'pw.NewPage(freeSpace: 500)'
    if text.count(old) != 1:
        raise RuntimeError('Seuil de carte attendu introuvable ou ambigu')
    PATH.write_text(text.replace(old, new, 1), encoding='utf-8')


if __name__ == '__main__':
    main()
