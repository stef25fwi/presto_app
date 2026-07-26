import 'package:cloud_functions/cloud_functions.dart';

class ProSiretVerificationResult {
  const ProSiretVerificationResult({
    required this.ok,
    required this.siret,
    required this.siren,
    required this.companyName,
    required this.address,
    required this.postalCode,
    required this.city,
    required this.nafCode,
    required this.proStatus,
  });

  final bool ok;
  final String siret;
  final String siren;
  final String companyName;
  final String address;
  final String postalCode;
  final String city;
  final String nafCode;
  final String proStatus;

  factory ProSiretVerificationResult.fromMap(Map<String, dynamic> map) {
    return ProSiretVerificationResult(
      ok: map['ok'] == true,
      siret: (map['siret'] ?? '').toString(),
      siren: (map['siren'] ?? '').toString(),
      companyName: (map['companyName'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      postalCode: (map['postalCode'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      nafCode: (map['nafCode'] ?? '').toString(),
      proStatus: (map['proStatus'] ?? '').toString(),
    );
  }
}

class ProSiretService {
  ProSiretService({
    FirebaseFunctions? functions,
  }) : _functionsOverride = functions;

  final FirebaseFunctions? _functionsOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  String cleanSiret(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  bool isValidSiretFormat(String value) {
    final siret = cleanSiret(value);
    return RegExp(r'^\d{14}$').hasMatch(siret);
  }

  bool isValidSiretLuhn(String value) {
    final siret = cleanSiret(value);

    if (!RegExp(r'^\d{14}$').hasMatch(siret)) {
      return false;
    }

    var sum = 0;

    for (var i = 0; i < siret.length; i++) {
      var digit = int.parse(siret[i]);

      if (i % 2 == 0) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
    }

    if (sum % 10 == 0) return true;

    // Exception historique pour certains SIRET La Poste.
    if (siret.startsWith('356000000')) {
      return sum % 5 == 0;
    }

    return false;
  }

  Future<ProSiretVerificationResult> preVerifySiret(String rawSiret) async {
    final cleaned = cleanSiret(rawSiret);

    if (!isValidSiretFormat(cleaned)) {
      throw Exception('Le SIRET doit contenir exactement 14 chiffres.');
    }

    if (!isValidSiretLuhn(cleaned)) {
      throw Exception('Le numéro SIRET n’est pas valide.');
    }

    final callable = _functions.httpsCallable('preVerifySiret');
    final response = await callable.call(<String, dynamic>{
      'siret': cleaned,
    });

    final rawData = response.data;
    if (rawData is! Map) {
      throw Exception('Réponse SIRET invalide.');
    }

    final data = Map<String, dynamic>.from(rawData);
    return ProSiretVerificationResult.fromMap(data);
  }

  Future<ProSiretVerificationResult> verifySiret(String rawSiret) async {
    final siret = cleanSiret(rawSiret);

    if (!isValidSiretFormat(siret)) {
      throw const ProSiretException(
        'Le SIRET doit contenir exactement 14 chiffres.',
      );
    }

    if (!isValidSiretLuhn(siret)) {
      throw const ProSiretException(
        'Le numéro SIRET est invalide.',
      );
    }

    try {
      final callable = _functions.httpsCallable('verifySiret');
      final response = await callable.call<Map<dynamic, dynamic>>({
        'siret': siret,
      });

      final data = Map<String, dynamic>.from(response.data);

      return ProSiretVerificationResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      throw ProSiretException(
        e.message ?? 'Impossible de vérifier ce SIRET pour le moment.',
      );
    }
  }
}

class ProSiretException implements Exception {
  const ProSiretException(this.message);

  final String message;

  @override
  String toString() => message;
}
