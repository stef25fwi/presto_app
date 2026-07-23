import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/friendly_snackbar.dart';
import 'app_operating_mode.dart';

class OperatingModeAdminTile extends StatefulWidget {
  final AppOperatingModeService? service;

  const OperatingModeAdminTile({super.key, this.service});

  @override
  State<OperatingModeAdminTile> createState() =>
      _OperatingModeAdminTileState();
}

class _OperatingModeAdminTileState extends State<OperatingModeAdminTile> {
  bool _saving = false;

  AppOperatingModeService get _service =>
      widget.service ?? AppOperatingModeService();

  @override
  void initState() {
    super.initState();
    unawaited(
      _service.ensureDefaults(
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      ),
    );
  }

  Future<void> _setCommercial(
    bool enabled,
    AppOperatingModeState state,
  ) async {
    if (_saving || enabled == state.mode.isCommercial) return;
    setState(() => _saving = true);
    try {
      await _service.setMode(
        enabled ? AppOperatingMode.commercial : AppOperatingMode.freeBeta,
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      );
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        enabled
            ? 'Version payante activée avec les garde-fous juridiques.'
            : 'Bêta gratuite activée : paiements et abonnements désactivés.',
      );
    } on StateError catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message.toString());
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        'Impossible de modifier le mode d’exploitation.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editPublisher(AppOperatingModeState state) async {
    final result = await showDialog<LegalPublisherProfile>(
      context: context,
      builder: (_) => _PublisherProfileDialog(initial: state.publisher),
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _service.updatePublisherProfile(
        result,
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Informations juridiques enregistrées.');
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        'Impossible d’enregistrer les informations juridiques.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE5E7EB);
    const muted = Color(0xFF6B7280);
    const green = Color(0xFF138A46);
    const orange = Color(0xFFFF6600);

    return StreamBuilder<AppOperatingModeState>(
      stream: _service.watchState(ensureExists: true),
      builder: (context, snapshot) {
        final state = snapshot.data ?? AppOperatingModeState.defaults();
        final ready = state.isPublicReady;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mode d’exploitation Ilipresto',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Un seul toggle pilote l’interface, Stripe, les droits et les documents juridiques.',
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activer la version payante'),
                subtitle: Text(
                  state.mode.isCommercial
                      ? 'Abonnements et Stripe actifs.'
                      : 'Bêta gratuite : aucun abonnement, paiement ou commission.',
                ),
                value: state.mode.isCommercial,
                onChanged: _saving
                    ? null
                    : (value) => _setCommercial(value, state),
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    label: state.mode.label,
                    color: state.mode.isCommercial ? orange : green,
                  ),
                  _StatusChip(
                    label: ready
                        ? 'Profil juridique complet'
                        : 'Profil juridique incomplet',
                    color: ready ? green : orange,
                  ),
                  _StatusChip(
                    label: state.legalVersion,
                    color: muted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _editPublisher(state),
                  icon: const Icon(Icons.gavel_rounded),
                  label: const Text('Configurer l’identité juridique'),
                ),
              ),
              if (!ready) ...[
                const SizedBox(height: 8),
                const Text(
                  'La publication conforme et la bascule payante restent verrouillées tant que les champs obligatoires ne sont pas renseignés.',
                  style: TextStyle(
                    color: orange,
                    fontSize: 12,
                    height: 1.35,
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

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PublisherProfileDialog extends StatefulWidget {
  final LegalPublisherProfile initial;

  const _PublisherProfileDialog({required this.initial});

  @override
  State<_PublisherProfileDialog> createState() =>
      _PublisherProfileDialogState();
}

class _PublisherProfileDialogState extends State<_PublisherProfileDialog> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _controllers = <String, TextEditingController>{
      'publisherName': TextEditingController(text: p.publisherName),
      'postalAddress': TextEditingController(text: p.postalAddress),
      'phone': TextEditingController(text: p.phone),
      'email': TextEditingController(text: p.email),
      'publicationDirector':
          TextEditingController(text: p.publicationDirector),
      'companyName': TextEditingController(text: p.companyName),
      'legalForm': TextEditingController(text: p.legalForm),
      'siren': TextEditingController(text: p.siren),
      'rcs': TextEditingController(text: p.rcs),
      'shareCapital': TextEditingController(text: p.shareCapital),
      'vatNumber': TextEditingController(text: p.vatNumber),
      'hostingProvider': TextEditingController(text: p.hostingProvider),
      'hostingAddress': TextEditingController(text: p.hostingAddress),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(String key) => _controllers[key]!.text.trim();

  LegalPublisherProfile _profile() => LegalPublisherProfile(
        publisherName: _value('publisherName'),
        postalAddress: _value('postalAddress'),
        phone: _value('phone'),
        email: _value('email'),
        publicationDirector: _value('publicationDirector'),
        companyName: _value('companyName'),
        legalForm: _value('legalForm'),
        siren: _value('siren'),
        rcs: _value('rcs'),
        shareCapital: _value('shareCapital'),
        vatNumber: _value('vatNumber'),
        hostingProvider: _value('hostingProvider'),
        hostingAddress: _value('hostingAddress'),
      );

  Widget _field(String key, String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _controllers[key],
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Identité juridique'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('publisherName', 'Nom de l’éditeur', required: true),
              _field('postalAddress', 'Adresse postale', required: true),
              _field('phone', 'Téléphone', required: true),
              _field('email', 'E-mail', required: true),
              _field(
                'publicationDirector',
                'Directeur de publication',
                required: true,
              ),
              const Divider(height: 24),
              _field('companyName', 'Dénomination sociale'),
              _field('legalForm', 'Forme juridique'),
              _field('siren', 'SIREN'),
              _field('rcs', 'RCS'),
              _field('shareCapital', 'Capital social'),
              _field('vatNumber', 'TVA intracommunautaire'),
              const Divider(height: 24),
              _field('hostingProvider', 'Hébergeur', required: true),
              _field('hostingAddress', 'Adresse hébergeur', required: true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_profile()),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
