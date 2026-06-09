import 'package:flutter/material.dart';

class SiretVerificationPage extends StatefulWidget {
  const SiretVerificationPage({super.key});

  static const routeName = '/siret-verification';

  @override
  State<SiretVerificationPage> createState() => _SiretVerificationPageState();
}

class _SiretVerificationPageState extends State<SiretVerificationPage> {
  final TextEditingController _siretController = TextEditingController();

  @override
  void dispose() {
    _siretController.dispose();
    super.dispose();
  }

  String get _cleanSiret => _siretController.text.replaceAll(RegExp(r'\D'), '');

  bool get _isValidFormat => _cleanSiret.length == 14;

  void _showPendingMessage() {
    final message = _isValidFormat
        ? 'Demande prête à être envoyée en vérification.'
        : 'Le SIRET doit contenir 14 chiffres.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isValidFormat = _isValidFormat;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérifier mon SIRET'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Vérification professionnelle',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Renseigne ton SIRET pour renforcer la confiance sur ta fiche Pro.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _siretController,
            keyboardType: TextInputType.number,
            maxLength: 14,
            decoration: InputDecoration(
              labelText: 'SIRET',
              hintText: '14 chiffres',
              border: const OutlineInputBorder(),
              suffixIcon: isValidFormat
                  ? const Icon(Icons.check_circle_outline)
                  : const Icon(Icons.info_outline),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(
                isValidFormat ? 'Format valide' : 'Format incomplet',
              ),
              subtitle: Text(
                isValidFormat
                    ? 'Le SIRET pourra passer en statut en_attente.'
                    : 'Le SIRET doit contenir exactement 14 chiffres.',
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _showPendingMessage,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Envoyer en vérification'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Note : cette page sera reliée au service Firestore à l’étape suivante.',
          ),
        ],
      ),
    );
  }
}
