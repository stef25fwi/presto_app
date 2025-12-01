import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_page.dart';

import 'firebase_options.dart';

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

final List<String> kCityNames = kCityPostalMap.keys.toList();

/// Petit état de session (user connecté ou non)
class SessionState {
  static String? userId;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PrestoApp());
}

class PrestoApp extends StatelessWidget {
  const PrestoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prestō',
      debugShowCheckedModeBanner: false,
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
                    'Prestō',
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
                  'Trouvez un prestataire\nillico presto',
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
                    onPressed: () => _navigateTo(const PublishOfferPage()),
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

/// Micro-animation au tap
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _TapScale({required this.child, this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _down(_) => setState(() => _scale = 0.96);
  void _up(_) => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}

/// Modèle carrousel
class _HomeSlide {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;

  const _HomeSlide({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
  });
}

/// HOME ///////////////////////////////////////////////////////////////////

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final PageController _carouselController = PageController();
  int _currentSlide = 0;

  late final AnimationController _categoryController;

  bool _isSeeding = false;

  /// Slogans animés (fade) pour Prestō
  final List<String> _firstSlideSlogans = const [
    "Disponible en quelques secondes…",
    "Trouvez un prestataire autour de vous",
    "Publiez… ils arrivent !",
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

  final List<_HomeSlide> _slides = const [
    _HomeSlide(
      title: "Slogans Prestō animés",
      subtitle:
          "Contact instantané avec des personnes disponibles autour de vous.",
      badge: "Nouveau",
      icon: Icons.flash_on_outlined,
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
      title: "Boîte à outils de l’entrepreneur",
      subtitle: "Liens utiles CCI, Région, aides et infos clés.",
      badge: "Pro",
      icon: Icons.business_center_outlined,
    ),
    _HomeSlide(
      title: "Prestō 100% gratuit",
      subtitle: "Publiez vos offres, recevez des réponses.",
      badge: "Gratuit",
      icon: Icons.favorite_border,
    ),
  ];

  @override
  void initState() {
    super.initState();

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
  }

  void _listenDynamicKeywords() {
    FirebaseFirestore.instance
        .collection('offers')
        .snapshots()
        .listen((snapshot) {
      final words = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final title = (data['title'] ?? '').toString().toLowerCase();
        final description =
            (data['description'] ?? '').toString().toLowerCase();
        final combined = '$title $description';
        for (final word in combined.split(RegExp(r'\\s+'))) {
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
    });
  }

  @override
  void dispose() {
    _carouselController.dispose();
    _categoryController.dispose();
    _sloganTimer?.cancel();
    super.dispose();
  }

  double _categoryScaleForIndex(int index) {
    const count = 4;
    final t = _categoryController.value * count;
    final active = t.floor() % count;
    final localT = t - t.floor();
    if (index == active) {
      return 1.0 + 0.25 * (1 - (localT - 0.5) * (localT - 0.5) * 4);
    }
    return 1.0;
  }

  void _onBottomTap(int index) {
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PublishOfferPage()),
      );
      return;
    }
    if (index == 0) {
      setState(() => _selectedIndex = 0);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ConsultOffersPage()),
      );
      return;
    }
    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MessagesPage()),
      );
      return;
    }
    if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AccountPage()),
      );
      return;
    }
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

  /// Moteur de suggestions “smart” pour la barre de recherche
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

    final col = FirebaseFirestore.instance.collection('offers');

    Future<void> addOffer({
      required String title,
      required String description,
      required String location,
      required String postalCode,
      required String category,
      required num budget,
      String? phone,
    }) async {
      await col.add({
        'title': title,
        'description': description,
        'location': location,
        'postalCode': postalCode,
        'category': category,
        'budget': budget,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await addOffer(
        title: "Serveur Jarry ce soir",
        description:
            "Restaurant à Baie-Mahault (Jarry) recherche un serveur pour le service de ce soir.",
        location: "Baie-Mahault (Jarry)",
        postalCode: "97122",
        category: "Restauration / Extra",
        budget: 60,
        phone: "0690 00 00 01",
      );
      await addOffer(
        title: "Peintre chambre 30 m²",
        description: "Peinture chambre à Saint-François, mission URGENTE.",
        location: "Saint-François",
        postalCode: "97118",
        category: "Peinture",
        budget: 150,
        phone: "0690 00 00 03",
      );
      await addOffer(
        title: "Jardinage Petit-Bourg demain",
        description:
            "Entretien jardin et petite taille de haie, idéal demain matin.",
        location: "Petit-Bourg",
        postalCode: "97170",
        category: "Jardinage",
        budget: 80,
        phone: "0690 00 00 05",
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Offres de démonstration ajoutées ✅")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de l’ajout des offres de démo : $e"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  /// Texte “quand ?” pour les dernières offres (ce soir / urgent / demain / bientôt)
  String _labelWhenFromTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('urgent')) return 'urgent';
    if (lower.contains('ce soir')) return 'ce soir';
    if (lower.contains('demain')) return 'demain';
    return 'bientôt';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                            "Prestō",
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
                    _TapScale(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text("Notifications : bientôt disponibles"),
                          ),
                        );
                      },
                      child: Stack(
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
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: kPrestoOrange,
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                "2",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Barre de recherche (halo + auto-complétion smart)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: RawAutocomplete<String>(
                    optionsBuilder: _buildSearchSuggestions,
                    onSelected: (String selected) {
                      _goToSearch(selected);
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return Row(
                        children: [
                          const Icon(Icons.search, color: Colors.black38),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                hintText:
                                    "Ex : jardinage aujourd’hui, serveur ce soir…",
                                border: InputBorder.none,
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              textInputAction: TextInputAction.search,
                              onSubmitted: _goToSearch,
                              enableSuggestions: true,
                              autocorrect: true,
                            ),
                          ),
                        ],
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 220,
                              minWidth: 260,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(
                                    option,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Carrousel
                SizedBox(
                  height: 200,
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
                          final String animatedText =
                              _firstSlideSlogans[_sloganIndex];

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 2, vertical: 4),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF8A50),
                                    kPrestoOrange,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
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
                                          const SizedBox(height: 4),
                                          if (index == 0)
                                            AnimatedSwitcher(
                                              duration: const Duration(
                                                  milliseconds: 450),
                                              transitionBuilder:
                                                  (child, animation) {
                                                return FadeTransition(
                                                  opacity: animation,
                                                  child: child,
                                                );
                                              },
                                              child: Text(
                                                animatedText,
                                                key: ValueKey(animatedText),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.3,
                                                ),
                                              ),
                                            )
                                          else
                                            Text(
                                              slide.title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                height: 1.3,
                                              ),
                                            ),
                                          const SizedBox(height: 6),
                                          Text(
                                            slide.subtitle,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.18),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        slide.icon,
                                        color: kPrestoBlue,
                                        size: 32,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _slides.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentSlide == index ? 18 : 8,
                              height: 8,
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

                const SizedBox(height: 18),

                // Catégories
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
                          const SizedBox(width: 12),
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
                          const SizedBox(width: 12),
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
                          const SizedBox(width: 12),
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
                          const SizedBox(width: 12),
                          _CategoryChip(
                            icon: Icons.child_care_outlined,
                            label: "Garde enfants",
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
                          const SizedBox(width: 12),
                          _CategoryChip(
                            icon: Icons.music_note_outlined,
                            label: "DJ / Sono",
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

                const SizedBox(height: 24),

                // BLOC COMMENT ÇA MARCHE ? ///////////////////////////
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
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
                      SizedBox(height: 10),
                      _HowItWorksStep(
                        stepNumber: 1,
                        title: "Je publie une offre",
                        description:
                            "En quelques lignes, vous décrivez votre besoin et votre lieu.",
                      ),
                      SizedBox(height: 8),
                      _HowItWorksStep(
                        stepNumber: 2,
                        title: "Ils la reçoivent en direct",
                        description:
                            "Les prestataires proches sont notifiés et voient immédiatement votre offre.",
                      ),
                      SizedBox(height: 8),
                      _HowItWorksStep(
                        stepNumber: 3,
                        title: "Ils me contactent aussitôt",
                        description:
                            "Vous échangez et choisissez la personne idéale pour le job.",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // SECTION GÉOLOCALISÉE DYNAMIQUE /////////////////////////////
                const Text(
                  "Autour de vous",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Prestataires proches :",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: const [
                    _GeoChip(label: "Baie-Mahault"),
                    _GeoChip(label: "Les Abymes"),
                    _GeoChip(label: "Le Gosier"),
                    _GeoChip(label: "Petit-Bourg"),
                    _GeoChip(label: "Pointe-à-Pitre"),
                  ],
                ),

                const SizedBox(height: 24),

                // PRÉVISUALISATION DES DERNIÈRES OFFRES //////////////////////
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
                      onPressed: () => _onBottomTap(0),
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
                const SizedBox(height: 6),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('offers')
                      .orderBy('createdAt', descending: true)
                      .limit(3)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
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
                        final title =
                            (data['title'] ?? 'Sans titre') as String;
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
                                    budget: data['budget'] is num
                                        ? data['budget'] as num
                                        : null,
                                    description:
                                        (data['description'] ?? '') as String?,
                                    phone: data['phone'] as String?,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF3E0),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.flash_on_outlined,
                                      color: kPrestoOrange,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
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
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 20,
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

                const SizedBox(height: 24),

                // SECTION EXISTANTE : D’après vos dernières recherches ///////
                const Text(
                  "D’après vos dernières recherches",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Text(
                      "Services à la personne",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Spacer(),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Colors.black45,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      _ServiceCard(
                        label: "Nettoyage",
                        icon: Icons.cleaning_services_outlined,
                        badge: "Populaire",
                      ),
                      _ServiceCard(
                        label: "Tonte",
                        icon: Icons.grass_outlined,
                        badge: "Saison",
                      ),
                      _ServiceCard(
                        label: "Serveur",
                        icon: Icons.restaurant_outlined,
                        badge: "Week-end",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: kPrestoOrange,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomNavItem(
                icon: Icons.search,
                label: "Je consulte\nles offres",
                selected: _selectedIndex == 0,
                onTap: () => _onBottomTap(0),
              ),
              _BottomNavItem(
                icon: Icons.add_circle_outline,
                label: "Publier\nune offre",
                isBig: true,
                onTap: () => _onBottomTap(1),
              ),
              _BottomNavItem(
                icon: Icons.chat_bubble_outline,
                label: "Messages",
                selected: _selectedIndex == 2,
                onTap: () => _onBottomTap(2),
              ),
              _BottomNavItem(
                icon: Icons.person_outline,
                label: "Compte",
                selected: _selectedIndex == 3,
                onTap: () => _onBottomTap(3),
              ),
            ],
          ),
        ),
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
          // Rond orange + pictogramme blanc + bord bleu fin
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

class _ServiceCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String badge;

  const _ServiceCard({
    required this.label,
    required this.icon,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exemples d’offres "$label" à venir')),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          icon,
                          size: 42,
                          color: Colors.black45,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
    final color = Colors.white;
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
                color: isBig ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: isBig
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
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

/// CHIP GEO ////////////////////////////////////////////////////////////////

class _GeoChip extends StatelessWidget {
  final String label;

  const _GeoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_outlined,
              size: 14, color: kPrestoOrange),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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

class _ConsultOffersPageState extends State<ConsultOffersPage> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _subCategoryController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();

  String? _selectedCategory;

  final List<String> _categories = const [
    'Toutes catégories',
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

  bool _showLocationSuggestions = false;

  List<String> get _citySuggestions {
    final text = _locationController.text.trim().toLowerCase();
    if (!_showLocationSuggestions) return [];
    if (text.length < 2) return [];
    return kCityNames
        .where((c) => c.toLowerCase().contains(text))
        .take(5)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    if (widget.categoryFilter != null && widget.categoryFilter!.isNotEmpty) {
      _selectedCategory = widget.categoryFilter;
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _subCategoryController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('offers');

    bool hasFilter = false;

    final loc = _locationController.text.trim();
    final subcat = _subCategoryController.text.trim();
    final cat = _selectedCategory;
    final cp = _postalCodeController.text.trim();

    if (loc.isNotEmpty) {
      hasFilter = true;
      query = query.where('location', isEqualTo: loc);
    }

    if (cp.isNotEmpty) {
      hasFilter = true;
      query = query.where('postalCode', isEqualTo: cp);
    }

    if (cat != null && cat.isNotEmpty && cat != 'Toutes catégories') {
      hasFilter = true;
      query = query.where('category', isEqualTo: cat);
    }

    if (subcat.isNotEmpty) {
      hasFilter = true;
      query = query.where('subcategory', isEqualTo: subcat);
    }

    if (!hasFilter) {
      query = query.orderBy('createdAt', descending: true);
    }

    return query;
  }

  void _onLocationChanged(String value) {
    setState(() {
      _showLocationSuggestions = true;
    });
    final lower = value.trim().toLowerCase();
    for (final entry in kCityPostalMap.entries) {
      if (entry.key.toLowerCase() == lower) {
        _postalCodeController.text = entry.value;
        break;
      }
    }
  }

  void _resetFilters() {
    _locationController.clear();
    _subCategoryController.clear();
    _postalCodeController.clear();
    setState(() {
      _selectedCategory = 'Toutes catégories';
      _showLocationSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseTitle = widget.categoryFilter == null
        ? "Je consulte les offres"
        : "Offres : ${widget.categoryFilter!}";

    final suggestions = _citySuggestions;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          baseTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Réinitialiser les filtres",
            onPressed: _resetFilters,
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
          // Zone filtres
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory ?? 'Toutes catégories',
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: "Catégorie",
                          isDense: true,
                        ),
                        items: _categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: "Lieu / Ville",
                          hintText: "Ex : Baie-Mahault",
                          isDense: true,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        enableSuggestions: true,
                        autocorrect: true,
                        textCapitalization: TextCapitalization.words,
                        keyboardType: TextInputType.streetAddress,
                        autofillHints: const [
                          AutofillHints.addressCity,
                          AutofillHints.addressCityAndState,
                        ],
                        onChanged: _onLocationChanged,
                        onSubmitted: (_) {
                          setState(() {
                            _showLocationSuggestions = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final city = suggestions[index];
                        return ListTile(
                          dense: true,
                          title: Text(city),
                          onTap: () {
                            setState(() {
                              _locationController.text = city;
                              final cp = kCityPostalMap[city];
                              if (cp != null) {
                                _postalCodeController.text = cp;
                              }
                              _showLocationSuggestions = false;
                            });
                            FocusScope.of(context).unfocus();
                          },
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _subCategoryController,
                        decoration: const InputDecoration(
                          labelText: "Sous-catégorie",
                          hintText: "Ex : terrasse, peinture chambre…",
                          isDense: true,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        enableSuggestions: true,
                        autocorrect: true,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _postalCodeController,
                        decoration: const InputDecoration(
                          labelText: "C/P",
                          hintText: "97122",
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        enableSuggestions: true,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.postalCode],
                        onSubmitted: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildQuery().snapshots(),
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
                        "Erreur lors du chargement des offres.\n${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }

                List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                    snapshot.data?.docs ?? [];

                if (widget.searchQuery != null &&
                    widget.searchQuery!.trim().isNotEmpty) {
                  final q = widget.searchQuery!.trim().toLowerCase();
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

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();

                    final title = (data['title'] ?? 'Sans titre') as String;
                    final location =
                        (data['location'] ?? 'Lieu non précisé') as String;
                    final category =
                        (data['category'] ?? 'Catégorie non précisée')
                            as String;
                    final budget = data['budget'];
                    final description = (data['description'] ?? '') as String;
                    final phone =
                        data['phone'] == null ? null : data['phone'] as String;

                    String subtitle = "$location · $category";
                    if (budget != null) {
                      subtitle += " · ${budget.toString()} €";
                    }

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
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
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          subtitle,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OfferDetailPage(
                                title: title,
                                location: location,
                                category: category,
                                budget: budget is num ? budget : null,
                                description:
                                    description.isEmpty ? null : description,
                                phone: phone,
                              ),
                            ),
                          );
                        },
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
            Icon(
              Icons.search_off_outlined,
              size: 56,
              color: Colors.black26,
            ),
            SizedBox(height: 16),
            Text(
              "Aucune offre publiée pour le moment",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              "Clique sur « Publier une offre » pour créer ta première annonce Prestō.",
              style: TextStyle(
                fontSize: 13,
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

/// PAGE DÉTAIL OFFRE /////////////////////////////////////////////////

class OfferDetailPage extends StatelessWidget {
  final String title;
  final String location;
  final String category;
  final num? budget;
  final String? description;
  final String? phone;

  const OfferDetailPage({
    super.key,
    required this.title,
    required this.location,
    required this.category,
    this.budget,
    this.description,
    this.phone,
  });

  Future<void> _callPhone(BuildContext context) async {
    if (phone == null || phone!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun numéro disponible.")),
      );
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: phone!.trim(),
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible de lancer l’appel sur cet appareil."),
          ),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Une erreur est survenue lors de l’appel."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetText =
        budget == null ? "À définir" : "${budget!.toStringAsFixed(2)} €";

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
            // Titre
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),

            // Lieu
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Catégorie
            Row(
              children: [
                const Icon(Icons.category_outlined, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Budget
            Row(
              children: [
                const Icon(Icons.euro_outlined, size: 18),
                const SizedBox(width: 4),
                Text(
                  budgetText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),

            if (phone != null && phone!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone_android_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    phone!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            const Text(
              "Description",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  (description == null || description!.trim().isEmpty)
                      ? "Aucune description détaillée fournie."
                      : description!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bouton accepter / appeler
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrestoBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _callPhone(context),
                icon: const Icon(Icons.call),
                label: const Text(
                  "Appeler le numéro",
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
}

/// PAGE MESSAGES ///////////////////////////////////////////////////////////

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
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
      body: const Center(
        child: Text(
          "Messagerie Prestō : bientôt disponible",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// PAGE COMPTE /////////////////////////////////////////////////////////////

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').add({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      SessionState.userId = doc.id;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Compte créé et connecté ✅"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la création du compte : $e"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAccount = SessionState.userId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Mon compte",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAccount
                      ? "Vous êtes connecté à Prestō"
                      : "Créez votre compte Prestō",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Un compte permettra de gérer vos offres, vos messages et votre visibilité.",
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
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: "Nom / Prénom",
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        enableSuggestions: true,
                        autocorrect: true,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Veuillez saisir votre nom";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: "Téléphone",
                          hintText: "Ex : 0690 12 34 56",
                        ),
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        enableSuggestions: true,
                        autocorrect: false,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Veuillez saisir un téléphone";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: "Email",
                        ),
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        enableSuggestions: true,
                        autocorrect: false,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          if (!value.contains('@')) {
                            return "Email invalide";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrestoOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _isSaving ? null : _createAccount,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person_add_alt_1_outlined,
                                ),
                          label: Text(
                            _isSaving
                                ? "Création en cours..."
                                : "Créer / mettre à jour mon compte",
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PAGE FORMULAIRE /////////////////////////////////////////////////////////

class PublishOfferPage extends StatefulWidget {
  const PublishOfferPage({super.key});

  @override
  State<PublishOfferPage> createState() => _PublishOfferPageState();
}

class _PublishOfferPageState extends State<PublishOfferPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();
  final _phoneController = TextEditingController();
  final _postalCodeController = TextEditingController();

  String? _category;
  bool _showLocationSuggestions = false;

  final List<String> _categories = const [
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

  List<String> get _citySuggestions {
    final text = _locationController.text.trim().toLowerCase();
    if (!_showLocationSuggestions) return [];
    if (text.length < 2) return [];
    return kCityNames
        .where((c) => c.toLowerCase().contains(text))
        .take(5)
        .toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    _phoneController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  void _onLocationChanged(String value) {
    setState(() {
      _showLocationSuggestions = true;
    });
    final lower = value.trim().toLowerCase();
    for (final entry in kCityPostalMap.entries) {
      if (entry.key.toLowerCase() == lower) {
        _postalCodeController.text = entry.value;
        break;
      }
    }
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    final postalCode = _postalCodeController.text.trim();
    final category = _category ?? 'Non précisé';
    final budgetText = _budgetController.text.trim();
    final phone = _phoneController.text.trim();

    final double? budget = budgetText.isEmpty
        ? null
        : double.tryParse(budgetText.replaceAll(',', '.'));

    try {
      await FirebaseFirestore.instance.collection('offers').add({
        'title': title,
        'description': description,
        'location': location,
        'postalCode': postalCode.isEmpty ? null : postalCode,
        'category': category,
        'budget': budget,
        'phone': phone.isEmpty ? null : phone,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l’enregistrement de l’offre : $e"),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const Center(
                child: Text(
                  "Récapitulatif de votre offre",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _RecapRow(label: "Titre", value: title),
              _RecapRow(label: "Catégorie", value: category),
              _RecapRow(label: "Lieu", value: location),
              if (postalCode.isNotEmpty)
                _RecapRow(label: "C/P", value: postalCode),
              if (phone.isNotEmpty)
                _RecapRow(label: "Téléphone", value: phone),
              _RecapRow(
                label: "Budget",
                value: budget == null
                    ? "À définir"
                    : "${budget.toStringAsFixed(2)} €",
              ),
              const SizedBox(height: 10),
              const Text(
                "Description",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrestoBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Offre publiée ✅"),
                      ),
                    );
                    _formKey.currentState!.reset();
                    _titleController.clear();
                    _descriptionController.clear();
                    _locationController.clear();
                    _budgetController.clear();
                    _phoneController.clear();
                    _postalCodeController.clear();
                    setState(() {
                      _category = null;
                      _showLocationSuggestions = false;
                    });
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    "Confirmer la publication",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _citySuggestions;
    final bool isSmall = MediaQuery.of(context).size.width < 600;
    final double horizontalPadding = isSmall ? 16.0 : 32.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Je publie une offre",
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
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Décrivez votre besoin à notre IA",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Saisie vocale / IA : fonctionnalité bientôt disponible.",
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.mic,
                              color: kPrestoBlue,
                            ),
                            tooltip: "Décrire mon besoin à l’IA",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Plus votre demande est claire, plus vous aurez de réponses adaptées.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: "Titre de l’offre *",
                        hintText: "Ex : Serveur pour service du soir",
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      enableSuggestions: true,
                      autocorrect: true,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Veuillez saisir un titre d’offre";
                        }
                        if (value.trim().length < 4) {
                          return "Titre trop court";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(
                        labelText: "Catégorie",
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _category = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: "Description détaillée *",
                        hintText:
                            "Expliquez ce que vous cherchez : horaires, tâches, niveau attendu…",
                        alignLabelWithHint: true,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      enableSuggestions: true,
                      autocorrect: true,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Veuillez décrire votre besoin";
                        }
                        if (value.trim().length < 10) {
                          return "Description trop courte";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _locationController,
                            decoration: const InputDecoration(
                              labelText: "Lieu / Ville *",
                              hintText: "Ex : Baie-Mahault, Jarry…",
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            enableSuggestions: true,
                            autocorrect: true,
                            textCapitalization: TextCapitalization.words,
                            keyboardType: TextInputType.streetAddress,
                            autofillHints: const [
                              AutofillHints.addressCity,
                              AutofillHints.addressCityAndState,
                            ],
                            onChanged: _onLocationChanged,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Indiquez un lieu";
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) {
                              setState(() {
                                _showLocationSuggestions = false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 110,
                          child: TextFormField(
                            controller: _postalCodeController,
                            decoration: const InputDecoration(
                              labelText: "C/P",
                              hintText: "97122",
                            ),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            enableSuggestions: true,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.postalCode],
                          ),
                        ),
                      ],
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final city = suggestions[index];
                            return ListTile(
                              dense: true,
                              title: Text(city),
                              onTap: () {
                                setState(() {
                                  _locationController.text = city;
                                  final cp = kCityPostalMap[city];
                                  if (cp != null) {
                                    _postalCodeController.text = cp;
                                  }
                                  _showLocationSuggestions = false;
                                });
                                FocusScope.of(context).unfocus();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: "Téléphone (optionnel)",
                        hintText: "Ex : 0690 12 34 56",
                      ),
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      enableSuggestions: true,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _budgetController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Budget proposé (€)",
                        hintText: "Ex : 80",
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      enableSuggestions: false,
                      autocorrect: false,
                      validator: (value) {
                        if (value == null || value.trim().isNotEmpty) {
                          final txt =
                              (value ?? '').trim().replaceAll(',', '.');
                          if (txt.isEmpty) {
                            return null;
                          }
                          final num? val = num.tryParse(txt);
                          if (val == null) {
                            return "Veuillez saisir un montant valide";
                          }
                          if (val <= 0) {
                            return "Le montant doit être positif";
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: kPrestoOrange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _submitForm,
                        icon: const Icon(Icons.send_outlined),
                        label: const Text(
                          "Publier l’offre",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "* Champs obligatoires",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                        fontWeight: FontWeight.w500,
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
}

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
import 'package:flutter/material.dart';

enum AuthMode { login, signup }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AuthMode _authMode = AuthMode.login;
  bool _isLoggedIn = false; // TODO: à connecter avec ton vrai système d'auth

  // Controllers pour les formulaires
  final _formKeyAuth = GlobalKey<FormState>();
  final _formKeyProfile = GlobalKey<FormState>();

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _passwordConfirmCtrl = TextEditingController();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _cpCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  bool _notifNearby = true;
  bool _notifFavorites = true;
  bool _notifAcceptOffer = true;
  bool _notifSystem = true;

  String _accountType = 'Particulier';
  String _language = 'Français';
  String _theme = 'Système';

  final List<String> _favoriteCategories = [
    'Jardinage',
    'Peinture',
    'Aide à domicile',
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _cpCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // --- Actions fictives à connecter plus tard à Firebase / Auth ---
  void _onGoogleSignIn() {
    // TODO: Intégrer Firebase Auth Google
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _onAppleSignIn() {
    // TODO: Intégrer Sign in with Apple
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _onEmailAuth() {
    if (_formKeyAuth.currentState?.validate() ?? false) {
      // TODO: login / signup email réel
      setState(() {
        _isLoggedIn = true;
      });
    }
  }

  void _onLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        centerTitle: true,
      ),
      body: Container(
        color: colorScheme.surface,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _isLoggedIn ? _buildProfileContent(colorScheme, isDark) : _buildAuthContent(colorScheme, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthContent(ColorScheme colorScheme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenue sur Presto',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Connectez-vous ou créez un compte pour publier et accepter des offres autour de vous.',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 24),

        // Switch Connexion / Inscription
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(isDark ? 0.3 : 1),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets(4),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _authMode = AuthMode.login),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _authMode == AuthMode.login ? colorScheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Connexion',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _authMode == AuthMode.login ? colorScheme.onPrimary : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _authMode = AuthMode.signup),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _authMode == AuthMode.signup ? colorScheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Inscription',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _authMode == AuthMode.signup ? colorScheme.onPrimary : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Boutons Google / Apple
        _buildSocialButton(
          icon: Icons.g_mobiledata,
          label: _authMode == AuthMode.login
              ? 'Se connecter avec Google'
              : "S’inscrire avec Google",
          onTap: _onGoogleSignIn,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 8),
        _buildSocialButton(
          icon: Icons.apple,
          label: _authMode == AuthMode.login
              ? 'Se connecter avec Apple'
              : "S’inscrire avec Apple",
          onTap: _onAppleSignIn,
          colorScheme: colorScheme,
        ),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: colorScheme.outline.withOpacity(0.4))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('ou avec e-mail'),
            ),
            Expanded(child: Divider(color: colorScheme.outline.withOpacity(0.4))),
          ],
        ),
        const SizedBox(height: 8),

        // Formulaire Email
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKeyAuth,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez saisir un e-mail';
                      }
                      if (!value.contains('@')) {
                        return 'Format e-mail invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez saisir un mot de passe';
                      }
                      if (value.length < 6) {
                        return 'Minimum 6 caractères';
                      }
                      return null;
                    },
                  ),
                  if (_authMode == AuthMode.signup) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordConfirmCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        if (_authMode == AuthMode.signup) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez confirmer le mot de passe';
                          }
                          if (value != _passwordCtrl.text) {
                            return 'Les mots de passe ne correspondent pas';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Bouton email
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _onEmailAuth,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _authMode == AuthMode.login ? 'Se connecter' : 'Créer mon compte',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  if (_authMode == AuthMode.login) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: mot de passe oublié
                        },
                        child: const Text('Mot de passe oublié ?'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),
        _buildPrestoPromoCard(colorScheme),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildPrestoPromoCard(ColorScheme colorScheme) {
    return Card(
      color: colorScheme.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.bolt, color: colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Besoin d’un jardinier tout de suite ? Publiez votre offre : ils sont des dizaines autour de vous, prêts à accepter le job !",
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(ColorScheme colorScheme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header profil
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: colorScheme.primary.withOpacity(0.15),
              child: Icon(Icons.person, size: 32, color: colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameCtrl.text.isEmpty ? 'Mon profil Presto' : _nameCtrl.text,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.verified, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Compte non vérifié',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _onLogout,
              icon: Icon(Icons.logout, color: colorScheme.error),
              tooltip: 'Déconnexion',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Infos personnelles
        _buildSectionTitle('Informations personnelles'),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKeyProfile,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Commune',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cpCtrl,
                    decoration: const InputDecoration(
                      labelText: 'C/P',
                      prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _accountType,
                          decoration: const InputDecoration(
                            labelText: 'Type de compte',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Particulier',
                              child: Text('Particulier'),
                            ),
                            DropdownMenuItem(
                              value: 'Pro',
                              child: Text('Pro'),
                            ),
                            DropdownMenuItem(
                              value: 'Micro-Entreprise',
                              child: Text('Micro-Entreprise'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _accountType = value;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        if (_formKeyProfile.currentState?.validate() ?? false) {
                          // TODO: sauvegarde profil vers Firestore
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profil mis à jour.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Préférences
        _buildSectionTitle('Préférences'),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSwitchRow(
                  title: 'Offres proches de moi',
                  subtitle: 'Recevoir les nouvelles annonces autour de ma position.',
                  value: _notifNearby,
                  onChanged: (v) => setState(() => _notifNearby = v),
                ),
                const Divider(),
                _buildSwitchRow(
                  title: 'Catégories favorites',
                  subtitle: 'Être alerté quand une annonce correspond à mes favoris.',
                  value: _notifFavorites,
                  onChanged: (v) => setState(() => _notifFavorites = v),
                ),
                const Divider(),
                _buildSwitchRow(
                  title: 'Quand on accepte mon offre',
                  subtitle: 'Notification dès qu’un prestataire ou un client accepte.',
                  value: _notifAcceptOffer,
                  onChanged: (v) => setState(() => _notifAcceptOffer = v),
                ),
                const Divider(),
                _buildSwitchRow(
                  title: 'Infos système & sécurité',
                  subtitle: 'Mises à jour importantes de Presto.',
                  value: _notifSystem,
                  onChanged: (v) => setState(() => _notifSystem = v),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Langue & thème
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _language,
                  decoration: const InputDecoration(
                    labelText: 'Langue',
                    prefixIcon: Icon(Icons.language),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Français',
                      child: Text('Français'),
                    ),
                    DropdownMenuItem(
                      value: 'Créole',
                      child: Text('Créole'),
                    ),
                    DropdownMenuItem(
                      value: 'Anglais',
                      child: Text('Anglais'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _language = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _theme,
                  decoration: const InputDecoration(
                    labelText: 'Thème',
                    prefixIcon: Icon(Icons.brightness_6_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Système',
                      child: Text('Automatique (système)'),
                    ),
                    DropdownMenuItem(
                      value: 'Clair',
                      child: Text('Clair'),
                    ),
                    DropdownMenuItem(
                      value: 'Sombre',
                      child: Text('Sombre'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _theme = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Catégories favorites
        _buildSectionTitle('Mes catégories favorites'),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._favoriteCategories.map(
                  (cat) => Chip(
                    label: Text(cat),
                    avatar: const Icon(Icons.star, size: 16),
                  ),
                ),
                ActionChip(
                  label: const Text('Ajouter'),
                  avatar: const Icon(Icons.add),
                  onPressed: () {
                    // TODO: ouvrir un bottom sheet avec la liste des catégories
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Sécurité & aide
        _buildSectionTitle('Sécurité & aide'),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_reset_outlined),
                title: const Text('Changer mon mot de passe'),
                onTap: () {
                  // TODO: action
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Télécharger mes données'),
                onTap: () {
                  // TODO: action
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.support_agent_outlined),
                title: const Text('FAQ & support'),
                onTap: () {
                  // TODO: ouvrir page aide
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: colorScheme.error),
                title: Text(
                  'Supprimer mon compte',
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: () {
                  // TODO: confirmation suppression
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}