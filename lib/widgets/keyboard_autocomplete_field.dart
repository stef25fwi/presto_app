import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardAutocompleteField<T> extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;

  final Iterable<T> Function(TextEditingValue value) optionsBuilder;
  final String Function(T option) displayStringForOption;
  final void Function(T option) onSelected;

  final int maxOptionsHeight;

  const KeyboardAutocompleteField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.decoration,
    required this.optionsBuilder,
    required this.displayStringForOption,
    required this.onSelected,
    this.maxOptionsHeight = 300,
  });

  @override
  State<KeyboardAutocompleteField<T>> createState() => _KeyboardAutocompleteFieldState<T>();
}

class _KeyboardAutocompleteFieldState<T> extends State<KeyboardAutocompleteField<T>> {
  int _highlightIndex = 0;
  final ScrollController _scroll = ScrollController();

  void _clampHighlight(int len) {
    if (len <= 0) {
      _highlightIndex = 0;
      return;
    }
    if (_highlightIndex < 0) _highlightIndex = 0;
    if (_highlightIndex > len - 1) _highlightIndex = len - 1;
  }

  void _ensureVisible(int index) {
    const itemExtent = 56.0; // approx ListTile height
    final target = index * itemExtent;
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, List<T> list, AutocompleteOnSelected<T> onSelected) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightIndex++;
        _clampHighlight(list.length);
      });
      _ensureVisible(_highlightIndex);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightIndex--;
        _clampHighlight(list.length);
      });
      _ensureVisible(_highlightIndex);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (list.isNotEmpty) {
        onSelected(list[_highlightIndex]);
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.focusNode.unfocus(); // ferme l'overlay
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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
