import 'dart:convert';

import 'package:http/http.dart' as http;

class MonEntrepriseSimulationResult {
  final bool success;
  final String source;
  final String? error;
  final double? cotisations;
  final double? revenuNet;
  final double? revenuApresImpot;
  final Map<String, dynamic>? raw;

  const MonEntrepriseSimulationResult({
    required this.success,
    required this.source,
    this.error,
    this.cotisations,
    this.revenuNet,
    this.revenuApresImpot,
    this.raw,
  });
}

class JeMeLanceMonEntrepriseApiService {
  static const String endpoint =
      'https://mon-entreprise.urssaf.fr/api/v1/evaluate';

  const JeMeLanceMonEntrepriseApiService();

  Future<MonEntrepriseSimulationResult> simulateAutoEntrepreneurCommerce({
    required double annualRevenue,
    bool isDrom = false,
  }) async {
    final payload = <String, dynamic>{
      'expressions': [
        'dirigeant . auto-entrepreneur . cotisations et contributions',
        'dirigeant . auto-entrepreneur . revenu net',
        'dirigeant . auto-entrepreneur . revenu net . après impôt',
      ],
      'situation': {
        'dirigeant . auto-entrepreneur': 'oui',
        'dirigeant . auto-entrepreneur . chiffre d’affaires': {
          'valeur': annualRevenue,
          'unité': '€/an',
        },
        'entreprise . activité . commerciale': 'oui',
        if (isDrom) 'dirigeant . auto-entrepreneur . DROM': 'oui',
      },
    };

    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: const {
              'accept': 'application/json',
              'content-type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return MonEntrepriseSimulationResult(
          success: false,
          source: 'Mon-entreprise / Urssaf',
          error: 'HTTP ${response.statusCode} : ${response.body}',
          raw: decoded is Map<String, dynamic> ? decoded : null,
        );
      }

      if (decoded is! Map<String, dynamic>) {
        return const MonEntrepriseSimulationResult(
          success: false,
          source: 'Mon-entreprise / Urssaf',
          error: 'Réponse API inattendue.',
        );
      }

      final evaluate = decoded['evaluate'];
      double? readValue(int index) {
        if (evaluate is! List || evaluate.length <= index) return null;
        final item = evaluate[index];
        if (item is! Map) return null;
        final value = item['nodeValue'];
        if (value is num) return value.toDouble();
        return null;
      }

      return MonEntrepriseSimulationResult(
        success: true,
        source: 'Mon-entreprise / Urssaf',
        cotisations: readValue(0),
        revenuNet: readValue(1),
        revenuApresImpot: readValue(2),
        raw: decoded,
      );
    } catch (error) {
      return MonEntrepriseSimulationResult(
        success: false,
        source: 'Mon-entreprise / Urssaf',
        error: 'Appel API impossible ou règles à ajuster : ${error.toString()}',
      );
    }
  }
}
