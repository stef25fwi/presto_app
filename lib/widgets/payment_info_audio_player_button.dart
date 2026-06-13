import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class PaymentInfoAudioPlayerButton extends StatefulWidget {
  const PaymentInfoAudioPlayerButton({
    super.key,
    required this.audioUrl,
    this.label = 'Écouter l’explication paiement',
    this.compact = false,
  });

  final String audioUrl;
  final String label;
  final bool compact;

  @override
  State<PaymentInfoAudioPlayerButton> createState() =>
      _PaymentInfoAudioPlayerButtonState();
}

class _PaymentInfoAudioPlayerButtonState
    extends State<PaymentInfoAudioPlayerButton> {
  late final AudioPlayer _player;
  StreamSubscription<void>? _completeSubscription;

  bool _isLoading = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();

    _player = AudioPlayer();

    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isPlaying = false;
      });
    });
  }

  @override
  void dispose() {
    _completeSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isLoading || widget.audioUrl.trim().isEmpty) return;

    try {
      setState(() => _isLoading = true);

      if (_isPlaying) {
        await _player.pause();

        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isPlaying = false;
        });

        return;
      }

      await _player.stop();
      await _player.play(UrlSource(widget.audioUrl));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isPlaying = true;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isPlaying = false;
      });

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Lecture audio impossible : $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(_isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded);

    if (widget.compact) {
      return IconButton(
        tooltip: widget.label,
        onPressed: _isLoading ? null : _toggle,
        icon: icon,
      );
    }

    return FilledButton.icon(
      onPressed: _isLoading ? null : _toggle,
      icon: icon,
      label: Text(_isPlaying ? 'Pause' : widget.label),
    );
  }
}
