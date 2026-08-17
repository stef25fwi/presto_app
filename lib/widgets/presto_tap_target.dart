import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Enveloppe [Semantics] + [Material] + [InkWell] pour rendre une zone
/// tactile accessible au clavier et aux lecteurs d'écran : focus Tab,
/// activation Entrée/Espace et rôle bouton, sans changement visuel
/// (`color` transparent par défaut).
///
/// Centralise un motif répété à chaque correctif d'accessibilité
/// (voir docs/evidence/ux/accessibility-audit.md §3bis) plutôt que de le
/// dupliquer à chaque site d'appel.
class PrestoTapTarget extends StatelessWidget {
  const PrestoTapTarget({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.customSemanticsActions,
    this.semanticLabel,
    this.button = true,
    this.selected,
    this.toggled,
    this.enabled,
    this.shape,
    this.borderRadius,
    this.color = Colors.transparent,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Actions accessibles supplémentaires (ex. l'appui long, sans équivalent
  /// clavier ni geste garanti chez tous les lecteurs d'écran) exposées comme
  /// actions discrètes plutôt que comme seul geste tactile.
  final Map<CustomSemanticsAction, VoidCallback>? customSemanticsActions;
  final String? semanticLabel;
  final bool button;
  final bool? selected;
  final bool? toggled;
  final bool? enabled;
  final ShapeBorder? shape;
  final BorderRadius? borderRadius;
  final Color color;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: button,
      selected: selected,
      toggled: toggled,
      enabled: enabled,
      label: semanticLabel,
      customSemanticsActions: customSemanticsActions,
      child: Material(
        color: color,
        shape: shape,
        borderRadius: shape == null ? borderRadius : null,
        clipBehavior: clipBehavior,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          customBorder: shape,
          borderRadius: shape == null ? borderRadius : null,
          child: child,
        ),
      ),
    );
  }
}
