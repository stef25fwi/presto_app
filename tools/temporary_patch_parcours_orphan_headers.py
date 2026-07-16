#!/usr/bin/env python3

from pathlib import Path

PATH = Path('lib/services/journey_pdf_export_service.dart')


def main() -> None:
    text = PATH.read_text(encoding='utf-8')
    old = """    return [
      for (var index = 0; index < chunks.length; index++)
        _stepCardChunk(
          heading: index == 0
              ? 'Étape $number - $title'
              : 'Étape $number - $title (suite ${index + 1})',
          objective: index == 0 ? objective : '',
          actions: chunks[index],
          expectedResult: index == chunks.length - 1 ? expectedResult : '',
        ),
    ];
"""
    new = """    return [
      for (var index = 0; index < chunks.length; index++) ...[
        pw.NewPage(freeSpace: 320),
        _stepCardChunk(
          heading: index == 0
              ? 'Étape $number - $title'
              : 'Étape $number - $title (suite ${index + 1})',
          objective: index == 0 ? objective : '',
          actions: chunks[index],
          expectedResult: index == chunks.length - 1 ? expectedResult : '',
        ),
      ],
    ];
"""
    if text.count(old) != 1:
        raise RuntimeError('Construction des cartes attendue introuvable ou ambiguë')
    PATH.write_text(text.replace(old, new, 1), encoding='utf-8')


if __name__ == '__main__':
    main()
