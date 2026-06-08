import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:presto_app/services/pro_siret_service.dart';

class ProSiretSignupSection extends StatefulWidget {
  const ProSiretSignupSection({
    super.key,
    required this.visible,
    this.onVerified,
  });

  final bool visible;
  final ValueChanged<ProSiretVerificationResult>? onVerified;

  @override
  State<ProSiretSignupSection> createState() => _ProSiretSignupSectionState();
}

class _ProSiretSignupSectionState extends State<ProSiretSignupSection> {
  final TextEditingController _siretController = TextEditingController();
  final ProSiretService _service = ProSiretService();

  bool _loading = false;
  String? _error;
  ProSiretVerificationResult? _result;

  @override
  void dispose() {
    _siretController.dispose();
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
      final result = await _service.verifySiret(_siretController.text);

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
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(14),
            ],
            decoration: InputDecoration(
              labelText: 'Numéro SIRET',
              hintText: '14 chiffres',
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
              text: [
                'Entreprise vérifiée',
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
  });

  final IconData icon;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final value = text?.trim() ?? '';

    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
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
      ],
    );
  }
}
