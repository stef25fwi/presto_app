import 'package:flutter/material.dart';

import '../services/payment_info_audio_service.dart';
import 'payment_info_audio_player_button.dart';

class PaymentInfoAudioAdminSectionProd extends StatefulWidget {
  const PaymentInfoAudioAdminSectionProd({super.key});

  @override
  State<PaymentInfoAudioAdminSectionProd> createState() =>
      _PaymentInfoAudioAdminSectionProdState();
}

class _PaymentInfoAudioAdminSectionProdState
    extends State<PaymentInfoAudioAdminSectionProd> {
  late final PaymentInfoAudioService _service;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _service = PaymentInfoAudioService();
  }

  Future<void> _generate() async {
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    try {
      await _service.generatePaymentInfoAudio();

      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('MP3 paiement généré et publié avec succès.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Génération MP3 impossible : $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Aucun MP3 publié pour le moment.';

    String two(int number) => number.toString().padLeft(2, '0');

    return 'Dernière génération : ${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.dividerColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<PaymentInfoAudioConfig?>(
          stream: _service.watchConfig(),
          builder: (context, snapshot) {
            final config = snapshot.data;
            final canPlay = config?.canPlay == true;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6600).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        color: Color(0xFFFF6600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Audio paiement MP3',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (canPlay)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Génère l’audio explicatif utilisé dans le popup paiement. '
                  'Le MP3 est stocké dans Firebase Storage puis publié dans Firestore.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  _formatDate(config?.generatedDate),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _isGenerating ? null : _generate,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        _isGenerating
                            ? 'Génération en cours...'
                            : canPlay
                                ? 'Regénérer le MP3'
                                : 'Générer le MP3',
                      ),
                    ),
                    if (canPlay)
                      PaymentInfoAudioPlayerButton(
                        audioUrl: config!.audioUrl!,
                        label: 'Tester la lecture',
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
