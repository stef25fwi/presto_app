import 'package:flutter/material.dart';
import '../services/splashscreen_service.dart';
import 'splash_screen_v2.dart';
import '../main.dart'; // Pour SplashScreen (v1)

class SplashScreenRouter extends StatefulWidget {
  const SplashScreenRouter({super.key});

  @override
  State<SplashScreenRouter> createState() => _SplashScreenRouterState();
}

class _SplashScreenRouterState extends State<SplashScreenRouter> {
  late Future<String> _splashVersionFuture;

  @override
  void initState() {
    super.initState();
    _splashVersionFuture = SplashScreenService.getActiveSplashscreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _splashVersionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Afficher un splash loading basique en attendant
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6600)),
              ),
            ),
          );
        }

        // Déterminer quelle version afficher
        final version = snapshot.data ?? 'v1';

        debugPrint('🎬 Affichage splashscreen: $version');

        return switch (version) {
          'v2' => const SplashScreenV2(),
          'v3' => const SplashScreenV3Placeholder(), // À implémenter plus tard
          _ => const SplashScreen(), // v1 par défaut
        };
      },
    );
  }
}

// Placeholder pour V3 (à implémenter)
class SplashScreenV3Placeholder extends StatelessWidget {
  const SplashScreenV3Placeholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Splashscreen V3 - À venir'),
      ),
    );
  }
}
