import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Exemple d'implémentation des splashscreens
/// À intégrer dans lib/widgets/

// ============================================================================
// SPLASHSCREEN V1 - Version Originale
// ============================================================================

class SplashscreenV1 extends StatelessWidget {
  const SplashscreenV1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF6600), // Orange Presto
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo simple
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.handyman_rounded,
                size: 64,
                color: Color(0xFFFF6600),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'IliPrestō',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Trouve ton prestataire',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SPLASHSCREEN V2 - Version Moderne
// ============================================================================

class SplashscreenV2 extends StatefulWidget {
  const SplashscreenV2({super.key});

  @override
  State<SplashscreenV2> createState() => _SplashscreenV2State();
}

class _SplashscreenV2State extends State<SplashscreenV2>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A73E8), // Bleu Presto
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo avec effet de brillance
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 72,
                        color: Color(0xFF1A73E8),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'IliPrestō',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'La plateforme des pros',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// SPLASHSCREEN V3 - Version Minimaliste
// ============================================================================

class SplashscreenV3 extends StatelessWidget {
  const SplashscreenV3({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo minimal
            Icon(
              Icons.trending_up_rounded,
              size: 80,
              color: Colors.purple,
            ),
            SizedBox(height: 24),
            Text(
              'IliPrestō',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: Colors.black87,
                letterSpacing: 3.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LOADER - Gestionnaire de splashscreen
// ============================================================================

class SplashscreenLoader extends StatefulWidget {
  final Widget Function() onComplete;

  const SplashscreenLoader({
    super.key,
    required this.onComplete,
  });

  @override
  State<SplashscreenLoader> createState() => _SplashscreenLoaderState();
}

class _SplashscreenLoaderState extends State<SplashscreenLoader> {
  String _activeSplash = 'v1';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSplashscreenConfig();
  }

  Future<void> _loadSplashscreenConfig() async {
    try {
      // Charger la configuration depuis Firestore
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('splashscreen')
          .get();

      if (doc.exists) {
        setState(() {
          _activeSplash = doc.data()?['active'] ?? 'v1';
        });
      }
    } catch (e) {
      // En cas d'erreur, utiliser V1 par défaut
      debugPrint('Erreur chargement splashscreen config: $e');
    }

    // Attendre au moins 2 secondes pour afficher le splash
    await Future.delayed(const Duration(seconds: 2));

    // Initialiser les services nécessaires ici
    // await _initializeApp();

    setState(() {
      _loading = false;
    });
  }

  Widget _getSplashscreenWidget() {
    switch (_activeSplash) {
      case 'v2':
        return const SplashscreenV2();
      case 'v3':
        return const SplashscreenV3();
      case 'v1':
      default:
        return const SplashscreenV1();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _getSplashscreenWidget();
    }

    return widget.onComplete();
  }
}

// ============================================================================
// UTILISATION DANS MAIN.DART
// ============================================================================

/*
import 'package:flutter/material.dart';
import 'widgets/splashscreen_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Firebase
  await Firebase.initializeApp();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IliPrestō',
      theme: ThemeData(...),
      home: SplashscreenLoader(
        onComplete: () => const HomePage(),
      ),
    );
  }
}
*/
