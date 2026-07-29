import 'package:flutter/material.dart';

const Color kFicheProOrange = Color(0xFFFF6600);

/// Champs et bouton de confirmation communs aux feuilles d'édition de la
/// fiche professionnelle.
InputDecoration ficheProInputDecoration(String hint) => InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );

Widget ficheProConfirmButton(BuildContext ctx, VoidCallback onPressed) =>
    FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: kFicheProOrange,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: onPressed,
      child: const Text(
        'Confirmer',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
