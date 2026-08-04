import 'package:flutter/material.dart';

import '../../../../app/presto_design_tokens.dart';

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: PrestoColors.brandOrange,
        // Action principale de tout le parcours d'authentification : en blanc
        // elle plafonnait à 2,94:1, sous le seuil AA du texte normal.
        foregroundColor: PrestoColors.textOnOrange,
        disabledBackgroundColor: const Color(0xFFFFB083),
        disabledForegroundColor: PrestoColors.textOnOrange,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: PrestoColors.textOnOrange,
              ),
            )
          : Icon(icon ?? Icons.login_rounded),
      label: Text(
        isLoading ? 'Veuillez patienter…' : label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}
