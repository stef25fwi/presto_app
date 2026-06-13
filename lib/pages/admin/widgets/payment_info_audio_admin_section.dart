import 'package:flutter/material.dart';
import 'package:presto_app/widgets/payment_info_audio_admin_section_prod.dart';

/// Compatibilité ancienne tuile admin.
/// L'implémentation production est dans PaymentInfoAudioAdminSectionProd.
class PaymentInfoAudioAdminSection extends StatelessWidget {
  const PaymentInfoAudioAdminSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const PaymentInfoAudioAdminSectionProd();
  }
}
