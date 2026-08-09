import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/system_ui_style.dart';
import '../../features/trust_score/pending_reviews_v2_card.dart';
import '../../features/trust_score/trust_score_v2_card.dart';
import '../../app_core.dart' show kPrestoOrange;

class MesAvisPage extends StatelessWidget {
  const MesAvisPage({super.key, this.uidOverride});

  static const routeName = '/account/mes-avis';

  final String? uidOverride;

  @override
  Widget build(BuildContext context) {
    final uid = uidOverride ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        systemOverlayStyle: prestoOverlayStyleFor(kPrestoOrange),
        title: const Text(
          'Mes avis',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: uid.isEmpty
          ? const Center(child: Text('Non connecté'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const PendingReviewsV2Card(),
                const SizedBox(height: 14),
                TrustScoreV2Card(userId: uid),
              ],
            ),
    );
  }
}
