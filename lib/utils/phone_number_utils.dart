const List<String> kSupportedPhoneCountryCodes = <String>[
  '+590',
  '+596',
  '+594',
  '+262',
  '+689',
  '+33',
];

String phoneCountryCodeForDepartment(String? departmentCode) {
  switch ((departmentCode ?? '').trim()) {
    case '971':
      return '+590';
    case '972':
      return '+596';
    case '973':
      return '+594';
    case '974':
    case '976':
      return '+262';
    case '987':
      return '+689';
    default:
      return '+33';
  }
}

String? phoneCountryCodeFromE164(String? value) {
  final compact = (value ?? '').replaceAll(RegExp(r'\s+'), '');
  for (final code in kSupportedPhoneCountryCodes) {
    if (compact.startsWith(code)) return code;
  }
  return null;
}

String phoneLocalNumberFromE164(String? value) {
  final compact = (value ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
  final code = phoneCountryCodeFromE164(compact);
  if (code == null) return compact;
  final codeDigits = code.replaceAll(RegExp(r'\D'), '');
  final allDigits = compact.replaceAll(RegExp(r'\D'), '');
  if (allDigits.length <= codeDigits.length) return '';
  return allDigits.substring(codeDigits.length);
}

String normalizePhoneNumberE164({
  required String countryCode,
  required String rawPhone,
}) {
  final trimmed = rawPhone.trim();
  if (trimmed.isEmpty) return '';

  final selectedCodeDigits = countryCode.replaceAll(RegExp(r'\D'), '');
  var phoneDigits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (selectedCodeDigits.isEmpty || phoneDigits.isEmpty) return '';

  final explicitInternational = trimmed.startsWith('+') ||
      phoneDigits.startsWith('00');
  if (phoneDigits.startsWith('00')) {
    phoneDigits = phoneDigits.substring(2);
  }

  if (explicitInternational) {
    return '+$phoneDigits';
  }

  for (final supportedCode in kSupportedPhoneCountryCodes) {
    final supportedDigits = supportedCode.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.startsWith(supportedDigits)) {
      return '+$phoneDigits';
    }
  }

  while (phoneDigits.startsWith('0')) {
    phoneDigits = phoneDigits.substring(1);
  }
  if (phoneDigits.isEmpty) return '';

  return '+$selectedCodeDigits$phoneDigits';
}

bool isValidE164PhoneNumber(String value) {
  return RegExp(r'^\+[0-9]{10,15}$').hasMatch(value.trim());
}
