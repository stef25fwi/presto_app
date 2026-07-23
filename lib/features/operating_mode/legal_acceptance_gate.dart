import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../pages/legal_info_page.dart';
import 'app_operating_mode.dart';
import 'legal_acceptance.dart';

class LegalAcceptanceGate extends StatelessWidget {
  final String userId;
  final AppOperatingModeState state;
  final Widget acceptedChild;
  final FirebaseFirestore? firestore;
  final AppOperatingModeService? service;

  const LegalAcceptanceGate({
    super.key,
    required this.userId,
    required this.state,
    required this.acceptedChild,
    this.firestore,
    this.service,
  });

  @override
  Widget build(BuildContext context) {
    if (!state.mode.isCommercial) return acceptedChild;

    final database = firestore ?? FirebaseFirestore.instance;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: database.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        final accepted = hasAcceptedCurrentLegalDocuments(
          snapshot.data?.data(),
          state,
        );
        if (accepted) return acceptedChild;
        return _LegalAcceptanceRequiredCard(
          state: state,
          service: service ?? AppOperatingModeService(firestore: database),
          userId: userId,
        );
      },
    );
  }
}

class _LegalAcceptanceRequiredCard extends StatefulWidget {
  final AppOperatingModeState state;
  final AppOperatingModeService service;
  final String userId;

  const _LegalAcceptanceRequiredCard({
    required this.state,
    required this.service,
    required this.userId,
  });

  @override
  State<_LegalAcceptanceRequiredCard> createState() =>
      _LegalAcceptanceRequiredCardState();
}

class _LegalAcceptanceRequiredCardState
    extends State<_LegalAcceptanceRequiredCard> {
  bool _saving = false;

  Future<void> _openLegal(int tab) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LegalInfoPage(
          initialTab: tab,
          operatingModeService: widget.service,
        ),
      ),
    );
  }

  Future<void> _accept() async {
    if (_saving) return;
    var checked = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nouvelles conditions commerciales'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ilipresto est passé en version commerciale. Consultez et acceptez les nouvelles CGU et la politique de confidentialité avant d’accéder aux abonnements.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _openLegal(2),
                      child: const Text('Lire les CGU'),
                    ),
                    OutlinedButton(
                      onPressed: () => _openLegal(1),
                      child: const Text('Lire la confidentialité'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: checked,
                  onChanged: (value) => setDialogState(
                    () => checked = value == true,
                  ),
                  title: Text(
                    'J’accepte les CGU ${widget.state.cguVersion} et la politique ${widget.state.privacyVersion}.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Plus tard'),
            ),
            FilledButton(
              onPressed: checked
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: const Text('Accepter'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.service.recordAcceptance(
        userId: widget.userId,
        state: widget.state,
        source: 'commercial_reacceptance',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nouvelles conditions acceptées.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d’enregistrer l’acceptation. Réessayez avant de souscrire.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6600);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: orange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nouvelles conditions à accepter',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Les offres payantes restent masquées et aucun Checkout ne peut être créé avant votre accord explicite.',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _accept,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Consulter et accepter'),
            ),
          ),
        ],
      ),
    );
  }
}
