import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

abstract class PaymentInfoAudioController {
  Stream<PlayerState> get onPlayerStateChanged;
  Stream<void> get onPlayerComplete;
  Future<void> setSource(String url);
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration position);
  Future<void> play(String url);
  Future<void> dispose();
}

class AudioplayersPaymentInfoAudioController
    implements PaymentInfoAudioController {
  AudioplayersPaymentInfoAudioController({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  @override
  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;

  @override
  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  @override
  Future<void> setSource(String url) => _player.setSource(UrlSource(url));

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> play(String url) => _player.play(UrlSource(url));

  @override
  Future<void> dispose() => _player.dispose();
}

class PaymentInfoAudioPlayerButton extends StatefulWidget {
  const PaymentInfoAudioPlayerButton({
    super.key,
    required this.audioUrl,
    this.label = 'Écouter l’explication paiement',
    this.compact = false,
    this.onPlayed,
    this.audioController,
  });

  final String audioUrl;
  final String label;
  final bool compact;
  final VoidCallback? onPlayed;
  final PaymentInfoAudioController? audioController;
  @override
  State<PaymentInfoAudioPlayerButton> createState() =>
      _PaymentInfoAudioPlayerButtonState();
}

class _PaymentInfoAudioPlayerButtonState
    extends State<PaymentInfoAudioPlayerButton> {
  late final PaymentInfoAudioController _player;
  late final bool _ownsPlayer;
  StreamSubscription<void>? _completeSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  PlayerState _playerState = PlayerState.stopped;
  bool _isLoading = false;
  bool _sourceLoaded = false;
  bool get _isPlaying => _playerState == PlayerState.playing;
  bool get _isPaused => _playerState == PlayerState.paused;

  @override
  void initState() {
    super.initState();
    _ownsPlayer = widget.audioController == null;
    _player = widget.audioController ?? AudioplayersPaymentInfoAudioController();

    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playerState = state;
        _isLoading = false;
      });
    });

    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playerState = PlayerState.stopped;
        _isLoading = false;
        _sourceLoaded = false;
      });
    });

    _preloadSource();
  }

  Future<void> _preloadSource() async {
    final url = widget.audioUrl.trim();
    if (url.isEmpty) return;
    try {
      await _player.setSource(url);
      if (mounted) setState(() => _sourceLoaded = true);
    } catch (_) {
      // Échec silencieux : la lecture tentera un play() classique.
    }
  }

  @override
  void didUpdateWidget(covariant PaymentInfoAudioPlayerButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.audioUrl != widget.audioUrl) {
      _resetPlayerForNewUrl();
    }
  }

  Future<void> _resetPlayerForNewUrl() async {
    try {
      await _player.stop();
    } catch (_) {
      // Rien à faire : le reset ne doit jamais casser l'UI.
    }

    if (!mounted) return;

    setState(() {
      _playerState = PlayerState.stopped;
      _isLoading = false;
      _sourceLoaded = false;
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _completeSubscription?.cancel();
    if (_ownsPlayer) {
      _player.dispose();
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    final audioUrl = widget.audioUrl.trim();

    if (_isLoading || audioUrl.isEmpty) return;

    try {
      setState(() => _isLoading = true);

      if (_isPlaying) {
        await _player.pause();
        return;
      }

      if (_isPaused && _sourceLoaded) {
        widget.onPlayed?.call();
        await _player.resume();
        return;
      }

      if (_sourceLoaded) {
        await _player.seek(Duration.zero);
        widget.onPlayed?.call();
        await _player.resume();
      } else {
        _sourceLoaded = true;
        widget.onPlayed?.call();
        await _player.play(audioUrl);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _playerState = PlayerState.stopped;
        _isLoading = false;
        _sourceLoaded = false;
      });

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Lecture audio impossible : $error'),
        ),
      );
    }
  }

  Widget _buildIcon() {
    if (_isLoading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_isPlaying) {
      return const Icon(Icons.pause_rounded);
    }

    if (_isPaused) {
      return const Icon(Icons.play_arrow_rounded);
    }

    return const Icon(Icons.volume_up_rounded);
  }

  String _buttonLabel() {
    if (_isLoading) return 'Chargement...';
    if (_isPlaying) return 'Pause';
    if (_isPaused) return 'Reprendre';
    return widget.label;
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = _isLoading ? null : _toggle;

    if (widget.compact) {
      return IconButton(
        tooltip: _buttonLabel(),
        onPressed: onPressed,
        icon: _buildIcon(),
      );
    }

    return FilledButton.icon(
      onPressed: onPressed,
      icon: _buildIcon(),
      label: Text(_buttonLabel()),
    );
  }
}
