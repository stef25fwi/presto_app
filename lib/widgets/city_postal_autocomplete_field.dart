import 'dart:async';

import 'package:flutter/material.dart';

import '../services/city_search.dart';
import '../services/french_city_postal_validator.dart';

String cityDisplayName(CityRecord city) {
  final match = RegExp(r'^PARIS (\d{2})$').firstMatch(city.name.toUpperCase());
  if (match == null) {
    return city.name;
  }
  final number = int.parse(match.group(1)!);
  final suffix = number == 1 ? 'er' : 'e';
  return 'Paris $number$suffix arrondissement';
}

Future<CityRecord?> pickCanonicalCity(
  BuildContext context,
  TextEditingController postalCodeController,
  CityRecord city,
) async {
  final validator = FrenchCityPostalValidator.instance;
  final choices = validator.postalCodesForCity(city.name);
  if (choices.isEmpty) {
    return city;
  }
  if (choices.length == 1) {
    return choices.first;
  }

  final typedPostalCode =
      FrenchCityPostalValidator.normalizePostalCode(postalCodeController.text);
  if (typedPostalCode.isNotEmpty) {
    for (final choice in choices) {
      if (choice.cp == typedPostalCode) {
        return choice;
      }
    }
  }

  return showModalBottomSheet<CityRecord>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          title: Text(
            'Choisir le code postal - ${city.name}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        ...choices.map(
          (choice) => ListTile(
            title: Text(choice.cp),
            subtitle: Text('${choice.dept} - ${choice.region}'),
            onTap: () => Navigator.pop(context, choice),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
}

/// Widget à utiliser dans tes formulaires.
/// - Tape la ville => suggestions
/// - Clique => remplit ville + CP
/// - Si plusieurs CP => choix via bottom sheet
class CityPostalAutocompleteField extends StatefulWidget {
  final TextEditingController cityController;
  final TextEditingController postalCodeController;
  final InputDecoration decoration;
  final ValueChanged<CityRecord>? onSelectedCity;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const CityPostalAutocompleteField({
    super.key,
    required this.cityController,
    required this.postalCodeController,
    required this.decoration,
    this.onSelectedCity,
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<CityPostalAutocompleteField> createState() =>
      _CityPostalAutocompleteFieldState();
}

class _CityPostalAutocompleteFieldState
    extends State<CityPostalAutocompleteField> {
  Timer? _debounce;
  List<CityRecord> _options = const [];

  @override
  void initState() {
    super.initState();
    widget.cityController.addListener(_onFieldChanged);
    widget.postalCodeController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    widget.cityController.removeListener(_onFieldChanged);
    widget.postalCodeController.removeListener(_onFieldChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onFieldChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), () {
      final q = widget.cityController.text.trim();
      if (q.length < 2) {
        if (!mounted) return;
        setState(() => _options = const []);
        return;
      }

      final res = FrenchCityPostalValidator.instance.searchSuggestions(
        q,
        postalCodeHint: widget.postalCodeController.text,
        limit: 12,
      );

      if (!mounted) return;
      setState(() => _options = res);
    });
  }

  Future<void> _applySelection(CityRecord city) async {
    final selected =
        await pickCanonicalCity(context, widget.postalCodeController, city);
    if (selected == null) {
      return;
    }

    widget.cityController.text = selected.name;
    widget.postalCodeController.text = selected.cp;
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
        controller.value = widget.cityController.value;
        return TextFormField(
          controller: widget.cityController,
          focusNode: focusNode,
          decoration: widget.decoration,
          enabled: widget.enabled,
          validator: widget.validator,
          onChanged: widget.onChanged,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 520),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = list[i];
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
