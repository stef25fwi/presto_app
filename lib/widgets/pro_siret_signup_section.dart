import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:presto_app/services/pro_siret_service.dart';
import 'package:presto_app/widgets/verification_status_tooltip.dart';

typedef ProSiretPreVerifier = Future<ProSiretVerificationResult> Function(
  String rawSiret,
);

class ProSiretSignupSection extends StatefulWidget {
  const ProSiretSignupSection({
    super.key,
    required this.visible,
    this.onSiretChanged,
    this.onVerified,
    this.preVerifier,
  });

  final bool visible;
  final ValueChanged<String>? onSiretChanged;
  final ValueChanged<ProSiretVerificationResult>? onVerified;
  final ProSiretPreVerifier? preVerifier;

  @override
  State<ProSiretSignupSection> createState() => _ProSiretSignupSectionState();
}

class _ProSiretSignupSectionState extends State<ProSiretSignupSection> {
  final TextEditingController _siretController = TextEditingController();

  ProSiretService get _service => ProSiretService();

  bool _loading = false;
  String? _error;
  ProSiretVerificationResult? _result;

  @override
  void dispose() {
    _siretController.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    widget.onSiretChanged?.call(value);

    if (_result != null || _error != null) {
      setState(() {
        _result = null;
        _error = null;
      });
    }
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      // Pré-vérification autorisée avant connexion :
      // App Check obligatoire, aucune écriture dans users/pro_profiles.
      final verifier = widget.preVerifier ?? _service.preVerifySiret;
      final result = await verifier(_siretController.text);

      if (!mounted) return;

      setState(() {
        _result = result;
      });

      widget.onVerified?.call(result);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
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
    if (!widget.visible) {
      return const SizedBox.shrink();
    }

    final error = _error;
    final result = _result;

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _siretController,
            onChanged: _handleChanged,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(14),
            ],
            decoration: InputDecoration(
              labelText: 'Numéro SIRET — 14 chiffres',
              hintText: 'Exemple : 73282932000074',
              prefixIcon: const Icon(Icons.business_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : _verify,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_outlined),
            label: Text(
              _loading ? 'Vérification du SIRET...' : 'Vérifier mon SIRET',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            _SiretMessage(
              icon: Icons.error_outline_rounded,
              text: error,
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 8),
            _SiretMessage(
              icon: Icons.check_circle_outline_rounded,
              tooltipMessage: kSiretVerificationDisclaimer,
              text: [
                'SIRET vérifié',
                if (result.companyName.isNotEmpty) result.companyName,
                if (result.city.isNotEmpty) result.city,
              ].join(' · '),
            ),
          ],
        ],
      ),
    );
  }
}

class _SiretMessage extends StatelessWidget {
  const _SiretMessage({
    required this.icon,
    required this.text,
    this.tooltipMessage,
  });

  final IconData icon;
  final String? text;
  final String? tooltipMessage;

  @override
  Widget build(BuildContext context) {
    final value = text?.trim() ?? '';

    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (tooltipMessage != null) ...[
          const SizedBox(width: 6),
          const Icon(Icons.info_outline_rounded, size: 17),
        ],
      ],
    );

    final tooltip = tooltipMessage;
    if (tooltip == null) return content;

    return VerificationStatusTooltip(
      message: tooltip,
      child: content,
    );
  }
}
