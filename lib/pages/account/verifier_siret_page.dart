import 'package:flutter/material.dart';

import '../../app/system_ui_style.dart';
import '../../app_core.dart' show kPrestoOrange;
import '../../widgets/pro_siret_verification_card.dart';

class VerifierSiretPage extends StatelessWidget {
  const VerifierSiretPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        systemOverlayStyle: prestoOverlayStyleFor(kPrestoOrange),
        title: const Text(
          'Vérifier mon SIRET',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: const SingleChildScrollView(
        child: ProSiretVerificationCard(),
      ),
    );
  }
}
