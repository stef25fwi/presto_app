import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileSavePayload {
  const UserProfileSavePayload._();

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
  }) {
    final normalizedEmail = (email ?? '').trim().toLowerCase();
    final normalizedDisplayName = displayName.trim();
    final normalizedAccountType =
        accountType.trim().isEmpty ? 'Particulier' : accountType.trim();
    final normalizedPhone = phone.trim();
    final normalizedCity = city.trim();
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
      'phone': normalizedPhone,
      'selectedFavoriteCategories': selectedFavoriteCategories,
      'selectedFavoriteSubcategories': selectedFavoriteSubcategories,
      'profileCompleted': true,
      'profileCompleteness': completeness,
      'profileUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
