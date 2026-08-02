import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/presto_design_tokens.dart';

/// Surface interactive commune aux composants personnalisés iliprestō.
///
/// Elle ajoute une sémantique de bouton, la navigation clavier Entrée/Espace,
/// un focus visible, un curseur adapté et un état pressé sans imposer un style
/// visuel particulier au contenu.
class PrestoAccessibleAction extends StatefulWidget {
  const PrestoAccessibleAction({
    super.key,
    required this.child,
    required this.onActivate,
    this.semanticLabel,
    this.semanticHint,
    this.semanticValue,
    this.selected,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(PrestoRadii.md),
    ),
    this.excludeChildSemantics = false,
    this.behavior = HitTestBehavior.opaque,
    this.onPressedChanged,
  });

  final Widget child;
  final VoidCallback? onActivate;
  final String? semanticLabel;
  final String? semanticHint;
  final String? semanticValue;
  final bool? selected;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final BorderRadius borderRadius;
  final bool excludeChildSemantics;
  final HitTestBehavior behavior;
  final ValueChanged<bool>? onPressedChanged;

  @override
  State<PrestoAccessibleAction> createState() =>
      _PrestoAccessibleActionState();
}

class _PrestoAccessibleActionState extends State<PrestoAccessibleAction> {
  bool _showFocus = false;
  bool _pressed = false;

  bool get _isEnabled => widget.enabled && widget.onActivate != null;

  void _activate() {
    if (!_isEnabled) return;
    widget.onActivate?.call();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    widget.onPressedChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: _isEnabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      value: widget.semanticValue,
      excludeSemantics:
          widget.excludeChildSemantics && widget.semanticLabel != null,
      onTap: _isEnabled ? _activate : null,
      child: FocusableActionDetector(
        enabled: _isEnabled,
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        mouseCursor:
            _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (value) {
          if (_showFocus == value) return;
          setState(() => _showFocus = value);
        },
        child: GestureDetector(
          behavior: widget.behavior,
          onTap: _isEnabled ? _activate : null,
          onTapDown: _isEnabled ? (_) => _setPressed(true) : null,
          onTapUp: _isEnabled ? (_) => _setPressed(false) : null,
          onTapCancel: _isEnabled ? () => _setPressed(false) : null,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              widget.child,
              if (_showFocus)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: widget.borderRadius,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_pressed)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: widget.borderRadius,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
