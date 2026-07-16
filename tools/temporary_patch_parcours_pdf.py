#!/usr/bin/env python3

from pathlib import Path
import re

PATH = Path('lib/services/journey_pdf_export_service.dart')


def replace_once(text: str, pattern: re.Pattern[str], replacement: str, label: str) -> str:
    updated, count = pattern.subn(replacement, text, count=1)
    if count != 1:
        raise RuntimeError(f'{label}: {count} remplacement(s), 1 attendu')
    return updated


def main() -> None:
    text = PATH.read_text(encoding='utf-8')

    call_pattern = re.compile(
        r'(?m)^(\s*)widgets\.add\(\s*\n\s*_stepCard\('
    )
    call_match = call_pattern.search(text)
    if call_match is None:
        raise RuntimeError('Appel _stepCard introuvable')
    indent = call_match.group(1)
    text = call_pattern.sub(
        f'{indent}widgets.addAll(\n{indent}  _stepCards(',
        text,
        count=1,
    )

    method_pattern = re.compile(
        r'(?ms)^  static pw\.Widget _stepCard\(\{.*?'
        r'^  \}\n\n(?=  static List<String> _stepActions\()'
    )
    new_method = '''  static List<pw.Widget> _stepCards({
    required int number,
    required String title,
    required String objective,
    required List<String> actions,
    required String expectedResult,
  }) {
    const maxActionsPerCard = 12;
    final chunks = <List<String>>[];

    if (actions.isEmpty) {
      chunks.add(const <String>[]);
    } else {
      for (var start = 0;
          start < actions.length;
          start += maxActionsPerCard) {
        final proposedEnd = start + maxActionsPerCard;
        final end =
            proposedEnd < actions.length ? proposedEnd : actions.length;
        chunks.add(actions.sublist(start, end));
      }
    }

    return [
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
  }

  static pw.Widget _stepCardChunk({
    required String heading,
    required String objective,
    required List<String> actions,
    required String expectedResult,
  }) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 8,
            ),
            decoration: const pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(10),
                topRight: pw.Radius.circular(10),
              ),
            ),
            child: pw.Text(
              heading,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(11),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (objective.isNotEmpty) ...[
                  _miniHeading('Objectif'),
                  _paragraph(objective),
                ],
                if (actions.isNotEmpty) ...[
                  _miniHeading('Actions à réaliser'),
                  ...actions.map(_checkLine),
                ],
                if (expectedResult.isNotEmpty) ...[
                  _miniHeading('Résultat attendu avant de continuer'),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      border: pw.Border.all(color: PdfColors.green200),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      expectedResult,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        lineSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
'''
    text = replace_once(
        text,
        method_pattern,
        new_method,
        'Méthode _stepCard',
    )

    letter_pattern = re.compile(
        r'''      for \(final template in letterTemplates\) \{\n'''
        r'''        widgets\.add\(_letterTemplate\(template\)\);\n'''
        r'''      \}'''
    )
    letter_replacement = '''      for (var index = 0; index < letterTemplates.length; index++) {
        if (index > 0) widgets.add(pw.NewPage());
        widgets.add(_letterTemplate(letterTemplates[index]));
      }'''
    text = replace_once(
        text,
        letter_pattern,
        letter_replacement,
        'Pagination des courriers',
    )

    # Inter ne fournit pas de variante italique dans le thème actuel. Retirer
    # l’italique évite le repli Helvetica et les glyphes Unicode manquants.
    text = text.replace('              fontStyle: pw.FontStyle.italic,\n', '')

    PATH.write_text(text, encoding='utf-8')
    print('Correctif de pagination PDF appliqué.')


if __name__ == '__main__':
    main()
