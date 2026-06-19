import 'package:flutter/material.dart';

import '../../pages/auth/login_page.dart';

class SignedOutAccountFallback extends StatelessWidget {
  const SignedOutAccountFallback({
    super.key,
    this.source,
    this.startInSignup = false,
  });

  final Object? source;
  final bool startInSignup;

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '✅ MON_COMPTE_UTILISE_LOGINPAGE_PIXEL_PERFECT '
      'file=lib/pages/auth/login_page.dart '
      'source=$source startInSignup=$startInSignup',
    );

    return LoginPage(
      onForgotPassword: () {
        Navigator.of(context).pushNamed('/forgot-password');
      },
      onCreateAccount: () {
        Navigator.of(context).pushNamed('/register');
      },
      onGoogle: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion Google à reconnecter ici.'),
          ),
        );
      },
      onApple: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion Apple à reconnecter ici.'),
          ),
        );
      },
    );
  }
}
