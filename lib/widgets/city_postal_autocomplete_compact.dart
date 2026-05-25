import 'dart:async';

import 'package:flutter/material.dart';

import '../services/city_search.dart';
import '../services/french_city_postal_validator.dart';
import 'city_postal_autocomplete_field.dart';

class CityPostalAutocompleteCompact extends StatefulWidget {
  final TextEditingController cityCtrl;
  final TextEditingController cpCtrl;
  final InputDecoration decoration;
  final ValueChanged<CityRecord>? onSelectedCity;

  const CityPostalAutocompleteCompact({
    super.key,
    required this.cityCtrl,
    required this.cpCtrl,
    required this.decoration,
    this.onSelectedCity,
  });

  @override
  State<CityPostalAutocompleteCompact> createState() =>
      _CityPostalAutocompleteCompactState();
}

class _CityPostalAutocompleteCompactState
    extends State<CityPostalAutocompleteCompact> {
  Timer? _debounce;
  List<CityRecord> _options = const [];

  @override
  void initState() {
    super.initState();
    widget.cityCtrl.addListener(_onChanged);
    widget.cpCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.cityCtrl.removeListener(_onChanged);
    widget.cpCtrl.removeListener(_onChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), () {
      final q = widget.cityCtrl.text.trim();
      if (q.length < 2) {
        if (mounted) setState(() => _options = const []);
        return;
      }
      final res = FrenchCityPostalValidator.instance.searchSuggestions(
        q,
        postalCodeHint: widget.cpCtrl.text,
        limit: 10,
      );
      if (!mounted) return;
      setState(() => _options = res);
    });
  }

  Future<void> _applySelection(CityRecord city) async {
    final selected = await pickCanonicalCity(context, widget.cpCtrl, city);
    if (selected == null) {
      return;
    }

    widget.cityCtrl.text = selected.name;
    widget.cpCtrl.text = selected.cp;
    widget.onSelectedCity?.call(selected);

    if (!mounted) return;
    setState(() => _options = const []);
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<CityRecord>(
      optionsBuilder: (_) => _options,
      displayStringForOption: cityDisplayName,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        controller.value = widget.cityCtrl.value;
        return TextFormField(
          controller: widget.cityCtrl,
          focusNode: focusNode,
          decoration: widget.decoration,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? "Ville obligatoire" : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 520),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final c = options.elementAt(i);
                  final choices =
                      FrenchCityPostalValidator.instance.postalCodesForCity(c.name);
                  final cpLabel = choices.isEmpty
                      ? c.cp
                      : choices.length == 1
                          ? choices.first.cp
                          : '${choices.first.cp} … (+${choices.length - 1})';
                  return ListTile(
                    dense: true,
                    title: Text(cityDisplayName(c)),
                    subtitle: Text(
                        '${c.dept}${cpLabel.isNotEmpty ? ' • $cpLabel' : ''}'),
                    onTap: () => onSelected(c),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (c) => _applySelection(c),
    );
  }
}
