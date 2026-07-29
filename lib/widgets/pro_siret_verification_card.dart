import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:presto_app/services/pro_siret_service.dart';

typedef ProSiretVerifier = Future<ProSiretVerificationResult> Function(
  String value,
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
  final _controller = TextEditingController();

  bool _loading = false;
  String? _error;
  ProSiretVerificationResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final verifier = widget.verifier ?? ProSiretService().verifySiret;
      final result = await verifier(_controller.text);

      if (!mounted) return;

      setState(() {
        _result = result;
      });

      widget.onVerified?.call(result);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
              'Entrez votre numéro SIRET pour activer votre compte professionnel ilipresto.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.organizationName],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(14),
              ],
              decoration: InputDecoration(
                labelText: 'Numéro SIRET — 14 chiffres',
                hintText: 'Exemple : 73282932000074',
                prefixIcon: const Icon(Icons.business_rounded),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Effacer',
                        onPressed: _loading
                            ? null
                            : () {
                                setState(() {
                                  _controller.clear();
                                  _error = null;
                                  _result = null;
                                });
                              },
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (_) {
                setState(() {
                  _error = null;
                  _result = null;
                });
              },
              onSubmitted: (_) => _loading ? null : _verify(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _verify,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_rounded),
              label: Text(_loading ? 'Vérification...' : 'Vérifier mon SIRET'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _InfoBox(
                icon: Icons.error_outline_rounded,
                title: 'SIRET non validé',
                message: _error!,
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 12),
              _InfoBox(
                icon: Icons.check_circle_rounded,
                title: 'Entreprise trouvée',
                message: [
                  if (result.companyName.isNotEmpty) result.companyName,
                  if (result.address.isNotEmpty) result.address,
                  [
                    result.postalCode,
                    result.city,
                  ].where((e) => e.isNotEmpty).join(' '),
                  if (result.nafCode.isNotEmpty) 'Activité : ${result.nafCode}',
                  'Statut : compte pro vérifié',
                ].where((e) => e.isNotEmpty).join('\n'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
