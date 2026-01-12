import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'splashscreen_v1.dart';
import 'splashscreen_v2.dart';
import 'splashscreen_v3.dart';

/// Gestionnaire de splashscreen dynamique
/// Charge la configuration depuis Firestore et affiche le bon splashscreen
class SplashscreenLoader extends StatefulWidget {
  final Widget child;
  final Duration minimumDuration;

  const SplashscreenLoader({
    super.key,
    required this.child,
    this.minimumDuration = const Duration(seconds: 2),
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
    final startTime = DateTime.now();

    try {
      // Charger la configuration depuis Firestore
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('splashscreen')
          .get()
          .timeout(const Duration(seconds: 3));

      if (doc.exists && mounted) {
        final data = doc.data();
        final active = data?['active'] as String?;
        if (active != null && active.isNotEmpty) {
          setState(() {
            _activeSplash = active;
          });
        }
      }
    } catch (e) {
      // En cas d'erreur, utiliser V1 par défaut
      debugPrint('⚠️ Splashscreen config error (using V1): $e');
    }

    // Assurer une durée minimale d'affichage
    final elapsed = DateTime.now().difference(startTime);
    final remaining = widget.minimumDuration - elapsed;

    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
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

    return widget.child;
  }
}
