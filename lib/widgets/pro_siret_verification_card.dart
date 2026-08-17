import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:presto_app/services/pro_siret_service.dart';
import 'package:presto_app/widgets/pro_declared_leader_fields.dart';
import 'package:presto_app/widgets/pro_siret_result_box.dart';
import 'package:presto_app/widgets/verification_status_tooltip.dart';

typedef ProSiretVerifier = Future<ProSiretVerificationResult> Function(
  String siret,
  String leaderFirstName,
  String leaderLastName,
);

class ProSiretVerificationCard extends StatefulWidget {
  const ProSiretVerificationCard({
    super.key,
    this.onVerified,
    this.verifier,
  });

  final ValueChanged<ProSiretVerificationResult>? onVerified;
  final ProSiretVerifier? verifier;

  @override
  State<ProSiretVerificationCard> createState() =>
      _ProSiretVerificationCardState();
}

class _ProSiretVerificationCardState extends State<ProSiretVerificationCard> {
  final _formKey = GlobalKey<FormState>();
  final _siretController = TextEditingController();
  final _leaderFirstNameController = TextEditingController();
  final _leaderLastNameController = TextEditingController();
  bool _loading = false;
  String? _error;
  ProSiretVerificationResult? _result;

  @override
  void dispose() {
    _siretController.dispose();
    _leaderFirstNameController.dispose();
    _leaderLastNameController.dispose();
    super.dispose();
  }

  void _invalidateResult() {
    if (_result == null && _error == null) return;
    setState(() {
      _result = null;
      _error = null;
    });
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final verifier = widget.verifier ??
          (siret, firstName, lastName) => ProSiretService().verifySiret(
                siret,
                leaderFirstName: firstName,
                leaderLastName: lastName,
              );
      final result = await verifier(
        _siretController.text,
        _leaderFirstNameController.text,
        _leaderLastNameController.text,
      );
      if (!mounted) return;
      setState(() => _result = result);
      widget.onVerified?.call(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Vérification du compte pro',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vérifiez le SIRET et la concordance du dirigeant déclaré avec les données administratives disponibles.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _siretController,
                enabled: !_loading,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(14),
                ],
                decoration: const InputDecoration(
                  labelText: 'Numéro SIRET — 14 chiffres',
                  hintText: 'Exemple : 73282932000074',
                  prefixIcon: Icon(Icons.business_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value ?? '').replaceAll(RegExp(r'\D'), '').length == 14
                        ? null
                        : 'SIRET obligatoire : 14 chiffres.',
                onChanged: (_) => _invalidateResult(),
              ),
              const SizedBox(height: 14),
              ProDeclaredLeaderFields(
                firstNameController: _leaderFirstNameController,
                lastNameController: _leaderLastNameController,
                enabled: !_loading,
                onChanged: _invalidateResult,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _loading ? null : _verify,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_rounded),
                label: Text(
                  _loading ? 'Vérification...' : 'Vérifier SIRET + dirigeant',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ProSiretResultBox(
                  icon: Icons.error_outline_rounded,
                  title: 'Vérification non validée',
                  message: _error!,
                ),
              ],
              if (result != null) ...[
                const SizedBox(height: 12),
                ProSiretResultBox(
                  icon: Icons.check_circle_rounded,
                  title: 'SIRET + dirigeant concordants',
                  tooltipMessage: kSiretLeaderMatchDisclaimer,
                  message: [
                    if (result.companyName.isNotEmpty) result.companyName,
                    if (result.declaredLeaderFirstName.isNotEmpty ||
                        result.declaredLeaderLastName.isNotEmpty)
                      'Dirigeant déclaré : ${result.declaredLeaderFirstName} ${result.declaredLeaderLastName}'.trim(),
                    if (result.declaredLeaderRole.isNotEmpty)
                      'Qualité : ${result.declaredLeaderRole}',
                    if (result.city.isNotEmpty)
                      '${result.postalCode} ${result.city}'.trim(),
                    'Concordance administrative uniquement — ce contrôle ne prouve pas l’identité de la personne connectée.',
                  ].where((e) => e.isNotEmpty).join('\n'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
