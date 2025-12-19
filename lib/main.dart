import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'firebase_options.dart';
import 'app_core.dart';
import 'constants.dart';
import 'widgets/offer_card.dart';
import 'widgets/ad_banner.dart';
import 'services/city_search.dart';
import 'services/ai_draft_service.dart';
import 'pages/pro_profile_page.dart';
import 'dev/seed_offers.dart';

import 'package:image_picker/image_picker.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);

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

/// Petit état de session (user connecté ou non)
class SessionState {
  static String? userId;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await CitySearch.instance.ensureLoaded();

  runApp(const PrestoApp());
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrestoOrange,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFDF4EC),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.black26),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kPrestoBlue, width: 1.4),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
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
    return Scaffold(
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
                    onPressed: () => _navigateTo(const HomePage(initialIndex: 2)),
                    child: const Text(
                      "J’offre un job",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
  late final PageController _pageController;
  final PageController _carouselController = PageController();
  int _currentSlide = 0;

  late final AnimationController _categoryController;

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
      title: "Boîte à outils de l’entrepreneur",
      subtitle: "Liens utiles CCI, Région, aides et infos clés.",
      badge: "Pro",
      icon: Icons.business_center_outlined,
    ),
    _HomeSlide(
      title: "Besoin d’un extra pour ce soir ?",
      subtitle: "Serveur, plonge, barman… publiez votre offre.",
      badge: "Restauration",
      icon: Icons.restaurant_outlined,
    ),
    _HomeSlide(
      title: "Jardin, peinture, déménagement",
      subtitle: "Des dizaines de prestataires prêts à accepter.",
      badge: "Maison",
      icon: Icons.handyman_outlined,
    ),
    
    _HomeSlide(
      title: "iliprestō 100% gratuit",
      subtitle: "Publiez vos offres, recevez des réponses.",
      badge: "Gratuit",
      icon: Icons.favorite_border,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addObserver(this);

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
  }

  void _listenDynamicKeywords() {
    FirebaseFirestore.instance.collection('offers').snapshots().listen(
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
        if (mounted) {
          setState(() {
            _dynamicKeywords = words.toList()..sort();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _carouselController.dispose();
    _categoryController.dispose();
    _sloganTimer?.cancel();
    super.dispose();
  }

  /// Force rebuild quand le clavier apparaît/disparaît
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
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
    _pageController.jumpToPage(index);
  }

  void _onPageChanged(int index) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reset + seed des offres en cours…")),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Offres de test réinitialisées et injectées ✅"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors du seed des offres : $e"),
          ),
        );
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
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        if (!_showSearchSuggestions) return const Iterable<String>.empty();
        return _buildSearchSuggestions(value);
      },
      onSelected: (String selection) {
        _goToSearch(selection);
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
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
          onSubmitted: _goToSearch,
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
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Connecte-toi à ton compte pour recevoir les notifications de nouveaux messages et annonces.",
                  ),
                ),
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

                final totalUnread = unreadMessagesCount + unreadNotificationsCount;

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
        title: const Text('Notifications'),
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
                return const Text('Aucune notification pour le moment.');
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
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(message),
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

  /// Illustration à droite du slide (plus de chrono image)
  Widget _buildSlideIllustration(_HomeSlide slide, int index) {
    // On ignore complètement slide.imageAsset, on affiche juste une icône
    return Container(
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
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: kPrestoOrange,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
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
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: _onPageChanged,
          children: [
            _buildHomeContent(),
            const ConsultOffersPage(),
            const PublishOfferPage(),
            const MessagesPage(),
            const AccountPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF9F2EA),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Color(0xFFFDF4EC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ligne du haut : logo + cloche
                Row(
                  children: [
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
                        itemCount: _slides.length,
                        onPageChanged: (index) {
                          setState(() => _currentSlide = index);
                        },
                        itemBuilder: (context, index) {
                          final slide = _slides[index];

                          // 🔥 SLIDE 1 : plein texte, sans image, phrase géante sur toute la largeur
                          if (index == 0) {
                            const String bigText =
                                "Trouvez immédiatement quelqu'un pour faire le job.";

                            return Container(
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
                                        fontSize: 24, // taille bien grosse
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

                          // 🔁 SLIDES 2, 3, 4, 5 : on garde le layout texte + icône / image
                          return Container(
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
                                          index == 0
                                              ? "Trouvez immédiatement quelqu'un pour faire le job."
                                              : slide.title,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: index == 0
                                                ? 22
                                                : 16, // 🔥 plus gros sur le slide 1
                                            fontWeight: FontWeight.w800,
                                            height: 1.3,
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

                                  // 👉 Illustration uniquement à partir du slide 2
                                  if (index != 0) ...[
                                    const SizedBox(width: 8),
                                    _buildSlideIllustration(slide, index),
                                  ],
                                ],
                              ),
                            ),
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

                // DERNIÈRES OFFRES
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Catégorie "$label" : bientôt disponible'),
              ),
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

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
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

class _BottomNavItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    const color = Colors.white;
    final fontWeight = selected ? FontWeight.w700 : FontWeight.w500;

    return _TapScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isBig ? 6 : 4),
              decoration: BoxDecoration(
                color: isBig
                    ? Colors.white
                    : selected
                        ? Colors.white.withOpacity(0.25)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: isBig
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : selected
                        ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
              ),
              child: Icon(
                icon,
                size: isBig ? 26 : 22,
                color: isBig ? kPrestoOrange : color,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 70,
              child: Text(
                label,
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

  const ConsultOffersPage({
    super.key,
    this.categoryFilter,
    this.searchQuery,
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

  bool _showFilters = true;

  late final Map<String, String> _deptToRegion = _buildDeptToRegion();

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

    if (widget.categoryFilter != null && widget.categoryFilter!.isNotEmpty) {
      _selectedCategory = widget.categoryFilter;
    } else {
      _selectedCategory = 'Toutes catégories';
    }

    _selectedRegionCode = null; // Pas de région sélectionnée par défaut

    // ✅ Si un searchQuery est fourni, l'initialiser dans le champ de mot-clé
    final initialQuery = widget.searchQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _activeSearchQuery = initialQuery;
      _keywordCtrl.text = initialQuery;
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
      _activeSearchQuery = _keywordCtrl.text.trim().isEmpty
          ? null
          : _keywordCtrl.text.trim();
      _queryKey++;
      _lastDoc = null; // Reset pagination
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

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
      _filterPanelKey++; // force rebuild pour éviter états résiduels
    });

    if (_showFilters && _scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final baseTitle = widget.categoryFilter == null
        ? "Je consulte les offres"
        : "Offres : ${widget.categoryFilter!}";

    return Scaffold(
      resizeToAvoidBottomInset: false,
      // Fond blanc derrière les annonces pour un look plus clair
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            baseTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        actions: [
            IconButton(
              icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
              tooltip: _showFilters ? 'Masquer les filtres' : 'Afficher les filtres',
              onPressed: _toggleFilters,
            ),
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
          _buildFilterPanel(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              key: ValueKey(_queryKey), // Force la reconstruction quand les filtres changent
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

                if (docs.isEmpty) {
                  return const _EmptyOffers();
                }

                const int _adsEvery = 8; // Bandeau pub après chaque 8 annonces
                final int _adSlots = docs.length ~/ _adsEvery;
                final int _totalItems = docs.length + _adSlots;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 120),
                  itemCount: _totalItems,
                  itemBuilder: (context, index) {
                    final bool isAd = (index + 1) % (_adsEvery + 1) == 0;
                    if (isAd) {
                      return const AdBanner(margin: EdgeInsets.symmetric(vertical: 8));
                    }

                    final int docIndex = index - (index ~/ (_adsEvery + 1));
                    final doc = docs[docIndex];
                    final offerId = doc.id;
                    final data = doc.data();

                    final title = (data['title'] ?? 'Sans titre') as String;
                    final location = (data['location'] ?? 'Lieu non précisé') as String;
                    final category = (data['category'] ?? 'Catégorie non précisée') as String;
                    final budget = data['budget'];
                    final description = (data['description'] ?? '') as String;
                    final phone = data['phone'] == null ? null : data['phone'] as String;

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
                                title: title,
                                location: location,
                                category: category,
                                subcategory: (data['subcategory'] ?? '') as String?,
                                budget: budget is num ? budget : null,
                                description: description.isEmpty ? null : description,
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
                );
              },
            ),
          ),
        ],
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

class OfferDetailPage extends StatelessWidget {
  final String title;
  final String location;
  final String category;
  final String? subcategory;
  final num? budget;
  final String? description;
  final String? phone;
  final List<String>? imageUrls;
  final String annonceurId;

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
  });

  Future<void> _callPhone(BuildContext context) async {
    if (phone == null || phone!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun numéro disponible.")),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    final uri = Uri(
      scheme: 'tel',
      path: phone!.trim(),
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Impossible de lancer l’appel sur cet appareil."),
          ),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Une erreur est survenue lors de l’appel."),
        ),
      );
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
                    final annonceurId = this.annonceurId;
                    if (annonceurId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text("Impossible de retrouver l'annonceur.")),
                      );
                      return;
                    }

                    // Cherche ou crée la conversation entre l'utilisateur courant et l'annonceur
                    final convs = await FirebaseFirestore.instance
                        .collection('conversations')
                        .where('participants', arrayContains: user.uid)
                        .get();
                    String? conversationId;
                    for (final doc in convs.docs) {
                      final parts =
                          List<String>.from(doc['participants'] ?? []);
                      if (parts.contains(annonceurId)) {
                        conversationId = doc.id;
                        break;
                      }
                    }
                    if (conversationId == null) {
                      final doc = await FirebaseFirestore.instance
                          .collection('conversations')
                          .add({
                        'participants': [user.uid, annonceurId],
                        'createdAt': FieldValue.serverTimestamp(),
                        'lastMessage': '',
                        'unreadCount': {user.uid: 0, annonceurId: 0},
                      });
                      conversationId = doc.id;
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ConversationPage(
                          conversationId: conversationId!,
                          offerTitle: title,
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

  @override
  Widget build(BuildContext context) {
    final budgetText =
        budget == null ? "À définir" : "${budget!.toStringAsFixed(2)} €";
    final bool hasPhone = phone != null && phone!.trim().isNotEmpty;

    // 🔥 Photos (0, 1 ou 2)
    final List<String> photos = imageUrls ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Détail de l’offre",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre de l’offre
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),

            // Métadonnées (lieu / catégorie / budget / téléphone)
            _OfferMetaRow(
              icon: Icons.place_outlined,
              text: location,
            ),
            const SizedBox(height: 8),
            _OfferMetaRow(
              icon: Icons.category_outlined,
              text: category,
            ),
            if (subcategory != null && subcategory!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _OfferMetaRow(
                icon: Icons.label_outline,
                text: subcategory!,
              ),
            ],
            const SizedBox(height: 8),
            _OfferMetaRow(
              icon: Icons.euro_outlined,
              text: budgetText,
            ),
            const SizedBox(height: 8),
            _OfferMetaRow(
              icon: Icons.phone_android_outlined,
              text: hasPhone ? "Numéro disponible" : "Numéro non renseigné",
            ),

            const SizedBox(height: 22),

            const Text(
              "Description",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            // Bloc central scrollable : description + photos + pub
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (description == null || description!.trim().isEmpty)
                                ? "Aucune description détaillée fournie."
                                : description!,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ✅ Si photos, on les affiche ; sinon, on affiche une grande pub
                          if (photos.isNotEmpty) ...[
                            const Text(
                              "Photos de l’annonce",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 190,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildPhotoTile(
                                      url: photos.isNotEmpty ? photos[0] : null,
                                      primary: true,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildPhotoTile(
                                      url: photos.length > 1 ? photos[1] : null,
                                      primary: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                          ],

                          const Text(
                            "Publicité",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: photos.isEmpty
                                ? 190
                                : 100, // ✅ Si pas de photos → grande bannière
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                color: Colors.white,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.black12,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "Espace Google Ads\nBannière 320x100",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Bouton principal
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrestoOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                onPressed: () => _showActionSheet(context),
                child: const Text(
                  "J’accepte l’offre",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoTile({String? url, bool primary = false}) {
    if (url == null || url.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: primary ? const Color(0xFFFFF3E0) : Colors.white,
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.add_a_photo_outlined,
          size: primary ? 44 : 36,
          color: primary ? Colors.black45 : Colors.black26,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: Colors.grey[200],
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.image, size: 24, color: kPrestoOrange),
          ),
        ),
      ),
    );
  }
}

/// Ligne méta avec icône dans un rond orange premium
class _OfferMetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _OfferMetaRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: kPrestoOrange,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

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
        title: const Text(
          "Mes messages",
          style: TextStyle(fontWeight: FontWeight.w700),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Mes messages",
          style: TextStyle(fontWeight: FontWeight.w700),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Connecte-toi à ton compte pour envoyer des messages iliprestō."),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l’envoi du message : $e"),
        ),
      );
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
    final messenger = ScaffoldMessenger.of(context);
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

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content:
              Text("Impossible d’ouvrir le client email sur cet appareil."),
        ),
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

    return Scaffold(
      appBar: AppBar(
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
              child: Text(
                widget.offerTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
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
    );
  }
}

/// PAGE PUBLIER UNE OFFRE //////////////////////////////////////////////////

class PublishOfferPage extends StatefulWidget {
  const PublishOfferPage({super.key});

  @override
  State<PublishOfferPage> createState() => _PublishOfferPageState();
}

class _PublishOfferPageState extends State<PublishOfferPage> {
  final _formKey = GlobalKey<FormState>();

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
  String _sttTranscript = '';
  String _sttFinalTranscript = '';

  // Service IA pour analyser la description
  final AiDraftService _aiService = AiDraftService();
  final stt.SpeechToText _stt = stt.SpeechToText();
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;
  // Toujours actif (améliore la qualité via Google STT côté serveur)
  final bool _useCloudStt = true;

  Future<void> _startMic() async {
    if (_isListening) return;
    // Préparer l'enregistreur haute qualité (WAV)
    if (!kIsWeb) {
      try {
        if (await _recorder.hasPermission()) {
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/presto_${DateTime.now().millisecondsSinceEpoch}.wav';
          await _recorder.start(
            RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: 16000,
              numChannels: 1,
              bitRate: 256000,
            ),
            path: filePath,
          );
          _recordingPath = filePath;
        }
      } catch (e) {
        debugPrint('Recorder start error: $e');
      }
    }
    final available = await _stt.initialize(
      onStatus: (s) {
        debugPrint('STT Status: $s');
      },
      onError: (e) {
        if (!mounted) return;
        debugPrint('STT Error: ${e.errorMsg}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur micro: ${e.errorMsg}')),
        );
      },
    );
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dictée non disponible sur cet appareil')),
      );
      return;
    }
    setState(() {
      _isListening = true;
      _sttTranscript = '';
      _sttFinalTranscript = '';
    });
    await _stt.listen(
      localeId: 'fr_FR',
      // Paramètres pour améliorer la qualité audio sur Android
      listenMode: stt.ListenMode.confirmation,
      cancelOnError: false,
      partialResults: true,
      listenFor: const Duration(seconds: 60), // Durée max d'écoute
      pauseFor: const Duration(seconds: 5),   // Durée de pause avant arrêt auto
      // Optimisation pour Android
      sampleRate: 16000, // Fréquence d'échantillonnage optimale
      onResult: (result) {
        setState(() {
          _sttTranscript = result.recognizedWords;
          if (result.finalResult) {
            _sttFinalTranscript = result.recognizedWords;
          }
        });
        debugPrint('STT Result: ${result.recognizedWords} (final: ${result.finalResult})');
      },
    );
  }

  Future<void> _stopMic() async {
    if (!_isListening) return;
    await _stt.stop();
    String? recordedPath;
    if (!kIsWeb) {
      try {
        recordedPath = await _recorder.stop();
        if (recordedPath == null) {
          recordedPath = _recordingPath;
        }
      } catch (e) {
        debugPrint('Recorder stop error: $e');
      }
    }
    setState(() {
      _isListening = false;
    });
    // Si l'audio est disponible et cloud STT activé, on passe par la fonction distante
    if (_useCloudStt && recordedPath != null && !kIsWeb) {
      setState(() => _isAnalyzing = true);
      try {
        await _uploadAndTranscribe(recordedPath);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur transcription: $e')),
        );
      } finally {
        if (mounted) setState(() => _isAnalyzing = false);
      }
      return;
    }

    // Fallback: utilisation texte local STT
    final text = (_sttFinalTranscript.isNotEmpty ? _sttFinalTranscript : _sttTranscript).trim();
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun texte reconnu')),
      );
      return;
    }
    setState(() => _isAnalyzing = true);
    try {
      final draft = await _aiService.generateOfferDraft(text: text);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Dictée analysée et champs remplis'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur IA: ${draft['error'] ?? 'inconnue'}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur analyse: $e')),
      );
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _uploadAndTranscribe(String localPath) async {
    // Upload vers Firebase Storage puis appel de la Cloud Function transcribeAndDraftOffer
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'anonymous';
    final file = File(localPath);
    if (!await file.exists()) {
      throw 'Fichier audio introuvable';
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    final storage = FirebaseStorage.instance;
    final destPath = 'voice_inputs/$uid/$ts.wav';
    final ref = storage.ref(destPath);
    await ref.putFile(file, SettableMetadata(contentType: 'audio/wav'));
    final bucket = ref.bucket; // Reference exposes bucket
    final gsUri = 'gs://$bucket/${ref.fullPath}';

    final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = functions.httpsCallable('transcribeAndDraftOffer');
    final res = await callable.call<dynamic>({
      'gcsUri': gsUri,
      'languageCode': 'fr-FR',
    });

    final data = (res.data as Map<dynamic, dynamic>);
    if (mounted) {
      setState(() {
        final title = (data['title'] ?? '').toString();
        final description = (data['description'] ?? '').toString();
        final category = (data['category'] ?? '').toString();
        final city = (data['city'] ?? '').toString();
        final postal = (data['postalCode'] ?? '').toString();

        if (title.isNotEmpty) _titleController.text = title;
        if (description.isNotEmpty) _descriptionController.text = description;
        if (category.isNotEmpty) {
          _category = category;
          _selectedSubCategory = null;
        }
        if (city.isNotEmpty) _locationController.text = city;
        if (postal.isNotEmpty) _postalCodeController.text = postal;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✨ Transcription réussie et champs remplis')),
    );
  }

  /// Appelle la Cloud Function pour analyser la description avec OpenAI
  // ignore: unused_element
  Future<void> _onTapAiAnalyze() async {
    final input = _descriptionController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord saisir une description'),
          duration: Duration(seconds: 2),
        ),
      );
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Analyse IA complétée\nChamps remplis automatiquement'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur IA : ${draft['error'] ?? 'Erreur inconnue'}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'analyse : $e'),
          duration: const Duration(seconds: 2),
        ),
      );
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
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✨ Tous les champs ont été réinitialisés'),
        duration: Duration(seconds: 2),
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 2 photos autorisées')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection : $e')),
      );
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
        await ref.putFile(
          File(photo.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );

        final url = await ref.getDownloadURL();
        _uploadedPhotoUrls.add(url);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'upload : $e')),
      );
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
    try {
      // Récupérer tous les utilisateurs ayant cette catégorie en favori
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('favoriteCategories', arrayContains: category)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      final now = Timestamp.now();

      for (final userDoc in usersQuery.docs) {
        // Ne pas notifier l'auteur de l'annonce
        if (userDoc.id == publisherUserId) continue;

        final userData = userDoc.data();
        final selectedFavoriteCats =
            (userData['selectedFavoriteCategories'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final selectedFavoriteSubcats =
            (userData['selectedFavoriteSubcategories'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        // Vérifier si la catégorie est sélectionnée
        bool shouldNotify = selectedFavoriteCats.contains(category);

        // Si une sous-catégorie est spécifiée, vérifier aussi
        if (subCategory != null && subCategory.isNotEmpty) {
          shouldNotify = shouldNotify && 
              (selectedFavoriteSubcats.isEmpty || 
               selectedFavoriteSubcats.contains(subCategory));
        }

        if (shouldNotify) {
          // Créer la notification
          final notifRef = FirebaseFirestore.instance
              .collection('notifications')
              .doc();

          batch.set(notifRef, {
            'userId': userDoc.id,
            'offerId': offerId,
            'title': 'Nouvelle offre : $category',
            'message': offerTitle,
            'category': category,
            'subCategory': subCategory,
            'read': false,
            'createdAt': now,
          });
        }
      }

      await batch.commit();
    } catch (e) {
      // Erreur silencieuse, ne pas bloquer la publication
      debugPrint('Erreur lors de la création des notifications : $e');
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre offre a été publiée 🎉'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la publication : $e'),
        ),
      );
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: kPrestoOrange,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Je publie une offre',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Réinitialiser tous les champs',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Réinitialiser ?'),
                  content: const Text(
                    'Voulez-vous effacer tous les champs et recommencer ?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _resetAllFields();
                      },
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Détail de votre besoin',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // Bouton IA pleine largeur avec enregistrement audio
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening ? Colors.red : kPrestoBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isAnalyzing ? null : (_isListening ? _stopMic : _startMic),
                  icon: _isListening 
                    ? const Icon(Icons.stop_circle, size: 28)
                    : const Icon(Icons.mic),
                  label: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _isListening ? 'Appuyer pour arrêter l\'enregistrement' : 'Décris ton besoin (IA)',
                      key: ValueKey(_isListening),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
                    child: Container
                      (
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kPrestoBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: kPrestoBlue.withOpacity(0.25)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kPrestoBlue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: kPrestoBlue.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _useCloudStt && !kIsWeb
                            ? const Icon(Icons.cloud_sync, size: 16, color: kPrestoBlue)
                            : SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(kPrestoBlue),
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
                decoration: const InputDecoration(
                  labelText: 'Titre de l’offre',
                  border: OutlineInputBorder(),
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
                decoration: InputDecoration(
                  labelText: 'Catégorie',
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
                  decoration: InputDecoration(
                    labelText: 'Sous-catégorie',
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
                  },
                ),
              if (_category != null) const SizedBox(height: 16),

              // DESCRIPTION
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description détaillée',
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
                  labelText: 'Ville',
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

              // TÉLÉPHONE
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Téléphone (pour être rappelé)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Montant (€)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      enabled: _budgetType == 'Fixe',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // BOUTON PUBLIER
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitForm,
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
        child: Image.file(
          File(localFile.path),
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
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
    'Bricolage / Travaux': ['Montage meuble', 'Électricité', 'Plomberie', 'Peinture'],
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
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _profilePseudoController.dispose();
    _profileCityController.dispose();
    _profilePhoneController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connexion réussie ✅")),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Erreur de connexion.")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text.trim() !=
        _passwordConfirmController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Les mots de passe ne correspondent pas.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Compte créé et connecté ✅")),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Erreur lors de l’inscription."),
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil mis à jour ✅")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la sauvegarde du profil : $e"),
          ),
        );
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connecté avec Google ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur Google : $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Connexion Apple dispo uniquement sur iOS / macOS.",
          ),
        ),
      );
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connecté avec Apple ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Connexion Apple indisponible ou erreur : $e",
          ),
        ),
      );
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
    } catch (_) {}
  }

  Widget _buildAuthForm() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Mon compte iliprestō",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
    );
  }

  Widget _buildProfile(User user) {
    SessionState.userId = user.uid;

    if (!_profileLoaded) {
      _profileLoaded = true;
      _loadUserProfile(user);
    }

    final pseudo = _profilePseudoController.text.trim();
    final displayName = pseudo.isNotEmpty
        ? pseudo
        : (user.displayName ?? "Utilisateur iliprestō");

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Mon compte iliprestō",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrestoBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomePage()),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.home_outlined),
                      label: const Text(
                        "Retour à l’accueil",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                          decoration: const InputDecoration(
                            labelText: "Pseudo",
                            hintText: "Ex : DJ Heat, Stef971...",
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _profileCityController,
                          decoration: const InputDecoration(
                            labelText: "Ville",
                            hintText: "Ex : Baie-Mahault",
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _profilePhoneController,
                          decoration: const InputDecoration(
                            labelText: "Téléphone",
                            hintText: "Ex : 0690 12 34 56",
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrestoOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: _isSavingProfile
                                ? null
                                : () => _saveProfile(user),
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
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _isSavingProfile
                                  ? "Enregistrement..."
                                  : "Enregistrer mon profil",
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
                  UserOffersSection(userId: user.uid),
                  const SizedBox(height: 24),
                  const Text(
                    "Mes catégories favorites",
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
                          items: _allFavoriteCategories.map((cat) {
                            final selected = _favoriteCategories.contains(cat);
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Row(
                                children: [
                                  Expanded(child: Text(cat)),
                                  if (selected)
                                    const Icon(Icons.check, color: kPrestoBlue, size: 18),
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          items: (_selectedCategoryInput == null
                                  ? <String>[]
                                  : (_subCategoriesByCategory[_selectedCategoryInput!] ?? []))
                              .map((sub) {
                            final label = '${_selectedCategoryInput ?? ''} — $sub';
                            final selected = _favoriteCategories.contains(label);
                            return DropdownMenuItem<String>(
                              value: sub,
                              child: Row(
                                children: [
                                  Expanded(child: Text(sub)),
                                  if (selected)
                                    const Icon(Icons.check, color: kPrestoBlue, size: 18),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (selectedSub) {
                            if (selectedSub == null || _selectedCategoryInput == null) return;
                            setState(() {
                              _selectedSubCategoryInput = selectedSub;
                            });
                            final label = '${_selectedCategoryInput!} — $selectedSub';
                            _toggleFavoriteCategory(user, label);
                          },
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check, color: kPrestoBlue, size: 18),
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
                                          icon: const Icon(Icons.close, size: 18, color: Colors.black54),
                                          onPressed: () => _toggleFavoriteCategory(user, cat),
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
                  const SizedBox(height: 28),
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
          return _buildAuthForm();
        } else {
          return _buildProfile(user);
        }
      },
    );
  }
}

// 🔥 SECTION "Mes annonces publiées" dans Mon compte
class UserOffersSection extends StatelessWidget {
  final String userId;

  const UserOffersSection({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('ownerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Erreur lors du chargement de vos annonces.\n${snapshot.error}",
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

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
      },
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Annonce mise à jour ✅"),
                    ),
                  );
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
    final messenger = ScaffoldMessenger.of(context);

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

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(offerId)
          .delete();

      messenger.showSnackBar(
        const SnackBar(content: Text("Annonce supprimée ✅")),
      );
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              "$label :",
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
