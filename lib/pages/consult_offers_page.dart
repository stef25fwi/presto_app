import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_core.dart';
import '../constants.dart';
import '../features/offers/presentation/consult_offers_pagination_policy.dart';
import '../features/trust_score/trust_score_service.dart';
import '../features/trust_score/trust_score_widgets.dart';
import '../app/system_ui_style.dart' show prestoOverlayStyleFor;
import '../services/offer_details_mapper.dart' show buildOfferDetailsOffer;
import '../services/presto_monitoring.dart' show PrestoMonitoring;
import '../services/region_resolver.dart' show inferRegionFromPostalCode;
import '../widgets/app_shell_widgets.dart' show CardShell;
import 'home_page.dart' show UnreadInboxBell;
import 'account_page.dart';
import '../pages/offers/offer_details_page.dart';
import '../services/app_route_parser.dart';
import '../services/conversation_service.dart';
import '../services/city_search.dart';
import '../services/firebase_functions_region.dart';
import '../services/offer_indexing.dart';
import '../services/public_offers_query_helpers.dart';
import '../utils/friendly_snackbar.dart';
import '../utils/offer_helpers.dart';

import '../utils/runtime_action_logger.dart';
import '../widgets/ad_banner.dart';
import '../widgets/home_interactions.dart';
import '../widgets/offer_network_image.dart';
import 'messages/messages_page_v2.dart';
import 'package:presto_app/widgets/deleted_user_profile.dart';
import 'package:presto_app/services/profile_department_resolver.dart';

class ConsultOffersPage extends StatefulWidget {
  final String? categoryFilter;
  final String? searchQuery;
  final Function(double)? onScroll;

  const ConsultOffersPage({
    super.key,
    this.categoryFilter,
    this.searchQuery,
    this.onScroll,
  });

  @override
  State<ConsultOffersPage> createState() => _ConsultOffersPageState();
}

class _Debouncer {
  _Debouncer({this.delay = const Duration(milliseconds: 300)});
  final Duration delay;
  Timer? _t;

  void run(void Function() action) {
    _t?.cancel();
    _t = Timer(delay, action);
  }

  void dispose() => _t?.cancel();
}

class _ConsultOffersPageState extends State<ConsultOffersPage>
    with WidgetsBindingObserver {
  static const Color _offersBg = Colors.white;
  static const Color _offersNavy = Color(0xFF1E2554);
  static const Color _offersOrange = Color(0xFFFF7A00);
  static const Color _offersSoftText = Color(0xFF626584);
  static const Color _offersCardBorder = Color(0xFFF0E8E8);

  void _logPageView() {
    logRuntimeAction(
      area: 'consult',
      action: 'page-view',
      details: <String, Object?>{
        'categoryFilter': widget.categoryFilter ?? '',
        'searchQuery': widget.searchQuery ?? '',
      },
    );
  }

  void _logSearch(String searchQuery) {
    final query = searchQuery.trim();
    if (query.isEmpty) return;
    logRuntimeAction(
      area: 'consult',
      action: 'search',
      details: <String, Object?>{'query': query},
    );
  }

  void _logFilterUsage(String filterType, String value) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) return;
    logRuntimeAction(
      area: 'consult',
      action: 'filter-usage',
      details: <String, Object?>{'type': filterType, 'value': normalizedValue},
    );
  }

  void _logFiltersApplied({
    String? category,
    String? region,
    String? department,
    String? city,
    String? searchQuery,
    int? resultCount,
  }) {
    logRuntimeAction(
      area: 'consult',
      action: 'filters-applied',
      details: <String, Object?>{
        'category': category?.trim() ?? '',
        'region': region?.trim() ?? '',
        'department': department?.trim() ?? '',
        'city': city?.trim() ?? '',
        'searchQuery': searchQuery?.trim() ?? '',
        'resultCount': resultCount,
      },
    );
  }

  void _logOfferClicked(String offerId, String title) {
    logRuntimeAction(
      area: 'consult',
      action: 'open-offer',
      details: <String, Object?>{'offerId': offerId, 'title': title},
    );
  }

  void _logConsultOffersFetch(
    String action, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    logRuntimeAction(
      area: 'consult_offers',
      action: 'fetch.$action',
      details: details,
    );
  }

  // --- Normalisation (réduction index) ---
  String _slugId(String input) {
    final s = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll('œ', 'oe');
    return s
        .replaceAll(RegExp(r"[/\-'’']"), ' ')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  String? _makeCategoryId(String? categoryLabel) {
    final s = (categoryLabel ?? '').trim();
    if (s.isEmpty || s == 'Toutes catégories') return null;
    return resolveOfferCategoryId(s) ?? _slugId(s);
  }

  String? _makeCityId({required String cityName, required String postalCode}) {
    final city = cityName.trim();
    final cp = postalCode.trim();
    if (city.isEmpty || cp.length < 3) return null; // CP requis pour stabilité
    return '${cp}_${_slugId(city)}';
  }

  String? _makeCityCategoryKey({
    required String? cityId,
    required String? categoryId,
  }) {
    if (cityId == null || categoryId == null) return null;
    return '${cityId}_$categoryId';
  }

  // ✅ Range budget (AVANCÉ) — évite requêtes “impossibles” + explosion d’index
  final bool _advancedFilters = false;
  final TextEditingController _budgetMinCtrl = TextEditingController();
  final TextEditingController _budgetMaxCtrl = TextEditingController();
  String? _budgetRangeWarning; // affiché dans l’UI si range désactivé

  double? _parseBudgetBound(String raw) {
    final s = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Copié")));
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await canLaunchUrl(uri);
    if (!ok) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  final TextEditingController _keywordCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();

  int _filterPanelKey = 0;
  int _lastSnapshotRawCount = 0;
  DateTime? _lastPaginationRequestAt;

  String? _selectedCategory;
  String? _selectedRegionCode;
  String? _selectedSubCategory;

  // Cache du stream pour éviter de le recréer à chaque setState non pertinent.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>?
      _cachedOffersStream;
  String? _cachedOffersStreamKey;
  final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _offersWarmCache =
      <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
  final Set<String> _offersWarmLoadsInFlight = <String>{};

  final _Debouncer _filterDebounce = _Debouncer(
    delay: const Duration(milliseconds: 300),
  );

  String? _filterCategory;
  String? _filterRegionCode;
  String? _filterDepartmentCode;
  String? _filterCityName;
  bool _departmentResetScheduled = false;

  // Pagination par curseur : chaque page ne relit plus les documents déjà
  // affichés. La limite maximale borne aussi le coût d'une session.
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _paginationDocs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  String? _paginationKey;
  bool _isLoadingNextPage = false;
  bool _hasMorePages = true;

  static const ConsultOffersPaginationPolicy _paginationPolicy =
      ConsultOffersPaginationPolicy();
  int _pageLimit = _paginationPolicy.initialLimit;

  /// Mot-clé actif appliqué aux résultats (initialisé depuis searchQuery, réinitialisable)
  String? _activeSearchQuery;

  // Variables pour l'autocomplétion de ville dans les filtres
  final TextEditingController _filterCityController = TextEditingController();
  final TextEditingController _filterPostalCodeController =
      TextEditingController();
  final FocusNode _regionFocus = FocusNode();
  final FocusNode _deptFocus = FocusNode();
  final FocusNode _filterCityFocusNode = FocusNode();
  final Set<String> _manualAutoApplyCriteria = <String>{};
  List<CityRecord> _filterCitySuggestions = [];
  int _filterCityHighlightedIndex = -1;
  Timer? _filterCityDebounce;

  final ScrollController _scrollController = ScrollController();

  bool _showFilters = false; // Panneau de filtres rétracté au départ
  int _lastResultCount = 0;
  int? _totalPublishedCount;
  bool _isLoadingPublishedCount = false;
  String _headerTitle = 'Je consulte les offres';
  static const int _autoApplyFiltersThreshold = 3;

  late final Map<String, String> _deptToRegion = _buildDeptToRegion();

  // ✅ Cache de normalisation pour améliorer la performance de recherche
  final Map<String, String> _normalizedTextCache = {};

  // ✅ Mémoisation UI pour éviter de recalculer filtre/tri et payload tuiles
  String? _displayedDocsCacheSignature;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _displayedDocsCache;
  String? _renderItemsCacheSignature;
  List<_ConsultOfferListItem>? _renderItemsCache;

  // ✅ Cache des résultats Firestore pour éviter les re-queries
  Map<String, List<DocumentSnapshot<Map<String, dynamic>>>>? _queryResultsCache;
  String? _lastCachedQuerySignature;
  Timer? _cacheInvalidationTimer;
  Timer? _jobDoneOverlayTimer;
  DateTime? _nextJobDoneOverlayRefreshAt;

  /// Normalise un texte pour la recherche (diacritiques, casse, séparateurs)
  String _normalizeText(String input) {
    // Cache hit: retourner directement
    if (_normalizedTextCache.containsKey(input)) {
      return _normalizedTextCache[input]!;
    }

    final normalized = input
        .trim()
        .toLowerCase()
        // Diacritiques courants FR
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll('œ', 'oe')
        // Séparateurs usuels
        .replaceAll(RegExp(r"[/\-'’']"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    // Limiter la taille du cache à 200 entrées
    if (_normalizedTextCache.length > 200) {
      _normalizedTextCache.clear();
    }

    _normalizedTextCache[input] = normalized;
    return normalized;
  }

  String _normalizeForCategoryMatch(String input) {
    return _normalizeText(input);
  }

  String? _matchKnownCategory(String input) {
    return canonicalizeOfferCategory(input);
  }

  Map<String, String> _buildDeptToRegion() {
    final out = <String, String>{};
    for (final entry in kRegionDepartments.entries) {
      for (final deptCode in entry.value) {
        out[deptCode] = entry.key;
      }
    }
    return out;
  }

  // ✅ Départements affichés selon région sélectionnée
  List<String> get _filteredDepartmentCodes {
    if (_filterRegionCode == null) {
      return kDepartments.keys.toList();
    }
    final depts = kRegionDepartments[_filterRegionCode!];
    return depts?.toList() ?? [];
  }

  // ✅ Les départements autorisés pour filtrer les villes
  List<String>? get _allowedDeptCodesForCity {
    if (_filterDepartmentCode != null) return [_filterDepartmentCode!];
    if (_filterRegionCode == null) return null; // null = pas de limite
    return _filteredDepartmentCodes;
  }

  /// Badge = messages non lus + notifications d'annonces (dont favoris)
  Widget _buildConsultNotificationBell() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (user == null) {
          return IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              showSuccessSnackBar(
                context,
                'Connecte-toi pour recevoir les notifications.',
              );
            },
            icon: const PrestoNotificationBellBase(
              badgeCount: 0,
              showBackground: false,
              iconColor: Colors.white,
            ),
            splashRadius: 20,
            padding: EdgeInsets.zero,
          );
        }

        return UnreadInboxBell(
          userId: user.uid,
          builder: (context, badgeCount) => IconButton(
            tooltip: 'Messages',
            onPressed: () {
              Navigator.of(context).pushNamed(buildMessagesRoute());
            },
            icon: PrestoNotificationBellBase(
              badgeCount: badgeCount,
              showBackground: false,
              iconColor: Colors.white,
            ),
            splashRadius: 20,
            padding: EdgeInsets.zero,
          ),
        );
      },
    );
  }

  bool get _hasActiveClientFilters {
    final selectedCategory =
        (_filterCategory != null && _filterCategory!.isNotEmpty)
            ? _filterCategory
            : ((_selectedCategory != null &&
                    _selectedCategory != 'Toutes catégories')
                ? _selectedCategory
                : null);
    final hasCity = _filterCityName?.trim().isNotEmpty ?? false;
    final hasSearch = _activeSearchQuery?.trim().isNotEmpty ?? false;
    final hasSubcategory =
        _selectedSubCategory != null && _selectedSubCategory!.isNotEmpty;
    final hasDept =
        (_filterDepartmentCode != null && _filterDepartmentCode!.isNotEmpty) ||
            (_filterRegionCode != null && _filterRegionCode!.isNotEmpty) ||
            (_selectedRegionCode != null && _selectedRegionCode!.isNotEmpty);
    final min = _parseBudgetBound(_budgetMinCtrl.text);
    final max = _parseBudgetBound(_budgetMaxCtrl.text);
    final hasBudgetRange = _advancedFilters &&
        (min != null || max != null) &&
        _budgetRangeWarning == null;

    return (selectedCategory != null && selectedCategory.isNotEmpty) ||
        hasCity ||
        hasSearch ||
        hasSubcategory ||
        hasDept ||
        hasBudgetRange;
  }

  bool _didApplyProfileDepartmentDefaultFilter = false;
  bool _didShowProfileDepartmentInfoPopup = false;

  Future<void> _applyProfileDepartmentFilterByDefault() async {
    if (_didApplyProfileDepartmentDefaultFilter) return;

    _didApplyProfileDepartmentDefaultFilter = true;

    final hasExplicitEntryFilter =
        widget.categoryFilter?.trim().isNotEmpty == true ||
            widget.searchQuery?.trim().isNotEmpty == true;

    final hasManualLocationFilter =
        (_filterDepartmentCode != null && _filterDepartmentCode!.isNotEmpty) ||
            (_filterCityName != null && _filterCityName!.isNotEmpty) ||
            _filterPostalCodeController.text.trim().isNotEmpty ||
            _postalCodeController.text.trim().isNotEmpty;

    if (hasExplicitEntryFilter || hasManualLocationFilter) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snapshot.data();

      if (data == null) return;

      final departmentCode = ProfileDepartmentResolver.resolveDepartmentCode(
        departmentCode: data['departmentCode'] ?? data['department_code'],
        departmentLabel:
            data['department'] ?? data['departement'] ?? data['departmentName'],
        city: data['city'] ?? data['ville'],
        postalCode: data['postalCode'] ??
            data['postal_code'] ??
            data['zipCode'] ??
            data['zip'],
      );

      if (departmentCode == null || departmentCode.isEmpty) return;

      final regionCode = _deptToRegion[departmentCode];

      if (!mounted) return;

      setState(() {
        _filterDepartmentCode = departmentCode;

        if (regionCode != null && regionCode.isNotEmpty) {
          _filterRegionCode = regionCode;

          _selectedRegionCode = regionCode;
        }

        // Le filtre profil est appliqué, mais le panneau reste replié.
        _showFilters = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _showProfileDepartmentInfoPopupOnce(
            departmentCode: departmentCode,
            regionCode: regionCode,
          ),
        );
      });
    } catch (error) {
      debugPrint('[ConsultOffers] Filtre département profil ignoré: $error');
    }
  }

  Future<void> _showProfileDepartmentInfoPopupOnce({
    required String departmentCode,
    String? regionCode,
  }) async {
    if (_didShowProfileDepartmentInfoPopup || !mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _didShowProfileDepartmentInfoPopup = true;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      final snapshot = await userRef.get();
      final data = snapshot.data();
      if (data?['consultProfileFilterInfoDismissed'] == true) return;
    } catch (error) {
      debugPrint('[ConsultOffers] Lecture popup filtre profil ignorée: $error');
    }

    if (!mounted) return;

    final departmentLabel = ProfileDepartmentResolver.departmentDisplayName(
      departmentCode,
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Offres synchronisées',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            'À l’ouverture de cette page, les offres sont automatiquement '
            'synchronisées avec la région et le département enregistrés dans '
            'votre profil : $departmentLabel.\\n\\n'
            'Le panneau de filtres reste replié. Vous pouvez l’ouvrir à tout '
            'moment pour modifier votre recherche.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6600),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('J’ai compris'),
            ),
          ],
        );
      },
    );

    try {
      await userRef.set({
        'consultProfileFilterInfoDismissed': true,
        'consultProfileFilterInfoDismissedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('[ConsultOffers] Sauvegarde fermeture popup ignorée: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        precacheImage(const AssetImage('assets/images/jobfait.webp'), context);
      }
    });

    // ✅ Analytics: page view
    _logPageView();

    _scrollController.addListener(() {
      widget.onScroll?.call(_scrollController.offset);
      _maybeLoadMore();
      if (_showFilters &&
          _scrollController.position.userScrollDirection !=
              ScrollDirection.idle) {
        setState(() => _showFilters = false);
      }
    });

    final initialCategoryFilter = widget.categoryFilter?.trim();
    if (initialCategoryFilter != null && initialCategoryFilter.isNotEmpty) {
      _selectedCategory = initialCategoryFilter;
      final matched = _matchKnownCategory(initialCategoryFilter);
      if (matched != null) {
        _filterCategory = matched;
        _selectedCategory = matched;
      }
    } else {
      _selectedCategory = 'Toutes catégories';
    }

    _selectedRegionCode = null; // Pas de région sélectionnée par défaut

    // ✅ Si un searchQuery est fourni (barre de recherche Accueil),
    // on essaie d'abord de le refléter dans le filtre Catégorie.
    // Si aucune catégorie ne correspond, on garde le comportement "mot-clé".
    final initialQuery = widget.searchQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      final matchedCategory = _matchKnownCategory(initialQuery);
      if (matchedCategory != null) {
        _filterCategory = matchedCategory;
        _selectedCategory = matchedCategory;
        _activeSearchQuery = null;
        _keywordCtrl.clear();
      } else {
        _activeSearchQuery = initialQuery;
        _keywordCtrl.text = initialQuery;
      }

      // ✅ Analytics: recherche (même si ça match une catégorie)
      _logSearch(initialQuery);
    }

    _headerTitle = _resolveConsultOffersTitle();

    // Quand le code postal change, on essaie de déduire la région
    _postalCodeController.addListener(_syncRegionWithPostalCode);

    // ✅ Précharger les données région/département
    _preloadRegionDeptData();
    unawaited(_applyProfileDepartmentFilterByDefault());

    // Synchroniser la ville sélectionnée (si déjà connue) dans le champ visible
    _filterCityController.addListener(_syncLocationFieldFromFilter);
    _syncLocationFieldFromFilter();

    final initialStreamKey = _buildOffersStreamKey();
    unawaited(_primeOffersWarmCache(initialStreamKey));
    if (!_hasActiveClientFilters) {
      unawaited(_refreshPublishedOffersCount(force: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshOffers());
    }
  }

  Future<void> _refreshPublishedOffersCount({bool force = false}) async {
    if (!force && _hasActiveClientFilters) {
      return;
    }
    if (_isLoadingPublishedCount) {
      return;
    }
    if (!force && _totalPublishedCount != null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingPublishedCount = true;
      });
    } else {
      _isLoadingPublishedCount = true;
    }

    try {
      final aggregate = await FirebaseFirestore.instance
          .collection(kListingsCollection)
          .where('status', isEqualTo: 'active')
          .where('visibility', isEqualTo: 'public')
          .count()
          .get();

      if (!mounted) {
        _totalPublishedCount = aggregate.count;
        return;
      }

      setState(() {
        _totalPublishedCount = aggregate.count;
      });
    } catch (error) {
      debugPrint('[ConsultOffers] published count failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPublishedCount = false;
        });
      } else {
        _isLoadingPublishedCount = false;
      }
    }
  }

  void _refreshPublishedOffersCountIfNeeded() {
    if (_hasActiveClientFilters) {
      return;
    }
    unawaited(_refreshPublishedOffersCount(force: true));
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final now = DateTime.now();
    final shouldRequest = _paginationPolicy.shouldRequestNextPage(
      hasActiveClientFilters: _hasActiveClientFilters,
      isLoading: _isLoadingNextPage,
      hasMore: _hasMorePages,
      hasCursor: _lastDoc != null,
      loadedCount: _paginationDocs.length,
      pixels: position.pixels,
      maxScrollExtent: position.maxScrollExtent,
      now: now,
      lastRequestAt: _lastPaginationRequestAt,
    );
    if (!shouldRequest) return;

    _lastPaginationRequestAt = now;
    unawaited(_loadNextPage());
  }

  Future<void> _loadNextPage() async {
    if (_hasActiveClientFilters || _isLoadingNextPage || !_hasMorePages) return;
    final cursor = _lastDoc;
    final key = _paginationKey;
    if (cursor == null || key == null) return;

    final requestedLimit = _paginationPolicy.nextPageLimit(
      _paginationDocs.length,
    );
    if (requestedLimit <= 0) return;
    setState(() => _isLoadingNextPage = true);

    try {
      final nextDocs = await loadMergedPublicOfferQueryVariants(
        queries: _buildCurrentListingsQueries(
          limit: requestedLimit,
          startAfterDocument: cursor,
        ),
        source: 'consult_listings_next_page',
      );
      if (!mounted || _paginationKey != key) return;

      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
        for (final doc in _paginationDocs) doc.id: doc,
      };
      for (final doc in nextDocs) {
        byId.putIfAbsent(doc.id, () => doc);
      }

      setState(() {
        _paginationDocs = byId.values.toList(growable: false);
        if (nextDocs.isNotEmpty) _lastDoc = nextDocs.last;
        _hasMorePages = _paginationPolicy.hasMoreAfterPage(
          receivedCount: nextDocs.length,
          requestedLimit: requestedLimit,
          totalLoadedCount: _paginationDocs.length,
        );
        _lastSnapshotRawCount = _paginationDocs.length;
        _lastResultCount = _buildDisplayedOfferDocs(_paginationDocs).length;
        _offersWarmCache[key] = _paginationDocs;
        _displayedDocsCacheSignature = null;
        _displayedDocsCache = null;
        _renderItemsCacheSignature = null;
        _renderItemsCache = null;
      });
    } catch (error) {
      _logConsultOffersFetch(
        'next-page-error',
        details: <String, Object?>{
          'message': error.toString(),
          'loadedCount': _paginationDocs.length,
        },
      );
    } finally {
      if (mounted) setState(() => _isLoadingNextPage = false);
    }
  }

  /// ✅ Précharge les données région/département au démarrage
  Future<void> _preloadRegionDeptData() async {
    try {
      // Simplement accéder à la map pour la forcer en mémoire
      debugPrint(
        '[ConsultOffers] Préchargement région/département (${_deptToRegion.length} entrées)',
      );
    } catch (e) {
      debugPrint('[ConsultOffers] Erreur préchargement: $e');
    }
  }

  /// ✅ Cache les résultats Firestore pour éviter les re-queries inutiles (template pour utilisation future)
  List<DocumentSnapshot<Map<String, dynamic>>> _getCachedOrFreshResults(
    String querySignature,
    List<DocumentSnapshot<Map<String, dynamic>>> freshResults,
  ) {
    // Si la signature a changé, invalider le cache
    if (_lastCachedQuerySignature != querySignature) {
      _queryResultsCache = null;
      _lastCachedQuerySignature = querySignature;
      _cacheInvalidationTimer?.cancel();

      // Cache expire après 5 minutes
      _cacheInvalidationTimer = Timer(const Duration(minutes: 5), () {
        _queryResultsCache = null;
        _lastCachedQuerySignature = null;
      });
    }

    // Mettre en cache les résultats
    _queryResultsCache = {'results': freshResults};
    return freshResults;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _filterDebounce.dispose();
    _cacheInvalidationTimer?.cancel(); // ✅ Nettoyer le timer de cache
    _locationController.dispose();
    _postalCodeController.dispose();
    _scrollController.dispose();
    _filterCityController.dispose();
    _filterPostalCodeController.dispose();
    _filterCityFocusNode.dispose();
    _filterCityDebounce?.cancel();
    _keywordCtrl.dispose();
    _cityCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    _jobDoneOverlayTimer?.cancel();
    super.dispose();
  }

  /// Clé unique qui représente l'état courant de la requête.
  /// Le stream n'est recréé que quand cette clé change.
  String _buildOffersStreamKey() {
    return [
      _filterCategory ?? '',
      _selectedCategory ?? '',
      _filterRegionCode ?? '',
      _selectedRegionCode ?? '',
      _filterDepartmentCode ?? '',
      _filterCityName ?? '',
      _filterPostalCodeController.text,
      _postalCodeController.text,
      _selectedSubCategory ?? '',
      _activeSearchQuery ?? '',
      _pageLimit.toString(),
      if (_advancedFilters) ...[_budgetMinCtrl.text, _budgetMaxCtrl.text],
    ].join('|');
  }

  List<Query<Map<String, dynamic>>> _buildCurrentListingsQueries({
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) {
    return buildMarketplaceListingsBrowseQueries(
      limit: limit,
      latestFirst: true,
      categoryId: _effectiveListingsCategoryId(),
      cityId: _effectiveListingsCityId(),
      startAfterDocument: startAfterDocument,
    );
  }

  Future<void> _primeOffersWarmCache(String key) async {
    if (_offersWarmCache.containsKey(key) ||
        _offersWarmLoadsInFlight.contains(key)) {
      return;
    }

    _offersWarmLoadsInFlight.add(key);
    final limit = _hasActiveClientFilters
        ? _paginationPolicy.maxLimit
        : _paginationPolicy.initialLimit;

    try {
      final loads = <Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>[
        loadMergedPublicOfferQueryVariants(
          queries: _buildCurrentListingsQueries(limit: limit),
          source: 'consult_listings_warm',
        ),
      ];

      if (kEnableLegacyPublicOffersBackfill) {
        loads.add(
          loadMergedPublicOfferQueryVariants(
            queries: buildLatestPublicOffersQueryVariants(limit: limit),
            source: 'consult_legacy_warm',
          ),
        );
      }

      final results = await Future.wait(loads);
      final listings = results[0];
      final legacy = results.length > 1
          ? results[1]
          : listings.isEmpty
              ? await loadLegacyPublicOffersOnDemand(
                  limit: limit,
                  source: 'consult_legacy_warm_fallback',
                )
              : const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final merged = mergeOfferDocsById(listings, legacy);
      final displayedCount = _buildDisplayedOfferDocs(merged).length;

      _offersWarmCache[key] = merged;

      if (mounted && _buildOffersStreamKey() == key) {
        setState(() {
          _lastResultCount = displayedCount;
        });
      }
    } catch (_) {
      // Le stream live reste la source de vérité ; l'amorçage est opportuniste.
    } finally {
      _offersWarmLoadsInFlight.remove(key);
    }
  }

  Future<void> _refreshOffers() async {
    final key = _buildOffersStreamKey();

    _cachedOffersStream = null;
    _cachedOffersStreamKey = null;
    _offersWarmCache.remove(key);
    _offersWarmLoadsInFlight.remove(key);
    _paginationDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    _paginationKey = null;
    _lastDoc = null;
    _hasMorePages = true;

    try {
      await _primeOffersWarmCache(key);
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Retourne le stream mis en cache ou en crée un nouveau si les paramètres
  /// de la requête ont changé depuis le dernier build.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getOffersStream() {
    final key = _buildOffersStreamKey();
    if (_cachedOffersStream == null || _cachedOffersStreamKey != key) {
      if (!_hasActiveClientFilters && _paginationKey != key) {
        _paginationKey = key;
        _paginationDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        _lastDoc = null;
        _hasMorePages = true;
      }
      // Le stream principal est l’unique chargement initial. Le warm load
      // parallèle doublait les lectures Firestore pour le même écran.
      _cachedOffersStream = _watchCombinedOffers().map((docs) {
        if (!_hasActiveClientFilters && _paginationKey == key) {
          _paginationDocs =
              List<QueryDocumentSnapshot<Map<String, dynamic>>>.of(
            docs,
            growable: false,
          );
          _lastDoc = docs.isEmpty ? null : docs.last;
          _hasMorePages = docs.length >= _paginationPolicy.initialLimit &&
              docs.length < _paginationPolicy.maxLimit;
        }
        final displayedCount = _buildDisplayedOfferDocs(docs).length;
        _offersWarmCache[key] = docs;
        if (mounted &&
            _cachedOffersStreamKey == key &&
            _lastResultCount != displayedCount) {
          setState(() {
            _lastResultCount = displayedCount;
          });
        }
        PrestoMonitoring.I.trackOffersSnapshot(displayedCount);
        return docs;
      });
      _cachedOffersStreamKey = key;
    }
    return _cachedOffersStream!;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _watchCombinedOffers() {
    // ✅ Fetch-once (get) au lieu d'un snapshots() permanent: la consultation
    // publique n'a pas besoin d'un live stream. La stream émet un unique
    // résultat fusionné, puis se termine. Un changement de filtre/pagination
    // change la clé (_buildOffersStreamKey), ce qui recrée un nouveau stream
    // et déclenche un nouveau fetch. Le refresh manuel reste assuré par le
    // bouton "Actualiser" qui invalide le cache du stream.
    final limit = _hasActiveClientFilters
        ? _paginationPolicy.maxLimit
        : _paginationPolicy.initialLimit;
    final categoryId = _effectiveListingsCategoryId();
    final cityId = _effectiveListingsCityId();

    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> loadOnce() async {
      _logConsultOffersFetch(
        'start',
        details: <String, Object?>{
          'limit': limit,
          'categoryId': categoryId ?? '',
          'cityId': cityId ?? '',
          'hasActiveClientFilters': _hasActiveClientFilters,
        },
      );
      try {
        final loads =
            <Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>[
          loadMergedPublicOfferQueryVariants(
            queries: buildMarketplaceListingsBrowseQueries(
              limit: limit,
              latestFirst: true,
              categoryId: categoryId,
              cityId: cityId,
            ),
            source: 'consult_listings_fetch',
          ),
        ];
        if (kEnableLegacyPublicOffersBackfill) {
          loads.add(
            loadMergedPublicOfferQueryVariants(
              queries: buildLatestPublicOffersQueryVariants(limit: limit),
              source: 'consult_legacy_fetch',
            ),
          );
        }
        final results = await Future.wait(loads);
        final listings = results[0];
        final legacy = results.length > 1
            ? results[1]
            : listings.isEmpty
                ? await loadLegacyPublicOffersOnDemand(
                    limit: limit,
                    source: 'consult_legacy_fetch_fallback',
                  )
                : const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final merged = mergeOfferDocsById(listings, legacy);
        _logConsultOffersFetch(
          'success',
          details: <String, Object?>{
            'listingsCount': listings.length,
            'legacyCount': legacy.length,
            'mergedCount': merged.length,
          },
        );
        return merged;
      } catch (error) {
        _logConsultOffersFetch(
          'error',
          details: <String, Object?>{
            'errorType': error.runtimeType.toString(),
            'message': error.toString(),
          },
        );
        rethrow;
      }
    }

    return loadOnce().asStream();
  }

  bool _offerIsActive(Map<String, dynamic> data) {
    return isVisibleInPublicBrowse(data);
  }

  void _scheduleJobDoneOverlayRefresh(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    DateTime? earliestExpiry;

    for (final doc in docs) {
      final expiry = offerJobDoneVisibleUntil(doc.data());
      if (expiry == null || !expiry.isAfter(DateTime.now())) {
        continue;
      }
      if (!isOfferJobDoneOverlayVisible(doc.data())) {
        continue;
      }
      if (earliestExpiry == null || expiry.isBefore(earliestExpiry)) {
        earliestExpiry = expiry;
      }
    }

    if (earliestExpiry == null) {
      _jobDoneOverlayTimer?.cancel();
      _jobDoneOverlayTimer = null;
      _nextJobDoneOverlayRefreshAt = null;
      return;
    }

    if (_nextJobDoneOverlayRefreshAt == earliestExpiry &&
        _jobDoneOverlayTimer != null) {
      return;
    }

    _jobDoneOverlayTimer?.cancel();
    _nextJobDoneOverlayRefreshAt = earliestExpiry;

    final delay = earliestExpiry.difference(DateTime.now());
    _jobDoneOverlayTimer = Timer(
      delay.isNegative ? Duration.zero : delay + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        setState(() {
          _nextJobDoneOverlayRefreshAt = null;
        });
      },
    );
  }

  String _offerCategoryLabel(Map<String, dynamic> data) {
    final raw = (data['category'] ?? '').toString().trim();
    return _matchKnownCategory(raw) ?? raw;
  }

  String _offerCityLabel(Map<String, dynamic> data) {
    return ((data['city'] ?? data['location']) ?? '').toString().trim();
  }

  String _offerPostalCode(Map<String, dynamic> data) {
    return ((data['postalCode'] ?? data['cp']) ?? '').toString().trim();
  }

  String? _effectiveListingsCategoryId() {
    final categoryLabel =
        (_filterCategory != null && _filterCategory!.isNotEmpty)
            ? _filterCategory
            : ((_selectedCategory != null &&
                    _selectedCategory != 'Toutes catégories')
                ? _selectedCategory
                : null);
    return _makeCategoryId(categoryLabel);
  }

  String? _effectiveListingsCityId() {
    final loc = _locationController.text.trim();
    final cp = _postalCodeController.text.trim();
    final filterCity = _filterCityName?.trim();

    final cityName =
        (filterCity != null && filterCity.isNotEmpty) ? filterCity : loc;
    final cpForCity = (filterCity != null &&
            filterCity.isNotEmpty &&
            _filterPostalCodeController.text.trim().isNotEmpty)
        ? _filterPostalCodeController.text.trim()
        : cp;

    return _makeCityId(cityName: cityName, postalCode: cpForCity);
  }

  String? _offerDepartmentCode(Map<String, dynamic> data) {
    final rawDept = (data['dept'] ?? '').toString().trim();
    if (rawDept.isNotEmpty) return rawDept;
    return departmentFromPostalCode(_offerPostalCode(data));
  }

  String? _offerRegionCode(Map<String, dynamic> data) {
    final dept = _offerDepartmentCode(data);
    if (dept == null || dept.isEmpty) return null;
    return _deptToRegion[dept];
  }

  double? _offerBudgetValue(Map<String, dynamic> data) {
    return budgetValueFromDynamic(
      data['budgetValue'] ?? data['budget'] ?? data['price'],
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _buildDisplayedOfferDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rawDocs,
  ) {
    final docs = rawDocs
        .where((d) => _matchesOfferFilters(d.data()))
        .toList(growable: false)
      ..sort((a, b) {
        final aTs = a.data()['createdAt'];
        final bTs = b.data()['createdAt'];
        final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
        final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
        return bMs.compareTo(aMs);
      });
    return docs;
  }

  String _makeRawDocsSignature(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rawDocs,
  ) {
    final buffer = StringBuffer();
    for (final doc in rawDocs) {
      final createdAt = doc.data()['createdAt'];
      final createdAtMs = createdAt is Timestamp
          ? createdAt.millisecondsSinceEpoch
          : (createdAt is int ? createdAt : 0);
      buffer
        ..write(doc.id)
        ..write(':')
        ..write(createdAtMs)
        ..write(';');
    }
    return buffer.toString();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _getDisplayedOfferDocsMemo(
    String streamKey,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rawDocs,
  ) {
    final signature = '$streamKey|${_makeRawDocsSignature(rawDocs)}';
    if (_displayedDocsCacheSignature == signature &&
        _displayedDocsCache != null) {
      return _displayedDocsCache!;
    }

    final next = _buildDisplayedOfferDocs(rawDocs);
    _displayedDocsCacheSignature = signature;
    _displayedDocsCache = next;
    return next;
  }

  String _makeDisplayedDocsSignature(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final buffer = StringBuffer();
    for (final doc in docs) {
      final data = doc.data();
      final createdAt = data['createdAt'];
      final createdAtMs = createdAt is Timestamp
          ? createdAt.millisecondsSinceEpoch
          : (createdAt is int ? createdAt : 0);
      buffer
        ..write(doc.id)
        ..write(':')
        ..write(createdAtMs)
        ..write(':')
        ..write(isOfferJobDoneOverlayVisible(data) ? '1' : '0')
        ..write(';');
    }
    return buffer.toString();
  }

  List<_ConsultOfferListItem> _getOfferListItemsMemo(
    String streamKey,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final signature = '$streamKey|${_makeDisplayedDocsSignature(docs)}';
    if (_renderItemsCacheSignature == signature && _renderItemsCache != null) {
      return _renderItemsCache!;
    }

    final items = _buildOfferListItems(docs);
    _renderItemsCacheSignature = signature;
    _renderItemsCache = items;
    return items;
  }

  List<_ConsultOfferListItem> _buildOfferListItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    const adsEvery = 8;
    final items = <_ConsultOfferListItem>[];

    for (var index = 0; index < docs.length; index++) {
      if (index > 0 && index % adsEvery == 0) {
        items.add(const _ConsultOfferListItem.ad());
      }

      final doc = docs[index];
      final data = doc.data();
      final offerId = doc.id;
      final title = (data['title'] ?? 'Sans titre').toString();
      final city =
          ((data['city'] ?? data['location']) ?? 'Lieu non précisé').toString();
      final postalCode =
          ((data['postalCode'] ?? data['cp']) ?? '').toString().trim();
      final category =
          (data['category'] ?? 'Catégorie non précisée').toString();
      final budgetRaw = data['budget'] ?? data['price'];
      final budget = budgetRaw is num
          ? budgetRaw.round()
          : int.tryParse(budgetRaw?.toString() ?? '') ?? 0;
      final publishedAge = _ageLabelFromCreatedAt(data['createdAt']);
      final publishedText = publishedAge.isEmpty
          ? 'Publication récente'
          : 'Publié il y a $publishedAge';
      final isUrgent = data['isUrgent'] == true || data['urgent'] == true;
      final showJobDoneOverlay = isOfferJobDoneOverlayVisible(data);
      final imageUrl = _primaryBrowseOfferImageUrl(data);
      final missionDelayLabel = _extractMissionDelayLabel(data);
      final cleanTitle = _sanitizeOfferTitle(
        rawTitle: title,
        city: city,
        postalCode: postalCode,
      );

      items.add(
        _ConsultOfferListItem.offer(
          offerId: offerId,
          title: title,
          data: data,
          tileData: _OfferBrowseTileData(
            imageUrl: imageUrl,
            title: cleanTitle,
            subtitle: [
              city,
              if (postalCode.isNotEmpty) postalCode,
              category,
            ].join(' / '),
            publishedText: publishedText,
            price: budget,
            hidePrice: _shouldHideConsultTilePrice(data),
            missionDelayLabel: missionDelayLabel,
            isUrgent: isUrgent && !showJobDoneOverlay,
            icon: _categoryIcon(category),
            showJobDoneOverlay: showJobDoneOverlay,
          ),
        ),
      );
    }

    return items;
  }

  bool _matchesOfferFilters(Map<String, dynamic> data) {
    if (!_offerIsActive(data)) return false;

    final effectiveCategoryId = _effectiveListingsCategoryId();
    if (effectiveCategoryId != null && effectiveCategoryId.isNotEmpty) {
      final rawCategoryId = (data['categoryId'] ?? '').toString().trim();
      final derivedCategoryId = _makeCategoryId(_offerCategoryLabel(data));
      if (rawCategoryId != effectiveCategoryId &&
          derivedCategoryId != effectiveCategoryId) {
        return false;
      }
    }

    final effectiveCityId = _effectiveListingsCityId();
    if (effectiveCityId != null && effectiveCityId.isNotEmpty) {
      final rawCityId = (data['cityId'] ?? '').toString().trim();
      final derivedCityId = _makeCityId(
        cityName: _offerCityLabel(data),
        postalCode: _offerPostalCode(data),
      );
      if (rawCityId != effectiveCityId && derivedCityId != effectiveCityId) {
        return false;
      }
    }

    if (_selectedSubCategory != null && _selectedSubCategory!.isNotEmpty) {
      final offerSubCategory =
          ((data['subCategory'] ?? data['subcategory']) ?? '')
              .toString()
              .trim();
      if (offerSubCategory != _selectedSubCategory) {
        return false;
      }
    }

    if (_filterDepartmentCode != null && _filterDepartmentCode!.isNotEmpty) {
      if (_offerDepartmentCode(data) != _filterDepartmentCode) {
        return false;
      }
    }

    final regionFilter =
        (_filterRegionCode != null && _filterRegionCode!.isNotEmpty)
            ? _filterRegionCode
            : _selectedRegionCode;
    if (regionFilter != null && regionFilter.isNotEmpty) {
      if (_offerRegionCode(data) != regionFilter) {
        return false;
      }
    }

    final min = _parseBudgetBound(_budgetMinCtrl.text);
    final max = _parseBudgetBound(_budgetMaxCtrl.text);
    if (_advancedFilters &&
        (min != null || max != null) &&
        _budgetRangeWarning == null) {
      final offerBudget = _offerBudgetValue(data);
      if (offerBudget == null) return false;
      if (min != null && offerBudget < min) return false;
      if (max != null && offerBudget > max) return false;
    }

    if (_activeSearchQuery != null && _activeSearchQuery!.trim().isNotEmpty) {
      final q = _normalizeText(_activeSearchQuery!);
      final queryTokens = q.split(' ').where((t) => t.isNotEmpty).toList();
      final title = _normalizeText((data['title'] ?? '').toString());
      final desc = _normalizeText((data['description'] ?? '').toString());
      final combined = '$title $desc';
      if (!queryTokens.every((token) => combined.contains(token))) {
        return false;
      }
    }

    return true;
  }

  void _applyFiltersOrSearch() {
    // Annule le debounce en cours pour éviter les conflits
    _filterDebounce._t?.cancel();

    final min = _parseBudgetBound(_budgetMinCtrl.text);
    final max = _parseBudgetBound(_budgetMaxCtrl.text);

    // ✅ Log l'utilisation des filtres
    if (_filterCategory != null && _filterCategory!.isNotEmpty) {
      _logFilterUsage('category', _filterCategory!);
    }
    if (_filterRegionCode != null && _filterRegionCode!.isNotEmpty) {
      _logFilterUsage('region', _filterRegionCode!);
    }
    if (_filterDepartmentCode != null && _filterDepartmentCode!.isNotEmpty) {
      _logFilterUsage('department', _filterDepartmentCode!);
    }
    if (_filterCityName != null && _filterCityName!.isNotEmpty) {
      _logFilterUsage('city', _filterCityName!);
    }

    // Compter les filtres égalité actifs (pour éviter explosion d’index si range)
    final bool eqCat =
        (_filterCategory != null && _filterCategory!.isNotEmpty) ||
            ((_selectedCategory ?? '').isNotEmpty &&
                _selectedCategory != 'Toutes catégories');
    final bool eqDept =
        (_filterDepartmentCode != null && _filterDepartmentCode!.isNotEmpty) ||
            ((_filterRegionCode ?? '').isNotEmpty) ||
            ((_selectedRegionCode ?? '').isNotEmpty);
    final bool eqLoc =
        (_filterCityName != null && _filterCityName!.trim().isNotEmpty) ||
            _locationController.text.trim().isNotEmpty;
    final bool eqCp = _postalCodeController.text.trim().isNotEmpty;
    final bool eqSub =
        (_selectedSubCategory != null && _selectedSubCategory!.isNotEmpty);

    final int eqCount = <bool>[
      eqCat,
      eqDept,
      eqLoc,
      eqCp,
      eqSub,
    ].where((b) => b).length;

    // ✅ Règle: range budget uniquement en “avancé” + idéalement peu de filtres == (sinon index explosion)
    String? budgetWarning;
    if (_advancedFilters && (min != null || max != null) && eqCount > 1) {
      budgetWarning = "Budget (avancé) désactivé : trop de filtres combinés. "
          "Garde 0–1 filtre (ex: seulement Ville OU seulement Catégorie) pour éviter l’explosion d’index.";
    }

    // ✅ Log les filtres appliqués
    _logFiltersApplied(
      category: _filterCategory,
      region: _filterRegionCode,
      department: _filterDepartmentCode,
      city: _filterCityName,
      searchQuery: _activeSearchQuery,
      resultCount: 0, // sera mis à jour après le StreamBuilder
    );

    setState(() {
      _budgetRangeWarning = budgetWarning;
      _activeSearchQuery =
          _keywordCtrl.text.trim().isEmpty ? null : _keywordCtrl.text.trim();
      _lastDoc = null; // Reset pagination
      _pageLimit = _paginationPolicy.initialLimit;
      _lastPaginationRequestAt = null;
      _showFilters = false;
      _headerTitle = _resolveConsultOffersTitle();
    });

    _refreshPublishedOffersCountIfNeeded();
  }

  void _trackManualFilterCriterion(String key, {required bool isActive}) {
    if (isActive) {
      _manualAutoApplyCriteria.add(key);
    } else {
      _manualAutoApplyCriteria.remove(key);
    }
  }

  void _pruneManualAutoApplyCriteria() {
    if ((_filterCategory ?? '').trim().isEmpty) {
      _manualAutoApplyCriteria.remove('category');
    }
    if ((_filterRegionCode ?? '').trim().isEmpty) {
      _manualAutoApplyCriteria.remove('region');
    }
    if ((_filterDepartmentCode ?? '').trim().isEmpty) {
      _manualAutoApplyCriteria.remove('department');
    }
    if ((_filterCityName ?? '').trim().isEmpty) {
      _manualAutoApplyCriteria.remove('city');
    }
  }

  void _onAnyFilterChanged() {
    if (_manualAutoApplyCriteria.length < _autoApplyFiltersThreshold) {
      return;
    }

    // ✅ Auto-apply avec debounce à partir de 3 critères sélectionnés
    _filterDebounce.run(() {
      _applyFiltersOrSearch();
    });
  }

  String _deptFromPostal(String cp) {
    final s = cp.trim();
    if (s.length < 2) return s;
    // DOM: 971/972/973/974/976 (postal commence par 97x) + 98x
    if (s.startsWith('97') || s.startsWith('98')) {
      return s.length >= 3 ? s.substring(0, 3) : s;
    }
    // Métropole
    return s.substring(0, 2);
  }

  void _resetFilters() {
    // 1) reset valeurs filtres
    setState(() {
      _selectedCategory = 'Toutes catégories';
      _selectedRegionCode = null;
      _selectedSubCategory = null;
      _filterCategory = null;
      _filterRegionCode = null;
      _filterDepartmentCode = null;
      _filterCityName = null;
      _filterCitySuggestions = [];
      _filterCityHighlightedIndex = -1;
      _activeSearchQuery = null;
      _budgetRangeWarning = null;
      _manualAutoApplyCriteria.clear();
      _filterPanelKey++; // Force la reconstruction du panneau
      _pageLimit = _paginationPolicy.initialLimit;
      _lastPaginationRequestAt = null;
      _showFilters = false;
      _headerTitle = _resolveConsultOffersTitle();
    });

    // 2) reset champs texte
    _keywordCtrl.clear();
    _cityCtrl.clear();
    _locationController.clear();
    _postalCodeController.clear();
    _filterCityController.clear();
    _filterPostalCodeController.clear();

    // Assurer que le champ visible est remis à vide
    _syncLocationFieldFromFilter();

    // 3) ferme le clavier si besoin
    FocusScope.of(context).unfocus();

    // 4) ✅ Pas de scroll forcé: on conserve la position courante
    _refreshPublishedOffersCountIfNeeded();
  }

  void _mutateActiveFilters(VoidCallback mutation) {
    setState(() {
      mutation();
      _pruneManualAutoApplyCriteria();
      _budgetRangeWarning = null;
      _lastDoc = null;
      _pageLimit = _paginationPolicy.initialLimit;
      _lastPaginationRequestAt = null;
      _headerTitle = _resolveConsultOffersTitle();
    });

    _refreshPublishedOffersCountIfNeeded();
  }

  Widget _buildRemovableFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close_rounded, size: 18),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1F4E95),
      ),
      backgroundColor: const Color(0xFFF4F8FF),
      side: const BorderSide(color: Color(0xFFBED5F8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  List<Widget> _buildActiveFilterChipItems() {
    final chips = <Widget>[];

    final effectiveCategory = (_filterCategory?.trim().isNotEmpty ?? false)
        ? _filterCategory!.trim()
        : (((_selectedCategory?.trim().isNotEmpty ?? false) &&
                _selectedCategory != 'Toutes catégories')
            ? _selectedCategory!.trim()
            : null);
    if (effectiveCategory != null) {
      chips.add(
        _buildRemovableFilterChip(
          label: 'Catégorie: $effectiveCategory',
          onDeleted: () {
            _mutateActiveFilters(() {
              _filterCategory = null;
              _selectedCategory = 'Toutes catégories';
            });
          },
        ),
      );
    }

    final effectiveRegionCode = (_filterRegionCode?.trim().isNotEmpty ?? false)
        ? _filterRegionCode!.trim()
        : ((_selectedRegionCode?.trim().isNotEmpty ?? false)
            ? _selectedRegionCode!.trim()
            : null);
    if (effectiveRegionCode != null) {
      final regionLabel = kRegions[effectiveRegionCode] ?? effectiveRegionCode;
      chips.add(
        _buildRemovableFilterChip(
          label: 'Région: $regionLabel',
          onDeleted: () {
            _mutateActiveFilters(() {
              _filterRegionCode = null;
              _selectedRegionCode = null;
            });
          },
        ),
      );
    }

    if (_filterDepartmentCode?.trim().isNotEmpty ?? false) {
      final departmentCode = _filterDepartmentCode!.trim();
      final departmentLabel = kDepartments[departmentCode] ?? departmentCode;
      chips.add(
        _buildRemovableFilterChip(
          label: 'Département: $departmentLabel',
          onDeleted: () {
            _mutateActiveFilters(() {
              _filterDepartmentCode = null;
            });
          },
        ),
      );
    }

    if (_filterCityName?.trim().isNotEmpty ?? false) {
      final cityName = _filterCityName!.trim();
      chips.add(
        _buildRemovableFilterChip(
          label: 'Ville: $cityName',
          onDeleted: () {
            _mutateActiveFilters(() {
              _filterCityController.clear();
              _filterPostalCodeController.clear();
              _locationController.clear();
              _postalCodeController.clear();
              _filterCityName = null;
              _filterCitySuggestions = [];
              _filterCityHighlightedIndex = -1;
            });
          },
        ),
      );
    }

    if (_selectedSubCategory?.trim().isNotEmpty ?? false) {
      final subCategory = _selectedSubCategory!.trim();
      chips.add(
        _buildRemovableFilterChip(
          label: 'Sous-catégorie: $subCategory',
          onDeleted: () {
            _mutateActiveFilters(() {
              _selectedSubCategory = null;
            });
          },
        ),
      );
    }

    if (_activeSearchQuery?.trim().isNotEmpty ?? false) {
      final searchQuery = _activeSearchQuery!.trim();
      chips.add(
        _buildRemovableFilterChip(
          label: 'Recherche: $searchQuery',
          onDeleted: () {
            _mutateActiveFilters(() {
              _activeSearchQuery = null;
              _keywordCtrl.clear();
            });
          },
        ),
      );
    }

    final minBudget = _parseBudgetBound(_budgetMinCtrl.text);
    final maxBudget = _parseBudgetBound(_budgetMaxCtrl.text);
    if (_advancedFilters &&
        _budgetRangeWarning == null &&
        (minBudget != null || maxBudget != null)) {
      final minLabel = _budgetMinCtrl.text.trim();
      final maxLabel = _budgetMaxCtrl.text.trim();
      final budgetLabel = minBudget != null && maxBudget != null
          ? 'Budget: $minLabel - $maxLabel €'
          : minBudget != null
              ? 'Budget: dès $minLabel €'
              : 'Budget: jusqu’à $maxLabel €';
      chips.add(
        _buildRemovableFilterChip(
          label: budgetLabel,
          onDeleted: () {
            _mutateActiveFilters(() {
              _budgetMinCtrl.clear();
              _budgetMaxCtrl.clear();
            });
          },
        ),
      );
    }

    return chips;
  }

  String _resolveConsultOffersTitle() {
    final activeCategory = (_filterCategory?.trim().isNotEmpty ?? false)
        ? _filterCategory!.trim()
        : (((_selectedCategory?.trim().isNotEmpty ?? false) &&
                _selectedCategory != 'Toutes catégories')
            ? _selectedCategory!.trim()
            : null);

    if (activeCategory == null) {
      return 'Je consulte les offres';
    }

    return 'Offres : $activeCategory';
  }

  // Met à jour le champ "Ville" visible avec la valeur des filtres si présente
  void _syncLocationFieldFromFilter() {
    final val = _filterCityController.text.trim();
    if (val.isNotEmpty && _locationController.text != val) {
      _locationController.text = val;
    }
  }

  void _syncRegionWithPostalCode() {
    final cp = _postalCodeController.text.trim();
    if (cp.length < 3) return;

    final regionName = inferRegionFromPostalCode(cp);
    if (regionName != null) {
      // Chercher le code région correspondant
      String? regionCode;
      for (final entry in kRegions.entries) {
        if (entry.value == regionName) {
          regionCode = entry.key;
          break;
        }
      }
      if (regionCode != null && regionCode != _selectedRegionCode) {
        setState(() {
          _selectedRegionCode = regionCode;
        });
      }
    }
  }

  /// ✅ Tuile unique cliquable pour afficher/masquer les filtres
  Widget _buildActiveFilterChips() {
    final activeFilterChips = _buildActiveFilterChipItems();
    final activeFiltersCount = activeFilterChips.length;

    final bool hasActiveFilters = _hasActiveClientFilters;
    final int displayedResultCount = _lastResultCount;
    final int publishedCount = _totalPublishedCount ?? displayedResultCount;
    final String offersLabel;

    if (!hasActiveFilters &&
        _isLoadingPublishedCount &&
        _totalPublishedCount == null) {
      offersLabel = 'Chargement des annonces publiées...';
    } else if (hasActiveFilters) {
      offersLabel =
          '$displayedResultCount annonce${displayedResultCount > 1 ? 's' : ''} trouvée${displayedResultCount > 1 ? 's' : ''}';
    } else {
      offersLabel =
          '$publishedCount annonce${publishedCount > 1 ? 's' : ''} publiée${publishedCount > 1 ? 's' : ''}';
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setState(() => _showFilters = !_showFilters),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 10 : 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: _showFilters
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0x331A73E8),
                                    Color(0x141A73E8),
                                    Color(0x0DFFFFFF),
                                  ],
                                )
                              : null,
                          color: _showFilters ? null : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFE4D8DA)),
                          boxShadow: null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showFilters ? Icons.tune : Icons.tune_rounded,
                              size: 18,
                              color: const Color(0xFF585D7C),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Filtres',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF474D70),
                                letterSpacing: -0.1,
                              ),
                            ),
                            if (activeFiltersCount > 0) ...[
                              const SizedBox(width: 7),
                              Container(
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6600),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  activeFiltersCount > 9
                                      ? '9+'
                                      : '$activeFiltersCount',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 4),
                            Icon(
                              _showFilters
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: const Color(0xFF777B97),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isNarrow ? 10 : 14),
                  Expanded(
                    child: Text(
                      offersLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isNarrow ? 14 : 15,
                        fontWeight: FontWeight.w700,
                        color: _offersNavy,
                        letterSpacing: -0.15,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (activeFiltersCount > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...activeFilterChips,
                OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Réinitialiser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrestoBlue,
                    side: const BorderSide(color: Color(0xFFBED5F8)),
                    backgroundColor: const Color(0xFFF4F8FF),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTitle = _headerTitle;
    final currentOffersStreamKey = _buildOffersStreamKey();
    final initialOfferDocs = _offersWarmCache[currentOffersStreamKey];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: prestoOverlayStyleFor(kPrestoOrange),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: _offersBg,
          body: Column(
            children: [
              // Header orange qui s'étend derrière la status bar
              Container(
                width: double.infinity,
                color: kPrestoOrange,
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: kToolbarHeight,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: MediaQuery.withNoTextScaling(
                          child: Text(
                            baseTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: kPrestoAppBarTitleStyle.copyWith(
                              color: Colors.white,
                              fontFamily: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.fontFamily,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // ✅ Tuiles cliquables pour filtres actifs
              _buildActiveFilterChips(),
              _buildFilterPanel(),
              Expanded(
                child: StreamBuilder<
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                  stream: _getOffersStream(),
                  initialData: initialOfferDocs,
                  builder: (context, snapshot) {
                    // ✅ Ne plus afficher le loader si on a déjà des données
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            kPrestoOrange,
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      debugPrint('❌ [OFFERS] Error: ${snapshot.error}');
                      debugPrint('❌ [OFFERS] Stack: ${snapshot.stackTrace}');

                      final err = snapshot.error;
                      if (err != null) {
                        PrestoMonitoring.I.trackError(
                          'consult_offers.fetch',
                          err,
                        );
                      }

                      final friendly = err == null
                          ? 'Impossible de charger les annonces pour le moment.'
                          : friendlyPublicOffersReadErrorWithAppCheck(err);

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Erreur lors du chargement des offres",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                friendly,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              if (err != null)
                                buildPublicOffersDebugCardWithAppCheck(
                                  err,
                                  source: 'consult_combined_offers',
                                ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _refreshOffers,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Réessayer'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrestoOrange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final snapshotDocs = snapshot.data ??
                        const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final rawDocs = !_hasActiveClientFilters &&
                            _paginationKey == currentOffersStreamKey &&
                            _paginationDocs.isNotEmpty
                        ? _paginationDocs
                        : snapshotDocs;
                    _lastSnapshotRawCount = rawDocs.length;

                    final docs = _getDisplayedOfferDocsMemo(
                      currentOffersStreamKey,
                      rawDocs,
                    );

                    _scheduleJobDoneOverlayRefresh(rawDocs);

                    if (docs.isEmpty) {
                      return RefreshIndicator(
                        color: kPrestoOrange,
                        onRefresh: _refreshOffers,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: ClampingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(24, 18, 24, 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.grid_view_rounded,
                                    size: 20,
                                    color: _offersOrange,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    '0 annonce',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: _offersNavy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 420,
                              child: _EmptyOffers(onRefresh: _refreshOffers),
                            ),
                          ],
                        ),
                      );
                    }

                    final items = _getOfferListItemsMemo(
                      currentOffersStreamKey,
                      docs,
                    );

                    return Column(
                      children: [
                        Expanded(
                          child: RefreshIndicator(
                            color: kPrestoOrange,
                            onRefresh: _refreshOffers,
                            child: ListView.builder(
                              key: const PageStorageKey<String>(
                                'consult-offers-list',
                              ),
                              controller: _scrollController,
                              cacheExtent: 1200,
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: ClampingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(6, 0, 6, 132),
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: true,
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                if (item.isAd) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      left: 6,
                                      right: 6,
                                      bottom: 6,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: AdBanner(
                                        margin: EdgeInsets.zero,
                                        placeholderFolderPrefix:
                                            'assets/carousel_home/',
                                        flat: true,
                                        animatePlaceholder: true,
                                      ),
                                    ),
                                  );
                                }
                                final offerId = item.offerId!;
                                final title = item.title!;
                                final data = item.data!;
                                final tileData = item.tileData!;

                                return RepaintBoundary(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _OfferBrowseTile(
                                      key: ValueKey<String>('offer-$offerId'),
                                      onTap: tileData.showJobDoneOverlay
                                          ? null
                                          : () {
                                              _logOfferClicked(offerId, title);
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      OfferDetailsPage(
                                                    offer:
                                                        buildOfferDetailsOffer(
                                                      offerId: offerId,
                                                      data: data,
                                                    ),
                                                    currentUserId: FirebaseAuth
                                                            .instance
                                                            .currentUser
                                                            ?.uid ??
                                                        '',
                                                  ),
                                                ),
                                              );
                                            },
                                      data: tileData,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    final panelFieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
    );

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 320),
      firstCurve: Curves.easeOutCubic,
      secondCurve: Curves.easeInCubic,
      sizeCurve: Curves.easeInOutCubicEmphasized,
      alignment: Alignment.topCenter,
      crossFadeState:
          _showFilters ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: Form(
        key: ValueKey(_filterPanelKey),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.97),
              labelStyle: const TextStyle(
                color: Color(0xFF345286),
                fontWeight: FontWeight.w700,
              ),
              hintStyle: const TextStyle(color: Color(0xFF7183A6)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: panelFieldBorder,
              border: panelFieldBorder,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFFFC04A),
                  width: 1.6,
                ),
              ),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x331A73E8),
                  Color(0x141A73E8),
                  Color(0x0DFFFFFF),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x331A73E8)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x1A1A73E8),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCategoryDropdown(),
                const SizedBox(height: 12),
                _buildRegionDropdown(),
                const SizedBox(height: 12),
                _buildDepartmentDropdown(),
                const SizedBox(height: 12),
                _buildFilterCityField(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _resetFilters,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kPrestoBlue,
                          backgroundColor: Colors.white.withValues(alpha: 0.97),
                          side: const BorderSide(color: Color(0xFFCDD9F0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Réinitialiser'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _applyFiltersOrSearch,
                        icon: const Icon(Icons.search),
                        label: const Text('Rechercher'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _offersOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }

  Widget _buildRegionDropdown() {
    return Focus(
      focusNode: _regionFocus,
      child: DropdownButtonFormField<String?>(
        initialValue: _filterRegionCode,
        isDense: true,
        dropdownColor: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(16),
        decoration: const InputDecoration(labelText: "Région", isDense: true),
        items: <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(
            value: null,
            child: Text("Toutes régions"),
          ),
          ...kRegionsOrdered.map(
            (r) =>
                DropdownMenuItem<String?>(value: r.code, child: Text(r.name)),
          ),
        ],
        onChanged: (code) {
          setState(() {
            _filterRegionCode = code;
            _trackManualFilterCriterion(
              'region',
              isActive: (code ?? '').trim().isNotEmpty,
            );
            _trackManualFilterCriterion('department', isActive: false);
            _trackManualFilterCriterion('city', isActive: false);

            // ✅ Région change => on reset le dept + ville + CP
            _filterDepartmentCode = null;
            _filterCityController.clear();
            _filterPostalCodeController.clear();
            _filterCityName = null;
            _filterCitySuggestions = [];
            _filterCityHighlightedIndex = -1;
          });

          _onAnyFilterChanged(); // ✅ auto-apply

          // Passe au champ département
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FocusScope.of(context).requestFocus(_deptFocus);
          });
        },
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    // ✅ Utilise le getter pour obtenir les départements filtrés
    final deptCodes = [..._filteredDepartmentCodes]..sort();

    final allowedCodes = deptCodes.toSet();
    final safeValue = (_filterDepartmentCode != null &&
            allowedCodes.contains(_filterDepartmentCode))
        ? _filterDepartmentCode
        : null; // ✅ si la valeur n’existe pas, on repasse à "Tous"

    // ✅ Si le filtre courant pointe vers un département non disponible,
    // on remet aussi l'état interne à null (sinon on a un "ghost value").
    if (_filterDepartmentCode != null &&
        safeValue == null &&
        !_departmentResetScheduled) {
      _departmentResetScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _departmentResetScheduled = false;
        if (!mounted || _filterDepartmentCode == null) return;
        if (allowedCodes.contains(_filterDepartmentCode)) return;

        setState(() {
          _filterDepartmentCode = null;
          _filterCityController.clear();
          _filterPostalCodeController.clear();
          _filterCityName = null;
          _filterCitySuggestions = [];
          _filterCityHighlightedIndex = -1;
        });

        _onAnyFilterChanged();
      });
    }

    return Focus(
      focusNode: _deptFocus,
      child: DropdownButtonFormField<String?>(
        initialValue: safeValue,
        isDense: true,
        dropdownColor: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(16),
        decoration: InputDecoration(
          labelText: 'Département',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Tous départements'),
          ),
          ...deptCodes.map(
            (code) => DropdownMenuItem<String?>(
              value: code,
              child: Text(kDepartments[code] ?? code),
            ),
          ),
        ],
        onChanged: (code) {
          setState(() {
            _filterDepartmentCode = code;
            _trackManualFilterCriterion(
              'department',
              isActive: (code ?? '').trim().isNotEmpty,
            );
            _trackManualFilterCriterion('city', isActive: false);

            // ✅ Si on choisit un dept, on synchronise la région automatiquement
            if (code != null) {
              final regionCode = _deptToRegion[code];
              if (regionCode != null) _filterRegionCode = regionCode;

              // ✅ Dept change => reset ville + CP (évite incohérences)
              _filterCityController.clear();
              _filterPostalCodeController.clear();
              _filterCityName = null;
              _filterCitySuggestions = [];
              _filterCityHighlightedIndex = -1;
            } else {
              _filterRegionCode = null;
            }
          });
        },
      ),
    );
  }

  // Méthodes pour la gestion de l'autocomplétion de ville dans les filtres
  List<CityRecord> _searchCities(String q) {
    final allowed = _allowedDeptCodesForCity;
    return CitySearch.instance.search(q, limit: 20, allowedDeptCodes: allowed);
  }

  Widget _buildFilterCityField() {
    return Autocomplete<CityRecord>(
      displayStringForOption: (c) => '${c.name} (${c.cp})',
      optionsBuilder: (TextEditingValue v) {
        final q = v.text.trim();
        if (q.length < 2) return const Iterable<CityRecord>.empty();
        return _searchCities(q);
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: const Color(0xFFF4F8FF),
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFBED5F8)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    final highlightedIndex = AutocompleteHighlightedOption.of(
                      context,
                    );
                    final isHighlighted = index == highlightedIndex;

                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(
                        '${option.name} (${option.cp})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isHighlighted
                              ? const Color(0xFF0D47A1)
                              : const Color(0xFF1E2554),
                        ),
                      ),
                      tileColor: isHighlighted
                          ? const Color(0xFFDDEBFF)
                          : Colors.transparent,
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      onSelected: (CityRecord c) {
        final dept = (c.departmentCode.trim().isNotEmpty)
            ? c.departmentCode.trim()
            : _deptFromPostal(c.postalCode);

        setState(() {
          // ✅ Ville
          _filterCityController.text = c.name;
          _filterCityName = c.name;
          _trackManualFilterCriterion('city', isActive: true);

          // ✅ CP
          _filterPostalCodeController.text = c.postalCode;

          // ✅ Dept (ex: 971 au lieu de 97)
          _filterDepartmentCode = dept;

          // ✅ Région: prendre celle du record si dispo, sinon fallback via dept
          final regionFromRecord = c.regionCode.trim();
          if (regionFromRecord.isNotEmpty) {
            _filterRegionCode = regionFromRecord;
          } else {
            for (final entry in kRegionDepartments.entries) {
              if (entry.value.contains(dept)) {
                _filterRegionCode = entry.key;
                break;
              }
            }
          }

          _filterCitySuggestions = [];
          _filterCityHighlightedIndex = -1;
        });

        _onAnyFilterChanged();
      },
      fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
        // Synchroniser avec notre controller
        if (_filterCityController.text != textCtrl.text) {
          textCtrl.text = _filterCityController.text;
        }

        return TextField(
          controller: textCtrl,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Ville',
            hintText: 'Ex: Paris, Les Abymes...',
            isDense: true,
            suffixIcon: textCtrl.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer la ville',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _filterCityController.clear();
                        _filterPostalCodeController.clear();
                        _filterCityName = null;
                        _filterCitySuggestions = [];
                        _filterCityHighlightedIndex = -1;
                        _trackManualFilterCriterion('city', isActive: false);
                      });
                      textCtrl.clear();
                      _onAnyFilterChanged();
                    },
                  ),
          ),
          onChanged: (value) {
            _filterCityController.text = value;
          },
        );
      },
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _filterCategory,
      isDense: true,
      dropdownColor: const Color(0xFFF4F8FF),
      borderRadius: BorderRadius.circular(16),
      decoration: const InputDecoration(labelText: 'Catégorie', isDense: true),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('Toutes les catégories'),
        ),
        ...kCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
      ],
      onChanged: (value) {
        setState(() {
          _filterCategory = value;
          _trackManualFilterCriterion(
            'category',
            isActive: (value ?? '').trim().isNotEmpty,
          );
          _headerTitle = _resolveConsultOffersTitle();
        });
        _onAnyFilterChanged();
      },
    );
  }

  String _ageLabelFromCreatedAt(dynamic createdAt) {
    if (createdAt == null) return '';

    DateTime dt;
    try {
      // Firestore Timestamp
      if (createdAt is Timestamp) {
        dt = createdAt.toDate();
      }
      // Milliseconds since epoch
      else if (createdAt is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(createdAt);
      }
      // ISO string
      else if (createdAt is String) {
        dt = DateTime.tryParse(createdAt) ?? DateTime.now();
      } else {
        return '';
      }
    } catch (_) {
      return '';
    }

    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} j';
  }

  String _sanitizeOfferTitle({
    required String rawTitle,
    required String city,
    required String postalCode,
  }) {
    var title = rawTitle.trim();
    if (title.isEmpty) return 'Sans titre';
    final safeCity = city.trim();
    final safePostalCode = postalCode.trim();

    if (safeCity.isNotEmpty && safeCity != 'Lieu non précisé') {
      final cityRegex = RegExp(_escapeRegex(safeCity), caseSensitive: false);
      title = title.replaceAll(cityRegex, ' ');
    }

    if (safePostalCode.isNotEmpty) {
      final postalRegex = RegExp(
        '\\b${_escapeRegex(safePostalCode)}\\b',
        caseSensitive: false,
      );
      title = title.replaceAll(postalRegex, ' ');
    }

    title = title
        .replaceAll(RegExp(r'\s*[-–/|]\s*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return title.isEmpty ? rawTitle.trim() : title;
  }

  String _escapeRegex(String input) {
    return input.replaceAllMapped(
      RegExp(r'[\\^\$.|?*+(){}\[\]]'),
      (m) => '\\${m[0]}',
    );
  }

  String _extractMissionDelayLabel(Map<String, dynamic> data) {
    final candidates = [
      data['missionDelay'],
      data['averageDelay'],
      data['dateLabel'],
      data['deadlineLabel'],
      data['executionDelay'],
      data['responseDelay'],
    ];

    for (final candidate in candidates) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }

    return 'Délai non précisé';
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'plomberie':
        return Icons.plumbing_outlined;
      case 'bricolage':
        return Icons.handyman_outlined;
      case 'jardinage':
        return Icons.yard_outlined;
      case 'menage':
      case 'ménage':
        return Icons.cleaning_services_outlined;
      case 'demenagement':
      case 'déménagement':
        return Icons.local_shipping_outlined;
      default:
        return Icons.work_outline_rounded;
    }
  }

  bool _isQuickResponse(Map<String, dynamic> data) {
    final dynamic direct = data['quickResponse'] ?? data['isQuickResponse'];
    if (direct is bool) return direct;

    final statusBadges = (data['statusBadges'] as List<dynamic>? ?? const [])
        .map((e) => e.toString().toLowerCase())
        .toList();
    if (statusBadges.any((b) => b.contains('rapide'))) {
      return true;
    }

    final availability = (data['availability'] ?? '').toString().toLowerCase();
    if (availability.contains('rapide')) {
      return true;
    }

    final averageDelay = (data['averageDelay'] ?? '').toString().toLowerCase();
    if (averageDelay.contains('min')) {
      return true;
    }

    return false;
  }

  Future<void> _showEditOfferDialog(
    BuildContext context,
    String offerId,
    Map<String, dynamic> data,
  ) async {
    final titleCtrl = TextEditingController(
      text: (data['title'] ?? '').toString(),
    );
    final cityCtrl = TextEditingController(
      text: (data['city'] ?? '').toString(),
    );
    final descCtrl = TextEditingController(
      text: (data['description'] ?? '').toString(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Modifier l\'annonce',
          style: kPrestoSectionTitleStyle,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Titre'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cityCtrl,
                decoration: const InputDecoration(labelText: 'Ville'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 3,
                maxLines: 6,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La modification d\'annonce doit passer par le flux canonique Marketplace. Cette edition directe n\'est plus autorisee ici.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteOffer(
    BuildContext context,
    String offerId,
    String title,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const CloseOfferReasonDialog(),
    );

    if (reason == null) return;

    try {
      final listingsRef = FirebaseFirestore.instance
          .collection(kListingsCollection)
          .doc(offerId);
      final listingsSnap = await listingsRef.get();
      if (listingsSnap.exists) {
        final shouldKeepVisibleWithJobDone = isOfferJobDoneDeletionReason(
          reason,
        );
        if (shouldKeepVisibleWithJobDone) {
          await TrustScoreService().closeOfferWithReason(
            offerId: offerId,
            reason: reason,
            jobDone: true,
          );
        } else {
          final callable = prestoFirebaseFunctions.httpsCallable(
            'deleteListing',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          );
          await callable.call<dynamic>({
            'listingId': offerId,
            'reason': reason,
          });
        }
        await _refreshOffers();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                shouldKeepVisibleWithJobDone
                    ? 'Annonce "$title" marquée comme réalisée. Elle restera visible 10 h avec son état de clôture.'
                    : 'Annonce supprimée.',
              ),
            ),
          );
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cette annonce legacy doit etre migree vers Marketplace avant suppression.',
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (context.mounted) {
        final message = error.code == 'permission-denied'
            ? 'Suppression refusée. Cette annonce ne vous appartient pas ou plus.'
            : error.code == 'not-found'
                ? 'Annonce introuvable.'
                : 'Suppression temporairement indisponible. Réessayez dans un instant.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Suppression temporairement indisponible. Réessayez dans un instant.',
            ),
          ),
        );
      }
    }
  }
}

bool _shouldHideConsultTilePrice(Map data) {
  const flagKeys = <String>[
    'isNegotiable',
    'negotiable',
    'priceNegotiable',
    'budgetNegotiable',
    'isPriceNegotiable',
    'isBudgetNegotiable',
    'aNegocier',
    'àNégocier',
    'toNegotiate',
    'priceToNegotiate',
  ];

  for (final key in flagKeys) {
    final value = data[key];

    if (value == true) return true;

    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text == 'true' ||
        text.contains('negocier') ||
        text.contains('négocier') ||
        text.contains('negotiable')) {
      return true;
    }
  }

  const priceKeys = <String>[
    'price',
    'budget',
    'amount',
    'tarif',
    'prix',
    'priceAmount',
    'budgetAmount',
    'estimatedBudget',
    'proposedBudget',
  ];

  for (final key in priceKeys) {
    final value = data[key];
    if (value == null) continue;

    if (value is num && value <= 0) return true;

    final raw = value.toString().trim().toLowerCase();
    final normalized = raw
        .replaceAll('€', '')
        .replaceAll('eur', '')
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'\s+'), '');

    if (raw.isEmpty ||
        raw == '0€' ||
        raw == '0 €' ||
        raw.contains('negocier') ||
        raw.contains('négocier') ||
        raw.contains('negotiable')) {
      return true;
    }

    final parsed = double.tryParse(normalized);
    if (parsed != null && parsed <= 0) return true;
  }

  return false;
}

class _ConsultOfferListItem {
  final bool isAd;
  final String? offerId;
  final String? title;
  final Map<String, dynamic>? data;
  final _OfferBrowseTileData? tileData;

  const _ConsultOfferListItem._({
    required this.isAd,
    this.offerId,
    this.title,
    this.data,
    this.tileData,
  });

  const _ConsultOfferListItem.ad() : this._(isAd: true);

  const _ConsultOfferListItem.offer({
    required String offerId,
    required String title,
    required Map<String, dynamic> data,
    required _OfferBrowseTileData tileData,
  }) : this._(
          isAd: false,
          offerId: offerId,
          title: title,
          data: data,
          tileData: tileData,
        );
}

class _OfferBrowseTileData {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String publishedText;
  final int price;
  final bool hidePrice;
  final String missionDelayLabel;
  final bool isUrgent;
  final IconData icon;
  final bool showJobDoneOverlay;

  const _OfferBrowseTileData({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.publishedText,
    required this.price,
    required this.hidePrice,
    required this.missionDelayLabel,
    required this.isUrgent,
    required this.icon,
    required this.showJobDoneOverlay,
  });
}

class _OfferBrowseTile extends StatelessWidget {
  final _OfferBrowseTileData data;
  final VoidCallback? onTap;

  const _OfferBrowseTile({super.key, required this.data, this.onTap});

  Widget _buildFallbackPhoto() {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  Widget _buildUrgentPhoto() {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(5),
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/urgent_stamp.webp',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
      ),
    );
  }

  Widget _buildPhoto() {
    if (data.isUrgent) {
      return _buildUrgentPhoto();
    }
    final imageUrl = data.imageUrl.trim();
    if (imageUrl.isEmpty) {
      return _buildFallbackPhoto();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 92,
        height: 92,
        child: OfferNetworkImage(
          url: imageUrl,
          fit: BoxFit.cover,
          cacheWidth: 300,
          errorChild: _buildFallbackPhoto(),
          loadingChild: _buildFallbackPhoto(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: _buildTileFrame(),
    );
  }

  Widget _buildTileFrame() {
    const outerRadius = 24.0;
    const cornerAccentSize = 54.0;
    const offerCardBorderWidth = 1.8;

    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: IgnorePointer(
              child: Container(
                width: cornerAccentSize,
                height: cornerAccentSize,
                decoration: const BoxDecoration(
                  color: kPrestoBlue,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(24)),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(outerRadius),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(outerRadius),
                border: Border.all(
                  color: _ConsultOffersPageState._offersCardBorder,
                  width: offerCardBorderWidth,
                ),
                boxShadow: [
                  const BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Surlignage titre — flush bords haut/gauche/droit de la tuile
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCEEFD),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(outerRadius),
                            topRight: Radius.circular(outerRadius),
                          ),
                        ),
                        child: Text(
                          data.title.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: _ConsultOffersPageState._offersNavy,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ),
                      // Contenu (photo + infos) avec padding normal
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _buildPhoto(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.15,
                                      fontWeight: FontWeight.w500,
                                      color: _ConsultOffersPageState._offersNavy
                                          .withValues(alpha: 0.82),
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    data.publishedText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.0,
                                      fontWeight: FontWeight.w500,
                                      color: _ConsultOffersPageState
                                          ._offersSoftText,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: _OfferMissionDelayChip(
                                          label: data.missionDelayLabel,
                                        ),
                                      ),
                                      if (!data.hidePrice) ...[
                                        const SizedBox(width: 12),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 132,
                                          ),
                                          child: Text(
                                            '${data.price} €',
                                            textAlign: TextAlign.right,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 26,
                                              height: 1.0,
                                              fontWeight: FontWeight.w700,
                                              color: _ConsultOffersPageState
                                                  ._offersOrange,
                                              letterSpacing: -0.9,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (data.showJobDoneOverlay)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(outerRadius),
                            ),
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Image.asset(
                                'assets/images/jobfait.webp',
                                height: 132,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality
                                    .none, // Maximum performance sur le web
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (onTap != null)
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(outerRadius),
                          onTap: onTap,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _primaryBrowseOfferImageUrl(Map<String, dynamic> data) {
  final thumbnailUrl = (data['thumbnailUrl'] ?? '').toString().trim();
  if (thumbnailUrl.isNotEmpty) return thumbnailUrl;

  final imageUrl = (data['imageUrl'] ?? '').toString().trim();
  if (imageUrl.isNotEmpty) return imageUrl;

  final imageUrls = data['imageUrls'];
  if (imageUrls is List) {
    for (final entry in imageUrls) {
      final value = entry.toString().trim();
      if (value.isNotEmpty) return value;
    }
  }

  final media = data['media'];
  if (media is List) {
    for (final entry in media) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry.cast<dynamic, dynamic>());
      final candidate =
          ((map['thumbnailUrl'] ?? map['downloadUrl']) ?? '').toString().trim();
      if (candidate.isNotEmpty) return candidate;
    }
  }

  return '';
}

class _OfferMissionDelayChip extends StatelessWidget {
  final String label;

  const _OfferMissionDelayChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cleanLabel =
        label.trim().isEmpty ? 'Délai non précisé' : label.trim();

    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6600),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFF6600)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              cleanLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StandardResponseBadge extends StatelessWidget {
  const _StandardResponseBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEF4),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Standard',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF666C87),
        ),
      ),
    );
  }
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Les annonces peuvent arriver à tout moment.",
              style: TextStyle(
                fontSize: 17,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "Tire vers le bas ou appuie sur le bouton pour recharger les annonces.",
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualiser'),
            ),
            const SizedBox(height: 16),
            const Text(
              "Ajoutez cette catégorie en favori pour être alerté dès qu'une annonce est publiée.",
              style: TextStyle(
                fontSize: 17,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              "Créez un compte pour enregistrer vos favoris et activer les notifications.",
              style: TextStyle(
                fontSize: 17,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ DEPRECATED: OfferDetailPage supprimee
// Utilisez OfferDetailsPage (pages/offers/offer_details_page.dart) a la place

class UserPublicProfilePage extends StatefulWidget {
  final String userId;
  final String? initialPseudo;

  const UserPublicProfilePage({
    super.key,
    required this.userId,
    this.initialPseudo,
  });

  @override
  State<UserPublicProfilePage> createState() => _UserPublicProfilePageState();
}

class _UserPublicProfilePageState extends State<UserPublicProfilePage> {
  late final Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _activeOffersFuture;

  @override
  void initState() {
    super.initState();
    _activeOffersFuture = _loadActiveOffers();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadActiveOffers() async {
    // Charger depuis la collection listings (marketplace) et offers (legacy)
    final listingsCol = FirebaseFirestore.instance.collection(
      kListingsCollection,
    );

    final results =
        await Future.wait<List<QueryDocumentSnapshot<Map<String, dynamic>>>>([
      listingsCol
          .where('ownerId', isEqualTo: widget.userId)
          .where(publicListingsFilter())
          .get()
          .then((snap) => snap.docs),
      loadLegacyPublicOffersByOwner(
        ownerField: 'uid',
        ownerId: widget.userId,
        limit: 200,
        source: 'consult_active_offers_legacy_uid',
      ),
      loadLegacyPublicOffersByOwner(
        ownerField: 'userId',
        ownerId: widget.userId,
        limit: 200,
        source: 'consult_active_offers_legacy_userId',
      ),
    ]);

    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final docs in results) {
      for (final d in docs) {
        byId[d.id] = d;
      }
    }

    final docs = byId.values.toList(growable: false);

    // Toute annonce publiée doit être visible dans le profil public.
    final filtered = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in docs) {
      final data = doc.data();
      if (!isVisibleInPublicBrowse(data)) {
        continue;
      }
      filtered.add(doc);
    }
    return filtered;
  }

  String _extractUserPseudo(Map<String, dynamic>? data) {
    final candidates = <String?>[
      data?['pseudo']?.toString(),
      data?['username']?.toString(),
      data?['displayName']?.toString(),
      data?['name']?.toString(),
      widget.initialPseudo,
    ];
    for (final v in candidates) {
      final s = (v ?? '').trim();
      if (s.isNotEmpty) return s;
    }
    return 'Profil';
  }

  Future<void> _contactUser(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      navigator.push(MaterialPageRoute(builder: (_) => const AccountPage()));
      return;
    }

    if (user.uid == widget.userId) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Vous ne pouvez pas vous envoyer un message.'),
        ),
      );
      return;
    }

    // The profile page has no offer context, so we anchor the conversation on
    // the most recent active offer published by this advertiser. If they have
    // none, the conversation cannot be created and we surface a clear error.
    List<QueryDocumentSnapshot<Map<String, dynamic>>> offers;
    try {
      offers = await _activeOffersFuture;
    } catch (error, stackTrace) {
      logRuntimeAction(
        area: 'messaging',
        action: 'contact-user-load-offers-failed',
        details: <String, Object?>{
          'targetUid': widget.userId,
          'error': error.toString(),
        },
      );
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'consult_offers contactUser load offers failed',
      );
      if (!context.mounted) return;
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Impossible de charger les annonces de cet annonceur.'),
        ),
      );
      return;
    }

    if (offers.isEmpty) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            "Cet annonceur n'a pas d'annonce active à laquelle rattacher la conversation.",
          ),
        ),
      );
      return;
    }

    final anchorDoc = offers.first;
    final anchorData = anchorDoc.data();
    final offerTitle =
        (anchorData['title'] ?? anchorData['titre'] ?? '').toString().trim();
    final offerId = anchorDoc.id;

    final otherUserPseudo = _extractUserPseudo(anchorData);
    final currentUserName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email ?? 'Utilisateur');
    final initialDraftText =
        'Bonjour $otherUserPseudo, je vous contacte au sujet de votre annonce "$offerTitle".';

    String conversationId;
    try {
      conversationId = await ConversationService.ensureConversation(
        offerId: offerId,
        offerTitle: offerTitle,
        currentUserId: user.uid,
        otherUserId: widget.userId,
        currentUserName: currentUserName,
        otherUserName: otherUserPseudo,
      );
    } catch (error, stackTrace) {
      logRuntimeAction(
        area: 'messaging',
        action: 'contact-user-ensure-conversation-failed',
        details: <String, Object?>{
          'targetUid': widget.userId,
          'offerId': offerId,
          'error': error.toString(),
        },
      );
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'consult_offers contactUser ensureConversation failed',
      );
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de démarrer la conversation : ${error.toString()}',
          ),
        ),
      );
      return;
    }

    logRuntimeAction(
      area: 'messaging',
      action: 'contact-user-open-conversation',
      details: <String, Object?>{
        'targetUid': widget.userId,
        'offerId': offerId,
        'conversationId': conversationId,
      },
    );

    if (!context.mounted) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => MessagesPageV2(
          initialConversationId: conversationId,
          initialDraftText: initialDraftText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
        leading: const BackButton(),
        title: const Text('Profil', style: kPrestoAppBarTitleStyle),
        centerTitle: true,
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(6, 14, 6, 14),
          children: [
            FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              future: _activeOffersFuture,
              builder: (context, snap) {
                final publicProfileData = (snap.data?.isNotEmpty ?? false)
                    ? snap.data!.first.data()
                    : null;
                final pseudo = _extractUserPseudo(publicProfileData);
                return CardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Image.asset(
                                'assets/images/default_avatar.webp',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              pseudo,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Contacter ce membre pour échanger sur ses annonces.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrestoBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: () => _contactUser(context),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Contacter par message'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            TrustScoreCard(userId: widget.userId),
            const SizedBox(height: 14),
            CardShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Annonces publiées en cours',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<
                      List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                    future: _activeOffersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                kPrestoOrange,
                              ),
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Text(
                          "Erreur de chargement des annonces.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }

                      final docs = snapshot.data ?? const [];
                      if (docs.isEmpty) {
                        return Text(
                          "Aucune annonce en cours.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }

                      return Column(
                        children: [
                          for (final doc in docs) ...[
                            _UserOfferMiniCard(
                              offerId: doc.id,
                              data: doc.data(),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserOfferMiniCard extends StatelessWidget {
  final String offerId;
  final Map<String, dynamic> data;
  const _UserOfferMiniCard({required this.offerId, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = (data['title'] ?? '').toString().trim();
    final location = (data['location'] ?? data['city'] ?? '').toString().trim();
    final category = (data['category'] ?? '').toString().trim();
    final budget = data['budget'];
    final priceText = (budget is num) ? "${budget.toStringAsFixed(0)} €" : '';

    final annonceurId = (data['userId'] ?? data['uid'] ?? '').toString().trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) {
                final description = (data['description'] ?? '').toString();
                final phone = data['phone']?.toString();

                final List<String> imageUrls =
                    (data['imageUrls'] as List<dynamic>? ?? [])
                        .map((e) => e.toString())
                        .toList();

                return OfferDetailsPage(
                  offer: buildOfferDetailsOffer(offerId: offerId, data: data),
                  currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
                );
              },
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.1),
              width: 1.4,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty ? 'Annonce' : title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              if (location.isNotEmpty)
                Text(
                  location,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (category.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    category,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (priceText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    priceText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: kPrestoOrange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
// (supprimé) `_OfferMetaRow` était non référencé et générait un avertissement.

/// Utilitaire : format d'heure pour la liste de conversations
String formatTimeLabel(Timestamp? ts) {
  if (ts == null) return '';
  final dt = ts.toDate();
  final now = DateTime.now();

  final sameDay =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;

  if (sameDay) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
}

/// Utilitaire : format "il y a X h/j" depuis un Timestamp
String formatAgeSince(Timestamp? ts) {
  if (ts == null) {
    return ""; // quand createdAt pas encore rempli (serverTimestamp)
  }
  final dt = ts.toDate();
  final now = DateTime.now();

  final diff = now.difference(dt);
  if (diff.isNegative) return ""; // sécurité si horloge bizarre

  if (diff.inHours < 24) {
    final h = diff.inHours;
    // si < 1h, on affiche en minutes (optionnel)
    if (h <= 0) {
      final m = diff.inMinutes.clamp(0, 59);
      return "il y a $m min";
    }
    return "il y a $h h";
  }

  final d = diff.inDays;
  return "il y a $d j";
}

bool _isDeletedUserMap(Map<String, dynamic>? data) {
  return DeletedUserProfile.isDeletedMap(data);
}

String _deletedAwareDisplayName(
  Map<String, dynamic>? data,
  String? fallbackName,
) {
  return DeletedUserProfile.displayName(
    isDeleted: _isDeletedUserMap(data),
    fallbackName: fallbackName,
  );
}

Widget _deletedAwareAvatar({
  required Map<String, dynamic>? data,
  required Widget fallback,
  double radius = 22,
}) {
  if (_isDeletedUserMap(data)) {
    return DeletedUserAvatar(radius: radius);
  }

  return fallback;
}
