// lib/widgets/keyboard_autocomplete_field.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// Champ AutoComplete réutilisable + compatible Web/Desktop.
/// IMPORTANT: RawAutocomplete impose T extends Object (non-nullable).
class KeyboardAutocompleteField<T extends Object> extends StatelessWidget {
  const KeyboardAutocompleteField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.optionsBuilder,
    required this.displayStringForOption,
    required this.onSelected,
    this.decoration,
    this.textInputAction,
    this.keyboardType,
    this.maxOptions = 20,
    this.maxOptionsHeight = 260,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Retourne les options selon le texte saisi.
  final FutureOr<Iterable<T>> Function(TextEditingValue) optionsBuilder;

  /// Comment afficher un item dans la liste.
  final String Function(T) displayStringForOption;

  /// Quand on clique / valide une option.
  final ValueChanged<T> onSelected;

  final InputDecoration? decoration;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;

  final int maxOptions;
  final double maxOptionsHeight;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<T>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: displayStringForOption,
      optionsBuilder: (TextEditingValue value) async {
        final res = await optionsBuilder(value);
        // Sécurité : limite le nombre d'options (évite listes énormes = lourd sur Web)
        return res.take(maxOptions);
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, textCtrl, fNode, onFieldSubmitted) {
        return TextField(
          controller: textCtrl,
          focusNode: fNode,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          decoration: decoration,
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelect, options) {
        final opts = options.toList(growable: false);
        final highlightedIndex = AutocompleteHighlightedOption.of(context);

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxOptionsHeight),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: opts.length,
                itemBuilder: (context, index) {
                  final option = opts[index];
                  final isHighlighted = index == highlightedIndex;

                  return InkWell(
                    onTap: () => onSelect(option),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      color: isHighlighted
                          ? Theme.of(context).focusColor.withOpacity(0.12)
                          : null,
                      child: Text(
                        displayStringForOption(option),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<T>(
      textEditingController: widget.controller,
      focusNode: widget.focusNode,
      displayStringForOption: widget.displayStringForOption,
      optionsBuilder: widget.optionsBuilder,
      onSelected: (opt) {
        widget.onSelected(opt);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: widget.decoration,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        _clampHighlight(list.length);

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxOptionsHeight.toDouble(), maxWidth: 520),
              child: Focus(
                autofocus: true,
                onKeyEvent: (node, event) => _onKey(node, event, list, onSelected),
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final opt = list[i];
                    final selected = i == _highlightIndex;

                    return InkWell(
                      onTap: () => onSelected(opt),
                      child: Container(
                        color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : null,
                        child: ListTile(
                          dense: true,
                          title: Text(widget.displayStringForOption(opt)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
