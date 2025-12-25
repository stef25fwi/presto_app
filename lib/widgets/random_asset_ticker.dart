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

  const RandomAssetTicker({
    super.key,
    required this.folderPrefix,
    this.interval = const Duration(seconds: 3),
    this.fit = BoxFit.cover,
    this.antiRepeatWindow = 3,
  });

  @override
  State<RandomAssetTicker> createState() => _RandomAssetTickerState();
}

class _RandomAssetTickerState extends State<RandomAssetTicker> {
  final _rnd = Random();
  Timer? _timer;

  List<String> _assets = [];
  String? _current;
  bool _loading = true;

  final Queue<String> _lastShown = Queue<String>();
  final Set<String> _failedAssets = <String>{};

  @override
  void initState() {
    super.initState();
    _loadCarouselImages();
  }

  Future<void> _loadCarouselImages() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = await manifest.listAssets();

      final images = allAssets
          .where((p) => p.startsWith('assets/carousel_home/'))
          .where((p) {
            final x = p.toLowerCase();
            return x.endsWith('.png') || x.endsWith('.jpg') || x.endsWith('.jpeg') || x.endsWith('.webp');
          })
          .toList();

      images.shuffle();

      debugPrint('carousel : ${images.length} image(s) trouvée(s)');
      if (images.isNotEmpty) {
        debugPrint(images.take(20).join('\n'));
      }

      if (!mounted) return;

      if (images.isEmpty) {
        setState(() {
          _assets = [];
          _loading = false;
        });
        return;
      }

      setState(() {
        _assets = images;
        _current = images.first;
        _loading = false;
      });

      _lastShown.clear();
      _pushLastShown(_current!);
      _startTicker();
    } catch (e) {
      if (!mounted) return;
      debugPrint('[RandomAssetTicker] Erreur chargement carousel: $e');
      setState(() {
        _assets = [];
        _loading = false;
      });
    }
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
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: Image.asset(
        _current!,
        key: ValueKey(_current),
        fit: widget.fit,
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
