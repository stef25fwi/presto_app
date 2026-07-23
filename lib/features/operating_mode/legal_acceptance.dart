import 'app_operating_mode.dart';

Map<String, dynamic> legalAcceptanceFromUserData(
  Map<String, dynamic>? userData,
) {
  final raw = userData?['legalAcceptance'];
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const <String, dynamic>{};
}

bool hasAcceptedCurrentLegalDocuments(
  Map<String, dynamic>? userData,
  AppOperatingModeState state,
) {
  final acceptance = legalAcceptanceFromUserData(userData);
  return acceptance['operatingMode'] == state.mode.firestoreValue &&
      acceptance['legalVersion'] == state.legalVersion &&
      acceptance['cguVersion'] == state.cguVersion &&
      acceptance['privacyVersion'] == state.privacyVersion;
}
