/// Pagination par curseur, indépendante de Firebase et des filtres locaux.
class ConsultOffersPager<T> {
  ConsultOffersPager({
    required this.idOf,
    required this.fetchPage,
    this.pageSize = 20,
  }) : assert(pageSize > 0);

  final String Function(T) idOf;
  final Future<List<T>> Function(T cursor, int limit) fetchPage;
  final int pageSize;
  List<T> docs = <T>[];
  T? cursor;
  String? queryKey;
  int generation = 0;
  bool initialized = false;
  bool loading = false;
  bool hasMore = false;
  Object? error;

  void reset(String key) {
    generation++;
    queryKey = key;
    docs = <T>[];
    cursor = null;
    initialized = false;
    loading = false;
    hasMore = false;
    error = null;
  }

  void seed({
    required int requestGeneration,
    required List<T> canonicalPage,
    required List<T> displayedPage,
  }) {
    if (requestGeneration != generation) return;
    docs = List<T>.of(displayedPage);
    // Le curseur ne doit jamais provenir de la collection legacy fusionnée.
    cursor = canonicalPage.isEmpty ? null : canonicalPage.last;
    hasMore = canonicalPage.length == pageSize;
    initialized = true;
  }

  Future<bool> loadNext() async {
    final after = cursor;
    if (loading || !hasMore || after == null) return false;
    final requestGeneration = generation;
    loading = true;
    error = null;
    try {
      final page = await fetchPage(after, pageSize);
      if (requestGeneration != generation) return false;
      if (page.isNotEmpty && idOf(page.last) == idOf(after)) {
        throw StateError('Le curseur de pagination n’a pas avancé.');
      }
      final merged = <String, T>{for (final doc in docs) idOf(doc): doc};
      for (final doc in page) {
        merged.putIfAbsent(idOf(doc), () => doc);
      }
      docs = merged.values.toList(growable: false);
      if (page.isNotEmpty) cursor = page.last;
      hasMore = page.length == pageSize;
      return true;
    } catch (failure) {
      if (requestGeneration == generation) error = failure;
      return false;
    } finally {
      if (requestGeneration == generation) loading = false;
    }
  }
}

String consultOffersResultLabel({
  required int count,
  required bool initialized,
  required bool hasMore,
}) {
  if (!initialized) return 'Chargement des annonces…';
  final plural = count > 1 ? 's' : '';
  final label = '$count annonce$plural affichée$plural';
  return hasMore ? '$label · résultats partiels' : label;
}
