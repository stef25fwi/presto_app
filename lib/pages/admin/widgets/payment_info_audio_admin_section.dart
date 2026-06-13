import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'package:presto_app/services/payment_info_audio_settings_service.dart';

class PaymentInfoAudioAdminSection extends StatefulWidget {
  const PaymentInfoAudioAdminSection({super.key});

  @override
  State<PaymentInfoAudioAdminSection> createState() =>
      _PaymentInfoAudioAdminSectionState();
}

class _PaymentInfoAudioAdminSectionState
    extends State<PaymentInfoAudioAdminSection> {
  final TextEditingController _urlController = TextEditingController();
  final AudioPlayer _player = AudioPlayer();

  bool _enabled = true;
  bool _saving = false;
  bool _testing = false;
  String? _lastLoadedUrl;

  @override
  void dispose() {
    _urlController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();

    if (url.isEmpty || !url.toLowerCase().contains('.mp3')) {
      _showMessage('Ajoute une URL MP3 valide.');
      return;
    }

    setState(() => _saving = true);

    try {
      await PaymentInfoAudioSettingsService.save(
        mp3Url: url,
        enabled: _enabled,
      );

      if (!mounted) return;
      _showMessage('MP3 paiement mis à jour.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Erreur sauvegarde MP3 : $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testAudio() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      _showMessage('Ajoute une URL MP3 avant de tester.');
      return;
    }

    setState(() => _testing = true);

    try {
      await _player.stop();
      await _player.play(UrlSource(url));

      if (!mounted) return;
      _showMessage('Lecture test démarrée.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Erreur lecture MP3 : $error');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _syncFromSettings(PaymentInfoAudioSettings settings) {
    if (_lastLoadedUrl == settings.mp3Url) return;

    _lastLoadedUrl = settings.mp3Url;
    _urlController.text = settings.mp3Url;
    _enabled = settings.enabled;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PaymentInfoAudioSettings>(
      stream: PaymentInfoAudioSettingsService.watch(),
      builder: (context, snapshot) {
        final settings = snapshot.data;

        if (settings != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _syncFromSettings(settings));
            }
          });
        }

        return Card(
          elevation: 0,
          color: const Color(0xFFFFF7ED),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFFFD7AA)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.volume_up_rounded,
                      color: Color(0xFFFF6600),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mise à jour MP3 paiement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Colle ici l’URL du fichier MP3 à lire dans le popup paiement.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: 'URL du MP3 paiement',
                    hintText: 'https://.../audio-paiement.mp3',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  value: _enabled,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFFFF6600),
                  title: const Text(
                    'Activer l’audio dans le popup paiement',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testing ? null : _testAudio,
                        icon: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: const Text('Tester'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: const Text('Enregistrer'),
                      ),
                    ),
                  ],
                ),
                if (snapshot.hasError) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Erreur chargement MP3 : ${snapshot.error}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
