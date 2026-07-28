part of '../pricing_calculator_page.dart';

// ---------------------------
// CALC ENGINE (pure logic)
// ---------------------------
class PricingInput {
  final double matieres;
  final double emballage;
  final double consommables;

  final int tempsFabricationMin;
  final double tauxHoraire;

  final double chargesMensuelles;
  final int volumeMensuel;

  /// Either percent OR fixed can be used (both allowed; engine handles)
  final double fraisVentePct; // ex: 0.12
  final double fraisVenteFixe; // ex: 1.20

  final double margePctSurCout; // ex: 0.35 (35%)
  final double tvaPct; // ex: 0.20
  final double prixVenteTtcEnvisage;
  final double materielAAmortir;
  final double amortissementParUnite;
  final double electriciteKwhParUnite;
  final double tarifElectriciteKwh;
  final double eauM3ParUnite;
  final double tarifEauM3;
  final double transportParUnite;
  final double autresCoutsParUnite;
  final String regionCode;

  const PricingInput({
    required this.matieres,
    required this.emballage,
    required this.consommables,
    required this.tempsFabricationMin,
    required this.tauxHoraire,
    required this.chargesMensuelles,
    required this.volumeMensuel,
    required this.fraisVentePct,
    required this.fraisVenteFixe,
    required this.margePctSurCout,
    required this.tvaPct,
    this.prixVenteTtcEnvisage = 0,
    this.materielAAmortir = 0,
    this.amortissementParUnite = 0,
    this.electriciteKwhParUnite = 0,
    this.tarifElectriciteKwh = 0,
    this.eauM3ParUnite = 0,
    this.tarifEauM3 = 0,
    this.transportParUnite = 0,
    this.autresCoutsParUnite = 0,
    this.regionCode = '',
  });

  Map<String, dynamic> toJson() => {
        'matieres': matieres,
        'emballage': emballage,
        'consommables': consommables,
        'tempsFabricationMin': tempsFabricationMin,
        'tauxHoraire': tauxHoraire,
        'chargesMensuelles': chargesMensuelles,
        'volumeMensuel': volumeMensuel,
        'fraisVentePct': fraisVentePct,
        'fraisVenteFixe': fraisVenteFixe,
        'margePctSurCout': margePctSurCout,
        'tvaPct': tvaPct,
        'prixVenteTtcEnvisage': prixVenteTtcEnvisage,
        'materielAAmortir': materielAAmortir,
        'amortissementParUnite': amortissementParUnite,
        'electriciteKwhParUnite': electriciteKwhParUnite,
        'tarifElectriciteKwh': tarifElectriciteKwh,
        'eauM3ParUnite': eauM3ParUnite,
        'tarifEauM3': tarifEauM3,
        'transportParUnite': transportParUnite,
        'autresCoutsParUnite': autresCoutsParUnite,
        'regionCode': regionCode,
      };

  factory PricingInput.fromJson(Map<String, dynamic> json) {
    return PricingInput(
      matieres: _jsonDouble(json['matieres']),
      emballage: _jsonDouble(json['emballage']),
      consommables: _jsonDouble(json['consommables']),
      tempsFabricationMin: _jsonInt(json['tempsFabricationMin']),
      tauxHoraire: _jsonDouble(json['tauxHoraire']),
      chargesMensuelles: _jsonDouble(json['chargesMensuelles']),
      volumeMensuel: math.max(_jsonInt(json['volumeMensuel']), 1),
      fraisVentePct: _jsonDouble(json['fraisVentePct']),
      fraisVenteFixe: _jsonDouble(json['fraisVenteFixe']),
      margePctSurCout: _jsonDouble(json['margePctSurCout']),
      tvaPct: _jsonDouble(json['tvaPct']),
      prixVenteTtcEnvisage:
          _jsonDouble(json['prixVenteTtcEnvisage']),
      materielAAmortir: _jsonDouble(json['materielAAmortir']),
      amortissementParUnite:
          _jsonDouble(json['amortissementParUnite']),
      electriciteKwhParUnite:
          _jsonDouble(json['electriciteKwhParUnite']),
      tarifElectriciteKwh:
          _jsonDouble(json['tarifElectriciteKwh']),
      eauM3ParUnite: _jsonDouble(json['eauM3ParUnite']),
      tarifEauM3: _jsonDouble(json['tarifEauM3']),
      transportParUnite: _jsonDouble(json['transportParUnite']),
      autresCoutsParUnite:
          _jsonDouble(json['autresCoutsParUnite']),
      regionCode: json['regionCode']?.toString() ?? '',
    );
  }
}

class PricingResult {
  final double coutDirect;
  final double coutEnergieEau;
  final double coutTransportAutres;
  final double coutMainOeuvre;
  final double chargeFixeUnitaire;
  final double amortissementUnitaire;
  final double coutDeRevient; // CR (hors frais % sur prix)
  final double prixMinimumRentable;
  final double prixMinimumRentableTtc;
  final double prixConseille;
  final double prixTTC;
  final double margeUnitaireEnvisagee;
  final double margeUnitaireConseillee;
  final int unitesPourAmortir;
  final int seuilRentabiliteUnites;
  final bool prixEnvisageRentable;

  const PricingResult({
    required this.coutDirect,
    required this.coutEnergieEau,
    required this.coutTransportAutres,
    required this.coutMainOeuvre,
    required this.chargeFixeUnitaire,
    required this.amortissementUnitaire,
    required this.coutDeRevient,
    required this.prixMinimumRentable,
    required this.prixMinimumRentableTtc,
    required this.prixConseille,
    required this.prixTTC,
    required this.margeUnitaireEnvisagee,
    required this.margeUnitaireConseillee,
    required this.unitesPourAmortir,
    required this.seuilRentabiliteUnites,
    required this.prixEnvisageRentable,
  });

  Map<String, dynamic> toJson() => {
        'coutDirect': coutDirect,
        'coutEnergieEau': coutEnergieEau,
        'coutTransportAutres': coutTransportAutres,
        'coutMainOeuvre': coutMainOeuvre,
        'chargeFixeUnitaire': chargeFixeUnitaire,
        'amortissementUnitaire': amortissementUnitaire,
        'coutDeRevient': coutDeRevient,
        'prixMinimumRentable': prixMinimumRentable,
        'prixMinimumRentableTtc': prixMinimumRentableTtc,
        'prixConseille': prixConseille,
        'prixTTC': prixTTC,
        'margeUnitaireEnvisagee': margeUnitaireEnvisagee,
        'margeUnitaireConseillee': margeUnitaireConseillee,
        'unitesPourAmortir': unitesPourAmortir,
        'seuilRentabiliteUnites': seuilRentabiliteUnites,
        'prixEnvisageRentable': prixEnvisageRentable,
      };

  factory PricingResult.fromJson(Map<String, dynamic> json) {
    return PricingResult(
      coutDirect: _jsonDouble(json['coutDirect']),
      coutEnergieEau: _jsonDouble(json['coutEnergieEau']),
      coutTransportAutres:
          _jsonDouble(json['coutTransportAutres']),
      coutMainOeuvre: _jsonDouble(json['coutMainOeuvre']),
      chargeFixeUnitaire:
          _jsonDouble(json['chargeFixeUnitaire']),
      amortissementUnitaire:
          _jsonDouble(json['amortissementUnitaire']),
      coutDeRevient: _jsonDouble(json['coutDeRevient']),
      prixMinimumRentable:
          _jsonDouble(json['prixMinimumRentable']),
      prixMinimumRentableTtc:
          _jsonDouble(json['prixMinimumRentableTtc']),
      prixConseille: _jsonDouble(json['prixConseille']),
      prixTTC: _jsonDouble(json['prixTTC']),
      margeUnitaireEnvisagee:
          _jsonDouble(json['margeUnitaireEnvisagee']),
      margeUnitaireConseillee:
          _jsonDouble(json['margeUnitaireConseillee']),
      unitesPourAmortir: _jsonInt(json['unitesPourAmortir']),
      seuilRentabiliteUnites:
          _jsonInt(json['seuilRentabiliteUnites']),
      prixEnvisageRentable:
          json['prixEnvisageRentable'] == true,
    );
  }
}

class PricingScenarioResult {
  final String name;
  final int volume;
  final double chiffreAffairesTtc;
  final double beneficeMensuel;
  final double beneficeParUnite;

  const PricingScenarioResult({
    required this.name,
    required this.volume,
    required this.chiffreAffairesTtc,
    required this.beneficeMensuel,
    required this.beneficeParUnite,
  });
}

class PricingEngine {
  static PricingResult compute(PricingInput i) {
    final coutEnergie =
        (i.electriciteKwhParUnite * i.tarifElectriciteKwh) +
            (i.eauM3ParUnite * i.tarifEauM3);
    final transportAutres = i.transportParUnite + i.autresCoutsParUnite;
    final coutDirect = i.matieres +
        i.emballage +
        i.consommables +
        coutEnergie +
        transportAutres;
    final coutMO = (i.tempsFabricationMin / 60.0) * i.tauxHoraire;
    final chargeFixe = i.chargesMensuelles / math.max(i.volumeMensuel, 1);
    final amortissement = math.max(i.amortissementParUnite, 0.0);
    final crHorsFraisPct =
        coutDirect + coutMO + chargeFixe + amortissement;

    final prixMin = _applyFeesToReachNet(
      targetNet: crHorsFraisPct + i.fraisVenteFixe,
      fraisPct: i.fraisVentePct,
    );
    final netCible =
        (crHorsFraisPct * (1 + i.margePctSurCout)) + i.fraisVenteFixe;
    final prixConseille = _applyFeesToReachNet(
      targetNet: netCible,
      fraisPct: i.fraisVentePct,
    );

    final prixMinTtc = prixMin * (1 + i.tvaPct);
    final prixTTC = prixConseille * (1 + i.tvaPct);
    final prixEnvisageHt =
        i.prixVenteTtcEnvisage / (1 + math.max(i.tvaPct, 0));
    final fraisEnvisages =
        (prixEnvisageHt * i.fraisVentePct.clamp(0.0, 0.999)) +
            i.fraisVenteFixe;
    final margeEnvisagee =
        prixEnvisageHt - crHorsFraisPct - fraisEnvisages;
    final fraisConseilles =
        (prixConseille * i.fraisVentePct.clamp(0.0, 0.999)) +
            i.fraisVenteFixe;
    final margeConseillee =
        prixConseille - crHorsFraisPct - fraisConseilles;

    final unitesPourAmortir =
        i.materielAAmortir > 0 && amortissement > 0
            ? (i.materielAAmortir / amortissement).ceil()
            : 0;

    final prixReferenceTtc =
        i.prixVenteTtcEnvisage > 0 ? i.prixVenteTtcEnvisage : prixTTC;
    final prixReferenceHt =
        prixReferenceTtc / (1 + math.max(i.tvaPct, 0));
    final fraisReference =
        (prixReferenceHt * i.fraisVentePct.clamp(0.0, 0.999)) +
            i.fraisVenteFixe;
    final coutVariable =
        coutDirect + coutMO + amortissement;
    final contribution =
        prixReferenceHt - fraisReference - coutVariable;
    final seuilRentabilite = i.chargesMensuelles <= 0
        ? 0
        : contribution > 0
            ? (i.chargesMensuelles / contribution).ceil()
            : 0;

    return PricingResult(
      coutDirect: coutDirect,
      coutEnergieEau: coutEnergie,
      coutTransportAutres: transportAutres,
      coutMainOeuvre: coutMO,
      chargeFixeUnitaire: chargeFixe,
      amortissementUnitaire: amortissement,
      coutDeRevient: crHorsFraisPct,
      prixMinimumRentable: prixMin,
      prixMinimumRentableTtc: prixMinTtc,
      prixConseille: prixConseille,
      prixTTC: prixTTC,
      margeUnitaireEnvisagee: margeEnvisagee,
      margeUnitaireConseillee: margeConseillee,
      unitesPourAmortir: unitesPourAmortir,
      seuilRentabiliteUnites: seuilRentabilite,
      prixEnvisageRentable:
          i.prixVenteTtcEnvisage > 0 && margeEnvisagee >= 0,
    );
  }

  static PricingScenarioResult computeScenario(
    PricingInput input, {
    required String name,
    required int volume,
  }) {
    final safeVolume = math.max(volume, 1);
    final result = compute(input);
    final priceTtc = input.prixVenteTtcEnvisage > 0
        ? input.prixVenteTtcEnvisage
        : result.prixTTC;
    final priceHt = priceTtc / (1 + math.max(input.tvaPct, 0));
    final coutEnergie =
        (input.electriciteKwhParUnite * input.tarifElectriciteKwh) +
            (input.eauM3ParUnite * input.tarifEauM3);
    final coutVariable = input.matieres +
        input.emballage +
        input.consommables +
        coutEnergie +
        input.transportParUnite +
        input.autresCoutsParUnite +
        ((input.tempsFabricationMin / 60.0) * input.tauxHoraire) +
        input.amortissementParUnite;
    final fraisUnitaire =
        (priceHt * input.fraisVentePct.clamp(0.0, 0.999)) +
            input.fraisVenteFixe;
    final beneficeMensuel =
        ((priceHt - coutVariable - fraisUnitaire) * safeVolume) -
            input.chargesMensuelles;

    return PricingScenarioResult(
      name: name,
      volume: safeVolume,
      chiffreAffairesTtc: priceTtc * safeVolume,
      beneficeMensuel: beneficeMensuel,
      beneficeParUnite: beneficeMensuel / safeVolume,
    );
  }

  static double _applyFeesToReachNet({
    required double targetNet,
    required double fraisPct,
  }) {
    final p = fraisPct.clamp(0.0, 0.999);
    return targetNet / (1.0 - p);
  }
}

class PricingRegionalTariffs {
  final double? electricityPerKwh;
  final double? waterPerM3;
  final DateTime? updatedAt;

  const PricingRegionalTariffs({
    required this.electricityPerKwh,
    required this.waterPerM3,
    required this.updatedAt,
  });
}

class PricingRegionalTariffRepository {
  final FirebaseFirestore? firestore;

  const PricingRegionalTariffRepository({this.firestore});

  Future<PricingRegionalTariffs?> load(String regionCode) async {
    if (firestore == null && Firebase.apps.isEmpty) return null;
    final database = firestore ?? FirebaseFirestore.instance;
    final snapshots = await Future.wait([
      database.collection('tarifs_electricite').doc(regionCode).get(),
      database.collection('tarifs_eau').doc(regionCode).get(),
    ]);
    final electricity = snapshots[0].data();
    final water = snapshots[1].data();
    if (electricity == null && water == null) return null;

    final electricityRate = _firstNumber(
      electricity,
      const ['prixKwh', 'pricePerKwh', 'tarifKwh', 'value'],
    );
    final waterRate = _firstNumber(
      water,
      const ['prixM3', 'pricePerM3', 'tarifM3', 'value'],
    );
    if (electricityRate == null && waterRate == null) return null;

    final electricityDate = _firstDate(electricity);
    final waterDate = _firstDate(water);
    final dates = [
      if (electricityDate != null) electricityDate,
      if (waterDate != null) waterDate,
    ]..sort();

    return PricingRegionalTariffs(
      electricityPerKwh: electricityRate,
      waterPerM3: waterRate,
      updatedAt: dates.isEmpty ? null : dates.last,
    );
  }

  static double? _firstNumber(
    Map<String, dynamic>? data,
    List<String> keys,
  ) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static DateTime? _firstDate(Map<String, dynamic>? data) {
    if (data == null) return null;
    for (final key in const ['updatedAt', 'effectiveAt', 'date']) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }
}


// ---------------------------
// MARKET POSITIONING
// ---------------------------
class MarketEval {
  final String label;
  final String hint;
  final Color color;

  const MarketEval(this.label, this.hint, this.color);
}

class MarketPositioning {
  static MarketEval evaluate({
    required double price,
    required double low,
    required double mid,
    required double high,
  }) {
    if (low <= 0 || mid <= 0 || high <= 0 || !(low <= mid && mid <= high)) {
      return const MarketEval(
        'Marché non renseigné',
        'Ajoute une fourchette (bas / moyen / haut) pour un conseil plus précis.',
        Color(0xFF9CA3AF),
      );
    }

    if (price < low) {
      return const MarketEval(
        'Sous-évalué',
        'Tu peux augmenter ton prix sans sortir du marché.',
        Color(0xFFF59E0B),
      );
    }
    if (price <= high) {
      return const MarketEval(
        'Aligné sur le marché!',
        'Bien placé. Mets en avant qualité & délai.',
        Color(0xFF22C55E),
      );
    }
    return const MarketEval(
      'Positionnement Premium',
      'À ce prix, renforce la valeur perçue (finitions, packaging, story, édition limitée).',
      Color(0xFFEF4444),
    );
  }
}
