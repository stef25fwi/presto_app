import 'package:flutter/material.dart';

import '../services/payment_info_audio_service.dart';
import 'payment_info_audio_player_button.dart';

class PaymentInfoAudioPaymentPopupButton extends StatefulWidget {
  const PaymentInfoAudioPaymentPopupButton({super.key});

  @override
  State<PaymentInfoAudioPaymentPopupButton> createState() =>
      _PaymentInfoAudioPaymentPopupButtonState();
}

class _PaymentInfoAudioPaymentPopupButtonState
    extends State<PaymentInfoAudioPaymentPopupButton> {
  late final PaymentInfoAudioService _service;

  @override
  void initState() {
    super.initState();
    _service = PaymentInfoAudioService();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PaymentInfoAudioConfig?>(
      stream: _service.watchConfig(),
      builder: (context, snapshot) {
        final config = snapshot.data;

        if (config == null || !config.canPlay) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: PaymentInfoAudioPlayerButton(
              audioUrl: config.audioUrl!,
              label: 'Écouter l’explication paiement',
            ),
          ),
        );
      },
    );
  }
}
