import { readFile, writeFile } from 'node:fs/promises';

const path = 'lib/pages/home_page.dart';
let source = await readFile(path, 'utf8');

const replaceOnce = (before, after, label) => {
  if (!source.includes(before)) {
    throw new Error(`Bloc introuvable: ${label}`);
  }
  source = source.replace(before, after);
};

replaceOnce(
  "import '../features/offers/public_offers_read_diagnostics.dart';\n",
  "import '../features/offers/home_offer_keywords.dart';\nimport '../features/offers/public_offers_read_diagnostics.dart';\n",
  'keywords import',
);

replaceOnce(
  `  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?\n      _dynamicKeywordsSubscription;\n\n`,
  '',
  'keywords subscription field',
);

replaceOnce(
  `    _listenDynamicKeywords();\n\n    unawaited(_refreshLatestOffers());`,
  `    unawaited(_refreshLatestOffers());`,
  'init keyword listener',
);

replaceOnce(
  `  void _listenDynamicKeywords() {\n    _dynamicKeywordsSubscription?.cancel();\n\n    Future<void> loadKeywords() async {\n      try {\n        // 60 docs is enough to populate the keyword chips; 200 was wasteful and\n        // delayed the home render because it ran in parallel with the main\n        // offers query.\n        final snapshot = await _recentOffersQuery(limit: 60).get();\n        final words = <String>{};\n        for (final doc in snapshot.docs) {\n          final data = doc.data();\n          if (!isPublishedOfferData(data)) continue;\n          final title = (data['title'] ?? '').toString().toLowerCase();\n          final description =\n              (data['description'] ?? '').toString().toLowerCase();\n          final combined = '$title $description';\n          for (final word in combined.split(RegExp(r'\\s+'))) {\n            if (word.length > 3 &&\n                !RegExp(r'[0-9]').hasMatch(word) &&\n                !word.startsWith('0')) {\n              words.add(word);\n            }\n          }\n        }\n\n        final next = words.toList()..sort();\n\n        if (!mounted) return;\n        if (listEquals(_dynamicKeywords, next)) return;\n\n        setState(() {\n          _dynamicKeywords = next;\n        });\n      } catch (e) {\n        debugPrint('Dynamic keywords load error: $e');\n      }\n    }\n\n    _dynamicKeywordsSubscription = null;\n    // Defer the keyword pre-fetch so the home offers query owns the network\n    // priority for the first frame.\n    WidgetsBinding.instance.addPostFrameCallback((_) {\n      if (!mounted) return;\n      unawaited(loadKeywords());\n    });\n  }\n\n`,
  '',
  'keyword Firestore loader',
);

replaceOnce(
  `    _dynamicKeywordsSubscription?.cancel();\n`,
  '',
  'subscription dispose',
);

replaceOnce(
  `      final docs = await _loadLatestOffers();\n      if (!mounted) return;\n      setState(() {\n        _latestOffers = docs;\n        _isLatestOffersLoading = false;\n        _latestOffersError = null;\n        _lastLatestOffersLoadedAt = DateTime.now();\n      });`,
  `      final docs = await _loadLatestOffers();\n      final keywords = buildHomeOfferKeywords(\n        docs.map((doc) => doc.data()),\n      );\n      if (!mounted) return;\n      setState(() {\n        _latestOffers = docs;\n        _dynamicKeywords = keywords;\n        _isLatestOffersLoading = false;\n        _latestOffersError = null;\n        _lastLatestOffersLoadedAt = DateTime.now();\n      });`,
  'latest offers keyword derivation',
);

await writeFile(path, source, 'utf8');
console.log('home keyword Firestore read removed');
