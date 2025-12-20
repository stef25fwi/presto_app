import 'package:flutter/material.dart';

/// Modèle pour représenter les indicatifs téléphoniques
class CountryCode {
  final String label;
  final String code;
  final String flag;

  const CountryCode({
    required this.label,
    required this.code,
    required this.flag,
  });
}

/// Widget pour saisir un numéro de téléphone avec sélection d'indicatif
/// France métropolitaine + DROM
class PhoneInputField extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final InputDecoration? decoration;
  final ValueChanged<String>? onCountryCodeChanged;
  final ValueChanged<String>? onPhoneChanged;
  final FocusNode? focusNode;

  const PhoneInputField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.decoration,
    this.onCountryCodeChanged,
    this.onPhoneChanged,
    this.focusNode,
  });

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  // Les indicatifs France + DROM + COM
  static const List<CountryCode> countryCodes = [
    CountryCode(
      label: 'France métropole',
      code: '+33',
      flag: '🇫🇷',
    ),
    CountryCode(
      label: 'Guadeloupe (971)',
      code: '+590',
      flag: '🇬🇵',
    ),
    CountryCode(
      label: 'Martinique (972)',
      code: '+596',
      flag: '🇲🇶',
    ),
    CountryCode(
      label: 'Guyane (973)',
      code: '+594',
      flag: '🇬🇫',
    ),
    CountryCode(
      label: 'La Réunion (974)',
      code: '+262',
      flag: '🇷🇪',
    ),
    CountryCode(
      label: 'Mayotte (976)',
      code: '+262',
      flag: '🇾🇹',
    ),
    CountryCode(
      label: 'Polynésie française',
      code: '+689',
      flag: '🇵🇫',
    ),
  ];

  late CountryCode _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry = countryCodes.first; // France par défaut
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCountryCodeChanged?.call(_selectedCountry.code);
    });
  }

  void _onCountryChanged(CountryCode? newCountry) {
    if (newCountry != null) {
      setState(() {
        _selectedCountry = newCountry;
      });
      widget.onCountryCodeChanged?.call(newCountry.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sélection de l'indicatif
        DropdownButton<CountryCode>(
          value: _selectedCountry,
          isExpanded: true,
          items: countryCodes
              .map(
                (country) => DropdownMenuItem<CountryCode>(
                  value: country,
                  child: Text(
                    '${country.flag} ${country.label} (${country.code})',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: _onCountryChanged,
        ),
        const SizedBox(height: 12),
        
        // Champ téléphone avec préfixe indicatif
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          decoration: (widget.decoration ?? InputDecoration()).copyWith(
            labelText: widget.labelText ?? 'Téléphone',
            hintText: widget.hintText ?? 'Ex: 612345678',
            prefixText: '${_selectedCountry.code} ',
            prefixIcon: const Icon(Icons.phone_outlined),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          keyboardType: TextInputType.phone,
          onChanged: widget.onPhoneChanged,
        ),
      ],
    );
  }
}

/// Version compacte : sélecteur d'indicatif + champ sur la même ligne
class PhoneInputFieldCompact extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final ValueChanged<String>? onCountryCodeChanged;
  final ValueChanged<String>? onPhoneChanged;
  final FocusNode? focusNode;

  const PhoneInputFieldCompact({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.onCountryCodeChanged,
    this.onPhoneChanged,
    this.focusNode,
  });

  @override
  State<PhoneInputFieldCompact> createState() =>
      _PhoneInputFieldCompactState();
}

class _PhoneInputFieldCompactState extends State<PhoneInputFieldCompact> {
  static const List<CountryCode> countryCodes = [
    CountryCode(label: 'France', code: '+33', flag: '🇫🇷'),
    CountryCode(label: 'Guadeloupe', code: '+590', flag: '🇬🇵'),
    CountryCode(label: 'Martinique', code: '+596', flag: '🇲🇶'),
    CountryCode(label: 'Guyane', code: '+594', flag: '🇬🇫'),
    CountryCode(label: 'La Réunion', code: '+262', flag: '🇷🇪'),
    CountryCode(label: 'Mayotte', code: '+262', flag: '🇾🇹'),
    CountryCode(label: 'Polynésie', code: '+689', flag: '🇵🇫'),
  ];

  late CountryCode _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry = countryCodes.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCountryCodeChanged?.call(_selectedCountry.code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sélecteur compact
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<CountryCode>(
            value: _selectedCountry,
            underline: const SizedBox.shrink(),
            items: countryCodes
                .map(
                  (country) => DropdownMenuItem<CountryCode>(
                    value: country,
                    child: Text(
                      '${country.flag} ${country.code}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: (newCountry) {
              if (newCountry != null) {
                setState(() {
                  _selectedCountry = newCountry;
                });
                widget.onCountryCodeChanged?.call(newCountry.code);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        
        // Champ téléphone flexible
        Expanded(
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            decoration: InputDecoration(
              labelText: widget.labelText ?? 'Téléphone',
              hintText: widget.hintText ?? '612345678',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.phone,
            onChanged: widget.onPhoneChanged,
          ),
        ),
      ],
    );
  }
}
