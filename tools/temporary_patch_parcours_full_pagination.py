#!/usr/bin/env python3

from pathlib import Path

PATH = Path('lib/services/journey_pdf_export_service.dart')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if text.count(old) != 1:
        raise RuntimeError(f'{label}: remplacement attendu une fois')
    return text.replace(old, new, 1)


def main() -> None:
    text = PATH.read_text(encoding='utf-8')

    old_chunks = """    const maxActionsPerCard = 12;
    final chunks = <List<String>>[];

    if (actions.isEmpty) {
      chunks.add(const <String>[]);
    } else {
      for (var start = 0; start < actions.length; start += maxActionsPerCard) {
        final proposedEnd = start + maxActionsPerCard;
        final end = proposedEnd < actions.length ? proposedEnd : actions.length;
        chunks.add(actions.sublist(start, end));
      }
    }
"""
    new_chunks = """    const maxActionsPerCard = 4;
    const maxCharactersPerCard = 1100;
    final chunks = <List<String>>[];

    if (actions.isEmpty) {
      chunks.add(const <String>[]);
    } else {
      var current = <String>[];
      var currentCharacters = 0;
      for (final action in actions.expand(_splitLongAction)) {
        final wouldOverflowCount = current.length >= maxActionsPerCard;
        final wouldOverflowText = current.isNotEmpty &&
            currentCharacters + action.length > maxCharactersPerCard;
        if (wouldOverflowCount || wouldOverflowText) {
          chunks.add(current);
          current = <String>[];
          currentCharacters = 0;
        }
        current.add(action);
        currentCharacters += action.length;
      }
      if (current.isNotEmpty) {
        chunks.add(current);
      }
    }
"""
    text = replace_once(text, old_chunks, new_chunks, 'découpage des actions')

    marker = "  static pw.Widget _stepCardChunk({\n"
    helper = """  static Iterable<String> _splitLongAction(String action) sync* {
    const maxCharacters = 850;
    final normalized = action.trim();
    if (normalized.length <= maxCharacters) {
      if (normalized.isNotEmpty) yield normalized;
      return;
    }

    var remaining = normalized;
    while (remaining.length > maxCharacters) {
      var cut = remaining.lastIndexOf(' ', maxCharacters);
      if (cut < maxCharacters ~/ 2) {
        cut = maxCharacters;
      }
      yield remaining.substring(0, cut).trim();
      remaining = remaining.substring(cut).trim();
    }
    if (remaining.isNotEmpty) yield remaining;
  }

"""
    text = replace_once(text, marker, helper + marker, 'helper de découpage texte')

    text = replace_once(
        text,
        """      pw.MultiPage(
        pageTheme: pw.PageTheme(
""",
        """      pw.MultiPage(
        maxPages: 100,
        pageTheme: pw.PageTheme(
""",
        'limite de pages',
    )

    PATH.write_text(text, encoding='utf-8')


if __name__ == '__main__':
    main()
