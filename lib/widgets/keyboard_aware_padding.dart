import 'package:flutter/material.dart';

/// Widget qui gère le padding automatiquement selon l'état du clavier
///
/// Cette classe encapsule la logique d'ajustement du padding quand le clavier apparaît/disparaît
/// pour éviter que les contenus ne se chevauchent avec le clavier virtuel.
class KeyboardAwarePadding extends StatelessWidget {
  final Widget child;
  final bool includeBottom;
  final EdgeInsets? basePadding;

  const KeyboardAwarePadding({
    super.key,
    required this.child,
    this.includeBottom = true,
    this.basePadding,
  });

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isPaddingNeeded = keyboardHeight > 0;

    // Calculer le padding du bas
    final bottomPadding =
        isPaddingNeeded ? keyboardHeight : (basePadding?.bottom ?? 0);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: basePadding?.left ?? 0,
        right: basePadding?.right ?? 0,
        top: basePadding?.top ?? 0,
        bottom: includeBottom ? bottomPadding : 0,
      ),
      child: child,
    );
  }
}

/// Widget qui gère automatiquement le scroll + padding pour les formulaires
///
/// Utilise SingleChildScrollView avec le bon keyboardDismissBehavior
/// et applique le padding selon le clavier
class KeyboardAwareForm extends StatelessWidget {
  final Widget child;
  final ScrollController? scrollController;
  final EdgeInsets padding;

  const KeyboardAwareForm({
    super.key,
    required this.child,
    this.scrollController,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: padding.left,
        right: padding.right,
        top: padding.top,
        bottom: padding.bottom + keyboardHeight,
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: child,
      ),
    );
  }
}
