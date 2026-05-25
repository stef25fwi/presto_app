import 'package:cloud_firestore/cloud_firestore.dart';

import 'city_search.dart';
import 'french_city_postal_validator.dart';

class UserProfileSavePayload {
  const UserProfileSavePayload._();

  static final RegExp _postalCodePattern =
      RegExp(r'\b(97\d{3}|98\d{3}|\d{5})\b');

  static const List<String> _requiredFields = <String>[
    'displayName',
    'city',
    'phone',
  ];

  static double calculateCompleteness({
    required String displayName,
    required String city,
    required String phone,
  }) {
    final values = <String, String>{
      'displayName': displayName,
      'city': city,
      'phone': phone,
    };
    final filled = _requiredFields
        .where((field) => (values[field] ?? '').trim().isNotEmpty)
        .length;
    return filled / _requiredFields.length;
  }

  static Map<String, dynamic> build({
    required String uid,
    required String? email,
    required String displayName,
    required String accountType,
    required String phone,
    required String city,
    String? postalCode,
    List<String> selectedFavoriteCategories = const <String>[],
    List<String> selectedFavoriteSubcategories = const <String>[],
  }) {
    final normalizedEmail = (email ?? '').trim().toLowerCase();
    final normalizedDisplayName = displayName.trim();
    final normalizedAccountType =
        accountType.trim().isEmpty ? 'Particulier' : accountType.trim();
    final normalizedPhone = phone.trim();
    final cityResolution = _resolveCanonicalLocation(
      city: city,
      postalCode: postalCode,
    );
    final normalizedCity = cityResolution.city;
    final normalizedPostalCode = cityResolution.postalCode;
    final completeness = calculateCompleteness(
      displayName: normalizedDisplayName,
      city: normalizedCity,
      phone: normalizedPhone,
    );

    return <String, dynamic>{
      'uid': uid,
      if (normalizedEmail.isNotEmpty) 'email': normalizedEmail,
      'pseudo': normalizedDisplayName,
      'displayName': normalizedDisplayName,
      'accountType': normalizedAccountType,
      'city': normalizedCity,
      'ville': normalizedCity,
      'commune': normalizedCity,
      'locality': normalizedCity,
      if (normalizedPostalCode.isNotEmpty) 'postalCode': normalizedPostalCode,
      if (normalizedPostalCode.isNotEmpty) 'codePostal': normalizedPostalCode,
      if (normalizedPostalCode.isNotEmpty) 'zipCode': normalizedPostalCode,
      if (normalizedPostalCode.isNotEmpty) 'cp': normalizedPostalCode,
      'phone': normalizedPhone,
      'selectedFavoriteCategories': selectedFavoriteCategories,
      'selectedFavoriteSubcategories': selectedFavoriteSubcategories,
      'profileCompleted': true,
      'profileCompleteness': completeness,
      'profileUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static ({String city, String postalCode}) _resolveCanonicalLocation({
    required String city,
    String? postalCode,
  }) {
    final explicitPostalCode = (postalCode ?? '').trim();
    final resolved = FrenchCityPostalValidator.instance.resolveCanonicalCity(
      city: city,
      postalCode: explicitPostalCode,
    );
    if (resolved != null) {
      return (city: resolved.name.trim(), postalCode: resolved.cp.trim());
    }

    final explicitCity = city.trim();
    if (explicitCity.isNotEmpty && explicitPostalCode.isNotEmpty) {
      return (city: explicitCity, postalCode: explicitPostalCode);
    }

    return _resolveCityAndPostalCode(explicitCity);
  }

  static ({String city, String postalCode}) _resolveCityAndPostalCode(
    String rawCity,
  ) {
    final trimmed = rawCity.trim();
    final match = _postalCodePattern.firstMatch(trimmed);
    final postalCode = match?.group(1) ?? '';
    final city = trimmed
        .replaceAll(RegExp(r'\(\s*(97\d{3}|98\d{3}|\d{5})\s*\)'), '')
        .replaceAll(_postalCodePattern, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return (
      city: _normalizeFallbackCity(city.isEmpty ? trimmed : city),
      postalCode: postalCode,
    );
  }

  static String _normalizeFallbackCity(String rawCity) {
    final trimmed = rawCity.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final normalizedPostalCode =
        FrenchCityPostalValidator.normalizePostalCode(trimmed);
    final candidates = normalizedPostalCode.isNotEmpty
        ? FrenchCityPostalValidator.instance.citiesForPostalCode(
            normalizedPostalCode,
          )
        : const <CityRecord>[];
    if (candidates.length == 1) {
      return candidates.first.name;
    }
    return trimmed;
  }
}
