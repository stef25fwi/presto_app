import 'entrepreneur_pricing_engine.dart';

export 'entrepreneur_pricing_engine.dart';
export 'entrepreneur_pricing_parsing.dart';

/// Centralise le décodage persistant des modèles de calcul tarifaire.
///
/// Ce point d’entrée garantit que le stockage local et ses futures migrations
/// utilisent tous la même logique de désérialisation.
class EntrepreneurPricingModelCodec {
  const EntrepreneurPricingModelCodec._();

  static EntrepreneurPricingDraft decodeDraft(Object? value) {
    return EntrepreneurPricingDraft.fromJson(
      Map<String, dynamic>.from(value as Map? ?? const {}),
    );
  }

  static EntrepreneurPricingCalculation decodeCalculation(Object? value) {
    return EntrepreneurPricingCalculation.fromJson(
      Map<String, dynamic>.from(value as Map? ?? const {}),
    );
  }
}