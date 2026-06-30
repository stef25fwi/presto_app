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
  }) : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

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

    if (cleaned.isEmpty) {
      throw const ProSiretException(
        'Saisissez votre numéro SIRET avant de lancer la vérification.',
      );
    }

    if (!isValidSiretFormat(cleaned)) {
      throw const ProSiretException(
        'Le SIRET doit contenir exactement 14 chiffres.',
      );
    }

    if (!isValidSiretLuhn(cleaned)) {
      throw const ProSiretException(
        'Le numéro SIRET saisi n’est pas valide. Vérifiez les 14 chiffres.',
      );
    }

    try {
      final callable = _functions.httpsCallable('preVerifySiret');
      final response = await callable.call(<String, dynamic>{
        'siret': cleaned,
      });

      final rawData = response.data;
      if (rawData is! Map) {
        throw const ProSiretException(
          'Réponse SIRET invalide. Réessayez dans quelques instants.',
        );
      }

      final data = Map<String, dynamic>.from(rawData);
      return ProSiretVerificationResult.fromMap(data);
    } on FirebaseFunctionsException catch (error) {
      throw ProSiretException(_friendlySiretFunctionMessage(error));
    }
  }

  String _friendlySiretFunctionMessage(FirebaseFunctionsException error) {
    final message = (error.message ?? '').trim();

    if (message.isNotEmpty &&
        !message.toLowerCase().contains('internal') &&
        !message.toLowerCase().contains('firebase')) {
      return message;
    }

    switch (error.code) {
      case 'invalid-argument':
        return 'Le numéro SIRET saisi est invalide. Vérifiez les 14 chiffres.';
      case 'not-found':
        return 'Aucune entreprise active n’a été trouvée avec ce SIRET.';
      case 'failed-precondition':
        return 'Ce SIRET correspond à un établissement fermé ou inactif.';
      case 'resource-exhausted':
        return 'Trop de vérifications ont été effectuées. Réessayez plus tard.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'La vérification SIRET est temporairement indisponible. Réessayez dans quelques instants.';
      case 'permission-denied':
        return 'La vérification SIRET est bloquée pour le moment. Rechargez la page puis réessayez.';
      default:
        return 'Impossible de vérifier ce SIRET pour le moment. Réessayez.';
    }
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
