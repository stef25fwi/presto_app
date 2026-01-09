import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RandomAssetTicker extends StatefulWidget {
  final String folderPrefix; // ex: 'assets/carousel_home/'
  final Duration interval;   // ex: 3s
  final BoxFit fit;
  final int antiRepeatWindow;
  final bool enabled;

  const RandomAssetTicker({
    super.key,
    required this.folderPrefix,
    this.interval = const Duration(seconds: 3),
    this.fit = BoxFit.cover,
    this.antiRepeatWindow = 3,
    this.enabled = true,
  });

  @override
  State<RandomAssetTicker> createState() => _RandomAssetTickerState();
}

class _RandomAssetTickerState extends State<RandomAssetTicker> {
  static final Map<String, List<String>> _folderAssetsCache = <String, List<String>>{};
  static final Map<String, Future<List<String>>> _folderAssetsLoader = <String, Future<List<String>>>{};

  final _rnd = Random();

  Timer? _timer;

  List<String> _assets = [];
  String? _current;
  bool _loading = true;

  final Queue<String> _lastShown = Queue<String>();
  final Set<String> _failedAssets = <String>{};

  bool _precachingAll = false;

  @override
  void initState() {
    super.initState();
    _loadCarouselImages();
  }

  @override
  void didUpdateWidget(covariant RandomAssetTicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.folderPrefix != widget.folderPrefix) {
      _timer?.cancel();
      setState(() {
        _assets = [];
        _current = null;
        _loading = true;
      });
      _loadCarouselImages();
      return;
    }

    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _startTicker();
      } else {
        _timer?.cancel();
      }
    }
  }

  Future<List<String>> _loadAssetsForFolder(String prefix) {
    final cached = _folderAssetsCache[prefix];
    if (cached != null) return Future.value(cached);

    return _folderAssetsLoader.putIfAbsent(prefix, () async {
      try {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        final allAssets = manifest.listAssets();
        final images = allAssets
            .where((p) => p.startsWith(prefix))
            .where((p) {
              final x = p.toLowerCase();
              return x.endsWith('.png') ||
                  x.endsWith('.jpg') ||
                  x.endsWith('.jpeg') ||
                  x.endsWith('.webp');
            })
            .toList()
          ..sort();

        _folderAssetsCache[prefix] = images;
        return images;
      } catch (e) {
        _folderAssetsLoader.remove(prefix);
        rethrow;
      }
    });
  }

  Future<void> _loadCarouselImages() async {
    try {
      final base = await _loadAssetsForFolder(widget.folderPrefix);
      final images = List<String>.from(base);

      // Affiche toujours le "slide 1" en premier si présent (ex: 01.png),
      // puis garde un ordre aléatoire pour le reste.
      final first = images.isNotEmpty ? images.first : null;
      final rest = images.length > 1 ? images.sublist(1) : <String>[];
      rest.shuffle(_rnd);

      if (!mounted) return;

      setState(() {
        _assets = [
          if (first != null) first,
          ...rest,
        ];
        _current = _assets.isNotEmpty ? _assets.first : null;
        _loading = false;
      });

      _lastShown.clear();
      if (_current != null) _pushLastShown(_current!);

      // Si le ticker est désactivé, on évite de précacher tout le dossier
      // (cas typique: placeholder statique dans une liste).
      if (widget.enabled) {
        _precacheAllAssets();
        _startTicker();
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('[RandomAssetTicker] Erreur chargement carousel: $e');
      setState(() {
        _assets = [];
        _loading = false;
      });
    }
  }

  void _precacheAllAssets() {
    if (_precachingAll) return;
    if (_assets.isEmpty) return;
    _precachingAll = true;

    // Pas await ici: on ne veut pas bloquer l'UI.
    Future<void>(() async {
      for (final asset in _assets) {
        if (!mounted) return;
        if (_failedAssets.contains(asset)) continue;
        try {
          await precacheImage(AssetImage(asset), context);
        } catch (_) {
          _failedAssets.add(asset);
        }
      }
    }).whenComplete(() {
      _precachingAll = false;
    });
  }

  void _pushLastShown(String asset) {
    _lastShown.addLast(asset);
    while (_lastShown.length > widget.antiRepeatWindow) {
      _lastShown.removeFirst();
    }
  }

  String _pickNext() {
    if (_assets.isEmpty) return _current ?? '';
    if (_assets.length == 1) return _assets.first;

    final excluded = Set<String>.from(_lastShown)..addAll(_failedAssets);
    List<String> candidates = _assets.where((a) => !excluded.contains(a)).toList();

    if (candidates.isEmpty) {
      final current = _current;
      candidates = _assets.where((a) => a != current && !_failedAssets.contains(a)).toList();
      if (candidates.isEmpty) {
        candidates = _assets.where((a) => !_failedAssets.contains(a)).toList();
      }
    }

    if (candidates.isEmpty) return '';
    return candidates[_rnd.nextInt(candidates.length)];
  }

  void _startTicker() {
    _timer?.cancel();
    if (!widget.enabled) return;
    if (_assets.length <= 1) return;

    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      if (_assets.isEmpty) return;

      final next = _pickNext();
      setState(() {
        _current = next;
      });
      _pushLastShown(next);
    });
  }

  void _advanceToNext({String? failed}) {
    if (failed != null) {
      _failedAssets.add(failed);
      if (kDebugMode) debugPrint('[RandomAssetTicker] Asset KO: $failed');
    }
    final next = _pickNext();
    if (!mounted) return;
    if (next.isEmpty) {
      setState(() {
        _current = null;
      });
      return;
    }
    if (next == _current) return;
    setState(() {
      _current = next;
    });
    _pushLastShown(next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_assets.isEmpty || _current == null) {
      final bool allFailed = _assets.isNotEmpty && _failedAssets.length == _assets.length;
      final String message = allFailed ? 'Toutes les images sont indisponibles.' : 'Aucune image trouvée.';
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF121212), Color(0xFF2C2C2C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined, color: Colors.white70, size: 36),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Vérifie pubspec.yaml puis fais un hot restart',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.03, 0),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
      child: Image.asset(
        _current!,
        key: ValueKey(_current),
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _advanceToNext(failed: _current);
          });
          return const Center(
            child: Text(
              'Image indisponible, passage à la suivante…',
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }
}
