import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/friendly_snackbar.dart';
import 'app_operating_mode.dart';
import 'legal_publisher_admin_form.dart';

class OperatingModeAdminTile extends StatefulWidget {
  final AppOperatingModeService? service;

  const OperatingModeAdminTile({super.key, this.service});

  @override
  State<OperatingModeAdminTile> createState() =>
      _OperatingModeAdminTileState();
}

class _OperatingModeAdminTileState extends State<OperatingModeAdminTile> {
  bool _savingMode = false;

  AppOperatingModeService get _service =>
      widget.service ?? AppOperatingModeService();

  String? get _adminId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    unawaited(_service.ensureDefaults(updatedBy: _adminId));
  }

  bool _samePublisher(
    LegalPublisherProfile expected,
    LegalPublisherProfile actual,
  ) {
    final expectedMap = expected.toMap();
    final actualMap = actual.toMap();
    return expectedMap.length == actualMap.length &&
        expectedMap.entries.every(
          (entry) => actualMap[entry.key] == entry.value,
        );
  }

  Future<void> _setCommercial(
    bool enabled,
    AppOperatingModeState state,
  ) async {
    if (_savingMode || enabled == state.mode.isCommercial) return;
    setState(() => _savingMode = true);
    try {
      await _service.setMode(
        enabled ? AppOperatingMode.commercial : AppOperatingMode.freeBeta,
        updatedBy: _adminId,
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
      if (mounted) setState(() => _savingMode = false);
    }
  }

  Future<void> _savePublisher(LegalPublisherProfile profile) async {
    var persisted = false;
    try {
      await _service.updatePublisherProfile(
        profile,
        updatedBy: _adminId,
      );
      persisted = true;

      final storedState = await _service.getState();
      if (!_samePublisher(profile, storedState.publisher)) {
        throw StateError(
          'La fiche juridique relue depuis Firestore ne correspond pas aux informations saisies.',
        );
      }

      final publicState = await _service.getPublicState();
      if (!_samePublisher(profile, publicState.publisher)) {
        throw StateError(
          'Les informations sont enregistrées dans Firestore mais la configuration juridique publique n’est pas encore synchronisée.',
        );
      }

      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Informations juridiques enregistrées et vérifiées en production.',
      );
    } on StateError catch (error) {
      if (!mounted) rethrow;
      showErrorSnackBar(
        context,
        persisted
            ? error.message.toString()
            : 'Impossible d’enregistrer les informations juridiques.',
      );
      rethrow;
    } catch (_) {
      if (!mounted) rethrow;
      showErrorSnackBar(
        context,
        persisted
            ? 'Les informations ont été écrites, mais leur publication n’a pas pu être vérifiée. Réessayez pour confirmer la synchronisation.'
            : 'Impossible d’enregistrer les informations juridiques.',
      );
      rethrow;
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
              const Row(
                children: [
                  Icon(Icons.policy_outlined, color: orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mode d’exploitation et identité juridique',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                'Un seul espace pilote le mode gratuit ou payant et les informations affichées dans les mentions légales.',
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
                onChanged: _savingMode
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
                  _StatusChip(label: state.legalVersion, color: muted),
                  const _StatusChip(
                    label: 'Visible sans connexion',
                    color: green,
                  ),
                ],
              ),
              if (!ready) ...[
                const SizedBox(height: 10),
                const Text(
                  'La mise en ligne conforme et la bascule payante restent verrouillées tant que les champs obligatoires ne sont pas renseignés.',
                  style: TextStyle(
                    color: orange,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              LegalPublisherAdminForm(
                initial: state.publisher,
                mode: state.mode,
                onSave: _savePublisher,
              ),
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
