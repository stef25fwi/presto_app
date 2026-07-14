class PublishOfferDraftPolicy {
  const PublishOfferDraftPolicy._();

  static String? normalizeDraftMissionDelay(String? rawUrgency) {
    final urgency = (rawUrgency ?? '').trim().toLowerCase();
    switch (urgency) {
      case 'immediat':
        return 'Urgent';
      case '24h':
        return 'Dans la journée';
      case 'demain':
        return 'Demain';
      case '48h':
        return 'Sous 48h';
      case '7j':
        return 'Cette semaine';
      case 'flexible':
        return 'À convenir';
      default:
        return null;
    }
  }

  static bool transcriptMentionsBudget(String transcript) {
    final lower = transcript.toLowerCase();
    return RegExp(r'\b\d{2,5}(?:[.,]\d{1,2})?\s*(€|euros?)\b')
            .hasMatch(lower) ||
        lower.contains('budget') ||
        lower.contains('tarif') ||
        lower.contains('prix') ||
        lower.contains('à négocier') ||
        lower.contains('a negocier');
  }

  static bool transcriptMentionsUrgency(String transcript) {
    final lower = transcript.toLowerCase();
    return lower.contains('urgent') ||
        lower.contains('urgence') ||
        lower.contains("aujourd'hui") ||
        lower.contains('aujourd hui') ||
        lower.contains('demain') ||
        lower.contains('ce soir') ||
        lower.contains('48h') ||
        lower.contains('cette semaine') ||
        lower.contains('rapidement') ||
        lower.contains('dès que possible') ||
        lower.contains('des que possible') ||
        lower.contains('immédiat') ||
        lower.contains('immediat');
  }

  static String? extractMissionDelayFromTranscript(String transcript) {
    final lower = transcript.toLowerCase();

    if (lower.contains('à convenir') ||
        lower.contains('a convenir') ||
        lower.contains('quand vous pouvez') ||
        lower.contains('quand tu peux') ||
        lower.contains('flexible') ||
        lower.contains('pas urgent')) {
      return 'À convenir';
    }
    if (lower.contains('urgent') ||
        lower.contains('urgence') ||
        lower.contains('immédiat') ||
        lower.contains('immediat')) {
      return 'Urgent';
    }
    if (lower.contains("aujourd'hui") ||
        lower.contains('aujourd hui') ||
        lower.contains('dans la journée') ||
        lower.contains('dans la journee') ||
        lower.contains('24h')) {
      return 'Dans la journée';
    }
    if (lower.contains('demain')) {
      return 'Demain';
    }
    if (lower.contains('48h') || lower.contains('sous 48h')) {
      return 'Sous 48h';
    }
    if (lower.contains('cette semaine') ||
        lower.contains('dans la semaine') ||
        lower.contains('7 jours') ||
        lower.contains('7j')) {
      return 'Cette semaine';
    }

    return null;
  }

  static bool transcriptRequestsNegotiatedBudget(String transcript) {
    final lower = transcript.toLowerCase();
    return lower.contains('à négocier') ||
        lower.contains('a negocier') ||
        lower.contains('à discuter') ||
        lower.contains('a discuter') ||
        lower.contains('prix flexible') ||
        lower.contains('budget flexible');
  }

  static double? extractBudgetAmountFromTranscript(String transcript) {
    final matches = RegExp(
      r'\b(\d{2,5}(?:[.,]\d{1,2})?)\s*(€|euros?)\b',
      caseSensitive: false,
    ).allMatches(transcript);

    for (final match in matches) {
      final raw = (match.group(1) ?? '').replaceAll(',', '.');
      final value = double.tryParse(raw);
      if (value != null && value > 0) {
        return value;
      }
    }

    return null;
  }

  static String buildRichDraftDescription(Map<String, dynamic> draft) {
    final shortDescription =
        ((draft['description_courte'] ?? draft['description']) as String? ?? '')
            .trim();
    final details = (draft['details'] is List)
        ? (draft['details'] as List)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];
    final availabilities =
        ((draft['disponibilites'] ?? '') as String?)?.trim() ?? '';

    final uniqueDetails = filterRedundantDetails(shortDescription, details);

    final lines = <String>[];
    if (shortDescription.isNotEmpty) {
      lines.add(shortDescription);
    }
    if (uniqueDetails.isNotEmpty) {
      lines.addAll(uniqueDetails.map((detail) => '- $detail'));
    }
    if (availabilities.isNotEmpty) {
      lines.add('Disponibilités : $availabilities');
    }
    return lines.join('\n').trim();
  }

  static String firstNonEmptyDraftValue(
    Map<String, dynamic> draft,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = draft[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static List<String> filterRedundantDetails(
    String description,
    List<String> details,
  ) {
    final referenceWords = significantDetailWords(description);
    final kept = <String>[];
    for (final detail in details) {
      final words = significantDetailWords(detail);
      if (words.isEmpty) continue;
      final matched = words
          .where((w) => referenceWords.any((d) => detailWordsMatch(w, d)))
          .length;
      if (matched / words.length >= 0.6) continue;
      kept.add(detail);
      referenceWords.addAll(words);
    }
    return kept;
  }

  static List<String> significantDetailWords(String text) {
    return normalizeDetailText(text)
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4 && !_detailFillerWords.contains(w))
        .toList();
  }

  static bool detailWordsMatch(String a, String b) {
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;
    final maxCommon = a.length < b.length ? a.length : b.length;
    var common = 0;
    while (common < maxCommon && a[common] == b[common]) {
      common++;
    }
    return common >= 5;
  }

  static String normalizeDetailText(String input) {
    const accents = 'àâäáãåçèéêëìíîïñòóôöõùúûüýÿ';
    const plain = 'aaaaaaceeeeiiiinooooouuuuyy';
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      final idx = accents.indexOf(ch);
      if (idx >= 0) {
        buffer.write(plain[idx]);
      } else if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
        buffer.write(ch);
      } else {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  static const Set<String> _detailFillerWords = {
    'avec',
    'pour',
    'dans',
    'chez',
    'vers',
    'sans',
    'sous',
    'entre',
    'plus',
    'tres',
    'tout',
    'toute',
    'tous',
    'toutes',
    'cette',
    'votre',
    'notre',
    'leur',
    'elle',
    'nous',
    'vous',
    'sont',
    'etre',
    'avoir',
    'faire',
    'merci',
    'besoin',
    'recherche',
    'recherchee',
    'demande',
    'secteur',
    'zone',
    'ville',
    'commune',
    'quartier',
  };
}
