import 'package:flutter/material.dart';

class ResetPasswordSuccessPage extends StatelessWidget {
  const ResetPasswordSuccessPage({
    super.key,
    required this.email,
  });

  static const routeName = '/reset-password-success';

  final String email;

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6600);

    return Scaffold(
      appBar: AppBar(title: const Text('E-mail envoyé')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mark_email_read, size: 80, color: orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Consultez votre boîte e-mail',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Si un compte iliprestō existe avec l’adresse $email, vous recevrez un lien sécurisé pour choisir un nouveau mot de passe.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context)
                          .popUntil((route) => route.isFirst),
                      child: const Text('Retour'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
