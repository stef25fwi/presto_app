import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/phone_number_utils.dart';

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
    List<String> selectedFavoriteCategories = const <String>[],
    List<String> selectedFavoriteSubcategories = const <String>[],
    List<String> selectedFavoriteDepartements = const <String>[],
  }) {
    final normalizedEmail = (email ?? '').trim().toLowerCase();
    final normalizedDisplayName = displayName.trim();
    final normalizedAccountType =
        accountType.trim().isEmpty ? 'Particulier' : accountType.trim();
    final normalizedPhone = phone.trim();
    final phoneCountryCode = phoneCountryCodeFromE164(normalizedPhone);
    final cityResolution = _resolveCityAndPostalCode(city);
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
      if (phoneCountryCode != null) 'phoneCountryCode': phoneCountryCode,
      'selectedFavoriteCategories': selectedFavoriteCategories,
      'selectedFavoriteSubcategories': selectedFavoriteSubcategories,
      'selectedFavoriteDepartements': selectedFavoriteDepartements,
      'profileCompleted': true,
      'profileCompleteness': completeness,
      'profileUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
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
      city: city.isEmpty ? trimmed : city,
      postalCode: postalCode,
    );
  }
}
