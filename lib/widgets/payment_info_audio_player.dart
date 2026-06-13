import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../services/payment_info_audio_settings_service.dart';

class PaymentInfoAudioPlayer extends StatefulWidget {
  const PaymentInfoAudioPlayer({super.key});

  @override
  State<PaymentInfoAudioPlayer> createState() => _PaymentInfoAudioPlayerState();
}

class _PaymentInfoAudioPlayerState extends State<PaymentInfoAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(String url) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (error) {
      setState(() {
        _error = 'Lecture impossible : $error';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PaymentInfoAudioSettings>(
      stream: PaymentInfoAudioSettingsService.watch(),
      builder: (context, snapshot) {
        final settings = snapshot.data;

        if (settings == null || !settings.hasAudio) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8, bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Info paiement audio',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : () => _play(settings.mp3Url),
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.volume_up_rounded),
                  label: const Text('Écouter le message paiement'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
