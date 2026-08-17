import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../app/presto_overlay_theme.dart';
import '../app_core.dart';
import '../constants.dart';
import '../features/offers/home_offer_keywords.dart';
import '../features/offers/public_offers_read_diagnostics.dart';
import '../models/hero_slide.dart';
import '../utils/friendly_snackbar.dart';
import '../dev/seed_offers.dart' hide kOffersCollection;
import 'legal_info_page.dart';

import '../services/hero_slides_service.dart';
import '../services/inbox_counts.dart';
import '../services/notification_service.dart';
import '../services/public_offers_query_helpers.dart';
import '../utils/offer_helpers.dart';
import '../utils/runtime_action_logger.dart';
import '../widgets/entrepreneur_toolbox_slide.dart';
import '../widgets/hero_media_slider.dart';
import '../widgets/home_bottom_nav_item.dart';
import '../widgets/home_interactions.dart';
import '../widgets/presto_info_icon_animated.dart';
import '../widgets/presto_tap_target.dart';
import '../widgets/unread_inbox_bell.dart';
import '../pages/offers/offer_details_page.dart';
import '../pages/messages/messages_page_v2.dart';
import 'account_page.dart';
import 'consult_offers_page.dart';
import 'publish_offer_page.dart';
import '../app/system_ui_style.dart' show prestoOverlayStyleFor;
import '../services/offer_details_mapper.dart' show buildOfferDetailsOffer;
import '../services/presto_monitoring.dart' show PrestoMonitoring;

class _HomeCategoryShortcut {
  final IconData icon;
  final String label;
  final String targetCategory;

  const _HomeCategoryShortcut({
    required this.icon,
    required this.label,
    required this.targetCategory,
  });
}

/// HOME ////////////////////////////////////////////////////////////////////

class HomePage extends StatefulWidget {
  final int initialIndex;
  final String? initialConsultCategoryFilter;
  final String? initialConsultSearchQuery;
  final String? initialMessagesConversationId;
  final String? initialMessagesDraftText;

  const HomePage({
    super.key,
    this.initialIndex = 0,
    this.initialConsultCategoryFilter,
    this.initialConsultSearchQuery,
    this.initialMessagesConversationId,
    this.initialMessagesDraftText,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const List<_HomeCategoryShortcut> _homeCategoryShortcuts = [
    _HomeCategoryShortcut(
      icon: Icons.restaurant_outlined,
      label: 'Restauration',
      targetCategory: 'Restauration / Extra',
    ),
    _HomeCategoryShortcut(
      icon: Icons.construction_outlined,
      label: 'Bricolage',
      targetCategory: 'Bricolage / Travaux',
    ),
    _HomeCategoryShortcut(
      icon: Icons.home_outlined,
      label: 'Aide domicile',
      targetCategory: 'Aide à domicile',
    ),
    _HomeCategoryShortcut(
      icon: Icons.child_care_outlined,
      label: 'Garde enfants',
      targetCategory: 'Garde d\'enfants',
    ),
    _HomeCategoryShortcut(
      icon: Icons.music_note_outlined,
      label: 'DJ / Sono',
      targetCategory: 'Événementiel / DJ',
    ),
    _HomeCategoryShortcut(
      icon: Icons.school_outlined,
      label: 'Cours',
      targetCategory: 'Cours & soutien',
    ),
    _HomeCategoryShortcut(
      icon: Icons.eco_outlined,
      label: 'Jardinage',
      targetCategory: 'Jardinage',
    ),
    _HomeCategoryShortcut(
      icon: Icons.format_paint_outlined,
      label: 'Peinture',
      targetCategory: 'Peinture',
    ),
    _HomeCategoryShortcut(
      icon: Icons.handyman_outlined,
      label: 'Main-d\'oeuvre',
      targetCategory: 'Main-d\'oeuvre',
    ),
    _HomeCategoryShortcut(
      icon: Icons.other_houses_outlined,
      label: 'Autres',
      targetCategory: 'Autre',
    ),
  ];

  int _selectedIndex = 0;
  final Set<int> _mountedTabs = <int>{};
  String? _consultCategoryFilter;
  String? _consultSearchQuery;
  final PageController _carouselController = PageController();
  final HeroSlidesService _heroSlidesService = HeroSlidesService();
  late final Stream<List<HeroSlide>> _heroSlidesStream =
      _heroSlidesService.watchActiveSlides();
  List<HeroSlide> _cachedHeroSlides = const <HeroSlide>[];
  String? _userRegion;
  int _currentSlide = 0;

  Timer? _homeAutoSlideTimer;
  Timer? _presenceTimer;
  DateTime? _lastPresenceUpdate;
  DateTime? _sessionStartTime;
  bool _isMessagingPermissionPromptVisible = false;

  // Bottom bar désormais fixe (ne se masque plus au scroll/clavier)

  late final AnimationController _categoryController;

  double _responsiveHomeSlideTitleFontSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 21;
    if (width < 430) return 24;
    if (width < 700) return 26;
    return 30;
  }

  double _responsiveHomeSlideSubtitleFontSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 12.5;
    if (width < 430) return 13.5;
    return 14;
  }

  bool _isSeeding = false;

  /// Contrôle l'affichage des suggestions de recherche
  bool _showSearchSuggestions = true;

  /// Chargement figé à l'ouverture de la home pour stabiliser la section.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _latestOffers = const [];
  bool _isLatestOffersLoading = true;
  Object? _latestOffersError;
  DateTime? _lastLatestOffersLoadedAt;

  final List<String> _baseSearchKeywords = const [
    "jardinage",
    "jardinage aujourd’hui",
    "serveur",
    "serveur ce soir",
    "peinture",
    "débroussaillage",
    "déménagement",
    "aide aux devoirs",
    "nettoyage",
    "ménage",
    "garde d’enfants",
    "DJ",
    "sono",
  ];

  /// Mots-clés dynamiques basés sur les offres Firestore
  List<String> _dynamicKeywords = [];

  /// Suggestions “smart” par défaut
  final List<String> _trendingSuggestions = const [
    "Jardinage aujourd’hui",
    "Serveur ce soir",
    "Peinture urgent",
    "Jardinage Petit-Bourg demain",
  ];

  /// Slides d’accueil
  final List<HomeSlide> _slides = const [
    HomeSlide(
      title: "Trouvez immédiatement quelqu’un pour faire le job.",
      subtitle: "Trouvez une personne près de chez vous en quelques secondes.",
      badge: "",
      // plus d'image chrono ici
      imageAsset: null,
    ),
    HomeSlide(
      title: "Boîte à outils de l'entrepreneur",
      subtitle: "Liens utiles CCI, Région, aides et infos clés.",
      badge: "Pro",
      icon: Icons.business_center_outlined,
    ),
    HomeSlide(
      title: "iliprestō",
      subtitle: "Qui sommes-nous ? Mentions légales, confidentialité, CGU.",
      badge: "Infos",
      icon: Icons.info_outline,
    ),
  ];

  // late final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  void _goToSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return;

    // ✅ Log la recherche
    _logSearch(q);

    setState(() {
      _consultCategoryFilter = null;
      _consultSearchQuery = q;
      _selectedIndex = 1;
      _mountedTabs.add(1);
    });
    _syncCategoryAnimation();
  }

  void _goToCategoryOffers(String category) {
    final normalizedCategory = category.trim();
    if (normalizedCategory.isEmpty) return;

    logRuntimeAction(
      area: 'home',
      action: 'open-category',
      details: <String, Object?>{'category': normalizedCategory},
    );

    setState(() {
      _consultCategoryFilter = normalizedCategory;
      _consultSearchQuery = null;
      _selectedIndex = 1;
      _mountedTabs.add(1);
    });
    _syncCategoryAnimation();
  }

  /// ✅ Enregistre la recherche effectuée
  Future<void> _logSearch(String searchQuery) async {
    try {
      // await _analytics.logSearch(searchTerm: searchQuery);
    } catch (e) {
      debugPrint('[Analytics] logSearch error: $e');
    }
  }

  void _onBottomTap(int index) {
    if (_selectedIndex == index) {
      logRuntimeAction(
        area: 'nav',
        action: 'bottom-tab-repeat',
        details: <String, Object?>{'tab': index},
      );
      return;
    }

    logRuntimeAction(
      area: 'nav',
      action: 'bottom-tab-change',
      details: <String, Object?>{'from': _selectedIndex, 'to': index},
    );

    // ✅ Log le changement d'onglet
    /*
    _analytics.logEvent(
      name: 'tab_changed',
      parameters: {
        'previous_tab': _selectedIndex,
        'new_tab': index,
      },
    );
    */

    setState(() {
      _selectedIndex = index;
      _mountedTabs.add(index);
    });
    if (!kIsWeb) {
      SystemChrome.setSystemUIOverlayStyle(
        prestoOverlayStyleFor(index == 1 ? kPrestoOrange : kPrestoBlue),
      );
    }
    _syncCategoryAnimation();

    if (index == 3) {
      unawaited(_maybePromptMessagingNotifications());
    }
  }

  @override
  void initState() {
    super.initState();

    // Charge les slides en cache (SharedPreferences) pour affichage immédiat
    // avant que le stream Firestore ne réponde.
    _heroSlidesService.loadCachedSlides().then((cached) {
      if (mounted && cached.isNotEmpty) {
        setState(() => _cachedHeroSlides = cached);
      }
    });

    // Charge la région de l'utilisateur pour le filtrage des slides régionaux.
    _loadUserRegion();

    // Assure la barre de statut bleue dès que l'accueil est actif
    SystemChrome.setSystemUIOverlayStyle(prestoOverlayStyleFor(kPrestoBlue));

    _selectedIndex = widget.initialIndex;
    _mountedTabs.add(_selectedIndex);
    _consultCategoryFilter = widget.initialConsultCategoryFilter;
    _consultSearchQuery = widget.initialConsultSearchQuery;
    _sessionStartTime = DateTime.now();
    WidgetsBinding.instance.addObserver(this);

    // ✅ Présence initiale avec statut "online"
    _touchPresence(status: 'online');
    _presenceTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _touchPresence();
    });

    // À l'arrivée sur l'accueil: on laisse le slide texte visible 4s,
    // puis on passe automatiquement au slide 2.
    if (_selectedIndex == 0) {
      _homeAutoSlideTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        if (!_carouselController.hasClients) return;
        _carouselController.animateToPage(
          1,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
        );
      });
    }

    _categoryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // N'anime les catégories que lorsque l'accueil est l'onglet visible.
    if (_selectedIndex == 0) {
      _categoryController.repeat();
    }

    unawaited(_refreshLatestOffers());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedIndex == 3) {
        unawaited(_maybePromptMessagingNotifications());
      }
    });
  }

  Future<void> _loadUserRegion() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final raw = doc.data()?['region']?.toString().trim() ?? '';
      if (raw.isNotEmpty && mounted) {
        setState(() {
          _userRegion = raw;
          _latestOffers = _prioritizeOffersForUserRegion(_latestOffers);
        });
      }
    } catch (_) {}
  }

  Future<void> _touchPresence({String? status}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ✅ Throttling: ne pas mettre à jour si < 30s depuis dernière update
    final now = DateTime.now();
    if (_lastPresenceUpdate != null &&
        status == null &&
        now.difference(_lastPresenceUpdate!).inSeconds < 30) {
      return;
    }

    _lastPresenceUpdate = now;

    try {
      final data = <String, dynamic>{
        'lastSeenAt': FieldValue.serverTimestamp(),
      };

      // ✅ Ajouter le statut si fourni (online/away/offline)
      if (status != null) {
        data['status'] = status;
      }

      // ✅ Stats de session (temps passé)
      if (_sessionStartTime != null && status == 'offline') {
        final sessionDuration = now.difference(_sessionStartTime!);
        data['lastSessionDuration'] = sessionDuration.inMinutes;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
    } catch (_) {
      // best-effort
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // ✅ App reprend → online
        _touchPresence(status: 'online');
        unawaited(NotificationService().syncPushRegistrationIfAuthorized());
        // Refetch only if the cached list is stale (>5 min) to avoid unnecessary
        // network round-trips when the user toggles between apps.
        final last = _lastLatestOffersLoadedAt;
        if (last == null ||
            DateTime.now().difference(last) > const Duration(minutes: 5)) {
          unawaited(_refreshLatestOffers());
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // ✅ App en pause → away
        _touchPresence(status: 'away');
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // ✅ App fermée → offline
        _touchPresence(status: 'offline');
        break;
    }
  }

  Future<void> _maybePromptMessagingNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isMessagingPermissionPromptVisible || !mounted) {
      return;
    }

    final notificationService = NotificationService();
    final shouldPrompt =
        await notificationService.shouldPromptForMessagingPermission(user.uid);
    if (!shouldPrompt || !mounted) return;

    _isMessagingPermissionPromptVisible = true;
    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final overlayTheme = dialogContext.prestoOverlayTheme;
        return AlertDialog(
          backgroundColor: overlayTheme.surfaceColor,
          surfaceTintColor: overlayTheme.surfaceTintColor,
          shape: overlayTheme.dialogShape,
          title: const Text('Recevoir les nouveaux messages'),
          content: const Text(
            'Activez les notifications pour être averti immédiatement quand un nouveau message arrive, même si l’application est fermée.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Plus tard'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Activer les notifications'),
            ),
          ],
        );
      },
    );

    _isMessagingPermissionPromptVisible = false;
    if (!mounted) return;

    if (shouldEnable != true) {
      await notificationService.markMessagingPermissionPromptDismissed(
        user.uid,
      );
      return;
    }

    final granted = await notificationService.requestPushPermission();
    if (!mounted) return;

    if (granted) {
      await notificationService.clearMessagingPermissionPromptDismissed(
        user.uid,
      );
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Notifications activées: vous recevrez les nouveaux messages même quand l’application est fermée.',
      );
      return;
    }

    await notificationService.markMessagingPermissionPromptDismissed(user.uid);
    if (!mounted) return;
    showErrorSnackBar(
      context,
      notificationService.pushActivationFailureMessage(),
    );
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialConsultCategoryFilter !=
            oldWidget.initialConsultCategoryFilter ||
        widget.initialConsultSearchQuery !=
            oldWidget.initialConsultSearchQuery) {
      _consultCategoryFilter = widget.initialConsultCategoryFilter;
      _consultSearchQuery = widget.initialConsultSearchQuery;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // ✅ Marquer offline avant de quitter
    _touchPresence(status: 'offline');

    _carouselController.dispose();
    _categoryController.dispose();
    _homeAutoSlideTimer?.cancel();
    _presenceTimer?.cancel();
    super.dispose();
  }

  /// Démarre/arrête l'animation des catégories selon l'onglet visible.
  /// L'accueil reste monté en permanence (IndexedStack) : sans cela
  /// l'AnimationController tournerait à 60 fps même hors de l'onglet home,
  /// ce qui provoquait des saccades de scroll.
  void _syncCategoryAnimation() {
    if (_selectedIndex == 0) {
      if (!_categoryController.isAnimating) _categoryController.repeat();
    } else if (_categoryController.isAnimating) {
      _categoryController.stop();
    }
  }

  /// Animation "bump" séquentielle sur les 6 catégories
  double _categoryScaleForIndex(int index, {int count = 10}) {
    final t = _categoryController.value * count;
    final active = t.floor() % count;
    final localT = t - t.floor();
    if (index == active) {
      return 1.0 + 0.25 * (1 - (localT - 0.5) * (localT - 0.5) * 4);
    }
    return 1.0;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
      _prioritizeOffersForUserRegion(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> offers,
  ) {
    final region = _userRegion?.trim() ?? '';
    if (region.isEmpty || offers.length <= 1) return offers;

    final prioritized = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
      offers,
    );
    prioritized.sort((a, b) {
      final aMatches = _offerMatchesUserRegion(a.data());
      final bMatches = _offerMatchesUserRegion(b.data());
      if (aMatches == bMatches) return 0;
      return aMatches ? -1 : 1;
    });
    return prioritized;
  }

  bool _offerMatchesUserRegion(Map<String, dynamic> data) {
    final userRegion = _userRegion?.trim() ?? '';
    if (userRegion.isEmpty) return false;

    final normalizedUserRegion = normalizeRegionKey(userRegion);
    final userRegionItem = kRegionsOrdered
        .where((item) {
          return item.code == userRegion ||
              item.normalizedKey == normalizedUserRegion ||
              normalizeRegionKey(item.label) == normalizedUserRegion;
        })
        .cast<RegionItem?>()
        .firstOrNull;

    final offerRegionValues = <String>{
      (data['region'] ?? '').toString().trim(),
      (data['regionCode'] ?? '').toString().trim(),
      (data['regionName'] ?? '').toString().trim(),
    }..removeWhere((value) => value.isEmpty);

    if (userRegionItem != null) {
      offerRegionValues.add(userRegionItem.code);
      offerRegionValues.add(userRegionItem.name);
      offerRegionValues.add(userRegionItem.label);
    }

    return offerRegionValues.any((value) {
      final normalizedValue = normalizeRegionKey(value);
      if (normalizedValue == normalizedUserRegion) return true;
      if (userRegionItem == null) return false;
      return value == userRegionItem.code ||
          normalizedValue == userRegionItem.normalizedKey;
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadLatestOffers() async {
    try {
      // Fetch a small over-pool (16) to absorb post-filter losses while keeping
      // the network payload tight. The query is already orderBy(createdAt desc),
      // so client-side sorting is unnecessary.
      final loaders =
          <Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>[
        loadMergedPublicOfferQueryVariants(
          queries: buildLatestPublicListingsQueryVariants(limit: 16),
          source: 'home_latest_offers_listings',
        ),
      ];
      if (kEnableLegacyPublicOffersBackfill) {
        loaders.add(
          loadMergedPublicOfferQueryVariants(
            queries: buildLatestPublicOffersQueryVariants(limit: 16),
            source: 'home_latest_offers_legacy',
          ),
        );
      }
      final results = await Future.wait(loaders);
      final listings = results[0];
      final legacy = results.length > 1
          ? results[1]
          : listings.isEmpty
              ? await loadLegacyPublicOffersOnDemand(
                  limit: 16,
                  source: 'home_latest_offers_legacy_fallback',
                )
              : const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final mergedAll = mergeOfferDocsById(listings, legacy).toList();
      final merged = _prioritizeOffersForUserRegion(
        mergedAll
            .where((doc) => isVisibleInPublicBrowse(doc.data()))
            .take(8)
            .toList(growable: false),
      );
      return merged;
    } catch (error, stackTrace) {
      logPublicOffersReadErrorWithAppCheck(
        'home_latest_offers',
        error,
        stackTrace,
      );
      throw PublicOffersReadException(
        diagnosePublicOffersReadIssueWithAppCheck(
          error,
          source: 'home_latest_offers',
        ),
      );
    }
  }

  Future<void> _loadLatestOffersOnOpen() async {
    try {
      final docs = await _loadLatestOffers();
      final keywords = buildHomeOfferKeywords(docs.map((doc) => doc.data()));
      if (!mounted) return;
      setState(() {
        _latestOffers = docs;
        _dynamicKeywords = keywords;
        _isLatestOffersLoading = false;
        _latestOffersError = null;
        _lastLatestOffersLoadedAt = DateTime.now();
      });
    } catch (error, stackTrace) {
      logPublicOffersReadErrorWithAppCheck(
        'home_latest_offers',
        error,
        stackTrace,
      );
      final diagnosedError = error is PublicOffersReadException
          ? error
          : PublicOffersReadException(
              diagnosePublicOffersReadIssueWithAppCheck(
                error,
                source: 'home_latest_offers',
              ),
            );
      if (!mounted) return;
      setState(() {
        _latestOffers = const [];
        _isLatestOffersLoading = false;
        _latestOffersError = diagnosedError;
      });
    }
  }

  Future<void> _refreshLatestOffers() async {
    if (mounted) {
      setState(() {
        _isLatestOffersLoading = true;
        _latestOffersError = null;
      });
    }

    await _loadLatestOffersOnOpen();
  }

  Widget _buildHomeCategoriesSection() {
    const compactTargets = <String>[
      'Jardinage',
      'Peinture',
      'Main-d\'oeuvre',
      'Garde d\'enfants',
      'Événementiel / DJ',
    ];

    final compactCategories = compactTargets
        .map(
          (target) => _homeCategoryShortcuts.firstWhere(
            (item) => item.targetCategory == target,
          ),
        )
        .toList(growable: false);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _categoryController,
        builder: (context, child) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < compactCategories.length; index++)
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: HomeCategoryChip(
                        icon: compactCategories[index].icon,
                        label: compactCategories[index].label,
                        iconScale: _categoryScaleForIndex(
                          index,
                          count: compactCategories.length,
                        ),
                        onTap: () => _goToCategoryOffers(
                          compactCategories[index].targetCategory,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLatestOffersSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dernières offres',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _onBottomTap(1),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Voir tout',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kPrestoBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_isLatestOffersLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
                ),
              ),
            )
          else if (_latestOffersError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    friendlyPublicOffersReadErrorWithAppCheck(
                      _latestOffersError!,
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      unawaited(_refreshLatestOffers());
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
                  buildPublicOffersDebugCardWithAppCheck(
                    _latestOffersError!,
                    source: 'home_latest_offers',
                  ),
                ],
              ),
            )
          else if (_latestOffers.isEmpty)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Aucune offre publiée pour le moment.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    unawaited(_refreshLatestOffers());
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualiser'),
                ),
              ],
            )
          else
            Builder(
              builder: (context) {
                PrestoMonitoring.I.trackOtherStream(
                  key: 'home.latestOffers',
                  docsCount: _latestOffers.length,
                );
                return TickerMode(
                  enabled: _selectedIndex == 0,
                  child: RepaintBoundary(
                    child: _AutoScrollingOffersCarousel(
                      offers: _latestOffers,
                      onOfferTap: (doc) {
                        final data = doc.data();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OfferDetailsPage(
                              offer: buildOfferDetailsOffer(
                                offerId: doc.id,
                                data: data,
                              ),
                              currentUserId:
                                  FirebaseAuth.instance.currentUser?.uid ?? '',
                              onBackToConsult: () {
                                if (!mounted) return;
                                setState(() {
                                  _consultCategoryFilter = null;
                                  _consultSearchQuery = null;
                                  _selectedIndex = 1;
                                  _mountedTabs.add(1);
                                });
                                _syncCategoryAnimation();
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Iterable<String> _buildSearchSuggestions(TextEditingValue value) {
    final text = value.text.trim().toLowerCase();

    final all = <String>{
      ..._baseSearchKeywords,
      ..._trendingSuggestions,
      ..._dynamicKeywords,
    };

    if (text.isEmpty) {
      return all.take(8);
    }

    return all.where((s) => s.toLowerCase().contains(text)).take(8);
  }

  Future<void> _seedSampleOffers() async {
    if (_isSeeding) return;
    setState(() => _isSeeding = true);

    try {
      if (mounted) {
        showSuccessSnackBar(context, "Reset + seed des offres en cours…");
      }

      await resetAndSeedOffers();
      await patchLegacyOfferCompatFields();

      if (mounted) {
        showSuccessSnackBar(
          context,
          "Offres de test réinitialisées et injectées ✅",
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, "Erreur lors du seed des offres : $e");
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  Widget _buildSmartSearchBar() {
    const searchBarBorderWidth = 1.8;
    TextEditingController? searchController;
    FocusNode? searchFocusNode;

    void selectSuggestion(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;

      searchController?.text = trimmed;
      searchController?.selection = TextSelection.collapsed(
        offset: trimmed.length,
      );

      setState(() => _showSearchSuggestions = false);
      searchFocusNode?.unfocus();

      _goToSearch(trimmed);
    }

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        if (!_showSearchSuggestions) {
          return const Iterable<String>.empty();
        }
        return _buildSearchSuggestions(value);
      },
      onSelected: selectSuggestion,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        searchController = textEditingController;
        searchFocusNode = focusNode;

        return GestureDetector(
          onTap: () {
            if (focusNode.hasFocus) {
              // Si déjà focusé, basculer l'affichage des suggestions
              setState(() {
                _showSearchSuggestions = !_showSearchSuggestions;
              });
            } else {
              // Sinon, montrer les suggestions
              setState(() {
                _showSearchSuggestions = true;
              });
            }
          },
          child: TextField(
            controller: textEditingController,
            focusNode: focusNode,
            onSubmitted: selectSuggestion,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: "Que cherchez-vous ? (ex: jardinage aujourd’hui)",
              hintStyle: const TextStyle(
                fontSize: 14,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: kPrestoBlue,
                size: 22,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: kPrestoBlue,
                  width: searchBarBorderWidth,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: kPrestoBlue,
                  width: searchBarBorderWidth,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: kPrestoBlue,
                  width: searchBarBorderWidth,
                ),
              ),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final surface = Theme.of(context).colorScheme.surface;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 6),
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
                      option,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    tileColor: isHighlighted
                        ? kPrestoBlue.withValues(alpha: 0.08)
                        : null,
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Cloche : pastille = nombre de messages non lus + notifications d'offres

  /// Affiche un dialogue avec les notifications récentes

  /// Icône d'information pour accéder aux pages légales

  /// Illustration à droite du slide (plus de chrono image)
  Widget _buildSlideIllustration(
    HomeSlide slide,
    int index, {
    VoidCallback? onTap,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final illustrationSize =
        screenWidth < 360 ? 46.0 : (screenWidth < 430 ? 56.0 : 72.0);
    final iconSize =
        screenWidth < 360 ? 24.0 : (screenWidth < 430 ? 28.0 : 32.0);

    // Le slide 3 (infos) reprend le style d'icône bleue animée de la boîte à outils.
    if (index == _slides.length - 1) {
      return PrestoInfoIconAnimated(
        size: illustrationSize,
        showBadge: false,
        onTap: onTap ?? () {},
      );
    }

    // On ignore complètement slide.imageAsset, on affiche juste une icône
    final child = Container(
      width: illustrationSize,
      height: illustrationSize,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(
        slide.icon ?? Icons.flash_on,
        color: kPrestoBlue,
        size: iconSize,
      ),
    );

    if (onTap == null) return child;

    // Même callback que le slide qui la contient (déjà accessible) : exclue
    // de la sémantique pour ne pas annoncer deux fois la même action.
    return ExcludeSemantics(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }

  Widget _buildFallbackHomeHeroSlider() {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (!_carouselController.hasClients || _slides.length <= 1) return;
        final v = details.primaryVelocity ?? 0;
        if (v < -200) {
          _carouselController.animateToPage(
            (_currentSlide + 1) % _slides.length,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
          );
        } else if (v > 200) {
          _carouselController.animateToPage(
            (_currentSlide - 1 + _slides.length) % _slides.length,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
          );
        }
      },
      child: Stack(
        children: [
          PageView.builder(
            controller: _carouselController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _slides.length,
            onPageChanged: (index) {
              setState(() {
                _currentSlide = index;
              });
            },
            itemBuilder: (context, index) {
              final slideIndex = index;
              final slide = _slides[slideIndex];

              // 🔥 SLIDE 1 : plein texte, sans image, phrase géante sur toute la largeur
              if (slideIndex == 0) {
                const String bigText =
                    "Trouvez immédiatement quelqu'un pour faire le job !";

                return Container(
                  height: double.infinity,
                  decoration: const BoxDecoration(color: kPrestoOrange),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ Phrase principale en très gros sur toute la largeur
                        Text(
                          bigText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.18,
                            shadows: const [
                              Shadow(
                                color: Color(0x4D000000),
                                blurRadius: 6,
                                offset: Offset(0, 1.5),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Une personne près de chez vous, en quelques minutes.",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                            shadows: const [
                              Shadow(
                                color: Color(0x40000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // ✅ SLIDE 2 : Boîte à outils de l'entrepreneur (icône bleue animée + badge)
              if (slideIndex == 1) {
                return const EntrepreneurToolboxSlide();
              }

              // 🔁 Slides texte restants : layout texte + icône / image
              final VoidCallback? onSlideTap =
                  slideIndex == (_slides.length - 1)
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LegalInfoPage(),
                            ),
                          );
                        }
                      : null;

              final slideBody = Container(
                height: double.infinity,
                decoration: const BoxDecoration(color: kPrestoOrange),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Texte
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              slide.badge.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              slide.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _responsiveHomeSlideTitleFontSize(
                                  context,
                                ),
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                                shadows: [
                                  Shadow(
                                    color: Color(0x4D000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 1.5),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              slide.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: _responsiveHomeSlideSubtitleFontSize(
                                  context,
                                ),
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(
                                    color: Color(0x40000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 👉 Illustration (icône) sur les slides texte
                      if (slideIndex != 0) ...[
                        const SizedBox(width: 8),
                        _buildSlideIllustration(
                          slide,
                          index,
                          onTap: onSlideTap,
                        ),
                      ],
                    ],
                  ),
                ),
              );

              if (onSlideTap == null) return slideBody;
              // L'icône du slide (même onSlideTap) est exclue de la
              // sémantique pour ne pas annoncer deux fois le même geste.
              return PrestoTapTarget(
                semanticLabel: '${slide.title}. ${slide.subtitle}',
                onTap: onSlideTap,
                child: slideBody,
              );
            },
          ),
          // Indicateurs
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentSlide == index ? 16 : 8,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _currentSlide == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final mq = MediaQuery.of(context);
    // Le clavier (mobile natif comme web) est detecte via viewInsets.bottom.
    // Quand il est ouvert, on masque la bottom bar pour qu'elle ne flotte pas a
    // mi-hauteur ; le body se redimensionne pour garder les champs visibles.
    // A la fermeture du clavier, la barre reapparait normalement en bas.
    final isKeyboardOpen = mq.viewInsets.bottom > 0;

    final statusBarColor = _selectedIndex == 0
        ? Colors.white // home tab: scaffold blanc → icônes sombres
        : (_selectedIndex == 4 || (!kIsWeb && _selectedIndex == 1))
            ? kPrestoOrange // compte + consult (mobile) → orange
            : kPrestoBlue;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: prestoOverlayStyleFor(statusBarColor),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          // Laisse Flutter appliquer l'inset du clavier : le body se
          // redimensionne et la mise en page se restaure proprement a la
          // fermeture (corrige la bottom bar bloquee a mi-ecran sur web).
          resizeToAvoidBottomInset: true,
          extendBody: true,
          backgroundColor: Colors.white,
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeContent(),
              _mountedTabs.contains(1)
                  ? ConsultOffersPage(
                      key: ValueKey<String>(
                        'consult:${_consultCategoryFilter ?? ''}|${_consultSearchQuery ?? ''}',
                      ),
                      onScroll: (_) {},
                      categoryFilter: _consultCategoryFilter,
                      searchQuery: _consultSearchQuery,
                    )
                  : const SizedBox.shrink(),
              _selectedIndex == 2
                  ? PublishOfferPage(onScroll: (_) {})
                  : const SizedBox.shrink(),
              _mountedTabs.contains(3)
                  ? MessagesPageV2(
                      initialConversationId:
                          widget.initialMessagesConversationId,
                      initialDraftText: widget.initialMessagesDraftText,
                    )
                  : const SizedBox.shrink(),
              _mountedTabs.contains(4)
                  ? const AccountPage()
                  : const SizedBox.shrink(),
            ],
          ),
          // Masquee tant que le clavier est ouvert : elle ne flotte plus a
          // mi-ecran et revient en bas des que le clavier se ferme.
          bottomNavigationBar: isKeyboardOpen
              ? null
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                  child: SafeArea(
                    top: false,
                    maintainBottomViewPadding: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: HomeBottomNavItem(
                            icon: Icons.home,
                            label: "Accueil",
                            selected: _selectedIndex == 0,
                            onTap: () => _onBottomTap(0),
                          ),
                        ),
                        Expanded(
                          child: HomeBottomNavItem(
                            icon: Icons.search,
                            label: "Je consulte\nles offres",
                            selected: _selectedIndex == 1,
                            onTap: () => _onBottomTap(1),
                          ),
                        ),
                        Expanded(
                          child: HomeBottomNavItem(
                            icon: Icons.add_circle_outline,
                            label: "Publier\nune offre",
                            isBig: true,
                            selected: _selectedIndex == 2,
                            onTap: () => _onBottomTap(2),
                          ),
                        ),
                        Expanded(
                          child: currentUser == null
                              ? HomeBottomNavItem(
                                  icon: Icons.chat_bubble_outline,
                                  label: "Messages",
                                  selected: _selectedIndex == 3,
                                  onTap: () => _onBottomTap(3),
                                )
                              : UnreadInboxBell(
                                  userId: currentUser.uid,
                                  monitoringKeyPrefix: 'bottomBar.messages',
                                  countType: InboxCountType.unreadMessages,
                                  // ✅ Utilise uniquement le doc agrégé
                                  // users/{uid}/metadata/inbox: un seul snapshot
                                  // léger, pas de fusion de flux conversations +
                                  // messages + notifications.
                                  builder: (context, badgeCount) =>
                                      HomeBottomNavItem(
                                    icon: Icons.chat_bubble_outline,
                                    label: "Messages",
                                    badgeCount: badgeCount,
                                    selected: _selectedIndex == 3,
                                    onTap: () => _onBottomTap(3),
                                  ),
                                ),
                        ),
                        Expanded(
                          child: HomeBottomNavItem(
                            icon: Icons.person_outline,
                            label: "Compte",
                            selected: _selectedIndex == 4,
                            onTap: () => _onBottomTap(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return SafeArea(
      bottom: true,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header : logo + recherche ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
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
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x331A73E8)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onLongPress: _seedSampleOffers,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 40,
                                height: 34,
                                child: Image.asset(
                                  'assets/images/logowebp.webp',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Text(
                                "iliprestō",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: kPrestoOrange,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildSmartSearchBar(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ── Hero slider — prend tout l'espace restant ──────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0x331A73E8),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: const Color(0x331A73E8),
                        blurRadius: 26,
                        spreadRadius: 1,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: _HeroSliderWithStableHeight(
                      cachedSlides: _heroSlidesService.filterSlidesForRegion(
                        _cachedHeroSlides,
                        _userRegion,
                      ),
                      heroSlidesStream: _heroSlidesStream,
                      userRegion: _userRegion,
                      fallbackBuilder: _buildFallbackHomeHeroSlider,
                      carouselController: _carouselController,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            _buildHomeCategoriesSection(),

            const SizedBox(height: 6),

            _buildLatestOffersSection(),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Widget pour envelopper le hero slider avec une hauteur stable, indépendamment du contenu.
/// Cela prévient le redimensionnement visible du hero lors du chargement des slides Firestore.
class _HeroSliderWithStableHeight extends StatelessWidget {
  final List<HeroSlide> cachedSlides;
  final Stream<List<HeroSlide>> heroSlidesStream;
  final String? userRegion;
  final Widget Function() fallbackBuilder;
  final PageController carouselController;

  const _HeroSliderWithStableHeight({
    required this.cachedSlides,
    required this.heroSlidesStream,
    required this.fallbackBuilder,
    required this.carouselController,
    this.userRegion,
  });

  List<HeroSlide> _filterForRegion(List<HeroSlide> slides) {
    return slides.where((slide) {
      if (slide.isGlobal) return true;
      if (slide.isRegional) {
        if (userRegion == null || userRegion!.isEmpty) return false;
        if (slide.targetRegions.isEmpty) return false;
        return slide.targetRegions.contains(userRegion);
      }
      return true; // anciens slides sans scope : global par défaut
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Utilise la même formule que _PrestoStableHeroViewport dans hero_media_slider.dart
    final factor = width < 360 ? 0.62 : (width < 700 ? 0.54 : 0.38);
    final stableHeight = (width * factor).clamp(180.0, 360.0).toDouble();

    return SizedBox(
      width: double.infinity,
      height: stableHeight,
      child: StreamBuilder<List<HeroSlide>>(
        stream: heroSlidesStream,
        builder: (context, snapshot) {
          final fallback = fallbackBuilder();
          final allSlides = snapshot.data ?? cachedSlides;
          final slides = _filterForRegion(allSlides);

          if (snapshot.hasError || slides.isEmpty) {
            // Même le fallback a la hauteur stable
            return fallback;
          }

          return HeroMediaSlider(
            slides: slides,
            fallback: fallback,
            borderRadius: 0,
          );
        },
      ),
    );
  }
}

/// Widget pour l'animation de point pulsant pendant l'enregistrement
class _PulsingDot extends StatefulWidget {
  final int delay;

  const _PulsingDot({required this.delay});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PulseWaveLayer extends StatefulWidget {
  final double width;
  final int delay;

  const _PulseWaveLayer({required this.width, required this.delay});

  @override
  State<_PulseWaveLayer> createState() => _PulseWaveLayerState();
}

class _PulseWaveLayerState extends State<_PulseWaveLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _scale = Tween<double>(
      begin: 0.92,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacity = Tween<double>(
      begin: 0.22,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: widget.width,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: const Color(0xFFE53935),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// BLOC COMMENT ÇA MARCHE /////////////////////////////////////////////////

class MessagesPage extends StatelessWidget {
  final String? initialConversationId;
  final String? initialDraftText;

  const MessagesPage({
    super.key,
    this.initialConversationId,
    this.initialDraftText,
  });

  @override
  Widget build(BuildContext context) {
    return MessagesPageV2(
      initialConversationId: initialConversationId,
      initialDraftText: initialDraftText,
    );
  }
}

class OfferDeepLinkPage extends StatelessWidget {
  final String offerId;
  final bool preferMarketplace;

  const OfferDeepLinkPage({
    super.key,
    required this.offerId,
    this.preferMarketplace = false,
  });

  Future<Map<String, dynamic>?> _loadOfferPayload() async {
    final firestore = FirebaseFirestore.instance;

    Future<Map<String, dynamic>?> loadDocument(
      String collectionName, {
      required bool isMarketplace,
    }) async {
      try {
        final snapshot =
            await firestore.collection(collectionName).doc(offerId).get();
        final data = snapshot.data();
        if (data == null) {
          return null;
        }
        return <String, dynamic>{
          ...data,
          'id': offerId,
          'offerId': offerId,
          'isMarketplace': isMarketplace,
        };
      } on FirebaseException catch (error) {
        final code = error.code.trim().toLowerCase();
        if (code == 'permission-denied' || code == 'unauthenticated') {
          debugPrint(
            '[OfferDeepLink] public load skipped '
            'collection=$collectionName offerId=$offerId code=${error.code}',
          );
          return null;
        }
        rethrow;
      }
    }

    if (preferMarketplace) {
      return await loadDocument('listings', isMarketplace: true) ??
          await loadDocument('offers', isMarketplace: false);
    }

    return await loadDocument('offers', isMarketplace: false) ??
        await loadDocument('listings', isMarketplace: true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadOfferPayload(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: kPrestoOrange,
              foregroundColor: Colors.white,
              title: const Text('Annonce introuvable'),
            ),
            body: const Center(
              child: Text('Cette annonce n\'est plus disponible.'),
            ),
          );
        }

        final isMarketplace = data['isMarketplace'] == true;
        return OfferDetailsPage(
          offer: isMarketplace
              ? data
              : buildOfferDetailsOffer(offerId: offerId, data: data),
          currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
        );
      },
    );
  }
}

// ============================================================================
// CARROUSEL AUTO-DÉFILANT POUR LES DERNIÈRES OFFRES (ligne unique)
// ============================================================================
class _AutoScrollingOffersCarousel extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> offers;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>>)? onOfferTap;

  const _AutoScrollingOffersCarousel({required this.offers, this.onOfferTap});

  @override
  State<_AutoScrollingOffersCarousel> createState() =>
      _AutoScrollingOffersCarouselState();
}

class _AutoScrollingOffersCarouselState
    extends State<_AutoScrollingOffersCarousel>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final Ticker _ticker;
  bool _isUserDragging = false;
  Duration _lastElapsed = Duration.zero;
  static const double _pixelsPerSecond = 44.0;
  String? _renderItemsSignature;
  List<_CarouselRenderItem> _renderItems = const <_CarouselRenderItem>[];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _ticker = createTicker(_onTick)..start();
    _refreshRenderItemsIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _AutoScrollingOffersCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offers.length != widget.offers.length) {
      _lastElapsed = Duration.zero;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
    _refreshRenderItemsIfNeeded();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_scrollController.hasClients) {
      _lastElapsed = elapsed;
      return;
    }

    // Ne pas interrompre le momentum post-fling utilisateur
    if (_isUserDragging ||
        _scrollController.position.isScrollingNotifier.value) {
      _lastElapsed = elapsed;
      return;
    }

    // Plafonner à 2 frames max pour éviter un saut brutal après un long drag
    final dtMs = (elapsed - _lastElapsed).inMilliseconds.clamp(0, 32);
    _lastElapsed = elapsed;
    if (dtMs <= 0) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final loopPoint = maxScroll / 2;
    if (loopPoint <= 0) return;

    final delta = _pixelsPerSecond * (dtMs / 1000.0);
    var next = _scrollController.offset + delta;
    if (next >= loopPoint) {
      next -= loopPoint;
    }

    _scrollController.jumpTo(next);
  }

  String _interventionDelayLabel(Map<String, dynamic> data) {
    String read(String key) => (data[key] ?? '').toString().trim();

    final candidates = <String>[
      read('missionDelay'),
      read('averageDelay'),
      read('availability'),
      read('delaiIntervention'),
      read('interventionDelay'),
      read('interventionWindow'),
    ];

    for (final value in candidates) {
      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'Délai à confirmer';
  }

  String _escapeRegex(String value) {
    return value.replaceAllMapped(
      RegExp(r'[\\^$.|?*+()\[\]{}]'),
      (match) => '\\${match.group(0)}',
    );
  }

  String _displayOfferTitle(String title, String location) {
    final trimmedTitle = title.trim();
    final trimmedLocation = location.trim();
    if (trimmedTitle.isEmpty || trimmedLocation.isEmpty) return trimmedTitle;

    final escapedLocation = _escapeRegex(trimmedLocation);
    final patterns = <RegExp>[
      RegExp(r'\s*[-–—|:]\s*' + escapedLocation + r'$', caseSensitive: false),
      RegExp(r'\s*\(' + escapedLocation + r'\)$', caseSensitive: false),
      RegExp(r'\s*,\s*' + escapedLocation + r'$', caseSensitive: false),
    ];

    var cleanedTitle = trimmedTitle;
    for (final pattern in patterns) {
      cleanedTitle = cleanedTitle.replaceFirst(pattern, '').trim();
    }

    return cleanedTitle.isEmpty ? trimmedTitle : cleanedTitle;
  }

  Widget _buildOfferCard(_CarouselOfferCardData cardData) {
    return PrestoTapTarget(
      semanticLabel: 'Annonce ${cardData.displayTitle}, ${cardData.location}',
      borderRadius: BorderRadius.circular(20),
      onTap: () => widget.onOfferTap?.call(cardData.doc),
      child: Container(
        width: 280,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kPrestoBlue, width: 1.8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cardData.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.12,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 32,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.asset(
                        'assets/images/logowebp.webp',
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F8FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      cardData.whenLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kPrestoBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    cardData.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.black38,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _refreshRenderItemsIfNeeded();
    final duplicatedItems = _renderItems.length > 1
        ? [..._renderItems, ..._renderItems]
        : _renderItems;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _isUserDragging = true;
        } else if (notification is ScrollEndNotification) {
          _isUserDragging = false;
        }
        return false;
      },
      child: SizedBox(
        height: 110,
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: duplicatedItems.length,
          addAutomaticKeepAlives: false,
          cacheExtent: 900,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) => RepaintBoundary(
            child: duplicatedItems[index].isToolbox
                ? const SizedBox(width: 280, child: EntrepreneurToolboxSlide())
                : _buildOfferCard(duplicatedItems[index].cardData!),
          ),
        ),
      ),
    );
  }

  String _offersSignature(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> offers,
  ) {
    if (offers.isEmpty) return '';
    final buffer = StringBuffer();
    for (final doc in offers.take(8)) {
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

  void _refreshRenderItemsIfNeeded() {
    final signature = _offersSignature(widget.offers);
    if (_renderItemsSignature == signature) return;
    _renderItemsSignature = signature;
    _renderItems = _buildCarouselItems(widget.offers);
  }

  List<_CarouselRenderItem> _buildCarouselItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> offers,
  ) {
    final items = <_CarouselRenderItem>[];
    final visibleOffers = offers.take(8).toList(growable: false);
    final toolboxInsertIndex =
        visibleOffers.length >= 4 ? 4 : visibleOffers.length;

    for (var index = 0; index < visibleOffers.length; index += 1) {
      final doc = visibleOffers[index];
      final data = doc.data();
      final title = (data['title'] ?? 'Sans titre').toString();
      final location = (data['location'] ?? 'Lieu non précisé').toString();
      items.add(
        _CarouselRenderItem.offer(
          _CarouselOfferCardData(
            doc: doc,
            displayTitle: _displayOfferTitle(title, location),
            location: location,
            whenLabel: _interventionDelayLabel(data),
          ),
        ),
      );
      if (index + 1 == toolboxInsertIndex) {
        items.add(const _CarouselRenderItem.toolbox());
      }
    }

    if (visibleOffers.isNotEmpty &&
        items.every((item) => item.isToolbox == false)) {
      items.add(const _CarouselRenderItem.toolbox());
    }

    return items;
  }
}

class _CarouselOfferCardData {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String displayTitle;
  final String location;
  final String whenLabel;

  const _CarouselOfferCardData({
    required this.doc,
    required this.displayTitle,
    required this.location,
    required this.whenLabel,
  });
}

class _CarouselRenderItem {
  final _CarouselOfferCardData? cardData;
  final bool isToolbox;

  const _CarouselRenderItem._({this.cardData, required this.isToolbox});

  const _CarouselRenderItem.offer(_CarouselOfferCardData cardData)
      : this._(cardData: cardData, isToolbox: false);

  const _CarouselRenderItem.toolbox() : this._(isToolbox: true);
}
