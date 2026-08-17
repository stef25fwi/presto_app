import 'package:flutter/material.dart';

import '../app_core.dart' show kPrestoOrange;

/// Bouton d'enregistrement en pied d'écran, avec état de sauvegarde en
/// cours. Extrait de `pages/fiche_pro_page.dart` pour rester sous le
/// budget de lignes d'un écran.
class PrestoSaveFooterButton extends StatelessWidget {
  const PrestoSaveFooterButton({
    super.key,
    required this.isSaving,
    required this.onSave,
    this.label = 'Enregistrer',
    this.savingLabel = 'Enregistrement…',
  });

  final bool isSaving;
  final VoidCallback? onSave;
  final String label;
  final String savingLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrestoOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              isSaving ? savingLabel : label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}
