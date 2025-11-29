
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:confetti/confetti.dart';

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

/// Petit état de session
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
    final base = ThemeData(
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
    );

    return MaterialApp(
      title: "Prestō",
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: base.textTheme.apply(fontSizeFactor: 1.06),
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
                    "Prestō",
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  "Trouvez un prestataire\nillico presto",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
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
                          TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
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
                    onPressed: () => _navigateTo(const JeConsultePage()),
                    child: const Text(
                      "Je consulte les offres",
                      style:
                          TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
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

class _HomePageState extends State<HomePage> {

  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(milliseconds: 900));

    /// Déclenche les confettis 1 seconde après l'ouverture de la page
    Future.delayed(const Duration(milliseconds: 1000), () {
      _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> dernieresOffres = List.generate(6, (i) {
    return {
      "titre": "Offre ${i + 1} – Besoin urgent",
      "description":
          "Description ultra rapide de l'offre numéro ${i + 1}. Prestataire demandé immédiatement.",
      "prix": "${50 + i * 5}",
      "ville": "Baie-Mahault"
    };
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF4EC),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// 🔍 Barre de recherche sans encadrement
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: "Rechercher un service…",
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// 🟧 Slide "Publiez… ils arrivent !" corrigé
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6600),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        "Publiez… ils arrivent !",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  /// 🔥 TITRE DERNIÈRES ANNONCES
                  const Text(
                    "Dernières annonces publiées",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// 🟠 SECTION AVEC CONFETTIS
                  Stack(
                    children: [
                      Column(
                        children: dernieresOffres
                            .map((offre) => _cardAnnonce(offre))
                            .toList(),
                      ),

                      /// 🎉 CONFETTIS ORANGE
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ConfettiWidget(
                            confettiController: _confetti,
                            blastDirectionality: BlastDirectionality.explosive,
                            maxBlastForce: 20,
                            minBlastForce: 8,
                            gravity: 0.25,
                            particleDrag: 0.05,
                            emissionFrequency: 0.02,
                            numberOfParticles: 25,
                            colors: [
                              Colors.orange.shade300,
                              Colors.orange.shade500,
                              Colors.orange.shade700,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ------- CARTE D'UNE ANNONCE (PRIX EN GRAS) -------
  Widget _cardAnnonce(Map<String, dynamic> offre) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          /// Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offre["titre"],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  offre["ville"],
                  style: const TextStyle(
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          /// Prix gras
          Text(
            "${offre["prix"]} €",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
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
                fontWeight: FontWeight.w600,
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
                fontWeight: FontWeight.w700,
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
    const color = Colors.white;
    final fontWeight = selected ? FontWeight.w700 : FontWeight.w600;

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
              fontWeight: FontWeight.w600,
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
                    fontWeight: FontWeight.w500,
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

class JeConsultePage extends StatefulWidget {
  const JeConsultePage({super.key});

  @override
  State<JeConsultePage> createState() => _JeConsultePageState();
}

class _JeConsultePageState extends State<JeConsultePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final List<String> _filters = [
    "Jardinage",
    "Peinture",
    "Bricolage",
    "Nettoyage",
    "Déménagement",
    "Plomberie"
  ];

  String selectedFilter = "";
  List<Map<String, dynamic>> annonces = List.generate(30, (i) {
    return {
      "titre": "Offre n°${i + 1} – Intervention rapide",
      "description":
          "Description détaillée de l’offre numéro ${i + 1}. Travail sérieux, rapide et disponible immédiatement.",
      "prix": (50 + i * 2).toString(),
      "ville": "Baie-Mahault"
    };
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF4EC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔍 Barre de recherche SANS encadrement
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: "Rechercher une offre...",
                  border: InputBorder.none,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            /// 🟦 Filtres uniformisés + wrap compact
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: -8,
                children: _filters.map((f) {
                  final bool act = selectedFilter == f;
                  return GestureDetector(
                    onTap: () => setState(() => selectedFilter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 14),
                      decoration: BoxDecoration(
                        color: act ? Colors.orange : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black26, width: 1),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: act ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 6),

            /// 📄 Liste des annonces + bandeaux slogans
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                itemCount: annonces.length,
                itemBuilder: (context, index) {
                  /// ➤ Tous les 5 annonces : BANNIÈRE MOTIVATION
                  if (index % 5 == 0 && index != 0) {
                    return Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "🔥 Plus vous publiez, plus vous trouvez vite !",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        _annonceCard(index),
                      ],
                    );
                  }

                  return _annonceCard(index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ------- CARTE D'ANNONCE (PRIX EN GRAS) --------
  Widget _annonceCard(int index) {
    final annonce = annonces[index];
    return GestureDetector(
      onTap: () => _openAnnonce(annonce),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              annonce["titre"],
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              annonce["description"],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${annonce["prix"]} €",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, // PRIX EN GRAS
                    fontSize: 16,
                  ),
                ),
                Text(
                  annonce["ville"],
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ------- PAGE DÉTAIL D'UNE ANNONCE --------
  void _openAnnonce(Map<String, dynamic> annonce) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              annonce["titre"],
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              annonce["description"],
              style: const TextStyle(
                fontSize: 16.5, // ✔️ Description légèrement agrandie
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // bouton bleu
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "J’accepte l’offre",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// PAGE DÉTAIL /////////////////////////////////////////////////////////////

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

  Future<void> _callPhone(BuildContext context, String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Impossible d’ouvrir le téléphone pour le numéro $phoneNumber"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erreur lors de l’ouverture du téléphone."),
        ),
      );
    }
  }

  void _onAcceptOffer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final hasPhone = phone != null && phone!.trim().isNotEmpty;
        final hasAccount = SessionState.userId != null;

        return Padding(
          padding: const EdgeInsets.all(16),
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
                "J’accepte l’offre",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading:
                    const Icon(Icons.call_outlined, color: kPrestoOrange),
                title: Text(
                  hasPhone
                      ? "Appeler le numéro : $phone"
                      : "Numéro non renseigné",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: hasPhone
                    ? () {
                        Navigator.of(context).pop();
                        _callPhone(context, phone!.trim());
                      }
                    : null,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline,
                    color: kPrestoOrange),
                title: Text(
                  hasAccount
                      ? "Contacter par message (bientôt disponible)"
                      : "Contacter par message (crée d’abord un compte)",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  if (!hasAccount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Crée ton compte dans « Mon compte » pour utiliser la messagerie.",
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Messagerie Prestō : fonctionnalité bientôt disponible.",
                        ),
                      ),
                    );
                  }
                },
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 18),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.category_outlined, size: 18),
                const SizedBox(width: 4),
                Text(
                  category,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.euro_outlined, size: 18),
                const SizedBox(width: 4),
                Text(
                  budgetText,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (phone != null && phone!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.phone_android_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    phone!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              "Description",
              style: TextStyle(
                fontSize: 16,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
                ),
                onPressed: () => _onAcceptOffer(context),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  "J’accepte l’offre",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
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
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1_outlined),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 600;
          final horizontalPadding = isSmall ? 16.0 : 32.0;

          return SingleChildScrollView(
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
                              "Décrivez votre besoin",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
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
                        initialValue: _category,
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
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
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final txt = value.trim().replaceAll(',', '.');
                          final num? val = num.tryParse(txt);
                          if (val == null) {
                            return "Veuillez saisir un montant valide";
                          }
                          if (val <= 0) {
                            return "Le montant doit être positif";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
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
          );
        },
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
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
