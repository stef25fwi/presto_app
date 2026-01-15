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

/// Wrapper pour les pages qui ont besoin de gérer le clavier correctement
/// sans que le Scaffold ne se redimensionne
class KeyboardAwarePage extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final FloatingActionButton? floatingActionButton;
  final Color backgroundColor;
  final bool extendBody;

  const KeyboardAwarePage({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.backgroundColor = Colors.white,
    this.extendBody = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        // NE PAS laisser le Scaffold se redimensionner au clavier
        // Le padding sera géré via AnimatedPadding dans le body
        resizeToAvoidBottomInset: false,
        appBar: appBar,
        backgroundColor: backgroundColor,
        extendBody: extendBody,
        body: KeyboardAwarePadding(
          includeBottom: true,
          child: body,
        ),
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}
