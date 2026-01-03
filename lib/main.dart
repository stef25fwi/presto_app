import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:record/record.dart';

import 'firebase_options.dart';
import 'app_core.dart';
import 'constants.dart';
import 'utils/crashlytics_context.dart';
import 'utils/friendly_snackbar.dart';
import 'utils/recording_path.dart';
import 'features/micro_ia/micro_ia_service.dart';
import 'features/micro_ia/web_audio_recorder_stub.dart'
  if (dart.library.html) 'features/micro_ia/web_audio_recorder.dart';
import 'features/messaging/conversation_service.dart';
import 'widgets/premium_ai_button.dart';
import 'widgets/ad_banner.dart';
import 'widgets/offer_card.dart';
import 'widgets/phone_input_field.dart';
import 'package:presto_app/widgets/random_asset_ticker.dart';
import 'widgets/entrepreneur_toolbox_slide.dart';
import 'services/city_search.dart';
import 'services/ai_draft_service.dart';
import 'services/notification_service.dart';
import 'pages/pro_profile_page.dart';
import 'pages/legal_info_page.dart';
import 'pages/admin_space_page.dart';
import 'dev/seed_offers.dart';

import 'app/theme.dart';

import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);

SystemUiOverlayStyle prestoOverlayStyleFor(Color backgroundColor) {
  final estimated = ThemeData.estimateBrightnessForColor(backgroundColor);
  final isDarkBackground = estimated == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: backgroundColor,
    statusBarIconBrightness:
        isDarkBackground ? Brightness.light : Brightness.dark,
    // iOS: Brightness.dark => icônes claires
    statusBarBrightness: isDarkBackground ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: kPrestoOrange,
    systemNavigationBarIconBrightness: Brightness.light,
  );
}

/// Villes + codes postaux (exemples Guadeloupe / Martinique)
const Map<String, String> kCityPostalMap = {
  // Guadeloupe
  'Baie-Mahault': '97122',
  'Les Abymes': '97139',
  'Pointe-à-Pitre': '97110',
  'Le Gosier': '97190',
  'Sainte-Anne': '97180',
  'Saint-François': '97118',
  'Petit-Bourg': '97170',
  'Lamentin': '97129',
  'Capesterre-Belle-Eau': '97130',
  'Basse-Terre': '97100',
  'Goyave': '97128',
  'Morne-à-l\'Eau': '97111',
  'Sainte-Rose': '97115',
  'Le Moule': '97160',
  'Saint-Claude': '97120',
  'Bouillante': '97125',
  'Deshaies': '97126',
  'Trois-Rivières': '97114',
  'Vieux-Habitants': '97119',
  'Vieux-Fort': '97141',
  'Anse-Bertrand': '97121',
  'Port-Louis': '97117',
  'Petit-Canal': '97131',
  'La Désirade': '97127',
  'Terre-de-Bas': '97136',
  'Terre-de-Haut': '97137',
  'Marie-Galante': '97140',
  // Martinique
  'Fort-de-France': '97200',
  'Le Lamentin': '97232',
  'Schoelcher': '97233',
  'Le Robert': '97231',
  'Le François': '97240',
  'Le Marin': '97290',
  'Les Trois-Îlets': '97229',
  'Sainte-Luce': '97228',
  'Sainte-Anne (MQ)': '97227',
  'La Trinité': '97220',
  'Le Lorrain': '97214',
  'Le Carbet': '97221',
  'Le Diamant': '97223',
  'Saint-Esprit': '97270',
};

/// Déduit une région à partir du code postal (France métropolitaine + DROM)
String? inferRegionFromPostalCode(String cp) {
  cp = cp.trim();
  if (cp.length < 2) return null;

  // DROM (3 chiffres)
  if (cp.length >= 3) {
    final dromPrefix = cp.substring(0, 3);
    switch (dromPrefix) {
      case '971':
        return 'Guadeloupe';
      case '972':
        return 'Martinique';
      case '973':
        return 'Guyane';
      case '974':
        return 'La Réunion';
      case '976':
        return 'Mayotte';
    }
  }

  // Corse : codes postaux 20000-20999 => on se base sur "20"
  if (cp.startsWith('20')) {
    return 'Corse';
  }

  // Métropole : 2 premiers chiffres => numéro de département
  final two = int.tryParse(cp.substring(0, 2));
  if (two == null) return null;

  // Auvergne-Rhône-Alpes
  if (<int>{1, 3, 7, 15, 26, 38, 42, 43, 63, 69, 73, 74}.contains(two)) {
    return 'Auvergne-Rhône-Alpes';
  }

  // Bourgogne-Franche-Comté
  if (<int>{21, 25, 39, 58, 70, 71, 89, 90}.contains(two)) {
    return 'Bourgogne-Franche-Comté';
  }

  // Bretagne
  if (<int>{22, 29, 35, 56}.contains(two)) {
    return 'Bretagne';
  }

  // Centre-Val de Loire
  if (<int>{18, 28, 36, 37, 41, 45}.contains(two)) {
    return 'Centre-Val de Loire';
  }

  // Grand Est
  if (<int>{8, 10, 51, 52, 54, 55, 57, 67, 68, 88}.contains(two)) {
    return 'Grand Est';
  }

  // Hauts-de-France
  if (<int>{2, 59, 60, 62, 80}.contains(two)) {
    return 'Hauts-de-France';
  }

  // Île-de-France
  if (<int>{75, 77, 78, 91, 92, 93, 94, 95}.contains(two)) {
    return 'Île-de-France';
  }

  // Normandie
  if (<int>{14, 27, 50, 61, 76}.contains(two)) {
    return 'Normandie';
  }

  // Nouvelle-Aquitaine
  if (<int>{16, 17, 19, 23, 24, 33, 40, 47, 64, 79, 86, 87}.contains(two)) {
    return 'Nouvelle-Aquitaine';
  }

  // Occitanie
  if (<int>{9, 11, 12, 30, 31, 32, 34, 46, 48, 65, 66, 81, 82}.contains(two)) {
    return 'Occitanie';
  }

  // Pays de la Loire
  if (<int>{44, 49, 53, 72, 85}.contains(two)) {
    return 'Pays de la Loire';
  }

  // Provence-Alpes-Côte d'Azur
  if (<int>{4, 5, 6, 13, 83, 84}.contains(two)) {
    return 'Provence-Alpes-Côte d\'Azur';
  }

  // Si on n'a rien trouvé, on ne force pas
  return null;
}

/// ============= WIDGETS HELPER POUR OfferDetailPage =============

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null)
                IconTheme(
                  data: IconThemeData(color: Colors.grey.shade500),
                  child: trailing!,
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.black.withOpacity(0.06)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPressed,
        icon: icon,
        label: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade900,
          ),
        ),
      ),
    );
  }
}

/// Petit état de session (user connecté ou non)
class SessionState {
  static String? userId;
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 🔒 App Check
    // - En debug: provider debug (nécessite d'ajouter le debug token dans la console App Check)
    // - En release: Play Integrity (Android) + App Attest (iOS)
    // Note: Web non activé ici (reCAPTCHA v3) car nécessite une siteKey.
    if (!kIsWeb) {
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
          appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        );
      } catch (e) {
        debugPrint('[AppCheck] activation failed: $e');
      }
    }

    // 🔒 Auth minimale requise pour les Cloud Functions (même en anonyme)
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
    } catch (e) {
      // Si l'auth anonyme n'est pas activée côté Firebase, les appels Functions échoueront.
      debugPrint('[Auth] anonymous sign-in failed: $e');
    }

    // Configuration de la barre de navigation système orange
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: kPrestoOrange,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: kPrestoOrange,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: kPrestoOrange,
      ),
    );

    // Crashlytics n'est pas supporté sur le web
    if (!kIsWeb) {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    await CitySearch.instance.ensureLoaded();

    // Initialisation des notifications push (mobile uniquement)
    if (!kIsWeb) {
      try {
        await NotificationService().initialize();
      } catch (e) {
        debugPrint('[Notifications] init error: $e');
      }
    }

    runApp(const PrestoApp());
  }, (error, stack) {
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

class PrestoApp extends StatelessWidget {
  const PrestoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iliprestō',
      debugShowCheckedModeBanner: false,
      routes: {
        '/publish': (_) => const PublishOfferPage(),
      },
      theme: buildPrestoTheme(),
      home: const SplashScreen(),
    );
  }
}

/// SPLASH /////////////////////////////////////////////////////////////////

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _navTimer = Timer(const Duration(milliseconds: 3500), () {
      _navigateTo(const HomePage());
    });
  }

  void _navigateTo(Widget page) {
    if (!mounted) return;
    _navTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _navTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: kPrestoOrange,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: kPrestoOrange,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: kPrestoOrange,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: const Text(
                      'iliprestō',
                      style: TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Trouvez un prestataire\nillico presto!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 46),
                  SizedBox(
                    width: 260,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 2),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () =>
                          _navigateTo(const HomePage(initialIndex: 2)),
                      child: const Text(
                        "J’offre un job",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 260,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 8),
                        backgroundColor: kPrestoBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () => _navigateTo(const ConsultOffersPage()),
                      child: const Text(
                        "Je consulte les offres",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
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
}

/// HOME ////////////////////////////////////////////////////////////////////

class HomePage extends StatefulWidget {
  final int initialIndex;
  const HomePage({super.key, this.initialIndex = 0});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late int _selectedIndex;
  final PageController _carouselController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentSlide = 0;

  Timer? _homeAutoSlideTimer;
  Timer? _presenceTimer;
  bool _carouselEnabled = false;
  bool _showBottomBar = true;
  double _lastScrollPosition = 0;
  bool _wasKeyboardVisible = false;

  late final AnimationController _categoryController;

  // Taille de police de référence pour les titres des slides (alignée sur le slide 1)
  static const double _homeSlideTitleFontSize = 24;

  bool _isSeeding = false;

  /// Contrôle l'affichage des suggestions de recherche
  bool _showSearchSuggestions = true;

  /// Stream figé pour éviter le clignotement des "Dernières offres"
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _latestOffersStream;

  /// Slogans animés (fade + slide) pour le 1er slide
  final List<String> _firstSlideSlogans = const [
    "Trouvez immédiatement quelqu’un pour faire le job.",
    "Une personne disponible près de chez vous.",
    "Publiez… ils arrivent aussitôt.",
  ];
  int _sloganIndex = 0;
  Timer? _sloganTimer;

  /// Mots-clés statiques
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

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _dynamicKeywordsSubscription;

  /// Suggestions “smart” par défaut
  final List<String> _trendingSuggestions = const [
    "Jardinage aujourd’hui",
    "Serveur ce soir",
    "Peinture urgent",
    "Jardinage Petit-Bourg demain",
  ];

  /// Slides d’accueil
  final List<_HomeSlide> _slides = const [
    _HomeSlide(
      title: "Trouvez immédiatement quelqu’un pour faire le job.",
      subtitle: "Carte des personnes disponibles en quelques secondes.",
      badge: "Disponible",
      // plus d'image chrono ici
      imageAsset: null,
    ),
    _HomeSlide(
      title: "Boîte à outils de l'entrepreneur",
      subtitle: "Liens utiles CCI, Région, aides et infos clés.",
      badge: "Pro",
      icon: Icons.business_center_outlined,
    ),
    _HomeSlide(
      title: "iliprestō",
      subtitle: "Qui sommes-nous ? Mentions légales, confidentialité, CGU.",
      badge: "Infos",
      icon: Icons.info_outline,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _selectedIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);

    _touchPresence();
    _presenceTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _touchPresence();
    });

    // À l'arrivée sur l'accueil: on laisse le slide texte visible 4s,
    // puis on lance le carousel et sa rotation.
    if (_selectedIndex == 0) {
      _homeAutoSlideTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        if (!_carouselController.hasClients) return;
        setState(() {
          _carouselEnabled = true;
        });
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
    )..repeat();

    if (_firstSlideSlogans.length > 1) {
      _sloganTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        setState(() {
          _sloganIndex = (_sloganIndex + 1) % _firstSlideSlogans.length;
        });
      });
    }

    _listenDynamicKeywords();

    _latestOffersStream = FirebaseFirestore.instance
        .collection('offers')
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots();

    // Listener pour hide/show bottom bar au scroll
    _scrollController.addListener(() {
      _onPageScroll(_scrollController.offset);
    });
  }

  Future<void> _touchPresence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // best-effort
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _touchPresence();
    }
  }

  void _onPageScroll(double offset) {
    final isScrollingDown = offset > _lastScrollPosition;

    if (isScrollingDown && _showBottomBar) {
      setState(() => _showBottomBar = false);
    } else if (!isScrollingDown && !_showBottomBar) {
      setState(() => _showBottomBar = true);
    }

    _lastScrollPosition = offset;
  }

  void _listenDynamicKeywords() {
    _dynamicKeywordsSubscription?.cancel();

    // Important perf: ne pas écouter toute la collection `offers`.
    // On se limite aux dernières offres pour alimenter des suggestions utiles,
    // sans déclencher des rebuilds massifs quand la collection grossit.
    _dynamicKeywordsSubscription = FirebaseFirestore.instance
        .collection('offers')
        .where(
          'createdAt',
          isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(0),
        )
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen(
      (snapshot) {
        final words = <String>{};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final title = (data['title'] ?? '').toString().toLowerCase();
          final description =
              (data['description'] ?? '').toString().toLowerCase();
          final combined = '$title $description';
          for (final word in combined.split(RegExp(r'\s+'))) {
            if (word.length > 3 &&
                !RegExp(r'[0-9]').hasMatch(word) &&
                !word.startsWith('0')) {
              words.add(word);
            }
          }
        }

        final next = words.toList()..sort();

        if (!mounted) return;
        if (listEquals(_dynamicKeywords, next)) return;

        setState(() {
          _dynamicKeywords = next;
        });
      },
      onError: (e) {
        debugPrint('Dynamic keywords stream error: $e');
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _carouselController.dispose();
    _scrollController.dispose();
    _categoryController.dispose();
    _sloganTimer?.cancel();
    _homeAutoSlideTimer?.cancel();
    _presenceTimer?.cancel();
    _dynamicKeywordsSubscription?.cancel();
    super.dispose();
  }

  /// Force rebuild quand le clavier apparaît/disparaît
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    
    // Utiliser View.of(context) au lieu de l'API window deprecated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      try {
        final isKeyboardVisible = View.of(context).viewInsets.bottom > 0;
        
        // Détecter les changements de visibilité du clavier
        if (_wasKeyboardVisible != isKeyboardVisible) {
          // Le clavier vient de se fermer : restaurer la bottomBar
          if (!isKeyboardVisible) {
            setState(() {
              _showBottomBar = true;
            });
          }
          // Le clavier vient de s'ouvrir : on peut optionnellement cacher la bottom bar
          // (actuellement géré par isKeyboardVisible dans le build)
        }
        
        _wasKeyboardVisible = isKeyboardVisible;
      } catch (e) {
        // Fallback si View.of(context) n'est pas disponible
        debugPrint('didChangeMetrics error: $e');
      }
    });
  }

  /// Animation "bump" séquentielle sur les 6 catégories
  double _categoryScaleForIndex(int index) {
    const count = 6;
    final t = _categoryController.value * count;
    final active = t.floor() % count;
    final localT = t - t.floor();
    if (index == active) {
      return 1.0 + 0.25 * (1 - (localT - 0.5) * (localT - 0.5) * 4);
    }
    return 1.0;
  }

  void _onBottomTap(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  void _goToSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConsultOffersPage(searchQuery: q),
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

      // Compat legacy : certaines vues utilisent encore `location` / `postalCode`.
      // On les remplit à partir de `city` / `cp` si absents.
      final fs = FirebaseFirestore.instance;
      final col = fs.collection(kOffersCollection);
      final snap = await col.get();

      WriteBatch batch = fs.batch();
      int ops = 0;
      Future<void> commitIfNeeded() async {
        if (ops == 0) return;
        await batch.commit();
        batch = fs.batch();
        ops = 0;
      }

      for (final doc in snap.docs) {
        final data = doc.data();
        final city = (data['city'] ?? '').toString();
        final cp = (data['cp'] ?? '').toString();

        final needsLocation =
            !(data.containsKey('location')) || (data['location'] == null);
        final needsPostalCode =
            !(data.containsKey('postalCode')) || (data['postalCode'] == null);

        if (!needsLocation && !needsPostalCode) continue;
        if (city.isEmpty && cp.isEmpty) continue;

        final patch = <String, dynamic>{};
        if (needsLocation && city.isNotEmpty) patch['location'] = city;
        if (needsPostalCode && cp.isNotEmpty) patch['postalCode'] = cp;

        if (patch.isEmpty) continue;

        batch.set(doc.reference, patch, SetOptions(merge: true));
        ops++;
        if (ops >= 450) {
          await commitIfNeeded();
        }
      }
      await commitIfNeeded();

      if (mounted) {
        showSuccessSnackBar(context, "Offres de test réinitialisées et injectées ✅");
      }
    } catch (e) {
      if (mounted) {
        showSuccessSnackBar(context, "Erreur lors du seed des offres : $e");
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  String _labelWhenFromTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('urgent')) return 'urgent';
    if (lower.contains('ce soir')) return 'ce soir';
    if (lower.contains('demain')) return 'demain';
    return 'bientôt';
  }

  Widget _buildSmartSearchBar() {
    TextEditingController? searchController;
    FocusNode? searchFocusNode;

    void selectSuggestion(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;

      searchController?.text = trimmed;
      searchController?.selection =
          TextSelection.collapsed(offset: trimmed.length);

      setState(() => _showSearchSuggestions = false);
      searchFocusNode?.unfocus();

      _goToSearch(trimmed);
    }

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        if (!_showSearchSuggestions) return const Iterable<String>.empty();
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
                fontSize: 13,
                color: Colors.black45,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              prefixIcon: const Icon(
                Icons.search,
                color: kPrestoBlue,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 18),
                color: kPrestoOrange,
                onPressed: () => _goToSearch(textEditingController.text),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
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
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  final highlightedIndex =
                      AutocompleteHighlightedOption.of(context);
                  final isHighlighted = index == highlightedIndex;
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(
                      option,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    tileColor:
                        isHighlighted ? kPrestoBlue.withOpacity(0.08) : null,
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
  Widget _buildNotificationBell() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        // Non connecté → cloche simple
        if (user == null) {
          return _TapScale(
            onTap: () {
              showSuccessSnackBar(
                context,
                "Connecte-toi à ton compte pour recevoir les notifications de nouveaux messages et annonces.",
              );
            },
            child: const _NotificationBellBase(badgeCount: 0),
          );
        }

        // Connecté → on compte les messages non lus ET les notifications non lues
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('conversations')
              .where('participants', arrayContains: user.uid)
              .snapshots(),
          builder: (context, convSnapshot) {
            int unreadMessagesCount = 0;

            if (convSnapshot.hasData) {
              for (final doc in convSnapshot.data!.docs) {
                final data = doc.data();
                final unreadMap =
                    (data['unreadCount'] as Map<String, dynamic>?) ?? {};
                final v = unreadMap[user.uid];
                if (v is int) unreadMessagesCount += v;
              }
            }

            // On compte aussi les notifications d'offres non lues
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: user.uid)
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, notifSnapshot) {
                int unreadNotificationsCount = 0;

                if (notifSnapshot.hasData) {
                  unreadNotificationsCount = notifSnapshot.data!.docs.length;
                }

                final totalUnread =
                    unreadMessagesCount + unreadNotificationsCount;

                return _TapScale(
                  onTap: () {
                    // Afficher une page de notifications ou aller aux messages
                    _showNotificationsDialog(context, user.uid);
                  },
                  child: _NotificationBellBase(badgeCount: totalUnread),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Affiche un dialogue avec les notifications récentes
  void _showNotificationsDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Notifications',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: userId)
                .orderBy('createdAt', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final notifications = snapshot.data!.docs;

              if (notifications.isEmpty) {
                return const Text(
                  'Aucune notification pour le moment.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  final data = notif.data();
                  final title = data['title'] as String? ?? '';
                  final message = data['message'] as String? ?? '';
                  final isRead = data['read'] as bool? ?? false;
                  final offerId = data['offerId'] as String?;

                  return ListTile(
                    leading: Icon(
                      Icons.announcement,
                      color: isRead ? Colors.grey : Colors.green,
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isRead ? Colors.grey.shade700 : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      message,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isRead ? Colors.grey.shade600 : Colors.grey.shade800,
                      ),
                    ),
                    onTap: () async {
                      // Marquer comme lue
                      if (!isRead) {
                        await FirebaseFirestore.instance
                            .collection('notifications')
                            .doc(notif.id)
                            .update({'read': true});
                      }

                      // Naviguer vers l'offre si disponible
                      if (offerId != null && context.mounted) {
                        Navigator.of(context).pop();
                        // Ouvrir la page ConsultOffersPage avec un filtre sur cette offre
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ConsultOffersPage(),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Marquer toutes comme lues
              final batch = FirebaseFirestore.instance.batch();
              final notifs = await FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: userId)
                  .where('read', isEqualTo: false)
                  .get();

              for (final doc in notifs.docs) {
                batch.update(doc.reference, {'read': true});
              }

              await batch.commit();

              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Tout marquer comme lu'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Icône d'information pour accéder aux pages légales
  Widget _buildInfoIcon() {
    // Icône supprimée sur la page d'accueil (on garde juste l'espace pour l'alignement).
    return const SizedBox(width: 40, height: 40);
  }

  /// Illustration à droite du slide (plus de chrono image)
  Widget _buildSlideIllustration(
    _HomeSlide slide,
    int index, {
    VoidCallback? onTap,
  }) {
    // On ignore complètement slide.imageAsset, on affiche juste une icône
    final child = Container(
      width: 70,
      height: 70,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(
        slide.icon ?? Icons.flash_on,
        color: kPrestoBlue,
        size: 32,
      ),
    );

    if (onTap == null) return child;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: prestoOverlayStyleFor(kPrestoBlue),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          extendBody: true, // Permettre au contenu de s'étendre sous la bottom bar
          backgroundColor: Colors.white, // Fond blanc pour éviter le bandeau beige
          body: SafeArea(
            bottom: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Stack(
                children: [
                  IndexedStack(
                    index: _selectedIndex,
                    children: [
                      _buildHomeContent(),
                      ConsultOffersPage(onScroll: _onPageScroll),
                      PublishOfferPage(onScroll: _onPageScroll),
                      const MessagesPage(),
                      AccountPage(onScroll: _onPageScroll),
                    ],
                  ),
                  if (!isKeyboardVisible)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        offset:
                            _showBottomBar ? Offset.zero : const Offset(0, 1),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: kPrestoOrange,
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                          child: SafeArea(
                            top: false,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _BottomNavItem(
                                    icon: Icons.home,
                                    label: "Accueil",
                                    selected: _selectedIndex == 0,
                                    onTap: () => _onBottomTap(0),
                                  ),
                                ),
                                Expanded(
                                  child: _BottomNavItem(
                                    icon: Icons.search,
                                    label: "Je consulte\nles offres",
                                    selected: _selectedIndex == 1,
                                    onTap: () => _onBottomTap(1),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: _BottomNavItem(
                                    icon: Icons.add_circle_outline,
                                    label: "Publier\nune offre",
                                    isBig: true,
                                    onTap: () => _onBottomTap(2),
                                  ),
                                ),
                                Expanded(
                                  child: _BottomNavItem(
                                    icon: Icons.chat_bubble_outline,
                                    label: "Messages",
                                    selected: _selectedIndex == 3,
                                    onTap: () => _onBottomTap(3),
                                  ),
                                ),
                                Expanded(
                                  child: _BottomNavItem(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final double bottomPadding = (isKeyboardVisible || !_showBottomBar) ? 16 : 100;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(10, 8, 10, bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ligne du haut : info + logo + cloche
                Row(
                  children: [
                    _buildInfoIcon(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onLongPress: _seedSampleOffers,
                        child: const Center(
                          child: Text(
                            "iliprestō",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: kPrestoOrange,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildNotificationBell(),
                  ],
                ),

                const SizedBox(height: 8),

                _buildSmartSearchBar(),

                const SizedBox(height: 14),

                // SLIDER
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _carouselController,
                        itemCount: _slides.length + 1,
                        onPageChanged: (index) {
                          setState(() {
                            _currentSlide = index;
                            if (index == 1) {
                              _carouselEnabled = true;
                            }
                          });
                        },
                        itemBuilder: (context, index) {
                          // Ordre voulu:
                          // 0 = slide texte (fixe 4s)
                          // 1 = carousel d'images (démarre après 4s)
                          // 2.. = slides existants

                          if (index == 1) {
                            return Container(
                              height: double.infinity,
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(horizontal: 0),
                              padding: const EdgeInsets.symmetric(vertical: 0),
                              decoration: BoxDecoration(
                                color: kPrestoOrange,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: SizedBox.expand(
                                  child: RepaintBoundary(
                                    child: RandomAssetTicker(
                                      folderPrefix: 'assets/carousel_home/',
                                      interval: const Duration(seconds: 3),
                                      antiRepeatWindow: 3,
                                      fit: BoxFit.cover,
                                      enabled: _carouselEnabled,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          final slideIndex = index == 0 ? 0 : index - 1;
                          final slide = _slides[slideIndex];

                          // 🔥 SLIDE 1 : plein texte, sans image, phrase géante sur toute la largeur
                          if (slideIndex == 0) {
                            const String bigText =
                                "Trouvez immédiatement quelqu'un pour faire le job !";

                            return Container(
                              height: double.infinity,
                              margin: const EdgeInsets.symmetric(horizontal: 0),
                              decoration: BoxDecoration(
                                color: kPrestoOrange,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 18,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      "DISPONIBLE",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    // ✅ Phrase principale en très gros sur toute la largeur
                                    Text(
                                      bigText,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize:
                                            _homeSlideTitleFontSize, // taille bien grosse
                                        fontWeight: FontWeight.w900,
                                        height: 1.25,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      "Une personne disponible près de chez vous, en quelques minutes.",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // ✅ SLIDE 2 (index 1) : Boîte à outils de l'entrepreneur
                          if (slideIndex == 1) {
                            return const EntrepreneurToolboxSlide();
                          }

                          // 🔁 SLIDES 2, 3, 4 : layout texte + icône / image
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
                            margin: const EdgeInsets.symmetric(horizontal: 0),
                            decoration: BoxDecoration(
                              color: kPrestoOrange,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.10),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: _homeSlideTitleFontSize,
                                            fontWeight: FontWeight.w900,
                                            height: 1.25,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          slide.subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
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
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );

                          if (onSlideTap == null) return slideBody;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
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
                            _slides.length + 1,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _currentSlide == index ? 16 : 8,
                              height: 7,
                              decoration: BoxDecoration(
                                color: _currentSlide == index
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // CATEGORIES COMPACTES
                AnimatedBuilder(
                  animation: _categoryController,
                  builder: (context, child) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _CategoryChip(
                            icon: Icons.eco_outlined,
                            label: "Jardinage",
                            iconScale: _categoryScaleForIndex(0),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ConsultOffersPage(
                                    categoryFilter: "Jardinage",
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          _CategoryChip(
                            icon: Icons.format_paint_outlined,
                            label: "Peinture",
                            iconScale: _categoryScaleForIndex(1),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ConsultOffersPage(
                                    categoryFilter: "Peinture",
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          _CategoryChip(
                            icon: Icons.handyman_outlined,
                            label: "Main-d’œuvre",
                            iconScale: _categoryScaleForIndex(2),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ConsultOffersPage(
                                    categoryFilter: "Main-d’œuvre",
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          _CategoryChip(
                            icon: Icons.other_houses_outlined,
                            label: "Autres",
                            iconScale: _categoryScaleForIndex(3),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ConsultOffersPage(
                                    categoryFilter: "Autre",
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          _CategoryChip(
                            icon: Icons.child_care_outlined,
                            label: "Garde enfants",
                            iconScale: _categoryScaleForIndex(4),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ConsultOffersPage(
                                    categoryFilter: "Garde d’enfants",
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          _CategoryChip(
                            icon: Icons.music_note_outlined,
                            label: "DJ / Sono",
                            iconScale: _categoryScaleForIndex(5),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ConsultOffersPage(
                                    categoryFilter: "Événementiel / DJ",
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),

                // COMMENT ÇA MARCHE
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Comment ça marche ?",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kPrestoBlue,
                        ),
                      ),
                      SizedBox(height: 8),
                      _HowItWorksStep(
                        stepNumber: 1,
                        title: "Je publie une offre",
                        description:
                            "En quelques lignes, vous décrivez votre besoin et votre lieu.",
                      ),
                      SizedBox(height: 6),
                      _HowItWorksStep(
                        stepNumber: 2,
                        title: "Mon offre est diffusée instantanément",
                        description:
                            "Les prestataires proches sont notifiés et voient immédiatement votre offre.",
                      ),
                      SizedBox(height: 6),
                      _HowItWorksStep(
                        stepNumber: 3,
                        title: "Ils me contactent aussitôt",
                        description:
                            "Vous échangez et choisissez la personne idéale pour le job.",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // DERNIÈRES OFFRES - Section avec fond blanc
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Dernières offres",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _onBottomTap(1),
                            child: const Text(
                              "Voir tout",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kPrestoBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _latestOffersStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(kPrestoOrange),
                                ),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return const SizedBox.shrink();
                          }

                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return const Text(
                              "Aucune offre publiée pour le moment.",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }

                          return Column(
                            children: docs.map((d) {
                              final data = d.data();
                              final title = (data['title'] ?? 'Sans titre') as String;
                              final location =
                                  (data['location'] ?? 'Lieu non précisé') as String;
                              final whenLabel = _labelWhenFromTitle(title);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _TapScale(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => OfferDetailPage(
                                          offerId: d.id,
                                          title: title,
                                          location: location,
                                          category: (data['category'] ??
                                              'Catégorie non précisée') as String,
                                          subcategory: data['subcategory'] as String?,
                                          budget: data['budget'] is num
                                              ? data['budget'] as num
                                              : null,
                                          description:
                                              (data['description'] ?? '') as String?,
                                          phone: data['phone'] as String?,
                                          imageUrls:
                                              (data['imageUrls'] as List<dynamic>?)
                                                  ?.map((e) => e.toString())
                                                  .toList(),
                                          annonceurId:
                                              (data['userId'] ?? '') as String,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF3E0),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.flash_on_outlined,
                                            color: kPrestoOrange,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "$location — $whenLabel",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.chevron_right,
                                          size: 18,
                                          color: Colors.black38,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SLIDE MODEL
class _HomeSlide {
  final String title;
  final String subtitle;
  final String badge;
  final IconData? icon;
  final String? imageAsset;

  const _HomeSlide({
    required this.title,
    required this.subtitle,
    required this.badge,
    this.icon,
    this.imageAsset,
  });
}

/// EFFET SCALE SUR TAP
class _TapScale extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _TapScale({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 120),
        child: child,
      ),
    );
  }
}

/// CHIPS / CARDS ///////////////////////////////////////////////////////////

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double iconScale;

  const _CategoryChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      onTap: onTap ??
          () {
            showSuccessSnackBar(
              context,
              'Catégorie "$label" : bientôt disponible',
            );
          },
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: kPrestoOrange,
              shape: BoxShape.circle,
              border: Border.all(
                color: kPrestoBlue,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Transform.scale(
                scale: iconScale,
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 90,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

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

class _BottomNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isBig;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.isBig = false,
  });

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_BottomNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jouer l'animation quand sélectionné
    if (widget.selected && !oldWidget.selected) {
      _controller.forward().then((_) {
        if (mounted) {
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = Colors.white;
    final fontWeight = widget.selected ? FontWeight.w700 : FontWeight.w500;

    return _TapScale(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: EdgeInsets.all(widget.isBig ? 6 : 4),
                decoration: BoxDecoration(
                  color: widget.isBig
                      ? Colors.white
                      : widget.selected
                          ? Colors.white.withOpacity(0.35)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: widget.isBig
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : widget.selected
                          ? [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 3,
                              ),
                            ]
                          : null,
                ),
                child: Icon(
                  widget.icon,
                  size: widget.isBig ? 28 : 24,
                  color: widget.isBig ? kPrestoOrange : color,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: 70,
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: fontWeight,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cloche de notifications avec badge dynamique /////////////////////////////

class _NotificationBellBase extends StatelessWidget {
  final int badgeCount;

  const _NotificationBellBase({required this.badgeCount});

  @override
  Widget build(BuildContext context) {
    final String? label;
    if (badgeCount <= 0) {
      label = null;
    } else if (badgeCount > 9) {
      label = "9+";
    } else {
      label = badgeCount.toString();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.notifications_none_outlined,
            size: 22,
            color: Colors.black87,
          ),
        ),
        if (label != null)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// BLOC COMMENT ÇA MARCHE /////////////////////////////////////////////////

class _HowItWorksStep extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String description;

  const _HowItWorksStep({
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: kPrestoOrange,
            child: Text(
              stepNumber.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// PAGE "JE CONSULTE LES OFFRES" ///////////////////////////////////////////

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

class _ConsultOffersPageState extends State<ConsultOffersPage> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  // ignore: unused_field
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _keywordCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();

  int _filterPanelKey = 0;
  int _queryKey = 0; // Force le StreamBuilder à se reconstruire

  String? _selectedCategory;
  String? _selectedRegionCode;
  String? _selectedSubCategory;

  final _Debouncer _filterDebounce =
      _Debouncer(delay: const Duration(milliseconds: 300));

  String? _filterCategory;
  String? _filterRegionCode;
  String? _filterDepartmentCode;
  String? _filterCityName;

  // Pagination / loading state
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _isLoading = false;

  /// Mot-clé actif appliqué aux résultats (initialisé depuis searchQuery, réinitialisable)
  String? _activeSearchQuery;

  // Variables pour l'autocomplétion de ville dans les filtres
  final TextEditingController _filterCityController = TextEditingController();
  final TextEditingController _filterPostalCodeController =
      TextEditingController();
  final FocusNode _regionFocus = FocusNode();
  final FocusNode _deptFocus = FocusNode();
  final FocusNode _filterCityFocusNode = FocusNode();
  // ignore: unused_field
  List<CityRecord> _filterCitySuggestions = [];
  // ignore: unused_field
  int _filterCityHighlightedIndex = -1;
  Timer? _filterCityDebounce;

  final ScrollController _scrollController = ScrollController();

  bool _showFilters = false; // Panneau de filtres rétracté au départ

  late final Map<String, String> _deptToRegion = _buildDeptToRegion();

  String _normalizeForCategoryMatch(String input) {
    return input
        .trim()
        .toLowerCase()
        // diacritiques courants FR
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('ç', 'c')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('œ', 'oe')
        // séparateurs usuels
        .replaceAll('/', ' ')
        .replaceAll('-', ' ')
        .replaceAll('’', ' ')
        .replaceAll("'", ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _matchKnownCategory(String input) {
    final q = _normalizeForCategoryMatch(input);
    if (q.isEmpty) return null;

    String? best;
    int bestScore = -1;

    for (final c in kCategories) {
      final cn = _normalizeForCategoryMatch(c);
      int score = -1;

      if (cn == q) {
        score = 10000;
      } else if (cn.contains(q) && q.length >= 2) {
        score = 5000 + q.length;
      } else if (q.contains(cn) && cn.length >= 2) {
        score = 3000 + cn.length;
      }

      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }

    return bestScore > 0 ? best : null;
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

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      widget.onScroll?.call(_scrollController.offset);
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
    }

    // Quand le code postal change, on essaie de déduire la région
    _postalCodeController.addListener(_syncRegionWithPostalCode);

    // Synchroniser la ville sélectionnée (si déjà connue) dans le champ visible
    _filterCityController.addListener(_syncLocationFieldFromFilter);
    _syncLocationFieldFromFilter();
  }

  @override
  void dispose() {
    _filterDebounce.dispose();
    _locationController.dispose();
    _postalCodeController.dispose();
    _scrollController.dispose();
    _filterCityController.dispose();
    _filterPostalCodeController.dispose();
    _filterCityFocusNode.dispose();
    _filterCityDebounce?.cancel();
    _keywordCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('offers');

    bool hasFilter = false;

    final loc = _locationController.text.trim();
    final cp = _postalCodeController.text.trim();
    final cat = _selectedCategory;
    final regionCode = _selectedRegionCode;
    final subcat = _selectedSubCategory;

    // Nouveaux filtres du panneau
    final filterCat = _filterCategory;
    final filterRegCode = _filterRegionCode;
    final filterDeptCode = _filterDepartmentCode;
    final filterCity = _filterCityName?.trim();

    // Filtre catégorie (panneau de filtres prioritaire)
    if (filterCat != null && filterCat.isNotEmpty) {
      hasFilter = true;
      query = query.where('category', isEqualTo: filterCat);
    } else if (cat != null && cat.isNotEmpty && cat != 'Toutes catégories') {
      hasFilter = true;
      query = query.where('category', isEqualTo: cat);
    }

    // Filtre région (par code région)
    if (filterRegCode != null && filterRegCode.isNotEmpty) {
      hasFilter = true;
      final regionName = kRegions[filterRegCode];
      if (regionName != null) {
        query = query.where('region', isEqualTo: regionName);
      }
    } else if (regionCode != null && regionCode.isNotEmpty) {
      hasFilter = true;
      final regionName = kRegions[regionCode];
      if (regionName != null) {
        query = query.where('region', isEqualTo: regionName);
      }
    }

    // Filtre département (par code département)
    if (filterDeptCode != null && filterDeptCode.isNotEmpty) {
      hasFilter = true;
      query = query.where('departmentCode', isEqualTo: filterDeptCode);
    }

    // Filtre ville (panneau de filtres prioritaire)
    if (filterCity != null && filterCity.isNotEmpty) {
      hasFilter = true;
      query = query.where('location', isEqualTo: filterCity);
    } else if (loc.isNotEmpty) {
      hasFilter = true;
      query = query.where('location', isEqualTo: loc);
    }

    // Code postal
    if (cp.isNotEmpty) {
      hasFilter = true;
      query = query.where('postalCode', isEqualTo: cp);
    }

    // Sous-catégorie
    if (subcat != null && subcat.isNotEmpty) {
      hasFilter = true;
      query = query.where('subcategory', isEqualTo: subcat);
    }

    if (!hasFilter) {
      query = query.orderBy('createdAt', descending: true);
    }

    return query;
  }

  // ignore: unused_element
  Future<void> _fetchOffers({bool resetPaging = false}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    if (resetPaging) {
      _lastDoc = null;
      // Si tu stockes une liste d'offres en mémoire : offers.clear();
    }

    try {
      var query = _buildQuery();

      // Exemple de pagination si besoin
      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      // Charge une première page (adapter la limite si besoin)
      final snap = await query.limit(20).get();

      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
      }

      // Si tu conserves les résultats : setState(() => offers = ...);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erreur lors du chargement des offres: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    // Annule le debounce en cours pour éviter les conflits
    _filterDebounce._t?.cancel();

    // Remonter en haut de la liste
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Force le StreamBuilder à se reconstruire
    setState(() {
      _activeSearchQuery =
          _keywordCtrl.text.trim().isEmpty ? null : _keywordCtrl.text.trim();
      _queryKey++;
      _lastDoc = null; // Reset pagination
      _showFilters = false; // ✅ Rétracter le panneau après application des filtres
    });
  }

  void _onAnyFilterChanged() {
    // ✅ Auto-apply avec debounce
    _filterDebounce.run(() {
      _applyFilters();
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
      _filterPanelKey++; // Force la reconstruction du panneau
      _queryKey++; // Force la reconstruction du StreamBuilder
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

    // 4) remonte la liste
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // 5) ✅ Pas besoin de _fetchOffers car le StreamBuilder se reconstruit automatiquement
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
    // Compter les filtres actifs
    int activeFiltersCount = 0;
    if (_filterCategory != null && _filterCategory!.isNotEmpty) activeFiltersCount++;
    if (_filterRegionCode != null && _filterRegionCode!.isNotEmpty) activeFiltersCount++;
    if (_filterDepartmentCode != null && _filterDepartmentCode!.isNotEmpty) activeFiltersCount++;
    if (_filterCityName != null && _filterCityName!.isNotEmpty) activeFiltersCount++;
    if (_activeSearchQuery != null && _activeSearchQuery!.isNotEmpty) activeFiltersCount++;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _showFilters = !_showFilters);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: activeFiltersCount > 0 
                      ? kPrestoOrange.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: activeFiltersCount > 0 ? kPrestoOrange : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _showFilters ? Icons.filter_list_off : Icons.filter_list,
                      size: 22,
                      color: activeFiltersCount > 0 ? kPrestoOrange : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _showFilters ? 'Masquer les filtres' : 'Filtres',
                        style: TextStyle(
                          color: activeFiltersCount > 0 ? kPrestoOrange : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (activeFiltersCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kPrestoOrange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$activeFiltersCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          _resetFilters();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: kPrestoOrange,
                          ),
                        ),
                      ),
                    ],
                  ],
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
    final baseTitle = widget.categoryFilter == null
        ? "Je consulte les offres"
        : "Offres : ${widget.categoryFilter!}";

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        // Fond blanc derrière les annonces pour un look plus clair
        backgroundColor: Colors.white,
        appBar: AppBar(
        systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            baseTitle,
            style: kPrestoAppBarTitleStyle,
          ),
        ),
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
        body: Column(
          children: [
            // ✅ Tuiles cliquables pour filtres actifs
            _buildActiveFilterChips(),
            _buildFilterPanel(),
            Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              key: ValueKey(
                  _queryKey), // Force la reconstruction quand les filtres changent
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                // ✅ Ne plus afficher le loader si on a déjà des données
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        "Erreur lors du chargement des offres.\n${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }

                List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                    snapshot.data?.docs ?? [];

                if (_activeSearchQuery != null &&
                    _activeSearchQuery!.trim().isNotEmpty) {
                  final q = _activeSearchQuery!.trim().toLowerCase();
                  docs = docs.where((d) {
                    final data = d.data();
                    final title =
                        (data['title'] ?? '').toString().toLowerCase();
                    final desc =
                        (data['description'] ?? '').toString().toLowerCase();
                    return title.contains(q) || desc.contains(q);
                  }).toList();
                }

                // Nombre après filtrage
                final int resultCount = docs.length;

                if (docs.isEmpty) {
                  return Column(
                    children: [
                      // Compteur d'annonces
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.list_alt, size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              '0 annonce',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Expanded(child: _EmptyOffers()),
                    ],
                  );
                }

                const int _adsEvery = 8; // Bandeau pub après chaque 8 annonces
                final int _adSlots = docs.length ~/ _adsEvery;
                final int _totalItems = docs.length + _adSlots;

                return Column(
                  children: [
                    // Compteur d'annonces
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.list_alt, size: 18, color: kPrestoOrange),
                          const SizedBox(width: 8),
                          Text(
                            '$resultCount annonce${resultCount > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(2, 16, 2, 120),
                        itemCount: _totalItems,
                        itemBuilder: (context, index) {
                          final bool isAd = (index + 1) % (_adsEvery + 1) == 0;
                          if (isAd) {
                            return AdBanner(
                              margin: EdgeInsets.zero,
                              placeholderHeight: kIsWeb ? 180.0 : 100.0,
                              placeholderFolderPrefix: 'assets/carousel_home/',
                              flat: true,
                            );
                          }

                          final int docIndex = index - (index ~/ (_adsEvery + 1));
                          final doc = docs[docIndex];
                          final offerId = doc.id;
                          final data = doc.data();

                          final title = (data['title'] ?? 'Sans titre') as String;
                          final location =
                              (data['location'] ?? 'Lieu non précisé') as String;
                          final category = (data['category'] ??
                              'Catégorie non précisée') as String;
                          final budget = data['budget'];
                          final description = (data['description'] ?? '') as String;
                          final phone =
                              data['phone'] == null ? null : data['phone'] as String;

                          final List<String> imageUrls =
                              (data['imageUrls'] as List<dynamic>? ?? [])
                                  .map((e) => e.toString())
                                  .toList();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => OfferDetailPage(
                                offerId: offerId,
                                title: title,
                                location: location,
                                category: category,
                                subcategory:
                                    (data['subcategory'] ?? '') as String?,
                                budget: budget is num ? budget : null,
                                description:
                                    description.isEmpty ? null : description,
                                phone: phone,
                                imageUrls: imageUrls.isEmpty ? null : imageUrls,
                                annonceurId: (data['userId'] ?? '') as String,
                              ),
                            ),
                          );
                        },
                        child: OfferCard(
                          offerId: offerId,
                          data: data,
                          showActionsMenu: false,
                        ),
                      ),
                    );
                  },
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
    );
  }

  Widget _buildFilterPanel() {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 220),
      crossFadeState:
          _showFilters ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: Form(
        key: ValueKey(_filterPanelKey),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(16),
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
                      child: const Text('Réinitialiser'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _applyFilters,
                      icon: const Icon(Icons.search),
                      label: const Text('Rechercher'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrestoBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
        value: _filterRegionCode,
        isDense: true,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(14),
        decoration: const InputDecoration(
          labelText: "Région",
          isDense: true,
        ),
        items: <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(
            value: null,
            child: Text("Toutes régions"),
          ),
          ...kRegionsOrdered.map((r) => DropdownMenuItem<String?>(
                value: r.code,
                child: Text(r.name),
              )),
        ],
        onChanged: (code) {
          setState(() {
            _filterRegionCode = code;

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
    if (_filterDepartmentCode != null && safeValue == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_filterDepartmentCode == null) return;

        final stillInvalid = !allowedCodes.contains(_filterDepartmentCode);
        if (!stillInvalid) return;

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
        value: safeValue,
        isDense: true,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(14),
        decoration: InputDecoration(
          labelText: 'Département',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              // ✅ Tous départements => reset ville + CP
              _filterCityController.clear();
              _filterPostalCodeController.clear();
              _filterCityName = null;
              _filterCitySuggestions = [];
              _filterCityHighlightedIndex = -1;
            }
          });

          _onAnyFilterChanged(); // ✅ auto-apply

          // Passe au champ ville
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FocusScope.of(context).requestFocus(_filterCityFocusNode);
          });
        },
      ),
    );
  }

  // Méthodes pour la gestion de l'autocomplétion de ville dans les filtres
  List<CityRecord> _searchCities(String q) {
    final allowed = _allowedDeptCodesForCity;
    return CitySearch.instance.search(
      q,
      limit: 20,
      allowedDeptCodes: allowed,
    );
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
        final surface = Theme.of(context).colorScheme.surface;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  final highlightedIndex =
                      AutocompleteHighlightedOption.of(context);
                  final isHighlighted = index == highlightedIndex;

                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(
                      '${option.name} (${option.cp})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    tileColor:
                        isHighlighted ? kPrestoBlue.withOpacity(0.08) : null,
                    onTap: () => onSelected(option),
                  );
                },
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
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _filterCityController.clear();
                        _filterPostalCodeController.clear();
                        _filterCityName = null;
                        _filterCitySuggestions = [];
                        _filterCityHighlightedIndex = -1;
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
      value: _filterCategory,
      isDense: true,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(14),
      decoration: const InputDecoration(
        labelText: 'Catégorie',
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('Toutes les catégories'),
        ),
        ...kCategories.map(
          (c) => DropdownMenuItem(
            value: c,
            child: Text(c),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _filterCategory = value;
        });
        _onAnyFilterChanged();
      },
    );
  }

  // ignore: unused_element
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

  // ignore: unused_element
  Future<void> _showEditOfferDialog(
    BuildContext context,
    String offerId,
    Map<String, dynamic> data,
  ) async {
    final titleCtrl =
        TextEditingController(text: (data['title'] ?? '').toString());
    final cityCtrl =
        TextEditingController(text: (data['city'] ?? '').toString());
    final descCtrl =
        TextEditingController(text: (data['description'] ?? '').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifier l\'annonce'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Titre')),
              const SizedBox(height: 8),
              TextField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'Ville')),
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
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enregistrer')),
        ],
      ),
    );

    if (ok != true) return;

    await FirebaseFirestore.instance.collection('offers').doc(offerId).update({
      'title': titleCtrl.text.trim(),
      'city': cityCtrl.text.trim(),
      'description': descCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ignore: unused_element
  Future<void> _confirmDeleteOffer(
    BuildContext context,
    String offerId,
    String title,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l\'annonce ?'),
        content: Text('Supprimer : "$title" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer')),
        ],
      ),
    );

    if (yes != true) return;

    await FirebaseFirestore.instance.collection('offers').doc(offerId).delete();
  }
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            const Icon(
              Icons.search_off_outlined,
              size: 56,
              color: Colors.black26,
            ),
            const SizedBox(height: 16),
            const Text(
              "Aucune offre publiée pour le moment",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              "Les annonces peuvent arriver à tout moment.\n⭐ Ajoutez cette catégorie en favori pour être alerté dès qu'une annonce est publiée.\n👤 Créez un compte pour enregistrer vos favoris et activer les notifications.",
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class OfferDetailPage extends StatefulWidget {
  final String title;
  final String location;
  final String category;
  final String? subcategory;
  final num? budget;
  final String? description;
  final String? phone;
  final List<String>? imageUrls;
  final String annonceurId;
  final String offerId;

  const OfferDetailPage({
    super.key,
    required this.title,
    required this.location,
    required this.category,
    this.subcategory,
    this.budget,
    this.description,
    this.phone,
    this.imageUrls,
    required this.annonceurId,
    required this.offerId,
  });

  @override
  State<OfferDetailPage> createState() => _OfferDetailPageState();
}

class _OfferDetailPageState extends State<OfferDetailPage> {
  bool _isPhoneVisible = false;

  String _extractUserPseudo(Map<String, dynamic>? data) {
    if (data == null) return 'Profil';
    final candidates = <String?>[
      data['pseudo']?.toString(),
      data['username']?.toString(),
      data['displayName']?.toString(),
      data['name']?.toString(),
    ];
    for (final v in candidates) {
      final s = (v ?? '').trim();
      if (s.isNotEmpty) return s;
    }
    return 'Profil';
  }

  String _maskPhone(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return raw;

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '••••••••••';

    // Masquage simple: on conserve les 2 premiers chiffres si possible.
    final keep = digits.length >= 2 ? digits.substring(0, 2) : digits;
    return '$keep •• •• •• ••';
  }

  Future<void> _shareOn(BuildContext context, String platform) async {
    final shareText =
        "${widget.title.trim()} – ${widget.location.trim()} | Rejoins Prest'o pour en savoir plus.";
    final shareUrl = Uri.parse('https://prestoo.app/offers');

    final encodedText = Uri.encodeComponent(shareText);
    final encodedUrl = Uri.encodeComponent(shareUrl.toString());

    Uri? uri;
    if (platform == 'whatsapp') {
      uri = Uri.parse('https://wa.me/?text=$encodedText%20$encodedUrl');
    } else if (platform == 'facebook') {
      uri = Uri.parse(
          'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl&quote=$encodedText');
    } else if (platform == 'instagram') {
      // Instagram n'offre pas de partage web direct : on ouvre l'app/web pour laisser l'utilisateur coller le texte.
      uri = Uri.parse('https://www.instagram.com/?text=$encodedText');
    }

    if (uri == null) return;

    try {
      final ok = await canLaunchUrl(uri);
      if (!context.mounted) return;
      if (!ok) {
        showSuccessSnackBar(context, "Partage indisponible sur cet appareil.");
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      showSuccessSnackBar(context, "Impossible de lancer le partage.");
    }
  }

  Future<void> _callPhone(BuildContext context) async {
    if (widget.phone == null || widget.phone!.trim().isEmpty) {
      showSuccessSnackBar(context, "Aucun numéro disponible.");
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: widget.phone!.trim(),
    );

    try {
      final ok = await canLaunchUrl(uri);
      if (!context.mounted) return;

      if (ok) {
        await launchUrl(uri);
        return;
      }

      showSuccessSnackBar(context, "Impossible de lancer l’appel sur cet appareil.");
    } catch (_) {
      if (!context.mounted) return;
      showSuccessSnackBar(context, "Une erreur est survenue lors de l’appel.");
    }
  }

  void _showActionSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isLoggedIn = user != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Text(
                "Que souhaites-tu faire ?",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrestoOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (!isLoggedIn) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccountPage(),
                        ),
                      );
                      return;
                    }

                    // Utilise l'identifiant de l'annonceur passé au détail de l'offre
                    final annonceurId = widget.annonceurId;
                    if (annonceurId.isEmpty) {
                      showSuccessSnackBar(
                        context,
                        "Impossible de retrouver l'annonceur.",
                      );
                      return;
                    }

                    // Cherche ou crée la conversation entre l'utilisateur courant et l'annonceur
                    final conversationId =
                        await ConversationService().getOrCreateConversationId(
                      currentUserId: user.uid,
                      otherUserId: annonceurId,
                    );

                    if (!context.mounted) return;

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ConversationPage(
                          conversationId: conversationId,
                          offerTitle: widget.title,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    isLoggedIn
                        ? "Envoyer un message"
                        : "Envoyer un message / Se connecter",
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrestoBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _callPhone(context);
                  },
                  icon: const Icon(Icons.call),
                  label: const Text(
                    "Appeler le numéro",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _reportOffer(BuildContext context) async {
    final subject = Uri.encodeComponent("Annonce signalée – ID ${widget.offerId}");
    final reportLink = 'https://prestoo.app/offers/${widget.offerId}';
    final bodyText = """
Bonjour,

Je souhaite signaler l'annonce suivante.

ID Firebase : ${widget.offerId}
Titre : ${widget.title.trim()}
Lieu : ${widget.location.trim()}
Catégorie : ${widget.category}

Lien : $reportLink

Motif du signalement :
- 
""";
    final body = Uri.encodeComponent(bodyText);
    final uri =
        Uri.parse('mailto:contact@ilipresto.fr?subject=$subject&body=$body');

    try {
      final ok = await canLaunchUrl(uri);
      if (!context.mounted) return;

      if (ok) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      showSuccessSnackBar(context, "Impossible d'ouvrir l'e-mail.");
    } catch (_) {
      if (!context.mounted) return;
      showSuccessSnackBar(context, "Une erreur est survenue.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // --- helpers format / extraction ---
    String formatPrice(num? b) {
      if (b == null) return "—";
      final v = b.toDouble();
      return "${v.toStringAsFixed(0)} €";
    }

    String extractDuration(String title) {
      // Ex: "Ménage 2h" => "2h" | "DJ 90 min" => "90 min"
      final reg = RegExp(r'(\d+\s*(h|min))', caseSensitive: false);
      final m = reg.firstMatch(title);
      return m?.group(1)?.replaceAll(' ', '') ?? "—";
    }

    final String priceText = formatPrice(widget.budget);
    final String durationText = extractDuration(widget.title);
    final String city = widget.location;

    final bool hasPhone = widget.phone != null && widget.phone!.trim().isNotEmpty;
    final String rawPhone = hasPhone ? widget.phone!.trim() : '';
    final String phoneText = hasPhone
      ? (_isPhoneVisible ? rawPhone : _maskPhone(rawPhone))
      : "Numéro non renseigné";
    final String rawDescription = (widget.description ?? '').trim();
    final String descriptionText = rawDescription.isEmpty
        ? "Aucune description détaillée fournie."
        : rawDescription;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF6F7F9),

      appBar: AppBar(
        systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          "Détail de l’offre",
          style: kPrestoAppBarTitleStyle,
        ),
        centerTitle: true,
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'report') {
                _reportOffer(context);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'report',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Signaler',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      // ✅ CTA sticky comme le mockup
      bottomSheet: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Réponse rapide • Paiement selon accord",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    "Récemment en ligne",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrestoOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  // ✅ garde ta logique : action sheet (message/appel)
                  onPressed: () => _showActionSheet(context),
                  child: const Text("Accepter l’offre"),
                ),
              ),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              0, 14, 0, 160), // espace pour bottomSheet, cartes pleine largeur
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ✅ Section principale avec infos clés
              _keyInfoCard(
                  context, theme, city, priceText, widget.category, durationText),

              const SizedBox(height: 16),

              // ✅ DESCRIPTION (carte)
              _SectionCard(
                title: "Description",
                child: Text(
                  descriptionText,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade800,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ✅ CONTACT (carte)
              _SectionCard(
                title: "Contact",
                trailing: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.annonceurId)
                      .snapshots(),
                  builder: (context, snap) {
                    final pseudo = _extractUserPseudo(snap.data?.data());
                    return TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserPublicProfilePage(
                              userId: widget.annonceurId,
                              initialPseudo: pseudo,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        pseudo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    );
                  },
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFFFF3E8),
                          child: Icon(
                            Icons.call,
                            size: 18,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            phoneText,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasPhone && !_isPhoneVisible) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isPhoneVisible = true;
                            });
                          },
                          child: const Text(
                            "Voir le numéro",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                    // Bouton messagerie retiré
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ✅ PUBLICITÉ - Carrousel pleine largeur sans rebord
              AdBanner(
                margin: EdgeInsets.zero,
                placeholderHeight: kIsWeb ? 220.0 : 140.0,
                placeholderFolderPrefix: 'assets/carousel_home/',
                flat: true,
              ),

              const SizedBox(height: 14),

              // ✅ PARTAGER (carte) -> boutons comme mockup
              _SectionCard(
                title: "Partager l’annonce",
                trailing: const Icon(Icons.chevron_right),
                child: Row(
                  children: [
                    Expanded(
                      child: _ShareButton(
                        icon: SvgPicture.network(
                          'https://cdn.simpleicons.org/whatsapp',
                          width: 18,
                          height: 18,
                          placeholderBuilder: (context) => Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                              color: Colors.grey.shade800),
                        ),
                        label: "WhatsApp",
                        onPressed: () => _shareOn(context, 'whatsapp'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ShareButton(
                        icon: SvgPicture.network(
                          'https://cdn.simpleicons.org/facebook',
                          width: 18,
                          height: 18,
                          placeholderBuilder: (context) => Icon(Icons.facebook,
                              size: 18, color: Colors.grey.shade800),
                        ),
                        label: "Facebook",
                        onPressed: () => _shareOn(context, 'facebook'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ShareButton(
                        icon: const Icon(Icons.link,
                            size: 18, color: Colors.grey),
                        label: "Copier le lien",
                        onPressed: () {
                          // si tu veux, tu peux faire Clipboard.setData(...)
                          // mais pour rester simple, on peut réutiliser un share "instagram" ou snackbar
                          showSuccessSnackBar(context, "Lien copié (à brancher).");
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------
  // SECTION 1 – En-tête ultra lisible
  // -------------------------
  // (supprimé) _headerCard inactif : bloc retiré pour éviter erreurs de compilation.

  // -------------------------
  // SECTION 2 – Bloc infos clés
  // -------------------------
  Widget _keyInfoCard(BuildContext context, ThemeData theme, String city,
      String priceText, String categoryText, String durationText) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          Text(
            widget.title.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          // Prix + "pour X heures" (conditionnellement)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                priceText,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: kPrestoOrange,
                  height: 1,
                ),
              ),
              if (durationText != "—") ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    "pour $durationText",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Infos secondaires avec icônes
          _infoRow(Icons.place_outlined, city, theme),
          const SizedBox(height: 12),
          _infoRow(Icons.local_shipping_outlined, categoryText, theme),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // (supprimé) _pill inactif : retiré car non référencé.
}

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
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadActiveOffers() async {
    final col = FirebaseFirestore.instance.collection('offers');

    final resUid = await col.where('uid', isEqualTo: widget.userId).get();
    final resUserId = await col.where('userId', isEqualTo: widget.userId).get();

    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final d in resUid.docs) {
      byId[d.id] = d;
    }
    for (final d in resUserId.docs) {
      byId[d.id] = d;
    }

    final docs = byId.values.toList(growable: false);

    // Filtrer “en cours”: public (nouveau modèle) ou status=active (legacy)
    final filtered = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in docs) {
      final data = doc.data();
      final visibility = (data['visibility'] is Map)
          ? (data['visibility'] as Map)
          : const <String, dynamic>{};
      final isPublic = visibility['isPublic'] == true || data['status'] == 'active';
      if (!isPublic) continue;
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
    final user = FirebaseAuth.instance.currentUser;
    final bool isLoggedIn = user != null;

    if (!isLoggedIn) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AccountPage(),
        ),
      );
      return;
    }

    final conversationId = await ConversationService().getOrCreateConversationId(
      currentUserId: user.uid,
      otherUserId: widget.userId,
    );

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationPage(
          conversationId: conversationId,
          offerTitle: 'Profil',
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Profil',
          style: kPrestoAppBarTitleStyle,
        ),
        centerTitle: true,
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .snapshots(),
              builder: (context, snap) {
                final pseudo = _extractUserPseudo(snap.data?.data());
                return _CardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFFFF3E8),
                            child: Icon(
                              Icons.person_outline,
                              size: 20,
                              color: Colors.orange.shade800,
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
            _CardShell(
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
                  FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                    future: _loadActiveOffers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(kPrestoOrange),
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
                            _UserOfferMiniCard(data: doc.data()),
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
  final Map<String, dynamic> data;
  const _UserOfferMiniCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = (data['title'] ?? '').toString().trim();
    final city = (data['city'] ?? '').toString().trim();
    final category = (data['category'] ?? '').toString().trim();
    final budget = data['budget'];
    final priceText = (budget is num) ? "${budget.toStringAsFixed(0)} €" : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
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
          if (city.isNotEmpty)
            Text(
              city,
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

/// PAGE MESSAGES (LISTE DE CONVERSATIONS) //////////////////////////////////

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  Widget _buildNeedAccount(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
        title: const Text(
          "Mes messages",
          style: kPrestoAppBarTitleStyle,
        ),
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 60,
                color: Colors.black26,
              ),
              const SizedBox(height: 16),
              const Text(
                "Pour utiliser la messagerie iliprestō, connecte-toi à ton compte.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrestoBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountPage()),
                  );
                },
                icon: const Icon(Icons.person),
                label: const Text(
                  "Se connecter / s’inscrire",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? SessionState.userId;

    if (userId == null) {
      return _buildNeedAccount(context);
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        appBar: AppBar(
          systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
          title: const Text(
            "Mes messages",
            style: kPrestoAppBarTitleStyle,
          ),
          backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .where('participants', arrayContains: userId)
            .orderBy('lastMessageAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Erreur lors du chargement des conversations.\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.black26,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Aucune conversation pour l’instant",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Accepte une offre ou envoie un message depuis le détail d’une annonce pour démarrer une conversation.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final conversationId = docs[index].id;

              final offerTitle =
                  (data['offerTitle'] ?? 'Conversation iliprestō') as String;
              final lastMessage =
                  (data['lastMessage'] ?? 'Pas encore de message') as String;
              final ts = data['lastMessageAt'] as Timestamp?;
              final timeLabel = formatTimeLabel(ts);

              final Map<String, dynamic> unreadMap =
                  (data['unreadCount'] as Map<String, dynamic>?) ?? {};
              final int unread =
                  (unreadMap[userId] is int) ? unreadMap[userId] as int : 0;

              return _TapScale(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ConversationPage(
                        conversationId: conversationId,
                        offerTitle: offerTitle,
                      ),
                    ),
                  );
                },
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 1.5,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 46,
                            height: 46,
                            color: const Color(0xFFFFF3E0),
                            child: const Icon(
                              Icons.work_outline,
                              color: kPrestoOrange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offerTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: unread > 0
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: unread > 0
                                      ? Colors.black87
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              timeLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (unread > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: kPrestoBlue,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  unread.toString(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }
}

/// PAGE CONVERSATION (CHAT) /////////////////////////////////

class ConversationPage extends StatefulWidget {
  final String conversationId;
  final String offerTitle;

  const ConversationPage({
    super.key,
    required this.conversationId,
    required this.offerTitle,
  });

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();

  List<String> _participants = [];
  bool _isLoadingMeta = true;

  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _loadConversationMeta();
    _loadCurrentUserName();
    _markAsRead();
  }

  Future<void> _loadConversationMeta() async {
    try {
      final doc = await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .get();
      if (!doc.exists) {
        setState(() {
          _participants = [];
          _isLoadingMeta = false;
        });
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      final parts = (data['participants'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      setState(() {
        _participants = parts;
        _isLoadingMeta = false;
      });
    } catch (_) {
      setState(() {
        _participants = [];
        _isLoadingMeta = false;
      });
    }
  }

  Future<void> _loadCurrentUserName() async {
    final user = _auth.currentUser;
    final userId = user?.uid ?? SessionState.userId;
    if (userId == null) return;

    String? name;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final pseudo = (data['pseudo'] ?? '') as String;
        if (pseudo.trim().isNotEmpty) {
          name = pseudo.trim();
        }
      }
    } catch (_) {}

    name ??= user?.displayName ?? user?.email ?? 'Utilisateur iliprestō';

    if (mounted) {
      setState(() {
        _currentUserName = name;
      });
    }
  }

  Future<void> _markAsRead() async {
    final user = _auth.currentUser;
    final userId = user?.uid ?? SessionState.userId;
    if (userId == null) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'unreadCount.$userId': 0,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final user = _auth.currentUser;
    final userId = user?.uid ?? SessionState.userId;

    if (userId == null) {
      showSuccessSnackBar(
        context,
        "Connecte-toi à ton compte pour envoyer des messages iliprestō.",
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AccountPage()),
      );
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final convRef =
        _firestore.collection('conversations').doc(widget.conversationId);
    final messagesRef = convRef.collection('messages');

    final String senderName = _currentUserName ??
        user?.displayName ??
        user?.email ??
        'Utilisateur iliprestō';

    _messageController.clear();

    try {
      await _firestore.runTransaction((txn) async {
        await messagesRef.add({
          'text': text,
          'senderId': userId,
          'senderName': senderName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final Map<String, dynamic> update = {
          'lastMessage': text,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': userId,
        };

        for (final p in _participants) {
          if (p == userId) {
            update['unreadCount.$p'] = 0;
          } else {
            update['unreadCount.$p'] = FieldValue.increment(1);
          }
        }

        txn.update(convRef, update);
      });

      _markAsRead();
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, "Erreur lors de l’envoi du message : $e");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMessagesOnce() async {
    final snap = await _firestore
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .get();

    return snap.docs.map((d) => d.data()).toList();
  }

  Future<void> _shareByEmail() async {
    final messages = await _fetchMessagesOnce();
    final buffer = StringBuffer();

    for (final m in messages) {
      final sender = (m['senderName'] ?? 'Utilisateur') as String;
      final text = (m['text'] ?? '') as String;
      final ts = m['createdAt'] as Timestamp?;
      final timeLabel = formatTimeLabel(ts);
      buffer.writeln("[$timeLabel] $sender : $text");
    }

    final subject =
        Uri.encodeComponent("Conversation iliprestō - ${widget.offerTitle}");
    final body = Uri.encodeComponent(buffer.toString());

    final uri = Uri.parse("mailto:?subject=$subject&body=$body");

    final ok = await canLaunchUrl(uri);
    if (!mounted) return;

    if (ok) {
      await launchUrl(uri);
      return;
    }

    {
      showSuccessSnackBar(
        context,
        "Impossible d’ouvrir le client email sur cet appareil.",
      );
    }
  }

  Future<void> _exportAsText() async {
    final messages = await _fetchMessagesOnce();
    final buffer = StringBuffer();

    buffer.writeln("Conversation iliprestō - ${widget.offerTitle}");
    buffer.writeln("======================================");
    buffer.writeln();

    for (final m in messages) {
      final sender = (m['senderName'] ?? 'Utilisateur') as String;
      final text = (m['text'] ?? '') as String;
      final ts = m['createdAt'] as Timestamp?;
      final timeLabel = formatTimeLabel(ts);
      buffer.writeln("[$timeLabel] $sender : $text");
    }

    final text = buffer.toString();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Conversation (texte)"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                text.isEmpty ? "Aucun message pour l’instant." : text,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Fermer"),
            ),
          ],
        );
      },
    );
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'email':
        _shareByEmail();
        break;
      case 'txt':
        _exportAsText();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final userId = user?.uid ?? SessionState.userId;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        appBar: AppBar(
          systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
          backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 40,
                height: 40,
                color: const Color(0xFFFFF3E0),
                child: const Icon(
                  Icons.work_outline,
                  color: kPrestoOrange,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.offerTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kPrestoAppBarTitleStyle,
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenuSelected,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'email',
                child: Text("Partager par email"),
              ),
              PopupMenuItem(
                value: 'txt',
                child: Text("Enregistrer la conversation (texte)"),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Liste des messages
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('conversations')
                  .doc(widget.conversationId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !_isLoadingMeta) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Aucun message pour le moment.\nCommence la conversation !",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final text = (data['text'] ?? '') as String;
                    final senderName =
                        (data['senderName'] ?? 'iliprestō') as String;
                    final senderId = (data['senderId'] ?? '') as String;
                    final ts = data['createdAt'] as Timestamp?;
                    final timeLabel = formatTimeLabel(ts);

                    final isMe = senderId == userId;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? kPrestoBlue : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isMe ? 18 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                senderName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54,
                                ),
                              ),
                            if (!isMe) const SizedBox(height: 2),
                            Text(
                              text,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isMe ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                timeLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe ? Colors.white70 : Colors.black38,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Zone de saisie
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.grey[100],
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: "Écrire un message...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: kPrestoOrange),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// PAGE PUBLIER UNE OFFRE //////////////////////////////////////////////////

class PublishOfferPage extends StatefulWidget {
  final Function(double)? onScroll;

  const PublishOfferPage({super.key, this.onScroll});

  @override
  State<PublishOfferPage> createState() => _PublishOfferPageState();
}

class _PublishOfferPageState extends State<PublishOfferPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  bool _isUrgent = false;

  // Champs texte
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  // Catégories / sous-catégories
  String? _category;
  String? _selectedSubCategory;

  List<String> get _categories =>
      kCategorySubcategories.keys.toList(); // Map<String, List<String>>

  // Budget: type (fixe / à négocier)
  final List<String> _budgetTypes = const ['Fixe', 'À négocier'];
  String _budgetType = 'Fixe';

  // Photos (max 2)
  final List<XFile> _selectedPhotos = [];
  final List<String> _uploadedPhotoUrls = [];

  // Autocomplétion villes
  List<CityRecord> _citySuggestions = [];
  int _highlightedIndex = -1;

  // Région / département (optionnel à exploiter dans le futur)
  // ignore: unused_field
  String? _selectedRegionCode;
  // ignore: unused_field
  String? _selectedDeptCode;

  bool _isSubmitting = false;
  bool _isAnalyzing = false;
  bool _isListening = false;

  bool _attemptedSubmit = false; // affiche erreurs après tentative
  bool _publishLocked = false; // lock après tentative invalide
  bool _canPublish = false;

  // Service IA pour analyser la description
  final AiDraftService _aiService = AiDraftService();
  final AudioRecorder _recorder = AudioRecorder();
  final WebAudioRecorder _webRec = WebAudioRecorder();
  String? _recordingPath;
  // Toujours actif (améliore la qualité via Google STT côté serveur)
  final bool _useCloudStt = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      widget.onScroll?.call(_scrollController.offset);
    });

    _titleController.addListener(_recompute);
    _descriptionController.addListener(_recompute);
    _locationController.addListener(_recompute);
    _phoneController.addListener(_recompute);
    _budgetController.addListener(_recompute);

    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());
  }

  bool _isValidPhoneFR(String raw) {
    final s = raw.replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return false;

    // Accepte : 612345678, 06XXXXXXXX, 07XXXXXXXX, +336XXXXXXXX, +337XXXXXXXX
    final fr9 = RegExp(r'^[67]\d{8}$');
    final fr10 = RegExp(r'^0[67]\d{8}$');
    final intl = RegExp(r'^\+33[67]\d{8}$');
    return fr9.hasMatch(s) || fr10.hasMatch(s) || intl.hasMatch(s);
  }

  double? _parseBudget(String raw) {
    final cleaned = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  Widget _requiredLabel(String text) {
    final theme = Theme.of(context);
    final base = theme.inputDecorationTheme.labelStyle ??
        theme.textTheme.bodyLarge ??
        const TextStyle(fontSize: 16, color: Colors.black87);
    final baseColor = base.color ?? Colors.black87;

    return RichText(
      text: TextSpan(
        style: base.copyWith(color: baseColor),
        children: [
          TextSpan(text: text),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  bool _requiredOk() {
    final titleOk = _titleController.text.trim().isNotEmpty;
    final descOk = _descriptionController.text.trim().isNotEmpty;
    final cityOk = _locationController.text.trim().isNotEmpty;
    final catOk = (_category ?? '').trim().isNotEmpty;
    final subOk = (_selectedSubCategory ?? '').trim().isNotEmpty;
    final phoneOk = _isValidPhoneFR(_phoneController.text);

    final budgetOk = _budgetType == 'À négocier'
        ? true
        : () {
            final b = _parseBudget(_budgetController.text);
            return b != null && b > 0;
          }();

    return titleOk && descOk && cityOk && catOk && subOk && phoneOk && budgetOk;
  }

  void _recompute() {
    final ok = _requiredOk();
    if (!mounted) return;
    if (_canPublish == ok && !(_publishLocked && ok)) return;
    setState(() {
      _canPublish = ok;
      if (_publishLocked && ok) _publishLocked = false; // délock auto
    });
  }

  Future<void> _onPublishPressed() async {
    setState(() => _attemptedSubmit = true);

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || !_requiredOk()) {
      setState(() {
        _publishLocked = true;
        _canPublish = false;
      });
      showSuccessSnackBar(context, 'Complète les champs obligatoires pour publier.');
      return;
    }

    await _submitForm();
  }

  Future<void> _startMic() async {
    if (_isListening) return;

    // ✅ Micro global: on ne fait PLUS speech_to_text (trop variable)
    // On enregistre uniquement en WAV 16k mono, puis _stopMic() déclenchera _uploadAndTranscribe() (MicroIA).
    if (kIsWeb) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          if (!mounted) return;
          showSuccessSnackBar(context, 'Connecte-toi pour utiliser la dictée');
          return;
        }

        await CrashlyticsContext.setUserId(uid);
        await CrashlyticsContext.setKey('flow', 'webMic');

        await _webRec.start();
        if (!mounted) return;
        setState(() => _isListening = true);
      } catch (e, st) {
        await CrashlyticsContext.recordError(
          e is Exception ? e : Exception(e.toString()),
          st,
          reason: 'Web mic start failed',
          fatal: false,
          keys: {
            'component': 'Main',
            'flow': 'webMic',
            'step': 'start',
          },
        );
        if (!mounted) return;
        showSuccessSnackBar(context, 'Micro web indisponible: $e');
      }
      return;
    }

    // Préparer l'enregistreur haute qualité (WAV)
    try {
      if (await _recorder.hasPermission()) {
        final filePath = await createTempAudioPath(prefix: 'presto', extension: 'm4a');
        await _recorder.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 44100,
            numChannels: 1,
          ),
          path: filePath,
        );
        _recordingPath = filePath;
      } else {
        if (!mounted) return;
        showSuccessSnackBar(context, 'Permission micro requise');
        return;
      }
    } catch (e) {
      debugPrint('Recorder start error: $e');
    }

    setState(() {
      _isListening = true;
    });
  }

  Future<void> _stopMic() async {
    if (!_isListening) return;
    if (_isAnalyzing) return;

    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _isAnalyzing = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        final uid = user?.uid;
        if (uid == null) throw Exception('Not authenticated');

        final blob = await _webRec.stopToBlob();
        final webmBytes = await webBlobToBytes(blob);
        if (webmBytes.length < 30000) {
          throw Exception('Audio invalide (blob trop petit: ${webmBytes.length} bytes).');
        }

        final ts = DateTime.now().millisecondsSinceEpoch;
        final destPath = 'stt/${uid}_$ts.webm';
        final ref = FirebaseStorage.instance.ref(destPath);
        await ref.putData(webmBytes, SettableMetadata(contentType: 'audio/webm'));

        final out = await MicroIaService.processAudio(
          storagePath: destPath,
          languageCode: 'fr-FR',
        );

        final transcript = (out['text'] ?? '').toString().trim();
        if (transcript.isEmpty) throw Exception('Aucun texte reconnu');

        final draft = await _aiService.generateOfferDraft(text: transcript);
        if (!mounted) return;

        if (draft['success'] == true) {
          setState(() {
            final title = (draft['title'] as String? ?? '').trim();
            final category = (draft['category'] as String? ?? '').trim();
            final description = (draft['description'] as String? ?? '').trim();
            final location = (draft['location'] as String? ?? '').trim();
            final postalCode = (draft['postalCode'] as String? ?? '').trim();

            if (title.isNotEmpty) _titleController.text = title;
            if (description.isNotEmpty) _descriptionController.text = description;
            if (category.isNotEmpty) {
              _category = category;
              _selectedSubCategory = null;
            }
            if (location.isNotEmpty) _locationController.text = location;
            if (postalCode.isNotEmpty) _postalCodeController.text = postalCode;
          });

          showSuccessSnackBar(context, 'Transcription réussie et champs remplis');
        } else {
          final code = (draft['code'] ?? '').toString();
          showSuccessSnackBar(
            context,
            code == 'deadline-exceeded'
                ? 'Connexion lente, réessaie.'
                : 'Erreur IA: ${draft['error'] ?? 'inconnue'}',
          );
        }
      } catch (e, st) {
        await CrashlyticsContext.recordError(
          e is Exception ? e : Exception(e.toString()),
          st,
          reason: 'Web mic stop/process failed',
          fatal: false,
          keys: {
            'component': 'Main',
            'flow': 'webMic',
            'step': 'stop',
          },
        );
        if (!mounted) return;
        if (isTimeoutError(e)) {
          showTimeoutSnackBar(context);
        } else {
          showSuccessSnackBar(context, 'Erreur transcription (web): $e');
        }
      } finally {
        if (mounted) setState(() => _isAnalyzing = false);
      }
      return;
    }

    String? recordedPath;
    try {
      recordedPath = await _recorder.stop();
      if (recordedPath == null) {
        recordedPath = _recordingPath;
      }
    } catch (e) {
      debugPrint('Recorder stop error: $e');
    }
    setState(() {
      _isListening = false;
    });
    // Si l'audio est disponible et cloud STT activé, on passe par la fonction distante
    if (_useCloudStt && recordedPath != null) {
      setState(() => _isAnalyzing = true);
      try {
        await _uploadAndTranscribe(recordedPath);
      } catch (e) {
        if (!mounted) return;
        if (isTimeoutError(e)) {
          showTimeoutSnackBar(context);
        } else {
          showSuccessSnackBar(context, 'Erreur transcription: $e');
        }
      } finally {
        if (mounted) setState(() => _isAnalyzing = false);
      }
      return;
    }

    if (!mounted) return;
    showSuccessSnackBar(context, 'Aucun audio disponible');
  }

  /// Construire le bouton d'enregistrement au micro avec indicateur visuel
  Widget _buildMicRecordingButton() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.92,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE53935), // Rouge plus clair en haut
            Color(0xFFC62828), // Rouge plus profond en bas
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC62828).withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _stopMic,
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stop_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Appuyer pour arrêter',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      letterSpacing: 0.3,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadAndTranscribe(String localPath) async {
    // Upload vers Firebase Storage puis appel de la Cloud Function.
    // ✅ Forcer le pipeline MicroIA (WAV 16k mono) + génération de draft.
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'anonymous';
    final xfile = XFile(localPath);
    final audioBytes = await xfile.readAsBytes();
    if (audioBytes.isEmpty) {
      throw 'Fichier audio introuvable';
    }
    final lower = localPath.toLowerCase();
    final isM4a = lower.endsWith('.m4a');
    final isMp4 = lower.endsWith('.mp4');
    final ext = isM4a ? 'm4a' : (isMp4 ? 'mp4' : 'wav');
    final contentType = (isM4a || isMp4) ? 'audio/mp4' : 'audio/wav';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final storage = FirebaseStorage.instance;
    final destPath = 'stt/${uid}_$ts.$ext';
    final ref = storage.ref(destPath);
    await ref.putData(audioBytes, SettableMetadata(contentType: contentType));

    final out = await MicroIaService.processAudio(
      storagePath: destPath,
      languageCode: 'fr-FR',
    );

    final transcript = (out['text'] ?? '').toString().trim();
    if (transcript.isEmpty) {
      throw Exception('Aucun texte reconnu');
    }

    final draft = await _aiService.generateOfferDraft(text: transcript);
    if (!mounted) return;

    if (draft['success'] == true) {
      setState(() {
        final title = (draft['title'] as String? ?? '').trim();
        final category = (draft['category'] as String? ?? '').trim();
        final description = (draft['description'] as String? ?? '').trim();
        final location = (draft['location'] as String? ?? '').trim();
        final postalCode = (draft['postalCode'] as String? ?? '').trim();

        if (title.isNotEmpty) _titleController.text = title;
        if (description.isNotEmpty) _descriptionController.text = description;
        if (category.isNotEmpty) {
          _category = category;
          _selectedSubCategory = null;
        }
        if (location.isNotEmpty) _locationController.text = location;
        if (postalCode.isNotEmpty) _postalCodeController.text = postalCode;
      });

      showSuccessSnackBar(context, 'Transcription réussie et champs remplis');
    } else {
      final code = (draft['code'] ?? '').toString();
      showSuccessSnackBar(
        context,
        code == 'deadline-exceeded'
            ? 'Connexion lente, réessaie.'
            : 'Erreur IA: ${draft['error'] ?? 'inconnue'}',
      );
    }
    
  }

  /// Appelle la Cloud Function pour analyser la description avec OpenAI
  // ignore: unused_element
  Future<void> _onTapAiAnalyze() async {
    final input = _descriptionController.text.trim();
    if (input.isEmpty) {
      showSuccessSnackBar(context, "Veuillez d'abord saisir une description");
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final draft = await _aiService.generateOfferDraft(text: input);

      if (!mounted) return;

      if (draft['success'] == true) {
        setState(() {
          if ((draft['title'] as String).isNotEmpty) {
            _titleController.text = draft['title'] as String;
          }
          if ((draft['category'] as String).isNotEmpty) {
            _category = draft['category'] as String;
            _selectedSubCategory = null;
          }
          if ((draft['description'] as String).isNotEmpty) {
            _descriptionController.text = draft['description'] as String;
          }
          // Remplir la ville si disponible
          final location = (draft['location'] as String? ?? '').trim();
          if (location.isNotEmpty) {
            _locationController.text = location;
          }
          // Remplir le code postal si disponible
          final postalCode = (draft['postalCode'] as String? ?? '').trim();
          if (postalCode.isNotEmpty) {
            _postalCodeController.text = postalCode;
          }
        });

        showSuccessSnackBar(
          context,
          '✨ Analyse IA complétée\nChamps remplis automatiquement',
        );
      } else {
        showSuccessSnackBar(
          context,
          "Erreur IA : ${draft['error'] ?? 'Erreur inconnue'}",
        );
      }
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, "Erreur lors de l'analyse : $e");
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    _budgetController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetAllFields() {
    setState(() {
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _postalCodeController.clear();
      _phoneController.clear();
      _budgetController.clear();
      _category = null;
      _selectedSubCategory = null;
      _budgetType = 'Fixe';
      _selectedPhotos.clear();
      _uploadedPhotoUrls.clear();
      _citySuggestions.clear();
      _highlightedIndex = -1;
      _selectedRegionCode = null;
      _selectedDeptCode = null;

      _isUrgent = false;

      _attemptedSubmit = false;
      _publishLocked = false;
      _canPublish = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());
    showSuccessSnackBar(context, 'Tous les champs ont été réinitialisés');
  }

  // --- LOGIQUE AUTOCOMPLÉTION VILLE ---

  void _onCityChanged(String value) {
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _citySuggestions = [];
        _highlightedIndex = -1;
      });
      return;
    }

    final results = CitySearch.instance.search(query, limit: 10);
    setState(() {
      _citySuggestions = results;
      _highlightedIndex = results.isNotEmpty ? 0 : -1;
    });
  }

  void _onPostalCodeChanged(String value) {
    final cp = value.trim();
    if (cp.length < 2) {
      // On ne spam pas si l'utilisateur tape juste "7"
      return;
    }

    final results = CitySearch.instance.searchByPostalCode(cp, limit: 10);

    if (!mounted) return;

    if (results.isEmpty) {
      setState(() {
        _citySuggestions = [];
        _highlightedIndex = -1;
      });
      return;
    }

    final best = CitySearch.instance.pickBestForPostalCode(cp);

    setState(() {
      _citySuggestions = results;
      _highlightedIndex = 0;
    });

    if (best != null) {
      _applyCity(best);
    }
  }

  void _applyCity(CityRecord city) {
    setState(() {
      _locationController.text = city.name;
      _postalCodeController.text = city.cp;

      _selectedDeptCode = city.dept;
      _selectedRegionCode = city.region;

      _citySuggestions = [];
      _highlightedIndex = -1;
    });
  }

  Widget _buildCitySuggestionsOverlay() {
    if (_citySuggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            spreadRadius: 1,
            color: Colors.black12,
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _citySuggestions.length,
        itemBuilder: (context, index) {
          final city = _citySuggestions[index];
          final selected = index == _highlightedIndex;

          return InkWell(
            onTap: () => _applyCity(city),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: selected ? kPrestoBlue.withOpacity(0.08) : null,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${city.name} (${city.cp})',
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Dept ${city.dept}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- GESTION DES PHOTOS ---

  Future<void> _pickImage(int photoIndex) async {
    if (_selectedPhotos.length >= 2 && photoIndex >= _selectedPhotos.length) {
      showSuccessSnackBar(context, 'Maximum 2 photos autorisées');
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      setState(() {
        if (photoIndex < _selectedPhotos.length) {
          _selectedPhotos[photoIndex] = image;
        } else {
          _selectedPhotos.add(image);
        }
      });
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur lors de la sélection : $e');
    }
  }

  Future<void> _uploadPhotos() async {
    if (_selectedPhotos.isEmpty) {
      _uploadedPhotoUrls.clear();
      return;
    }

    try {
      _uploadedPhotoUrls.clear();

      for (int i = 0; i < _selectedPhotos.length; i++) {
        final photo = _selectedPhotos[i];
        final fileName =
            'offers/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

        final ref = FirebaseStorage.instance.ref().child(fileName);
        final bytes = await photo.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

        final url = await ref.getDownloadURL();
        _uploadedPhotoUrls.add(url);
      }
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, "Erreur lors de l'upload : $e");
      rethrow;
    }
  }

  /// Crée des notifications pour les utilisateurs ayant cette catégorie en favori
  Future<void> _createNotificationsForFavorites(
    String offerId,
    String category,
    String? subCategory,
    String offerTitle,
    String publisherUserId,
  ) async {
    // 🔒 Sécurité: la création de notifications se fait côté serveur (Cloud Functions)
    // afin d'éviter qu'un client puisse créer des notifications pour d'autres utilisateurs.
    return;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Uploader les photos
      await _uploadPhotos();

      // Récupérer l'utilisateur actuel
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Sauvegarder l'offre dans Firestore
      final docRef = await FirebaseFirestore.instance.collection('offers').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category,
        'subCategory': _selectedSubCategory,
        'urgent': _isUrgent,
        'location': _locationController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'budget': _budgetController.text.trim(),
        'budgetType': _budgetType,
        'imageUrls': _uploadedPhotoUrls.isEmpty ? null : _uploadedPhotoUrls,
        'userId': user.uid,
        'createdAt': Timestamp.now(),
      });

      // Créer des notifications pour les utilisateurs ayant cette catégorie en favori
      await _createNotificationsForFavorites(
        docRef.id,
        _category ?? '',
        _selectedSubCategory,
        _titleController.text.trim(),
        user.uid,
      );

      if (!mounted) return;

      final offerId = docRef.id;
      final title = _titleController.text.trim();
      final location = _locationController.text.trim();
      final category = (_category ?? '').toString().trim();
      final subcategory = _selectedSubCategory;
      final budgetNum = _budgetType == 'À négocier' ? null : _parseBudget(_budgetController.text);
      final description = _descriptionController.text.trim();
      final phone = _phoneController.text.trim();
      final imageUrls = _uploadedPhotoUrls.isEmpty ? null : List<String>.from(_uploadedPhotoUrls);

      // ✅ Checkmark bleu au milieu de l'écran.
      showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.10),
        builder: (_) => const Center(
          child: Icon(
            Icons.check_circle,
            color: kPrestoBlue,
            size: 96,
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      // Fermer le checkmark puis aller au détail.
      Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OfferDetailPage(
            title: title.isEmpty ? 'Annonce' : title,
            location: location,
            category: category,
            subcategory: subcategory,
            budget: budgetNum,
            description: description,
            phone: phone.isEmpty ? null : phone,
            imageUrls: imageUrls,
            annonceurId: user.uid,
            offerId: offerId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur lors de la publication : $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final publishDisabled = _publishLocked || !_canPublish || _isSubmitting;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
          backgroundColor: kPrestoOrange,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          title: const Text(
            'Je publie une offre',
            style: kPrestoAppBarTitleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'Réinitialiser tous les champs',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: Colors.white,
                    title: const Text('Réinitialiser ?'),
                    content: const Text(
                      'Voulez-vous effacer tous les champs et recommencer ?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: kPrestoBlue,
                        ),
                        child: const Text('Annuler'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _resetAllFields();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: kPrestoOrange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode:
              _attemptedSubmit ? AutovalidateMode.always : AutovalidateMode.disabled,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Bouton Premium AI avec enregistrement audio
              Center(
                child: _isListening
                    ? _buildMicRecordingButton()
                    : PremiumAiButton(
                        onPressed: _isAnalyzing ? null : _startMic,
                        label: 'Décrire mon besoin (IA)',
                        isLoading: _isAnalyzing,
                      ),
              ),
              if (_isListening) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PulsingDot(delay: 0),
                    const SizedBox(width: 8),
                    _PulsingDot(delay: 200),
                    const SizedBox(width: 8),
                    _PulsingDot(delay: 400),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enregistrement en cours...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                if (_useCloudStt && !kIsWeb)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kPrestoBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: kPrestoBlue.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.cloud_done, size: 16, color: kPrestoBlue),
                          SizedBox(width: 6),
                          Text(
                            'Qualité audio améliorée (Cloud)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kPrestoBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (_isAnalyzing) ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kPrestoBlue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: kPrestoBlue.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _useCloudStt && !kIsWeb
                            ? const Icon(Icons.cloud_sync,
                                size: 16, color: kPrestoBlue)
                            : SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      kPrestoBlue),
                                ),
                              ),
                        const SizedBox(width: 8),
                        Text(
                          _useCloudStt && !kIsWeb
                              ? 'Transcription et analyse (Cloud)…'
                              : 'Analyse en cours…',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kPrestoBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // TITRE
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  label: _requiredLabel('Titre de l’offre'),
                  border: const OutlineInputBorder(),
                  hintText: 'Ex : Monter un meuble IKEA',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Merci de saisir un titre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // CATÉGORIE
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(14),
                decoration: InputDecoration(
                  label: _requiredLabel('Catégorie'),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: _categories
                    .map(
                      (cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _category = value;
                    _selectedSubCategory = null;
                  });
                  _recompute();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Merci de choisir une catégorie';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // SOUS-CATÉGORIE (dropdown dynamique)
              if (_category != null)
                DropdownButtonFormField<String>(
                  value: _selectedSubCategory,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  decoration: InputDecoration(
                    label: _requiredLabel('Sous-catégorie'),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  items: (kCategorySubcategories[_category] ?? [])
                      .map(
                        (sub) => DropdownMenuItem(
                          value: sub,
                          child: Text(sub),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSubCategory = value;
                    });
                    _recompute();
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Merci de choisir une sous-catégorie';
                    }
                    return null;
                  },
                ),
              if (_category != null) const SizedBox(height: 16),

              // DESCRIPTION
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  label: _requiredLabel('Description détaillée'),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                minLines: 4,
                maxLines: 8,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Merci de décrire votre besoin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // PHOTOS (max 2)
              const Text(
                'Photos de l\'offre',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PhotoSelectorTile(
                      label: 'Photo 1',
                      file: _selectedPhotos.isNotEmpty
                          ? _selectedPhotos[0]
                          : null,
                      onTap: () => _pickImage(0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PhotoSelectorTile(
                      label: 'Photo 2',
                      file: _selectedPhotos.length > 1
                          ? _selectedPhotos[1]
                          : null,
                      onTap: () => _pickImage(1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // VILLE + CP + AUTOCOMPLÉTION
              const Text(
                'Localisation',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  label: _requiredLabel('Ville'),
                  hintText: 'Ex : Les Abymes, Baie-Mahault, Paris...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onChanged: _onCityChanged,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Merci de saisir une ville';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _postalCodeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Code postal',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onChanged: _onPostalCodeChanged,
              ),
              _buildCitySuggestionsOverlay(),
              const SizedBox(height: 16),

              // TÉLÉPHONE avec sélection indicatif
              PhoneInputFieldCompact(
                controller: _phoneController,
                label: _requiredLabel('Téléphone (pour être rappelé)'),
                hintText: '612345678',
                onPhoneChanged: (_) => _recompute(),
                validator: (value) {
                  return _isValidPhoneFR(value ?? '')
                      ? null
                      : 'Téléphone invalide';
                },
              ),
              const SizedBox(height: 16),

              // URGENT
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: SwitchListTile.adaptive(
                  value: _isUrgent,
                  onChanged: (v) {
                    setState(() => _isUrgent = v);
                  },
                  title: const Text(
                    'Urgent',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  activeColor: kPrestoOrange,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // BUDGET
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _budgetType,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      items: _budgetTypes
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _budgetType = v;
                          if (_budgetType == 'À négocier') {
                            _budgetController.clear();
                          }
                        });
                        _recompute();
                      },
                      decoration: InputDecoration(
                        labelText: 'Budget',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]'))],
                      decoration: InputDecoration(
                        label: _budgetType == 'Fixe'
                            ? _requiredLabel('Montant (€)')
                            : null,
                        labelText: _budgetType == 'Fixe' ? null : 'Montant (€)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      enabled: _budgetType == 'Fixe',
                      validator: (value) {
                        if (_budgetType == 'À négocier') return null;
                        final b = _parseBudget(value ?? '');
                        if (b == null) return 'Montant invalide';
                        if (b <= 0) return 'Le montant doit être > 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                '* Champs obligatoires',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),

              // BOUTON PUBLIER
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: publishDisabled ? null : _onPublishPressed,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSubmitting
                        ? 'Publication en cours...'
                        : 'Publier mon offre',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrestoOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ignore: unused_element
/// Petite carte pour sélectionner une photo
class _PhotoSelectorTile extends StatelessWidget {
  final String label;
  final XFile? file;
  final VoidCallback onTap;

  const _PhotoSelectorTile({
    required this.label,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ variable locale pour la promotion null-safety
    final XFile? localFile = file;

    Widget content;
    if (localFile == null) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_a_photo_outlined,
              size: 28, color: Colors.black45),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      );
    } else {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: FutureBuilder<Uint8List>(
          future: localFile.readAsBytes(),
          builder: (context, snap) {
            if (snap.hasData) {
              return Image.memory(
                snap.data!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.image, size: 24, color: kPrestoOrange),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: content,
      ),
    );
  }
}

/// PAGE COMPTE (Firebase Auth : email / Google / Apple) ////////////////////

class AccountPage extends StatefulWidget {
  final Function(double)? onScroll;

  const AccountPage({super.key, this.onScroll});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<void> _touchPresence() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _trackLogin() async {
    try {
      final callable = _functions.httpsCallable(
        'trackUserLogin',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
      );
      await callable.call<dynamic>({});
    } catch (_) {
      // best-effort
    } finally {
      await _touchPresence();
    }
  }

  final TextEditingController _adminMicroIaLanguageController =
      TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoginMode = true;
  bool _isLoading = false;

  // Email / mot de passe
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  // Profil utilisateur
  final TextEditingController _profilePseudoController =
      TextEditingController();
  final TextEditingController _profileCityController = TextEditingController();
  final TextEditingController _profilePhoneController = TextEditingController();

  Set<String> _favoriteCategories = <String>{};
  Set<String> _selectedFavoriteCategories = <String>{};
  Set<String> _selectedFavoriteSubcategories = <String>{};
  String? _selectedCategoryInput;
  String? _selectedSubCategoryInput;
  bool _profileLoaded = false;
  bool _isSavingProfile = false;
  bool _isEditingProfile = false; // ✅ Mode édition du profil

  // Admin: paramètres Micro-IA (Remote Config)
  bool _adminConfigLoaded = false;
  bool _adminSaving = false;
  bool _adminMicroIaEditing = false;
  String _adminMicroIaMode = 'HYBRID';
  bool _adminMicroIaFallbackEnabled = true;
  double _adminMicroIaQualityThreshold = 0.62;
  String _adminMicroIaLanguageCode = 'fr-FR';

  Future<Map<String, dynamic>>? _adminCfgFuture;

  Future<Map<String, dynamic>> _adminGetMicroIaConfig() async {
    final callable = _functions.httpsCallable(
      'adminGetMicroIaConfig',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    final res = await callable.call<dynamic>({});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> _adminSetMicroIaConfig() async {
    if (_adminSaving) return;
    setState(() => _adminSaving = true);
    try {
      final callable = _functions.httpsCallable(
        'adminSetMicroIaConfig',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final res = await callable.call<dynamic>({
        'mode': _adminMicroIaMode,
        'fallbackEnabled': _adminMicroIaFallbackEnabled,
        'qualityThreshold': _adminMicroIaQualityThreshold,
        'languageCode': _adminMicroIaLanguageCode,
      });

      // ✅ Re-synchronise l'UI avec la config effectivement publiée.
      final data = (res.data is Map) ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final mode = (data['mode'] ?? _adminMicroIaMode).toString();
      final fallback = data['fallbackEnabled'] == true;
      final threshold = (data['qualityThreshold'] as num?)?.toDouble() ?? _adminMicroIaQualityThreshold;
      final lang = (data['languageCode'] ?? _adminMicroIaLanguageCode).toString();

      if (!mounted) return;

      setState(() {
        _adminMicroIaMode = mode;
        _adminMicroIaFallbackEnabled = fallback;
        _adminMicroIaQualityThreshold = threshold;
        _adminMicroIaLanguageCode = lang;
        _adminMicroIaLanguageController.text = lang;
        _adminMicroIaEditing = false; // ✅ re-griser les champs
      });
      showSuccessSnackBar(context, 'Paramètres Micro-IA mis à jour');
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, e.message ?? 'Erreur admin');
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur admin: $e');
    } finally {
      if (mounted) setState(() => _adminSaving = false);
    }
  }

  // ignore: unused_element
  Widget _buildAdminMicroIaPanel(User user) {
    _adminCfgFuture ??= _adminGetMicroIaConfig();

    return FutureBuilder<Map<String, dynamic>>(
      future: _adminCfgFuture,
      builder: (context, cfgSnap) {
        if (cfgSnap.connectionState == ConnectionState.waiting && !_adminConfigLoaded) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
              ),
            ),
          );
        }

        if (cfgSnap.hasError && !_adminConfigLoaded) {
          final err = cfgSnap.error;
          if (err is FirebaseFunctionsException) {
            if (err.code == 'permission-denied' || err.code == 'unauthenticated') {
              return const SizedBox.shrink();
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Erreur chargement Admin.\n$err",
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        if (cfgSnap.hasData && !_adminConfigLoaded) {
          final cfg = cfgSnap.data!;
          final mode = (cfg['mode'] ?? 'HYBRID').toString();
          final fallback = cfg['fallbackEnabled'] == true;
          final threshold = (cfg['qualityThreshold'] as num?)?.toDouble() ?? 0.62;
          final lang = (cfg['languageCode'] ?? 'fr-FR').toString();

          _adminMicroIaMode = mode;
          _adminMicroIaFallbackEnabled = fallback;
          _adminMicroIaQualityThreshold = threshold;
          _adminMicroIaLanguageCode = lang;
          _adminMicroIaLanguageController.text = lang;
          _adminConfigLoaded = true;
        }

        final canEdit = _adminMicroIaEditing && !_adminSaving;
        final disabledHintStyle = TextStyle(
          color: kPrestoBlue.withOpacity(0.65),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        );

        final techLines = <String>[
          'uid: ${user.uid}',
          'email: ${user.email ?? "(null)"}',
          'providers: ${user.providerData.map((p) => p.providerId).join(', ')}',
          'createdAt: ${user.metadata.creationTime?.toIso8601String() ?? "(null)"}',
          'lastSignIn: ${user.metadata.lastSignInTime?.toIso8601String() ?? "(null)"}',
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Text(
              'PANNEAU ADMIN',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: kPrestoBlue,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Réglages et outils de gestion (fonctions à venir).',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kPrestoBlue.withOpacity(0.18)),
                boxShadow: [
                  BoxShadow(
                    color: kPrestoBlue.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Espace admin',
                    style: TextStyle(
                      fontSize: 12,
                      color: kPrestoBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: kPrestoBlue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kPrestoBlue.withOpacity(0.18)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profil admin (technique)',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: kPrestoBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          techLines.join('\n'),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Micro-IA (transcription audio)',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: kPrestoOrange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _adminMicroIaMode,
                    items: const [
                      DropdownMenuItem(
                        value: 'HYBRID',
                        child: Text('Hybrid (recommandé)'),
                      ),
                      DropdownMenuItem(
                        value: 'GOOGLE_ONLY',
                        child: Text('Google STT uniquement'),
                      ),
                      DropdownMenuItem(
                        value: 'WHISPER_ONLY',
                        child: Text('Whisper uniquement'),
                      ),
                    ],
                    onChanged: canEdit
                        ? (v) {
                            if (v == null) return;
                            setState(() => _adminMicroIaMode = v);
                          }
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Mode',
                      helperText: canEdit ? null : 'Lecture seule (appuie sur “Modifier”)',
                      helperStyle: disabledHintStyle,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fallback activé'),
                    subtitle: const Text(
                      'Si la qualité est faible, tente un autre provider.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _adminMicroIaFallbackEnabled,
                    onChanged: canEdit ? (v) => setState(() => _adminMicroIaFallbackEnabled = v) : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Seuil qualité: ${_adminMicroIaQualityThreshold.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    value: _adminMicroIaQualityThreshold,
                    min: 0.40,
                    max: 0.95,
                    divisions: 55,
                    onChanged: canEdit ? (v) => setState(() => _adminMicroIaQualityThreshold = v) : null,
                  ),
                  TextField(
                    controller: _adminMicroIaLanguageController,
                    decoration: const InputDecoration(
                      labelText: 'Language code',
                      hintText: 'fr-FR',
                    ),
                    enabled: canEdit,
                    onChanged: (v) {
                      _adminMicroIaLanguageCode = v.trim();
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: _adminMicroIaEditing
                        ? ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrestoBlue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _adminSaving ? null : _adminSetMicroIaConfig,
                            icon: _adminSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(
                              _adminSaving ? 'Application…' : 'Appliquer',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: _adminSaving
                                ? null
                                : () {
                                    setState(() => _adminMicroIaEditing = true);
                                  },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text(
                              'Modifier',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ces réglages modifient Firebase Remote Config (impact côté Functions).',
                    style: TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static const List<String> _allFavoriteCategories = [
    'Restauration / Extra',
    'Bricolage / Travaux',
    'Aide à domicile',
    'Garde d’enfants',
    'Événementiel / DJ',
    'Cours & soutien',
    'Jardinage',
    'Peinture',
    'Main-d’œuvre',
    'Autre',
  ];

  static const Map<String, List<String>> _subCategoriesByCategory = {
    'Restauration / Extra': ['Service', 'Plonge', 'Cuisine', 'Bar'],
    'Bricolage / Travaux': [
      'Montage meuble',
      'Électricité',
      'Plomberie',
      'Peinture'
    ],
    'Aide à domicile': ['Ménage', 'Repassage', 'Courses'],
    'Garde d’enfants': ['Sortie d’école', 'Soirée', 'Mercredi'],
    'Événementiel / DJ': ['DJ', 'Sono', 'Lumières'],
    'Cours & soutien': ['Maths', 'Langues', 'Musique'],
    'Jardinage': ['Tonte', 'Taille', 'Désherbage'],
    'Peinture': ['Intérieur', 'Extérieur'],
    'Main-d’œuvre': ['Manutention', 'Aide chantier'],
    'Autre': ['Général'],
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      widget.onScroll?.call(_scrollController.offset);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _profilePseudoController.dispose();
    _profileCityController.dispose();
    _profilePhoneController.dispose();
    _adminMicroIaLanguageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      showSuccessSnackBar(context, "Connexion réussie");
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, e.message ?? "Erreur de connexion.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text.trim() !=
        _passwordConfirmController.text.trim()) {
      showSuccessSnackBar(context, "Les mots de passe ne correspondent pas.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _trackLogin();
      if (!mounted) return;
      showSuccessSnackBar(context, "Compte créé et connecté avec succès");
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, e.message ?? "Erreur lors de l’inscription.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserProfile(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _profilePseudoController.text = (data['pseudo'] ?? '') as String;
        _profileCityController.text = (data['city'] ?? '') as String;
        _profilePhoneController.text = (data['phone'] ?? '') as String;
        final favs = (data['favoriteCategories'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        _favoriteCategories = favs.toSet();
        final selectedCats =
            (data['selectedFavoriteCategories'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
        _selectedFavoriteCategories = selectedCats.toSet();
        final selectedSubcats =
            (data['selectedFavoriteSubcategories'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
        _selectedFavoriteSubcategories = selectedSubcats.toSet();
        
        // ✅ Si les champs sont remplis, ne pas être en mode édition par défaut
        final hasProfile = _profilePseudoController.text.isNotEmpty ||
            _profileCityController.text.isNotEmpty ||
            _profilePhoneController.text.isNotEmpty;
        _isEditingProfile = !hasProfile;
      } else {
        _favoriteCategories = <String>{};
        _selectedFavoriteCategories = <String>{};
        _selectedFavoriteSubcategories = <String>{};
      }
    } catch (_) {
      _favoriteCategories = <String>{};
      _selectedFavoriteCategories = <String>{};
      _selectedFavoriteSubcategories = <String>{};
    }

    if (mounted) {
      setState(() {
        _profileLoaded = true;
      });
    }
  }

  Future<void> _saveProfile(User user) async {
    setState(() => _isSavingProfile = true);
    try {
      final pseudo = _profilePseudoController.text.trim();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pseudo': pseudo,
        'city': _profileCityController.text.trim(),
        'phone': _profilePhoneController.text.trim(),
        'favoriteCategories': _favoriteCategories.toList(),
        'selectedFavoriteCategories': _selectedFavoriteCategories.toList(),
        'selectedFavoriteSubcategories':
            _selectedFavoriteSubcategories.toList(),
      }, SetOptions(merge: true));

      if (pseudo.isNotEmpty) {
        await user.updateDisplayName(pseudo);
      }

      if (mounted) {
        // ✅ Passer en mode lecture après enregistrement
        setState(() => _isEditingProfile = false);
        
        showSuccessSnackBar(context, "Profil mis à jour avec succès");
      }
    } catch (e) {
      if (mounted) {
        showSuccessSnackBar(context, "Erreur lors de la sauvegarde du profil : $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _toggleFavoriteCategory(User user, String category) async {
    setState(() {
      final exists = _favoriteCategories.contains(category);
      if (exists) {
        _favoriteCategories.remove(category);
        _selectedFavoriteCategories.remove(category);
        _selectedFavoriteSubcategories.remove(category);
      } else {
        _favoriteCategories.add(category);
        _selectedFavoriteCategories.add(category);
        if (category.contains('—')) {
          _selectedFavoriteSubcategories.add(category);
        }
      }
    });
    await _saveProfile(user);
  }

  // ignore: unused_element
  Future<void> _toggleFavoriteSubcategory(User user, String subcategory) async {
    setState(() {
      if (_selectedFavoriteSubcategories.contains(subcategory)) {
        _selectedFavoriteSubcategories.remove(subcategory);
      } else {
        _selectedFavoriteSubcategories.add(subcategory);
      }
    });
    await _saveProfile(user);
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          setState(() => _isLoading = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await _auth.signInWithCredential(credential);
      }

      await _trackLogin();

      if (!mounted) return;
      showSuccessSnackBar(context, "Connecté avec Google");
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, "Erreur Google : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      if (!mounted) return;
      showSuccessSnackBar(context, "Connexion Apple dispo uniquement sur iOS / macOS.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      await _auth.signInWithCredential(oauthCredential);

      await _trackLogin();

      if (!mounted) return;
      showSuccessSnackBar(context, "Connecté avec Apple");
    } catch (e) {
      if (!mounted) return;
      showSuccessSnackBar(context, "Connexion Apple indisponible ou erreur : $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (!kIsWeb) {
        final googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      }
      SessionState.userId = null;
      await CrashlyticsContext.setUserId(null);
    } catch (_) {}
  }

  Widget _buildAuthForm() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
        title: const Text(
          "Mon compte iliprestō",
          style: kPrestoAppBarTitleStyle,
        ),
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoginMode
                      ? "Se connecter à iliprestō"
                      : "Créer un compte iliprestō",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Un compte te permet de gérer tes offres, tes messages et ta visibilité.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: "Email",
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Indique un email";
                          }
                          if (!value.contains('@')) {
                            return "Email invalide";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: "Mot de passe",
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.trim().length < 6) {
                            return "Au moins 6 caractères";
                          }
                          return null;
                        },
                      ),
                      if (!_isLoginMode) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordConfirmController,
                          decoration: const InputDecoration(
                            labelText: "Confirme le mot de passe",
                          ),
                          obscureText: true,
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrestoOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () {
                                  if (_isLoginMode) {
                                    _signInWithEmail();
                                  } else {
                                    _registerWithEmail();
                                  }
                                },
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  _isLoginMode
                                      ? "Se connecter"
                                      : "Créer mon compte",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
                      });
                    },
                    child: Text(
                      _isLoginMode
                          ? "Pas encore de compte ? S’inscrire"
                          : "Déjà un compte ? Se connecter",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: kPrestoBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  "Ou se connecter avec",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.black12),
                      backgroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: Image.asset(
                      'assets/images/google_g.png',
                      width: 18,
                      height: 18,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.login,
                            size: 18, color: Colors.red);
                      },
                    ),
                    label: const Text(
                      "Continuer avec Google",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.black12),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _signInWithApple,
                    icon: const Icon(
                      Icons.apple,
                      size: 20,
                    ),
                    label: const Text(
                      "Continuer avec Apple",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Vous êtes une entreprise ?",
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Créez un profil Pro pour publier plus facilement et accéder aux options Pro.\n"
                        "Abonnement bientôt disponible.",
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ProProfilePage()),
                            );
                          },
                          icon: const Icon(Icons.business_center_outlined),
                          label: const Text("Créer un compte Pro"),
                        ),
                      ),
                    ],
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

  Widget _buildProfile(User user) {
    SessionState.userId = user.uid;
    // Lier les crash reports à l'utilisateur connecté
    CrashlyticsContext.setUserId(user.uid);

    if (!_profileLoaded) {
      _profileLoaded = true;
      _loadUserProfile(user);
    }

    final pseudo = _profilePseudoController.text.trim();
    final displayName = pseudo.isNotEmpty
        ? pseudo
        : (user.displayName ?? "Utilisateur iliprestō");

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
          title: const Text(
            "Mon compte iliprestō",
            style: kPrestoAppBarTitleStyle,
          ),
          backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: kPrestoOrange.withOpacity(0.1),
                          backgroundImage: user.photoURL != null
                              ? NetworkImage(user.photoURL!)
                              : null,
                          child: user.photoURL == null
                              ? const Icon(
                                  Icons.person,
                                  size: 42,
                                  color: kPrestoOrange,
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email ?? "",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Tu restes connecté automatiquement.\nTu ne seras déconnecté que si tu appuies sur « Se déconnecter ».",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Mon profil",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextField(
                          controller: _profilePseudoController,
                          enabled: _isEditingProfile,
                          decoration: InputDecoration(
                            labelText: "Pseudo",
                            hintText: "Ex : DJ Heat, Stef971...",
                            filled: !_isEditingProfile,
                            fillColor: !_isEditingProfile ? Colors.grey.shade100 : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AbsorbPointer(
                          absorbing: !_isEditingProfile,
                          child: Opacity(
                            opacity: _isEditingProfile ? 1.0 : 0.6,
                            child: Autocomplete<CityRecord>(
                              displayStringForOption: (city) => '${city.name} (${city.cp})',
                              optionsBuilder: (TextEditingValue value) {
                                final query = value.text.trim();
                                if (query.length < 2) {
                                  return const Iterable<CityRecord>.empty();
                                }
                                return CitySearch.instance.search(query, limit: 10);
                              },
                              onSelected: (CityRecord city) {
                                setState(() {
                                  _profileCityController.text = '${city.name} (${city.cp})';
                                });
                              },
                              fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                                // Synchroniser avec le controller principal
                                if (_profileCityController.text.isNotEmpty && 
                                    textController.text != _profileCityController.text) {
                                  textController.text = _profileCityController.text;
                                }
                                
                                return TextField(
                                  controller: textController,
                                  focusNode: focusNode,
                                  enabled: _isEditingProfile,
                                  decoration: InputDecoration(
                                    labelText: "Ville",
                                    hintText: "Ex : Baie-Mahault",
                                    filled: !_isEditingProfile,
                                    fillColor: !_isEditingProfile ? Colors.grey.shade100 : null,
                                  ),
                                  onChanged: (value) {
                                    _profileCityController.text = value;
                                  },
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    child: Container(
                                      constraints: const BoxConstraints(maxHeight: 200),
                                      width: MediaQuery.of(context).size.width - 80,
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder: (context, index) {
                                          final city = options.elementAt(index);
                                          return ListTile(
                                            dense: true,
                                            title: Text('${city.name} (${city.cp})'),
                                            subtitle: Text('Dept ${city.dept}'),
                                            onTap: () => onSelected(city),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        AbsorbPointer(
                          absorbing: !_isEditingProfile,
                          child: Opacity(
                            opacity: _isEditingProfile ? 1.0 : 0.6,
                            child: PhoneInputFieldCompact(
                              controller: _profilePhoneController,
                              labelText: 'Téléphone',
                              hintText: '690123456',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isEditingProfile ? kPrestoOrange : kPrestoBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: _isSavingProfile
                                ? null
                                : () {
                                    if (_isEditingProfile) {
                                      _saveProfile(user);
                                    } else {
                                      setState(() => _isEditingProfile = true);
                                    }
                                  },
                            icon: _isSavingProfile
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Icon(_isEditingProfile ? Icons.save_outlined : Icons.edit_outlined),
                            label: Text(
                              _isSavingProfile
                                  ? "Enregistrement..."
                                  : _isEditingProfile 
                                      ? "Enregistrer mon profil"
                                      : "Modifier mon profil",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Mes messages",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Retrouve toutes les conversations liées à tes offres ou aux offres auxquelles tu as répondu.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const MessagesPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text(
                              "Ouvrir mes messages",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Mes annonces publiées",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RepaintBoundary(
                    child: UserOffersSection(userId: user.uid),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Mes catégories favorites",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RepaintBoundary(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Sélectionne les catégories pour lesquelles tu veux être notifié quand une nouvelle annonce est publiée.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Sélecteur Catégorie
                        DropdownButtonFormField<String>(
                          value: _selectedCategoryInput,
                          hint: const Text('Choisir une catégorie'),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          items: _allFavoriteCategories.map((cat) {
                            final selected = _favoriteCategories.contains(cat);
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Row(
                                children: [
                                  Expanded(child: Text(cat)),
                                  if (selected)
                                    const Icon(Icons.check,
                                        color: kPrestoBlue, size: 18),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (selectedCat) {
                            setState(() {
                              _selectedCategoryInput = selectedCat;
                              _selectedSubCategoryInput = null;
                            });
                            if (selectedCat != null) {
                              _toggleFavoriteCategory(user, selectedCat);
                            }
                          },
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF9F9F9),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Sélecteur Sous-catégorie (dépend de la catégorie choisie)
                        DropdownButtonFormField<String>(
                          value: _selectedSubCategoryInput,
                          hint: Text(_selectedCategoryInput == null
                              ? 'Choisis d’abord une catégorie'
                              : 'Sous-catégorie'),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          items: (_selectedCategoryInput == null
                                  ? <String>[]
                                  : (_subCategoriesByCategory[
                                          _selectedCategoryInput!] ??
                                      []))
                              .map((sub) {
                            final label =
                                '${_selectedCategoryInput ?? ''} — $sub';
                            final selected =
                                _favoriteCategories.contains(label);
                            return DropdownMenuItem<String>(
                              value: sub,
                              child: Row(
                                children: [
                                  Expanded(child: Text(sub)),
                                  if (selected)
                                    const Icon(Icons.check,
                                        color: kPrestoBlue, size: 18),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (selectedSub) {
                            if (selectedSub == null ||
                                _selectedCategoryInput == null) return;
                            setState(() {
                              _selectedSubCategoryInput = selectedSub;
                            });
                            final label =
                                '${_selectedCategoryInput!} — $selectedSub';
                            _toggleFavoriteCategory(user, label);
                          },
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF9F9F9),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Liste des sélections
                        if (_favoriteCategories.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sélections :',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: _favoriteCategories.map((cat) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check,
                                            color: kPrestoBlue, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            cat,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close,
                                              size: 18, color: Colors.black54),
                                          onPressed: () =>
                                              _toggleFavoriteCategory(
                                                  user, cat),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          "Plus tard, ces favoris pourront déclencher des notifications push et un badge sur la cloche de l'accueil.",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          kPrestoOrange.withOpacity(0.15),
                          kPrestoBlue.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: kPrestoOrange.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kPrestoOrange.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kPrestoOrange,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.business_center,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "Vous êtes une entreprise ?",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Créez un profil Pro pour publier plus facilement et accéder aux options Pro.\n"
                          "Abonnement bientôt disponible.",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrestoOrange,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ProProfilePage()),
                              );
                            },
                            icon: const Icon(Icons.business_center_outlined, size: 20),
                            label: const Text(
                              "Créer un compte Pro",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildAdminSpaceEntry(user),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text(
                        "Se déconnecter",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildAdminSpaceEntry(User user) {
    _adminCfgFuture ??= _adminGetMicroIaConfig();

    return FutureBuilder<Map<String, dynamic>>(
      future: _adminCfgFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          // Non-admin => on masque.
          final errStr = snapshot.error.toString();
          if (errStr.contains('permission-denied') ||
              errStr.contains('unauthenticated')) {
            return const SizedBox.shrink();
          }
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kPrestoBlue.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.admin_panel_settings,
                      color: kPrestoBlue.withOpacity(0.95)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Espace admin',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Outils d’administration et réglages Micro-IA.",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminSpacePage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text("Ouvrir l'espace admin"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrestoOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ignore: unused_element
  List<String> _getSubcategoriesForCategory(String category) {
    final subcats = kCategorySubcategories[category] ?? [];
    return ['', ...subcats];
  }

  // ignore: unused_element
  List<String> _getAvailableSubcategories() {
    final allSubcats = <String>{};
    for (final cat in _selectedFavoriteCategories) {
      final subcats = kCategorySubcategories[cat] ?? [];
      allSubcats.addAll(subcats);
    }
    return allSubcats.toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          SessionState.userId = null;
          CrashlyticsContext.setUserId(null);
          return _buildAuthForm();
        } else {
          return _buildProfile(user);
        }
      },
    );
  }
}

// 🔥 SECTION "Mes annonces publiées" dans Mon compte
class UserOffersSection extends StatefulWidget {
  final String userId;

  const UserOffersSection({
    super.key,
    required this.userId,
  });

  @override
  State<UserOffersSection> createState() => _UserOffersSectionState();
}

class _UserOffersSectionState extends State<UserOffersSection> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _offers;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    if (widget.userId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _offers = [];
        });
      }
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('offers')
          .where('ownerId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      if (!mounted) return;
      
      setState(() {
        _offers = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "Erreur lors du chargement de vos annonces.\n$_error",
          style: const TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final docs = _offers ?? [];

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Tu n’as pas encore publié d’annonce.",
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final offerId = doc.id;

            final title = (data['title'] ?? 'Sans titre') as String;
            final location = (data['location'] ?? 'Lieu non précisé') as String;
            final category =
                (data['category'] ?? 'Catégorie non précisée') as String;
            final budget = data['budget'];

            String subtitle = "$location · $category";
            if (budget != null) {
              subtitle += " · ${budget.toString()} €";
            }

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(
                    Icons.work_outline,
                    color: kPrestoOrange,
                  ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditOfferDialog(context, offerId, data);
                    } else if (value == 'delete') {
                      _confirmDeleteOffer(context, offerId, title);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text("Modifier"),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text("Supprimer"),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OfferDetailPage(
                        offerId: offerId,
                        title: title,
                        location: location,
                        category: category,
                        subcategory: data['subcategory'] as String?,
                        budget: budget is num ? budget : null,
                        description: (data['description'] ?? '') as String?,
                        phone: data['phone'] as String?,
                        imageUrls: (data['imageUrls'] as List<dynamic>?)
                                ?.map((e) => e.toString())
                                .toList() ??
                            const [],
                        annonceurId: (data['userId'] ?? '') as String,
                      ),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
  }

  Future<void> _showEditOfferDialog(
    BuildContext context,
    String offerId,
    Map<String, dynamic> data,
  ) async {
    final titleController =
        TextEditingController(text: (data['title'] ?? '') as String);
    final descController =
        TextEditingController(text: (data['description'] ?? '') as String);
    final budgetController = TextEditingController(
      text: data['budget']?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Modifier l’annonce"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: "Titre",
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: "Description",
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: budgetController,
                  decoration: const InputDecoration(
                    labelText: "Budget (€)",
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newTitle = titleController.text.trim();
                final newDesc = descController.text.trim();
                final budgetText = budgetController.text.trim();

                num? newBudget;
                if (budgetText.isNotEmpty) {
                  newBudget = num.tryParse(budgetText.replaceAll(',', '.'));
                }

                await FirebaseFirestore.instance
                    .collection('offers')
                    .doc(offerId)
                    .update({
                  'title': newTitle.isEmpty ? data['title'] : newTitle,
                  'description':
                      newDesc.isEmpty ? data['description'] : newDesc,
                  'budget': newBudget ?? data['budget'],
                });

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  showSuccessSnackBar(context, "Annonce mise à jour ✅");
                }
              },
              child: const Text("Enregistrer"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteOffer(
    BuildContext context,
    String offerId,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Supprimer l’annonce"),
          content: Text(
            'Voulez-vous vraiment supprimer :\n"$title" ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("Supprimer"),
            ),
          ],
        );
      },
    );

    if (!context.mounted) return;

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(offerId)
          .delete();

      if (!context.mounted) return;

      showSuccessSnackBar(context, "Annonce supprimée ✅");
    }
  }
}

// ignore: unused_element
class _RecapRow extends StatelessWidget {
  final String label;
  final String value;

  const _RecapRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
