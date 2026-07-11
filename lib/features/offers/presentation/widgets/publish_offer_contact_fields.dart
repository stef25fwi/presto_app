import 'package:flutter/material.dart';

import '../../../../widgets/city_postal_autocomplete_field.dart';
import '../../../../widgets/phone_input_field.dart';

/// Localisation de l'offre avec ville assistée et code postal.
class PublishOfferLocationFields extends StatelessWidget {
  const PublishOfferLocationFields({
    super.key,
    required this.cityController,
    required this.postalCodeController,
    required this.cityLabel,
    required this.onCitySelected,
    required this.onPostalTap,
    required this.onPostalEditingComplete,
    required this.postalValidator,
    this.cityDecorator,
    this.postalDecorator,
  });

  final TextEditingController cityController;
  final TextEditingController postalCodeController;
  final Widget cityLabel;
  final ValueChanged<CityEntry> onCitySelected;
  final VoidCallback onPostalTap;
  final VoidCallback onPostalEditingComplete;
  final FormFieldValidator<String> postalValidator;
  final Widget Function(Widget child)? cityDecorator;
  final Widget Function(Widget child)? postalDecorator;

  @override
  Widget build(BuildContext context) {
    final cityField = CityPostalAutocompleteField(
      cityController: cityController,
      postalCodeController: postalCodeController,
      onSelected: onCitySelected,
      decoration: InputDecoration(
        label: cityLabel,
        hintText: 'Ex : Les Abymes, Baie-Mahault, Paris...',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );

    final postalField = TextFormField(
      controller: postalCodeController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Code postal',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      onTap: onPostalTap,
      onEditingComplete: onPostalEditingComplete,
      validator: postalValidator,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Localisation',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        cityDecorator?.call(cityField) ?? cityField,
        const SizedBox(height: 8),
        postalDecorator?.call(postalField) ?? postalField,
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Téléphone de contact et option de confidentialité associée.
class PublishOfferPhoneFields extends StatelessWidget {
  const PublishOfferPhoneFields({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.initialCountryCode,
    required this.onCountryCodeChanged,
    required this.onPhoneChanged,
    required this.validator,
    required this.hidePhone,
    required this.onHidePhoneChanged,
    this.phoneDecorator,
  });

  final TextEditingController controller;
  final Widget label;
  final String hintText;
  final String initialCountryCode;
  final ValueChanged<String> onCountryCodeChanged;
  final ValueChanged<String> onPhoneChanged;
  final FormFieldValidator<String> validator;
  final bool hidePhone;
  final ValueChanged<bool> onHidePhoneChanged;
  final Widget Function(Widget child)? phoneDecorator;

  @override
  Widget build(BuildContext context) {
    final phoneField = PhoneInputFieldCompact(
      controller: controller,
      label: label,
      hintText: hintText,
      initialCountryCode: initialCountryCode,
      onCountryCodeChanged: onCountryCodeChanged,
      onPhoneChanged: onPhoneChanged,
      validator: validator,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        phoneDecorator?.call(phoneField) ?? phoneField,
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onHidePhoneChanged(!hidePhone),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Switch(
                  value: hidePhone,
                  onChanged: onHidePhoneChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Masquer mon numéro (les visiteurs verront uniquement l'indicatif)",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
