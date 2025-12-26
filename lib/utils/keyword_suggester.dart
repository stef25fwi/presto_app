import 'dart:math' as math;

/// Un item de suggestion (chip)
class SuggestionItem {
  final String label;

  /// Mots-clés “canon” qui décrivent le projet
  /// (ex: ["gateau", "patisserie", "traiteur", "sucre"])
  final List<String> keywords;

  /// Tags/catégories optionnels (ex: ["food", "artisanat"])
  final List<String> tags;

  /// Régions compatibles (vide = toutes)
  final List<String> regions;

  /// Situations compatibles (vide = toutes)
  final List<String> situations;

  /// Poids manuel (0..100) pour prioriser certaines suggestions
  final double weight;

  /// Popularité (0..100) pour départager à score égal
  final double popularity;

  const SuggestionItem({
    required this.label,
    required this.keywords,
    this.tags = const [],
    this.regions = const [],
    this.situations = const [],
    this.weight = 0,
    this.popularity = 0,
  });

  String get normLabel => KeywordSuggester.normalize(label);
  List<String> get normKeywords =>
      keywords.map(KeywordSuggester.normalize).toList(growable: false);
  List<String> get normTags =>
      tags.map(KeywordSuggester.normalize).toList(growable: false);
}

class KeywordSuggester {
  /// Stopwords FR (tu peux compléter)
  static const Set<String> _stop = {
    "je", "tu", "il", "elle", "on", "nous", "vous", "ils", "elles",
    "de", "des", "du", "la", "le", "les", "un", "une", "et", "ou",
    "a", "au", "aux", "pour", "avec", "sans", "sur", "dans",
    "mon", "ma", "mes", "ton", "ta", "tes", "son", "sa", "ses",
    "faire", "cree", "creer", "creation", "projet", "entreprise",
  };

  /// Synonymes / variantes (sans IA)
  /// Clé = token normalisé, valeur = expansions
  static final Map<String, List<String>> synonyms = {
    "gateau": ["patisserie", "sucre", "dessert", "traiteur", "boulangerie"],
    "coiffure": ["coiffeur", "barbier", "tresse", "locks", "esthetique"],
    "vitrine": ["site", "internet", "web", "landing", "page"],
    "ecommerce": ["boutique", "shop", "vente", "enligne", "enligne"],
    "livraison": ["transport", "coursier", "colis", "logistique"],
    "menage": ["nettoyage", "entretien", "proprete"],
    "bricolage": ["renovation", "reparation", "travaux"],
    "formation": ["apprendre", "certification", "diplome"],
  };

  /// Normalisation (accents, ponctuation -> espaces, lowercase)
  static String normalize(String input) {
    final s = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"[’']"), " ")
        .replaceAll(RegExp(r"[^a-z0-9\s-]"), " ")
        .replaceAll("-", " ")
        .replaceAll(RegExp(r"\s+"), " ");
    return _removeDiacritics(s);
  }

  static String _removeDiacritics(String s) {
    // mapping simple (suffisant pour FR)
    const map = {
      'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
      'ç': 'c',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
      'ÿ': 'y', 'ñ': 'n',
    };
    final b = StringBuffer();
    for (final ch in s.split('')) {
      b.write(map[ch] ?? ch);
    }
    return b.toString();
  }

  /// Tokenization + mini “stemming” (très léger, sans IA)
  static List<String> tokenize(String input) {
    final n = normalize(input);
    if (n.isEmpty) return const [];
    final raw = n.split(' ').where((t) => t.isNotEmpty).toList();

    final out = <String>[];
    for (final t in raw) {
      if (_stop.contains(t)) continue;
      out.add(_stem(t));
    }
    return out;
  }

  static String _stem(String t) {
    // Stem minimal pour FR (évite d’être agressif)
    if (t.length <= 3) return t;
    var x = t;
    // pluriels basiques
    if (x.endsWith('s') && x.length > 4) x = x.substring(0, x.length - 1);
    if (x.endsWith('es') && x.length > 5) x = x.substring(0, x.length - 2);
    // infinitif “er” (creer, livrer -> cre, livr) : très léger
    if (x.endsWith('er') && x.length > 5) x = x.substring(0, x.length - 2);
    return x;
  }

  /// Similarité Levenshtein (0..1) (fuzzy)
  static double similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final d = _levenshtein(a, b);
    final m = math.max(a.length, b.length);
    return (m - d) / m;
  }

  static int _levenshtein(String s, String t) {
    final n = s.length, m = t.length;
    if (n == 0) return m;
    if (m == 0) return n;

    final prev = List<int>.generate(m + 1, (j) => j);
    final curr = List<int>.filled(m + 1, 0);

    for (int i = 1; i <= n; i++) {
      curr[0] = i;
      final si = s.codeUnitAt(i - 1);
      for (int j = 1; j <= m; j++) {
        final cost = (si == t.codeUnitAt(j - 1)) ? 0 : 1;
        curr[j] = math.min(
          math.min(curr[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
      }
      for (int j = 0; j <= m; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[m];
  }

  /// Calcul des suggestions
  static List<SuggestionItem> compute({
    required String query,
    required List<SuggestionItem> items,
    String? region,     // ex: "Guadeloupe"
    String? situation,  // ex: "Sans emploi"
    int limit = 8,
  }) {
    final qNorm = normalize(query);
    final tokens = tokenize(query);

    // expansions synonymes (tokens + synonyms)
    final expanded = <String>{...tokens};
    for (final t in tokens) {
      final syn = synonyms[t];
      if (syn != null) expanded.addAll(syn.map(_stem));
    }
    final expandedTokens = expanded.toList();

    // bigrammes (ex: "vente gateau")
    final bigrams = <String>[];
    for (int i = 0; i < tokens.length - 1; i++) {
      bigrams.add("${tokens[i]} ${tokens[i + 1]}");
    }

    final scored = <({SuggestionItem item, double score})>[];

    for (final it in items) {
      double score = 0;

      // 0) priorités manuelles / popularité
      score += it.weight * 0.06;      // poids léger mais utile
      score += it.popularity * 0.02;  // départage

      // 1) compat région/situation
      final r = (region == null) ? "" : normalize(region);
      final s = (situation == null) ? "" : normalize(situation);

      if (it.regions.isNotEmpty) {
        final ok = it.regions.map(normalize).contains(r);
        score += ok ? 2.0 : -4.0; // pénalité si non compatible
      }
      if (it.situations.isNotEmpty) {
        final ok = it.situations.map(normalize).contains(s);
        score += ok ? 1.5 : -3.0;
      }

      // 2) matching label global
      final label = it.normLabel;
      if (qNorm.isNotEmpty) {
        if (label.startsWith(qNorm)) score += 6;
        else if (label.contains(qNorm)) score += 3;
      }

      // 3) matching tokens sur keywords/tags
      final kws = it.normKeywords.map(_stem).toList(growable: false);
      final tags = it.normTags.map(_stem).toList(growable: false);
      final pool = <String>[...kws, ...tags, ...label.split(' ').map(_stem)];

      int matchedTokens = 0;

      for (final tkn in expandedTokens) {
        if (tkn.isEmpty) continue;

        bool hit = false;

        // exact
        if (pool.contains(tkn)) {
          score += 5.0;
          hit = true;
        } else {
          // prefix / contains
          for (final p in pool) {
            if (p.startsWith(tkn)) {
              score += 3.2;
              hit = true;
              break;
            }
            if (p.contains(tkn) && tkn.length >= 4) {
              score += 1.6;
              hit = true;
              break;
            }
          }

          // fuzzy (typos)
          if (!hit && tkn.length >= 4) {
            double best = 0;
            for (final p in pool) {
              if ((p.length - tkn.length).abs() > 2) continue;
              best = math.max(best, similarity(tkn, p));
              if (best >= 0.90) break;
            }
            if (best >= 0.88) {
              score += 2.2;
              hit = true;
            } else if (best >= 0.78) {
              score += 1.2;
              hit = true;
            }
          }
        }

        if (hit) matchedTokens++;
      }

      // 4) bonus bigrammes (intention plus précise)
      if (bigrams.isNotEmpty) {
        final label2 = label;
        for (final bg in bigrams) {
          if (label2.contains(bg)) score += 4.5;
        }
      }

      // 5) bonus “coverage” (plus tu matches de tokens, plus c’est pertinent)
      if (tokens.isNotEmpty) {
        final coverage = matchedTokens / math.max(1, tokens.length);
        score += coverage * 4.0;
      }

      // 6) seuil minimal pour éviter bruit si query non vide
      final keep = query.trim().isNotEmpty ? score >= 2.0 : true;
      if (keep) scored.add((item: it, score: score));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      // tie-break: popularité, puis label plus court
      final byPop = b.item.popularity.compareTo(a.item.popularity);
      if (byPop != 0) return byPop;
      return a.item.label.length.compareTo(b.item.label.length);
    });

    // fallback intelligent : si rien et query non vide -> top “populaires” compatibles
    if (scored.isEmpty && query.trim().isNotEmpty) {
      final fallback = items.where((it) {
        final r = region == null ? "" : normalize(region);
        final s = situation == null ? "" : normalize(situation);
        final okR = it.regions.isEmpty || it.regions.map(normalize).contains(r);
        final okS = it.situations.isEmpty || it.situations.map(normalize).contains(s);
        return okR && okS;
      }).toList()
        ..sort((a, b) => b.popularity.compareTo(a.popularity));
      return fallback.take(limit).toList();
    }

    return scored.take(limit).map((e) => e.item).toList();
  }
}
