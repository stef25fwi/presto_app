import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

const List<CountryCode> kPhoneCountryCodes = [
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

CountryCode phoneCountryFromCode(String? code) {
  if (code == null) return kPhoneCountryCodes.first;
  return kPhoneCountryCodes.firstWhere(
    (country) => country.code == code,
    orElse: () => kPhoneCountryCodes.first,
  );
}

String phoneHintForCountryCode(String? code) {
  switch ((code ?? '').trim()) {
    case '+590':
      return '690123456';
    case '+596':
      return '696123456';
    case '+594':
      return '694123456';
    case '+262':
      return '692123456';
    case '+689':
      return '87123456';
    case '+33':
    default:
      return '612345678';
  }
}

class _PhoneFieldPrefix extends StatelessWidget {
  final CountryCode selectedCountry;
  final ValueChanged<CountryCode?> onCountryChanged;

  const _PhoneFieldPrefix({
    required this.selectedCountry,
    required this.onCountryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<CountryCode>(
              value: selectedCountry,
              isDense: true,
              borderRadius: BorderRadius.circular(14),
              icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
              items: kPhoneCountryCodes
                  .map(
                    (country) => DropdownMenuItem<CountryCode>(
                      value: country,
                      child: Text(
                        '${country.flag} ${country.code}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onCountryChanged,
            ),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }
}

InputDecoration _buildPhoneDecoration({
  required BuildContext context,
  required InputDecoration? baseDecoration,
  required Widget? label,
  required String? labelText,
  required String? hintText,
  required CountryCode selectedCountry,
  required ValueChanged<CountryCode?> onCountryChanged,
}) {
  final effectiveHintText = hintText ?? phoneHintForCountryCode(selectedCountry.code);
  final decoration = (baseDecoration ?? const InputDecoration()).copyWith(
    label: label,
    labelText: label == null ? (labelText ?? 'Téléphone') : null,
    hintText: effectiveHintText,
    hintStyle: ((baseDecoration ?? const InputDecoration()).hintStyle ??
            const TextStyle())
        .copyWith(
      color: const Color(0xFF9CA3AF),
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
    ),
    prefixIcon: _PhoneFieldPrefix(
      selectedCountry: selectedCountry,
      onCountryChanged: onCountryChanged,
    ),
    prefixIconConstraints: const BoxConstraints(
      minWidth: 124,
      minHeight: 0,
    ),
    border: (baseDecoration ?? const InputDecoration()).border ??
        const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
    contentPadding:
        (baseDecoration ?? const InputDecoration()).contentPadding ??
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );

  return decoration;
}

/// Widget pour saisir un numéro de téléphone avec sélection d'indicatif
/// France métropolitaine + DROM
class PhoneInputField extends StatefulWidget {
  final TextEditingController controller;
  final Widget? label;
  final String? labelText;
  final String? hintText;
  final String? initialCountryCode;
  final InputDecoration? decoration;
  final ValueChanged<String>? onCountryCodeChanged;
  final ValueChanged<String>? onPhoneChanged;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;

  const PhoneInputField({
    super.key,
    required this.controller,
    this.label,
    this.labelText,
    this.hintText,
    this.initialCountryCode,
    this.decoration,
    this.onCountryCodeChanged,
    this.onPhoneChanged,
    this.focusNode,
    this.validator,
  });

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  late CountryCode _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry = phoneCountryFromCode(widget.initialCountryCode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCountryCodeChanged?.call(_selectedCountry.code);
    });
  }

  CountryCode? _fromCode(String? code) {
    return phoneCountryFromCode(code);
  }

  @override
  void didUpdateWidget(covariant PhoneInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCountryCode != null &&
        widget.initialCountryCode != _selectedCountry.code) {
      final next = _fromCode(widget.initialCountryCode);
      if (next != null && next.code != _selectedCountry.code) {
        setState(() {
          _selectedCountry = next;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onCountryCodeChanged?.call(_selectedCountry.code);
        });
      }
    }
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
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      decoration: _buildPhoneDecoration(
        context: context,
        baseDecoration: widget.decoration,
        label: widget.label,
        labelText: widget.labelText,
        hintText: widget.hintText,
        selectedCountry: _selectedCountry,
        onCountryChanged: _onCountryChanged,
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
      ],
      validator: widget.validator,
      onChanged: widget.onPhoneChanged,
    );
  }
}

/// Version compacte : sélecteur d'indicatif + champ sur la même ligne
class PhoneInputFieldCompact extends StatefulWidget {
  final TextEditingController controller;
  final Widget? label;
  final String? labelText;
  final String? hintText;
  final String? initialCountryCode;
  final ValueChanged<String>? onCountryCodeChanged;
  final ValueChanged<String>? onPhoneChanged;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;

  const PhoneInputFieldCompact({
    super.key,
    required this.controller,
    this.label,
    this.labelText,
    this.hintText,
    this.initialCountryCode,
    this.onCountryCodeChanged,
    this.onPhoneChanged,
    this.focusNode,
    this.validator,
  });

  @override
  State<PhoneInputFieldCompact> createState() => _PhoneInputFieldCompactState();
}

class _PhoneInputFieldCompactState extends State<PhoneInputFieldCompact> {
  late CountryCode _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry = phoneCountryFromCode(widget.initialCountryCode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCountryCodeChanged?.call(_selectedCountry.code);
    });
  }

  CountryCode? _fromCode(String? code) {
    return phoneCountryFromCode(code);
  }

  void _onCountryChanged(CountryCode? newCountry) {
    if (newCountry == null) return;
    setState(() {
      _selectedCountry = newCountry;
    });
    widget.onCountryCodeChanged?.call(newCountry.code);
  }

  @override
  void didUpdateWidget(covariant PhoneInputFieldCompact oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCountryCode != null &&
        widget.initialCountryCode != _selectedCountry.code) {
      final next = _fromCode(widget.initialCountryCode);
      if (next != null && next.code != _selectedCountry.code) {
        setState(() {
          _selectedCountry = next;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onCountryCodeChanged?.call(_selectedCountry.code);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      decoration: _buildPhoneDecoration(
        context: context,
        baseDecoration: const InputDecoration(),
        label: widget.label,
        labelText: widget.labelText,
        hintText: widget.hintText,
        selectedCountry: _selectedCountry,
        onCountryChanged: _onCountryChanged,
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
      ],
      validator: widget.validator,
      onChanged: widget.onPhoneChanged,
    );
  }
}
